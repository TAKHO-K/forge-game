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

return P3dFVerify
