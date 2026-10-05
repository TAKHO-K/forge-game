-- BR1 대공 잡기 → BR1-2 개정(docs/design/boss-br1-2.md §3 - 6종 공통 규칙, 모션만 보스별). primitive = "grab" 핸들러 + 잡힘 종류 "airFrozen"(얼음) · "grabbed"(손).
-- 흐름(수치 = BossData.mechanics.airGrab):
--   시전(스킬 telegraphSeconds 5초): 보스 위 "점프하지 마" · BR1-4a: 시전 끝 judgeWindowSeconds(1.5초) 동안의 **누적 체공**(강제 체공 · 원거리 정지 · 가둠 포함)이
--   airAccumSeconds(0.65초)에 닿는 순간 그 자리에 얼림 · 창 안에서 떠 있는 사람 머리 위 손바닥이 누적만큼 찬다
--   → 시전 끝: 얼린 사람이 없으면 끝. 있으면 가장 가까운 사람부터(잡는 순간 거리로 다시) 보스가 이동 속도 × chaseSpeedMultiplier로 다가가 잡는다 - 잡힌 사람은 보스 머리 위 둘레에 들려 따라간다
--   → 마지막 사람을 잡은 뒤 holdSeconds 안에 못 빠져나온 사람 = 던짐(보스별 던지는 모션 · 벽 앞까지) + 현재 체력 × currentHpFraction(발사 허가 - 되돌림 0)
--   BR1-4a(사용자 정정): 탈출은 **사람마다** - 자기 발버둥 게이지(pressesBase회)를 채우거나 동료가 그 사람의 손을 때려(3타) · 곁에서 F 홀드로 풀어 준다.
--   보스 기절은 두 경우만: ① 잡힌 사람 전원이 탈출(한 명도 안 던져짐) ② 시전 판정에 아무도 안 걸림(전조를 읽고 점프 안 함). 한 명이라도 던져지면 기절 없음.
--   도발(성기사 - K)로 풀린 사람은 탈출로 친다. 잡기 동안 보스는 새 패턴을 고르지 않는다(스킬 진행 중) · 환경 변화는 따로 돈다.
--   공중 가둠(거품 · 회오리 - kind "bubbled")에 갇힌 사람은 "공중"이다 - 얼림 · 잡기로 이어진다(BR1-2 §4).
-- 판정 · 잡힘 · 던짐 발신은 서버, 손 모션 · 들림 · 던짐 물리는 클라(BossGrabView · 기존 BossStormView.launch).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Reach = require(ReplicatedStorage.Shared.Reach) -- A2-M1 구출 정면 판정
local BossTrap = require(script.Parent.BossTrap)
local PlayerState = require(script.Parent.PlayerState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossArenaContainment = require(script.Parent.BossArenaContainment)
local HeightGuard = require(script.Parent.HeightGuard)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossRig = require(ReplicatedStorage.Shared.BossRig)
local BossMotion = require(ReplicatedStorage.Shared.BossMotion)
local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData) -- BOSS-FRAMEWORK 변신 기준(enrage.phaseAt)
local PlayerStun = require(script.Parent.PlayerStun) -- BR1-3 기절 면역(연속 기절 방지 - 얼림도 같은 규칙)

local BossAirGrab = {}

local CONFIG = BossData.mechanics.airGrab
local ROOT_ABOVE_FEET = 3 -- 루트 중심 = 발 + 3(HipHeight 2 + 루트 반높이 1)
local SAFETY_TRAP_SECONDS = 40 -- 잡힘 · 얼음의 자동 해제는 이 핸들러가 직접 한다 - 타이머는 안전장치(보스가 사라진 경우)

local kit -- BossPatterns가 register로 넘긴다

local struggleEvent = Instance.new("RemoteEvent")
struggleEvent.Name = "BossGrabStruggle"
struggleEvent.Parent = ReplicatedStorage

local grabsByModel = {} -- [보스 Model] = { [Player] = true } - 지금 이 보스가 들고 있는 사람
local handTargets = {} -- [Player] = { model(구출 대상 손), lastHitAt = { [구출자] = os.clock } }

local function realPlayer(player)
	return typeof(player) == "Instance"
end

local function userIdOf(player)
	return realPlayer(player) and player.UserId or 0
end

