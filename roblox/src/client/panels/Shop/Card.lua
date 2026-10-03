-- 상점 카드(QUEUE-ALL9C 1-6R · 사용자 10-03): 모든 탭이 같은 카드 하나. 비율 3:4(격자 칸 크기 = Layout) · 위 60% = 미리보기 그림(정지 - 스크롤 중 회전 없음) ·
--   이름 1줄(넘치면 한 단계 축소 → 줄임표) · 칸 이름 작은 글씨(묶음 = 구성품 합계 취소선) · 맨 아래 가격 버튼(kit/PriceButton).
--   왼쪽 위 NEW(공개 뒤 14일) · 오른쪽 위 가격급 띠(기본 · 특별 · 대표 = UI 중립색 3종 · 등급 색 아님) · 보유 = 회색 반투명 덮개 + "보유 중 ✓" + 버튼 착용/착용 중.
--   카드 누름 = spec.onOpen(상세 패널) · 버튼 = spec.button.onActivated.
-- Card.build(parent, spec, L) -> Frame. spec = { name, title, slotText, strikeText, picture = function(holder) , isNew, band, owned, button = PriceButton spec + onActivated · enabled, onOpen }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Text = require(ReplicatedStorage.Shared.Text)
local PriceButton = require(script.Parent.Parent.Parent.ui.kit.PriceButton)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local Card = {}

Card.PICTURE = 0.6 -- 위 60%(폰 5:4 카드는 아래가 먼저 - 남는 자리)
Card.MIN_PICTURE = 40
local PAD = 6

local function fits(text, size, width)
	return TextService:GetTextSize(text, size, Theme.font, Vector2.new(10000, 1000)).X <= width
end

local function tag(parent, name, text, bg, fg, anchorX)
	local size = Theme.textSize("caption") - 2
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Font = Theme.font
	l.TextSize = size
	l.Text = text
	l.TextColor3 = fg
	l.BackgroundColor3 = bg
	l.BackgroundTransparency = 0.05
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromOffset(0, size + 6)
	l.AnchorPoint = Vector2.new(anchorX, 0)
	l.Position = UDim2.new(anchorX, anchorX == 0 and PAD or -PAD, 0, PAD)
	l.ZIndex = 4
	l.Parent = parent
	local p = Instance.new("UIPadding")
	p.PaddingLeft = UDim.new(0, 5)
	p.PaddingRight = UDim.new(0, 5)
	p.Parent = l
	Theme.corner(l, 4)
	return l
end

function Card.build(parent, spec, L)
	local w, h = L.cardW, L.cardH
	local card = Instance.new("TextButton") -- 카드 누름 = 상세(버튼 위 누름은 버튼이 먼저 받는다)
	card.Name = spec.name
	card.Text = ""
	card.AutoButtonColor = false
	card.BackgroundColor3 = Theme.colors.slot
	card.BackgroundTransparency = Theme.colors.slotTransparency
	card.Size = UDim2.fromOffset(w, h)
	card.LayoutOrder = spec.order or 0
	card.ClipsDescendants = true
	card.Parent = parent
	Theme.corner(card, Theme.corner.chip)
	Theme.stroke(card)
	if spec.onOpen then
		card.Activated:Connect(spec.onOpen)
	end

	-- 아래(이름 · 칸 · 버튼)를 아래부터 쌓고 그림 = 남는 자리(최대 60%) - 작은 카드(폰)에서도 겹치지 않게
	local inner = w - 2 * PAD
	local titleSize = Theme.textSize("body")
	local function neededFor(size)
		return 4 + (size + 4) + (Theme.textSize("caption") + 2) + 4 + L.buttonH + PAD
	end
	if h - neededFor(titleSize) < Card.MIN_PICTURE or not fits(spec.title or "", titleSize, inner) then
		titleSize = Theme.textSize("caption") -- 낮은 카드(폰 5:4) · 긴 이름 = 한 단계 축소(하한 caption) → 그래도 넘치면 줄임표
	end
	local picH = math.min(math.floor(h * Card.PICTURE), h - neededFor(titleSize))
	local picture = Instance.new("Frame")
	picture.Name = "Picture"
	picture.BackgroundColor3 = UIColors.shopCardPicture
	picture.BorderSizePixel = 0
	picture.Size = UDim2.new(1, 0, 0, picH)
	picture.Parent = card
	Theme.corner(picture, Theme.corner.chip)
	if spec.picture then
		spec.picture(picture)
	end

	-- 아래 40%: 이름 · 칸 이름 · 가격 버튼(맨 아래)
	local buttonH = L.buttonH
	local title = Theme.label(card, spec.title or "", "body", "textPrimary")
	title.Name = "Title"
	title.TextSize = titleSize
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Position = UDim2.fromOffset(PAD, picH + 4)
	title.Size = UDim2.fromOffset(inner, titleSize + 4)
	local slotSize = Theme.textSize("caption")
	local slot = Theme.label(card, spec.slotText or "", "caption", "textSecondary")
	slot.Name = "SlotText"
	slot.TextTruncate = Enum.TextTruncate.AtEnd
	slot.Position = UDim2.fromOffset(PAD, picH + 4 + titleSize + 4)
	slot.Size = UDim2.fromOffset(inner, slotSize + 2)
	if spec.strikeText then -- 묶음: 구성품 합계 취소선(오른쪽)
		slot.RichText = true
		slot.Text = ("%s  <s>%s</s>"):format(spec.slotText or "", spec.strikeText)
	end

	local b = spec.button or {}
	local button = PriceButton.build({
		parent = card, name = "PriceButton", kind = b.kind or (spec.owned and "secondary" or "primary"),
		currency = b.currency, amount = b.amount, label = b.label, text = b.state and Text.get(PriceButton.stateText[b.state]) or b.text,
		width = inner, height = buttonH, anchorPoint = Vector2.new(0.5, 1), position = UDim2.new(0.5, 0, 1, -PAD),
		enabled = b.enabled ~= false, onActivated = b.onActivated,
	})

	if spec.isNew then
		tag(card, "NewTag", Text.get("shop.card.new"), UIColors.shopNew, UIColors.shopNewText, 0)
	end
	if spec.band then
		local band = UIColors.shopBand[spec.band]
		tag(card, "BandTag", Text.get("shop.band." .. spec.band), band.bg, band.fg, 1)
	end
	if spec.owned then -- 보유 = 그림 위 회색 반투명 덮개 + 보유 중 ✓
		local cover = Instance.new("TextLabel")
		cover.Name = "OwnedCover"
		cover.BackgroundColor3 = UIColors.shopOwnedCover
		cover.BackgroundTransparency = 0.35
		cover.Size = UDim2.new(1, 0, 0, picH)
		cover.Font = Theme.font
		cover.TextSize = Theme.textSize("body")
		cover.TextColor3 = Theme.colors.textPrimary
		cover.Text = Text.get("shop.ownedCheck")
		cover.ZIndex = 3
		cover.Parent = card
		Theme.corner(cover, Theme.corner.chip)
	end
	return card, button
end

return Card
