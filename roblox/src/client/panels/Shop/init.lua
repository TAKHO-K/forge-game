-- 상점 창(QUEUE-B1 B2 UI - P4c 골격) - 보석상인 좌판의 두 번째 ProximityPrompt(ShopPrompt · 서버 HuntingGround가 만든다)가 여는 station.
--   QUEUE-ALL9C 1-6R(사용자 10-03 - 인기 게임식 탭): PC · 태블릿 = 왼쪽 세로 탭 / 폰 = 위 가로 탭 - [추천](RecommendTab) · [치장](CosmeticTab - 하위 칩) · [시즌 패스](SeasonTab) · [편의](ConvenienceTab)
--   + [골드](GoldTab - 보석상인 좌판 프롬프트로 열었을 때만 · 변환권 · 보석 도구 입구). 꾸미기 토큰 잔액 = 제목줄 오른쪽(탭 아님). 모든 상품 = 같은 카드(Card) · 카드 누름 = 상세(Preview3D).
--   이 창은 서버 상태의 진실을 갖지 않는다: ShopSync(MonetizationService.view) · GemSync · Attribute를 그리고, 요청은 ShopRequest(action, a, b) · 기존 Remote로 보낸다.
--   결과 = ShopResult(action, ok, why - QUEUE-B1 결정 10): 실패는 이유 한 줄 · 성공은 요청 뒤 오는 ShopSync 표를 요청 전과 비교한 문구(pendingCheck).
--   배치 = Layout.compute(화면, 터치) 순수 함수 - 폰(폭 < 720 또는 높이 < 400)은 메뉴바 오른쪽부터 화면 끝까지 · 버튼 · 탭 44. 화면 크기 · 터치 판정이 바뀌면 다시 짓는다.
--   R.debugForceScreen(Vector2)으로 가상 화면을 강제해 폰 배치를 PC 창에서 실제 인스턴스로 잴 수 있다(장비창과 같은 방식 - 자체 점검 · 스크린샷용).
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Text = require(ReplicatedStorage.Shared.Text)
local Confirm = require(script.Parent.Parent.ui.kit.Confirm)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local PriceCache = require(script.Parent.Parent.ui.PriceCache) -- QUEUE-ALL9C 1-6 지역 가격
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local UIManager = require(script.Parent.Parent.UIManager)
local Layout = require(script.Layout)
local Rows = require(script.Rows)
local GoldTab = require(script.GoldTab)
local CosmeticTab = require(script.CosmeticTab)
local ConvenienceTab = require(script.ConvenienceTab)
local SeasonTab = require(script.SeasonTab)
local RecommendTab = require(script.RecommendTab)
local GiftPopup = require(script.GiftPopup)

local R = {}

R.id = "shop"
R.promptName = "ShopPrompt"
R.GiftPopup = GiftPopup
R.Layout = Layout
local TABS = { "recommend", "cosmetic", "season", "convenience", "gold" } -- gold = 좌판에서 열었을 때만 보인다
-- 옛 구역 id(다른 화면 · 1-6 한 페이지 시절 R.open 인자) → { 탭, 치장 칩 }
local OPEN_MAP = { starter = { "recommend" }, theme = { "cosmetic", "theme" }, glider = { "cosmetic", "glider" }, item = { "cosmetic", "killFx" }, equip = { "cosmetic" } }
local PENDING_LIMIT = 3 -- 초. 서버 응답(ShopSync · 결과 Remote)이 안 오면 이 뒤에 입력이 풀린다
local RANGE_MARGIN = 2 -- 서버 반경보다 이만큼 더 벗어나면 창을 닫는다(보석 공방과 같은 값)
local ROBUX_WIDTH = 104 -- "로벅스 199"가 모바일 글씨(16)에서도 한 줄
local CHIP_WIDTH = 104

local player = Players.LocalPlayer
local shopRequest, shopSync

-- 서버 스냅샷(그대로)
local state = { view = nil, rerollTickets = { ancient = 0, primordial = 0 }, justBought = {}, previewIndex = {} } -- QUEUE-ALL9B justBought = 이번에 연 창에서 산 것(추천 탭 "구매 완료" 유지) · previewIndex = 테마별 다음 미리보기 효과
R.state = state
local built = nil -- { panel, tabButtons, chips, chipButtons, scroll, status, balance, ctx, L, key }
local current = { tab = "recommend", chip = "theme", merchant = false } -- merchant = 보석상인 좌판에서 열었다([골드] 탭 보임)
local pendingSince, pendingCheck = nil, nil
local statusText, statusColor = "", "textSecondary"
local debugSkipRangeClose = false
local openedFromHud = false -- 왼쪽 메뉴 상점 버튼으로 열었다 = 어디서든(좌판 반경 밖이어도 닫지 않는다 - 골드 소모는 서버가 반경을 다시 잰다)

