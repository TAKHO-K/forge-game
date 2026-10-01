-- A2-M1 보스 아레나 꾸미기(클라 전용 - client/BossArenaDressing · ArtStyleV1 스위치 뒤 · 판정 · 충돌 무관). 서버 아레나(BossArenaMap · BossArenaMapData)는 그대로 두고,
--   **플레이 영역 밖**(벽 반경 140 밖 - 테라스 140 ~ 180 · 먼 배경 180 ~)에 충돌 없는 장식 · 떠다니는 조각 · 환경 효과를 얹는다. 플레이 영역 안은 바닥 재질 · 가장자리 선 · 떠오르는 작은 빛(조준 · 충돌 없음)만.
--   반경 = 아레나 중심에서 stud · 높이 = 바닥 윗면에서 stud · 색 역할 = accent(보스 테마 강조) · head · body · floor(바닥색) · stone(바닥을 어둡게) · light(강조를 밝게) 또는 Color3.
-- 종류(kind):
--   floatStones = { count, radius = { 최소, 최대 }, height = { 최소, 최대 }, size, color, inlay(빛 줄 색), bob(위아래 stud), spin(도/초) } - 떠다니며 천천히 도는 돌(매 프레임 · 개수 적게)
--   clusters    = { count, radius, shards = { 최소, 최대 }, size(큰 조각 크기), color, material } - 테라스 위 결정 · 가시 무리(고정)
--   pillars     = { count, radius, height = { 최소, 최대 }, width, color, broken(윗부분 기울어진 조각) } - 먼 배경 기둥(고정)
--   motes       = { every(초), life, rise, size, color, phoneScale, fall(true = 위에서 떨어짐 · 높이 fromHeight), wind(Vector3 - 옆으로 흐름), shape("ball" | "block" | "streak" - 빗줄기 · 모래바람 줄), material }
--                 - 아레나 안 환경 효과(BossFx 풀 - 동시 상한): 떠오르는 빛 · 눈 내림 · 물방울 · 결정 반짝임 · 모래바람 · 빗줄기
--   bolts       = { every(초 - 평균), radius = { 최소, 최대 }, color } - 먼 번개(플레이 영역 밖 · 설정 "섬광 줄이기"면 옅게 · 화면 번쩍임 없음)
--   edge        = { color, width, transparency } - 벽 안쪽 바닥 가장자리 선(반경 138.5)
--   floor       = { material, tint(바닥색에 섞을 색 역할), amount } - 바닥 재질(이 클라만)
--   atmosphere  = { density, color, decay, haze } - 보스전 동안 대기(이 클라만 - 끝나면 되돌림)
--   backdrop    = 배경 링 층 목록(A2-N4 P0-5 - 아레나 밖 사냥터 · 다른 아레나를 가린다 · 충돌 · 조준 · 그림자 없음 · 폰도 개수 그대로 = 틈 없음):
--                 { shape("peak" 45° 돌린 상자 = 산 삼각 실루엣 | "cliff" 상자 + 윗면 쐐기 | "spire" 가는 첨탑 | "dome" 둔덕 · 구름 공), count, radius = { 최소, 최대 }, height = { 최소, 최대 },
--                   width(cliff · spire 폭 - peak · dome은 높이에서), color(역할), fog(0 ~ 1 - 대기색 쪽으로 섞기 = 멀수록 흐림), material, lift(바닥 위로 띄움 - 구름) }
--   sky         = { clockTime } - 보스전 동안 하늘 시각(이 클라만 - 끝나면 되돌림)
--   floorMesh   = { mesh(ArtMeshCache 키), scaleXZ, material, slabLighten, slabBDarken, groutDarken | grout(역할 · 색), runes | detail(색), runeTransparency | detailTransparency, detailMaterial, hideDecor }
--                 - QUEUE-ALL1 바닥 v2 석판 메시: 구간 수호자 = Slice1~8 · Hub · Runes(붕괴 조각별 보임) · 나머지 = SlabA · SlabB(두 톤) · Grout(줄눈 원판) · Detail(무늬)
--   rim         = { fire(화로 불빛 색 - 보스 테마 · 주황 · 빨강 금지), braziers, pillars(개수 - 없으면 공통 값), curbColor · pillarColor(역할), material }
--                 - QUEUE-ALL1 바닥 v2 가장자리(docs/design/v2/03 4절): 벽 밑 낮은 턱(벽 24각형 면마다 1조각) · 벽에 박힌 부서진 기둥 + 테라스에 쓰러진 윗동 · 벽 위 화로
-- 폰(짧은 변 < 500 · 터치)은 phone = { … 개수 배율 } 만큼 줄인다.
local BossArenaDressData = {}

