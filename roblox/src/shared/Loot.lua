-- 갑옷 드랍 판정 + 방어력 계산이 실제로 곱해지는 유일한 위치(12-1, PlayerCombat·
-- InfiniteStage와 같은 이유). 판정은 서버(AttackServer.server.lua)에서만 호출한다 -
-- Random.new() 인스턴스를 쓴다(math.random은 전역 시드를 공유한다, 10-4와 같은 이유).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)

local lootRng = Random.new()

local Loot = {}

-- gradeRollTable은 순서 배열이라 등급명으로 바로 못 찾는다 - getSellPrice가 "그 등급으로
-- 뽑힐 확률"을 역산할 때 쓴다(13-1). 표가 2줄뿐이라 순회 비용은 무시할 만하다.
local function getGradeChance(gradeId)
	for _, entry in ipairs(ArmorData.gradeRollTable) do
		if entry.grade == gradeId then
			return entry.chance
		end
	end
	return nil
end

-- 부위 균등 랜덤(16-6, 웹 core/loot.js rollItemPart와 동등) - EquipSlots.order(갑옷/장갑/
-- 신발) 3개 중 하나를 똑같은 확률로 고른다. 무기는 대상이 아니다(EquipSlots.lua 주석 참고).
function Loot.rollItemPart()
	local order = EquipSlots.order
	return order[lootRng:NextInteger(1, #order)]
end

-- 드랍 판정 1회(슬롯1만, 슬롯2 다중 드랍은 범위 밖). 드랍이 없으면 nil, 있으면
-- { grade, part, dropStage, itemLevel, locked = false }. part는 16-6에서 추가 - 웹처럼
-- 드랍 순간엔 등급만 정해지고 부위는 균등 랜덤이다(rollItemPart). dropStage(몬스터를 잡은
-- 스테이지)와 itemLevel(획득 시점 캐릭터 레벨)은 서로 다른 정보라 둘 다 남긴다 -
-- dropStage는 getSellPrice의 "그 스테이지에서 사냥했다"는 경제적 맥락에, itemLevel은
-- getArmorDefense류의 실제 파워 계산에 쓰인다(13-2 - 12-1이 캐릭터 레벨 축이 없어
-- dropStage를 대체재로 썼던 것을, 축이 생긴 지금 원래 설계(PRD 20.11-4)대로 되돌린다).
-- locked는 13-1에서 추가 - 아이템이 생성되는 이 한 지점에서만 기본값을 정하면, 기존
-- 저장분은 SaveSystem.migrate()가 따로 채운다.
function Loot.rollArmorDrop(monsterStage, itemLevel)
	if lootRng:NextNumber() >= ArmorData.dropChance then
		return nil
	end

	local roll = lootRng:NextNumber()
	local acc = 0
	for _, entry in ipairs(ArmorData.gradeRollTable) do
		acc += entry.chance
		if roll < acc then
			return {
				grade = entry.grade,
				part = Loot.rollItemPart(),
				dropStage = monsterStage,
				itemLevel = itemLevel,
				locked = false,
			}
		end
	end

	return nil -- 확률 합이 1 미만인 경우의 방어적 처리(지금 표는 정확히 1.0)
end

-- 보스 확정 드랍(15-1, 지시 [4] "드랍이 달라야 하는가"). 잡몹과 같은 25% 확률·등급 굴림을
-- 그대로 쓰면 보스를 잡을 경제적 이유가 약하다 - 100%로 확정하고 등급도 이 프로젝트에
-- 있는 최고 등급(ArmorData.gradeOrder의 마지막 항목, 지금은 "희귀")을 그대로 지급한다.
-- 등급이 나중에 늘어도(영웅·전설 등) gradeOrder 마지막 항목을 그대로 참조하므로 이
-- 함수를 다시 고칠 필요가 없다. 부위는 잡몹과 같은 균등 랜덤(16-6).
function Loot.rollBossArmorDrop(monsterStage, itemLevel)
	local topGrade = ArmorData.gradeOrder[#ArmorData.gradeOrder]
	return {
		grade = topGrade,
		part = Loot.rollItemPart(),
		dropStage = monsterStage,
		itemLevel = itemLevel,
		locked = false,
	}
end

-- 장비 방어력 보너스(갑옷 전용). item이 nil이면(미착용) 0 - PlayerCombat.getDefense의
-- equipmentDefenseBonus 자리에 그대로 넘긴다. 13-2부터 dropStage가 아니라 itemLevel(획득
-- 시점 캐릭터 레벨) 기준이다 - PRD 20.11-4가 정의한 "아이템 레벨 시스템" 그대로. 갑옷만
-- ArmorData의 전용 배율표(defenseGradeMultiplier)를 쓴다 - 16-5 조사로 확인한 대로 이
-- 표는 장갑·신발의 일반 배율(ItemVisualData.gradeVisuals.statMultiplier)과 축이 다르다.
function Loot.getArmorDefense(item)
	if not item then
		return 0
	end
	local grade = ArmorData.grades[item.grade]
	return ArmorData.baseDefense * grade.defenseGradeMultiplier * CharacterLevel.getItemLevelMultiplier(item.itemLevel)
end

-- 장갑 공격력 비율 보너스(16-6, 웹 ITEM_PART_BASE_STAT.gloves 그대로 이식). item이 nil이면
-- 0. 갑옷과 달리 일반 등급 배율(ItemVisualData.gradeVisuals.statMultiplier, 1.0~15.0)을
-- 쓴다 - 갑옷 전용표(위 getArmorDefense)와 절대 섞지 않는다(단일 출처 원칙, 16-5 확인).
function Loot.getGlovesAttackPercent(item)
	if not item then
		return 0
	end
	local visual = ItemVisualData.gradeVisuals[item.grade]
	return EquipSlots.baseValue.gloves * visual.statMultiplier * CharacterLevel.getItemLevelMultiplier(item.itemLevel)
end

-- 신발 이동+공격속도 비율 보너스(16-6, 웹 ITEM_PART_BASE_STAT.shoes 그대로 이식) -
-- getGlovesAttackPercent와 완전히 같은 형태, 부위만 다르다(웹도 base값이 0.15로 같다).
function Loot.getShoesSpeedPercent(item)
	if not item then
		return 0
	end
	local visual = ItemVisualData.gradeVisuals[item.grade]
	return EquipSlots.baseValue.shoes * visual.statMultiplier * CharacterLevel.getItemLevelMultiplier(item.itemLevel)
end

-- 판매가(13-1) - 이 관계식이 유일한 계산 지점이다(서버 InventoryServer의 SellRequest 처리·
-- 클라이언트 UI 표시 둘 다 이 함수를 그대로 호출해야 어긋나지 않는다, getArmorDefense와 같은 원칙).
--   기대 처치 수 = 1 / (dropChance × 그 등급 확률)  - "이 등급 하나를 얻으려면 평균 몇 마리를
--     잡아야 하는가"
--   처치당 골드 = InfiniteStage.getGoldReward(tier1 기본 골드, 그 아이템을 주운 스테이지)
--   판매가 = 기대 처치 수 × 처치당 골드 × ArmorData.sellRecoveryRate
-- 13-2에서 getArmorDefense는 itemLevel 기준으로 바뀌었지만 이 함수는 dropStage를 그대로
-- 쓴다 - 의도적이다. "처치당 골드"는 아이템의 파워가 아니라 "그 스테이지에서 사냥했다"는
-- 경제적 맥락(거기서 얻을 수 있었던 골드)을 나타내는 값이라 itemLevel과는 다른 질문에
-- 답한다. 등급이 오르면 기대 처치 수가 커지고, 드랍 스테이지가 오르면 처치당 골드가
-- 커진다 - 회수율 하나만 상수로 고정해 두면 두 축 모두 판매가에 자동으로 반영된다
-- (ArmorData.sellRecoveryRate 주석에 회수율 값 근거).
function Loot.getSellPrice(item)
	if not item then
		return 0
	end
	local gradeChance = getGradeChance(item.grade)
	if not gradeChance then
		return 0
	end
	local expectedKills = 1 / (ArmorData.dropChance * gradeChance)
	local goldPerKill = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, item.dropStage)
	return math.floor(expectedKills * goldPerKill * ArmorData.sellRecoveryRate)
end

return Loot
