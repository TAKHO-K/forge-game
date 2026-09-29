-- A2-N2 2-5 UI 등급 프레임(클라 · ArtStyleV1 스위치 뒤 · 값 = shared/data/ArtV1UiData). 장비창 칸 · 착용 슬롯 · 드랍 이름표 · 확률 창이 같은 규칙을 쓴다.
--   apply(frame, stroke, glowFrame, gradeId) = 테두리(UIStroke) 두께 · 색 · 그라데이션 띠 · 배경 섞기 · 바깥 빛. glowFrame이 없으면 빛은 생략.
--   움직임(띠 회전 · 무지개 흐름 · 초월 흑금 숨쉬기)은 이 모듈의 한 루프가 돌린다(약한 표 - 창이 닫혀 인스턴스가 사라지면 자동으로 빠진다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local UiData = require(ReplicatedStorage.Shared.data.ArtV1UiData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)

local GradeFrame = {}

local spinning = setmetatable({}, { __mode = "k" }) -- [UIGradient] = 도/초
local breathing = setmetatable({}, { __mode = "k" }) -- [glow Frame] = 기준 투명도

function GradeFrame.isOn()
	return Workspace:GetAttribute(ArtStyleV1Data.attribute) == true
end

local function mix(a, b, t)
	return a:Lerp(b, t)
end

local function gradient(parent, seq, spin)
	local old = parent:FindFirstChild("GradeSheen")
	if old then
		old:Destroy()
	end
	local g = Instance.new("UIGradient")
	g.Name = "GradeSheen"
	g.Color = seq
	g.Rotation = 45
	g.Parent = parent
	if spin and spin > 0 then
		spinning[g] = spin
	end
	return g
end

-- 등급 색(초월 = 금)
function GradeFrame.colorOf(gradeId)
	local v = ItemVisualData.gradeVisuals[gradeId]
	return v and v.color or Color3.new(1, 1, 1)
end

function GradeFrame.apply(frame, stroke, glowFrame, gradeId)
	local spec = UiData.grades[gradeId]
	if not spec or not stroke then
		return false
	end
	local color = GradeFrame.colorOf(gradeId)
	stroke.Thickness = spec.thickness
	stroke.Transparency = 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if spec.blackGold then
		local B = UiData.blackGold
		stroke.Color = Color3.new(1, 1, 1)
		gradient(stroke, ColorSequence.new({
			ColorSequenceKeypoint.new(0, B.dark), ColorSequenceKeypoint.new(0.35, B.gold), ColorSequenceKeypoint.new(0.5, B.shine),
			ColorSequenceKeypoint.new(0.65, B.gold), ColorSequenceKeypoint.new(1, B.dark),
		}), spec.spin)
		if frame and frame:IsA("GuiObject") then
			frame.BackgroundColor3 = B.cell
		end
		color = B.gold
	elseif spec.rainbow then
		stroke.Color = Color3.new(1, 1, 1)
		gradient(stroke, ItemVisualData.rainbowSequence, spec.spin)
	else
		stroke.Color = spec.sheen > 0 and Color3.new(1, 1, 1) or color
		if spec.sheen > 0 then
			local light = mix(color, Color3.new(1, 1, 1), spec.sheen)
			gradient(stroke, ColorSequence.new({
				ColorSequenceKeypoint.new(0, color), ColorSequenceKeypoint.new(0.45, color), ColorSequenceKeypoint.new(0.5, light),
				ColorSequenceKeypoint.new(0.55, color), ColorSequenceKeypoint.new(1, color),
			}), spec.spin)
		end
		if frame and frame:IsA("GuiObject") and spec.fill > 0 then
			frame.BackgroundColor3 = mix(frame.BackgroundColor3, color, spec.fill)
		end
	end
	if glowFrame then
		if spec.glow > 0 then
			glowFrame.BackgroundColor3 = color
			glowFrame.BackgroundTransparency = 1 - spec.glow
			if spec.blackGold then
				breathing[glowFrame] = 1 - spec.glow
			end
		else
			glowFrame.BackgroundTransparency = 1
		end
	end
	return true
end

-- 글자(이름표 · 확률 창 줄): 등급 색 + 초월 = 금 글자 · 검은 외곽선 / 태초 = 무지개 그라데이션
function GradeFrame.applyText(label, gradeId)
	local spec = UiData.grades[gradeId]
	if not spec then
		return
	end
	local color = GradeFrame.colorOf(gradeId)
	label.TextColor3 = spec.rainbow and Color3.new(1, 1, 1) or color
	if spec.rainbow then
		gradient(label, ItemVisualData.rainbowSequence, spec.spin)
	elseif spec.blackGold then
		label.TextColor3 = Color3.new(1, 1, 1)
		local B = UiData.blackGold
		gradient(label, ColorSequence.new({ ColorSequenceKeypoint.new(0, B.gold), ColorSequenceKeypoint.new(0.5, B.shine), ColorSequenceKeypoint.new(1, B.gold) }), spec.spin)
		label.TextStrokeColor3 = B.cell
		label.TextStrokeTransparency = 0.2
	end
end

RunService.RenderStepped:Connect(function(dt)
	for g, speed in pairs(spinning) do
		if g.Parent then
			g.Rotation = (g.Rotation + speed * dt) % 360
		end
	end
	if next(breathing) then
		local wave = (math.sin(os.clock() * math.pi * 2 * UiData.blackGold.breatheHz) + 1) / 2
		for glow, base in pairs(breathing) do
			if glow.Parent then
				glow.BackgroundTransparency = math.clamp(base + 0.25 * wave, 0, 1)
			end
		end
	end
end)

return GradeFrame
