-- QUEUE-UI UI-0 화면 배치 표(코드에 좌표 숫자를 쓰지 않는다). 좌표 = 기준 해상도 px(PC 1920×1080 · 폰 800×360 · 원점 왼쪽 위) { X, Y, W, H }.
--   루트 = client/ui/v2/UiRoot(기준 크기 Frame + UIScale = min(화면W/기준W, 화면H/기준H)) → 실제 화면에 맞춘다.
--   출처 = docs/design/handoff/<주제>/vN/spec.md "화면별 좌표" · 목록(카드 줄)은 첫 줄 + 줄 높이 + 간격으로 적는다(칸 수 = 데이터).
return {
	-- 01 메인 메뉴 · 이어하기 · 직업 선택(01_main-menu/v1)
	mainMenu = {
		pc = {
			robloxButtons = { 0, 0, 132, 60 }, -- 비움(로블록스 기본 버튼)
			keyArt = { 300, 0, 1620, 1080 }, -- 좌 810 + 우 810
			keyArtFade = 0.22, -- 이미지 왼쪽 22% 투명 → 불투명
			title = { 96, 150, 700, 90 }, -- 게임 제목(72) - 목업 pc_01
			titleSub = { 100, 236, 600, 26 }, -- BEYOND LEGENDARY
			titleExpanded = { 96, 196, 360, 60 }, -- 이어하기 펼침(46)
			titleSubExpanded = { 98, 256, 360, 22 },
			-- 메뉴 버튼 묶음(접힘 = 폭 440 · 펼침 = 폭 300)
			menu = {
				x = 96, width = 440, widthExpanded = 300,
				main = { y = 291, h = 88, yExpanded = 309, hExpanded = 76 },
				items = { h = 60, hExpanded = 56, gap = 14, gapExpanded = 14 }, -- 주 버튼 아래 줄(직업 선택 · 설정 · 소식)
			},
			lore = { 96, 690, 460, 110 }, -- 첫 실행 설정 문구(3초 뒤 페이드)
			slotWindow = { 432, 92, 580, 920 }, -- 이어하기 창
			slotWindowNarrow = { 24, 92, 580, 920 }, -- 01 v3 좁은 창 모드(빈 구역 < 키 아트 지킬 영역): 메뉴 숨김 + 창 왼쪽
			narrowMinGapPx = 24, -- 판정 10-05: 왼쪽 묶음(펼친 메뉴 · 제목 글 끝) ↔ 이어하기 창 간격이 이보다 작으면 좁은 창 모드(화면 px)
			slotWindowSlide = 40, -- 펼침: X −40 → 0
			slotList = { x = 19, y = 91, w = 542, selectedH = 158, cardH = 128, emptyH = 92, lockedH = 76, gap = 10 }, -- 창 안 좌표
			slotClose = { 521, 15, 44, 44 }, -- 창 안
			slotCloseRing = true, -- 닫기 원 흰 테두리(PC = 빨강 X 원 · 01 spec)
			slotMore = { 479, 17, 44, 44 }, -- 카드 안(오른쪽 위)
			slotFace = { 18, 16, 96, 96 }, -- 카드 안
			slotWeapon = { 374, 16, 88, 88 }, -- 카드 안
			slotArchive = { 19, 855, 131, 48 }, -- 창 안 보관함 버튼
			slotFooterNote = { 162, 858, 400, 44 },
			confirm = { 720, 400, 520, 309 }, -- 보관 확인 창(01 v3 309)
			confirmCancel = { 31, 188, 223, 56 }, -- 확인 창 안(01 v3 588 − 400)
			confirmOk = { 266, 188, 223, 56 },
			-- 직업 선택
			classBack = { 96, 84, 124, 52 },
			classList = { x = 96, y = 176, w = 320, h = 104, gap = 12 },
			classArt = { 520, 170, 709, 860 },
			classArtSilhouette = { 640, 200, 480, 600 },
			classInfo = { 1290, 150, 534, 510 }, -- 01 v3 510
			classInfoBrowse = { 1290, 150, 534, 460 }, -- 구경 모드(목업 pc_07 · 01 v3 460)
			classBackBrowse = { 96, 96, 124, 52 },
			classStart = { 1290, 918, 534, 72 }, -- 01 v3 918
			browseBand = { 0, 0, 1920, 67 },
		},
		phone = {
			robloxButtons = { 0, 0, 140, 52 },
			keyArt = { 262, 0, 540, 360 }, -- 01 spec 그대로(오른쪽 2px 넘침 = 이음매 없게)
			keyArtFade = 0.22,
			title = { 24, 56, 300, 34 }, -- 로블록스 버튼 자리(0 ~ 52) 아래
			titleSub = { 24, 91, 260, 14 },
			titleExpanded = { 24, 56, 300, 34 },
			titleSubExpanded = { 24, 91, 260, 14 },
			menu = {
				x = 24, width = 250, widthExpanded = 250,
				main = { y = 119, h = 60, yExpanded = 119, hExpanded = 60 }, -- 01 v3 119
				items = { h = 44, hExpanded = 44, gap = 8, gapExpanded = 8, pairLast = true }, -- 설정 · 소식 = 한 줄 두 칸(121 + 8 + 121)
			},
			lore = { 0, 0, 800, 360 }, -- 폰 = 전체 덮개(탭하면 바로 메뉴)
			slotWindow = { 12, 60, 470, 290 },
			slotWindowSlide = 0, -- 폰 = 메뉴 숨김 → 같은 자리
			slotList = { x = 10, y = 61, w = 450, selectedH = 100, cardH = 84, emptyH = 52, lockedH = 44, gap = 6 },
			slotClose = { 6, 4, 44, 44 }, -- 폰 = 왼쪽 위 [<] 메뉴로(01 v3 18, 64 - 창 12, 60) · 판 B 9-slice(테두리 그림 안) = 머리 48 안
			slotCloseRing = false, -- 폰 [<] = 판 B 그림(테두리는 그림 안 · 그림 없을 때 대체 원도 테두리 없음 - 원 밖 3이 머리 48을 넘음)
			slotMore = { 398, 28, 44, 44 },
			slotFace = { 10, 12, 56, 56 },
			slotWeapon = { 330, 12, 56, 56 },
			slotArchive = { 391, 4, 75, 44 }, -- 01 v3 403 − 12 · 폭 75
			slotFooterNote = { 0, 0, 0, 0 }, -- 폰 = 없음
			confirm = { 220, 70, 360, 220 },
			confirmCancel = { 20, 154, 155, 48 },
			confirmOk = { 185, 154, 155, 48 },
			classBack = { 18, 64, 44, 44 }, -- UI1F-1: 왼쪽 위 = 이어하기 창 머리 [<]와 같은 화면 자리(01 v3 18, 64) · 로블록스 버튼(0 ~ 52) 아래
			classList = { x = 12, y = 116, w = 150, h = 52, gap = 6 }, -- [<] 아래(64 + 44 + 8) · 4직업 = 340까지
			classArt = { 172, 52, 247, 300 },
			classArtSilhouette = { 200, 70, 190, 240 },
			classInfo = { 430, 12, 358, 260 },
			classInfoBrowse = { 430, 62, 358, 212 }, -- 구경 모드(목업 phone_07 - 띠 아래)
			classBackBrowse = { 18, 64, 44, 44 }, -- 구경 모드도 같은 자리(띠 = 150부터)
			classStart = { 430, 284, 358, 56 },
			browseBand = { 150, 0, 650, 54 },
		},
	},
	-- 02 HUD v5(02_hud/v5 spec "화면별 좌표") - 기본 배치. 메뉴 열 = 첫 칸 + 칸 크기 + 간격(칸 수 = HudData)
	hud = {
		pc = {
			robloxButtons = { 0, 0, 132, 60 },
			left = { x = 24, y = 96, size = 72, gap = 44 }, -- 72 + 간격 44(목업 96 → 212: 116 - 이름표 자리 포함)
			right = { x = 1824, y = 248, size = 72, gap = 44 }, -- 재화 · 스테이지 · 메인 퀘스트 칸 아래(248)
			leftBoss = { x = 24, y = 96, size = 56, gap = 10 },
			moreWindow = { 112, 492, 434, 164 }, -- 더보기 펼침(더보기 버튼 오른쪽)
			moreItem = { x = 21, y = 55, size = 64, gap = 18 }, -- 창 안(133 − 112 · 547 − 492)
			rewardWindow = { 1458, 438, 350, 200 }, -- 보상 펼침(보상 버튼 왼쪽 - 오른쪽 열 버튼 1824 − 16)
			currency = { 1685, 20, 211, 48 },
			stage = { 1665, 76, 231, 40 },
			quest = { 1516, 122, 380, 79 },
			minimap = { 1316, 20, 180, 180 }, -- 켰을 때만
			party = { x = 24, y = 704, w = 270, h = 56, gap = 8 },
			partyBoss = { x = 24, y = 472, w = 270, h = 56, gap = 8 },
			hp = { 680, 920, 560, 24 },
			bossHp = { 510, 790, 900, 65 },
		},
		phone = {
			robloxButtons = { 0, 0, 140, 52 },
			top = { x = 150, y = 4, size = 44, gap = 8 },
			moreWindow = { 150, 54, 312, 273 },
			moreFrequent = { 14, 36, 284, 79 }, -- 창 안 "자주 쓰는 것" 칸(164 − 150 · 90 − 54)
			moreItem = { x = 30, size = 44, gap = 28, rowsY = { 42, 121, 194 } }, -- 창 안(180 − 150 · 96/175/248 − 54) · 칸 간격 72 − 44 · 첫 줄 = 자주 쓰는 것
			rewardWindow = { 150, 54, 260, 172 },
			currency = { 657, 8, 133, 32 },
			stage = { 673, 44, 117, 28 },
			quest = { 528, 70, 262, 50 },
			party = { x = 10, y = 87, w = 176, h = 28, gap = 5 },
			hp = { 310, 10, 220, 16 },
			hpBoss = { 310, 36, 220, 16 },
			bossHp = { 250, 304, 250, 41 },
			joystick = { 70, 214, 124, 124 }, -- 비움(로블록스 조이스틱)
			-- 전투 버튼(v2 좌표 그대로 · 사각 간격 8 이상 · 화면 끝 8 이상 - 하네스)
			combat = {
				attack = { 688, 250, 96, 96 },
				q = { 616, 294, 56, 56 },
				e = { 608, 222, 56, 56 },
				r = { 672, 186, 56, 56 },
				t = { 736, 186, 56, 56 },
				jump = { 536, 286, 64, 64 },
				dash = { 544, 206, 52, 52 }, -- UI-1 0단계: 02 v6 가운데 (570, 232) · 아래 충전 점 8
				lockon = { 616, 164, 44, 44 }, -- UI-1 0단계: 02 v6 가운데 (638, 186)(옛 182)
			},
			lockedBubble = { w = 148, h = 34, seconds = 1.5 },
		},
		-- UI-1 0단계 · 02_hud/v6 spec §3 · §4 배치표(기준 px { X, Y, W, H } + anchor = 붙는 쪽 - shared/HudPlace). 글자만큼 폭인 칩 = 폭 상한(하네스 겹침 판정용).
		--   modes = 그 요소가 보이는 때(normal = 평상시 · boss = 보스전) · touch = 누르는 것(폰 44 이상 검사) · text = 글자 1.3이면 늘어나는 높이(이름표 · 줄 수 기준 px)
		--   reserve = 비움 구역(다른 요소가 들어가면 안 됨 - 상단 바 · 로블록스 버튼 · 엄지 영역)
		v6 = {
			pc = {
				topBar = { 0, 0, 1920, 58, anchor = "WT", reserve = true },
				robloxButtons = { 0, 0, 132, 60, anchor = "TL", reserve = true },
				leftMenu = { 24, 96, 72, 541, anchor = "TL", modes = { normal = true }, touch = true, text = 125 },
				leftMenuBoss = { 24, 96, 56, 320, anchor = "TL", modes = { boss = true }, touch = true },
				zoneChip = { 1636, 66, 260, 32, anchor = "TR", modes = { normal = true, boss = true } },
				currencyChip = { 1516, 106, 380, 40, anchor = "TR", modes = { normal = true, boss = true } },
				stageChip = { 1556, 154, 340, 32, anchor = "TR", modes = { normal = true, boss = true } },
				minimap = { 1316, 66, 180, 180, anchor = "TR", modes = { normal = true } },
				nextGoal = { 1516, 198, 380, 72, anchor = "TR", modes = { normal = true }, touch = true, text = 22 },
				serverGoal = { 1516, 278, 380, 44, anchor = "TR", modes = { normal = true } },
				rightColumn = { 1824, 336, 72, 541, anchor = "TR", modes = { normal = true }, touch = true, text = 125 },
				notices = { 760, 66, 400, 166, anchor = "TC", modes = { normal = true } },
				bossBar = { 560, 66, 800, 92, anchor = "TC", modes = { boss = true }, text = 16 },
				bossNotices = { 760, 166, 400, 50, anchor = "TC", modes = { boss = true } },
				party = { 24, 672, 300, 244, anchor = "TL", modes = { normal = true } },
				partyBoss = { 24, 440, 300, 244, anchor = "TL", modes = { boss = true } },
				statusRow = { 680, 858, 296, 36, anchor = "BC", modes = { normal = true, boss = true }, touch = true },
				hp = { 680, 902, 560, 24, anchor = "BC", modes = { normal = true, boss = true } },
				skillRow = { 610, 950, 700, 90, anchor = "BC", modes = { normal = true, boss = true }, touch = true },
				exp = { 0, 1066, 1920, 14, anchor = "W" },
			},
			phone = {
				topBar = { 0, 0, 800, 58, anchor = "WT", reserve = true },
				joystick = { 0, 190, 260, 170, anchor = "BL", reserve = true },
				menuRow = { 8, 62, 148, 44, anchor = "TL", modes = { normal = true, boss = true }, touch = true },
				infoChips = { 552, 62, 240, 28, anchor = "TR", modes = { normal = true } },
				infoChipsBoss = { 632, 62, 160, 28, anchor = "TR", modes = { boss = true } }, -- 보스전 = 골드 · Lv만
				nextGoal = { 530, 96, 262, 44, anchor = "TR", modes = { normal = true }, touch = true },
				party = { 8, 112, 220, 80, anchor = "TL", modes = { normal = true, boss = true } },
				bossBar = { 244, 62, 326, 60, anchor = "TC", modes = { boss = true }, text = 10 },
				bossNotices = { 270, 128, 260, 30, anchor = "TC", modes = { boss = true } },
				notices = { 270, 62, 260, 68, anchor = "TC", modes = { normal = true } },
				statusRow = { 272, 286, 194, 30, anchor = "BC", modes = { normal = true, boss = true } },
				hp = { 272, 322, 256, 14, anchor = "BC", modes = { normal = true, boss = true } },
				exp = { 0, 354, 800, 6, anchor = "W" },
				-- 2단계 폰 메뉴 줄 펼침 창(메뉴 줄이 (8, 62)로 내려가 그 아래 · 화면 안)
				menuTop = { x = 8, y = 62, size = 44, gap = 8 },
				moreWindow = { 8, 110, 312, 246 },
				rewardWindow = { 8, 110, 260, 172 },
			},
			-- 폰 전투 버튼(기준 px · 오른쪽 아래 붙음 - hud.phone.combat 값을 읽어 짓는다 · 02 v6 §4 가운데 좌표 − 반지름)
			phoneCombatAnchor = "BR",
			-- B-7 오른쪽 열 접기(02 v6 §9): 시작 y · 칸 · 간격 · 이름표 · 아래 여백(24 + 경험치 줄 14)
			rightFold = { y = 336, size = 72, gap = 14, label = 25, bottomPad = 38, innerGap = 14 },
			leftColumn = { x = 24, y = 96, size = 72, gap = 14, label = 25 },
			hudHiddenCurrency = { sparkleShard = true },
			phoneChipScale = 0.7, -- 2단계: 폰 정보 칩 높이 28(02 v6 §4) ÷ 지금 칩 높이 40 · 보스전 = 골드 · Lv만(스테이지 칩 숨김) -- 2단계(02 v6 MISSING 13 · CC-UI-1 §2): 꾸미기 토큰 = HUD 칩에서 숨김(상점 · 도감에서만)
			-- 2단계 스킬 줄(02 v6 §7 · F v2 §1 B v2): PC 칸 72 · 간격 18 · 대시 원형 · 폰 = hud.phone.combat 크기
			skill = { pc = 72, gap = 18, dashGap = 26, keyRatio = 0.3, keyPhone = { 17, 14 }, secondsRatio = 0.56, secondsLeft = 0.12, secondsTop = 0.20, twoDigitScale = 0.8, stunInset = 8, stunRatio = 0.34, keyBg = "0E1120", keyBgTransparency = 0.15, secondsStroke = 5 },
			-- 2단계 보스 바(02 v6 §5): 이름 줄 · 막대 · 아래 줄 높이(기준 px) · 표시선 · 폼 꼬리표 = 폭풍 군주만(F v2 0절 4)
			bossBar = { pc = { name = 32, bar = 22, below = 24, status = 32 }, phone = { name = 22, bar = 12, below = 14, status = 22 }, ticks = { 0.5, 0.2 }, formBosses = { storm_lord = true }, formAt = 0.5,
				fill = "F2453D", track = "3A1416", guardFill = "8A8F9E" },
		},
	},
	-- 03 가방 · 장비창 v2(03_bag-equip/v2 spec "화면 규칙") - 기존 장비창(panels/Inventory)의 겉모습 값. 장비창은 배율 1(화면 px - Inventory/Layout.compute)이라 좌표 대신 크기만 둔다.
	--   lookV2 = false → 옛 겉모습(금색 머리 띠 · 색 탭 · 색 칸)으로 되돌림(기능은 같음).
	bag = {
		lookV2 = true,
		pc = { headH = 64, line = 4, tabW = 107, tabH = 44, tabGap = 7, rowH = 44, close = 44, cardSlice = true },
		phone = { headH = 48, line = 4, tabSize = 44, tabGap = 8, close = 44, cardSlice = true },
		-- 폰 그림 탭(44) 아이콘: ui = UiIconData 아이콘 ID · part = 게임 장비 아이콘(ItemIcons 부위) · gem = 보석 몸통(GemData.iconBodyByGrade 등급)
		-- 등급 골라 분해(2-2): PC = 가운데 창 640 × 480 · 폰 = 아래 시트(창 폭 · 232). 칩 = ArmorData.gradeOrder 앞 chipGrades개(고를 수 있음 = bulkSellGrades · 나머지 막힘)
		salvage = {
			chipGrades = 6,
			pc = { w = 640, h = 480, pad = 31, titleY = 22, titleH = 40, subH = 48, chipY = 112, chipH = 48, chipGap = 8, chipCols = 3, summaryH = 60, autoH = 32, buttonH = 56, buttonGap = 12 },
			phone = { w = 784, h = 232, pad = 17, titleY = 6, titleH = 30, subH = 0, chipY = 44, chipH = 44, chipGap = 8, chipCols = 6, summaryH = 52, autoH = 0, buttonH = 48, buttonGap = 10 },
		},
		tabIcons = { gear = { part = "weapon" }, all = { ui = "bag" }, armor = { part = "armor" }, gloves = { part = "gloves" }, shoes = { part = "shoes" }, gem = { gem = "legendary" }, codex = { ui = "book" } },
		-- UI-1 4단계(03 v3 §4 · §5 · §6): 칸 v3 · 무기 그림(ui/weapon/weapon-<직업>-g<등급 번호> · 칸의 82%) · 정렬 4 · 필터 · 선택 체크 그림
		v3 = {
			cell = { band = { pc = 20, phone = 18 }, bandText = { pc = 14, phone = 13 }, bandBg = "0E1120", bandBgTransparency = 0.18, lock = { pc = 24, phone = 20 }, lockRim = "FFE7A3",
				levelText = { pc = 14, phone = 13 }, newPill = 18, armorIcon = 0.60, weaponIcon = 0.82, smallFrom = 56 },
			weaponIcon = { prefix = "ui/weapon/weapon-", classStem = { greatsword = "gs", dualblade = "db", bow = "bow", healer = "staff" } },
			sortModes = { "grade", "part", "power", "newest" },
			check = { on = "ui/weapon/cell-check-on", off = "ui/weapon/cell-check-off", size = 26 },
			gemLockedText = "ui1.bag.gemSoon", -- 보석 홈 열기 방식 = 사용자 확인 대기 → 잠긴 홈 = 자물쇠 + "곧 열려요"(지시 "준비 중" = 글자 검사 ALL8 A3 금지 문구라 같은 뜻으로 · 새 힘 · 비용 없음)
		},
	},
	-- UI-1 6단계 E 강화 불씨(05_enhance-inherit/v4 spec §3 ~ 6): 강화대 창(빠른 창) + 불씨 칸 · 큰 창 = 옛 강화 패널([i]로 열기)
	enhance = {
		v4 = {
			pc = { cx = 960, bottom = 846, w = 640, pad = 12, head = 44, levelRow = 40, chips = 36, ember = 104, foot = 56, short = 20, gap = 8, button = { 190, 56 }, info = 44, close = 44 },
			phone = { x = 266, bottom = 352, w = 388, pad = 8, head = 40, chips = 28, ember = 70, foot = 30, short = 16, gap = 6, close = 40, round = { 688, 250, 96, 96 } },
			ember = {
				pc = { cellH = 22, gap = 3, gapMany = 2, manyFrom = 18, corner = 4, medal = 44, big = 32, small = 15, foot = 13 },
				phone = { cellH = 16, gap = 3, gapMany = 2, manyFrom = 18, corner = 3, medal = 32, big = 22, small = 12, foot = 11 },
				fill = { "FFF1C2", "FFD45A", "FFB13D" }, stroke = "3A4466", strokeFull = "FFD45A", strokeLast = "FFB13D", base = "141826", amber = "FFB13D",
				stripeTile = 32, breathe = 1.2, lastBreathe = 0.8, shimmerEvery = 1.6,
			},
			window = { bg = "161A2B", bgT = 0.06, stroke = "3A4466", strokeFull = "FFD45A", success = "5BD18A", down = "FF6B6B", close = "E5484D" }, -- close = 닫기 버튼(빨강 = 닫기 규칙 · UI-1b 0절 코드에서 옮김)
			band = { seconds = 2 }, -- 결과 띠: 2초 뒤 접힘 · 누르면 바로
			images = {
				flame = "ui/ember/ember-flame", stripe = "ui/ember/ember-ghost-stripe", medalOn = "ui/ember/ember-medal-on", medalOff = "ui/ember/ember-medal-off",
				shieldOn = "ui/ember/ember-shield-on", shieldOff = "ui/ember/ember-shield-off", shimmer = "ui/ember/ember-shimmer", spark = "ui/ember/ember-spark",
				round = { normal = "ui/ember/btn-enhance-round-normal", pressed = "ui/ember/btn-enhance-round-pressed", disabled = "ui/ember/btn-enhance-round-disabled", full = "ui/ember/btn-enhance-round-full" },
			},
		},
	},
	-- UI-1 7단계 F 자동 창(08 v5-auto-boss §1 ~ 4 · v6-auto-boss-v2 pc_01 · pc_02 · ph_01 · ph_02): 출석 + 시즌판 = 창 1개 · 탭 2 · [오늘 모두 받기]
	auto = {
		v6 = {
			pc = { x = 360, w = 1200, week = { y = 260, h = 540 }, season = { y = 180, h = 720 }, head = 64, line = 4, pad = 20, tabY = 80, tabH = 44, tabW = 132,
				note = { y = 144, h = 24 }, weekCell = { y = 180, w = 152, h = 236, gap = 12, icon = 44 }, seasonTop = { y = 140, h = 30 },
				seasonCell = { y = 182, w = 132, h = 100, gapX = 12, gapY = 10, icon = 36 }, foot = { h = 64, bottom = 18 }, button = { 300, 60 }, badge = 28, close = 44, dot = 14 },
			phone = { x = 8, y = 62, w = 784, h = 290, head = 48, line = 3, pad = 10, tabH = 40, tabW = 64, weekCell = { y = 66, w = 100, h = 150, gap = 8, icon = 30 },
				seasonCell = { y = 58, w = 88, h = 40, gapX = 7, gapY = 4, icon = 20 }, foot = { h = 46, bottom = 8 }, button = { 200, 46 }, badge = 20, close = 40, dot = 12 },
			colors = { window = "161A2B", cell = "1E2438", cellClaimed = "12162A", stroke = "3A4466", today = "FFD45A", day7 = "D8B96E", tabOn = "FFC83D", tabOff = "232A42", dot = "EB3C3C", line = "FFC83D" },
			resetHourUtc = 0, kstOffset = 9, -- 서버 초기화 = UTC 자정(QuestService resetIn) → 한국 시간 오전 9시(문구는 이 값으로 계산)
			openDelay = 2, giftDelay = 1, -- 마을 2초 뒤 출석 · 닫히고 1초 뒤 선물함
			displayOrder = 160, -- HUD 메뉴(150) 위
			check = "ui/ds/icon-check", headIcon = "ui/ds/icon-reward",
			rewardIcons = { gold = "ui/ds/icon-gold", goldKills = "ui/ds/icon-gold", sparkleShard = "ui/ds/icon-token", enhanceStone = "ui/ds/icon-reward-enhance-stone",
				highEnhanceStone = "ui/ds/icon-reward-enhance-stone-high", egg = "ui/ds/icon-reward-egg", gemDust = "ui/ds/icon-reward-gem-dust", rerollTicket = "ui/ds/icon-reward-reroll",
				rebirthTicket = "ui/ds/icon-reward-rebirth-ticket", passExp = "ui/ds/icon-reward-pass-exp", title = "ui/ds/icon-reward-title", cosmeticItem = "ui/ds/icon-reward-cosmetic" },
			rewardOrder = { "gold", "sparkleShard", "enhanceStone", "highEnhanceStone", "egg", "gemDust", "rerollTicket", "rebirthTicket", "passExp", "title", "cosmeticItem" },
		},
	},
	-- UI-1 7b단계 G(08 v7-map-settings): 지도 버튼 · 핀 크기
	map = {
		v7 = { inset = 16, button = 52, buttonPhone = 44, gap = 8, meSize = 34, gateSize = 40, gateStroke = "FFD45A",
			-- 구역 선택 칸(§2): 상태 그림 · 보스 칸
			stateIcon = 20, cellPortrait = 22, starBadge = 16, bossCellBg = "3A3016", bossCellStroke = "D8B96E",
			stageIcons = { cleared = "ui/g/stage-clear", inProgress = "ui/g/stage-tried", open = "ui/g/stage-open", locked = "ui/g/stage-locked", reward = "ui/g/stage-first-reward" },
			bossPortraits = { section_guardian = "ui/boss/boss-portrait-guardian", crystal_queen = "ui/boss/boss-portrait-crystal", abyssal_lord = "ui/boss/boss-portrait-abyssal",
				scorpion_queen = "ui/boss/boss-portrait-scorpion", storm_lord = "ui/boss/boss-portrait-storm", frost_giant = "ui/boss/boss-portrait-mammoth" },
		},
	},
	-- UI-1 7b단계 보스 관문 창(08 v7 §3)
	bossGate = {
		v7 = {
			pc = { x = 460, y = 230, w = 1000, h = 520, pad = 24, gap = 12, portrait = 280, close = 44, powerH = 64, bandH = 110, button = { 240, 64 } },
			phone = { x = 8, y = 62, w = 784, h = 290, pad = 10, gap = 6, portrait = 120, close = 40, powerH = 40, bandH = 46, button = { 180, 44 } },
			colors = { window = "161A2B", stroke = "3A4466", box = "1E2438", band = "3A3016", bandStroke = "D8B96E", bandText = "FFE9B0", info = "8FD8FF" },
			displayOrder = 160,
		},
	},
	-- UI-1 7b단계 HUD 편집 모드(08 v7 §6): 옮길 요소 8 = 기준 자리(hud.v6 이름) · 실제 프레임(PlayerGui 아래 경로) · 격자 · 금지 자리(상단 바 · 로블록스 버튼)
	--   저장 = 설정 키 hudLayoutPc · hudLayoutPhone("id:x,y;…" 기준 px 왼쪽 위) · hudLayoutVersion(형식 번호) - 서버 SettingsService가 shared/HudEditRules로 같은 검사(화면 밖 · 금지 자리 · id 화이트리스트)
	hudEdit = {
		v7 = {
			version = 1,
			grid = { pc = 24, phone = 16 },
			forbidden = { "topBar", "robloxButtons" }, -- hud.v6[기기] 사각형 이름
			robloxButtons = { phone = { 0, 0, 140, 52 } }, -- 폰 표에 없는 로블록스 버튼 자리(01 spec 폰 140 × 52)
			elements = {
				{ id = "leftMenu", label = "ui1.hudEdit.el.leftMenu", rect = { pc = "leftMenu", phone = "menuRow" }, paths = { pc = { "HudMenuV2Gui/HudLeft" }, phone = { "HudMenuV2Gui/HudLeft" } } },
				{ id = "rightMenu", label = "ui1.hudEdit.el.rightMenu", rect = { pc = "rightColumn" }, paths = { pc = { "HudMenuV2Gui/HudRight" } } },
				{ id = "nextGoal", label = "ui1.hudEdit.el.nextGoal", rect = { pc = "nextGoal", phone = "nextGoal" }, paths = { pc = { "NextGoalGui/NextGoal" }, phone = { "NextGoalGui/NextGoal" } } },
				{ id = "minimap", label = "ui1.hudEdit.el.minimap", rect = { pc = "minimap" }, paths = { pc = { "MinimapGui/Minimap", "MinimapGui/MinimapFeedAnchor" } } },
				{ id = "party", label = "ui1.hudEdit.el.party", rect = { pc = "party", phone = "party" }, paths = { pc = { "PartyHudGui/PartyList" }, phone = { "PartyHudGui/PartyList" } } },
				{ id = "hpStatus", label = "ui1.hudEdit.el.hpStatus", rect = { pc = "hp", phone = "hp" }, extra = { pc = "statusRow", phone = "statusRow" },
					paths = { pc = { "PlayerHealthBarGui/HealthBar", "PlayerHealthBarGui/ComboPipsAnchor", "PlayerHealthBarGui/BuffHudAnchor", "StatusHudGui/StatusRowHolder" },
						phone = { "PlayerHealthBarGui/HealthBar", "PlayerHealthBarGui/ComboPipsAnchor", "PlayerHealthBarGui/BuffHudAnchor", "StatusHudGui/StatusRowHolder" } } },
				{ id = "bossBar", label = "ui1.hudEdit.el.bossBar", rect = { pc = "bossBar", phone = "bossBar" }, ghost = true, paths = { pc = { "BossBarGui/BossBar" }, phone = { "BossBarGui/BossBar" } } }, -- 편집 중엔 자리만 점선
				{ id = "skillRow", label = "ui1.hudEdit.el.skillRow", rect = { phone = { 536, 150, 256, 206, anchor = "BR" } }, paths = { phone = { "SkillSlotsGui/PhoneCombat" } } }, -- 폰만(전투 버튼 묶음 · 오른쪽 아래에 붙음)
			},
			colors = { dim = 0.35, box = "8FD8FF", drag = "FFD45A", overlap = "FFB13D", forbidden = "6B7088", bar = "161A2B" },
			bar = { pc = { y = 176, h = 64 }, phone = { y = 62, h = 44 } },
			displayOrder = 180, -- HUD(150 · 160) 위 · 확인 창 overlay(200) 아래
		},
	},
	-- UI-1 7b단계 설정 새 줄(06 v3): "새로" 알약 = 출시 판 숨김(스위치)
	settings = { v7 = { showNewPill = false } },
	-- UI-1 7c 상점 04 v2: 노랑 [구매](화면마다 1개) · 창 상한 1600 × 880(디자인 시스템 큰 창)
	shop = { v2 = { buy = { fill = "FFC83D", text = "2A1E00" }, maxW = 1600, maxH = 880 } },
	-- UI-1 7c 알 · 펫(08 v8-rest §1 · v1.1): 확률 막대 · 숫자 열 · 펫 줄 · 놓아주기 확인
	petUi = {
		v1 = {
			gradeColors = { common = "9299A1", uncommon = "2478D4", rare = "7545C6", epic = "D87828" }, commonText = "C3C7CB",
			pc = { nameW = 92, numW = 54, rowH = 30, barH = 18 }, phone = { nameW = 62, numW = 40, rowH = 28, barH = 16 },
			petRowH = 102,
			confirm = { bg = "161A2B", stroke = "3A4466", warn = "FF8A8A" },
		},
	},
	-- UI-1 7c 캐릭터 창(08 v8-rest §2): 왼쪽 판 = 아바타 뷰 + 칭호 카드(+ 직업 이름)
	character = { v1 = { avatarBottom = 120, titleCardH = 70 } },
	-- UI-1 7c 파티 창 빠른 말 줄(F v2.1 · H §5): 말 8 + 이모트 4 = 한 격자
	quickChat = { v1 = { height = 112, cellW = 106, cellH = 44 } },
	-- UI-1b A 설명 창(I v1 0-2 · 0-4 · pc_10): 재화 칩 설명 · [?] 도움말 · 보상 칸 설명 = 같은 틀(client/ui/v2/InfoTip) · 크기 = 기준 px(HUD 배율 m 곱)
	infoTip = {
		pc = { w = 520, pad = 18, head = 44, rowPad = 10 },
		phone = { w = 330, pad = 12, head = 34, rowPad = 7 },
		bg = "161A2B", bgT = 0.04, stroke = "8FD8FF", strokeW = 3, ringW = 3, line = "2A3352", corner = 14, gap = 10, displayOrder = 175,
	},
	-- UI-1b 1절 16(I v1 spec 0-4 · pc_10 · ph_06): HUD 오른쪽 위 칩 = 왼쪽 메뉴 버튼과 같은 크기 단계 · 아이콘 크게 + 이름 · 누르면 설명(InfoTip)
	--   기준 px(HUD 배율 m 곱 · 폰 칩 배율 없음) · 줄 1 = 재화 · 줄 2 = 구역 · 스테이지 · 최고 + Lv · 전투력(폰 = 줄 2 = Lv · 전투력만 - 스테이지는 지도 · 구역 선택)
	infoChips = {
		pc = { h = 52, icon = 36, name = 15, num = 20, padX = 12, gap = 10, rowGap = 8, right = 24, top = 68, stage = true },
		-- 폰 이름 글자 = 보임(사용자 10-10) · 줄 1 폭 > maxW면 그때만 이름 숨김(아이콘 + 숫자 + 누르면 설명)
		phone = { maxW = 300, h = 40, icon = 26, name = 12, num = 14, padX = 8, gap = 6, rowGap = 6, right = 8, top = 62, stage = false },
		row1 = { pc = { "gold", "sparkleShard", "enhanceStone" }, phone = { "gold", "sparkleShard" } }, -- 줄 1 재화(좌표 표 밖 - 글자 목록)
		bg = "0E1120", bgT = 0.25, stroke = "3A4466", strokeW = 2,
	},
	-- UI-1b 1절 2(I v1 spec 0-3 · pc_11 · ph_06): 보스 바 = 로블록스 상단 바 가운데 빈 칸 안(전투 중에만 · 상단 바 비움의 유일한 예외)
	--   화면 px(상단 바는 우리 배율과 무관) · 폭 = min(w, 빈 칸 폭 − 2 × margin) · minW보다 좁으면 상단 바 바로 아래(below) · 상태 아이콘 줄 = 바 바로 아래 · 위쪽 알림 = 그 아래
	topbarBoss = {
		pc = { w = 760, h = 44, portrait = 32, name = 20, bar = 16, pct = 20, nameW = 210, formW = 64, pctW = 64, pad = 8, status = 30 },
		phone = { w = 430, h = 34, portrait = 24, name = 14, bar = 10, pct = 14, nameW = 104, formW = 46, pctW = 44, pad = 6, status = 24 },
		minW = 360, margin = 12, below = 4, statusGap = 4, noticeGap = 8,
		bg = "0E1120", bgT = 0.18, stroke = "3A4466", strokeW = 2, corner = 12,
	},
	-- UI-1b 0절(VERIFY-5 상3) 실제 화면 겹침 검사: 표 사각형이 아니라 실제 GUI 인스턴스의 AbsolutePosition · AbsoluteSize로 잰다(hud/HudRealCheck · shared/HudRealRules).
	--   path = PlayerGui 기준 · each = 보이는 직속 자식마다 한 칸(메뉴 버튼 · 칩) · allow = 겹쳐도 되는 짝(설계상 겹침 - 이유 적기)
	realCheck = {
		units = {
			{ id = "leftMenu", path = "HudMenuV2Gui/HudLeft", each = true },
			{ id = "rightMenu", path = "HudMenuV2Gui/HudRight", each = true },
			{ id = "chips", path = "TopChipsGui/TopChipsRow", each = true },
			{ id = "minimap", path = "MinimapGui/Minimap" },
			{ id = "nextGoal", path = "NextGoalGui/NextGoal" },
			{ id = "exp", path = "ExpBarGui/ExpTrack" },
			{ id = "health", path = "PlayerHealthBarGui/HealthBar" },
			{ id = "status", path = "StatusHudGui/StatusRowHolder" },
			{ id = "skills", path = "SkillSlotsGui/CentralRow" },
			{ id = "phoneCombat", path = "SkillSlotsGui/PhoneCombat", each = true },
			{ id = "bossBar", path = "BossBarGui/BossBarBottom", topbarOk = true }, -- 상단 바 안 = 설계(I v1 0-3)
			{ id = "party", path = "PartyHudGui/PartyList" },
			{ id = "region", path = "WorldHud/RegionLabel" },
		},
		allow = {},
		sizes = { { 1920, 1080 }, { 1366, 768 }, { 800, 360, phone = true } }, -- 보고용 기준(Studio 창으로 만들 수 있는 크기는 실측 크기를 함께 적는다)
	},
}
