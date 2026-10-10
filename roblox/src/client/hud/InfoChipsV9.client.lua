-- UI-1b 1절 16(I v1 spec 0-4 · pc_10 · ph_06): HUD 오른쪽 위 칩 = 왼쪽 메뉴 버튼과 같은 크기 단계(PC 높이 52 · 아이콘 36 · 이름 15 + 숫자 20 / 폰 40 · 26 · 숫자 14).
--   줄 1 = 재화(골드 · 꾸미기 토큰 · 강화석 - 폰 골드 · 토큰) · 줄 2 = 스테이지 · 최고(PC) + Lv · 전투력 · 누르면 A 설명 창(InfoTip · 문구 = CurrencyInfo) · 스테이지 칩 = 구역 선택(옛 칩과 같음).
--   자리 = 옛 칩 줄(TopChipsRow - 다음 목표 카드 · 미니맵 · 귀환이 이 줄 아래를 따라간다)의 맨 앞 · 옛 칩(골드 · 레벨 · 스테이지)은 값 스크립트 그대로 두고 화면에서만 숨김.
--   스위치 UiV2Flags.chipsV9 끔 = 옛 칩 그대로. 보스전 = 골드 · Lv만(02 v6 규칙 유지).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Flags = require(ReplicatedStorage.Shared.data.UiV2Flags)
if not Flags.chipsV9 then
	return
end
local Text = require(ReplicatedStorage.Shared.Text)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local Layout = require(ReplicatedStorage.Shared.data.UiLayoutData)
local C = Layout.infoChips
local client = script.Parent.Parent
local Theme = require(client.ui.kit.Theme)
local UiKit = require(client.ui.v2.UiKit)
local InfoTip = require(client.ui.v2.InfoTip)
local ArtImage = require(client.ui.ArtImage)
local CurrencyBar = require(client.ui.CurrencyBar)

local player = Players.LocalPlayer
local row = player:WaitForChild("PlayerGui"):WaitForChild("TopChipsGui"):WaitForChild("TopChipsRow")
local phone = Theme.isMobile
local S = phone and C.phone or C.pc

local root = Instance.new("Frame")
root.Name = "InfoChipsV9"
root.LayoutOrder = 0
root.BackgroundTransparency = 1
root.AutomaticSize = Enum.AutomaticSize.XY
root.Size = UDim2.new()
root.Parent = row
if phone and Flags.hud then -- 옛 폰 칩 배율(phoneChipScale 0.7)을 되돌려 spec 크기(높이 40) 그대로
	local un = Instance.new("UIScale")
	un.Scale = 1 / Layout.hud.v6.phoneChipScale
	un.Parent = root
end
local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Right
list.Padding = UDim.new(0, S.rowGap)
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Parent = root

local function line(order)
	local f = Instance.new("Frame")
	f.Name = "Row" .. order
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.new()
	f.Parent = root
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Right
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, S.gap)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	return f
end

-- 칩 하나: 알약(테 2) + 아이콘 + [이름(작게) / 숫자(크게)] · 누르기 = onPress(chip)
local function chip(parent, order, iconFn, onPress)
	local b = Instance.new("TextButton")
	b.Name = "Chip"
	b.Text = ""
	b.AutoButtonColor = false
	b.LayoutOrder = order
	b.BackgroundColor3 = Color3.fromHex(C.bg)
	b.BackgroundTransparency = C.bgT
	b.AutomaticSize = Enum.AutomaticSize.XY -- 글자 1.3에서 넘치면 높이만 늘어남(기본 = spec 높이)
	b.Size = UDim2.fromOffset(0, S.h)
	b.Parent = parent
	UiKit.corner(b, S.h / 2)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromHex(C.stroke)
	st.Thickness = C.strokeW
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = b
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, S.padX - 4), UDim.new(0, S.padX + 4)
	pad.Parent = b
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, 8)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = b
	if iconFn then
		local ic = iconFn(b)
		ic.LayoutOrder = 1
	end
	if onPress then
		UiKit.attachPress(b, { onActivated = function()
			onPress(b)
		end })
	end
	return b
end

-- 글자 = spec px(새 보통) × 설정 글자 단계(1.0 · 1.15 · 1.3 - textBase는 spec 값에 이미 들어 있음)
local texts = {} -- { label, base }
local function stepMul()
	local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
	local UiModel = require(ReplicatedStorage.Shared.UiModel)
	return UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) / (Flags.text and Tokens.textBase or 1)
end
local function sized(label, base)
	table.insert(texts, { label, base })
	label.TextSize = math.floor(base * stepMul() + 0.5)
end
player:GetAttributeChangedSignal("UiTextScale"):Connect(function()
	local k = stepMul()
	for _, t in ipairs(texts) do
		t[1].TextSize = math.floor(t[2] * k + 0.5)
	end
end)

