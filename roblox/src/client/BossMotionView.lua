-- 보스 모션(P3d A1 · A2 · A4 - 카툰 연출, 판정 없음). 서버 보스 모델은 그대로 움직이고(떠오름 · 돌진 = 서버 PivotTo - 판정 위치), 이 클라는 그 모델을 **로컬에서만** 숨기고
-- (LocalTransparencyModifier) 같은 모양의 복제 인형을 서버 모델의 피벗에 붙여 과장된 모션(늘어남 · 찌그러짐 · 예비 동작 · 여운)과 팔 · 꼬리 · 지팡이를 그린다.
-- 인형은 매 프레임 서버 모델 피벗을 따라가므로 보스가 있는 자리는 서버와 같다. 모션이 끝나면 인형을 치우고 서버 모델을 다시 보인다.
-- 스타일 = BossFxData.bosses[보스 id].slam · charge(아래 SLAM · 빌더 표의 키 - 보스 이름이 들어간 함수는 없다).
--   slamWindup(shockTelegraph) → 크게 들어 올린다(windupFraction) → 꼭대기에서 멈칫(holdFraction) → 내려찍는다 → slamImpact(shockwave 첫 겹) = 납작 + 풍압(방사형 먼지 · 바람 줄기 · 흰 고리) + 가까우면 흔들림
--   chargeWindup(focus) → 발 긁기(뒤로 젖혀 흔들며 뒤쪽으로 흙을 찬다) · chargeRun(charge) → 앞으로 늘어나 달린다 + 속도선 · 잔상 · 먼지 꼬리 → 도착 = 강한 임팩트
--   잠행(charge = "burrow")은 인형 없이 먼지만(몸은 서버가 땅속에 숨긴다).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local BossFx = require(script.Parent.BossFx)

local BossMotionView = {}

local player = Players.LocalPlayer
local DUST_COLOR = Color3.fromRGB(235, 228, 214) -- 흙먼지(BossArenaMapView와 같은 값)
local WHITE = Color3.new(1, 1, 1)
local STAFF_COLOR = Color3.fromRGB(90, 70, 50) -- 지팡이 자루(나무)
local rng = Random.new()

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function easeOut(t)
	return 1 - (1 - t) ^ 3
end

local function easeIn(t)
	return t * t * t
end

-- 여운: 넘쳤다가 돌아온다(카툰).
local function easeOutBack(t)
	local c = 1.7
	return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
end

local function findBoss(near)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		local root = model.PrimaryPart
		if root and not CollectionService:HasTag(model, "RescueTarget") then
			local d = Vector3.new(root.Position.X - near.X, 0, root.Position.Z - near.Z).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

-- ─────────────────────────── 인형 ───────────────────────────
local puppet = nil -- { model, folder, clones = { { src, clone, offset, size } }, extras = { { part, place } }, bottom, unit, style, phase, t0, T, ... }

local function newExtra(p, shape, size, color, material)
	local part = BossFx.acquirePart(shape)
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Parent = p.folder
	return part
end

local function disposePuppet()
	local p = puppet
	if not p then
		return
	end
	puppet = nil
	for part, modifier in pairs(p.hidden) do
		if part.Parent then
			part.LocalTransparencyModifier = modifier
		end
	end
	for _, extra in ipairs(p.extras) do
		BossFx.releasePart(extra.part, extra.shape)
	end
	for _, ghost in ipairs(p.ghosts or {}) do
		ghost.folder:Destroy()
	end
	p.folder:Destroy()
end

local function buildPuppet(model)
	if puppet and puppet.model == model then
		return puppet
	end
	disposePuppet()
	local pivot = model:GetPivot()
	local folder = Instance.new("Model")
	folder.Name = "BossPuppet"
	local p = { model = model, folder = folder, clones = {}, extras = {}, hidden = {}, bottom = math.huge }
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
			local clone = part:Clone()
			clone:ClearAllChildren()
			clone.Anchored = true
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Parent = folder
			local offset = pivot:ToObjectSpace(part.CFrame)
			table.insert(p.clones, { src = part, clone = clone, offset = offset, size = part.Size })
			p.bottom = math.min(p.bottom, offset.Position.Y - part.Size.Y / 2)
			p.hidden[part] = part.LocalTransparencyModifier
			part.LocalTransparencyModifier = 1
		end
	end
	if #p.clones == 0 then
		folder:Destroy()
		return nil
	end
	local body = model:FindFirstChild("Body")
	p.unit = body and math.max(body.Size.X, body.Size.Z) or 3 -- 몸 폭(stud) - 팔 · 꼬리 · 지팡이 크기의 잣대
	local head = model:FindFirstChild("Head")
	p.headColor = head and head.Color or WHITE
	p.bodyColor = body and body.Color or WHITE
	folder.Parent = Workspace
	puppet = p
	return p
