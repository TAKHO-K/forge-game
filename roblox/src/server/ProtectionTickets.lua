-- 방지권 상점 · 보스 계정 첫 클리어 지급(28-1 S05, PRD 20.72 [1-3] · 20.73 [4-1]). RemoteEvent 연결은 ProtectionTicketServer.server.lua가 하고, 판정은 전부 여기 함수
-- 하나씩이다 - 자동 검증(EnhanceVerify)과 DevTools("/gg ticket buy")가 스크립트를 require할 수 없어서(Script는 모듈이 아니다) 같은 함수를 바로 부를 수 있게 뒀다.
-- 가격 · 지급 식은 shared/Enhance.lua(getProtectionPrice · getBossGrant)와 EnhanceConfig.protection이 유일한 출처다 - 여기엔 숫자가 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local ImmediateSave = require(script.Parent.ImmediateSave)
local PlayerProfile = require(script.Parent.PlayerProfile)

local ProtectionTickets = {}

-- 보스 계정 첫 클리어 지급 알림(kind, count, stage) - 방금 얼마를 받았다는 일회성 연출 신호(클라 MaterialHud가 재료 팝업과 같은 모양으로 띄운다). 보유 장수 자체는
-- Attribute(ProtectionDrop · ProtectionReset)가 유일한 소스다. 재료의 MaterialGained와 같은 패턴(모듈 로드 때 만든다).
local granted = Instance.new("RemoteEvent")
granted.Name = "ProtectionTicketGranted"
granted.Parent = ReplicatedStorage

local function isNearStation(rootPart)
	local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	return (rootPart.Position - stationPosition).Magnitude <= WorldConfig.enhance.interactionRangeStuds
end

local function isKind(kind)
	return kind == "drop" or kind == "reset"
end

-- 두 방지권의 지금 상점가(골드). 기준은 지금 서 있는 스테이지가 아니라 **계정 최고 스테이지**다(스테이지 1로 내려가 싸게 사는 구멍을 막는다 - 옵션 변환권과 같은 모양).
-- 반환: { drop = n, reset = n, accountBestStage = s } - ProtectionTicketPriceRequest가 그대로 돌려주는 모양이다.
function ProtectionTickets.getPrices(player)
	local accountBestStage = PlayerProfile.getAccountBestStage(player)
	return {
		drop = Enhance.getProtectionPrice("drop", accountBestStage),
		reset = Enhance.getProtectionPrice("reset", accountBestStage),
		accountBestStage = accountBestStage,
	}
end

-- 골드로 1장을 산다. 반환: ok, reason(실패 사유 - "invalid_kind" · "not_near_station" · "insufficient_gold") 또는 가격. 가격은 클라가 보낸 값을 안 믿고 매번 다시
-- 계산한다. 강화대 근접이 필수다(GemServer의 변환권 구매와 같은 식). 성공하면 즉시 저장을 요청한다(골드가 빠지는 되돌릴 수 없는 사건).
function ProtectionTickets.tryBuy(player, kind)
	if not isKind(kind) then
		return false, "invalid_kind"
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return false, "not_near_station"
	end
	local price = Enhance.getProtectionPrice(kind, PlayerProfile.getAccountBestStage(player))
	if not PlayerProfile.trySpendGold(player, price) then
		return false, "insufficient_gold"
	end
	PlayerProfile.addProtectionTicket(player, kind, 1)
	ImmediateSave.request(player)
	print(("[forge-game] 방지권 구매: %s - %s (비용 %d)"):format(player.Name, kind, price))
	return true, price
end

-- 보스 스테이지 stage의 계정 첫 클리어 지급. handleBossDeath가 **기여 10%를 넘긴 수령자마다** 부른다(호출 뒤에 이미 ImmediateSave.request가 있어 여기서 저장을 또 요청하지
-- 않는다). 지급 스테이지(Enhance.getBossGrant)이고 그 스테이지를 아직 안 받았을 때만 지급 + 표시(계정 단위 - 직업별 bossFirstClearStages와 별개 집합이라 부캐로 같은
-- 스테이지를 다시 깨도 안 나온다). 반환: 지급한 하락 장수, 초기화 장수(안 줬으면 0, 0).
function ProtectionTickets.grantForBoss(player, stage)
	if PlayerProfile.hasClaimedProtectionStage(player, stage) then
		return 0, 0
	end
	local dropCount, resetCount = Enhance.getBossGrant(stage)
	if dropCount == 0 and resetCount == 0 then
		return 0, 0
	end
	PlayerProfile.markProtectionStageClaimed(player, stage)
	for kind, count in pairs({ drop = dropCount, reset = resetCount }) do
		if count > 0 then
			PlayerProfile.addProtectionTicket(player, kind, count)
			granted:FireClient(player, kind, count, stage)
		end
	end
	print(("[forge-game] 방지권 지급: %s - 스테이지 %d 보스 첫 클리어(계정) - 하락 %d · 초기화 %d"):format(player.Name, stage, dropCount, resetCount))
	return dropCount, resetCount
end

return ProtectionTickets
