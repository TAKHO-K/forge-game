-- QUEUE-ALL6 C 보상 칸 펼쳐 보기(출석 · 퀘스트 · 도감 · 합동 목표 · 시즌 패스 공통 - RewardIcons.row가 칸마다 붙인다).
--   칸을 누르면(폰 탭 · PC 클릭) 상세 카드가 펼쳐지고 한 번 더 누르거나 다른 곳을 누르면 접힌다. PC는 마우스를 올려도 같은 카드(놓으면 사라짐 - 누른 카드는 남는다).
--   카드 = 큰 그림 · 이름 · 받는 수량 · 한 줄 설명 · 지금 가진 개수 - 문구 = ItemInfoData(item.name/desc.* - 가방 · 상점과 같은 표).
--   카드는 자기 ScreenGui(창 위 DisplayOrder)에 그려 스크롤 칸에 잘리지 않는다 · 화면 안으로 민다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ItemInfoData = require(ReplicatedStorage.Shared.data.ItemInfoData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.kit.Theme)
local ArtImage = require(script.Parent.ArtImage)

local RewardDetail = {}

local player = Players.LocalPlayer
local CARD_W, ICON = 260, 56
local DISPLAY_ORDER = 260 -- overlay 대역(200 ~ 249) 위

local gui, card, refs
local current = nil -- { cell, sticky }

function RewardDetail.itemId(key)
	return ItemInfoData.alias[key] or key
end

