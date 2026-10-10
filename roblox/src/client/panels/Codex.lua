-- QUEUE-ALL1 P5 도감 v2 창(K · 메뉴바 칸 - PanelRegistry "codex"). 서버 CodexService가 판정 · 지급 · 화면 표(CodexUpdate)를 준다 - 클라는 계산하지 않는다.
--   요청 = CodexRequest("view" | "claim" 칸 id · "all" · "board:<점수>" | "title" id).
-- QUEUE-ALL3 Q1(10 문서 1절) 그림 · 보상판 다시:
--   위 줄 = 탭 8개(그림 + 짧은 글자 · 자체 가로 줄 - kit Tabs는 5개 한도라 안 쓴다) + [모두 받기](초록 · 굵게 · 폰 60 / PC 48 높이).
--   본문 = 왼쪽 칸 목록(탭마다 ScrollingFrame 1개 - 처음 볼 때 만든다 · CodexV2/Grid) + 오른쪽 상세 칸(CodexV2/Detail - 3D 미리보기 ViewportFrame 1개).
--   받기 = 보상 그림이 오른쪽 위 재화 칩으로 0.4초 날아간다(CodexV2/Fly - 서버가 받음을 확인한 표가 온 뒤).
--   폰 판정 = 화면 크기(ScreenGui 폭 < 720 또는 높이 < 400 - COMMON §2 · Inventory/Layout과 같은 경계) · UIScale 축소 없음.
--   Studio 점검: CodexPanel.debugEmptyPictureCount() = 모든 탭을 그려 그림 없는 칸 수(기대 0)를 센다.
-- QUEUE-ALL9C 1-11(F3): 탭 줄 아래 꾸미기 토큰 진행 줄 = 지금 토큰 / 499급 토큰가(700 - Monetization.premiumTokenProgress · 상점과 같은 식) + "다음 499급 치장까지 n토큰"
--   + [무료로 모으는 곳](퀘스트 창 - 일일 · 주간 · 출석 보상의 토큰) - 무료로도 모을 수 있다는 인식이 목적. 값 = Player Attribute SparkleShard(서버 지갑).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CodexData = require(ReplicatedStorage.Shared.data.CodexData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIManager = require(script.Parent.Parent.UIManager)
local Info = require(script.Parent.CodexV2.Info)
local Grid = require(script.Parent.CodexV2.Grid)
local Detail = require(script.Parent.CodexV2.Detail)
local Fly = require(script.Parent.CodexV2.Fly)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Players = game:GetService("Players")
-- UI-1c 4단계 도감 v3(I v1 §2 · 스위치 UiV2Flags.codexV3): 창 = 기준 화면 좌표(PC 1840 × 990 · 폰 784 × 298) + UIScale · 탭 7(% · 빨간 점) · 띠 = 진행 + 상자 10 + [모두 받기] ·
--   왼쪽 판 1290 + 오른쪽 상세 502(보스 = 상세 없이 전체 폭) · 무기 · 보스 · 탐험 · 칭호 = CodexV2/V3 · 나머지 탭 = 옛 그리드(칸만 크게)
local V3ON = require(ReplicatedStorage.Shared.data.UiV2Flags).codexV3
local L3 = require(ReplicatedStorage.Shared.data.UiLayoutData).codexV3
local V3 = V3ON and require(script.Parent.CodexV2.V3) or nil
local V3TABS = { class = true, boss = true, nest = true, title = true }

local CodexPanel = {}
CodexPanel.id = "codex"

local PANEL_SIZE = Vector2.new(720, 480)
local PAD = 8
local ALL_W = 120
local WHERE_W = 128 -- [무료로 모으는 곳]
local NEED_W = 210 -- "다음 499급 치장까지 n토큰"
local PHONE_W, PHONE_H = 720, 400 -- COMMON §2 폰 경계(panels/Inventory/Layout과 같은 값)

local requestRemote = ReplicatedStorage:WaitForChild("CodexRequest")
local updateRemote = ReplicatedStorage:WaitForChild("CodexUpdate")

local built
local scrolls, dirty = {}, {}
local pending -- 받기 연출 대기 { ids | all, items, before, t }
local S = { tab = "armor", selected = nil, phone = false, claimH = 48, cellW = 92, cellH = 122, gridW = 440, detailW = 250 }
S.clientRoot = script.Parent.Parent

function S.send(action, arg)
	requestRemote:FireServer(action, arg)
end

-- 서버가 0.2초 안의 요청을 버린다 → 여러 칸 받기는 0.25초 간격
local sendQueue, pumping = {}, false
local function sendQueued(action, arg)
	table.insert(sendQueue, { action, arg })
	if pumping then
		return
	end
	pumping = true
	task.spawn(function()
		while #sendQueue > 0 do
			local q = table.remove(sendQueue, 1)
			S.send(q[1], q[2])
			if #sendQueue > 0 then
				task.wait(0.25)
			end
		end
		pumping = false
	end)
end

function S.close()
	UIManager.close(CodexPanel.id)
end

local function tabClaimable(tabId)
	local view = S.view
	if not view then
		return false
	end
	if tabId == "board" then
		for _, b in ipairs(view.board) do
			if b.done and not b.claimed then
				return true
			end
		end
		return false
	end
	for _, c in pairs(view.cells) do
		if c.tab == tabId and c.done and not c.claimed then
			return true
		end
	end
	return false
end

local function claimedCount()
	local n = 0
	for _, c in pairs(S.view.cells) do
		n += c.claimed and 1 or 0
	end
	for _, b in ipairs(S.view.board) do
		n += b.claimed and 1 or 0
	end
	return n
end

local function isClaimed(id)
	local t = tonumber(id:match("^board:(%d+)$"))
	if t then
		for _, b in ipairs(S.view.board) do
			if b.threshold == t then
				return b.claimed
			end
		end
		return false
	end
	local c = S.view.cells[id]
	return c and c.claimed
end

function S.claim(ids, rewardRow)
	if not ids or #ids == 0 then
		return
	end
	pending = { ids = ids, items = Fly.capture(rewardRow), t = os.clock() }
	for _, id in ipairs(ids) do
		sendQueued("claim", id)
	end
end

local function claimAll()
	if not S.view then
		return
	end
	local b = built.claimAll.root
	local c = b.AbsolutePosition + b.AbsoluteSize / 2
	local items = {}
	for i, key in ipairs({ "gold", "enhanceStone", "sparkleShard" }) do
		local img = ArtImage.get("icons/reward/" .. key)
		if img then
			table.insert(items, { key = key, image = img, center = c + Vector2.new((i - 2) * 22, 0), size = 32 })
		end
	end
	pending = { all = true, before = claimedCount(), items = items, t = os.clock() }
	sendQueued("claim", "all")
end

local function checkPending()
	if not pending or not S.view then
		return
	end
	local hit = false
	if pending.all then
		hit = claimedCount() > pending.before
	else
		for _, id in ipairs(pending.ids) do
			hit = hit or isClaimed(id)
		end
	end
	if hit then
		Fly.launch(pending.items)
		pending = nil
	elseif os.clock() - pending.t > 5 then
		pending = nil
	end
end

local function ensureScroll(tabId)
	local sc = scrolls[tabId]
	if sc then
		return sc
	end
	sc = Instance.new("ScrollingFrame")
	sc.Name = "Body_" .. tabId
	sc.BackgroundTransparency = 1
	sc.BorderSizePixel = 0
	sc.ScrollBarThickness = 6
	sc.ScrollingDirection = Enum.ScrollingDirection.XY
	sc.CanvasSize = UDim2.new()
	sc.Size = UDim2.fromScale(1, 1)
	sc.Visible = false
	sc.Parent = built.gridArea
	scrolls[tabId] = sc
	dirty[tabId] = true
	return sc
end

local function renderTab(tabId)
	if not S.view then
		return
	end
	if V3ON and V3TABS[tabId] then -- UI-1c 4단계
		local sc = ensureScroll(tabId)
		for _, child in ipairs(sc:GetChildren()) do
			if not child:IsA("UIBase") then
				child:Destroy()
			end
		end
		local fn = ({ class = V3.renderClass, boss = V3.renderBoss, nest = V3.renderNest, title = V3.renderTitles })[tabId]
		fn(S, sc)
		dirty[tabId] = false
		return
	end
	Grid.render(S, tabId, ensureScroll(tabId))
	dirty[tabId] = false
end

-- 크기 · 폰 판정 → 위 줄 · 본문 · 상세 칸 자리(창 높이가 화면에 맞춰 줄어도 따라간다)
local lastLayout
-- UI-1c 4단계: v3 배치 = 데이터 좌표 그대로(창 = 기준 화면 + UIScale - 화면 크기로 다시 계산하지 않음 · 몸 좌표 = 창 좌표 − 머리)
local function relayoutV3()
	local phone = built.v3phone
	local key = "v3:" .. tostring(phone) .. ":" .. tostring(S.tab)
	if key == lastLayout then
		return false
	end
	lastLayout = key
	local P = phone and L3.phone or L3.pc
	local top = P.head + P.line
	S.phone = phone
	S.v3 = true
	S.claimH = P.tabs[4]
	S.cellW = P.cell
	S.cellH = (S.cellW - 12) + 18 + Theme.textSize("caption") * 2
	local full = S.tab == "boss"
	local G = full and P.full or P.grid
	S.gridW = G[3]
	S.detailW = P.detail[3]
	-- 탭 7 = 같은 폭 · 글 + %(그림 없음)
	built.top.Position = UDim2.fromOffset(P.tabs[1], P.tabs[2] - top)
	built.top.Size = UDim2.fromOffset(P.tabs[3], P.tabs[4])
	built.tabRow.Size = UDim2.fromScale(1, 1)
	local n = #Info.tabs
	local tw = math.floor((P.tabs[3] - (n - 1) * P.tabs.gap) / n)
	for i, t in ipairs(Info.tabs) do
		local b = built.tabButtons[t.id]
		b.Size = UDim2.fromOffset(tw, P.tabs[4])
		b.Position = UDim2.fromOffset((i - 1) * (tw + P.tabs.gap), 0)
		b.Icon.Visible = false
		b.Label.Position = UDim2.fromOffset(0, 0)
		b.Label.Size = UDim2.fromScale(1, 1)
		b.Label.RichText = true
		b.Label.TextSize = P.tabs.text
	end
	built.tabRow.CanvasSize = UDim2.fromOffset(0, 0)
	if P.band then -- 띠: 진행 + 상자 10 + [모두 받기](오른쪽)
		local B = P.band
		built.tokenBar.Visible = true
		built.tokenBar.Position = UDim2.fromOffset(B[1], B[2] - top)
		built.tokenBar.Size = UDim2.fromOffset(B[3], B[4])
		built.claimAll.root.Parent = built.tokenBar
		built.claimAll.root.AnchorPoint = Vector2.new(1, 0.5)
		built.claimAll.root.Position = UDim2.new(1, -12, 0.5, 0)
		built.claimAll.root.Size = UDim2.fromOffset(B.claimW, B.claimH)
		if built.boxRow then
			local R = built.boxRow
			R.head.Size = UDim2.new(0, B.headW, 1, 0)
			R.head.Position = UDim2.fromOffset(16, 0)
			R.head.Parent.Size = UDim2.fromScale(1, 1)
			local bar = R.fill.Parent
			bar.AnchorPoint = Vector2.new(0, 0.5)
			bar.Position = UDim2.new(0, B.headW + 40, 0.5, 6)
			bar.Size = UDim2.new(1, -(B.headW + 40 + B.claimW + 60), 0, 10)
			for n, box in ipairs(R.boxes) do -- 상자 = 막대 위 가운데(10%마다)
				box.Size = UDim2.fromOffset(B.box, B.box)
				box.AnchorPoint = Vector2.new(0.5, 0.5)
				box.Position = UDim2.new(n / #R.boxes, 0, 0.5, 0)
			end
		end
	else -- 폰: 띠 없음(머리 오른쪽 "전체 n%" · [모두 받기] = 머리)
		built.tokenBar.Visible = false
		built.claimAll.root.Parent = built.v3head
		built.claimAll.root.AnchorPoint = Vector2.new(1, 0.5)
		built.claimAll.root.Position = UDim2.new(1, -(P.close + 110), 0.5, 0)
		built.claimAll.root.Size = UDim2.fromOffset(110, P.head - 8)
	end
	built.gridArea.Position = UDim2.fromOffset(G[1], G[2] - top)
	built.gridArea.Size = UDim2.fromOffset(G[3], G[4])
	local D = P.detail
	built.detail.root.Position = UDim2.fromOffset(D[1], D[2] - top)
	built.detail.root.Size = UDim2.fromOffset(D[3], D[4])
	built.detail.root.Visible = not full and S.tab ~= "title"
	built.titleDetail.Position = built.detail.root.Position
	built.titleDetail.Size = built.detail.root.Size
	built.titleDetail.Visible = S.tab == "title"
	for id in pairs(scrolls) do
		dirty[id] = true
	end
	return true
end

local function relayout()
	if V3ON and built.v3 then
		return relayoutV3()
	end
	local screen = built.panel.screenGui.AbsoluteSize
	local phone = screen.X > 0 and (screen.X < PHONE_W or screen.Y < PHONE_H)
	local size = built.panel.content.AbsoluteSize
	local uiScale = built.panel.frame:FindFirstChildOfClass("UIScale") -- 열림 트윈(0.94 → 1)은 크기 변화로 안 본다
	local k = uiScale and uiScale.Scale > 0 and uiScale.Scale or 1
	local W = size.X > 0 and math.floor(size.X / k + 0.5) or PANEL_SIZE.X
	local H = size.Y > 0 and math.floor(size.Y / k + 0.5) or PANEL_SIZE.Y - 41
	local key = ("%s:%d:%d"):format(tostring(phone), W, H)
	if key == lastLayout then
		return false
	end
	lastLayout = key
	S.phone = phone
	S.claimH = phone and 60 or 48
	local ts = Theme.textSize("caption")
	S.cellW = phone and 86 or 92
	S.cellH = (S.cellW - 12) + 18 + ts * 2
	S.detailW = phone and math.clamp(math.floor(W * 0.36), 210, 280) or 250
	S.gridW = W - S.detailW - PAD * 3
	local top = built.top
	top.Size = UDim2.new(1, -PAD * 2, 0, S.claimH)
	built.tabRow.Size = UDim2.new(1, -(ALL_W + PAD), 1, 0)
	local tw = 68 -- 8칸 × (68 + 4) = 576 = PC 720 · 폰 736 창에서 [모두 받기] 옆에 스크롤 없이 들어간다
	for i, t in ipairs(Info.tabs) do
		local b = built.tabButtons[t.id]
		b.Size = UDim2.fromOffset(tw, S.claimH)
		b.Position = UDim2.fromOffset((i - 1) * (tw + 4), 0)
		b.Icon.Size = UDim2.fromOffset(S.claimH - ts - 12, S.claimH - ts - 12)
		b.Label.Position = UDim2.new(0, 0, 1, -(ts + 4))
		b.Label.Size = UDim2.new(1, 0, 0, ts + 2)
	end
	built.tabRow.CanvasSize = UDim2.fromOffset(#Info.tabs * (tw + 4), 0)
	built.claimAll.root.Size = UDim2.fromOffset(ALL_W, S.claimH)
	local tokenH = phone and 44 or 30 -- QUEUE-ALL9C 1-11 토큰 진행 줄(폰 = 버튼 44)
	if Info.V2 then
		tokenH = phone and 48 or 56 -- UI-1 5단계: 진행 줄(막대 + 상자 10)
	end
	local tokenY = PAD + S.claimH + 6
	-- QUEUE-ALL9C 2-6: 낮은 폰(본문이 칸 2줄보다 낮음) = 토큰 줄을 오른쪽 상세 칸 위로 옮겨 칸 목록 높이를 돌려준다(작은 폰 389에서 칸이 1줄만 보이던 것)
	local stacked = phone and (H - (tokenY + tokenH + 6) - PAD) < 2 * (70 + 8) + 40
	local detailTop
	if stacked then
		built.tokenBar.Position = UDim2.new(1, -(S.detailW + PAD), 0, tokenY)
		built.tokenBar.Size = UDim2.fromOffset(S.detailW, 22 + 4 + tokenH)
		built.tokenGauge.root.Size = UDim2.fromOffset(S.detailW, 22)
		built.tokenGauge.root.Position = UDim2.fromOffset(0, 0)
		built.tokenNeed.Visible = false -- 남은 토큰 = 게이지 글자
		built.tokenWhere.root.Size = UDim2.fromOffset(S.detailW, tokenH)
		built.tokenWhere.root.AnchorPoint = Vector2.new(0, 0)
		built.tokenWhere.root.Position = UDim2.fromOffset(0, 26)
		detailTop = tokenY + 22 + 4 + tokenH + 6
	else
		built.tokenBar.Position = UDim2.fromOffset(PAD, tokenY)
		built.tokenBar.Size = UDim2.new(1, -PAD * 2, 0, tokenH)
		local gaugeW = math.max(120, W - PAD * 2 - WHERE_W - NEED_W - 16)
		built.tokenGauge.root.Size = UDim2.fromOffset(gaugeW, 22)
		built.tokenGauge.root.Position = UDim2.new(0, 0, 0.5, -11)
		built.tokenNeed.Visible = true
		built.tokenNeed.Position = UDim2.fromOffset(gaugeW + 8, 0)
		built.tokenNeed.Size = UDim2.new(0, NEED_W, 1, 0)
		built.tokenWhere.root.Size = UDim2.fromOffset(WHERE_W, tokenH)
		built.tokenWhere.root.AnchorPoint = Vector2.new(1, 0)
		built.tokenWhere.root.Position = UDim2.new(1, 0, 0, 0)
	end
	local bodyY = stacked and tokenY or (tokenY + tokenH + 6)
	detailTop = detailTop or bodyY
	built.gridArea.Position = UDim2.fromOffset(PAD, bodyY)
	built.gridArea.Size = UDim2.new(1, -(S.detailW + PAD * 3), 1, -(bodyY + PAD))
	built.detail.root.Position = UDim2.new(1, -(S.detailW + PAD), 0, detailTop)
	built.detail.root.Size = UDim2.new(0, S.detailW, 1, -(detailTop + PAD))
	for id in pairs(scrolls) do
		dirty[id] = true
	end
	S.boardScrolled = false
	return true
end

local function selectFirstClaimable()
	S.selected = nil
	local view = S.view
	if not view then
		return
	end
	if S.tab == "board" then
		local nextOne
		for _, b in ipairs(view.board) do
			if b.done and not b.claimed then
				S.selected = { kind = "board", id = "board:" .. b.threshold, threshold = b.threshold }
				return
			end
			if not b.done and not nextOne then
				nextOne = b
			end
		end
		if nextOne then
			S.selected = { kind = "board", id = "board:" .. nextOne.threshold, threshold = nextOne.threshold }
		end
		return
	end
	if S.tab == "armor" then
		for _, z in ipairs(Info.zones) do
			for _, g in ipairs(CodexData.armor.grades) do
				for _, p in ipairs(Info.parts) do
					local c = view.cells[("armor:%s:%s:%s"):format(z.key, g, p)]
					if c and c.done and not c.claimed then
						S.selected = { kind = "bingo", id = ("bingo:%s:%s"):format(z.key, g), zone = z.key, grade = g }
						return
					end
				end
			end
		end
	end
	local best
	for id, c in pairs(view.cells) do
		if c.tab == S.tab and c.done and not c.claimed and (not best or id < best) then
			best = id
		end
	end
	if best then
		S.selected = { kind = "cell", id = best }
	end
end

function S.select(sel)
	S.selected = sel
	if V3ON and built.v3 and V3TABS[S.tab] then -- UI-1c 4단계: 고른 칸 테 = 다시 그림 · 보스 · 칭호 = 옛 상세 안 씀
		renderTab(S.tab)
		if S.tab == "title" then
			V3.titleDetail(S, built.titleDetail)
		elseif S.tab ~= "boss" then
			built.detail.show()
		end
		return
	end
	if S.tab == "board" then
		renderTab("board")
	else
		local sc = scrolls[S.tab]
		for _, c in ipairs(sc and sc:GetChildren() or {}) do
			local id = c:GetAttribute("CodexCell")
			local st = id and c:FindFirstChildOfClass("UIStroke")
			if st and c:GetAttribute("CodexState") then
				Grid.styleStroke(st, c:GetAttribute("CodexState"), sel and sel.id == id)
			end
		end
	end
	built.detail.show()
end

-- UI-1c 4단계 v3 창 틀: ScreenGui(Sibling) + 기준 화면 루트(UIScale) + 창(머리 = 책 아이콘 · 도감 28 · [?] · "천천히 모아 보는 곳" · 재화 칩 3 · 닫기) → Panel.create와 같은 refs
local function buildShellV3(onOpen, onClose)
	Theme.recompute()
	local phone = Theme.isMobile
	local P = phone and L3.phone or L3.pc
	local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
	local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
	local V9 = require(script.Parent.Parent.ui.v2.UiV9)
	local CurrencyBar = require(script.Parent.Parent.ui.CurrencyBar)
	local InfoTip = require(script.Parent.Parent.ui.v2.InfoTip)
	local base = phone and HudPlace.base.phone or HudPlace.base.pc
	local gui = Instance.new("ScreenGui")
	gui.Name = "CodexV3Gui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(base.w, base.h)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local v = gui.AbsoluteSize
		if v.X > 1 then
			scale.Scale = math.min(v.X / base.w, v.Y / base.h)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	local C = L3.colors
	local win = V9.frame(root, P.win, C.window, "Window")
	V9.corner(win, phone and 14 or 18)
	V9.stroke(win, C.stroke, 3)
	local head = V9.frame(win, { 0, 0, P.win[3], P.head }, nil, "Head")
	V9.frame(win, { 0, P.head, P.win[3], P.line }, "FFC83D", "AccentLine")
	local icon = UiKit.icon(head, "book", phone and 26 or 40)
	icon.Position = UDim2.fromOffset(phone and 12 or 20, math.floor((P.head - (phone and 26 or 40)) / 2))
	local tx = (phone and 12 or 20) + (phone and 26 or 40) + 10
	local title = V9.label(head, Text.get("ui1c.codex.title"), V9.px(P.title), "FFFFFF", { name = "Title", font = "korean", rect = { tx, 0, 200, P.head } })
	title.AutomaticSize = Enum.AutomaticSize.X
	title.Size = UDim2.fromOffset(0, P.head)
	title.TextTruncate = Enum.TextTruncate.None
	local hb = require(script.Parent.Parent.ui.v2.HelpButton).besideLabel(title, "codex")
	hb.Size = UDim2.fromOffset(phone and 26 or 36, phone and 26 or 36)
	if P.sub > 0 then
		local sub = V9.label(head, Text.get("ui1c.codex.sub"), V9.px(P.sub), C.muted, { name = "Sub" })
		task.defer(function()
			local s = scale.Scale > 0 and scale.Scale or 1
			sub.Position = UDim2.fromOffset(tx + title.AbsoluteSize.X / s + 56, 0)
		end)
		sub.Size = UDim2.fromOffset(400, P.head)
	end
	UiKit.closeButton({ parent = head, name = "Close", rect = { P.win[3] - P.close - 12, math.floor((P.head - P.close) / 2), P.close, P.close }, onActivated = function()
		UIManager.close(CodexPanel.id)
	end })
	local total
	if P.chipH > 0 then -- 머리 재화 칩 3(높이 44 · 아이콘 28 · 이름 + 숫자 · 누르면 설명 = HUD 칩과 같은 틀)
		local x = P.win[3] - P.close - 24
		for i = 3, 1, -1 do
			local id = ({ "gold", "sparkleShard", "enhanceStone" })[i]
			local chip = Instance.new("TextButton")
			chip.Name = "Chip_" .. id
			chip.AutoButtonColor = false
			chip.Text = ""
			chip.BackgroundColor3 = Color3.fromHex("0E1120")
			chip.AnchorPoint = Vector2.new(1, 0.5)
			chip.Size = UDim2.fromOffset(150, P.chipH)
			chip.Position = UDim2.new(0, x, 0.5, 0)
			chip.Parent = head
			V9.corner(chip, "pill")
			V9.stroke(chip, C.stroke, 2)
			local ic = ArtImage.label(chip, "icons/reward/" .. id, UDim2.fromOffset(P.chipIcon, P.chipIcon), "")
			ic.Position = UDim2.fromOffset(10, math.floor((P.chipH - P.chipIcon) / 2))
			V9.label(chip, Text.get("item.name." .. id), V9.px(15), C.muted, { rect = { P.chipIcon + 16, 2, 120, 18 } })
			local num = V9.label(chip, "", V9.px(18), "FFFFFF", { font = "number", rect = { P.chipIcon + 16, 20, 120, 22 } })
			local function upd()
				num.Text = CurrencyBar.text(CurrencyBar.valueOf(id))
			end
			Players.LocalPlayer:GetAttributeChangedSignal(CurrencyBar.attrOf(id)):Connect(upd)
			upd()
			chip.Activated:Connect(function()
				InfoTip.currency(chip, id)
			end)
			x -= 150 + 10
		end
	else -- 폰: "전체 n%"
		total = V9.label(head, "", V9.px(14), "FFFFFF", { name = "TotalPct", rich = true, align = Enum.TextXAlignment.Right, rect = { P.win[3] - P.close - 220 - 128, 0, 120, P.head } }) -- [모두 받기](닫기 왼쪽 110 · 폭 110) 왼쪽
	end
	local body = V9.frame(win, { 0, P.head + P.line, P.win[3], P.win[4] - P.head - P.line }, nil, "Content")
	UIManager.register(CodexPanel.id, {
		kind = "window",
		screenGui = gui,
		hasCloseButton = true,
		onOpen = function()
			gui.Enabled = true
			onOpen()
		end,
		onClose = function()
			gui.Enabled = false
			onClose()
		end,
	})
	return { screenGui = gui, frame = win, content = body, titleLabel = title, head = head, totalLabel = total, phone = phone }
end

local function build()
	local function onOpen()
		task.defer(function()
			CodexPanel.render()
			S.send("view")
		end)
	end
	local function onClose()
		if built then
			built.detail.stop()
		end
	end
	local panel = V3ON and buildShellV3(onOpen, onClose) or Panel.create({ id = CodexPanel.id, kind = "window", title = Text.name(CodexData.text.title), size = PANEL_SIZE, helpId = "codex", -- UI-1b 1절 3: 상자 · 별 · 칭호 규칙
		onOpen = onOpen, onClose = onClose })
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BackgroundTransparency = 1
	top.Position = UDim2.fromOffset(PAD, PAD)
	top.Parent = panel.content
	local tabRow = Instance.new("ScrollingFrame")
	tabRow.Name = "Tabs"
	tabRow.BackgroundTransparency = 1
	tabRow.BorderSizePixel = 0
	tabRow.ScrollBarThickness = 3
	tabRow.ScrollingDirection = Enum.ScrollingDirection.X
	tabRow.Parent = top
	local tabButtons = {}
	for _, t in ipairs(Info.tabs) do
		local b = Instance.new("TextButton")
		b.Name = "Tab_" .. t.id
		b.AutoButtonColor = false
		b.Text = ""
		b.Parent = tabRow
		Theme.corner(b, 10)
		local icon = ArtImage.label(b, "icons/codex/tab_" .. t.icon, nil, "")
		icon.Name = "Icon"
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 4)
		local l = Theme.label(b, Text.get("codex.v2.tab." .. t.id), "caption", "textPrimary")
		l.Name = "Label"
		l.Font = Theme.font
		l.TextXAlignment = Enum.TextXAlignment.Center
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(1, 0)
		dot.Position = UDim2.new(1, -3, 0, 3)
		dot.Size = UDim2.fromOffset(10, 10)
		dot.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
		dot.Visible = false
		dot.Parent = b
		Theme.corner(dot, 5)
		b.Activated:Connect(function()
			CodexPanel.setTab(t.id)
		end)
		tabButtons[t.id] = b
	end
	local all = Button.build({ parent = top, kind = "claim", text = Text.get("codex.v2.claimAll"), width = ALL_W, height = 48,
		position = UDim2.new(1, 0, 0, 0), anchorPoint = Vector2.new(1, 0), onActivated = claimAll })
	all.root.Name = "ClaimAll"
	local gridArea = Instance.new("Frame")
	gridArea.Name = "GridArea"
	gridArea.BackgroundTransparency = 1
	gridArea.ClipsDescendants = true
	gridArea.Parent = panel.content
	-- QUEUE-ALL9C 1-11 토큰 진행 줄
	local tokenBar = Instance.new("Frame")
	tokenBar.Name = "TokenProgress"
	tokenBar.BackgroundTransparency = 1
	tokenBar.Parent = panel.content
	local tokenGauge = Gauge.build({ parent = tokenBar, height = 22, width = 200, trackColorName = "slot", fillColorName = "gold", value = 0, text = "" })
	tokenGauge.root.Name = "TokenGauge"
	local tokenNeed = Theme.label(tokenBar, "", "caption", "textSecondary")
	tokenNeed.Name = "TokenNeed"
	tokenNeed.TextYAlignment = Enum.TextYAlignment.Center
	local tokenWhere = Button.build({ parent = tokenBar, name = "TokenWhere", kind = "secondary", text = Text.get("codex.token.where"), width = WHERE_W, height = 30,
		position = UDim2.new(1, 0, 0, 0), anchorPoint = Vector2.new(1, 0), onActivated = function()
			UIManager.close(CodexPanel.id)
			require(script.Parent.Quests).open()
		end })
	built = { panel = panel, top = top, tabRow = tabRow, tabButtons = tabButtons, claimAll = all, gridArea = gridArea,
		tokenBar = tokenBar, tokenGauge = tokenGauge, tokenNeed = tokenNeed, tokenWhere = tokenWhere }
	if V3ON then -- UI-1c 4단계: v3 틀 표시 · 칭호 상세 판(오른쪽 · 칭호 탭만)
		built.v3, built.v3phone, built.v3head = true, panel.phone, panel.head
		local td = Instance.new("Frame")
		td.Name = "TitleDetail"
		td.BackgroundColor3 = Color3.fromHex(L3.colors.panel)
		td.Visible = false
		td.Parent = panel.content
		Theme.corner(td, 14)
		built.titleDetail = td
	end
	if Info.V2 then -- UI-1 5단계(08 v4-codex §5): 진행 줄 = "전체 진행 n / 362칸 · p%" + 막대 + 상자 10개(10%마다 · 60% · 70% = 토큰 상자) · 상자 = 누르면 보상 창(토글)
		tokenGauge.root.Visible = false
		tokenNeed.Visible = false
		tokenWhere.root.Visible = false
		local row = Instance.new("Frame")
		row.Name = "ProgressV2"
		row.BackgroundTransparency = 1
		row.Size = UDim2.fromScale(1, 1)
		row.Parent = tokenBar
		local head = Theme.label(row, "", "caption", "textPrimary")
		head.Name = "Head"
		head.Size = UDim2.new(0, 150, 1, 0)
		head.TextWrapped = true
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.BackgroundColor3 = Color3.fromRGB(26, 31, 51)
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 160, 1, -6)
		bar.Size = UDim2.new(1, -176, 0, 10)
		bar.Parent = row
		Theme.corner(bar, 5)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Color3.fromHex("FFC83D")
		fill.Size = UDim2.fromScale(0, 1)
		fill.Parent = bar
		Theme.corner(fill, 5)
		local boxes = {}
		for n = 1, CodexData.boxes.count do
			local b = Instance.new("ImageButton")
			b.Name = "Box" .. n
			b.BackgroundTransparency = 1
			b.AnchorPoint = Vector2.new(0.5, 1)
			b.Position = UDim2.new(n / CodexData.boxes.count, 0, 0, -2)
			b.Size = UDim2.fromOffset(30, 30)
			b.Parent = bar
			local dot = Instance.new("Frame")
			dot.Name = "Dot"
			dot.AnchorPoint = Vector2.new(1, 0)
			dot.Position = UDim2.new(1, 2, 0, -2)
			dot.Size = UDim2.fromOffset(10, 10)
			dot.BackgroundColor3 = Color3.fromRGB(235, 60, 60)
			dot.Visible = false
			dot.Parent = b
			Theme.corner(dot, 5)
			boxes[n] = b
		end
		if Theme.isMobile then -- UI-1b 2절 5: 폰 = 머리 위 줄 · 막대 전체 폭 · 상자 = 막대 폭 ÷ 10
			local R = require(ReplicatedStorage.Shared.data.UiLayoutData).codexBoxRow
			head.Size = UDim2.new(1, 0, 0, R.phoneHeadH)
			bar.Position = UDim2.new(0, 0, 1, -6)
			bar.Size = UDim2.new(1, -4, 0, R.phoneBarH)
			local function fitBoxes()
				local s = math.clamp(math.floor(bar.AbsoluteSize.X / CodexData.boxes.count) - R.gap, 12, R.box)
				for n, b in ipairs(boxes) do
					b.Size = UDim2.fromOffset(s, s)
					b.Position = UDim2.new((n - 0.5) / CodexData.boxes.count, 0, 0, -2) -- 칸 가운데(끝 상자가 막대 밖으로 반 나가지 않게)
				end
			end
			bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitBoxes)
			fitBoxes()
		end
		local pop = Instance.new("Frame")
		pop.Name = "BoxPopup"
		pop.BackgroundColor3 = Color3.fromHex("161A2B")
		pop.Size = UDim2.fromOffset(260, 120)
		pop.Visible = false
		pop.ZIndex = 20
		pop.Parent = panel.content
		Theme.corner(pop, 10)
		local pst = Instance.new("UIStroke")
		pst.Color = Color3.fromHex("3A4466")
		pst.Parent = pop
		local popText = Theme.label(pop, "", "caption", "textPrimary")
		popText.Position, popText.Size = UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 64)
		popText.TextWrapped = true
		popText.TextYAlignment = Enum.TextYAlignment.Top
		popText.ZIndex = 21
		local popClaim = Button.build({ parent = pop, kind = "claim", text = Text.get("codex.v2.claim"), width = 120, height = 40,
			position = UDim2.new(1, -10, 1, -8), anchorPoint = Vector2.new(1, 1), onActivated = function()
				if built.boxOpen then
					S.send("claim", "box:" .. built.boxOpen)
					pop.Visible = false
					built.boxOpen = nil
				end
			end })
		popClaim.root.ZIndex = 21
		local function lift(node, z) -- 창 = ZIndex 전체 모드: 진행 줄 · 상자 · 보상 창을 창 바탕 위로(깊이만큼 +1)
			if node:IsA("GuiObject") then
				node.ZIndex = z
			end
			for _, c in ipairs(node:GetChildren()) do
				lift(c, z + 1)
			end
		end
		lift(row, 6)
		lift(pop, 30)
		built.boxRow = { head = head, fill = fill, boxes = boxes, pop = pop, popText = popText, popClaim = popClaim }
		for n, b in ipairs(boxes) do
			b.Activated:Connect(function()
				if built.boxOpen == n then -- 같은 상자 다시 = 닫힘(토글)
					pop.Visible = false
					built.boxOpen = nil
					return
				end
				built.boxOpen = n
				CodexPanel.renderTokens()
			end)
		end
	end
	built.detail = Detail.build(panel.content, S)
	relayout()
	if V3ON then -- 탭이 바뀌면 배치(보스 = 전체 폭 · 칭호 = 칭호 상세)도 다시
		lastLayout = nil
	end
	panel.content:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if relayout() then
			CodexPanel.render()
		end
	end)
