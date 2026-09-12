-- 장비 부위 아이콘(16-3). `Claude outputs/inventory-mockup.html`은 clip-path 다각형으로
-- 실루엣을 그렸지만 로블록스 UI엔 clip-path가 없다 - 대신 회전·크기가 다른 Frame 여러
-- 개를 겹쳐 같은 실루엣을 흉내 낸다(HudIcons.lua와 같은 방식, 다만 이쪽은 부위 아이콘
-- 전용이라 별도 모듈로 뺐다 - 스킬 아이콘과 섞이면 두 목적이 헷갈린다).
--
-- 무기 아이콘은 목업 첫 버전이 대각선(45도)으로 그렸다가 체크 표시처럼 보여 수직으로
-- 고쳤다는 지시를 그대로 따른다 - 여기서도 처음부터 수직으로 그린다(같은 실수를
-- 반복하지 않는다).
--
-- 색은 인자로 받는다(그 아이템의 등급색) - 이 모듈은 등급이 뭔지 모른다(단일 출처 원칙,
-- InventoryUI.client.lua가 ItemVisualData.gradeVisuals에서 색을 뽑아 넘겨준다).
-- 완벽한 그림을 만들려 하지 않는다 - 네 부위가 서로 구별되기만 하면 된다(지시 그대로).

local ItemIcons = {}

local function rect(parent, w, h, x, y, color, cornerRadius)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.new(0, w, 0, h)
	frame.Position = UDim2.new(0, x, 0, y)
	frame.BackgroundColor3 = color
	frame.Parent = parent
	if cornerRadius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, cornerRadius)
		corner.Parent = frame
	end
	return frame
end

local function newCanvas(parent, size)
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(0, size, 0, size)
	canvas.Parent = parent
	return canvas
end

-- 무기 - 수직 검. 칼날(세로 긴 사각형) → 코등이(가로 짧은 사각형) → 손잡이(작은 세로
-- 사각형) 순서로 겹친다. 코등이를 칼날 중간(50%)에 폭 넓게 놓으면 십자가/플러스
-- 기호로 읽힌다(16-3 Studio 실측 스크린샷으로 실제 확인) - 칼날을 훨씬 길게(72%),
-- 코등이는 아래쪽(68%)에 짧고 좁게(37%) 둬서 "자루 쪽에 짧은 가로대가 있다"는
-- 비대칭이 뚜렷하게 보이도록 고쳤다.
function ItemIcons.weapon(parent, size, color)
	local canvas = newCanvas(parent, size)
	local center = size / 2
	rect(canvas, size * 0.13, size * 0.72, center, 0, color, size * 0.03) -- 칼날
	rect(canvas, size * 0.38, size * 0.08, center, size * 0.66, color, size * 0.02) -- 코등이
	rect(canvas, size * 0.16, size * 0.24, center, size * 0.72, color, size * 0.03) -- 손잡이
	return canvas
end

-- 갑옷 - 몸통(사각형) + 좌우 어깨(사각형 2개).
function ItemIcons.armor(parent, size, color)
	local canvas = newCanvas(parent, size)
	local center = size / 2
	rect(canvas, size * 0.55, size * 0.75, center, size * 0.25, color, size * 0.08) -- 몸통
	rect(canvas, size * 0.24, size * 0.24, size * 0.19, size * 0.16, color, size * 0.05) -- 왼쪽 어깨
	rect(canvas, size * 0.24, size * 0.24, size * 0.81, size * 0.16, color, size * 0.05) -- 오른쪽 어깨
	return canvas
end

-- 장갑 - 손바닥(사각형) + 위쪽 손가락 4개(작은 사각형).
function ItemIcons.gloves(parent, size, color)
	local canvas = newCanvas(parent, size)
	local center = size / 2
	rect(canvas, size * 0.62, size * 0.5, center, size * 0.5, color, size * 0.08) -- 손바닥
	local fingerWidth = size * 0.12
	local fingerSpacing = size * 0.17
	local startX = center - fingerSpacing * 1.5
	for i = 0, 3 do
		rect(canvas, fingerWidth, size * 0.32, startX + i * fingerSpacing, size * 0.16, color, size * 0.03)
	end
	return canvas
end

-- 신발 - 세로 사각형(발목) + 아래 가로 사각형(발, L자).
function ItemIcons.boots(parent, size, color)
	local canvas = newCanvas(parent, size)
	rect(canvas, size * 0.34, size * 0.62, size * 0.34, 0, color, size * 0.05) -- 발목
	rect(canvas, size * 0.7, size * 0.28, size * 0.52, size * 0.64, color, size * 0.05) -- 발
	return canvas
end

ItemIcons.byPart = {
	weapon = ItemIcons.weapon,
	armor = ItemIcons.armor,
	gloves = ItemIcons.gloves,
	shoes = ItemIcons.boots,
}

-- 자물쇠 - 위 반원(테두리만 있는 알약 모양, 아래 절반은 body에 가려 arc처럼 보인다) +
-- 아래 몸체(채워진 사각형). 이모지(🔒)는 쓰지 않는다 - TextLabel 컬러 이모지가 로블록스
-- 기본 폰트에서 두부(빈 사각형)로 나오는 문제를 GoldHud(10-1)에서 이미 겪었다.
function ItemIcons.lock(parent, size, color)
	local canvas = newCanvas(parent, size)
	local center = size / 2

	local shackle = Instance.new("Frame")
	shackle.BackgroundTransparency = 1
	shackle.AnchorPoint = Vector2.new(0.5, 0)
	shackle.Size = UDim2.new(0, size * 0.5, 0, size * 0.45)
	shackle.Position = UDim2.new(0, center, 0, 0)
	shackle.ZIndex = 1
	shackle.Parent = canvas
	local shackleCorner = Instance.new("UICorner")
	shackleCorner.CornerRadius = UDim.new(1, 0)
	shackleCorner.Parent = shackle
	local shackleStroke = Instance.new("UIStroke")
	shackleStroke.Thickness = math.max(1, size * 0.1)
	shackleStroke.Color = color
	shackleStroke.Parent = shackle

	local body = rect(canvas, size * 0.75, size * 0.55, center, size * 0.42, color, size * 0.1)
	body.ZIndex = 2 -- shackle 아래 절반을 가려 위쪽만 고리처럼 보이게 한다.

	return canvas
end

return ItemIcons
