-- 보스 체력바 HUD(S19b A). 보스전 중에만 화면 상단 가운데(ScreenMap TC.bossBar)에 보스 이름 + 체력바를 그린다(아트 켬 = QUEUE-ALL1 하단 가운데 틀 · hud/BossHudLayout). 머리 위 보스 바는 없다(서버 MonsterSpawner가 안 만든다).
-- 전달 방식: 서버가 보스 모델 Attribute BossHpRatio(0 ~ 1)와 BossName을 걸고(HP 계산은 서버만), 이 HUD는 읽어서 표시만 한다. RemoteEvent를 안 쓴다.
-- "내 보스": 서버(BossEncounter)가 보스 모델과 멤버 Player에 같은 번호 BossEncounterId를 건다 - 내 Attribute와 같은 번호의 Monster 태그 모델이 내 보스다(다른 파티의 보스 · 구출 대상은 번호가 다르다).
-- 갱신은 0.1초(= 초당 최대 10회)마다 한 번만 읽는다. 값 변화는 Gauge가 0.15초 트윈으로 부드럽게 채운다.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Gauge = require(script.Parent.Parent.ui.kit.Gauge)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local PartyListView = require(script.Parent.PartyListView)
local Text = require(game:GetService("ReplicatedStorage").Shared.Text)

local REFRESH_SECONDS = 0.1
local NAME_HEIGHT = 22
local GAP = 2

local player = Players.LocalPlayer

local function build()
	local slot = ScreenMap.slot("TC", "bossBar")
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BossBarGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = slot.instanceName
	root.BackgroundTransparency = 1
	root.Size = slot.size
	root.Visible = false
	ScreenMap.place(root, "TC", "bossBar")
	root.Parent = screenGui

	local nameLabel = Theme.label(root, "", "header", "textPrimary")
	nameLabel.Name = "BossName"
	nameLabel.Size = UDim2.new(1, 0, 0, NAME_HEIGHT)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextStrokeTransparency = 0.5 -- 3D 화면 위에 그려지므로 글씨 외곽선

	local gauge = Gauge.build({
		parent = root,
		name = "BossHpGauge",
		height = 16,
		width = slot.size.X.Offset,
		position = UDim2.new(0, 0, 0, NAME_HEIGHT + GAP),
		value = 1,
	})
	return { root = root, nameLabel = nameLabel, gauge = gauge, screenGui = screenGui, slotWidth = slot.size.X.Offset, slotHeight = slot.size.Y.Offset }
end

local refs = build()

-- 폰(모바일 축약형 파티 목록: 메뉴바 오른쪽 옆 x = 여백 14 + 버튼 48 + 8, 폭 96)에서는 화면 폭이 좁으면 슬롯 폭(360)이 목록과 겹친다 - 목록 오른쪽 끝 + 8보다 안쪽으로만 폭을 줄인다(가운데 정렬).
-- PC는 슬롯 폭 그대로. 좁아도 160 아래로는 안 줄인다.
local MIN_MOBILE_WIDTH = 160
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")
local ArtV1UiData = require(game:GetService("ReplicatedStorage").Shared.data.ArtV1UiData)
local ArtStyleV1Data = require(game:GetService("ReplicatedStorage").Shared.data.ArtStyleV1Data)
local nameInBar = nil -- A2-N4 메이플식: 막대 안 이름(아트 켬 - QUEUE-ALL1에서 하단 틀로 바뀌어 안 만든다)
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local BossHudLayout = require(script.Parent.BossHudLayout)
local HB = ArtV1UiData.bossHud
-- UI-1 2단계(02 v6 §5 · F v2 0절 4): 스위치 UiV2Flags.hud = 보스 바 위 가운데(PC 560, 66, 800 · 폰 244, 62, 326) · 표시선 50% · 20% · 보스 상태 아이콘(이름 줄 오른쪽) · 폼 꼬리표 = 폭풍 군주만 ·
--   변신 무적 = 채움 회색 + 사선 무늬 · BREAK 게이지 · 내 기여 % = 데이터 없음 → 그 줄 숨김(MISSING 5 · 6) · 위쪽 알림(TC 줄) = 보스 바 바로 아래로.
local V6ON = require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).hud
local V6 = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).hud.v6
local HudPlace = require(game:GetService("ReplicatedStorage").Shared.HudPlace)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local v6 = nil -- { ticks, statusRow, form, stripes }
local boss = nil -- 지금 표시 중인 보스 모델

