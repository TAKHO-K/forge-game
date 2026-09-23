-- 보석 가공 요청 한 건의 서버 판정(P2.5b C · B - GemEquip · GemWorkshop과 같은 모양). 규칙은 PlayerProfile(→ shared/GemCraft)이고, 이 모듈은 요청 모양 검사만 앞에 붙인다.
-- 자리 제한 없음(보석 장착 · 장비 분해와 같이 어디서나). GemServer가 RemoteEvent를 받아 여기로 넘기고, 자동 검증(P25bVerify)이 같은 함수를 직접 부른다.
--   GemCraftRequest.handle(player, action, a, b, c) -> success, reason(실패 이유 코드 | nil), data(성공 결과 표 | nil)
--     action = "dismantle"(a = 가방 index)       → data = { dust }
--              "dismantleBulk"(a = 기준 등급 id) → data = { count, dust }   (대상 0개면 실패 "none")
--   이유 코드: invalid(인자 모양 · 프로필 없음) · no_class · not_found · none.

local PlayerProfile = require(script.Parent.PlayerProfile)

local GemCraftRequest = {}

local function isIndex(value)
	return type(value) == "number" and value == value and value >= 1 and value < math.huge
end

function GemCraftRequest.handle(player, action, a, b, c)
	if not PlayerProfile.getProfile(player) then
		return false, "invalid"
	end
	if action == "dismantle" then
		if not isIndex(a) then
			return false, "invalid"
		end
		local ok, result = PlayerProfile.dismantleGem(player, math.floor(a))
		if not ok then
			return false, result
		end
		return true, nil, { dust = result }
	elseif action == "dismantleBulk" then
		if type(a) ~= "string" then
			return false, "invalid"
		end
		local count, dust = PlayerProfile.dismantleGemsUpTo(player, a)
		if count == 0 then
			return false, "none"
		end
		return true, nil, { count = count, dust = dust }
	end
	return false, "invalid"
end

return GemCraftRequest
