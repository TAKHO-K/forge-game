-- P3a 자동 검증(나) - 원형 보스맵 · 구조물(C)과 장판 판정 실측(D). 보스 검증 체인 끝에서 P3aVerify.runLive 다음에 돈다(DevTools).
--   runLiveC: 보스 6종 맵이 실제로 지어지는가(원형 바닥 · 벽 24 · 테마 색 · 구조물 · 외곽선) · 구조물 3타 파괴 · 돌진 충돌 기절 · 큰 바위판 위 튕김 ·
--             뺑뺑이 방지 · 얼음 기둥이 구조물과 안 겹친다 · 전역 기믹 빨강 바닥 = 원 · 파트 수(C3) · 끝나면 장식이 사라진다.
--   runLiveD(label): 보스방 입장 20회(첫 진입 = 슬롯 기반을 부수고 새로 짓기) + 20회(두 번째 이후) - 판정마다 "원 안이었나 · 판정이 닿았나 · 안 닿았으면 왜"를
--             클라가 받은 예고(P3aTelegraphAck)와 나란히 적는다 + 점프 높이별 판정. 신규 보호(스테이지 5 = ×0.16)를 켠 채로 잰다(첫 보스 = 신규 플레이어).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local P3aVerify = require(script.Parent.P3aVerify)

