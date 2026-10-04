-- QUEUE-ALL9E1 2-2 무기 이펙트 진화 단계표(사용자 결정 10-04 밤) - 아이콘 · 3D 이펙트가 같은 표를 읽는다(판정 = shared/WeaponFx.stepOf).
--   실제 모양(텍스처 · 파티클 · 색 확정)은 디자인 묶음(docs/phase/DESIGN-BACKLOG.md 9) - 지금은 표 · 판정 · 연결 지점만. 색 hex는 임시.
--   transcend[n + 1] = 초월 강화 +n(0 ~ 25)에서 "켜져 있는 것 전부"(누적값 - 앞 단계와 차이를 계산할 필요 없음).
--     큰 변화(major) = +5 검기 · +10 연기 오라 + 타격 파편 · +15 몸 오라 + 긴 검기 + 금가루 · +20 번개 균열 + 이중 검기 + 프리즘.
--     작은 변화 = 사이 단계마다 한 칸(+6 ~ 9 균열 줄 · 불티 / +11 ~ 14 빛살 · 맥동 / +16 ~ 19 빛 고리 조각 · 프리즘 / +21 ~ 25 별자리 점). +1 ~ +4 = +0과 같다(초월은 +6부터 매 단계).
--   enhanceHigh = 계승 전(초월 아닌 무기) 강화 +20 ~ +30 색 띠.
return {
	-- 이펙트 규칙(모양이 들어와도 지킨다)
	rules = {
		auraMaxStuds = 1.5, -- 무기 · 몸 주위 작은 오라 반경 상한
		screenAura = false, -- 화면 전체 오라 금지
		groundFx = false, -- 바닥 효과 금지(보스 경고 보호)
		othersInBossMultiplier = 0.5, -- 남의 효과 · 보스전
		phoneMaxEmittersPerWeapon = 2, -- 폰(터치 전용) 무기 1개당 이미터 상한
	},

	transcend = {
		{ step = 0, major = true, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "none", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 1, major = false, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "none", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 2, major = false, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "none", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 3, major = false, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "none", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 4, major = false, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "none", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 5, major = true, crackLines = 2, embers = 0, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 6, major = false, crackLines = 3, embers = 2, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 7, major = false, crackLines = 4, embers = 4, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 8, major = false, crackLines = 5, embers = 6, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 9, major = false, crackLines = 6, embers = 8, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = false, hitShards = false, bodyAura = false, goldDust = false, lightning = false },
		{ step = 10, major = true, crackLines = 6, embers = 8, rays = 0, pulse = 0, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = true, hitShards = true, bodyAura = false, goldDust = false, lightning = false },
		{ step = 11, major = false, crackLines = 6, embers = 8, rays = 1, pulse = 1, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = true, hitShards = true, bodyAura = false, goldDust = false, lightning = false },
		{ step = 12, major = false, crackLines = 6, embers = 8, rays = 2, pulse = 1, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = true, hitShards = true, bodyAura = false, goldDust = false, lightning = false },
		{ step = 13, major = false, crackLines = 6, embers = 8, rays = 3, pulse = 2, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = true, hitShards = true, bodyAura = false, goldDust = false, lightning = false },
		{ step = 14, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 0, prism = 0, constellation = 0, trail = "short", smokeAura = true, hitShards = true, bodyAura = false, goldDust = false, lightning = false },
		{ step = 15, major = true, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 0, prism = 0, constellation = 0, trail = "long", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = false },
		{ step = 16, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 1, prism = 0, constellation = 0, trail = "long", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = false },
		{ step = 17, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 2, prism = 0, constellation = 0, trail = "long", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = false },
		{ step = 18, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 3, prism = 1, constellation = 0, trail = "long", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = false },
		{ step = 19, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 2, ringShards = 4, prism = 1, constellation = 0, trail = "long", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = false },
		{ step = 20, major = true, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 0, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
		{ step = 21, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 1, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
		{ step = 22, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 2, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
		{ step = 23, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 3, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
		{ step = 24, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 4, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
		{ step = 25, major = false, crackLines = 6, embers = 8, rays = 4, pulse = 3, ringShards = 4, prism = 2, constellation = 5, trail = "dual", smokeAura = true, hitShards = true, bodyAura = true, goldDust = true, lightning = true },
	},

	-- 계승 전 강화 +20 ~ +30(초월 아닌 무기 · WeaponLevel) 색 띠 - fromLevel 이상이면 그 띠(위에서 아래로 높은 쪽)
	enhanceHigh = {
		{ fromLevel = 20, band = "silver", hex = "C9CED6" }, -- 은
		{ fromLevel = 22, band = "mint", hex = "8FE3C8" }, -- 민트
		{ fromLevel = 24, band = "sky", hex = "8CC8F0" }, -- 하늘
		{ fromLevel = 26, band = "aqua", hex = "4FD6D9" }, -- 아쿠아
		{ fromLevel = 28, band = "whiteSky", hex = "DDF1FF" }, -- 흰하늘
		{ fromLevel = 30, band = "platinum", hex = "F2EEE2" }, -- 백금
	},

	-- 실제 모양이 들어오기 전 3D 연출 = 기존 강화 연출(EnhanceVisualData) 이 단계로(초월 무기)
	transcendTempVisualLevel = 30,
}
