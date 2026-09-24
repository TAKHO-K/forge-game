-- 폭풍 군주의 낙뢰 연출(29-3). 서버(BossPatterns)가 보내는 사실만 그린다.
--   · bolt: 하늘에서 낙하점으로 꽂히는 번개 - 꺾인 흰 선(임팩트 = 흰색, 25-4 색 언어 그대로). 파트 몇 개뿐이고 0.25초에 사라진다.
--   · launch: 낙뢰에 **내가** 맞았을 때 팝콘처럼 튕겨 난다. 캐릭터 물리는 이 클라 소유라 여기서 속도를 준다 - 서버는 "맞았다"만
--     알린다(20-2a의 돌진 이동과 같은 신뢰 모델). 높이·거리는 서버 데이터(BossData strike.onHit)에서 온다: 높이 5stud는 판정의
--     높이차 상한(8)·아레나 벽(12)보다 낮아 보스가 대상을 놓치지 않고 맵 밖으로도 못 나간다.
--   · 29-4 회오리(launch에 holdSeconds가 실려 온다 - 같은 결과 조각의 파라미터만 늘었다): 그 자리에서 heightStuds까지 떠올라
--     회오리 중심 둘레(spinRadiusStuds)를 돌다가 내려온다. 몸은 세로축으로만 돈다(구르지 않는다). **뜬 동안 카메라는 도는
--     캐릭터가 아니라 회오리 중심에 묶는다** - 캐릭터를 따라가면 화면 전체가 흔들린다(모바일 멀미). 끝나면 내려앉을 자리로
--     카메라를 먼저 옮긴 뒤 캐릭터에게 돌려준다(화면이 튀지 않게).
--   · 29-4 피뢰침: 충전되면 파랑으로 빛난다(파랑 = 기회, 25-4). 서버의 정적 kit 파트를 이 클라에서만 칠한다 - 서버는 "언제까지
--     충전인가"만 안다. 두 개가 다 차면(zoneDischarge) 흰색으로 번쩍이고 원래 색으로 돌아간다.
-- 새 색·새 파티클·새 에셋 없음.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- P3c A5: 넉백 높이 · 거리 상한과 착지 경계(벽에서 containment.innerMarginStuds 안쪽) - 서버 계측과 같은 함수다.
local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment)

local BossStormView = {}

local IMPACT_COLOR = Color3.new(1, 1, 1)
local BOLT_HEIGHT_STUDS = 60
local BOLT_SEGMENTS = 6
local BOLT_JITTER_STUDS = 4
local BOLT_THICKNESS_STUDS = 0.8

local OPPORTUNITY_COLOR = Color3.fromRGB(120, 200, 255) -- BossPatternVisuals의 헤롱 말풍선·BossTrapView의 구출 막대와 같은 값
local ROD_NAME = "LightningRod" -- BossData stormKitParts의 파트 이름
local LIFT_RISE_SECONDS = 0.3
local LIFT_TURNS_PER_SECOND = 0.75 -- 도는 빠르기(1.5초에 한 바퀴 남짓 - 빠르면 어지럽다)
local WHIRL_BANDS = 10

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

-- 회오리의 그림: 흰 띠 몇 개가 나선으로 돌며 솟는다(임팩트 = 흰색). seconds 뒤에 사라진다.
function BossStormView.whirl(position, radius, seconds)
	seconds = seconds or 1.8
	local bands = {}
	for index = 1, WHIRL_BANDS do
		local band = Instance.new("Part")
		band.Anchored = true
		band.CanCollide = false
		band.CanQuery = false
		band.CanTouch = false
		band.CastShadow = false
		band.Material = Enum.Material.Neon
		band.Color = IMPACT_COLOR
		band.Transparency = 0.35
		band.Size = Vector3.new(0.4, 0.4, radius * 0.5)
		band.Parent = Workspace
		bands[index] = band
	end
	local startedAt = os.clock()
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - startedAt
		if t >= seconds then
			connection:Disconnect()
			for _, band in ipairs(bands) do
				band:Destroy()
			end
			return
		end
		for index, band in ipairs(bands) do
			local alpha = index / WHIRL_BANDS
			local angle = alpha * math.pi * 4 + t * math.pi * 3
			local r = radius * (0.25 + 0.35 * alpha)
			local at = position + Vector3.new(math.cos(angle) * r, 1 + alpha * 9, math.sin(angle) * r)
			band.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(angle), 0.15, math.cos(angle)))
			band.Transparency = 0.35 + 0.65 * math.max((t - (seconds - 0.4)) / 0.4, 0)
		end
	end)
end

