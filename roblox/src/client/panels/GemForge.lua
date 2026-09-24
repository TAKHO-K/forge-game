-- 보석 가공 창(P2.5b B · C). 가방 상세 바에서 보석을 고르고 [재련]을 누르면 열린다(그 보석이 재련 대상).
--   [재련] 탭: 대상보다 레벨이 높은 가방 보석 목록 → 하나 고르면 미리보기(레벨 · 옵션 수치 전후) + 비용(골드 + 가루) → [재련] → "되돌릴 수 없음" 확인창 → GemCraftRequest("refine").
--   [일괄 분해] 탭: 기준 등급(영웅 ~ 태초 - "이하 전부") → 대상 개수 · 가루 합 → [일괄 분해] → 확인창(보석은 전부 영웅 이상이라 항상 묻는다) → GemCraftRequest("dismantleBulk").
-- 판정 · 비용 · 결과는 서버다(GemCraftRequest → PlayerProfile). 이 창은 GemSync 스냅샷을 그리고 GemCraftResult를 한 줄로 보인다. kind = window(확인창 overlay가 이 창 위에 뜨게).
-- 폰(화면 폭 < 720 또는 높이 < 400)에서도 실효 글씨 12 이상 · 터치 44 이상 - 본문은 스크롤, 아래 줄(비용 · 버튼)은 스크롤 밖.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Confirm = require(script.Parent.Parent.ui.kit.Confirm)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)

local GemForge = {}
GemForge.id = "gemForge"

local PANEL_SIZE = Vector2.new(600, 430)
local PAD = 12
local PENDING_LIMIT = 4

local player = Players.LocalPlayer
local gemFetch = ReplicatedStorage:WaitForChild("GemFetch")
local gemSync = ReplicatedStorage:WaitForChild("GemSync")
local craftRequest = ReplicatedStorage:WaitForChild("GemCraftRequest")
local craftResult = ReplicatedStorage:WaitForChild("GemCraftResult")

local REASON_TEXT = {
	invalid = "잘못된 요청입니다",
	no_class = "직업을 먼저 고르세요",
	not_found = "보석을 찾을 수 없습니다",
	same_gem = "같은 보석은 먹일 수 없습니다",
	no_gain = "먹일 보석의 레벨이 대상보다 높아야 합니다",
	no_gold = "골드가 부족합니다",
	no_dust = "보석 가루가 부족합니다 - 보석을 분해하면 얻습니다",
	none = "분해할 보석이 없습니다",
}
GemForge.reasonText = function(reason)
	return REASON_TEXT[reason] or ("거절되었습니다(" .. tostring(reason) .. ")")
end

local state = { gems = { false, false, false, false, false }, gemInventory = {} }
local built
local mode = "refine" -- "refine" | "bulk"
local target -- { kind = "slot" | "bag", key }
local fodderIndex
local bulkGrade = "epic"
local pendingSince

local function gradeName(gradeId)
	local grade = ArmorData.grades[gradeId]
	return grade and grade.displayName or tostring(gradeId)
end