end

function CodexPanel.render()
	if not built or not UIManager.isOpen(CodexPanel.id) then
		return
	end
	if V3ON and built.v3 then
		relayout()
	end
	for id, b in pairs(built.tabButtons) do
		local on = id == S.tab
		b.BackgroundColor3 = on and Color3.fromRGB(96, 80, 160) or Color3.fromRGB(40, 44, 60)
		b.Label.TextColor3 = on and Theme.colors.textPrimary or Theme.colors.textSecondary
		b.Dot.Visible = tabClaimable(id)
		if V3ON and built.v3 then -- UI-1c 4단계: 탭 = 노랑(고름) · 글 + %(PC) · 빨간 점
			local C = L3.colors
			b.BackgroundColor3 = Color3.fromHex(on and C.tabOn or C.tabOff)
			b.Label.TextColor3 = Color3.fromHex(on and C.tabOnText or C.tabOffText)
			local name = Text.get("ui1c.codex.tab." .. ((built.v3phone and id == "class") and "classShort" or id))
			local pct = S.view and V3.tabStats(S.view, id)
			b.Label.Text = (pct and not built.v3phone) and ('%s  <font size="%d">%d%%</font>'):format(name, L3.pc.tabs.pct, pct) or name
		end
	end
	for id, sc in pairs(scrolls) do
		sc.Visible = id == S.tab
	end
	local view = S.view
	if not view then
		built.panel.titleLabel.Text = Text.name(CodexData.text.title)
		return
	end
	if not (V3ON and built.v3) then
		built.panel.titleLabel.Text = Text.get("codex.v2.titleScore", { score = tostring(view.score), total = tostring(view.total) })
	elseif built.panel.totalLabel then -- 폰 머리 "전체 n%"
		built.panel.totalLabel.Text = Text.get("ui1c.codex.totalPhone", { pct = ("%d"):format(math.floor((view.total > 0 and view.score / view.total or 0) * 100)) })
	end
	CodexPanel.renderTokens()
	local anyClaim = false
	for _, t in ipairs(Info.tabs) do
		anyClaim = anyClaim or tabClaimable(t.id)
	end
	built.claimAll.setEnabled(anyClaim)
	local sc = ensureScroll(S.tab)
	sc.Visible = true
	if dirty[S.tab] then
		renderTab(S.tab)
	end
	if V3ON and built.v3 and S.tab == "title" then
		V3.titleDetail(S, built.titleDetail)
		return
	elseif V3ON and built.v3 and S.tab == "boss" then
		return
	end
	built.detail.show()
