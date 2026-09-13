-- 버프 HUD(20-2b [1]) - 자기 자신에게 거는 지속 효과가 걸린 동안 화면에 보이지 않으면
-- 유저가 인지하지 못한다는 지시 그대로. 체력바 근처(PlayerHealthBar.client.lua의
-- BuffHudAnchor, 콤보 점 한 단 위)에 작은 아이콘 + 남은 시간을 가로로 나열한다.
-- 이미지 에셋 없이 도형(둥근 사각 프레임 + 색 채움)만 쓴다 - 18-2 스킬 슬롯의 메탈
-- 톤(어두운 그라디언트 배경 + 밝은 테두리)과 같은 어휘를 재사용한다.
--
-- 서버(BuffState.lua)가 유일한 진실이다 - 이 스크립트는 BuffUpdate 이벤트를 받아
-- 표시만 한다. 시간 기반 버프는 서버가 준 remainingSeconds로 로컬 카운트다운만 돌리고
-- (쿨다운 링과 같은 "낙관적 표시" 원칙 - 매초 서버가 다시 알려줄 필요 없다), 횟수 기반
-- 버프는 서버가 충전을 소모할 때마다 새 값을 보내준다(정확한 소모 시점은 클라가 예측할
-- 수 없다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local buffUpdate = ReplicatedStorage:WaitForChild("BuffUpdate")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local anchor = playerGui:WaitForChild("PlayerHealthBarGui"):WaitForChild("BuffHudAnchor")

local ICON_SIZE = 28
local ICON_GAP = 6

local row = Instance.new("UIListLayout")
row.FillDirection = Enum.FillDirection.Horizontal
row.HorizontalAlignment = Enum.HorizontalAlignment.Center
row.VerticalAlignment = Enum.VerticalAlignment.Center
row.Padding = UDim.new(0, ICON_GAP)
row.SortOrder = Enum.SortOrder.Name
row.Parent = anchor

-- [buffId] = { frame, label, expiresAt(초 단위 os.clock 기준, nil이면 시간 기반이 아님) }
local icons = {}

local function buildIcon(buffId, color)
	local frame = Instance.new("Frame")
	frame.Name = buffId
	frame.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	frame.BackgroundColor3 = UIColors.metalBottom
	frame.Parent = anchor

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = frame

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(UIColors.metalTop, UIColors.metalBottom)
	gradient.Rotation = 90
	gradient.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 1.5
	stroke.Parent = frame

	-- 도형만으로 "버프가 걸려 있다"를 보여주는 채움(이미지 에셋 없음, 지시 그대로) - 안쪽에
	-- 버프 색으로 살짝 발광하는 작은 사각형.
	local fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0.5, 0.5)
	fill.Position = UDim2.new(0.5, 0, 0.42, 0)
	fill.Size = UDim2.new(0, 12, 0, 12)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = frame
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -2)
	label.Size = UDim2.new(1, -4, 0, 12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = UIColors.textPrimary
	label.Text = ""
	label.Parent = frame

	return { frame = frame, label = label }
end

local function removeIcon(buffId)
	local entry = icons[buffId]
	if not entry then
		return
	end
	entry.frame:Destroy()
	icons[buffId] = nil
end

buffUpdate.OnClientEvent:Connect(function(buffId, data)
	if not data.active then
		removeIcon(buffId)
		return
	end

	local color = (data.colorName and UIColors[data.colorName]) or UIColors.ember
	local entry = icons[buffId]
	if not entry then
		entry = buildIcon(buffId, color)
		icons[buffId] = entry
	end

	entry.expiresAt = data.remainingSeconds and (os.clock() + data.remainingSeconds) or nil
	entry.chargesRemaining = data.chargesRemaining
end)

-- 로컬 카운트다운(쿨다운 링과 같은 원칙 - 매초 서버 왕복 없이 클라가 직접 센다). 횟수
-- 기반 버프는 charges 숫자를 그대로 보여준다(시간이 없으므로 셀 게 없다).
local RunService = game:GetService("RunService")
RunService.Heartbeat:Connect(function()
	for buffId, entry in pairs(icons) do
		if entry.expiresAt then
			local remaining = entry.expiresAt - os.clock()
			if remaining <= 0 then
				removeIcon(buffId)
			else
				entry.label.Text = remaining < 1 and ("%.1f"):format(remaining) or ("%d"):format(math.ceil(remaining))
			end
		elseif entry.chargesRemaining then
			entry.label.Text = tostring(entry.chargesRemaining)
		end
	end
end)