-- 지금 가진 개수(글자) - 모르면 nil
function RewardDetail.ownedText(id)
	local info = ItemInfoData.items[id]
	local owned = info and info.owned
	if not owned then
		return nil
	end
	local n
	if owned.attr then
		n = player:GetAttribute(owned.attr)
	elseif owned.source == "eggs" then
		local ok, NestState = pcall(require, script.Parent.Parent.NestState)
		n = ok and #NestState.eggs or nil
	end
	if type(n) ~= "number" then
		return nil
	end
	return NumberFormat.format(n)
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "RewardDetailGui"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = DISPLAY_ORDER
	gui.IgnoreGuiInset = false
	gui.Parent = player:WaitForChild("PlayerGui")
	card = Instance.new("Frame")
	card.Name = "RewardDetailCard"
	card.Visible = false
	card.Size = UDim2.fromOffset(CARD_W, 108)
	card.BackgroundColor3 = Theme.color("panel")
	card.BackgroundTransparency = 0.04
	card.Parent = gui
	Theme.corner(card, Theme.corner.panel)
	Theme.stroke(card, "gold")
	local icon = Instance.new("Frame")
	icon.Name = "IconSlot"
	icon.BackgroundColor3 = Theme.color("slot")
	icon.Position = UDim2.fromOffset(10, 10)
	icon.Size = UDim2.fromOffset(ICON + 8, ICON + 8)
	icon.Parent = card
	Theme.corner(icon, 10)
	local name = Theme.label(card, "", "header", "textPrimary")
	name.Name = "ItemName"
	name.Position = UDim2.fromOffset(ICON + 28, 8)
	name.Size = UDim2.new(1, -(ICON + 36), 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local qty = Theme.label(card, "", "body", "gold")
	qty.Name = "ItemQty"
	qty.Position = UDim2.fromOffset(ICON + 28, 30)
	qty.Size = UDim2.new(1, -(ICON + 36), 0, 18)
	local owned = Theme.label(card, "", "caption", "textSecondary")
	owned.Name = "ItemOwned"
	owned.Position = UDim2.fromOffset(ICON + 28, 50)
	owned.Size = UDim2.new(1, -(ICON + 36), 0, 18)
	local desc = Theme.label(card, "", "body", "textPrimary")
	desc.Name = "ItemDesc"
	desc.TextWrapped = true
	desc.Position = UDim2.fromOffset(10, ICON + 22)
	desc.Size = UDim2.new(1, -20, 0, 36)
	local hint = Theme.label(card, "", "caption", "textSecondary")
	hint.Name = "ItemHint"
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.new(1, -10, 0, 8)
	hint.Size = UDim2.fromOffset(80, 16)
	refs = { icon = icon, name = name, qty = qty, owned = owned, desc = desc, hint = hint }
	-- 다른 곳을 누르면 접는다(카드 · 지금 칸 안은 제외)
	UserInputService.InputBegan:Connect(function(input)
		if not current or not card.Visible then
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local p = Vector2.new(input.Position.X, input.Position.Y)
		local function inside(g)
			local a, s = g.AbsolutePosition, g.AbsoluteSize
			local inset = gui.IgnoreGuiInset and Vector2.zero or game:GetService("GuiService"):GetGuiInset()
			local q = p - inset
			return q.X >= a.X and q.Y >= a.Y and q.X <= a.X + s.X and q.Y <= a.Y + s.Y
		end
		if not inside(card) and not (current.cell.Parent and inside(current.cell)) then
			RewardDetail.hide()
		end
	end)
end

function RewardDetail.hide()
	current = nil
	if card then
		card.Visible = false
	end
end

-- 카드 채우기 + 자리(칸 아래 · 화면 안)
function RewardDetail.show(cell, key, qtyText, sticky)
	if not gui then
		build()
	end
	local id = RewardDetail.itemId(key)
	current = { cell = cell, sticky = sticky }
	for _, c in ipairs(refs.icon:GetChildren()) do
		c:Destroy()
	end
	local info = ItemInfoData.items[id]
	local img = ArtImage.label(refs.icon, "icons/reward/" .. (info and info.icon or id), UDim2.fromOffset(ICON, ICON), "?")
	img.Position = UDim2.fromOffset(4, 4)
	refs.name.Text = Text.get("item.name." .. id)
	refs.qty.Text = qtyText or ""
	refs.qty.Visible = qtyText ~= nil and qtyText ~= ""
	local owned = RewardDetail.ownedText(id)
	refs.owned.Text = owned and Text.get("item.owned", { n = owned }) or ""
	refs.desc.Text = Text.get("item.desc." .. id)
	refs.hint.Text = sticky and Text.get("item.collapseHint") or ""
	card.Visible = true
	local screen = gui.AbsoluteSize
	local a, s = cell.AbsolutePosition, cell.AbsoluteSize
	local h = card.AbsoluteSize.Y
	local x = math.clamp(a.X + s.X / 2 - CARD_W / 2, 8, math.max(8, screen.X - CARD_W - 8))
	local y = a.Y + s.Y + 6
	if y + h > screen.Y - 8 then
		y = a.Y - h - 6 -- 아래가 모자라면 칸 위로
	end
	card.Position = UDim2.fromOffset(x, math.clamp(y, 8, math.max(8, screen.Y - h - 8)))
end

function RewardDetail.isOpenFor(cell)
	return current ~= nil and current.cell == cell and card.Visible
end

-- 칸(GuiButton)에 붙이기: 누름 = 펼침/접기 · PC 마우스 올림 = 잠깐 보기
function RewardDetail.attach(cell, key, qtyText)
	cell.Activated:Connect(function()
		if RewardDetail.isOpenFor(cell) and current.sticky then
			RewardDetail.hide()
		else
			RewardDetail.show(cell, key, qtyText, true)
		end
	end)
	cell.MouseEnter:Connect(function()
		if not Theme.isMobile and not (current and current.sticky) then
			RewardDetail.show(cell, key, qtyText, false)
		end
	end)
	cell.MouseLeave:Connect(function()
		if current and current.cell == cell and not current.sticky then
			RewardDetail.hide()
		end
	end)
	cell.AncestryChanged:Connect(function()
		if not cell:IsDescendantOf(game) and current and current.cell == cell then
			RewardDetail.hide()
		end
	end)
end

return RewardDetail
