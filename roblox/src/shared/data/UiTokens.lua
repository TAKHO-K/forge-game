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
		["accent.text"] = "3A2A12", -- 노랑 위 글자
		info = "8FD8FF", -- 구경 모드 띠 선
		success = "3FC97A", -- 토글 켜짐
		warning = "F2453D", -- 닫기 · 알림 점(작게만)
		["disabled.bg"] = "3A4058",
		["lore.text"] = "E8DCC0", -- 설정 문구
		["title.sub"] = "FFE7A3", -- BEYOND LEGENDARY 부제
	},
	text = {
		title = { pc = 72, phone = 28 }, -- 게임 제목(외곽선 titleStroke)
		titleExpanded = { pc = 46, phone = 28 }, -- 이어하기 창 펼침 때
		titleSub = { pc = 18, phone = 12 },
		mainButton = { pc = 28, phone = 18 },
		mainButtonSub = { pc = 16, phone = 12 },
		button = { pc = 24, phone = 15 },
		buttonExpanded = { pc = 22, phone = 15 },
		cardName = { pc = 24, phone = 15 },
		cardInfo = { pc = 16, phone = 12 },
		windowTitle = { pc = 26, phone = 17 },
		confirmBody = { pc = 19, phone = 14 },
		confirmSub = { pc = 15, phone = 12 },
		lore = { pc = 24, phone = 15 },
		caption = { pc = 14, phone = 12 },
	},
	titleStroke = { pc = 6, phone = 3 },
	minPhoneText = 12,
	minTouch = 44,
	fonts = { korean = "GothamBlack", koreanBold = "GothamBold", number = "FredokaOne" }, -- 한글 = 기본 글꼴 Bold · 숫자 · 영문 = 카툰(한 줄에 섞지 않음)
	corner = { button = 12, window = 16, card = 12, chip = 8 },
	stroke = { window = 3, card = 2, cardSelected = 3, close = 3, button = 2, slotEmpty = 2, slotLocked = 2 },
	lip = 4, -- 버튼 아래턱(눌림 = Y + lip)
	windowHead = { pc = 68, phone = 48 },
	windowLine = { pc = 4, phone = 3 }, -- 머리 아래 노랑 줄
	bandHeight = { pc = 64, phone = 52 }, -- 안내 띠
	close = { size = 44, pressScale = 0.92 },
	confirmOpenScale = 0.9, -- 확인 창 열 때 UIScale 0.9 → 1
	dimTransparency = 0.5,
	tweenSeconds = 0.25,
	iconSlot = { pc = 88, phone = 56 }, -- 무기 · 아이콘 칸
	tendencyBlocks = 5, -- 성향 막대 칸 수
}
