-- A2-N4 §4-2 세트 도감 탭(장비창 - SetData.codex 스위치 뒤). 구역(WorldMapData.zones) × 등급(ArmorData.gradeOrder) 칸마다 그 구역 · 등급 갑옷 아이콘 + 가진 부위 수(0 ~ 3).
--   1차 = 지금 가방 + 착용 3부위로 센다(서버 스냅샷 S.inventory · S.equippedByPart - 저장 변경 없음). 3부위를 다 가진 칸 = 완성(금테). 보상은 설계만(docs/design/set-codex.md).
--   구역 = item.setZone → 없으면 itemLevel이 닿는 보스 구역(ArtMeshKit.armorZone - 아이콘 · 착용 표시와 같은 규칙).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local SetData = require(ReplicatedStorage.Shared.data.SetData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)

local CodexTab = {}

function CodexTab.enabled()
	return SetData.codex.enabled or workspace:GetAttribute(SetData.codex.attribute) == true
end

-- 순수: 아이템 목록 → [구역][등급] = { [부위] = true }
function CodexTab.collect(items)
	local owned = {}
	for _, item in ipairs(items) do
		if type(item) == "table" and item.part and item.grade and table.find(SetData.parts, item.part) then
			local zone = ArtMeshKit.armorZone(item)
			owned[zone] = owned[zone] or {}
			owned[zone][item.grade] = owned[zone][item.grade] or {}
			owned[zone][item.grade][item.part] = true
		end
	end
	return owned
end

local CELL, GAP, LABEL_W, ROW_GAP, TOP = 48, 6, 110, 14, 56

local function gradeColor(grade)
	local v = ItemVisualData.gradeVisuals[grade]
	return v and v.color or Color3.new(1, 1, 1)
end

function CodexTab.create(S, R)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "CodexTab"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.Visible = false
	frame.Parent = R.content
	R.codexFrame = frame

	local summary = Instance.new("TextLabel")
	summary.Name = "Summary"
	summary.BackgroundTransparency = 1
	summary.Font = Theme.font
	summary.TextColor3 = Color3.new(1, 1, 1)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.Position = UDim2.new(0, 12, 0, 6)
	summary.Size = UDim2.new(1, -24, 0, 22)
	summary.Parent = frame
	local reward = summary:Clone()
	reward.Name = "Reward"
	reward.Font = Theme.fontBody
	reward.TextColor3 = UIColors.textSecondary
	reward.Position = UDim2.new(0, 12, 0, 28)
	reward.Parent = frame

	local cells = {}
	local function rebuild()
		for _, c in ipairs(cells) do
			c:Destroy()
		end
		table.clear(cells)
		local items = {}
		for _, item in ipairs(S.inventory or {}) do
			table.insert(items, item)
		end
		for _, item in pairs(S.equippedByPart()) do
			table.insert(items, item)
		end
		local owned = CodexTab.collect(items)
		local grades = ArmorData.gradeOrder
		local done, pieces = 0, 0
		for row, zone in ipairs(WorldMapData.zones) do
			local y = TOP + (row - 1) * (CELL + ROW_GAP)
			local name = Instance.new("TextLabel")
			name.BackgroundTransparency = 1
			name.Font = Theme.fontBody
			name.TextSize = Theme.textSize("caption")
			name.TextColor3 = UIColors.textSecondary
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.TextWrapped = true
			name.Text = zone.theme
			name.Position = UDim2.new(0, 12, 0, y)
			name.Size = UDim2.new(0, LABEL_W - 8, 0, CELL)
			name.Parent = frame
			table.insert(cells, name)
			for col, grade in ipairs(grades) do
				local count = 0
				for _ in pairs((owned[zone.key] and owned[zone.key][grade]) or {}) do
					count += 1
				end
				pieces += count
				local complete = count >= #SetData.parts
				if complete then
					done += 1
				end
				local cell = Instance.new("Frame")
				cell.Name = ("Cell_%s_%s"):format(zone.key, grade)
				cell.Position = UDim2.new(0, LABEL_W + (col - 1) * (CELL + GAP), 0, y)
				cell.Size = UDim2.new(0, CELL, 0, CELL)
				cell.BackgroundColor3 = UIColors.panel
				cell.BackgroundTransparency = count > 0 and 0.1 or 0.6
				cell.Parent = frame
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0, 8)
				corner.Parent = cell
				local stroke = Instance.new("UIStroke")
				stroke.Thickness = complete and 3 or 1.5
				stroke.Color = complete and UIColors.gold or gradeColor(grade)
				stroke.Transparency = count > 0 and 0 or 0.6
				stroke.Parent = cell
				local icon = Instance.new("Frame")
				icon.BackgroundTransparency = 1
				icon.AnchorPoint = Vector2.new(0.5, 0.5)
				icon.Position = UDim2.new(0.5, 0, 0.42, 0)
				icon.Size = UDim2.new(0, 30, 0, 30)
				icon.Parent = cell
				if not ItemIcons.image(icon, 30, ("icons/armor/armor_%s_%s"):format(zone.key, grade)) then
					ItemIcons.armor(icon, 30, gradeColor(grade))
				end
				for _, d in ipairs(cell:GetDescendants()) do
					if d:IsA("ImageLabel") then
						d.ImageTransparency = count > 0 and 0 or 0.7
					end
				end
				local n = Instance.new("TextLabel")
				n.BackgroundTransparency = 1
				n.Font = Theme.font
				n.TextSize = Theme.textSize("caption")
				n.TextColor3 = count > 0 and Color3.new(1, 1, 1) or UIColors.textSecondary
				n.TextStrokeTransparency = 0.3
				n.Text = ("%d/%d"):format(count, #SetData.parts)
				n.AnchorPoint = Vector2.new(1, 1)
				n.Position = UDim2.new(1, -3, 1, -1)
				n.Size = UDim2.new(0, 32, 0, 14)
				n.TextXAlignment = Enum.TextXAlignment.Right
				n.Parent = cell
				table.insert(cells, cell)
			end
		end
		local total = #WorldMapData.zones * #grades
		summary.TextSize = Theme.textSize("body")
		summary.Text = Text.get("codex.summary", { done = tostring(done), total = tostring(total), pieces = tostring(pieces), allPieces = tostring(total * #SetData.parts) })
		reward.TextSize = Theme.textSize("caption")
		reward.Text = Text.get("codex.reward")
		frame.CanvasSize = UDim2.new(0, LABEL_W + #grades * (CELL + GAP) + 12, 0, TOP + #WorldMapData.zones * (CELL + ROW_GAP) + 12)
	end
	S.rebuildCodex = rebuild

	table.insert(R.layouts, function(L)
		frame.Position = UDim2.new(0, 0, 0, L.bodyTop)
		frame.Size = UDim2.new(1, 0, 0, L.bodyH)
	end)
	frame:GetPropertyChangedSignal("Visible"):Connect(function()
		if frame.Visible then
			rebuild()
		end
	end)
end

return CodexTab
