-- K1 궁극기(T) - 게이지 표시 · T 키 · 폰 버튼 자리(최종 배치 = U1) · 발동 연출(모든 클라 - 시전자 Player Attribute를 본다). 판정 · 게이지 = 서버(UltimateService).
--   게이지 = LocalPlayer Attribute UltGauge(0 ~ 100) · 요청 = SkillRequest:FireServer("T", 클릭 지점) · 결과 = SkillCastResult("T", …).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
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
label.Text = "T 0%"
label.ZIndex = 2
label.Parent = button

local function refresh()
	local value = player:GetAttribute("UltGauge") or 0
	local ratio = math.clamp(value / UltimateData.max, 0, 1)
	fill.Size = UDim2.new(1, 0, ratio, 0)
	label.Text = ratio >= 1 and "T 궁극기" or ("T %d%%"):format(math.floor(ratio * 100))
	stroke.Color = ratio >= 1 and Color3.fromRGB(255, 215, 90) or Color3.fromRGB(90, 90, 110)
end
player:GetAttributeChangedSignal("UltGauge"):Connect(refresh)
refresh()

local function request()
	if UIManager.isInputBlocked() or (player:GetAttribute("UltGauge") or 0) < UltimateData.max then
		return
	end
	local mouse = player:GetMouse()
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
