-- 갑옷 드랍 데이터(12-1, 17-1부터 7등급 전부 실제 드랍). 장갑·신발도 16-6부터 드랍된다 -
-- 랜덤/특수 옵션만 아직 범위 밖이다.
--
-- 등급 배율 출처: PRD-forge-game.md 7.0의 `ARMOR_DEFENSE_GRADE_MULTIPLIER`
-- (1.184/2.397/3.903/5.866/8.347/11.25/15.0, 일반~태초). `git log`/grep으로 확인한 결과
-- 이 표는 `data/items.js`에 실제 구현된 적이 없다(그 파일은 여전히 범용 ITEM_GRADES.
-- multiplier 1.0/1.4/2.0/...를 쓴다) - PRD 자체가 "방어구 전용 표를 새로 만든다"는
-- 설계 문구 그대로이고 웹 코드가 아직 안 따라간 상태이므로, "PRD가 나중"이 아니라
-- "PRD만 있고 웹은 구현한 적이 없다" - 비교할 웹 값 자체가 없으니 PRD를 그대로 쓴다.
--
-- 드랍률(dropChance)은 PRD 7.1 값을 그대로 쓴다 - 몬스터 전체 공통, tier와 무관하다.
-- 등급별 확률은 17-1부터 tier마다 다르다 - MonsterData.dropGradeTableByTier(16-6이 계산만
-- 해 뒀던 표)를 Loot.rollArmorDrop이 tierIndex로 직접 읽는다. 이 파일엔 더 이상 등급 확률
-- 표를 안 둔다(중복 출처 방지) - grades 아래의 defenseGradeMultiplier만 여기 남는다.
--
-- baseDefense=5는 CombatConfig.playerDefense와 같은 값이다 - 우연이 아니라, "일반 등급
-- 갑옷 하나가 지금 기본 방어력만큼을 더해준다"는 체감 기준으로 의도적으로 맞췄다(웹
-- ITEM_PART_BASE_STAT.armor.base=2는 웹 자체 파워 스케일 기준이라 그대로 옮기면 안
-- 된다 - ClassData critRate 주석과 같은 "출처가 다른 두 값" 원칙).
--
-- 레벨 스케일링(13-2로 12-1의 판단을 되돌림): 갑옷 방어력은 등급뿐 아니라 "획득 시점
-- 캐릭터 레벨"(itemLevel)에도 비례한다(CharacterLevel.getItemLevelMultiplier,
-- PRD-forge-game-roblox.md 20.11-4 "defenseFlat도 k로 키워야 방어력/몬스터공격력 비율이
-- 스테이지 무관 상수로 수렴한다"). 12-1 시점엔 로블록스에 캐릭터 레벨 축 자체가 없어
-- "주운 스테이지"(dropStage)를 대체재로 썼었다 - 20.22가 이 대체가 "막히면 아래에서
-- 파밍한다"는 설계와 어긋남을 확인했고(낮은 스테이지에서 주운 장비가 영구히 무력해짐),
-- 13-2가 캐릭터 레벨 축을 만들면서 원래 설계(itemLevel 기준)로 되돌렸다. 등급에만
-- 의존하면 레벨1에서 주운 희귀템이 영원히 가치를 유지해 "레벨을 올릴 이유"가 사라진다는
-- 점은 그대로다 - 축의 이름만 dropStage에서 itemLevel로 바뀌었다. 실제 계산·검증은
-- Loot.lua와 PRD 20.23 참고.

local CombatConfig = require(script.Parent.CombatConfig)
local ItemVisualData = require(script.Parent.ItemVisualData)
local InfiniteStage = require(game:GetService("ReplicatedStorage").Shared.InfiniteStage)

-- P2.5a R3: 갑옷 등급 배율도 1단계 = ×1.45(ItemVisualData.gradeStep) - 일반 1.184(옛 값 그대로)에서 시작해 1.184 × 1.45^(순서 − 1).
-- 옛 표 1.184 · 2.397 · 3.903 · 5.866 · 8.347 · 11.25 · 15.0. 이 표는 tier 공정성 r(t)(MonsterData)의 입력이라 tier별 몬스터 HP · 골드 배율도 따라 바뀐다(공정성 항등식은 그대로).
local ARMOR_NORMAL = 1.184
local STEP = ItemVisualData.gradeStep

