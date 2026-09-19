-- S05b 자동 검증(PRD 20.87) - 저장 집합의 키를 문자열로 통일(SAVE_VERSION 28): classes[*].stageProgress.bossFirstClearStages · tutorial.granted.
-- 결함: DataStore 왕복이 숫자 키를 문자열로 돌려줘 숫자 키 조회(hasBossFirstClearReward)가 재접속 뒤 저장된 기록을 못 찾았다 - 재접속마다 첫 클리어 확정 드랍이 다시 나왔다.
--   (가) 합성 프로필 - 서버 시작 때(플레이어 없이). DataStore가 돌려줄 수 있는 모양(숫자 키 · 문자열 키 · 섞임 · 배열 모양)을 실제 SaveSystem.migrate에 통과시킨다.
--   (나) 실제 Player의 실제 처치 경로(applyDamage → resolveHit) - 첫 처치에서만 Loot.rollBossFirstClearDrop이 불리는지 호출 횟수로 센다. 보스 검증 체인의 끝에서 돈다.
--   check · clean - **저장 → 재접속 왕복**은 순수 검증(가)이 못 본다(S05 교훈). DevTools "/gg keycheck" · "/gg keyclean"이 부른다(Play 두 번에 걸쳐 손으로 이어 간다).
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼. 검증이 만든 것(보스 · 프로필 값 · 캐릭터 위치)은 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local Loot = require(ReplicatedStorage.Shared.Loot)
local BossEncounter = require(script.Parent.BossEncounter)
local LootRuleVerify = require(script.Parent.LootRuleVerify)
local MonsterState = require(script.Parent.MonsterState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)
local SaveSystem = require(script.Parent.SaveSystem)

local SaveKeyVerify = {}

-- 지급 스테이지(방지권 - Enhance.getBossGrant)가 아닌 보스 스테이지 - 처치가 계정 지급(purchases)을 건드리지 않는다. 개발 계정의 기존 기록(5 · 10 · 20)과도 겹치지 않는다.
local PROBE_STAGE = 3 * BossData.stageInterval
-- 견습 확정 지급 기록으로 쓰는 단계(1 ~ 3단계 지급 중 하나) - 재접속 검증에서 tutorial.granted를 확인하는 데 쓴다.
local PROBE_TUTORIAL_STEP = 2

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S05b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- 집합의 키를 "5(string) 10(string)" 꼴로(정렬). 비었으면 "없음".
local function describeKeys(set)
	local parts = {}
	for key in pairs(set) do
		table.insert(parts, ("%s(%s)"):format(tostring(key), typeof(key)))
	end
	table.sort(parts)
	return #parts > 0 and table.concat(parts, " ") or "없음"
end

local function numericKeyCount(set)
	local count = 0
	for key in pairs(set) do
		if type(key) ~= "string" then
			count += 1
		end
	end
	return count
end

local function countKeys(set)
	local count = 0
	for _ in pairs(set) do
		count += 1
	end
	return count
end

-- ─────────────────────────── (가) 합성 프로필 ───────────────────────────

-- DataStore를 왕복한 v27 프로필의 여러 모양. 직업 4개: A = 숫자 키 · B = 문자열 + 숫자 섞임 · C = 같은 스테이지가 숫자와 문자열로 둘 다 · D = 이미 문자열(개발 계정의 현재 모양).
local function buildV27Profile(classIds)
	local profile = SaveSystem.defaultProfile()
	profile.version = 27
	profile.classes[classIds[1]].stageProgress.bossFirstClearStages = { [5] = true, [10] = true }
	profile.classes[classIds[2]].stageProgress.bossFirstClearStages = { ["20"] = true, [25] = true }
	profile.classes[classIds[3]].stageProgress.bossFirstClearStages = { [5] = true, ["5"] = true }
	profile.classes[classIds[4]].stageProgress.bossFirstClearStages = { ["5"] = true, ["10"] = true, ["20"] = true }
	profile.tutorial.granted = { [1] = true, [2] = true, [3] = true, [7] = true }
	return profile
end