end

-- pose = { sx, sy, sz, lean(뒤로 − · 앞으로 +, rad), yaw(rad), raise(0 ~ 1 - 팔 · 지팡이 들기), swing(꼬리 회전 rad) }
local function applyPose(p, pose)
	local pivot = p.model:GetPivot()
	-- lean > 0 = 앞(−Z, LookVector 쪽)으로 숙인다: X축 회전 −lean이면 위쪽이 −Z로 기운다.
	local base = pivot * CFrame.new(0, p.bottom, 0) * CFrame.Angles(-(pose.lean or 0), pose.yaw or 0, 0)
	for _, c in ipairs(p.clones) do
		local position = c.offset.Position
		local rel = Vector3.new(position.X * pose.sx, (position.Y - p.bottom) * pose.sy, position.Z * pose.sz)
		c.clone.CFrame = base * CFrame.new(rel) * c.offset.Rotation
		c.clone.Size = c.size * Vector3.new(pose.sx, pose.sy, pose.sz)
	end
	for _, extra in ipairs(p.extras) do
		extra.place(base, pose)
	end
	p.lastBase = base
end

-- ─────────────────────────── 찍기 스타일(A1) - 팔 · 꼬리 · 지팡이 ───────────────────────────
local SLAM = {}

-- 두 손 내려찍기: 주먹 둘이 옆구리 → 머리 위(raise 1) → 앞바닥(raise 0 · 찍은 뒤)
function SLAM.twoFistSlam(p)
	local u = p.unit
	for _, side in ipairs({ -1, 1 }) do
		local fist = newExtra(p, "block", Vector3.new(0.55, 0.55, 0.55) * u, p.headColor)
		table.insert(p.extras, { part = fist, shape = "block", place = function(base, pose)
			local raise = pose.raise or 0
			local height = lerp(0.45, 2.1, raise) * u * pose.sy
			local forward = lerp(-0.55, 0.1, raise) * u -- 찍을 때(raise 0으로 떨어질 때) 앞으로
			local spread = lerp(0.75, 0.35, raise) * u
			fist.CFrame = base * CFrame.new(side * spread, height, forward) * CFrame.Angles(raise * 0.6, 0, side * raise * 0.3)
		end })
	end
end

-- 꼬리 휘두르기: 등 뒤 꼬리(쐐기 셋)가 뒤로 감겼다가(raise 1) 찍는 순간 한 바퀴(swing) 휘둘러 바닥을 쓴다
function SLAM.tailSwipe(p)
	local u = p.unit
	for k = 1, 3 do
		local seg = newExtra(p, "block", Vector3.new(0.5 - k * 0.1, 0.35, 0.7) * u, k == 3 and p.headColor or p.bodyColor)
		table.insert(p.extras, { part = seg, shape = "block", place = function(base, pose)
			local curl = (pose.raise or 0) * 0.5 * k
			local angle = (pose.swing or 0) + math.pi -- 기본 = 등 뒤(+Z가 앞이면 뒤는 π)
			local reach = (0.45 + 0.55 * k) * u
			local dir = Vector3.new(math.sin(angle + curl), 0, -math.cos(angle + curl))
			seg.CFrame = base * CFrame.new(dir * reach + Vector3.new(0, lerp(0.35, 0.9, pose.raise or 0) * u, 0)) * CFrame.Angles(0, -(angle + curl), 0)
		end })
	end
end

-- 지팡이 찍기: 옆구리 지팡이를 머리 위로 치켜들어(끝이 번쩍) 앞바닥에 꽂는다
function SLAM.staffStrike(p)
	local u = p.unit
	local shaft = newExtra(p, "cylinder", Vector3.new(2.6 * u, 0.18 * u, 0.18 * u), STAFF_COLOR)
	local tip = newExtra(p, "ball", Vector3.new(0.45, 0.45, 0.45) * u, p.headColor, Enum.Material.Neon)
	table.insert(p.extras, { part = shaft, shape = "cylinder", place = function(base, pose)
		local raise = pose.raise or 0
		-- 들 때 뒤로 젖혀 머리 위(각 −70°) → 찍을 때 앞으로(+35°) 꽂는다
		local tilt = math.rad(lerp(35, -70, raise))
		local grip = base * CFrame.new(0.7 * u, lerp(0.9, 2.0, raise) * u * pose.sy, 0) * CFrame.Angles(tilt, 0, 0)
		shaft.CFrame = grip * CFrame.new(0, 0.6 * u, 0) * CFrame.Angles(0, 0, math.rad(90)) -- 원기둥 로컬 X = 길이
		tip.CFrame = grip * CFrame.new(0, 1.9 * u, 0)
		tip.Transparency = raise > 0.9 and (rng:NextNumber() < 0.5 and 0 or 0.4) or 0.2 -- 꼭대기에서 번쩍
	end })
	table.insert(p.extras, { part = tip, shape = "ball", place = function() end })
