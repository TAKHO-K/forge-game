-- 구역별 지형 데이터(22-5, PRD 20.49 [5] 3단계). 지형은 코드가 아니라 여기 데이터로만 정의한다 -
-- 9구역을 각각 손으로 짜면 규칙이 바뀔 때마다 아홉 번 고쳐야 한다. 배치·규칙 검사·Part 생성은
-- 전부 server/ZoneTerrain.lua가 한다(이 파일에는 함수·부작용을 두지 않는다).
--
-- 좌표계: 모든 x/z는 그 구역 중심 기준 오프셋(stud), y는 구역 바닥 윗면 기준(기본 0). 구역 반너비는
-- WorldConfig.zoneSize.halfSizeStuds(128)이고, 몬스터 슬롯은 x,z ∈ {-64, 0, 64}의 3×3 격자다.
--
-- 배치 규칙(20.50이 20.49 [2]를 개정한 것 - ZoneTerrain이 배치 시점에 강제, 어기면 warn + 그 요소 생략):
--   도달원(슬롯 중심 반경 = 리쉬 38.4) 안에는 경사 ≤ 45°·단차 ≤ 2인 완만한 언덕·웅덩이·계단만.
--   급경사(> 45°)·수직 절벽(단차 > 2)·심연(바닥 없음)·키 큰 충돌 장식(높이 > 2)은 도달원 밖에만 -
--   즉 담장 안쪽 띠(|x| 또는 |z| > 64 + 38.4 = 102.4)와 셀 중심 포켓(반경 6.85)에만.
--   높이차 상한 8을 넘는 지형이 도달원 안에 있으면 어그로가 끊기므로 그것도 위반이다.
--
-- 요소 종류(kind)와 필드 - 자세한 기하는 ZoneTerrain.lua 각 expand 함수 주석:
--   hill     { x, z, top = {w, d}, height, run, rotation?, surface }        평평한 정상 + 사면 4 + 모서리 4 (9파트)
--   pit      { x, z, bottom = {w, d}, depth, run, surface, rampSurface }     바닥을 뚫고 내려가는 대야꼴 (5파트)
--   terrace  { x, z, w, d, height, stairsSide, stepDepth?, surface, stairSurface }  단 + 한쪽 계단 (1 + 단수-1 파트)
--   hut      { x, z, w, d, wallHeight, roofHeight, rotation?, wallSurface, roofSurface, trimSurface }  (10파트, 못 들어감)
--   tree     { x, z, y?, trunkHeight, trunkDiameter, canopyDiameter, trunkSurface, canopySurface,
--              canopyStyle? = "ball"(기본, 2파트·528삼각형) | "cube"(22-6, 상자 2·24삼각형), trunkShape? = "cylinder" | "box", rotation? }
--   strip    { points = {{x,z},...}, width, thickness?, y?, surface, collide?, ground? }  꺾은선 띠(개울·흙길·성벽, 22-6) - 마디당 1파트
--   box / ball / cylinder / wedge  원시 도형 { x, z, y?, size, rotation?, surface, collide?, ground?, snap?, sink?, tallDir? }
--   hole     { x, z, w, d }  바닥에 구멍(심연) - 도달원 안이면 항상 위반
--   scatter  { seed, count, region = {x, z, w, d}, exclude = {rect...}, template = <원시 도형> }  결정론적 흩뿌리기
--
-- 재질(surface)은 아래 surfaces 표의 이름으로만 참조한다. 커스텀 텍스처가 오면 이 표의 항목에
-- textureId(+ studsPerTile)만 채우면 그 재질을 쓰는 모든 파트에 한 번에 붙는다 - 요소 데이터는 안 바뀐다.

