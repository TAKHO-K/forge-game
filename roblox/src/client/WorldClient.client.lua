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
	gui.Size = UDim2.new(0, 300, 0, 84) -- 세 줄(자물쇠 이름 · 조건)이 잘리지 않게
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

-- M1-2 후속(사용자): 지역명 = 오른쪽 위 [파티] 버튼 · 골드 칩 위에 작게(오른쪽 맞춤 한 줄 - 마을 · 구역 · 사냥터 / 나무를 오르면 높이 · 정거장).
--   귀환 시전 · 쿨 · 돌아가기 시간은 [귀환] · [돌아가기] 버튼 글씨. 보스전 중엔 숨긴다.
local regionLabel = Instance.new("TextLabel")
regionLabel.Name = "RegionLabel"
ScreenMap.place(regionLabel, "TR", "region")
regionLabel.Size = UDim2.new(0, 0, 0, 22)
regionLabel.AutomaticSize = Enum.AutomaticSize.X
regionLabel.BackgroundColor3 = UIColors.panel
regionLabel.BackgroundTransparency = UIColors.panelTransparency
regionLabel.Font = Theme.font
regionLabel.TextSize = Theme.textSize("caption")
regionLabel.TextColor3 = UIColors.textPrimary
regionLabel.Parent = hud
Theme.corner(regionLabel, 6)
local regionPad = Instance.new("UIPadding")
regionPad.PaddingLeft, regionPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
regionPad.Parent = regionLabel
-- M1-3 관문 등록: 등록 전 보스 스테이지 = "다음 목표: ○○ 관문을 찾아라 · 거리" 추적(지역명 왼쪽 같은 줄 · 보스 색 글씨)
local objectiveLabel = regionLabel:Clone()
objectiveLabel.Name = "ObjectiveLabel"
objectiveLabel.AnchorPoint = Vector2.new(1, 0)
objectiveLabel.Visible = false
objectiveLabel.Parent = hud
local function placeObjective()
	objectiveLabel.Position = UDim2.new(0, regionLabel.AbsolutePosition.X - 6, 0, regionLabel.AbsolutePosition.Y)
end
regionLabel:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeObjective)
regionLabel:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeObjective)

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
local backButton = button("TravelBackButton", "travelBack", "돌아가기") -- M1-2: 귀환한 자리로(5분 · 1회 · 남은 시간 = 카드 귀환 줄)
backButton.Visible = false
backButton.Size = UDim2.new(0, 104, 0, Theme.isMobile and Theme.touchMin or 36) -- "돌아가기 4:59"가 들어가게
-- [귀환] 버튼 안 시전 게이지(버튼 바탕을 왼쪽부터 채운다 - 글씨는 위)
local castFill = Instance.new("Frame")
castFill.Name = "CastFill"
castFill.BackgroundColor3 = Color3.fromRGB(120, 190, 255)
castFill.BackgroundTransparency = 0.25
castFill.BorderSizePixel = 0
castFill.Size = UDim2.fromScale(0, 1)
castFill.Parent = hubButton
Theme.corner(castFill, 8)
local hubLabel = Instance.new("TextLabel") -- 자식은 부모 위에 그려지므로 글씨를 게이지 위 자식으로 둔다
hubLabel.Name = "HubLabel"
hubLabel.BackgroundTransparency = 1
hubLabel.Size = UDim2.fromScale(1, 1)
hubLabel.Font = Theme.font
hubLabel.TextSize = Theme.textSize("body")
hubLabel.TextColor3 = UIColors.textPrimary
hubLabel.ZIndex = 2
hubLabel.Parent = hubButton
hubButton.Text = ""
hubButton.Size = UDim2.new(0, 84, 0, Theme.isMobile and Theme.touchMin or 36) -- "귀환 0:42"가 들어가게
backButton.Activated:Connect(function()
	if request then
		request:FireServer("back")
	end
end)
-- 귀환 상태 = 버튼 글씨(서버 Attribute RecallCastUntil · RecallReadyAt · RecallBackUntil = 서버 시각 · 취소 = RecallCancel)
--   [귀환] = 시전 중 "귀환 2.1"(+ 바탕 게이지) · 취소 "취소됨" 1.5초 · 쿨 "귀환 0:42"(흐리게) / [돌아가기] = "돌아가기 4:12"(남은 시간 - 그때만 보인다)
local cancelShownUntil = 0
player:GetAttributeChangedSignal("RecallCancelAt"):Connect(function()
	cancelShownUntil = os.clock() + 1.5
end)
local function mmss(seconds)
	local left = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(left // 60, left % 60)
end
RunService.RenderStepped:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local untilAt = player:GetAttribute("RecallCastUntil")
	local readyAt = player:GetAttribute("RecallReadyAt")
	local backUntil = player:GetAttribute("RecallBackUntil")
	backButton.Visible = backUntil ~= nil and backUntil > now
	if backButton.Visible then
		backButton.Text = "돌아가기 " .. mmss(backUntil - now)
	end
	local fill, text, dim = 0, "귀환", false
	if untilAt and untilAt > now then
		fill = math.clamp(1 - (untilAt - now) / WorldMapData.travel.recall.castSeconds, 0, 1)
		text = ("귀환 %.1f"):format(untilAt - now)
	elseif os.clock() < cancelShownUntil then
		text = "취소됨"
	elseif readyAt and readyAt > now then
		text, dim = "귀환 " .. mmss(readyAt - now), true
	end
	castFill.Size = UDim2.fromScale(fill, 1)
	hubLabel.Text = text
	hubLabel.TextTransparency = dim and 0.45 or 0
end)
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
		backButton.AnchorPoint = Vector2.new(1, 0)
		backButton.Position = UDim2.new(0, pos.X + size.X - hubButton.AbsoluteSize.X - 8, 0, pos.Y + size.Y + 8)
	end
	reposition()
	anchor:GetPropertyChangedSignal("AbsolutePosition"):Connect(reposition)
	anchor:GetPropertyChangedSignal("AbsoluteSize"):Connect(reposition)
