-- 드랍 확률이 계산되는 유일한 위치(P2 E1). 데이터는 shared/data/DropTableData.lua. 순수 함수다 - 플레이어 인스턴스를 모르고, 호출부가 필요한 값만 표로 넘긴다:
--   playerInfo  = { bestStage = 본인(활성 직업) 최고 스테이지 }
--   monsterInfo = { tierIndex = 사냥 구역 tier }
--   huntStage   = 그 몬스터를 잡은 사냥 스테이지(받는 사람의 스테이지 = 몬스터 레벨)
-- 서버 굴림(CombatResolution → Loot.rollArmorDrop) · 조회 API(DropTableQuery) · EconSim이 모두 effectiveRate를 부른다 - 표시와 실제가 어긋날 길이 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)

local DropTable = {}

local PRIMORDIAL = "primordial"

-- G1-2: 처치 시간 공정성 보정(규칙 = DropTableData.fairness 주석). killSeconds가 nil이면 1(보정 없음 - 옛 호출). hpUnits ≤ 1이면 1.
function DropTable.timeFairnessFactor(killSeconds, hpUnits)
	if killSeconds == nil or hpUnits == nil or hpUnits <= 1 then
		return 1
	end
	local config = DropTableData.fairness
	local k = math.max(killSeconds, 0)
	local spent = math.max(k, config.killFloorSeconds) + config.travelSeconds
	local tierOne = math.max(k / hpUnits, config.killFloorSeconds) + config.travelSeconds
	local c = math.min(1, spent / tierOne / hpUnits)
	return Sanitize.number(1 - config.strength * (1 - c), 1)
end

-- G1-1 보스 확정 장비 등급표(보상 목록 단일 소스 - 서버 굴림 Loot와 스테이지 선택 보상 띠가 같은 함수를 부른다).
-- D1: 첫 클리어 = 영웅 이상 보장 표 하나(환생 0회 상향표 폐지 - rebirthCount는 호출 호환용으로만 받는다). 재도전 = 토벌 표(반복 보스).
function DropTable.bossFirstClearGradeTable(_rebirthCount)
	return DropTableData.bossGrades.firstClear
end

function DropTable.bossRetryGradeTable()
	return DropTableData.bossGrades.raid
end

-- D1 ⑩ 확률 공개(정보창 데이터 - 창 UI는 U1): 드랍표 3종 = 보스 첫 클리어 · 토벌 · 잡몹(tier마다 태초 별도 굴림 포함 · 감쇠 전).
-- 반환 = { firstClear = rows, raid = rows, field = { [tier] = rows }, sparkle = rows } · rows = gradeRows 모양({ id, chance } 낮은 등급부터).
function DropTable.disclosure()
	local field = {}
	for tierIndex = 1, #DropTableData.armorGradeByTier do
		field[tierIndex] = DropTable.gradeRows(DropTable.gradeRow(tierIndex))
	end
	return {
		firstClear = DropTable.gradeRows(DropTableData.bossGrades.firstClear),
		raid = DropTable.gradeRows(DropTableData.bossGrades.raid),
		field = field,
		sparkle = DropTable.gradeRows(RareMonsterConfig.sparkleGradeChances), -- D1-2: 반짝이 확정 1개(출현 = RareMonsterConfig.sparkleChance)
	}
end

-- 등급표 → 확률 > 0인 등급을 낮은 등급부터 { { id, chance }... }(화면 목록용).
function DropTable.gradeRows(gradeTable)
	local rows = {}
	for _, gradeId in ipairs(ArmorData.gradeOrder) do
		local chance = gradeTable[gradeId]
		if chance and chance > 0 then
			table.insert(rows, { id = gradeId, chance = chance })
		end
	end
	return rows
end

-- 잡몹 장비 1개의 기본 등급 분포(태초 별도 굴림 전 - 공정성 식의 입력). 표 밖 tier는 tier1.
function DropTable.armorGradeTable(tierIndex)
	return DropTableData.armorGradeByTier[tierIndex] or DropTableData.armorGradeByTier[1]
end

-- 감쇠 전 태초 확률(장비 1개당) = 드래곤 확률 ÷ dragonOverTier[t](칸이 없으면 0).
function DropTable.primordialBaseRate(tierIndex)
	local config = DropTableData.primordial
	local divisor = config.dragonOverTier[tierIndex]
	return divisor and config.dragonRate / divisor or 0
end

-- 레벨 감쇠 배수(0 ~ 1): 격차 = 최고 − 사냥 스테이지. 격차 ≥ startGap이면 (격차 − startGap + 1) × perLevel만큼 깎는다(0 미만 금지).
function DropTable.levelDecay(bestStage, huntStage)
	local decay = DropTableData.primordial.levelDecay
	local gap = (bestStage or huntStage) - huntStage
	if gap < decay.startGap then
		return 1
	end
	return math.max(0, 1 - (gap - decay.startGap + 1) * decay.perLevel)
end

-- 이 플레이어가 이 몬스터를 이 사냥 스테이지에서 잡을 때 장비 1개가 태초일 확률.
function DropTable.effectiveRate(playerInfo, monsterInfo, huntStage)
	local rate = DropTable.primordialBaseRate(monsterInfo.tierIndex) * DropTable.levelDecay(playerInfo and playerInfo.bestStage, huntStage)
	return Sanitize.number(rate, 0)
end

-- 태초 확률이 primordialRate일 때 등급 gradeId가 나올 확률(태초를 먼저 굴리고, 아니면 기본 표에서 태초를 뺀 나머지를 비율대로).
-- primordialRate가 nil이면 감쇠 전 기본 확률(판매가 계산 등 - "그 등급으로 뽑힐 확률").
function DropTable.gradeChance(tierIndex, gradeId, primordialRate)
	local row = DropTable.armorGradeTable(tierIndex)
	local rate = primordialRate or DropTable.primordialBaseRate(tierIndex)
	if gradeId == PRIMORDIAL then
		return rate
	end
	local chance = row[gradeId]
	if not chance then
		return nil
	end
	local rest = 1 - (row[PRIMORDIAL] or 0)
	return chance / rest * (1 - rate)
end

-- 등급 분포 한 줄 전체({ [등급] = 확률 }, 합 1) - 조회 API · EconSim 기대 개수용.
function DropTable.gradeRow(tierIndex, primordialRate)
	local row = {}
	for gradeId in pairs(DropTable.armorGradeTable(tierIndex)) do
		row[gradeId] = DropTable.gradeChance(tierIndex, gradeId, primordialRate)
	end
	local rate = primordialRate or DropTable.primordialBaseRate(tierIndex)
	if rate > 0 then
		row[PRIMORDIAL] = rate
	end
	return row
end

return DropTable
