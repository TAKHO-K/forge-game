-- 무기 보석 슬롯 순수 계산 로직(23-2). 데이터(GemData)와 분리해서 여기엔 공식만 둔다 -
-- Enhance.lua/Loot.lua와 같은 분리 원칙. 26-3부터 옵션 롤은 Gem.buildGrantedGem을 거쳐
-- Option.rollFor(서버 전용, Option.lua 주석 참고)로만 굴린다 - 이 파일 자체엔 이제
-- math.random 계열 호출이 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
-- 26-1: 환생 지급 보석이 옵션을 즉시 굴린다(PRD 20.67 [1] "지급 순간 옵션을 1회 굴린다").
local Option = require(ReplicatedStorage.Shared.Option)

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

-- S20c: 보석 gradeId를 slot에 끼울 수 없는 이유(nil = 끼울 수 있다). PlayerProfile.equipGem과 같은 순서(해금 → 등급 상한)라 클라가 미리 보여 주는 판정이 서버와 갈리지 않는다.
-- 서버 규칙은 그대로이고(equipGem이 다시 검증한다) 이 함수는 그 규칙을 읽기만 한다.
function Gem.socketBlockReason(slotUnlocked, slot, gradeId)
	if not Gem.isSlotUnlocked(slotUnlocked, slot) then
		return "slot_locked"
	end
	if not Gem.canSocket(gradeId, slot) then
		return "grade_too_high"
	end
	return nil
end

-- S20c: 자동 장착 대상 = 끼울 수 있는 열린 홈 중 등급 상한이 가장 낮은 홈(상한이 같으면 번호가 작은 쪽). 빈 홈이 있으면 그 중에서 먼저 고른다(지금 규칙에서는 홈이 열리면 바로 채워져
-- 빈 홈이 없다 - 옛 개발 계정만 예외). 반환: slot, 또는 nil + 이유("no_slot_open" = 열린 홈이 없다 · "grade_too_high" = 열린 홈 중 이 등급을 받는 곳이 없다).
function Gem.autoSlot(slotUnlocked, gems, gradeId)
	local bestSlot, bestKey
	local anyOpen = false
	for slot = 1, Gem.slotCount do
		if Gem.isSlotUnlocked(slotUnlocked, slot) then
			anyOpen = true
			if Gem.canSocket(gradeId, slot) then
				local key = (Gem.isFilled(gems, slot) and 1000 or 0) + armorGradeIndex(Gem.gradeCapForSlot(slot)) * 10 + slot
				if not bestKey or key < bestKey then
					bestSlot, bestKey = slot, key
				end
			end
		end
	end
	if bestSlot then
		return bestSlot
	end
	return nil, anyOpen and "grade_too_high" or "no_slot_open"
end

-- S20d: 자동 장착으로 밀려날 보석 미리보기. 자동 장착 대상 홈(Gem.autoSlot)이 이미 차 있으면 그 보석 - 서버 규칙상 장착은 항상 "교체"라 밀려난 보석은 보석칸으로 돌아온다(사라지지 않는다).
-- 반환: 밀려날 보석 표(gems[slot]), slot. 빈 홈으로 들어가거나(교체 없음) 대상 홈이 없으면 nil.
function Gem.replacePreview(slotUnlocked, gems, gradeId)
	local slot = Gem.autoSlot(slotUnlocked, gems, gradeId)
	if slot and Gem.isFilled(gems, slot) then
		return gems[slot], slot
	end
	return nil
end

-- S20c: 보석칸 표시 순서 = 등급 높은 순(같은 등급은 획득 순 = 서버 index 순). 서버 index는 그대로 두고 표시 순서만 정한다. 반환: 서버 index 배열.
function Gem.displayOrder(gemInventory)
	local order = {}
	for index = 1, #gemInventory do
		order[index] = index
	end
	table.sort(order, function(a, b)
		local ga, gb = armorGradeIndex(gemInventory[a].grade) or 0, armorGradeIndex(gemInventory[b].grade) or 0
		if ga ~= gb then
			return ga > gb
		end
		return a < b
	end)
	return order
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
