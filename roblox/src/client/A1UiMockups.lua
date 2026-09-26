-- A1 UI 목업(스타일 잠금용 - 기능 없음 · 게임 UI를 바꾸지 않는다). art-spec 9장 · docs/art/ref/16 ~ 18 시트 기준. 본 작업은 U1(BR2 뒤).
-- A1UiMockups.show("hud" | "equipment" | "card" | "fonts") → PlayerGui.A1UiMock 한 장. hide()로 지운다. 아이콘 = UI 도형(Frame · UICorner · UIStroke)만으로 그릴 수 있는지 판정용.
-- 목업 글자는 게임 문장이 아니라 TextData에 넣지 않는다(U1에서 실제 창을 만들 때 번역 규칙대로 옮긴다).

local Players = game:GetService("Players")

local ItemIcons = require(script.Parent.ItemIcons)

local A1UiMockups = {}

local C = {
	ink = Color3.fromHex("#1E1B2E"), panel = Color3.fromHex("#23213A"), panel2 = Color3.fromHex("#2C2A48"), text = Color3.fromHex("#FFFFFF"), sub = Color3.fromHex("#B9B6D3"),
	orange = Color3.fromHex("#F39A3A"), green = Color3.fromHex("#5CC96B"), teal = Color3.fromHex("#3CC7D6"), red = Color3.fromHex("#F2544B"), gray = Color3.fromHex("#8A8AA0"),
	gold = Color3.fromHex("#FFD34D"), magenta = Color3.fromHex("#FF3FD2"), paper = Color3.fromHex("#F5E6C8"), brown = Color3.fromHex("#7A4A2A"),
	grades = { Color3.fromRGB(230, 230, 230), Color3.fromRGB(77, 166, 255), Color3.fromRGB(166, 77, 255), Color3.fromRGB(255, 153, 51), Color3.fromRGB(255, 215, 0), Color3.fromRGB(224, 57, 62), Color3.fromRGB(255, 255, 255) }, -- 기존 ItemVisualData 순서(태초 = 흰 + 자홍 점)
}
local FONT_LATIN = Enum.Font.FredokaOne -- 카툰 영문 · 숫자
local FONT_KO = Enum.Font.GothamBlack -- 한글 = 굵은 기본 + 외곽선(art-spec 9-1 ★)

local gui = nil

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	o.Parent = parent
	return o
end

