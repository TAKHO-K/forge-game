-- 상점 창(QUEUE-B1 B2 UI - P4c 골격) - 보석상인 좌판의 두 번째 ProximityPrompt(ShopPrompt · 서버 HuntingGround가 만든다)가 여는 station.
--   탭 4개: [골드](GoldTab - 기존 골드 소모처 입구) · [치장](CosmeticTab - 조각 · 로벅스만) · [편의](ConvenienceTab - 게임패스) · [시즌](SeasonTab - 시즌 패스 40칸).
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
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
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
-- QUEUE-ALL2 P2 B-4 ①: 추천 · 치장 · 시즌 패스 · 편의 + 골드(보석상인 좌판 소모처 - 좌판에서 열 때 첫 탭)
local TAB_ORDER = { "recommend", "cosmetic", "season", "convenience", "gold" }
local TAB_MODULES = { recommend = RecommendTab, gold = GoldTab, cosmetic = CosmeticTab, convenience = ConvenienceTab, season = SeasonTab }
local PENDING_LIMIT = 3 -- 초. 서버 응답(ShopSync · 결과 Remote)이 안 오면 이 뒤에 입력이 풀린다
local RANGE_MARGIN = 2 -- 서버 반경보다 이만큼 더 벗어나면 창을 닫는다(보석 공방과 같은 값)
local ROBUX_WIDTH = 104 -- "로벅스 199"가 모바일 글씨(16)에서도 한 줄

local player = Players.LocalPlayer
local shopRequest, shopSync

-- 서버 스냅샷(그대로)
local state = { view = nil, rerollTickets = { ancient = 0, primordial = 0 }, justBought = {}, previewIndex = {} } -- QUEUE-ALL9B justBought = 이번에 연 창에서 산 것(추천 탭 "구매 완료" 유지) · previewIndex = 테마별 다음 미리보기 효과
R.state = state
local built = nil -- { panel, tabs, scroll, status, ctx, L, key }
local selectedTab = "gold"
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

function R.render()
	if not built or not UIManager.isOpen(R.id) then
		return
	end
	built.ctx.clear()
	TAB_MODULES[selectedTab].render(built.ctx, R.env)
	built.status.Text = statusText
	built.status.TextColor3 = Theme.colors[statusColor]
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
				state.justBought[b] = true
				task.defer(function() -- QUEUE-ALL9B(사용자 10-03): 구매 완료 창
					Confirm.ask({ title = Text.get("shop.bought.title"), body = Text.get("shop.bought.body", { name = CosmeticTab.nameOf(a, b) }),
						primaryText = Text.get("shop.bought.equip"), secondaryText = Text.get("shop.bought.close"), parentId = R.id }, function(accepted)
						if accepted then
							R.selectTab("cosmetic")
						end
					end)
				end)
			end
			return owned and "shop.status.bought" or "shop.status.buyFailed", owned and "success" or "danger"
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
local function robuxButton(productKey, name)
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
	return { name = name, text = Text.get("shop.robuxPrice", { n = tostring(product.robux) }), kind = "primary", width = ROBUX_WIDTH, enabled = not busy(),
		onActivated = function()
			if not product.paidRandom then
				send("buyRobux", productKey)
				return
			end
			Confirm.ask({
				title = Text.get("shop.odds.title"),
				body = R.oddsText(product.odds),
				primaryText = Text.get("shop.odds.buy"),
				secondaryText = Text.get("shop.cancel"),
				parentId = R.id,
			}, function(accepted)
				if accepted then
					send("buyRobux", productKey)
				end
			end)
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

R.env = { state = state, send = send, busy = busy, robuxButton = robuxButton, buyReroll = buyReroll, openGemTools = openGemTools, preview = preview, previewNext = previewNext }

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
		anchorPoint = Vector2.new(L.anchorX, 0),
		position = UDim2.new(L.anchorX, L.winX, 0, L.winY),
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
	local tabList = {}
	for _, id in ipairs(TAB_ORDER) do
		table.insert(tabList, { id = id, text = Text.get("shop.tab." .. id) })
	end
	local tabs = Tabs.build({
		parent = content,
		tabs = tabList,
		selected = selectedTab,
		width = L.winW - 2 * Layout.pad,
		position = UDim2.new(0, Layout.pad, 0, 2),
		onSelect = function(id)
			selectedTab = id
			if built then
				built.scroll.CanvasPosition = Vector2.zero
			end
			R.render()
		end,
	})
	tabs.root.Size = UDim2.new(0, L.winW - 2 * Layout.pad, 0, L.tabH) -- 탭 버튼은 root 높이를 채운다(폰 44 = 터치 타깃)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, Layout.pad, 0, L.bodyTop)
	scroll.Size = UDim2.new(0, L.winW - 2 * Layout.pad, 0, L.bodyH)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = content
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 4)
	list.Parent = scroll

	local status = Theme.label(content, "", "caption", "textSecondary")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, Layout.pad + 2, 1, -2)
	status.Size = UDim2.new(1, -(2 * Layout.pad + 4), 0, L.statusH - 4)

	built = { panel = panel, tabs = tabs, scroll = scroll, status = status, ctx = Rows.new(scroll, L), L = L, key = layoutKey(L) }
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

