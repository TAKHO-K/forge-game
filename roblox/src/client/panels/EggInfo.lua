-- M1-3 알 가방 · 알 정보창(오른쪽 칩 스택의 [알] 버튼이 연다). 본문 = 스크롤(폰에서도 글씨 실효 12 이상).
--   ① 알 목록(최근 것부터): 알 색 견본(구역 = 관문 색) · 구역 알 이름 · 등급 · 개체 후보 2(반반)
--   ② 부화 결과 확률(사전 고지 - EggData.hatch · 알 등급별 표) ③ 비밀 둥지 발견 수. 부화 자체는 펫 단계.
-- 값 = NestState(서버 NestSync) · 문구 = TextData(egg.*).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EggData = require(ReplicatedStorage.Shared.data.EggData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)
local NestState = require(script.Parent.Parent.NestState)

local EggInfoPanel = {}
EggInfoPanel.id = "eggInfo"

local PANEL_SIZE = Vector2.new(520, 400)
local PAD = 12
local ROW_H = 46

local built
local order = 0

local function clearBody()
	for _, c in ipairs(built.scroll:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	order = 0
end

local function line(text, sizeName, colorName, name)
	order += 1
	local label = Theme.label(built.scroll, text, sizeName, colorName)
	label.Name = name or ("Line" .. order)
	label.LayoutOrder = order
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, Theme.textSize(sizeName) + 8)
	return label
end

local function swatch(parent, color, grade)
	local egg = Instance.new("Frame")
	egg.Name = "EggSwatch"
	egg.Size = UDim2.new(0, 22, 0, 30)
	egg.Position = UDim2.new(0, 6, 0.5, -15)
	egg.BackgroundColor3 = color
	egg.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = egg
	local look = EggData.look[grade] or EggData.look.normal
	local dark = Color3.new(color.R * EggData.look.patternDarken, color.G * EggData.look.patternDarken, color.B * EggData.look.patternDarken)
	for k = 1, look.pattern do
		local band = Instance.new("Frame")
		band.Name = "Band"
		band.BorderSizePixel = 0
		band.BackgroundColor3 = grade == "rare" and Color3.new(1, 1, 1) or dark
		band.Size = UDim2.new(1, 0, 0, 3)
		band.Position = UDim2.new(0, 0, (k + 0.5) / (look.pattern + 2), 0)
		band.Parent = egg
	end
	if look.glow then
		local stroke = Instance.new("UIStroke")
		stroke.Color = color
		stroke.Thickness = 2.5
		stroke.Transparency = 0.1
		stroke.Parent = egg
	end
	return egg
end

local function eggRow(egg, i)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = "EggRow" .. i
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, 0, 0, ROW_H)
	frame.BackgroundColor3 = Theme.color("slot")
	frame.BackgroundTransparency = 0.4
	frame.Parent = built.scroll
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame
	swatch(frame, NestState.zoneColor and NestState.zoneColor(egg.zone) or Color3.new(1, 1, 1), egg.grade)
	local zoneName = EggData.zones[egg.zone] and EggData.zones[egg.zone].name or tostring(egg.zone)
	local name = Theme.label(frame, Text.get("egg.row", { egg = zoneName, grade = EggData.gradeNames[egg.grade] or egg.grade }), "body", "textPrimary")
	name.Name = "EggName"
	name.Position = UDim2.new(0, 38, 0, 3)
	name.Size = UDim2.new(1, -44, 0, 20)
	local cand = Theme.label(frame, Text.get("egg.candidates", { a = EggData.species[egg.species[1]] or "?", b = EggData.species[egg.species[2]] or "?" }), "caption", "textSecondary")
	cand.Name = "EggCandidates"
	cand.Position = UDim2.new(0, 38, 0, 24)
	cand.Size = UDim2.new(1, -44, 0, 18)
end

-- 부화 결과 확률 표: 열 = 알 등급(보통 · 좋은 · 희귀) · 줄 = 결과 등급(일반 · 고급 · 희귀 · 영웅)
local function hatchTable()
	line(Text.get("egg.hatchHeader"), "body", "textPrimary", "HatchHeader")
	order += 1
	local grid = Instance.new("Frame")
	grid.Name = "HatchTable"
	grid.LayoutOrder = order
	grid.BackgroundTransparency = 1
	local rows = #EggData.hatchGrades + 1
	local cellH = Theme.textSize("caption") + 10
	grid.Size = UDim2.new(1, 0, 0, rows * cellH)
	grid.Parent = built.scroll
	local cols = #EggData.gradeOrder + 1
	for c = 1, cols do
		for r = 1, rows do
			local text
			if r == 1 and c == 1 then
				text = ""
			elseif r == 1 then
				text = Text.get("egg.hatchCol", { grade = EggData.gradeNames[EggData.gradeOrder[c - 1]] })
			elseif c == 1 then
				text = EggData.hatchGradeNames[EggData.hatchGrades[r - 1]]
			else
				local v = EggData.hatch[EggData.gradeOrder[c - 1]][EggData.hatchGrades[r - 1]]
				text = (v % 1 == 0) and ("%d%%"):format(v) or ("%.1f%%"):format(v)
			end
			local cell = Theme.label(grid, text, "caption", (r == 1 or c == 1) and "textSecondary" or "textPrimary")
			cell.Name = ("Cell_%d_%d"):format(r, c)
			cell.Position = UDim2.new((c - 1) / cols, 0, 0, (r - 1) * cellH)
			cell.Size = UDim2.new(1 / cols, -4, 0, cellH)
			cell.TextXAlignment = c == 1 and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center
		end
	end
end

local function render()
	if not built then
		return
	end
	built.panel.titleLabel.Text = Text.get("egg.title", { count = #NestState.eggs, cap = NestState.cap })
	clearBody()
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = built.scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, PAD), UDim.new(0, PAD + 4), UDim.new(0, PAD), UDim.new(0, PAD)
	pad.Parent = built.scroll
	if #NestState.eggs == 0 then
		line(Text.get("egg.empty"), "body", "textSecondary", "Empty")
	else
		for i = #NestState.eggs, 1, -1 do
			eggRow(NestState.eggs[i], i)
		end
	end
	hatchTable()
	line(Text.get("egg.dex", { count = NestState.dex }), "caption", "textSecondary", "Dex")
end

local function build()
	local panel = Panel.create({
		id = EggInfoPanel.id,
		kind = "window",
		title = Text.get("egg.title", { count = 0, cap = NestState.cap }),
		size = PANEL_SIZE,
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel.content
	built = { panel = panel, scroll = scroll }
	NestState.changed:Connect(render)
end

function EggInfoPanel.toggle()
	if not built then
		build()
	end
	render()
	UIManager.switchTo(EggInfoPanel.id)
end

function EggInfoPanel.debugRefs()
	return built
end

return EggInfoPanel
