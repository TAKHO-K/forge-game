-- 장비창 배치 계산(S20b · QUEUE-ALL2 P2 ref 17 3단) - 순수 함수. 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋) → 폰 / PC 판정 + 각 영역의 치수. Instance를 만들지 않는다(자체 점검이 가상 화면으로 그대로 부른다).
--
-- 원칙(사용자 결정 2026-09-21): 캔버스 전체를 UIScale로 줄이지 않는다 - 좁으면 배치를 바꾼다. 배율은 항상 1이라 명목 글씨 = 화면 글씨(실효 12 이상)다.
-- **폰 / PC 판정은 화면 크기 기준이다**(터치 여부가 아니다 - PC 창을 줄여도 같은 결과): ScreenGui 폭 < 720 또는 높이 < 400 이면 폰(1단), 아니면 PC(3단).
--   800 × 360(ScreenGui 800 × 302) · 667 × 375(667 × 317) · 842 × 388(842 × 330)은 높이 400 미만이라 폰이고, 1024 × 768(1024 × 710) · Studio 창 1321 × 484(1321 × 426)는 PC다.
--   경계값은 COMMON.md §2 "모바일 기준 해상도"에도 적어 둔다.
-- PC(ref 17): 3단 = 왼쪽 착용 중(캐릭터 + 4칸 + 스탯 · 세트 효과) · 가운데 가방(탭 + 정렬/필터 줄 + 격자) · 오른쪽 선택 아이템 상세 카드(항상 보임).
--   창 폭이 wideWidth(1100) 이상이면 넓은 3단(왼쪽 260 · 오른쪽 360), 미만이면 좁은 3단(190 · 290). 보석 · 도감 탭은 왼쪽 + 가운데 자리(bodyX · bodyW)를 쓰고 오른쪽 상세는 그대로 남는다.
-- 폰: 창은 메뉴바 오른쪽부터 화면 오른쪽 끝(여백 8)까지 · 1단. 상단 탭 [장비 · 전체 · 갑옷 · 장갑 · 신발 · 보석] · 내용은 세로 스크롤 · 아이템 상세는 아래에서 올라오는 시트(높이는 DetailSheet가 버튼 줄 수로 정한다 · 닫기 44). 모든 버튼 · 칸 터치 44 이상.

local Layout = {}
local BAG_V2 = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).bag -- QUEUE-UI2 UI2-5 2차(03 v2 겉모습 - lookV2 끄면 옛 값)
Layout.lookV2 = BAG_V2 ~= nil and BAG_V2.lookV2 == true
-- UI-1c 5단계: 장비 상세 = 칸 옆 고정 창(스위치 gearPin) → PC 오른쪽 상세 단 없음(가방 목록이 넓어짐 · 열 = bag.pin.pc.maxCols) · detailX = nil(고정 창이 자리를 정한다)
Layout.pin = require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).gearPin == true and BAG_V2 ~= nil and BAG_V2.pin ~= nil

Layout.phoneWidthBelow = 720
Layout.phoneHeightBelow = 400
Layout.margin = 8 -- 화면 가장자리 안전 여백(UIManager.safeMargin과 같은 값)

Layout.cellSize, Layout.cellGap = 78, 8 -- 가방 칸(줄이지 않는다) - 폰
-- QUEUE-UI2 UI2-5(03 v2): PC 창 1600 × 880 · 3구역 왼쪽 312 · 가운데 716 · 오른쪽 500 · 칸 88 · 간격 10 · 최대 7열(작은 화면 = 예전처럼 들어가는 만큼)
Layout.pc = { cellSize = 88, cellGap = 10, maxCols = 7, leftW = 312, rightW = 500 }
Layout.pcWidth, Layout.pcHeight = 1600, 880 -- PC 창 최대(03 v2 - 옛 1240 × 720)
Layout.wideWidth = 1100
Layout.pad, Layout.colGap = 12, 10
Layout.phoneLeftInset = 72 -- 폰 창의 왼쪽 여백: 메뉴바(hud/MenuBar, 오른쪽 끝 66)가 창 위에 그려지므로 그 오른쪽부터 시작한다(스크린샷 Play에서 겹침 발견)
Layout.gridPad = 12 -- 가방 격자 좌우 여백(스크롤 막대 자리 포함)
Layout.currencyH = 28 -- QUEUE-ALL9B R3 헤더 아래 재화 줄(모든 재화 한 줄 - 모자라면 줄이 넘쳐 두 줄 = 아이콘 18 · 글씨 13)

