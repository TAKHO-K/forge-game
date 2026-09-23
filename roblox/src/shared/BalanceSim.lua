-- 밸런스 실측 시뮬레이터(19-3a, 20-7에서 전면 확장). 실제 클릭·타이머 대기로 재는 대신, 이 게임이
-- 이미 갖고 있는 공식(PlayerCombat·Loot·CharacterLevel·InfiniteStage·CombatConfig·SkillData)을
-- 그대로 재사용해 "이 조건이면 생존 타수/60초 총딜/처치 시간이 얼마인가"를 계산한다 - 도구
-- 호출 왕복 지연 때문에 수동 클릭으로는 처치 시간을 잴 수 없다는 문제를 formula-level 계산으로
-- 우회한다.
--
-- 이 모듈은 순수 함수만 담는다(플레이어·저장·RemoteEvent를 모른다) - DevTools.server.lua가
-- 실제 플레이어 조건을 읽어 이 함수들에 넘기고, Studio Edit 모드에서 직접 호출해도(플레이어
-- 없이) 똑같이 동작한다. 스킬 8종의 계수를 조정할 때도 이 모듈 하나만 계속 재사용한다
-- (19-3a 지시 - "이 시뮬레이터가 앞으로 모든 밸런스 작업의 기준이 된다").
--
-- 20-7: 옛 simulateRotation(스킬을 "쿨다운당 계수×atk" 근사로만 더하던 헬퍼, 실제 어느
-- 스킬도 배선돼 있지 않았다)을 simulateCombat(이벤트 기반 전투 시뮬레이션)으로 교체했다.
-- 스킬 정의는 여기 박지 않고 SkillData.lua(단일 출처)를 그대로 읽는다 - 계수·쿨다운·틱 수·
-- 지속시간이 바뀌면 이 시뮬레이터 결과가 자동으로 따라온다. 실제 서버 경로와 맞춘 항목:
--   · 평타 쿨다운은 "요청 시점의 버프 상태"로 판정(AttackServer가 BuffState.getValue를 매
--     요청마다 읽는 것과 같다 - 속사 만료 직후의 첫 평타는 만료 후 쿨다운을 쓴다)
--   · 3타 강타는 평균 배율이 아니라 실제 카운터(3번째마다 1.8배, 2초 공백 시 리셋)
--   · 치명타는 기대값 배율(확률 롤을 매번 시뮬레이션하지 않는다) - 단, 쌍검 Q 확정 치명타 창과
--     활 백스텝샷의 치확 +30%p는 그 타격의 기대값에 정확히 반영한다
--   · 대검 E/쌍검 E 채널링 틱은 서버(SkillServer castCircleChannel/castSingleChannel)와 같은
--     간격·분할 계수. 채널링 중엔 평타가 막힌다(21-1 [1]-C - PlayerState.isChanneling으로
--     AttackServer가 거부, PRD 4.3 "채널링 3초는 평타 시간에서 뺀다"와 일치) - 20-7까지는
--     막는 코드가 없어 opts.channelBlocksAutoAttack 기본값이 false였다. 이제 기본 true이고,
--     false는 "차단 전 코드"와 비교할 때만 쓴다
--   · 원거리(활·힐러)는 발사 예비동작(AttackMotionData.releaseT)+비행시간(ProjectileConfig)
--     뒤에 피해가 들어간다 - 측정 창(60초) 안에 도달하지 못한 발은 손실
--   · 활 꽂히는 화살: 속사 중 "쏜" 평타가 명중하면 0.8초 뒤 개별 폭발, 몬스터당 4개 상한
--     (초과분은 가장 오래된 것이 즉시 폭발 - StuckArrowState와 같은 규칙)
--   · 활 백스텝샷: 5충전, 충전이 남은 평타에 +0.5×atk(3타 강타 배율 밖에서 더한다 - AttackServer의
--     base += coefficient×atk 순서 그대로) + 치확 +30%p
--   · 힐러 딜링모드: base(3타 강타 포함)에 SkillData.healer.E.attackMultiplier배(P2 F3 전 3.13), 치명타 전
--   · 쌍검 난무: 시전 시점 대상 고정, 대상이 죽으면 남은 틱 손실, 1틱째만 확정 치명타(Q 활성 시)
--   · 회전 지연(AttackInput.client.lua 720도/초·15도 스냅): 대상을 바꿀 때만 발생하므로 단일
--     더미 60초 측정엔 0이고, 처치 시간 측정에서 opts.turnDelaySeconds로 "새 대상으로 돌아서는"
--     비용을 더한다

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local ProjectileConfig = require(ReplicatedStorage.Shared.data.ProjectileConfig)
local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Loot = require(ReplicatedStorage.Shared.Loot)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Option = require(ReplicatedStorage.Shared.Option)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local BalanceSim = {}

-- gearSpec = nil(미착용) 또는 { grade = "normal", itemLevel = 100 }. Loot.getArmorDefense류가
-- 읽는 필드만 채운다 - 실제 드랍(Loot.rollArmorDrop)이 아니라 합성 아이템이므로 locked=true로
-- 둔다(테스트 중 실수로 판매되는 사고 방지, 어차피 세션 한정이라 인벤토리에 들어가지도 않는다).
local function buildItem(part, gearSpec)
	if not gearSpec then
		return nil
	end
	return {
		grade = gearSpec.grade,
		part = part,
		dropStage = gearSpec.dropStage or 1,
		itemLevel = gearSpec.itemLevel,
		tierIndex = gearSpec.tierIndex or 1,
		locked = true,
	}
