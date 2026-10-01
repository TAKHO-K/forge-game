-- 스킬 툴팁(P3b D - 롤 · 로아 방식). SkillSlots가 Q · E 칸마다 SkillTooltip.attach로 입력을 붙인다.
--   PC(터치 배치가 아님) = 마우스를 올리면 뜨고 내리면 닫힌다. 클릭 = 시전(기존 그대로).
--   폰(터치 배치) = 짧게 누름 = 시전 · 길게 누름(LONG_PRESS_SECONDS) = 툴팁(손을 떼면 닫힌다) - 길게 누른 뒤 손을 떼도 시전하지 않는다(Activated를 한 번 삼킨다).
--     Studio에서 ForceTouchLayout이면 마우스 왼쪽 누름도 터치처럼 다룬다(길게 누르기를 PC에서 실제 입력으로 확인한다).
-- 글 = shared/SkillTooltipText(규칙 · 사거리는 SkillData, 수치는 서버 SkillStats.info - 스킬 판정과 같은 함수). 보일 때마다 1초보다 오래된 수치면 서버에 다시 묻는다.
-- 자리: PC = 칸 위(가운데 맞춤) · 폰 = 칸 왼쪽(손가락이 누르고 있는 칸을 가리지 않게). 화면 밖으로 안 나가게 민다. 넘치면 본문은 스크롤.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")

local SkillTooltipText = require(ReplicatedStorage.Shared.SkillTooltipText)
local SkillIconData = require(ReplicatedStorage.Shared.data.SkillIconData)
local UltimateData = require(ReplicatedStorage.Shared.data.UltimateData)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.Parent.ui.ArtImage)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local SkillTooltip = {}

SkillTooltip.longPressSeconds = 0.4
local INFO_MAX_AGE = 1
local PAD = 10
local LABEL_WIDTH = 84
local ICON = 56
local KEEP = { cooldown = true, expected = true, effect = true, heal = true, shield = true } -- 카드 = 핵심 수치 1 ~ 2개(QUEUE-ALL3 Q9) · QUEUE-ALL4 E: 줄 id로 고른다(줄 머리 글은 언어마다 다르다)
local MARGIN = 8

local player = Players.LocalPlayer
local infoRemote = ReplicatedStorage:WaitForChild("SkillInfoRequest")

local refs
local cache = { info = nil, at = -math.huge, fetching = false }
local current = nil -- { slotId, anchor, touch }

local function isTouch()
	return Theme.isMobile
end

local function build()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkillTooltipGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60 -- HUD(0 ~ 9) 위 · 창(100 ~) 아래
	gui.Parent = player:WaitForChild("PlayerGui")

	local root = Instance.new("Frame")
	root.Name = "SkillTooltip"
	root.BackgroundColor3 = UIColors.panel
	root.BackgroundTransparency = 0.05
	root.Visible = false
	root.Parent = gui
	Theme.corner(root, Theme.corner.button)
	Theme.stroke(root)

	-- QUEUE-ALL3 Q9 정보 카드: 왼쪽 위 스킬 그림(56) + 이름
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.new(0, PAD, 0, PAD)
	icon.Size = UDim2.fromOffset(ICON, ICON)
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = root
	local title = Theme.label(root, "", "header", "textPrimary")
	title.Name = "Title"
	title.Position = UDim2.new(0, PAD + ICON + 8, 0, PAD)
	title.Size = UDim2.new(1, -(PAD * 2 + ICON + 8), 0, ICON)
	title.TextWrapped = true

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.ScrollBarThickness = 3
	body.ScrollBarImageColor3 = UIColors.rim
	body.AutomaticCanvasSize = Enum.AutomaticSize.None
	body.Position = UDim2.new(0, PAD, 0, PAD + ICON + 8)
	body.Parent = root

	local guideButton = Instance.new("TextButton") -- 잠긴 칸: [환생 안내](환생 제단 길 안내)
	guideButton.Name = "RebirthGuide"
	guideButton.AnchorPoint = Vector2.new(1, 1)
	guideButton.Position = UDim2.new(1, -PAD, 1, -PAD)
	guideButton.Size = UDim2.fromOffset(130, 44)
	guideButton.BackgroundColor3 = UIColors.ember
	guideButton.Font = Theme.font
	guideButton.TextSize = 14
	guideButton.TextColor3 = UIColors.textPrimary
	guideButton.Text = Text.get("skillCard.rebirthGuide")
	guideButton.Visible = false
	guideButton.Parent = root
	Theme.corner(guideButton, 8)
	guideButton.Activated:Connect(function()
		require(script.Parent.Parent.QuestGuide).go("altar", false)
		SkillTooltip.hide()
	end)
	refs = { gui = gui, root = root, title = title, body = body, lines = {}, icon = icon, guideButton = guideButton }
