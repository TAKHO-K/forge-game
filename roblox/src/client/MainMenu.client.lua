-- QUEUE-ALL9C 2-3 첫 화면 = 메인 메뉴 → (로딩) → 게임. 가림막(배경) = first/MenuBoot.client.lua가 접속 즉시 띄운 MainMenuGui · 값 = shared/data/MainMenuData · 글 = TextData_menu.
--   메뉴에 있는 동안 MainMenuData.steps(저장 · 맵 · 소품 · 캐릭터 · 주변 스트리밍 · 아이콘 · 소리)를 미리 불러온다. 메뉴는 저장을 다 읽은 뒤 보인다(이어하기 줄 = 직업 · 레벨 · 스테이지).
--   [이어하기] · [직업 선택]을 누를 때 남은 단계가 있으면 로딩 막대 + 팁 한 줄 → 다 되거나 loadCapSeconds가 지나면 입장(남은 단계는 배경에서 계속).
--   메뉴 · 로딩 동안 캐릭터 조작은 끈다(HUD · 창은 가림막 아래에 미리 지어진다 - 들어가면 완성된 화면).
--   배경 = 키 아트 한 장(first/MenuBoot - 가림막이 바로 불러와 서서히 표시 · 오기 전 = 하늘 그라데이션) · 게임 이름 자리 = GameInfoData.name.
--   끈 기능(데이터 스위치 · 코드 남김): 장소 사진 교차 전환(backgroundCrossfade) · 좌우 등급 빛줄기(lights.enabled).
--   설정 = 효과음 · 음악 · 그래픽 · 언어 · "다음부터 메뉴 건너뛰고 바로 시작"(SettingsData skipMenu - 직업이 있을 때만 건너뜀).
--   측정(ALL9F 집계) = 입장 때 Remote MenuTiming 한 번: 접속 → 메뉴 표시 · 메뉴 → 플레이(ms) · 상한 발동 · 건너뜀.
--   메뉴는 모든 접속에서 보인다(10-05 버그 수정) · 건너뛰기 = Studio 테스트 플래그 TestSkipMainMenuUntil(만료 시각 - shared/MenuGate)만 · 캐릭터는 입장 때 스폰(SlotRequest enterWorld) · 시험 훅 DevMenuStallStep(그 단계 안 끝냄 - 15초 상한) · 메뉴 Attribute DevBackground(교차 전환 장 고정).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("MainMenuGui", 20)
if not gui then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared.data.MainMenuData)
local ArtAssetIds = require(Shared.data.ArtAssetIds)
local ArtImportData = require(Shared.data.ArtImportData)
local ArmorData = require(Shared.data.ArmorData)
local GradeColor = require(Shared.GradeColor)
local GraphicsMode = require(script.Parent.GraphicsMode)
local ArtStyleV1Data = require(Shared.data.ArtStyleV1Data)
local SoundSheetData = require(Shared.data.SoundSheetData)
local SocialRewardData = require(Shared.data.SocialRewardData)
local SettingsData = require(Shared.data.SettingsData)
local GameInfoData = require(Shared.data.GameInfoData)
local Text = require(Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)
local Button = require(script.Parent.ui.kit.Button)
local Toggle = require(script.Parent.ui.kit.Toggle)
local SettingSave = require(script.Parent.ui.SettingSave)

local bootClock = gui:GetAttribute("BootClock") or os.clock()

-- 조작 끄기(입장 때 다시 켬): 이 게임은 PlayerModule이 없다 → 키보드 · 게임패드 입력을 최우선으로 삼킨다(Enter = 이어하기만 여기서 받는다). 터치 = 가림막(Active)이 막는다.
local entered = false
local BLOCK_ACTION = "MainMenuInputBlock"
local onEnterKey = nil
local function blockInput(_, state, input)
	if state == Enum.UserInputState.Begin and input.KeyCode == Enum.KeyCode.Return and onEnterKey then
		onEnterKey()
	end
	return Enum.ContextActionResult.Sink
end
local function bindBlock() -- QUEUE-MENU2 D: 메인 메뉴로 다시 열 때도 같은 막기
	ContextActionService:BindActionAtPriority(BLOCK_ACTION, blockInput, false, Enum.ContextActionPriority.High.Value + 100, Enum.UserInputType.Keyboard, Enum.UserInputType.Gamepad1)
end
bindBlock()
gui:WaitForChild("Sky").Active = true
-- 로블록스 채팅 창 · 플레이어 목록(CoreGui)이 왼쪽 위 메뉴를 덮어 클릭을 가로챈다 → 메뉴 동안 숨기고 입장 때 원래 값으로
local StarterGui = game:GetService("StarterGui")
local hiddenCore = {}
local function hideCore() -- 시작 때 + 메뉴를 보일 때 한 번 더(다른 스크립트가 시작하며 다시 켤 수 있다 - Nameplate 촬영 모드 적용)
	for _, coreType in ipairs({ Enum.CoreGuiType.Chat, Enum.CoreGuiType.PlayerList }) do
		local ok, was = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, coreType)
		if ok and was then
			hiddenCore[coreType] = true
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, false)
		end
	end
end
hideCore()

-- ── 미리 불러오기 ──────────────────────────────────────────────
local done = {}
local function waitAttribute(inst, name)
	while not inst:GetAttribute(name) do
		inst:GetAttributeChangedSignal(name):Wait()
	end
