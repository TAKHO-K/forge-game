-- M1-0 자동 검증(docs/phase/M1-0-report.md) - 이동 · 카메라 개편(공중 점프 스택형 · 공중대시 섞기 · 아레나 같은 규칙).
--   (가) 공중 점프 식(최대 도달 · 적분 대조) · 조합별 체공 표 · 높이 검증 합성 표본(새 허용치) · [측정] 기존 점프 패턴이 쉬워진 정도(G2b 입력) · 판정 층(8) 위에 머무는 시간.
--   (나) 실제 Player: 합법 최대 높이(발 +19.4)로 띄워도 되돌림 0 · 기본 Shift Lock 꺼짐 · 보스 아레나 안에서 벽 윗면보다 높이 떠 있어도(착지 아님) 복귀 0.
--   클라 공중 점프 · 충전 점 · 모션 · 카메라 · 시점 고정은 서버에서 못 누른다 - 스크린샷 Play에서 MCP로 잰다(보고서).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local HeightGuard = require(script.Parent.HeightGuard)

local M1_0Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[M1-0][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function near(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-6)
end

-- 1단 + 공중 점프를 정점마다 누르는 궤적을 가짜 시계로 적분(클라 규칙 그대로 - 위 속도 = max(지금, 공중 점프 속도)).
local function simulateApexChain(h1, presses)
	local g = MovementConfig.gravity
	local y, v, dt, peak, used = 0, JumpMath.upSpeed(h1), 1 / 600, 0, 0
	for _ = 1, 12000 do
		y += v * dt - g * dt * dt / 2 -- 등가속도 한 걸음은 정확하게(오일러 누적 오차 없이)
		v -= g * dt
		if v <= 0 and used < presses then
			used += 1
			v = math.max(v, JumpMath.upSpeed(JumpMath.airJumpRise(h1)))
		end
		peak = math.max(peak, y)
		if y < 0 then
			break
		end
	end
	return peak
end

-- 파동 박자 i..j를 한 체공으로 넘기는 데 필요한 체공(초): i의 첫 겹이 닿는 순간부터 j의 마지막 겹이 다 지나갈 때까지 떠 있어야 한다(판정 = 띠가 발을 덮는 매 틱에 공중인가).
-- 서는 자리는 보스 곁(0) · 근접 자리(standoff) · 파동 끝(WAVE_MAX) 중 가장 쉬운 곳.
local function coverSeconds(skill, waves, i, j, standoff)
	local best = math.huge
	for _, d in ipairs({ 0, standoff, BossSkillMath.WAVE_MAX_RADIUS_STUDS }) do
		local first = waves[i].startSeconds + d / waves[i].speedStuds
		local last = waves[j].startSeconds + waves[j].layerGapSeconds * (waves[j].layers - 1) + (d + skill.waveThicknessStuds) / waves[j].speedStuds
		best = math.min(best, last - first)
	end
	return best
end

-- 한 체공으로 연달아 넘길 수 있는 최대 박자 수.
local function maxBeatsInOneAir(skill, waves, standoff, air)
	local most = 0
	for i = 1, #waves do
		for j = i, #waves do
			if coverSeconds(skill, waves, i, j, standoff) <= air then
				most = math.max(most, j - i + 1)
			end
		end
	end
	return most
end

function M1_0Verify.runPure()
	print("===M1-0 검증 시작(가)===")
	local r = newRecorder("가")
	local h1 = MovementConfig.jumpHeightStuds
	local dash = DashConfig.durationSeconds
	local layer = TerrainConfig.heightToleranceStuds

	r.section("공중 점프 식", function()
		local reach, reachBonus = JumpMath.maxReachStuds(h1), JumpMath.maxReachStuds(JumpMath.jumpHeight(1))
		local sim1, sim2 = simulateApexChain(h1, 1), simulateApexChain(h1, 2)
		r.check(("충전 %d · 공중 점프 1회 %.2f(1단 %.1f × %.2f) · 최대 발 %.2f(적분 1회 %.2f · 2회 %.2f) · 점프력 상한 %.2f · 높이 검증 허용 %.2f(= %.2f + %.1f)"):format(
			MovementConfig.airJump.charges, JumpMath.airJumpRise(h1), h1, MovementConfig.airJump.heightFraction, reach, sim1, sim2, reachBonus,
			JumpMath.heightGuardAllowance(), reachBonus, MovementConfig.heightGuard.toleranceStuds),
			near(JumpMath.airJumpRise(h1), 6.12) and near(reach, 19.44) and near(sim1, 13.32, 0.05) and near(sim2, 19.44, 0.05) and near(reachBonus, 21.384, 1e-3)
				and near(JumpMath.heightGuardAllowance(), 22.384, 1e-3) and JumpMath.jumpHeight(1) == JumpMath.jumpHeight(0.1))
		local rows, ok = {}, true
		-- 기대값 = 스크래치 air.py(같은 식 · 격자 48)
		for _, c in ipairs({
			{ "1단", 0, nil, 0.542 }, { "공중 1", 1, nil, 1.042 }, { "공중 2", 2, nil, 1.541 },
			{ "1단 + 대시", 0, dash, 0.954 }, { "공중 1 + 대시", 1, dash, 1.459 }, { "공중 2 + 대시", 2, dash, 1.961 },
		}) do
			local t = JumpMath.maxAirSeconds(h1, c[2], c[3])
			ok = ok and near(t, c[4], 0.01)
			table.insert(rows, ("%s %.3f"):format(c[1], t))
		end
		r.check(("한 체공 최대(초): %s (기대 0.542 · 1.042 · 1.541 · 0.954 · 1.459 · 1.961 ± 0.01)"):format(table.concat(rows, " · ")), ok)
		local above = JumpMath.maxAirSeconds(h1, 2, dash, 0, layer)
		local above1 = JumpMath.maxAirSeconds(h1, 1, nil, 0, layer)
		r.check(("[측정] 발이 판정 층 %.0f 위에 머무는 최대: 공중 2 + 대시 %.3f초 · 공중 1 %.3f초 · 1단 0(발 최고 %.1f < %.0f)"):format(layer, above, above1, h1, layer),
			above > 0 and above1 > 0 and h1 < layer)
	end)

	r.section("높이 검증 판정(새 허용치 · 합성)", function()
		local function run(samples)
			local st = { strikes = 0, graceUntil = 0, exemptUntil = 0, reverts = 0 }
			local out = {}
			for i, s in ipairs(samples) do
				table.insert(out, HeightGuard.evaluate(st, s, i * 0.5))
			end
			return table.concat(out, ",")
		end
		local function at(y, grounded)
			return { feetY = y, pos = Vector3.new(0, y + 3, 0), grounded = grounded }
		end
		local chain = run({ at(0, true), at(0, true), at(7.2, false), at(13.3, false), at(19.4, false), at(19.4, false), at(8, false), at(0, true) })
		local dais = run({ at(3.5, true), at(3.5, true), at(10.7, false), at(16.8, false), at(22.9, false), at(0, true) })
		local fly = run({ at(0, true), at(0, true), at(12, false), at(23, false), at(24, false), at(24, false) })
		r.check(("공중 점프 2회 최대(발 19.4) [%s] · 단상 3.5 위에서(발 22.9) [%s] · 날기(발 23 ~ 24 > 허용 %.2f) [%s](기대 둘째 넘음에서 revert)"):format(chain, dais, JumpMath.heightGuardAllowance(), fly),
			chain == "reset,ok,ok,ok,ok,ok,ok,ok" and dais == "reset,ok,ok,ok,ok,ok" and fly == "reset,ok,ok,strike,revert,strike")
	end)

	r.section("[측정] 기존 점프 패턴(파동)이 쉬워진 정도", function()
		local oldAir = JumpMath.maxAirSeconds(h1, 0, dash) -- G2a: 한 체공 = 이단(상한형) 또는 공중대시 - 큰 쪽이 공중대시 0.954
		local jumpAir = BossData.mechanics.dodge.jumpAirSeconds
		local newAir = JumpMath.maxAirSeconds(h1, 2, dash)
		local count = 0
		local bossIds = {}
		for bossId in pairs(BossData.bosses) do
			table.insert(bossIds, bossId)
		end
		table.sort(bossIds)
		for _, bossId in ipairs(bossIds) do
			local boss = BossData.bosses[bossId]
			for _, skillId in ipairs(boss.skillOrder) do
				local skill = boss.skills[skillId]
				if skill.primitive == "ring" then
					count += 1
					local waves = BossSkillMath.ringWaves(skill)
					local standoff = boss.chaseStopDistanceStuds
					local passes, windows = {}, {}
					for i = 1, #waves do
						local pass = coverSeconds(skill, waves, i, i, standoff)
						table.insert(passes, ("%.2f"):format(pass))
						table.insert(windows, ("%.2f→%.2f"):format(jumpAir - pass, newAir - pass))
					end
					local pairsNeed = {}
					for i = 2, #waves do
						table.insert(pairsNeed, ("%d→%d %.2f"):format(i - 1, i, coverSeconds(skill, waves, i - 1, i, standoff)))
					end
					local whole = coverSeconds(skill, waves, 1, #waves, standoff)
					r.check(("[측정] %s.%s 박자 %d: 한 박자 통과 %s초 · 뛰는 타이밍 창(1단 → 새 최대) %s · 두 박자 한 체공에 필요 %s · 전부 한 체공에 %.2f초 · 한 체공 최대 박자 수 G2a %d → 지금 %d(체공 %.3f → %.3f)"):format(
						bossId, skillId, #waves, table.concat(passes, "/"), table.concat(windows, " · "), table.concat(pairsNeed, " · "), whole,
						maxBeatsInOneAir(skill, waves, standoff, oldAir), maxBeatsInOneAir(skill, waves, standoff, newAir), oldAir, newAir), true)
				end
			end
		end
		-- 판정 층 위로 피하는 지면 패턴(원 · 직선 · 돌진 - 판정 = 발 기준 높이차 ≤ 8): 공중 점프 1회면 발 13.3으로 층 위
		local byPrimitive = {}
		for _, boss in pairs(BossData.bosses) do
			for _, skill in pairs(boss.skills) do
				byPrimitive[skill.primitive] = (byPrimitive[skill.primitive] or 0) + 1
			end
		end
		r.check(("[측정] 파동 스킬 %d개(기대 3) · 스킬 종류 수: 원(보스) %d · 원(대상) %d · 직선 %d · 돌진 %d · 파동 %d · 기믹 %d - 원 · 직선 · 돌진은 발이 판정 층 %.0f 위면 안 맞는다(공중 점프 1회 = 발 %.1f)"):format(
			count, byPrimitive.circleBoss or 0, byPrimitive.circleTarget or 0, byPrimitive.line or 0, byPrimitive.charge or 0, byPrimitive.ring or 0, byPrimitive.gimmick or 0,
			layer, h1 + JumpMath.airJumpRise(h1)), count == 3)
		local wall = BossArenaMapData.geometry.wallHeightStuds
		r.check(("[측정] 아레나 벽 %d: 바닥에서 최대 발 %.2f · 단상(3.5) 위 %.2f → 넘을 수 있다(넘으면 원 밖 → 본인 스폰 + 보호 %.2f초)"):format(
			wall, JumpMath.maxReachStuds(h1), 3.5 + JumpMath.maxReachStuds(h1), BossArenaMapData.containment.returnProtectSeconds), JumpMath.maxReachStuds(h1) > wall)
	end)

	local pass, count = r.summary()
	print(("===M1-0 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

function M1_0Verify.runLive(player, env)
	print("===M1-0 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local MonsterState = require(script.Parent.MonsterState)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaContainment = require(script.Parent.BossArenaContainment)
	local BossArenaMap = require(script.Parent.BossArenaMap)

	-- 루트를 발 높이 feetY(절대)에 seconds 동안 붙잡았다가 놓는다(서버가 만든 제약은 소유 클라 물리에도 걸린다 - G2a(나)와 같은 방법).
	local function hold(root, position, seconds)
		local attachment = Instance.new("Attachment")
		attachment.Parent = root
		local align = Instance.new("AlignPosition")
		align.Mode = Enum.PositionAlignmentMode.OneAttachment
		align.Attachment0 = attachment
		align.RigidityEnabled = true
		align.Position = position
		align.Parent = root
		task.wait(seconds)
		align:Destroy()
		attachment:Destroy()
	end

	r.section("높이 검증 - 합법 최대 높이", function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		assert(root, "캐릭터 없음")
		BossEncounter.despawnFor(player)
		HeightGuard.debugOff = false
		HeightGuard.reset(player)
		task.wait(1.5)
		local st = HeightGuard.getState(player)
		local reverts0 = st.reverts
		local base = root.Position
		-- 공중 점프 2회 정점(발 +19.4) 근처에 0.6초(정점 체류보다 길게) → 되돌림 0
		hold(root, base + Vector3.new(0, JumpMath.maxReachStuds() - 0.2, 0), 0.6)
		task.wait(2)
		local legit = st.reverts - reverts0
		-- 허용치 + 3 위에 붙잡기 → 되돌림
		local before = st.reverts
		hold(root, base + Vector3.new(0, JumpMath.heightGuardAllowance() + 3, 0), 1.5)
		task.wait(0.5)
		local caught = st.reverts - before
		r.check(("발 +%.1f(공중 점프 2회 정점)에 0.6초 → 되돌림 %d(기대 0) · 발 +%.1f(허용 %.2f + 3)에 1.5초 → 되돌림 %d(기대 ≥ 1)"):format(
			JumpMath.maxReachStuds() - 0.2, legit, JumpMath.heightGuardAllowance() + 3, JumpMath.heightGuardAllowance(), caught), legit == 0 and caught >= 1)
		st.flaggedAt = nil
	end)
	HeightGuard.debugOff = true -- 절 안에서 에러가 나도 체인에는 꺼진 채로

	r.section("기본 Shift Lock 꺼짐", function()
		r.check(("DevEnableMouseLock = %s(기대 false - 대시 LeftShift와 충돌 0) · 중계 Remote AirMoveFx %s"):format(tostring(player.DevEnableMouseLock), tostring(ReplicatedStorage:FindFirstChild("AirMoveFx") ~= nil)),
			player.DevEnableMouseLock == false and ReplicatedStorage:FindFirstChild("AirMoveFx") ~= nil)
	end)

	r.section("아레나 - 벽 윗면보다 높이 떠 있어도 복귀 0", function()
		BossEncounter.despawnFor(player)
		env.applyStage(player, 10)
		BossEncounter.spawnFor(player, 10)
		local encounter = BossEncounter.getEncounter(player)
		assert(encounter and encounter.model, "보스 스폰 실패")
		task.wait(1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		assert(root, "캐릭터 없음")
		local floorTop = BossArenaMap.floorTopY()
		local spot = root.Position - Vector3.new(0, root.Position.Y, 0) -- 입장 자리 바로 위(아레나 안)
		local before = #BossArenaContainment.corrections()
		local feet = floorTop + BossArenaMapData.geometry.wallHeightStuds + 2 -- 벽 윗면 + 2(옛 규칙: 1초 넘게 머물면 복귀)
		hold(root, spot + Vector3.new(0, feet + MovementConfig.rootAboveFeetStuds, 0), 1.8)
		task.wait(1)
		local after = #BossArenaContainment.corrections()
		r.check(("아레나 안 공중 발 %.1f(바닥 + 벽 %d + 2)에 1.8초 → 복귀 %d(기대 0 - 벽 위에 서 있을 때만 잰다)"):format(feet - floorTop, BossArenaMapData.geometry.wallHeightStuds, after - before), after == before)
		-- 리뷰 2: 벽 윗면에 선 뒤 점프를 누르고 있어도(폴링이 공중만 봐도) 복귀한다 - 벽 윗면 띠(반경 R + 1.8 · 변 가운데)에 세우고 0.1초마다 Jump
		local zone = require(ReplicatedStorage.Shared.data.WorldConfig).zones[encounter.zoneKey]
		local angle = math.rad(180 / BossArenaMapData.geometry.wallSegments)
		local top = zone.center + Vector3.new(math.cos(angle) * (zone.radius + 1.8), 0, math.sin(angle) * (zone.radius + 1.8))
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		local before2 = #BossArenaContainment.corrections()
		player.Character:PivotTo(CFrame.new(top.X, floorTop + BossArenaMapData.geometry.wallHeightStuds + 3, top.Z))
		local t0 = os.clock()
		while #BossArenaContainment.corrections() == before2 and os.clock() - t0 < 4 do
			humanoid.Jump = true
			task.wait(0.1)
		end
		local fix = BossArenaContainment.corrections()[before2 + 1]
		r.check(("벽 윗면에서 점프를 누르고 있음 → %.2f초 뒤 복귀 %s(기대 offFloor · ≤ 2.5초)"):format(os.clock() - t0, tostring(fix and fix.reason)), fix ~= nil and fix.reason == "offFloor" and os.clock() - t0 <= 2.5)
		task.wait(BossArenaMapData.containment.returnProtectSeconds + 0.1)
		BossEncounter.despawnFor(player)
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
	local pass, count = r.summary()
	print(("===M1-0 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return M1_0Verify
