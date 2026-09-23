-- 장비 계승 창(P2.5b A). 가방 상세 바의 [계승](착용 중인 같은 부위보다 좋은 장비를 골랐을 때만 보인다)이 연다.
--   ① 착용 중 A → 새 장비 B ② 남길 옵션 세트 고르기(A 세트 / B 세트 - B 등급이 낮으면 A 세트는 회색 + 이유) ③ 계승 전후 최종 능력치(서버가 계산 - InheritPreview)
--   ④ A 환급 · 비용 ⑤ [계승] → "되돌릴 수 없음" 확인창(Confirm) → InheritRequest. 결과(InheritResult)는 토스트 한 줄 · 창을 닫고 가방으로 돌아간다.
-- 판정 · 비용 · 능력치는 전부 서버 값이다(이 창은 그리기만 한다). kind = window(가방 창이 닫히고 이 창이 열린다 - 확인창 overlay가 이 창 위에 뜨게).
-- 폰(화면 폭 < 720 또는 높이 < 400)에서도 실효 글씨 12 이상 · 터치 44 이상 - 본문은 스크롤, 아래 줄(비용 · 버튼)은 스크롤 밖.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Confirm = require(script.Parent.Parent.ui.kit.Confirm)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)

local InheritPanel = {}
InheritPanel.id = "inherit"

local PANEL_SIZE = Vector2.new(600, 430)
local PAD = 12
local PENDING_LIMIT = 4 -- 초. 서버 결과가 안 오면 입력 잠금을 푼다

local player = Players.LocalPlayer
local previewRemote = ReplicatedStorage:WaitForChild("InheritPreview")
local requestRemote = ReplicatedStorage:WaitForChild("InheritRequest")
local resultRemote = ReplicatedStorage:WaitForChild("InheritResult")

local REASON_TEXT = {
	invalid = "잘못된 요청입니다",
	no_class = "직업을 먼저 고르세요",
	not_equipped = "같은 부위에 착용 중인 장비가 없습니다",
	not_found = "가방에서 장비를 찾을 수 없습니다",
	part_mismatch = "같은 부위끼리만 계승할 수 있습니다",
	locked = "새 장비가 잠겨 있습니다 - 가방에서 잠금을 먼저 푸세요",
	a_locked = "착용 중 장비가 잠겨 있습니다 - 해제한 뒤 잠금을 풀고 다시 착용하세요",
	b_grade_lower = "새 장비 등급이 낮아 착용 장비의 옵션을 옮길 수 없습니다",
	no_gold = "골드가 부족합니다",
}
InheritPanel.reasonText = function(reason)
	return REASON_TEXT[reason] or ("계승할 수 없습니다(" .. tostring(reason) .. ")")
end

local STAT_ROWS = {
	{ key = "attack", label = "공격력", fmt = function(v) return NumberFormat.format(math.floor(v)) end },
	{ key = "defense", label = "방어력", fmt = function(v) return NumberFormat.format(math.floor(v)) end },
	{ key = "maxHp", label = "최대 체력", fmt = function(v) return NumberFormat.format(math.floor(v)) end },
	{ key = "speedPercent", label = "이동 · 공격 속도", fmt = function(v) return ("+%.1f%%"):format(v * 100) end },
	{ key = "critRate", label = "치명 확률(옵션)", fmt = function(v) return ("+%.1f%%p"):format(v * 100) end },
	{ key = "critDmg", label = "치명 피해(옵션)", fmt = function(v) return ("+%.2f"):format(v) end },
}

local built -- refs
local target -- { part, bagIndex, a, b }
local preview -- 서버 미리보기 표
local keep = "b"
local pendingSince

local function gradeColor(gradeId)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	return (visual and not visual.rainbow) and visual.color or Theme.color("textPrimary")
end

-- 옵션 세트 한 줄(그 세트가 B에 붙었을 때의 값 - 수치는 B 등급 · itemLevel로 다시 계산).
local function setText(sourceItem, onItem)
	local option = sourceItem and sourceItem.option
	if not option or not OptionData.options[option.id] then
		return "옵션 없음"
	end
	local probe = { grade = onItem.grade, itemLevel = onItem.itemLevel, option = option }
	local lines = ItemDescribe.optionLines(probe, player:GetAttribute("ClassId"))
	local texts = {}
	for _, line in ipairs(lines) do
		table.insert(texts, line.text)
	end
	local span = OptionData.rollMax - OptionData.rollMin
	return ("%s · 굴림 %d%%"):format(table.concat(texts, " · "), math.floor((option.roll - OptionData.rollMin) / span * 100 + 0.5))
end