-- UI-1 3단계 2폼 카드(08 v5-auto-boss §7 · F v2 §1-6): 폭풍 군주 변신 무적이 시작되는 순간 · 보스 바 아래 가운데(PC y 190 · 폰 130) · 2폼 초상 140 + "2폼" + 이름 + 한 줄 ·
--   테 3 #8FE6FF · 2.5초 · 레터박스 없음(전투 계속) · 문구 = TextData_ui1 · 초 = BossFrameworkData.v3[보스].transformGuard.seconds(데이터)
local lastGuard = false
local function showForm2Card(bossId, bossModel)
	local RS = game:GetService("ReplicatedStorage")
	local PD = require(RS.Shared.data.BossPortraitData)
	local BossPortrait = require(script.Parent.Parent.ui.v2.BossPortrait)
	local tg = ((require(RS.Shared.data.BossFrameworkData).v3 or {})[bossId] or {}).transformGuard
	local phone = Theme.isMobile
	local view = workspace.CurrentCamera.ViewportSize
	local m = HudPlace.scale(view.X, view.Y, phone)
	local size = phone and PD.size.form2.phone or PD.size.form2.pc
	local color = BossPortrait.color(bossId, true)
	local card = Instance.new("CanvasGroup")
	card.Name = "Form2Card"
	card.BackgroundColor3 = Color3.fromHex("161A2B")
	card.BackgroundTransparency = 0.06
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Size = UDim2.fromOffset(size + (phone and 300 or 560), size + 24)
	card.Position = UDim2.new(0.5, 0, 0, HudPlace.topY(phone and PD.form2.y.phone or PD.form2.y.pc, 0, 0, m, phone and HudPlace.base.phone or HudPlace.base.pc))
	card.GroupTransparency = 1
	card.Parent = refs.screenGui
	local sc = Instance.new("UIScale")
	sc.Scale = m
	sc.Parent = card
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 16)
	c.Parent = card
	local st = Instance.new("UIStroke")
	st.Color = color
	st.Thickness = PD.form2.stroke
	st.Parent = card
	local portrait = BossPortrait.make(card, bossId, size, { form2 = true })
	portrait.Position = UDim2.fromOffset(12, 12)
	local x = size + 28
	local function lbl(text, y, px, col, font)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.new(1, -(x + 12), 0, px + 6)
		l.Font = font
		l.TextSize = px
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.TextWrapped = true
		l.TextColor3 = col
		l.Text = text
		l.Parent = card
		return l
	end
	local small = phone and 0.55 or 1
	lbl(Text.get("ui1.boss.form2"), 14, math.floor(22 * small + 0.5) + (phone and 4 or 0), color, Enum.Font.GothamBold)
	lbl(Text.get("ui1.form2." .. bossId .. ".name"), 14 + 30 * small + (phone and 6 or 0), math.floor(44 * small), Color3.new(1, 1, 1), Enum.Font.GothamBlack)
	local desc = lbl(Text.get("ui1.form2." .. bossId .. ".descShort"), 14 + 84 * small + (phone and 8 or 0), math.max(13, math.floor(17 * small)), Color3.fromRGB(184, 192, 214), Enum.Font.GothamBold)
	task.spawn(function() -- 변신 무적이 실제로 켜지면(새 몸) "n초 동안 피해 없음"(초 = 데이터)
		for _ = 1, 10 do
			if bossModel and bossModel:GetAttribute("BossTransformGuard") == true and tg then
				desc.Text = Text.get("ui1.form2." .. bossId .. ".desc", { seconds = tostring(tg.seconds) })
				return
			end
			task.wait(0.1)
		end
	end)
	TweenService:Create(card, TweenInfo.new(0.2), { GroupTransparency = 0 }):Play()
	task.delay(2.5, function()
		TweenService:Create(card, TweenInfo.new(0.3), { GroupTransparency = 1 }):Play()
		task.delay(0.35, function()
			card:Destroy()
		end)
	end)
end

