-- 머리 위 이름표(S12b D): "★n Lv.35 표시이름". 커스텀 BillboardGui - 기본 이름표는 서버(NameplateServer)가 끈다. 클릭은 없다(오터치 방지 - 이름 클릭 메뉴는 드랍 피드 · 태초 배너 · 파티창에서만).
-- 레벨 · 환생은 서버가 내려주는 Attribute(CharacterLevel · RebirthCount)를 그대로 읽는다 - 바뀌면 다시 그린다. 표시 거리 = SocialData.nameplate.maxDistanceStuds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local WorldLabelStyle = require(ReplicatedStorage.Shared.WorldLabelStyle)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local RunService = game:GetService("RunService")

local settings = SocialData.nameplate
local BILLBOARD_NAME = "PlayerNameplate"

-- D1 ⑤: 태초 착용 중(서버 Attribute PrimordialEquipped)이면 이름 앞에 자홍 태초 문양.
local GLYPH = ('<font color="#%s">%s</font> '):format(PrimordialData.accentColor:ToHex(), PrimordialData.glyph)

local function refresh(player, label)
	local text = PlayerLabelFormat.richText(player.DisplayName, player:GetAttribute("CharacterLevel"), player:GetAttribute("RebirthCount"), settings.textSize)
	label.Text = player:GetAttribute("PrimordialEquipped") and (GLYPH .. text) or text
end

-- D1(사용자 결정): 이름표 위 칭호 한 줄 - [칭호] 위 · [닉네임 Lv] 아래. 색 = 칭호 등급(장비 7등급 색) · 최상위는 흰 글자 위로 무지개 띠가 천천히 훑고 지나간다.
local flowing = {} -- 흐르는 그라데이션(UIGradient) 목록
local function shownTitle(player)
	local owned = {}
	for id in string.gmatch(player:GetAttribute("Titles") or "", "[^,]+") do
		owned[id] = true
	end
	for _, id in ipairs(TitleData.nameplateOrder) do
		if owned[id] and TitleData.titles[id] then
			return TitleData.titles[id]
		end
	end
	return nil
end

local function refreshTitle(player, titleGui, titleLabel)
	local title = shownTitle(player)
	titleGui.Enabled = title ~= nil
	local gradient = titleLabel:FindFirstChild("TopGradient")
	if not title then
		return
	end
	titleLabel.Text = title.name
	if TitleData.topGrades[title.grade] then
		titleLabel.TextColor3 = Color3.new(1, 1, 1)
		if not gradient then
			gradient = Instance.new("UIGradient")
			gradient.Name = "TopGradient"
			-- 흰 바탕 → 무지개 띠(가운데 좁게) → 흰 바탕: 오프셋이 흐르며 띠가 글자를 훑고 지나간다
			local rainbow = ItemVisualData.rainbowSequence.Keypoints
			local keys = { ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.3, Color3.new(1, 1, 1)) }
			for _, key in ipairs(rainbow) do
				table.insert(keys, ColorSequenceKeypoint.new(0.3 + key.Time * 0.4, key.Value))
			end
			table.insert(keys, ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)))
			gradient.Color = ColorSequence.new(keys)
			gradient.Parent = titleLabel
			table.insert(flowing, gradient)
		end
	else
		if gradient then
			gradient:Destroy()
		end
		titleLabel.TextColor3 = GradeColor.of(title.grade)
	end
end

RunService.Heartbeat:Connect(function()
	local phase = (os.clock() % TitleData.gradientSeconds) / TitleData.gradientSeconds
	for i = #flowing, 1, -1 do
		local gradient = flowing[i]
		if gradient.Parent then
			gradient.Offset = Vector2.new(phase * 2 - 1, 0) -- −1 → 1: 무지개 띠가 왼쪽 밖에서 들어와 오른쪽으로 빠진다
		else
			table.remove(flowing, i)
		end
	end
end)

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

	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "PlayerTitle"
	titleGui.Adornee = root
	titleGui.Size = UDim2.new(0, settings.width, 0, settings.height)
	titleGui.StudsOffsetWorldSpace = Vector3.new(0, settings.offsetStuds + TitleData.offsetStuds, 0)
	titleGui.AlwaysOnTop = false
	WorldLabelStyle.setupNameplateBillboard(titleGui, TitleData.maxDistanceStuds)
	titleGui.Parent = character -- 빌보드 안에 빌보드는 안 그려진다 - 캐릭터에 따로(캐릭터와 함께 사라진다)
	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Size = UDim2.new(1, 0, 1, 0)
	WorldLabelStyle.styleNameplateText(titleLabel, settings.textSize)
	titleLabel.Parent = titleGui
	refreshTitle(player, titleGui, titleLabel)

	local connections = {
		player:GetAttributeChangedSignal("Titles"):Connect(function()
			refreshTitle(player, titleGui, titleLabel)
		end),
		player:GetAttributeChangedSignal("CharacterLevel"):Connect(function()
			refresh(player, label)
		end),
		player:GetAttributeChangedSignal("RebirthCount"):Connect(function()
			refresh(player, label)
		end),
		player:GetAttributeChangedSignal("PrimordialEquipped"):Connect(function()
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
