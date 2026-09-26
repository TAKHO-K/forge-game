-- 덩굴 리프트 · 나무 입구 안내판 표시(M1-2c - 클라 · 사람마다 해금이 달라 로컬로 칠한다). 도형 = 서버(WorldMapLayout 허브) · 수치 = WorldMapData.hub.tree.course.lift · entranceBoard.
--   잠김(역대 최고 레벨 < 첫 정거장): 덩굴 · 잎 · 바구니 = 시든 갈색 · 표지 "🔒 덩굴 리프트 Lv.○○ 필요" · [F] 꺼짐.
--   열림: 초록 + 바구니 빛 + 위로 오르는 반딧불(로컬 · 수 제한 · 멀면 끔) · 표지 "정거장 N · 높이 m" · [F] "타기 · 정거장 N (높이 m)".
--   처음 해금(이번 접속에서 가장 높은 열린 정거장이 올라가면): 알림 1회 + 길 안내(리프트까지 - 도착 · 탑승 · 3분이면 끔).
--   안내판: 정거장마다 이름 · 필요 레벨 · 높이(열린 것 표시).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.ui.kit.Toast)
local Theme = require(script.Parent.ui.kit.Theme)
local Wayfinder = require(script.Parent.Wayfinder)

local player = Players.LocalPlayer
local COURSE = WorldMapData.hub.tree.course
local L = COURSE.lift
local EB = COURSE.entranceBoard
local FLOOR = WorldMapData.floorTopY
local GUIDE_OWNER = "vineLift"
local GUIDE_SECONDS = 180

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end
local WITHERED, ALIVE, GLOW, FIREFLY = rgb(L.colors.withered), rgb(L.colors.alive), rgb(L.colors.glow), rgb(L.colors.firefly)

local stations = WorldMapLayout.stations()
local liftPoint = WorldMapLayout.hubPoint(L.angleDeg, L.r)

local function metersOf(s)
	return ("%d"):format(math.floor((s.y - FLOOR) * COURSE.metersPerStud + 0.5))
end

local function highest()
	local peak = player:GetAttribute("PeakLevel") or 1
	local best = 0
	for i, s in ipairs(stations) do
		if peak >= s.unlockLevel then
			best = i
		end
	end
	return best
end

local parts = {} -- [part] = LiftPart 종류
local signText, prompt, boardRows, basketLight, fireflies = nil, nil, nil, nil, nil

local function paint()
	local best = highest()
	local open = best > 0
	for part, kind in pairs(parts) do
		if part.Parent and kind ~= "sign" then
			part.Color = open and (kind == "leaf" and GLOW or ALIVE) or WITHERED
			part.Material = (open and kind == "basket") and Enum.Material.Neon or Enum.Material.SmoothPlastic
		end
	end
	if basketLight then
		basketLight.Enabled = open
	end
	if signText then
		signText.Text = open and Text.get("lift.open", { station = best, meters = metersOf(stations[best]) })
			or Text.get("lift.locked", { level = stations[1].unlockLevel })
		signText.TextColor3 = open and GLOW or Color3.new(1, 1, 1)
	end
	if prompt then
		prompt.Enabled = open
		if open then
			prompt.ActionText = Text.get("lift.prompt", { station = best, meters = metersOf(stations[best]) })
		end
	end
	if boardRows then
		local peak = player:GetAttribute("PeakLevel") or 1
		for i, s in ipairs(stations) do
			local row = boardRows[i]
			if row then
				local isOpen = peak >= s.unlockLevel
				row.Text = Text.get(isOpen and "board.rowOpen" or "board.row", { station = i, name = s.name, level = s.unlockLevel, meters = metersOf(s) })
				row.TextColor3 = isOpen and GLOW or Color3.fromRGB(235, 225, 210)
			end
		end
	end
end

local function makeSign(anchor)
	local gui = Instance.new("BillboardGui")
	gui.Name = "VineLiftSign"
	gui.Size = UDim2.new(0, 230, 0, 64)
	gui.MaxDistance = 140
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.TextScaled = true
	text.Font = Theme.font
	text.TextStrokeTransparency = 0.25
	text.Parent = gui
	signText = text
end

