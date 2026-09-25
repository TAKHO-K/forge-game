-- 등급 색의 단일 출처(G1-1). 색 값 자체는 shared/data/ItemVisualData.gradeVisuals[등급].color 한 곳에만 있다 - 화면 · 채팅 · 아이콘은 전부 이 함수로 읽는다.
-- 옛 코드는 태초(rainbow)일 때 흰색 · 기본 글자색으로 바꾸는 분기가 6곳에 있어 "태초가 흰색(일반)으로 보인다"(D0 (h)). 무지개 테두리를 그리는 자리는 그 위에 따로 덧씌운다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

local GradeColor = {}

-- 등급의 표시 색. 모르는 등급이면 fallback(없으면 일반 색).
function GradeColor.of(gradeId, fallback)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	return visual and visual.color or fallback or ItemVisualData.gradeVisuals.normal.color
end

-- 리치 텍스트용 "#rrggbb"(채팅 DisplaySystemMessage · RichText 라벨).
function GradeColor.hex(gradeId)
	local c = GradeColor.of(gradeId)
	return ("#%02x%02x%02x"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

return GradeColor