local function frame(parent, pos, size, color, radius, strokeW)
	local f = new("Frame", { Position = pos, Size = size, BackgroundColor3 = color, BorderSizePixel = 0 }, parent)
	if radius then
		new("UICorner", { CornerRadius = radius }, f)
	end
	if strokeW then
		new("UIStroke", { Color = C.ink, Thickness = strokeW, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	end
	return f
end

local function label(parent, pos, size, text, sizePx, font, color, align)
	local t = new("TextLabel", { Position = pos, Size = size, BackgroundTransparency = 1, Text = text, TextSize = sizePx, Font = font or FONT_KO,
		TextColor3 = color or C.text, TextXAlignment = align or Enum.TextXAlignment.Center, TextWrapped = true }, parent)
	new("UIStroke", { Color = C.ink, Thickness = math.max(1, sizePx / 9) }, t)
	return t
end

-- 아이콘(UI 도형만): 가방 · 그래프 · 지도 · 자물쇠
local function iconBag(parent, s, body)
	frame(parent, UDim2.fromOffset(s * 0.3, s * 0.12), UDim2.fromOffset(s * 0.4, s * 0.22), C.ink, UDim.new(0.4, 0)).BackgroundTransparency = 0
	local inner = frame(parent, UDim2.fromOffset(s * 0.36, s * 0.18), UDim2.fromOffset(s * 0.28, s * 0.14), body, UDim.new(0.4, 0))
	inner.ZIndex = 2
	local b = frame(parent, UDim2.fromOffset(s * 0.16, s * 0.28), UDim2.fromOffset(s * 0.68, s * 0.56), Color3.fromHex("#FFC27A"), UDim.new(0.25, 0), 3)
	frame(b, UDim2.fromScale(0.62, 0), UDim2.fromScale(0.38, 1), Color3.fromHex("#E08A38"), UDim.new(0.25, 0)) -- 3톤: 오른면 어둡게
	local pocket = frame(b, UDim2.fromScale(0.22, 0.38), UDim2.fromScale(0.56, 0.34), Color3.fromHex("#FFD9A6"), UDim.new(0.3, 0), 2)
	pocket.ZIndex = 3
end
local function iconGraph(parent, s)
	frame(parent, UDim2.fromOffset(s * 0.14, s * 0.14), UDim2.fromOffset(s * 0.72, s * 0.72), Color3.fromHex("#EFFFF1"), UDim.new(0.12, 0), 3)
	for i, h in ipairs({ 0.22, 0.36, 0.5 }) do
		frame(parent, UDim2.fromOffset(s * (0.2 + (i - 1) * 0.2), s * (0.8 - h)), UDim2.fromOffset(s * 0.14, s * h), i == 3 and C.green or Color3.fromHex("#3A7BD5"), UDim.new(0.15, 0), 2)
	end
	local arrow = frame(parent, UDim2.fromOffset(s * 0.2, s * 0.36), UDim2.fromOffset(s * 0.55, s * 0.07), C.red, UDim.new(1, 0))
	arrow.Rotation = -28
end
local function iconMap(parent, s)
	for i = 0, 2 do
		local p = frame(parent, UDim2.fromOffset(s * (0.14 + i * 0.24), s * (0.2 + (i % 2) * 0.05)), UDim2.fromOffset(s * 0.25, s * 0.6), i == 1 and Color3.fromHex("#E8D3A8") or C.paper, nil, 2)
		p.Rotation = (i % 2 == 0) and -4 or 4
	end
	for k, d in ipairs({ { 0.22, 0.62 }, { 0.34, 0.52 }, { 0.46, 0.58 }, { 0.58, 0.46 } }) do
		frame(parent, UDim2.fromOffset(s * d[1], s * d[2]), UDim2.fromOffset(s * 0.06, s * 0.06), C.red, UDim.new(1, 0)).ZIndex = 3
	end
	for _, r in ipairs({ 45, -45 }) do
		local x = frame(parent, UDim2.fromOffset(s * 0.6, s * 0.3), UDim2.fromOffset(s * 0.18, s * 0.05), C.red, UDim.new(1, 0))
		x.Rotation = r
		x.ZIndex = 3
	end
end
local function iconLock(parent, s)
	local shackle = frame(parent, UDim2.fromOffset(s * 0.3, s * 0.1), UDim2.fromOffset(s * 0.4, s * 0.4), Color3.new(0, 0, 0), UDim.new(1, 0))
	shackle.BackgroundTransparency = 1
	new("UIStroke", { Color = C.ink, Thickness = s * 0.08 }, shackle)
	frame(parent, UDim2.fromOffset(s * 0.2, s * 0.38), UDim2.fromOffset(s * 0.6, s * 0.46), C.gold, UDim.new(0.2, 0), 3)
end

-- 둥근 두툼한 버튼(모서리 20% · 아래 그림자 = 색 × 0.55 · 위 광택 · 굵은 외곽선) + 단축키 칩 + 상태
local function button(parent, pos, size, color, draw, key, state, showChip)
	local holder = frame(parent, pos, UDim2.fromOffset(size, size + 8), Color3.new(), nil)
	holder.BackgroundTransparency = 1
	local pressed = state == "pressed"
	local locked = state == "locked"
	local base = locked and C.gray or color
	if not pressed then
		frame(holder, UDim2.fromOffset(0, 6), UDim2.fromOffset(size, size), Color3.new(base.R * 0.55, base.G * 0.55, base.B * 0.55), UDim.new(0.2, 0), 3)
	end
	local face = frame(holder, UDim2.fromOffset(0, pressed and 5 or 0), UDim2.fromOffset(size, size), base, UDim.new(0.2, 0), 3)
	local gloss = frame(face, UDim2.fromScale(0.08, 0.06), UDim2.fromScale(0.84, 0.36), Color3.new(1, 1, 1), UDim.new(0.3, 0))
	gloss.BackgroundTransparency = 0.72
	local art = frame(face, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.new(), nil)
	art.BackgroundTransparency = 1
	draw(art, size, base)
	if locked then
		local veil = frame(face, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), C.ink, UDim.new(0.2, 0))
		veil.BackgroundTransparency = 0.45
		veil.ZIndex = 5
		local lockHolder = frame(face, UDim2.fromScale(0.52, 0.5), UDim2.fromOffset(size * 0.45, size * 0.45), Color3.new(), nil)
		lockHolder.BackgroundTransparency = 1
		lockHolder.ZIndex = 6
		iconLock(lockHolder, size * 0.45)
	end
	if state == "notice" then
		local dot = frame(face, UDim2.new(1, -size * 0.2, 0, -size * 0.12), UDim2.fromOffset(size * 0.32, size * 0.32), C.red, UDim.new(1, 0), 2)
		dot.ZIndex = 7
		local n = label(dot, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "3", size * 0.22, FONT_LATIN)
		n.ZIndex = 8
	end
	if showChip then -- 단축키 칩(PC만 - 터치 기기에서는 숨김)
		local chip = frame(face, UDim2.new(1, -size * 0.26, 1, -size * 0.26), UDim2.fromOffset(size * 0.3, size * 0.3), C.ink, UDim.new(0.25, 0))
		chip.ZIndex = 7
		local t = label(chip, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), key, size * 0.2, FONT_LATIN)
		t.ZIndex = 8
	end
	return holder
