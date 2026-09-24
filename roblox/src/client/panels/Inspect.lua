-- 장비 보기 창(S12b B → P3b B) - window, 읽기 전용. 메이플 · 로아 · 디아블로4처럼 부위별 칸 목록 → 칸을 누르면 상세가 그 칸 바로 아래에 펼쳐진다(같은 칸을 다시 누르면 접힌다).
--   맨 위: @username(caption) + "★n Lv.35 표시이름" + 직업 · 오른쪽 [내 장비와 비교] 토글.
--   칸: 무기 · 갑옷 · 장갑 · 신발 · 보석 5칸. 상세 = 등급 · 레벨 · 기본 효과 · 옵션 · 굴림 위치(장비 · 보석) / 등급 · 강화 · 무기 배율 · 보석 칸 수(무기).
--   비교를 켜면 상세가 "상대 | 나 | 차이" 세 칸이 되고(차이 = 상대 − 나, 좋으면 success · 나쁘면 danger), 칸 머리 오른쪽에 요약 차이가 붙는다.
--   줄 · 수치는 전부 shared/EquipCompare(게임 함수 그대로 - 화면용 복사 계산 없음)가 만든다.
-- 두 가지로 연다: Inspect.open(userId) = 같은 서버 사람(서버 조회 InspectPlayer - 전부 공개) · Inspect.openCard(card) = 리더보드 카드(무기 · 보석만 공개, 방어구 칸은 "?").
-- 내 장비는 비교를 처음 켤 때 InspectPlayer(내 id)로 한 번 받는다(서버 간격 0.5초에 걸리면 0.6초 뒤 한 번 더).
-- 창 본문은 스크롤(패널이 화면보다 클 수 없다 - COMMON.md §2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local EquipCompare = require(ReplicatedStorage.Shared.EquipCompare)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local UIManager = require(script.Parent.Parent.UIManager)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toggle = require(script.Parent.Parent.ui.kit.Toggle)

local Inspect = {}

Inspect.id = "inspect"
local PAD = 14
local ROW_GAP = 6
local HEADER_HEIGHT = 64
local COMPARE_WIDTH = 176
local DIFF_WIDTH = 76
local LABEL_WIDTH = 78

local inspectRemote = ReplicatedStorage:WaitForChild("InspectPlayer")
local localPlayer = Players.LocalPlayer

local REASON_TEXT = {
	rate_limited = "잠시 뒤 다시 시도하세요",
	not_in_server = "서버를 떠난 플레이어입니다",
	no_class = "아직 직업을 고르지 않은 플레이어입니다",
	bad_request = "조회할 수 없습니다",
}

local PART_TEXT = { weapon = "무기", armor = "갑옷", gloves = "장갑", shoes = "신발" }

local built
local requestToken = 0
-- 지금 보여 주는 것: data = 스냅샷(카드면 equipment 없음) · card = 카드인가 · expanded[slot] = 펼침 · compare · mine = 내 스냅샷(비교용)
local view = { data = nil, card = false, expanded = {}, compare = false, mine = nil }

local function rowHeight()
	return Theme.isMobile and Theme.touchMin or 40
end

local function lineHeight()
	return Theme.textSize("body") + 8
end

local function signColor(sign)
	if sign == 1 then
		return Theme.colors.success
	elseif sign == -1 then
		return Theme.colors.danger
	end
	return Theme.colors.textSecondary
end

-- 상세 줄 목록(EquipCompare) - 비교가 켜져 있고 내 스냅샷이 있으면 "나" 칸이 채워진다.
local function detailLines(slotName)
	local data = view.data
	local item, hidden = EquipCompare.slotItem(data, slotName)
	if hidden then
		return { { label = PART_TEXT[slotName] or "장비", theirs = "리더보드에서는 무기 · 보석만 공개됩니다" } }
	end
	local compare = view.compare and view.mine ~= nil
	local mineItem = compare and EquipCompare.slotItem(view.mine, slotName) or nil
	if slotName == "weapon" and not item then
		return {}
	end
	return EquipCompare.lines(slotName, item, mineItem, data.classId, view.mine and view.mine.classId, compare)
end

local function build()
	Theme.recompute()
	local panel = Panel.create({
		id = Inspect.id,
		kind = "window",
		title = "장비 보기",
		size = Vector2.new(560, 440),
		onClose = function()
			requestToken += 1 -- 늦게 온 응답이 닫힌 창을 다시 그리지 않게
			-- 리더보드에서 열었으면 닫을 때 리더보드로 돌아간다(다른 창을 열어서 닫힌 경우는 제외 - 그 창이 스택에 있다).
			local back = view.returnTo
			view.returnTo = nil
			if back then
				task.delay(0.3, function()
					if #UIManager.getStack() == 0 then
						UIManager.open(back)
					end
				end)
			end
		end,
	})
	local content = panel.content

	local usernameLabel = Theme.label(content, "", "caption", "textTertiary")
	usernameLabel.Name = "Username"
	usernameLabel.Position = UDim2.new(0, PAD, 0, 8)
	usernameLabel.Size = UDim2.new(1, -(PAD * 2 + COMPARE_WIDTH), 0, Theme.textSize("caption") + 4)
	usernameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local nameLabel = Theme.label(content, "", "header", "textPrimary")
	nameLabel.Name = "NameLine"
	nameLabel.RichText = true
	nameLabel.Position = UDim2.new(0, PAD, 0, 8 + Theme.textSize("caption") + 6)
	nameLabel.Size = UDim2.new(1, -(PAD * 2 + COMPARE_WIDTH), 0, Theme.textSize("header") + 6)
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd

	local compareToggle = Toggle.build({
		parent = content,
		name = "CompareToggle",
		text = "내 장비와 비교",
		width = COMPARE_WIDTH - 8,
		position = UDim2.new(1, -(PAD + COMPARE_WIDTH - 8), 0, 10),
		value = false,
		onChanged = function(value)
			Inspect.setCompare(value)
		end,
	})

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
	scroll.Visible = false
	scroll.Parent = content

	-- 칸 머리: 부위(caption) + 아이템 이름(body, 등급색) + 비교 요약(오른쪽). 머리 전체가 버튼(모바일 44 이상).
	local rows = {} -- slotName -> { button, titleLabel, summaryLabel, stroke, detail }
	for order, slotName in ipairs(EquipCompare.slotOrder) do
		local button = Instance.new("TextButton")
		button.Name = slotName
		button.LayoutOrder = order
		button.AutoButtonColor = false
		button.Text = ""
		button.Size = UDim2.new(1, -PAD * 2, 0, rowHeight())
		button.BackgroundColor3 = Theme.colors.slot
		button.BackgroundTransparency = Theme.colors.slotTransparency
		button.Parent = scroll
		Theme.corner(button, Theme.corner.chip)
		local stroke = Theme.stroke(button)

		local gemSlot = slotName:match("^gem(%d)$")
		local partLabel = Theme.label(button, gemSlot and ("보석 " .. gemSlot) or PART_TEXT[slotName], "caption", "textSecondary")
		partLabel.Position = UDim2.new(0, 10, 0, 0)
		partLabel.Size = UDim2.new(0, 56, 1, 0)

		local titleLabel = Theme.label(button, "", "body", "textPrimary")
		titleLabel.Name = "Title"
		titleLabel.Position = UDim2.new(0, 70, 0, 0)
		titleLabel.Size = UDim2.new(1, -(80 + DIFF_WIDTH), 1, 0)
		titleLabel.TextTruncate = Enum.TextTruncate.AtEnd

		local summaryLabel = Theme.label(button, "", "body", "textSecondary")
		summaryLabel.Name = "Summary"
		summaryLabel.AnchorPoint = Vector2.new(1, 0)
		summaryLabel.Position = UDim2.new(1, -10, 0, 0)
		summaryLabel.Size = UDim2.new(0, DIFF_WIDTH, 1, 0)
		summaryLabel.TextXAlignment = Enum.TextXAlignment.Right

		local detail = Instance.new("Frame")
		detail.Name = slotName .. "Detail"
		detail.BackgroundColor3 = Theme.colors.panel
		detail.BackgroundTransparency = 0.35
		detail.Visible = false
		detail.Size = UDim2.new(1, -PAD * 2, 0, 0)
		detail.Parent = scroll
		Theme.corner(detail, Theme.corner.chip)

		rows[slotName] = { button = button, titleLabel = titleLabel, summaryLabel = summaryLabel, stroke = stroke, detail = detail }
		button.Activated:Connect(function()
			Inspect.toggleSlot(slotName)
		end)
	end

	built = { mobile = Theme.isMobile, panel = panel, usernameLabel = usernameLabel, nameLabel = nameLabel, statusLabel = statusLabel, scroll = scroll, rows = rows, compareToggle = compareToggle }
end

-- 상세 틀 한 개를 줄 목록으로 다시 채운다(자식을 지우고 새로 - 고정 줄 높이). 반환 = 높이.
local function fillDetail(frame, lines)
	for _, child in ipairs(frame:GetChildren()) do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	local compare = view.compare and view.mine ~= nil
	local h = lineHeight()
	local y = 4
	local function cell(text, x, width, colorName, alignRight, color)
		local label = Theme.label(frame, text or "", "body", colorName or "textPrimary")
		label.Position = UDim2.new(x.Scale, x.Offset, 0, y)
		label.Size = width
		label.TextTruncate = Enum.TextTruncate.AtEnd
		if alignRight then
			label.TextXAlignment = Enum.TextXAlignment.Right
		end
		if color then
			label.TextColor3 = color
		end
		return label
	end
	local valueX = UDim.new(0, 10 + LABEL_WIDTH)
	-- 비교 칸: 상대(남은 폭의 절반) | 나(절반) | 차이(고정) - 남은 폭 = 전체 - 이름 칸 - 차이 칸 - 여백.
	local rest = -(10 + LABEL_WIDTH + DIFF_WIDTH + 18)
	if compare then
		cell("", UDim.new(0, 10), UDim2.new(0, LABEL_WIDTH, 0, h), "textTertiary")
		cell("상대", valueX, UDim2.new(0.5, rest / 2, 0, h), "textTertiary")
		cell("나", UDim.new(0.5, 10 + LABEL_WIDTH + rest / 2), UDim2.new(0.5, rest / 2, 0, h), "textTertiary")
		cell("차이", UDim.new(1, -(DIFF_WIDTH + 8)), UDim2.new(0, DIFF_WIDTH, 0, h), "textTertiary", true)
		y += h
	end
	for _, entry in ipairs(lines) do
		cell(entry.label, UDim.new(0, 10), UDim2.new(0, LABEL_WIDTH, 0, h), "textSecondary")
		if compare then
			cell(entry.theirs, valueX, UDim2.new(0.5, rest / 2, 0, h))
			cell(entry.mine, UDim.new(0.5, 10 + LABEL_WIDTH + rest / 2), UDim2.new(0.5, rest / 2, 0, h))
			cell(entry.diff or "-", UDim.new(1, -(DIFF_WIDTH + 8)), UDim2.new(0, DIFF_WIDTH, 0, h), nil, true, signColor(entry.sign))
		else
			cell(entry.theirs, valueX, UDim2.new(1, -(10 + LABEL_WIDTH + 10), 0, h))
		end
		y += h
	end
	return y + 4
end

-- 칸 머리(제목 · 등급색 · 요약)와 펼친 상세를 전부 다시 그리고 세로 자리를 다시 잡는다.
local function render()
	local refs = built
	local data = view.data
	local compare = view.compare and view.mine ~= nil
	local y = 6
	for _, slotName in ipairs(EquipCompare.slotOrder) do
		local row = refs.rows[slotName]
		local item, hidden = EquipCompare.slotItem(data, slotName)
		if hidden then
			row.titleLabel.Text = "?"
			row.titleLabel.TextColor3 = Theme.colors.textTertiary
		elseif item then
			local text, gradeId = EquipCompare.title(slotName, item, data.classId)
			local visual = ItemVisualData.gradeVisuals[gradeId]
			row.titleLabel.Text = text
			row.titleLabel.TextColor3 = (visual and visual.color) or Theme.colors.textPrimary
		else
			row.titleLabel.Text = slotName:match("^gem") and "비어 있음" or "없음"
			row.titleLabel.TextColor3 = Theme.colors.textTertiary
		end
		local summaryText, sign
		if compare and not hidden then
			summaryText, sign = EquipCompare.summary(slotName, item, (EquipCompare.slotItem(view.mine, slotName)), data.classId, view.mine.classId)
		end
		row.summaryLabel.Text = summaryText or ""
		row.summaryLabel.TextColor3 = signColor(sign)

		local expanded = view.expanded[slotName] == true
		row.stroke.Color = expanded and Theme.colors.ember or Theme.colors.rim
		row.stroke.Transparency = expanded and 0 or Theme.colors.rimTransparency
		row.button.Position = UDim2.new(0, PAD, 0, y)
		y += rowHeight() + ROW_GAP
		row.detail.Visible = expanded
		if expanded then
			local height = fillDetail(row.detail, detailLines(slotName))
			row.detail.Position = UDim2.new(0, PAD, 0, y - ROW_GAP + 2)
			row.detail.Size = UDim2.new(1, -PAD * 2, 0, height)
			y += height + ROW_GAP
		end
	end
	refs.scroll.CanvasSize = UDim2.new(0, 0, 0, y + 6)
end

local function headerLine(data)
	local class = ClassData.classes[data.classId]
	return PlayerLabelFormat.richText(data.displayName or data.name or "", data.level, data.rebirthCount, Theme.textSize("header"))
		.. ('  <font size="%d" color="%s">%s</font>'):format(PlayerLabelFormat.levelSize(Theme.textSize("header")), Theme.colorHex("textSecondary"), class and class.displayName or "")
end

local function showData(data, card)
	local refs = built
	view.data, view.card = data, card
	refs.usernameLabel.Text = card and ("@%s · 리더보드 - 무기 · 보석만 공개"):format(data.name or "") or ("@%s"):format(data.name)
	refs.nameLabel.Text = headerLine(data)
	refs.statusLabel.Text = ""
	refs.scroll.Visible = true
	render()
end

local function resetView()
	requestToken += 1
	view.data, view.card, view.expanded = nil, false, {}
	local refs = built
	refs.scroll.Visible = false
	refs.scroll.CanvasPosition = Vector2.zero
	refs.usernameLabel.Text = ""
	refs.nameLabel.Text = ""
	return requestToken
end

-- 내 스냅샷(비교용)을 받는다 - 한 창을 여는 동안 한 번. 서버 간격(0.5초)에 걸리면 0.6초 뒤 한 번 더.
local function fetchMine(token)
	task.spawn(function()
		for _ = 1, 2 do
			local ok, result = pcall(function()
				return inspectRemote:InvokeServer(localPlayer.UserId)
			end)
			if token ~= requestToken then
				return
			end
			if ok and type(result) == "table" and result.ok then
				view.mine = result.data
				if view.data then
					render()
				end
				return
			end
			if not (ok and type(result) == "table" and result.reason == "rate_limited") then
				built.statusLabel.Text = "내 장비를 불러오지 못했습니다"
				return
			end
			task.wait(0.6)
		end
	end)
end

function Inspect.setCompare(value)
	view.compare = value == true
	if built.compareToggle.getValue() ~= view.compare then
		built.compareToggle.setValue(view.compare, true)
	end
	if view.compare and not view.mine then
		fetchMine(requestToken)
	end
	if view.data then
		render()
	end
end

-- 칸 하나를 펼치거나 접는다(같은 칸을 다시 누르면 접힌다 - 여러 칸을 같이 펼쳐 둘 수 있다).
function Inspect.toggleSlot(slotName)
	if not view.data then
		return
	end
	view.expanded[slotName] = not view.expanded[slotName] or nil
	render()
end

-- 처음 열 때 짓고, 모바일 판정(Studio ForceTouchLayout 포함)이 바뀌었으면 다시 짓는다(줄 높이가 판정에서 나온다).
local function ensureBuilt()
	Theme.recompute()
	if built and built.mobile ~= Theme.isMobile then
		UIManager.unregister(Inspect.id)
		built.panel.screenGui:Destroy()
		built = nil
	end
	if not built then
		build()
	end
end

-- userId의 장비를 조회해 창을 연다. 조회가 거절되면 창은 열리고 상태 줄에 이유가 나온다.
function Inspect.open(userId)
	ensureBuilt()
	local token = resetView()
	view.mine = nil -- 창을 열 때마다 내 장비도 새로(방금 바꿨을 수 있다)
	local refs = built
	refs.statusLabel.Text = "불러오는 중…"
	local target = Players:GetPlayerByUserId(userId)
	if target then
		refs.nameLabel.Text = PlayerLabelFormat.richText(target.DisplayName, target:GetAttribute("CharacterLevel"), target:GetAttribute("RebirthCount"), Theme.textSize("header"))
	end
	UIManager.open(Inspect.id)
	if view.compare then
		fetchMine(token)
	end

	task.spawn(function()
		local ok, result = pcall(function()
			return inspectRemote:InvokeServer(userId)
		end)
		if token ~= requestToken then
			return
		end
		if ok and type(result) == "table" and result.ok then
			if userId == localPlayer.UserId then
				view.mine = result.data -- 자기 조회면 그대로 비교 기준
			end
			showData(result.data, false)
		else
			refs.statusLabel.Text = REASON_TEXT[ok and type(result) == "table" and result.reason or "bad_request"] or "조회할 수 없습니다"
		end
	end)
end

-- 리더보드 카드(무기 · 보석만 - 방어구 칸은 "?")로 연다. returnTo = 닫을 때 다시 열 창 id(선택). card = Leaderboard 카드({ userId, name, displayName, classId, level, rebirthCount, weapon }).
function Inspect.openCard(card, returnTo)
	ensureBuilt()
	local token = resetView()
	view.returnTo = returnTo -- 닫으면 돌아갈 창 id(리더보드)
	view.mine = nil
	local shown = table.clone(card)
	shown.equipment = nil -- 카드에 방어구가 실려 와도 그리지 않는다(리더보드 화면만 무기 제한 - B3)
	showData(shown, true)
	UIManager.open(Inspect.id)
	if view.compare then
		fetchMine(token)
	end
end

-- 검사용: 칸을 누른 것과 같은 일을 한다(name = weapon · armor · gloves · shoes · gem1 ~ gem5). 지금 그 칸이 펼쳐졌는지와 칸 제목을 돌려준다.
function Inspect.debugSelect(name)
	Inspect.toggleSlot(name)
	return view.expanded[name] == true, built.rows[name].titleLabel.Text
end

-- 검사용: 지금 창이 그린 칸 제목(위에서 아래).
function Inspect.debugRows()
	local texts = {}
	if built then
		for _, name in ipairs(EquipCompare.slotOrder) do
			table.insert(texts, built.rows[name].titleLabel.Text)
		end
	end
	return texts
end

-- 검사용: 펼친 칸의 상세 글(줄마다 칸을 " | "로 이음) · 요약 · 비교 상태 · 내 스냅샷 유무.
function Inspect.debugState()
	local details, summaries = {}, {}
	for _, name in ipairs(EquipCompare.slotOrder) do
		local row = built and built.rows[name]
		if row then
			summaries[name] = row.summaryLabel.Text
			if row.detail.Visible then
				local cells = {}
				for _, child in ipairs(row.detail:GetChildren()) do
					if child:IsA("TextLabel") then
						table.insert(cells, child)
					end
				end
				table.sort(cells, function(a, b)
					if a.Position.Y.Offset ~= b.Position.Y.Offset then
						return a.Position.Y.Offset < b.Position.Y.Offset
					end
					return a.AbsolutePosition.X < b.AbsolutePosition.X
				end)
				local texts = {}
				for _, cell in ipairs(cells) do
					table.insert(texts, cell.Text)
				end
				details[name] = table.concat(texts, " | ")
			end
		end
	end
	return { compare = view.compare, hasMine = view.mine ~= nil, card = view.card, details = details, summaries = summaries, canvas = built and built.scroll.CanvasSize.Y.Offset or 0 }
end

return Inspect