local function busy()
	return pendingSince ~= nil and os.clock() - pendingSince < PENDING_LIMIT
end

local function setStatus(text, colorName)
	statusText, statusColor = text or "", colorName or "textSecondary"
	if built then
		built.status.Text = statusText
		built.status.TextColor3 = Theme.colors[statusColor]
	end
end

-- 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋). 점검이 가상 화면을 강제할 수 있다.
local function screenSize()
	if R.forcedScreen then
		return R.forcedScreen
	end
	if RunService:IsStudio() then
		local forced = player:GetAttribute("DebugShopScreen") -- Studio 전용 훅(스크린샷 · 실제 클릭 확인용): Vector2(800, 302) 등
		if typeof(forced) == "Vector2" then
			return forced
		end
	end
	local camera = workspace.CurrentCamera
	local inset = GuiService:GetGuiInset()
	return Vector2.new(camera.ViewportSize.X, camera.ViewportSize.Y - inset.Y)
end

local TAB_RENDER -- 아래(env가 생긴 뒤) 채운다
local Catalog = require(script.Catalog)
local function visibleChips()
	local out = {}
	for _, chip in ipairs(Catalog.CHIPS) do
		if state.view and #Catalog.chipEntries(state.view, chip) > 0 then -- 공개 상품 0개 칩 = 숨김
			table.insert(out, chip)
		end
	end
	return out
end
local function tabVisible(id)
	return id ~= "gold" or current.merchant
end
local function paintSelected(b, on)
	b.root.BackgroundColor3 = on and Theme.colors.ember or Theme.colors.slot
	b.root.BackgroundTransparency = on and 0 or Theme.colors.slotTransparency
end
function R.render()
	if not built or not UIManager.isOpen(R.id) then
		return
	end
	built.ctx.clear()
	if not tabVisible(current.tab) then
		current.tab = "recommend"
	end
	for id, b in pairs(built.tabButtons) do
		b.root.Visible = tabVisible(id)
		paintSelected(b, id == current.tab)
	end
	built.balance.Text = NumberFormat.currency(state.view and state.view.shards or 0, Text.languageFor())
	-- 치장 탭 = 하위 칩 줄(본문을 그만큼 내린다)
	local chips = current.tab == "cosmetic" and state.view and visibleChips() or {}
	local chip
	for _, b in pairs(built.chipButtons) do
		b.root.Visible = false
	end
	for index, c in ipairs(chips) do
		local b = built.chipButtons[c.id]
		b.root.Visible = true
		b.root.LayoutOrder = index
		if c.id == current.chip then
			chip = c
		end
	end
	chip = chip or chips[1]
	if chip then
		current.chip = chip.id
	end
	for id, b in pairs(built.chipButtons) do
		paintSelected(b, chip ~= nil and id == chip.id)
	end
	built.chips.Visible = #chips > 0
	local L = built.L
	local shift = #chips > 0 and (L.chipsH + 4) or 0
	built.scroll.Position = UDim2.new(0, L.bodyX, 0, L.bodyTop + shift)
	built.scroll.Size = UDim2.new(0, L.bodyW, 0, L.bodyH - shift)
	if not state.view then
		built.ctx.line(Text.get("shop.loading"), "textSecondary", 1, "Loading")
	else
		TAB_RENDER[current.tab](built.ctx, R.env, chip)
	end
	built.status.Text = statusText
	built.status.TextColor3 = Theme.colors[statusColor]
end

-- 탭(· 치장 칩) 고르기 = 본문 맨 위부터
function R.selectTab(tabId, chipId)
	local mapped = OPEN_MAP[tabId]
	if mapped then
		tabId, chipId = mapped[1], chipId or mapped[2]
	end
	current.tab = table.find(TABS, tabId) and tabId or "recommend"
	if chipId then
		current.chip = chipId
	end
	if built then
		built.scroll.CanvasPosition = Vector2.zero
	end
	R.render()
end

