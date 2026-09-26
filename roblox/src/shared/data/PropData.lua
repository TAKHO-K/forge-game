-- M1-4 소품 라이브러리 틀(카툰 대비 구조 - docs/art/asset-pipeline.md). 맵에는 소품 이름 · 위치 · 회전 · 크기만 둔다(shared/PropKit.place) -
-- 서버가 이 틀로 ReplicatedStorage.Assets.Props.<이름> 모델을 한 번 만들고(server/PropLibrary) 배치마다 복제한다. 라이브러리 모델 하나를 카툰 모델로 바꾸면 전체가 바뀐다.
-- 틀 = 로컬 좌표(원점 = 바닥 가운데 · −Z = 앞 · +Y = 위) 도형 목록. 틀의 크기 · 충돌 = **계약**(판정 · 검사 · 둥지 보호 부피 침범 검사가 이 도형을 읽는다 - 교체 모델도 같은 발자국을 지킨다).
-- 도형: n = 이름 · s = 크기 { x, y, z } · p = 위치 { x, y, z } · r = 회전(도) { x, y, z } · c = 색({ r, g, b } 또는 지형 재질 이름 - TerrainGenData.materialColors) ·
--   m = 재질 · sh = "Block" | "Ball" | "Cylinder" | "Wedge" | "Truss" · col = 충돌(false면 장식 - 쿼리 · 터치 · 그림자 끔) · tr = 투명도 · mesh = SpecialMesh 종류 · a = Attribute 표 · dk = 색을 이만큼 어둡게(0 ~ 1).
-- 이름 규칙: <테마>_<종류>[_<변형>] - 테마 = T1 ~ T6 · Hub · Common(여러 구역 공용). 크기 배율은 배치 쪽(scale = 숫자 또는 { x, y, z } - 틀 로컬 축 기준).
local WOOD = { 142, 84, 58 }
local LEAF = { 88, 128, 70 }
local CRYSTAL = { 120, 230, 255 } -- 수정 여왕 관문 색(BossData)

