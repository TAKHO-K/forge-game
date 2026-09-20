-- S14 자동 검증(PRD 20.81 [C-3]) - 스테이지 25 이후 낙하 원 밀도 + 검사기.
--   (가) 순수 계산 - 식 · 사본 규칙 · 대상 조건 · 검사기 48칸 · 몬테카를로 · 2연타. 로컬 Luau 하네스와 같은 값(난수는 BossSim의 자체 LCG).
--   (나) 실제 서버 경로 - 스테이지 100 구간 수호자를 스폰해 낙석을 강제로 시작하고(한 틱 뒤 원의 수) 겹친 원에서 한 번만 맞는지, 견습 · 스테이지 25는 원래 값인지.
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼. 검사기의 진짜 합격 기준은 (가) 4번이다: 실패하면 값을 고치지 않는다(maxExtra = 0으로 끄고 표와 함께 보고).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossDensityVerify = {}

local GUARDIAN = "section_guardian"
local TRIALS = 10000 -- 칸당 무작위 배치 횟수(작업 지시 4번)
local CHECK_SEED = 20260920
local TUNING_RUNS = 100 -- 6종 몬테카를로(29-5 (가)와 같은 100회/칸)
-- 밀도 대상 3종: 구간 수호자 낙석 · 서리 거인 낙빙 · 전갈 여왕 독침 낙하(BossData의 densityScalable 플래그 - 아래 [3]이 조건과 대조한다).
local TARGETS = { { GUARDIAN, "meteor" }, { "frost_giant", "icefall" }, { "scorpion_queen", "sting" } }

local function near(actual, expected, tolerance)
	return actual ~= nil and math.abs(actual - expected) <= tolerance
