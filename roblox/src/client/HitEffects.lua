-- 피격·사망 반응(14-2). 몬스터 9마리가 동시에 맞고 죽는 게 정상 시나리오라(지시 사항),
-- 타격마다 Instance.new/Destroy를 하지 않는다 - 고정 개수 파트를 미리 만들어 두고
-- 라운드로빈으로 재사용한다(풀링). TweenService는 같은 인스턴스의 같은 프로퍼티를
-- 다시 Play()하면 이전 트윈을 자동으로 덮어써서 별도 취소 로직이 필요 없다.
--
-- 풀 크기 근거(숫자로): "9마리 동시" 시나리오 + 여유 3개 = 12. 이펙트 하나의 수명이
-- 0.18~0.4초로 짧아(아래 DURATION 상수) 실제로 동시에 "재생 중"인 이펙트가 12개를
-- 넘는 상황은 광역 스킬이 생기기 전까지는 거의 없다 - 넘어서도 라운드로빈이라 오래된
-- 이펙트를 새 이펙트가 밀어내는 것뿐(끊긴 채로 재생되는 정도)이라 에러는 안 난다.
-- 파트 12개(Neon Ball, 메시 없음)는 모바일 기준으로도 무시할 수준이다 - 이 사냥터에
-- 이미 상시 존재하는 파트가 몬스터 9마리×3파트(Root·Body·Head)=27개인데 그 절반도 안
-- 된다.

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArtV1FxData = require(ReplicatedStorage.Shared.data.ArtV1FxData) -- A2-N2 2-4 타격 링(ArtStyleV1 스위치 뒤)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArtV1Fx = require(script.Parent.ArtV1Fx)

local HitEffects = {}

local POOL_SIZE = 12
local pool = {}
local poolIndex = 0

local NORMAL_COLOR = Color3.fromRGB(255, 250, 210)
local NORMAL_DURATION = 0.18
local NORMAL_MAX_SIZE = 1.6

local CRIT_COLOR = Color3.fromRGB(255, 90, 30)
local CRIT_DURATION = 0.26
local CRIT_MAX_SIZE = 2.6

local DEATH_COLOR_FALLBACK = Color3.fromRGB(255, 240, 200)
local DEATH_DURATION = 0.35
local DEATH_MAX_SIZE = 3.2

local FLASH_COLOR = Color3.new(1, 1, 1)
local FLASH_BACK_SECONDS = 0.15

for i = 1, POOL_SIZE do
	local part = Instance.new("Part")
	part.Name = "HitBurst"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Parent = Workspace
	pool[i] = part
end

local function nextSlot()
	poolIndex = (poolIndex % POOL_SIZE) + 1
	return pool[poolIndex]
end

local function burst(position, color, maxSize, duration)
	local part = nextSlot()
	part.Color = color
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Position = position
	part.Transparency = 0.1

	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(maxSize, maxSize, maxSize),
		Transparency = 1,
	}):Play()
end

