-- M1-3 관문 등록 표시(클라 - 사람마다 등록 상태가 달라 로컬로 칠한다). 도형 = 서버(WorldMapLayout.buildBossGates) · 수치 = WorldMapData.bossGate · 색 = BossData gate.color.
--   빛기둥(Persistent): 등록 전 = 흐리게 깜빡(pillarDim · blinkSeconds) / 뒤 = 밝게 꾸준히(pillarLit) - 멀리서도 등록 여부가 보인다(토벌 관문도 같은 표지).
--   아치 문양(GateEmblem): 등록 전 꺼짐(어두운 회색 · 무광) / 뒤 켜짐(보스 색 네온).
--   등록 프롬프트(GateRegisterPrompt - 서버가 붙인다): 등록 전만 켠다(Enabled 로컬) · 가까이(hintDistance) 오면 "관문 등록 [F]" 큰 안내(폰 = 상호작용 버튼 안내).
--   첫 등록(서버 BossGateRegistered): 문양이 켜지는 짧은 연출(흰 섬광 → 보스 색 · 크기 1.6배 → 원래) + 화면 알림.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Toast = require(script.Parent.ui.kit.Toast)
local Theme = require(script.Parent.ui.kit.Theme)

local player = Players.LocalPlayer
local G = WorldMapData.bossGate
local OFF_COLOR = Color3.fromRGB(62, 62, 70)

local gateColor = {} -- [bossId] = Color3
for _, g in ipairs(WorldMapLayout.bossGates()) do
	gateColor[g.bossId] = Color3.fromRGB(g.color[1], g.color[2], g.color[3])
end

local pillars, emblems, prompts, hints = {}, {}, {}, {} -- [part/prompt] = bossId
local flashing = {} -- [bossId] = true(연출 중 - 칠하기를 건너뛴다)

local function registered()
	local set = {}
	for id in string.gmatch(player:GetAttribute("BossGatesRegistered") or "", "[^,]+") do
		set[id] = true
	end
	return set
end
local reg = registered()

local function paintEmblem(part, bossId)
	if flashing[bossId] then
		return
	end
	local on = reg[bossId] == true
	part.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
	part.Color = on and gateColor[bossId] or OFF_COLOR
end

local function paintAll()
	for part, id in pairs(emblems) do
		paintEmblem(part, id)
	end
	for prompt, id in pairs(prompts) do
		prompt.Enabled = not reg[id]
	end
end

-- 가까이 오면 큰 안내(등록 전만)
local function makeHint(anchor, bossId)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GateRegisterHint"
	gui.Size = UDim2.new(0, 300, 0, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 10, 0) -- 프롬프트 자리 위(관문 앞 허브 쪽)
	gui.MaxDistance = G.hintDistance
	gui.Parent = anchor
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Theme.font
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeColor3 = gateColor[bossId] or Color3.new(0, 0, 0)
	text.TextStrokeTransparency = 0
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	text.Text = touch and "관문 등록 - 버튼을 눌러요" or "관문 등록 [F]"
	text.Parent = gui
	hints[gui] = bossId
	gui.Enabled = not reg[bossId]
end

local function track(inst)
	if inst:IsA("BasePart") then
		local pillarId = inst:GetAttribute("GatePillar") and inst:GetAttribute("BossId")
		if pillarId then
			pillars[inst] = pillarId
		end
		local emblemId = inst:GetAttribute("GateEmblem")
		if emblemId then
			emblems[inst] = emblemId
			paintEmblem(inst, emblemId)
		end
		local promptId = inst:GetAttribute("GatePrompt")
		if promptId then
			makeHint(inst, promptId)
		end
	elseif inst:IsA("ProximityPrompt") and inst.Name == "GateRegisterPrompt" then
		local id = inst.Parent and inst.Parent:GetAttribute("GatePrompt")
		if id then
			prompts[inst] = id
			inst.Enabled = not reg[id]
		end
	end
end

local ground = Workspace:WaitForChild("Ground")
for _, d in ipairs(ground:GetDescendants()) do
	track(d)
end
ground.DescendantAdded:Connect(track)
ground.DescendantRemoving:Connect(function(inst)
	pillars[inst], emblems[inst], prompts[inst] = nil, nil, nil
end)

player:GetAttributeChangedSignal("BossGatesRegistered"):Connect(function()
	reg = registered()
	paintAll()
	for gui, id in pairs(hints) do
		if gui.Parent then
			gui.Enabled = not reg[id]
		else
			hints[gui] = nil
		end
	end
end)

-- 빛기둥: 등록 전 흐리게 깜빡 · 뒤 밝게 꾸준히
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	local wave = (math.sin(t * 2 * math.pi / G.blinkSeconds) + 1) / 2
	local dim = G.pillarDim[1] + (G.pillarDim[2] - G.pillarDim[1]) * wave
	for part, id in pairs(pillars) do
		if not flashing[id] then
			part.Transparency = reg[id] and G.pillarLit or dim
		end
	end
end)

-- 첫 등록 순간: 문양 섬광 · 빛기둥 번쩍 + 화면 알림
ReplicatedStorage:WaitForChild("BossGateRegistered").OnClientEvent:Connect(function(bossId)
	local g = WorldMapLayout.bossGate(bossId)
	if not g then
		return
	end
	flashing[bossId] = true
	local secs = G.registerFlashSeconds
	for part, id in pairs(emblems) do
		if id == bossId then
			local size = part.Size
			part.Material = Enum.Material.Neon
			part.Color = Color3.new(1, 1, 1)
			part.Size = size * 1.6
			TweenService:Create(part, TweenInfo.new(secs, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = size, Color = gateColor[id] }):Play()
		end
	end
	for part, id in pairs(pillars) do
		if id == bossId then
			part.Transparency = 0
			TweenService:Create(part, TweenInfo.new(secs), { Transparency = G.pillarLit }):Play()
		end
	end
	task.delay(secs + 0.05, function()
		flashing[bossId] = nil
		paintAll()
	end)
	Toast.push("TC", { text = G.registerText:format(g.name), grade = "important", seconds = 4 })
end)
