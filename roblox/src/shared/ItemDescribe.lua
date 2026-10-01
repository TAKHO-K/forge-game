-- 장비 · 보석 · 무기 한 개를 툴팁 글로 바꾸는 순수 함수(S12b B · C). 알림 속 아이템 툴팁(드랍 순간 스냅샷)과 장비 보기 창이 같은 함수를 쓴다.
-- S20부터 가방 상세 패널(InventoryUI)도 이 모듈로 문구를 만든다(이중 유지 0) - 이름 · 부위/Lv/기본효과 · 옵션 줄 · 가방 셀 옵션 태그가 전부 여기서 나온다(InventoryUI를 이 모듈로 옮기는 것은 S20 이후).
-- 반환은 글 조각뿐이다(색은 gradeId로 클라가 ItemVisualData에서 고른다). classId = 그 아이템을 쥔 사람의 직업(직업 특화 옵션 불일치 판정).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local StageGeneration = require(ReplicatedStorage.Shared.StageGeneration) -- C5-6
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Option = require(ReplicatedStorage.Shared.Option)
local Text = require(ReplicatedStorage.Shared.Text)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData) -- C5-7b 특수 옵션 툴팁

-- C4-3: 치명 옵션이면 툴팁 한 줄(오버치명 전환 안내) - ItemTooltip이 옵션 줄 아래 작은 글씨로 그린다.
local function critNote(item)
	return item and item.option and item.option.id == "crit" and Text.get("item.critOverflowNote") or nil
end

-- C5-7b: 초월이면 부위 고정 특수 옵션 한 줄(치명 안내가 있으면 그 아래 줄로).
local function specialNote(item)
	if not item or item.grade ~= TranscendentData.gradeId then
		return nil
	end
	local id = TranscendentData.specialByPart[item.part or "armor"]
	if id == "phantom" then
		return Text.get("transcendent.special.phantom", { chance = tostring(math.floor(TranscendentData.phantom.chance * 100 + 0.5)) })
	elseif id == "frenzy" then
		local f = TranscendentData.frenzy
		return Text.get("transcendent.special.frenzy", { speed = tostring(math.floor(f.moveSpeedBonus * 100 + 0.5)), dash = tostring(math.floor((1 - f.dashCooldownScale) * 100 + 0.5)) })
	elseif id == "soar" then
		return Text.get("transcendent.special.soar", { cd = ("%d"):format(TranscendentData.soar.resetCooldownSeconds) })
	end
	return nil
end

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
			{ text = Text.get("desc.item.critRate", { value = ("%+.1f"):format(value.critRate * 100) }), dim = mismatched },
			{ text = Text.get("desc.item.critDmg", { value = ("%+.2f"):format(value.critDmg) }), dim = mismatched },
		}
	end
	local text = Text.get(mismatched and "desc.item.optionMismatch" or "desc.item.option", { name = optionName(option.id), value = ("%+.1f"):format(value * 100) })
	return { { text = text, dim = mismatched, accentClassId = accentClassId } }
end

ItemDescribe.optionLines = optionLines -- 옵션 줄(text · dim · accentClassId) - 가방 상세의 옵션 게이지가 글 · 회색 · 직업색을 여기서 받는다(S20)

-- 가방 셀 · 착용 칸의 옵션 태그(S20 - 이름 유도가 셀 코드 두 곳에 복제돼 있던 것을 여기 하나로). 반환 { text = 옵션 이름, mismatched, accentClassId } | nil(옵션이 없거나 데이터에 없다).
-- 색 규칙은 클라가 입힌다: 직업 불일치 = 회색이 우선 · 직업 특화 옵션 = accentClassId의 직업색 · 공통 옵션 = 기존 색(등급색).
function ItemDescribe.optionTag(item, classId)
	local option = item and item.option
	local def = option and OptionData.options[option.id]
	if not def then
		return nil
	end
	local mismatched = def.classId ~= nil and def.classId ~= classId
	return { text = Text.name(optionName(option.id)), mismatched = mismatched, accentClassId = not mismatched and def.classId or nil }