end

-- QUEUE-ALL9C 1-11 토큰 진행(상점 "다음 499급"과 같은 식 · 지갑 = SparkleShard)
function CodexPanel.renderTokens()
	if not built then
		return
	end
	if Info.V2 and built.boxRow then -- UI-1 5단계 진행 상자
		local view = S.view
		local B = built.boxRow
		if not view or not view.boxes then
			return
		end
		local p = view.total > 0 and view.score / view.total or 0
		B.head.Text = Text.get("ui1.codex.progress", { have = tostring(view.score), total = tostring(view.total), pct = ("%d"):format(math.floor(p * 100)) })
		if V3ON and built.v3 then -- UI-1c: 띠 머리 = "전체 진행 n / 전체칸" + 큰 %
			B.head.RichText = true
			B.head.Text = ('%s  <font size="15">%s</font>\n<font size="30"><b>%d%%</b></font>'):format(Text.get("ui1c.codex.total"), Text.get("ui1c.codex.totalCells", { have = tostring(view.score), total = tostring(view.total) }), math.floor(p * 100))
		end
		B.fill.Size = UDim2.fromScale(math.clamp(p, 0, 1), 1)
		for n, box in ipairs(view.boxes) do
			local b = B.boxes[n]
			local token = (box.sparkleShard or 0) > 0
			local state = box.claimed and "open" or (box.done and "ready" or "locked")
			b.Image = ArtImage.get(("ui/codex/codex-box-%s-%s"):format(token and "token" or "normal", state)) or ""
			b.Dot.Visible = box.done and not box.claimed
		end
		local n = built.boxOpen
		local box = n and view.boxes[n]
		B.pop.Visible = box ~= nil
		if box then
			local parts = {}
			if (box.gold or 0) > 0 then
				table.insert(parts, Text.get("ui1.codex.boxGold", { n = NumberFormat.commas(math.floor(box.gold)) }))
			end
			if (box.enhanceStone or 0) > 0 then
				table.insert(parts, Text.get("ui1.codex.boxStone", { n = tostring(box.enhanceStone) }))
			end
			if (box.sparkleShard or 0) > 0 then
				table.insert(parts, Text.get("ui1.codex.boxToken", { n = tostring(box.sparkleShard) }))
			end
			local state = box.claimed and Text.get("ui1.codex.boxClaimed") or (box.done and "" or Text.get("ui1.codex.boxLocked", { pct = tostring(n * 10), now = ("%d"):format(math.floor(p * 100)) }))
			B.popText.Text = Text.get("ui1.codex.boxTitle", { pct = tostring(n * 10) }) .. "\n" .. table.concat(parts, " · ") .. (state ~= "" and ("\n" .. state) or "")
			B.popClaim.root.Visible = box.done and not box.claimed
			local bAbs, cAbs = B.boxes[n].AbsolutePosition, built.panel.content.AbsolutePosition
			local x = math.clamp(bAbs.X - cAbs.X - 130, 4, math.max(4, built.panel.content.AbsoluteSize.X - 264))
			B.pop.Position = UDim2.fromOffset(x, bAbs.Y - cAbs.Y + 42)
		end
		return
	end
	local have = Players.LocalPlayer:GetAttribute("SparkleShard") or 0
	local p = Monetization.premiumTokenProgress(MonetizationData, have)
	local lang = Text.languageFor()
	built.tokenGauge.setValue(p.ratio, Text.get("codex.token.bar", { have = NumberFormat.commas(math.min(have, p.price)), price = NumberFormat.commas(p.price) }))
	built.tokenNeed.Text = p.need > 0 and Text.get("codex.token.need", { n = NumberFormat.currency(p.need, lang) }) or Text.get("codex.token.ready")
	built.tokenNeed.TextColor3 = p.need > 0 and Theme.colors.textSecondary or Theme.colors.success
