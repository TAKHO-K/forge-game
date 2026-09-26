-- MV1 환생 해금 안내(18번 시트 규칙 - 그림 + 한 줄 · 40자 이하 · 번역 가능 문자열). 환생이 성공하면(RebirthResult) 새로 열린 이동 기술을 overlay 창 하나로 보여 준다.
--   내용 = MovementUnlockData.popups[회차](그림 종류 · TextData 키). 그림은 파트 없이 UI 도형(점 · 곡선 점 · 잎 · 별)으로 그린다(이미지 속 글자 없음).
--   기준 = 계정 최대 환생(MoveTier) - 이 환생으로 그 값이 올라갔을 때만 뜬다(다른 직업이 이미 더 많이 환생했으면 새로 열린 것이 없다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementUnlockData = require(ReplicatedStorage.Shared.data.MovementUnlockData)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.ui.kit.Panel)
local Button = require(script.Parent.ui.kit.Button)
local Theme = require(script.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.UIManager)

local player = Players.LocalPlayer
local ID = "moveUnlock"
local SIZE = Vector2.new(360, 250)
local PAD = 16

local built

local function dot(parent, x, y, d, color)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(0, x, 0, y)
	f.Size = UDim2.new(0, d, 0, d)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	return f
end

-- 그림(캔버스 = 폭 w · 높이 h 프레임): 사람 = 큰 점 · 궤적 = 작은 점 줄.
local function drawDiagram(canvas, kind)
	for _, child in ipairs(canvas:GetChildren()) do
		child:Destroy()
	end
	local w, h = canvas.AbsoluteSize.X > 0 and canvas.AbsoluteSize.X or SIZE.X - PAD * 2, canvas.AbsoluteSize.Y > 0 and canvas.AbsoluteSize.Y or 96
	local ground = Instance.new("Frame")
	ground.Size = UDim2.new(1, 0, 0, 3)
	ground.Position = UDim2.new(0, 0, 1, -3)
	ground.BackgroundColor3 = UIColors.rim
	ground.BorderSizePixel = 0
	ground.Parent = canvas
	local ink, hot = UIColors.textPrimary, UIColors.xp
	if kind == "airJump" or kind == "airCombo" then
		-- 두 번 솟는 궤적 + (airCombo면) 정점마다 별
		local pts = {}
		for i = 0, 20 do
			local t = i / 20
			local y = t < 0.5 and math.sin(t * 2 * math.pi / 2) or 1 + 0.6 * math.sin((t - 0.5) * 2 * math.pi / 2)
			table.insert(pts, { 20 + t * (w - 60), h - 10 - y * (h - 30) / 1.6 })
		end
		for _, p in ipairs(pts) do
			dot(canvas, p[1], p[2], 5, ink)
		end
		dot(canvas, pts[#pts][1] + 16, pts[#pts][2], 16, hot)
		if kind == "airCombo" then
			for k, i in ipairs({ 8, 14, 20 }) do
				dot(canvas, pts[i][1], pts[i][2] - 14, k == 3 and 16 or 10, k == 3 and hot or UIColors.ember)
			end
		end
	elseif kind == "glide" or kind == "boost" then
		-- 잎 글라이더 아래 사람이 길게 내려간다(boost면 더 길게 + 화살 끝)
		local len = kind == "boost" and 1 or 0.72
		for i = 0, 16 do
			local t = i / 16
			dot(canvas, 24 + t * (w - 60) * len, 18 + t * (h - 40) * 0.5, 4, ink)
		end
		local leaf = Instance.new("Frame")
		leaf.AnchorPoint = Vector2.new(0.5, 0.5)
		leaf.Size = UDim2.new(0, 46, 0, 16)
		leaf.Position = UDim2.new(0, 24 + (w - 60) * len, 0, 18 + (h - 40) * 0.5 - 16)
		leaf.BackgroundColor3 = MovementConfig.glide.look.leafColor
		leaf.BorderSizePixel = 0
		leaf.Parent = canvas
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = leaf
		dot(canvas, 24 + (w - 60) * len, 18 + (h - 40) * 0.5, 16, hot)
	else -- weapon: 큰 별 하나
		local star = Theme.label(canvas, "★", "title", "textPrimary")
		star.TextSize = 48
		star.Size = UDim2.new(1, 0, 1, 0)
		star.TextXAlignment = Enum.TextXAlignment.Center
	end
end

local function build()
	local refs = Panel.create({ id = ID, kind = "overlay", title = Text.get("moveUnlock.popup.title"), size = SIZE })
	local content = refs.content
	local canvas = Instance.new("Frame")
	canvas.Name = "Diagram"
	canvas.BackgroundColor3 = UIColors.slot
	canvas.BackgroundTransparency = 0.2
	canvas.BorderSizePixel = 0
	canvas.Position = UDim2.new(0, PAD, 0, 8)
	canvas.Size = UDim2.new(1, -PAD * 2, 0, 96)
	canvas.Parent = content
	local line = Theme.label(content, "", "header", "textPrimary")
	line.Name = "Line"
	line.TextWrapped = true
	line.Position = UDim2.new(0, PAD, 0, 110)
	line.Size = UDim2.new(1, -PAD * 2, 0, 40)
	line.TextXAlignment = Enum.TextXAlignment.Center
	Button.build({
		parent = content, name = "Ok", kind = "primary", text = Text.get("moveUnlock.popup.ok"), width = 120,
		anchorPoint = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -PAD),
		onActivated = function()
			UIManager.close(ID)
		end,
	})
	built = { refs = refs, canvas = canvas, line = line }
end

-- 회차 n의 안내를 연다(검증 · 스크린샷 훅도 이 함수).
local function show(n)
	local popup = MovementUnlockData.popups[n]
	if not popup then
		return false
	end
	if not built then
		build()
	end
	built.line.Text = Text.get(popup.textKey)
	UIManager.open(ID)
	task.defer(drawDiagram, built.canvas, popup.diagram)
	return true
end

local lastTier = player:GetAttribute("MoveTier") or 0
local pending = false -- 환생 결과를 받은 뒤 MoveTier가 따라오기를 기다리는 중
ReplicatedStorage:WaitForChild("RebirthResult").OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not data.success then
		return
	end
	pending = true
	task.delay(0.3, function() -- MoveTier Attribute가 따라올 시간
		pending = false
		local now = player:GetAttribute("MoveTier") or 0
		if now > lastTier then
			show(now)
		end
		lastTier = now
	end)
end)
player:GetAttributeChangedSignal("MoveTier"):Connect(function()
	if not pending then
		lastTier = player:GetAttribute("MoveTier") or 0 -- 로드 · 개발 명령 = 안내 없이 받아들인다
	end
end)

if RunService:IsStudio() then -- 스크린샷 · 검증 훅: 클라 execute_luau → PlayerGui.MV1PopupHook:Invoke(n)
	local hook = Instance.new("BindableFunction")
	hook.Name = "MV1PopupHook"
	hook.OnInvoke = show
	hook.Parent = player:WaitForChild("PlayerGui")
end
