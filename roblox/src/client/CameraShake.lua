-- 카메라 흔들림(16-7에서 AttackInput.client.lua 안에 private로 만들어졌던 것을 20-2a에서
-- 뽑아냈다) - 스킬(SkillInput.client.lua)도 강타와 같은 흔들림 메커니즘을 재사용해야 해서
-- 공유 모듈로 옮겼다. 동작은 원본과 동일하다: trigger()를 부른 순간부터 durationSeconds
-- 안에 감쇠하며 잦아든다(지시 - "과하면 멀미가 난다. 감쇠 속도가 중요하다"). 여러 번
-- 겹쳐 불러도 마지막 호출의 지속시간으로 그냥 갱신된다(짧은 흔들림들이 순차로 오면 항상
-- 최신 것 기준으로 감쇠 - 강타 전용이라 실제로 겹칠 일이 거의 없다).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local FxPolicyData = require(game:GetService("ReplicatedStorage").Shared.data.FxPolicyData)

local camera = Workspace.CurrentCamera

local CameraShake = {}

-- QUEUE-ALL2 P4 ①: 종류별 규칙(FxPolicyData) · 연출 세기(FxScale) · 흔들림/번쩍임 = 같은 3초 안에 1번(클라이맥스 예외). 반환 = 이번 호출에 곱할 배율(0 = 하지 않음)
local lastBudgetAt = { shake = -math.huge, flash = -math.huge }
function CameraShake.allow(channel, kind)
	local localPlayer = Players.LocalPlayer
	local def = FxPolicyData.kinds[kind or "heavy"] or FxPolicyData.kinds.heavy
	local fx = localPlayer and localPlayer:GetAttribute("FxScale")
	local scale = def.scale * (type(fx) == "number" and fx or 1)
	if scale <= 0 then
		return 0
	end
	if channel == "shake" and localPlayer and localPlayer:GetAttribute("SettingScreenShake") == false then -- 설정 끔 = 모든 종류(climax 포함) 안 흔든다
		return 0
	end
	if def.budget then
		local now = os.clock()
		if now - lastBudgetAt[channel] < FxPolicyData.budgetSeconds then
			return 0
		end
		lastBudgetAt[channel] = now
	end
	return scale
end

local shakeUntil = 0
local shakeDurationSeconds = 0
local shakeAmplitudeStuds = 0

RunService:BindToRenderStep("CameraShake", Enum.RenderPriority.Camera.Value + 1, function()
	local remaining = shakeUntil - os.clock()
	if remaining <= 0 then
		return
	end
	local decay = remaining / shakeDurationSeconds
	local offset = Vector3.new(
		(math.random() * 2 - 1) * shakeAmplitudeStuds * decay,
		(math.random() * 2 - 1) * shakeAmplitudeStuds * decay,
		0
	)
	camera.CFrame *= CFrame.new(offset)
end)

-- A2-N3 결정 ①: 타격 FOV 킥(시야각을 degrees만큼 넓혔다가 seconds 동안 선형으로 되돌림 - 위치는 안 움직인다). 다른 코드가 FOV를 바꿔도 더한 몫만 빼고 더한다.
local kickUntil, kickSeconds, kickDegrees, kickApplied, lastSet = 0, 0, 0, 0, nil
RunService:BindToRenderStep("CameraFovKick", Enum.RenderPriority.Camera.Value + 1, function()
	if lastSet and math.abs(camera.FieldOfView - lastSet) > 1e-3 then
		kickApplied = 0 -- 다른 코드가 FOV를 새로 썼다(사망 줌 · 태초 연출 등) → 그 값이 새 기준(더한 몫을 빼지 않는다)
		kickUntil = 0
	end
	local remaining = kickUntil - os.clock()
	local want = remaining > 0 and kickDegrees * (remaining / kickSeconds) or 0
	if want ~= kickApplied then
		camera.FieldOfView += want - kickApplied
		kickApplied = want
	end
	lastSet = (want ~= 0 or kickApplied ~= 0) and camera.FieldOfView or nil
end)
function CameraShake.fovKick(degrees, seconds)
	local scale = CameraShake.allow("shake", "heavy") -- QUEUE-ALL2 P4: 보스 적중 FOV 킥도 흔들림 몫(3초에 1번 · × 연출 세기)
	if scale <= 0 then
		return
	end
	kickDegrees, kickSeconds, kickUntil = degrees * scale, seconds, os.clock() + seconds
end

-- durationSeconds 동안 studsAmplitude 크기로 흔든다(원본 AttackInput.client.lua의
-- CAMERA_SHAKE_SECONDS=0.15/CAMERA_SHAKE_STUDS=0.35와 같은 기본값을 호출부가 넘긴다).
-- W3c: 설정 "화면 흔들림" 끔(LocalPlayer Attribute SettingScreenShake = false - client/panels/Settings)이면 아무것도 안 한다.
-- kind = FxPolicyData.kinds 이름(heavy · hurt · boss · climax - 없으면 heavy)
function CameraShake.trigger(durationSeconds, studsAmplitude, kind)
	local scale = CameraShake.allow("shake", kind)
	if scale <= 0 then
		return
	end
	shakeDurationSeconds = durationSeconds
	shakeAmplitudeStuds = studsAmplitude * scale
	shakeUntil = os.clock() + durationSeconds
end

return CameraShake