end

local function screen(title)
	A1UiMockups.hide()
	gui = new("ScreenGui", { Name = "A1UiMock", IgnoreGuiInset = true, DisplayOrder = 200, ResetOnSpawn = false }, Players.LocalPlayer.PlayerGui)
	local back = frame(gui, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), Color3.fromHex("#15142A"), nil)
	-- 설계 캔버스 1560 × 860 고정 → 화면에 맞게 줄인다(Studio 창 높이가 짧아도 전부 보이게)
	local bg = frame(back, UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(1560, 860), Color3.fromHex("#15142A"), nil)
	bg.AnchorPoint = Vector2.new(0.5, 0.5)
	local scale = new("UIScale", {}, bg)
	local function fit()
		scale.Scale = math.min(1, back.AbsoluteSize.X / 1560, back.AbsoluteSize.Y / 860)
	end
	back:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	label(bg, UDim2.fromOffset(300, 18), UDim2.new(1, -340, 0, 44), title, 30, FONT_KO, C.text, Enum.TextXAlignment.Left)
	return bg
end

local function hud()
	local bg = screen("A1 목업 ① HUD 버튼(가방 B · 성장 M · 지도 N) - 기능 없음")
	local items = { { "가방", C.orange, iconBag, "B" }, { "성장", C.green, iconGraph, "M" }, { "지도", C.teal, iconMap, "N" } }
	label(bg, UDim2.fromOffset(40, 90), UDim2.fromOffset(500, 30), "PC 72px · 단축키 칩 · 상태 = 기본 · 알림", 20, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	for i, it in ipairs(items) do
		button(bg, UDim2.fromOffset(60 + (i - 1) * 110, 140), 72, it[2], function(a, s, base)
			it[3](a, s, base)
		end, it[4], i == 2 and "notice" or "base", true)
		label(bg, UDim2.fromOffset(40 + (i - 1) * 110, 228), UDim2.fromOffset(112, 28), it[1], 22)
	end
	label(bg, UDim2.fromOffset(460, 90), UDim2.fromOffset(600, 30), "상태 4가지(가방): 기본 · 눌림 · 알림 · 잠김", 20, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	for i, st in ipairs({ "base", "pressed", "notice", "locked" }) do
		button(bg, UDim2.fromOffset(480 + (i - 1) * 120, 140), 72, C.orange, iconBag, "B", st, true)
		label(bg, UDim2.fromOffset(460 + (i - 1) * 120, 228), UDim2.fromOffset(112, 28), ({ "기본", "눌림", "알림", "잠김" })[i], 22)
	end
	label(bg, UDim2.fromOffset(40, 290), UDim2.fromOffset(700, 30), "폰(터치) - 칩 숨김 · 버튼 크게(96px) · 간격 12px", 20, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	for i, it in ipairs(items) do
		button(bg, UDim2.fromOffset(60 + (i - 1) * 118, 340), 96, it[2], it[3], it[4], "base", false)
	end
	-- 한글 · 카툰 폰트 비교
	label(bg, UDim2.fromOffset(480, 290), UDim2.fromOffset(700, 30), "폰트: ① 전부 카툰 영문 폰트 ② 숫자·영문 카툰 + 한글 굵은 기본 + 외곽선", 20, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	label(bg, UDim2.fromOffset(480, 335), UDim2.fromOffset(640, 44), "① 가방 Lv.46 STAGE 46 · 태초의 대검 +20", 30, FONT_LATIN, C.gold, Enum.TextXAlignment.Left)
	local row = frame(bg, UDim2.fromOffset(480, 390), UDim2.fromOffset(640, 44), Color3.new(), nil)
	row.BackgroundTransparency = 1
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, row)
	for _, seg in ipairs({ { "② 가방", FONT_KO }, { "Lv.46", FONT_LATIN }, { "STAGE 46", FONT_LATIN }, { "· 태초의 대검", FONT_KO }, { "+20", FONT_LATIN } }) do
		local t = label(row, UDim2.new(), UDim2.fromOffset(0, 44), seg[1], 30, seg[2], C.gold)
		t.AutomaticSize = Enum.AutomaticSize.X
	end
end

local ICONS = { ItemIcons.weapon, ItemIcons.armor, ItemIcons.gloves, ItemIcons.boots }
local iconTurn = 0

local function slot(parent, pos, s, gradeIndex, plus, lv, locked, isNew, iconIndex)
	local color = C.grades[gradeIndex]
	local f = frame(parent, pos, UDim2.fromOffset(s, s), C.panel2, UDim.new(0.14, 0))
	iconTurn += 1
	local holder = frame(f, UDim2.fromScale(0.2, 0.2), UDim2.fromScale(0.6, 0.6), Color3.new(), nil)
	holder.BackgroundTransparency = 1
	ICONS[iconIndex or ((iconTurn - 1) % #ICONS + 1)](holder, s * 0.6, color)
	new("UIStroke", { Color = color, Thickness = 4 }, f)
	if gradeIndex == 7 then -- 태초 = 흰 빛 + 자홍 점
		frame(f, UDim2.new(0.5, -5, 0, -5), UDim2.fromOffset(10, 10), C.magenta, UDim.new(1, 0)).ZIndex = 4
	end
	if plus then
		label(f, UDim2.fromOffset(4, 2), UDim2.fromOffset(40, 18), "+" .. plus, 15, FONT_LATIN, C.gold, Enum.TextXAlignment.Left)
	end
	if lv then
		label(f, UDim2.new(1, -46, 1, -20), UDim2.fromOffset(42, 18), "Lv" .. lv, 13, FONT_LATIN, C.text, Enum.TextXAlignment.Right)
	end
	if locked then
		local l = frame(f, UDim2.new(1, -20, 0, 3), UDim2.fromOffset(16, 16), Color3.new(), nil)
		l.BackgroundTransparency = 1
		iconLock(l, 16)
	end
	if isNew then
		frame(f, UDim2.new(1, -8, 0, -6), UDim2.fromOffset(13, 13), C.red, UDim.new(1, 0), 2).ZIndex = 5
	end
	return f
end

local function equipment()
	local bg = screen("A1 목업 ② 장비창 배치(17번 시트) - 데이터 없는 칸 = 빈 자리")
	local win = frame(bg, UDim2.fromOffset(30, 70), UDim2.fromOffset(1500, 780), C.panel, UDim.new(0, 18), 4)
	local header = frame(win, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 56), C.orange, UDim.new(0, 18))
	local hb = frame(header, UDim2.fromOffset(14, 6), UDim2.fromOffset(44, 44), Color3.new(), nil)
	hb.BackgroundTransparency = 1
	iconBag(hb, 44, C.orange)
	label(header, UDim2.fromOffset(66, 6), UDim2.fromOffset(200, 44), "가방", 30, FONT_KO, C.text, Enum.TextXAlignment.Left)
	local close = frame(header, UDim2.new(1, -54, 0, 8), UDim2.fromOffset(40, 40), C.red, UDim.new(1, 0), 3)
	label(close, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "X", 22, FONT_LATIN)
	-- ① 착용 슬롯(게임 기준: 무기 · 머리 · 몸 · 발 - 방어구 3부위 + 무기)
	local left = frame(win, UDim2.fromOffset(16, 72), UDim2.new(0.24, -16, 1, -88), C.panel2, UDim.new(0, 14))
	label(left, UDim2.fromOffset(0, 8), UDim2.new(1, 0, 0, 28), "착용 중", 22)
	for i, s in ipairs({ { "무기", 7, 20 }, { "머리", 6, 12 }, { "몸", 5, 12 }, { "발", 4, 5 } }) do
		local x = (i % 2 == 1) and 20 or 150
		local y = 50 + math.floor((i - 1) / 2) * 120
		slot(left, UDim2.fromOffset(x, y), 84, s[2], s[3], nil, i == 1, false)
		label(left, UDim2.fromOffset(x, y + 86), UDim2.fromOffset(84, 24), s[1], 18)
	end
	local set = frame(left, UDim2.new(0, 12, 1, -150), UDim2.new(1, -24, 0, 136), C.panel, UDim.new(0, 10))
	label(set, UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 26), "세트 효과 · (세트 이름 자리)", 18, FONT_KO, C.gold, Enum.TextXAlignment.Left)
	label(set, UDim2.fromOffset(10, 40), UDim2.new(1, -20, 0, 24), "● 2세트 (효과 자리 - 활성 = 초록)", 16, FONT_KO, C.green, Enum.TextXAlignment.Left)
	label(set, UDim2.fromOffset(10, 70), UDim2.new(1, -20, 0, 24), "○ 3세트 (효과 자리)", 16, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	-- ② 가방 격자
	local mid = frame(win, UDim2.new(0.24, 8, 0, 72), UDim2.new(0.4, -8, 1, -88), C.panel2, UDim.new(0, 14))
	for i, tab in ipairs({ "전체", "무기", "방어구", "장신구", "보석" }) do
		local t = frame(mid, UDim2.fromOffset(12 + (i - 1) * 100, 10), UDim2.fromOffset(92, 36), i == 1 and C.orange or C.panel, UDim.new(0, 10), 2)
		label(t, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), tab, 18)
	end
	label(mid, UDim2.fromOffset(14, 52), UDim2.new(1, -28, 0, 24), "정렬: 등급 ▼ | □ 잠긴 것만 | 자동 분해 필터", 15, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	for r = 0, 3 do
		for c = 0, 5 do
			local g = 7 - ((r * 6 + c) % 7)
			slot(mid, UDim2.fromOffset(14 + c * 84, 86 + r * 84), 76, g, 20 - (r * 6 + c) % 9, 46 - (c % 4), (r + c) % 5 == 0, (r * 6 + c) % 7 == 3)
		end
	end
	for c = 0, 5 do
		local empty = frame(mid, UDim2.fromOffset(14 + c * 84, 86 + 4 * 84), UDim2.fromOffset(76, 76), C.panel, UDim.new(0.14, 0))
		new("UIStroke", { Color = C.gray, Thickness = 2, Transparency = 0.5 }, empty)
	end
	-- ③ 상세 카드(태초 예)
	local card = frame(win, UDim2.new(0.64, 8, 0, 72), UDim2.new(0.36, -24, 1, -88), C.panel2, UDim.new(0, 14))
	new("UIStroke", { Color = C.grades[7], Thickness = 4 }, card)
	local nameBar = frame(card, UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 48), C.panel, UDim.new(0, 10))
	new("UIStroke", { Color = C.text, Thickness = 3 }, nameBar)
	label(nameBar, UDim2.fromOffset(12, 4), UDim2.new(1, -120, 1, -8), "태초의 대검 +20", 24, FONT_KO, C.text, Enum.TextXAlignment.Left)
	local badge = frame(nameBar, UDim2.new(1, -96, 0, 10), UDim2.fromOffset(84, 28), C.magenta, UDim.new(1, 0))
	label(badge, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "태초", 17)
	slot(card, UDim2.fromOffset(16, 74), 96, 7, nil, nil, false, false)
	label(card, UDim2.fromOffset(124, 74), UDim2.new(1, -136, 0, 22), "아이템 레벨 46 · 강화 +20", 17, FONT_KO, C.text, Enum.TextXAlignment.Left)
	label(card, UDim2.fromOffset(124, 100), UDim2.new(1, -136, 0, 22), "공격력 12,840 (▲ +3,210)", 17, FONT_KO, C.green, Enum.TextXAlignment.Left)
	label(card, UDim2.fromOffset(124, 126), UDim2.new(1, -136, 0, 22), "치명 확률 +6% (▼ −1%)", 17, FONT_KO, C.red, Enum.TextXAlignment.Left)
	local engrave = frame(card, UDim2.fromOffset(14, 184), UDim2.new(1, -28, 0, 84), C.panel, UDim.new(0, 10))
	new("UIStroke", { Color = C.magenta, Thickness = 2 }, engrave)
	label(engrave, UDim2.fromOffset(10, 6), UDim2.new(1, -20, 0, 26), "세계 N번째 태초 (각인 자리)", 18, FONT_KO, C.text, Enum.TextXAlignment.Left)
	label(engrave, UDim2.fromOffset(10, 34), UDim2.new(1, -20, 0, 20), "최초 획득: (이름 · 날짜 자리)", 15, FONT_KO, C.magenta, Enum.TextXAlignment.Left)
	label(engrave, UDim2.fromOffset(10, 56), UDim2.new(1, -20, 0, 20), "출처: (보스 · 스테이지 자리)", 15, FONT_KO, C.sub, Enum.TextXAlignment.Left)
	label(card, UDim2.fromOffset(16, 282), UDim2.fromOffset(80, 30), "보석 홈", 17, FONT_KO, C.text, Enum.TextXAlignment.Left)
	for i = 1, 5 do
		local hole = frame(card, UDim2.fromOffset(100 + (i - 1) * 50, 280), UDim2.fromOffset(38, 38), C.panel, UDim.new(1, 0))
		new("UIStroke", { Color = C.gray, Thickness = 2 }, hole)
		if i <= 3 then
			local gem = frame(hole, UDim2.fromScale(0.22, 0.22), UDim2.fromScale(0.56, 0.56), ({ Color3.fromHex("#4C8DFF"), C.red, Color3.fromHex("#22D3A6") })[i], nil, 2)
			gem.Rotation = 45
		end
	end
	local lockRow = frame(card, UDim2.fromOffset(14, 332), UDim2.new(1, -28, 0, 48), C.panel, UDim.new(0, 10))
	local li = frame(lockRow, UDim2.fromOffset(10, 8), UDim2.fromOffset(32, 32), Color3.new(), nil)
	li.BackgroundTransparency = 1
	iconLock(li, 32)
	label(lockRow, UDim2.fromOffset(50, 8), UDim2.new(1, -130, 0, 32), "잠금 - 분해·판매·재료 사용 불가", 16, FONT_KO, C.gold, Enum.TextXAlignment.Left)
	local toggle = frame(lockRow, UDim2.new(1, -74, 0, 10), UDim2.fromOffset(60, 28), C.green, UDim.new(1, 0), 2)
	frame(toggle, UDim2.new(1, -26, 0, 3), UDim2.fromOffset(22, 22), C.text, UDim.new(1, 0))
	for i, b in ipairs({ { "장착", C.green }, { "각성", C.text }, { "계승", Color3.fromHex("#4C8DFF") }, { "분해", C.gray }, { "판매", C.gray } }) do
		local col = (i - 1) % 3
		local rowI = math.floor((i - 1) / 3)
		local btn = frame(card, UDim2.new(col / 3, 14 - col * 4, 0, 396 + rowI * 62), UDim2.new(1 / 3, -14, 0, 52), b[2], UDim.new(0.2, 0), 3)
		label(btn, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), b[1], 22, FONT_KO, i == 2 and C.magenta or C.text)
		if i >= 4 then
			local l = frame(btn, UDim2.new(1, -24, 0, 4), UDim2.fromOffset(18, 18), Color3.new(), nil)
			l.BackgroundTransparency = 1
			iconLock(l, 18)
		end
	end
end

local function pizza(parent, pos, s, mode)
	local disc = frame(parent, pos, UDim2.fromOffset(s, s), Color3.fromHex("#A8A29A"), UDim.new(1, 0), 3)
	if mode ~= "gray" then
		local g = new("UIGradient", { Rotation = 45 }, disc)
		if mode == "split" then
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.red), ColorSequenceKeypoint.new(0.499, C.red), ColorSequenceKeypoint.new(0.5, C.green), ColorSequenceKeypoint.new(1, C.green) })
			disc.BackgroundColor3 = Color3.new(1, 1, 1)
		else -- fall: 빨간 절반이 꺼진 구멍(어둡게)
			g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.ink), ColorSequenceKeypoint.new(0.499, C.ink), ColorSequenceKeypoint.new(0.5, C.green), ColorSequenceKeypoint.new(1, C.green) })
			disc.BackgroundColor3 = Color3.new(1, 1, 1)
		end
	end
	for k = 0, 3 do -- 8조각 금
		local line = frame(disc, UDim2.new(0.5, -s / 2, 0.5, -1), UDim2.fromOffset(s, 3), C.ink, nil)
		line.Rotation = k * 45
		line.BackgroundTransparency = mode == "gray" and 0.2 or 0.4
	end
	return disc
