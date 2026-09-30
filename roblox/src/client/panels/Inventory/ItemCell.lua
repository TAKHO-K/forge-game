-- 장비창 아이템 칸 한 개(QUEUE-ALL2 P2 ref 17 "아이템 칸 읽는 법") - 가방 칸 · 착용 칸이 같은 규칙으로 그린다.
--   테두리 = 등급색(S.applyGradeVisual - 태초 무지개 · ArtStyleV1 등급 프레임 포함) · 왼쪽 위 = +N(무기 강화) 또는 옵션 이름(방어구는 강화가 없다) · 오른쪽 아래 = Lv ·
--   오른쪽 위 = 자물쇠(잠김) · 모서리 빨간 점 = 새 아이템(NewItems) · 왼쪽 아래 = 세트 문양(구역 번호 1 ~ 6 - 착용 칸 · 세트 효과 칸과 같은 번호).
-- 글씨는 전부 caption(12 · 폰 14) 이상 - 실효 12 미만 금지(COMMON §2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local ItemCell = {}

local zoneNumber = {} -- 구역 키 -> 번호(tierIndex)
for _, zone in pairs(WorldMapData.zones) do
	if type(zone) == "table" and zone.key and zone.tierIndex then
		zoneNumber[zone.key] = zone.tierIndex
	end
end

-- 세트 문양 번호(nil = 세트 아님)
function ItemCell.setNumber(zoneKey)
	return zoneKey and zoneNumber[zoneKey] or nil
end

local function tag(parent, name, anchor, position, size, text, color, align)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.AnchorPoint = anchor
	label.Position = position
	label.Size = size
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = Theme.textSize("caption")
	label.TextXAlignment = align
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextStrokeTransparency = 0.45 -- 아이콘 위에서도 읽히게
	label.TextColor3 = color
	label.Text = text
	label.Parent = parent
	return label
end

-- 세트 문양(둥근 금색 칩 + 구역 번호). parent 안 왼쪽 아래. 반환: 칩(없으면 nil)
function ItemCell.emblem(parent, zoneKey, size)
	local number = ItemCell.setNumber(zoneKey)
	if not number then
		return nil
	end
	size = size or 18
	local chip = Instance.new("Frame")
	chip.Name = "SetEmblem"
	chip.AnchorPoint = Vector2.new(0, 1)
	chip.Position = UDim2.new(0, 4, 1, -4)
	chip.Size = UDim2.new(0, size, 0, size)
	chip.BackgroundColor3 = UIColors.gold
	chip.BorderSizePixel = 0
	chip.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chip
	local label = tag(chip, "Number", Vector2.new(0.5, 0.5), UDim2.new(0.5, 0, 0.5, 0), UDim2.new(1, 4, 1, 0), tostring(number), Color3.fromRGB(34, 24, 10), Enum.TextXAlignment.Center)
	label.TextStrokeTransparency = 1
	return chip
end

-- 새 아이템 빨간 점(모서리 바깥쪽으로 살짝 걸친다). 반환: 점
function ItemCell.newDot(parent, visible)
	local dot = Instance.new("Frame")
	dot.Name = "NewDot"
	dot.AnchorPoint = Vector2.new(1, 0)
	dot.Position = UDim2.new(1, 4, 0, -4)
	dot.Size = UDim2.new(0, 12, 0, 12)
	dot.BackgroundColor3 = UIColors.danger
	dot.BorderSizePixel = 0
	dot.Visible = visible == true
	dot.ZIndex = parent.ZIndex + 1
	dot.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1.5
	stroke.Parent = dot
	return dot
end

-- cell(TextButton · Frame)을 칠한다. spec = { gradeId, part, iconKey, iconColor, iconSize, topLeft = { text, color } | nil, level = number | nil, locked, isNew, setZone }
-- applyGradeVisual = S.applyGradeVisual. 반환 { gradeStroke, glow, newDot }
function ItemCell.paint(cell, spec, applyGradeVisual)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = cell

	-- 은은한 발광(희귀 이상) - 칸보다 살짝 큰 별도 프레임을 뒤에 깐다(box-shadow 대체).
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.Size = UDim2.new(1, 10, 1, 10)
	glow.BackgroundTransparency = 1
	glow.ZIndex = cell.ZIndex - 1
	glow.Parent = cell
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(0, 11)
	glowCorner.Parent = glow

	local gradeStroke = Instance.new("UIStroke")
	gradeStroke.Name = "GradeStroke"
	gradeStroke.Thickness = 2
	gradeStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	gradeStroke.Parent = cell
	if spec.gradeId then
		applyGradeVisual(cell, gradeStroke, glow, spec.gradeId)
	else
		gradeStroke.Color = UIColors.rim
		gradeStroke.Transparency = 0.4
	end

	local iconSize = spec.iconSize or 30
	local holder = Instance.new("Frame")
	holder.Name = "Icon"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, 0)
	holder.Size = UDim2.new(0, iconSize, 0, iconSize)
	holder.BackgroundTransparency = 1
	holder.Parent = cell
	if not ItemIcons.image(holder, iconSize, spec.iconKey, 0.6) then -- A2-N3 Open Cloud 아이콘(ArtStyleV1 뒤 · 없으면 도형)
		local builder = ItemIcons.byPart[spec.part or "armor"] or ItemIcons.byPart.armor
		builder(holder, iconSize, spec.iconColor or UIColors.textPrimary)
	end

	if spec.topLeft and spec.topLeft.text and spec.topLeft.text ~= "" then
		tag(cell, "TopLeft", Vector2.new(0, 0), UDim2.new(0, 5, 0, 3), UDim2.new(1, -24, 0, 14), spec.topLeft.text, spec.topLeft.color or UIColors.textPrimary, Enum.TextXAlignment.Left)
	end
	if spec.level then
		tag(cell, "Level", Vector2.new(1, 1), UDim2.new(1, -5, 1, -3), UDim2.new(1, -28, 0, 14), ("Lv.%d"):format(spec.level), UIColors.textPrimary, Enum.TextXAlignment.Right)
	end
	if spec.locked then
		local lockHolder = Instance.new("Frame")
		lockHolder.Name = "Lock"
		lockHolder.AnchorPoint = Vector2.new(1, 0)
		lockHolder.Position = UDim2.new(1, -4, 0, 4)
		lockHolder.Size = UDim2.new(0, 13, 0, 13)
		lockHolder.BackgroundTransparency = 1
		lockHolder.Parent = cell
		ItemIcons.lock(lockHolder, 13, UIColors.xp)
	end
	ItemCell.emblem(cell, spec.setZone)
	local dot = ItemCell.newDot(cell, spec.isNew)
	return { gradeStroke = gradeStroke, glow = glow, newDot = dot }
end

return ItemCell
