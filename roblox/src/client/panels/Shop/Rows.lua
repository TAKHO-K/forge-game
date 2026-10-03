-- 상점 창 본문 줄 부품(QUEUE-B1 B2 UI). 탭 파일 4개가 같은 줄 모양을 쓴다: 절 제목 · 글 줄 · 행(왼쪽 제목 · 부제 + 오른쪽 버튼 여러 개) · 칩 줄(장착 고르기) · 게이지.
-- 크기는 전부 Layout(L)에서 나온다(고정 크기 - AutomaticSize 중첩 없음 · 스크롤 안 자리는 offset). 버튼 높이 = L.buttonH(폰 44 = 터치 타깃 하한).
-- Rows.new(scroll, L) -> ctx. ctx.clear() 뒤에 다시 채운다(상태가 바뀔 때마다 탭 전체를 다시 그린다 - 행 수 최대 약 45).
local Button = require(script.Parent.Parent.Parent.ui.kit.Button)
local Gauge = require(script.Parent.Parent.Parent.ui.kit.Gauge)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Layout = require(script.Parent.Layout)
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)


local Rows = {}
-- QUEUE-ALL9C 1-6: 가격 아이콘(로벅스 = 로블록스 기본 그림 · 토큰 = 꾸미기 토큰 그림) - 한 버튼에 한 가격 · 아이콘으로 종류를 분명히
Rows.ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"

