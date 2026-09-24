-- 데미지 숫자 팝업(9-3~9-5에서 AttackInput.client.lua 안에 private로 있던 것을 20-2a에서
-- 뽑아냈다) - 스킬(SkillInput.client.lua)도 평타와 같은 표시를 재사용해야 해서 공유
-- 모듈로 옮겼다. 동작은 원본과 동일하다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local DamageNumbers = {}

-- 몬스터별로 동시에 떠 있는 데미지 숫자 개수(9-5 개정, 9-3에서 미루기만 했던 스택
-- 오프셋). 약한 테이블 키라 몬스터가 사라지면(사망·리스폰) 항목도 같이 수거된다.
local activeStacks = setmetatable({}, { __mode = "k" })

-- 치명타 크기 배율(PRD-forge-game.md 4.4 "크기 1.5배 + 굵게 + 튀어오르는 모션"). 색은
-- 그대로 두고(같은 흰색 계열) 크기·폰트·모션만 바꿔 구분한다.
local CRIT_SIZE_SCALE = 1.5

-- isHeal(20-6 [5], 힐러 Q) - 몬스터가 아니라 캐릭터(플레이어 자신)에 붙일 때도 그대로
-- 쓴다("Head"를 갖고 있으면 대상 종류를 안 가린다). true면 녹색 "+숫자"로 표시한다 - 기본값
-- false·생략이라 기존 4개 호출부(대검/활)는 그대로 동작한다.
function DamageNumbers.show(monsterModel, damage, isCrit, isHeal)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	-- 짧은 시간에 여러 대를 때리면 숫자가 겹쳐 안 보인다 - 이미 떠 있는 개수만큼 위로
	-- 밀어서 계단식으로 쌓는다(스킬로 여러 마리를 동시에 때려도 같은 원칙이 그대로 적용된다).
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
	label.Text = (isHeal and "+" or "") .. NumberFormat.format(damage)
	label.TextColor3 = isHeal and Color3.fromRGB(120, 230, 130) or Color3.fromRGB(255, 220, 60)
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

-- P3a D4: 내가 맞은 피해(빨강 "−숫자") · 쉴드가 막은 몫(테두리색 "흡수 숫자"). 몬스터 숫자와 같은 쌓기 · 수명을 쓴다. 색은 기존 UIColors(danger · rim).
function DamageNumbers.showTaken(character, damage, absorbed)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local stackIndex = activeStacks[character] or 0
	activeStacks[character] = stackIndex + 1
	local gui = Instance.new("BillboardGui")
	gui.Name = "DamageTakenGui"
	gui.Size = UDim2.new(3, 0, 1, 0)
	gui.StudsOffset = Vector3.new(0, 2.6 + stackIndex * 0.9, 0)
	gui.AlwaysOnTop = true
	gui.Adornee = head
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	if damage > 0 then
		label.Text = "-" .. NumberFormat.format(damage) .. ((absorbed or 0) > 0 and (" (흡수 %s)"):format(NumberFormat.format(absorbed)) or "")
		label.TextColor3 = UIColors.danger
	else
		label.Text = ("흡수 %s"):format(NumberFormat.format(absorbed or 0))
		label.TextColor3 = UIColors.rim
	end
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	task.delay(CombatConfig.damageNumberLifetimeSeconds, function()
		gui:Destroy()
		activeStacks[character] = math.max((activeStacks[character] or 1) - 1, 0)
	end)
end

return DamageNumbers
