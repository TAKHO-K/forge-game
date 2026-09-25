-- G1-0 자동 검증(docs/phase/G1-0-report.md).
--   (가) 순수: ① 받는 피해 배율 하한 0.25(스탠드인) ② 재생성 자리 찾기 체크포인트 간격(프레임 분할 ≤ 2ms 근거) ③ 단상 위 점프 = 평지 점프(발밑 지면 기준)
--        ④ 맵 이탈 복귀 경로 1,000회 시뮬(벽 위 · 맵 바깥 지면 · 허공 · 점프 중 넉백 · 연쇄 넉백 · 복귀 직후 재이탈)
--   (나) 실제 보스전: 배율 하한(실제 Player) · 복귀 표본(벽 위 · 바깥 지면 · 허공 · 연쇄 · 재이탈 · 오탐 없음) · 단상 위 점프 판정 · 12인 재생성 전후(한 번에 vs 나눠서)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)
local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
local Reach = require(ReplicatedStorage.Shared.Reach)

local G1_0Verify = {}

local REGROW = BossArenaMapData.regrow
local CONTAINMENT = BossArenaMapData.containment
local GEOMETRY = BossArenaMapData.geometry
local BOSSES = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-0][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[G1-0][%s] %s"):format(tag, label))
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
	return math.abs(a - b) <= (tol or 1e-9)
end

-- ─────────────────────────── 복귀 경로 시뮬(순수) ───────────────────────────
-- 한 조합 = 경로 하나. 떨어진 뒤 서버 규칙(0.25초 검사 · 원 밖 · 바닥 아래 · 벽 윗면 1초)을 시간 순으로 돌린다. 규칙 함수는 게임과 같다(ArenaContainment).
-- 복귀는 순간이동만(체력 · 누적 불변 - 코드 경로 checkMember) · 스폰 자리 = BossArenaMap.entryPosition과 같은 식 · 스폰 자리가 구조물에 덮였는가는 실제 배치(generate)로 잰다.
local GRAVITY = 196.2
local function simulatePaths(trials, seed)
	local state = seed
	local function rand()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local R, floorTop, wallH = GEOMETRY.radiusStuds, 1, GEOMETRY.wallHeightStuds
	local zone = { center = Vector3.new(0, floorTop, 0), radius = R }
	local kinds = { "wallTop", "outsideGround", "void", "jumpKnock", "chainKnock", "relaunch" }
	local out = { trials = 0, byKind = {}, returned = 0, needReturn = 0, missed = 0, falseReturn = 0, slow = 0, maxSeconds = 0, spawnBlocked = 0, protectMissing = 0, suppressed = 0 }
	-- 스폰 자리(1 ~ 4인)와 실제 배치 6맵 × 20시드의 겹침
	local layouts = {}
	for _, bossId in ipairs(BOSSES) do
		for s = 1, 20 do
			table.insert(layouts, ArenaLayout.generate(BossArenaMapData.maps[bossId], 9100 + s, ArenaLayout.optionsFor(BossData.bosses[bossId])))
		end
	end
	local function spawnOf(index, count)
		local offset = math.deg(((index - 1) - (count - 1) / 2) * 4 / GEOMETRY.entryDistanceStuds)
		local a = math.rad(GEOMETRY.entryAngleDeg + offset)
		return Vector3.new(math.cos(a) * GEOMETRY.entryDistanceStuds, floorTop, math.sin(a) * GEOMETRY.entryDistanceStuds)
	end
	for _, layout in ipairs(layouts) do
		for count = 1, 4 do
			for index = 1, count do
				local p = spawnOf(index, count)
				for _, item in ipairs(layout.items) do
					for _, c in ipairs(item.colliders) do
						if math.sqrt((p.X - c.x) ^ 2 + (p.Z - c.z) ^ 2) < c.r + 1.5 + 0.5 then
							out.spawnBlocked += 1
						end
					end
				end
			end
		end
	end
	for _ = 1, trials do
		out.trials += 1
		local kind = kinds[1 + math.floor(rand() * #kinds)]
		out.byKind[kind] = (out.byKind[kind] or 0) + 1
		local a = rand() * 2 * math.pi
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		-- 경로 = 시각별 (반경, 발 높이) 함수. rest = 경로가 끝난 뒤 서 있는 곳(반경, 발 높이, 떨어지는 중인가).
		local path -- function(t) → radial, feetY
		local mustReturn = true
		if kind == "wallTop" then -- 벽 윗면 안쪽 띠(원 밖 판정에 안 걸리는 곳)에 착지해 서 있다
			local rr = R + 0.5 + rand() * (CONTAINMENT.outsideToleranceStuds - 0.5)
			local land = 0.2 + rand() * 0.4
			path = function(t)
				if t < land then
					return R - 10 + (rr - R + 10) * t / land, floorTop + wallH + 3 * math.sin(math.pi * t / land)
				end
				return rr, floorTop + wallH
			end
		elseif kind == "outsideGround" then -- 벽 너머 테라스(바닥보다 rimDrop 낮음)
			local rr = R + GEOMETRY.wallThicknessStuds + rand() * GEOMETRY.rimWidthStuds
			path = function(t)
				local land = 0.6
				if t < land then
					return R - 6 + (rr - R + 6) * t / land, floorTop + 16 * math.sin(math.pi * t / land)
				end
				return rr, floorTop - GEOMETRY.rimDropStuds
			end
		elseif kind == "void" then -- 테라스 밖 허공 - 계속 떨어진다
			local rr = R + GEOMETRY.wallThicknessStuds + GEOMETRY.rimWidthStuds + 5 + rand() * 40
			path = function(t)
				return math.min(R - 6 + (rr - R + 6) * t / 0.8, rr), floorTop + 16 - 0.5 * GRAVITY * math.max(t - 0.4, 0) ^ 2
			end
		elseif kind == "jumpKnock" then -- 점프 중(발 0 ~ 7.2, 단상 위면 +3.5) 넉백 7.5 - 아레나 안 착지(벽 높이를 넘어도 안쪽에 떨어지면 복귀 없음이 맞다)
			local start = rand() * 7.2 + (rand() < 0.3 and 3.5 or 0)
			local r0 = rand() * (R - 20)
			local apex = start + 7.5
			local up = math.sqrt(2 * 7.5 / GRAVITY)
			local down = math.sqrt(2 * apex / GRAVITY)
			path = function(t)
				local y
				if t < up then
					y = start + 7.5 - 0.5 * GRAVITY * (up - t) ^ 2
				else
					y = math.max(apex - 0.5 * GRAVITY * (t - up) ^ 2, 0)
				end
				return math.min(r0 + 12 * math.min(t / (up + down), 1), R - 1), floorTop + y
			end
			mustReturn = false
		elseif kind == "chainKnock" then -- 연쇄 넉백: 0.1 ~ 0.6초 간격 2 ~ 4번 - 마지막에 바깥 지면
			local n = 2 + math.floor(rand() * 3)
			local gap = 0.1 + rand() * 0.5
			local rr = R + GEOMETRY.wallThicknessStuds + rand() * GEOMETRY.rimWidthStuds
			path = function(t)
				local k = math.min(math.floor(t / gap), n)
				local frac = k / n
				return R - 30 + (rr - R + 30) * frac, floorTop + (k < n and 10 or -GEOMETRY.rimDropStuds)
			end
		else -- relaunch: 바깥 지면 → 복귀 → 복귀 직후(보호 안) 다시 넉백 시도 = 무시 · 보호 뒤 다시 날아가 벽 위 → 다시 복귀
			local rr = R + GEOMETRY.wallThicknessStuds + 5
			path = function(t)
				return (t < 0.3) and (R - 5 + (rr - R + 5) * t / 0.3) or rr, floorTop - GEOMETRY.rimDropStuds
			end
		end
		-- 서버 규칙을 0.25초마다
		local offSince, returnedAt, t, returns = nil, nil, 0, 0
		local position -- 복귀 뒤에는 스폰 자리에 선다
		local protectUntil = -math.huge
		local secondPhase = false
		while t < 6 do
			t += CONTAINMENT.checkIntervalSeconds
			local radial, feetY
			if position then
				radial, feetY = position.radial, position.feetY
			else
				radial, feetY = path(t)
			end
			local p = Vector3.new(radial * dir.X, feetY + 3, radial * dir.Z)
			local outside = ArenaContainment.isOutside(zone, p, floorTop)
			if ArenaContainment.isOffFloorHeight(feetY, floorTop, wallH) then
				offSince = offSince or t
				if not outside and t - offSince >= CONTAINMENT.offFloorReturnSeconds then
					outside = true
				end
			else
				offSince = nil
			end
			if outside then
				returnedAt = returnedAt or t
				returns += 1
				out.returned += 1
				position = { radial = GEOMETRY.entryDistanceStuds, feetY = floorTop }
				offSince = nil
				protectUntil = t + CONTAINMENT.returnProtectSeconds
				if protectUntil <= t then
					out.protectMissing += 1
				end
				if kind == "relaunch" and not secondPhase then
					-- 복귀 직후 넉백: 보호 안이면 무시된다(BossArenaContainment.isProtected → 넉백 건너뜀)
					if t + 0.1 < protectUntil then
						out.suppressed += 1
					end
					-- 보호가 끝난 뒤 다시 날아가 벽 윗면에 착지 → 1초 뒤 다시 복귀해야 한다
					secondPhase = true
					local again = t + CONTAINMENT.returnProtectSeconds + 0.05
					path = function(tt)
						if tt < again then
							return GEOMETRY.entryDistanceStuds, floorTop
						end
						return R + 1, floorTop + wallH
					end
					position = nil
				end
			end
		end
		if mustReturn then
			out.needReturn += 1
			if not returnedAt or (kind == "relaunch" and returns < 2) then
				out.missed += 1
			else
				out.maxSeconds = math.max(out.maxSeconds, returnedAt)
				out.slow += returnedAt > 2 and 1 or 0
			end
		elseif returnedAt then
			out.falseReturn += 1
		end
	end
	return out
end

function G1_0Verify.runPure()
	print("===G1-0 검증 시작(가)===")
	local r = newRecorder("가")
	local PlayerState = require(script.Parent.PlayerState)

	r.section("① 받는 피해 배율 하한", function()
		local stand = { Name = "G10Stand", UserId = -9701 }
		PlayerState.init(stand)
		PlayerState.setIncomingDamageMultiplierUntil(stand, 0.5, 5, "a")
		local one = PlayerState.getIncomingDamageMultiplier(stand)
		PlayerState.setIncomingDamageMultiplierUntil(stand, 0.5, 5, "b")
		local two = PlayerState.getIncomingDamageMultiplier(stand)
		PlayerState.setIncomingDamageMultiplierUntil(stand, 0.5, 5, "c")
		local three = PlayerState.getIncomingDamageMultiplier(stand)
		PlayerState.setIncomingDamageMultiplierUntil(stand, 1.3, 5, "up")
		local withUp = PlayerState.getIncomingDamageMultiplier(stand)
		PlayerState.setInvulnerableUntil(stand, 5, "inv")
		local inv = PlayerState.getIncomingDamageMultiplier(stand)
		PlayerState.clearIncomingDamageMultiplier(stand)
		local floor = CombatConfig.incomingDamageMultiplierFloor
		r.check(("① 0.5 한 개 ×%.3f · 두 개 ×%.3f · 세 개(곱 0.125) ×%.3f(기대 하한 %.2f) · +증가 1.3 ×%.3f(기대 max(0.1625, 0.25)) · 무적 ×%.0f(기대 0 - 하한과 무관)"):format(
			one, two, three, floor, withUp, inv),
			near(one, 0.5) and near(two, 0.25) and near(three, floor) and near(withUp, floor) and inv == 0 and floor == 0.25)
	end)

	r.section("② 재생성 자리 찾기 - 체크포인트 간격", function()
		-- 체크포인트 사이 계산이 가장 길 때(ms). 서버는 조각이 예산 × yieldAtFraction을 넘은 뒤 다음 체크포인트에서 양보하므로 한 프레임 ≤ 그 값 + 가장 긴 간격.
		local state = 20260925
		local function rng()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		local maxGap, calls, spots, totalMs, maxMs = 0, 0, 0, 0, 0
		local last = nil
		local function checkpoint()
			local now = os.clock()
			if last then
				maxGap = math.max(maxGap, now - last)
			end
			calls += 1
			last = now
		end
		for _, bossId in ipairs(BOSSES) do
			local theme = BossArenaMapData.maps[bossId]
			local opts = ArenaLayout.optionsFor(BossData.bosses[bossId])
			for s = 1, 10 do
				local layout = ArenaLayout.generate(theme, 8800 + s, opts)
				local items = table.clone(layout.items)
				for e = 1, 12 do
					last = nil
					local t0 = os.clock()
					local item = ArenaLayout.regrowSpot(theme, items, rng, { kit = opts.kit, coverageMin = 0, members = { { x = 10, z = 10 } }, boss = { x = 0, z = 0 }, pits = {}, mounds = layout.mounds, checkpoint = checkpoint }, 2000 + e)
					local ms = (os.clock() - t0) * 1000
					totalMs, maxMs, spots = totalMs + ms, math.max(maxMs, ms), spots + 1
					if item and #items < REGROW.maxObstacles then
						table.insert(items, item)
					end
				end
				task.wait()
			end
		end
		-- 솟기 직전 다시 보기 = 연결 검사 한 번(나누지 않는다) - 상한 14개 배치에서 한 번 걸리는 시간
		local openMax = 0
		for _, bossId in ipairs(BOSSES) do
			local theme = BossArenaMapData.maps[bossId]
			local opts = ArenaLayout.optionsFor(BossData.bosses[bossId])
			for s = 1, 10 do
				local layout = ArenaLayout.generate(theme, 8900 + s, opts)
				local t0 = os.clock()
				ArenaLayout.regrowOpen(layout.items, opts)
				openMax = math.max(openMax, (os.clock() - t0) * 1000)
			end
		end
		r.note(("② 연결 검사 한 번 최대 %.3fms(참고 - 게임 경로는 자리 찾기 · 솟기 전 다시 보기 모두 나눠 돈다)"):format(openMax))
		local bound = REGROW.frameBudgetMs * REGROW.yieldAtFraction + maxGap * 1000
		r.check(("② %d회 자리 찾기(한 번에 돌면 평균 %.2f · 최대 %.2fms) · 체크포인트 %d번 · 가장 긴 간격 %.3fms → 한 프레임 상한 %.2f × %.1f + %.3f = %.2fms(기대 ≤ %.1f)"):format(
			spots, totalMs / math.max(spots, 1), maxMs, calls, maxGap * 1000, REGROW.frameBudgetMs, REGROW.yieldAtFraction, maxGap * 1000, bound, REGROW.frameBudgetMs),
			bound <= REGROW.frameBudgetMs)
	end)

	r.section("③ 단상 위 점프 = 평지 점프(발밑 지면)", function()
		-- 판정 높이차 상한(TerrainConfig.heightToleranceStuds 8)과 점프 발 최고 7.2 · 단상 윗면 3.5: 옛 기준(아레나 바닥)이면 3.5 + 7.2 = 10.7 > 8.
		local daisTop = BossArenaMapData.obstacle.climbHeightStuds or 3.5
		local jump = 7.2
		local old = Reach.sameLayer(Vector3.new(0, daisTop + jump, 0), Vector3.new(0, 0, 0))
		local new = Reach.sameLayer(Vector3.new(0, daisTop + jump - daisTop, 0), Vector3.new(0, 0, 0))
		local g = 196.2
		local v0 = math.sqrt(2 * g * jump)
		-- 옛 기준에서 빠지던 시간: 발이 바닥 + 8을 넘는 구간(단상 위 이륙)
		local above = daisTop + jump - TerrainConfig.heightToleranceStuds
		local missed = above > 0 and 2 * math.sqrt(2 * above / g) or 0
		r.check(("③ 단상(%.1f) 위 점프 정점 발 %.1f: 옛 판정 %s(빠지던 시간 %.3f초 - D0 0.332) → 새 판정(발밑 지면 기준 %.1f) %s · 초속 %.1f"):format(
			daisTop, daisTop + jump, tostring(old), missed, jump, tostring(new), v0), old == false and new == true and near(missed, 0.332, 0.01))
	end)

	r.section("④ 맵 이탈 복귀 경로 1,000회", function()
		local out = simulatePaths(1000, 20260925)
		local kinds = {}
		for k, n in pairs(out.byKind) do
			table.insert(kinds, ("%s %d"):format(k, n))
		end
		table.sort(kinds)
		r.check(("④ %d회(%s): 복귀가 필요한 경우 %d · 놓침 %d · 오탐(안쪽 착지인데 복귀) %d · 2초 넘김 %d · 최장 %.2f초 · 보호 누락 %d · 복귀 직후 넉백 무시 %d · 스폰 자리 구조물 겹침 %d(6맵 × 20시드 × 1 ~ 4인) · 사망 · 낙하 피해 · 체력 · 누적 변화 = 순간이동만(코드 경로)"):format(
			out.trials, table.concat(kinds, " · "), out.needReturn, out.missed, out.falseReturn, out.slow, out.maxSeconds, out.protectMissing, out.suppressed, out.spawnBlocked),
			out.missed == 0 and out.falseReturn == 0 and out.slow == 0 and out.protectMissing == 0 and out.spawnBlocked == 0 and out.suppressed == (out.byKind.relaunch or 0))
	end)

	local pass, count = r.summary()
	print(("===G1-0 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

-- ─────────────────────────── (나) 실제 보스전 ───────────────────────────
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

function G1_0Verify.runLive(player, env)
	print("===G1-0 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
	local BossArenaContainment = require(script.Parent.BossArenaContainment)
	local BossMechanics = require(script.Parent.BossMechanics)
	local MonsterState = require(script.Parent.MonsterState)
	local PlayerState = require(script.Parent.PlayerState)
	local root = nil
	local function refreshRoot()
		for _ = 1, 100 do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			root = character and character:FindFirstChild("HumanoidRootPart")
			if root and humanoid and humanoid.Health > 0 then
				return
			end
			task.wait(0.1)
		end
	end
	refreshRoot()
	local FLOOR = BossArenaMap.floorTopY()

	r.section("A 배율 하한(실제 Player)", function()
		PlayerState.clearIncomingDamageMultiplier(player)
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 3, "skill:greatsword:E")
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 3, "dash")
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 3, "g10:extra")
		local m = PlayerState.getIncomingDamageMultiplier(player)
		PlayerState.clearIncomingDamageMultiplier(player)
		r.check(("A 회전베기 × 대시 × 추가 0.5 = ×%.3f(기대 하한 %.2f)"):format(m, CombatConfig.incomingDamageMultiplierFloor), near(m, CombatConfig.incomingDamageMultiplierFloor))
	end)

	r.section("B 복귀 표본", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 1001)
		local zone = WorldConfig.zones[encounter.zoneKey]
		BossPatterns.setGrace(model, data, 120)
		refreshRoot()
		root.Anchored = false
		local spawn = BossArenaContainment.spawnPointFor(encounter, player)
		BossMechanics.applyGimmickDamage(model, player, 0.1, "G1-0 검증 누적")
		local function sample(label, position, expectReason, timeout)
			refreshRoot()
			root.Anchored = false
			local hpBefore = PlayerState.getHp(player)
			local stackBefore = BossMechanics.gimmickDamageOf(model, player)
			local before = #BossArenaContainment.corrections()
			root.AssemblyLinearVelocity = Vector3.zero
			player.Character:PivotTo(CFrame.new(position))
			local waited = 0
			while #BossArenaContainment.corrections() == before and waited < timeout do
				waited += task.wait(0.05)
			end
			local fix = BossArenaContainment.corrections()[before + 1]
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local alive = humanoid ~= nil and humanoid.Health > 0 and (PlayerState.getHp(player) or 0) > 0
			local protected = BossArenaContainment.isProtected(player) and BossArenaMap.isLaunchProtected ~= nil and BossArenaMap.isLaunchProtected(player) -- 받는 피해 0 + 넉백 무시(복귀 직후 재이탈 방지)
			local dist = spawn and fix and (Vector3.new(fix.to.X, 0, fix.to.Z) - Vector3.new(spawn.X, 0, spawn.Z)).Magnitude or -1
			local stuck = fix ~= nil and BossArenaMap.overlapsObstacle(encounter.zoneKey, fix.to, 1.5, 0.5)
			if expectReason == nil then
				r.check(("B %s: %.2f초 동안 복귀 %s(기대 없음 - 오탐 0)"):format(label, waited, tostring(fix and fix.reason)), fix == nil)
				return
			end
			r.check(("B %s → %.2f초 뒤 %s(기대 %s) · 스폰까지 %.2f · 끼임 %s · 살아 있음 %s · 체력 %.1f → %.1f · 누적 %.3f → %.3f · 보호 %s"):format(label, waited, tostring(fix and fix.reason), expectReason,
				dist, tostring(stuck), tostring(alive), hpBefore, PlayerState.getHp(player), stackBefore, BossMechanics.gimmickDamageOf(model, player), tostring(protected)),
				fix ~= nil and fix.reason == expectReason and fix.spawn == true and dist >= 0 and dist < 0.5 and not stuck and alive
					and near(PlayerState.getHp(player), hpBefore, 1e-6) and near(BossMechanics.gimmickDamageOf(model, player), stackBefore, 1e-9) and protected)
			task.wait(CONTAINMENT.returnProtectSeconds + 0.1)
		end
		local function at(radial, y, angleDeg)
			local a = math.rad(angleDeg or 0)
			return zone.center + Vector3.new(math.cos(a) * radial, 0, math.sin(a) * radial) + Vector3.new(0, y - zone.center.Y, 0)
		end
		-- 벽 윗면 안쪽 띠(반경 R + 1.5 - 원 밖 허용 2 안) · 발 = 벽 윗면
		-- 24각형 변의 가운데(7.5°)는 안쪽 면이 반경 R - 캐릭터 중심을 R + 1.8(원 밖 허용 2 안)에 두면 벽 윗면에 선다(꼭짓점 0°는 면이 R × 1.0086이라 미끄러져 안으로 떨어졌다 - Play 1)
		sample("벽 위 착지(반경 R + 1.8)", at(zone.radius + 1.8, FLOOR + GEOMETRY.wallHeightStuds + 3, 180 / GEOMETRY.wallSegments), "offFloor", 3)
		sample("맵 바깥 지면(테라스)", at(zone.radius + GEOMETRY.wallThicknessStuds + 10, FLOOR - GEOMETRY.rimDropStuds + 3, 30), "outside", 2)
		sample("허공(테라스 밖)", at(zone.radius + GEOMETRY.wallThicknessStuds + GEOMETRY.rimWidthStuds + 20, FLOOR + 10, 60), "outside", 2)
		-- 연쇄: 복귀 직후(보호 안) 곧바로 다시 바깥 → 다음 검사에서 다시 복귀
		sample("연쇄 1(바깥)", at(zone.radius + 20, FLOOR - GEOMETRY.rimDropStuds + 3, 90), "outside", 2)
		sample("연쇄 2(보호 중 다시 바깥)", at(zone.radius + 20, FLOOR - GEOMETRY.rimDropStuds + 3, 120), "outside", 2)
		-- 오탐 없음: 아레나 안 높이 뜸(벽 윗면보다 조금 높이 - 떨어지며 1초 안에 내려온다) · 평지 점프 높이
		sample("아레나 안 공중(발 15 → 떨어짐)", at(40, FLOOR + 15 + 3, 200), nil, 1.6)
		sample("아레나 안 점프 높이(발 7.2)", at(50, FLOOR + 7.2 + 3, 220), nil, 1.2)
		BossEncounter.despawnFor(player)
		fullHeal(player)
	end)

	r.section("C 단상 위 점프 판정(발밑 지면)", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 1002)
		BossPatterns.setGrace(model, data, 60)
		local dais = nil
		for _, o in ipairs(BossArenaMap.obstacles(encounter.zoneKey)) do
			if o.climbable and not dais then
				dais = o
			end
		end
		assert(dais, "단상이 없다")
		local c = dais.colliders[1]
		local top = BossArenaMap.obstacleTop(encounter.zoneKey, dais.id)
		local onDais = Vector3.new(c.center.X, top + 7.2, c.center.Z)
		local offDais = Vector3.new(c.center.X + c.r + 12, FLOOR + 7.2, c.center.Z)
		local g1 = BossPatterns.groundFeet(encounter.zoneKey, FLOOR, onDais)
		local g2 = BossPatterns.groundFeet(encounter.zoneKey, FLOOR, offDais)
		local floorRef = Vector3.new(0, FLOOR, 0)
		r.check(("C 단상(윗면 %.1f) 위 점프 발 %.1f: 옛 %s → 새 발밑 기준 %.1f %s · 평지 점프 %.1f %s(둘 다 판정 안)"):format(top - FLOOR, onDais.Y - FLOOR,
			tostring(Reach.sameLayer(onDais, floorRef)), g1.Y - FLOOR, tostring(Reach.sameLayer(g1, floorRef)), g2.Y - FLOOR, tostring(Reach.sameLayer(g2, floorRef))),
			not Reach.sameLayer(onDais, floorRef) and Reach.sameLayer(g1, floorRef) and Reach.sameLayer(g2, floorRef) and near(g1.Y - FLOOR, 7.2, 0.05))
		BossEncounter.despawnFor(player)
	end)

	r.section("D 12인 재생성 전후(한 번에 vs 나눠서)", function()
		BossEncounter.despawnFor(player)
		local Stats = game:GetService("Stats")
		local function run(sliced)
			local keys = {}
			for slot = 1, WorldConfig.bossArena.slotCount do
				local zoneKey = "bossArena" .. slot
				BossArenaMap.dress(zoneKey, BossData.bosses[BOSSES[1 + (slot - 1) % #BOSSES]], 7100 + slot)
				table.insert(keys, zoneKey)
			end
			local frameMax, frames, planMax, planSlices, maxSlice, done = 0, 0, 0, 0, 0, 0
			BossArenaMap.debugFrameUsedPeakMs(true)
			local conn = RunService.Heartbeat:Connect(function()
				frames += 1
				frameMax = math.max(frameMax, Stats.HeartbeatTimeMs)
			end)
			-- 12개 아레나가 동시에 재생성을 16번씩(상한을 넘겨 교체까지) - 게임 경로처럼 각자 스레드
			for _, zoneKey in ipairs(keys) do
				task.spawn(function()
					local zone = WorldConfig.zones[zoneKey]
					for _ = 1, REGROW.maxObstacles + 2 do
						local t0 = os.clock()
						local plan = BossArenaMap.planRegrow(zoneKey, { members = {}, boss = zone.center, pits = {}, sliced = sliced })
						planMax = math.max(planMax, (os.clock() - t0) * 1000)
						if plan then
							planSlices += plan.frames or 1
							maxSlice = math.max(maxSlice, plan.maxSliceMs or (os.clock() - t0) * 1000)
							BossArenaMap.spawnRegrown(zoneKey, plan)
						end
						RunService.Heartbeat:Wait()
					end
					done += 1
				end)
			end
			local waited = 0
			while done < #keys and waited < 30 do
				waited += RunService.Heartbeat:Wait()
			end
			conn:Disconnect()
			local framePeak = BossArenaMap.debugFrameUsedPeakMs(true) -- 리뷰 2: 서버 전체 한 프레임 합(아레나 12개 스레드 합)
			for _, zoneKey in ipairs(keys) do
				BossArenaMap.undress(zoneKey)
			end
			return frameMax, sliced and framePeak or maxSlice, planMax, planSlices, waited
		end
		local f0, s0, p0, _, w0 = run(false)
		task.wait(0.5)
		local f1, s1, p1, n1, w1 = run(true)
		r.check(("D 12아레나 × %d회 동시: 한 번에 - Heartbeat 최대 %.2fms · 자리 찾기 한 번 최대 %.2fms(%.1f초) → 나눠서 - Heartbeat 최대 %.2fms · 한 프레임 합(12아레나) 최대 %.2fms(기대 ≤ %.1f) · 조각 %d · 끝까지 최대 %.1fms(%.1f초)"):format(
			REGROW.maxObstacles + 2, f0, s0, w0, f1, s1, REGROW.frameBudgetMs, n1, p1, w1), s1 <= REGROW.frameBudgetMs and f1 <= f0)
	end)

	PlayerState.clearIncomingDamageMultiplier(player)
	env.restore(player)
	local orphan = 0
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if d and d.isBoss and not BossEncounter.getEncounterByModel(m) then
			orphan += 1
		end
	end
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphan), orphan == 0)
	local passCount, totalCount = r.summary()
	print(("===G1-0 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

return G1_0Verify
