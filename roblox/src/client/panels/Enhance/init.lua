-- 강화 패널 조립(28-1 S07, PRD 20.72 [1-8] · 20.81 [D]). GUI 공통 틀(S06) 위에 처음으로 올라가는 화면 - `Panel`(kind = "station")로 만들고 `UIManager`가 열림 규칙을 준다.
-- 320 × 340 고정 · 하단 중앙 앵커(지금 자리). 강화대 근처에 들어가면 열리고 벗어나면 닫힌다(근접 열림 - 지금 동작). X로 닫으면 벗어났다 돌아올 때까지 다시 열지 않는다.
-- 탭 "강화 | 환생": 강화 탭 = 위쪽 본문은 스크롤(비용 2줄 · 확률표 5행 · 불씨 · 방지권 2줄 · 한 줄 안내 - CanvasSize는 행 수로 계산) + 아래 고정(강화 버튼 · 결과 줄) /
-- 환생 탭 = 옛 EnhanceUI의 환생 탭 그대로(RebirthView). 스크롤이 있다는 것은 스크롤바 + 아래쪽 흐림(더 볼 내용이 있을 때만)으로 보인다.
-- 처음 가까이 갈 때 짓는다(Theme.recompute 뒤의 모바일 판정을 따르기 위해 - 판정이 바뀌면 다시 짓는다).
-- 이 패널은 서버 상태의 진실을 갖지 않는다 - Attribute · Remote 응답을 그리기만 한다(Controller).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local UIManager = require(script.Parent.Parent.UIManager)
local Controller = require(script.Controller)
local CostView = require(script.CostView)
local OddsView = require(script.OddsView)
local RebirthView = require(script.RebirthView)
local TicketView = require(script.TicketView)

local EnhancePanel = {}

EnhancePanel.id = "enhance"
local PANEL_SIZE = Vector2.new(320, 340)
local BOTTOM_OFFSET = 120 -- 화면 아래에서 띄우는 간격(옛 패널 자리 그대로 - 스킬 · 체력바 위)
local TOP_MARGIN = 8
local PAD = 8
local BUTTON_WIDTH = 200
local FADE_HEIGHT = 18 -- 스크롤 영역 아래쪽 흐림(더 볼 내용이 있다는 표시)
local BUY_FAIL_REASONS = {
	insufficient_gold = "골드가 부족합니다",
	not_near_station = "강화대에서 너무 멀리 떨어졌습니다",
	invalid_kind = "알 수 없는 방지권입니다",
}
local TAB_LABELS = { { id = "enhance", text = "강화" }, { id = "rebirth", text = "환생" } }

local player = Players.LocalPlayer
local built -- 지은 패널의 refs 표 하나(아래 build) - 없으면 아직 안 지었다
local dismissed = false -- X · Backspace로 닫았다: 강화대에서 벗어났다 돌아올 때까지 다시 열지 않는다
local suppressDismiss = false -- 다시 짓는 동안의 닫힘은 사용자가 닫은 것이 아니다

-- 도움말 문구(PRD 20.72 [1-8]) - 숫자는 확률표 · EnhanceConfig에서 끼운다.
local function helpText()
	local dropFrom, resetFrom = Enhance.getRiskStartLevels()
	return ("0~%d강은 실패해도 단계가 내려가지 않습니다. %d강부터 하락, %d강부터 초기화(%d강)가 있습니다. 실패할 때마다 불씨가 차고, 가득 차면 다음 시도는 반드시 성공합니다."):format(
		dropFrom - 1, dropFrom, resetFrom, EnhanceConfig.resetToLevel)
end

