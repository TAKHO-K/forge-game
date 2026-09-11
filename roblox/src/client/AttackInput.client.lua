-- 공격 입력(버튼 하나, 모바일 탭 가능) + 서버 결과 수신. 사거리·대상·데미지 판정은
-- 전부 서버가 한다 - 여기는 클릭 신호를 보내고 서버가 알려준 결과를 그리기만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local HudIcons = require(script.Parent.HudIcons)
local WeaponVisual = require(script.Parent.WeaponVisual)
local HitEffects = require(script.Parent.HitEffects)
local Projectiles = require(script.Parent.Projectiles)

-- 원거리 클래스(활·힐러)는 판정 결과를 곧바로 보여주지 않는다 - 투사체가 도착하는
-- 순간까지 미룬다(아래 attackResult 핸들러 참고). 근접 두 클래스는 즉시 표시.
local RANGED_PROJECTILE_KIND = { bow = "arrow", healer = "orb" }

local attackRequest = ReplicatedStorage:WaitForChild("AttackRequest")
local attackResult = ReplicatedStorage:WaitForChild("AttackResult")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- 16-2: "플래시 게임 버튼 같다"는 피드백으로 만든 목업(Claude outputs/hud-mockup.html)의
-- .attack을 옮긴다. 배치도 바뀌었다 - 화면 우하단 단독 버튼이 아니라 SkillSlots.client.lua가
-- 만드는 중앙 하단 한 줄(Q·공격·E·대시)의 가운데 자리로 들어간다. 그 Row를 SkillSlots가
-- 먼저 만들어 두므로 WaitForChild로 찾는다(두 파일이 이름·순서를 계약처럼 공유 - SkillSlots.
-- client.lua 상단 주석 참고). 지름은 목업 값 92px 그대로 고정폭으로 쓴다 - SkillSlots가
-- 행 높이(ROW_HEIGHT=92)를 이 값과 같다고 가정하고 있어서, 여기서 반응형 스케일을 넣으면
-- 두 파일의 가정이 어긋난다(9-5의 "화면 비율로 키운다" 대신 목업처럼 고정값을 쓰기로
-- 바꾼 이유). 92px는 9-5의 최소 터치 타깃(88px) 기준을 이미 넘는다.
local skillSlotsGui = playerGui:WaitForChild("SkillSlotsGui")
local centralRow = skillSlotsGui:WaitForChild("CentralRow")

local ATTACK_DIAMETER = 92

local attackButton = Instance.new("TextButton")
attackButton.Name = "AttackButton"
attackButton.LayoutOrder = 2 -- SkillSlots.client.lua의 ATTACK_LAYOUT_ORDER와 맞춘 값.
attackButton.Size = UDim2.new(0, ATTACK_DIAMETER, 0, ATTACK_DIAMETER)
attackButton.Text = "" -- 16-2: 글자를 없앤다 - "공격" 텍스트가 있으면 UI 요소로 읽힌다.
attackButton.AutoButtonColor = false
-- 반투명(목업 --panel, transparency .28 근처) - 게임 화면이 버튼 너머로 비쳐야 한다.
attackButton.BackgroundColor3 = UIColors.panel
attackButton.BackgroundTransparency = UIColors.panelTransparency
attackButton.Parent = centralRow

local attackButtonCorner = Instance.new("UICorner")
attackButtonCorner.CornerRadius = UDim.new(1, 0)
attackButtonCorner.Parent = attackButton

-- 안쪽 온기(ember) 글로우 - CSS radial-gradient 대체. Roblox Frame엔 방사형 그라디언트가
-- 없어 ember색 반투명 원을 버튼보다 작게 겹쳐 "가운데가 은은하게 밝다"는 인상만 옮긴다.
local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.AnchorPoint = Vector2.new(0.5, 0.5)
glow.Position = UDim2.new(0.5, 0, 0.42, 0)
glow.Size = UDim2.new(0.82, 0, 0.82, 0)
glow.BackgroundColor3 = UIColors.ember
glow.BackgroundTransparency = 0.88
glow.BorderSizePixel = 0
glow.ZIndex = 0
glow.Parent = attackButton

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(1, 0)
glowCorner.Parent = glow

-- 굵은 흰 테두리 대신 얇은 두 겹 링(목업 .attack의 2px 메인 링 + ::before의 1px 바깥 보조
-- 링). Roblox UIStroke는 하나만 붙일 수 있어(안팎 이중 테두리 불가) 보조 링은 버튼보다
-- 살짝 큰 별도 프레임으로 만든다.
local mainRing = Instance.new("UIStroke")
mainRing.Thickness = 2
mainRing.Color = UIColors.ember
mainRing.Transparency = 0.38
mainRing.Parent = attackButton

