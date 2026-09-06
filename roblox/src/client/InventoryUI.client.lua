-- 인벤토리 UI(12-1 [3]). 기능 확인 수준 - 목록과 착용/해제 버튼만 있다. 인벤토리는
-- Attribute가 아니라 InventorySync 이벤트로만 온다(배열이라 Attribute에 못 담는다) -
-- 접속 직후 놓칠 수 있는 첫 push는 InventoryFetch로 따로 받아온다(GoldHud 등의
-- "지금 값을 바로 읽는다" 패턴을 Attribute가 아닌 이 경우에 맞게 바꾼 것).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local Loot = require(ReplicatedStorage.Shared.Loot)

local inventorySync = ReplicatedStorage:WaitForChild("InventorySync")
local inventoryFetch = ReplicatedStorage:WaitForChild("InventoryFetch")
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")
local equipRequest = ReplicatedStorage:WaitForChild("EquipRequest")

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 다른 HUD가 없는 우측 중단에 둔다(좌상단=스테이지, 우상단=골드, 상단중앙=체력바,
-- 우하단=공격, 좌하단=직업변경, 하단중앙=강화).
local toggleButton = Instance.new("TextButton")
toggleButton.Name = "InventoryToggleButton"
toggleButton.AnchorPoint = Vector2.new(1, 0.5)
toggleButton.Position = UDim2.new(1, -16, 0.5, 0)
toggleButton.Size = UDim2.new(0, 90, 0, 36)
toggleButton.Text = "가방"
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 14
toggleButton.TextColor3 = Color3.new(1, 1, 1)
toggleButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
toggleButton.Parent = screenGui

local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -116, 0.5, 0)
panel.Size = UDim2.new(0, 300, 0, 360)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.new(0, 8, 0, 6)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "인벤토리"
title.Parent = panel

local equippedLabel = Instance.new("TextLabel")
equippedLabel.BackgroundTransparency = 1
equippedLabel.Size = UDim2.new(1, -16, 0, 20)
equippedLabel.Position = UDim2.new(0, 8, 0, 30)
equippedLabel.Font = Enum.Font.Gotham
equippedLabel.TextSize = 14
equippedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
equippedLabel.TextXAlignment = Enum.TextXAlignment.Left
equippedLabel.Text = "착용 중: 없음"
equippedLabel.Parent = panel

local unequipButton = Instance.new("TextButton")
unequipButton.Size = UDim2.new(0, 70, 0, 22)
unequipButton.Position = UDim2.new(1, -78, 0, 30)
unequipButton.Font = Enum.Font.Gotham
unequipButton.TextSize = 13
unequipButton.Text = "해제"
unequipButton.TextColor3 = Color3.new(1, 1, 1)
unequipButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
unequipButton.Parent = panel
unequipButton.Activated:Connect(function()
	equipRequest:FireServer("unequip")
end)

local listFrame = Instance.new("ScrollingFrame")
listFrame.BackgroundTransparency = 1
listFrame.Position = UDim2.new(0, 8, 0, 58)
listFrame.Size = UDim2.new(1, -16, 1, -66)
listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
listFrame.ScrollBarThickness = 6
listFrame.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = listFrame

toggleButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- 아이템 하나의 표시 텍스트: 등급 + 주운 스테이지 + 그 시점 방어력(실제 계산과 같은
-- 값이어야 한다 - Loot.getArmorDefense를 그대로 재사용해서 서버 계산과 어긋날 일이 없다).
local function describeItem(item)
	local grade = ArmorData.grades[item.grade]
	local defense = Loot.getArmorDefense(item)
	return ("%s 갑옷 (%d단계, 방어력 +%.1f)"):format(grade.displayName, item.dropStage, defense)
end

local function rebuild(state)
	equippedLabel.Text = state.armor and ("착용 중: " .. describeItem(state.armor)) or "착용 중: 없음"

	for _, child in ipairs(listFrame:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	for index, item in ipairs(state.inventory) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 28)
		row.BackgroundTransparency = 1
		row.LayoutOrder = index
		row.Parent = listFrame

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -76, 1, 0)
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = describeItem(item)
		label.Parent = row

		local equipButton = Instance.new("TextButton")
		equipButton.Size = UDim2.new(0, 70, 0, 22)
		equipButton.Position = UDim2.new(1, -70, 0, 3)
		equipButton.Font = Enum.Font.Gotham
		equipButton.TextSize = 13
		equipButton.Text = "착용"
		equipButton.TextColor3 = Color3.new(1, 1, 1)
		equipButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
		equipButton.Parent = row
		equipButton.Activated:Connect(function()
			equipRequest:FireServer("equip", index)
		end)
	end
end

inventorySync.OnClientEvent:Connect(rebuild)

local ok, initialState = pcall(function()
	return inventoryFetch:InvokeServer()
end)
if ok and initialState then
	rebuild(initialState)
end

inventoryFull.OnClientEvent:Connect(function()
	equippedLabel.Text = "인벤토리가 가득 찼습니다 - 드랍을 놓쳤습니다"
	task.delay(2, function()
		local state = { inventory = {}, armor = nil }
		local fetchOk, fetched = pcall(function()
			return inventoryFetch:InvokeServer()
		end)
		if fetchOk and fetched then
			state = fetched
		end
		rebuild(state)
	end)
end)
