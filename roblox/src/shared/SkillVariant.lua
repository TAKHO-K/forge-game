-- QUEUE-10h Q9 K4 스킬 변형 계산(순수 - 서버 굴림 · 적용 · 클라 툴팁 · 확률 공개가 같은 함수). 데이터 = shared/data/SkillVariantData.lua.
--   item.skillVariant = { classId, slot, id }(SAVE v51 - 옵션 필드처럼 장비에 딸린다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SkillVariantData = require(ReplicatedStorage.Shared.data.SkillVariantData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Text = require(ReplicatedStorage.Shared.Text) -- Q15: 표시 문구 = TextData(variant.*)

local SkillVariant = {}

-- 그 직업의 굴림 표(칸 × 변형 · 확률) - 칸을 먼저 고르게(같은 확률) 한 뒤 칸 안 가중치
function SkillVariant.rows(classId)
	local pools = SkillVariantData.pools[classId]
	local rows = {}
	if not pools then
		return rows
	end
	local slots = {}
	for _, slot in ipairs(SkillVariantData.slots) do
		if pools[slot] and #pools[slot] > 0 then
			table.insert(slots, slot)
		end
	end
	for _, slot in ipairs(slots) do
		local sum = 0
		for _, e in ipairs(pools[slot]) do
			sum += e.w
		end
		for _, e in ipairs(pools[slot]) do
			table.insert(rows, { classId = classId, slot = slot, id = e.id, chance = (1 / #slots) * e.w / sum })
		end
	end
	return rows
end

-- 굴림(rng = Random) - classId 없거나 풀 없으면 nil
function SkillVariant.roll(classId, rng)
	local rows = SkillVariant.rows(classId)
	if #rows == 0 then
		return nil
	end
	local r = rng:NextNumber()
	for _, row in ipairs(rows) do
		r -= row.chance
		if r < 0 then
			return { classId = row.classId, slot = row.slot, id = row.id }
		end
	end
	local last = rows[#rows]
	return { classId = last.classId, slot = last.slot, id = last.id }
end

-- 확률 공개(직업마다 칸 · 변형 · 확률 + 출현 확률)
function SkillVariant.disclosure()
	local out = { appearChance = SkillVariantData.appearChance, classes = {} }
	for _, classId in ipairs(ClassData.order) do
		out.classes[classId] = SkillVariant.rows(classId)
	end
	return out
end

-- 착용(equipment)에서 지금 직업 · 이 칸에 걸리는 변형 곱(없으면 전부 1). 같은 칸이 여럿이면 높은 등급 하나.
function SkillVariant.modsFor(equipment, classId, slot, gradeRank)
	local best, bestRank
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		local item = equipment and equipment[part]
		local v = type(item) == "table" and item.skillVariant
		if type(v) == "table" and v.classId == classId and v.slot == slot and SkillVariantData.templates[v.id] then
			local rank = gradeRank and gradeRank(item.grade) or 0
			if not best or rank > bestRank then
				best, bestRank = v, rank
			end
		end
	end
	local t = best and SkillVariantData.templates[best.id]
	return { damage = t and t.damage or 1, cooldown = t and t.cooldown or 1, range = t and t.range or 1, id = best and best.id }
end

-- 툴팁 한 줄(active = 지금 직업과 맞는가 - 아니면 회색 · "꺼짐")
function SkillVariant.describe(v, activeClassId)
	local t = type(v) == "table" and SkillVariantData.templates[v.id]
	if not t then
		return nil
	end
	local parts = {}
	for _, key in ipairs({ "damage", "cooldown", "range" }) do
		local m = t[key]
		if m and m ~= 1 then
			table.insert(parts, Text.get("variant.axis." .. key, { pct = ("%+d"):format(math.floor((m - 1) * 100 + 0.5)) }))
		end
	end
	local class = ClassData.classes[v.classId]
	return {
		text = Text.get("variant.line", { class = class and class.displayName or v.classId, slot = v.slot, name = t.name, parts = table.concat(parts, " · ") }),
		active = v.classId == activeClassId,
	}
end

return SkillVariant