local outerRing = Instance.new("Frame")
outerRing.Name = "OuterRing"
outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
outerRing.Position = UDim2.new(0.5, 0, 0.5, 0)
outerRing.Size = UDim2.new(1, 12, 1, 12)
outerRing.BackgroundTransparency = 1
outerRing.ZIndex = 0
outerRing.Parent = attackButton

local outerRingCorner = Instance.new("UICorner")
outerRingCorner.CornerRadius = UDim.new(1, 0)
outerRingCorner.Parent = outerRing

local outerRingStroke = Instance.new("UIStroke")
outerRingStroke.Thickness = 1
outerRingStroke.Color = UIColors.ember
outerRingStroke.Transparency = 0.82
outerRingStroke.Parent = outerRing

-- 칼 아이콘(HudIcons.sword) - 텍스트 대신 이 하나만 남는다.
local iconHolder = Instance.new("Frame")
iconHolder.BackgroundTransparency = 1
iconHolder.AnchorPoint = Vector2.new(0.5, 0.5)
iconHolder.Position = UDim2.new(0.5, 0, 0.5, 0)
iconHolder.Size = UDim2.new(0, 34, 0, 34)
iconHolder.ZIndex = 2
iconHolder.Parent = attackButton
HudIcons.sword(iconHolder, 34)

-- 눌림 반응 - 색이 아니라 스케일 0.93 + 글로우 강화(지시 2). UIScale로 버튼 전체를 줄이고,
-- 글로우·링의 Transparency를 낮춰(더 진하게) "눌렸다"는 확실한 반응을 준다.
local pressScale = Instance.new("UIScale")
pressScale.Scale = 1
pressScale.Parent = attackButton

local function setPressed(pressed)
	local scaleGoal = pressed and 0.93 or 1
	local glowGoal = pressed and 0.7 or 0.88
	local ringGoal = pressed and 0.15 or 0.38
	local outerRingGoal = pressed and 0.55 or 0.82
	local tweenInfo = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(pressScale, tweenInfo, { Scale = scaleGoal }):Play()
	TweenService:Create(glow, tweenInfo, { BackgroundTransparency = glowGoal }):Play()
	TweenService:Create(mainRing, tweenInfo, { Transparency = ringGoal }):Play()
	TweenService:Create(outerRingStroke, tweenInfo, { Transparency = outerRingGoal }):Play()
end

attackButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setPressed(true)
	end
end)

attackButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		setPressed(false)
	end
end)

