-- 스킬 슬롯(16-1 [2] 신설 → 16-2 목업 재정렬 → 18-2 재배치). 16-7로 클릭·탭 조준 공격이
-- 유일한 기본공격 수단이 되면서 중앙의 공격 버튼이 역할을 잃었다 - AttackInput.client.lua가
-- 그 버튼을 완전히 없앴고, 이 스크립트가 소유하던 CentralRow는 더 이상 두 파일이 공유하는
-- 계약이 아니다(이 파일 안에서만 쓰는 컨테이너로 되돌아갔다).
--
-- 18-2: 롤·로스트아크·디아블로4식 스킬바를 참고해 5칸으로 늘린다. 실제로 동작하는 건
-- Q·E 두 칸뿐이고 나머지 3칸은 잠김(자물쇠 아이콘, 채도 없는 어두운 톤, 발광 없음) -
-- 특수 스킬·무기 스킬 후보가 있으나 미정이라 자리만 잡는다. 대시는 스킬이 아니라 이동
-- 기능이라 5칸과 한 칸 띄워 오른쪽에 따로 둔다(DASH_GAP).
--
-- 대시·Q·E 전부 실제 스킬은 아직 없다(스킬 자체는 18-3). 쿨다운 링·오버레이·번쩍임 UI가
-- 실제로 동작하는 걸 보여주기 위해 이 파일 하단에서 더미 쿨다운을 반복 재생한다 -
-- 스킬 시스템이 붙으면 이 데모 호출만 지우고 setCooldown을 실제 스킬 쿨다운에 연결하면 된다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudIcons = require(script.Parent.HudIcons)

local SLOT_SIZE = 54
local SLOT_GAP = 11 -- 5칸 사이 기본 간격
local DASH_GAP = 26 -- 대시를 스킬 5칸과 분리해 보이게 하는 큰 간격(지시 2)
local ROW_HEIGHT = 54 -- 공격 버튼이 없어진 뒤로는 슬롯 자신의 지름이 행에서 가장 큰 값이다.
local ICON_SIZE = 26

local CENTRAL_ROW_NAME = "CentralRow"

-- 경험치바(ExpBar.client.lua, 높이15) 위에 16px 여백을 두고 행을 앉힌다.
local ROW_BOTTOM_OFFSET = 15 + 16

-- 쿨다운 중 슬롯을 덮는 어둡기(지시 4 "쿨다운 중: 전체를 어둡게 덮고 링만 밝게") - 색
-- 자체가 아니라 튜닝값이라 UIColors가 아니라 이 파일 로컬 상수로 둔다(9-5 개정의 스택
-- 오프셋과 같은 전례).
local COOLDOWN_OVERLAY_TRANSPARENCY = 0.55
local READY_FLASH_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SLOTS = {
	{ id = "q", key = "Q", icon = "spin" },
	{ id = "e", key = "E", icon = "burst" },
	{ id = "locked1", locked = true },
	{ id = "locked2", locked = true },
	{ id = "locked3", locked = true },
}

-- 18-2 [6]: 모바일은 좌하단 조이스틱·우하단 점프 버튼이 기본이라 중앙 하단 배치가 양손
-- 엄지 어느 쪽으로도 닿기 애매할 수 있다 - 실제 배치는 폰 실기로 보고 정한다(지시, 이번엔
-- 구조만 준비). 지금은 PC 기준으로 두되, 나중에 플랫폼 분기를 넣을 때 이 좌표 하나만
-- 바꾸면 되도록 상수로 뺀다.
local ROW_ANCHOR_POINT = Vector2.new(0.5, 1)
local ROW_POSITION = UDim2.new(0.5, 0, 1, -ROW_BOTTOM_OFFSET)

local player = Players.LocalPlayer

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillSlotsGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local row = Instance.new("Frame")
row.Name = CENTRAL_ROW_NAME
row.AnchorPoint = ROW_ANCHOR_POINT
row.Position = ROW_POSITION
row.AutomaticSize = Enum.AutomaticSize.X
row.Size = UDim2.new(0, 0, 0, ROW_HEIGHT)
row.BackgroundTransparency = 1
row.Parent = screenGui

local rowLayout = Instance.new("UIListLayout")
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
rowLayout.Padding = UDim.new(0, DASH_GAP)
rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowLayout.Parent = row