end

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S14][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function runPure()
	print("===S14 검증 시작(가: 밀도 식 · 사본 규칙 · 대상 조건 · 검사기 · 몬테카를로 · 2연타)===")
	local r = newRecorder("가")
	local density = BossData.mechanics.stageDensity

	r.section("[1] densityExtra", function()
		local stages = { 5, 25, 49, 50, 74, 75, 100, 500 }
		local expected = { 0, 0, 0, 1, 1, 2, 3, 3 }
		local cells, ok = {}, true
		for index, stage in ipairs(stages) do
			local extra = BossRules.densityExtra(stage)
			ok = ok and extra == expected[index]
			table.insert(cells, ("%d→%d(기대 %d)"):format(stage, extra, expected[index]))
		end
		r.check(("1 densityExtra(시작 %d · 간격 %d · 상한 %d): %s · 견습 스테이지 1 → %d(기대 0) · isPairStage(100) = %s(기대 false - 자리만)"):format(
			density.startStage, density.stepStages, density.maxExtra, table.concat(cells, " "), BossRules.densityExtra(1), tostring(BossRules.isPairStage(100))),
			ok and BossRules.densityExtra(1) == 0 and BossRules.isPairStage(100) == false and density.startStage == 25 and density.stepStages == 25 and density.maxExtra == 3)
	end)

	r.section("[2] 사본 규칙", function()
		local source = BossData.bosses[GUARDIAN].skills.meteor
		local rawCount, rawScatter = source.count, source.scatterStuds
		local data = BossRules.buildInstanceData(100, GUARDIAN, 1)
		local dense = data.skills.meteor
		local scale = BossRules.skillRangeScale(100)
		local ok = dense ~= source and dense.count == rawCount + 3 and near(dense.scatterStuds, rawScatter * scale * math.sqrt((rawCount + 3) / rawCount), 1e-9)
			and data.densityExtra == 3 and source.count == 3 and source.scatterStuds == 10
			and dense.radiusStuds == source.radiusStuds * scale and dense.telegraphSeconds == source.telegraphSeconds and dense.cooldownSeconds == source.cooldownSeconds
		r.check(("2 스테이지 100 구간 수호자 낙석: count %d → %d(기대 3 → 6) · 산개 %.3f = 10 × 범위 배율 %.3f × √2 = %.3f · **BossData 원본은 count %d · 산개 %g 그대로** · 반경 = 원본 × 배율(밀도는 반경을 안 건드림) · 예고 · 쿨 그대로"):format(
			rawCount, dense.count, dense.scatterStuds, scale, 10 * scale * math.sqrt(2), source.count, source.scatterStuds), ok)

		local cells, cellsOk = {}, true
		for _, stage in ipairs({ 49, 50, 75, 100 }) do
			local skill = BossRules.buildInstanceData(stage, GUARDIAN, 1).skills.meteor
			local expectedCount = 3 + BossRules.densityExtra(stage)
			cellsOk = cellsOk and skill.count == expectedCount
			table.insert(cells, ("%d→%d개"):format(stage, skill.count))
		end
		local four = BossRules.buildInstanceData(100, "frost_giant", PartyConfig.maxMembers).skills.icefall
		local fourTotal = four.count + four.countPerMember * PartyConfig.maxMembers
		r.check(("2 스테이지별 낙석 개수 %s(기대 3 · 4 · 5 · 6) · 낙빙 %d인 스테이지 100: count %d + 인원 몫 %d × %d = %d개(기대 5 + 4 = 9 - 인원 몫은 그대로)"):format(
			table.concat(cells, " "), PartyConfig.maxMembers, four.count, four.countPerMember, PartyConfig.maxMembers, fourTotal), cellsOk and fourTotal == 9)
	end)

	r.section("[3] 대상 조건 · 아닌 스킬 불변", function()
		local flagged, eligible, mismatched, unchanged, checked = {}, {}, {}, true, 0
		local scale = BossRules.skillRangeScale(100)
		for _, bossId in ipairs(BossData.pools[1].bossIds) do
			local boss = BossData.bosses[bossId]
			local data = BossRules.buildInstanceData(100, bossId, 1)
			for id, skill in pairs(boss.skills) do
				local isFlagged, isEligible = skill.densityScalable == true, BossSkillMath.densityEligible(skill)
				if isFlagged then
					table.insert(flagged, bossId .. "." .. id)
				end
				if isEligible then
					table.insert(eligible, bossId .. "." .. id)
				end
				if isFlagged ~= isEligible then
					table.insert(mismatched, bossId .. "." .. id)
				end
				if not isFlagged and skill.count ~= nil then
					checked += 1
					local instance = data.skills[id]
					if instance.count ~= skill.count or (skill.scatterStuds and not near(instance.scatterStuds, skill.scatterStuds * scale, 1e-9)) then
						unchanged = false
					end
				end
			end
		end
		table.sort(flagged)
		table.sort(eligible)
		r.check(("3 플래그 목록(%d) = 조건 목록(%d) · 어긋남 %d건: 플래그 [%s] / 조건 [%s]"):format(
			#flagged, #eligible, #mismatched, table.concat(flagged, " "), table.concat(eligible, " ")), #mismatched == 0 and #flagged == 3)
		r.check(("3 대상 아닌 스킬(순차 · 기믹 · gate · 산개 0 - count를 가진 %d개)은 스테이지 100에서도 count 불변 · 산개는 범위 배율만: %s"):format(checked, tostring(unchanged)), unchanged and checked > 0)
	end)

	-- [4] 진짜 합격 기준 ① - 3스킬 × extra 0 ~ 3 × 범위 배율 2 × 인원 2 = 48칸, 칸당 10,000회. 칸마다 양보한다(서버 스레드 실행 시간 제한).
	r.section("[4] 검사기 48칸", function()
		local scales = { 1, BossRules.maxSkillRangeScale() }
		local parties = { 1, PartyConfig.maxMembers }
		local cells, failedCells, worstP99Margin, worstMaxMargin = 0, {}, math.huge, math.huge
		print(("[S14][가] 검사기 표(칸당 %d회 · seed %d): 스킬 | extra | 배율 | 인원 | 원 개수 | 산개 | p99 ≤ 전조 | 최대 ≤ 전조 + %.2f | (참고: 몸 반폭을 더한 p99 · 최대) | 판정"):format(
			TRIALS, CHECK_SEED, density.check.maxOverSeconds))
		for _, target in ipairs(TARGETS) do
			for extra = 0, density.maxExtra do
				for _, scale in ipairs(scales) do
					for _, party in ipairs(parties) do
						local result = BossSim.checkDensity(target[1], target[2], extra, TRIALS, CHECK_SEED + cells, { rangeScale = scale, partySize = party })
						cells += 1
						worstP99Margin = math.min(worstP99Margin, result.telegraphSeconds - result.p99)
						worstMaxMargin = math.min(worstMaxMargin, result.telegraphSeconds + density.check.maxOverSeconds - result.max)
						if not result.ok then
							table.insert(failedCells, ("%s.%s extra %d 배율 %.3f %d인"):format(target[1], target[2], extra, scale, party))
						end
						print(("[S14][가]   %s.%s | %d | %.3f | %d인 | %d개 | %.1fstud | %.3f ≤ %.2f | %.3f ≤ %.2f | (%.3f · %.3f) | %s"):format(
							target[1], target[2], extra, scale, party, result.count, result.scatterStuds, result.p99, result.telegraphSeconds,
							result.max, result.telegraphSeconds + density.check.maxOverSeconds, result.pBody, result.maxBody, result.ok and "O" or "X"))
						task.wait() -- 칸마다 양보 - 48칸 × 10,000회를 한 번에 돌리면 서버 스레드 실행 시간 제한에 걸린다
					end
				end
			end
		end
		r.check(("4 검사기 %d칸(3스킬 × extra 0 ~ %d × 배율 2 × 인원 2, 칸당 %d회) 전부 합격: 실패 %d칸%s · 가장 빠듯한 여유 p99 %.3f초 · 최대 %.3f초 ★진짜 합격 기준 ①"):format(
			cells, density.maxExtra, TRIALS, #failedCells, #failedCells > 0 and (" [" .. table.concat(failedCells, ", ") .. "]") or "", worstP99Margin, worstMaxMargin),
			cells == 48 and #failedCells == 0)
		-- 검사기가 밀도를 실제로 보는가(판별력): extra를 극단으로 키운 낙석은 extra 0보다 최댓값이 커져야 한다 - 안 커지면 48칸 통과가 아무것도 증명하지 못한다.
		local plain = BossSim.checkDensity(GUARDIAN, "meteor", 0, TRIALS, CHECK_SEED, { rangeScale = 1 })
		local crowded = BossSim.checkDensity(GUARDIAN, "meteor", 20, TRIALS, CHECK_SEED, { rangeScale = 1 })
		r.check(("4 판별력: 낙석 extra 0 → 원 %d개 p99 %.3f · 최대 %.3f / extra 20 → 원 %d개 p99 %.3f · 최대 %.3f (기대: 최대가 커진다 - 검사기가 원의 개수를 본다)"):format(
			plain.count, plain.p99, plain.max, crowded.count, crowded.p99, crowded.max), crowded.max > plain.max and crowded.count > plain.count)
	end)

	r.section("[5] 6종 몬테카를로", function()
		-- 29-5 (가)와 같은 조건(파훼 후 = 구간 수호자 같은 인원 평균 ±10% · 초회 = 파훼 후의 1.8 ~ 2.7배)을 extra 3으로 다시 돌린다. 모형(BossSim.run)은 원의 개수를 회피 비용에
		-- 반영하지 않으므로(evadeSecondsOf) extra 0과 같은 값이 나오는 것이 기대다 - 다른 값이 나오면 그 차이가 어디서 왔는지 봐야 한다.
		local ids = BossData.pools[1].bossIds
		local extra = density.maxExtra
		local base = {}
		for _, n in ipairs({ 1, 4 }) do
			base[n] = BossSim.monteCarlo(GUARDIAN, { partySize = n, breaks = "always", densityExtra = extra }, TUNING_RUNS).mean
		end
		local changed = {}
		for _, bossId in ipairs(ids) do
			if bossId ~= GUARDIAN then
				local cells, ok = {}, true
				for _, n in ipairs({ 1, 4 }) do
					local afterPlain = BossSim.monteCarlo(bossId, { partySize = n, breaks = "always" }, TUNING_RUNS)
					local after = BossSim.monteCarlo(bossId, { partySize = n, breaks = "always", densityExtra = extra }, TUNING_RUNS)
					local never = BossSim.monteCarlo(bossId, { partySize = n, breaks = "never", densityExtra = extra }, TUNING_RUNS)
					local delta, ratio = after.mean / base[n] - 1, never.mean / after.mean
					ok = ok and math.abs(delta) <= 0.10 and ratio >= 1.8 and ratio <= 2.7 and after.minGimmickCount >= 1
					if not near(after.mean, afterPlain.mean, 1e-9) then
						table.insert(changed, ("%s %d인 %.2f → %.2f"):format(bossId, n, afterPlain.mean, after.mean))
					end
					table.insert(cells, ("%d인 파훼 후 %.1f초(%+.1f%%) · 초회 %.1f초(x%.2f)"):format(n, after.mean, delta * 100, never.mean, ratio))
				end
				r.check(("5 %s(extra %d): %s"):format(bossId, extra, table.concat(cells, " | ")), ok)
			end
		end
		r.check(("5 extra 0 대비 평균이 달라진 칸: %d개%s - %s"):format(#changed, #changed > 0 and (" [" .. table.concat(changed, " · ") .. "]") or "",
			#changed == 0 and "모형은 밀도를 보지 않는다(원의 개수가 회피 비용에 안 들어간다 - 처치 시간 회귀 없음)" or "모형이 개수를 본 자리가 있다(낙빙 얼음 기둥 수)"), true)
	end)

	r.section("[6] 2연타 · 피해 몫 불변", function()
		local pairCount, violations, worst = 0, 0, 0
		for _, bossId in ipairs(BossData.pools[1].bossIds) do
			local rows, bad = BossSim.checkPairs(bossId)
			pairCount += #rows
			violations += bad
			for _, row in ipairs(rows) do
				if row.possible then
					worst = math.max(worst, row.share)
				end
			end
		end
		-- 밀도 스킬의 피해 몫(판정 한 번 = 배율 ÷ 생존 타수)은 원의 개수와 무관해야 한다 - 판정은 멤버당 한 번(break)이다.
		local sharesSame = true
		for _, target in ipairs(TARGETS) do
			local raw = BossData.bosses[target[1]].skills[target[2]]
			local denseSingle, denseTotal = BossSkillMath.damageShares(BossSkillMath.densifySkills(BossData.bosses[target[1]].skills, density.maxExtra)[target[2]], BalanceAnchorConfig.surviveTargetHits)
			local rawSingle, rawTotal = BossSkillMath.damageShares(raw, BalanceAnchorConfig.surviveTargetHits)
			sharesSame = sharesSame and denseSingle == rawSingle and denseTotal == rawTotal
		end
		r.check(("6 인접 쌍 %d개 중 100%% 이상인 가능한 쌍 %d건(최악 %.1f%%) · 밀도 3스킬의 피해 몫 extra %d = extra 0: %s"):format(
			pairCount, violations, worst * 100, density.maxExtra, tostring(sharesSame)), violations == 0 and worst < 1 and sharesSame)
	end)

	local pass, total = r.summary()
	print(("===S14 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnBoss(player, env, bossId, stage)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.setDebugForcedBoss(player, bossId)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

local function step(model, data, player, root, count)
	for _ = 1, count or 1 do
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
	end
end

local function runLive(player, env)
	print("===S14 검증 시작(나: 실제 스폰 · 낙석 배치 · 겹친 원 판정)===")
	local r = newRecorder("나")
	local function finish()
		local pass, total = r.summary()
		print(("===S14 검증 끝(나)=== %d/%d 통과"):format(pass, total))
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not PlayerProfile.getProfile(player) or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		return finish()
	end
	env.ensureBackup(player)

	-- 스테이지 100 보스의 기본 공격 · 스킬은 검증 캐릭터에게 치명적이다(공격력이 스테이지에 비례) - 피해 함수를 세는 스텁으로 바꿔 아무도 안 다치게 한다.
	-- 보스 스킬의 피해는 PlayerDamage.applyHit(player, attack, label, multiplier)로 들어온다(BossPatterns.applySkillDamage) - 그 호출 횟수가 곧 "피해 몇 번"이다.
	local originalApplyHit = PlayerDamage.applyHit
	local hitLog = {}
	PlayerDamage.applyHit = function(target, _, label)
		table.insert(hitLog, label)
		return 0
	end
	local function countHits(label)
		local count = 0
		for _, entry in ipairs(hitLog) do
			if entry == label then
				count += 1
			end
		end
		return count
	end

	local ok, err = pcall(function()
		local dense = BossData.mechanics.stageDensity
		local stage = dense.startStage + dense.stepStages * dense.maxExtra -- 100
		local model, data = spawnBoss(player, env, GUARDIAN, stage)
		if not model then
			r.check("스테이지 100 구간 수호자 스폰 실패", false)
			return
		end
		-- 캐릭터는 어그로 밖(60stud)에 둔다 - 가까우면 MonsterAI도 같은 보스를 step해 강제 시작이 흔들린다(29-3의 교훈).
		root.CFrame = CFrame.new(model.PrimaryPart.Position + Vector3.new(60, 1.5, 0))
		RunService.Heartbeat:Wait()
		local st = MonsterState.getBossPatternState(model)
		local skill = data.skills.meteor
		local rawSkill = BossData.bosses[GUARDIAN].skills.meteor

		r.section("[7] 스테이지 100 낙석 원 개수", function()
			local forced = BossPatterns.force(model, data, "meteor")
			step(model, data, player, root, 1) -- 강제 시작한 틱에는 추적이 안 돈다 - 시작은 이 step에서 일어나고 배치는 그때 정해진다
			local positions = st.meteorPositions or {}
			local zone = WorldConfig.zones[MonsterState.getZoneKey(model) or ""] or { center = MonsterState.getSpawnPosition(model), halfSize = WorldConfig.bossArena.halfSizeStuds }
			local outside = 0
			for _, position in ipairs(positions) do
				if math.abs(position.X - zone.center.X) > zone.halfSize or math.abs(position.Z - zone.center.Z) > zone.halfSize then
					outside += 1
				end
			end
			local phase = BossPatterns.getPhase(model)
			r.check(("7 스테이지 %d 구간 수호자 낙석 강제 시작(force=%s) 한 틱 뒤 phase=%s · 원 %d개(기대 6) · 아레나 밖 %d개(기대 0) · 인스턴스 count %d · 원본 count %d · 산개 %.1f(원본 %g × 배율 %.3f × √2)"):format(
				stage, tostring(forced), phase, #positions, outside, skill.count, rawSkill.count, skill.scatterStuds, rawSkill.scatterStuds, data.skillRangeScale),
				forced and phase == "meteorTelegraph" and #positions == 6 and outside == 0 and skill.count == 6 and rawSkill.count == 3)
		end)

		r.section("[8] 겹친 원 한 번만", function()
			BossPatterns.interrupt(model, data)
			BossPatterns.force(model, data, "meteor")
			step(model, data, player, root, 1)
			local first = st.meteorPositions and st.meteorPositions[1]
			if not first then
				r.check("8 낙석 시작 실패 - 원이 없다", false)
				return
			end
			-- 대상(검증 캐릭터)의 발밑 원 + 그 곁에 겹친 원 하나: 캐릭터는 두 원 모두에 든다. 판정은 멤버당 한 번(break)이라 피해는 1회여야 한다.
			hitLog = {}
			st.meteorPositions = { first, first + Vector3.new(1, 0, 0) }
			st.phaseEndsAt = os.clock()
			step(model, data, player, root, 1)
			local overlapped = countHits(skill.damageLabel)
			-- 대조: 원 하나만 있을 때도 1회(판정 경로가 실제로 돌았다는 증거 - 둘 다 0이면 아무것도 못 잰 것이다).
			hitLog = {}
			BossPatterns.interrupt(model, data)
			BossPatterns.force(model, data, "meteor")
			step(model, data, player, root, 1)
			st.meteorPositions = { st.meteorPositions[1] }
			st.phaseEndsAt = os.clock()
			step(model, data, player, root, 1)
			local single = countHits(skill.damageLabel)
			r.check(("8 겹친 원(캐릭터가 두 원 모두 안): 피해 %d회(기대 1) · 원 하나만: %d회(기대 1) ★진짜 합격 기준 ②"):format(overlapped, single), overlapped == 1 and single == 1)
		end)

		r.section("[9] 스테이지 25 · 견습", function()
			local _, atTwentyFive = spawnBoss(player, env, GUARDIAN, dense.startStage)
			local scale = BossRules.skillRangeScale(dense.startStage)
			local meteor25 = atTwentyFive and atTwentyFive.skills.meteor
			local tutorial = BossRules.buildTutorialInstanceData(1, 1, { "meteor" }, 1, 1)
			r.check(("9 스테이지 %d 보스(실제 스폰): 낙석 count %s(기대 3) · 산개 %s(기대 10 × 배율 %.3f = %.3f) · extra %s(기대 0) · 견습 보스: count %s(기대 3) · extra %s(기대 0)"):format(
				dense.startStage, tostring(meteor25 and meteor25.count), meteor25 and ("%.3f"):format(meteor25.scatterStuds) or "-", scale, 10 * scale, tostring(atTwentyFive and atTwentyFive.densityExtra),
				tostring(tutorial.skills.meteor and tutorial.skills.meteor.count), tostring(tutorial.densityExtra)),
				meteor25 ~= nil and meteor25.count == 3 and near(meteor25.scatterStuds, 10 * scale, 1e-9) and atTwentyFive.densityExtra == 0
					and tutorial.skills.meteor ~= nil and tutorial.skills.meteor.count == 3 and tutorial.densityExtra == 0)
		end)
	end)
	if not ok then
		r.check(("(나) 실행 중 에러: %s"):format(tostring(err)), false)
	end

	PlayerDamage.applyHit = originalApplyHit
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	r.check(("10 검증 뒤 encounter 없는 보스 모델 %d개(기대 0) · PlayerDamage.applyHit 원래 함수로 복원=%s"):format(orphans, tostring(PlayerDamage.applyHit == originalApplyHit)),
		orphans == 0 and PlayerDamage.applyHit == originalApplyHit)
	env.restore(player)
	finish()
end

BossDensityVerify.runPure = runPure
BossDensityVerify.runLive = runLive

return BossDensityVerify
