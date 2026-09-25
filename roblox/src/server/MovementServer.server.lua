-- 이동 보조(M1-0).
--   ① 공중 점프 · 대시 모션 중계(AirMoveFx): 모션은 클라가 루트 관절 C0로 그려서 복제되지 않는다 - 입력한 클라가 kind를 보내면 다른 사람들에게 (그 사람, kind)로 다시 보낸다.
--      그리기 신호일 뿐 판정 · 상태는 없다. kind는 두 가지만 받고, relayMinGapSeconds보다 잦으면 버린다.
--   ② 로블록스 기본 Shift Lock을 끈다(DevEnableMouseLock) - 기본 키가 LeftShift라 대시와 겹친다. 시점 고정은 자체 구현(client/ShiftLock.client.lua · LeftControl).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local KINDS = { flip = true, lean = true }

local airMoveFx = Instance.new("RemoteEvent")
airMoveFx.Name = "AirMoveFx"
airMoveFx.Parent = ReplicatedStorage

local lastRelayAt = {} -- [Player] = { [kind] = os.clock() } - 종류별(점프 직후 대시 기울임이 먹히지 않게)

airMoveFx.OnServerEvent:Connect(function(player, kind)
	if not KINDS[kind] then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local last = lastRelayAt[player] or {}
	lastRelayAt[player] = last
	if now - (last[kind] or -math.huge) < MovementConfig.airMotion.relayMinGapSeconds then
		return
	end
	last[kind] = now
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			airMoveFx:FireClient(other, player, kind)
		end
	end
end)

local function onPlayer(player)
	player.DevEnableMouseLock = false
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end
Players.PlayerRemoving:Connect(function(player)
	lastRelayAt[player] = nil
end)
