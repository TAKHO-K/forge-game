-- 순간이동 도착 대기(M1-2c - 클라 · 내 캐릭터만). 서버가 옮긴 뒤 ArrivalAt · ArrivalPos Attribute를 준다(server/TeleportArrival).
--   도착 자리 근처(nearStuds)에 왔는데 발 아래 probeStuds 안에 아무것도 없으면(발판이 아직 스트리밍으로 안 들어옴) 루트를 붙잡고(Anchored - 로컬 물리) 발판이 보이면 푼다(최대 holdMaxSeconds).
--   캐릭터 물리는 클라 소유라 여기서 붙잡아야 떨어지지 않는다. 서버 높이 검증은 그동안 제자리(기준 = 도착 자리)라 영향 없음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local player = Players.LocalPlayer
local A = WorldMapData.travel.arrival
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local token = 0

local function groundBelow(character, root)
	params.FilterDescendantsInstances = { character }
	return Workspace:Raycast(root.Position, Vector3.new(0, -A.probeStuds, 0), params) ~= nil
end

local function onArrival()
	token += 1
	local mine = token
	local target = player:GetAttribute("ArrivalPos")
	if typeof(target) ~= "Vector3" then
		return
	end
	local startedAt = os.clock()
	-- 서버가 준 자리가 내 캐릭터에 반영될 때까지(복제) 잠깐 기다린다
	local character, root
	while os.clock() - startedAt < 1 do
		character = player.Character
		root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - target).Magnitude <= A.nearStuds then
			break
		end
		root = nil
		RunService.Heartbeat:Wait()
	end
	if not root or mine ~= token or groundBelow(character, root) then
		return
	end
	local wasAnchored = root.Anchored
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	local heldAt = os.clock()
	while os.clock() - heldAt < A.holdMaxSeconds and mine == token and root.Parent do
		if groundBelow(character, root) then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if root.Parent and not wasAnchored then
		root.Anchored = false
	end
	print(("[forge-game] 도착 대기: 발판 로딩 %.2f초(%s)"):format(os.clock() - heldAt, groundBelow(character, root) and "발판 보임" or "상한 - 그냥 놓음"))
end

player:GetAttributeChangedSignal("ArrivalAt"):Connect(function()
	task.spawn(onArrival)
end)
