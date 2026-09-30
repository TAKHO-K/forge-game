-- BR1-2 전멸기 도식(첫 만남 카드 · 보스 선택 창 "기믹 도움말"이 같이 쓴다). 정사각 Frame 안에 작은 아레나(원) · 보스(빨강) · 나(흰 점) · 안전한 곳을 그린다.
-- 종류(BossData 보스의 intro.diagram): zones(금 간 원 밖) · pillar(기둥 뒤) · platform(같은 색 발판 - ● / ▲) · real(흰 원 = 진짜) · shell(고리 = 손 떼기) · rod(피뢰침 곁)
-- · BR1-3 slices(금 간 조각 밖) · mound(빛나는 꼬리 둔덕) · bells(종 다섯 - 색 + 모양).
-- QUEUE-ALL2 P2(ref 18): 기믹 카드 = 그림 3컷(① 보이는 것 → ② 할 일 → ③ 실패하면) + 40자 이하 한 줄 - buildCard. 컷 목록 · 문구 키 = HelpCodexData.gimmickCards,
--   실패 숫자 = BossData에서 읽는다(failText). 컷 그림 = drawPicture(도형만 - 그림 안에 글자 없음. 숫자 칩 · 번호는 그림 밖 라벨). 첫 만남 카드 · 도움말 창이 같은 함수를 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local HelpCodexData = require(ReplicatedStorage.Shared.data.HelpCodexData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)

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
	elseif kind == "slices" then
		-- BR1-3 지반 붕괴: 피자 조각 8개 중 둘이 금 간 빨강 - 나는 옆 조각으로
		for k = 0, 7 do
			local a = (k + 0.5) / 8 * 2 * math.pi
			local red = k == 1 or k == 5
			shape(frame, 0.5 + math.cos(a) * 0.3, 0.5 + math.sin(a) * 0.3, 0.2, 0.2, red and RED or UIColors.slot, true, nil, red and 0.25 or 0.6)
		end
		boss(0.5, 0.5)
		me(0.5 + math.cos(3.2 / 8 * 2 * math.pi) * 0.33, 0.5 + math.sin(3.2 / 8 * 2 * math.pi) * 0.33)
	elseif kind == "mound" then
		-- BR1-3 진짜 전갈 찾기: 둔덕 셋 - 하나만 노란 꼬리 끝
		for i, p in ipairs({ { 0.25, 0.4 }, { 0.72, 0.32 }, { 0.5, 0.72 } }) do
			shape(frame, p[1], p[2], 0.24, 0.14, Color3.fromRGB(190, 160, 110), true)
			if i == 2 then
				shape(frame, p[1] + 0.06, p[2] - 0.09, 0.07, 0.1, Color3.fromRGB(255, 214, 90), false)
			end
		end
		me(0.62, 0.45)
	elseif kind == "bells" then
		-- BR1-3 수정 오르골: 종 다섯(색 + 모양) · 순서 번호
		local colors = { Color3.fromRGB(230, 159, 0), Color3.fromRGB(86, 180, 233), Color3.fromRGB(0, 158, 115), Color3.fromRGB(240, 228, 66), Color3.fromRGB(204, 121, 167) }
		local symbols = { "●", "▲", "■", "◆", "★" }
		boss(0.5, 0.5)
		for i = 1, 5 do
			local a = (i - 1) / 5 * 2 * math.pi - math.pi / 2
			shape(frame, 0.5 + math.cos(a) * 0.34, 0.5 + math.sin(a) * 0.34, 0.2, 0.2, colors[i], true, symbols[i])
		end
	elseif kind == "rod" then
		boss(0.5, 0.25)
		for _, x in ipairs({ 0.3, 0.7 }) do
			ring(frame, x, 0.65, 0.3, Color3.fromRGB(255, 220, 60), 2)
			shape(frame, x, 0.65, 0.05, 0.2, Color3.fromRGB(255, 220, 60), false)
		end
		me(0.36, 0.72)
	end
end

