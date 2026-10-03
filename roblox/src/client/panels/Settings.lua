-- 설정 창(M1-0 · Q14 저장 · QUEUE-ALL2 P2 B-4 ⑤ 정리 - 한 창에 분류 탭 4개). 왼쪽 메뉴 더보기 [설정] · 오른쪽 칩 스택 설정 칩이 연다.
--   [화면] 연출 세기(끔 · 약 · 보통 - 흔들림 · 번쩍임 · 남의 효과를 한 번에) · 번쩍임 줄이기 · 탑다운 시점 · 남의 궤적 흐리게 · 그래픽(보통 · 가벼움)
--   [소리] 음량 4(효과 · UI · 환경 · 음악) / [게임] 자동 스테이지 · 다른 서버 초월 알림 · 자동 정리(QUEUE-N1004 A-1) · 코드 입력 / [단축키] 단축키 보기(PanelRegistry.hotkeySheet - 09 문서 B-3 표).
--   값 = LocalPlayer Attribute(클라 코드는 이것만 읽는다) · 저장 = SettingsSave(서버가 SettingsData로 검증 · 저장 · Attribute 적용). 직업 변경은 캐릭터 창(C)으로 옮겼다(중복 삭제).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local AutoStageData = require(ReplicatedStorage.Shared.data.AutoStageData)
local SettingsData = require(ReplicatedStorage.Shared.data.SettingsData)
local SoundData = require(ReplicatedStorage.Shared.data.SoundData)
local UserInputService = game:GetService("UserInputService") -- QUEUE-ALL9C 1-7 음량 슬라이더 끌기
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData) -- QUEUE-N1004 A-1 자동 정리 기준 등급
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Toggle = require(script.Parent.Parent.ui.kit.Toggle)
local Tabs = require(script.Parent.Parent.ui.kit.Tabs)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local PanelRegistry = require(script.Parent.Parent.ui.PanelRegistry)
local UIManager = require(script.Parent.Parent.UIManager)
local AttackTrail = require(script.Parent.Parent.AttackTrail)
local GraphicsMode = require(script.Parent.Parent.GraphicsMode)

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
local function cycleRow(body, y, labelText, key, names, refs, resolve)
	local def = SettingsData.keys[key]
	local label = Theme.label(body, labelText, "body", "textPrimary")
	label.Position = UDim2.fromOffset(PAD, y)
	label.Size = UDim2.new(1, -PAD * 2 - 130, 0, 36)
	local function current()
		if resolve then -- QUEUE-ALL6 A2: 저장 전(auto)이면 실효값(기기 기본)을 보여 주고 거기서 다음 값으로
			return resolve()
		end
		return player:GetAttribute(def.attrs[1]) or def.default
	end
	local b = Button.build({ parent = body, kind = "secondary", width = 120, position = UDim2.new(1, -PAD - 120, 0, y), text = Text.name(names[current()] or tostring(current())),
		onActivated = function()
			local i = table.find(def.options, current()) or 1
			local nextValue = def.options[i % #def.options + 1]
			player:SetAttribute(def.attrs[1], nextValue)
			save(key, nextValue)
		end })
	b.root.Name = "Cycle_" .. key
	player:GetAttributeChangedSignal(def.attrs[1]):Connect(function()
		b.setText(Text.name(names[current()] or tostring(current())))
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
	local tabs = Tabs.build({ parent = content, tabs = tabList, selected = "screen", width = width, position = UDim2.fromOffset(PAD, 4), onSelect = function(id)
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
	cycleRow(s, PAD + 62 + ROW * 3, Text.get("settings.graphics"), "graphics", { normal = Text.get("settings.gfx.normal"), lite = Text.get("settings.gfx.lite") }, refs, GraphicsMode.effective)
	local gfxHint = Theme.label(s, Text.get("settings.gfx.liteHint"), "caption", "textSecondary") -- QUEUE-ALL6 A2: 가벼움에서 꺼지는 것
	gfxHint.Name = "GraphicsLiteHint"
	gfxHint.TextWrapped = true
	gfxHint.Position = UDim2.fromOffset(PAD, PAD + 62 + ROW * 3 + 38)
	gfxHint.Size = UDim2.new(1, -PAD * 2, 0, 36)
	local shiftHint = Theme.label(s, Text.get("settings.shiftLockHint"), "caption", "textSecondary")
	shiftHint.TextWrapped = true
	shiftHint.Position = UDim2.fromOffset(PAD, PAD + 62 + ROW * 4 + 30)
	shiftHint.Size = UDim2.new(1, -PAD * 2, 0, 36)

	-- [소리] 음량 4줄(효과 · UI · 환경 · 음악)
	local volumeRows = {}
	for index, categoryId in ipairs(SoundData.categoryOrder) do
		local key = SoundData.categories[categoryId].settingKey
		local def = SettingsData.keys[key]
		local y = PAD + (index - 1) * 52
		local nameLabel = Theme.label(pages.sound, Text.get("settings.volume." .. categoryId), "body", "textPrimary")
		nameLabel.Position = UDim2.fromOffset(PAD, y)
		nameLabel.Size = UDim2.new(0, 110, 0, Theme.buttonHeight)
		-- QUEUE-ALL9C 1-7 L4: [슬라이더(누르거나 끌기)] [숫자 0 ~ 100 입력] [음소거] - 손을 뗄 때 · 입력을 마칠 때 저장(끄는 중에는 Attribute만 - 소리가 바로 바뀐다)
		local muteKey = SoundData.categories[categoryId].muteKey
		local muteDef = muteKey and SettingsData.keys[muteKey]
		local SLIDER_X, SLIDER_W = PAD + 116, 170 -- 창 폭 520 안: 이름 110 · 슬라이더 170 · 숫자 52 · 음소거 96
		local track = Instance.new("TextButton")
		track.Name = "VolumeSlider_" .. categoryId
		track.Text = ""
		track.AutoButtonColor = false
		track.BackgroundColor3 = Theme.color("slot")
		track.Position = UDim2.fromOffset(SLIDER_X, y + Theme.buttonHeight / 2 - 6)
		track.Size = UDim2.fromOffset(SLIDER_W, 12)
		track.Parent = pages.sound
		Theme.corner(track, 6)
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BackgroundColor3 = Theme.color("ember")
		fill.Size = UDim2.fromScale(1, 1)
		fill.Parent = track
		Theme.corner(fill, 6)
		local knob = Instance.new("Frame")
		knob.Name = "Knob"
		knob.AnchorPoint = Vector2.new(0.5, 0.5)
		knob.Size = UDim2.fromOffset(20, 20)
		knob.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
		knob.Parent = track
		Theme.corner(knob, 10)
		local box = Instance.new("TextBox")
		box.Name = "VolumeValue_" .. categoryId
		box.Position = UDim2.fromOffset(SLIDER_X + SLIDER_W + 12, y)
		box.Size = UDim2.new(0, 52, 0, Theme.buttonHeight)
		box.BackgroundColor3 = Theme.color("slot")
		box.TextColor3 = Theme.color("textPrimary")
		box.Font = Theme.font
		box.TextSize = 16
		box.ClearTextOnFocus = true -- 누르면 비우고 새로 입력(비운 채 나가면 원래 값으로 다시 그림)
		box.Parent = pages.sound
		Theme.corner(box, 8)
		local function current()
			local v = player:GetAttribute(def.attrs[1])
			return type(v) == "number" and v or def.default
		end
		local function muted()
			return muteDef ~= nil and player:GetAttribute(muteDef.attrs[1]) == true
		end
		local muteButton
		local function render()
			local v = current()
			fill.Size = UDim2.fromScale(v, 1)
			knob.Position = UDim2.fromScale(v, 0.5)
			fill.BackgroundColor3 = muted() and Theme.color("textSecondary") or Theme.color("ember")
			if not box:IsFocused() then
				box.Text = tostring(math.floor(v * 100 + 0.5))
			end
			if muteButton then
				muteButton.setText(Text.get(muted() and "settings.muteOn" or "settings.muteOff"))
			end
		end
		local function setValue(v, persist)
			v = math.floor(math.clamp(v, 0, 1) * 100 + 0.5) / 100
			player:SetAttribute(def.attrs[1], v)
			if persist then
				save(key, v)
			end
			render()
		end
		local dragging = false
		local function fromX(x)
			return (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
		end
		track.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				setValue(fromX(input.Position.X), false)
			end
		end)
		UserInputService.InputChanged:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
				setValue(fromX(input.Position.X), false)
			end
		end)
		UserInputService.InputEnded:Connect(function(input)
			if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
				dragging = false
				setValue(current(), true)
			end
		end)
		box.FocusLost:Connect(function()
			local n = tonumber((box.Text:gsub("%%", "")))
			if n and n == n then
				setValue(n / 100, true)
			end
			render()
		end)
		if muteDef then
			muteButton = Button.build({ parent = pages.sound, name = "Mute_" .. categoryId, kind = "secondary", width = 96, position = UDim2.fromOffset(SLIDER_X + SLIDER_W + 74, y),
				text = Text.get("settings.muteOff"), onActivated = function()
					local v = not muted()
					player:SetAttribute(muteDef.attrs[1], v)
					save(muteKey, v)
					render()
				end })
			player:GetAttributeChangedSignal(muteDef.attrs[1]):Connect(render)
		end
		player:GetAttributeChangedSignal(def.attrs[1]):Connect(render)
		render()
		volumeRows[categoryId] = { render = render }
	end
	-- QUEUE-ALL7 C3: 다른 플레이어 효과음 줄이기(4인 보스전 피로 - 내 소리는 그대로)
	refs.quietOthersToggle = Toggle.build({ parent = pages.sound, name = "QuietOthersSfxToggle", text = Text.get("settings.quietOthersSfx"), value = player:GetAttribute("QuietOthersSfx") == true,
		width = width, position = UDim2.fromOffset(PAD, PAD + #SoundData.categoryOrder * 52 + 4), onChanged = function(v)
			player:SetAttribute("QuietOthersSfx", v)
			save("quietOthersSfx", v)
		end })

	-- [게임]
	local g = pages.game
	local autoLabel = Theme.label(g, Text.get("settings.autoStage"), "body", "textPrimary")
	autoLabel.Position = UDim2.fromOffset(PAD, PAD)
	autoLabel.Size = UDim2.new(1, -PAD * 2 - 130, 0, 36)
	local function presetName(id)
		for _, preset in ipairs(AutoStageData.presets) do
			if preset.id == id then
				return Text.name(preset.name)
			end
		end
		return Text.name(AutoStageData.presets[1].name)
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
	do -- QUEUE-N1004 A-1 자동 정리(가방 드롭다운과 같은 값 · 켜기/기준 = AutoProcessRequest(서버 검사) · 방식 = 설정 autoProcessMode)
		local y = PAD + ROW * 2
		local tidyLabel = Theme.label(g, Text.get("autoTidy.settings"), "body", "textPrimary")
		tidyLabel.Position = UDim2.fromOffset(PAD, y)
		tidyLabel.Size = UDim2.new(1, -PAD * 2 - 130, 0, 36)
		local function tidyText()
			local grade = ArmorData.grades[player:GetAttribute("AutoProcess") or "off"]
			return grade and Text.get("autoTidy.upTo", { grade = Text.name(grade.displayName) }) or Text.get("autoTidy.off")
		end
		local tidyButton = Button.build({ parent = g, name = "AutoTidyButton", kind = "secondary", width = 120, position = UDim2.new(1, -PAD - 120, 0, y), text = tidyText(),
			onActivated = function()
				local choices = ArmorData.autoProcessGradeChoices -- 끔 → 일반 이하 → 희귀 이하 → 영웅 이하 → 끔(가방 드롭다운과 같은 순서)
				local index = table.find(choices, player:GetAttribute("AutoProcess") or "off")
				local remote = ReplicatedStorage:WaitForChild("AutoProcessRequest")
				if index == nil then
					remote:FireServer(true, choices[#choices])
				elseif index > 1 then
					remote:FireServer(true, choices[index - 1])
				else
					remote:FireServer(false, choices[#choices])
				end
			end })
		player:GetAttributeChangedSignal("AutoProcess"):Connect(function()
			tidyButton.setText(tidyText())
		end)
		cycleRow(g, y + ROW, Text.get("autoTidy.mode"), "autoProcessMode", { sell = Text.get("autoTidy.mode.sell"), dismantle = Text.get("autoTidy.mode.dismantle") }, refs)
		local tidyNote = Theme.label(g, Text.get("autoTidy.note"), "caption", "textSecondary")
		tidyNote.Name = "AutoTidyNote"
		tidyNote.TextWrapped = true
		tidyNote.Position = UDim2.fromOffset(PAD, y + ROW * 2 - 8)
		tidyNote.Size = UDim2.new(1, -PAD * 2, 0, 18)
	end
	do -- 코드 입력(서버 RedeemCode가 검증 · 대소문자 무시)
		local y = PAD + ROW * 4 + 22
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
		-- QUEUE-ALL9C 1-6 환불 문구 ②: 구매를 못 받았을 때 안내(문구 그대로)
		local purchaseHelp = Theme.label(g, Text.get("settings.purchaseHelp"), "caption", "textSecondary")
		purchaseHelp.Name = "PurchaseHelp"
		purchaseHelp.TextWrapped = true
		purchaseHelp.Position = UDim2.fromOffset(PAD, y + Theme.buttonHeight + 12)
		purchaseHelp.Size = UDim2.new(1, -PAD * 2, 0, 40)
		-- QUEUE-ALL9C 1-8 [창 위치 초기화](PC · 태블릿 - 옮긴 창 · 가방 창을 기본 자리로)
		if not Theme.isMobile then
			Button.build({ parent = g, name = "WindowResetButton", kind = "secondary", width = 160, position = UDim2.fromOffset(PAD, y + Theme.buttonHeight + 60),
				text = Text.get("settings.windowReset"), onActivated = function()
					require(script.Parent.Parent.ui.WindowPositions).reset()
					local Toast = require(script.Parent.Parent.ui.kit.Toast)
					Toast.push("TC", { richParts = { { text = Text.get("settings.windowResetDone"), colorName = "textPrimary", bold = true } }, seconds = 2, fadeSeconds = 0.3 })
				end })
		end
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

	built = { panel = panel, refs = refs, volumeRows = volumeRows, pages = pages, tabs = tabs }
end

local function refreshRefs()
	if not built then
		build()
	end
	built.refs.cameraToggle.setValue(player:GetAttribute("CameraTopDown") == true, true)
	built.refs.dimToggle.setValue(AttackTrail.dimOthers(), true)
	built.refs.flashToggle.setValue(player:GetAttribute("ReduceFlashes") == true, true)
	for _, row in pairs(built.volumeRows) do
		row.render()
	end
end

function SettingsPanel.toggle()
	refreshRefs()
	UIManager.switchTo(SettingsPanel.id)
end

-- QUEUE-ALL7B 2: 마을 게시판(HubServices)이 [게임] 탭(코드 입력)으로 연다
function SettingsPanel.open(tabId)
	refreshRefs()
	if tabId and built.pages[tabId] then
		built.tabs.select(tabId)
	end
	return UIManager.isOpen(SettingsPanel.id) or UIManager.open(SettingsPanel.id)
end

function SettingsPanel.debugRefs()
	return built
end

return SettingsPanel