local function send(action, a, b)
	if busy() then
		return
	end
	local before = state.view
	pendingSince = os.clock()
	-- 결과 판정: 다음 ShopSync 표에서 이 요청이 반영됐는지 본다(서버가 이유를 돌려주지 않는다 - 보고 사항)
	pendingCheck = function(view)
		if action == "buyShards" then
			local owned = (a == "cosmeticTheme" and view.themes and view.themes[b]) or (a == "gliderSkin" and view.gliderSkins and view.gliderSkins[b])
				or (a == "cosmeticItem" and view.items and view.items[b]) -- 리뷰: 소품(cosmeticItem)도 성공으로 본다
			if owned then
				state.justBought[b] = true -- 구매 완료 창 = ShopSync 비교(R.start - 토큰 · 로벅스 공통)
			end
			return owned and "" or "shop.status.buyFailed", owned and "success" or "danger" -- QUEUE-ALL9C 1-6: 성공 = 구매 완료 창만(상태 줄과 두 번 보이던 것 - ALL9B 넘김 4)
		elseif action == "equip" then
			local ok = view.equipped[a] == b
			return ok and "shop.status.equipped" or "shop.status.equipFailed", ok and "success" or "danger"
		elseif action == "seasonClaim" then
			local claimed = a == "free" and view.season and view.season.claimedFree or view.season and view.season.claimedPaid
			local ok = claimed ~= nil and claimed[tostring(b)] == true
			return ok and "shop.status.claimed" or "shop.status.claimFailed", ok and "success" or "danger"
		elseif action == "giftClaim" then
			local ok = before ~= nil and (view.gifts or 0) < (before.gifts or 0)
			return ok and "gift.claimed" or "gift.claimFailed", ok and "success" or "danger"
		elseif action == "buyRobux" or action == "buyPass" then
			return "shop.status.prompted", "textSecondary"
		end
		return "", "textSecondary"
	end
	setStatus(Text.get("shop.status.sending"), "textSecondary")
	shopRequest:FireServer(action, a, b)
	R.render()
end

-- 로벅스 구매 버튼 spec(치장 · 시즌 공통). 준비 중(productId 0) = 회색 "준비 중" · 유료 랜덤 제한(blocked) = 회색 "구매 불가" · 유료 랜덤이면 확률표 확인창을 먼저 띄운다.
-- QUEUE-ALL9C 1-6: 로벅스 결제 전 우리 확인 창(구성 + 환불 문구 ①) → 서버가 로블록스 결제 창을 연다. info = { title, body }(구성 - 행 제목 · 부제)
local function confirmRobux(info, price, onYes, extraBody)
	local parts = {}
	for _, piece in ipairs({ info and info.body or "", extraBody or "", Text.get("shop.refund.note") }) do
		if piece ~= "" then
			table.insert(parts, piece)
		end
	end
	local body = table.concat(parts, "\n\n")
	Confirm.ask({ title = info and info.title or Text.get("shop.confirm.title"), body = body, primaryText = Text.get("shop.confirm.buy", { n = tostring(price) }),
		primaryPrice = { label = Text.get("shop.confirm.buyLabel"), currency = "robux", amount = price }, -- QUEUE-ALL9C 1-6R 같은 가격 버튼(구매 + 로벅스 아이콘 + 숫자)
		secondaryText = Text.get("shop.cancel"), parentId = R.id }, function(accepted)
		if accepted then
			onYes()
		end
	end)
end
R.confirmRobux = confirmRobux
-- QUEUE-ALL9C 1-6R: 반환 = kit/PriceButton spec(currency · amount) - 행(Rows) · 카드 · 배너 · 상세가 같은 모양
local function robuxButton(productKey, name, info)
	local product = state.view and state.view.products and state.view.products[productKey]
	if not product then
		return { name = name, text = Text.get("shop.notReady"), enabled = false, width = ROBUX_WIDTH }
	end
	if product.blocked then
		return { name = name, text = Text.get("shop.blocked"), enabled = false, width = ROBUX_WIDTH }
	end
	if not product.ready then
		return { name = name, text = Text.get("shop.notReady"), enabled = false, width = ROBUX_WIDTH }
	end
	local price = PriceCache.get("product", product.productId, product.robux) -- QUEUE-ALL9C 1-6 지역 가격(없으면 데이터 값)
	return { name = name, currency = "robux", amount = price, kind = "primary", width = ROBUX_WIDTH, enabled = not busy(),
		onActivated = function()
			confirmRobux(info, price, function()
				send("buyRobux", productKey)
			end, product.paidRandom and R.oddsText(product.odds) or nil) -- 유료 랜덤(지금 0개)은 확률표도 같은 창에
		end }
end

-- 확률표 → 여러 줄 글. odds 모양은 아직 정해지지 않았다(paidRandom 상품 0개) - { {name|id, chance} } 배열 또는 { [이름] = 확률 } 표 둘 다 받는다. 확률 1 이하는 비율로 보고 %로 바꾼다.
function R.oddsText(odds)
	local lines = {}
	local function add(name, chance)
		chance = tonumber(chance) or 0
		local percent = chance <= 1 and chance * 100 or chance
		table.insert(lines, Text.get("shop.odds.line", { name = tostring(name), percent = ("%g"):format(math.floor(percent * 1000 + 0.5) / 1000) }))
	end
	if type(odds) == "table" then
		if #odds > 0 then
			for _, entry in ipairs(odds) do
				add(entry.name or entry.id, entry.chance or entry.weight)
			end
		else
			local names = {}
			for name in pairs(odds) do
				table.insert(names, name)
			end
			table.sort(names)
			for _, name in ipairs(names) do
				add(name, odds[name])
			end
		end
	end
	if #lines == 0 then
		return Text.get("shop.odds.missing")
	end
	return table.concat(lines, "\n")
