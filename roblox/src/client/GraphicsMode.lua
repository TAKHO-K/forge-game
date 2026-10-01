-- QUEUE-ALL6 A2 그래픽 실효값(클라 한 곳): 저장한 값(GraphicsMode = normal | lite)이 있으면 그것, 아직 안 골랐으면(auto) 기기로 판별.
--   폰(터치 전용) · 로블록스 품질을 직접 낮춘 기기(SavedQualityLevel 1 ~ liteAtSavedQualityAtMost) = lite, 그 밖 = normal. 기준 = SettingsData.graphicsAuto.
--   기기 판별값은 저장하지 않는다(같은 계정이 PC로 오면 보통) - 설정 창에서 직접 바꾸면 그 값이 저장되고 이후 유지된다.
--   읽는 곳: FxSettings(먼 산) · GrassTuftView(풀 덤불) · TreeWind(나무 바람) · 설정 창 그래픽 줄.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)

local GraphicsMode = {}

function GraphicsMode.deviceDefault()
	local rule = SettingsData.graphicsAuto
	if rule.liteWhenTouchOnly and UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "lite"
	end
	local ok, level = pcall(function()
		return UserSettings().GameSettings.SavedQualityLevel.Value
	end)
	if ok and level >= 1 and level <= rule.liteAtSavedQualityAtMost then -- 0 = 자동
		return "lite"
	end
	return "normal"
end

function GraphicsMode.effective()
	local v = Players.LocalPlayer:GetAttribute("GraphicsMode")
	if v == "normal" or v == "lite" then
		return v
	end
	return GraphicsMode.deviceDefault()
end

function GraphicsMode.isLite()
	return GraphicsMode.effective() == "lite"
end

return GraphicsMode
