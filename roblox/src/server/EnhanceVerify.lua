-- S03 자동 검증(PRD 20.84) - 강화 확률표 · 골드표 · 천장("불씨").
--   (가) 순수 함수 + 합성 프로필 - 서버 시작 때(플레이어 없이).
--   (나) 실제 Player · 실제 EnhanceService.handleRequest(= EnhanceRequest 핸들러 본문) 경로 - 보스 검증 체인의 끝에서 돈다.
-- env = { ensureBackup, restore } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(골드 · 무기 강화 단계 · 게이지 · 캐릭터 위치)은 (나)가 끝날 때 전부 되돌린다.
-- S04 자동 검증(PRD 20.85) - 강화 재료 2종 + 재료 × 경험치 배수: 아래 "S04" 구역(runPureS04 · runLiveS04). 같은 규칙(가 = 서버 시작 때 · 나 = 체인 끝)이다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local Loot = require(ReplicatedStorage.Shared.Loot)
local BossEncounter = require(script.Parent.BossEncounter)
local CombatResolution = require(script.Parent.CombatResolution)
local EnhanceService = require(script.Parent.EnhanceService)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)
local TutorialState = require(script.Parent.TutorialState)
-- S05(방지권) 검증용.
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local EnhancePolicy = require(script.Parent.EnhancePolicy)
local ImmediateSave = require(script.Parent.ImmediateSave)
local ProtectionTickets = require(script.Parent.ProtectionTickets)

local EnhanceVerify = {}

local RESULT_KEYS = { "success", "maintain", "down1", "down2", "reset" }
local FLAGS_OFF = { false, false }

local function newRecorder(tag, session)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[%s][%s] %s %s"):format(session or "S03", tag, label, ok and "O" or "X"))
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

-- 천장 때문에 "확정 성공"이 되는 시도 번호 = ceil(2 / p) + 1 (PRD 20.72 [1-5](가) n).
local function expectedCeilingAttempt(successRate)
	return math.ceil(2 / successRate) + 1
end

-- ─────────────────────────── (가) 순수 함수 ───────────────────────────

local function checkRowSums(r)
	r.section("[1] 25행 합", function()
		local rows, worst = #EnhanceConfig.probability, 0
		for _, row in ipairs(EnhanceConfig.probability) do
			local sum = 0
			for _, key in ipairs(RESULT_KEYS) do
				sum += row[key]
			end
			worst = math.max(worst, math.abs(sum - 1))
		end
		r.check(("확률표 %d행(기대 %d) 합의 1과의 최대 오차 %.2e(기대 ≤ 1e-9) - 모듈 로드 시 검사도 같은 기준"):format(rows, EnhanceConfig.maxLevel, worst),
			rows == EnhanceConfig.maxLevel and worst <= 1e-9)
	end)
end

-- 분포 · 하락 없음 · 바닥은 한 번에 훑는다. 난수 대신 [0, 1)을 SAMPLES 등분한 롤을 주입한다(tryEnhance의 4번째 인자): 지시서의 ±0.3%p는
-- 20만 회 난수 표본에서 2.7σ(성공률 0.5 근처)라 25단계 × 결과 ~100건이면 우연히 X가 날 확률이 20%쯤이다. 등분 롤은 "롤 → 결과" 대응이 표와
-- 같은지만 결정적으로 확인한다(난수원 자체의 검증은 [7]의 실제 math.random 몬테카를로가 맡는다).
local SAMPLES = 200000
local distribution -- [level] = { counts = { result = n }, minLevelAfterNonReset, ... } ([2] · [3] · [5]가 공유)

local function sampleDistribution(r)
	distribution = {}
	for level = 0, EnhanceConfig.maxLevel - 1 do
		local counts = { success = 0, maintain = 0, down1 = 0, down2 = 0, reset = 0 }
		local lowestNonReset = math.huge
		for index = 1, SAMPLES do
			local outcome = Enhance.tryEnhance(level, 0, FLAGS_OFF, (index - 0.5) / SAMPLES)
			counts[outcome.result] += 1
			if outcome.result ~= "reset" then
				lowestNonReset = math.min(lowestNonReset, outcome.level)
			end
		end
		distribution[level] = { counts = counts, lowestNonReset = lowestNonReset }
		task.wait() -- 25단계 × 20만 회 - 한 번에 몰아 돌리다 스크립트 실행 시간 한도에 걸리지 않게 단계마다 양보한다
	end
end

local function checkDistribution(r)
	r.section("[2] 결과 분포", function()
		local worst, worstAt = 0, ""
		for level = 0, EnhanceConfig.maxLevel - 1 do
			local prob = EnhanceConfig.probability[level + 1]
			for _, key in ipairs(RESULT_KEYS) do
				local share = distribution[level].counts[key] / SAMPLES
				local deviation = math.abs(share - prob[key])
				if deviation > worst then
					worst, worstAt = deviation, ("+%d %s"):format(level, key)
				end
			end
		end
		r.check(("단계 25개 × tryEnhance %d회(등분 롤 주입): 표와의 최대 차 %.4f%%p(%s)(기대 ≤ 0.3%%p)"):format(SAMPLES, worst * 100, worstAt == "" and "-" or worstAt),
			worst <= 0.003)
	end)
end

local function checkNoDropBelow19(r)
	r.section("[3] 0 ~ 18강 하락 없음", function()
		local bad = 0
		for level = 0, 18 do
			local counts = distribution[level].counts
			bad += counts.down1 + counts.down2 + counts.reset
		end
		-- 실제 난수 경로도 한 번 더 - 등분 롤이 아니라 math.random으로 tryEnhance를 부른다.
		local randomBad, randomTotal = 0, 0
		for level = 0, 18 do
			for _ = 1, 20000 do
				local outcome = Enhance.tryEnhance(level, 0, FLAGS_OFF)
				randomTotal += 1
				if outcome.result == "down1" or outcome.result == "down2" or outcome.result == "reset" or outcome.level < level then
					randomBad += 1
				end
			end
		end
		r.check(("0 ~ 18강 × 등분 롤 %d회 + 실제 난수 %d회: down1 · down2 · reset(또는 단계 하락) %d건 · %d건(기대 0 · 0) ★진짜 합격 기준"):format(
			19 * SAMPLES, randomTotal, bad, randomBad), bad == 0 and randomBad == 0)
	end)
end

local function checkCeiling(r)
	r.section("[4] 천장", function()
		-- 각 단계에서 "계속 실패"를 강제한다: 롤을 1에 가깝게 주입하면 성공이 아닌 결과(확률이 있는 마지막 결과)만 나온다. 시도한 단계는 고정한다
		-- (하락 · 초기화로 반환 단계가 바뀌어도 게이지는 "시도한 단계의 성공률"로 찬다).
		local rows, allOk = {}, true
		local byRate = {}
		for level = 0, EnhanceConfig.maxLevel - 1 do
			local gauge, attempts = 0, 0
			repeat
				attempts += 1
				local outcome = Enhance.tryEnhance(level, gauge, FLAGS_OFF, 0.999999999)
				gauge = outcome.gauge
				local done = outcome.result == "success"
				if attempts > 100 then
					break
				end
			until done
			local rate = EnhanceConfig.probability[level + 1].success
			local expected = expectedCeilingAttempt(rate)
			allOk = allOk and attempts == expected
			byRate[rate] = { attempts = attempts, expected = expected, ok = attempts == expected }
		end
		for _, rate in ipairs({ 0.92, 0.78, 0.62, 0.48, 0.38, 0.28, 0.18, 0.12 }) do
			local entry = byRate[rate]
			table.insert(rows, ("%.2f→%d번째(기대 %d)"):format(rate, entry and entry.attempts or -1, entry and entry.expected or -1))
		end
		-- 지시서가 적은 리터럴 표와도 대조한다.
		local literal = { [0.92] = 4, [0.78] = 4, [0.62] = 5, [0.48] = 6, [0.38] = 7, [0.28] = 9, [0.18] = 13, [0.12] = 18 }
		for rate, expected in pairs(literal) do
			allOk = allOk and byRate[rate] ~= nil and byRate[rate].attempts == expected
		end
		r.check(("25단계 전부 '계속 실패' 강제 → 확정 성공이 몇 번째 시도인가: %s (= ceil(2/p)+1번째)"):format(table.concat(rows, " · ")), allOk)
	end)
end

local function checkFloors(r)
	r.section("[5] 바닥", function()
		local floorLevel = EnhanceConfig.downFloorLevel
		local expected = {
			{ 19, "down1", 18 }, { 20, "down2", 18 }, { 21, "down2", 19 }, { 22, "down1", 21 }, { 22, "down2", 20 },
			{ 23, "down1", 22 }, { 23, "down2", 21 }, { 24, "down2", 22 }, { 22, "reset", 12 }, { 23, "reset", 12 }, { 24, "reset", 12 },
		}
		local tableOk = true
		for _, row in ipairs(expected) do
			tableOk = tableOk and Enhance.getResultLevel(row[1], row[2]) == row[3]
		end
		-- 어떤 하락이든 바닥 아래로 가지 않는다(19 ~ 24 × down1 · down2), 초기화는 항상 resetToLevel.
		for level = 19, EnhanceConfig.maxLevel - 1 do
			tableOk = tableOk and Enhance.getResultLevel(level, "down1") >= floorLevel and Enhance.getResultLevel(level, "down2") >= floorLevel
		end
		-- tryEnhance가 실제로 낸 결과 단계도 본다(등분 롤): reset이 아닌 결과는 전부 바닥 이상.
		local lowest, resetOk = math.huge, true
		for level = 19, EnhanceConfig.maxLevel - 1 do
			lowest = math.min(lowest, distribution[level].lowestNonReset)
			if EnhanceConfig.probability[level + 1].reset > 0 then
				resetOk = resetOk and Enhance.tryEnhance(level, 0, FLAGS_OFF, 0.999999999).level == EnhanceConfig.resetToLevel
			end
		end
		r.check(("19·20·21·22·23·24강 결과 단계: 19→18 · 20→18 · 21 down2→19 · 22→21/20 · reset→%d(표 대조 %s) · tryEnhance가 낸 reset 아닌 결과의 최저 단계 %d(기대 ≥ %d) · reset 롤이 %d로 감(%s)"):format(
			EnhanceConfig.resetToLevel, tostring(tableOk), lowest, floorLevel, EnhanceConfig.resetToLevel, tostring(resetOk)),
			tableOk and lowest >= floorLevel and resetOk and EnhanceConfig.resetToLevel == 12)
	end)
end

