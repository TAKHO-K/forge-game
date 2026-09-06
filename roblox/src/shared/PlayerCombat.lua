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
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)

-- math.random은 전역 시드를 다른 호출과 공유한다 - 치명타 판정만의 독립된 스트림을 쓴다
-- (10-4 지시). 이 모듈은 서버 스크립트(AttackServer 등)에서만 damage 계산 목적으로
-- 호출된다 - 치명타 롤도 그래서 항상 서버에서만 일어난다.
local critRng = Random.new()

local PlayerCombat = {}

function PlayerCombat.getClass(classId)
	return ClassData.classes[classId]
end

-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율(10-2에서 자리만 만들었던
-- classAttackMultiplier=1.0을 여기서 실제 클래스 값으로 대체한다). 치명타를 적용하기 전
-- 기본 데미지다 - calcDamage에 base로 넘긴다.
function PlayerCombat.getAttack(weapon, classId)
	local class = ClassData.classes[classId]
	local weaponData = WeaponData.weapons[weapon.id]
	return Enhance.getPlayerAttack(weaponData, weapon.level, class.atk)
end

-- 치명타 판정 + 적용 - 유일한 위치(10-4 [3]). base는 평타의 getAttack 결과일 수도,
-- 나중에 들어올 스킬의 계수(atk를 대체하는 값)일 수도 있다 - 여기 한 곳에만 크리를
-- 넣어두면 스킬이 들어와도 자동으로 크리가 적용된다(평타 경로에만 붙이지 말라는 지시).
function PlayerCombat.calcDamage(base, classId)
	local class = ClassData.classes[classId]
	local isCrit = critRng:NextNumber() < class.critRate
	local damage = isCrit and base * class.critDmg or base
	return damage, isCrit
end

function PlayerCombat.getDefense(classId, equipmentDefenseBonus)
	local class = ClassData.classes[classId]
	return (CombatConfig.playerDefense + (equipmentDefenseBonus or 0)) * class.def
end

-- 공격 쿨다운 = 기본 쿨다운 ÷ 클래스 공격속도 배율(atkSpeed가 클수록 빠르다 - 웹
-- main.js calcAttackInterval과 같은 나눗셈 방향).
function PlayerCombat.getAttackCooldown(classId)
	local class = ClassData.classes[classId]
	return CombatConfig.attackCooldownSeconds / class.atkSpeed
end

return PlayerCombat
