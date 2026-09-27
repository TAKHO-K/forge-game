-- BR1-4a 자동 검증 - 보스 패턴 수치 · 로직(모션 구조 교체 없음).
--   (가) 순수: 피해 종류 표(전멸기 · 기믹 = %최대체력 · 일반 = 능력치) · 대공 잡기 판정 창 · 회오리 직후 우선순위 · 에네르기파 점프 회피 · 상한 · 회오리 체공 · 붕괴 건너기 표(환생 단계) ·
--        회피 부등식 전 보스 · 2연타 위반 0 · 아레나 낙하 제외.
--   (나) 실제 Player: 고정 % 피해(대시 무시 · 기술 감소) · 에네르기파(맞음 · 점프로 넘음 · 빈틈 · 끌림 → 풀림 · 시전당 45%) · 회오리(2.5초 + 물리 발사 · 되돌림 0) ·
--        대공 잡기 강제 체공 누적 → 얼림 · 붕괴(바닥이 실제로 꺼짐 → 떨어짐 → 전멸기 피해 + 가장자리 복귀 · 끝나면 원판) · 아레나 낙하 제외.
-- 도우미 = BR1Verify.helpers(스탠드인 · 보스 직접 step). 검증이 만든 것(보스 · 스탠드인 · 조각 바닥 · 배율)은 절마다 되돌린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSim = require(ReplicatedStorage.Shared.BossSim)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local MovementUnlockData = require(ReplicatedStorage.Shared.data.MovementUnlockData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[BR1-4a][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1-4a][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

local ALL = { "section_guardian", "frost_giant", "deep_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

-- 전멸기 · 기믹(%최대체력이 맞는 패턴) - 나머지 스킬의 maxHp 피해 = 규칙 위반
local FIXED_PRIMITIVES = { colorMatch = true, lightningRods = true, sandSearch = true, orgel = true, sonic = true, reflect = true, pillarRoar = true, split = true }

function V.runPure()
	print("===BR1-4a 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("4a-1 피해 종류 표", function()
		local rows, bad = {}, {}
		for _, id in ipairs(ALL) do
			local boss = BossData.bosses[id]
			for _, sid in ipairs(boss.skillOrder) do
				local s = boss.skills[sid]
				local kind = s and s.damage and s.damage.kind
				local fixed = s and (s.role == "gimmick" or s.role == "signature" and kind == "maxHp" or FIXED_PRIMITIVES[s.primitive])
				if kind == "maxHp" and not fixed then
					table.insert(bad, id .. "." .. sid)
				end
				if kind == "maxHp" or (s and s.failMaxHpFraction) then
					table.insert(rows, ("%s.%s(%s)"):format(id, sid, s.primitive))
				end
			end
		end
		local charge = BossData.bosses.section_guardian.skills.charge.damage
		local stab = BossData.bosses.scorpion_queen.skills.stab
		r.note("전멸기 · 기믹 %최대체력: " .. table.concat(rows, " · "))
		r.check(("일반 패턴 %%최대체력 %d(기대 0%s) · 돌진 = 공격 ×%.3f(옛 55%% = 앵커 ×%.3f) · 잠행 찌르기 ×%.3f"):format(#bad, #bad > 0 and (" - " .. table.concat(bad, " · ")) or "",
			charge.multiplier, 0.55 * BalanceAnchorConfig.surviveTargetHits, stab and stab.damage.multiplier or -1),
			#bad == 0 and charge.kind == "attack" and math.abs(charge.multiplier - 0.55 * BalanceAnchorConfig.surviveTargetHits) < 1e-9 and stab and stab.damage.kind == "attack")
	end)

	r.section("4a-2 대공 잡기", function()
		local g = BossData.mechanics.airGrab
		local oneJump = JumpMath.maxAirSeconds(JumpMath.jumpHeight(0), 0, nil)
		local skills = BossData.bosses.storm_lord.skills
		local state = BossScheduler.newState(skills, BossData.bosses.storm_lord.skillOrder, 0)
		for id in pairs(state.readyAt) do
			state.readyAt[id] = math.huge
		end
		state.readyAt.grab, state.readyAt.swipe = 0, 0.5 -- grab이 먼저 기다렸다(평소엔 grab이 뽑힌다)
		state.lastEndAt = -100
		local ctx = { now = 10, enraged = false, graceUntil = 0, conditionMet = function() return true end, boundSeconds = function() return 5 end }
		state.lastSkillId = "strike"
		local normal = BossScheduler.pick(state, skills, BossData.bosses.storm_lord.skillOrder, BossData.bosses.storm_lord.scheduler, ctx)
		state.lastSkillId = "whirl"
		local afterWhirl = BossScheduler.pick(state, skills, BossData.bosses.storm_lord.skillOrder, BossData.bosses.storm_lord.scheduler, ctx)
		r.check(("판정 창 %.1f초 · 누적 %.2f초(1단 점프 %.3f < 누적) · 우선순위: 평소 %s(기대 grab) · 회오리 직후 %s(기대 swipe)"):format(g.judgeWindowSeconds, g.airAccumSeconds, oneJump, tostring(normal), tostring(afterWhirl)),
			g.airAccumSeconds > oneJump and normal == "grab" and afterWhirl == "swipe")
		-- 발버둥 게이지(표): 필요 횟수 = base + perExtra × (인원 − 1) · 초당 상한 maxPressesPerSecond · 들고 있기 holdSeconds
		local s = g.struggle
		local cells = {}
		for n = 1, 4 do
			local need = s.pressesBase + s.pressesPerExtra * (n - 1)
			table.insert(cells, ("%d명 %d회 = 최대 속도 %.1f초 · 초당 4회 %.1f초"):format(n, need, need / (n * s.maxPressesPerSecond), need / (n * 4)))
		end
		r.note(("발버둥(들고 있기 %.1f초 · 구출 %d타 %.1f초 간격 → 최소 %.1f초): %s"):format(g.holdSeconds, g.rescueHits.requiredHits, g.rescueHits.hitIntervalSeconds,
			(g.rescueHits.requiredHits - 1) * g.rescueHits.hitIntervalSeconds, table.concat(cells, " / ")))
		r.check(("솔로 탈출(초당 4회) %.1f초 ≤ 들고 있기 %.1f초"):format(s.pressesBase / 4, g.holdSeconds), s.pressesBase / 4 <= g.holdSeconds)
	end)

	r.section("4a-3 에네르기파", function()
		local b = BossData.bosses.crystal_queen.skills.energyBeam
		local w = BossSkillMath.beamJumpWorst(b, MovementConfig.jumpHeightStuds, MovementConfig.gravity)
		local margin = BossData.mechanics.dodge.marginFactor
		local rev = 360 / (b.sweepDeg / b.sweepSeconds)
		local ticks = math.floor(b.pull.maxSeconds / b.tickSeconds) + 1
		local anchorTotal = ticks * b.damage.multiplier / BalanceAnchorConfig.surviveTargetHits
		local length = BossArenaMapData.geometry.radiusStuds * 2 * b.lengthArenaFraction
		r.check(("빔 점프: 반경 %d에서 지나는 시간 %.3f × %.2f ≤ 1단 점프 빔 위 %.3f초 · 한 바퀴 %.1f초(%d° = 한 자리 1 ~ 2번) · 길이 %.0f(아레나 반지름) · 끌림 %.1f초 도트 %d번 = 앵커 %.0f%% ≤ 상한 %.0f%%"):format(
			w.r, w.passSeconds, margin, w.clearSeconds, rev, b.sweepDeg, length, b.pull.maxSeconds, ticks, anchorTotal * 100, b.castMaxHpFraction * 100),
			w.clearSeconds >= w.passSeconds * margin and b.sweepDeg == 540 and rev >= 2 and rev <= 3 and anchorTotal <= b.castMaxHpFraction + 1e-9 and length == BossArenaMapData.geometry.radiusStuds)
	end)

	r.section("4a-4 회오리", function()
		local lift = BossData.bosses.storm_lord.skills.whirl.onHit[1]
		local tornado = BossData.bosses.storm_lord.skills.tornado.onHit[1]
		local g = MovementConfig.gravity
		local fly = math.sqrt(2 * g * lift.flingUpStuds) / g + math.sqrt(2 * (lift.flingUpStuds + lift.heightStuds) / g)
		local helpless = 0.3 + lift.holdSeconds + fly + 0.78
		r.check(("돌기 %.1f초(옛 1.5) · 끝 물리 발사 수평 %d(넉백 상한 %d 안) · 위로 %d · 비행 %.2f초 · 조작 잃음 %.2f ≤ 무적 %.1f · 회오리 이동도 같은 조각 %s"):format(
			lift.holdSeconds, lift.flingDistanceStuds, BossArenaMapData.containment.maxLaunchDistanceStuds, lift.flingUpStuds, fly, helpless, lift.immuneSeconds, tostring(lift == tornado)),
			lift.holdSeconds > 1.5 and lift.flingDistanceStuds <= BossArenaMapData.containment.maxLaunchDistanceStuds and helpless <= lift.immuneSeconds and lift == tornado)
	end)

	r.section("4a-5 붕괴 건너기(환생 단계별 틈 폭)", function()
		local env = BossData.bosses.section_guardian.environment
		local spec = env.zones
		local rows, ok = {}, true
		local band0 = nil
		for tier = 0, 4 do
			local caps = WorldMapLayout.capsForTier(MovementUnlockData.tiers[tier], false, false, 16)
			local gap = JumpMath.maxGapStuds({ walk = 16, airJumps = caps.airJumps, dashes = 1, dashStuds = caps.dashStuds, rise = 0 })
			local rMax = (gap - 1) / (2 * math.sin(math.pi / spec.count)) -- 45° 조각 현 = 2r·sin 22.5° ≤ 틈 폭 − 1
			table.insert(rows, ("환생 %d 틈 %.1f → 반경 %.1f 안에서 건넌다"):format(tier, gap, rMax))
			if tier == 0 then
				band0 = rMax
			end
			ok = ok and rMax > spec.hubRadiusStuds + 5
		end
		local r40 = 2 * 40 * math.sin(math.pi / spec.count)
		r.note("건너기 표: " .. table.concat(rows, " · "))
		r.check(("환생 0도 점프 + 대시로 건넌다(허브 %d 밖 반경 %.1f까지) · 여유 좁음(반경 40 현 %.1f vs 틈 %.1f) · 낙하 = 전멸기(첫 %.0f%% · 다시 %.0f%%) + 가장자리 복귀"):format(
			spec.hubRadiusStuds, band0, r40, band0 * 2 * math.sin(math.pi / spec.count) + 1, BossData.mechanics.gimmickFail.firstMaxHpFraction * 100, BossData.mechanics.gimmickFail.maxHpFraction * 100),
			ok and env.fall.wipe == true)
	end)

	r.section("4a-6 아레나 낙하 제외 · 회피 부등식 · 2연타", function()
		local reason = MoveRules.fallExcluded({ inBoss = true })
		local failed = {}
		local BossRules = require(ReplicatedStorage.Shared.BossRules)
		for _, id in ipairs(ALL) do
			for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do -- BR1 회피 부등식과 같은 범위 배율 두 가지
				local skills = BossSkillMath.scaleSkills(BossData.bosses[id].skills, scale)
				for _, sid in ipairs(BossData.bosses[id].skillOrder) do
					for _, c in ipairs(BossSkillMath.dodgeChecks(skills[sid], 8, WorldConfig.playerWalkSpeedStuds)) do
						if not c.ok then
							table.insert(failed, ("%s.%s %s ×%.2f(%.2f < %.2f)"):format(id, sid, c.label, scale, c.availableSeconds, c.requiredSeconds))
						end
					end
				end
			end
		end
		local pairsBad = 0
		for _, id in ipairs(ALL) do
			local _, violations = BossSim.checkPairs(id)
			pairsBad += violations
		end
		r.check(("보스 아레나 낙하 = 제외(%s) · 회피 부등식 위반 %d%s · 2연타 위반 %d(기대 0 0)"):format(tostring(reason), #failed, #failed > 0 and (" - " .. table.concat(failed, " · ")) or "", pairsBad),
			reason == "boss" and #failed == 0 and pairsBad == 0)
	end)

	local pass, total = r.summary()
	print(("===BR1-4a 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function V.runLive(player, env)
	print("===BR1-4a 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local H = require(script.Parent.BR1Verify).helpers
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossTrap = require(script.Parent.BossTrap)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local HeightGuard = require(script.Parent.HeightGuard)
	local FallServer = require(script.Parent.FallServer)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local sent, events = {}, {}
	local standIns = {}
	local function hook()
		table.clear(sent)
		table.clear(events)
		BossPatterns.debugSendHook = function(kind, payload)
			table.insert(sent, { kind = kind, payload = payload, at = os.clock() })
		end
	end
	local function countKind(kind, filter)
		local n, last = 0, nil
		for _, e in ipairs(sent) do
			if e.kind == kind and (not filter or filter(e.payload)) then
				n += 1
				last = e
			end
		end
		return n, last
	end
	local rawSection = r.section
	r.section = function(name, fn)
		rawSection(name, fn)
		if root then
			root.Anchored = false
		end
		BossPatterns.debugSendHook = nil
		H.clearStandIns(player, standIns)
		PlayerState.clearIncomingDamageMultiplier(player)
		HeightGuard.debugOff = true
		BossEncounter.despawnFor(player)
	end

	r.section("4a-1 고정 % 피해(실제 Player)", function()
		H.fullHeal(player)
		local maxHp = PlayerState.getMaxHp(player)
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 5, "dash")
		local hp0 = PlayerState.getHp(player)
		PlayerDamage.applyMaxHpFraction(player, 0.3, "검증 기믹")
		local dashIgnored = (hp0 - PlayerState.getHp(player)) / maxHp
		H.fullHeal(player)
		PlayerState.clearIncomingDamageMultiplier(player)
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 5, "verifySkill", true)
		hp0 = PlayerState.getHp(player)
		PlayerDamage.applyMaxHpFraction(player, 0.3, "검증 기믹")
		local technique = (hp0 - PlayerState.getHp(player)) / maxHp
		H.fullHeal(player)
		PlayerState.clearIncomingDamageMultiplier(player)
		local newbie = PlayerDamage.getNewbieMultiplier(player)
		r.check(("최대 체력 30%%: 대시(50%%) 중 %.1f%%(기대 30 × 신규 보호 %.2f - 대시 무시) · 기술 감소(50%%) 중 %.1f%%(기대 15 × 보호)"):format(dashIgnored * 100, newbie, technique * 100),
			math.abs(dashIgnored - 0.3 * newbie) < 0.005 and math.abs(technique - 0.15 * newbie) < 0.005)
	end)

	r.section("4a-3 에네르기파(실제 Player + 스탠드인)", function()
		local model, data, encounter = H.spawnBoss(player, env, "crystal_queen", 4301, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		local skill = data.skills.energyBeam
		local oldGap = skill.gapChance
		local results = {}
		for _, gapCase in ipairs({ 0, 1 }) do
			skill.gapChance = gapCase
			H.clearStandIns(player, standIns)
			local center = zone.center
			root.Anchored = true
			root.CFrame = CFrame.new(center + Vector3.new(30, FLOOR + 3, 0))
			local jumper, jumperRoot = H.newStandIn(model, "Jumper", center + Vector3.new(0, FLOOR + 3 + 4, 30)) -- 발이 빔 위(점프 중)
			local inner, innerRoot = H.newStandIn(model, "Inner", center + Vector3.new(-10, FLOOR + 3, 0)) -- 보스 곁 10(빈틈이면 안전)
			table.insert(standIns, jumper)
			table.insert(standIns, inner)
			local st = MonsterState.getBossPatternState(model)
			st.graceUntil = 0
			hook()
			BossPatterns.force(model, data, "energyBeam")
			H.drive(player, root, model, data, skill.telegraphSeconds + skill.sweepSeconds + skill.pull.maxSeconds + 1, function()
				return countKind("sweepEnd") > 0
			end)
			local dealt = st.beamDealt or {}
			local hitsPlayer = countKind("beamPull", function(p) return p.userId == player.UserId end)
			local _, pullEvt = countKind("beamPull", function(p) return p.userId == player.UserId end)
			local _, relEvt = countKind("beamRelease", function(p) return p.userId == player.UserId end)
			local lockSeconds = pullEvt and relEvt and (relEvt.at - pullEvt.at) or -1
			results[gapCase] = {
				gap = countKind("sweepTelegraph", function(p) return p.gap == true end) == 1,
				player = hitsPlayer, share = (dealt[player] or 0) / PlayerState.getMaxHp(player), lock = lockSeconds,
				jumper = dealt[jumper] ~= nil, inner = dealt[inner] ~= nil,
			}
			_ = jumperRoot
			_ = innerRoot
		end
		skill.gapChance = oldGap
		local a, b = results[0], results[1]
		r.check(("빈틈 없음: 선 사람 걸림 %d번(기대 1 - 풀린 뒤 면역) · 시전 피해 %.1f%%(≤ %.0f%%) · 끌림 %.2f초(≤ %.1f) · 점프 중 스탠드인 맞음 %s · 곁 10 맞음 %s(기대 true)"):format(
			a.player, a.share * 100, skill.castMaxHpFraction * 100, a.lock, skill.pull.maxSeconds, tostring(a.jumper), tostring(a.inner)),
			a.player == 1 and a.share > 0 and a.share <= skill.castMaxHpFraction + 1e-6 and a.lock > 0 and a.lock <= skill.pull.maxSeconds + 0.1 and not a.jumper and a.inner)
		r.check(("빈틈 있음(전조 표시 %s): 곁 10 맞음 %s(기대 false - 보스 곁 %d 안 안전) · 선 사람 걸림 %d"):format(tostring(b.gap), tostring(b.inner), skill.gapInnerStuds, b.player),
			b.gap and not b.inner and b.player == 1)
	end)

	r.section("4a-4 회오리(실제 Player · 되돌림 0)", function()
		local model, data, encounter = H.spawnBoss(player, env, "storm_lord", 4401, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = false
		character:PivotTo(CFrame.new(zone.center + Vector3.new(12, FLOOR + 3, 0)))
		HeightGuard.reset(player)
		task.wait(1.2)
		HeightGuard.debugOff = false
		local hs = HeightGuard.getState(player)
		local reverts0, h0 = hs and hs.reverts or 0, (hs and hs.hReverts) or 0
		local corrections0 = #require(script.Parent.BossArenaContainment).corrections()
		local st = MonsterState.getBossPatternState(model)
		st.graceUntil = 0
		hook()
		local start = root.Position
		BossPatterns.force(model, data, "whirl")
		local maxRise = 0
		local t0 = os.clock()
		H.drive(player, root, model, data, 7, function()
			maxRise = math.max(maxRise, root.Position.Y - start.Y)
			return false
		end)
		local moved = Vector3.new(root.Position.X - start.X, 0, root.Position.Z - start.Z).Magnitude
		local launch = st.lastLaunch
		local reverts = (hs and hs.reverts or 0) - reverts0
		local hreverts = ((hs and hs.hReverts) or 0) - h0
		local corrections = #require(script.Parent.BossArenaContainment).corrections() - corrections0
		HeightGuard.debugOff = true
		r.check(("회오리: 뜸 %s(돌기 %.1f · 발사 %s) · 최고 +%.1f · 수평 이동 %.1f · 높이 되돌림 %d · 수평 되돌림 %d · 맵 이탈 복귀 %d(기대 0 0 0) · %.1f초"):format(tostring(launch ~= nil),
			launch and launch.effect.holdSeconds or -1, tostring(launch and launch.effect.flingDistanceStuds), maxRise, moved, reverts, hreverts, corrections, os.clock() - t0),
			launch ~= nil and launch.effect.holdSeconds == 2.5 and reverts == 0 and hreverts == 0 and corrections == 0 and maxRise > 3)
	end)

	r.section("4a-2 대공 잡기 강제 체공 누적(실제 Player)", function()
		local model, data, encounter = H.spawnBoss(player, env, "section_guardian", 4201, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = false
		character:PivotTo(CFrame.new(zone.center + Vector3.new(20, FLOOR + 3, 0)))
		HeightGuard.reset(player)
		task.wait(1)
		local st = MonsterState.getBossPatternState(model)
		st.graceUntil = 0
		hook()
		BossPatterns.force(model, data, "grab")
		local g = BossData.mechanics.airGrab
		local launched = false
		local patternEvent = ReplicatedStorage:FindFirstChild("BossPatternEvent")
		H.drive(player, root, model, data, data.skills.grab.telegraphSeconds + 1.5, function()
			if not launched and st.phaseEndsAt and os.clock() >= st.phaseEndsAt - g.judgeWindowSeconds + 0.05 and st.phase == "grabTelegraph" then
				launched = true -- 판정 창 시작 뒤 넉백(강제 체공 - 클라 PlatformStand)
				HeightGuard.grantLaunch(player, 12, JumpMath.launchAirSeconds(12) + 1, "검증 넉백")
				if patternEvent then
					patternEvent:FireClient(player, "launch", { from = root.Position + Vector3.new(1, 0, 0), heightStuds = 12, distanceStuds = 0 })
				end
			end
			local rec = BossTrap.getRecord(player)
			return rec ~= nil
		end)
		local rec = BossTrap.getRecord(player)
		local accum = st.grabAirAccum and st.grabAirAccum[player] or 0
		r.check(("판정 창 넉백(강제 체공) → 누적 %.2f초 · 얼림 %s(종류 %s - 기대 airFrozen/grabbed)"):format(accum, tostring(rec ~= nil), tostring(rec and rec.kind)),
			launched and rec ~= nil and (rec.kind == "airFrozen" or rec.kind == "grabbed"))
		BossTrap.release(player, "reset")
	end)

	r.section("4a-5 붕괴(바닥이 실제로 꺼짐 · 실제 Player)", function()
		local model, data, encounter = H.spawnBoss(player, env, "section_guardian", 4501, 15)
		assert(model, "보스 스폰 실패")
		local zone = WorldConfig.zones[encounter.zoneKey]
		local st = MonsterState.getBossPatternState(model)
		st.env = { phase = "armed", phaseEndsAt = 0, taken = {} }
		st.graceUntil = os.clock() + 999
		root.Anchored = true
		root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 3, 60))
		hook()
		H.drive(player, root, model, data, 2, function()
			return countKind("envTelegraph") > 0
		end)
		local _, tel = countKind("envTelegraph")
		assert(tel, "붕괴 전조 없음")
		local z = tel.payload.zones[1]
		local sliceFloor = BossArenaMap.sliceFloorOf(encounter.zoneKey)
		local a = math.rad(z.startDeg + z.widthDeg / 2)
		local spot = Vector3.new(z.center.X, FLOOR + 3, z.center.Z) + Vector3.new(math.cos(a), 0, math.sin(a)) * 60
		root.Anchored = false
		character:PivotTo(CFrame.new(spot))
		HeightGuard.reset(player)
		local fellAt = nil
		H.drive(player, root, model, data, data.environment.telegraphSeconds + 3, function()
			if not fellAt and countKind("voidFall", function(p) return p.userId == player.UserId end) > 0 then
				fellAt = os.clock()
			end
			return fellAt ~= nil and os.clock() - fellAt > 0.5
		end)
		local _, fall = countKind("voidFall", function(p) return p.userId == player.UserId end)
		local collided = 0
		for _, p in ipairs(sliceFloor and sliceFloor.slices[z.index] or {}) do
			collided += p.CanCollide and 1 or 0
		end
		local edge = fall and fall.payload.edge
		local nowPos = root.Position
		local offHole = edge and not require(script.Parent.BossEnvironment).blocksBoss(model, nowPos)
		local base = BossArenaMap.buildBase(encounter.zoneKey)
		r.check(("조각 바닥 %s · 무너진 조각 충돌 파트 %d(기대 0) · 떨어짐 %s → 가장자리 복귀 %s(구멍 밖 %s) · 바닥 원판 꺼짐 %s"):format(tostring(sliceFloor ~= nil), collided, tostring(fall ~= nil),
			edge and ("(%.0f, %.0f)"):format(edge.X, edge.Z) or "없음", tostring(offHole), tostring(base.floor.CanCollide == false)),
			sliceFloor ~= nil and collided == 0 and fall ~= nil and offHole and base.floor.CanCollide == false)
		BossEncounter.despawnFor(player)
		r.check(("보스전 끝 → 조각 바닥 치움 %s · 원판 충돌 %s"):format(tostring(BossArenaMap.sliceFloorOf(encounter.zoneKey) == nil), tostring(base.floor.CanCollide)),
			BossArenaMap.sliceFloorOf(encounter.zoneKey) == nil and base.floor.CanCollide == true)
	end)

	r.section("4a-6 보스 아레나 낙하 제외(실제 경로)", function()
		local model = H.spawnBoss(player, env, "section_guardian", 4601, 15)
		assert(model, "보스 스폰 실패")
		local why = MoveRules.fallExcluded(FallServer.context(player, {}, os.clock()))
		r.check(("보스전 중 낙하 판정 제외 = %s(기대 boss)"):format(tostring(why)), why == "boss")
	end)

	env.restore(player)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d(기대 0)"):format(orphan), orphan == 0)
	local pass, total = r.summary()
	print(("===BR1-4a 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