BossArenaDressData.phone = { countScale = 0.5, moteScale = 0.5 }
BossArenaDressData.playRadius = 140

-- 가장자리 · 조명 공통 수치(QUEUE-ALL1 바닥 v2 4 · 5절). 반경 · 벽 높이 · 두께 · 면 수 = BossArenaMapData.geometry(서버와 같은 값).
--   턱: 벽 안쪽 면에서 안으로 curbWidth · 바닥 위 curbHeight(낮게 - 발 · 시야 안 가림 · 가장자리 선 138.5보다 바깥) · 붕괴 조각이 무너지면 그 조각 위 턱도 숨김
--   기둥: 벽 모서리에 박힘 · 높이 = 바닥에서(벽 14 위로 솟은 만큼 보인다) · 쓰러진 윗동은 테라스(벽 바깥 fallenOut)
--   화로: 벽 윗면 위 그릇 + 불(Neon) + PointLight(그림자 끔) · 폰 = 광원 없이 발광 재질만
--   가운데 조명: 중심 위 centerLight.height의 PointLight 1개(가운데 약간 밝고 가장자리 어둡게 - 범위가 가장자리까지 안 닿는다)
--   파트 합 = 턱 24 + 기둥 × 2 + 화로 × 2 + 가운데 1 ≤ 41 · 광원 = 화로 + 1 ≤ 7
BossArenaDressData.rim = {
	curbHeight = 0.7, curbWidth = 2,
	braziers = 4, pillars = 4,
	pillarWidth = 5, pillarHeight = { 19, 25 }, fallenOut = 9,
	bowlSize = Vector3.new(2.6, 5.6, 5.6), flameSize = 3.8, flameTransparency = 0.15, -- QUEUE-ALL4 A1: 3.2 그릇은 반경 140 아레나 전경에서 점으로만 보임(Play 캡처) → 약 1.8배
	fireLight = { brightness = 1.6, range = 26, flicker = 0.25 },
	centerLight = { height = 26, brightness = 0.9, range = 60, color = Color3.fromRGB(232, 238, 255) },
	phoneLights = false,
}