-- ═══ QUEUE-ALL2 P2(ref 18): 컷 그림 · 기믹 카드 ═══
-- 그림은 정사각 Frame(좌표 0 ~ 1) 안에 도형으로만 그린다. 색만 쓰지 않고 모양을 같이 쓴다: 안전 = 초록 + 흰 고리 · 실패 = 빨강 + X · 발판 = ● / ▲.
local GREEN = Color3.fromRGB(80, 210, 120)
local YELLOW = Color3.fromRGB(255, 214, 90)
local ORANGE = Color3.fromRGB(255, 140, 40)
local SAND = Color3.fromRGB(190, 160, 110)
local HOLE = Color3.fromRGB(14, 14, 20)
local ICE = Color3.fromRGB(150, 220, 255)
local STONE = Color3.fromRGB(120, 110, 100)
local ME_BODY = Color3.fromRGB(70, 130, 230)
local SKIN = Color3.fromRGB(255, 220, 180)
local WHITE = Color3.new(1, 1, 1)

-- 두 점을 잇는 막대(회전 Frame). 좌표가 정사각 비율이라 길이를 가로 비율로 줘도 된다.
local function bar(parent, x1, y1, x2, y2, color, thickness)
	local dx, dy = x2 - x1, y2 - y1
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.new((x1 + x2) / 2, 0, (y1 + y2) / 2, 0)
	f.Size = UDim2.new(math.sqrt(dx * dx + dy * dy), 0, 0, thickness or 3)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function arrow(parent, x1, y1, x2, y2, color)
	bar(parent, x1, y1, x2, y2, color, 3)
	local a = math.atan2(y2 - y1, x2 - x1)
	for _, side in ipairs({ 1, -1 }) do
		local b = a + math.pi + side * 0.6
		bar(parent, x2, y2, x2 + math.cos(b) * 0.09, y2 + math.sin(b) * 0.09, color, 3)
	end
end

local function cross(parent, x, y, s, color)
	bar(parent, x - s / 2, y - s / 2, x + s / 2, y + s / 2, color, 4)
	bar(parent, x - s / 2, y + s / 2, x + s / 2, y - s / 2, color, 4)
end

-- 나(사람 모양): 머리 원 + 몸 네모
local function person(parent, x, y, s, body, head, transparency)
	shape(parent, x, y + s * 0.18, s * 0.42, s * 0.5, body or ME_BODY, false, nil, transparency)
	local h = shape(parent, x, y - s * 0.27, s * 0.36, s * 0.36, head or SKIN, true, nil, transparency)
	h.Name = "Me"
end

local function bossAt(parent, bossId, x, y, s)
	local boss = BossData.bosses[bossId]
	local b = shape(parent, x, y, s, s, boss and boss.bodyColor or RED, true)
	b.Name = "Boss"
	shape(parent, x, y - s * 0.12, s * 0.5, s * 0.5, boss and boss.headColor or RED, true)
	return b
end

local function safeRing(parent, x, y, s)
	return ring(parent, x, y, s, GREEN, 3)
end

local function spark(parent, x, y, color)
	for k = 0, 3 do
		local a = k / 4 * 2 * math.pi + 0.4
		bar(parent, x + math.cos(a) * 0.05, y + math.sin(a) * 0.05, x + math.cos(a) * 0.12, y + math.sin(a) * 0.12, color or YELLOW, 3)
	end
end

-- 지반 붕괴: 조각 8개(가운데 = 보스). red = 금 간 조각(빨강 + 금 선) · holes = 꺼진 조각 · green = 옮겨 갈 조각(초록 + 흰 고리)
local function slices(frame, bossId, red, holes, green)
	shape(frame, 0.5, 0.5, 0.98, 0.98, UIColors.slot, true, nil, 0.35)
	local pos = {}
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * 2 * math.pi
		local x, y = 0.5 + math.cos(a) * 0.32, 0.5 + math.sin(a) * 0.32
		pos[k] = { x, y }
		local color, transparency = STONE, 0.3
		if holes[k] then
			color, transparency = HOLE, 0
		elseif red[k] then
			color, transparency = RED, 0.1
		elseif green[k] then
			color, transparency = GREEN, 0.1
		end
		shape(frame, x, y, 0.24, 0.24, color, true, nil, transparency)
		if red[k] then
			bar(frame, x - 0.08, y - 0.05, x + 0.07, y + 0.06, HOLE, 2)
		elseif green[k] then
			ring(frame, x, y, 0.28, WHITE, 2)
		end
	end
	bossAt(frame, bossId, 0.5, 0.5, 0.18)
	return pos
end

local function waves(frame, x, y)
	for _, s in ipairs({ 0.4, 0.62, 0.84 }) do
		ring(frame, x, y, s, ICE, 3)
	end
end

