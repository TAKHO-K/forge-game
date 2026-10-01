-- K1 궁극기(T) - 게이지 표시 · T 키 · 폰 버튼 자리(최종 배치 = U1) · 발동 연출(모든 클라 - 시전자 Player Attribute를 본다). 판정 · 게이지 = 서버(UltimateService).
--   게이지 = LocalPlayer Attribute UltGauge(0 ~ 100) · 요청 = SkillRequest:FireServer("T", 클릭 지점) · 결과 = SkillCastResult("T", …).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local SkillEffects = require(script.Parent.Parent.SkillEffects)
local UIManager = require(script.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local skillRequest = ReplicatedStorage:WaitForChild("SkillRequest")

-- ── 게이지 칩(스킬 줄 왼쪽 위 - 임시 자리 · U1에서 최종 배치) ──
local gui = Instance.new("ScreenGui")
gui.Name = "UltGaugeGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local button = Instance.new("TextButton")
button.Name = "UltButton"
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, -260, 1, -96)
button.Size = UDim2.fromOffset(64, 64)
button.BackgroundColor3 = Color3.fromRGB(28, 26, 40)
button.AutoButtonColor = false
button.Text = ""
button.Parent = gui
Instance.new("UICorner", button).CornerRadius = UDim.new(1, 0)
local stroke = Instance.new("UIStroke", button)
stroke.Thickness = 3
stroke.Color = Color3.fromRGB(90, 90, 110)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.AnchorPoint = Vector2.new(0.5, 1)
fill.Position = UDim2.new(0.5, 0, 1, 0)
fill.Size = UDim2.new(1, 0, 0, 0)
fill.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
fill.BackgroundTransparency = 0.35
fill.BorderSizePixel = 0
fill.Parent = button
Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

local label = Instance.new("TextLabel")
label.Name = "Label"
label.BackgroundTransparency = 1
label.Size = UDim2.fromScale(1, 1)
label.Font = Enum.Font.GothamBold
label.TextSize = 16
label.TextColor3 = Color3.new(1, 1, 1)
label.Text = Text.get("hud.ult.percent", { percent = "0" })
label.ZIndex = 2
label.Parent = button

local function refresh()
	local value = player:GetAttribute("UltGauge") or 0
	local ratio = math.clamp(value / UltimateData.max, 0, 1)
	fill.Size = UDim2.new(1, 0, ratio, 0)
	label.Text = ratio >= 1 and Text.get("hud.ult.full") or Text.get("hud.ult.percent", { percent = ("%d"):format(math.floor(ratio * 100)) })
	stroke.Color = ratio >= 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(90, 90, 110)
end
player:GetAttributeChangedSignal("UltGauge"):Connect(refresh)
refresh()

-- QUEUE-ALL2 P2 중복 삭제: 따로 떠 있던 "T 0%" 원 → 스킬 줄 T 칸(SkillSlotsGui Slot_locked2 - Q · E · R 다음 칸) 안 게이지로 합친다(같은 버튼 · T 키 · 컷인 그대로)
task.spawn(function()
	local slots = player.PlayerGui:WaitForChild("SkillSlotsGui", 30)
	local slot = slots and slots:FindFirstChild("Slot_locked2", true)
	while slots and not slot do
		slots.DescendantAdded:Wait()
		slot = slots:FindFirstChild("Slot_locked2", true)
	end
	if not slot then
		return
	end
	button.AnchorPoint = Vector2.new(0, 0)
	button.Position = UDim2.fromScale(0, 0)
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = slot.ZIndex + 5
	for _, c in ipairs(button:GetChildren()) do
		if c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0, 10)
		end
	end
	for _, c in ipairs(fill:GetChildren()) do
		if c:IsA("UICorner") then
			c.CornerRadius = UDim.new(0, 10)
		end
	end
	fill.ZIndex = button.ZIndex + 1
	label.ZIndex = button.ZIndex + 2
	label.TextSize = 14
	button.Parent = slot
	slot.Name = "Slot_t" -- 칸 이름도 T로(점검 · 캡처)
	-- QUEUE-ALL3 Q9: T 칸도 정보 카드(PC 마우스 올림 · 폰 길게 누름 - 짧게 누름 = 발동 그대로)
	require(script.Parent.SkillTooltip).attach(button, "t", nil, function()
		return require(script.Parent.Parent.ui.kit.Theme).isMobile
	end)
end)

