-- 메뉴바(S16, PRD 20.81 [D-2] · [D-1]). 화면 왼쪽 세로 중앙의 세로 1열 - 칸 = PanelRegistry의 menuOrder 항목(지금은 가방 · 파티 · 스테이지 선택, 상한 5). 누르면 UIManager.switchTo(열려 있으면 닫고 · 다른 창이 열려 있으면 그 창을 닫고 연다 - S17 사전 작업)이고 단축키는 PanelRegistry가 이미 문다 -
-- 이 파일은 단축키 표를 따로 갖지 않는다(라벨도 PanelRegistry의 hotkey 이름에서 읽는다). 빈 버튼은 만들지 않는다: 상점 · 펫 · 보상은 그 창을 등록하는 세션이 표에 한 줄 넣으면 칸이 생긴다.
--   · 열린 패널의 버튼 = ember 테두리(UIManager.changed를 듣는다 - 단축키 · 다른 버튼 · 밀려 닫힘 모두).
--   · 전환을 막는 이유가 있는 버튼(UIManager.switchBlockedReason: 확인창(overlay)이 떠 있다 · 그 창의 canOpen이 막는다) = 회색(lockedBg · lockedIcon). 눌러도 받고 이유를 TC 토스트로 낸다(같은 글 3초에 한 번).
--   · PC는 버튼 오른쪽 위에 단축키 글자(caption 12 · textSecondary), 모바일은 없다. 첫 접속 8초 동안만 버튼 오른쪽에 이름표를 띄운다(저장 없음 - 이 스크립트가 도는 동안의 메모리뿐).
--   · 가방 버튼에 빨간 점(Badge) - 서버의 InventoryFull 신호(가방이 가득이라 줍기 실패)를 들으면 켜지고 가방을 열면 꺼진다. 그 밖의 배지 규칙은 없다.
--   · 견습 중 · 직업 선택 전에는 PanelRegistry의 menuHiddenWhile을 가진 칸(스테이지)이 숨는다 - 가방 · 파티는 보인다. 숨으면 남은 칸이 세로 중앙에서 다시 정렬된다.
--   · 모바일은 아래 끝이 BL 터치 예약 구역에 닿으면 ScreenMap.mobileMenuBarShiftUp만큼(겹침 0이 되는 최소 이동) 위로 민다.
-- 파티 목록은 이 바 오른쪽 옆으로 옮겼다(ScreenMap ML.partyList - hud/PartyListView가 place로 받는다). 기존 열기 버튼(가방 · 파티 · 스테이지 칩)은 그대로 둔다 - 중복 허용(지시).
-- 자체 점검(`[S16][UI]`)은 이 파일 끝에 있다: Studio에서 DevToolsConfig.verify에 "S16(UI)"가 있을 때만(또는 회귀 전체).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudIcons = require(script.Parent.Parent.HudIcons)
local PanelRegistry = require(script.Parent.Parent.ui.PanelRegistry)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Badge = require(script.Parent.Parent.ui.kit.Badge)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Confirm = require(script.Parent.Parent.ui.kit.Confirm)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local inventoryFull = ReplicatedStorage:WaitForChild("InventoryFull")

local ICON_SIZE = 26 -- 아이콘 캔버스(PC · 모바일 같다 - 버튼 안 자리만 다르다)
local NAME_TAG_SECONDS = 8
local NAME_TAG_HEIGHT = 28
local BADGE_PANEL = "inventory" -- 빨간 점이 붙는 칸

-- menuHiddenWhile 조건 이름 → (Player처럼 GetAttribute를 가진 것) → 지금 참인가. 자체 점검이 가짜 Player 표를 넣어 직업 선택 전 조건도 잰다(진짜 ClassId를 바꾸면 직업 선택창이 뜬다).
local HIDE_CONDITIONS = {
	tutorial = function(who)
		return who:GetAttribute("TutorialCompleted") ~= true and (who:GetAttribute("TutorialStep") or 0) > 0
	end,
	noClass = function(who)
		local classId = who:GetAttribute("ClassId")
		return classId == nil or classId == ""
	end,
}

local function isHidden(entry, who)
	for _, name in ipairs(entry.menuHiddenWhile or {}) do
		if HIDE_CONDITIONS[name](who or player) then
			return true
		end
	end
	return false
end

local function buttonSize()
	return Theme.isMobile and ScreenMap.menuBar.mobileButton or ScreenMap.menuBar.button
end

-- 열림(ember 테두리) · 비활성(회색: 전환을 막는 이유가 있다 - 확인창이 떠 있다 · canOpen이 막는다). 비활성이 열림보다 우선한다. 비활성이어도 눌림은 받는다(이유를 토스트로 알린다).
local function applyLook(item)
	local open = UIManager.isOpen(item.entry.id)
	local blocked = UIManager.switchBlockedReason(item.entry.id) ~= nil
	item.stroke.Color = blocked and UIColors.lockedRim or open and UIColors.ember or UIColors.rim
	item.stroke.Transparency = blocked and 0.3 or open and 0 or UIColors.rimTransparency
	item.stroke.Thickness = not blocked and open and 2 or 1
	item.button.BackgroundColor3 = blocked and UIColors.lockedBg or UIColors.slot
	item.button.BackgroundTransparency = blocked and 0 or UIColors.slotTransparency
	for frame, color in pairs(item.iconColors) do
		frame.BackgroundColor3 = blocked and UIColors.lockedIcon or color
	end
	item.letter.TextColor3 = blocked and UIColors.lockedIcon or UIColors.textSecondary
	item.blocked = blocked