end

-- 기존 골드 소모처 입구(새 Remote 없음)
local buyRerollRemote
local function buyReroll(gradeId)
	if busy() then
		return
	end
	pendingSince, pendingCheck = os.clock(), nil
	setStatus(Text.get("shop.status.sending"), "textSecondary")
	buyRerollRemote:FireServer(gradeId)
	R.render()
end
local function openGemTools()
	require(script.Parent.GemWorkshop).open() -- 같은 station 자리 - 상점은 UIManager가 닫는다
end

-- QUEUE-ALL2 P2 B-4 ①: 치장 입혀 보기 - 내 Player Attribute Cosmetic_<칸>을 로컬에서만 잠깐 바꾼다(복제 안 됨 · 서버 값 그대로) → PREVIEW_SECONDS 뒤 원래 값
local PREVIEW_SECONDS = 10
local previewToken = 0
-- QUEUE-ALL9B(사용자 10-03): 테마는 4종을 하나씩 - 버튼이 보여 준 효과(previewNext)를 입히고 다음 효과로 넘긴다.
local function previewNext(entry)
	local i = state.previewIndex[entry.id] or 1
	local part = CosmeticTab.themeParts[i]
	return i, Text.get(part.key), part
end
local previewSaved = {}
local function preview(kind, entry)
	previewToken += 1
	local mine = previewToken
	for slot, value in pairs(previewSaved) do -- 앞 미리보기를 먼저 원래 값으로
		player:SetAttribute("Cosmetic_" .. slot, value)
	end
	previewSaved = {}
	local slots, partInfo
	if kind == "cosmeticTheme" then
		local i, partName, part = previewNext(entry)
		slots, partInfo = { part.slot }, { name = partName, input = part.input }
		state.previewIndex[entry.id] = i % #CosmeticTab.themeParts + 1
	else
		slots = kind == "gliderSkin" and { "gliderSkin" } or { entry.slot } -- QUEUE-ALL6 H 소품 = 그 칸 하나
	end
	for _, slot in ipairs(slots) do
		previewSaved[slot] = player:GetAttribute("Cosmetic_" .. slot)
		player:SetAttribute("Cosmetic_" .. slot, entry.id)
	end
	local saved = previewSaved
	if partInfo then
		setStatus(Text.get("shop.cos.tryingPart", { name = Text.name(entry.name), part = partInfo.name, n = tostring(PREVIEW_SECONDS), key = partInfo.input }), "success")
		R.render()
	else
		setStatus(Text.get("shop.cos.trying", { name = entry.name, n = tostring(PREVIEW_SECONDS) }), "success")
	end
	task.delay(PREVIEW_SECONDS, function()
		if mine ~= previewToken then
			return
		end
		for slot, value in pairs(saved) do
			player:SetAttribute("Cosmetic_" .. slot, value)
		end
		previewSaved = {}
	end)
end

-- QUEUE-ALL9C 1-6 게임패스 가격(지역 가격 · 없으면 데이터 값)
local function passPrice(key)
	local pass = state.view and state.view.passes and state.view.passes[key]
	return pass and PriceCache.get("pass", pass.passId, pass.robux) or nil
end
R.env = { state = state, send = send, busy = busy, robuxButton = robuxButton, buyReroll = buyReroll, openGemTools = openGemTools, preview = preview, previewNext = previewNext,
	passPrice = passPrice, confirmRobux = confirmRobux, selectTab = function(tabId, chipId)
		R.selectTab(tabId, chipId)
	end, robuxSpec = function(productKey, info)
		return robuxButton(productKey, nil, info)
	end }
-- QUEUE-ALL9C 1-6R 카드 누름 = 상세 패널(3D 미리보기 + 구성품 목록 · 토글 + 로벅스/토큰 구매 + 환불 문구 ① + [직접 보기])
R.env.openDetail = function(productKey)
	local kind, entry = Catalog.firstGrant(productKey)
	require(script.Preview3D).openDetail(R.env, productKey, function()
		if entry then
			preview(kind, entry) -- 내 캐릭터에 잠깐(테마 = 누를 때마다 다음 칸)
		end
	end)