end

-- 옵션 보너스 4축(26-2, PRD 20.67 [14] 3단계 "BalanceSim.gemBonusesFor → 옵션 전체") - 장비
-- 3부위(armorItem·glovesItem·shoesItem) + 보석 5개(gems)를 한 목록으로 모아 Option.
-- sumAxisBonus(=Option.valueOf+Option.sumWithCap 합성, PlayerProfile.lua의 buildOptionSources와
-- 같은 모양)로 계산한다 - 여기서 새 계산식을 만들지 않는다. 전부 nil/빈 슬롯이면 전부 0
-- (보석·옵션 미장착과 계산이 완전히 같다).
local function gemBonusesFor(classId, armorItem, glovesItem, shoesItem, gems)
	local sources = {}
	for _, item in ipairs({ armorItem, glovesItem, shoesItem }) do
		if item then
			table.insert(sources, item)
		end
	end
	if gems then
		for slot = 1, Gem.slotCount do
			if Gem.isFilled(gems, slot) then
				table.insert(sources, gems[slot])
			end
		end
	end
	return {
		attackPercent = Option.sumAxisBonus(sources, "attackPercent", classId),
		speedPercent = Option.sumAxisBonus(sources, "speedPercent", classId),
		defensePercent = Option.sumAxisBonus(sources, "defensePercent", classId),
		maxHpPercent = Option.sumAxisBonus(sources, "maxHpPercent", classId),
	}
end

-- buildLoadout(합성 아이템)과 buildLoadoutFromEquipment(실제 착용 아이템) 둘 다 여기로
-- 모인다 - "장비 3부위 테이블에서 loadout을 뽑는다"는 계산 자체는 아이템이 합성이든
-- 실제 드랍이든 완전히 같다(Loot.get*류 함수가 이미 item 테이블 형태만 본다). gems(23-4
-- 신설, weapon.gems 형태 그대로 - 5칸 배열, 빈 슬롯은 false)는 선택 인자다 - PlayerProfile.
-- getAttackPercentBonus/getSpeedPercentBonus/getDefensePercentBonus/refreshMaxHp가 실제
-- 전투 경로에서 장갑·신발·갑옷 보너스에 더하는 자리에 똑같이 더한다(단일 계산 경로 -
-- 여기서 새 공식을 만들지 않고 PlayerProfile과 같은 지점에 합류시킨다).
local function buildLoadoutCore(classId, level, weaponLevel, weaponGrade, armorItem, glovesItem, shoesItem, gems)
	local class = ClassData.classes[classId]
	assert(class, "알 수 없는 classId: " .. tostring(classId))

	local weapon = { id = WeaponData.starterId, level = weaponLevel or 0, grade = weaponGrade or 0 }
	local gemBonus = gemBonusesFor(classId, armorItem, glovesItem, shoesItem, gems)
	local attackPercentBonus = Loot.getGlovesAttackPercent(glovesItem) + gemBonus.attackPercent
	local speedPercentBonus = Loot.getShoesSpeedPercent(shoesItem) + gemBonus.speedPercent
	local armorBonus = Loot.getArmorDefense(armorItem)
	local maxHpBonus = Loot.getMaxHpBonus(armorItem)

	return {
		classId = classId,
		level = level,
		class = class,
		atk = PlayerCombat.getAttack(weapon, classId, level, attackPercentBonus),
		defense = PlayerCombat.getDefense(classId, armorBonus, gemBonus.defensePercent),
		maxHp = (CombatConfig.playerMaxHp + maxHpBonus) * (1 + gemBonus.maxHpPercent),
		speedPercentBonus = speedPercentBonus,
		weaponLevel = weapon.level, -- P2.5a: 딜링모드 투자 기울기(PlayerCombat.getInvestmentScale)가 읽는다
		attackPercentBonus = attackPercentBonus,
		attackCooldown = PlayerCombat.getAttackCooldown(classId, speedPercentBonus),
		attackRange = PlayerCombat.getAttackRange(classId),
		critRate = class.critRate,
		critDmg = class.critDmg,
		-- 치명타 평균 배율 - calcDamage의 기대값(확률 롤을 매번 시뮬레이션하지 않고 기대치로 계산).
		critMultAvg = 1 + class.critRate * (class.critDmg - 1),
		-- 3타 강타 평균 배율(CombatConfig.comboHitEvery/comboHitMultiplier) - 쉬지 않고 계속
		-- 공격한다고 가정할 때(콤보 리셋 없음) N번에 한 번 1.8배가 나오는 것의 평균.
		comboMultAvg = 1 + (CombatConfig.comboHitMultiplier - 1) / CombatConfig.comboHitEvery,
	}
end

