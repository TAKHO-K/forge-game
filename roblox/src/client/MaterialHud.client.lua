-- 강화 재료 · 방지권 획득 팝업(28-1 S04 · S05). 처치 보상으로 재료를 받을 때 캐릭터 머리 위에 "+3 강화석"이, 보스 계정 첫 클리어로 방지권을 받을 때 "+1 하락 방지권"이 짧게 뜬다 - GoldHud의 처치 팝업과 같은 모양
-- (BillboardGui · 위로 떠오르며 사라짐 · 수명 1초)이고 색은 UIColors.textPrimary다. 보유량 표시는 이 파일의 일이 아니다(서버 Attribute
-- MaterialEnhanceStone · MaterialHighEnhanceStone - 본격 UI는 S07).
-- 골드 팝업(머리 위 3 → 4.2stud)과 겹치지 않게 그 위에서 시작하고, 같은 처치에서 재료가 둘 나오면 살아 있는 팝업 수만큼 한 칸씩 더 올린다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local materialGained = ReplicatedStorage:WaitForChild("MaterialGained")
local protectionTicketGranted = ReplicatedStorage:WaitForChild("ProtectionTicketGranted")

local POPUP_LIFETIME_SECONDS = 1.0
local BASE_OFFSET_STUDS = 4.4 -- 골드 팝업의 끝(4.2) 위
local LINE_STUDS = 1.2

local player = Players.LocalPlayer
local livePopups = 0

local function showPopup(text)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end

	local startOffset = BASE_OFFSET_STUDS + LINE_STUDS * livePopups
	livePopups += 1

	local gui = Instance.new("BillboardGui")
	gui.Name = "MaterialPopupGui"
	gui.Size = UDim2.new(5, 0, 0.9, 0)
	gui.StudsOffset = Vector3.new(0, startOffset, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = text
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = UIColors.textPrimary
	label.TextScaled = true
	label.Parent = gui

	TweenService:Create(gui, TweenInfo.new(POPUP_LIFETIME_SECONDS), {
		StudsOffset = Vector3.new(0, startOffset + LINE_STUDS, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(POPUP_LIFETIME_SECONDS), {
		TextTransparency = 1,
	}):Play()

	task.delay(POPUP_LIFETIME_SECONDS, function()
		livePopups -= 1
		gui:Destroy()
	end)
end

materialGained.OnClientEvent:Connect(function(materialId, count)
	local material = EnhanceMaterialData.materials[materialId]
	if material then
		showPopup(("+%d %s"):format(count, material.displayName))
	end
end)

-- 보스 계정 첫 클리어 방지권 지급(kind = "drop" / "reset", count, stage).
protectionTicketGranted.OnClientEvent:Connect(function(kind, count)
	local config = EnhanceConfig.protection[kind]
	if config and kind ~= "bossGrant" then
		showPopup(("+%d %s"):format(count, config.displayName))
	end
end)
