-- 견습 모드(튜토리얼, 23-1) 7단계 데이터. PRD-forge-game-roblox.md 20.47 [1]의 단계표를
-- 옮기되, tier 6종을 실제로 매핑하면서 어긋나는 부분(아래 [매핑]·[난이도] 설명)은 이번
-- 세션이 새로 유도했다 - 보고서의 "임의 결정" 목록 참고.
--
-- [매핑] 몬스터는 기존 tier 6종을 재사용한다(새 몬스터 금지, 지시 그대로). 7단계인데 tier가
-- 6종이라 1:1이 안 된다 - 등급표(ArmorData.gradeOrder, 일반→태초)와 tier(슬라임→드래곤)를
-- 그대로 나란히 두고 7단계(태초)만 6단계(고대)와 같은 tier6(드래곤)를 재사용한다. 근거:
-- (1) 등급·tier 둘 다 "오름차순 하나의 축"이라 나란히 두는 게 가장 단순하고 기억하기 쉽다.
-- (2) tier6가 이미 최상위 tier라 마지막 두 단계(고대·태초)가 "같은 구역에서 한 번 더"가
-- 되는 건 자연스럽다 - 7단계 "졸업 시험"이 6단계보다 쉬워 보이면 안 되는데, 마지막 두
-- 단계를 같은(가장 강한) tier에 두면 그 문제가 안 생긴다.
--
-- [난이도] PRD 20.47[1](마)의 "잡몹 stage(1,2,3,5,7,9,12)" 곡선은 전 단계가 tier1(슬라임)
-- 하나라는 전제 위에서 유도됐다(그 절의 처치시간 계산이 tier를 언급하지 않는다) - tier
-- 6종을 실제로 섞으면 전제 자체가 바뀐다. tier의 HP 배율(MonsterData.getRewardRatio^p,
-- tier1~6 = ×1.0~×17.7, git log 확인)이 이미 sole 성장축이 되도록 monsterStage는 전 단계
-- 공통 1로 고정한다(새 stage 곡선을 따로 만들지 않는다 - "PRD에 없으면 가장 단순한 값"
-- 원칙). 잡몹은 3~5분 예산 안에서 이 정도 변동(약 2.5~2.6배)을 그대로 흡수하지만, 보스는
-- hpMultiplier(=20, BossData)가 tier 배율을 한 번 더 곱해 30초~1분 예산을 크게 넘긴다(계산은
-- 아래 bossHpScale 주석) - 그래서 보스 HP 배율(tutorialBossHpScale)만 tier별로 역산해
-- 상쇄한다. 잡몹 stage는 그대로 두고(예산 안에서 흡수) 보스만 보정하는 게 "필요한 곳만
-- 최소로 고친다"는 이 프로젝트 원칙과 맞는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local TutorialData = {}

-- PRD 20.47[1](마)의 0.5를 그대로 기준(BASE)으로 두고, tier의 HP 배율(r(tier)^p)로
-- 나눠 tier1 기준선으로 되돌린다 - 그래야 "순딜 60초×0.5=30초, 회피 포함 ≈45초"라는 PRD의
-- 원래 계산이 tier가 몇이든 그대로 유지된다(BASE_HP_SCALE × r^p × hpMultiplier(20) = 항상
-- 같은 값). 새 상수를 추가하는 게 아니라 기존 상수(0.5)를 기존 관계식(r(t)^p)으로 나눈
-- 값이다 - MonsterData.getRewardRatio/fairnessExponent를 그대로 재사용한다.
local BASE_TUTORIAL_BOSS_HP_SCALE = 0.5

local function bossHpScaleFor(tierIndex)
	local r = MonsterData.getRewardRatio(tierIndex)
	return BASE_TUTORIAL_BOSS_HP_SCALE / (r ^ MonsterData.fairnessExponent)
end

-- 보스 패턴 부분집합(BossData.bosses.section_guardian.skills의 부분집합 - 29-2부터 견습 보스는 이 보스로 고정, 새 보스 금지 -
-- PRD 그대로 "같은 보스 id에 patterns 부분집합만 넘기는 방식"). 강공격(heavy)은 필드가 아니라
-- BossData 자체의 상시 동작이라 목록에 없어도 항상 나온다(1단계 "강공격"이 그 뜻).
local NO_PATTERNS = {}
local UP_TO_SHOCKWAVE = { "shockwave" }
local UP_TO_CHARGE = { "shockwave", "charge" }
local UP_TO_METEOR = { "shockwave", "charge", "meteor" }
local ALL_PATTERNS = { "shockwave", "charge", "meteor", "cross" }

