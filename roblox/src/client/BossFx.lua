-- 보스 연출 조각(P3d A5 - 풀링 · 동시 상한 · 흔들림 설정). 판정 없음 - 파트는 전부 충돌 · 조준 · 터치 없음(서버 레이캐스트에 안 걸린다 · 클라에만 있다).
-- 조각 = 풀에서 꺼낸 파트 하나 + 시작값 · 끝값 · 수명. RenderStepped 하나가 살아 있는 조각을 전부 움직이고(트윈을 조각마다 만들지 않는다), 수명이 끝나면 풀로 돌려준다.
-- 동시 상한 BossFxData.maxActive를 넘는 요청은 버린다(연출이 빠질 뿐 - 판정은 서버). 숫자 · 상한 = shared/data/BossFxData.
--   spawn(spec)  spec = { shape("block"|"ball"|"cylinder"), position, velocity?, gravity?, size0, size1?, color, transparency0?, transparency1?, life, rotation?(CFrame), spin?(rad/초), material?, flat?(원판 - 크기 = 지름) }
--   puff · streak · ring · chunk  자주 쓰는 모양
--   shake(position, weight)  내 캐릭터가 가까우면 카메라를 짧게 흔든다(설정으로 끈다 - SettingBossScreenShake)
--   count(n, weight)  다른 멤버가 주인공인 효과의 조각 수(weight = BossFxData.otherPlayerWeight)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
local CameraShake = require(script.Parent.CameraShake)

local BossFx = {}

local player = Players.LocalPlayer
local folder = Instance.new("Folder")
folder.Name = "BossFx"
folder.Parent = Workspace

local pools = { block = {}, ball = {}, cylinder = {} }
local active = {} -- 배열: { part, shape, t0, life, p0, v, g, size0, size1, tr0, tr1, rotation, spin, flat }
local stats = { spawned = 0, dropped = 0, peak = 0, created = 0 }

local SHAPES = { block = Enum.PartType.Block, ball = Enum.PartType.Ball, cylinder = Enum.PartType.Cylinder }

local function newPart(shape)
	local part = Instance.new("Part")
	part.Name = "BossFxPiece"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Shape = SHAPES[shape]
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	stats.created += 1
	return part
end

local function acquire(shape)
	local pool = pools[shape]
	local part = table.remove(pool)
	if not part then
		part = newPart(shape)
	end
	part.Parent = folder
	return part
end

local function release(entry)
	local pool = pools[entry.shape]
	if #pool < BossFxData.poolKeep then
		entry.part.Parent = nil
		table.insert(pool, entry.part)
	else
		entry.part:Destroy()
	end
end

function BossFx.count(n, weight)
	return math.max(1, math.floor(n * (weight or 1) + 0.5))
end