end

-- 막힌 이유 토스트(TC 줄). 같은 글은 3초에 한 번만(연타해도 "×3"이 쌓이지 않는다).
local BLOCKED_TOAST_GAP = 3
local lastBlockedToast = { text = nil, at = 0 }
local function notifyBlocked(text)
	local now = os.clock()
	if lastBlockedToast.text == text and now - lastBlockedToast.at < BLOCKED_TOAST_GAP then
		return
	end
	lastBlockedToast.text, lastBlockedToast.at = text, now
	Toast.push("TC", { text = text, colorName = "textPrimary" })
end

-- 버튼을 누른 처리(Activated와 자체 점검이 같은 함수를 부른다): UIManager.switchTo가 전환하거나, 막혔으면 이유를 토스트로 낸다.
local function onButtonPressed(id)
	local ok, text = UIManager.switchTo(id)
	if not ok and text then
		notifyBlocked(text)
	end
	return ok, text
end

-- 첫 접속 이름표(버튼 오른쪽) - 버튼의 자식이라 버튼이 숨으면 같이 숨는다. 8초 뒤 지운다.
local function showNameTags(items)
	for _, item in ipairs(items) do
		local text = item.entry.menuLabel or item.entry.id
		local width = TextService:GetTextSize(text, Theme.textSize("body"), Theme.font, Vector2.new(400, 100)).X + 20
		local tag = Instance.new("TextLabel")
		tag.Name = "NameTag"
		tag.AnchorPoint = Vector2.new(0, 0.5)
		tag.Position = UDim2.new(1, 8, 0.5, 0)
		tag.Size = UDim2.new(0, width, 0, Theme.isMobile and Theme.touchMin - 12 or NAME_TAG_HEIGHT)
		tag.BackgroundColor3 = UIColors.panel
		tag.BackgroundTransparency = UIColors.panelTransparency
		tag.Font = Theme.font
		tag.TextSize = Theme.textSize("body")
		tag.TextColor3 = UIColors.textPrimary
		tag.Text = text
		tag.Parent = item.button
		Theme.corner(tag, Theme.corner.chip)
		Theme.stroke(tag)
		task.delay(NAME_TAG_SECONDS, function()
			tag:Destroy()
		end)
	end
end

-- 메뉴바를 짓고 참조를 refs 표 하나로 돌려준다(Luau 레지스터 한계 - 인스턴스는 이 함수 안에서만 만든다).
local function build()
	local refs = { items = {} }

	local gui = Instance.new("ScreenGui")
	gui.Name = "MenuBarGui"
	gui.ResetOnSpawn = false
	-- window(DisplayOrder 100 ~ 149)의 딤이 화면을 덮어도 메뉴바는 눌려야 한다("열린 버튼을 다시 누르면 닫힌다" · 창 → 창 전환) - window 대역 바로 위, overlay(200 ~ 249 - 확인창) 아래.
	-- 실제 클릭으로 확인한 결함이다: 4일 때는 딤이 클릭을 먹어 열림 표시가 켜진 버튼을 눌러도 안 닫혔다. 창은 720 폭 상한이라 바(x 14 ~ 62)와 겹치는 것은 화면 폭 780 미만일 때 가장자리뿐이다.
	gui.DisplayOrder = 150
	gui.Parent = player:WaitForChild("PlayerGui")
	refs.gui = gui

	local bar = Instance.new("Frame")
	bar.Name = "MenuBar"
	ScreenMap.place(bar, "ML", "menuBar")
	bar.Size = UDim2.new(0, 0, 0, 0)
	bar.BackgroundTransparency = 1
	bar.Parent = gui
	refs.bar = bar

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.Padding = UDim.new(0, ScreenMap.menuBar.gap)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar

	for _, entry in ipairs(PanelRegistry.menuEntries()) do
		local button = Instance.new("TextButton")
		button.Name = "MenuButton_" .. entry.id
		button.LayoutOrder = entry.menuOrder
		button.AutoButtonColor = false
		button.Text = ""
		button.BackgroundColor3 = UIColors.slot
		button.BackgroundTransparency = UIColors.slotTransparency
		button.Parent = bar
		Theme.corner(button, Theme.corner.button)
		local stroke = Theme.stroke(button)

		local icon = HudIcons[entry.iconKey](button, ICON_SIZE, UIColors.textPrimary)
		icon.Name = "Icon"

		local letter = Instance.new("TextLabel")
		letter.Name = "Hotkey"
		letter.AnchorPoint = Vector2.new(1, 0)
		letter.Position = UDim2.new(1, -4, 0, 2)
		letter.Size = UDim2.new(0, 14, 0, 14)
		letter.BackgroundTransparency = 1
		letter.Font = Theme.fontBody
		letter.TextSize = Theme.text.caption
		letter.TextColor3 = UIColors.textSecondary
		letter.TextXAlignment = Enum.TextXAlignment.Right
		letter.Text = entry.hotkey and entry.hotkey.Name or ""
		letter.Parent = button

		local item = { entry = entry, button = button, stroke = stroke, icon = icon, letter = letter, iconColors = {}, blocked = false }
		for _, part in ipairs(icon:GetDescendants()) do
			if part:IsA("Frame") then
				item.iconColors[part] = part.BackgroundColor3 -- 비활성 회색에서 되돌릴 원래 색
			end
		end
		if entry.id == BADGE_PANEL then
			item.badge = Badge.build({
				parent = button, kind = "dot", name = "FullBadge",
				anchorPoint = Vector2.new(0.5, 0.5), position = UDim2.new(1, -6, 1, -6),
			})
		end
		button.Activated:Connect(function()
			onButtonPressed(entry.id)
		end)
		table.insert(refs.items, item)
	end
	return refs
