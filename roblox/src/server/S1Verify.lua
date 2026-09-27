-- S1 자동 검증(이동 보안 · 획득 보안). id = "S1(가)" · "S1(나)".
--   (가) 순수: 수평 이동 판정(걷기 · 속도 조작 · 50씩 순간이동 · 대시 허가 · 활강 · 발사 허가 · 지연 몰림 · 예외) · 해금 단계별 높이 허용 · 서버 궤적 낙하 속도 ·
--        스테이지 하드 상한 · 저장 거부 · 배정밀도 여유 · 포아송 꼬리 · 속도 봉투 · 리더보드 값(동점 = 먼저) · 집계 대상 · 비밀 둥지 서버 전용
--   (나) 실제 서버: 속도 조작 · 순간이동 되돌림(HeightGuard.poll) · 대시 허가 뒤 합법 · 미해금 공중 점프 높이 되돌림 · 둥지 원격 줍기 거절 · 비밀 둥지 앵커 숨김 ·
--        착지 속도 위조 → 서버 궤적 · 25,301 저장 거부 · 원장 없는 태초 격리 · 칭호 회수 · 봉투 초과 보류 · 운 좋은 계정 통과 · 분해 보석 · 환생 무기 미집계 · 운영 명령
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local AuditConfig = require(ReplicatedStorage.Shared.data.AuditConfig)
local NestData = require(ReplicatedStorage.Shared.data.NestData)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local AuditMath = require(ReplicatedStorage.Shared.AuditMath)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[S1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[S1][%s] %s"):format(tag, label))
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

function V.runPure()
	print("===S1 검증 시작(가)===")
	local r = newRecorder("가")
	local HeightGuard = require(script.Parent.HeightGuard)
	local walk = MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier

	r.section("수평 이동(합성 표본 0.25초)", function()
		-- speeds = 표본마다 이번 0.25초 이동 거리 · ctx = { rate, exempt } · grants = { [표본 번호] = 대시 허가 거리 }
		local function run(steps, rate, grants, exempt)
			local st = HeightGuard.newState()
			local x, out = 0, {}
			HeightGuard.evaluateHorizontal(st, { pos = Vector3.new(0, 3, 0) }, 0, { rate = rate })
			for i, d in ipairs(steps) do
				local now = i * 0.25
				if grants and grants[i] then
					HeightGuard.bankAt(st, grants[i] * MovementConfig.moveGuard.dashMargin, MovementConfig.moveGuard.dashWindowSeconds, now - 0.25)
				end
				x += d
				local v = HeightGuard.evaluateHorizontal(st, { pos = Vector3.new(x, 3, 0) }, now, { rate = rate, exempt = exempt })
				if v == "hrevert" then
					x = st.hGood.X
				end
				table.insert(out, v == "ok" and "o" or "R")
			end
			return table.concat(out), st
		end
		local function rep(v, n)
			local t = {}
			for i = 1, n do
				t[i] = v
			end
			return t
		end
		local legalWalk = run(rep(walk * 0.25, 16), walk * MovementConfig.moveGuard.walkMargin)
		local speedHack = run(rep(40 * 0.25, 24), walk * MovementConfig.moveGuard.walkMargin)
		local tp50 = run(rep(50, 6), walk)
		local dashSteps = rep(walk * 0.25, 8)
		dashSteps[3] = walk * 0.25 + 38.5 -- 환생 4 공중 대시 최대(이속 상한) 한 폴링에
		local dash = run(dashSteps, walk, { [3] = 38.5 })
		local dashNoGrant = run(dashSteps, walk)
		local glide = run(rep(30.2 * 0.25, 16), MovementConfig.glide.forwardSpeed * MovementConfig.moveGuard.glideMargin)
		local permit = run(rep(150 * 0.25, 8), MovementConfig.moveGuard.permitSpeed)
		local bunch = run({ 0, 12, 0, 12, 0, 12, 0, 12, 0, 12, 0, 12 }, walk) -- 지연 0.25: 표본이 두 폴링씩 몰림(평균 24)
		local exempt = run(rep(80, 4), walk, nil, true)
		r.check(("걷기 24/s %s · 속도 조작 40/s %s · 50씩 순간이동 %s · 대시 38.5(허가) %s · 같은 이동 허가 없음 %s · 활강 30.2 %s · 발사 허가 150/s %s · 지연 몰림 %s · 예외(붙잡힘) %s"):format(
			legalWalk, speedHack, tp50, dash, dashNoGrant, glide, permit, bunch, exempt),
			not legalWalk:find("R") and speedHack:find("R") ~= nil and tp50 == "RRRRRR" and not dash:find("R") and dashNoGrant:find("R") ~= nil
			and not glide:find("R") and not permit:find("R") and not bunch:find("R") and not exempt:find("R"))
		-- 리뷰 3: 순간이동 유예 = 도착 자리 근처만 · 리뷰 4: 발사 허가 속도 = 설계 체공(expiresAt) 안만
		local gs = HeightGuard.newState()
		gs.hAnchor = Vector3.new(0, 3, 0)
		local gNear = HeightGuard.evaluateHorizontal(gs, { pos = Vector3.new(4, 3, 0) }, 10, { rate = walk, grace = true })
		local gFar = HeightGuard.evaluateHorizontal(gs, { pos = Vector3.new(500, 3, 0) }, 10.25, { rate = walk, grace = true })
		local gBack = gs.hGood and gs.hGood.X or -1
		local ps = HeightGuard.newState()
		ps.permit = { expiresAt = 5, maxFeetY = 100, hRate = MovementConfig.moveGuard.permitSpeed } -- S1 후속 0-4: 보스 발사(grantLaunch)만 400
		ps.exemptUntil, ps.graceUntil = 0, 0
		local fakeChar = { GetAttribute = function() return nil end }
		local fakeHum = { GetState = function() return Enum.HumanoidStateType.Running end }
		local fakeRoot = { Position = Vector3.new(0, 2000, 0) } -- 물 밖
		local inside = HeightGuard.horizontalContext(ps, fakeChar, fakeRoot, fakeHum, 4).rate
		local after = HeightGuard.horizontalContext(ps, fakeChar, fakeRoot, fakeHum, 6).rate
		r.check(("유예: 도착 근처 → %s · 500 밖 → %s(기준 = 도착 %.0f) · 보스 발사 허가 속도 설계 체공 안 %.0f · 뒤 %.0f"):format(gNear, gFar, gBack, inside, after),
			gNear == "ok" and gFar == "hrevert" and gBack == 0 and inside == MovementConfig.moveGuard.permitSpeed and after < MovementConfig.moveGuard.permitSpeed)
		-- S1 후속 0-4: 발판 허가 = 설계 수평 속도 × 여유(점프대) · 통통 열매(hSpeed 없음) = 걷기 그대로 · 나무 점프대 설계 수평 최대(표)
		local walkRate = HeightGuard.horizontalContext(HeightGuard.newState(), fakeChar, fakeRoot, fakeHum, 4).rate
		local pads = HeightGuard.newState()
		HeightGuard.grantAt(pads, 100, 1.1, "합성 점프대", 3, 40 * MovementConfig.moveGuard.padSpeedMargin)
		local padRate = HeightGuard.horizontalContext(pads, fakeChar, fakeRoot, fakeHum, 3.5).rate
		local fruit = HeightGuard.newState()
		HeightGuard.grantAt(fruit, 100, 4, "합성 통통 열매", 3, nil)
		local fruitRate = HeightGuard.horizontalContext(fruit, fakeChar, fakeRoot, fakeHum, 3.5).rate
		local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
		local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
		local maxPad, padCount = 0, 0
		for i in ipairs(WorldMapLayout.tree().elements) do
			local s = WorldMapLayout.treeLaunch(i)
			if s and s.kind == "pad" then
				padCount += 1
				local c = WorldMapLayout.tree().elements[i].center
				maxPad = math.max(maxPad, (Vector3.new(s.target.X - c.X, 0, s.target.Z - c.Z).Magnitude + s.radius) / WorldMapData.hub.tree.course.pad.flightSeconds)
			end
		end
		-- 지연 0.25 흉내: 설계 수평 maxPad/s 점프대 비행을 0.25초 폴링으로 보되 표본이 두 폴링씩 몰린다(허가는 지연된 위치 기록으로 - 비행 표본보다 먼저).
		-- 리뷰 5: 걷기 버킷만으로 통과하지 않게 버킷이 빈 채 시작(직전까지 걸어 옴) + 허가 없는 대조군은 되돌림이 나와야 한다.
		local function lagRun(withPermit)
			local lagSt = HeightGuard.newState()
			lagSt.exemptUntil, lagSt.graceUntil = 0, 0
			lagSt.hGood, lagSt.hAt = Vector3.new(0, 3, 0), 20 -- 버킷 = 걸어 온 상태(가득 - 리뷰 5 대조군이 되돌림을 내도록 비행은 2초)
			local x, out = 0, {}
			for i = 1, 8 do -- 2초(점프대 두 번 이어 타기)
				local now = 20 + i * 0.25
				if withPermit and i == 1 then -- 서버는 발판 위 표본(지연된 위치 기록)으로 허가한 뒤에 비행 표본을 본다
					HeightGuard.grantAt(lagSt, 1000, MovementConfig.permit.padSeconds, "합성 점프대(늦은 허가)", now, maxPad * MovementConfig.moveGuard.padSpeedMargin)
				end
				x += (i % 2 == 1) and maxPad * 0.5 or 0 -- 몰림: 두 폴링 몫이 한 표본에
				local ctx = HeightGuard.horizontalContext(lagSt, fakeChar, fakeRoot, fakeHum, now)
				local v = HeightGuard.evaluateHorizontal(lagSt, { pos = Vector3.new(x, 3, 0) }, now, ctx)
				if v == "hrevert" then
					x = lagSt.hGood.X
				end
				table.insert(out, v == "ok" and "o" or "R")
			end
			return table.concat(out)
		end
		local lagWith, lagWithout = lagRun(true), lagRun(false)
		r.check(("지연 0.25 점프대(설계 %.1f/s · 2초 · 표본 몰림): 허가 %s(기대 되돌림 0) · 허가 없음 %s(기대 되돌림 있음)"):format(maxPad, lagWith, lagWithout),
			not lagWith:find("R") and lagWithout:find("R") ~= nil)
		r.check(("발판 허가 수평: 점프대(설계 40/s) %.0f(기대 40 × %.2f) · 통통 열매 %.1f(기대 = 걷기 %.1f) · 나무 점프대 %d개 설계 최대 %.1f/s × 여유 = %.1f(기대 < 보스 %d)"):format(
			padRate, MovementConfig.moveGuard.padSpeedMargin, fruitRate, walkRate, padCount, maxPad, maxPad * MovementConfig.moveGuard.padSpeedMargin, MovementConfig.moveGuard.permitSpeed),
			math.abs(padRate - 40 * MovementConfig.moveGuard.padSpeedMargin) < 1e-6 and fruitRate == walkRate and padCount > 0 and maxPad * MovementConfig.moveGuard.padSpeedMargin < MovementConfig.moveGuard.permitSpeed)
		-- 한 폴링 합법 최대(걷기 + 대시 몫) < 버킷 + 허가 · 합법 목록
		r.note(("합법 이동 목록(데이터 MovementConfig.moveGuard.legal): %s"):format(table.concat(MovementConfig.moveGuard.legal, " · ")))
	end)

	r.section("공중 정체(S1 후속 0-1)", function()
		local HG = require(script.Parent.HeightGuard)
		local stallS = MovementConfig.heightGuard.stallSeconds
		local function run(feetAt, seconds, flags)
			local st = HG.newState()
			st.allowance = 22.38
			HG.evaluate(st, { feetY = 0, pos = Vector3.new(0, 3, 0), grounded = true }, 0)
			local out = {}
			local t = 0
			while t < seconds do
				t += 0.25
				local f = feetAt(t)
				table.insert(out, HG.evaluate(st, { feetY = f, pos = Vector3.new(0, f + 3, 0), grounded = false, gliding = flags and flags.gliding, probe = flags and flags.probe }, t))
			end
			return out
		end
		local function reverts(list)
			local n = 0
			for _, v in ipairs(list) do
				n += v == "revert" and 1 or 0
			end
			return n
		end
		local hover = reverts(run(function(t) return math.min(t * 40, 17.3) end, 6))
		local glide = reverts(run(function(t) return math.min(t * 40, 17.3) end, 6, { gliding = true }))
		-- 합법 최대: 점프 → 공중 점프 2 → 대시 두 번(수평 - 높이 유지) → 떨어짐(약 2.6초 공중 · 한 번도 이륙 표본 아래로 안 내려감)
		local legal = reverts(run(function(t) if t < 1.6 then return 6 + t * 8 elseif t < 2.2 then return 18.8 else return 18.8 - (t - 2.2) * 40 end end, 2.8))
		local ledgeFloor = reverts(run(function(t) return math.min(t * 40, 17.3) end, 6, { probe = function() return 16 end })) -- 발 바로 아래 얇은 파트(FloorMaterial Air)
		r.check(("허용 아래 띄워 두기(발 +17.3 · 6초) 되돌림 %d(기대 ≥ 1 - %.1f초) · 같은 동작 활강 표시 %d(기대 0) · 합법 최대 체공 2.8초 %d(기대 0) · 발밑 지면(probe) %d(기대 0)"):format(hover, stallS, glide, legal, ledgeFloor),
			hover >= 1 and glide == 0 and legal == 0 and ledgeFloor == 0)
	end)

	r.section("해금 단계별 높이 허용 · 서버 궤적 낙하", function()
		local a0, a1, a2 = JumpMath.heightGuardAllowance(0), JumpMath.heightGuardAllowance(1), JumpMath.heightGuardAllowance(2)
		local st = HeightGuard.newState()
		st.allowance = a0
		local out = {}
		for i, s in ipairs({ { 0, true }, { 0, true }, { 6, false }, { 12, false }, { 12, false } }) do -- 환생 0이 공중 점프(12) = 미해금
			table.insert(out, HeightGuard.evaluate(st, { feetY = s[1], pos = Vector3.new(0, s[1] + 3, 0), grounded = s[2] }, i * 0.5))
		end
		r.check(("높이 허용: 환생 0 %.2f · 1 %.2f · 3+ %.2f · 환생 0 공중 점프(발 12) [%s](기대 revert)"):format(a0, a1, a2, table.concat(out, ",")),
			a0 < a1 and a1 < a2 and math.abs(a2 - 22.384) < 1e-3 and table.find(out, "revert") ~= nil)
		local AirState = require(script.Parent.AirState)
		local ast = { grounded = true, groundPos = Vector3.zero, session = nil, sessionCount = 0, takeoffCount = 0 }
		AirState.step(ast, true, Vector3.new(0, 3, 0), false, 0)
		for i, y in ipairs({ 10, 20, 30, 25, 15, 18, 22, 10, 3 }) do -- 30까지 올랐다 떨어지다 공중 점프(15 → 22) 뒤 착지
			AirState.step(ast, false, Vector3.new(0, y, 0), false, i * 0.1)
		end
		AirState.step(ast, true, Vector3.new(0, 3, 0), false, 1)
		local speed, h = AirState.fallSpeedOf(ast.lastSession)
		r.check(("서버 궤적: 최고 30 → 공중 점프(15 → 22) → 착지 3 = 낙하 높이 %.1f(기대 19 - 마지막 오름 뒤 최고점) · 속도 %.1f"):format(h or -1, speed or -1), h and math.abs(h - 19) < 1e-6)
	end)

	r.section("스테이지 하드 상한 · 배정밀도", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local ok25300 = #SaveSystem.stageCapViolations({ classes = { bow = { stageProgress = { infinite = 25300, infiniteBest = 25300, bestBossCleared = 25300 } } } }) == 0
		local bad = SaveSystem.stageCapViolations({ classes = { bow = { stageProgress = { infinite = 25301, infiniteBest = 25301, bestBossCleared = 25295 } } } })
		r.check(("하드 상한 %d(= 설계 최대 %d) · 25,300 저장 허용 %s · 25,301 거부 %d칸"):format(InfiniteStageConfig.hardMaxStage, InfiniteStageConfig.designMaxStage, tostring(ok25300), #bad),
			InfiniteStageConfig.hardMaxStage == 25300 and ok25300 and #bad == 2)
		local BossData = require(ReplicatedStorage.Shared.data.BossData)
		local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
		local maxMult = 0
		for _, b in pairs(BossData.bosses) do
			maxMult = math.max(maxMult, b.hpMultiplier)
		end
		local tierMul = MonsterData.getRewardRatio(#MonsterData.tierOrder) ^ MonsterData.fairnessExponent
		local function worst(stage)
			return InfiniteStage.getMonsterHp(80, stage) * maxMult * 12 ^ BossData.mechanics.party.hpExponent * tierMul * 1000
		end
		local lo, hi = 1, 60000
		while lo < hi do
			local mid = math.floor((lo + hi + 1) / 2)
			if worst(mid) < 1e300 then
				lo = mid
			else
				hi = mid - 1
			end
		end
		r.check(("배정밀도 최악(보스 HP × 12인 N^%.2f × tier6 r² × 토벌 ×1000 가정) 1e300 안 최대 %d · 25,300 = %.2g · 확장 여유 %d스테이지(전체 한계 safeStageCap %d)"):format(
			BossData.mechanics.party.hpExponent, lo, worst(25300), math.min(lo, InfiniteStageConfig.safeStageCap) - InfiniteStageConfig.hardMaxStage, InfiniteStageConfig.safeStageCap),
			lo > InfiniteStageConfig.hardMaxStage and worst(25300) < 1e300)
	end)

	r.section("획득 감사(순수)", function()
		local t1 = AuditMath.poissonTail(1, 1e-3)
		local t3 = AuditMath.poissonTail(3, 1e-3)
		local tLucky = AuditMath.poissonTail(2, 0.05)
		r.check(("포아송 꼬리: P(≥1 | 0.001) = %.3g(≈1e-3) · P(≥3 | 0.001) = %.3g(< 1e-6 = 검토) · 운 좋은 P(≥2 | 0.05) = %.3g(> 1e-6 = 통과)"):format(t1, t3, tLucky),
			math.abs(t1 - (1 - math.exp(-1e-3))) < 1e-9 and t3 < AuditConfig.poissonThreshold and tLucky > AuditConfig.poissonThreshold)
		local e1169 = AuditMath.envelopeStage(1169)
		local back = AuditMath.hoursForStage(25300)
		r.check(("속도 봉투: 1,169시간 → %.0f · 25,300 ← %.0f시간(하루 24시간 %.1f일 · 12시간 %.1f일) · 1시간 %.0f · 여유 ×%.1f"):format(e1169, back, back / 24, back / 12, AuditMath.envelopeStage(1), AuditConfig.envelope.margin),
			math.abs(AuditMath.envelopeStage(back) - 25300) < 1 and back > 1000 and back < 1300)
		local early, late = AuditMath.boardValue(3, 1000), AuditMath.boardValue(3, 2000)
		r.check(("리더보드 값: 같은 3개 먼저 달성 %.0f > 나중 %.0f · 4개 > 3개"):format(early, late), early > late and AuditMath.boardValue(4, 9e9) > early)
		local AcquisitionAudit = require(script.Parent.AcquisitionAudit)
		local function item(kind, extra)
			local it = { grade = "primordial", part = "armor", source = kind and { kind = kind } or nil, primordial = { rollId = "x", no = 1 } }
			for k, v in pairs(extra or {}) do
				it.primordial[k] = v
			end
			return it
		end
		local rows = {
			{ "잡몹", AcquisitionAudit.isCountable(item("field")), true }, { "보스 첫 클리어", AcquisitionAudit.isCountable(item("boss")), true },
			{ "토벌", AcquisitionAudit.isCountable(item("raid")), true }, { "반짝이", AcquisitionAudit.isCountable(item("sparkle")), true },
			{ "분해 보석(출처 없음)", AcquisitionAudit.isCountable(item(nil)), false }, { "운영 지급", AcquisitionAudit.isCountable(item("ops")), false },
			{ "원장 id 없음", AcquisitionAudit.isCountable(item("field", { rollId = false })), false }, { "격리", AcquisitionAudit.isCountable(item("field", { quarantined = "no_ledger" })), false },
			{ "회수", AcquisitionAudit.isCountable(item("field", { revoked = 1 })), false }, { "옛 태초", AcquisitionAudit.isCountable(item("field", { legacy = true })), false },
		}
		local bad, txt = 0, {}
		for _, row in ipairs(rows) do
			bad += (row[2] == row[3]) and 0 or 1
			table.insert(txt, ("%s %s"):format(row[1], row[2] and "O" or "-"))
		end
		r.check(("집계 대상(드랍 출처만): %s - 틀림 %d"):format(table.concat(txt, " · "), bad), bad == 0)
	end)

	r.section("비밀 둥지 서버 전용", function()
		local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
		local secret = require(ServerScriptService.SecretNestData)
		local c, names = 0, {}
		for _, spec in ipairs(NestData.nests) do
			if spec.track == "C" then
				c += 1
				if WorldStructures.modelNameOf(spec):find(spec.id, 1, true) then
					table.insert(names, spec.id)
				end
			end
		end
		r.check(("C 명세 = 서버 전용 모듈 %d곳 · 서버 NestData 합침 %d(전체 %d) · 모델 이름에 id 노출 %d(클라 쪽 C 0곳 = 수동 확인 - 보고서)"):format(
			#secret, c, #NestData.nests, #names),
			#secret == 40 and c == 40 and #names == 0)
	end)

	local pass, total = r.summary()
	print(("===S1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===S1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local HeightGuard = require(script.Parent.HeightGuard)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local SaveSystem = require(script.Parent.SaveSystem)
	local AcquisitionAudit = require(script.Parent.AcquisitionAudit)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		r.check("캐릭터 없음", false)
		print("===S1 검증 끝(나)=== 0/1 통과")
		return
	end
	local origin = root.CFrame
	local wasAnchored = root.Anchored

	r.section("이동 되돌림(HeightGuard.poll · 실제 루트)", function()
		HeightGuard.debugOff = false
		root.Anchored = false
		HeightGuard.reset(player)
		local st = HeightGuard.getState(player)
		local t = os.clock()
		HeightGuard.poll(player, t) -- 기준
		st.graceUntil = 0
		HeightGuard.poll(player, t + 0.25)
		local base = root.Position
		-- ① 50씩 순간이동(서버가 옮긴 척 - 표시 없음)
		root.CFrame = root.CFrame + Vector3.new(50, 0, 0)
		local v1 = HeightGuard.poll(player, t + 0.5)
		local back1 = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(base.X, 0, base.Z)).Magnitude
		-- ② 대시 허가 뒤 같은 거리(30.8 × 1.15 몫 안)
		task.wait(0.05)
		HeightGuard.poll(player, t + 0.75)
		local before = root.Position
		HeightGuard.grantDash(player, 30.8)
		root.CFrame = root.CFrame + Vector3.new(30, 0, 0)
		local v2 = HeightGuard.poll(player, t + 1.0)
		local moved2 = (root.Position - before).Magnitude
		r.check(("50 순간이동(표시 없음) → %s(돌아간 거리 %.1f) · 대시 허가 뒤 30 → %s(그대로 %.1f) · 위반 누적 %d · 되돌림 %d"):format(tostring(v1), back1, tostring(v2), moved2, st.hViolations or 0, st.hReverts or 0),
			v1 == "hrevert" and back1 < 1 and v2 ~= "hrevert" and moved2 > 29)
		-- ③ 미해금 공중 점프: 환생 0이 발 12 위(허용 8.92) 두 번
		player:SetAttribute("MoveTierOverride", 0)
		HeightGuard.reset(player)
		HeightGuard.poll(player, t + 1.25)
		st.graceUntil = 0
		local groundY = root.Position.Y
		HeightGuard.poll(player, t + 1.5)
		root.Anchored = true -- 공중에 둔다(폴링은 고정이면 건너뛰므로 표본만 공중으로)
		root.Anchored = false
		root.CFrame = root.CFrame + Vector3.new(0, 12, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		local h1 = HeightGuard.poll(player, t + 1.75)
		root.CFrame = root.CFrame + Vector3.new(0, 0.01, 0)
		local h2 = HeightGuard.poll(player, t + 2.0)
		local dropped = root.Position.Y - groundY
		player:SetAttribute("MoveTierOverride", nil)
		r.check(("환생 0 발 12 위(허용 %.2f) → %s · %s(되돌림 뒤 높이 차 %.1f)"):format(JumpMath.heightGuardAllowance(0), tostring(h1), tostring(h2), dropped), (h1 == "revert" or h2 == "revert") and dropped < 3)
		HeightGuard.debugOff = true
		root.CFrame = origin
		root.Anchored = wasAnchored
	end)

	r.section("비밀 둥지(원격 줍기 · 앵커 숨김)", function()
		local NestServer = require(script.Parent.NestServer)
		local secretId
		for _, spec in ipairs(NestData.nests) do
			if spec.track == "C" and spec.sub == "field" then
				secretId = spec.id
				break
			end
		end
		local a = NestServer.anchor(secretId)
		local far = (a.part.Position - root.Position).Magnitude
		local hidden = a.part.Parent and a.part.Parent:IsDescendantOf(ServerStorage)
		local ok, why = NestServer.tryPickup(player, secretId)
		r.check(("C 둥지 %s: 거리 %.0f · 앵커 = 서버 창고 %s · 원격 줍기 → %s(%s)"):format(secretId, far, tostring(hidden), tostring(ok), tostring(why)), far > NestData.secret.hideStuds and hidden and not ok)
	end)

	r.section("착지 속도 위조 → 서버 궤적", function()
		local FallServer = require(script.Parent.FallServer)
		local AirState = require(script.Parent.AirState)
		local st = AirState.stateOf(player)
		task.wait(MovementConfig.fall.reportMinGapSeconds + 0.05)
		st.lastSession = { id = -9, since = os.clock() - 5, endedAt = os.clock(), takeoffPos = root.Position, peakY = root.Position.Y + 3, landY = root.Position.Y, airDashes = 0, airAttacks = 0 }
		local res = FallServer.onLanded(player, 2000)
		local log = FallServer.log
		r.check(("클라 신고 2000 · 서버 궤적 높이 3 → %s(쓴 속도 %.1f · 서버 값 %s)"):format(res, log.speed or -1, tostring(log.server)), res == "none" and log.server == true and math.abs(log.speed - math.sqrt(2 * workspace.Gravity * 3)) < 0.5) -- 높이 3 자유 낙하 속도 √(2g·3) ≈ 34(안전 아래)
	end)

	r.section("비밀 둥지 단서 이름(S1 후속 0-6)", function()
		local OLD = { AlcoveFloor = true, AlcoveWall = true, AlcoveLintel = true, AlcoveRoof = true, FallenSlab = true, BuriedLintel = true, FakeWall = true, OddStone = true,
			TimedDoor = true, GazeboPost = true, HollowTrunk = true, HollowRoof = true, VineCurtain = true, MossLine = true, FallSheet = true, NestHint = true }
		local oldNames, clueAttrs, outcrops, motes = 0, 0, 0, 0
		for _, d in ipairs(workspace.Ground:GetDescendants()) do
			if OLD[d.Name] then
				oldNames += 1
			end
			if d.Name:match("^Outcrop_") then
				outcrops += 1
			end
			for _, key in ipairs({ "TimedDoor", "NestHint", "Cycle", "Ambient" }) do
				if d:GetAttribute(key) ~= nil then
					clueAttrs += 1
				end
			end
			if d:IsA("ParticleEmitter") and d.Name == "Motes" then
				motes += 1
			end
		end
		local doors = require(script.Parent.NestServer).timedDoorCount()
		r.check(("월드 옛 단서 이름 %d · C 전용 모델 이름(Outcrop_) %d · 단서 속성(TimedDoor · NestHint · Cycle · Ambient) %d(기대 0 0 0 - 서버가 읽고 지움) · 서버 번개 문 %d · 반딧불 입자(서버) %d(기대 둘 다 > 0 - 동작 불변)"):format(oldNames, outcrops, clueAttrs, doors, motes),
			oldNames == 0 and outcrops == 0 and clueAttrs == 0 and doors > 0 and motes > 0)
	end)

	r.section("스테이지 상한 · 저장 전 자름", function()
		local before = PlayerProfile.getInfiniteStage(player)
		local set = PlayerProfile.setInfiniteStage(player, InfiniteStageConfig.hardMaxStage + 1)
		local profile = PlayerProfile.getProfile(player)
		local copy = table.clone(profile)
		copy.classes = { bow = { stageProgress = { infinite = 25301, infiniteBest = 25301, bestBossCleared = 1 } } }
		local bad = SaveSystem.clampStageCap(copy) -- 리뷰 7: 저장 거부 대신 상한으로 자름(실제 저장은 하지 않는다)
		local sp = copy.classes.bow.stageProgress
		r.check(("setInfiniteStage(25,301) → %s(스테이지 그대로 %s) · 25,301 저장 전 → 자른 칸 %d · %d/%d"):format(tostring(set), tostring(PlayerProfile.getInfiniteStage(player) == before), #bad, sp.infinite, sp.infiniteBest),
			set == false and PlayerProfile.getInfiniteStage(player) == before and #bad >= 2 and sp.infinite == InfiniteStageConfig.hardMaxStage and sp.infiniteBest == InfiniteStageConfig.hardMaxStage)
	end)

	r.section("태초 원장 · 격리 · 봉투 · 확률", function()
		local profile = PlayerProfile.getProfile(player)
		local savedInv, savedAudit, savedTitles = table.clone(profile.inventory), table.clone(profile.audit or {}), table.clone(profile.titles)
		-- 다른 태초는 치운다(개발 계정 기존 태초 - 기대값을 흔들지 않게)
		for i = #profile.inventory, 1, -1 do
			if type(profile.inventory[i]) == "table" and profile.inventory[i].grade == "primordial" then
				table.remove(profile.inventory, i)
			end
		end
		local equipBackup = {}
		for classId, cs in pairs(profile.classes) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				local it = cs.equipment and cs.equipment[part]
				if type(it) == "table" and it.grade == "primordial" then
					equipBackup[{ classId, part }] = it
					cs.equipment[part] = nil
				end
			end
		end
		local legitId = AcquisitionAudit.newRollId()
		local wrote = AcquisitionAudit.writeLedger({ rollId = legitId, userId = player.UserId, source = { kind = "field", stage = 10 }, p = 1e-4, stage = 10, at = os.time(), jobId = game.JobId, no = nil, part = "armor", test = true })
		local legit = { grade = "primordial", part = "armor", itemLevel = 10, source = { kind = "field", stage = 10 }, primordial = { rollId = legitId, ownerId = player.UserId, at = os.time() } }
		local forged = { grade = "primordial", part = "gloves", itemLevel = 10, source = { kind = "field", stage = 10 }, primordial = { no = 999999, ownerId = player.UserId, at = os.time() } }
		local gem = { grade = "primordial", part = "shoes", itemLevel = 10, primordial = { rollId = AcquisitionAudit.newRollId(), ownerId = player.UserId, at = os.time() } } -- 분해 보석 · 환생 무기처럼 출처 태그 없음
		table.insert(profile.inventory, legit)
		table.insert(profile.inventory, forged)
		table.insert(profile.inventory, gem)
		PlayerProfile.grantTitle(player, PrimordialData.titleId)
		-- ① 원장 없는 것만 격리 · 칭호 유지(원장 있는 잡몹 태초가 있다)
		profile.audit = { lambda = 0.05, primordialRolls = 500, playSeconds = profile.audit and profile.audit.playSeconds or 0 }
		local res = AcquisitionAudit.auditProfile(player)
		local q1 = forged.primordial.quarantined
		local titleKept = PlayerProfile.hasTitle(player, PrimordialData.titleId)
		local countable = AcquisitionAudit.countableCount(profile)
		r.check(("원장 쓰기 %s · 감사: 확인 %d · 격리 %d(위조 %s · 원장 있는 잡몹 %s) · 집계 %d(출처 없는 보석 제외) · 칭호 유지 %s"):format(tostring(wrote), res.checked, res.quarantined, tostring(q1), tostring(legit.primordial.quarantined), countable, tostring(titleKept)),
			wrote and q1 ~= nil and legit.primordial.quarantined == nil and countable == 1 and titleKept)
		-- ② 운 좋은 계정(λ 0.05 · 1개 · 봉투 안) = 통과 / 불가능한 운(λ 0.001 · 3개) = 검토
		local okLucky = AcquisitionAudit.checkProbability(player)
		local extra = {}
		for i = 1, 2 do
			local id = AcquisitionAudit.newRollId()
			AcquisitionAudit.writeLedger({ rollId = id, userId = player.UserId, source = { kind = "sparkle" }, p = 5e-5, at = os.time(), test = true })
			local it = { grade = "primordial", part = "armor", itemLevel = 10, source = { kind = "sparkle" }, primordial = { rollId = id, ownerId = player.UserId, at = os.time() } }
			table.insert(profile.inventory, it)
			table.insert(extra, it)
		end
		profile.audit.lambda = 0.001
		local okUnlucky, tail = AcquisitionAudit.checkProbability(player)
		r.check(("확률: 운 좋은 계정(λ 0.05 · 1개) → %s · 태초 3개 · λ 0.001 → %s(P = %.2g < 1e-6 = 검토 대기 · 제재 없음)"):format(okLucky and "통과" or "검토", okUnlucky and "통과" or "검토", tail or -1),
			okLucky == true and okUnlucky == false)
		-- ③ 속도 봉투: 플레이 0시간(봉투 1 × 1.1) · 최고 스테이지(지금 계정 값)가 봉투 초과 = 보류. S1 후속 0-7: 개발 계정은 /gg 표시(gg_tainted)가 먼저 막아
		--   실제 봉투 판정까지 못 갔다(S1 미확인) → 이 항목 동안만 표시 검사를 끄고 eligibility의 봉투 분기까지 실제로 태운다.
		local Leaderboard = require(script.Parent.Leaderboard)
		local savedTainted = PlayerProfile.isLeaderboardTainted
		PlayerProfile.isLeaderboardTainted = function()
			return false
		end
		profile.audit.playSeconds = 0
		local best = PlayerProfile.getAccountBestStage(player)
		local _, reasonFast = Leaderboard.eligibility(player)
		profile.audit.playSeconds = math.floor(AuditMath.hoursForStage(best) * 3600) + 3600
		local _, reasonOk = Leaderboard.eligibility(player)
		PlayerProfile.isLeaderboardTainted = savedTainted
		r.check(("속도 봉투(실제 eligibility · 표시 검사 끔): 최고 %d · 플레이 0시간(봉투 %.1f) → %s(기대 velocity_hold) · 합법 시간 → %s(기대 ok)"):format(best, AuditMath.envelopeStage(0) * AuditConfig.envelope.margin, tostring(reasonFast), tostring(reasonOk)),
			best > AuditMath.envelopeStage(0) * AuditConfig.envelope.margin and reasonFast == "velocity_hold" and reasonOk == "ok")
		-- ④ 운영 명령: 격리 해제(원장 확인은 운영 판단) · 기록
		local hook = ServerStorage:FindFirstChild("OpsHook")
		local rel, logEntry = hook:Invoke(player, "/ops release " .. player.UserId .. " 999999")
		local rev = hook:Invoke(player, "/ops revoke " .. player.UserId .. " " .. legitId)
		r.check(("운영: release 위조(번호 999999) → %s(격리 %s) · revoke 잡몹 → %s(회수 · 칭호 %s) · 기록 %s"):format(tostring(rel), tostring(forged.primordial.quarantined), tostring(rev),
			tostring(PlayerProfile.hasTitle(player, PrimordialData.titleId)), logEntry and logEntry.text or "-"),
			rel == "released" and forged.primordial.quarantined == nil and rev == "revoked" and legit.primordial.revoked ~= nil and logEntry ~= nil)
		-- ⑤ S1 후속 0-5: /ops stats(이 서버 메모리) · 종료 요약 저장(검증 모드 = _verify 저장소) → /ops stats all
		local AlphaStats = require(script.Parent.AlphaStats)
		AlphaStats.notePull(0.5, 12, 1) -- 리뷰 6: 빈 서버는 저장을 건너뛴다 - 검증용 끌어오기 1건(Studio 메모리 카운터)
		local here = hook:Invoke(player, "/ops stats")
		local saved, entry = AlphaStats.saveSummary()
		local all = hook:Invoke(player, "/ops stats all")
		r.check(("운영 stats: 이 서버 → \"%s\" · 요약 저장 %s · all → \"%s\""):format(tostring(here), tostring(saved), tostring(all)),
			type(here) == "string" and here:find("끌어오기") ~= nil and saved == true and entry ~= nil and type(all) == "string" and all:find("저장된 서버") ~= nil)
		-- 되돌리기
		profile.inventory = savedInv
		profile.audit = savedAudit
		profile.titles = savedTitles
		for key, it in pairs(equipBackup) do
			profile.classes[key[1]].equipment[key[2]] = it
		end
		PlayerProfile.pushInventory(player)
	end)

	root.CFrame = origin
	root.Anchored = wasAnchored
	local pass, total = r.summary()
	print(("===S1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
