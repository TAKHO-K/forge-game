-- UI-1c(I v1 묶음) 공용 그리기 조각: 글자 크기 · 판 · 글 · 테 · 아바타(HeadShot). 명예의 전당 · 도감 v3 · 장비 상세가 같이 쓴다.
--   글자 = spec 값(새 보통 기준) → 설정 3단(1.0 · 1.15 · 1.3)만 곱함(UiTokens.textBase는 다시 안 곱함).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UiModel = require(ReplicatedStorage.Shared.UiModel)
local Tokens = require(ReplicatedStorage.Shared.data.UiTokens)
local Flags = require(ReplicatedStorage.Shared.data.UiV2Flags)
local UiKit = require(script.Parent.UiKit)

local V9 = {}

function V9.hex(h)
	return typeof(h) == "Color3" and h or Color3.fromHex(h)
end
local hex = V9.hex

function V9.px(n)
	local base = Flags.text and Tokens.textBase or 1
	return math.floor(n * UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) / base + 0.5)
end

function V9.corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = r == "pill" and UDim.new(1, 0) or UDim.new(0, r)
	c.Parent = inst
	return c
end

function V9.stroke(inst, color, thick, transparency)
	local s = Instance.new("UIStroke")
	s.Color = hex(color)
	s.Thickness = thick
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = inst
	return s
end

-- 판(rect = { x, y, w, h } · color nil = 투명)
function V9.frame(parent, rect, color, name)
	local f = Instance.new("Frame")
	f.Name = name or "Frame"
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color and hex(color) or Color3.new()
	f.BackgroundTransparency = color and 0 or 1
	f.Position = UDim2.fromOffset(rect[1], rect[2])
	f.Size = UDim2.fromOffset(rect[3], rect[4])
	f.Parent = parent
	return f
end

-- 글(props = { name, font, align, alignY, rich, rect, wrap })
function V9.label(parent, text, size, color, props)
	props = props or {}
	local l = Instance.new("TextLabel")
	l.Name = props.name or "Label"
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(props.font or "koreanBold")
	l.TextSize = size
	l.TextColor3 = hex(color or "FFFFFF")
	l.TextXAlignment = props.align or Enum.TextXAlignment.Left
	l.TextYAlignment = props.alignY or Enum.TextYAlignment.Center
	l.TextTruncate = props.wrap and Enum.TextTruncate.None or Enum.TextTruncate.AtEnd
	l.TextWrapped = props.wrap == true
	l.RichText = props.rich == true
	l.Text = text or ""
	if props.rect then
		l.Position = UDim2.fromOffset(props.rect[1], props.rect[2])
		l.Size = UDim2.fromOffset(props.rect[3], props.rect[4])
	end
	l.Parent = parent
	return l
end

