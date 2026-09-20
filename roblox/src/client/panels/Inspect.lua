-- 장비 보기 창(S12b B) - window, 읽기 전용. 서버 조회 1개(InspectPlayer RemoteFunction → PlayerInspect)로 그 플레이어의 공개 필드만 받아 그린다:
--   맨 위: @username(caption) + "★n Lv.35 표시이름" + 직업 / 아래: 무기 · 갑옷 · 장갑 · 신발 · 보석 5칸 줄. 줄을 누르면 옵션 툴팁(ItemTooltip - 알림 속 아이템과 같은 부품)이 뜬다(같은 줄 다시 누르면 닫힘).
-- 창 본문은 스크롤(패널이 화면보다 클 수 없다 - COMMON.md §2). 조회는 열 때 한 번 - 서버가 0.5초 간격 · 같은 서버 확인을 한다(거절 사유는 상태 줄에 한 줄).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local UIManager = require(script.Parent.Parent.UIManager)
local ItemTooltip = require(script.Parent.Parent.ui.kit.ItemTooltip)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local Inspect = {}

Inspect.id = "inspect"
local PAD = 14
local ROW_GAP = 6
local HEADER_HEIGHT = 64
local GEM_SLOTS = 5

local inspectRemote = ReplicatedStorage:WaitForChild("InspectPlayer")

local REASON_TEXT = {
	rate_limited = "잠시 뒤 다시 시도하세요",
	not_in_server = "서버를 떠난 플레이어입니다",
	no_class = "아직 직업을 고르지 않은 플레이어입니다",
	bad_request = "조회할 수 없습니다",
}

local built
local requestToken = 0
local shownRow = nil -- 툴팁이 떠 있는 줄 이름

local function rowHeight()
	return Theme.isMobile and Theme.touchMin or 40
end

local function build()
	local panel = Panel.create({
		id = Inspect.id,
		kind = "window",
		title = "장비 보기",
		size = Vector2.new(460, 420),
		onClose = function()
			shownRow = nil
			if built then
				built.tooltip.hide()
			end
		end,
	})
	local content = panel.content

	local usernameLabel = Theme.label(content, "", "caption", "textTertiary")
	usernameLabel.Name = "Username"
	usernameLabel.Position = UDim2.new(0, PAD, 0, 8)
	usernameLabel.Size = UDim2.new(1, -PAD * 2, 0, Theme.textSize("caption") + 4)

	local nameLabel = Theme.label(content, "", "header", "textPrimary")
	nameLabel.Name = "NameLine"
	nameLabel.RichText = true
	nameLabel.Position = UDim2.new(0, PAD, 0, 8 + Theme.textSize("caption") + 6)
	nameLabel.Size = UDim2.new(1, -PAD * 2, 0, Theme.textSize("header") + 6)

	local statusLabel = Theme.label(content, "", "body", "textSecondary")
	statusLabel.Name = "Status"
	statusLabel.Position = UDim2.new(0, PAD, 0, HEADER_HEIGHT + 8)
	statusLabel.Size = UDim2.new(1, -PAD * 2, 0, Theme.textSize("body") + 6)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT)
	scroll.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.colors.rim
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	local rowCount = 4 + GEM_SLOTS
	scroll.CanvasSize = UDim2.new(0, 0, 0, rowCount * (rowHeight() + ROW_GAP) + 12)
	scroll.Visible = false
	scroll.Parent = content

	-- 줄: 이름(caption) + 아이템 글(body, 등급색). 줄 전체가 버튼이다(모바일 44 이상).
	local rows = {} -- 이름 -> { button, partLabel, titleLabel, desc }
	local function makeRow(name, partText, order)
		local button = Instance.new("TextButton")
		button.Name = name
		button.AutoButtonColor = false
		button.Text = ""
		button.Position = UDim2.new(0, PAD, 0, 6 + (order - 1) * (rowHeight() + ROW_GAP))
		button.Size = UDim2.new(1, -PAD * 2, 0, rowHeight())
		button.BackgroundColor3 = Theme.colors.slot
		button.BackgroundTransparency = Theme.colors.slotTransparency
		button.Parent = scroll
		Theme.corner(button, Theme.corner.chip)
		Theme.stroke(button)

		local partLabel = Theme.label(button, partText, "caption", "textSecondary")
		partLabel.Position = UDim2.new(0, 10, 0, 0)
		partLabel.Size = UDim2.new(0, 56, 1, 0)

		local titleLabel = Theme.label(button, "", "body", "textPrimary")
		titleLabel.Position = UDim2.new(0, 70, 0, 0)
		titleLabel.Size = UDim2.new(1, -80, 1, 0)

		rows[name] = { button = button, titleLabel = titleLabel, desc = nil }
		return rows[name]
	end
	makeRow("weapon", "무기", 1)
	makeRow("armor", "갑옷", 2)
	makeRow("gloves", "장갑", 3)
	makeRow("shoes", "신발", 4)
	for slot = 1, GEM_SLOTS do
		makeRow("gem" .. slot, "보석 " .. slot, 4 + slot)
	end

	local tooltip = ItemTooltip.build({ parent = panel.screenGui, name = "InspectTooltip" })
	tooltip.root.ZIndex = 5

	local function selectRow(name)
		local row = rows[name]
		if not row.desc or shownRow == name then
			tooltip.hide()
			shownRow = nil
			return
		end
		tooltip.set(row.desc)
		tooltip.root.Visible = true
		local screenSize = panel.screenGui.AbsoluteSize
		ItemTooltip.placeNear(tooltip.root, { min = row.button.AbsolutePosition, max = row.button.AbsolutePosition + row.button.AbsoluteSize }, screenSize)
		shownRow = name
	end
	for name, row in pairs(rows) do
		row.button.Activated:Connect(function()
			selectRow(name)
		end)
	end

	built = { panel = panel, usernameLabel = usernameLabel, nameLabel = nameLabel, statusLabel = statusLabel, scroll = scroll, rows = rows, tooltip = tooltip, selectRow = selectRow }
