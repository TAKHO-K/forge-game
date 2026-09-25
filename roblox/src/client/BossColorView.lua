-- BR1-2 색 맞추기의 그림(서버 BossColorMatch가 보낸 사실만). 색약 대비: 빨강 = ● · 파랑 = ▲ - 색과 모양을 같이 쓴다.
--   colorStart    발판(돌단 윗단)마다 윗면을 덮는 색판 + 큰 기호 · 멤버 머리 위 표시(내 것은 크게) · 남은 시간 막대(내 표시 아래)
--   colorFlip     그 발판 색 · 기호를 바꾸고 튄다
--   colorResolve  생존 = 파랑 고리 · 실패 = 붉은 번쩍임 / colorEnd = 치운다
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossFx = require(script.Parent.BossFx)

local BossColorView = {}

local player = Players.LocalPlayer
local COLORS = { red = Color3.fromRGB(235, 60, 60), blue = Color3.fromRGB(60, 140, 255) }
local SYMBOLS = { red = "●", blue = "▲" }
local WHITE = Color3.new(1, 1, 1)

local slabs = {} -- [index] = { part, label }
local marks = {} -- [userId] = gui
local live = {}

local function track(inst)
	live[inst] = true
	return inst
end

local function clear()
	for inst in pairs(live) do
		inst:Destroy()
	end
	live, slabs, marks = {}, {}, {}
end

local function paint(entry, color)
	entry.part.Color = COLORS[color]
	entry.label.Text = SYMBOLS[color]
	entry.label.TextColor3 = WHITE
end

local function playerByUserId(userId)
	for _, p in ipairs(Players:GetPlayers()) do
		if p.UserId == userId then
			return p
		end
	end
	return nil
end

function BossColorView.start(data)
	clear()
	for _, p in ipairs(data.platforms) do
		local top = p.center.Y + p.size.Y / 2
		local part = track(Instance.new("Part"))
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.Material = Enum.Material.Neon
		part.Transparency = 0.35
		part.Size = Vector3.new(p.size.X - 0.4, 0.15, p.size.Z - 0.4)
		part.CFrame = CFrame.new(p.center.X, top + 0.08, p.center.Z)
		part.Parent = Workspace
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 70, 0, 70)
		gui.StudsOffset = Vector3.new(0, 3, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 300
		gui.Adornee = part
		gui.Parent = part
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBlack
		label.TextScaled = true
		label.TextStrokeTransparency = 0.1
		label.Parent = gui
		slabs[p.index] = { part = part, label = label }
		paint(slabs[p.index], p.color)
	end
	for _, m in ipairs(data.marks) do
		local target = playerByUserId(m.userId)
		local head = target and target.Character and target.Character:FindFirstChild("Head")
		if head then
			local mine = target == player
			local gui = track(Instance.new("BillboardGui"))
			gui.Name = "BossColorMark"
			gui.Size = UDim2.new(0, mine and 84 or 54, 0, mine and 96 or 54)
			gui.StudsOffset = Vector3.new(0, 4.6, 0)
			gui.AlwaysOnTop = true
			gui.Adornee = head
			gui.Parent = head
			local label = Instance.new("TextLabel")
			label.Size = UDim2.new(1, 0, 0, mine and 84 or 54)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.GothamBlack
			label.TextScaled = true
			label.Text = SYMBOLS[m.color]
			label.TextColor3 = COLORS[m.color]
			label.TextStrokeTransparency = 0
			label.TextStrokeColor3 = WHITE
			label.Parent = gui
			if mine then
				local bar = Instance.new("Frame")
				bar.Position = UDim2.new(0, 0, 1, -8)
				bar.Size = UDim2.new(1, 0, 0, 8)
				bar.BackgroundColor3 = COLORS[m.color]
				bar.BorderSizePixel = 0
				bar.Parent = gui
				TweenService:Create(bar, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 8) }):Play()
			end
			marks[m.userId] = gui
		end
	end
end

function BossColorView.flip(data)
	local entry = slabs[data.index]
	if not entry then
		return
	end
	paint(entry, data.color)
	BossFx.ring(entry.part.Position, 2, 9, COLORS[data.color], 0.3)
	local size = entry.part.Size
	entry.part.Size = size + Vector3.new(1.5, 0, 1.5)
	TweenService:Create(entry.part, TweenInfo.new(0.2), { Size = size }):Play()
end

function BossColorView.resolve(data)
	for _, id in ipairs(data.safe or {}) do
		local target = playerByUserId(id)
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root then
			BossFx.ring(root.Position - Vector3.new(0, 2.5, 0), 2, 8, Color3.fromRGB(120, 200, 255), 0.5)
		end
	end
	for _, id in ipairs(data.failed or {}) do
		local target = playerByUserId(id)
		local root = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
		if root then
			BossFx.puff(root.Position, 5, COLORS.red, 0.5, Vector3.new(0, 6, 0))
		end
	end
end

function BossColorView.finish()
	clear()
end

return BossColorView
