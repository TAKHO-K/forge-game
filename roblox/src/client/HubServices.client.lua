-- QUEUE-ALL7B 2 마을 기능 지점(HubServiceData): 자리 기둥(Spot)에 프롬프트(PC E · 폰 탭) + 머리 위 기능 아이콘 + 첫 방문 소개 한 줄.
--   누르면 그 창 · 탭을 연다(창을 여는 것뿐 - 받기 · 도전 같은 행동은 창 안에서 서버가 다시 판정한다). 단축키(L 등) · 창 안 길은 그대로.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.HubServiceData)
local HubArtData = require(ReplicatedStorage.Shared.data.HubArtData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.ui.ArtImage)
local Toast = require(script.Parent.ui.kit.Toast)
local SettingSave = require(script.Parent.ui.SettingSave)
local UIManager = require(script.Parent.UIManager)

local player = Players.LocalPlayer
local PROMPT_NAME = "HubServicePrompt"

local OPEN = {
	leaderboard = function()
		return require(script.Parent.panels.Leaderboard).open()
	end,
	settings = function(focus)
		return require(script.Parent.panels.Settings).open(focus)
	end,
	quests = function(focus)
		return require(script.Parent.panels.Quests).open(focus)
	end,
	character = function(focus)
		return require(script.Parent.panels.Character).open(focus)
	end,
}

local byId = {}
for _, s in ipairs(D.services) do
	byId[s.id] = s
end

local function attach(part, s)
	if part:FindFirstChild(PROMPT_NAME) then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = PROMPT_NAME
	prompt:SetAttribute("HubService", s.id)
	prompt.ActionText = Text.get(s.actionKey)
	prompt.ObjectText = Text.get(s.nameKey)
	prompt.MaxActivationDistance = D.promptDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	local icon = Instance.new("BillboardGui")
	icon.Name = "HubServiceIcon"
	icon.Size = UDim2.fromOffset(34, 34)
	icon.MaxDistance = 160
	icon.Parent = part
	local function lift() -- QUEUE-ALL7B 3: 메시(NPC · 게시판)가 서면 그 꼭대기 위(server/HubArt TagTop)
		local top = part:GetAttribute("TagTop")
		icon.StudsOffsetWorldSpace = Vector3.new(0, top and (WorldMapData.floorTopY + top + HubArtData.iconGap - part.Position.Y) or D.iconOffsetY, 0)
	end
	lift()
	part:GetAttributeChangedSignal("TagTop"):Connect(lift)
	local img = ArtImage.label(icon, s.icon, UDim2.fromScale(1, 1), "!")
	img.BackgroundTransparency = 1
end

local function relabel()
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.Name == PROMPT_NAME then
			local s = byId[d:GetAttribute("HubService")]
			if s then
				d.ActionText = Text.get(s.actionKey)
				d.ObjectText = Text.get(s.nameKey)
			end
		end
	end
end

local spots = {} -- [service id] = 자리 파트
local function consider(inst)
	if not inst:IsA("BasePart") then
		return
	end
	local spotId = inst:GetAttribute("Spot")
	for _, s in ipairs(D.services) do
		if s.spot == spotId then
			spots[s.id] = inst
			attach(inst, s)
		end
	end
end
for _, d in ipairs(Workspace:GetDescendants()) do
	consider(d)
end
Workspace.DescendantAdded:Connect(consider)
player:GetAttributeChangedSignal(Text.languageAttribute):Connect(relabel)
Workspace:GetAttributeChangedSignal(Text.devLanguageAttribute):Connect(relabel)

ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
	if who ~= player or prompt.Name ~= PROMPT_NAME then
		return
	end
	local s = byId[prompt:GetAttribute("HubService")]
	local open = s and OPEN[s.panel]
	if open and not UIManager.isOpen(s.panel) then
		open(s.focus)
	end
end)

-- 첫 방문 소개 한 줄(서비스마다 한 번 · 설정 키로 재접속 유지 - 설정이 로드되기 전에는 기다린다)
task.spawn(function()
	while true do
		task.wait(1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			for _, s in ipairs(D.services) do
				local part = spots[s.id]
				local attr = "HubIntroSeen_" .. s.id -- 설정 로드 전 = nil(기다림) · 로드 뒤 안 봄 = false
				if part and part.Parent and player:GetAttribute(attr) == false and (part.Position - root.Position).Magnitude <= D.introRadius then
					SettingSave(s.intro, true)
					Toast.push("TC", { text = Text.get(s.introKey), colorName = "textPrimary", seconds = 4 })
				end
			end
		end
	end
end)
