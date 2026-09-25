-- 갑옷 드랍 판정 + 방어력 계산이 실제로 곱해지는 유일한 위치(12-1, PlayerCombat·
-- InfiniteStage와 같은 이유). 판정은 서버(AttackServer.server.lua)에서만 호출한다 -
-- Random.new() 인스턴스를 쓴다(math.random은 전역 시드를 공유한다, 10-4와 같은 이유).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
-- 26-1: 장비 생성 지점에서 옵션을 굴린다(PRD 20.67 [1] "옵션 굴림 시점은 장비가 생성되는
-- 모든 지점"). Option.rollFor가 알아서 옵션 풀이 없는 등급(일반·희귀)엔 nil을 돌려준다.
local Option = require(ReplicatedStorage.Shared.Option)
-- P2 E1: 등급 확률 · 태초 확률은 드랍표 단일 소스(DropTable)에서 읽는다.
local DropTable = require(ReplicatedStorage.Shared.DropTable)

local lootRng = Random.new()

local Loot = {}

-- tierIndex 몬스터가 gradeId로 뽑힐 확률(17-1 - 드랍표를 tier별로 연결하면서 등급 확률이
-- tier마다 달라졌다. getSellPrice가 "그 등급으로 뽑힐 확률"을 역산할 때 쓴다, 13-1과 같은
-- 목적). MonsterData.dropGradeTableByTier[tierIndex]에 그 등급이 없으면(예: tier1엔
-- "전설"이 없다) 0 - 그 tier에서는 절대 안 나온다는 뜻이다.
-- P2 E1: DropTable.gradeChance(감쇠 전 기본 확률) - tier1 ~ 5의 태초(별도 굴림)도 여기서 확률을 얻는다(옛 표엔 없어 판매가 0이었을 자리).
-- 기본 표에 이미 있는 등급(tier6 태초 포함)은 표 값 그대로다(판매가가 한 자리도 안 바뀐다 - 리뷰 지적 1: 전에는 tier1 ~ 5 기존 등급까지 ×(1 − 태초)가 곱해졌다).
local function getGradeChance(tierIndex, gradeId)
	local row = MonsterData.dropGradeTableByTier[tierIndex]
	if not row then
		return nil
	end
	if row[gradeId] then
		return row[gradeId]
	end
	local chance = DropTable.gradeChance(tierIndex, gradeId)
	return (chance and chance > 0) and chance or nil
end

-- 부위 균등 랜덤(16-6, 웹 core/loot.js rollItemPart와 동등) - EquipSlots.order(갑옷/장갑/
-- 신발) 3개 중 하나를 똑같은 확률로 고른다. 무기는 대상이 아니다(EquipSlots.lua 주석 참고).
function Loot.rollItemPart()
	local order = EquipSlots.order
	return order[lootRng:NextInteger(1, #order)]
end

-- 28-1(S01) 드랍 규칙 - PRD 20.72 [2]. 장비 하나는 { grade, part, dropStage, itemLevel, tierIndex, locked = false,
-- option }이다. option(26-1, PRD 20.67 [1])은 Option.rollFor(grade, classId)의 결과 - 일반·희귀는 항상 nil.
-- part는 웹처럼 드랍 순간엔 등급만 정해지고 부위는 균등 랜덤이다(rollItemPart). dropStage(그 스테이지에서
-- 잡았다)는 getSellPrice의 경제적 맥락에, itemLevel은 getArmorDefense류의 실제 파워 계산에 쓰인다.
--
-- itemLevel = max(1, S + δ)(rollItemLevel). S = 기준 스테이지: 잡몹·반짝이는 받는 사람 자신의 스테이지, 보스는
-- 보스 스테이지 - 캐릭터 레벨은 더 이상 안 본다(옛 규칙은 "레벨 × tier 보너스"라 레벨 100이 tier6을 잡으면
-- itemLevel 420이 나왔다). tier는 등급표(MonsterData.dropGradeTableByTier)와 기대 드랍 개수만 정한다.
-- locked는 13-1에서 추가 - 아이템이 생성되는 이 한 지점에서만 기본값을 정하면, 기존 저장분은
-- SaveSystem.migrate()가 따로 채운다.

-- 가중치 표({ { delta =, weight = }, ... })에서 δ 하나를 뽑는다.
local function rollDelta(deltaTable)
	local total = 0
	for _, row in ipairs(deltaTable) do
		total += row.weight
	end
	local roll = lootRng:NextNumber() * total
	local acc = 0
	for _, row in ipairs(deltaTable) do
		acc += row.weight
		if roll < acc then
			return row.delta
		end
	end
	return deltaTable[#deltaTable].delta -- 부동소수 오차 극단값의 방어적 처리
end

-- 등급표(map)를 ArmorData.gradeOrder 순서로 굴린다(순회 순서가 결정적이어야 한다). 표 끝까지 안 걸리면 nil.
-- excludeGrade(P2 E1): 그 등급을 빼고 나머지 합으로 정규화해 굴린다(태초를 따로 굴린 뒤 "태초가 아니면"의 분포).
local function rollGrade(gradeTable, excludeGrade)
	local total = 1
	if excludeGrade and gradeTable[excludeGrade] then
		total -= gradeTable[excludeGrade]
	end
	local roll = lootRng:NextNumber() * total
	local acc = 0
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		local chance = gradeId ~= excludeGrade and gradeTable[gradeId]
		if chance then
			acc += chance
			if roll < acc then
				return gradeId
			end
		end
	end
	return nil
end

local function buildDropItem(gradeId, monsterStage, itemLevel, tierIndex, classId)
	return {
		grade = gradeId,
		part = Loot.rollItemPart(),
		dropStage = monsterStage,
		itemLevel = itemLevel,
		tierIndex = tierIndex,
		locked = false,
		option = Option.rollFor(gradeId, classId),
	}
end

function Loot.rollItemLevel(stage, deltaTable)
	return math.max(1, stage + rollDelta(deltaTable))
end

-- 기대 개수 → 실제 개수: floor개는 확정, 소수부는 그 확률로 1개 더. 장비 드랍과 강화석(S04)이 같은 함수를 쓴다.
function Loot.rollCount(expected)
	local count = math.floor(expected)
	local fraction = expected - count
	if fraction > 0 and lootRng:NextNumber() < fraction then
		count += 1
	end
	return count
end

-- 잡몹 1마리가 주는 기대 장비 개수 = dropChance × tier의 dropCountMultiplier(= r^(p−1), 공정성 항등식이 옛 itemLevel
-- 보너스로 맡던 몫) × 접두사 보상 배율(22-2 [1], = HP 배율 - 시간당 드랍 기대값이 접두사 무관하게 같아지도록).
-- 옛 규칙("확률에 배율을 곱하고 1에서 자른다")을 대체한다 - 1을 넘으면 여러 개가 나온다.
function Loot.expectedArmorDropCount(tierIndex, rewardMultiplier)
	local tierData = MonsterData[MonsterData.tierOrder[tierIndex]] or MonsterData.tier1
	return ArmorData.dropChance * tierData.dropCountMultiplier * (rewardMultiplier or 1)
end

-- 잡몹 드랍 판정 1회. 0개 이상의 장비 배열을 돌려준다(개수 = rollCount(expectedArmorDropCount)). 아이템마다 등급 ·
-- 부위 · 옵션 · itemLevel을 독립으로 굴린다. 등급표는 tierIndex로 MonsterData.dropGradeTableByTier의 그 구역
-- 줄을 그대로 가져온다(17-1).
-- P2 E1 · E4: primordialRate(= DropTable.effectiveRate - 호출부 CombatResolution이 받는 사람 기준으로 구한다)가 오면 아이템마다 태초를 먼저 굴리고,
-- 아니면 기본 표에서 태초를 뺀 나머지 분포로 굴린다. 태초의 itemLevel = 그 몬스터를 잡은 사냥 스테이지(몬스터 레벨 - 편차 δ 없음).
-- primordialRate가 nil이면 옛 굴림 그대로(기본 표 - tier6 태초 0.1% 포함).
function Loot.rollArmorDrop(monsterStage, tierIndex, rewardMultiplier, classId, primordialRate)
	local gradeTable = MonsterData.dropGradeTableByTier[tierIndex] or MonsterData.dropGradeTableByTier[1]
	local items = {}
	for _ = 1, Loot.rollCount(Loot.expectedArmorDropCount(tierIndex, rewardMultiplier)) do
		local gradeId
		if primordialRate then
			gradeId = lootRng:NextNumber() < primordialRate and "primordial" or rollGrade(gradeTable, "primordial")
		else
			gradeId = rollGrade(gradeTable)
		end
		if gradeId then -- 확률 합이 1 미만인 경우의 방어적 처리(지금 표는 전부 정확히 1.0)
			local itemLevel = (primordialRate and gradeId == "primordial") and math.max(1, monsterStage) or Loot.rollItemLevel(monsterStage, ArmorData.itemLevelDelta)
			table.insert(items, buildDropItem(gradeId, monsterStage, itemLevel, tierIndex, classId))
		end
	end
	return items
end

-- 강화 재료(28-1 S04)의 처치당 기대 개수 = 재료의 처치당 확률 × 마릿수분(killUnits) × 받는 사람의 경험치 배수. 마릿수분은 호출부가 정한다
-- (잡몹 = tier · 접두사 보상 배율, 보스 = 20, 반짝이 · 상자 = 보너스분 - CombatResolution). 경험치 배수를 곱하는 이유: 파티 보너스 · 성장 옵션은
-- 레벨당 마릿수를 줄이는데 재료는 처치당으로 나오므로, 안 곱하면 같은 여정에서 재료가 덜 쌓인다(PRD 20.81 [B-4]).
function Loot.expectedMaterialCount(materialId, killUnits, expGainMultiplier)
	return EnhanceMaterialData.materials[materialId].dropChancePerKill * killUnits * expGainMultiplier
end

-- 처치 1회의 재료 드랍 판정 → { [재료 id] = 개수 }(0개인 재료는 없다). 받는 사람의 스테이지가 minStage 미만이면 그 재료는 굴리지 않는다.
-- 두 재료는 각각 독립으로 굴려진다(스테이지 75+에서는 강화석도 같이 나온다). 개수 = rollCount(기대 개수) - 장비 드랍과 같은 헬퍼.
function Loot.rollMaterialDrops(recipientStage, killUnits, expGainMultiplier)
	local drops = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		if recipientStage >= EnhanceMaterialData.materials[materialId].minStage then
			local count = Loot.rollCount(Loot.expectedMaterialCount(materialId, killUnits, expGainMultiplier))
			if count > 0 then
				drops[materialId] = count
			end
		end
	end
	return drops
end

-- 보스 첫 처치 확정 드랍(20-4, 지시 [1] "태초 희소성 복구" - 15-1의 rollBossArmorDrop을
-- 대체한다). 옛 방식(매 처치마다 무조건 최상위 등급 확정)은 보스 재입장이 무제한이라
-- 가장 약한 보스를 반복하면 태초가 무한히 나왔다 - 반짝이 몬스터의 0.005%와 같은 급을
-- 두고 공존할 수 없는 상태였다(PRD 20.28 원래 기록, 이번에 폐기). 이제 "그 스테이지
-- 보스를 처음 깼을 때만" 이 함수를 타고(CombatResolution.grantKillReward가 분기), 등급은
-- MonsterData.bossFirstClearGradeTable(환생 1회 이상, tier6 표 그대로 - 태초 0.1%) 또는
-- bossFirstClearUpgradedGradeTable(환생 0회, 그 표를 1단계 상향 - 재무장 부트스트랩 특례,
-- 태초 2%)에서 굴린다. 재도전(이미 첫 처치 기록이 있는 스테이지)은 rollBossRetryDrop으로 간다.
-- 보스는 항상 tier1 기준으로 계산되므로(BossRules.buildInstanceData) tierIndex=1 고정.
-- 28-1 [2-2]: itemLevel = 보스 스테이지 + δ(0 / +1 / +2, 3:2:1 - 음수 없음). roll이 표 끝까지 안 걸리는
-- 부동소수 오차 극단값에도 확정 지급이 깨지면 안 되므로 방어적 기본값(rollSparkleArmorDrop과 같은 패턴)을
-- 둔다 - 두 표 모두 실제로는 정확히 1.0으로 맞아떨어진다.
function Loot.rollBossFirstClearDrop(bossStage, rebirthCount, classId)
	local gradeTable = DropTable.bossFirstClearGradeTable(rebirthCount) -- G1-1: 보상 띠와 같은 함수

	local grade = rollGrade(gradeTable) or ArmorData.gradeOrder[#ArmorData.gradeOrder]
	return buildDropItem(grade, bossStage, Loot.rollItemLevel(bossStage, ArmorData.bossItemLevelDelta), 1, classId)
end

-- 보스 재도전 확정 드랍(28-1 [2-2]) - 확정 1개(확률 굴림 없음, 기존 25%에서 상향). 등급 상승은 첫 클리어 전용이라
-- 등급표는 tier1(일반·희귀만)이고, itemLevel 편향만 첫 클리어와 같다.
function Loot.rollBossRetryDrop(bossStage, classId)
	local grade = rollGrade(DropTable.bossRetryGradeTable()) or ArmorData.gradeOrder[1] -- G1-1: 보상 띠와 같은 함수(값 = 옛 tier1 표)
	return buildDropItem(grade, bossStage, Loot.rollItemLevel(bossStage, ArmorData.bossItemLevelDelta), 1, classId)
end

-- 반짝이 몬스터 확정 드랍(19-4 [6], PRD 8.0-5 "유물 이상 확정 드랍" - 웹 BALANCE.
-- sparkleGradeChances 그대로). 잡몹과 같은 dropChance(25%) 굴림 자체를 안 거친다 - 반짝이는
-- 발견하면 100% 확정이다(웹 원문 "도망가지 않는다 - 발견하면 반드시 잡을 수 있어야
-- 한다"와 짝을 이루는 지급 방식). tierIndex는 그 구역 그대로 넘긴다 - 등급만 강제로 위로
-- 끌어올릴 뿐, itemLevel(28-1: 스테이지 + δ, 잡몹과 같은 분포)·판매가 계산(Loot.getSellPrice)은 일반 드랍과
-- 같은 축을 그대로 쓴다(단일 출처 유지 - 반짝이 전용 별도 계산식을 만들지 않는다).
function Loot.rollSparkleArmorDrop(monsterStage, tierIndex, classId)
	local roll = lootRng:NextNumber()
	local acc = 0
	local grade = "relic" -- 확률 합이 부동소수 오차로 1 미만이 되는 극단적인 경우의 방어적 기본값
	for gradeId, chance in pairs(RareMonsterConfig.sparkleGradeChances) do
		acc += chance
		if roll < acc then
			grade = gradeId
			break
		end
	end

	return buildDropItem(grade, monsterStage, Loot.rollItemLevel(monsterStage, ArmorData.itemLevelDelta), tierIndex or 1, classId)
end

-- 견습 모드 확정 지급(23-1, PRD 20.47[1] "rollBossFirstClearDrop 자리를 등급·부위 고정
-- 드랍으로 재사용"). 등급·부위가 굴림이 아니라 그 단계가 정한 고정값이라는 점만
-- rollBossFirstClearDrop과 다르다 - 반환 모양은 동일(TutorialState가 ItemDropSpawner.spawn에
-- 그대로 넘긴다, 잡몹/보스 확정 드랍과 같은 "주웠다" 연출을 그대로 재사용). 28-1: itemLevel = stage(δ = 0 고정).
function Loot.buildFixedArmorDrop(grade, part, stage, tierIndex, classId)
	return {
		grade = grade,
		part = part,
		dropStage = stage,
		itemLevel = stage,
		tierIndex = tierIndex,
		locked = false,
		option = Option.rollFor(grade, classId),
	}
end

-- 장비 방어력 보너스(갑옷 전용). item이 nil이면(미착용) 0 - PlayerCombat.getDefense의
-- equipmentDefenseBonus 자리에 그대로 넘긴다. 13-2부터 dropStage가 아니라 itemLevel
-- 기준이다(28-1부터 itemLevel = 드랍 기준 스테이지 ± 2 - 위 rollItemLevel) - PRD 20.11-4가 정의한 "아이템 레벨 시스템" 그대로. 갑옷만
-- ArmorData의 전용 배율표(defenseGradeMultiplier)를 쓴다 - 16-5 조사로 확인한 대로 이
-- 표는 장갑·신발의 일반 배율(ItemVisualData.gradeVisuals.statMultiplier)과 축이 다르다.
function Loot.getArmorDefense(item)
	if not item then
		return 0
	end
	local grade = ArmorData.grades[item.grade]
	return ArmorData.baseDefense * grade.defenseGradeMultiplier * CharacterLevel.getItemLevelMultiplier(item.itemLevel)
end

-- 최대체력 보너스(17-1, PRD-forge-game-roblox.md 20.11-4 "maxHp 성장 경로"). 갑옷에서만
-- 나온다(defenseFlat과 나란히) - 등급은 안 본다는 게 PRD의 핵심 결정이다("처음 시도(등급에
-- 결합)한 방식은 폐기" - 등급 전환 직후 방어력·최대체력이 동시에 떨어지는 골짜기가
-- 생겼었다). CombatConfig.maxHpBonusBase에 defenseFlat과 같은 함수(itemLevelMultiplier,
-- 동결 없음)를 곱한다 - 몬스터공격력과 같은 k로 자라야 "받는 피해/최대체력" 비율이
-- 스테이지 무관 상수로 수렴한다(defenseFlat 주석과 같은 이유).
function Loot.getMaxHpBonus(item)
	if not item then
		return 0
	end
	return CombatConfig.maxHpBonusBase * CharacterLevel.getItemLevelMultiplier(item.itemLevel)
end

-- 장갑 공격력 비율 보너스(16-6, 웹 ITEM_PART_BASE_STAT.gloves 그대로 이식). item이 nil이면
-- 0. 갑옷과 달리 일반 등급 배율(ItemVisualData.gradeVisuals.statMultiplier, 1.0~15.0)을
-- 쓴다 - 갑옷 전용표(위 getArmorDefense)와 절대 섞지 않는다(단일 출처 원칙, 16-5 확인).
-- itemLevel 계수는 17-1부터 레벨25에서 동결한다(getItemLevelMultiplierFrozen) - 무기
-- 공격력(getWeaponExpMultiplier)이 이미 레벨25 이후 지수 성장을 맡고 있어, 여기까지 같이
-- 무한 성장하면 두 지수가 곱으로 겹친다(CharacterLevel.lua 주석 참고).
function Loot.getGlovesAttackPercent(item)
	if not item then
		return 0
	end
	local visual = ItemVisualData.gradeVisuals[item.grade]
	return EquipSlots.baseValue.gloves * visual.statMultiplier * CharacterLevel.getItemLevelMultiplierFrozen(item.itemLevel)
end

-- 신발 이동+공격속도 비율 보너스(16-6, 웹 ITEM_PART_BASE_STAT.shoes 그대로 이식) -
-- getGlovesAttackPercent와 완전히 같은 형태, 부위만 다르다(웹도 base값이 0.15로 같다).
-- itemLevel 계수 동결 이유도 위와 같다(17-1).
function Loot.getShoesSpeedPercent(item)
	if not item then
		return 0
	end
	local visual = ItemVisualData.gradeVisuals[item.grade]
	return EquipSlots.baseValue.shoes * visual.statMultiplier * CharacterLevel.getItemLevelMultiplierFrozen(item.itemLevel)
end

-- 판매가(13-1) - 이 관계식이 유일한 계산 지점이다(서버 InventoryServer의 SellRequest 처리·
-- 클라이언트 UI 표시 둘 다 이 함수를 그대로 호출해야 어긋나지 않는다, getArmorDefense와 같은 원칙).
--   기대 처치 수 = 1 / (dropChance × 그 등급 확률)  - "이 등급 하나를 얻으려면 평균 몇 마리를
--     잡아야 하는가"
--   처치당 골드 = InfiniteStage.getGoldReward(tier1 기본 골드, 그 아이템을 주운 스테이지)
--   판매가 = 기대 처치 수 × 처치당 골드 × ArmorData.sellRecoveryRate
-- 13-2에서 getArmorDefense는 itemLevel 기준으로 바뀌었지만 이 함수는 dropStage를 그대로
-- 쓴다 - 의도적이다. "처치당 골드"는 아이템의 파워가 아니라 "그 스테이지에서 사냥했다"는
-- 경제적 맥락(거기서 얻을 수 있었던 골드)을 나타내는 값이라 itemLevel과는 다른 질문에
-- 답한다. 등급이 오르면 기대 처치 수가 커지고, 드랍 스테이지가 오르면 처치당 골드가
-- 커진다 - 회수율 하나만 상수로 고정해 두면 두 축 모두 판매가에 자동으로 반영된다
-- (ArmorData.sellRecoveryRate 주석에 회수율 값 근거).
function Loot.getSellPrice(item)
	if not item then
		return 0
	end
	local gradeChance = getGradeChance(item.tierIndex or 1, item.grade)
	if not gradeChance then
		return 0
	end
	local expectedKills = 1 / (ArmorData.dropChance * gradeChance)
	local goldPerKill = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, item.dropStage)
	return math.floor(expectedKills * goldPerKill * ArmorData.sellRecoveryRate)
end

return Loot
