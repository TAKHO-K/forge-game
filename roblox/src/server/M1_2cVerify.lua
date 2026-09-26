-- M1-2c 자동 검증(점프대 × 높이 검사 · 발사 허가 · 도착 대기 · 덩굴 리프트). (가) = 서버 시작 때 순수 계산 · (나) = 검증 체인 끝(실제 Player · 실제 서버 경로).
--   (가) 설계 정점 표(점프대 · 통통 열매 - 클라 궤적 적분과 대조) · 허가 합성 표본(점프대 + 공중 점프 2 + 대시 · 허가 없음 · 넘침 · 착지 · 최근 것만 · 활공 · 보스 공중 피격 · 던지기 속도 · 안 쓴 허가) ·
--        위치 기록 판정(LaunchPermit.checkHistory) · 보스 발사 설계 높이 표
--   (나) 나무 점프대 · 통통 열매 전부 실제 발사(높이 검증 켬) → 되돌림 0 · 허가 없이 같은 높이 → 되돌림 · 보스 발사 최대(넉백 · 회오리 · 토네이도 · 던지기 · 판 털기(땅 · 공중) · 파편) → 되돌림 0 ·
--        덩굴 리프트 [F] · 도착 대기(리프트 · 허브 귀환 · 포탈 · 관문 → 아레나 · 아레나 → 관문 앞 낙하 없음)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)

local M1_2cVerify = {}

local PERMIT = MovementConfig.permit
local G = MovementConfig.gravity
local ROOT_ABOVE = MovementConfig.rootAboveFeetStuds

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1-2c][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1-2c][%s] %s"):format(tag, label))
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

-- 나무 발사 요소 목록(요소 번호 · 설계)
local function treeLaunches()
	local list = {}
	for i in ipairs(WorldMapLayout.tree().elements) do
		local spec = WorldMapLayout.treeLaunch(i)
		if spec then
			table.insert(list, { id = i, spec = spec })
		end
	end
	return list
end

-- 보스 발사 설계(데이터에서 - 최대값). escape = 상한 없이(맵 밖이면 기존 복귀)
local function bossLaunches()
	local storm = BossData.bosses.storm_lord.skills
	local strike = storm.strike.onHit[1]
	local whirl = storm.whirl.onHit[1]
	local tornado = storm.tornado.onHit[1]
	local pan = BossData.bosses.abyssal_lord.environment.onStart.pan
	local throw = BossData.mechanics.airGrab.throw
	local topBreak = BossArenaMapData.obstacle.topBreak
	local R = BossArenaMapData.geometry and BossArenaMapData.geometry.radiusStuds or 140
	return {
		{ name = "넉백(폭풍 내려치기 · 4명 함께)", effect = { type = "launch", heightStuds = strike.heightStuds, distanceStuds = strike.distanceStuds, extraHeightPerCoHit = strike.extraHeightPerCoHit, maxHeightStuds = strike.maxHeightStuds }, coHits = 4, height = strike.maxHeightStuds },
		{ name = "회오리(붙잡힘 1.5초)", effect = whirl, coHits = 1, height = whirl.heightStuds },
		{ name = "토네이도(붙잡힘)", effect = tornado, coHits = 1, height = tornado.heightStuds },
		{ name = "잡아 던지기(최대 거리 · escape)", effect = { type = "launch", heightStuds = throw.heightStuds, distanceStuds = R * 2 - throw.wallMarginStuds, escape = true }, coHits = 1, height = throw.heightStuds },
		{ name = "판 털기(땅 · 최대 거리)", effect = { type = "launch", heightStuds = pan.heightStuds, distanceStuds = pan.distanceStuds + pan.distanceJitter, escape = true }, coHits = 1, height = pan.heightStuds },
		{ name = "판 털기(공중 피격 · 최대 세기)", effect = { type = "launch", heightStuds = pan.heightStuds + pan.airborneHeightBonus, distanceStuds = (pan.distanceStuds + pan.distanceJitter) * pan.airborneDistanceScale, escape = true },
			coHits = 1, height = pan.heightStuds + pan.airborneHeightBonus, airborne = true },
		{ name = "구조물 파편 튕김", effect = { type = "launch", heightStuds = topBreak.heightStuds, distanceStuds = topBreak.distanceStuds }, coHits = 1, height = topBreak.heightStuds, debris = true },
	}
