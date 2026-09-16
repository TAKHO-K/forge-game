-- 무기 보석 슬롯 순수 계산 로직(23-2). 데이터(GemData)와 분리해서 여기엔 공식만 둔다 -
-- Enhance.lua/Loot.lua와 같은 분리 원칙. math.random을 직접 굴리는 함수(rollOption)는
-- 반드시 서버(GemServer.server.lua)에서만 호출해야 한다 - 클라이언트는 조회 함수만 쓴다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
-- 26-1: 환생 지급 보석이 옵션을 즉시 굴린다(PRD 20.67 [1] "지급 순간 옵션을 1회 굴린다").
local Option = require(ReplicatedStorage.Shared.Option)

-- 보석 옵션 롤도 치명타 판정(PlayerCombat.critRng)과 같은 이유로 전역 시드와 분리한다.
local gemRng = Random.new()

local Gem = {}

Gem.slotCount = #GemData.slotGradeCap -- 5

-- 슬롯 i가 받아들이는 최고 등급(23-4, GemData.slotGradeCap 주석 참고) - 더 이상 "그 슬롯의
-- 유일한 등급"이 아니라 상한이다. 이 상한 자체가 그 슬롯에 열릴 때 확정 지급되는 보석의
-- 등급이기도 하다(Gem.buildGrantedGem).
function Gem.gradeCapForSlot(slot)
	return GemData.slotGradeCap[slot]
end

-- 슬롯이 열렸는가 - 23-4부터 매번 계산하지 않고 저장된 값(classState.weapon.slotUnlocked,
-- PlayerProfile.rebirth가 그 순간 기록한다)을 그대로 읽는다(GemData.slotUnlockRequiredRebirth
-- 주석 참고 - 나중에 환생 횟수만으로 못 나타내는 조건이 와도 저장 형태를 안 바꾸기 위함).
function Gem.isSlotUnlocked(slotUnlocked, slot)
	return slotUnlocked ~= nil and slotUnlocked[slot] == true
end

local function armorGradeIndex(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 보석 gradeId가 slot에 꽂힐 수 있는가 - "그 이하 등급은 전부 가능, 더 높은 등급은 불가"
-- (23-4 지시 그대로, ArmorData.gradeOrder의 순서를 그대로 비교 기준으로 쓴다).
function Gem.canSocket(gemGradeId, slot)
	local capIndex = armorGradeIndex(Gem.gradeCapForSlot(slot))
	local gemIndex = armorGradeIndex(gemGradeId)
	return capIndex ~= nil and gemIndex ~= nil and gemIndex <= capIndex
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
-- 1개가 확정 지급된다") - 23-4부터 그 등급은 슬롯의 등급 상한(Gem.gradeCapForSlot)이다.
-- 항상 테이블을 돌려준다(빈 슬롯은 false로 구분 - PlayerProfile.rebirth 참고).
--
-- 26-1(PRD 20.67 [1][13]): 23-3의 "optionId=nil 지급"을 폐지한다 - 지급 순간 Option.rollFor로
-- 옵션을 1회 굴린다(classId·itemLevel은 호출부(PlayerProfile.rebirth)가 넘긴다 - 환생 순간
-- 캐릭터 레벨=25×회차). gem.optionId 필드는 이제 없다(gem.option으로 대체, SaveSystem.migrate
-- v23 참고) - 이 함수가 호출되는 시점 자체가 이번 세션부터이므로 옛 필드를 쓸 이유가 없다.
function Gem.buildGrantedGem(slot, classId, itemLevel)
	local grade = Gem.gradeCapForSlot(slot)
	return { grade = grade, itemLevel = itemLevel, option = Option.rollFor(grade, classId) }
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

-- 26-2(PRD 20.67 [14] 3단계): "옛 4축 = 등급표 인접비" 계산(attackPercentBonusForGrade·
-- magnitudeForGrade·optionAxis·AXIS_CORRECTION, 슬롯별 합산 slotBonusForAxis/sumBonusForAxis,
-- 그리고 그걸로 만든 Gem.total*PercentBonus 4종)을 여기서 폐기한다 - PlayerProfile의 4축
-- 함수가 이제 장비 3부위 옵션 + 보석 5개를 Option.sumAxisBonus(Option.valueOf·Option.sumWithCap
-- 합성)로 직접 합산한다(PlayerProfile.lua 참고). Gem.lua는 슬롯 구조(등급 상한·해금·장착
-- 가능 여부)만 다루고, 값 계산은 전부 Option.lua가 유일한 출처다.

return Gem
