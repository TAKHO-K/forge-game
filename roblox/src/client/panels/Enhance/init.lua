-- 강화 패널 조립(28-1 S07, PRD 20.72 [1-8] · 20.81 [D]). GUI 공통 틀(S06) 위에 처음으로 올라가는 화면 - `Panel`(kind = "station")로 만들고 `UIManager`가 열림 규칙을 준다.
-- 320 × 340 고정 · 하단 중앙 앵커(지금 자리). 강화대 근처에 들어가면 열리고 벗어나면 닫힌다(근접 열림 - 지금 동작). X로 닫으면 벗어났다 돌아올 때까지 다시 열지 않는다.
-- 탭 "강화 | 환생": 강화 탭 = 비용 2줄 · 확률표 5행 · 장인의 기운 · 강화 버튼 · 결과 줄 / 환생 탭 = 옛 EnhanceUI의 환생 탭 그대로(RebirthView).
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

local EnhancePanel = {}

EnhancePanel.id = "enhance"
local PANEL_SIZE = Vector2.new(320, 340)
local BOTTOM_OFFSET = 120 -- 화면 아래에서 띄우는 간격(옛 패널 자리 그대로 - 스킬 · 체력바 위)
local TOP_MARGIN = 8
local PAD = 8
local BUTTON_WIDTH = 200
local TAB_LABELS = { { id = "enhance", text = "강화" }, { id = "rebirth", text = "환생" } }

local player = Players.LocalPlayer
local built -- 지은 패널의 refs 표 하나(아래 build) - 없으면 아직 안 지었다
local dismissed = false -- X · Backspace로 닫았다: 강화대에서 벗어났다 돌아올 때까지 다시 열지 않는다
local suppressDismiss = false -- 다시 짓는 동안의 닫힘은 사용자가 닫은 것이 아니다

-- 도움말 문구(PRD 20.72 [1-8]) - 숫자는 확률표 · EnhanceConfig에서 끼운다.
local function helpText()
	local dropFrom, resetFrom = Enhance.getRiskStartLevels()
	return ("0~%d강은 실패해도 단계가 내려가지 않습니다. %d강부터 하락, %d강부터 초기화(%d강)가 있습니다. 실패할 때마다 장인의 기운이 차고, 가득 차면 다음 시도는 반드시 성공합니다."):format(
		dropFrom - 1, dropFrom, resetFrom, EnhanceConfig.resetToLevel)
end

-- 결과 줄의 문구와 색(UIColors 이름). payload = EnhanceResult가 실어 온 표(EnhanceService.handleRequest).
local function resultLine(data)
	local level = data.level or (player:GetAttribute("WeaponLevel") or 0)
	local result = data.result
	local suffix = ""
	if data.gaugeGain and data.gaugeGain > 0 then
		suffix = (" · 기운 +%s"):format(OddsView.formatPercent(data.gaugeGain / (data.gaugeMax or EnhanceConfig.gauge.max)))
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
		return ("%d강에서 다시 시작합니다. 기운은 유지됩니다"):format(EnhanceConfig.resetToLevel), "danger"
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

local function refresh()
	if not built then
		return
	end
	local state = Controller.getState()
	if built.tab == "enhance" then
		built.panel.titleLabel.Text = state.maxed and ("%s 등급 · +%d (최대)"):format(state.gradeName, state.level)
			or ("%s 등급 · +%d → +%d"):format(state.gradeName, state.level, state.level + 1)
	else
		built.panel.titleLabel.Text = "환생"
	end
	CostView.update(built.cost, state)
	OddsView.updateTable(built.odds, state.level, state.outcomes)
	OddsView.updateGaugeRow(built.gauge, state)
	if state.maxed then
		built.button.setText("최대")
		built.button.setEnabled(false, "최대 강화 단계입니다")
	else
		built.button.setText("강화")
		built.button.setEnabled(state.canAfford, state.shortReason)
	end
	built.rebirth.update()
end

-- 모바일에서 BL · BR 터치 영역(ScreenMap.mobileReserved)에 걸리면 위로 민다(PRD 20.81 [D-5]). 위로 밀 자리가 모자라면 화면 안에 남긴다.
local function place(panelFrame, gui)
	if not Theme.isMobile then
		panelFrame.Position = UDim2.new(0.5, 0, 1, -BOTTOM_OFFSET)
		return
	end
	local size = gui.AbsoluteSize
	local left = size.X / 2 - PANEL_SIZE.X / 2
	local right = left + PANEL_SIZE.X
	local bottom = size.Y - BOTTOM_OFFSET
	for _, reserved in pairs(ScreenMap.mobileReserved) do
		if left < reserved.right * size.X and right > reserved.left * size.X then
			bottom = math.min(bottom, reserved.top * size.Y)
		end
	end
	bottom = math.min(math.max(bottom, PANEL_SIZE.Y + TOP_MARGIN), size.Y - TOP_MARGIN)
	panelFrame.Position = UDim2.new(0.5, 0, 0, bottom)
end

-- Studio 전용 자체 점검: 강화 탭 내용이 본문 높이 안에 들어가는지(고정 크기 320 × 340) 잰다.
local function selfCheck()
	if not RunService:IsStudio() or not built then
		return
	end
	local body = built.enhanceBody
	local bottom = 0
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("GuiObject") and child.Visible then
			local extra = child.Name == "EnhanceButton" and (Theme.textSize("caption") + 6) or 0 -- 버튼 아래 이유 줄
			bottom = math.max(bottom, child.Position.Y.Offset + child.Size.Y.Offset + extra)
		end
	end
	print(("[S07][UI] 패널 %d × %d · 강화 탭 내용 아래끝 %d / 본문 높이 %d(%s) %s"):format(
		built.panel.frame.AbsoluteSize.X, built.panel.frame.AbsoluteSize.Y, bottom, body.AbsoluteSize.Y, Theme.isMobile and "모바일" or "PC",
		bottom <= body.AbsoluteSize.Y and "들어감" or "넘침"))
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

	-- 강화 탭: 위에서부터 쌓는다(비용 2줄 → 확률표 → 기운 → 강화 버튼 → 결과 줄).
	local innerWidth = width - PAD * 2
	local y = 4
	refs.cost = CostView.build(refs.enhanceBody, PAD, y, innerWidth)
	y += CostView.height() + 2
	refs.odds = OddsView.buildTable(refs.enhanceBody, PAD, y, innerWidth)
	y += OddsView.tableHeight() + 4
	refs.gauge = OddsView.buildGaugeRow(refs.enhanceBody, PAD, y, innerWidth)
	y += OddsView.gaugeRowHeight() + 6
	local buttonY = y
	refs.button = Button.build({
		parent = refs.enhanceBody,
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
	y += Theme.buttonHeight + 4 + Theme.textSize("caption") + 2 + 2 -- 버튼 + 아래 이유 줄(Button 규약: 호출부가 caption 높이 + 4를 비운다)
	refs.resultLabel = Theme.label(refs.enhanceBody, "", "caption", "textPrimary")
	refs.resultLabel.Name = "ResultLine"
	refs.resultLabel.TextXAlignment = Enum.TextXAlignment.Center
	refs.resultLabel.Position = UDim2.new(0, PAD, 0, y)
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