end

local refs = build()

-- 버튼 크기(PC 44 · 모바일 48) · 아이콘 자리 · 단축키 글자(PC만). 모바일 판정이 바뀌면(Studio ForceTouchLayout) 다시 부른다.
local function applyMetrics()
	local size = buttonSize()
	for _, item in ipairs(refs.items) do
		item.button.Size = UDim2.new(0, size, 0, size)
		if Theme.isMobile then
			item.icon.Position = UDim2.new(0, (size - ICON_SIZE) / 2, 0, (size - ICON_SIZE) / 2)
		else
			-- 오른쪽 위 모서리(단축키 글자)를 피해 왼쪽 아래로 3px씩.
			item.icon.Position = UDim2.new(0, (size - ICON_SIZE) / 2 - 3, 0, (size - ICON_SIZE) / 2 + 3)
		end
		item.letter.Visible = not Theme.isMobile
	end
end

local function refreshLook()
	for _, item in ipairs(refs.items) do
		applyLook(item)
	end
end

-- 보이는 칸 수로 바 크기를 다시 재고(고정 크기) 세로 중앙 · 모바일 위로 밀기를 적용한다.
local function relayout()
	local size = buttonSize()
	local count = 0
	for _, item in ipairs(refs.items) do
		local hidden = isHidden(item.entry)
		item.button.Visible = not hidden
		if not hidden then
			count += 1
		end
	end
	local height = count > 0 and count * size + (count - 1) * ScreenMap.menuBar.gap or 0
	refs.bar.Size = UDim2.new(0, size, 0, height)
	local placed = ScreenMap.slot("ML", "menuBar")
	local shift = Theme.isMobile and ScreenMap.mobileMenuBarShiftUp(refs.gui.AbsoluteSize.Y, height) or 0
	refs.bar.Position = UDim2.new(placed.position.X.Scale, placed.position.X.Offset, placed.position.Y.Scale, placed.position.Y.Offset - shift)
	refreshLook() -- 견습 · 직업 선택 속성이 바뀌면 canOpen 막힘(회색)도 달라진다
end

local function findItem(id)
	for _, item in ipairs(refs.items) do
		if item.entry.id == id then
			return item
		end
	end
	return nil
end

-- 가방이 가득이라 줍기 실패(InventoryFull) → 가방 버튼의 점. 가방을 열면 꺼진다.
local function onBagFull()
	local item = findItem(BADGE_PANEL)
	if item and item.badge then
		item.badge.setCount(1)
	end
end

applyMetrics()
relayout()
refreshLook()
showNameTags(refs.items)

UIManager.changed:Connect(function(id, isOpen)
	refreshLook()
	local item = findItem(id)
	if item and item.badge and isOpen then
		item.badge.setCount(0)
	end
end)
inventoryFull.OnClientEvent:Connect(onBagFull)
refs.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(relayout)
for _, name in ipairs({ "TutorialCompleted", "TutorialStep", "ClassId" }) do
	player:GetAttributeChangedSignal(name):Connect(relayout)
end
-- Studio에서 폰 화면을 흉내 낼 때(ForceTouchLayout)만: 모바일 판정을 다시 재고 메뉴바 크기 · 자리를 바꾼다. 실제 기기에서는 판정이 접속 때 정해진다.
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
		Theme.recompute()
		applyMetrics()
		relayout()
	end)
	-- 스크린샷용: 이름표(첫 8초)를 다시 띄운다. Attribute ShowMenuBarTags = true를 넣으면 한 번 띄우고 지운다.
	player:GetAttributeChangedSignal("ShowMenuBarTags"):Connect(function()
		if player:GetAttribute("ShowMenuBarTags") then
			player:SetAttribute("ShowMenuBarTags", nil)
			showNameTags(refs.items)
		end
	end)
