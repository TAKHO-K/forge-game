-- 29-2 자동 검증(PRD 20.75 F) - 쿨타임·우선순위 구동, 회피 부등식, 인접 피해 합, 처치 시간 몬테카를로, 보스별
-- 스킬표·범위 배율·아레나 kit 훅·견습 보스 고정. BossMechanicsVerify(29-1)와 같은 패턴이고 DevTools가 그 바로
-- 뒤에 이어서 부른다(둘이 같은 플레이어·같은 아레나를 쓰므로 동시에 돌면 안 된다).
--   (가) 순수 계산 - BossSim·BossScheduler·BossSkillMath. 로컬 Luau 하네스(실제 모듈 + 스텁)와 같은 값을 낸다.
--   (나) 실제 서버 경로 - 6종을 스폰해 스킬마다 force → step, 범위 배율, kit, 실시간 전역 쿨.
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local BossArenaKit = require(script.Parent.BossArenaKit)
local GroundProbe = require(script.Parent.GroundProbe)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local BossSkillVerify = {}

local GUARDIAN = "section_guardian"
local BOSS_IDS = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

-- 21-3부터의 스케줄러를 실제 BossPatterns 코드로 600초 돌린 기준선(29-2 세션 로컬 하네스, 가짜 시계)의 첫 다섯
-- 스킬. 새 구동의 모형이 같은 순서·같은 시각(±0.3초 - 모형은 0.05초 틱, 돌진 이동 시간은 가정값)을 내야 한다.
local GUARDIAN_BASELINE = {
	{ id = "heavy", at = 6.02 }, { id = "shockwave", at = 13.53 }, { id = "meteor", at = 29.63 },
	{ id = "heavy", at = 37.17 }, { id = "charge", at = 44.70 },
}
-- 결정 모형의 기대값(로컬 하네스와 같은 BossSim) - { live 솔로, live 4인, design 파훼 후 솔로, 4인, 파훼 전 솔로, 4인 }.
local EXPECTED_SECONDS = {
	frost_giant = { 73.40, 35.10, 73.40, 35.10, 197.95, 82.95 }, -- 29-3: 포효가 켜졌다(지금 = 설계). 첫 포효 16초·낙빙 선행
	abyssal_lord = { 77.30, 37.75, 77.75, 38.30, 200.35, 89.75 },
	crystal_queen = { 76.65, 37.80, 74.00, 36.10, 194.60, 83.80 },
	scorpion_queen = { 73.55, 34.70, 73.70, 35.45, 214.25, 83.70 },
	storm_lord = { 72.30, 36.00, 68.55, 34.20, 169.90, 73.85 },
}
local SIM_TOLERANCE_SECONDS = 0.06
local MONTE_CARLO_RUNS = 100
-- primitive → 스킬을 강제로 시작한 직후의 phase.
local FIRST_PHASE = {
	circleBoss = "heavyTelegraph", ring = "shockHop", circleTarget = "meteorTelegraph",
	charge = "focus", line = "crossTelegraph", gimmick = "gimmickTelegraph",
}

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
		print(("[29-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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
	print("===29-2 검증 시작(가: 구동·회피 부등식·인접 피해·처치 시간)===")
	local r = newRecorder("가")

	-- [F-3] 구간 수호자가 새 구동에서 기존 시퀀스를 그대로 재현하는가
	r.section("기본형 회귀", function()
		local solo = BossSim.run(GUARDIAN, { partySize = 1 })
		local party = BossSim.run(GUARDIAN, { partySize = 4 })
		local parts, same = {}, true
		for index, expected in ipairs(GUARDIAN_BASELINE) do
			local actual = solo.sequence[index]
			same = same and actual ~= nil and actual.id == expected.id and near(actual.at, expected.at, 0.3)
			table.insert(parts, ("%s@%.2f(기준 %s@%.2f)"):format(actual and actual.id or "-", actual and actual.at or -1, expected.id, expected.at))
		end
		r.check("구간 수호자 시퀀스: " .. table.concat(parts, " "), same)
		r.check(("구간 수호자 처치 시간: 솔로 %.2f초(29-1과 같은 73.30) / 4인 %.2f초(37.85), 우선순위 전부 같음 → 가장 오래 기다린 것부터"):format(solo.seconds, party.seconds),
			near(solo.seconds, 73.30, SIM_TOLERANCE_SECONDS) and near(party.seconds, 37.85, SIM_TOLERANCE_SECONDS))
	end)

	-- [F-4][F-5] 전역 쿨·굶주림 - 600초 고정 실행
	r.section("전역 쿨·굶주림", function()
		for _, bossId in ipairs(BOSS_IDS) do
			local boss = BossData.bosses[bossId]
			local always = BossSim.run(bossId, { design = true, fixedSeconds = 600, hpRatio = 0.5, breaks = "always" })
			local never = BossSim.run(bossId, { design = true, fixedSeconds = 600, hpRatio = 0.5, breaks = "never" })
			local parts, starved = {}, false
			for _, id in ipairs(boss.skillOrder) do
				local count = math.max(always.counts[id] or 0, never.counts[id] or 0)
				local wait = math.min(always.maxWaitSeconds[id] or math.huge, never.maxWaitSeconds[id] or math.huge)
				starved = starved or count == 0
				table.insert(parts, ("%s %d/%d회(최장 %.0f초)"):format(id, always.counts[id] or 0, never.counts[id] or 0, wait))
			end
			local gcd = boss.scheduler.globalCooldownSeconds
			r.check(("%s 600초(파훼/미파훼): %s | 최소 간격 %.2f초(전역 쿨 %d)"):format(bossId, table.concat(parts, " · "), always.minGapSeconds, gcd),
				not starved and always.minGapSeconds >= gcd - 1e-6 and never.minGapSeconds >= gcd - 1e-6)
		end
		local enraged = BossSim.run(GUARDIAN, { partySize = 1 })
		r.check(("격노 구간 포함 최소 간격 %.2f초 ≥ 격노 전역 쿨 %.1f초"):format(enraged.minGapSeconds, BossData.bosses[GUARDIAN].scheduler.enragedGlobalCooldownSeconds),
			enraged.minGapSeconds >= BossData.bosses[GUARDIAN].scheduler.enragedGlobalCooldownSeconds - 1e-6)
	end)

	-- [F-6] 회피 부등식 - 범위 배율 1(스테이지 5)과 최대(스테이지 25+), 속도는 신발 없는 기본 걷기
	r.section("회피 부등식", function()
		local maxScale = BossRules.maxSkillRangeScale()
		r.check(("범위 배율: 스테이지 5 = %.3f, 15 = %.3f, 25 = %.3f, 1000 = %.3f(상한 %.3f), 견습 1 = %.3f"):format(
			BossRules.skillRangeScale(5), BossRules.skillRangeScale(15), BossRules.skillRangeScale(25), BossRules.skillRangeScale(1000), maxScale, BossRules.skillRangeScale(1)),
			BossRules.skillRangeScale(5) == 1 and BossRules.skillRangeScale(1) == 1 and near(maxScale, 1.152, 0.001)
				and BossRules.skillRangeScale(1000) == maxScale and BossRules.skillRangeScale(15) > 1 and BossRules.skillRangeScale(15) < maxScale)
		print(("[29-2][가] 보스 | 스킬 | 판정 | 회피 거리 | 필요 ≤ 전조(배율 1.00) | 필요 ≤ 전조(배율 %.3f) - 속도 %dstud/s, 인지 %.2f초, 여유 x%.2f"):format(
			maxScale, WorldConfig.playerWalkSpeedStuds, BossData.mechanics.dodge.perceptionSeconds, BossData.mechanics.dodge.marginFactor))
		for _, bossId in ipairs(BOSS_IDS) do
			local baseRows, baseOk = BossSim.checkDodge(bossId, 1)
			local maxRows, maxOk = BossSim.checkDodge(bossId, maxScale)
			for index, row in ipairs(baseRows) do
				local wide = maxRows[index]
				print(("[29-2][가]   %s | %s | %s | %.1f → %.1fstud | %.2f ≤ %.2f %s | %.2f ≤ %.2f %s"):format(
					bossId, row.skillId, row.label, row.distanceStuds, wide.distanceStuds,
					row.requiredSeconds, row.availableSeconds, row.ok and "O" or "X",
					wide.requiredSeconds, wide.availableSeconds, wide.ok and "O" or "X"))
			end
			r.check(("%s 회피 부등식: 배율 1.00 %s · 최대 배율 %s (%d판정)"):format(bossId, baseOk and "통과" or "실패", maxOk and "통과" or "실패", #baseRows), baseOk and maxOk)
		end
	end)

	-- [F-7] 2연타 합계 - 인접 가능한 쌍 전수 + 600초 실행에서 실제로 나온 최악 인접
	r.section("인접 피해 합", function()
		for _, bossId in ipairs(BOSS_IDS) do
			local rows, violations = BossSim.checkPairs(bossId)
			local top, blocked = nil, {}
			for _, row in ipairs(rows) do
				if row.possible and not top then
					top = row
				elseif not row.possible and row.share >= 1 then
					table.insert(blocked, ("%s→%s %.0f%%"):format(row.first, row.second, row.share * 100))
				end
			end
			local observed = BossSim.run(bossId, { design = true, fixedSeconds = 600, hpRatio = 0.5, breaks = "never" })
			r.check(("%s: %d쌍 중 위반 %d, 가능한 최악 %s→%s %.1f%%, 600초 실측 최악 %s %.1f%%, 데이터로 막힌 쌍 [%s]"):format(
				bossId, #rows, violations, top.first, top.second, top.share * 100,
				tostring(observed.worstAdjacentPair), observed.worstAdjacentShare * 100, table.concat(blocked, ", ")),
				violations == 0 and observed.worstAdjacentShare < 1)
		end
	end)

	-- [F-8][F-9] 처치 시간 - 결정 모형(로컬 하네스와 대조) + 몬테카를로
	r.section("처치 시간", function()
		for _, bossId in ipairs(BOSS_IDS) do
			if bossId ~= GUARDIAN then
				local expected = EXPECTED_SECONDS[bossId]
				local values = {
					BossSim.run(bossId, { partySize = 1 }).seconds,
					BossSim.run(bossId, { partySize = 4 }).seconds,
					BossSim.run(bossId, { partySize = 1, design = true, breaks = "always" }).seconds,
					BossSim.run(bossId, { partySize = 4, design = true, breaks = "always" }).seconds,
					BossSim.run(bossId, { partySize = 1, design = true, breaks = "never" }).seconds,
					BossSim.run(bossId, { partySize = 4, design = true, breaks = "never" }).seconds,
				}
				local matches = true
				for index, value in ipairs(values) do
					matches = matches and near(value, expected[index], SIM_TOLERANCE_SECONDS)
				end
				r.check(("%s 결정 모형: 지금 %.2f/%.2f · 설계 파훼 후 %.2f/%.2f · 파훼 전 %.2f/%.2f (솔로/4인) - 로컬 하네스와 일치"):format(
					bossId, values[1], values[2], values[3], values[4], values[5], values[6]), matches)
			end
		end
		task.wait()

		print(("[29-2][가] 몬테카를로 %d회: 보스 | 인원 | 파훼 후 평균(p5~p95, 기준 대비) | 파훼 전 평균(배수) | 첫 기믹 최늦 | 최소 기믹 횟수"):format(MONTE_CARLO_RUNS))
		local reference, ratioSum, ratioCount = {}, 0, 0
		for _, n in ipairs({ 1, PartyConfig.maxMembers }) do
			reference[n] = BossSim.monteCarlo(GUARDIAN, { partySize = n }, MONTE_CARLO_RUNS).mean
			task.wait()
		end
		for _, bossId in ipairs(BOSS_IDS) do
			local afterBySize = {}
			for _, n in ipairs({ 1, PartyConfig.maxMembers }) do
				local live = BossSim.monteCarlo(bossId, { partySize = n }, MONTE_CARLO_RUNS)
				task.wait()
				local after = BossSim.monteCarlo(bossId, { partySize = n, design = true, breaks = "always" }, MONTE_CARLO_RUNS)
				task.wait()
				local never = BossSim.monteCarlo(bossId, { partySize = n, design = true, breaks = "never" }, MONTE_CARLO_RUNS)
				task.wait()
				afterBySize[n] = after.mean
				local hasGimmick = bossId ~= GUARDIAN
				local inBand = math.abs(after.mean / reference[n] - 1) <= 0.10 and math.abs(live.mean / reference[n] - 1) <= 0.10
				local gated = not hasGimmick or never.mean / after.mean >= 2
				-- 첫 기믹 = 자리 비우기(reserveFirstUse)를 건 스킬의 첫 발동 시각(서리 거인 16 · 폭풍 군주 8 · 나머지 10).
				local firstExpected = 0
				for _, id in ipairs(BossData.bosses[bossId].skillOrder) do
					local skill = BossData.bosses[bossId].skills[id]
					if skill.reserveFirstUse then
						firstExpected = math.max(firstExpected, skill.firstAvailableSeconds)
					end
				end
				local firstOk = not hasGimmick or (after.latestFirstGimmickAt <= firstExpected + 0.06 and after.minGimmickCount >= 1)
				r.check(("%s | %d인 | 지금 %.1f(%+.1f%%) · 파훼 후 %.1f(%.1f~%.1f, %+.1f%%) | 파훼 전 %.1f(x%.2f) | %.2f초 | %d회"):format(
					bossId, n, live.mean, (live.mean / reference[n] - 1) * 100, after.mean, after.p5, after.p95, (after.mean / reference[n] - 1) * 100,
					never.mean, never.mean / after.mean, after.latestFirstGimmickAt, after.minGimmickCount),
					inBand and gated and firstOk)
			end
			if bossId ~= GUARDIAN then
				ratioSum += afterBySize[PartyConfig.maxMembers] / afterBySize[1]
				ratioCount += 1
			end
		end
		local target = PartyConfig.maxMembers ^ (BossRules.partyHpExponent() - 1)
		r.check(("p 전제: T_4/T_1 평균 %.3f (목표 %.3f, 허용 +-0.03)"):format(ratioSum / ratioCount, target), near(ratioSum / ratioCount, target, 0.03))
	end)

	-- [F-10] 어그로·리쉬·기본 공격 규칙 - 데이터 검사
	r.section("규칙 위반", function()
		local violations = {}
		for _, bossId in ipairs(BOSS_IDS) do
			local boss = BossData.bosses[bossId]
			local basic = boss.basicAttack
			if boss.moveSpeedStuds >= WorldConfig.playerWalkSpeedStuds then
				table.insert(violations, bossId .. ": 추격 속도가 플레이어 걷기 이상(걸어서 못 벗어난다)")
			end
			if basic.rangeStuds > WorldConfig.aggro.rangeStuds then
				table.insert(violations, bossId .. ": 기본 공격 사거리가 어그로 범위보다 길다(어그로 전에 맞는다)")
			end
			if boss.chaseStopDistanceStuds >= basic.rangeStuds then
				table.insert(violations, bossId .. ": 멈추는 거리가 사거리 이상(평타가 안 닿는다)")
			end
			if math.abs(basic.damageMultiplier / basic.cooldownSeconds - 1) > 1e-6 then
				table.insert(violations, bossId .. ": 기본 공격 주기 × 배율이 보존되지 않는다")
			end
			if boss.scheduler.globalCooldownSeconds < boss.scheduler.enragedGlobalCooldownSeconds then
				table.insert(violations, bossId .. ": 전역 쿨이 격노 하한보다 짧다")
			end
			local signatures = 0
			for _, id in ipairs(boss.skillOrder) do
				signatures += (boss.skills[id].role == "signature") and 1 or 0
			end
			if bossId ~= GUARDIAN and signatures ~= 1 then
				table.insert(violations, bossId .. ": 시그니처 스킬이 정확히 하나가 아니다")
			end
		end
		r.check(("어그로 %.1f / 리쉬 %.1f / 걷기 %d 기준 규칙 위반 %d건 %s"):format(
			WorldConfig.aggro.rangeStuds, WorldConfig.aggro.leashRangeStuds, WorldConfig.playerWalkSpeedStuds, #violations, table.concat(violations, "; ")),
			#violations == 0)
	end)

	local passCount, totalCount = r.summary()
	print(("===29-2 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ─────────────────────────── (나) 실제 서버 경로 ───────────────────────────

local function spawnBoss(player, env, bossId, stage)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	-- 같은 스테이지에 이미 확정된 보스(pending)가 있으면 getBossForStage는 강제 지정보다 그것을 먼저 돌려준다(23-5 -
	-- 재도전 때 보스가 바뀌지 않게). 검증은 매번 다른 보스를 불러야 하므로 pending부터 지운다(29-2 첫 Play의 교훈).
	PlayerProfile.clearBossRotationPending(player)
	PlayerProfile.forceBossRotationNext(player, bossId)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

local function runLive(player, env)
	print("===29-2 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 준비 실패 - (나) 전체 건너뜀", false)
		env.restore(player)
		local passCount, totalCount = r.summary()
		print(("===29-2 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
		return
	end
	local firstStage = BossData.stageInterval

	-- [F-3] 기본형 인스턴스 + 스테이지 범위 배율
	r.section("기본형·범위 배율", function()
		local source = BossData.bosses[GUARDIAN]
		local model, data = spawnBoss(player, env, GUARDIAN, firstStage)
		local clocks = BossPatterns.debugClocks(model)
		r.check(("구간 수호자(스테이지 %d): 스킬표가 BossData 원본 그대로=%s, 시계 6/11/13/15/17 = %.1f/%.1f/%.1f/%.1f/%.1f, 전역 쿨 %d, 평타 %.2f초 x%.2f 사거리 %d"):format(
			firstStage, tostring(data.skills == source.skills), clocks.heavy or -1, clocks.shockwave or -1, clocks.meteor or -1, clocks.charge or -1, clocks.cross or -1,
			data.scheduler.globalCooldownSeconds, data.attackCooldownSeconds, data.basicAttackDamageMultiplier, data.attackRangeStuds),
			data.skills == source.skills and data.skillRangeScale == 1
				and near(clocks.heavy, 6, 0.5) and near(clocks.shockwave, 11, 0.5) and near(clocks.meteor, 13, 0.5) and near(clocks.charge, 15, 0.5) and near(clocks.cross, 17, 0.5)
				and data.attackCooldownSeconds == 1 and data.basicAttackDamageMultiplier == 1 and data.attackRangeStuds == 14)
		local farStage = firstStage * 5
		local _, wide = spawnBoss(player, env, GUARDIAN, farStage)
		local scale = BossRules.skillRangeScale(farStage)
		r.check(("구간 수호자(스테이지 %d): 범위 배율 %.3f → 강공격 반경 %.2f(원본 %d 그대로=%s), 돌진 반폭 %.2f, 예고·쿨 그대로=%s"):format(
			farStage, scale, wide.skills.heavy.radiusStuds, source.skills.heavy.radiusStuds, tostring(source.skills.heavy.radiusStuds == 14),
			wide.skills.charge.pathHalfWidthStuds, tostring(wide.skills.heavy.telegraphSeconds == 1.5 and wide.skills.heavy.cooldownSeconds == 6)),
			near(wide.skills.heavy.radiusStuds, 14 * scale, 1e-6) and source.skills.heavy.radiusStuds == 14
				and near(wide.skills.charge.pathHalfWidthStuds, 4 * scale, 1e-6) and wide.skills.heavy.telegraphSeconds == 1.5 and wide.skills.heavy.cooldownSeconds == 6)
	end)

	-- 6종의 켜진 스킬 전부: 강제 시작 → 한 틱 → 그 프리미티브의 첫 phase, 에러 없음
	r.section("6종 스킬 시작", function()
		for _, bossId in ipairs(BOSS_IDS) do
			local source = BossData.bosses[bossId]
			for _, id in ipairs(source.skillOrder) do
				local skill = source.skills[id]
				if skill.enabled ~= false then
					local model, data = spawnBoss(player, env, bossId, firstStage)
					local forced = BossPatterns.force(model, data, id)
					local ok, err = pcall(function()
						BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
					end)
					local phase = BossPatterns.getPhase(model)
					r.check(("%s.%s(%s): force=%s phase=%s(기대 %s) 에러=%s"):format(bossId, id, skill.primitive, tostring(forced), phase, FIRST_PHASE[skill.primitive], ok and "없음" or tostring(err)),
						forced and ok and phase == FIRST_PHASE[skill.primitive])
				else
					local _, data = spawnBoss(player, env, bossId, firstStage)
					local clocks = BossPatterns.debugClocks(BossEncounter.getActive(player))
					r.check(("%s.%s(설계만, enabled=false): 시계 없음=%s, 인스턴스에 데이터는 있음=%s"):format(bossId, id, tostring(clocks[id] == nil), tostring(data.skills[id] ~= nil)),
						clocks[id] == nil and data.skills[id] ~= nil)
				end
			end
		end
	end)

	-- 견습 보스 고정·순환 첫 자리·kit 훅
	r.section("견습·순환·kit", function()
		local tutorial = BossRules.buildTutorialInstanceData(1, 1, { "shockwave" }, 1, 1)
		local keys = {}
		for id in pairs(tutorial.skills) do
			table.insert(keys, id)
		end
		table.sort(keys)
		r.check(("견습 보스 = %s(고정), 스킬 부분집합 = [%s]"):format(tutorial.id, table.concat(keys, ",")),
			tutorial.id == BossData.tutorialBossId and #keys == 2 and keys[1] == "heavy" and keys[2] == "shockwave")
		local allFirst = true
		for _ = 1, 30 do
			allFirst = allFirst and BossRules.nextRotationBossId({ index = 1 }) == BossData.tutorialBossId
		end
		local second = { order = { "a", "b", GUARDIAN }, index = 4 }
		local secondId = BossRules.nextRotationBossId(second)
		r.check(("새 순환의 첫 보스 30회 전부 %s=%s, 두 번째 바퀴 첫 보스 %s(직전 마지막과 다름=%s)"):format(
			BossData.tutorialBossId, tostring(allFirst), tostring(secondId), tostring(secondId ~= GUARDIAN)), allFirst and secondId ~= GUARDIAN)

		local zone = WorldConfig.zones.bossArena1
		local kit = { parts = {
			{ name = "VerifyKitGround", size = Vector3.new(4, 1, 4), offset = Vector3.new(20, 0.5, 20), color = Color3.fromRGB(40, 20, 20), ground = true },
			{ name = "VerifyKitDecor", size = Vector3.new(2, 6, 2), offset = Vector3.new(-20, 3, 20), color = Color3.fromRGB(40, 20, 20), collide = false },
		} }
		local built = BossArenaKit.build(kit, zone, 1)
		local groundParent = built[1] and built[1].Parent
		BossArenaKit.destroy(built)
		r.check(("아레나 kit 훅: 지은 파트 %d(지면 폴더=%s), 치운 뒤 남은 것=%s, kit 없는 보스 = 파트 %d"):format(
			#built, tostring(groundParent == GroundProbe.folder()), tostring(built[1].Parent ~= nil or built[2].Parent ~= nil), #BossArenaKit.build(nil, zone, 1)),
			#built == 2 and groundParent == GroundProbe.folder() and built[1].Parent == nil and built[2].Parent == nil and #BossArenaKit.build(nil, zone, 1) == 0)
	end)

	-- [F-4] 실시간 전역 쿨 - 가장 바쁜 보스(폭풍 군주, 전역 쿨 5초)를 실제 시계로 돌려 "끝 → 다음 시작" 간격을 잰다.
	-- 시계가 어그로로 다시 시작돼도 간격 측정에는 영향이 없다(간격은 직전 스킬의 끝을 기준으로 한다).
	r.section("실시간 전역 쿨", function()
		local model, data = spawnBoss(player, env, "storm_lord", firstStage)
		local gcd = data.scheduler.globalCooldownSeconds
		local startedAt = os.clock()
		local lastCurrent, lastEndAt, minGap, starts = nil, nil, math.huge, {}
		local stepSeconds, stepCount = 0, 0
		while os.clock() - startedAt < 32 and #starts < 4 do
			RunService.Heartbeat:Wait()
			-- 검증 중인 캐릭터는 스킬을 피하지 않는다 - 맞아 죽어 보스가 리셋되지 않게 매 틱 채운다.
			PlayerState.setHp(player, PlayerState.getMaxHp(player))
			local before = os.clock()
			BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
			stepSeconds += os.clock() - before
			stepCount += 1
			local _, clockStartedAt, current = BossPatterns.debugClocks(model)
			if current ~= lastCurrent then
				local now = os.clock()
				if current then
					table.insert(starts, ("%s@+%.1f"):format(current, now - clockStartedAt))
					if lastEndAt then
						minGap = math.min(minGap, now - lastEndAt)
					end
				else
					lastEndAt = now
				end
				lastCurrent = current
			end
		end
		r.check(("폭풍 군주 실시간: %s | 끝 → 다음 시작 최소 %.2f초 ≥ 전역 쿨 %d초, 첫 스킬 = 시그니처 낙뢰(자리 비우기 8초)=%s"):format(
			table.concat(starts, " "), minGap, gcd, tostring(starts[1] and starts[1]:match("^strike@%+8") ~= nil)),
			#starts >= 3 and minGap >= gcd - 0.05 and starts[1] ~= nil and starts[1]:match("^strike@%+[78]") ~= nil)
		local perStep = stepSeconds / math.max(stepCount, 1)
		print(("[29-2][나] 성능: BossPatterns.step 평균 %.1f마이크로초/틱(%d틱) → 보스전 12개 x 60Hz = 초당 %.2fms (29-1 실측 28.6마이크로초)"):format(
			perStep * 1e6, stepCount, perStep * 12 * 60 * 1000))
		r.check("성능: step 평균 < 100마이크로초", perStep < 100e-6)
	end)

	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===29-2 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

function BossSkillVerify.runPure()
	runPure()
end

function BossSkillVerify.runLive(player, env)
	runLive(player, env)
end

return BossSkillVerify
