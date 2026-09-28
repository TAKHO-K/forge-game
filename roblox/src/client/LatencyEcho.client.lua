-- C4 파트 0: 서버 왕복 핑 측정 표식을 받자마자 돌려준다(server/RangedLagAssist - 원거리 보정 반경).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local echo = ReplicatedStorage:WaitForChild("LatencyEcho")
echo.OnClientEvent:Connect(function(token)
	echo:FireServer(token)
end)
