-- 요청 배너(S18, PRD 20.81 [D-2] MR · [D-3]). 수락 / 거절이 필요한 요청은 전부 이 부품 하나로 온다: 지금은 파티 투표 · 파티 초대, 앞으로는 친구 초대 · 거래도 같은 배너다.
-- 제목 · 본문(3줄) · 남은 시간 Gauge · 수락(primary) / 거절(secondary) Button. **한 번에 하나**만 보이고 나머지는 대기열에서 차례를 기다린다.
-- 남은 시간은 요청이 **도착한 때**부터 센다(서버 제한 시간은 도착 순간부터 흐른다 - 대기 중에 지난 시간만큼 게이지가 줄어 있고, 대기 중에 다 지난 요청은 차례가 와도 조용히 버린다).
-- RequestBanner.push({ key, title, body, seconds, noGauge, accept = { text, onActivated, keepOpen }, decline = { … }, onClose(reason) }) → "shown" | "queued" | "replaced"
--   · key가 같은 요청은 새로 세우지 않고 그 자리(보이는 것 · 대기 중인 것)의 내용을 바꾼다(reason "replaced").
--   · 버튼이 없으면(accept · decline 둘 다 nil) 정보 배너다(파티장 화면의 "투표 중"). keepOpen = true인 버튼은 눌러도 배너가 남고 버튼만 사라진다(투표: 서버 결과를 기다린다).
--   · reason = "accept" | "decline" | "timeout" | "resolved" | "replaced" | "cleared".
-- RequestBanner.resolve(key, { title?, body, seconds }) - 결과 안내로 바꾸고(버튼 · 게이지 없음) seconds 뒤에 닫는다. 그 key가 대기 중이면 버리고, 어디에도 없으면 결과만 띄운다.
-- 자리: ScreenMap MR.requestBanner. 모바일은 아래 끝을 BR 터치 예약 구역 위 끝에 맞춘다(공격 · 스킬 버튼을 안 덮는다). ScreenGui는 window 대역(100 ~ 149)과 메뉴바(150) 위 · overlay(200 ~) 아래(창을 연 채 온 초대도 보이고 눌린다).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Button = require(script.Parent.Parent.ui.kit.Button)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local RequestBanner = {}

RequestBanner.width = 224
RequestBanner.displayOrder = 151
RequestBanner.bodyLines = 3
local PAD, GAP, BUTTON_GAP, GAUGE_HEIGHT = 10, 6, 8, 10
local TICK_SECONDS = 0.1

local gui, frame, titleLabel, bodyLabel, gauge, acceptButton, declineButton
local showing -- { req, expiresAt, total, hasGauge, buttonsShown, resolved }
local queue = {}
local close, showNext -- 아래에서 정의

local function textHeights()
	return Theme.textSize("body") + 4, (Theme.textSize("caption") + 2) * RequestBanner.bodyLines
end

-- 배너 자리. PC는 슬롯 그대로(세로 중앙 + 26 = 가방 버튼 바로 아래). 모바일은 아래 끝이 BR 예약 구역 위 끝(화면 높이 × mobileReserved.BR.top)에서 슬롯의 오프셋(26)만큼 위에 오게 올린다(가방 버튼 위).
local function applyPosition()
	local slotDef = ScreenMap.slot("MR", "requestBanner")
	frame.AnchorPoint = slotDef.anchor
	local offsetY = slotDef.position.Y.Offset
	if Theme.isMobile then
		offsetY = gui.AbsoluteSize.Y * (ScreenMap.mobileReserved.BR.top - slotDef.position.Y.Scale) - frame.Size.Y.Offset * (1 - slotDef.anchor.Y) - slotDef.position.Y.Offset
	end
	frame.Position = UDim2.new(slotDef.position.X.Scale, slotDef.position.X.Offset, slotDef.position.Y.Scale, offsetY)
end

-- 위에서 아래로 쌓는다: 제목 · 본문 · (게이지) · (버튼 줄). 높이는 보이는 것만큼.
local function layout(hasGauge, hasAccept, hasDecline)
	local titleHeight, bodyHeight = textHeights()
	local y = PAD
	titleLabel.Position = UDim2.new(0, PAD, 0, y)
	titleLabel.Size = UDim2.new(1, -PAD * 2, 0, titleHeight)
	y += titleHeight + 2
	bodyLabel.Position = UDim2.new(0, PAD, 0, y)
	bodyLabel.Size = UDim2.new(1, -PAD * 2, 0, bodyHeight)
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
	titleLabel.Text = req.title or ""
	bodyLabel.Text = req.body or ""
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

	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyPosition)
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
			elseif entry.hasGauge then
				gauge.setValue(remaining / entry.total)
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
		visible = frame ~= nil and frame.Visible,
		frame = frame,
	}
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
