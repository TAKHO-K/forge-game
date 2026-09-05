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

local PlayerCombat = {}

function PlayerCombat.getClass(classId)
	return ClassData.classes[classId]
end

-- 공격력 = 무기 기본값 × 강화 배율 × 등급 배율 × 클래스 배율(10-2에서 자리만 만들었던
-- classAttackMultiplier=1.0을 여기서 실제 클래스 값으로 대체한다).
function PlayerCombat.getAttack(weapon, classId)
	local class = ClassData.classes[classId]
	local weaponData = WeaponData.weapons[weapon.id]
	return Enhance.getPlayerAttack(weaponData, weapon.level, class.atk)
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
