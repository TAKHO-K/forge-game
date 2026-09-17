-- 강화 UI(10-2). 기능 확인 수준 - 폴리시(꾸미기)는 UI 세션에서 한꺼번에 한다. 강화대
-- 근처에서만 보인다(거리 기준, WorldConfig.enhance.interactionRangeStuds와 서버가 같은
-- 값을 쓴다). 서버 Attribute(WeaponLevel/Gold)만 읽는다 - 확률·비용 표시는 Enhance
-- 조회 함수로 계산하되, 실제 판정은 절대 여기서 하지 않는다(서버 전용, EnhanceServer.server.lua).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local HelpTooltip = require(script.Parent.HelpTooltip)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)

local enhanceRequest = ReplicatedStorage:WaitForChild("EnhanceRequest")
local enhanceResult = ReplicatedStorage:WaitForChild("EnhanceResult")
-- 23-2: 환생·분해(PRD 20.37/20.38) - 강화대가 무기 관련 상호작용의 기존 허브라 같은
-- 패널에 탭으로 붙인다(20.37 [3] "분해 UI는 강화대에 둔다"와 같은 판단을 환생에도 그대로
-- 적용 - 새 UI 스타일을 만들지 않는다는 지시). 보석 탭은 23-4에서 장비창으로 옮겼다.
local rebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest")
local rebirthResult = ReplicatedStorage:WaitForChild("RebirthResult")

local RESULT_LABEL = {
	success = "성공! +%d",
	maintain = "실패 - 형상유지 (+%d)",
	down1 = "실패 - 1강 하락 (+%d)",
	down2 = "실패 - 2강 하락 (+%d)",
	reset = "실패 - 초기화 (+%d)",
	max = "이미 최대 강화 단계입니다",
	insufficient_gold = "골드가 부족합니다",
}

local player = Players.LocalPlayer
local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EnhanceGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "EnhancePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -120)
panel.Size = UDim2.new(0, 320, 0, 208)
panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
panel.BackgroundTransparency = 0.1
panel.Visible = false
panel.Parent = screenGui

-- 탭 2개(강화/환생, 23-2 신설·23-4에서 보석 탭 분리) - 320px 패널 폭을 2등분한다. 같은 색
-- 규칙(선택 탭=골드, 나머지=어두운 회색)만 쓴다 - 새 색을 만들지 않는다.
local TAB_NAMES = { "강화", "환생" }
local tabButtons = {}
local tabContents = {}
local activeTab = "강화"

local tabRow = Instance.new("Frame")
tabRow.Size = UDim2.new(1, 0, 0, 28)
tabRow.Position = UDim2.new(0, 0, 0, 0)
tabRow.BackgroundTransparency = 1
tabRow.Parent = panel

local function selectTab(name)
	activeTab = name
	for tabName, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = tabName == name and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(40, 40, 46)
	end
	for tabName, frame in pairs(tabContents) do
		frame.Visible = tabName == name
	end
end

for i, name in ipairs(TAB_NAMES) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1 / #TAB_NAMES, 0, 1, 0)
	btn.Position = UDim2.new((i - 1) / #TAB_NAMES, 0, 0, 0)
	btn.Text = name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	btn.Parent = tabRow
	tabButtons[name] = btn
	btn.Activated:Connect(function()
		selectTab(name)
	end)
end

-- ═══ 강화 탭(기존 내용 그대로, 탭 프레임 안으로 이동만 했다) ═══

local enhanceTab = Instance.new("Frame")
enhanceTab.Size = UDim2.new(1, 0, 1, -28)
enhanceTab.Position = UDim2.new(0, 0, 0, 28)
enhanceTab.BackgroundTransparency = 1
enhanceTab.Parent = panel
tabContents["강화"] = enhanceTab

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, -16, 0, 90)
infoLabel.Position = UDim2.new(0, 8, 0, 8)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.TextWrapped = true
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 16
infoLabel.TextColor3 = Color3.new(1, 1, 1)
infoLabel.Text = ""
infoLabel.Parent = enhanceTab

