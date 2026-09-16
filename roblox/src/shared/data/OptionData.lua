-- 보석·장비 통합 옵션 표(26-1, PRD-forge-game-roblox.md 20.67 [2][3] 그대로). 이 절이 도입하는
-- 유일한 새 상수가 이 파일이다 - "태초 기준값"·"합산 상한" 두 열 외에는 전부 기존 데이터
-- (ItemVisualData.gradeVisuals.statMultiplier·CharacterLevelConfig.statBonusPerLevel·
-- BalanceAnchorConfig.referenceLevel·GemData.survivalReductionAtAnchor)에서 계산한다 - 실제
-- 계산은 Option.lua가 한다(단일 출처, GemData/Gem.lua와 같은 분리 원칙).
--
-- 16종 = 공통 8(commonOrder) + 직업 특화 8(classId당 2, classSkillOptions). 공통 8은 드랍·
-- 환생 지급·리롤 풀에서 항상 후보이고, 직업 특화는 "그 순간 플레이어의 직업" 2종만 후보에
-- 더해진다(20.67 [1] "드랍·환생·변환권 세 경로 모두 같다"). 풀은 10종 균등 확률(Option.lua).
--
-- displayName이 없는 항목(직업 특화 8종)은 의도적이다 - 20.67 [2] "직업 특화의 표시명은
-- SkillData[classId][slot].name을 그대로 읽는다(이름 중복 정의 금지)". Option.lua가 필요할 때
-- SkillData에서 직접 읽는다.
--
-- minGradeIndex=3(ArmorData.gradeOrder: 1=일반, 2=희귀, 3=영웅부터) - "일반·희귀 장비는 옵션이
-- 없다"(20.67 [1]), 보석도 같은 경계에서만 존재한다(PlayerProfile.DISMANTLE_MIN_GRADE_INDEX와
-- 같은 값, 우연이 아니라 "보석=영웅 이상 장비의 옵션"이라는 항등식 때문이다).
--
-- rollMin/rollMax=U[0.875,1.125] - 20.67 [4] "폭이 인접비의 절반을 넘지 않게" 도출한 값
-- (인접비 최소 1.5 → w≤0.125). 롤은 균등분포(임의 결정 5, 게이지 위치=실제 확률 위치).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemData = require(ReplicatedStorage.Shared.data.GemData)

return {
	minGradeIndex = 3,
	rollMin = 0.875,
	rollMax = 1.125,

	-- 드랍·환생·리롤 풀에 항상 들어가는 공통 8종의 결정적 순서(순회 순서 보장 - ArmorData.
	-- gradeOrder와 같은 이유).
	commonOrder = {
		"attackPercent", "speedPercent", "crit", "maxHpPercent",
		"defensePercent", "expGain", "healingPower", "lifesteal",
	},

	-- 옵션 정의. category: "dps"/"survival"/"utility"/"classSkill"(20.67 [5] 카테고리 구분 -
	-- 카테고리 안에서만 등가, 카테고리 사이엔 등가를 두지 않는다). cap=nil은 "합산 상한 없음"
	-- (20.67 [7] - 자기 제한적이거나 별도 상한이 실효인 축).
	options = {
		attackPercent = { displayName = "위력", category = "dps", baseValue = 0.30, cap = nil },
		speedPercent = { displayName = "신속", category = "dps", baseValue = 0.30, cap = nil },
		-- 치명: 치확 +a%p·치피 +b(각각 독립 롤) - a=b=21%p(20.67 [6-3], 활 기준 위력 등가 해).
		crit = { displayName = "치명", category = "dps", critRateBase = 0.21, critDmgBase = 0.21, cap = nil },
		maxHpPercent = { displayName = "건강", category = "survival", baseValue = 0.10, cap = 0.20 },
		-- 방어: 생존 기여를 건강과 맞추려면 ρ(GemData.survivalReductionAtAnchor)로 나눈 값이
		-- 필요하다(20.67 [3] "value = ... × ρ 보정", Gem.lua의 옛 AXIS_CORRECTION.defensePercent와
		-- 같은 식) - 10%라는 새 상수를 다시 만들지 않고 maxHpPercent의 태초 기준값을 그대로
		-- 재사용해 도출한다.
		defensePercent = { displayName = "방어", category = "survival", baseValue = 0.10 / GemData.survivalReductionAtAnchor, cap = 0.32 },
		expGain = { displayName = "성장", category = "utility", baseValue = 0.125, cap = 0.25 },
		healingPower = { displayName = "재생", category = "utility", baseValue = 0.20, cap = 1.00 },
		-- 흡혈: %합산 상한은 없다(20.67 [6-1] - 초당 흡수 상한이 실효 상한이고, 그 상한 자체는
		-- 이번 범위 밖인 흡혈 축 연결(20.67 [14] 4단계)에서 도입한다).
		lifesteal = { displayName = "흡혈", category = "utility", baseValue = 0.03, cap = nil },

		-- 직업 특화 8종(20.67 [2][8]). classId·slot은 SkillData[classId][slot]을 가리킨다 -
		-- 표시명은 여기 두지 않고 그 데이터에서 읽는다(위 모듈 주석).
		skill_greatsword_Q = { classId = "greatsword", slot = "Q", category = "classSkill", baseValue = 0.90, cap = nil },
		skill_greatsword_E = { classId = "greatsword", slot = "E", category = "classSkill", baseValue = 0.90, cap = nil },
		-- 속사: 배율 2.5 상한(기존 attackSpeedCap)이 실효 상한이라 %합산 상한을 따로 두지 않는다.
		skill_bow_Q = { classId = "bow", slot = "Q", category = "classSkill", baseValue = 0.60, cap = nil },
		skill_bow_E = { classId = "bow", slot = "E", category = "classSkill", baseValue = -0.30, cap = 0.50 },
		-- 그림자분신: 지속 ≤ 쿨다운(14초)이 되도록 상한 180%.
		skill_dualblade_Q = { classId = "dualblade", slot = "Q", category = "classSkill", baseValue = 0.60, cap = 1.80 },
		skill_dualblade_E = { classId = "dualblade", slot = "E", category = "classSkill", baseValue = 1.20, cap = nil },
		skill_healer_Q = { classId = "healer", slot = "Q", category = "classSkill", baseValue = -0.30, cap = 0.50 },
		skill_healer_E = { classId = "healer", slot = "E", category = "classSkill", baseValue = -0.60, cap = 0.90 },
	},

	-- classId → 그 직업이 드랍·환생·리롤 풀에 더하는 옵션 id 2개(Q·E 순서).
	classSkillOptions = {
		greatsword = { "skill_greatsword_Q", "skill_greatsword_E" },
		dualblade = { "skill_dualblade_Q", "skill_dualblade_E" },
		bow = { "skill_bow_Q", "skill_bow_E" },
		healer = { "skill_healer_Q", "skill_healer_E" },
	},
}
