-- 요청 배너(S18, PRD 20.81 [D-2] MR · [D-3]). 수락 / 거절이 필요한 요청은 전부 이 부품 하나로 온다: 지금은 파티 투표 · 파티 초대, 앞으로는 친구 초대 · 거래도 같은 배너다.
-- 제목 · 본문(3줄) · 남은 시간 Gauge · 수락(primary) / 거절(secondary) Button. **한 번에 하나**만 보이고 나머지는 대기열에서 차례를 기다린다.
-- 남은 시간은 요청이 **도착한 때**부터 센다(서버 제한 시간은 도착 순간부터 흐른다 - 대기 중에 지난 시간만큼 게이지가 줄어 있고, 대기 중에 다 지난 요청은 차례가 와도 조용히 버린다).
-- RequestBanner.push({ key, title, body, bodyFn(remainingSeconds) -> 글(있으면 body 대신 0.1초마다 다시 쓴다), seconds, noGauge, accept = { text, onActivated, keepOpen }, decline = { … }, onClose(reason) }) → "shown" | "queued" | "replaced"
--   · key가 같은 요청은 새로 세우지 않고 그 자리(보이는 것 · 대기 중인 것)의 내용을 바꾼다(reason "replaced").
--   · 버튼이 없으면(accept · decline 둘 다 nil) 정보 배너다(파티장 화면의 "투표 중"). keepOpen = true인 버튼은 눌러도 배너가 남고 버튼만 사라진다(투표: 서버 결과를 기다린다).
--   · reason = "accept" | "decline" | "timeout" | "resolved" | "replaced" | "cleared".
-- RequestBanner.resolve(key, { title?, body, seconds }) - 결과 안내로 바꾸고(버튼 · 게이지 없음) seconds 뒤에 닫는다. 그 key가 대기 중이면 버리고, 어디에도 없으면 결과만 띄운다.
-- 첫 줄 보호(S20b 사전 작업 2): 제목이 "누가 · 무엇을"이다. title에 {name}을 쓰고 name에 사람 이름을 주면 제목이 한 줄 폭에 안 들어갈 때 **이름 뒤를 …로 줄여** 접미사("님 파티 초대")가 안 잘리게 한다(RequestBanner.fitTitle). 본문은 세부 내용이라 낮은 화면에서 줄임표로 잘려도 되고,
--   잘렸으면 제목 · 본문 영역을 탭하면 필요한 줄만큼 펼쳐진다(다시 탭하면 접힌다 · 화면 안전 영역 안에서만 커진다).
-- 자리: ScreenMap MR.requestBanner. 모바일은 아래 끝을 BR 터치 예약 구역 위 끝에 맞춘다(공격 · 스킬 버튼을 안 덮는다). ScreenGui는 window 대역(100 ~ 149)과 메뉴바(150) 위 · overlay(200 ~) 아래(창을 연 채 온 초대도 보이고 눌린다).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Button = require(script.Parent.Parent.ui.kit.Button)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local RequestBanner = {}

RequestBanner.width = 224
RequestBanner.displayOrder = 151
RequestBanner.bodyLines = 3
local PAD, GAP, BUTTON_GAP, GAUGE_HEIGHT = 10, 6, 8, 10
local SAFE_MARGIN = 8 -- 화면 위 · 아래 끝에서 남기는 여백(UIManager.safeMargin과 같은 값 - 창과 같은 안전 영역). ScreenGui는 IgnoreGuiInset = false라 AbsoluteSize에 이미 상단 인셋(GetGuiInset)이 빠져 있다.
local TICK_SECONDS = 0.1

local TEXT_WIDTH = RequestBanner.width - PAD * 2 -- 제목 · 본문 글 폭

local gui, frame, titleLabel, bodyLabel, gauge, acceptButton, declineButton, expandZone
local showing -- { req, expiresAt, total, hasGauge, buttonsShown, resolved, rows(본문이 필요로 하는 줄 수), expanded }
local queue = {}
local close, showNext -- 아래에서 정의

