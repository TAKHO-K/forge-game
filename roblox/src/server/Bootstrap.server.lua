-- Rojo 동기화 확인용 스크립트. 게임 로직 아님 - 환경 구축 마일스톤 검증 전용.
local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local Players = game:GetService("Players")

print("[forge-game] 서버 스크립트 로드됨 - Rojo 동기화 확인")

Players.PlayerAdded:Connect(function(player)
	print("[forge-game] 플레이어 입장: " .. player.Name)
end)
