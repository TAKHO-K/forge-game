-- QUEUE-ALL6 E4 장비창 캐릭터 미리보기(3D - ref 17 구성): 내 캐릭터(입은 방어구 · 무기 포함)를 복제해 ViewportFrame에 세운다.
--   천천히 돈다 · 마우스/손가락으로 끌면 돌리고(놓고 2초 뒤 다시 천천히) · 조명 = 왼쪽 위 주광(LightDirection) + 채움(Ambient) + 뒤 밝은 바탕(테두리 빛 느낌).
--   복제는 열 때 · 장비가 바뀔 때만(매 프레임은 카메라만 돈다) · 창이 안 보이면 돌리지 않는다. 겉모습만(판정 · 서버 무관).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CharacterPreview = {}

local player = Players.LocalPlayer
local SPIN = 0.45 -- 라디안/초
local DRAG = 0.012 -- 라디안/px
local RESUME = 2

function CharacterPreview.create(parent)
	local vf = Instance.new("ViewportFrame")
	vf.Name = "CharacterPreview3D"
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(150, 156, 172) -- 채움
	vf.LightColor = Color3.fromRGB(255, 246, 232) -- 주광(따뜻한 흰색)
	vf.LightDirection = Vector3.new(0.6, -0.8, 0.5) -- 왼쪽 위 앞에서(카메라 기준으로 아래 rotate 때 같이 돈다)
	vf.Parent = parent
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vf
	vf.CurrentCamera = camera
	local backdrop = Instance.new("Frame") -- 뒤 밝은 둥근 빛(테두리 빛 느낌 · 바닥 그림자는 부모의 기존 그림자)
	backdrop.Name = "Backdrop"
	backdrop.AnchorPoint = Vector2.new(0.5, 0.5)
	backdrop.Position = UDim2.fromScale(0.5, 0.45)
	backdrop.Size = UDim2.fromScale(0.8, 0.8)
	backdrop.BackgroundColor3 = Color3.fromRGB(120, 140, 190)
	backdrop.BackgroundTransparency = 0.82
	backdrop.ZIndex = vf.ZIndex - 1
	backdrop.Parent = parent
	Instance.new("UICorner", backdrop).CornerRadius = UDim.new(1, 0)

	local model, center, radius, halfWidth = nil, Vector3.zero, 3, 1.5
	local angle, lastDragAt, dragX = math.rad(200), -math.huge, nil

	local function place()
		local aspect = vf.AbsoluteSize.Y > 0 and vf.AbsoluteSize.X / vf.AbsoluteSize.Y or 1 -- 좁은 칸 = 가로 시야가 세로보다 좁다
		local t = math.tan(math.rad(camera.FieldOfView / 2))
		local dist = math.max(radius / t, halfWidth / (t * math.max(aspect, 0.2))) * 1.05
		local dir = Vector3.new(math.sin(angle), 0.18, math.cos(angle)).Unit
		camera.CFrame = CFrame.lookAt(center + dir * dist, center)
	end

	local self = {}
	function self.refresh()
		if model then
			model:Destroy()
			model = nil
		end
		local character = player.Character
		if not character then
			return false
		end
		local was = character.Archivable
		character.Archivable = true
		local ok, clone = pcall(function()
			return character:Clone()
		end)
		character.Archivable = was
		if not ok or not clone then
			return false
		end
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("BillboardGui") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = true
			end
		end
		local hum = clone:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		-- Play E5: 착용 방어구 조각은 캐릭터 밑이 아니라 workspace.ArmorWear에 용접돼 있다(ArmorWearView) → 이 캐릭터에 붙은 조각도 같이 복제
		local wear = workspace:FindFirstChild("ArmorWear")
		for _, piece in ipairs(wear and wear:GetChildren() or {}) do
			local weld = piece:IsA("BasePart") and piece:FindFirstChildOfClass("WeldConstraint")
			if weld and weld.Part0 and weld.Part0:IsDescendantOf(character) then
				local copy = piece:Clone()
				for _, w in ipairs(copy:GetChildren()) do
					if w:IsA("WeldConstraint") then
						w:Destroy()
					end
				end
				copy.Anchored = true
				copy.CFrame = piece.CFrame
				copy.Parent = clone
			end
		end
		clone:PivotTo(CFrame.new())
		clone.Parent = vf
		model = clone
		local cf, size = clone:GetBoundingBox()
		center = cf.Position
		radius = math.max(size.Y * 0.55, 2) -- 세로 반(+여유) · 가로 반은 halfWidth(돌아도 잘리지 않게 X · Z 중 큰 쪽)
		halfWidth = math.max(size.X, size.Z) * 0.33 -- Play E5: 그림 칸 폭 68 = 팔 끝까지 맞추면 키 약 90px → 몸통 폭 맞춤(팔 끝은 칸 끝에서 살짝 잘림)
		place()
		return true
	end

	vf.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragX = input.Position.X
			lastDragAt = os.clock()
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragX and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			angle -= (input.Position.X - dragX) * DRAG
			dragX = input.Position.X
			lastDragAt = os.clock()
			place()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragX = nil
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		local gui = vf:FindFirstAncestorWhichIsA("ScreenGui")
		if not model or not dragX and os.clock() - lastDragAt < RESUME or not (gui and gui.Enabled and vf.AbsoluteSize.X > 0 and vf.Visible) then
			return
		end
		local frame = vf:FindFirstAncestorWhichIsA("GuiObject")
		while frame do -- 접힌(안 보이는) 창이면 돌리지 않는다
			if not frame.Visible then
				return
			end
			frame = frame.Parent and frame.Parent:IsA("GuiObject") and frame.Parent or nil
		end
		if not dragX then
			angle += dt * SPIN
			place()
		end
	end)
	player.CharacterAdded:Connect(function()
		task.wait(2)
		self.refresh()
	end)
	self.frame = vf
	return self
end

return CharacterPreview
