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

local lootRng = Random.new()

local Loot = {}

-- tierIndex 몬스터가 gradeId로 뽑힐 확률(17-1 - 드랍표를 tier별로 연결하면서 등급 확률이
-- tier마다 달라졌다. getSellPrice가 "그 등급으로 뽑힐 확률"을 역산할 때 쓴다, 13-1과 같은
-- 목적). MonsterData.dropGradeTableByTier[tierIndex]에 그 등급이 없으면(예: tier1엔
-- "전설"이 없다) 0 - 그 tier에서는 절대 안 나온다는 뜻이다.
local function getGradeChance(tierIndex, gradeId)
	local row = MonsterData.dropGradeTableByTier[tierIndex]
	return row and row[gradeId] or nil
end

-- 부위 균등 랜덤(16-6, 웹 core/loot.js rollItemPart와 동등) - EquipSlots.order(갑옷/장갑/
-- 신발) 3개 중 하나를 똑같은 확률로 고른다. 무기는 대상이 아니다(EquipSlots.lua 주석 참고).
function Loot.rollItemPart()
	local order = EquipSlots.order
	return order[lootRng:NextInteger(1, #order)]
end

-- 드랍 판정 1회(슬롯1만, 슬롯2 다중 드랍은 범위 밖). 드랍이 없으면 nil, 있으면
-- { grade, part, dropStage, itemLevel, tierIndex, locked = false }. part는 16-6에서 추가 -
-- 웹처럼 드랍 순간엔 등급만 정해지고 부위는 균등 랜덤이다(rollItemPart). dropStage(몬스터를
-- 잡은 스테이지)와 itemLevel(획득 시점 캐릭터 레벨)은 서로 다른 정보라 둘 다 남긴다 -
-- dropStage는 getSellPrice의 "그 스테이지에서 사냥했다"는 경제적 맥락에, itemLevel은
-- getArmorDefense류의 실제 파워 계산에 쓰인다(13-2 - 12-1이 캐릭터 레벨 축이 없어
-- dropStage를 대체재로 썼던 것을, 축이 생긴 지금 원래 설계(PRD 20.11-4)대로 되돌린다).
-- locked는 13-1에서 추가 - 아이템이 생성되는 이 한 지점에서만 기본값을 정하면, 기존
-- 저장분은 SaveSystem.migrate()가 따로 채운다.
--
-- 등급표는 tierIndex로 MonsterData.dropGradeTableByTier에서 그 구역의 줄을 그대로 가져온다
-- (17-1 - 16-6이 계산만 해 두고 실제 드랍에는 안 걸어 뒀던 자리). ArmorData.gradeOrder
-- 순서로 굴려야 결과가 결정적이다(dropGradeTableByTier의 각 줄은 맵이라 순회 순서가
-- 보장되지 않는다). itemLevel에는 그 tier의 itemLevelBonus(=r(t)^(p-1), MonsterData.lua
-- 공정성 식 참고)를 곱한다 - "고tier일수록 같은 캐릭터 레벨이어도 더 좋은 장비가 나온다"는
-- 16-6 설계를 실제로 반영하는 지점이 이번 세션 전까지 없었다.
-- chanceMultiplier(22-2 [1], 선택값) - 접두사 변종의 보상 배율(= HP 배율). 드랍 확률에
-- 그대로 곱한다(단단한 ×2 → 50%, 거대한 ×3 → 75%, 연약한 ×0.5 → 12.5%) - 시간당 드랍
-- 기대값이 접두사 무관하게 같아지도록. 1을 넘지 않게 자른다(거대한 0.75가 현재 최대).
function Loot.rollArmorDrop(monsterStage, itemLevel, tierIndex, chanceMultiplier)
	if lootRng:NextNumber() >= math.min(ArmorData.dropChance * (chanceMultiplier or 1), 1) then
		return nil
	end

	local gradeTable = MonsterData.dropGradeTableByTier[tierIndex] or MonsterData.dropGradeTableByTier[1]
	local roll = lootRng:NextNumber()
	local acc = 0
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		local chance = gradeTable[gradeId]
		if chance then
			acc += chance
			if roll < acc then
				local tierData = MonsterData[MonsterData.tierOrder[tierIndex]] or MonsterData.tier1
				return {
					grade = gradeId,
					part = Loot.rollItemPart(),
					dropStage = monsterStage,
					itemLevel = math.floor(itemLevel * tierData.itemLevelBonus + 0.5),
					tierIndex = tierIndex,
					locked = false,
				}
			end
		end
	end

	return nil -- 확률 합이 1 미만인 경우의 방어적 처리(지금 표는 전부 정확히 1.0)
end

-- 보스 첫 처치 확정 드랍(20-4, 지시 [1] "태초 희소성 복구" - 15-1의 rollBossArmorDrop을
-- 대체한다). 옛 방식(매 처치마다 무조건 최상위 등급 확정)은 보스 재입장이 무제한이라
-- 가장 약한 보스를 반복하면 태초가 무한히 나왔다 - 반짝이 몬스터의 0.005%와 같은 급을
-- 두고 공존할 수 없는 상태였다(PRD 20.28 원래 기록, 이번에 폐기). 이제 "그 스테이지
-- 보스를 처음 깼을 때만" 이 함수를 타고(CombatResolution.grantKillReward가 분기), 등급은
-- MonsterData.bossFirstClearGradeTable(환생 1회 이상, tier6 표 그대로 - 태초 0.1%) 또는
-- bossFirstClearUpgradedGradeTable(환생 0회, 그 표를 1단계 상향 - 재무장 부트스트랩 특례,
-- 태초 2%)에서 굴린다. 재도전(이미 첫 처치 기록이 있는 스테이지)은 이 함수를 아예 안 타고
-- Loot.rollArmorDrop(잡몹과 동일, 확정 아님)으로 간다. 보스는 항상 tier1 기준으로
-- 계산되므로(BossRules.buildInstanceData) tierIndex=1 고정 - itemLevel 보너스도 tier1의
-- 값(=1.0)이라 그대로 itemLevel을 쓴다. roll이 표 끝까지 안 걸리는 부동소수 오차
-- 극단값에도 확정 지급이 깨지면 안 되므로 방어적 기본값(rollSparkleArmorDrop과 같은
-- 패턴)을 둔다 - 두 표 모두 실제로는 정확히 1.0으로 맞아떨어진다.
function Loot.rollBossFirstClearDrop(monsterStage, itemLevel, rebirthCount)
	local gradeTable = (rebirthCount and rebirthCount > 0)
		and MonsterData.bossFirstClearGradeTable
		or MonsterData.bossFirstClearUpgradedGradeTable

	local roll = lootRng:NextNumber()
	local acc = 0
	local grade = ArmorData.gradeOrder[#ArmorData.gradeOrder]
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		local chance = gradeTable[gradeId]
		if chance then
			acc += chance
			if roll < acc then
				grade = gradeId
				break
			end
		end
	end

	return {
		grade = grade,
		part = Loot.rollItemPart(),
		dropStage = monsterStage,
		itemLevel = itemLevel,
		tierIndex = 1,
		locked = false,
	}
end

-- 반짝이 몬스터 확정 드랍(19-4 [6], PRD 8.0-5 "유물 이상 확정 드랍" - 웹 BALANCE.
-- sparkleGradeChances 그대로). 잡몹과 같은 dropChance(25%) 굴림 자체를 안 거친다 - 반짝이는
-- 발견하면 100% 확정이다(웹 원문 "도망가지 않는다 - 발견하면 반드시 잡을 수 있어야
-- 한다"와 짝을 이루는 지급 방식). tierIndex는 그 구역 그대로 넘긴다 - 등급만 강제로 위로
-- 끌어올릴 뿐, itemLevel 보너스·판매가 계산(Loot.getSellPrice)은 일반 드랍과 같은
-- 축을 그대로 쓴다(단일 출처 유지 - 반짝이 전용 별도 계산식을 만들지 않는다).
function Loot.rollSparkleArmorDrop(monsterStage, itemLevel, tierIndex)
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

	return {
		grade = grade,
		part = Loot.rollItemPart(),
		dropStage = monsterStage,
		itemLevel = itemLevel,
		tierIndex = tierIndex or 1,
		locked = false,
	}
end

-- 장비 방어력 보너스(갑옷 전용). item이 nil이면(미착용) 0 - PlayerCombat.getDefense의
-- equipmentDefenseBonus 자리에 그대로 넘긴다. 13-2부터 dropStage가 아니라 itemLevel(획득
-- 시점 캐릭터 레벨) 기준이다 - PRD 20.11-4가 정의한 "아이템 레벨 시스템" 그대로. 갑옷만
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
