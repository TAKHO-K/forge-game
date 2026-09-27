-- W2: 무기 발광(내 무기 PointLight · 남의 오른손 빛) 삭제 → 공격 궤적(client/AttackTrail)의 굵기 단계가 "다음이 강공격"을 알린다. 남은 것 = 폰 3칸 막대 · 조준 외곽선 색.
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

local ComboGlow = {}

local COUNT = CombatConfig.comboHitEvery
local cfg = CombatConfig.comboGlow
local GLOW_COLOR = UIColors[cfg.colorKey]

local player = Players.LocalPlayer
local filled, lastComboAt = 0, 0

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
	return { filled = filled, brightness = 0, bars = on } -- W2: 무기 발광 삭제(brightness 항상 0 - 궤적 단계가 대신)
end

task.spawn(buildBars)
paint()

RunService.RenderStepped:Connect(function()
	if filled > 0 and os.clock() - lastComboAt > CombatConfig.comboResetWindowSeconds then
		ComboGlow.reset()
	end
end)

return ComboGlow
