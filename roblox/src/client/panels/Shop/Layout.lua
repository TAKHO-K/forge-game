-- 상점 창 배치 계산(QUEUE-B1 B2 UI) - 순수 함수. 화면 크기(ScreenGui 폭 · 높이 = 뷰포트 - 상단 인셋) + 터치 여부 → 폰 / PC 판정과 각 영역 치수. Instance를 만들지 않는다
-- (자체 점검이 800 × 302 · 667 × 317 · 842 × 330 · 1024 × 710으로 그대로 부른다 - COMMON §2 모바일 기준 해상도).
-- 폰 / PC 판정 = 화면 크기(panels/Inventory/Layout.isPhone - 경계 한 곳). 폰은 메뉴바 오른쪽(phoneLeftInset)부터 화면 오른쪽 끝(여백 4)까지 · 위아래 여백 4 · 버튼 · 탭 · 행 44 이상.
-- 패널 제목줄 높이는 kit/Panel이 터치 여부(Theme.isMobile)로 정한다(44 / 40) - 그래서 touch를 인자로 받는다.
local InventoryLayout = require(script.Parent.Parent.Inventory.Layout)

local Layout = {}

-- QUEUE-ALL9C 1-6R 창 크기(사용자 10-03 "기본 창이 작고 너무 하단 - 답답"): PC · 태블릿 = 사용 가능 영역(위 재화 줄 · 아래 HP · 스킬 줄 · 안전 영역 뺀 곳)의
--   폭 75% · 높이 80%(최소 720 × 480 · 최대 1200 × 760 · 그래도 화면 - 여백 안) · 그 영역 정중앙(AnchorPoint 0.5, 0.5). 폰 = 거의 전체 화면(메뉴바 오른쪽 ~ 끝 · 여백 4).
Layout.minWidth, Layout.minHeight = 720, 480
Layout.maxWidth, Layout.maxHeight = 1200, 760 -- Panel.create maxSize로 넘긴다
if require(game:GetService("ReplicatedStorage").Shared.data.UiV2Flags).rest then -- UI-1 7c 04 v2: 디자인 시스템 큰 창 1600 × 880(예외 없음)
	local S = require(game:GetService("ReplicatedStorage").Shared.data.UiLayoutData).shop.v2
	Layout.maxWidth, Layout.maxHeight = S.maxW, S.maxH
end
Layout.areaW, Layout.areaH = 0.75, 0.8
Layout.hudTop = 60 -- 위 재화 줄(Studio 실측 HUD 위 끝 약 60)
Layout.hudBottom = 116 -- 아래 HP 바 · 스킬 줄 · 경험치 줄(Studio 실측 화면 아래에서 113)
Layout.margin = InventoryLayout.margin
Layout.phoneMargin = 4
Layout.statusHeight = 24
Layout.phoneStatusHeight = 20
Layout.pad = 12 -- 본문 좌우 여백
Layout.phonePad = 8
Layout.scrollBar = 6 -- 스크롤 막대 자리(행 폭에서 뺀다)
Layout.gap = 6 -- 행 안 버튼 사이