end
TAB_RENDER = {
	recommend = RecommendTab.render,
	cosmetic = function(ctx, env, chip)
		if chip then
			CosmeticTab.render(ctx, env, chip)
		end
	end,
	season = function(ctx, env)
		SeasonTab.render(ctx, env, { tiersOpen = state.seasonOpen == true, onToggleTiers = function()
			state.seasonOpen = not state.seasonOpen
			R.render()
		end })
	end,
	convenience = function(ctx, env)
		ConvenienceTab.render(ctx, env)
	end,
	gold = GoldTab.render,
}

local function layoutKey(L)
	return ("%s:%d:%d:%s"):format(L.mode, L.winW, L.winH, tostring(Theme.isMobile))
end

local function destroy()
	if not built then
		return
	end
	UIManager.unregister(R.id)
	built.panel.screenGui:Destroy()
	built = nil
end

local function build(L)
	local panel = Panel.create({
		id = R.id,
		kind = "station",
		title = Text.get("shop.title"),
		size = Vector2.new(L.winW, L.winH),
		maxSize = Vector2.new(Layout.maxWidth, Layout.maxHeight),
		anchorPoint = Vector2.new(L.anchorX, L.anchorY),
		position = UDim2.fromOffset(L.winX, L.winY), -- 앵커 점 자리(px) - PC = 사용 가능 영역 가운데 · 폰 = 메뉴바 오른쪽 위
		help = { short = Text.get("shop.help.short"), detail = Text.get("shop.help.detail") },
		onOpen = function()
			setStatus("", "textSecondary")
			if built then
				built.scroll.CanvasPosition = Vector2.zero
			end
			shopRequest:FireServer("view")
			task.defer(R.render)
		end,
	})
	local content = panel.content
	-- QUEUE-ALL9C 1-6R 탭: PC · 태블릿 = 왼쪽 세로(railW) / 폰 = 위 가로
	local phone = L.mode == "phone"
	local rail = Instance.new("Frame")
	rail.Name = "TabRail"
	rail.BackgroundTransparency = 1
	rail.Position = UDim2.new(0, L.pad, 0, 4)
	rail.Size = phone and UDim2.new(0, L.winW - 2 * L.pad, 0, L.tabH) or UDim2.new(0, L.railW - L.pad, 0, L.winH - L.titleH - L.statusH - 8)
	rail.Parent = content
	local railLayout = Instance.new("UIListLayout")
	railLayout.FillDirection = phone and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	railLayout.SortOrder = Enum.SortOrder.LayoutOrder
	railLayout.Padding = UDim.new(0, 4)
	railLayout.Parent = rail
	local tabButtons = {}
	local tabW = phone and math.floor((L.winW - 2 * L.pad - 4 * 4) / 5) or (L.railW - L.pad)
	for index, id in ipairs(TABS) do
		local b = Button.build({ parent = rail, name = "Tab_" .. id, kind = "secondary", text = Text.get("shop.tab." .. id), width = tabW, height = L.tabH,
			onActivated = function()
				R.selectTab(id)
			end })
		b.root.LayoutOrder = index
		tabButtons[id] = b
	end
	-- 치장 하위 칩(가로 스크롤 - 폰 높이 44 = 터치 타깃) · 공개 상품 0개 칩 = 숨김(render)
	local chips = Instance.new("ScrollingFrame")
	chips.Name = "SubChips"
	chips.BackgroundTransparency = 1
	chips.BorderSizePixel = 0
	chips.Position = UDim2.new(0, L.bodyX, 0, L.bodyTop)
	chips.Size = UDim2.new(0, L.bodyW, 0, L.chipsH)
	chips.ScrollingDirection = Enum.ScrollingDirection.X
	chips.ScrollBarThickness = 2
	chips.AutomaticCanvasSize = Enum.AutomaticSize.X
	chips.CanvasSize = UDim2.new()
	chips.Visible = false
	chips.Parent = content
	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Padding = UDim.new(0, 4)
	chipLayout.Parent = chips
	local chipButtons = {}
	for _, chip in ipairs(Catalog.CHIPS) do
		local b = Button.build({ parent = chips, name = "Chip_" .. chip.id, kind = "secondary", text = Text.get("shop.chip." .. chip.id), width = CHIP_WIDTH, height = L.chipsH - 4,
			onActivated = function()
				R.selectTab("cosmetic", chip.id)
			end })
		chipButtons[chip.id] = b
	end
	-- 꾸미기 토큰 잔액 = 제목줄 오른쪽(도움말 · X 왼쪽 · 탭 아님)
	local balanceRow = Instance.new("Frame")
	balanceRow.Name = "TokenBalance"
	balanceRow.BackgroundTransparency = 1
	balanceRow.AnchorPoint = Vector2.new(1, 0.5)
	balanceRow.Position = UDim2.new(1, -(Panel.closeSize + 4 + 40 + 8), 0, (L.titleH - 1) / 2)
	balanceRow.AutomaticSize = Enum.AutomaticSize.X
	balanceRow.Size = UDim2.fromOffset(0, Theme.textSize("body") + 4)
	balanceRow.Parent = panel.frame
	local balanceLayout = Instance.new("UIListLayout")
	balanceLayout.FillDirection = Enum.FillDirection.Horizontal
	balanceLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	balanceLayout.SortOrder = Enum.SortOrder.LayoutOrder
	balanceLayout.Padding = UDim.new(0, 4)
	balanceLayout.Parent = balanceRow
	local tokenIcon = ArtImage.label(balanceRow, "icons/reward/sparkleShard", UDim2.fromOffset(Theme.textSize("body"), Theme.textSize("body")), "◆")
	tokenIcon.Name = "TokenIcon"
	tokenIcon.LayoutOrder = 1
	local balance = Theme.label(balanceRow, "0", "body", "gold")
	balance.Name = "Amount"
	balance.LayoutOrder = 2
	balance.AutomaticSize = Enum.AutomaticSize.X
	balance.Size = UDim2.fromOffset(0, Theme.textSize("body") + 4)
	panel.titleLabel.Size = UDim2.new(0, math.max(80, L.winW - 16 - (Panel.closeSize + 4 + 40 + 8) - 90), 0, L.titleH - 1)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, L.bodyX, 0, L.bodyTop)
	scroll.Size = UDim2.new(0, L.bodyW, 0, L.bodyH)
	scroll.ScrollBarThickness = 4 -- 얇은 스크롤 막대
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = content
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 6)
	list.Parent = scroll

	local status = Theme.label(content, "", "caption", "textSecondary")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, L.pad + 2, 1, -2)
	status.Size = UDim2.new(1, -(2 * L.pad + 4), 0, L.statusH - 4)

	built = { panel = panel, tabButtons = tabButtons, chips = chips, chipButtons = chipButtons, scroll = scroll, status = status, balance = balance, ctx = Rows.new(scroll, L), L = L, key = layoutKey(L) }
