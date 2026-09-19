-- 폭풍 군주의 낙뢰 연출(29-3). 서버(BossPatterns)가 보내는 사실만 그린다.
--   · bolt: 하늘에서 낙하점으로 꽂히는 번개 - 꺾인 흰 선(임팩트 = 흰색, 25-4 색 언어 그대로). 파트 몇 개뿐이고 0.25초에 사라진다.
--   · launch: 낙뢰에 **내가** 맞았을 때 팝콘처럼 튕겨 난다. 캐릭터 물리는 이 클라 소유라 여기서 속도를 준다 - 서버는 "맞았다"만
--     알린다(20-2a의 돌진 이동과 같은 신뢰 모델). 높이·거리는 서버 데이터(BossData strike.onHit)에서 온다: 높이 5stud는 판정의
--     높이차 상한(8)·아레나 벽(12)보다 낮아 보스가 대상을 놓치지 않고 맵 밖으로도 못 나간다.
-- 새 색·새 파티클·새 에셋 없음.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossStormView = {}

local IMPACT_COLOR = Color3.new(1, 1, 1)
local BOLT_HEIGHT_STUDS = 60
local BOLT_SEGMENTS = 6
local BOLT_JITTER_STUDS = 4
local BOLT_THICKNESS_STUDS = 0.8

local rng = Random.new()
local player = Players.LocalPlayer

function BossStormView.bolt(position)
	local from = position + Vector3.new(0, BOLT_HEIGHT_STUDS, 0)
	for index = 1, BOLT_SEGMENTS do
		local alpha = index / BOLT_SEGMENTS
		local to = position + Vector3.new(0, BOLT_HEIGHT_STUDS * (1 - alpha), 0)
		if index < BOLT_SEGMENTS then -- 마지막 마디는 낙하점에 정확히 꽂힌다
			to += Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * BOLT_JITTER_STUDS
		end
		local segment = Instance.new("Part")
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Material = Enum.Material.Neon
		segment.Color = IMPACT_COLOR
		segment.Size = Vector3.new(BOLT_THICKNESS_STUDS, BOLT_THICKNESS_STUDS, (to - from).Magnitude)
		segment.CFrame = CFrame.lookAt((from + to) / 2, to)
		segment.Parent = Workspace
		TweenService:Create(segment, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transparency = 1 }):Play()
		task.delay(0.25, function()
			segment:Destroy()
		end)
		from = to
	end
end

-- data = { from(판정 중심), heightStuds, distanceStuds }
function BossStormView.launch(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	local away = Vector3.new(root.Position.X - data.from.X, 0, root.Position.Z - data.from.Z)
	if away.Magnitude < 0.5 then -- 한가운데서 맞았으면 아무 방향으로나
		local angle = rng:NextNumber(0, 2 * math.pi)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	-- 포물선: 최고 높이 h = v² ÷ 2g, 체공 = 2v ÷ g, 그동안 수평으로 distance.
	local gravity = Workspace.Gravity
	local up = math.sqrt(2 * gravity * data.heightStuds)
	local airSeconds = 2 * up / gravity
	local velocity = away.Unit * (data.distanceStuds / airSeconds) + Vector3.new(0, up, 0)

	-- 떠 있는 동안 Humanoid의 조작을 끈다 - 켜 두면 걷기 제어가 수평 속도를 곧바로 지워 "튕겨 난다"가 안 보인다.
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)) -- 팝콘처럼 구른다
	task.delay(airSeconds + 0.1, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

return BossStormView
