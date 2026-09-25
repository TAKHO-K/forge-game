-- BR1 자동 검증(docs/design/boss-br1.md). (가) = 서버 시작 때 순수 계산 · (나) = 보스 검증 체인 끝(실제 보스 6종 · 스탠드인 · 실제 판정 경로).
--   (가) 회피 부등식(6종 × 범위 배율 1 · 최대) · 겹침 분류(피할 수 있음 / 어려움 / 피할 수 없음) · 대공 잡기 수치 대조 · 첫 도전 모형 요약
--   (나) 보스마다 새 패턴 강제(이벤트 · 부채꼴 판정 모양 = 전조 모양 · 칸 · 볼리 수 · 반사 선분 · 공중 파동) · 대공 잡기(N초 · 던짐 = 현재 체력 50% · 구출 → 기절) ·
--        환경 변화(전조 → 구역 도트 · 정원 파트 · 끝나면 정리) · 12인 스탠드인 최악 조건 step 시간
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossOverlap = require(ReplicatedStorage.Shared.BossOverlap)
local BossDifficultySim = require(ReplicatedStorage.Shared.BossDifficultySim)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)

local BR1Verify = {}

local ALL_BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }
-- 보스마다 BR1이 새로 넣거나 바꾼 패턴(강화 평타 swipe 포함 - 대공 잡기는 따로 검사한다)
local NEW_SKILLS = {
	section_guardian = { "swipe", "fists", "orbs", "earthSplit", "shockwave" },
	frost_giant = { "swipe", "spear", "stomp", "snowball" },
	abyssal_lord = { "swipe", "tailSweep", "vortex", "bubbles", "spout", "tide" },
	crystal_queen = { "swipe", "spikes", "shards", "mirrorDash", "beam" },
	scorpion_queen = { "swipe", "stingJab", "ambush", "clawSweep" },
	storm_lord = { "swipe", "tornado", "thunderRing", "boltSpear", "discharge" },
}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[BR1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[BR1][%s] %s"):format(tag, label))
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

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-3)
end