function R.open(tabId)
	R.applyLayout()
	if tabId and TAB_MODULES[tabId] then
		selectedTab = tabId
		built.tabs.select(tabId, true)
	end
	if UIManager.isOpen(R.id) then
		R.render()
		return true
	end
	return UIManager.open(R.id)
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

function R.selectTab(tabId)
	if built and TAB_MODULES[tabId] then
		built.tabs.select(tabId, false)
	end
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

local REROLL_REASON = { no_gold = "shop.reason.noGold", no_dust = "shop.reason.noDust", out_of_range = "shop.reason.outOfRange" }

function R.start()
	shopRequest = ReplicatedStorage:WaitForChild("ShopRequest")
	shopSync = ReplicatedStorage:WaitForChild("ShopSync")
	buyRerollRemote = ReplicatedStorage:WaitForChild("BuyRerollTicketRequest")

	-- QUEUE-B1 결정 10: 서버 결과(action, ok, why) - 실패면 이유 한 줄(표 비교 추정보다 우선) · 성공이면 다음 ShopSync의 추정 문구를 그대로 쓴다
	local SHOP_REASON = { shards = "shop.reason.shards", owned = "shop.reason.owned", off_season = "item.reason.offSeason", not_ready = "shop.reason.notReady", not_owned = "shop.reason.notOwned",
		no_pass = "shop.reason.noPass", not_reached = "shop.reason.notReached", claimed = "shop.reason.claimed", not_premium = "shop.reason.notPremium",
		egg_full = "shop.reason.eggFull", restricted = "shop.reason.restricted", none = "shop.reason.none" }
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
			R.open("gold")
		end
	end)
	shopSync.OnClientEvent:Connect(function(view)
		if type(view) ~= "table" then
			return
		end
		state.view = view
		if pendingCheck then
			local key, color = pendingCheck(view)
			pendingCheck = nil
			setStatus(key ~= "" and Text.get(key) or "", color)
		end
		pendingSince = nil
		R.render()
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
			state.justBought = {} -- QUEUE-ALL9B: 창을 닫으면 추천 탭은 다시 안 산 것만
		end
	end)
	-- 시즌 패스 받을 칸 수 → 왼쪽 메뉴 상점 빨간 점(로컬 Attribute ShopClaimable)
	shopSync.OnClientEvent:Connect(function(view)
		local season = type(view) == "table" and view.season
		player:SetAttribute("ShopClaimable", season and SeasonTab.claimableCount(season) or 0)
	end)
	GiftPopup.start(send)
	R.applyLayout()
	shopRequest:FireServer("view")
end

return R
