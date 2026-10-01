-- QUEUE-ALL2 P2 B-4 ⑤ · 09 문서 B-2 "연출 세기(끔 · 약 · 보통) 하나로 흔들림 · 번쩍임 · 남의 효과를 함께 줄인다".
--   LocalPlayer Attribute FxLevel(서버 SettingsService가 저장 값으로 넣는다) → 옛 개별 Attribute로 풀어 준다(옛 코드는 그 값만 읽는다 - 입구 그대로):
--   끔 = 흔들림 끔(SettingScreenShake · SettingBossScreenShake false) + 번쩍임 줄이기 켬 + 남의 궤적 흐리게 / 약 = 흔들림 켬(CameraShake가 FxScale 0.5를 곱한다) + 남의 궤적 흐리게 / 보통 = 옛 기본.
--   FxScale(0 · 0.5 · 1) = 새 연출(P4)이 곱하는 세기. 흔들림 · 번쩍임 "3초에 1번" 규칙은 CameraShake · FxBudget이 따로 지킨다.
local Players = game:GetService("Players")

local AttackTrail = require(script.Parent.AttackTrail)
local GraphicsMode = require(script.Parent.GraphicsMode)

local player = Players.LocalPlayer
local SCALE = { normal = 1, low = 0.5, off = 0 }

local function apply()
	local level = player:GetAttribute("FxLevel") or "normal"
	player:SetAttribute("FxScale", SCALE[level] or 1)
	player:SetAttribute("SettingScreenShake", level ~= "off")
	player:SetAttribute("SettingBossScreenShake", level ~= "off")
	if level == "off" then
		player:SetAttribute("ReduceFlashes", true)
	end
	if level ~= "normal" and not AttackTrail.dimOthers() then
		AttackTrail.setDimOthers(true)
	end
end

player:GetAttributeChangedSignal("FxLevel"):Connect(apply)
apply()

-- QUEUE-ALL3 Q10: 그래픽 "가벼움" = 먼 산 LOD 줄(Workspace.DistantMountains.Far)을 내 화면에서 숨김
local function applyGraphics()
	local lite = GraphicsMode.isLite() -- QUEUE-ALL6 A2: 안 골랐으면 기기 기본
	local far = workspace:FindFirstChild("DistantMountains") and workspace.DistantMountains:FindFirstChild("Far")
	for _, d in ipairs(far and far:GetDescendants() or {}) do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = lite and 1 or 0
		end
	end
end
player:GetAttributeChangedSignal("GraphicsMode"):Connect(applyGraphics)
workspace.ChildAdded:Connect(function(c)
	if c.Name == "DistantMountains" then
		task.wait(2)
		applyGraphics()
	end
end)
task.defer(applyGraphics)