-- spec = { classId, level, weaponLevel = 0, weaponGrade = 0(0~6), gear = { armor=gearSpec,
-- gloves=gearSpec, shoes=gearSpec } }
-- gearSpec = { grade, itemLevel } - 실측 시나리오를 가정해 만든 합성 아이템. 실제 드랍
-- 확률(ArmorData.dropChance 등)은 거치지 않는다(이 시뮬레이터는 "이 조건이면"을 계산하는
-- 도구이지 드랍을 재현하는 도구가 아니다).
function BalanceSim.buildLoadout(spec)
	local gear = spec.gear or {}
	return buildLoadoutCore(
		spec.classId, spec.level, spec.weaponLevel, spec.weaponGrade,
		buildItem("armor", gear.armor), buildItem("gloves", gear.gloves), buildItem("shoes", gear.shoes),
		spec.gems
	)
end

-- 실제 플레이어의 현재 착용 아이템(PlayerProfile.getEquipped가 돌려주는 실제 item 테이블,
-- 없으면 nil)으로 loadout을 만든다. DevTools의 "/gg measure"가 쓴다 - 합성 조건이 아니라
-- 지금 이 플레이어가 실제로 들고 있는 장비 그대로 잰다. gems(23-4 신설) - weapon.gems를
-- 그대로 넘기면 위력·신속·방어·건강 네 축 보너스가 전부 반영된다(gemBonusesFor).
function BalanceSim.buildLoadoutFromEquipment(classId, level, weaponLevel, weaponGrade, equipment, gems)
	equipment = equipment or {}
	return buildLoadoutCore(classId, level, weaponLevel, weaponGrade, equipment.armor, equipment.gloves, equipment.shoes, gems)
end

-- 생존 타수. CombatConfig.damageReductionAlpha 유도식(hits = maxHp×(D+αA)/(αA²))과 완전히
-- 같은 식이다 - 그 상수를 역산할 때 쓴 공식을 그대로 재사용해 이 도구와 그 상수가 항상
-- 같은 정의를 쓰게 한다. incomingDamageMultiplier(선택, 기본 1) - 대검 E 채널링 중 "받는
-- 피해 50% 감소"(PlayerState.getIncomingDamageMultiplier)를 넣어 볼 때 쓴다.
-- S21-0 A6(docs/stage-scaling-audit.md Fable 목록 5번, 버그): 예전 식 `alpha*A*A/(D+alpha*A)`은
-- A²를 직접 계산해 A 자신보다 훨씬 일찍(스테이지 ≈2,448) 오버플로했다(A > sqrt(1.7977e308))
-- - 실제 게임(server/PlayerDamage.lua computeHitDamage)은 애초에 제곱을 만들지 않는다.
-- 수학적으로 같은 식을 PlayerDamage와 같은 연산 순서(reduction 먼저, 그다음 A에 곱)로 바꿔
-- 이 측정 도구도 게임과 같은 붕괴 지점(§1-2, 스테이지 ≈4,871부터)을 갖게 한다.
function BalanceSim.getSurviveHits(loadout, monsterAttack, incomingDamageMultiplier)
	local D, A, alpha = loadout.defense, monsterAttack, CombatConfig.damageReductionAlpha
	local reduction = D / (D + alpha * A)
	local dmgPerHit = A * (1 - reduction) * (incomingDamageMultiplier or 1)
	return loadout.maxHp / dmgPerHit, dmgPerHit
end

-- tier 몬스터 1마리의 스테이지 적용 평타(InfiniteStage.getMonsterAttack 재사용). tierKey
-- 기본값 tier1 - CombatConfig.damageReductionAlpha 앵커가 쓰는 것과 같은 관례.
function BalanceSim.getMonsterAttack(stage, tierKey)
	local tierData = MonsterData[tierKey or "tier1"]
	return InfiniteStage.getMonsterAttack(tierData.attack, stage)
end