-- 반환: { mode("phone"|"tablet"|"pc"), screenW, screenH, winX, winY(앵커 점 자리 px), anchorX, anchorY, winW, winH, titleH, tabH, buttonH, rowH, statusH, bodyTop, bodyH, rowW,
--   railW(PC · 태블릿 왼쪽 세로 탭 폭 · 폰 0) · bodyX · bodyW · chipsH(치장 하위 칩 줄) · cols · cardW · cardH · cardGap · pad }
--   카드: PC 4열 · 태블릿 3열 = 3:4 / 폰 = 폭 phoneCardMin 이상으로 들어가는 만큼 열(최소 2) · 5:4 가로형 · 높이 상한 = 본문(칩 줄 있는 치장 탭 기준) × 0.8
--   (사용자 10-03: 가로 폰에서 한 줄이 통째로 보이고 다음 줄 윗부분이 살짝 - 스크롤이 있음을 알게). 최소: 버튼 44 · 이름 caption(Card가 지킨다).
--   bodyTop · bodyH = 칩 줄이 없을 때의 본문 자리(치장 탭은 chipsH + 4만큼 내려 그린다 - init).
Layout.cols = { pc = 4, tablet = 3, phone = 2 }
Layout.phoneCardMin = 160
Layout.phoneCardRatio = 0.8 -- 높이 = 폭 × 0.8(5:4)
Layout.phoneCardBodyShare = 0.8
Layout.railWidth = 112
Layout.cardGap = 8
function Layout.compute(screenW, screenH, touch)
	local phone = InventoryLayout.isPhone(screenW, screenH)
	local L = { screenW = screenW, screenH = screenH, mode = phone and "phone" or (touch and "tablet" or "pc") }
	if phone then
		local m = Layout.phoneMargin
		L.anchorX, L.anchorY = 0, 0
		L.winX, L.winY = InventoryLayout.phoneLeftInset, m
		L.winW = screenW - InventoryLayout.phoneLeftInset - m
		L.winH = screenH - 2 * m
		L.tabH, L.buttonH, L.rowH = 44, 44, 56
		L.pad = Layout.phonePad
		L.statusH = Layout.phoneStatusHeight
	else
		local m = Layout.margin
		local areaTop = Layout.hudTop
		local areaH = math.max(0, screenH - Layout.hudTop - Layout.hudBottom)
		L.winW = math.min(screenW - 2 * m, math.clamp(math.floor((screenW - 2 * m) * Layout.areaW), Layout.minWidth, Layout.maxWidth))
		L.winH = math.min(screenH - 2 * m, math.clamp(math.floor(areaH * Layout.areaH), Layout.minHeight, Layout.maxHeight))
		L.anchorX, L.anchorY = 0.5, 0.5
		L.winX = math.floor(screenW / 2)
		-- 사용 가능 영역 가운데 · 화면 밖으로 나가면 화면 안으로(작은 화면 = 최소 크기가 HUD를 덮는다)
		L.winY = math.floor(math.clamp(areaTop + areaH / 2, L.winH / 2 + m, screenH - L.winH / 2 - m))
		L.tabH = touch and 44 or 32
		L.buttonH = touch and 44 or 32
		L.rowH = touch and 56 or 44
		L.pad = Layout.pad
		L.statusH = Layout.statusHeight
	end
	L.titleH = (touch and 44 or 40) + 1 -- kit/Panel 제목줄 + 구분선 1
	L.railW = phone and 0 or Layout.railWidth
	L.bodyX = L.railW + L.pad
	L.bodyW = L.winW - L.railW - 2 * L.pad
	L.bodyTop = phone and (L.tabH + 2) or 4 -- 폰 = 위 가로 탭 아래 · PC = 세로 탭 옆 맨 위
	L.chipsH = L.tabH
	L.bodyH = L.winH - L.titleH - L.bodyTop - L.statusH
	L.rowW = L.bodyW - Layout.scrollBar
	L.cols = Layout.cols[L.mode]
	L.cardGap = Layout.cardGap
	if phone then
		L.cols = math.max(L.cols, math.floor((L.rowW + L.cardGap) / (Layout.phoneCardMin + L.cardGap)))
	end
	L.cardW = math.floor((L.rowW - (L.cols - 1) * L.cardGap) / L.cols)
	if phone then
		local cap = math.floor((L.bodyH - L.chipsH - 4) * Layout.phoneCardBodyShare)
		L.cardH = math.max(Layout.cardMinHeight(L), math.min(math.floor(L.cardW * Layout.phoneCardRatio), cap))
	else
		L.cardH = math.floor(L.cardW * 4 / 3)
	end
	return L
end

-- 카드 최소 높이: 아래(이름 caption · 칸 caption · 버튼) + 그림 최소 40(Card와 같은 계산 - 이름 · 칸 = caption 크기 기준)
function Layout.cardMinHeight(L)
	local caption = L.mode == "phone" and 16 or 14 -- Theme caption(폰 ×1.15)
	return 40 + 4 + (caption + 4) + (caption + 2) + 4 + L.buttonH + 6
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