end
M1_2cVerify.bossLaunches = bossLaunches

-- 합성 체공(0.25초 폴링 표본). events: 점프대 비행(v0) → 정점마다 공중 점프 airJumps번(스택형 - 정점에서) → 대시 hold초(높이 고정) → 착지 landY. 반환 = 표본 목록 { t, feetY, grounded, pos }
local function simulate(opts)
	local dt = 1 / 240
	local t, y, vy = 0, opts.startFeet, opts.vy
	local x = 0
	local jumpsLeft, holdLeft = opts.airJumps or 0, opts.dashHold or 0
	local samples, nextSample = {}, opts.firstSampleAt or 0.25
	local rise = JumpMath.airJumpRise(JumpMath.jumpHeight(MovementConfig.jumpHeightBonusCap))
	local peak = y
	table.insert(samples, { t = 0, feetY = opts.startFeet, grounded = true, pos = Vector3.new(0, opts.startFeet + ROOT_ABOVE, 0) })
	local landed = false
	while t < (opts.maxSeconds or 12) do
		t += dt
		x += (opts.flatSpeed or 0) * dt
		if opts.glideSpeed and vy < 0 and t > (opts.glideAfter or 0) then
			vy = -opts.glideSpeed -- 활공: 천천히 내려온다
		elseif opts.climbAt and t >= opts.climbAt and t < opts.climbAt + 0.6 then
			vy = 50 -- 활공 중 다시 오르기(부정 흉내)
		elseif holdLeft > 0 and vy <= 0 and jumpsLeft == 0 then
			holdLeft -= dt
			vy = 0
		else
			vy -= G * dt
		end
		if vy <= 0 and jumpsLeft > 0 then
			vy = JumpMath.upSpeed(rise)
			jumpsLeft -= 1
		end
		y += vy * dt
		peak = math.max(peak, y)
		if y <= opts.landY and vy < 0 and t > 0.1 then
			y = opts.landY
			landed = true
		end
		if t >= nextSample then
			nextSample += 0.25
			table.insert(samples, { t = t, feetY = y, grounded = landed, pos = Vector3.new(x, y + ROOT_ABOVE, 0) })
			if landed then
				break
			end
		end
	end
	return samples, peak
end

-- 표본 목록을 evaluate에 넣는다. grants = { { at, maxFeetY(여유 전), seconds } } · 반환: 되돌림 수
local function runGuard(samples, grants, st)
	local HeightGuard = require(script.Parent.HeightGuard)
	st = st or HeightGuard.newState()
	local reverts = 0
	local gi = 1
	for _, s in ipairs(samples) do
		while grants and grants[gi] and grants[gi].at <= s.t do
			HeightGuard.grantAt(st, grants[gi].maxFeetY + PERMIT.marginStuds, grants[gi].seconds, "합성", 100 + grants[gi].at)
			gi += 1
		end
		local verdict = HeightGuard.evaluate(st, { feetY = s.feetY, pos = s.pos, grounded = s.grounded, skip = false }, 100 + s.t)
		if verdict == "revert" then
			reverts += 1
		end
	end
	return reverts, st
end