-- ─── QUEUE-ALL1 01 A-1 하단 보스 바(아트 켬) ───
local artBar = nil
local layoutArt
local function buildArt()
	if artBar then
		return artBar
	end
	local root = Instance.new("Frame")
	root.Name = "BossBarBottom"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Visible = false
	root.Parent = refs.screenGui
	local function label(align)
		local l = Theme.label(root, "", "caption", "textPrimary")
		l.Font = Theme.font
		l.TextXAlignment = align
		l.TextStrokeTransparency = 0.2
		l.Size = UDim2.new(0.6, 0, 0, HB.nameHeight)
		l.Position = UDim2.new(align == Enum.TextXAlignment.Left and 0 or 0.4, 0, 0, 0)
		return l
	end
	local name, pct = label(Enum.TextXAlignment.Left), label(Enum.TextXAlignment.Right)
	name.Name, pct.Name = "BossName", "BossPercent"
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = HB.track
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.new(0, 0, 1, 0)
	track.ClipsDescendants = true
	track.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = HB.border
	stroke.Thickness = 2
	stroke.Parent = track
	local lag = Instance.new("Frame")
	lag.Name = "Lag"
	lag.BorderSizePixel = 0
	lag.BackgroundColor3 = HB.lag
	lag.BackgroundTransparency = HB.lagTransparency
	lag.Size = UDim2.new(1, 0, 1, 0)
	lag.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.Parent = track
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(HB.fillTop, HB.fill)
	g.Parent = fill
	-- 보스전 중 화면 위쪽은 비움 - 클리어 시간만 오른쪽 위(지역 이름 자리 - 보스전 중엔 숨겨진다) 작게
	local timer = Theme.label(refs.screenGui, "", "caption", "textSecondary")
	timer.Name = "BossClearTimer"
	timer.Font = Theme.font
	timer.TextStrokeTransparency = 0.3
	timer.TextXAlignment = Enum.TextXAlignment.Right
	timer.Size = UDim2.new(0, 80, 0, 22)
	timer.Visible = false
	ScreenMap.place(timer, "TR", "region")
	artBar = { root = root, name = name, pct = pct, track = track, lag = lag, fill = fill, ratio = nil, lagSerial = 0, timer = timer, startedAt = nil }
	return artBar
end

