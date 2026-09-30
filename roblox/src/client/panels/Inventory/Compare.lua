-- 착용 중인 장비와의 비교 줄(QUEUE-ALL2 P2 ref 17 - 상세 카드 · 비교 툴팁이 같은 글). 순수(Instance 없음) - 반환 = { { text, color } }.
--   기본 효과(부위 수치 - shared/Inherit.baseStat, 서버 계승 판정과 같은 값) 차이: ▲ 초록 = 오름 · ▼ 빨강 = 내림 · = 회색 = 같음(색 + 모양 - 색만으로 구분하지 않는다).
--   옵션: 같은 옵션이면 값 차이(▲ / ▼) · 다른 옵션이면 착용 중 옵션을 한 줄로 같이 보여 준다(축이 달라 수치 비교를 하지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Option = require(ReplicatedStorage.Shared.Option)
local Text = require(ReplicatedStorage.Shared.Text)

local Compare = {}

local function signed(key, stat, value, color)
	return { text = Text.get(key, { stat = stat, value = value }), color = color }
end

-- 기본 효과 한 줄. equipped = 같은 부위에 착용 중인 아이템(nil = 비어 있음)
function Compare.baseLine(item, equipped)
	local part = item.part or "armor"
	local stat = Text.get("inv.cmp.stat." .. part)
	if not equipped then
		return { text = Text.get("inv.cmp.none", { part = ItemVisualData.partDisplayNames[part] or "" }), color = UIColors.success }
	end
	local diff = Inherit.baseStat(item) - Inherit.baseStat(equipped)
	local value, zero
	if part == "armor" then
		local whole = math.floor(math.abs(diff))
		value, zero = NumberFormat.format(whole), whole == 0
	else
		value, zero = ("%.1f%%p"):format(math.abs(diff) * 100), math.abs(diff) < 0.0005
	end
	if zero then
		return { text = Text.get("inv.cmp.same", { stat = stat }), color = UIColors.textSecondary }
	elseif diff > 0 then
		return signed("inv.cmp.up", stat, value, UIColors.success)
	end
	return signed("inv.cmp.down", stat, value, UIColors.danger)
end

-- 옵션 줄들(includeOwn = 이 아이템의 옵션 글도 앞에 - 툴팁. 상세 카드는 옵션 게이지가 따로 있어 차이 줄만)
function Compare.optionLines(item, equipped, classId, includeOwn)
	local lines = {}
	if includeOwn then
		for _, line in ipairs(ItemDescribe.optionLines(item, classId)) do
			local color = line.dim and UIColors.textTertiary or (line.accentClassId and UIColors.classAccent[line.accentClassId]) or UIColors.textPrimary
			table.insert(lines, { text = line.text, color = color })
		end
	end
	if not equipped then
		return lines
	end
	local mine, theirs = item.option, equipped.option
	if mine and theirs and mine.id == theirs.id and mine.id ~= "crit" then
		local a = Option.valueOf(mine, item.grade, item.itemLevel, classId)
		local b = Option.valueOf(theirs, equipped.grade, equipped.itemLevel, classId)
		if type(a) == "number" and type(b) == "number" then
			local tagInfo = ItemDescribe.optionTag(item, classId)
			local name = tagInfo and tagInfo.text or ""
			local diff = (a - b) * 100
			if math.abs(diff) >= 0.05 then
				table.insert(lines, signed(diff > 0 and "inv.cmp.up" or "inv.cmp.down", name, ("%.1f%%p"):format(math.abs(diff)), diff > 0 and UIColors.success or UIColors.danger))
			end
			return lines
		end
	end
	local texts = {}
	for _, line in ipairs(ItemDescribe.optionLines(equipped, classId)) do
		table.insert(texts, line.text)
	end
	if #texts > 0 then
		table.insert(lines, { text = Text.get("inv.cmp.equippedOption", { text = table.concat(texts, " · ") }), color = UIColors.textSecondary })
	end
	return lines
end

return Compare
