-- 드랍표 조회 RemoteFunction(P2 E1 - 화면은 P4에서 만든다). 클라가 tier(1 ~ 6)를 보내면 그 플레이어 기준 드랍표(DropTableQuery.forPlayer)를 돌려준다.
-- 판정 · 지급과는 무관한 읽기 전용이다. 인자 모양이 틀리면 nil, 같은 플레이어가 너무 자주 부르면 nil(요청 간격 = CombatConfig 값이 아니라 입력 보호라 여기 둔다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local DropTableQuery = require(script.Parent.DropTableQuery)

local MIN_INTERVAL_SECONDS = 0.2

local query = Instance.new("RemoteFunction")
query.Name = "DropTableQuery"
query.Parent = ReplicatedStorage

local lastAt = {}

query.OnServerInvoke = function(player, tierIndex)
	if type(tierIndex) ~= "number" or tierIndex ~= math.floor(tierIndex) or tierIndex < 1 or tierIndex > #MonsterData.tierOrder then
		return nil
	end
	local now = os.clock()
	if lastAt[player] and now - lastAt[player] < MIN_INTERVAL_SECONDS then
		return nil
	end
	lastAt[player] = now
	return DropTableQuery.forPlayer(player, tierIndex)
end

Players.PlayerRemoving:Connect(function(player)
	lastAt[player] = nil
end)