end)

-- 지역 · 높이 줄 · 파티 버튼 보이기 · 관문 안내(0.2초마다)
local function stationText()
	local cp = player:GetAttribute("TreeCheckpoint")
	return cp and (" · 정거장 %d"):format(cp) or ""
end
local function regionName(position)
	if WorldMapLayout.inHub(position) then
		return WorldMapData.hub.displayName
	end
	local range, rangeZone = WorldMapLayout.huntRangeAt(position)
	if range then
		return ("%s · %s"):format(rangeZone.theme, range.name)
	end
	local zone = WorldMapLayout.zoneAt(position)
	return zone and zone.theme or "들판"
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
	regionLabel.Visible = player:GetAttribute("BossEncounterId") == nil -- 보스전 중엔 숨김
	if root then
		local feet = root.Position - Vector3.new(0, 3, 0)
		local above = feet.Y - WorldMapData.floorTopY
		local climbing = Vector3.new(feet.X, 0, feet.Z).Magnitude <= 160 and above > 12
		regionLabel.Text = climbing and ("큰 나무 · 높이 %dm%s"):format(math.floor(above * TREE.metersPerStud + 0.5), stationText()) or regionName(feet)
	end
	-- M1-3: 관문 길 안내 + 다음 목표 = 등록 전 보스 스테이지만(서버 BossGateId - 등록하면 꺼진다)
	local gate = player:GetAttribute("BossGateId")
	if gate ~= lastGate then
		lastGate = gate
		if gate then
			Wayfinder.setPoints("bossGate", WorldMapLayout.bossGateRoute(gate))
		else
			Wayfinder.clear("bossGate")
		end
	end
	local g = gate and WorldMapLayout.bossGate(gate)
	objectiveLabel.Visible = g ~= nil and regionLabel.Visible
	if g and root then
		local d = Vector3.new(g.position.X - root.Position.X, 0, g.position.Z - root.Position.Z).Magnitude
		objectiveLabel.Text = ("다음 목표: %s 관문을 찾아라 · %dm"):format(g.name, math.floor(d * TREE.metersPerStud + 0.5))
		objectiveLabel.TextColor3 = Color3.fromRGB(g.color[1], g.color[2], g.color[3])
		placeObjective()
	end
end)