-- 회오리에 뜬다. data = { from(회오리 중심 - 서버가 벽에서 spinRadius만큼 안쪽으로 잘라 보낸다), heightStuds, holdSeconds, spinRadiusStuds }
local function lift(data, root, humanoid)
	local camera = Workspace.CurrentCamera
	local center = Vector3.new(data.from.X, root.Position.Y, data.from.Z)
	local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
	local startRadius = offset.Magnitude
	local startAngle = startRadius > 0.1 and math.atan2(offset.Z, offset.X) or rng:NextNumber(0, 2 * math.pi)
	local total = LIFT_RISE_SECONDS + data.holdSeconds

	-- 카메라의 기준점: 보이지 않는 고정 파트. 지금 캐릭터 자리에서 회오리 중심으로 옮겨 가고(뜨는 0.3초), 거기 머문다.
	local anchor = Instance.new("Part")
	anchor.Name = "BossWhirlCameraAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = root.Position
	anchor.Parent = Workspace
	TweenService:Create(anchor, TweenInfo.new(LIFT_RISE_SECONDS, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { Position = center }):Play()
	if camera then
		camera.CameraSubject = anchor
	end

	humanoid.PlatformStand = true
	local startedAt = os.clock()
	local connection
	local function finish(landing)
		connection:Disconnect()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		-- 내려앉을 자리로 카메라를 먼저 옮기고(떨어지는 동안) 캐릭터에게 돌려준다.
		local fallSeconds = math.sqrt(2 * data.heightStuds / Workspace.Gravity)
		TweenService:Create(anchor, TweenInfo.new(fallSeconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Position = landing }):Play()
		task.delay(fallSeconds + 0.05, function()
			if humanoid.Parent then
				humanoid.PlatformStand = false
				if camera and camera.CameraSubject == anchor then
					camera.CameraSubject = humanoid
				end
			end
			anchor:Destroy()
		end)
	end
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - startedAt
		-- 도중에 죽었거나 잡혔으면(서버가 루트를 고정한다) 바로 놓는다.
		if t >= total or not root.Parent or humanoid.Health <= 0 or root.Anchored then
			finish(Vector3.new(root.Position.X, center.Y, root.Position.Z))
			return
		end
		local rise = math.min(t / LIFT_RISE_SECONDS, 1)
		local radius = startRadius + (data.spinRadiusStuds - startRadius) * rise
		local angle = startAngle + t * LIFT_TURNS_PER_SECOND * 2 * math.pi
		local position = center + Vector3.new(math.cos(angle) * radius, data.heightStuds * rise, math.sin(angle) * radius)
		root.CFrame = CFrame.new(position) * CFrame.Angles(0, -angle, 0)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end)
end

-- data = { from(판정 중심), heightStuds, distanceStuds, holdSeconds?, spinRadiusStuds?, zoneCenter?, zoneRadius? }
function BossStormView.launch(data)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored then
		return
	end
	if data.holdSeconds then
		-- P3c A5(리뷰 5): 회오리도 넉백 높이 상한을 거친다(수평은 제자리 + 중심을 서버가 벽 안쪽으로 잘라 보낸다).
		local capped = table.clone(data)
		capped.heightStuds = select(1, ArenaContainment.limitLaunch(nil, root.Position, Vector3.zero, data.heightStuds, 0))
		lift(capped, root, humanoid)
		return
	end
	local away = Vector3.new(root.Position.X - data.from.X, 0, root.Position.Z - data.from.Z)
	if away.Magnitude < 0.5 then -- 한가운데서 맞았으면 아무 방향으로나
		local angle = rng:NextNumber(0, 2 * math.pi)
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	-- P3c A5: 높이 · 거리 상한 + 착지점이 벽 안쪽 경계를 넘지 않게 거리를 줄인다(구역이 실려 오지 않으면 상한만).
	local zone = data.zoneRadius and { center = data.zoneCenter, radius = data.zoneRadius } or nil
	local heightStuds, distanceStuds = ArenaContainment.limitLaunch(zone, root.Position, away, data.heightStuds, data.distanceStuds)
	-- 포물선: 최고 높이 h = v² ÷ 2g, 체공 = 2v ÷ g, 그동안 수평으로 distance.
	local gravity = Workspace.Gravity
	local up = math.sqrt(2 * gravity * math.max(heightStuds, 0.5))
	local airSeconds = 2 * up / gravity
	local velocity = away.Unit * (distanceStuds / airSeconds) + Vector3.new(0, up, 0)

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

-- ─────────────────────────── 피뢰침(29-4) ───────────────────────────

local charged = {} -- [part] = { color, material, token }

local function findRod(center)
	for _, part in ipairs(Workspace:GetChildren()) do
		if part.Name == ROD_NAME and math.abs(part.Position.X - center.X) < 1 and math.abs(part.Position.Z - center.Z) < 1 then
			return part
		end
	end
	return nil
end

local function restoreRod(part)
	local entry = charged[part]
	if entry then
		charged[part] = nil
		if part.Parent then
			part.Color = entry.color
			part.Material = entry.material
		end
	end
end

-- data = zoneCharge 이벤트 { center, seconds } - seconds 동안 파랑으로 빛난다(다시 충전되면 시계가 새로 돈다).
function BossStormView.chargeRod(data)
	local part = findRod(data.center)
	if not part then
		return
	end
	local entry = charged[part] or { color = part.Color, material = part.Material }
	entry.token = (entry.token or 0) + 1
	charged[part] = entry
	part.Material = Enum.Material.Neon
	part.Color = OPPORTUNITY_COLOR
	local token = entry.token
	task.delay(data.seconds, function()
		if charged[part] == entry and entry.token == token then
			restoreRod(part)
		end
	end)
end

-- flash = true: 두 피뢰침이 다 찼다 - 흰색으로 번쩍이고 방전된다. false: 조용히 끈다(리셋·보스전 종료).
function BossStormView.dischargeRods(flash)
	for part in pairs(charged) do
		if flash and part.Parent then
			part.Color = IMPACT_COLOR
			task.delay(0.3, function()
				restoreRod(part)
			end)
		else
			restoreRod(part)
		end
	end
end

return BossStormView
