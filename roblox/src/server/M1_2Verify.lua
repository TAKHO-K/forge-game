-- M1-2 자동 검증(마을 · 나무 다듬기 · 몬스터 스폰 범위 · 귀환 · M1 결정 반영). (가) = 서버 시작 때 순수 계산 · (나) = 검증 체인(실제 서버 경로).
--   (가) C안 공동 책임(데이터 · 모형 파티 전멸 30 ~ 50%) · 정거장 기준 · 스폰 지점 배치(구역당 수 · 간격 · 회피 · 범위 안) · 스폰 사이클 1,000회 시뮬(누수 · 중복 · 전투 중 정리 · 처치 중 정리 0) ·
--        마을(안전 반경 · 잎 덮개 · 거리 배치 겹침 0) · 귀환 수치 · 뿌리(경사 · 땅속 끝 · 코스 뿌리 = 공중 점프 · 일반 뿌리 지름길 0) · 윗잎(전망대 눈높이 위) · 스트리밍 켜짐
--   (나) 스폰 지점 실제 사이클(짧은 정리 시간으로 20회) · 전투 중 보류 · 처치 판정 중 남김 · 귀환 시전 · 맞으면 취소 · 돌아가기 1회 · 뿌리 밟기
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local BossData = require(ReplicatedStorage.Shared.data.BossData)