-- 가득 참 발광(묶음 F1): 테두리 맥동
game:GetService("RunService").RenderStepped:Connect(function()
	local full = (player:GetAttribute("UltGauge") or 0) >= UltimateData.max
	stroke.Thickness = full and (3 + 1.5 * (1 + math.sin(os.clock() * 6))) or 3
end)

-- 발동 컷인(묶음 F1 · 0.3초 이내): 내 궁극기가 서버에서 받아들여지면 이름을 화면 가운데 잠깐
local cutin = Instance.new("TextLabel")
cutin.Name = "UltCutin"
cutin.AnchorPoint = Vector2.new(0.5, 0.5)
cutin.Position = UDim2.fromScale(0.5, 0.38)
cutin.Size = UDim2.fromOffset(520, 70)
cutin.BackgroundTransparency = 1
cutin.Font = Enum.Font.GothamBlack
cutin.TextSize = 44
cutin.TextColor3 = Color3.fromRGB(255, 225, 120)
cutin.TextStrokeTransparency = 0.2
cutin.Visible = false
cutin.Parent = gui
ReplicatedStorage:WaitForChild("SkillCastResult").OnClientEvent:Connect(function(slot, data)
	if slot ~= "T" or not data.ok or data.kind == "ultHit" then
		return
	end
	local classId = player:GetAttribute("ClassId")
	local def = classId and UltimateData.skills[classId]
	cutin.Text = def and Text.name(def.name) or Text.get("hud.ult.name")
	cutin.Visible = true
	task.delay(0.3, function()
		cutin.Visible = false
	end)
end)

local function request()
	if UIManager.isInputBlocked() or (player:GetAttribute("UltGauge") or 0) < UltimateData.max then
		return
	end
	local mouse = player:GetMouse()
	-- A2-M1: 궁극기 몸 모션(내 화면 즉시 · 남 = 중계 skillT - 그리기만 · 판정은 서버 SkillCastResult)
	local WeaponVisual = require(script.Parent.Parent.WeaponVisual)
	if WeaponVisual.playSkill(nil, "T") then
		local fx = game:GetService("ReplicatedStorage"):FindFirstChild("AirMoveFx")
		if fx then
			fx:FireServer("skillT")
		end
	end
	skillRequest:FireServer("T", mouse and mouse.Hit and mouse.Hit.Position or nil) -- 활 = 클릭 지점(서버가 거리 검사) · 나머지는 무시
end
button.Activated:Connect(request)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.T then
		request()
	end
end)

-- ── 발동 연출(모든 클라) ──
local function accent(p)
	local classId = p:GetAttribute("ClassId")
	return (classId and UIColors.classAccent[classId]) or Color3.fromRGB(255, 200, 80)
end

local function parseCenter(text)
	local x, y, z = (text or ""):match("^([%-%d%.]+),([%-%d%.]+),([%-%d%.]+)")
	return x and Vector3.new(tonumber(x), tonumber(y), tonumber(z)) or nil
end

local function disc(center, radius, color, seconds, transparency)
	local part = Instance.new("Part")
	part.Name = "UltZone"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, radius * 2, radius * 2)
	part.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency
	part.Parent = Workspace
	task.delay(seconds, function()
		part:Destroy()
	end)
end

local function watchPlayer(p)
	p:GetAttributeChangedSignal("UltRain"):Connect(function()
		local center = parseCenter(p:GetAttribute("UltRain"))
		local def = UltimateData.skills.bow
		if center then
			disc(center, def.radiusStuds, accent(p), def.durationSeconds, 0.75) -- 보이는 원 = 판정 원
			for i = 0, def.tickCount - 1 do
				task.delay(i * def.durationSeconds / def.tickCount, function()
					SkillEffects.expandingRing(center, def.radiusStuds * (0.4 + 0.6 * math.random()), accent(p), 0.25)
				end)
			end
		end
	end)
	p:GetAttributeChangedSignal("UltSanctuary"):Connect(function()
		local center = parseCenter(p:GetAttribute("UltSanctuary"))
		local def = UltimateData.skills.healer
		if center then
			disc(center, def.radiusStuds, Color3.fromRGB(140, 255, 170), def.durationSeconds, 0.7)
		end
	end)
	p:GetAttributeChangedSignal("UltTransform"):Connect(function()
		local character = p.Character
		if p:GetAttribute("UltTransform") and character then
			SkillEffects.selfBuffAura(character, 5, accent(p), UltimateData.skills.greatsword.durationSeconds)
		end
	end)
end
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end
Players.PlayerAdded:Connect(watchPlayer)
