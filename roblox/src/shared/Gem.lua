-- 무기 보석 슬롯 순수 계산 로직(23-2). 데이터(GemData)와 분리해서 여기엔 공식만 둔다 -
-- Enhance.lua/Loot.lua와 같은 분리 원칙. math.random을 직접 굴리는 함수(rollOption)는
-- 반드시 서버(GemServer.server.lua)에서만 호출해야 한다 - 클라이언트는 조회 함수만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

-- 보석 옵션 롤도 치명타 판정(PlayerCombat.critRng)과 같은 이유로 전역 시드와 분리한다.
local gemRng = Random.new()

local Gem = {}

Gem.slotCount = #GemData.slotGradeOrder -- 5

function Gem.gradeForSlot(slot)
	return GemData.slotGradeOrder[slot]
end

-- 슬롯이 열렸는가 = 환생 회차가 그 슬롯 번호 이상(1:1 대응, 20.38 [2]).
function Gem.isSlotUnlocked(slot, rebirthCount)
	return (rebirthCount or 0) >= slot
end

local function armorGradeIndex(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 보석 하나가 주는 공격력% 보너스(PlayerCombat.getAttack의 attackPercentBonus 자리에
-- 장갑 보너스와 합산해 그대로 더해진다, PlayerProfile.getAttackPercentBonus 참고).
-- 값은 "등급표 인접비"(ItemVisualData.gradeVisuals.statMultiplier, 20.37 [2]가 이미
-- 인용한 "등급 한 단계는 공격력을 40~88% 올린다"는 그 비율) 그대로다 - 새 계수를 만들지
-- 않고 슬롯 k의 보석이 "무기가 그 등급에 도달했을 때의 한 단계 상승분"을 미리 하나 얹어
-- 준다는 뜻으로 재사용한다(슬롯 등급이 항상 무기의 "한 발 앞"이라는 20.38 [2] 정합성
-- 메모와도 맞는 비유).
function Gem.attackPercentBonusForGrade(gradeId)
	local index = armorGradeIndex(gradeId)
	if not index or index <= 1 then
		return 0
	end
	local currentMultiplier = ItemVisualData.gradeVisuals[gradeId].statMultiplier
	local previousGradeId = ArmorData.gradeOrder[index - 1]
	local previousMultiplier = ItemVisualData.gradeVisuals[previousGradeId].statMultiplier
	return (currentMultiplier / previousMultiplier) - 1
end

-- 고대·태초 등급만 이름 풀에서 하나를 무작위로 뽑는다(GemData 주석 참고 - 영웅/전설/
-- 유물은 풀 자체가 없어 항상 nil, "이름 없는" 보석이다). 서버 전용(math.random 계열).
-- 23-3부터 이 함수를 부르는 곳은 PlayerProfile.rerollGemOption(변환권 소모) 하나뿐이다 -
-- 자동 지급·분해는 더 이상 이 함수를 안 부른다(GemData.lua "[옵션 배정]" 주석 참고 -
-- 안 그러면 분해를 반복해 변환권 없이 옵션을 공짜로 재굴림하는 구멍이 생긴다).
function Gem.rollOption(gradeId)
	local pool = GemData.optionPoolByGrade[gradeId]
	if not pool then
		return nil
	end
	return pool[gemRng:NextInteger(1, #pool)]
end

-- 슬롯이 열릴 때 자동 지급되는 확정 보석 하나(20.38 [2] "슬롯이 열릴 때 그 등급의 보석
-- 1개가 확정 지급된다"). 항상 테이블을 돌려준다(빈 슬롯은 false로 구분 - PlayerProfile.
-- rebirth 참고) - 23-3부터 optionId는 항상 nil로 시작한다(옵션은 오직 옵션 변환권으로만
-- 배정된다, 위 rollOption 주석 참고). 옵션이 없어도 영웅~유물 등급은 여전히 공격력%를
-- 주고(Gem.attackPercentBonusForGrade, 축 선택이 없는 무조건 보너스), 고대·태초는 변환권을
-- 쓰기 전까지 그 슬롯의 축 보너스가 0이다.
function Gem.buildGrantedGem(slot)
	return { optionId = nil }
end

function Gem.isFilled(gems, slot)
	return type(gems[slot]) == "table"
end

function Gem.allSlotsFilled(gems)
	for slot = 1, Gem.slotCount do
		if not Gem.isFilled(gems, slot) then
			return false
		end
	end
	return true
end

-- 옵션을 재굴림할 수 있는 등급인가(고대·태초뿐, GemData.optionPoolByGrade 참고) -
-- GemServer가 리롤 요청을 받을 때 이 등급인지부터 확인한다(영웅~유물 슬롯은 재굴림 대상이
-- 아예 아니다 - purchases.optionRerollTickets가 ancient/primordial 두 종류뿐인 이유와 같다).
function Gem.isRerollableGrade(gradeId)
	return GemData.optionPoolByGrade[gradeId] ~= nil
end

-- optionId가 배정된 스탯 축(GemData.optionAxis) - 미배정(nil)이거나 표에 없는 이름이면 nil.
function Gem.optionAxis(optionId)
	return optionId and GemData.optionAxis[optionId]
end

-- 축별 보정 계수(23-3, GemData.survivalReductionAtAnchor 주석 참고) - 방어력만 피해감소식의
-- 수확체감 때문에 보정이 필요하고, 나머지 셋(공격력·공속·최대체력)은 전부 "1+r 배율"이
-- 그대로 DPS%나 생존타수%로 직결되는 선형 축이라 보정이 없다(1).
local AXIS_CORRECTION = {
	attackPercent = 1,
	speedPercent = 1,
	maxHpPercent = 1,
	defensePercent = 1 / GemData.survivalReductionAtAnchor,
}

-- 보석 하나가 그 등급에서 axis에 주는 보너스 크기. attackPercentBonusForGrade가 구하는
-- "등급표 인접비"를 축 전체의 공통 기준값으로 재사용하고(23-2 그대로), 축별 보정 계수만
-- 곱한다 - 그래야 같은 등급의 네 옵션이 서로 다른 축이어도 기대 가치(DPS%·생존타수%)가
-- 같아진다(보고서 "기대 가치 환산표" 참고).
function Gem.magnitudeForGrade(gradeId, axis)
	return Gem.attackPercentBonusForGrade(gradeId) * (AXIS_CORRECTION[axis] or 1)
end

-- 슬롯 하나가 axis에 기여하는 보너스. 옵션 풀이 없는 등급(영웅~유물)은 축 선택 자체가
-- 없으므로 무조건 attackPercent에만 기여한다(기존 23-2 동작 그대로 유지). 옵션 풀이 있는
-- 등급(고대·태초)은 배정된 옵션의 축과 axis가 같을 때만 기여한다 - 옵션 미배정(nil)이면
-- 아무 축에도 기여하지 않는다(GemData.lua "[옵션 배정]" 주석).
local function slotBonusForAxis(gems, slot, axis)
	local gradeId = Gem.gradeForSlot(slot)
	if not Gem.isRerollableGrade(gradeId) then
		return axis == "attackPercent" and Gem.attackPercentBonusForGrade(gradeId) or 0
	end
	local gem = gems[slot]
	local gemAxis = Gem.optionAxis(gem.optionId)
	return gemAxis == axis and Gem.magnitudeForGrade(gradeId, axis) or 0
end

local function sumBonusForAxis(gems, axis)
	local total = 0
	for slot = 1, Gem.slotCount do
		if Gem.isFilled(gems, slot) then
			total += slotBonusForAxis(gems, slot, axis)
		end
	end
	return total
end

-- 장착된 보석 전체의 공격력% 보너스 합. PlayerProfile.getAttackPercentBonus가 장갑 보너스에
-- 그대로 더한다(같은 자리를 공유하는 단일 배율 슬롯, PlayerCombat.lua 주석).
function Gem.totalAttackPercentBonus(gems)
	return sumBonusForAxis(gems, "attackPercent")
end

-- 공속·이속% 보너스 합(23-3 신설, 속사의 흔적) - PlayerProfile.getSpeedPercentBonus가
-- 신발 보너스에 그대로 더한다(같은 축, PlayerCombat.getAttackCooldown·WalkSpeed 둘 다에
-- 자동으로 반영된다).
function Gem.totalSpeedPercentBonus(gems)
	return sumBonusForAxis(gems, "speedPercent")
end

-- 방어력% 보너스 합(23-3 신설, 심판의 표식) - PlayerCombat.getDefense의 새 defensePercentBonus
-- 자리로 들어간다(PlayerProfile.getDefensePercentBonus).
function Gem.totalDefensePercentBonus(gems)
	return sumBonusForAxis(gems, "defensePercent")
end

-- 최대체력% 보너스 합(23-3 신설, 삼위일체) - PlayerProfile.refreshMaxHp가 갑옷 보너스를
-- 더한 총합에 곱한다.
function Gem.totalMaxHpPercentBonus(gems)
	return sumBonusForAxis(gems, "maxHpPercent")
end

return Gem