end

function CodexPanel.open()
	if not built then
		build()
	end
	if not UIManager.isOpen(CodexPanel.id) and not UIManager.open(CodexPanel.id) then
		return false
	end
	CodexPanel.render()
	S.send("view")
	return true
end

function CodexPanel.init()
	if not built then
		build()
	end
	Players.LocalPlayer:GetAttributeChangedSignal("SparkleShard"):Connect(CodexPanel.renderTokens) -- QUEUE-ALL9C 1-11
	updateRemote.OnClientEvent:Connect(function(v)
		local first = S.view == nil
		S.view = v
		Info.indexNests(v)
		for id in pairs(scrolls) do
			dirty[id] = true
		end
		if first then
			selectFirstClaimable()
		end
		checkPending()
		CodexPanel.render()
	end)
	ReplicatedStorage:WaitForChild("CodexNotice").OnClientEvent:Connect(function(key, args)
		-- QUEUE-ALL6R 3: 서버 = 키 + 인자 → 내 언어로 조합
		if type(args) == "table" and type(args.titleId) == "string" then
			args.title = require(ReplicatedStorage.Shared.CodexRules).titleText(args.titleId, args.title) -- 도감 칭호 = 틀 + 이름 따로(합친 이름은 사전에 없다)
		end
		local text = type(key) == "string" and Text.get(key, type(args) == "table" and args or nil)
		if text and not (workspace:GetAttribute("ArtStyleV1") == true and key == "srv.codex.lineDone") then -- QUEUE-ALL2 P4: 아트 켬 = 줄 칭호는 CodexMoments 배너가 알림(중복 막기)
			Toast.push("TC", { richParts = { { text = text, color = Theme.colors.gold, bold = true } }, seconds = 4, fadeSeconds = 0.3 })
		end
	end)
