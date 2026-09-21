-- S11 자동 검증(PRD 20.73 [4-1] · [4-2] · 30-0 S11) - 보스 첫 클리어 보상 미리보기 + 도감 도장.
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이): 방지권 · 강화석 표시의 데이터 식(스테이지 45 / 50 / 75 / 100) · 입력 검사 · 요청 간격 · 배치표 · 저장 이관(v28 → v29) · 저장 검사.
--   (나) 실제 Player - 보스 검증 체인의 끝에서: 새 프로필 조회 · 스테이지 50 실제 처치 → 다시 조회 · 직업을 바꿔 조회(직업 / 계정 다른 축) · 잘못된 입력 · 스테이지 100 · 되돌림.
-- 문자열 생성기(클라 StageRewardBand.describe)의 검사는 클라 콘솔의 [S11][UI]가 맡고, 여기 (가)는 그 문자열이 읽는 **데이터 식**만 본다(지시).
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(보스 · 프로필 값 · 도감)은 (나)가 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRewardPreviewData = require(ReplicatedStorage.Shared.data.BossRewardPreviewData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local BossRewardPreview = require(script.Parent.BossRewardPreview)
local EnhanceVerify = require(script.Parent.EnhanceVerify)
local MonsterState = require(script.Parent.MonsterState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)

local BossRewardPreviewVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S11][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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
	for key, inner in pairs(value) do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function countKeys(set)
	local count = 0
	for _ in pairs(set) do
		count += 1
	end
	return count
end

-- 데이터 식(클라 띠가 읽는 것과 같은 출처): 강화석 항목 = minStage 이하 스테이지에서 dropChancePerKill × 보스 hpMultiplier.
local function stoneEntries(stage, bossId)
	local entries = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		local material = EnhanceMaterialData.materials[materialId]
		if stage >= material.minStage then
			table.insert(entries, ("%s ≈%g"):format(material.displayName, material.dropChancePerKill * BossData.bosses[bossId].hpMultiplier))
		end
	end
	return entries
end

-- ─────────────────────────── (가) 순수 함수 ───────────────────────────

function BossRewardPreviewVerify.runPure()
	print("===S11 검증 시작(가: 방지권 · 강화석 데이터 식 · 입력 검사 · 저장)===")
	local r = newRecorder("가")

	r.section("[1] 방지권 표시(Enhance.getBossGrant)", function()
		local rows, ok = {}, true
		local expected = { [45] = { 0, 0 }, [50] = { 1, 0 }, [75] = { 1, 0 }, [100] = { 1, 1 }, [55] = { 0, 0 }, [125] = { 1, 1 } }
		for _, stage in ipairs({ 45, 50, 75, 100, 55, 125 }) do
			local drop, reset = Enhance.getBossGrant(stage)
			table.insert(rows, ("%d → 하락 %d · 초기화 %d"):format(stage, drop, reset))
			ok = ok and drop == expected[stage][1] and reset == expected[stage][2]
		end
		r.check(("방지권 스테이지 45 / 50 / 75 / 100 = 없음 / 하락 / 하락 / 둘 다(그 밖 55 없음 · 125 둘 다): %s"):format(table.concat(rows, " · ")), ok)
	end)

	r.section("[2] 강화석 항목(데이터 식)", function()
		local bossId = BossRules.bossIdForStage(50)
		local rows, ok = {}, true
		local expectedCount = { [45] = 0, [50] = 1, [75] = 2, [100] = 2 }
		for _, stage in ipairs({ 45, 50, 75, 100 }) do
			local entries = stoneEntries(stage, bossId)
			table.insert(rows, ("%d → [%s]"):format(stage, table.concat(entries, " · ")))
			ok = ok and #entries == expectedCount[stage]
		end
		local at50, at75 = stoneEntries(50, bossId), stoneEntries(75, bossId)
		ok = ok and at50[1] == "강화석 ≈5" and at75[1] == "강화석 ≈5" and at75[2] == "상급 강화석 ≈5"
		r.check(("스테이지 45 / 50 / 75 / 100 = 없음 / ≈5 / ≈5 + 상급 ≈5 / 같음(dropChancePerKill × 보스 hpMultiplier %d): %s"):format(BossData.bosses[bossId].hpMultiplier, table.concat(rows, " · ")), ok)
	end)

	r.section("[3] 입력 검사", function()
		local function reason(stages)
			local ok, why = BossRewardPreview.validate(stages)
			return ok and "통과" or why
		end
		local cases = {
			{ "[50, 55, 100]", { 50, 55, 100 }, "통과" },
			{ "[5, 10, 15, 20, 25](5개 = 최대)", { 5, 10, 15, 20, 25 }, "통과" },
			{ "6개", { 5, 10, 15, 20, 25, 30 }, "count" },
			{ "빈 배열", {}, "count" },
			{ "nil", nil, "not_array" },
			{ "숫자 42", 42, "not_array" },
			{ "문자열 스테이지 ['50']", { "50" }, "not_number" },
			{ "NaN", { 0 / 0 }, "not_number" },
			{ "무한대", { math.huge }, "not_number" },
			{ "소수 50.5", { 50.5 }, "not_number" },
			{ "보스 아닌 스테이지 [52]", { 52 }, "not_boss_stage" },
			{ "0", { 0 }, "not_boss_stage" },
			{ "음수 [-5]", { -5 }, "not_boss_stage" },
			{ "표 안의 표 [[50]]", { { 50 } }, "not_number" },
			{ "구멍 난 배열", { [1] = 50, [3] = 55 }, "not_array" },
			{ "키가 문자열인 표", { a = 50 }, "not_array" },
		}
		local mismatches = {}
		for _, case in ipairs(cases) do
			local got = reason(case[2])
			if got ~= case[3] then
				table.insert(mismatches, ("%s: %s(기대 %s)"):format(case[1], got, case[3]))
			end
		end
		r.check(("입력 검사 %d건(6개 · 보스 아닌 스테이지 · 숫자 아님 · 구멍 · 표 아님 포함): 어긋난 것 %d개 [%s]"):format(#cases, #mismatches, table.concat(mismatches, " | ")), #mismatches == 0)
	end)

	r.section("[4] 요청 간격", function()
		local fake = { Name = "S11RateStandIn" }
		local interval = BossRewardPreviewData.minIntervalSeconds
		local first = BossRewardPreview.handle(fake, {}, 100) -- 빈 배열은 count로 거절되지만 요청 시각은 찍힌다(검사 전에 간격부터 본다)
		local tooSoon = BossRewardPreview.handle(fake, {}, 100 + interval * 0.5)
		local afterInterval = BossRewardPreview.handle(fake, {}, 100 + interval * 0.5 + interval)
		BossRewardPreview.forget(fake)
		local afterForget = BossRewardPreview.handle(fake, {}, 100)
		r.check(("요청 간격 %s초: 첫 요청 %s(기대 count) · 간격 절반 뒤 %s(기대 rate) · 간격 넘긴 뒤 %s(기대 count) · 기록 지운 뒤 %s(기대 count)"):format(
			tostring(interval), tostring(first.reason), tostring(tooSoon.reason), tostring(afterInterval.reason), tostring(afterForget.reason)),
			first.ok == false and first.reason == "count" and tooSoon.reason == "rate" and afterInterval.reason == "count" and afterForget.reason == "count")
	end)

	r.section("[5] 보스 배치 · 도감 칸", function()
		local mismatches, distinct = {}, {}
		for stage = BossData.stageInterval, BossData.stageInterval * 40, BossData.stageInterval do
			local bossId = BossRules.bossIdForStage(stage)
			if bossId == nil or BossData.bosses[bossId] == nil then
				table.insert(mismatches, tostring(stage))
			else
				distinct[bossId] = true
			end
		end
		local codexIds = BossData.pools[1].bossIds
		r.check(("보스 스테이지 40개의 bossId가 전부 BossData에 있다(어긋남 %d개) · 종류 %d(기대 %d) · 도감 칸 %d개(기대 6 - BossData 선언 순) · 첫 보스 %s(기대 %s)"):format(
			#mismatches, countKeys(distinct), #codexIds, #codexIds, tostring(BossRules.bossIdForStage(BossData.stageInterval)), BossData.tutorialBossId),
			#mismatches == 0 and countKeys(distinct) == #codexIds and #codexIds == 6 and BossRules.bossIdForStage(BossData.stageInterval) == BossData.tutorialBossId and BossRules.bossIdForStage(52) == nil)
	end)

	r.section("[6] 저장 이관(v28 → v29) · 검사", function()
		local profile = SaveSystem.defaultProfile()
		profile.version = 28
		profile.purchases.bossCodex = nil -- v28까지는 이 필드가 없었다
		local migrated = SaveSystem.migrate(profile)
		local emptyCodex = migrated.purchases.bossCodex ~= nil and next(migrated.purchases.bossCodex) == nil
		local validAfter = SaveSystem.isValidProfile(migrated)

		local kept = SaveSystem.defaultProfile()
		kept.version = 28
		kept.purchases.bossCodex = { frost_giant = true }
		local keptMigrated = SaveSystem.migrate(kept)
		local keeps = keptMigrated.purchases.bossCodex.frost_giant == true

		local function validWith(mutate)
			local copy = deepCopy(migrated)
			mutate(copy)
			return SaveSystem.isValidProfile(copy)
		end
		local rejects = not validWith(function(copy) copy.purchases.bossCodex = nil end)
			and not validWith(function(copy) copy.purchases.bossCodex = 3 end)
			and not validWith(function(copy) copy.purchases.bossCodex.not_a_boss = true end)
			and not validWith(function(copy) copy.purchases.bossCodex.frost_giant = false end)
			and not validWith(function(copy) copy.purchases.bossCodex.frost_giant = 1 end)
			and not validWith(function(copy) copy.purchases.bossCodex[1] = true end)
		local edgeOk = validWith(function(copy)
			for _, bossId in ipairs(BossData.pools[1].bossIds) do
				copy.purchases.bossCodex[bossId] = true
			end
		end)
		r.check(("v28 → v%d(기대 %d): 빈 집합=%s · isValidProfile=%s(기대 true) · 이미 있는 도장 유지=%s · 6종 전부 통과=%s · 집합 없음 · 표 아님 · 없는 보스 id · false · 숫자 값 · 숫자 키 거부=%s · 기본 프로필 v%d"):format(
			migrated.version, SaveConfig.saveVersion, tostring(emptyCodex), tostring(validAfter), tostring(keeps), tostring(edgeOk), tostring(rejects), SaveSystem.defaultProfile().version),
			migrated.version == SaveConfig.saveVersion and SaveConfig.saveVersion >= 29 and emptyCodex and validAfter and keeps and edgeOk and rejects and SaveSystem.defaultProfile().version == SaveConfig.saveVersion)
	end)

	local pass, total = r.summary()
	print(("===S11 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 Player ───────────────────────────

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

function BossRewardPreviewVerify.runLive(player, env)
	print("===S11 검증 시작(나: 실제 Player · 실제 처치 경로 · 조회)===")
	local r = newRecorder("나")
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S11 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player) -- classes · gold · 가방 · 재료 · 방지권 · 받은 스테이지 · 도감은 env.restore가 되돌린다
	local savedCFrame = root.CFrame
	local bagBefore = #profile.inventory
	local codexBefore = deepCopy(profile.purchases.bossCodex)
	local classA, classB = ClassData.order[1], ClassData.order[2]
	PlayerProfile.setClassId(player, classA)

	-- 기준 상태: 새 프로필처럼(방지권 0장 · 받은 스테이지 · 도감 · 두 직업의 첫 클리어 기록 비움 - 개발 계정에 남은 값이 결과를 흔들지 않게).
	PlayerProfile.trySpendProtectionTicket(player, "drop", PlayerProfile.getProtectionTicket(player, "drop"))
	PlayerProfile.trySpendProtectionTicket(player, "reset", PlayerProfile.getProtectionTicket(player, "reset"))
	table.clear(profile.purchases.protectionClaimedStages)
	table.clear(profile.purchases.bossCodex)
	table.clear(profile.inventory) -- 보스 장비가 가방으로 직행하므로 자리를 비운다(env.restore가 되돌린다)
	for _, classId in ipairs({ classA, classB }) do
		profile.classes[classId].stageProgress.bossFirstClearStages = {}
	end

	local clock = 1e6 -- 요청 간격 하한에 안 걸리게 요청마다 시각을 늘려 넣는다(끝에서 기록을 지운다)
	local function query(stages)
		clock += 10
		return BossRewardPreview.handle(player, stages, clock)
	end
	local function entryOf(payload, stage)
		for _, entry in ipairs(payload.entries or {}) do
			if entry.stage == stage then
				return entry
			end
		end
		return nil
	end

	r.section("[1] 새 프로필로 [50, 55, 100] 조회", function()
		local payload = query({ 50, 55, 100 })
		local e50, e55, e100 = entryOf(payload, 50), entryOf(payload, 55), entryOf(payload, 100)
		local ok = payload.ok and e50 ~= nil and e55 ~= nil and e100 ~= nil
		if ok then
			ok = e50.gearClaimed == false and e50.dropTicket == "available" and e50.resetTicket == "none"
				and e55.gearClaimed == false and e55.dropTicket == "none" and e55.resetTicket == "none"
				and e100.gearClaimed == false and e100.dropTicket == "available" and e100.resetTicket == "available"
				and e50.bossId == BossRules.bossIdForStage(50) and e55.bossId == BossRules.bossIdForStage(55) and e100.bossId == BossRules.bossIdForStage(100)
				and countKeys(payload.codex) == 0
		end
		r.check(("새 프로필 [50, 55, 100]: 50 = 장비 %s · 하락 %s · 초기화 %s / 55 = %s · %s · %s / 100 = %s · %s · %s · bossId %s · %s · %s(기대 bossIdForStage와 같음) · 도감 %d칸(기대 0)"):format(
			tostring(e50 and e50.gearClaimed), tostring(e50 and e50.dropTicket), tostring(e50 and e50.resetTicket),
			tostring(e55 and e55.gearClaimed), tostring(e55 and e55.dropTicket), tostring(e55 and e55.resetTicket),
			tostring(e100 and e100.gearClaimed), tostring(e100 and e100.dropTicket), tostring(e100 and e100.resetTicket),
			tostring(e50 and e50.bossId), tostring(e55 and e55.bossId), tostring(e100 and e100.bossId), payload.codex and countKeys(payload.codex) or -1), ok)
	end)

	local bossId50 = BossRules.bossIdForStage(50)
	r.section("[2] 스테이지 50 보스를 실제 처치 경로로 잡은 뒤 다시 조회", function()
		local result = EnhanceVerify.killBossOnce(player, env, 50, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		local payload = query({ 50 })
		local e50 = entryOf(payload, 50)
		local ok = result.ok and payload.ok and e50 ~= nil and e50.gearClaimed == true and e50.dropTicket == "claimed" and e50.resetTicket == "none" and payload.codex[bossId50] == true and countKeys(payload.codex) == 1
			and result.bossId == bossId50
		r.check(("스테이지 50 보스(%s) 처치 뒤: 장비 %s(기대 true) · 하락 %s(기대 claimed) · 도감[%s] %s(기대 true) · 도감 %d칸(기대 1) · 처치한 보스 = bossIdForStage(50)이다 %s · resolveHit 에러=%s"):format(
			tostring(result.bossId), tostring(e50 and e50.gearClaimed), tostring(e50 and e50.dropTicket), bossId50, tostring(payload.codex and payload.codex[bossId50]),
			payload.codex and countKeys(payload.codex) or -1, tostring(result.bossId == bossId50), result.ok and "없음" or tostring(result.err)), ok)
	end)

	r.section("[3] 직업을 바꿔 같은 스테이지 조회 - 직업 · 계정은 다른 축", function()
		PlayerProfile.setClassId(player, classB)
		local payload = query({ 50 })
		local e50 = entryOf(payload, 50)
		local ok = payload.ok and e50 ~= nil and e50.gearClaimed == false and e50.dropTicket == "claimed" and payload.codex[bossId50] == true
		r.check(("직업 %s(직업 %s가 이미 받은 스테이지 50): 장비 %s(기대 false - 직업별) · 하락 방지권 %s(기대 claimed - 계정 공유) · 도감 %s(기대 true - 계정 공유) ★진짜 합격 기준"):format(
			classB, classA, tostring(e50 and e50.gearClaimed), tostring(e50 and e50.dropTicket), tostring(payload.codex and payload.codex[bossId50])), ok)
		PlayerProfile.setClassId(player, classA)
		local back = entryOf(query({ 50 }), 50)
		r.check(("다시 직업 %s: 장비 %s(기대 true)"):format(classA, tostring(back and back.gearClaimed)), back ~= nil and back.gearClaimed == true)
	end)

	r.section("[4] 잘못된 입력 · 너무 잦은 요청 → 거절 · 에러 0", function()
		local cases = {
			{ "6개", { 5, 10, 15, 20, 25, 30 } },
			{ "보스 아닌 스테이지", { 52 } },
			{ "숫자 아님", { "50" } },
			{ "nil", nil },
			{ "구멍", { [1] = 50, [3] = 55 } },
		}
		local errors, notRejected = {}, {}
		for _, case in ipairs(cases) do
			clock += 10
			local called, payload = pcall(BossRewardPreview.handle, player, case[2], clock)
			if not called then
				table.insert(errors, ("%s: %s"):format(case[1], tostring(payload)))
			elseif payload.ok ~= false then
				table.insert(notRejected, case[1])
			end
		end
		local first = query({ 50 })
		local tooSoon = BossRewardPreview.handle(player, { 50 }, clock + BossRewardPreviewData.minIntervalSeconds * 0.5)
		r.check(("잘못된 입력 %d건: 에러 %d개 · 거절 안 된 것 %d개(기대 0 · 0) [%s] · 정상 요청 %s → 간격 절반 뒤 %s(기대 true → rate)"):format(
			#cases, #errors, #notRejected, table.concat(errors, " | "), tostring(first.ok), tostring(tooSoon.reason)),
			#errors == 0 and #notRejected == 0 and first.ok == true and tooSoon.reason == "rate")
	end)

	r.section("[5] 스테이지 100 보스 - 방지권 둘 다 · 도감", function()
		local result = EnhanceVerify.killBossOnce(player, env, 100, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		local bossId100 = BossRules.bossIdForStage(100)
		local payload = query({ 50, 100 })
		local e100 = entryOf(payload, 100)
		local expectedCodex = bossId100 == bossId50 and 1 or 2
		local ok = result.ok and e100 ~= nil and e100.gearClaimed == true and e100.dropTicket == "claimed" and e100.resetTicket == "claimed" and payload.codex[bossId100] == true
			and countKeys(payload.codex) == expectedCodex
		r.check(("스테이지 100 보스(%s) 처치 뒤: 장비 %s · 하락 %s · 초기화 %s(기대 true · claimed · claimed) · 도감 %d칸(기대 %d = 50번과 %s)"):format(
			bossId100, tostring(e100 and e100.gearClaimed), tostring(e100 and e100.dropTicket), tostring(e100 and e100.resetTicket),
			payload.codex and countKeys(payload.codex) or -1, expectedCodex, bossId100 == bossId50 and "같은 보스" or "다른 보스"), ok)
	end)

	r.section("[6] 저장 형식", function()
		local badKeys = 0
		for bossId, stamped in pairs(profile.purchases.bossCodex) do
			if type(bossId) ~= "string" or BossData.bosses[bossId] == nil or stamped ~= true then
				badKeys += 1
			end
		end
		r.check(("실제 프로필의 도감: 키 %d개 모두 BossData 보스 id 문자열 · 값 true(어긋남 %d개, 기대 0) · isValidProfile %s(기대 true)"):format(countKeys(profile.purchases.bossCodex), badKeys, tostring(SaveSystem.isValidProfile(profile))),
			badKeys == 0 and SaveSystem.isValidProfile(profile))
	end)

	-- [7] 되돌리기: classes · gold · 가방 · 재료 · 방지권 · 받은 스테이지 · 도감은 env.restore가, 위치 · 요청 기록은 직접. 검증이 만든 것은 전부 없어야 한다.
	local codexDuring = countKeys(profile.purchases.bossCodex)
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	env.restore(player)
	BossRewardPreview.forget(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.Anchored = false
		currentRoot.CFrame = savedCFrame
	end
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	local restoredClass = PlayerProfile.getClassId(player)
	local codexSame = countKeys(profile.purchases.bossCodex) == countKeys(codexBefore)
	for bossId in pairs(codexBefore) do
		codexSame = codexSame and profile.purchases.bossCodex[bossId] == true
	end
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d개(기대 0) · 가방 %d → %d칸 · 도감 %d → %d칸(검증 전 %d칸과 같은 내용=%s) · 직업 %s"):format(
		orphans, bagBefore, #profile.inventory, codexDuring, countKeys(profile.purchases.bossCodex), countKeys(codexBefore), tostring(codexSame), tostring(restoredClass)),
		orphans == 0 and #profile.inventory == bagBefore and codexSame)

	local pass, total = r.summary()
	print(("===S11 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return BossRewardPreviewVerify