return {
	folder = "Assets", -- ReplicatedStorage.Assets.Props
	-- 교체 모델 자리(Rojo 파일 · place): 같은 이름 모델이 있으면 틀 대신 그걸 라이브러리에 쓴다(server/PropLibrary)
	overrideFolders = { "Shared.PropModels" },
	templates = {
		-- ─── 옮긴 것(M1-3 이전 소품) ───
		T2_CrystalCluster = { -- 수정 군집(기울어진 기둥 5 · 통과) - WorldStructures 수정 · 굴 방
			parts = {
				{ n = "Crystal", s = { 1.6, 9, 1.6 }, p = { 0, 3.5, 0 }, c = CRYSTAL, m = "Glass", tr = 0.25, col = false },
				{ n = "Crystal", s = { 1.6, 6, 1.6 }, p = { 2.2, 1.9, 1.42 }, r = { 18, 20, 0 }, c = CRYSTAL, m = "Glass", tr = 0.25, col = false },
				{ n = "Crystal", s = { 1.6, 5, 1.6 }, p = { -2, 1.39, 0.64 }, r = { -22, 50, 0 }, c = CRYSTAL, m = "Glass", tr = 0.25, col = false },
				{ n = "Crystal", s = { 1.6, 4.5, 1.6 }, p = { 0.8, 1.21, -1.88 }, r = { 15, -40, 0 }, c = CRYSTAL, m = "Glass", tr = 0.25, col = false },
				{ n = "Crystal", s = { 1.6, 3.5, 1.6 }, p = { -1.4, 0.73, -1.96 }, r = { -12, 130, 0 }, c = CRYSTAL, m = "Glass", tr = 0.25, col = false },
			},
		},
		T4_Cactus = { -- 선인장(높이 8 기준 - 배치가 y 배율로 6 ~ 11) · 몸통만 충돌 + Cactus 표시(피해는 서버가 위치 표로 잰다)
			parts = {
				{ n = "Cactus", s = { 9, 2.2, 2.2 }, p = { 0, 3.5, 0 }, r = { 0, 0, 90 }, c = "LeafyGrass", m = "LeafyGrass", sh = "Cylinder", a = { Cactus = true } },
				{ n = "CactusArm", s = { 2.2, 1.4, 1.4 }, p = { -1.6, 4.8, 0 }, c = "LeafyGrass", m = "LeafyGrass", col = false },
				{ n = "CactusArm", s = { 3, 1.4, 1.4 }, p = { -2.4, 6.4, 0 }, r = { 0, 0, 90 }, c = "LeafyGrass", m = "LeafyGrass", sh = "Cylinder", col = false },
				{ n = "CactusArm", s = { 2.2, 1.4, 1.4 }, p = { 1.6, 3.6, 0 }, c = "LeafyGrass", m = "LeafyGrass", col = false },
				{ n = "CactusArm", s = { 3, 1.4, 1.4 }, p = { 2.4, 5.2, 0 }, r = { 0, 0, 90 }, c = "LeafyGrass", m = "LeafyGrass", sh = "Cylinder", col = false },
			},
		},
		T1_RuinPillar = { -- 폐허 기둥(높이 16 · 지름 3.6 + 머리) - 열주
			parts = {
				{ n = "RuinPillar", s = { 16, 3.6, 3.6 }, p = { 0, 8, 0 }, r = { 0, 0, 90 }, c = "Limestone", m = "Limestone", sh = "Cylinder" },
				{ n = "RuinCapital", s = { 5.2, 1, 5.2 }, p = { 0, 16.5, 0 }, c = "Limestone", m = "Limestone" },
			},
		},
		T1_RuinPillarBroken = { -- 부러진 기둥(높이 8 기준 - y 배율)
			parts = { { n = "RuinPillar", s = { 8, 3.6, 3.6 }, p = { 0, 4, 0 }, r = { 0, 0, 90 }, c = "Limestone", m = "Limestone", sh = "Cylinder" } },
		},
		T1_RuinFallen = { -- 쓰러진 기둥(누운 원통 - 길이 14)
			parts = { { n = "RuinFallen", s = { 14, 3.6, 3.6 }, p = { 0, 1.8, 0 }, c = "Limestone", m = "Limestone", sh = "Cylinder" } },
		},
		T1_RuinBeam = { -- 들보 조각(길이 27)
			parts = { { n = "RuinBeam", s = { 27, 1.6, 3.6 }, p = { 0, 0.8, 0 }, c = "Limestone", m = "Limestone" } },
		},
		T1_RuinDais = { -- 낮은 단(78 × 26 · 윗면 1.2 - 밑 2는 땅속)
			parts = { { n = "RuinDais", s = { 78, 3.2, 26 }, p = { 0, -0.4, 0 }, c = "Limestone", m = "Limestone", dk = 0.3 } },
		},
		T1_Monolith = { -- 비석(10 × 10 · 높이 34 - 밑 2 땅속) - T1 랜드마크 고리
			parts = { { n = "Landmark", s = { 10, 36, 10 }, p = { 0, 16, 0 }, c = "Rock", m = "Rock", dk = 0.3 } },
		},
		T2_CrystalSpire = { -- 수정 첨탑(10 × 10 · 높이 130 기준 - y 배율) - T2 랜드마크
			parts = { { n = "Landmark", s = { 10, 132, 10 }, p = { 0, 64, 0 }, c = "Basalt", m = "Basalt", dk = 0.3 } },
		},
		T6_IceWallSlab = { -- 얼음 벽 판(40 × 10 · 높이 120) - T6 랜드마크
			parts = { { n = "Landmark", s = { 40, 122, 10 }, p = { 0, 59, 0 }, c = "Glacier", m = "Glacier", dk = 0.3 } },
		},
		Common_LeafClump = { -- 잎 뭉치(타원 · 통과) - 둥지 나무 · 줄기 속 방 · 채우기 나무
			parts = { { n = "Leaves", s = { 14, 9, 14 }, p = { 0, 4.5, 0 }, c = LEAF, m = "Grass", mesh = "Sphere", col = false } },
		},
		Common_Bird = { -- 앉은 새(몸 · 머리 - 비밀 둥지 환경 힌트)
			parts = {
				{ n = "Bird", s = { 1.2, 0.9, 1.6 }, p = { 0, 0.45, 0 }, c = { 90, 70, 60 }, mesh = "Sphere", col = false },
				{ n = "Bird", s = { 0.7, 0.7, 0.7 }, p = { 0, 0.95, -0.7 }, c = { 90, 70, 60 }, mesh = "Sphere", col = false },
			},
		},
		Common_Ladder = { -- 사다리(높이 10 기준 - y 배율 · TrussPart = 로블록스 기본 오르기 · 앞 = −Z 쪽에서 오른다). Climbable = 서버 높이 검사가 "오르는 중 = 서 있음"으로 인정하는 표시
			parts = {
				{ n = "LadderTruss", s = { 2, 10, 2 }, p = { 0, 5, 0 }, c = WOOD, m = "Wood", sh = "Truss", a = { Climbable = true } },
				{ n = "LadderRail", s = { 0.5, 10.6, 0.5 }, p = { -1.4, 5.3, -0.4 }, c = WOOD, m = "Wood", col = false },
				{ n = "LadderRail", s = { 0.5, 10.6, 0.5 }, p = { 1.4, 5.3, -0.4 }, c = WOOD, m = "Wood", col = false },
			},
		},
		Common_LadderLanding = { -- 사다리 꼭대기 발판(사다리 → 절벽 윗면 · 길이 6 기준 - z 배율 · 원점 = 사다리 꼭대기 · +Z = 절벽 쪽)
			parts = { { n = "LadderLanding", s = { 4, 1, 6 }, p = { 0, -0.5, 3 }, c = WOOD, m = "WoodPlanks" } },
		},

		-- ─── M1-4 빈 공간 채우기(구역 테마) ───
		Common_FallenLog = { -- 쓰러진 거목(누운 줄기 + 그루터기 · 밟고 넘는다)
			parts = {
				{ n = "Log", s = { 26, 4.4, 4.4 }, p = { 0, 2, 0 }, r = { 0, 0, 4 }, c = { 118, 84, 60 }, m = "Wood", sh = "Cylinder" },
				{ n = "Stump", s = { 3, 5, 5 }, p = { -15, 1.5, 0 }, r = { 0, 0, 90 }, c = { 96, 68, 50 }, m = "Wood", sh = "Cylinder" },
				{ n = "Branch", s = { 7, 1.2, 1.2 }, p = { 5, 4.6, 1.6 }, r = { 0, 30, 35 }, c = { 118, 84, 60 }, m = "Wood", col = false },
			},
		},
		Common_Tree = { -- 들판 나무(줄기 + 잎 뭉치 2 · 줄기만 충돌)
			parts = {
				{ n = "Trunk", s = { 14, 2.4, 2.4 }, p = { 0, 6, 0 }, r = { 0, 0, 90 }, c = WOOD, m = "Wood", sh = "Cylinder" },
				{ n = "Leaves", s = { 16, 11, 16 }, p = { 0, 15, 0 }, c = LEAF, m = "Grass", mesh = "Sphere", col = false },
				{ n = "Leaves", s = { 11, 8, 11 }, p = { 3, 20, -2 }, c = { 104, 146, 80 }, m = "Grass", mesh = "Sphere", col = false },
			},
		},
		Common_RuinWall = { -- 무너진 담 조각(높낮이 다른 블록 3)
			parts = {
				{ n = "RuinWall", s = { 10, 8, 2.4 }, p = { -6, 3, 0 }, c = "Limestone", m = "Limestone", dk = 0.15 },
				{ n = "RuinWall", s = { 6, 5, 2.4 }, p = { 2.5, 1.5, 0.2 }, r = { 0, 4, 0 }, c = "Limestone", m = "Limestone", dk = 0.15 },
				{ n = "RuinRubble", s = { 3, 2, 3 }, p = { 7.5, 0.5, 1.5 }, r = { 8, 25, 12 }, c = "Limestone", m = "Limestone", dk = 0.25 },
			},
		},
		-- T1 석조 평원
		T1_RockPillar = { -- 돌기둥(쌓인 돌 3 · 높이 20)
			parts = {
				{ n = "RockPillar", s = { 7, 9, 7 }, p = { 0, 3.5, 0 }, r = { 0, 12, 0 }, c = "Rock", m = "Rock" },
				{ n = "RockPillar", s = { 5.5, 8, 5.5 }, p = { 0.4, 11, 0.2 }, r = { 3, 40, 2 }, c = "Rock", m = "Rock", dk = 0.08 },
				{ n = "RockPillar", s = { 4.5, 5, 4.5 }, p = { 0.2, 17.2, 0.5 }, r = { -4, 70, 5 }, c = "Rock", m = "Rock" },
			},
		},
		T1_StoneArch = { -- 돌 아치(다리 2 + 윗돌 - 사이로 지나간다 · 폭 10 · 높이 16)
			parts = {
				{ n = "ArchLeg", s = { 4, 15, 5 }, p = { -7, 5.5, 0 }, r = { 0, 0, -4 }, c = "Rock", m = "Rock" },
				{ n = "ArchLeg", s = { 4, 14, 5 }, p = { 7, 5, 0 }, r = { 0, 0, 5 }, c = "Rock", m = "Rock", dk = 0.08 },
				{ n = "ArchTop", s = { 20, 4, 6 }, p = { 0, 14.5, 0 }, r = { 0, 0, 3 }, c = "Rock", m = "Rock" },
			},
		},
		T1_BalancedRock = { -- 균형 바위(가는 받침 위 큰 돌)
			parts = {
				{ n = "RockBase", s = { 5, 7, 5 }, p = { 0, 2.5, 0 }, r = { 0, 20, 0 }, c = "Rock", m = "Rock", dk = 0.1 },
				{ n = "RockTop", s = { 11, 7, 9 }, p = { 1, 9.2, 0 }, r = { 8, 35, -10 }, c = "Rock", m = "Rock" },
			},
		},
		T1_Boulder = { -- 바위 무더기(기울인 돌 3)
			parts = {
				{ n = "Boulder", s = { 8, 6, 7 }, p = { 0, 2, 0 }, r = { 10, 20, 8 }, c = "Rock", m = "Rock" },
				{ n = "Boulder", s = { 5, 4, 5 }, p = { 5, 1.2, 2 }, r = { -12, 60, 15 }, c = "Rock", m = "Rock", dk = 0.1 },
				{ n = "Boulder", s = { 3.5, 3, 3.5 }, p = { -4, 0.8, 3 }, r = { 20, 5, -10 }, c = "Rock", m = "Rock" },
			},
		},
		-- T2 수정 동굴
		T2_CrystalSpike = { -- 큰 수정 가시(높이 16 · 옆 작은 가시 2)
			parts = {
				{ n = "CrystalSpike", s = { 3.4, 16, 3.4 }, p = { 0, 7, 0 }, r = { 8, 15, -6 }, c = CRYSTAL, m = "Glass", tr = 0.2 },
				{ n = "CrystalSpike", s = { 2, 8, 2 }, p = { 2.8, 3, 1 }, r = { 25, 40, 20 }, c = { 150, 200, 255 }, m = "Glass", tr = 0.2, col = false },
				{ n = "CrystalSpike", s = { 1.6, 6, 1.6 }, p = { -2.5, 2.2, -1 }, r = { -20, 10, -25 }, c = CRYSTAL, m = "Glass", tr = 0.2, col = false },
				{ n = "CrystalRock", s = { 6, 2.5, 6 }, p = { 0, 0.4, 0 }, r = { 5, 30, 4 }, c = "Basalt", m = "Basalt" },
			},
		},
		T2_CaveMouth = { -- 동굴 입구(바위 턱 + 어두운 안 - 장식 · 들어가지 못한다)
			parts = {
				{ n = "CaveRock", s = { 6, 14, 8 }, p = { -8, 6, 0 }, r = { 0, 8, -6 }, c = "Basalt", m = "Basalt" },
				{ n = "CaveRock", s = { 6, 13, 8 }, p = { 8, 5.5, 0 }, r = { 0, -10, 7 }, c = "Basalt", m = "Basalt", dk = 0.08 },
				{ n = "CaveRock", s = { 24, 6, 10 }, p = { 0, 14, 1 }, r = { 4, 0, 2 }, c = "Basalt", m = "Basalt" },
				{ n = "CaveDark", s = { 12, 11, 1 }, p = { 0, 5.5, 2.5 }, c = { 12, 10, 18 }, m = "SmoothPlastic" },
				{ n = "CaveCrystal", s = { 1.4, 5, 1.4 }, p = { 5, 2, -2 }, r = { 15, 0, 20 }, c = CRYSTAL, m = "Glass", tr = 0.2, col = false },
			},
		},
		T2_Boulder = {
			parts = {
				{ n = "Boulder", s = { 8, 6, 7 }, p = { 0, 2, 0 }, r = { 10, 20, 8 }, c = "Basalt", m = "Basalt" },
				{ n = "Boulder", s = { 5, 4, 5 }, p = { 5, 1.2, 2 }, r = { -12, 60, 15 }, c = "Slate", m = "Slate" },
			},
		},
		-- T3 수몰 사원 해안
		T3_CoastRock = { -- 해안 바위(파도에 깎인 기둥 2)
			parts = {
				{ n = "CoastRock", s = { 8, 12, 7 }, p = { 0, 4.5, 0 }, r = { 0, 15, 6 }, c = "Rock", m = "Rock" },
				{ n = "CoastRock", s = { 5, 7, 5 }, p = { 6, 2, 3 }, r = { 8, 50, -8 }, c = "Rock", m = "Rock", dk = 0.12 },
				{ n = "Barnacle", s = { 8.4, 1.2, 7.4 }, p = { 0, 0.6, 0 }, r = { 0, 15, 0 }, c = { 150, 146, 120 }, m = "Sand", col = false },
			},
		},
		T3_Shipwreck = { -- 난파선(기운 선체 반쪽 + 부러진 돛대 · 길이 24)
			parts = {
				{ n = "Hull", s = { 7, 6, 24 }, p = { 0, 2, 0 }, r = { 0, 0, 22 }, c = { 110, 80, 58 }, m = "WoodPlanks", sh = "Wedge" },
				{ n = "HullRib", s = { 1, 7, 1 }, p = { -2, 3.2, -6 }, r = { 0, 0, -20 }, c = { 90, 66, 48 }, m = "Wood", col = false },
				{ n = "HullRib", s = { 1, 7, 1 }, p = { -2, 3.2, 4 }, r = { 0, 0, -20 }, c = { 90, 66, 48 }, m = "Wood", col = false },
				{ n = "Mast", s = { 14, 1.4, 1.4 }, p = { 3, 5, 2 }, r = { 0, 20, 55 }, c = { 96, 70, 50 }, m = "Wood", sh = "Cylinder", col = false },
			},
		},
		-- T4 모래 유적
		T4_MushroomRock = { -- 버섯 바위(가는 대 + 넓은 머리 · 높이 16)
			parts = {
				{ n = "RockStem", s = { 5, 11, 5 }, p = { 0, 4.5, 0 }, r = { 0, 10, 2 }, c = "Sandstone", m = "Sandstone", dk = 0.1 },
				{ n = "RockCap", s = { 15, 5, 13 }, p = { 0.5, 12.5, 0 }, r = { 3, 30, -4 }, c = "Sandstone", m = "Sandstone" },
			},
		},
		T4_Hoodoo = { -- 첨탑 바위(쌓인 사암 3 · 높이 22)
			parts = {
				{ n = "Hoodoo", s = { 8, 9, 8 }, p = { 0, 3.5, 0 }, r = { 0, 25, 0 }, c = "Sandstone", m = "Sandstone", dk = 0.1 },
				{ n = "Hoodoo", s = { 6, 8, 6 }, p = { 0.3, 11, 0 }, r = { 0, 50, 3 }, c = "Sand", m = "Sandstone" },
				{ n = "Hoodoo", s = { 5, 5, 5 }, p = { 0.5, 17.5, 0.3 }, r = { 4, 10, -3 }, c = "Sandstone", m = "Sandstone" },
			},
		},
		T4_Boulder = {
			parts = {
				{ n = "Boulder", s = { 9, 5, 7 }, p = { 0, 1.8, 0 }, r = { 8, 20, 6 }, c = "Sandstone", m = "Sandstone" },
				{ n = "Boulder", s = { 4, 3, 4 }, p = { 5.5, 0.8, 2 }, r = { -12, 60, 15 }, c = "Sandstone", m = "Sandstone", dk = 0.12 },
			},
		},
		-- T5 폭풍 첨탑
		T5_SpireRock = { -- 뾰족 첨탑 바위(좁아지는 돌 3 · 높이 26 · 조금 기움)
			parts = {
				{ n = "SpireRock", s = { 7, 10, 7 }, p = { 0, 4, 0 }, r = { 0, 20, 3 }, c = "Basalt", m = "Basalt" },
				{ n = "SpireRock", s = { 4.6, 10, 4.6 }, p = { 0.5, 13, 0.2 }, r = { 2, 45, 5 }, c = "Basalt", m = "Basalt", dk = 0.1 },
				{ n = "SpireRock", s = { 2.6, 8, 2.6 }, p = { 1.2, 21.5, 0.4 }, r = { 3, 70, 7 }, c = "Basalt", m = "Basalt" },
			},
		},
		T5_StruckRock = { -- 번개 맞은 바위(쪼개진 두 쪽 + 그을린 틈 · 은은한 빛 - 위험색 아님)
			parts = {
				{ n = "SplitRock", s = { 6, 9, 9 }, p = { -3.6, 3.5, 0 }, r = { 0, 0, -10 }, c = "Cobblestone", m = "Cobblestone" },
				{ n = "SplitRock", s = { 6, 8, 9 }, p = { 3.6, 3, 0 }, r = { 0, 0, 12 }, c = "Cobblestone", m = "Cobblestone", dk = 0.1 },
				{ n = "Scorch", s = { 3, 0.3, 10 }, p = { 0, 0.15, 0 }, c = { 40, 38, 44 }, m = "Slate", col = false },
				{ n = "ScorchGlow", s = { 0.4, 6, 0.4 }, p = { 0, 3, 0 }, c = { 170, 200, 255 }, m = "Neon", tr = 0.5, col = false },
			},
		},
		T5_Boulder = {
			parts = {
				{ n = "Boulder", s = { 8, 6, 7 }, p = { 0, 2, 0 }, r = { 10, 20, 8 }, c = "Cobblestone", m = "Cobblestone" },
				{ n = "Boulder", s = { 5, 4, 5 }, p = { 5, 1.2, 2 }, r = { -12, 60, 15 }, c = "Basalt", m = "Basalt" },
			},
		},
		-- T6 빙하
		T6_IcePillar = { -- 얼음 기둥(비스듬한 빙주 2 · 높이 18)
			parts = {
				{ n = "IcePillar", s = { 5, 18, 5 }, p = { 0, 8, 0 }, r = { 6, 20, -5 }, c = "Ice", m = "Ice", tr = 0.1 },
				{ n = "IcePillar", s = { 3, 10, 3 }, p = { 3.5, 4, 1.5 }, r = { -10, 50, 14 }, c = "Glacier", m = "Glacier", tr = 0.1 },
				{ n = "SnowCap", s = { 6, 1.4, 6 }, p = { 0.8, 16.6, -0.8 }, r = { 6, 20, -5 }, c = "Snow", m = "Snow", col = false },
			},
		},
		T6_IceChunk = { -- 얼음 덩어리(기울인 판 3)
			parts = {
				{ n = "IceChunk", s = { 9, 5, 7 }, p = { 0, 1.8, 0 }, r = { 12, 25, 10 }, c = "Glacier", m = "Glacier" },
				{ n = "IceChunk", s = { 5, 7, 4 }, p = { 5, 2.5, -1 }, r = { -8, 60, -12 }, c = "Ice", m = "Ice", tr = 0.1 },
				{ n = "IceChunk", s = { 4, 3, 4 }, p = { -4.5, 0.8, 2.5 }, r = { 20, 5, 10 }, c = "Snow", m = "Snow" },
			},
		},
		T6_SnowBoulder = {
			parts = {
				{ n = "Boulder", s = { 8, 6, 7 }, p = { 0, 2, 0 }, r = { 10, 20, 8 }, c = "Rock", m = "Rock" },
				{ n = "SnowCap", s = { 7, 1.6, 6 }, p = { 0.2, 4.6, 0 }, r = { 10, 20, 8 }, c = "Snow", m = "Snow", col = false },
			},
		},
	},
}