local function refundText(refund)
	if not refund then
		return ""
	end
	if refund.kind == "gold" then
		return ("판매가 %s 골드"):format(NumberFormat.format(refund.gold))
	end
	local gem = refund.gem
	return ("%s(보석 가방) · 옵션 %s"):format(ItemDescribe.gem(gem).title, setText(gem, gem):match("^[^·]+") or "없음")
end

local function build()
	local panel = Panel.create({
		id = InheritPanel.id,
		kind = "window",
		title = "장비 계승",
		size = PANEL_SIZE,
		help = "착용 중인 장비의 옵션(종류 + 굴림 위치)을 새 장비로 옮깁니다. 수치는 새 장비의 등급 · 레벨로 다시 계산됩니다. 착용 중이던 장비는 분해 재료로 돌려받습니다.",
		onClose = function()
			target, preview, pendingSince = nil, nil, nil
		end,
	})
	local content = panel.content
	local bottomHeight = Theme.buttonHeight + PAD * 2 + Theme.textSize("caption") + 4

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, -bottomHeight)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = content

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.new(0, 0, 1, 0)
	bottom.Size = UDim2.new(1, 0, 0, bottomHeight)
	bottom.Parent = content

	local line = Theme.label(scroll, "", "body", "textPrimary")
	line.Name = "Heading"
	local lineA = Theme.label(scroll, "", "body", "textPrimary")
	lineA.Name = "ItemA"
	local lineB = Theme.label(scroll, "", "body", "textPrimary")
	lineB.Name = "ItemB"
	local chooseLabel = Theme.label(scroll, "남길 옵션 세트", "caption", "textSecondary")

	local function makeCard(name, onActivated)
		local card = Instance.new("TextButton")
		card.Name = name
		card.Text = ""
		card.AutoButtonColor = false
		card.BackgroundColor3 = Theme.color("slot")
		card.BackgroundTransparency = Theme.colors.slotTransparency
		card.Parent = scroll
		Theme.corner(card, Theme.corner.chip)
		local stroke = Theme.stroke(card)
		local title = Theme.label(card, "", "body", "textPrimary")
		title.Position = UDim2.new(0, 10, 0, 6)
		title.Size = UDim2.new(1, -20, 0, Theme.textSize("body") + 4)
		local body = Theme.label(card, "", "caption", "textSecondary")
		body.Position = UDim2.new(0, 10, 0, 8 + Theme.textSize("body") + 4)
		body.Size = UDim2.new(1, -20, 0, Theme.textSize("caption") + 4)
		local reason = Theme.label(card, "", "caption", "danger")
		reason.Position = UDim2.new(0, 10, 0, 10 + Theme.textSize("body") + Theme.textSize("caption") + 8)
		reason.Size = UDim2.new(1, -20, 0, Theme.textSize("caption") + 4)
		card.Activated:Connect(onActivated)
		return { root = card, stroke = stroke, title = title, body = body, reason = reason }
	end

	local refs = { panel = panel, scroll = scroll, heading = line, lineA = lineA, lineB = lineB, chooseLabel = chooseLabel, statRows = {} }
	refs.cardA = makeCard("KeepA", function()
		if preview and not preview.keepABlock then
			keep = "a"
			InheritPanel.render()
		end
	end)
	refs.cardB = makeCard("KeepB", function()
		if preview then
			keep = "b"
			InheritPanel.render()
		end
	end)

	refs.statHeader = Theme.label(scroll, "", "caption", "textSecondary")
	-- 0번 행 = 열 머리(능력치 · 현재 · 계승 후 · 변화) - 값 행과 같은 칸 배치.
	for index = 0, #STAT_ROWS do
		local row = STAT_ROWS[index] or { key = "Header", label = "능력치" }
		local frame = Instance.new("Frame")
		frame.Name = "Stat_" .. row.key
		frame.BackgroundTransparency = (index == 0 or index % 2 == 1) and 1 or 0.85
		frame.BackgroundColor3 = Theme.color("slot")
		frame.BorderSizePixel = 0
		frame.Parent = scroll
		local label = Theme.label(frame, row.label, "caption", "textSecondary")
		local now = Theme.label(frame, "", "caption", "textPrimary")
		now.TextXAlignment = Enum.TextXAlignment.Right
		local after = Theme.label(frame, "", "caption", "textPrimary")
		after.TextXAlignment = Enum.TextXAlignment.Right
		local delta = Theme.label(frame, "", "caption", "textSecondary")
		delta.TextXAlignment = Enum.TextXAlignment.Right
		refs.statRows[index] = { frame = frame, label = label, now = now, after = after, delta = delta }
	end
	refs.refund = Theme.label(scroll, "", "caption", "textSecondary")
	refs.refund.Name = "Refund"
	refs.refund.TextWrapped = true
	refs.status = Theme.label(scroll, "", "caption", "textSecondary")
	refs.status.Name = "Status"

	refs.cost = Theme.label(bottom, "", "body", "gold")
	refs.cost.Name = "Cost"
	refs.cost.Position = UDim2.new(0, PAD, 0, PAD)
	refs.cost.Size = UDim2.new(1, -(PAD * 3 + 240), 0, Theme.buttonHeight)
	refs.inheritButton = Button.build({
		parent = bottom,
		name = "InheritButton",
		kind = "primary",
		text = "계승",
		width = 112,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -PAD, 0, PAD),
		onActivated = function()
			InheritPanel.confirm()
		end,
	})
	refs.cancelButton = Button.build({
		parent = bottom,
		name = "CancelButton",
		kind = "secondary",
		text = "취소",
		width = 112,
		anchorPoint = Vector2.new(1, 0),
		position = UDim2.new(1, -(PAD + 112 + 8), 0, PAD),
		onActivated = function()
			InheritPanel.back()
		end,
	})
	built = refs