local function isBubbled(player)
	local record = BossTrap.getRecord(player)
	return record ~= nil and record.kind == "bubbled"
end

-- BR1-4a: 판정 창(시전 끝 judgeWindowSeconds) 안에서 센 누적 체공. 공중 가둠은 그 시간 내내 공중이다. 강제 체공 · 원거리 정지는 trackAir가 체공으로 센다.
local function countedAir(c, player)
	return (c.st.grabAirAccum and c.st.grabAirAccum[player]) or 0
end

-- 판정 창 안 한 틱: 떠 있으면 누적에 dt를 더한다.
local function accumulate(c)
	local st = c.st
	st.grabAirAccum = st.grabAirAccum or {}
	if c.now < st.phaseEndsAt - CONFIG.judgeWindowSeconds then
		return
	end
	local dt = math.min(st.dt or 1 / 30, 0.1)
	for _, v in ipairs(kit.victims(st)) do
		-- BR1-4c c-11: 잡힌 사람(눈덩이에 파묻혀 구르는 중 포함 - 가둠 제외)은 땅 위 취급 - 체공을 세지 않는다
		if isBubbled(v.player) or (not BossTrap.isTrapped(v.player) and kit.airSecondsOf(st, v.player, c.now) > 0) then
			st.grabAirAccum[v.player] = (st.grabAirAccum[v.player] or 0) + dt
		end
	end
end

local function markLevel(accum)
	if accum <= 0 then
		return 0
	end
	-- 0.25 단위로 끊어 보낸다(바뀔 때만 발신 - 매 틱 보내지 않는다). 가득 = 얼림.
	local level = math.clamp(accum / CONFIG.airAccumSeconds, 0, 1)
	return math.max(math.floor(level * 4 + 1e-6) / 4, 0.25)
end

local function sendMarks(c)
	local st = c.st
	st.grabMarks = st.grabMarks or {}
	for _, v in ipairs(kit.victims(st)) do
		local frozen = st.grabFrozen[v.player]
		local level = (frozen or (BossTrap.isTrapped(v.player) and not isBubbled(v.player))) and 0 or markLevel(countedAir(c, v.player))
		if st.grabMarks[v.player] ~= level then
			st.grabMarks[v.player] = level
			kit.send(st, "grabMark", { userId = realPlayer(v.player) and v.player.UserId or nil, level = level })
		end
	end
end

local function clearMarks(c)
	local st = c.st
	for player, level in pairs(st.grabMarks or {}) do
		if level > 0 then
			kit.send(st, "grabMark", { userId = realPlayer(player) and player.UserId or nil, level = 0 })
		end
	end
	st.grabMarks = {}
end

-- 얼릴 수 있는가: 판정 창 누적 체공 ≥ airAccumSeconds · (진짜 사람은) 지면 거리까지 재도 떠 있다(가둠은 예외) · 무적 · 복귀 보호 아님 · 가둠 말고 다른 잡힘 아님 · 살아 있다.
local function freezable(c, v)
	if c.st.grabFrozen[v.player] or (PlayerState.getHp(v.player) or 0) <= 0 or PlayerStun.isImmune(v.player) then
		return false
	end
	local bubbled = isBubbled(v.player)
	if BossTrap.isTrapped(v.player) and not bubbled then
		return false
	end
	if not bubbled and (PlayerState.isInvulnerable(v.player) or BossArenaContainment.isProtected(v.player)) then
		return false
	end
	if countedAir(c, v.player) < CONFIG.airAccumSeconds then
		return false
	end
	return bubbled or not realPlayer(v.player) or kit.isAirborne(v.player.Character, 0.5)
end

local function freeze(c, v)
	local st = c.st
	local air = countedAir(c, v.player)
	if isBubbled(v.player) then
		BossTrap.release(v.player, "chain") -- 가둠 → 얼음(유예 없음)
	end
	if not BossTrap.trap(v.player, {
		kind = "airFrozen", rescueType = "chainFrozen", autoReleaseSeconds = SAFETY_TRAP_SECONDS,
		context = { origin = v.root.Position, zoneKey = MonsterState.getZoneKey(c.model), bossModel = c.model },
	}) then
		return
	end
	st.grabFrozen[v.player] = true
	st.grabFrozenCount += 1
	HeightGuard.exempt(v.player, SAFETY_TRAP_SECONDS)
	kit.send(st, "grabFreeze", { userIds = { userIdOf(v.player) }, positions = { v.root.Position }, bossId = c.data.id, color = c.data.headColor })
	kit.debugEvent("grabFreeze", { player = v.player, at = c.now, air = air })
	print(("[forge-game] 대공 잡기: %s 얼림(판정 창 누적 체공 %.2f초)"):format(tostring(v.player.Name), air))