end

-- 지금 화면으로 배치를 계산하고, 지은 것과 다르면 다시 짓는다. 반환: L
function R.applyLayout()
	Theme.recompute()
	local size = screenSize()
	local L = Layout.compute(size.X, size.Y, Theme.isMobile)
	if built and built.key ~= layoutKey(L) then
		local wasOpen = UIManager.isOpen(R.id)
		if wasOpen then
			UIManager.close(R.id, true)
		end
		destroy()
		build(L)
		if wasOpen then
			UIManager.open(R.id)
		end
	elseif not built then
		build(L)
	end
	return L
end

-- 점검 전용: 가상 화면을 강제하고(nil = 해제) 배치를 다시 계산해 돌려준다(창 · 행 크기가 전부 L에서 나오므로 실제 폰과 같은 크기 · 자리가 된다).
function R.debugForceScreen(size)
	R.forcedScreen = size
	local L = R.applyLayout()
	R.render()
	return L
end

function R.open(tabId, chipId)
	R.applyLayout()
	local wasOpen = UIManager.isOpen(R.id)
	local opened = wasOpen or UIManager.open(R.id)
	R.selectTab(tabId or current.tab, chipId) -- 옛 구역 id(theme · glider …)도 받는다(OPEN_MAP)
	return opened
end

-- QUEUE-ALL2 P2: 왼쪽 메뉴 금색 [상점] - 어디서든 연다(열린 window는 먼저 닫는다 - station 규칙) · 같은 버튼 다시 = 닫기
function R.openFromHud(tabId)
	if built and UIManager.isOpen(R.id) then
		UIManager.close(R.id)
		return false
	end
	for _, id in ipairs(UIManager.getStack()) do
		if UIManager.getKind(id) == "window" then
			UIManager.close(id, true)
		end
	end
	openedFromHud = true
	task.spawn(R.fetchGemTickets)
	return R.open(tabId or "recommend")
end

function R.close()
	UIManager.close(R.id)
end