-- UI-1b 1절 2(I v1 spec 0-3): 보스 바 = 로블록스 상단 바 가운데 빈 칸 안(GuiService.TopbarInset = 로블록스 버튼을 뺀 남은 칸 · 화면 px).
--   한 줄 판 = 초상 + 이름 + 형태 알약 + 체력 막대 + % · 폭이 좁으면 형태 알약 숨김 · 빈 칸 < minW = 상단 바 바로 아래 · 상태 아이콘 = 판 바로 아래 가운데.
local TOPBAR_ON = require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).topbarBoss
local TB = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).topbarBoss
local topbarParts = nil
local topbarRect = nil -- 판 화면 자리(알림 줄 · 상태 줄이 따라감)
local function layoutTopbar(a)
	local phone = Theme.isMobile
	local P = phone and TB.phone or TB.pc
	local inset = GuiService.TopbarInset
	local view = workspace.CurrentCamera.ViewportSize
	local room = inset.Width > 0 and inset.Width - 2 * TB.margin or view.X - 2 * TB.margin
	local w = math.floor(math.min(P.w, room))
	local x, y
	if inset.Width > 0 and room >= TB.minW then
		x = inset.Min.X + (inset.Width - w) / 2
		y = inset.Min.Y + math.max(0, (inset.Height - P.h) / 2)
	else -- 빈 칸이 좁음(폰 · 작은 창) = 상단 바 바로 아래
		w = math.floor(math.min(P.w, view.X - 2 * TB.margin))
		x = (view.X - w) / 2
		y = math.max(inset.Max.Y, GuiService:GetGuiInset().Y) + TB.below
	end
	refs.screenGui.IgnoreGuiInset = true
	refs.screenGui.ScreenInsets = Enum.ScreenInsets.None -- TopbarInset = 화면 좌표(안전 영역 기준 아님)
	if not topbarParts then
		topbarParts = {}
		local st = Instance.new("UIStroke")
		st.Name = "TopbarStroke"
		st.Color = Color3.fromHex(TB.stroke)
		st.Thickness = TB.strokeW
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = a.root
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, TB.corner)
		c.Parent = a.root
		local holder = Instance.new("Frame")
		holder.Name = "TopbarPortrait"
		holder.BackgroundTransparency = 1
		holder.Parent = a.root
		topbarParts.portrait = holder
	end
	a.root.BackgroundColor3 = Color3.fromHex(TB.bg)
	a.root.BackgroundTransparency = TB.bgT
	a.root.AnchorPoint = Vector2.zero
	a.root.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	a.root.Size = UDim2.fromOffset(w, P.h)
	topbarRect = { x = math.floor(x), y = math.floor(y), w = w, h = P.h }
	local cx = P.pad
	topbarParts.portrait.Size = UDim2.fromOffset(P.portrait, P.portrait)
	topbarParts.portrait.Position = UDim2.fromOffset(cx, math.floor((P.h - P.portrait) / 2))
	cx += P.portrait + P.pad
	a.name.TextXAlignment = Enum.TextXAlignment.Left
	a.name.TextSize = P.name
	a.name.TextScaled = false
	a.name.TextTruncate = Enum.TextTruncate.AtEnd
	a.name.AnchorPoint = Vector2.new(0, 0.5)
	a.name.Position = UDim2.new(0, cx, 0.5, 0)
	a.name.Size = UDim2.fromOffset(P.nameW, P.h - 4)
	cx += P.nameW + P.pad
	local formRoom = w - cx - P.pctW - P.pad * 2 - 80 >= P.formW -- 좁으면 형태 알약 숨김(spec: 이름 줄임 → 형태 알약 숨김)
	topbarParts.formX = formRoom and cx or nil
	if formRoom then
		cx += P.formW + P.pad
	end
	a.track.AnchorPoint = Vector2.new(0, 0.5)
	a.track.Position = UDim2.new(0, cx, 0.5, 0)
	a.track.Size = UDim2.fromOffset(math.max(40, w - cx - P.pctW - P.pad), P.bar)
	a.pct.TextXAlignment = Enum.TextXAlignment.Right
	a.pct.TextSize = P.pct
	a.pct.AnchorPoint = Vector2.new(1, 0.5)
	a.pct.Position = UDim2.new(1, -P.pad, 0.5, 0)
	a.pct.Size = UDim2.fromOffset(P.pctW, P.h - 4)
	for _, tick in ipairs(v6.ticks) do
		tick.Size = UDim2.fromOffset(3, P.bar + 6)
	end
	v6.form.Size = UDim2.fromOffset(P.formW, P.h - 12)
	v6.form.TextSize = P.pct - 4
	v6.statusScale.Scale = 1
	v6.statusHolder.Size = UDim2.fromOffset(P.status * 5, P.status)
	v6.statusHolder.AnchorPoint = Vector2.new(0.5, 0)
	v6.statusHolder.Position = UDim2.new(0.5, 0, 1, TB.statusGap)
end

-- 보스 초상(판 왼쪽 원) = 보스가 바뀔 때만 다시
local function setTopbarPortrait(bossId)
	if not topbarParts or topbarParts.bossId == bossId then
		return
	end
	topbarParts.bossId = bossId
	topbarParts.portrait:ClearAllChildren()
	if bossId then
		local p = require(script.Parent.Parent.ui.v2.BossPortrait).make(topbarParts.portrait, bossId, topbarParts.portrait.AbsoluteSize.X > 0 and topbarParts.portrait.AbsoluteSize.X or (Theme.isMobile and TB.phone or TB.pc).portrait, { stroke = 2 })
		p.Position = UDim2.fromOffset(0, 0)
	end
end