BossArenaDressData.bosses = {
	-- 공허의 제단(구간 수호자): 공중에 뜬 고대 룬석 · 테라스의 보라 수정 무리 · 먼 폐허 기둥 · 떠오르는 룬 불티
	section_guardian = {
		floatStones = { count = 10, radius = { 168, 215 }, height = { 12, 34 }, size = Vector3.new(7, 9, 5), color = "stone", inlay = "accent", bob = 2.2, spin = 6 },
		-- 결정은 벽(높이 14) 위로 10 이상 솟게(Play 3: 높이 12는 벽에 가려 안에서 안 보였다)
		clusters = { count = 9, radius = { 150, 170 }, shards = { 3, 5 }, size = Vector3.new(4.4, 26, 4.4), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 8, radius = { 230, 290 }, height = { 34, 60 }, width = 11, color = "pillar", broken = true },
		motes = { every = 0.22, life = 3.2, rise = 9, size = 0.45, color = "light", phoneScale = 0.5 },
		edge = { color = "accent", width = 0.9, transparency = 0.35 },
		floor = { material = Enum.Material.Slate, tint = Color3.fromRGB(150, 152, 162), amount = 0.35 }, -- A2-M1 2차: 보라 보스가 보라 바닥에 묻힘(리뷰) → 밝은 중성 회색 쪽으로
		-- QUEUE-ALL1 P2 바닥 v2: 동심원 석판(8조각 = 붕괴 조각 · 허브 · 룬) - 석판 = 바닥색을 밝게 · 줄눈(서버 바닥) = 어둡게 · 룬 = 옅은 청록(빨강 · 주황 금지)
		floorMesh = { mesh = "arena/floor_guardian", scaleXZ = 10, material = Enum.Material.Slate, slabLighten = 0.12, groutDarken = 0.45, runes = Color3.fromRGB(120, 210, 200), runeTransparency = 0.35,
			hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- 석판을 덮는 서버 바닥 장식(이 클라에서만 숨김)
		rim = { fire = Color3.fromRGB(170, 120, 255), curbColor = "pillar", pillarColor = "pillar", material = Enum.Material.Slate },
		atmosphere = { density = 0.32, color = "accent", decay = "body", haze = 1.2 },
		backdrop = {
			{ shape = "cliff", count = 22, radius = { 188, 205 }, height = { 34, 56 }, width = 58, color = "stone", fog = 0.15, material = Enum.Material.Slate },
			{ shape = "peak", count = 16, radius = { 300, 330 }, height = { 90, 140 }, color = "body", fog = 0.55, material = Enum.Material.Slate },
		},
	},
	-- 빙하 동굴(서리 거인): 떠 있는 얼음 조각 · 테라스 얼음 가시 · 먼 얼음 폭포 기둥 · 눈 내림 · 차가운 안개
	frost_giant = {
		floatStones = { count = 8, radius = { 170, 215 }, height = { 14, 36 }, size = Vector3.new(6, 9, 6), color = "light", inlay = "accent", bob = 1.6, spin = 4, material = Enum.Material.Ice },
		clusters = { count = 10, radius = { 150, 170 }, shards = { 3, 5 }, size = Vector3.new(4.6, 28, 4.6), color = "light", material = Enum.Material.Ice },
		pillars = { count = 8, radius = { 230, 290 }, height = { 40, 70 }, width = 12, color = "light", broken = false, material = Enum.Material.Glacier },
		motes = { every = 0.07, life = 4.5, rise = 28, size = 0.5, color = Color3.fromRGB(248, 252, 255), phoneScale = 0.5, fall = true, fromHeight = 30, wind = Vector3.new(3, 0, 1.5), material = Enum.Material.SmoothPlastic, shape = "block" }, -- 눈송이 = 작은 판(공은 삼각형이 많다 - Play 4 추정 1.9만)
		edge = { color = "accent", width = 0.9, transparency = 0.4 },
		floor = { material = Enum.Material.Glacier, tint = Color3.fromRGB(96, 124, 158), amount = 0.35 }, -- A2-M1 2차: 흰 바닥에 흰 포효 전조가 묻힘(리뷰) → 푸른 회색 얼음
		floorMesh = { mesh = "arena/floor_frost", scaleXZ = 10, material = Enum.Material.Glacier, slabLighten = 0.12, slabBDarken = 0.08, grout = Color3.fromRGB(232, 240, 250), detail = Color3.fromRGB(214, 236, 255), detailTransparency = 0.45, hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- QUEUE-ALL1 P2 바닥 v2: 두꺼운 얼음 판 · 눈 쌓인 이음매 · 얼음 금
		rim = { fire = Color3.fromRGB(150, 215, 255), curbColor = "light", pillarColor = "light", material = Enum.Material.Glacier },
		atmosphere = { density = 0.36, color = "light", decay = "accent", haze = 1.6 },
		backdrop = {
			{ shape = "peak", count = 22, radius = { 188, 205 }, height = { 40, 64 }, color = "light", fog = 0.1, material = Enum.Material.Glacier },
			{ shape = "peak", count = 16, radius = { 300, 330 }, height = { 100, 150 }, color = Color3.fromRGB(236, 244, 252), fog = 0.45, material = Enum.Material.Snow },
		},
	},
	-- 수몰 사원(심해 군주): 가라앉은 기둥 조각이 물속처럼 떠 있음 · 테라스 산호 · 먼 신전 기둥 · 떠오르는 물방울 · 깊은 청록 안개
	abyssal_lord = {
		floatStones = { count = 9, radius = { 168, 215 }, height = { 10, 30 }, size = Vector3.new(6, 10, 6), color = "pillar", inlay = "accent", bob = 2.6, spin = 3 },
		clusters = { count = 9, radius = { 150, 170 }, shards = { 3, 6 }, size = Vector3.new(3.4, 22, 3.4), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 9, radius = { 230, 290 }, height = { 36, 62 }, width = 11, color = "pillar", broken = true },
		motes = { every = 0.16, life = 3.6, rise = 14, size = 0.55, color = "light", phoneScale = 0.5, material = Enum.Material.Glass },
		edge = { color = "accent", width = 0.9, transparency = 0.35 },
		floor = { material = Enum.Material.Cobblestone, tint = "accent", amount = 0.1 },
		floorMesh = { mesh = "arena/floor_abyssal", scaleXZ = 10, material = Enum.Material.Slate, slabLighten = 0.1, slabBDarken = 0.1, grout = "stone", detail = Color3.fromRGB(96, 176, 196), detailTransparency = 0.3, detailMaterial = Enum.Material.Glass, hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- 젖은 산호석 · 얕은 물웅덩이
		rim = { fire = Color3.fromRGB(70, 215, 225), curbColor = "pillar", pillarColor = "pillar", material = Enum.Material.Slate },
		atmosphere = { density = 0.38, color = "accent", decay = "body", haze = 1.4 },
		backdrop = {
			{ shape = "cliff", count = 22, radius = { 188, 205 }, height = { 30, 50 }, width = 58, color = "stone", fog = 0.2, material = Enum.Material.Rock },
			{ shape = "spire", count = 18, radius = { 290, 320 }, height = { 80, 130 }, width = 22, color = "body", fog = 0.6, material = Enum.Material.Rock },
		},
	},
	-- 수정 동굴(수정 여왕): 떠 있는 결정 · 테라스 청록 결정 · 먼 결정 첨탑 · 반짝임 · 분홍 안개
	crystal_queen = {
		floatStones = { count = 10, radius = { 165, 212 }, height = { 12, 36 }, size = Vector3.new(4, 11, 4), color = "accent", inlay = "light", bob = 2.2, spin = 10, material = Enum.Material.Glass },
		clusters = { count = 11, radius = { 150, 170 }, shards = { 3, 6 }, size = Vector3.new(4.2, 26, 4.2), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 8, radius = { 230, 290 }, height = { 44, 76 }, width = 9, color = "accent", broken = false, material = Enum.Material.Glass },
		motes = { every = 0.14, life = 2.4, rise = 5, size = 0.4, color = "light", phoneScale = 0.5 },
		edge = { color = "accent", width = 0.9, transparency = 0.3 },
		floor = { material = Enum.Material.Marble, tint = "head", amount = 0.08 },
		floorMesh = { mesh = "arena/floor_crystal", scaleXZ = 10, material = Enum.Material.SmoothPlastic, slabLighten = 0.22, slabBDarken = 0.08, grout = "stone", detail = Color3.fromRGB(206, 170, 255), detailTransparency = 0.4, hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- 자수정 결정 판 · 옅은 보라 결정 맥(Play: Marble 재질은 잔무늬가 많고 어두웠다 → 매끈 + 밝게)
		rim = { fire = Color3.fromRGB(205, 140, 255), curbColor = "pillar", pillarColor = "stone", material = Enum.Material.Rock },
		atmosphere = { density = 0.3, color = "head", decay = "accent", haze = 1.2 },
		backdrop = {
			{ shape = "cliff", count = 22, radius = { 188, 205 }, height = { 30, 50 }, width = 58, color = "stone", fog = 0.15, material = Enum.Material.Rock },
			{ shape = "spire", count = 18, radius = { 290, 320 }, height = { 90, 150 }, width = 20, color = "accent", fog = 0.45, material = Enum.Material.Glass },
		},
	},
	-- 모래 유적(전갈 여왕): 떠 있는 것 없음 · 테라스 사암 바위 · 먼 폐허 기둥 · 모래바람 줄 · 따뜻한 먼지 안개
	scorpion_queen = {
		clusters = { count = 10, radius = { 150, 172 }, shards = { 2, 4 }, size = Vector3.new(7, 20, 7), color = "pillar", material = Enum.Material.Sandstone },
		pillars = { count = 10, radius = { 225, 290 }, height = { 26, 50 }, width = 12, color = "pillar", broken = true, material = Enum.Material.Sandstone },
		motes = { every = 0.06, life = 1.6, rise = 0, size = 0.3, color = "pillar", phoneScale = 0.4, shape = "streak", wind = Vector3.new(34, 0, 10) },
		edge = { color = "accent", width = 0.9, transparency = 0.45 },
		floor = { material = Enum.Material.Sand, tint = "floor", amount = 0 },
		floorMesh = { mesh = "arena/floor_scorpion", scaleXZ = 10, material = Enum.Material.Sandstone, slabLighten = 0.06, slabBDarken = 0.1, grout = Color3.fromRGB(222, 196, 140), hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- 모래가 이음매를 메운 유적 타일
		rim = { fire = Color3.fromRGB(120, 235, 190), curbColor = "pillar", pillarColor = "pillar", material = Enum.Material.Sandstone }, -- 오아시스 청록(전갈 강조색 호박색 = 경고색 계열이라 안 씀)
		atmosphere = { density = 0.42, color = "pillar", decay = "accent", haze = 2.2 },
		backdrop = {
			{ shape = "dome", count = 22, radius = { 190, 210 }, height = { 26, 40 }, color = "pillar", fog = 0.15, material = Enum.Material.Sand },
			{ shape = "cliff", count = 16, radius = { 300, 330 }, height = { 70, 110 }, width = 110, color = "pillar", fog = 0.5, material = Enum.Material.Sandstone },
		},
	},
	-- 폭풍 첨탑(폭풍 군주): 떠 있는 번개 바위 · 테라스 피뢰 가시 · 먼 검은 첨탑 · 빗줄기 · 먼 번개
	storm_lord = {
		floatStones = { count = 9, radius = { 168, 215 }, height = { 14, 38 }, size = Vector3.new(6, 8, 6), color = "stone", inlay = "accent", bob = 3, spin = 8 },
		clusters = { count = 8, radius = { 150, 170 }, shards = { 1, 2 }, size = Vector3.new(1.6, 30, 1.6), color = "stone", material = Enum.Material.Metal, tip = "accent" },
		pillars = { count = 8, radius = { 230, 290 }, height = { 50, 84 }, width = 10, color = "stone", broken = false },
		motes = { every = 0.03, life = 0.9, rise = -46, size = 0.18, color = "light", phoneScale = 0.35, fall = true, fromHeight = 40, shape = "streak", wind = Vector3.new(-6, 0, 3) },
		bolts = { every = 5, radius = { 190, 260 }, color = "accent" },
		edge = { color = "accent", width = 0.9, transparency = 0.35 },
		floor = { material = Enum.Material.Slate, tint = "accent", amount = 0.04 },
		floorMesh = { mesh = "arena/floor_storm", scaleXZ = 10, material = Enum.Material.Basalt, slabLighten = 0.12, slabBDarken = 0.1, grout = "stone", detail = Color3.fromRGB(150, 210, 255), detailTransparency = 0.3, hideDecor = { ArenaFloorRing = true, ArenaFloorRingInner = true, ArenaFloorDisc = true } }, -- 떠 있는 섬 바위 · 번개 문양 동심원
		rim = { fire = Color3.fromRGB(175, 160, 255), curbColor = "stone", pillarColor = "stone", material = Enum.Material.Basalt },
		atmosphere = { density = 0.4, color = "stone", decay = "body", haze = 1.8 },
		backdrop = {
			{ shape = "peak", count = 22, radius = { 188, 205 }, height = { 40, 66 }, color = "stone", fog = 0.15, material = Enum.Material.Slate },
			{ shape = "spire", count = 18, radius = { 290, 320 }, height = { 110, 170 }, width = 18, color = "stone", fog = 0.5, material = Enum.Material.Basalt },
		},
		sky = { clockTime = 17.3 }, -- 해질녘(Play: 18.4는 달밤처럼 어두워 보스가 묻혔다)
	},
}

return BossArenaDressData