local function makeFireflies(vine)
	local e = Instance.new("ParticleEmitter")
	e.Name = "VineFireflies"
	e.EmissionDirection = Enum.NormalId.Right -- 덩굴 원통은 로컬 X가 위(90° 눕힌 원통)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = L.fireflies.rate
	e.Lifetime = NumberRange.new(L.fireflies.lifetime * 0.75, L.fireflies.lifetime)
	e.Speed = NumberRange.new(L.fireflies.speed * 0.6, L.fireflies.speed)
	e.SpreadAngle = Vector2.new(25, 25)
	e.Size = NumberSequence.new(L.fireflies.size)
	e.Color = ColorSequence.new(FIREFLY)
	e.LightEmission = 1
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.15), NumberSequenceKeypoint.new(0.8, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Enabled = false
	e.Parent = vine
	fireflies = fireflies or {}
	table.insert(fireflies, e)
end

local function makeBoard(board)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "StationBoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local h = EB.h * 40
	local list = Instance.new("Frame")
	list.Size = UDim2.new(1, -40, 1, -30)
	list.Position = UDim2.new(0, 20, 0, 15)
	list.BackgroundTransparency = 1
	list.Parent = gui
	local rowH = math.floor((h - 30) / (#stations + 2))
	local function label(i, text, size)
		local t = Instance.new("TextLabel")
		t.Size = UDim2.new(1, 0, 0, rowH)
		t.Position = UDim2.new(0, 0, 0, (i - 1) * rowH)
		t.BackgroundTransparency = 1
		t.Font = Theme.font
		t.TextSize = size
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = Color3.fromRGB(235, 225, 210)
		t.Text = text
		t.Parent = list
		return t
	end
	label(1, Text.get("board.title"), math.floor(rowH * 0.8)).TextColor3 = Color3.fromRGB(255, 230, 120)
	boardRows = {}
	for i = 1, #stations do
		boardRows[i] = label(i + 1, "", math.floor(rowH * 0.62))
	end
	label(#stations + 2, Text.get("board.footer"), math.floor(rowH * 0.5))
end

local function track(inst)
	if inst:IsA("BasePart") then
		local kind = inst:GetAttribute("LiftPart")
		if kind then
			parts[inst] = kind
			if kind == "sign" and not signText then
				makeSign(inst)
			elseif kind == "basket" and not basketLight then
				basketLight = Instance.new("PointLight")
				basketLight.Color = GLOW
				basketLight.Range = 16
				basketLight.Brightness = 1.5
				basketLight.Parent = inst
			elseif kind == "vine" and inst.Size.Y >= L.vineDia - 0.01 then
				makeFireflies(inst)
			end
			paint()
		elseif inst:GetAttribute("StationBoard") and not boardRows then
			makeBoard(inst)
			paint()
		end
	elseif inst:IsA("ProximityPrompt") and inst.Name == "VineLiftPrompt" then
		prompt = inst
		paint()
	end
end

local ground = Workspace:WaitForChild("Ground")
for _, d in ipairs(ground:GetDescendants()) do
	track(d)
end
ground.DescendantAdded:Connect(track)
ground.DescendantRemoving:Connect(function(inst)
	parts[inst] = nil
	if prompt == inst then
		prompt = nil
	end
end)

-- 처음 해금: 이번 접속의 첫 값을 기준으로 가장 높은 열린 정거장이 올라가면 알림 1회 + 길 안내
local known = player:GetAttribute("PeakLevel") and highest() or nil
local guideUntil = 0
player:GetAttributeChangedSignal("PeakLevel"):Connect(function()
	local best = highest()
	if known ~= nil and best > known then
		local s = stations[best]
		Toast.push("TC", { text = Text.get("lift.unlockToast", { station = best, name = s.name, meters = metersOf(s) }), grade = "important", seconds = 5 })
		Wayfinder.setPoints(GUIDE_OWNER, { liftPoint })
		guideUntil = os.clock() + GUIDE_SECONDS
		print(("[forge-game] 덩굴 리프트 해금 알림: 정거장 %d(%s)"):format(best, s.name))
	end
	known = best
	paint()
end)
player:GetAttributeChangedSignal("TreeCheckpoint"):Connect(function()
	if guideUntil > 0 and player:GetAttribute("TreeCheckpoint") then
		guideUntil = 0
		Wayfinder.clear(GUIDE_OWNER)
	end
end)

-- 반딧불 켜기(열림 · 가까이) · 길 안내 끝(도착 · 시간)
task.spawn(function()
	while true do
		task.wait(0.5)
		local open = highest() > 0
		local camera = Workspace.CurrentCamera
		local near = camera and (camera.CFrame.Position - liftPoint).Magnitude <= L.fireflies.maxDistance
		for _, e in ipairs(fireflies or {}) do
			e.Enabled = open and near == true
		end
		if guideUntil > 0 then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local arrived = root and Vector3.new(root.Position.X - liftPoint.X, 0, root.Position.Z - liftPoint.Z).Magnitude <= L.basketRadius + 3
			if arrived or os.clock() > guideUntil then
				guideUntil = 0
				Wayfinder.clear(GUIDE_OWNER)
			end
		end
	end
end)

paint()