end

function SLAM.hopLand(_p)
	-- 늘어남 · 찌그러짐만
end

-- ─────────────────────────── 시간표 ───────────────────────────
local function slamPose(p, t)
	local T = p.T
	local w, h = BossFxData.windupFraction * T, BossFxData.holdFraction * T
	local S, Q = BossFxData.stretch, BossFxData.squash
	local pose
	if t < w then
		local a = easeOut(t / w)
		pose = { sy = lerp(1, S, a), lean = -0.22 * a, raise = a, swing = 0 }
	elseif t < w + h then
		local jitter = math.sin(t * 60) * 0.02
		pose = { sy = S + jitter, lean = -0.22 + jitter, raise = 1, swing = 0 }
	else
		local a = easeIn(math.clamp((t - w - h) / math.max(T - w - h, 1e-3), 0, 1))
		pose = { sy = lerp(S, Q, a), lean = lerp(-0.22, 0.28, a), raise = 1 - a, swing = a * 2 * math.pi }
	end
	-- 방금 찍은 뒤(다음 파동의 예비 동작이 바로 이어질 때)는 0.2초 동안 납작한 자세에서 섞어 든다
	if p.fromSquash and t < 0.2 then
		local b = t / 0.2
		pose.sy = lerp(Q, pose.sy, b)
		pose.lean = lerp(0.28, pose.lean, b)
	end
	pose.sx = 1 / math.sqrt(pose.sy)
	pose.sz = pose.sx
	return pose
end

local function recoverPose(t)
	local Q = BossFxData.squash
	local a = math.clamp(t / BossFxData.recoverSeconds, 0, 1)
	local sy = lerp(Q, 1, easeOutBack(a))
	return { sy = sy, sx = 1 / math.sqrt(math.max(sy, 0.3)), sz = 1 / math.sqrt(math.max(sy, 0.3)), lean = lerp(0.28, 0, easeOut(a)), raise = 0, swing = 2 * math.pi }
end

-- ─────────────────────────── 찍기(A1 · A2) ───────────────────────────
function BossMotionView.slamWindup(data)
	local model = findBoss(data.center)
	if not model then
		return
	end
	local wasRecovering = puppet and puppet.model == model and puppet.phase == "recover"
	local p = buildPuppet(model)
	if not p then
		return
	end
	if not p.style then
		local style = (BossFxData.bosses[data.bossId or ""] or {}).slam or BossFxData.defaultSlam
		p.style = style
		local builder = SLAM[style] or SLAM.hopLand
		builder(p)
	end
	p.phase = "windup"
	p.t0 = os.clock()
	p.T = math.max(data.seconds or 1.2, 0.3)
	p.fromSquash = wasRecovering
end

-- 풍압: 찍은 자리에서 방사형 먼지 · 바람 줄기 · 흰 고리 + 가까우면 흔들림. data = shockwave 이벤트(첫 겹).
function BossMotionView.slamImpact(data)
	local cfg = BossFxData.impact
	local center = data.center + Vector3.new(0, 0.2, 0)
	for k = 1, cfg.dustCount do
		local angle = (k / cfg.dustCount) * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		-- 먼지는 파동(18 ~ 36stud/초)보다 느리게 퍼진다 - 앞서 가는 빨강 파동 띠를 덮지 않는다
		BossFx.puff(center + dir * rng:NextNumber(0.3, 0.6) * cfg.dustRadius + Vector3.new(0, 0.6, 0), rng:NextNumber(cfg.dustSize[1], cfg.dustSize[2]), DUST_COLOR, cfg.dustSeconds, dir * 9 + Vector3.new(0, 1.2, 0))
	end
	for k = 1, cfg.streakCount do
		local angle = (k / cfg.streakCount) * 2 * math.pi + rng:NextNumber(-0.15, 0.15)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		BossFx.streak(center + dir * 4 + Vector3.new(0, rng:NextNumber(1.5, 3.5), 0), dir, rng:NextNumber(cfg.streakLength[1], cfg.streakLength[2]), cfg.streakThickness, WHITE, cfg.streakSeconds, 30)
	end
	BossFx.ring(center, 2, cfg.ringRadius, WHITE, cfg.ringSeconds, 0.25)
	BossFx.shake(center, 1)
	local p = puppet
	if p and p.phase == "windup" then
		p.phase = "recover"
		p.t0 = os.clock()
	end
