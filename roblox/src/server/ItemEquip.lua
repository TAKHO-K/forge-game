-- 장비 착용 · 해제 요청 한 건의 서버 판정(S20d: InventoryServer.server.lua에서 분리 - 자동 검증(ItemFlowVerify)이 실제 판정 경로를 직접 부를 수 있게. GemEquip과 같은 모양).
-- 규칙은 PlayerProfile.equipItem / unequipItem 그대로다(착용 = 항상 교체 · 비용 없음 · 해제는 가방에 빈 칸이 있을 때만). 이 모듈은 요청 모양 검사만 앞에 붙이고, 이유 코드를 돌려준다.
--   이유 코드: invalid(인자 모양이 틀렸다 · 프로필이 아직 없다) · no_class · not_found(착용) · not_equipped · full(해제) - 뒤 넷은 PlayerProfile이 shared/Equip 판정으로 준다.
--   ItemEquip.handle(player, action, arg) -> success(boolean), reason(string | nil)   action = "equip"(arg = 가방 index) | "unequip"(arg = 부위 이름)

local PlayerProfile = require(script.Parent.PlayerProfile)

local ItemEquip = {}

function ItemEquip.handle(player, action, arg)
	if not PlayerProfile.getProfile(player) then
		return false, "invalid" -- 프로필 로드가 아직 안 끝났다
	end
	local success, reason
	if action == "equip" then
		if type(arg) ~= "number" then
			return false, "invalid"
		end
		success, reason = PlayerProfile.equipItem(player, math.floor(arg))
	elseif action == "unequip" then
		if type(arg) ~= "string" then
			return false, "invalid"
		end
		success, reason = PlayerProfile.unequipItem(player, arg)
	else
		return false, "invalid"
	end
	return success == true, reason
end

return ItemEquip
