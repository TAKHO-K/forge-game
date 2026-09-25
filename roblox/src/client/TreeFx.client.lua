-- M1 나무 점프맵 요소(클라 - 내 캐릭터만 · 판정 최소). 수치 = WorldMapData.hub.tree.course. 도형 = WorldMapLayout.buildTree(서버가 짓는다 - 여기서는 속성으로 찾는다).
--   통통 열매(TreeFruit = bounce): 밟으면 위로 크게 튄다(발 + bounce.reachStuds) · 점프대(TreePad): 정해진 포물선(flightSeconds)으로 착지 표시 자리까지 날린다.
--     둘 다 서버 높이 검증 예외를 요청한다(TreeLaunch - 서버가 거리를 확인하고 HeightGuard.exempt).
--   말랑 열매(soft): 밟으면 살짝 가라앉다가 dropSeconds 뒤 떨어지고(로컬 - 충돌 끔) respawnSeconds 뒤 제자리(같은 파트를 되살린다 = 풀링).
--   매달린 열매(hang) · 흔들리는 잎(LeafSway): 서버 시계 기준 진자 · 흔들림(모두 같은 위상) - 움직이는 발판은 속도를 같이 줘서 선 사람을 싣는다.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)

local player = Players.LocalPlayer
local C = WorldMapData.hub.tree.course
local G = Workspace.Gravity

local fruits, pads, hangs, sways = {}, {}, {}, {}
local ropes = {}
local launchRemote = nil

local function register(part)
	if not part:IsA("BasePart") then
		return
	end
	local kind = part:GetAttribute("TreeFruit")
	if kind == "hang" then
		hangs[part] = { base = part.CFrame, pivotY = part:GetAttribute("HangPivotY"), tan = Vector3.new(part:GetAttribute("HangTanX") or 1, 0, part:GetAttribute("HangTanZ") or 0) }
	elseif kind then
		fruits[part] = { kind = kind, base = part.CFrame }
	elseif part:GetAttribute("TreePad") then
		pads[part] = Vector3.new(part:GetAttribute("PadTargetX") or 0, part:GetAttribute("PadTargetY") or 0, part:GetAttribute("PadTargetZ") or 0)
	elseif part:GetAttribute("LeafSway") then
		sways[part] = part.CFrame
	elseif part:GetAttribute("RopeFor") then
		ropes[part:GetAttribute("RopeFor")] = { part = part, base = part.CFrame }
	end
end
local function unregister(part)
	fruits[part], pads[part], hangs[part], sways[part] = nil, nil, nil, nil
end

task.spawn(function()
	local ground = Workspace:WaitForChild("Ground", 60)
	local course = ground and ground:WaitForChild("TreeCourse", 60)
	if not course then
		return
	end
	for _, d in ipairs(course:GetDescendants()) do
		register(d)
	end
	course.DescendantAdded:Connect(register) -- 스트리밍으로 들어온 파트
	course.DescendantRemoving:Connect(unregister)
	launchRemote = ReplicatedStorage:WaitForChild("TreeLaunch", 30)
end)

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function standingPart(character, root)
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -4.5, 0), params)
	return hit and hit.Instance
end

local flight = nil -- { v0, startedAt, seconds } - 점프대 비행(속도를 매 프레임 포물선 값으로 덮는다 - 휴머노이드 공중 제어가 줄이지 못하게)
local lastLaunchAt = 0
local softState = {} -- [part] = { steppedAt, droppedAt }

local function launch(root, id, velocity, seconds)
	lastLaunchAt = os.clock()
	if launchRemote then
		launchRemote:FireServer(id)
	end
	root.AssemblyLinearVelocity = velocity
	if seconds then
		flight = { v0 = velocity, startedAt = os.clock(), seconds = seconds }
	end
end

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	-- 매달린 열매(진자) · 흔들리는 잎
	for part, h in pairs(hangs) do
		if part.Parent then
			local amp = math.rad(C.hang.swingDeg)
			local w = 2 * math.pi / C.hang.periodSeconds
			local theta = amp * math.sin(now * w)
			local rope = h.pivotY - h.base.Position.Y
			local pivot = Vector3.new(h.base.Position.X, h.pivotY, h.base.Position.Z)
			local offset = h.tan * (math.sin(theta) * rope) - Vector3.new(0, math.cos(theta) * rope, 0)
			part.CFrame = CFrame.new(pivot + offset)
			local speed = amp * w * math.cos(now * w) * rope
			part.AssemblyLinearVelocity = h.tan * speed * math.cos(theta)
			local r = ropes[part:GetAttribute("FruitId")]
			if r and r.part.Parent then
				r.part.CFrame = CFrame.lookAt((pivot + pivot + offset) / 2, pivot) * CFrame.Angles(math.rad(90), 0, 0)
			end
		end
	end
	for part, base in pairs(sways) do
		if part.Parent then
			part.CFrame = base * CFrame.Angles(0, 0, math.rad(C.leafSway.deg) * math.sin(now * 2 * math.pi / C.leafSway.periodSeconds))
		end
	end
	-- 말랑 열매 되살리기(같은 파트 - 풀링)
	local clock = os.clock()
	for part, s in pairs(softState) do
		if s.droppedAt and clock - s.droppedAt >= C.soft.respawnSeconds then
			local f = fruits[part]
			if f then
				part.CFrame = f.base
			end
			part.CanCollide = true
			part.Transparency = 0
			softState[part] = nil
		elseif not s.droppedAt and clock - s.steppedAt >= C.soft.dropSeconds then
			s.droppedAt = clock
			part.CanCollide = false
			part.Transparency = 0.75
		end
	end
	-- 내 캐릭터가 밟은 것
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		flight = nil
		return
	end
	if flight then
		local t = os.clock() - flight.startedAt
		if t >= flight.seconds or (t > 0.2 and humanoid.FloorMaterial ~= Enum.Material.Air) then
			flight = nil
		else
			root.AssemblyLinearVelocity = Vector3.new(flight.v0.X, flight.v0.Y - G * t, flight.v0.Z)
		end
		return
	end
	local part = standingPart(character, root)
	if not part or os.clock() - lastLaunchAt < 0.4 then
		return
	end
	local f = fruits[part]
	if f and f.kind == "bounce" then
		launch(root, part:GetAttribute("FruitId"), Vector3.new(root.AssemblyLinearVelocity.X, math.sqrt(2 * G * C.bounce.reachStuds), root.AssemblyLinearVelocity.Z))
	elseif f and f.kind == "soft" and not softState[part] then
		softState[part] = { steppedAt = os.clock() }
		part.CFrame = f.base - Vector3.new(0, C.soft.sinkStuds, 0)
	elseif pads[part] then
		local target = pads[part] + Vector3.new(0, 3.5, 0) -- 착지 = 다음 요소 윗면 위 루트 높이
		local T = C.pad.flightSeconds
		local from = root.Position
		local v = (target - from) / T + Vector3.new(0, G * T / 2, 0)
		launch(root, part:GetAttribute("TreePad"), v, T)
	end
end)