layoutArt = function()
	local a = buildArt()
	local screen = refs.screenGui.AbsoluteSize
	-- 폭 = 스킬 줄(CentralRow) 폭 · 궁극기 버튼(UltGaugeGui.UltButton - 스킬 줄 왼쪽 위)을 안 덮게 그 오른쪽 끝 + 8 안쪽까지 · 없으면 화면 widthFraction
	local gui = player:FindFirstChild("PlayerGui")
	local row = gui and gui:FindFirstChild("CentralRow", true)
	local ult = gui and gui:FindFirstChild("UltGaugeGui") and gui.UltGaugeGui:FindFirstChild("UltButton")
	local width = (row and row.AbsoluteSize.X > 0) and row.AbsoluteSize.X or math.clamp(screen.X * HB.widthFraction, HB.widthMin, HB.widthMax)
	if ult and ult.Visible and ult.AbsoluteSize.X > 0 then
		width = math.min(width, 2 * (screen.X / 2 - (ult.AbsolutePosition.X + ult.AbsoluteSize.X + 8)))
	end
	if Theme.isMobile then
		width = math.min(width, screen.X - 2 * HB.phoneSideReserve)
	end
	width = math.max(width, MIN_MOBILE_WIDTH)
	if V6ON then -- UI-1 2단계: 위 가운데
		local B = V6.bossBar
		local P = Theme.isMobile and B.phone or B.pc
		local spec = Theme.isMobile and V6.phone.bossBar or V6.pc.bossBar
		local view = workspace.CurrentCamera.ViewportSize
		local m = HudPlace.scale(view.X, view.Y, Theme.isMobile)
		local r = HudPlace.screenRect(spec, spec.anchor, view.X, view.Y, m, Theme.isMobile)
		refs.screenGui.IgnoreGuiInset = true
		refs.screenGui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
		a.root.AnchorPoint = Vector2.new(0, 0)
		a.root.Position = UDim2.fromOffset(math.floor(r[1]), math.floor(r[2]))
		a.root.Size = UDim2.fromOffset(math.floor(r[3]), math.floor((P.name + P.bar) * m))
		a.track.Size = UDim2.new(1, 0, 0, math.floor(P.bar * m))
		a.name.Size = UDim2.new(0.6, 0, 0, math.floor(P.name * m))
		a.pct.Size = UDim2.new(0.4, 0, 0, math.floor(P.name * m))
		a.pct.Position = UDim2.new(0.6, 0, 0, 0)
		if not v6 then
			v6 = {}
			v6.ticks = {}
			for _, t in ipairs(B.ticks) do
				local tick = Instance.new("ImageLabel")
				tick.Name = "Tick" .. math.floor(t * 100)
				tick.BackgroundTransparency = 1
				tick.Image = ArtImage.get("ui/ds/bossbar-tick") or ""
				tick.AnchorPoint = Vector2.new(0.5, 0.5)
				tick.Position = UDim2.fromScale(t, 0.5)
				tick.ZIndex = 5
				tick.Parent = a.track
				table.insert(v6.ticks, tick)
			end
			v6.stripes = Instance.new("ImageLabel")
			v6.stripes.Name = "GuardStripes"
			v6.stripes.BackgroundTransparency = 1
			v6.stripes.Image = ArtImage.get("ui/ds/bossbar-guard-stripes") or ""
			v6.stripes.ScaleType = Enum.ScaleType.Tile
			v6.stripes.TileSize = UDim2.fromOffset(16, 16)
			v6.stripes.Size = UDim2.fromScale(1, 1)
			v6.stripes.ZIndex = 4
			v6.stripes.Visible = false
			v6.stripes.Parent = a.track
			v6.form = Theme.label(a.root, "", "caption", "textPrimary")
			v6.form.Name = "FormTag"
			v6.form.Font = Theme.font
			v6.form.TextStrokeTransparency = 0.2
			v6.form.Visible = false
			local holder = Instance.new("Frame")
			holder.Name = "BossStatus"
			holder.BackgroundTransparency = 1
			holder.AnchorPoint = Vector2.new(1, 0)
			holder.Parent = a.root
			v6.statusHolder = holder
			v6.statusScale = Instance.new("UIScale")
			v6.statusScale.Parent = holder
			v6.statusRow = require(script.Parent.Parent.ui.v2.UiParts).statusRow({ parent = holder, place = "boss", tappable = true, name = "BossStatusRow", max = 4, info = function(id)
				return boss and require(script.Parent.Parent.ui.v2.UiParts).readStatus(id, { boss = boss }, "boss")
			end })
		end
		for _, tick in ipairs(v6.ticks) do
			tick.Size = UDim2.fromOffset(math.max(2, math.floor(4 * m)), math.floor((P.bar + 6) * m))
		end
		local cell = (Theme.isMobile and 30 or 38)
		v6.statusHolder.Size = UDim2.fromOffset(cell * 5, cell)
		v6.statusHolder.Position = UDim2.new(0.6, -4, 0, math.floor((P.name * m - cell * m) / 2))
		v6.statusScale.Scale = m
		v6.form.Size = UDim2.fromOffset(math.floor(60 * m), math.floor(P.name * m))
		if TOPBAR_ON then
			layoutTopbar(a)
		end
		return
	end
	local barH = BossHudLayout.barHeight()
	refs.screenGui.IgnoreGuiInset = false
	a.root.Position = UDim2.new(0.5, 0, 1, -BossHudLayout.barBottom())
	a.root.Size = UDim2.new(0, width, 0, barH + HB.nameGap + HB.nameHeight)
	a.track.Size = UDim2.new(1, 0, 0, barH)
