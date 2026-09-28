-- QUEUE-10h Q9 K4 직업옵션(스킬 변형) - 장비에 붙는 "자기 직업 스킬 하나를 ±5% 맞교환으로 바꾸는" 옵션. 계산 = shared/SkillVariant.lua · 적용 = server/SkillStats(피해 계수 · 쿨다운 · 범위 한 곳).
--   출현: 장비 드랍 중 옵션이 붙는 등급(영웅 이상 - Option 풀과 같은 문턱)의 appearChance · 받는 사람 직업의 스킬(Q · E · R)만. 궁극기(T)는 제외(결정 필요 - 약하게 넣을지).
--   적용: 착용 3부위 중 지금 직업과 같은 변형만 · 같은 칸이 여럿이면 높은 등급 하나(칸당 1개). 직업을 바꾸면 다른 직업 변형은 회색(꺼짐).
--   리롤: 같은 직업 풀에서 다시 굴림(rollWeights - 확률 공개 단일 소스 · SkillVariant.disclosure) · 가격 = GoldCost "variantReroll" × rerollKills.
--   templates: 곱(damage · cooldown · range) - 한쪽 + 다른 쪽 −(sidegrade). 이름 = 표시 이름(번역 = L 단계).
return {
	appearChance = 0.10,
	rerollKills = 200,
	templates = {
		wide = { name = "넓게", damage = 0.95, range = 1.05 },
		swift = { name = "재빠르게", damage = 0.95, cooldown = 0.95 },
		heavy = { name = "묵직하게", damage = 1.05, cooldown = 1.05 },
		far = { name = "멀리", range = 1.05, cooldown = 1.05 }, -- 피해 계수가 없는 범위 스킬용 맞교환(Play E 리뷰 - wide는 피해 −5%가 안 먹어 순수 이득이었다)
	},
	-- 직업 · 칸마다 가능한 변형(1 ~ 2개) · 가중치(정수 - 확률 공개)
	-- 칸마다 "실제로 먹는 축 두 개"만(피해 = coefficient · 범위 = rangeStuds/radiusStuds/lengthStuds · 쿨). 두 번째 축이 없는 칸(활 Q · 쌍검 Q · 치유사 Q · E)은 비운다.
	pools = {
		greatsword = { Q = { { id = "wide", w = 1 }, { id = "heavy", w = 1 } }, E = { { id = "wide", w = 1 }, { id = "swift", w = 1 } }, R = { { id = "far", w = 1 } } },
		dualblade = { E = { { id = "heavy", w = 1 }, { id = "swift", w = 1 } }, R = { { id = "far", w = 1 } } },
		bow = { E = { { id = "far", w = 1 } }, R = { { id = "heavy", w = 1 }, { id = "swift", w = 1 } } },
		healer = { R = { { id = "far", w = 1 } } },
	},
	slots = { "Q", "E", "R" },
}
