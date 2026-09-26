-- 몬스터 런타임 상태 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다.
-- 확인 결과: Humanoid.Health/MaxHealth는 문서상 number(Lua 64비트 double)이지만,
-- 로블록스 내부적으로는 32비트 float로 저장되는 것으로 보고돼 있다(devforum: 값이 10^9
-- 근처만 가도 정밀도가 깨져 미세 조정이 불가능해짐). 우리 무한 모드는 1e308까지 가고
-- 그 위는 bignum{m,e}로 넘어가므로 애초에 Humanoid.Health로는 표현이 불가능하다.
-- 지금은 plain number로 두되, 나중에 bignum{m,e}로 바꿀 때 이 모듈만 고치면 되도록
-- 읽기/쓰기를 한 곳으로 모은다.
--
-- 19-4: 사냥터 잡몹(공유)과 보스(개인 인스턴스)가 서로 다른 HP 모델을 쓴다 - 반드시
-- isBoss로 분기해서 읽어야 한다.
--   보스(isBoss=true): 기존 그대로 절대값 hp/maxHp. BossRules.buildInstanceData가
--     스폰 시점에 이미 스테이지 배율을 곱해 최종값을 만들어 두므로(플레이어 1인 전용
--     인스턴스라 "누구 기준인가" 문제 자체가 없다), 여기서 추가로 배율을 곱하지 않는다.
--   잡몹(isBoss=false/nil): 절대값이 없다. hpRatio(0~1)만 저장한다 - 여러 플레이어가
--     서로 다른 stage를 갖고 같은 몬스터를 때리므로 "이 몬스터의 최대체력"이라는 절대
--     숫자 자체가 성립하지 않는다(19-4 [0] 조사, C안 채택). 대신 플레이어 P가 데미지 D를
--     넣으면 "P의 stage 기준 이 몬스터의 유효 최대체력"(InfiniteStage.getMonsterHp(data.hp,
--     P.stage))으로 나눈 비율만큼 공용 hpRatio 풀에서 뺀다 - 이 비율 자체는 "누구
--     기준인가"를 묻지 않는 값이라(0~1 사이, 보는 사람과 무관) HP바에 그대로 쓸 수 있다.
--     공격력·골드·경험치도 같은 이유로 "그 순간 계산 대상 플레이어의 stage"를 인자로
--     받는다(getAttackFor/getGoldDropFor/getExpRewardFor) - 몬스터 인스턴스 자체엔
--     stage를 저장하지 않는다(예전 setStage/getStage는 19-4에서 완전히 제거했다).
--   C1(2026-09-26): 위 "때린 사람 stage로 나눈다"는 기준 스테이지(참여자 중 최고)로 바뀌었다 - 규칙 = shared/MobShare.lua 머리 주석.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
local TreasureChestConfig = require(ReplicatedStorage.Shared.data.TreasureChestConfig)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig) -- C1 도움 참여 반경
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local MobShare = require(ReplicatedStorage.Shared.MobShare) -- C1: 기준 스테이지(참여자 중 최고)로 잡몹 피해 환산
local AlphaStats = require(script.Parent.AlphaStats) -- C1 마무리: 결정 6 탱커 끌어오기 계측
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel) -- G1-3: 레벨차 계수 -- G1-2: 처치 시간 상한(fairness.maxSecondsPerHit)

local MonsterState = {}

