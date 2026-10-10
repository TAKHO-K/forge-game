-- UI-1 4단계(03 v3 MISSING 1): 가방 장비 1개 전투력 변화 = PlayerProfile.combatPowerDeltaPct(같은 함수 getCombatPower · 부위만 바꿔 끼운 계산).
--   RemoteFunction BagItemPower → { base = 지금 전투력, deltas = { [가방 index] = 끼우면 몇 % } } · 가방 "전투력" 정렬 · 상세 ▲ ▼ % · 바닥 장비 ▲ +%(ItemDropSpawner Attribute)가 같은 값.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)

local MIN_GAP = 0.5 -- 같은 사람 연속 요청 간격(초)
local lastAt = {}

local rf = Instance.new("RemoteFunction")
rf.Name = "BagItemPower"
rf.Parent = ReplicatedStorage

rf.OnServerInvoke = function(player)
	local now = os.clock()
	if lastAt[player] and now - lastAt[player] < MIN_GAP then
		return nil
	end
	lastAt[player] = now
	local inventory = PlayerProfile.getInventory(player)
	if type(inventory) ~= "table" then
		return nil
	end
	local deltas = {}
	for i, item in ipairs(inventory) do
		deltas[i] = math.floor(PlayerProfile.combatPowerDeltaPct(player, item) * 10 + 0.5) / 10
	end
	return { base = PlayerProfile.getCombatPower(player), deltas = deltas }
end

Players.PlayerRemoving:Connect(function(player)
	lastAt[player] = nil
end)
