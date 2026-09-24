-- P3a D1 계측(자동 검증 전용 - 검증 모드(VerifyArmedUntil)가 아니면 아무것도 안 한다). 이 클라가 보스 예고(장판)를 받아 그린 순간을 서버 검증(P3aVerify D)에 알린다:
-- 받은 서버 시각 · 종류 · 내 루트 높이 · 발밑에 바닥이 보이는가(스트리밍 도착 여부). 서버는 이것과 자기 판정 기록을 나란히 놓고 "보였는데 판정 없음"을 센다.
-- 아레나 바닥(BossArenaFloor)이 이 클라에 도착한 순간도 알린다(첫 진입 때 스트리밍이 늦는지).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not DevToolsConfig.verifyArmed then
	return
end

local ack = ReplicatedStorage:WaitForChild("P3aTelegraphAck", 600)
if not ack then
	return
end
local patternEvent = ReplicatedStorage:WaitForChild("BossPatternEvent")
local player = Players.LocalPlayer

local TELEGRAPHS = { heavyTelegraph = true, meteor = true, cross = true, focus = true, shockTelegraph = true, gimmickTelegraph = true }

local function footInfo()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	return root.Position, hit ~= nil
end

patternEvent.OnClientEvent:Connect(function(kind)
	if TELEGRAPHS[kind] then
		local position, grounded = footInfo()
		ack:FireServer("telegraph", kind, Workspace:GetServerTimeNow(), position, grounded)
	end
end)

-- 바닥 도착(스트리밍): 지면 폴더에 아레나 바닥이 생기는 순간.
local function watchFolder(folder)
	folder.ChildAdded:Connect(function(child)
		if child.Name == "BossArenaFloor" then
			local position = footInfo()
			ack:FireServer("floor", child.Name, Workspace:GetServerTimeNow(), position, true)
		end
	end)
end
local ground = Workspace:FindFirstChild("Ground") or Workspace:WaitForChild("Ground", 30)
if ground then
	watchFolder(ground)
end