end

-- ─────────────────────────── 돌진(A4) ───────────────────────────
local charge = nil -- { model, dir, style, phase, t0, T, nextScrape, nextStreak, nextGhost, nextTrail, weight, targetIsMe, endPosition, burrow }

local function ensureGhosts(p)
	if p.ghosts then
		return
	end
	p.ghosts = {}
	for index = 1, BossFxData.charge.ghostMax do
		local folder = Instance.new("Model")
		folder.Name = "BossGhost"
		local parts = {}
		for _, c in ipairs(p.clones) do
			local g = c.clone:Clone()
			g.Material = Enum.Material.Neon
			g.Color = WHITE
			g.Transparency = 1
			g.Parent = folder
			table.insert(parts, { ghost = g, clone = c.clone })
		end
		folder.Parent = Workspace
		p.ghosts[index] = { folder = folder, parts = parts, t0 = -math.huge }
	end
	p.ghostNext = 1
end

local function dropGhost(p)
	ensureGhosts(p)
	local ghost = p.ghosts[p.ghostNext]
	p.ghostNext = p.ghostNext % #p.ghosts + 1
	ghost.t0 = os.clock()
	for _, entry in ipairs(ghost.parts) do
		entry.ghost.CFrame = entry.clone.CFrame
		entry.ghost.Size = entry.clone.Size
	end
end

