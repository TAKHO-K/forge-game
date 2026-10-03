-- 가격 · 상태 버튼(QUEUE-ALL9C 1-6R · 사용자 10-03): 로벅스 · 토큰 · 골드 가격과 "보유 중 ✓" · "착용" · "착용 중"을 전부 이 컴포넌트 하나로 그린다
--   (상점 카드 · 상세 · 시즌 패스 · 스타터 · 구매 확인 창 · 강화 창).
--   버튼 안 = [앞 글(선택)] [아이콘] [숫자]를 묶음 Frame 하나(AutomaticSize X · 가로 UIListLayout 가운데 · 간격 4)로 만들어 버튼 정중앙(AnchorPoint 0.5 · 0.5)에 둔다.
--   아이콘 = 글자 높이와 같은 정사각 · 숫자 = 고정 TextSize(넘치면 한 단계 축소 → 그래도 넘치면 줄임표). 바탕 · 눌림 · 비활성 색은 kit/Button 그대로(글자색을 따라간다).
-- PriceButton.build(props) -> Button refs + setPrice(spec). props = Button.build props + spec 필드(currency · amount · label · text).
-- PriceButton.attach(buttonRefs) -> setPrice(spec) : 이미 만든 Button(확인 창 주 버튼)에 묶음을 붙인다.
-- spec = { currency = "robux" | "token" | "gold" | nil, amount = number | nil, label = 앞 글 | nil, text = 글만(아이콘 없음 - 상태 버튼) | nil }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.Parent.ArtImage)
local Button = require(script.Parent.Button)
local Theme = require(script.Parent.Theme)

local PriceButton = {}

PriceButton.ROBUX_ICON = "rbxasset://textures/ui/common/robux.png"
PriceButton.GAP = 4
PriceButton.SIDE_PAD = 8 -- 묶음이 버튼 가장자리에 닿지 않게 남기는 양쪽 여백
local ICON_PATH = { token = "icons/reward/sparkleShard", gold = "icons/reward/gold" }
local ICON_FALLBACK = { token = "◆", gold = "●" }

local function textWidth(text, size)
	return TextService:GetTextSize(text, size, Theme.font, Vector2.new(10000, 1000)).X
end

-- 상태 버튼 글(앞 지시 그대로 공통 키)
PriceButton.stateText = {
	owned = "shop.ownedCheck",
	equip = "shop.card.equip",
	equipped = "shop.card.equipped",
}

