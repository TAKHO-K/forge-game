-- QUEUE-10h Q11 펫 규칙(순수 - 서버 판정 · 클라 확률 공개 · 검증이 같은 함수). 데이터 = PetData · EggData.
--   상태(profile.pets, SAVE v52) = { list = { { species, grade, zone, at } }, equipped = list 번호 | nil, hatchCount, hatching = { { egg, doneAt } } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PetData = require(ReplicatedStorage.Shared.data.PetData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)

local Pet = {}

function Pet.newState()
	return { list = {}, equipped = nil, hatchCount = 0, hatching = {} }
end

-- UI-1 7c(H v1.1 §2): 놓아주기 판정 = 데리고 다니지 않고(equipped ≠ 그 번호) · 잠그지 않은(locked ≠ true) 펫만. 반환 = true | false, 이유("none" · "equipped" · "locked")
function Pet.canRelease(state, index)
	local p = type(state) == "table" and type(state.list) == "table" and type(index) == "number" and state.list[index]
	if not p then
		return false, "none"
	elseif state.equipped == index then
		return false, "equipped"
	elseif p.locked == true then
		return false, "locked"
	end
	return true
end

-- 놓아준 뒤 데리고 다니는 번호 맞추기(목록에서 빠진 번호보다 뒤면 한 칸 앞으로)
function Pet.removeAt(state, index)
	table.remove(state.list, index)
	if state.equipped and state.equipped > index then
		state.equipped -= 1
	end
end

-- 부화 레벨(1부터) = 누적 부화 수가 넘은 마지막 단계
function Pet.levelOf(hatchCount)
	local level = 1
	for i, row in ipairs(PetData.levels) do
		if (hatchCount or 0) >= row.hatches then
			level = i
		end
	end
	return level
end

-- 결과 등급 확률표(%) - 알 등급 × 부화 레벨. 일반 몫에서 shift만큼 위 등급으로(일반이 모자라면 있는 만큼).
function Pet.hatchTable(eggGrade, level)
	local base = EggData.hatch[eggGrade] or EggData.hatch.normal
	local row = PetData.levels[level] or PetData.levels[1]
	local t = {}
	for _, g in ipairs(EggData.hatchGrades) do
		t[g] = base[g] or 0
	end
	local moved = math.min(row.shift, t.common or 0)
	t.common -= moved
	for g, share in pairs(PetData.shiftSplit) do
		t[g] = (t[g] or 0) + moved * share
	end
	return t
end

-- 부화 결과(rng = Random): 종 = 알 후보 candidateWeights · 등급 = hatchTable
function Pet.rollHatch(egg, level, rng)
	local weights = EggData.candidateWeights
	local sum = 0
	for i = 1, #egg.species do
		sum += weights[i] or 0
	end
	local r = rng:NextNumber() * sum
	local species = egg.species[#egg.species]
	for i = 1, #egg.species do
		r -= weights[i] or 0
		if r < 0 then
			species = egg.species[i]
			break
		end
	end
	local t = Pet.hatchTable(egg.grade, level)
	local g = rng:NextNumber() * 100
	local grade = EggData.hatchGrades[1]
	for _, id in ipairs(EggData.hatchGrades) do
		g -= t[id]
		if g < 0 then
			grade = id
			break
		end
		grade = id
	end
	return { species = species, grade = grade, zone = egg.zone }
end

function Pet.unlocked(characterLevel, key)
	local need = PetData.unlocks[key]
	return need ~= nil and (characterLevel or 0) >= need
end

function Pet.queueCap(characterLevel)
	return PetData.queueBase + (Pet.unlocked(characterLevel, "hatchQueuePlus") and 1 or 0)
end

function Pet.bodyOf(species)
	return PetData.bodyOf[species] or "dog"
end

-- 확률 공개(부화 레벨 표 전체 - 알 창)
function Pet.disclosure()
	local out = { levels = {} }
	for level, row in ipairs(PetData.levels) do
		local byEgg = {}
		for _, eggGrade in ipairs(EggData.gradeOrder) do
			byEgg[eggGrade] = Pet.hatchTable(eggGrade, level)
		end
		table.insert(out.levels, { level = level, hatches = row.hatches, byEgg = byEgg })
	end
	return out
end

return Pet
