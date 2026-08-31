-- 강화대 배치(10-2). 울타리(PRD-forge-game-roblox.md 20.16)가 실제로 쓰이는 첫 자리 -
-- WorldConfig.enhance.stationOffset이 울타리 경계선 바깥임을 이미 보장한다(계산 근거는
-- WorldConfig.lua 주석 참고). 모양은 기능 확인용 도형이다(몬스터와 같은 원칙, render 폴리시는 나중).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local function createEnhanceStation()
	local position = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset

	local model = Instance.new("Model")
	model.Name = "EnhanceStation"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(4, 3, 4)
	base.Anchored = true
	base.CanCollide = true
	base.Color = Color3.fromRGB(90, 90, 100)
	base.Position = position + Vector3.new(0, 1.5, 0)
	base.Parent = model

	local anvilTop = Instance.new("Part")
	anvilTop.Name = "AnvilTop"
	anvilTop.Size = Vector3.new(3, 1, 2)
	anvilTop.Anchored = true
	anvilTop.CanCollide = true
	anvilTop.Color = Color3.fromRGB(160, 130, 60)
	anvilTop.Position = position + Vector3.new(0, 3.5, 0)
	anvilTop.Parent = model

	local label = Instance.new("BillboardGui")
	label.Name = "NameplateGui"
	label.Size = UDim2.new(4, 0, 1, 0)
	label.StudsOffset = Vector3.new(0, 1.2, 0)
	label.AlwaysOnTop = true
	label.Adornee = anvilTop
	label.Parent = anvilTop

	local labelText = Instance.new("TextLabel")
	labelText.BackgroundTransparency = 1
	labelText.Size = UDim2.new(1, 0, 1, 0)
	labelText.Text = "강화대"
	labelText.TextColor3 = Color3.new(1, 1, 1)
	labelText.TextScaled = true
	labelText.Parent = label

	model.PrimaryPart = base
	model.Parent = Workspace

	return model
end

createEnhanceStation()
print("[forge-game] 강화대 배치 완료")