end

-- 점검 · 스크린샷용
function CodexPanel.setTab(id)
	if V3ON and built and built.v3 and S.tab ~= id then
		lastLayout = nil -- 보스 = 전체 폭 · 칭호 = 칭호 상세
	end
	S.tab = id
	S.boardScrolled = false
	selectFirstClaimable()
	CodexPanel.render()
end

-- Studio 전용 점검: 모든 탭을 실제로 그려 그림 없는 칸 수를 센다(기대 0). 칸 = Attribute CodexCell이 달린 인스턴스 · 그림 = 이름 Pic · Pic2 · Icon(보상) 인 ImageLabel(Image 비어 있거나 글자 대체면 빈 칸)
--   반환 = 빈 칸 수, { [탭] = 빈 칸 수 }, { [탭] = 칸 수 }, 빈 칸 id 목록(앞 20개). 탭 그림(8개)도 같이 센다.
function CodexPanel.debugEmptyPictureCount()
	if not RunService:IsStudio() then
		return nil
	end
	if not built then
		build()
	end
	if not S.view then
		warn("[Codex] 표가 아직 없음 - 창을 한 번 열거나 CodexRequest view 뒤에 다시")
		return -1
	end
	local total, per, counts, samples = 0, {}, {}, {}
	for _, t in ipairs(Info.tabs) do
		local sc = ensureScroll(t.id)
		renderTab(t.id)
		local miss, n = 0, 0
		for _, cell in ipairs(sc:GetChildren()) do
			local id = cell:GetAttribute("CodexCell")
			if id then
				n += 1
				local pics, bad = 0, false
				for _, d in ipairs(cell:GetDescendants()) do
					if d.Name == "Pic" or d.Name == "Pic2" or d.Name == "Icon" then
						pics += 1
						if not d:IsA("ImageLabel") or d.Image == "" then
							bad = true
						end
					end
				end
				if pics == 0 or bad then
					miss += 1
					if #samples < 20 then
						table.insert(samples, id)
					end
				end
			end
		end
		per[t.id], counts[t.id] = miss, n
		total += miss
		sc.Visible = t.id == S.tab
	end
	for id, b in pairs(built.tabButtons) do
		if not b.Icon:IsA("ImageLabel") or b.Icon.Image == "" then
			total += 1
			table.insert(samples, "tab:" .. id)
		end
	end
	local parts = {}
	for _, t in ipairs(Info.tabs) do
		table.insert(parts, ("%s %d/%d"):format(t.id, per[t.id], counts[t.id]))
	end
	print(("[Codex][그림] 빈 칸 %d · %s%s"):format(total, table.concat(parts, " · "), #samples > 0 and (" · 예: " .. table.concat(samples, ", ")) or ""))
	return total, per, counts, samples
end

return CodexPanel