end

local function width()
	return isTouch() and 420 or 380
end

-- 줄 글을 다시 채우고 크기 · 자리를 정한다.
local function render()
	if not current then
		return
	end
	local classId = player:GetAttribute("ClassId")
	local slotId = current.slotId
	local built = classId and classId ~= "" and SkillTooltipText.build(classId, slotId:upper(), cache.info and cache.info.classId == classId and cache.info or nil)
	if not built and classId and classId ~= "" then -- T(궁극기) · 대시 = 짧은 카드
		local ult = slotId == "t" and UltimateData.skills[classId]
		built = { keyText = slotId == "dash" and "Shift" or slotId:upper(), title = ult and ult.name or Text.get("skillCard.dash"), lines = {} }
		if ult then
			table.insert(built.lines, { id = "cooldown", label = Text.get("desc.skill.label.cooldown"), text = Text.get("skillCard.ultGauge") })
			if ult.durationSeconds then
				table.insert(built.lines, { id = "effect", label = Text.get("desc.skill.label.effect"), text = Text.get("skillCard.duration", { n = tostring(ult.durationSeconds) }), colorName = "ember" })
			end
		end
	end
	if not built then
		refs.root.Visible = false
		return
	end
	-- QUEUE-ALL3 Q9 카드 = 그림 · 이름 · 40자 한 줄 · 쿨타임 · 핵심 수치 1 ~ 2개 · 잠겼으면 "환생 n에서 열려요 · 지금 a / n" + [환생 안내]
	local short = classId and SkillIconData.short[classId] and SkillIconData.short[classId][slotId]
	local compact = {}
	if short then
		table.insert(compact, { label = "", text = short })
	end
	for _, entry in ipairs(built.lines) do
		if KEEP[entry.id] and #compact < 3 then
			table.insert(compact, entry)
		end
	end
	local need = SkillIconData.unlockRebirth[slotId] or 0
	local have = player:GetAttribute("MoveTier") or player:GetAttribute("RebirthCount") or 0
	local locked = need > have
	if locked then
		table.insert(compact, { label = "", text = Text.get("skillCard.unlock", { n = tostring(need), a = tostring(have) }), colorName = "gold" })
	end
	built.lines = compact
	refs.guideButton.Visible = locked
	local path = classId and SkillIconData.images[classId] and SkillIconData.images[classId][slotId]
	refs.icon.Image = path and ArtImage.get(path) or ""
	refs.icon.ImageColor3 = locked and Color3.fromRGB(120, 122, 130) or Color3.new(1, 1, 1)
	local w = width()
	refs.title.Text = Text.get("hud.skill.title", { key = built.keyText, name = built.title })
	for _, label in ipairs(refs.lines) do
		label.left:Destroy()
		label.right:Destroy()
	end
	refs.lines = {}
	local valueWidth = w - PAD * 2 - LABEL_WIDTH - 6
	local textSize = Theme.textSize("caption")
	local y = 0
	for _, entry in ipairs(built.lines) do
		local height = TextService:GetTextSize(entry.text, textSize, Theme.fontBody, Vector2.new(valueWidth, 1000)).Y + 4
		local left = Theme.label(refs.body, entry.label, "caption", "textSecondary")
		left.Position = UDim2.new(0, 0, 0, y)
		left.Size = UDim2.new(0, LABEL_WIDTH, 0, textSize + 4)
		local right = Theme.label(refs.body, entry.text, "caption", entry.colorName or "textPrimary")
		right.Position = UDim2.new(0, LABEL_WIDTH + 6, 0, y)
		right.Size = UDim2.new(0, valueWidth, 0, height)
		right.TextWrapped = true
		right.TextYAlignment = Enum.TextYAlignment.Top
		table.insert(refs.lines, { left = left, right = right })
		y += height + 2
	end
	local screen = refs.gui.AbsoluteSize
	local header = PAD + ICON + 8
	local height = math.min(header + y + PAD + (refs.guideButton.Visible and 52 or 0), screen.Y - MARGIN * 2)
	refs.root.Size = UDim2.new(0, w, 0, height)
	refs.body.Size = UDim2.new(1, -PAD * 2, 1, -(header + PAD + (refs.guideButton.Visible and 52 or 0)))
	refs.body.CanvasSize = UDim2.new(0, 0, 0, y)

	-- 자리(ScreenGui 좌표 - 칸과 같은 인셋 ScreenGui라 AbsolutePosition을 그대로 쓴다)
	local anchor = current.anchor
	local aPos, aSize = anchor.AbsolutePosition, anchor.AbsoluteSize
	local x, top
	if current.touch then
		x = aPos.X - MARGIN - w
		top = aPos.Y + aSize.Y / 2 - height / 2
		if x < MARGIN then -- 왼쪽에 자리가 없으면 위로
			x = aPos.X + aSize.X / 2 - w / 2
			top = aPos.Y - MARGIN - height
		end
	else
		x = aPos.X + aSize.X / 2 - w / 2
		top = aPos.Y - MARGIN - height
	end
	x = math.clamp(x, MARGIN, math.max(MARGIN, screen.X - w - MARGIN))
	top = math.clamp(top, MARGIN, math.max(MARGIN, screen.Y - height - MARGIN))
	refs.root.Position = UDim2.new(0, x, 0, top)
	refs.root.Visible = true