function BossFx.spawn(spec)
	if #active >= BossFxData.maxActive then
		stats.dropped += 1
		return nil
	end
	local part = acquire(spec.shape or "block")
	part.Material = spec.material or Enum.Material.SmoothPlastic
	part.Color = spec.color or Color3.new(1, 1, 1)
	part.Transparency = spec.transparency0 or 0
	local entry = {
		part = part, shape = spec.shape or "block", t0 = os.clock(), life = spec.life or 0.4,
		p0 = spec.position, v = spec.velocity or Vector3.zero, g = spec.gravity or 0,
		size0 = spec.size0, size1 = spec.size1 or spec.size0, tr0 = spec.transparency0 or 0, tr1 = spec.transparency1 or 1,
		rotation = spec.rotation or CFrame.identity, spin = spec.spin or 0, flat = spec.flat,
	}
	table.insert(active, entry)
	stats.spawned += 1
	stats.peak = math.max(stats.peak, #active)
	return entry
end

-- 덩어리 먼지(카툰 - 공이 부풀며 옅어진다).
function BossFx.puff(position, size, color, life, drift)
	return BossFx.spawn({ shape = "ball", position = position, velocity = drift, size0 = Vector3.one * size * 0.55, size1 = Vector3.one * size,
		color = color, transparency0 = BossFxData.impact.dustTransparency, transparency1 = 1, life = life })
end

-- 속도선 · 바람 줄기(얇은 흰 막대가 dir로 밀려나며 사라진다).
function BossFx.streak(from, dir, length, thickness, color, life, speed)
	local unit = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	return BossFx.spawn({ shape = "block", position = from + unit * length / 2, velocity = unit * (speed or 0),
		size0 = Vector3.new(thickness, thickness, length), size1 = Vector3.new(thickness * 0.3, thickness * 0.3, length * 1.3),
		rotation = CFrame.lookAt(Vector3.zero, unit).Rotation, color = color, transparency0 = 0.15, transparency1 = 1, life = life, material = Enum.Material.Neon })
end

-- 바닥에 퍼지는 고리(원판 - 지름 r0 → r1).
function BossFx.ring(center, r0, r1, color, life, transparency)
	return BossFx.spawn({ shape = "cylinder", flat = true, position = center, size0 = Vector3.new(0.12, r0 * 2, r0 * 2), size1 = Vector3.new(0.12, r1 * 2, r1 * 2),
		rotation = CFrame.Angles(0, 0, math.rad(90)), color = color, transparency0 = transparency or 0.2, transparency1 = 1, life = life, material = Enum.Material.Neon })
end

-- 튀는 파편(중력 · 회전).
function BossFx.chunk(position, velocity, size, color, life)
	return BossFx.spawn({ shape = "block", position = position, velocity = velocity, gravity = Workspace.Gravity * 0.5, size0 = Vector3.one * size, size1 = Vector3.one * size * 0.6,
		rotation = CFrame.Angles(math.random() * 6, math.random() * 6, 0), spin = 8, color = color, transparency0 = 0, transparency1 = 0.6, life = life })
end

-- ─────────────────────────── 흔들림(A2 - 로컬 · 약하게 · 끌 수 있게) ───────────────────────────
function BossFx.shakeEnabled()
	return BossFxData.shake.enabled and player:GetAttribute("SettingBossScreenShake") ~= false
end

-- 설정창(F6 예정)이 부를 자리 - 지금은 Attribute만 쓴다.
function BossFx.setShakeEnabled(enabled)
	player:SetAttribute("SettingBossScreenShake", enabled == true)
end

-- position에서 가까울수록 세게(nearStuds 밖이면 없음). weight = 배율(돌진 대상이 나면 chargeTargetBonus).
function BossFx.shake(position, weight)
	if not BossFx.shakeEnabled() then
		return false
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local cfg = BossFxData.shake
	local d = (root.Position - position).Magnitude
	if d > cfg.nearStuds then
		return false
	end
	CameraShake.trigger(cfg.seconds, cfg.amplitudeStuds * (1 - d / cfg.nearStuds) * (weight or 1))
	return true
end

function BossFx.clear()
	for i = #active, 1, -1 do
		release(active[i])
		active[i] = nil
	end
end

function BossFx.stats()
	return { active = #active, spawned = stats.spawned, dropped = stats.dropped, peak = stats.peak, created = stats.created,
		pooled = #pools.block + #pools.ball + #pools.cylinder }
end

RunService.RenderStepped:Connect(function()
	if #active == 0 then
		return
	end
	local now = os.clock()
	local i = 1
	while i <= #active do
		local e = active[i]
		local t = now - e.t0
		local alpha = t / e.life
		if alpha >= 1 then
			release(e)
			active[i] = active[#active]
			active[#active] = nil
		else
			local ease = 1 - (1 - alpha) * (1 - alpha) -- 빠르게 부풀고 천천히 멈춘다(카툰 여운)
			local position = e.p0 + e.v * t - Vector3.new(0, 0.5 * e.g * t * t, 0)
			local part = e.part
			part.Size = e.size0:Lerp(e.size1, ease)
			part.Transparency = e.tr0 + (e.tr1 - e.tr0) * alpha
			local rotation = e.rotation
			if e.spin ~= 0 then
				rotation = rotation * CFrame.Angles(e.spin * t, e.spin * t * 0.7, 0)
			end
			part.CFrame = CFrame.new(position) * rotation
			i += 1
		end
	end
end)

return BossFx