end

local function setRow(row, desc, emptyText)
	row.desc = desc
	if desc then
		local visual = ItemVisualData.gradeVisuals[desc.gradeId]
		row.titleLabel.Text = desc.title
		row.titleLabel.TextColor3 = (visual and visual.color) or Theme.colors.textPrimary
	else
		row.titleLabel.Text = emptyText
		row.titleLabel.TextColor3 = Theme.colors.textTertiary
	end
end

local function showData(data)
	local refs = built
	local class = ClassData.classes[data.classId]
	refs.usernameLabel.Text = ("@%s"):format(data.name)
	refs.nameLabel.Text = PlayerLabelFormat.richText(data.displayName, data.level, data.rebirthCount, Theme.textSize("header"))
		.. ('  <font size="%d" color="%s">%s</font>'):format(PlayerLabelFormat.levelSize(Theme.textSize("header")), Theme.colorHex("textSecondary"), class and class.displayName or "")
	refs.statusLabel.Text = ""
	refs.scroll.Visible = true

	setRow(refs.rows.weapon, ItemDescribe.weapon(data.weapon.gradeId, data.weapon.level), "")
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		local item = data.equipment[part]
		setRow(refs.rows[part], item and ItemDescribe.item(item, data.classId) or nil, "없음")
	end
	for slot = 1, GEM_SLOTS do
		local gem = data.weapon.gems[slot]
		setRow(refs.rows["gem" .. slot], gem and ItemDescribe.gem(gem, data.classId) or nil, "비어 있음")
	end
end

-- userId의 장비를 조회해 창을 연다. 조회가 거절되면 창은 열리고 상태 줄에 이유가 나온다.
function Inspect.open(userId)
	if not built then
		build()
	end
	requestToken += 1
	local token = requestToken
	local refs = built
	shownRow = nil
	refs.tooltip.hide()
	refs.scroll.Visible = false
	refs.usernameLabel.Text = ""
	refs.nameLabel.Text = ""
	refs.statusLabel.Text = "불러오는 중…"
	local target = Players:GetPlayerByUserId(userId)
	if target then
		refs.nameLabel.Text = PlayerLabelFormat.richText(target.DisplayName, target:GetAttribute("CharacterLevel"), target:GetAttribute("RebirthCount"), Theme.textSize("header"))
	end
	UIManager.open(Inspect.id)

	task.spawn(function()
		local ok, result = pcall(function()
			return inspectRemote:InvokeServer(userId)
		end)
		if token ~= requestToken then
			return
		end
		if ok and type(result) == "table" and result.ok then
			showData(result.data)
		else
			refs.statusLabel.Text = REASON_TEXT[ok and type(result) == "table" and result.reason or "bad_request"] or "조회할 수 없습니다"
		end
	end)
end

-- 검사용: 줄을 누른 것과 같은 일을 한다(name = weapon · armor · gloves · shoes · gem1 ~ gem5). 지금 툴팁이 열려 있는지(글 포함)도 돌려준다.
function Inspect.debugSelect(name)
	built.selectRow(name)
	return built.tooltip.root.Visible, built.tooltip.title.Text
end

-- 검사용: 지금 창이 그린 줄 글(위에서 아래).
function Inspect.debugRows()
	local texts = {}
	if built then
		for _, name in ipairs({ "weapon", "armor", "gloves", "shoes", "gem1", "gem2", "gem3", "gem4", "gem5" }) do
			table.insert(texts, built.rows[name].titleLabel.Text)
		end
	end
	return texts
end

return Inspect