-- 슬롯 하나(잠김·정상 공용). 정상 슬롯만 그라디언트·안쪽 하이라이트·발광·쿨다운 UI를
-- 받는다 - 잠긴 슬롯은 그 무엇도 없이 어둡고 채도 없는 판만 남는다(지시 4).
local function buildSlot(parent, layoutOrder, def)
	local slot = Instance.new("Frame")
	slot.Name = "Slot_" .. def.id
	slot.LayoutOrder = layoutOrder
	slot.Size = UDim2.new(0, SLOT_SIZE, 0, SLOT_SIZE)
	slot.BackgroundColor3 = def.locked and UIColors.lockedBg or UIColors.metalBottom
	slot.ClipsDescendants = false
	slot.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4) -- 둥글게 하되 약하게 - 금속은 무르지 않다(지시 4).
	corner.Parent = slot

	if not def.locked then
		-- 빛이 위에서 온다는 암시 - 아주 미세하게(지시 4).
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(UIColors.metalTop, UIColors.metalBottom)
		gradient.Rotation = 90
		gradient.Parent = slot
	end

	-- 바깥쪽 어두운 금속 테두리.
	local outerStroke = Instance.new("UIStroke")
	outerStroke.Name = "OuterEdge"
	outerStroke.Color = def.locked and UIColors.lockedRim or UIColors.metalOuter
	outerStroke.Transparency = def.locked and 0.5 or 0
	outerStroke.Thickness = 1.5
	outerStroke.Parent = slot

	if not def.locked then
		-- 안쪽 밝은 하이라이트선 - UIStroke는 슬롯당 하나뿐이라(공격 버튼 outerRing과 같은
		-- 이유) 2px 안쪽에 별도 프레임을 겹쳐 둘째 링을 만든다. 이 두 겹이 금속 두께감을 낸다.
		local innerHighlight = Instance.new("Frame")
		innerHighlight.Name = "InnerHighlight"
		innerHighlight.BackgroundTransparency = 1
		innerHighlight.AnchorPoint = Vector2.new(0.5, 0.5)
		innerHighlight.Position = UDim2.new(0.5, 0, 0.5, 0)
		innerHighlight.Size = UDim2.new(1, -4, 1, -4)
		innerHighlight.Parent = slot

		local innerHighlightCorner = Instance.new("UICorner")
		innerHighlightCorner.CornerRadius = UDim.new(0, 3)
		innerHighlightCorner.Parent = innerHighlight

		local innerHighlightStroke = Instance.new("UIStroke")
		innerHighlightStroke.Color = UIColors.metalInner
		innerHighlightStroke.Transparency = UIColors.metalInnerTransparency
		innerHighlightStroke.Thickness = 1
		innerHighlightStroke.Parent = innerHighlight
	end

	local iconHolder = Instance.new("Frame")
	iconHolder.BackgroundTransparency = 1
	iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	iconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
	iconHolder.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
	iconHolder.Parent = slot

	if def.locked then
		HudIcons.lock(iconHolder, ICON_SIZE)
	else
		HudIcons[def.icon](iconHolder, ICON_SIZE, true)
	end

	local readyGlow
	local overlay
	if not def.locked then
		-- 준비된 스킬 - 테두리에 은은한 발광(지시 4, ember 강조 유지). 쿨다운 중엔 숨긴다.
		readyGlow = Instance.new("UIStroke")
		readyGlow.Name = "ReadyGlow"
		readyGlow.Color = UIColors.ember
		readyGlow.Transparency = 0.78
		readyGlow.Thickness = 1.5
		readyGlow.Parent = slot

		-- 쿨다운 중: 전체를 어둡게 덮는다. iconHolder 다음, 쿨다운 링보다 먼저 만들어야
		-- 아이콘은 덮고 링은 덮지 않는다(같은 ZIndex에서 나중에 만든 것이 위에 그려진다).
		overlay = Instance.new("Frame")
		overlay.Name = "CooldownOverlay"
		overlay.BackgroundColor3 = Color3.new(0, 0, 0)
		overlay.BackgroundTransparency = 1
		overlay.Size = UDim2.new(1, 0, 1, 0)
		overlay.Parent = slot

		local overlayCorner = Instance.new("UICorner")
		overlayCorner.CornerRadius = UDim.new(0, 4)
		overlayCorner.Parent = overlay
	end

	if def.key then
		-- 키 라벨 알약 - 슬롯 바깥 아래로 살짝 겹쳐 나온다. 잠긴 칸엔 만들지 않는다(지시 2 -
		-- 무엇이 들어갈지 미정인데 키를 박으면 나중에 유저가 혼란스럽다).
		local keyPill = Instance.new("TextLabel")
		keyPill.Name = "KeyPill"
		keyPill.AnchorPoint = Vector2.new(0.5, 0)
		keyPill.Position = UDim2.new(0.5, 0, 1, 3)
		keyPill.AutomaticSize = Enum.AutomaticSize.X
		keyPill.Size = UDim2.new(0, 0, 0, 15)
		keyPill.BackgroundColor3 = UIColors.panel
		keyPill.BackgroundTransparency = 0
		keyPill.Font = Enum.Font.GothamBold
		keyPill.TextSize = 10
		keyPill.TextColor3 = UIColors.textTertiary
		keyPill.Text = def.key
		keyPill.ZIndex = 2
		keyPill.Parent = slot

		local keyPillPadding = Instance.new("UIPadding")
		keyPillPadding.PaddingLeft = UDim.new(0, 5)
		keyPillPadding.PaddingRight = UDim.new(0, 5)
		keyPillPadding.Parent = keyPill

		local keyPillCorner = Instance.new("UICorner")
		keyPillCorner.CornerRadius = UDim.new(0, 4)
		keyPillCorner.Parent = keyPill

		local keyPillStroke = Instance.new("UIStroke")
		keyPillStroke.Color = UIColors.rim
		keyPillStroke.Transparency = UIColors.rimTransparency
		keyPillStroke.Thickness = 1
		keyPillStroke.Parent = keyPill
	end

	if def.locked then
		return nil
	end

	-- 쿨다운 링(스톱워치 눈금) - HudIcons.buildCooldownRing 재사용. 16-2에서 고친 "준비
	-- 완료인데 링이 밝게 남는" 버그 수정이 그 함수 안에 그대로 있다 - 여기서 새로 만들지 않는다.
	local updateRing = HudIcons.buildCooldownRing(slot, SLOT_SIZE)

	local cooldownLabel = Instance.new("TextLabel")
	cooldownLabel.Name = "CooldownLabel"
	cooldownLabel.BackgroundTransparency = 1
	cooldownLabel.Size = UDim2.new(1, 0, 1, 0)
	cooldownLabel.Font = Enum.Font.GothamBold
	cooldownLabel.TextSize = 18
	cooldownLabel.TextColor3 = UIColors.textPrimary
	cooldownLabel.Text = ""
	cooldownLabel.ZIndex = 3
	cooldownLabel.Parent = slot

	local cooldownLabelStroke = Instance.new("UIStroke")
	cooldownLabelStroke.Thickness = 1.5
	cooldownLabelStroke.Color = Color3.new(0, 0, 0)
	cooldownLabelStroke.Parent = cooldownLabel

	return {
		updateRing = updateRing,
		label = cooldownLabel,
		overlay = overlay,
		readyGlow = readyGlow,
		wasCooling = false,
	}
