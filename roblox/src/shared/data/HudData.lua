-- QUEUE-UI2 UI2-4 HUD v5 메뉴 표 한 곳(02_hud/v5 spec "메뉴 v5 규칙"). 좌표 = UiLayoutData.hud · 아이콘 = UiIconData · 키 = PanelRegistry(창 단축키 · 행동 키 - 여기서 키를 정하지 않는다).
--   항목 = 게임 실제 창(panel = PanelRegistry id) 또는 동작(action). 스위치 menuV5 = false → 옛 왼쪽 메뉴(hud/MenuBar) 그대로.
--   환생 = 창이 아니라 마을 제단(RebirthAltarPrompt) → 메뉴에 없음(환생 가능 = 알림 ④ · 안내 = 강화 창 [환생] 탭) - 하네스 hud_v5가 진입 경로를 센다.
return {
	menuV5 = true,
	items = {
		inventory = { icon = "bag", panel = "inventory", label = "ui.panel.menu.inventory" },
		character = { icon = "growth", panel = "character", label = "ui.panel.menu.character" },
		training = { icon = "training", panel = "training", label = "ui.panel.menu.training" },
		worldMap = { icon = "map", panel = "worldMap", label = "ui.panel.menu.worldMap" },
		more = { icon = "more", action = "more", label = "hud.menu.more" },
		stageSelect = { icon = "zone", panel = "stageSelect", label = "ui.panel.menu.stageSelect" },
		quests = { icon = "quest", panel = "quests", label = "ui.panel.menu.quests" },
		reward = { icon = "reward", action = "reward", label = "hud.menu.reward" },
		shop = { icon = "shop", action = "shop", label = "hud.menu.shop" },
		hubReturn = { icon = "home", action = "hubReturn", round = true, label = "scene.world.recall" }, -- 동작 = 둥근 판(btn-combat)
		party = { icon = "party", phoneIcon = "party2", panel = "party", label = "ui.panel.menu.party" },
		codex = { icon = "book", panel = "codex", label = "ui.panel.menu.codex" },
		leaderboard = { icon = "rank", panel = "leaderboard", label = "ui.panel.menu.leaderboard" },
		pet = { icon = "pet", action = "pet", label = "hud.menu.pet" }, -- 알 · 펫 창(panels/EggInfo)
		settings = { icon = "gear", panel = "settings", label = "ui.panel.menu.settings" },
	},
	pc = {
		left = { "inventory", "character", "training", "worldMap", "more" }, -- "내 캐릭터 관리"
		right = { "stageSelect", "quests", "reward", "shop" }, -- "진행 · 보상" + 맨 아래 귀환
		returnItem = "hubReturn",
		more = { "party", "codex", "leaderboard", "pet", "settings" },
	},
	phone = {
		top = { "inventory", "reward", "more" },
		moreFrequent = { "stageSelect", "training", "character", "quests" }, -- "자주 쓰는 것"
		moreRest = { "worldMap", "shop", "party", "codex", "leaderboard", "pet", "settings", "hubReturn" },
		moreCols = 4,
	},
	-- 보상 작은 창(더보기 펼침과 같은 모양): 줄마다 받을 것이 있으면 점 · 버튼 점 = 셋 중 하나라도(숫자 없음)
	rewards = {
		{ id = "attendance", icon = "star", label = "hud.reward.attendance" }, -- panels/Attendance
		{ id = "seasonBoard", icon = "book", label = "hud.reward.seasonBoard" }, -- panels/SeasonBoard(시즌 출석판)
		{ id = "gift", icon = "reward", label = "hud.reward.gift" }, -- 선물함(서버 GiftPopup 다시 보내기)
	},
	boss = { menuTransparency = 0.5, hideRight = true, hideLabels = true }, -- 보스전(BossEncounterId)
	alertDot = { pc = 16, phone = 14 },
	keyChip = { pc = 20, textSize = 13 }, -- 폰 = 키 칩 없음
}
