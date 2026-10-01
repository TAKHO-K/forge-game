-- QUEUE-ALL2 P4 ⑤⑥(09 B-2 "내가 맞을 때 = 공격 크기에 비례" · docs/visual-audit.md 1순위 5 · 6): 화면 가장자리만 붉게 번진다(가운데 · 전조를 가리지 않음 - 가장자리 edgeFraction만).
--   작은 피해(평타) = 옅게 짧게 · 큰 피해(한 대 ≥ 최대 체력 × PlayerMotionData.bigHitFraction - 큰 피격 모션과 같은 선) = 진하게 + 짧은 흔들림(CameraShake "hurt" - 설정 · 3초 규칙 따름) + 묵직한 소리
--   체력 30% 아래 = 가장자리 심장 박동(약하게 · 번쩍임 줄이기 켬 = 박동 없이 고정 번짐). 세기 × 연출 세기(FxScale · 끔이면 없음). 아트 켬(ArtStyleV1)일 때만 - 끔 = 전과 같음.
--   입력 = 서버 PlayerHitFeedback(damage, absorbed - 내 캐릭터) · Player Attribute Hp · MaxHp. 판정 무관(화면만).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local CameraShake = require(script.Parent.CameraShake)
local SoundSheet = require(script.Parent.SoundSheet)

local player = Players.LocalPlayer
local E = { edgeFraction = 0.12, small = { alpha = 0.8, seconds = 0.25 }, big = { alpha = 0.55, seconds = 0.45, shakeSeconds = 0.12, shakeStuds = 0.15 },
	lowHp = { fraction = 0.3, period = 1.0, from = 0.88, to = 0.74 } }
local RED = Color3.fromRGB(200, 30, 40)

local gui = Instance.new("ScreenGui")
gui.Name = "HurtEdgeGui"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 3
gui.Parent = player:WaitForChild("PlayerGui")

-- 네 가장자리 띠(안쪽으로 투명해지는 그라데이션) - 한 값(Alpha)으로 함께 움직인다
local bands = {}
local function band(name, size, position, rotation)
	local f = Instance.new("Frame")
	f.Name = name
	f.BorderSizePixel = 0
	f.BackgroundColor3 = RED
	f.BackgroundTransparency = 1
	f.Size, f.Position = size, position
	f.Parent = gui
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	table.insert(bands, f)
end
band("Left", UDim2.new(E.edgeFraction, 0, 1, 0), UDim2.new(0, 0, 0, 0), 0)
band("Right", UDim2.new(E.edgeFraction, 0, 1, 0), UDim2.new(1 - E.edgeFraction, 0, 0, 0), 180)
band("Top", UDim2.new(1, 0, E.edgeFraction, 0), UDim2.new(0, 0, 0, 0), 90)
band("Bottom", UDim2.new(1, 0, E.edgeFraction, 0), UDim2.new(0, 0, 1 - E.edgeFraction, 0), 270)

local value = Instance.new("NumberValue") -- 0 = 안 보임 · 1 = 가장 진하게
local pulse = 0 -- 체력 낮음 번짐(0 ~ 1)
local function apply()
	local a = math.max(value.Value, pulse)
	for _, f in ipairs(bands) do
		f.BackgroundTransparency = 1 - a
	end
end
value.Changed:Connect(apply)

local function on()
	return Workspace:GetAttribute("ArtStyleV1") == true and (player:GetAttribute("FxScale") or 1) > 0
end

local function hit(strength, seconds)
	local fx = player:GetAttribute("FxScale") or 1
	value.Value = math.max(value.Value, strength * fx)
	TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 0 }):Play()
end

ReplicatedStorage:WaitForChild("PlayerHitFeedback").OnClientEvent:Connect(function(damage)
	if not on() or type(damage) ~= "number" or damage <= 0 then
		return
	end
	local maxHp = player:GetAttribute("MaxHp") or 100
	if damage >= maxHp * PlayerMotionData.overlay.bigHitFraction then -- QUEUE-ALL6 I: 값은 overlay 아래(WeaponVisual과 같은 줄) - 옛 = nil 곱하기 에러로 맞을 때마다 연출 · 소리가 안 났다
		hit(1 - E.big.alpha, E.big.seconds)
		CameraShake.trigger(E.big.shakeSeconds, E.big.shakeStuds, "hurt")
		SoundSheet.play("hurt_big", { minInterval = 0.3 })
	else
		hit(1 - E.small.alpha, E.small.seconds)
		SoundSheet.play("hurt_small", { minInterval = 0.25 })
	end
end)

-- 체력 30% 아래 = 약한 심장 박동(번쩍임 줄이기 = 고정 번짐)
local lastBeat = 0
RunService.Heartbeat:Connect(function()
	local hp, maxHp = player:GetAttribute("Hp"), player:GetAttribute("MaxHp")
	local low = on() and hp and maxHp and maxHp > 0 and hp > 0 and hp / maxHp < E.lowHp.fraction
	if not low then
		if pulse ~= 0 then
			pulse = 0
			apply()
		end
		return
	end
	local fx = player:GetAttribute("FxScale") or 1
	if player:GetAttribute("ReduceFlashes") == true then
		pulse = (1 - E.lowHp.from) * fx
	else
		local phase = (os.clock() % E.lowHp.period) / E.lowHp.period
		local beat = math.max(0, math.sin(phase * math.pi * 2)) ^ 3
		pulse = ((1 - E.lowHp.from) + ((E.lowHp.from - E.lowHp.to) * beat)) * fx
		if os.clock() - lastBeat >= E.lowHp.period * 2 then
			lastBeat = os.clock()
			SoundSheet.play("heartbeat")
		end
	end
	apply()
end)
