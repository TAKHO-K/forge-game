-- BR1 대공 잡기(docs/design/boss-br1.md §2 - 6종 공통 규칙, 모션만 보스별). primitive = "grab" 핸들러 + 잡힘 종류 "grabbed"(구출 종류 "grab").
-- 흐름: 전조(telegraphSeconds - 큰 모션 · 아레나 전역 손바닥 · 떠 있는 사람 머리 위 작은 손바닥이 찬다)
--   → 판정: 그 순간 연속 체공 ≥ airGrab.airSeconds(N)인 사람 전원(무적 · 복귀 보호 · 이미 잡힌 사람 제외)
--   → 잡힘(BossTrap - 면역 · 행동 막힘 · 자동 해제 = holdSeconds): 보스 곁 공중(발 +holdLiftStuds)에 들려 고정
--   → 자동 해제(= 다 버텼다) = 던짐(기존 넉백 조각 launch - 높이 · 거리 상한 · 맵 밖이면 기존 복귀) + 현재 체력 × currentHpFraction
--   → 구출(동료가 손 3타 또는 곁에서 F 홀드) · 도발 = 풀림 + 보스 기절 stunSeconds(돌진 헤롱과 같은 그림)
--   발버둥: 잡힌 본인이 점프를 누를 때마다 남은 시간이 준다(RemoteEvent BossGrabStruggle - 초당 인정 횟수 상한 · 최소 유지 시간).
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

local BossAirGrab = {}

local CONFIG = BossData.mechanics.airGrab
local ROOT_ABOVE_FEET = 3 -- 루트 중심 = 발 + 3(HipHeight 2 + 루트 반높이 1)

local kit -- BossPatterns가 register로 넘긴다

local struggleEvent = Instance.new("RemoteEvent")
struggleEvent.Name = "BossGrabStruggle"
struggleEvent.Parent = ReplicatedStorage

local grabsByModel = {} -- [보스 Model] = { [Player] = true } - 지금 이 보스가 들고 있는 사람
local handTargets = {} -- [Player] = { model, lastHitAt = { [구출자] = os.clock } }

local function realPlayer(player)
	return typeof(player) == "Instance"
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
		local level = BossTrap.isTrapped(v.player) and 0 or markLevel(kit.airSecondsOf(st, v.player, c.now))
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

-- 잡을 수 있는가: 연속 체공 ≥ N · 지면 거리까지 재도 떠 있다 · 무적(복귀 보호 · 띄움 · 다른 무적)이 아니다 · 안 잡혔다 · 살아 있다.
local function grabbable(c, v)
	if BossTrap.isTrapped(v.player) or (PlayerState.getHp(v.player) or 0) <= 0 then
		return false
	end
	if PlayerState.isInvulnerable(v.player) or BossArenaContainment.isProtected(v.player) then
		return false
	end
	if kit.airSecondsOf(c.st, v.player, c.now) < CONFIG.airSeconds then
		return false
	end
	return not realPlayer(v.player) or kit.isAirborne(v.player.Character, 0.5)
end

local function holdPointFor(c, v, index, count)
	local origin = kit.xz(c.position)
	local toward = kit.xz(v.root.Position) - origin
	local dir = toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(1, 0, 0)
	if count > 1 then -- 여럿이면 보스 둘레로 벌린다
		local spread = math.rad((index - (count + 1) / 2) * 40)
		dir = (CFrame.fromAxisAngle(Vector3.yAxis, spread) * dir).Unit
	end
	local at = origin + dir * CONFIG.holdOffsetStuds
	return Vector3.new(at.X, c.st.floorY + CONFIG.holdLiftStuds + ROOT_ABOVE_FEET, at.Z)
end

local function beginStun(c)
	local st = c.st
	st.phase = "grabStun"
	st.phaseEndsAt = c.now + CONFIG.stunSeconds
	st.dazeBase = c.position
	c.model:PivotTo(CFrame.new(c.position - Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(25)))
	kit.send(st, "daze", { seconds = CONFIG.stunSeconds })
	kit.send(st, "grabEnd", { stunned = true })
	print(("[forge-game] 대공 잡기 해제 → 보스 기절 %.1f초"):format(CONFIG.stunSeconds))
end

