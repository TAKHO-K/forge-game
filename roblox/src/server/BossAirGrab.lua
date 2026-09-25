-- BR1 대공 잡기 → BR1-2 개정(docs/design/boss-br1-2.md §3 - 6종 공통 규칙, 모션만 보스별). primitive = "grab" 핸들러 + 잡힘 종류 "airFrozen"(얼음) · "grabbed"(손).
-- 흐름(수치 = BossData.mechanics.airGrab):
--   시전(스킬 telegraphSeconds 5초): 보스 위 "점프하지 마" · 떠 있는 사람 머리 위 손바닥이 찬다 · 시전 시작 + noticeSeconds 뒤부터 센 연속 체공이 airSeconds를 넘는 순간 그 자리에 얼림
--   → 시전 끝: 얼린 사람이 없으면 끝. 있으면 가장 가까운 사람부터(잡는 순간 거리로 다시) 보스가 이동 속도 × chaseSpeedMultiplier로 다가가 잡는다 - 잡힌 사람은 보스 머리 위 둘레에 들려 따라간다
--   → 마지막 사람을 잡은 뒤 holdSeconds → 전원 던짐(보스별 던지는 모션 · 벽 앞까지) + 현재 체력 × currentHpFraction
--   발악: 잡힌 사람들의 점프 연타가 **게이지 하나**를 함께 줄인다(필요 횟수 = pressesBase + pressesPerExtra × (얼린 인원 − 1)) → 0이면 전원 풀림 + 보스 기절
--   구출(동료가 손 3타 · 곁에서 F 홀드) · 도발 → 같다(전원 풀림 + 기절). 잡기 동안 보스는 새 패턴을 고르지 않는다(스킬 진행 중) · 환경 변화는 따로 돈다.
--   공중 가둠(거품 · 회오리 - kind "bubbled")에 갇힌 사람은 "공중"이다 - 얼림 · 잡기로 이어진다(BR1-2 §4).
-- 판정 · 잡힘 · 던짐 발신은 서버, 손 모션 · 들림 · 던짐 물리는 클라(BossGrabView · 기존 BossStormView.launch).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossTrap = require(script.Parent.BossTrap)
local PlayerState = require(script.Parent.PlayerState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossArenaContainment = require(script.Parent.BossArenaContainment)
local HeightGuard = require(script.Parent.HeightGuard)
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

-- 시전 중 "센" 연속 체공 = min(실제 연속 체공, 시전 시작 + noticeSeconds부터 흐른 시간). 공중 가둠은 그 시간 내내 공중이다.
local function countedAir(c, player)
	local since = c.now - (c.st.grabStartedAt + CONFIG.noticeSeconds)
	if since <= 0 then
		return 0
	end
	if isBubbled(player) then
		return since
	end
	return math.min(kit.airSecondsOf(c.st, player, c.now), since)
end

local function markLevel(airSeconds)
	if airSeconds < CONFIG.warnAirSeconds then
		return 0
	end
	-- 0.25 단위로 끊어 보낸다(바뀔 때만 발신 - 매 틱 보내지 않는다).
	local level = math.clamp((airSeconds - CONFIG.warnAirSeconds) / (CONFIG.airSeconds - CONFIG.warnAirSeconds), 0, 1)
	return math.max(math.floor(level * 4 + 1e-6) / 4, 0.25)
end

local function sendMarks(c)
	local st = c.st
	st.grabMarks = st.grabMarks or {}
	for _, v in ipairs(kit.victims(st)) do
		local frozen = st.grabFrozen[v.player]
		local level = (frozen or (BossTrap.isTrapped(v.player) and not isBubbled(v.player))) and 0 or markLevel(kit.airSecondsOf(st, v.player, c.now))
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

-- 얼릴 수 있는가: 센 연속 체공 ≥ N · (진짜 사람은) 지면 거리까지 재도 떠 있다(가둠은 예외) · 무적 · 복귀 보호 아님 · 가둠 말고 다른 잡힘 아님 · 살아 있다.
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
	if countedAir(c, v.player) < CONFIG.airSeconds then
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
	print(("[forge-game] 대공 잡기: %s 얼림(센 체공 %.2f초)"):format(tostring(v.player.Name), air))
end

-- 들고 있는 자리: 보스 머리 위 둘레(index마다 90° 벌린다).
local function holdPoint(c, index)
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

local function gaugeAttribute(st)
	local left = st.grabGauge and math.clamp(1 - st.grabGauge.done / st.grabGauge.need, 0, 1) or nil
	for _, player in ipairs(st.grabHeld or {}) do
		if realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", left)
		end
	end
end

local function grab(c, v)
	local st, skill = c.st, c.skill
	st.grabFrozen[v.player] = nil
	local from = v.root.Position
	BossTrap.release(v.player, "chain") -- 얼음 → 손(유예 없음 - 바로 다음 잡힘)
	local index = #st.grabHeld + 1
	local point = holdPoint(c, index)
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
	local held = grabsByModel[c.model] or {}
	grabsByModel[c.model] = held
	held[v.player] = true
	HeightGuard.exempt(v.player, SAFETY_TRAP_SECONDS)
	setRootAt(v, point)
	gaugeAttribute(st)
	kit.send(st, "grabPick", {
		userId = realPlayer(v.player) and v.player.UserId or nil, from = from, point = point, liftSeconds = CONFIG.liftSeconds,
		bossId = c.data.id, motion = skill.motion, color = c.data.headColor, bossPosition = Vector3.new(c.position.X, st.floorY, c.position.Z),
		need = st.grabGauge.need,
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
		end
	end
	st.grabHeld = {}
end

local function beginStun(c, why)
	local st = c.st
	releaseAll(c, "rescued")
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
	local held = grabsByModel[c.model]
	grabsByModel[c.model] = nil
	for _, player in ipairs(st.grabHeld) do
		if realPlayer(player) and player.Parent then
			player:SetAttribute("BossGrabGauge", nil)
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
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.grabStartedAt = c.now
		st.grabMarks = {}
		st.grabRescued = false
		st.grabFrozen = {}
		st.grabFrozenCount = 0
		st.grabHeld = {}
		st.grabGauge = nil
		kit.send(st, "grabTelegraph", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds,
			bossId = c.data.id, motion = skill.motion, color = c.data.headColor, noJump = true,
			warnAirSeconds = CONFIG.warnAirSeconds, airSeconds = CONFIG.airSeconds, noticeSeconds = CONFIG.noticeSeconds,
		})
		sendMarks(c)
	end,
	step = function(c)
		local st = c.st
		if st.phase == "grabTelegraph" then
			-- 시전 내내: N초 넘게 뜬 사람은 그 순간 얼린다
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
				kit.endSkill(c.model, st, c.data, c.now)
				return
			end
			local struggle = CONFIG.struggle
			st.grabGauge = { need = struggle.pressesBase + struggle.pressesPerExtra * (st.grabFrozenCount - 1), done = 0 }
			st.phase = "grabChase"
			st.grabChaseStartedAt = c.now
			kit.debugEvent("grab", { count = st.grabFrozenCount, at = c.now, need = st.grabGauge.need })
			print(("[forge-game] 대공 잡기: %d명 얼림 → 가까운 순서로 잡으러 간다(발악 %d회)"):format(st.grabFrozenCount, st.grabGauge.need))
			return
		end
		if st.phase == "grabStun" then
			if c.now >= st.phaseEndsAt then
				kit.clearDaze(c.model, st)
				kit.endSkill(c.model, st, c.data, c.now)
			end
			return
		end
		-- 잡기 · 들고 있기 공통: 구출 · 발악 · 도발 → 전원 풀림 + 기절
		if st.grabRescued or (st.grabGauge and st.grabGauge.done >= st.grabGauge.need) then
			beginStun(c, st.grabRescued and "구출" or "발악")
			return
		end
		-- 들린 사람은 보스를 따라간다(손 = 구출 대상도 같이)
		for index, player in ipairs(st.grabHeld) do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local point = holdPoint(c, index)
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
-- 자동 해제 = 던짐(피해는 풀리기 직전에 넣었다). 구출 · 도발 = 그 보스가 기절한다(step이 grabRescued를 보고 grabStun으로 넘어간다).
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
	elseif reason == "rescued" and st then
		st.grabRescued = true
	end
	if st and kit then
		kit.send(st, "grabRelease", { userId = realPlayer(player) and player.UserId or nil, reason = reason })
	end
	if realPlayer(player) and player.Parent then
		player:SetAttribute("BossGrabGauge", nil)
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
BossTrap.registerRescueHandler("grab", {})
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
			end
		end
		return true
	end
	local model = record.context and record.context.bossModel
	local st = model and MonsterState.getBossPatternState(model)
	if not (st and st.grabGauge) then
		return false
	end
	st.grabGauge.done += 1
	gaugeAttribute(st)
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
