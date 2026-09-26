-- 서버 순간이동 도착 알림(M1-2c). 모든 서버 순간이동(세계 이동 Travel · 보스 아레나 입장 / 복귀 · 심연 복귀 · 아레나 이탈 복귀)이 부른다.
--   mark = Player Attribute ArrivalAt(서버 시각) · ArrivalPos → 클라 ArrivalHold가 발 아래 발판이 아직 안 들어왔으면(스트리밍) 도착 자리에 붙잡고 기다린다.
--   preloadAsync = 기다리지 않는 RequestStreamAroundAsync(보스 입장처럼 한 틱 안에 여러 명을 옮기는 곳 - 순간이동 순서 · 시각을 바꾸지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local TeleportArrival = {}
TeleportArrival.count = 0

function TeleportArrival.mark(player, position)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	TeleportArrival.count += 1
	player:SetAttribute("ArrivalPos", position)
	player:SetAttribute("ArrivalAt", Workspace:GetServerTimeNow())
end

function TeleportArrival.preloadAsync(player, position)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(position, WorldMapData.travel.streamTimeoutSeconds)
		end)
	end)
end

return TeleportArrival
