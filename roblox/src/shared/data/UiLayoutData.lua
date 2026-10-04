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
			moreFrequent = { 164, 36, 284, 79 }, -- 창 안 "자주 쓰는 것" 칸(164 − 150 · 90 − 54)
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
				dash = { 544, 198, 52, 52 },
				lockon = { 616, 160, 44, 44 },
			},
			lockedBubble = { w = 148, h = 34, seconds = 1.5 },
		},
	},
}
