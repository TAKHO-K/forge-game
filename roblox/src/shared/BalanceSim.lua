-- 밸런스 실측 시뮬레이터(19-3a). 실제 클릭·타이머 대기로 재는 대신, 이 게임이 이미 갖고
-- 있는 공식(PlayerCombat·Loot·CharacterLevel·InfiniteStage·CombatConfig)을 그대로 재사용해
-- "이 조건이면 생존 타수/60초 총딜이 얼마인가"를 계산한다 - 도구 호출 왕복 지연 때문에
-- 수동 클릭으로는 처치 시간을 잴 수 없다는 문제를 formula-level 계산으로 우회한다.
--
-- 이 모듈은 순수 함수만 담는다(플레이어·저장·RemoteEvent를 모른다) - DevTools.server.lua가
-- 실제 플레이어 조건을 읽어 이 함수들에 넘기고, Studio Edit 모드에서 직접 호출해도(플레이어
-- 없이) 똑같이 동작한다. 앞으로 스킬 8종의 실제 계수를 조정할 때도 이 모듈 하나만 계속
-- 재사용한다(19-3a 지시 - "이 시뮬레이터가 앞으로 모든 밸런스 작업의 기준이 된다").

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local Loot = require(ReplicatedStorage.Shared.Loot)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
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

