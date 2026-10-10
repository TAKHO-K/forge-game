-- QUEUE-UI UI-0 디자인 토큰 한 곳(색 · 글자 · 모서리 · 테두리 · 간격 · 기준 해상도). 출처 = docs/design/handoff/01_main-menu/v1/spec.md "색 토큰" · "글자" · "부품 구조".
--   00 디자인 시스템 묶음이 오면 이 표의 값만 갱신한다(새 화면 부품 = client/ui/v2/UiKit이 여기서만 읽는다 - 옛 kit/Theme은 기존 화면용으로 그대로).
--   글자 = { pc, phone } px(기준 해상도에서 - 루트 UIScale이 실제 화면에 맞춘다). 폰 글자 최소 12.
return {
	base = { pc = { w = 1920, h = 1080 }, phone = { w = 800, h = 360 } },
	colors = {
		["bg.deep"] = "0E1120", -- 가장 깊은 바탕 · 글자 외곽선
		["bg.top"] = "1E3050", -- 맨 뒤 바탕 그라데이션 위
		["bg.bottom"] = "15203A", -- 맨 뒤 바탕 그라데이션 아래
		["panel.window"] = "161A2B", -- 창 몸통
		["panel.section"] = "20263A", -- 카드 · 창 머리
		["panel.slot"] = "2B3350", -- 보조 버튼 · 꺼진 탭 · 아이콘 칸
		["panel.empty"] = "1A1F33", -- 빈 칸(새 캐릭터) · 보조 버튼 아래턱
		["panel.locked"] = "121626", -- 잠긴 칸
		line = "3A4466", -- 창 · 카드 UIStroke
		["text.primary"] = "FFFFFF",
		["text.secondary"] = "B8C0D6",
		["text.muted"] = "7D87A3",
		accent = "FFC83D", -- 주 버튼(시작 · 구매만) · 선택 카드 테두리
		["accent.lip"] = "C9901A", -- 주 버튼 아래턱
		["accent.pressed"] = "E6B02F", -- 00 spec 누름
		["accent.text"] = "3A2A12", -- 노랑 위 글자
		info = "8FD8FF", -- 구경 모드 띠 선
		success = "3FC97A", -- 토글 켜짐
		warning = "F2453D", -- 닫기 · 알림 점 · 위험 버튼(확인 창 안에서만) · ▼ - 00 spec: 작게만 · 넓은 면 금지 · 전투 HUD 위 = 알림 점만 · 항상 모양(!, X, ▼)과 같이
		["warning.lip"] = "A82620",
		["plate.b"] = "F3E7C2", -- 아이콘 판 B(양피지 크림) · 테두리 outline.warm 3 · 입술 plate.lip
		["plate.lip"] = "C9B48A",
		["outline.warm"] = "2B1B12",
		["outline.cool"] = "1C2140",
		["disabled.bg"] = "3A4058",
		["lore.text"] = "E8DCC0", -- 설정 문구
		["title.sub"] = "FFE7A3", -- BEYOND LEGENDARY 부제
	},
	-- 글자(UI2-2 · 00 spec 단계 + 사용자 임시 하한 10-05: PC body 18 · caption 16 · micro 14 / 폰 display 28 · title 22 · heading 18 · button 18 · body 16 · caption 14 · micro 13 · 12 이하 금지).
	--   Claude Design 새 단계표가 오면 scale 값만 바꾼다. 화면별 이름(cardInfo 등)은 scale 이름을 가리키거나 자기 값(제목 등 특수)을 가진다.
	textScale = {
		display = { pc = 48, phone = 28 },
		title = { pc = 32, phone = 22 },
		heading = { pc = 24, phone = 18 },
		button = { pc = 20, phone = 18 },
		body = { pc = 18, phone = 16 },
		caption = { pc = 16, phone = 14 },
		micro = { pc = 14, phone = 13 },
	},
	text = {
		title = { pc = 72, phone = 28 }, -- 게임 제목(외곽선 titleStroke)
		titleExpanded = { pc = 46, phone = 28 }, -- 이어하기 창 펼침 때
		titleSub = { pc = 18, phone = 13 },
		mainButton = { pc = 28, phone = 18 },
		mainButtonSub = "caption",
		button = { pc = 24, phone = 18 },
		buttonExpanded = { pc = 22, phone = 18 },
		cardName = "heading",
		cardInfo = { pc = 18, phone = 14 }, -- 카드 보조 글(PC body · 폰 caption)
		windowTitle = "title",
		confirmBody = { pc = 20, phone = 16 },
		confirmSub = "caption",
		lore = { pc = 24, phone = 16 },
		caption = "caption",
		micro = "micro",
		hudNumber = { pc = 16, phone = 13 }, -- UI-1b 1절 1: HUD 숫자(체력 · 경험치 %) - 숫자 우선 키움(× textBase = PC 18 · 폰 15)
	},
	-- 설정 "글자 크기"(계정 설정 textScale) = 글자 토큰에만 곱함(아이콘 · 칸 · 버튼 크기 그대로)
	textScaleSteps = { normal = 1.0, large = 1.15, xlarge = 1.3 },
	-- UI-1b 1절 1(사용자 10-10 "글자가 아직 작음" · I v1 spec 0-1): 모든 글자 토큰 기준 × textBase(새 보통 = 옛 크게) · 3단 = 새 보통 기준 1.0 · 1.15 · 1.3(= 옛 1.15 · 1.32 · 1.5)
	--   최소(이보다 작은 글자 없음): PC 본문 18 · 작은 글자 15 / 폰(논리 800×360) 본문 14 · 작은 글자 12. UiV2Flags.text 끔 = textBase 1 · 옛 최소.
	textBase = 1.15,
	minText = { pc = { body = 18, small = 15 }, phone = { body = 14, small = 12 } },
	textScaleOrder = { "normal", "large", "xlarge" },
	-- 로블록스 자체 글자 크기 설정(GuiService.PreferredTextSize) → 배율. 우리 배율과 곱하지 않고 큰 쪽 하나만(두 번 커지지 않게 - UiKit.textMul)
	platformTextScale = { Medium = 1.0, Large = 1.15, Larger = 1.3, Largest = 1.5 },
	-- 화면 루트 UIScale이 작을 때(작은 창 · 노트북 배율) 글자만 덜 줄인다: 실제 글자 배율 = max(루트 배율, textMinRootScale)
	--   UI2-2 원인: Studio 창 1052×592 = 루트 배율 0.548 → 카드 보조 16이 화면에서 약 8.8(캡처 1.75배 = 약 15px · 글자 몸 높이 약 10px)
	textMinRootScale = 0.75,
	titleStroke = { pc = 6, phone = 3 },
	minPhoneText = 12,
	minTouch = 44,
	fonts = { korean = "GothamBlack", koreanBold = "GothamBold", number = "FredokaOne" }, -- 한글 = 기본 글꼴 Bold · 숫자 · 영문 = 카툰(한 줄에 섞지 않음)
	corner = { button = 12, window = 16, card = 12, chip = 8 },
	stroke = { window = 3, card = 2, cardSelected = 3, close = 3, button = 2, slotEmpty = 2, slotLocked = 2 },
	lip = 4, -- 버튼 아래턱(눌림 = Y + lip) - 그림 없는(색) 대체 버튼용
	-- UI2-2 버튼 상태 5개(00 spec "상태 전환 수치") · 9-slice(원본 2배 → SliceScale 0.5)
	press = {
		downSeconds = 0.06, downScale = 0.95, contentDown = 2, -- Quad Out · 내용 y +2
		upSeconds = 0.10, -- Back Out(살짝 넘었다 복귀)
		hoverSeconds = 0.08, hoverScale = 1.03,
		shakeSeconds = 0.24, shakePx = 4, shakeCount = 3, -- 비활성 누름
		focusSeconds = 0.08, focusOutset = 3,
		dragCancel = 8, -- 스크롤 목록 안 누른 뒤 이만큼 넘게 끌면 취소
		disabledIconTransparency = 0.5,
	},
	slice = {
		-- 종류 → 그림 접두사(ArtAssetIds 키 ui/ds/btn-<종류>-<상태>) · SliceCenter(원본 px) · nil = 9-slice 아님(원)
		pri = { center = { 32, 32, 64, 64 } }, primal = { center = { 32, 32, 64, 64 } }, sec = { center = { 32, 32, 64, 64 } },
		danger = { center = { 32, 32, 64, 64 } }, plate = { center = { 32, 32, 64, 64 } }, card = { center = { 32, 32, 64, 64 } },
		["tab-on"] = { center = { 28, 28, 68, 68 } }, ["tab-off"] = { center = { 28, 28, 68, 68 } },
		combat = { center = nil }, close = { center = nil },
	},
	sliceScale = 0.5,
	focusRing = { r12 = { key = "ui/ds/focus-ring-r12", center = { 40, 40, 80, 80 } }, r10 = { key = "ui/ds/focus-ring-r10", center = { 36, 36, 84, 84 } }, circle = { key = "ui/ds/focus-ring-circle" } },
	windowHead = { pc = 68, phone = 48 },
	windowLine = { pc = 4, phone = 3 }, -- 머리 아래 노랑 줄
	bandHeight = { pc = 64, phone = 52 }, -- 안내 띠
	close = { size = 44, pressScale = 0.92 },
	confirmOpenScale = 0.9, -- 확인 창 열 때 UIScale 0.9 → 1
	dimTransparency = 0.5,
	tweenSeconds = 0.25,
	iconSlot = { pc = 88, phone = 56 }, -- 무기 · 아이콘 칸
	tendencyBlocks = 5, -- 성향 막대 칸 수
	newsDot = { pc = 14, phone = 12, inset = 8 }, -- QUEUE-UI1F-1 [소식] 안 읽은 점(지름 · 버튼 오른쪽 위에서 안쪽)
}
