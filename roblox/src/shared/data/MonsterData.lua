-- 몬스터 tier 1~6 데이터(9-4 단일 tier1 → 16-6 6종 확장). 웹에서 가져오는 건 6종의
-- 이름뿐이다(딱딱꼬물이~폭군드래곤, 각 tier의 "탱커형" 대표 하나) - HP·공격력·골드는
-- 전부 아래 공정성 관계식으로 계산한다(웹 원본 수치는 절대 안 쓴다). 이유: 웹은 tier가
-- 곧 진행도축이었지만(tier가 오르며 몬스터·보상·플레이어 파워가 다 같이 컸다), 로블록스는
-- tier(구역, 유한 6~8종)와 무한 스테이지(아이템레벨, 무한)를 직교시킨다 - 진행도의
-- 대부분은 InfiniteStage 배율이 이미 전담하므로 tier 자체의 HP 스펙트럼은 웹보다
-- 훨씬 완만해야 맞다(16-6 세션에서 실측 비교로 확인 - 웹 889배 vs 이 식 17.6배, 사용자
-- 승인 완료).
--
-- tier1은 기존 값(hp=80, attack=8, goldDrop=6)을 앵커로 그대로 둔다 - InfiniteStageConfig.
-- growthRate 계수·BossRules의 보스 스케일링이 전부 이 값을 기준으로 이미 맞춰져 있어서
-- (InfiniteStageConfig.lua 주석 참고), 바꾸면 무한 모드 밸런스 전체가 흔들린다.
--
-- 관계식(16-6, 사용자 확정 — b가 약분돼 tier1까지 같이 커지는 형식화 오류를 지적받고
-- 고친 최종판):
--   E[g|t] = Σ (DROP_GRADE_TABLE[t][등급] × ArmorData.grades[등급].defenseGradeMultiplier)
--   r(t)   = E[g|t] / E[g|1]                              -- "같은 시간에 얻는 장비 가치" 비
--   HP배율        = r(t)^p
--   공격력 배율    = r(t)^(p-1)
--   itemLevel보너스 = r(t)^(p-1)      -- 다음 세션이 드랍표에 연결할 자리(아직 안 씀)
--   골드 배율      = r(t)^p
--   p = 2 (튜닝 노브는 이것 하나)
-- 공정성 항등식: 시간당보상 = (itemLevel보너스 × E[g|t]) / HP배율
--             = (r^(p-1) × r × E[g|1]) / r^p = E[g|1]  (t에 무관 - 아래 코드가 6개 tier
--             전부 이 값을 실제로 계산해 검증한다).
-- 공격력이 HP보다 낮은 지수(p-1=1)를 쓰는 이유: 드래곤은 "오래 걸리는" 몬스터지 "한
-- 방에 죽이는" 몬스터가 아니어야 한다 - 그래야 1층 장비로도 6층에 가서 드래곤을 잡는
-- 파밍 경로가 성립한다(지시 그대로).
--
-- 몬스터 방어력 개념은 로블록스에 아예 없다(플레이어→몬스터 데미지는 뺄셈 없이 그대로
-- HP에서 깎인다, AttackServer.server.lua) - 도입하지 않는다(지시).
-- 이동속도는 전 tier 공통(지시) - moveSpeedStuds를 tier마다 다르게 만들지 않는다.

local ArmorData = require(script.Parent.ArmorData)
local CombatConfig = require(script.Parent.CombatConfig)

local MonsterData = {}

-- 드랍 등급 확률표(웹 data/items.js DROP_GRADE_TABLE, 16-5 조사로 확인한 값 그대로,
-- index=tier). 이번 세션은 이 표를 실제 드랍 판정에 연결하지 않는다(다음 세션 몫) - 지금은
-- tier별 "기대 장비 가치" E[g|t]를 계산하는 입력으로만 쓴다. 다음 세션이 드랍표를 열 때
-- 이 자리에서 그대로 가져다 쓰면 된다(단일 출처 유지).
MonsterData.dropGradeTableByTier = {
	{ normal = 0.90, rare = 0.10 },
	{ normal = 0.70, rare = 0.27, epic = 0.03 },
	{ normal = 0.45, rare = 0.40, epic = 0.14, legendary = 0.01 },
	{ normal = 0.20, rare = 0.40, epic = 0.30, legendary = 0.09, relic = 0.01 },
	{ normal = 0.05, rare = 0.25, epic = 0.40, legendary = 0.25, relic = 0.045, ancient = 0.005 },
	{ rare = 0.10, epic = 0.30, legendary = 0.40, relic = 0.18, ancient = 0.019, primordial = 0.001 },
}

MonsterData.fairnessExponent = 2 -- p. 이 값 하나만 튜닝 노브다.

local function expectedGradeValue(tierIndex)
	local row = MonsterData.dropGradeTableByTier[tierIndex]
	local sum = 0
	for gradeId, chance in pairs(row) do
		sum += chance * ArmorData.grades[gradeId].defenseGradeMultiplier
	end
	return sum
