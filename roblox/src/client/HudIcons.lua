-- 전투 HUD 아이콘(16-2). `Claude outputs/hud-mockup.html`의 .ic-sword/.ic-spin/.ic-burst/
-- .ic-dash를 그대로 옮긴다 - 전부 이미지 없이 사각형(Frame)의 크기·회전·위치 조합이라
-- Roblox Frame.Rotation으로 1:1에 가깝게 옮길 수 있다(지시 3). AttackInput.client.lua와
-- SkillSlots.client.lua 둘 다 쓰므로 ModuleScript로 뺐다 - 이 폴더의 HitEffects.lua/
-- Projectiles.lua/WeaponVisual.lua와 같은 패턴(client 전용 공유 모듈, .client 접미사 없음).
--
-- 쿨다운 링(HudIcons.buildCooldownRing) - 목업은 CSS conic-gradient로 "12시부터 시계방향
-- 부채꼴이 걷힌다"를 표현하는데, Roblox UIGradient/UIStroke는 각도 기준 부분 투명도를
-- 지원하지 않아 진짜 conic-gradient를 만들 수 없다. 이미지 마스크(회전하는 원형 마스크
-- ImageLabel)로도 만들 수는 있지만, 이 프로젝트는 이미 "이미지 에셋 없이 도형으로 표현한다"
-- 원칙을 GoldHud(이모지 tofu 문제)에서부터 지켜왔다 - 그 원칙을 깨면서까지 매끄러운
-- conic을 만들 가치가 없다고 판단했다. 대신 스톱워치 눈금처럼 12개 조각(시계 숫자
-- 위치)을 놓고 경과한 만큼 하나씩 밝아지게 한다 - 매끄럽진 않지만 "각도 진행"이라는
-- 정보 자체는 정확히 전달되고, 이미지도 필요 없다. Q·E·대시는 18-2부터 더미 쿨다운으로
-- 이 링을 실제로 돌린다(SkillSlots.client.lua 참고) - 진짜 스킬은 아직 없다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local HudIcons = {}

local function newFrame(parent, size, anchorPoint, position, rotation, color)
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.AnchorPoint = anchorPoint
	frame.Position = position
	frame.Rotation = rotation or 0
	frame.BackgroundColor3 = color
	frame.Parent = parent
	return frame
end

local function round(frame, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = frame
	return corner
end

-- 칼 - 공격 버튼 아이콘(목업 30x30 기준, size로 다른 크기에도 비례 적용).
function HudIcons.sword(parent, size)
	local f = size / 30
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(0, size, 0, size)
	canvas.Parent = parent

	-- 날 - 위쪽 절반, 70% 지점을 축으로 45도 회전(CSS transform-origin:50% 70%와 동일).
	local blade = newFrame(canvas, UDim2.new(0, 5 * f, 0, 20 * f), Vector2.new(0.5, 0.7),
		UDim2.new(0, 15 * f, 0, 14 * f), 45, Color3.fromRGB(255, 154, 87))
	round(blade, 2 * f)
	local bladeGradient = Instance.new("UIGradient")
	bladeGradient.Color = ColorSequence.new(Color3.fromRGB(255, 227, 207), Color3.fromRGB(255, 154, 87))
	bladeGradient.Rotation = 90
	bladeGradient.Parent = blade

	-- 코등이 - 날 밑동을 가로지른다(자기 중심 축 회전).
	local guard = newFrame(canvas, UDim2.new(0, 20 * f, 0, 4 * f), Vector2.new(0.5, 0.5),
		UDim2.new(0, 15 * f, 0, 21 * f), 45, Color3.fromRGB(255, 199, 154))
	round(guard, 2 * f)

	-- 손잡이 - 코등이 아래, 자기 윗변을 축으로 회전(CSS transform-origin:50% 0).
	local grip = newFrame(canvas, UDim2.new(0, 4 * f, 0, 9 * f), Vector2.new(0.5, 0),
		UDim2.new(0, 15 * f, 0, 21 * f), 45, Color3.fromRGB(196, 115, 62))
	round(grip, 2 * f)

	return canvas
end

-- 대시 - 셋. 오른쪽을 가리키는 셰브런(">") 세 개를 왼쪽부터 옅게-짙게 이어붙여 "앞으로
-- 미끄러진다"는 잔상 느낌을 낸다(CSS의 border-triangle 화살표 대신 ">"을 이루는 짧은 막대
-- 두 개 조합 - Roblox엔 삼각형 primitive가 없어 가장 단순한 대체다).
function HudIcons.dash(parent, size, dim)
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(0, size, 0, size)
	canvas.Parent = parent

	local baseTransparency = dim and { 0.88, 0.8, 0.7 } or { 0.68, 0.38, 0.08 }
	local armSize = size * 0.16
	local spacing = size * 0.24
	local startX = size * 0.22
	local centerY = size / 2

	for i = 0, 2 do
		local cx = startX + i * spacing
		local transparency = baseTransparency[i + 1]
		local upperArm = newFrame(canvas, UDim2.new(0, armSize, 0, size * 0.06), Vector2.new(0, 0.5),
			UDim2.new(0, cx, 0, centerY), -40, UIColors.textPrimary)
		upperArm.BackgroundTransparency = transparency
		round(upperArm, size * 0.03)
		local lowerArm = newFrame(canvas, UDim2.new(0, armSize, 0, size * 0.06), Vector2.new(0, 0.5),
			UDim2.new(0, cx, 0, centerY), 40, UIColors.textPrimary)
		lowerArm.BackgroundTransparency = transparency
		round(lowerArm, size * 0.03)
	end

	return canvas
