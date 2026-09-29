-- A2-N2 클라 VFX 조각(ArtStyleV1 스위치 뒤 연출이 같이 쓴다 - 드랍 · 레벨업 · 부화 · 환생 · 강화 실패 · 치장 · 전투 링). 값 = shared/data/ArtV1FxData.
--   폰 예산(§5-1): 동시 입자 수를 세어(Emit 수 · rate × 수명) 상한을 넘으면 새 연출의 입자를 남은 몫까지 줄인다 · Beam 수도 센다.
--   모든 파트 = Anchored · 충돌 · 조회 · 그림자 없음 · Workspace.ArtV1Fx 폴더(한 화면 정리 · 스트리밍과 무관한 클라 전용).
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData)

local B = FxData.budget
local Fx = {}
local isStudio = game:GetService("RunService"):IsStudio()

-- Studio 캡처용 슬로모션 배율(ReplicatedStorage Attribute ArtV1FxSlow - ArtV1View와 같은 값 · 실제 게임은 항상 1)
function Fx.slow()
	return isStudio and tonumber(ReplicatedStorage:GetAttribute("ArtV1FxSlow")) or 1
end

local live = { particles = 0, beams = 0 }
Fx.live = live -- 검증 · 개발 확인용(읽기만)

function Fx.isOn()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

function Fx.reduceFlashes()
	return Players.LocalPlayer:GetAttribute("ReduceFlashes") == true
end

local function folder()
	local f = Workspace:FindFirstChild("ArtV1Fx")
	if not f then
		f = Instance.new("Folder")
		f.Name = "ArtV1Fx"
		f.Parent = Workspace
	end
	return f
end

-- 입자 몫 빌리기: 원하는 수 → 줄 수 있는 수(0 가능) · seconds 뒤 반납. 보스전 중이면 bossParticleScale배.
function Fx.reserve(want, seconds)
	if Players.LocalPlayer:GetAttribute("BossEncounterId") ~= nil then
		want = math.floor(want * B.bossParticleScale)
	end
	local n = math.clamp(want, 0, math.max(0, B.particles - live.particles))
	if n > 0 then
		live.particles += n
		task.delay(seconds, function()
			live.particles -= n
		end)
	end
	return n
end

-- 상시 이미터용(rate × 수명): 켤 때 빌리고 release()로 돌려준다
function Fx.hold(want)
	local n = math.clamp(want, 0, math.max(0, B.particles - live.particles))
	live.particles += n
	local released = false
	return n, function()
		if not released then
			released = true
			live.particles -= n
		end
	end
end

function Fx.holdBeam()
	if live.beams >= B.beams then
		return false, function() end
	end
	live.beams += 1
	local released = false
	return true, function()
		if not released then
			released = true
			live.beams -= 1
		end
	end
end

function Fx.part(name, size, color, cf, shape, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Ball
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.CFrame = cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = folder()
	return p
end

-- 흰 번쩍 공: 커지며 사라진다
function Fx.flash(pos, size, seconds, color)
	seconds *= Fx.slow()
	local p = Fx.part("ArtV1Flash", Vector3.one * 0.4, color or Color3.new(1, 1, 1), CFrame.new(pos))
	p.Transparency = 0.1
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	Debris:AddItem(p, seconds + 0.05)
end

-- 바닥 링(납작한 원기둥): 퍼지며 사라진다
function Fx.ring(pos, size, seconds, color, thick, startTransparency)
	seconds *= Fx.slow()
	thick = thick or 0.12
	local p = Fx.part("ArtV1Ring", Vector3.new(thick, 1, 1), color, CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
	p.Transparency = startTransparency or 0.15
	TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(thick, size, size), Transparency = 1 }):Play()
	Debris:AddItem(p, seconds + 0.05)
	return p
end

-- 한 번에 뿜는 입자(예산 적용). o = { color, size, speed, spread, gravity, lifetime = {a, b}, dir = NormalId, texture, lightEmission, drag }
function Fx.burst(pos, count, o)
	local life = o.lifetime or { 0.45, 0.9 }
	local n = Fx.reserve(count, life[2])
	if n <= 0 then
		return 0
	end
	local holder = Fx.part("ArtV1Emitter", Vector3.one * 0.1, o.color, CFrame.new(pos))
	holder.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(life[1], life[2])
	e.Speed = NumberRange.new(o.speed * 0.6, o.speed)
	e.SpreadAngle = Vector2.new(o.spread or 30, o.spread or 30)
	e.EmissionDirection = o.dir or Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -(o.gravity or 0), 0)
	e.Drag = o.drag or 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.size), NumberSequenceKeypoint.new(1, o.sizeEnd or 0) })
	e.Transparency = o.transparency or NumberSequence.new(0)
	e.Color = ColorSequence.new(o.color)
	e.LightEmission = o.lightEmission or 1
	e.TimeScale = 1 / Fx.slow()
	if o.texture then
		e.Texture = o.texture
	end
	e.Parent = holder
	e:Emit(n)
	Debris:AddItem(holder, life[2] * Fx.slow() + 0.1)
	return n
end

-- 솟는 빛기둥(Beam · 아래 진하고 위로 투명): 솟음 → 흐려지며 가늘어짐
function Fx.pillar(pos, o)
	o = table.clone(o)
	o.seconds *= Fx.slow()
	local ok, release = Fx.holdBeam()
	if not ok then
		return
	end
	local host = Fx.part("ArtV1Pillar", Vector3.one * 0.1, o.color, CFrame.new(pos))
	host.Transparency = 1
	local a0 = Instance.new("Attachment")
	a0.Parent = host
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.2, 0)
	a1.Parent = host
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.FaceCamera = true
	beam.Segments = 1
	beam.LightEmission = 0.5 -- 1(가산)은 블룸과 겹쳐 색이 흰색으로 날아갔다(Play 2 - 환생 보라 · 부화 등급 색)
	beam.Color = ColorSequence.new(o.color)
	beam.Width0, beam.Width1 = o.width, o.topWidth or o.width * 0.5
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = host
	local rise = TweenService:Create(a1, TweenInfo.new(o.seconds * 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = Vector3.new(0, o.height, 0) })
	rise.Completed:Connect(function()
		local steps = 12
		for i = 1, steps do
			task.delay(o.seconds * 0.7 * i / steps, function()
				if beam.Parent then
					local f = i / steps
					beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05 + 0.95 * f), NumberSequenceKeypoint.new(0.5, 0.45 + 0.55 * f), NumberSequenceKeypoint.new(1, 1) })
					beam.Width0 = o.width * (1 - 0.6 * f)
				end
			end)
		end
	end)
	rise:Play()
	task.delay(o.seconds + 0.05, function()
		host:Destroy()
		release()
	end)
end

-- 짧은 화면 반짝임(섬광 줄이기 켜면 없음)
function Fx.screenFlash(brightness, seconds)
	if Fx.reduceFlashes() then
		return
	end
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "ArtV1ScreenFlash"
	grade.Brightness = brightness
	grade.Parent = Lighting
	local back = TweenService:Create(grade, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 })
	back.Completed:Connect(function()
		grade:Destroy()
	end)
	back:Play()
end

-- 캐릭터 발밑(지면 위 0.1)
function Fx.feetOf(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not root then
		return nil
	end
	local down = (hum and hum.HipHeight or 2) + root.Size.Y / 2
	return root.Position - Vector3.new(0, down - 0.1, 0)
end

return Fx