-- D1(사용자 확정): 드랍 장비용 등급 위력표 - 상위 등급 가속. 일반 ~ 영웅 = 옛 값(1.45 단계) · 전설 ×1.5 · 유물 ×1.7 · 고대 ×2.0 · 태초 ×2.5(직전 등급 대비).
-- 누적 = 1.00 · 1.45 · 2.10 · 3.15 · 5.36 · 10.7 · 26.8. 드랍 장비(갑옷 방어 · 장갑 공격% · 신발 속도%)만 쓴다 - 무기 환생 등급 · 보석(옵션) 등급은
-- 옛 ItemVisualData.statMultiplier(1.45^n) 그대로(지시: 이번에 안 바꿈). 몬스터 tier 공정성 식(MonsterData)은 옛 배율(fairnessMultiplier)을 고정 입력으로 쓴다.
local DROP_STEPS = { 1, 1.45, 1.45, 1.5, 1.7, 2.0, 2.5 }
local dropPower = {}
do
	local acc = 1
	for i, step in ipairs(DROP_STEPS) do
		acc *= step
		dropPower[i] = acc
	end
end
-- D1-2(사용자 지시 - 태초 딜 부위 변별력): 장갑 · 신발(딜 부위) 태초 = 고대 × 이 배율. 갑옷 태초 방어(defenseGradeMultiplier)는 위 표 그대로(×2.5).
-- 비교 = ×1.0 · 1.2 · 1.25 · 1.3 · 1.6 · 2.0(보고서 D1-2 ②): 상한 도달 시간 비 ≤ 1.3을 두 프로필(상위 1% 1.26 · 일반 1.26) 모두 여유 있게 지키는 가장 큰 값 = 1.25(×1.3은 상위 1% 1.302).
-- "수렴 뒤 스테이지 차 ≤ 150"은 딜 우위가 조금이라도 있으면(×1.0 + 치명 피해 고유 효과도 +1,155) 못 맞춘다 - 결정 대기. 신발은 공격 속도 상한에 걸려 이 배율이 딜에 안 닿는다.
local DPS_PRIMORDIAL_STEP = 1.25

