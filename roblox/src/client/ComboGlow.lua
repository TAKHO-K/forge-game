-- 3타 강타 표시(M1-0 후속 - 사용자: 발밑 3칸 고리는 버튼 · 화면과 겹쳐 난잡 → 제거. 발밑은 점프 · 대시 표시 전용).
--   ① 내 무기 발광 단계: 1 · 2타 = 은은하게 → 다음 타가 강타(준비)면 밝게 + 한 번 번쩍. 색 = UIColors.comboGlow(보라 - 강화 이펙트의 ember · gold · danger · 흰색과 구분).
--      빛은 무기의 이펙트 자리(WeaponModelData.effectAnchor - 강화 빛과 같은 자리)에 PointLight 하나. 수치 = CombatConfig.comboGlow.
--   ② 남의 발광은 약하게: 서버가 Player Attribute ComboStage(0 · 1 · 2 = 이번 사이클에 친 수)를 건다 - 준비(2)일 때만 그 사람 오른손에 약한 빛.
--      (남의 무기 모델은 아직 클라에 안 그려진다 - WeaponEnhanceVisual 머리 주석 · README S08 미결. 그래서 손에 단다.)
--   ③ 폰(터치 배치): 공격 버튼이 없다(18-2 - 화면 탭 공격) → 스킬 줄 왼쪽 끝에 3칸 막대(아래부터 채움 · 준비면 3칸째까지 보라). PC에서는 숨는다.
--   조준 외곽선 색 신호(G1-1 C - AimTarget.setHeavyReady)는 그대로 둔다. 리셋 = 서버 규칙과 같은 comboResetWindowSeconds.
-- 판정은 건드리지 않는다(표시만). 새 에셋 · 파티클 없음.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local AimTarget = require(script.Parent.AimTarget)
local WeaponVisual = require(script.Parent.WeaponVisual)

local ComboGlow = {}

local COUNT = CombatConfig.comboHitEvery
local cfg = CombatConfig.comboGlow
local GLOW_COLOR = UIColors[cfg.colorKey]

local player = Players.LocalPlayer
local filled, lastComboAt, flashUntil = 0, 0, 0
local light -- 내 무기의 PointLight(무기를 새로 지으면 같이 지워진다 - 그때 다시 단다)

local function stageOf(count)
	if count <= 0 then
		return nil
	end
	return count == COUNT - 1 and cfg.mine.ready or cfg.mine.hit
end

local function ensureLight()
	if light and light.Parent and light.Parent.Parent then
		return light
	end
	local part, anchorPosition = WeaponVisual.getEffectAttach()
	if not part then
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = "ComboGlowAnchor"
	attachment.Position = anchorPosition
	attachment.Parent = part
	light = Instance.new("PointLight")
	light.Name = "ComboGlow"
	light.Color = GLOW_COLOR
	light.Shadows = false
	light.Parent = attachment
	return light
end

-- 폰 3칸 막대
local bars, barHolder = {}, nil
local function buildBars()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("SkillSlotsGui")
	local row = gui:WaitForChild("CentralRow")
	barHolder = Instance.new("Frame")
	barHolder.Name = "ComboBars"
	barHolder.LayoutOrder = -1
	barHolder.Size = UDim2.new(0, 10, 0, 54)
	barHolder.BackgroundTransparency = 1
	barHolder.Visible = false
	barHolder.Parent = row
	local cell = (54 - (COUNT - 1) * 3) / COUNT
	for i = 1, COUNT do
		local bar = Instance.new("Frame")
		bar.Name = "Bar" .. i
		bar.AnchorPoint = Vector2.new(0, 1)
		bar.Position = UDim2.new(0, 0, 1, -(i - 1) * (cell + 3)) -- 1칸 = 맨 아래
		bar.Size = UDim2.new(1, 0, 0, cell)
		bar.BorderSizePixel = 0
		bar.Parent = barHolder
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 3)
		corner.Parent = bar
		local stroke = Instance.new("UIStroke")
		stroke.Color = UIColors.rim
		stroke.Transparency = UIColors.rimTransparency
		stroke.Parent = bar
		bars[i] = bar
	end
	local function refresh()
		barHolder.Visible = UserInputService.TouchEnabled or (RunService:IsStudio() and player:GetAttribute("ForceTouchLayout") == true)
	end
	refresh()
	player:GetAttributeChangedSignal("ForceTouchLayout"):Connect(refresh)