end
local function character()
	local c = player.Character or player.CharacterAdded:Wait()
	return c, c:WaitForChild("HumanoidRootPart")
end
local function preloadIds(ids)
	if #ids > 0 then
		pcall(ContentProvider.PreloadAsync, ContentProvider, ids)
	end
end
local STEP_RUNNERS = {
	profile = function()
		while player:GetAttribute("ClassId") == nil do
			player:GetAttributeChangedSignal("ClassId"):Wait()
		end
	end,
	map = function()
		waitAttribute(workspace, ArtImportData.mapBuiltAttribute)
	end,
	props = function()
		waitAttribute(workspace, ArtImportData.mapBuiltAttribute)
		if not workspace:GetAttribute(ArtStyleV1Data.attribute) then
			return -- 아트 끔 = 소품 메시 없음
		end
		waitAttribute(ReplicatedStorage:WaitForChild(ArtImportData.cacheFolder), ArtImportData.propsReadyAttribute)
	end,
	character = function()
		local c = character()
		pcall(ContentProvider.PreloadAsync, ContentProvider, { c })
	end,
	stream = function()
		local _, root = character()
		pcall(player.RequestStreamAroundAsync, player, root.Position, Data.streamTimeoutSeconds)
	end,
	icons = function()
		local ids = {}
		for key, e in pairs(ArtAssetIds) do
			for _, prefix in ipairs(Data.iconPrefixes) do
				if e.image and key:sub(1, #prefix) == prefix then
					table.insert(ids, "rbxassetid://" .. e.image)
				end
			end
		end
		preloadIds(ids)
	end,
	sounds = function()
		local ids = {}
		for _, sheet in pairs(SoundSheetData.sheets) do
			local e = ArtAssetIds[sheet.file]
			if e then
				table.insert(ids, "rbxassetid://" .. e.id)
			end
		end
		preloadIds(ids)
	end,
}
-- ── 장소 사진 교차 전환(사용자 10-03 결정으로 끔: MainMenuData.backgroundCrossfade · 코드는 남김 - 배경 = first/MenuBoot 키 아트) ──
local sky = gui:WaitForChild("Sky")
local pictures = {}
for i = 1, 2 do
	local pic = Instance.new("ImageLabel")
	pic.Name = "Picture" .. i
	pic.Size = UDim2.fromScale(1, 1)
	pic.BackgroundTransparency = 1
	pic.ScaleType = Enum.ScaleType.Crop
	pic.ImageTransparency = 1
	pic.ZIndex = 2
	pic.Parent = sky
	pictures[i] = pic
end
local bgIds = {}
for _, key in ipairs(Data.backgroundCrossfade and Data.backgrounds or {}) do -- 끔 = 사진 없음(배경 = 가림막의 키 아트 한 장)
	local e = ArtAssetIds[key]
	if e and e.image and e.status == "Approved" then
		table.insert(bgIds, "rbxassetid://" .. e.image)
	end
end
local bgLoaded = {} -- [id] = true(받음)
local firstBackgroundAt = nil
task.spawn(function()
	for _, id in ipairs(bgIds) do
		-- 글자 id는 콜백이 안 불리고, 끝난 직후 상태가 Loading으로 남기도 한다(Play 실측) → 실패 · 시간 초과만 거른다
		pcall(ContentProvider.PreloadAsync, ContentProvider, { id })
		local status = ContentProvider:GetAssetFetchStatus(id)
		bgLoaded[id] = status ~= Enum.AssetFetchStatus.Failure and status ~= Enum.AssetFetchStatus.TimedOut
	end
end)
-- 교차 전환: 위 장(ZIndex 3)이 서서히 나타나 아래 장을 덮고, 끝나면 아래 장을 비운다(깜빡임 없음)
task.spawn(function()
	local front, shown = 1, nil
	while gui.Parent do
		local nextIndex = nil
		local devIndex = RunService:IsStudio() and gui:GetAttribute("DevBackground") -- Studio 촬영용: 이 번호 장소로 고정
		if devIndex and bgIds[devIndex] and devIndex ~= shown then
			bgLoaded[bgIds[devIndex]] = true
		end
		for step = 1, #bgIds do
			if devIndex then
				nextIndex = devIndex ~= shown and bgIds[devIndex] and devIndex or nil
				break
			end
			local i = ((shown or 0) + step - 1) % #bgIds + 1
			if bgLoaded[bgIds[i]] and i ~= shown then
				nextIndex = i
				break
			end
		end
		if nextIndex then
			local top = pictures[front]
			local bottom = pictures[3 - front]
			top.Image = bgIds[nextIndex]
			top.ZIndex, bottom.ZIndex = 3, 2
			local fade = shown == nil and Data.backgroundFirstFadeSeconds or Data.backgroundFadeSeconds
			TweenService:Create(top, TweenInfo.new(fade, Enum.EasingStyle.Sine), { ImageTransparency = 0 }):Play()
			if shown == nil then
				firstBackgroundAt = os.clock()
			end
			task.delay(fade, function()
				if bottom.Parent then
					bottom.ImageTransparency = 1
				end
			end)
			shown, front = nextIndex, 3 - front
			local holdUntil = os.clock() + fade + Data.backgroundHoldSeconds
			while os.clock() < holdUntil and (not RunService:IsStudio() or gui:GetAttribute("DevBackground") == devIndex) do
				task.wait(0.2)
			end
		else
			task.wait(0.2)
		end
	end
end)

local totalWeight = 0
local bgWaitStart = os.clock()
while not firstBackgroundAt and #bgIds > 0 and os.clock() - bgWaitStart < Data.backgroundFirstWaitSeconds do
	task.wait(0.05)
end
for _, step in ipairs(Data.steps) do
	totalWeight += step.weight
	task.spawn(function()
		if RunService:IsStudio() and ReplicatedStorage:GetAttribute("DevMenuStallStep") == step.id then
			return -- Studio 시험: 이 단계를 끝내지 않음(15초 상한 확인용 - Edit ReplicatedStorage Attribute)
		end
		local ok, err = pcall(STEP_RUNNERS[step.id])
		if not ok then
			warn(("[MENU] 미리 불러오기 %s 실패(건너뜀): %s"):format(step.id, tostring(err)))
		end
		done[step.id] = os.clock()
	end)
end
local function progress()
	local sum = 0
	for _, step in ipairs(Data.steps) do
		if done[step.id] then
			sum += step.weight
		end
	end
	return sum / totalWeight
end

-- ── 화면 ──────────────────────────────────────────────────────
Theme.recompute()
local fadeTargets = {} -- { inst, 속성 } - 입장 때 투명하게
local texts = {} -- { label, key, argsFn } - 언어를 바꾸면 다시 쓴다
local function addFade(inst, prop)
	table.insert(fadeTargets, { inst, prop }) -- 3 = 되돌릴 값(입장 직전에 기록 - QUEUE-MENU2 D 메인 메뉴로 다시 열 때)
end
for _, name in ipairs({ "Sky", "Ground", "Shade" }) do
	local f = name == "Sky" and sky or sky:FindFirstChild(name)
	if f then
		addFade(f, "BackgroundTransparency")
	end
end
for _, pic in ipairs(pictures) do
	addFade(pic, "ImageTransparency")
end
for _, d in ipairs(sky:GetDescendants()) do -- 가림막의 키 아트(first/MenuBoot)
	if d:IsA("ImageLabel") and d.Parent and d.Parent.Name == "KeyArt" then
		addFade(d, "ImageTransparency")
	end
end

-- ── 등급 빛줄기(좌우 가장자리 · 아래 → 위 - 사용자 10-03 결정으로 끔: MainMenuData.lights.enabled · 코드는 남김) ─────────────────────────
local L = Data.lights
local lightLayer, lightsOn = nil, false
if L.enabled then
	lightLayer = Instance.new("Frame")
	lightLayer.Name = "GradeLights"
	lightLayer.BackgroundTransparency = 1
	lightLayer.Size = UDim2.fromScale(1, 1)
	lightLayer.ClipsDescendants = true
	lightLayer.ZIndex = 2
	lightLayer.Parent = gui
	sky.ZIndex = 1
	local lite = GraphicsMode.isLite()
	local function lightFrame(color, width)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = color
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0)
		f.Size = UDim2.new(0, width, L.height, 0)
		f.Position = UDim2.new(0, 0, 1.05, 0)
		f.Parent = lightLayer
		Theme.corner(f, math.floor(width / 2))
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.1, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		return f
	end
	local streaks = {} -- { frame, side, index, finale } - 미리 지어 재사용
	local order = ArmorData.gradeOrder
	for i, gradeId in ipairs(order) do
		local finale = i == #order
		local sides = lite and { i % 2 == 1 and "L" or "R" } or { "L", "R" }
		for _, side in ipairs(sides) do
			local width = math.random(L.width[1], L.width[2]) * (finale and L.finaleWidthScale or 1)
			local f = lightFrame(GradeColor.border(gradeId), math.floor(width))
			f.Name = "Light_" .. gradeId .. "_" .. side
			table.insert(streaks, { frame = f, side = side, index = i, finale = finale })
		end
	end
	local finaleColor = GradeColor.border(order[#order])
	local sparks = {}
	for i = 1, lite and L.sparks - 1 or L.sparks do
		local f = Instance.new("Frame")
		f.Name = "FinaleSpark" .. i
		f.BackgroundColor3 = finaleColor
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.new(0, 3, 0, L.sparkLength)
		f.Parent = lightLayer
		sparks[i] = f
	end
	local glow = Instance.new("Frame")
	glow.Name = "FinaleGlow"
	glow.BackgroundColor3 = finaleColor
	glow.BackgroundTransparency = 1
	glow.BorderSizePixel = 0
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Size = UDim2.fromOffset(0, 0)
	glow.Parent = lightLayer
	Theme.corner(glow, L.glowSize)
	local glowGradient = Instance.new("UIGradient")
	glowGradient.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
	glowGradient.Parent = glow

	local function edgeX(side)
		local x = (0.15 + math.random() * 0.85) * L.edge
		return side == "L" and x or 1 - x
	end
	local function launch(s)
		local f = s.frame
		local x = edgeX(s.side)
		local peak = s.finale and L.finaleTransparency or L.transparency
		f.Position = UDim2.new(x, 0, 1.05, 0)
		f.BackgroundTransparency = 1
		local rise = TweenInfo.new(L.riseSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(f, rise, { Position = UDim2.new(x, 0, -L.height - 0.02, 0) }):Play()
		TweenService:Create(f, TweenInfo.new(L.riseSeconds * 0.25), { BackgroundTransparency = peak }):Play()
		task.delay(L.riseSeconds * 0.55, function()
			TweenService:Create(f, TweenInfo.new(L.riseSeconds * 0.45), { BackgroundTransparency = 1 }):Play()
		end)
		if s.finale and (s.side == "R" or lite) then
			-- 금빛 균열 반짝(한 번만 - 오른쪽 빛줄기): 화면 위쪽에 닿을 즈음 그 자리에서 짧은 금 줄이 갈라지듯 번쩍 + 둥근 빛
			task.delay(L.riseSeconds * 0.45, function()
				local y = 0.22
				glow.Position = UDim2.new(x, 0, y, 0)
				glow.Size = UDim2.fromOffset(L.glowSize * 0.3, L.glowSize * 0.3)
				glow.BackgroundTransparency = 0.2
				TweenService:Create(glow, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(L.glowSize, L.glowSize), BackgroundTransparency = 1 }):Play()
				for i, sp in ipairs(sparks) do
					local k = i - (#sparks + 1) / 2
					sp.Position = UDim2.new(x, k * 10, y, 0)
					sp.Rotation = k * 35 + math.random(-10, 10)
					sp.Size = UDim2.new(0, 3, 0, L.sparkLength * 0.3)
					sp.BackgroundTransparency = 0
					TweenService:Create(sp, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = UDim2.new(0, 2, 0, L.sparkLength), BackgroundTransparency = 1 }):Play()
				end
			end)
		end
	end
	lightsOn = true
	task.spawn(function()
		local spacing = (L.cycleSeconds - L.riseSeconds) / math.max(1, #order - 1)
		while lightsOn and gui.Parent do
			for _, s in ipairs(streaks) do
				task.delay((s.index - 1) * spacing + (s.side == "R" and spacing * 0.35 or 0), function()
					if lightsOn then
						launch(s)
					end
				end)
			end
			task.wait(L.cycleSeconds)
		end
	end)
end -- L.enabled


local function textOf(key, argsFn)
	return Text.get(key, argsFn and argsFn() or nil)
end
local function bindText(inst, key, argsFn)
	table.insert(texts, { inst, key, argsFn })
	inst.Text = textOf(key, argsFn)
	return inst
end
local function refreshTexts()
	for _, t in ipairs(texts) do
		if t[1] and t[2] and t[1].Parent then
			t[1].Text = textOf(t[2], t[3])
		end
	end
end

local waitLabel = Theme.label(gui, "", "header", "textPrimary")
waitLabel.Name = "MenuWait"
waitLabel.AnchorPoint = Vector2.new(0.5, 1)
waitLabel.Position = UDim2.new(0.5, 0, 1, -40)
waitLabel.Size = UDim2.new(1, -32, 0, 24)
waitLabel.TextXAlignment = Enum.TextXAlignment.Center
waitLabel.ZIndex = 3
bindText(waitLabel, "menu.waitProfile")

local root = Instance.new("Frame")
root.Name = "Menu"
root.BackgroundTransparency = 1
root.AnchorPoint = Vector2.new(0, 0.5)
root.Visible = false
root.ZIndex = 3 -- 배경(1) 위
root.Parent = gui

local function rowHeight()
	return Theme.buttonHeight
end

local menuWidth = Data.panelWidth
local function placeRoot() -- 메뉴 묶음 · 로고 = 화면 왼쪽 menuZone(35%) 안 · 왼쪽 여백 menuMargin(최소 16px)
	local w = gui.AbsoluteSize.X
	if w <= 0 then
		return
	end
	local x = math.max(16, math.floor(w * Data.menuMargin))
	menuWidth = math.min(Data.panelWidth, math.floor(w * Data.menuZone) - x)
	root.Size = UDim2.new(0, menuWidth, 1, -32)
	root.AnchorPoint = Vector2.new(0, 0.5)
	root.Position = UDim2.new(0, x, 0.5, 0)
end
placeRoot()
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeRoot)

-- 페이지 = 가운데 정렬 목록(내용이 높으면 스크롤)
local pages = {}
local function makePage(name)
	local page = Instance.new("ScrollingFrame")
	page.Name = name
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.Size = UDim2.fromScale(1, 1)
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.ScrollBarThickness = 4
	page.Visible = false
	page.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, Theme.space[2])
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = page
	pages[name] = page
	return page
end
local v2 = nil -- QUEUE-UI UI-1 메인 메뉴 v2(MainMenuData.v2Menu - 아래에서 짓는다) · 메인 페이지 = v2 · 설정 · 소식 페이지 = 옛 모양 그대로
local function showPage(name)
	if v2 and name == "MainPage" then
		for _, page in pairs(pages) do
			page.Visible = false
		end
		root.Visible = false
		v2.show()
		return
	end
	for n, page in pairs(pages) do
		page.Visible = n == name
	end
end

local function panelBox(parent, height, order)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.color("panel")
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, -8, 0, height)
	f.LayoutOrder = order
	f.Parent = parent
	Theme.corner(f, Theme.corner.chip)
	return f
