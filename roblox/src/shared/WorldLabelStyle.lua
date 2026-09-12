-- 월드 스페이스 텍스트 공통 가독성 설정(16-7, 17-1 후속). 몬스터 이름표(BillboardGui -
-- 항상 카메라를 향해야 하는 대상)와 포탈 표지판(SurfaceGui - 판자 표면에 고정, 카메라를
-- 따라 돌지 않음)은 서로 다른 GUI 타입이라 필요한 설정도 다르다. 한 모듈이 둘 다 처리하면
-- 한쪽을 고칠 때 다른 쪽이 같이 바뀌므로 이름표용/표지판용 함수를 분리한다(지시 - "표지판용과
-- 이름표용을 분리해라").

local WorldLabelStyle = {}

-- 외곽선 있는 고정 크기 텍스트. TextScaled 대신 고정 TextSize를 쓴다(양쪽 다 거리에 따라
-- 자동 축소되지 않으므로 호출부가 용도에 맞는 크기를 직접 골라야 한다).
local function styleTextCommon(label, textSize)
	label.TextScaled = false
	label.TextSize = textSize
	label.Font = Enum.Font.GothamBold
	label.TextStrokeTransparency = 0
	label.TextStrokeColor3 = Color3.new(0, 0, 0)
end

-- 몬스터 이름표(BillboardGui) -------------------------------------------------
-- 움직이는 대상이라 항상 카메라 정면을 보는 게 맞다.

-- LightInfluence=0이 없으면 어두운 구역에서 글씨가 같이 어두워진다.
function WorldLabelStyle.setupNameplateBillboard(billboard, maxDistance)
	billboard.LightInfluence = 0
	if maxDistance then
		billboard.MaxDistance = maxDistance
	end
end

function WorldLabelStyle.styleNameplateText(label, textSize)
	styleTextCommon(label, textSize)
end

-- 포탈 표지판(SurfaceGui) -----------------------------------------------------
-- 고정된 판자 Part 표면에 그린다. 판자 색 자체가 배경이라 반투명 배경 Frame은 필요 없다.

-- LightInfluence=0이 없으면 그늘에서 판자가 어두워진다.
function WorldLabelStyle.setupSignSurface(surfaceGui, maxDistance)
	surfaceGui.LightInfluence = 0
	if maxDistance then
		surfaceGui.MaxDistance = maxDistance
	end
end

function WorldLabelStyle.styleSignText(label, textSize)
	styleTextCommon(label, textSize)
end

return WorldLabelStyle