local enhanceButton = Instance.new("TextButton")
enhanceButton.Size = UDim2.new(0, 140, 0, 40)
enhanceButton.Position = UDim2.new(0.5, -70, 1, -48)
enhanceButton.Text = "강화"
enhanceButton.Font = Enum.Font.GothamBold
enhanceButton.TextSize = 18
enhanceButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
enhanceButton.Parent = enhanceTab

-- 25-3: 실패의 구체적 결과(4종)가 화면 어디에도 안 보여서 붙인다(단계 3).
HelpTooltip.attach(enhanceTab, UDim2.new(0.5, 78, 1, -28),
	"강화 실패 시 형상유지·1강 하락·2강 하락·초기화 중 하나가 확률로 정해집니다. 단계가 오를수록 성공률이 낮아집니다.", "left")

local resultLabel = Instance.new("TextLabel")
resultLabel.BackgroundTransparency = 1
resultLabel.Size = UDim2.new(1, -16, 0, 20)
resultLabel.Position = UDim2.new(0, 8, 1, -74)
resultLabel.Font = Enum.Font.GothamBold
resultLabel.TextSize = 14
resultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
resultLabel.Text = ""
resultLabel.Parent = enhanceTab

-- ═══ 환생 탭(23-2, PRD 20.38 [1][2]) ═══

local rebirthTab = Instance.new("Frame")
rebirthTab.Size = UDim2.new(1, 0, 1, -28)
rebirthTab.Position = UDim2.new(0, 0, 0, 28)
rebirthTab.BackgroundTransparency = 1
rebirthTab.Visible = false
rebirthTab.Parent = panel
tabContents["환생"] = rebirthTab

local rebirthInfoLabel = Instance.new("TextLabel")
rebirthInfoLabel.BackgroundTransparency = 1
rebirthInfoLabel.Size = UDim2.new(1, -16, 0, 90)
rebirthInfoLabel.Position = UDim2.new(0, 8, 0, 8)
rebirthInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
rebirthInfoLabel.TextYAlignment = Enum.TextYAlignment.Top
rebirthInfoLabel.TextWrapped = true
rebirthInfoLabel.Font = Enum.Font.Gotham
rebirthInfoLabel.TextSize = 16
rebirthInfoLabel.TextColor3 = Color3.new(1, 1, 1)
rebirthInfoLabel.Text = ""
rebirthInfoLabel.Parent = rebirthTab

local rebirthButton = Instance.new("TextButton")
rebirthButton.Size = UDim2.new(0, 140, 0, 40)
rebirthButton.Position = UDim2.new(0.5, -70, 1, -48)
rebirthButton.Text = "환생"
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextSize = 18
rebirthButton.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
rebirthButton.Parent = rebirthTab

local rebirthResultLabel = Instance.new("TextLabel")
rebirthResultLabel.BackgroundTransparency = 1
rebirthResultLabel.Size = UDim2.new(1, -16, 0, 20)
rebirthResultLabel.Position = UDim2.new(0, 8, 1, -74)
rebirthResultLabel.Font = Enum.Font.GothamBold
rebirthResultLabel.TextSize = 14
rebirthResultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
rebirthResultLabel.Text = ""
rebirthResultLabel.Parent = rebirthTab

-- 확인창(지시 - "환생은 되돌릴 수 없는 조작이다... 확인 단계 없이 즉시 실행되지 않게 하라").
-- 화면 전체를 덮어 패널 뒤 다른 조작이 새어 들어가지 않게 한다.
local rebirthConfirmOverlay = Instance.new("Frame")
rebirthConfirmOverlay.Size = UDim2.new(1, 0, 1, 0)
rebirthConfirmOverlay.BackgroundColor3 = Color3.new(0, 0, 0)
rebirthConfirmOverlay.BackgroundTransparency = 0.4
rebirthConfirmOverlay.Visible = false
rebirthConfirmOverlay.ZIndex = 10
rebirthConfirmOverlay.Parent = screenGui