local function checkGaugeRules(r)
	r.section("[6] 게이지 규칙", function()
		local gainAt19 = Enhance.getGaugeGain(19)
		local gainAt22 = Enhance.getGaugeGain(22)
		local gainAt0 = Enhance.getGaugeGain(0)
		-- 하락(19강 down1: 롤 0.9 → 성공 .28 + 유지 .58 = .86 이후 down1): 단계는 18로 내려가도 게이지는 유지 + 시도한 단계(19)의 gain만큼 오른다.
		local down = Enhance.tryEnhance(19, 300, FLAGS_OFF, 0.9)
		-- 초기화(22강, 롤 0.999): 12강으로 가도 게이지는 유지 + 22강의 gain.
		local reset = Enhance.tryEnhance(22, 300, FLAGS_OFF, 0.999)
		-- 유지(0강): 게이지는 오르고 max에서 자른다.
		local maintain = Enhance.tryEnhance(0, 900, FLAGS_OFF, 0.95)
		-- 성공: 게이지 0(자연 성공도, 천장 성공도).
		local natural = Enhance.tryEnhance(5, 700, FLAGS_OFF, 0.0)
		local ceiling = Enhance.tryEnhance(5, EnhanceConfig.gauge.max, FLAGS_OFF, 0.999999999)
		local ok = down.result == "down1" and down.level == 18 and down.gauge == 300 + gainAt19
			and reset.result == "reset" and reset.level == 12 and reset.gauge == 300 + gainAt22
			and maintain.result == "maintain" and maintain.gauge == math.min(EnhanceConfig.gauge.max, 900 + gainAt0)
			and natural.result == "success" and natural.gauge == 0 and not natural.gaugeWasFull
			and ceiling.result == "success" and ceiling.gauge == 0 and ceiling.gaugeWasFull
		r.check(("성공에만 0(자연 성공 700→%d · 천장 성공 %d→%d) · 하락 300→%d(19강 gain %d, 단계 %d) · 초기화 300→%d(22강 gain %d, 단계 %d) · 유지 900→%d(max %d에서 자름)"):format(
			natural.gauge, EnhanceConfig.gauge.max, ceiling.gauge, down.gauge, gainAt19, down.level, reset.gauge, gainAt22, reset.level, maintain.gauge, EnhanceConfig.gauge.max), ok)
	end)
end

-- 0 → 19강의 기대 골드 · 시도 수. 해석식: E_att(L) = Σ_{k=0..f} (1−p)^k (f = 천장에 닿는 실패 횟수 = ceil(max / gain)), 기대 골드 = Σ goldCost(L) × E_att(L).
-- 0 ~ 18강은 하락이 없어 단계마다 게이지 0에서 새로 시작한다(성공하면 게이지 0). 몬테카를로는 실제 math.random 경로로 같은 값이 나오는지 본다.
local function analyticExpectation()
	local gold, attempts = 0, 0
	for level = 0, 18 do
		local p = EnhanceConfig.probability[level + 1].success
		local failsToFull = math.ceil(EnhanceConfig.gauge.max / Enhance.getGaugeGain(level))
		local expectedAttempts = 0
		for k = 0, failsToFull do
			expectedAttempts += (1 - p) ^ k
		end
		gold += EnhanceConfig.goldCost[level + 1] * expectedAttempts
		attempts += expectedAttempts
	end
	return gold, attempts
end

local function checkExpectedGold(r)
	local analyticGold, analyticAttempts = analyticExpectation()
	local monteGold, monteAttempts
	r.section("[7][8] 0 → 19강 기대 골드 · 시도 수", function()
		local runs, goldSum, attemptSum = 20000, 0, 0
		for run = 1, runs do
			local level, gauge = 0, 0
			while level < 19 do
				goldSum += EnhanceConfig.goldCost[level + 1]
				attemptSum += 1
				local outcome = Enhance.tryEnhance(level, gauge, FLAGS_OFF)
				level, gauge = outcome.level, outcome.gauge
			end
			if run % 2000 == 0 then
				task.wait()
			end
		end
		monteGold, monteAttempts = goldSum / runs, attemptSum / runs
		r.check(("⑦ 0 → 19강 기대 골드: 해석식 %.0f · 몬테카를로 %d회 평균 %.0f (기대 498,8xx ±1%% = PRD 498,822 · 몬테카를로는 해석식 ±3%%) ★진짜 합격 기준"):format(
			analyticGold, runs, monteGold),
			math.abs(analyticGold - 498822) <= 498822 * 0.01 and math.abs(monteGold - analyticGold) <= analyticGold * 0.03)
		r.check(("⑧ 0 → 19강 기대 시도 수: 해석식 %.2f · 몬테카를로 평균 %.2f (기대 34.6 ±1 - 옛 구조 679회)"):format(analyticAttempts, monteAttempts),
			math.abs(analyticAttempts - 34.6) <= 1 and math.abs(monteAttempts - 34.6) <= 1)
	end)
end

local function outcomeString(outcomes)
	return ("%.0f/%.0f/%.0f/%.0f/%.0f"):format(outcomes.success * 100, outcomes.maintain * 100, outcomes.down1 * 100, outcomes.down2 * 100, outcomes.reset * 100)
end

local function outcomeMatches(outcomes, expected)
	for index, key in ipairs(RESULT_KEYS) do
		if math.abs(outcomes[key] * 100 - expected[index]) > 1e-6 then
			return false
		end
	end
	return true
end

local function checkOutcomeTable(r)
	r.section("[9] getOutcomeTable", function()
		local dropOnly = Enhance.getOutcomeTable(23, false, true, false)
		local both = Enhance.getOutcomeTable(23, false, true, true)
		local full = Enhance.getOutcomeTable(23, true, true, true)
		local plain = Enhance.getOutcomeTable(23, false, false, false)
		local max = Enhance.getOutcomeTable(EnhanceConfig.maxLevel, false, false, false)
		r.check(("(23강) 기본 %s · 하락 방지 %s(기대 12/87/0/0/1) · 둘 다 %s(기대 12/88/0/0/0) · gaugeFull %s(기대 100/0/0/0/0) · 상한 %s(기대 nil)"):format(
			outcomeString(plain), outcomeString(dropOnly), outcomeString(both), outcomeString(full), tostring(max)),
			outcomeMatches(plain, { 12, 81, 4, 2, 1 }) and outcomeMatches(dropOnly, { 12, 87, 0, 0, 1 }) and outcomeMatches(both, { 12, 88, 0, 0, 0 })
				and outcomeMatches(full, { 100, 0, 0, 0, 0 }) and max == nil)
	end)
end

-- 저장 이관: 게이지 없는 v24 프로필 → 모든 직업 0 · 강화 단계는 그대로 · isValidProfile 통과 / 1001 · 소수 · 음수는 거부.
local function checkSaveMigration(r)
	r.section("[10] 저장 이관", function()
		local classA, classB = ClassData.order[1], ClassData.order[2]
		local profile = SaveSystem.defaultProfile()
		profile.version = 24
		for _, classState in pairs(profile.classes) do
			classState.weapon.enhanceGauge = nil -- v24까지는 이 필드가 없었다
		end
		profile.classes[classA].weapon.level = 21 -- 이미 20강 이상인 무기 - 단계는 소급 없이 그대로여야 한다
		profile.classes[classB].weapon.level = 7
		local migrated = SaveSystem.migrate(profile)
		local allZero = true
		for _, classState in pairs(migrated.classes) do
			allZero = allZero and classState.weapon.enhanceGauge == 0
		end
		local levelsKept = migrated.classes[classA].weapon.level == 21 and migrated.classes[classB].weapon.level == 7
		local validAfter = SaveSystem.isValidProfile(migrated)

		local function validWith(value)
			local copy = deepCopy(migrated)
			copy.classes[classA].weapon.enhanceGauge = value
			return SaveSystem.isValidProfile(copy)
		end
		local edge = validWith(EnhanceConfig.gauge.max) and validWith(0) -- 경계는 통과
		local rejects = not validWith(EnhanceConfig.gauge.max + 1) and not validWith(-1) and not validWith(12.5)
		r.check(("v24 → v%d: 모든 직업 게이지 0=%s · 강화 단계 그대로(+21 · +7)=%s · isValidProfile=%s(기대 true) · 경계 0 · %d 통과=%s · %d(1001) · -1 · 12.5 거부=%s"):format(
			migrated.version, tostring(allZero), tostring(levelsKept), tostring(validAfter), EnhanceConfig.gauge.max, tostring(edge), EnhanceConfig.gauge.max + 1, tostring(rejects)),
			migrated.version == SaveConfig.saveVersion and allZero and levelsKept and validAfter and edge and rejects)
	end)
end

