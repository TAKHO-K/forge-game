-- QUEUE-ALL10 블록 2 초월 계승 창구: RemoteFunction TranscendRequest(action, arg) → TranscendService.handle 결과 표(창이 결과 · 화면 표를 그대로 그린다).
--   요청 제한 = RequestGate.invoke(공통 입구 · RequestLimitConfig.TranscendRequest). 스위치(All10Economy)가 꺼져 있으면 서비스가 "disabled"를 돌려준다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RequestGate = require(script.Parent.RequestGate)
local TranscendService = require(script.Parent.TranscendService)
require(script.Parent.TranscendFirsts).start() -- QUEUE-ALL9E1 0-5 초월 최초 달성(배너 Remote · 다른 서버 구독)

local request = Instance.new("RemoteFunction")
request.Name = "TranscendRequest"
request.Parent = ReplicatedStorage

request.OnServerInvoke = function(player, action, arg)
	if type(action) ~= "string" then
		return nil
	end
	return RequestGate.invoke(player, "TranscendRequest", action .. "|" .. string.sub(tostring(arg), 1, 64), function()
		local result = TranscendService.handle(player, action, arg)
		if action == "confirm" or action == "enhance" then -- MENU2 판정 4: 계승 · 초월 강화 연출 중 메뉴 이동 금지
			require(script.Parent.MenuBlock).mark(player, "inherit")
		end
		return result
	end)
end