end

local function fetch()
	if cache.fetching then
		return
	end
	cache.fetching = true
	task.spawn(function()
		local ok, result = pcall(function()
			return infoRemote:InvokeServer()
		end)
		cache.fetching = false
		if ok and type(result) == "table" and result.ok then
			cache.info, cache.at = result.info, os.clock()
			render()
		end
	end)
end

function SkillTooltip.show(slotId, anchor, touch)
	if not refs then
		build()
	end
	local shown = { slotId = slotId, anchor = anchor, touch = touch == true }
	current = shown
	render()
	if os.clock() - cache.at > INFO_MAX_AGE then
		fetch()
	end
	-- 보이는 동안 1초마다 서버 수치를 새로 받는다(딜링모드 전환 · 장비 교체가 바로 반영되게 - 리뷰 6).
	task.spawn(function()
		while current == shown do
			task.wait(INFO_MAX_AGE)
			if current == shown and os.clock() - cache.at >= INFO_MAX_AGE then
				fetch()
			end
		end
	end)
	if RunService:IsStudio() then
		player:SetAttribute("P3bTooltipShown", (player:GetAttribute("P3bTooltipShown") or 0) + 1)
	end
end

function SkillTooltip.hide()
	current = nil
	if refs then
		refs.root.Visible = false
		for _, pair in ipairs(refs.lines) do -- 숨길 때 줄을 지운다(보일 때마다 새로 그린다 - 숨은 채 남는 인스턴스 0)
			pair.left:Destroy()
			pair.right:Destroy()
		end
		refs.lines = {}
	end
end

function SkillTooltip.isVisible()
	return refs ~= nil and refs.root.Visible
end

