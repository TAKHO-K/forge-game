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
	local dot
	if require(ReplicatedStorage.Shared.data.UiV2Flags).bag then
		dot = ItemCell.v3(cell, spec, holder) -- UI-1 4단계 칸 v3
	else
		dot = ItemCell.newDot(cell, spec.isNew)
	end
	return { gradeStroke = gradeStroke, glow = glow, newDot = dot }
end

-- UI-1 4단계 칸 v3(03 v3 §4 · §5): 위 가운데 = 아이템 레벨(1만 이상 "18.4K" · 카툰 숫자 + 외곽선) · 아래 띠 = 옵션 이름(줄임 없음 · 등급 밝은 색) ·
--   오른쪽 아래 = 잠금(진한 판 + 금 테 #FFE7A3 + 자물쇠) · 위 테두리 밖 = NEW 노랑 알약(세션 NewItems · 이름 NewDot = 옛 점과 같은 끄기 경로) ·
--   무기 = 실제 무기 그림(ui/weapon/weapon-<직업>-g<n>) 칸의 82% + 왼쪽 아래 "+N" · 방어구 그림 = 칸의 60% · 56 이하 칸 = Lv · 띠 · 잠금 · NEW 없음 · 칸 안 글자 = 글자 크기 설정과 무관(고정).
local V3 = require(ReplicatedStorage.Shared.data.UiLayoutData).bag.v3
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local function compact(n)
	if n >= 10000 then
		return ("%.1fK"):format(n / 1000)
	end
	return tostring(n)
end
function ItemCell.v3(cell, spec, holder)
	local C = V3.cell
	local phone = Theme.isMobile
	local px = math.max(cell.AbsoluteSize.X, cell.Size.X.Offset, 1)
	local small = px > 1 and px <= C.smallFrom
	local function fixed(name, text, size, color)
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextSize = size
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.TextStrokeColor3 = Color3.fromHex(C.bandBg)
		l.Text = text
		l.ZIndex = cell.ZIndex + 3
		l.Parent = cell
		return l
	end
	-- 그림 크기(무기 = 실제 무기 그림 82%)
	if spec.part == "weapon" and spec.weaponClass then
		local stem = V3.weaponIcon.classStem[spec.weaponClass]
		local gi = table.find(ArmorData.gradeOrder, spec.gradeId) or 1
		local img = stem and ArtImage.get(V3.weaponIcon.prefix .. stem .. "-g" .. gi)
		if img then
			for _, c in ipairs(holder:GetChildren()) do
				c:Destroy()
			end
			local w = Instance.new("ImageLabel")
			w.Name = "WeaponArt"
			w.BackgroundTransparency = 1
			w.ScaleType = Enum.ScaleType.Fit
			w.Image = img
			w.Size = UDim2.fromScale(1, 1)
			w.Parent = holder
			holder.Size = UDim2.fromScale(C.weaponIcon, C.weaponIcon)
		end
	elseif spec.gradeId then
		holder.Size = UDim2.fromScale(C.armorIcon, C.armorIcon)
	end
	-- 옛 글자 자리 정리(같은 정보를 새 자리로)
	local oldTop, oldLevel = cell:FindFirstChild("TopLeft"), cell:FindFirstChild("Level")
	if oldLevel then
		oldLevel.Visible = false
	end
	if oldTop then
		oldTop.Visible = false
	end
	if not small and spec.level then
		local lv = fixed("LevelV3", "Lv." .. compact(spec.level), phone and C.levelText.phone or C.levelText.pc, Color3.new(1, 1, 1))
		lv.AnchorPoint = Vector2.new(0.5, 0)
		lv.Position = UDim2.new(0.5, 0, 0, 2)
		lv.Size = UDim2.new(0.6, 0, 0, (phone and C.levelText.phone or C.levelText.pc) + 2)
	end
	if spec.part == "weapon" and spec.topLeft and spec.topLeft.text then -- 무기 강화 "+N" = 왼쪽 아래
		local plus = fixed("PlusV3", spec.topLeft.text, phone and 13 or 15, spec.topLeft.color or Color3.new(1, 1, 1))
		plus.AnchorPoint = Vector2.new(0, 1)
		plus.Position = UDim2.new(0, 4, 1, -2)
		plus.Size = UDim2.new(0.5, 0, 0, 16)
		plus.TextXAlignment = Enum.TextXAlignment.Left
	elseif not small and spec.topLeft and spec.topLeft.text and spec.topLeft.text ~= "" then -- 옵션 이름 띠(줄임 없음)
		local bh = phone and C.band.phone or C.band.pc
		local band = Instance.new("Frame")
		band.Name = "OptionBand"
		band.AnchorPoint = Vector2.new(0, 1)
		band.Position = UDim2.new(0, 0, 1, 0)
		band.Size = UDim2.new(1, 0, 0, bh)
		band.BackgroundColor3 = Color3.fromHex(C.bandBg)
		band.BackgroundTransparency = C.bandBgTransparency
		band.BorderSizePixel = 0
		band.ZIndex = cell.ZIndex + 2
		band.Parent = cell
		local bt = Instance.new("TextLabel")
		bt.Name = "Text"
		bt.BackgroundTransparency = 1
		bt.Size = UDim2.new(1, -4, 1, 0)
		bt.Position = UDim2.fromOffset(2, 0)
		bt.Font = Enum.Font.GothamBold
		bt.TextScaled = true -- 줄임 없음(넘치면 글자만 작게)
		bt.TextColor3 = spec.topLeft.color or Color3.new(1, 1, 1)
		bt.Text = spec.topLeft.text
		bt.ZIndex = cell.ZIndex + 3
		bt.Parent = band
		local lim = Instance.new("UITextSizeConstraint")
		lim.MaxTextSize = phone and C.bandText.phone or C.bandText.pc
		lim.MinTextSize = 8
		lim.Parent = bt
	end
	local lock = cell:FindFirstChild("Lock")
	if lock then
		lock:Destroy()
	end
	if not small and spec.locked then
		local ls = phone and C.lock.phone or C.lock.pc
		local plate = Instance.new("Frame")
		plate.Name = "Lock"
		plate.AnchorPoint = Vector2.new(1, 1)
		plate.Position = UDim2.new(1, -2, 1, -((phone and C.band.phone or C.band.pc) + 2))
		plate.Size = UDim2.fromOffset(ls, ls)
		plate.BackgroundColor3 = Color3.fromHex(C.bandBg)
		plate.ZIndex = cell.ZIndex + 4
		plate.Parent = cell
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0, 6)
		pc.Parent = plate
		local ps = Instance.new("UIStroke")
		ps.Color = Color3.fromHex(C.lockRim)
		ps.Thickness = 2
		ps.Parent = plate
		ItemIcons.lock(plate, ls - 6, Color3.fromHex(C.lockRim))
		for _, d in ipairs(plate:GetDescendants()) do
			if d:IsA("GuiObject") then
				d.ZIndex = plate.ZIndex + 1
				if d.Parent == plate then
					d.AnchorPoint = Vector2.new(0.5, 0.5)
					d.Position = UDim2.fromScale(0.5, 0.5)
				end
			end
		end
	end
	-- NEW 노랑 알약(위 테두리 밖 · 이름 NewDot = 본 뒤 끄는 옛 경로)
	local pill = Instance.new("TextLabel")
	pill.Name = "NewDot"
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.new(0.5, 0, 0, 0)
	pill.Size = UDim2.fromOffset(38, C.newPill)
	pill.BackgroundColor3 = Color3.fromHex("FFC83D")
	pill.TextColor3 = Color3.fromHex("3A2A12")
	pill.Font = Enum.Font.FredokaOne
	pill.TextSize = 13
	pill.Text = "NEW"
	pill.Visible = spec.isNew == true and not small
	pill.ZIndex = cell.ZIndex + 5
	pill.Parent = cell
	local nc = Instance.new("UICorner")
	nc.CornerRadius = UDim.new(1, 0)
	nc.Parent = pill
	return pill
end

return ItemCell
