-- UI-1b A 설명 창(I v1 spec 0-2 · 0-4 · pc_10): 제목 + 줄("항목 · 글") + "닫기 = 바깥 누르기".
--   재화 칩 설명 · 창 제목 옆 [?] 도움말 · 출석 보상 칸 설명이 모두 이 창 하나를 쓴다(한 번에 하나).
--   InfoTip.toggle(anchor, key, content) - 같은 key 다시 누름 = 닫힘 · 바깥 누름 = 닫힘(PC · 폰 같음) · 열린 동안 anchor 하늘 테 3.
--   content = { title = 글, rows = { { label, text } … } } · 크기 · 색 = UiLayoutData.infoTip(데이터).
--   문구 틀(사용자 10-10 · 모든 InfoTip 같음): 첫 줄 = 이름 한 단어("골드") · 그 아래 짧은 줄 "획득처: …" · "사용처: …"(줄 이름 = 노랑 · 글 = 흰색 한 줄 · 넘치면 줄바꿈).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Text = require(ReplicatedStorage.Shared.Text)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local D = require(ReplicatedStorage.Shared.data.UiLayoutData).infoTip
local UiKit = require(script.Parent.UiKit)

local InfoTip = {}
local state = { gui = nil, frame = nil, key = nil, anchor = nil, ring = nil }

local function hex(h)
	return Color3.fromHex(h)
end

function InfoTip.close()
	if state.frame then
		state.frame:Destroy()
	end
	if state.ring then
		state.ring:Destroy()
	end
	state.frame, state.key, state.anchor, state.ring = nil, nil, nil, nil
end

function InfoTip.isOpen(key)
	return state.frame ~= nil and (key == nil or state.key == key)
end

local function inside(o, p)
	if not (o and o.Parent) then
		return false
	end
	local lo, s = o.AbsolutePosition, o.AbsoluteSize
	return p.X >= lo.X and p.X <= lo.X + s.X and p.Y >= lo.Y and p.Y <= lo.Y + s.Y
end

UserInputService.InputBegan:Connect(function(input)
	if not state.frame then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	-- input.Position = 화면 좌표 · AbsolutePosition = 상단 바 아래 좌표 → 인셋만큼 빼서 맞춘다
	local inset = game:GetService("GuiService"):GetGuiInset()
	local p = Vector2.new(input.Position.X, input.Position.Y) - Vector2.new(0, inset.Y)
	if inside(state.frame, p) or inside(state.anchor, p) then
		return -- 창 안 · 자기 버튼(같은 버튼 다시 = 버튼 쪽 toggle이 닫는다)
	end
	InfoTip.close()
end)

function InfoTip.toggle(anchor, key, content)
	if state.key == key and state.frame then
		InfoTip.close()
		return false
	end
	InfoTip.close()
	local lp = Players.LocalPlayer
	if not state.gui then
		local g = Instance.new("ScreenGui")
		g.Name = "InfoTipGui"
		g.ResetOnSpawn = false
		g.IgnoreGuiInset = false
		g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		g.DisplayOrder = D.displayOrder
		g.Parent = lp:WaitForChild("PlayerGui")
		state.gui = g
	end
	local phone = UiKit.isPhone()
	local S = phone and D.phone or D.pc
	local view = workspace.CurrentCamera.ViewportSize
	local m = HudPlace.scale(view.X, view.Y, phone)
	local f = Instance.new("Frame")
	f.Name = "InfoTip"
	f.BackgroundColor3 = hex(D.bg)
	f.BackgroundTransparency = D.bgT
	f.Size = UDim2.fromOffset(S.w, 0)
	f.AutomaticSize = Enum.AutomaticSize.Y
	f.Parent = state.gui
	UiKit.corner(f, D.corner)
	local st = Instance.new("UIStroke")
	st.Color = hex(D.stroke)
	st.Thickness = D.strokeW
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = f
	local sc = Instance.new("UIScale")
	sc.Scale = m
	sc.Parent = f
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight, pad.PaddingTop, pad.PaddingBottom = UDim.new(0, S.pad), UDim.new(0, S.pad), UDim.new(0, S.pad - 4), UDim.new(0, S.pad - 4)
	pad.Parent = f
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 0)
	list.Parent = f
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, S.head)
	head.LayoutOrder = 1
	head.Parent = f
	local title = UiKit.label(head, content.title or "", "heading", "text.primary", { name = "Title", font = "korean" })
	title.Size = UDim2.new(0.62, 0, 1, 0)
	local hint = UiKit.label(head, Text.get("ui1b.info.close"), "micro", "text.muted", { name = "CloseHint", font = "korean", align = Enum.TextXAlignment.Right })
	hint.AnchorPoint = Vector2.new(1, 0)
	hint.Position = UDim2.fromScale(1, 0)
	hint.Size = UDim2.new(0.38, 0, 1, 0)
	for i, r in ipairs(content.rows or {}) do
		local row = Instance.new("Frame")
		row.Name = "Row" .. i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		row.LayoutOrder = 1 + i
		row.Parent = f
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BorderSizePixel = 0
		line.BackgroundColor3 = hex(D.line)
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Parent = row
		local rp = Instance.new("UIPadding")
		rp.PaddingTop, rp.PaddingBottom = UDim.new(0, S.rowPad), UDim.new(0, S.rowPad)
		rp.Parent = row
		local function esc(t)
			return (tostring(t):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
		end
		local txt = esc(r[2] or "")
		if r[1] and r[1] ~= "" then -- "획득처: …" 한 줄(줄 이름 = 노랑)
			txt = ('<font color="#%s">%s:</font> %s'):format(UiKit.color("accent"):ToHex(), esc(r[1]), txt)
		end
		local body = UiKit.label(row, txt, "body", "text.primary", { name = "Text", font = "korean", wrap = true, rich = true })
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.TextYAlignment = Enum.TextYAlignment.Top
	end
	-- 자리: 버튼 아래(오른쪽 끝 맞춤 · 화살 오른쪽) · 아래가 모자라면 위 · 화면 안으로
	local a, as = anchor.AbsolutePosition, anchor.AbsoluteSize
	local w = S.w * m
	local x = math.clamp(a.X + as.X - w, 8, view.X - w - 8)
	f.Position = UDim2.fromOffset(x, a.Y + as.Y + D.gap)
	task.defer(function()
		if f.Parent and f.AbsolutePosition.Y + f.AbsoluteSize.Y > state.gui.AbsoluteSize.Y - 8 then
			f.Position = UDim2.fromOffset(x, math.max(8, a.Y - D.gap - f.AbsoluteSize.Y))
		end
	end)
	local ring = Instance.new("UIStroke")
	ring.Name = "InfoTipRing"
	ring.Color = hex(D.stroke)
	ring.Thickness = D.ringW
	ring.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ring.Parent = anchor
	state.frame, state.key, state.anchor, state.ring = f, key, anchor, ring
	anchor.Destroying:Connect(function()
		if state.anchor == anchor then
			InfoTip.close()
		end
	end)
	return true
end

-- 재화 · 칩 설명(CurrencyInfo) 한 줄 열기
function InfoTip.currency(anchor, id)
	local CI = require(ReplicatedStorage.Shared.data.CurrencyInfo)
	local e = CI.ids[id]
	if not e then
		return false
	end
	local rows = {}
	for _, r in ipairs(CI.rows) do
		table.insert(rows, { Text.get("ui1b.info.row." .. r), Text.get("ui1b.cur." .. id .. "." .. r) })
	end
	return InfoTip.toggle(anchor, "cur:" .. id, { title = Text.get(e.name), rows = rows })
end

return InfoTip