-- ─────────────────────────── (가) ───────────────────────────
function M1_2cVerify.runPure()
	print("===M1-2c 검증 시작(가)===")
	local r = newRecorder("가")
	local HeightGuard = require(script.Parent.HeightGuard)
	local LaunchPermit = require(script.Parent.LaunchPermit)
	local allowance = JumpMath.heightGuardAllowance()
	local airOnly = JumpMath.airJumpsOnlyStuds()

	r.section("설계 정점 표", function()
		local C = WorldMapData.hub.tree.course
		local rows, worstGap, overAllowance, pads, bounces = {}, 0, 0, 0, 0
		local okAll = true
		for _, item in ipairs(treeLaunches()) do
			local s = item.spec
			local measured = -math.huge
			for _, lift in ipairs({ 0, C.launchProbeStuds - ROOT_ABOVE }) do
				local fromFeet = s.top + lift
				local vy
				if s.kind == "pad" then
					local el = WorldMapLayout.tree().elements[item.id]
					local v = JumpMath.arcLaunch(Vector3.new(el.center.X, fromFeet + ROOT_ABOVE, el.center.Z), s.target, C.pad.flightSeconds)
					vy = v.Y
				else
					vy = math.sqrt(2 * G * C.bounce.reachStuds)
				end
				-- 클라와 같은 식(점프대는 매 프레임 v0 − g·t로 덮는다 = 포물선)을 1/240초로 적분
				local y, v, t = fromFeet, vy, 0
				while v > 0 and t < 3 do
					t += 1 / 240
					v -= G / 240
					y += v / 240
				end
				measured = math.max(measured, y)
			end
			local gap = s.flightApexFeetY - measured
			worstGap = math.max(worstGap, math.abs(gap))
			okAll = okAll and gap >= -0.3 and gap <= 1.0
			local rise = s.flightApexFeetY - s.top
			if rise > allowance then
				overAllowance += 1
			end
			if s.kind == "pad" then
				pads += 1
			else
				bounces += 1
			end
			table.insert(rows, ("%s%d 윗면 %.0f · 비행 정점 +%.1f(적분 +%.1f) · 허가 +%.1f"):format(s.kind == "pad" and "점프대" or "열매", item.id, s.top, rise, measured - s.top, s.apexFeetY + PERMIT.marginStuds - s.top))
		end
		r.note("설계 정점 표: " .. table.concat(rows, " / "))
		r.check(("점프대 %d · 통통 열매 %d: 설계 정점 = 클라 궤적 적분(최대 차 %.2f) · 비행 정점이 평소 허용 %.2f를 넘는 것 %d개(= 옛 되돌림 원인 - 공중 점프 몫 %.2f + 여유 %d를 더해 허가)"):format(
			pads, bounces, worstGap, allowance, overAllowance, airOnly, PERMIT.marginStuds), okAll and pads >= 6 and overAllowance >= 1)
	end)

	-- 가장 높은 점프대 하나로 합성 체공
	local worst
	for _, item in ipairs(treeLaunches()) do
		if item.spec.kind == "pad" and (not worst or item.spec.flightApexFeetY - item.spec.top > worst.spec.flightApexFeetY - worst.spec.top) then
			worst = item
		end
	end
	local function padFlight(extra)
		local s = worst.spec
		local el = WorldMapLayout.tree().elements[worst.id]
		local from = Vector3.new(el.center.X, s.top + 1.5 + ROOT_ABOVE, el.center.Z)
		local v = JumpMath.arcLaunch(from, s.target, WorldMapData.hub.tree.course.pad.flightSeconds)
		local o = { startFeet = s.top + 1.5, vy = v.Y, landY = s.target.Y - WorldMapData.hub.tree.course.pad.landRootAboveStuds, flatSpeed = 30 }
		for k, val in pairs(extra or {}) do
			o[k] = val
		end
		return simulate(o)
	end

	r.section("허가 합성 표본", function()
		local s = worst.spec
		local grant = { { at = 0.15, maxFeetY = s.apexFeetY, seconds = PERMIT.padSeconds } }
		local samples, peak = padFlight({ airJumps = 2, dashHold = 0.3 })
		local reverts = runGuard(samples, grant)
		r.check(("점프대 %d + 공중 점프 2(정점마다) + 대시 0.3초 · 허가 0.15초 뒤(지연): 발 정점 +%.1f ≤ 허가 +%.1f · 되돌림 %d(기대 0)"):format(worst.id, peak - s.top, s.apexFeetY + PERMIT.marginStuds - s.top, reverts),
			reverts == 0 and peak <= s.apexFeetY + PERMIT.marginStuds)
		local noPermit = runGuard(samples, nil)
		r.check(("같은 궤적 · 허가 없음(점프대 안 밟고 같은 높이) → 되돌림 %d(기대 ≥ 1)"):format(noPermit), noPermit >= 1)
		local over = select(1, padFlight({ airJumps = 4 }))
		local overReverts = runGuard(over, grant)
		r.check(("허가 뒤 공중 점프 4번(허가 높이를 넘김) → 되돌림 %d(기대 ≥ 1)"):format(overReverts), overReverts >= 1)
		-- 착지하면 끝: 한 번 날고 착지 → 같은 비행을 허가 없이 한 번 더
		local st = HeightGuard.newState()
		runGuard(samples, grant, st)
		local landed = st.permit == nil and st.landings >= 1
		local again = {}
		local last = samples[#samples].t
		for _, x in ipairs(samples) do
			table.insert(again, { t = last + 0.25 + x.t, feetY = x.feetY, grounded = x.grounded, pos = x.pos })
		end
		local secondReverts = runGuard(again, nil, st)
		r.check(("착지 → 허가 끝 %s · 같은 비행을 허가 없이 다시 → 되돌림 %d(기대 ≥ 1)"):format(tostring(landed), secondReverts), landed and secondReverts >= 1)
		-- 가장 최근 것만: 높은 허가(+60) 뒤 낮은 허가(평소 + 1) → 점프대 비행 → 되돌림
		local latest = runGuard(samples, { { at = 0.05, maxFeetY = s.top + 60, seconds = 4 }, { at = 0.1, maxFeetY = s.top + allowance - PERMIT.marginStuds + 1, seconds = 4 } })
		r.check(("겹쳐 쌓지 않음: 높은 허가 → 낮은 허가(마지막) → 점프대 높이 비행 = 되돌림 %d(기대 ≥ 1)"):format(latest), latest >= 1)
		-- 활공(시간 상한 4초를 넘겨 천천히 내려옴) → 되돌림 0 · 상한 뒤 다시 오르기(+25) → 되돌림
		local glide = select(1, padFlight({ glideSpeed = 3, glideAfter = 0.6, landY = s.top - 400, maxSeconds = 9 }))
		local glideReverts = runGuard(glide, grant)
		local climb = select(1, padFlight({ glideSpeed = 3, glideAfter = 0.6, climbAt = 6, landY = s.top - 400, maxSeconds = 9 }))
		local climbReverts = runGuard(climb, grant)
		r.check(("활공(9초 · 초당 3 하강 - 상한 %d초 넘김) → 되돌림 %d(기대 0) · 상한 뒤 다시 오르기 → 되돌림 %d(기대 ≥ 1)"):format(PERMIT.padSeconds, glideReverts, climbReverts), glideReverts == 0 and climbReverts >= 1)
		-- 안 쓴 허가: 받고 1초 넘게 서 있으면 끝 → 그 뒤 같은 높이 비행 → 되돌림
		local stU = HeightGuard.newState()
		HeightGuard.evaluate(stU, { feetY = s.top, pos = Vector3.new(0, s.top + 3, 0), grounded = true }, 100)
		HeightGuard.grantAt(stU, s.apexFeetY + PERMIT.marginStuds, PERMIT.padSeconds, "합성", 100.05)
		for k = 1, 5 do
			HeightGuard.evaluate(stU, { feetY = s.top, pos = Vector3.new(0, s.top + 3, 0), grounded = true }, 100 + k * 0.25)
		end
		r.check(("안 쓴 허가(공중 없이 %.1f초 서 있음) → 끝 %s"):format(PERMIT.unusedSeconds, tostring(stU.permit == nil)), stU.permit == nil)
	end)

	r.section("보스 발사 합성", function()
		-- 공중에서 맞음: 서버가 본 발은 늦어서 +5(실제 +20) · 판 털기 공중 최대 세기 → 공중 점프 2 → 되돌림 0
		for _, b in ipairs(bossLaunches()) do
			local st = HeightGuard.newState()
			HeightGuard.evaluate(st, { feetY = 0, pos = Vector3.new(0, 3, 0), grounded = true }, 100)
			local actualFeet = b.airborne and allowance - 1 or 0
			local seenFeet = b.airborne and 5 or 0
			local base = HeightGuard.launchBaseFeet(st, seenFeet, not b.airborne)
			local up = b.height
			local air = JumpMath.launchAirSeconds(up) + (b.effect.holdSeconds or 0) + (b.effect.escape and 1.5 or 0)
			local grants = { { at = 0.1, maxFeetY = base + up + airOnly, seconds = air + PERMIT.bossExtraSeconds } }
			local distance = b.effect.distanceStuds or 0
			local samples, peak = simulate({ startFeet = actualFeet, vy = JumpMath.upSpeed(up), airJumps = 2, dashHold = b.effect.holdSeconds or 0, landY = -30, flatSpeed = distance / math.max(JumpMath.launchAirSeconds(up), 0.1) })
			samples[1].grounded = not b.airborne
			local reverts = runGuard(samples, grants, st)
			r.check(("%s: 높이 %.1f · 거리 %.0f(초당 %.0f)%s · 발 정점 %.1f ≤ 허가 %.1f · 되돌림 %d(기대 0)"):format(b.name, up, distance, distance / math.max(JumpMath.launchAirSeconds(up), 0.1),
				b.airborne and (" · 공중 피격(실제 발 %.1f · 서버가 본 발 %.1f)"):format(actualFeet, seenFeet) or "", peak, base + up + airOnly + PERMIT.marginStuds, reverts), reverts == 0)
		end
	end)

	r.section("위치 기록 판정", function()
		local spec = { top = 100, center = Vector3.new(0, 100, 0), radius = 2.6, apexFeetY = 150 }
		local onPad = { { t = 9.7, pos = Vector3.new(1, 103, 0) }, { t = 9.9, pos = Vector3.new(6, 118, 3) }, { t = 10, pos = Vector3.new(12, 130, 5) } }
		local ok1 = LaunchPermit.checkHistory(spec, onPad, 10)
		local far = { { t = 9.7, pos = Vector3.new(40, 103, 0) }, { t = 10, pos = Vector3.new(44, 130, 5) } }
		local ok2 = LaunchPermit.checkHistory(spec, far, 10)
		local old = { { t = 9.2, pos = Vector3.new(1, 103, 0) }, { t = 10, pos = Vector3.new(14, 130, 5) } }
		local ok3 = LaunchPermit.checkHistory(spec, old, 10)
		r.check(("최근 %.1f초 안에 발판 위 표본(지금은 평면 13 · 높이 +27) → %s(기대 true) · 발판 근처에 없었음 → %s(기대 false) · 0.8초 전에만 있었음 → %s(기대 false)"):format(
			PERMIT.historySeconds, tostring(ok1), tostring(ok2), tostring(ok3)), ok1 and not ok2 and not ok3)
	end)

	local pass, total = r.summary()
	print(("===M1-2c 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function M1_2cVerify.runLive(player, env)
	print("===M1-2c 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local HeightGuard = require(script.Parent.HeightGuard)
	local LaunchPermit = require(script.Parent.LaunchPermit)
	local Travel = require(script.Parent.Travel)
	local WorldMap = require(script.Parent.WorldMap)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossPatterns = require(script.Parent.BossPatterns)
	local MonsterState = require(script.Parent.MonsterState)
	local BossArenaContainment = require(script.Parent.BossArenaContainment)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	assert(root and humanoid, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
	end
	local function flight(seconds)
		local peak = root.Position.Y
		local t0 = os.clock()
		while os.clock() - t0 < seconds do
			task.wait(0.03)
			peak = math.max(peak, root.Position.Y)
		end
		return peak - ROOT_ABOVE
	end

	r.section("나무 발사 전부(높이 검증 켬)", function()
		HeightGuard.debugOff = false
		local course = WorldMap.model("TreeCourse")
		local partOf = {}
		for _, part in ipairs(course:GetDescendants()) do
			local id = part:GetAttribute("TreePad") or (part:GetAttribute("TreeFruit") == "bounce" and part:GetAttribute("FruitId"))
			if id then
				partOf[id] = part
			end
		end
		local rows, totalReverts, launched, permitsBefore = {}, 0, 0, LaunchPermit.stats.granted
		for _, item in ipairs(treeLaunches()) do
			local part = partOf[item.id]
			if part then
				-- 발판 위 +6에 붙잡아 두고(순간이동 유예 1초가 지나게 - 유예 중 발사는 허가 없이도 안 잡혀 검증이 무의미) 유예를 끈 뒤 놓는다 → 떨어져 밟고 발사
				local el = WorldMapLayout.tree().elements[item.id]
				local attachment = Instance.new("Attachment")
				attachment.Parent = root
				local align = Instance.new("AlignPosition")
				align.Mode = Enum.PositionAlignmentMode.OneAttachment
				align.Attachment0 = attachment
				align.RigidityEnabled = true
				align.Position = Vector3.new(el.center.X, item.spec.top + 6 + ROOT_ABOVE, el.center.Z)
				align.Parent = root
				put(align.Position)
				task.wait(0.7)
				local hs = HeightGuard.getState(player)
				hs.graceUntil = 0
				local reverts0 = hs.reverts
				align:Destroy()
				attachment:Destroy()
				local peakFeet = flight(2.6)
				local reverts = hs.reverts - reverts0
				totalReverts += reverts
				if peakFeet - item.spec.top > 8 then
					launched += 1
				end
				table.insert(rows, ("%s%d +%.1f(허가 +%.1f) 되돌림 %d"):format(item.spec.kind == "pad" and "점프대" or "열매", item.id, peakFeet - item.spec.top, item.spec.apexFeetY + PERMIT.marginStuds - item.spec.top, reverts))
			end
		end
		local granted = LaunchPermit.stats.granted - permitsBefore
		r.note("실측: " .. table.concat(rows, " / "))
		r.check(("나무 발사 %d/%d곳 실제로 떠오름 · 허가 %d장(늦게 온 위치로 확인 %d) · 되돌림 합 %d(기대 0)"):format(launched, #rows, granted, LaunchPermit.stats.deferred, totalReverts),
			totalReverts == 0 and launched == #rows and granted >= #rows and #rows >= 6)
	end)

	r.section("허가 없이 같은 높이(치트 방지 유지)", function()
		HeightGuard.debugOff = false
		put(WorldMapLayout.hubPoint(135, 150, 4))
		task.wait(1.2)
		HeightGuard.reset(player)
		task.wait(1.2)
		local st = HeightGuard.getState(player)
		local before = st.reverts
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local align = Instance.new("AlignPosition")
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Position = root.Position + Vector3.new(0, 36, 0) -- 점프대 비행 정점과 같은 높이(+36)
		align.Parent = root
		local t0 = os.clock()
		local caught
		while os.clock() - t0 < 3 do
			task.wait(0.05)
			if st.reverts > before then
				caught = os.clock() - t0
				break
			end
		end
		align:Destroy()
		attachment:Destroy()
		task.wait(0.8)
		r.check(("허브 바닥에서 점프대 없이 +36으로 → 되돌림 %s초 뒤(기대 ≤ 1.5)"):format(caught and ("%.2f"):format(caught) or "없음"), caught ~= nil and caught <= 1.5)
	end)

	r.section("보스 발사 최대(실제 서버 경로 runHitEffects)", function()
		local hook = ServerStorage:FindFirstChild("DevCommandHook")
		assert(hook, "DevCommandHook 없음")
		hook:Invoke(player, "/gg boss pattern storm_lord strike 15")
		task.wait(1.5)
		hook:Invoke(player, "/gg god on")
		local model = BossEncounter.getActive(player)
		assert(model, "보스 없음")
		BossPatterns.setOnlyPattern(model, MonsterState.getData(model), nil)
		HeightGuard.debugOff = false
		local st = MonsterState.getBossPatternState(model)
		BossPatterns.kit.stun(model, st, MonsterState.getData(model), 120) -- 자연 패턴이 끼어들지 않게(최대 수치 발사만 잰다 - 자연 패턴은 MCP 수동 확인)
		local zone = BossPatterns.kit.zoneOf(model)
		local patternEvent = ReplicatedStorage:FindFirstChild("BossPatternEvent")
		local total = 0
		for _, b in ipairs(bossLaunches()) do
			-- 보스에서 떨어진 자리(바깥쪽으로 날아가게) · 서 있게
			local spot = zone.center + Vector3.new(zone.radius * 0.35, 0, 0)
			put(Vector3.new(spot.X, (st.floorY or zone.center.Y) + 4, spot.Z))
			task.wait(1.2)
			local hs = HeightGuard.getState(player)
			local reverts0 = hs.reverts
			local returns0 = #BossArenaContainment.corrections()
			local startFeet = root.Position.Y - ROOT_ABOVE
			if b.airborne then
				humanoid.Jump = true
				task.wait(0.3) -- 올라가는 중(서버가 본 발은 늦다)
			end
			local from = root.Position - Vector3.new(5, 0, 0)
			if b.debris then
				HeightGuard.grantLaunch(player, b.height, JumpMath.launchAirSeconds(b.height), "파편 튕김(검증)")
				patternEvent:FireClient(player, "launch", { from = from, heightStuds = b.height, distanceStuds = b.effect.distanceStuds, zoneCenter = zone.center, zoneRadius = zone.radius })
			else
				local v = { player = player, root = root, feet = root.Position - Vector3.new(0, ROOT_ABOVE, 0), groundFeet = root.Position - Vector3.new(0, ROOT_ABOVE, 0) }
				BossPatterns.kit.runHitEffects({ model = model, st = st, data = MonsterState.getData(model), now = os.clock() }, { b.effect }, v, from, b.coHits)
			end
			local x0 = root.Position
			local peakFeet = root.Position.Y - ROOT_ABOVE
			local far = 0
			local t0 = os.clock()
			while os.clock() - t0 < 5 do
				task.wait(0.03)
				peakFeet = math.max(peakFeet, root.Position.Y - ROOT_ABOVE)
				far = math.max(far, Vector3.new(root.Position.X - x0.X, 0, root.Position.Z - x0.Z).Magnitude)
			end
			local reverts = hs.reverts - reverts0
			local returned = #BossArenaContainment.corrections() - returns0
			total += reverts
			r.check(("%s: 설계 높이 %.1f · 거리 %.0f → 실측 발 +%.1f · 수평 최대 %.0f · 맵 밖 복귀 %d · 되돌림 %d(기대 0)"):format(b.name, b.height, b.effect.distanceStuds or 0,
				peakFeet - startFeet, far, returned, reverts), reverts == 0)
		end
	end)
	-- 보스 절이 도중에 에러가 나도 보스 · 무적을 치운다(다음 절 - 보스전 중이면 리프트가 안 된다)
	pcall(function()
		ServerStorage.DevCommandHook:Invoke(player, "/gg god off")
	end)
	if BossEncounter.getEncounter(player) then
		BossEncounter.leaveFor(player)
	end
	BossEncounter.despawnFor(player)
	task.wait(0.8)

	r.section("덩굴 리프트 [F] · 도착 대기", function()
		HeightGuard.debugOff = true
		local L = WorldMapData.hub.tree.course.lift
		local count0 = require(script.Parent.TeleportArrival).count
		put(WorldMapLayout.hubPoint(L.angleDeg, L.r, 4))
		task.wait(0.8)
		local prompt
		for _, d in ipairs(WorldMap.model("Hub"):GetDescendants()) do
			if d:IsA("ProximityPrompt") and d.Name == "VineLiftPrompt" then
				prompt = d
			end
		end
		local best = Travel.rideLift(player)
		task.wait(0.4)
		local y0 = root.Position.Y
		task.wait(2)
		local drop = y0 - root.Position.Y
		local arrivals = require(script.Parent.TeleportArrival).count - count0
		r.check(("리프트 프롬프트 %s(키 %s · 거리 %s) · 타기 → 정거장 %s · 도착 뒤 2초 낙하 %.1f(기대 < 3) · 도착 알림 %d"):format(tostring(prompt ~= nil), prompt and prompt.KeyboardKeyCode.Name or "-",
			prompt and tostring(prompt.MaxActivationDistance) or "-", tostring(best), drop, arrivals), prompt ~= nil and best ~= nil and (best == 0 or drop < 3) and (best == 0 or arrivals >= 1))
		-- 먼 곳으로 순간이동 5곳: 도착 뒤 2초 동안 발이 3 넘게 떨어지지 않는다(발판 미로딩 낙하 없음)
		local rows, okAll = {}, true
		local function arrive(label, fn)
			fn()
			task.wait(0.3)
			local y1 = root.Position.Y
			local t0 = os.clock()
			local low = y1
			while os.clock() - t0 < 2 do
				task.wait(0.05)
				low = math.min(low, root.Position.Y)
			end
			local fell = y1 - low
			okAll = okAll and fell < 3
			table.insert(rows, ("%s 낙하 %.1f"):format(label, fell))
		end
		arrive("리프트 → 정거장", function()
			put(WorldMapLayout.hubPoint(L.angleDeg, L.r, 4))
			task.wait(0.5)
			Travel.rideLift(player)
		end)
		arrive("허브 귀환", function()
			Travel.teleport(player, require(ReplicatedStorage.Shared.data.WorldConfig).zones.spawn.arrival + Vector3.new(0, WorldMapData.floorTopY + 3, 0), "검증 허브 귀환")
		end)
		arrive("포탈 → 캠프(tier1)", function()
			local z = WorldMapLayout.zoneByKey("tier1")
			Travel.teleport(player, WorldMapLayout.camp(z) + Vector3.new(0, 3, 0), "검증 포탈")
		end)
		arrive("관문 → 아레나", function()
			local hook = ServerStorage:FindFirstChild("DevCommandHook")
			hook:Invoke(player, "/gg boss pattern storm_lord strike 15")
			task.wait(1)
			local model = BossEncounter.getActive(player)
			if model then
				BossPatterns.setOnlyPattern(model, MonsterState.getData(model), nil)
			end
		end)
		arrive("아레나 → 관문 앞", function()
			BossEncounter.leaveFor(player)
		end)
		r.check(("순간이동 5곳 도착 직후 낙하 없음(< 3): %s"):format(table.concat(rows, " · ")), okAll)
	end)

	HeightGuard.debugOff = guardOff
	if BossEncounter.getEncounter(player) then
		BossEncounter.leaveFor(player)
	end
	local pass, total = r.summary()
	print(("===M1-2c 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return M1_2cVerify
