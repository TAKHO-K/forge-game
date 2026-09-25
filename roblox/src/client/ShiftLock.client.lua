-- 시점 고정(M1-0 - 자체 구현). 로블록스 기본 Shift Lock(키 LeftShift = 대시와 겹침)은 서버가 끈다(MovementServer - DevEnableMouseLock).
-- 기본 PlayerModule을 복제해 키만 바꾸지 않은 이유: 복제본은 로블록스 카메라 · 조작 업데이트를 더 못 받는다. 여기는 기본 카메라 위에 세 가지만 얹는다:
--   ① 마우스를 화면 가운데에 묶는다(MouseBehavior.LockCenter - 기본 카메라가 이때 마우스 이동으로 시점을 돌린다) ② 캐릭터가 카메라 방위를 본다(AutoRotate 끄고 루트 회전)
--   ③ 카메라를 오른쪽 어깨 너머로(Humanoid.CameraOffset). 창이 열려 있으면(모달) 잠시 풀어 마우스를 쓸 수 있게 한다 - 창을 닫으면 다시 묶는다.
-- 켜고 끄기: PC = LeftControl · 폰 = 대시 버튼 바로 위 "고정" 버튼(SkillSlotsGui.DashHolder 안 - 터치 배치일 때만 보인다). 이번 접속 동안만(저장은 P4 설정창).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local UIManager = require(script.Parent.UIManager)

local player = Players.LocalPlayer
local cfg = MovementConfig.shiftLock

local BUTTON = 44
local locked = false
local applied = false -- 지금 ①~③을 걸고 있는가(창이 열리면 locked여도 푼다)

local function humanoidAndRoot()
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid"), character and character:FindFirstChild("HumanoidRootPart")
end

local function release()
	if not applied then
		return
	end
	applied = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	local humanoid = humanoidAndRoot()
	if humanoid then
		humanoid.AutoRotate = true
		humanoid.CameraOffset = Vector3.zero
	end
end

-- 폰 버튼
local button = Instance.new("TextButton")
button.Name = "ShiftLockButton"
button.AnchorPoint = Vector2.new(0, 1)
button.Position = UDim2.new(0, 5, 0, -8) -- 대시 칸(DashHolder) 위 끝에서 8 위
button.Size = UDim2.new(0, BUTTON, 0, BUTTON)
button.AutoButtonColor = false
button.Font = Enum.Font.GothamBold
button.TextSize = 14
button.Text = Text.get("shiftLock.button")
button.TextColor3 = UIColors.textPrimary
button.BackgroundColor3 = UIColors.panel
button.BackgroundTransparency = UIColors.panelTransparency
button.Visible = false
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = button
local stroke = Instance.new("UIStroke")
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Thickness = 2
stroke.Parent = button

local function paint()
	stroke.Color = locked and UIColors.ember or UIColors.rim
	stroke.Transparency = locked and 0 or UIColors.rimTransparency
end
paint()

local function setLocked(on)
	locked = on
	player:SetAttribute("ShiftLocked", on) -- 검증 · 스크린샷이 읽는다(이 클라에서만)
	paint()
	if not on then
		release()
	end
end

local function isTouchLayout()
	return UserInputService.TouchEnabled or (RunService:IsStudio() and player:GetAttribute("ForceTouchLayout") == true)
end

task.spawn(function()
	-- DashHolder는 PC 배치에서 CentralRow 안, 터치 배치에서 SkillSlotsGui 바로 아래로 옮겨진다 - 자손으로 찾는다(Play 1: 자식 WaitForChild가 무한 대기)
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("SkillSlotsGui")
	local holder = gui:FindFirstChild("DashHolder", true)
	while not holder do
		gui.DescendantAdded:Wait()
		holder = gui:FindFirstChild("DashHolder", true)
	end
	button.Parent = holder
	local function refresh()
		button.Visible = isTouchLayout()
	end
	refresh()
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(refresh)
end)

button.Activated:Connect(function()
	setLocked(not locked)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftControl then
		setLocked(not locked)
	end
end)

-- 카메라 모듈 · CameraRig(+2) 뒤
RunService:BindToRenderStep("ShiftLock", Enum.RenderPriority.Camera.Value + 3, function()
	if not locked then
		return
	end
	local humanoid, root = humanoidAndRoot()
	local camera = Workspace.CurrentCamera
	if not humanoid or not root or humanoid.Health <= 0 or UIManager.isInputBlocked() or root.Anchored then
		release()
		return
	end
	applied = true
	if not isTouchLayout() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
	humanoid.AutoRotate = false
	humanoid.CameraOffset = cfg.cameraOffsetStuds
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 1e-3 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat.Unit)
	end
end)

player.CharacterAdded:Connect(function()
	-- 새 Humanoid는 기본값(AutoRotate 켜짐)이다 - 마우스만 풀고 다음 프레임에 다시 건다(리뷰 3: 창이 열린 채 캐릭터가 바뀌어도 마우스가 가운데에 남지 않게)
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	applied = false
end)
