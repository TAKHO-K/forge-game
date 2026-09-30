-- QUEUE-ALL3 Q5 · Q6 이동 시전 · 체크포인트 표시(클라 로컬 - 판정 = 서버 Travel).
--   ① 정신 집중(귀환 B · 체크포인트) = 발밑 원형 진행(얇은 흰 고리 + 차오르는 원판) + 머리 위 작은 진행 막대 · 취소 = 짧은 토스트("귀환 취소")
--   ② 체크포인트 7곳 = 로컬 수정 기둥(찾음 = 밝게 · 못 찾음 = 흐리게) + 이름표 · 처음 찾으면(CheckpointFound) 빛 퍼짐 + 토스트 + 소리(SoundHooks가 같은 이벤트를 듣는다)
--   값 = 서버 Attribute RecallCastUntil · RecallCastKind · RecallCancel(At) · CheckpointsFound · Workspace CheckpointTeleport. 충돌 · 조회 없음 · 입자 없음(폰).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local CP = WorldMapData.checkpoints
local CYAN = Color3.fromRGB(120, 220, 255)
local RING_RADIUS = 5

local folder = Instance.new("Folder")
folder.Name = "TravelChannelLocal"
folder.Parent = Workspace

local function part(name, shape, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = shape or Enum.PartType.Block
	p.Material = Enum.Material.Neon
	p.Color = color or CYAN
	p.Transparency = transparency or 0
	p.Parent = folder
	return p
end

-- ① 시전 표시
local ring = part("ChannelRing", Enum.PartType.Cylinder, Color3.new(1, 1, 1), 1)
ring.Size = Vector3.new(0.12, RING_RADIUS * 2, RING_RADIUS * 2)
local disc = part("ChannelFill", Enum.PartType.Cylinder, CYAN, 1)
local bar = Instance.new("BillboardGui")
bar.Name = "ChannelBar"
bar.Size = UDim2.fromOffset(70, 10)
bar.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
bar.AlwaysOnTop = true
bar.Enabled = false
bar.Parent = folder
local track = Instance.new("Frame")
track.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
track.BackgroundTransparency = 0.2
track.Size = UDim2.fromScale(1, 1)
track.Parent = bar
Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
local fill = Instance.new("Frame")
fill.BackgroundColor3 = CYAN
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = track
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local castStart, castTotal = nil, 1
player:GetAttributeChangedSignal("RecallCastUntil"):Connect(function()
	local untilAt = player:GetAttribute("RecallCastUntil")
	if untilAt then
		castStart = Workspace:GetServerTimeNow()
		castTotal = math.max(0.1, untilAt - castStart)
	else
		castStart = nil
	end
end)
RunService.RenderStepped:Connect(function()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local untilAt = player:GetAttribute("RecallCastUntil")
	local now = Workspace:GetServerTimeNow()
	local active = root ~= nil and untilAt ~= nil and untilAt > now and castStart ~= nil
	if not active then
		ring.Transparency, disc.Transparency, bar.Enabled = 1, 1, false
		return
	end
	local t = math.clamp((now - castStart) / castTotal, 0, 1)
	local feet = root.Position - Vector3.new(0, 2.9, 0)
	ring.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Transparency = 0.35
	local r = math.max(0.2, RING_RADIUS * t)
	disc.Size = Vector3.new(0.1, r * 2, r * 2)
	disc.CFrame = CFrame.new(feet + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	disc.Color = player:GetAttribute("RecallCastKind") == "checkpoint" and Color3.fromRGB(150, 255, 190) or CYAN
	disc.Transparency = 0.55
	bar.Adornee = root
	bar.Enabled = true
	fill.Size = UDim2.fromScale(t, 1)
end)
player:GetAttributeChangedSignal("RecallCancelAt"):Connect(function()
	Toast.push("TC", { text = Text.get(player:GetAttribute("RecallCastKind") == "checkpoint" and "travel.cpCancel" or "travel.recallCancel"), colorName = "textPrimary" })
end)

-- ② 체크포인트 기둥
local markers = {}
local function cpPosition(cp)
	return cp.hub and WorldMapLayout.spawnPoint() or WorldMapLayout.camp(WorldMapLayout.zoneByKey(cp.zone))
end
local function isFound(id)
	return string.find("," .. tostring(player:GetAttribute("CheckpointsFound") or "") .. ",", "," .. id .. ",", 1, true) ~= nil
end
local function refreshMarkers()
	local on = Workspace:GetAttribute(CP.attribute) == true
	for _, cp in ipairs(CP.list) do
		local m = markers[cp.id]
		if not m then
			local base = cpPosition(cp) + Vector3.new(8, 0, 8)
			m = part("Checkpoint_" .. cp.id, Enum.PartType.Block, CYAN, 0.2)
			m.Size = Vector3.new(2.2, 7, 2.2)
			m.CFrame = CFrame.new(base + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0, math.rad(45), 0)
			local tag = Instance.new("BillboardGui")
			tag.Name = "Label"
			tag.Size = UDim2.fromOffset(160, 24)
			tag.StudsOffsetWorldSpace = Vector3.new(0, 5.5, 0)
			tag.MaxDistance = 120
			tag.Parent = m
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Font = Enum.Font.GothamBold
			l.TextSize = 14
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0.3
			l.Text = cp.name
			l.Parent = tag
			markers[cp.id] = m
		end
		local found = isFound(cp.id)
		m.Transparency = on and (found and 0.15 or 0.7) or 1
		m.Label.Enabled = on
	end
end
player:GetAttributeChangedSignal("CheckpointsFound"):Connect(refreshMarkers)
Workspace:GetAttributeChangedSignal(CP.attribute):Connect(refreshMarkers)
task.defer(refreshMarkers)

-- 발견 순간: 빛 퍼짐(0.8초 · 로컬) + 토스트
ReplicatedStorage:WaitForChild("CheckpointFound").OnClientEvent:Connect(function(id)
	for _, cp in ipairs(CP.list) do
		if cp.id == id then
			local burst = part("CheckpointBurst", Enum.PartType.Ball, CYAN, 0.3)
			burst.Size = Vector3.new(2, 2, 2)
			burst.CFrame = CFrame.new(cpPosition(cp) + Vector3.new(8, 3.5, 8))
			local tw = TweenService:Create(burst, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(22, 22, 22), Transparency = 1 })
			tw:Play()
			tw.Completed:Connect(function()
				burst:Destroy()
			end)
			Toast.push("TC", { text = Text.get("travel.cpFound", { name = cp.name }), colorName = "success" })
		end
	end
	refreshMarkers()
end)