end

local BASE_E = expectedGradeValue(1)

-- r(t) = E[g|t]/E[g|1]. 다음 세션(드랍표 연결)도 이 함수를 그대로 재사용할 수 있다.
function MonsterData.getRewardRatio(tierIndex)
	return expectedGradeValue(tierIndex) / BASE_E
end

-- tier 순서 + 웹에서 가져온 이름(각 tier의 "탱커형" 대표 하나, 16-6 조사)뿐 - 나머지는
-- 전부 아래에서 관계식으로 계산한다.
local TIER_INFO = {
	{ key = "tier1", displayName = "딱딱꼬물이", bodyColor = Color3.fromRGB(111, 158, 76) },
	{ key = "tier2", displayName = "찐득슬라임", bodyColor = Color3.fromRGB(63, 142, 92) },
	{ key = "tier3", displayName = "굳센고블린", bodyColor = Color3.fromRGB(74, 122, 46) },
	{ key = "tier4", displayName = "육중오크", bodyColor = Color3.fromRGB(168, 95, 38) },
	{ key = "tier5", displayName = "거대트롤", bodyColor = Color3.fromRGB(106, 63, 142) },
	{ key = "tier6", displayName = "폭군드래곤", bodyColor = Color3.fromRGB(224, 80, 92) },
}

MonsterData.tierOrder = {}
for _, info in ipairs(TIER_INFO) do
	table.insert(MonsterData.tierOrder, info.key)
end

-- tier1 앵커(위 주석 참고 - 절대 바꾸지 않는다). 나머지는 r(t)로 유도한다.
local BASE_HP, BASE_ATTACK, BASE_GOLD = 80, 8, 6
local BASE_RADIUS_PX = 12

local function blendTowardWhite(color, ratio)
	return Color3.new(
		color.R + (1 - color.R) * ratio,
		color.G + (1 - color.G) * ratio,
		color.B + (1 - color.B) * ratio
	)
end

for tierIndex, info in ipairs(TIER_INFO) do
	local r = MonsterData.getRewardRatio(tierIndex)
	local p = MonsterData.fairnessExponent
	local hpMultiplier = r ^ p
	local attackMultiplier = r ^ (p - 1)
	local goldMultiplier = r ^ p
	local itemLevelBonus = r ^ (p - 1) -- 다음 세션이 드랍표에 연결하기 전까지는 아무도 안 읽는다.
	local sizeScale = r ^ 0.5

	local hp = BASE_HP * hpMultiplier
	local attack = BASE_ATTACK * attackMultiplier
	local goldDrop = BASE_GOLD * goldMultiplier

	MonsterData[info.key] = {
		id = info.key,
		tierIndex = tierIndex,
		displayName = info.displayName,
		hp = hp,
		attack = attack,
		-- 처치 경험치(13-2) - tier1이 이미 goldDrop/2 비율을 썼다(웹 전 몬스터 공통 비율을
		-- 재사용한 값, 원래 MonsterData.lua 주석 참고) - 다른 tier도 같은 비율을 유지한다.
		goldDrop = goldDrop,
		expReward = goldDrop / 2,
		itemLevelBonus = itemLevelBonus,
		rewardRatio = r,

		radiusPx = BASE_RADIUS_PX * sizeScale,
		sizeScale = sizeScale,
		bodyColor = info.bodyColor,
		headColor = blendTowardWhite(info.bodyColor, 0.3),

		-- 지시 - 이동속도는 전 tier 공통, 사거리·쿨다운도 이번엔 안 바꾼다.
		moveSpeedStuds = 10,
		attackRangeStuds = CombatConfig.attackRangeStuds,
		attackCooldownSeconds = 1.0,
	}
end

-- 공정성 항등식 자체 검증용 데이터(16-6 지시 - "6개 tier 전부 수치로 확인하고 결과를
-- 보여줘라"). 이 모듈은 데이터만 계산해 두고, 실제 콘솔 출력은 HuntingGround.server.lua가
-- 서버 시작 시 한 번 찍는다(데이터 모듈에 print 부작용을 두지 않는다는 이 프로젝트
-- 관례를 따른다) - 코드가 계산한 값이 사람이 손으로 검산한 값과 실행 시점에 항상
-- 같은지 죽은 주석이 아니라 실제 로그로 재확인한다.
MonsterData.fairnessCheck = {}
for tierIndex = 1, #TIER_INFO do
	local r = MonsterData.getRewardRatio(tierIndex)
	local p = MonsterData.fairnessExponent
	local hpMultiplier = r ^ p
	local itemLevelBonus = r ^ (p - 1)
	local eGT = expectedGradeValue(tierIndex)
	local rewardPerTime = (itemLevelBonus * eGT) / hpMultiplier
	table.insert(MonsterData.fairnessCheck, {
		tier = tierIndex,
		r = r,
		rewardPerTime = rewardPerTime,
	})
end

return MonsterData