end

-- ═══ 자체 점검 [S16][UI] (Studio · verify에 "S16(UI)"가 있을 때) ═══
-- 다른 클라 점검(PanelFitCheck 10초 · S10 12초 · StageSelectCheck 30초 · SocialSelfCheck 50초)이 끝난 뒤에 돈다. 로컬 Attribute(Tutorial* · ClassId)를 잠깐 바꾸고 끝에 되돌린다.
-- 클릭 · 실제 키 입력은 여기서 못 한다 - 별도 Play에서 MCP로 확인한다. 버튼 Activated는 onButtonPressed(→ UIManager.switchTo)를 부를 뿐이라 여기서는 같은 함수로 대신한다(창 → 창 전환 · 막힘 토스트까지).
local CHECK_DELAY = 75

local function selfCheck()
	local pass, total = 0, 0
	print("===S16 검증 시작(UI: 메뉴바 · 단축키 표 · 파티 목록 자리)===")
	local function check(label, passed)
		total += 1
		if passed then
			pass += 1
		end
		print(("[S16][UI] %s %s"):format(label, passed and "O" or "X"))
	end
	local function screenPosition(inst)
		return inst.AbsolutePosition - refs.gui.AbsolutePosition
	end

	local touched = { "TutorialCompleted", "TutorialStep" }
	local saved = {}
	for index, name in ipairs(touched) do
		saved[index] = player:GetAttribute(name)
	end
	local ok, err = pcall(function()
		player:SetAttribute("TutorialCompleted", true)
		UIManager.closeAll()
		task.wait(0.3)
		relayout()
		task.wait(0.2)

		-- 1. 표
		local entries = PanelRegistry.menuEntries()
		local ids = {}
		for _, entry in ipairs(entries) do
			table.insert(ids, ("%s(%s)"):format(entry.id, entry.hotkey and entry.hotkey.Name or "-"))
		end
		check(("등록 표: 메뉴 칸 %s(기대 inventory(I) · party(P) · stageSelect(M) 순) · 칸 상한 %d"):format(table.concat(ids, " · "), PanelRegistry.menuSlotLimit),
			#entries == 3 and entries[1].id == "inventory" and entries[1].hotkey == Enum.KeyCode.I and entries[2].id == "party" and entries[2].hotkey == Enum.KeyCode.P
				and entries[3].id == "stageSelect" and entries[3].hotkey == Enum.KeyCode.M and PanelRegistry.menuSlotLimit == 5)
		-- 6번째 칸 · 금지 키 · 겹치는 키는 error(합성 표를 같은 validate에 넣는다)
		local six = {}
		for index = 1, 6 do
			table.insert(six, { id = "dummy" .. index, menuOrder = index })
		end
		local okSix, errSix = pcall(PanelRegistry.validate, six)
		local okFive = pcall(PanelRegistry.validate, { table.unpack(six, 1, 5) })
		local okKey, errKey = pcall(PanelRegistry.validate, { { id = "a", hotkey = Enum.KeyCode.W } })
		local okDup, errDup = pcall(PanelRegistry.validate, { { id = "a", hotkey = Enum.KeyCode.O }, { id = "b", hotkey = Enum.KeyCode.O } })
		check(("칸 6개 = error %s · 5개 = 통과 %s · 금지 키(W) = error %s · 같은 키 두 번 = error %s (메시지: %s | %s)"):format(
			tostring(not okSix and tostring(errSix):find("보상 창의 탭") ~= nil), tostring(okFive), tostring(not okKey and tostring(errKey):find("금지 키") ~= nil),
			tostring(not okDup and tostring(errDup):find("겹친다") ~= nil), tostring(errSix):sub(1, 50), tostring(errKey):sub(1, 40)),
			not okSix and tostring(errSix):find("보상 창의 탭") ~= nil and okFive and not okKey and tostring(errKey):find("금지 키") ~= nil and not okDup and tostring(errDup):find("겹친다") ~= nil)

		-- 2. 모양: 크기 · 간격 · 왼쪽 14 · 세로 중앙 · 아이콘 · 글씨 · 터치
		local size = buttonSize()
		local shown = {}
		for _, item in ipairs(refs.items) do
			if item.button.Visible then
				table.insert(shown, item)
			end
		end
		local gaps, sizeOk, touchOk, iconOk, letterOk = {}, true, true, true, true
		for index, item in ipairs(shown) do
			local abs = item.button.AbsoluteSize
			sizeOk = sizeOk and abs.X == size and abs.Y == size
			touchOk = touchOk and abs.X >= Theme.touchMin and abs.Y >= Theme.touchMin
			local frames = 0
			for _, part in ipairs(item.icon:GetChildren()) do
				if part:IsA("Frame") then
					frames += 1
					local pos, sz = part.AbsolutePosition, part.AbsoluteSize
					iconOk = iconOk and pos.X >= item.button.AbsolutePosition.X - 0.5 and pos.Y >= item.button.AbsolutePosition.Y - 0.5
						and pos.X + sz.X <= item.button.AbsolutePosition.X + abs.X + 0.5 and pos.Y + sz.Y <= item.button.AbsolutePosition.Y + abs.Y + 0.5
				end
			end
			iconOk = iconOk and frames >= 5
			if not Theme.isMobile then
				letterOk = letterOk and item.letter.Visible and Theme.effectiveTextSize(item.letter) >= Theme.minTextSize and item.letter.Text ~= ""
			else
				letterOk = letterOk and not item.letter.Visible
			end
			if shown[index + 1] then
				table.insert(gaps, shown[index + 1].button.AbsolutePosition.Y - (item.button.AbsolutePosition.Y + abs.Y))
			end
		end
		local barPos, barSize = screenPosition(refs.bar), refs.bar.AbsoluteSize
		local centerOffset = math.abs((barPos.Y + barSize.Y / 2) - refs.gui.AbsoluteSize.Y / 2)
		local gapText = {}
		local gapsOk = true
		for _, gap in ipairs(gaps) do
			table.insert(gapText, ("%.0f"):format(gap))
			gapsOk = gapsOk and math.abs(gap - ScreenMap.menuBar.gap) < 0.5
		end
		check(("모양(%s): 보이는 칸 %d · 버튼 %d × %d(기대 %d) · 간격 %s(기대 %d) · 왼쪽 %.0f(기대 %d) · 세로 중앙에서 %.1f px(모바일이면 위로 민 값) · 아이콘 도형 5개 이상 · 안 넘침 %s · 단축키 글씨(PC 실효 ≥ 12 · 모바일 없음) %s · 터치 ≥ 44 %s"):format(
			Theme.isMobile and "모바일" or "PC", #shown, shown[1] and shown[1].button.AbsoluteSize.X or -1, shown[1] and shown[1].button.AbsoluteSize.Y or -1, size, table.concat(gapText, "/"), ScreenMap.menuBar.gap,
			barPos.X, ScreenMap.edgeMargin, centerOffset, tostring(iconOk), tostring(letterOk), tostring(touchOk)),
			#shown == 3 and sizeOk and gapsOk and math.abs(barPos.X - ScreenMap.edgeMargin) < 0.5 and (Theme.isMobile or centerOffset < 1) and iconOk and letterOk and touchOk)

		-- 창 딤 위 · 확인창(overlay) 아래(실제 클릭은 별도 Play가 확인한다)
		local windowTop = 149
		local overlayBottom = 200
		check(("메뉴바 DisplayOrder %d(기대 window 대역 149 초과 · overlay 200 미만 - 창 딤이 덮어도 눌린다 · 확인창은 메뉴바를 덮는다)"):format(refs.gui.DisplayOrder), refs.gui.DisplayOrder > windowTop and refs.gui.DisplayOrder < overlayBottom)

		-- 3. 열림 표시(ember 테두리) · window ↔ station 규칙
		local looks = {}
		local looksOk = true
		for _, item in ipairs(refs.items) do
			UIManager.toggle(item.entry.id)
			task.wait(0.3)
			local openedLook = item.stroke.Color == UIColors.ember and item.stroke.Thickness == 2 and UIManager.isOpen(item.entry.id)
			local othersRim = true
			for _, other in ipairs(refs.items) do
				if other ~= item and other.stroke.Color ~= UIColors.rim then
					othersRim = false
				end
			end
			UIManager.toggle(item.entry.id)
			task.wait(0.3)
			local closedLook = item.stroke.Color == UIColors.rim and item.stroke.Thickness == 1 and not UIManager.isOpen(item.entry.id)
			table.insert(looks, ("%s 열림 %s · 다른 칸 그대로 %s · 닫힘 %s"):format(item.entry.id, tostring(openedLook), tostring(othersRim), tostring(closedLook)))
			looksOk = looksOk and openedLook and othersRim and closedLook
		end
		check(("토글 표시(UIManager.toggle - 버튼 Activated와 같은 호출): %s(기대 전부 true)"):format(table.concat(looks, " | ")), looksOk)

		UIManager.closeAll()
		task.wait(0.3)
		UIManager.toggle("stageSelect")
		task.wait(0.3)
		local stageItem, bagItem = findItem("stageSelect"), findItem("inventory")
		UIManager.toggle("inventory") -- station이 열린 채 window를 열면 station이 닫히고 window가 열린다
		task.wait(0.4)
		local windowWins = not UIManager.isOpen("stageSelect") and UIManager.isOpen("inventory") and stageItem.stroke.Color == UIColors.rim and bagItem.stroke.Color == UIColors.ember
		local stageBlocked = UIManager.open("stageSelect") == false and not UIManager.isOpen("stageSelect") -- window가 열려 있으면 station은 안 열린다(20.81 [D-1])
		UIManager.closeAll()
		task.wait(0.3)
		check(("규칙 그대로: 스테이지(station)를 연 채 가방(window) → 스테이지 닫힘 · 가방 열림 · 테두리 %s / 가방을 연 채 스테이지 → 안 열림 %s(기대 true · true)"):format(tostring(windowWins), tostring(stageBlocked)), windowWins and stageBlocked)

		-- 3b. 전환(S17 사전 작업 - S16 결정 2): 버튼 Activated가 부르는 onButtonPressed로 잰다. 창 → 스테이지 · 스테이지 → 가방 · 창 → 창 · 막힘(회색 + 토스트)
		local function settle()
			task.wait(0.4)
		end
		local partyItem = findItem("party")
		UIManager.closeAll()
		settle()
		onButtonPressed("inventory")
		settle()
		local windowToStage = onButtonPressed("stageSelect")
		settle()
		local switchedToStage = windowToStage and UIManager.isOpen("stageSelect") and not UIManager.isOpen("inventory")
			and stageItem.stroke.Color == UIColors.ember and bagItem.stroke.Color == UIColors.rim and not stageItem.blocked and not bagItem.blocked
		onButtonPressed("party") -- station이 열린 채 window(파티) 버튼: 스테이지가 닫히고 파티가 열린다
		settle()
		local stageToParty = UIManager.isOpen("party") and not UIManager.isOpen("stageSelect")
		onButtonPressed("inventory") -- window → window
		settle()
		local windowToWindow = UIManager.isOpen("inventory") and not UIManager.isOpen("party") and #UIManager.getStack() == 1
		onButtonPressed("inventory") -- 열린 버튼을 다시 누르면 닫힌다
		settle()
		local closedAgain = #UIManager.getStack() == 0
		check(("전환: 가방 → 스테이지 버튼 = 가방 닫히고 스테이지 열림 %s · 스테이지 → 파티 버튼 %s · 파티 → 가방 버튼(window → window, 스택 1개) %s · 열린 버튼 다시 = 닫힘 %s(기대 전부 true)"):format(
			tostring(switchedToStage), tostring(stageToParty), tostring(windowToWindow), tostring(closedAgain)),
			switchedToStage and stageToParty and windowToWindow and closedAgain)

		-- 막힘 (1) overlay(확인창)가 떠 있다: 세 버튼 전부 회색 · 눌러도 안 열리고 이유 토스트
		Toast.clear()
		lastBlockedToast.text = nil
		Confirm.ask({ title = "자체 점검", body = "메뉴바 비활성 확인" }, function() end)
		settle()
		local allGray, noneBlockedOpen = true, true
		for _, item in ipairs(refs.items) do
			allGray = allGray and item.blocked and item.stroke.Color == UIColors.lockedRim and item.button.BackgroundColor3 == UIColors.lockedBg
		end
		local pressedOk, pressedText = onButtonPressed("inventory")
		settle()
		noneBlockedOpen = not pressedOk and not UIManager.isOpen("inventory") and UIManager.isOpen(Confirm.id)
		local overlayToast = table.concat(Toast.debugTexts("TC"), "|")
		local overlayToastOk = overlayToast:find(UIManager.blockedTexts.overlay, 1, true) ~= nil
		local iconGray = true
		for frame in pairs(bagItem.iconColors) do
			iconGray = iconGray and frame.BackgroundColor3 == UIColors.lockedIcon
		end
		UIManager.close(Confirm.id, true)
		settle()
		local restored = true
		for _, item in ipairs(refs.items) do
			restored = restored and not item.blocked and item.stroke.Color == UIColors.rim and item.button.BackgroundColor3 == UIColors.slot
		end
		for frame, color in pairs(bagItem.iconColors) do
			restored = restored and frame.BackgroundColor3 == color
		end
		check(("막힘 ① 확인창(overlay): 세 버튼 회색 %s · 아이콘 회색 %s · 눌러도 안 열림(확인창 그대로) %s · 토스트 '%s' %s · 확인창이 닫히면 원래 모양 %s(기대 전부 true - 실제 마우스는 딤이 먼저 먹는다: 클릭 재현은 별도 Play)"):format(
			tostring(allGray), tostring(iconGray), tostring(noneBlockedOpen), tostring(pressedText), tostring(overlayToastOk), tostring(restored)),
			allGray and iconGray and noneBlockedOpen and overlayToastOk and restored)

		-- 막힘 (2) canOpen(견습 중 스테이지 선택): 눌러도 안 열리고 이유 토스트 · 스테이지 버튼만 회색(버튼은 원래 견습 중 숨는다 - 그 숨김을 잠깐 무시하고 상태만 잰다)
		Toast.clear()
		lastBlockedToast.text = nil
		player:SetAttribute("TutorialCompleted", false)
		player:SetAttribute("TutorialStep", 2)
		settle()
		local tutorialOk, tutorialText = onButtonPressed("stageSelect")
		settle()
		local stageGray = stageItem.blocked and not bagItem.blocked and not partyItem.blocked
		local tutorialToast = table.concat(Toast.debugTexts("TC"), "|")
		local tutorialToastOk = tutorialToast:find("견습 중에는 스테이지를 고를 수 없습니다", 1, true) ~= nil
		onButtonPressed("stageSelect") -- 같은 글은 3초에 한 번만
		local stackedOnce = #Toast.debugTexts("TC") == 1
		player:SetAttribute("TutorialCompleted", true)
		player:SetAttribute("TutorialStep", saved[2])
		settle()
		local stageBack = not stageItem.blocked
		Toast.clear()
		check(("막힘 ② canOpen(견습): 안 열림 %s · 스테이지만 회색 %s · 토스트 '%s' %s · 연타해도 1개 %s · 견습이 끝나면 회색 풀림 %s(기대 전부 true)"):format(
			tostring(not tutorialOk and not UIManager.isOpen("stageSelect")), tostring(stageGray), tostring(tutorialText), tostring(tutorialToastOk), tostring(stackedOnce), tostring(stageBack)),
			not tutorialOk and not UIManager.isOpen("stageSelect") and stageGray and tutorialToastOk and stackedOnce and stageBack)
		UIManager.closeAll()
		settle()

		-- 4. 배지(가방 버튼만)
		local badgeOff = bagItem.badge.root.Visible == false
		onBagFull()
		local badgeOn = bagItem.badge.root.Visible == true
		local otherBadge = false
		for _, item in ipairs(refs.items) do
			otherBadge = otherBadge or (item ~= bagItem and item.badge ~= nil)
		end
		UIManager.toggle("inventory")
		task.wait(0.4)
		local badgeCleared = bagItem.badge.root.Visible == false
		UIManager.closeAll()
		task.wait(0.3)
		check(("가득 배지: 처음 꺼짐 %s · InventoryFull 처리 뒤 켜짐 %s · 가방 버튼에만 있음 %s · 가방을 열면 꺼짐 %s(기대 true · true · true · true)"):format(tostring(badgeOff), tostring(badgeOn), tostring(not otherBadge), tostring(badgeCleared)),
			badgeOff and badgeOn and not otherBadge and badgeCleared)

		-- 5. 숨김: 견습 중 · 직업 선택 전 → 스테이지 칸만 숨고 남은 칸이 다시 정렬된다
		player:SetAttribute("TutorialCompleted", false)
		player:SetAttribute("TutorialStep", 2)
		task.wait(0.3)
		local hiddenByTutorial = not stageItem.button.Visible and bagItem.button.Visible and findItem("party").button.Visible
		local tutorialHeight = refs.bar.AbsoluteSize.Y
		player:SetAttribute("TutorialCompleted", true)
		player:SetAttribute("TutorialStep", saved[2])
		task.wait(0.3)
		-- 직업 선택 전(ClassId 비어 있음)은 가짜 Player 표로 같은 조건 함수를 잰다.
		local function fakePlayer(classId)
			return { GetAttribute = function(_, name) return name == "ClassId" and classId or nil end }
		end
		local stageEntry = stageItem.entry
		local hiddenByNoClass = isHidden(stageEntry, fakePlayer("")) and isHidden(stageEntry, fakePlayer(nil)) and not isHidden(stageEntry, fakePlayer("bow"))
			and not isHidden(bagItem.entry, fakePlayer("")) and not isHidden(findItem("party").entry, fakePlayer(""))
		local shownAgain = stageItem.button.Visible and refs.bar.AbsoluteSize.Y == 3 * size + 2 * ScreenMap.menuBar.gap
		check(("숨김: 견습 중 스테이지 숨음 %s(바 높이 %.0f - 기대 %d) · 직업 선택 전(가짜 Player 표) 스테이지만 숨음 %s · 돌아오면 다시 보이고 높이 %.0f(기대 %d) %s"):format(
			tostring(hiddenByTutorial), tutorialHeight, 2 * size + ScreenMap.menuBar.gap, tostring(hiddenByNoClass), refs.bar.AbsoluteSize.Y, 3 * size + 2 * ScreenMap.menuBar.gap, tostring(shownAgain)),
			hiddenByTutorial and tutorialHeight == 2 * size + ScreenMap.menuBar.gap and hiddenByNoClass and shownAgain)

		-- 6. 파티 목록: 메뉴바 오른쪽 옆(x = 14 + 48 + 8)
		local partyList = player.PlayerGui:FindFirstChild("PartyHudGui") and player.PlayerGui.PartyHudGui:FindFirstChild("PartyList")
		local listX = partyList and screenPosition(partyList).X or -1
		local expectX = ScreenMap.edgeMargin + 48 + 8
		local barRight = barPos.X + barSize.X
		check(("파티 목록 자리: x %.0f(기대 %d = 14 + 48 + 8) · 메뉴바 오른쪽 끝 %.0f + 8 = %.0f 이상 %s · 세로 앵커 중앙 %s"):format(
			listX, expectX, barRight, barRight + 8, tostring(listX >= barRight + 8 - 0.5), tostring(partyList ~= nil and partyList.AnchorPoint.Y == 0.5 and partyList.Position.Y.Scale == 0.5)),
			partyList ~= nil and math.abs(listX - expectX) < 0.5 and listX >= barRight + 8 - 0.5 and partyList.AnchorPoint.Y == 0.5 and partyList.Position.Y.Scale == 0.5)

		-- 7. 다른 HUD와 안 겹침(ScreenMap 슬롯 표에 이름이 있는 보이는 인스턴스 전부 - 파티 목록 자신은 위에서 봤다)
		local function isShownGui(inst)
			local node = inst
			while node and node ~= game do
				if node:IsA("GuiObject") and not node.Visible then
					return false
				end
				if node:IsA("ScreenGui") then
					return node.Enabled
				end
				node = node.Parent
			end
			return false
		end
		local barRect = { min = refs.bar.AbsolutePosition, max = refs.bar.AbsolutePosition + refs.bar.AbsoluteSize }
		local hits = {}
		local names = {}
		for _, _, slot in ScreenMap.each() do
			if slot.instanceName and slot.instanceName ~= "MenuBar" and slot.instanceName ~= "PartyList" then
				names[slot.instanceName] = true
			end
		end
		for _, inst in ipairs(player.PlayerGui:GetDescendants()) do
			if inst:IsA("GuiObject") and names[inst.Name] and isShownGui(inst) and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 then
				local a, b = inst.AbsolutePosition, inst.AbsolutePosition + inst.AbsoluteSize
				if a.X < barRect.max.X and barRect.min.X < b.X and a.Y < barRect.max.Y and barRect.min.Y < b.Y then
					table.insert(hits, inst.Name)
				end
			end
		end
		local center = ScreenMap.centerRect(refs.gui.AbsoluteSize)
		local inCenter = barRect.min.X - refs.gui.AbsolutePosition.X < center.max.X and center.min.X < barRect.max.X - refs.gui.AbsolutePosition.X
			and barRect.min.Y - refs.gui.AbsolutePosition.Y < center.max.Y and center.min.Y < barRect.max.Y - refs.gui.AbsolutePosition.Y
		check(("메뉴바 겹침: 표의 다른 HUD와 겹친 것 %d개 [%s](기대 0) · C 구역(전투 시야) 침범 %s(기대 false)"):format(#hits, table.concat(hits, ", "), tostring(inCenter)), #hits == 0 and not inCenter)

		-- 8. 모바일 위로 밀기: 폰 가로 높이들에서 3칸 바의 아래 끝이 BL 예약 구역 위 끝(0.55H)을 안 넘고 위 끝이 여백 안. 5칸(상한)은 알려진 한계를 참고로 찍는다.
		local mobileParts, mobileOk = {}, true
		for _, height in ipairs({ 320, 360, 375, 388, 414, 540 }) do
			local barHeight = 3 * ScreenMap.menuBar.mobileButton + 2 * ScreenMap.menuBar.gap
			local shift = ScreenMap.mobileMenuBarShiftUp(height, barHeight)
			local bottom = height / 2 + barHeight / 2 - shift
			local top = height / 2 - barHeight / 2 - shift
			local good = bottom <= height * ScreenMap.mobileReserved.BL.top + 1e-6 and top >= ScreenMap.menuBar.topMargin - 1e-6
			mobileOk = mobileOk and good
			table.insert(mobileParts, ("H%d 위로 %.0f → 위 %.0f · 아래 %.0f ≤ %.0f %s"):format(height, shift, top, bottom, height * ScreenMap.mobileReserved.BL.top, good and "O" or "X"))
		end
		local five = 5 * ScreenMap.menuBar.mobileButton + 4 * ScreenMap.menuBar.gap
		local fiveShift = ScreenMap.mobileMenuBarShiftUp(388, five)
		check(("모바일(48) 3칸 위로 밀기 - 겹침 0이 되는 최소 이동: %s"):format(table.concat(mobileParts, " · ")), mobileOk)
		print(("[S16][UI][참고] 5칸(상한)이면 폰 가로 388에서 바 높이 %d · 아래 끝 %.0f > BL 한계 %.0f - 못 피한다(칸이 늘 때 한 열로는 안 들어간다 - 그때 다시 결정)"):format(five, 388 / 2 + five / 2 - fiveShift, 388 * ScreenMap.mobileReserved.BL.top))
		if Theme.isMobile then
			local bottom = barPos.Y + barSize.Y
			check(("실제 모바일 화면: 바 아래 끝 %.0f ≤ BL 예약 구역 위 끝 %.0f(화면 높이 %.0f × 0.55)"):format(bottom, refs.gui.AbsoluteSize.Y * ScreenMap.mobileReserved.BL.top, refs.gui.AbsoluteSize.Y),
				bottom <= refs.gui.AbsoluteSize.Y * ScreenMap.mobileReserved.BL.top + 0.5)
		end
	end)
	if not ok then
		check(("자체 점검 실행 중 에러: %s"):format(tostring(err)), false)
	end
	UIManager.closeAll()
	for index, name in ipairs(touched) do
		player:SetAttribute(name, saved[index])
	end
	relayout()
	print(("===S16 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

if RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S16(UI)")) then
	task.delay(CHECK_DELAY, selfCheck)
end
