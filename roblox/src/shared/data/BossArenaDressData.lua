-- A2-M1 보스 아레나 꾸미기(클라 전용 - client/BossArenaDressing · ArtStyleV1 스위치 뒤 · 판정 · 충돌 무관). 서버 아레나(BossArenaMap · BossArenaMapData)는 그대로 두고,
--   **플레이 영역 밖**(벽 반경 140 밖 - 테라스 140 ~ 180 · 먼 배경 180 ~)에 충돌 없는 장식 · 떠다니는 조각 · 환경 효과를 얹는다. 플레이 영역 안은 바닥 재질 · 가장자리 선 · 떠오르는 작은 빛(조준 · 충돌 없음)만.
--   반경 = 아레나 중심에서 stud · 높이 = 바닥 윗면에서 stud · 색 역할 = accent(보스 테마 강조) · head · body · floor(바닥색) · stone(바닥을 어둡게) · light(강조를 밝게) 또는 Color3.
-- 종류(kind):
--   floatStones = { count, radius = { 최소, 최대 }, height = { 최소, 최대 }, size, color, inlay(빛 줄 색), bob(위아래 stud), spin(도/초) } - 떠다니며 천천히 도는 돌(매 프레임 · 개수 적게)
--   clusters    = { count, radius, shards = { 최소, 최대 }, size(큰 조각 크기), color, material } - 테라스 위 결정 · 가시 무리(고정)
--   pillars     = { count, radius, height = { 최소, 최대 }, width, color, broken(윗부분 기울어진 조각) } - 먼 배경 기둥(고정)
--   motes       = { every(초), life, rise, size, color, phoneScale, fall(true = 위에서 떨어짐 · 높이 fromHeight), wind(Vector3 - 옆으로 흐름), shape("ball" | "streak" - 빗줄기 · 모래바람 줄), material }
--                 - 아레나 안 환경 효과(BossFx 풀 - 동시 상한): 떠오르는 빛 · 눈 내림 · 물방울 · 결정 반짝임 · 모래바람 · 빗줄기
--   bolts       = { every(초 - 평균), radius = { 최소, 최대 }, color } - 먼 번개(플레이 영역 밖 · 설정 "섬광 줄이기"면 옅게 · 화면 번쩍임 없음)
--   edge        = { color, width, transparency } - 벽 안쪽 바닥 가장자리 선(반경 138.5)
--   floor       = { material, tint(바닥색에 섞을 색 역할), amount } - 바닥 재질(이 클라만)
--   atmosphere  = { density, color, decay, haze } - 보스전 동안 대기(이 클라만 - 끝나면 되돌림)
-- 폰(짧은 변 < 500 · 터치)은 phone = { … 개수 배율 } 만큼 줄인다.
local BossArenaDressData = {}

BossArenaDressData.phone = { countScale = 0.5, moteScale = 0.5 }
BossArenaDressData.playRadius = 140

