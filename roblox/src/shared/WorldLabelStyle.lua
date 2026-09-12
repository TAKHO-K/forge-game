-- 월드 스페이스 BillboardGui 텍스트 공통 가독성 설정(16-7). 포탈 표지판·몬스터 이름표·
-- 드랍 아이템 이름표가 전부 이 모듈을 통해 스타일을 맞춘다 - 흰 글씨가 3D 배경에 묻히는
-- 문제를 한 곳에서 고치기 위함(지시 - "모든 BillboardGui TextLabel에 공통 적용").

local WorldLabelStyle = {}

-- BillboardGui 자체에 붙는 설정. LightInfluence=0이 없으면 어두운 구역에서 글씨가 같이
-- 어두워진다.
function WorldLabelStyle.setupBillboard(billboard, maxDistance)
	billboard.LightInfluence = 0
	if maxDistance then
		billboard.MaxDistance = maxDistance
	end
end

-- TextLabel 하나에 외곽선 + 고정 크기를 적용한다. TextScaled 대신 고정 TextSize를 쓰고
-- Size는 호출부에서 Offset 단위로 잡는다(BillboardGui가 거리에 따라 자동 축소되므로
-- Offset이 맞는 단위 - 지시 그대로).
function WorldLabelStyle.styleText(label, textSize)
	label.TextScaled = false
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
end

-- 반투명 어두운 배경 Frame + UICorner를 billboard 맨 밑에 깐다. 외곽선과 배경 둘 다 써야
-- 밝은 배경 위에서도 읽힌다(지시 - "하나만으로는 부족하다"). 텍스트보다 먼저 만들어야
-- 자식 순서상 뒤(아래)에 깔린다.
function WorldLabelStyle.addBackground(billboard)
	local frame = Instance.new("Frame")
	frame.Name = "ReadabilityBackground"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.new(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.BorderSizePixel = 0
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	return frame
end

return WorldLabelStyle
