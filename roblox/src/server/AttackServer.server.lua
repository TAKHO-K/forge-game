-- 서버 권위 공격 판정. 클라이언트는 "공격하겠다"는 의사 + 조준점(aimPoint, 16-7)만
-- 보낸다 - 사거리 검증·대상 선정·쿨다운 관리·데미지 계산은 전부 여기서만 한다. aimPoint는
-- "어느 방향으로 대상을 고를지"에만 쓰이는 힌트일 뿐(아래 AimPicker.pick), 사거리·데미지·
-- 최종 대상 확정은 클라이언트 값을 그대로 믿지 않고 항상 서버가 다시 계산한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local Loot = require(ReplicatedStorage.Shared.Loot)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)

local attackRequest = Instance.new("RemoteEvent")
attackRequest.Name = "AttackRequest"
attackRequest.Parent = ReplicatedStorage

local attackResult = Instance.new("RemoteEvent")
attackResult.Name = "AttackResult"
attackResult.Parent = ReplicatedStorage

-- 처치 순간 골드 팝업(10-1)용. 골드 자체는 PlayerProfile.addGold가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 "방금 얼마 벌었다"는 일회성 연출 신호만 보낸다.
local goldGained = Instance.new("RemoteEvent")
goldGained.Name = "GoldGained"
goldGained.Parent = ReplicatedStorage

-- 레벨업 알림(13-2)용. characterExp 자체는 PlayerProfile.addCharacterExp가 Attribute로 이미
-- 동기화한다 - 이 이벤트는 레벨이 실제로 오른 순간에만 쏘는 일회성 연출 신호다(매 처치마다
-- 쏘지 않는다 - goldGained와 다르게 레벨업은 드물다).
local levelUp = Instance.new("RemoteEvent")
levelUp.Name = "LevelUp"
levelUp.Parent = ReplicatedStorage

local lastAttackTick = {} -- [Player] = os.clock() 시각

-- 3타 강타(16-7, 웹 main.js comboCount/comboResetWindow와 동일 값 CombatConfig 참고).
-- 헛스윙도 콤보에 들어간다 - 웹 performAttack()이 대상 유무와 무관하게 매 공격 입력마다
-- comboCount를 올리는 것과 같다.
local comboCounts = {} -- [Player] = number
local lastComboAttackTick = {} -- [Player] = os.clock() 시각

local comboUpdate = Instance.new("RemoteEvent")
comboUpdate.Name = "ComboUpdate"
comboUpdate.Parent = ReplicatedStorage

-- 구역 밖 공격 차단 안내(19-4 [4]-나). 조용히 씹으면 버그로 오해한다는 지시 - 스팸
-- 방지로 플레이어당 3초에 한 번만 띄운다(입구에 서서 연타해도 토스트가 겹쳐 뜨지 않게).
local zoneBlockedNotice = Instance.new("RemoteEvent")
zoneBlockedNotice.Name = "ZoneBlockedNotice"
zoneBlockedNotice.Parent = ReplicatedStorage

local ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS = 3
local lastZoneBlockedNoticeAt = {} -- [Player] = os.clock() 시각

local function notifyZoneBlocked(player)
	local now = os.clock()
	local last = lastZoneBlockedNoticeAt[player]
	if last and now - last < ZONE_BLOCKED_NOTICE_THROTTLE_SECONDS then
		return
	end
	lastZoneBlockedNoticeAt[player] = now
	zoneBlockedNotice:FireClient(player, "구역 안으로 들어가야 공격할 수 있습니다")
end

