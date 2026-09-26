-- M1-3 대형 지형(로블록스 Terrain) 수치의 단일 출처. 형상 식 = shared/TerrainShape(순수 · 결정적) · 굽기 = server/TerrainBake(Studio edit에서 구역별로 굽고 place 저장).
-- Rojo는 Terrain 복셀을 동기화하지 않는다(docs/perf/streaming-settings.md "place 전용 항목") - 그래서 생성기(이 파일 + TerrainShape)만 git에 두고 결과는 place에 굽는다.
-- 좌표: 구역 좌표(r = 원점에서 바깥쪽 · lat = 옆) - WorldMapLayout.toWorld와 같다. 높이 level = 바닥 윗면(floorTopY) 기준 위(+) · 아래(−).
-- 구조 원칙(사용자): 큰 모양(언덕 · 능선 · 산 · 계곡 · 물 · 동굴) = 지형 / 정밀하게 밟는 곳(둥지 오르기 · 점프맵 · 다리 · 신전) = 파트(WorldStructureData · NestData).
--   둥지 · 구조물 · 길 · 캠프 · 관문이 지형의 입력이다(평탄 · 보호 부피) - 생성기가 그 자리를 먼저 비우고 둘레에 지형을 쌓는다.
-- 이동 기준(movement-metrics v2): 발 최대 19.44(옵션 21.38) · 못 오르는 벽 ≥ 23 · 못 넘는 틈 ≥ 46 · 걷는 경사 ≤ 45°(TerrainConfig) - 필수 길 = 평탄 도로(걷기).
-- 표본 높이는 standMaxY(160 - WorldMapData.progress) 아래만 "오를 수 있는 곳"으로 설계한다. 봉우리(200+)는 경치 - 기어오르면 기존 높은 곳 복귀 · 외곽 밀어내기(서버).

local ZONE_PALETTE = {
	-- 재질 = Enum.Material 이름. 색은 재질마다 하나(Terrain:SetMaterialColor는 place 전체) - 구역마다 다른 재질을 써서 색을 가른다(카툰 질감 = A1 MaterialVariant).
	tier1 = { ground = "Grass", ground2 = "LeafyGrass", slope = "Rock", cliff = "Rock", bed = "Mud" }, -- 석회암(흰색)은 비탈에서 눈처럼 보여 폐허 기둥에만
	tier2 = { ground = "Slate", ground2 = "Pavement", slope = "Basalt", cliff = "Basalt", bed = "Slate" },
	tier3 = { ground = "LeafyGrass", ground2 = "Grass", slope = "Mud", cliff = "Rock", bed = "Mud" },
	tier4 = { ground = "Sand", ground2 = "Sandstone", slope = "Sandstone", cliff = "Sandstone", bed = "Sand" },
	tier5 = { ground = "Ground", ground2 = "Asphalt", slope = "Cobblestone", cliff = "Rock", bed = "Ground" },
	tier6 = { ground = "Snow", ground2 = "Ice", slope = "Glacier", cliff = "Glacier", bed = "Ice" },
}

