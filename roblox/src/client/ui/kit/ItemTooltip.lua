-- 아이템 툴팁 부품(S12b B · C). ItemDescribe(shared)가 만든 글 조각({ title, gradeId, meta, options })을 작은 패널 하나에 그린다.
-- 알림 속 아이템(드랍 순간 스냅샷)과 장비 보기 창의 슬롯 상세가 같은 부품을 쓴다. 고정 폭 · 고정 줄 높이(AutomaticSize 없음) - 높이는 줄 수로 계산해 set이 돌려준다.
-- ItemTooltip.build({ parent, width, name }) -> { root, set(desc) -> height, hide() }. root는 처음에 숨어 있다(Visible = false) - 자리는 호출부가 정한다(placeNear).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local Theme = require(script.Parent.Theme)

local ItemTooltip = {}

ItemTooltip.defaultWidth = 260
local PAD = 10
local LINE_GAP = 2

function ItemTooltip.build(props)
	local width = props.width or ItemTooltip.defaultWidth

	-- 겹쳐 그려질 때 위에 오게 zIndex를 줄 수 있다. 자식 라벨은 root보다 1 위여야 한다(ZIndexBehavior가 Global이면 자식이 root 뒤로 숨어 글이 안 보인다 - Play 3 스크린샷에서 발견).
	local z = props.zIndex or 1
	local root = Instance.new("Frame")
	root.ZIndex = z
	root.Name = props.name or "ItemTooltip"
	root.Size = UDim2.new(0, width, 0, 60)
	root.BackgroundColor3 = Theme.colors.panel
	root.BackgroundTransparency = 0.05
	root.Active = true -- 툴팁 위를 눌러도 뒤로 새지 않는다
	root.Visible = false
	root.Parent = props.parent
	Theme.corner(root, Theme.corner.button)
	Theme.stroke(root)

	local titleHeight = Theme.textSize("header") + 4
	local metaHeight = Theme.textSize("caption") + 4
	local optionHeight = Theme.textSize("body") + 4

	local title = Theme.label(root, "", "header", "textPrimary")
	title.Name = "Title"
	title.ZIndex = z + 1
	title.Position = UDim2.new(0, PAD, 0, PAD)
	title.Size = UDim2.new(1, -PAD * 2, 0, titleHeight)

	local meta = Theme.label(root, "", "caption", "textSecondary")
	meta.Name = "Meta"
	meta.ZIndex = z + 1
	meta.Position = UDim2.new(0, PAD, 0, PAD + titleHeight + LINE_GAP)
	meta.Size = UDim2.new(1, -PAD * 2, 0, metaHeight)

	local optionLabels = {}
	for index = 1, 2 do -- 옵션 줄은 최대 2(치명 = 치확 · 치피)
		local label = Theme.label(root, "", "body", "textPrimary")
		label.Name = "Option" .. index
		label.ZIndex = z + 1
		label.Position = UDim2.new(0, PAD, 0, PAD + titleHeight + metaHeight + LINE_GAP * 2 + (index - 1) * optionHeight)
		label.Size = UDim2.new(1, -PAD * 2, 0, optionHeight)
		label.Visible = false
		optionLabels[index] = label
	end

	local refs = { root = root, title = title, meta = meta, optionLabels = optionLabels }

	-- desc = ItemDescribe 결과. 높이를 돌려준다(줄 수만큼).
	function refs.set(desc)
		local visual = ItemVisualData.gradeVisuals[desc.gradeId]
		title.Text = desc.title
		title.TextColor3 = (visual and visual.color) or Theme.colors.textPrimary
		meta.Text = desc.meta or ""
		for index, label in ipairs(optionLabels) do
			local line = desc.options and desc.options[index]
			label.Visible = line ~= nil
			if line then
				label.Text = line.text
				label.TextColor3 = line.dim and Theme.colors.textTertiary or Theme.colors.textPrimary
			end
		end
		local optionCount = math.min(desc.options and #desc.options or 0, #optionLabels)
		local height = PAD * 2 + titleHeight + metaHeight + LINE_GAP + optionCount * optionHeight + (optionCount > 0 and LINE_GAP or 0)
		root.Size = UDim2.new(0, width, 0, height)
		return height
	end

	function refs.hide()
		root.Visible = false
	end

	return refs
end

-- root를 anchorRect({ min, max } - GuiObject.AbsolutePosition 좌표) 옆에 놓는다. 화면 오른쪽 가장자리의 행(피드 줄)은 왼쪽 → 아래 → 위 순서, 그 밖의 행(가운데 띠 · 창 안 줄)은 아래 → 왼쪽 → 위 순서로 자리를 찾고 화면 안으로 민다
-- (왼쪽 위 로블록스 채팅창 쪽으로 가운데 띠의 툴팁이 밀려가지 않게 - Play 4 스크린샷).
-- root는 ScreenGui 직계여야 하고 screenSize는 그 ScreenGui의 AbsoluteSize다. AbsolutePosition은 ScreenGui 안 좌표다(실측: Position (0, 52)인 칩 스택의 Abs Y = 52 - GuiInset 58과 무관) - 인셋을 더하거나 빼지 않는다.
function ItemTooltip.placeNear(root, anchorRect, screenSize, gap)
	gap = gap or 6
	local width, height = root.Size.X.Offset, root.Size.Y.Offset -- 고정 크기(set이 정한 값)
	local leftFits = anchorRect.min.X - gap - width >= 8
	local belowFits = anchorRect.max.Y + gap + height <= screenSize.Y - 8
	local onRightEdge = (anchorRect.min.X + anchorRect.max.X) / 2 > screenSize.X * 0.6
	local x, y
	if onRightEdge and leftFits then
		x, y = anchorRect.min.X - gap - width, anchorRect.min.Y
	elseif belowFits then
		x, y = anchorRect.min.X, anchorRect.max.Y + gap
	elseif leftFits then
		x, y = anchorRect.min.X - gap - width, anchorRect.min.Y
	else
		x, y = anchorRect.min.X, anchorRect.min.Y - gap - height
	end
	x = math.clamp(x, 8, math.max(8, screenSize.X - width - 8))
	y = math.clamp(y, 8, math.max(8, screenSize.Y - height - 8))
	root.AnchorPoint = Vector2.new(0, 0)
	root.Position = UDim2.new(0, x, 0, y)
end

return ItemTooltip
