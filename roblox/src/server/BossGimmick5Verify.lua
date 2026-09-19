-- 29-5 자동 검증(PRD 20.80) - 보스 배치 고정 · F 홀드 구출 · 수정 여왕(대상 선택) · 6종 튜닝 · 탱커 훅.
-- BossGimmick4Verify(29-4)와 같은 패턴이고 DevTools가 그 뒤에 이어서 부른다(같은 플레이어·같은 아레나 - 동시에 돌면 안 된다).
--   (가) 순수 계산 - 배치표·스킬표·모형. 로컬 Luau 하네스와 같은 값.
--   (나) 실제 서버 경로 - 실제 Player의 프로필·스폰 경로를 그대로 탄다.
-- env = { ensureBackup, restore, applyStage, applyOptionStack } - DevTools의 로컬 헬퍼.
-- 29-4의 교훈(X 4건이 전부 스탠드인과 읽는 시점): 스탠드인은 실제 Player가 받는 호출(SetAttribute·GetAttribute·FireClient 대상)을
-- 전부 받을 수 있어야 하고, 상태는 그것을 만드는 틱이 **지난 뒤에** 읽는다(drive 뒤).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossEncounter = require(script.Parent.BossEncounter)
local MonsterState = require(script.Parent.MonsterState)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)

local BossGimmick5Verify = {}

