-- QUEUE-ALL1 P3 §3 균열 시간(클라 - 화면만 · 판정 · 리더보드 불변): Workspace RiftActive(서버 RiftService)를 따라
--   ① DropTable.activeBoost = 균열 배율(이 화면의 확률 공개 창 = 서버 굴림과 같은 표) ② 분위기(하늘 시각 · 대기 · 색조 - 보스전 중에는 아레나 꾸미기가 우선)
--   ③ 구역 날씨 입자(카메라 주변 · BossFx 풀 · 폰 × phoneParticleScale · 아레나 = 그 보스 구역 날씨 · 안개 상한 arenaFogCap) ④ 번개 번쩍임(초당 maxFlashPerSecond 미만 · 번쩍임 줄이기 = 없음)
--   ⑤ 남은 시간 HUD("균열 m:ss") ⑥ 시작 · 끝 배너(RiftBanner). 수치 = shared/data/RiftData.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local RiftData = require(ReplicatedStorage.Shared.data.RiftData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Layout = require(ReplicatedStorage.Shared.WorldMapLayout)
local BossFx = require(script.Parent.BossFx)
local Toast = require(script.Parent.ui.kit.Toast)
local Theme = require(script.Parent.ui.kit.Theme)

local player = Players.LocalPlayer
local moodWas = nil
local tint = nil

local function isPhone()
	local cam = Workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return UserInputService.TouchEnabled and math.min(vp.X, vp.Y) < 500
end

local function inBoss()
	return player:GetAttribute("BossEncounterId") ~= nil
end

-- ② 분위기(보스전 밖에서만 - 아레나는 BossArenaDressing이 대기 · 하늘을 맡는다)
local function setMood(on)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local M = RiftData.mood
	if on and not moodWas and not inBoss() then
		moodWas = { clock = Lighting.ClockTime, brightness = Lighting.Brightness, atmo = atmo and { atmo.Density, atmo.Haze, atmo.Color } }
		Lighting.ClockTime = M.clockTime
		Lighting.Brightness = Lighting.Brightness * M.brightnessScale
		if atmo then
			atmo.Density, atmo.Haze, atmo.Color = M.atmosphereDensity, M.atmosphereHaze, M.atmosphereColor
		end
		tint = Instance.new("ColorCorrectionEffect")
		tint.Name = "RiftTint"
		tint.TintColor = M.tint
		tint.Parent = Lighting
	elseif not on and moodWas then
		Lighting.ClockTime = moodWas.clock
		Lighting.Brightness = moodWas.brightness
		if atmo and moodWas.atmo then
			atmo.Density, atmo.Haze, atmo.Color = moodWas.atmo[1], moodWas.atmo[2], moodWas.atmo[3]
		end
		if tint then
			tint:Destroy()
			tint = nil
		end
		moodWas = nil
	end
end

-- ⑤ 남은 시간 HUD
local gui = Instance.new("ScreenGui")
gui.Name = "RiftHud"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")
local timer = Instance.new("TextLabel")
timer.Name = "RiftTimer"
timer.AnchorPoint = Vector2.new(0.5, 0)
timer.Position = UDim2.new(0.5, 0, 0, 6)
timer.Size = UDim2.fromOffset(150, 26)
timer.BackgroundColor3 = Color3.fromRGB(46, 30, 70)
timer.BackgroundTransparency = 0.2
timer.TextColor3 = Color3.fromRGB(230, 210, 255)
timer.Font = Theme.font
timer.TextSize = 16
timer.Visible = false
timer.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(1, 0)
corner.Parent = timer

-- ③ 지금 날씨(구역 · 아레나)
local function weatherNow()
	if inBoss() then
		for _, m in ipairs(Workspace:GetChildren()) do
			local rig = m:IsA("Model") and m:GetAttribute("BossRig")
			if rig and m:GetAttribute("BossEncounterId") == player:GetAttribute("BossEncounterId") then
				local b = BossData.bosses[rig]
				return RiftData.weather[RiftData.weatherByZone[b and b.gate and b.gate.zone or ""] or ""], true
			end
		end
		return nil, true
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, false
	end
	local z = Layout.zoneAt(root.Position)
	return RiftData.weather[RiftData.weatherByZone[z and z.key or "hub"] or ""], false
end

local spawnAt, flashAt = 0, 0
local function weatherStep(now)
	local W, arena = weatherNow()
	if not W then
		return
	end
	local every = W.every / (isPhone() and RiftData.phoneParticleScale or 1) / (arena and 0.5 or 1)
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	local n = 0
	while spawnAt < now and n < 6 do
		spawnAt += every
		n += 1
		local a, r = math.random() * math.pi * 2, math.sqrt(math.random()) * RiftData.particleRadius
		local base = cam.Focus.Position + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local v = Vector3.new(0, -W.fall, 0) + W.wind
		if W.shape == "streak" then
			BossFx.streak(base + Vector3.new(0, 18 + math.random() * 10, 0), v, math.max(v.Magnitude * 0.06, 1), W.size, W.color, W.life, v.Magnitude)
		else
			BossFx.spawn({ shape = W.shape, position = base + Vector3.new(0, W.fall > 0 and (14 + math.random() * 10) or math.random() * 4, 0), velocity = v,
				size0 = Vector3.one * W.size, size1 = Vector3.one * W.size * 0.6, color = W.color, transparency0 = W.transparency or 0.2, transparency1 = 1,
				life = W.life, material = W.material or Enum.Material.SmoothPlastic, spin = W.shape == "block" and 3 or nil })
		end
	end
	if spawnAt < now - 1 then
		spawnAt = now
	end
	-- ④ 번개 번쩍임(뇌우만 · 초당 상한 · 번쩍임 줄이기 = 없음)
	if W.flashEvery and now >= flashAt and player:GetAttribute("ReduceFlashes") ~= true then
		flashAt = now + math.max(W.flashEvery * (0.6 + math.random() * 0.8), 1 / RiftData.maxFlashPerSecond)
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Brightness = 0.12
		cc.Parent = Lighting
		task.delay(0.08, function()
			cc:Destroy()
		end)
	end
	-- 안개(아레나 = 상한)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo and W.fogDensity then
		atmo.Density = math.max(atmo.Density, arena and math.min(W.fogDensity, RiftData.arenaFogCap) or W.fogDensity)
	end
end

local active = false
local function apply()
	active = Workspace:GetAttribute("RiftActive") == true
	DropTable.activeBoost = active and RiftData.gradeMultiplier or nil -- ① 이 화면의 확률 공개 = 서버 굴림 표
	DropTable.gainOnly = (Players.LocalPlayer:GetAttribute("RebirthCount") or 0) == 0 -- QUEUE-ALL1 R1: 첫 환생 전 = 이득만(서버 굴림과 같은 규칙)
	setMood(active)
	timer.Visible = active
end
Workspace:GetAttributeChangedSignal("RiftActive"):Connect(apply)
player:GetAttributeChangedSignal("RebirthCount"):Connect(apply) -- QUEUE-ALL1 R1 첫 환생 뒤 = 보통 균열 표
player:GetAttributeChangedSignal("BossEncounterId"):Connect(function()
	setMood(false)
	if active then
		setMood(true)
	end
end)
apply()

ReplicatedStorage:WaitForChild("RiftBanner").OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end
	Toast.push("TC", { richParts = { { text = info.kind == "start" and RiftData.text.start or RiftData.text.finish, color = Color3.fromRGB(214, 180, 255), bold = true } },
		seconds = RiftData.bannerSeconds, fadeSeconds = 0.4 })
end)

RunService.RenderStepped:Connect(function()
	if not active then
		return
	end
	local now = os.clock()
	local endsAt = Workspace:GetAttribute("RiftEndsAt")
	if type(endsAt) == "number" then
		local left = math.max(0, endsAt - os.time())
		timer.Text = RiftData.text.timer:format(left // 60, left % 60)
	end
	weatherStep(now)
end)