-- 칸(TextButton)에 입력을 붙인다. onTap = 시전(짧게 누름 · 클릭 · 기존 Activated 자리). isTouchLayout = SkillSlots의 터치 배치 판정.
function SkillTooltip.attach(button, slotId, onTap, isTouchLayout)
	local holding, pressToken, shownByPress, swallowActivate = false, 0, false, false
	local pressInput = nil -- 이 칸을 누른 입력(다른 손가락 - 조이스틱 - 을 뗀 것은 무시한다, 리뷰 3)
	local function isPress(input)
		local inputType = input.UserInputType
		return inputType == Enum.UserInputType.Touch or (inputType == Enum.UserInputType.MouseButton1 and isTouchLayout())
	end
	local function release()
		holding = false
		if shownByPress then
			shownByPress = false
			SkillTooltip.hide()
		end
	end
	button.InputBegan:Connect(function(input)
		if not isPress(input) then
			return
		end
		holding, swallowActivate, pressInput = true, false, input
		pressToken += 1
		local token = pressToken
		task.delay(SkillTooltip.longPressSeconds, function()
			if holding and token == pressToken then
				shownByPress, swallowActivate = true, true -- 이 누름은 툴팁이다 - 손을 뗄 때 오는 Activated를 삼킨다
				SkillTooltip.show(slotId, button, true)
			end
		end)
	end)
	button.InputEnded:Connect(function(input)
		if isPress(input) then
			release()
		end
	end)
	-- 손가락이 칸 밖으로 미끄러진 뒤 떼면 칸의 InputEnded가 안 올 수 있다 - 화면 어디서든 뗀 순간 닫는다.
	UserInputService.InputEnded:Connect(function(input)
		-- 터치는 손가락마다 다른 InputObject다 - 이 칸을 누른 그 손가락이 떨어졌을 때만. 마우스(Studio 터치 흉내)는 왼쪽 버튼이면 같은 누름이다.
		local same = input == pressInput or (pressInput ~= nil and input.UserInputType == Enum.UserInputType.MouseButton1 and pressInput.UserInputType == Enum.UserInputType.MouseButton1)
		if holding and same then
			release()
		end
	end)
	-- 칸이 숨거나 사라지면(직업 변경 · 배치 전환) 이 칸의 툴팁을 닫는다 - MouseLeave가 안 오는 경우(리뷰 7).
	local function hideIfMine()
		if current and current.anchor == button then
			SkillTooltip.hide()
		end
	end
	button:GetPropertyChangedSignal("Visible"):Connect(hideIfMine)
	button.AncestryChanged:Connect(hideIfMine)
	-- 칸이 움직이면(PC ↔ 터치 배치 전환) 마우스가 떠나도 MouseLeave가 안 온다 - 스크린샷 Play에서 PC 툴팁이 터치 배치 뒤에도 남았다.
	button:GetPropertyChangedSignal("AbsolutePosition"):Connect(hideIfMine)
	player:GetAttributeChangedSignal("ClassId"):Connect(hideIfMine)
	button.Activated:Connect(function()
		if swallowActivate then
			swallowActivate = false
			return
		end
		if RunService:IsStudio() then
			player:SetAttribute("P3bSkillTaps", (player:GetAttribute("P3bSkillTaps") or 0) + 1)
		end
		if onTap then -- T 칸(UltGauge)은 발동을 자기 버튼이 한다
			onTap()
		end
	end)
	button.MouseEnter:Connect(function()
		if not isTouchLayout() then
			SkillTooltip.show(slotId, button, false)
		end
	end)
	button.MouseLeave:Connect(function()
		if not isTouchLayout() and current and current.anchor == button then
			SkillTooltip.hide()
		end
	end)
end

-- 창이 열리면 툴팁을 닫는다(툴팁은 창 대역 아래 - 열린 창 뒤로 비친다).
UIManager.changed:Connect(function(_, isOpen)
	if isOpen then
		SkillTooltip.hide()
	end
end)

-- 검사용: 지금 툴팁 글(제목 + 줄 "이름: 값").
function SkillTooltip.debugText()
	if not refs or not refs.root.Visible then
		return nil
	end
	local lines = { refs.title.Text }
	for _, pair in ipairs(refs.lines) do
		table.insert(lines, pair.left.Text .. ": " .. pair.right.Text)
	end
	return table.concat(lines, "\n")
end

-- 검사용: 서버 수치를 새로 받아 돌려준다(툴팁이 쓰는 캐시도 갱신).
function SkillTooltip.debugFetch()
	local ok, result = pcall(function()
		return infoRemote:InvokeServer()
	end)
	if ok and type(result) == "table" and result.ok then
		cache.info, cache.at = result.info, os.clock()
		return result.info
	end
	return nil
end

return SkillTooltip