-- tier 몬스터 1마리의 스테이지 적용 최대 HP(MonsterState.applyDamage가 "attackerStage 기준
-- 유효 최대체력"으로 쓰는 것과 같은 값 - InfiniteStage.getMonsterHp 재사용).
function BalanceSim.getMonsterHp(stage, tierKey)
	local tierData = MonsterData[tierKey or "tier1"]
	return InfiniteStage.getMonsterHp(tierData.hp, stage)
end

-- 스킬 없는 순수 평타만의 durationSeconds초 총딜 - 평균 배율 근사(19-3a 원본 그대로). 빠른
-- 어림용이다 - 정확한 값(원거리 비행시간·콤보 카운터 반영)은 simulateCombat(useSkills=false).
function BalanceSim.simulateAutoAttack(loadout, durationSeconds)
	local hits = durationSeconds / loadout.attackCooldown
	local avgHit = loadout.atk * loadout.comboMultAvg * loadout.critMultAvg
	return { hits = hits, totalDamage = hits * avgHit, avgHit = avgHit }
end

-- ═══ 이벤트 기반 전투 시뮬레이션(20-7) ═══
--
-- opts:
--   durationSeconds          측정 창(기본 60)
--   useSkills                Q/E를 쿨다운마다 사용(기본 true). false면 순수 평타(힐러 딜링모드도 꺼진다)
--   targetCount              동시에 사거리 안에 있는 대상 수(기본 1). 평타·난무는 항상 1마리만,
--                            대검 Q(선분)/E(원형)만 이 수만큼 동시에 맞힌다
--   lineMaxTargets           대검 Q 선분 판정이 한 번에 맞힐 수 있는 상한(기본 targetCount)
--   targetHp                 nil이면 무한 HP 더미(총딜 측정). 숫자면 1번 대상이 그 HP를 가진
--                            실제 몬스터 - 죽는 순간 멈추고 killTime을 돌려준다(처치 시간 측정)
--   targetDistanceStuds      원거리 비행 거리(기본 = 몬스터 평타 사거리 - 몬스터가 여기까지
--                            다가와 멈춘다, MonsterAI tryAttack)
--   turnDelaySeconds         첫 대상을 향해 돌아서는 시간(기본 0). 처치 시간 측정에서만 의미가 있다
--   channelBlocksAutoAttack  채널링 중 평타 차단(기본 true=21-1 이후 코드 동작, false는 차단 전 비교용)
--
-- 반환: { totalDamage, autoDamage, skillDamage = {이름->값}, skillDamageTotal, autoHits,
--         killTime(targetHp가 있을 때만), casts = {이름->횟수} }
function BalanceSim.simulateCombat(loadout, opts)
	opts = opts or {}
	local duration = opts.durationSeconds or 60
	local useSkills = opts.useSkills ~= false
	local targetCount = math.max(opts.targetCount or 1, 1)
	local lineMaxTargets = math.min(opts.lineMaxTargets or targetCount, targetCount)
	local targetDistance = opts.targetDistanceStuds or MonsterData.tier1.attackRangeStuds
	local channelBlocksAutoAttack = opts.channelBlocksAutoAttack ~= false

	local classId = loadout.classId
	local class = loadout.class
	local atk = loadout.atk
	local skills = SkillData[classId] or {}
	local projectileKind = ProjectileConfig.kindByClass[classId]
	local motion = AttackMotionData[classId]
	local releaseDelay = (motion and motion.releaseT) and motion.releaseT * motion.totalDurationSeconds or 0
	local travelTime = projectileKind and (targetDistance / ProjectileConfig.speedStudsPerSec[projectileKind]) or 0

	-- 대상: [1]이 평타·난무 대상. targetHp가 있으면 [1]만 유한.
	local targets = {}
	for i = 1, targetCount do
		targets[i] = { hp = (i == 1 and opts.targetHp) or math.huge, alive = true, stuckArrows = {} }
	end

	local result = {
		totalDamage = 0,
		autoDamage = 0,
		skillDamage = {},
		skillDamageTotal = 0,
		autoHits = 0,
		killTime = nil,
		casts = {},
	}

	local t = 0
	local finished = false

	local function critMultFor(critRateBonus)
		local rate = math.min(class.critRate + (critRateBonus or 0), 1)
		return 1 + rate * (class.critDmg - 1)
	end

	-- 버프 상태(BuffState와 같은 의미의 필드만).
	local quickShotUntil = -1
	local guaranteedCritUntil = -1
	local backstepCharges = 0
	local dealingModeActive = false

	local function isQuickShot(at)
		return at < quickShotUntil
	end
	local function isGuaranteedCrit(at)
		return at < guaranteedCritUntil
	end

	local function addDamage(target, amount, sourceName)
		if not target.alive then
			return false
		end
		target.hp -= amount
		result.totalDamage += amount
		if sourceName then
			result.skillDamage[sourceName] = (result.skillDamage[sourceName] or 0) + amount
			result.skillDamageTotal += amount
		else
			result.autoDamage += amount
		end
		if target.hp <= 0 then
			target.alive = false
			if target == targets[1] then
				result.killTime = t
				finished = true
			end
			return true
		end
		return false
	end

	-- 예약 이벤트(원거리 도달·채널링 틱·꽂힌 화살 폭발). at 오름차순으로 처리한다.
	local events = {}
	local function schedule(at, fn)
		table.insert(events, { at = at, fn = fn })
	end
	local function popNextEventTime()
		local best = nil
		for _, e in ipairs(events) do
			if not best or e.at < best then
				best = e.at
			end
		end
		return best
	end
	local function runEventsAt(at)
		-- 같은 시각 이벤트는 등록 순서대로.
		local i = 1
		while i <= #events do
			local e = events[i]
			if e.at <= at + 1e-9 then
				table.remove(events, i)
				e.fn()
				if finished then
					return
				end
			else
				i += 1
			end
		end
	end

	-- 꽂히는 화살(StuckArrowState 규칙): 상한 초과 시 가장 오래된 것부터 즉시 폭발.
	local function explodeArrow(target, record)
		if record.exploded then
			return
		end
		record.exploded = true
		for i, r in ipairs(target.stuckArrows) do
			if r == record then
				table.remove(target.stuckArrows, i)
				break
			end
		end
		if not target.alive then
			return
		end
		addDamage(target, record.base * loadout.critMultAvg, skills.Q.name .. "(꽂힌 화살)")
	end
	local function attachArrow(target, at)
		local def = skills.Q
		while #target.stuckArrows >= def.stuckArrowMaxPerMonster do
			explodeArrow(target, target.stuckArrows[1])
			if finished then
				return
			end
		end
		local record = { base = atk * def.stuckArrowDamageCoefficient, exploded = false }
		table.insert(target.stuckArrows, record)
		schedule(at + def.stuckArrowDelaySeconds, function()
			explodeArrow(target, record)
		end)
	end

	-- 평타(AttackServer 경로 그대로).
	local lastAttackAt = nil
	local comboCount = 0
	local lastComboAt = nil
	local channelUntil = -1 -- channelBlocksAutoAttack용

	-- 속사 배율(SkillServer castSelfBuff와 같은 식 - ClassData.critRate만 읽는다, 백스텝샷
	-- 치확 보너스는 반영되지 않는다).
	local quickShotMult = 1
	if skills.Q and skills.Q.shape == "selfBuff" then
		quickShotMult = math.min(skills.Q.attackSpeedCap, skills.Q.attackSpeedBase + class.critRate * skills.Q.attackSpeedCritCoefficient)
	end
	local cooldownBase = PlayerCombat.getAttackCooldown(classId, loadout.speedPercentBonus, 1)
	local cooldownBuffed = PlayerCombat.getAttackCooldown(classId, loadout.speedPercentBonus, quickShotMult)

	-- 다음 평타 가능 시각: 서버는 "요청 시점 t'의 버프 상태로 계산한 쿨다운"으로 판정한다
	-- (t' - last >= cooldown(t')). 버프 쿨다운으로 잡은 후보 시각에 버프가 이미 꺼져 있으면
	-- 기본 쿨다운이 적용된다.
	local function nextAttackTime()
		if not lastAttackAt then
			return (opts.turnDelaySeconds or 0)
		end
		local candidate = lastAttackAt + cooldownBuffed
		if not isQuickShot(candidate) then
			candidate = lastAttackAt + cooldownBase
		end
		if channelBlocksAutoAttack then
			candidate = math.max(candidate, channelUntil)
		end
		return candidate
	end

	local function doAttack()
		lastAttackAt = t
		if not lastComboAt or t - lastComboAt > CombatConfig.comboResetWindowSeconds then
			comboCount = 0
		end
		comboCount += 1
		lastComboAt = t
		local isComboHit = comboCount % CombatConfig.comboHitEvery == 0

		local target = targets[1]
		local base = atk
		if isComboHit then
			base *= CombatConfig.comboHitMultiplier
		end
		if dealingModeActive then
			base *= skills.E.attackMultiplier * PlayerCombat.getInvestmentScale(loadout.weaponLevel, loadout.attackPercentBonus, skills.E.investmentScaling)
		end
		local critRateBonus = 0
		if backstepCharges > 0 then
			base += skills.E.damageCoefficient * atk
			critRateBonus = skills.E.critRateBonus
			backstepCharges -= 1
		end

		local critMult
		local forceCrit, critDmgBonus = PlayerCombat.resolveGuaranteedCrit(classId, isGuaranteedCrit(t), critRateBonus)
		if forceCrit then
			critMult = class.critDmg
		elseif critDmgBonus > 0 then
			critMult = class.critDmg + critDmgBonus
		else
			critMult = critMultFor(critRateBonus)
		end
		local damage = base * critMult
		local wasQuickShotActive = isQuickShot(t)
		result.autoHits += 1

		if not projectileKind then
			addDamage(target, damage)
			return
		end
		schedule(t + releaseDelay + travelTime, function()
			if not target.alive then
				return
			end
			local isDead = addDamage(target, damage)
			if not isDead and wasQuickShotActive and projectileKind == "arrow" then
				attachArrow(target, t)
			end
		end)
	end

	-- 스킬(SkillServer 경로 그대로, shape로 분기).
	local lastCastAt = {}
	local function isReady(slot, def)
		local last = lastCastAt[slot]
		return not last or (t - last) >= def.cooldownSeconds
	end
	local function markCast(slot, def)
		lastCastAt[slot] = t
		result.casts[def.name] = (result.casts[def.name] or 0) + 1
	end

	local function castSkill(slot, def)
		if def.shape == "line" then
			markCast(slot, def)
			local n = lineMaxTargets
			for i = 1, n do
				addDamage(targets[i], atk * def.coefficient * loadout.critMultAvg, def.name)
				if finished then
					return
				end
			end
		elseif def.shape == "circle" then
			markCast(slot, def)
			channelUntil = t + def.channelSeconds
			local tickInterval = def.channelSeconds / def.tickCount
			local perTick = atk * (def.coefficient / def.tickCount) * loadout.critMultAvg
			for k = 1, def.tickCount do
				schedule(t + tickInterval * k, function()
					for i = 1, targetCount do
						addDamage(targets[i], perTick, def.name)
						if finished then
							return
						end
					end
				end)
			end
		elseif def.shape == "singleChannel" then
			local locked = targets[1]
			if not locked.alive then
				return -- 대상 없음 - 쿨다운을 태우지 않는다(서버 reject "noTarget")
			end
			markCast(slot, def)
			channelUntil = t + def.channelSeconds
			local tickInterval = def.channelSeconds / def.tickCount
			local perTickBase = atk * (def.coefficient / def.tickCount)
			for k = 1, def.tickCount do
				schedule(t + tickInterval * k, function()
					if not locked.alive then
						return -- 대상이 죽었다 - 남은 틱 손실
					end
					local mult = loadout.critMultAvg
					if k <= (def.guaranteedCritHits or 0) then
						local forceCrit, critDmgBonus = PlayerCombat.resolveGuaranteedCrit(classId, isGuaranteedCrit(t), 0)
						if forceCrit then
							mult = class.critDmg
						elseif critDmgBonus > 0 then
							mult = class.critDmg + critDmgBonus
						end
					end
					addDamage(locked, perTickBase * mult, def.name)
				end)
			end
		elseif def.shape == "selfBuff" then
			markCast(slot, def)
			quickShotUntil = t + def.durationSeconds
		elseif def.shape == "dash" then
			markCast(slot, def)
			backstepCharges = def.chargesGranted
		elseif def.shape == "summon" then
			markCast(slot, def)
			guaranteedCritUntil = t + def.durationSeconds
		elseif def.shape == "heal" then
			markCast(slot, def) -- 피해 없음 - 캐스트 횟수만 기록
		elseif def.shape == "toggle" then
			if not dealingModeActive then
				markCast(slot, def)
				dealingModeActive = true -- 60초 측정 창 안에서는 계속 켜 둔다(가동률은 simulateHealerCycle이 따로 잰다)
			end
		end
	end

	-- 캐스트 순서: Q 먼저, E 다음(둘 다 준비돼 있을 때). 쌍검은 Q(확정 치명타 창)가 먼저 켜져야
	-- E 1틱째에 확정 치명타가 붙고, 활은 코드상 순서 의존이 없다(속사 배율이 백스텝샷 치확을
	-- 안 읽는다 - castSelfBuff는 ClassData.critRate만 읽는다, 20-7 [1] 확인).
	local slotOrder = { "Q", "E" }

	local function nextSkillTime()
		if not useSkills then
			return nil
		end
		local best = nil
		for _, slot in ipairs(slotOrder) do
			local def = skills[slot]
			if def and not (def.shape == "toggle" and dealingModeActive) then
				local last = lastCastAt[slot]
				local ready = last and (last + def.cooldownSeconds) or 0
				if not best or ready < best then
					best = ready
				end
			end
		end
		return best
	end

	while not finished do
		local tAttack = nextAttackTime()
		local tSkill = nextSkillTime()
		local tEvent = popNextEventTime()
		local nextT = tAttack
		if tSkill and tSkill < nextT then
			nextT = tSkill
		end
		if tEvent and tEvent < nextT then
			nextT = tEvent
		end
		if nextT > duration then
			break
		end
		t = math.max(nextT, t)

		runEventsAt(t)
		if finished then
			break
		end
		if useSkills then
			for _, slot in ipairs(slotOrder) do
				local def = skills[slot]
				if def and isReady(slot, def) and not (def.shape == "toggle" and dealingModeActive) then
					castSkill(slot, def)
					if finished then
						break
					end
				end
			end
			if finished then
				break
			end
		end
		if tAttack <= t + 1e-9 then
			doAttack()
		end
	end

	return result
