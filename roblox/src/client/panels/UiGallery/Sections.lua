-- 부품 전시장의 구역들(30-0 S06). 각 함수는 (parent, width, ctx)를 받아 그 안에 부품을 늘어놓고 **높이**를 돌려준다(고정 좌표 - AutomaticSize 없음).
-- ctx = { note(text), ids = { window, stationA, stationB } }. 개발 전용(/gg ui gallery) - 프로덕션에는 열 길이가 없다.

local Badge = require(script.Parent.Parent.Parent.ui.kit.Badge)
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)
local Gauge = require(script.Parent.Parent.Parent.ui.kit.Gauge)
local ListRow = require(script.Parent.Parent.Parent.ui.kit.ListRow)
local Tabs = require(script.Parent.Parent.Parent.ui.kit.Tabs)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local Toggle = require(script.Parent.Parent.Parent.ui.kit.Toggle)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local Sections = {}

local function heading(parent, text)
	local label = Theme.label(parent, text, "header", "textPrimary")
	label.Font = Theme.font
	label.Size = UDim2.new(1, 0, 0, Theme.textSize("header") + 6)
	return Theme.textSize("header") + 6 + 6
end

local function caption(parent, text, y)
	local label = Theme.label(parent, text, "caption", "textSecondary")
	label.Position = UDim2.new(0, 0, 0, y)
	label.Size = UDim2.new(1, 0, 0, Theme.textSize("caption") + 4)
	return label
end

function Sections.buttons(parent, width, ctx)
	local y = heading(parent, "버튼 - 종류 3 × 상태 4")
	local kinds = { { "primary", "주" }, { "secondary", "보조" }, { "danger", "위험" } }
	local states = { { "default", "기본" }, { "pressed", "눌림" }, { "disabled", "비활성" }, { "busy", "진행 중" } }
	local rowHeight = Theme.buttonHeight + Theme.textSize("caption") + 6 + 10
	for _, kindEntry in ipairs(kinds) do
		local kind = kindEntry[1]
		local kindLabel = Theme.label(parent, kindEntry[2], "body", "textSecondary")
		kindLabel.Position = UDim2.new(0, 0, 0, y)
		kindLabel.Size = UDim2.new(0, 56, 0, Theme.buttonHeight)
		for index, stateEntry in ipairs(states) do
			local refs = Button.build({
				parent = parent,
				kind = kind,
				text = stateEntry[2],
				width = 110,
				position = UDim2.new(0, 60 + (index - 1) * 120, 0, y),
				onActivated = function()
					ctx.note(("버튼 %s · %s 눌림"):format(kindEntry[2], stateEntry[2]))
				end,
			})
			if stateEntry[1] == "pressed" then
				refs.forceVisual("pressed")
			elseif stateEntry[1] == "disabled" then
				refs.setEnabled(false, "이유: 골드가 모자란다")
			elseif stateEntry[1] == "busy" then
				refs.setBusy(true)
			end
		end
		y += rowHeight
	end
	return y
end

function Sections.toggles(parent, width, ctx)
	local y = heading(parent, "토글 - 켜짐 ✓ · 꺼짐 · 비활성")
	local specs = {
		{ text = "방지권 사용", value = true },
		{ text = "자동 줍기", value = false },
		{ text = "구간 진입", value = false, disabled = true },
	}
	for index, spec in ipairs(specs) do
		local refs = Toggle.build({
			parent = parent,
			text = spec.text,
			value = spec.value,
			width = 200,
			position = UDim2.new(0, (index - 1) * 210, 0, y),
			onChanged = function(value)
				ctx.note(("토글 '%s' → %s"):format(spec.text, value and "켜짐" or "꺼짐"))
			end,
		})
		if spec.disabled then
			refs.setEnabled(false, "이유: 조건 미달")
		end
	end
	return y + (Theme.isMobile and Theme.touchMin or 32) + Theme.textSize("caption") + 10
end

