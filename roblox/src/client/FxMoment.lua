-- QUEUE-ALL2 P4 1순위 ⑥ · 2순위 연출 공통 조각(docs/visual-audit.md 3-2). 판정 없음 - 그리기만. 수치 = shared/data/FxMomentData.
--   FxMoment.scale() = ArtStyleV1 켬일 때 LocalPlayer FxScale(보통 1 · 약 0.5 · 끔 0) · 끔이면 0 → 호출부는 0이면 꾸밈 연출을 건너뛴다(끄면 전과 같음).
--   FxMoment.pop(obj, peak, seconds) = UIScale 팝(1 → peak → 1) · 같은 대상 연타는 새 팝이 덮는다.
--   FxMoment.banner(style, main, sub, image) = 상단 가운데 배너 한 줄(차례대로 하나씩 - 겹치지 않음) · FxMoment.stamp(text) = 도장(줄 앞으로 끼어듦).
--   배너 자리 = 중앙 금지 구역(40% × 50%) 위 · ScreenMap TC bossBar 선(아트 켬이면 보스바는 화면 아래 - 비어 있다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local FxMomentData = require(ReplicatedStorage.Shared.data.FxMomentData)

local FxMoment = {}
local player = Players.LocalPlayer
local B = FxMomentData.banner

function FxMoment.isOn()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

-- 0 = 하지 않음 · 0.5 = 약 · 1 = 보통
function FxMoment.scale()
	if not FxMoment.isOn() then
		return 0
	end
	local fx = player:GetAttribute("FxScale")
	return type(fx) == "number" and math.clamp(fx, 0, 1) or 1
end

function FxMoment.reduceFlashes()
	return player:GetAttribute("ReduceFlashes") == true
end

-- UIScale 팝: 1 → 1 + (peak − 1) × 세기 → 1. 위로 35%(Quad Out) · 되돌림 65%(Back Out)
local popTokens = setmetatable({}, { __mode = "k" })
function FxMoment.pop(obj, peak, seconds, strength)
	strength = strength or FxMoment.scale()
	if not obj or strength <= 0 then
		return
	end
	local ui = obj:FindFirstChild("FxMomentPop")
	if not ui then
		ui = Instance.new("UIScale")
		ui.Name = "FxMomentPop"
		ui.Parent = obj
	end
	local token = (popTokens[obj] or 0) + 1
	popTokens[obj] = token
	local top = 1 + (peak - 1) * strength
	local up = TweenService:Create(ui, TweenInfo.new(seconds * 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = top })
	up.Completed:Connect(function()
		if popTokens[obj] == token then
			TweenService:Create(ui, TweenInfo.new(seconds * 0.65, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	up:Play()
end

-- ─────────────── 배너 ───────────────
local gui
local function screenGui()
	if gui and gui.Parent then
		return gui
	end
	gui = Instance.new("ScreenGui")
	gui.Name = "FxMomentGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = B.displayOrder
	gui.Parent = player:WaitForChild("PlayerGui")
	return gui
end

local function label(parent, text, size, color, font)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.Text = text
	l.TextColor3 = color
	l.TextSize = size -- TextScaled + 크기 제약은 Play 실측 12px로 줄어 그려져(칸 22px) 고정 크기 + 말줄임
	l.TextWrapped = false
	l.TextTruncate = Enum.TextTruncate.AtEnd
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Transparency = 0.3
	stroke.Parent = l
	l.Parent = parent
	return l
end

-- 배너 한 장을 짓는다(보이기 전 · 투명)
local function build(styleName, main, sub, image)
	local st = B.styles[styleName]
	local w, h = st.width or B.width, st.height or B.height
	local frame = Instance.new("Frame")
	frame.Name = "Moment_" .. styleName
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, B.top)
	frame.Size = UDim2.new(0, w, 0, h)
	frame.BackgroundColor3 = st.bg
	frame.BackgroundTransparency = st.bgTransparency
	frame.ClipsDescendants = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, styleName == "stamp" and 6 or 10)
	corner.Parent = frame
	local rim = Instance.new("UIStroke")
	rim.Color = st.rim
	rim.Thickness = styleName == "trans" and 2.5 or 2
	rim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = frame
	local canvas = Instance.new("CanvasGroup") -- 전체 투명도 한 번에(들어옴 · 나감)
	canvas.Name = "Body"
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.fromScale(1, 1)
	canvas.GroupTransparency = 1
	canvas.Parent = frame
	local left = 10
	if image and st.picture then
		local pic = Instance.new("ImageLabel")
		pic.Name = "Pic"
		pic.BackgroundTransparency = 1
		pic.ScaleType = Enum.ScaleType.Fit
		pic.Image = image.image or ""
		if image.silhouette then
			pic.ImageColor3 = Color3.new(0, 0, 0)
		end
		pic.AnchorPoint = Vector2.new(0, 0.5)
		pic.Position = UDim2.new(0, 6, 0.5, 0)
		pic.Size = UDim2.new(0, st.picture, 0, st.picture)
		pic.Parent = canvas
		left = st.picture + 12
	end
	local font = styleName == "stamp" and Enum.Font.GothamBlack or Enum.Font.GothamBold
	local mainLabel = label(canvas, main, st.textSize, st.text, font)
	mainLabel.Name = "Main"
	if sub then
		mainLabel.Position = UDim2.new(0, left, 0, 3)
		mainLabel.Size = UDim2.new(1, -left - 10, 0.58, -3)
		local subLabel = label(canvas, sub, math.floor(st.textSize * 0.6), st.sub or st.text)
		subLabel.Name = "Sub"
		subLabel.Position = UDim2.new(0, left, 0.58, 0)
		subLabel.Size = UDim2.new(1, -left - 10, 0.42, -3)
	else
		mainLabel.Position = UDim2.new(0, left, 0, 4)
		mainLabel.Size = UDim2.new(1, -left - 10, 1, -8)
	end
	if styleName == "trans" then -- 흑금: 글자에 금 그라디언트
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 170)), ColorSequenceKeypoint.new(0.5, st.text), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 130, 40)) })
		g.Rotation = 90
		g.Parent = mainLabel
	end
	if styleName == "stamp" then
		frame.Rotation = -4 -- 도장 기울기
	end
	frame.Parent = screenGui()
	return frame, canvas, st
