-- "보석 공방" 창(S20e) - 커뮤니티 센터 보석상인(ProximityPrompt GemMerchantPrompt, PC E · 모바일 탭)이 여는 station. 보석 탭에 있던 변환 · 리롤 UI가 여기로 옮겨 왔다:
--   ① 변환권 구매(고대 · 태초 - 골드) ② 리롤할 대상 목록(홈 5 + 착용 3부위 + 가방 장비 중 고대 · 태초만) 각 행의 [리롤(n장)].
-- 기능 · 서버 규칙 · 비용은 그대로다(GemRerollRequest · BuyRerollTicketRequest). 달라진 것은 자리뿐 - 서버가 요청 시점에 보석상인 반경을 직접 잰다(GemWorkshop → GemMerchantAccess).
-- 이 창은 서버 상태의 진실을 갖지 않는다: GemSync · InventorySync 스냅샷을 그리고, GemWorkshopResult(action, success, reason)를 한 줄로 보인다. 걸어서 반경을 벗어나면 저절로 닫힌다(표시 편의 - 판정은 서버).
-- 처음 시작할 때 짓는다(Theme.recompute 뒤의 모바일 판정을 따르기 위해 - 판정이 바뀌면 다시 짓는다). 행은 상태가 바뀔 때마다 다시 그린다(행 수 최대 약 30).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Gem = require(ReplicatedStorage.Shared.Gem)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)
local Guide = require(script.Guide)

local GemWorkshop = {}

GemWorkshop.id = "gemWorkshop"
GemWorkshop.promptName = "GemMerchantPrompt"
local PANEL_SIZE = Vector2.new(480, 380)
local STATUS_HEIGHT = 26
local TOP_OFFSET = 16 -- 화면 위에서 띄우는 간격 - 위쪽에 붙여 아래쪽 스킬 바 · 체력바(PC)를 가리지 않는다(창이 화면보다 크면 UIManager.fitToScreen이 줄인다)
local PENDING_LIMIT = 3 -- 초. 서버 결과가 안 오면(서버가 조용히 버린 요청) 이 뒤에 입력이 풀린다
local RANGE_MARGIN = 2 -- 서버 반경보다 이만큼 더 벗어나면 창을 닫는다(경계에서 깜빡이지 않게)

local player = Players.LocalPlayer
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")
local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local inventoryFetch = ReplicatedStorage:WaitForChild("InventoryFetch")
local inventorySync = ReplicatedStorage:WaitForChild("InventorySync")
local rerollRequest = ReplicatedStorage:WaitForChild("GemRerollRequest")
local buyRequest = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")
local workshopResult = ReplicatedStorage:WaitForChild("GemWorkshopResult")

-- 서버 스냅샷(그대로) - 열 때 · 스냅샷이 올 때 다시 그린다.
local state = {
	gems = { false, false, false, false, false },
	tickets = { ancient = 0, primordial = 0 },
	inventory = {},
	equipment = {},
}
local built = nil -- { panel, scroll, status, mobile, rows = { [행 이름] = 버튼 refs } }
local pendingSince = nil
local debugSkipRangeClose = false -- Studio 자체 점검 전용: 검증 캐릭터는 보석상인 반경 밖이라 창이 열리자마자 닫히지 않게 끈다
local statusText, statusColorName = "", "textSecondary"

-- 결과 이유 코드 → 한 줄(서버 GemServer의 workshopResult 주석과 같은 코드).
local REASON_TEXT = {
	out_of_range = "보석상인에게서 너무 멀어 요청이 거절되었습니다",
	no_character = "캐릭터를 찾을 수 없습니다",
	invalid = "잘못된 요청입니다",
	no_ticket = "변환권이 없습니다 - 위에서 구매하세요",
	no_gold = "골드가 부족합니다",
	no_class = "직업을 먼저 고르세요",
	empty_slot = "빈 홈은 리롤할 수 없습니다",
	not_rerollable = "고대 · 태초 등급만 리롤할 수 있습니다",
	not_found = "대상을 찾을 수 없습니다",
	not_equipped = "착용 중인 장비가 아닙니다",
}

