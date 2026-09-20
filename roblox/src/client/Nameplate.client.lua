-- 머리 위 이름표(S12b D): "★n Lv.35 표시이름". 커스텀 BillboardGui - 기본 이름표는 서버(NameplateServer)가 끈다. 클릭은 없다(오터치 방지 - 이름 클릭 메뉴는 드랍 피드 · 태초 배너 · 파티창에서만).
-- 레벨 · 환생은 서버가 내려주는 Attribute(CharacterLevel · RebirthCount)를 그대로 읽는다 - 바뀌면 다시 그린다. 표시 거리 = SocialData.nameplate.maxDistanceStuds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)

local settings = SocialData.nameplate
local BILLBOARD_NAME = "PlayerNameplate"

local function refresh(player, label)
	label.Text = PlayerLabelFormat.richText(player.DisplayName, player:GetAttribute("CharacterLevel"), player:GetAttribute("RebirthCount"), settings.textSize)
end

local function attach(player, character)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root or character:FindFirstChild(BILLBOARD_NAME) then
		return
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Name = BILLBOARD_NAME
	billboard.Adornee = root
	billboard.Size = UDim2.new(0, settings.width, 0, settings.height)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, settings.offsetStuds, 0)
	billboard.AlwaysOnTop = false
	WorldLabelStyle.setupNameplateBillboard(billboard, settings.maxDistanceStuds)
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.RichText = true
	WorldLabelStyle.styleNameplateText(label, settings.textSize)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Parent = billboard
	refresh(player, label)

	local connections = {
		player:GetAttributeChangedSignal("CharacterLevel"):Connect(function()
			refresh(player, label)
		end),
		player:GetAttributeChangedSignal("RebirthCount"):Connect(function()
			refresh(player, label)
		end),
		player:GetPropertyChangedSignal("DisplayName"):Connect(function()
			refresh(player, label)
		end),
	}
	billboard.Destroying:Connect(function()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end)
end

local function watch(player)
	if player.Character then
		task.spawn(attach, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		attach(player, character)
	end)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end