local surfaces = {
	-- 이름 = { material = 로블록스 기본 Material 이름, color = {r,g,b}, textureId = "rbxassetid://..."(선택),
	--          studsPerTile = 타일 크기(텍스처 있을 때), faces = {"Top", ...}(기본 Top만) }
	grass = { material = "Grass", color = { 106, 150, 78 } },
	grassDark = { material = "Grass", color = { 84, 128, 66 } },
	dirt = { material = "Ground", color = { 128, 104, 78 } },
	dirtPath = { material = "Ground", color = { 146, 124, 92 } },
	rock = { material = "Slate", color = { 118, 118, 112 } },
	rockDark = { material = "Slate", color = { 92, 94, 92 } },
	pebble = { material = "Cobblestone", color = { 132, 128, 120 } },
	wood = { material = "WoodPlanks", color = { 156, 118, 74 } },
	woodDark = { material = "Wood", color = { 94, 68, 42 } },
	roof = { material = "Slate", color = { 122, 74, 58 } },
	bark = { material = "Wood", color = { 106, 78, 52 } },
	leaves = { material = "Grass", color = { 78, 132, 62 } },
	flowerPink = { material = "SmoothPlastic", color = { 232, 128, 168 } },
	flowerYellow = { material = "SmoothPlastic", color = { 240, 208, 88 } },
	-- 22-6 고블린 숲. 물은 Terrain Water가 아니라 반투명 Part(20.53 후속 판단, PRD 20.55 [1](다)) -
	-- transparency/friction은 ZoneTerrain.applySurface가 읽는다. 텍스처가 오면 textureId만 채운다.
	forestLeaves = { material = "Grass", color = { 62, 118, 54 } },
	forestLeavesLight = { material = "Grass", color = { 92, 150, 66 } },
	forestBark = { material = "Wood", color = { 92, 66, 44 } },
	mountainRock = { material = "Slate", color = { 104, 100, 96 } },
	mountainGrass = { material = "Grass", color = { 72, 114, 58 } },
	water = { material = "SmoothPlastic", color = { 72, 142, 204 }, transparency = 0.42 },
	waterFoam = { material = "SmoothPlastic", color = { 220, 240, 250 }, transparency = 0.25 },
	-- 워터슬라이드 표면: 마찰 0.02(기본 0.3). 45°보다 급해 Humanoid가 서지 못하고 미끄러진다(TerrainServer의
	-- MaxSlopeAngle 45°) - 별도 힘 없이 엔진 미끄러짐 + 저마찰만으로 "탄다".
	slide = { material = "SmoothPlastic", color = { 96, 176, 228 }, transparency = 0.12, friction = 0.02 },
	mushroomRed = { material = "SmoothPlastic", color = { 204, 62, 52 } },
	tentCloth = { material = "Fabric", color = { 122, 92, 62 } },
	totem = { material = "Wood", color = { 120, 72, 40 } },
	flame = { material = "Neon", color = { 255, 140, 40 } },
	-- 22-6 리스폰 마을.
	plaza = { material = "Cobblestone", color = { 172, 162, 146 } },
	-- 광장 문양(20.51 [6] 발주 T22) 자리 - 데칼이 오면 textureId를 채운다. 원반(눕힌 원기둥)의 윗면은 local +X(Right).
	plazaMark = { material = "SmoothPlastic", color = { 226, 216, 190 }, faces = { "Right" } },
	stoneWall = { material = "Concrete", color = { 150, 146, 136 } },
	stonePost = { material = "Slate", color = { 122, 118, 112 } },
	lampPost = { material = "Metal", color = { 62, 62, 68 } },
	lamp = { material = "Neon", color = { 255, 222, 150 } },
	barrel = { material = "Wood", color = { 122, 86, 52 } },
	stallRed = { material = "Fabric", color = { 204, 82, 72 } },
	stallBlue = { material = "Fabric", color = { 82, 122, 204 } },
	wellStone = { material = "Cobblestone", color = { 142, 136, 126 } },
}