local function ticketPrice()
	-- 28-2 [8] 3번: 가격 기준은 계정 최고 스테이지(서버 GemServer.rerollTicketPrice와 같은 값 - Attribute는 PlayerProfile이 내린다).
	local stage = player:GetAttribute("AccountBestStage") or 1
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage) * GemData.rerollTicketGoldMultiplier
end

local function gradeName(gradeId)
	local grade = ArmorData.grades[gradeId]
	return grade and grade.displayName or tostring(gradeId)
end

local function optionText(described)
	local texts = {}
	for _, line in ipairs(described.options) do
		table.insert(texts, line.text)
	end
	return #texts > 0 and table.concat(texts, " · ") or "옵션 없음"
end

-- 리롤할 수 있는 대상(고대 · 태초만): { kind, key, title, subtitle, gradeId }
local function collectTargets()
	local classId = player:GetAttribute("ClassId")
	local list = {}
	for slot = 1, Gem.slotCount do
		local gem = state.gems[slot]
		if type(gem) == "table" and Gem.isRerollableGrade(gem.grade) then
			local described = ItemDescribe.gem(gem, classId)
			table.insert(list, { kind = "gem", key = slot, title = ("%d번 홈 · %s"):format(slot, described.title), subtitle = optionText(described), gradeId = gem.grade })
		end
	end
	for _, part in ipairs(EquipSlots.order) do
		local item = state.equipment[part]
		if type(item) == "table" and Gem.isRerollableGrade(item.grade) then
			local described = ItemDescribe.item(item, classId)
			table.insert(list, { kind = "equipped", key = part, title = ("착용 · %s"):format(described.title), subtitle = described.meta .. " · " .. optionText(described), gradeId = item.grade })
		end
	end
	for index, item in ipairs(state.inventory) do
		if Gem.isRerollableGrade(item.grade) then
			local described = ItemDescribe.item(item, classId)
			table.insert(list, { kind = "bag", key = index, title = ("가방 · %s"):format(described.title), subtitle = described.meta .. " · " .. optionText(described), gradeId = item.grade })
		end
	end
	return list
end

local function isPending()
	return pendingSince ~= nil and os.clock() - pendingSince < PENDING_LIMIT
end

local function setStatus(text, colorName)
	statusText, statusColorName = text, colorName or "textSecondary"
	if built then
		built.status.Text = statusText
		built.status.TextColor3 = Theme.colors[statusColorName]
	end
end

local refresh

local function sendReroll(target)
	if isPending() then
		return
	end
	pendingSince = os.clock()
	setStatus("리롤 요청 중...", "textSecondary")
	rerollRequest:FireServer(target.kind, target.key)
	refresh()
end

local function sendBuy(gradeId)
	if isPending() then
		return
	end
	pendingSince = os.clock()
	setStatus("변환권 구매 요청 중...", "textSecondary")
	buyRequest:FireServer(gradeId)
	refresh()
end

-- 행 하나: 왼쪽 제목 · 부제 + 오른쪽 버튼. 버튼 높이 = Theme.buttonHeight(PC 32 / 모바일 44). 반환: 행, 버튼 refs(자체 점검이 활성 상태를 읽는다).
local function buildRow(parent, width, props)
	local rowHeight = Theme.isMobile and 56 or 44
	local row = Instance.new("Frame")
	row.Name = props.name
	row.LayoutOrder = props.order
	row.Size = UDim2.new(0, width, 0, rowHeight)
	row.BackgroundColor3 = Theme.colors.slot
	row.BackgroundTransparency = Theme.colors.slotTransparency
	row.Parent = parent
	Theme.corner(row, Theme.corner.chip)
	Theme.stroke(row)

	local rightWidth = Button.minWidth + 8
	local title = Theme.label(row, props.title, "body", "textPrimary")
	title.Position = UDim2.new(0, 10, 0, Theme.isMobile and 8 or 4)
	title.Size = UDim2.new(1, -(20 + rightWidth), 0, Theme.textSize("body") + 4)
	if props.gradeColor then
		title.TextColor3 = props.gradeColor
	end
	local subtitle = Theme.label(row, props.subtitle, "caption", "textSecondary")
	subtitle.Position = UDim2.new(0, 10, 0, (Theme.isMobile and 8 or 4) + Theme.textSize("body") + 6)
	subtitle.Size = UDim2.new(1, -(20 + rightWidth), 0, Theme.textSize("caption") + 2)

	local button = Button.build({
		parent = row,
		kind = props.kind or "secondary",
		text = props.buttonText,
		width = Button.minWidth,
		anchorPoint = Vector2.new(1, 0.5),
		position = UDim2.new(1, -8, 0.5, 0),
		onActivated = props.onActivated,
	})
	button.setEnabled(props.enabled ~= false)
	return row, button
