-- 수련 창(QUEUE-ALL3 Q2 · 10 문서 2절 - 옛 퀘스트 창의 수련 · 직업 능력 줄을 따로 뗀 창). 단축키 U · 왼쪽 메뉴 수련 칸(PanelRegistry "training").
--   맨 위 = 그림 한 장(icons/hud/training) + 한 줄 설명(40자 이하) · 줄마다 작은 그림 + 이름 + 지금 값 → 다음 값(▲ 초록) + 비용 + [올리기](골드가 되면 강조).
--   값은 QuestUpdate(서버 QuestService 표 - training · abilities)만 그린다 - 판정 · 지급 = 서버(QuestRequest "train" kind id).
--   올릴 수 있는 줄이 처음 생기면: 왼쪽 메뉴 수련 빨간 점(로컬 Attribute TrainingReady) + 말풍선 1회(이번 접속).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)

local TrainingPanel = {}
TrainingPanel.id = "training"

local player = Players.LocalPlayer
local PANEL_SIZE = Vector2.new(600, 440)
local HEADER_H = 84
local ROW_H = 56

local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

-- 줄 그림(작게): 공격 = 교차 검 · 체력 · 방어 = 갑옷 · 그 밖(직업 축) = 수련 아이콘
local ICON_OF = { attack = "icons/codex/tab_class", hp = "icons/codex/tab_equipment", defense = "icons/codex/tab_equipment" }
for _, suffix in ipairs({ "might" }) do
	for _, c in ipairs({ "gs", "db", "bow", "heal" }) do
		ICON_OF[c .. "_" .. suffix] = "icons/codex/tab_class"
	end
end
for _, c in ipairs({ "gs_iron", "db_iron", "bow_iron", "heal_iron", "gs_guard" }) do
	ICON_OF[c] = "icons/codex/tab_equipment"
end

local built, view
local hintShown = false

local function rowsOf(v)
	local list = {}
	for _, t in ipairs(v and v.training or {}) do
		table.insert(list, t)
	end
	for _, t in ipairs(v and v.abilities or {}) do
		table.insert(list, t)
	end
	return list
end

local function affordable(t)
	return t.level < t.cap and (player:GetAttribute("Gold") or 0) >= (t.cost or math.huge)
end

local function build()
	local panel = Panel.create({ id = TrainingPanel.id, kind = "window", title = Text.get("training.title"), size = PANEL_SIZE,
		onOpen = function()
			task.defer(function()
				TrainingPanel.render()
				requestRemote:FireServer("view")
			end)
		end })
	local content = panel.content
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.color("slot")
	header.BackgroundTransparency = 0.2
	header.Position = UDim2.fromOffset(12, 10)
	header.Size = UDim2.new(1, -24, 0, HEADER_H)
	header.Parent = content
	Theme.corner(header, 12)
	local pic = ArtImage.label(header, "icons/hud/training", UDim2.fromOffset(HEADER_H - 12, HEADER_H - 12), "")
	pic.Position = UDim2.fromOffset(6, 6)
	local line = Theme.label(header, Text.get("training.line"), "header", "textPrimary")
	line.Name = "Line"
	line.Position = UDim2.fromOffset(HEADER_H + 4, 0)
	line.Size = UDim2.new(1, -(HEADER_H + 12), 1, 0)
	line.TextWrapped = true

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(12, HEADER_H + 18)
	scroll.Size = UDim2.new(1, -24, 1, -(HEADER_H + 26))
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll
	built = { panel = panel, scroll = scroll }
end

local function row(t, order)
	local f = Instance.new("Frame")
	f.Name = "Train_" .. t.id
	f.LayoutOrder = order
	f.BackgroundColor3 = Theme.color("slot")
	f.BackgroundTransparency = 0.35
	f.Size = UDim2.new(1, -6, 0, ROW_H)
	f.Parent = built.scroll
	Theme.corner(f, 10)
	-- 작은 그림(보상 · 수련 아이콘 - 없으면 이름 첫 글자)
	local icon = ArtImage.label(f, ICON_OF[t.id] or ICON_OF[t.kind] or "icons/hud/training", UDim2.fromOffset(40, 40), utf8.char(utf8.codepoint(t.name or "?", 1)))
	icon.Position = UDim2.fromOffset(8, 8)
	local name = Theme.label(f, t.name, "body", "textPrimary")
	name.Position = UDim2.fromOffset(56, 4)
	name.Size = UDim2.new(0.4, 0, 0, 22)
	local now = t.level * (t.perLevel or 0) * 100
	local nxt = (t.level + 1) * (t.perLevel or 0) * 100
	local atCap = t.level >= t.cap
	local change = Theme.label(f, atCap and Text.get("training.valueCap", { now = ("%.2f"):format(now) })
		or Text.get("training.value", { now = ("%.2f"):format(now), next = ("%.2f"):format(nxt) }), "body", atCap and "textSecondary" or "success")
	change.Name = "Change"
	change.Position = UDim2.fromOffset(56, 28)
	change.Size = UDim2.new(0.5, 0, 0, 22)
	local ok = affordable(t)
	local b = Button.build({ parent = f, kind = ok and "primary" or "secondary", width = 150, height = 44,
		text = atCap and Text.get("quests.trainCap") or Text.get("training.button", { cost = NumberFormat.format(t.cost) }),
		position = UDim2.new(1, -8, 0.5, 0), anchorPoint = Vector2.new(1, 0.5), onActivated = function()
			requestRemote:FireServer("train", t.kind, t.id)
		end })
	b.root.Name = "TrainButton"
	b.setEnabled(not atCap)
end

function TrainingPanel.render()
	if not built or not UIManager.isOpen(TrainingPanel.id) then
		return
	end
	for _, child in ipairs(built.scroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, t in ipairs(rowsOf(view)) do
		row(t, i)
	end
end

-- 올릴 수 있는 줄이 있나 → 빨간 점 · 처음이면 말풍선(토스트 줄 TC · 짧게)
local function refreshReady()
	local ready = false
	for _, t in ipairs(rowsOf(view)) do
		ready = ready or affordable(t)
	end
	player:SetAttribute("TrainingReady", ready)
	if ready and not hintShown and (player:GetAttribute("TutorialCompleted") == true) then
		hintShown = true
		Toast.push("TC", { text = Text.get("training.hint"), colorName = "success" })
	end
end

function TrainingPanel.init()
	build()
	updateRemote.OnClientEvent:Connect(function(v)
		view = v
		refreshReady()
		TrainingPanel.render()
	end)
	player:GetAttributeChangedSignal("Gold"):Connect(function()
		refreshReady()
		TrainingPanel.render()
	end)
end

function TrainingPanel.toggle()
	UIManager.switchTo(TrainingPanel.id)
end

return TrainingPanel