end

-- BR1-4b(4b-3 · 4b-5): 관절 리그 보스는 **보이는 손 · 어깨 · 꼬리 · 집게 부착점**에 매단다 - 모션과 같은 식(shared/BossMotion)으로 서버가 FK를 풀어 그 자리를 쓴다(클라 BossAnimator도 같은 자리에 그린다).
-- 반환: 루트 자리, 부착점 이름(없으면 nil = 옛 머리 위 둘레).
local rigCache = {}
local function rigHoldPoint(c, index)
	local rig, rigId = BossRigSpec.rigOf(c.model) -- BOSS-FRAMEWORK 1: 새 몸(BossRigKey)이면 그 리그 FK
	local root = c.model.PrimaryPart
	if not rig or not root then
		return nil
	end
	local cache = rigCache[rigId]
	if not cache then
		cache = { ctx = BossMotion.context(rigId, rig, c.data.skills, c.data.moveSpeedStuds), rest = BossMotion.prepare(rig) }
		rigCache[rigId] = cache
	end
	local slots = BossRigSpec.holdSlots[rig.plan] or BossRigSpec.holdSlots.biped
	local slot = slots[math.min(index, #slots)]
	local m = c.model
	local st = { act = m:GetAttribute("BossAct"), actAt = m:GetAttribute("BossActAt"), actHit = m:GetAttribute("BossActHit"), speed = 0,
		pickAt = m:GetAttribute("BossPickAt"), inCombat = true, noOverlap = true,
		form = rig.variant and (((m:GetAttribute("BossHpRatio") or 1) < BossMotionData.enrage.phaseAt) and "after" or "before") or nil } -- BOSS-FRAMEWORK: 새 몸 = 체력 절반 아래면 변신 뒤 세트(클라 겉모습과 같은 기준) -- BR1-4c: 클라와 같은 보스전 기본 자세 · A2-M1: 잡기 중 겹침 지연 끔(클라도 잡기 중 끔 - 같은 부착점)
	local plan = m:GetAttribute("BossThrowPlan") -- 4b 리뷰 1: 지난 회차의 던지기 예정은 버린다(클라 readState와 같은 거르기)
	st.throwPlan = (plan and st.actAt and plan > st.actAt) and plan or nil
	local S = root.Size.X / 2
	-- 한 틱에 보스당 한 번만 자세 · FK를 푼다(잡힌 사람 여럿이면 부착점만 꺼낸다)
	local tick = c.st.rigHoldTick
	if not tick or tick.at ~= c.now or tick.root ~= root.CFrame then
		local pose = BossMotion.evaluate(cache.ctx, st, kit.serverNow())
		local upright = CFrame.new(root.Position) * CFrame.Angles(0, math.atan2(-root.CFrame.LookVector.X, -root.CFrame.LookVector.Z), 0)
		tick = { at = c.now, root = root.CFrame, frames = BossRig.solve(rig, upright, S, BossMotion.toTransforms(cache.rest, S, pose)) }
		c.st.rigHoldTick = tick
	end
	local a = rig.attach[slot]
	local host = a and tick.frames[a.part]
	local at = host and host * CFrame.new(a.at * S)
	return at and (at.Position - Vector3.new(0, BossRigSpec.holdHangStuds, 0)) or nil, slot
end

-- 들고 있는 자리: 리그 부착점(위) · 없으면 보스 머리 위 둘레(index마다 90° 벌린다).
local function holdPoint(c, index)
	local rigPoint, slot = rigHoldPoint(c, index)
	if rigPoint then
		return rigPoint, slot
	end
	local origin = kit.xz(c.model:GetPivot().Position)
	local a = math.rad(90 * (index - 1) + 45)
	local at = origin + Vector3.new(math.cos(a), 0, math.sin(a)) * CONFIG.holdOffsetStuds
	return Vector3.new(at.X, c.st.floorY + CONFIG.holdLiftStuds + ROOT_ABOVE_FEET, at.Z)
end

local function nearestFrozen(c)
	local best, bestDistance = nil, math.huge
	local from = kit.xz(c.model:GetPivot().Position)
	for player in pairs(c.st.grabFrozen) do
		local record = BossTrap.getRecord(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and record and record.kind == "airFrozen" then
			local d = (kit.xz(root.Position) - from).Magnitude
			if d < bestDistance then
				best, bestDistance = { player = player, root = root }, d
			end
		else
			c.st.grabFrozen[player] = nil
		end
	end
	return best, bestDistance
end

local function setRootAt(v, point)
	if typeof(v.root) == "Instance" then
		v.root.CFrame = CFrame.new(point) * v.root.CFrame.Rotation
	else
		v.root.Position = point
	end
end

-- 사람마다 발버둥 게이지(남은 비율 - 가득 1 → 0이면 탈출).
local function gaugeAttribute(st)
	for _, player in ipairs(st.grabHeld or {}) do
		local g = st.grabGauges and st.grabGauges[player]
		if g and realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", math.clamp(1 - g.done / g.need, 0, 1))
		end
	end
end

local function grab(c, v)
	local st, skill = c.st, c.skill
	st.grabFrozen[v.player] = nil
	local from = v.root.Position
	BossTrap.release(v.player, "chain") -- 얼음 → 손(유예 없음 - 바로 다음 잡힘)
	local index = #st.grabHeld + 1
	local point, slot = holdPoint(c, index)
	if not BossTrap.trap(v.player, {
		kind = skill.trap.kind, rescueType = skill.trap.rescueType, autoReleaseSeconds = SAFETY_TRAP_SECONDS,
		context = { origin = point, zoneKey = MonsterState.getZoneKey(c.model), bossModel = c.model, grab = true, color = c.data.headColor },
		onAutoRelease = function(player) -- 안전장치 경로도 던짐과 같은 피해(풀리기 직전 - 잡힌 채)
			PlayerDamage.applyCurrentHpFraction(player, CONFIG.currentHpFraction, skill.damageLabel)
		end,
	}) then
		return
	end
	table.insert(st.grabHeld, v.player)
	st.grabGauges[v.player] = { need = CONFIG.struggle.pressesBase, done = 0 }
	local held = grabsByModel[c.model] or {}
	grabsByModel[c.model] = held
	held[v.player] = true
	HeightGuard.exempt(v.player, SAFETY_TRAP_SECONDS)
	setRootAt(v, point)
	if realPlayer(v.player) then
		v.player:SetAttribute("BossHoldSlot", slot) -- BR1-4b: 클라가 보이는 부착점에 붙여 그린다
	end
	gaugeAttribute(st)
	kit.send(st, "grabPick", {
		userId = realPlayer(v.player) and v.player.UserId or nil, from = from, point = point, liftSeconds = CONFIG.liftSeconds,
		bossId = c.data.id, motion = skill.motion, color = c.data.headColor, bossPosition = Vector3.new(c.position.X, st.floorY, c.position.Z),
		need = CONFIG.struggle.pressesBase,
	})
	kit.debugEvent("grabPick", { player = v.player, at = c.now, index = index })
end

local function releaseAll(c, reason)
	local st = c.st
	for player in pairs(st.grabFrozen or {}) do
		BossTrap.release(player, reason)
	end
	st.grabFrozen = {}
	local held = grabsByModel[c.model]
	grabsByModel[c.model] = nil
	for player in pairs(held or {}) do
		BossTrap.release(player, reason)
	end
	for _, player in ipairs(st.grabHeld or {}) do
		if realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", nil)
			player:SetAttribute("BossHoldSlot", nil)
		end
	end
	st.grabHeld = {}
end

local function beginStun(c, why)
	local st = c.st
	releaseAll(c, "reset") -- 이미 전원 풀렸다(탈출) 또는 아무도 없다(안 걸림) - 남은 기록만 치운다
	st.phase = "grabStun"
	st.phaseEndsAt = c.now + CONFIG.stunSeconds
	st.dazeBase = c.model:GetPivot().Position
	c.model:PivotTo(CFrame.new(st.dazeBase - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(25)))
	kit.send(st, "daze", { seconds = CONFIG.stunSeconds })
	kit.send(st, "grabEnd", { stunned = true, why = why })
	kit.debugEvent("grabStun", { at = c.now, why = why })
	print(("[forge-game] 대공 잡기 풀림(%s) → 보스 기절 %.1f초"):format(why, CONFIG.stunSeconds))
end

-- 던짐 방향 · 거리: 무작위 방위로 아레나 벽 앞(반경 − wallMarginStuds)에 떨어지게(사용자 - 중앙에서 담장 근처까지). 맵 밖이면 기존 복귀.
local function throwPlan(model, root)
	local zone = kit.zoneOf(model)
	local center = kit.xz(zone.center)
	local angle = math.random() * 2 * math.pi
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local land = center + dir * ((zone.radius or 140) - CONFIG.throw.wallMarginStuds)
	local flat = land - kit.xz(root.Position)
	local distance = math.max(flat.Magnitude, CONFIG.throw.minDistanceStuds)
	local away = flat.Magnitude > 1e-3 and flat.Unit or dir
	return away, distance
end

local function throwAll(c)
	local st, skill = c.st, c.skill
	local ids = {}
	for _, player in ipairs(st.grabHeld) do
		if BossTrap.getRecord(player) and BossTrap.getRecord(player).kind == "grabbed" then
			PlayerDamage.applyCurrentHpFraction(player, CONFIG.currentHpFraction, skill.damageLabel)
			BossTrap.noteSkillHit(player)
			table.insert(ids, userIdOf(player))
		end
	end
	kit.send(st, "grabThrow", { userIds = ids, motion = skill.motion, bossId = c.data.id, bossPosition = c.model:GetPivot().Position, color = c.data.headColor })
	-- 4b 리뷰 3: 던지는 출발 높이는 옛 들기 높이 그대로(던지기 전조 자세의 손 높이면 포물선이 길어져 벽을 넘을 수 있다 - 던짐 판정 불변)
	for _, player in ipairs(st.grabHeld) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			setRootAt({ root = root }, Vector3.new(root.Position.X, st.floorY + CONFIG.holdLiftStuds + ROOT_ABOVE_FEET, root.Position.Z))
		end
	end
	local held = grabsByModel[c.model]
	grabsByModel[c.model] = nil
	for _, player in ipairs(st.grabHeld) do
		if realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", nil)
			player:SetAttribute("BossHoldSlot", nil)
		end
		if held and held[player] then
			local record = BossTrap.getRecord(player)
			if record then
				record.onAutoRelease = nil -- 피해는 방금 넣었다
			end
			BossTrap.release(player, "auto") -- onReleased → 던짐
		end
	end
	st.grabHeld = {}
end

BossAirGrab.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "grabTelegraph"
		c.model:SetAttribute("BossThrowPlan", nil) -- 4b 리뷰 1: 지난 회차 값 지우기
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.grabStartedAt = c.now
		st.grabMarks = {}
		st.grabAirAccum = {}
		st.grabGauges, st.grabEscaped, st.grabThrown = {}, 0, 0
		st.grabFrozen = {}
		st.grabFrozenCount = 0
		st.grabHeld = {}

		kit.send(st, "grabTelegraph", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds,
			bossId = c.data.id, motion = skill.motion, color = c.data.headColor, noJump = true,
			judgeWindowSeconds = CONFIG.judgeWindowSeconds, airAccumSeconds = CONFIG.airAccumSeconds,
		})
		sendMarks(c)
	end,
	step = function(c)
		local st = c.st
		if st.phase == "grabTelegraph" then
			-- 판정 창(시전 끝 1.5초): 누적 체공이 기준에 닿는 순간 얼린다
			accumulate(c)
			for _, v in ipairs(kit.victims(st)) do
				if freezable(c, v) then
					freeze(c, v)
				end
			end
			sendMarks(c)
			if c.now < st.phaseEndsAt then
				return
			end
			clearMarks(c)
			if st.grabFrozenCount == 0 then
				kit.send(st, "grabMiss", {})
				beginStun(c, "아무도 안 걸림") -- BR1-4a: 전조를 읽고 아무도 안 떴으면 보스가 헛손질 → 기절
				return
			end
			st.phase = "grabChase"
			st.grabChaseStartedAt = c.now
			kit.debugEvent("grab", { count = st.grabFrozenCount, at = c.now, need = CONFIG.struggle.pressesBase })
			print(("[forge-game] 대공 잡기: %d명 얼림 → 가까운 순서로 잡으러 간다(사람마다 발버둥 %d회)"):format(st.grabFrozenCount, CONFIG.struggle.pressesBase))
			return
		end
		if st.phase == "grabStun" then
			if c.now >= st.phaseEndsAt then
				kit.clearDaze(c.model, st)
				kit.endSkill(c.model, st, c.data, c.now)
			end
			return
		end
		-- 잡기 · 들고 있기 공통: 잡힌 사람 전원이 (각자) 빠져나왔고 얼린 사람도 없다 → 한 명도 안 던져졌으면 기절
		if #st.grabHeld == 0 and next(st.grabFrozen) == nil and st.grabFrozenCount > 0 then -- 얼음 상태에서 구출된 사람도 탈출로 친다
			if st.grabThrown == 0 then
				beginStun(c, "전원 탈출")
			else
				kit.send(st, "grabEnd", { stunned = false })
				kit.endSkill(c.model, st, c.data, c.now)
			end
			return
		end
		-- 들린 사람은 보스를 따라간다(손 = 구출 대상도 같이)
		for index, player in ipairs(st.grabHeld) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local point, slot = holdPoint(c, index)
				if slot and realPlayer(player) and player:GetAttribute("BossHoldSlot") ~= slot then
					player:SetAttribute("BossHoldSlot", slot) -- 4b 리뷰 2: 한 명이 풀려 순서가 당겨지면 보이는 자리도 같이
				end
				setRootAt({ root = root }, point)
				local entry = handTargets[player]
				if entry and entry.model and entry.model.Parent then
					entry.model:PivotTo(CFrame.new(point - Vector3.new(0, ROOT_ABOVE_FEET + 1.5, 0) + Vector3.new(0, 1, 0)))
				end
			end
		end
		if st.phase == "grabChase" then
			local v, distance = nearestFrozen(c)
			if not v then
				st.phase = "grabHold"
				st.phaseEndsAt = c.now + CONFIG.holdSeconds
				c.model:SetAttribute("BossThrowPlan", kit.serverNow() + CONFIG.holdSeconds) -- BR1-4b 모션(판정과 무관): 던지는 예정 시각 - 클라가 던지기 전조를 미리 시작한다
				return
			end
			local timedOut = c.now - st.grabChaseStartedAt >= CONFIG.chaseMaxSeconds
			if distance <= CONFIG.chaseReachStuds or timedOut then
				if timedOut then -- 못 닿으면(구조물 · 멀리) 곁으로 순간 이동해서라도 잡는다 - 얼린 사람은 전원 잡힌다(사용자)
					local toward = kit.xz(v.root.Position) - kit.xz(c.position)
					local at = kit.xz(v.root.Position) - (toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(1, 0, 0)) * (CONFIG.chaseReachStuds - 1)
					c.model:PivotTo(CFrame.new(at.X, c.position.Y, at.Z))
				end
				grab(c, v)
				st.grabChaseStartedAt = c.now
				return
			end
			-- 다가간다(보스 이동 속도 × chaseSpeedMultiplier - 수평)
			local speed = (c.data.moveSpeedStuds or 8) * CONFIG.chaseSpeedMultiplier
			local from = c.model:GetPivot().Position
			local dir = kit.xz(v.root.Position) - kit.xz(from)
			local step = math.min(speed * (st.dt or 1 / 30), math.max(dir.Magnitude - (CONFIG.chaseReachStuds - 1), 0))
			if dir.Magnitude > 1e-3 then
				local to = from + dir.Unit * step
				c.model:PivotTo(CFrame.lookAt(to, to + dir.Unit))
			end
			return
		end
		if st.phase == "grabHold" then
			if c.now < st.phaseEndsAt then
				return
			end
			st.grabThrown += #st.grabHeld
			throwAll(c)
			kit.send(st, "grabEnd", { stunned = false })
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		clearMarks(c)
		releaseAll(c, "reset")
	end,
}

-- ─────────────────────────── 풀림 ───────────────────────────
-- 자동 해제 = 던짐(피해는 풀리기 직전에 넣었다). 발버둥 · 구출 · 도발 = 그 사람만 탈출(BR1-4a - 전원 탈출이면 step이 기절로 넘어간다).
local function throw(player, record)
	local model = record.context and record.context.bossModel
	local st = model and MonsterState.getBossPatternState(model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (st and root) then
		return
	end
	local c = { model = model, st = st, data = st.context and st.context.data, now = os.clock() }
	if not c.data then
		return
	end
	local away, distance = throwPlan(model, root)
	local feet = root.Position - Vector3.new(0, ROOT_ABOVE_FEET, 0)
	local v = { player = player, root = root, feet = feet, groundFeet = feet }
	-- escape: 넉백 상한 · 착지 경계를 거치지 않는다 - 맵 밖으로 날아가면 기존 복귀(본인 스폰 + 보호)가 받는다
	kit.runHitEffects(c, { { type = "launch", heightStuds = CONFIG.throw.heightStuds, distanceStuds = distance, escape = true } }, v, root.Position - away * 5, 1)
	kit.debugEvent("grabThrow", { player = player, distance = distance, at = c.now })
	print(("[forge-game] 대공 잡기 던짐: %s - 거리 %.0f"):format(tostring(player.Name), distance))
end

BossTrap.onReleased(function(player, record, reason)
	if record.kind ~= "grabbed" then
		return
	end
	local model = record.context and record.context.bossModel
	local held = model and grabsByModel[model]
	if held then
		held[player] = nil
	end
	local st = model and MonsterState.getBossPatternState(model)
	if reason == "auto" then
		throw(player, record)
	elseif st then
		-- BR1-4b 리뷰 1: 퇴장 · 리셋("reset")도 잡힘 목록에서 뺀다(남으면 전원 탈출 기절이 안 나고 새 캐릭터가 머리 위로 끌려간다). 탈출 수는 구출 · 발버둥만 센다.
		if reason == "rescued" or reason == "escaped" then
			st.grabEscaped = (st.grabEscaped or 0) + 1
		elseif st.grabHeld and table.find(st.grabHeld, player) then
			st.grabThrown = (st.grabThrown or 0) + 1 -- 파트 0 리뷰 2: 퇴장 · 리셋은 탈출이 아니다 - "전원 탈출" 기절 조건에서 뺀다(던짐처럼 센다)
		end
		local at = st.grabHeld and table.find(st.grabHeld, player)
		if at then
			table.remove(st.grabHeld, at)
		end
		if st.grabGauges then
			st.grabGauges[player] = nil
		end
	end
	if st and kit then
		kit.send(st, "grabRelease", { userId = realPlayer(player) and player.UserId or nil, reason = reason })
	end
	if realPlayer(player) and player.Parent then
		player:SetAttribute("BossGrabGauge", nil)
		player:SetAttribute("BossHoldSlot", nil)
	end
	local entry = handTargets[player]
	if entry then
		handTargets[player] = nil
		MonsterSpawner.removeRescueTarget(entry.model)
	end
end)

-- 잡은 손 = 때릴 수 있는 구출 대상(얼음 덩어리와 같은 엔티티 - 평타 · 스킬 · 투사체가 그대로 맞는다). 구출자 1인당 hitIntervalSeconds에 한 번, requiredHits번이면 풀린다.
local HAND_ASPECT = Vector3.new(1.2, 1.1, 2.4)

BossTrap.onTrapped(function(player, record)
	if record.kind ~= "grabbed" or not realPlayer(player) then -- 얼음(airFrozen)에는 손이 없다 - 손은 잡힌 순간에만
		return
	end
	local point = record.context and record.context.origin
	if not point then
		return
	end
	local config = CONFIG.rescueHits
	local entry = { lastHitAt = {} }
	handTargets[player] = entry
	entry.model = MonsterSpawner.spawnRescueTarget({
		displayName = "손",
		color = record.context.color or Color3.fromRGB(120, 110, 100),
		bodyAspect = HAND_ASPECT,
		footPosition = point - Vector3.new(0, ROOT_ABOVE_FEET + 1.5, 0),
		onHit = function(rescuer)
			local now = os.clock()
			local last = entry.lastHitAt[rescuer]
			if rescuer == player or (last and now - last < config.hitIntervalSeconds) then
				return
			end
			entry.lastHitAt[rescuer] = now
			BossTrap.addRescueProgress(player, rescuer, 1 / config.requiredHits)
		end,
		remaining = function()
			return 1 - (player:GetAttribute("BossTrapRescue") or 0)
		end,
	}, record.context.zoneKey)
end)

-- F 홀드(보스 곁 - BossData.mechanics.rescue.grab.reachStuds). 조각 없음 - 공통 홀드 규칙 그대로.
-- A2-M1(사용자 결정): 잡힌 사람 구출은 보스 정면에서만(Reach.inFront - 클라 프롬프트 · 바닥 안내와 같은 식)
BossTrap.registerRescueHandler("grab", {
	canHold = function(_, record, rescuer)
		local cfg = BossData.mechanics.rescue.grab
		local boss = record.context and record.context.bossModel
		local bossRoot = boss and boss.PrimaryPart
		local root = typeof(rescuer) == "Instance" and rescuer.Character and rescuer.Character:FindFirstChild("HumanoidRootPart")
		if not (bossRoot and root) then
			return true -- 보스 · 루트 없음(검증 스탠드인 등) = 옛 규칙
		end
		return Reach.inFront(bossRoot.CFrame, root.Position, cfg.frontHalfAngleDeg, cfg.frontReachStuds + BossData.mechanics.rescue.hold.reachSlackStuds)
	end,
})
BossTrap.registerRescueHandler("bubble", {}) -- BR1-2 공중 가둠: 곁에서 F 홀드(공통 규칙)

-- 발악: 잡힌 사람의 점프(클라 BossGrabView가 JumpRequest를 보낸다) = 게이지 하나를 1회 줄인다. 1인당 초당 maxPressesPerSecond회까지만 센다.
local lastPressAt = {}
function BossAirGrab.press(player)
	local record = BossTrap.getRecord(player)
	if not record or (record.kind ~= "grabbed" and record.kind ~= "bubbled") then
		return false
	end
	local now = os.clock()
	if realPlayer(player) and lastPressAt[player] and now - lastPressAt[player] < 1 / CONFIG.struggle.maxPressesPerSecond then
		return false
	end
	lastPressAt[player] = now
	if record.kind == "bubbled" then -- BR1-2 공중 가둠: 혼자 presses회 → 탈출(떨어진다 - 해제 유예 없음)
		record.context.pressed = (record.context.pressed or 0) + 1
		if realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", math.clamp(1 - record.context.pressed / record.context.presses, 0, 1))
		end
		if record.context.pressed >= record.context.presses then
			BossTrap.release(player, "escaped")
			if realPlayer(player) and player.Parent then
				player:SetAttribute("BossGrabGauge", nil)
				player:SetAttribute("BossHoldSlot", nil)
			end
		end
		return true
	end
	local model = record.context and record.context.bossModel
	local st = model and MonsterState.getBossPatternState(model)
	local g = st and st.grabGauges and st.grabGauges[player]
	if not g then
		return false
	end
	g.done += 1
	gaugeAttribute(st)
	if g.done >= g.need then
		BossTrap.release(player, "escaped") -- BR1-4a: 스스로 발버둥으로 탈출(그 사람만)
	end
	return true
end
struggleEvent.OnServerEvent:Connect(BossAirGrab.press)

Players.PlayerRemoving:Connect(function(player)
	lastPressAt[player] = nil
end)

-- 도발(성기사 - K 단계)이 들어오면 이 보스가 들고 있는 사람을 즉시 푼다 - 연결 고리만(BossPatterns.onTaunt가 부른다). 반환: 푼 사람 수.
function BossAirGrab.releaseByTaunt(model)
	local held = grabsByModel[model]
	local count = 0
	for player in pairs(held or {}) do
		if BossTrap.release(player, "rescued") then
			count += 1
		end
	end
	return count
end

-- 보스전 종료(처치 · 이탈)에 부른다 - 들고 있던 사람을 풀고 모델 참조를 지운다(리뷰 8).
function BossAirGrab.clear(model)
	local held = grabsByModel[model]
	grabsByModel[model] = nil
	for player in pairs(held or {}) do
		BossTrap.release(player, "reset")
	end
end

function BossAirGrab.register(handlers, patternKit)
	kit = patternKit
	handlers.grab = BossAirGrab.handler
end

-- 검증 · 하네스 전용
BossAirGrab.debug = { countedAir = function(...) return countedAir(...) end, throwPlan = function(...) return throwPlan(...) end }

return BossAirGrab
