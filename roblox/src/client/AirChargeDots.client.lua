-- 공중 점프 충전 표시(M1-0): 자기 캐릭터 발밑의 작은 점(충전 수만큼 - 남은 것 = 노랑, 쓴 것 = 회색) + 공중대시 1칸. 밝은 바닥에서 투명도로는 구분이 안 됐다(스크린샷) - 색을 바꾼다. PC · 폰 같은 모양이라 HUD 자리(ScreenMap)가 필요 없다.
-- M1-0 후속(사용자): 공중대시 칸 = 화살표(">" - 둥근 점과 모양이 다르다) · 지금 쓸 수 있을 때만 초록(success), 이 체공에 이미 썼거나 대시 쿨다운 중이면 회색. 발밑은 점프 · 대시 표시 전용(3타 고리는 무기 발광으로 옮겼다).
-- 떠 있는 동안만 보인다(땅에서는 늘 가득이라 숨긴다). 값 = 캐릭터 Attribute "AirJumpsLeft" · "AirDashesUsed" · "DashReadyAt" · "DashSecondUntil"(DoubleJumpInput · DashInput이 이 클라에서 쓴다). 남에게는 안 보인다.
-- MV1: 점 수 = 해금된 공중 점프(MoveRules.tierOf - 0이면 점 없음) · 화살표 = 한 체공 공중 대시 수(태초 신발 2). 칸은 최대만큼 만들어 두고 안 쓰는 칸을 숨긴다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)

local player = Players.LocalPlayer
local charges = MovementConfig.airJump.charges -- 칸 최대(해금 최대)
local DASH_MAX = DashConfig.primordialShoes.charges

local DOT = 12
local GAP = 6

local gui = Instance.new("BillboardGui")
gui.Name = "AirChargeDots"
gui.Size = UDim2.new(0, (charges + DASH_MAX) * (DOT + GAP) + GAP, 0, DOT + 4)
gui.StudsOffset = Vector3.new(0, -MovementConfig.rootAboveFeetStuds - 0.6, 0) -- 루트 기준 발 조금 아래
gui.AlwaysOnTop = true
gui.LightInfluence = 0
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function cell(index, color)
	local frame = Instance.new("Frame")
	frame.Name = "Cell" .. index
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.new(0, DOT, 0, DOT)
	frame.Position = UDim2.new(0, GAP + (index - 1) * (DOT + GAP) + DOT / 2, 0.5, 0)
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.panel
	stroke.Thickness = 1
	stroke.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = frame
	return frame
end

local jumpCells = {}
for i = 1, charges do
	jumpCells[i] = cell(i, UIColors.xp)
end

-- 화살표(">") = 막대 둘을 ±45°로 세운 것(새 에셋 없이). 막대마다 색을 칠한다. MV1: 공중 대시 수만큼(최대 DASH_MAX).
local dashArrows = {}
for d = 1, DASH_MAX do
	local holder = Instance.new("Frame")
	holder.Name = d == 1 and "DashArrow" or ("DashArrow" .. d)
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.new(0, DOT, 0, DOT)
	holder.BackgroundTransparency = 1
	holder.Parent = gui
	local bars = {}
	for i, sign in ipairs({ 1, -1 }) do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Size = UDim2.new(0, 10, 0, 4)
		bar.Position = UDim2.new(0.5, 0, 0.5, sign * -3)
		bar.Rotation = sign * 45
		bar.BorderSizePixel = 0
		bar.Parent = holder
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIColors.panel
		stroke.Thickness = 1
		stroke.Parent = bar
		bars[i] = bar
	end
	dashArrows[d] = { holder = holder, bars = bars }
end

local function primordialShoes()
	local parts = player:GetAttribute("PrimordialParts")
	return type(parts) == "string" and parts:find("shoes", 1, true) ~= nil
end

local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }
local ART_SIDE_STUDS = 1.9 -- 아트 켬: 발 옆(화면 오른쪽)
local hasCells = true -- 보일 칸이 있나(아트 켬 + 공중 점프 해금 0 = 줄 숨김)

local function render(character)
	local unlocked = (MoveRules.tierOf(player)).airJumps
	local left = character:GetAttribute("AirJumpsLeft") or unlocked
	local dashes = MoveRules.airDashesAllowed(primordialShoes())
	local slot = 0
	for i, frame in ipairs(jumpCells) do
		frame.Visible = i <= unlocked
		if frame.Visible then
			slot += 1
			frame.Position = UDim2.new(0, GAP + (slot - 1) * (DOT + GAP) + DOT / 2, 0.5, 0)
		end
		frame.BackgroundColor3 = i <= left and UIColors.xp or UIColors.lockedIcon
	end
	local readyAt = character:GetAttribute("DashReadyAt") or 0
	local secondUntil = character:GetAttribute("DashSecondUntil") or 0
	local used = character:GetAttribute("AirDashesUsed") or 0
	local now = os.clock()
	-- QUEUE-ALL1 01 B(아트 켬): 대시 표시는 Shift 칸(SkillSlots - 원형 쿨 + 칸 아래 충전 점)으로 - 발 옆에는 공중 점프 점만 · 끔 = 옛 줄
	local art = workspace:GetAttribute("ArtStyleV1") == true
	gui.StudsOffset = art and Vector3.new(ART_SIDE_STUDS, -MovementConfig.rootAboveFeetStuds + 0.4, 0) or Vector3.new(0, -MovementConfig.rootAboveFeetStuds - 0.6, 0)
	hasCells = not art or unlocked > 0
	for d, arrow in ipairs(dashArrows) do
		arrow.holder.Visible = d <= dashes and not art
		if arrow.holder.Visible then
			slot += 1
			arrow.holder.Position = UDim2.new(0, GAP + (slot - 1) * (DOT + GAP) + DOT / 2, 0.5, 0)
		end
		local usable = d > used and (now >= readyAt or now <= secondUntil)
		for _, bar in ipairs(arrow.bars) do
			bar.BackgroundColor3 = usable and UIColors.success or UIColors.lockedIcon
		end
	end
	local nextChange = (now < secondUntil and secondUntil) or (now < readyAt and readyAt) or nil
	if nextChange and nextChange ~= readyAt then
		task.delay(nextChange - now + 0.02, function()
			if character.Parent then
				render(character)
			end
		end)
	end
	if os.clock() < readyAt then
		task.delay(readyAt - os.clock() + 0.02, function() -- 쿨다운이 끝나는 순간 초록으로
			if character.Parent then
				render(character)
			end
		end)
	end
end

local function bind(character)
	local humanoid = character:WaitForChild("Humanoid")
	gui.Adornee = character:WaitForChild("HumanoidRootPart")
	gui.Enabled = false
	render(character)
	character:GetAttributeChangedSignal("AirJumpsLeft"):Connect(function()
		render(character)
	end)
	for _, name in ipairs({ "AirDashesUsed", "DashSecondUntil" }) do
		character:GetAttributeChangedSignal(name):Connect(function()
			render(character)
		end)
	end
	character:GetAttributeChangedSignal("DashReadyAt"):Connect(function()
		render(character)
	end)
	humanoid.StateChanged:Connect(function(_, new)
		render(character)
		gui.Enabled = AIR[new] == true and humanoid.Health > 0 and hasCells
	end)
end

if player.Character then
	task.spawn(bind, player.Character)
end
player.CharacterAdded:Connect(bind)