-- 결과 줄의 문구와 색(UIColors 이름). payload = EnhanceResult가 실어 온 표(EnhanceService.handleRequest).
local function resultLine(data)
	local level = data.level or (player:GetAttribute("WeaponLevel") or 0)
	local result = data.result
	local suffix = ""
	if data.gaugeGain and data.gaugeGain > 0 then
		suffix = (" · 불씨 +%s"):format(OddsView.formatPercent(data.gaugeGain / (data.gaugeMax or EnhanceConfig.gauge.max)))
	end
	if data.blockedBy then
		local left = data.ticketsLeft and data.ticketsLeft[data.blockedBy] or 0
		return ("%s이 막았습니다(남은 %d장)"):format(EnhanceConfig.protection[data.blockedBy].displayName, left), "textPrimary"
	elseif result == "success" then
		return ("성공! +%d"):format(level), "success"
	elseif result == "maintain" then
		return ("실패 - 유지 (+%d)%s"):format(level, suffix), "textPrimary"
	elseif result == "down1" or result == "down2" then
		return ("실패 - %d강 하락 (+%d)%s"):format(result == "down1" and 1 or 2, level, suffix), "ember"
	elseif result == "reset" then
		return ("%d강에서 다시 시작합니다. 불씨는 유지됩니다"):format(EnhanceConfig.resetToLevel), "danger"
	elseif result == "max" then
		return "이미 최대 강화 단계입니다", "textPrimary"
	elseif result == "insufficient_gold" then
		return "골드가 부족합니다", "danger"
	elseif result == "insufficient_material" then
		local state = Controller.getState()
		local name = state.material and state.material.name or tostring(data.materialId)
		return ("%s이 부족합니다 (%d개 필요 · 보유 %d개)"):format(name, data.need, data.have), "danger"
	end
	return tostring(result), "textPrimary"
end

-- 방지권 구매 결과(ProtectionTicketBuyResult payload)의 문구와 색.
local function buyResultLine(data)
	if data.ok then
		return ("%s을 샀습니다 (보유 %d장)"):format(EnhanceConfig.protection[data.kind].displayName, data.tickets[data.kind]), "success"
	end
	return BUY_FAIL_REASONS[data.reason] or tostring(data.reason), "danger"
end

local function refresh()
	if not built then
		return
	end
	local state = Controller.getState()
	if built.tab == "enhance" then
		-- P2.5a R4: 최대 단계를 제목에 항상 적는다("최대 +30" - EnhanceConfig.maxLevel).
		built.panel.titleLabel.Text = state.maxed and ("%s 등급 · +%d (최대)"):format(state.gradeName, state.level)
			or ("%s 등급 · +%d → +%d · 최대 +%d"):format(state.gradeName, state.level, state.level + 1, EnhanceConfig.maxLevel)
	else
		built.panel.titleLabel.Text = "환생"
	end
	CostView.update(built.cost, state)
	OddsView.updateTable(built.odds, state.level, state.outcomes)
	OddsView.updateGaugeRow(built.gauge, state)
	TicketView.update(built.tickets, state)
	OddsView.updateHint(built.hint, state)
	if state.maxed then
		built.button.setText("최대")
		built.button.setEnabled(false, "최대 강화 단계입니다")
	else
		built.button.setText("강화")
		built.button.setEnabled(state.canAfford, state.shortReason)
	end
	built.rebirth.update()
end

-- 강화 탭 아래 고정 영역(강화 버튼 · 결과 줄)의 세로. 버튼 아래 이유 줄은 Button 규약대로 caption 높이 + 4를 비운다.
local function footerLayout()
	local caption = Theme.textSize("caption")
	local buttonY = 6
	local resultY = buttonY + Theme.buttonHeight + 4 + caption + 2 + 2
	return buttonY, resultY, resultY + caption + 4 + 4
end

-- 모바일에서 BL · BR 터치 영역(ScreenMap.mobileReserved)을 피한다(PRD 20.81 [D-5]). 320 폭 패널은 폰 가로 화면에서 두 예약 구역 사이의 빈 띠(0.3 × 폭)보다 넓어서 통째로는 못 피한다 -
-- 가로: 그 띠의 가운데에 놓아 하단 고정 영역(강화 버튼 · 결과 줄)이 두 구역을 피하게 한다. 세로: 위로 밀 수 있는 만큼 민다(높이가 모자라면 화면 안에 남긴다).
local function place(panelFrame, gui)
	if not Theme.isMobile then
		panelFrame.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
		return
	end
	local size = gui.AbsoluteSize
	local reserved = ScreenMap.mobileReserved
	local centerX = math.clamp((reserved.BL.right + reserved.BR.left) / 2 * size.X, PANEL_SIZE.X / 2, size.X - PANEL_SIZE.X / 2)
	local left = centerX - PANEL_SIZE.X / 2
	local right = left + PANEL_SIZE.X
	local bottom = size.Y - BOTTOM_OFFSET
	for _, zone in pairs(reserved) do
		if left < zone.right * size.X and right > zone.left * size.X then
			bottom = math.min(bottom, zone.top * size.Y)
		end
	end
	bottom = math.min(math.max(bottom, PANEL_SIZE.Y + TOP_MARGIN), size.Y - TOP_MARGIN)
	panelFrame.Position = UDim2.new(0, centerX, 0, bottom)
