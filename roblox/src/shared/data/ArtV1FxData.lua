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
		rare = { glow = { height = 4, width = 0.5, transparency = 0.55 }, motes = 0 },
		epic = { glow = { height = 6, width = 0.7, transparency = 0.6 }, motes = 2 },
		legendary = { glow = { height = 13, width = 0.9, transparency = 0.6 }, motes = 4, ring = 9 },
		relic = { glow = { height = 18, width = 1.1, transparency = 0.58 }, motes = 6, ring = 11 },
		ancient = { glow = { height = 23, width = 1.3, transparency = 0.55 }, motes = 8, ring = 13, flash = 3 },
		primordial = { glow = { height = 30, width = 1.6, transparency = 0.5, rim = C(255, 60, 200), core = C(255, 255, 255) }, motes = 10, ring = 16, flash = 4 },
		transcendent = { glow = { height = 36, width = 1.8, transparency = 0.25, rim = GOLD, core = BLACK }, motes = 12, ring = 18, flash = 4, moteColor = C(255, 208, 92) },
		moteLifetime = 1.6, moteSpeed = 3.2, moteSize = 0.28, ringSeconds = 0.7, flashSeconds = 0.18,
		transcendentColor = GOLD, -- ItemVisualData 초월 색과 같다(땅 드랍 표시 전용)
	},

	levelUp = { seconds = 1.0, ringSize = 6, ringColor = C(255, 244, 170), flashColor = C(255, 255, 255), particles = 16, particleColor = C(255, 226, 90), speed = 9, spread = 25, gravity = 4, size = 0.35 },

	hatch = { -- 부화 결과 펫 등급(EggData.hatchGrades) - 한 단계씩 커진다(링 · 입자 · 기둥)
		common = { color = C(240, 240, 232), ring = 5, particles = 8, pillar = nil },
		uncommon = { color = C(126, 214, 110), ring = 7, particles = 12, pillar = nil },
		rare = { color = C(90, 170, 255), ring = 9, particles = 16, pillar = { height = 8, width = 1.0 } },
		epic = { color = C(190, 110, 255), ring = 11, particles = 20, pillar = { height = 12, width = 1.3 }, flash = 3 },
		seconds = 1.2, speed = 8, spread = 60, gravity = 10, size = 0.4,
	},

	rebirth = { seconds = 1.6, color = C(140, 110, 230), light = C(214, 200, 255), pillar = { height = 16, width = 2.2, topWidth = 0.6 }, rings = { 8, 14 }, particles = 20, speed = 10, spread = 30, gravity = -2, size = 0.45,
		screenFlash = { brightness = 0.1, seconds = 0.22 } },

	enhanceFail = {
		maintain = { smoke = 4, pieces = 0, ring = nil },
		down = { smoke = 6, pieces = 6, ring = 5 },
		smokeColor = C(150, 146, 152), pieceColor = C(96, 96, 108), ringColor = C(70, 66, 84),
		smokeSize = 1.1, smokeSpeed = 2.5, pieceSize = 0.25, pieceSpeed = 6, seconds = 0.8,
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
		hitRingSeconds = 0.18, hitRingSize = 3.2, critRingSize = 4.6, critCore = C(255, 250, 240), critRim = C(255, 226, 110), -- 치명 테 = 금노랑(색상 51° - 위험색 330 ~ 50° 밖)
		heavyRingSize = 6, heavyRingSeconds = 0.26, ultRingSize = 14, ultRingSeconds = 0.45, ringThick = 0.12,
		allyOpacityInBoss = 0.5, -- 보스전 중 아군 연출 불투명도 상한(§5)
	},
}
