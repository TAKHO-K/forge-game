-- A2-M1 보스 아레나 꾸미기(클라 전용 - client/BossArenaDressing · ArtStyleV1 스위치 뒤 · 판정 · 충돌 무관). 서버 아레나(BossArenaMap · BossArenaMapData)는 그대로 두고,
--   **플레이 영역 밖**(벽 반경 140 밖 - 테라스 140 ~ 180 · 먼 배경 180 ~)에 충돌 없는 장식 · 떠다니는 조각 · 환경 효과를 얹는다. 플레이 영역 안은 바닥 재질 · 가장자리 선 · 떠오르는 작은 빛(조준 · 충돌 없음)만.
--   반경 = 아레나 중심에서 stud · 높이 = 바닥 윗면에서 stud · 색 역할 = accent(보스 테마 강조) · head · body · floor(바닥색) · stone(바닥을 어둡게) · light(강조를 밝게) 또는 Color3.
-- 종류(kind):
--   floatStones = { count, radius = { 최소, 최대 }, height = { 최소, 최대 }, size, color, inlay(빛 줄 색), bob(위아래 stud), spin(도/초) } - 떠다니며 천천히 도는 돌(매 프레임 · 개수 적게)
--   clusters    = { count, radius, shards = { 최소, 최대 }, size(큰 조각 크기), color, material } - 테라스 위 결정 · 가시 무리(고정)
--   pillars     = { count, radius, height = { 최소, 최대 }, width, color, broken(윗부분 기울어진 조각) } - 먼 배경 기둥(고정)
--   motes       = { every(초), life, rise, size, color, phoneScale } - 아레나 안 떠오르는 작은 빛(BossFx 풀 - 동시 상한)
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
}

return BossArenaDressData