function SaveKeyVerify.runPure()
	print("===S05b 검증 시작(가: 저장 집합 키 문자열 통일 v27 → v28)===")
	local r = newRecorder("가")
	local classIds = ClassData.order

	r.section("이관", function()
		local before = buildV27Profile(classIds)
		local migrated = SaveSystem.migrate(deepCopy(before))
		local sets = {}
		for index, classId in ipairs(classIds) do
			sets[index] = migrated.classes[classId].stageProgress.bossFirstClearStages
		end

		r.check(("① 숫자 키 {[5]·[10]} → %s(기대 5(string) 10(string) · 값 true) ★진짜 합격 기준"):format(describeKeys(sets[1])),
			sets[1]["5"] == true and sets[1]["10"] == true and countKeys(sets[1]) == 2 and numericKeyCount(sets[1]) == 0)
		r.check(("② 문자열 · 숫자 섞임 {[\"20\"]·[25]} → %s(기대 20(string) 25(string))"):format(describeKeys(sets[2])),
			sets[2]["20"] == true and sets[2]["25"] == true and countKeys(sets[2]) == 2 and numericKeyCount(sets[2]) == 0)
		r.check(("③ 같은 스테이지가 숫자 · 문자열로 둘 다 {[5]·[\"5\"]} → %s(기대 5(string) 하나)"):format(describeKeys(sets[3])),
			sets[3]["5"] == true and countKeys(sets[3]) == 1)
		r.check(("④ 이미 문자열 {\"5\"·\"10\"·\"20\"}(개발 계정의 현재 모양) → %s(기대 그대로)"):format(describeKeys(sets[4])),
			sets[4]["5"] == true and sets[4]["10"] == true and sets[4]["20"] == true and countKeys(sets[4]) == 3 and numericKeyCount(sets[4]) == 0)
		local granted = migrated.tutorial.granted
		r.check(("⑤ tutorial.granted {[1]·[2]·[3]·[7]} → %s(기대 1 · 2 · 3 · 7 전부 string)"):format(describeKeys(granted)),
			granted["1"] == true and granted["2"] == true and granted["3"] == true and granted["7"] == true and countKeys(granted) == 4 and numericKeyCount(granted) == 0)

		-- ⑥ 나머지는 하나도 안 바뀐다: 이관 전 복사본에 기대 집합 · version만 고친 것과 통째로 비교한다.
		local expected = deepCopy(before)
		expected.version = SaveConfig.saveVersion
		expected.classes[classIds[1]].stageProgress.bossFirstClearStages = { ["5"] = true, ["10"] = true }
		expected.classes[classIds[2]].stageProgress.bossFirstClearStages = { ["20"] = true, ["25"] = true }
		expected.classes[classIds[3]].stageProgress.bossFirstClearStages = { ["5"] = true }
		expected.tutorial.granted = { ["1"] = true, ["2"] = true, ["3"] = true, ["7"] = true }
		local diffs = {}
		deepEqual(migrated, expected, "profile", diffs)
		r.check(("⑥ 이관 전 복사본에 기대 집합 · version만 고친 것과 통째로 비교: 다른 곳 %d개%s(기대 0)"):format(#diffs, #diffs > 0 and (" - " .. diffs[1]) or ""), #diffs == 0)

		-- ⑦ 멱등: 이미 v28인 것을 다시 통과 · 버전을 27로 되돌려 이관을 실제로 한 번 더 돌린다 - 둘 다 같은 결과.
		local again = deepCopy(migrated)
		SaveSystem.migrate(again)
		local forced = deepCopy(migrated)
		forced.version = 27
		SaveSystem.migrate(forced)
		local diffsA, diffsB = {}, {}
		deepEqual(again, migrated, "again", diffsA)
		deepEqual(forced, migrated, "forced", diffsB)
		r.check(("⑦ 이관을 두 번 돌림: v28 그대로 다시 %d곳 · 버전을 27로 되돌려 다시 %d곳 다름(기대 0 · 0)"):format(#diffsA, #diffsB), #diffsA == 0 and #diffsB == 0)

		r.check(("⑧ 이관 뒤 version=%d(기대 %d) · isValidProfile=%s(기대 true)"):format(migrated.version, SaveConfig.saveVersion, tostring(SaveSystem.isValidProfile(migrated))),
			migrated.version == SaveConfig.saveVersion and SaveSystem.isValidProfile(migrated))
	end)

	r.section("옛 버전 · 배열 모양", function()
		-- 옛 버전(v26)에서 시작해도 순차 이관을 지나며 같은 결과가 나온다.
		local old = buildV27Profile(classIds)
		old.version = 26
		local migratedOld = SaveSystem.migrate(old)
		local oldSet = migratedOld.classes[classIds[1]].stageProgress.bossFirstClearStages
		r.check(("⑨ v26에서 시작한 숫자 키 집합 → %s · version %d(기대 5(string) 10(string) · %d)"):format(describeKeys(oldSet), migratedOld.version, SaveConfig.saveVersion),
			oldSet["5"] == true and oldSet["10"] == true and numericKeyCount(oldSet) == 0 and migratedOld.version == SaveConfig.saveVersion)

		-- DataStore는 1 ~ n이 빈틈없이 이어진 키를 배열로 저장해 숫자 키(1 · 2 · 3)로 돌려준다 - 값이 true뿐인 배열 모양.
		local arrayShaped = SaveSystem.defaultProfile()
		arrayShaped.version = 27
		arrayShaped.tutorial.granted = { true, true, true }
		local migratedArray = SaveSystem.migrate(arrayShaped)
		r.check(("⑩ 배열 모양 tutorial.granted {true, true, true} → %s(기대 1 · 2 · 3 전부 string)"):format(describeKeys(migratedArray.tutorial.granted)),
			migratedArray.tutorial.granted["1"] == true and migratedArray.tutorial.granted["2"] == true and migratedArray.tutorial.granted["3"] == true
				and countKeys(migratedArray.tutorial.granted) == 3 and numericKeyCount(migratedArray.tutorial.granted) == 0)

		-- 새 계정(빈 집합)은 그대로 빈 집합.
		local fresh = SaveSystem.migrate({})
		r.check(("⑪ 신규 계정 이관: 집합 %d개 · %d개(기대 0 · 0) · isValidProfile=%s"):format(
			countKeys(fresh.classes[classIds[1]].stageProgress.bossFirstClearStages), countKeys(fresh.tutorial.granted), tostring(SaveSystem.isValidProfile(fresh))),
			countKeys(fresh.classes[classIds[1]].stageProgress.bossFirstClearStages) == 0 and countKeys(fresh.tutorial.granted) == 0 and SaveSystem.isValidProfile(fresh))
	end)

	local pass, total = r.summary()
	print(("===S05b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 경로 ───────────────────────────

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- 보스를 실제 처치 경로로 한 번 잡고 그동안 Loot.rollBossFirstClearDrop이 몇 번 불렸는지 돌려준다(첫 클리어 확정 드랍의 호출 횟수). 스폰 실패면 nil.
local function killAndCountFirstClearDrops(player, env, stage)
	local model, data = LootRuleVerify.spawnBossAt(player, env, stage)
	if not model then
		return nil
	end
	local original = Loot.rollBossFirstClearDrop
	local calls = 0
	Loot.rollBossFirstClearDrop = function(...)
		calls += 1
		return original(...)
	end
	local ok, err = pcall(LootRuleVerify.killBoss, player, model, data, stage)
	Loot.rollBossFirstClearDrop = original
	if not ok then
		BossEncounter.despawnFor(player)
		error(err)
	end
	return calls
end

local function activeStageSet(profile)
	return profile.classes[profile.classId].stageProgress.bossFirstClearStages
end

function SaveKeyVerify.runLive(player, env)
	print("===S05b 검증 시작(나: 실제 처치 경로 · 첫 클리어 확정 드랍 호출 횟수)===")
	local r = newRecorder("나")
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root or not profile.classId then
		r.check("프로필 · 캐릭터 · 직업이 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S05b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	-- ① 로드된 실제 프로필: 모든 직업의 bossFirstClearStages · tutorial.granted에 숫자 키가 없다(v28 이관 · 재접속 뒤 모양).
	local numeric, total = 0, 0
	for _, classId in ipairs(ClassData.order) do
		local set = profile.classes[classId].stageProgress.bossFirstClearStages
		numeric += numericKeyCount(set)
		total += countKeys(set)
	end
	numeric += numericKeyCount(profile.tutorial.granted)
	total += countKeys(profile.tutorial.granted)
	r.check(("① 로드된 프로필의 집합 키(첫 클리어 4직업 + 견습 지급) %d개 중 숫자 키 %d개(기대 0 - 전부 문자열) ★진짜 합격 기준"):format(total, numeric), numeric == 0)

	env.ensureBackup(player)
	local savedCFrame = root.CFrame
	local grantBefore = PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP)
	local savedGrant = profile.tutorial.granted[tostring(PROBE_TUTORIAL_STEP)]
	local stage = PROBE_STAGE
	local stageKey = tostring(stage)

	r.section("[2] 첫 처치 → 다시 처치", function()
		PlayerProfile.clearBossFirstClearRewards(player, stage)
		local firstCalls = killAndCountFirstClearDrops(player, env, stage)
		local set = activeStageSet(profile)
		r.check(("② 첫 처치(스테이지 %d): 확정 드랍 호출 %s회(기대 1) · 기록 %s(기대 %s(string)만) · hasBossFirstClearReward=%s(기대 true) ★진짜 합격 기준"):format(
			stage, tostring(firstCalls), describeKeys(set), stageKey, tostring(PlayerProfile.hasBossFirstClearReward(player, stage))),
			firstCalls == 1 and set[stageKey] == true and set[stage] == nil and PlayerProfile.hasBossFirstClearReward(player, stage))

		local secondCalls = killAndCountFirstClearDrops(player, env, stage)
		r.check(("③ 같은 스테이지 다시 처치: 확정 드랍 호출 %s회(기대 0 - 재도전 드랍만) · 기록 %s(기대 그대로 1개)"):format(
			tostring(secondCalls), describeKeys(activeStageSet(profile))),
			secondCalls == 0 and countKeys(activeStageSet(profile)) >= 1 and activeStageSet(profile)[stageKey] == true)
	end)

	r.section("[4] 견습 지급 기록", function()
		profile.tutorial.granted[tostring(PROBE_TUTORIAL_STEP)] = nil
		local missing = PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP)
		PlayerProfile.markTutorialGrant(player, PROBE_TUTORIAL_STEP)
		local granted = profile.tutorial.granted
		r.check(("④ 견습 %d단계 지급 표시 전 %s(기대 false) → 표시 뒤 hasTutorialGrant=%s(기대 true) · 기록 %s(기대 %d(string)만 새로 생김)"):format(
			PROBE_TUTORIAL_STEP, tostring(missing), tostring(PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP)), describeKeys(granted), PROBE_TUTORIAL_STEP),
			not missing and PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP) and granted[tostring(PROBE_TUTORIAL_STEP)] == true
				and granted[PROBE_TUTORIAL_STEP] == nil and numericKeyCount(granted) == 0)
	end)

	-- 되돌리기: restore는 직업별 상태 · 가방을 되돌리고 tutorial(계정 공유)은 손대지 않으므로 견습 지급은 직접 되돌린다.
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	profile.tutorial.granted[tostring(PROBE_TUTORIAL_STEP)] = savedGrant
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	r.check(("⑤ 검증 뒤 되돌림: encounter 없는 보스 모델 %d개 · 견습 %d단계 지급 기록 %s → %s · 스테이지 %d 첫 클리어 기록 %s(기대 0 · 처음과 같음 · 처음과 같음)"):format(
		orphans, PROBE_TUTORIAL_STEP, tostring(grantBefore), tostring(PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP)), stage,
		tostring(PlayerProfile.hasBossFirstClearReward(player, stage))),
		orphans == 0 and PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP) == grantBefore)

	local pass, totalCount = r.summary()
	print(("===S05b 검증 끝(나)=== %d/%d 통과"):format(pass, totalCount))
end

-- ─────────────────────────── 저장 → 재접속 왕복 (DevTools 수동) ───────────────────────────
-- "/gg keycheck <스테이지> [save]" - 실제 처치 한 번으로 첫 클리어 확정 드랍이 불렸는지(호출 횟수)와 저장된 집합의 실제 키 타입을 찍는다.
--   처치가 만든 것(가방 · 골드 · 경험치 · 재료)은 restore가 되돌리고, `save`를 붙이면 그 위에 **두 기록만**(스테이지 첫 클리어 · 견습 지급)을 표시하고 즉시 저장한다.
--   Play A: keycheck 15 save → (기대 호출 1회) → Play 정지 · 재시작 → Play B: keycheck 15 → (기대 호출 0회 · 기록 유지) → keyclean 15.
function SaveKeyVerify.check(player, env, stage, persist)
	local lines = {}
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root or not profile.classId then
		return { "프로필 · 캐릭터 · 직업이 없습니다" }
	end
	local grantBefore = PlayerProfile.hasTutorialGrant(player, PROBE_TUTORIAL_STEP)
	local flagBefore = PlayerProfile.hasBossFirstClearReward(player, stage)
	table.insert(lines, ("처치 전: 스테이지 %d 첫 클리어 기록=%s · 견습 %d단계 지급 기록=%s · 첫 클리어 집합 %s · 견습 지급 집합 %s"):format(
		stage, tostring(flagBefore), PROBE_TUTORIAL_STEP, tostring(grantBefore), describeKeys(activeStageSet(profile)), describeKeys(profile.tutorial.granted)))
	if persist and grantBefore then
		table.insert(lines, ("견습 %d단계 지급 기록이 이미 있어 저장 모드를 거절합니다(실제 기록을 덮어쓰지 않으려고) - 다른 단계가 필요하면 PROBE_TUTORIAL_STEP을 바꾸세요"):format(PROBE_TUTORIAL_STEP))
		return lines
	end

	env.ensureBackup(player)
	local savedCFrame = root.CFrame
	local ok, calls = pcall(killAndCountFirstClearDrops, player, env, stage)
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	table.insert(lines, ok and ("처치 결과: 첫 클리어 확정 드랍 호출 %s회 (%s)"):format(tostring(calls), flagBefore and "기대 0 - 이미 받은 스테이지" or "기대 1 - 처음 깨는 스테이지")
		or ("처치 실패: " .. tostring(calls)))
	table.insert(lines, ("처치 직후 집합: %s"):format(describeKeys(activeStageSet(profile))))
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end

	if persist then
		PlayerProfile.markBossFirstClearReward(player, stage)
		PlayerProfile.markTutorialGrant(player, PROBE_TUTORIAL_STEP)
		SaveCoordinator.saveForPlayer(player)
		table.insert(lines, ("저장 완료: 스테이지 %d 첫 클리어 · 견습 %d단계 지급만 표시 - Play를 정지하고 다시 켠 뒤 keycheck %d를 다시 부르세요"):format(stage, PROBE_TUTORIAL_STEP, stage))
	end
	return lines
end

-- keycheck save로 남긴 두 기록을 지우고 저장한다(개발 계정을 검증 전 모양으로 되돌린다).
function SaveKeyVerify.clean(player, stage)
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return "프로필이 없습니다"
	end
	PlayerProfile.clearBossFirstClearRewards(player, stage)
	profile.tutorial.granted[tostring(PROBE_TUTORIAL_STEP)] = nil
	SaveCoordinator.saveForPlayer(player)
	return ("스테이지 %d 첫 클리어 · 견습 %d단계 지급 기록을 지우고 저장했습니다 - 집합 %s · %s"):format(
		stage, PROBE_TUTORIAL_STEP, describeKeys(activeStageSet(profile)), describeKeys(profile.tutorial.granted))
end

SaveKeyVerify.probeStage = PROBE_STAGE

return SaveKeyVerify
