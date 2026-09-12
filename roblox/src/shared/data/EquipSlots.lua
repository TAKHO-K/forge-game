-- 드랍·장착 가능한 장비 부위 단일 출처(16-6, 16-5에서 예고한 EquipSlots.lua). 드랍 판정
-- (Loot.rollItemPart)·장비창 UI(InventoryUI 좌측 장비 패널·보관함 격자)·스탯 합산
-- (PlayerCombat)이 전부 이 목록만 읽어야 한다 - 부위 이름을 하드코딩한 곳이 있으면 안
-- 된다는 지시를 그대로 따른다.
--
-- 무기는 여기 없다 - 16-5/16-6 조사로 이미 확인했듯 웹도 무기를 드랍하지 않는다(강화대
-- 전용 시스템, ITEM_PARTS에 weapon 자체가 없음). 장비창 좌측 패널은 무기 슬롯을 따로
-- 하나 더 붙여서 보여주지만(InventoryUI.client.lua), 그건 "표시"의 문제고 "드랍·장착
-- 가능한 부위"는 여전히 이 셋뿐이다.
--
-- statType/baseValue는 웹 data/items.js ITEM_PART_BASE_STAT을 그대로 옮긴다:
--   갑옷 = 방어력 flat 가산, 장갑 = 공격력 비율(%), 신발 = 이동+공격속도 비율(%).
-- 갑옷의 실제 base는 여기 2가 아니라 ArmorData.baseDefense(=CombatConfig.playerDefense=5)를
-- 쓴다 - 12-1이 이미 "일반 등급 갑옷 하나가 기본 방어력만큼 더해준다"는 체감 기준으로
-- 의도적으로 맞춘 값이라(ArmorData.lua 주석) 이번에 덮어쓰지 않는다. 장갑·신발은 이
-- 프로젝트에 처음 생기는 부위라 웹 base(0.15)를 그대로 쓴다.
return {
	order = { "armor", "gloves", "shoes" },

	statType = {
		armor = "defenseFlat",
		gloves = "attackPercent",
		shoes = "speedPercent",
	},

	baseValue = {
		gloves = 0.15,
		shoes = 0.15,
		-- armor는 ArmorData.baseDefense를 쓴다(위 주석) - 여기 없는 게 의도적이다.
	},
}