-- 처치 보상 지급 1인분(19-4 [2]) - 보스(단독 수령)와 잡몹(기여자 각자)이 똑같이 이 함수
-- 하나로 받는다. dropStage는 "그 스테이지에서 사냥했다"는 경제적 맥락(Loot.getSellPrice가
-- 나중에 쓴다, Loot.lua 주석 참고)이라 보스는 자기 스테이지(monsterData.stageNumber,
-- 고정값), 잡몹은 이 recipient 본인의 "지금" 무한 스테이지를 쓴다 - 스테이지 100인
-- 사람과 10인 사람이 같은 몬스터를 잡아도 서로 다른 itemLevel·dropStage를 받는 지점이
-- 바로 여기다.
local function grantKillReward(recipient, target, monsterData, deathPosition)
	local isBoss = monsterData.isBoss
	local isSparkle = MonsterState.isSparkle(target)
	local recipientStage = PlayerProfile.getInfiniteStage(recipient) or 1
	local dropStage = isBoss and monsterData.stageNumber or recipientStage

	-- 반짝이는 골드가 오히려 준다(19-4 [6], PRD 8.0-5 "골드는 적게(보상이 아이템이므로)").
	local goldDrop = MonsterState.getGoldDropFor(target, recipientStage)
	if isSparkle then
		goldDrop = math.floor(goldDrop * RareMonsterConfig.goldMultiplier)
	end
	PlayerProfile.addGold(recipient, goldDrop)
	goldGained:FireClient(recipient, goldDrop)

	-- 경험치 지급(13-2) - 레벨업이 일어났으면 그 순간에만 알림을 쏜다. 아이템 레벨 각인
	-- (아래)보다 먼저 지급해야 이번 처치로 오른 레벨이 드랍에 반영된다.
	local expReward = MonsterState.getExpRewardFor(target, recipientStage)
	local oldLevel, newLevel = PlayerProfile.addCharacterExp(recipient, expReward)
	if newLevel and newLevel ~= oldLevel then
		levelUp:FireClient(recipient, newLevel)
	end

	-- 갑옷 드랍 판정(12-1 [2]) - 보스는 확정 드랍(15-1), 반짝이는 확정 최고 등급 드랍
	-- (19-4 [6]), 그 외 잡몹은 자기 tier의 등급 확률표. 기여자마다 이 함수가 각자 따로
	-- 불리므로(19-4 [2]) 반짝이를 여럿이 같이 잡으면 전원이 각자 확정 드랍을 받는다 -
	-- "달려가서 참전하는 게 모두에게 이득"이라는 [2]의 취지와 반짝이의 "발견의 재미"가
	-- 자연스럽게 겹친다. 14-1부터 인벤토리에 바로 들어가지 않는다 - 바닥에 떨어뜨리고
	-- (ItemDropSpawner), owner를 recipient로 못박아 그 사람만 주울 수 있다.
	local armorDrop
	if isBoss then
		armorDrop = Loot.rollBossArmorDrop(dropStage, newLevel or oldLevel)
	elseif isSparkle then
		armorDrop = Loot.rollSparkleArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
	else
		armorDrop = Loot.rollArmorDrop(dropStage, newLevel or oldLevel, monsterData.tierIndex)
	end
	if armorDrop then
		ItemDropSpawner.spawn(armorDrop, deathPosition, recipient)
	end
end