end

-- 보스 블록이 보이는 동안 BC의 다른 슬롯(콤보 점 · 버프 줄 · 획득 팝업 · 잡기 패널)을 위로 올린다(끝나면 제자리)
local SHIFTED_NAMES = { "BuffHudAnchor", "ComboPipsAnchor", "ToastLane_BC", "BossTrapPanel" }
local shifted = {} -- [GuiObject] = 원래 Position
local shiftSearchAt = nil -- 리뷰 6: PlayerGui 재귀 탐색은 1초에 한 번(늦게 생기는 잡기 패널 때문에 한 번으로 끝내지는 않는다)
local tcSaved = nil -- UI-1 2단계: 위쪽 알림 줄(TC) 원래 자리
local function moveNotices(on)
	local gui = player:FindFirstChild("PlayerGui")
	local tcGui = gui and gui:FindFirstChild("ToastGuiTC")
	local lane = tcGui and tcGui:FindFirstChildWhichIsA("Frame")
	if on and lane and not tcSaved and artBar then
		tcSaved = { lane = lane, pos = lane.Position, anchor = lane.AnchorPoint }
		local spec = Theme.isMobile and V6.phone.bossNotices or V6.pc.bossNotices
		local view = workspace.CurrentCamera.ViewportSize
		local m = HudPlace.scale(view.X, view.Y, Theme.isMobile)
		local r = HudPlace.screenRect(spec, spec.anchor, view.X, view.Y, m, Theme.isMobile)
		local insetY = tcGui.IgnoreGuiInset and 0 or GuiService:GetGuiInset().Y
		lane.AnchorPoint = Vector2.new(0.5, 0)
		lane.Position = UDim2.new(0.5, 0, 0, math.floor(r[2] - insetY))
		if TOPBAR_ON and topbarRect then -- UI-1b: 판 → 상태 아이콘 줄 → 알림(그 아래)
			local P = Theme.isMobile and TB.phone or TB.pc
			lane.Position = UDim2.new(0.5, 0, 0, math.floor(topbarRect.y + topbarRect.h + TB.statusGap + P.status + TB.noticeGap - insetY))
		end
	elseif not on and tcSaved then
		if tcSaved.lane.Parent then
			tcSaved.lane.Position, tcSaved.lane.AnchorPoint = tcSaved.pos, tcSaved.anchor
		end
		tcSaved = nil
	end
end
local function shiftOthers(on)
	if V6ON then
		moveNotices(on) -- 보스 바가 위로 갔다 → 아래 칸을 올릴 필요 없음 · 위쪽 알림만 보스 바 아래로
		return
	end
	local gui = player:FindFirstChild("PlayerGui")
	if on then
		if shiftSearchAt and os.clock() - shiftSearchAt < 1 then
			return
		end
		shiftSearchAt = os.clock()
		local dy = BossHudLayout.shift()
		for _, n in ipairs(SHIFTED_NAMES) do
			local o = gui and gui:FindFirstChild(n, true)
			if o and o:IsA("GuiObject") and not shifted[o] then
				shifted[o] = o.Position
				o.Position = o.Position + UDim2.fromOffset(0, -dy)
			end
		end
	else
		for o, pos in pairs(shifted) do
			if o.Parent then
				o.Position = pos
			end
		end
		table.clear(shifted)
		shiftSearchAt = nil
	end
end