function PriceButton.attach(refs)
	local root = refs.root
	local bundle = Instance.new("Frame")
	bundle.Name = "PriceBundle"
	bundle.BackgroundTransparency = 1
	bundle.AnchorPoint = Vector2.new(0.5, 0.5)
	bundle.Position = UDim2.new(0.5, 0, 0.5, 0)
	bundle.AutomaticSize = Enum.AutomaticSize.X
	bundle.Size = UDim2.new(0, 0, 0, 0)
	bundle.Parent = root
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, PriceButton.GAP)
	layout.Parent = bundle

	local function label(name, order)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.LayoutOrder = order
		l.BackgroundTransparency = 1
		l.Font = Theme.font
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextYAlignment = Enum.TextYAlignment.Center
		l.Parent = bundle
		return l
	end
	local lead = label("Lead", 1)
	local amount = label("Amount", 3)
	local icon -- 종류가 바뀔 때만 다시 만든다(이미지 · 대체 글자)
	local iconKind = nil

	local function syncColor()
		lead.TextColor3 = root.TextColor3
		amount.TextColor3 = root.TextColor3
		if icon and icon:IsA("TextLabel") then
			icon.TextColor3 = root.TextColor3
		end
	end
	root:GetPropertyChangedSignal("TextColor3"):Connect(syncColor)
	-- 진행 중("…")은 kit/Button이 root.Text로 그린다 - 그동안 묶음을 숨긴다
	root:GetPropertyChangedSignal("Text"):Connect(function()
		bundle.Visible = root.Text == ""
	end)

	local function setPrice(spec)
		spec = spec or {}
		local size = Theme.textSize("body")
		local available = root.AbsoluteSize.X > 0 and root.AbsoluteSize.X or root.Size.X.Offset
		available -= 2 * PriceButton.SIDE_PAD
		local leadText = spec.text or spec.label or ""
		local amountText = ""
		if spec.text == nil and spec.amount ~= nil then -- 로벅스 · 토큰 = 정확한 값(12,345) · 골드 = 게임 큰 수 표기(1.2만)
			amountText = spec.currency == "gold" and NumberFormat.currency(spec.amount, Text.languageFor()) or NumberFormat.commas(spec.amount)
		end
		local kind = spec.text == nil and spec.currency or nil
		local function widthAt(s)
			local w, parts = 0, 0
			for _, t in ipairs({ leadText, amountText }) do
				if t ~= "" then
					w += textWidth(t, s)
					parts += 1
				end
			end
			if kind then
				w += s
				parts += 1
			end
			return w + math.max(0, parts - 1) * PriceButton.GAP
		end
		if widthAt(size) > available then -- 한 단계 축소(body → caption)
			size = Theme.textSize("caption")
		end
		local truncate = widthAt(size) > available
		if kind ~= iconKind then
			if icon then
				icon:Destroy()
				icon = nil
			end
			if kind == "robux" then
				icon = Instance.new("ImageLabel")
				icon.Image = PriceButton.ROBUX_ICON
				icon.ScaleType = Enum.ScaleType.Fit
				icon.BackgroundTransparency = 1
				icon.Parent = bundle
			elseif kind then
				icon = ArtImage.label(bundle, ICON_PATH[kind], nil, ICON_FALLBACK[kind])
			end
			if icon then
				icon.Name = "PriceIcon"
				icon.LayoutOrder = 2
			end
			iconKind = kind
		end
		if icon then
			icon.Size = UDim2.fromOffset(size, size) -- 글자 높이와 같은 정사각
			if icon:IsA("TextLabel") then
				icon.TextSize = size
			end
		end
		for _, l in ipairs({ lead, amount }) do
			l.TextSize = size
			l.Visible = (l == lead and leadText ~= "") or (l == amount and amountText ~= "")
			l.Text = l == lead and leadText or amountText
			if truncate and l == lead then -- 그래도 넘침 = 앞 글을 남은 폭에 맞춰 줄임표
				l.AutomaticSize = Enum.AutomaticSize.None
				l.TextTruncate = Enum.TextTruncate.AtEnd
				local rest = (amountText ~= "" and textWidth(amountText, size) + PriceButton.GAP or 0) + (kind and size + PriceButton.GAP or 0)
				l.Size = UDim2.fromOffset(math.max(0, available - rest), size + 2)
			else
				l.AutomaticSize = Enum.AutomaticSize.X
				l.TextTruncate = Enum.TextTruncate.None
				l.Size = UDim2.fromOffset(0, size + 2)
			end
		end
		bundle.Size = UDim2.fromOffset(0, size + 2)
		syncColor()
	end

	refs.setText("") -- 글은 묶음이 그린다(Button.setText를 다시 부르면 그 글이 겹친다 - 이 버튼은 setPrice만)
	refs.setPrice = setPrice
	refs.bundle = bundle
	return setPrice
end

-- spec 필드는 props에 함께 넣는다(currency · amount · label · text)
function PriceButton.build(props)
	local refs = Button.build({
		parent = props.parent, name = props.name, kind = props.kind or "primary", text = "", width = props.width, height = props.height,
		position = props.position, anchorPoint = props.anchorPoint, layoutOrder = props.layoutOrder, onActivated = props.onActivated,
	})
	PriceButton.attach(refs)
	refs.setPrice({ currency = props.currency, amount = props.amount, label = props.label, text = props.text })
	if props.enabled ~= nil then
		refs.setEnabled(props.enabled)
	end
	return refs
end

-- 자동 검사 한 건: 묶음 가운데 − 버튼 가운데(px · x · y 중 큰 쪽)
function PriceButton.centerError(refs)
	local b, r = refs.bundle, refs.root
	local bc = b.AbsolutePosition + b.AbsoluteSize / 2
	local rc = r.AbsolutePosition + r.AbsoluteSize / 2
	return math.max(math.abs(bc.X - rc.X), math.abs(bc.Y - rc.Y))
end

return PriceButton
