-- 보석 탭 맨 위 두 줄(S20c) + PC 무기 그림 장식. GemTab.lua(800줄 한도)에서 분리.
--   GemHeader.createStatus(parent) -> { paint(near), setHint(text) }
--     첫 줄 = 강화대 상태("강화대 근처에서 장착 가능" - 가까우면 초록 · 멀면 회색. 장착은 강화대 12stud 안에서만 서버가 받는다) · 둘째 줄 = 상황별 안내 한 줄.
--   GemHeader.createWeaponArt(parent, size) -> { holder, update(weaponGradeId, classId) }
--     확대한 무기 실루엣(홈은 이제 여기 붙지 않는다 - 무기 에셋은 임시, F5에서 Socket Attachment로 교체) + 직업색 발광(스킬 슬롯이 이미 쓰는 classAccent 재사용 - 새 색 없음).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)

local GemHeader = {}

function GemHeader.createStatus(parent)
	local dot = Instance.new("Frame")
	dot.Name = "StationDot"
	dot.Position = UDim2.new(0, 14, 0, 9)
	dot.Size = UDim2.new(0, 8, 0, 8)
	dot.BackgroundColor3 = UIColors.textTertiary
	dot.BorderSizePixel = 0
	dot.Parent = parent
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local status = Instance.new("TextLabel")
	status.Name = "StationStatus"
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0, 28, 0, 4)
	status.Size = UDim2.new(1, -42, 0, 18)
	status.Font = Enum.Font.GothamBold
	status.TextSize = Theme.textSize("caption")
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextTruncate = Enum.TextTruncate.AtEnd
	status.Text = "강화대 근처에서 장착 가능"
	status.Parent = parent

	local hint = Instance.new("TextLabel")
	hint.Name = "GemHint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 14, 0, 22)
	hint.Size = UDim2.new(1, -28, 0, 18)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = Theme.textSize("caption")
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.TextColor3 = UIColors.textSecondary
	hint.Text = ""
	hint.Parent = parent

	return {
		paint = function(near)
			dot.BackgroundColor3 = near and UIColors.success or UIColors.textTertiary
			status.TextColor3 = near and UIColors.success or UIColors.textTertiary
		end,
		setHint = function(text)
			hint.Text = text
		end,
		-- PC = 두 줄(상태 위 · 안내 아래) / 폰 = 한 줄(상태 왼쪽 · 안내 오른쪽) - 폰은 상세 시트가 올라오면 본문이 106밖에 안 남아 한 줄을 아낀다.
		setLayout = function(phone)
			if phone then
				status.Size = UDim2.new(0, 190, 0, 18)
				hint.Position = UDim2.new(0, 226, 0, 4)
				hint.Size = UDim2.new(1, -240, 0, 18)
			else
				status.Size = UDim2.new(1, -42, 0, 18)
				hint.Position = UDim2.new(0, 14, 0, 22)
				hint.Size = UDim2.new(1, -28, 0, 18)
			end
		end,
	}
end

function GemHeader.createWeaponArt(parent, size)
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Size = UDim2.new(0, size, 0, size)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local glow = Instance.new("Frame")
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.new(0.5, 0, 0.5, 0)
	glow.Size = UDim2.new(0, size * 1.2, 0, size * 1.2)
	glow.BackgroundTransparency = 0.86
	glow.BackgroundColor3 = UIColors.textTertiary
	glow.ZIndex = 0
	glow.Parent = holder
	local glowCorner = Instance.new("UICorner")
	glowCorner.CornerRadius = UDim.new(1, 0)
	glowCorner.Parent = glow

	local art = Instance.new("Frame")
	art.BackgroundTransparency = 1
	art.Size = UDim2.new(1, 0, 1, 0)
	art.ZIndex = 2
	art.Parent = holder

	return {
		holder = holder,
		update = function(weaponGrade, classId)
			local visual = weaponGrade and ItemVisualData.gradeVisuals[weaponGrade]
			glow.BackgroundColor3 = (classId and UIColors.classAccent[classId]) or UIColors.textTertiary
			for _, child in ipairs(art:GetChildren()) do
				child:Destroy()
			end
			local iconColor = (visual and visual.rainbow) and Color3.new(1, 1, 1) or (visual and visual.color or UIColors.textPrimary)
			ItemIcons.weapon(art, size, iconColor)
		end,
	}
end

return GemHeader