attackRequest.OnServerEvent:Connect(function(player, aimPoint)
	-- 프로필 로드가 아직 안 끝난 접속 직후, 혹은 클래스를 아직 안 고른 상태에서 공격이
	-- 들어올 수 있다 - 공격력·쿨다운 둘 다 클래스가 있어야 계산할 수 있으니 헛스윙으로
	-- 처리한다(10-3 [3] - 클래스 배율이 실제로 평타에 반영되는 첫 지점).
	local weapon = PlayerProfile.getWeapon(player)
	local classId = PlayerProfile.getClassId(player)
	if not weapon or not classId then
		return
	end

	local now = os.clock()
	local last = lastAttackTick[player]
	-- 신발 공속 보너스(16-6) - 미착용이면 PlayerProfile.getSpeedPercentBonus가 0을 돌려줘
	-- 기존과 똑같이 계산된다.
	local cooldown = PlayerCombat.getAttackCooldown(classId, PlayerProfile.getSpeedPercentBonus(player))
	if last and now - last < cooldown then
		return -- 쿨다운이 안 지났다 - 조용히 무시
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	lastAttackTick[player] = now -- 헛스윙이어도 쿨다운은 소모한다
	-- 19-1: 공격 시도(헛스윙 포함)도 "전투 중"이다 - 자동회복이 싸우는 동안엔 켜지지
	-- 않아야 한다(PlayerRegen.server.lua 주석 참고).
	PlayerState.setLastCombatActionAt(player, now)

	-- 3타 강타 콤보 카운터 - 헛스윙도 포함해 이 시점에서 갱신한다(웹과 동일 지점).
	local lastCombo = lastComboAttackTick[player]
	if not lastCombo or now - lastCombo > CombatConfig.comboResetWindowSeconds then
		comboCounts[player] = 0
	end
	comboCounts[player] += 1
	lastComboAttackTick[player] = now
	local isComboHit = comboCounts[player] % CombatConfig.comboHitEvery == 0
	comboUpdate:FireClient(player, comboCounts[player], isComboHit)

	-- aimPoint는 클릭·탭한 지점(AttackInput.client.lua) - 서버 검증: Vector3가 아니면
	-- 무시한다(지시 - "클라가 보낸 방향을 그대로 믿으면 안 된다"). 방향이 없거나 이상한
	-- 값이면 AimPicker가 사거리 안 최근접으로 대체하므로 안전하게 실패한다. 사거리·데미지는
	-- 이 값과 무관하게 아래에서 항상 서버가 다시 계산한다.
	local safeAimPoint = typeof(aimPoint) == "Vector3" and aimPoint or nil
	local target = AimPicker.pick(rootPart.Position, safeAimPoint, PlayerCombat.getAttackRange(classId), MonsterState.getAllModels())
	if not target then
		return -- 사거리 안에 몬스터가 없다 - 헛스윙
	end

	-- 구역 밖 공격 차단(19-4 [4]-나) - 담장(HuntingGround.server.lua)이 1차 방어, 이건
	-- 뚫렸을 때의 2차 방어이자 "입구에 서서 안쪽을 쏘는" 행위 자체를 막는 장치다. 클라이언트
	-- 좌표가 아니라 서버가 들고 있는 rootPart.Position으로 판정한다.
	local targetZoneKey = MonsterState.getZoneKey(target)
	if not ZoneBounds.isInside(rootPart.Position, targetZoneKey) then
		notifyZoneBlocked(player)
		return
	end

	-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율 × 캐릭터 레벨계수(10-2 [1],
	-- 10-3 [3], 13-2에서 레벨계수가 들어갔다) × (1+장갑 공격력%, 16-6) × 3타 강타 배율(16-7,
	-- 웹 main.js "attack = getPlayerAttack() * (isComboHit ? comboHitMultiplier : 1)"과 같은
	-- 순서 - 치명타 판정보다 먼저 곱한다). 배율이 곱해지는 지점은 PlayerCombat 하나뿐이다.
	-- 치명타(10-4)는 이 base를 calcDamage에 넘겨서 판정한다 - 판정도 서버 여기 한 곳뿐이다.
	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local base = PlayerCombat.getAttack(weapon, classId, characterLevel, PlayerProfile.getAttackPercentBonus(player))
	if isComboHit then
		base *= CombatConfig.comboHitMultiplier
	end
	local damage, isCrit = PlayerCombat.calcDamage(base, classId)

	-- 19-4(C안) - 잡몹은 공유 HP(비율)라 "이 공격자의 stage 기준" 유효 최대체력으로 나눈
	-- 비율만큼만 깎인다(MonsterState.applyDamage 참고). 보스는 기존 그대로 절대값 차감.
	local attackerStage = PlayerProfile.getInfiniteStage(player) or 1
	local isDead = MonsterState.applyDamage(target, damage, attackerStage, player)
	MonsterSpawner.updateHpLabel(target)

	-- died(14-2)를 같이 보낸다 - 클라이언트가 사망 연출(HitEffects.playDeath)을 정확히
	-- 이 타격에서만 재생하려면 "이 타격으로 죽었는가"를 알아야 한다. isComboHit(16-7)은
	-- 클라이언트가 강타 전용 피드백(히트스톱·카메라 흔들림·확대된 스윙)을 이 타격에서만
	-- 재생하도록 같이 보낸다. damage는 이 공격자 본인 기준 절대값 그대로 보여준다(19-4 [1] -
	-- "옆 사람과 숫자가 다른 건 이미 기본값"이라 데미지 숫자는 바꾸지 않는다, HP바만 비율).
	attackResult:FireClient(player, target, damage, isCrit, isDead, isComboHit)

	if isDead then
		-- 처치 경합 가드(15-1 검증 중 재현) - 연타로 두 AttackRequest가 같은 처치 직전
		-- 몬스터를 거의 동시에 때리면, 뒤 이은 ImmediateSave.request(DataStore 호출로 실제
		-- yield한다)가 끝나기 전에 두 번째 요청이 여기 도달해 골드·경험치·드랍을 이중
		-- 지급하는 경합이 실제로 재현됐다. MonsterState.tryClaimDeath는 확인과 표시를
		-- 한 번에 처리해(그 사이 yield 없음) 오직 첫 번째 요청만 통과시킨다 - 뒤따르는
		-- 요청은 조용히 물러난다(이미 처리된 처치이므로 보상도, 로그도 다시 내지 않는다).
		if not MonsterState.tryClaimDeath(target) then
			return
		end

		-- despawn이 MonsterState.clear를 즉시 호출해 데이터(기여 기록 포함)를 지우므로,
		-- 그 전에 전부 읽는다.
		local monsterData = MonsterState.getData(target)
		local isBoss = monsterData.isBoss
		local deathPosition = target.PrimaryPart.Position

		if isBoss then
			-- 보스는 개인 인스턴스라 지금까지처럼 처치한 플레이어 1인이 그대로 가져간다
			-- (19-4 [3] 지시 - "역할이 다르므로 구조가 달라도 된다", 건드리지 않는다).
			grantKillReward(player, target, monsterData, deathPosition)

			-- 보스 처치 기록(15-1) - 이 스테이지 이상으로 이동을 막던 게이트(StageServer)가
			-- 이제부터 풀린다. infiniteBest와 같은 "다시 오르면 그만이 아닌 실제 성취"라
			-- 즉시저장한다.
			PlayerProfile.setBossCleared(player, monsterData.stageNumber)
			ImmediateSave.request(player)
			BossEncounter.clearFor(player)
			print(("[forge-game] 보스 처치: %s - 스테이지 %d"):format(player.Name, monsterData.stageNumber))
		else
			-- 공유 잡몹(19-4 [2], PRD 20.13이 미결로 남긴 드랍 정책을 여기서 확정 - C안).
			-- 막타 1인이 아니라 기여 비율(CombatConfig.contributionRewardThreshold) 이상인
			-- 플레이어 "전원"이 각자 온전한 보상을 받는다 - 나눠 갖지 않는다. contributor.Parent
			-- 검사는 방어적 가드다(PlayerRemoving에서 clearPlayerContributions가 이미 지우므로
			-- 정상 경로에선 나간 플레이어가 여기 남아있을 수 없지만, 같은 프레임 안의 순서
			-- 문제까지 이중으로 막는다).
			for contributor, ratio in pairs(MonsterState.getContributors(target)) do
				if ratio >= CombatConfig.contributionRewardThreshold and contributor.Parent then
					grantKillReward(contributor, target, monsterData, deathPosition)
				end
			end
		end

		MonsterSpawner.despawn(target)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTick[player] = nil
	comboCounts[player] = nil
	lastComboAttackTick[player] = nil
	lastZoneBlockedNoticeAt[player] = nil
	-- 아직 살아있는 몬스터의 기여 기록에 이 플레이어가 남아있으면(퇴장 시점에 전투 중이었던
	-- 경우) 몬스터가 죽을 때까지 계속 남는다 - 떠나는 쪽이 자기 흔적을 지운다(MonsterAI.
	-- server.lua의 releaseChasersOf와 같은 원칙, 19-4 지시 - 이전 nil 비교 사고 반복 금지).
	MonsterState.clearPlayerContributions(player)
end)
