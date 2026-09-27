-- BR1-4c c-4 보스 진입 연출(서버 BossEncounter.startIntro가 시간표를 보낸다 - 파티원 전원 같은 시간표): 보스 줌인 + 이름 → 아군을 한 명씩 → 전투 시작.
-- 화면 연출만(판정은 서버 - 연출 동안 보스 행동 · 피해 없음 · 입력 잠금 = BossIntroLock). 카메라는 끝나면 원래 방식으로 돌려놓는다. 짧은 버전 = 보스 컷만.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("BossIntroCinema")

local token = 0

local function easeInOut(t)
	t = math.clamp(t, 0, 1)
	return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2
end

local function nameBanner(text, seconds)
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossIntroBanner"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 50
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.72)
	label.Size = UDim2.fromScale(0.8, 0.12)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.2
	label.TextTransparency = 1
	label.Text = text
	label.Parent = gui
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
	gui.Parent = player:WaitForChild("PlayerGui")
	TweenService:Create(label, TweenInfo.new(0.25), { TextTransparency = 0 }):Play()
	for _, bar in ipairs(bars) do
		TweenService:Create(bar, TweenInfo.new(0.25), { Size = UDim2.new(1, 0, 0.1, 0) }):Play()
	end
	task.delay(math.max(seconds - 0.3, 0.1), function()
		TweenService:Create(label, TweenInfo.new(0.3), { TextTransparency = 1 }):Play()
		for _, bar in ipairs(bars) do
			TweenService:Create(bar, TweenInfo.new(0.3), { Size = UDim2.new(1, 0, 0, 0) }):Play()
		end
		task.delay(0.35, function()
			gui:Destroy()
		end)
	end)
	return gui
end

local function characterOf(userId)
	local p = Players:GetPlayerByUserId(userId)
	return p and p.Character
end

event.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not data.model then
		return
	end
	token += 1
	local my = token
	local camera = Workspace.CurrentCamera
	local oldType, oldSubject = camera.CameraType, camera.CameraSubject
	local started = os.clock()
	local banner = nameBanner(data.displayName or "", data.seconds)
	-- 컷 목록(시각 · 대상): 보스 → 아군
	local cuts = { { at = 0, len = data.bossSeconds, kind = "boss" } }
	if data.full and (data.memberSeconds or 0) > 0 then
		for i, userId in ipairs(data.members or {}) do
			table.insert(cuts, { at = data.bossSeconds + (i - 1) * data.memberSeconds, len = data.memberSeconds, kind = "member", userId = userId })
		end
	end
	RunService:BindToRenderStep("BossIntroCinema", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock() - started
		if my ~= token or t >= data.seconds or not data.model.Parent then
			RunService:UnbindFromRenderStep("BossIntroCinema")
			if my == token then
				camera.CameraType = oldType
				camera.CameraSubject = oldSubject
			end
			return
		end
		local cut = cuts[1]
		for _, c in ipairs(cuts) do
			if t >= c.at then
				cut = c
			end
		end
		local f = easeInOut((t - cut.at) / math.max(cut.len, 0.05))
		camera.CameraType = Enum.CameraType.Scriptable
		if cut.kind == "boss" then
			local root = data.model.PrimaryPart
			local head = data.model:FindFirstChild("Head")
			if root then
				local look = root.CFrame.LookVector
				local target = (head and head.Position) or (root.Position + Vector3.new(0, 6, 0))
				local far = target + look * 42 + Vector3.new(0, 6, 0)
				local near = target + look * 16 + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.lookAt(far:Lerp(near, f), target) -- 보스 줌인
			end
		else
			local character = characterOf(cut.userId)
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local target = root.Position + Vector3.new(0, 1.5, 0)
				local from = target + root.CFrame.LookVector * 9 + root.CFrame.RightVector * (2 - 3 * f) + Vector3.new(0, 1.2, 0)
				camera.CFrame = CFrame.lookAt(from, target) -- 아군 한 명씩(살짝 옆으로 흐름)
			end
		end
	end)
	task.delay(data.seconds + 0.5, function()
		if banner.Parent then
			banner:Destroy()
		end
	end)
end)
