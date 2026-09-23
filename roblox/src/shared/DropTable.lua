-- 드랍 확률이 계산되는 유일한 위치(P2 E1). 데이터는 shared/data/DropTableData.lua. 순수 함수다 - 플레이어 인스턴스를 모르고, 호출부가 필요한 값만 표로 넘긴다:
--   playerInfo  = { bestStage = 본인(활성 직업) 최고 스테이지 }
--   monsterInfo = { tierIndex = 사냥 구역 tier }
--   huntStage   = 그 몬스터를 잡은 사냥 스테이지(받는 사람의 스테이지 = 몬스터 레벨)
-- 서버 굴림(CombatResolution → Loot.rollArmorDrop) · 조회 API(DropTableQuery) · EconSim이 모두 effectiveRate를 부른다 - 표시와 실제가 어긋날 길이 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)

local DropTable = {}

local PRIMORDIAL = "primordial"

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
