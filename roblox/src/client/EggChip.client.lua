-- M1-3 [알] 버튼: 오른쪽 칩 스택의 설정 버튼 **왼쪽 옆**(설정 버튼의 자식 - 스택 높이를 늘리지 않는다: 폰 높이 302에서 스택 아래 끝이 넘치지 않게). 누르면 알 가방 · 정보창(panels/EggInfo).
--   보이는 원 = 설정 버튼과 같은 34(세로 가운데를 맞춘다) · 누르는 영역 = 44 × 44(모바일 터치 타깃 규칙). 알 모양 = 둥근 틀(새 에셋 없음) · 알이 있으면 개수.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local NestState = require(script.Parent.NestState)
local EggInfo = require(script.Parent.panels.EggInfo)

local player = Players.LocalPlayer
local chipsGui = player:WaitForChild("PlayerGui"):WaitForChild("TopChipsGui", 60) -- StageUI.client.lua
local row = chipsGui and chipsGui:WaitForChild("TopChipsRow", 60)
local settings = row and row:WaitForChild("SettingsButton", 60)
if not settings then
	warn("[forge-game] 알 버튼: 설정 버튼 없음")
	return
end

local button = Instance.new("TextButton")
button.Name = "EggButton"
button.AnchorPoint = Vector2.new(1, 0.5)
button.Position = UDim2.new(0, -4, 0.5, 0) -- 설정 원 왼쪽 끝 − 4(누르는 영역 44의 오른쪽 끝)
button.Size = UDim2.new(0, 44, 0, 44)
button.Text = ""
button.AutoButtonColor = false
button.BackgroundTransparency = 1
button.Parent = settings

local circle = Instance.new("Frame")
circle.Name = "Circle"
circle.AnchorPoint = Vector2.new(1, 0.5)
circle.Position = UDim2.new(1, 0, 0.5, 0)
circle.Size = UDim2.new(0, 34, 0, 34)
circle.BackgroundColor3 = UIColors.panel
circle.BackgroundTransparency = UIColors.panelTransparency
circle.Parent = button
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = circle
local stroke = Instance.new("UIStroke")
stroke.Color = UIColors.rim
stroke.Transparency = UIColors.rimTransparency
stroke.Thickness = 1
stroke.Parent = circle

local egg = Instance.new("Frame")
egg.Name = "EggIcon"
egg.AnchorPoint = Vector2.new(0.5, 0.5)
egg.Position = UDim2.new(0.5, 0, 0.5, 0)
egg.Size = UDim2.new(0, 13, 0, 17)
egg.BackgroundColor3 = UIColors.textPrimary
egg.Parent = circle
local eggCorner = Instance.new("UICorner")
eggCorner.CornerRadius = UDim.new(0.5, 0)
eggCorner.Parent = egg
local band = Instance.new("Frame")
band.Name = "EggBand"
band.BorderSizePixel = 0
band.Size = UDim2.new(1, 0, 0, 2)
band.Position = UDim2.new(0, 0, 0.55, 0)
band.BackgroundColor3 = UIColors.gold
band.Parent = egg

local count = Instance.new("TextLabel")
count.Name = "EggCount"
count.AnchorPoint = Vector2.new(1, 1)
count.Position = UDim2.new(1, 2, 1, 2)
count.Size = UDim2.new(0, 18, 0, 14)
count.BackgroundColor3 = UIColors.ember
count.TextColor3 = UIColors.textPrimary
count.Font = Enum.Font.GothamBold
count.TextSize = 12
count.Text = ""
count.Visible = false
count.Parent = circle
local countCorner = Instance.new("UICorner")
countCorner.CornerRadius = UDim.new(1, 0)
countCorner.Parent = count

local function update()
	local n = #NestState.eggs
	count.Visible = n > 0
	count.Text = tostring(n)
end
NestState.changed:Connect(update)
update()

button.Activated:Connect(EggInfo.toggle)
