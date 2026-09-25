-- 공중 점프 충전 표시(M1-0): 자기 캐릭터 발밑의 작은 점(충전 수만큼 - 남은 것 = 밝음, 쓴 것 = 어두움) + 공중대시 1칸(마름모 - 쓰면 어두움). PC · 폰 같은 모양이라 HUD 자리(ScreenMap)가 필요 없다.
-- 떠 있는 동안만 보인다(땅에서는 늘 가득이라 숨긴다). 값 = 캐릭터 Attribute "AirJumpsLeft" · "AirDashUsed"(DoubleJumpInput · DashInput이 이 클라에서 쓴다). 남에게는 안 보인다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local player = Players.LocalPlayer
local charges = MovementConfig.airJump.charges

local DOT = 10
local GAP = 6
local DIM = 0.7 -- 쓴 칸의 배경 투명도

local gui = Instance.new("BillboardGui")
gui.Name = "AirChargeDots"
gui.Size = UDim2.new(0, (charges + 1) * (DOT + GAP) + GAP, 0, DOT + 4)
gui.StudsOffset = Vector3.new(0, -MovementConfig.rootAboveFeetStuds - 0.6, 0) -- 루트 기준 발 조금 아래
gui.AlwaysOnTop = true
gui.LightInfluence = 0
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local function cell(index, color, rotation)
	local frame = Instance.new("Frame")
	frame.Name = "Cell" .. index
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.new(0, DOT, 0, DOT)
	frame.Position = UDim2.new(0, GAP + (index - 1) * (DOT + GAP) + DOT / 2, 0.5, 0)
	frame.Rotation = rotation or 0
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.panel
	stroke.Thickness = 1
	stroke.Parent = frame
	if not rotation then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = frame
	end
	return frame
end

local jumpCells = {}
for i = 1, charges do
	jumpCells[i] = cell(i, UIColors.textPrimary)
end
local dashCell = cell(charges + 1, UIColors.ember, 45)

local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }

local function render(character)
	local left = character:GetAttribute("AirJumpsLeft") or charges
	for i, frame in ipairs(jumpCells) do
		frame.BackgroundTransparency = i <= left and 0 or DIM
	end
	dashCell.BackgroundTransparency = character:GetAttribute("AirDashUsed") and DIM or 0
end

local function bind(character)
	local humanoid = character:WaitForChild("Humanoid")
	gui.Adornee = character:WaitForChild("HumanoidRootPart")
	gui.Enabled = false
	render(character)
	character:GetAttributeChangedSignal("AirJumpsLeft"):Connect(function()
		render(character)
	end)
	character:GetAttributeChangedSignal("AirDashUsed"):Connect(function()
		render(character)
	end)
	humanoid.StateChanged:Connect(function(_, new)
		gui.Enabled = AIR[new] == true and humanoid.Health > 0
	end)
end

if player.Character then
	task.spawn(bind, player.Character)
end
player.CharacterAdded:Connect(bind)
