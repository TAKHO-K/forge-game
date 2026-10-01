-- 캐릭터 창(QUEUE-ALL2 P2 - 09 문서 B-3 "C = 캐릭터(성장 · 능력치 · 직업 변경)"). 단축키 C · 왼쪽 메뉴 상시 칸(PanelRegistry "character").
--   왼쪽 = 직업 그림(icons/codex/class_<직업>) + 직업 이름 · 오른쪽 = 능력치 줄(서버 Player Attribute 그대로 - 클라는 계산하지 않는다) · 아래 = [직업 변경](옛 왼쪽 아래 "직업 변경" 버튼 자리 - 중복 삭제) · [수련 U] 바로 가기.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)

local CharacterPanel = {}
CharacterPanel.id = "character"

local player = Players.LocalPlayer
local PANEL_SIZE = Vector2.new(560, 380)
local ROW_H = 30
-- 능력치 줄: { 글자 키, Attribute, 형식 }
local ROWS = {
	{ "character.level", "CharacterLevel", "int" },
	{ "character.power", "CombatPower", "big" },
	{ "character.maxHp", "MaxHp", "big" },
	{ "character.weapon", "WeaponLevel", "plus" },
	{ "character.rebirth", "RebirthCount", "int" },
	{ "character.best", "InfiniteStageBest", "int" },
	{ "character.speed", "SpeedPercentBonus", "pct" },
	{ "character.milestone", "MilestoneMultiplier", "mult" },
}

local built
local cosView = nil -- QUEUE-ALL6 H 꾸미기 보기: ShopSync 표(MonetizationService.view - 산 것 · 장착) 그대로
local showCos = false

-- 칸 → 고를 수 있는 목록(테마 세트 · 글라이더 · 소품) · 산 것만
local function optionsFor(slotId)
	if slotId == "gliderSkin" then
		return CosmeticSlotData.gliderSkins, "gliderSkins"
	elseif table.find(CosmeticSlotData.itemSlots, slotId) then
		return CosmeticSlotData.items, "items"
	end
	return CosmeticSlotData.sets, "themes"
end

local function format(kind, v)
	v = v or 0
	if kind == "big" then
		return NumberFormat.format(v)
	elseif kind == "plus" then
		return "+" .. tostring(math.floor(v))
	elseif kind == "pct" then
		return ("%+.1f%%"):format(v) -- SpeedPercentBonus = 이미 % 단위
	elseif kind == "mult" then
		return ("×%.2f"):format(v == 0 and 1 or v)
	end
	return tostring(math.floor(v))
end

local function build()
	local panel = Panel.create({ id = CharacterPanel.id, kind = "window", title = Text.get("character.title"), size = PANEL_SIZE,
		onOpen = function()
			task.defer(CharacterPanel.render)
		end })
	local content = panel.content
	local left = Instance.new("Frame")
	left.Name = "Portrait"
	left.BackgroundColor3 = Theme.color("slot")
	left.BackgroundTransparency = 0.2
	left.Position = UDim2.fromOffset(12, 12)
	left.Size = UDim2.new(0, 190, 1, -84)
	left.Parent = content
	Theme.corner(left, 12)
	local className = Theme.label(left, "", "header", "textPrimary")
	className.Name = "ClassName"
	className.AnchorPoint = Vector2.new(0.5, 1)
	className.Position = UDim2.new(0.5, 0, 1, -8)
	className.Size = UDim2.new(1, -12, 0, 22)
	className.TextXAlignment = Enum.TextXAlignment.Center

	local list = Instance.new("Frame")
	list.Name = "Stats"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(214, 12)
	list.Size = UDim2.new(1, -226, 1, -84)
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	local values = {}
	for i, row in ipairs(ROWS) do
		local f = Instance.new("Frame")
		f.Name = "Row_" .. row[2]
		f.LayoutOrder = i
		f.BackgroundTransparency = 1
		f.Size = UDim2.new(1, 0, 0, ROW_H)
		f.Parent = list
		local name = Theme.label(f, Text.get(row[1]), "body", "textSecondary")
		name.Size = UDim2.new(0.55, 0, 1, 0)
		local value = Theme.label(f, "", "header", "textPrimary")
		value.Name = "Value"
		value.Position = UDim2.new(0.55, 0, 0, 0)
		value.Size = UDim2.new(0.45, 0, 1, 0)
		value.TextXAlignment = Enum.TextXAlignment.Right
		values[row[2]] = { label = value, kind = row[3] }
	end

	local change = Button.build({ parent = content, kind = "secondary", text = Text.get("character.changeClass"), width = 150,
		position = UDim2.new(0, 12, 1, -12), anchorPoint = Vector2.new(0, 1), onActivated = function()
			UIManager.close(CharacterPanel.id)
			local classUi = player.PlayerScripts:FindFirstChild("ClassSelectUI", true)
			local signal = classUi and classUi:FindFirstChild("OpenClassSelect")
			if signal then
				signal:Fire()
			end
		end })
	change.root.Name = "ChangeClassButton"
	local train = Button.build({ parent = content, kind = "primary", text = Text.get("character.toTraining"), width = 150,
		position = UDim2.new(1, -12, 1, -12), anchorPoint = Vector2.new(1, 1), onActivated = function()
			UIManager.openLazy("training")
		end })
	train.root.Name = "TrainingButton"

	-- QUEUE-ALL6 H 꾸미기 보기(능력치 자리를 바꿔 끼움): 칸마다 [기본] + 산 것 칩 · 하이파이브 단추
	local cos = Instance.new("ScrollingFrame")
	cos.Name = "Cosmetics"
	cos.BackgroundTransparency = 1
	cos.BorderSizePixel = 0
	cos.Position = list.Position
	cos.Size = list.Size
	cos.ScrollBarThickness = 6
	cos.AutomaticCanvasSize = Enum.AutomaticSize.Y
	cos.CanvasSize = UDim2.new()
	cos.Visible = false
	cos.Parent = content
	local cosLayout = Instance.new("UIListLayout")
	cosLayout.SortOrder = Enum.SortOrder.LayoutOrder
	cosLayout.Padding = UDim.new(0, 4)
	cosLayout.Parent = cos
	local toggle = Button.build({ parent = content, kind = "secondary", text = Text.get("character.cosmetics"), width = 120,
		position = UDim2.new(0.5, 0, 1, -12), anchorPoint = Vector2.new(0.5, 1), onActivated = function()
			showCos = not showCos
			CharacterPanel.render()
			if showCos then
				ReplicatedStorage:WaitForChild("ShopRequest"):FireServer("view")
			end
		end })
	toggle.root.Name = "CosmeticsToggle"
	built = { panel = panel, left = left, className = className, values = values, list = list, cos = cos, toggle = toggle }
