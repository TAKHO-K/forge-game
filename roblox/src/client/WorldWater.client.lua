-- M1-3 필드 환경(클라 - 연출 · 내 캐릭터 물리만): 물살 끌림 · 선인장 밀림 · 흔들다리 흔들림.
--   물살: 헤엄 중이고 TerrainShape 흐름 안이면 매 프레임 하류로 흐름 속도만큼 옮긴다(걷기 16 > 물살 10 - 거슬러 오를 수 있다). 서버는 속도 상한만 잰다(WorldHazards).
--   선인장: 서버 HazardPush(방향 × 속도) → 수평 속도로 살짝 밀린다.
--   흔들다리: 판자 · 밧줄(BridgePlank)을 로컬로 조금 흔든다(± swayStuds · 서버 판정 = 고정 위치 - 사용자 지시). 카메라 거리 밖이면 멈춘다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local NestData = require(ReplicatedStorage.Shared.data.NestData)

local player = Players.LocalPlayer
local SWAY = NestData.kit.bridge.sway

-- 물살
local flowCheckAt = 0
local flowNow = nil
RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or root.Anchored or humanoid.Health <= 0 then
		return
	end
	if humanoid:GetState() ~= Enum.HumanoidStateType.Swimming then
		flowNow = nil
		return
	end
	local now = os.clock()
	if now >= flowCheckAt then -- 식 계산은 0.2초마다(같은 강 구간이면 방향 · 속도가 같다)
		flowCheckAt = now + MovementConfig.water.flowCheckSeconds
		local waterY, flow = TerrainShape.waterAt(root.Position.X, root.Position.Z)
		flowNow = (flow and waterY and root.Position.Y < waterY + 2) and flow or nil
	end
	if flowNow then
		root.CFrame = root.CFrame + flowNow * dt
	end
end)

-- 선인장 밀림
ReplicatedStorage:WaitForChild("HazardPush").OnClientEvent:Connect(function(velocity)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if typeof(velocity) ~= "Vector3" or not root or root.Anchored then
		return
	end
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, math.max(v.Y, 8), velocity.Z)
end)

-- 흔들다리(로컬 흔들림): 판자마다 처음 자리를 기억하고 가운데일수록 크게
local planks = {}
local function track(part)
	if part:IsA("BasePart") and part:GetAttribute("BridgePlank") and not planks[part] then
		planks[part] = { cf = part.CFrame, i = part:GetAttribute("BridgePlank") }
	end
end
local ground = Workspace:WaitForChild("Ground", 30)
if ground then
	for _, d in ipairs(ground:GetDescendants()) do
		track(d)
	end
	ground.DescendantAdded:Connect(track)
	ground.DescendantRemoving:Connect(function(d)
		planks[d] = nil
	end)
end
local maxIndex = 1
RunService.RenderStepped:Connect(function()
	local cam = Workspace.CurrentCamera
	if not cam or next(planks) == nil then
		return
	end
	local t = os.clock()
	for part, info in pairs(planks) do
		maxIndex = math.max(maxIndex, info.i)
		if part.Parent and (part.Position - cam.CFrame.Position).Magnitude < SWAY.maxDistance then
			local k = math.sin(math.pi * info.i / (maxIndex + 1))
			local off = math.sin(t * 2 * math.pi / SWAY.periodSeconds + info.i * 0.35) * SWAY.studs * k
			part.CFrame = info.cf * CFrame.new(off, 0, 0)
		end
	end
end)