-- QUEUE-ALL9C 1-6R Studio 전용 촬영: 가상 화면(DebugShopScreen)이 Studio 뷰포트보다 크면(1366 × 768 · 1920 × 1080 · 2560 × 1440 · 태블릿) 열린 창을 비율대로 줄여
--   뷰포트 가운데에 가상 화면 테두리와 함께 그린다(창 · 카드 배치 비율 확인용 - 글씨도 같이 작아진다). Attribute DebugShopFit = true(열린 뒤) · nil = 해제.
function R.debugFitForced(on)
	if not built then
		return
	end
	local frame, gui = built.panel.frame, built.panel.screenGui
	local outline = gui:FindFirstChild("DebugScreenOutline")
	if outline then
		outline:Destroy()
	end
	local scale = frame:FindFirstChildOfClass("UIScale")
	local fit = frame:FindFirstChild("ScreenFit")
	local L = built.L
	if not on then
		R.applyLayout()
		return
	end
	local real = gui.AbsoluteSize
	local s = math.min(1, real.X / L.screenW, real.Y / L.screenH)
	if fit then
		fit.MaxSize = Vector2.new(math.huge, math.huge)
	end
	frame.Size = UDim2.fromOffset(L.winW, L.winH)
	if scale then
		scale.Scale = s
	end
	-- 가상 화면 좌표(앵커 점) → 실제 뷰포트 가운데 기준
	frame.Position = UDim2.new(0.5, (L.winX - L.screenW / 2) * s, 0.5, (L.winY - L.screenH / 2) * s)
	frame.AnchorPoint = Vector2.new(L.anchorX, L.anchorY)
	outline = Instance.new("Frame")
	outline.Name = "DebugScreenOutline"
	outline.BackgroundTransparency = 1
	outline.AnchorPoint = Vector2.new(0.5, 0.5)
	outline.Position = UDim2.fromScale(0.5, 0.5)
	outline.Size = UDim2.fromOffset(L.screenW * s, L.screenH * s)
	outline.ZIndex = 0
	outline.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 2
	stroke.Parent = outline
	local label = Theme.label(outline, ("%d × %d · ×%.2f"):format(L.screenW, L.screenH, s), "caption", "textPrimary")
	label.Position = UDim2.fromOffset(4, 2)
	label.Size = UDim2.fromOffset(240, 18)
	print(("[SHOPFIT] 가상 %d×%d 창 %d×%d 열 %d 카드 %d×%d 축소 %.2f"):format(L.screenW, L.screenH, L.winW, L.winH, L.cols, L.cardW, L.cardH, s))
end

-- 점검 · 스크린샷 전용: 합성 표로 그린다(서버 없이). view = MonetizationService.view 모양
function R.debugApply(view)
	state.view = view
	R.render()
end
function R.debugBuilt()
	return built
end
function R.debugSkipRangeClose(skip)
	debugSkipRangeClose = skip == true
end

local function fetchGemTickets()
	local ok, gemState = pcall(function()
		return ReplicatedStorage:WaitForChild("GemFetch"):InvokeServer()
	end)
	if ok and type(gemState) == "table" and type(gemState.rerollTickets) == "table" then
		state.rerollTickets = gemState.rerollTickets
	end
end

R.fetchGemTickets = fetchGemTickets

-- 걸어서 보석상인 반경을 벗어나면 닫는다(표시 편의 - 판정은 서버. 상점 프롬프트는 보석상인 좌판에 있다)
local merchantGuide
local function step()
	if debugSkipRangeClose or openedFromHud or not built or not UIManager.isOpen(R.id) then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	merchantGuide = merchantGuide or require(script.Parent.GemWorkshop.Guide)
	if (root.Position - merchantGuide.merchantPosition()).Magnitude > WorldConfig.gemMerchant.interactionRangeStuds + RANGE_MARGIN then
		UIManager.close(R.id)
	end
end

-- QUEUE-ALL9C 1-6 X6: ShopSync 두 표를 비교해 새로 생긴 치장(테마 · 글라이더 · 소품) = 구매 완료 창 [바로 장착 · 닫기]. 첫 표(접속 직후)는 비교하지 않는다.
local KIND_BAG = { cosmeticTheme = "themes", gliderSkin = "gliderSkins", cosmeticItem = "items" }
function R.announceNewlyOwned(before, after)
	if type(before) ~= "table" or type(after) ~= "table" then
		return
	end
	for kind, bag in pairs(KIND_BAG) do
		for id, owned in pairs(after[bag] or {}) do
			if owned and not (before[bag] or {})[id] then
				state.justBought[id] = true
				task.defer(function()
					Confirm.ask({ title = Text.get("shop.bought.title"), body = Text.get("shop.bought.body", { name = CosmeticTab.nameOf(kind, id) }),
						primaryText = Text.get("shop.bought.equip"), secondaryText = Text.get("shop.bought.close"), parentId = UIManager.isOpen(R.id) and R.id or nil }, function(accepted)
						if accepted then
							send("equipAll", kind, id) -- 바로 장착(그 치장이 들어가는 칸 전부)
						end
					end)
				end)
				return -- 한 번에 창 하나(묶음은 첫 것 이름)
			end
		end
	end
