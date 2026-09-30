-- QUEUE-ALL1 ★0+ 자동 이동(사용자 제안 09-30 · 설계 승인): 길 안내(Wayfinder)가 그린 경로를 그대로 따라 걷는다(매 프레임 Humanoid:Move). 걷기만 - 자동 전투 없음.
--   대상 제한 = WorldMapData.guide.autoWalk.owners(관문 · 견습 사냥터 · 보스 선택 [여기로 안내]) - 사람 · 몬스터 · 승강기 등은 안 된다.
--   멈춤: 이동 입력(스틱 · WASD) · 점프 입력 · 처리 안 된 키 · 좌클릭(공격) · 스킬 · 대시 · 체력이 줄면(피격 - 허용한 절벽 낙하 피해는 제외) · 보스전 · 안내가 꺼지거나 바뀜 · 도착 ·
--     큰 절벽 앞(낙하 피해 > 최대 체력 × maxDropFraction - 작은 절벽은 뛰어내린다) · 끼임 한도.
--   끼임 대책: stuckSeconds 동안 stuckStuds 못 가면 점프 → jumpsBeforeRecompute번 뒤 경로 재계산 → maxRecomputes번 넘으면 멈춤 + 안내.
--   클라 이동만(서버 판정 · 속도 불변). AutoWalk.start() · stop(reason) · isActive() · changed(Event - active, reason).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local Wayfinder = require(script.Parent.Wayfinder)

local AutoWalk = {}

local A = WorldMapData.guide.autoWalk
local player = Players.LocalPlayer
local changed = Instance.new("BindableEvent")
AutoWalk.changed = changed.Event

local active, reasonText = false, nil
local moveTarget = nil -- 지금 걸어가는 점(BindToRenderStep이 매 프레임 그쪽으로 Move)
local expectFallUntil = -math.huge -- 허용한 절벽 낙하: 이 시각까지 체력 감소 = 낙하 피해(피격 아님)
local F = MovementConfig.fall
local selfJumpAt = -math.huge -- 자동 이동이 스스로 점프한 시각: Humanoid.Jump = true도 JumpRequest를 부른다(Play 실측 - 사람 점프로 오인해 멈춤)
local function selfJump(humanoid)
	selfJumpAt = os.clock()
	humanoid.Jump = true
end
local lastHealth, lastPos, lastProgressAt, jumps, recomputes, owner, goal = nil, nil, 0, 0, 0, nil, nil
AutoWalk.log = {} -- 검사용: 멈춤 기록 { reason, at, position }

local STOP_TEXT = {
	input = nil, -- 사람이 직접 움직임 · 버튼으로 끔 = 조용히 끔(input-move · input-key · input-jump · input-skill도 같음 - 표에 없으면 문구 없음)
	arrived = "도착했어요",
	damaged = "공격받아 자동 이동을 멈췄어요",
	boss = nil,
	route = nil,
	drop = "앞이 절벽이에요 - 직접 내려가 주세요",
	stuck = "길이 막혀 자동 이동을 멈췄어요",
	dead = nil,
}
AutoWalk.stopText = STOP_TEXT

-- 사람 이동 입력(스틱 · 조이스틱): 기본 조작 모듈의 GetMoveVector. 모듈 자리 = PlayerScripts 또는 StarterPlayer(엔진 버전마다 다름 - Play 실측 StarterPlayer).
--   틱 안에서 부르므로 절대 기다리지 않는다(FindFirstChild · 못 찾으면 키보드 · 게임패드 입력 감지만 - 아래 InputBegan · InputChanged).
local controls = nil
local function moveVector()
	if controls == nil then
		local module = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule") or game:GetService("StarterPlayer"):FindFirstChild("PlayerModule")
		local ok, c = pcall(function()
			return module and require(module):GetControls()
		end)
		controls = ok and c or false
	end
	return controls and controls:GetMoveVector() or Vector3.zero
end

local function humanoidAndRoot()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