local function platforms(frame, redAt, blueAt, greenAround)
	local r = shape(frame, redAt[1], redAt[2], 0.34, 0.16, RED, true, "●")
	local b = shape(frame, blueAt[1], blueAt[2], 0.34, 0.16, BLUE, true, "▲")
	if greenAround then
		ring(frame, redAt[1], redAt[2], 0.4, GREEN, 3).Size = UDim2.new(0.42, 0, 0.24, 0)
	end
	return r, b
end

local function marker(frame, x, y, symbol, color)
	local m = shape(frame, x, y, 0.16, 0.16, HOLE, false, symbol)
	m.TextColor3 = color
	return m
end

local function bells(frame, bossId, transparency)
	local skill = BossData.bosses.crystal_queen.skills.orgel
	local pos = {}
	bossAt(frame, bossId, 0.5, 0.5, 0.18)
	for i, p in ipairs(skill.palette) do
		local a = (i - 1) / #skill.palette * 2 * math.pi - math.pi / 2
		local x, y = 0.5 + math.cos(a) * 0.34, 0.5 + math.sin(a) * 0.34
		pos[i] = { x, y }
		shape(frame, x, y, 0.2, 0.2, p.color, true, p.symbol, transparency)
	end
	return pos
end

local MOUNDS = { { 0.25, 0.42 }, { 0.72, 0.32 }, { 0.5, 0.76 } }
local function mounds(frame, glowIndex)
	for i, p in ipairs(MOUNDS) do
		shape(frame, p[1], p[2], 0.28, 0.15, SAND, true)
		if i == glowIndex then
			shape(frame, p[1] + 0.06, p[2] - 0.1, 0.06, 0.1, YELLOW, false)
			ring(frame, p[1] + 0.06, p[2] - 0.1, 0.18, YELLOW, 2)
		end
	end
end

local function rod(frame, x, y, glow)
	shape(frame, x, y, 0.05, 0.24, glow and YELLOW or STONE, false)
	shape(frame, x, y - 0.13, 0.08, 0.08, glow and YELLOW or STONE, true)
	if glow then
		ring(frame, x, y - 0.13, 0.22, YELLOW, 3)
	end
end

local function reticle(frame, x, y, color)
	ring(frame, x, y, 0.2, color, 2)
	bar(frame, x - 0.13, y, x + 0.13, y, color, 2)
	bar(frame, x, y - 0.13, x, y + 0.13, color, 2)
end

local function bolt(frame, x)
	bar(frame, x + 0.05, 0.05, x - 0.03, 0.3, YELLOW, 4)
	bar(frame, x - 0.03, 0.3, x + 0.04, 0.32, YELLOW, 4)
	bar(frame, x + 0.04, 0.32, x - 0.04, 0.6, YELLOW, 4)
end

