-- 환생 탭(23-2, PRD 20.38 [1][2]) - 옛 EnhanceUI.client.lua의 환생 탭을 **옮기기만 했다**(문구 · 수치 · 흐름 변경 0). 인스턴스와 확인창 오버레이가 build 안으로 들어갔고,
-- Attribute · Remote 연결은 조립하는 쪽(init.lua)이 refs.update · refs.handleResult로 이어 준다.
-- 확인창(지시 - "환생은 되돌릴 수 없는 조작이다... 확인 단계 없이 즉시 실행되지 않게 하라"): 화면 전체를 덮는 오버레이는 패널의 ScreenGui 위에 얹는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemData = require(ReplicatedStorage.Shared.data.GemData)

local RebirthView = {}

local player = Players.LocalPlayer
local rebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest")

-- parent = 환생 탭 본문 Frame, overlayParent = 확인창 오버레이를 붙일 ScreenGui. 반환 refs = { update, handleResult, hideOverlay }.
function RebirthView.build(parent, overlayParent)
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
	infoLabel.Parent = parent

	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 140, 0, 40)
	button.Position = UDim2.new(0.5, -70, 1, -48)
	button.Text = "환생"
	button.Font = Enum.Font.GothamBold
	button.TextSize = 18
	button.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
	button.Parent = parent

	local resultLabel = Instance.new("TextLabel")
	resultLabel.BackgroundTransparency = 1
	resultLabel.Size = UDim2.new(1, -16, 0, 20)
	resultLabel.Position = UDim2.new(0, 8, 1, -74)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 14
	resultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	resultLabel.Text = ""
	resultLabel.Parent = parent

	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Visible = false
	overlay.ZIndex = 10
	overlay.Parent = overlayParent

	local box = Instance.new("Frame")
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.new(0.5, 0, 0.5, 0)
	box.Size = UDim2.new(0, 280, 0, 140)
	box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	box.ZIndex = 11
	box.Parent = overlay

	local confirmLabel = Instance.new("TextLabel")
	confirmLabel.BackgroundTransparency = 1
	confirmLabel.Size = UDim2.new(1, -16, 0, 70)
	confirmLabel.Position = UDim2.new(0, 8, 0, 8)
	confirmLabel.TextWrapped = true
	confirmLabel.Font = Enum.Font.Gotham
	confirmLabel.TextSize = 15
	confirmLabel.TextColor3 = Color3.new(1, 1, 1)
	confirmLabel.ZIndex = 11
	confirmLabel.Text = "정말 환생하시겠습니까?\n레벨과 무한 스테이지가 1로 초기화됩니다 - 되돌릴 수 없습니다."
	confirmLabel.Parent = box

	local confirmYes = Instance.new("TextButton")
	confirmYes.Size = UDim2.new(0, 120, 0, 36)
	confirmYes.Position = UDim2.new(0, 12, 1, -48)
	confirmYes.Text = "환생한다"
	confirmYes.Font = Enum.Font.GothamBold
	confirmYes.TextSize = 15
	confirmYes.BackgroundColor3 = Color3.fromRGB(200, 160, 40)
	confirmYes.ZIndex = 11
	confirmYes.Parent = box

	local confirmNo = Instance.new("TextButton")
	confirmNo.Size = UDim2.new(0, 120, 0, 36)
	confirmNo.Position = UDim2.new(1, -132, 1, -48)
	confirmNo.Text = "취소"
	confirmNo.Font = Enum.Font.GothamBold
	confirmNo.TextSize = 15
	confirmNo.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	confirmNo.ZIndex = 11
	confirmNo.Parent = box

	local refs = {}

	function refs.update()
		local rebirthCount = player:GetAttribute("RebirthCount") or 0
		local level = player:GetAttribute("CharacterLevel") or 1
		if rebirthCount >= GemData.maxRebirthCount then
			infoLabel.Text = ("환생 %d/%d회 완료 - 더 이상 환생할 수 없습니다."):format(rebirthCount, GemData.maxRebirthCount)
			button.Text = "완료"
			button.AutoButtonColor = false
			return
		end

		local requiredLevel = 25 * (rebirthCount + 1)
		button.Text = "환생"
		button.AutoButtonColor = true
		infoLabel.Text = ("환생 %d/%d회 · 현재 레벨 %d\n필요 레벨 %d - 레벨을 1로 초기화하고 무기 등급·보석 슬롯을 1단계 올립니다.\n경험치 배수 ×%d → ×%d"):format(
			rebirthCount, GemData.maxRebirthCount, level, requiredLevel, rebirthCount + 1, rebirthCount + 2)
	end

	function refs.handleResult(data)
		if data.success then
			resultLabel.Text = ("환생 성공! %d회차"):format(data.rebirthCount)
		elseif data.reason == "level_too_low" then
			resultLabel.Text = ("레벨이 부족합니다(필요 레벨 %d)"):format(data.requiredLevel or 0)
		elseif data.reason == "max_rebirth" then
			resultLabel.Text = "이미 최대 환생 회차입니다"
		else
			resultLabel.Text = "환생 실패: " .. tostring(data.reason)
		end
		refs.update()
	end

	-- 패널이 닫힐 때 열려 있던 확인창을 같이 닫는다(station이 걸어서 벗어나거나 window가 열려서 닫히면 오버레이만 남지 않게).
	function refs.hideOverlay()
		overlay.Visible = false
	end

	button.Activated:Connect(function()
		if (player:GetAttribute("RebirthCount") or 0) >= GemData.maxRebirthCount then
			return
		end
		overlay.Visible = true
	end)
	confirmNo.Activated:Connect(function()
		overlay.Visible = false
	end)
	confirmYes.Activated:Connect(function()
		overlay.Visible = false
		rebirthRequest:FireServer()
	end)

	return refs
end

return RebirthView
