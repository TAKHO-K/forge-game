-- 갑옷 드랍 판정 + 방어력 계산이 실제로 곱해지는 유일한 위치(12-1, PlayerCombat·
-- InfiniteStage와 같은 이유). 판정은 서버(AttackServer.server.lua)에서만 호출한다 -
-- Random.new() 인스턴스를 쓴다(math.random은 전역 시드를 공유한다, 10-4와 같은 이유).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local lootRng = Random.new()

local Loot = {}

-- 드랍 판정 1회(슬롯1만, 슬롯2 다중 드랍은 범위 밖). 드랍이 없으면 nil, 있으면
-- { grade = "normal"/"rare", dropStage = 몬스터를 잡은 스테이지 } - dropStage를
-- 아이템에 각인해 두어야 나중에 방어력을 계산할 수 있다(장비 레벨 각인과 같은 개념).
function Loot.rollArmorDrop(monsterStage)
	if lootRng:NextNumber() >= ArmorData.dropChance then
		return nil
	end

	local roll = lootRng:NextNumber()
	local acc = 0
	for _, entry in ipairs(ArmorData.gradeRollTable) do
		acc += entry.chance
		if roll < acc then
			return { grade = entry.grade, dropStage = monsterStage }
		end
	end

	return nil -- 확률 합이 1 미만인 경우의 방어적 처리(지금 표는 정확히 1.0)
end

-- 장비 방어력 보너스. item이 nil이면(미착용) 0 - PlayerCombat.getDefense의
-- equipmentDefenseBonus 자리에 그대로 넘긴다.
function Loot.getArmorDefense(item)
	if not item then
		return 0
	end
	local grade = ArmorData.grades[item.grade]
	return ArmorData.baseDefense * grade.defenseGradeMultiplier * InfiniteStage.getMultiplier(item.dropStage)
end

return Loot