local PICS = {
	slicesSee = function(frame, bossId)
		local pos = slices(frame, bossId, { [1] = true, [5] = true }, {}, {})
		person(frame, pos[1][1], pos[1][2], 0.2)
	end,
	slicesMove = function(frame, bossId)
		local pos = slices(frame, bossId, { [1] = true, [5] = true }, {}, { [2] = true })
		arrow(frame, pos[1][1], pos[1][2], pos[2][1] + 0.04, pos[2][2] - 0.02, WHITE)
		person(frame, pos[2][1], pos[2][2], 0.2)
	end,
	slicesFail = function(frame, bossId)
		local pos = slices(frame, bossId, {}, { [1] = true, [5] = true }, {})
		person(frame, pos[1][1], pos[1][2], 0.14, RED, nil, 0.35)
		cross(frame, pos[1][1] - 0.2, pos[1][2] - 0.02, 0.1, RED)
	end,
	pillarSee = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.2, 0.2)
		waves(frame, 0.5, 0.2)
		shape(frame, 0.26, 0.66, 0.14, 0.24, ICE, false)
		person(frame, 0.66, 0.8, 0.2)
	end,
	pillarHide = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.18, 0.2)
		shape(frame, 0.5, 0.4, 0.5, 0.18, RED, false, nil, 0.7)
		shape(frame, 0.5, 0.6, 0.26, 0.16, ICE, false)
		person(frame, 0.5, 0.82, 0.2)
		safeRing(frame, 0.5, 0.82, 0.3)
	end,
	pillarFail = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.2, 0.2)
		waves(frame, 0.5, 0.2)
		shape(frame, 0.34, 0.64, 0.06, 0.06, ICE, false)
		shape(frame, 0.42, 0.7, 0.05, 0.05, ICE, false)
		person(frame, 0.55, 0.78, 0.2, RED)
		cross(frame, 0.78, 0.74, 0.12, RED)
	end,
	platformSee = function(frame)
		platforms(frame, { 0.26, 0.82 }, { 0.74, 0.82 })
		marker(frame, 0.5, 0.18, "●", RED)
		person(frame, 0.5, 0.48, 0.22)
	end,
	platformStand = function(frame)
		platforms(frame, { 0.26, 0.82 }, { 0.74, 0.82 }, true)
		marker(frame, 0.26, 0.36, "●", RED)
		person(frame, 0.26, 0.64, 0.22)
	end,
	platformFail = function(frame)
		platforms(frame, { 0.26, 0.82 }, { 0.74, 0.82 })
		marker(frame, 0.74, 0.36, "●", RED)
		person(frame, 0.74, 0.64, 0.22, RED)
		cross(frame, 0.48, 0.6, 0.12, RED)
	end,
	bellsSee = function(frame, bossId)
		local pos = bells(frame, bossId)
		ring(frame, pos[1][1], pos[1][2], 0.28, WHITE, 3)
		ring(frame, pos[1][1], pos[1][2], 0.36, WHITE, 1)
	end,
	bellsHit = function(frame, bossId)
		local pos = bells(frame, bossId)
		safeRing(frame, pos[1][1], pos[1][2], 0.28)
		spark(frame, pos[1][1], pos[1][2])
		person(frame, pos[1][1] + 0.2, pos[1][2] + 0.14, 0.18)
	end,
	bellsFail = function(frame, bossId)
		bells(frame, bossId, 0.65)
		local diamond = shape(frame, 0.5, 0.5, 0.34, 0.34, ICE, false, nil, 0.55)
		diamond.Rotation = 45
		person(frame, 0.5, 0.5, 0.24, ICE, ICE, 0.1)
		cross(frame, 0.8, 0.82, 0.12, RED)
	end,
	moundSee = function(frame)
		mounds(frame, 2)
		person(frame, 0.34, 0.74, 0.18)
	end,
	moundHit = function(frame)
		mounds(frame, 2)
		arrow(frame, 0.5, 0.56, 0.66, 0.4, WHITE)
		spark(frame, 0.72, 0.32)
		person(frame, 0.44, 0.62, 0.18)
	end,
	moundFail = function(frame)
		mounds(frame, nil)
		for _, p in ipairs(MOUNDS) do
			ring(frame, p[1], p[2], 0.34, ORANGE, 3)
			spark(frame, p[1], p[2], ORANGE)
		end
		person(frame, 0.5, 0.5, 0.18, RED)
	end,
	rodSee = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.16, 0.18)
		rod(frame, 0.16, 0.62)
		rod(frame, 0.84, 0.62)
		reticle(frame, 0.5, 0.8, RED)
		person(frame, 0.5, 0.6, 0.2)
	end,
	rodLure = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.16, 0.18)
		rod(frame, 0.16, 0.62, true)
		rod(frame, 0.84, 0.62)
		arrow(frame, 0.56, 0.84, 0.3, 0.84, WHITE)
		reticle(frame, 0.2, 0.84, RED)
		person(frame, 0.34, 0.6, 0.2)
	end,
	rodFail = function(frame, bossId)
		bossAt(frame, bossId, 0.5, 0.16, 0.18)
		rod(frame, 0.16, 0.62)
		rod(frame, 0.84, 0.62)
		bolt(frame, 0.3)
		bolt(frame, 0.66)
		person(frame, 0.5, 0.74, 0.2, RED)
		cross(frame, 0.72, 0.78, 0.12, RED)
	end,
	-- 도움말: 잠긴 몹(회색 체력바 + 자물쇠 · 튕김)
	stealLock = function(frame)
		local bg = Color3.fromRGB(120, 196, 90)
		local back = shape(frame, 0.5, 0.5, 1, 1, bg, false)
		Theme.corner(back, 10)
		shape(frame, 0.5, 0.8, 0.62, 0.12, Color3.fromRGB(90, 150, 70), true)
		shape(frame, 0.5, 0.72, 0.46, 0.46, Color3.fromRGB(90, 200, 100), true)
		shape(frame, 0.5, 0.86, 0.5, 0.2, bg, false)
		shape(frame, 0.46, 0.3, 0.5, 0.07, Color3.fromRGB(150, 150, 160), true)
		shape(frame, 0.78, 0.32, 0.09, 0.08, YELLOW, false)
		ring(frame, 0.78, 0.26, 0.06, YELLOW, 2)
		spark(frame, 0.2, 0.62, WHITE)
	end,
}

