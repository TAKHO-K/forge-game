-- 상점 창 배치 계산(QUEUE-B1 B2 UI) - 순수 함수. 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋) + 터치 여부 → 폰 / PC 판정과 각 영역 치수. Instance를 만들지 않는다
-- (자체 점검이 800 × 302 · 667 × 317 · 842 × 330 · 1024 × 710으로 그대로 부른다 - COMMON §2 모바일 기준 해상도).
-- 폰 / PC 판정 = 화면 크기(panels/Inventory/Layout.isPhone - 경계 한 곳). 폰은 메뉴바 오른쪽(phoneLeftInset)부터 화면 오른쪽 끝(여백 8)까지 · 위아래 여백 8 · 버튼 · 탭 · 행 44 이상.
-- 패널 제목줄 높이는 kit/Panel이 터치 여부(Theme.isMobile)로 정한다(44 / 40) - 그래서 touch를 인자로 받는다.
local InventoryLayout = require(script.Parent.Parent.Inventory.Layout)

local Layout = {}

Layout.pcWidth, Layout.pcHeight = 560, 440
Layout.maxWidth, Layout.maxHeight = 720, 480 -- kit/Panel.maxSize(station 패널이 이보다 크면 Panel이 자른다 - 계산도 같은 값으로 자른다)
Layout.margin = InventoryLayout.margin
Layout.pcTop = 16 -- PC: 화면 위에서 띄우는 간격(보석 공방과 같은 자리 - 아래 스킬 바를 가리지 않는다)
Layout.statusHeight = 24
Layout.pad = 12 -- 본문 좌우 여백
Layout.scrollBar = 6 -- 스크롤 막대 자리(행 폭에서 뺀다)
Layout.gap = 6 -- 행 안 버튼 사이

-- 반환: { mode("phone"|"pc"), screenW, screenH, winX, winY, winW, winH, anchorX, titleH, tabH, buttonH, rowH, statusH, bodyTop, bodyH, rowW }
--   winX · winY = 패널 왼쪽 위(anchorX 0) 또는 가운데 위(anchorX 0.5 - PC) 기준 offset. bodyTop · bodyH = content 안 본문 스크롤의 자리(탭 아래 ~ 상태줄 위).
function Layout.compute(screenW, screenH, touch)
	local phone = InventoryLayout.isPhone(screenW, screenH)
	local L = { screenW = screenW, screenH = screenH, mode = phone and "phone" or "pc" }
	local margin = Layout.margin
	if phone then
		L.winX, L.winY, L.anchorX = InventoryLayout.phoneLeftInset, margin, 0
		L.winW = math.min(Layout.maxWidth, screenW - InventoryLayout.phoneLeftInset - margin)
		L.winH = math.min(Layout.maxHeight, screenH - 2 * margin)
		L.tabH, L.buttonH, L.rowH = 44, 44, 56
	else
		L.winW = math.min(Layout.pcWidth, screenW - 2 * margin)
		L.winH = math.min(Layout.pcHeight, screenH - 2 * margin)
		L.winX, L.anchorX = 0, 0.5
		L.winY = math.max(margin, math.min(Layout.pcTop, screenH - L.winH - margin))
		L.tabH = touch and 44 or 32
		L.buttonH = touch and 44 or 32
		L.rowH = touch and 56 or 44
	end
	L.titleH = (touch and 44 or 40) + 1 -- kit/Panel 제목줄 + 구분선 1
	L.statusH = Layout.statusHeight
	L.bodyTop = L.tabH + 4
	L.bodyH = L.winH - L.titleH - L.bodyTop - L.statusH
	L.rowW = L.winW - 2 * Layout.pad - Layout.scrollBar
	return L
end

-- 한 행에 버튼 n개(폭 w)를 오른쪽에 놓을 때 왼쪽 글 칸 폭(음수면 행이 좁다 - 점검용).
function Layout.textWidth(L, buttonCount, buttonWidth)
	if buttonCount <= 0 then
		return L.rowW - 16
	end
	return L.rowW - 16 - buttonCount * buttonWidth - (buttonCount - 1) * Layout.gap - 8
end

-- 칩(장착 고르기) 줄: 칩 n개가 한 줄에 들어가는 폭(칩 폭 chipW). 한 줄 칩 수 = 넘치면 두 줄 이상.
function Layout.chipsPerLine(L, chipW)
	return math.max(1, math.floor((L.rowW + Layout.gap) / (chipW + Layout.gap)))
end

return Layout
