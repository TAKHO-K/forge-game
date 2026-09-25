-- 커뮤니티 환생 제단(S12b F): 월드의 ProximityPrompt(RebirthAltarPrompt, PC E키 · 모바일 탭)를 누르면 확인창(Confirm overlay)을 연다. 문구 · 조건식은 강화대 환생 탭(RebirthView)과 같은 것을 쓴다.
-- 확인하면 기존 RebirthRequest를 그대로 쏜다 - 어느 자리에서 눌렀는지는 서버가 요청 시점의 위치로 다시 잰다(RebirthAccess). 여기 거리 판정은 표시 편의일 뿐이다.
-- 결과(RebirthResult)는 이 경로로 요청했을 때만 상단 토스트로 알린다(강화대 환생 탭은 자기 결과 줄이 있다).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GemData = require(ReplicatedStorage.Shared.data.GemData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Text = require(ReplicatedStorage.Shared.Text)
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
			title = Text.get("rebirth.confirm.title"),
			body = Text.get("rebirth.confirm.done", { count = rebirthCount, max = GemData.maxRebirthCount }),
			primaryText = Text.get("rebirth.confirm.ok"),
			secondaryText = Text.get("rebirth.confirm.close"),
			primaryEnabled = false,
		}, function() end)
		return
	end
	local requiredLevel = RebirthView.requiredLevel(rebirthCount)
	local enough = level >= requiredLevel
	-- G1-3: 제목에 "레벨이 1로 돌아갑니다" · 첫 줄 = 무엇이 1이 되는가 · 한 줄 = 얻는 것(영구). 경험치 배수는 서버와 같은 데이터 함수(옛: rebirthCount + 1을 직접 계산).
	Confirm.ask({
		title = Text.get("rebirth.confirm.title"),
		body = Text.get("rebirth.confirm.body", {
			level = level, stage = player:GetAttribute("InfiniteStage") or 1,
			expFrom = ("%g"):format(CharacterLevel.getRebirthExpMultiplier(rebirthCount)), expTo = ("%g"):format(CharacterLevel.getRebirthExpMultiplier(rebirthCount + 1)),
			count = rebirthCount, max = GemData.maxRebirthCount, required = requiredLevel,
		}),
		primaryText = Text.get("rebirth.confirm.ok"),
		secondaryText = Text.get("rebirth.confirm.cancel"),
		danger = true,
		primaryEnabled = enough,
		reason = (not enough) and Text.get("rebirth.levelShort", { required = requiredLevel }) or nil,
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