-- [이름 / 숫자] 두 줄 묶음(폰 = 이름 없음 - 이름은 설명 창 제목)
local function textBlock(parent, order, nameText)
	local f = Instance.new("Frame")
	f.Name = "Text" .. order
	f.LayoutOrder = order
	f.BackgroundTransparency = 1
	f.AutomaticSize = Enum.AutomaticSize.XY
	f.Size = UDim2.fromOffset(0, S.h - 8)
	f.Parent = parent
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Vertical
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = f
	local name
	if S.name > 0 and nameText then
		name = Instance.new("TextLabel")
		name.Name = "Name"
		name.LayoutOrder = 1
		name.BackgroundTransparency = 1
		name.AutomaticSize = Enum.AutomaticSize.X
		name.Size = UDim2.fromOffset(0, 0)
		name.AutomaticSize = Enum.AutomaticSize.XY
		name.Font = UiKit.font("korean")
		sized(name, S.name)
		name.TextColor3 = UiKit.color("text.secondary")
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.Text = nameText
		name.Parent = f
	end
	local num = Instance.new("TextLabel")
	num.Name = "Num"
	num.LayoutOrder = 2
	num.BackgroundTransparency = 1
	num.AutomaticSize = Enum.AutomaticSize.X
	num.Size = UDim2.fromOffset(0, 0)
	num.AutomaticSize = Enum.AutomaticSize.XY
	num.Font = UiKit.font("number")
	sized(num, S.num)
	num.TextColor3 = UiKit.color("text.primary")
	num.TextXAlignment = Enum.TextXAlignment.Left
	num.Parent = f
	return num, name
end

local r1, r2 = line(1), line(2)
local cur = {}
local names = {} -- 폰: 줄 1이 maxW를 넘으면 이름 숨김
for i, id in ipairs(phone and C.row1.phone or C.row1.pc) do
	local b = chip(r1, i, function(p)
		return ArtImage.label(p, "icons/reward/" .. id, UDim2.fromOffset(S.icon, S.icon), "")
	end, function(b)
		InfoTip.currency(b, id)
	end)
	b.Name = "Chip_" .. id
	local num, nm = textBlock(b, 2, Text.get("item.name." .. id))
	cur[id] = { chip = b, num = num }
	table.insert(names, nm)
	local function upd()
		num.Text = CurrencyBar.text(CurrencyBar.valueOf(id))
	end
	player:GetAttributeChangedSignal(CurrencyBar.attrOf(id)):Connect(upd)
	upd()
end

local stageChip
if S.stage then
	stageChip = chip(r2, 1, function(p)
		return UiKit.icon(p, "zone", S.icon)
	end, function()
		require(client.StageSelectPanel).open()
	end)
	stageChip.Name = "Chip_stage"
	local num, name = textBlock(stageChip, 2, "")
	local function upd()
		num.Text = Text.get("ui1b.chip.stage", { stage = tostring(player:GetAttribute("InfiniteStage") or 1) })
		if name then
			name.Text = Text.get("ui1b.chip.best", { best = tostring(player:GetAttribute("InfiniteStageBest") or 1) })
		end
	end
	player:GetAttributeChangedSignal("InfiniteStage"):Connect(upd)
	player:GetAttributeChangedSignal("InfiniteStageBest"):Connect(upd)
	upd()
end

local lvChip = chip(r2, 2, nil, function(b)
	InfoTip.currency(b, "power")
end)
lvChip.Name = "Chip_power"
local lvNum = textBlock(lvChip, 1, Text.get("ui1b.chip.level"))
local cpNum = textBlock(lvChip, 2, Text.get("ui1b.chip.power"))
local function updLv()
	lvNum.Text = "Lv " .. tostring(player:GetAttribute("CharacterLevel") or 1)
	local p = player:GetAttribute("CombatPower")
	cpNum.Text = p and CombatFormula.display(p) or "-"
end
player:GetAttributeChangedSignal("CharacterLevel"):Connect(updLv)
player:GetAttributeChangedSignal("CombatPower"):Connect(updLv)
updLv()

-- 옛 칩(값 스크립트는 그대로) = 화면에서만 숨김 · 보스전 = 골드 · Lv만
local OLD = { "CurrencyStack", "LevelChip", "StageWrapper" }
local function refresh()
	for _, n in ipairs(OLD) do
		local o = row:FindFirstChild(n)
		if o and o.Visible then
			o.Visible = false
		end
	end
	local boss = player:GetAttribute("BossEncounterId") ~= nil
	for id, e in pairs(cur) do
		e.chip.Visible = id == "gold" or not boss
	end
	if stageChip then
		stageChip.Visible = not boss
	end
end
row.ChildAdded:Connect(function(c)
	if table.find(OLD, c.Name) then
		task.defer(refresh)
	end
end)
for _, n in ipairs(OLD) do
	task.spawn(function()
		local o = row:WaitForChild(n, 30)
		if o then
			o:GetPropertyChangedSignal("Visible"):Connect(function()
				if o.Visible then
					o.Visible = false
				end
			end)
			refresh()
		end
	end)
end
player:GetAttributeChangedSignal("BossEncounterId"):Connect(refresh)
refresh()
if S.maxW then -- 폰: 이름까지 넣어 줄 1 폭이 maxW(기준 px)를 넘으면 이름만 숨김
	local function fit()
		for _, n in ipairs(names) do
			n.Visible = true
		end
		task.defer(function()
			local un = root:FindFirstChildOfClass("UIScale")
			local rs = row:FindFirstChildOfClass("UIScale")
			local s = (un and un.Scale or 1) * (rs and rs.Scale or 1) -- 화면 px → 기준 px
			local over = r1.AbsoluteSize.X / s > S.maxW
			for _, n in ipairs(names) do
				n.Visible = not over
			end
		end)
	end
	for _, e in pairs(cur) do
		e.num:GetPropertyChangedSignal("Text"):Connect(fit)
	end
	fit()
end
