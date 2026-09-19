-- 방지권 상점 RemoteEvent 연결(28-1 S05). 클라이언트는 "이 종류를 사겠다"는 요청만 보낸다 - 가격 계산 · 강화대 근접 확인 · 골드 차감 · 즉시 저장은 전부 서버의
-- ProtectionTickets.tryBuy가 한 번의 동기 흐름으로 처리한다(UI는 S07 - 이 세션은 "/gg ticket buy <kind>"가 같은 함수를 부른다).
--   ProtectionTicketBuyRequest(kind)      - 클라 → 서버 구매 요청
--   ProtectionTicketBuyResult(payload)    - 서버 → 클라 { ok, kind, reason 또는 price, tickets }
--   ProtectionTicketPriceRequest          - RemoteFunction: 가격 조회 → { drop, reset, accountBestStage }
-- (ProtectionTicketGranted는 보스 첫 클리어 지급 알림이라 ProtectionTickets 모듈이 만든다.)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)
local ProtectionTickets = require(script.Parent.ProtectionTickets)

local buyRequest = Instance.new("RemoteEvent")
buyRequest.Name = "ProtectionTicketBuyRequest"
buyRequest.Parent = ReplicatedStorage

local buyResult = Instance.new("RemoteEvent")
buyResult.Name = "ProtectionTicketBuyResult"
buyResult.Parent = ReplicatedStorage

local priceRequest = Instance.new("RemoteFunction")
priceRequest.Name = "ProtectionTicketPriceRequest"
priceRequest.Parent = ReplicatedStorage

buyRequest.OnServerEvent:Connect(function(player, kind)
	local ok, priceOrReason = ProtectionTickets.tryBuy(player, kind)
	buyResult:FireClient(player, {
		ok = ok,
		kind = kind,
		price = ok and priceOrReason or nil,
		reason = (not ok) and priceOrReason or nil,
		tickets = { drop = PlayerProfile.getProtectionTicket(player, "drop"), reset = PlayerProfile.getProtectionTicket(player, "reset") },
	})
end)

priceRequest.OnServerInvoke = function(player)
	return ProtectionTickets.getPrices(player)
end