local function gradeColor(gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	return (visual and not visual.rainbow) and visual.color or Theme.color("textPrimary")
end

local function targetGem()
	if not target then
		return nil
	end
	if target.kind == "slot" then
		return Gem.isFilled(state.gems, target.key) and state.gems[target.key] or nil
	end
	return state.gemInventory[target.key]
end

local function optionText(gem)
	local lines = ItemDescribe.optionLines(gem, player:GetAttribute("ClassId"))
	local texts = {}
	for _, line in ipairs(lines) do
		table.insert(texts, line.text)
	end
	return #texts > 0 and table.concat(texts, " · ") or "옵션 없음"
end

-- 먹일 수 있는 보석(가방 · 대상보다 레벨이 높다 · 대상 자신 제외) - 레벨 높은 순.
local function fodderCandidates(gem)
	local list = {}
	for index, candidate in ipairs(state.gemInventory) do
		local isTarget = target and target.kind == "bag" and target.key == index
		if not isTarget and GemCraft.refineBlockReason(gem, candidate) == nil then
			table.insert(list, index)
		end
	end
	table.sort(list, function(a, b)
		return (state.gemInventory[a].itemLevel or 0) > (state.gemInventory[b].itemLevel or 0)
	end)
	return list
end

local function isPending()
	return pendingSince ~= nil and os.clock() - pendingSince < PENDING_LIMIT
end

local function build()
	local panel = Panel.create({
		id = GemForge.id,
		kind = "window",
		title = "보석 가공",
		size = PANEL_SIZE,
		help = "재련: 레벨이 낮아진 보석에 더 높은 레벨의 보석을 먹여 그 레벨로 올립니다. 옵션 종류 · 굴림 위치는 그대로이고 수치만 새 레벨로 다시 계산됩니다(먹인 보석은 사라집니다).\n분해: 보석을 보석 가루로 바꿉니다. 가루는 재련 · 변환권 구매에 씁니다.",
		onClose = function()
			pendingSince = nil
		end,
	})
	local content = panel.content
	local tabH = Theme.buttonHeight + PAD
	local bottomHeight = Theme.buttonHeight + PAD * 2 + Theme.textSize("caption") + 4

	local refs = { panel = panel, rows = {} }
	refs.refineTab = Button.build({
		parent = content, name = "RefineTab", kind = "secondary", text = "재련", width = 112,
		position = UDim2.new(0, PAD, 0, PAD / 2),
		onActivated = function()
			GemForge.setMode("refine")
		end,
	})
	refs.bulkTab = Button.build({
		parent = content, name = "BulkTab", kind = "secondary", text = "일괄 분해", width = 112,
		position = UDim2.new(0, PAD + 112 + 8, 0, PAD / 2),
		onActivated = function()
			GemForge.setMode("bulk")
		end,
	})
	refs.dust = Theme.label(content, "", "body", "textSecondary")
	refs.dust.Name = "DustOwned"
	refs.dust.TextXAlignment = Enum.TextXAlignment.Right
	refs.dust.AnchorPoint = Vector2.new(1, 0)
	refs.dust.Position = UDim2.new(1, -PAD, 0, PAD / 2)
	refs.dust.Size = UDim2.new(0, 220, 0, Theme.buttonHeight)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 0, 0, tabH)
	scroll.Size = UDim2.new(1, 0, 1, -(tabH + bottomHeight))
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD + 4)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.Parent = scroll
	refs.scroll = scroll

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 0, 1, 0)
	bottom.Size = UDim2.new(1, 0, 0, bottomHeight)
	bottom.Parent = content
	refs.cost = Theme.label(bottom, "", "body", "gold")
	refs.cost.Name = "Cost"
	refs.cost.Position = UDim2.new(0, PAD, 0, PAD)
	refs.cost.Size = UDim2.new(1, -(PAD * 3 + 240), 0, Theme.buttonHeight)
	refs.action = Button.build({
		parent = bottom, name = "ActionButton", kind = "primary", text = "재련", width = 112,
		anchorPoint = Vector2.new(1, 0), position = UDim2.new(1, -PAD, 0, PAD),
		onActivated = function()
			GemForge.confirm()
		end,
	})
	refs.back = Button.build({
		parent = bottom, name = "BackButton", kind = "secondary", text = "닫기", width = 112,
		anchorPoint = Vector2.new(1, 0), position = UDim2.new(1, -(PAD + 112 + 8), 0, PAD),
		onActivated = function()
			GemForge.back()
		end,
	})
	built = refs
end

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function addLabel(text, sizeName, colorName, height)
	local label = Theme.label(built.scroll, text, sizeName, colorName)
	label.LayoutOrder = nextOrder()
	label.Size = UDim2.new(1, 0, 0, height or (Theme.textSize(sizeName) + 8))
	label.TextWrapped = (height or 0) > Theme.textSize(sizeName) + 8
	return label
end