end

-- 폭에 맞춰 본문을 다시 놓는다(카드 두 장은 폭이 좁으면 위아래로). 행 높이는 글씨에서 나온다.
local function layoutBody()
	local refs = built
	local width = refs.scroll.AbsoluteSize.X - 8
	if width <= 0 then
		width = PANEL_SIZE.X - 8
	end
	local bodyH, captionH = Theme.textSize("body") + 6, Theme.textSize("caption") + 6
	local rowH = math.max(captionH, Theme.isMobile and 26 or 22)
	local y = PAD
	for _, label in ipairs({ refs.heading, refs.lineA, refs.lineB }) do
		label.Position = UDim2.new(0, PAD, 0, y)
		label.Size = UDim2.new(0, width - PAD * 2, 0, bodyH)
		y += bodyH + 2
	end
	y += 6
	refs.chooseLabel.Position = UDim2.new(0, PAD, 0, y)
	refs.chooseLabel.Size = UDim2.new(0, width - PAD * 2, 0, captionH)
	y += captionH + 2
	local cardH = 14 + Theme.textSize("body") + Theme.textSize("caption") * 2 + 16
	local stacked = width < 460
	local cardW = stacked and (width - PAD * 2) or math.floor((width - PAD * 3) / 2)
	refs.cardA.root.Position = UDim2.new(0, PAD, 0, y)
	refs.cardA.root.Size = UDim2.new(0, cardW, 0, cardH)
	if stacked then
		y += cardH + 8
		refs.cardB.root.Position = UDim2.new(0, PAD, 0, y)
	else
		refs.cardB.root.Position = UDim2.new(0, PAD * 2 + cardW, 0, y)
	end
	refs.cardB.root.Size = UDim2.new(0, cardW, 0, cardH)
	y += cardH + 12
	refs.statHeader.Position = UDim2.new(0, PAD, 0, y)
	refs.statHeader.Size = UDim2.new(0, width - PAD * 2, 0, captionH)
	y += captionH
	local colW = math.floor((width - PAD * 2) / 4)
	for index = 0, #refs.statRows do
		local row = refs.statRows[index]
		row.frame.Position = UDim2.new(0, PAD, 0, y)
		row.frame.Size = UDim2.new(0, width - PAD * 2, 0, rowH)
		row.label.Position, row.label.Size = UDim2.new(0, 6, 0, 0), UDim2.new(0, colW + 20, 1, 0)
		row.now.Position, row.now.Size = UDim2.new(0, colW + 20, 0, 0), UDim2.new(0, colW - 14, 1, 0)
		row.after.Position, row.after.Size = UDim2.new(0, colW * 2 + 12, 0, 0), UDim2.new(0, colW - 6, 1, 0)
		row.delta.Position, row.delta.Size = UDim2.new(0, colW * 3 + 12, 0, 0), UDim2.new(0, colW - 18, 1, 0)
		y += rowH
	end
	y += 8
	refs.refund.Position = UDim2.new(0, PAD, 0, y)
	refs.refund.Size = UDim2.new(0, width - PAD * 2, 0, captionH * 2)
	y += captionH * 2 + 2
	refs.status.Position = UDim2.new(0, PAD, 0, y)
	refs.status.Size = UDim2.new(0, width - PAD * 2, 0, captionH)
	y += captionH + PAD
	refs.scroll.CanvasSize = UDim2.new(0, 0, 0, y)
