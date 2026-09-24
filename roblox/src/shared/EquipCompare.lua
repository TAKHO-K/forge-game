-- 장비 보기 창의 부위별 상세 줄 · "내 장비와 비교" 줄(P3b B)을 만드는 순수 함수. 클라(panels/Inspect)와 검증 (가)가 같은 함수를 쓴다.
-- 수치는 게임이 실제로 쓰는 함수에서만 나온다(화면용 복사 계산 없음): 부위 기본 효과 = Inherit.baseStat(가방 상세의 "착용 대비"와 같은 값) ·
-- 옵션 값 = Option.valueOf(그 장비를 쥔 사람의 직업 기준 - 직업 특화 옵션은 직업이 다르면 0) · 무기 배율 = PlayerCombat.gradeMultiplier × Enhance.getTotalMultiplier.
-- 입력 스냅샷 = PlayerInspect.buildSnapshot 모양({ classId, weapon = { gradeId, level, gems }, equipment = { armor, gloves, shoes } }) 또는 리더보드 카드(equipment 없음 = 비공개).
-- 줄 = { label, theirs(글), mine(글 | nil), diff(글 | nil), sign(1 좋음 · -1 나쁨 · 0 같음 | nil = 비교 불가) }. 차이는 "상대 − 나"(상대 장비가 나보다 얼마나 좋은가).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Option = require(ReplicatedStorage.Shared.Option)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)

local EquipCompare = {}

EquipCompare.gemSlots = 5
EquipCompare.parts = { "armor", "gloves", "shoes" }
-- 창의 줄 순서(위에서 아래).
EquipCompare.slotOrder = { "weapon", "armor", "gloves", "shoes", "gem1", "gem2", "gem3", "gem4", "gem5" }

local function gradeIndex(gradeId)
	return table.find(ArmorData.gradeOrder, gradeId) or 0
end

local function gradeName(gradeId)
	local grade = ArmorData.grades[gradeId]
	return grade and grade.displayName or "-"
end

local function signOf(delta)
	if math.abs(delta) < 1e-9 then
		return 0
	end
	return delta > 0 and 1 or -1
end

-- 슬롯 이름 → 그 스냅샷의 물건. 반환 (item | nil, hidden) - hidden = 리더보드 카드처럼 공개되지 않은 칸.
function EquipCompare.slotItem(snapshot, slotName)
	if not snapshot then
		return nil, false
	end
	if slotName == "weapon" then
		return snapshot.weapon, false
	end
	local gemSlot = tonumber(slotName:match("^gem(%d)$"))
	if gemSlot then
		local gem = snapshot.weapon and snapshot.weapon.gems and snapshot.weapon.gems[gemSlot]
		return gem or nil, false
	end
	if snapshot.equipment == nil then
		return nil, true -- 방어구 비공개(카드)
	end
	return snapshot.equipment[slotName] or nil, false
end

-- 무기 배율(등급 배율 × 강화 누적 배율) - 공격력에 곱해지는 무기 몫.
function EquipCompare.weaponMultiplier(weapon)
	local gradeMultiplier = PlayerCombat.gradeMultiplier(gradeIndex(weapon.gradeId) - 1)
	return gradeMultiplier * Enhance.getTotalMultiplier(weapon.level or 0)
end

-- 배율 글: 1000 미만은 소수 둘째 자리(NumberFormat은 정수로 버린다), 그 위는 NumberFormat 단위.
local function multText(value)
	if value < 1000 then
		return ("×%.2f"):format(value)
	end
	return "×" .. NumberFormat.format(value)
end

local function filledGems(weapon)
	local count = 0
	for slot = 1, EquipCompare.gemSlots do
		if weapon.gems and weapon.gems[slot] then
			count += 1
		end
	end
	return count
end

