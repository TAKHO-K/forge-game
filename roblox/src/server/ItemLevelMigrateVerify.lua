-- S02 자동 검증(PRD 20.83) - v23 → v24 이관: 부풀려진 장비 itemLevel을 min(itemLevel, dropStage + 2)로 자른다.
-- 26-1의 "/gg option migrate"와 같은 방식이다 - 합성 프로필을 실제 SaveSystem.migrate에 통과시킨다.
--   (가) 합성 프로필 - 서버 시작 때(플레이어 없이).
--   (나) 실제 Player의 로드된 프로필을 읽기만 한다(고치지 않는다) - 보스 검증 체인의 끝에서 돈다. 이관 로그 한 줄
--        (`[forge-game] v24 이관: …`)은 프로필 로드 시점에 SaveSystem이 남긴다.
-- 불변식("모든 장비에서 itemLevel <= dropStage + 2")은 isValidProfile에 넣지 않았다(미결 - PRD 20.83 [6]): 견습 5 ~ 7단계의
-- 대여 장비가 dropStage = 1 · itemLevel = 캐릭터 레벨로 만들어져 정상 경로가 그 부등식을 어긴다. 그래서 (나)는 "이관 뒤 어긴 장비 수"를
-- 세어 보여 주기만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)

local ItemLevelMigrateVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S02][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[key] = deepCopy(child)
	end
	return copy
end

local function deepEqual(a, b, path, diffs)
	if type(a) ~= type(b) then
		table.insert(diffs, ("%s: 타입 %s ≠ %s"):format(path, type(a), type(b)))
		return
	end
	if type(a) ~= "table" then
		if a ~= b then
			table.insert(diffs, ("%s: %s ≠ %s"):format(path, tostring(a), tostring(b)))
		end
		return
	end
	for key, value in pairs(a) do
		deepEqual(value, b[key], path .. "." .. tostring(key), diffs)
	end
	for key in pairs(b) do
		if a[key] == nil then
			table.insert(diffs, ("%s.%s: 한쪽에만 있음"):format(path, tostring(key)))
		end
	end
end

local function makeItem(part, grade, dropStage, itemLevel, tierIndex)
	return {
		grade = grade, part = part, dropStage = dropStage, itemLevel = itemLevel, tierIndex = tierIndex,
		locked = true, option = { id = "attackPercent", roll = 1.1 },
	}
end

-- v23 시절의 합성 프로필 하나. 반환: 프로필, 기대 itemLevel 표(이관 뒤 모습을 만들려고 쓴다).
local function buildV23Profile()
	local profile = SaveSystem.defaultProfile()
	profile.version = 23
	local classA, classB = ClassData.order[1], ClassData.order[2]

	profile.inventory = {
		makeItem("armor", "primordial", 100, 420, 6), -- 1: 레벨 100 × tier6(4.21) - 옛 규칙의 최대급
		makeItem("gloves", "epic", 50, 60, 2), -- 2: 레벨이 스테이지보다 높았던 정상 아이템
		makeItem("shoes", "rare", 50, 52, 1), -- 3a: 경계(그대로)
		makeItem("armor", "normal", 50, 40, 1), -- 3b: 이미 낮은 값(그대로)
	}
	profile.classes[classB].equipment.armor = makeItem("armor", "legendary", 30, 95, 3) -- 4: 다른 직업의 착용 갑옷
	profile.classes[classA].weapon.gems[1] = { grade = "epic", option = { id = "attackPercent", roll = 1.0 }, itemLevel = 300 } -- 5: 보석
	table.insert(profile.classes[classA].gemInventory, { grade = "relic", option = { id = "attackPercent", roll = 1.0 }, itemLevel = 300 })
	profile.classes[classA].weapon.level = 12 -- 9: 강화 단계도 그대로여야 한다
	return profile
end

function ItemLevelMigrateVerify.runPure()
	print("===S02 검증 시작(가: v23 → v24 이관)===")
	local r = newRecorder("가")
	local classA, classB = ClassData.order[1], ClassData.order[2]

	r.section("이관", function()
		local before = buildV23Profile()
		local expected = deepCopy(before)
		expected.version = SaveConfig.saveVersion
		expected.inventory[1].itemLevel = 102
		expected.inventory[2].itemLevel = 52
		expected.classes[classB].equipment.armor.itemLevel = 32

		local migrated = SaveSystem.migrate(deepCopy(before))
		local bag, worn = migrated.inventory, migrated.classes[classB].equipment.armor

		r.check(("① 가방: dropStage 100 · itemLevel 420 → %d(기대 102) ★진짜 합격 기준"):format(bag[1].itemLevel), bag[1].itemLevel == 102)
		r.check(("② 가방: dropStage 50 · itemLevel 60(레벨이 스테이지보다 높았던 정상 아이템) → %d(기대 52)"):format(bag[2].itemLevel), bag[2].itemLevel == 52)
		r.check(("③ 경계 dropStage 50 · itemLevel 52 → %d(기대 52) · dropStage 50 · itemLevel 40 → %d(기대 40, 그대로)"):format(bag[3].itemLevel, bag[4].itemLevel),
			bag[3].itemLevel == 52 and bag[4].itemLevel == 40)
		r.check(("④ 다른 직업(%s)의 착용 갑옷: dropStage 30 · itemLevel 95 → %d(기대 32)"):format(classB, worn.itemLevel), worn.itemLevel == 32)
		local gem, stored = migrated.classes[classA].weapon.gems[1], migrated.classes[classA].gemInventory[1]
		r.check(("⑤ 보석 itemLevel 300 → 홈 %d · 보유 %d(기대 300 · 300, 그대로)"):format(gem.itemLevel, stored.itemLevel), gem.itemLevel == 300 and stored.itemLevel == 300)
		r.check(("⑥ 이관 뒤 version=%d(기대 %d) · isValidProfile=%s(기대 true)"):format(migrated.version, SaveConfig.saveVersion, tostring(SaveSystem.isValidProfile(migrated))),
			migrated.version == SaveConfig.saveVersion and SaveSystem.isValidProfile(migrated))

		-- ⑦ 멱등: (a) 이미 v24인 것을 다시 통과 (b) 버전을 23으로 되돌려 절단을 실제로 한 번 더 돌린다 - 둘 다 같은 결과여야 한다.
		local again = deepCopy(migrated)
		SaveSystem.migrate(again)
		local forced = deepCopy(migrated)
		forced.version = 23
		SaveSystem.migrate(forced)
		local diffsA, diffsB = {}, {}
		deepEqual(again, migrated, "again", diffsA)
		deepEqual(forced, migrated, "forced", diffsB)
		r.check(("⑦ 이관을 두 번 돌림: v24 그대로 다시 %d곳 · 버전을 23으로 되돌려 절단을 다시 %d곳 다름(기대 0 · 0) ★진짜 합격 기준"):format(#diffsA, #diffsB), #diffsA == 0 and #diffsB == 0)

		-- ⑨ itemLevel 말고는 아무것도 안 바뀐다: 이관 전 복사본에 기대 itemLevel · version만 고친 것과 통째로 비교한다
		-- (옵션 · 등급 · locked · 강화 단계 · dropStage · tierIndex · 보석 · 무기가 전부 포함된다).
		local diffs = {}
		deepEqual(migrated, expected, "profile", diffs)
		r.check(("⑨ 이관 전 복사본에 기대 itemLevel 3곳 · version만 고친 것과 통째로 비교: 다른 곳 %d개%s(기대 0 - 옵션 · 등급 · locked · 강화 단계 · dropStage · tierIndex 그대로) ★진짜 합격 기준"):format(
			#diffs, #diffs > 0 and (" - " .. diffs[1]) or ""), #diffs == 0 and migrated.classes[classA].weapon.level == 12)
	end)

	r.section("dropStage 없는 항목", function()
		local profile = buildV23Profile()
		profile.inventory[1].dropStage = nil
		local migrated = SaveSystem.migrate(profile)
		r.check(("dropStage가 없는 장비는 건드리지 않는다: itemLevel %d(기대 420, 그대로 - 개수는 이관 로그에 남는다)"):format(migrated.inventory[1].itemLevel), migrated.inventory[1].itemLevel == 420)
	end)

	print("[S02][가] ⑧ v24 프로필에 itemLevel 60 · dropStage 50을 손으로 넣으면 isValidProfile false - **보류**(불변식을 isValidProfile에 넣지 않았다 - PRD 20.83 [6] 미결) · 점수에 넣지 않는다")
	local pass, total = r.summary()
	print(("===S02 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- 실제 Player의 프로필을 읽기만 한다. 견습 대여 장비(dropStage 1 · itemLevel = 레벨)가 없고 이관이 끝난 개발 계정에서는 0이어야 한다.
function ItemLevelMigrateVerify.runLive(player)
	print("===S02 검증 시작(나: 실제 프로필 읽기 전용)===")
	local r = newRecorder("나")
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		r.check("프로필이 없어 검증을 건너뜀", false)
	else
		local total, over, worst, noStage = 0, 0, nil, 0
		local function scan(item, where)
			if type(item) ~= "table" or type(item.itemLevel) ~= "number" then
				return
			end
			total += 1
			if type(item.dropStage) ~= "number" then
				noStage += 1
			elseif item.itemLevel > item.dropStage + 2 then
				over += 1
				if not worst or item.itemLevel - item.dropStage > worst.gap then
					worst = { gap = item.itemLevel - item.dropStage, where = where, itemLevel = item.itemLevel, dropStage = item.dropStage }
				end
			end
		end
		for index, item in ipairs(profile.inventory) do
			scan(item, "가방 " .. index)
		end
		for classId, classState in pairs(profile.classes) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				scan(classState.equipment[part], classId .. "." .. part)
			end
		end
		r.check(("로드된 실제 프로필: version=%s(기대 %d) · 장비 %d개(가방 + 모든 직업 착용) 중 itemLevel > dropStage + 2 인 것 %d개%s · dropStage 없는 것 %d개 (기대 0 · 0 - 두 번째 Play라면 이관 로그도 없어야 한다)"):format(
			tostring(profile.version), SaveConfig.saveVersion, total, over,
			worst and (" - 최악 " .. worst.where .. " itemLevel " .. worst.itemLevel .. " / dropStage " .. worst.dropStage) or "", noStage),
			profile.version == SaveConfig.saveVersion and over == 0 and noStage == 0)
	end
	local pass, total = r.summary()
	print(("===S02 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return ItemLevelMigrateVerify