end

-- ═══ 힐러 딜링모드 정상 상태 가동률(20-7 [3]) ═══
--
-- 규칙(코드 그대로): 자동회복은 마지막 전투 행위(피격·평타 요청·딜링모드 소모 틱) 후
-- CombatConfig.regenDelaySeconds(5초)가 지나야 시작되고 초당 regenPercentPerSecond(4%)씩 찬다.
-- 딜링모드는 켜져 있는 매 순간 전투 행위로 찍히므로(HealerDealingMode.server.lua) 켜 둔 채로는
-- 절대 회복이 시작되지 않는다. 힐러 Q(치유)는 전투 행위로 찍히지 않는다(SkillServer는
-- setLastCombatActionAt을 부르지 않는다) - 쉬는 동안 써도 회복 타이머를 리셋하지 않는다.
--
-- 사이클: [전투] hp가 reserveRatio까지 떨어지면 → [이탈] retreatSeconds(피격도 회복도 없음) →
-- [대기] 마지막 전투 행위 후 5초 → [회복] 만피까지 → [복귀] returnSeconds → [전투]. Q는 쿨마다
-- (전투·휴식 무관) 기대 회복량(healPercent×(1+critRate×(critHealMultiplier−1)))을 준다.
--
-- params:
--   hitsPerSecond        전투 중 초당 피격 횟수(0=완벽 회피, 1=몬스터 평타 쿨다운 1초 그대로 맞음)
--   hitRatio             피격 1회당 최대체력 대비 손실(getSurviveHits의 dmgPerHit/maxHp)
--   drainPerSecond       딜링모드 초당 소모(기본 SkillData.healer.E.drainPercentPerSecond, 0이면 비힐러 비교용)
--   reserveRatio         이 비율에서 이탈(기본 0.3 - 피격 2대 여유)
--   retreatSeconds       어그로에서 벗어나는 시간(기본 2)
--   returnSeconds        복귀 시간(기본 2)
--   healQ                true면 힐러 Q 사용(기본 drainPerSecond>0일 때만)
--   simSeconds           시뮬레이션 길이(기본 3600)
--   regenPerSecond       자동 회복률(초당 최대체력 비율, 기본 CombatConfig.regenPercentPerSecond). 0이면 보스전 조건(자동 회복 없음 - S13 측정) - 이때 회복은 Q 치유뿐이다
-- 반환: { uptime = 전투(딜링모드 켜짐) 시간 / 전체, fightSeconds, cycleSeconds, cycles }
function BalanceSim.simulateHealerCycle(params)
	local healerE = SkillData.healer.E
	local healerQ = SkillData.healer.Q
	local hitsPerSecond = params.hitsPerSecond or 0
	local hitRatio = params.hitRatio or 0
	local drain = params.drainPerSecond
	if drain == nil then
		drain = healerE.drainPercentPerSecond
	end
	local reserve = params.reserveRatio or 0.3
	local retreatSeconds = params.retreatSeconds or 2
	local returnSeconds = params.returnSeconds or 2
	local useHealQ = params.healQ
	if useHealQ == nil then
		useHealQ = drain > 0
	end
	local simSeconds = params.simSeconds or 3600
	local regen = params.regenPerSecond
	if regen == nil then
		regen = CombatConfig.regenPercentPerSecond
	end
	local regenDelay = CombatConfig.regenDelaySeconds
	local healAmount = healerQ.healPercentOfMaxHp * (1 + ClassData.classes.healer.critRate * (healerQ.critHealMultiplier - 1))

	local dt = 0.05
	local hp = 1.0
	local phase = "fight"
	local phaseLeft = 0
	local lastCombatAt = 0
	local nextHealAt = 0
	local fightSeconds, cycles = 0, 0
	local t = 0
	while t < simSeconds do
		if useHealQ and t >= nextHealAt then
			hp = math.min(hp + healAmount, 1)
			nextHealAt = t + healerQ.cooldownSeconds
		end

		if phase == "fight" then
			hp -= (drain + hitsPerSecond * hitRatio) * dt
			lastCombatAt = t
			fightSeconds += dt
			if hp <= reserve then
				phase = "retreat"
				phaseLeft = retreatSeconds
			end
		elseif phase == "retreat" then
			phaseLeft -= dt
			if phaseLeft <= 0 then
				phase = "regen"
			end
		elseif phase == "regen" then
			if t - lastCombatAt >= regenDelay then
				hp = math.min(hp + regen * dt, 1)
			end
			if hp >= 1 then
				phase = "return"
				phaseLeft = returnSeconds
			end
		elseif phase == "return" then
			phaseLeft -= dt
			if phaseLeft <= 0 then
				phase = "fight"
				cycles += 1
			end
		end
		t += dt
	end

	return {
		uptime = fightSeconds / simSeconds,
		fightSeconds = fightSeconds,
		cycleSeconds = cycles > 0 and simSeconds / cycles or math.huge,
		cycles = cycles,
	}
