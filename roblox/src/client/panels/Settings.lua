-- 설정 창(M1-0 · Q14 저장 · QUEUE-ALL2 P2 B-4 ⑤ 정리 - 한 창에 분류 탭 4개). 왼쪽 메뉴 더보기 [설정] · 오른쪽 칩 스택 설정 칩이 연다.
--   [화면] 연출 세기(끔 · 약 · 보통 - 흔들림 · 번쩍임 · 남의 효과를 한 번에) · 번쩍임 줄이기 · 탑다운 시점 · 남의 궤적 흐리게 · 그래픽(보통 · 가벼움)
--   [소리] 음량 4(효과 · UI · 환경 · 음악) / [게임] 자동 스테이지 · 다른 서버 초월 알림 · 코드 입력 / [단축키] 단축키 보기(PanelRegistry.hotkeySheet - 09 문서 B-3 표).
--   값 = LocalPlayer Attribute(클라 코드는 이것만 읽는다) · 저장 = SettingsSave(서버가 SettingsData로 검증 · 저장 · Attribute 적용). 직업 변경은 캐릭터 창(C)으로 옮겼다(중복 삭제).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local AutoStageData = require(ReplicatedStorage.Shared.data.AutoStageData)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)
local SoundData = require(ReplicatedStorage.Shared.data.SoundData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Toggle = require(script.Parent.Parent.ui.kit.Toggle)
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local PanelRegistry = require(script.Parent.Parent.ui.PanelRegistry)
local UIManager = require(script.Parent.Parent.UIManager)
local AttackTrail = require(script.Parent.Parent.AttackTrail)

local SettingsPanel = {}
SettingsPanel.id = "settings"

local PANEL_SIZE = Vector2.new(520, 440)
local PAD = 12
local ROW = 48
local TAB_IDS = { "screen", "sound", "game", "hotkeys" }

local player = Players.LocalPlayer
local built
local saveRemote = ReplicatedStorage:WaitForChild("SettingsSave", 10)
local function save(key, value)
	if saveRemote then
		saveRemote:FireServer(key, value)
	end
end

local function page(parent, name)
	local body = Instance.new("ScrollingFrame")
	body.Name = name
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, Theme.tabHeight + 8)
	body.Size = UDim2.new(1, 0, 1, -(Theme.tabHeight + 8))
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = Theme.color("rim")
	body.AutomaticCanvasSize = Enum.AutomaticSize.Y
	body.CanvasSize = UDim2.new()
	body.Visible = false
	body.Parent = parent
	return body
end

