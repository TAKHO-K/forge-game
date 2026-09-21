-- 장비(갑옷 · 장갑 · 신발) 착용 · 해제 요청의 판정(S20d). 서버 PlayerProfile.equipItem / unequipItem이 이 함수로 거절 여부를 정하고, 클라(ItemActions)가 같은 함수로 미리 보인다 -
-- Gem.socketBlockReason과 같은 방식이다(판정은 서버 권위 · 클라는 표시 · 미리 판정 전용). 규칙은 S20d 전과 같다: 직업이 있어야 하고, 착용은 그 칸에 부위가 있는 아이템이 있어야 하며,
-- 해제는 착용 중이어야 하고 가방에 빈 칸이 있어야 한다(순수 추가라서). 레벨 · 직업 조건은 서버에 없다.
--   이유 코드: no_class(직업 미선택) · not_found(그 칸에 착용할 아이템이 없다) · not_equipped(그 부위에 착용 중인 것이 없다) · full(가방이 가득 차 해제할 수 없다).
-- 요청 모양이 틀린 경우(invalid)는 서버 ItemEquip이 앞에서 거른다.

local Equip = {}

-- 가방 index의 아이템을 착용할 수 있는가. 반환: nil(가능) 또는 이유 코드. 착용은 항상 "교체"라 칸 수가 안 늘어 가방이 가득 차 있어도 된다.
function Equip.equipBlockReason(inventory, index, hasClass)
	if not hasClass then
		return "no_class"
	end
	local item = inventory[index]
	if not item or not item.part then
		return "not_found"
	end
	return nil
end

-- 부위(part)를 해제할 수 있는가. equipped = 부위 -> 착용 중 아이템 표 · bagCount = 가방의 지금 아이템 수 · slots = 가방 칸 수.
function Equip.unequipBlockReason(equipped, part, bagCount, slots, hasClass)
	if not hasClass then
		return "no_class"
	end
	if not equipped[part] then
		return "not_equipped"
	end
	if bagCount >= slots then
		return "full"
	end
	return nil
end

return Equip
