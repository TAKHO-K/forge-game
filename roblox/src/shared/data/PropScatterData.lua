-- M1-4 빈 공간 채우기 수치(소품 흩뿌리기 · 절벽 사다리). 식 = shared/PropScatter(결정적 - 고정 시드) · 소품 틀 = data/PropData.
-- 규칙(사용자): 필수 길(도로 · 캠프 · 관문 · 사냥 지대 · 포탈)은 막지 않는다 · 비밀 둥지 보호 부피를 침범하지 않는다(캡슐 검사 재실행) · 물 · 급경사 · 너무 높은 곳 금지.
-- 측정: "걷는 격자점 → 가장 가까운 볼거리(소품 · 구조물 · 랜드마크 · 지형 변화)" 거리 > emptyStuds 비율(검증 M1-4(가) · 보고서 빈 공간 전/후).
return {
	seed = 20261004,
	emptyStuds = 60, -- 빈 곳 기준(사용자 예시 60 · 걷기 약 4초)
	-- 후보 = 격자 cell마다 한 점(흔들림 jitter) · 가장 가까운 볼거리가 minGap보다 가까우면 건너뛴다(빈 곳에만 놓는다)
	cell = 88, jitter = 0.8, minGap = 64,
	sizeMul = 1.6, -- 묶음 배율 전체에 곱한다(M1-4 첫 스크린샷: 틀 크기 그대로는 세계 크기에 비해 자갈처럼 보였다)
	-- 빈터(초원 · 사막 평지)를 남기는 밀도 잡음: fbm(x/lambda) < sparse면 그 칸은 건너뛴다(고른 격자처럼 보이지 않게)
	density = { lambda = 380, sparse = -0.3 },
	hubMargin = 60, -- 허브 안전 반경 + 이만큼 밖
	edgeMargin = 30, -- 외곽 허용 반경(능선) − 이만큼 안
	maxAbove = 110, -- 평지 위 이 높이까지(능선 비탈 · 둥지 대지 위는 괜찮다)
	maxRelief = 8, -- 발자국(반경 footprint) 안 높이 차 상한(비탈에 걸쳐 뜨지 않게)
	-- 피하는 거리(가장자리 기준 여유)
	avoid = { road = 14, camp = 70, gate = 90, ground = 18, portal = 30, nest = 12, protect = 6, feature = 12, structure = 16, basin = 30, water = 10, spawnSlot = 10 },
	-- 구역 테마 묶음: weight = 고를 무게 · items = { { 소품, x, z, yaw(도), 배율 { 최소, 최대 } } } - 묶음 원점 = 후보 점 · 묶음 전체를 무작위로 돌린다
	sets = {
		tier1 = {
			{ weight = 3, items = { { "T1_RockPillar", 0, 0, 0, { 0.8, 1.3 } }, { "T1_Boulder", 9, 4, 30, { 0.7, 1.0 } } } },
			{ weight = 2, items = { { "T1_StoneArch", 0, 0, 0, { 0.9, 1.2 } } } },
			{ weight = 2, items = { { "T1_BalancedRock", 0, 0, 0, { 0.8, 1.2 } }, { "T1_Boulder", -8, -5, 70, { 0.6, 0.9 } } } },
			{ weight = 3, items = { { "Common_Tree", 0, 0, 0, { 0.9, 1.3 } }, { "Common_Tree", 11, 6, 90, { 0.7, 1.0 } }, { "Common_FallenLog", -6, 12, 40, { 0.8, 1.0 } } } },
			{ weight = 2, items = { { "Common_RuinWall", 0, 0, 0, { 0.9, 1.2 } }, { "T1_RuinPillarBroken", 10, 3, 0, { 1.0, 1.4 } } } },
			{ weight = 2, items = { { "Common_Tree", 0, 0, 0, { 1.0, 1.4 } }, { "T1_Boulder", 7, -6, 0, { 0.6, 0.9 } } } },
		},
		tier2 = {
			{ weight = 3, items = { { "T2_CrystalSpike", 0, 0, 0, { 0.9, 1.5 } }, { "T2_CrystalCluster", 7, 3, 0, { 0.8, 1.1 } } } },
			{ weight = 2, items = { { "T2_CaveMouth", 0, 0, 0, { 0.9, 1.2 } }, { "T2_CrystalCluster", -10, -4, 0, { 0.7, 1.0 } } } },
			{ weight = 2, items = { { "T2_Boulder", 0, 0, 0, { 0.9, 1.3 } }, { "T2_CrystalSpike", 6, 5, 40, { 0.6, 0.9 } } } },
			{ weight = 2, items = { { "T2_CrystalCluster", 0, 0, 0, { 1.2, 1.6 } }, { "T2_Boulder", 9, -3, 20, { 0.6, 0.8 } } } },
		},
		tier3 = {
			{ weight = 3, items = { { "T3_CoastRock", 0, 0, 0, { 0.9, 1.4 } }, { "T1_Boulder", 8, 5, 0, { 0.5, 0.8 } } } },
			{ weight = 1, items = { { "T3_Shipwreck", 0, 0, 0, { 0.9, 1.1 } } } },
			{ weight = 2, items = { { "Common_FallenLog", 0, 0, 0, { 0.8, 1.1 } }, { "Common_Tree", 9, -8, 0, { 0.9, 1.2 } } } },
			{ weight = 2, items = { { "Common_RuinWall", 0, 0, 0, { 0.9, 1.2 } }, { "T1_RuinPillarBroken", -9, 2, 0, { 0.8, 1.2 } } } },
			{ weight = 2, items = { { "Common_Tree", 0, 0, 0, { 1.0, 1.4 } }, { "T3_CoastRock", 10, 4, 60, { 0.5, 0.7 } } } },
		},
		tier4 = {
			{ weight = 3, items = { { "T4_MushroomRock", 0, 0, 0, { 0.9, 1.4 } }, { "T4_Boulder", 9, 4, 0, { 0.7, 1.0 } } } },
			{ weight = 3, items = { { "T4_Hoodoo", 0, 0, 0, { 0.8, 1.3 } }, { "T4_Hoodoo", 8, 5, 60, { 0.5, 0.7 } } } },
			{ weight = 2, items = { { "T4_Boulder", 0, 0, 0, { 1.0, 1.5 } }, { "T4_Cactus", 7, -4, 0, { 0.8, 1.1 } } } },
			{ weight = 1, items = { { "Common_RuinWall", 0, 0, 0, { 1.0, 1.3 } } } },
		},
		tier5 = {
			{ weight = 3, items = { { "T5_SpireRock", 0, 0, 0, { 0.9, 1.5 } }, { "T5_Boulder", 8, 4, 0, { 0.6, 0.9 } } } },
			{ weight = 2, items = { { "T5_StruckRock", 0, 0, 0, { 0.9, 1.2 } } } },
			{ weight = 2, items = { { "T5_SpireRock", 0, 0, 0, { 0.7, 1.0 } }, { "T5_SpireRock", 9, -4, 30, { 0.5, 0.7 } }, { "T5_Boulder", -6, 6, 0, { 0.6, 0.8 } } } },
			{ weight = 1, items = { { "Common_FallenLog", 0, 0, 0, { 0.8, 1.0 } }, { "T5_Boulder", 7, 7, 0, { 0.6, 0.8 } } } },
		},
		tier6 = {
			{ weight = 3, items = { { "T6_IcePillar", 0, 0, 0, { 0.9, 1.5 } }, { "T6_IceChunk", 8, 3, 0, { 0.6, 0.9 } } } },
			{ weight = 2, items = { { "T6_IceChunk", 0, 0, 0, { 1.0, 1.4 } }, { "T6_SnowBoulder", -7, 5, 0, { 0.7, 1.0 } } } },
			{ weight = 2, items = { { "T6_SnowBoulder", 0, 0, 0, { 1.0, 1.4 } }, { "T6_IcePillar", 7, -5, 30, { 0.6, 0.9 } } } },
			{ weight = 1, items = { { "Common_FallenLog", 0, 0, 0, { 0.8, 1.0 } }, { "T6_SnowBoulder", 8, 6, 0, { 0.5, 0.8 } } } },
		},
	},
	-- 절벽 + 사다리(구역 옛 cliff 지형 - WorldMapData features 번호): 절벽 윗면 = 전망 지점. side = 사다리를 붙일 면(구역 좌표 방향 도 - 0 = 허브 쪽)
	--   오를 곳 최고 120(M1-3 결정 4 - standMaxY 160 아래). T5 낙뢰 절벽(150)은 경치로 둔다.
	cliffLadders = {
		{ zone = "tier1", feature = 5, side = 0 },
		{ zone = "tier3", feature = 5, side = 0 },
		{ zone = "tier6", feature = 1, side = 0 },
	},
	ladder = { standoff = 1.2, landing = 7 },
	-- M1-4 외곽 벽 사다리(구역 테마 경계 - 메사 계단 벽 · 빙벽): 방위 deg에서 발치 → 능선으로 지형을 훑어 벽(10 안에 20 넘게 오름)마다 하나씩
	edgeLadders = { { zone = "tier4", deg = 12 }, { zone = "tier6", deg = 22 } }, -- 사다리 = 절벽 면에서 standoff 앞 · 꼭대기 발판 길이(절벽 가장자리 너머까지)
}