end

-- 메인 페이지(맨 위 = 게임 이름 자리 - GameInfoData.name · 메뉴 항목은 아래 4개)
local mainPage = makePage("MainPage")
local function gameName() -- 사용자 10-04: 플레이어 언어로(names에 없으면 기본 name)
	return GameInfoData.names[Text.languageFor(nil)] or GameInfoData.name
end
local logo = Theme.label(mainPage, gameName(), "title", "textPrimary")
logo.Name = "GameLogo"
do -- 긴 이름(Beyond Legendary)이 폰 폭에서 잘리지 않게 - 칸에 맞춰 줄이되 logoTextSize를 넘지 않음
	logo.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = Data.logoTextSize
	limit.Parent = logo
end
player:GetAttributeChangedSignal(SettingsData.keys.language.attrs[1]):Connect(function()
	logo.Text = gameName()
end)
logo.Font = Enum.Font.GothamBlack
logo.TextSize = Data.logoTextSize
logo.LayoutOrder = 0
logo.Size = UDim2.new(1, -8, 0, Data.logoTextSize + 12)
local logoStroke = Instance.new("UIStroke")
logoStroke.Thickness = 2
logoStroke.Transparency = 0.3
logoStroke.Parent = logo
local continueCard = Instance.new("TextButton")
continueCard.Name = "MenuContinue"
continueCard.AutoButtonColor = true
continueCard.Text = ""
continueCard.BackgroundColor3 = Theme.color("ember")
continueCard.Size = UDim2.new(1, -8, 0, Data.continueHeight + (Theme.isMobile and 8 or 0))
continueCard.LayoutOrder = 1
continueCard.Parent = mainPage
Theme.corner(continueCard, Theme.corner.button)
local continueTitle = Theme.label(continueCard, "", "title", "panel") -- QUEUE-N1004 A-2: 주황 카드 위 밝은 글자 2.2:1 → 어두운 글자 7.4:1(검사 = tools/check_grade_colors.py ④)
continueTitle.Position = UDim2.new(0, 16, 0, 8)
continueTitle.Size = UDim2.new(1, -32, 0.5, -4)
local continueSub = Theme.label(continueCard, "", "body", "panel")
continueSub.Position = UDim2.new(0, 16, 0.5, 2)
continueSub.Size = UDim2.new(1, -32, 0.5, -10)

