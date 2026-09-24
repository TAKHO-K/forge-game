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
-- 20-2a: 대검 Q(관통돌진)·E(회전베기)가 실제로 붙었다 - 더미 쿨다운 데모는 지웠다.
-- 실제 쿨다운은 두 채널에서 온다: (1) SkillCastLocal(BindableEvent, 이 스크립트가 여기
-- 만들어 SkillInput.client.lua에 공개한다) - 키를 누른 순간 낙관적으로 링을 돌리기
-- 시작한다(지시 [1] "낙관적으로 먼저 돌아도 된다"). (2) SkillCastResult(RemoteEvent,
-- 서버 SkillServer.server.lua가 쏜다) - 서버가 거부했으면(쿨다운 등) 이 스크립트가 직접
-- 구독해 링을 정확한 서버 잔여 쿨다운으로 되돌린다(지시 [1] "서버 응답이 다르면 서버
-- 상태로 되돌려라"). 대시(SHIFT)는 여전히 스킬이 아니라 이동 기능이라 데모 쿨다운을
-- 그대로 남겨 둔다(범위 밖, 20-2a는 Q/E만 다룬다).

-- 21-2: (1) 대시(SHIFT) 슬롯이 실제 DashServer 쿨다운에 연결됐다 - 데모 쿨다운 제거.
-- (2) 슬롯이 실제 버튼(TextButton)이다 - 탭/클릭하면 SkillSlotTapped(BindableEvent)로
-- 슬롯 id를 쏘고, SkillInput/DashInput이 키 입력과 같은 함수로 처리한다. 버튼이라
-- 그 위의 탭은 gameProcessedEvent=true가 되어 AttackInput의 탭 공격(16-7)으로 새지
-- 않는다. (3) 18-2 [6]이 "구조만 준비"해 둔 플랫폼 분기를 실제로 켠다 - 터치 기기면
-- 스킬 5칸을 우측(점프 버튼 위)으로, 대시를 좌측(조이스틱 위)으로 갈라 놓아 두 손으로
-- 점프+대시를 동시에 누를 수 있게 한다(보스 공중 대시 회피의 전제, PRD 20.44 [3]).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local SkillIconData = require(ReplicatedStorage.Shared.data.SkillIconData)
local HudIcons = require(script.Parent.HudIcons)
local SkillTooltip = require(script.Parent.hud.SkillTooltip)

local skillCastResult = ReplicatedStorage:WaitForChild("SkillCastResult")
local dashResult = ReplicatedStorage:WaitForChild("DashResult")

local player = Players.LocalPlayer

local SLOT_SIZE = 54
local SLOT_GAP = 11 -- 5칸 사이 기본 간격
local DASH_GAP = 26 -- 대시를 스킬 5칸과 분리해 보이게 하는 큰 간격(지시 2)
local ROW_HEIGHT = 54 -- 공격 버튼이 없어진 뒤로는 슬롯 자신의 지름이 행에서 가장 큰 값이다.
local ICON_SIZE = 26

-- 19-2 [5]: Q/E 스킬 아이콘 - 슬롯(54px)의 약 70%. 꽉 채우면 테두리와 붙어 답답하다(지시).
local SKILL_ICON_SIZE = math.floor(SLOT_SIZE * 0.7)
-- 아이콘은 원래색을 거의 유지한다(ImageColor3로 살짝만 낮춘다) - 쿨다운 중에만 30% 밝기로
-- 어둡게 덮는다(지시 그대로).
local SKILL_ICON_READY_COLOR = Color3.fromRGB(230, 230, 230)
local SKILL_ICON_COOLDOWN_COLOR = Color3.fromRGB(76, 76, 76)

local CENTRAL_ROW_NAME = "CentralRow"

-- 경험치바(ExpBar.client.lua, 높이15) 위에 16px 여백을 두고 행을 앉힌다.
local ROW_BOTTOM_OFFSET = 15 + 16

-- 쿨다운 중 슬롯을 덮는 어둡기(지시 4 "쿨다운 중: 전체를 어둡게 덮고 링만 밝게") - 색
-- 자체가 아니라 튜닝값이라 UIColors가 아니라 이 파일 로컬 상수로 둔다(9-5 개정의 스택
-- 오프셋과 같은 전례).
local COOLDOWN_OVERLAY_TRANSPARENCY = 0.55
local READY_FLASH_TWEEN = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local SLOTS = {
	{ id = "q", key = "Q", skillIcon = true },
	{ id = "e", key = "E", skillIcon = true },
	{ id = "locked1", locked = true },
	{ id = "locked2", locked = true },
	{ id = "locked3", locked = true },
}

-- 18-2 [6]: 모바일은 좌하단 조이스틱·우하단 점프 버튼이 기본이라 중앙 하단 배치가 양손
-- 엄지 어느 쪽으로도 닿기 애매하다 - PC는 이 좌표(중앙 하단) 그대로, 터치 기기는 아래
-- TOUCH_* 좌표로 분기한다(21-2 [3]에서 실제로 켰다).
local ROW_ANCHOR_POINT = Vector2.new(0.5, 1)
local ROW_POSITION = UDim2.new(0.5, 0, 1, -ROW_BOTTOM_OFFSET)

-- 터치 레이아웃(21-2 [3]). 로블록스 기본 터치 컨트롤(PlayerModule ControlModule.TouchJump)의
-- 점프 버튼 기하를 그대로 재계산한다 - 화면 짧은 변이 500px 이하면 "작은 화면"(버튼 70px,
-- 우하단에서 x -(70×1.5−10)=−95, y −(70+20)=−90), 아니면 큰 화면(120px, x −170, y
-- −120×1.75=−210). 스킬 5칸은 그 점프 버튼 "위"에 우측 정렬로 앉히고(오른손 엄지 - 점프와
-- 같은 손, 점프 중 스킬은 어차피 19-2가 착지 버퍼로 미룬다), 대시는 좌측(조이스틱 위,
-- 왼손 엄지)에 따로 둔다 - 점프(오른손)+대시(왼손)를 동시에 누를 수 있어야 보스 공중
-- 대시 회피가 성립한다(지시). 조이스틱은 동적(DynamicThumbstick)이라 좌하단 터치 지점에
-- 생기므로, 대시 버튼은 그 영역 위쪽 가장자리에 두고 이 ScreenGui의 DisplayOrder를
-- TouchGui(기본 0)보다 높게 잡아 버튼 위 터치가 조이스틱으로 안 새게 한다.
local TOUCH_EDGE_MARGIN = 16
local TOUCH_SMALL_SCREEN_MAX_AXIS = 500
local TOUCH_DASH_LEFT = 24

local function touchJumpGeometry()
	local viewport = workspace.CurrentCamera.ViewportSize
	local isSmall = math.min(viewport.X, viewport.Y) <= TOUCH_SMALL_SCREEN_MAX_AXIS
	local size = isSmall and 70 or 120
	local right = size * 1.5 - 10
	local bottom = isSmall and (size + 20) or (size * 1.75)
	return { size = size, right = right, bottom = bottom, isSmall = isSmall }
end

-- Studio는 TouchEnabled=false라 실제 터치 배치를 볼 수 없다 - Studio 한정으로 LocalPlayer
-- Attribute ForceTouchLayout=true면 터치 레이아웃을 강제하고, 점프 버튼이 놓일 자리에
-- 모의 원(JumpMock)을 그려 겹침을 눈으로 확인한다(에뮬레이션 - 실제 TouchGui가 아니다).
local function isTouchLayout()
	if UserInputService.TouchEnabled then
		return true
	end
	return RunService:IsStudio() and player:GetAttribute("ForceTouchLayout") == true
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SkillSlotsGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5 -- TouchGui(0)보다 위, UIManager 창(100+)보다 아래.
screenGui.Parent = player:WaitForChild("PlayerGui")

-- 슬롯 탭/클릭 신호(21-2) - SkillInput.client.lua(q/e)·DashInput.client.lua(dash)가 구독한다.
-- SkillCastLocal과 같은 "잘 알려진 자리" 계약.
local slotTapped = Instance.new("BindableEvent")
slotTapped.Name = "SkillSlotTapped"
slotTapped.Parent = screenGui

-- SkillInput.client.lua가 WaitForChild로 찾는 로컬 전용 신호(20-2a) - ComboPipsAnchor
-- (AttackInput.client.lua)와 같은 "잘 알려진 자리" 계약 패턴. RemoteEvent가 아니라
-- BindableEvent다 - 같은 클라 안 두 LocalScript끼리만 오가고 네트워크를 안 탄다(그래서
-- "낙관적"이라는 말이 성립한다 - 왕복 지연이 없다).
local skillCastLocal = Instance.new("BindableEvent")
skillCastLocal.Name = "SkillCastLocal"
skillCastLocal.Parent = screenGui

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
	-- 21-2: 정상 슬롯은 TextButton(탭/클릭 = 시전 요청, 그 위 터치가 탭 공격으로 안 샌다).
	-- 잠긴 슬롯은 Frame이지만 Active=true로 둬 역시 입력을 삼킨다(잠긴 칸을 눌렀다고
	-- 뒤의 몬스터를 때리면 안 된다).
	local slot
	if def.locked then
		slot = Instance.new("Frame")
		slot.Active = true
	else
		slot = Instance.new("TextButton")
		slot.Text = ""
		slot.AutoButtonColor = false
		if def.skillIcon then
			-- P3b D: Q · E 칸 = 툴팁(PC 마우스 올림 · 폰 길게 누름). 짧게 누름 · 클릭은 기존처럼 시전 - 길게 누른 뒤 뗀 것은 시전하지 않는다(SkillTooltip.attach).
			SkillTooltip.attach(slot, def.id, function()
				slotTapped:Fire(def.id)
			end, isTouchLayout)
		else
			slot.Activated:Connect(function()
				slotTapped:Fire(def.id)
			end)
		end
	end
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

	local innerHighlightStroke
	if not def.locked then
		-- 안쪽 밝은 하이라이트선 - UIStroke는 슬롯당 하나뿐이라(공격 버튼 outerRing과 같은
		-- 이유) 2px 안쪽에 별도 프레임을 겹쳐 둘째 링을 만든다. 이 두 겹이 금속 두께감을 낸다.
		-- 19-2 [5]: Q/E 슬롯은 이 선을 나중에(refreshClassIcons) 직업색으로 갈아 끼운다 -
		-- 그래서 스트로크 자체를 handle로 밖에 내보낸다.
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

		innerHighlightStroke = Instance.new("UIStroke")
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

	local iconImage
	if def.locked then
		HudIcons.lock(iconHolder, ICON_SIZE)
	elseif def.skillIcon then
		-- 19-2 [5]: 실제 아이콘은 아직 모른다(직업에 따라 갈린다) - refreshClassIcons가
		-- Image를 채운다. ScaleType Fit으로 512×512 원본 비율이 안 깨지게 한다.
		iconHolder.Size = UDim2.new(0, SKILL_ICON_SIZE, 0, SKILL_ICON_SIZE)
		iconImage = Instance.new("ImageLabel")
		iconImage.Name = "SkillIcon"
		iconImage.BackgroundTransparency = 1
		iconImage.Size = UDim2.new(1, 0, 1, 0)
		iconImage.ScaleType = Enum.ScaleType.Fit
		iconImage.ImageColor3 = SKILL_ICON_READY_COLOR
		iconImage.Parent = iconHolder
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

	local keyPill
	if def.key then
		-- 키 라벨 알약 - 슬롯 바깥 아래로 살짝 겹쳐 나온다. 잠긴 칸엔 만들지 않는다(지시 2 -
		-- 무엇이 들어갈지 미정인데 키를 박으면 나중에 유저가 혼란스럽다). 터치 레이아웃에선
		-- 숨긴다(키보드가 없는데 "Q"가 붙어 있으면 거짓 안내다 - 아래 applyLayout).
		keyPill = Instance.new("TextLabel")
		keyPill.Name = "KeyPill"
		keyPill.AnchorPoint = Vector2.new(0.5, 0)
		keyPill.Position = UDim2.new(0.5, 0, 1, 2)
		keyPill.AutomaticSize = Enum.AutomaticSize.X
		keyPill.Size = UDim2.new(0, 0, 0, 16)
		keyPill.BackgroundColor3 = UIColors.panel
		keyPill.BackgroundTransparency = 0
		keyPill.Font = Enum.Font.GothamBold
		keyPill.TextSize = 12 -- S13b: 실효 12px 하한(COMMON.md §2). 알약 높이 15 -> 16, 아래 끝은 그대로
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
		iconImage = iconImage,
		innerHighlightStroke = innerHighlightStroke,
		keyPill = keyPill,
		slot = slot,
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

-- 대시 슬롯은 자기 홀더에 담는다 - PC 레이아웃에선 홀더가 row 안(스킬 5칸 오른쪽, DASH_GAP
-- 간격)에 있고, 터치 레이아웃에선 홀더째 좌측으로 옮긴다(applyLayout). 슬롯 자체는 한 번만
-- 만든다(쿨다운 링 상태가 재생성으로 끊기지 않게).
local dashHolder = Instance.new("Frame")
dashHolder.Name = "DashHolder"
dashHolder.LayoutOrder = 2
dashHolder.Size = UDim2.new(0, SLOT_SIZE, 0, ROW_HEIGHT)
dashHolder.BackgroundTransparency = 1
dashHolder.Parent = row

slotHandles["dash"] = buildSlot(dashHolder, 1, { id = "dash", key = "SHIFT", icon = "dash" })
slotHandles["dash"].slot.AnchorPoint = Vector2.new(0, 1)
slotHandles["dash"].slot.Position = UDim2.new(0, 0, 1, 0)

-- 에뮬레이션용 모의 점프 버튼(Studio + ForceTouchLayout에서만 생성).
local jumpMock = nil

local function applyLayout()
	local touch = isTouchLayout()
	for _, id in ipairs({ "q", "e", "dash" }) do
		local handle = slotHandles[id]
		if handle and handle.keyPill then
			handle.keyPill.Visible = not touch
		end
	end

	if not touch then
		row.AnchorPoint = ROW_ANCHOR_POINT
		row.Position = ROW_POSITION
		dashHolder.Parent = row
		if jumpMock then
			jumpMock:Destroy()
			jumpMock = nil
		end
		return
	end

	local jump = touchJumpGeometry()
	-- 스킬 5칸: 점프 버튼 바로 위, 우측 정렬. 점프 버튼 상단(-jump.bottom)에서 여백만큼 더 위.
	row.AnchorPoint = Vector2.new(1, 1)
	row.Position = UDim2.new(1, -TOUCH_EDGE_MARGIN, 1, -(jump.bottom + TOUCH_EDGE_MARGIN))
	-- 대시: 좌측, 조이스틱 영역 위쪽. 점프 버튼과 같은 높이대에 두어 왼손 엄지가 조이스틱에서
	-- 살짝 올라가면 닿는 자리다.
	dashHolder.Parent = screenGui
	dashHolder.AnchorPoint = Vector2.new(0, 1)
	dashHolder.Position = UDim2.new(0, TOUCH_DASH_LEFT, 1, -(jump.bottom + TOUCH_EDGE_MARGIN))

	if RunService:IsStudio() and not UserInputService.TouchEnabled and not jumpMock then
		jumpMock = Instance.new("Frame")
		jumpMock.Name = "JumpMock"
		jumpMock.AnchorPoint = Vector2.new(1, 1)
		jumpMock.Size = UDim2.new(0, jump.size, 0, jump.size)
		jumpMock.Position = UDim2.new(1, -jump.right + jump.size, 1, -jump.bottom + jump.size)
		jumpMock.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		jumpMock.BackgroundTransparency = 0.6
		jumpMock.Parent = screenGui
		local mockCorner = Instance.new("UICorner")
		mockCorner.CornerRadius = UDim.new(1, 0)
		mockCorner.Parent = jumpMock
		local mockLabel = Instance.new("TextLabel")
		mockLabel.BackgroundTransparency = 1
		mockLabel.Size = UDim2.new(1, 0, 1, 0)
		mockLabel.Font = Enum.Font.GothamBold
		mockLabel.TextSize = 12
		mockLabel.TextColor3 = Color3.new(0, 0, 0)
		mockLabel.Text = "JUMP\n(모의)"
		mockLabel.Parent = jumpMock
	end
end

applyLayout()
player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(applyLayout)
screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if isTouchLayout() then
		applyLayout()
	end
end)