end

local function buildSectionLabel(parent, text, order)
	local label = Theme.label(parent, text, "caption", "textSecondary")
	label.Name = "Section" .. order
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -8, 0, Theme.textSize("caption") + 6)
	return label
end

refresh = function()
	if not built then
		return
	end
	for _, child in ipairs(built.scroll:GetChildren()) do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	built.rows = {}
	local width = PANEL_SIZE.X - 24
	local gold = player:GetAttribute("Gold") or 0
	local price = ticketPrice()
	local busy = isPending()
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end

	buildSectionLabel(built.scroll, "변환권 - 골드로 구매(가격은 계정 최고 스테이지 기준)", nextOrder())
	for _, gradeId in ipairs({ "ancient", "primordial" }) do
		local owned = state.tickets[gradeId] or 0
		local ticketName = "Ticket_" .. gradeId
		local _, ticketButton = buildRow(built.scroll, width, {
			name = ticketName,
			order = nextOrder(),
			title = ("%s 변환권 · 보유 %d장"):format(gradeName(gradeId), owned),
			subtitle = ("가격 %s골드"):format(NumberFormat.format(price)),
			buttonText = "구매",
			enabled = gold >= price and not busy,
			onActivated = function()
				sendBuy(gradeId)
			end,
		})
		built.rows[ticketName] = ticketButton
	end

	buildSectionLabel(built.scroll, "리롤 - 고대 · 태초 등급 장비 · 보석의 옵션을 변환권으로 다시 굴립니다", nextOrder())
	local targets = collectTargets()
	if #targets == 0 then
		local empty = Theme.label(built.scroll, "리롤할 수 있는 고대 · 태초 등급 장비 · 보석이 없습니다", "body", "textSecondary")
		empty.Name = "Empty"
		empty.LayoutOrder = nextOrder()
		empty.Size = UDim2.new(1, -8, 0, 40)
	end
	for _, target in ipairs(targets) do
		local owned = state.tickets[target.gradeId] or 0
		local visual = ItemVisualData.gradeVisuals[target.gradeId]
		local targetName = ("Target_%s_%s"):format(target.kind, tostring(target.key))
		local _, targetButton = buildRow(built.scroll, width, {
			name = targetName,
			order = nextOrder(),
			title = target.title,
			subtitle = target.subtitle .. ((owned < 1) and " · 변환권 없음" or ""),
			gradeColor = visual and visual.color or nil,
			buttonText = ("리롤(%d장)"):format(owned),
			enabled = owned >= 1 and not busy,
			onActivated = function()
				sendReroll(target)
			end,
		})
		built.rows[targetName] = targetButton
	end
	built.status.Text = statusText
	built.status.TextColor3 = Theme.colors[statusColorName]
end

local function fetchState()
	local okGem, gemState = pcall(function()
		return gemFetch:InvokeServer()
	end)
	if okGem and type(gemState) == "table" then
		state.gems, state.tickets = gemState.gems, gemState.rerollTickets
	end
	local okInv, invState = pcall(function()
		return inventoryFetch:InvokeServer()
	end)
	if okInv and type(invState) == "table" then
		state.inventory = invState.inventory or {}
		state.equipment = { armor = invState.armor, gloves = invState.gloves, shoes = invState.shoes }
	end
