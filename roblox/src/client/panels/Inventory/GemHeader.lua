-- 보석 탭 맨 위 두 줄(S20c) + PC 무기 그림 장식. GemTab.lua(800줄 한도)에서 분리.
--   GemHeader.createStatus(parent, hooks) -> { paint(used), setHint(text), setLayout(phone), height(), isUsed() }   hooks.onLocate() = 안내 줄을 누를 때(위치 안내)
--     첫 줄 = 변환 · 리롤 안내 줄(S20e - 보석상인을 써 본 적이 없으면 눈에 띄는 [위치 안내] 버튼 · 써 본 뒤에는 작은 회색 한 줄 + ? 도움말) · 둘째 줄 = 상황별 안내 한 줄.
--   GemHeader.createWeaponArt(parent, size) -> { holder, update(weaponGradeId, classId) }
--     확대한 무기 실루엣(홈은 이제 여기 붙지 않는다 - 무기 에셋은 임시, F5에서 Socket Attachment로 교체) + 직업색 발광(스킬 슬롯이 이미 쓰는 classAccent 재사용 - 새 색 없음).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local ItemIcons = require(script.Parent.Parent.Parent.ItemIcons)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local HelpToggle = require(script.Parent.Parent.Parent.ui.kit.HelpToggle)

local GemHeader = {}

function GemHeader.createStatus(parent, hooks)
	-- 안내 줄(S20e): 변환 · 리롤은 보석상인에게서만 된다는 것을 알린다. 아직 보석상인을 써 본 적이 없으면(hints.gemMerchantUsed = false) 줄 전체가 [위치 안내] 버튼으로 눈에 띄고,
	-- 써 본 뒤에는 작은 회색 한 줄 + ? 도움말로 줄어든다. 예전의 "강화대 근처에서 장착 가능" 상태 줄은 없다(장착은 어디서나 된다).
	local guide = Instance.new("TextButton")
	guide.Name = "GuideLine"
	guide.AutoButtonColor = false
	guide.Font = Enum.Font.GothamBold
	guide.TextSize = Theme.textSize("caption")
	guide.TextXAlignment = Enum.TextXAlignment.Left
	guide.TextTruncate = Enum.TextTruncate.AtEnd
	guide.Parent = parent
	local guideCorner = Instance.new("UICorner")
	guideCorner.CornerRadius = UDim.new(0, 6)
	guideCorner.Parent = guide
	local guidePad = Instance.new("UIPadding")
	guidePad.PaddingLeft = UDim.new(0, 10)
	guidePad.PaddingRight = UDim.new(0, 10)
	guidePad.Parent = guide
	local guideStroke = Instance.new("UIStroke")
	guideStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	guideStroke.Parent = guide
	guide.Activated:Connect(function()
		if hooks and hooks.onLocate then
			hooks.onLocate()
		end
	end)

	-- 써 본 뒤의 작은 회색 줄은 누르는 곳이 아니라 글일 뿐이다(버튼이면 폰 터치 44 규칙에 걸린다) - 눈에 띄는 안내 줄(GuideLine 버튼)과 따로 둔다.
	local small = Instance.new("TextLabel")
	small.Name = "GuideLineSmall"
	small.BackgroundTransparency = 1
	small.Font = Enum.Font.Gotham
	small.TextSize = Theme.textSize("caption")
	small.TextXAlignment = Enum.TextXAlignment.Left
	small.TextYAlignment = Enum.TextYAlignment.Center
	small.TextTruncate = Enum.TextTruncate.AtEnd
	small.TextColor3 = UIColors.textTertiary
	small.Text = ""
	small.Parent = parent

	local helpButton = HelpToggle.build({
		parent = parent,
		text = "변환 · 리롤(옵션 다시 굴리기)은 커뮤니티 센터의 보석상인에게서 할 수 있습니다. 환생의 제단 옆입니다.\n보석 장착 · 교체는 어디서나 됩니다.",
		position = UDim2.new(0, 0, 0, 0),
		panelSide = "right",
	}).root

	local hint = Instance.new("TextLabel")
	hint.Name = "GemHint"
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = Theme.textSize("caption")
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	hint.TextColor3 = UIColors.textSecondary
	hint.TextYAlignment = Enum.TextYAlignment.Center
	hint.Text = ""
	hint.Parent = parent

	local used, phone = false, false
	local usedText = "변환 · 리롤은 보석상인에게서"
	local unusedText = "변환 · 리롤은 커뮤니티 센터 보석상인에게서 - 눌러서 [위치 안내]"
	local self = {}

	-- 줄 높이: 안 써 봤다 = 눈에 띄는 버튼(폰은 터치 44) · 써 봤다 = 작은 회색 글 한 줄 + ? 도움말(폰은 ? 를 터치 44로 키우고 그 줄이 44라 안내 한 줄도 같은 줄에 놓는다).
	local function apply()
		if used then
			guide.Visible = false
			small.Visible = true
			small.Text = usedText
			helpButton.Visible = true
			if phone then
				small.Position = UDim2.new(0, 4, 0, 4)
				small.Size = UDim2.new(0, 190, 0, 44)
				helpButton.Size = UDim2.new(0, 44, 0, 44)
				helpButton.Position = UDim2.new(0, 4 + 190 + 22, 0, 4 + 22)
				hint.Position = UDim2.new(0, 4 + 190 + 44 + 8, 0, 4)
				hint.Size = UDim2.new(1, -(4 + 190 + 44 + 8 + 14), 0, 44)
			else
				small.Position = UDim2.new(0, 4, 0, 4)
				small.Size = UDim2.new(0, 250, 0, 18)
				helpButton.Size = UDim2.new(0, HelpToggle.size, 0, HelpToggle.size)
				helpButton.Position = UDim2.new(0, 250 + 20, 0, 13)
				hint.Position = UDim2.new(0, 14, 0, 22)
				hint.Size = UDim2.new(1, -28, 0, 18)
			end
		else
			local height = phone and 44 or 26
			guide.Visible = true
			small.Visible = false
			guide.BackgroundColor3 = UIColors.slot
			guide.BackgroundTransparency = UIColors.slotTransparency
			guide.TextColor3 = UIColors.gold
			guide.Text = unusedText
			guideStroke.Color = UIColors.gold
			guideStroke.Transparency = 0.2
			guide.Position = UDim2.new(0, 14, 0, 4)
			guide.Size = UDim2.new(1, -28, 0, height)
			helpButton.Visible = false
			hint.Position = UDim2.new(0, 14, 0, 4 + height + 4)
			hint.Size = UDim2.new(1, -28, 0, 18)
		end
	end

	-- 안내 블록(안내 줄 + 상황 안내 한 줄)의 전체 높이 - GemTab이 그 아래에 본문을 놓는다.
	function self.height()
		if used then
			return phone and 52 or 42
		end
		return 4 + (phone and 44 or 26) + 4 + 18 + 4
	end
	function self.paint(usedNow)
		if used ~= usedNow then
			used = usedNow
			apply()
		end
	end
	function self.setHint(text)
		hint.Text = text
	end
	function self.setLayout(phoneNow)
		phone = phoneNow
		apply()
	end
	function self.isUsed()
		return used
	end
	apply()
	return self
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
