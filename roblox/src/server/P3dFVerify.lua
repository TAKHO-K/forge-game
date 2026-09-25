-- P3d-F 자동 검증(docs/phase/P3d-F-log.md). (나) = 보스 검증 체인 끝(실제 보스전 · 실제 판정 경로).
--   (나) A1 재생성 누수: 보스전 A가 재생성을 등록한 직후(자리 찾기 대기 · 전조 중) 끝내고 곧바로 같은 슬롯에 보스전 B를 세우기 5회 -
--        B에 A의 계획 · 전조 · 솟음이 섞이면 X. 등록 · 취소 · 생성 시각을 A 종료 · B 시작과 나란히 찍는다(BossPatterns.debugEventHook).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)

local P3dFVerify = {}

local REGROW = BossArenaMapData.regrow

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[P3dF][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[P3dF][%s] %s"):format(tag, label))
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

local function drive(player, root, model, data, seconds, untilFn)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local startedAt = os.clock()
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		fullHeal(player)
		if not model.Parent then
			break
		end
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, BossEncounter.getMembersOfModel(model))
		if untilFn and untilFn() then
			break
		end
	end
end

function P3dFVerify.runLive(player, env)
	print("===P3dF 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossPatterns = require(script.Parent.BossPatterns)
	local BossEncounter = require(script.Parent.BossEncounter)
	local BossArenaMap = require(script.Parent.BossArenaMap)
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
	local events, sends = {}, {}
	BossPatterns.debugEventHook = function(kind, record)
		table.insert(events, { kind = kind, at = os.clock(), record = record })
	end
	BossPatterns.debugSendHook = function(kind, payload)
		if kind == "regrowTelegraph" or kind == "regrowSpawn" then
			table.insert(sends, { kind = kind, at = os.clock(), id = payload.id })
		end
	end
	local function eventsOf(kind, since)
		local list = {}
		for _, e in ipairs(events) do
			if e.kind == kind and e.at >= (since or 0) then
				table.insert(list, e)
			end
		end
		return list
	end

	r.section("A1 재생성 누수 5회", function()
		local clean = 0
		for cycle = 1, 5 do
			refreshRoot()
			fullHeal(player)
			PlayerState.clearIncomingDamageMultiplier(player)
			-- 홀수 = 등록 직후(자리 찾기가 아직 안 돈 때) 끝냄 · 짝수 = 전조 중(계획 뒤 솟기 전) 끝냄
			local stopAt = cycle % 2 == 1 and "regrowQueue" or "regrowPlan"
			local modelA, dataA, encounterA = spawnBoss(player, env, "section_guardian", 900 + cycle)
			assert(modelA and encounterA, "보스전 A 스폰 실패")
			local zoneA = encounterA.zoneKey
			local tokenA = BossArenaMap.regrowToken(zoneA)
			BossPatterns.setGrace(modelA, dataA, 120)
			root.Anchored = true
			root.CFrame = CFrame.new(WorldConfig.zones[zoneA].center + Vector3.new(0, BossArenaMap.floorTopY() + 3, 60))
			local since = os.clock()
			BossPatterns.force(modelA, dataA, "shockwave")
			local queuedAt, plannedAt = nil, nil
			drive(player, root, modelA, dataA, 14, function()
				for _, e in ipairs(eventsOf("regrowQueue", since)) do
					queuedAt = queuedAt or (e.record.token == tokenA and e.at or nil)
				end
				for _, e in ipairs(eventsOf("regrowPlan", since)) do
					plannedAt = plannedAt or (e.record.token == tokenA and e.at or nil)
				end
				return (stopAt == "regrowQueue" and queuedAt ~= nil) or (stopAt == "regrowPlan" and plannedAt ~= nil)
			end)
			local endAt = os.clock()
			BossEncounter.despawnFor(player) -- 보스전 A 종료
			local modelB, dataB, encounterB = spawnBoss(player, env, "frost_giant", 950 + cycle) -- 곧바로 보스전 B
			local startB = os.clock()
			assert(modelB and encounterB, "보스전 B 스폰 실패")
			local zoneB = encounterB.zoneKey
			local tokenB = BossArenaMap.regrowToken(zoneB)
			BossPatterns.setGrace(modelB, dataB, 120)
			local layoutB = #BossArenaMap.obstacles(zoneB)
			task.wait(REGROW.telegraphSeconds + 1.0) -- A의 전조가 살아 있었다면 이 안에 솟는다
			-- 판정: A 토큰의 계획 · 솟음이 A 종료 뒤에 있으면 누수 · B 시작 뒤 전조 · 솟음 전송 0 · B 구조물에 재생성분 0 · 개수 그대로
			local leakPlan, leakSpawn, cancel = 0, 0, nil
			for _, e in ipairs(eventsOf("regrowPlan", endAt)) do
				leakPlan += e.record.token == tokenA and 1 or 0
			end
			for _, e in ipairs(eventsOf("regrowSpawn", endAt)) do
				leakSpawn += e.record.token == tokenA and 1 or 0
			end
			for _, e in ipairs(eventsOf("regrowSkip", since)) do
				if e.record.token == tokenA and not cancel then
					cancel = e
				end
			end
			local sentB = 0
			for _, s in ipairs(sends) do
				sentB += s.at >= startB and 1 or 0
			end
			local regrownB = 0
			for _, o in ipairs(BossArenaMap.obstacles(zoneB)) do
				local full = BossArenaMap.debugObstacle(zoneB, o.id)
				regrownB += full and full.regrown and 1 or 0
			end
			local countB = #BossArenaMap.obstacles(zoneB)
			local function rel(t)
				return t and ("%+.3f"):format(t - since) or "-"
			end
			r.note(("A1 #%d 시각(A 진동파 시작 기준 초): 등록 %s · 계획 %s · A 종료 %s · B 시작 %s · 취소 %s(%s%s) · 생성(A 토큰) %d · 슬롯 %s → %s · 토큰 %s → %s"):format(
				cycle, rel(queuedAt), rel(plannedAt), rel(endAt), rel(startB), rel(cancel and cancel.at), tostring(cancel and cancel.record.reason), cancel and cancel.record.atSpawn and " · 솟기 직전" or "",
				leakSpawn, tostring(zoneA), tostring(zoneB), tostring(tokenA), tostring(tokenB)))
			local ok = (queuedAt ~= nil) and (stopAt == "regrowQueue" or plannedAt ~= nil) and leakPlan == 0 and leakSpawn == 0 and cancel ~= nil and sentB == 0 and regrownB == 0 and countB == layoutB
			r.check(("A1 #%d(%s 끝냄): A 종료 뒤 A 계획 %d · A 솟음 %d · 취소 기록 %s · B 시작 뒤 재생성 전송 %d · B 재생성 구조물 %d · B 구조물 %d → %d(기대 전부 0 · 취소 있음 · 개수 그대로)"):format(
				cycle, stopAt == "regrowQueue" and "등록 직후" or "전조 중", leakPlan, leakSpawn, tostring(cancel ~= nil), sentB, regrownB, layoutB, countB), ok)
			clean += ok and 1 or 0
			root.Anchored = false
			BossEncounter.despawnFor(player)
		end
		r.note(("A1 합계 %d/5 깨끗함"):format(clean))
	end)

	local PlayerDamage = require(script.Parent.PlayerDamage)
	local BossTrap = require(script.Parent.BossTrap)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local FLOOR = BossArenaMap.floorTopY()
	local function hit()
		local h = PlayerDamage.applyHit(player, 1, "P3dF 확인", 1)
		fullHeal(player)
		return h
	end
	-- 재생성 구조물 하나를 세운다(끼임 확인용)
	local function regrowOne(zoneKey, model)
		local plan = BossArenaMap.planRegrow(zoneKey, { members = {}, boss = model.PrimaryPart.Position, pits = {} })
		return plan and BossArenaMap.spawnRegrown(zoneKey, plan), plan
	end

	r.section("B6 받는 피해 배율 출처별 · 복귀 보호 + 회전베기", function()
		refreshRoot()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 811)
		local zone = WorldConfig.zones[encounter.zoneKey]
		BossPatterns.setGrace(model, data, 60)
		PlayerState.clearIncomingDamageMultiplier(player)
		local base = hit()
		local whirlKey = "skill:greatsword:E"
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 3, whirlKey) -- 회전베기와 같은 호출(SkillServer castCircleChannel - 출처 키 모양 그대로)
		local whirl = hit()
		-- 맵 밖 → 복귀 보호(무적 플래그)
		local BossArenaContainment = require(script.Parent.BossArenaContainment)
		root.Anchored = false
		root.CFrame = CFrame.new(zone.center + Vector3.new(zone.radius + 12, FLOOR + 3, 0))
		local waited = 0
		while not BossArenaContainment.isProtected(player) and waited < 2 do
			waited += task.wait(0.05)
		end
		local during, multDuring = hit(), PlayerState.getIncomingDamageMultiplier(player)
		task.wait(BossArenaMapData.containment.returnProtectSeconds + 0.1)
		local after, multAfter = hit(), PlayerState.getIncomingDamageMultiplier(player)
		PlayerState.setIncomingDamageMultiplierUntil(player, 0.5, 0.3, "dash")
		local multDash = PlayerState.getIncomingDamageMultiplier(player)
		task.wait(0.35)
		local multDashGone = PlayerState.getIncomingDamageMultiplier(player)
		PlayerState.clearIncomingDamageMultiplierSource(player, whirlKey)
		local multEnd = PlayerState.getIncomingDamageMultiplier(player)
		r.check(("B6 기준 피격 %.4f · 회전베기 %.4f(×%.2f) · 복귀 보호 중 ×%.2f 피격 %.4f · 보호 %.2f초 끝 뒤 ×%.2f 피격 %.4f(회전베기 남음 - 옛 칸은 1) · +대시 ×%.2f · 대시 만료 ×%.2f · 회전베기 자기 키 해제 ×%.2f"):format(
			base, whirl, whirl / math.max(base, 1e-9), multDuring, during, BossArenaMapData.containment.returnProtectSeconds, multAfter, after, multDash, multDashGone, multEnd),
			base > 0 and math.abs(whirl / base - 0.5) < 0.02 and multDuring == 0 and during == 0 and math.abs(multAfter - 0.5) < 1e-9 and math.abs(after / base - 0.5) < 0.02
				and math.abs(multDash - 0.25) < 1e-9 and math.abs(multDashGone - 0.5) < 1e-9 and multEnd == 1)
		BossEncounter.despawnFor(player)
	end)

	r.section("B5 끼임 = 무적 아님 · 공유 칸 A 고정(잡힘 × 끼임)", function()
		refreshRoot()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 812)
		local zoneKey = encounter.zoneKey
		BossPatterns.setGrace(model, data, 60)
		PlayerState.clearIncomingDamageMultiplier(player)
		-- ① 끼인 동안 피격이 들어간다(옛: 0배)
		local o1 = regrowOne(zoneKey, model)
		assert(o1, "재생성 실패 1")
		BossArenaMap.encase(zoneKey, o1, player, root)
		local encasedHit = hit()
		-- ② 끼인 채 잡힘 → 끼임 부서짐: 잡힘 고정은 남는다
		BossTrap.trap(player, { kind = "frozen", rescueType = "hitCount", autoReleaseSeconds = 30 })
		BossArenaMap.breakObstacle(zoneKey, o1.id, "escape")
		local anchoredAfterBreak, trappedAfterBreak = root.Anchored, BossTrap.isTrapped(player)
		BossTrap.release(player, "reset")
		local anchoredAfterTrap = root.Anchored
		-- ③ 잡힌 채 끼임 → 잡힘 풀림: 끼임 고정은 남는다 → 끼임 부서짐: 풀림
		local o2 = regrowOne(zoneKey, model)
		assert(o2, "재생성 실패 2")
		BossTrap.trap(player, { kind = "frozen", rescueType = "hitCount", autoReleaseSeconds = 30 })
		BossArenaMap.encase(zoneKey, o2, player, root)
		BossTrap.release(player, "reset")
		local anchoredEncaseOnly = root.Anchored
		BossArenaMap.breakObstacle(zoneKey, o2.id, "escape")
		local anchoredNone = root.Anchored
		r.check(("B5 끼인 동안 피격 %.4f(> 0 - 무적 아님) · A 끼임+잡힘 → 끼임 부서짐: 고정 %s · 잡힘 %s → 잡힘 풀림: 고정 %s / 잡힘+끼임 → 잡힘 풀림: 고정 %s → 끼임 부서짐: 고정 %s(기대 true · true · false / true · false)"):format(
			encasedHit, tostring(anchoredAfterBreak), tostring(trappedAfterBreak), tostring(anchoredAfterTrap), tostring(anchoredEncaseOnly), tostring(anchoredNone)),
			encasedHit > 0 and anchoredAfterBreak and trappedAfterBreak and not anchoredAfterTrap and anchoredEncaseOnly and not anchoredNone)
		PlayerState.clearIncomingDamageMultiplier(player)
		BossEncounter.despawnFor(player)
	end)

	r.section("공유 칸 B 이동속도 · D 체력바 눈금", function()
		refreshRoot()
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
		PlayerProfile.refreshMovementSpeed(player)
		local w0 = humanoid.WalkSpeed
		local key = "skill:greatsword:E"
		PlayerState.setMoveSpeedMultiplier(player, key, 0.5)
		PlayerProfile.refreshMovementSpeed(player)
		local w1 = humanoid.WalkSpeed
		PlayerProfile.refreshMovementSpeed(player) -- 채널링 중 장비 · 보석 교체(같은 함수가 다시 계산한다)
		local w2 = humanoid.WalkSpeed
		PlayerState.setMoveSpeedMultiplier(player, key, nil)
		PlayerProfile.refreshMovementSpeed(player)
		local w3 = humanoid.WalkSpeed
		local a, b = Instance.new("Part"), Instance.new("Part")
		a.Parent, b.Parent = workspace, workspace
		PlayerState.setTickDamageSource(player, a, 10)
		PlayerState.setTickDamageSource(player, b, 5)
		local t1 = player:GetAttribute("TickDamage")
		PlayerState.setTickDamageSource(player, a, nil)
		local t2 = player:GetAttribute("TickDamage")
		PlayerState.setTickDamageSource(player, b, nil)
		local t3 = player:GetAttribute("TickDamage")
		a:Destroy()
		b:Destroy()
		r.check(("B 이동속도 %.2f → 감속 %.2f → 장비 교체 재계산 %.2f → 해제 %.2f(기대 ×0.5 유지 · 원래로) · D 눈금 두 몹 %s → 앞 몹 해제 %s → 전부 해제 %s(기대 10 · 5 · 0)"):format(w0, w1, w2, w3, tostring(t1), tostring(t2), tostring(t3)),
			math.abs(w1 - w0 * 0.5) < 1e-6 and math.abs(w2 - w0 * 0.5) < 1e-6 and math.abs(w3 - w0) < 1e-6 and t1 == 10 and t2 == 5 and t3 == 0)
	end)

	r.section("B3 단상 금 표시 · 붕괴 예고", function()
		refreshRoot()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 802) -- P3d(나) C와 같은 시드(단상 있음)
		local zoneKey = encounter.zoneKey
		BossPatterns.setGrace(model, data, 60)
		local dais = nil
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			if o.climbable and not dais then
				dais = o
			end
		end
		assert(dais, "단상이 없다")
		local c = dais.colliders[1]
		local colorsBefore = {}
		for _, part in ipairs(dais.model:GetDescendants()) do
			if part:IsA("BasePart") and part.Transparency < 1 then
				colorsBefore[part] = part.Color
			end
		end
		root.Anchored = true
		root.CFrame = CFrame.new(Vector3.new(c.center.X, FLOOR + c.h + 3, c.center.Z))
		local since = os.clock()
		BossPatterns.force(model, data, "shockwave")
		local st = MonsterState.getBossPatternState(model)
		local crackParts, tinted = 0, 0
		drive(player, root, model, data, 12, function()
			if crackParts == 0 and BossArenaMap.debugObstacle(zoneKey, dais.id) and BossArenaMap.debugObstacle(zoneKey, dais.id).cracked then
				for _, part in ipairs(dais.model:GetDescendants()) do
					if part:IsA("BasePart") then
						crackParts += part.Name == "ObstacleCrack" and 1 or 0
						tinted += colorsBefore[part] and part.Color ~= colorsBefore[part] and 1 or 0
					end
				end
			end
			return os.clock() - since > 1 and st.phase == "normal"
		end)
		local warnAt, breakAt, lead = nil, nil, nil
		for _, e in ipairs(eventsOf("daisWarn", since)) do
			if e.record.id == dais.id then
				warnAt, lead = e.at, e.record.lead
			end
		end
		for _, e in ipairs(eventsOf("daisWave", since)) do
			if e.record.id == dais.id and e.record.result == "break" then
				breakAt = e.at
			end
		end
		local look = BossArenaMapData.obstacle.daisCrackLook
		local gap = warnAt and breakAt and breakAt - warnAt or -1
		r.check(("B3 금 파트 %d(기대 ≥ %d · 폭 %.1f) · 색 바뀐 파트 %d(> 0 - 위험색 %.0f%%) · 붕괴 예고 → 무너짐 %.2f초(예고 계산 %.2f · 기대 %.1f ± 0.1)"):format(
			crackParts, look.lines * 2, look.widthStuds, tinted, look.tintFraction * 100, gap, lead or -1, BossArenaMapData.obstacle.daisWave.collapseWarnSeconds),
			crackParts >= look.lines * 2 and tinted > 0 and lead ~= nil and lead >= BossArenaMapData.obstacle.daisWave.collapseWarnSeconds - 0.05 and math.abs(gap - lead) <= 0.1)
		root.Anchored = false
		BossEncounter.despawnFor(player)
	end)

	r.section("B4 상한 = 가장 오래된 재생성분 교체", function()
		refreshRoot()
		local model, data, encounter = spawnBoss(player, env, "section_guardian", 813)
		local zoneKey = encounter.zoneKey
		BossPatterns.setGrace(model, data, 60)
		local firstRegrown = nil
		for _ = 1, 20 do
			if #BossArenaMap.obstacles(zoneKey) >= REGROW.maxObstacles then
				break
			end
			local o = regrowOne(zoneKey, model)
			firstRegrown = firstRegrown or (o and o.id)
		end
		local atCap = #BossArenaMap.obstacles(zoneKey)
		local o, plan = regrowOne(zoneKey, model)
		local last = BossArenaMap.lastBreak(zoneKey)
		r.check(("B4 상한 %d개에서 하나 더: 교체된 #%s(가장 오래된 재생성분 #%s) · 붕괴 cause %s · 새로 솟음 %s · 개수 %d → %d"):format(atCap, tostring(plan and plan.replaced), tostring(firstRegrown),
			tostring(last and last.cause), tostring(o ~= nil), atCap, #BossArenaMap.obstacles(zoneKey)),
			atCap == REGROW.maxObstacles and plan ~= nil and plan.replaced == firstRegrown and last and last.cause == "cap" and o ~= nil and #BossArenaMap.obstacles(zoneKey) == REGROW.maxObstacles)
		BossEncounter.despawnFor(player)
	end)

	BossPatterns.debugEventHook = nil
	BossPatterns.debugSendHook = nil
	if root then
		root.Anchored = false
	end
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
	print(("===P3dF 검증 끝(나)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ═══ (가E) 무거운 계산 - 체인 끝 ═══
-- B4: 100시드 × 6맵, 시드마다 재생성 EVENTS번(상한을 넘기게) - 상한이면 가장 오래된 재생성분을 빼고 새로 뽑는다(서버 planRegrow와 같은 규칙).
-- 잰다: 겹침 0 · 닫힌 공간 0 · 이동 가능 면적 최소(≥ minWalkableFraction) · 교체 수 · 자리 찾기 1회 평균 · 최대 ms.
local EVENTS = 16

function P3dFVerify.runRegrowSeeds()
	print("===P3dF 검증 시작(가E)===")
	local r = newRecorder("가E")
	local ArenaLayout = require(ReplicatedStorage.Shared.ArenaLayout)
	local GEOMETRY = BossArenaMapData.geometry
	r.section("B4 재생성 교체 100시드 × 6맵", function()
		local startedAt = os.clock()
		local state = REGROW.check.seedBase + 7
		local function rng()
			state = (state * 1103515245 + 12345) % 2147483648
			return state / 2147483648
		end
		local total = { events = 0, spawned = 0, replaced = 0, overlap = 0, closed = 0, minWalk = 1, spotMs = 0, spotMax = 0, spots = 0, over = 0 }
		for _, bossId in ipairs({ "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }) do
			local boss = BossData.bosses[bossId]
			local theme = BossArenaMapData.maps[bossId]
			local opts = ArenaLayout.optionsFor(boss)
			local per = { spawned = 0, replaced = 0, overlap = 0, closed = 0, minWalk = 1 }
			for s = 1, REGROW.check.seeds do
				local layout = ArenaLayout.generate(theme, REGROW.check.seedBase + s, opts)
				local items = table.clone(layout.items)
				local regrown = {} -- 오래된 순
				local nextId = 1000
				for _ = 1, EVENTS do
					total.events += 1
					if #items >= REGROW.maxObstacles and #regrown > 0 then
						local oldest = table.remove(regrown, 1)
						table.remove(items, table.find(items, oldest))
						per.replaced += 1
					end
					local members = {}
					for _ = 1, 1 + math.floor(rng() * 4) do
						local a, d = rng() * 2 * math.pi, math.sqrt(rng()) * (GEOMETRY.radiusStuds - 2)
						table.insert(members, { x = math.cos(a) * d, z = math.sin(a) * d })
					end
					local ba, bd = rng() * 2 * math.pi, math.sqrt(rng()) * 120
					nextId += 1
					local t0 = os.clock()
					local item = ArenaLayout.regrowSpot(theme, items, rng, { kit = opts.kit, coverageMin = 0, members = members, boss = { x = math.cos(ba) * bd, z = math.sin(ba) * bd }, pits = {}, mounds = layout.mounds }, nextId)
					local ms = (os.clock() - t0) * 1000
					total.spotMs += ms
					total.spotMax = math.max(total.spotMax, ms)
					total.spots += 1
					if item then
						per.spawned += 1
						local bad = false
						for _, other in ipairs(items) do
							bad = bad or math.sqrt((item.x - other.x) ^ 2 + (item.z - other.z) ^ 2) - item.radius - other.radius < BossArenaMapData.layout.minGapStuds - 1e-6
						end
						per.overlap += bad and 1 or 0
						table.insert(items, item)
						table.insert(regrown, item)
						total.over += #items > REGROW.maxObstacles and 1 or 0
						local open, _, fraction = ArenaLayout.regrowOpen(items, opts)
						local connected = ArenaLayout.connectivity(items, opts)
						per.closed += connected and 0 or 1
						per.minWalk = math.min(per.minWalk, fraction or 0)
						if not open and connected then
							per.minWalk = math.min(per.minWalk, fraction or 0)
						end
					end
				end
				if s % 10 == 0 then
					task.wait()
				end
			end
			r.check(("B4 %s: 재생성 %d · 교체 %d · 겹침 %d · 닫힌 공간 %d · 이동 가능 면적 최소 %.1f%%(하한 %.0f%%)"):format(bossId, per.spawned, per.replaced, per.overlap, per.closed,
				per.minWalk * 100, REGROW.minWalkableFraction * 100), per.overlap == 0 and per.closed == 0 and per.minWalk >= REGROW.minWalkableFraction and per.replaced > 0)
			total.spawned += per.spawned
			total.replaced += per.replaced
			total.overlap += per.overlap
			total.closed += per.closed
			total.minWalk = math.min(total.minWalk, per.minWalk)
		end
		r.check(("B4 합계 %d회: 재생성 %d · 교체 %d · 겹침 %d · 닫힌 공간 %d · 상한 넘김 %d · 면적 최소 %.1f%% · 자리 찾기 평균 %.2fms · 최대 %.2fms · %.1f초"):format(total.events, total.spawned, total.replaced,
			total.overlap, total.closed, total.over, total.minWalk * 100, total.spotMs / math.max(total.spots, 1), total.spotMax, os.clock() - startedAt),
			total.overlap == 0 and total.closed == 0 and total.over == 0 and total.minWalk >= REGROW.minWalkableFraction)
	end)
	local pass, count = r.summary()
	print(("===P3dF 검증 끝(가E)=== %d/%d 통과"):format(pass, count))
end

return P3dFVerify
