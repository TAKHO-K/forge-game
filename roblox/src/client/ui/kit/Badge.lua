-- 배지(30-0 S06, PRD 20.81 [D-3]). 점 8px(수량 없음) / 숫자 16px. 메뉴바 · 탭에만 쓴다. danger 색.
-- Badge.build(props) -> refs. props = { parent, kind("dot"|"count"), count, anchorPoint, position }.
-- refs = { root, setCount(n) } - dot은 n > 0이면 보이고, count는 n > 0이면 숫자(99 초과는 "99+")로 보인다. 숫자 글씨는 12(caption, 모바일 14) - 12 미만 금지.

local Theme = require(script.Parent.Theme)

local Badge = {}

Badge.dotSize = 8
Badge.countSize = 16

function Badge.build(props)
	local kind = props.kind or "dot"
	assert(kind == "dot" or kind == "count", "Badge.build: kind는 dot 또는 count - " .. tostring(kind))
	local size = kind == "dot" and Badge.dotSize or Badge.countSize

	local root = Instance.new("Frame")
	root.Name = props.name or "Badge"
	root.AnchorPoint = props.anchorPoint or Vector2.new(0, 0)
	root.Position = props.position or UDim2.new(0, 0, 0, 0)
	root.Size = UDim2.new(0, size, 0, size)
	root.BackgroundColor3 = Theme.colors.danger
	root.BorderSizePixel = 0
	root.Visible = false
	root.Parent = props.parent
	Theme.corner(root, size / 2)

	local numberLabel
	if kind == "count" then
		numberLabel = Theme.label(root, "", "caption", "textPrimary")
		numberLabel.Size = UDim2.new(1, 0, 1, 0)
		numberLabel.TextXAlignment = Enum.TextXAlignment.Center
		numberLabel.TextTruncate = Enum.TextTruncate.None
		numberLabel.Font = Theme.font
	end

	local refs = { root = root }
	function refs.setCount(count)
		count = count or 0
		root.Visible = count > 0
		if numberLabel then
			numberLabel.Text = count > 99 and "99+" or tostring(count)
			-- 두 자리 이상이면 알약 모양으로 늘린다(높이는 16 그대로).
			root.Size = UDim2.new(0, count > 9 and (count > 99 and 30 or 24) or size, 0, size)
		end
	end
	refs.setCount(props.count or 0)
	return refs
end

return Badge
