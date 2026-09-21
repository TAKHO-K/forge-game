-- 보석 장착 요청 한 건의 서버 판정(S20c: GemServer.server.lua에서 분리 - 자동 검증(GemFlowVerify)이 실제 판정 경로를 직접 부를 수 있게).
-- 규칙은 PlayerProfile.equipGem 그대로다(장착 = 항상 교체 · 비용 없음 · 해제 없음). 이 모듈은 요청 모양 검사만 앞에 붙이고, 어떤 검사에서 거절됐는지 이유 코드로 돌려준다.
--   이유 코드: invalid(인자 모양이 틀렸다) · no_class · slot_locked · not_found · grade_too_high(마지막 넷은 PlayerProfile.equipGem이 준다).
-- S20e: 자리 제한이 없다 - 옛 강화대 12stud 검사(far)를 제거했다. 보석 장착 · 교체는 어디서나 된다(변환 · 리롤만 보석상인 - GemWorkshop).

local PlayerProfile = require(script.Parent.PlayerProfile)

local GemEquip = {}

-- 반환: 성공 여부(boolean), 실패 이유 코드(string, 성공이면 nil)
function GemEquip.handle(player, slot, gemInventoryIndex)
	if type(slot) ~= "number" or type(gemInventoryIndex) ~= "number" then
		return false, "invalid"
	end
	local success, reason = PlayerProfile.equipGem(player, math.floor(slot), math.floor(gemInventoryIndex))
	return success == true, reason
end

return GemEquip
