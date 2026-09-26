-- M1-3 둥지 3트랙(알 줍기 자리) - 수치 · 자리의 단일 출처. 도형 = shared/WorldStructures(키트) · 지형은 둥지 자리를 먼저 비우고 그 위에 쌓는다(TerrainShape S4 · 보호 부피).
-- 알 품질 기준 = 높이가 아니라 "찾기 · 도달 난이도"(사용자). 구역마다 A 5 · B 3 · C 2(= 50 / 30 / 20) + 허브 C-마을 4.
--   A 열린 둥지: 높은 바위 · 나무 위 · 절벽 끝(점프 · 이후 활강으로 닿는다). high = 직접 오른 높은 곳 → 알 저점 보장(좋은 이상).
--   B 도전 둥지: 점프맵 끝 · 신전 꼭대기 · 흔들다리 가운데 · 수중 신전 - 지붕 · 굴 · 좁은 입구로 위에서 활강 착지 불가. top = B 최상위(하루 1회).
--   C 비밀 둥지: 지도 · 길 안내 · 표시 없음(환경 힌트만). village = 허브(한 단계 낮게) · field = 전투 지역(고정) · hidden = 진짜 히든(후보 5곳 중 매일 1곳 - 순환).
-- 자리: zone(구역 키 · 허브 = "hub") · r · lat(구역 좌표) · face(허브 쪽 기준 회전 도) · kit + 키트 인자. 키트 = WorldStructures.KITS.
--   kit = rock(높은 바위 - h · skill easy | air1 | air2) · tree(h) · mesaEdge(대지 가장자리 - mesa 번호 · steps) · ledge(지형 선반 위 - level) · feature(옛 지형 위 - index) · landmark(랜드마크 위) ·
--         tower(w · h · cols) · shrine(기둥 점프 코스 끝 사당) · cliffCave(mouth · 절벽 굴) · cave(구역 굴 안 수정 점프맵) · alcove(숨은 방 - cover = fakeWall | vine | waterfall | buried | ice | slab | timed | oasis | underwater) ·
--         bridgeHut(흔들다리 가운데) · sunken(수중 신전 안) · mesaShrine(빙벽 위 사당) · hub 전용(chimney · attic · trunk · arch).
--   hint = 환경 힌트(C) - fireflies(반딧불 몇 마리 · 클라) · moss(이끼 줄) · stone(어긋난 돌) · flow(물살 방향) · birds(새 - 소리 에셋 없음: 앉은 새 모형 자리만).