-- 몬스터 반응 - 색만 순간 바꾼다(밀림/넉백은 일부러 뺐다: Root/Body/Head는 서버
-- MonsterAI.server.lua가 매 프레임 위치를 되돌려 놓으므로, 클라이언트에서 CFrame을
-- 건드리면 다음 서버 리플리케이션에 즉시 덮어써져 흔들리거나 안 보일 위험이 크다.
-- Color3는 서버가 손대지 않는 프로퍼티라 이 충돌이 없다).
--
-- holdSeconds(16-7, 3타 강타 전용) - 흰 플래시를 곧바로 되돌리지 않고 그만큼 붙들었다가
-- 되돌린다. 몬스터는 서버가 매 프레임 위치를 되돌리는 파트라 CFrame으로 "멈췄다"를
-- 표현할 수 없으니(위 주석), 색 되돌림을 지연시키는 것으로 피격자 쪽 히트스톱을 흉내낸다.
-- QUEUE-ALL2 P4 ②(09 B-2 "맞은 몹 흰 번쩍임 0.06초 · 작은 뒤로 밀림 - 보이는 것만"): 아트 켬 = 몸 전체 Highlight 흰 채움 0.06초 + 루트 관절 C0를 내 반대쪽으로 0.3 stud 0.1초(전조 포즈 중이면 건너뜀).
--   판정 · 서버 위치 불변(로컬 C0만 · 끝나면 원래 값). 아트 끔 = 옛 동작 그대로.
local HIT_FLASH = { hold = 0.06, back = 0.06, fill = 0.25 }
local PUSH = { studs = 0.3, out = 0.05, back = 0.1 }
local pushing = setmetatable({}, { __mode = "k" })
local function artHitFeel(monsterModel)
	local hl = monsterModel:FindFirstChild("HitFlash")
	if not hl then
		hl = Instance.new("Highlight")
		hl.Name = "HitFlash"
		hl.FillColor = Color3.new(1, 1, 1)
		hl.OutlineTransparency = 1
		hl.DepthMode = Enum.HighlightDepthMode.Occluded
		hl.FillTransparency = 1
		hl.Parent = monsterModel
	end
	hl.FillTransparency = HIT_FLASH.fill
	task.delay(HIT_FLASH.hold, function()
		if hl.Parent then
			TweenService:Create(hl, TweenInfo.new(HIT_FLASH.back), { FillTransparency = 1 }):Play()
		end
	end)
	if monsterModel:GetAttribute("MobWindup") or pushing[monsterModel] then
		return -- 전조 포즈 중 = 밀지 않는다(전조 읽기 우선)
	end
	local joint = monsterModel:FindFirstChild("RootJoint", true)
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not (joint and joint:IsA("Motor6D") and joint.Part0 and root) then
		return
	end
	local away = joint.Part0.Position - root.Position
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude < 0.01 then
		return
	end
	local localDir = joint.Part0.CFrame:VectorToObjectSpace(away.Unit * PUSH.studs)
	local base = joint.C0
	pushing[monsterModel] = true
	TweenService:Create(joint, TweenInfo.new(PUSH.out, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = CFrame.new(localDir) * base }):Play()
	task.delay(PUSH.out, function()
		local tw = TweenService:Create(joint, TweenInfo.new(PUSH.back, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { C0 = base })
		tw.Completed:Connect(function()
			pushing[monsterModel] = nil
		end)
		tw:Play()
	end)
end

local function flashMonster(monsterModel, holdSeconds)
	if ArtV1Fx.isOn() and monsterModel:FindFirstChild("RootJoint", true) then
		artHitFeel(monsterModel)
		return
	end
	for _, partName in ipairs({ "Body", "Head" }) do
		local part = monsterModel:FindFirstChild(partName)
		if part then
			local originalColor = part.Color
			part.Color = FLASH_COLOR
			task.delay(holdSeconds or 0, function()
				TweenService:Create(part, TweenInfo.new(FLASH_BACK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Color = originalColor,
				}):Play()
			end)
		end
	end
end

-- 일반/치명타 둘 다 이 진입점 하나 - 크기·색·지속시간만 다르다(치명타가 더 크고 진한
-- 색, 숫자 크기·폰트 구분과 같은 원칙). holdSeconds는 3타 강타 히트스톱 동안 플래시를
-- 붙들어 두는 시간(AttackInput.client.lua가 넘긴다) - 없으면 즉시 되돌아간다(기존 동작).
function HitEffects.playHit(monsterModel, isCrit, holdSeconds)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	local art = ArtV1Fx.isOn()
	if isCrit then
		burst(head.Position, art and ArtV1FxData.combat.critCore or CRIT_COLOR, CRIT_MAX_SIZE, CRIT_DURATION)
	else
		burst(head.Position, NORMAL_COLOR, NORMAL_MAX_SIZE, NORMAL_DURATION)
	end
	if art then
		-- A2-N2 2-4 통일: 옆으로 퍼지는 링(카메라를 향함) = 타격 · 일반 = 직업 강조색 · 치명 = 금노랑(주황빨강 = 보스 경고색이라 아군 치명에서 뺐다) · 강공격 = 한 겹 더
		local K = ArtV1FxData.combat
		local classId = Players.LocalPlayer:GetAttribute("ClassId")
		local accent = UIColors.classAccent[classId or ""] or NORMAL_COLOR
		if monsterModel:GetAttribute("BossRig") then -- QUEUE-ALL2 P4 ④: 보스 = 내 파티원 색(파티일 때 - 이름표 · 파티 창과 같은 색)
			accent = require(script.Parent.PartyColors).of(Players.LocalPlayer) or accent
		end
		local camera = Workspace.CurrentCamera
		local face = camera and CFrame.lookAt(head.Position, camera.CFrame.Position) or CFrame.new(head.Position)
		local ring = ArtV1Fx.ring(head.Position, isCrit and K.critRingSize or K.hitRingSize, K.hitRingSeconds, isCrit and K.critRim or accent, K.ringThick, 0.1)
		ring.CFrame = face * CFrame.Angles(0, math.rad(90), 0) -- 원기둥 높이 축(X)을 카메라 쪽으로
		if holdSeconds and holdSeconds > 0 then
			local outer = ArtV1Fx.ring(head.Position, K.heavyRingSize, K.heavyRingSeconds, accent, K.ringThick, 0.2)
			outer.CFrame = ring.CFrame
		end
	end
	flashMonster(monsterModel, holdSeconds)
end

-- 사망 연출 - 큰 버스트(색은 몬스터 Body 색을 그대로 재사용, "이 몬스터가 터졌다"는
-- 인상) + Body/Head를 그 자리에서 줄어들며 사라지게 한다(위치는 그대로 두고 크기·
-- 투명도만 바꾼다 - Body/Head가 서로 다른 절대 위치를 갖고 있어(머리는 몸통 위 2.3stud
-- 고정) 자리를 다시 계산해 옮기려 하지 않는다, 그러면 "흩어짐"이 아니라 "겹쳐짐"이
-- 될 위험이 있다). MonsterSpawner.despawn이 damageNumberLifetimeSeconds(0.8초) 뒤에
-- 실제로 Destroy하므로, 이 연출(0.35초)이 그 안에 여유 있게 끝난다.
-- QUEUE-ALL2 P4 ③ 로켓단식(09 B-2 클립 순간): 마무리 강공격 · 치명 처치면 내 화면에서만 몸을 복제해 하늘로 날린다(포물선 · 회전) → 꼭대기에서 "반짝" 별빛과 함께 사라짐.
--   원본은 LocalTransparencyModifier로 숨김(서버 모델 · 드랍 · 판정 그대로 - 드랍은 원래 자리). 아트 켬 · 연출 세기 끔이 아닐 때만. 수치 = LAUNCH(연출 전용).
local LAUNCH = { seconds = 0.7, away = 30, up = 60, gravity = 20, spinDeg = 720, sparkleSeconds = 0.3, sparkleStuds = 7 }
local function hideLocally(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("BillboardGui") then
			d.Enabled = false
		end
	end
end
local function sparkle(at)
	for i = 0, 1 do
		local p = Instance.new("Part")
		p.Name = "LaunchStar"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 244, 200)
		p.Size = Vector3.new(0.4, LAUNCH.sparkleStuds * 0.2, 0.4)
		p.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(45 + i * 90))
		p.Parent = Workspace
		local tw = TweenService:Create(p, TweenInfo.new(LAUNCH.sparkleSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, LAUNCH.sparkleStuds, 0.15), Transparency = 1 })
		tw.Completed:Connect(function()
			p:Destroy()
		end)
		tw:Play()
	end
	pcall(function()
		require(script.Parent.SoundSheet).play("reward_fly", { volume = 0.8 })
	end)
