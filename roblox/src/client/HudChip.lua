-- 상단 정보 칩 공통 틀(16-2). `Claude outputs/hud-mockup.html`의 .chip을 옮긴다 - 골드·
-- 레벨·스테이지 세 칩이 전부 이 틀(반투명 패널 + 얇은 링 + 알약 모서리 + 내용 폭에 맞춰
-- 늘어나는 AutomaticSize)을 쓴다. GoldHud.client.lua/LevelHud.client.lua/StageUI.client.lua가
-- 각자 안쪽 내용(아이콘·텍스트)만 채운다 - 이 모듈은 틀만 만들고 값은 모른다.
--
-- 세 스크립트가 부모를 공유해야 해서(목업처럼 한 줄로 나란히 붙어야 한다) StageUI.client.lua가
-- 행(TopChipsRow) 컨테이너를 만들고 Gold·LevelHud는 WaitForChild로 그 행을 찾아 자기 칩을
-- 끼워 넣는다(AttackInput이 SkillSlots의 Row를 찾는 것과 같은 패턴).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local HudChip = {}

function HudChip.new(parent, layoutOrder)
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.LayoutOrder = layoutOrder
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.Size = UDim2.new(0, 0, 0, 34)
	chip.BackgroundColor3 = UIColors.panel
	chip.BackgroundTransparency = UIColors.panelTransparency
	chip.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = chip

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Rim"
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Thickness = 1
	stroke.Parent = chip

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 13)
	padding.PaddingRight = UDim.new(0, 13)
	padding.Parent = chip

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 7)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = chip

	return chip
end

return HudChip