local GUARDIAN = "section_guardian"

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[29-5][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- ─────────────────────────── (가) 순수 계산 ───────────────────────────

-- 보스 배치(PRD 20.80 [A]) - 다른 구역이 아직 없는 로컬 하네스에서도 이 함수만 따로 부를 수 있게 떼어 둔다.
function BossGimmick5Verify.checkPlacement(r)
	local interval = BossData.stageInterval
	local allIds = BossData.pools[1].bossIds

	r.section("배치표 규칙", function()
		local problems = BossRules.validatePlacement()
		local laps = BossData.placement.laps
		-- 이웃 쌍(A 다음에 B)이 주기 안에서 되풀이되지 않는가 - 바퀴마다 흐름이 다르다는 것의 검사
		local pairSeen, repeatedPairs = {}, 0
		for _, lap in ipairs(laps) do
			for i = 1, #lap - 1 do
				local key = lap[i] .. ">" .. lap[i + 1]
				if pairSeen[key] then
					repeatedPairs += 1
				end
				pairSeen[key] = true
			end
		end
		r.check(("배치표 %d바퀴 × %d마리: 규칙 위반 %d건%s · 바퀴 안에서 되풀이되는 이웃 쌍 %d건(기대 0 - 바퀴마다 흐름이 다르다)"):format(
			#laps, #laps[1], #problems, #problems > 0 and (" [" .. table.concat(problems, " / ") .. "]") or "", repeatedPairs),
			#problems == 0 and repeatedPairs == 0)
	end)

	r.section("첫 바퀴", function()
		local seen, names = {}, {}
		for n = 2, #allIds do
			local id = BossRules.bossIdForStage(n * interval)
			seen[id] = (seen[id] or 0) + 1
			table.insert(names, ("%d=%s"):format(n * interval, tostring(id)))
		end
		local allOnce = seen[GUARDIAN] == nil
		for _, id in ipairs(allIds) do
			if id ~= GUARDIAN then
				allOnce = allOnce and seen[id] == 1
			end
		end
		r.check(("첫 보스 스테이지 %d = %s(기대 %s = 견습 보스) · 그다음 다섯 [%s]에 나머지 5종이 한 번씩=%s"):format(
			interval, tostring(BossRules.bossIdForStage(interval)), BossData.tutorialBossId, table.concat(names, " "), tostring(allOnce)),
			BossRules.bossIdForStage(interval) == BossData.tutorialBossId and BossData.tutorialBossId == GUARDIAN and allOnce)
	end)

	r.section("연속 등장·바퀴 경계", function()
		local perLap = #BossData.placement.laps[1]
		local minGap, consecutive, boundaryRepeats, checked = math.huge, 0, 0, 2000
		local lastAt = {}
		local previous
		for n = 1, checked do
			local id = BossRules.bossIdForStage(n * interval)
			if id == previous then
				consecutive += 1
				if (n - 1) % perLap == 0 then
					boundaryRepeats += 1
				end
			end
			if lastAt[id] then
				minGap = math.min(minGap, n - lastAt[id])
			end
			lastAt[id] = n
			previous = id
		end
		r.check(("보스 스테이지 %d개(스테이지 %d까지): 같은 보스 연속 %d건(바퀴 경계 %d건) · 같은 보스가 다시 나오기까지 최소 %d마리(기대 ≥ %d)"):format(
			checked, checked * interval, consecutive, boundaryRepeats, minGap, BossData.placement.minRepeatGap),
			consecutive == 0 and boundaryRepeats == 0 and minGap >= BossData.placement.minRepeatGap)
	end)

	r.section("스테이지만의 함수", function()
		-- 인자가 stage 하나뿐인가(플레이어·프로필을 받을 자리가 없다) · 같은 입력 = 같은 출력 · 보스 스테이지가 아니면 nil · 아주 큰 스테이지
		local arity, isVararg = debug.info(BossRules.bossIdForStage, "a")
		local stable = true
		for n = 1, 200 do
			local first = BossRules.bossIdForStage(n * interval)
			for _ = 1, 3 do
				stable = stable and BossRules.bossIdForStage(n * interval) == first
			end
		end
		local period = #BossData.placement.laps * #BossData.placement.laps[1] * interval
		local far = 1e9 * interval
		r.check(("bossIdForStage의 인자 %d개(가변 %s) · 같은 스테이지 200개 × 4회 같은 값=%s · 일반 스테이지 %d·0 → %s·%s · 주기 %d스테이지: f(20)=%s = f(20 + 주기)=%s · 스테이지 %.0f → %s"):format(
			arity, tostring(isVararg), tostring(stable), interval + 1, tostring(BossRules.bossIdForStage(interval + 1)), tostring(BossRules.bossIdForStage(0)),
			period, tostring(BossRules.bossIdForStage(20)), tostring(BossRules.bossIdForStage(20 + period)), far, tostring(BossRules.bossIdForStage(far))),
			arity == 1 and not isVararg and stable and BossRules.bossIdForStage(interval + 1) == nil and BossRules.bossIdForStage(0) == nil
				and BossRules.bossIdForStage(20) == BossRules.bossIdForStage(20 + period) and BossData.bosses[BossRules.bossIdForStage(far)] ~= nil)
	end)
end

local function runPure()
	print("===29-5 검증 시작(가: 배치표)===")
	local r = newRecorder("가")
	BossGimmick5Verify.checkPlacement(r)
	local pass, total = r.summary()
	print(("===29-5 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnAt(player, env, stage)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

local function activeClassState(player)
	local profile = PlayerProfile.getProfile(player)
	return profile and profile.classId and profile.classes[profile.classId]
end

local function runLive(player, env)
	print("===29-5 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	env.ensureBackup(player)

	-- [2][5] "유저 둘이 같은 스테이지에서 같은 보스" + "순환이 진행된 기존 세이브의 전환". 실제 Player의 실제 프로필에 서로 다른
	-- 두 유저의 세이브 상태(23-5 순환 필드)를 차례로 넣고 실제 스폰 경로(BossEncounter.spawnFor)를 탄다 - 23-5 코드였다면
	-- A는 순환의 첫 자리(기본형), B는 pending의 storm_lord가 나왔을 상태다.
	r.section("유저 상태와 무관한 보스", function()
		local classState = activeClassState(player)
		local stage = 4 * BossData.stageInterval
		local expected = BossRules.bossIdForStage(stage)

		classState.bossRotation = { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false } -- 유저 A: 새 세이브
		local _, dataA = spawnAt(player, env, stage)

		local saved = { -- 유저 B: 순환이 한창 진행된 옛 세이브(다른 보스가 확정돼 있고 강제 지정까지 남아 있다)
			order = { "storm_lord", "abyssal_lord", "frost_giant", "scorpion_queen", "section_guardian", "crystal_queen" },
			index = 4, pending = { stage = stage, bossId = "storm_lord" }, history = { "storm_lord", "abyssal_lord", "frost_giant" },
			debugForceNextId = "frost_giant",
		}
		classState.bossRotation = saved
		local _, dataB = spawnAt(player, env, stage)
		local untouched = saved.index == 4 and saved.pending.bossId == "storm_lord" and #saved.history == 3 and saved.debugForceNextId == "frost_giant"

		classState.bossRotation = nil -- 필드가 아예 없는 경우에도 스폰 경로가 읽지 않는가
		local _, dataC = spawnAt(player, env, stage)

		r.check(("스테이지 %d: 새 세이브 → %s · 순환 4/6 진행 + pending storm_lord + 강제 frost_giant → %s · bossRotation 없음 → %s (기대 전부 %s) · 옛 필드를 쓰지도 않았다=%s"):format(
			stage, tostring(dataA and dataA.id), tostring(dataB and dataB.id), tostring(dataC and dataC.id), expected, tostring(untouched)),
			dataA ~= nil and dataA.id == expected and dataB ~= nil and dataB.id == expected and dataC ~= nil and dataC.id == expected and untouched)
		classState.bossRotation = saved
	end)

	-- 파티 경로도 같은 함수를 보는가(리더가 누구든 같은 보스) + 첫 보스 = 기본형 + Studio 전용 강제 지정은 한 번만
	r.section("파티·첫 보스·강제 지정", function()
		local interval = BossData.stageInterval
		local _, first = spawnAt(player, env, interval)

		BossEncounter.despawnFor(player)
		local stage = 6 * interval
		PartyState.addDummies(player, 1)
		local party = PartyState.getParty(player)
		env.applyStage(player, stage)
		BossEncounter.spawnForParty(party, player, stage)
		local partyModel = BossEncounter.getActive(player)
		local partyData = partyModel and MonsterState.getData(partyModel)
		BossEncounter.despawnFor(player)
		PartyState.leave(player, "leave")

		BossEncounter.setDebugForcedBoss(player, "scorpion_queen")
		local _, forced = spawnAt(player, env, stage)
		local _, after = spawnAt(player, env, stage)
		r.check(("첫 보스 스테이지 %d = %s · 파티(인원 %s) 스테이지 %d = %s(기대 %s) · 강제 지정 scorpion_queen → %s → 다음 스폰은 다시 %s"):format(
			interval, tostring(first and first.id), tostring(partyData and partyData.partySize), stage, tostring(partyData and partyData.id),
			BossRules.bossIdForStage(stage), tostring(forced and forced.id), tostring(after and after.id)),
			first ~= nil and first.id == GUARDIAN and partyData ~= nil and partyData.id == BossRules.bossIdForStage(stage) and partyData.partySize == 2
				and forced ~= nil and forced.id == "scorpion_queen" and after ~= nil and after.id == BossRules.bossIdForStage(stage))
	end)

	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d개(기대 0)"):format(orphans), orphans == 0)
	env.restore(player)
	local pass, total = r.summary()
	print(("===29-5 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

BossGimmick5Verify.runPure = runPure
BossGimmick5Verify.runLive = runLive

return BossGimmick5Verify
