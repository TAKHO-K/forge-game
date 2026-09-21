-- 보석 공방(S20e) 요청 한 건의 서버 판정 - 변환 · 리롤(옵션 리롤)과 변환권 구매. GemServer가 RemoteEvent를 받아 여기로 넘기고, 자동 검증(GemMerchantVerify)이 같은 함수를 직접 부른다.
-- 규칙 · 비용은 PlayerProfile 그대로다(리롤 = 변환권 1장 소모 · 고대 · 태초만 / 변환권 구매 = 골드). 이 모듈이 앞에 붙이는 것은 요청 모양 검사 + **보석상인 반경 검사**뿐이고,
-- 성공하면 "보석상인을 써 봤다" 기록(hints.gemMerchantUsed)을 남긴다(보석 탭 안내 줄이 줄어든다).
--   이유 코드: invalid(인자 모양이 틀렸다) · out_of_range · no_character(GemMerchantAccess) · PlayerProfile이 주는 no_class · empty_slot · not_found · not_equipped · not_rerollable · no_ticket · no_gold(구매).
--   accessCheck(player) -> true | false, 이유(선택): 반경 판정을 갈아 끼운다(검증이 자리를 옮기지 않고 안 · 밖을 강제할 때). 기본 = GemMerchantAccess.check.

local PlayerProfile = require(script.Parent.PlayerProfile)
local GemMerchantAccess = require(script.Parent.GemMerchantAccess)

local GemWorkshop = {}

local EQUIP_PARTS = { armor = true, gloves = true, shoes = true }

-- 26-3(PRD 20.67 [10]): 리롤 대상 = 홈 5 + 장비 3부위(가방 · 착용). kind="gem"이면 key=슬롯(1~5), "equipped"면 key=부위명(armor/gloves/shoes), "bag"이면 key=인벤토리 index.
-- 반환: 성공 여부(boolean), 실패 이유 코드(string, 성공이면 nil)
function GemWorkshop.reroll(player, kind, key, accessCheck)
	local validShape = (kind == "gem" and type(key) == "number")
		or (kind == "equipped" and type(key) == "string" and EQUIP_PARTS[key] == true)
		or (kind == "bag" and type(key) == "number")
	if not validShape then
		return false, "invalid"
	end
	local near, whyNot = (accessCheck or GemMerchantAccess.check)(player)
	if not near then
		return false, whyNot
	end

	local success, reason
	if kind == "gem" then
		success, reason = PlayerProfile.rerollGemOption(player, math.floor(key))
	elseif kind == "equipped" then
		success, reason = PlayerProfile.rerollEquippedOption(player, key)
	else
		success, reason = PlayerProfile.rerollBagItemOption(player, math.floor(key))
	end
	if not success then
		return false, reason
	end
	PlayerProfile.markGemMerchantUsed(player)
	return true, nil
end

-- 변환권 구매. cost는 서버가 매번 다시 계산한 가격이다(GemServer - 클라가 보낸 값을 믿지 않는다). gradeId = "ancient" | "primordial".
function GemWorkshop.buyTicket(player, gradeId, cost, accessCheck)
	if gradeId ~= "ancient" and gradeId ~= "primordial" then
		return false, "invalid"
	end
	local near, whyNot = (accessCheck or GemMerchantAccess.check)(player)
	if not near then
		return false, whyNot
	end
	if not PlayerProfile.tryBuyOptionRerollTicket(player, gradeId, cost) then
		return false, "no_gold"
	end
	PlayerProfile.markGemMerchantUsed(player)
	return true, nil
end

return GemWorkshop
