-- 프리즘 분열의 그리기(29-5, PRD 20.80 [C] - 수정 여왕: 대상 선택). 서버(BossPatterns의 gimmick 핸들러 - beginSplit)가
-- 보내는 splitStart·splitBreak·splitEnd만 그린다. 분신 자체는 서버의 타격 대상 엔티티라 여기서 만들지 않는다.
-- 색 언어는 25-4 그대로다:
--   · 넷 모두의 발밑 = **빨강 원**("여기에 손대면 맞는다" - 갑각 태세의 고리와 같은 뜻).
--   · 진짜의 원에서만 **흰 원이 안쪽에서 자란다**(흰색 = 남은 시간 - 낙석의 카운트다운과 같은 그림). 다 차면 파편 폭풍이다.
--     가짜의 원은 가만히 있다 - 구분은 색이 아니라 **움직임(자란다 / 가만히 있다)** 이라 색약에서도 같다. 흰 원은 빨강 위에
--     얹히므로 밝기로도 갈린다.
--   · 분신을 때렸다 = 그 원이 흰색으로 번쩍이고 사라진다 + 분신 → 때린 사람을 잇는 **흰 선**(임팩트 = 흰색. 갑각 반사와 같은
--     그림 - 왜 맞았는지가 선으로 이어진다).
-- 새 색·새 파티클·새 에셋 없음. 파트: 원 4 + 카운트다운 1 + 선 1 = ≤ 6(kit 클라 상한 20).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossSplitView = {}

local DANGER_COLOR = UIColors.danger
local IMPACT_COLOR = Color3.new(1, 1, 1)
local DISC_HEIGHT_STUDS = 0.2

local discs = {} -- [자리 번호] = Part
local countdown = nil

local function newDisc(center, radius, color, transparency, lift)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency
	part.Size = Vector3.new(DISC_HEIGHT_STUDS, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center + Vector3.new(0, lift, 0)) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = Workspace
	return part
end

function BossSplitView.clear()
	for _, part in pairs(discs) do
		part:Destroy()
	end
	discs = {}
	if countdown then
		countdown:Destroy()
		countdown = nil
	end
end

-- data = { spots(바닥 좌표 목록), realIndex, radius, seconds }
function BossSplitView.start(data)
	BossSplitView.clear()
	for index, spot in ipairs(data.spots) do
		discs[index] = newDisc(spot, data.radius, DANGER_COLOR, 0.45, 0.1)
	end
	local real = data.spots[data.realIndex]
	if real then
		countdown = newDisc(real, 0.5, IMPACT_COLOR, 0.25, 0.25)
		TweenService:Create(countdown, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(DISC_HEIGHT_STUDS, data.radius * 2, data.radius * 2),
		}):Play()
	end
	local mine = discs
	task.delay(data.seconds + 1, function() -- 서버의 splitEnd를 놓쳐도 남지 않게
		if discs == mine then
			BossSplitView.clear()
		end
	end)
end

-- data = { index(깨진 분신의 자리), to(때린 사람) }
function BossSplitView.breakDecoy(data)
	local disc = discs[data.index]
	if not disc then
		return
	end
	discs[data.index] = nil
	local from = Vector3.new(disc.Position.X, data.to.Y, disc.Position.Z)
	disc.Color = IMPACT_COLOR
	TweenService:Create(disc, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
	task.delay(0.35, function()
		disc:Destroy()
	end)
	local delta = data.to - from
	if delta.Magnitude > 0.5 then
		local beam = Instance.new("Part")
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = IMPACT_COLOR
		beam.Size = Vector3.new(0.6, 0.6, delta.Magnitude)
		beam.CFrame = CFrame.lookAt(from + delta / 2, data.to)
		beam.Parent = Workspace
		TweenService:Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		task.delay(0.35, function()
			beam:Destroy()
		end)
	end
end

return BossSplitView
