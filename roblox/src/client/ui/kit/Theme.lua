-- GUI 공통 틀의 값 한 곳(30-0 S06, PRD 20.81 [D-3]). 부품(kit/*)은 색 · 글씨 · 간격 · 모서리를 전부 여기서만 받는다 - 새 색 0(UIColors 그대로).
-- 모바일 판정은 이 파일 한 곳이다(Theme.isMobile). 사람이 Studio에서 폰 화면을 흉내 낼 수 있게 SkillSlots와 같은 ForceTouchLayout Attribute를 Studio에서만 따른다 -
-- 그 경우 Theme.recompute()를 다시 불러야 값이 바뀐다(전시장이 열릴 때마다 부른다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local Theme = {}

Theme.colors = UIColors
Theme.font = Enum.Font.GothamBold -- 지금 HUD의 폰트 하나
Theme.fontBody = Enum.Font.Gotham

-- 글씨 5단(PC 기준). 12 미만 금지(16-6 [4]).
Theme.text = { title = 20, header = 16, body = 14, caption = 12, number = 18 }
Theme.space = { 4, 8, 12, 16 }
Theme.touchMin = 44
Theme.mobileTextScale = 1.15

-- Theme.corner는 표이면서 함수다: Theme.corner.panel(값) · Theme.corner(inst, px)(헬퍼) - 지시서가 둘 다 같은 이름으로 적었다.
Theme.corner = setmetatable({ panel = 12, button = 10, chip = 8 }, {
	__call = function(_, inst, px)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, px)
		corner.Parent = inst
		return corner
	end,
})

Theme.isMobile = false
Theme.buttonHeight = 32
Theme.tabHeight = 28

-- 모바일 판정 + 그에 따라 바뀌는 값(버튼 · 탭 높이)을 다시 계산한다.
function Theme.recompute()
	local player = Players.LocalPlayer
	local forced = RunService:IsStudio() and player ~= nil and player:GetAttribute("ForceTouchLayout") == true
	Theme.isMobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or forced
	Theme.buttonHeight = Theme.isMobile and 44 or 32
	Theme.tabHeight = Theme.isMobile and 40 or 28
end
Theme.recompute()

-- 글씨 크기: 모바일이면 ×1.15 반올림(title 23 · header 18 · body 16 · caption 14 · number 21).
function Theme.textSize(name)
	local base = Theme.text[name]
	assert(base, "Theme.textSize: 알 수 없는 글씨 단 - " .. tostring(name))
	if Theme.isMobile then
		return math.floor(base * Theme.mobileTextScale + 0.5)
	end
	return base
end

function Theme.color(name)
	local color = UIColors[name]
	assert(typeof(color) == "Color3", "Theme.color: UIColors에 없는 색 - " .. tostring(name))
	return color
end

-- RichText용 "#RRGGBB".
function Theme.colorHex(name)
	local color = Theme.color(name)
	return ("#%02X%02X%02X"):format(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

-- 얇은 테두리(rim 1px).
function Theme.stroke(inst, colorName, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = colorName and Theme.color(colorName) or UIColors.rim
	stroke.Transparency = transparency or UIColors.rimTransparency
	stroke.Thickness = 1
	stroke.Parent = inst
	return stroke
end

-- 글 한 줄 라벨. 크기는 호출부가 정한다(고정 크기 원칙 - AutomaticSize를 쓰지 않는다).
function Theme.label(parent, text, sizeName, colorName)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = (sizeName == "caption" or sizeName == "body") and Theme.fontBody or Theme.font
	label.TextSize = Theme.textSize(sizeName or "body")
	label.TextColor3 = Theme.color(colorName or "textPrimary")
	label.Text = text or ""
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

return Theme
