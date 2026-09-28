-- QUEUE-10h Q8 K3 영혼 모습(그리기만 - 판정은 서버 SoulService): Player Attribute SoulState인 사람의 캐릭터를 반투명(SoulData.transparency) + 이름표 옅게.
--   모든 사람의 화면에서 같게 보인다(각 클라가 같은 Attribute를 보고 로컬로 그린다). 풀리면 원래 투명도로.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoulData = require(ReplicatedStorage.Shared.data.SoulData)

local ORIGINAL = "SoulOrigTransparency"

local function apply(character, on)
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			if on then
				if d:GetAttribute(ORIGINAL) == nil then
					d:SetAttribute(ORIGINAL, d.Transparency)
				end
				local base = d:GetAttribute(ORIGINAL)
				d.Transparency = base >= 1 and base or math.max(base, SoulData.transparency)
			elseif d:GetAttribute(ORIGINAL) ~= nil then
				d.Transparency = d:GetAttribute(ORIGINAL)
				d:SetAttribute(ORIGINAL, nil)
			end
		end
	end
end

local function watch(player)
	local function refresh()
		if player.Character then
			apply(player.Character, player:GetAttribute("SoulState") == true)
		end
	end
	player:GetAttributeChangedSignal("SoulState"):Connect(refresh)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 5)
		task.wait(0.2)
		refresh()
	end)
	refresh()
end

for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
Players.PlayerAdded:Connect(watch)