local NESTS = {
	-- ═══ T1 석조 평원 ═══
	{ id = "t1_a_pillar", zone = "tier1", track = "A", r = 1930, lat = 205, kit = "rock", h = 14, skill = "easy", style = "pillar" },
	{ id = "t1_a_rock", zone = "tier1", track = "A", r = 1150, lat = 480, kit = "rock", h = 10, skill = "easy" },
	{ id = "t1_a_mesa", zone = "tier1", track = "A", high = true, r = 2250, lat = 460, kit = "mesaEdge", mesa = 1 },
	{ id = "t1_a_tree", zone = "tier1", track = "A", high = true, r = 1150, lat = -470, kit = "tree", h = 26 },
	{ id = "t1_a_crag", zone = "tier1", track = "A", r = 1650, lat = -500, kit = "rock", h = 12, skill = "air1" },
	{ id = "t1_b_watch", zone = "tier1", track = "B", r = 1180, lat = -610, kit = "tower", w = 16, h = 48, cols = 2 },
	{ id = "t1_b_peakcave", zone = "tier1", track = "B", top = true, r = 2545, lat = -330, kit = "cliffCave", mouth = 18 },
	{ id = "t1_b_ruins", zone = "tier1", track = "B", r = 2090, lat = 280, face = 20, kit = "shrine" },
	{ id = "t1_c_field", zone = "tier1", track = "C", sub = "field", r = 1590, lat = -560, face = 180, kit = "alcove", cover = "fakeWall", hint = { "stone", "moss" } },
	{ id = "t1_c_h1", zone = "tier1", track = "C", sub = "hidden", r = 2505, lat = 0, inLandmark = true, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t1_c_h2", zone = "tier1", track = "C", sub = "hidden", r = 1060, lat = 640, face = -30, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t1_c_h3", zone = "tier1", track = "C", sub = "hidden", r = 1330, lat = 380, kit = "alcove", cover = "trunk", hint = { "birds" } },
	{ id = "t1_c_h4", zone = "tier1", track = "C", sub = "hidden", r = 2540, lat = 360, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t1_c_h5", zone = "tier1", track = "C", sub = "hidden", r = 1000, lat = -300, face = 60, kit = "alcove", cover = "vine", hint = { "fireflies", "moss" } },

	-- ═══ T2 수정 동굴 ═══
	{ id = "t2_a_rock", zone = "tier2", track = "A", r = 1050, lat = -420, kit = "rock", h = 10, skill = "easy", style = "crystal" },
	{ id = "t2_a_crag", zone = "tier2", track = "A", r = 1600, lat = -620, kit = "rock", h = 14, skill = "air1", style = "crystal" },
	{ id = "t2_a_hill", zone = "tier2", track = "A", high = true, kit = "feature", feature = 3, offset = { 12, 0 } },
	{ id = "t2_a_tower", zone = "tier2", track = "A", high = true, kit = "feature", feature = 4, offset = { 4, 4 } },
	{ id = "t2_a_ridge", zone = "tier2", track = "A", r = 2330, lat = 260, kit = "rock", h = 12, skill = "air1", style = "crystal" },
	{ id = "t2_b_cave", zone = "tier2", track = "B", top = true, kit = "cave", cave = 1 },
	{ id = "t2_b_spire", zone = "tier2", track = "B", r = 1250, lat = 520, kit = "tower", w = 16, h = 44, cols = 2 },
	{ id = "t2_b_shrine", zone = "tier2", track = "B", r = 1750, lat = -560, face = -40, kit = "shrine" },
	{ id = "t2_c_field", zone = "tier2", track = "C", sub = "field", r = 1720, lat = 560, face = 90, kit = "alcove", cover = "fakeWall", hint = { "stone", "fireflies" } },
	{ id = "t2_c_h1", zone = "tier2", track = "C", sub = "hidden", r = 2330, lat = 700, face = 150, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t2_c_h2", zone = "tier2", track = "C", sub = "hidden", r = 1320, lat = -620, kit = "alcove", cover = "vine", hint = { "moss" } },
	{ id = "t2_c_h3", zone = "tier2", track = "C", sub = "hidden", r = 2505, lat = 0, inLandmark = true, kit = "alcove", cover = "slab", hint = { "stone" } },
	{ id = "t2_c_h4", zone = "tier2", track = "C", sub = "hidden", r = 1950, lat = -720, face = -60, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t2_c_h5", zone = "tier2", track = "C", sub = "hidden", r = 1990, lat = 780, face = 170, kit = "alcove", cover = "fakeWall", hint = { "moss" } },

	-- ═══ T3 수몰 사원 ═══
	{ id = "t3_a_rock", zone = "tier3", track = "A", r = 1100, lat = 200, kit = "rock", h = 10, skill = "easy" },
	{ id = "t3_a_tree", zone = "tier3", track = "A", high = true, r = 1500, lat = -300, kit = "tree", h = 26 },
	{ id = "t3_a_bell", zone = "tier3", track = "A", high = true, kit = "feature", feature = 2, offset = { 6, 0 } },
	{ id = "t3_a_crag", zone = "tier3", track = "A", r = 2150, lat = 250, kit = "rock", h = 12, skill = "air1" },
	{ id = "t3_a_bank", zone = "tier3", track = "A", r = 1650, lat = -380, kit = "rock", h = 10, skill = "easy" },
	{ id = "t3_b_temple", zone = "tier3", track = "B", top = true, kit = "sunken" },
	{ id = "t3_b_spire", zone = "tier3", track = "B", r = 1650, lat = -720, kit = "tower", w = 16, h = 44, cols = 2 },
	{ id = "t3_b_shrine", zone = "tier3", track = "B", r = 2300, lat = 520, face = 30, kit = "shrine" },
	{ id = "t3_c_field", zone = "tier3", track = "C", sub = "field", r = 2010, lat = -500, kit = "alcove", cover = "underwater", river = 4, hint = { "flow", "fireflies" } },
	{ id = "t3_c_h1", zone = "tier3", track = "C", sub = "hidden", r = 1300, lat = -662, face = -70, kit = "alcove", cover = "waterfall", hint = { "flow" } },
	{ id = "t3_c_h2", zone = "tier3", track = "C", sub = "hidden", r = 2450, lat = 290, face = 60, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t3_c_h3", zone = "tier3", track = "C", sub = "hidden", r = 1200, lat = 560, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t3_c_h4", zone = "tier3", track = "C", sub = "hidden", r = 1000, lat = -150, kit = "alcove", cover = "trunk", hint = { "birds" } },
	{ id = "t3_c_h5", zone = "tier3", track = "C", sub = "hidden", r = 2250, lat = 640, face = 120, kit = "alcove", cover = "vine", hint = { "moss" } },

	-- ═══ T4 모래 유적 ═══
	{ id = "t4_a_rock", zone = "tier4", track = "A", r = 1050, lat = -350, kit = "rock", h = 10, skill = "easy", style = "sand" },
	{ id = "t4_a_pyramid", zone = "tier4", track = "A", high = true, kit = "landmark" },
	{ id = "t4_a_obelisk", zone = "tier4", track = "A", high = true, kit = "feature", feature = 3, offset = { 4, 4 } },
	{ id = "t4_a_crag", zone = "tier4", track = "A", r = 2250, lat = -250, kit = "rock", h = 12, skill = "air1", style = "sand" },
	{ id = "t4_a_dune", zone = "tier4", track = "A", r = 1300, lat = 200, kit = "rock", h = 8, skill = "easy", style = "sand" },
	{ id = "t4_b_vault", zone = "tier4", track = "B", top = true, r = 1650, lat = -700, kit = "tower", w = 18, h = 44, cols = 2 },
	{ id = "t4_b_shrine", zone = "tier4", track = "B", r = 2150, lat = 300, face = 60, kit = "shrine" },
	{ id = "t4_b_peakcave", zone = "tier4", track = "B", r = 2545, lat = -400, kit = "cliffCave", mouth = 18 },
	{ id = "t4_c_field", zone = "tier4", track = "C", sub = "field", r = 1480, lat = 530, kit = "alcove", cover = "oasis", hint = { "fireflies" } },
	{ id = "t4_c_h1", zone = "tier4", track = "C", sub = "hidden", r = 1200, lat = 480, kit = "alcove", cover = "buried", hint = { "stone" } },
	{ id = "t4_c_h2", zone = "tier4", track = "C", sub = "hidden", r = 2290, lat = 590, face = 150, kit = "alcove", cover = "buried", hint = { "stone" } },
	{ id = "t4_c_h3", zone = "tier4", track = "C", sub = "hidden", r = 2420, lat = -210, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t4_c_h4", zone = "tier4", track = "C", sub = "hidden", r = 1700, lat = -300, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t4_c_h5", zone = "tier4", track = "C", sub = "hidden", r = 2050, lat = -560, kit = "alcove", cover = "buried", hint = { "birds" } },

	-- ═══ T5 폭풍 첨탑 ═══
	{ id = "t5_a_rock", zone = "tier5", track = "A", r = 1000, lat = -300, kit = "rock", h = 10, skill = "easy" },
	{ id = "t5_a_wind", zone = "tier5", track = "A", high = true, kit = "feature", feature = 1, offset = { 6, 6 } },
	{ id = "t5_a_crag", zone = "tier5", track = "A", r = 1500, lat = -150, kit = "rock", h = 12, skill = "air1" },
	{ id = "t5_a_shoulder", zone = "tier5", track = "A", high = true, r = 2262, lat = 548, kit = "ledge", level = 60 },
	{ id = "t5_a_ridge", zone = "tier5", track = "A", r = 2350, lat = 200, kit = "rock", h = 12, skill = "air1" },
	{ id = "t5_b_thunder", zone = "tier5", track = "B", top = true, r = 2150, lat = -600, kit = "tower", w = 30, h = 110, cols = 3, temple = "thunder" },
	{ id = "t5_b_bridge", zone = "tier5", track = "B", kit = "bridgeHut" },
	{ id = "t5_b_shrine", zone = "tier5", track = "B", r = 1800, lat = 520, face = 60, kit = "shrine" },
	{ id = "t5_c_field", zone = "tier5", track = "C", sub = "field", r = 2215, lat = 640, face = -140, kit = "alcove", cover = "fakeWall", base = "natural", hint = { "stone", "moss" } }, -- 흔들다리 아래 절벽 틈
	{ id = "t5_c_h1", zone = "tier5", track = "C", sub = "hidden", r = 2150, lat = -600, kit = "alcove", cover = "timed", templeBack = true, hint = { "stone" } }, -- 번개 칠 때만 열리는 문(신전 뒤)
	{ id = "t5_c_h2", zone = "tier5", track = "C", sub = "hidden", r = 2400, lat = -450, kit = "alcove", cover = "fakeWall", hint = { "moss" } },
	{ id = "t5_c_h3", zone = "tier5", track = "C", sub = "hidden", r = 1600, lat = -450, kit = "alcove", cover = "vine", hint = { "fireflies" } },
	{ id = "t5_c_h4", zone = "tier5", track = "C", sub = "hidden", r = 1250, lat = 560, face = -40, kit = "alcove", cover = "vine", hint = { "moss" } },
	{ id = "t5_c_h5", zone = "tier5", track = "C", sub = "hidden", r = 2470, lat = -110, kit = "alcove", cover = "slab", hint = { "stone" } },

	-- ═══ T6 빙하 동굴 ═══
	{ id = "t6_a_rock", zone = "tier6", track = "A", r = 1050, lat = 300, kit = "rock", h = 10, skill = "easy", style = "ice" },
	{ id = "t6_a_tower", zone = "tier6", track = "A", high = true, kit = "feature", feature = 5, offset = { 4, 4 } },
	{ id = "t6_a_lake", zone = "tier6", track = "A", high = true, r = 2045, lat = 452, kit = "ledge", level = 55 },
	{ id = "t6_a_crag", zone = "tier6", track = "A", r = 1700, lat = -250, kit = "rock", h = 12, skill = "air1", style = "ice" },
	{ id = "t6_a_ridge", zone = "tier6", track = "A", r = 2300, lat = -250, kit = "rock", h = 12, skill = "air1", style = "ice" },
	{ id = "t6_b_icewall", zone = "tier6", track = "B", top = true, kit = "mesaShrine", mesa = 2 },
	{ id = "t6_b_spire", zone = "tier6", track = "B", r = 1300, lat = 550, kit = "tower", w = 16, h = 44, cols = 2 },
	{ id = "t6_b_shrine", zone = "tier6", track = "B", r = 2250, lat = 200, face = 30, kit = "shrine" },
	{ id = "t6_c_field", zone = "tier6", track = "C", sub = "field", r = 1438, lat = -612, face = 0, kit = "alcove", cover = "ice", noMound = true, hint = { "moss" } }, -- 빙벽 틈(빙하 혀 안)
	{ id = "t6_c_h1", zone = "tier6", track = "C", sub = "hidden", r = 2140, lat = 455, face = 30, kit = "alcove", cover = "ice", base = 55, hint = { "fireflies" } }, -- 호수 선반 뒤 얼음 틈
	{ id = "t6_c_h2", zone = "tier6", track = "C", sub = "hidden", r = 2400, lat = -300, kit = "alcove", cover = "fakeWall", hint = { "stone" } },
	{ id = "t6_c_h3", zone = "tier6", track = "C", sub = "hidden", r = 2480, lat = -150, kit = "alcove", cover = "slab", hint = { "moss" } },
	{ id = "t6_c_h4", zone = "tier6", track = "C", sub = "hidden", r = 1200, lat = -600, face = 30, kit = "alcove", cover = "ice", hint = { "stone" } },
	{ id = "t6_c_h5", zone = "tier6", track = "C", sub = "hidden", r = 1450, lat = 700, face = -60, kit = "alcove", cover = "vine", hint = { "fireflies" } },

	-- ═══ 허브 C-마을(안전 · 가기 쉬움 - 한 단계 낮게) ═══
	{ id = "hub_c_chimney", zone = "hub", track = "C", sub = "village", kit = "chimney", facility = "forge" },
	{ id = "hub_c_attic", zone = "hub", track = "C", sub = "village", kit = "attic", facility = "market" },
	{ id = "hub_c_trunk", zone = "hub", track = "C", sub = "village", kit = "trunk", angleDeg = 255 },
	{ id = "hub_c_arch", zone = "hub", track = "C", sub = "village", kit = "arch", facility = "portal" },
}

return {
	nests = NESTS,
	-- 키트 공통 수치(이동 기준 movement-metrics v2 · 80% 여유 - 검증이 leaps를 Layout.moveSkill로 잰다)
	kit = {
		skill = { easy = { rise = 4, gap = 4 }, air1 = { rise = 9, gap = 7 }, air2 = { rise = 13, gap = 9 } },
		rock = { top = 8, step = 6 },
		tree = { trunk = 5, rise = 5, gap = 4, pad = 5, top = 12 },
		tower = { wall = 2, door = { w = 5, h = 8 }, pad = 5, rise = 7, headroom = 7 },
		templeTower = { pad = 5, rise = 9 },
		shrine = { pillars = { { h = 5, gap = 4 }, { h = 13, gap = 7 }, { h = 24, gap = 11 } }, dashGap = 22, top = 26, size = 12, roofH = 8, pillar = 5 },
		cliffCave = { rise = 9, gap = 6, ledge = 6, width = 10, height = 9, depth = 22, chamber = 16, mound = 26 },
		alcove = { w = 8, d = 8, h = 7, wall = 1.5, door = 5, doorH = 6, mound = 11, moundRadius = 15, moundBlend = 20 },
		caveCourse = { pillars = { { h = 6, gap = 4 }, { h = 13, gap = 5 }, { h = 20, gap = 5 } }, ledge = 27 },
		bridge = { width = 8, plank = 4, sag = 3.5, rail = 3.2, hut = 11, hutH = 8 },
		gorgeExit = { rise = 4.6, steps = 4, size = 4 },
		marker = { ring = 3.4, ringH = 0.8 },
	},
	-- 줍기 · 재생성(개인 쿨다운 - 모두에게 보이고 각자 기준으로 줍는다). 초.
	respawn = {
		A = { seconds = 30 * 60 },
		B = { minSeconds = 2 * 3600, maxSeconds = 4 * 3600 },
		Btop = { daily = true },
		Cvillage = { minSeconds = 2 * 3600, maxSeconds = 4 * 3600 }, -- 지시에 없음 - B와 같게(결정 로그)
		Cfield = { minSeconds = 2 * 3600, maxSeconds = 4 * 3600 },
		Chidden = { daily = true },
	},
	-- 하루 경계 = 한국 자정(UTC + 9) · 순환형 = 날짜마다 후보 5곳 중 1곳(구역 키 해시 + 날짜 - 이웃 날은 다른 곳)
	dayOffsetSeconds = 9 * 3600,
	rotateCandidates = 5,
	-- 줍기 서버 검증(M1-2c 위치 기록): 최근 historySeconds 동안 서버가 본 루트가 둥지 반경 pickupRadius 안에 minSamples장 이상 · 표본 사이 이동 ≤ maxStepStuds(순간이동 줍기 차단).
	pickup = { radius = 9, promptDistance = 8, historySeconds = 0.5, minSamples = 3, maxStepStuds = 12, requestGapSeconds = 0.5 },
	-- 번개 문(시간형 C - 폭풍 첨탑 신전 뒤): 주기 periodSeconds 중 openSeconds 동안 열림(서버 시각 기준 - 모두 같다)
	timedDoor = { periodSeconds = 150, openSeconds = 18, graceSeconds = 1.5 },
	-- 발견 도감(C 처음 발견 - 칭호 · 꾸미기만): 개수 문턱마다 칭호(WorldMapData.sealed.title과 같은 칭호 집합 titles)
	dex = { titles = { { count = 1, id = "nestSeeker", name = "둥지 탐험가" }, { count = 10, id = "secretKeeper", name = "비밀 수집가" } }, discoverSeconds = 2.5 },
	-- 알 가방 상한(다 차면 못 줍는다 - 부화 · 펫 단계에서 쓴다)
	eggCap = 40,
}