local function textHeights(lines, mobile)
	return Theme.textSizeFor("body", mobile) + 4, (Theme.textSizeFor("caption", mobile) + 2) * (lines or RequestBanner.bodyLines)
end

-- 제목 첫 줄 보호: template의 {name}을 name으로 바꾸되 한 줄 폭(TEXT_WIDTH)에 안 들어가면 이름 뒤를 하나씩 줄이고 …를 붙인다(접미사는 그대로). 이름이 없으면 template 그대로.
function RequestBanner.fitTitle(template, name, mobile)
	if not name or not template:find("{name}", 1, true) then
		return template
	end
	local size = Theme.textSizeFor("body", mobile)
	local function build(shown)
		return (template:gsub("{name}", function()
			return shown
		end))
	end
	local function width(text)
		return TextService:GetTextSize(text, size, Theme.font, Vector2.new(10000, 10000)).X
	end
	local length = utf8.len(name) or #name
	local shown = name
	while length > 1 and width(build(shown)) > TEXT_WIDTH do
		length -= 1
		shown = name:sub(1, (utf8.offset(name, length + 1) or (#name + 1)) - 1) .. "…"
	end
	return build(shown)
end

-- 본문이 필요로 하는 줄 수(폭 TEXT_WIDTH에서 줄바꿈한 결과). 자리를 줄인 줄 수보다 크면 본문이 잘린 것이다.
function RequestBanner.rowsFor(text, mobile)
	local size = Theme.textSizeFor("caption", mobile)
	local one = TextService:GetTextSize("가", size, Theme.fontBody, Vector2.new(10000, 10000)).Y
	local full = TextService:GetTextSize(text, size, Theme.fontBody, Vector2.new(TEXT_WIDTH, 10000)).Y
	return math.max(1, math.floor(full / one + 0.5))
end

-- 내용 높이(px): 제목 · 본문(lines줄) · (게이지) · (버튼 줄).
local function contentHeight(lines, hasGauge, hasButtons, mobile)
	local titleHeight, bodyHeight = textHeights(lines, mobile)
	local y = PAD + titleHeight + 2 + bodyHeight + GAP
	if hasGauge then
		y += GAUGE_HEIGHT
	end
	if hasButtons then
		y += (hasGauge and BUTTON_GAP or 0) + Theme.buttonHeightFor(mobile)
	end
	return y + PAD
end

-- 배너의 위 끝 y(px, ScreenGui 기준). PC는 슬롯 그대로(세로 중앙 + 26 = 가방 버튼 바로 아래). 모바일은 아래 끝이 BR 터치 예약 구역 위 끝(화면 높이 × mobileReserved.BR.top)에 오는 자리다.
local function desiredTop(height, screenHeight, mobile)
	local slotDef = ScreenMap.slot("MR", "requestBanner")
	if mobile then
		return screenHeight * ScreenMap.mobileReserved.BR.top - height * (1 - slotDef.anchor.Y)
	end
	return slotDef.position.Y.Scale * screenHeight + slotDef.position.Y.Offset
end

-- 화면 안전 영역 안으로 고정(S20 사전 작업 2): 위 끝 >= SAFE_MARGIN · 아래 끝 <= 화면 높이 - SAFE_MARGIN. 낮은 화면(모바일 800 × 360 → ScreenGui 높이 302)에서 본문 3줄이 안 들어가면 본문을 2줄 → 1줄로 줄인다(긴 문장은 ...로 잘린다).
-- 화면 높이는 ScreenGui 높이(상단 인셋 GetGuiInset이 이미 빠진 값)다. 순수 함수 - 자체 점검이 가상 화면(800 × 360 · 667 × 375 ...)으로 그대로 부른다. 반환: 본문 줄 수 · 위 끝 y · 높이.
-- expandLines(있으면): 탭해서 펼친 배너가 원하는 본문 줄 수 - 기본 줄 수보다 늘리되 화면 안전 영역(높이 - 2 × SAFE_MARGIN)에 들어가는 줄 수까지만.
function RequestBanner.placementFor(screenHeight, mobile, hasGauge, hasButtons, expandLines)
	local lines = RequestBanner.bodyLines
	if expandLines and expandLines > lines then
		lines = expandLines
		while lines > RequestBanner.bodyLines and contentHeight(lines, hasGauge, hasButtons, mobile) > screenHeight - 2 * SAFE_MARGIN do
			lines -= 1
		end
	end
	while lines > 1 and mobile and lines <= RequestBanner.bodyLines and desiredTop(contentHeight(lines, hasGauge, hasButtons, mobile), screenHeight, mobile) < SAFE_MARGIN do
		lines -= 1
	end
	local height = contentHeight(lines, hasGauge, hasButtons, mobile)
	local top = desiredTop(height, screenHeight, mobile)
	top = math.min(top, screenHeight - SAFE_MARGIN - height) -- 아래로 넘치면 위로
	top = math.max(top, SAFE_MARGIN) -- 그래도 위로 넘치면(화면이 너무 낮다) 위 여백까지만
	return lines, top, height
end

local function fitPlacement(hasGauge, hasButtons)
	local expandLines = showing and showing.expanded and showing.rows or nil
	local lines, top = RequestBanner.placementFor(gui.AbsoluteSize.Y, Theme.isMobile, hasGauge, hasButtons, expandLines)
	return lines, top
end

-- 배너 자리(위 끝만 바꾼다 - 크기는 layout이 정했다).
local function applyPosition()
	local slotDef = ScreenMap.slot("MR", "requestBanner")
	frame.AnchorPoint = Vector2.new(slotDef.anchor.X, 0)
	local hasGauge = gauge.root.Visible
	local hasButtons = acceptButton.root.Visible or declineButton.root.Visible
	local _, top = fitPlacement(hasGauge, hasButtons)
	frame.Position = UDim2.new(slotDef.position.X.Scale, slotDef.position.X.Offset, 0, top)
end

-- 위에서 아래로 쌓는다: 제목 · 본문 · (게이지) · (버튼 줄). 높이는 보이는 것만큼.
local function layout(hasGauge, hasAccept, hasDecline)
	local lines = fitPlacement(hasGauge, hasAccept or hasDecline)
	local titleHeight, bodyHeight = textHeights(lines)
	local y = PAD
	titleLabel.Position = UDim2.new(0, PAD, 0, y)
	titleLabel.Size = UDim2.new(1, -PAD * 2, 0, titleHeight)
	y += titleHeight + 2
	bodyLabel.Position = UDim2.new(0, PAD, 0, y)
	bodyLabel.Size = UDim2.new(1, -PAD * 2, 0, bodyHeight)
	-- 본문이 잘렸거나(필요한 줄 > 자리) 펼쳐 있으면 제목 · 본문 전체가 탭 영역이다(높이 >= 44 - 모바일 터치 타깃).
	local expandable = showing ~= nil and (showing.expanded or showing.rows > lines)
	expandZone.Visible = expandable
	expandZone.Position = UDim2.new(0, 0, 0, 0)
	expandZone.Size = UDim2.new(1, 0, 0, math.max(y + bodyHeight + GAP, Theme.touchMin))
	y += bodyHeight + GAP
	gauge.root.Visible = hasGauge
	if hasGauge then
		gauge.root.Position = UDim2.new(0, PAD, 0, y)
		y += GAUGE_HEIGHT
	end
	local hasButtons = hasAccept or hasDecline
	acceptButton.root.Visible = hasAccept
	declineButton.root.Visible = hasDecline
	if hasButtons then
		y += (hasGauge and BUTTON_GAP or 0)
		acceptButton.root.Position = UDim2.new(1, -PAD, 0, y)
		declineButton.root.Position = UDim2.new(0, PAD, 0, y)
		y += Theme.buttonHeight
	end
	frame.Size = UDim2.new(0, RequestBanner.width, 0, y + PAD)
	applyPosition()
end

local function show(entry)
	local req = entry.req
	showing = entry
	titleLabel.Text = RequestBanner.fitTitle(req.title or "", req.name, Theme.isMobile)
	bodyLabel.Text = req.bodyFn and req.bodyFn(req.seconds) or req.body or ""
	entry.rows = RequestBanner.rowsFor(bodyLabel.Text, Theme.isMobile)
	entry.expanded = false
	if req.accept then
		acceptButton.setText(req.accept.text)
	end
	if req.decline then
		declineButton.setText(req.decline.text)
	end
	entry.hasGauge = req.seconds ~= nil and not req.noGauge
	entry.buttonsShown = req.accept ~= nil or req.decline ~= nil
	layout(entry.hasGauge, entry.buttonsShown and req.accept ~= nil, entry.buttonsShown and req.decline ~= nil)
	gauge.setValue(1)
	frame.Visible = true
end

close = function(reason)
	local entry = showing
	if not entry then
		return
	end
	showing = nil
	frame.Visible = false
	if entry.req.onClose then
		entry.req.onClose(reason)
	end
	showNext()
end

showNext = function()
	while not showing and #queue > 0 do
		local entry = table.remove(queue, 1)
		if entry.expiresAt and os.clock() >= entry.expiresAt then
			if entry.req.onClose then
				entry.req.onClose("timeout") -- 기다리는 사이 서버 제한 시간이 지났다 - 띄우지 않는다
			end
		else
			show(entry)
		end
	end
end

local function press(which)
	local entry = showing
	if not entry or not entry.buttonsShown then
		return
	end
	local spec = entry.req[which]
	if not spec then
		return
	end
	if spec.onActivated then
		spec.onActivated()
	end
	if spec.keepOpen and showing == entry then
		entry.buttonsShown = false
		layout(entry.hasGauge, false, false) -- 버튼만 사라진다
	else
		close(which)
	end
end

local function ensureBuilt()
	if gui then
		return
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "RequestBannerGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = RequestBanner.displayOrder
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	frame = Instance.new("Frame")
	frame.Name = "RequestBanner"
	frame.Size = UDim2.new(0, RequestBanner.width, 0, 100)
	frame.BackgroundColor3 = Theme.colors.panel
	frame.BackgroundTransparency = Theme.colors.panelTransparency
	frame.Visible = false
	frame.Parent = gui
	Theme.corner(frame, Theme.corner.panel)
	Theme.stroke(frame)

	expandZone = Instance.new("TextButton") -- 라벨보다 먼저 만들어 라벨 뒤에 깐다(글은 입력을 안 막는다)
	expandZone.Name = "ExpandZone"
	expandZone.BackgroundTransparency = 1
	expandZone.Text = ""
	expandZone.AutoButtonColor = false
	expandZone.Visible = false
	expandZone.Parent = frame

	titleLabel = Theme.label(frame, "", "body", "textPrimary")
	titleLabel.Name = "Title"
	titleLabel.Font = Theme.font
	bodyLabel = Theme.label(frame, "", "caption", "textPrimary")
	bodyLabel.Name = "Body"
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	gauge = Gauge.build({ parent = frame, name = "TimeGauge", height = GAUGE_HEIGHT, width = RequestBanner.width - PAD * 2, trackColorName = "slot", fillColorName = "ember", value = 1 })
	local buttonWidth = (RequestBanner.width - PAD * 2 - BUTTON_GAP) / 2
	acceptButton = Button.build({ parent = frame, name = "AcceptButton", kind = "primary", text = "수락", width = buttonWidth, anchorPoint = Vector2.new(1, 0), onActivated = function()
		press("accept")
	end })
	declineButton = Button.build({ parent = frame, name = "DeclineButton", kind = "secondary", text = "거절", width = buttonWidth, onActivated = function()
		press("decline")
	end })

	expandZone.Activated:Connect(function()
		RequestBanner.debugToggleExpand()
	end)

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if showing then
			-- 화면 크기가 바뀌면 안전 영역(본문 줄 수 포함)을 다시 잰다.
			layout(showing.hasGauge, showing.buttonsShown and showing.req.accept ~= nil, showing.buttonsShown and showing.req.decline ~= nil)
		else
			applyPosition()
		end
	end)
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < TICK_SECONDS or not showing then
			return
		end
		accumulated = 0
		local entry = showing
		if entry.expiresAt then
			local remaining = entry.expiresAt - os.clock()
			if remaining <= 0 then
				close(entry.resolved and "resolved" or "timeout")
			else
				if entry.req.bodyFn and not entry.resolved then
					bodyLabel.Text = entry.req.bodyFn(remaining) -- 남은 시간이 글에 들어가는 요청(파티 복귀 - S20 사전 작업 1)
				end
				if entry.hasGauge then
					gauge.setValue(remaining / entry.total)
				end
			end
		end
	end)
end

function RequestBanner.push(req)
	ensureBuilt()
	local entry = { req = req, expiresAt = req.seconds and os.clock() + req.seconds or nil, total = req.seconds }
	if req.key then
		if showing and showing.req.key == req.key then
			local old = showing.req
			show(entry) -- 같은 자리에서 내용만 바꾼다
			if old.onClose then
				old.onClose("replaced")
			end
			return "replaced"
		end
		for index, queued in ipairs(queue) do
			if queued.req.key == req.key then
				queue[index] = entry
				if queued.req.onClose then
					queued.req.onClose("replaced")
				end
				return "queued"
			end
		end
	end
	if showing then
		table.insert(queue, entry)
		return "queued"
	end
	show(entry)
	return "shown"
end

function RequestBanner.resolve(key, opts)
	ensureBuilt()
	if showing and showing.req.key == key then
		if opts.title then
			titleLabel.Text = opts.title
		end
		bodyLabel.Text = opts.body
		showing.rows = RequestBanner.rowsFor(opts.body, Theme.isMobile)
		showing.expanded = false
		showing.buttonsShown = false
		showing.hasGauge = false
		showing.resolved = true
		showing.expiresAt = os.clock() + opts.seconds
		layout(false, false, false)
		return "resolved"
	end
	for index, queued in ipairs(queue) do
		if queued.req.key == key then
			table.remove(queue, index)
			if queued.req.onClose then
				queued.req.onClose("resolved")
			end
			return "dropped"
		end
	end
	RequestBanner.push({ key = key, title = opts.title, body = opts.body, seconds = opts.seconds, noGauge = true })
	return "shown"
end

-- 검사용: 지금 상태({ showing = key, queued = { key, … }, title, body, buttonsShown, gaugeValue, visible, frame }).
function RequestBanner.debugState()
	local keys = {}
	for _, queued in ipairs(queue) do
		table.insert(keys, queued.req.key)
	end
	return {
		showing = showing and showing.req.key or nil,
		queued = keys,
		title = titleLabel and titleLabel.Text or "",
		body = bodyLabel and bodyLabel.Text or "",
		buttonsShown = showing ~= nil and showing.buttonsShown == true,
		gaugeValue = gauge and gauge.getValue() or 0,
		rows = showing and showing.rows or 0,
		expanded = showing ~= nil and showing.expanded == true,
		expandable = expandZone ~= nil and expandZone.Visible,
		visible = frame ~= nil and frame.Visible,
		frame = frame,
	}
end

-- 잘린 본문 펼치기 · 접기(expandZone을 탭한 것과 같은 함수). 펼칠 것이 없으면 아무 일도 없다. 검사용으로도 쓴다.
function RequestBanner.debugToggleExpand()
	local entry = showing
	if not entry or not expandZone.Visible then
		return
	end
	entry.expanded = not entry.expanded
	layout(entry.hasGauge, entry.buttonsShown and entry.req.accept ~= nil, entry.buttonsShown and entry.req.decline ~= nil)
end

-- 검사용: 버튼을 사람 손 대신 누른다("accept" | "decline") - 실제 Button.Activated와 같은 함수를 부른다.
function RequestBanner.debugPress(which)
	press(which)
end

-- 검사용: 보이는 것 · 대기열을 전부 비운다(onClose "cleared").
function RequestBanner.clear()
	local pending = queue
	queue = {}
	for _, queued in ipairs(pending) do
		if queued.req.onClose then
			queued.req.onClose("cleared")
		end
	end
	if showing then
		close("cleared")
	end
end

return RequestBanner