BossAirGrab.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "grabTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.grabMarks = {}
		st.grabRescued = false
		kit.send(st, "grabTelegraph", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds,
			bossId = c.data.id, motion = skill.motion, color = c.data.headColor,
			warnAirSeconds = CONFIG.warnAirSeconds, airSeconds = CONFIG.airSeconds,
		})
		sendMarks(c)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "grabTelegraph" then
			sendMarks(c)
			if c.now < st.phaseEndsAt then
				return
			end
			local caught = {}
			for _, v in ipairs(kit.victims(st)) do
				if grabbable(c, v) then
					table.insert(caught, v)
				end
			end
			clearMarks(c)
			if #caught == 0 then
				kit.send(st, "grabMiss", {})
				kit.endSkill(c.model, st, c.data, c.now)
				return
			end
			local held = {}
			grabsByModel[c.model] = held
			local userIds, points = {}, {}
			for index, v in ipairs(caught) do
				local point = holdPointFor(c, v, index, #caught)
				local trapped = BossTrap.trap(v.player, {
					kind = skill.trap.kind, rescueType = skill.trap.rescueType, autoReleaseSeconds = CONFIG.holdSeconds,
					context = { origin = point, zoneKey = MonsterState.getZoneKey(c.model), bossModel = c.model, grab = true, color = c.data.headColor },
					onAutoRelease = function(player) -- 다 버텼다 = 던진다: 피해는 아직 잡힌 채로(풀린 뒤에는 해제 유예 무적이 막는다)
						PlayerDamage.applyCurrentHpFraction(player, CONFIG.currentHpFraction, skill.damageLabel)
						BossTrap.noteSkillHit(player)
					end,
				})
				if trapped then
					held[v.player] = true
					if typeof(v.root) == "Instance" then
						v.root.CFrame = CFrame.new(point) * v.root.CFrame.Rotation
					else
						v.root.Position = point
					end
					table.insert(userIds, realPlayer(v.player) and v.player.UserId or 0)
					table.insert(points, point)
				end
			end
			print(("[forge-game] 대공 잡기: %d명 잡힘(연속 체공 ≥ %.1f초)"):format(#points, CONFIG.airSeconds))
			kit.debugEvent("grab", { caught = caught, at = c.now })
			kit.send(st, "grabbed", { userIds = userIds, points = points, seconds = CONFIG.holdSeconds, bossId = c.data.id, motion = skill.motion, color = c.data.headColor })
			st.phase = "grabHold"
			st.phaseEndsAt = c.now + CONFIG.holdSeconds + 1 -- 안전장치(잡힘 기록이 사라지지 않았을 때)
			return
		elseif st.phase == "grabHold" then
			local held = grabsByModel[c.model]
			if held and next(held) ~= nil and c.now < st.phaseEndsAt then
				return
			end
			if held then -- 안전장치: 시간이 넘었는데 남아 있으면 자동 해제로 던진다(리뷰 8: 피해 조각도 같이 - 풀리기 직전)
				for player in pairs(held) do
					local record = BossTrap.getRecord(player)
					if record and record.onAutoRelease then
						record.onAutoRelease(player, record)
					end
					BossTrap.release(player, "auto")
				end
			end
			grabsByModel[c.model] = nil
			if st.grabRescued then
				beginStun(c)
				return
			end
			kit.send(st, "grabEnd", { stunned = false })
			kit.endSkill(c.model, st, c.data, c.now)
		elseif c.now >= st.phaseEndsAt then -- grabStun
			kit.clearDaze(c.model, st)
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		clearMarks(c)
		local held = grabsByModel[c.model]
		grabsByModel[c.model] = nil
		for player in pairs(held or {}) do
			BossTrap.release(player, "reset")
		end
	end,
}

-- ─────────────────────────── 풀림 ───────────────────────────
-- 자동 해제 = 던짐(피해는 풀리기 직전 onAutoRelease가 넣었다). 구출 · 도발 = 그 보스가 기절한다(grabHold가 모두 풀린 뒤 grabStun으로 넘어간다).
local function throw(player, record)
	local model = record.context and record.context.bossModel
	local st = model and MonsterState.getBossPatternState(model)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (st and root) then
		return
	end
	local angle = math.random() * 2 * math.pi
	local away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local c = { model = model, st = st, data = st.context and st.context.data, now = os.clock() }
	if not c.data then
		return
	end
	local feet = root.Position - Vector3.new(0, ROOT_ABOVE_FEET, 0)
	local v = { player = player, root = root, feet = feet, groundFeet = feet }
	kit.runHitEffects(c, { { type = "launch", heightStuds = CONFIG.throw.heightStuds, distanceStuds = CONFIG.throw.distanceStuds } }, v, root.Position - away * 5, 1)
	print(("[forge-game] 대공 잡기 던짐: %s"):format(tostring(player.Name)))
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
	local entry = handTargets[player]
	if entry then
		handTargets[player] = nil
		MonsterSpawner.removeRescueTarget(entry.model)
	end
end)

-- 잡은 손 = 때릴 수 있는 구출 대상(얼음 덩어리와 같은 엔티티 - 평타 · 스킬 · 투사체가 그대로 맞는다). 구출자 1인당 hitIntervalSeconds에 한 번, requiredHits번이면 풀린다.
local HAND_ASPECT = Vector3.new(1.2, 1.1, 2.4)

BossTrap.onTrapped(function(player, record)
	if record.rescueType ~= "grab" or not realPlayer(player) then
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

-- 발버둥: 잡힌 본인이 점프를 누를 때마다(클라 BossGrabView가 JumpRequest를 보낸다) 남은 시간 − secondsPerPress. 초당 maxPressesPerSecond회까지만 센다.
local lastPressAt = {}
struggleEvent.OnServerEvent:Connect(function(player)
	local record = BossTrap.getRecord(player)
	if not record or record.kind ~= "grabbed" then
		return
	end
	local now = os.clock()
	local struggle = CONFIG.struggle
	if lastPressAt[player] and now - lastPressAt[player] < 1 / struggle.maxPressesPerSecond then
		return
	end
	lastPressAt[player] = now
	BossTrap.shortenRelease(player, struggle.secondsPerPress, struggle.minHoldSeconds)
end)

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

return BossAirGrab
