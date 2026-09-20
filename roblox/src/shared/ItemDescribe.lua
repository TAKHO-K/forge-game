-- 장비 · 보석 · 무기 한 개를 툴팁 글로 바꾸는 순수 함수(S12b B · C). 알림 속 아이템 툴팁(드랍 순간 스냅샷)과 장비 보기 창이 같은 함수를 쓴다.
-- 가방 상세 패널(InventoryUI)은 자기 코드로 같은 문구를 만든다 - 이 모듈은 그 문구 형식(이름 · 부위/Lv/기본효과 · 옵션 줄)을 그대로 따른다(InventoryUI를 이 모듈로 옮기는 것은 S20 이후).
-- 반환은 글 조각뿐이다(색은 gradeId로 클라가 ItemVisualData에서 고른다). classId = 그 아이템을 쥔 사람의 직업(직업 특화 옵션 불일치 판정).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Option = require(ReplicatedStorage.Shared.Option)

local ItemDescribe = {}

local function gradeName(gradeId)
	local grade = ArmorData.grades[gradeId]
	return grade and grade.displayName or tostring(gradeId)
end

local function optionName(optionId)
	local def = OptionData.options[optionId]
	local name = def and def.displayName
	if not name and def and def.classId then
		local skillDef = SkillData[def.classId] and SkillData[def.classId][def.slot]
		name = skillDef and skillDef.name
	end
	return name or optionId
end

-- 옵션 줄들: { { text, dim, accentClassId } }. 옵션이 없거나 데이터에 없는 id면 빈 목록. accentClassId = 직업 특화 옵션이 내 직업과 맞을 때 그 직업(S13 - 클라가 UIColors.classAccent로 글씨색을 입힌다).
-- 직업이 안 맞으면 dim(회색)이 우선이라 accentClassId를 안 준다. 공통 옵션 · 치명 옵션은 nil.
local function optionLines(item, classId)
	local option = item.option
	local def = option and OptionData.options[option.id]
	if not def then
		return {}
	end
	local value = Option.valueOf(option, item.grade, item.itemLevel, classId)
	local mismatched = def.classId ~= nil and def.classId ~= classId
	local accentClassId = not mismatched and def.classId or nil
	if option.id == "crit" then
		return {
			{ text = ("치확 %+.1f%%p"):format(value.critRate * 100), dim = mismatched },
			{ text = ("치피 %+.2f"):format(value.critDmg), dim = mismatched },
		}
	end
	local text = ("%s %+.1f%%"):format(optionName(option.id), value * 100)
	if mismatched then
		text ..= "(직업 불일치 · 효과 없음)"
	end
	return { { text = text, dim = mismatched, accentClassId = accentClassId } }
end

local PART_META = {
	armor = function(item)
		return ("%s · Lv.%d · 방어력 %s"):format(ItemVisualData.partDisplayNames.armor, item.itemLevel, NumberFormat.format(Loot.getArmorDefense(item)))
	end,
	gloves = function(item)
		return ("%s · Lv.%d · 공격력 +%.0f%%"):format(ItemVisualData.partDisplayNames.gloves, item.itemLevel, Loot.getGlovesAttackPercent(item) * 100)
	end,
	shoes = function(item)
		return ("%s · Lv.%d · 이동+공속 +%.0f%%"):format(ItemVisualData.partDisplayNames.shoes, item.itemLevel, Loot.getShoesSpeedPercent(item) * 100)
	end,
}

-- 장비(갑옷 · 장갑 · 신발). 반환 { title = "유물 장갑", gradeId, meta, options }.
function ItemDescribe.item(item, classId)
	local part = item.part or "armor"
	local metaFn = PART_META[part] or PART_META.armor
	return {
		title = ("%s %s"):format(gradeName(item.grade), ItemVisualData.partDisplayNames[part] or "장비"),
		gradeId = item.grade,
		meta = metaFn(item),
		options = optionLines(item, classId),
	}
end

-- 보석. "<등급> <옵션명> 보석 · Lv.N"(옵션 미배정은 "<등급> 보석(옵션 미배정)").
function ItemDescribe.gem(gem, classId)
	local title
	if not gem.option then
		title = ("%s 보석(옵션 미배정)"):format(gradeName(gem.grade))
	else
		title = ("%s %s 보석 · Lv.%d"):format(gradeName(gem.grade), optionName(gem.option.id), gem.itemLevel or 0)
	end
	return { title = title, gradeId = gem.grade, meta = "무기 보석", options = optionLines(gem, classId) }
end

-- 무기(등급 · 강화 단계). 무기는 옵션이 없다(20.67 [1]).
function ItemDescribe.weapon(gradeId, weaponLevel)
	local weaponData = WeaponData.weapons[WeaponData.starterId]
	return {
		title = ("%s %s"):format(gradeId and gradeName(gradeId) or "", weaponData.displayName),
		gradeId = gradeId,
		meta = ("무기 · +%d"):format(weaponLevel or 0),
		options = {},
	}
end

return ItemDescribe
