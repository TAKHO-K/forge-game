-- 선택 아이템 상세 카드 본문(QUEUE-ALL2 P2 ref 17 오른쪽 카드) - 세로 스크롤 하나에 칸을 쌓는다. 버튼 줄 · 이유 줄(DetailHint)은 DetailSheet가 스크롤 밖 아래에 둔다(COMMON §2 - 하단 고정 줄은 스크롤 밖).
--   ① 이름 칸(이름 + 등급 칩) ② 그림 + 글 줄(부위 · Lv · 기본 효과 / 착용 대비 ▲▼ / 판매가 · 품질) ③ 옵션 게이지(치명 = 두 줄) ④ 안내 글(치명 전환 · 초월 특수 · 스킬 변형 · 세트 · 출처 - ItemDescribe)
--   ⑤ 태초 · 초월 세계 번호 카드(PrimordialStamp) ⑥ 보석 홈 줄(무기 · 보석을 골랐을 때 - 누르면 보석 탭) ⑦ 잠금 토글 줄(가방 장비만 - 서버 LockRequest는 DetailSheet가 보낸다).
-- DetailCard.build(parent, S) -> card: { scroll, layout(width, phone), clear(emptyText, hintText), set(spec), onLock(fn), onGems(fn) }
--   spec = { title, gradeId, part, iconKey, lines = { { text, color } }, option = item | nil, notes = string | nil, stamp = item.primordial | nil, gems = bool, locked = bool | nil(잠금 줄 숨김) }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Text = require(ReplicatedStorage.Shared.Text)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local DetailCard = {}

local INK_DARK = Color3.fromRGB(24, 20, 14)

local function label(parent, name, sizeName, colorName)
	local l = Theme.label(parent, "", sizeName, colorName)
	l.Name = name
	l.Font = Enum.Font.GothamBold
	return l
end

local function frame(parent, name, order)
	local f = Instance.new("Frame")
	f.Name = name
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, -8, 0, 0)
	f.Parent = parent
	return f
end

local function corner(inst, px)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, px)
	c.Parent = inst
	return c
end

local function textHeight(text, size, font, width)
	return TextService:GetTextSize(text, size, font, Vector2.new(math.max(width, 10), 2000)).Y
end

-- 밝은 등급색 위에는 어두운 글씨(칩)
local function inkOn(color)
	local luminance = 0.299 * color.R + 0.587 * color.G + 0.114 * color.B
	return luminance > 0.55 and INK_DARK or Color3.new(1, 1, 1)
end

-- 옵션 게이지 한 줄(26-3 PRD 20.67 [12] - 값 글 · 최소 · 트랙(등급색 채움 + 기댓값 눈금) · 최대). 폭이 좁으면 최소 · 최대 숫자를 숨긴다.
local function buildGauge(parent, name, order)
	local row = frame(parent, name, order)
	row.Size = UDim2.new(1, -8, 0, 18)
	row.Visible = false
	local valueText = label(row, "Value", "caption", "textPrimary")
	local minText = label(row, "Min", "caption", "textTertiary")
	minText.Font = Enum.Font.Gotham
	minText.TextXAlignment = Enum.TextXAlignment.Right
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = UIColors.slot
	track.BorderSizePixel = 0
	track.Parent = row
	corner(track, 3)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Parent = track
	corner(fill, 3)
	local tick = Instance.new("Frame") -- 기댓값(롤 범위 중앙 = 1.0) 눈금
	tick.Name = "Tick"
	tick.AnchorPoint = Vector2.new(0.5, 0.5)
	tick.Position = UDim2.new(0.5, 0, 0.5, 0)
	tick.Size = UDim2.new(0, 1, 0, 10)
	tick.BackgroundColor3 = UIColors.rimHi
	tick.BackgroundTransparency = UIColors.rimHiTransparency
	tick.BorderSizePixel = 0
	tick.ZIndex = 2
	tick.Parent = track
	local maxText = label(row, "Max", "caption", "textTertiary")
	maxText.Font = Enum.Font.Gotham
	local gauge = { row = row, valueText = valueText, minText = minText, track = track, fill = fill, maxText = maxText }
	function gauge.layout(width)
		local wide = width >= 300
		local trackW = wide and 110 or 70
		local numW = wide and 30 or 0
		local valueW = width - trackW - numW * 2 - 12
		valueText.Position, valueText.Size = UDim2.new(0, 0, 0, 0), UDim2.new(0, valueW, 1, 0)
		minText.Visible, maxText.Visible = wide, wide
		minText.Position, minText.Size = UDim2.new(0, valueW + 2, 0, 0), UDim2.new(0, numW, 1, 0)
		track.Position, track.Size = UDim2.new(0, valueW + numW + 6, 0.5, -3), UDim2.new(0, trackW, 0, 6)
		maxText.Position, maxText.Size = UDim2.new(0, valueW + numW + trackW + 10, 0, 0), UDim2.new(0, numW, 1, 0)
	end
	-- p(0 ~ 1) = 굴림 위치. 글 색: p ≥ 0.75 초록 · p ≤ 0.25 보조색 · 그 밖 기본색(회색 = 직업 불일치가 우선 · 직업 특화 = 직업색)
	function gauge.apply(text, minValue, maxValue, p, fillColor, dim, accent)
		p = math.clamp(p, 0, 1)
		row.Visible = true
		valueText.Text = text
		valueText.TextColor3 = dim and UIColors.textTertiary or accent or (p >= 0.75 and UIColors.success or (p <= 0.25 and UIColors.textSecondary or UIColors.textPrimary))
		minText.Text = minValue or ""
		maxText.Text = maxValue or ""
		fill.Size = UDim2.new(p, 0, 1, 0)
		fill.BackgroundColor3 = dim and UIColors.textTertiary or fillColor
	end
	return gauge
