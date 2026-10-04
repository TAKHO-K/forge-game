-- QUEUE-ALL9C 2-3 첫 화면 가림막 값. ReplicatedFirst는 Shared보다 먼저 떠서 shared/data를 못 읽는다 - 가림막이 쓰는 값만 여기 둔다.
--   장소 사진 · 등급 빛 · 메뉴 · 로딩 문구 · 상한 초 = shared/data/MainMenuData.lua · 글 = TextData_menu.lua(옛 S12 로딩 문구 4줄도 그쪽 menu.tip.*로 옮김).
return {
	displayOrder = 1000, -- 모든 HUD · 창(최대 300) 위
	legacyLoadingTip = false, -- 옛 S12 로딩 문구(LoadingTip.client.lua · 기본 로딩 화면 위 한 줄) - 메뉴로 대체되어 끔
	skyTop = Color3.fromRGB(86, 152, 222),
	skyBottom = Color3.fromRGB(176, 214, 236),
	ground = Color3.fromRGB(84, 146, 70),
	shade = Color3.fromRGB(10, 14, 22), -- 메뉴 쪽(왼쪽) 어둡게 - 글씨 대비 4.5:1 이상(밝은 하늘 위에서도 · 캡처 표본으로 확인)
	-- 어두운 그라데이션(투명도: 왼쪽 → 오른쪽으로 옅어짐) - { 화면 가로 비율, 투명도 } · 메뉴 묶음 · 로고 = 왼쪽 35% 안
	shadeKeys = { { 0, 0.18 }, { 0.3, 0.3 }, { 0.42, 0.62 }, { 0.6, 1 }, { 1, 1 } },
	focusY = 0.55, -- 키 아트 세로 기준점(0 = 위 · 1 = 아래) - 넓은 화면에서 하늘을 더 자르고 가운데 인물 · 무기 · 빛을 남긴다
	-- 배경 키 아트(한 장 - 사용자 제공 그림 · 교체 = docs/phase/all9c/menu-background.md). 접속 즉시 불러와 다 오면 서서히 표시 · 화면 꽉 채움(잘라내기) · 가운데 기준.
	--   parts = 좌우로 나눈 장(로블록스 이미지 한 변 1024 한도 - 큰 그림을 2장으로) · x0 ~ x1 = 원본 가로 픽셀 범위(가운데 몇 px 겹침 = 이음매 없음).
	--   빈 parts = 하늘 그라데이션만.
	fadeSeconds = 0.8,
	-- QUEUE-UI UI-1(01 spec "배경 · 가리지 않기"): v2 = 키 아트를 화면 높이에 맞춰 오른쪽에 붙임(PC X 300 · W 1620 / 폰 X 262 · W 540 = 높이 × 1.5) · 그림 왼쪽 22% 투명 → 불투명 ·
	--   그 위 #0E1120 덮개(투명도 0 → 0.05 · 0.20 → 0.14 · 0.38 → 0.55 · 0.50 → 1) · 맨 뒤 바탕 #1E3050 → #15203A · 땅 없음. false = 옛 화면 꽉 채움(잘라내기)
	layoutV2 = true,
	v2 = {
		skyTop = Color3.fromHex("1E3050"),
		skyBottom = Color3.fromHex("15203A"),
		shade = Color3.fromHex("0E1120"),
		shadeKeys = { { 0, 0.05 }, { 0.2, 0.14 }, { 0.38, 0.55 }, { 0.5, 1 }, { 1, 1 } },
		artAspect = 1.5, -- 이미지 영역 너비 = 높이 × 1.5(1620 / 1080 · 540 / 360)
		artFade = 0.22, -- 이미지 왼쪽 22% 서서히
	},
	-- BEGIN menu_bg.py(생성 - 손으로 고치지 않는다 · menu_keyart_v2.png)
	background = {
		width = 1536,
		height = 1024,
		parts = {
			{ image = "rbxassetid://90708952668878", x0 = 0, x1 = 770 },
			{ image = "rbxassetid://129274403210371", x0 = 766, x1 = 1536 },
		},
	},
	-- END menu_bg.py
}
