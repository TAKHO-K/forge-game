-- 강화 RemoteEvent 연결(10-2). 클라이언트는 "강화하겠다"는 요청만 보낸다(인자는 방지권 토글 2개뿐 - S05) - 강화대 근접 확인·상한 확인·골드 확인/차감·확률 판정·결과
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

-- 30-0 S08: 20강+ 성공 공지(같은 서버 전원 - 인자 = 표시 이름 · 새 단계). 채팅 시스템 메시지로 바꾸는 것은 클라(client/EnhanceAnnounceClient.client.lua).
local enhanceAnnounce = Instance.new("RemoteEvent")
enhanceAnnounce.Name = "EnhanceAnnounce"
enhanceAnnounce.Parent = ReplicatedStorage

EnhanceService.init(enhanceResult, enhanceAnnounce)

-- 28-1 S05: 요청 인자 2개(useDropTicket · useResetTicket - boolean, 없으면 false). 값 검증은 EnhanceService가 한다(boolean true만 인정).
enhanceRequest.OnServerEvent:Connect(function(player, useDropTicket, useResetTicket)
	EnhanceService.handleRequest(player, useDropTicket, useResetTicket)
end)