end

local function renderCos()
	local cos = built.cos
	for _, child in ipairs(cos:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	if not cosView then
		Theme.label(cos, Text.get("shop.loading"), "body", "textSecondary").Size = UDim2.new(1, 0, 0, 24)
		return
	end
	local equipped = cosView.equipped or {}
	local order = 0
	local function add(inst)
		order += 1
		inst.LayoutOrder = order
		inst.Parent = cos
	end
	if equipped.emote == "highFive" then
		local use = Button.build({ parent = cos, kind = "primary", text = Text.get("cos.emote.use"), width = 140, onActivated = function()
			local fx = player.PlayerScripts:FindFirstChild("CosmeticFx", true)
			local use = fx and fx:FindFirstChild("CosmeticEmoteUse")
			if use then
				use:Fire()
			end
		end })
		use.root.Name = "EmoteUse"
		add(use.root)
	end
	for _, slot in ipairs(CosmeticSlotData.slots) do
		local list, ownedKey = optionsFor(slot.id)
		local row = Instance.new("Frame")
		row.Name = "CosSlot_" .. slot.id
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		local rowLayout = Instance.new("UIListLayout")
		rowLayout.FillDirection = Enum.FillDirection.Horizontal
		rowLayout.Wraps = true
		rowLayout.Padding = UDim.new(0, 4)
		rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowLayout.Parent = row
		local title = Theme.label(row, Text.get("shop.slot." .. slot.id), "body", "textSecondary")
		title.Size = UDim2.new(1, 0, 0, 20)
		title.LayoutOrder = 0
		local function chip(id, text, n)
			local selected = equipped[slot.id] == id
			local b = Button.build({ parent = row, kind = selected and "primary" or "secondary", text = text, width = 104, height = 28, layoutOrder = n, onActivated = function()
				if not selected then
					ReplicatedStorage:WaitForChild("ShopRequest"):FireServer("equip", slot.id, id)
				end
			end })
			b.root.Name = "Chip_" .. tostring(id)
		end
		chip(nil, Text.get("shop.cos.default"), 1)
		local owned = cosView[ownedKey] or {}
		for i, entry in ipairs(list) do
			if owned[entry.id] and (ownedKey ~= "items" or entry.slot == slot.id) then
				chip(entry.id, Text.name(entry.name), i + 1)
			end
		end
		add(row)
	end
end

function CharacterPanel.render()
	if not built then
		return
	end
	built.list.Visible = not showCos
	built.cos.Visible = showCos
	built.toggle.setText(Text.get(showCos and "character.stats" or "character.cosmetics"))
	if showCos then
		renderCos()
	end
	local classId = player:GetAttribute("ClassId")
	local class = classId and ClassData.classes[classId]
	built.className.Text = class and Text.get("class.name." .. classId) or "-"
	local art = built.left:FindFirstChild("Art")
	local path = classId and ("icons/codex/class_" .. classId) or ""
	if not art or art:GetAttribute("Path") ~= path then
		if art then
			art:Destroy()
		end
		art = ArtImage.label(built.left, path, UDim2.new(1, -16, 1, -44), class and Text.get("class.name." .. classId) or "")
		art.Position = UDim2.fromOffset(8, 8)
		art:SetAttribute("Path", path)
	end
	for attr, entry in pairs(built.values) do
		entry.label.Text = format(entry.kind, player:GetAttribute(attr))
	end
end

function CharacterPanel.init()
	build()
	for _, row in ipairs(ROWS) do
		player:GetAttributeChangedSignal(row[2]):Connect(function()
			if UIManager.isOpen(CharacterPanel.id) then
				CharacterPanel.render()
			end
		end)
	end
	player:GetAttributeChangedSignal("ClassId"):Connect(CharacterPanel.render)
	task.spawn(function() -- QUEUE-ALL6 H 꾸미기 보기 표
		ReplicatedStorage:WaitForChild("ShopSync").OnClientEvent:Connect(function(view)
			cosView = view
			if showCos and UIManager.isOpen(CharacterPanel.id) then
				CharacterPanel.render()
			end
		end)
	end)
end

return CharacterPanel