end

-- 목표 가동률이 나오는 딜링모드 소모율을 이분법으로 역산한다(21-1 [1]-D). 소모율이 클수록
-- 가동률은 단조 감소하므로 이분법이 성립한다. params는 simulateHealerCycle과 같다(drainPerSecond만
-- 여기서 채운다).
function BalanceSim.solveHealerDrain(targetUptime, params)
	local lo, hi = 0, 0.2
	for _ = 1, 30 do
		local mid = (lo + hi) / 2
		local p = table.clone(params)
		p.drainPerSecond = mid
		if BalanceSim.simulateHealerCycle(p).uptime > targetUptime then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) / 2
end

-- ═══ 앵커 곡선(21-1 [2], BalanceAnchorConfig) ═══
--
-- 앵커 조건의 loadout - 레벨 L, itemLevel L(gearGrade 3부위), 무기 등급 g, 강화 +0.
-- armorGradeId(선택)를 주면 갑옷만 그 등급으로 바꾼다(무기 등급과 갑옷 등급을 짝지어
-- "등급 축이 생존에도 반영되면"을 재볼 때 쓴다 - 20.44 [2] 표의 세 번째 변형).
function BalanceSim.buildAnchorLoadout(classId, level, weaponGrade, armorGradeId)
	local gearGrade = BalanceAnchorConfig.gearGrade
	return BalanceSim.buildLoadout({
		classId = classId,
		level = level,
		weaponLevel = BalanceAnchorConfig.weaponLevel,
		weaponGrade = weaponGrade or 0,
		gear = {
			armor = { grade = armorGradeId or gearGrade, itemLevel = level },
			gloves = { grade = gearGrade, itemLevel = level },
			shoes = { grade = gearGrade, itemLevel = level },
		},
	})