function EnhanceVerify.runPure()
	print("===S03 검증 시작(가: 확률표 · 골드표 · 천장)===")
	local r = newRecorder("가")
	checkRowSums(r)
	local ok, err = pcall(sampleDistribution, r)
	if not ok then
		r.check(("분포 표본 수집 중 에러: %s"):format(tostring(err)), false)
	else
		checkDistribution(r)
		checkNoDropBelow19(r)
	end
	checkCeiling(r)
	if ok then
		checkFloors(r)
	end
	checkGaugeRules(r)
	checkExpectedGold(r)
	checkOutcomeTable(r)
	checkSaveMigration(r)
	local pass, total = r.summary()
	print(("===S03 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 경로 ───────────────────────────

function EnhanceVerify.runLive(player, env)
	print("===S03 검증 시작(나: 실제 EnhanceRequest 경로)===")
	local r = newRecorder("나")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not PlayerProfile.getProfile(player) or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S03 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	local savedCFrame = root.CFrame
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local goldBefore = PlayerProfile.getGold(player)
	local weaponBefore = PlayerProfile.getWeapon(player)
	local levelBefore, gaugeBefore = weaponBefore.level, PlayerProfile.getEnhanceGauge(player)

	-- 강화대 옆으로 옮기고(핸들러가 근접을 확인한다) 시작 상태를 만든 뒤, 실제 핸들러(EnhanceService.handleRequest)를 count번 부른다.
	-- fixedLevel이 있으면 매 시도 전에 그 단계로 되돌린다(게이지는 그대로) - 하락 · 초기화가 나와도 같은 단계를 계속 시험한다.
	-- 시도마다 payload · 프로필을 순수 함수(Enhance.getResultLevel · getGaugeGain)가 정한 기대값과 대조한다.
	local function runAttempts(count, fixedLevel)
		local stats = { attempts = 0, missing = 0, dropped = 0, mismatches = 0, badResult = 0, spent = 0, failures = 0, downs = 0, gaugeGained = 0, successes = 0, trace = {} }
		for _ = 1, count do
			task.wait(EnhanceService.requestCooldownSeconds + 0.1) -- 요청 쿨다운(0.5초)
			if fixedLevel then
				PlayerProfile.setWeaponLevel(player, fixedLevel)
			end
			local levelBeforeTry = PlayerProfile.getWeapon(player).level
			local gaugeBeforeTry = PlayerProfile.getEnhanceGauge(player)
			local payload = EnhanceService.handleRequest(player)
			if not payload then
				stats.missing += 1
			else
				stats.attempts += 1
				stats.spent += payload.cost or 0
				local weapon = PlayerProfile.getWeapon(player)
				if payload.level < levelBeforeTry then
					stats.dropped += 1
				end
				local isSuccess = payload.result == "success"
				if isSuccess then
					stats.successes += 1
				else
					stats.failures += 1
					if payload.result == "down1" or payload.result == "down2" or payload.result == "reset" then
						stats.downs += 1
					end
				end
				-- 기대: 단계 = getResultLevel, 게이지 = 성공이면 0 / 실패면 min(max, 이전 + 시도한 단계의 gain), gaugeGain = 실제로 오른 양
				local expectedLevel = Enhance.getResultLevel(levelBeforeTry, payload.result)
				local expectedGauge = isSuccess and 0 or math.min(EnhanceConfig.gauge.max, gaugeBeforeTry + Enhance.getGaugeGain(levelBeforeTry))
				stats.gaugeGained += math.max(0, payload.gauge - gaugeBeforeTry)
				if payload.gauge ~= PlayerProfile.getEnhanceGauge(player) or payload.level ~= weapon.level or payload.gaugeMax ~= EnhanceConfig.gauge.max
					or payload.level ~= expectedLevel or payload.gauge ~= expectedGauge or payload.gaugeGain ~= math.max(0, expectedGauge - gaugeBeforeTry)
					or (gaugeBeforeTry >= EnhanceConfig.gauge.max and not isSuccess) then -- 천장: 게이지가 가득이면 이번 시도는 반드시 성공
					stats.mismatches += 1
				end
				if fixedLevel == nil and not isSuccess and payload.result ~= "maintain" then
					stats.badResult += 1
				end
				table.insert(stats.trace, ("+%d %s→+%d(게이지 %d)"):format(levelBeforeTry, payload.result, payload.level, payload.gauge))
			end
		end
		return stats
	end

	local goldStart, spentTotal = 0, 0
	r.section("[나] 준비", function()
		-- 루트를 고정(Anchored)한 채 옮긴다 - Play 시작 때 플레이어가 보스 아레나(z = -2900대)에 서 있으면(저장 스테이지가 보스 스테이지일 때) 2,600stud를
		-- 순간이동한 자리의 지형을 클라이언트가 아직 못 받아 캐릭터가 추락하고, 심연 복귀로 강화대 밖에 서서 응답 10회가 전부 nil이 된다(S04 사전 Play에서 확인).
		root.Anchored = true
		root.CFrame = CFrame.new(WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset + Vector3.new(0, 3, 0))
		PlayerProfile.setWeaponLevel(player, 0)
		PlayerProfile.setEnhanceGauge(player, 0)
		PlayerProfile.addGold(player, 20000000 * GoldCost.scale(PlayerProfile.getAccountBestStage(player), "enhance")) -- 19강 시도 1회 23.5만 × 10회까지 넉넉히
		goldStart = PlayerProfile.getGold(player)
	end)

	r.section("[나] +0에서 10회", function()
		local stats = runAttempts(10, nil)
		spentTotal += stats.spent
		r.check(("+0에서 시작 시도 %d회(응답 없음 %d): 단계가 내려간 적 %d(기대 0) · success/maintain 밖의 결과 %d(기대 0) ★진짜 합격 기준 · 경과: %s"):format(
			stats.attempts, stats.missing, stats.dropped, stats.badResult, table.concat(stats.trace, " ")),
			stats.attempts == 10 and stats.dropped == 0 and stats.badResult == 0)
		r.check(("payload · 프로필이 기대와 같다(어긋난 시도 %d회, 기대 0 - 단계 · 게이지 · gaugeGain · gaugeMax) · 골드 차감 = payload.cost 합 %d"):format(stats.mismatches, stats.spent), stats.mismatches == 0)
	end)

	-- 위 10회는 거의 성공만 나와 게이지가 움직이지 않는다 - 실패 경로(게이지 적립 · 천장 · 하락 · 단계 유지)를 실제 핸들러로 밟는다.
	r.section("[나] 실패 경로", function()
		PlayerProfile.setEnhanceGauge(player, 0)
		-- S04부터 19강 시도는 강화석을 쓴다(EnhanceMaterialData.costByLevel[19]) - 이 구역은 게이지 · 골드 경로만 보므로 10회 몫의 두 배를 쥐여 준다
		-- (재료 소모 · 부족 거절은 S04 (나)가 본다. env.restore가 되돌린다).
		local cost19 = EnhanceMaterialData.costByLevel[19]
		PlayerProfile.addMaterial(player, cost19.id, cost19.count * 20)
		local at17 = runAttempts(12, 17) -- 성공률 0.28 - 하락 없음 · 게이지가 쌓이다 천장(9번째 이내)에서 성공
		local at19 = runAttempts(10, 19) -- 성공률 0.28 - 하락(14%) · 유지 · 게이지는 하락해도 유지
		spentTotal += at17.spent + at19.spent
		r.check(("+17에서 12회: 실패 %d · 성공 %d · 게이지 적립 합 %d · 단계가 내려간 적 %d(기대 0) · 어긋남 %d(기대 0) / +19에서 10회: 실패 %d(하락 %d) · 성공 %d · 게이지 적립 합 %d · 어긋남 %d(기대 0) - 기대: 실패가 실제로 나왔고 게이지가 payload · 프로필 · 순수 함수와 같다"):format(
			at17.failures, at17.successes, at17.gaugeGained, at17.dropped, at17.mismatches, at19.failures, at19.downs, at19.successes, at19.gaugeGained, at19.mismatches),
			at17.failures > 0 and at17.gaugeGained > 0 and at17.dropped == 0 and at17.mismatches == 0 and at17.missing == 0
				and at19.failures > 0 and at19.gaugeGained > 0 and at19.mismatches == 0 and at19.missing == 0)
		print(("[S03][나]   +17 경과: %s"):format(table.concat(at17.trace, " ")))
		print(("[S03][나]   +19 경과: %s"):format(table.concat(at19.trace, " ")))
	end)

	r.section("[나] 골드", function()
		local goldSpent = goldStart - PlayerProfile.getGold(player)
		r.check(("골드 차감 합 %d = 모든 시도의 payload.cost 합 %d (기대 같음 - 골드 차감은 재료와 별개로 payload.cost 그대로다)"):format(goldSpent, spentTotal), goldSpent == spentTotal)
	end)

	-- 되돌리기: classes · gold는 env.restore가, 캐릭터 위치는 직접.
	env.restore(player)
	local currentRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if currentRoot then
		currentRoot.Anchored = false
		currentRoot.CFrame = savedCFrame
	end
	local weaponAfter = PlayerProfile.getWeapon(player)
	r.check(("검증 뒤 되돌림: 골드 %s → %s · 무기 +%s → +%s · 게이지 %s → %s (기대 전부 같음)"):format(
		tostring(goldBefore), tostring(PlayerProfile.getGold(player)), tostring(levelBefore), tostring(weaponAfter and weaponAfter.level),
		tostring(gaugeBefore), tostring(PlayerProfile.getEnhanceGauge(player))),
		PlayerProfile.getGold(player) == goldBefore and weaponAfter ~= nil and weaponAfter.level == levelBefore and PlayerProfile.getEnhanceGauge(player) == gaugeBefore)

	local pass, total = r.summary()
	print(("===S03 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- S04(PRD 20.85) - 강화 재료 2종 + 재료 × 경험치 배수
-- ═══════════════════════════════════════════════════════════════════════════

local RESULT_SET = { success = true, maintain = true, down1 = true, down2 = true, reset = true }
local ENHANCE_STONE, HIGH_STONE = "enhanceStone", "highEnhanceStone"

-- ─────────────────────────── S04 (가) 순수 함수 ───────────────────────────

local function checkRollCount(r)
	r.section("[1] rollCount(0.25)", function()
		local samples, sum, outside = 100000, 0, 0
		for _ = 1, samples do
			local value = Loot.rollCount(0.25)
			sum += value
			if value ~= 0 and value ~= 1 then
				outside += 1
			end
		end
		local mean = sum / samples
		r.check(("rollCount(0.25) %d회: 평균 %.4f(기대 0.25 ± 0.005) · 0 또는 1이 아닌 값 %d개(기대 0)"):format(samples, mean, outside),
			math.abs(mean - 0.25) <= 0.005 and outside == 0)
	end)

	r.section("[2] rollCount(5.0) · rollCount(7.5)", function()
		local samples, notFive, notSevenEight, sum = 20000, 0, 0, 0
		for _ = 1, samples do
			if Loot.rollCount(5.0) ~= 5 then
				notFive += 1
			end
			local value = Loot.rollCount(7.5)
			sum += value
			if value ~= 7 and value ~= 8 then
				notSevenEight += 1
			end
		end
		local mean = sum / samples
		r.check(("rollCount(5.0) %d회 중 5가 아닌 것 %d개(기대 0) · rollCount(7.5): 7 · 8이 아닌 것 %d개(기대 0) · 평균 %.4f(기대 7.5 ± 0.05)"):format(
			samples, notFive, notSevenEight, mean), notFive == 0 and notSevenEight == 0 and math.abs(mean - 7.5) <= 0.05)
	end)
end

-- 기대 개수 식 표: tier1 ~ 6 × 접두사 배율(1 · 3) × 경험치 배수(1.0 · 1.2 · 1.5). 마릿수분은 MonsterState.getKillUnits(= tier r^p × 접두사)이고 골드가 쓰는
-- 배율(goldDrop ÷ tier1.goldDrop × 접두사)과 같은지도 같이 본다. 가짜 모델(빈 테이블)을 MonsterState에 등록해 실제 함수를 그대로 부른다.
local function checkExpectedFormula(r)
	r.section("[3] 기대 개수 식", function()
		local chance = EnhanceMaterialData.materials[ENHANCE_STONE].dropChancePerKill
		local multipliers = { 1.0, 1.2, 1.5 }
		local allOk, halfOk = true, true
		for tierIndex, tierKey in ipairs(MonsterData.tierOrder) do
			local data = MonsterData[tierKey]
			local rows = {}
			for _, prefixMultiplier in ipairs({ 1, 3 }) do
				local fake = {}
				MonsterState.init(fake, data, nil, nil, { prefix = prefixMultiplier ~= 1 and { hpMultiplier = prefixMultiplier } or nil })
				local units = MonsterState.getKillUnits(fake)
				MonsterState.clear(fake)
				local goldRatio = data.goldDrop / MonsterData.tier1.goldDrop * prefixMultiplier
				allOk = allOk and math.abs(units - goldRatio) <= 1e-9
				local cells = {}
				local baseCount
				for _, multiplier in ipairs(multipliers) do
					local expected = Loot.expectedMaterialCount(ENHANCE_STONE, units, multiplier)
					allOk = allOk and math.abs(expected - chance * units * multiplier) <= 1e-9
					baseCount = baseCount or expected
					halfOk = halfOk and (multiplier ~= 1.5 or math.abs(expected - baseCount * 1.5) <= 1e-9)
					table.insert(cells, ("%.3f"):format(expected))
				end
				table.insert(rows, ("접두사x%d 마릿수분 %.3f → 기대 %s"):format(prefixMultiplier, units, table.concat(cells, "/")))
			end
			print(("[S04][가]   tier%d(r^p=%.3f): %s (경험치 배수 1.0/1.2/1.5)"):format(tierIndex, data.goldDrop / MonsterData.tier1.goldDrop, table.concat(rows, " · ")))
		end
		r.check(("tier1 ~ 6 × 접두사 1 · 3 × 배수 1.0/1.2/1.5: 기대 개수 = 0.25 × 마릿수분 × 배수(오차 ≤ 1e-9) · 마릿수분 = 골드 배율(goldDrop ÷ tier1 × 접두사)=%s · 배수 1.5 = 1.0의 1.5배=%s ★진짜 합격 기준(경험치 배수가 곱해진다)"):format(
			tostring(allOk), tostring(halfOk)), allOk and halfOk)
	end)
end

local function checkCostTable(r)
	r.section("[4] costByLevel", function()
		local expected = { [19] = 8, [20] = 10, [21] = 12, [22] = 10, [23] = 13, [24] = 16 }
		local cells, ok = {}, true
		for level = 19, 24 do
			local entry = EnhanceMaterialData.costByLevel[level]
			ok = ok and entry ~= nil and entry.count == expected[level]
			table.insert(cells, ("%d강 %s"):format(level, entry and ("%s %d개"):format(entry.id, entry.count) or "없음"))
		end
		ok = ok and EnhanceMaterialData.costByLevel[19].id == ENHANCE_STONE and EnhanceMaterialData.costByLevel[21].id == ENHANCE_STONE
			and EnhanceMaterialData.costByLevel[22].id == HIGH_STONE and EnhanceMaterialData.costByLevel[24].id == HIGH_STONE
		local below, above = 0, 0
		for level = 0, 18 do
			if EnhanceMaterialData.costByLevel[level] then
				below += 1
			end
		end
		if EnhanceMaterialData.costByLevel[EnhanceConfig.maxLevel] then -- P2.5a: 최대 단계(25 → 30)에는 재료 칸이 없다(시도 불가)
			above += 1
		end
		r.check(("%s · 0 ~ 18강에 재료 있는 단계 %d개(기대 0) · 최대 %d강 %d개(기대 0) - 기대 8 · 10 · 12 · 10 · 13 · 16"):format(table.concat(cells, " · "), below, EnhanceConfig.maxLevel, above),
			ok and below == 0 and above == 0)
	end)
end

local function checkMaterialsSave(r)
	r.section("[5] 저장 이관 · 검사", function()
		local profile = SaveSystem.defaultProfile()
		profile.version = 25
		profile.materials = nil -- v25까지는 이 필드가 없었다
		local migrated = SaveSystem.migrate(profile)
		local zeros = migrated.materials ~= nil and migrated.materials[ENHANCE_STONE] == 0 and migrated.materials[HIGH_STONE] == 0
		local validAfter = SaveSystem.isValidProfile(migrated)

		local kept = SaveSystem.defaultProfile()
		kept.version = 25
		kept.materials = { [ENHANCE_STONE] = 7, [HIGH_STONE] = 3 }
		local keptMigrated = SaveSystem.migrate(kept)
		local keeps = keptMigrated.materials[ENHANCE_STONE] == 7 and keptMigrated.materials[HIGH_STONE] == 3

		local function validWith(mutate)
			local copy = deepCopy(migrated)
			mutate(copy)
			return SaveSystem.isValidProfile(copy)
		end
		local rejects = {
			negative = validWith(function(copy) copy.materials[ENHANCE_STONE] = -1 end),
			fraction = validWith(function(copy) copy.materials[HIGH_STONE] = 2.5 end),
			missing = validWith(function(copy) copy.materials[HIGH_STONE] = nil end),
			notTable = validWith(function(copy) copy.materials = 5 end),
		}
		local edgeOk = validWith(function(copy) copy.materials[ENHANCE_STONE] = 0 end) and validWith(function(copy) copy.materials[HIGH_STONE] = 123456 end)
		local rejectsOk = not rejects.negative and not rejects.fraction and not rejects.missing and not rejects.notTable
		r.check(("v25 → v%d: 재료 둘 다 0=%s · isValidProfile=%s(기대 true) · 이미 있는 값(7 · 3)은 유지=%s · 0 · 123456 통과=%s · 음수 · 소수 · 빠짐 · 표 아님 거부=%s"):format(
			migrated.version, tostring(zeros), tostring(validAfter), tostring(keeps), tostring(edgeOk), tostring(rejectsOk)),
			migrated.version == SaveConfig.saveVersion and zeros and validAfter and keeps and edgeOk and rejectsOk)
	end)
end

function EnhanceVerify.runPureS04()
	print("===S04 검증 시작(가: 재료 순수 함수)===")
	local r = newRecorder("가", "S04")
	checkRollCount(r)
	checkExpectedFormula(r)
	checkCostTable(r)
	checkMaterialsSave(r)
	local pass, total = r.summary()
	print(("===S04 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── S04 (나) 실제 처치 경로 · 강화 소모 ───────────────────────────

-- 검증용 잡몹은 플레이어에게서 먼 곳에 스폰한다. 잡몹은 죽으면 5초 뒤 같은 자리에 스스로 리스폰하므로(MonsterSpawner.despawn) 배치마다 그 시간을
-- 기다렸다가 새로 생긴 몬스터 · 땅의 드랍을 전부 지운다 - "검증이 남긴 것 0"을 지키는 방법이다(제품 코드에 검증용 훅을 넣지 않는다).
-- 자리는 **지면이 있는** 곳이어야 한다: 사망 지점에 지면이 없으면 ItemDropSpawner가 드랍을 주인 발밑에 떨어뜨려 자동 줍기가 가방을 채운다
-- (처음 Play에서 지면 없는 (0, 5, 4000)에 세웠다가 그렇게 가방이 가득 차 보스 드랍이 땅으로 갔다). 그래서 플레이어에게서 가장 먼 tier 구역의 중심을 쓴다.
local KILL_CHUNK = 200

local function monsterSet()
	local set = {}
	for _, model in ipairs(MonsterState.getAllModels()) do
		set[model] = true
	end
	return set
end

local function groundSet()
	local set = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		set[model] = true
	end
	return set
end

local function clearNewGround(player, before)
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not before[model] and ItemDropState.getOwnerId(model) == player.UserId and model.Parent then
			ItemDropSpawner.despawn(model)
		end
	end
end

local function materialSnapshot(player)
	local values = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		values[materialId] = PlayerProfile.getMaterial(player, materialId)
	end
	return values
end

local function materialGains(player, before)
	local gains = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		gains[materialId] = PlayerProfile.getMaterial(player, materialId) - before[materialId]
	end
	return gains
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- 플레이어에게서 가장 먼 tier 구역의 중심(지면 위 5).
local function farSpotFrom(player)
	local root = rootOf(player)
	local best, bestDistance = nil, -1
	for _, zoneKey in ipairs(WorldConfig.tierZoneOrder) do
		local center = WorldConfig.zones[zoneKey].center
		local distance = root and (center - root.Position).Magnitude or 0
		if distance > bestDistance then
			best, bestDistance = center, distance
		end
	end
	return best + Vector3.new(0, 5, 0)
end

-- 실제 처치 경로로 count마리를 잡는다: 스폰 → applyDamage → resolveHit(handleMobDeath → grantKillReward → 재료). variant = {} 이면 접두사 · 반짝이 없는 기본형.
local function killMobs(player, count, data, variant)
	local monstersBefore, groundBefore = monsterSet(), groundSet()
	local stage = TutorialState.getMonsterStage(player)
	local spot = farSpotFrom(player)
	for index = 1, count do
		local model = MonsterSpawner.spawn(data, spot, nil, variant)
		local isDead = MonsterState.applyDamage(model, 1e12, stage, player)
		CombatResolution.resolveHit(player, model, isDead)
		if index % 50 == 0 then
			task.wait()
		end
	end
	task.wait(WorldConfig.zoneMonsterGrid.respawnDelaySeconds + 1)
	for _, model in ipairs(MonsterState.getAllModels()) do
		if not monstersBefore[model] then
			MonsterState.clear(model)
			if model.Parent then
				model:Destroy()
			end
		end
	end
	clearNewGround(player, groundBefore)
end

-- count마리를 chunk씩 나눠 잡고(리스폰 폭주를 줄인다) 재료 증가량을 돌려준다.
local function killAndMeasure(player, count, data, variant)
	local before = materialSnapshot(player)
	local remaining = count
	while remaining > 0 do
		local chunk = math.min(KILL_CHUNK, remaining)
		killMobs(player, chunk, data, variant)
		remaining -= chunk
	end
	return materialGains(player, before)
end

local function setMaterial(player, materialId, amount)
	local have = PlayerProfile.getMaterial(player, materialId)
	if have > amount then
		PlayerProfile.trySpendMaterial(player, materialId, have - amount)
	elseif have < amount then
		PlayerProfile.addMaterial(player, materialId, amount - have)
	end
end

-- 보스를 실제 처치 경로로 잡는다(27-1 (나)와 같은 호출 - resolveHit이 handleBossDeath · 복귀 텔레포트 · despawn까지 탄다). standInRatio가 있으면 그 기여의
-- 스탠드인(가짜 Player)을 encounter 후보에 끼운다. 스탠드인이 보상을 받으면 FireClient에서 하드 에러가 나므로 resolveHit은 pcall로 감싼다.
local function killBossOnce(player, env, stage, standInRatio)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	if not model then
		return nil
	end
	local data = MonsterState.getData(model)
	local playerStage = TutorialState.getMonsterStage(player)
	local _, maxHp = MonsterState.getBossHp(model)
	if standInRatio then
		local standIn = { Name = "S04StandIn", Parent = true }
		BossEncounter.debugAddMember(model, standIn)
		MonsterState.applyDamage(model, maxHp * standInRatio, playerStage, standIn)
	end
	local before = materialSnapshot(player)
	local isDead = MonsterState.applyDamage(model, maxHp, playerStage, player)
	MonsterSpawner.updateHpLabel(model)
	local ok, err = pcall(CombatResolution.resolveHit, player, model, isDead)
	BossEncounter.despawnFor(player)
	return { gains = materialGains(player, before), ok = ok, err = err, units = BossData.bosses[data.id].hpMultiplier, playerStage = playerStage, bossId = data.id }
end
-- S11(보스 도감 검증)이 같은 실제 처치 경로를 쓴다.
EnhanceVerify.killBossOnce = killBossOnce

local function gainsText(gains)
	return ("강화석 +%d · 상급 +%d"):format(gains[ENHANCE_STONE], gains[HIGH_STONE])
end

function EnhanceVerify.runLiveS04(player, env)
	print("===S04 검증 시작(나: 실제 처치 경로 · 강화 소모)===")
	local r = newRecorder("나", "S04")
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S04 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player) -- classes · gold · 가방 · 재료는 env.restore가 되돌린다
	local savedCFrame = root.CFrame
	local materialsBefore, bagBefore, monstersBefore, groundBefore = materialSnapshot(player), #profile.inventory, monsterSet(), groundSet()
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end

	-- 기준 상태: 착용 장비 · 보석을 비워 경험치 배수가 1이 되게 한다(개발 계정의 성장 옵션이 기대값을 흔들지 않게). 9번만 성장 옵션 장비를 낀다.
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		PlayerProfile.setEquippedDirect(player, part, nil)
	end
	local weapon = PlayerProfile.getWeapon(player)
	for slot = 1, #weapon.gems do
		weapon.gems[slot] = false
	end
	local baseMultiplier = PlayerProfile.getExpGainMultiplier(player)
	local chance = EnhanceMaterialData.materials[ENHANCE_STONE].dropChancePerKill
	print(("[S04][나] 기준 상태: 경험치 배수 x%.3f(기대 1.000) · 처치 기준 스테이지는 아래 항목마다 지정한다"):format(baseMultiplier))

	local function prepareStage(stage)
		env.applyStage(player, stage)
		return TutorialState.getMonsterStage(player) == stage
	end

	local tier1 = MonsterData.tier1
	-- P2.5c 결정 10: 해금 스테이지는 데이터에서 읽는다(옛 50 · 75 → 힘 비율 환산 358 · 539).
	local stoneStage = EnhanceMaterialData.materials[ENHANCE_STONE].minStage
	local highStage = EnhanceMaterialData.materials[HIGH_STONE].minStage

	r.section("[6] 강화석 해금 바로 아래 · 200마리", function()
		if not prepareStage(stoneStage - 1) then
			r.check(("준비 실패: 처치 기준 스테이지 %s(기대 %d) - 견습 진행 중이면 그 단계의 스테이지가 쓰인다"):format(tostring(TutorialState.getMonsterStage(player)), stoneStage - 1), false)
			return
		end
		local gains = killAndMeasure(player, 200, tier1, {})
		r.check(("스테이지 %d · tier1 200마리 처치: %s (기대 0 · 0 - 경계 바로 아래) ★진짜 합격 기준"):format(stoneStage - 1, gainsText(gains)), gains[ENHANCE_STONE] == 0 and gains[HIGH_STONE] == 0)
	end)

	r.section("[7] 강화석 해금 스테이지 · 400마리", function()
		if not prepareStage(stoneStage) then
			r.check(("준비 실패: 처치 기준 스테이지가 %d가 아니다"):format(stoneStage), false)
			return
		end
		local gains = killAndMeasure(player, 400, tier1, {})
		local expected = 400 * chance * baseMultiplier
		r.check(("스테이지 %d · tier1 · 접두사 없음 400마리 처치: %s (기대 강화석 %.0f ± 25 · 상급 0) ★진짜 합격 기준"):format(stoneStage, gainsText(gains), expected),
			math.abs(gains[ENHANCE_STONE] - expected) <= 25 and gains[HIGH_STONE] == 0)
	end)

	r.section("[8] 상급 해금 바로 아래 / 해금", function()
		if not prepareStage(highStage - 1) then
			r.check(("준비 실패: 처치 기준 스테이지가 %d가 아니다"):format(highStage - 1), false)
			return
		end
		local at74 = killAndMeasure(player, 100, tier1, {})
		if not prepareStage(highStage) then
			r.check(("준비 실패: 처치 기준 스테이지가 %d가 아니다"):format(highStage), false)
			return
		end
		local at75 = killAndMeasure(player, 100, tier1, {})
		r.check(("스테이지 %d · 100마리: %s (기대 강화석 > 0 · 상급 0) / 스테이지 %d · 100마리: %s (기대 둘 다 > 0) ★진짜 합격 기준"):format(highStage - 1, gainsText(at74), highStage, gainsText(at75)),
			at74[ENHANCE_STONE] > 0 and at74[HIGH_STONE] == 0 and at75[ENHANCE_STONE] > 0 and at75[HIGH_STONE] > 0)
	end)

	r.section("[9] 경험치 배수 m > 1 · 강화석 해금 스테이지 · 400마리", function()
		-- 성장(expGain) 옵션 장비를 낀다 - 26-2 검증이 옵션 장비를 만드는 방식(setEquippedDirect + option 테이블)을 따른다. 새 디버그 훅은 없다.
		PlayerProfile.setEquippedDirect(player, "armor", {
			grade = "primordial", part = "armor", dropStage = 100, itemLevel = 100, tierIndex = 1, locked = true, option = { id = "expGain", roll = 1.0 },
		})
		local multiplier = PlayerProfile.getExpGainMultiplier(player)
		if multiplier <= baseMultiplier then
			r.check(("성장 옵션이 안 걸림: 경험치 배수 x%.3f(기대 > 1)"):format(multiplier), false)
			return
		end
		if not prepareStage(stoneStage) then
			r.check(("준비 실패: 처치 기준 스테이지가 %d가 아니다"):format(stoneStage), false)
			return
		end
		local gains = killAndMeasure(player, 400, tier1, {})
		local perKill = chance * multiplier -- < 1이면 매 처치 베르누이(확률 perKill)
		local mean = 400 * perKill
		local fraction = perKill - math.floor(perKill)
		local sigma = math.sqrt(400 * fraction * (1 - fraction))
		r.check(("경험치 배수 m = x%.3f(getExpGainMultiplier): 강화석 해금 스테이지 · 400마리 처치: %s (기대 강화석 %.1f ± %.1f(3σ) = 100 × m ± 3σ · 상급 0) ★진짜 합격 기준"):format(
			multiplier, gainsText(gains), mean, 3 * sigma), math.abs(gains[ENHANCE_STONE] - mean) <= 3 * sigma and gains[HIGH_STONE] == 0)
		PlayerProfile.setEquippedDirect(player, "armor", nil)
	end)

	-- P2.5c 결정 10: 강화석만 나오는 첫 보스 스테이지(옛 50 → 강화석 해금 이상 · 상급 해금 미만의 첫 보스 스테이지 360).
	local stoneBossStage = math.ceil(stoneStage / BossData.stageInterval) * BossData.stageInterval
	r.section("[10] 보스(강화석 해금 뒤 첫 보스 스테이지) 처치", function()
		local result = killBossOnce(player, env, stoneBossStage, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		-- 기대 = 0.25 × 20 × 배수 = 5(배수 1) - 소수부가 없어 정확히 5다. 지시서의 범위는 4 ~ 6.
		local expected = chance * result.units * baseMultiplier
		r.check(("스테이지 %d 보스 처치(마릿수분 %d, 받는 사람 스테이지 %d): %s (기대 강화석 4 ~ 6 · 상급 0) · resolveHit 에러=%s"):format(
			stoneBossStage, result.units, result.playerStage, gainsText(result.gains), result.ok and "없음" or tostring(result.err)),
			result.ok and result.gains[ENHANCE_STONE] >= 4 and result.gains[ENHANCE_STONE] <= 6 and math.abs(result.gains[ENHANCE_STONE] - expected) <= 1 and result.gains[HIGH_STONE] == 0)
	end)

	r.section("[11] 기여 9% 스탠드인 + 실제 Player 91%", function()
		local result = killBossOnce(player, env, stoneBossStage, 0.09)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		-- 스탠드인이 보상을 받았다면 grantKillReward의 FireClient가 하드 에러를 냈을 것이다(27-1 A-기여도와 같은 구성) - 에러 없이 실제 Player만 받는다.
		r.check(("스탠드인 기여 9%% + 실제 Player: %s (기대 강화석 4 ~ 6 - 실제 Player만 받는다) · 스탠드인이 받았다면 났을 하드 에러=%s(기대 없음)"):format(
			gainsText(result.gains), result.ok and "없음" or tostring(result.err)),
			result.ok and result.gains[ENHANCE_STONE] >= 4 and result.gains[ENHANCE_STONE] <= 6)
	end)

	-- 12 · 13: 강화대 옆에서 실제 EnhanceService.handleRequest 경로. 루트를 고정(Anchored)해 강화대로 옮긴다 - 옮긴 자리의 지형이 아직 스트리밍되지 않았을 때
	-- 캐릭터가 추락해 "심연 복귀"로 강화대 밖에 서는 일을 막는다(S04 사전 Play에서 S03 (나)가 그렇게 실패했다).
	local function standAtStation()
		local currentRoot = rootOf(player)
		currentRoot.Anchored = true
		currentRoot.CFrame = CFrame.new(WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset + Vector3.new(0, 3, 0))
	end

	r.section("[12] 19강 · 강화석 7개 → 부족 거절", function()
		standAtStation()
		PlayerProfile.setWeaponLevel(player, 19)
		PlayerProfile.setEnhanceGauge(player, 0)
		PlayerProfile.addGold(player, 20000000 * GoldCost.scale(PlayerProfile.getAccountBestStage(player), "enhance")) -- P2 C1: 계정 최고 > 100이면 비용이 커진다
		setMaterial(player, ENHANCE_STONE, 7)
		task.wait(EnhanceService.requestCooldownSeconds + 0.1)
		local goldBefore = PlayerProfile.getGold(player)
		local payload = EnhanceService.handleRequest(player)
		local goldAfter, stonesAfter = PlayerProfile.getGold(player), PlayerProfile.getMaterial(player, ENHANCE_STONE)
		r.check(("19강 · 강화석 7개 · 골드 충분: 결과 %s(기대 insufficient_material) · 필요 %s · 보유 %s(기대 8 · 7) · 골드 %d → %d(기대 그대로) · 강화석 %d개(기대 7) · 무기 +%d(기대 +19)"):format(
			payload and payload.result or "응답 없음", tostring(payload and payload.need), tostring(payload and payload.have), goldBefore, goldAfter, stonesAfter,
			PlayerProfile.getWeapon(player).level),
			payload ~= nil and payload.result == "insufficient_material" and payload.materialId == ENHANCE_STONE and payload.need == 8 and payload.have == 7
				and goldAfter == goldBefore and stonesAfter == 7 and PlayerProfile.getWeapon(player).level == 19)
	end)

	r.section("[13] 강화석 8개 → 시도", function()
		setMaterial(player, ENHANCE_STONE, 8)
		task.wait(EnhanceService.requestCooldownSeconds + 0.1)
		local goldBefore = PlayerProfile.getGold(player)
		local payload = EnhanceService.handleRequest(player)
		local goldAfter, stonesAfter = PlayerProfile.getGold(player), PlayerProfile.getMaterial(player, ENHANCE_STONE)
		local resultOk = payload ~= nil and RESULT_SET[payload.result] == true
			and payload.level == Enhance.getResultLevel(19, payload.result) and PlayerProfile.getWeapon(player).level == payload.level
		-- P2 C1: 1회 골드 = GoldCost(표 235,000, 계정 최고 스테이지) - 최고 100 이하면 235,000 그대로, 그 위면 골드 수입과 같은 비율로 크다.
		local expectedCost = Enhance.getCost(19, PlayerProfile.getAccountBestStage(player))
		r.check(("강화석 8개 → 시도: 결과 %s · 무기 +%d · 강화석 8 → %d(기대 0) · 골드 %.0f → %.0f(차감 %.0f, 기대 %.0f = 표 235,000 × GoldCost(최고 %d)) · 결과가 정상(5종 중 하나 · 단계가 판정과 같음)=%s"):format(
			payload and payload.result or "응답 없음", PlayerProfile.getWeapon(player).level, stonesAfter, goldBefore, goldAfter, goldBefore - goldAfter, expectedCost,
			PlayerProfile.getAccountBestStage(player), tostring(resultOk)),
			resultOk and stonesAfter == 0 and Enhance.getCost(19) == 235000 and goldBefore - goldAfter == expectedCost)
	end)

	-- [14] 되돌리기: classes · gold · 가방 · 재료는 env.restore가, 위치 · 고정은 직접. 검증이 만든 것은 전부 없어야 한다.
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.Anchored = false
		currentRoot.CFrame = savedCFrame
	end
	local orphans, leftoverMonsters = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
		if not monstersBefore[model] then
			leftoverMonsters += 1
		end
	end
	local leftoverDrops = 0
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not groundBefore[model] and ItemDropState.getOwnerId(model) == player.UserId and model.Parent then
			leftoverDrops += 1
		end
	end
	local materialsAfter = materialSnapshot(player)
	local materialsSame = materialsAfter[ENHANCE_STONE] == materialsBefore[ENHANCE_STONE] and materialsAfter[HIGH_STONE] == materialsBefore[HIGH_STONE]
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d개 · 검증이 남긴 몬스터 %d개 · 땅의 드랍 %d개(기대 0 · 0 · 0) · 재료 %d/%d → %d/%d(기대 같음) · 가방 %d → %d칸(기대 같음)"):format(
		orphans, leftoverMonsters, leftoverDrops, materialsBefore[ENHANCE_STONE], materialsBefore[HIGH_STONE], materialsAfter[ENHANCE_STONE], materialsAfter[HIGH_STONE],
		bagBefore, #profile.inventory), orphans == 0 and leftoverMonsters == 0 and leftoverDrops == 0 and materialsSame and #profile.inventory == bagBefore)

	local pass, total = r.summary()
	print(("===S04 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end


-- ═══════════════════════════════════════════════════════════════════════════
-- S05(PRD 20.86) - 방지권 2종 · 상점 · 보스 계정 첫 클리어 지급 · 규제 관문
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────── S05 (가) 순수 함수 ───────────────────────────

local function checkBossGrantFormula(r)
	r.section("[1] bossGrant 식", function()
		-- P2.5c 결정 10: 지급 스테이지는 데이터(힘 비율 환산 360 · 180칸 · 720)에서 만든다 - 옛 45 · 50 · 55 · 75 · 100 · 125 · 130 · 150과 같은 모양의 행.
		local grant, interval = EnhanceConfig.protection.bossGrant, BossData.stageInterval
		local expected = {
			{ grant.firstStage - interval, 0, 0 }, { grant.firstStage, 1, 0 }, { grant.firstStage + interval, 0, 0 }, { grant.firstStage + grant.stepStages, 1, 0 },
			{ grant.resetFromStage, 1, 1 }, { grant.resetFromStage + grant.stepStages, 1, 1 }, { grant.resetFromStage + interval, 0, 0 }, { grant.resetFromStage + 2 * grant.stepStages, 1, 1 },
		}
		local cells, ok = {}, true
		for _, row in ipairs(expected) do
			local dropCount, resetCount = Enhance.getBossGrant(row[1])
			ok = ok and dropCount == row[2] and resetCount == row[3]
			table.insert(cells, ("%d → 하락 %d · 초기화 %d"):format(row[1], dropCount, resetCount))
		end
		r.check(("%s (기대 없음 · 하락 · 없음 · 하락 · 둘 다 · 둘 다 · 없음 · 둘 다)"):format(table.concat(cells, " / ")), ok)
	end)
end

local function checkProtectionPrice(r)
	r.section("[2] 방지권 가격", function()
		-- P2.5a: 골드 성장률이 1.001이라 스테이지 83과 1의 마리당 골드가 같다(6) - 차이가 보이는 계정 최고 3000으로 잰다(식은 그대로).
		local perKill = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 3000)
		local dropPrice, resetPrice = Enhance.getProtectionPrice("drop", 3000), Enhance.getProtectionPrice("reset", 3000)
		-- 가격 함수는 "계정 최고 스테이지" 하나만 받는다(지금 서 있는 스테이지 인자가 없다) - 서 있는 스테이지를 1로 바꿔도 같은 값인지는 실제 Player의 상점 경로로 (나) 17번이 잰다.
		r.check(("계정 최고 3000: 하락 %d(기대 스테이지 3000 마리당 골드 %d × 300 = %d) · 초기화 %d(기대 × 900 = %d) · 스테이지 1 기준 하락 %d은 더 싸다(=스테이지 1로 내려가 사는 길이 있었다면 그 값) - 함수는 계정 최고만 받는다"):format(
			dropPrice, perKill, perKill * 300, resetPrice, perKill * 900, Enhance.getProtectionPrice("drop", 1)),
			dropPrice == perKill * 300 and resetPrice == perKill * 900 and Enhance.getProtectionPrice("drop", 1) < dropPrice)
	end)
end

-- 23강(성공 12 · 하락 6 · 초기화 1 · 유지 81)을 samples회 굴려 결과 분포와 방지권 소모율을 잰다. 게이지는 매번 0(천장이 끼지 않게).
local function measureProtection(level, flags, samples)
	local counts = { success = 0, maintain = 0, down1 = 0, down2 = 0, reset = 0 }
	local blocked = { drop = 0, reset = 0 }
	for index = 1, samples do
		local outcome = Enhance.tryEnhance(level, 0, flags)
		counts[outcome.result] += 1
		if outcome.blockedBy then
			blocked[outcome.blockedBy] += 1
		end
		if index % 100000 == 0 then
			task.wait()
		end
	end
	return counts, blocked
end

local function distributionText(counts, samples)
	local cells = {}
	for _, key in ipairs(RESULT_KEYS) do
		table.insert(cells, ("%.2f"):format(counts[key] / samples * 100))
	end
	return table.concat(cells, " / ")
end

local function distributionWithin(counts, samples, expected, tolerance)
	for index, key in ipairs(RESULT_KEYS) do
		if math.abs(counts[key] / samples - expected[index]) > tolerance then
			return false
		end
	end
	return true
end

local function checkProtectionDistribution(r)
	local samples = 200000
	local dropCounts, dropBlocked
	r.section("[3] 23강 · 하락 방지 on", function()
		dropCounts, dropBlocked = measureProtection(23, { true, false }, samples)
		local usage = dropBlocked.drop / samples
		r.check(("23강 · 하락 방지 on · %d회: 성공/유지/하락1/하락2/초기화 = %s %%(기대 12/87/0/0/1 ±0.3%%p) · 소모 장수 ÷ 시도 = %.4f(기대 0.06 ± 0.003) · 초기화 방지권 소모 %d(기대 0)"):format(
			samples, distributionText(dropCounts, samples), usage, dropBlocked.reset),
			distributionWithin(dropCounts, samples, { 0.12, 0.87, 0, 0, 0.01 }, 0.003) and math.abs(usage - 0.06) <= 0.003 and dropBlocked.reset == 0)
	end)

	r.section("[4] 3번의 분포 = getOutcomeTable", function()
		local table23 = Enhance.getOutcomeTable(23, false, true, false)
		local expected, cells = {}, {}
		for _, key in ipairs(RESULT_KEYS) do
			table.insert(expected, table23[key])
			table.insert(cells, ("%.2f"):format(table23[key] * 100))
		end
		r.check(("getOutcomeTable(23, false, true, false) = %s %%: 3번의 실제 분포 %s %%와 ±0.3%%p 안에서 같다(같은 표)"):format(
			table.concat(cells, " / "), dropCounts and distributionText(dropCounts, samples) or "3번 실패"),
			dropCounts ~= nil and distributionWithin(dropCounts, samples, expected, 0.003))
	end)

	r.section("[5] 23강 · 둘 다 on", function()
		local counts, blocked = measureProtection(23, { true, true }, samples)
		local resetUsage = blocked.reset / samples
		r.check(("23강 · 둘 다 on · %d회: 분포 %s %%(기대 12/88/0/0/0 ±0.3%%p) · 초기화 방지권 소모율 %.4f(기대 0.01 ± 0.002) · 하락 방지권 소모율 %.4f(기대 0.06)"):format(
			samples, distributionText(counts, samples), resetUsage, blocked.drop / samples),
			distributionWithin(counts, samples, { 0.12, 0.88, 0, 0, 0 }, 0.003) and math.abs(resetUsage - 0.01) <= 0.002)
	end)
end

-- ★ 진짜 합격 기준: 막지 않은 시도에서 방지권이 빠진 적이 없다. 같은 롤로 **원래 확률표의 결과**(방지권 없음)를 따로 구해, 그 결과가 성공 · 유지인데 방지권이
-- 소모된 시도(blockedBy가 있는 시도)를 센다. 하락 · 초기화인데 방지권이 안 빠진 시도도 같이 센다(막을 수 있었는데 안 막은 경우).
local function checkNoWastedTickets(r)
	r.section("[6] 성공 · 유지에서 방지권 소모", function()
		local wasted, missed, blockedTotal, samples = 0, 0, 0, 0
		for level = 19, 24 do
			local original = Enhance.getOutcomeTable(level, false, false, false)
			for index = 1, 50000 do
				local roll = math.random()
				local rolled = Enhance.rollResult(original, roll)
				local outcome = Enhance.tryEnhance(level, 0, { true, true }, roll)
				samples += 1
				if outcome.blockedBy then
					blockedTotal += 1
				end
				if (rolled == "success" or rolled == "maintain") and outcome.blockedBy ~= nil then
					wasted += 1
				end
				-- 하락은 하락 방지권이, 초기화는 초기화 방지권이 (해당 단계에서 쓸 수 있으면) 반드시 막는다. 20 · 21강에는 초기화가 없고 19강엔 초기화 확률이 없다.
				if (rolled == "down1" or rolled == "down2") and outcome.blockedBy ~= "drop" then
					missed += 1
				elseif rolled == "reset" and outcome.blockedBy ~= "reset" then
					missed += 1
				end
				if index % 25000 == 0 then
					task.wait()
				end
			end
		end
		r.check(("19 ~ 24강 × 5만 회(방지권 둘 다 on, 총 %d회 · 막은 시도 %d회): 원래 결과가 성공 · 유지인데 방지권이 빠진 시도 %d건(기대 0) ★진짜 합격 기준 · 막을 수 있는 하락 · 초기화를 못 막은 시도 %d건(기대 0)"):format(
			samples, blockedTotal, wasted, missed), wasted == 0 and missed == 0 and blockedTotal > 0)
	end)
end

local function checkFlagResolution(r)
	r.section("[7] 요청 플래그 재검증", function()
		local cases = {
			{ "18강에서 하락 방지 on(보유 5)", { 18, false, true, false, 5, 5 }, { false, false } },
			{ "21강에서 초기화 방지 on(보유 5)", { 21, false, false, true, 5, 5 }, { false, false } },
			{ "23강에서 둘 다 on · 보유 0", { 23, false, true, true, 0, 0 }, { false, false } },
			{ "19강에서 하락 방지 on(보유 1) - 쓸 수 있다", { 19, false, true, true, 1, 1 }, { true, false } },
			{ "23강에서 둘 다 on(보유 1 · 1) - 쓸 수 있다", { 23, false, true, true, 1, 1 }, { true, true } },
			{ "boolean이 아닌 값(문자열 · 숫자)", { 23, false, "yes", 1, 5, 5 }, { false, false } },
		}
		local cells, ok = {}, true
		for _, case in ipairs(cases) do
			local args = case[2]
			local useDrop, useReset = Enhance.resolveProtectionFlags(args[1], args[2], args[3], args[4], args[5], args[6])
			local same = useDrop == case[3][1] and useReset == case[3][2]
			ok = ok and same
			table.insert(cells, ("%s → %s/%s"):format(case[1], tostring(useDrop), tostring(useReset)))
		end
		-- 플래그가 false로 처리된 시도는 방지권을 안 쓰고 강화는 정상이다: flags = { false, false }로 만 회 굴려 blockedBy가 한 번도 없고 결과가 5종 안이다.
		local blockedAny, outOfSet = 0, 0
		for _ = 1, 10000 do
			local outcome = Enhance.tryEnhance(23, 0, { false, false })
			if outcome.blockedBy then
				blockedAny += 1
			end
			if not RESULT_SET[outcome.result] then
				outOfSet += 1
			end
		end
		r.check(("%s · 플래그 false로 만 회 강화: 소모 %d건 · 5종 밖의 결과 %d건(기대 0 · 0)"):format(table.concat(cells, " / "), blockedAny, outOfSet), ok and blockedAny == 0 and outOfSet == 0)
	end)
end

local function checkFullGauge(r)
	r.section("[8] 게이지 가득 + 방지 on", function()
		local useDrop, useReset = Enhance.resolveProtectionFlags(23, true, true, true, 5, 5)
		local outcome = Enhance.tryEnhance(23, EnhanceConfig.gauge.max, { true, true })
		r.check(("게이지 가득 · 23강 · 둘 다 on(보유 5 · 5): 플래그 %s/%s(기대 false/false) · 결과 %s(기대 success) · 방지권 소모 %s(기대 없음) · 게이지 %d(기대 0)"):format(
			tostring(useDrop), tostring(useReset), outcome.result, tostring(outcome.blockedBy), outcome.gauge),
			useDrop == false and useReset == false and outcome.result == "success" and outcome.blockedBy == nil and outcome.gauge == 0)
	end)
end

local function checkBlockedGauge(r)
	r.section("[9] 막힌 시도의 게이지", function()
		-- 롤 0.95는 23강 원래 표(성공 0.12 · 유지 0.81 · 하락1 0.04 · 하락2 0.02 · 초기화 0.01)에서 하락1(0.93 ~ 0.97)이다.
		local before = 100
		local blockedByDrop = Enhance.tryEnhance(23, before, { true, false }, 0.95)
		local plain = Enhance.tryEnhance(23, before, { false, false }, 0.95)
		local gain = Enhance.getGaugeGain(23)
		r.check(("23강 · 롤 0.95(원래 결과 하락) · 하락 방지 on: 결과 %s · 막은 것 %s · 게이지 %d → %d(기대 %d - 막힌 시도도 실패라 찬다) · 방지권 없이는 결과 %s · 게이지 %d(막힌 시도와 같다) · 단계 %d(기대 23 그대로)"):format(
			blockedByDrop.result, tostring(blockedByDrop.blockedBy), before, blockedByDrop.gauge, before + gain, plain.result, plain.gauge, blockedByDrop.level),
			blockedByDrop.result == "maintain" and blockedByDrop.blockedBy == "drop" and blockedByDrop.gauge == before + gain and plain.result == "down1"
				and plain.gauge == blockedByDrop.gauge and blockedByDrop.level == 23)
	end)
end

local function checkPolicy(r)
	r.section("[10] EnhancePolicy", function()
		local inputs = { "gold", "enhanceStone" }
		local emptyTrue, emptyReason = EnhancePolicy.evaluate(inputs, EnhanceConfig.paidInputIds, true) -- 제품 데이터 표(빈 표) + 제한 true 주입
		-- 검증 안에서만 "enhanceStone"을 넣은 사본 표 - 제품 데이터 표는 안 건드린다.
		local copy = deepCopy(EnhanceConfig.paidInputIds)
		table.insert(copy, "enhanceStone")
		local restrictedOk, restrictedReason = EnhancePolicy.evaluate(inputs, copy, true)
		local freeOk = EnhancePolicy.evaluate(inputs, copy, false)
		local unrelatedOk = EnhancePolicy.evaluate({ "gold", "dropTicket" }, copy, true)
		r.check(("paidInputIds %d개(기대 0): 제한 true를 주입해도 canAttempt 핵심 %s(기대 true - 이 분기는 절대 안 탄다) · 사본 표에 enhanceStone: 제한 true → %s %s(기대 false paid_random_restricted) · 제한 false → %s(기대 true) · 표에 없는 투입물(gold · dropTicket)만 → %s(기대 true)"):format(
			#EnhanceConfig.paidInputIds, tostring(emptyTrue), tostring(restrictedOk), tostring(restrictedReason), tostring(freeOk), tostring(unrelatedOk)),
			#EnhanceConfig.paidInputIds == 0 and emptyTrue == true and emptyReason == nil and restrictedOk == false and restrictedReason == "paid_random_restricted"
				and freeOk == true and unrelatedOk == true)
	end)
end

local function checkProtectionSave(r)
	r.section("[11] 저장 이관 · 검사", function()
		local profile = SaveSystem.defaultProfile()
		profile.version = 26
		profile.purchases.protectionTickets = nil -- v26까지는 이 필드가 없었다
		profile.purchases.protectionClaimedStages = nil
		local migrated = SaveSystem.migrate(profile)
		local zeros = migrated.purchases.protectionTickets ~= nil and migrated.purchases.protectionTickets.drop == 0 and migrated.purchases.protectionTickets.reset == 0
		local emptyClaims = migrated.purchases.protectionClaimedStages ~= nil and next(migrated.purchases.protectionClaimedStages) == nil
		local validAfter = SaveSystem.isValidProfile(migrated)

		local kept = SaveSystem.defaultProfile()
		kept.version = 26
		kept.purchases.protectionTickets = { drop = 4, reset = 2 }
		kept.purchases.protectionClaimedStages = { ["50"] = true }
		local keptMigrated = SaveSystem.migrate(kept)
		local keeps = keptMigrated.purchases.protectionTickets.drop == 4 and keptMigrated.purchases.protectionTickets.reset == 2 and keptMigrated.purchases.protectionClaimedStages["50"] == true

		local function validWith(mutate)
			local copy = deepCopy(migrated)
			mutate(copy)
			return SaveSystem.isValidProfile(copy)
		end
		local rejects = not validWith(function(copy) copy.purchases.protectionTickets.drop = -1 end)
			and not validWith(function(copy) copy.purchases.protectionTickets.reset = 1.5 end)
			and not validWith(function(copy) copy.purchases.protectionTickets.reset = nil end)
			and not validWith(function(copy) copy.purchases.protectionTickets = 3 end)
			and not validWith(function(copy) copy.purchases.protectionClaimedStages = nil end)
		local edgeOk = validWith(function(copy) copy.purchases.protectionTickets.drop = 0 end) and validWith(function(copy) copy.purchases.protectionTickets.reset = 999 end)
		r.check(("v26 → v%d: 0장 둘 다=%s · 받은 스테이지 빈 집합=%s · isValidProfile=%s(기대 true) · 이미 있는 값(4 · 2 · 스테이지 50)은 유지=%s · 0 · 999 통과=%s · 음수 · 소수 · 빠짐 · 표 아님 · 집합 없음 거부=%s"):format(
			migrated.version, tostring(zeros), tostring(emptyClaims), tostring(validAfter), tostring(keeps), tostring(edgeOk), tostring(rejects)),
			migrated.version == SaveConfig.saveVersion and zeros and emptyClaims and validAfter and keeps and edgeOk and rejects)
	end)
end

function EnhanceVerify.runPureS05()
	print("===S05 검증 시작(가: 방지권 순수 함수)===")
	local r = newRecorder("가", "S05")
	checkBossGrantFormula(r)
	checkProtectionPrice(r)
	checkProtectionDistribution(r) -- 3 · 4 · 5번
	checkNoWastedTickets(r)
	checkFlagResolution(r)
	checkFullGauge(r)
	checkBlockedGauge(r)
	checkPolicy(r)
	checkProtectionSave(r)
	local pass, total = r.summary()
	print(("===S05 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── S05 (나) 실제 처치 경로 · 상점 ───────────────────────────

local function ticketCounts(player)
	return PlayerProfile.getProtectionTicket(player, "drop"), PlayerProfile.getProtectionTicket(player, "reset")
end

function EnhanceVerify.runLiveS05(player, env)
	print("===S05 검증 시작(나: 실제 처치 경로 · 상점)===")
	local r = newRecorder("나", "S05")
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S05 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player) -- classes · gold · 가방 · 재료 · 방지권 · 받은 스테이지는 env.restore가 되돌린다
	local savedCFrame = root.CFrame
	local bagBefore, monstersBefore = #profile.inventory, monsterSet()
	local dropBefore, resetBefore = ticketCounts(player)
	local claimsBefore = deepCopy(profile.purchases.protectionClaimedStages)
	local classA, classB = ClassData.order[1], ClassData.order[2]
	PlayerProfile.setClassId(player, classA)

	-- 기준 상태: 방지권 0장 · 받은 스테이지 빈 집합(개발 계정에 남은 값이 결과를 흔들지 않게). 직업 둘의 첫 클리어 기록도 비운다.
	PlayerProfile.trySpendProtectionTicket(player, "drop", dropBefore)
	PlayerProfile.trySpendProtectionTicket(player, "reset", resetBefore)
	table.clear(profile.purchases.protectionClaimedStages)
	table.clear(profile.inventory) -- 보스 장비가 매번 가방으로 들어오므로 자리를 비운다(가방은 env.restore가 되돌린다)
	for _, classId in ipairs({ classA, classB }) do
		profile.classes[classId].stageProgress.bossFirstClearStages = {}
	end

	-- 보스를 실제 처치 경로로 잡고, 방지권 증가량 · 즉시 저장 요청 수 · 가방 증가를 함께 잰다.
	local function killAndMeasure(stage, standInRatio)
		local dropStart, resetStart = ticketCounts(player)
		local bagStart, savesStart = #profile.inventory, ImmediateSave.getRequestCount()
		local result = killBossOnce(player, env, stage, standInRatio)
		if not result then
			return nil
		end
		local dropEnd, resetEnd = ticketCounts(player)
		result.dropGain, result.resetGain = dropEnd - dropStart, resetEnd - resetStart
		result.bagGain, result.saves = #profile.inventory - bagStart, ImmediateSave.getRequestCount() - savesStart
		return result
	end

	-- P2.5c 결정 10: 옛 50(첫 지급) · 75(다음 지급) · 100(초기화 시작) → 데이터의 360 · 540 · 720.
	local grant = EnhanceConfig.protection.bossGrant
	local firstGrant, secondGrant, resetGrant = grant.firstStage, grant.firstStage + grant.stepStages, grant.resetFromStage
	r.section("[12] 직업 A · 첫 지급 스테이지 보스", function()
		local result = killAndMeasure(firstGrant, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		-- 저장 형식: 키가 문자열이어야 DataStore 왕복 뒤에도 같은 조회가 통한다(숫자 키는 문자열로 돌아온다 - PlayerProfile.hasClaimedProtectionStage 주석).
		local claimKey = next(profile.purchases.protectionClaimedStages)
		r.check(("직업 %s · 스테이지 %d 보스 처치: 하락 방지권 +%d(기대 1) · 초기화 +%d(기대 0) · protectionClaimedStages[%d]=%s(기대 true) · 저장 키 %s(%s, 기대 %d string) · 즉시 저장 요청 %d회(기대 1) · resolveHit 에러=%s"):format(
			classA, firstGrant, result.dropGain, result.resetGain, firstGrant, tostring(PlayerProfile.hasClaimedProtectionStage(player, firstGrant)), tostring(claimKey), typeof(claimKey), firstGrant, result.saves, result.ok and "없음" or tostring(result.err)),
			result.ok and result.dropGain == 1 and result.resetGain == 0 and PlayerProfile.hasClaimedProtectionStage(player, firstGrant) and claimKey == tostring(firstGrant) and result.saves == 1)
	end)

	r.section("[13] 같은 보스를 한 번 더", function()
		local result = killAndMeasure(firstGrant, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		r.check(("같은 첫 지급 스테이지 보스를 한 번 더: 방지권 하락 +%d · 초기화 +%d(기대 0 · 0 - 계정 단위 1회)"):format(result.dropGain, result.resetGain), result.ok and result.dropGain == 0 and result.resetGain == 0)
	end)

	r.section("[14] 직업 B로 같은 첫 지급 스테이지 보스", function()
		PlayerProfile.setClassId(player, classB)
		local firstClearBefore = PlayerProfile.hasBossFirstClearReward(player, firstGrant)
		local result = killAndMeasure(firstGrant, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		local firstClearAfter = PlayerProfile.hasBossFirstClearReward(player, firstGrant)
		-- 장비 확정 드랍은 직업별 첫 클리어라 나온다: 가방에 아이템이 들어오고(빈 가방) 직업 B의 첫 클리어 기록이 새로 찍힌다.
		r.check(("직업 %s(직업 %s로 이미 받은 스테이지)로 첫 지급 스테이지 보스: 방지권 하락 +%d · 초기화 +%d(기대 0 · 0) ★진짜 합격 기준 · 장비 확정 드랍 - 직업 %s 첫 클리어 기록 %s → %s(기대 false → true) · 가방 +%d(기대 1)"):format(
			classB, classA, result.dropGain, result.resetGain, classB, tostring(firstClearBefore), tostring(firstClearAfter), result.bagGain),
			result.ok and result.dropGain == 0 and result.resetGain == 0 and firstClearBefore == false and firstClearAfter == true and result.bagGain == 1)
		PlayerProfile.setClassId(player, classA)
	end)

	r.section("[15] 초기화 지급 시작 스테이지 보스", function()
		local result = killAndMeasure(resetGrant, nil)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		r.check(("스테이지 %d 보스: 하락 +%d · 초기화 +%d(기대 1 · 1)"):format(resetGrant, result.dropGain, result.resetGain), result.ok and result.dropGain == 1 and result.resetGain == 1)
	end)

	r.section("[16] 기여 9% 스탠드인", function()
		local result = killAndMeasure(secondGrant, 0.09)
		if not result then
			r.check("보스 스폰 실패", false)
			return
		end
		-- 스탠드인이 지급 대상이면 grantForBoss의 FireClient에서 하드 에러가 났을 것이다 - 에러 없이 실제 Player만 받는다.
		r.check(("스테이지 %d 보스 · 스탠드인 기여 9%% + 실제 Player: 하락 +%d(기대 1 - 실제 Player만) · 스탠드인이 지급 대상이었다면 났을 하드 에러=%s(기대 없음)"):format(
			secondGrant, result.dropGain, result.ok and "없음" or tostring(result.err)), result.ok and result.dropGain == 1 and PlayerProfile.hasClaimedProtectionStage(player, secondGrant))
	end)

	r.section("[17] 상점", function()
		-- 지금 서 있는 스테이지는 1, 계정 최고 스테이지는 83(모든 직업) - 가격 기준이 계정 최고인지 본다.
		for _, classId in ipairs(ClassData.order) do
			profile.classes[classId].stageProgress.infiniteBest = 83
		end
		env.applyStage(player, 1)
		local prices = ProtectionTickets.getPrices(player)
		local perKill = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 83)
		local priceOk = prices.accountBestStage == 83 and prices.drop == perKill * 300 and prices.reset == perKill * 900

		-- (a) 강화대 밖(보스 처치 뒤 사냥터로 복귀한 자리 - 강화대에서 멀다) - 골드가 충분해도 거절
		PlayerProfile.addGold(player, prices.drop * 3)
		local goldA, dropA = PlayerProfile.getGold(player), PlayerProfile.getProtectionTicket(player, "drop")
		local okOutside, reasonOutside = ProtectionTickets.tryBuy(player, "drop")
		local outsideOk = okOutside == false and reasonOutside == "not_near_station" and PlayerProfile.getGold(player) == goldA and PlayerProfile.getProtectionTicket(player, "drop") == dropA

		-- (b) 강화대 안 · 골드 부족 - 거절, 골드 불변
		local stationRoot = rootOf(player)
		stationRoot.Anchored = true
		stationRoot.CFrame = CFrame.new(WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset + Vector3.new(0, 3, 0))
		PlayerProfile.trySpendGold(player, PlayerProfile.getGold(player)) -- 골드를 0으로
		PlayerProfile.addGold(player, prices.drop - 1)
		local goldB, dropB = PlayerProfile.getGold(player), PlayerProfile.getProtectionTicket(player, "drop")
		local okPoor, reasonPoor = ProtectionTickets.tryBuy(player, "drop")
		local poorOk = okPoor == false and reasonPoor == "insufficient_gold" and PlayerProfile.getGold(player) == goldB and PlayerProfile.getProtectionTicket(player, "drop") == dropB

		-- (c) 강화대 안 · 골드 충분 - 장수 +1, 골드가 정확히 가격만큼
		PlayerProfile.addGold(player, 1 + 500)
		local goldC, dropC = PlayerProfile.getGold(player), PlayerProfile.getProtectionTicket(player, "drop")
		local okBuy, priceOrReason = ProtectionTickets.tryBuy(player, "drop")
		local buyOk = okBuy == true and PlayerProfile.getProtectionTicket(player, "drop") == dropC + 1 and goldC - PlayerProfile.getGold(player) == prices.drop and priceOrReason == prices.drop
		local okInvalid, reasonInvalid = ProtectionTickets.tryBuy(player, "bossGrant")
		r.check(("서 있는 스테이지 1 · 계정 최고 %d: 가격 하락 %d(기대 %d = 스테이지 83 × 300) · 초기화 %d(기대 %d = × 900)=%s / 강화대 밖 → %s %s · 골드 · 장수 불변=%s / 강화대 안 · 골드 %d(가격 %d 미만) → %s %s · 골드 불변=%s / 골드 충분 → %s · 장수 %d → %d(기대 +1) · 골드 %d → %d(차감 %d, 기대 가격 %d) · 잘못된 종류 → %s"):format(
			prices.accountBestStage, prices.drop, perKill * 300, prices.reset, perKill * 900, tostring(priceOk),
			tostring(okOutside), tostring(reasonOutside), tostring(outsideOk), goldB, prices.drop, tostring(okPoor), tostring(reasonPoor), tostring(poorOk),
			tostring(okBuy), dropC, PlayerProfile.getProtectionTicket(player, "drop"), goldC, PlayerProfile.getGold(player), goldC - PlayerProfile.getGold(player), prices.drop, tostring(reasonInvalid)),
			priceOk and outsideOk and poorOk and buyOk and okInvalid == false and reasonInvalid == "invalid_kind")
	end)

	-- [18] 되돌리기: classes · gold · 가방 · 재료 · 방지권 · 받은 스테이지는 env.restore가, 위치 · 고정은 직접. 검증이 만든 것은 전부 없어야 한다.
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.Anchored = false
		currentRoot.CFrame = savedCFrame
	end
	local orphans, leftoverMonsters = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
		if not monstersBefore[model] then
			leftoverMonsters += 1
		end
	end
	local dropAfter, resetAfter = ticketCounts(player)
	local claimsSame = true
	for key in pairs(profile.purchases.protectionClaimedStages) do
		claimsSame = claimsSame and claimsBefore[key] == true
	end
	for key in pairs(claimsBefore) do
		claimsSame = claimsSame and profile.purchases.protectionClaimedStages[key] == true
	end
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d개 · 검증이 남긴 몬스터 %d개(기대 0 · 0) · 방지권 하락 %d → %d · 초기화 %d → %d · 받은 스테이지 같음=%s · 가방 %d → %d칸 · 직업 %s(기대 전부 같음)"):format(
		orphans, leftoverMonsters, dropBefore, dropAfter, resetBefore, resetAfter, tostring(claimsSame), bagBefore, #profile.inventory, tostring(PlayerProfile.getClassId(player))),
		orphans == 0 and leftoverMonsters == 0 and dropAfter == dropBefore and resetAfter == resetBefore and claimsSame and #profile.inventory == bagBefore)

	local pass, total = r.summary()
	print(("===S05 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return EnhanceVerify
