-- 보스 진입 연출 카메라 · 이름 카드(BR1-4c c-4 → A2-M1 개정). 서버 BossEncounter.startIntro가 시간표를 보낸다(파티원 전원 같은 시각 - untilServer):
--   첫 조우(3초 - 이 보스를 처음 만나는 멤버가 있을 때) = ① 저각 클로즈업: 보스가 솟는 동안(등장 동작 = client/BossAnimator · BossBodyFx) 아래에서 올려다보며 조금씩 다가감
--     ② 포효 풀샷: 뒤로 물러나 몸 전체 + 이름 · 칭호 카드 · 흔들림(설정 "화면 흔들림" 존중) ③ 마지막 0.55초 = 원래 시점으로 부드럽게 돌아옴(끊김 없음).
--   짧은 판(1.2초) = 보스 정면으로 밀고 들어가며 포효 · 이름만 → 원래 시점으로.
-- 화면 연출만(판정은 서버 - 연출 동안 보스 행동 · 피해 없음 · 입력 잠금 = BossIntroLock · 기록 시작 = 연출 끝). 카메라는 끝나면 원래 방식으로 돌려놓는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossMotionData = require(ReplicatedStorage.Shared.data.BossMotionData)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Text = require(ReplicatedStorage.Shared.Text)
local Easing = require(ReplicatedStorage.Shared.Easing)

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("BossIntroCinema")

