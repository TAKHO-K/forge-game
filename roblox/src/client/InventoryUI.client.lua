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
local sellRequest = ReplicatedStorage:WaitForChild("SellRequest")
local lockRequest = ReplicatedStorage:WaitForChild("LockRequest")

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

-- 일괄 판매(13-1 [3]) - "일반 등급 이하 전부"만 최소 범위로 둔다(ArmorData.gradeOrder에서
-- normal이 맨 아래라 사실상 "잡템 전부"와 같다 - 지금 2등급뿐이라 이게 자연스러운 최소치).
-- 잠긴 아이템은 서버(PlayerProfile.sellArmorBulkUpTo)가 알아서 제외한다.
local bulkSellButton = Instance.new("TextButton")
bulkSellButton.Size = UDim2.new(1, -16, 0, 22)
bulkSellButton.Position = UDim2.new(0, 8, 0, 54)
bulkSellButton.Font = Enum.Font.Gotham
bulkSellButton.TextSize = 13
bulkSellButton.Text = "일반 등급 이하 일괄판매"
bulkSellButton.TextColor3 = Color3.new(1, 1, 1)
bulkSellButton.BackgroundColor3 = Color3.fromRGB(70, 70, 50)
bulkSellButton.Parent = panel
bulkSellButton.Activated:Connect(function()
	sellRequest:FireServer("sellBulk", "normal")
end)

local listFrame = Instance.new("ScrollingFrame")
listFrame.BackgroundTransparency = 1
listFrame.Position = UDim2.new(0, 8, 0, 80)
listFrame.Size = UDim2.new(1, -16, 1, -88)
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

-- 아이템 하나의 표시 텍스트: 등급 + 주운 스테이지 + 그 시점 방어력 + 판매가(전부 실제 계산과
-- 같은 값이어야 한다 - Loot.getArmorDefense/getSellPrice를 그대로 재사용해서 서버 계산과
-- 어긋날 일이 없다). 잠긴 아이템은 앞에 표시해 UI에서도 바로 구분되게 한다.
local function describeItem(item)
	local grade = ArmorData.grades[item.grade]
	local defense = Loot.getArmorDefense(item)
	local price = Loot.getSellPrice(item)
	local lockPrefix = item.locked and "[잠금] " or ""
	return ("%s%s 갑옷 (%d단계, 방어력 +%.1f, 판매가 %d)"):format(
		lockPrefix, grade.displayName, item.dropStage, defense, price)
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
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundTransparency = 1
		row.LayoutOrder = index
		row.Parent = listFrame

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, 0, 0, 24)
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.Text = describeItem(item)
		label.Parent = row

		local equipButton = Instance.new("TextButton")
		equipButton.Size = UDim2.new(0, 56, 0, 22)
		equipButton.Position = UDim2.new(0, 0, 0, 24)
		equipButton.Font = Enum.Font.Gotham
		equipButton.TextSize = 13
		equipButton.Text = "착용"
		equipButton.TextColor3 = Color3.new(1, 1, 1)
		equipButton.BackgroundColor3 = Color3.fromRGB(60, 80, 60)
		equipButton.Parent = row
		equipButton.Activated:Connect(function()
			equipRequest:FireServer("equip", index)
		end)

		-- 잠긴 아이템은 판매 버튼 자체를 안 보여준다(13-1 [2] - 잠금이 개별 판매도 막는다는
		-- 결정을 UI에도 그대로 반영 - 눌러봐야 서버가 거부할 버튼을 만들지 않는다).
		if not item.locked then
			local sellButton = Instance.new("TextButton")
			sellButton.Size = UDim2.new(0, 56, 0, 22)
			sellButton.Position = UDim2.new(0, 60, 0, 24)
			sellButton.Font = Enum.Font.Gotham
			sellButton.TextSize = 13
			sellButton.Text = "판매"
			sellButton.TextColor3 = Color3.new(1, 1, 1)
			sellButton.BackgroundColor3 = Color3.fromRGB(80, 60, 60)
			sellButton.Parent = row
			sellButton.Activated:Connect(function()
				sellRequest:FireServer("sell", index)
			end)
		end

		local lockButton = Instance.new("TextButton")
		lockButton.Size = UDim2.new(0, 56, 0, 22)
		lockButton.Position = UDim2.new(1, -56, 0, 24)
		lockButton.Font = Enum.Font.Gotham
		lockButton.TextSize = 13
		lockButton.Text = item.locked and "해제" or "잠금"
		lockButton.TextColor3 = Color3.new(1, 1, 1)
		lockButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		lockButton.Parent = row
		lockButton.Activated:Connect(function()
			lockRequest:FireServer(index, not item.locked)
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
