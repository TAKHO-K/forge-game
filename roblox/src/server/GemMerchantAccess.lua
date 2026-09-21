-- 보석 변환 · 리롤을 어디서 요청할 수 있는가(S20e) - 서버 판정 한 곳. 커뮤니티 센터 보석상인 반경 안에서만 된다(WorldConfig.gemMerchant). 강화대는 더 이상 관계없다.
-- 클라의 ProximityPrompt 거리 · "보석 공방" 창이 열려 있는지는 믿지 않는다 - 요청이 올 때마다 그 시점의 캐릭터 위치를 다시 잰다(RebirthAccess와 같은 원칙).
--   position() = 보석상인 자리(월드 좌표 - HuntingGround가 모델을 이 좌표에 놓는다) · evaluate = 순수 판정(검증 (가)가 합성 위치로 부른다) · check = 실제 Player의 캐릭터 위치로 evaluate.
-- 이유 코드: no_character(캐릭터 · 루트 파트 없음) · out_of_range(반경 밖).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local GemMerchantAccess = {}

function GemMerchantAccess.position()
	return WorldConfig.huntingGround.center + WorldConfig.zones.community.center + WorldConfig.gemMerchant.offsetFromCommunity
end

-- 순수 판정. position은 Vector3 또는 nil. 반환: true | false, 이유 코드.
function GemMerchantAccess.evaluate(position)
	if not position then
		return false, "no_character"
	end
	if (position - GemMerchantAccess.position()).Magnitude > WorldConfig.gemMerchant.interactionRangeStuds then
		return false, "out_of_range"
	end
	return true
end

function GemMerchantAccess.check(player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	return GemMerchantAccess.evaluate(rootPart and rootPart.Position or nil)
end

return GemMerchantAccess
