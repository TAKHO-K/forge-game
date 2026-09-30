-- A2-N4 P0-3 B안: 게임 안 표준 체형(ArtStyleV1Data.standardBody - 기본 끔 · Workspace Attribute StandardBodyV1 · 개발 /gg body std on|off).
--   켜져 있으면 캐릭터가 날 때 HumanoidDescription의 몸 파트(Torso · 팔 · 다리) = 0(기본 R15) · 배율 = 고정값으로 다시 입힌다.
--   머리 · 얼굴 · 머리카락 · 액세서리 · 피부색 · 옷은 그대로(겉모습만 - 판정 파트 HumanoidRootPart 크기 불변).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.data.ArtStyleV1Data).standardBody

workspace:SetAttribute(Config.attribute, Config.enabled)

local function apply(character)
	if workspace:GetAttribute(Config.attribute) ~= true then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end
	local ok, desc = pcall(function()
		return humanoid:GetAppliedDescription()
	end)
	if not ok or not desc then
		return
	end
	desc.Torso, desc.LeftArm, desc.RightArm, desc.LeftLeg, desc.RightLeg = 0, 0, 0, 0, 0
	for name, value in pairs(Config.scales) do
		desc[name] = value
	end
	local applied, err = pcall(function()
		humanoid:ApplyDescription(desc)
	end)
	if not applied then
		warn("[StandardBody] 적용 실패: " .. tostring(err))
	end
end

local function bind(player)
	player.CharacterAppearanceLoaded:Connect(apply)
end

for _, p in ipairs(Players:GetPlayers()) do
	bind(p)
end
Players.PlayerAdded:Connect(bind)