local function hasClass()
	local id = player:GetAttribute("ClassId")
	return type(id) == "string" and id ~= ""
end
local function continueArgs()
	return {
		class = Text.get("class.name." .. tostring(player:GetAttribute("ClassId"))),
		level = tostring(player:GetAttribute("CharacterLevel") or 1),
		stage = tostring(player:GetAttribute("InfiniteStage") or 1),
	}
end
local function refreshContinue()
	if hasClass() then
		continueTitle.Text = Text.get("menu.continue")
		continueSub.Text = Text.get("menu.continueSub", continueArgs())
	else
		continueTitle.Text = Text.get("menu.start")
		continueSub.Text = Text.get("menu.newSub")
	end
end
for _, attr in ipairs({ "ClassId", "CharacterLevel", "InfiniteStage" }) do
	player:GetAttributeChangedSignal(attr):Connect(refreshContinue)
end

local enter -- 아래 정의
local function menuButton(page, name, key, order, onActivated)
	local refs = Button.build({ parent = page, name = name, kind = "secondary", width = Data.panelWidth - 8, layoutOrder = order, text = "", onActivated = onActivated })
	refs.root.Size = UDim2.new(1, -8, 0, rowHeight())
	table.insert(texts, { refs.root, key })
	refs.setText(Text.get(key))
	return refs