return {
	-- 지형 버전(구역별 - 모양을 바꾸면 그 구역 숫자를 올리고 다시 굽는다). 서버 시작 때 Terrain Attribute TerrainVersion_<구역>과 다르면 경고만(런타임 생성 금지).
	version = { hub = 1, tier1 = 1, tier2 = 1, tier3 = 1, tier4 = 1, tier5 = 1, tier6 = 1 },
	seed = 20260926,
	voxel = 4, -- 로블록스 Terrain 해상도(고정)
	-- 평지 높이 = 바닥 윗면 + flatLevel(도로 · 캠프 · 관문 판이 지형 위에 얹힌다 - 굽기 실측으로 맞춘 값). bottomY = 지형 바닥(심연 복귀선 −24 위에서 끝낸다).
	flatLevel = -0.4,
	bottomY = -22,
	minBedY = -20, -- 물 바닥 · 골짜기 바닥 하한(심연 복귀선 −24 위 - TerrainConfig.voidReturnY)
	-- 허브(파트 바닥 · 나무) = 반경 hubRadius 안은 평지(잔디). 그 밖부터 언덕이 hubRamp만큼에 걸쳐 커진다.
	hub = { radius = 470, ramp = 260, material = "Grass" },
	-- 언덕(구역 기본): fbm 두 층(파장 · 높이) - 구역마다 hills 배율.
	hills = { lambda = 260, amp = 9, lambda2 = 75, amp2 = 3, bigLambda = 560, bigAmp = 26 }, -- big = 큰 기복(구릉 - 사냥 지대 · 길은 평탄 마스크가 깎는다)
	-- 구역 원 테두리 능선(구역 경계 = 언덕 · 능선): 구역 원 중심에서 반경 radius(원 850 + 50 - 결계 바깥)에 능선 · 폭 sigma · 높이 base ± vary(원 둘레 잡음).
	--   이웃 원이 맞닿는 r 1,472에서 두 능선이 합쳐져 경계 능선이 되고, 그 안쪽(허브 쪽) · 바깥쪽(외곽)은 두 원 사이 골짜기가 된다(봉인 입구로 가는 길).
	--   원이 너무 반듯하면 인공적이다: 반경을 wobble만큼 흔들고, 방향별 세기(허브 쪽 inner · 옆 side · 바깥 outer)를 준다 - 옆(이웃 구역과 맞닿는 쪽)이 가장 높다.
	rim = { radius = 900, sigma = 80, base = 52, vary = 34, lambda = 380, wobble = 70, wobbleLambda = 300, inner = 0.3, side = 1.0, outer = 0.85 },
	-- 외곽 설산(보이는 경계 - 실제 차단은 서버 밀어내기 WorldMapData.edgeGuard): r start → full에서 오르고 높이 base ± vary(방위 잡음) · 봉우리 결 ridges. 3,200까지 이어져 끝이 안 보인다.
	--   산맥 = 밑 둔덕(base - 안부 높이) + 봉우리 줄(peakEveryDeg마다 하나 · 반경 peakR ± · 높이 peakH ± · 폭 peakWidth ±) + 날카로운 능선 결(ridge). 벽처럼 윗면이 평평하지 않게.
	edge = { start = 2560, full = 2900, outer = 3200, base = 150, vary = 40, lambdaDeg = 18, ridgeAmp = 46, ridgeLambda = 110, startVary = 170, startLambdaDeg = 9,
		peakEveryDeg = 5, peakJitterDeg = 2, peakR = { 2720, 3080 }, peakH = { 170, 400 }, peakWidth = { 130, 260 }, backFill = 3050 },
	-- 눈 · 바위 선: 높이(바닥 기준) snowLine ± snowVary 위 = 눈 · 경사 steepDeg 넘으면 바위(구역 cliff 재질).
	snowLine = 170, snowVary = 25, snowMaterial = "Snow", steepDeg = 40, rockMaterial = "Rock",
	-- 바깥 고리 확장 자리(WorldMapData.reserved.outerRing - 꽃잎 사이) = 설산 속 분지 + 허브 쪽에서 들어가는 골짜기(봉인 입구 문 앞까지 걸어서).
	-- 서버 경계 백업(사용자 보강 ②): 발이 반경 allowR(설산 발치) 밖에 서 있으면 안쪽으로 pushStuds 밀어낸다. 봉인 입구 분지 · 골짜기와 바다 만(헤엄) 안은 basinAllowR까지.
	edgeGuard = { allowR = 2640, basinAllowR = 2945, pushStuds = 8 },
	reservedBasin = { centerR = 2760, radius = 170, blend = 90, corridorFromR = 2200, corridorWidth = 50, corridorBlend = 90 },
	-- 평탄 마스크 공통(도로 · 캠프 · 사냥 지대 · 관문 · 결계 문 · 옛 지형 · 봉인 입구): 반경 + margin 안 = 평지 · 그 밖 blend에 걸쳐 원래 지형으로.
	flatten = { roadMargin = 10, roadBlend = 70, campRadius = 70, groundRadius = 150, gateRadius = 90, raidRadius = 40, featureMargin = 14, blend = 60, sealedRadius = 70 },
	-- 보호 부피(사용자 보강 ①): 둥지 · 동굴 · 통로 부피 + 여유 protectMargin(= 통로 폭 여유 8) 안은 굽기 뒤에도 공기(2차 비우기 FillBlock/FillBall Air).
	protectMargin = 4,
	water = { material = "Water", color = { 70, 130, 170 }, transparency = 0.35, waveSize = 0.08, waveSpeed = 6, reflectance = 0.6 },
	-- 재질 색(place 전체 - 굽기가 설정). 기존 WorldMapData 회색 · 구역 바닥 색 계열 + 자연색.
	materialColors = {
		Grass = { 106, 138, 78 }, LeafyGrass = { 88, 128, 70 }, Limestone = { 196, 190, 170 }, Rock = { 128, 124, 118 }, Mud = { 92, 76, 58 },
		Slate = { 96, 100, 116 }, Pavement = { 120, 124, 140 }, Basalt = { 70, 72, 84 },
		Sand = { 214, 190, 138 }, Sandstone = { 186, 150, 104 },
		Ground = { 112, 102, 90 }, Asphalt = { 84, 84, 92 }, Cobblestone = { 118, 114, 116 },
		Snow = { 236, 240, 246 }, Ice = { 190, 222, 240 }, Glacier = { 160, 200, 226 },
	},
	palette = ZONE_PALETTE,

	-- ═══ 구역별 ═══ hills = 언덕 배율 · peaks = 봉우리(가우스 · 이름 있으면 랜드마크 - 구역당 200+ 1개 이상) · mesas = 솟은 대지(윗면 level · 가장자리 blend - 작을수록 절벽) ·
	--   trails = 산길(점마다 level - 사이 선형 · 폭 width · 양옆 blend) · valleys = 골짜기(바닥 = 평지 − depth · 물 stream = 바닥 위 수심) · river = 물살 강(점마다 수면 level) ·
	--   lakes = 호수(수면 level · 수심 depth · 가장자리 blend) · bay = 바다 만(수면 level · 바닥 bed) · dunes = 사구 · caves = 굴(점 = { r, lat, floor } · 반경 radius · 높이 height).
	zones = {
		tier1 = {
			hills = 1.0,
			peaks = {
				{ r = 2820, lat = -320, h = 300, radius = 300, name = "수호자 봉" },
				{ r = 2720, lat = 560, h = 230, radius = 250 },
			},
			mesas = { { r = 2250, lat = 460, radius = 42, level = 40, blend = 12, material = "Limestone" } }, -- 전망 바위(A 높은 둥지)
			valleys = {
				-- 작은 계곡(마른 개울 + 얕은 물줄기 - 흐름 없음)
				{ pts = { { 1300, -560 }, { 1500, -640 }, { 1750, -610 }, { 1980, -700 } }, width = 46, depth = 16, blend = 22, stream = 2 },
			},
		},
		tier2 = {
			hills = 0.8,
			peaks = {
				{ r = 2780, lat = 380, h = 280, radius = 280, name = "수정 왕관 봉" },
				{ r = 2200, lat = 580, h = 120, radius = 150 }, -- 수정 동굴 언덕(굴이 이 속으로 들어간다)
			},
			mesas = {},
			-- 큰 동굴 입구(Terrain 파내기): 언덕 발치 입 → 안쪽 방(수정 군집). 굴 바닥은 평지 높이에서 시작해 완만히.
			caves = {
				{ pts = { { 2080, 470, 0 }, { 2150, 530, 0 }, { 2215, 585, 2 }, { 2255, 620, 2 } }, radius = 22, height = 30, chamber = { r = 2265, lat = 630, radius = 34, height = 36 } },
			},
		},
		tier3 = {
			hills = 0.7,
			peaks = {
				{ r = 1330, lat = -700, h = 150, radius = 190 }, -- 샘 언덕(강의 발원)
				{ r = 2860, lat = -460, h = 260, radius = 260, name = "파도 곶" },
				{ r = 2850, lat = 360, h = 240, radius = 240 },
			},
			-- 물살 강: 샘(언덕 중턱) → 계단 폭포 → 평지 강 → 계곡(물 사이 - 절벽 벽 · 기슭 계단) → 바다 만. level = 수면(바닥 기준).
			river = {
				pts = { { 1270, -620, 30 }, { 1340, -590, 12 }, { 1430, -565, -0.8 }, { 1650, -520, -0.8 }, { 1900, -470, -0.8 }, { 2150, -420, -0.8 }, { 2350, -330, -0.8 }, { 2500, -230, -0.8 } },
				width = 24, depth = 7, bankBlend = 16, spring = { radius = 16 },
				gorge = { from = 4, to = 5, wallHeight = 18, wallBlend = 5, exitEvery = 20 }, -- 점 4 → 5 구간 = 계곡(양옆 절벽 · 기슭 계단 20마다)
				flowSpeed = 10, -- 하류 방향 힘(클라가 준다 · 서버 상한 검사) - 걷기 16보다 약해 거슬러 오를 수 있다
			},
			-- 바다 만(길 끝 = 관문 뒤 · 수중 신전): 수면 level · 바닥 bed(심연 복귀선 위) · 먼바다 쪽 수로(channel - 설산 사이로 세계 밖까지 보인다)
			bay = { r = 2720, lat = -60, radius = 250, level = -0.8, bed = -18, shoreBlend = 40, channel = { width = 220, toR = 3200 } },
		},
		tier4 = {
			hills = 0.5,
			peaks = {
				{ r = 2800, lat = -420, h = 260, radius = 280, name = "태양 모래산" },
			},
			-- 사구: 바람 방향 dirDeg(구역 좌표) · 파장 · 높이 - 평탄 마스크 밖에서만 솟는다(사냥 지대 · 도로는 평지)
			dunes = { amp = 16, lambda = 150, dirDeg = 35, warp = 60 },
			-- 오아시스(선인장 밭 한가운데 - C 둥지): 작은 못
			lakes = { { r = 1480, lat = 560, radius = 16, level = -0.8, depth = 3, blend = 10 } },
		},
		tier5 = {
			hills = 1.2,
			peaks = {
				-- 흔들다리가 걸리는 큰 산 둘(가운데 협곡)
				{ r = 2010, lat = 790, h = 230, radius = 220, name = "천둥 쌍봉(북)" },
				{ r = 2330, lat = 470, h = 210, radius = 210, name = "천둥 쌍봉(남)" },
				{ r = 2820, lat = -300, h = 300, radius = 260 },
			},
			mesas = {
				{ r = 2140, lat = 665, radius = 24, level = 60, blend = 10, material = "Rock" }, -- 다리 북쪽 어깨(산 옆구리를 깎은 선반)
				{ r = 2245, lat = 565, radius = 24, level = 60, blend = 10, material = "Rock" }, -- 다리 남쪽 어깨(산길 끝)
			},
			-- 산길(남쪽 어깨까지 걸어서 - 경사 ≤ 18°)
			trails = { { pts = { { 1990, 420, 0 }, { 2080, 470, 18 }, { 2160, 530, 38 }, { 2230, 566, 60 } }, width = 12, blend = 14 } },
		},
		tier6 = {
			hills = 1.0,
			peaks = {
				{ r = 2150, lat = 560, h = 190, radius = 200, name = "거울 호수 산" },
				{ r = 2820, lat = -380, h = 320, radius = 300, name = "서리 왕관" },
			},
			mesas = {
				{ r = 2080, lat = 500, radius = 70, level = 55, blend = 18, material = "Snow" }, -- 산 중턱 호수 선반
				{ r = 1500, lat = -620, radius = 60, level = 40, blend = 5, material = "Glacier" }, -- 빙벽(빙하 혀 - 사방 절벽)
			},
			lakes = { { r = 2080, lat = 500, radius = 46, level = 54, depth = 8, blend = 14 } }, -- 산 중턱 호수(선반 위)
			trails = { { pts = { { 1850, 400, 0 }, { 1960, 470, 20 }, { 2020, 560, 40 }, { 2060, 540, 55 } }, width = 12, blend = 14 } },
		},
	},
}
