-- QUEUE-ALL8 B 허브 마을 소품 배치(ArtStyleV1 켬일 때만 - 끄면 소품 없음 · 길 · 기능 자리 상자는 그대로). 메시 = HubArtMeta(prop_*) · 배치 = server/HubArt.
--   자리 표기: facility + along(거리 방향) + side(나무 쪽 −/바깥 +) = 시설 프레임(WorldMapLayout.spot과 같은 식) · 또는 angleDeg + r(허브 원점 기준).
--   yaw = 도(0 = 소품 앞(−Z)이 나무 쪽) · rgb = 조각 색 덮기 { 조각 이름 = { r, g, b } }.
--   길 안내 · 자동 이동 경로 위 배치 금지 = clear(서버 HubPathVerify.props가 배치된 소품마다 다시 잰다 · scatter는 놓을 때 같은 규칙으로 거른다).
return {
	folder = "Props", -- Workspace.HubArt 아래
	-- 손으로 놓는 소품(거리마다 성격)
	placements = {
		-- 시장 거리: 노점 · 상자 · 수레 · 나무통
		{ kind = "prop_stall", facility = "market", along = 16, side = 14 },
		{ kind = "prop_stall", facility = "market", along = 34, side = 14, rgb = { Awning = { 70, 130, 210 } } },
		{ kind = "prop_crates", facility = "market", along = 48, side = 8, yaw = 15 },
		{ kind = "prop_cart", facility = "market", along = 50, side = -10, yaw = 25 },
		{ kind = "prop_barrel", facility = "market", along = -50, side = 8 },
		{ kind = "prop_barrel", facility = "market", along = -47, side = 11 },
		{ kind = "prop_flowerpot", facility = "market", along = -8, side = 14 },
		{ kind = "prop_flowerpot", facility = "market", along = 8, side = 14 },
		-- 대장간 거리: 모루 동상 · 나무통 · 상자 · 표지판
		{ kind = "prop_anvil_statue", facility = "forge", along = -24, side = -12 },
		{ kind = "prop_barrel", facility = "forge", along = -48, side = 8 },
		{ kind = "prop_barrel", facility = "forge", along = -45, side = 11 },
		{ kind = "prop_crates", facility = "forge", along = -40, side = 13, yaw = -10 },
		{ kind = "prop_sign", facility = "forge", along = 54, side = -16, yaw = 30 },
		-- 커뮤니티 광장: 깃발 4 · 벤치 2 · 화분
		{ kind = "prop_flag", facility = "community", along = -47, side = -4 },
		{ kind = "prop_flag", facility = "community", along = 47, side = -4, rgb = { Cloth = { 70, 120, 210 } } },
		{ kind = "prop_flag", facility = "community", along = -24, side = 42, rgb = { Cloth = { 240, 190, 60 } } },
		{ kind = "prop_flag", facility = "community", along = 24, side = 42, rgb = { Cloth = { 90, 170, 90 } } },
		{ kind = "prop_bench", facility = "community", along = -16, side = 20, yaw = 180 },
		{ kind = "prop_bench", facility = "community", along = 16, side = 20, yaw = 180 },
		{ kind = "prop_flowerpot", facility = "community", along = -20, side = -40 },
		{ kind = "prop_flowerpot", facility = "community", along = 20, side = -40 },
		-- 포탈 광장 · 체크포인트 둘레
		{ kind = "prop_well", angleDeg = -40, r = 215 },
		{ kind = "prop_bench", angleDeg = -78, r = 196, yaw = 10 },
		{ kind = "prop_sign", angleDeg = -100, r = 196, yaw = -20 },
		-- QUEUE-ALL8 H2: 큰 나무 뿌리 사이(아늑하게) - 꽃밭 · 랜턴(뿌리 각 ±14° 밖)
		{ kind = "prop_flowers", angleDeg = 97, r = 128 }, { kind = "prop_flowers", angleDeg = 133, r = 130 }, { kind = "prop_flowers", angleDeg = 192, r = 126 }, { kind = "prop_flowers", angleDeg = 250, r = 130 },
		{ kind = "prop_lantern", angleDeg = 100, r = 146 }, { kind = "prop_lantern", angleDeg = 190, r = 146 }, { kind = "prop_lantern", angleDeg = 255, r = 146 },
	},
	-- 거리 · 광장 랜턴(카툰 가로등) - 거리 앞 모서리 · 광장 둘레
	lanterns = {
		{ facility = "forge", along = -56, side = -18 }, { facility = "forge", along = 56, side = -18 },
		{ facility = "market", along = -56, side = -18 }, { facility = "market", along = 56, side = -18 },
		{ facility = "community", along = -38, side = -38 }, { facility = "community", along = 38, side = -38 },
		{ facility = "portal", along = -34, side = -34 }, { facility = "portal", along = 34, side = -34 },
	},
	boundaryLanterns = true, -- 허브 경계 노란 점 기둥(LanternPost · Lantern 32) → prop_lantern(겉모습만)
	-- 건물 줄 뒤 낮은 울타리(마을 밖 들판과 경계) - 줄 양끝 + edgeExtra까지 · 뒤 = 건물 뒤 + backGap
	fences = { kind = "prop_fence", segment = 8, backGap = 4, edgeExtra = 6, facilities = { "forge", "market", "community" } },
	-- 빈 땅 채우기(고정 시드 - 매번 같은 자리): 활동 영역(시설 · 기능 자리 · 체크포인트 · 스폰 activityRadius 안)의 격자 spacing마다 흔들어 하나
	scatter = {
		seed = 20261002, spacing = 15, jitter = 0.35, rMin = 120, rMax = 380, activityRadius = 85,
		kinds = { { kind = "prop_bush", weight = 4 }, { kind = "prop_flowers", weight = 3 }, { kind = "prop_tree_small", weight = 2 }, { kind = "prop_flowerpot", weight = 1 } },
	},
	-- 비워 둘 거리(stud): 구역 길(RoadNet) · 걷는 길(체크포인트 · 스폰 → 시설 · 기능 자리 · 길 시작) · 건물 상자 · 자리 기둥 · 거리 · 광장 바닥 · 나무 뿌리
	clear = { road = 8, corridor = 6, building = 4, spot = 8, floor = 2, rootAngleDeg = 14, rootR = 175 },
	-- 단순 충돌(울타리 · 우물만 - 나머지는 겉모습만)
	colliders = { prop_fence = { 8, 2.4, 0.6 }, prop_well = { 5, 2.2, 5 } },
	-- 바닥(거리 · 광장 = 카툰 자갈 + 테두리 연석 · 색 = 지도 큰 길 색 계열 render.py ROAD_FILL · ROAD_EDGE)
	floor = { material = "Pavement", -- Cobblestone은 길찾기가 돌아가는 비용으로 본다(실측 9.91 vs 9.38초 · 3회 같음) → 돌 판 Pavement
		 rgb = { 222, 204, 164 }, curbRgb = { 130, 100, 66 }, texture = "terrain/hub_cobble", studsPerTile = 14, -- 무늬 = roblox/tools/mapgen/cobble_texture.py
		 curbW = 1.2, curbH = 0.45, ringSegments = 24 },
}
