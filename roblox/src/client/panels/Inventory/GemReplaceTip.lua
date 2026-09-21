-- 보석 자동 장착 미리보기 툴팁(S20d - PC 전용 호버). 보석칸의 보석 위에 마우스를 올리면 자동 장착이 밀어낼 보석을 한 줄로 보여 준다("교체될 보석: ..."). 교체가 없으면(빈 홈으로 들어가면) 안 나온다.
-- 폰은 이 툴팁 대신 상세 시트의 [장착] 버튼 위 한 줄(DetailSheet dhint)이 같은 글을 보인다 - hover에 기대는 조작은 없다(호버 툴팁은 PC의 덤).
-- GemReplaceTip.create(screenGui) -> { show(text, anchorFrame), hide() }. 말풍선은 screenGui 직계 Frame 하나(재사용). 글씨 실효 12 이상(caption) · ZIndex는 Global 층에서 창 위(60).

local TextService = game:GetService("TextService")

local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ItemTooltip = require(script.Parent.Parent.Parent.ui.kit.ItemTooltip)

local GemReplaceTip = {}

local PAD_X, PAD_Y = 10, 6
local MAX_WIDTH = 360

function GemReplaceTip.create(screenGui)
	local root = Instance.new("Frame")
	root.Name = "GemReplaceTip"
	root.BackgroundColor3 = Theme.colors.panel
	root.BackgroundTransparency = 0.05
	root.ZIndex = 60
	root.Visible = false
	root.Parent = screenGui
	Theme.corner(root, 6)
	Theme.stroke(root)

	local label = Theme.label(root, "", "caption", "textPrimary")
	label.ZIndex = 61 -- 자식은 root보다 1 위여야 한다(ZIndexBehavior Global에서 root 뒤로 숨는다)
	label.Position = UDim2.new(0, PAD_X, 0, PAD_Y)

	local self = {}

	function self.hide()
		root.Visible = false
	end

	-- text가 nil이면(교체 없음) 숨긴다. anchorFrame = 마우스가 올라간 보석 셀.
	function self.show(text, anchorFrame)
		if not text or not anchorFrame or not anchorFrame.Parent then
			root.Visible = false
			return
		end
		label.Text = text
		local bounds = TextService:GetTextSize(text, label.TextSize, label.Font, Vector2.new(MAX_WIDTH, 1000))
		local width, height = math.min(MAX_WIDTH + PAD_X * 2, bounds.X + PAD_X * 2 + 2), bounds.Y + PAD_Y * 2
		root.Size = UDim2.new(0, width, 0, height)
		label.Size = UDim2.new(0, width - PAD_X * 2, 0, bounds.Y)
		local pos, size = anchorFrame.AbsolutePosition, anchorFrame.AbsoluteSize
		ItemTooltip.placeNear(root, { min = pos, max = pos + size }, screenGui.AbsoluteSize, 6)
		root.Visible = true
	end

	return self
end

return GemReplaceTip
