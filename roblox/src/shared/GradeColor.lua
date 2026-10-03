-- 등급 색의 단일 출처(G1-1). 색 값 자체는 shared/data/ItemVisualData.gradeVisuals[등급].color 한 곳에만 있다 - 화면 · 채팅 · 아이콘은 전부 이 함수로 읽는다.
-- 옛 코드는 태초(rainbow)일 때 흰색 · 기본 글자색으로 바꾸는 분기가 6곳에 있어 "태초가 흰색(일반)으로 보인다"(D0 (h)). 무지개 테두리를 그리는 자리는 그 위에 따로 덧씌운다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

local GradeColor = {}

-- QUEUE-ALL9C 2-2: 쓰임별 세 가지 - of = 메인(3D 본체 · 칸 바탕 섞기) · text = 어두운 패널 위 글자 · 아이콘(대비 4.5:1) · border = 칸 테두리 · 빛기둥 · 점 · 드랍 빛(초월 = 금).
local function field(gradeId, key, fallback)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	return visual and (visual[key] or visual.color) or fallback or ItemVisualData.gradeVisuals.normal[key] or ItemVisualData.gradeVisuals.normal.color
end

-- 등급의 메인 색. 모르는 등급이면 fallback(없으면 일반 색).
function GradeColor.of(gradeId, fallback)
	return field(gradeId, "color", fallback)
end

-- 글자 · 아이콘 색(어두운 패널 위 대비 4.5:1 이상 - 하네스 grade_color_test)
function GradeColor.text(gradeId, fallback)
	return field(gradeId, "text", fallback)
end

-- 테두리 · 빛기둥 · 점 색(초월 = 금)
function GradeColor.border(gradeId, fallback)
	return field(gradeId, "border", fallback)
end

function GradeColor.light(gradeId)
	return field(gradeId, "light")
end

function GradeColor.dark(gradeId)
	return field(gradeId, "dark")
end

-- 글자 라벨에 등급 글자색 + (태초) 자홍 외곽선
function GradeColor.applyText(label, gradeId, fallback)
	label.TextColor3 = GradeColor.text(gradeId, fallback)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if visual and visual.textStroke then
		label.TextStrokeColor3 = visual.textStroke
		label.TextStrokeTransparency = 0.2
	elseif label:GetAttribute("GradeStroke") then
		label.TextStrokeTransparency = 1
	end
	label:SetAttribute("GradeStroke", visual ~= nil and visual.textStroke ~= nil or nil)
end

-- 펫 등급(common · uncommon · rare · epic) → 장비 등급 색 id
function GradeColor.petGrade(hatchGrade)
	return ItemVisualData.petGradeColorOf[hatchGrade] or "normal"
end

-- 리치 텍스트용 "#rrggbb"(채팅 DisplaySystemMessage · RichText 라벨 - 글자색).
function GradeColor.hex(gradeId)
	local c = GradeColor.text(gradeId)
	return ("#%02x%02x%02x"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

return GradeColor
