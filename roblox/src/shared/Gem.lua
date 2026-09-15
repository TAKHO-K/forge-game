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
function Gem.rollOption(gradeId)
	local pool = GemData.optionPoolByGrade[gradeId]
	if not pool then
		return nil
	end
	return pool[gemRng:NextInteger(1, #pool)]
end

-- 슬롯이 열릴 때 자동 지급되는 확정 보석 하나(20.38 [2] "슬롯이 열릴 때 그 등급의 보석
-- 1개가 확정 지급된다"). 항상 테이블을 돌려준다(빈 슬롯은 false로 구분 - PlayerProfile.
-- rebirth 참고) - optionId는 옵션 풀이 있는 등급에서만 채워진다.
function Gem.buildGrantedGem(slot)
	local gradeId = Gem.gradeForSlot(slot)
	return { optionId = Gem.rollOption(gradeId) }
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

-- 장착된 보석 5개(빈 슬롯 제외)의 공격력% 보너스 합. PlayerProfile.getAttackPercentBonus가
-- 장갑 보너스에 그대로 더한다(같은 자리를 공유하는 단일 배율 슬롯, PlayerCombat.lua 주석).
function Gem.totalAttackPercentBonus(gems)
	local total = 0
	for slot = 1, Gem.slotCount do
		if Gem.isFilled(gems, slot) then
			total += Gem.attackPercentBonusForGrade(Gem.gradeForSlot(slot))
		end
	end
	return total
end

-- 옵션을 재굴림할 수 있는 등급인가(고대·태초뿐, GemData.optionPoolByGrade 참고) -
-- GemServer가 리롤 요청을 받을 때 이 등급인지부터 확인한다(영웅~유물 슬롯은 재굴림 대상이
-- 아예 아니다 - purchases.optionRerollTickets가 ancient/primordial 두 종류뿐인 이유와 같다).
function Gem.isRerollableGrade(gradeId)
	return GemData.optionPoolByGrade[gradeId] ~= nil
end

return Gem