local M1_2Verify = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1-2][%s] %s"):format(tag, label))
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

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 스폰 사이클 시뮬(순수 - SpawnSites.tick에 가짜 훅). 반환: 결과 표
function M1_2Verify.simulateCycles(cycles, seed)
	local SpawnSites = require(script.Parent.SpawnSites)
	local CFG = WorldMapData.spawnSites
	local rng = Random.new(seed or 1)
	local list = SpawnSites.buildPoints()
	local alive = {} -- [model] = true
	local res = { cycles = 0, spawned = 0, cleared = 0, dupSpawn = 0, clearedEngaged = 0, clearedDying = 0, leaks = 0, rewardLost = 0, held = 0, dyingKept = 0, respawnInactive = 0 }
	local now = 0
	local hooks = {
		spawn = function(point, slot)
			if slot.model and alive[slot.model] then
				res.dupSpawn += 1
			end
			local m = { point = point, hitAt = nil, target = false, claimed = false, dying = false }
			alive[m] = true
			res.spawned += 1
			return m
		end,
		alive = function(m)
			return alive[m] == true
		end,
		engaged = function(m, t)
			return m.target or (m.hitAt ~= nil and t - m.hitAt < CFG.combatHoldSeconds)
		end,
		claim = function(m)
			if m.claimed then
				return false
			end
			m.claimed = true
			return true
		end,
		remove = function(m)
			if m.target or (m.hitAt and now - m.hitAt < CFG.combatHoldSeconds) then
				res.clearedEngaged += 1
			end
			if m.dying then
				res.clearedDying += 1
			end
			alive[m] = nil
			res.cleared += 1
		end,
	}
	-- 처치(보상 경로): claim → (보상 처리 · yield) → 사라짐 → 지점이 켜져 있으면 그 슬롯에 되살림
	local pendingDeaths = {}
	local function kill(m, slot)
		if not hooks.claim(m) then
			return
		end
		m.dying = true
		-- 보상 처리(ImmediateSave 등 yield) 시간: 대개 1.5초 · 30%는 정리 시점을 넘길 만큼 길게(처치 중 정리 경합)
		table.insert(pendingDeaths, { m = m, slot = slot, at = now + (rng:NextNumber() < 0.3 and CFG.idleSeconds + 5 or 1.5) })
	end
	local function settleDeaths()
		for i = #pendingDeaths, 1, -1 do
			local d = pendingDeaths[i]
			if now >= d.at then
				table.remove(pendingDeaths, i)
				if alive[d.m] then
					alive[d.m] = nil -- 보상 지급 뒤 사라짐(보상은 이 경로만 준다 - 사라지기 전에 치워졌으면 누락)
				else
					res.rewardLost += 1
				end
				if d.m.point.active then
					if d.slot.model == d.m then
						d.slot.model = hooks.spawn(d.m.point, d.slot)
					end
				elseif d.slot.model == d.m then
					d.slot.model = nil
				end
			end
		end
	end
	local function step(foci)
		now += CFG.checkSeconds
		settleDeaths()
		local report = SpawnSites.tick(list, foci, now, hooks)
		res.held += report.held
		res.dyingKept += report.dying
	end
	for c = 1, cycles do
		local point = list[rng:NextInteger(1, #list)]
		-- 파티원 둘: 하나는 지점을 지나가고, 가끔 하나는 근처(유지 반경 안)에 남는다
		local walker = point.position + Vector3.new(CFG.activateRadius * 0.5, 0, 0)
		local stayer = rng:NextNumber() < 0.2 and point.position + Vector3.new(0, 0, CFG.keepRadius * 0.9) or nil
		step({ walker, stayer })
		-- 전투: 30% 한 마리를 누가 계속 때린다(떠난 뒤에도 먼 곳에서 - 원거리) · 20% 한 마리 처치 · 10% 어그로 대상 있음
		local fightSlot = point.slots[rng:NextInteger(1, #point.slots)]
		local fight = fightSlot.model
		local mode = rng:NextNumber()
		if fight and mode < 0.3 then
			fight.hitAt = now
		elseif fight and mode < 0.5 then
			kill(fight, fightSlot)
		elseif fight and mode < 0.6 then
			fight.target = true
		end
		-- 떠난다(stayer는 남기도 한다): idleSeconds + 2 동안 멀리
		local t0 = now
		while now - t0 < CFG.idleSeconds + 3 do
			if fight and mode < 0.3 then
				fight.hitAt = now -- 떠난 뒤에도 정리 시점 너머까지 맞는 중(원거리)
			end
			if fight and mode >= 0.5 and mode < 0.6 and now - t0 > CFG.idleSeconds + 1 then
				fight.target = false -- 어그로가 정리 시점 너머까지 붙어 있다 풀림
			end
			step({ stayer })
		end
		-- 모두 떠남(남던 사람도) → 전투 보류가 풀릴 때까지
		local t1 = now
		while now - t1 < CFG.idleSeconds + CFG.combatHoldSeconds + 4 do
			step({})
		end
		res.cycles += 1
		-- 누수: 꺼진 지점에 살아 있는 몬스터 · 켜진 지점이 남음
		for _, p in ipairs(list) do
			for _, s in ipairs(p.slots) do
				if s.model and alive[s.model] and not p.active then
					res.leaks += 1
				end
			end
		end
	end
	local stillAlive, activeLeft = 0, 0
	for _ in pairs(alive) do
		stillAlive += 1
	end
	for _, p in ipairs(list) do
		activeLeft += p.active and 1 or 0
	end
	res.aliveAtEnd, res.activeAtEnd = stillAlive, activeLeft
	return res
end

-- M1-2 후속(스폰 밀도 140 → 110 · 20 → 12초): 사냥꾼 한 명 시뮬(순수 - 실제 SpawnSites.tick + 리스폰 respawnDelay). mode = "stay"(한 지점에 서서 사냥 - 공급 상한) |
--   "walk"(구역 지점을 가까운 순으로 돌며 지점마다 group.count마리를 잡고 다음 지점으로 - 걷기 16). killSeconds = 한 마리 처치 시간 · REACH 안에 들어가야 때린다.
--   반환: 시간당 처치 · 몬스터가 없어 기다린 시간 비율(공급 부족) · 평균 · 최대 동시 몬스터 · 평균 켜진 지점
function M1_2Verify.simulateHunter(mode, killSeconds, hours, zoneIndex)
	local SpawnSites = require(script.Parent.SpawnSites)
	local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
	local respawn = WorldConfig.zoneMonsterGrid.respawnDelaySeconds
	local zoneKey = WorldMapData.zones[zoneIndex or 1].key
	local list = {}
	for _, p in ipairs(SpawnSites.buildPoints()) do
		if p.zoneKey == zoneKey then
			table.insert(list, p)
		end
	end
	-- 걷는 순서 = 가까운 이웃 순회(첫 지점부터)
	local route, used = { list[1] }, { [list[1]] = true }
	while #route < #list do
		local last, best, bestD = route[#route], nil, math.huge
		for _, p in ipairs(list) do
			if not used[p] then
				local d = flat(p.position, last.position)
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		used[best] = true
		table.insert(route, best)
	end
	local alive, pendingRespawn = {}, {}
	local now = 0
	local hooks = {
		spawn = function(point, slot)
			local m = { point = point, slot = slot, pos = slot.position }
			alive[m] = true
			return m
		end,
		alive = function(m) return alive[m] == true end,
		engaged = function(m) return m.target == true end,
		claim = function() return true end,
		remove = function(m) alive[m] = nil end,
	}
	local SPEED, REACH, DT = 16, 10, 0.25
	local pos = route[1].position
	local stepIndex, target, hitLeft, pointKills, waited = 1, nil, 0, 0, 0
	local kills, aliveSum, aliveMax, activeSum, ticks, nextTick = 0, 0, 0, 0, 0, 0
	local total = hours * 3600
	local steps = 0
	while now < total do
		now += DT
		steps += 1
		if steps % 600 == 0 then
			task.wait() -- M1-4: 지점 80곳 · 긴 시뮬이 스크립트 시간 한도를 넘지 않게
		end
		if now >= nextTick then
			nextTick = now + WorldMapData.spawnSites.checkSeconds
			SpawnSites.tick(list, { pos }, now, hooks)
			-- 리스폰(MonsterSpawner.respawnHook과 같은 규칙 - 지점이 켜져 있을 때만 그 슬롯에)
			for i = #pendingRespawn, 1, -1 do
				local e = pendingRespawn[i]
				if now >= e.at then
					table.remove(pendingRespawn, i)
					if e.point.active and not (e.slot.model and alive[e.slot.model]) then
						e.slot.model = hooks.spawn(e.point, e.slot)
					end
				end
			end
			local n, a = 0, 0
			for _ in pairs(alive) do
				n += 1
			end
			for _, p in ipairs(list) do
				a += p.active and 1 or 0
			end
			aliveSum += n
			aliveMax = math.max(aliveMax, n)
			activeSum += a
			ticks += 1
		end
		if target and not alive[target] then
			target = nil
		end
		if not target then
			-- 지금 지점의 살아 있는 몬스터(걷기 = 이 지점만 · 서 있기 = 어디든 가장 가까운)
			local here = route[stepIndex]
			local best, bestD = nil, 60
			for m in pairs(alive) do
				if mode == "stay" or (m.point == here and pointKills < (here.size or 3)) then -- M1-4: 무리 크기(3 ~ 5)
					local d = flat(m.pos, pos)
					if d < bestD then
						best, bestD = m, d
					end
				end
			end
			if best then
				target, hitLeft = best, killSeconds
				best.target = true
			elseif mode == "walk" and here.active and pointKills >= (here.size or 3) then
				stepIndex, pointKills = stepIndex % #route + 1, 0 -- 이 지점 다 잡았다 → 다음 지점
			elseif mode == "stay" then
				waited += DT -- 서 있는데 잡을 몬스터가 없다(공급 부족)
			end
		end
		local goal = target and target.pos or route[stepIndex].position
		local d = flat(goal, pos)
		if d > (target and REACH or 1) then
			local dir = Vector3.new(goal.X - pos.X, 0, goal.Z - pos.Z).Unit
			pos += dir * math.min(d, SPEED * DT)
		elseif target then
			hitLeft -= DT
			if hitLeft <= 0 then
				alive[target] = nil
				kills += 1
				pointKills += 1
				table.insert(pendingRespawn, { point = target.point, slot = target.slot, at = now + respawn })
				target = nil
			end
		end
	end
	return { killsPerHour = kills / hours, waitFraction = waited / total, aliveAvg = aliveSum / math.max(ticks, 1), aliveMax = aliveMax, activeAvg = activeSum / math.max(ticks, 1) }
end

-- ─────────────────────────── (가) ───────────────────────────
function M1_2Verify.runPure()
	print("===M1-2 검증 시작(가)===")
	local r = newRecorder("가")
	local D = WorldMapData
	r.section("M1 결정", function()
		local sand = BossData.bosses.scorpion_queen.skills.sandSearch.decoyBlast
		local orgel = BossData.bosses.crystal_queen.skills.orgel.wrongShock
		r.check(("C안 공동 책임(오답 · 인원별 최대 체력): 전갈 %s · 수정 %s · 솔로 0"):format(table.concat(sand.partyShareMaxHpByParty, "/"), table.concat(orgel.partyShareMaxHpByParty, "/")),
			sand.partyShareMaxHpByParty[1] == 0 and orgel.partyShareMaxHpByParty[1] == 0 and sand.partyShareMaxHpByParty[2] > 0 and orgel.partyShareMaxHpByParty[4] > 0)
		local Sim = require(ReplicatedStorage.Shared.BossDifficultySim)
		local cells, ok = {}, true
		for _, id in ipairs({ "crystal_queen", "scorpion_queen" }) do
			for _, n in ipairs({ 2, 4 }) do
				local res = Sim.monteCarlo(id, { partySize = n, role = "ranged", familiar = true, stage = 500 }, 200)
				table.insert(cells, ("%s %d인 %.0f%%"):format(id, n, res.wipeRate * 100))
				ok = ok and res.wipeRate >= 0.25 and res.wipeRate <= 0.55 -- 200판 표본 흔들림 ±5(로컬 500판 = 31 · 39 · 35 · 44%)
				task.wait()
			end
		end
		r.check(("모형 스테이지 500 파티 전멸(200판 · 목표 30 ~ 50%%): %s"):format(table.concat(cells, " · ")), ok)
		local levels = {}
		for _, s in ipairs(D.hub.tree.course.stations) do
			table.insert(levels, s.unlockLevel)
		end
		r.check(("나무 정거장 기준(역대 최고 레벨) = %s(확정 10 · 30 · 60 · 120 · 250)"):format(table.concat(levels, " · ")), table.concat(levels, ",") == "10,30,60,120,250")
		r.check(("스트리밍 켜짐 = %s(반경 · 무결성 · 내보내기 값은 스크립트로 못 읽는다 - docs/perf/streaming-settings.md)"):format(tostring(workspace.StreamingEnabled)), workspace.StreamingEnabled == true)
	end)
	r.section("스폰 지점 배치", function()
		local S = D.spawnSites
		local rows, ok = {}, true
		for _, z in ipairs(D.zones) do
			local range = WorldMapLayout.huntRange(z)
			local pts = WorldMapLayout.huntPoints(z)
			local minGap, outside, hitsBlock = math.huge, 0, 0
			for i, p in ipairs(pts) do
				for j = i + 1, #pts do
					minGap = math.min(minGap, flat(p.position, pts[j].position))
				end
				for _, s in ipairs(p.slots) do
					if flat(s, range.center) > range.radius - S.edgeMargin + 0.01 then
						outside += 1
					end
				end
				if flat(p.position, WorldMapLayout.camp(z)) < S.avoid.camp or flat(p.position, WorldMapLayout.gate(z)) < S.avoid.gate then
					hitsBlock += 1
				end
			end
			local regionC = WorldMapLayout.regionCenter(z)
			local inRegion = flat(range.center, regionC) + range.radius <= D.layout.regionRadius
			local campOut = flat(WorldMapLayout.camp(z), range.center) > range.radius and flat(WorldMapLayout.gate(z), range.center) > range.radius
			table.insert(rows, ("%s %d곳 간격≥%.0f"):format(z.key, #pts, minGap))
			ok = ok and #pts == S.pointsPerRange and minGap >= S.pointSpacing and outside == 0 and hitsBlock == 0 and inRegion and campOut and #z.hunt.monsters >= 1
		end
		r.check(("구역마다 스폰 지점(범위 반경 %d · 한곳에 몰리지 않게 최소 간격 %d · 캠프 · 관문 · 지형 · 둥지 회피 · 범위가 구역 원 안 · 캠프 · 관문은 범위 밖): %s"):format(S.huntRange.radius, S.pointSpacing, table.concat(rows, " · ")), ok)
		local SpawnSites = require(script.Parent.SpawnSites)
		local picked = SpawnSites.pickMonster({ { tier = 1, weight = 1 }, { tier = 2, weight = 3 } }, 0.5)
		local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
		r.check(("몬스터 목록 가중치(M2 대비 - 종 2개 · 가중 1 : 3 · 굴림 0.5 → %s = tier2)"):format(picked and picked.displayName or "?"), picked == MonsterData[MonsterData.tierOrder[2]])
	end)
	r.section("스폰 사이클 1,000회", function()
		local t0 = os.clock()
		local res = M1_2Verify.simulateCycles(1000, 7)
		r.check(("지나감 → 생성 → 떠남 → 정리 %d회(%.1f초): 생성 %d · 정리 %d · 전투라 미룸 %d · 처치 중이라 남김 %d / 중복 생성 %d · 전투 중 정리 %d · 처치 중 정리 %d · 보상 누락 %d · 누수(꺼진 지점의 몬스터) %d · 끝에 남은 몬스터 %d · 켜진 지점 %d"):format(
			res.cycles, os.clock() - t0, res.spawned, res.cleared, res.held, res.dyingKept, res.dupSpawn, res.clearedEngaged, res.clearedDying, res.rewardLost, res.leaks, res.aliveAtEnd, res.activeAtEnd),
			res.cycles == 1000 and res.dupSpawn == 0 and res.clearedEngaged == 0 and res.clearedDying == 0 and res.rewardLost == 0 and res.leaks == 0 and res.aliveAtEnd == 0 and res.activeAtEnd == 0 and res.held > 0 and res.dyingKept > 0)
	end)
	r.section("마을", function()
		local H = D.hub
		local CS = H.tree.crownShape
		-- 가장 아래 잎 층의 바깥 반경(수관 식) ≥ 안전 반경
		local lowest = CS.shoulderY
		while lowest - CS.coneTiers.spacing > CS.baseY do
			lowest -= CS.coneTiers.spacing
		end
		local bottom = lowest - CS.coneTiers.skirt
		local canopy = CS.baseRadius + (CS.shoulderRadius - CS.baseRadius) * (bottom - CS.baseY) / (CS.shoulderY - CS.baseY)
		r.check(("안전 지대 반경 %d(300 → 400) · 잎 덮개(가장 아래 층 끝) %.0f ≥ 안전 반경"):format(H.safeRadius, canopy), H.safeRadius == 400 and canopy >= H.safeRadius)
		-- 시설 도형이 서로 · 뿌리 · 포탈 광장 · 리스폰 · 리프트와 겹치지 않고 안전 반경 안
		local prims = WorldMapLayout.buildAll()
		local boxes = {}
		for _, p in ipairs(prims) do
			if p.model == "Hub" and (p.name:match("^Facility_") or p.name:match("^Spot_")) then
				table.insert(boxes, p)
			end
		end
		local function corners(p)
			local list = {}
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					table.insert(list, (p.cf * CFrame.new(sx * p.size.X / 2, 0, sz * p.size.Z / 2)).Position)
				end
			end
			return list
		end
		local overlap, outside, nearThings = 0, 0, 0
		local keep = {
			{ p = WorldMapLayout.spawnPoint(), r = 20 },
			{ p = WorldMapLayout.hubPoint(H.tree.course.lift.angleDeg, H.tree.course.lift.r), r = 12 },
			{ p = WorldMapLayout.facility("portal"), r = H.facilities.portal.radius + 4 },
			{ p = Vector3.zero, r = H.tree.trunkRadius + H.tree.roots.reach + 8 },
		}
		for i, a in ipairs(boxes) do
			for _, c in ipairs(corners(a)) do
				if Vector3.new(c.X, 0, c.Z).Magnitude > H.safeRadius then
					outside += 1
				end
				for _, k in ipairs(keep) do
					if flat(c, k.p) < k.r then
						nearThings += 1
					end
				end
			end
			for j = i + 1, #boxes do
				local b = boxes[j]
				local rel = a.cf:PointToObjectSpace(b.cf.Position)
				local rb = math.max(b.size.X, b.size.Z) / 2
				if math.abs(rel.X) < a.size.X / 2 + rb - 1 and math.abs(rel.Z) < a.size.Z / 2 + rb - 1 and flat(a.cf.Position, b.cf.Position) < math.max(a.size.X, a.size.Z) / 2 + rb - 1 then
					overlap += 1
				end
			end
		end
		r.check(("거리 배치(건물 · 자리 %d개): 서로 겹침 %d · 안전 반경 밖 모서리 %d · 리스폰 · 리프트 · 포탈 광장 · 뿌리 침범 %d"):format(#boxes, overlap, outside, nearThings), #boxes >= 16 and overlap == 0 and outside == 0 and nearThings == 0)
		local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
		local okPos = flat(WorldConfig.enhance.stationOffset, WorldMapLayout.facility("forge")) < 0.01 and flat(WorldConfig.zones.community.center, WorldMapLayout.facility("community")) < 0.01
		r.check("기능 자리 = 거리 가운데(강화대 = 대장간 거리 · 제단 = 커뮤니티 광장 · 보석상인 = 시장)", okPos)
		local T = D.travel
		r.check(("귀환: 시전 %d초 · 쿨 %d초(도착 뒤) · 돌아가기 %d초 안 1회 · 단축키 H(F · Q · E · R · T · Shift · Ctrl · Space와 안 겹침)"):format(T.recall.castSeconds, T.hubReturnCooldownSeconds, T.recall.backSeconds),
			T.recall.castSeconds == 3 and T.recall.backSeconds == 300)
	end)
	r.section("나무", function()
		local tree = D.hub.tree
		local worst, tipBelow = 0, true
		for _, a in ipairs(tree.roots.angles) do
			local segs = WorldMapLayout.rootSegments(a, 0)
			for i, seg in ipairs(segs) do
				local _, h0 = WorldMapLayout.rootAt(seg.t0)
				local r0 = WorldMapLayout.rootAt(seg.t0)
				local r1, h1 = WorldMapLayout.rootAt(seg.t1)
				if i == #segs then
					h1 = -tree.roots.sink
				end
				worst = math.max(worst, math.deg(math.atan2(h0 - h1, r1 - r0)))
				if i == #segs then
					local tip = (seg.cf * CFrame.new(0, seg.size.Y / 2, -seg.size.Z / 2)).Position
					tipBelow = tipBelow and tip.Y < D.floorTopY
				end
			end
		end
		r.check(("뿌리 %d개: 가장 가파른 조각 %.0f°(≤ 45 - 걸어 오른다) · 끝이 땅속 %s · 충돌 있음(밟는다)"):format(#tree.roots.angles, worst, tostring(tipBelow)), worst <= 45 and tipBelow)
		local moves = WorldMapLayout.courseRootMoves()
		local rows, allAir = {}, true
		for _, m in ipairs(moves) do
			local skill, name = WorldMapLayout.moveSkill(m.rise, m.gap)
			table.insert(rows, ("%s → %s(오름 %.1f · 간격 %.1f = %s)"):format(m.from, m.to, m.rise, m.gap, tostring(name)))
			allAir = allAir and skill ~= nil and skill ~= "easy"
		end
		r.check(("코스 뿌리(밟고 높은 곳에서 시작 · 폭 %.1f 혹 · 공중 점프 필요): %s"):format(tree.courseRoot.knobWidth, table.concat(rows, " · ")), allAir and tree.courseRoot.knobWidth <= 2.5)
		local T = WorldMapLayout.tree()
		local bad = 0
		for _, a in ipairs(tree.roots.angles) do
			for i = 0, 20 do
				local rr, h = WorldMapLayout.rootAt(i / 20)
				local p = WorldMapLayout.hubPoint(a, rr)
				for _, el in ipairs(T.elements) do
					if el.leg == 1 and el.index >= 3 and WorldMapLayout.moveSkill(el.top - h, flat(el.center, p) - 3) and flat(el.center, p) > 3 then
						bad += 1
					end
				end
			end
		end
		r.check(("일반 뿌리 위 → 코스 중간(1구간 3번째 요소부터) 지름길 %d(기대 0)"):format(bad), bad == 0)
		local lowTop = math.huge
		for _, t in ipairs(tree.crownShape.topTiers) do
			lowTop = math.min(lowTop, t.bottom)
		end
		r.check(("윗잎 층 %d장 · 가장 낮은 아래 가장자리 %d ≥ 785(전망대 760 눈높이 위)"):format(#tree.crownShape.topTiers, lowTop), lowTop >= 785)
	end)
	r.section("스폰 밀도(M1-2 후속)", function()
		local S = D.spawnSites
		local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
		r.check(("스폰 밀도 = 활성 반경 %d · 유지 %d초(사용자 확정 110 · 12)"):format(S.activateRadius, S.idleSeconds), S.activateRadius == 110 and S.idleSeconds == 12)
		-- EconSim 수요(시간당 처치 = 3600 / (처치 + 이동 여유)) 대 서 있는 사냥꾼 공급 상한 · 걷는 사냥꾼(새 값 대 옛 값)
		local rows, ok = {}, true
		for _, id in ipairs({ "casual", "normal", "top" }) do
			local prof = EconSimConfig.profiles[id]
			local demand = 3600 / (prof.targetKillSeconds + prof.moveOverheadSeconds)
			-- M1-4 무리 스폰(지점 80 · 무리 3 ~ 5): 옛 "140 · 20초 대비" 비교는 M1-2 결정으로 닫혔다 - 공급 · 걷기 처치만 본다(30분 표본)
			local stay = M1_2Verify.simulateHunter("stay", prof.targetKillSeconds, 0.5)
			local walk = M1_2Verify.simulateHunter("walk", prof.targetKillSeconds, 0.5)
			table.insert(rows, ("%s 수요 %.0f/시 · 서서 %.0f(몬스터 없어 기다림 %.1f%%) · 걸어 %.0f · 동시 몬스터 평균 %.1f 최대 %d · 켜진 지점 %.1f"):format(
				prof.displayName, demand, stay.killsPerHour, stay.waitFraction * 100, walk.killsPerHour, walk.aliveAvg, walk.aliveMax, walk.activeAvg))
			ok = ok and stay.waitFraction <= 0.05 and walk.killsPerHour > 0
		end
		r.check("스폰 공급이 처치를 막지 않음(서 있는 사냥꾼 기다림 ≤ 5% - M1-4 무리 3 ~ 5 · 리스폰 5초 · EconSim은 스폰 값을 안 읽는다) · 걷는 사냥꾼 처치: " .. table.concat(rows, " / "), ok)
	end)
	local pass, total = r.summary()
	print(("===M1-2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function M1_2Verify.runLive(player, env)
	print("===M1-2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local SpawnSites = require(script.Parent.SpawnSites)
	local MonsterState = require(script.Parent.MonsterState)
	local Travel = require(script.Parent.Travel)
	local PlayerState = require(script.Parent.PlayerState)
	local HeightGuard = require(script.Parent.HeightGuard)
	local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
	local D = WorldMapData
	local CFG = D.spawnSites
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	assert(root, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	HeightGuard.debugOff = true
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
	end
	put(WorldConfig.zones.spawn.arrival + Vector3.new(0, 5, 0))
	task.wait(0.5)
	r.section("스폰 지점 실제 사이클", function()
		local idle0, hold0, check0 = CFG.idleSeconds, CFG.combatHoldSeconds, CFG.checkSeconds
		CFG.idleSeconds, CFG.combatHoldSeconds = 3, 2 -- 짧게(규칙은 같다 - 1,000회 시뮬은 실제 값으로 (가)가 돈다)
		local ok, err = pcall(function()
			local pts = SpawnSites.points()
			local zone1 = {}
			for _, p in ipairs(pts) do
				if p.zoneKey == "tier1" then
					table.insert(zone1, p)
				end
			end
			local cycles, spawnedOk, clearedOk, dup = 0, 0, 0, 0
			for c = 1, 20 do
				local p = zone1[(c - 1) % #zone1 + 1]
				SpawnSites.debugFoci[1] = p.position
				task.wait(CFG.checkSeconds * 1.6)
				local n = 0
				local seen = {}
				for _, s in ipairs(p.slots) do
					if s.model and s.model.Parent and MonsterState.getData(s.model) then
						n += 1
						if seen[s.model] then
							dup += 1
						end
						seen[s.model] = true
					end
				end
				spawnedOk += (p.active and n == (p.size or -1)) and 1 or 0 -- M1-4: 무리 크기만큼(3 ~ 5)
				table.clear(SpawnSites.debugFoci)
				task.wait(CFG.idleSeconds + CFG.checkSeconds * 2.2)
				local left = 0
				for _, s in ipairs(p.slots) do
					left += (s.model and s.model.Parent) and 1 or 0
				end
				clearedOk += (not p.active and left == 0) and 1 or 0
				cycles += 1
			end
			local leaks, orphans = SpawnSites.audit()
			r.check(("실제 사이클 %d회(정리 %d초로 줄여서): 지나가면 무리(최대 %d마리) 생성 %d/%d · 떠나면 정리 %d/%d · 중복 %d · 누수 %d · 주인 없는 구역 잡몹 %d"):format(cycles, CFG.idleSeconds, CFG.group.maxSize, spawnedOk, cycles, clearedOk, cycles, dup, leaks, orphans),
				spawnedOk == cycles and clearedOk == cycles and dup == 0 and leaks == 0 and orphans == 0)
			-- 전투 중 보류: 켜고 떠난 뒤 한 마리를 계속 때린다 → 정리 안 됨 → 멈추면 정리
			local p = zone1[1]
			SpawnSites.debugFoci[1] = p.position
			task.wait(CFG.checkSeconds * 1.6)
			table.clear(SpawnSites.debugFoci)
			local target = p.slots[1].model
			local held = true
			local t0 = os.clock()
			while os.clock() - t0 < CFG.idleSeconds + 3 do
				if target and MonsterState.getData(target) then
					MonsterState.applyDamage(target, 0.0001, 1, nil)
				end
				task.wait(0.5)
				held = held and p.active and target.Parent ~= nil
			end
			task.wait(CFG.combatHoldSeconds + CFG.checkSeconds * 2.5)
			r.check(("떠난 뒤에도 맞는 중 %.0f초 → 정리 보류 %s · 때리기를 멈추고 %d초 뒤 → 정리 %s"):format(CFG.idleSeconds + 3, tostring(held), CFG.combatHoldSeconds, tostring(not p.active)), held and not p.active)
			-- 처치 판정 중(보상 처리 중) 몬스터: 정리가 건드리지 않는다
			SpawnSites.debugFoci[1] = p.position
			task.wait(CFG.checkSeconds * 1.6)
			table.clear(SpawnSites.debugFoci)
			local dying = p.slots[2].model
			local claimed = dying and MonsterState.tryClaimDeath(dying)
			task.wait(CFG.idleSeconds + CFG.checkSeconds * 2.5)
			local keptDying = dying and dying.Parent ~= nil and MonsterState.getData(dying) ~= nil
			r.check(("처치 판정 중인 몬스터(claim %s): 지점 정리 %s · 그 몬스터는 남음 %s(보상 경로가 치운다 - 누락 0)"):format(tostring(claimed), tostring(not p.active), tostring(keptDying)), claimed and not p.active and keptDying)
			if dying then
				MonsterState.clear(dying)
				dying:Destroy()
			end
		end)
		CFG.idleSeconds, CFG.combatHoldSeconds, CFG.checkSeconds = idle0, hold0, check0
		table.clear(SpawnSites.debugFoci)
		if not ok then
			error(err)
		end
	end)
	r.section("귀환", function()
		local st = Travel.stateOf(player)
		st.hubAt, st.recall, st.back = -math.huge, nil, nil
		local spot = WorldMapLayout.camp(WorldMapLayout.zoneByKey("tier1")) + Vector3.new(0, 4, 0) -- 캠프(안전 - 몬스터 피격이 시전을 끊지 않게 · 허브 밖이라 돌아가기 자리가 생긴다)
		put(spot)
		task.wait(0.5)
		PlayerState.setHp(player, PlayerState.getMaxHp(player))
		local ok1, why1 = Travel.requestHub(player)
		task.wait(1.0)
		PlayerState.setHp(player, PlayerState.getMaxHp(player) * 0.9) -- 맞음
		task.wait(0.6)
		local cancelled = st.recall == nil and player:GetAttribute("RecallCancel") == "hit" and flat(root.Position, spot) < 5
		r.check(("시전 시작 %s(%s) · 1초 뒤 맞음 → 취소 %s(제자리)"):format(tostring(ok1), tostring(why1), tostring(cancelled)), ok1 and why1 == "casting" and cancelled)
		PlayerState.setHp(player, PlayerState.getMaxHp(player))
		local ok2 = Travel.requestHub(player)
		local t0 = os.clock()
		task.wait(D.travel.recall.castSeconds - 0.6)
		local stillThere = flat(root.Position, spot) < 5
		task.wait(1.4)
		local arrived = flat(root.Position, WorldConfig.zones.spawn.arrival) < 12
		local backUntil = player:GetAttribute("RecallBackUntil")
		r.check(("다시 시전 %s → %.1f초엔 제자리 %s → %.1f초 뒤 허브 %s · 돌아가기 %s초 남음"):format(tostring(ok2), D.travel.recall.castSeconds - 0.6, tostring(stillThere), os.clock() - t0, tostring(arrived),
			backUntil and ("%.0f"):format(backUntil - workspace:GetServerTimeNow()) or "없음"), ok2 and stillThere and arrived and backUntil ~= nil)
		local okCd, whyCd = Travel.requestHub(player)
		local okB = Travel.requestBack(player)
		task.wait(0.5)
		local back = flat(root.Position, spot) < 6
		local okB2, whyB2 = Travel.requestBack(player)
		r.check(("도착 뒤 바로 귀환 = %s(%s) · [돌아가기] %s → 귀환한 자리 %s · 두 번째 = %s(%s - 1회)"):format(tostring(okCd), tostring(whyCd), tostring(okB), tostring(back), tostring(okB2), tostring(whyB2)),
			not okCd and whyCd == "cooldown" and okB and back and not okB2 and whyB2 == "no_back")
		st.hubAt = -math.huge
	end)
	r.section("뿌리 밟기", function()
		local rows, okAll = {}, true
		for _, a in ipairs({ D.hub.tree.roots.angles[1], D.hub.tree.roots.angles[4] }) do
			local rr, h = WorldMapLayout.rootAt(0.3)
			local p = WorldMapLayout.hubPoint(a, rr, h + 4)
			put(p)
			task.wait(1.2)
			local feet = root.Position.Y - 3
			local ok = math.abs(feet - (D.floorTopY + h)) < 2.5
			table.insert(rows, ("%d° 뿌리 t 0.3(윗면 %.1f) → 1.2초 뒤 발 %.1f"):format(a, h, feet - D.floorTopY))
			okAll = okAll and ok
		end
		r.check(("뿌리 위에 선다(관통 X): %s"):format(table.concat(rows, " · ")), okAll)
	end)
	put(WorldConfig.zones.spawn.arrival + Vector3.new(0, 5, 0))
	HeightGuard.debugOff = guardOff
	local pass, total = r.summary()
	print(("===M1-2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return M1_2Verify
