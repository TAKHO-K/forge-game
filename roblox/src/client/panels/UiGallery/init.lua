-- 부품 전시장(30-0 S06) - kit 부품 전부를 한 window 안에 늘어놓는 개발 전용 패널. `/gg ui gallery`(DevTools → UiDevCommand → UiGalleryBoot)로만 열린다 -
-- 프로덕션에는 DevTools가 죽어 있어 열 길이가 없다. window 하나(uiGallery) + station 둘(uiGalleryStationA · B - station 규칙 시험용)을 등록한다.
-- 열 때마다 Theme.recompute()를 부르고 전부 다시 짓는다(모바일 판정 · Studio ForceTouchLayout이 바뀐 것을 따르려고).

local Confirm = require(script.Parent.Parent.ui.kit.Confirm)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.UIManager)
local RuleCheck = require(script.RuleCheck)
local Sections = require(script.Sections)

local UiGallery = {}

UiGallery.ids = { window = "uiGallery", stationA = "uiGalleryStationA", stationB = "uiGalleryStationB" }

local SECTION_GAP = 16
local PADDING = 12
local SCROLLBAR = 8

local built -- { window = Panel refs, stationA = refs, stationB = refs }

function UiGallery.refs()
	return built
end

local function destroyBuilt()
	if not built then
		return
	end
	for _, id in pairs(UiGallery.ids) do
		UIManager.unregister(id)
	end
	for _, key in ipairs({ "window", "stationA", "stationB" }) do
		built[key].screenGui:Destroy()
	end
	built = nil
	Confirm.reset()
end

local function buildStation(id, title)
	local refs = Panel.create({ id = id, kind = "station", title = title, size = Vector2.new(300, 130) })
	local note = Theme.label(refs.content, "station은 비모달이다 - 열린 채로 걸을 수 있다. window가 열리면 닫힌다.", "caption", "textSecondary")
	note.TextWrapped = true
	note.TextTruncate = Enum.TextTruncate.None
	note.TextYAlignment = Enum.TextYAlignment.Top
	note.Position = UDim2.new(0, 16, 0, 12)
	note.Size = UDim2.new(1, -32, 1, -24)
	return refs
end

local function build()
	Theme.recompute()
	local ids = UiGallery.ids
	local windowRefs = Panel.create({
		id = ids.window, kind = "window", title = "UI 전시장" .. (Theme.isMobile and " (모바일)" or " (PC)"), size = Vector2.new(720, 480),
		help = "부품 전시장이다(개발 전용). ?는 누르면 열리고 다시 누르면 닫힌다 - hover에 기대지 않는다. X · Backspace로 맨 위 패널을 닫는다.",
	})
	local content = windowRefs.content

	-- 마지막 동작을 남기는 줄(위에 고정) + 그 아래 스크롤 영역.
	local statusHeight = Theme.textSize("caption") + 10
	local status = Theme.label(content, "마지막 동작: -", "caption", "textSecondary")
	status.Name = "Status"
	status.Position = UDim2.new(0, PADDING, 0, 4)
	status.Size = UDim2.new(1, -PADDING * 2, 0, statusHeight - 4)
	local ctx = {
		ids = ids,
		note = function(text)
			status.Text = "마지막 동작: " .. text
		end,
	}

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.new(0, 0, 0, statusHeight)
	scroll.Size = UDim2.new(1, 0, 1, -statusHeight)
	scroll.ScrollBarThickness = SCROLLBAR
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.None
	scroll.Parent = content

	local viewportX = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X or 1280
	local windowWidth = Theme.isMobile and math.min(viewportX * 0.92, Panel.maxSize.X) or Panel.maxSize.X
	local width = windowWidth - PADDING * 2 - SCROLLBAR

	local y = PADDING
	for _, name in ipairs(Sections.order) do
		local section = Instance.new("Frame")
		section.Name = "Section_" .. name
		section.BackgroundTransparency = 1
		section.Position = UDim2.new(0, PADDING, 0, y)
		section.Parent = scroll
		local height = Sections[name](section, width, ctx)
		section.Size = UDim2.new(0, width, 0, height)
		y += height + SECTION_GAP
	end
	scroll.CanvasSize = UDim2.new(0, 0, 0, y)

	built = { window = windowRefs, stationA = buildStation(ids.stationA, "station A"), stationB = buildStation(ids.stationB, "station B") }
end

-- 전시장을 새로 지어 연다. 이미 열려 있으면 닫았다 다시 지어 연다.
function UiGallery.open()
	UIManager.closeAll()
	Toast.clear()
	destroyBuilt()
	build()
	UIManager.open(UiGallery.ids.window)
end

-- 규칙 검사(PRD 20.88 · 합격 기준 2): 패널 종류 규칙이 실제로 도는지 순서대로 부르고 `[S06][UI][규칙] … O/X`를 클라 콘솔에 찍는다.
function UiGallery.runRuleCheck()
	RuleCheck.run(UiGallery)
end

function UiGallery.close()
	UIManager.closeAll()
	destroyBuilt()
end

return UiGallery