-- 원형 아바타 = HeadShot 썸네일(불러오는 중 · 실패 = 회색 원 + 이름 첫 글자) · 사람마다 한 번만 요청
local thumbs = {} -- [userId] = 그림 문자열 | false(실패) | "pending"
local waiting = {}
function V9.avatar(parent, userId, name, sizePx, ringColor, ringW, colors)
	colors = colors or { faceBg = "3A4466", faceText = "E3E7EE" }
	local holder = Instance.new("Frame")
	holder.Name = "Avatar"
	holder.BackgroundColor3 = hex(colors.faceBg)
	holder.Size = UDim2.fromOffset(sizePx, sizePx)
	holder.Parent = parent
	V9.corner(holder, "pill")
	if ringColor then
		V9.stroke(holder, ringColor, ringW or 3)
	end
	local initial = (name and name ~= "") and utf8.char(utf8.codepoint(name, 1, 1)) or "?"
	local first = V9.label(holder, initial, math.floor(sizePx * 0.45), colors.faceText, { name = "Initial", align = Enum.TextXAlignment.Center, font = "number" })
	first.Size = UDim2.fromScale(1, 1)
	first.TextTruncate = Enum.TextTruncate.None
	local img = Instance.new("ImageLabel")
	img.Name = "HeadShot"
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Visible = false
	img.Parent = holder
	V9.corner(img, "pill")
	local function apply(content)
		if content then
			img.Image = content
			img.Visible = true
			first.Visible = false
		end
	end
	local id = tonumber(userId)
	if not id or id <= 0 then
		return holder
	end
	local known = thumbs[id]
	if type(known) == "string" and known ~= "pending" then
		apply(known)
	elseif known == nil or known == "pending" then
		waiting[id] = waiting[id] or {}
		table.insert(waiting[id], apply)
		if known == nil then
			thumbs[id] = "pending"
			task.spawn(function()
				local ok, content, ready = pcall(function()
					return Players:GetUserThumbnailAsync(id, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
				end)
				thumbs[id] = (ok and ready and content) or false
				for _, fn in ipairs(waiting[id] or {}) do
					fn(thumbs[id] or nil)
				end
				waiting[id] = nil
			end)
		end
	end
	return holder
end

-- UI-1c: 기준 화면 루트(UIScale)가 1보다 작을 때(1366 × 768 등) 글자만 최소 크기로 되돌림(UiModel.textFloorPx · 스위치 UiV2Flags.textFloor).
--   원래 크기 = 속성 V9BaseText(코드가 TextSize를 다시 쓰면 그 값이 새 원래 크기) · 키운 글자가 칸을 넘치면 2줄(높이 되면) → 그래도 넘치면 원래 크기 쪽으로 1씩 줄임(말줄임 대신).
local TextService = game:GetService("TextService")
local function plain(t)
	return t.RichText and (t.Text:gsub("<[^>]->", "")) or t.Text
end
local function widthOf(g, s)
	return g.Size.X.Scale == 0 and g.AutomaticSize == Enum.AutomaticSize.None and g.Size.X.Offset or g.AbsoluteSize.X / s
end
local function fitsAt(t, size, s)
	if t.AutomaticSize ~= Enum.AutomaticSize.None then -- 자동 폭 = 가장 가까운 고정 폭 조상 칸 − 같은 줄 다른 것(아이콘 등) 안에 들어가야 함
		local a = t.Parent
		while a and a:IsA("GuiObject") and a.AutomaticSize ~= Enum.AutomaticSize.None do
			a = a.Parent
		end
		if not (a and a:IsA("GuiObject")) then
			return true
		end
		local room = widthOf(a, s) - 12
		if t.Parent ~= a then
			for _, c in ipairs(t.Parent:GetChildren()) do
				if c ~= t and c:IsA("GuiObject") and c.Visible then
					room -= widthOf(c, s) + 4
				end
			end
		end
		local ok, b = pcall(TextService.GetTextSize, TextService, plain(t), size, t.Font, Vector2.new(1e5, 1e5))
		return not ok or b.X <= room
	end
	local w = t.Size.X.Scale == 0 and t.Size.X.Offset or t.AbsoluteSize.X / s
	local h = t.Size.Y.Scale == 0 and t.Size.Y.Offset or t.AbsoluteSize.Y / s
	if w <= 0 or h <= 0 then
		return true
	end
	local ok, b = pcall(TextService.GetTextSize, TextService, plain(t), size, t.Font, Vector2.new(t.TextWrapped and w or 1e5, 1e5))
	return not ok or (b.X <= w + 1 and b.Y <= (t.TextWrapped and h + 1 or h * 1.25 + 1)) -- 한 줄 글자는 칸 높이 25%까지 넘쳐도 됨(가운데 정렬 · 잘리지 않음)
end
function V9.textFloor(root, scaleObj, isPhone)
	if not Flags.textFloor then
		return
	end
	local mul = UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) / (Flags.text and Tokens.textBase or 1)
	local function apply(t)
		local base = t:GetAttribute("V9BaseText")
		if not base or t.TextSize ~= t:GetAttribute("V9AppliedText") then -- 처음 · 코드가 다시 씀
			base = t.TextSize
			t:SetAttribute("V9BaseText", base)
		end
		if t.RichText and t.Text ~= t:GetAttribute("V9AppliedRich") then -- RichText <font size="n"> = 원래 글을 따로 기억
			t:SetAttribute("V9BaseRich", t.Text)
		end
		local s = scaleObj.Scale
		local full = UiModel.textFloorPx(base, s, isPhone, mul)
		local want = full
		if want > base and not fitsAt(t, want, s) then
			if not t.TextWrapped and t.TextTruncate ~= Enum.TextTruncate.None and fitsAt(t, base, s) then
				local h = t.Size.Y.Scale == 0 and t.Size.Y.Offset or t.AbsoluteSize.Y / s
				if h >= want * 2.2 then
					t.TextWrapped = true
				end
			end
			while want > base and not fitsAt(t, want, s) do
				want -= 1
			end
		end
		t:SetAttribute("V9AppliedText", want)
		t.TextSize = want
		local rich = t.RichText and t:GetAttribute("V9BaseRich")
		if rich then
			local frac = full > base and (want - base) / (full - base) or 1
			local out = rich:gsub('size="(%d+)"', function(n)
				n = tonumber(n)
				return ('size="%d"'):format(n + math.floor((UiModel.textFloorPx(n, s, isPhone, mul) - n) * frac))
			end)
			t:SetAttribute("V9AppliedRich", out)
			t.Text = out
		end
	end
	local function hook(t)
		if not (t:IsA("TextLabel") or t:IsA("TextButton") or t:IsA("TextBox")) or t.TextScaled then
			return
		end
		task.defer(function() -- 만드는 코드가 TextSize · 크기 · 글을 다 넣은 뒤
			if t.Parent then
				apply(t)
				t:GetPropertyChangedSignal("TextSize"):Connect(function()
					if t.TextSize ~= t:GetAttribute("V9AppliedText") then
						apply(t)
					end
				end)
				t:GetPropertyChangedSignal("Text"):Connect(function()
					if t.Text ~= t:GetAttribute("V9AppliedRich") then
						apply(t)
					end
				end)
			end
		end)
	end
	for _, d in ipairs(root:GetDescendants()) do
		hook(d)
	end
	root.DescendantAdded:Connect(hook)
	scaleObj:GetPropertyChangedSignal("Scale"):Connect(function()
		for _, d in ipairs(root:GetDescendants()) do
			if d:GetAttribute("V9BaseText") then
				apply(d)
			end
		end
	end)
end

return V9