-- tier1 슬라임 초원: 넓은 잔디밭 + 완만한 언덕 3 + 움푹 파인 곳 3 + 북쪽 단·남서 전망대(계단) +
-- 오두막 1 + 나무 4 + 바위·잔돌·꽃. 언덕·웅덩이는 도달원 안(슬롯 사이 셀 중심 ±32)에 두어 몬스터가
-- 추격 중 실제로 오르내리게 하고, 급경사(단·전망대 절벽)·오두막·바위는 띠(|x|,|z| > 102.4)에만 둔다.
local tier1 = {
	floorSurface = "grass",
	features = {
		-- ── 도달원 안: 완만한 높낮이(경사 ≤ 45°) ──
		{ kind = "hill", x = 32, z = -32, top = { 16, 16 }, height = 3, run = 10, surface = "grassDark" }, -- 16.7°
		{ kind = "hill", x = -32, z = 32, top = { 12, 12 }, height = 4.5, run = 9, rotation = 15, surface = "grassDark" }, -- 26.6°
		{ kind = "hill", x = -96, z = 0, top = { 12, 30 }, height = 2, run = 12, surface = "grassDark" }, -- 9.5°, 서쪽 완만한 둔덕(띠까지 걸침)
		{ kind = "pit", x = 32, z = 32, bottom = { 10, 10 }, depth = 2, run = 6, surface = "dirt", rampSurface = "grassDark" }, -- 18.4°
		{ kind = "pit", x = -32, z = -32, bottom = { 8, 8 }, depth = 1.5, run = 5, surface = "dirt", rampSurface = "grassDark" }, -- 16.7°
		{ kind = "pit", x = 0, z = -96, bottom = { 6, 6 }, depth = 1.2, run = 5, surface = "dirt", rampSurface = "grassDark" }, -- 13.5°, 남쪽 슬롯 아래
		-- 입구 쪽 흙길(비충돌 얇은 판 - 바닥 위 0.1, 시각 전용)
		{ kind = "box", x = 84, z = 0, y = 0.1, size = { 88, 0.2, 8 }, surface = "dirtPath", collide = false },

		-- ── 띠(도달원 밖): 급경사·절벽·구조물 ──
		-- 북쪽 단(높이 4, 계단은 남쪽으로 내려온다 - 계단 자체는 단차 2라 도달원에 걸쳐도 된다)
		{ kind = "terrace", x = -60, z = 116, w = 40, d = 20, height = 4, stairsSide = "-z", stepDepth = 3, surface = "grassDark", stairSurface = "rock" },
		-- 남서 전망대(높이 6 - 상한 8 아래, 동쪽으로 계단). 절벽 세 면은 전부 도달원 밖.
		{ kind = "terrace", x = -110, z = -110, w = 28, d = 28, height = 6, stairsSide = "+x", stepDepth = 3, surface = "grassDark", stairSurface = "rock" },
		-- 오두막(북서 모퉁이, 못 들어간다 - 아래 주석)
		{ kind = "hut", x = -112, z = 112, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = 30, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		-- 나무
		{ kind = "tree", x = -98, z = 100, trunkHeight = 9, trunkDiameter = 1.6, canopyDiameter = 10, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = 112, z = 112, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = 116, z = -100, trunkHeight = 8, trunkDiameter = 1.4, canopyDiameter = 9, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = -20, z = -116, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, trunkSurface = "bark", canopySurface = "leaves" },
		-- 중형 바위(충돌, 높이 3 > 단차 2 → 띠에만)
		{ kind = "box", x = 112, z = -70, size = { 4, 3, 4 }, rotation = 20, surface = "rock" },
		{ kind = "box", x = 114, z = 88, size = { 5, 3.5, 4 }, rotation = -35, surface = "rockDark" },
		{ kind = "box", x = -116, z = 60, size = { 4, 2.6, 3 }, rotation = 50, surface = "rock" },
		{ kind = "box", x = 24, z = 118, size = { 4, 3, 4 }, rotation = 10, surface = "rockDark" },
		{ kind = "box", x = -48, z = -118, size = { 3.5, 2.8, 3.5 }, rotation = 40, surface = "rock" },
		{ kind = "box", x = 108, z = -114, size = { 6, 4, 5 }, rotation = 25, surface = "rockDark" },
		{ kind = "box", x = 100, z = -120, size = { 3, 2.4, 3 }, rotation = -15, surface = "rock" },

		-- ── 어디든(비충돌·낮음): 잔돌·꽃 - 지면에 스냅 ──
		{ kind = "scatter", seed = 101, count = 40, region = { x = 0, z = 0, w = 240, d = 240 },
			exclude = { { x = -112, z = 112, w = 22, d = 22 }, { x = 84, z = 0, w = 88, d = 8 } },
			template = { kind = "ball", size = { 0.8, 1.6 }, sink = 0.35, surface = "pebble", collide = false, rotation = "random" } },
		{ kind = "scatter", seed = 202, count = 16, region = { x = 0, z = 0, w = 220, d = 220 },
			exclude = { { x = -112, z = 112, w = 22, d = 22 }, { x = 84, z = 0, w = 88, d = 8 } },
			template = { kind = "box", size = { 0.6, 0.6, 0.6 }, sink = 0.1, surface = "flowerPink", collide = false, rotation = "random" } },
		{ kind = "scatter", seed = 303, count = 16, region = { x = 0, z = 0, w = 220, d = 220 },
			exclude = { { x = -112, z = 112, w = 22, d = 22 }, { x = 84, z = 0, w = 88, d = 8 } },
			template = { kind = "box", size = { 0.6, 0.6, 0.6 }, sink = 0.1, surface = "flowerYellow", collide = false, rotation = "random" } },
	},
}

-- ═══ tier2 고블린 숲(22-6) ═══
-- 테마: 북쪽 띠(z ≥ 104)에 산(계단식 4층, 정상 16) + 정상에서 떨어지는 폭포·개울·연못 + 동쪽 끝 워터슬라이드,
-- 사냥 바닥은 두 층 - 아래 숲 바닥(y 0, 슬롯 6)과 북쪽 초원 단(y 6, 슬롯 3, 언덕이라 사면 26.6°로 오르내린다).
-- 나무는 띠와 셀 포켓에만(줄기가 충돌 장애물이라 도달원 안은 규칙 위반) - 상한 40그루(PRD 20.55 [1](가)).
--
-- 워터슬라이드 판단(20.55 [1](나)): 정상·슬라이드·오르는 경사로가 전부 띠(몬스터가 리쉬로 못 오는 곳)에 있고
-- 슬라이드는 48.8°라 아래에서 위로는 못 오른다 → "몬스터를 떼어내는 새 도망 경로"가 아니다. 착지(z 108 → 슬라이드
-- 연못 → 사냥 바닥 가장자리)는 슬롯 (64,64) 도달원 바로 밖이라 내려가면 곧 전투다. 몬스터는 플레이어가 띠로
-- 들어가면 리쉬 초과, 슬라이드 중간(높이 8 초과)이면 sameLayer 실패로 복귀한다(MonsterAI, 코드 변경 없음).
local tier2 = {
	floorSurface = "grass",
	features = {
		-- ── 초원 단(도달원 안·경사 26.6°·높이 6 ≤ 8): 북쪽 슬롯 3개가 이 위에 선다 ──
		{ kind = "hill", x = 0, z = 64, top = { 160, 40 }, height = 6, run = 12, surface = "mountainGrass" },

		-- ── 산(북쪽 띠 z ≥ 104): 층 4(각 4stud) + 동쪽 끝 절벽(슬라이드 배경) ──
		{ kind = "box", x = -15, z = 116, y = 0, size = { 170, 4, 24 }, surface = "mountainRock", ground = true },
		{ kind = "box", x = -15, z = 119, y = 4, size = { 170, 4, 18 }, surface = "mountainGrass", ground = true },
		{ kind = "box", x = -15, z = 122, y = 8, size = { 170, 4, 12 }, surface = "mountainRock", ground = true },
		{ kind = "box", x = 0, z = 125, y = 12, size = { 200, 4, 6 }, surface = "mountainGrass", ground = true },
		{ kind = "box", x = 85, z = 125, y = 0, size = { 30, 12, 6 }, surface = "mountainRock", ground = true },
		-- 오르는 경사로(38.7°, 각 4 높이·5 run) - x=30 열에 4단. 높은 면(+z)이 다음 층 앞면에 붙는다.
		{ kind = "wedge", x = 30, z = 101.5, y = 0, size = { 6, 4, 5 }, tallDir = "+z", surface = "mountainGrass", ground = true },
		{ kind = "wedge", x = 30, z = 107.5, y = 4, size = { 6, 4, 5 }, tallDir = "+z", surface = "mountainGrass", ground = true },
		{ kind = "wedge", x = 30, z = 113.5, y = 8, size = { 6, 4, 5 }, tallDir = "+z", surface = "mountainGrass", ground = true },
		{ kind = "wedge", x = 30, z = 119.5, y = 12, size = { 6, 4, 5 }, tallDir = "+z", surface = "mountainGrass", ground = true },

		-- ── 워터슬라이드(동쪽 끝, 정상 16 → 바닥, run 14 = 48.8°) + 착지 연못 ──
		{ kind = "wedge", x = 80, z = 115, y = 0, size = { 8, 16, 14 }, tallDir = "+z", surface = "slide", ground = true },
		{ kind = "pit", x = 80, z = 99, bottom = { 8, 6 }, depth = 1, run = 3, surface = "dirt", rampSurface = "mountainGrass" },
		{ kind = "box", x = 80, z = 99, y = -0.85, size = { 11, 0.3, 9 }, surface = "water", collide = false },

		-- ── 폭포(x=−60, 층 앞면마다 물판) + 층 웅덩이 + 기슭 연못 ──
		{ kind = "box", x = -60, z = 121.7, y = 12, size = { 6, 4, 0.5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 115.7, y = 8, size = { 6, 4, 0.5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 109.7, y = 4, size = { 6, 4, 0.5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 103.7, y = 0, size = { 6, 4, 0.5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 119, y = 12.05, size = { 7, 0.25, 5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 113, y = 8.05, size = { 7, 0.25, 5 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 107, y = 4.05, size = { 7, 0.25, 5 }, surface = "water", collide = false },
		{ kind = "pit", x = -60, z = 98, bottom = { 8, 4 }, depth = 1, run = 3, surface = "dirt", rampSurface = "mountainGrass" },
		{ kind = "box", x = -60, z = 98, y = -0.85, size = { 11, 0.3, 7 }, surface = "water", collide = false },
		{ kind = "box", x = -60, z = 101, y = 0.05, size = { 7, 0.2, 3 }, surface = "waterFoam", collide = false },
		-- 개울: 기슭 연못 → 서쪽 띠를 따라 남하 → 숲 바닥 연못(셀 포켓 (−32,−32) 자리)
		{ kind = "strip", points = { { -60, 96 }, { -100, 100 }, { -110, 90 }, { -110, -20 }, { -70, -30 }, { -40, -32 } }, width = 3, y = 0.08, surface = "water" },
		{ kind = "pit", x = -32, z = -32, bottom = { 10, 8 }, depth = 1.2, run = 5, surface = "dirt", rampSurface = "grassDark" }, -- 13.5°
		{ kind = "box", x = -32, z = -32, y = -1.05, size = { 15.5, 0.3, 13.5 }, surface = "water", collide = false },

		-- ── 입구 흙길(서쪽 입구 → 숲 바닥) ──
		{ kind = "strip", points = { { -124, 0 }, { -70, 0 } }, width = 6, y = 0.1, surface = "dirtPath" },

		-- ── 나무 40그루(상한) - 띠 + 포켓 3. 서쪽 띠는 입구(z −14~14)를 비운다 ──
		-- 서쪽 띠 x=−118 (10)
		{ kind = "tree", x = -118, z = -112, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -116, z = -98, trunkHeight = 9, trunkDiameter = 1.6, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 35, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = -119, z = -84, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -117, z = -70, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -119, z = -56, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 40, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = -116, z = -42, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 5, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -118, z = -28, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 25, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -118, z = 28, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 15, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = -117, z = 42, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -119, z = 56, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		-- 북서·북동 모퉁이(산 옆) (4)
		{ kind = "tree", x = -114, z = 112, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -117, z = 124, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 45, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 114, z = 110, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 117, z = 123, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		-- 동쪽 띠 x=116 (14)
		{ kind = "tree", x = 116, z = -112, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 118, z = -98, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 115, z = -84, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 40, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 117, z = -70, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 118, z = -56, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 115, z = -42, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 5, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 117, z = -28, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 25, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 118, z = -14, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 15, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 116, z = 0, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 35, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 115, z = 14, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 118, z = 28, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 116, z = 42, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 45, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 117, z = 56, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 115, z = 70, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		-- 남쪽 띠 z=−116 (9) - 가운데는 고블린 야영지(천막 2·모닥불·토템)
		{ kind = "tree", x = -96, z = -116, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 15, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -80, z = -118, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 40, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = -64, z = -115, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -48, z = -117, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 25, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = -32, z = -116, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 30, z = -117, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 35, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 70, z = -115, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 5, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 86, z = -118, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = 100, z = -116, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 45, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		-- 셀 포켓(반경 6.85) (3) - (−32,−32)는 연못
		{ kind = "tree", x = 32, z = 32, trunkHeight = 12, trunkDiameter = 1.8, canopyDiameter = 12, canopyStyle = "cube", trunkShape = "box", rotation = 15, trunkSurface = "forestBark", canopySurface = "forestLeaves" },
		{ kind = "tree", x = 32, z = -32, trunkHeight = 11, trunkDiameter = 1.8, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "forestBark", canopySurface = "forestLeavesLight" },
		{ kind = "tree", x = -32, z = 32, trunkHeight = 13, trunkDiameter = 2, canopyDiameter = 13, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "forestBark", canopySurface = "forestLeaves" },

		-- ── 고블린 야영지(남쪽 띠): 천막 2(쐐기 2개 A자) · 모닥불 · 토템 ──
		{ kind = "wedge", x = -12, z = -114, size = { 8, 5, 4 }, tallDir = "+z", surface = "tentCloth" },
		{ kind = "wedge", x = -12, z = -110, size = { 8, 5, 4 }, tallDir = "-z", surface = "tentCloth" },
		{ kind = "wedge", x = 12, z = -114, size = { 8, 5, 4 }, tallDir = "+z", surface = "tentCloth" },
		{ kind = "wedge", x = 12, z = -110, size = { 8, 5, 4 }, tallDir = "-z", surface = "tentCloth" },
		{ kind = "box", x = 0, z = -110, size = { 2.6, 0.6, 0.6 }, rotation = 0, surface = "woodDark", collide = false },
		{ kind = "box", x = 0, z = -110, size = { 2.6, 0.6, 0.6 }, rotation = 60, surface = "woodDark", collide = false },
		{ kind = "box", x = 0, z = -110, size = { 2.6, 0.6, 0.6 }, rotation = 120, surface = "woodDark", collide = false },
		{ kind = "box", x = 0, z = -110, y = 0.5, size = { 1, 1.4, 1 }, rotation = 45, surface = "flame", collide = false },
		{ kind = "box", x = 52, z = -112, size = { 1.5, 6, 1.5 }, surface = "totem" },
		{ kind = "box", x = 52, z = -112, y = 6, size = { 2.2, 1.6, 2.2 }, surface = "totem", collide = false },

		-- ── 바위(띠) ──
		{ kind = "box", x = -124, z = 76, size = { 4, 3, 4 }, rotation = 20, surface = "rock" },
		{ kind = "box", x = 122, z = 88, size = { 5, 3.5, 4 }, rotation = -30, surface = "rockDark" },
		{ kind = "box", x = -122, z = -124, size = { 4, 2.6, 3 }, rotation = 50, surface = "rock" },
		{ kind = "box", x = 120, z = -122, size = { 4, 3, 4 }, rotation = 10, surface = "rockDark" },
		{ kind = "box", x = -70, z = -124, size = { 3.5, 2.8, 3.5 }, rotation = 40, surface = "rock" },
		{ kind = "box", x = 60, z = -124, size = { 6, 4, 5 }, rotation = 25, surface = "rockDark" },

		-- ── 버섯(비충돌·낮음, 지면 스냅 - 산 위에도 앉는다) ──
		{ kind = "scatter", seed = 404, count = 14, region = { x = 0, z = -20, w = 230, d = 200 },
			exclude = { { x = 80, z = 108, w = 16, d = 30 }, { x = -127, z = 0, w = 40, d = 12 } },
			template = { kind = "box", size = { 1.2, 1.0, 1.2 }, sink = 0.1, surface = "mushroomRed", collide = false, rotation = "random" } },
	},
}

-- ═══ 리스폰 마을(spawn, 5번 칸, 22-6) ═══
-- 몬스터가 없어 도달원 규칙이 없다(reachCircles가 빈 목록). 이미 있는 것: 스폰(중심), 포탈 6개(HuntingGround가
-- 중심에서 각 tier 방향 50stud에 둔다 - 동/서/대각 4), 강화대는 북쪽(2번 강화소 구역). 그래서 광장은 반경 62 원반,
-- 길은 4방 문 + 4모서리 출구로, 집은 광장 밖 반경 88 고리에, 낮은 성벽(높이 3)은 ±112에 문(폭 28)·모서리 틈(32)을 둔다.
local spawn = {
	floorSurface = "grass",
	features = {
		-- 광장 원반 + 문양 자리(20.51 [6] T22 데칼 - surfaces.plazaMark.textureId)
		{ kind = "cylinder", x = 0, z = 0, y = 0.05, height = 0.2, diameter = 124, surface = "plaza", collide = false },
		{ kind = "cylinder", x = 0, z = 0, y = 0.22, height = 0.15, diameter = 22, surface = "plazaMark", collide = false },
		-- 길: 4방 문으로(폭 8) + 4모서리 출구로(폭 5)
		{ kind = "strip", points = { { 0, 60 }, { 0, 122 } }, width = 8, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { 0, -60 }, { 0, -122 } }, width = 8, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { 60, 0 }, { 122, 0 } }, width = 8, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { -60, 0 }, { -122, 0 } }, width = 8, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { 44, 44 }, { 108, 108 } }, width = 5, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { -44, 44 }, { -108, 108 } }, width = 5, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { 44, -44 }, { 108, -108 } }, width = 5, y = 0.1, surface = "dirtPath" },
		{ kind = "strip", points = { { -44, -44 }, { -108, -108 } }, width = 5, y = 0.1, surface = "dirtPath" },
		-- 낮은 성벽(높이 3, 두께 2): 변마다 2조각, 가운데 문 28·모서리 틈 32. 기둥은 조각 끝마다.
		{ kind = "strip", points = { { -96, -112 }, { -14, -112 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { 14, -112 }, { 96, -112 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { -96, 112 }, { -14, 112 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { 14, 112 }, { 96, 112 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { -112, -96 }, { -112, -14 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { -112, 14 }, { -112, 96 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { 112, -96 }, { 112, -14 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "strip", points = { { 112, 14 }, { 112, 96 } }, width = 2, thickness = 3, surface = "stoneWall", collide = true },
		{ kind = "box", x = -96, z = -112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -14, z = -112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 14, z = -112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 96, z = -112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -96, z = 112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -14, z = 112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 14, z = 112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 96, z = 112, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -112, z = -96, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -112, z = -14, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -112, z = 14, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = -112, z = 96, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 112, z = -96, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 112, z = -14, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 112, z = 14, size = { 3, 4.5, 3 }, surface = "stonePost" },
		{ kind = "box", x = 112, z = 96, size = { 3, 4.5, 3 }, surface = "stonePost" },
		-- 집 6채(반경 88 고리, 문이 광장을 향한다: rotation = 90 − 각도). 못 들어간다(hut 주석 - 카메라).
		{ kind = "hut", x = 76.2, z = 44, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = 60, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		{ kind = "hut", x = 22.8, z = 85, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = 15, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		{ kind = "hut", x = -76.2, z = 44, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = -60, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		{ kind = "hut", x = -76.2, z = -44, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = -120, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		{ kind = "hut", x = -22.8, z = -85, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = -165, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		{ kind = "hut", x = 76.2, z = -44, w = 14, d = 12, wallHeight = 6, roofHeight = 4, rotation = 120, wallSurface = "wood", roofSurface = "roof", trimSurface = "woodDark" },
		-- 가로등 4(기둥 + 네온 상자)
		{ kind = "box", x = 8, z = 58, size = { 0.5, 7, 0.5 }, surface = "lampPost" },
		{ kind = "box", x = 8, z = 58, y = 7, size = { 1.4, 1.4, 1.4 }, surface = "lamp", collide = false },
		{ kind = "box", x = -8, z = -58, size = { 0.5, 7, 0.5 }, surface = "lampPost" },
		{ kind = "box", x = -8, z = -58, y = 7, size = { 1.4, 1.4, 1.4 }, surface = "lamp", collide = false },
		{ kind = "box", x = 58, z = -8, size = { 0.5, 7, 0.5 }, surface = "lampPost" },
		{ kind = "box", x = 58, z = -8, y = 7, size = { 1.4, 1.4, 1.4 }, surface = "lamp", collide = false },
		{ kind = "box", x = -58, z = 8, size = { 0.5, 7, 0.5 }, surface = "lampPost" },
		{ kind = "box", x = -58, z = 8, y = 7, size = { 1.4, 1.4, 1.4 }, surface = "lamp", collide = false },
		-- 우물(광장 남쪽): 돌 원기둥 + 기둥 2 + 지붕 쐐기 2
		{ kind = "cylinder", x = 0, z = -30, height = 3, diameter = 5, surface = "wellStone" },
		{ kind = "box", x = -2.4, z = -30, size = { 0.5, 7, 0.5 }, surface = "woodDark" },
		{ kind = "box", x = 2.4, z = -30, size = { 0.5, 7, 0.5 }, surface = "woodDark" },
		{ kind = "wedge", x = 0, z = -31.6, y = 7, size = { 6.5, 1.6, 3.2 }, tallDir = "+z", surface = "roof", collide = false },
		{ kind = "wedge", x = 0, z = -28.4, y = 7, size = { 6.5, 1.6, 3.2 }, tallDir = "-z", surface = "roof", collide = false },
		-- 노점 2(광장 북쪽): 천막 지붕 + 기둥 2 + 판매대
		{ kind = "box", x = -12, z = 30, y = 5, size = { 8, 0.4, 5 }, surface = "stallRed", collide = false },
		{ kind = "box", x = -15.5, z = 30, size = { 0.5, 5, 0.5 }, surface = "woodDark" },
		{ kind = "box", x = -8.5, z = 30, size = { 0.5, 5, 0.5 }, surface = "woodDark" },
		{ kind = "box", x = -12, z = 28.5, size = { 8, 2.5, 2 }, surface = "wood" },
		{ kind = "box", x = 12, z = 30, y = 5, size = { 8, 0.4, 5 }, surface = "stallBlue", collide = false },
		{ kind = "box", x = 8.5, z = 30, size = { 0.5, 5, 0.5 }, surface = "woodDark" },
		{ kind = "box", x = 15.5, z = 30, size = { 0.5, 5, 0.5 }, surface = "woodDark" },
		{ kind = "box", x = 12, z = 28.5, size = { 8, 2.5, 2 }, surface = "wood" },
		-- 통 6(집 옆)
		{ kind = "cylinder", x = 66, z = 52, height = 2.5, diameter = 2, surface = "barrel" },
		{ kind = "cylinder", x = 68.5, z = 53, height = 2.5, diameter = 2, surface = "barrel" },
		{ kind = "cylinder", x = -66, z = -52, height = 2.5, diameter = 2, surface = "barrel" },
		{ kind = "cylinder", x = -68.5, z = -53, height = 2.5, diameter = 2, surface = "barrel" },
		{ kind = "cylinder", x = 32, z = 86, height = 2.5, diameter = 2, surface = "barrel" },
		{ kind = "cylinder", x = -32, z = -86, height = 2.5, diameter = 2, surface = "barrel" },
		-- 마을 나무 8(상자 수관)
		{ kind = "tree", x = 100, z = 22, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 10, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = 100, z = -22, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 30, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = -100, z = 22, trunkHeight = 11, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 0, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = -100, z = -22, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 40, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = 22, z = 100, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 20, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = -22, z = 100, trunkHeight = 9, trunkDiameter = 1.5, canopyDiameter = 10, canopyStyle = "cube", trunkShape = "box", rotation = 15, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = 22, z = -100, trunkHeight = 11, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 35, trunkSurface = "bark", canopySurface = "leaves" },
		{ kind = "tree", x = -22, z = -100, trunkHeight = 10, trunkDiameter = 1.6, canopyDiameter = 11, canopyStyle = "cube", trunkShape = "box", rotation = 5, trunkSurface = "bark", canopySurface = "leaves" },
		-- 꽃(광장·집 밖)
		{ kind = "scatter", seed = 505, count = 24, region = { x = 0, z = 0, w = 210, d = 210 },
			exclude = { { x = 0, z = 0, w = 126, d = 126 } },
			template = { kind = "box", size = { 0.6, 0.6, 0.6 }, sink = 0.1, surface = "flowerYellow", collide = false, rotation = "random" } },
	},
}

-- 맵 가장자리 바위 능선(22-5 지시 - 구역 담장 대신 "맵 밖으로만 못 나가게"). 보이지 않는 장벽
-- (HuntingGround MapBarrier)이 실제로 막고, 이 능선은 "여기가 끝"을 자연스럽게 보여 주는 장식이다.
-- 맵 한 변(WorldConfig.superGrid.mapSizeStuds)을 따라 segmentLength 간격으로 높이·폭·회전·색을
-- 조금씩 다르게 한 바위 블록을 세우고(균일하면 담장처럼 읽힌다 - 첫 스크린샷에서 확인), 그 안쪽에
-- 둥근 바위(boulder)를 드문드문 굴려 둔다.
local perimeter = {
	seed = 7,
	segmentLength = 16,
	widthRange = { 6, 12 },
	heightRange = { 3, 10 },
	yawJitterDegrees = 12,
	insetJitter = 4,
	colorJitter = 14,
	surface = "rockDark",
	-- 24-5 성능 예산(PRD 20.63 [3] 16인 화면 삼각형 초과) - 줄일 순서 1번(20.55 [3]).
	-- 실측(Studio RenderBreakdown, 부품 단위 재검증): 둥근 바위(Ball 432tri)가 전체 지형
	-- 69,210 tri 중 40,608(59%)로 단일 최대 소비원이었다 - every 2→4로 개수를 절반 근처로
	-- 줄인다(94개 → 실측 후 정확한 값은 부팅 로그).
	boulder = { every = 4, diameterRange = { 3, 6 }, inset = 9, surface = "rock" },
}

return {
	surfaces = surfaces,
	zones = {
		tier1 = tier1,
		tier2 = tier2,
		spawn = spawn,
	},
	perimeter = perimeter,
}