-- 19-2 [5]: 직업 전환 시 Q/E 아이콘·테두리색을 갱신한다(WeaponVisual.refresh와 같은
-- ClassId Attribute 갱신 패턴). 직업을 안 골랐으면(빈 classId) 손대지 않는다 - 이전
-- 직업의 아이콘이 남아있는 게 아니라, 아직 아무 것도 못 채운 초기 상태일 뿐이다.
local function refreshClassIcons()
	local classId = player:GetAttribute("ClassId")
	local iconSet = classId and classId ~= "" and SkillIconData[classId]
	if not iconSet then
		return
	end
	local accentColor = UIColors.classAccent[classId]
	for _, slotId in ipairs({ "q", "e" }) do
		local handle = slotHandles[slotId]
		handle.iconImage.Image = iconSet[slotId]
		if accentColor then
			handle.innerHighlightStroke.Color = accentColor
		end
	end
end

player:GetAttributeChangedSignal("ClassId"):Connect(refreshClassIcons)
refreshClassIcons()

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
		if handle.iconImage then
			handle.iconImage.ImageColor3 = SKILL_ICON_COOLDOWN_COLOR
		end
	else
		handle.updateRing(0)
		handle.label.Text = ""
		handle.overlay.BackgroundTransparency = 1
		if handle.iconImage then
			handle.iconImage.ImageColor3 = SKILL_ICON_READY_COLOR
		end
		if handle.wasCooling then
			handle.readyGlow.Transparency = 0.05
			TweenService:Create(handle.readyGlow, READY_FLASH_TWEEN, { Transparency = 0.78 }):Play()
		else
			handle.readyGlow.Transparency = 0.78
		end
	end

	handle.wasCooling = isCooling
