-- QUEUE-ALL2 P4 2순위: 장비 줍기 빛 구슬(docs/visual-audit.md 16). 줍기는 서버가 판정한다(ItemDropServer) - 여기는 그 신호(ItemPickedUp)를 한 번 더 듣고 그리기만 한다.
--   줍기 신호에는 자리가 없다 → 땅 드랍 모델(Workspace ItemDrop)의 자리를 기억해 두고, 신호 직전 · 직후 matchSeconds 안에 내 근처에서 사라진 같은 등급 드랍과 짝짓는다.
--   구슬 = 등급색 작은 빛 공이 드랍 자리(화면 투영) → 가방 버튼(MenuBarGui.MenuBar.MenuButton_inventory)으로 위로 휘며 0.4초 · 도착하면 버튼 팝 + pickup 소리.
--   minGrade(영웅) 이상만 · 동시 maxLive개 · 아트 끔 · 연출 세기 끔 = 없음(0.5 = 구슬 작게). 짝이 없거나 화면 밖이면 건너뜀.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local O = require(ReplicatedStorage.Shared.data.FxMomentData).pickupOrb
local FxMoment = require(script.Parent.FxMoment)
local SoundSheet = require(script.Parent.SoundSheet)

local player = Players.LocalPlayer
local MATCH_STUDS = 40 -- 내 캐릭터에서 이 안에서 사라진 드랍만(펫 자동 줍기 반경 포함 여유)

local gradeIndex = {}
for i, id in ipairs(ArmorData.gradeOrder) do
	gradeIndex[id] = i
end

-- 땅 드랍 자리 기억(0.25초마다 · 몇 개뿐)
local drops = {} -- [model] = { pos, grade }
local removed = {} -- { pos, grade, at }
local pickedUp = {} -- { grade, at } - 드랍 사라짐보다 신호가 먼저 온 경우

local function remember(model)
	local ok, pivot = pcall(model.GetPivot, model)
	local d = drops[model]
	if d and ok then
		d.pos = pivot.Position
	end
	if d then
		d.grade = model:GetAttribute("DropGrade") or d.grade
	end
end

local function track(inst)
	if inst:IsA("Model") and inst.Name == "ItemDrop" then
		drops[inst] = { grade = inst:GetAttribute("DropGrade") }
		remember(inst)
	end
end
for _, inst in ipairs(Workspace:GetChildren()) do
	track(inst)
end
Workspace.ChildAdded:Connect(track)

local live = 0
local gui

local function orbGui()
	if gui and gui.Parent then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "PickupOrbGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 45 -- 메뉴바 위
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function bagButton()
	local menuGui = player.PlayerGui:FindFirstChild("MenuBarGui")
	local bar = menuGui and menuGui:FindFirstChild("MenuBar")
	local button = bar and bar:FindFirstChild("MenuButton_inventory", true)
	return button and button.Visible and button.AbsoluteSize.X > 0 and button or nil
end

local function fly(worldPos, grade)
	local strength = FxMoment.scale()
	local button = bagButton()
	local camera = Workspace.CurrentCamera
	if strength <= 0 or not button or not camera or live >= O.maxLive then
		return
	end
	local screen, onScreen = camera:WorldToScreenPoint(worldPos)
	if not onScreen then
		return
	end
	local g = orbGui()
	local from = Vector2.new(screen.X, screen.Y)
	local to = button.AbsolutePosition + button.AbsoluteSize / 2 - g.AbsolutePosition
	local control = (from + to) / 2 - Vector2.new(0, O.arcPixels)
	local size = O.size * (0.6 + 0.4 * strength)
	local visual = ItemVisualData.gradeVisuals[grade]
	local orb = Instance.new("Frame")
	orb.Name = "PickupOrb"
	orb.AnchorPoint = Vector2.new(0.5, 0.5)
	orb.Size = UDim2.fromOffset(size, size)
	orb.BackgroundColor3 = visual and visual.color or Color3.new(1, 1, 1)
	orb.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = orb
	local glow = Instance.new("UIStroke")
	glow.Color = Color3.new(1, 1, 1)
	glow.Thickness = 2
	glow.Transparency = 0.3
	glow.Parent = orb
	local core = Instance.new("Frame") -- 흰 속
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.45, 0.45)
	core.BackgroundColor3 = Color3.new(1, 1, 1)
	core.BorderSizePixel = 0
	local coreCorner = Instance.new("UICorner")
	coreCorner.CornerRadius = UDim.new(1, 0)
	coreCorner.Parent = core
	core.Parent = orb
	orb.Position = UDim2.fromOffset(from.X, from.Y)
	orb.Parent = g
	live += 1
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = math.clamp((os.clock() - t0) / O.seconds, 0, 1)
		local e = t * t -- 빨려 들어가듯 점점 빠르게
		local p = from:Lerp(control, e):Lerp(control:Lerp(to, e), e)
		orb.Position = UDim2.fromOffset(p.X, p.Y)
		orb.Size = UDim2.fromOffset(size * (1 - 0.4 * e), size * (1 - 0.4 * e))
		if t >= 1 then
			conn:Disconnect()
			orb:Destroy()
			live -= 1
			FxMoment.pop(button, O.arrivePop.scale, O.arrivePop.seconds, strength)
			SoundSheet.play("pickup", { minInterval = 0.08 })
		end
	end)
end

local function near(pos)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root and (root.Position - pos).Magnitude <= MATCH_STUDS
end

local function eligible(grade)
	return (gradeIndex[grade] or 0) >= O.minGrade
end

Workspace.ChildRemoved:Connect(function(inst)
	local d = drops[inst]
	if not d then
		return
	end
	drops[inst] = nil
	if not d.pos or not near(d.pos) then
		return
	end
	local now = os.clock()
	for i, p in ipairs(pickedUp) do -- 신호가 먼저 왔다
		if now - p.at <= O.matchSeconds and p.grade == d.grade then
			table.remove(pickedUp, i)
			fly(d.pos, d.grade)
			return
		end
	end
	table.insert(removed, { pos = d.pos, grade = d.grade, at = now })
	if #removed > 8 then
		table.remove(removed, 1)
	end
end)

task.spawn(function()
	local remote = ReplicatedStorage:WaitForChild("ItemPickedUp", 30)
	if not remote then
		return
	end
	remote.OnClientEvent:Connect(function(item)
		if type(item) ~= "table" or not eligible(item.grade) or not FxMoment.isOn() then
			return
		end
		local now = os.clock()
		for i = #removed, 1, -1 do -- 드랍이 먼저 사라졌다(보통)
			local r = removed[i]
			if now - r.at <= O.matchSeconds and r.grade == item.grade then
				table.remove(removed, i)
				fly(r.pos, r.grade)
				return
			end
		end
		table.insert(pickedUp, { grade = item.grade, at = now })
		if #pickedUp > 8 then
			table.remove(pickedUp, 1)
		end
	end)
end)

-- 자리 갱신(튀어 오름 · 착지 뒤 자리)
task.spawn(function()
	while true do
		task.wait(0.25)
		for model in pairs(drops) do
			remember(model)
		end
	end
end)