-- 컷 그림 하나(정사각 Frame). 모르는 종류면 아무것도 그리지 않는다.
function BossIntroDiagram.drawPicture(frame, kind, bossId)
	local draw = PICS[kind]
	if draw then
		draw(frame, bossId)
	end
end

local function pct(x)
	return math.floor(x * 100 + 0.5)
end

-- 실패 숫자(문장 밖 칩) - BossData에서 읽는다(HelpCodexData.gimmickCards[보스].fail 규칙).
function BossIntroDiagram.failText(bossId)
	local card = HelpCodexData.gimmickCards[bossId]
	local boss = BossData.bosses[bossId]
	local fail = card and card.fail
	if not (fail and boss) then
		return ""
	end
	if fail.mechanics then
		local m = BossData.mechanics[fail.mechanics]
		return ("-%d~%d%%"):format(pct(m.firstMaxHpFraction), pct(m.maxHpFraction))
	end
	local skill = boss.skills[fail.skill]
	if fail.perTick then
		return ("-%d%% ×%d"):format(pct(skill.tickFraction), skill.ticks)
	end
	return ("-%d%%"):format(pct(skill.failMaxHpFraction))
end

-- 번개 조준경 필요 피뢰침 수(BR1-2 식 그대로: base + perExtra × (인원 − 1), 아레나 피뢰침 수 상한)
function BossIntroDiagram.rodsNeeded(boss, memberCount)
	local skill = boss.skills.rods
	local rodCount = 0
	for _, part in ipairs(boss.arenaKit and boss.arenaKit.parts or {}) do
		rodCount += part.tag == skill.rodTag and 1 or 0
	end
	return math.min(skill.requiredBase + skill.requiredPerExtra * math.max((memberCount or 1) - 1, 0), rodCount > 0 and rodCount or math.huge)
end

local function chipText(rule, boss, memberCount)
	if rule == "rods" then
		if memberCount then
			return ("×%d"):format(BossIntroDiagram.rodsNeeded(boss, memberCount))
		end
		return ("×%d~%d"):format(BossIntroDiagram.rodsNeeded(boss, 1), BossIntroDiagram.rodsNeeded(boss, PartyConfig.maxMembers))
	end
	return ""
end

-- 카드 배치(순수 계산 - 폭 · 모바일 여부만 본다). height = 컷 + 컷 아래 말 + 한 줄.
function BossIntroDiagram.cardLayout(width, mobile, panelHeight)
	local arrowW = 16
	local ph = panelHeight or (mobile and 96 or 124)
	local capH = Theme.textSizeFor("caption", mobile) + 6
	local lineH = Theme.textSizeFor("body", mobile) + 14
	return {
		arrowW = arrowW,
		pw = math.floor((width - arrowW * 2) / 3),
		ph = ph,
		capH = capH,
		lineH = lineH,
		height = ph + 4 + capH + 6 + lineH,
	}
end