end

-- 설정 페이지
local settingsPage = makePage("SettingsPage")
local function settingRow(order)
	local row = panelBox(settingsPage, rowHeight() + 8, order)
	local name = Theme.label(row, "", "body", "textPrimary")
	name.Position = UDim2.new(0, 12, 0, 0)
	name.Size = UDim2.new(0.38, -12, 1, 0)
	return row, name
end
local function smallButton(parent, name, text, anchorX, offsetX, width)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = Vector2.new(anchorX, 0.5)
	b.Position = UDim2.new(anchorX, offsetX, 0.5, 0)
	b.Size = UDim2.new(0, width, 0, rowHeight())
	b.BackgroundColor3 = Theme.color("slot")
	b.TextColor3 = Theme.color("textPrimary")
	b.Font = Theme.font
	b.TextSize = Theme.textSize("body")
	b.Text = text
	b.Parent = parent
	Theme.corner(b, Theme.corner.chip)
	Theme.stroke(b)
	return b
end
local function volumeRow(order, key, labelKey)
	local def = SettingsData.keys[key]
	local row, name = settingRow(order)
	row.Name = "Row_" .. key
	bindText(name, labelKey)
	local value = Theme.label(row, "", "body", "textPrimary")
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -12 - rowHeight() - 4, 0.5, 0)
	value.Size = UDim2.new(0, 48, 1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Center
	local function current()
		return player:GetAttribute(def.attrs[1]) or def.default
	end
	local function render()
		value.Text = Text.get("menu.percent", { percent = ("%d"):format(math.floor(current() * 100 + 0.5)) })
	end
	local function change(delta)
		local v = math.clamp(math.floor((current() + delta) * 100 + 0.5) / 100, 0, 1)
		SettingSave(key, v)
		render()
	end
	smallButton(row, "Minus", "−", 1, -12 - rowHeight() - 4 - 48 - 4, rowHeight()).Activated:Connect(function()
		change(-SettingsData.volumeStep)
	end)
	smallButton(row, "Plus", "+", 1, -12, rowHeight()).Activated:Connect(function()
		change(SettingsData.volumeStep)
	end)
	player:GetAttributeChangedSignal(def.attrs[1]):Connect(render)
	render()
end
local function cycleRow(order, key, labelKey, options, valueKeyPrefix, onChanged)
	local def = SettingsData.keys[key]
	local row, name = settingRow(order)
	row.Name = "Row_" .. key
	bindText(name, labelKey)
	local button = smallButton(row, "Cycle", "", 1, -12, 150)
	button.Size = UDim2.new(0.58, -12, 0, rowHeight()) -- 폭 = 줄 비율(최대 150)
	local cap = Instance.new("UISizeConstraint")
	cap.MaxSize = Vector2.new(150, math.huge)
	cap.Parent = button
	local function current()
		return player:GetAttribute(def.attrs[1]) or def.default
	end
	local function render()
		button.Text = Text.get(valueKeyPrefix .. tostring(current()))
	end
	table.insert(texts, { button, nil, nil, render })
	button.Activated:Connect(function()
		local i = table.find(options, current()) or 0
		SettingSave(key, options[i % #options + 1])
		render()
		if onChanged then
			onChanged()
		end
	end)
	render()
end
volumeRow(1, "volumeSfx", "menu.set.sfx")
volumeRow(2, "volumeMusic", "menu.set.music")
cycleRow(3, "graphics", "menu.set.graphics", SettingsData.keys.graphics.options, "menu.set.gfx.")
cycleRow(4, "language", "menu.set.language", SettingsData.keys.language.options, "menu.set.lang.", function()
	refreshTexts()
end)
local langNote = Theme.label(settingsPage, "", "caption", "textPrimary") -- 배경 그림 위 글자: 회색은 3.3:1 → 밝은 글자 8.1:1(캡처 표본)
langNote.Size = UDim2.new(1, -8, 0, Theme.textSize("caption") + 6)
langNote.LayoutOrder = 5
langNote.TextWrapped = true
bindText(langNote, "menu.set.langNote")
local skipBox = panelBox(settingsPage, rowHeight() + 8, 6)
skipBox.Visible = Data.skipMenuOption == true -- QUEUE-MENU2 C: "메뉴 건너뛰기" 옵션 UI 제거(코드 · 저장 필드 skipMenu 남김 - 켬이던 유저도 메뉴 표시)
local skipToggle = Toggle.build({ parent = skipBox, name = "SkipMenuToggle", text = Text.get("menu.set.skip"), value = Data.skipMenuOption == true and player:GetAttribute("SkipMainMenu") == true,
	width = menuWidth - 32, position = UDim2.new(0, 12, 0.5, -12), onChanged = function(v)
		SettingSave("skipMenu", v)
	end })
skipToggle.root.AnchorPoint = Vector2.new(0, 0.5) -- 토글 높이(PC · 폰 다름)와 상관없이 줄 가운데
skipToggle.root.Position = UDim2.new(0, 12, 0.5, 0)
skipToggle.root.Size = UDim2.new(1, -24, 1, -8) -- 폭 = 줄 비율(지을 때 화면 폭이 아직 0일 수 있다) · 좁은 폰 = 두 줄
local skipLabel = skipToggle.root:FindFirstChild("Label")
if skipLabel then
	skipLabel.TextWrapped = true
	skipLabel.TextTruncate = Enum.TextTruncate.None
	skipLabel.Size = UDim2.new(1, -34, 1, 0)
end
table.insert(texts, { nil, nil, nil, function()
	skipToggle.setText(Text.get("menu.set.skip"))
end })

-- 소식 페이지(업데이트 한 줄 · 코드는 마을 게시판 그대로)
local newsPage = makePage("NewsPage")
local newsBox = panelBox(newsPage, 132, 1) -- QUEUE-ALL9E1-ADD C: 다음 업데이트 줄 자리(+36)
newsBox.Name = "NewsBox"
local newsLine = Theme.label(newsBox, "", "body", "textPrimary")
newsLine.Position = UDim2.new(0, 12, 0, 8)
newsLine.Size = UDim2.new(1, -24, 0, 48)
newsLine.TextWrapped = true
newsLine.TextTruncate = Enum.TextTruncate.None
newsLine.TextYAlignment = Enum.TextYAlignment.Top
local latest = SocialRewardData.news[1]
if latest then
	bindText(newsLine, "update.board.newsLine", function()
		return { date = latest.date, text = Text.get(latest.textKey) }
	end)
end
local nextLine = Theme.label(newsBox, "", "caption", "textPrimary") -- QUEUE-ALL9E1-ADD C: 다음 업데이트(데이터 키 하나 - SocialRewardData.nextUpdateKey)
nextLine.Name = "NextUpdate"
nextLine.Position = UDim2.new(0, 12, 0, 60)
nextLine.Size = UDim2.new(1, -24, 0, 36)
nextLine.TextWrapped = true
nextLine.TextTruncate = Enum.TextTruncate.None
nextLine.TextYAlignment = Enum.TextYAlignment.Top
if SocialRewardData.nextUpdateKey then
	bindText(nextLine, SocialRewardData.nextUpdateKey)
end
local codeNote = Theme.label(newsBox, "", "caption", "textPrimary") -- QUEUE-N1004 A-2: 회색 4.48:1(뒤가 밝을 때) → 4.5 이상
codeNote.Position = UDim2.new(0, 12, 1, -28)
codeNote.Size = UDim2.new(1, -24, 0, 20)
bindText(codeNote, "menu.news.codes")

for _, page in ipairs({ settingsPage, newsPage }) do
	menuButton(page, "MenuBack", "menu.back", 99, function()
		showPage("MainPage")
	end)
end

-- refreshTexts가 render 함수 줄(4번째 칸)도 부르게
local baseRefresh = refreshTexts
refreshTexts = function()
	baseRefresh()
	for _, t in ipairs(texts) do
		if t[4] then
			t[4]()
		end
	end
	refreshContinue()
end

-- ── 로딩 ──────────────────────────────────────────────────────
local loading = Instance.new("Frame")
loading.Name = "Loading"
loading.BackgroundTransparency = 1
loading.AnchorPoint = Vector2.new(0.5, 1)
loading.Position = UDim2.new(0.5, 0, 1, -32)
loading.Size = UDim2.new(0, Data.barWidth, 0, 64)
loading.Visible = false
loading.ZIndex = 3
loading.Parent = gui
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MaxSize = Vector2.new(Data.barWidth, 64)
sizeConstraint.Parent = loading
loading.Size = UDim2.new(1, -32, 0, 64)
local loadingBack = Instance.new("Frame") -- 팁 · 막대 받침(배경 그림 아래쪽이 밝아도 글자 대비)
loadingBack.Name = "Back"
loadingBack.BackgroundColor3 = Theme.color("panel")
loadingBack.BackgroundTransparency = 0.3
loadingBack.BorderSizePixel = 0
loadingBack.Position = UDim2.new(0, -12, 0, -8)
loadingBack.Size = UDim2.new(1, 24, 1, 22)
loadingBack.Parent = loading
Theme.corner(loadingBack, Theme.corner.chip)
local tip = Theme.label(loading, "", "body", "textPrimary")
tip.Name = "Tip"
tip.Size = UDim2.new(1, 0, 0, 36)
tip.TextWrapped = true
tip.TextTruncate = Enum.TextTruncate.None
tip.TextXAlignment = Enum.TextXAlignment.Center
local tipStroke = Instance.new("UIStroke")
tipStroke.Thickness = 1
tipStroke.Transparency = 0.4
tipStroke.Parent = tip
local barBack = Instance.new("Frame")
barBack.Name = "Bar"
barBack.Position = UDim2.new(0, 0, 0, 42)
barBack.Size = UDim2.new(1, 0, 0, 10)
barBack.BackgroundColor3 = Theme.color("panel")
barBack.BackgroundTransparency = 0.2
barBack.BorderSizePixel = 0
barBack.Parent = loading
Theme.corner(barBack, 5)
local barFill = Instance.new("Frame")
barFill.Name = "Fill"
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Theme.color("xp")
barFill.BorderSizePixel = 0
barFill.Parent = barBack
Theme.corner(barFill, 5)
local percentLabel = Theme.label(loading, "", "caption", "textPrimary")
percentLabel.Name = "Percent"
percentLabel.Position = UDim2.new(0, 0, 0, 54)
percentLabel.Size = UDim2.new(1, 0, 0, 14)
percentLabel.TextXAlignment = Enum.TextXAlignment.Center

local function allDone()
	return progress() >= 1
end

local menuShownClock = nil
enter = function(mode, skipped)
	if entered then
		return
	end
	entered = true
	lightsOn = false
	if lightLayer then
		lightLayer.Visible = false
	end
	local pressClock = os.clock()
	if v2 then
		v2.hide()
	end
	task.spawn(function() -- 메인 메뉴 버그(10-05): 접속 때 캐릭터를 월드에 두지 않는다 → 입장하는 지금 스폰(로딩 막대 앞 - 캐릭터 · 주변 스트리밍 단계가 스폰을 기다린다)(칸 play · new가 이미 스폰했으면 서버가 아무것도 안 함)
		local remote = ReplicatedStorage:FindFirstChild("SlotRequest")
		if remote then
			pcall(function()
				remote:InvokeServer("enterWorld")
			end)
		end
	end)
	root.Visible = false
	waitLabel.Visible = false
	menuShownClock = menuShownClock or pressClock
	local capHit = false
	if not allDone() then
		tip.Text = Text.get(Data.tips[math.random(#Data.tips)])
		loading.Visible = true
		while not allDone() do
			local p = progress()
			barFill.Size = UDim2.fromScale(p, 1)
			percentLabel.Text = Text.get("menu.loading", { percent = ("%d"):format(math.floor(p * 100)) })
			if os.clock() - pressClock >= Data.loadCapSeconds then
				capHit = true
				break
			end
			task.wait(0.1)
		end
		barFill.Size = UDim2.fromScale(progress(), 1)
	end
	local playClock = os.clock()
	local left = {}
	for _, step in ipairs(Data.steps) do
		if not done[step.id] then
			table.insert(left, step.id)
		end
	end
	local timing = ReplicatedStorage:FindFirstChild("MenuTiming")
	if timing then
		timing:FireServer({ showMs = math.floor((menuShownClock - bootClock) * 1000), playMs = math.floor((playClock - pressClock) * 1000), capHit = capHit, skipped = skipped == true })
	end
	ContextActionService:UnbindAction(BLOCK_ACTION)
	if player:GetAttribute("CaptureMode") ~= true then
		for coreType in pairs(hiddenCore) do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, true)
		end
	end
	loading.Visible = false
	local info = TweenInfo.new(Data.fadeSeconds)
	for _, t in ipairs(fadeTargets) do
		t[3] = t[1][t[2]] -- QUEUE-MENU2 D: 다시 열 때 되돌릴 값 = 입장 직전 보이던 값(키 아트는 시작 때 아직 서서히 나타나는 중이라 그때 값은 투명)
		TweenService:Create(t[1], info, { [t[2]] = 1 }):Play()
	end
	if mode == "classes" and hasClass() then
		local holder = script.Parent:FindFirstChild("ClassSelectUI")
		local signal = holder and holder:FindFirstChild("OpenClassSelect")
		if signal then
			signal:Fire()
		end
	end
	task.delay(Data.fadeSeconds + 0.05, function()
		if entered then
			gui.Enabled = false -- QUEUE-MENU2 D: 지우지 않고 숨김(설정 → [메인 메뉴로] = 다시 연다)
		end
	end)
end

-- ── QUEUE-MENU2 E: 이어하기 창(캐릭터 칸) · 새 캐릭터 ─────────────
local SlotSaveData = require(Shared.data.SlotSaveData)
local slotRemote = SlotSaveData.enabled and ReplicatedStorage:WaitForChild("SlotRequest", 10) or nil
local slotWindow = slotRemote and require(script.Parent.ui.SlotWindow).new(gui, {
	onPlay = function(slot)
		local ok, res = pcall(function()
			return slotRemote:InvokeServer("play", slot)
		end)
		if ok and res and res.ok then
			enter("continue")
			return true
		end
		return false, ok and res and res.reason
	end,
	onNew = function()
		local ok, res = pcall(function()
			return slotRemote:InvokeServer("new")
		end)
		if ok and res and res.ok then
			enter("classes") -- 캐릭터 없음(ClassId "") = 직업 선택 창이 스스로 열린다
			return true
		end
		return false, ok and res and res.reason
	end,
}) or nil
local function openSlots()
	if slotWindow and slotWindow.open() then
		return true
	end
	return false
end
if Data.v2Menu then
	v2 = require(script.Parent.ui.v2.MainMenuV2).new(gui, {
		enter = function(mode)
			enter(mode)
		end,
		showOldPage = function(name)
			v2.hide()
			root.Visible = true
			showPage(name)
		end,
		slotRemote = slotRemote,
		classSelectRequest = ReplicatedStorage:WaitForChild("ClassSelectRequest", 10),
		settingSave = SettingSave,
	})
	local baseRefresh2 = refreshTexts
	refreshTexts = function()
		baseRefresh2()
		v2.refreshTexts()
	end
end

-- QUEUE-MENU2 D: 다시 열기(설정 → [메인 메뉴로] - 서버가 저장 · 파티 해제 · 캐릭터를 뺀 뒤)
local function reopen()
	if not entered then
		return
	end
	entered = false
	for _, t in ipairs(fadeTargets) do
		if t[3] ~= nil then
			t[1][t[2]] = t[3]
		end
	end
	gui.Enabled = true
	bindBlock()
	hideCore()
	refreshTexts()
	refreshContinue()
	waitLabel.Visible = false
	loading.Visible = false
	if v2 then -- 메뉴 다시 열기 = 이어하기 창 펼친 채
		showPage("MainPage")
		v2.openSlots()
		return
	end
	showPage("MainPage")
	root.Visible = true
	if slotWindow then
		slotWindow.close()
	end
	openSlots()
end
local reopenSignal = Instance.new("BindableEvent")
reopenSignal.Name = "OpenMainMenu"
reopenSignal.Parent = script
reopenSignal.Event:Connect(reopen)

continueCard.Activated:Connect(function()
	if not openSlots() then -- QUEUE-MENU2 E: 캐릭터 칸 창(스위치 끔 · 서버 없음 = 옛 동작)
		enter("continue")
	end
end)
menuButton(mainPage, "MenuClasses", "menu.classSelect", 2, function()
	if openSlots() then -- QUEUE-MENU2 C: 직업 선택 = 새 캐릭터 - 칸 창의 "+ 새 캐릭터"(빈 칸이 없으면 보관 안내)
		return
	end
	enter("classes")
end)
menuButton(mainPage, "MenuSettings", "menu.settings", 3, function()
	showPage("SettingsPage")
end)
menuButton(mainPage, "MenuNews", "menu.news", 4, function()
	showPage("NewsPage")
end)
onEnterKey = function()
	if v2 then
		v2.onEnterKey()
		return
	end
	if root.Visible and pages.MainPage.Visible then
		if not openSlots() then
			enter("continue")
		end
	end
end

-- ── 메뉴 표시(저장 · 설정을 읽은 뒤) ─────────────────────────────
-- 메인 메뉴 버그(10-05): 건너뛰기 = 테스트 플래그 TestSkipMainMenuUntil만(shared/MenuGate) - 옛 VerifyArmedUntil · DevSkipMainMenu · 저장값 skipMenu는 읽지 않는다
local MenuGate = require(Shared.MenuGate)
local function devSkip()
	return MenuGate.shouldSkip({ isStudio = RunService:IsStudio(), now = os.time(), flagUntil = ReplicatedStorage:GetAttribute(MenuGate.flagName) })
end

while not done.profile do
	task.wait(0.05)
end
if devSkip() then
	enter("continue", true)
	return
end
refreshTexts()
hideCore()
showPage("MainPage")
root.Visible = v2 == nil
waitLabel.Visible = false
menuShownClock = os.clock()