end

-- 실제 Q/E/대시 쿨다운(20-2a, 21-2에서 대시 합류 - 데모 쿨다운은 제거) - [slotId(소문자)] =
-- { startTick, totalSeconds } 또는 nil(대기 없음). SkillInput/DashInput은 이 상태를 직접 못
-- 건드린다 - 아래 구독(로컬 낙관적 신호 + 서버 결과)이 유일한 갱신 경로다.
local activeCooldown = {}

local function startCooldown(slotId, totalSeconds)
	activeCooldown[slotId] = { startTick = os.clock(), totalSeconds = totalSeconds }
end

local function driveCooldownLoop(slotId)
	task.spawn(function()
		while true do
			local state = activeCooldown[slotId]
			if state then
				local remaining = state.totalSeconds - (os.clock() - state.startTick)
				if remaining <= 0 then
					setCooldown(slotId, 0, state.totalSeconds)
					activeCooldown[slotId] = nil
				else
					setCooldown(slotId, remaining, state.totalSeconds)
				end
			end
			task.wait()
		end
	end)
end

driveCooldownLoop("q")
driveCooldownLoop("e")
driveCooldownLoop("dash")

-- 낙관적 시작(지시 [1] "클라 UI는 낙관적으로 먼저 돌아도 된다") - SkillInput.client.lua가
-- 키를 누른 그 순간(네트워크 왕복 전) 이 BindableEvent를 쏜다.
skillCastLocal.Event:Connect(function(slot, cooldownSeconds)
	startCooldown(slot:lower(), cooldownSeconds)
end)

-- 서버 진실(지시 [1] "서버 응답이 다르면 서버 상태로 되돌려라"). ok=true면 서버가 확정한
-- cooldownSeconds로 다시 맞춘다 - "dash"(Q)·"channelStart"(E)에만 cooldownSeconds가
-- 실려 온다("tick"은 없다 - 채널링 중 매 틱마다 링이 리셋되는 버그를 피한다). ok=false면
-- (쿨다운 중 요청 등 드문 경합) 로컬 낙관적 표시를 지운다.
local function applyServerResult(slotId, data)
	if not data.ok then
		activeCooldown[slotId] = nil
		setCooldown(slotId, 0, 0)
		return
	end
	if data.cooldownSeconds then
		startCooldown(slotId, data.cooldownSeconds)
	end
end

skillCastResult.OnClientEvent:Connect(function(slot, data)
	applyServerResult(slot:lower(), data)
end)

-- 대시(21-2) - DashServer의 DashResult가 Q/E의 SkillCastResult와 같은 모양이라 같은 함수.
dashResult.OnClientEvent:Connect(function(data)
	applyServerResult("dash", data)
end)
