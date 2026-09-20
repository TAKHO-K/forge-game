-- 클래스 배율이 실제로 곱해지는 유일한 위치(10-3 [3]). 공격력·방어력·공격속도 전부 이
-- 모듈을 거친다 - 배율 적용 지점이 흩어지면 나중에 특수옵션(장비 접미사 등)이 들어올 때마다
-- 어디에 곱해야 할지 매번 찾아야 한다는 게 지시 사항의 이유였다.
--
-- 방어력은 "(기본값 + 장비 보너스) × 클래스 배율" - 부분에만 곱하지 않는다(PRD-forge-
-- game-roblox.md 20.11-4 "구현 시 반영 사항" - 웹 main.js는 장비 보너스를 배율 밖에서
-- 더하는 실수를 했고, 로블록스는 처음부터 합계 전체에 곱하는 쪽으로 짠다). 장비 방어
-- 보너스가 아직 없어(드랍 시스템 미구현) equipmentDefenseBonus는 항상 0으로 호출되지만,
-- 인자 자리를 지금 만들어 둬야 나중에 장비가 생겼을 때 이 함수 밖에서 따로 더하는
-- 실수가 재발하지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local EnhanceEffect = require(ReplicatedStorage.Shared.EnhanceEffect)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)

-- 무기 등급 배율 - 갑옷·장갑·신발과 같은 단일 출처(ArmorData.gradeOrder로 index->id,
-- ItemVisualData.gradeVisuals[id].statMultiplier로 배율)를 쓴다(20-1, WeaponData.lua
-- 주석 참고). 여기 한 곳에서만 조회한다 - BalanceSim도 이 함수를 거친다.
local function gradeMultiplierForIndex(gradeIndex)
	local gradeId = ArmorData.gradeOrder[(gradeIndex or 0) + 1]
	return gradeId and ItemVisualData.gradeVisuals[gradeId].statMultiplier or 1.0
end

-- math.random은 전역 시드를 다른 호출과 공유한다 - 치명타 판정만의 독립된 스트림을 쓴다
-- (10-4 지시). 이 모듈은 서버 스크립트(AttackServer 등)에서만 damage 계산 목적으로
-- 호출된다 - 치명타 롤도 그래서 항상 서버에서만 일어난다.
local critRng = Random.new()

local PlayerCombat = {}

function PlayerCombat.getClass(classId)
	return ClassData.classes[classId]
end

-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율 × 캐릭터 레벨계수(13-2 -
-- 웹 main.js의 getEnhanceDamageMultiplier×getWeaponExpAttackMultiplier와 같은 구조, PRD
-- 20.8/20.10이 이미 "레벨이 무기 공격력 배율을 밀어올린다"고 확정해 둔 축을 여기서 실제로
-- 채운다) × (1+장갑 공격력%, 16-6). 치명타를 적용하기 전 기본 데미지다 - calcDamage에
-- base로 넘긴다. attackPercentBonus는 장갑 미착용이면 항상 0이 들어와 곱셈이 1이 되므로
-- 기존 호출부(장갑 이식 전)와 결과가 똑같다.
function PlayerCombat.getAttack(weapon, classId, characterLevel, attackPercentBonus)
	local class = ClassData.classes[classId]
	local weaponData = WeaponData.weapons[weapon.id]
	local gradeMultiplier = gradeMultiplierForIndex(weapon.grade)
	local base = Enhance.getPlayerAttack(weaponData, weapon.level, class.atk, gradeMultiplier)
	return base * CharacterLevel.getWeaponExpMultiplier(characterLevel) * (1 + (attackPercentBonus or 0))
end

-- 신발의 이동+공격속도 비율 보너스를 1+x 배율로 바꾼다(16-6, 웹 core/equipment.js
-- speedMultiplier와 같은 형태) - WalkSpeed·공격 쿨다운 둘 다 이 하나의 배율을 공유한다
-- (웹도 신발 하나가 "이동+공속"을 같이 준다, ITEM_PART_BASE_STAT.shoes 참고).
function PlayerCombat.getSpeedMultiplier(speedPercentBonus)
	return 1 + (speedPercentBonus or 0)
