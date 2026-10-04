-- 장비창 아이템 칸 한 개(QUEUE-ALL2 P2 ref 17 "아이템 칸 읽는 법") - 가방 칸 · 착용 칸이 같은 규칙으로 그린다.
--   테두리 = 등급색(S.applyGradeVisual - 태초 무지개 · ArtStyleV1 등급 프레임 포함) · 왼쪽 위 = +N(무기 강화) 또는 옵션 이름(방어구는 강화가 없다) · 오른쪽 아래 = Lv ·
--   오른쪽 위 = 자물쇠(잠김) · 모서리 빨간 점 = 새 아이템(NewItems) · 왼쪽 아래 = 세트 문양(구역 번호 1 ~ 6 - 착용 칸 · 세트 효과 칸과 같은 번호).
--   QUEUE-ALL9C 2-5 칸 틀 ⑥(ArtV1UiData.iconFrameV3 켬): 바탕 = 남색 + 등급 어두운 색 · 좌상단 = 세트 문장 · 우상단 = 등급 마름모 → +N · 옵션 글자 = 왼쪽 아래 · 자물쇠 = 마름모 왼쪽.
-- 글씨는 전부 caption(12 · 폰 14) 이상 - 실효 12 미만 금지(COMMON §2).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ArtImage = require(script.Parent.Parent.Parent.ui.ArtImage)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local FRAME = require(ReplicatedStorage.Shared.data.ArtV1UiData).iconFrameV3 -- QUEUE-ALL9C 2-5 칸 틀 ⑥
local UiTokens = require(ReplicatedStorage.Shared.data.UiTokens)
local UiKit = require(script.Parent.Parent.Parent.ui.v2.UiKit)
local V2 = require(script.Parent.Layout).lookV2 -- QUEUE-UI2 UI2-5 2차(03 v2): 빈 칸 = btn-card 9-slice · 찬 칸 = 모서리 12 + 등급 테두리 3

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

-- QUEUE-ALL9C 2-5 칸 틀 ⑥: 바탕 · 좌상단 세트 문장 · 우상단 등급 마름모(테두리 = 기존 등급 테두리 그대로 - applyGradeVisual)
function ItemCell.frameV3(cell, gradeId, setZone)
	local visual = ItemVisualData.gradeVisuals[gradeId]
	if not visual then
		return
	end
	if cell:IsA("GuiObject") and visual.dark then
		cell.BackgroundColor3 = FRAME.cellBg:Lerp(visual.dark, FRAME.darkMix)
		cell.BackgroundTransparency = 0
	end
	local w = math.max(cell.AbsoluteSize.X, 40)
	local image = setZone and ArtImage.get("icons/ui/set_" .. setZone)
	if image then
		local cs = math.clamp(math.floor(w * FRAME.crestSize), FRAME.crestMin, FRAME.crestMax)
		local crest = Instance.new("ImageLabel")
		crest.Name = "SetCrest"
		crest.BackgroundTransparency = 1
		crest.Image = image
		crest.Position = UDim2.new(0, 3, 0, 3)
		crest.Size = UDim2.fromOffset(cs, cs)
		crest.ZIndex = cell.ZIndex + 1
		crest.Parent = cell
	elseif setZone then
		local chip = ItemCell.emblem(cell, setZone, 16) -- 문장 이미지가 아직 없으면 번호 칩을 좌상단에
		if chip then
			chip.AnchorPoint = Vector2.new(0, 0)
			chip.Position = UDim2.new(0, 3, 0, 3)
		end
	end
	local ds = math.clamp(math.floor(w * FRAME.diamondSize), FRAME.diamondMin, FRAME.diamondMax)
	local diamond = Instance.new("Frame")
	diamond.Name = "GradeDiamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(1, -4 - ds * 0.7, 0, 4 + ds * 0.7)
	diamond.Size = UDim2.fromOffset(ds, ds)
	diamond.Rotation = 45
	diamond.BorderSizePixel = 0
	diamond.BackgroundColor3 = GradeColor.border(gradeId)
	diamond.ZIndex = cell.ZIndex + 1
	diamond.Parent = cell
	local edge = Instance.new("UIStroke")
	edge.Color = visual.light or Color3.new(1, 1, 1)
	edge.Thickness = 1
	edge.Parent = diamond
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