end

local PART_META = {
	armor = function(item)
		return Text.get("desc.item.meta.armor", { part = ItemVisualData.partDisplayNames.armor, level = ("%d"):format(item.itemLevel), value = NumberFormat.format(Loot.getArmorDefense(item)) })
	end,
	gloves = function(item)
		return Text.get("desc.item.meta.gloves", { part = ItemVisualData.partDisplayNames.gloves, level = ("%d"):format(item.itemLevel), value = ("%.0f"):format(Loot.getGlovesAttackPercent(item) * 100) })
	end,
	shoes = function(item)
		return Text.get("desc.item.meta.shoes", { part = ItemVisualData.partDisplayNames.shoes, level = ("%d"):format(item.itemLevel), value = ("%.0f"):format(Loot.getShoesSpeedPercent(item) * 100) })
	end,
}

-- 장비(갑옷 · 장갑 · 신발). 반환 { title = "유물 장갑", gradeId, meta, options }.
function ItemDescribe.item(item, classId)
	local part = item.part or "armor"
	local metaFn = PART_META[part] or PART_META.armor
	local suffix = StageGeneration.itemSuffix(item) -- C5-6 세대 세트 이름 접미사(주운 스테이지 ≥ 17,000)
	return {
		title = Text.get(suffix and "desc.item.titleSuffix" or "desc.item.title", { grade = gradeName(item.grade), part = ItemVisualData.partDisplayNames[part] or Text.get("desc.item.partGear"), suffix = suffix }),
		gradeId = item.grade,
		meta = metaFn(item),
		options = optionLines(item, classId),
		note = (function()
			local lines = {}
			for _, line in ipairs({ critNote(item) or false, specialNote(item) or false }) do
				if line then
					table.insert(lines, line)
				end
			end
			local variant = item.skillVariant and require(script.Parent.SkillVariant).describe(item.skillVariant, classId) -- Q9 K4: 스킬 변형(다른 직업 = 꺼짐)
			if variant then
				table.insert(lines, variant.active and variant.text or Text.get("variant.off", { line = variant.text }))
			end
			local setName = item.setZone and require(script.Parent.SetBonus).setName(item.setZone, item.dropStage) -- Q7: 세트 계열(Q5)
			if setName then
				table.insert(lines, Text.get("item.setLine", { name = setName }))
			end
			local where = require(script.Parent.PrimordialStamp).sourceText(item.source) -- Q7: 출처(Q5 보스 출처 태그 포함)
			if where then
				table.insert(lines, Text.get("item.sourceLine", { source = where }))
			end
			return #lines > 0 and table.concat(lines, "\n") or nil
		end)(),
	}
end

-- 보석. "<등급> <옵션명> 보석 · Lv.N"(옵션 미배정은 "<등급> 보석(옵션 미배정)").
function ItemDescribe.gem(gem, classId)
	local title
	if not gem.option then
		title = Text.get("desc.item.gemNoOption", { grade = gradeName(gem.grade) })
	else
		title = Text.get("desc.item.gemTitle", { grade = gradeName(gem.grade), option = optionName(gem.option.id), level = ("%d"):format(gem.itemLevel or 0) })
	end
	return { title = title, gradeId = gem.grade, meta = Text.get("desc.item.gemMeta"), options = optionLines(gem, classId), note = critNote(gem) }
end

-- 무기(등급 · 강화 단계). 무기는 옵션이 없다(20.67 [1]).
function ItemDescribe.weapon(gradeId, weaponLevel)
	local weaponData = WeaponData.weapons[WeaponData.starterId]
	return {
		title = Text.get("desc.item.weaponTitle", { grade = gradeId and gradeName(gradeId) or "", weapon = weaponData.displayName }),
		gradeId = gradeId,
		meta = Text.get("desc.item.weaponMeta", { level = ("%d"):format(weaponLevel or 0) }),
		options = {},
	}
end

return ItemDescribe