end

-- 자물쇠 - 잠긴 스킬 슬롯(18-2). Roblox엔 아치(반원) primitive가 없어 shackle을 곡선 대신
-- 각진 "⊓" 브라켓(세로 기둥 둘 + 가로대 하나, burst 아이콘과 같은 막대 조합 방식)으로 대체한다.
function HudIcons.lock(parent, size)
	local color = UIColors.lockedIcon
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(0, size, 0, size)
	canvas.Parent = parent

	local armThickness = size * 0.12
	local shackleWidth = size * 0.4
	local shackleHeight = size * 0.26
	local shackleTop = size * 0.14

	local leftArm = newFrame(canvas, UDim2.new(0, armThickness, 0, shackleHeight), Vector2.new(0.5, 0),
		UDim2.new(0.5, -shackleWidth / 2, 0, shackleTop), 0, color)
	round(leftArm, armThickness / 2)

	local rightArm = newFrame(canvas, UDim2.new(0, armThickness, 0, shackleHeight), Vector2.new(0.5, 0),
		UDim2.new(0.5, shackleWidth / 2, 0, shackleTop), 0, color)
	round(rightArm, armThickness / 2)

	local topArm = newFrame(canvas, UDim2.new(0, shackleWidth + armThickness, 0, armThickness), Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0, shackleTop), 0, color)
	round(topArm, armThickness / 2)

	local bodyWidth, bodyHeight = size * 0.6, size * 0.42
	local body = newFrame(canvas, UDim2.new(0, bodyWidth, 0, bodyHeight), Vector2.new(0.5, 0),
		UDim2.new(0.5, 0, 0, shackleTop + shackleHeight - armThickness * 0.5), 0, color)
	round(body, size * 0.08)

	return canvas
end

-- 톱니(설정 버튼) - burst 아이콘과 같은 방사형 막대 6개 + 중앙 원. 실제 톱니바퀴 곡선은
-- 아니지만 "설정"으로 읽히는 최소 형태(지시 5 - 이번엔 창 내용 없이 자리만).
function HudIcons.gear(parent, size, color)
	local iconColor = color or UIColors.textSecondary
	local canvas = Instance.new("Frame")
	canvas.BackgroundTransparency = 1
	canvas.Size = UDim2.new(0, size, 0, size)
	canvas.Parent = parent

	local center = size / 2
	for i = 0, 5 do
		local angle = i * 60
		local tooth = newFrame(canvas, UDim2.new(0, size * 0.16, 0, size * 0.5), Vector2.new(0.5, 0),
			UDim2.new(0, center, 0, center), angle, iconColor)
		tooth.ZIndex = 1
		round(tooth, size * 0.03)
	end

	local hubRadius = size * 0.22
	local hub = newFrame(canvas, UDim2.new(0, hubRadius * 2, 0, hubRadius * 2), Vector2.new(0.5, 0.5),
		UDim2.new(0, center, 0, center), 0, iconColor)
	hub.ZIndex = 2
	round(hub, hubRadius)

	return canvas
end

-- 쿨다운 링 - 위 모듈 설명 참고("스톱워치 눈금" 방식). diameter는 슬롯 지름과 같게 준다.
-- 반환값은 update(remainingRatio) 함수 하나 - remainingRatio=1이면 전부 어둡게(막 씀),
-- 0이면 전부 밝게(사용 가능). SkillSlots.client.lua의 setCooldown이 이 update를 부른다.
function HudIcons.buildCooldownRing(parent, diameter)
	local TICK_COUNT = 12
	local center = diameter / 2
	local radius = diameter / 2 - 5
	local ticks = {}

	for i = 0, TICK_COUNT - 1 do
		local angleDeg = i * (360 / TICK_COUNT)
		local angle = math.rad(angleDeg)
		local x = center + radius * math.sin(angle)
		local y = center - radius * math.cos(angle)
		local tick = newFrame(parent, UDim2.new(0, 3, 0, 6), Vector2.new(0.5, 0.5),
			UDim2.new(0, x, 0, y), angleDeg, UIColors.rim)
		round(tick, 2)
		ticks[i + 1] = tick
	end

	local function update(remainingRatio)
		-- remainingRatio<=0(쿨다운 없음)이면 링 자체를 완전히 숨긴다 - 목업도 "사용 가능"
		-- 슬롯(E)엔 링이 아예 없다. 이 분기가 없으면 elapsedCount가 TICK_COUNT까지 차서
		-- "전부 밝은 원"이 항상 떠 있는 상태가 되어 버린다(첫 구현에서 실제로 이렇게 렌더된
		-- 걸 Studio 스크린샷으로 확인하고 고쳤다).
		if remainingRatio <= 0 then
			for _, tick in ipairs(ticks) do
				tick.BackgroundTransparency = 1
			end
			return
		end

		local elapsedCount = math.floor((1 - math.clamp(remainingRatio, 0, 1)) * TICK_COUNT + 0.5)
		for index, tick in ipairs(ticks) do
			if index <= elapsedCount then
				tick.BackgroundColor3 = UIColors.rim
				tick.BackgroundTransparency = UIColors.rimTransparency
			else
				tick.BackgroundColor3 = Color3.new(0, 0, 0)
				tick.BackgroundTransparency = 0.15
			end
		end
	end

	update(0)
	return update
end

return HudIcons
