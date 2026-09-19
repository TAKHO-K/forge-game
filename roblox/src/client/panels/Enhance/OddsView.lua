-- 확률표 5행 + 합계 + 장인의 기운 줄(28-1 S07, PRD 20.72 [1-8]). 인스턴스 만들기(build)와 값 채우기(update)만 한다 - 값은 Controller가 준다.
-- 표는 **항상 5행 고정**: 성공 · 실패 유지 · 1강 하락 · 2강 하락 · 초기화. 확률 0인 행은 "-"로 흐리게(textTertiary). 열 = 결과 · 확률 · 되는 단계(Enhance.getResultLevel).
-- 합계는 표시값이 아니라 원값의 합으로 찍는다(반올림한 칸을 더하면 100%에서 어긋난다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enhance = require(ReplicatedStorage.Shared.Enhance)
local Gauge = require(script.Parent.Parent.Parent.ui.kit.Gauge)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local OddsView = {}

-- 결과 5종의 순서 · 이름 · 색(색은 UIColors 이름). 유지는 색 지정이 없어 본문색이다.
local ROWS = {
	{ key = "success", text = "성공", colorName = "success" },
	{ key = "maintain", text = "실패 · 유지", colorName = "textPrimary" },
	{ key = "down1", text = "실패 · 1강 하락", colorName = "ember" },
	{ key = "down2", text = "실패 · 2강 하락", colorName = "ember" },
	{ key = "reset", text = "실패 · 초기화", colorName = "danger" },
}

local PAD = 8
local RESULT_COL_WIDTH = 132
local PROB_COL_RIGHT = 218 -- 확률 열의 오른쪽 끝 x(박스 안)
local PROB_COL_WIDTH = 64
local LEVEL_COL_WIDTH = 74 -- 되는 단계 열은 박스 오른쪽 끝에 붙는다
local GAUGE_LABEL_WIDTH = 82

-- 확률(0 ~ 1) → "4.5%" · "12%"(소수 첫째 자리까지, 끝의 ".0"은 뗀다). Controller의 확인창도 같은 표기를 쓴다.
function OddsView.formatPercent(ratio)
	local text = ("%.1f"):format(ratio * 100):gsub("%.0$", "")
	return text .. "%"
end

local function rowHeight()
	return Theme.textSize("caption") + 4
end

-- 표 박스 + 기운 줄의 세로 크기(위에서부터 쌓는 호출부가 y를 계산하는 데 쓴다).
function OddsView.tableHeight()
	return rowHeight() * (#ROWS + 2) + 8
end

local GAUGE_HEIGHT = 16
function OddsView.gaugeRowHeight()
	return GAUGE_HEIGHT
end

local function cell(parent, name, xAlign, x, width, y, height, colorName)
	local label = Theme.label(parent, "", "caption", colorName or "textPrimary")
	label.Name = name
	label.TextXAlignment = xAlign
	label.Position = UDim2.new(0, x, 0, y)
	label.Size = UDim2.new(0, width, 0, height)
	return label
end

-- parent 안 (x, y)에 폭 width로 표 박스를 짓는다. 반환 refs = { box, rows = { key -> { label, prob, level } }, sumProb }.
function OddsView.buildTable(parent, x, y, width)
	local height = rowHeight()
	local box = Instance.new("Frame")
	box.Name = "OddsTable"
	box.BackgroundColor3 = Theme.colors.slot
	box.BackgroundTransparency = Theme.colors.slotTransparency
	box.BorderSizePixel = 0
	box.Position = UDim2.new(0, x, 0, y)
	box.Size = UDim2.new(0, width, 0, OddsView.tableHeight())
	box.Parent = parent
	Theme.corner(box, Theme.corner.chip)
	Theme.stroke(box)

	local levelX = width - PAD - LEVEL_COL_WIDTH
	local refs = { box = box, rows = {} }

	local header = { text = "결과", prob = "확률", level = "되는 단계" }
	local headerY = 4
	cell(box, "HeaderResult", Enum.TextXAlignment.Left, PAD, RESULT_COL_WIDTH, headerY, height, "textSecondary").Text = header.text
	cell(box, "HeaderProb", Enum.TextXAlignment.Right, PROB_COL_RIGHT - PROB_COL_WIDTH, PROB_COL_WIDTH, headerY, height, "textSecondary").Text = header.prob
	cell(box, "HeaderLevel", Enum.TextXAlignment.Right, levelX, LEVEL_COL_WIDTH, headerY, height, "textSecondary").Text = header.level

	for index, row in ipairs(ROWS) do
		local rowY = 4 + index * height
		refs.rows[row.key] = {
			label = cell(box, "Result_" .. row.key, Enum.TextXAlignment.Left, PAD, RESULT_COL_WIDTH, rowY, height),
			prob = cell(box, "Prob_" .. row.key, Enum.TextXAlignment.Right, PROB_COL_RIGHT - PROB_COL_WIDTH, PROB_COL_WIDTH, rowY, height),
			level = cell(box, "Level_" .. row.key, Enum.TextXAlignment.Right, levelX, LEVEL_COL_WIDTH, rowY, height),
		}
		refs.rows[row.key].label.Text = row.text
	end

	local sumY = 4 + (#ROWS + 1) * height
	cell(box, "SumLabel", Enum.TextXAlignment.Left, PAD, RESULT_COL_WIDTH, sumY, height, "textSecondary").Text = "합계"
	refs.sumProb = cell(box, "SumProb", Enum.TextXAlignment.Right, PROB_COL_RIGHT - PROB_COL_WIDTH, PROB_COL_WIDTH, sumY, height, "textSecondary")
	return refs
end

-- 표를 채운다. outcomes = Enhance.getOutcomeTable(...)의 결과(상한이면 nil - 전부 "-").
function OddsView.updateTable(refs, level, outcomes)
	local sum = 0
	for _, row in ipairs(ROWS) do
		local cells = refs.rows[row.key]
		local ratio = outcomes and outcomes[row.key] or 0
		sum += ratio
		if ratio > 0 then
			local color = Theme.color(row.colorName)
			cells.label.TextColor3 = color
			cells.prob.TextColor3 = color
			cells.level.TextColor3 = color
			cells.prob.Text = OddsView.formatPercent(ratio)
			cells.level.Text = "+" .. Enhance.getResultLevel(level, row.key)
		else
			local dim = Theme.colors.textTertiary
			cells.label.TextColor3 = dim
			cells.prob.TextColor3 = dim
			cells.level.TextColor3 = dim
			cells.prob.Text = "-"
			cells.level.Text = "-"
		end
	end
	refs.sumProb.Text = outcomes and OddsView.formatPercent(sum) or "-"
end

-- 장인의 기운 줄: 왼쪽 이름 + Gauge(높이 16, 안에 "54% (실패 시 +6%)"). 반환 refs = { gauge }.
function OddsView.buildGaugeRow(parent, x, y, width)
	local label = cell(parent, "GaugeLabel", Enum.TextXAlignment.Left, x, GAUGE_LABEL_WIDTH, y, GAUGE_HEIGHT, "textSecondary")
	label.Text = "장인의 기운"
	local gauge = Gauge.build({
		parent = parent,
		name = "MasteryGauge",
		height = GAUGE_HEIGHT,
		width = width - GAUGE_LABEL_WIDTH,
		position = UDim2.new(0, x + GAUGE_LABEL_WIDTH, 0, y),
		trackColorName = "slot",
		fillColorName = "ember",
	})
	return { gauge = gauge }
end

-- state = Controller.getState()의 결과.
function OddsView.updateGaugeRow(refs, state)
	local ratio = state.gauge / state.gaugeMax
	local text
	if state.maxed then
		text = OddsView.formatPercent(ratio)
	elseif state.gaugeFull then
		text = "다음 시도 확정 성공"
	else
		text = ("%s (실패 시 +%s)"):format(OddsView.formatPercent(ratio), OddsView.formatPercent(state.gaugeGain / state.gaugeMax))
	end
	refs.gauge.setValue(ratio, text)
end

return OddsView