-- 03 v2 빈 칸 · 칸 바탕 = btn-card 9-slice 그림(그림 없으면 옛 색 칸 그대로). 반환: 그림(없으면 nil)
function ItemCell.cardSkin(cell)
	local skin = V2 and UiKit.skin(cell, "card", { keepZ = true })
	if not skin then
		return nil
	end
	skin.Name = "CardSkin"
	for _, child in ipairs(cell:GetChildren()) do
		if child:IsA("UIStroke") then
			child.Enabled = false -- 테두리는 그림 안에 있다
		end
	end
	return skin
end

-- cell(TextButton · Frame)을 칠한다. spec = { gradeId, part, iconKey, iconColor, iconSize, topLeft = { text, color } | nil, level = number | nil, locked, isNew, setZone }
-- applyGradeVisual = S.applyGradeVisual. 반환 { gradeStroke, glow, newDot }
function ItemCell.paint(cell, spec, applyGradeVisual)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, V2 and UiTokens.corner.card or 8)
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
		if V2 then
			gradeStroke.Thickness = math.max(gradeStroke.Thickness, UiTokens.stroke.cardSelected) -- 03 v2 등급 테두리 3
		end
	elseif V2 and ItemCell.cardSkin(cell) then
		gradeStroke.Enabled = false -- 빈 착용 칸 = 카드 그림
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

	local v3 = FRAME and FRAME.enabled
	if v3 and spec.gradeId then
		ItemCell.frameV3(cell, spec.gradeId, spec.setZone)
	end
	if spec.topLeft and spec.topLeft.text and spec.topLeft.text ~= "" then
		if v3 then -- 틀 ⑥: 좌상단 = 세트 문장 → 글자는 왼쪽 아래
			tag(cell, "TopLeft", Vector2.new(0, 1), UDim2.new(0, 5, 1, -3), UDim2.new(1, -40, 0, 14), spec.topLeft.text, spec.topLeft.color or UIColors.textPrimary, Enum.TextXAlignment.Left)
		else
			tag(cell, "TopLeft", Vector2.new(0, 0), UDim2.new(0, 5, 0, 3), UDim2.new(1, -24, 0, 14), spec.topLeft.text, spec.topLeft.color or UIColors.textPrimary, Enum.TextXAlignment.Left)
		end
	end
	if spec.level then
		tag(cell, "Level", Vector2.new(1, 1), UDim2.new(1, -5, 1, -3), UDim2.new(1, -28, 0, 14), ("Lv.%d"):format(spec.level), UIColors.textPrimary, Enum.TextXAlignment.Right)
	end
	if spec.locked then
		local lockHolder = Instance.new("Frame")
		lockHolder.Name = "Lock"
		lockHolder.AnchorPoint = Vector2.new(1, 0)
		lockHolder.Position = v3 and spec.gradeId and UDim2.new(1, -20, 0, 4) or UDim2.new(1, -4, 0, 4) -- 틀 ⑥: 마름모 왼쪽
		lockHolder.Size = UDim2.new(0, 13, 0, 13)
		lockHolder.BackgroundTransparency = 1
		lockHolder.Parent = cell
		ItemIcons.lock(lockHolder, 13, UIColors.xp)
	end
	if not v3 then
		ItemCell.emblem(cell, spec.setZone)
	end
	local dot = ItemCell.newDot(cell, spec.isNew)
	return { gradeStroke = gradeStroke, glow = glow, newDot = dot }
end

return ItemCell