-- 보스전 동안 로블록스 채팅 창 = 작고 투명하게(끄지 않음)
local chatSaved = nil
local function chatSmall(on)
	local cfg = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if not cfg then
		return
	end
	if on and not chatSaved then
		chatSaved = { cfg.HeightScale, cfg.WidthScale, cfg.BackgroundTransparency }
		cfg.HeightScale, cfg.WidthScale, cfg.BackgroundTransparency = HB.chat.heightScale, HB.chat.widthScale, HB.chat.backgroundTransparency
	elseif not on and chatSaved then
		cfg.HeightScale, cfg.WidthScale, cfg.BackgroundTransparency = chatSaved[1], chatSaved[2], chatSaved[3]
		chatSaved = nil
	end
end

local function setArtRatio(ratio)
	local a = artBar
	if a.ratio == ratio then
		return
	end
	local dropped = a.ratio ~= nil and ratio < a.ratio
	a.ratio = ratio
	TweenService:Create(a.fill, TweenInfo.new(0.12), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	a.pct.Text = ("%d%%"):format(math.ceil(ratio * 100)) -- 올림: 남아 있는 보스가 0%로 보이지 않는다
	if not dropped then
		a.lag.Size = UDim2.new(ratio, 0, 1, 0)
		return
	end
	a.lagSerial += 1
	local mine = a.lagSerial
	task.delay(HB.lagHoldSeconds, function() -- 맞은 만큼 흰 잔상이 늦게 줄어든다
		if mine == a.lagSerial then
			TweenService:Create(a.lag, TweenInfo.new(HB.lagSeconds, Enum.EasingStyle.Quad), { Size = UDim2.new(a.ratio, 0, 1, 0) }):Play()
		end
	end)
end

local function applyWidth()
	-- QUEUE-ALL1 01 A-1: 아트 켬 = 화면 하단 가운데 새 틀(artBar - 아래 layoutArt) · 옛 틀(refs.root)은 끔에서만
	if Workspace:GetAttribute(ArtStyleV1Data.attribute) == true then
		layoutArt()
		return
	end
	if nameInBar then
		nameInBar.Visible = false
	end
	refs.screenGui.IgnoreGuiInset = false
	ScreenMap.place(refs.root, "TC", "bossBar") -- 아트 켬 자리(상단 칸)에서 옛 자리로
	refs.nameLabel.Visible = true
	local width = refs.slotWidth
	if Theme.isMobile then
		local listRight = ScreenMap.edgeMargin + ScreenMap.menuBar.mobileButton + 8 + PartyListView.compact.width
		width = math.clamp(refs.screenGui.AbsoluteSize.X - 2 * (listRight + 8), MIN_MOBILE_WIDTH, refs.slotWidth)
	end
	refs.root.Size = UDim2.new(0, width, 0, refs.slotHeight)
	refs.gauge.root.Position = UDim2.new(0, 0, 0, NAME_HEIGHT + GAP)
	refs.gauge.root.Size = UDim2.new(0, width, 0, 16)
end
applyWidth()
refs.screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyWidth)
Workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(applyWidth)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyWidth)
-- Studio에서 폰 화면을 흉내 낼 때(ForceTouchLayout - MenuBar가 Theme.recompute를 한 뒤)만 다시 잰다. 실제 기기는 접속 때 판정이 정해진다.
player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(function()
	task.delay(0.1, applyWidth)
end)
boss = nil -- 지금 표시 중인 보스 모델(UI-1: 선언은 위 - 보스 상태 설명 창이 읽는다)
local shownRatio = nil

local function findBoss(id)
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		if model:GetAttribute("BossEncounterId") == id then
			return model
		end
	end
	return nil
end

local function hide()
	boss = nil
	shownRatio = nil
	refs.root.Visible = false
	if artBar then
		artBar.root.Visible = false
		artBar.ratio = nil
		artBar.timer.Visible = false
		artBar.startedAt = nil
	end
	shiftOthers(false)
	chatSmall(false)
end

