-- S03 자동 검증(PRD 20.84) - 강화 확률표 · 골드표 · 천장("장인의 기운").
--   (가) 순수 함수 + 합성 프로필 - 서버 시작 때(플레이어 없이).
--   (나) 실제 Player · 실제 EnhanceService.handleRequest(= EnhanceRequest 핸들러 본문) 경로 - 보스 검증 체인의 끝에서 돈다.
-- env = { ensureBackup, restore } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(골드 · 무기 강화 단계 · 게이지 · 캐릭터 위치)은 (나)가 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local EnhanceService = require(script.Parent.EnhanceService)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveSystem = require(script.Parent.SaveSystem)

local EnhanceVerify = {}

local RESULT_KEYS = { "success", "maintain", "down1", "down2", "reset" }
local FLAGS_OFF = { false, false }

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S03][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

	r.section("[나] +0에서 10회", function()
		-- 강화대 옆으로 옮기고(핸들러가 근접을 확인한다) +0 · 게이지 0 · 넉넉한 골드로 시작한다.
		root.CFrame = CFrame.new(WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset + Vector3.new(0, 3, 0))
		PlayerProfile.setWeaponLevel(player, 0)
		PlayerProfile.setEnhanceGauge(player, 0)
		PlayerProfile.addGold(player, 100000)
		local goldStart = PlayerProfile.getGold(player)

		local attempts, drops, mismatches, spent, missing, badResult = 0, 0, 0, 0, 0, 0
		local trace = {}
		for _ = 1, 10 do
			task.wait(EnhanceService.requestCooldownSeconds + 0.1) -- 요청 쿨다운(0.5초)
			local levelBeforeTry = PlayerProfile.getWeapon(player).level
			local payload = EnhanceService.handleRequest(player)
			if not payload then
				missing += 1
			else
				attempts += 1
				spent += payload.cost or 0
				local weapon = PlayerProfile.getWeapon(player)
				if payload.level < levelBeforeTry or weapon.level < levelBeforeTry then
					drops += 1
				end
				if payload.gauge ~= PlayerProfile.getEnhanceGauge(player) or payload.level ~= weapon.level or payload.gaugeMax ~= EnhanceConfig.gauge.max then
					mismatches += 1
				end
				if payload.result ~= "success" and payload.result ~= "maintain" then
					badResult += 1
				end
				table.insert(trace, ("%s→+%d(게이지 %d)"):format(payload.result, payload.level, payload.gauge))
			end
		end
		local goldSpent = goldStart - PlayerProfile.getGold(player)
		r.check(("시도 %d회(응답 없음 %d): 단계가 내려간 적 %d(기대 0) · success/maintain 밖의 결과 %d(기대 0) ★진짜 합격 기준 · 경과: %s"):format(
			attempts, missing, drops, badResult, table.concat(trace, " ")), attempts == 10 and drops == 0 and badResult == 0)
		r.check(("payload의 gauge · level · gaugeMax가 프로필과 같다(어긋난 시도 %d회, 기대 0) · 골드 차감 %d = payload.cost 합 %d"):format(mismatches, goldSpent, spent),
			mismatches == 0 and goldSpent == spent)
	end)

	-- 되돌리기: classes · gold는 env.restore가, 캐릭터 위치는 직접.
	env.restore(player)
	local currentRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if currentRoot then
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

return EnhanceVerify
