-- 보스 "태세"의 그리기(29-3, PRD 20.76 - 전갈 여왕의 갑각 태세). 서버(BossPatterns의 gimmick 핸들러)가 보내는
-- stanceStart·stanceEnd·reflectHit만 그린다. 색 언어는 25-4 그대로다:
--   · 태세 = 보스 몸을 감싼 **빨강 고리**("여기에 손대면 맞는다") - 고리가 있는 동안은 때리면 안 된다.
--   · 반사 = 보스 → 맞은 사람을 잇는 **흰 선** 한 줄 + 고리의 흰 번쩍임(임팩트 = 흰색). 왜 맞았는지가 선으로 이어진다.
--   · 꼬리가 박힌 뒤(때려도 되는 순간) = 고리가 **사라지고** 파랑 말풍선이 뜬다(BossPatternVisuals - 기회 = 파랑).
-- "있다 / 없다"로 갈리는 신호라 색약에서도 같다. 새 색·새 파티클·새 에셋 없음.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossStanceView = {}

local DANGER_COLOR = UIColors.danger
local IMPACT_COLOR = Color3.new(1, 1, 1)
local RING_SEGMENTS = 24
local RING_THICKNESS_STUDS = 1
local RING_HEIGHT_STUDS = 1.2

local ringParts = {}

local function newPart(size, color, transparency)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency
	part.Parent = Workspace
	return part
end

function BossStanceView.clear()
	for _, part in ipairs(ringParts) do
		part:Destroy()
	end
	ringParts = {}
end

-- data = { center(보스 발밑), radius, seconds }
function BossStanceView.start(data)
	BossStanceView.clear()
	local segmentLength = 2 * math.pi * data.radius / RING_SEGMENTS * 1.08
	for i = 1, RING_SEGMENTS do
		local angle = (i / RING_SEGMENTS) * 2 * math.pi
		local part = newPart(Vector3.new(segmentLength, RING_HEIGHT_STUDS, RING_THICKNESS_STUDS), DANGER_COLOR, 0.2)
		part.CFrame = CFrame.new(data.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * data.radius + Vector3.new(0, RING_HEIGHT_STUDS / 2, 0))
			* CFrame.Angles(0, -angle, 0)
		-- 고리가 숨쉬듯 깜빡인다 - 정지한 도형보다 "지금 켜져 있다"가 읽힌다(말풍선 그림 글자와 같은 기법).
		TweenService:Create(part, TweenInfo.new(0.375, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 }):Play()
		ringParts[i] = part
	end
	local parts = ringParts
	task.delay(data.seconds + 0.5, function() -- 서버의 stanceEnd를 놓쳐도 남지 않게
		if ringParts == parts then
			BossStanceView.clear()
		end
	end)
end

-- data = { from(보스), to(반사를 받은 사람) }
function BossStanceView.reflect(data)
	local from = Vector3.new(data.from.X, data.to.Y, data.from.Z)
	local delta = data.to - from
	if delta.Magnitude > 0.5 then
		local beam = newPart(Vector3.new(0.6, 0.6, delta.Magnitude), IMPACT_COLOR, 0)
		beam.CFrame = CFrame.lookAt(from + delta / 2, data.to)
		TweenService:Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		task.delay(0.35, function()
			beam:Destroy()
		end)
	end
	for _, part in ipairs(ringParts) do
		part.Color = IMPACT_COLOR
		task.delay(0.15, function()
			if part.Parent then
				part.Color = DANGER_COLOR
			end
		end)
	end
end

return BossStanceView
