-- 장비 계승 규칙(P2.5b A) - 순수 함수. 서버(PlayerProfile.inheritItem · previewInherit)가 판정하고 클라(계승 창 · 상세 바)가 같은 함수로 미리 보인다(Equip · Gem.socketBlockReason과 같은 방식).
-- A = 지금 착용 중인 장비, B = 가방의 같은 부위 장비. 계승 = B가 그 부위에 착용되고 A는 사라진다(분해 재료로 환급).
--   옮기는 것: 옵션 세트(종류 + 굴림 위치 roll · roll2) 중 고른 쪽 - 수치는 B의 등급 · itemLevel로 Option.valueOf가 다시 계산한다(옵션 표에 수치가 저장돼 있지 않다).
--   장비에는 강화 단계 · 보석 칸이 없다(무기만 갖는다 - docs/phase/P25b-log.md 결정 1) - 그래서 옮길 강화 · 보석이 없다.
--   이유 코드: no_class · not_equipped(A 없음) · not_found(B 없음) · part_mismatch · locked(A 또는 B 잠금) · invalid(keep이 "a" | "b"가 아님) · b_grade_lower(B 등급이 A보다 낮아 A 세트 불가).
--   골드 부족(no_gold)은 서버가 비용을 다시 계산해 따로 거른다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local InheritConfig = require(ReplicatedStorage.Shared.data.InheritConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Option = require(ReplicatedStorage.Shared.Option)

local Inherit = {}

local function gradeRank(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return 0
end
Inherit.gradeRank = gradeRank

local function partOf(item)
	return item.part or "armor" -- v10 이전 갑옷은 part가 없었다(SaveSystem v10이 채운다 - 방어적으로 같은 기본값)
end

local function copyOption(option)
	if not option then
		return nil
	end
	return { id = option.id, roll = option.roll, roll2 = option.roll2 }
end

-- 그 장비의 옵션 세트(목록 - 지금 규칙에서 0 ~ 1개).
function Inherit.optionSet(item)
	return (item and item.option) and { item.option } or {}
end

-- 비교 기준 = 부위 기본 효과(갑옷 방어력 · 장갑 공격력% · 신발 이동+공속%) - 상세 바의 "착용 대비" 줄과 [계승] 버튼 노출이 이 값을 본다.
function Inherit.baseStat(item)
	if not item then
		return 0
	end
	local part = partOf(item)
	if part == "gloves" then
		return Loot.getGlovesAttackPercent(item)
	elseif part == "shoes" then
		return Loot.getShoesSpeedPercent(item)
	end
	return Loot.getArmorDefense(item)
end

-- B가 A보다 좋은가(A7 [계승] 버튼 노출 조건): 같은 부위이고 기본 효과가 더 크다.
function Inherit.isUpgrade(a, b)
	return a ~= nil and b ~= nil and partOf(a) == partOf(b) and Inherit.baseStat(b) > Inherit.baseStat(a)
end

-- A 세트를 고를 수 없는 이유(nil = 고를 수 있다) - B 등급이 A보다 낮다(A3).
function Inherit.keepABlockReason(a, b)
	if gradeRank(b.grade) < gradeRank(a.grade) then
		return "b_grade_lower"
	end
	return nil
end

-- 계승 요청 판정(서버 · 클라 공용). hasClass = 직업을 골랐는가.
function Inherit.blockReason(a, b, keep, hasClass)
	if not hasClass then
		return "no_class"
	end
	if not a then
		return "not_equipped"
	end
	if not b then
		return "not_found"
	end
	if partOf(a) ~= partOf(b) then
		return "part_mismatch"
	end
	if a.locked or b.locked then
		return "locked"
	end
	if keep ~= "a" and keep ~= "b" then
		return "invalid"
	end
	if keep == "a" then
		return Inherit.keepABlockReason(a, b)
	end
	return nil
end

-- 계승 뒤 B(새 표): 옵션 = 고른 세트를 B 등급의 옵션 칸 수(Option.optionSlotsFor)까지 자른 것. 그 밖의 필드(등급 · itemLevel · tier · 주운 스테이지)는 B 그대로.
function Inherit.resultItem(a, b, keep)
	local item = {}
	for key, value in pairs(b) do
		item[key] = value
	end
	local set = keep == "a" and Inherit.optionSet(a) or Inherit.optionSet(b)
	item.option = Option.optionSlotsFor(b.grade) >= 1 and copyOption(set[1]) or nil
	item.locked = nil
	return item
end

-- A 환급(A5 "분해한 것과 같은 재료"). 분해 가능 등급(영웅 이상 = OptionData.minGradeIndex, PlayerProfile.dismantleItem과 같은 문턱)이면 보석 1개 - 등급 · itemLevel = A,
-- 옵션 = **고르지 않은 쪽** 세트(A 세트를 B로 옮겼는데 A 옵션 보석까지 주면 같은 굴림이 둘이 된다 - 옵션 총량 보존). 그 아래 등급은 분해 결과가 없어 판매가 골드.
-- 반환: { kind = "gem", gem = { grade, itemLevel, option } } | { kind = "gold", gold = n }
function Inherit.refund(a, b, keep)
	if gradeRank(a.grade) >= OptionData.minGradeIndex then
		local unchosen = keep == "a" and b.option or a.option
		return { kind = "gem", gem = { grade = a.grade, itemLevel = a.itemLevel, option = copyOption(unchosen) } }
	end
	return { kind = "gold", gold = Loot.getSellPrice(a) }
end

-- 비용(골드). stage = 계정 최고 스테이지 · discountFraction = 마일스톤 계승 할인(0 ~ 1, 없으면 0).
function Inherit.cost(bGradeId, stage, discountFraction)
	local kills = InheritConfig.goldKillEquivalent[bGradeId] or InheritConfig.goldKillEquivalent.normal
	local full = GoldCost.cost(MonsterData.tier1.goldDrop * kills, stage, "inherit")
	return math.floor(full * (1 - (discountFraction or 0)))
end

return Inherit
