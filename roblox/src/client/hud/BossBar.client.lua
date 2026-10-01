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
local function shiftOthers(on)
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
local boss = nil -- 지금 표시 중인 보스 모델
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