function Sections.tabs(parent, width, ctx)
	local y = heading(parent, "탭 - 최대 5개")
	local selectedLabel = caption(parent, "선택: 정보", y + Theme.tabHeight + 4)
	Tabs.build({
		parent = parent,
		tabs = { { id = "info", text = "정보" }, { id = "gem", text = "보석" }, { id = "party", text = "파티" } },
		selected = "info",
		width = 320,
		position = UDim2.new(0, 0, 0, y),
		onSelect = function(id)
			selectedLabel.Text = "선택: " .. id
			ctx.note("탭 → " .. id)
		end,
	})
	return y + Theme.tabHeight + Theme.textSize("caption") + 12
end

function Sections.rows(parent, width, ctx)
	local y = heading(parent, "목록 행 - 높이 28 · 40 · 56 (글이 길면 말줄임)")
	local firstRowY = y
	local rowWidth = math.min(width, 460)
	local firstRow = ListRow.build({
		parent = parent, height = 28, iconText = "검", title = "단검 - 아주 긴 이름이 말줄임으로 잘리는지 보기 위한 행", valueText = "+12",
		width = rowWidth, position = UDim2.new(0, 0, 0, y),
	})
	y += 28 + 6
	local buttonRowHeight = Theme.isMobile and 56 or 40 -- 버튼이 들어가는 행 높이(모바일은 버튼 44 + 여백)
	ListRow.build({
		parent = parent, height = buttonRowHeight, iconText = "갑", title = "천 갑옷", subtitle = "방어 +32 · 레벨 15", button = { text = "장착", onActivated = function() ctx.note("행 버튼: 장착") end },
		width = rowWidth, position = UDim2.new(0, 0, 0, y),
	})
	y += buttonRowHeight + 6
	ListRow.build({
		parent = parent, height = 56, iconText = "보", title = "전설 보석", subtitle = "공격력 +7.2% · 선택된 행은 밝은 테두리", valueText = "Lv 40", selected = true,
		width = rowWidth, position = UDim2.new(0, 0, 0, y), onActivated = function() ctx.note("행 눌림") end,
	})
	y += 56 + 6
	-- 배지(메뉴바 · 탭에만 쓴다): 첫 행 오른쪽 위에 점 하나, 행 오른쪽 옆에 숫자 배지 셋
	Badge.build({ parent = firstRow.root, kind = "dot", anchorPoint = Vector2.new(1, 0), position = UDim2.new(1, -2, 0, 2), count = 1 })
	local badgeX = rowWidth + 12
	local badgeCaption = Theme.label(parent, "배지: 점 8px · 숫자 16px", "caption", "textSecondary")
	badgeCaption.Position = UDim2.new(0, badgeX, 0, firstRowY)
	badgeCaption.Size = UDim2.new(0, math.max(width - badgeX, 120), 0, Theme.textSize("caption") + 4)
	for index, count in ipairs({ 3, 12, 120 }) do
		Badge.build({ parent = parent, kind = "count", count = count, position = UDim2.new(0, badgeX + (index - 1) * 36, 0, firstRowY + Theme.textSize("caption") + 12) })
	end
	return y
end

function Sections.gauges(parent, width, ctx)
	local y = heading(parent, "게이지 - 높이 10 · 16 · 22 (숫자는 16부터)")
	local gauges = {}
	local specs = { { 10, "hpDark", "hp", 0.75 }, { 16, "hpDark", "hp", 0.5 }, { 22, "slot", "xp", 0.3 } }
	for _, spec in ipairs(specs) do
		table.insert(gauges, Gauge.build({
			parent = parent, height = spec[1], trackColorName = spec[2], fillColorName = spec[3], width = 300, position = UDim2.new(0, 0, 0, y),
			value = spec[4], text = ("%d / 100"):format(spec[4] * 100),
		}))
		y += spec[1] + 10
	end
	local step = 0
	Button.build({
		parent = parent, kind = "secondary", text = "값 바꾸기", width = 110, position = UDim2.new(0, 320, 0, y - 10 - 22 - 10 - 16),
		onActivated = function()
			step = (step + 1) % 4
			for _, gauge in ipairs(gauges) do
				gauge.setValue(step / 3, ("%d / 100"):format(step / 3 * 100))
			end
			ctx.note("게이지 값 → " .. tostring(math.floor(step / 3 * 100)) .. "%")
		end,
	})
	return y
