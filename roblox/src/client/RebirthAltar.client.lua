-- 커뮤니티 환생 제단(S12b F): 월드의 ProximityPrompt(RebirthAltarPrompt, PC E키 · 모바일 탭)를 누르면 확인창(Confirm overlay)을 연다. 문구 · 조건식은 강화대 환생 탭(RebirthView)과 같은 것을 쓴다.
-- 확인하면 기존 RebirthRequest를 그대로 쏜다 - 어느 자리에서 눌렀는지는 서버가 요청 시점의 위치로 다시 잰다(RebirthAccess). 여기 거리 판정은 표시 편의일 뿐이다.
-- 결과(RebirthResult)는 이 경로로 요청했을 때만 상단 토스트로 알린다(강화대 환생 탭은 자기 결과 줄이 있다).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Confirm = require(script.Parent.ui.kit.Confirm)
local Toast = require(script.Parent.ui.kit.Toast)
local RebirthView = require(script.Parent.panels.Enhance.RebirthView)

local player = Players.LocalPlayer
local rebirthRequest = ReplicatedStorage:WaitForChild("RebirthRequest")
local rebirthResult = ReplicatedStorage:WaitForChild("RebirthResult")

local PROMPT_NAME = "RebirthAltarPrompt"
local awaitingResult = false

local function askRebirth()
	local rebirthCount = player:GetAttribute("RebirthCount") or 0
	local level = player:GetAttribute("CharacterLevel") or 1
	if rebirthCount >= GemData.maxRebirthCount then
		Confirm.ask({
			title = "환생",
			body = ("환생 %d/%d회 완료 - 더 이상 환생할 수 없습니다."):format(rebirthCount, GemData.maxRebirthCount),
			primaryText = "환생한다",
			secondaryText = "닫기",
			primaryEnabled = false,
		}, function() end)
		return
	end
	local requiredLevel = RebirthView.requiredLevel(rebirthCount)
	local enough = level >= requiredLevel
	Confirm.ask({
		title = "환생",
		body = ("%s\n\n환생 %d/%d회 · 현재 레벨 %d · 필요 레벨 %d\n경험치 배수 ×%d → ×%d"):format(
			RebirthView.confirmText, rebirthCount, GemData.maxRebirthCount, level, requiredLevel, rebirthCount + 1, rebirthCount + 2),
		primaryText = "환생한다",
		secondaryText = "취소",
		danger = true,
		primaryEnabled = enough,
		reason = (not enough) and ("레벨이 부족합니다(필요 레벨 %d)"):format(requiredLevel) or nil,
	}, function(accepted)
		if accepted then
			awaitingResult = true
			rebirthRequest:FireServer()
			task.delay(3, function()
				awaitingResult = false -- 서버가 조용히 무시한 요청(자리 밖)은 답이 없다 - 나중의 강화대 결과가 이 경로의 토스트로 오해되지 않게
			end)
		end
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
	if prompt.Name == PROMPT_NAME and triggeringPlayer == player then
		askRebirth()
	end
end)

rebirthResult.OnClientEvent:Connect(function(data)
	if not awaitingResult then
		return
	end
	awaitingResult = false
	Toast.push("TC", { text = RebirthView.resultText(data), colorName = data.success and "success" or "danger", seconds = 4 })
end)