end

-- 화면 사각형(AbsolutePosition · 크기)이 모바일 예약 구역(BL · BR)과 겹치는 수.
local function reservedOverlaps(gui, position, size)
	local origin = gui.AbsolutePosition
	local viewport = gui.AbsoluteSize
	local count = 0
	for _, zone in pairs(ScreenMap.mobileReserved) do
		local rect = ScreenMap.rectFromFractions(zone, viewport)
		local x, y = position.X - origin.X, position.Y - origin.Y
		if x < rect.max.X and x + size.X > rect.min.X and y < rect.max.Y and y + size.Y > rect.min.Y then
			count += 1
		end
	end
	return count
end

-- Studio 전용 자체 점검(고정 크기 320 × 340): 스크롤 안 자식이 CanvasSize 안에 들어가는지 · 고정 하단이 자기 높이 안인지 · (모바일) 강화 버튼 · 결과 줄 글씨가 BL · BR와 겹치는지 잰다.
local function selfCheck()
	if not RunService:IsStudio() or not built then
		return
	end
	local scroll, footer = built.scroll, built.footer
	local childBottom = 0
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local extra = child.Name:find("^Toggle_") and (Theme.textSize("caption") + 4) or 0 -- Toggle 아래 이유 줄
			childBottom = math.max(childBottom, child.Position.Y.Offset + child.Size.Y.Offset + extra)
		end
	end
	local footerBottom = 0
	for _, child in ipairs(footer:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local extra = child.Name == "EnhanceButton" and (Theme.textSize("caption") + 6) or 0 -- 버튼 아래 이유 줄
			footerBottom = math.max(footerBottom, child.Position.Y.Offset + child.Size.Y.Offset + extra)
		end
	end
	local gui = built.panel.screenGui
	local button, result = built.button.root, built.resultLabel
	local textWidth = result.TextBounds.X
	local buttonOverlap = reservedOverlaps(gui, button.AbsolutePosition, button.AbsoluteSize)
	local textOverlap = textWidth > 0 and reservedOverlaps(gui, Vector2.new(result.AbsolutePosition.X + (result.AbsoluteSize.X - textWidth) / 2, result.AbsolutePosition.Y),
		Vector2.new(textWidth, result.AbsoluteSize.Y)) or 0
	local canvas = scroll.CanvasSize.Y.Offset
	print(("[S07][UI] 패널 %d × %d(%s) · 스크롤 창 %d / 내용 %d(%s) · 자식 아래끝 %d ≤ CanvasSize %d %s · 고정 하단 %d / %d %s · 뷰포트 %d × %d · 강화 버튼 겹침 %d · 결과 줄 글씨 겹침 %d(BL · BR)"):format(
		built.panel.frame.AbsoluteSize.X, built.panel.frame.AbsoluteSize.Y, Theme.isMobile and "모바일" or "PC",
		scroll.AbsoluteWindowSize.Y, canvas, canvas > scroll.AbsoluteWindowSize.Y and "스크롤됨" or "스크롤 없음",
		childBottom, canvas, childBottom <= canvas and "들어감" or "넘침",
		footerBottom, footer.AbsoluteSize.Y, footerBottom <= footer.AbsoluteSize.Y and "들어감" or "넘침",
		gui.AbsoluteSize.X, gui.AbsoluteSize.Y, buttonOverlap, textOverlap))
end

local function anyWindowOpen()
	for _, id in ipairs(UIManager.getStack()) do
		if UIManager.getKind(id) == "window" then
			return true
		end
	end
	return false
end

local function onOpen()
	if not built then
		return
	end
	place(built.panel.frame, built.panel.screenGui)
	built.scroll.CanvasPosition = Vector2.zero
	refresh()
	task.delay(0.3, selfCheck) -- 열림 트윈(UIScale 0.94 → 1, 0.12초)이 끝난 뒤에 잰다 - 도중에는 AbsoluteSize가 축소돼 있다
end

local function onClose()
	if built then
		built.rebirth.hideOverlay()
	end
	-- 사용자가 닫았으면(X · Backspace) 강화대 옆에서 다시 열지 않는다. window가 열려서 밀려난 것 · 걸어서 벗어난 것 · 다시 짓는 중의 닫힘은 아니다.
	if suppressDismiss then
		return
	end
	task.defer(function()
		if Controller.isNear() and not anyWindowOpen() then
			dismissed = true
		end
	end)
end

local function build()
	Theme.recompute()
	local panel = Panel.create({
		id = EnhancePanel.id,
		kind = "station",
		title = "",
		size = PANEL_SIZE,
		anchorPoint = Vector2.new(0.5, 1),
		position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET),
		help = helpText(),
		onOpen = onOpen,
		onClose = onClose,
	})
	local refs = { panel = panel, mobile = Theme.isMobile, tab = "enhance", connections = {} }
	local content = panel.content
	local width = PANEL_SIZE.X

	local tabs = Tabs.build({
		parent = content,
		tabs = TAB_LABELS,
		selected = "enhance",
		width = width,
		onSelect = function(id)
			refs.tab = id
			refs.enhanceBody.Visible = id == "enhance"
			refs.rebirthBody.Visible = id == "rebirth"
			refresh()
		end,
	})
	local bodyTop = Theme.tabHeight
	local function newBody(name)
		local body = Instance.new("Frame")
		body.Name = name
		body.BackgroundTransparency = 1
		body.Position = UDim2.new(0, 0, 0, bodyTop)
		body.Size = UDim2.new(1, 0, 1, -bodyTop)
		body.Parent = content
		return body
	end
	refs.enhanceBody = newBody("EnhanceBody")
	refs.rebirthBody = newBody("RebirthBody")
	refs.rebirthBody.Visible = false
	refs.tabs = tabs

	-- 강화 탭 = 위쪽 스크롤 본문(비용 2줄 → 확률표 → 불씨 → 방지권 2줄 → 한 줄 안내) + 아래 고정(강화 버튼 → 결과 줄). 본문 높이는 행 수로 계산해 CanvasSize에 넣는다.
	local buttonY, resultY, footerHeight = footerLayout()
	local innerWidth = width - PAD * 2
	local barThickness = Theme.isMobile and 6 or 4
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "EnhanceScroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 0, 0, 0)
	scroll.Size = UDim2.new(1, 0, 1, -footerHeight)
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.ScrollBarThickness = barThickness
	scroll.ScrollBarImageColor3 = Theme.colors.textSecondary
	scroll.ScrollBarImageTransparency = 0.2
	scroll.Parent = refs.enhanceBody
	refs.scroll = scroll

	local y = 4
	refs.cost = CostView.build(scroll, PAD, y, innerWidth)
	y += CostView.height() + 2
	refs.odds = OddsView.buildTable(scroll, PAD, y, innerWidth)
	y += OddsView.tableHeight() + 4
	refs.gauge = OddsView.buildGaugeRow(scroll, PAD, y, innerWidth)
	y += OddsView.gaugeRowHeight() + 6
	refs.tickets = TicketView.build(scroll, PAD, y, innerWidth, Controller.ticketKinds, {
		onToggle = function(kind, value)
			Controller.setToggle(kind, value)
			refresh()
		end,
		onBuy = function(kind)
			Controller.requestBuy(kind, EnhancePanel.id)
		end,
	})
	y += TicketView.height(#Controller.ticketKinds)
	refs.hint = OddsView.buildHint(scroll, PAD, y, innerWidth)
	y += OddsView.hintHeight() + 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, y)

	-- 스크롤이 있다는 표시: 스크롤바(위) + 더 볼 내용이 있을 때만 보이는 아래쪽 흐림. 흐림은 Active가 아니라 입력을 막지 않는다.
	local fade = Instance.new("Frame")
	fade.Name = "ScrollFade"
	fade.BackgroundColor3 = Theme.colors.panel
	fade.BorderSizePixel = 0
	fade.Position = UDim2.new(0, 0, 1, -(footerHeight + FADE_HEIGHT))
	fade.Size = UDim2.new(1, -barThickness, 0, FADE_HEIGHT)
	fade.Parent = refs.enhanceBody
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	gradient.Parent = fade
	local function updateFade()
		fade.Visible = scroll.CanvasSize.Y.Offset - (scroll.CanvasPosition.Y + scroll.AbsoluteWindowSize.Y) > 1
	end
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(updateFade)
	scroll:GetPropertyChangedSignal("AbsoluteWindowSize"):Connect(updateFade)
	updateFade()

	local footer = Instance.new("Frame")
	footer.Name = "EnhanceFooter"
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 0, 1, -footerHeight)
	footer.Size = UDim2.new(1, 0, 0, footerHeight)
	footer.Parent = refs.enhanceBody
	refs.footer = footer
	local divider = Instance.new("Frame")
	divider.Name = "FooterDivider"
	divider.BackgroundColor3 = Theme.colors.rim
	divider.BackgroundTransparency = Theme.colors.rimTransparency
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, 0, 0, 1)
	divider.Parent = footer

	refs.button = Button.build({
		parent = footer,
		name = "EnhanceButton",
		kind = "primary",
		text = "강화",
		width = BUTTON_WIDTH,
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, buttonY),
		onActivated = function()
			Controller.requestEnhance(EnhancePanel.id, OddsView.formatPercent)
		end,
	})
	refs.resultLabel = Theme.label(footer, "", "caption", "textPrimary")
	refs.resultLabel.Name = "ResultLine"
	refs.resultLabel.TextXAlignment = Enum.TextXAlignment.Center
	refs.resultLabel.Position = UDim2.new(0, PAD, 0, resultY)
	refs.resultLabel.Size = UDim2.new(0, innerWidth, 0, Theme.textSize("caption") + 4)

	-- 환생 탭(옛 EnhanceUI 그대로).
	refs.rebirth = RebirthView.build(refs.rebirthBody, panel.screenGui)

	-- 연결(다시 지을 때 끊는다).
	local function connect(connection)
		table.insert(refs.connections, connection)
	end
	for _, name in ipairs(Controller.attributeNames()) do
		connect(player:GetAttributeChangedSignal(name):Connect(refresh))
	end
	connect(player:GetAttributeChangedSignal("RebirthCount"):Connect(refs.rebirth.update))
	connect(player:GetAttributeChangedSignal("CharacterLevel"):Connect(refs.rebirth.update))
	connect(Controller.connectResult(function(data)
		local text, colorName = resultLine(data)
		refs.resultLabel.Text = text
		refs.resultLabel.TextColor3 = Theme.color(colorName)
		refresh()
	end))
	connect(Controller.connectBuyResult(function(data)
		local text, colorName = buyResultLine(data)
		refs.resultLabel.Text = text
		refs.resultLabel.TextColor3 = Theme.color(colorName)
		refresh()
	end))
	connect(ReplicatedStorage:WaitForChild("RebirthResult").OnClientEvent:Connect(refs.rebirth.handleResult))

	built = refs
end

local function destroy()
	if not built then
		return
	end
	suppressDismiss = true
	for _, connection in ipairs(built.connections) do
		connection:Disconnect()
	end
	UIManager.unregister(EnhancePanel.id)
	built.panel.screenGui:Destroy()
	built = nil
	suppressDismiss = false
end

local function ensureBuilt()
	Theme.recompute()
	if built and built.mobile ~= Theme.isMobile then
		destroy() -- Studio에서 ForceTouchLayout이 바뀐 경우 등 - 새 판정으로 다시 짓는다
	end
	if not built then
		build()
	end
end

-- 강화대 근접 열림 · 닫힘 - 걸어서 들어오면 열고 벗어나면 닫는다(window가 열려 있으면 UIManager가 열지 않는다).
local function step()
	if not Controller.isNear() then
		dismissed = false
		if built and UIManager.isOpen(EnhancePanel.id) then
			UIManager.close(EnhancePanel.id)
		end
		return
	end
	if dismissed or (built and UIManager.isOpen(EnhancePanel.id)) then
		return
	end
	ensureBuilt()
	UIManager.open(EnhancePanel.id)
end

function EnhancePanel.start()
	RunService.Heartbeat:Connect(step)
end

return EnhancePanel