return {
	baseDefense = CombatConfig.playerDefense,
	dpsPrimordialStep = DPS_PRIMORDIAL_STEP, -- D1-2: 딜 부위 태초 = 고대 × 이 값(검증 · 보고서가 읽는다)

	-- 17-1부터 7등급 전부 실제로 드랍된다(16-6이 미뤄 뒀던 "드랍표 연결"). 오름차순 순서 -
	-- Loot.rollArmorDrop이 이 순서로 tier별 확률표를 굴리고(MonsterData.dropGradeTableByTier의
	-- 각 줄은 맵이라 순회 순서가 없다 - 이 배열이 결정적 순서를 정한다),
	-- Loot.rollBossFirstClearDrop의 등급 상향(MonsterData.shiftGradeTableUp), 인벤토리
	-- 일괄판매 컷오프도 전부 이 배열을 본다.
	gradeOrder = { "normal", "rare", "epic", "legendary", "relic", "ancient", "primordial" },
	-- G1-2(D0 결정 4 - 규칙 위반 해소): 분해 가능 등급의 문턱(gradeOrder 번호) - 이 번호 이상이면 분해 → 보석(영웅 이상, 값 그대로). 옛 코드는 서버 PlayerProfile과
	-- 클라 Store에 각각 3을 박아 두었다. 보석은 옵션이 있는 등급에서만 생기므로 OptionData.minGradeIndex와 같은 값이어야 한다(검증 G1-2(가)).
	dismantleMinGradeIndex = 3,
	-- G1-2(D0 결정 4 나): 줍는 순간 자동 처리 필터 - 고를 수 있는 기준 등급(이 등급 이하 = 자동 처리). 가장 높은 기준 = 영웅("영웅 이하"). 끄면 보관(옛 동작).
	--   기준 이하 · 잠기지 않은 장비: 분해 가능 등급(dismantleMinGradeIndex 이상 = 영웅)은 분해 → 보석, 그 아래(일반 · 희귀)는 판매 → 골드. 기본 = 끔.
	autoProcessGradeChoices = { "epic", "rare", "normal" },

	-- 일괄판매 기준 등급의 상한(지시 - 유물·고대·태초는 어떤 사용자 설정으로도 일괄판매
	-- 대상이 되지 않는다. 귀한 등급을 확인창 한 번의 오클릭으로 잃는 사고를 막는다).
	-- PlayerProfile.sellItemsBulkUpTo가 서버 쪽 강제 상한으로, InventoryUI.client.lua가
	-- 선택지 목록을 이 등급까지만 만드는 데 같이 쓴다(단일 출처).
	bulkSellMaxGrade = "legendary",

	-- defenseGradeMultiplier = Loot.getArmorDefense의 갑옷 배율(D1 - 1.184 × dropPower) · fairnessMultiplier = 몬스터 tier 공정성 계산(MonsterData, 16-6)의
	-- 고정 입력(D1 전 값 1.184 × 1.45^n - 몬스터 HP · 골드 · 드랍 개수가 안 바뀐다) · dropPower = 드랍 장비 등급 위력(장갑 · 신발 배율 - D1).
	grades = {
		normal = {
			id = "normal",
			displayName = "일반",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[1],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 0, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[1],
		},
		rare = {
			id = "rare",
			displayName = "희귀",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[2],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 1, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[2],
		},
		-- 아래 5등급은 PRD-forge-game.md 7.0 각주의 ARMOR_DEFENSE_GRADE_MULTIPLIER 표를
		-- 그대로 옮긴 값이다(1.184/2.397/3.903/5.866/8.347/11.25/15.0, 일반~태초) - 16-5
		-- 조사에서 이미 확인했고 이번에 값만 채운다. 새로 만든 숫자가 아니다.
		epic = {
			id = "epic",
			displayName = "영웅",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[3],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 2, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[3],
		},
		legendary = {
			id = "legendary",
			displayName = "전설",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[4],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 3, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[4],
		},
		relic = {
			id = "relic",
			displayName = "유물",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[5],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 4, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[5],
		},
		ancient = {
			id = "ancient",
			displayName = "고대",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[6],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 5, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[6],
		},
		primordial = {
			id = "primordial",
			displayName = "태초",
			defenseGradeMultiplier = ARMOR_NORMAL * dropPower[7],
			fairnessMultiplier = ARMOR_NORMAL * STEP ^ 6, -- 옛 배율(몬스터 tier 공정성 식 고정 입력 - D1)
			dropPower = dropPower[6] * DPS_PRIMORDIAL_STEP, -- D1-2: 딜 부위(장갑 · 신발)만 - 갑옷 방어는 위 defenseGradeMultiplier(×2.5)
		},
	},

	-- 슬롯1 드랍 확률(PRD 7.1 dropChance 임시값). 슬롯2(30%p 보너스)는 이번 범위 밖 -
	-- "몬스터당 최대 2개" 다중 드랍은 다음이다.
	dropChance = 0.25,

	-- 28-1 [2-1]: 드랍 itemLevel = max(1, S + δ). S = 기준 스테이지(잡몹·반짝이 = 받는 사람 자신의 스테이지, 보스 = 보스
	-- 스테이지), δ는 삼각 분포 1:2:3:2:1(11.1 / 22.2 / 33.3 / 22.2 / 11.1%). tier의 itemLevel 곱셈은 폐지했다 - tier는 등급표만 정한다.
	itemLevelDelta = {
		{ delta = -2, weight = 1 },
		{ delta = -1, weight = 2 },
		{ delta = 0, weight = 3 },
		{ delta = 1, weight = 2 },
		{ delta = 2, weight = 1 },
	},
	-- 28-1 [2-2]: 보스 드랍(첫 클리어 · 재도전)은 −가 없다. 3:2:1.
	-- P2.5c 결정 6: 옛 +0 · +1 · +2(k 1.155 - 몬스터 힘 ×1 · ×1.155 · ×1.334)를 같은 힘의 지금 칸으로(힘 비율 - InfiniteStage.fromLegacySpan) = +0 · +7 · +15(평균 +4.8).
	bossItemLevelDelta = {
		{ delta = 0, weight = 3 },
		{ delta = InfiniteStage.fromLegacySpan(1), weight = 2 },
		{ delta = InfiniteStage.fromLegacySpan(2), weight = 1 },
	},

	-- 판매가 회수율(13-1). Loot.getSellPrice가 쓰는 유일한 상수 -
	--   판매가 = (1 / (dropChance × 그 등급 확률)) × 그 스테이지 처치당 골드 × sellRecoveryRate
	-- 이 관계식 자체가 "등급·드랍 스테이지가 바뀌어도 판매가가 자동으로 따라온다"는 지시를
	-- 만족시킨다 - 숫자를 등급표에 박지 않고 이 배율 하나만 조정하면 전체 판매가가 같이 움직인다.
	--
	-- 0.3으로 정한 근거(13-1 - 등급 2종뿐이던 시절 산출값): 인벤토리 20칸을 가득 채워 전부
	-- 파는 "한 사이클"의 총 판매 수익은 등급별로 (그 사이클의 총 처치 수)×(처치당 골드)×
	-- sellRecoveryRate로 수렴한다(기대 처치 수와 드랍 개수가 서로 상쇄되기 때문 - 어느 등급이든
	-- 같은 사이클 안에서 등가). 희귀·9단계(12-1에서 실제 검증한 방어보너스 37.96짜리 아이템)
	-- 하나를 팔면 228골드로 EnhanceConfig.goldCost의 +7강→+8강(200골드)을 넉넉히 감당한다.
	-- 검증 수치는 13-1 세션 PRD-forge-game-roblox.md 20.21 참고. 17-1부터 7등급 전부
	-- 드랍되면서 "한 사이클 등가" 전제(등급 2종)가 더는 정확히 성립하지 않는다 - 재검증은
	-- 다음 밸런스 세션 몫으로 남긴다.
	sellRecoveryRate = 0.3,
}
