-- A2-N2 2-5 UI 등급 프레임 8종(ArtStyleV1 스위치 뒤 · 코드 테두리 · 그라데이션 - client/GradeFrame). 아이콘 이미지는 가져오기 뒤(지금은 프레임만).
--   사다리: 등급이 오를수록 테두리 두께 · 그라데이션 · 움직임이 한 겹씩 쌓인다(무기 사다리와 같은 누적 언어). 색 = ItemVisualData 등급 색(여기 없음 · 초월만 흑금 전용).
--   thickness = UIStroke 두께 · sheen = 테두리 위 밝은 띠(UIGradient 두 색 - 등급 색 → 흰 쪽 섞기 비율) · spin = 띠가 도는 속도(도/초 · 0 = 멈춤) · fill = 칸 배경을 등급 색 쪽으로 섞는 비율 · glow = 바깥 빛(0 ~ 1)
local C = Color3.fromRGB
local TRANSCENDENT = require(script.Parent.ItemVisualData).gradeVisuals.transcendent -- QUEUE-ALL9C 2-2 초월 흑금 = 등급 색 한 곳

return {
	grades = {
		normal = { thickness = 1, sheen = 0, spin = 0, fill = 0.03, glow = 0, strokeTransparency = 0.4 }, -- 검토: 일반 흰 테두리가 희귀보다 또렷해 서열이 거꾸로 보였다
		rare = { thickness = 2, sheen = 0.35, spin = 0, fill = 0.06, glow = 0 },
		epic = { thickness = 2, sheen = 0.45, spin = 0, fill = 0.08, glow = 0.15 },
		legendary = { thickness = 2.5, sheen = 0.55, spin = 40, fill = 0.1, glow = 0.25 },
		relic = { thickness = 2.5, sheen = 0.6, spin = 60, fill = 0.12, glow = 0.3 },
		ancient = { thickness = 3, sheen = 0.6, spin = 80, fill = 0.14, glow = 0.38 },
		primordial = { thickness = 3, rainbow = true, spin = 90, fill = 0.1, glow = 0.45 }, -- 무지개 흐름(기존 태초 규칙)
		transcendent = { thickness = 3.5, blackGold = true, spin = 70, glow = 0.5 }, -- 흑금: 검은 칸 + 금 테두리 위를 도는 흰금 빛 + 금 숨쉬기
	},
	blackGold = {
		cell = TRANSCENDENT.color, gold = TRANSCENDENT.border, shine = C(255, 236, 170), dark = C(150, 116, 36), -- QUEUE-ALL9C 2-2: 칸 = 초월 메인 #202127 · 금 = #D8B96E(ItemVisualData 한 곳) -- 검토: 어두운 금(92, 72, 24)이 올리브로 탁했다 → 금 쪽으로
		breatheHz = 0.6, -- 금빛 숨쉬기(바깥 빛 투명도가 오르내린다)
	},
	glowPad = 8, -- 바깥 빛 여백(px)
	-- A2-N4 §3-3 결정(A2-N3 8-1 메이플식): 보스바 = 화면 맨 위 얇은 전체 폭(이름은 막대 안 왼쪽) · 기믹 안내 = 화면 중앙 아래(화면 높이 gimmickHudY 비율). ArtStyleV1 뒤(끔 = 옛 자리).
	bossHud = { barHeight = 20, barMargin = 12, barTop = 4, gimmickHudY = 0.62,
		-- QUEUE-ALL1 01 A-1(사용자 09-30: 보스 체력바 = 화면 하단 가운데 · 소울류 - 메이플식 맨 위 · 로블록스 버튼 옆 줄은 폐기): 아래부터 내 체력바 윗변(healthBarTopFromBottom = ScreenMap healthBar 94 + 19) ·
		--   gapAboveHealth · 보스 바(PC 14 · 폰 12) · nameGap · 이름/% 줄 nameHeight · gimmickGap · 기믹 한 줄 gimmickHeight(글씨가 바뀐 뒤 gimmickFadeSeconds면 흐려짐)
		--   폭 = 스킬 줄 폭(궁극기 버튼을 안 덮게 · 없으면 화면 widthFraction · widthMin ~ widthMax) · 폰 = 좌우 phoneSideReserve(조이스틱 · 버튼 자리)는 비움 · 색 = 진홍 채움 + 금 테두리 · 맞은 만큼 흰 잔상이 lagHoldSeconds 뒤 lagSeconds 동안 줄어듦
		healthBarTopFromBottom = 113, gapAboveHealth = 8, barHeightPc = 14, barHeightMobile = 12, nameGap = 2, nameHeight = 16, gimmickGap = 6, gimmickHeight = 44,
		gimmickFadeSeconds = 2, gimmickFadedTransparency = 0.45,
		widthFraction = 0.45, widthMin = 360, widthMax = 720, phoneSideReserve = 230,
		fill = C(196, 30, 46), fillTop = C(232, 64, 72), track = C(52, 12, 18), border = C(214, 176, 62), lag = C(255, 255, 255), lagTransparency = 0.25,
		lagHoldSeconds = 0.45, lagSeconds = 0.6,
		chat = { heightScale = 0.55, widthScale = 0.8, backgroundTransparency = 0.85 }, -- 보스전 동안 로블록스 채팅 창 = 작고 투명하게(끄지 않음)
	},
	-- A2-N4 §4-6 GUI 트렌드 1차(client/ArtV1GuiTrend - ArtStyleV1 뒤): 대상 = ScreenMap 인스턴스 이름 · 보스바 · 장비창 창. 굵은 잉크 외곽선 · 둥근 모서리 최소 · 위 → 아래 그라데이션(아래 색을 곱한다) · 글씨 외곽선 불투명 상한.
	guiTrend = {
		targets = { "MenuBar", "TopChipsRow", "PartyToggleButton", "LeaderboardToggleButton", "TravelHubButton", "TravelBackButton", "TravelPartyButton", "ClassReopenButton",
			"InventoryToggleButton", "HealthBar", "CentralRow", "ExpTrack", "BossBar", "InventoryGui/Window" }, -- "부모/이름" = 그 부모 아래의 그 이름만
		ink = C(30, 27, 46), strokeThickness = 2.5, cornerRadius = 12, gradientBottom = C(200, 205, 215), textStroke = 0.35,
	},
}