-- 목록 한 행: 왼쪽 글 두 줄 · 오른쪽 버튼. 선택되면 ember 테두리.
local function addRow(name, title, subtitle, titleColor, selected, buttonText, enabled, onActivated)
	local rowH = math.max(Theme.buttonHeight + 12, Theme.textSize("body") + Theme.textSize("caption") + 20)
	local row = Instance.new("Frame")
	row.Name = name
	row.LayoutOrder = nextOrder()
	row.Size = UDim2.new(1, 0, 0, rowH)
	row.BackgroundColor3 = Theme.color("slot")
	row.BackgroundTransparency = Theme.colors.slotTransparency
	row.Parent = built.scroll
	Theme.corner(row, Theme.corner.chip)
	local stroke = Theme.stroke(row)
	if selected then
		stroke.Color = Theme.color("ember")
		stroke.Transparency = 0
		stroke.Thickness = 2
	end
	local titleLabel = Theme.label(row, title, "body", "textPrimary")
	titleLabel.TextColor3 = titleColor or Theme.color("textPrimary")
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.Size = UDim2.new(1, -(10 + 112 + 16), 0, Theme.textSize("body") + 4)
	local sub = Theme.label(row, subtitle, "caption", "textSecondary")
	sub.Position = UDim2.new(0, 10, 0, 8 + Theme.textSize("body") + 4)
	sub.Size = UDim2.new(1, -(10 + 112 + 16), 0, Theme.textSize("caption") + 4)
	local button = Button.build({
		parent = row, name = "Pick", kind = selected and "primary" or "secondary", text = buttonText, width = 104,
		anchorPoint = Vector2.new(1, 0.5), position = UDim2.new(1, -8, 0.5, 0),
		onActivated = onActivated,
	})
	button.setEnabled(enabled)
	built.rows[name] = button
	return row
end