-- steps[n] = { grade, tierIndex, zoneKey, killTarget, lessonText, grant | nil, lend | nil,
--              bossPatternKeys, bossHpScale }
-- friendHintText(1단계만, 선택) = 안내 토스트 끝에 붙는 친구 부르기 한 줄.
-- grant(1~3단계, 영구 지급) = { part, grade } - 보스 첫 처치 확정 드랍(Loot.buildFixedArmorDrop).
-- lend(4~7단계, 대여) = { weaponGrade(0~6), armorGrade(3~7단계에서 nil 아니면 3부위 세트) } -
--   대여는 별도 슬롯이 아니라 classState.weapon.grade/equipment를 직접 덮어쓰고 보스 클리어
--   시(또는 견습 종료 시) 원래 값으로 되돌린다("임의 결정" 목록 참고 - 대여 전용 슬롯 UI는
--   이번 세션 범위 밖).
TutorialData.steps = {
	[1] = {
		grade = "normal",
		tierIndex = 1,
		killTarget = 25,
		lessonText = "이동(WASD/조이스틱)과 클릭·탭 공격을 배워보세요. 슬라임을 처치하면 드랍이 떨어집니다 - I키로 가방을 열어 착용하세요.",
		-- 안내 뒤에 한 줄 더(S12, PRD 20.73 [7-1]) - 클라 안내 토스트가 lessonText 아래에 붙이고, 같은 단계에서 [친구 부르기] 버튼이 강조된다. 다른 단계는 필드가 없다.
		friendHintText = "친구가 있다면 지금 불러도 됩니다 - 레벨이 달라도 같은 슬라임을 같이 잡을 수 있어요.",
		grant = { part = "armor", grade = "normal" },
		lend = nil,
		bossPatternKeys = NO_PATTERNS,
	},
	[2] = {
		grade = "rare",
		tierIndex = 2,
		killTarget = 28,
		lessonText = "등급마다 색이 다릅니다. 장갑(공격력%)을 착용하고, 강화대에서 첫 강화를 해보세요. Shift로 대시할 수 있습니다.",
		grant = { part = "gloves", grade = "rare" },
		lend = nil,
		bossPatternKeys = UP_TO_SHOCKWAVE,
	},
	[3] = {
		grade = "epic",
		tierIndex = 3,
		killTarget = 28,
		lessonText = "신발(이동+공속%)까지 착용하면 3부위 완성입니다. Q로 스킬을 써보세요.",
		grant = { part = "shoes", grade = "epic" },
		lend = nil,
		bossPatternKeys = UP_TO_CHARGE,
	},
	[4] = {
		grade = "legendary",
		tierIndex = 4,
		killTarget = 28,
		lessonText = "무기 등급은 강화가 아니라 환생으로만 오릅니다. 전설 무기를 잠시 빌려드립니다 - E 스킬도 써보세요.",
		grant = nil,
		lend = { weaponGrade = 3 },
		bossPatternKeys = UP_TO_METEOR,
	},
	[5] = {
		grade = "relic",
		tierIndex = 5,
		killTarget = 28,
		lessonText = "유물 무기와 3부위 풀세트를 빌려드립니다 - 처치 속도가 얼마나 달라지는지 느껴보세요.",
		grant = nil,
		lend = { weaponGrade = 4, armorGrade = "relic" },
		bossPatternKeys = ALL_PATTERNS,
	},
	[6] = {
		grade = "ancient",
		tierIndex = 6,
		killTarget = 28,
		lessonText = "고대 무기와 3부위를 빌려드립니다. 보스 체력이 낮아지면(격노) 패턴이 더 자주 나옵니다.",
		grant = nil,
		lend = { weaponGrade = 5, armorGrade = "ancient" },
		bossPatternKeys = ALL_PATTERNS,
	},
	[7] = {
		grade = "primordial",
		tierIndex = 6,
		killTarget = 28,
		lessonText = "마지막 단계입니다. 태초 무기와 3부위를 빌려드립니다 - 환생 5회 + 보석 5개를 모으면 당신 것이 됩니다.",
		grant = nil,
		lend = { weaponGrade = 6, armorGrade = "primordial" },
		bossPatternKeys = ALL_PATTERNS,
		isFinal = true,
	},
}

for _, step in pairs(TutorialData.steps) do
	step.zoneKey = MonsterData.tierOrder[step.tierIndex]
	step.bossHpScale = bossHpScaleFor(step.tierIndex)
end

TutorialData.stepCount = 7

-- 잡몹·보스 모두 이 값으로 InfiniteStage.getMonsterHp/getMonsterAttack 등을 호출한다(위
-- [난이도] 주석 - tier 배율이 유일한 성장축이라 stage 자체는 전 단계 공통 1).
TutorialData.monsterStage = 1

-- 단계 상한(20.47[1](마) "숫자만 1,800→300초로 개정"). 만료되면 목표를 못 채웠어도
-- 자동으로 보스 도전을 시작한다.
TutorialData.stepTimeLimitSeconds = 300

-- 튜토리얼 보스는 대여 무기 배율(m_g)을 HP에 한 번 더 곱한다(20.47[1](마) "대여 무기 배율을
-- 곱하지 않으면 7단계 보스가 4~6초에 죽어 패턴을 못 본다") - 플레이어 DPS도 같은 배율로
-- 커지므로 순딜 시간 자체는 이 배율과 무관하게 유지된다(위 bossHpScale 주석과 같은 상쇄 원리).
function TutorialData.bossWeaponMultiplier(step)
	local lend = TutorialData.steps[step].lend
	if not lend then
		return 1
	end
	local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
	local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
	local gradeId = ArmorData.gradeOrder[lend.weaponGrade + 1]
	return ItemVisualData.gradeVisuals[gradeId].statMultiplier
end

-- 완료 보상(20.47[1](사)). 계산 근거: 무한 모드 스테이지1 골드 6/마리 -> 500골드 ≈ 83마리
-- ≈ 5분 파밍 상당. 강화 +1~+8 시도 합(EnhanceConfig.goldCost)보다 적어 "첫 강화 몇 번 눌러볼
-- 돈"이지 강화 단계를 사는 돈이 아니다(PRD 그대로 - 새 상수지만 PRD가 이미 근거를 댄 값이라
-- 그대로 채택한다).
TutorialData.tutorialCompletionGold = 500

return TutorialData