-- 순환 버튼 줄(이름 · [값]) - choice 키
local function cycleRow(body, y, labelText, key, names, refs)
	local def = SettingsData.keys[key]
	local label = Theme.label(body, labelText, "body", "textPrimary")
	label.Position = UDim2.fromOffset(PAD, y)
	label.Size = UDim2.new(1, -PAD * 2 - 130, 0, 36)
	local function current()
		return player:GetAttribute(def.attrs[1]) or def.default
	end
	local b = Button.build({ parent = body, kind = "secondary", width = 120, position = UDim2.new(1, -PAD - 120, 0, y), text = names[current()] or tostring(current()),
		onActivated = function()
			local i = table.find(def.options, current()) or 1
			local nextValue = def.options[i % #def.options + 1]
			player:SetAttribute(def.attrs[1], nextValue)
			save(key, nextValue)
		end })
	b.root.Name = "Cycle_" .. key
	player:GetAttributeChangedSignal(def.attrs[1]):Connect(function()
		b.setText(names[current()] or tostring(current()))
	end)
	refs[key] = b
end

local function build()
	local panel = Panel.create({ id = SettingsPanel.id, kind = "window", title = Text.get("settings.title"), size = PANEL_SIZE })
	local content = panel.content
	local pages = {}
	for _, id in ipairs(TAB_IDS) do
		pages[id] = page(content, "Page_" .. id)
	end
	local tabList = {}
	for _, id in ipairs(TAB_IDS) do
		table.insert(tabList, { id = id, text = Text.get("settings.tab." .. id) })
	end
	local width = PANEL_SIZE.X - PAD * 2
	local refs = {}
	Tabs.build({ parent = content, tabs = tabList, selected = "screen", width = width, position = UDim2.fromOffset(PAD, 4), onSelect = function(id)
		for pid, p in pairs(pages) do
			p.Visible = pid == id
		end
	end })
	pages.screen.Visible = true

	-- [화면]
	local s = pages.screen
	cycleRow(s, PAD, Text.get("settings.fxLevel"), "fxLevel", { off = Text.get("settings.fx.off"), low = Text.get("settings.fx.low"), normal = Text.get("settings.fx.normal") }, refs)
	local fxHint = Theme.label(s, Text.get("settings.fxLevelHint"), "caption", "textSecondary")
	fxHint.Position = UDim2.fromOffset(PAD, PAD + 38)
	fxHint.Size = UDim2.new(1, -PAD * 2, 0, 18)
	refs.flashToggle = Toggle.build({ parent = s, name = "ReduceFlashesToggle", text = Text.get("settings.reduceFlashes"), value = player:GetAttribute("ReduceFlashes") == true,
		width = width, position = UDim2.fromOffset(PAD, PAD + 62), onChanged = function(v)
			player:SetAttribute("ReduceFlashes", v)
			save("reduceFlashes", v)
		end })
	refs.cameraToggle = Toggle.build({ parent = s, name = "CameraTopDownToggle", text = Text.get("settings.cameraTopDown"), value = player:GetAttribute("CameraTopDown") == true,
		width = width, position = UDim2.fromOffset(PAD, PAD + 62 + ROW), onChanged = function(v)
			player:SetAttribute("CameraTopDown", v)
			save("cameraTopDown", v)
		end })
	refs.dimToggle = Toggle.build({ parent = s, name = "DimOthersTrailToggle", text = Text.get("settings.dimOthersTrail"), value = AttackTrail.dimOthers(),
		width = width, position = UDim2.fromOffset(PAD, PAD + 62 + ROW * 2), onChanged = function(v)
			AttackTrail.setDimOthers(v)
			save("dimOthersTrail", v)
		end })
	cycleRow(s, PAD + 62 + ROW * 3, Text.get("settings.graphics"), "graphics", { normal = Text.get("settings.gfx.normal"), lite = Text.get("settings.gfx.lite") }, refs)
	local shiftHint = Theme.label(s, Text.get("settings.shiftLockHint"), "caption", "textSecondary")
	shiftHint.TextWrapped = true
	shiftHint.Position = UDim2.fromOffset(PAD, PAD + 62 + ROW * 4)
	shiftHint.Size = UDim2.new(1, -PAD * 2, 0, 36)

	-- [소리] 음량 4줄(효과 · UI · 환경 · 음악)
	local volumeRows = {}
	for index, categoryId in ipairs(SoundData.categoryOrder) do
		local key = SoundData.categories[categoryId].settingKey
		local def = SettingsData.keys[key]
		local y = PAD + (index - 1) * 52
		local nameLabel = Theme.label(pages.sound, Text.get("settings.volume." .. categoryId), "body", "textPrimary")
		nameLabel.Position = UDim2.fromOffset(PAD, y)
		nameLabel.Size = UDim2.new(0, 140, 0, Theme.buttonHeight)
		local valueLabel = Theme.label(pages.sound, "", "body", "textPrimary")
		valueLabel.Name = "VolumeValue_" .. categoryId
		valueLabel.TextXAlignment = Enum.TextXAlignment.Center
		valueLabel.Position = UDim2.fromOffset(PAD + 244, y)
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
		Button.build({ parent = pages.sound, name = "VolumeDown_" .. categoryId, kind = "secondary", width = 88, position = UDim2.fromOffset(PAD + 148, y), text = "−", onActivated = function()
			step(-1)
		end })
		Button.build({ parent = pages.sound, name = "VolumeUp_" .. categoryId, kind = "secondary", width = 88, position = UDim2.fromOffset(PAD + 308, y), text = "+", onActivated = function()
			step(1)
		end })
		player:GetAttributeChangedSignal(def.attrs[1]):Connect(render)
		render()
		volumeRows[categoryId] = { render = render }
	end

	-- [게임]
	local g = pages.game
	local autoLabel = Theme.label(g, Text.get("settings.autoStage"), "body", "textPrimary")
	autoLabel.Position = UDim2.fromOffset(PAD, PAD)
	autoLabel.Size = UDim2.new(1, -PAD * 2 - 130, 0, 36)
	local function presetName(id)
		for _, preset in ipairs(AutoStageData.presets) do
			if preset.id == id then
				return preset.name
			end
		end
		return AutoStageData.presets[1].name
	end
	local autoButton = Button.build({ parent = g, name = "AutoStageButton", kind = "secondary", width = 120, position = UDim2.new(1, -PAD - 120, 0, PAD),
		text = presetName(player:GetAttribute("AutoStage") or AutoStageData.default), onActivated = function()
			local cur = player:GetAttribute("AutoStage") or AutoStageData.default
			local nextId = AutoStageData.presets[1].id
			for index, preset in ipairs(AutoStageData.presets) do
				if preset.id == cur then
					nextId = (AutoStageData.presets[index + 1] or AutoStageData.presets[1]).id
					break
				end
			end
			ReplicatedStorage:WaitForChild("AutoStageSetting"):FireServer(nextId)
		end })
	player:GetAttributeChangedSignal("AutoStage"):Connect(function()
		autoButton.setText(presetName(player:GetAttribute("AutoStage") or AutoStageData.default))
	end)
	cycleRow(g, PAD + ROW, Text.get("settings.transcendNotice"), "transcendNotice", TranscendentData.announce.noticeModeNames, refs)
	do -- 코드 입력(서버 RedeemCode가 검증 · 대소문자 무시)
		local y = PAD + ROW * 2 + 8
		local box = Instance.new("TextBox")
		box.Name = "CodeBox"
		box.Position = UDim2.fromOffset(PAD, y)
		box.Size = UDim2.new(1, -PAD * 2 - 100, 0, Theme.buttonHeight)
		box.BackgroundColor3 = Theme.color("slot")
		box.TextColor3 = Theme.color("textPrimary")
		box.PlaceholderText = Text.get("settings.codePlaceholder")
		box.PlaceholderColor3 = Theme.color("textSecondary")
		box.Font = Theme.font
		box.TextSize = 16
		box.Text = ""
		box.ClearTextOnFocus = false
		box.Parent = g
		Theme.corner(box, 8)
		Button.build({ parent = g, name = "CodeRedeemButton", kind = "primary", width = 90, position = UDim2.new(1, -PAD - 90, 0, y), text = Text.get("settings.codeRedeem"),
			onActivated = function()
				local ok, result = pcall(function()
					return ReplicatedStorage:WaitForChild("RedeemCode"):InvokeServer(box.Text)
				end)
				local Toast = require(script.Parent.Parent.ui.kit.Toast)
				Toast.push("TC", { richParts = { { text = ok and type(result) == "table" and tostring(result.message) or Text.get("settings.codeLater"), colorName = "textPrimary", bold = true } }, seconds = 3, fadeSeconds = 0.3 })
				if ok and type(result) == "table" and result.ok then
					box.Text = ""
				end
			end })
	end

	-- [단축키] 단축키 보기(09 문서 B-3 최종 표)
	local h = pages.hotkeys
	for i, row in ipairs(PanelRegistry.hotkeySheet) do
		local y = PAD + (i - 1) * 30
		local chip = Theme.label(h, row.keys, "body", "gold")
		chip.Name = "Key_" .. i
		chip.Position = UDim2.fromOffset(PAD, y)
		chip.Size = UDim2.new(0, 190, 0, 28)
		local what = Theme.label(h, Text.get(row.text), "body", "textPrimary")
		what.Position = UDim2.fromOffset(PAD + 200, y)
		what.Size = UDim2.new(1, -(PAD * 2 + 200), 0, 28)
	end
	local phoneNote = Theme.label(h, Text.get("settings.hotkeysPhone"), "caption", "textSecondary")
	phoneNote.TextWrapped = true
	phoneNote.Position = UDim2.fromOffset(PAD, PAD + #PanelRegistry.hotkeySheet * 30 + 4)
	phoneNote.Size = UDim2.new(1, -PAD * 2, 0, 36)

	built = { panel = panel, refs = refs, volumeRows = volumeRows, pages = pages }
end

function SettingsPanel.toggle()
	if not built then
		build()
	end
	built.refs.cameraToggle.setValue(player:GetAttribute("CameraTopDown") == true, true)
	built.refs.dimToggle.setValue(AttackTrail.dimOthers(), true)
	built.refs.flashToggle.setValue(player:GetAttribute("ReduceFlashes") == true, true)
	for _, row in pairs(built.volumeRows) do
		row.render()
	end
	UIManager.switchTo(SettingsPanel.id)
end

function SettingsPanel.debugRefs()
	return built
end

return SettingsPanel
