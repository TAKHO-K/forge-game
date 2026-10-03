-- QUEUE-ALL9C 1-6 X6 3D 미리보기 창(상점 위 overlay - 상점을 닫으면 같이 닫힌다 · X · Backspace로 닫기 · Esc는 로블록스 메뉴 그대로).
--   내 아바타 복제(Character:Clone - 겉모습 그대로)를 ViewportFrame 안 WorldModel에 세우고 끌어서 돌려 본다.
--   구성품 칩 = 그 치장이 주는 칸마다 하나씩 켜고 끄기: 글라이더 = 실제 글라이더 모양(GlideView.buildOnto) · 테마 = 칸마다 정지 모양(대시 = 뒤 빛줄기 · 점프 = 발밑 고리 ·
--   활강 = 머리 위 빛줄 · 발자국 = 바닥 자국 - 테마 색 ArtV1CosmeticData). ViewportFrame은 입자 · 트레일을 그리지 않아 움직이는 효과는 [직접 보기](내 캐릭터에 잠깐 입혀 보기 - 옛 미리보기)로 본다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ArtV1CosmeticData = require(ReplicatedStorage.Shared.data.ArtV1CosmeticData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local Preview3D = {}
Preview3D.id = "shopPreview3D"

local player = Players.LocalPlayer
local SIZE = Vector2.new(560, 440)
local PARTS = { "dashTrail", "jumpFx", "glideTrail", "footstep" }

local built -- { panel, viewport, world, camera, chips, title }
local current -- { kind, entry, model, root, pieces = { [part] = Instance }, on = { [part] = bool } }
local yaw = 200

local function cameraUpdate()
	if not built or not current or not current.root then
		return
	end
	local center = current.root.Position + Vector3.new(0, 0.6, 0)
	local r = math.rad(yaw)
	built.camera.CFrame = CFrame.lookAt(center + Vector3.new(math.sin(r) * 15, 3, math.cos(r) * 15), center + Vector3.new(0, 1.2, 0))
end

local function neon(name, size, color, transparency, cf, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency or 0.2
	p.Size = size
	p.CFrame = cf
	if shape then
		p.Shape = shape
	end
	return p
end

-- 테마 칸 하나의 정지 모양(뷰포트 안 - 실제 효과 대신 색 · 자리만)
local function themePiece(slot, look, root)
	local theme = look and look ~= "" and ArtV1CosmeticData.themes[look]
	if not theme then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = "Piece_" .. slot
	local base = root.CFrame
	if slot == "dashTrail" then
		for i = 1, 4 do
			neon("Dash" .. i, Vector3.new(1.6 - i * 0.25, 2.2 - i * 0.3, 0.9), i % 2 == 1 and theme.core or theme.edge, 0.15 + i * 0.15, base * CFrame.new(0, 0, 1.2 + i * 1.0)).Parent = m
		end
	elseif slot == "jumpFx" then
		neon("Ring", Vector3.new(0.2, 5, 5), theme.edge, 0.6, base * CFrame.new(0, -2.9, 0) * CFrame.Angles(0, 0, math.rad(90)), Enum.PartType.Cylinder).Parent = m
	elseif slot == "glideTrail" then
		for i = 1, 5 do
			neon("Glide" .. i, Vector3.new(0.35, 0.35, 1.1), theme.core, 0.1 + i * 0.12, base * CFrame.new(0, 3.4, 1 + i * 1.1)).Parent = m
		end
	elseif slot == "footstep" then
		for i, x in ipairs({ -0.6, 0.6 }) do
			neon("Step" .. i, Vector3.new(0.7, 0.05, 1.1), theme.particle or theme.core, 0.1, base * CFrame.new(x, -3, 1.6 + i * 1.2)).Parent = m
		end
	end
	return m
end

local function clearCurrent()
	if current and current.model then
		current.model:Destroy()
	end
	for _, piece in pairs(current and current.pieces or {}) do
		piece:Destroy()
	end
	current = nil
end

local function setPiece(part, on)
	local piece = current and current.pieces[part]
	if piece then
		piece.Parent = on and built.world or nil
	end
	current.on[part] = on
end

local function renderChips()
	for _, child in ipairs(built.chips:GetChildren()) do
		if child:IsA("GuiButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	if not current then
		return
	end
	local order = 0
	local function chip(name, text, on, onActivated)
		order += 1
		local b = Button.build({ parent = built.chips, name = name, kind = on and "primary" or "secondary", text = text, width = 120, onActivated = onActivated })
		b.root.LayoutOrder = order
	end
	for _, part in ipairs(current.partOrder) do
		chip("Toggle_" .. part, (current.on[part] and "✓ " or "") .. Text.get(current.partNames[part]), current.on[part], function()
			setPiece(part, not current.on[part])
			renderChips()
		end)
	end
	if current.tryInWorld then
		local try = current.tryInWorld
		chip("TryInWorld", Text.get("shop.preview.tryWorld"), false, function()
			UIManager.close(Preview3D.id) -- 딤을 걷고 내 캐릭터로 본다(상점 상태 줄에 무엇을 눌러 보는지 나온다)
			try()
		end)
	end
end

local function build()
	local panel = Panel.create({ id = Preview3D.id, kind = "overlay", parentId = "shop", title = Text.get("shop.preview.title"), size = SIZE,
		onClose = function()
			clearCurrent()
		end })
	local content = panel.content
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Viewport"
	viewport.BackgroundColor3 = Color3.fromRGB(28, 32, 42)
	viewport.Position = UDim2.fromOffset(12, 8)
	viewport.Size = UDim2.new(1, -24, 1, -(Theme.buttonHeight * 2 + 40))
	viewport.Ambient = Color3.fromRGB(170, 170, 180)
	viewport.LightColor = Color3.fromRGB(255, 255, 250)
	viewport.LightDirection = Vector3.new(-1, -2, -1)
	viewport.Parent = content
	Theme.corner(viewport, 10)
	local world = Instance.new("WorldModel")
	world.Parent = viewport
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local hint = Theme.label(viewport, Text.get("shop.preview.dragHint"), "caption", "textSecondary")
	hint.Name = "DragHint"
	hint.AnchorPoint = Vector2.new(0.5, 1)
	hint.Position = UDim2.new(0.5, 0, 1, -6)
	hint.Size = UDim2.new(1, -12, 0, 18)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	local chips = Instance.new("Frame")
	chips.Name = "PartChips"
	chips.BackgroundTransparency = 1
	chips.AnchorPoint = Vector2.new(0, 1)
	chips.Position = UDim2.new(0, 12, 1, -8)
	chips.Size = UDim2.new(1, -24, 0, Theme.buttonHeight * 2 + 12)
	chips.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(124, Theme.buttonHeight)
	grid.CellPadding = UDim2.fromOffset(6, 6)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = chips
	-- 끌어서 돌리기(마우스 · 터치 공통 - 뷰포트 위에서 누른 채 옆으로)
	local dragging, lastX = false, 0
	viewport.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, lastX = true, input.Position.X
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			yaw = (yaw - (input.Position.X - lastX) * 0.6) % 360
			lastX = input.Position.X
			cameraUpdate()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	built = { panel = panel, viewport = viewport, world = world, camera = camera, chips = chips }
end

-- kind = "cosmeticTheme" | "gliderSkin" · entry = CosmeticSlotData 항목 · tryInWorld(선택) = 내 캐릭터에 잠깐 입혀 보기(옛 미리보기)
function Preview3D.open(kind, entry, tryInWorld)
	if not built then
		build()
	end
	clearCurrent()
	local character = player.Character
	if not character then
		return false
	end
	local archivable = character.Archivable
	character.Archivable = true
	local model = character:Clone()
	character.Archivable = archivable
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ForceField") or d:IsA("BillboardGui") or d.Name == "MV1Glider" then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		model:Destroy()
		return false
	end
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = built.world
	current = { kind = kind, entry = entry, model = model, root = root, pieces = {}, on = {}, partOrder = {}, partNames = {}, tryInWorld = tryInWorld }
	if kind == "gliderSkin" then
		local glider = Instance.new("Model")
		glider.Name = "PreviewGlider"
		if require(script.Parent.Parent.Parent.GlideView).buildOnto(glider, root, entry.id) then
			for _, d in ipairs(glider:GetDescendants()) do
				if d:IsA("BasePart") then
					d.Anchored = false -- 몸통에 용접된 채(몸통 고정)
				end
			end
			glider.Parent = built.world
			current.pieces.glider = glider
			current.on.glider = true
			table.insert(current.partOrder, "glider")
			current.partNames.glider = "shop.slot.gliderSkin"
		end
	elseif kind == "cosmeticTheme" then
		for _, part in ipairs(PARTS) do
			local piece = themePiece(part, entry.looks and entry.looks[part], root)
			if piece then
				current.pieces[part] = piece
				table.insert(current.partOrder, part)
				current.partNames[part] = "shop.slot." .. part
				setPiece(part, true)
			end
		end
	end
	built.panel.titleLabel.Text = Text.get("shop.preview.titleOf", { name = Text.name(entry.name) })
	yaw = 200
	cameraUpdate()
	renderChips()
	if not UIManager.isOpen(Preview3D.id) then
		UIManager.open(Preview3D.id)
	end
	return true
end

function Preview3D.debugState()
	return current and { kind = current.kind, id = current.entry.id, on = table.clone(current.on), yaw = yaw } or nil
end

return Preview3D