end

local function person(parent, pos, s)
	local p = frame(parent, pos, UDim2.fromOffset(s * 0.5, s), Color3.new(), nil)
	p.BackgroundTransparency = 1
	frame(p, UDim2.fromScale(0.2, 0), UDim2.fromScale(0.6, 0.3), Color3.fromHex("#FFD9A6"), UDim.new(0.2, 0), 2)
	frame(p, UDim2.fromScale(0.1, 0.32), UDim2.fromScale(0.8, 0.4), Color3.fromHex("#4C8DFF"), UDim.new(0.1, 0), 2)
	frame(p, UDim2.fromScale(0.15, 0.72), UDim2.fromScale(0.7, 0.28), Color3.fromHex("#2B3A67"), UDim.new(0.1, 0), 2)
	return p
end

local function card()
	local bg = screen("A1 목업 ③ 보스 기믹 카드(18번 시트) - 그림 3컷 + 40자 이하 한 줄")
	local w = frame(bg, UDim2.fromOffset(120, 80), UDim2.fromOffset(1000, 470), C.panel, UDim.new(0, 18), 4)
	local head = frame(w, UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, 58), C.green, UDim.new(0, 18))
	label(head, UDim2.fromOffset(20, 6), UDim2.new(1, -40, 1, -12), "구간 수호자 — 땅 무너짐", 30, FONT_KO, C.text, Enum.TextXAlignment.Left)
	local steps = {
		{ "1", C.orange, "금 가는 조각 보기", "gray" },
		{ "2", C.green, "초록 조각으로!", "split" },
		{ "3", C.red, "늦으면 떨어져요", "fall" },
	}
	for i, st in ipairs(steps) do
		local x = 24 + (i - 1) * 322
		local panel = frame(w, UDim2.fromOffset(x, 76), UDim2.fromOffset(300, 290), C.panel2, UDim.new(0, 14))
		local num = frame(panel, UDim2.fromOffset(10, 10), UDim2.fromOffset(40, 40), st[2], UDim.new(1, 0), 3)
		label(num, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), st[1], 24, FONT_LATIN)
		pizza(panel, UDim2.fromOffset(70, 50), 160, st[4])
		local who = person(panel, UDim2.fromOffset(i == 1 and 128 or (i == 2 and 185 or 120), i == 3 and 150 or 80), 60)
		who.ZIndex = 4
		if i == 3 then
			label(panel, UDim2.fromOffset(200, 10), UDim2.fromOffset(90, 34), "−45%", 26, FONT_LATIN, C.red)
		end
		if i < 3 then
			label(w, UDim2.fromOffset(x + 300, 200), UDim2.fromOffset(22, 30), "▶", 22, FONT_LATIN, C.text)
		end
		label(panel, UDim2.fromOffset(0, 240), UDim2.new(1, 0, 0, 36), st[3], 22)
	end
	local line = frame(w, UDim2.fromOffset(24, 384), UDim2.new(1, -48, 0, 60), C.ink, UDim.new(0, 12))
	label(line, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "빨간 조각이 떨어져요. 초록 조각으로 가요!", 26) -- 21자(≤ 40)
end

function A1UiMockups.show(which)
	if which == "hud" then
		hud()
	elseif which == "equipment" then
		equipment()
	elseif which == "card" then
		card()
	end
	return gui
end

function A1UiMockups.hide()
	if gui then
		gui:Destroy()
		gui = nil
	end
end

return A1UiMockups