-- 켤 수 있나(버튼 표시용): 안내가 보이고 · 허용 대상이고 · 경로가 있고 · 아직 도착 전이고 · 보스전이 아니고 · 살아 있음
function AutoWalk.canStart()
	local route, _, who = Wayfinder.route()
	local humanoid, root = humanoidAndRoot()
	local dest = Wayfinder.destination()
	local near = dest and root and (Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z)).Magnitude <= WorldMapData.guide.arriveStuds -- 이미 도착(버튼 숨김)
	return route ~= nil and not near and A.owners[who] == true and humanoid ~= nil and humanoid.Health > 0 and player:GetAttribute("BossEncounterId") == nil
end

function AutoWalk.isActive()
	return active
end

function AutoWalk.stop(reason)
	if not active then
		return
	end
	active = false
	reasonText = STOP_TEXT[reason]
	moveTarget = nil
	RunService:UnbindFromRenderStep("AutoWalkMove")
	local humanoid, root = humanoidAndRoot()
	if humanoid then
		humanoid:Move(Vector3.zero) -- 걷던 걸음을 제자리에서 끊는다
	end
	table.insert(AutoWalk.log, { reason = reason, at = os.clock(), position = root and root.Position })
	player:SetAttribute("AutoWalkStop", reason) -- 검사용(로컬 Attribute)
	changed:Fire(false, reason, reasonText)
end

function AutoWalk.start()
	if active or not AutoWalk.canStart() then
		return false
	end
	local humanoid, root = humanoidAndRoot()
	active, jumps, recomputes = true, 0, 0
	lastHealth, lastPos, lastProgressAt = humanoid.Health, root.Position, os.clock()
	owner = select(3, Wayfinder.route())
	goal = Wayfinder.destination()
	player:SetAttribute("AutoWalkStop", nil)
	-- 걷기 = 매 프레임 Humanoid:Move(방향 - 조작 모듈 뒤 순서 Input + 1). MoveTo도 되지만(실측 2초 19 stud) 8초 제한 · 틱마다 다시 부를 필요 없이 프레임마다 방향을 틀어 부드럽다.
	RunService:BindToRenderStep("AutoWalkMove", Enum.RenderPriority.Input.Value + 1, function()
		local h, r = humanoidAndRoot()
		if moveTarget and h and r then
			local d = Vector3.new(moveTarget.X - r.Position.X, 0, moveTarget.Z - r.Position.Z)
			h:Move(d.Magnitude > 0.2 and d.Unit or Vector3.zero, false)
		end
	end)
	changed:Fire(true)
	return true
end

-- 입력으로 멈춤: 처리 안 된 키 · 좌클릭(공격) · 점프 입력 · 스킬 · 대시
UserInputService.InputBegan:Connect(function(input, processed)
	if not active or processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.Keyboard or input.UserInputType == Enum.UserInputType.MouseButton1 then
		AutoWalk.stop("input-key")
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if active and input.KeyCode == Enum.KeyCode.Thumbstick1 and input.Position.Magnitude > 0.3 then
		AutoWalk.stop("input-pad")
	end
end)
UserInputService.JumpRequest:Connect(function()
	if active and os.clock() - selfJumpAt > A.selfJumpIgnoreSeconds then
		AutoWalk.stop("input-jump")
	end
end)
task.spawn(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("SkillSlotsGui", 30)
	local cast = gui and gui:WaitForChild("SkillCastLocal", 30)
	if cast then
		cast.Event:Connect(function()
			AutoWalk.stop("input-skill")
		end)
	end
end)