end

function DetailCard.build(parent, S)
	local player = S.player
	local card = {}
	local width, phone = 300, false
	local lastNotes, lastSpec

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Info"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = parent
	card.scroll = scroll
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = scroll
	list:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.new(0, 0, 0, list.AbsoluteContentSize.Y + 4)
	end)

	-- ① 이름 칸
	local nameBox = frame(scroll, "NameBox", 1)
	nameBox.BackgroundColor3 = UIColors.panel
	nameBox.BackgroundTransparency = 0.2
	corner(nameBox, 8)
	local nameStroke = Instance.new("UIStroke")
	nameStroke.Thickness = 2
	nameStroke.Color = Color3.new(1, 1, 1)
	nameStroke.Parent = nameBox
	local nameLabel = label(nameBox, "Name", "header", "textPrimary")
	nameLabel.AnchorPoint = Vector2.new(0, 0.5)
	nameLabel.Position = UDim2.new(0, 10, 0.5, 0)
	local chip = Instance.new("Frame")
	chip.Name = "GradeChip"
	chip.AnchorPoint = Vector2.new(1, 0.5)
	chip.Position = UDim2.new(1, -8, 0.5, 0)
	chip.BorderSizePixel = 0
	chip.Parent = nameBox
	corner(chip, 12)
	local chipLabel = label(chip, "Grade", "caption", "textPrimary")
	chipLabel.Size = UDim2.new(1, 0, 1, 0)
	chipLabel.TextXAlignment = Enum.TextXAlignment.Center
	chipLabel.TextTruncate = Enum.TextTruncate.None

	-- ② 그림 + 글 줄
	local topRow = frame(scroll, "TopRow", 2)
	local iconBox = Instance.new("Frame")
	iconBox.Name = "IconBox"
	iconBox.BackgroundColor3 = UIColors.slot
	iconBox.BackgroundTransparency = UIColors.slotTransparency
	iconBox.Parent = topRow
	corner(iconBox, 8)
	local iconStroke = Instance.new("UIStroke")
	iconStroke.Thickness = 2
	iconStroke.Parent = iconBox
	local lineLabels = {}
	for i = 1, 5 do -- QUEUE-ALL9C 1-10: 5번째 = "분해 시 · 판매 시" 줄(4줄이면 잘렸다)
		local l = label(topRow, "Line" .. i, i == 1 and "body" or "caption", "textPrimary")
		l.Visible = false
		lineLabels[i] = l
	end

	-- ③ 옵션 게이지
	local gaugeA = buildGauge(scroll, "OptionRow", 3)
	local gaugeB = buildGauge(scroll, "OptionRow2", 4)

	-- ④ 안내 글
	local notes = frame(scroll, "Notes", 5)
	local notesLabel = Theme.label(notes, "", "caption", "textSecondary")
	notesLabel.Size = UDim2.new(1, 0, 1, 0)
	notesLabel.TextWrapped = true
	notesLabel.TextTruncate = Enum.TextTruncate.None
	notesLabel.TextYAlignment = Enum.TextYAlignment.Top

	-- ⑤ 태초 · 초월 세계 번호 카드
	local stampBox = frame(scroll, "StampCard", 6)
	stampBox.BackgroundColor3 = UIColors.panel
	stampBox.BackgroundTransparency = 0.2
	corner(stampBox, 8)
	local stampStroke = Instance.new("UIStroke")
	stampStroke.Thickness = 2
	stampStroke.Parent = stampBox
	local stampLines = {}
	for i = 1, 3 do
		local l = label(stampBox, "StampLine" .. i, i == 1 and "body" or "caption", i == 1 and "textPrimary" or "textSecondary")
		l.Position = UDim2.new(0, 10, 0, 8 + (i - 1) * 20 + (i > 1 and 4 or 0))
		l.Size = UDim2.new(1, -20, 0, 18)
		stampLines[i] = l
	end

	-- ⑥ 보석 홈 줄(누르면 보석 탭)
	local gemRow = Instance.new("TextButton")
	gemRow.Name = "GemRow"
	gemRow.LayoutOrder = 7
	gemRow.AutoButtonColor = false
	gemRow.Text = ""
	gemRow.BackgroundTransparency = 1
	gemRow.Size = UDim2.new(1, -8, 0, 40)
	gemRow.Parent = scroll
	local gemTitle = label(gemRow, "Title", "caption", "textPrimary")
	gemTitle.Text = Text.get("inv.gems.title")
	gemTitle.AnchorPoint = Vector2.new(0, 0.5)
	gemTitle.Position = UDim2.new(0, 2, 0.5, 0)
	gemTitle.Size = UDim2.new(0, 70, 0, 18)
	local sockets = {}
	for slot = 1, Gem.slotCount do
		local socket = Instance.new("Frame")
		socket.Name = "Socket" .. slot
		socket.AnchorPoint = Vector2.new(0, 0.5)
		socket.BorderSizePixel = 0
		socket.Parent = gemRow
		corner(socket, 16)
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1.5
		stroke.Parent = socket
		local plus = label(socket, "Plus", "caption", "textTertiary")
		plus.Text = "+"
		plus.Size = UDim2.new(1, 0, 1, 0)
		plus.TextXAlignment = Enum.TextXAlignment.Center
		local lockHolder = Instance.new("Frame")
		lockHolder.Name = "Lock"
		lockHolder.AnchorPoint = Vector2.new(0.5, 0.5)
		lockHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
		lockHolder.Size = UDim2.new(0, 12, 0, 12)
		lockHolder.BackgroundTransparency = 1
		lockHolder.Parent = socket
		ItemIcons.lock(lockHolder, 12, UIColors.textTertiary)
		sockets[slot] = { frame = socket, stroke = stroke, plus = plus, lock = lockHolder }
	end

	-- ⑦ 잠금 토글 줄(가방 장비만)
	local lockRow = Instance.new("TextButton")
	lockRow.Name = "LockToggle"
	lockRow.LayoutOrder = 8
	lockRow.AutoButtonColor = false
	lockRow.Text = ""
	lockRow.BackgroundColor3 = UIColors.panel
	lockRow.BackgroundTransparency = 0.25
	lockRow.Size = UDim2.new(1, -8, 0, 40)
	lockRow.Parent = scroll
	corner(lockRow, 8)
	local lockIcon = Instance.new("Frame")
	lockIcon.AnchorPoint = Vector2.new(0, 0.5)
	lockIcon.Position = UDim2.new(0, 10, 0.5, 0)
	lockIcon.Size = UDim2.new(0, 16, 0, 16)
	lockIcon.BackgroundTransparency = 1
	lockIcon.Parent = lockRow
	ItemIcons.lock(lockIcon, 16, UIColors.xp)
	local lockText = label(lockRow, "Text", "caption", "textPrimary")
	lockText.Text = Text.get("inv.lock.row")
	lockText.TextColor3 = UIColors.xp
	lockText.AnchorPoint = Vector2.new(0, 0.5)
	lockText.Position = UDim2.new(0, 34, 0.5, 0)
	lockText.Size = UDim2.new(1, -(34 + 64), 0, 18)
	local switch = Instance.new("Frame")
	switch.Name = "Switch"
	switch.AnchorPoint = Vector2.new(1, 0.5)
	switch.Position = UDim2.new(1, -10, 0.5, 0)
	switch.Size = UDim2.new(0, 46, 0, 24)
	switch.BorderSizePixel = 0
	switch.Parent = lockRow
	corner(switch, 12)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.new(0, 18, 0, 18)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = switch
	corner(knob, 9)

	-- 빈 상태 안내(선택 없음)
	local emptyHint = frame(scroll, "EmptyHint", 9)
	local emptyLabel = Theme.label(emptyHint, "", "caption", "textSecondary")
	emptyLabel.Size = UDim2.new(1, 0, 1, 0)
	emptyLabel.TextWrapped = true
	emptyLabel.TextTruncate = Enum.TextTruncate.None
	emptyLabel.TextYAlignment = Enum.TextYAlignment.Top

	local lockCallback, gemCallback
	lockRow.Activated:Connect(function()
		if lockCallback then
			lockCallback()
		end
	end)
	gemRow.Activated:Connect(function()
		if gemCallback then
			gemCallback()
		end
	end)
	function card.onLock(fn)
		lockCallback = fn
	end
	function card.onGems(fn)
		gemCallback = fn
	end

	local function setIcon(part, key, color)
		for _, child in ipairs(iconBox:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local size = phone and 30 or 44
		local holder = Instance.new("Frame")
		holder.AnchorPoint = Vector2.new(0.5, 0.5)
		holder.Position = UDim2.new(0.5, 0, 0.5, 0)
		holder.Size = UDim2.new(0, size, 0, size)
		holder.BackgroundTransparency = 1
		holder.Parent = iconBox
		if not ItemIcons.image(holder, size, key, 0.8) then
			local builder = ItemIcons.byPart[part] or ItemIcons.byPart.armor
			builder(holder, size, color)
		end
	end

	local function paintGems()
		local state = S.gemState and S.gemState()
		for slot, socket in ipairs(sockets) do
			local gem = state and Gem.isFilled(state.gems, slot) and state.gems[slot] or nil
			local unlocked = state and state.slotUnlocked and state.slotUnlocked[slot]
			local visual = gem and ItemVisualData.gradeVisuals[gem.grade]
			socket.frame.BackgroundColor3 = visual and visual.color or UIColors.slot
			socket.frame.BackgroundTransparency = gem and 0 or 0.2
			socket.stroke.Color = gem and Color3.new(1, 1, 1) or UIColors.rim
			socket.stroke.Transparency = gem and 0.3 or 0.5
			socket.plus.Visible = not gem and unlocked == true
			socket.lock.Visible = not gem and unlocked ~= true
		end
	end

	local function paintLock(locked)
		switch.BackgroundColor3 = locked and UIColors.success or UIColors.slot
		knob.Position = locked and UDim2.new(1, -21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		lockText.TextColor3 = locked and UIColors.xp or UIColors.textSecondary
	end

	-- 폭 · 폰 여부가 바뀌면(배치) 칸 크기를 다시 정한다. 마지막 내용을 다시 그린다(안내 글 높이가 폭에 따른다).
	function card.layout(newWidth, isPhone)
		width, phone = newWidth, isPhone
		local inner = width - 8
		nameBox.Size = UDim2.new(1, -8, 0, phone and 32 or 44)
		nameLabel.TextSize = Theme.textSize(phone and "body" or "header")
		gaugeA.layout(inner)
		gaugeB.layout(inner)
		local socketSize = phone and 30 or 26
		for slot, socket in ipairs(sockets) do
			socket.frame.Size = UDim2.new(0, socketSize, 0, socketSize)
			socket.frame.Position = UDim2.new(0, 76 + (slot - 1) * (socketSize + 8), 0.5, 0)
		end
		gemRow.Size = UDim2.new(1, -8, 0, phone and 44 or 40)
		lockRow.Size = UDim2.new(1, -8, 0, phone and 44 or 40)
		if lastSpec then
			card.set(lastSpec)
		elseif lastNotes then
			card.clear(lastNotes[1], lastNotes[2])
		end
	end

	-- 선택 없음(또는 무기 · 보석처럼 일부만 쓰는 경우의 바탕)
	function card.clear(emptyText, hintText)
		lastSpec, lastNotes = nil, { emptyText, hintText }
		nameLabel.Text = emptyText or ""
		nameLabel.TextColor3 = UIColors.textTertiary
		nameLabel.Size = UDim2.new(1, -20, 1, 0)
		nameStroke.Color = UIColors.rim
		nameStroke.Transparency = 0.5
		chip.Visible = false
		topRow.Visible = false
		gaugeA.row.Visible, gaugeB.row.Visible = false, false
		notes.Visible = false
		stampBox.Visible = false
		gemRow.Visible = false
		lockRow.Visible = false
		emptyHint.Visible = hintText ~= nil
		if hintText then
			emptyLabel.Text = hintText
			emptyHint.Size = UDim2.new(1, -8, 0, textHeight(hintText, emptyLabel.TextSize, emptyLabel.Font, width - 8) + 4)
		end
	end

	function card.set(spec)
		lastSpec = spec
		emptyHint.Visible = false
		local visual = ItemVisualData.gradeVisuals[spec.gradeId]
		local color = visual and visual.color or UIColors.textPrimary
		-- ① 이름 + 등급 칩
		nameLabel.Text = spec.title
		nameLabel.TextColor3 = UIColors.textPrimary
		nameStroke.Color = color
		nameStroke.Transparency = 0
		local grade = spec.gradeId and ArmorData.grades[spec.gradeId]
		chip.Visible = grade ~= nil
		local chipW = 0
		if grade then
			chipLabel.Text = Text.name(grade.displayName)
			chipW = TextService:GetTextSize(chipLabel.Text, chipLabel.TextSize, chipLabel.Font, Vector2.new(400, 40)).X + 22
			chip.Size = UDim2.new(0, chipW, 0, phone and 22 or 26)
			chip.BackgroundColor3 = color
			chipLabel.TextColor3 = inkOn(color)
		end
		nameLabel.Size = UDim2.new(1, -(20 + chipW + 6), 1, 0)
		-- ② 그림 + 글 줄
		topRow.Visible = true
		local iconSize = phone and 44 or 72
		iconBox.Size = UDim2.new(0, iconSize, 0, iconSize)
		iconStroke.Color = color
		setIcon(spec.part, spec.iconKey, color)
		local lineX = iconSize + 10
		local y = 0
		for i, l in ipairs(lineLabels) do
			local line = spec.lines[i]
			l.Visible = line ~= nil
			if line then
				l.Text = line.text
				l.TextColor3 = line.color or UIColors.textPrimary
				local h = l.TextSize + 5
				l.Position = UDim2.new(0, lineX, 0, y)
				l.Size = UDim2.new(1, -lineX, 0, h)
				y += h
			end
		end
		topRow.Size = UDim2.new(1, -8, 0, math.max(iconSize, y))
		-- ③ 옵션 게이지
		gaugeA.row.Visible, gaugeB.row.Visible = false, false
		local item = spec.option
		if item and item.option then
			local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
			local Option = require(ReplicatedStorage.Shared.Option)
			local def = OptionData.options[item.option.id]
			if def then
				local classId = player:GetAttribute("ClassId")
				local lines = ItemDescribe.optionLines(item, classId)
				local span = OptionData.rollMax - OptionData.rollMin
				if item.option.id == "crit" then
					gaugeA.apply(lines[1].text, nil, nil, (item.option.roll - OptionData.rollMin) / span, color, lines[1].dim)
					gaugeB.apply(lines[2].text, nil, nil, ((item.option.roll2 or item.option.roll) - OptionData.rollMin) / span, color, lines[2].dim)
				else
					local range = Option.rangeOf(item.option.id, item.grade, item.itemLevel, classId)
					local accent = lines[1].accentClassId and UIColors.classAccent[lines[1].accentClassId] or nil
					gaugeA.apply(lines[1].text, ("%.1f"):format(range.min * 100), ("%.1f"):format(range.max * 100), (item.option.roll - OptionData.rollMin) / span, color, lines[1].dim, accent)
				end
			end
		end
		-- ④ 안내 글
		notes.Visible = spec.notes ~= nil and spec.notes ~= ""
		if notes.Visible then
			notesLabel.Text = spec.notes
			notes.Size = UDim2.new(1, -8, 0, textHeight(spec.notes, notesLabel.TextSize, notesLabel.Font, width - 8) + 4)
		end
		-- ⑤ 세계 번호 카드
		local head = spec.stamp and PrimordialStamp.numberText(spec.stamp)
		stampBox.Visible = head ~= nil
		if head then
			stampStroke.Color = color
			stampLines[1].Text = Text.get("inv.stamp.head", { head = head })
			stampLines[1].TextColor3 = color
			local owner = not spec.stamp.legacy and spec.stamp.ownerName or nil
			local date = PrimordialStamp.dateText(spec.stamp.at)
			stampLines[2].Text = owner and (date and Text.get("inv.stamp.owner", { name = owner, date = date }) or Text.get("inv.stamp.ownerNoDate", { name = owner })) or ""
			local source = PrimordialStamp.sourceText(spec.stamp.source)
			stampLines[3].Text = source and Text.get("inv.stamp.source", { source = source }) or ""
			local count = 1 + (stampLines[2].Text ~= "" and 1 or 0) + (stampLines[3].Text ~= "" and 1 or 0)
			stampBox.Size = UDim2.new(1, -8, 0, 16 + count * 20 + 4)
		end
		-- ⑥ 보석 홈 · ⑦ 잠금
		gemRow.Visible = spec.gems == true
		if gemRow.Visible then
			paintGems()
		end
		lockRow.Visible = spec.locked ~= nil
		if lockRow.Visible then
			paintLock(spec.locked)
		end
	end

	return card
end

return DetailCard
