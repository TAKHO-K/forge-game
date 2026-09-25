-- 설정 창(M1-0 - 우측 칩 스택의 설정 버튼이 연다). 지금은 카메라 방식 하나: "탑다운 시점"(끄면 로블록스 기본 카메라 - CameraRig.client.lua).
-- 값은 LocalPlayer Attribute "CameraTopDown"(이 클라에서만 · 이번 접속 동안). 저장 · 키 재설정은 P4 설정창에서 설정 묶음으로 한다.
-- kind = window(다른 창을 닫는다) · 토글 터치 영역 44(Toggle) · 문구는 TextData.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Toggle = require(script.Parent.Parent.ui.kit.Toggle)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local SettingsPanel = {}
SettingsPanel.id = "settings"

local PANEL_SIZE = Vector2.new(420, 190)
local PAD = 12

local player = Players.LocalPlayer
local built

local function build()
	local panel = Panel.create({
		id = SettingsPanel.id,
		kind = "window",
		title = Text.get("settings.title"),
		size = PANEL_SIZE,
	})
	local toggle = Toggle.build({
		parent = panel.content, name = "CameraTopDownToggle", text = Text.get("settings.cameraTopDown"),
		value = player:GetAttribute("CameraTopDown") == true, width = PANEL_SIZE.X - PAD * 2,
		position = UDim2.new(0, PAD, 0, PAD),
		onChanged = function(value)
			player:SetAttribute("CameraTopDown", value)
		end,
	})
	local hint = Theme.label(panel.content, Text.get("settings.cameraTopDownHint"), "caption", "textSecondary")
	hint.Name = "CameraHint"
	hint.TextWrapped = true
	hint.Position = UDim2.new(0, PAD, 0, PAD + 48)
	hint.Size = UDim2.new(1, -PAD * 2, 0, 20)
	local shiftHint = Theme.label(panel.content, Text.get("settings.shiftLockHint"), "caption", "textSecondary")
	shiftHint.Name = "ShiftLockHint"
	shiftHint.TextWrapped = true
	shiftHint.Position = UDim2.new(0, PAD, 0, PAD + 72)
	shiftHint.Size = UDim2.new(1, -PAD * 2, 0, 20)
	built = { panel = panel, toggle = toggle }
end

function SettingsPanel.toggle()
	if not built then
		build()
	end
	built.toggle.setValue(player:GetAttribute("CameraTopDown") == true, true)
	UIManager.switchTo(SettingsPanel.id)
end

function SettingsPanel.debugRefs()
	return built
end

return SettingsPanel