end

-- 치명타 판정 + 적용 - 유일한 위치(10-4 [3]). base는 평타의 getAttack 결과일 수도,
-- 나중에 들어올 스킬의 계수(atk를 대체하는 값)일 수도 있다 - 여기 한 곳에만 크리를
-- 넣어두면 스킬이 들어와도 자동으로 크리가 적용된다(평타 경로에만 붙이지 말라는 지시).
-- critRateBonus(20-2b) - 활 백스텝샷처럼 "다음 N회 평타 치명타 확률 +Xp" 버프가 있을 때
-- 호출부(AttackServer.server.lua)가 BuffState에서 읽어 넘긴다. 이 함수 자체는 BuffState를
-- 모른다(공유 모듈이 서버 전용 상태를 직접 참조하면 안 된다) - 순수하게 "확률에 더할 값"만
-- 받는다. 기본 0이라 기존 2-인자 호출부(SkillServer.server.lua 등)는 그대로 동작한다.
-- forceCrit·critDmgBonus(20-6, 쌍검 Q 확정 치명타) - RNG 롤 자체를 건너뛰고 무조건
-- 치명타로 처리하거나(forceCrit), 치명타 피해율에 값을 더한다(critDmgBonus, PRD 4.3
-- "확률 100% 초과분은 피해율로 전환" - resolveGuaranteedCrit이 둘 중 하나만 세팅해서 넘긴다).
-- 기본값 둘 다 false/0이라 기존 4-인자 이하 호출부는 그대로 동작한다.
function PlayerCombat.calcDamage(base, classId, critRateBonus, forceCrit, critDmgBonus)
	local class = ClassData.classes[classId]
	local isCrit = forceCrit or (critRng:NextNumber() < class.critRate + (critRateBonus or 0))
	local damage = isCrit and base * (class.critDmg + (critDmgBonus or 0)) or base
	return damage, isCrit
end

-- 확정 치명타 버프(20-6) 해석 - 호출부(AttackServer/SkillServer)가 BuffState.get으로 버프
-- 활성 여부만 확인해 isActive로 넘긴다(이 모듈은 BuffState를 모른다, 위 calcDamage와 같은
-- 원칙). 유효 치명타확률(클래스 기본값 + critRateBonus)이 100%를 넘겼으면 강제 발동 대신
-- 치명타 피해율 보너스로 전환한다(PRD 4.3) - calcDamage에 넘길 (forceCrit, critDmgBonus)
-- 쌍을 돌려준다.
function PlayerCombat.resolveGuaranteedCrit(classId, isActive, critRateBonus)
	if not isActive then
		return false, 0
	end
	local class = ClassData.classes[classId]
	local effectiveCritRate = class.critRate + (critRateBonus or 0)
	if effectiveCritRate >= 1.0 then
		return false, CombatConfig.guaranteedCritOverflowBonus
	end
	return true, 0
end

-- 클래스별 유효 사거리(19-2) = 기본 사거리 × 클래스 배율(ClassData.rangeMultiplier).
-- 서버(AttackServer, 대상 판정)와 클라이언트(AimTarget, 조준 표시) 둘 다 이 함수 하나로
-- 계산한다 - 화면에 보이는 조준 대상과 실제로 맞는 대상이 어긋나면 안 된다(AimPicker와
-- 같은 이유).
--
-- weaponLevel(30-0 S08, PRD 20.72 [1-9]) - 강화 단계의 사거리 보너스(+15 · +20 - EnhanceVisualData.rangeBonusByLevel)를 곱한다. 없으면(nil · 0) 보너스 없이 기존 값 그대로라
-- 기존 호출부(BalanceSim 등)는 동작이 같다. 보너스가 붙은 값은 아래 getBuffedAttackRange와 같은 상한(어그로 범위 - 여유값)에서 자른다.
local function safeMaxRange()
	return WorldConfig.aggro.rangeStuds - CombatConfig.rangeBuffAggroMarginStuds
end

