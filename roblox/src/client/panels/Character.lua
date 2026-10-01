-- 캐릭터 창(QUEUE-ALL2 P2 - 09 문서 B-3 "C = 캐릭터(성장 · 능력치 · 직업 변경)"). 단축키 C · 왼쪽 메뉴 상시 칸(PanelRegistry "character").
--   왼쪽 = 직업 그림(icons/codex/class_<직업>) + 직업 이름 · 오른쪽 = 능력치 줄(서버 Player Attribute 그대로 - 클라는 계산하지 않는다) · 아래 = [직업 변경](옛 왼쪽 아래 "직업 변경" 버튼 자리 - 중복 삭제) · [수련 U] 바로 가기.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
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
	built = { panel = panel, left = left, className = className, values = values }
end

function CharacterPanel.render()
	if not built then
		return
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
end

return CharacterPanel
