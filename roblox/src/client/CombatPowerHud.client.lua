-- QUEUE-10h Q7-5 전투력(CP) 칩: 상단 칩 행(TopChipsRow - 골드 1 · 레벨 2 · 스테이지 3)의 4번째. 값 = 서버 CombatPowerSync가 1초마다 쓰는 Player Attribute "CombatPower"(C2 전투력 - 판정과 같은 값).
--   오를 때만 짧은 연출(0.4초 - 칩이 살짝 커졌다 돌아오고 숫자가 경험치색으로 번쩍) · 극적 연출 없음. 숫자 = NumberFormat(큰 수 줄임).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local HudChip = require(script.Parent.HudChip)

local player = Players.LocalPlayer
local topChipsRow = player:WaitForChild("PlayerGui"):WaitForChild("TopChipsGui"):WaitForChild("TopChipsRow")
local chip = HudChip.new(topChipsRow, 4)
chip.Name = "CombatPowerChip"

local prefix = Instance.new("TextLabel")
prefix.Name = "Prefix"
prefix.LayoutOrder = 1
prefix.BackgroundTransparency = 1
prefix.AutomaticSize = Enum.AutomaticSize.X
prefix.Size = UDim2.new(0, 0, 1, 0)
prefix.Font = Enum.Font.GothamBold
prefix.TextSize = 13
prefix.TextColor3 = UIColors.textSecondary
prefix.Text = "CP"
prefix.Parent = chip

local value = Instance.new("TextLabel")
value.Name = "CombatPowerLabel"
value.LayoutOrder = 2
value.BackgroundTransparency = 1
value.AutomaticSize = Enum.AutomaticSize.X
value.Size = UDim2.new(0, 0, 1, 0)
value.Font = Enum.Font.GothamBold
value.TextSize = 13
value.TextColor3 = UIColors.textPrimary
value.Text = "-"
value.Parent = chip

local scale = Instance.new("UIScale")
scale.Parent = chip

local last
local function refresh()
	local power = player:GetAttribute("CombatPower")
	if type(power) ~= "number" then
		return
	end
	local shown = CombatFormula.display and CombatFormula.display(power) or power
	value.Text = NumberFormat.format(shown)
	if last and power > last * 1.0005 then -- 오를 때만(흔들림 무시)
		scale.Scale = 1.12
		value.TextColor3 = UIColors.xp
		TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(value, TweenInfo.new(0.4), { TextColor3 = UIColors.textPrimary }):Play()
	end
	last = power
end

player:GetAttributeChangedSignal("CombatPower"):Connect(refresh)
refresh()