-- [Model] = { hp, maxHp(보스 전용, 잡몹은 nil), hpRatio(잡몹 전용, 보스는 nil),
--             contributions(잡몹 전용 - [Player]=누적 기여 비율, 보스는 nil),
--             data(스폰에 쓴 MonsterData/BossRules 항목 - 여러 몬스터 인스턴스가 같은
--             테이블을 공유하므로 절대 직접 고치지 않는다), spawnPosition(리스폰 자리),
--             aiState("idle"/"chasing"/"returning"), aiTarget(추격 중인 Player, 없으면 nil),
--             lastAttackTick(반격 쿨다운 기준 시각, os.clock()),
--             bossPattern(21-3, isBoss 인스턴스만 - 패턴 상태 머신의 가변 테이블. 내용은
--             BossPatterns.lua만 읽고 쓴다 - 15-1의 bossPhase/bossPhaseEndsAt/bossNextHeavyAt
--             세 필드를 이 테이블 하나로 대체했다. 여기 두는 이유는 "몬스터 런타임 상태는
--             이 모듈이 단일 통로"라는 원칙 - clear(model) 한 번에 같이 사라진다) }
local monsters = {}

-- C1: 실제 Player의 "지금" 스테이지(TutorialState.getMonsterStage - TutorialState가 이 모듈을 require하므로 여기서 부를 수 없어 거꾸로 등록한다).
-- 지연 피해(꽂힌 화살 폭발 · 채널 틱)가 시전 때 잡은 옛 스테이지로 참여하는 것을 막는다(리뷰 3). 스탠드인(표)은 넘긴 스테이지 그대로.
local stageResolver = nil
function MonsterState.setStageResolver(fn)
	stageResolver = fn
end

-- C1: 피해 없이 비율이 바뀐 몹(기준 상승 · 초기화 - 어그로 · 도움 · 퇴장) → HP바 다시 그리기(MonsterSpawner가 등록 - 리뷰 4).
local ratioListener = nil
function MonsterState.setRatioListener(fn)
	ratioListener = fn
end
local function notifyRatio(model)
	if ratioListener then
		ratioListener(model)
	end
end

-- C1 후속: 막힌 타격(스틸 불가한 낮은 사람이 잡는 몹을 더 높은 사람이 침) → 그 사람 화면에 반사 연출(CombatResolution이 등록 - RemoteEvent).
local blockedListener = nil
function MonsterState.setBlockedListener(fn)
	blockedListener = fn
end

-- C1 마무리: 잡는 사람 목록 → 모델 Attribute MobHunters(클라 MobLockView가 자물쇠 · 회색 체력바를 각자 판정 - MobShare.lockedFor).
-- 만료는 서버 시각으로 적어 두므로 서버가 따로 지우지 않아도 클라가 풀린다. 타격마다 만료가 늘어나 글이 바뀌므로 같은 사람 집합이면 0.5초에 1번만 쓴다.
local HUNTERS_REWRITE_SECONDS = 0.5
local function syncHunters(model, entry, now)
	local serverNow = workspace:GetServerTimeNow()
	local encoded = MobShare.encodeHunters(entry, now, function(at)
		return serverNow + (at - now)
	end)
	local idKey = encoded:gsub(",[%d%.]+;", ";"):gsub(",[%d%.]+$", "")
	if idKey == entry.huntersKey and now - (entry.huntersWrittenAt or 0) < HUNTERS_REWRITE_SECONDS then
		return
	end
	entry.huntersKey = idKey
	entry.huntersWrittenAt = now
	model:SetAttribute("MobHunters", encoded ~= "" and encoded or nil)
end

-- variant(22-2) - 스폰 시점에 굴린 인스턴스별 변종 { isSparkle, prefix(MonsterPrefixData 항목
-- 또는 nil), isChest }. data는 여러 인스턴스가 공유하는 원본 테이블이라 변종 배율을 data에
-- 쓰지 않고 entry에만 둔다. 보스는 셋 다 없다(MonsterSpawner.spawn이 보스엔 안 굴린다).
--
-- 보물상자(isChest, 22-2 [3])는 HP 대신 피격 횟수를 센다 - chestHits(총 유효 피격 수),
-- chestLastHitAt([Player]=마지막 유효 피격 시각), chestHitters([Player]=true, 한 번이라도
-- 유효 피격을 낸 전원 - 보상 대상). 상자가 파괴·소멸되면 clear(model) 한 번에 이 셋이
-- 같이 사라진다(지시 "정리 항목" - 기록을 entry 밖에 두지 않는 이유).
function MonsterState.init(model, data, spawnPosition, zoneKey, variant)
	variant = variant or {}
	monsters[model] = {
		hp = data.isBoss and data.hp or nil,
		maxHp = data.isBoss and data.hp or nil,
		hpRatio = data.isBoss and nil or 1.0,
		-- 24-1: 보스도 기여 비율을 기록한다(damage/maxHp) - 파티 보스 보상이 잡몹과 같은 "기여
		-- 10% 이상 각자 독립 지급" 규칙(CombatConfig.contributionRewardThreshold)을 쓴다(지시 4).
		contributions = {},
		hitCounts = {}, -- G1-2 리뷰 2
		firstHitAt = {}, -- G1-2: [Player] = 처음 때린 시각(os.clock) - 처치 시간 공정성 보정(DropTable.timeFairnessFactor)
		data = data,
		spawnPosition = spawnPosition,
		zoneKey = zoneKey, -- 16-6, tier 구역 몬스터만 있음(보스는 nil).
		isSparkle = variant.isSparkle or false, -- 19-4 [6], 잡몹 전용(보스는 항상 false로 들어온다).
		prefix = variant.prefix, -- 22-2 [1], 잡몹 전용.
		isChest = variant.isChest or false, -- 22-2 [3].
		-- 29-3 구출 대상(빙결된 친구를 감싼 얼음 덩어리). 몬스터가 아니다 - 조준·피격 경로만 공유한다(상자와 같은 이유).
		-- HP가 없고, 맞을 때마다 onRescueHit(때린 사람)을 부를 뿐이다. HP바는 rescueRemaining()(1 → 0)을 그린다.
		isRescueTarget = variant.isRescueTarget or false,
		onRescueHit = variant.onRescueHit,
		rescueRemaining = variant.rescueRemaining,
		chestHits = 0,
		chestLastHitAt = {},
		chestHitters = {},
		aiState = "idle",
		aiTarget = nil,
		lastAttackTick = nil,
		bossPattern = data.isBoss and {} or nil,
	}
	if not data.isBoss then
		MobShare.fresh(monsters[model]) -- C1: hpRatio · refStage · participants · partStage · 기여 · 첫 타격(보스는 고정 스테이지라 없음)
	end
end

function MonsterState.isChest(model)
	local entry = monsters[model]
	return entry ~= nil and entry.isChest
end

function MonsterState.isRescueTarget(model)
	local entry = monsters[model]
	return entry ~= nil and entry.isRescueTarget
end

function MonsterState.getPrefix(model)
	local entry = monsters[model]
	return entry and entry.prefix
end

-- 접두사 보상 배율(22-2 [1]) - 골드·경험치·드랍 확률이 전부 이 값을 곱는다(= HP 배율,
-- MonsterPrefixData 공평성 정의). 접두사가 없으면 1.
function MonsterState.getRewardMultiplier(model)
	local entry = monsters[model]
	return MonsterPrefixData.getRewardMultiplier(entry and entry.prefix)
end

-- 이동속도(22-2 [1]) - data.moveSpeedStuds × 접두사 배율. MonsterAI가 data를 직접 읽지 않고
-- 이 함수를 쓴다(인스턴스별 값이라 공유 data에 둘 수 없다).
function MonsterState.getMoveSpeed(model)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	local multiplier = entry.prefix and entry.prefix.moveSpeedMultiplier or 1
	return entry.data.moveSpeedStuds * multiplier
end

-- 보물상자를 한 번이라도 유효 피격한 [Player]=true 집합(22-2 [3] - 파괴 시 전원이 각자
-- 보상을 받는다). 상자가 아니면 빈 테이블.
function MonsterState.getChestHitters(model)
	local entry = monsters[model]
	return (entry and entry.isChest and entry.chestHitters) or {}
end

-- 21-3 - 보스 패턴 상태 테이블(BossPatterns.lua 전용). 보스가 아니면 nil.
function MonsterState.getBossPatternState(model)
	local entry = monsters[model]
	return entry and entry.bossPattern
end

-- 21-3 - 플레이어 사망 시 보스 HP를 최대치로 되돌린다(BossEncounter.resetFor). 잡몹은
-- 대상이 아니다(공유 비율 HP라 "되돌릴 최대치" 자체가 없다).
function MonsterState.resetBossHp(model)
	local entry = monsters[model]
	if entry and entry.data.isBoss then
		entry.hp = entry.maxHp
		entry.contributions = {} -- 처음부터 다시 - 리셋 전 기여는 무효(HP가 복구됐으므로).
	end
end

-- 29-1 - 보스의 받는 피해 배율(파훼 게이트 ×g, 기회 창 ×m). BossMechanics만 쓴다. 기본 1.
function MonsterState.setDamageTakenMultiplier(model, multiplier)
	local entry = monsters[model]
	if entry and entry.data.isBoss then
		entry.damageTakenMultiplier = multiplier
	end
end

function MonsterState.getDamageTakenMultiplier(model)
	local entry = monsters[model]
	return entry and entry.damageTakenMultiplier or 1
end

-- 29-3 - 보스가 플레이어에게 맞을 때마다 불리는 함수 하나(BossMechanics의 반사 태세만 쓴다). nil이면 끈다.
-- 플레이어 → 보스 피해는 전부 applyDamage를 지나므로 평타·스킬·투사체·꽂힌 화살이 빠짐없이 여기로 온다.
function MonsterState.setHitListener(model, fn)
	local entry = monsters[model]
	if entry and entry.data.isBoss then
		entry.hitListener = fn
	end
end

-- 24-1 DevTools "/gg party info" 전용 - 보스 절대 HP(현재/최대). 잡몹은 nil.
function MonsterState.getBossHp(model)
	local entry = monsters[model]
	if entry and entry.data.isBoss then
		return entry.hp, entry.maxHp
	end
	return nil
end

function MonsterState.isSparkle(model)
	local entry = monsters[model]
	return entry ~= nil and entry.isSparkle
end

function MonsterState.getZoneKey(model)
	local entry = monsters[model]
	return entry and entry.zoneKey
end

function MonsterState.getData(model)
	local entry = monsters[model]
	return entry and entry.data
end

-- HP 비율(0~1). 보스는 hp/maxHp를 그대로 나눈 값(기존과 동일한 절대값 기반), 잡몹은
-- hpRatio를 그대로 돌려준다. MonsterSpawner.updateHpLabel(HP바)이 이 함수 하나만 본다 -
-- "누구 기준인가"를 몰라도 되는 값이라 HP바가 유일하게 항상 정확한 표시다(19-4 [1] 지시 -
-- 절대 숫자를 보여주지 않는다).
function MonsterState.getHpRatio(model)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.maxHp > 0 and math.clamp(entry.hp / entry.maxHp, 0, 1) or 0
	end
	if entry.isRescueTarget then
		return math.clamp(entry.rescueRemaining and entry.rescueRemaining() or 1, 0, 1)
	end
	if entry.isChest then
		-- 상자는 "남은 피격 횟수" 비율 - HP바 하나로 진행도를 보여준다.
		return math.clamp(1 - entry.chestHits / TreasureChestConfig.requiredHits, 0, 1)
	end
	return math.clamp(entry.hpRatio, 0, 1)
end

-- 데미지 적용(19-4 [1][2]). attackerStage는 잡몹 계산에만 쓰인다(보스는 무시) -
-- attackerPlayer는 기여 비율 기록용. 24-1부터 보스도 기록한다(damage/maxHp) - 파티 보스
-- 보상이 잡몹과 같은 기여 임계값 규칙을 쓰기 때문(CombatResolution.handleBossDeath).
-- 반환값: 이번 타격으로 죽었는가(bool), 실제로 들어간 피해(29-1 - 보스의 받는 피해 배율이
-- 곱해진 값. 호출부가 데미지 숫자·흡혈에 이 값을 쓴다. 잡몹·상자는 넘긴 damage 그대로).
-- hitInfo(29-3, 선택) = { committedAt = 이 공격을 시작한 시각(os.clock - 투사체는 쏜 순간, 채널링은 시전 순간. 없으면
-- 지금), indirect = 지연 폭발·지속 피해 } - 보스의 반사 태세가 "막을 수 있었던 공격인가"를 가리는 데만 쓴다.
-- BR1-2 보스 보호막(수정 여왕 환경 변화 동안): 켜진 동안 받는 피해 0 · 모델 Attribute BossShielded(클라 "무효" 표시 · 보호막 그림).
function MonsterState.setShielded(model, shielded)
	local entry = monsters[model]
	if entry then
		entry.shielded = shielded or nil
	end
	if model and model.Parent then
		model:SetAttribute("BossShielded", shielded or nil)
	end
end

function MonsterState.applyDamage(model, damage, attackerStage, attackerPlayer, hitInfo)
	local entry = monsters[model]
	if not entry then
		return false, 0
	end
	-- G1-3: 레벨차 계수 - 주는 피해(CharacterLevelConfig.levelGap). 스테이지 = 잡몹은 때린 사람의 스테이지, 보스는 보스 스테이지. 실제 Player만(스탠드인 · 구출 · 상자는 영향 없음).
	local damageBeforeGap = damage -- G2a(사용자 결정 - G1-3 결정 필요 2): 보스 기여도는 계수를 곱하기 전 피해로 센다(저레벨 파티원이 10% 문턱에서 빠지지 않게)
	local fixed = hitInfo ~= nil and hitInfo.fixed == true -- BR1-3 고정 피해(보스 에어본 5% - 레벨차 계수 · 받는 피해 배율 없이, 보호막만 막는다)
	-- C1: 잡몹은 먼저 참여시켜 기준 스테이지(참여자 중 최고)를 정한다 - 레벨차 계수 · 환산 HP 둘 다 이 기준(때린 사람 스테이지가 아니다).
	local mobRef
	if not entry.data.isBoss and not entry.isRescueTarget and not entry.isChest then
		local now = os.clock()
		if attackerPlayer then
			local stage = (stageResolver and typeof(attackerPlayer) == "Instance") and stageResolver(attackerPlayer) or attackerStage
			local oldRef = entry.refStage
			local touchedRef, _wasReset, rose, blocked = MobShare.touch(entry, attackerPlayer, stage, now)
			mobRef = touchedRef
			if blocked then
				-- C1 후속(결정 1): 스틸 불가 + 더 높은 스테이지 - 피해 0 · 참여 · 기여 없음 · 기준 그대로
				if blockedListener then
					blockedListener(model, attackerPlayer)
				end
				return false, 0
			end
			-- 결정 6 계측: 쫓기기만 하던 몹(pullStartedAt)이 첫 타격 한 번에 기준이 stealStageGap 넘게 오름 = 탱커 끌어오기
			local pullLive = entry.pullLastAt and now - entry.pullLastAt <= CombatConfig.participationWindowSeconds -- 리뷰 3: 끊긴 지 8초 넘은 옛 끌기는 안 센다
			if entry.pullStartedAt and pullLive and rose and oldRef and touchedRef - oldRef > CombatConfig.stealStageGap then
				AlphaStats.notePull(now - entry.pullStartedAt, touchedRef - oldRef, entry.data.attackCooldownSeconds or 1)
			end
			entry.pullStartedAt = nil
			syncHunters(model, entry, now)
		else
			mobRef = MobShare.refresh(entry, now)
			if entry.refStage == nil then
				entry.refStage = attackerStage -- 리뷰 2: 공격자 없는 피해도 기준을 남긴다(다음 상승이 이 비율을 다시 환산하게)
			end
		end
		mobRef = mobRef or attackerStage
	end
	if typeof(attackerPlayer) == "Instance" and not entry.isRescueTarget and not entry.isChest and not fixed then
		local gapStage = entry.data.isBoss and entry.data.stageNumber or mobRef
		damage *= CharacterLevel.levelGapDealMultiplier(attackerPlayer:GetAttribute("CharacterLevel"), gapStage)
	end

	if entry.data.isBoss then
		if entry.hitListener and attackerPlayer then
			entry.hitListener(attackerPlayer, hitInfo)
		end
		-- 29-1 파훼 게이트·기회 창(BossMechanics가 setDamageTakenMultiplier로 건다). 기여도도 받는 피해 배율까지는 곱한다.
		-- G2a: 레벨차 계수만 빼고 센다(계수가 1이면 합이 1(= maxHp)로 닫히고, 벌점을 받는 멤버가 있으면 합이 1보다 조금 크다 - 문턱 · 표시 모두 이 값).
		local taken = fixed and 1 or (entry.damageTakenMultiplier or 1)
		if entry.shielded then -- BR1-2 수정 여왕 보호막: 피해로는 절대 안 깨진다(수정 둘을 깨야 풀린다 - BossEnvironment) · 클라는 "무효"로 그린다
			taken = 0
		end
		damage *= taken
		entry.hp -= damage
		if attackerPlayer and entry.maxHp > 0 then
			entry.contributions[attackerPlayer] = (entry.contributions[attackerPlayer] or 0) + damageBeforeGap * taken / entry.maxHp
		end
		return entry.hp <= 0, damage
	end

	-- 구출 대상(29-3) - 피해도 죽음도 없다. 누가 때렸는지만 알린다(유효 타격 규칙은 BossGimmicks의 구출 핸들러가 안다).
	-- 들어간 피해 0 → 데미지 숫자 0·흡혈 0("구출에는 보상이 없다", 20.73 [2-8] A-2).
	if entry.isRescueTarget then
		if attackerPlayer and entry.onRescueHit then
			entry.onRescueHit(attackerPlayer, hitInfo) -- 29-5: 분신은 "막을 수 있었던 공격인가"(hitInfo)를 본다
		end
		return false, 0
	end

	-- 보물상자(22-2 [3]) - 피해량은 무관, 피격 "횟수"만 센다. 플레이어당 유효 피격 간격
	-- (TreasureChestConfig.hitIntervalSeconds) 안의 연타는 세지 않는다 - 이게 없으면 한 명이
	-- 0.28초 평타로 혼자 순식간에 깨서 "모두가 받는다"가 무의미해진다(설계의 핵심). 첫 유효
	-- 피격을 낸 순간 보상 대상(chestHitters)에 들어간다 - 강한 사람도 15번, 약한 사람도 15번.
	if entry.isChest then
		if not attackerPlayer then
			return false, damage
		end
		local now = os.clock()
		local last = entry.chestLastHitAt[attackerPlayer]
		if last and now - last < TreasureChestConfig.hitIntervalSeconds then
			return false, damage
		end
		entry.chestLastHitAt[attackerPlayer] = now
		entry.chestHitters[attackerPlayer] = true
		entry.chestHits += 1
		return entry.chestHits >= TreasureChestConfig.requiredHits, damage
	end

	-- 접두사 변종(22-2 [1]) - HP 배율은 "이 인스턴스"의 값이라 공유 data가 아니라 entry에서
	-- 곱한다. 비율 모델(19-4)은 그대로 - 유효 최대체력만 배율만큼 커진다.
	entry.lastDamagedAt = os.clock() -- M1-2: 스폰 지점 정리 보류(맞는 중인 공유 몬스터는 치우지 않는다 - SpawnSites)
	local prefixHpMultiplier = entry.prefix and entry.prefix.hpMultiplier or 1
	-- C1: 기준 스테이지 HP로 환산(옛 = 때린 사람 스테이지 HP - 낮은 스테이지 피해가 높은 몹으로 샜다). 첫 타격 · 타격 수(G1-2 리뷰 2 k 상한)도 MobShare가 쌓는다.
	local effectiveMaxHp = InfiniteStage.getMonsterHp(entry.data.hp, mobRef) * prefixHpMultiplier
	local ratioDealt = effectiveMaxHp > 0 and (damage / effectiveMaxHp) or 0
	return MobShare.applyRatio(entry, attackerPlayer, ratioDealt, os.clock()), damage
end

-- C1: 어그로(쫓기는 중) 참여 - MonsterAI가 추격 틱마다 부른다.
function MonsterState.noteParticipant(model, player, stage)
	local entry = monsters[model]
	if entry and entry.participants and not entry.isChest and not entry.isRescueTarget then
		local now = os.clock()
		local _, wasReset, rose = MobShare.touch(entry, player, stage, now, true) -- 쫓김 = passive(잡는 사람 아님)
		if not MobShare.hasHunters(entry, now) then
			if entry.pullLastAt and now - entry.pullLastAt > CombatConfig.participationWindowSeconds then
				entry.pullStartedAt = nil -- 끊겼다 다시 쫓김 = 새 끌기
			end
			entry.pullStartedAt = entry.pullStartedAt or now -- 결정 6 계측: 아무도 안 때린 채 쫓기는 중
			entry.pullLastAt = now
		end
		if wasReset or rose then
			notifyRatio(model)
		end
		return wasReset
	end
	return false
end

-- C1: 치유 · 보호 · 버프 참여 - target이 참여 중인 잡몹 중 helperPosition에서 CombatConfig.supportRadiusStuds 안인 몹에 helper를 참여시킨다(HealCast가 부른다).
-- 반경(리뷰 1): 파티 버프 · 회복은 거리와 상관없이 파티원 전원에게 걸린다 - 반경이 없으면 맵 반대편 높은 치유사가 낮은 멤버의 몹 기준을 계속 올려 사냥을 막는다.
function MonsterState.noteSupport(helper, helperStage, target, helperPosition)
	if not helperPosition then
		return
	end
	local now = os.clock()
	local radius = CombatConfig.supportRadiusStuds
	for model, entry in pairs(monsters) do
		local root = entry.participants and entry.participants[target] and model.PrimaryPart
		if root and (root.Position - helperPosition).Magnitude <= radius then
			local was = entry.hpRatio
			if MobShare.support(entry, helper, helperStage, target, now) then
				syncHunters(model, entry, now)
				if entry.hpRatio ~= was then
					notifyRatio(model)
				end
			end
		end
	end
end

-- C1: 스테이지를 바꾼 순간(HuntingGround가 InfiniteStage Attribute 변경에서 부른다). 그 사람의 참여 · 기여 · 첫 타격을 지우고 기준을 다시 잡는다.
-- 반환 = 그 사람만 닿아 있어 체력 가득으로 초기화된 모델 목록(호출부가 HP바를 다시 그린다).
function MonsterState.onStageChanged(player, stage)
	local now = os.clock()
	local resetModels = {}
	for model, entry in pairs(monsters) do
		local recorded = entry.partStage and entry.partStage[player]
		if recorded ~= nil and recorded ~= stage then
			if MobShare.purge(entry, player) then
				table.insert(resetModels, model)
			else
				MobShare.refresh(entry, now)
			end
			syncHunters(model, entry, now)
		end
	end
	return resetModels
end

-- C1 후속: 이 타격이 "참여"였는가(잡몹 = 참여자 목록에 있음 · 보스 · 상자 = 항상). 막힌 타격은 파티 활동으로 안 센다.
function MonsterState.isActiveParticipant(model, player)
	local entry = monsters[model]
	if not (entry and entry.participants) or entry.isChest then
		return true
	end
	return entry.participants[player] ~= nil
end

-- C1: 보상 자격(기여 ≥ 10% · 같은 스테이지에서 쌓음 · 지금 스테이지 ≤ 기준). 반환 = bool, 이유.
function MonsterState.isRewardEligible(model, player, stageNow)
	local entry = monsters[model]
	if not (entry and entry.participants) then
		return false, "none"
	end
	return MobShare.eligible(entry, player, stageNow)
end

-- C1 검증 · DevTools: 기준 스테이지(nil = 아무도 참여 안 함)와 참여자 수.
function MonsterState.getRefStage(model)
	local entry = monsters[model]
	if not (entry and entry.participants) then
		return nil, 0
	end
	local count = 0
	for _ in pairs(entry.participants) do
		count += 1
	end
	return entry.refStage, count
end

-- 이 몬스터에 기여한 [Player]=누적비율 테이블(잡몹 전용, 보스는 항상 빈 테이블 - 보스는
-- 애초에 기록하지 않는다). AttackServer의 사망 처리가 이 테이블을 훑어 임계값
-- (CombatConfig.contributionRewardThreshold) 이상인 플레이어 전원에게 각자 보상을 준다.
-- G1-2: 이 사람이 처음 때린 뒤 지금까지(초) - 처치 순간 부르면 처치 시간. 기록이 없으면 nil(보정 없음).
function MonsterState.getKillSecondsFor(model, player)
	local entry = monsters[model]
	local at = entry and entry.firstHitAt and entry.firstHitAt[player]
	if not at then
		return nil
	end
	-- 리뷰 2: 한 대 찔러 두고 나중에 잡아도 걸린 시간이 부풀지 않게 - 때린 횟수 × maxSecondsPerHit 이하
	return math.min(os.clock() - at, (entry.hitCounts[player] or 1) * DropTableData.fairness.maxSecondsPerHit)
end

function MonsterState.getContributors(model)
	local entry = monsters[model]
	return (entry and entry.contributions) or {}
end

-- 플레이어 퇴장 시 호출한다(AttackServer의 PlayerRemoving). 그 플레이어가 아직 살아있는
-- 모든 몬스터의 기여 기록에 남아 있을 수 있으므로 전부 지운다 - 안 지우면 이미 나간
-- Player 인스턴스를 몬스터가 죽을 때까지 계속 들고 있게 된다(MonsterAI.server.lua의
-- releaseChasersOf와 같은 "떠나는 쪽이 자기 흔적을 지운다" 원칙).
function MonsterState.clearPlayerContributions(player)
	for model, entry in pairs(monsters) do
		if entry.participants then
			local had = entry.partStage[player] ~= nil
			if MobShare.purge(entry, player) then -- C1: 잡몹 = 참여 · 스테이지 기록까지(혼자였던 몹은 초기화)
				notifyRatio(model)
			end
			if had then
				syncHunters(model, entry, os.clock())
			end
		end
		if entry.contributions then
			entry.contributions[player] = nil
		end
		if entry.firstHitAt then
			entry.firstHitAt[player] = nil
			entry.hitCounts[player] = nil
		end
		-- 보물상자 피격 기록도 같이 지운다(22-2 [3] 지시 "플레이어 퇴장 시 그 기록도 정리") -
		-- 남겨 두면 파괴 시점에 이미 나간 Player를 보상 대상으로 순회하게 된다.
		if entry.isChest then
			entry.chestLastHitAt[player] = nil
			entry.chestHitters[player] = nil
		end
	end
end

-- C1 후속(결정 2): 잡몹이 주는 피해의 스테이지 = 몹 기준 스테이지(체력과 같은 기준). 아무도 참여 안 했으면 맞는 사람 스테이지(fallback).
-- 스테이지 1 탱커가 높은 몹을 약하게 맞으며 붙잡는 길을 막는다. 보스는 fallback 그대로(보스 data.attack이 이미 최종값).
function MonsterState.getAttackStage(model, fallbackStage)
	local entry = monsters[model]
	if entry and entry.participants then
		MobShare.refresh(entry, os.clock()) -- 리뷰 4: 만료된 옛 높은 기준을 읽지 않게
		if entry.refStage then
			return entry.refStage
		end
	end
	return fallbackStage
end

-- C1 후속(리뷰 1) · C1 마무리: 이 잡몹이 이 사람을 쫓아도 되는가 - 막힐 사람도, 나보다 높은 참여자와 스틸 불가한 사람도 안 쫓는다(판정 = MobShare.canShare 하나).
-- 높은 사람이 초보 곁 몹을 태그하면 기준이 올라 몹이 초보를 기준 공격력으로 즉사시키던 길 · 스테이지 1 탱커가 높은 몹을 붙잡는 길을 막는다.
function MonsterState.canChase(model, player, stage)
	local entry = monsters[model]
	if not (entry and entry.participants) or entry.data.isBoss then
		return true
	end
	local now = os.clock()
	MobShare.refresh(entry, now)
	if MobShare.isBlocked(entry, player, stage, now) then
		return false
	end
	return not MobShare.tooWeakFor(entry, player, stage)
end

-- 스테이지 배율이 적용된 공격력(19-4, InfiniteStage 직접 호출로 교체 - 예전
-- setStage/entry.stage는 완전히 제거했다). 보스는 data.attack이 이미 최종값이라 그대로
-- 돌려준다(BossRules.buildInstanceData 참고) - 잡몹은 targetStage로 매 호출마다 새로
-- 계산한다(같은 몬스터를 서로 다른 stage의 플레이어가 때려도 각자 맞는 값이 나온다).
function MonsterState.getAttackFor(model, targetStage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.attack
	end
	return InfiniteStage.getMonsterAttack(entry.data.attack, targetStage)
end

function MonsterState.getGoldDropFor(model, stage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.goldDrop
	end
	return InfiniteStage.getGoldReward(entry.data.goldDrop, stage) * MonsterPrefixData.getRewardMultiplier(entry.prefix)
end

-- 이 잡몹 1마리가 강화 재료(28-1 S04)에서 "몇 마리분"인가 = 골드 식에서 스테이지 지수 성장(k^(S−1))만 뺀 배율 = tier r^p × 접두사 보상 배율.
-- getGoldDropFor와 같은 두 인자(data.rewardRatio · MonsterData.fairnessExponent의 r^p, entry.prefix)를 쓴다 - 골드와 시간당 기대값이 같다.
function MonsterState.getKillUnits(model)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	return (entry.data.rewardRatio ^ MonsterData.fairnessExponent) * MonsterPrefixData.getRewardMultiplier(entry.prefix)
end

function MonsterState.getExpRewardFor(model, stage)
	local entry = monsters[model]
	if not entry then
		return 0
	end
	if entry.data.isBoss then
		return entry.data.expReward
	end
	return InfiniteStage.getExpReward(entry.data.expReward, stage) * MonsterPrefixData.getRewardMultiplier(entry.prefix)
end

function MonsterState.getSpawnPosition(model)
	local entry = monsters[model]
	return entry and entry.spawnPosition
end

-- M1-2: 마지막으로 맞은 시각(os.clock · 잡몹 - 없으면 nil)
function MonsterState.getLastDamagedAt(model)
	local entry = monsters[model]
	return entry and entry.lastDamagedAt
end

function MonsterState.getAiState(model)
	local entry = monsters[model]
	return entry and entry.aiState
end

function MonsterState.setAiState(model, value)
	local entry = monsters[model]
	if entry then
		entry.aiState = value
	end
end

function MonsterState.getAiTarget(model)
	local entry = monsters[model]
	return entry and entry.aiTarget
end

function MonsterState.setAiTarget(model, player)
	local entry = monsters[model]
	if entry then
		entry.aiTarget = player
	end
end

function MonsterState.getLastAttackTick(model)
	local entry = monsters[model]
	return entry and entry.lastAttackTick
end

function MonsterState.setLastAttackTick(model, value)
	local entry = monsters[model]
	if entry then
		entry.lastAttackTick = value
	end
end

-- 처치 경합 가드(15-1 검증 중 재현 - 연타로 두 AttackRequest가 거의 동시에 같은 처치
-- 직전 몬스터를 때리면, 첫 요청이 ImmediateSave.request(DataStore 호출로 실제 yield한다)에서
-- 멈춘 사이 두 번째 요청이 똑같이 "내가 죽였다"고 판단해 골드·경험치·드랍을 이중 지급하고,
-- 뒤이어 이미 지워진 MonsterState를 다시 despawn하려다 크래시했다(몬스터 사망은 로그에
-- 두 번 찍히고 despawn만 두 번째에서 nil 참조로 죽는 형태로 재현됨). 이 함수는 "처치를
-- 확정하는" 시점(AttackServer의 newHp<=0 분기 맨 앞)에서 단 한 번만 호출해야 한다 - 이후
-- 어떤 yield(ImmediateSave 등)가 끼어들어도, 두 번째 호출은 이미 clear된 entry가 아니라
-- 여기서 곧바로 false를 받아 조용히 물러난다(entry 자체를 즉시 지우지는 않는다 - despawn이
-- 뒤이어 data·spawnPosition을 여전히 읽어야 하므로, "죽었다는 사실"만 이 한 줄로 원자적으로
-- 표시한다). check와 set 사이에 yield가 없어야 이 보장이 성립하므로 이 함수 자체는 절대
-- yield하지 않는다.
function MonsterState.tryClaimDeath(model)
	local entry = monsters[model]
	if not entry or entry.claimed then
		return false
	end
	entry.claimed = true
	return true
end

function MonsterState.clear(model)
	monsters[model] = nil
end

-- 사거리 판정 등 전체 몬스터를 훑어야 하는 로직용. 순서는 보장하지 않는다.
function MonsterState.getAllModels()
	local models = {}
	for model in pairs(monsters) do
		table.insert(models, model)
	end
	return models
end

return MonsterState