local token = 0
local ROAR_SHAKE = { seconds = 0.55, studs = 0.55 }

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- 이름 카드: 위아래 영화 띠 · 칭호(강조색 작은 글씨) · 이름(큰 글씨) · 강조색 밑줄이 펼쳐짐. 폰(짧은 변 360)에서도 글씨 실효 12 이상(TextScaled + 최소 크기).
local function nameCard(bossId, displayName, accent, showAt, hideAt, full)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossIntroBanner"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	gui.ResetOnSpawn = false
	local bars = {}
	for _, top in ipairs({ true, false }) do -- 영화 띠(위 · 아래)
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.new(1, 0, 0, 0)
		bar.Position = top and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 1)
		bar.AnchorPoint = top and Vector2.new(0, 0) or Vector2.new(0, 1)
		bar.Parent = gui
		table.insert(bars, bar)
	end
	local holder = Instance.new("Frame")
	holder.Name = "Card"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.6) -- A2-M1: 하단 HUD(체력바 · 스킬 줄) 위
	holder.Size = UDim2.fromScale(0.8, full and 0.2 or 0.13)
	holder.Parent = gui
	local function label(name, text, y, h, color, font)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = font
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.25
		l.TextTransparency = 1
		l.TextStrokeColor3 = Color3.new(0, 0, 0)
		l.Text = text
		local limit = Instance.new("UITextSizeConstraint")
		limit.MinTextSize = 14
		limit.Parent = l
		l.Parent = holder
		return l
	end
	local labels = {}
	if full then
		table.insert(labels, label("Title", Text.get("boss.title." .. tostring(bossId)), 0, 0.3, accent:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Font.GothamBold))
	end
	table.insert(labels, label("Name", displayName or "", full and 0.3 or 0, full and 0.58 or 0.8, Color3.new(1, 1, 1), Enum.Font.GothamBlack))
	local line = Instance.new("Frame")
	line.Name = "Underline"
	line.BorderSizePixel = 0
	line.BackgroundColor3 = accent
	line.AnchorPoint = Vector2.new(0.5, 0)
	line.Position = UDim2.fromScale(0.5, full and 0.92 or 0.86)
	line.Size = UDim2.new(0, 0, 0, 3)
	line.Parent = holder
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, bar in ipairs(bars) do
		TweenService:Create(bar, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.new(1, 0, 0.09, 0) }):Play()
	end
	task.delay(math.max(showAt, 0), function()
		if not gui.Parent then
			return
		end
		for i, l in ipairs(labels) do
			l.Position += UDim2.fromScale(0, 0.06)
			TweenService:Create(l, TweenInfo.new(0.28 + i * 0.05, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { TextTransparency = 0, Position = l.Position - UDim2.fromScale(0, 0.06) }):Play()
		end
		TweenService:Create(line, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = UDim2.new(0.42, 0, 0, 3) }):Play()
	end)
	task.delay(math.max(hideAt, 0.1), function()
		for _, l in ipairs(labels) do
			TweenService:Create(l, TweenInfo.new(0.3), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
		TweenService:Create(line, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		for _, bar in ipairs(bars) do
			TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end)
	return gui
end

-- A2-M1: 서버가 보스를 만든 그 프레임에 보내 모델 참조가 아직 복제 전이면 nil로 온다(옛 연출이 첫 입장에서 조용히 안 나온 원인) → 조우 id로 모델을 잠깐 기다린다
local CollectionService = game:GetService("CollectionService")
local function awaitModel(data)
	if data.model then
		return data.model
	end
	local deadline = os.clock() + 1.5
	while os.clock() < deadline do
		for _, m in ipairs(CollectionService:GetTagged("Monster")) do
			if m:GetAttribute("BossIntroUntil") == data.untilServer and m.PrimaryPart then
				return m
			end
		end
		task.wait()
	end
	return nil
end

event.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then
		return
	end
	data.model = awaitModel(data)
	if not data.model then
		return
	end
	token += 1
	local my = token
	local camera = Workspace.CurrentCamera
	local oldType, oldSubject = camera.CameraType, camera.CameraSubject
	local seconds = data.seconds or 1.2
	local startServer = (data.untilServer or serverNow() + seconds) - seconds
	local boss = BossMotionData.bosses[data.bossId or ""] or {}
	local introSpec = boss.intro or {}
	local riseT = data.full and seconds * (introSpec.riseFrac or 0.42) or 0
	local rig = BossRigSpec.rigs[data.bossId or ""]
	local accent = (rig and rig.themeColors and rig.themeColors.accent) or (rig and rig.accent) or Color3.fromRGB(255, 220, 120)
	local tNow = serverNow() - startServer
	local banner = nameCard(data.bossId, data.displayName, accent, (data.full and riseT or 0.1) - tNow, seconds - 0.45 - tNow, data.full)
	local shakeOn = player:GetAttribute("SettingScreenShake") ~= false and player:GetAttribute("SettingBossScreenShake") ~= false
	local roarAt = data.full and (riseT + 0.4) or 0.5
	local root = data.model.PrimaryPart
	local size = data.model:GetExtentsSize()
	local height = math.max(size.Y, 6)
	-- A2-M1 2차: 연출 동안 다른 HUD를 숨긴다(리뷰: 스킬 줄 · 메뉴가 떠 있어 연출이 싸 보임) · 게임 시점 복귀(마지막 0.55초)가 시작될 때 되돌림
	local hidden = {}
	local lateConn = nil
	local function restoreHud()
		if lateConn then
			lateConn:Disconnect()
			lateConn = nil
		end
		for _, g in ipairs(hidden) do
			if g.Parent then
				g.Enabled = true
			end
		end
		table.clear(hidden)
	end
	for _, g in ipairs(player.PlayerGui:GetChildren()) do
		if g:IsA("ScreenGui") and g.Enabled and g ~= banner and g.Name ~= "BossIntroCard" then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	local function hideBillboard(g)
		if g:IsA("BillboardGui") and g.Enabled then
			g.Enabled = false
			table.insert(hidden, g)
		end
	end
	-- 보스 머리 위 이름표(빌보드)가 이름 카드 칭호와 겹친다 · 머리는 스트리밍으로 연출 시작 뒤에 도착하기도 해 들어오는 것도 끈다(Play 8: 이름표가 남았다)
	lateConn = data.model.DescendantAdded:Connect(hideBillboard)
	for _, g in ipairs(data.model:GetDescendants()) do
		hideBillboard(g)
	end
	RunService:BindToRenderStep("BossIntroCinema", Enum.RenderPriority.Camera.Value + 1, function()
		local t = serverNow() - startServer
		if #hidden > 0 and (t > seconds - 0.55 or my ~= token) then
			restoreHud()
		end
		if my ~= token or t >= seconds or not data.model.Parent or not root then
			restoreHud()
			RunService:UnbindFromRenderStep("BossIntroCinema")
			if my == token then
				camera.CameraType = oldType
				camera.CameraSubject = oldSubject
			end
			return
		end
		camera.CameraType = Enum.CameraType.Scriptable
		-- 기준 방향: 보스 → 나(수평) - 보스는 등장 동안 파티 쪽을 보고 선다(BossAnimator 표시 방향)
		local my_ = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local bossPos = root.Position
		local toMe = my_ and Vector3.new(my_.Position.X - bossPos.X, 0, my_.Position.Z - bossPos.Z) or Vector3.new(0, 0, 1)
		local front = toMe.Magnitude > 1e-3 and toMe.Unit or Vector3.new(0, 0, 1)
		local side = Vector3.new(0, 1, 0):Cross(front)
		local feet = bossPos - Vector3.new(0, 1.5, 0)
		local chest = feet + Vector3.new(0, height * 0.62, 0)
		local shotCf
		if data.full and t < riseT + 0.15 then
			-- ① 저각 클로즈업(아래에서 올려다봄 · 조금씩 다가감)
			local f = Easing.get("sine", t / (riseT + 0.15))
			local dist = height * (1.35 - 0.2 * f)
			local from = feet + front * dist + side * dist * 0.38 + Vector3.new(0, height * 0.12, 0)
			shotCf = CFrame.lookAt(from, chest + Vector3.new(0, height * 0.1 * f, 0))
		else
			-- ② 포효 풀샷(짧은 판 = 밀고 들어감)
			local t0 = data.full and riseT + 0.15 or 0
			local f = Easing.get("out", (t - t0) / math.max(seconds - 0.55 - t0, 0.2))
			local dist = data.full and height * (1.55 + 0.25 * f) or height * (1.9 - 0.45 * f)
			local from = feet + front * dist + side * dist * (data.full and 0.18 or 0.1) + Vector3.new(0, height * 0.42, 0)
			shotCf = CFrame.lookAt(from, chest)
		end
		-- 포효 흔들림(설정 존중)
		if shakeOn and t >= roarAt and t < roarAt + ROAR_SHAKE.seconds then
			local k = (1 - (t - roarAt) / ROAR_SHAKE.seconds) * ROAR_SHAKE.studs
			shotCf *= CFrame.new((math.random() * 2 - 1) * k, (math.random() * 2 - 1) * k, 0)
		end
		-- ③ 마지막 0.55초: 게임 시점(나 뒤에서 보스를 바라봄 · 보스별 카메라 거리 · 30° 내려다봄)으로 이징 - 연출이 끝나면 기본 카메라가 이 자리에서 이어받는다
		local back = seconds - 0.55
		if t > back and my_ then
			local focus = my_.Position + Vector3.new(0, 1.5, 0)
			local dist = math.max(player.CameraMinZoomDistance, (BossData.bosses[data.bossId or ""] or {}).cameraZoomStuds or 26)
			local pitch = math.rad(30)
			local from = focus + front * dist * math.cos(pitch) + Vector3.new(0, dist * math.sin(pitch), 0)
			shotCf = shotCf:Lerp(CFrame.lookAt(from, focus), Easing.get("inout", (t - back) / 0.55))
		end
		camera.CFrame = shotCf
	end)
	task.delay(seconds + 0.6, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end)