function PlayerCombat.getAttackRange(classId, weaponLevel)
	local class = ClassData.classes[classId]
	local baseRange = CombatConfig.attackRangeStuds * class.rangeMultiplier
	local bonus = EnhanceEffect.getRangeBonus(classId, weaponLevel)
	if bonus <= 0 then
		return baseRange
	end
	return math.min(baseRange * (1 + bonus), safeMaxRange())
end

-- 사거리 버프(20-4 [2], 활 백스텝샷)가 걸렸을 때 실제로 쓸 사거리. getAttackRange에
-- rangeMultiplier를 그대로 곱하지 않는다 - WorldConfig.aggro.rangeStuds(19-2가 "몬스터가
-- 어그로하기 전에 때리는 무한 안전 사냥"을 막으려고 사거리보다 일부러 크게 잡아 둔 값)를
-- 넘으면 그 안전장치가 깨진다. 어그로 범위에서 CombatConfig.rangeBuffAggroMarginStuds만큼
-- 뺀 선을 상한으로 자른다 - 서버(AttackServer, 실제 대상 판정)와 클라이언트(AimTarget,
-- 조준 표시)가 같은 함수를 써야 화면과 실제 판정이 어긋나지 않는다(getAttackRange와 같은
-- 이유). rangeMultiplier가 없거나 1 이하면(버프 없음) 기존 사거리 그대로 - 기존 호출부
-- 동작을 안 바꾼다.
-- weaponLevel(S08) - 강화 사거리 보너스가 붙은 사거리에 버프 배율을 곱하고, 같은 상한에서 자른다(강화 +20 활 24.0 × 백스텝샷 2 → 24.6).
function PlayerCombat.getBuffedAttackRange(classId, rangeMultiplier, weaponLevel)
	local baseRange = PlayerCombat.getAttackRange(classId, weaponLevel)
	if not rangeMultiplier or rangeMultiplier <= 1 then
		return baseRange
	end
	return math.min(baseRange * rangeMultiplier, safeMaxRange())
end

-- defensePercentBonus(23-3, 보석 "심판의 표식") - 갑옷 보너스까지 합친 방어력 전체에
-- ×(1+x)로 곱한다(attackPercentBonus가 getAttack 전체 결과에 곱하는 것과 같은 자리 -
-- 기본 0이라 기존 2-인자 호출부(BalanceSim 등)는 그대로 동작한다). GemData.
-- survivalReductionAtAnchor 주석 참고 - 방어력은 수확체감 축이라 이 값이 다른 보석 축
-- (공격력%·공속%·최대체력%)보다 커야 같은 만큼 생존에 기여한다.
function PlayerCombat.getDefense(classId, equipmentDefenseBonus, defensePercentBonus)
	local class = ClassData.classes[classId]
	return (CombatConfig.playerDefense + (equipmentDefenseBonus or 0)) * class.def * (1 + (defensePercentBonus or 0))
end

-- 공격 쿨다운 = 기본 쿨다운 ÷ (클래스 공격속도 배율 × 신발 공속 배율 × 버프 공속 배율)
-- (atkSpeed·배율이 클수록 빠르다 - 웹 main.js calcAttackInterval과 같은 나눗셈 방향).
-- speedPercentBonus는 신발 미착용이면 0이 들어와 배율이 1이 되므로 기존 호출부와 결과가
-- 똑같다. buffSpeedMultiplier(20-2b, 기본 1) - 활 속사처럼 "치명타 확률에 비례해 최대
-- 2.5배" 같은 자기 버프가 있을 때 호출부가 BuffState에서 읽어 넘긴다(신발과 같은
-- 자리 - 곱셈 지점이 흩어지면 나중에 또 다른 공속 버프가 생겼을 때 어디에 곱해야
-- 할지 매번 찾아야 한다).
function PlayerCombat.getAttackCooldown(classId, speedPercentBonus, buffSpeedMultiplier)
	local class = ClassData.classes[classId]
	return CombatConfig.attackCooldownSeconds
		/ (class.atkSpeed * PlayerCombat.getSpeedMultiplier(speedPercentBonus) * (buffSpeedMultiplier or 1))
end

return PlayerCombat
