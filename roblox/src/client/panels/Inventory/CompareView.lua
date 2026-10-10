-- UI-1 4단계 나란히 비교(03 v3 §7): 고른 가방 장비 ↔ 같은 부위 착용 중 · 가운데 = 바뀌는 것(▲ 초록 · ▼ 빨강 · = 회색 + 글자 - 색만으로 안 읽게) · 전투력 변화(서버 같은 함수).
--   PC = 가방 + 상세 자리를 덮음(왼쪽 착용 중은 그대로) · 폰 = 창 전체 · [닫기](보조) [이것으로 장착](노랑).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
local Compare = require(script.Parent.Compare)

local CompareView = {}

function CompareView.create(S, R)
	local player = Players.LocalPlayer
	local view = nil
	local function close()
		if view then
			view:Destroy()
			view = nil
		end
	end
	local function column(parent, x, w, titleText, item, classId)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = UIColors.panel
		f.BackgroundTransparency = 0.1
		f.Position = UDim2.new(x, 8, 0, 56)
		f.Size = UDim2.new(w, -16, 1, -128)
		f.ZIndex = 41
		f.Parent = parent
		UiKit.corner(f, 12)
		local list = Instance.new("UIListLayout")
		list.Padding = UDim.new(0, 6)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Parent = f
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop = UDim.new(0, 12), UDim.new(0, 12), UDim.new(0, 10)
		pad.Parent = f
		local function line(text, color, size, order)
			local l = Theme.label(f, text, size or "body", "textPrimary")
			l.TextColor3 = color or UIColors.textPrimary
			l.TextWrapped = true
			l.TextTruncate = Enum.TextTruncate.None
			l.AutomaticSize = Enum.AutomaticSize.Y
			l.Size = UDim2.new(1, 0, 0, 0)
			l.LayoutOrder = order
			l.ZIndex = 42
			return l
		end
		line(titleText, UIColors.textSecondary, "caption", 0)
		if item then
			local d = ItemDescribe.item(item, classId)
			line(d.title, GradeColor.text(item.grade, UIColors.textPrimary), "header", 1)
			line(d.meta, UIColors.textPrimary, "body", 2)
			for i, l in ipairs(ItemDescribe.optionLines(item, classId) or {}) do
				line(l.text, l.dim and UIColors.textTertiary or UIColors.textPrimary, "body", 2 + i)
			end
		else
			line(Text.get("ui1.bag.compareNone"), UIColors.textTertiary, "body", 1)
		end
		return f
	end
	function S.openCompareView(index)
		close()
		local item = S.inventory[index]
		if not item then
			return
		end
		local classId = player:GetAttribute("ClassId")
		local equipped = S.equippedByPart()[item.part or "armor"]
		local L = R.layout
		local phone = L and L.mode == "phone"
		local f = Instance.new("Frame")
		f.Name = "CompareView"
		f.BackgroundColor3 = Color3.fromHex("161A2B")
		f.BackgroundTransparency = 0.02
		f.ZIndex = 40
		if L and not phone then -- 가운데 가방 + 오른쪽 상세 자리를 덮음
			local top = math.min(L.bagY, L.detailY or L.bagY)
			f.Position = UDim2.fromOffset(L.bagX, top)
			f.Size = UDim2.fromOffset(L.detailX and (L.detailX + L.detailW - L.bagX) or L.bagW, L.bagY + L.bagH - top) -- UI-1c: 고정 창(detailX nil) = 가방 단만
		else
			f.Size = UDim2.fromScale(1, 1)
		end
		f.Parent = R.content
		UiKit.corner(f, 12)
		f.Active = true
		local title = Theme.label(f, Text.get("ui1.bag.compareTitle"), "title", "textPrimary")
		title.Position, title.Size = UDim2.fromOffset(16, 10), UDim2.new(1, -32, 0, 36)
		title.ZIndex = 41
		column(f, 0, 0.34, Text.get("ui1.bag.compareSelected"), item, classId)
		local mid = column(f, 0.34, 0.32, Text.get("ui1.bag.compareChanges"), nil, classId)
		for _, c in ipairs(mid:GetChildren()) do
			if c:IsA("TextLabel") and c.LayoutOrder == 1 then
				c:Destroy() -- "비교할 장비 없음" 줄 대신 바뀌는 것
			end
		end
		local changes = { Compare.baseLine(item, equipped) }
		for _, l in ipairs(Compare.optionLines(item, equipped, classId, true)) do
			table.insert(changes, l)
		end
		local pct = S.powerDeltas and S.powerDeltas[index]
		if pct then
			table.insert(changes, 1, S.powerLine(pct))
		end
		for i, c in ipairs(changes) do
			local l = Theme.label(mid, c.text, "body", "textPrimary")
			l.TextColor3 = c.color or UIColors.textPrimary
			l.TextWrapped = true
			l.TextTruncate = Enum.TextTruncate.None
			l.AutomaticSize = Enum.AutomaticSize.Y
			l.Size = UDim2.new(1, 0, 0, 0)
			l.LayoutOrder = 10 + i
			l.ZIndex = 42
		end
		column(f, 0.66, 0.34, Text.get("ui1.bag.compareEquipped"), equipped, classId)
		local function button(name, textKey, primary, x, w, fn)
			local b = Instance.new("TextButton")
			b.Name = name
			b.AutoButtonColor = true
			b.AnchorPoint = Vector2.new(1, 1)
			b.Position = UDim2.new(1, x, 1, -12)
			b.Size = UDim2.fromOffset(w, phone and 44 or 52)
			b.BackgroundColor3 = primary and UiKit.color("accent") or UiKit.color("panel.slot")
			b.TextColor3 = primary and UiKit.color("accent.text") or UiKit.color("text.primary")
			b.Font = Enum.Font.GothamBold
			b.TextSize = Theme.textSize("header")
			b.Text = Text.get(textKey)
			b.Parent = f
			UiKit.corner(b, 12)
			b.Activated:Connect(fn)
		end
		button("CompareClose", "ui1.bag.close", false, -(phone and 170 or 260), phone and 140 or 200, close) -- [닫기](보조)
		button("CompareEquip", "ui1.bag.equipThis", true, -16, phone and 150 or 230, function() -- [이것으로 장착](노랑)
			close()
			S.equipFromBag(index)
		end)
		-- InventoryGui = ZIndex 전체 모드(Global): 자식 글자가 판 뒤로 숨지 않고 상세 카드보다 위에 오게 전부 같은 층 위로(깊이만큼 +1)
		local function lift(node, z)
			if node:IsA("GuiObject") then
				node.ZIndex = z
			end
			for _, c in ipairs(node:GetChildren()) do
				lift(c, z + 1)
			end
		end
		lift(f, 80)
		view = f
	end
	S.closeCompareView = close
end

return CompareView
