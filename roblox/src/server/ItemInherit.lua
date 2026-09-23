-- 장비 계승 요청 한 건의 서버 판정(P2.5b A - ItemEquip · GemEquip과 같은 모양). 규칙은 PlayerProfile.inheritItem · previewInherit(→ shared/Inherit)이고, 이 모듈은 요청 모양 검사만 앞에 붙인다.
-- 자리 제한 없음(착용 · 해제 · 분해와 같이 어디서나). 자동 검증(P25bVerify)이 같은 함수를 직접 부른다.
--   ItemInherit.handle(player, part, bagIndex, keep) -> success, reason(성공이면 환급 종류 "gem" | "gold")
--   ItemInherit.preview(player, part, bagIndex) -> 표 | nil, reason
--   이유 코드: invalid(인자 모양 · 프로필 없음) + PlayerProfile이 주는 no_class · not_equipped · not_found · part_mismatch · a_locked · locked · b_grade_lower · no_gold.

local PlayerProfile = require(script.Parent.PlayerProfile)

local ItemInherit = {}

local PARTS = { armor = true, gloves = true, shoes = true }

local function validShape(player, part, bagIndex)
	return PlayerProfile.getProfile(player) ~= nil and type(part) == "string" and PARTS[part] == true and type(bagIndex) == "number" and bagIndex == bagIndex
end

function ItemInherit.handle(player, part, bagIndex, keep)
	if not validShape(player, part, bagIndex) or type(keep) ~= "string" then
		return false, "invalid"
	end
	local success, reason = PlayerProfile.inheritItem(player, part, math.floor(bagIndex), keep)
	return success == true, reason
end

function ItemInherit.preview(player, part, bagIndex)
	if not validShape(player, part, bagIndex) then
		return nil, "invalid"
	end
	return PlayerProfile.previewInherit(player, part, math.floor(bagIndex))
end

return ItemInherit
