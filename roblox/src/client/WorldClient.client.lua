-- M1 세계(클라): 잠긴 구역 결계(로컬 충돌 벽 + 발밑 빛 선 + 결계 문 "잠김" 표시) · 허브 포탈 잠김 표시 · 나무 높이 표시 · [귀환] · [파티 곁] 버튼 · 보스 관문 길 안내.
-- 결계 벽은 클라만 만든다 - 캐릭터 물리는 클라 소유라 로컬 벽이 그 사람만 막는다(구역 개방은 사람마다 다르다). 서버 밀어내기(Travel)는 보조.
-- 수치 = WorldMapData(barrier · hub.tree) · 개방 = Player Attribute ZonesUnlocked · PortalsOpen · 안내 = BossGateZone(서버 - 보스 스테이지를 고르면).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ScreenMap = require(script.Parent.ui.ScreenMap)
local Theme = require(script.Parent.ui.kit.Theme)
local Wayfinder = require(script.Parent.Wayfinder)

local player = Players.LocalPlayer
local B = WorldMapData.barrier
local TREE = WorldMapData.hub.tree

-- ─────────────────────────── 결계 ───────────────────────────
local barrierFolder = Instance.new("Folder")
barrierFolder.Name = "WorldBarrierLocal"
barrierFolder.Parent = Workspace
local built = {} -- [zoneKey] = { parts }

local function localPart(parent, name, size, cf, opts)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CanCollide = opts.collide == true
	p.Transparency = opts.transparency or 0
	p.Material = opts.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
	p.Color = opts.color or Color3.fromRGB(120, 190, 255)
	p.Parent = parent
	return p
end

local function lockText(zone)
	local prev = WorldMapData.zones[zone.tierIndex - 1]
	return ("🔒 %s\n%s 보스를 처음 잡으면 열린다"):format(zone.theme, prev and prev.theme or "이전 구역")
end

local function buildBarrier(zone)
	local folder = Instance.new("Folder")
	folder.Name = "Barrier_" .. zone.key
	folder.Parent = barrierFolder
	local color = Color3.fromRGB(WorldMapData.colors.barrier[1], WorldMapData.colors.barrier[2], WorldMapData.colors.barrier[3])
	for _, seg in ipairs(WorldMapLayout.barrierSegments(zone)) do
		localPart(folder, "BarrierWall", Vector3.new(seg.length, B.wallHeight, 2), seg.cf * CFrame.new(0, B.wallHeight / 2 - 2, 0), { collide = true, transparency = 1 })
		localPart(folder, "BarrierLine", Vector3.new(seg.length, B.lineHeight, B.lineWidth), seg.cf * CFrame.new(0, B.lineHeight / 2 + 0.3, 0), { neon = true, transparency = 0.3, color = color })
	end
	-- 결계 문 표시(길이 구역 원을 지나는 자리)
	local gatePos = WorldMapLayout.toWorld(zone, WorldMapData.layout.barrierGateR, 0, B.gateHeight + 6)
	local anchor = localPart(folder, "BarrierSign", Vector3.new(1, 1, 1), CFrame.new(gatePos), { transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 260, 0, 60)
	gui.MaxDistance = 400
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Theme.font
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Text = lockText(zone)
	text.Parent = gui
	return folder
end

local function refreshBarriers()
	local unlocked = player:GetAttribute("ZonesUnlocked") or WorldMapData.progress.startUnlocked
	for _, zone in ipairs(WorldMapData.zones) do
		local locked = zone.tierIndex > unlocked
		if locked and not built[zone.key] then
			built[zone.key] = buildBarrier(zone)
		elseif not locked and built[zone.key] then
			built[zone.key]:Destroy()
			built[zone.key] = nil
		end
	end
end
player:GetAttributeChangedSignal("ZonesUnlocked"):Connect(refreshBarriers)
refreshBarriers()

-- 허브 포탈 판 이름표(열림 / 잠김) - 로컬 표시 파트
local portalFolder = Instance.new("Folder")
portalFolder.Name = "PortalSignsLocal"
portalFolder.Parent = Workspace
local portalLabels = {}
for _, zone in ipairs(WorldMapData.zones) do
	local p = WorldMapLayout.hubPortal(zone) + Vector3.new(0, 6, 0)
	local anchor = localPart(portalFolder, "PortalSign", Vector3.new(1, 1, 1), CFrame.new(p), { transparency = 1 })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 140, 0, 36)
	gui.MaxDistance = 120
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Theme.font
	text.TextStrokeTransparency = 0.3
	text.Parent = gui
	portalLabels[zone.key] = text
