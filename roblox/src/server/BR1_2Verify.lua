-- BR1-2 자동 검증(docs/design/boss-br1-2.md). (가) = 서버 시작 때 순수 계산(Play 없이도 로컬 하네스로 돈다).
--   (가) 난이도 곡선 표 검사: 표본 스테이지(BossCurveData.sampleStages) × 6종 × 인원 1 · 4 - 투사체 인당 개수 · 반경 · 장판 범위 · 장판 개수 · 연쇄 칸이
--        앞 표본보다 줄지 않는가 · 인당 8 초과 없음 · 회피 부등식(전조 맞춤 뒤) 통과.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local BR1_2Verify = {}

local ALL_BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[BR1-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-2][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end

-- 스킬 하나의 "크기" 지표(줄면 안 되는 것)
local function metrics(skill)
	local m = {}
	if skill.primitive == "projectile" then
		m.count = skill.count
		m.radius = skill.radiusStuds
	else
		m.radius = skill.radiusStuds or 0
		m.halfWidth = skill.halfWidthStuds or skill.pathHalfWidthStuds or 0
		m.scatter = skill.scatterStuds or 0
		if skill.densityScalable then
			m.count = skill.count
		end
		if skill.chain then
			m.chain = skill.chain.count
		end
	end
	return m
end

function BR1_2Verify.curveCheck(r)
	local stages = BossCurveData.sampleStages
	for _, bossId in ipairs(ALL_BOSSES) do
		for _, party in ipairs({ 1, 4 }) do
			local prev = nil
			local shrinks, overCap, dodgeFails, fittedTotal = {}, {}, {}, 0
			for _, stage in ipairs(stages) do
				local data = BossRules.buildInstanceData(stage, bossId, party)
				local now = {}
				for id, skill in pairs(data.skills) do
					now[id] = metrics(skill)
					if skill.primitive == "projectile" and skill.count > BossCurveData.perPersonMax then
						table.insert(overCap, ("%s@%d=%d"):format(id, stage, skill.count))
					end
					if skill.primitive ~= "gimmick" then
						for _, ch in ipairs(BossSkillMath.dodgeChecks(skill, 8, WorldConfig.playerWalkSpeedStuds)) do
							if not ch.ok and ch.distanceStuds > 0 then
								table.insert(dodgeFails, ("%s@%d %s(%.2f<%.2f)"):format(id, stage, ch.label, ch.availableSeconds, ch.requiredSeconds))
							end
						end
					end
					if prev and prev[id] then
						for key, value in pairs(now[id]) do
							if prev[id][key] and value < prev[id][key] - 1e-9 then
								table.insert(shrinks, ("%s.%s@%d %.2f<%.2f"):format(id, key, stage, value, prev[id][key]))
							end
						end
					end
				end
				prev = now
			end
			r.check(("곡선 %s %d인: 표본 %d개 - 줄어듦 %d · 인당 8 초과 %d · 회피 실패 %d%s"):format(bossId, party, #stages, #shrinks, #overCap, #dodgeFails,
				(#shrinks + #overCap + #dodgeFails) > 0 and (" " .. table.concat(shrinks, " / ") .. table.concat(overCap, " / ") .. table.concat(dodgeFails, " / ")) or ""),
				#shrinks == 0 and #overCap == 0 and #dodgeFails == 0)
		end
	end
end

-- 표본 스테이지마다 단계 · 스킬별 인당 투사체 · 전조를 늘린 스킬(보고서 표).
function BR1_2Verify.curveTable(r)
	for _, stage in ipairs(BossCurveData.sampleStages) do
		local row = BossSkillMath.curveRow(stage)
		local cells, fitted = {}, {}
		for _, bossId in ipairs(ALL_BOSSES) do
			local boss = BossData.bosses[bossId]
			local skills, fit = BossSkillMath.applyCurve(BossSkillMath.scaleSkills(boss.skills, BossRules.skillRangeScale(stage)), row, row.zoneExtra, WorldConfig.playerWalkSpeedStuds)
			for _, id in ipairs(boss.skillOrder) do
				local skill = skills[id]
				if skill and skill.primitive == "projectile" then
					table.insert(cells, ("%s %d(r%.1f)"):format(id, skill.count, skill.radiusStuds))
				end
				if fit[id] then
					table.insert(fitted, ("%s.%s +%.2f"):format(bossId, id, fit[id]))
				end
			end
		end
		r.note(("표본 %d: 단계 %d · 장판 ×%.2f(이속 보정 ×%.3f) · 개수 %+d · 연쇄 %+d | 인당 투사체 %s | 전조 늘림 %s"):format(stage, row.tier, row.zoneRangeScale,
			BossRules.skillRangeScale(stage), row.zoneExtra, row.chainExtra, table.concat(cells, " "), #fitted > 0 and table.concat(fitted, " ") or "없음"))
	end
end

-- 초반 보호(스테이지 1 ~ 30 - CombatConfig.newbieProtection): 1 = atStage1 · plateau = atPlateau · 오르막만 · 30 < 1 · 31 = 1 · 첫 보스 6종(5 ~ 30) 모두 보호 안.
function BR1_2Verify.protectionCheck(r)
	local p = CombatConfig.newbieProtection
	local cells, monotone, prev = {}, true, 0
	for stage = 1, 32 do
		local m = PlayerCombat.getNewbieDamageMultiplier(stage)
		if m < prev - 1e-12 then
			monotone = false
		end
		prev = m
		if stage == 1 or stage % 5 == 0 or stage == 24 or stage == 27 or stage == 31 then
			table.insert(cells, ("%d ×%.3f"):format(stage, m))
		end
	end
	local m1, mP, m30, m31 = PlayerCombat.getNewbieDamageMultiplier(1), PlayerCombat.getNewbieDamageMultiplier(p.plateauStage), PlayerCombat.getNewbieDamageMultiplier(30), PlayerCombat.getNewbieDamageMultiplier(31)
	r.check(("초반 보호 1 ~ %d: %s · 오르막 %s · nil → %s"):format(p.untilStage, table.concat(cells, " · "), tostring(monotone), tostring(PlayerCombat.getNewbieDamageMultiplier(nil))),
		monotone and math.abs(m1 - p.atStage1) < 1e-9 and math.abs(mP - p.atPlateau) < 1e-9 and m30 < 1 and m31 == 1 and PlayerCombat.getNewbieDamageMultiplier(nil) == 1)
end

-- 지진파 무작위 리듬(구간 수호자 진동파 randomRhythm): 가능한 모든 순서(3 · 4 · 5박 · 두 종류 · 같은 종류 3연속 없음)가 회피 부등식을 통과하는가 + 굴린 1,000번의 분포.
function BR1_2Verify.quakeCheck(r)
	local skill = BossData.bosses.section_guardian.skills.shockwave
	local spec = skill.randomRhythm
	local sequences, fails = 0, {}
	local function walk(types, count)
		if #types == count then
			local hasAir, hasGround, run, ok = false, false, 0, true
			for i, t in ipairs(types) do
				hasAir = hasAir or t == "air"
				hasGround = hasGround or t == "ground"
				run = (i > 1 and t == types[i - 1]) and run + 1 or 1
				ok = ok and run <= spec.maxSameInRow
			end
			if ok and hasAir and hasGround then
				sequences += 1
				for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
					local copy = table.clone(BossSkillMath.scaleSkills({ s = skill }, scale).s)
					copy.rhythm = BossSkillMath.rollRhythm(copy, nil, types)
					for _, ch in ipairs(BossSkillMath.dodgeChecks(copy, 8, WorldConfig.playerWalkSpeedStuds)) do
						if not ch.ok then
							table.insert(fails, table.concat(types, "-") .. " " .. ch.label)
						end
					end
				end
			end
			return
		end
		for _, t in ipairs({ "ground", "air" }) do
			local nextTypes = table.clone(types)
			table.insert(nextTypes, t)
			walk(nextTypes, count)
		end
	end
	for _, count in ipairs(spec.counts) do
		walk({}, count)
	end
	local seed = 12345
	local function rng()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local byCount = {}
	for _ = 1, 1000 do
		local rhythm = BossSkillMath.rollRhythm(skill, rng)
		byCount[#rhythm] = (byCount[#rhythm] or 0) + 1
	end
	r.check(("지진파 무작위: 가능한 순서 %d가지 × 범위 배율 1 · 최대 - 회피 실패 %d%s · 굴림 1,000번 3박 %d · 4박 %d · 5박 %d"):format(sequences, #fails,
		#fails > 0 and (" " .. table.concat(fails, " / ")) or "", byCount[3] or 0, byCount[4] or 0, byCount[5] or 0), #fails == 0 and sequences > 0 and (byCount[3] or 0) > 0 and (byCount[5] or 0) > 0)
end

-- 수정 부수기 점프맵(BossJumpMapData): 코스마다 완주 가능(단계마다 가장 약한 기술 조합의 최대 간격 × safety 안 · 대시 간격 · 어려운 단계 수 · 발판 폭 · 마지막 = 수정) + 8방위 자리 배치.
function BR1_2Verify.jumpCourseCheck(r)
	local BossJumpMapData = require(ReplicatedStorage.Shared.data.BossJumpMapData)
	local BossJumpCourseMath = require(ReplicatedStorage.Shared.BossJumpCourseMath)
	for _, course in ipairs(BossJumpMapData.courses) do
		local ok, problems, combos, hard = BossJumpCourseMath.validate(course)
		local labels = {}
		for i = 2, #course.steps do
			table.insert(labels, combos[i] and combos[i].label or "X")
		end
		local placed = 0
		for k = 0, 7 do
			if BossJumpCourseMath.place(course, k * math.pi / 4, Vector3.new(0, 0, 0), 0, 140) then
				placed += 1
			end
		end
		local layout = BossJumpCourseMath.layout(course)
		r.check(("점프맵 %s: 완주 %s · 어려운 단계 %d(≥ %d) · 꼭대기 %.0f · 8방위 배치 %d/8 · %s%s"):format(course.name, tostring(ok), hard, BossJumpMapData.minHardSteps, layout[#layout].position.Y, placed,
			table.concat(labels, " / "), #problems > 0 and (" | " .. table.concat(problems, " | ")) or ""), ok and placed == 8)
	end
end

function BR1_2Verify.runPure()
	print("===BR1-2 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("초반 보호", function()
		BR1_2Verify.protectionCheck(r)
	end)
	r.section("지진파", function()
		BR1_2Verify.quakeCheck(r)
	end)
	r.section("점프맵", function()
		BR1_2Verify.jumpCourseCheck(r)
	end)
	r.section("곡선 표", function()
		BR1_2Verify.curveCheck(r)
		BR1_2Verify.curveTable(r)
	end)
	local pass, total = r.summary()
	print(("===BR1-2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

-- ─────────────────────────── (나) 실제 서버(보스 · 스탠드인 · 실제 판정 경로) ───────────────────────────
function BR1_2Verify.runLive(player, env)
	print("===BR1-2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local H = require(script.Parent.BR1Verify).helpers
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossArenaProps = require(script.Parent.BossArenaProps)
	local BossTrap = require(script.Parent.BossTrap)
	local BossHandlersBR1 = require(script.Parent.BossHandlersBR1)
	local BossAirGrab = require(script.Parent.BossAirGrab)
	local MonsterState = require(script.Parent.MonsterState)
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local SaveSystem = require(script.Parent.SaveSystem)
	local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
	local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
	local RunService = game:GetService("RunService")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local sent = {}
	local standIns = {}
	local rawSection = r.section
	r.section = function(name, fn)
		rawSection(name, fn)
		if root then
			root.Anchored = false
		end
		BossPatterns.debugSendHook = nil
		H.clearStandIns(player, standIns)
		PlayerState.clearIncomingDamageMultiplier(player)
		BossEncounter.despawnFor(player)
	end
	local function hook()
		table.clear(sent)
		BossPatterns.debugSendHook = function(kind, payload)
			table.insert(sent, { kind = kind, payload = payload })
		end
	end
	local function countKind(kind)
		local n = 0
		for _, e in ipairs(sent) do
			if e.kind == kind then
				n += 1
			end
		end
		return n
	end
	local function setup(bossId, stage, seed)
		local model, data, encounter = H.spawnBoss(player, env, bossId, seed, stage)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = true
		root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 3, 70))
		PlayerState.setIncomingDamageMultiplierUntil(player, 0, 600, "br12Verify") -- 개발 캐릭터는 대상일 뿐(죽지 않게)
		local st = MonsterState.getBossPatternState(model)
		st.graceUntil = os.clock() + 999 -- 기본 패턴은 멈춘다(강제한 것만)
		return model, data, zone, st
	end
	local function standIn(model, name, position)
		local fake, fakeRoot = H.newStandIn(model, name, position)
		table.insert(standIns, fake)
		return fake, fakeRoot
	end

	-- 1) 곡선 ④(스테이지 10000): 인당 8발 × 대상 4명(개발 + 스탠드인 3) = 32발 · 아레나 상한 안
	r.section("곡선 4단계 투사체", function()
		local model, data, zone = setup("section_guardian", 10000, 1201)
		for i = 1, 3 do
			local a = i / 3 * 2 * math.pi
			standIn(model, "C" .. i, zone.center + Vector3.new(math.cos(a) * 20, FLOOR + 3, math.sin(a) * 20))
		end
		hook()
		BossPatterns.force(model, data, "orbs")
		H.drive(player, root, model, data, data.skills.orbs.telegraphSeconds + data.skills.orbs.launchIntervalSeconds * 8 + 0.5)
		local spawns = countKind("projSpawn")
		r.check(("곡선 %d단계(스테이지 10000): orbs 인당 %d발 × 대상 4 = 투사체 %d(기대 32 · 아레나 상한 %d)"):format(data.curveTier, data.skills.orbs.count, spawns, BossCurveData.arenaProjectileCap),
			data.curveTier == 4 and data.skills.orbs.count == BossCurveData.perPersonMax and spawns == 32)
	end)

	-- 2) 성능 최악: 최대 단계 · 4인 · 동시 보스전 4개(서버 16명 = 4인 파티 4개) - 보스마다 투사체 스킬을 겹쳐 한 프레임 합을 잰다
	r.section("성능 최악", function()
		local model, data, zone = setup("storm_lord", 10000, 1202)
		local members = { player }
		for i = 1, 3 do
			local a = i / 3 * 2 * math.pi
			local fake = standIn(model, "P" .. i, zone.center + Vector3.new(math.cos(a) * 25, FLOOR + 3, math.sin(a) * 25))
			table.insert(members, fake)
		end
		-- 같은 아레나에 보스 3마리를 더(판정 · 투사체 계산은 보스마다 따로 - 서버 부하는 아레나가 달라도 같다)
		local models = { model }
		for i = 1, 3 do
			local extra = MonsterSpawner.spawn(data, zone.center + Vector3.new(i * 12 - 24, FLOOR + 1.5, -30), MonsterState.getZoneKey(model))
			table.insert(models, extra)
		end
		for _, m in ipairs(models) do
			BossPatterns.force(m, data, "tornado")
		end
		local costs, peakProjectiles = {}, 0
		local startedAt = os.clock()
		while os.clock() - startedAt < 5 do
			RunService.Heartbeat:Wait()
			local t0 = os.clock()
			local alive = 0
			for _, m in ipairs(models) do
				if m.Parent then
					BossPatterns.step(m, data, m.PrimaryPart.Position, player, root, 1 / 60, members)
					local s2 = MonsterState.getBossPatternState(m)
					alive += s2 and s2.projectiles and #s2.projectiles or 0
					if s2 and s2.phase == "normal" then
						BossPatterns.force(m, data, "boltSpear")
					end
				end
			end
			peakProjectiles = math.max(peakProjectiles, alive)
			table.insert(costs, os.clock() - t0)
		end
		local avg, peak = H.stats(costs)
		for i = 2, #models do
			MonsterSpawner.despawn(models[i])
		end
		BR1_2Verify.perf = { avg = avg, peak = peak, projectiles = peakProjectiles, bosses = #models, members = #members }
		r.check(("성능 최악(스테이지 10000 · 4인 · 보스 %d마리 동시): 투사체 최대 %d개 · 한 프레임 합 평균 %.0fμs · 최대 %.0fμs(허용 평균 ≤ 4000 · 최대 ≤ 16000 = 보스당 1000 · 4000 × 4)"):format(#models, peakProjectiles, avg, peak),
			avg <= 4000 and peak <= 16000 and peakProjectiles >= 64)
	end)

	-- 3) 반사: 반사 중 원거리 평타 → 되돌림 → 경로의 첫 사람(막은 동료)만 70% · 쏜 사람 무사
	r.section("반사", function()
		local model, data, zone, st = setup("frost_giant", BossData.stageInterval, 1203)
		local c = zone.center
		model:PivotTo(CFrame.new(c + Vector3.new(0, FLOOR + 3.5, 0)))
		local shooter = standIn(model, "Shooter", c + Vector3.new(30, FLOOR + 3, 0))
		local blocker = standIn(model, "Blocker", c + Vector3.new(15, FLOOR + 3, 0))
		H.fullHeal(shooter)
		H.fullHeal(blocker)
		hook()
		BossPatterns.force(model, data, "mirror")
		H.drive(player, root, model, data, data.skills.mirror.telegraphSeconds + 0.5, function()
			return st.phase == "reflectStance"
		end)
		local stance = st.phase == "reflectStance"
		local reflected = BossHandlersBR1.tryReflect(model, shooter)
		local hpS, hpB = PlayerState.getHp(shooter), PlayerState.getHp(blocker)
		H.drive(player, root, model, data, 2.5)
		local lostB = (hpB - PlayerState.getHp(blocker)) / PlayerState.getMaxHp(blocker)
		r.check(("반사: 태세 %s · 흡수 %s · 되돌림 %d · 막은 동료 %.0f%%(기대 70) · 쏜 사람 %.0f%%(기대 0)"):format(tostring(stance), tostring(reflected), countKind("reflectShot"), lostB * 100, (hpS - PlayerState.getHp(shooter)) / PlayerState.getMaxHp(shooter) * 100),
			stance and reflected and countKind("reflectShot") == 1 and math.abs(lostB - 0.7) < 0.02 and PlayerState.getHp(shooter) == hpS)
	end)

	-- 4) 음파 포효: 트인 곳 = 6틱 90% · 큰 얼음 기둥 뒤 = 0
	r.section("음파 포효", function()
		local model, data, zone = setup("frost_giant", BossData.stageInterval, 1204)
		local c = zone.center
		model:PivotTo(CFrame.new(c + Vector3.new(0, FLOOR + 3.5, 0)))
		local open = standIn(model, "Open", c + Vector3.new(0, FLOOR + 3, 6))
		local hider, hiderRoot = standIn(model, "Hider", c + Vector3.new(40, FLOOR + 3, 0))
		H.fullHeal(open)
		H.fullHeal(hider)
		hook()
		BossPatterns.force(model, data, "roar")
		H.drive(player, root, model, data, 0.2)
		local best = nil
		for _, prop in ipairs(BossArenaProps.list(model)) do
			if prop.kind == "roarPillar" and (not best or (prop.position - hiderRoot.Position).Magnitude < (best.position - hiderRoot.Position).Magnitude) then
				best = prop
			end
		end
		if best then -- 곁의 큰 얼음 기둥 뒤로(보스 반대쪽 반경 + 2)
			local away = Vector3.new(best.position.X - c.X, 0, best.position.Z - c.Z).Unit
			hiderRoot.Position = Vector3.new(best.position.X, FLOOR + 3, best.position.Z) + away * (best.radius + 2)
		end
		H.drive(player, root, model, data, data.skills.roar.telegraphSeconds + data.skills.roar.tickSeconds * data.skills.roar.ticks + 1.5, function()
			return countKind("sonicEnd") > 0
		end)
		local lostOpen = 1 - PlayerState.getHp(open) / PlayerState.getMaxHp(open)
		local lostHider = 1 - PlayerState.getHp(hider) / PlayerState.getMaxHp(hider)
		r.check(("음파 포효: 틱 %d(기대 %d) · 트인 곳 %.0f%%(기대 90) · 큰 기둥 뒤 %.0f%%(기대 0) · 큰 기둥 %s"):format(countKind("sonicTick"), data.skills.roar.ticks, lostOpen * 100, lostHider * 100, tostring(best ~= nil)),
			countKind("sonicTick") == data.skills.roar.ticks and math.abs(lostOpen - 0.9) < 0.02 and lostHider < 0.01 and best ~= nil)
	end)

	-- 5) 색 맞추기: 같은 색 발판 위 = 생존(+ 공동 책임 35%) · 바닥 = 90%
	r.section("색 맞추기", function()
		local model, data, zone, st = setup("abyssal_lord", BossData.stageInterval, 1205)
		local platforms = BossPropMath.kitZones(data.arenaKit, zone.center, FLOOR, "platform")
		local p1 = platforms[1]
		local onTop = standIn(model, "OnTop", Vector3.new(p1.center.X, p1.center.Y + p1.size.Y / 2 + 3, p1.center.Z))
		local floorOne = standIn(model, "Floor", zone.center + Vector3.new(0, FLOOR + 3, 20))
		H.fullHeal(onTop)
		H.fullHeal(floorOne)
		hook()
		BossPatterns.force(model, data, "colors")
		H.drive(player, root, model, data, 0.5, function()
			return st.colorMark ~= nil and st.colorMark[onTop] ~= nil
		end)
		if st.colorMark and st.colorMark[onTop] then
			st.colorOf[p1.index] = st.colorMark[onTop] -- 서 있던 발판을 자기 색으로(올라선 것이 아니라 뒤집히지 않는다)
		end
		H.drive(player, root, model, data, data.skills.colors.telegraphSeconds + 3, function()
			return countKind("colorResolve") > 0
		end)
		local lostTop = 1 - PlayerState.getHp(onTop) / PlayerState.getMaxHp(onTop)
		local lostFloor = 1 - PlayerState.getHp(floorOne) / PlayerState.getMaxHp(floorOne)
		local share = BossData.mechanics.party.failShareFraction
		local failed = 0
		for _, e in ipairs(sent) do
			if e.kind == "colorResolve" then
				failed = #e.payload.failed -- 개발 캐릭터(멀리 바닥)도 멤버라 실패에 든다
			end
		end
		local expectFloor = math.min(0.9 + share * (failed - 1), 1)
		r.check(("색 맞추기: 실패 %d명 · 같은 색 발판 %.0f%%(기대 공동 책임 %.0f × %d) · 바닥 %.0f%%(기대 90 + 공동 책임 → %.0f)"):format(failed, lostTop * 100, share * 100, failed, lostFloor * 100, expectFloor * 100),
			failed >= 1 and math.abs(lostTop - share * failed) < 0.02 and math.abs(lostFloor - expectFloor) < 0.02)
	end)

	-- 6) 공중 가둠: 거품탄 두 번 → 발 + 8 갇힘 · 점프 연타 10회 → 탈출
	r.section("공중 가둠", function()
		local model, data, zone, st = setup("abyssal_lord", BossData.stageInterval, 1206)
		local victim, victimRoot = standIn(model, "Bubbled", zone.center + Vector3.new(10, FLOOR + 3, 10))
		local spec = data.skills.bubbles.trapOnHits
		local c = { model = model, st = st, data = data, now = os.clock() }
		local v = { player = victim, root = victimRoot }
		BossHandlersBR1.noteTrapHit(c, v, spec)
		c.now = os.clock()
		local y0 = victimRoot.Position.Y
		local trapped = BossHandlersBR1.noteTrapHit(c, v, spec)
		local lifted = victimRoot.Position.Y - y0
		local kind = BossTrap.getRecord(victim) and BossTrap.getRecord(victim).kind
		local presses = 0
		for _ = 1, 20 do
			if BossAirGrab.press(victim) then
				presses += 1
			end
			if not BossTrap.isTrapped(victim) then
				break
			end
		end
		r.check(("공중 가둠: 두 번째 명중 → %s(%s) · 발 + %.0f · 연타 %d회에 탈출 %s"):format(tostring(trapped), tostring(kind), lifted, presses, tostring(not BossTrap.isTrapped(victim))),
			trapped and kind == "bubbled" and math.abs(lifted - spec.liftStuds) < 0.01 and presses == spec.presses and not BossTrap.isTrapped(victim))
	end)

	-- 6-2) 번개 조준경: 피뢰침 5 · 필요(스탠드인 1 + 개발 = 2인 → 3) · 한 명을 피뢰침 곁에 세워 두면 그 사람이 표적일 때 충전 · 7번 뒤 판정
	r.section("번개 조준경", function()
		local model, data, zone, st = setup("storm_lord", BossData.stageInterval, 1207)
		local rods = BossPropMath.kitZones(data.arenaKit, zone.center, FLOOR, "rod")
		local onRod = standIn(model, "OnRod", Vector3.new(rods[1].center.X + 2, FLOOR + 3, rods[1].center.Z))
		H.fullHeal(onRod)
		PlayerState.setIncomingDamageMultiplierUntil(onRod, 0, 120, "br12Verify") -- 일반 번개에 죽어 표적 차례를 잃지 않게(검증 쪽)
		hook()
		BossPatterns.force(model, data, "rods")
		local skill = data.skills.rods
		local total = skill.telegraphSeconds + skill.discharges * (skill.markSeconds + skill.trackSeconds + skill.lockSeconds + skill.gapSeconds) + 2
		H.drive(player, root, model, data, total, function()
			return countKind("rodsEnd") > 0
		end)
		local startPayload, strikes, charged = nil, 0, 0
		for _, e in ipairs(sent) do
			if e.kind == "rodsStart" then
				startPayload = e.payload
			elseif e.kind == "rodsStrike" then
				strikes += 1
				charged += e.payload.rodIndex and 1 or 0
			end
		end
		r.check(("번개 조준경: 피뢰침 %d(기대 5) · 필요 %s(기대 3 - 2인) · 방전 %d(기대 7) · 충전 %d(피뢰침 곁 표적 차례만 - 기대 1) · 끝 %d"):format(#rods, tostring(startPayload and startPayload.required), strikes, charged, countKind("rodsEnd")),
			#rods == 5 and startPayload and startPayload.required == 3 and strikes == skill.discharges and charged == 1 and countKind("rodsEnd") == 1)
	end)

	-- 7) 저장 v37: 이관(빈 표) · 첫 만남 표시 한 번만 · 되돌리기
	r.section("저장 v37", function()
		local old = SaveSystem.defaultProfile()
		old.version = 36
		old.hints = { gemMerchantUsed = true }
		local migrated = SaveSystem.migrate(old)
		PlayerProfile.debugResetBossIntro(player) -- 앞 섹션의 보스전이 이미 본 것으로 적었다
		local first = PlayerProfile.markBossIntroSeen(player, "frost_giant")
		local second = PlayerProfile.markBossIntroSeen(player, "frost_giant")
		PlayerProfile.debugResetBossIntro(player)
		local again = PlayerProfile.markBossIntroSeen(player, "frost_giant")
		PlayerProfile.debugResetBossIntro(player)
		r.check(("저장 v%d(기대 37): v36 → v%d · bossIntroSeen 빈 표 %s · 옛 힌트 유지 %s · 첫 만남 %s → 두 번째 %s · 비우면 다시 %s"):format(SaveConfig.saveVersion, migrated.version,
			tostring(type(migrated.hints.bossIntroSeen) == "table" and next(migrated.hints.bossIntroSeen) == nil), tostring(migrated.hints.gemMerchantUsed), tostring(first), tostring(second), tostring(again)),
			SaveConfig.saveVersion == 37 and migrated.version == 37 and type(migrated.hints.bossIntroSeen) == "table" and migrated.hints.gemMerchantUsed == true and first and not second and again)
	end)

	root.Anchored = false
	BossEncounter.despawnFor(player)
	local passed, total = r.summary()
	print(("===BR1-2 검증 끝(나)=== %d/%d 통과"):format(passed, total))
end

return BR1_2Verify