-- 부위 기본 효과의 글 · 수치(Inherit.baseStat).
local function baseStatText(part, value)
	if part == "armor" then
		return ("방어력 %s"):format(NumberFormat.format(math.floor(value)))
	elseif part == "gloves" then
		return ("공격력 +%.1f%%"):format(value * 100)
	end
	return ("이동+공속 +%.1f%%"):format(value * 100)
end

local function baseStatDiff(part, delta)
	if part == "armor" then
		return ("%s%s"):format(delta >= 0 and "+" or "-", NumberFormat.format(math.floor(math.abs(delta))))
	end
	return ("%+.1f%%p"):format(delta * 100)
end

-- 굴림 위치(0 ~ 100%): 옵션 굴림이 그 등급 · 레벨 범위의 어디쯤인가(가방 상세 게이지와 같은 식).
function EquipCompare.rollPercent(roll)
	return math.clamp((roll - OptionData.rollMin) / (OptionData.rollMax - OptionData.rollMin), 0, 1) * 100
end

-- 옵션 한 개의 수치 목록 { { label, value(수) , text } } - 치명은 두 줄.
local function optionValues(item, classId)
	local option = item and item.option
	if not option or not OptionData.options[option.id] then
		return {}
	end
	local lines = ItemDescribe.optionLines(item, classId)
	local value = Option.valueOf(option, item.grade, item.itemLevel, classId)
	if option.id == "crit" then
		return {
			{ key = "crit.rate", label = "옵션", value = value.critRate, text = lines[1].text, pct = true },
			{ key = "crit.dmg", label = "옵션", value = value.critDmg, text = lines[2].text, pct = false },
		}
	end
	return { { key = option.id, label = "옵션", value = value, text = lines[1].text, pct = true } }
end

local function line(label, theirs, mine, diff, sign)
	return { label = label, theirs = theirs, mine = mine, diff = diff, sign = sign }
end

