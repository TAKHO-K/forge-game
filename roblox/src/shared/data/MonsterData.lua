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
local CharacterLevelConfig = require(script.Parent.CharacterLevelConfig)
local DropTableData = require(script.Parent.DropTableData)

local MonsterData = {}

-- 드랍 등급 확률표(웹 data/items.js DROP_GRADE_TABLE, 16-5 조사로 확인한 값 그대로,
-- index=tier). tier별 "기대 장비 가치" E[g|t] 계산의 입력이자, 17-1부터 Loot.rollArmorDrop이
-- 실제 드랍 판정에도 이 표를 그대로 읽는다(단일 출처 유지).
-- P2 E1: 표 자체는 드랍표 단일 소스(DropTableData.armorGradeByTier)로 옮겼다 - 이 이름은 그 표를 가리키는 별칭(값 · 공정성 계산 불변).
MonsterData.dropGradeTableByTier = DropTableData.armorGradeByTier

-- gradeOrder 안에서 gradeId의 위치(1부터). PlayerProfile.lua의 같은 이름 로컬 함수와
-- 동일한 패턴이다 - 공유 유틸이 아니라 각자의 파일 안에서만 쓰는 작은 헬퍼라 중복을
-- 그대로 둔다(PlayerProfile.lua는 판매 컷오프용, 여긴 아래 shiftGradeTableUp 전용).
local function gradeIndexOf(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 보스 첫 처치 확정 드랍 등급표(20-4, 지시 [1] "태초 희소성 복구"). tier6 표(환생 1회
-- 이상 - 재무장 특례 없음)를 등급 1단계씩 위로 미는 변환이다(환생 0회 - "재무장
-- 부트스트랩" 특례). 태초(gradeOrder 마지막)는 밀려날 자리가 없어 그대로 누적된다 -
-- tier6의 ancient(1.9%)+primordial(0.1%)가 합쳐져 결과 표의 primordial이 정확히 2%가
-- 된다(지시가 준 "태초2"와 일치 - 별도로 박아 넣은 숫자가 아니라 이 변환의 산출값이다).
local function shiftGradeTableUp(sourceRow)
	local shifted = {}
	for gradeId, chance in pairs(sourceRow) do
		local index = gradeIndexOf(gradeId)
		local targetIndex = math.min(index + 1, #ArmorData.gradeOrder)
		local targetGrade = ArmorData.gradeOrder[targetIndex]
		shifted[targetGrade] = (shifted[targetGrade] or 0) + chance
	end
	return shifted
end

-- G1-1: 보스 표는 드래곤 표와 따로 선언한다(DropTableData.bossGrades - 값은 옛 tier6 그대로).
MonsterData.bossFirstClearGradeTable = DropTableData.bossGrades.firstClear
MonsterData.bossFirstClearUpgradedGradeTable = shiftGradeTableUp(DropTableData.bossGrades.firstClear)

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

-- tier 순서 + 기본형 이름(22-2 [1] - 웹의 꼬물이~드래곤 계열에서 판타지 기본형으로 교체.
-- 유저가 이름만 보고 무엇인지 즉시 알아야 한다는 지시). 접두사 변종(MonsterPrefixData)이
-- 이 기본형 앞에 붙는다("단단한 슬라임"). 색은 20.27 아트 동결 그대로 둔다. 나머지는
-- 전부 아래에서 관계식으로 계산한다.
--   tier1 슬라임 - 판타지의 첫 몬스터, 젤리 실루엣. 초록 팔레트가 그대로 맞는다.
--   tier2 고블린 - 소형 인간형, "슬라임 다음"으로 누구나 아는 순서.
--   tier3 오크 - 대형 인간형, 고블린의 상위 종족이라는 관습.
--   tier4 트롤 - 거인 계열, 오크보다 크고 느린 덩치(HP 계열이 커지는 tier와 맞는다).
--   tier5 골렘 - 석상·정령 계열, 인간형 계보에서 벗어나 "다른 종류"로 읽힌다. 보라 팔레트가
--            수정 골렘으로 읽힌다. 와이번은 tier6 드래곤과 실루엣이 겹쳐 제외했다.
--   tier6 드래곤 - 최상위 관습. 붉은 팔레트 그대로.
local TIER_INFO = {
	{ key = "tier1", displayName = "슬라임", bodyColor = Color3.fromRGB(111, 158, 76) },
	{ key = "tier2", displayName = "고블린", bodyColor = Color3.fromRGB(63, 142, 92) },
	{ key = "tier3", displayName = "오크", bodyColor = Color3.fromRGB(74, 122, 46) },
	{ key = "tier4", displayName = "트롤", bodyColor = Color3.fromRGB(168, 95, 38) },
	{ key = "tier5", displayName = "골렘", bodyColor = Color3.fromRGB(106, 63, 142) },
	{ key = "tier6", displayName = "드래곤", bodyColor = Color3.fromRGB(224, 80, 92) },
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
	-- 28-1 [2-1] 이름 변경(옛 itemLevelBonus, 값은 그대로): itemLevel에 곱하던 값이 "기대 드랍 개수에 곱하는 값"이 됐다 -
	-- 공정성 항등식의 r^(p−1) 몫을 개수가 맡는다(Loot.expectedArmorDropCount). itemLevel은 스테이지가 정한다.
	local dropCountMultiplier = r ^ (p - 1)
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
		goldDrop = goldDrop,
		-- 처치 경험치(13-2, 17-1에서 공식 교체) - "몬스터 경험치는 그 몬스터의 최대 HP에
		-- 비례한다"(17-1 [0] 설계)는 원칙대로 hp × monsterExpCoefficient로 계산한다.
		-- InfiniteStage.getExpReward(entry.data.expReward, stage)가 이 stage1 기준값에
		-- 그대로 stage 배율을 곱하므로(goldDrop·attack과 같은 패턴), 실제 처치 시점 경험치는
		-- 결과적으로 "그 순간 몬스터의 최대 HP × coefficient"와 정확히 같다(HP도 같은
		-- 배율로 스케일되므로).
		expReward = hp * CharacterLevelConfig.monsterExpCoefficient,
		dropCountMultiplier = dropCountMultiplier,
		rewardRatio = r,

		radiusPx = BASE_RADIUS_PX * sizeScale,
		sizeScale = sizeScale,
		bodyColor = info.bodyColor,
		headColor = blendTowardWhite(info.bodyColor, 0.3),

		-- 지시 - 이동속도는 전 tier 공통, 사거리·쿨다운도 이번엔 안 바꾼다.
		moveSpeedStuds = 10,
		attackRangeStuds = CombatConfig.attackRangeStuds,
		attackCooldownSeconds = 1.0,
		-- 22-5: 잡몹 몸통 충돌을 껐으므로(MonsterSpawner, 밀려 떨어짐 사고 방지) 보스(BossData
		-- chaseStopDistanceStuds 8)와 같은 정지 거리가 필요하다 - 없으면 플레이어 좌표까지
		-- 파고들어 겹친다. 몸통 반폭(1.2×배율, tier6 1.8) + 캐릭터 반폭 1 + 여유 ≈ 4. 사거리
		-- 10 안이라 평타엔 영향이 없고, 어그로 25.6·리쉬 38.4 사슬과도 무관하다(정지는 대상
		-- 기준 거리, 리쉬는 집 기준 거리).
		chaseStopDistanceStuds = 4,
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
	local dropCountMultiplier = r ^ (p - 1)
	local eGT = expectedGradeValue(tierIndex)
	local rewardPerTime = (dropCountMultiplier * eGT) / hpMultiplier
	table.insert(MonsterData.fairnessCheck, {
		tier = tierIndex,
		r = r,
		rewardPerTime = rewardPerTime,
	})
end

return MonsterData