-- buildLoadout(합성 아이템)과 buildLoadoutFromEquipment(실제 착용 아이템) 둘 다 여기로
-- 모인다 - "장비 3부위 테이블에서 loadout을 뽑는다"는 계산 자체는 아이템이 합성이든
-- 실제 드랍이든 완전히 같다(Loot.get*류 함수가 이미 item 테이블 형태만 본다).
local function buildLoadoutCore(classId, level, weaponLevel, armorItem, glovesItem, shoesItem)
	local class = ClassData.classes[classId]
	assert(class, "알 수 없는 classId: " .. tostring(classId))

	local weapon = { id = WeaponData.starterId, level = weaponLevel or 0 }
	local attackPercentBonus = Loot.getGlovesAttackPercent(glovesItem)
	local speedPercentBonus = Loot.getShoesSpeedPercent(shoesItem)
	local armorBonus = Loot.getArmorDefense(armorItem)
	local maxHpBonus = Loot.getMaxHpBonus(armorItem)

	return {
		classId = classId,
		level = level,
		class = class,
		atk = PlayerCombat.getAttack(weapon, classId, level, attackPercentBonus),
		defense = PlayerCombat.getDefense(classId, armorBonus),
		maxHp = CombatConfig.playerMaxHp + maxHpBonus,
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

-- spec = { classId, level, weaponLevel = 0, gear = { armor=gearSpec, gloves=gearSpec, shoes=gearSpec } }
-- gearSpec = { grade, itemLevel } - 실측 시나리오를 가정해 만든 합성 아이템. 실제 드랍
-- 확률(ArmorData.dropChance 등)은 거치지 않는다(이 시뮬레이터는 "이 조건이면"을 계산하는
-- 도구이지 드랍을 재현하는 도구가 아니다).
function BalanceSim.buildLoadout(spec)
	local gear = spec.gear or {}
	return buildLoadoutCore(
		spec.classId, spec.level, spec.weaponLevel,
		buildItem("armor", gear.armor), buildItem("gloves", gear.gloves), buildItem("shoes", gear.shoes)
	)
end

-- 실제 플레이어의 현재 착용 아이템(PlayerProfile.getEquipped가 돌려주는 실제 item 테이블,
-- 없으면 nil)으로 loadout을 만든다. DevTools의 "/gg measure"가 쓴다 - 합성 조건이 아니라
-- 지금 이 플레이어가 실제로 들고 있는 장비 그대로 잰다.
function BalanceSim.buildLoadoutFromEquipment(classId, level, weaponLevel, equipment)
	equipment = equipment or {}
	return buildLoadoutCore(classId, level, weaponLevel, equipment.armor, equipment.gloves, equipment.shoes)
end

-- 생존 타수. CombatConfig.damageReductionAlpha 유도식(hits = maxHp×(D+αA)/(αA²))과 완전히
-- 같은 식이다 - 그 상수를 역산할 때 쓴 공식을 그대로 재사용해 이 도구와 그 상수가 항상
-- 같은 정의를 쓰게 한다.
function BalanceSim.getSurviveHits(loadout, monsterAttack)
	local D, A, alpha = loadout.defense, monsterAttack, CombatConfig.damageReductionAlpha
	local dmgPerHit = (alpha * A * A) / (D + alpha * A)
	return loadout.maxHp / dmgPerHit, dmgPerHit
end

-- tier 몬스터 1마리의 스테이지 적용 평타(InfiniteStage.getMonsterAttack 재사용). tierKey
-- 기본값 tier1 - CombatConfig.damageReductionAlpha 앵커가 쓰는 것과 같은 관례.
function BalanceSim.getMonsterAttack(stage, tierKey)
	local tierData = MonsterData[tierKey or "tier1"]
	return InfiniteStage.getMonsterAttack(tierData.attack, stage)
end

-- 스킬 없는 순수 평타만의 durationSeconds초 총딜.
function BalanceSim.simulateAutoAttack(loadout, durationSeconds)
	local hits = durationSeconds / loadout.attackCooldown
	local avgHit = loadout.atk * loadout.comboMultAvg * loadout.critMultAvg
	return { hits = hits, totalDamage = hits * avgHit, avgHit = avgHit }
end

-- skills(선택) 배열의 각 항목:
--   name                  표시용 이름
--   cooldownSeconds       스킬 재사용 대기시간
--   castsOverride         (선택) duration/cooldown 대신 쓸 캐스트 횟수(자원 제약이 있는
--                         스킬 - 예: 힐러 딜링모드 - 은 호출부가 직접 계산해 넘긴다)
--   coefficient           (선택, 기본 0) atk 단위 자체 피해 계수 - 1회 캐스트당
--                         coefficient × loadout.atk × 치명타평균 × targets 만큼 데미지.
--                         평타의 3타 강타(콤보)는 적용하지 않는다(콤보 카운터는 평타 전용).
--   targets               (선택, 기본 1) 그 캐스트가 동시에 맞히는 대상 수 - 광역 스킬의
--                         "총딜"을 낼 때만 1보다 크게 준다(생존 타수 등 단일 대상 계산에는 안 쓴다).
--   channelSeconds        (선택, 기본 0) 캐스트 1회당 평타를 못 치는 시간(대검 회전형 스킬 등).
--                         casts × channelSeconds만큼 평타 가능 시간에서 뺀다.
--   windowSeconds/windowAttackSpeedMult/windowDamageMult/windowGuaranteedCrit
--                         (선택) 캐스트 후 그 시간 동안 평타에 걸리는 버프. 이 창들은
--                         서로 겹치지 않는다고 가정한다(기본 킷 비교 목적의 근사치 - PRD의
--                         "기본킷" 표와 같은 수준의 근사, 여러 버프가 정확히 겹치는 실력
--                         폭 시나리오는 이 함수 밖에서 별도로 계산한다).
-- 반환: { autoattackHits, autoattackDamage, skillDamage(이름->값), skillDamageTotal, totalDamage }
function BalanceSim.simulateRotation(loadout, durationSeconds, skills)
	skills = skills or {}

	local totalChannelTime = 0
	local skillDamage = {}
	local skillDamageTotal = 0
	local windowContributions = {}

	for _, skill in ipairs(skills) do
		local casts = skill.castsOverride or (durationSeconds / skill.cooldownSeconds)

		if skill.coefficient and skill.coefficient ~= 0 then
			local dmg = skill.coefficient * loadout.atk * loadout.critMultAvg * (skill.targets or 1) * casts
			skillDamage[skill.name] = dmg
			skillDamageTotal += dmg
		end

		totalChannelTime += (skill.channelSeconds or 0) * casts

		if skill.windowSeconds and skill.windowSeconds > 0 then
			local windowTime = math.min(skill.windowSeconds * casts, durationSeconds)
			local speedMult = skill.windowAttackSpeedMult or 1
			local dmgMult = skill.windowDamageMult or 1
			local critMult = skill.windowGuaranteedCrit and loadout.critDmg or loadout.critMultAvg

			-- "이 창이 없었다면" 나왔을 평타 수·데미지 대비 차이만 더한다(아래 baseHits/
			-- baseDamage가 이미 전체 시간 기준으로 그 몫을 계산해 두므로, 여기서 다시
			-- 더하면 이중 계산이 된다).
			local baseHitsInWindow = windowTime / loadout.attackCooldown
			local actualHitsInWindow = baseHitsInWindow * speedMult
			local baseDamageInWindow = baseHitsInWindow * loadout.atk * loadout.comboMultAvg * loadout.critMultAvg
			local actualDamageInWindow = actualHitsInWindow * loadout.atk * loadout.comboMultAvg * critMult * dmgMult

			table.insert(windowContributions, {
				name = skill.name,
				extraHits = actualHitsInWindow - baseHitsInWindow,
				extraDamage = actualDamageInWindow - baseDamageInWindow,
			})
		end
	end

	local availableTime = math.max(durationSeconds - totalChannelTime, 0)
	local baseHits = availableTime / loadout.attackCooldown
	local baseDamage = baseHits * loadout.atk * loadout.comboMultAvg * loadout.critMultAvg

	local extraHits, extraDamage = 0, 0
	for _, window in ipairs(windowContributions) do
		extraHits += window.extraHits
		extraDamage += window.extraDamage
	end

	local autoattackHits = baseHits + extraHits
	local autoattackDamage = baseDamage + extraDamage

	return {
		autoattackHits = autoattackHits,
		autoattackDamage = autoattackDamage,
		skillDamage = skillDamage,
		skillDamageTotal = skillDamageTotal,
		totalDamage = autoattackDamage + skillDamageTotal,
		windowContributions = windowContributions,
	}
end

return BalanceSim
