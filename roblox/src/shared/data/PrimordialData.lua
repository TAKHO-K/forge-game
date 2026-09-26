-- D1 태초 낭만 · 상위 등급 표시 규칙 값(연출 모양 = docs/art/ref/15_effects.png ⑤ ⑦ · 장비창 칸 = 17_ui_equipment.png).
-- 서버(PrimordialRegistry · ItemDropSpawner · DropNotice · PlayerProfile.awakenItem)와 클라(PrimordialFx · DropFeed · 명예의 전당 · 오라)가 같이 읽는다.

return {
	-- ② 세계 번호: 전역 카운터 = DataStore UpdateAsync(원본 기록). 알림(MessagingService)은 best-effort 부가.
	storeName = "PrimordialWorld_v1",
	counterKey = "worldCounter",
	recentKey = "recent", -- 최근 태초 목록(명예의 전당 원본)
	testKeyPrefix = "test_", -- /gg drop force · 검증은 이 접두사 키만 쓴다(실제 세계 번호를 안 올린다)
	claimRetries = 3, -- UpdateAsync 실패 시 다시 시도 횟수(전부 실패 = 번호 없이 지급 · 경고)
	recentKeep = 20, -- 명예의 전당 표시 건수

	-- ③ 전 서버 알림
	topic = "PrimordialFound",
	bannerSeconds = 6, -- 상단 배너 표시(대기열 - 하나씩)
	bannerQueueMax = 6, -- 대기열 상한(넘으면 가장 오래된 것부터 버림 - 원본은 DataStore)
	fallbackName = "모험가", -- 이름 필터 실패 시

	-- ① 획득 순간
	flashSeconds = 0.45,
	slowSeconds = 0.6, -- 필드에서만(보스전 중 없음) - 화면 연출(시야 · 색) · 게임 시간은 멈추지 않는다
	pillarSeconds = 30, -- 드랍 지점 흰 빛기둥(같은 서버 전원)
	soundId = nil, -- 전용 효과음 자리(지금 게임에 효과음 에셋이 하나도 없다 - 사운드 단계에서 id를 넣으면 PrimordialFx가 재생한다)

	-- ④ 명예의 전당(허브 커뮤니티 광장 석판)
	hallRefreshSeconds = 300,

	-- ⑤ 보유 표시
	auraMaxDistance = 60, -- 흰 오라는 이 거리 안에서만(art-spec §5 "가까운 거리 약 60")
	auraColor = Color3.fromRGB(255, 255, 255),
	accentColor = Color3.fromRGB(255, 63, 210), -- 자홍 포인트(#FF3FD2)
	glyph = "★", -- 이름표 옆 태초 문양

	-- ⑥ 칭호
	titleId = "primordialChosen", -- 이름 · 등급 · 조건 = shared/data/TitleData

	-- D1-2 딜 부위 태초 고유 효과(능력치 상한 안 - 수치 = Loot.getGlovesCritDmgBonus · getShoesSpeedPercent · getShoesDashMultiplier, 연출 = client/PrimordialFx).
	--   장갑: 치명 피해 +glovesCritDmgBonus(합계 상한 CombatConfig.critDmgBonusCap) + 강공격(3타)마다 흰 번개(glovesBolt - 본인 · 곁의 사람 화면).
	--   신발: 공격 속도 · 이동 속도 = 상한(CombatConfig.attackSpeedMaxMultiplier · MovementConfig.moveSpeedMaxMultiplier) · 대시 거리 = DashConfig.rangeMaxMultiplier + 흰 발자국(footprint).
	unique = {
		glovesCritDmgBonus = 0.4,
		glovesBolt = { sendStuds = 120, heightStuds = 14, seconds = 0.35, width = 0.35, segmentStuds = 2, jitter = 1.2, branches = 2 },
		-- 발자국 색 = 흰색에 자홍을 조금 섞은 색(허브 흰 바닥에서 순백 발자국이 안 보였다 - D1-2 스크린샷)
		footprint = { color = Color3.fromRGB(255, 170, 235), everyStuds = 3.2, lifeSeconds = 1.6, size = Vector3.new(0.9, 0.05, 1.3), sideOffset = 0.55, maxAlive = 24 },
	},

	-- ⑧ 고대: 같은 서버 알림 + 본인 큰 연출(고대 색 빛기둥) - 전 서버 알림 없음
	ancientPillarSeconds = 12,
	ancientPillarWidth = 3.8,
	beaconWidth = 5.4, -- ① 30초 흰 빛기둥 굵기

	-- ⑨ 드랍 표시(사용자 결정 · 디아블로4식): 바닥 원(모든 등급) + 불규칙한 번개가 내리꽂히는 줄기(영웅부터 - 높이 = 등급 단계) · 장비 본체 = 어두운 실루엣.
	-- 파티클 없이 파트 + 투명도(번개는 클라 DropLightning이 지그재그를 계속 다시 긋는다). 부위 아이콘은 쓰지 않는다(사용자 결정).
	pillarHeights = { normal = 0, rare = 0, epic = 6, legendary = 13, relic = 18, ancient = 23, primordial = 30 },
	ringDiameter = 4,
	-- 낮은 등급일수록 등급 색을 회색 쪽으로 뺀다(0 = 등급 색 그대로 · 1 = 회색) · 광원 밝기(0 = 빛 없음). UI 등급 색(ItemVisualData)은 그대로 - 땅 드랍 표시만.
	dropLook = {
		normal = { desaturate = 1, light = 0 },
		rare = { desaturate = 0.55, light = 0.5 },
		epic = { desaturate = 0.3, light = 1.0 },
		legendary = { desaturate = 0.1, light = 1.8 },
		relic = { desaturate = 0, light = 2.6 },
		ancient = { desaturate = 0, light = 3.4 },
		primordial = { desaturate = 0, light = 4.5 },
	},
	dropGray = Color3.fromRGB(128, 128, 134),
	silhouetteColor = Color3.fromRGB(16, 16, 22), -- 장비 본체(빛 속의 검은 실루엣)
	bolt = { restrikeMin = 0.12, restrikeMax = 0.4, jitter = 1.1, segmentStuds = 2.4, width = 0.28, maxDistance = 300 },

	-- [3] 태초 각성: itemLevel → 역대 최고 스테이지(계정 최고 - PlayerProfile.getAccountBestStage). 비용 = tier1 잡몹 골드 × 이 마릿수(GoldCost "awaken" - 계정 최고 스테이지 기준).
	-- 375마리 = 일반 프로필 약 900마리/시간 × 25분(지시 "현재 스테이지 사냥 20 ~ 30분 분량"). 등급 · 강화 · 보석 · 옵션은 그대로. 고대 제외(태초만).
	awakenGoldKills = 375,
}
