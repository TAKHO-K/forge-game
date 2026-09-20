-- 플레이어 이름 표시 형식(S12b D) - "★n Lv.35 표시이름". 머리 위 이름표 · 파티창 · 드랍 알림이 같은 규칙을 쓴다(순수 함수 - 검증이 그대로 부른다).
-- ★n(환생이 있을 때만)과 Lv 부분은 이름보다 한 단계 작은 글씨 · 다른 색이다. DisplayName만 쓴다 - @username은 장비 보기 창 상단에만 나온다.
--   parts = 조각 목록({ text, colorName?, size?, isName? }) - Toast 같은 조각 단위 표시가 그대로 쓴다.  richText = 조각을 RichText 한 줄로 이은 것.  plain = 태그 없는 글.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local PlayerLabelFormat = {}

local function hexOf(colorName)
	local color = UIColors[colorName]
	return ("#%02X%02X%02X"):format(math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local function escape(text)
	return (tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- 이름 글씨 크기의 한 단계 아래(sizeSteps에서 size보다 작은 가장 큰 값). 맨 아래 단(12) 이하면 그 단 그대로 - 12 미만은 만들지 않는다.
function PlayerLabelFormat.levelSize(size)
	local steps = SocialData.label.sizeSteps
	local best = steps[#steps]
	for _, step in ipairs(steps) do
		if step < size and step > best then
			best = step
		end
	end
	return best
end

-- 조각 목록. level이 nil이면 Lv 조각을 빼고, rebirth가 nil · 0이면 ★ 조각을 뺀다. size = 이름의 글씨 크기(px) - ★n · Lv 조각은 levelSize(size).
-- 이름 조각에는 size가 없다(라벨의 기본 크기 그대로) · nameColorName을 주면 colorName이 붙는다.
function PlayerLabelFormat.parts(displayName, level, rebirth, size, nameColorName)
	local label = SocialData.label
	local small = PlayerLabelFormat.levelSize(size)
	local parts = {}
	if rebirth and rebirth > 0 then
		table.insert(parts, { text = label.rebirthFormat:format(rebirth) .. " ", colorName = label.rebirthColorName, size = small })
	end
	if level then
		table.insert(parts, { text = label.levelFormat:format(level) .. " ", colorName = label.levelColorName, size = small })
	end
	table.insert(parts, { text = tostring(displayName), colorName = nameColorName, isName = true })
	return parts
end

-- RichText 한 줄(라벨 RichText = true). 이름의 색은 nameColorName이 없으면 라벨의 TextColor3.
function PlayerLabelFormat.richText(displayName, level, rebirth, size, nameColorName)
	local out = {}
	for _, part in ipairs(PlayerLabelFormat.parts(displayName, level, rebirth, size, nameColorName)) do
		local text = escape(part.text)
		if part.size then
			text = ('<font size="%d" color="%s">%s</font>'):format(part.size, hexOf(part.colorName), text)
		elseif part.colorName then
			text = ('<font color="%s">%s</font>'):format(hexOf(part.colorName), text)
		end
		table.insert(out, text)
	end
	return table.concat(out)
end

-- 태그 없는 글자("★2 Lv.35 표시이름").
function PlayerLabelFormat.plain(displayName, level, rebirth)
	local out = {}
	for _, part in ipairs(PlayerLabelFormat.parts(displayName, level, rebirth, SocialData.label.sizeSteps[1])) do
		table.insert(out, part.text)
	end
	return table.concat(out)
end

return PlayerLabelFormat