-- 앞쪽 점: 진행 번호부터 lookAheadStuds만큼 간 점 · 그 사이 절벽(낙하 피해) · 올라가는 턱
local function ahead(route, cursor, feet)
	local pts = route.points
	local walked, target = 0, pts[math.min(#pts, cursor + 1)]
	local drop, step = 0, false
	local treeR = WorldMapData.progress.treeRadius
	for k = cursor + 1, #pts do
		local a, b = pts[k - 1], pts[k]
		local h = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
		if walked <= A.dropAheadStuds and Vector3.new(a.X, 0, a.Z).Magnitude > treeR then
			drop = math.max(drop, a.Y - b.Y)
		end
		if walked <= A.lookAheadStuds and b.Y - WorldMapData.guide.groundLift - feet.Y > A.stepJumpStuds then -- 경로 점 = 지면 + groundLift
			step = true
		end
		walked += h
		target = b
		if walked >= A.lookAheadStuds then
			break
		end
	end
	return target, drop, step
end

-- 검사용 계측: 이번 틱이 어느 분기에서 끝났나(바뀔 때만 로컬 Attribute AutoWalkTrace)
local function trace(text)
	if player:GetAttribute("AutoWalkTrace") ~= text then
		player:SetAttribute("AutoWalkTrace", text)
	end
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	if not active then
		return
	end
	elapsed += dt
	if elapsed < A.tickSeconds then
		return
	end
	elapsed = 0
	local humanoid, root = humanoidAndRoot()
	if not humanoid or not root or humanoid.Health <= 0 then
		return AutoWalk.stop("dead")
	end
	if moveVector().Magnitude > 0.1 then
		return AutoWalk.stop("input-move")
	end
	local falling = humanoid:GetState() == Enum.HumanoidStateType.Freefall
	if falling and os.clock() < expectFallUntil then
		expectFallUntil = os.clock() + A.fallGraceSeconds -- 떨어지는 동안 · 착지 직후까지 늘린다
	end
	if humanoid.Health < lastHealth - 0.01 and os.clock() >= expectFallUntil then
		return AutoWalk.stop("damaged")
	end
	lastHealth = humanoid.Health
	if player:GetAttribute("BossEncounterId") ~= nil then
		return AutoWalk.stop("boss")
	end
	if goal and (Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)).Magnitude <= WorldMapData.guide.arriveStuds then
		return AutoWalk.stop("arrived") -- 견습 안내는 도착하면 지워진다(다른 안내로 넘어가기 전에 먼저 판정)
	end
	local route, cursor, who = Wayfinder.route()
	if not route then
		-- 안내 끔 · 목적지 바뀜 · 보스전(Wayfinder.isShowing 거짓)
		if Wayfinder.destination() == nil or Wayfinder.isHidden() or Wayfinder.activeOwner() ~= owner then
			return AutoWalk.stop("route")
		end
		return trace("wait-route") -- 재계산 중(경로가 곧 돌아온다)
	end
	if who ~= owner then
		return AutoWalk.stop("route")
	end
	local feet = root.Position - Vector3.new(0, 3, 0)
	local target, drop, step = ahead(route, cursor, feet)
	if drop > F.safeHeight then
		-- 절벽: 낙하 피해가 작으면(maxDropFraction 이하) 계속 - 그 낙하 피해는 피격 멈춤에서 뺀다 · 크면 앞에서 멈춤
		if (drop - F.safeHeight) / (F.lethalHeight - F.safeHeight) > A.maxDropFraction then
			return AutoWalk.stop("drop")
		end
		expectFallUntil = os.clock() + A.fallGraceSeconds
	end
	moveTarget = target
	trace(("walk c%d/%d j%d r%d"):format(cursor, #route.points, jumps, recomputes))
	if step and humanoid.FloorMaterial ~= Enum.Material.Air then
		selfJump(humanoid)
	end
	-- 끼임: stuckSeconds 동안 stuckStuds 못 감 → 점프 → 재계산 → 멈춤
	local now = os.clock()
	if (Vector3.new(root.Position.X - lastPos.X, 0, root.Position.Z - lastPos.Z)).Magnitude >= A.stuckStuds then
		lastPos, lastProgressAt, jumps = root.Position, now, 0
	elseif now - lastProgressAt >= A.stuckSeconds then
		lastProgressAt = now
		if jumps < A.jumpsBeforeRecompute then
			jumps += 1
			selfJump(humanoid)
		elseif recomputes < A.maxRecomputes then
			jumps, recomputes = 0, recomputes + 1
			Wayfinder.recomputeNow()
		else
			return AutoWalk.stop("stuck")
		end
	end
end)

-- 검사 훅: 클라 execute_luau에서 LocalPlayer:SetAttribute("AutoWalkDebug", os.clock()) → 켜기 시도(결과 = Attribute AutoWalkStarted)
player:GetAttributeChangedSignal("AutoWalkDebug"):Connect(function()
	if player:GetAttribute("AutoWalkDebug") then
		AutoWalk.stop("route") -- 걷는 중이면 옛 목적지(goal) · owner를 버리고 새로
		player:SetAttribute("AutoWalkStarted", AutoWalk.start())
	else
		AutoWalk.stop("input")
	end
end)

return AutoWalk