end

local REROLL_REASON = { no_gold = "shop.reason.noGold", no_dust = "shop.reason.noDust", out_of_range = "shop.reason.outOfRange" }

function R.start()
	-- QUEUE-ALL9C 1-6R(사용자 10-03): 로블록스 공식 Shop 전역 버튼은 끈다 - 우리 상점(3D 미리보기)이 유일한 상점 입구
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.ExperienceShop, false)
	end)
	shopRequest = ReplicatedStorage:WaitForChild("ShopRequest")
	shopSync = ReplicatedStorage:WaitForChild("ShopSync")
	buyRerollRemote = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")

	-- QUEUE-B1 결정 10: 서버 결과(action, ok, why) - 실패면 이유 한 줄(표 비교 추정보다 우선) · 성공이면 다음 ShopSync의 추정 문구를 그대로 쓴다
	local SHOP_REASON = { shards = "shop.reason.shards", owned = "shop.reason.owned", off_season = "item.reason.offSeason", not_ready = "shop.reason.notReady", not_owned = "shop.reason.notOwned",
		no_pass = "shop.reason.noPass", not_reached = "shop.reason.notReached", claimed = "shop.reason.claimed", not_premium = "shop.reason.notPremium",
		egg_full = "shop.reason.eggFull", restricted = "shop.reason.restricted", none = "shop.reason.none", not_released = "shop.reason.notReleased", busy = "shop.reason.busy" }
	ReplicatedStorage:WaitForChild("ShopResult").OnClientEvent:Connect(function(_, ok, why)
		if ok then
			return
		end
		pendingCheck = nil
		pendingSince = nil
		setStatus(Text.get(SHOP_REASON[why] or "shop.reason.rejected", { reason = tostring(why) }), "danger")
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if prompt.Name == R.promptName and triggeringPlayer == player then
			task.spawn(fetchGemTickets)
			openedFromHud = false
			current.merchant = true -- [골드] 탭 = 좌판에서 열었을 때만
			R.open("gold")
		end
	end)
	shopSync.OnClientEvent:Connect(function(view)
		if type(view) ~= "table" then
			return
		end
		local before = state.view
		state.view = view
		R.announceNewlyOwned(before, view) -- QUEUE-ALL9C 1-6 X6 구매 완료 창(토큰 · 로벅스 공통)
		if pendingCheck then
			local key, color = pendingCheck(view)
			pendingCheck = nil
			setStatus(key ~= "" and Text.get(key) or "", color)
		end
		pendingSince = nil
		R.render()
		require(script.Preview3D).refresh(R.env) -- 열린 상세의 보유 · 착용 · 잔액
	end)
	ReplicatedStorage:WaitForChild("GemSync").OnClientEvent:Connect(function(snapshot)
		if type(snapshot) == "table" and type(snapshot.rerollTickets) == "table" then
			state.rerollTickets = snapshot.rerollTickets
		end
		R.render()
	end)
	ReplicatedStorage:WaitForChild("GemWorkshopResult").OnClientEvent:Connect(function(action, success, reason)
		if action ~= "buy" or not UIManager.isOpen(R.id) then
			return
		end
		pendingSince = nil
		setStatus(success and Text.get("shop.status.ticketBought") or Text.get(REROLL_REASON[reason] or "shop.reason.rejected", { reason = tostring(reason) }), success and "success" or "danger")
		R.render()
	end)
	for _, name in ipairs({ "Gold", "GemDust", "AccountBestStage" }) do
		player:GetAttributeChangedSignal(name):Connect(R.render)
	end
	RunService.Heartbeat:Connect(step)
	UIManager.changed:Connect(function(id, isOpen)
		if id == R.id and not isOpen then
			openedFromHud = false
			current.merchant = false
			state.justBought = {} -- QUEUE-ALL9B: 창을 닫으면 추천 탭은 다시 안 산 것만
		end
	end)
	-- 시즌 패스 받을 칸 수 → 왼쪽 메뉴 상점 빨간 점(로컬 Attribute ShopClaimable)
	shopSync.OnClientEvent:Connect(function(view)
		local season = type(view) == "table" and view.season
		player:SetAttribute("ShopClaimable", season and SeasonTab.claimableCount(season) or 0)
	end)
	if RunService:IsStudio() then
		player:GetAttributeChangedSignal("DebugShopFit"):Connect(function()
			R.debugFitForced(player:GetAttribute("DebugShopFit") == true)
		end)
	end
	GiftPopup.start(send)
	R.applyLayout()
	shopRequest:FireServer("view")
end

return R
