-- A2-N4 §4-6 GUI 트렌드 1차(ArtStyleV1 뒤 · 겉모습만): 요즘 인기 로블록스 게임 스타일 - 굵은 잉크 외곽선 · 둥근 큰 모서리 · 위가 밝은 그라데이션 · 글씨 외곽선.
--   대상 = HUD 슬롯(ArtV1UiData.guiTrend.targets - ScreenMap 인스턴스 이름) + 보스바 + 장비창 창(InventoryGui.Window). 창 틀(Panel)과 다른 창은 안 건드린다(회귀 범위 제한).
--   덧칠만: 기존 UIStroke · UICorner는 값만 올리고 원래 값을 Attribute로 적어 두었다가 아트 끄면 되돌린다 · 새로 붙인 것(Name = Trend*)은 지운다. 배치 · 크기 · 입력 불변.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArtV1UiData = require(ReplicatedStorage.Shared.data.ArtV1UiData)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)

local G = ArtV1UiData.guiTrend
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local targetNames = {}
for _, n in ipairs(G.targets) do
	targetNames[n] = true
end

local function on()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

local function isTarget(inst)
	local node = inst
	while node and node ~= playerGui do
		if targetNames[node.Name] or (node.Parent and targetNames[node.Parent.Name .. "/" .. node.Name]) then
			return true
		end
		node = node.Parent
	end
	return false
end

local function styleButton(b)
	if b:GetAttribute("TrendDone") then
		return
	end
	b:SetAttribute("TrendDone", true)
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if stroke then
		-- 기존 테는 굵기만: 색 · 투명도는 등급 · 선택 표시라 그대로(A2-N4 Play - 잉크로 덮자 착용 칸 노란 테가 사라졌다)
		stroke:SetAttribute("TrendWas", ("%g|%s|%g"):format(stroke.Thickness, stroke.Color:ToHex(), stroke.Transparency))
	else
		stroke = Instance.new("UIStroke")
		stroke.Name = "TrendStroke"
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Color = G.ink
		stroke.Transparency = 0
		stroke.Parent = b
	end
	stroke.Thickness = math.max(stroke.Thickness, G.strokeThickness)
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		if corner.CornerRadius.Scale == 0 then
			corner:SetAttribute("TrendWas", corner.CornerRadius.Offset)
			corner.CornerRadius = UDim.new(0, math.max(corner.CornerRadius.Offset, G.cornerRadius))
		end
	else
		corner = Instance.new("UICorner")
		corner.Name = "TrendCorner"
		corner.CornerRadius = UDim.new(0, G.cornerRadius)
		corner.Parent = b
	end
	if b.BackgroundTransparency < 0.6 and not b:FindFirstChildOfClass("UIGradient") then
		local grad = Instance.new("UIGradient")
		grad.Name = "TrendGradient"
		grad.Rotation = 90
		grad.Color = ColorSequence.new(Color3.new(1, 1, 1), G.gradientBottom)
		grad.Parent = b
	end
end

local function styleText(t)
	if t:GetAttribute("TrendDone") then
		return
	end
	t:SetAttribute("TrendDone", true)
	t:SetAttribute("TrendWas", t.TextStrokeTransparency)
	t.TextStrokeColor3 = G.ink
	t.TextStrokeTransparency = math.min(t.TextStrokeTransparency, G.textStroke)
end

local function apply(inst)
	if not on() or not isTarget(inst) then
		return
	end
	if inst:IsA("GuiButton") then
		styleButton(inst)
	elseif inst:IsA("Frame") and inst:FindFirstChildOfClass("UICorner") and inst.BackgroundTransparency < 0.6 then
		styleButton(inst) -- 칩(둥근 배경 프레임)
	end
	if inst:IsA("TextLabel") or inst:IsA("TextButton") then
		styleText(inst)
	end
end

local function revert()
	for _, d in ipairs(playerGui:GetDescendants()) do
		if d:GetAttribute("TrendDone") then
			d:SetAttribute("TrendDone", nil)
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d:GetAttribute("TrendWas") then
				d.TextStrokeTransparency = d:GetAttribute("TrendWas")
				d:SetAttribute("TrendWas", nil)
			end
		end
		if d.Name == "TrendStroke" or d.Name == "TrendCorner" or d.Name == "TrendGradient" then
			d:Destroy()
		elseif d:IsA("UIStroke") and d:GetAttribute("TrendWas") then
			local th, hex, tr = d:GetAttribute("TrendWas"):match("^([^|]+)|([^|]+)|([^|]+)$")
			d.Thickness, d.Color, d.Transparency = tonumber(th), Color3.fromHex(hex), tonumber(tr)
			d:SetAttribute("TrendWas", nil)
		elseif d:IsA("UICorner") and d:GetAttribute("TrendWas") then
			d.CornerRadius = UDim.new(0, d:GetAttribute("TrendWas"))
			d:SetAttribute("TrendWas", nil)
		end
	end
end

local function applyAll()
	for _, d in ipairs(playerGui:GetDescendants()) do
		apply(d)
	end
end

playerGui.DescendantAdded:Connect(function(d)
	task.defer(apply, d)
end)
Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(function()
	if on() then
		applyAll()
	else
		revert()
	end
end)
task.delay(3, applyAll)