end

local function paintCard(card, selected, enabled, title, body, reason)
	card.title.Text = title
	card.body.Text = body
	card.reason.Text = reason or ""
	card.reason.Visible = reason ~= nil
	card.stroke.Color = selected and Theme.color("ember") or Theme.color("rim")
	card.stroke.Transparency = selected and 0 or Theme.colors.rimTransparency
	card.stroke.Thickness = selected and 2 or 1
	card.title.TextColor3 = enabled and Theme.color("textPrimary") or Theme.color("textTertiary")
	card.root.AutoButtonColor = false
	card.root.Active = enabled
end

function InheritPanel.render()
	if not built or not target then
		return
	end
	local refs = built
	local a, b = target.a, target.b
	refs.heading.Text = ("착용 중 %s → 새 장비"):format(ItemVisualData.partDisplayNames[b.part or "armor"] or "장비")
	local describedA = ItemDescribe.item(a, player:GetAttribute("ClassId"))
	local describedB = ItemDescribe.item(b, player:GetAttribute("ClassId"))
	-- meta의 첫 조각은 부위 이름이다(제목에 이미 있다) - 레벨 · 기본 효과만 붙인다. 문자 집합([^·])은 바이트 단위라 한글(옷 = … B7)과 섞여 못 쓴다 - 평문 find.
	local function withoutPart(meta)
		local at = meta:find(" · ", 1, true)
		return at and meta:sub(at + #" · ") or meta
	end
	refs.lineA.Text = ("A(착용) %s · %s"):format(describedA.title, withoutPart(describedA.meta))
	refs.lineA.TextColor3 = gradeColor(a.grade)
	refs.lineB.Text = ("B(새 장비) %s · %s"):format(describedB.title, withoutPart(describedB.meta))
	refs.lineB.TextColor3 = gradeColor(b.grade)

	local blockA = preview and preview.keepABlock or Inherit.keepABlockReason(a, b)
	if blockA and keep == "a" then
		keep = "b"
	end
	paintCard(refs.cardA, keep == "a", not blockA, "A 옵션 세트 남기기", setText(a, b), blockA and InheritPanel.reasonText(blockA) or nil)
	paintCard(refs.cardB, keep == "b", true, "B 옵션 세트 남기기", setText(b, b), nil)

	local stats = preview and preview.stats
	local after = stats and stats[keep]
	refs.statHeader.Text = ("최종 능력치 비교 - 계승 후 = %s 옵션 세트를 남겼을 때"):format(keep == "a" and "A" or "B")
	local header = refs.statRows[0]
	header.now.Text, header.after.Text, header.delta.Text = "현재", "계승 후", "변화"
	for _, cell in ipairs({ header.label, header.now, header.after, header.delta }) do
		cell.TextColor3 = Theme.color("textTertiary")
	end
	for index, row in ipairs(STAT_ROWS) do
		local cells = refs.statRows[index]
		local nowValue = stats and stats.current and stats.current[row.key]
		local afterValue = after and after[row.key]
		cells.now.Text = nowValue and row.fmt(nowValue) or "-"
		cells.after.Text = afterValue and row.fmt(afterValue) or "-"
		if nowValue and afterValue then
			local diff = afterValue - nowValue
			local relative = math.abs(nowValue) > 1e-9 and diff / math.abs(nowValue) or 0
			if math.abs(relative) < 1e-6 and math.abs(diff) < 1e-9 then
				cells.delta.Text = "변화 없음"
				cells.delta.TextColor3 = Theme.color("textTertiary")
			else
				cells.delta.Text = math.abs(nowValue) > 1e-9 and ("%+.1f%%"):format(relative * 100) or row.fmt(diff)
				cells.delta.TextColor3 = diff > 0 and Theme.color("success") or Theme.color("danger")
			end
		else
			cells.delta.Text = ""
		end
	end
	local refund = preview and preview.refund and preview.refund[keep]
	refs.refund.Text = refund and ("A 환급: %s"):format(refundText(refund)) or ""

	local cost, gold = preview and preview.cost, player:GetAttribute("Gold") or 0
	if cost then
		refs.cost.Text = ("비용 %s 골드(보유 %s)"):format(NumberFormat.format(cost), NumberFormat.format(gold))
		refs.cost.TextColor3 = gold >= cost and Theme.color("gold") or Theme.color("danger")
	elseif preview and preview.error then
		refs.cost.Text = "계승할 수 없습니다"
		refs.cost.TextColor3 = Theme.color("danger")
	else
		refs.cost.Text = "비용 계산 중…"
		refs.cost.TextColor3 = Theme.color("textSecondary")
	end
	local reason
	if not preview then
		reason = nil
	elseif preview.error then
		reason = InheritPanel.reasonText(preview.error)
	elseif gold < cost then
		reason = REASON_TEXT.no_gold
	end
	refs.status.Text = preview and preview.error and InheritPanel.reasonText(preview.error) or (preview and "" or "불러오는 중…")
	refs.inheritButton.setEnabled(preview ~= nil and not preview.error and gold >= cost and not pendingSince, reason)
	layoutBody()
end

local function fetchPreview()
	local requested = target
	local ok, result = pcall(function()
		return previewRemote:InvokeServer(requested.part, requested.bagIndex)
	end)
	if target ~= requested then
		return -- 그 사이 창이 닫히거나 다른 장비로 다시 열렸다
	end
	preview = ok and result or { error = "invalid" }
	InheritPanel.render()
end

-- part = 착용 부위 · bagIndex = 가방 서버 index · a · b = 지금 스냅샷의 두 장비(표시용 - 판정은 서버).
function InheritPanel.open(part, bagIndex, a, b)
	if not built then
		build()
	end
	target = { part = part, bagIndex = bagIndex, a = a, b = b }
	preview = nil
	keep = "b"
	pendingSince = nil
	built.scroll.CanvasPosition = Vector2.zero
	if not UIManager.open(InheritPanel.id) then
		target = nil
		return false
	end
	InheritPanel.render()
	task.spawn(fetchPreview)
	return true
end

-- 취소 · 결과 뒤: 이 창을 닫고 가방으로 돌아간다.
function InheritPanel.back()
	UIManager.close(InheritPanel.id)
	task.defer(function()
		UIManager.open("inventory")
	end)
end

function InheritPanel.confirm()
	if not target or not preview or preview.error or pendingSince then
		return
	end
	local chosen, requested = keep, target
	local refund = preview.refund and preview.refund[chosen]
	Confirm.ask({
		title = "계승 - 되돌릴 수 없습니다",
		body = ("A(착용 중)는 사라지고 B가 %s 옵션 세트로 착용됩니다.\nA 환급: %s\n비용: %s 골드"):format(
			chosen == "a" and "A" or "B", refundText(refund), NumberFormat.format(preview.cost)),
		primaryText = "계승",
		danger = true,
		parentId = InheritPanel.id,
	}, function(accepted)
		if not accepted or target ~= requested then
			return
		end
		pendingSince = os.clock()
		built.inheritButton.setBusy(true)
		requestRemote:FireServer(requested.part, requested.bagIndex, chosen)
		task.delay(PENDING_LIMIT, function()
			if pendingSince and os.clock() - pendingSince >= PENDING_LIMIT - 0.05 then
				pendingSince = nil
				if built then
					built.inheritButton.setBusy(false)
					InheritPanel.render()
				end
			end
		end)
	end)
end

resultRemote.OnClientEvent:Connect(function(success, reason)
	pendingSince = nil
	if built then
		built.inheritButton.setBusy(false)
	end
	if success then
		Toast.push("TC", { text = reason == "gem" and "계승 완료 - 착용 장비는 보석으로 돌려받았습니다" or "계승 완료 - 착용 장비는 골드로 돌려받았습니다", colorName = "success", seconds = 4 })
		if UIManager.isOpen(InheritPanel.id) then
			InheritPanel.back()
		end
	else
		Toast.push("TC", { text = InheritPanel.reasonText(reason), colorName = "danger", seconds = 4 })
		InheritPanel.render()
	end
end)

-- 점검용(P25b(UI) 자체 점검 · 스크린샷): 서버에 묻지 않고 합성 미리보기로 연다. 판정 · 요청 경로는 그대로(계승 버튼은 실제 요청을 보낸다 - 점검은 누르지 않는다).
function InheritPanel.debugOpen(part, bagIndex, a, b, fakePreview, keepChoice)
	if not built then
		build()
	end
	target = { part = part, bagIndex = bagIndex, a = a, b = b }
	preview = fakePreview
	keep = keepChoice or "b"
	pendingSince = nil
	if not UIManager.isOpen(InheritPanel.id) and not UIManager.open(InheritPanel.id) then
		return false
	end
	InheritPanel.render()
	return true
end

-- 점검용: 지금 상태(열림 · 선택 세트 · 미리보기 유무 · 계승 버튼 활성).
function InheritPanel.debugState()
	return {
		open = UIManager.isOpen(InheritPanel.id),
		keep = keep,
		hasPreview = preview ~= nil and not preview.error,
		error = preview and preview.error,
		refs = built,
	}
end

return InheritPanel