local function refresh()
	local id = player:GetAttribute("BossEncounterId")
	if id == nil then
		hide()
		return
	end
	if not boss or not boss.Parent or boss:GetAttribute("BossEncounterId") ~= id then
		boss = findBoss(id)
		shownRatio = nil
	end
	if not boss then
		hide() -- 잔류(처치 뒤 모델만 없음) · 다시 도전 사이: 하단 바 · 밀린 슬롯 · 채팅 · 타이머까지 되돌린다(리뷰 1)
		return
	end
	local ratio = math.clamp(boss:GetAttribute("BossHpRatio") or 1, 0, 1)
	if Workspace:GetAttribute(ArtStyleV1Data.attribute) == true then
		local a = buildArt()
		if not a.root.Visible then
			layoutArt() -- 보스전에 들어갈 때마다 스킬 줄 · 궁극기 버튼 자리를 다시 잰다
		end
		refs.root.Visible = false
		a.name.Text = Text.name(boss:GetAttribute("BossName") or boss.Name)
		setArtRatio(ratio)
		-- 2폼 카드 = 폼이 바뀌는 순간(체력 formAt 아래로 · 폭풍 군주만) - 변신 무적(v3 transformGuard)은 새 몸이 켜졌을 때만 있어 신호로 쓰지 않는다
		-- UI-1b 0절(VERIFY-5): F 보스 창 스위치(boss)만 따른다(옛 = hud 스위치 안에 묶여 hud를 끄면 같이 사라짐)
		if require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).boss then
			local form2 = ratio < V6.bossBar.formAt
			if form2 and not lastGuard then
				local bid = boss:GetAttribute("BossRig")
				if V6.bossBar.formBosses[bid] then
					showForm2Card(bid, boss)
				end
			end
			lastGuard = form2
		end
		if V6ON and v6 then
			local B = V6.bossBar
			local guard = boss:GetAttribute("BossTransformGuard") == true
			a.fill.BackgroundColor3 = guard and Color3.fromHex(B.guardFill) or Color3.new(1, 1, 1)
			v6.stripes.Visible = guard
			local bossId = boss:GetAttribute("BossRig") -- 보스 데이터 id(MonsterSpawner)
			if TOPBAR_ON then
				setTopbarPortrait(bossId)
			end
			if B.formBosses[bossId] then -- 폼 꼬리표 = 폭풍 군주만
				v6.form.Visible = true
				v6.form.Text = Text.get(ratio < B.formAt and "ui1.boss.form2" or "ui1.boss.form1")
				local tb = a.name.TextBounds.X
				v6.form.Position = UDim2.fromOffset(math.floor(tb + 10), 0)
				if TOPBAR_ON and topbarParts then -- UI-1b: 판 안 형태 알약 자리(좁으면 숨김)
					v6.form.Visible = topbarParts.formX ~= nil
					v6.form.AnchorPoint = Vector2.new(0, 0.5)
					v6.form.Position = UDim2.new(0, topbarParts.formX or 0, 0.5, 0)
				end
			else
				v6.form.Visible = false
			end
			local list = {}
			for _, id in ipairs({ "stun", "boss-transform-guard", "boss-enrage", "shield" }) do
				local st = require(script.Parent.Parent.ui.v2.UiParts).readStatus(id, { boss = boss }, "boss")
				if st then
					st.id = id
					table.insert(list, st)
				end
			end
			v6.statusRow.update(list)
		end
		a.root.Visible = true
		a.startedAt = a.startedAt or os.clock()
		local secs = math.floor(os.clock() - a.startedAt)
		a.timer.Text = ("%d:%02d"):format(secs // 60, secs % 60)
		a.timer.Visible = true
		shiftOthers(true)
		chatSmall(true)
		return
	elseif artBar and artBar.root.Visible then
		artBar.root.Visible = false
		artBar.timer.Visible = false
		shiftOthers(false)
		chatSmall(false)
	end
	refs.nameLabel.Text = Text.name(boss:GetAttribute("BossName") or boss.Name)
	if nameInBar then
		nameInBar.Text = refs.nameLabel.Text
	end
	if ratio ~= shownRatio then
		shownRatio = ratio
		refs.gauge.setValue(ratio, ("%d%%"):format(math.ceil(ratio * 100))) -- 올림: 남아 있는 보스가 0%로 보이지 않는다
	end
	refs.root.Visible = true
end

local accumulated = 0
RunService.Heartbeat:Connect(function(dt)
	accumulated += dt
	if accumulated >= REFRESH_SECONDS then
		accumulated = 0
		refresh()
	end
end)