-- 스윙 모션은 서버 확인 없이 여기서 바로 재생한다(지시 사항 - "모션은 클라이언트에서
-- 재생한다. 판정은 여전히 서버다. 둘을 섞지 마라"). 다만 버튼을 쿨다운보다 빨리 연타하면
-- (서버는 조용히 무시하는데) 모션만 계속 재생되면 실제 공격 속도보다 빨라 보여 오히려
-- 거짓 피드백이 된다 - 그래서 여기서도 같은 쿨다운을 직접 계산해 재생 여부를 건너뛴다
-- (서버 쿨다운과 별개의 클라이언트 판정 - 공격 자체를 막는 게 아니라 "모션을 또
-- 보여줄지"만 결정한다. attackRequest는 클라이언트 쿨다운과 무관하게 항상 보낸다 -
-- 헛스윙 판정은 여전히 서버 몫이다).
local lastSwingTick = 0

-- Activated는 마우스 클릭·터치 탭·게임패드를 전부 같은 이벤트로 받는다(모바일 대응).
attackButton.Activated:Connect(function()
	attackRequest:FireServer()

	local classId = player:GetAttribute("ClassId")
	if not classId or classId == "" then
		return
	end
	local cooldown = PlayerCombat.getAttackCooldown(classId)
	local now = os.clock()
	if now - lastSwingTick >= cooldown then
		lastSwingTick = now
		WeaponVisual.playSwing()
	end
end)

-- 몬스터별로 동시에 떠 있는 데미지 숫자 개수(9-5 개정, 9-3에서 미루기만 했던
-- 스택 오프셋). 약한 테이블 키라 몬스터가 사라지면(사망·리스폰) 항목도 같이
-- 수거된다 - 죽은 몬스터 참조를 붙들고 있을 이유가 없다.
local activeStacks = setmetatable({}, { __mode = "k" })

-- 치명타 크기 배율(PRD-forge-game.md 4.4 "크기 1.5배 + 굵게 + 튀어오르는 모션").
-- 색은 그대로 두고(같은 흰색 계열) 크기·폰트·모션만 바꿔 구분한다.
local CRIT_SIZE_SCALE = 1.5

local function showDamageNumber(monsterModel, damage, isCrit)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	-- 짧은 시간에 여러 대를 때리면 숫자가 겹쳐 안 보인다 - 이미 떠 있는 개수만큼
	-- 위로 밀어서 계단식으로 쌓는다.
	local stackIndex = activeStacks[monsterModel] or 0
	activeStacks[monsterModel] = stackIndex + 1

	local scale = isCrit and CRIT_SIZE_SCALE or 1
	local finalSize = UDim2.new(3 * scale, 0, 1 * scale, 0)

	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageNumberGui"
	gui.Size = finalSize
	gui.StudsOffset = Vector3.new(0, 2.6 + stackIndex * 0.9, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Text = NumberFormat.format(damage)
	label.TextColor3 = Color3.fromRGB(255, 220, 60)
	label.TextScaled = true
	label.Font = isCrit and Enum.Font.GothamBlack or Enum.Font.GothamMedium
	label.Parent = gui

	if isCrit then
		-- 튀어오르는 모션: 작게 시작해서 목표 크기로 튕기듯 커진다.
		gui.Size = UDim2.new(finalSize.X.Scale * 0.6, 0, finalSize.Y.Scale * 0.6, 0)
		TweenService:Create(
			gui,
			TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = finalSize }
		):Play()
	end

	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		gui:Destroy()
		activeStacks[monsterModel] = math.max((activeStacks[monsterModel] or 1) - 1, 0)
	end)
end

-- died가 추가된 이유는 AttackServer.server.lua의 attackResult:FireClient 주석 참고.
-- 죽었으면 피격 반응 대신 사망 연출을 재생한다(둘 다 재생하면 사망 직전 프레임에
-- Body/Head 색을 흰색으로 바꿨다가 곧바로 사망 연출이 그 색을 지워버려 부자연스럽다).
local function showResult(monsterModel, damage, isCrit, died)
	showDamageNumber(monsterModel, damage, isCrit)
	if not monsterModel then
		return
	end
	if died then
		HitEffects.playDeath(monsterModel)
	else
		HitEffects.playHit(monsterModel, isCrit)
	end
end

-- 활·힐러는 서버 판정 결과(이미 확정된 데미지·치명타·사망 여부)를 곧바로 보여주지
-- 않는다 - 활시위가 아직 안 당겨졌거나 화살이 아직 날아가는 중인데 데미지 숫자가
-- 먼저 뜨면 판정 시점과 화살 도달 시점이 어긋나 보인다(지시 사항). 서버는 이미
-- 즉시 판정했으므로(9-2 서버 권위), 여기서 하는 일은 "이미 정해진 결과를 언제
-- 보여줄지"를 투사체가 실제로 도착하는 순간으로 늦추는 것뿐 - 새로 판정하지 않는다.
attackResult.OnClientEvent:Connect(function(monsterModel, damage, isCrit, died)
	local classId = player:GetAttribute("ClassId")
	local projectileKind = RANGED_PROJECTILE_KIND[classId]

	if not projectileKind then
		showResult(monsterModel, damage, isCrit, died)
		return
	end

	-- 스윙이 아직 "발사 시점"(releaseT)에 안 닿았으면 그때까지 기다렸다가 쏜다 - 서버
	-- 응답이 스윙 애니메이션보다 먼저 와도(대개 그렇다) 시위가 안 당겨진 채로 화살이
	-- 나가는 어색함을 막는다.
	local releaseDelay = WeaponVisual.getReleaseDelay()
	task.delay(releaseDelay, function()
		local targetHead = monsterModel and monsterModel:FindFirstChild("Head")
		local muzzle = WeaponVisual.getMuzzleWorldPosition()
		if not targetHead or not muzzle then
			-- 발사 시점에 대상이 이미 사라졌으면(드문 경우) 투사체 없이 즉시 표시로 대체한다.
			showResult(monsterModel, damage, isCrit, died)
			return
		end
		Projectiles.fire(projectileKind, muzzle, targetHead.Position, isCrit, function()
			showResult(monsterModel, damage, isCrit, died)
		end)
	end)
end)