local function renderRefine()
	local gem = targetGem()
	if not gem then
		addLabel("재련할 보석이 없습니다 - 가방 · 보석 탭에서 보석을 고르고 [재련]을 누르세요", "body", "textSecondary", 44)
		return nil
	end
	local where = target.kind == "slot" and ("%d번 홈(장착 중)"):format(target.key) or "보석 가방"
	local head = addLabel(("대상: %s · Lv.%d · %s"):format(ItemDescribe.gem(gem).title, gem.itemLevel or 0, where), "body", "textPrimary")
	head.Name = "TargetLine"
	head.TextColor3 = gradeColor(gem.grade)
	addLabel(("지금 옵션: %s"):format(optionText(gem)), "caption", "textSecondary")
	local fodder = fodderIndex and state.gemInventory[fodderIndex]
	if fodder and GemCraft.refineBlockReason(gem, fodder) ~= nil then
		fodderIndex, fodder = nil, nil
	end
	if fodder then
		local after = GemCraft.refinedGem(gem, fodder)
		local preview = addLabel(("재련 뒤: Lv.%d → Lv.%d · %s → %s"):format(gem.itemLevel or 0, after.itemLevel, optionText(gem), optionText(after)), "caption", "success", 36)
		preview.Name = "PreviewLine"
	end
	local candidates = fodderCandidates(gem)
	addLabel(("먹일 보석(대상보다 레벨이 높은 가방 보석 %d개 - 먹인 보석은 사라집니다)"):format(#candidates), "caption", "textSecondary")
	if #candidates == 0 then
		addLabel("대상보다 레벨이 높은 보석이 가방에 없습니다", "body", "textTertiary", 36)
	end
	for _, index in ipairs(candidates) do
		local candidate = state.gemInventory[index]
		addRow("Fodder_" .. index, ItemDescribe.gem(candidate).title, ("Lv.%d · %s"):format(candidate.itemLevel or 0, optionText(candidate)),
			gradeColor(candidate.grade), fodderIndex == index, fodderIndex == index and "선택됨" or "먹이기", not isPending(), function()
				fodderIndex = index
				GemForge.render()
			end)
	end
	return gem, fodder
end

local function renderBulk()
	addLabel("기준 등급 이하의 가방 보석을 전부 가루로 바꿉니다(홈에 낀 보석은 대상이 아닙니다)", "caption", "textSecondary", 36)
	for _, gradeId in ipairs(GemCraft.bulkGradeChoices()) do
		local count, dust = GemCraft.bulkEstimate(state.gemInventory, gradeId)
		addRow("Grade_" .. gradeId, ("%s 이하"):format(gradeName(gradeId)), ("대상 %d개 → 가루 %s"):format(count, NumberFormat.format(dust)),
			gradeColor(gradeId), bulkGrade == gradeId, bulkGrade == gradeId and "선택됨" or "고르기", not isPending(), function()
				bulkGrade = gradeId
				GemForge.render()
			end)
	end
end

function GemForge.render()
	if not built or not UIManager.isOpen(GemForge.id) then
		return
	end
	for name in pairs(built.rows) do
		built.rows[name] = nil
	end
	for _, child in ipairs(built.scroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	order = 0
	local dustOwned = player:GetAttribute("GemDust") or 0
	local gold = player:GetAttribute("Gold") or 0
	built.dust.Text = ("보석 가루 %s"):format(NumberFormat.format(dustOwned))
	built.refineTab.forceVisual(mode == "refine" and "pressed" or nil)
	built.bulkTab.forceVisual(mode == "bulk" and "pressed" or nil)

	if mode == "refine" then
		local gem, fodder = renderRefine()
		built.action.setText("재련")
		if gem and fodder then
			local goldCost, dustCost = GemCraft.refineCost(gem.grade, player:GetAttribute("AccountBestStage") or 1)
			built.cost.Text = ("비용 %s 골드 + 가루 %d"):format(NumberFormat.format(goldCost), dustCost)
			local reason = (gold < goldCost and REASON_TEXT.no_gold) or (dustOwned < dustCost and REASON_TEXT.no_dust) or nil
			built.cost.TextColor3 = reason and Theme.color("danger") or Theme.color("gold")
			built.action.setEnabled(reason == nil and not isPending(), reason)
		else
			built.cost.Text = gem and "먹일 보석을 고르세요" or ""
			built.cost.TextColor3 = Theme.color("textSecondary")
			built.action.setEnabled(false)
		end
	else
		renderBulk()
		built.action.setText("일괄 분해")
		local count, dust = GemCraft.bulkEstimate(state.gemInventory, bulkGrade)
		built.cost.Text = ("%s 이하 %d개 → 가루 +%s"):format(gradeName(bulkGrade), count, NumberFormat.format(dust))
		built.cost.TextColor3 = Theme.color("textPrimary")
		built.action.setEnabled(count > 0 and not isPending(), count == 0 and REASON_TEXT.none or nil)
	end
end

function GemForge.setMode(newMode)
	mode = newMode
	if built then
		built.scroll.CanvasPosition = Vector2.zero
	end
	GemForge.render()
end

-- targetKind = "slot" | "bag" · key = 홈 번호 | 가방 index. openMode = "refine"(기본) | "bulk".
function GemForge.open(targetKind, key, openMode)
	if not built then
		build()
	end
	target = targetKind and { kind = targetKind, key = key } or nil
	fodderIndex = nil
	mode = openMode or "refine"
	pendingSince = nil
	if not UIManager.open(GemForge.id) then
		return false
	end
	GemForge.render()
	task.spawn(function()
		local ok, data = pcall(function()
			return gemFetch:InvokeServer()
		end)
		if ok and type(data) == "table" then
			state = data
			GemForge.render()
		end
	end)
	return true
end

function GemForge.back()
	UIManager.close(GemForge.id)
	task.defer(function()
		UIManager.open("inventory")
	end)
end

local function send(action, a, b, c)
	pendingSince = os.clock()
	built.action.setBusy(true)
	craftRequest:FireServer(action, a, b, c)
	task.delay(PENDING_LIMIT, function()
		if pendingSince and os.clock() - pendingSince >= PENDING_LIMIT - 0.05 then
			pendingSince = nil
			if built then
				built.action.setBusy(false)
				GemForge.render()
			end
		end
	end)
end

function GemForge.confirm()
	if isPending() then
		return
	end
	if mode == "refine" then
		local gem = targetGem()
		local fodder = fodderIndex and state.gemInventory[fodderIndex]
		if not gem or not fodder or GemCraft.refineBlockReason(gem, fodder) then
			return
		end
		local goldCost, dustCost = GemCraft.refineCost(gem.grade, player:GetAttribute("AccountBestStage") or 1)
		local requested, fodderAt = target, fodderIndex
		Confirm.ask({
			title = "재련 - 되돌릴 수 없습니다",
			body = ("%s의 레벨이 Lv.%d → Lv.%d가 됩니다.\n먹인 보석(%s)은 사라집니다.\n비용: %s 골드 + 가루 %d"):format(
				ItemDescribe.gem(gem).title, gem.itemLevel or 0, fodder.itemLevel, ItemDescribe.gem(fodder).title, NumberFormat.format(goldCost), dustCost),
			primaryText = "재련",
			danger = true,
			parentId = GemForge.id,
		}, function(accepted)
			if accepted and target == requested and fodderIndex == fodderAt then
				send("refine", requested.kind, requested.key, fodderAt)
			end
		end)
	else
		local count, dust, highest = GemCraft.bulkEstimate(state.gemInventory, bulkGrade)
		if count == 0 then
			return
		end
		local chosen = bulkGrade
		Confirm.ask({
			title = "일괄 분해 - 되돌릴 수 없습니다",
			body = ("%s 이하 보석 %d개를 가루 %s로 바꿉니다(대상 중 최고 등급: %s).\n홈에 낀 보석은 그대로입니다."):format(
				gradeName(chosen), count, NumberFormat.format(dust), gradeName(highest)),
			primaryText = "분해",
			danger = true,
			parentId = GemForge.id,
		}, function(accepted)
			if accepted then
				send("dismantleBulk", chosen)
			end
		end)
	end
end

gemSync.OnClientEvent:Connect(function(data)
	state = data
	GemForge.render()
end)

craftResult.OnClientEvent:Connect(function(action, success, reason, data)
	if action ~= "refine" and action ~= "dismantleBulk" and action ~= "dismantle" and action ~= "sell" then
		return
	end
	pendingSince = nil
	if built then
		built.action.setBusy(false)
	end
	if success then
		local text
		if action == "refine" then
			text = "재련 완료 - 보석 레벨이 올랐습니다"
		elseif action == "dismantleBulk" then
			text = ("보석 %d개를 분해해 가루 %s를 얻었습니다"):format(data and data.count or 0, NumberFormat.format(data and data.dust or 0))
		elseif action == "sell" then
			text = ("보석을 판매해 골드 %s를 얻었습니다"):format(NumberFormat.format(data and data.gold or 0)) -- P3c E4
		else
			text = ("보석을 분해해 가루 %s를 얻었습니다"):format(NumberFormat.format(data and data.dust or 0))
		end
		Toast.push("TC", { text = text, colorName = "success", seconds = 4 })
		if action == "refine" and UIManager.isOpen(GemForge.id) then
			GemForge.back() -- 가방 index가 바뀌었다(먹인 보석이 빠졌다) - 대상을 다시 고르게 가방으로 돌아간다
		elseif action == "dismantleBulk" and target and target.kind == "bag" then
			-- 리뷰 1: 가방 보석이 빠져 index가 밀렸다 - 옛 index로 다른 보석이 대상이 되지 않게 비운다(재련 탭은 "대상 없음"을 보이고 가방에서 다시 고른다).
			target, fodderIndex = nil, nil
		end
	else
		Toast.push("TC", { text = GemForge.reasonText(reason), colorName = "danger", seconds = 4 })
	end
	GemForge.render()
end)

player:GetAttributeChangedSignal("GemDust"):Connect(GemForge.render)

-- 점검용(P25b(UI) · 스크린샷): 서버 스냅샷 대신 합성 보석 상태로 연다(GemSync가 오면 실제 상태로 덮인다).
function GemForge.debugOpen(fakeState, targetKind, key, openMode, fodder)
	if not built then
		build()
	end
	state = fakeState
	target = targetKind and { kind = targetKind, key = key } or nil
	fodderIndex = fodder
	mode = openMode or "refine"
	pendingSince = nil
	if not UIManager.isOpen(GemForge.id) and not UIManager.open(GemForge.id) then
		return false
	end
	GemForge.render()
	return true
end

-- 점검용.
function GemForge.debugState()
	return { open = UIManager.isOpen(GemForge.id), mode = mode, target = target, fodderIndex = fodderIndex, bulkGrade = bulkGrade, refs = built }
end

return GemForge