function BossMotionView.chargeWindup(data)
	local model = findBoss(data.bossPosition)
	if not model then
		return
	end
	local style = (BossFxData.bosses[data.bossId or ""] or {}).charge or "hoofScrape"
	local delta = data.endPosition - data.bossPosition
	local dir = Vector3.new(delta.X, 0, delta.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local targetIsMe = data.targetUserId ~= nil and data.targetUserId == player.UserId
	charge = { model = model, dir = dir, style = style, phase = "scrape", t0 = os.clock(), T = data.seconds or 1.5, nextScrape = 0, floorY = data.floorY,
		weight = (data.targetUserId == nil or targetIsMe) and 1 or BossFxData.otherPlayerWeight, targetIsMe = targetIsMe, burrow = data.burrow }
	if style ~= "burrow" and not data.burrow then
		local p = buildPuppet(model)
		if p then
			p.phase = "scrape"
			p.t0 = os.clock()
		end
	end
end

function BossMotionView.chargeRun(data)
	if not charge then
		return
	end
	charge.phase = "run"
	charge.t0 = os.clock()
	charge.T = math.max(data.durationSeconds or 0.5, 0.05)
	charge.endPosition = data.endPosition
	charge.crashed = data.crashed
	charge.nextStreak, charge.nextGhost, charge.nextTrail = 0, 0, 0
	if puppet and puppet.model == charge.model then
		puppet.phase = "run"
		puppet.t0 = os.clock()
	end
end

local function chargeImpact(c)
	local cfg = BossFxData.charge
	local at = Vector3.new(c.endPosition.X, (c.floorY or c.endPosition.Y - 2) + 0.4, c.endPosition.Z)
	local chunks = BossFx.count(cfg.impactChunks * (c.crashed and 1.5 or 1), c.weight)
	for k = 1, chunks do
		local angle = (k / chunks) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		BossFx.chunk(at + dir, dir * rng:NextNumber(6, 12) + Vector3.new(0, rng:NextNumber(14, 22), 0), rng:NextNumber(0.5, 0.9), DUST_COLOR:Lerp(Color3.new(0, 0, 0), 0.35), 0.6)
		BossFx.puff(at + dir * 2, rng:NextNumber(1.8, 2.8), DUST_COLOR, 0.55, dir * 8 + Vector3.new(0, 1, 0))
	end
	BossFx.ring(at, 2, cfg.impactRing * (c.crashed and 1.3 or 1), WHITE, 0.35, 0.15)
	BossFx.shake(at, (c.targetIsMe and BossFxData.shake.chargeTargetBonus or 1) * (c.crashed and 1.3 or 1))
	if puppet and puppet.model == c.model then
		puppet.phase = "recover"
		puppet.t0 = os.clock()
	end
end

local function stepCharge(now)
	local c = charge
	if not c then
		return
	end
	if not c.model.Parent then
		charge = nil
		return
	end
	local cfg = BossFxData.charge
	local t = now - c.t0
	local pivot = c.model:GetPivot()
	local feet = Vector3.new(pivot.Position.X, (c.floorY or pivot.Position.Y - 2) + 0.4, pivot.Position.Z)
	if c.phase == "scrape" then
		if t >= c.nextScrape then
			c.nextScrape = t + cfg.scrapeInterval
			for _ = 1, BossFx.count(cfg.scrapeDust, c.weight) do
				local side = Vector3.new(-c.dir.Z, 0, c.dir.X) * rng:NextNumber(-1.5, 1.5)
				BossFx.puff(feet - c.dir * 2.5 + side, rng:NextNumber(1, 1.8), DUST_COLOR, 0.45, -c.dir * rng:NextNumber(6, 10) + Vector3.new(0, 2.5, 0))
			end
		end
		if t > c.T + 0.5 then
			charge = nil -- 돌진이 안 왔다(중단)
			if puppet and puppet.model == c.model then
				puppet.phase = "recover"
				puppet.t0 = now
			end
		end
	elseif c.phase == "run" then
		if t >= c.nextStreak then
			c.nextStreak = t + cfg.streakInterval
			for _ = 1, BossFx.count(cfg.streakPerTick, c.weight) do
				local side = Vector3.new(-c.dir.Z, 0, c.dir.X) * rng:NextNumber(-3, 3)
				BossFx.streak(feet + side + Vector3.new(0, rng:NextNumber(0.5, 4), 0) - c.dir * 3, -c.dir, rng:NextNumber(cfg.streakLength[1], cfg.streakLength[2]), 0.18, WHITE, cfg.streakSeconds, 12)
			end
		end
		if t >= c.nextTrail then
			c.nextTrail = t + cfg.trailInterval
			BossFx.puff(feet - c.dir * 2, rng:NextNumber(cfg.trailSize[1], cfg.trailSize[2]), DUST_COLOR, 0.5, -c.dir * 3 + Vector3.new(0, 1.5, 0))
		end
		if puppet and puppet.model == c.model and t >= c.nextGhost then
			c.nextGhost = t + cfg.ghostInterval
			dropGhost(puppet)
		end
		if t >= c.T then
			chargeImpact(c)
			charge = nil
		end
	end
end

local function stepPuppet(now)
	local p = puppet
	if not p then
		return
	end
	if not p.model.Parent then
		disposePuppet()
		return
	end
	local t = now - (p.t0 or now)
	local pose
	if p.phase == "windup" then
		pose = slamPose(p, t)
		if t > p.T + 0.6 then -- 찍기가 안 왔다(중단) - 여운으로 끝낸다
			p.phase = "recover"
			p.t0 = now
		end
	elseif p.phase == "scrape" then
		local wobble = math.sin(t * 2 * math.pi / BossFxData.charge.scrapeInterval)
		pose = { sx = 1.05, sy = 1.04, sz = 0.92, lean = -0.16 + 0.07 * wobble }
	elseif p.phase == "run" then
		pose = { sx = 0.9, sy = 0.86, sz = 1.28, lean = 0.22 }
	else -- recover
		pose = recoverPose(t)
		if t >= BossFxData.recoverSeconds then
			disposePuppet()
			return
		end
	end
	-- 리뷰 8: 발 긁기 · 달리기는 돌진 방향으로 몸을 돌린다(서버는 돌진 중 모델을 돌리지 않는다 - 인형의 앞(−Z)을 돌진 방향에 맞춘다)
	if charge and charge.model == p.model and (p.phase == "scrape" or p.phase == "run") then
		local localDir = p.model:GetPivot():VectorToObjectSpace(charge.dir)
		pose.yaw = math.atan2(-localDir.X, -localDir.Z)
	end
	applyPose(p, pose)
	-- 잔상 희미해지기
	for _, ghost in ipairs(p.ghosts or {}) do
		local a = (now - ghost.t0) / BossFxData.charge.ghostSeconds
		local transparency = a >= 1 and 1 or lerp(BossFxData.charge.ghostTransparency, 1, a)
		for _, entry in ipairs(ghost.parts) do
			entry.ghost.Transparency = transparency
		end
	end
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	stepCharge(now)
	stepPuppet(now)
end)

function BossMotionView.reset()
	charge = nil
	disposePuppet()
end

function BossMotionView.debugState()
	return { puppet = puppet ~= nil, style = puppet and puppet.style, phase = puppet and puppet.phase, clones = puppet and #puppet.clones or 0, extras = puppet and #puppet.extras or 0,
		charge = charge ~= nil and charge.phase or nil }
end

return BossMotionView
