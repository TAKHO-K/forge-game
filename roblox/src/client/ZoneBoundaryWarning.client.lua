-- 구역 진입 알림(16-6 지시 - "유저가 실수로 드래곤 구역에 들어가는 일이 없어야 한다...
-- 경계 진입 시 경고를 띄워라(구역 이름 + tier)" → 22-5 지시 "구역은 들어갈 때마다 어디에
-- 진입했다고 알려만 주기"로 담장이 사라진 뒤 유일한 구역 구분 수단이 됐다. tier 구역만이
-- 아니라 9구역 전부 알린다). 0.3초마다 플레이어 위치가 어느 구역 AABB 안에 있는지 확인하고,
-- 구역이 바뀐 순간에만(계속 밟고 있는 동안 매번 뜨지 않게) 토스트를 띄운다 -
-- SaveNoticeHud.client.lua와 같은 패턴.

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

-- 어느 구역 AABB 안에 있는지(복도는 nil).
local function findZone(position)
	for _, zoneKey in ipairs(WorldConfig.zoneOrder) do
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
	local text, color
	if zone.role == "tier" then
		local monster = MonsterData[zoneKey]
		text = ("%s 구역 진입 - tier %d"):format(monster.displayName, zone.tierIndex)
		color = monster.bodyColor
	else
		text = ("%s 진입"):format(zone.displayName or zoneKey)
		color = UIColors.textPrimary
	end
	label.Text = text
	label.TextColor3 = color
	local tweenIn = TweenInfo.new(0.15)
	TweenService:Create(label, tweenIn, { BackgroundTransparency = 0.15, TextTransparency = 0 }):Play()
	TweenService:Create(stroke, tweenIn, { Transparency = UIColors.rimTransparency }):Play()

	task.delay(DISPLAY_SECONDS, function()
		if label.Text == text then
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
			local zoneKey = findZone(rootPart.Position)
			if zoneKey ~= currentZoneKey then
				currentZoneKey = zoneKey
				if zoneKey then
					showWarning(zoneKey, WorldConfig.zones[zoneKey])
				end
			end
		end
	end
end)
