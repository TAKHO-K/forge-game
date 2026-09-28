-- C4 파트 0(W3b 결정 8): 원거리 서버 보정 반경을 지연만큼 넓힌다.
--   화면 속 몹은 서버보다 지연만큼 옛 자리에 있다 - 움직이는 몹을 겨눈 조준점이 서버 경로에서 빗나가는 몫을 반경으로 받는다.
--   extra(player, model) = 몹 수평 속도 × 편도 지연(왕복 핑 × lagOneWayScale) - AimPicker.pickPath의 assistExtra.
--   왕복 핑 = 서버가 보낸 표식을 클라(client/LatencyEcho)가 바로 돌려준 시간(시뮬 지연 IncomingReplicationLag도 들어간다 - GetNetworkPing은 못 잰다).
--   몹 속도 = 서버 PivotTo 이동이라 물리 속도가 0 → 표본 간격마다 위치 차로 잰다(표는 매번 새로 - 사라진 몹이 안 남는다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MonsterState = require(script.Parent.MonsterState)

local A = CombatConfig.rangedAim
local RangedLagAssist = {}

local echo = Instance.new("RemoteEvent")
echo.Name = "LatencyEcho"
echo.Parent = ReplicatedStorage

local pending = {} -- player -> { [token] = sentAt } (C5 파트 0-1 리뷰 3: 표식마다 - 왕복이 탐침 간격을 넘는 사람의 늦은 응답도 표본이 된다. 옛 코드는 매 탐침이 덮어써 그 사람은 표본 0 = 보정 0)
local samples = {} -- player -> { rtt... } (최근 lagSampleCount)

echo.OnServerEvent:Connect(function(player, token)
	local p = pending[player]
	local sentAt = p and type(token) == "number" and p[token]
	if not sentAt then
		return
	end
	p[token] = nil
	local list = samples[player] or {}
	table.insert(list, math.min(os.clock() - sentAt, A.lagMaxSeconds))
	while #list > A.lagSampleCount do
		table.remove(list, 1)
	end
	samples[player] = list
end)

Players.PlayerRemoving:Connect(function(player)
	pending[player] = nil
	samples[player] = nil
end)

task.spawn(function()
	local nextToken = 0
	while true do
		task.wait(A.lagProbeSeconds)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			nextToken += 1
			local p = pending[player] or {}
			for token, sentAt in pairs(p) do
				if now - sentAt > A.lagMaxSeconds then -- 상한을 넘긴 표식은 버린다(표본이 되어도 상한값이라 정보가 없다)
					p[token] = nil
				end
			end
			p[nextToken] = now
			pending[player] = p
			echo:FireClient(player, nextToken)
		end
	end
end)

-- 왕복 핑(중앙값 · 표본 없으면 0)
function RangedLagAssist.roundTrip(player)
	local list = samples[player]
	if not list or #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.ceil(#sorted / 2)]
end

local speeds = {}
local lastPos = {}
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < A.mobSpeedSampleSeconds then
		return
	end
	local newPos, newSpeeds = {}, {}
	for _, model in ipairs(MonsterState.getAllModels()) do
		local root = model.PrimaryPart
		if root then
			local pos = root.Position
			local prev = lastPos[model]
			newPos[model] = pos
			newSpeeds[model] = prev and Vector3.new(pos.X - prev.X, 0, pos.Z - prev.Z).Magnitude / acc or 0
		end
	end
	lastPos, speeds, acc = newPos, newSpeeds, 0
end)

function RangedLagAssist.mobSpeed(model)
	return speeds[model] or 0
end

-- pickPath의 assistExtra로 넘길 함수(이 플레이어의 지연으로 고정)
function RangedLagAssist.extraFor(player)
	local oneWay = RangedLagAssist.roundTrip(player) * A.lagOneWayScale
	return function(model)
		return RangedLagAssist.mobSpeed(model) * oneWay
	end
end

return RangedLagAssist
