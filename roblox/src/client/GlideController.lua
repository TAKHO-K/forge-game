-- MV1 활강(자기 캐릭터 - 캐릭터 물리는 이 클라가 가진다). 수치 = MovementConfig.glide · 게이지 식 = MoveRules.stepGauge.
--   켜기 = DashInput(공중에서 대시 길게 누름 - DashConfig.input.glideHoldSeconds). 끄기 = 대시 다시 누름(DashInput) · 점프(DoubleJumpInput) · 게이지 소진 · 착지 · 물 · 넉백.
--   활강 중: 수평 = 바라보는 방향 × forwardSpeed · 세로 = −descentSpeed(일정) - 루트에 LinearVelocity 제약(물리 스텝 안에서 속도를 지킨다 · 매 스텝 속도만 덮어쓰면 중력이 섞여 하강 7/s가 됐다 - MV1 실측). 이동 입력 쪽으로 turnDegPerSecond만큼 돈다(좌우 조향).
--   게이지: 활강 중 줄고 · 서 있으면 refillSeconds에 가득 · 공중에서는 그대로. 캐릭터 옆 원형 게이지(점 고리 - 초록 → 노랑 → 빨강)는 활강 중이거나 덜 찼을 때만 보인다(자기 화면만).
--   서버에 알림(GlideState) → 서버가 Character Attribute "Gliding"을 켜서 남의 화면에 글라이더가 보인다(이 모듈이 남의 캐릭터 Attribute를 감시해 GlideView를 부른다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local MoveRules = require(ReplicatedStorage.Shared.MoveRules)
local GlideView = require(script.Parent.GlideView)

local GlideController = {}

local G = MovementConfig.glide
local UI = G.gaugeUi
local player = Players.LocalPlayer
local glideState = ReplicatedStorage:WaitForChild("GlideState")

local state = { gliding = false, gauge = G.gaugeSeconds, dir = Vector3.new(0, 0, -1), startedAt = 0, lastStop = nil }
GlideController.state = state -- 검증 · 계측(클라 execute_luau는 모듈 사본이라 Attribute로도 낸다)

local AIR = { [Enum.HumanoidStateType.Jumping] = true, [Enum.HumanoidStateType.Freefall] = true }

local function parts()
	local character = player.Character
	return character, character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function maxSeconds()
	return MoveRules.glideGaugeSeconds((MoveRules.tierOf(player)))
end

function GlideController.isGliding()
	return state.gliding
end

-- 지금 켤 수 있는가(해금 · 공중 · 게이지 · 넉백 · 잡힘 아님).
function GlideController.canStart()
	local character, humanoid, root = parts()
	if not humanoid or not root or humanoid.Health <= 0 or root.Anchored or humanoid.PlatformStand then
		return false
	end
	if not MoveRules.tierOf(player).glide or not AIR[humanoid:GetState()] then
		return false
	end
	if character:GetAttribute("AirLocked") or character:GetAttribute("LedgeHanging") or player:GetAttribute("BossTrapKind") then
		return false
	end
	return state.gauge > 0.05
end

function GlideController.start()
	if state.gliding or not GlideController.canStart() then
		return false
	end
	local character, humanoid, root = parts()
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	state.dir = flat.Magnitude > 1e-3 and flat.Unit or Vector3.new(0, 0, -1)
	state.gliding, state.startedAt, state.lastStop = true, os.clock(), nil
	state.autoRotate = humanoid.AutoRotate
	humanoid.AutoRotate = false
	GlideView.show(character)
	local attach = Instance.new("Attachment")
	attach.Name = "MV1GlideAttach"
	attach.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MV1GlideVelocity"
	lv.Attachment0 = attach
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = math.huge
	lv.VectorVelocity = state.dir * G.forwardSpeed + Vector3.new(0, -G.descentSpeed, 0)
	lv.Parent = root
	state.constraint, state.attach = lv, attach
	character:SetAttribute("MV1GlideStartedAt", os.clock())
	glideState:FireServer(true)
	return true
end

-- reason = "dash" | "jump" | "empty" | "land" | "water" | "locked" | "dead"
function GlideController.stop(reason)
	if not state.gliding then
		return
	end
	state.gliding, state.lastStop = false, reason
	if state.constraint then
		state.constraint:Destroy()
		state.attach:Destroy()
		state.constraint, state.attach = nil, nil
	end
	local character, humanoid = parts()
	if humanoid then
		humanoid.AutoRotate = state.autoRotate ~= false
	end
	GlideView.hide(character)
	if character then
		character:SetAttribute("MV1GlideStop", reason) -- 계측(검증 - 클라 execute_luau가 읽는다)
		character:SetAttribute("MV1GlideSeconds", os.clock() - state.startedAt)
	end
	glideState:FireServer(false)
end

-- ── 원형 게이지(점 고리) ──
local gui = Instance.new("BillboardGui")
gui.Name = "GlideGauge"
gui.Size = UDim2.new(0, UI.sizePx, 0, UI.sizePx)
gui.StudsOffset = Vector3.new(UI.sideStuds, 0.5, 0)
gui.AlwaysOnTop = true
gui.LightInfluence = 0
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local dots = {}
for i = 1, UI.dots do
	local a = (i - 1) / UI.dots * math.pi * 2 - math.pi / 2 -- 12시에서 시계 방향
	local dot = Instance.new("Frame")
	dot.Name = "Dot" .. i
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Size = UDim2.new(0, UI.dotPx, 0, UI.dotPx)
	dot.Position = UDim2.new(0.5, math.cos(a) * (UI.sizePx / 2 - UI.dotPx / 2), 0.5, math.sin(a) * (UI.sizePx / 2 - UI.dotPx / 2))
	dot.BorderSizePixel = 0
	dot.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.panel
	stroke.Thickness = 1
	stroke.Parent = dot
	dots[i] = dot
end

-- QUEUE-ALL1 01 B(아트 켬): 점 고리 → 매끈한 링(ui/kit/RingGauge) · 활강 중에만(다시 차는 동안은 숨김) · 적으면 노랑 → 빨강 깜빡 · 끔 = 옛 점 고리
local ring = nil
local function renderGauge(root, maxS)
	local fraction = maxS > 0 and state.gauge / maxS or 0
	local color = fraction <= UI.dangerFraction and UIColors.danger or (fraction <= UI.warnFraction and UIColors.xp or UIColors.success)
	local art = workspace:GetAttribute("ArtStyleV1") == true
	if art and not ring then
		ring = require(script.Parent.ui.kit.RingGauge).build(gui, UI.sizePx - 6, 5, 48)
	end
	if ring then
		ring.root.Visible = art
	end
	for _, dot in ipairs(dots) do
		dot.Visible = not art
	end
	if art then
		if fraction <= UI.dangerFraction and math.floor(os.clock() * 6) % 2 == 0 then
			color = UIColors.xp -- 빨강 ↔ 노랑 깜빡(초당 3회)
		end
		ring.set(fraction, color, UIColors.lockedIcon)
	else
		local lit = math.ceil(fraction * UI.dots - 1e-6)
		for i, dot in ipairs(dots) do
			dot.BackgroundColor3 = i <= lit and color or UIColors.lockedIcon
		end
	end
	gui.Adornee = root
	gui.Enabled = MoveRules.tierOf(player).glide and (state.gliding or (not art and fraction < 0.999))
end

-- ── 물리 스텝 ──
RunService.Stepped:Connect(function(_, dt)
	local character, humanoid, root = parts()
	if not humanoid or not root then
		gui.Enabled = false
		return
	end
	local maxS = maxSeconds()
	state.gauge = math.min(state.gauge, maxS)
	local hstate = humanoid:GetState()
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air and not AIR[hstate]
	if state.gliding then
		if humanoid.Health <= 0 then
			GlideController.stop("dead")
		elseif hstate == Enum.HumanoidStateType.Swimming then
			GlideController.stop("water")
		elseif grounded then
			GlideController.stop("land")
		elseif humanoid.PlatformStand or root.Anchored or character:GetAttribute("AirLocked") then
			GlideController.stop("locked")
		end
	end
	state.gauge = MoveRules.stepGauge(state.gauge, maxS, dt, state.gliding, grounded)
	if state.gliding and state.gauge <= 0 then
		GlideController.stop("empty") -- 소진 → 자유 낙하(세로 속도는 지금 −descentSpeed에서 중력대로)
	end
	if state.gliding then
		local move = humanoid.MoveDirection
		local want = Vector3.new(move.X, 0, move.Z)
		if want.Magnitude > 0.1 then
			want = want.Unit
			local angle = math.acos(math.clamp(state.dir:Dot(want), -1, 1))
			local step = math.rad(G.turnDegPerSecond) * dt
			if angle <= step then
				state.dir = want
			else
				local side = state.dir:Cross(want).Y >= 0 and 1 or -1
				state.dir = (CFrame.Angles(0, side * step, 0) * state.dir).Unit
			end
		end
		local velocity = state.dir * G.forwardSpeed + Vector3.new(0, -G.descentSpeed, 0)
		if state.constraint then
			state.constraint.VectorVelocity = velocity
		end
		root.AssemblyLinearVelocity = velocity
		root.CFrame = CFrame.lookAt(root.Position, root.Position + state.dir)
	end
	renderGauge(root, maxS)
end)

-- ── 남의 글라이더(서버 Attribute) ──
local function watch(other)
	if other == player then
		return
	end
	local function bind(character)
		local function apply()
			if character:GetAttribute("Gliding") then
				GlideView.show(character)
			else
				GlideView.hide(character)
			end
		end
		character:GetAttributeChangedSignal("Gliding"):Connect(apply)
		apply()
	end
	if other.Character then
		bind(other.Character)
	end
	other.CharacterAdded:Connect(bind)
end
for _, other in ipairs(Players:GetPlayers()) do
	watch(other)
end
Players.PlayerAdded:Connect(watch)

player.CharacterAdded:Connect(function()
	state.gliding = false
	state.gauge = maxSeconds()
end)

-- QUEUE-ALL7 E1 개발 /gg glide(Studio 전용 - 라이브는 DevTools가 없어 이 속성이 안 생긴다): 서버가 높이 올린 뒤 DevGlideStart를 찍으면 떨어지기 시작할 때 활강을 켠다(키 입력 경로를 건너뛴 촬영용)
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("DevGlideStart"):Connect(function()
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 4 and not GlideController.canStart() do
				task.wait(0.05)
			end
			GlideController.start()
		end)
	end)
end

return GlideController
