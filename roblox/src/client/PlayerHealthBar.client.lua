-- 플레이어 체력바. PRD-forge-game.md 5.2 "체력·데미지 표시" 확정 설계를 그대로 옮긴다:
-- 칸 개수는 항상 20(최대체력에 비례시키지 않는다 - 안 그러면 무한 모드 후반에 칸이
-- 10^300개가 된다), 칸 하나의 값 = 최대체력/20, 10+10 두 줄(마인크래프트식), 부분 채움 지원.
-- HP는 서버 PlayerState가 유일한 소스다 - 여기선 서버가 Player Attribute로 보내주는 값만
-- 읽고 그린다(MonsterAI.server.lua의 syncHud 참고).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

local CELL_COUNT = 20
local CELLS_PER_ROW = 10
local CELL_W, CELL_H, GAP = 32, 24, 4

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PlayerHealthBarGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local rowWidth = CELLS_PER_ROW * CELL_W + (CELLS_PER_ROW - 1) * GAP
local container = Instance.new("Frame")
container.Name = "HealthBar"
container.AnchorPoint = Vector2.new(0.5, 0)
container.Position = UDim2.new(0.5, 0, 0, 20)
container.Size = UDim2.new(0, rowWidth, 0, CELL_H * 2 + GAP)
container.BackgroundTransparency = 1
container.Parent = screenGui

local hpLabel = Instance.new("TextLabel")
hpLabel.Name = "HpLabel"
hpLabel.AnchorPoint = Vector2.new(0.5, 0)
hpLabel.Position = UDim2.new(0.5, 0, 1, 4)
hpLabel.Size = UDim2.new(0, rowWidth, 0, 20)
hpLabel.BackgroundTransparency = 1
hpLabel.TextColor3 = Color3.new(1, 1, 1)
hpLabel.TextScaled = true
hpLabel.Font = Enum.Font.SourceSansBold
hpLabel.Parent = container

-- 칸 i(0-based)는 아래줄부터 채운다 - row 0(i=0~9)이 아래, row 1(i=10~19)이 위
-- (core/render.js drawPlayerHealthBar와 같은 규칙).
local fills = {}
for i = 0, CELL_COUNT - 1 do
	local row = math.floor(i / CELLS_PER_ROW)
	local col = i % CELLS_PER_ROW

	local cellBg = Instance.new("Frame")
	cellBg.Name = "Cell" .. i
	cellBg.BorderSizePixel = 0
	cellBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	cellBg.Position = UDim2.new(0, col * (CELL_W + GAP), 0, (1 - row) * (CELL_H + GAP))
	cellBg.Size = UDim2.new(0, CELL_W, 0, CELL_H)
	cellBg.Parent = container

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = cellBg

	local cellFill = Instance.new("Frame")
	cellFill.Name = "Fill"
	cellFill.BorderSizePixel = 0
	cellFill.BackgroundColor3 = Color3.fromRGB(224, 92, 92)
	cellFill.Size = UDim2.new(0, 0, 1, 0)
	cellFill.Parent = cellBg

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 3)
	fillCorner.Parent = cellFill

	fills[i] = cellFill
end

local function render(hp, maxHp)
	hpLabel.Text = ("%s / %s"):format(NumberFormat.format(hp), NumberFormat.format(maxHp))

	if maxHp <= 0 then
		return
	end
	local cellValue = maxHp / CELL_COUNT

	for i = 0, CELL_COUNT - 1 do
		local ratio = (hp - i * cellValue) / cellValue
		ratio = math.clamp(ratio, 0, 1)
		fills[i].Size = UDim2.new(ratio, 0, 1, 0)
	end
end

local function renderFromAttributes()
	local hp = player:GetAttribute("Hp")
	local maxHp = player:GetAttribute("MaxHp")
	if hp and maxHp then
		render(hp, maxHp)
	end
end

player:GetAttributeChangedSignal("Hp"):Connect(renderFromAttributes)
player:GetAttributeChangedSignal("MaxHp"):Connect(renderFromAttributes)
renderFromAttributes()
