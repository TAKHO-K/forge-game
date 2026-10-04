-- QUEUE-ALL9C 2-3 첫 화면 = 메인 메뉴 → (로딩) → 게임. 화면 = client/MainMenu.client.lua · 가림막 = first/MenuBoot.client.lua · 글 = TextData_menu.lua.
--   메뉴에 있는 동안 아래 단계를 미리 불러오고, [이어하기] 등을 누를 때 남은 단계가 있으면 로딩 막대(최대 loadCapSeconds 뒤 입장 - 나머지는 배경에서 계속).
--   steps 순서 = 막대 진행 순서(무게 = 막대에서 차지하는 몫). id별 할 일은 화면 코드의 STEP_RUNNERS 한 곳.
return {
	v2Menu = true, -- QUEUE-UI UI-1 메인 메뉴 v2(01_main-menu/v1 - client/ui/v2/MainMenuV2) · false = 옛 기본 모양(QUEUE-MENU2)
	skipMenuOption = false, -- QUEUE-MENU2 C: "다음부터 메뉴 건너뛰기" 옵션(끔 = UI 숨김 · 저장값 skipMenu 무시 - 직업 선택이 메뉴의 새 캐릭터라 메뉴를 늘 보인다)
	loadCapSeconds = 15,
	steps = {
		{ id = "profile", weight = 1 }, -- 저장 불러오기(ClassId Attribute가 생김 - 새 계정은 빈 글)
		{ id = "map", weight = 2 }, -- 서버가 마을 · 맵을 다 지음(Workspace WorldMapBuilt)
		{ id = "props", weight = 2 }, -- 마을 소품 메시(ArtMeshCache PropsReady)
		{ id = "character", weight = 1 }, -- 내 캐릭터(옷 · 액세서리 포함 미리 불러오기)
		{ id = "stream", weight = 2 }, -- 캐릭터 주변 맵 스트리밍(RequestStreamAroundAsync)
		{ id = "icons", weight = 2 }, -- UI 아이콘(아래 iconPrefixes)
		{ id = "sounds", weight = 1 }, -- 소리 시트(SoundSheetData.sheets)
	},
	iconPrefixes = { "icons/ui/", "icons/hud/", "icons/skills/", "icons/reward/" }, -- ArtAssetIds 키 앞부분(이미지 있는 것만)
	streamTimeoutSeconds = 6,
	tips = { "menu.tip.1", "menu.tip.2", "menu.tip.3", "menu.tip.4" }, -- 로딩 막대 위 한 줄(무작위)
	-- 배경 = 키 아트 한 장(first/MenuBootData.background - 교체 절차 docs/phase/all9c/menu-background.md). 아래 둘은 사용자 10-03 결정으로 끔(코드는 남김):
	-- (끔) 장소 사진 교차 전환: 사진 여러 장(키 = ArtAssetIds · Studio 캡처 → tools/blender/cartoon_menu_bg.py) · 미리 불러오기 1번 · holdSeconds마다 교차 전환.
	backgroundCrossfade = false,
	backgrounds = { "ui/menu_hub", "ui/menu_hunt", "ui/menu_gate" },
	backgroundHoldSeconds = 9,
	backgroundFadeSeconds = 2.5,
	backgroundFirstFadeSeconds = 1.2,
	backgroundFirstWaitSeconds = 1.5, -- 첫 사진을 이만큼 먼저 기다린 뒤 나머지 미리 불러오기 시작
	-- (끔) 등급 빛: 화면 좌우 가장자리에서 아래 → 위로 올라오는 빛줄기(UI 트윈만 · 프레임 미리 지어 재사용 · 움직이는 프레임 ≤ 20).
	--   순서 = ArmorData.gradeOrder(일반 → 초월) · 색 = GradeColor.border(드랍 빛기둥과 같은 색 - 초월 = 금) · cycleSeconds마다 한 바퀴.
	--   그래픽 가벼움(GraphicsMode lite) = 등급마다 한쪽만(빛 개수 절반) · 초월 끝 = 금빛 균열 반짝(sparks 줄 + 둥근 빛 1).
	lights = {
		enabled = false,
		cycleSeconds = 7,
		riseSeconds = 2.4,
		edge = 0.035, -- 가장자리 폭(화면 비율)
		width = { 8, 14 }, -- px(무작위)
		height = 0.36, -- 화면 높이 비율
		transparency = 0.55, -- 가장 밝을 때 투명도(은은하게)
		finaleWidthScale = 1.8,
		finaleTransparency = 0.3,
		sparks = 3, -- 초월 균열 줄 수(양쪽 합 - 움직이는 프레임 = 빛줄기 16 + 균열 3 + 둥근 빛 1 = 20 · lite = 8 + 2 + 1)
		sparkLength = 46,
		glowSize = 120,
	},
	-- 메뉴 버튼 · 줄 크기(PC 기준 - 폰은 Theme.buttonHeight)
	panelWidth = 320,
	menuZone = 0.35, -- 메뉴 버튼 묶음 · 로고 = 화면 왼쪽 35% 안(안전 영역 docs/art/ref/menu-safe-zone.png)
	menuMargin = 0.04, -- 왼쪽 여백(화면 비율 · 최소 16px)
	continueHeight = 64,
	logoTextSize = 44, -- 게임 이름 자리(GameInfoData.name)
	fadeSeconds = 0.35,
	barWidth = 480,
}