-- 탭 id: 가방 필터(all · armor · gloves · shoes) · 보석(gem) · 폰 장비(gear) · 도감(codex - 스위치 뒤, Shell이 붙인다)
Layout.filterTabs = { all = true, armor = true, gloves = true, shoes = true }

-- 화면 크기로 판정(폰이면 true).
function Layout.isPhone(screenWidth, screenHeight)
	return screenWidth < Layout.phoneWidthBelow or screenHeight < Layout.phoneHeightBelow
end

-- 폭 width 안에 한 줄로 들어가는 칸 수.
local function columns(width, cell, gap)
	return math.max(1, math.floor((width + gap) / (cell + gap)))
end

-- 반환: { mode, wide, screenW, screenH, winX, winW, winH, headerH, tabH, tabX, tabY, tabW, tabButtonH, pillH, closeSize, actionH, tabs(= tabNames),
--         bodyTop, bodyH, bodyX, bodyW(보석 · 도감 본문), gearX/Y/W/H, bagX/Y/W/H, detailX/Y/W/H(PC 오른쪽 카드 - 폰은 시트라 nil), gearSlot, gearCols, bagCols }
-- hudReserve(선택 · PC) = { left, right } 화면 px - HUD v5 메뉴 열 자리(창 폭에서 뺀다 · Shell이 그 사이에 놓는다)
function Layout.compute(screenWidth, screenHeight, touch, hudReserve)
	local phone = Layout.isPhone(screenWidth, screenHeight)
	local L = { screenW = screenWidth, screenH = screenHeight, mode = phone and "phone" or "pc" }
	local margin = Layout.margin
	if phone then
		L.winX = Layout.phoneLeftInset
		L.winW, L.winH = screenWidth - Layout.phoneLeftInset - margin, screenHeight - 2 * margin
		L.headerH, L.tabH = 52, 44
		L.currencyH = Layout.currencyH -- QUEUE-ALL9B R3 헤더 아래 재화 줄
		L.pillH, L.closeSize, L.actionH, L.tabButtonH = 44, 44, 44, 44
		if Layout.lookV2 then -- 03 v2: 머리 48 + 노랑 줄 4 · 그림 탭 44 + 위아래 4
			L.headerH, L.tabH = BAG_V2.phone.headH + BAG_V2.phone.line, BAG_V2.phone.tabSize + 8
			L.closeSize, L.tabButtonH = BAG_V2.phone.close, BAG_V2.phone.tabSize
		end
		L.tabs = { "gear", "all", "armor", "gloves", "shoes", "gem" }
		L.tabX, L.tabY, L.tabW = 0, L.headerH + L.currencyH, L.winW
		L.bodyTop = L.headerH + L.currencyH + L.tabH
		L.bodyH = L.winH - L.bodyTop -- 시트는 본문 위에 얹히지 않고 본문을 줄인다(S.sheetInset)
		L.bodyX, L.bodyW = 0, L.winW
		L.gearX, L.gearY, L.gearW, L.gearH = 0, L.bodyTop, L.winW, L.bodyH
		L.bagX, L.bagY, L.bagW, L.bagH = 0, L.bodyTop, L.winW, L.bodyH
		L.gearSlot = 78
		L.gearCols = 4
		L.pin = Layout.pin or nil
		L.sheetWide = true -- 폰 시트는 항상 두 칸(왼쪽 정보 스크롤 · 오른쪽 버튼)
	else
		-- QUEUE-ALL9C 2-6: 터치 화면(태블릿 · 큰 폰 842 × 534)은 창이 메뉴바 오른쪽(phoneLeftInset)부터 그려진다 → 그만큼 뺀 폭으로 3단을 짠다
		--   (옛 = 화면 폭으로 짜서 오른쪽 상세 카드가 창 밖으로 밀려 안내 글 · 테두리가 잘렸다)
		local availW = screenWidth - 2 * margin - (touch and (Layout.phoneLeftInset - margin) or 0) - (hudReserve and (hudReserve.left + hudReserve.right) or 0)
		L.winW, L.winH = math.min(Layout.pcWidth, availW), math.min(Layout.pcHeight, screenHeight - 2 * margin)
		L.headerH, L.tabH = 48, 36
		L.currencyH = Layout.currencyH -- QUEUE-ALL9B R3
		L.pillH, L.closeSize, L.actionH, L.tabButtonH = 30, 32, 44, 30
		if Layout.lookV2 then -- 03 v2: 머리 64 + 노랑 줄 4(재화 = 머리 오른쪽 - 줄 없음) · 탭 44 · 정렬 줄 44 · 닫기 44
			L.headerH, L.currencyH = BAG_V2.pc.headH + BAG_V2.pc.line, 0
			L.tabH, L.tabButtonH, L.pillH, L.closeSize = BAG_V2.pc.tabH + 8, BAG_V2.pc.tabH, BAG_V2.pc.rowH, BAG_V2.pc.close
		end
		L.tabs = { "all", "armor", "gloves", "shoes", "gem" }
		L.wide = L.winW >= Layout.wideWidth
		local pad, gap = Layout.pad, Layout.colGap
		local leftW = L.wide and (L.winW >= Layout.pcWidth and Layout.pc.leftW or 260) or 190
		local rightW = L.wide and (L.winW >= Layout.pcWidth and Layout.pc.rightW or 360) or 290
		if Layout.pin then
			rightW = 0 -- 오른쪽 단 없음(아래 midW에 그 단 앞 간격도 돌려줌)
		end
		-- 정렬 · 일괄 버튼 자리: 가운데 단이 넓으면(400) 가방 위 줄 · 아니면 머리 오른쪽(BagTab.layoutBag와 같은 판정)
		L.pillsInRow = L.winW - 2 * pad - 2 * gap - leftW - rightW >= 400
		L.currencyInHeader = Layout.lookV2 and L.pillsInRow -- 03 v2: 재화 = 머리 오른쪽(버튼이 머리에 있으면 옛처럼 머리 아래 줄)
		if Layout.lookV2 and not L.currencyInHeader then
			L.currencyH = Layout.currencyH
		end
		local colTop = L.headerH + L.currencyH + pad
		local colH = L.winH - colTop - pad
		local midMin = Layout.cellSize + 2 * Layout.gridPad
		local midW = math.max(midMin, L.winW - 2 * pad - (Layout.pin and 1 or 2) * gap - leftW - rightW)
		local midX = pad + leftW + gap
		L.gearX, L.gearY, L.gearW, L.gearH = pad, colTop, leftW, colH
		L.tabX, L.tabY, L.tabW = midX, colTop, midW
		L.bodyTop = colTop + L.tabH + 6
		L.bodyH = L.winH - L.bodyTop - pad
		L.bagX, L.bagY, L.bagW, L.bagH = midX, L.bodyTop, midW, L.bodyH
		L.bodyX, L.bodyW = pad, leftW + gap + midW
		L.detailX, L.detailY, L.detailW, L.detailH = midX + midW + gap, colTop, rightW, colH
		if Layout.pin then
			L.detailX, L.detailW, L.pin = nil, nil, true
		end
		if midW < 330 then
			-- 아주 좁은 PC(폭 720 ~ 900): 가운데 단에 탭 5개가 안 들어간다 - 탭 줄을 왼쪽 + 가운데 단 위로 넓히고 착용 칸도 탭 아래에서 시작한다.
			L.tabX, L.tabW = pad, L.bodyW
			L.gearY, L.gearH = L.bodyTop, L.bodyH
		end
		L.gearSlot = L.wide and 80 or 70
		L.gearCols = 2
		L.sheetWide = true
	end
	L.tabNames = L.tabs -- 옛 이름(자체 점검이 개수를 센다)
	L.cellSize = phone and Layout.cellSize or Layout.pc.cellSize
	L.cellGap = phone and Layout.cellGap or Layout.pc.cellGap
	L.bagCols = columns(L.bagW - 2 * Layout.gridPad, L.cellSize, L.cellGap)
	if not phone then
		L.bagCols = math.min(L.bagCols, Layout.pin and BAG_V2.pin.pc.maxCols or Layout.pc.maxCols)
	end
	return L
end

return Layout