-- 한 칸의 상세 줄. mineItem · myClassId가 nil이면 비교 없음(상대 값만). theirClassId = 그 장비를 쥔 사람의 직업.
function EquipCompare.lines(slotName, theirItem, mineItem, theirClassId, myClassId, compare)
	local out = {}
	local function mineOr(text)
		return compare and (text or "없음") or nil
	end
	if slotName == "weapon" then
		local t, m = theirItem, compare and mineItem or nil
		table.insert(out, line("등급", gradeName(t.gradeId), mineOr(m and gradeName(m.gradeId)), m and ("%+d단계"):format(gradeIndex(t.gradeId) - gradeIndex(m.gradeId)) or nil,
			m and signOf(gradeIndex(t.gradeId) - gradeIndex(m.gradeId)) or nil))
		table.insert(out, line("강화", ("+%d"):format(t.level or 0), mineOr(m and ("+%d"):format(m.level or 0)), m and ("%+d"):format((t.level or 0) - (m.level or 0)) or nil,
			m and signOf((t.level or 0) - (m.level or 0)) or nil))
		local tm = EquipCompare.weaponMultiplier(t)
		local mm = m and EquipCompare.weaponMultiplier(m)
		table.insert(out, line("무기 배율", multText(tm), mineOr(mm and multText(mm)),
			mm and mm > 0 and ("%+.1f%%"):format((tm / mm - 1) * 100) or nil, mm and signOf(tm - mm) or nil))
		table.insert(out, line("보석", ("%d / %d칸"):format(filledGems(t), EquipCompare.gemSlots), mineOr(m and ("%d / %d칸"):format(filledGems(m), EquipCompare.gemSlots)),
			m and ("%+d"):format(filledGems(t) - filledGems(m)) or nil, m and signOf(filledGems(t) - filledGems(m)) or nil))
		return out
	end

	local isGem = slotName:match("^gem") ~= nil
	local t, m = theirItem, compare and mineItem or nil
	if not t then
		table.insert(out, line(isGem and "보석" or "장비", "없음", mineOr(m and (isGem and ItemDescribe.gem(m).title or ItemDescribe.item(m, myClassId).title)), nil, nil))
		return out
	end
	local ti = gradeIndex(t.grade)
	local mi = m and gradeIndex(m.grade)
	table.insert(out, line("등급", gradeName(t.grade), mineOr(m and gradeName(m.grade)), m and ("%+d단계"):format(ti - mi) or nil, m and signOf(ti - mi) or nil))
	table.insert(out, line("레벨", ("Lv.%d"):format(t.itemLevel or 0), mineOr(m and ("Lv.%d"):format(m.itemLevel or 0)),
		m and ("%+d"):format((t.itemLevel or 0) - (m.itemLevel or 0)) or nil, m and signOf((t.itemLevel or 0) - (m.itemLevel or 0)) or nil))
	if not isGem then
		local part = slotName
		local tv = Inherit.baseStat(t)
		local mv = m and Inherit.baseStat(m)
		table.insert(out, line("기본 효과", baseStatText(part, tv), mineOr(m and baseStatText(part, mv)), m and baseStatDiff(part, tv - mv) or nil, m and signOf(tv - mv) or nil))
	end
	local tOptions = optionValues(t, theirClassId)
	local mOptions = m and optionValues(m, myClassId) or {}
	if #tOptions == 0 then
		table.insert(out, line("옵션", "없음", mineOr(m and (mOptions[1] and mOptions[1].text or "없음")), nil, nil))
	end
	for i, option in ipairs(tOptions) do
		local mineOption = mOptions[i]
		local same = mineOption and mineOption.key == option.key
		local diffText, sign
		if same then
			local delta = option.value - mineOption.value
			diffText = option.pct and ("%+.1f%%p"):format(delta * 100) or ("%+.2f"):format(delta)
			sign = signOf(delta)
		end
		table.insert(out, line("옵션", option.text, mineOr(m and (mineOption and mineOption.text or "없음")), diffText, sign))
	end
	if t.option and t.option.roll then
		local tr = EquipCompare.rollPercent(t.option.roll)
		local mr = m and m.option and m.option.roll and EquipCompare.rollPercent(m.option.roll)
		table.insert(out, line("굴림 위치", ("%.0f%%"):format(tr), mineOr(mr and ("%.0f%%"):format(mr)), mr and ("%+.0f%%p"):format(tr - mr) or nil, mr and signOf(tr - mr) or nil))
	end
	return out
end

-- 줄 머리의 요약 차이(비교 켰을 때) - 무기 = 무기 배율 · 방어구 = 기본 효과 · 보석 = 같은 옵션일 때 값. 반환 (글 | nil, sign).
function EquipCompare.summary(slotName, theirItem, mineItem, theirClassId, myClassId)
	if not theirItem or not mineItem then
		return nil, nil
	end
	local lines = EquipCompare.lines(slotName, theirItem, mineItem, theirClassId, myClassId, true)
	local wanted = slotName == "weapon" and "무기 배율" or (slotName:match("^gem") and "옵션" or "기본 효과")
	for _, entry in ipairs(lines) do
		if entry.label == wanted and entry.diff then
			return entry.diff, entry.sign
		end
	end
	return nil, nil
end

-- 줄 머리 제목(등급색 id · 글). 무기 = "전설 기본 무기 +12" · 장비 = ItemDescribe 제목 · 보석 = ItemDescribe.gem 제목.
function EquipCompare.title(slotName, item, classId)
	if slotName == "weapon" then
		local described = ItemDescribe.weapon(item.gradeId, item.level)
		return ("%s +%d"):format(described.title, item.level or 0), item.gradeId
	end
	if slotName:match("^gem") then
		return ItemDescribe.gem(item, classId).title, item.grade
	end
	return ItemDescribe.item(item, classId).title, item.grade
end

EquipCompare.gradeVisual = function(gradeId)
	return ItemVisualData.gradeVisuals[gradeId]
end

return EquipCompare