end

local function paint()
	local ready = filled == COUNT - 1
	for i, bar in ipairs(bars) do
		local on = i <= filled or (ready and i == COUNT)
		bar.BackgroundColor3 = on and GLOW_COLOR or UIColors.panel
		bar.BackgroundTransparency = on and (ready and 0 or 0.25) or UIColors.panelTransparency
	end
	AimTarget.setHeavyReady(ready) -- 다음 타가 강타(G1-1 C)
end

-- 서버 ComboUpdate 한 번. comboCount = 누적값 · isHeavyHit = 이번 타가 강타였는가(강타 뒤 = 사이클 끝 → 꺼짐).
function ComboGlow.onCombo(comboCount, isHeavyHit)
	filled = isHeavyHit and 0 or ((comboCount - 1) % COUNT) + 1
	lastComboAt = os.clock()
	if filled == COUNT - 1 then
		flashUntil = os.clock() + cfg.flashSeconds
	end
	paint()
end

function ComboGlow.reset()
	filled = 0
	paint()
end

-- 자체 점검용(G1-1(UI)): 마지막 ComboUpdate 시각 · 지금 내 무기 빛 밝기(없으면 0) · 폰 막대 켜진 칸 수
function ComboGlow.debugLastComboAt()
	return lastComboAt
end

function ComboGlow.debugState()
	local on = 0
	for _, bar in ipairs(bars) do
		on += bar.BackgroundColor3 == GLOW_COLOR and 1 or 0
	end
	return { filled = filled, brightness = light and light.Parent and light.Enabled and light.Brightness or 0, bars = on }
end

-- 남의 발광(준비 단계만 · 약하게)
local othersLight = {} -- [Player] = PointLight
local othersChangedAt = {} -- [Player] = os.clock()

local function setOthers(other, on)
	local existing = othersLight[other]
	if not on then
		if existing then
			existing:Destroy()
			othersLight[other] = nil
		end
		return
	end
	local hand = other.Character and (other.Character:FindFirstChild("RightHand") or other.Character:FindFirstChild("Right Arm"))
	if not hand then
		return
	end
	if existing and existing.Parent == hand then
		return
	end
	if existing then
		existing:Destroy()
	end
	local created = Instance.new("PointLight")
	created.Name = "ComboGlowOther"
	created.Color = GLOW_COLOR
	created.Brightness = cfg.others.ready.brightness
	created.Range = cfg.others.ready.range
	created.Shadows = false
	created.Parent = hand
	othersLight[other] = created
end

local function watchOther(other)
	if other == player then
		return
	end
	other:GetAttributeChangedSignal("ComboStage"):Connect(function()
		othersChangedAt[other] = os.clock()
		setOthers(other, other:GetAttribute("ComboStage") == COUNT - 1)
	end)
end

for _, other in ipairs(Players:GetPlayers()) do
	watchOther(other)
end
Players.PlayerAdded:Connect(watchOther)
Players.PlayerRemoving:Connect(function(other)
	setOthers(other, false)
	othersChangedAt[other] = nil
end)

task.spawn(buildBars)
paint()

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	if filled > 0 and now - lastComboAt > CombatConfig.comboResetWindowSeconds then
		ComboGlow.reset()
	end
	for other, at in pairs(othersChangedAt) do
		if othersLight[other] and now - at > CombatConfig.comboResetWindowSeconds then
			setOthers(other, false)
		end
	end
	local stage = stageOf(filled)
	if not stage then
		if light and light.Parent then
			light.Enabled = false
		end
		return
	end
	local glow = ensureLight()
	if not glow then
		return
	end
	glow.Enabled = true
	glow.Range = stage.range
	glow.Brightness = now < flashUntil and cfg.flashBrightness or stage.brightness
end)

return ComboGlow
