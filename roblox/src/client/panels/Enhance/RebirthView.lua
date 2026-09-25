-- 환생 탭(23-2, PRD 20.38 [1][2]) - 옛 EnhanceUI.client.lua의 환생 탭을 **옮기기만 했다**(문구 · 수치 · 흐름 변경 0). 인스턴스와 확인창 오버레이가 build 안으로 들어갔고,
-- Attribute · Remote 연결은 조립하는 쪽(init.lua)이 refs.update · refs.handleResult로 이어 준다.
-- 확인창(지시 - "환생은 되돌릴 수 없는 조작이다... 확인 단계 없이 즉시 실행되지 않게 하라"): 화면 전체를 덮는 오버레이는 패널의 ScreenGui 위에 얹는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemData = require(ReplicatedStorage.Shared.data.GemData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Text = require(ReplicatedStorage.Shared.Text)

local RebirthView = {}

-- P2 B: 필요 레벨은 서버(PlayerProfile.rebirth)와 같은 표 한 곳(CharacterLevelConfig.rebirth.requiredLevels)에서 읽는다.
function RebirthView.requiredLevel(rebirthCount)
	return CharacterLevel.getRebirthRequiredLevel(rebirthCount)
end

-- 서버 결과(RebirthResult) → 한 줄 문구(기존 문구 그대로 + 보스전 · 강화 중 두 줄).
function RebirthView.resultText(data)
	if data.success then
		return ("환생 성공! %d회차"):format(data.rebirthCount)
	elseif data.reason == "level_too_low" then
		return ("레벨이 부족합니다(필요 레벨 %d)"):format(data.requiredLevel or 0)
	elseif data.reason == "max_rebirth" then
		return "이미 최대 환생 회차입니다"
	elseif data.reason == "boss_fight" then
		return "보스전 중에는 환생할 수 없습니다"
	elseif data.reason == "enhancing" then
		return "강화 직후에는 잠시 뒤 다시 시도하세요"
	end
	return "환생 실패: " .. tostring(data.reason)
end

local player = Players.LocalPlayer

-- G1-3(사용자 결정): 환생은 커뮤니티 센터의 환생 제단 한 곳에서만 한다(서버 RebirthAccess도 제단만). 이 탭은 안내 · 상태 · 성장 보상 버튼 · 결과 줄만 남긴다.
-- parent = 환생 탭 본문 Frame. 반환 refs = { update, handleResult, hideOverlay(옛 호출 호환 - 할 일 없음) }.
function RebirthView.build(parent, _overlayParent)
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

	-- P2.5b D2: 환생 후 레벨 마일스톤 보상 목록(성장 보상 창 - window라 이 강화대 창은 닫힌다).
	local milestoneButton = Instance.new("TextButton")
	milestoneButton.Name = "MilestoneButton"
	milestoneButton.Size = UDim2.new(0, 140, 0, 44)
	milestoneButton.Position = UDim2.new(0.5, -70, 0, 100)
	milestoneButton.Text = "성장 보상"
	milestoneButton.Font = Enum.Font.GothamBold
	milestoneButton.TextSize = 16
	milestoneButton.TextColor3 = Color3.new(1, 1, 1)
	milestoneButton.BackgroundColor3 = Color3.fromRGB(60, 60, 66)
	milestoneButton.Parent = parent
	milestoneButton.Activated:Connect(function()
		require(script.Parent.Parent.Milestones).open()
	end)

	local resultLabel = Instance.new("TextLabel")
	resultLabel.BackgroundTransparency = 1
	resultLabel.Size = UDim2.new(1, -16, 0, 20)
	resultLabel.Position = UDim2.new(0, 8, 1, -74)
	resultLabel.Font = Enum.Font.GothamBold
	resultLabel.TextSize = 14
	resultLabel.TextColor3 = Color3.fromRGB(255, 220, 90)
	resultLabel.Text = ""
	resultLabel.Parent = parent

	local refs = {}

	function refs.update()
		local rebirthCount = player:GetAttribute("RebirthCount") or 0
		local level = player:GetAttribute("CharacterLevel") or 1
		if rebirthCount >= GemData.maxRebirthCount then
			infoLabel.Text = Text.get("rebirth.confirm.done", { count = rebirthCount, max = GemData.maxRebirthCount })
			return
		end
		infoLabel.Text = Text.get("rebirth.tab.where") .. "\n" .. Text.get("rebirth.tab.status", {
			count = rebirthCount, max = GemData.maxRebirthCount, level = level, required = RebirthView.requiredLevel(rebirthCount),
			expFrom = ("%g"):format(CharacterLevel.getRebirthExpMultiplier(rebirthCount)), expTo = ("%g"):format(CharacterLevel.getRebirthExpMultiplier(rebirthCount + 1)),
		})
	end

	function refs.handleResult(data)
		resultLabel.Text = RebirthView.resultText(data)
		refs.update()
	end

	function refs.hideOverlay() end

	return refs
end

return RebirthView
