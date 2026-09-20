-- 로딩 문구 한 줄(S12, PRD 20.73 [7-1]) - 화면 하단에 무작위 1개를 띄우고 게임이 다 불러와진 뒤 1초에 페이드아웃한다. 이미지 없음.
-- 로블록스 기본 로딩 화면은 끄지 않는다(RemoveDefaultLoadingScreen을 부르지 않는다). 새 색을 만들지 않으려고 기본 흰색 글씨 + 검은 외곽선만 쓴다.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LoadingTips = require(script.Parent:WaitForChild("LoadingTips"))

local FADE_SECONDS = 1

local index = math.random(#LoadingTips)

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Name = "LoadingTipGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "Tip"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -48)
label.Size = UDim2.new(0.8, 0, 0, 36)
label.BackgroundTransparency = 1
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextWrapped = true
label.TextColor3 = Color3.new(1, 1, 1)
label.TextStrokeColor3 = Color3.new(0, 0, 0)
label.TextStrokeTransparency = 0.4
label.Text = LoadingTips[index]
label.Parent = gui

print(("[LoadingTip] 문구 %d번 표시: %s"):format(index, LoadingTips[index]))

if not game:IsLoaded() then
	game.Loaded:Wait()
end
task.wait(1)
local fade = TweenService:Create(label, TweenInfo.new(FADE_SECONDS), { TextTransparency = 1, TextStrokeTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
