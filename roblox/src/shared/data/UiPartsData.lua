-- UI-1 1단계 A 공용 부품 값 표(00_design-system/v8 spec §0 ~ §11 - 코드에 숫자를 박지 않는다). 그림 = ArtAssetIds 키(ui/ds/<파일 이름>).
return {
	-- §0-1 상태 아이콘 색(초록 안 씀) · §2 게이지 색
	statusColors = { cc = "D32F2F", debuff = "FFC400", buff = "2F9BFF" },
	statusOrder = { cc = 1, debuff = 2, buff = 3 },
	gaugeColors = { exp = "FFC83D", ember = "FFB238", serverGoal = "4FD6C8", contribution = "8FD8FF", bossHp = "F2453D" },

	-- §1 토글
	toggle = {
		track = { 56, 32 }, knob = 28, inset = 2, knobOffX = 2, knobOnX = 26, rowMinH = { pc = 56, phone = 44 },
		pressSeconds = 0.05, pressStretch = 1.18, moveSeconds = 0.12, shakeSeconds = 0.18, shakePx = 4,
		img = {
			on = "ui/ds/toggle-track-on", off = "ui/ds/toggle-track-off", onPressed = "ui/ds/toggle-track-on-pressed", offPressed = "ui/ds/toggle-track-off-pressed",
			onDisabled = "ui/ds/toggle-track-on-disabled", offDisabled = "ui/ds/toggle-track-off-disabled",
			knob = "ui/ds/toggle-knob", knobPressed = "ui/ds/toggle-knob-pressed", knobDisabled = "ui/ds/toggle-knob-disabled", focus = "ui/ds/toggle-focus",
		},
	},

	-- §2 게이지(9-slice) · 움직임
	gauge = {
		track = { img = "ui/ds/gauge-track", center = { 16, 16, 48, 16 }, src = 32, pad = 3 },
		fill = { img = "ui/ds/gauge-fill", center = { 12, 12, 52, 12 }, src = 24 },
		shine = "ui/ds/gauge-shine", tip = "ui/ds/gauge-tip",
		ghostTransparency = 0.45, riseGhostSeconds = 0.05, riseSeconds = 0.30, fallHoldSeconds = 0.4, fallSeconds = 0.2, shineSeconds = 0.4,
		fullFlashSeconds = 0.15, fullFlashGap = 0.2, fullFlashCount = 2,
	},

	-- §3 쿨타임 · 남은 시간 덮개
	cooldown = {
		maskR18 = "ui/ds/cd-mask-r18", maskCircle = "ui/ds/cd-mask-circle", flashR18 = "ui/ds/cd-ready-flash-r18", flashCircle = "ui/ds/cd-ready-flash-circle",
		color = "0E1120", skillTransparency = 0.28, statusTransparency = 0.34, chargeTransparency = 0.6,
		coolingIconColor = "B5B5B5", disabledIconColor = "6E6E6E", secondsRatio = 0.42, edgeMinSlot = 44,
		readyFlashSeconds = 0.08, readyFlashFade = 0.27, readyFlashScale = 1.25, readyIconPop = 1.08,
	},

	-- §4 상태 아이콘 줄
	status = {
		size = { row = { pc = 36, phone = 30 }, boss = { pc = 32, phone = 26 }, party = { pc = 22, phone = 18 }, tipHead = { pc = 40, phone = 30 } },
		cell = { row = { pc = 44, phone = 44 }, boss = { pc = 38, phone = 30 }, party = { pc = 26, phone = 22 } },
		max = { pc = 7, phone = 5 }, partyMax = 3,
		blinkUnderSeconds = 3, blinkPeriod = 0.5,
		popScale = 1.25, popSeconds = 0.15, shakePx = 3, shakeCount = 2, shakeSeconds = 0.2, ccFlashSeconds = 0.1,
		endSeconds = 0.12, endScale = 0.8,
		frameMore = "ui/ds/status-frame-more", glow = "ui/ds/status-glow", glowScale = 1.31, glowPeriod = 1.6,
		tipAutoCloseSeconds = { pc = nil, phone = 4 },
	},

	-- §5 설명 창
	tip = { panel = "ui/ds/tip-panel", center = { 20, 20, 76, 76 }, arrow = "ui/ds/tip-arrow", width = { pc = 470, phone = 268 }, band = 5, gap = 14, openSeconds = 0.12, centerAvoid = 0.35 },

	-- §6 알림 배너
	banner = {
		panel = "ui/ds/banner-panel", center = { 24, 28, 72, 44 },
		pc = { y = 72, w = 720, h = 72, icon = 52, bossY = 166 }, phone = { y = 62, w = 400, h = 48, icon = 34, bossY = 128, sliceScale = 0.7 },
		inSeconds = 0.25, stay = 4, outSeconds = 0.2, maxQueue = 3,
		icons = { rift = "ui/ds/banner-icon-rift", golden = "ui/ds/banner-icon-golden", serverGoal = "ui/ds/banner-icon-server-goal" },
	},

	-- §7 전투 문구(영어 큰 줄 + 한국어 작은 줄 · 키 = UiText)
	combatText = {
		y = { pc = 0.30, phone = 0.42 }, rays = "ui/ds/fx-pop-rays",
		kinds = {
			dodge = { en = "PERFECT DODGE!", textKey = "ui1.ct.dodge", bottom = "8FD8FF", top = "FFFFFF", size = { pc = 64, phone = 36 }, rays = false },
			["break"] = { en = "BREAK!", textKey = "ui1.ct.break", bottom = "FFC83D", top = "FFF2B0", size = { pc = 80, phone = 44 }, rays = true },
			rescued = { en = "RESCUED!", textKey = "ui1.ct.rescued", bottom = "5FE0D0", top = "E6FFFB", size = { pc = 64, phone = 36 }, rays = false },
			revive = { en = "MIRACLE REVIVE!", textKey = "ui1.ct.revive", bottom = "FFE7A3", top = "FFFFFF", size = { pc = 64, phone = 36 }, rays = true },
		},
		popFrom = 0.4, popPeak = 1.15, popInSeconds = 0.12, settleSeconds = 0.08, holdSeconds = 0.6, outSeconds = 0.3, outRise = 24, strokeRatio = 0.10,
	},

	-- §8 아이콘 받기 전 · §9 빈 상태
	loading = { shimmer = "ui/ds/icon-loading-shimmer", ring = "C9B48A", letter = "B5A27A", period = 1.2, timeout = 5, crossSeconds = 0.15 },
	empty = {
		ring = "ui/ds/empty-ring", size = { pc = 160, phone = 84 }, iconRatio = 0.56,
		kinds = {
			rank = { icon = "rank", titleKey = "ui1.empty.rank.title", lineKey = "ui1.empty.rank.line", buttonKey = "ui1.empty.rank.button" },
			bag = { icon = "bag", titleKey = "ui1.empty.bag.title", lineKey = "ui1.empty.bag.line", buttonKey = "ui1.empty.bag.button" },
			egg = { icon = "pet", titleKey = "ui1.empty.egg.title", lineKey = "ui1.empty.egg.line" },
		},
	},
}