end

-- 광택 한 번(ReduceFlashes · 세기 0이면 없음)
local function shine(frame)
	local band = Instance.new("Frame")
	band.Name = "Shine"
	band.BackgroundColor3 = Color3.new(1, 1, 1)
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0.25, 0, 1, 0)
	band.Position = UDim2.new(-0.3, 0, 0, 0)
	band.ZIndex = 5
	local g = Instance.new("UIGradient")
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = band
	band.Parent = frame
	local t = TweenService:Create(band, TweenInfo.new(B.shineSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Position = UDim2.new(1.05, 0, 0, 0) })
	t.Completed:Connect(function()
		band:Destroy()
	end)
	t:Play()
end

local queue = {}
local current = nil -- { frame, token }
local running = false
local token = 0

local function showOne(item)
	token += 1
	local mine = token
	local frame, canvas, st = build(item.style, item.main, item.sub, item.image)
	current = { frame = frame, token = mine }
	local strength = FxMoment.scale()
	local peak = st.popScale or B.popScale
	if strength > 0 then
		local ui = Instance.new("UIScale")
		ui.Scale = 1 + (peak - 1) * strength
		ui.Parent = frame
		TweenService:Create(ui, TweenInfo.new(B.inSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	TweenService:Create(canvas, TweenInfo.new(B.inSeconds * 0.6), { GroupTransparency = 0 }):Play()
	if strength > 0 and not FxMoment.reduceFlashes() and item.style ~= "cell" then
		task.delay(B.inSeconds, function()
			if frame.Parent then
				shine(frame)
			end
		end)
	end
	local hold = math.max(0, st.seconds - B.outSeconds)
	local elapsed = 0
	while elapsed < hold and token == mine do
		elapsed += task.wait(0.05)
	end
	if token == mine then
		local out = TweenService:Create(canvas, TweenInfo.new(B.outSeconds), { GroupTransparency = 1 })
		TweenService:Create(frame, TweenInfo.new(B.outSeconds), { BackgroundTransparency = 1 }):Play()
		local rim = frame:FindFirstChildOfClass("UIStroke")
		if rim then
			TweenService:Create(rim, TweenInfo.new(B.outSeconds), { Transparency = 1 }):Play()
		end
		out:Play()
		task.wait(B.outSeconds)
	end
	frame:Destroy()
	if current and current.token == mine then
		current = nil
	end
end

local function pump()
	if running then
		return
	end
	running = true
	task.spawn(function()
		while #queue > 0 do
			showOne(table.remove(queue, 1))
		end
		running = false
	end)
end

-- style = "trans" | "line" | "cell" · image = { image = "rbxassetid://..", silhouette } | nil
function FxMoment.banner(style, main, sub, image)
	if not FxMoment.isOn() or not B.styles[style] then
		return
	end
	table.insert(queue, { style = style, main = main, sub = sub, image = image })
	pump()
end

-- 도장: 지금 보이는 배너를 바로 치우고 맨 앞에서 보인다(보스 처치 순간)
function FxMoment.stamp(text)
	if not FxMoment.isOn() then
		return
	end
	if current then
		token += 1 -- 지금 배너의 대기 루프를 끊는다(그 배너는 곧바로 지워진다)
		current.frame.Visible = false
	end
	table.insert(queue, 1, { style = "stamp", main = text })
	pump()
end

return FxMoment