end

-- 한 점(loadout × stage)의 전부 - "/gg measure"와 "/gg curve"가 같은 함수를 쓴다.
-- unit = 무기 기본 atk 단위(atk ÷ 클래스 배율) - PRD-forge-game.md 4.4의 "60초 딜 총합
-- (atk-단위)" 표(쌍검 436.5·활 408.5·대검 330.8)와 같은 눈금이라 그 표와 바로 비교된다.
-- stage는 정수가 아니어도 된다(InfiniteStage.getMultiplier가 실수 지수) - solveKillOffset이 쓴다.
function BalanceSim.measurePoint(loadout, stage)
	local monsterAttack = BalanceSim.getMonsterAttack(stage)
	local monsterHp = BalanceSim.getMonsterHp(stage)
	local surviveHits, dmgPerHit = BalanceSim.getSurviveHits(loadout, monsterAttack)
	local killAuto = BalanceSim.simulateCombat(loadout, { useSkills = false, targetHp = monsterHp, durationSeconds = 600, turnDelaySeconds = 0.125 })
	local killRotation = BalanceSim.simulateCombat(loadout, { useSkills = true, targetHp = monsterHp, durationSeconds = 600, turnDelaySeconds = 0.125 })
	return {
		stage = stage,
		monsterAttack = monsterAttack,
		monsterHp = monsterHp,
		surviveHits = surviveHits,
		dmgPerHit = dmgPerHit,
		killAutoSeconds = killAuto.killTime or math.huge,
		killAutoHits = killAuto.autoHits,
		killRotationSeconds = killRotation.killTime or math.huge,
		unit = loadout.atk / loadout.class.atk,
	}