function Rows.new(scroll, L)
	local ctx = { scroll = scroll, L = L, order = 0, buttons = {} }

	local function nextOrder()
		ctx.order += 1
		return ctx.order
	end

	function ctx.clear()
		for _, child in ipairs(scroll:GetChildren()) do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		ctx.order = 0
		ctx.buttons = {}
	end

	-- 절 제목(caption · textSecondary)
	function ctx.section(text, name)
		local label = Theme.label(scroll, text, "caption", "textSecondary")
		label.Name = name or ("Section" .. (ctx.order + 1))
		label.LayoutOrder = nextOrder()
		label.Size = UDim2.new(0, L.rowW, 0, Theme.textSize("caption") + 8)
		label.TextYAlignment = Enum.TextYAlignment.Bottom
		return label
	end

	-- 글 줄(줄 수 고정 - 넘치면 말줄임). colorName = UIColors 이름.
	function ctx.line(text, colorName, lineCount, name)
		local size = Theme.textSize("body")
		local label = Theme.label(scroll, text, "body", colorName or "textPrimary")
		label.Name = name or ("Line" .. (ctx.order + 1))
		label.LayoutOrder = nextOrder()
		label.TextWrapped = true
		label.Size = UDim2.new(0, L.rowW, 0, (size + 4) * (lineCount or 1) + 4)
		return label
	end

	-- 버튼 하나(행 · 칩 공통). spec = { name, text, kind, enabled, width, onActivated, swatch(Color3 - 왼쪽 작은 칸) }
	local function makeButton(parent, spec, position, anchorPoint)
		local button = Button.build({
			parent = parent,
			name = spec.name,
			kind = spec.kind or "secondary",
			text = spec.text,
			width = spec.width or Button.minWidth,
			height = L.buttonH,
			anchorPoint = anchorPoint,
			position = position,
			onActivated = spec.onActivated,
		})
		button.setEnabled(spec.enabled ~= false)
		if spec.swatch then
			local swatch = Instance.new("Frame")
			swatch.Name = "Swatch"
			swatch.AnchorPoint = Vector2.new(0, 0.5)
			swatch.Position = UDim2.new(0, 8, 0.5, 0)
			swatch.Size = UDim2.new(0, 12, 0, 12)
			swatch.BackgroundColor3 = spec.swatch
			swatch.BorderSizePixel = 0
			swatch.Parent = button.root
			Theme.corner(swatch, 3)
		end
		if spec.icon then
			local icon
			if spec.icon == "robux" then
				icon = Instance.new("ImageLabel")
				icon.Image = Rows.ROBUX_ICON
				icon.ScaleType = Enum.ScaleType.Fit
			else
				icon = ArtImage.label(button.root, "icons/reward/sparkleShard", UDim2.fromOffset(18, 18), "◆")
			end
			icon.Name = "PriceIcon"
			icon.BackgroundTransparency = 1
			icon.AnchorPoint = Vector2.new(0, 0.5)
			icon.Position = UDim2.new(0, 10, 0.5, 0)
			icon.Size = UDim2.fromOffset(18, 18)
			icon.Parent = button.root
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 22)
			pad.Parent = button.root
		end
		if spec.name then
			ctx.buttons[spec.name] = button
		end
		return button
	end

	ctx.button = makeButton -- 탭이 자기 모양의 행(시즌 칸)을 지을 때 쓴다
	ctx.nextOrder = nextOrder

	-- 행: 왼쪽 제목(body) · 부제(caption) + 오른쪽 버튼들(오른쪽부터 buttons[#buttons] … buttons[1] 순서가 아니라 왼쪽→오른쪽 그대로). 반환: 행 Frame
	function ctx.row(props)
		local row = Instance.new("Frame")
		row.Name = props.name or ("Row" .. (ctx.order + 1))
		row.LayoutOrder = nextOrder()
		row.Size = UDim2.new(0, L.rowW, 0, L.rowH)
		row.BackgroundColor3 = Theme.colors.slot
		row.BackgroundTransparency = Theme.colors.slotTransparency
		row.Parent = scroll
		Theme.corner(row, Theme.corner.chip)
		Theme.stroke(row, props.highlight and "rimHi" or nil, props.highlight and Theme.colors.rimHiTransparency or nil)

		local buttons = props.buttons or {}
		local x = -8
		for index = #buttons, 1, -1 do
			local spec = buttons[index]
			local width = math.max(Button.minWidth, spec.width or Button.minWidth)
			makeButton(row, spec, UDim2.new(1, x, 0.5, 0), Vector2.new(1, 0.5))
			x -= width + Layout.gap
		end
		local textRight = -x + 4
		local titleSize, captionSize = Theme.textSize("body"), Theme.textSize("caption")
		local hasSubtitle = props.subtitle ~= nil and props.subtitle ~= ""
		local block = titleSize + 4 + (hasSubtitle and (captionSize + 4) or 0)
		local title = Theme.label(row, props.title or "", "body", props.titleColor or "textPrimary")
		title.Name = "Title"
		title.Position = UDim2.new(0, 10, 0.5, -block / 2)
		title.Size = UDim2.new(1, -(10 + textRight), 0, titleSize + 4)
		if hasSubtitle then
			local subtitle = Theme.label(row, props.subtitle, "caption", props.subtitleColor or "textSecondary")
			subtitle.Name = "Subtitle"
			subtitle.Position = UDim2.new(0, 10, 0.5, -block / 2 + titleSize + 4)
			subtitle.Size = UDim2.new(1, -(10 + textRight), 0, captionSize + 4)
		end
		return row
	end

	-- 칩 줄(장착 고르기): chips = { spec, ... } - 넘치면 다음 줄로. selected = true인 칩은 primary 모양.
	function ctx.chips(name, chips, chipWidth)
		chipWidth = math.max(Button.minWidth, chipWidth or Button.minWidth)
		local perLine = Layout.chipsPerLine(L, chipWidth)
		local lines = math.max(1, math.ceil(#chips / perLine))
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.LayoutOrder = nextOrder()
		frame.BackgroundTransparency = 1
		frame.Size = UDim2.new(0, L.rowW, 0, lines * L.buttonH + (lines - 1) * Layout.gap)
		frame.Parent = scroll
		for index, spec in ipairs(chips) do
			local col = (index - 1) % perLine
			local line = math.floor((index - 1) / perLine)
			spec.width = chipWidth
			spec.kind = spec.selected and "primary" or "secondary"
			makeButton(frame, spec, UDim2.new(0, col * (chipWidth + Layout.gap), 0, line * (L.buttonH + Layout.gap)), Vector2.new(0, 0))
		end
		return frame
	end

	-- 게이지(높이 22 - 숫자 표시). 반환: Gauge refs
	function ctx.gauge(name, ratio, text, fillColorName)
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.LayoutOrder = nextOrder()
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(0, L.rowW, 0, 26)
		holder.Parent = scroll
		return Gauge.build({ parent = holder, height = 22, width = L.rowW, position = UDim2.new(0, 0, 0, 2), trackColorName = "hpDark",
			fillColorName = fillColorName or "xp", value = ratio, text = text })
	end

	return ctx
end

return Rows
