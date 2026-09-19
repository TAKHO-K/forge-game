-- 강화 RemoteEvent 연결(10-2). 클라이언트는 "강화하겠다"는 요청만 보낸다(RemoteEvent 인자 없음) - 강화대 근접 확인·상한 확인·골드 확인/차감·확률 판정·결과
-- 반영은 전부 서버의 EnhanceService.handleRequest(28-1 S03에서 이 파일의 핸들러 본문을 옮겼다 - 원자성 설명도 거기 있다)가 한 번의 동기 흐름으로 처리한다.
-- 즉시저장 스로틀 자체는 ImmediateSave.lua에 있다(10-3부터 클래스 선택과 공유).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceService = require(script.Parent.EnhanceService)

local enhanceRequest = Instance.new("RemoteEvent")
enhanceRequest.Name = "EnhanceRequest"
enhanceRequest.Parent = ReplicatedStorage

local enhanceResult = Instance.new("RemoteEvent")
enhanceResult.Name = "EnhanceResult"
enhanceResult.Parent = ReplicatedStorage

EnhanceService.init(enhanceResult)

enhanceRequest.OnServerEvent:Connect(function(player)
	EnhanceService.handleRequest(player)
end)
