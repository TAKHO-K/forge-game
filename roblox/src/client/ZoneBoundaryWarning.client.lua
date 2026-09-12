-- tier 구역 경계 진입 경고(16-6 지시 - "유저가 실수로 드래곤 구역에 들어가는 일이
-- 없어야 한다... 경계 진입 시 경고를 띄워라(구역 이름 + tier)"). 0.3초마다 플레이어
-- 위치가 어느 tier 구역 AABB 안에 있는지 확인하고, 구역이 바뀐 순간에만(계속 밟고
-- 있는 동안 매번 뜨지 않게) 토스트를 띄운다 - SaveNoticeHud.client.lua와 같은 패턴.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local CHECK_INTERVAL_SECONDS = 0.3
local DISPLAY_SECONDS = 2.5

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ZoneBoundaryWarningGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "ZoneWarningLabel"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.new(0.5, 0, 0, 100)
label.Size = UDim2.new(0, 420, 0, 48)
label.BackgroundColor3 = UIColors.panel
label.BackgroundTransparency = 1
label.TextTransparency = 1
label.BorderSizePixel = 0
label.Font = Enum.Font.GothamBold
label.TextSize = 18
label.TextColor3 = UIColors.textPrimary
label.Text = ""
label.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = label

local stroke = Instance.new("UIStroke")
stroke.Color = UIColors.rim
stroke.Transparency = 1
stroke.Parent = label

-- 어느 tier 구역 AABB 안에 있는지. 없으면 nil.
local function findTierZone(position)
	for _, zoneKey in ipairs(WorldConfig.tierZoneOrder) do
		local zone = WorldConfig.zones[zoneKey]
		if math.abs(position.X - zone.center.X) <= zone.halfSize
			and math.abs(position.Z - zone.center.Z) <= zone.halfSize then
			return zoneKey, zone
		end
	end
	return nil
end

local currentZoneKey = nil

local function showWarning(zoneKey, zone)
	local monster = MonsterData[zoneKey]
	label.Text = ("%s 구역 진입 - tier %d (%s)"):format(zoneKey:upper(), zone.tierIndex, monster.displayName)
	label.TextColor3 = monster.bodyColor
	local tweenIn = TweenInfo.new(0.15)
	TweenService:Create(label, tweenIn, { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()
	TweenService:Create(stroke, tweenIn, { Transparency = UIColors.rimTransparency }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text:find(monster.displayName, 1, true) then
			local tweenOut = TweenInfo.new(0.5)
			TweenService:Create(label, tweenOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			TweenService:Create(stroke, tweenOut, { Transparency = 1 }):Play()
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(CHECK_INTERVAL_SECONDS)
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart then
			local zoneKey = findTierZone(rootPart.Position)
			if zoneKey ~= currentZoneKey then
				currentZoneKey = zoneKey
				if zoneKey then
					showWarning(zoneKey, WorldConfig.zones[zoneKey])
				end
			end
		end
	end
end)
