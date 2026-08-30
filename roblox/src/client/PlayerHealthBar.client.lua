-- 플레이어 체력바 9-5 개정. 20칸 분절 표시(9-5 최초안)를 대체한다 - 피격 상한을
-- 없앤 뒤로는 "몇 칸 남았나"보다 "지금 상대하는 몬스터한테 몇 대 맞으면 죽나"가
-- 진짜 정보다. 세 겹으로 쌓는다(PRD-forge-game-roblox.md 20.15 참고):
--   [1] 게이지 - 비율대로 깎이는 막대 하나(디아블로식). 화면상 길이는 항상 같다.
--   [2] 눈금 - 지금 상대하는 몬스터의 평타 1회 피해량 = 눈금 하나(롤식). 개수를
--       고정하지 않는다 - 방어구가 좋아지면 눈금이 촘촘해지고, 스펙이 모자란
--       구역에서는 눈금이 1개로 줄어 "한 방이다"가 화면에 뜬다.
--   [3] 숫자 - 축약 없는 원본(K/M/B/T 전환은 NumberFormat/20.9-1이 이미 정한
--       10,000 기준을 그대로 쓴다) + 이전보다 큰 글씨.
-- HP·눈금 기준값 전부 서버 Attribute(Hp/MaxHp/TickDamage)만 읽는다 - 서버
-- PlayerState/MonsterAI.server.lua가 유일한 소스다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local BAR_WIDTH, BAR_HEIGHT = 440, 34

-- 눈금이 이보다 많아지면(수십 개 이상) 낱개 가는 눈금 대신 대표 눈금 약 10개만
-- 굵게 그린다 - 안 그러면 선이 겹쳐 안 보인다. 적을 땐 실제 타수를 그대로 보여준다.
local MINOR_TICK_LIMIT = 20

local NORMAL_FILL_COLOR = Color3.fromRGB(214, 60, 60)
local DANGER_FILL_COLOR = Color3.fromRGB(255, 30, 30)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHealthBarGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local container = Instance.new("Frame")
container.Name = "HealthBar"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 20)
container.Size = UDim2.new(0, BAR_WIDTH, 0, BAR_HEIGHT)
container.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
container.BorderSizePixel = 0
container.ClipsDescendants = true
container.Parent = screenGui

local containerCorner = Instance.new("UICorner")
containerCorner.CornerRadius = UDim.new(0, 6)
containerCorner.Parent = container

-- 위험 경고(9-5 개정) - "3칸 이하" 대신 "남은 눈금 1개 이하"로 다시 정의했다.
-- 상한을 없앤 지금은 칸 개념 자체가 없고, 눈금이 진짜 위험도를 나타내기 때문이다.
local dangerStroke = Instance.new("UIStroke")
dangerStroke.Name = "DangerStroke"
dangerStroke.Thickness = 3
dangerStroke.Color = Color3.fromRGB(255, 60, 60)
dangerStroke.Transparency = 1
dangerStroke.Parent = container

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BorderSizePixel = 0
fill.BackgroundColor3 = NORMAL_FILL_COLOR
fill.Size = UDim2.new(1, 0, 1, 0)
fill.ZIndex = 1
fill.Parent = container

local tickHolder = Instance.new("Frame")
tickHolder.Name = "Ticks"
tickHolder.BackgroundTransparency = 1
tickHolder.Size = UDim2.new(1, 0, 1, 0)
tickHolder.ZIndex = 2
tickHolder.Parent = container

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpLabel"
hpLabel.BackgroundTransparency = 1
hpLabel.Size = UDim2.new(1, 0, 1, 0)
hpLabel.Text = ""
hpLabel.Font = Enum.Font.GothamBold
hpLabel.TextSize = 22
hpLabel.TextColor3 = Color3.new(1, 1, 1)
hpLabel.ZIndex = 3
hpLabel.Parent = container

local hpLabelStroke = Instance.new("UIStroke")
hpLabelStroke.Thickness = 2
hpLabelStroke.Color = Color3.new(0, 0, 0)
hpLabelStroke.Parent = hpLabel

local tickFrames = {}

local function clearTicks()
	for _, frame in ipairs(tickFrames) do
		frame:Destroy()
	end
	tickFrames = {}
end

-- 눈금 하나 = 지금 상대하는 몬스터의 평타 1회 피해량(TickDamage). 위협이 없으면
-- (TickDamage<=0, MonsterAI.server.lua가 전투 종료 시 0으로 지운다) 눈금을 아예
-- 안 그린다 - "몇 대"는 상대가 있을 때만 의미있다.
local function rebuildTicks(maxHp, tickDamage)
	clearTicks()
	if tickDamage <= 0 or maxHp <= 0 then
		return
	end

	local rawTickCount = math.floor(maxHp / tickDamage)
	if rawTickCount < 1 then
		return
	end

	local step, thickness = 1, 1
	if rawTickCount > MINOR_TICK_LIMIT then
		step = math.ceil(rawTickCount / 10)
		thickness = 2
	end

	for i = step, rawTickCount - 1, step do
		local fraction = (i * tickDamage) / maxHp
		local tickLine = Instance.new("Frame")
		tickLine.BorderSizePixel = 0
		tickLine.BackgroundColor3 = Color3.new(0, 0, 0)
		tickLine.BackgroundTransparency = 0.35
		tickLine.Size = UDim2.new(0, thickness, 1, 0)
		tickLine.Position = UDim2.new(fraction, -thickness / 2, 0, 0)
		tickLine.ZIndex = 2
		tickLine.Parent = tickHolder
		table.insert(tickFrames, tickLine)
	end
end

local isDanger = false

local function updateFillAndLabel()
	local hp = player:GetAttribute("Hp")
	local maxHp = player:GetAttribute("MaxHp")
	if not hp or not maxHp or maxHp <= 0 then
		return
	end

	local ratio = math.clamp(hp / maxHp, 0, 1)
	fill.Size = UDim2.new(ratio, 0, 1, 0)
	hpLabel.Text = ("%s / %s"):format(NumberFormat.format(hp), NumberFormat.format(maxHp))

	local tickDamage = player:GetAttribute("TickDamage") or 0
	local remainingHits = tickDamage > 0 and (hp / tickDamage) or math.huge
	isDanger = remainingHits <= 1
end

local function updateTicks()
	local maxHp = player:GetAttribute("MaxHp") or 0
	local tickDamage = player:GetAttribute("TickDamage") or 0
	rebuildTicks(maxHp, tickDamage)
end

player:GetAttributeChangedSignal("Hp"):Connect(updateFillAndLabel)
player:GetAttributeChangedSignal("MaxHp"):Connect(function()
	updateFillAndLabel()
	updateTicks()
end)
player:GetAttributeChangedSignal("TickDamage"):Connect(function()
	updateFillAndLabel()
	updateTicks()
end)
updateFillAndLabel()
updateTicks()

RunService.RenderStepped:Connect(function()
	if isDanger then
		fill.BackgroundColor3 = DANGER_FILL_COLOR
		local pulse = (math.sin(os.clock() * 10) + 1) / 2
		dangerStroke.Transparency = 1 - pulse
	else
		fill.BackgroundColor3 = NORMAL_FILL_COLOR
		dangerStroke.Transparency = 1
	end
end)
