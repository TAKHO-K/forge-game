-- MV1 자동 검증(대시 개선 · 활강 · 낙하 · 공중 전투 · 환생 해금 · 태초 유틸). id = "MV1(가)" · "MV1(나)".
--   (가) 순수: 대시 거리(이속 16 · 20 · 24) · 짧게/길게 경계 · 2단 대시 충전 · 공중 공격 예산 · 활강 거리 · 게이지 · 낙하 속도별 결과 · 제외 · 해금표 ·
--        서버 체공 세션(AirState.step) · 높이 검증(활강 하강 · 붙잡기 허가 - 지연 0.25 표본) · 공중 vs 지상 DPS · 못 넘는 틈 · 도달성 요약(메모)
--   (나) 실제 서버: MoveTier · 대시(DashHook - 거리 · 공중 대시 횟수 · 2단 대시) · 공중 공격 예산 · 스택 초기화 · 공중 3타 강공격 게이트(AttackHook) ·
--        낙하 피해 · 쓰러짐 → 안전 지점 부활 · 제외(보스 · 나무 · 물 · 허가) · 붙잡기(LedgeClimbHook - 장갑 · 1회 · 불일치 · 허가) / 되돌림
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local MovementUnlockData = require(ReplicatedStorage.Shared.data.MovementUnlockData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local TextData = require(ReplicatedStorage.Shared.data.TextData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[MV1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[MV1][%s] %s"):format(tag, label))
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

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

function V.runPure()
	print("===MV1 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("대시 거리", function()
		local d16, d20, d24 = JumpMath.dashRangeStuds(1), JumpMath.dashRangeStuds(20 / 16), JumpMath.dashRangeStuds(24 / 16)
		r.check(("대시 거리 이속 16 = %.1f · 20 = %.1f · 24 = %.1f(기대 22 · 27.5 · 30.8 - 상한 ×%.1f) · 감속(×0.5) = %.1f(하한 기본)"):format(d16, d20, d24, DashConfig.speedScaleMax, JumpMath.dashRangeStuds(0.5)),
			near(d16, 22) and near(d20, 27.5) and near(d24, 30.8, 1e-6) and near(JumpMath.dashRangeStuds(0.5), 22))
		r.check(("기본 +%.1f%%(지시 30 ~ 50%%) · 환생 4 공중 대시 = %.1f"):format((DashConfig.rangeStuds / 16 - 1) * 100, JumpMath.dashRangeStuds(1, MovementUnlockData.tiers[4].airDashRangeMultiplier)),
			DashConfig.rangeStuds / 16 >= 1.3 and DashConfig.rangeStuds / 16 <= 1.5)
	end)

	r.section("짧게 · 길게 경계", function()
		local h = DashConfig.input.glideHoldSeconds
		local cases = {
			{ 0.10, true, true, "dash" }, { h - 0.01, true, true, "dash" }, { 0.10, false, true, "wait" }, { h, false, true, "glide" },
			{ h, false, false, "dash" }, { h + 0.2, true, false, "dash" }, { 0.2, true, false, "dash" },
		}
		local bad = {}
		for _, c in ipairs(cases) do
			local got = MoveRules.classifyPress(c[1], c[2], c[3])
			if got ~= c[4] then
				table.insert(bad, ("%.2f초 %s %s → %s(기대 %s)"):format(c[1], c[2] and "뗌" or "누르는 중", c[3] and "활강 가능" or "활강 불가", got, c[4]))
			end
		end
		r.check(("누름 판정 %d경우(경계 %.2f초 · 공중 길게 = 활강 · 해금 전 길게 = 대시): 틀림 %d %s"):format(#cases, h, #bad, table.concat(bad, " / ")), #bad == 0)
	end)

	r.section("2단 대시", function()
		local st = MoveRules.newDashState()
		local a = { MoveRules.tryDash(st, 100, 1) }
		local b = { MoveRules.tryDash(st, 100.4, 1) }
		local c = { MoveRules.tryDash(st, 108.01, 1) }
		r.check(("일반: 첫 %s · 0.4초 뒤 %s(%s) · 8초 뒤 %s"):format(tostring(a[1]), tostring(b[1]), tostring(b[2]), tostring(c[1])), a[1] and not b[1] and b[2] == "cooldown" and c[1])
		local p = MoveRules.newDashState()
		local p1 = { MoveRules.tryDash(p, 100, 2) }
		local busy = { MoveRules.tryDash(p, 100.1, 2) }
		local p2 = { MoveRules.tryDash(p, 100.4, 2) }
		local p3 = { MoveRules.tryDash(p, 101, 2) }
		local p4 = { MoveRules.tryDash(p, 108.39, 2) }
		local p5 = { MoveRules.tryDash(p, 108.41, 2) }
		r.check(("태초 신발: 첫 %s · 0.1초(대시 중) %s · 0.4초 두 번째 %s · 1초 %s(%s) · 두 번째 + 7.99초 %s · + 8.01초 %s"):format(tostring(p1[1]), tostring(busy[2]), tostring(p2[3]), tostring(p3[1]), tostring(p3[2]), tostring(p4[1]), tostring(p5[1])),
			p1[1] and busy[2] == "busy" and p2[1] and p2[3] and not p3[1] and not p4[1] and p5[1])
		local m = MoveRules.newDashState()
		MoveRules.tryDash(m, 100, 2)
		local late = { MoveRules.tryDash(m, 100 + DashConfig.primordialShoes.chainWindowSeconds + 0.1, 2) }
		local after = { MoveRules.tryDash(m, 108.01, 2) }
		r.check(("창(%.1f초)을 놓치면 두 번째 %s · 쿨다운 = 첫 대시부터(8.01초 %s)"):format(DashConfig.primordialShoes.chainWindowSeconds, tostring(late[1]), tostring(after[1])), not late[1] and after[1])
		r.check(("한 체공 공중 대시: 기본 %d · 태초 신발 %d"):format(MoveRules.airDashesAllowed(false), MoveRules.airDashesAllowed(true)), MoveRules.airDashesAllowed(false) == 1 and MoveRules.airDashesAllowed(true) == 2)
	end)

	r.section("해금표 · 공중 공격 예산", function()
		local rows, ok = {}, true
		local prev = nil
		for n = 0, 5 do
			local t = MovementUnlockData.tiers[n]
			local b0, b1 = MoveRules.airAttackBudget(t, 0), MoveRules.airAttackBudget(t, 1)
			table.insert(rows, ("환생%d 점프%d 공격%s 활강%s 3타%s 예산 %d/%d"):format(n, t.airJumps, tostring(t.airAttack), tostring(t.glide), tostring(t.airHeavy), b0, b1))
			if prev then
				ok = ok and t.airJumps >= prev.airJumps and (not prev.glide or t.glide) and (not prev.airHeavy or t.airHeavy)
			end
			prev = t
		end
		local t = MovementUnlockData.tiers
		ok = ok and t[0].airJumps == 0 and not t[0].airAttack and t[1].airJumps == 1 and t[1].airAttack and t[2].glide and t[3].airJumps == 2 and t[3].airHeavy
			and t[4].glideSecondsBonus > 0 and t[4].airDashRangeMultiplier > 1 and MoveRules.airAttackBudget(t[3], 1) == 3 and MoveRules.airAttackBudget(t[0], 1) == 0
		r.check(("해금표(단조 증가 · 지시 표): %s"):format(table.concat(rows, " | ")), ok)
		local long = {}
		for key, text in pairs(TextData.ko) do
			if key:find("^moveUnlock%.popup%.%d") and utf8.len(text) > 40 then
				table.insert(long, key)
			end
		end
		local missing = 0
		for n = 1, 5 do
			missing += (TextData.ko[MovementUnlockData.popups[n].textKey] and 0 or 1) + (TextData.ko[MovementUnlockData.rewardRows[n][1]] and 0 or 1)
		end
		r.check(("안내 한 줄 ≤ 40자: 넘음 %d · 문구 키 없음 %d · 3회 안내 = 공중 3타 강공격 %s"):format(#long, missing, tostring(TextData.ko["moveUnlock.popup.3"]:find("강공격") ~= nil)),
			#long == 0 and missing == 0 and TextData.ko["moveUnlock.popup.3"]:find("강공격") ~= nil)
	end)

	r.section("활강", function()
		local d2, h2, s2 = MoveRules.glideReach(MovementUnlockData.tiers[2])
		local d4, h4, s4 = MoveRules.glideReach(MovementUnlockData.tiers[4])
		r.check(("게이지 소진 활강: 환생 2 = %.0f초 · %.0f 전진 · %.0f 하강 / 환생 4 = %.0f초 · %.0f · %.0f"):format(s2, d2, h2, s4, d4, h4), near(d2, 240) and near(h2, 40) and s4 > s2)
		local g = 0
		for _ = 1, 20 do
			g = MoveRules.stepGauge(g, 8, 0.1, false, true)
		end
		local air = MoveRules.stepGauge(3, 8, 1, false, false)
		local used = MoveRules.stepGauge(8, 8, 8.5, true, false)
		r.check(("게이지: 빈 채 착지 2초 뒤 %.2f(가득 8) · 공중(활강 아님) 그대로 %.1f · 활강 8.5초 = %.1f(소진)"):format(g, air, used), near(g, 8, 1e-6) and air == 3 and used == 0)
	end)

	r.section("낙하", function()
		local F = MovementConfig.fall
		local sp = JumpMath.fallSpeedFromHeight
		local safe = MoveRules.fallSafeHeight()
		local o1, o2, o3, o4 = MoveRules.fallOutcome(sp(JumpMath.maxClimbStuds(2, false, 0.1))), MoveRules.fallOutcome(sp(safe + 0.25 * (F.lethalHeight - safe))), MoveRules.fallOutcome(sp((safe + F.lethalHeight) / 2)), MoveRules.fallOutcome(sp(F.lethalHeight) + 1e-6)
		local st3 = WorldMapLayout.stations()[3]
		r.check(("안전 높이 %.2f(합법 정점 + %d) · 정점 21.38 낙하 → %s · 1/4 높이 → %.1f%% · 가운데 → %.1f%% · 치명 %d(= 나무 세 번째 정거장 %.0f) → %s"):format(safe, F.safeMarginStuds, o1.kind, o2.fraction * 100, o3.fraction * 100, F.lethalHeight, st3.y - WorldMapData.floorTopY, o4.kind),
			o1.kind == "none" and near(o2.fraction, 0.25, 1e-6) and near(o3.fraction, 0.5, 1e-6) and o4.kind == "knockdown" and near(st3.y - WorldMapData.floorTopY, F.lethalHeight, 0.5))
		local nanOut = MoveRules.fallOutcome(0 / 0)
		r.check(("이상한 보고(NaN) → %s · 음수 → %s"):format(nanOut.kind, MoveRules.fallOutcome(-500).kind), nanOut.kind == "none" and MoveRules.fallOutcome(-500).kind == "none")
		local ex = {
			{ { inBoss = true }, "boss" }, { { inTree = true }, "tree" }, { { permitRecent = true }, "permit" }, { { fromLadder = true }, "ladder" }, { { inWater = true }, "water" }, { {}, nil },
		}
		local bad = 0
		for _, e in ipairs(ex) do
			bad += MoveRules.fallExcluded(e[1]) == e[2] and 0 or 1
		end
		r.check(("제외 사유 6경우(보스 · 나무 · 강제 체공 · 사다리 · 물 · 없음): 틀림 %d"):format(bad), bad == 0)
		local vs, vf, vl = MoveRules.fallSpeeds()
		r.note(("착지 속도 기준: 안전 %.0f · 불꽃(예상 피해 %d%%) %.0f · 치명 %.0f"):format(vs, F.flameWarnFraction * 100, vf, vl))
	end)

	r.section("서버 체공 세션(AirState.step)", function()
		local AirState = require(script.Parent.AirState)
		local st = { grounded = true, groundPos = nil, session = nil, sessionCount = 0, takeoffCount = 0 }
		local p0 = Vector3.new(1, 2, 3)
		AirState.step(st, true, p0, true, 0) -- 사다리 위
		local s1 = AirState.step(st, false, p0 + Vector3.new(0, 1, 0), false, 0.1)
		local counted0 = st.takeoffCount
		AirState.step(st, false, p0, false, 0.3)
		local counted1 = st.takeoffCount
		AirState.step(st, true, p0 + Vector3.new(5, 0, 0), false, 0.5)
		local bump = AirState.step(st, false, p0, false, 0.6)
		AirState.step(st, true, p0, false, 0.65)
		r.check(("사다리에서 뜸 → 세션 fromLadder %s · 이륙 자리 = 선 자리 %s · 0.15초 전 뜬 횟수 %d → 뒤 %d · 착지 뒤 lastSession 보존 %s · 요철 0.05초 = 안 셈(%d)"):format(
			tostring(s1 and s1.fromLadder), tostring(s1 and s1.takeoffPos == p0), counted0, counted1, tostring(st.lastSession ~= nil), st.takeoffCount),
			s1 ~= nil and s1.fromLadder == true and s1.takeoffPos == p0 and counted0 == 0 and counted1 == 1 and bump ~= nil and st.takeoffCount == 1)
	end)

	r.section("높이 검증(활강 · 붙잡기 - 지연 0.25 표본)", function()
		local HeightGuard = require(script.Parent.HeightGuard)
		-- 활강: 발 19.4(공중 점프 2 정점)에서 5/s로 내려가며 0.25초 폴링 · 기준 = 0
		local st = HeightGuard.newState()
		HeightGuard.evaluate(st, { feetY = 0, pos = Vector3.zero, grounded = true }, 0)
		local verdicts = {}
		local reverts = 0
		for i = 1, 40 do
			local t = i * 0.25
			local v = HeightGuard.evaluate(st, { feetY = 19.4 - MovementConfig.glide.descentSpeed * t, pos = Vector3.new(MovementConfig.glide.forwardSpeed * t, 0, 0), grounded = false }, t)
			reverts += (v == "revert" or v == "strike") and 1 or 0
			verdicts[v] = (verdicts[v] or 0) + 1
		end
		r.check(("활강 10초(하강 %d/s · 전진 %d/s · 폴링 0.25) 되돌림 · 경고 %d"):format(MovementConfig.glide.descentSpeed, MovementConfig.glide.forwardSpeed, reverts), reverts == 0)
		-- 붙잡기: 공중 점프 2 정점 19.4에서 모서리(손 높이 7.5 위 = 26.9)로 올라섬 - 지연 0.25: 서버는 한 폴링 늦게 모서리 위를 본다(허가는 매달리는 순간 요청 → 먼저 닿는다)
		local top = JumpMath.maxClimbStuds(2, true)
		local function climb(withPermit)
			local s = HeightGuard.newState()
			HeightGuard.evaluate(s, { feetY = 0, pos = Vector3.zero, grounded = true }, 0)
			if withPermit then
				HeightGuard.grantAt(s, top + MovementConfig.ledgeGrab.permitMarginStuds + MovementConfig.permit.marginStuds, MovementConfig.ledgeGrab.permitSeconds, "ledge", 0.3)
			end
			local out = {}
			local samples = { { 0.25, 12, false }, { 0.5, 19.4, false }, { 0.75, top - MovementConfig.ledgeGrab.hangBelowStuds + 3 - 3, false }, { 1.0, top + 0.2, false }, { 1.25, top, true }, { 1.5, top, true } }
			for _, sm in ipairs(samples) do
				table.insert(out, HeightGuard.evaluate(s, { feetY = sm[2], pos = Vector3.new(0, 0, 1), grounded = sm[3] }, sm[1]))
			end
			return out, s
		end
		local withP, s1 = climb(true)
		local noP = climb(false)
		local function has(list, v)
			return table.find(list, v) ~= nil
		end
		-- 허가 없음 = 모서리 위 공중 표본에서 경고(strike) - 되돌림은 옛 규칙대로 두 번 연속일 때(한 폴링 만에 올라서면 경고만 · S1 과제)
		r.check(("붙잡기 올라서기(발 0 → 모서리 %.1f): 허가 있음 %s(경고 · 되돌림 0 · 착지 뒤 기준 %.1f) / 허가 없음 %s(경고 생김)"):format(top, table.concat(withP, ","), s1.supportY or -1, table.concat(noP, ",")),
			not has(withP, "revert") and not has(withP, "strike") and near(s1.supportY, top) and (has(noP, "strike") or has(noP, "revert")))
		local okV, why = MoveRules.ledgeClimbValid(20, 20.5, 14)
		local _, why2 = MoveRules.ledgeClimbValid(26, 20, 14)
		local _, why3 = MoveRules.ledgeClimbValid(60, 60, 14)
		r.check(("서버 모서리 확인: 일치 %s · 불일치 %s · 마지막 지면 + 허용치 + 손 높이 넘음 %s"):format(tostring(okV), tostring(why2), tostring(why3)), okV and why2 == "mismatch" and why3 == "too_high")
	end)

	r.section("공중 vs 지상 DPS", function()
		local worst, rows = 0, {}
		for _, cls in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			for _, cap in ipairs({ 1, CombatConfig.attackSpeedMaxMultiplier }) do
				local cd = CombatConfig.attackCooldownSeconds / ClassData.classes[cls].atkSpeed / cap
				local tier = MovementUnlockData.tiers[3]
				local motionAir = require(ReplicatedStorage.Shared.data.AttackMotionData)[cls].air
				local air = JumpMath.maxAirSeconds(nil, tier.airJumps, DashConfig.durationSeconds, 0, nil, 16) + (motionAir.hoverSeconds or 0) * MoveRules.airAttackBudget(tier, 1) -- 원거리 공중 정지가 체공을 늘린다
				local groundHits = math.floor(air / cd) + 1
				local airHits = math.min(MoveRules.airAttackBudget(tier, 1), groundHits)
				local function dmg(n)
					local d = 0
					for i = 1, n do
						d += (i % CombatConfig.comboHitEvery == 0) and CombatConfig.comboHitMultiplier or 1
					end
					return d
				end
				local ratio = dmg(airHits) / dmg(groundHits)
				worst = math.max(worst, ratio)
				table.insert(rows, ("%s×%.1f %.2f"):format(cls, cap, ratio))
			end
		end
		r.check(("한 체공(환생 3 · 최대 %.2f초) 공중 피해 ÷ 같은 시간 지상 피해 ≤ 1: 최대 %.2f(%s)"):format(JumpMath.maxAirSeconds(nil, 2, DashConfig.durationSeconds, 0, nil, 16), worst, table.concat(rows, " · ")), worst <= 1)
	end)

	r.section("S1 · BR1-4에 넘길 값(MoveRules.s1Limits)", function()
		local S = MoveRules.s1Limits()
		r.check(("걷기 상한 %.0f · 대시 최대 %.1f(%.0f/s) · 활강 %.0f/s · 원거리 공중 정지 %.2f초 × %d = %.2f초 · 한 폴링 최대 이동 %.1f < 순간이동 판정 %d · 못 넘는 틈 %d / %d / %d · 못 오르는 벽 %.1f(붙잡기 %.1f)"):format(
			S.walkMax, S.dash.maxStuds, S.dash.maxSpeed, S.glide.forwardSpeed, S.rangedHover.seconds, S.rangedHover.perAirborneMax, S.rangedHover.totalSeconds, S.pollMaxStuds, MovementConfig.heightGuard.teleportResetStuds,
			S.unjumpableGap.walk16, S.unjumpableGap.walkMax, S.unjumpableGap.primordialWorst, S.unclimbableWall, S.unclimbableWallLedge),
			S.pollMaxStuds < MovementConfig.heightGuard.teleportResetStuds and S.rangedHover.seconds > 0)
	end)

	r.section("이동 기준(movement-metrics v3) · 도달성", function()
		local g16 = JumpMath.unjumpableGapStuds({ walk = 16, airJumps = 2, dashes = 1 })
		local g24 = JumpMath.unjumpableGapStuds({ walk = 24, airJumps = 2, dashes = 1, dashStuds = JumpMath.dashRangeStuds(1.5) })
		local gp = JumpMath.unjumpableGapStuds({ walk = 24, airJumps = 2, dashes = 2, dashStuds = JumpMath.dashRangeStuds(1.5, MovementUnlockData.tiers[4].airDashRangeMultiplier) })
		r.check(("못 넘는 틈(환생 3 · 대시 1): 걷기 16 = %d · 이속 상한 24 = %d · 최악(태초 신발 · 환생 4 · 24) = %d · 오를 수 없는 벽 %.1f(붙잡기 %.1f)"):format(g16, g24, gp, JumpMath.maxClimbStuds(2, false, 0.1) + 1.6, JumpMath.maxClimbStuds(2, true, 0.1) + 1.6),
			g16 > 46 and g24 > g16 and gp > g24)
		local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
		local counts = { A = { 0, 0 }, B = { 0, 0 }, C = { 0, 0 } }
		local caps0 = WorldMapLayout.capsForTier(MovementUnlockData.tiers[0], false, false, 16)
		local aBad = {}
		for _, n in ipairs(WorldStructures.nestList()) do
			local ok = true
			for _, l in ipairs(n.leaps or {}) do
				ok = ok and WorldMapLayout.moveSkill(l.rise, l.gap, caps0) ~= nil
			end
			local c = counts[n.track]
			c[1] += ok and 1 or 0
			c[2] += 1
			if n.track == "A" and not ok then
				table.insert(aBad, n.id)
			end
		end
		r.note(("환생 0 도달: A %d/%d · B %d/%d · C %d/%d - A 막힘 %s(결정 - MV1 보고서 §도달성)"):format(counts.A[1], counts.A[2], counts.B[1], counts.B[2], counts.C[1], counts.C[2], table.concat(aBad, " · ")))
		local ledgeSkill = WorldMapLayout.moveSkill(WorldMapData.sealed.door.ledgeH, 2, caps0)
		local ledgeGloves = WorldMapLayout.moveSkill(WorldMapData.sealed.door.ledgeH, 2, WorldMapLayout.capsForTier(MovementUnlockData.tiers[0], false, true, 16))
		r.note(("봉인 입구 틈 선반(%d): 환생 0 %s · 태초 장갑 붙잡기 %s(봉인 상자 · 서버 구역 검사가 그대로 막는다)"):format(WorldMapData.sealed.door.ledgeH, tostring(ledgeSkill), tostring(ledgeGloves)))
	end)

	local pass, total = r.summary()
	print(("===MV1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===MV1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerState = require(script.Parent.PlayerState)
	local AirState = require(script.Parent.AirState)
	local FallServer = require(script.Parent.FallServer)
	local HeightGuard = require(script.Parent.HeightGuard)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 없음", false)
		print("===MV1 검증 끝(나)=== 0/1 통과")
		return
	end
	local origin = root.CFrame
	local wasAnchored = root.Anchored
	local originalSpeed = PlayerProfile.getSpeedPercentBonus
	local originalShoes = PlayerProfile.getEquipped(player, "shoes")
	local originalGloves = PlayerProfile.getEquipped(player, "gloves")
	-- 열린 곳(허브 가장자리 - 나무 둘레 밖 · 보스 아레나 밖)에 루트를 고정해 둔다
	local spot = Vector3.new(0, WorldMapData.floorTopY + 30, WorldMapData.progress.treeRadius + 45)
	root.Anchored = true
	root.CFrame = CFrame.new(spot)
	AirState.debugPaused = true
	local st = AirState.stateOf(player)
	local function freshSession(extra)
		st.takeoffCount += 1
		st.session = { id = st.takeoffCount, since = os.clock() - 2, takeoffPos = spot, fromLadder = false, airDashes = 0, airAttacks = 0, ledgeUsed = false, counted = true }
		for k, v in pairs(extra or {}) do
			st.session[k] = v
		end
		return st.session
	end
	local function ground()
		st.session, st.lastSession, st.grounded, st.groundPos = nil, nil, true, spot
	end

	r.section("해금 단계 Attribute", function()
		player:SetAttribute("MoveTierOverride", nil)
		local tierAttr = player:GetAttribute("MoveTier")
		player:SetAttribute("MoveTierOverride", 3)
		local row, n = MoveRules.tierOf(player)
		r.check(("MoveTier(계정 최대 환생) = %s · 덮어쓰기 3 → 단계 %d(공중 점프 %d)"):format(tostring(tierAttr), n, row.airJumps), type(tierAttr) == "number" and n == 3 and row.airJumps == 2)
	end)

	r.section("대시(DashHook)", function()
		local hook = ServerStorage:FindFirstChild("DashHook")
		ground()
		local rows, ok = {}, true
		for _, bonus in ipairs({ 0, 0.25, 0.5 }) do
			PlayerProfile.getSpeedPercentBonus = function()
				return bonus
			end
			local status, range = hook:Invoke(player, true)
			local expect = DashConfig.rangeStuds * math.min(1 + bonus, DashConfig.speedScaleMax)
			table.insert(rows, ("이속 %d → %s %.1f(기대 %.1f)"):format(16 * (1 + bonus), tostring(status), range or -1, expect))
			ok = ok and status == "ok" and near(range or -1, expect, 1e-6)
			task.wait(DashConfig.durationSeconds + 0.05)
		end
		PlayerProfile.getSpeedPercentBonus = originalSpeed
		r.check("지상 대시 거리 " .. table.concat(rows, " · "), ok)
		player:SetAttribute("MoveTierOverride", 4)
		freshSession()
		local a1, rangeA = hook:Invoke(player, true)
		task.wait(DashConfig.durationSeconds + 0.05)
		local a2 = hook:Invoke(player, true)
		r.check(("공중(환생 4): 첫 %s %.1f(×%.2f) · 같은 체공 두 번째 %s"):format(tostring(a1), rangeA or -1, MovementUnlockData.tiers[4].airDashRangeMultiplier, tostring(a2)),
			a1 == "ok" and near(rangeA or -1, JumpMath.dashRangeStuds(JumpMath.moveSpeedMultiplier(PlayerProfile.getSpeedPercentBonus(player)), 1.25), 1e-6) and a2 == "air_used")
		PlayerProfile.setEquippedDirect(player, "shoes", { grade = "primordial", part = "shoes", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		task.wait(0.1)
		ground()
		local g1 = hook:Invoke(player, true)
		task.wait(DashConfig.durationSeconds + 0.05)
		local g2, _, _, _, second = hook:Invoke(player, false)
		task.wait(DashConfig.durationSeconds + 0.05)
		local g3 = hook:Invoke(player, false)
		freshSession()
		local f1 = hook:Invoke(player, true)
		task.wait(DashConfig.durationSeconds + 0.05)
		local f2 = hook:Invoke(player, false)
		task.wait(DashConfig.durationSeconds + 0.05)
		local f3 = hook:Invoke(player, true)
		r.check(("태초 신발 2단 대시: 지상 첫 %s · 두 번째 %s(second %s) · 세 번째 %s / 공중 %s · %s · 세 번째(쿨 무시) %s"):format(tostring(g1), tostring(g2), tostring(second), tostring(g3), tostring(f1), tostring(f2), tostring(f3)),
			g1 == "ok" and g2 == "ok" and second == true and g3 == "cooldown" and f1 == "ok" and f2 == "ok" and f3 == "air_used")
		PlayerProfile.setEquippedDirect(player, "shoes", originalShoes)
	end)

	r.section("공중 공격(AttackHook)", function()
		local hook = ServerStorage:FindFirstChild("AttackHook")
		local classId = PlayerProfile.getClassId(player)
		local cd = CombatConfig.attackCooldownSeconds / ClassData.classes[classId].atkSpeed + 0.08
		local function swing(air)
			task.wait(cd)
			return hook:Invoke(player, nil, air)
		end
		player:SetAttribute("MoveTierOverride", 0)
		freshSession()
		local t0 = swing(true)
		player:SetAttribute("MoveTierOverride", 1)
		freshSession()
		local a1, a2 = swing(true), swing(true)
		st.session.airDashes = 1
		local a3 = swing(true)
		r.check(("예산: 환생 0 공중 → %s · 환생 1 첫 %s(공중 %s) · 두 번째 %s · 공중 대시 뒤 %s"):format(t0.status, a1.status, tostring(a1.isAir), a2.status, a3.status),
			t0.status == "air_budget" and a1.status == "swing" and a1.isAir and a2.status == "air_budget" and a3.status == "swing")
		-- 스택: (앞 체공에서 착지한 뒤) 지상 2타 → 뜸(새 세션) → 공중 1타 = 콤보 1
		ground()
		st.takeoffCount += 1 -- 앞 체공(뜬 횟수가 바뀐 뒤 첫 지상 공격 = 0부터)
		local g1, g2 = swing(false), swing(false)
		player:SetAttribute("MoveTierOverride", 3)
		freshSession({ airDashes = 1 })
		local b1, b2, b3 = swing(true), swing(true), swing(true)
		r.check(("스택 초기화: 지상 %d · %d → 뜬 뒤 공중 %d · %d · %d(환생 3 셋째 강공격 %s)"):format(g1.combo or -1, g2.combo or -1, b1.combo or -1, b2.combo or -1, b3.combo or -1, tostring(b3.isComboHit)),
			g2.combo == 2 and b1.combo == 1 and b3.combo == 3 and b3.isComboHit == true)
		player:SetAttribute("MoveTierOverride", 2)
		freshSession({ airDashes = 2 })
		local c1, c2, c3 = swing(true), swing(true), swing(true)
		r.check(("환생 2(예산 강제 3): 공중 셋째 강공격 %s(기대 false - 3회 해금 전) · %s %s %s"):format(tostring(c3.isComboHit), c1.status, c2.status, c3.status), c3.status == "swing" and c3.isComboHit == false)
		ground()
	end)

	r.section("낙하(FallServer.onLanded)", function()
		player:SetAttribute("MoveTierOverride", nil)
		ground()
		local maxHp = PlayerState.getMaxHp(player)
		PlayerState.setHp(player, maxHp)
		local function land(speed, flags)
			task.wait(MovementConfig.fall.reportMinGapSeconds + 0.05)
			-- 리뷰 1: 보고는 서버 체공과 맞아야 한다 - 방금 끝난 긴 체공(5초)을 세워 둔다
			st.lastSession = { id = -1, since = os.clock() - 5, endedAt = os.clock(), takeoffPos = spot, airDashes = 0, airAttacks = 0, ledgeUsed = false, fromLadder = false }
			return FallServer.onLanded(player, speed, flags)
		end
		local n = land(90)
		local d = land(200)
		local hpAfter = PlayerState.getHp(player)
		local expect = MoveRules.fallOutcome(200).fraction
		r.check(("속도 90 → %s · 200 → %s(체력 %.1f%% 잃음 · 기대 %.1f%%)"):format(n, d, (1 - hpAfter / maxHp) * 100, expect * 100), n == "none" and d == "damage" and near(1 - hpAfter / maxHp, expect, 1e-6))
		PlayerState.setHp(player, maxHp)
		player:SetAttribute("BossEncounterId", "verify")
		local eb = land(300)
		player:SetAttribute("BossEncounterId", nil)
		local ew = land(200, { water = true })
		local el = land(200, { ladder = true })
		HeightGuard.grant(player, 999, 2, "verify")
		local ep = land(300)
		HeightGuard.reset(player)
		root.CFrame = CFrame.new(0, WorldMapData.floorTopY + 30, 60)
		local et = land(300)
		root.CFrame = CFrame.new(spot)
		r.check(("제외: 보스 %s · 물 %s · 사다리 %s · 발사 허가 %s · 나무 둘레 %s · 체력 그대로 %s"):format(eb, ew, el, ep, et, tostring(PlayerState.getHp(player) == maxHp)),
			eb == "excluded:boss" and ew == "excluded:water" and el == "excluded:ladder" and ep == "excluded:permit" and et == "excluded:tree" and PlayerState.getHp(player) == maxHp)
		task.wait(MovementConfig.fall.permitGraceSeconds + 0.1)
		-- 리뷰 1: 서버 체공과 안 맞는 보고(위조) - 체공 없음 · 짧은 체공 · 오래전 체공
		task.wait(MovementConfig.fall.reportMinGapSeconds + 0.05)
		st.session, st.lastSession = nil, nil
		local f1 = FallServer.onLanded(player, 400)
		task.wait(MovementConfig.fall.reportMinGapSeconds + 0.05)
		st.lastSession = { id = -2, since = os.clock() - 0.3, endedAt = os.clock(), takeoffPos = spot }
		local f2 = FallServer.onLanded(player, 400)
		task.wait(MovementConfig.fall.reportMinGapSeconds + 0.05)
		st.lastSession = { id = -3, since = os.clock() - 10, endedAt = os.clock() - 5, takeoffPos = spot }
		local f3 = FallServer.onLanded(player, 400)
		r.check(("위조 보고 거절: 체공 없음 %s · 체공 0.3초에 속도 400 %s · 5초 전 체공 %s · 체력 그대로 %s"):format(f1, f2, f3, tostring(PlayerState.getHp(player) == maxHp)),
			f1 == "excluded:no_air" and f2 == "excluded:short_air" and f3 == "excluded:no_air" and PlayerState.getHp(player) == maxHp)
		-- 쓰러짐: 치명 속도 → 고정 · 그을림 → knockdownSeconds 뒤 안전 지점 · 체력 가득
		st.groundPos = spot
		PlayerState.setHp(player, maxHp * 0.5)
		local k = land(400) -- 치명 높이(360) 넘는 속도
		local knocked, anchored, charred = character:GetAttribute("FallKnockdown"), root.Anchored, character:GetAttribute("CharredUntil")
		task.wait(MovementConfig.fall.knockdownSeconds + 0.6)
		local moved = require(script.Parent.Travel).lastTeleport
		local standGap = moved and moved.player == player and (moved.position - (spot + Vector3.new(0, 3, 0))).Magnitude or math.huge
		r.check(("치명 400 → %s(쓰러짐 %s · 고정 %s · 그을림 %s) → %.1f초 뒤 일어남 %s · 부활 체력 %.0f/%.0f · 부활 자리 ↔ 안전 지점 + 3 = %.1f"):format(k, tostring(knocked), tostring(anchored), tostring(charred ~= nil), MovementConfig.fall.knockdownSeconds,
			tostring(character:GetAttribute("FallKnockdown") == nil), PlayerState.getHp(player), maxHp, standGap),
			k == "knockdown" and knocked == true and anchored and charred ~= nil and character:GetAttribute("FallKnockdown") == nil and near(PlayerState.getHp(player), maxHp * MovementConfig.fall.reviveHpCapFraction, 1e-6) and standGap < 0.5) -- 부활 체력 = min(떨어지기 전 50%, 최대 × 0.3)
		root.Anchored = true
		root.CFrame = CFrame.new(spot)
		PlayerState.setHp(player, maxHp * 0.1)
		local kd = land(200) -- 피해가 체력보다 크면 죽지 않고 쓰러짐
		task.wait(MovementConfig.fall.knockdownSeconds + 0.6)
		r.check(("체력 10%%에서 속도 200(피해 %.0f%%) → %s(사망 대신 쓰러짐) · 체력 %.0f"):format(MoveRules.fallOutcome(200).fraction * 100, kd, PlayerState.getHp(player)), kd == "knockdown" and near(PlayerState.getHp(player), maxHp * 0.1, 1e-6)) -- 부활 체력 = 떨어지기 전(10%) - 일부러 떨어져 회복 못 함
		root.Anchored = true
		root.CFrame = CFrame.new(spot)
	end)

	r.section("붙잡기(LedgeClimbHook)", function()
		local hook = ServerStorage:FindFirstChild("LedgeClimbHook")
		local feetY = spot.Y - MovementConfig.rootAboveFeetStuds
		local wall = Instance.new("Part")
		wall.Name = "MV1VerifyWall"
		wall.Anchored = true
		wall.Size = Vector3.new(8, 12, 8)
		wall.CFrame = CFrame.new(spot.X, feetY + 5 - 6, spot.Z + 1.5 + 4) -- 윗면 = 발 + 5 · 앞면 = 루트 앞 1.5
		wall.Parent = Workspace
		local top = feetY + 5
		local dir = Vector3.new(0, 0, 1)
		local function call(y)
			task.wait(MovementConfig.ledgeGrab.requestGapSeconds + 0.05)
			return hook:Invoke(player, Vector3.new(spot.X, y, spot.Z + 3.2), dir) -- 모서리 윗점(벽 안쪽)
		end
		PlayerProfile.setEquippedDirect(player, "gloves", { grade = "ancient", part = "gloves", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		freshSession()
		local noGloves = call(top)
		PlayerProfile.setEquippedDirect(player, "gloves", { grade = "primordial", part = "gloves", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		HeightGuard.reset(player)
		local okCall = call(top)
		local permit = HeightGuard.getState(player) and HeightGuard.getState(player).permit
		local used = call(top)
		freshSession()
		local mismatch = call(top + 5)
		ground()
		local grounded = call(top)
		r.check(("태초 아님 %s · 태초 장갑 %s(허가 %s ≤ %.1f · 기대 %.1f) · 같은 체공 두 번째 %s · 높이 불일치 %s · 땅(체공 없음) %s"):format(noGloves, okCall, permit and tostring(permit.source) or "없음", permit and permit.maxFeetY or -1,
			top + MovementConfig.ledgeGrab.permitMarginStuds + MovementConfig.permit.marginStuds, used, mismatch, grounded),
			noGloves == "no_gloves" and okCall == "ok" and permit ~= nil and permit.source == "ledge" and near(permit.maxFeetY, top + MovementConfig.ledgeGrab.permitMarginStuds + MovementConfig.permit.marginStuds, 0.05)
				and used == "used" and (mismatch == "mismatch" or mismatch == "no_ledge") and grounded == "not_air")
		wall:Destroy()
		PlayerProfile.setEquippedDirect(player, "gloves", originalGloves)
		HeightGuard.reset(player)
	end)

	-- 되돌림
	player:SetAttribute("MoveTierOverride", nil)
	PlayerProfile.getSpeedPercentBonus = originalSpeed
	PlayerProfile.setEquippedDirect(player, "shoes", originalShoes)
	PlayerProfile.setEquippedDirect(player, "gloves", originalGloves)
	ground()
	AirState.debugPaused = false
	root.CFrame = origin
	root.Anchored = wasAnchored
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	character:SetAttribute("CharredUntil", nil)
	HeightGuard.reset(player)
	env.restore(player)
	r.check(("되돌림: 덮어쓰기 %s · 체공 일시정지 %s · 검증 벽 %d"):format(tostring(player:GetAttribute("MoveTierOverride")), tostring(AirState.debugPaused), Workspace:FindFirstChild("MV1VerifyWall") and 1 or 0),
		player:GetAttribute("MoveTierOverride") == nil and AirState.debugPaused == false and Workspace:FindFirstChild("MV1VerifyWall") == nil)
	local pass, total = r.summary()
	print(("===MV1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
