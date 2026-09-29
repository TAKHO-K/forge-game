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
local AttackTrail = require(script.Parent.Parent.AttackTrail)

local SettingsPanel = {}
SettingsPanel.id = "settings"

local PANEL_SIZE = Vector2.new(420, 440) -- Q14: 섬광 줄이기 · 직업 변경 한 줄씩 -- W2: 궤적 토글 한 줄 추가 · W3c: 화면 흔들림 토글 한 줄 · C5-4: 자동 이동 한 줄
local Button = require(script.Parent.Parent.ui.kit.Button)
local AutoStageData = require(ReplicatedStorage.Shared.data.AutoStageData)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData) -- B4 음량 줄(키 · Attribute · 기본값 · 단계)
local SoundData = require(ReplicatedStorage.Shared.data.SoundData) -- B4 카테고리 순서 → 설정 키
local PAD = 12

local player = Players.LocalPlayer
local built
local saveRemote = ReplicatedStorage:WaitForChild("SettingsSave", 10) -- Q14: 설정 저장(서버가 검증 · 저장 · Attribute 적용)
local function save(key, value)
	if saveRemote then
		saveRemote:FireServer(key, value)
	end
end

local function build()
	local panel = Panel.create({
		id = SettingsPanel.id,
		kind = "window",
		title = Text.get("settings.title"),
		size = PANEL_SIZE,
	})
	-- Q14 리뷰(치명): 폰 창(높이 0.88 × 화면)에서는 본문이 약 220 ~ 300px라 아래 줄([직업 변경] 등)이 잘렸다 → 본문을 스크롤로
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 1, 0)
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Theme.color("rim")
	body.CanvasSize = UDim2.new(0, 0, 0, PAD + 376 + #SoundData.categoryOrder * 52 + PAD) -- B4: 음량 제목(348) + 카테고리 줄 52씩
	body.Parent = panel.content
	local toggle = Toggle.build({
		parent = body, name = "CameraTopDownToggle", text = Text.get("settings.cameraTopDown"),
		value = player:GetAttribute("CameraTopDown") == true, width = PANEL_SIZE.X - PAD * 2,
		position = UDim2.new(0, PAD, 0, PAD),
		onChanged = function(value)
			player:SetAttribute("CameraTopDown", value)
			save("cameraTopDown", value)
		end,
	})
	local hint = Theme.label(body, Text.get("settings.cameraTopDownHint"), "caption", "textSecondary")
	hint.Name = "CameraHint"
	hint.TextWrapped = true
	hint.Position = UDim2.new(0, PAD, 0, PAD + 48)
	hint.Size = UDim2.new(1, -PAD * 2, 0, 20)
	local shiftHint = Theme.label(body, Text.get("settings.shiftLockHint"), "caption", "textSecondary")
	shiftHint.Name = "ShiftLockHint"
	shiftHint.TextWrapped = true
	shiftHint.Position = UDim2.new(0, PAD, 0, PAD + 72)
	shiftHint.Size = UDim2.new(1, -PAD * 2, 0, 20)
	-- W2: 다른 유저 궤적 흐리게(파티 전투 화면 정리 - 이 클라 · 이번 접속 동안 · 저장은 P4-4)
	local dimToggle = Toggle.build({
		parent = body, name = "DimOthersTrailToggle", text = Text.get("settings.dimOthersTrail"),
		value = AttackTrail.dimOthers(), width = PANEL_SIZE.X - PAD * 2,
		position = UDim2.new(0, PAD, 0, PAD + 100),
		onChanged = function(value)
			AttackTrail.setDimOthers(value)
			save("dimOthersTrail", value)
		end,
	})
	-- W3c: 화면 흔들림 끄기(타격 · 스킬 = CameraShake · 보스 = BossFx - 이 클라 · 이번 접속 동안 · 저장은 P4-4)
	local shakeToggle = Toggle.build({
		parent = body, name = "ScreenShakeToggle", text = Text.get("settings.screenShake"),
		value = player:GetAttribute("SettingScreenShake") ~= false, width = PANEL_SIZE.X - PAD * 2,
		position = UDim2.new(0, PAD, 0, PAD + 148),
		onChanged = function(value)
			player:SetAttribute("SettingScreenShake", value)
			player:SetAttribute("SettingBossScreenShake", value)
			save("screenShake", value)
		end,
	})
	-- Q14 번개 · 태초 화면 섬광 줄이기(보스 경고는 밝기만 - 관문 날씨 섬광 끔)
	local flashToggle = Toggle.build({
		parent = body, name = "ReduceFlashesToggle", text = Text.get("settings.reduceFlashes"),
		value = player:GetAttribute("ReduceFlashes") == true, width = PANEL_SIZE.X - PAD * 2,
		position = UDim2.new(0, PAD, 0, PAD + 196),
		onChanged = function(value)
			player:SetAttribute("ReduceFlashes", value)
			save("reduceFlashes", value)
		end,
	})
	-- C5-4 자동 스테이지 이동(보통 → 편함 → 도전 → 끄기 순환 - 서버 RemoteEvent AutoStageSetting · 이번 접속 동안 · 저장은 P4-4)
	local autoLabel = Theme.label(body, Text.get("settings.autoStage"), "body", "textPrimary")
	autoLabel.Name = "AutoStageLabel"
	autoLabel.Position = UDim2.new(0, PAD, 0, PAD + 244)
	autoLabel.Size = UDim2.new(1, -PAD * 2 - 120, 0, 32)
	local function presetName(id)
		for _, preset in ipairs(AutoStageData.presets) do
			if preset.id == id then
				return preset.name
			end
		end
		return AutoStageData.presets[1].name
	end
	local autoButton = Button.build({
		parent = body, name = "AutoStageButton", kind = "secondary", width = 110,
		position = UDim2.new(1, -PAD - 110, 0, PAD + 244),
		text = presetName(player:GetAttribute("AutoStage") or AutoStageData.default),
		onActivated = function()
			local current = player:GetAttribute("AutoStage") or AutoStageData.default
			local nextId = AutoStageData.presets[1].id
			for index, preset in ipairs(AutoStageData.presets) do
				if preset.id == current then
					nextId = (AutoStageData.presets[index + 1] or AutoStageData.presets[1]).id
					break
				end
			end
			ReplicatedStorage:WaitForChild("AutoStageSetting"):FireServer(nextId)
		end,
	})
	-- Q14 P4e: [직업 변경](폰에서는 왼쪽 아래 버튼이 조이스틱 구역이라 숨는다 - 여기서 연다 · PC도 같이 쓴다)
	local classButton = Button.build({
		parent = body, name = "ClassChangeButton", kind = "secondary", width = 110,
		position = UDim2.new(0, PAD, 0, PAD + 292),
		text = Text.get("settings.classChange"),
		onActivated = function()
			local ui = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("ClassSelectUI")
			local signal = ui and ui:FindFirstChild("OpenClassSelect")
			if signal then
				UIManager.close(SettingsPanel.id)
				signal:Fire()
			end
		end,
	})
	classButton.root.Name = "ClassChangeButton"
	-- B4 소리 음량(카테고리 4줄: 이름 · [−] · 값 · [+] - 버튼 높이 = Theme.buttonHeight(폰 44) · 저장 = 같은 SettingsSave)
	local soundHeader = Theme.label(body, Text.get("settings.soundHeader"), "body", "textSecondary")
	soundHeader.Name = "SoundHeader"
	soundHeader.Position = UDim2.new(0, PAD, 0, PAD + 348)
	soundHeader.Size = UDim2.new(1, -PAD * 2, 0, 24)
	local volumeRows = {}
	for index, categoryId in ipairs(SoundData.categoryOrder) do
		local key = SoundData.categories[categoryId].settingKey
		local def = SettingsData.keys[key]
		local y = PAD + 376 + (index - 1) * 52
		local nameLabel = Theme.label(body, Text.get("settings.volume." .. categoryId), "body", "textPrimary")
		nameLabel.Name = "VolumeLabel_" .. categoryId
		nameLabel.Position = UDim2.new(0, PAD, 0, y)
		nameLabel.Size = UDim2.new(0, 140, 0, Theme.buttonHeight)
		local valueLabel = Theme.label(body, "", "body", "textPrimary")
		valueLabel.Name = "VolumeValue_" .. categoryId
		valueLabel.TextXAlignment = Enum.TextXAlignment.Center
		valueLabel.Position = UDim2.new(0, PAD + 244, 0, y)
		valueLabel.Size = UDim2.new(0, 56, 0, Theme.buttonHeight)
		local function current()
			local v = player:GetAttribute(def.attrs[1])
			return type(v) == "number" and v or def.default
		end
		local function render()
			valueLabel.Text = Text.get("settings.volumeValue", { percent = tostring(math.floor(current() * 100 + 0.5)) })
		end
		local function step(sign)
			local v = math.clamp(current() + sign * SettingsData.volumeStep, 0, 1)
			v = math.floor(v * 100 + 0.5) / 100
			player:SetAttribute(def.attrs[1], v)
			save(key, v)
			render()
		end
		Button.build({
			parent = body, name = "VolumeDown_" .. categoryId, kind = "secondary", width = 88,
			position = UDim2.new(0, PAD + 148, 0, y), text = "−",
			onActivated = function()
				step(-1)
			end,
		})
		Button.build({
			parent = body, name = "VolumeUp_" .. categoryId, kind = "secondary", width = 88,
			position = UDim2.new(0, PAD + 308, 0, y), text = "+",
			onActivated = function()
				step(1)
			end,
		})
		player:GetAttributeChangedSignal(def.attrs[1]):Connect(render)
		render()
		volumeRows[categoryId] = { render = render, valueLabel = valueLabel }
	end
	player:GetAttributeChangedSignal("AutoStage"):Connect(function()
		autoButton.setText(presetName(player:GetAttribute("AutoStage") or AutoStageData.default))
	end)
	built = { panel = panel, toggle = toggle, dimToggle = dimToggle, shakeToggle = shakeToggle, flashToggle = flashToggle, autoButton = autoButton, volumeRows = volumeRows }
end

function SettingsPanel.toggle()
	if not built then
		build()
	end
	built.toggle.setValue(player:GetAttribute("CameraTopDown") == true, true)
	built.dimToggle.setValue(AttackTrail.dimOthers(), true)
	built.shakeToggle.setValue(player:GetAttribute("SettingScreenShake") ~= false, true)
	built.flashToggle.setValue(player:GetAttribute("ReduceFlashes") == true, true)
	for _, row in pairs(built.volumeRows) do
		row.render()
	end
	UIManager.switchTo(SettingsPanel.id)
end

function SettingsPanel.debugRefs()
	return built
end

return SettingsPanel
