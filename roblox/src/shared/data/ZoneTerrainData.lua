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
--   tree     { x, z, trunkHeight, trunkDiameter, canopyDiameter, trunkSurface, canopySurface }  (2파트)
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
	boulder = { every = 2, diameterRange = { 3, 6 }, inset = 9, surface = "rock" },
}

return {
	surfaces = surfaces,
	zones = {
		tier1 = tier1,
	},
	perimeter = perimeter,
}
