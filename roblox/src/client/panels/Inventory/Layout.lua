-- 장비창 배치 계산(S20b) - 순수 함수. 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋) → 폰 / PC 판정 + 각 영역의 치수. Instance를 만들지 않는다(자체 점검이 가상 화면으로 그대로 부른다).
--
-- 원칙(사용자 결정 2026-09-21): 캔버스 전체를 UIScale로 줄이지 않는다 - 좁으면 배치를 바꾼다. 배율은 항상 1이라 명목 글씨 = 화면 글씨(실효 12 이상)다.
-- **폰 / PC 판정은 화면 크기 기준이다**(터치 여부가 아니다 - PC 창을 줄여도 같은 결과): ScreenGui 폭 < 720 또는 높이 < 400 이면 폰(1단), 아니면 PC(2단).
--   근거: PC 2단은 장비 칸 228 + 가방 5열(78 × 5 + 8 × 4 + 여백 28 = 450)이 들어가는 폭 720 이상 · 상세 바(104) + 탭 + 헤더를 얹고도 본문이 보이는 높이 400 이상이 필요하다.
--   800 × 360(ScreenGui 800 × 302) · 667 × 375(667 × 317) · 842 × 388(842 × 330)은 높이 400 미만이라 폰이고, 1024 × 768(1024 × 710) · 지금 Studio 창 1321 × 484(ScreenGui 1321 × 426)는 PC다.
--   경계값은 COMMON.md §2 "모바일 기준 해상도"에도 적어 둔다.
-- 폰: 창은 메뉴바 오른쪽부터 화면 오른쪽 끝(여백 8)까지 · 1단. 상단 탭 [장비 / 가방 / 보석] · 내용은 세로 스크롤 · 아이템 상세는 툴팁이 아니라 아래에서 올라오는 시트(닫기 44). 모든 버튼 · 칸 터치 44 이상.
-- PC: 2단(장비 칸 + 가방) 그대로 · 낮은 창에서는 두 칸이 각각 세로 스크롤.

local Layout = {}

Layout.phoneWidthBelow = 720
Layout.phoneHeightBelow = 400
Layout.margin = 8 -- 화면 가장자리 안전 여백(UIManager.safeMargin과 같은 값)

-- 칸 치수(원래 720 × 560 목업 값 그대로 - 크기를 줄이지 않는다)
Layout.cellSize, Layout.cellGap = 78, 8
Layout.gearSlot, Layout.gearGap = 95, 9
Layout.pcWidth, Layout.pcHeight = 720, 560
Layout.gearWidth = 228 -- PC 장비 칸 폭
Layout.pcDetailHeight = 104 -- PC 하단 상세 바
Layout.wideSheetWidth = 700 -- 폰에서 창 폭이 이 이상이면 상세 시트가 한 줄(정보 + 버튼), 미만이면 두 줄(정보 위 · 버튼 아래)
Layout.phoneLeftInset = 72 -- 폰 창의 왼쪽 여백: 메뉴바(B · P · M - hud/MenuBar, 오른쪽 끝 66)가 창 위에 그려지므로 그 오른쪽부터 시작한다(스크린샷 Play에서 겹침 발견)

-- 화면 크기로 판정(폰이면 true).
function Layout.isPhone(screenWidth, screenHeight)
	return screenWidth < Layout.phoneWidthBelow or screenHeight < Layout.phoneHeightBelow
end

-- 한 줄에 들어가는 칸 수(가로 여백 좌우 14씩 = 28).
local function columns(width, cell, gap)
	return math.max(1, math.floor((width - 28 + gap) / (cell + gap)))
end

-- 반환: { mode, screenW, screenH, winW, winH, headerH, tabH, bodyTop, bodyH, detailH(PC 바 높이 · 폰은 시트 높이), sheetWide, pillH, closeSize, actionH, tabNames,
--         gearW, bagW, gearCols, bagCols }
function Layout.compute(screenWidth, screenHeight)
	local phone = Layout.isPhone(screenWidth, screenHeight)
	local L = { screenW = screenWidth, screenH = screenHeight, mode = phone and "phone" or "pc" }
	local margin = Layout.margin
	if phone then
		L.winX = Layout.phoneLeftInset
		L.winW, L.winH = screenWidth - Layout.phoneLeftInset - margin, screenHeight - 2 * margin
		L.headerH, L.tabH = 52, 44
		L.pillH, L.closeSize, L.actionH, L.tabButtonH = 44, 44, 44, 44
		L.tabNames = { "장비", "가방", "보석" }
		L.sheetWide = L.winW >= Layout.wideSheetWidth
		L.detailH = L.sheetWide and 84 or 140 -- 시트 높이
		L.gearW, L.bagW = L.winW, L.winW
		L.bodyH = L.winH - (L.headerH + L.tabH) -- 시트는 본문 위에 얹힌다(가린다)
	else
		L.winW, L.winH = math.min(Layout.pcWidth, screenWidth - 2 * margin), math.min(Layout.pcHeight, screenHeight - 2 * margin)
		L.headerH, L.tabH = 44, 30
		L.pillH, L.closeSize, L.actionH, L.tabButtonH = 26, 26, 34, 22
		L.tabNames = { "장비", "보석" }
		L.sheetWide = true
		L.detailH = Layout.pcDetailHeight
		L.gearW = Layout.gearWidth
		L.bagW = L.winW - (Layout.gearWidth + 1)
		L.bodyH = L.winH - (L.headerH + L.tabH + L.detailH)
	end
	L.bodyTop = L.headerH + L.tabH
	L.gearCols = columns(L.gearW, Layout.gearSlot, Layout.gearGap)
	L.bagCols = columns(L.bagW, Layout.cellSize, Layout.cellGap)
	return L
end

return Layout