BossArenaDressData.bosses = {
	-- 공허의 제단(구간 수호자): 공중에 뜬 고대 룬석 · 테라스의 보라 수정 무리 · 먼 폐허 기둥 · 떠오르는 룬 불티
	section_guardian = {
		floatStones = { count = 10, radius = { 168, 215 }, height = { 12, 34 }, size = Vector3.new(7, 9, 5), color = "stone", inlay = "accent", bob = 2.2, spin = 6 },
		-- 결정은 벽(높이 14) 위로 10 이상 솟게(Play 3: 높이 12는 벽에 가려 안에서 안 보였다)
		clusters = { count = 9, radius = { 150, 170 }, shards = { 3, 5 }, size = Vector3.new(4.4, 26, 4.4), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 8, radius = { 230, 290 }, height = { 34, 60 }, width = 11, color = "pillar", broken = true },
		motes = { every = 0.22, life = 3.2, rise = 9, size = 0.45, color = "light", phoneScale = 0.5 },
		edge = { color = "accent", width = 0.9, transparency = 0.35 },
		floor = { material = Enum.Material.Slate, tint = "accent", amount = 0.08 },
		atmosphere = { density = 0.32, color = "accent", decay = "body", haze = 1.2 },
	},
	-- 빙하 동굴(서리 거인): 떠 있는 얼음 조각 · 테라스 얼음 가시 · 먼 얼음 폭포 기둥 · 눈 내림 · 차가운 안개
	frost_giant = {
		floatStones = { count = 8, radius = { 170, 215 }, height = { 14, 36 }, size = Vector3.new(6, 9, 6), color = "light", inlay = "accent", bob = 1.6, spin = 4, material = Enum.Material.Ice },
		clusters = { count = 10, radius = { 150, 170 }, shards = { 3, 5 }, size = Vector3.new(4.6, 28, 4.6), color = "light", material = Enum.Material.Ice },
		pillars = { count = 8, radius = { 230, 290 }, height = { 40, 70 }, width = 12, color = "light", broken = false, material = Enum.Material.Glacier },
		motes = { every = 0.07, life = 4.5, rise = 28, size = 0.5, color = Color3.fromRGB(248, 252, 255), phoneScale = 0.5, fall = true, fromHeight = 30, wind = Vector3.new(3, 0, 1.5), material = Enum.Material.SmoothPlastic },
		edge = { color = "accent", width = 0.9, transparency = 0.4 },
		floor = { material = Enum.Material.Glacier, tint = "light", amount = 0.15 },
		atmosphere = { density = 0.36, color = "light", decay = "accent", haze = 1.6 },
	},
	-- 수몰 사원(심해 군주): 가라앉은 기둥 조각이 물속처럼 떠 있음 · 테라스 산호 · 먼 신전 기둥 · 떠오르는 물방울 · 깊은 청록 안개
	abyssal_lord = {
		floatStones = { count = 9, radius = { 168, 215 }, height = { 10, 30 }, size = Vector3.new(6, 10, 6), color = "pillar", inlay = "accent", bob = 2.6, spin = 3 },
		clusters = { count = 9, radius = { 150, 170 }, shards = { 3, 6 }, size = Vector3.new(3.4, 22, 3.4), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 9, radius = { 230, 290 }, height = { 36, 62 }, width = 11, color = "pillar", broken = true },
		motes = { every = 0.16, life = 3.6, rise = 14, size = 0.55, color = "light", phoneScale = 0.5, material = Enum.Material.Glass },
		edge = { color = "accent", width = 0.9, transparency = 0.35 },
		floor = { material = Enum.Material.Cobblestone, tint = "accent", amount = 0.1 },
		atmosphere = { density = 0.38, color = "accent", decay = "body", haze = 1.4 },
	},
	-- 수정 동굴(수정 여왕): 떠 있는 결정 · 테라스 청록 결정 · 먼 결정 첨탑 · 반짝임 · 분홍 안개
	crystal_queen = {
		floatStones = { count = 10, radius = { 165, 212 }, height = { 12, 36 }, size = Vector3.new(4, 11, 4), color = "accent", inlay = "light", bob = 2.2, spin = 10, material = Enum.Material.Glass },
		clusters = { count = 11, radius = { 150, 170 }, shards = { 3, 6 }, size = Vector3.new(4.2, 26, 4.2), color = "accent", material = Enum.Material.Glass },
		pillars = { count = 8, radius = { 230, 290 }, height = { 44, 76 }, width = 9, color = "accent", broken = false, material = Enum.Material.Glass },
		motes = { every = 0.14, life = 2.4, rise = 5, size = 0.4, color = "light", phoneScale = 0.5 },
		edge = { color = "accent", width = 0.9, transparency = 0.3 },
		floor = { material = Enum.Material.Marble, tint = "head", amount = 0.08 },
		atmosphere = { density = 0.3, color = "head", decay = "accent", haze = 1.2 },
	},
	-- 모래 유적(전갈 여왕): 떠 있는 것 없음 · 테라스 사암 바위 · 먼 폐허 기둥 · 모래바람 줄 · 따뜻한 먼지 안개
	scorpion_queen = {
		clusters = { count = 10, radius = { 150, 172 }, shards = { 2, 4 }, size = Vector3.new(7, 20, 7), color = "pillar", material = Enum.Material.Sandstone },
		pillars = { count = 10, radius = { 225, 290 }, height = { 26, 50 }, width = 12, color = "pillar", broken = true, material = Enum.Material.Sandstone },
		motes = { every = 0.06, life = 1.6, rise = 0, size = 0.3, color = "pillar", phoneScale = 0.4, shape = "streak", wind = Vector3.new(34, 0, 10) },
		edge = { color = "accent", width = 0.9, transparency = 0.45 },
		floor = { material = Enum.Material.Sand, tint = "floor", amount = 0 },
		atmosphere = { density = 0.42, color = "pillar", decay = "accent", haze = 2.2 },
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
		atmosphere = { density = 0.4, color = "stone", decay = "body", haze = 1.8 },
	},
}

return BossArenaDressData