end
function HitEffects.launch(monsterModel)
	local fx = Players.LocalPlayer:GetAttribute("FxScale")
	if not ArtV1Fx.isOn() or fx == 0 or not monsterModel or not monsterModel.Parent then
		return false
	end
	local me = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local okClone, clone = pcall(function()
		monsterModel.Archivable = true
		return monsterModel:Clone()
	end)
	if not okClone or not clone or not me then
		return false
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	clone.Name = "LaunchedMonster"
	local start = monsterModel:GetPivot()
	local away = start.Position - me.Position
	away = Vector3.new(away.X, 0, away.Z)
	away = away.Magnitude > 0.01 and away.Unit or Vector3.new(0, 0, -1)
	local axis = away:Cross(Vector3.yAxis)
	clone.Parent = Workspace
	hideLocally(monsterModel)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= LAUNCH.seconds or not clone.Parent then
			conn:Disconnect()
			local at = clone.Parent and clone:GetPivot().Position
			clone:Destroy()
			if at then
				sparkle(at)
			end
			return
		end
		local pos = start.Position + away * LAUNCH.away * t + Vector3.yAxis * (LAUNCH.up * t - LAUNCH.gravity * t * t)
		clone:PivotTo(CFrame.new(pos) * CFrame.fromAxisAngle(axis.Magnitude > 0 and axis.Unit or Vector3.xAxis, math.rad(LAUNCH.spinDeg * t)) * start.Rotation)
	end)
	return true
end

function HitEffects.playDeath(monsterModel, launch)
	if launch and HitEffects.launch(monsterModel) then
		return
	end
	local body = monsterModel and monsterModel:FindFirstChild("Body")
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not body then
		return
	end

	burst(body.Position, body.Color or DEATH_COLOR_FALLBACK, DEATH_MAX_SIZE, DEATH_DURATION)
	if monsterModel:GetAttribute("ArtV1") then
		return -- A2-S 아트 샘플 몸체: 쓰러짐(데굴 + 흐려짐)은 client/ArtV1View가 모든 사람 화면에서 같게 그린다
	end

	for _, part in ipairs({ body, head }) do
		if part then
			TweenService:Create(part, TweenInfo.new(DEATH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(0.05, 0.05, 0.05),
				Transparency = 1,
			}):Play()
		end
	end
end

return HitEffects
