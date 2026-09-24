-- P3c A 연출(판정 없음 - 서버 BossPatterns가 보내는 사실만 그린다). 새 색 · 새 에셋 없음: 위험 = UIColors.danger, 알림 = 흰색(임팩트 색).
--   · waveCue: 줄넘기 파동이 **내 자리**에 닿기 직전 CUE_SECONDS 동안 내 발밑에 흰 고리가 조여 든다 - 다 조이는 순간이 파동이 닿는 순간이다("점프 틈" 표시).
--     내 자리는 매 프레임 다시 잰다(움직여도 맞다). 겹(layer 2 이상)은 첫 겹에만 띄운다 - 한 번의 점프로 넘는 한 덩어리다.
--   · chargeTarget: 돌진 대상 머리 위 표식(‼ - 말풍선과 같은 그림 문자) - 전조 동안만. 방향선은 BossPatternVisuals의 경로선이다.
--   · follow: 번개 추적 원이 그 사람의 캐릭터를 따라간다(서버가 멈춘 자리를 meteorLock으로 보내면 BossPatternVisuals가 그 자리로 다시 그린다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossRhythmView = {}

local player = Players.LocalPlayer
local CUE_SECONDS = 0.7
local CUE_MAX_RADIUS = 4
local CUE_COLOR = Color3.new(1, 1, 1)
local MARK_COLOR = UIColors.danger

local live = {} -- 지울 것(파트 · GUI · 연결)

local function track(thing)
	live[thing] = true
	return thing
end

local function drop(thing)
	if live[thing] then
		live[thing] = nil
		if typeof(thing) == "RBXScriptConnection" then
			thing:Disconnect()
		else
			thing:Destroy()
		end
	end
end

local function myRoot()
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- data = shockwave 이벤트 { center(바닥), serverStart, speed, thickness, maxRadius, layer }
function BossRhythmView.waveCue(data)
	if (data.layer or 1) > 1 then
		return
	end
	local ring = Instance.new("Part")
	ring.Name = "BossJumpCue"
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = CUE_COLOR
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 1
	ring.Size = Vector3.new(0.12, 1, 1)
	ring.Parent = Workspace
	track(ring)
	local connection
	connection = track(RunService.RenderStepped:Connect(function()
		local root = myRoot()
		if not root or not live[ring] then
			drop(connection)
			drop(ring)
			return
		end
		local d = Vector3.new(root.Position.X - data.center.X, 0, root.Position.Z - data.center.Z).Magnitude
		if d > data.maxRadius then
			drop(connection)
			drop(ring)
			return
		end
		local left = data.serverStart + d / data.speed - Workspace:GetServerTimeNow()
		if left < -0.15 then
			drop(connection)
			drop(ring)
			return
		end
		local alpha = math.clamp(left / CUE_SECONDS, 0, 1)
		ring.Transparency = left > CUE_SECONDS and 1 or (0.15 + 0.5 * alpha)
		local radius = 1.2 + (CUE_MAX_RADIUS - 1.2) * alpha
		ring.Size = Vector3.new(0.12, radius * 2, radius * 2)
		local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
		local feetY = root.Position.Y - (humanoid and (humanoid.HipHeight + root.Size.Y / 2) or 3)
		ring.CFrame = CFrame.new(root.Position.X, feetY + 0.2, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	end))
end

local function characterOf(userId)
	for _, other in ipairs(Players:GetPlayers()) do
		if other.UserId == userId then
			return other.Character
		end
	end
	return nil
end

-- data = focus 이벤트 { targetUserId, seconds }
function BossRhythmView.chargeTarget(data)
	local character = data.targetUserId and characterOf(data.targetUserId)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossChargeTargetMark"
	gui.Size = UDim2.new(0, 64, 0, 64)
	gui.StudsOffset = Vector3.new(0, 3.2, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Adornee = head
	gui.Parent = head
	track(gui)
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.Text = "‼"
	icon.TextColor3 = MARK_COLOR
	icon.TextStrokeTransparency = 0
	icon.TextStrokeColor3 = CUE_COLOR
	icon.Parent = gui
	task.delay(data.seconds, function()
		drop(gui)
	end)
end

-- parts = 그 원의 파트들(바닥 원판 · 흰 카운트다운) - seconds 동안 userId의 캐릭터 발밑(XZ)을 따라간다. Y는 그대로(바닥).
function BossRhythmView.follow(parts, userId, seconds)
	local startedAt = os.clock()
	local connection
	connection = track(RunService.RenderStepped:Connect(function()
		local character = characterOf(userId)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if os.clock() - startedAt >= seconds or not root then
			drop(connection)
			return
		end
		for _, part in ipairs(parts) do
			if part.Parent then
				part.CFrame = CFrame.new(root.Position.X, part.Position.Y, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end))
end

function BossRhythmView.clear()
	for thing in pairs(live) do
		live[thing] = true
		drop(thing)
	end
	live = {}
end

return BossRhythmView