-- 기믹 카드(그림 3컷 + 한 줄)를 parent 안에 짓는다. opts = { width(px - 필수), position, mobile, panelHeight, memberCount, zIndex }.
-- 반환 { root, height } - 카드 데이터가 없는 보스면 nil.
function BossIntroDiagram.buildCard(parent, bossId, opts)
	local card = HelpCodexData.gimmickCards[bossId]
	local boss = BossData.bosses[bossId]
	if not (card and boss) then
		return nil
	end
	local mobile = opts.mobile
	if mobile == nil then
		mobile = Theme.isMobile
	end
	local L = BossIntroDiagram.cardLayout(opts.width, mobile, opts.panelHeight)
	local root = Instance.new("Frame")
	root.Name = "GimmickCard"
	root.BackgroundTransparency = 1
	root.Position = opts.position or UDim2.new(0, 0, 0, 0)
	root.Size = UDim2.new(0, opts.width, 0, L.height)
	root.Parent = parent

	local badgeColors = { Theme.color("gold"), Theme.color("success"), Theme.color("danger") }
	local numberSize = Theme.textSizeFor("number", mobile)
	for i, p in ipairs(card.panels) do
		local x = (i - 1) * (L.pw + L.arrowW)
		local panel = Instance.new("Frame")
		panel.Name = "Panel" .. i
		panel.Position = UDim2.new(0, x, 0, 0)
		panel.Size = UDim2.new(0, L.pw, 0, L.ph)
		panel.BackgroundColor3 = Color3.fromRGB(38, 42, 62)
		panel.BorderSizePixel = 0
		panel.ClipsDescendants = true
		panel.Parent = root
		Theme.corner(panel, 8)

		local pic = Instance.new("Frame")
		pic.Name = "Pic"
		pic.AnchorPoint = Vector2.new(0.5, 0.5)
		pic.Position = UDim2.new(0.5, 0, 0.5, 4)
		pic.Size = UDim2.new(1, -16, 1, -16)
		pic.BackgroundTransparency = 1
		pic.Parent = panel
		local aspect = Instance.new("UIAspectRatioConstraint")
		aspect.AspectRatio = 1
		aspect.Parent = pic
		BossIntroDiagram.drawPicture(pic, p.pic, bossId)

		local badge = Theme.label(panel, tostring(i), "caption", "textPrimary")
		badge.Name = "Number"
		badge.Font = Theme.font
		badge.TextColor3 = Color3.fromRGB(20, 20, 30)
		badge.TextXAlignment = Enum.TextXAlignment.Center
		badge.BackgroundTransparency = 0
		badge.BackgroundColor3 = badgeColors[i] or badgeColors[3]
		badge.Position = UDim2.new(0, 5, 0, 5)
		badge.Size = UDim2.new(0, 22, 0, 22)
		Theme.corner(badge, 11)

		local chip = i == #card.panels and BossIntroDiagram.failText(bossId) or chipText(p.chip, boss, opts.memberCount)
		if chip ~= "" then
			local chipLabel = Theme.label(panel, chip, "number", i == #card.panels and "danger" or "gold")
			chipLabel.Name = i == #card.panels and "FailChip" or "Chip"
			chipLabel.Font = Enum.Font.GothamBlack
			chipLabel.TextSize = numberSize
			chipLabel.TextStrokeTransparency = 0.35
			chipLabel.TextXAlignment = Enum.TextXAlignment.Right
			chipLabel.TextTruncate = Enum.TextTruncate.None
			chipLabel.AnchorPoint = Vector2.new(1, 0)
			chipLabel.Position = UDim2.new(1, -6, 0, 4)
			chipLabel.Size = UDim2.new(1, -34, 0, numberSize + 4)
		end

		local caption = Theme.label(root, Text.get(p.captionKey), "caption", "textPrimary")
		caption.Name = "Caption" .. i
		caption.Font = Theme.font
		caption.TextXAlignment = Enum.TextXAlignment.Center
		caption.Position = UDim2.new(0, x, 0, L.ph + 4)
		caption.Size = UDim2.new(0, L.pw, 0, L.capH)

		if i < #card.panels then
			local chevron = Instance.new("Frame")
			chevron.Name = "Arrow" .. i
			chevron.BackgroundTransparency = 1
			chevron.Position = UDim2.new(0, x + L.pw, 0, math.floor(L.ph / 2) - 10)
			chevron.Size = UDim2.new(0, L.arrowW, 0, 20)
			chevron.Parent = root
			for _, side in ipairs({ -1, 1 }) do
				local b = Instance.new("Frame")
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.Position = UDim2.new(0.5, 0, 0.5, side * 3)
				b.Size = UDim2.new(0, 10, 0, 3)
				b.Rotation = side * -45
				b.BackgroundColor3 = WHITE
				b.BorderSizePixel = 0
				b.Parent = chevron
			end
		end
	end

	local lineBox = Instance.new("Frame")
	lineBox.Name = "LineBox"
	lineBox.Position = UDim2.new(0, 0, 0, L.ph + 4 + L.capH + 6)
	lineBox.Size = UDim2.new(1, 0, 0, L.lineH)
	lineBox.BackgroundColor3 = Color3.fromRGB(20, 22, 34)
	lineBox.BackgroundTransparency = 0.1
	lineBox.BorderSizePixel = 0
	lineBox.Parent = root
	Theme.corner(lineBox, 8)
	local line = Theme.label(lineBox, Text.get(card.lineKey), "body", "textPrimary")
	line.Name = "Line"
	line.Font = Theme.font
	line.TextXAlignment = Enum.TextXAlignment.Center
	line.Position = UDim2.new(0, 8, 0, 0)
	line.Size = UDim2.new(1, -16, 1, 0)

	if opts.zIndex then
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = opts.zIndex
			end
		end
	end
	return { root = root, height = L.height }
end

return BossIntroDiagram