end

function Sections.toasts(parent, width, ctx)
	local y = heading(parent, "토스트 - TC · TR · BC 줄")
	local status = caption(parent, "누르면 화면에 뜬다(TC 위 중앙 · TR 오른쪽 위 · BC 스킬 슬롯 위)", y + Theme.buttonHeight + 8)
	local function report(lane)
		local state = Toast.debugState(lane)
		status.Text = ("%s 줄: 보이는 행 %d / %d · 대기 %d"):format(lane, state.rows, state.maxRows, state.queued)
	end
	local specs = {
		{ "TC 토스트", function()
			Toast.push("TC", { text = "시스템 알림 - 저장 성공", colorName = "success" })
			report("TC")
		end },
		{ "TR 토스트 ×5", function()
			for index = 1, 5 do
				Toast.push("TR", {
					richParts = { { text = "획득 ", colorName = "textSecondary" }, { text = ("전설 장갑 %d"):format(index), colorName = "gold" } },
					priority = index, seconds = 8,
				})
			end
			report("TR")
		end },
		{ "TR 묶기 ×3", function()
			for _ = 1, 3 do
				Toast.push("TR", { text = "보석 획득", colorName = "xp", groupKey = "gallery-gem", seconds = 8 })
			end
			report("TR")
		end },
		{ "BC 토스트", function()
			Toast.push("BC", { text = "강화석 +1", colorName = "xp", groupKey = "gallery-stone" })
			report("BC")
		end },
	}
	for index, spec in ipairs(specs) do
		Button.build({
			parent = parent, name = "Btn_toast_" .. index, kind = "secondary", text = spec[1], width = 130, position = UDim2.new(0, (index - 1) * 140, 0, y), onActivated = spec[2],
		})
	end
	return y + Theme.buttonHeight + Theme.textSize("caption") + 16
end

function Sections.overlays(parent, width, ctx)
	local y = heading(parent, "확인창(overlay) · 도움말(제목줄 ?) · station")
	local function ask(danger)
		Confirm.ask({
			title = danger and "되돌릴 수 없는 동작" or "확인창 시험",
			body = danger and "이 동작은 되돌릴 수 없다. 정말 진행할까?" or "주 버튼이나 보조 버튼을 누르면 결과가 위 줄에 남는다. 부모(전시장)를 닫으면 이 창도 같이 닫힌다.",
			primaryText = "진행", secondaryText = "취소", danger = danger, parentId = ctx.ids.window,
		}, function(accepted)
			ctx.note("확인창 결과: " .. (accepted and "진행(true)" or "취소(false)"))
		end)
	end
	Button.build({ parent = parent, name = "Btn_confirm", kind = "primary", text = "확인창", width = 120, position = UDim2.new(0, 0, 0, y), onActivated = function() ask(false) end })
	Button.build({ parent = parent, name = "Btn_confirmDanger", kind = "danger", text = "위험 확인창", width = 130, position = UDim2.new(0, 130, 0, y), onActivated = function() ask(true) end })
	for index, id in ipairs({ ctx.ids.stationA, ctx.ids.stationB }) do
		Button.build({
			parent = parent, name = "Btn_station" .. index, kind = "secondary", text = index == 1 and "station A" or "station B", width = 110, position = UDim2.new(0, 270 + (index - 1) * 120, 0, y),
			onActivated = function()
				local opened = UIManager.open(id)
				ctx.note(("%s: %s"):format(id, opened and "열림" or "거절 - window가 열려 있으면 station은 열리지 않는다"))
			end,
		})
	end
	caption(parent, "station 규칙은 /gg ui check가 순서대로 검사한다(window 없이 열기 · station 사이 교체 · window가 열리면 닫힘).", y + Theme.buttonHeight + 8)
	return y + Theme.buttonHeight + Theme.textSize("caption") + 16
end

Sections.order = { "buttons", "toggles", "tabs", "rows", "gauges", "toasts", "overlays" }

return Sections