end

local function onOpen()
	Guide.hide() -- 찾아온 것이니 마커는 끈다
	setStatus("", "textSecondary")
	if built then
		built.scroll.CanvasPosition = Vector2.zero
	end
	refresh()
end

local function build()
	Theme.recompute()
	local panel = Panel.create({
		id = GemWorkshop.id,
		kind = "station",
		title = "보석 공방",
		size = PANEL_SIZE,
		anchorPoint = Vector2.new(0.5, 0),
		position = UDim2.new(0.5, 0, 0, TOP_OFFSET),
		help = "고대 · 태초 등급 장비 · 보석의 옵션을 변환권으로 다시 굴립니다. 변환권은 이곳에서 골드로 삽니다.\n보석 장착 · 교체는 어디서나 됩니다(가방 → 보석 탭).",
		onOpen = onOpen,
	})
	local content = panel.content

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "List"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 12, 0, 8)
	scroll.Size = UDim2.new(1, -24, 1, -(STATUS_HEIGHT + 12))
	scroll.ScrollBarThickness = 4
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = scroll

	local status = Theme.label(content, "", "caption", "textSecondary")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 14, 1, -4)
	status.Size = UDim2.new(1, -28, 0, STATUS_HEIGHT - 4)

	built = { panel = panel, scroll = scroll, status = status, mobile = Theme.isMobile }
end

local function destroy()
	if not built then
		return
	end
	UIManager.unregister(GemWorkshop.id)
	built.panel.screenGui:Destroy()
	built = nil
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

function GemWorkshop.open()
	ensureBuilt()
	fetchState()
	return UIManager.open(GemWorkshop.id)
end

-- Studio 자체 점검 전용(GemWorkshopCheck): 서버 없이 상태를 넣어 그리고 · 지금 창(패널 · 목록)을 돌려준다. 실제 화면은 서버 스냅샷이 그린다.
function GemWorkshop.debugApply(snapshot)
	state.gems = snapshot.gems or state.gems
	state.tickets = snapshot.tickets or state.tickets
	state.inventory = snapshot.inventory or state.inventory
	state.equipment = snapshot.equipment or state.equipment
	refresh()
end
function GemWorkshop.debugSkipRangeClose(skip)
	debugSkipRangeClose = skip == true
end
function GemWorkshop.debugBuilt()
	return built
end
function GemWorkshop.debugReset()
	fetchState()
	refresh()
end

-- 걸어서 반경을 벗어나면 닫는다(서버가 요청마다 다시 재므로 표시 편의일 뿐이다).
local function step()
	if debugSkipRangeClose or not built or not UIManager.isOpen(GemWorkshop.id) then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	if (root.Position - Guide.merchantPosition()).Magnitude > WorldConfig.gemMerchant.interactionRangeStuds + RANGE_MARGIN then
		UIManager.close(GemWorkshop.id)
	end
end

function GemWorkshop.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if prompt.Name == GemWorkshop.promptName and triggeringPlayer == player then
			GemWorkshop.open()
		end
	end)
	gemSync.OnClientEvent:Connect(function(snapshot)
		state.gems, state.tickets = snapshot.gems, snapshot.rerollTickets
		refresh()
	end)
	inventorySync.OnClientEvent:Connect(function(snapshot)
		state.inventory = snapshot.inventory
		state.equipment = { armor = snapshot.armor, gloves = snapshot.gloves, shoes = snapshot.shoes }
		refresh()
	end)
	workshopResult.OnClientEvent:Connect(function(action, success, reason)
		pendingSince = nil
		if success then
			setStatus(action == "buy" and "변환권을 샀습니다" or "리롤 완료 - 새 옵션을 확인하세요", "success")
		else
			setStatus(REASON_TEXT[reason] or ("거절되었습니다(" .. tostring(reason) .. ")"), "danger")
		end
		refresh()
	end)
	player:GetAttributeChangedSignal("Gold"):Connect(refresh)
	RunService.Heartbeat:Connect(step)
	ensureBuilt()
end

return GemWorkshop
