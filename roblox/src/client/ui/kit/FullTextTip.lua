-- 잘린 글 전체 보기(S12b G): 글씨를 키우면 고정 폭 라벨에서 글이 넘칠 수 있다. root 아래 모든 TextLabel · TextButton에 줄임표(TextTruncate = AtEnd, 줄바꿈 라벨은 제외)를 걸고,
-- 글이 실제로 잘려 있을 때(TextBounds.X > 폭) 가리키거나(PC hover) 누르면(모바일 탭 - 다시 누르면 닫힘) 전체 글을 작은 말풍선으로 보여 준다. 나중에 생기는 자손(행 다시 짓기)에도 자동으로 붙는다.
-- 툴팁 전용 hover에만 기대지 않는다 - 탭이 같은 일을 한다. 말풍선은 screenGui 직계 Frame 하나(재사용).
-- FullTextTip.attach(root, screenGui) -> { hide(), truncatedIn(container) }.

local Theme = require(script.Parent.Theme)

local FullTextTip = {}

local MAX_WIDTH = 320

function FullTextTip.attach(root, screenGui)
	local tip = Instance.new("Frame")
	tip.Name = "FullTextTip"
	tip.AutomaticSize = Enum.AutomaticSize.None
	tip.BackgroundColor3 = Theme.colors.panel
	tip.BackgroundTransparency = 0.05
	tip.ZIndex = 50
	tip.Visible = false
	tip.Parent = screenGui
	Theme.corner(tip, 6)
	Theme.stroke(tip)

	local tipLabel = Theme.label(tip, "", "caption", "textPrimary")
	tipLabel.ZIndex = 51
	tipLabel.TextWrapped = true
	tipLabel.TextTruncate = Enum.TextTruncate.None
	tipLabel.RichText = false
	tipLabel.Position = UDim2.new(0, 8, 0, 6)

	local owner
	local refs = {}

	local function hide()
		owner = nil
		tip.Visible = false
	end
	refs.hide = hide

	local function isTruncated(inst)
		return inst.Text ~= "" and inst.TextBounds.X > inst.AbsoluteSize.X + 0.5
	end

	local function show(inst)
		if inst.Text == "" then
			return
		end
		owner = inst
		local plain = inst.Text:gsub("<[^>]+>", "")
		tipLabel.Text = plain
		local bounds = game:GetService("TextService"):GetTextSize(plain, tipLabel.TextSize, tipLabel.Font, Vector2.new(MAX_WIDTH - 16, 1000))
		local width, height = math.min(MAX_WIDTH, bounds.X + 16), bounds.Y + 12
		tip.Size = UDim2.new(0, width, 0, height)
		tipLabel.Size = UDim2.new(0, width - 16, 0, bounds.Y)
		local position = inst.AbsolutePosition -- ScreenGui 안 좌표(인셋 무관)
		local screen = screenGui.AbsoluteSize
		local x = math.clamp(position.X, 8, math.max(8, screen.X - width - 8))
		local y = position.Y - height - 4
		if y < 8 then
			y = position.Y + inst.AbsoluteSize.Y + 4
		end
		tip.Position = UDim2.new(0, x, 0, math.clamp(y, 8, math.max(8, screen.Y - height - 8)))
		tip.Visible = true
	end

	local attached = setmetatable({}, { __mode = "k" })
	local function attachOne(inst)
		if attached[inst] or not (inst:IsA("TextLabel") or inst:IsA("TextButton")) or inst == tipLabel then
			return
		end
		attached[inst] = true
		if not inst.TextWrapped and inst.TextTruncate == Enum.TextTruncate.None then
			inst.TextTruncate = Enum.TextTruncate.AtEnd
		end
		inst.MouseEnter:Connect(function()
			if isTruncated(inst) then
				show(inst)
			end
		end)
		inst.MouseLeave:Connect(function()
			if owner == inst then
				hide()
			end
		end)
		inst.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch and isTruncated(inst) then
				if owner == inst then
					hide()
				else
					show(inst)
				end
			end
		end)
	end

	for _, descendant in ipairs(root:GetDescendants()) do
		attachOne(descendant)
	end
	root.DescendantAdded:Connect(attachOne)

	-- 검사용: container 아래에서 지금 실제로 잘려 있는(보이는) 글 라벨 목록.
	function refs.truncatedIn(container)
		local list = {}
		for _, inst in ipairs(container:GetDescendants()) do
			if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst ~= tipLabel then
				local shown = inst.Visible
				local node = inst.Parent
				while shown and node and node ~= container.Parent do
					if node:IsA("GuiObject") and not node.Visible then
						shown = false
					end
					node = node.Parent
				end
				if shown and isTruncated(inst) then
					table.insert(list, inst)
				end
			end
		end
		return list
	end

	return refs
end

return FullTextTip
