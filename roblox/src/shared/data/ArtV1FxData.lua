-- A2-N2 2-2 도파민 연출 · 2-4 전투 통일 규칙 값(ArtStyleV1 스위치 뒤 · 클라 전용 - client/ArtV1Fx · ArtV1Dopamine · ArtV1View). 표 = docs/art/art-direction-v1.md §5-1 · §5-2.
--   단계 규칙: 흰 번쩍(짧게) → 색 → 흩어짐. 위로 솟는 것 = 좋은 일 · 옆으로 퍼지는 것 = 타격 · 아래로 떨어지는 것 = 실패.
--   섬광(화면 밝기)은 Player Attribute ReduceFlashes = true면 전부 끈다. 보스전(Player Attribute BossEncounterId) 중에는 입자 × bossParticleScale.
local C = Color3.fromRGB

local GOLD = C(214, 176, 62)
local BLACK = C(24, 22, 32)

return {
	-- 폰 예산(§5-1)
	budget = { particles = 120, beams = 12, dropParticleDistance = 250, otherPlayerScale = 0.5, otherPlayerDistance = 120, bossParticleScale = 0.5 },

	-- 드랍 등급 8단계: glow = 번개(D1 DropLightning - 영웅부터) 뒤의 부드러운 빛 띠(Beam) · 높이 = PrimordialData.pillarHeights와 같은 단계(희귀 · 초월만 여기서)
	--   motes = 기둥을 타고 오르는 반짝이(rate × 수명 = 동시 수) · ring = 등장 때 바닥에서 퍼지는 링 · flash = 등장 흰 번쩍 공
	drop = {
		normal = { glow = nil, motes = 0 },
		rare = { glow = { height = 5, width = 0.8, transparency = 0.35 }, motes = 0 }, -- Play 2: 0.5 · 0.55는 번개 없는 희귀에서 거의 안 보였다
		epic = { glow = { height = 6, width = 0.7, transparency = 0.6 }, motes = 2 },
		legendary = { glow = { height = 13, width = 0.9, transparency = 0.45, color = C(255, 110, 20) }, motes = 4, ring = 9, ringColor = C(255, 130, 40), boltColor = C(255, 118, 30) }, -- Play 3 · 검토: 등급 주황이 블룸에서 노랑으로 번져 유물 금과 겹쳤다 → 빛 띠 · 링만 진한 주황(등급 색 자체는 그대로)
		relic = { glow = { height = 18, width = 1.1, transparency = 0.58 }, motes = 6, ring = 11 },
		ancient = { glow = { height = 23, width = 1.3, transparency = 0.55 }, motes = 8, ring = 13, flash = 3 },
		primordial = { glow = { height = 30, width = 1.6, transparency = 0.5, rim = C(255, 60, 200), core = C(255, 255, 255) }, motes = 10, ring = 16, flash = 4 },
		transcendent = { glow = { height = 36, width = 1.8, transparency = 0.1, rim = GOLD, core = BLACK }, motes = 12, ring = 18, flash = 4, moteColor = C(255, 208, 92) }, -- 검은 심 = 비발광 띠(ArtV1Dopamine)
		moteLifetime = 1.6, moteSpeed = 3.2, moteSize = 0.28, ringSeconds = 0.7, flashSeconds = 0.18,
		transcendentColor = GOLD, -- ItemVisualData 초월 색과 같다(땅 드랍 표시 전용)
		dropLightScale = 0.35, dropLightMaxRange = 10, -- 서버 드랍 광원 밝기 배율 · 범위 상한(이 화면만 - 검토: 여러 드랍이 겹쳐 잔디가 반경 10 넘게 흰노랑으로 탔다)
		glowEmission = 0.4, -- 색 빛 띠 발광(1 = 가산이면 블룸에서 전설 주황이 노랑으로 번져 유물 금과 겹쳤다) · 흰 심 = 1 · 검은 심 = 0
	},

	levelUp = { seconds = 1.0, ringSize = 6, ringColor = C(255, 244, 170), flashColor = C(255, 255, 255), particles = 16, particleColor = C(255, 226, 90), speed = 9, spread = 25, gravity = 4, size = 0.35 },

	hatch = { -- 부화 결과 펫 등급(EggData.hatchGrades) - 한 단계씩 커진다(링 · 입자 · 기둥)
		common = { color = C(240, 240, 232), ring = 5, particles = 8, pillar = nil },
		uncommon = { color = C(126, 214, 110), ring = 7, particles = 12, pillar = nil },
		rare = { color = C(90, 170, 255), ring = 9, particles = 16, pillar = { height = 8, width = 1.0 } },
		epic = { color = C(150, 80, 255), ring = 11, particles = 20, pillar = { height = 12, width = 1.3 }, flash = 3 }, -- Neon 링이 분홍으로 번져 보여 보라 쪽으로
		seconds = 1.2, speed = 8, spread = 60, gravity = 10, size = 0.4,
	},

	-- 환생: 기둥은 발광 0.5(Fx.pillar)라 채도 높은 보라 · 안쪽 금 링 = 부화와 구별하는 표식
	rebirth = { seconds = 1.6, color = C(170, 90, 255), light = C(214, 200, 255), innerRing = C(255, 215, 90), pillar = { height = 16, width = 2.2, topWidth = 0.6 }, rings = { 8, 14 }, particles = 20, speed = 10, spread = 30, gravity = -2, size = 0.45,
		screenFlash = { brightness = 0.1, seconds = 0.22 } },

	enhanceFail = {
		maintain = { smoke = 6, pieces = 0, ring = nil },
		down = { smoke = 9, pieces = 8, ring = 7 }, -- Play 3: 연기 4 · 링 5는 강화대 거리에서 거의 안 보였다
		smokeColor = C(150, 146, 152), pieceColor = C(96, 96, 108), ringColor = C(70, 66, 84),
		smokeSize = 1.6, smokeSpeed = 3, pieceSize = 0.35, pieceSpeed = 7, seconds = 0.8,
		smokeTexture = "rbxasset://textures/particles/smoke_main.dds",
	},

	-- 2-4 보스 전조 공통 규칙(가독성 최우선 - client/TelegraphStyle): 채움 = 각 연출 그대로(옅게 시작 → 진해짐) · 테두리 = 진한 위험색 · 두께 고정 · 처음부터 보임 · 터지기 직전만 깜빡
	telegraph = {
		rimColor = C(255, 84, 70), -- 위험색(UIColors.danger 226, 59, 59)보다 한 단계 밝게 - 채움 위에서 선으로 읽힌다
		rimTransparency = 0.05,
		rimStuds = 0.55, -- 원 · 선 테두리 두께(크기와 상관없이 같은 두께 = 폰 800 × 360에서 읽히는 최소)
		rimHeight = 0.08, -- 채움보다 이만큼 두껍게(겹침 깜빡임 방지)
		blinkBelow = 0.35, blinkHz = 7, -- 채움 투명도가 이 아래(= 예고가 거의 끝남)면 테두리가 깜빡인다
	},

	-- 2-4 전투 이펙트 통일(client/HitEffects - 옆으로 퍼지는 링 = 타격): 일반 = 흰 심 + 직업 강조색 링 · 치명 = 흰 심 + 금노랑 링 · 강공격(3타) = 링 한 겹 더 · 궁극기 = UltGauge(강조색 2겹 - 기존)
	combat = {
		hitRingSeconds = 0.18, hitRingSize = 4, critRingSize = 5.5, critCore = C(255, 250, 240), critRim = C(255, 226, 110), -- 치명 테 = 금노랑(색상 51° - 위험색 330 ~ 50° 밖)
		heavyRingSize = 7, heavyRingSeconds = 0.26, ultRingSize = 14, ultRingSeconds = 0.45, ringThick = 0.3, -- 검토: 0.12는 옅은 호 하나라 존재감이 없었다
		allyOpacityInBoss = 0.5, -- 보스전 중 아군 연출 불투명도 상한(§5)
	},
}