local rebirthConfirmBox = Instance.new("Frame")
rebirthConfirmBox.AnchorPoint = Vector2.new(0.5, 0.5)
rebirthConfirmBox.Position = UDim2.new(0.5, 0, 0.5, 0)
rebirthConfirmBox.Size = UDim2.new(0, 280, 0, 140)
rebirthConfirmBox.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
rebirthConfirmBox.ZIndex = 11
rebirthConfirmBox.Parent = rebirthConfirmOverlay

local rebirthConfirmLabel = Instance.new("TextLabel")
rebirthConfirmLabel.BackgroundTransparency = 1
rebirthConfirmLabel.Size = UDim2.new(1, -16, 0, 70)
rebirthConfirmLabel.Position = UDim2.new(0, 8, 0, 8)
rebirthConfirmLabel.TextWrapped = true
rebirthConfirmLabel.Font = Enum.Font.Gotham
rebirthConfirmLabel.TextSize = 15
rebirthConfirmLabel.TextColor3 = Color3.new(1, 1, 1)
rebirthConfirmLabel.ZIndex = 11
rebirthConfirmLabel.Text = "정말 환생하시겠습니까?\n레벨과 무한 스테이지가 1로 초기화됩니다 - 되돌릴 수 없습니다."
rebirthConfirmLabel.Parent = rebirthConfirmBox

local rebirthConfirmYes = Instance.new("TextButton")
rebirthConfirmYes.Size = UDim2.new(0, 120, 0, 36)
rebirthConfirmYes.Position = UDim2.new(0, 12, 1, -48)
rebirthConfirmYes.Text = "환생한다"
rebirthConfirmYes.Font = Enum.Font.GothamBold
rebirthConfirmYes.TextSize = 15
rebirthConfirmYes.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
rebirthConfirmYes.ZIndex = 11
rebirthConfirmYes.Parent = rebirthConfirmBox

local rebirthConfirmNo = Instance.new("TextButton")
rebirthConfirmNo.Size = UDim2.new(0, 120, 0, 36)
rebirthConfirmNo.Position = UDim2.new(1, -132, 1, -48)
rebirthConfirmNo.Text = "취소"
rebirthConfirmNo.Font = Enum.Font.GothamBold
rebirthConfirmNo.TextSize = 15
rebirthConfirmNo.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
rebirthConfirmNo.ZIndex = 11
rebirthConfirmNo.Parent = rebirthConfirmBox

local function updateRebirthInfo()
	local rebirthCount = player:GetAttribute("RebirthCount") or 0
	local level = player:GetAttribute("CharacterLevel") or 1
	if rebirthCount >= GemData.maxRebirthCount then
		rebirthInfoLabel.Text = ("환생 %d/%d회 완료 - 더 이상 환생할 수 없습니다."):format(rebirthCount, GemData.maxRebirthCount)
		rebirthButton.Text = "완료"
		rebirthButton.AutoButtonColor = false
		return
	end

	local requiredLevel = 25 * (rebirthCount + 1)
	rebirthButton.Text = "환생"
	rebirthButton.AutoButtonColor = true
	rebirthInfoLabel.Text = ("환생 %d/%d회 · 현재 레벨 %d\n필요 레벨 %d - 레벨을 1로 초기화하고 무기 등급·보석 슬롯을 1단계 올립니다.\n경험치 배수 ×%d → ×%d"):format(
		rebirthCount, GemData.maxRebirthCount, level, requiredLevel, rebirthCount + 1, rebirthCount + 2)
end

rebirthButton.Activated:Connect(function()
	if (player:GetAttribute("RebirthCount") or 0) >= GemData.maxRebirthCount then
		return
	end
	rebirthConfirmOverlay.Visible = true
end)

rebirthConfirmNo.Activated:Connect(function()
	rebirthConfirmOverlay.Visible = false
end)