local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local BossArenaMap = require(script.Parent.BossArenaMap)
local BossArenaProps = require(script.Parent.BossArenaProps)
local MonsterState = require(script.Parent.MonsterState)
local PlayerState = require(script.Parent.PlayerState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerShield = require(script.Parent.PlayerShield)
local BossTrap = require(script.Parent.BossTrap)
local GroundProbe = require(script.Parent.GroundProbe)

local P3aArenaVerify = {}

-- D 실측의 이름표(수정 전 = "전" · 수정 뒤 = "후") - 로그 · 보고서가 두 Play를 나란히 놓는다.
P3aArenaVerify.D_LABEL = "후"

local FLOOR_TOP = BossArenaMap.floorTopY()

local function fullHeal(player)
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	PlayerDamage.syncHud(player)
end

local function place(root, position)
	root.CFrame = CFrame.new(position)
	RunService.Heartbeat:Wait()
end

local function spawnBoss(player, env, bossId, stage)
	stage = stage or BossData.stageInterval
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	if bossId then
		BossEncounter.setDebugForcedBoss(player, bossId)
	end
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	local encounter = BossEncounter.getEncounter(player)
	return model, model and MonsterState.getData(model), encounter
end

-- 보스를 직접 step한다(29-4 drive와 같다 - 캐릭터를 어그로 밖에 두면 MonsterAI는 이 보스를 안 돌린다).
local function drive(player, root, model, data, seconds, untilFn)
	local startedAt = os.clock()
	while os.clock() - startedAt < seconds do
		RunService.Heartbeat:Wait()
		fullHeal(player)
		if not model.Parent then
			break
		end
		BossPatterns.step(model, data, model.PrimaryPart.Position, player, root, 1 / 60, { player })
		if untilFn and untilFn() then
			break
		end
	end
end

local function countParts(instance)
	local parts, total = 0, 0
	if not instance then
		return 0, 0
	end
	for _, d in ipairs(instance:GetDescendants()) do
		total += 1
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	return parts, total + 1
end

function P3aArenaVerify.runLiveC(player, env)
	print("===P3a 검증 시작(나C)===")
	local r = P3aVerify.newRecorder("나C")
	env.ensureBackup(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ids = { "section_guardian", "frost_giant", "abyssal_lord", "crystal_queen", "scorpion_queen", "storm_lord" }
	local perfRows = {}

	r.section("맵 6종", function()
		for _, bossId in ipairs(ids) do
			local model, _, encounter = spawnBoss(player, env, bossId)
			local zone = WorldConfig.zones[encounter.zoneKey]
			local baseModel, dressing, floor = BossArenaMap.debugModels(encounter.zoneKey)
			local theme = BossArenaMapData.maps[bossId]
			local walls = 0
			for _, child in ipairs(baseModel:GetChildren()) do
				walls += child.Name == "BossArenaWall" and 1 or 0
			end
			local expectedObstacles = 0
			for _, spec in ipairs(theme.obstacles) do
				expectedObstacles += #spec.angles
			end
			local obstacles = BossArenaMap.obstacles(encounter.zoneKey)
			local highlights = 0
			for _, d in ipairs(baseModel:GetDescendants()) do
				highlights += (d:IsA("Highlight") and d.Name == "CartoonOutline") and 1 or 0
			end
			for _, d in ipairs(dressing:GetDescendants()) do
				highlights += (d:IsA("Highlight") and d.Name == "CartoonOutline") and 1 or 0
			end
			local floorOk = floor.Shape == Enum.PartType.Cylinder and math.abs(floor.Size.Y / 2 - (zone.radius + BossArenaMapData.geometry.wallThicknessStuds)) < 1e-3
				and floor.Color == theme.floor.color
			local entry = root and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(zone.center.X, 0, zone.center.Z)).Magnitude
			local baseParts = countParts(baseModel) + 1 -- + 바닥(지면 폴더)
			local dressingParts, dressingInstances = countParts(dressing)
			local kitParts = #(encounter.kitParts or {})
			local colliders = 0
			for _, child in ipairs(GroundProbe.folder():GetChildren()) do
				if child.Name == "ArenaObstacleCollider" and ArenaShape.contains(zone, child.Position) then
					colliders += 1
				end
			end
			table.insert(perfRows, ("%s 기반 %d · 장식+구조물 %d(인스턴스 %d) · 킷 %d · 충돌 기둥 %d"):format(bossId, baseParts, dressingParts, dressingInstances, kitParts, colliders))
			r.check(("%s(%s): 원형 바닥(반경 %.0f · 테마색)=%s · 벽 %d(기대 24) · 구조물 %d(기대 %d) · 외곽선 %d(기대 2) · 입장 자리 중심에서 %.1f(기대 %d)"):format(
				bossId, theme.name, floor.Size.Y / 2, tostring(floorOk), walls, #obstacles, expectedObstacles, highlights, entry or -1, BossArenaMapData.geometry.entryDistanceStuds),
				model ~= nil and floorOk and walls == 24 and #obstacles == expectedObstacles and highlights == 2 and entry and math.abs(entry - BossArenaMapData.geometry.entryDistanceStuds) < 2)
		end
	end)

	r.section("구조물 3타 파괴 · 큰 바위판 튕김", function()
		local _, _, encounter = spawnBoss(player, env, "section_guardian")
		local zoneKey = encounter.zoneKey
		local list = BossArenaMap.obstacles(zoneKey)
		local target = list[1]
		local hitsSeen = {}
		for _ = 1, 3 do
			MonsterState.applyDamage(target.model, 1, BossData.stageInterval, player, { committedAt = os.clock() })
			table.insert(hitsSeen, #BossArenaMap.obstacles(zoneKey))
			task.wait(BossArenaMapData.obstacle.hitIntervalSeconds + 0.05)
		end
		local broke = BossArenaMap.lastBreak(zoneKey)
		r.check(("작은 구조물 3타: 남은 구조물 %s(기대 %d · %d · %d) · 마지막 부서짐 원인 %s"):format(table.concat(hitsSeen, " · "), #list, #list, #list - 1, tostring(broke and broke.cause)),
			hitsSeen[1] == #list and hitsSeen[2] == #list and hitsSeen[3] == #list - 1 and broke and broke.cause == "hits")
		-- 연타(간격 안)는 세지 않는다.
		local second = BossArenaMap.obstacles(zoneKey)[1]
		for _ = 1, 3 do
			MonsterState.applyDamage(second.model, 1, BossData.stageInterval, player, { committedAt = os.clock() })
		end
		local afterBurst = BossArenaMap.obstacles(zoneKey)
		local stillThere = false
		for _, o in ipairs(afterBurst) do
			stillThere = stillThere or (o.id == second.id and o.hits == 1)
		end
		r.check(("한 틱에 3타(간격 %.2f초 안) → 1타로 센다=%s"):format(BossArenaMapData.obstacle.hitIntervalSeconds, tostring(stillThere)), stillThere)
		-- 큰 바위판: 위에 서 있다가 부서지면 튕겨 나고 최대 체력 10% 피해.
		local mesa = nil
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			if o.radius >= 8 then
				mesa = o
			end
		end
		fullHeal(player)
		root.Anchored = true
		place(root, mesa.center + Vector3.new(0, mesa.height + 3, 0))
		local hpBefore = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		BossArenaMap.breakObstacle(zoneKey, mesa.id, "hits")
		local info = BossArenaMap.lastBreak(zoneKey)
		local hpAfter = PlayerState.getHp(player) / PlayerState.getMaxHp(player)
		root.Anchored = false
		r.check(("큰 바위판(반경 %.0f · 높이 %.1f) 위에서 부서짐 → 튕김 %d명(기대 1) · 체력 %.0f%% → %.0f%%(기대 −%.0f%%)"):format(mesa.radius, mesa.height, info and #info.launched or 0,
			hpBefore * 100, hpAfter * 100, BossArenaMapData.obstacle.topBreak.maxHpFraction * 100),
			info and #info.launched == 1 and math.abs((hpBefore - hpAfter) - BossArenaMapData.obstacle.topBreak.maxHpFraction) < 1e-6)
		BossEncounter.despawnFor(player)
		local _, dressingAfter = BossArenaMap.debugModels(zoneKey)
		r.check(("보스전 끝 → 장식 · 구조물 치움=%s · 이 슬롯의 구조물 %d"):format(tostring(dressingAfter == nil), #BossArenaMap.obstacles(zoneKey)), dressingAfter == nil and #BossArenaMap.obstacles(zoneKey) == 0)
	end)

	r.section("돌진 충돌 · 뺑뺑이 방지", function()
		local model, data, encounter = spawnBoss(player, env, "section_guardian")
		local zoneKey = encounter.zoneKey
		local zone = WorldConfig.zones[zoneKey]
		local target = nil
		for _, o in ipairs(BossArenaMap.obstacles(zoneKey)) do
			if o.radius < 8 then
				target = o
				break
			end
		end
		-- 보스는 중심, 대상은 구조물 너머(중심 → 구조물 방향으로 구조물 + 15) - 어그로(25.6) 밖이라 MonsterAI는 이 보스를 안 돌린다.
		local dir = Vector3.new(target.center.X - zone.center.X, 0, target.center.Z - zone.center.Z).Unit
		root.Anchored = true
		place(root, Vector3.new(target.center.X, FLOOR_TOP + 3, target.center.Z) + dir * (target.radius + 15))
		BossPatterns.force(model, data, "charge")
		local st = MonsterState.getBossPatternState(model)
		local chargeTo, recoverLeft = nil, nil
		drive(player, root, model, data, 8, function()
			if st.phase == "focus" and st.chargeTo and not chargeTo then
				chargeTo = st.chargeTo
			end
			if st.phase == "chargeRecover" and not recoverLeft then
				recoverLeft = st.phaseEndsAt - os.clock()
				return true
			end
			return false
		end)
		root.Anchored = false
		local info = BossArenaMap.lastBreak(zoneKey)
		local stopDistance = chargeTo and (Vector3.new(chargeTo.X, 0, chargeTo.Z) - Vector3.new(target.center.X, 0, target.center.Z)).Magnitude or -1
		local expectedRecover = data.skills.charge.recoverSeconds + BossArenaMapData.obstacle.chargeStunBonusSeconds
		r.check(("돌진 → 구조물 앞에서 멈춤(도착점과 구조물 중심 %.1f, 기대 %.1f = 반경 + 몸통) · 부서짐 원인 %s · 헤롱 %.2f초(기대 %.1f = %.1f + %.1f)"):format(
			stopDistance, target.radius + BossArenaMapData.obstacle.chargeBodyHalfStuds, tostring(info and info.cause), recoverLeft or -1, expectedRecover,
			data.skills.charge.recoverSeconds, BossArenaMapData.obstacle.chargeStunBonusSeconds),
			math.abs(stopDistance - (target.radius + BossArenaMapData.obstacle.chargeBodyHalfStuds)) < 0.6 and info and info.cause == "charge" and recoverLeft and math.abs(recoverLeft - expectedRecover) < 0.1)
		-- 뺑뺑이 방지: 구조물 곁에서 추격이 이어지면(dt를 흘려) 계산한 시간에 부순다.
		local other = BossArenaMap.obstacles(zoneKey)[1]
		local nearPoint = other.center + Vector3.new(other.radius + 2, 1.5, 0)
		local limit = BossArenaMap.smashSeconds(other.radius, data.moveSpeedStuds)
		local elapsed, smashed = 0, nil
		while elapsed < limit * 2 and not smashed do
			elapsed += 0.5
			smashed = BossArenaMap.noteBossChase(zoneKey, nearPoint, 0.5, data.moveSpeedStuds)
		end
		r.check(("뺑뺑이 방지: 구조물(반경 %.1f) 곁 추격 %.1f초에 부숨(기대 %.1f초 = %d바퀴 · 보스 속도 %d)"):format(other.radius, elapsed, limit, BossArenaMapData.obstacle.smashAfterLaps, data.moveSpeedStuds),
			smashed == other.id and elapsed >= limit - 1e-6 and elapsed < limit + 0.5 + 1e-6)
		BossEncounter.despawnFor(player)
	end)

	r.section("기믹 지형 ↔ 구조물 · 전역 기믹 바닥", function()
		local model, data, encounter = spawnBoss(player, env, "frost_giant")
		local zoneKey = encounter.zoneKey
		local target = BossArenaMap.obstacles(zoneKey)[1]
		local zone = WorldConfig.zones[zoneKey]
		local out = Vector3.new(target.center.X - zone.center.X, 0, target.center.Z - zone.center.Z).Unit
		root.Anchored = true
		place(root, Vector3.new(target.center.X, FLOOR_TOP + 3, target.center.Z) + out * (target.radius + 1.5)) -- 구조물에 붙어 선다(낙빙 첫 원 = 발밑)
		BossPatterns.force(model, data, "icefall")
		local st = MonsterState.getBossPatternState(model)
		local started = false
		drive(player, root, model, data, 6, function()
			started = started or st.phase == "meteorTelegraph"
			return started and st.phase ~= "meteorTelegraph"
		end)
		root.Anchored = false
		local overlapping, pillars = 0, 0
		for _, prop in ipairs(BossArenaProps.list(model)) do
			pillars += 1
			if BossArenaMap.overlapsObstacle(zoneKey, prop.position, prop.radius, 0) then
				overlapping += 1
			end
		end
		r.check(("낙빙(구조물에 붙어 선 대상): 선 얼음 기둥 %d · 구조물과 겹친 기둥 %d(기대 0 - 겹칠 자리는 건너뛴다)"):format(pillars, overlapping), overlapping == 0)
		-- 전역 기믹의 빨강 바닥이 원이고 맵 바닥색을 싣는다.
		local payload = nil
		BossPatterns.debugSendHook = function(kind, data_)
			if kind == "gimmickTelegraph" then
				payload = data_
			end
		end
		root.Anchored = true
		place(root, Vector3.new(zone.center.X + 40, FLOOR_TOP + 3, zone.center.Z))
		BossPatterns.force(model, data, "roar")
		drive(player, root, model, data, 1, function()
			return payload ~= nil
		end)
		root.Anchored = false
		BossPatterns.debugSendHook = nil
		r.check(("전역 기믹 예고: 원 반경 %s(기대 %d) · 바닥색 = 테마(%s)"):format(tostring(payload and payload.zoneRadius), zone.radius,
			tostring(payload and payload.floorColor == BossArenaMapData.maps.frost_giant.floor.color)),
			payload and payload.zoneRadius == zone.radius and payload.floorColor == BossArenaMapData.maps.frost_giant.floor.color)
		BossEncounter.despawnFor(player)
	end)

	r.section("C3 파트 수", function()
		r.check(("아레나 파트(보스전 1개 활성): %s"):format(table.concat(perfRows, " / ")), #perfRows == 6)
		local model = spawnBoss(player, env, "frost_giant")
		task.wait(0.5)
		local parts, total = 0, 0
		for _, d in ipairs(Workspace:GetDescendants()) do
			total += 1
			if d:IsA("BasePart") then
				parts += 1
			end
		end
		r.check(("보스전 장면(서리 거인 · 테마 맵) 워크스페이스 인스턴스 %d · 파트 %d(P2.5a 기준선 1,908 ~ 1,918 · 1,067 ~ 1,069 - 사용자 지시로 기준선 초과 허용, 보고)"):format(total, parts), model ~= nil)
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
	r.check(("검증 뒤 encounter 없는 보스 모델 %d"):format(orphan), orphan == 0)
	local passCount, totalCount = r.summary()
	print(("===P3a 검증 끝(나C)=== %d/%d 통과"):format(passCount, totalCount))
end

-- ═══ D: 장판 표시 ↔ 판정 실측 ═══

local ackEvent = nil
local function ensureAck()
	if not ackEvent then
		ackEvent = Instance.new("RemoteEvent")
		ackEvent.Name = "P3aTelegraphAck"
		ackEvent.Parent = ReplicatedStorage
	end
	return ackEvent
end

local function shapeContains(shape, position)
	local p = Vector3.new(position.X, 0, position.Z)
	if shape.kind == "circle" then
		for _, center in ipairs(shape.centers) do
			local d = (p - Vector3.new(center.X, 0, center.Z)).Magnitude
			if d <= shape.radius and d >= (shape.inner or 0) then
				return true
			end
		end
		return false
	elseif shape.kind == "beams" then
		local rel = p - Vector3.new(shape.origin.X, 0, shape.origin.Z)
		for _, beam in ipairs(shape.beams) do
			local along = rel:Dot(beam.dir)
			if along >= 0 and along <= beam.length and (rel - beam.dir * along).Magnitude <= shape.halfWidth then
				return true
			end
		end
	end
	return false
end

-- 판정에서 빠진 까닭(원 안이었는데 판정이 안 닿았을 때).
local function missReason(player, root, floorY)
	if not root then
		return "캐릭터 없음"
	end
	if (PlayerState.getHp(player) or 0) <= 0 then
		return "체력 0"
	end
	local dy = root.Position.Y - floorY
	if math.abs(dy) > 8 then
		return ("높이(루트 − 바닥 %.1f > 8)"):format(dy)
	end
	if BossTrap.isTrapped(player) then
		return "잡힘"
	end
	return "알 수 없음"
end

function P3aArenaVerify.runLiveD(player, env, label, entries)
	entries = entries or 20
	print(("===P3a 검증 시작(D %s)==="):format(label))
	local r = P3aVerify.newRecorder("D " .. label)
	env.ensureBackup(player)
	local ack = ensureAck()
	local acks = {}
	local connection = ack.OnServerEvent:Connect(function(who, kind, name, serverTime, position, grounded)
		if who == player then
			table.insert(acks, { kind = kind, name = name, t = serverTime, position = position, grounded = grounded })
		end
	end)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local profile = PlayerProfile.getProfile(player)
	local classState = profile.classes[profile.classId]
	-- 첫 보스 = 신규 플레이어: 신규 보호를 켜고(체인은 끄고 돈다) 최고를 5로 둔다(×0.16).
	local oldNewbieOff = PlayerDamage.debugNewbieProtectionOff
	PlayerDamage.debugNewbieProtectionOff = false
	local stage = BossData.stageInterval

	local judgements, sends = {}, {}
	BossPatterns.debugSendHook = function(kind, payload, serverTime)
		if kind == "heavyTelegraph" or kind == "meteor" or kind == "cross" or kind == "focus" or kind == "shockTelegraph" or kind == "gimmickTelegraph" then
			table.insert(sends, { kind = kind, t = serverTime, clock = os.clock() })
		end
	end
	BossPatterns.debugJudgeHook = function(record)
		local character_ = player.Character
		local root_ = character_ and character_:FindFirstChild("HumanoidRootPart")
		record.rootPosition = root_ and root_.Position
		record.inside = root_ and shapeContains(record.shape, root_.Position) or false
		record.hit = record.hits[player] ~= nil
		record.dealt = record.hits[player]
		record.reason = (record.inside and not record.hit) and missReason(player, root_, record.floorY) or nil
		record.newbie = PlayerDamage.getNewbieMultiplier(player)
		record.shield = PlayerShield.getTotal(player)
		table.insert(judgements, record)
	end

	local rows = {}
	local shownNoJudge, insideTotal, hitTotal = 0, 0, 0
	local function runEntry(index, first)
		if first then
			BossEncounter.despawnFor(player)
			BossArenaMap.debugDestroyBases()
		end
		classState.stageProgress.infiniteBest = stage -- 신규 보호 ×0.16
		fullHeal(player)
		local judgedFrom, sentFrom, ackFrom = #judgements + 1, #sends + 1, #acks + 1
		local t0 = os.clock()
		local _, _, encounter = spawnBoss(player, env, nil, stage)
		local model = encounter and encounter.model
		if not model then
			return
		end
		local registeredAt = os.clock() -- spawnEncounter 안에서 encounterOf가 채워진다(같은 틱)
		local st = MonsterState.getBossPatternState(model)
		task.wait(0.5) -- 입장 뒤 걸어 들어오기 시작(실제 플레이의 첫 몇 걸음)
		local zone = WorldConfig.zones[encounter.zoneKey]
		place(root, Vector3.new(zone.center.X, FLOOR_TOP + 3, zone.center.Z + 10)) -- 보스 10stud 앞(강타 반경 안 · 어그로 안) - 이후 가만히 선다
		local deadline = os.clock() + 12
		while os.clock() < deadline do
			task.wait(0.1)
			fullHeal(player)
			local got = 0
			for i = judgedFrom, #judgements do
				got += (judgements[i].model == model) and 1 or 0
			end
			if got >= 2 then
				break
			end
		end
		local firstSend = sends[sentFrom]
		local graceUntil = st and st.graceUntil
		for i = judgedFrom, #judgements do
			local j = judgements[i]
			if j.model == model then
				-- 이 판정의 예고를 클라가 받았는가(판정 시각 − 3초 안의 같은 계열 예고 수신).
				local shown = false
				for a = ackFrom, #acks do
					if acks[a].kind == "telegraph" and acks[a].t <= j.serverTime and acks[a].t >= j.serverTime - 3.5 then
						shown = true
					end
				end
				if j.inside then
					insideTotal += 1
					hitTotal += j.hit and 1 or 0
				end
				if shown and j.inside and not j.hit then
					shownNoJudge += 1
				end
				table.insert(rows, ("%s#%02d %s +%.2f초 | 등록 +%.2f · 유예끝 +%.2f · 첫 예고 +%s | 원안=%s 판정=%s 피해 %s(신규 보호 ×%.2f · 쉴드 %.0f) 루트−바닥 %.1f 클라 수신=%s%s"):format(
					first and "첫" or "재", index, tostring(j.skill), j.at - t0, registeredAt - t0, (graceUntil or t0) - t0,
					firstSend and ("%.2f"):format(firstSend.clock - t0) or "-", tostring(j.inside), tostring(j.hit), j.dealt and ("%.1f"):format(j.dealt) or "-",
					j.newbie, j.shield, j.rootPosition and (j.rootPosition.Y - j.floorY) or -99, tostring(shown), j.reason and (" · 빠진 까닭 " .. j.reason) or ""))
			end
		end
		local floorAcks = {}
		for a = ackFrom, #acks do
			if acks[a].kind == "floor" then
				table.insert(floorAcks, ("%.2f"):format(acks[a].t - (Workspace:GetServerTimeNow() - (os.clock() - t0))))
			end
		end
		table.insert(rows, ("%s#%02d 입장 요약: 바닥 도착(클라) +%s초 · 판정 %d회"):format(first and "첫" or "재", index, #floorAcks > 0 and table.concat(floorAcks, ",") or "없음(이미 있음)", (function()
			local n = 0
			for i = judgedFrom, #judgements do
				n += (judgements[i].model == model) and 1 or 0
			end
			return n
		end)()))
		BossEncounter.despawnFor(player)
	end

	for index = 1, entries do
		runEntry(index, true)
	end
	for index = 1, entries do
		runEntry(index, false)
	end
	for _, row in ipairs(rows) do
		print(("[P3a][D %s] %s"):format(label, row))
	end
	r.check(("입장 %d + %d회: 원 안 판정 %d번 중 판정 닿음 %d · 보였는데(클라 수신) 판정 없음 %d(기대 0)"):format(entries, entries, insideTotal, hitTotal, shownNoJudge), shownNoJudge == 0 and insideTotal > 0)

	-- 점프 높이별: 강타(구간 수호자 heavy, 반경 14)의 판정 순간에 루트를 바닥 + 3 + h에 둔다(점프 정점 ≈ 7.2).
	local jumpRows, jumpMiss = {}, 0
	for _, h in ipairs({ 0, 2, 4, 5, 6, 7 }) do
		local model, data, encounter = spawnBoss(player, env, "section_guardian", stage)
		local zone = WorldConfig.zones[encounter.zoneKey]
		root.Anchored = true
		place(root, Vector3.new(zone.center.X, FLOOR_TOP + 3, zone.center.Z + 8))
		fullHeal(player)
		local st = MonsterState.getBossPatternState(model)
		-- 어그로가 붙는 순간 스케줄러 시계가 새로 시작돼(onAggro) 강제한 스킬이 지워진다(P3a Play 1: h 0 칸이 판정 없음 nil) - 어그로가 붙은 뒤에 강제한다.
		local aggroWait = 0
		while MonsterState.getAiState(model) ~= "chasing" and aggroWait < 2 do
			RunService.Heartbeat:Wait()
			aggroWait += 1 / 60
		end
		local before = #judgements
		BossPatterns.force(model, data, "heavy")
		-- 대상이 보스 8stud 안(어그로 안)이라 MonsterAI가 이 보스를 돌린다 - 여기서는 step하지 않고 보기만 한다(이중 step 금지 - 29-4 교훈).
		local lifted, waited = false, 0
		while waited < 4 and #judgements <= before do
			RunService.Heartbeat:Wait()
			waited += 1 / 60
			fullHeal(player)
			if st.phase == "heavyTelegraph" and not lifted and os.clock() >= st.phaseEndsAt - 0.05 then
				lifted = true
				root.CFrame = CFrame.new(zone.center.X, FLOOR_TOP + 3 + h, zone.center.Z + 8)
			end
		end
		local j = judgements[before + 1]
		root.Anchored = false
		if j and j.inside and not j.hit then
			jumpMiss += 1
		end
		table.insert(jumpRows, ("h %d → 원안 %s · 판정 %s"):format(h, tostring(j and j.inside), tostring(j and j.hit)))
		BossEncounter.despawnFor(player)
	end
	r.check(("점프 높이별(루트 = 바닥 + 3 + h · 점프 정점 약 7.2): %s · 원 안인데 판정 없음 %d(기대 0 - 높이 상한 8의 뜻 \"점프(7.2)로 닿는 높이는 같은 층\" · TerrainConfig)"):format(table.concat(jumpRows, " · "), jumpMiss), jumpMiss == 0)

	BossPatterns.debugSendHook = nil
	BossPatterns.debugJudgeHook = nil
	connection:Disconnect()
	PlayerDamage.debugNewbieProtectionOff = oldNewbieOff
	env.restore(player)
	local passCount, totalCount = r.summary()
	print(("===P3a 검증 끝(D %s)=== %d/%d 통과"):format(label, passCount, totalCount))
end

return P3aArenaVerify