end
local function refreshPortals()
	local open = {}
	for key in string.gmatch(player:GetAttribute("PortalsOpen") or "", "[^,]+") do
		open[key] = true
	end
	for _, zone in ipairs(WorldMapData.zones) do
		local label = portalLabels[zone.key]
		label.Text = (open[zone.key] and "→ " or "🔒 ") .. zone.theme
		label.TextColor3 = open[zone.key] and Color3.new(1, 1, 1) or Color3.fromRGB(170, 170, 170)
	end
end
player:GetAttributeChangedSignal("PortalsOpen"):Connect(refreshPortals)
refreshPortals()

-- ─────────────────────────── HUD ───────────────────────────
local hud = Instance.new("ScreenGui")
hud.Name = "WorldHud"
hud.ResetOnSpawn = false
hud.Parent = player:WaitForChild("PlayerGui")

local heightLabel = Instance.new("TextLabel")
heightLabel.Name = "TreeHeightLabel"
ScreenMap.place(heightLabel, "TC", "treeHeight")
heightLabel.Size = UDim2.new(0, 220, 0, 36)
heightLabel.BackgroundColor3 = UIColors.panel
heightLabel.BackgroundTransparency = UIColors.panelTransparency
heightLabel.TextColor3 = UIColors.textPrimary
heightLabel.Font = Theme.font
heightLabel.TextSize = Theme.textSize("body")
heightLabel.Visible = false
heightLabel.Parent = hud
Theme.corner(heightLabel, 8)

local function button(name, slotName, text)
	local b = Instance.new("TextButton")
	b.Name = name
	ScreenMap.place(b, "TR", slotName)
	b.Size = UDim2.new(0, 72, 0, Theme.isMobile and Theme.touchMin or 36)
	b.Text = text
	b.Font = Theme.font
	b.TextSize = Theme.textSize("body")
	b.TextColor3 = UIColors.textPrimary
	b.BackgroundColor3 = UIColors.panel
	b.BackgroundTransparency = UIColors.panelTransparency
	b.Parent = hud
	Theme.corner(b, 8)
	Theme.stroke(b)
	return b
end
local request = ReplicatedStorage:WaitForChild("TravelRequest", 30)
local hubButton = button("TravelHubButton", "travelHub", "귀환")
local partyButton = button("TravelPartyButton", "travelParty", "파티 곁")
hubButton.Activated:Connect(function()
	if request then
		request:FireServer("hub")
	end
end)
partyButton.Activated:Connect(function()
	if request then
		request:FireServer("party")
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H and request then
		request:FireServer("hub") -- PC 단축키 H = 허브 귀환
	end
end)
-- [순위] 버튼 아래로 이어 붙인다(순위 버튼이 파티 버튼 · 칩 스택을 따라 움직인다)
task.spawn(function()
	local gui = player.PlayerGui:WaitForChild("LeaderboardToggleGui", 20)
	local anchor = gui and gui:WaitForChild("LeaderboardToggleButton", 10)
	if not anchor then
		return
	end
	local function reposition()
		local pos, size = anchor.AbsolutePosition, anchor.AbsoluteSize
		hubButton.AnchorPoint = Vector2.new(1, 0)
		hubButton.Position = UDim2.new(0, pos.X + size.X, 0, pos.Y + size.Y + 8)
		partyButton.AnchorPoint = Vector2.new(1, 0)
		partyButton.Position = UDim2.new(0, pos.X + size.X, 0, pos.Y + size.Y * 2 + 16)
	end
	reposition()
	anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
end)

-- 높이 표시 · 파티 버튼 보이기 · 관문 안내(0.2초마다)
local function stationText()
	local cp = player:GetAttribute("TreeCheckpoint")
	return cp and (" · 정거장 %d"):format(cp) or ""
end
local lastGate = nil
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	partyButton.Visible = player:GetAttribute("InParty") == true
	if root then
		local feet = root.Position - Vector3.new(0, 3, 0)
		local above = feet.Y - WorldMapData.floorTopY
		local nearTree = Vector3.new(feet.X, 0, feet.Z).Magnitude <= 160
		heightLabel.Visible = nearTree and above > 12
		if heightLabel.Visible then
			heightLabel.Text = ("높이 %dm%s"):format(math.floor(above * TREE.metersPerStud + 0.5), stationText())
		end
	end
	local gate = player:GetAttribute("BossGateZone")
	if gate ~= lastGate then
		lastGate = gate
		if gate then
			Wayfinder.setPoints("bossGate", Wayfinder.routeToGate(gate))
		else
			Wayfinder.clear("bossGate")
		end
	end
end)
