-- QUEUE-ALL1 P3 §3 균열 시간(docs/design/v2/04 §3): 모든 서버 동시(서버 시계 UTC) · 하루 2번 × 20분 · 맵 전체 분위기 전환 + 구역별 날씨 + 보상 배율.
--   시간표 = windowsUtc(시 · 분) - 한국 저녁 20시(= UTC 11시) + 미국 저녁대 1회(UTC 1시 = 미 중부 서머타임 20시). 판정 = shared/RiftRules(순수 - 서버 · 클라 같은 식).
--   효과: 골드 × goldMultiplier · 장비 등급 gradeMultiplier(전설 · 유물 · 고대 × 1.5 - 태초 · 초월 제외 · 늘어난 몫은 그보다 낮은 등급에서 비율대로 뺀다 = 합 1) ·
--   확률 공개 창 = 같은 표(DropTable.boosted - 균열 중이면 균열 표 + 배율 줄). 다른 부스트(복귀 = 드랍 개수 × 1.5)는 축이 달라 겹치지 않는다(등급 부스트는 균열 하나).
--   날씨 = 화면만(판정 · 리더보드 불변) · 입자는 카메라 주변 클라 전용 · 번개 번쩍임 초당 3회 미만(maxFlashPerSecond) · 설정 "번쩍임 줄이기"면 번쩍임 없음.
--   EconSim: participationShare(균열 시간에 노는 비중 - 예 30%)만큼 균열 배율을 섞어 캐주얼 목표를 확인한다(EconSim.lua expectedCandidates · gold).
local C = Color3.fromRGB

return {
	windowsUtc = { { hour = 11, minute = 0 }, { hour = 1, minute = 0 } },
	durationSeconds = 20 * 60,
	gradeMultiplier = { legendary = 1.5, relic = 1.5, ancient = 1.5 },
	goldMultiplier = 1.25,
	participationShare = 0.3,
	-- 분위기(이 화면 - 끝나면 되돌림): 하늘 시각 · 대기 · 색조
	mood = { clockTime = 18.1, atmosphereDensity = 0.42, atmosphereHaze = 2.2, atmosphereColor = C(150, 132, 170), tint = C(226, 214, 240), brightnessScale = 0.8 },
	-- 구역별 날씨(WorldMapData 구역 key) · 아레나 = 그 보스의 구역 날씨(BossData gate.zone)
	weatherByZone = { tier1 = "acidRain", tier2 = "crystalRain", tier3 = "seaFog", tier4 = "sandstorm", tier5 = "thunder", tier6 = "blizzard", hub = "drizzle" },
	weather = {
		acidRain = { shape = "streak", color = C(196, 240, 110), every = 0.02, fall = 60, wind = Vector3.new(4, 0, 2), size = 0.22, life = 0.9 },
		crystalRain = { shape = "block", color = C(200, 170, 255), every = 0.035, fall = 40, wind = Vector3.new(1, 0, 1), size = 0.3, life = 1.2, material = Enum.Material.Glass },
		seaFog = { shape = "ball", color = C(190, 220, 226), every = 0.12, fall = -1.5, wind = Vector3.new(3, 0, 0), size = 5, life = 5, transparency = 0.82, fogDensity = 0.55 },
		sandstorm = { shape = "streak", color = C(222, 196, 140), every = 0.018, fall = 3, wind = Vector3.new(38, 0, 12), size = 0.24, life = 1.1 },
		thunder = { shape = "streak", color = C(190, 205, 240), every = 0.02, fall = 70, wind = Vector3.new(6, 0, 0), size = 0.2, life = 0.8, flashEvery = 2.6 },
		blizzard = { shape = "block", color = C(248, 252, 255), every = 0.02, fall = 16, wind = Vector3.new(18, 0, 6), size = 0.3, life = 2.2, material = Enum.Material.SmoothPlastic },
		drizzle = { shape = "streak", color = C(200, 210, 230), every = 0.06, fall = 45, wind = Vector3.new(2, 0, 1), size = 0.16, life = 0.9 },
	},
	particleRadius = 50, phoneParticleScale = 0.4, arenaFogCap = 0.45, maxFlashPerSecond = 2.5,
	-- 배너(시작 · 끝) · 남은 시간 HUD
	bannerSeconds = 6,
	text = { start = "균열이 열렸다! 20분 동안 골드 · 전설 · 유물 · 고대 확률 증가", finish = "균열이 닫혔다", timer = "균열 %d:%02d" },
}