rebirthConfirmYes.Activated:Connect(function()
	rebirthConfirmOverlay.Visible = false
	rebirthRequest:FireServer()
end)

rebirthResult.OnClientEvent:Connect(function(data)
	if data.success then
		rebirthResultLabel.Text = ("환생 성공! %d회차"):format(data.rebirthCount)
	elseif data.reason == "level_too_low" then
		rebirthResultLabel.Text = ("레벨이 부족합니다(필요 레벨 %d)"):format(data.requiredLevel or 0)
	elseif data.reason == "max_rebirth" then
		rebirthResultLabel.Text = "이미 최대 환생 회차입니다"
	else
		rebirthResultLabel.Text = "환생 실패: " .. tostring(data.reason)
	end
	updateRebirthInfo()
end)

player:GetAttributeChangedSignal("RebirthCount"):Connect(updateRebirthInfo)
player:GetAttributeChangedSignal("CharacterLevel"):Connect(updateRebirthInfo)

-- 23-4: 보석 탭을 강화대에서 뗐다(PRD 20.58 지시 - "강화대까지 가야 보석을 볼 수 있는
-- 문제"를 장비창 탭으로 옮겨 해결한다). 드래그 장착·무기 확대 실루엣 등 새 UI를 강화대
-- (320x208 좁은 패널)에도 유지하면 같은 로직 두 벌을 관리해야 해서 통째로 InventoryUI.
-- client.lua "보석" 탭으로 옮기고 여기선 정리했다 - 강화/환생 2탭만 남는다.

selectTab("강화")

-- 강화대가 등급을 몰랐던 것(20-1 [2] - "강화대에 현재 무기 등급 표시")을 여기서 연결한다.
-- 등급 자체는 이 화면에서 바꾸지 않는다(환생 전용 축, EnhanceUI는 표시만).
local function gradeDisplayName()
	local grade = player:GetAttribute("WeaponGrade") or 0
	local gradeId = ArmorData.gradeOrder[grade + 1]
	local gradeInfo = gradeId and ArmorData.grades[gradeId]
	return gradeInfo and gradeInfo.displayName or "일반"
end

local function updateInfo()
	local level = player:GetAttribute("WeaponLevel") or 0
	local gold = player:GetAttribute("Gold") or 0
	local cost = Enhance.getCost(level)
	local gradeName = gradeDisplayName()

	if not cost then
		infoLabel.Text = ("%s 등급 · 현재 +%d (최대 강화 단계)"):format(gradeName, level)
		enhanceButton.Text = "최대"
		enhanceButton.AutoButtonColor = false
		return
	end

	local prob = Enhance.getProbability(level)
	enhanceButton.Text = "강화"
	enhanceButton.AutoButtonColor = true
	infoLabel.Text = ("%s 등급 · 현재 +%d\n다음 +%d 성공 확률 %.0f%%\n소모 골드 %s (보유 %s)"):format(
		gradeName, level, level + 1, prob.success * 100, NumberFormat.format(cost), NumberFormat.format(gold))
end

enhanceButton.Activated:Connect(function()
	enhanceRequest:FireServer()
end)

enhanceResult.OnClientEvent:Connect(function(data)
	local level = data.level or (player:GetAttribute("WeaponLevel") or 0)
	local template = RESULT_LABEL[data.result] or data.result
	if template:find("%%d") then
		resultLabel.Text = template:format(level)
	else
		resultLabel.Text = template
	end
	updateInfo()
end)

player:GetAttributeChangedSignal("WeaponLevel"):Connect(updateInfo)
player:GetAttributeChangedSignal("WeaponGrade"):Connect(updateInfo)
player:GetAttributeChangedSignal("Gold"):Connect(updateInfo)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		panel.Visible = false
		return
	end

	local distance = (root.Position - stationPosition).Magnitude
	local wasVisible = panel.Visible
	panel.Visible = distance <= WorldConfig.enhance.interactionRangeStuds
	if panel.Visible and not wasVisible then
		updateInfo()
		updateRebirthInfo()
	end
end)