end

local slotHandles = {}

local skillGroup = Instance.new("Frame")
skillGroup.Name = "SkillGroup"
skillGroup.LayoutOrder = 1
skillGroup.AutomaticSize = Enum.AutomaticSize.X
skillGroup.Size = UDim2.new(0, 0, 0, ROW_HEIGHT)
skillGroup.BackgroundTransparency = 1
skillGroup.Parent = row

local skillGroupLayout = Instance.new("UIListLayout")
skillGroupLayout.FillDirection = Enum.FillDirection.Horizontal
skillGroupLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
skillGroupLayout.Padding = UDim.new(0, SLOT_GAP)
skillGroupLayout.SortOrder = Enum.SortOrder.LayoutOrder
skillGroupLayout.Parent = skillGroup

for i, def in ipairs(SLOTS) do
	slotHandles[def.id] = buildSlot(skillGroup, i, def)
end

slotHandles["dash"] = buildSlot(row, 2, { id = "dash", key = "SHIFT", icon = "dash" })

-- remainingSeconds<=0이면 완전히 걷힌 "사용 가능" 상태로 되돌린다. wasCooling이 참이었다가
-- 이번에 풀리는 순간(방금 완료된 순간)만 테두리를 한 번 밝게 번쩍인다(지시 3).
local function setCooldown(slotId, remainingSeconds, totalSeconds)
	local handle = slotHandles[slotId]
	if not handle then
		return
	end

	local isCooling = remainingSeconds > 0 and totalSeconds > 0

	if isCooling then
		handle.updateRing(remainingSeconds / totalSeconds)
		handle.label.Text = remainingSeconds < 1 and ("%.1f"):format(remainingSeconds)
			or ("%d"):format(math.ceil(remainingSeconds))
		handle.overlay.BackgroundTransparency = COOLDOWN_OVERLAY_TRANSPARENCY
		handle.readyGlow.Transparency = 1
	else
		handle.updateRing(0)
		handle.label.Text = ""
		handle.overlay.BackgroundTransparency = 1
		if handle.wasCooling then
			handle.readyGlow.Transparency = 0.05
			TweenService:Create(handle.readyGlow, READY_FLASH_TWEEN, { Transparency = 0.78 }):Play()
		else
			handle.readyGlow.Transparency = 0.78
		end
	end

	handle.wasCooling = isCooling
end

-- 더미 쿨다운 데모(지시 - "쿨다운 링이 도는 걸 확인할 수 있게") - 스킬 자체는 아직 없어서
-- 서로 다른 길이로 반복시켜 링·숫자·번쩍임을 눈으로 바로 검증할 수 있게 한다. 실제 스킬이
-- 붙으면 이 호출들을 지우고 setCooldown을 서버/클라이언트 쿨다운 값에 연결하면 된다.
local function runDemoCooldown(slotId, totalSeconds, gapSeconds)
	task.spawn(function()
		while true do
			local startTick = os.clock()
			while true do
				local remaining = totalSeconds - (os.clock() - startTick)
				if remaining <= 0 then
					setCooldown(slotId, 0, totalSeconds)
					break
				end
				setCooldown(slotId, remaining, totalSeconds)
				task.wait()
			end
			task.wait(gapSeconds)
		end
	end)
end

runDemoCooldown("q", 4, 2)
runDemoCooldown("e", 6, 1.5)
runDemoCooldown("dash", 8, 3)
