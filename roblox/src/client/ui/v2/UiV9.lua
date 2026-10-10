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

return V9
