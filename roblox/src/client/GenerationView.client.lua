-- C5-6 세대 표시(클라 - 연출만 · 판정 없음): 내 스테이지(Player Attribute InfiniteStage)의 세대(shared/StageGeneration)에 따라 곁의 잡몹 몸통을 세대 틴트로 물들이고,
--   조준 이름표(AimTarget이 Humanoid.DisplayName을 읽는다)에 세대 접두사를 붙인다. 잡몹은 사람마다 스테이지가 다르므로(C1 기준 스테이지) 몹 자체가 아니라 "내 화면"이 세대를 입는다.
--   세대 전(스테이지 < 17,000)이면 아무것도 안 바꾼다(원래 색 · 이름 그대로).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local StageGeneration = require(ReplicatedStorage.Shared.StageGeneration)
local Text = require(ReplicatedStorage.Shared.Text)
local Toast = require(script.Parent.ui.kit.Toast)

local player = Players.LocalPlayer
local painted = {} -- [Model] = { parts = { [BasePart] = 원래 색 }, name = 원래 DisplayName, index }
local currentIndex = 0

local function restore(model)
	local record = painted[model]
	if not record then
		return
	end
	for part, color in pairs(record.parts) do
		if part.Parent then
			part.Color = color
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and record.name then
		humanoid.DisplayName = record.name
	end
	if record.label and record.label.Parent and record.labelText then
		record.label.Text = record.labelText
		if record.label:GetAttribute("WorldTextPrefix") then -- QUEUE-ALL6R 3: 앞말을 떼고 지금 언어로 다시
			record.label:SetAttribute("WorldTextPrefix", nil)
			record.label:SetAttribute("WorldTextApplied", nil)
			Text.applyLabel(record.label)
		end
	end
	painted[model] = nil
end

local function paint(model, generation)
	if model:GetAttribute("IsBoss") or model:GetAttribute("IsChest") then
		return
	end
	local record = painted[model]
	if record and record.index == generation.index then
		return
	end
	if record then
		restore(model)
	end
	record = { parts = {}, index = generation.index }
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			record.parts[part] = part.Color
			part.Color = part.Color:Lerp(generation.tint, generation.tintAlpha)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		record.name = humanoid.DisplayName
		if humanoid.DisplayName ~= "" and not humanoid.DisplayName:find(generation.prefix, 1, true) then
			humanoid.DisplayName = generation.prefix .. " " .. humanoid.DisplayName
		end
	end
	-- 묶음 A Play 1: 조준 이름표는 NameplateGui.NameLabel 글씨를 그대로 보여 준다(AimTarget) - 여기에도 앞말
	local nameplate = model:FindFirstChild("NameplateGui", true)
	local label = nameplate and nameplate:FindFirstChild("NameLabel")
	if label and label:IsA("TextLabel") then
		label:SetAttribute("WorldTextPrefix", nil) -- QUEUE-ALL6R 3: 내 언어 이름(Text.applyLabel) 위에 앞말 - 언어가 바뀌어 다시 써도 앞말이 남게 속성으로
		label:SetAttribute("WorldTextApplied", nil)
		Text.applyLabel(label)
		record.label, record.labelText = label, label.Text
		if label:GetAttribute("WorldTextApplied") then
			label:SetAttribute("WorldTextPrefix", generation.prefix)
			label:SetAttribute("WorldTextApplied", nil)
			Text.applyLabel(label)
		elseif not label.Text:find(generation.prefix, 1, true) then
			label.Text = generation.prefix .. " " .. label.Text
		end
	end
	painted[model] = record
end

local function refresh()
	local stage = player:GetAttribute("InfiniteStage")
	local generation = StageGeneration.forStage(stage)
	local newIndex = generation and generation.index or 0
	if newIndex > 0 and newIndex ~= currentIndex then -- 새 세대에 들어섰다(내 스테이지 기준) - 토스트 1회
		Toast.push("TC", { text = Text.get("generation.enter", { name = generation.prefix, index = tostring(newIndex) }), colorName = "gold", seconds = 4, fadeSeconds = 0.4 })
	end
	currentIndex = newIndex
	if not generation then
		for model in pairs(painted) do
			restore(model)
		end
		return
	end
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		if model:IsA("Model") and model.Parent then
			paint(model, generation)
		end
	end
end

player:GetAttributeChangedSignal("InfiniteStage"):Connect(refresh)
CollectionService:GetInstanceAddedSignal("Monster"):Connect(function(model)
	if currentIndex > 0 then
		task.defer(function()
			local generation = StageGeneration.forStage(player:GetAttribute("InfiniteStage"))
			if generation and model.Parent then
				paint(model, generation)
			end
		end)
	end
end)
CollectionService:GetInstanceRemovedSignal("Monster"):Connect(function(model)
	painted[model] = nil
end)
task.defer(refresh)

-- 검증 훅(Studio · 클라 execute_luau): PlayerGui.GenerationHook:Invoke() → { index, painted = n }
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "GenerationHook"
	hook.OnInvoke = function()
		refresh()
		local n = 0
		for _ in pairs(painted) do
			n += 1
		end
		return { index = currentIndex, painted = n }
	end
	hook.Parent = player:WaitForChild("PlayerGui")
end