end

-- 무기 등급 g가 처치 시간 축에서 몇 스테이지에 해당하는가: atk가 statMultiplier(m_g)배가
-- 되면 몬스터 HP가 k^Δ배일 때 처치 시간이 같으므로 Δ = ln(m_g)/ln(k). 생존 축은 무기 등급을
-- 전혀 안 본다(방어력·최대체력에 무기 등급 항이 없다 - PlayerCombat.getDefense/Loot.getMaxHpBonus)
-- - 그래서 이 Δ를 rec에 더하면 생존 타수가 k^(~1.6Δ)로 무너진다(20.44 [2] 측정 참고).
function BalanceSim.gradeStageShift(weaponGrade)
	local gradeId = ArmorData.gradeOrder[(weaponGrade or 0) + 1]
	local m = gradeId and ItemVisualData.gradeVisuals[gradeId].statMultiplier or 1
	return math.log(m) / math.log(InfiniteStageConfig.growthRate)
end

-- 기준 직업·기준 레벨·등급0에서 로테이션 처치 시간이 killTargetSeconds가 되는 스테이지를
-- 이분법으로 찾아 "rec(L) = L + offset"의 offset을 돌려준다. 처치 시간은 스테이지에 단조
-- 증가(HP가 k^S)라 이분법이 성립한다. 결과는 실수 - 곡선 자체는 실수, 표시할 때만 반올림.
local cachedKillOffset = nil
function BalanceSim.solveKillOffset()
	if cachedKillOffset then
		return cachedKillOffset
	end
	local level = BalanceAnchorConfig.referenceLevel
	local loadout = BalanceSim.buildAnchorLoadout(BalanceAnchorConfig.referenceClassId, level, 0)
	-- P2.5a: 탐색 상한 = 레벨 + "HP 1만 배"에 해당하는 스테이지 수(k = 1.155에서 64 - 옛 +60과 같은 폭, k = 1.02에서 466 - 처치 오프셋이 +167이라 옛 +60으로는 못 찾는다).
	local lo, hi = 1, level + math.ceil(math.log(1e4) / math.log(InfiniteStageConfig.growthRate))
	for _ = 1, 40 do
		local mid = (lo + hi) / 2
		local point = BalanceSim.measurePoint(loadout, mid)
		if point.killRotationSeconds < BalanceAnchorConfig.killTargetSeconds then
			lo = mid
		else
			hi = mid
		end
	end
	cachedKillOffset = (lo + hi) / 2 - level
	return cachedKillOffset
end

-- 권장 스테이지 rec(L, g). includeGrade=false면 등급을 무시한 rec(L)(생존 축이 아는 유일한
-- 곡선), true면 처치 축의 등급 환산(gradeStageShift)을 더한 rec(L, g). 둘 중 어느 쪽이
-- 기준인지는 20.44 [2]의 측정 결과가 정한다 - 이 함수는 둘 다 계산해 준다.
function BalanceSim.recommendedStage(level, weaponGrade, includeGrade)
	local stage = level + BalanceSim.solveKillOffset()
	if includeGrade then
		stage += BalanceSim.gradeStageShift(weaponGrade)
	end
	return math.max(1, math.floor(stage + 0.5))
end

-- 앵커 곡선 위 격자(BalanceAnchorConfig.curveLevels × curveGrades)를 전부 잰다. 각 점마다
-- 세 변형: (1) rec(L) 등급 무시, (2) rec(L,g) 등급 반영, (3) rec(L,g)에서 갑옷 등급까지
-- 무기 등급과 짝지은 경우(생존 축이 등급을 알게 되면 얼마나 회복되는가).
function BalanceSim.measureCurve(classId)
	local rows = {}
	for _, level in ipairs(BalanceAnchorConfig.curveLevels) do
		for _, grade in ipairs(BalanceAnchorConfig.curveGrades) do
			local loadout = BalanceSim.buildAnchorLoadout(classId, level, grade)
			local recFree = BalanceSim.recommendedStage(level, grade, false)
			local recGrade = BalanceSim.recommendedStage(level, grade, true)
			local free = BalanceSim.measurePoint(loadout, recFree)
			local graded = BalanceSim.measurePoint(loadout, recGrade)
			local pairedLoadout = BalanceSim.buildAnchorLoadout(classId, level, grade, ArmorData.gradeOrder[grade + 1])
			local paired = BalanceSim.measurePoint(pairedLoadout, recGrade)
			table.insert(rows, {
				level = level,
				grade = grade,
				recFree = recFree,
				recGrade = recGrade,
				free = free,
				graded = graded,
				paired = paired,
			})
		end
	end
	return rows
end

return BalanceSim
