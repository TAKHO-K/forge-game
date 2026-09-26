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
	},
}
