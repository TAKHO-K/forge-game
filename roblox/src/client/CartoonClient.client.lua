-- A1 카툰 스타일 클라 쪽: ① 외곽선 풀(OutlinePool - 조준 외곽선 포함 · 두 프로필 공통) ② 구역 색조(카툰 프로필에서만 - 서버가 만든 CartoonColorCorrection 위에
-- 이 클라 전용 ColorCorrection 하나로 구역마다 아주 옅게 · CartoonStyleData.zoneTint). 프로필 = Workspace Attribute CartoonStyle(서버 CartoonStyle.apply).

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local OutlinePool = require(script.Parent.OutlinePool)

OutlinePool.start()

local player = Players.LocalPlayer
local T = CartoonStyleData.zoneTint
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "CartoonZoneTint"
tint.Enabled = false
tint.Parent = Lighting -- 이 클라만(LocalScript가 만든 것은 복제 안 됨)
local currentKey = nil

local function zoneKeyAt(position)
	if WorldMapLayout.inHub(position) then
		return "hub"
	end
	local zone = WorldMapLayout.zoneAt(position)
	return zone and zone.key or nil
end

while true do
	local profile = CartoonStyleData.profiles[workspace:GetAttribute("CartoonStyle") or "base"]
	local on = profile ~= nil and profile.zoneTint == true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local key = on and root and zoneKeyAt(root.Position) or nil
	if key ~= currentKey then
		currentKey = key
		local c = key and T[key] or { 255, 255, 255 }
		tint.Enabled = on
		TweenService:Create(tint, TweenInfo.new(T.tweenSeconds), { TintColor = Color3.fromRGB(c[1], c[2], c[3]) }):Play()
	elseif not on and tint.Enabled then
		tint.Enabled = false
	end
	task.wait(0.5)
end
