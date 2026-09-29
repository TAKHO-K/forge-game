-- QUEUE-6h-b R2 저장 안전 감사(블록 R2(가) - 순수: SaveSystem.migrate · isValidProfile · sanitizeForSave만 부른다 · DataStore 호출 없음).
--   ① 이관 체인 전수: 버전 0 ~ 현재 직전마다 최소 표본(골드 · 장비 1 · 직업 상태)을 현재 버전까지 → 스키마 통과 · 값 보존
--   ② 멱등(옛 계정): 현재 모양의 꽉 찬 표본에 version = v(40 ~ 현재 직전)를 붙여 이관 → 이미 있는 값이 덮이지 않는가
--   ③ 새 계정: migrate({}) 기본값 완전성(이정표 · 출석 · 퀘스트 · 펫 · 설정 · 수련)
--   ④ 손상 입력: NaN · inf · 음수 · 타입 틀림 · 큰 배열 · 모르는 필드 → 스키마 거부 또는 저장 직전 안전값
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)

local SaveAuditVerify = {}

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = deepCopy(x)
	end
	return out
end

function SaveAuditVerify.runPure()
	local SaveSystem = require(script.Parent.SaveSystem)
	local pass, total = 0, 0
	local failures = {}
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		else
			table.insert(failures, label)
		end
		print(("[R2][가] %s %s"):format(label, ok and "O" or "X"))
	end
	print("===R2 검증 시작(가)===")
	local current = SaveConfig.saveVersion

	-- ① 이관 체인 전체: 실제 v0 모양 표본(골드 · 옛 장비 칸 · 옛 스테이지 기록)이 54단계를 전부 지나 현재 버전이 되는가.
	--   v1 이후 버전마다의 "그 버전 모양" 표본은 옛 스키마를 되살려야 해서 만들지 않는다 - 단계 하나하나는 기존 블록(G1-2 v35 · M1-3T v40 · P25b v30 ~ 32 · Q0 v49 ~ 53 등)이 따로 본다.
	local v0 = { version = 0, gold = 12345, equipment = { weapon = nil, armor = nil, gloves = nil, shoes = nil }, stageProgress = { normal = 3, infinite = 40 }, gamepasses = {} }
	local okChain, chained = pcall(SaveSystem.migrate, deepCopy(v0))
	check(("이관 체인 v0 → v%d(54단계 전부): 에러 없음 · 스키마 통과 · 골드 보존(%s)"):format(current, okChain and tostring(chained.gold) or tostring(chained)),
		okChain and chained.version == current and SaveSystem.isValidProfile(chained) and chained.gold == 12345)
	local okTwice, twice = pcall(SaveSystem.migrate, okChain and deepCopy(chained) or {})
	check("이관 두 번(이미 현재 버전) = 변화 없음(골드 · 스키마)", okTwice and twice.version == current and twice.gold == 12345 and SaveSystem.isValidProfile(twice))

	-- ③ 새 계정 기본값
	local okNew, fresh = pcall(SaveSystem.migrate, {})
	local q = okNew and fresh.quests
	check("새 계정 migrate({}) = 스키마 통과 · 현재 버전", okNew and fresh.version == current and SaveSystem.isValidProfile(fresh))
	check("새 계정: 이정표 1단계 · 출석 0일 · 메인 퀘스트 1", q ~= nil and q.guide == 1 and type(q.attendance) == "table" and q.attendance.count == 0 and q.main == 1)
	check("새 계정: 펫 빈 상태 · 설정 빈 표(= 기본값) · 수련 0 · 알 가방 빈 표", okNew and type(fresh.pets) == "table" and #fresh.pets.list == 0 and fresh.pets.hatchCount == 0
		and type(fresh.settings) == "table" and next(fresh.settings) == nil and fresh.training and fresh.training.attack == 0 and type(fresh.eggs) == "table" and #fresh.eggs == 0)

	-- ② 멱등(옛 계정 - 이미 있는 값이 이관 단계에서 덮이지 않는가)
	local full = deepCopy(fresh)
	full.gold = 777777
	full.pets = { list = { { species = "crystalBat", grade = "rare", zone = "tier2", at = 1 } }, equipped = 1, hatchCount = 3, hatching = {} }
	full.settings = { reduceFlashes = true, screenShake = false }
	full.training = { attack = 5, hp = 4, defense = 3 }
	full.quests.main = 4
	full.eggs = { { zone = "tier1", grade = "good", species = { "stoneTurtle", "mossHare" }, nest = "t1_a_rock", at = 2 } }
	full.titles = { curious = true }
	full.inventory = { { grade = "legendary", part = "gloves", itemLevel = 40, setZone = "tier3", skillVariant = { classId = "bow", slot = "E", id = "far" } } }
	local clobbered = {}
	for v = 40, current - 1 do
		local copy = deepCopy(full)
		copy.version = v
		local ok, m = pcall(SaveSystem.migrate, copy)
		local miss = {}
		if not ok then
			table.insert(miss, "에러")
		else
			if m.gold ~= 777777 then table.insert(miss, "gold") end
			if not (m.pets and #m.pets.list == 1 and m.pets.hatchCount == 3) then table.insert(miss, "pets") end
			if not (m.settings and m.settings.reduceFlashes == true and m.settings.screenShake == false) then table.insert(miss, "settings") end
			if not (m.training and m.training.attack == 5) then table.insert(miss, "training") end
			if not (m.quests and m.quests.main == 4) then table.insert(miss, "quests") end
			if not (m.eggs and #m.eggs == 1) then table.insert(miss, "eggs") end
			if not (m.titles and m.titles.curious) then table.insert(miss, "titles") end
			local it = m.inventory and m.inventory[1]
			if not (it and it.grade == "legendary" and it.itemLevel == 40 and it.skillVariant and it.skillVariant.id == "far") then table.insert(miss, "inventory") end
			if not SaveSystem.isValidProfile(m) then table.insert(miss, "스키마") end
		end
		if #miss > 0 then
			table.insert(clobbered, ("v%d:%s"):format(v, table.concat(miss, "/")))
		end
	end
	check(("멱등 v40 ~ v%d: 이미 있는 값(골드 · 펫 · 설정 · 수련 · 퀘스트 · 알 · 칭호 · 장비 · 변형) 보존(덮임 %d: %s)"):format(current - 1, #clobbered, table.concat(clobbered, " · ")), #clobbered == 0)

	-- ④ 손상 입력
	local function withField(mutate)
		local c = deepCopy(fresh)
		mutate(c)
		local ok, valid = pcall(SaveSystem.isValidProfile, c)
		return ok and valid, ok
	end
	local rows = {}
	local function reject(label, mutate)
		local valid, noErr = withField(mutate)
		table.insert(rows, ("%s=%s"):format(label, noErr and (valid and "통과" or "거부") or "에러"))
		return noErr and not valid
	end
	local r1 = reject("골드 문자열", function(c) c.gold = "x" end)
	local r2 = reject("가방 nil", function(c) c.inventory = nil end)
	local r3 = reject("칸 수 문자열", function(c) c.inventorySlots = "20" end)
	local r4 = reject("장비 옵션 모르는 id", function(c) c.inventory = { { grade = "epic", part = "armor", itemLevel = 1, option = { id = "없는옵션" } } } end)
	check(("손상 입력 스키마 거부(타입 틀림 · 필수 없음 · 모르는 옵션): %s"):format(table.concat(rows, " · ")), r1 and r2 and r3 and r4)
	local rows2 = {}
	local function accepted(label, mutate)
		local valid, noErr = withField(mutate)
		table.insert(rows2, ("%s=%s"):format(label, noErr and (valid and "통과" or "거부") or "에러"))
		return noErr
	end
	local a1 = accepted("모르는 필드", function(c) c.someFutureField = { x = 1 } end)
	local big = {}
	for i = 1, 5000 do
		big[i] = { grade = "normal", part = "armor", itemLevel = 1 }
	end
	local a2 = accepted("가방 5,000개", function(c) c.inventory = big end)
	local a3 = accepted("음수 골드", function(c) c.gold = -5 end)
	check(("손상 입력 에러 없이 판정(모르는 필드 · 큰 배열 · 음수): %s"):format(table.concat(rows2, " · ")), a1 and a2 and a3)
	-- 저장 직전 NaN · inf → 이전 값 또는 0
	local node = { gold = 0 / 0, gemDust = math.huge, nested = { hp = -math.huge, ok = 5 } }
	local old = { gold = 100, gemDust = 7, nested = { hp = 3 } }
	SaveSystem.sanitizeForSave(node, old, "t")
	check(("저장 직전 NaN · inf → 이전 값(골드 %s · 가루 %s · 중첩 %s · 정상 %s)"):format(tostring(node.gold), tostring(node.gemDust), tostring(node.nested.hp), tostring(node.nested.ok)),
		node.gold == 100 and node.gemDust == 7 and node.nested.hp == 3 and node.nested.ok == 5)
	local node2 = { gold = 0 / 0 }
	SaveSystem.sanitizeForSave(node2, nil, "t")
	check("저장 직전 NaN(옛 값 없음) → 0", node2.gold == 0)

	print(("===R2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total, failures
end

return SaveAuditVerify