-- ─────────────────────────── (가) ───────────────────────────
function BR1Verify.runPure()
	print("===BR1 검증 시작(가)===")
	local r = newRecorder("가")
	r.section("회피 부등식", function()
		for _, id in ipairs(ALL_BOSSES) do
			local boss = BossData.bosses[id]
			local fails = {}
			for _, scale in ipairs({ 1, BossRules.maxSkillRangeScale() }) do
				local skills = BossSkillMath.scaleSkills(boss.skills, scale)
				for _, sid in ipairs(boss.skillOrder) do
					for _, ch in ipairs(BossSkillMath.dodgeChecks(skills[sid], 8, WorldConfig.playerWalkSpeedStuds)) do
						if not ch.ok then
							table.insert(fails, ("%s %s ×%.3f(%.2f < %.2f)"):format(sid, ch.label, scale, ch.availableSeconds, ch.requiredSeconds))
						end
					end
				end
			end
			r.check(("회피 부등식 %s: 스킬 %d개 × 범위 배율 1 · %.3f - 실패 %d%s"):format(id, #boss.skillOrder, BossRules.maxSkillRangeScale(), #fails, #fails > 0 and (" " .. table.concat(fails, " / ")) or ""), #fails == 0)
		end
	end)
	r.section("겹침 분류", function()
		for _, id in ipairs(ALL_BOSSES) do
			local table_ = BossOverlap.classify(id)
			local counts = { dodgeable = 0, hard = 0, impossible = 0 }
			local impossible = {}
			for _, sid in ipairs(BossData.bosses[id].skillOrder) do
				local e = table_ and table_[sid]
				if e then
					counts[e.class] += 1
					if e.class == "impossible" then
						table.insert(impossible, ("%s(필요 %.2f > 전조 %.2f)"):format(sid, e.need100, e.available))
					end
				end
			end
			r.check(("겹침 %s + %s: 피할 수 있음 %d · 어려움 %d · 피할 수 없음 %d%s"):format(id, BossData.bosses[id].environment.id, counts.dodgeable, counts.hard, counts.impossible,
				#impossible > 0 and (" - " .. table.concat(impossible, " · ")) or ""), table_ ~= nil and counts.dodgeable + counts.hard + counts.impossible == #BossData.bosses[id].skillOrder)
		end
	end)
	r.section("대공 잡기 수치", function()
		local grab = BossData.mechanics.airGrab
		local h1 = JumpMath.jumpHeight(0)
		local maxAir = JumpMath.maxAirSeconds(h1, 2, DashConfig.durationSeconds)
		local single = JumpMath.maxAirSeconds(h1, 1, nil)
		local double = JumpMath.maxAirSeconds(h1, 2, nil)
		r.check(("N = %.1f초: 1단 + 공중 1(%.3f초) < N < 공중 2(%.3f) · 한 체공 최대 %.3f(데이터 %.3f) · 전조 %.1f ≥ 인지 + 최대 체공 %.2f"):format(grab.airSeconds, single, double, maxAir, grab.maxAirSeconds,
			BossData.bosses.section_guardian.skills.grab.telegraphSeconds, 0.5 + grab.maxAirSeconds),
			grab.airSeconds > single and grab.airSeconds < double and near(maxAir, grab.maxAirSeconds, 0.01) and BossData.bosses.section_guardian.skills.grab.telegraphSeconds >= 0.5 + grab.maxAirSeconds)
	end)
	r.section("첫 도전 모형", function()
		for _, id in ipairs(ALL_BOSSES) do
			local known = BossDifficultySim.monteCarlo(id, { partySize = 1, role = "ranged", familiar = true }, 150)
			local fresh = BossDifficultySim.monteCarlo(id, { partySize = 1, role = "ranged", familiar = false }, 150)
			r.note(("모형 %s 솔로(원거리): 아는 보스 = 처치 p50 %.0f초 · 피해 %.0f%% · 전멸 %.0f%% · 겹침 미룸 %.2f/판 | 처음 보는 보스 = 전멸 %.0f%%"):format(id, known.p50, known.takenMean * 100, known.wipeRate * 100, known.deferredPerRun, fresh.wipeRate * 100))
			r.check(("모형 범위 %s: 아는 보스 전멸 %.0f%%(허용 20 ~ 65) · 처치 %.0f초(45 ~ 100)"):format(id, known.wipeRate * 100, known.p50),
				known.wipeRate >= 0.2 and known.wipeRate <= 0.65 and known.p50 >= 45 and known.p50 <= 100)
		end
	end)
	local passed, total = r.summary()
	print(("===BR1 검증 끝(가)=== %d/%d 통과"):format(passed, total))
end

-- ─────────────────────────── (나) 헬퍼 ───────────────────────────
local function fullHeal(player)
	local PlayerState = require(script.Parent.PlayerState)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
end

local function spawnBoss(player, env, bossId, seed)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local MonsterState = require(script.Parent.MonsterState)
	BossEncounter.despawnFor(player)
	env.applyStage(player, BossData.stageInterval)
	BossEncounter.setDebugForcedBoss(player, bossId)
	BossArenaMap.debugNextSeed = seed
	BossEncounter.spawnFor(player, BossData.stageInterval)
	local model = BossEncounter.getActive(player)
	local encounter = BossEncounter.getEncounter(player)
	return model, model and MonsterState.getData(model), encounter
end

local function newStandIn(model, name, position)
	local PlayerState = require(script.Parent.PlayerState)
	local BossEncounter = require(script.Parent.BossEncounter)
	local fakeRoot = { Position = position }
	local fake = { Name = name, UserId = -9700 - math.random(1, 9999), Parent = Workspace }
	fake.Character = {
		FindFirstChild = function(_, child)
			return child == "HumanoidRootPart" and fakeRoot or nil
		end,
		FindFirstChildOfClass = function()
			return nil
		end,
	}
	function fake:SetAttribute() end
	function fake:GetAttribute()
		return nil
	end
	PlayerState.init(fake)
	BossEncounter.debugAddMember(model, fake)
	return fake, fakeRoot
end

local function clearStandIns(player, standIns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossTrap = require(script.Parent.BossTrap)
	local PlayerState = require(script.Parent.PlayerState)
	local encounter = BossEncounter.getEncounter(player)
	for _, fake in ipairs(standIns) do
		BossTrap.release(fake, "reset")
		PlayerState.clear(fake)
		if encounter then
			local at = table.find(encounter.members, fake)
			if at then
				table.remove(encounter.members, at)
			end
		end
	end
	table.clear(standIns)
end

-- 보스를 직접 step한다(개발 캐릭터는 어그로 밖 - MonsterAI는 이 보스를 안 돌린다). 반환: 마지막 step 시간(초) 목록.
local function drive(player, root, model, data, seconds, untilFn)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local startedAt = os.clock()
	local costs = {}
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		fullHeal(player)
		if not model.Parent then
			break
		end
		local t0 = os.clock()
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, BossEncounter.getMembersOfModel(model))
		table.insert(costs, os.clock() - t0)
		if untilFn and untilFn() then
			break
		end
	end
	return costs
end

local function stats(costs)
	local sum, peak = 0, 0
	for _, c in ipairs(costs) do
		sum += c
		peak = math.max(peak, c)
	end
	return #costs > 0 and sum / #costs * 1e6 or 0, peak * 1e6
end

-- ─────────────────────────── (나) ───────────────────────────
function BR1Verify.runLive(player, env)
	print("===BR1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossTrap = require(script.Parent.BossTrap)
	local BossEnvironment = require(script.Parent.BossEnvironment)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local FLOOR = BossArenaMap.floorTopY()
	local sent, judged = {}, {}
	local standIns = {}
	PlayerState.clearIncomingDamageMultiplier(player)
	local rawSection = r.section
	r.section = function(name, fn)
		rawSection(name, fn)
		if root then
			root.Anchored = false
		end
		BossArenaMap.debugNextSeed = nil
		BossPatterns.debugJudgeHook = nil
		BossPatterns.debugSendHook = nil
		clearStandIns(player, standIns)
		PlayerState.clearIncomingDamageMultiplier(player)
		BossEncounter.despawnFor(player)
	end
	local function hook()
		table.clear(sent)
		table.clear(judged)
		BossPatterns.debugSendHook = function(kind, payload)
			table.insert(sent, { kind = kind, payload = payload })
		end
		BossPatterns.debugJudgeHook = function(record)
			table.insert(judged, record)
		end
	end
	local function countKind(kind)
		local n, last = 0, nil
		for _, e in ipairs(sent) do
			if e.kind == kind then
				n += 1
				last = e.payload
			end
		end
		return n, last
	end
	local perf = {}

	for bossIndex, bossId in ipairs(ALL_BOSSES) do
		r.section(("새 패턴 %s"):format(bossId), function()
			local model, data, encounter = spawnBoss(player, env, bossId, 700 + bossIndex)
			assert(model, "보스 스폰 실패")
			local zone = WorldConfig.zones[encounter.zoneKey]
			root.Anchored = true
			root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 3, 60)) -- 대상(어그로 밖이지만 조준 대상) - 보스 쪽 거리 60
			local near1 = newStandIn(model, "Near", zone.center + Vector3.new(10, FLOOR + 3, 0))
			table.insert(standIns, near1)
			local st = MonsterState.getBossPatternState(model)
			local spawnAt = MonsterState.getSpawnPosition(model)
			for _, sid in ipairs(NEW_SKILLS[bossId]) do
				local skill = data.skills[sid]
				-- Play 2(검증 쪽): 스탠드인 체력을 채우고(죽으면 체공 추적 · 대상에서 빠진다) 보스를 스폰 자리로(잠복 뒤 개발 캐릭터 곁에 솟으면 MonsterAI도 이 보스를 돌린다)
				fullHeal(near1)
				model:PivotTo(CFrame.new(spawnAt))
				hook()
				near1.debugAirborne = skill.targetRule == "airborne" or nil -- 대공 투사체는 떠 있는 사람만 노린다
				if near1.debugAirborne then
					drive(player, root, model, data, 0.5) -- 연속 체공이 쌓인 뒤에 쏜다(Play 1: 같은 틱에 띄우면 대상 0 - 검증 쪽)
				end
				BossPatterns.force(model, data, sid)
				-- BR1-2 첫 Play: 대기 = 16초 또는 투사체 수명 전체(벽 튕김마다 bounceLifetimeSeconds가 다시 붙는다 - 눈덩이 2번 = 1.5 + 9 + 9 × 2 ≈ 29초) 중 큰 쪽
				local waitSeconds = math.max(16, (skill.telegraphSeconds or 0) + (skill.lifetimeSeconds or 0) + (skill.bounces or 0) * (skill.bounceLifetimeSeconds or 0) + 2)
				drive(player, root, model, data, waitSeconds, function()
					-- 이 스킬이 실제로 시작된 뒤(말풍선) 끝났는가 - Play 1: "#sent > 1"은 강제 직전 스킬의 reset 등으로 너무 일찍 참이 됐다(검증 쪽)
					return countKind("bubble") > 0 and st.phase == "normal" and st.current == nil and (not st.projectiles or #st.projectiles == 0)
				end)
				near1.debugAirborne = nil
				local ok, detail = true, ""
				local p = skill.primitive
				if p == "sector" then
					local telegraphs, payload = countKind("sector")
					local impacts = countKind("sectorImpact")
					local volleys = #BossSkillMath.volleysOf(skill)
					local shape = nil
					for _, j in ipairs(judged) do
						if j.shape and j.shape.kind == "sector" then
							shape = j.shape
						end
					end
					ok = telegraphs == volleys and impacts == volleys and shape ~= nil and payload ~= nil and near(shape.angleDeg, payload.angleDeg) and near(shape.widthDeg, payload.widthDeg) and near(shape.radius, payload.radius)
					detail = ("부채꼴 전조 %d · 판정 %d(기대 %d) · 판정 모양 = 전조(각 %.1f · 폭 %.0f · 반경 %.1f)"):format(telegraphs, impacts, volleys, payload and payload.angleDeg or -1, payload and payload.widthDeg or -1, payload and payload.radius or -1)
				elseif p == "projectile" then
					local spawns = countKind("projSpawn")
					local ends = countKind("projEnd")
					ok = spawns == (skill.count or 1) and ends == spawns
					detail = ("투사체 %d발(기대 %d) · 끝 %d"):format(spawns, skill.count or 1, ends)
				elseif p == "vortex" then
					ok = countKind("vortex") == 1 and countKind("vortexBurst") == 1
					detail = ("소용돌이 %d · 폭발 %d"):format(countKind("vortex"), countKind("vortexBurst"))
				elseif p == "circleTarget" and skill.chain then
					local _, payload = countKind("chain")
					ok = payload ~= nil and countKind("chainImpact") == #payload.positions and #payload.positions > 0
					detail = ("연쇄 원 %d · 솟음 %d"):format(payload and #payload.positions or -1, countKind("chainImpact"))
				elseif p == "circleTarget" and skill.ambush then
					ok = countKind("ambushDig") == 1 and countKind("ambushEmerge") == 1 and countKind("meteorLock") == 1
					detail = ("파고듦 %d · 추적 멈춤 %d · 솟음 %d"):format(countKind("ambushDig"), countKind("meteorLock"), countKind("ambushEmerge"))
				elseif p == "circleTarget" then
					local impacts = countKind("meteorImpact")
					local expected = skill.shots and #skill.shots or skill.count
					local radii = {}
					for _, e in ipairs(sent) do
						if e.kind == "meteorImpact" then
							table.insert(radii, ("%.1f"):format(e.payload.radius))
						end
					end
					ok = impacts == expected
					detail = ("연발 %d(기대 %d) · 반경 %s"):format(impacts, expected, table.concat(radii, "→"))
				elseif p == "line" then
					local fires = countKind("crossFire")
					local _, payload = countKind("cross")
					local expected = #BossSkillMath.volleysOf(skill)
					ok = fires == expected and (not skill.reflect or (payload and payload.segments and #payload.segments > 0))
					detail = ("볼리 %d(기대 %d)%s"):format(fires, expected, skill.reflect and (" · 반사 선분 %d"):format(payload and payload.segments and #payload.segments or 0) or "")
				elseif p == "ring" then
					local airWaves, total = 0, 0
					for _, e in ipairs(sent) do
						if e.kind == "shockwave" and (e.payload.layer or 1) == 1 then
							total += 1
							airWaves += e.payload.air and 1 or 0
						end
					end
					local expectAir = 0
					for _, w in ipairs(BossSkillMath.ringWaves(skill)) do
						expectAir += w.air and 1 or 0
					end
					ok = total == #BossSkillMath.ringWaves(skill) and airWaves == expectAir and expectAir >= 1
					detail = ("파동 %d · 공중 파동 %d(기대 %d)"):format(total, airWaves, expectAir)
				end
				r.check(("%s %s(%s): %s"):format(bossId, sid, p, detail), ok)
			end

			-- 대공 잡기: Air(연속 체공 ≥ N) 잡힘 · Late(판정 0.5초 전부터 떠 있음) 안 잡힘 · 던짐 = 현재 체력 50% · 다시 잡고 구출 → 기절
			local air = newStandIn(model, "Air", zone.center + Vector3.new(12, FLOOR + 3, 0))
			local late = newStandIn(model, "Late", zone.center + Vector3.new(-12, FLOOR + 3, 0))
			table.insert(standIns, air)
			table.insert(standIns, late)
			hook()
			air.debugAirborne = true
			BossPatterns.force(model, data, "grab")
			local telegraph = data.skills.grab.telegraphSeconds
			local forcedAt = os.clock()
			drive(player, root, model, data, telegraph + 1, function()
				if not late.debugAirborne and os.clock() - forcedAt >= telegraph - 0.4 then
					late.debugAirborne = true
				end
				return countKind("grabFreeze") > 0 or countKind("grabMiss") > 0 -- 사슬: 얼림 → 가까운 사람부터 잡기(grabPick)
			end)
			local airGrabbed = BossTrap.getRecord(air)
			local hpBefore = PlayerState.getHp(air)
			r.check(("%s 대공 잡기: 연속 체공 ≥ %.1f초 잡힘 %s(종류 %s) · 판정 0.4초 전부터 뜬 사람 안 잡힘 %s"):format(bossId, BossData.mechanics.airGrab.airSeconds,
				tostring(airGrabbed ~= nil), tostring(airGrabbed and airGrabbed.kind), tostring(BossTrap.getRecord(late) == nil)), airGrabbed ~= nil and airGrabbed.kind == "grabbed" and BossTrap.getRecord(late) == nil)
			air.debugAirborne, late.debugAirborne = nil, nil
			drive(player, root, model, data, BossData.mechanics.airGrab.holdSeconds + 1.5, function()
				return st.phase == "normal" and st.current == nil
			end)
			local hpAfter = PlayerState.getHp(air)
			r.check(("%s 던짐: 풀림 %s · 체력 %.1f → %.1f(기대 현재 체력의 50%% 감소) · 스킬 끝"):format(bossId, tostring(BossTrap.getRecord(air) == nil), hpBefore, hpAfter),
				BossTrap.getRecord(air) == nil and near(hpAfter, hpBefore * (1 - BossData.mechanics.airGrab.currentHpFraction), 0.02 * hpBefore) and st.phase == "normal")
			-- 구출 → 기절
			fullHeal(air)
			air.debugAirborne = true
			BossPatterns.force(model, data, "grab")
			drive(player, root, model, data, telegraph + 1, function()
				return BossTrap.getRecord(air) ~= nil
			end)
			air.debugAirborne = nil
			local record = BossTrap.getRecord(air)
			if record then
				BossTrap.completeHold(air, record, late) -- 동료(Late)가 F 홀드를 끝까지 눌렀다
			end
			drive(player, root, model, data, 0.5, function()
				return st.phase == "grabStun"
			end)
			r.check(("%s 구출 → 보스 기절: 풀림 %s · 단계 %s(기대 grabStun) · 기절 %.1f초"):format(bossId, tostring(BossTrap.getRecord(air) == nil), tostring(st.phase), BossData.mechanics.airGrab.stunSeconds),
				record ~= nil and BossTrap.getRecord(air) == nil and st.phase == "grabStun")
			drive(player, root, model, data, BossData.mechanics.airGrab.stunSeconds + 0.5, function()
				return st.phase == "normal"
			end)
		end)

		r.section(("환경 변화 %s"):format(bossId), function()
			local model, data, encounter = spawnBoss(player, env, bossId, 800 + bossIndex)
			assert(model, "보스 스폰 실패")
			local zone = WorldConfig.zones[encounter.zoneKey]
			root.Anchored = true
			root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 3, 60))
			local victim, victimRoot = newStandIn(model, "EnvVictim", zone.center + Vector3.new(0, FLOOR + 3, 30))
			table.insert(standIns, victim)
			local st = MonsterState.getBossPatternState(model)
			local envData = data.environment
			hook()
			st.env = { phase = "armed", phaseEndsAt = 0, taken = {} } -- 체력 50%를 지난 것으로
			st.graceUntil = os.clock() + 999 -- 기본 패턴은 멈춘다(환경만 본다)
			drive(player, root, model, data, 2, function()
				return countKind("envTelegraph") > 0
			end)
			local _, telegraphPayload = countKind("envTelegraph")
			assert(telegraphPayload, "환경 전조 없음")
			-- 스탠드인을 첫 위험 구역 안에 세운다(모양별 대표 자리)
			local z = telegraphPayload.zones[1]
			if z then
				local c = Vector3.new(z.center.X, FLOOR + 3, z.center.Z)
				if z.shape == "ring" then
					victimRoot.Position = c + Vector3.new(z.beyond + 10, 0, 0)
				elseif z.shape == "wind" then
					local a = math.rad(z.angleDeg)
					victimRoot.Position = c + Vector3.new(math.cos(a), 0, math.sin(a)) * (z.beyond + 10)
				else
					victimRoot.Position = c
				end
			end
			drive(player, root, model, data, envData.telegraphSeconds + 0.5, function()
				return countKind("envStart") > 0
			end)
			fullHeal(victim) -- Play 2(검증 쪽): 활성 순간 피해(밥상뒤집기 ×2.5)로 거의 죽은 뒤 도트를 재면 모자라 보였다 - 도트만 잰다
			local hp0 = PlayerState.getHp(victim)
			local costs = drive(player, root, model, data, 1.6)
			local hp1 = PlayerState.getHp(victim)
			if envData.kind == "cores" then
				local parts, cores = BossEnvironment.debugGarden(model)
				r.check(("%s 환경 %s: 전조 %.1f초 → 정원 파트 %d(기대 %d) · 핵 %d(기대 2)"):format(bossId, envData.id, envData.telegraphSeconds, parts, envData.garden.platformCount * 2, cores),
					parts == envData.garden.platformCount * 2 and cores == 2)
				st.env.phaseEndsAt = os.clock() -- 시간 넘김 → 수정 폭풍(첫 실패 55%)
				drive(player, root, model, data, 0.5, function()
					return countKind("envEnd") > 0
				end)
				local hp2 = PlayerState.getHp(victim)
				local partsAfter = BossEnvironment.debugGarden(model)
				local maxHp = PlayerState.getMaxHp(victim)
				r.check(("%s 정원 실패: 수정 폭풍 %.0f%%(기대 첫 실패 %.0f%%) · 끝나면 파트 %d(기대 0)"):format(bossId, (hp1 - hp2) / maxHp * 100, BossData.mechanics.gimmickFail.firstMaxHpFraction * 100, partsAfter),
					near((hp1 - hp2) / maxHp, BossData.mechanics.gimmickFail.firstMaxHpFraction, 0.02) and partsAfter == 0)
			else
				local expected = math.floor(1.6 / envData.tick.seconds) * envData.tick.fraction * PlayerState.getMaxHp(victim)
				r.check(("%s 환경 %s: 전조 %.1f초 → 구역 %d개 · 구역 안 1.6초 도트 %.1f(기대 약 %.1f - %.0f%%/%.1f초)%s"):format(bossId, envData.id, envData.telegraphSeconds, #telegraphPayload.zones,
					hp0 - hp1, expected, envData.tick.fraction * 100, envData.tick.seconds, envData.onStart and " · 활성 순간 튕김 + 피해" or ""),
					#telegraphPayload.zones >= 1 and hp0 - hp1 >= expected * 0.6)
				st.env.phaseEndsAt = os.clock()
				drive(player, root, model, data, 0.5, function()
					return countKind("envEnd") > 0
				end)
				r.check(("%s 환경 끝 신호 %d"):format(bossId, countKind("envEnd")), countKind("envEnd") == 1)
			end
			local avg, peak = stats(costs)
			perf[bossId] = { envAvg = avg, envPeak = peak }
		end)
	end

	-- 12인 최악 조건: 스탠드인 12 · 환경 활성 + 가장 무거운 새 패턴 겹침 - 보스 step 시간
	r.section("12인 성능", function()
		for bossIndex, bossId in ipairs(ALL_BOSSES) do
			local model, data, encounter = spawnBoss(player, env, bossId, 900 + bossIndex)
			local zone = WorldConfig.zones[encounter.zoneKey]
			root.Anchored = true
			root.CFrame = CFrame.new(zone.center + Vector3.new(0, FLOOR + 3, 60))
			for i = 1, 11 do
				local a = i / 11 * 2 * math.pi
				local s = newStandIn(model, "P" .. i, zone.center + Vector3.new(math.cos(a) * 25, FLOOR + 3, math.sin(a) * 25))
				s.debugAirborne = (i % 3 == 0) or nil
				table.insert(standIns, s)
			end
			local st = MonsterState.getBossPatternState(model)
			st.env = { phase = "armed", phaseEndsAt = 0, taken = {} }
			drive(player, root, model, data, data.environment.telegraphSeconds + 0.5, function()
				return st.env.phase == "active"
			end)
			local heavy = NEW_SKILLS[bossId][#NEW_SKILLS[bossId]]
			BossPatterns.force(model, data, heavy)
			local costs = drive(player, root, model, data, 4)
			local avg, peak = stats(costs)
			perf[bossId] = perf[bossId] or {}
			perf[bossId].p12Avg, perf[bossId].p12Peak = avg, peak
			r.check(("12인 %s: 환경 %s + %s 겹침 - 보스 step 평균 %.0fμs · 최대 %.0fμs(허용 평균 ≤ 1000 · 최대 ≤ 8000)"):format(bossId, data.environment.id, heavy, avg, peak), avg <= 1000 and peak <= 8000)
			clearStandIns(player, standIns)
			BossEncounter.despawnFor(player)
		end
	end)
	for _, bossId in ipairs(ALL_BOSSES) do
		local p = perf[bossId] or {}
		r.note(("성능 %s: 환경 활성 1인 step 평균 %.0fμs · 최대 %.0fμs | 12인 겹침 평균 %.0fμs · 최대 %.0fμs"):format(bossId, p.envAvg or -1, p.envPeak or -1, p.p12Avg or -1, p.p12Peak or -1))
	end
	root.Anchored = false
	BossEncounter.despawnFor(player)
	-- 검증 뒤 encounter 없는 보스 모델 0(COMMON §3)
	local orphans = 0
	for _, m in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphans += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphans), orphans == 0)
	local passed, total = r.summary()
	print(("===BR1 검증 끝(나)=== %d/%d 통과"):format(passed, total))
end

return BR1Verify
