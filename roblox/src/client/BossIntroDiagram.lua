-- BR1-2 전멸기 도식(첫 만남 카드 · 보스 선택 창 "기믹 도움말"이 같이 쓴다). 정사각 Frame 안에 작은 아레나(원) · 보스(빨강) · 나(흰 점) · 안전한 곳을 그린다.
-- 종류(BossData 보스의 intro.diagram): zones(금 간 원 밖) · pillar(기둥 뒤) · platform(같은 색 발판 - ● / ▲) · real(흰 원 = 진짜) · shell(고리 = 손 떼기) · rod(피뢰침 곁).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossIntroDiagram = {}

local RED = Color3.fromRGB(230, 40, 40)
local BLUE = Color3.fromRGB(70, 150, 255)
local SAFE = Color3.fromRGB(120, 200, 255)

local function shape(parent, x, y, w, h, color, round, text, transparency)
	local f = Instance.new(text and "TextLabel" or "Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new(x, 0, y, 0)
	f.Size = UDim2.new(w, 0, h, 0)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = transparency or 0
	f.BorderSizePixel = 0
	if text then
		f.Text = text
		f.TextScaled = true
		f.Font = Enum.Font.GothamBlack
		f.TextColor3 = Color3.new(1, 1, 1)
	end
	if round then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0.5, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function ring(parent, x, y, s, color, thickness)
	local f = shape(parent, x, y, s, s, color, true, nil, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 2
	stroke.Parent = f
	return f
end

function BossIntroDiagram.draw(frame, kind)
	local arena = shape(frame, 0.5, 0.5, 1, 1, UIColors.slot, true, nil, 0.2)
	arena.Name = "Arena"
	local function boss(x, y)
		return shape(frame, x or 0.5, y or 0.35, 0.16, 0.16, RED, true)
	end
	local function me(x, y)
		local dot = shape(frame, x, y, 0.1, 0.1, Color3.new(1, 1, 1), true)
		dot.Name = "Me"
		return dot
	end
	if kind == "zones" then
		boss()
		shape(frame, 0.45, 0.62, 0.42, 0.42, RED, true, nil, 0.45)
		me(0.8, 0.7)
	elseif kind == "pillar" then
		boss(0.5, 0.22)
		shape(frame, 0.5, 0.52, 0.5, 0.36, RED, false, nil, 0.7) -- 포효가 퍼지는 쪽
		shape(frame, 0.5, 0.6, 0.14, 0.14, SAFE, false) -- 기둥
		me(0.5, 0.78)
	elseif kind == "platform" then
		boss(0.5, 0.25)
		shape(frame, 0.28, 0.66, 0.24, 0.24, RED, false, "●")
		shape(frame, 0.72, 0.66, 0.24, 0.24, BLUE, false, "▲")
		me(0.28, 0.66)
		shape(frame, 0.28, 0.45, 0.12, 0.12, RED, true, "●") -- 내 머리 위 표시
	elseif kind == "real" then
		for _, p in ipairs({ { 0.5, 0.2 }, { 0.2, 0.5 }, { 0.8, 0.5 }, { 0.5, 0.8 } }) do
			boss(p[1], p[2])
		end
		ring(frame, 0.8, 0.5, 0.3, Color3.new(1, 1, 1), 3)
		me(0.6, 0.55)
	elseif kind == "shell" then
		boss(0.5, 0.45)
		ring(frame, 0.5, 0.45, 0.4, RED, 3)
		shape(frame, 0.5, 0.8, 0.22, 0.22, RED, false, "✖", 1).TextColor3 = RED
		me(0.8, 0.75)
	elseif kind == "rod" then
		boss(0.5, 0.25)
		for _, x in ipairs({ 0.3, 0.7 }) do
			ring(frame, x, 0.65, 0.3, Color3.fromRGB(255, 220, 60), 2)
			shape(frame, x, 0.65, 0.05, 0.2, Color3.fromRGB(255, 220, 60), false)
		end
		me(0.36, 0.72)
	end
end

return BossIntroDiagram
