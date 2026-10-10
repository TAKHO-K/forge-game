-- UI-1 0단계 HUD 배치 계산(순수 - 레이아웃 하네스 · 실제 HUD가 같은 함수를 부른다). 출처 = 02_hud/v6 spec §2 · §3 · §4 · §9.
--   ① 폰 판정 하나: 안전 영역 짧은 변 ≤ phoneMaxShortSide 또는 터치만(키보드 없음) → 폰 배치.
--   ② HUD 배율 하나(m): PC = clamp(min(가로 ÷ 1920, 세로 ÷ 1080), 0.75, 1.25) · 폰 = min(가로 ÷ 800, 세로 ÷ 360). 메뉴 · 칩 · 미니맵 · 스킬 줄 · 체력바가 같은 m.
--   ③ 요소 자리 = 기준 좌표 { x, y, w, h } + 붙는 쪽(anchor): 왼(L) · 오른(R) · 가운데(C) × 위(T) · 아래(B) · 가로 전체(W · WB = 아래 끝 · WT = 위 끝 전체 폭).
--      화면 x = 붙는 쪽 기준 거리 × m(오른쪽 붙음 = 화면 오른쪽 끝에서 (기준 폭 − x) × m) → 좁은 화면에서도 오른쪽 · 아래 요소가 화면 끝을 지킨다.
--   ④ 오른쪽 열 접기(B-7): 필요 높이 = 시작 y + 칸 수 × (칸 + 이름표 × 글자 배율) + (칸 수 − 1) × 간격 · 쓸 수 있는 높이 = 화면 세로 ÷ m − 아래 여백.
local HudPlace = {}

HudPlace.base = { pc = { w = 1920, h = 1080 }, phone = { w = 800, h = 360 } }
HudPlace.phoneMaxShortSide = 500
HudPlace.mClamp = { 0.75, 1.25 }
HudPlace.topBarPx = 58 -- 로블록스 상단 바(화면 px · 우리 배율로 안 줄어듦) - 위에 붙는 요소의 y는 이 아래 끝에서 잰다(1366×768에서 y 66 × 0.75 = 49.5가 상단 바를 침범하던 것)

function HudPlace.isPhone(viewW, viewH, touch, keyboard)
	local short = math.min(viewW or 0, viewH or 0)
	return (short > 1 and short <= HudPlace.phoneMaxShortSide) or (touch == true and keyboard ~= true)
end

function HudPlace.scale(viewW, viewH, phone)
	local b = phone and HudPlace.base.phone or HudPlace.base.pc
	local s = math.min(viewW / b.w, viewH / b.h)
	if phone then
		return s
	end
	return math.clamp(s, HudPlace.mClamp[1], HudPlace.mClamp[2])
end

-- anchor 글자 → (가로 붙는 비율, 세로 붙는 비율): L 0 · C 0.5 · R 1 / T 0 · B 1
local AX = { L = 0, C = 0.5, R = 1, W = 0 }
local AY = { T = 0, B = 1, M = 0.5 }
function HudPlace.anchorOf(anchor)
	anchor = anchor or "TL"
	local v, h = anchor:sub(1, 1), anchor:sub(2, 2)
	if anchor == "W" or anchor == "WB" then
		return 0, 1, true -- 아래 끝 전체 폭(경험치 줄)
	elseif anchor == "WT" then
		return 0, 0, true -- 위 끝 전체 폭(상단 바)
	end
	return AX[h] or 0, AY[v] or 0, false
end

-- 세로 자리: 위에 붙음(ay 0)이고 y ≥ 상단 바 = 상단 바 아래 끝 + (y − 58) × m · 아래 붙음 = 화면 아래 끝 − (기준 높이 − y) × m
function HudPlace.topY(y, ay, viewH, m, b)
	if ay == 0 and y >= HudPlace.topBarPx then
		return HudPlace.topBarPx + (y - HudPlace.topBarPx) * m
	end
	return viewH * ay + (y - b.h * ay) * m
end

-- 기준 rect + 붙는 쪽 → 화면 rect { x, y, w, h }(px)
function HudPlace.screenRect(rect, anchor, viewW, viewH, m, phone)
	local b = phone and HudPlace.base.phone or HudPlace.base.pc
	local ax, ay, wide = HudPlace.anchorOf(anchor)
	local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
	local sy = HudPlace.topY(y, ay, viewH, m, b)
	if wide then
		return { 0, sy, viewW, h * m }
	end
	local sx = viewW * ax + (x - b.w * ax) * m
	return { sx, sy, w * m, h * m }
end

-- 실제 GuiObject에 넣을 값: Position = UDim2.new(ax, ox, ay, oy) · AnchorPoint (0, 0) · Size = 기준 w × h + UIScale m(왼쪽 위 기준으로 커짐)
--   반환 = ax, ox, ay, oy(호출부가 UDim2를 만든다 - 하네스는 UDim2 없이 숫자만 본다)
function HudPlace.udim(rect, anchor, m, phone)
	local b = phone and HudPlace.base.phone or HudPlace.base.pc
	local ax, ay, wide = HudPlace.anchorOf(anchor)
	local oy = HudPlace.topY(rect[2], ay, 0, m, b)
	if wide then
		return 0, 0, ay, oy
	end
	return ax, (rect[1] - b.w * ax) * m, ay, oy
end

-- B-7 오른쪽 열 접기: n = 보이는 칸 수(구역 선택 · 퀘스트 · 보상 · 상점 · 귀환 순) → { stage, outer = 바깥 열 칸 수, inner = 안쪽 열 칸 수, toMore = 더보기로 보낼 칸 수, labelH }
--   spec = { y, size, gap, label, bottomPad } · viewH = 화면 세로 px · m · textMul = 글자 배율(이름표만 늘어남)
function HudPlace.rightFold(spec, n, viewH, m, textMul)
	local labelH = spec.label * (textMul or 1)
	local function need(k)
		return spec.y + k * (spec.size + labelH) + math.max(k - 1, 0) * spec.gap
	end
	local avail = viewH / m - spec.bottomPad
	if need(n) <= avail then
		return { stage = 1, outer = n, inner = 0, toMore = 0, labelH = labelH, need = need(n), avail = avail }
	end
	local outerN = math.min(3, n)
	if need(outerN) <= avail then
		return { stage = 2, outer = outerN, inner = n - outerN, toMore = 0, labelH = labelH, need = need(outerN), avail = avail }
	end
	local o = math.min(2, n)
	local i = math.min(1, math.max(n - o, 0))
	return { stage = 3, outer = o, inner = i, toMore = n - o - i, labelH = labelH, need = need(o), avail = avail }
end

-- 두 rect 겹침(px) - 하네스 · 자체 점검
function HudPlace.overlap(a, b)
	local w = math.min(a[1] + a[3], b[1] + b[3]) - math.max(a[1], b[1])
	local h = math.min(a[2] + a[4], b[2] + b[4]) - math.max(a[2], b[2])
	if w <= 0 or h <= 0 then
		return 0, 0
	end
	return w, h
end

return HudPlace
