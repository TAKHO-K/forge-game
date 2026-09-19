-- 비용 2줄(28-1 S07, PRD 20.72 [1-8]): 골드(보유) · 재료(보유). 부족한 쪽은 danger색. 0 ~ 18강은 재료 줄이 "-"(골드만 든다).
-- 큰 수 표기는 shared/NumberFormat. 인스턴스 만들기(build)와 값 채우기(update)만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local CostView = {}

local NAME_WIDTH = 96

local function rowHeight()
	return Theme.textSize("body") + 4
end

function CostView.height()
	return rowHeight() * 2
end

-- parent 안 (x, y)에 폭 width로 두 줄을 짓는다. 반환 refs = { goldName, goldValue, materialName, materialValue }.
function CostView.build(parent, x, y, width)
	local height = rowHeight()
	local refs = {}
	local function row(prefix, rowY, defaultName)
		local name = Theme.label(parent, defaultName, "body", "textSecondary")
		name.Name = prefix .. "Name"
		name.Position = UDim2.new(0, x, 0, rowY)
		name.Size = UDim2.new(0, NAME_WIDTH, 0, height)
		local value = Theme.label(parent, "", "body", "textPrimary")
		value.Name = prefix .. "Value"
		value.Position = UDim2.new(0, x + NAME_WIDTH, 0, rowY)
		value.Size = UDim2.new(0, width - NAME_WIDTH, 0, height)
		return name, value
	end
	refs.goldName, refs.goldValue = row("Gold", y, "골드")
	refs.materialName, refs.materialValue = row("Material", y + height, "재료")
	return refs
end

-- state = Controller.getState()의 결과.
function CostView.update(refs, state)
	local colors = Theme.colors
	if state.maxed then
		refs.goldValue.Text = "-"
		refs.goldValue.TextColor3 = colors.textTertiary
	else
		refs.goldValue.Text = ("%s (보유 %s)"):format(NumberFormat.format(state.cost), NumberFormat.format(state.gold))
		refs.goldValue.TextColor3 = state.gold < state.cost and colors.danger or colors.textPrimary
	end

	local material = state.material
	if material then
		refs.materialName.Text = material.name
		refs.materialValue.Text = ("%s (보유 %s)"):format(NumberFormat.format(material.need), NumberFormat.format(material.have))
		refs.materialValue.TextColor3 = material.have < material.need and colors.danger or colors.textPrimary
	else
		refs.materialName.Text = "재료"
		refs.materialValue.Text = "-"
		refs.materialValue.TextColor3 = colors.textTertiary
	end
end

return CostView
