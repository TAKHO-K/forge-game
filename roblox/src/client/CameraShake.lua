-- 카메라 흔들림(16-7에서 AttackInput.client.lua 안에 private로 만들어졌던 것을 20-2a에서
-- 뽑아냈다) - 스킬(SkillInput.client.lua)도 강타와 같은 흔들림 메커니즘을 재사용해야 해서
-- 공유 모듈로 옮겼다. 동작은 원본과 동일하다: trigger()를 부른 순간부터 durationSeconds
-- 안에 감쇠하며 잦아든다(지시 - "과하면 멀미가 난다. 감쇠 속도가 중요하다"). 여러 번
-- 겹쳐 불러도 마지막 호출의 지속시간으로 그냥 갱신된다(짧은 흔들림들이 순차로 오면 항상
-- 최신 것 기준으로 감쇠 - 강타 전용이라 실제로 겹칠 일이 거의 없다).

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local camera = Workspace.CurrentCamera

local CameraShake = {}

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

-- durationSeconds 동안 studsAmplitude 크기로 흔든다(원본 AttackInput.client.lua의
-- CAMERA_SHAKE_SECONDS=0.15/CAMERA_SHAKE_STUDS=0.35와 같은 기본값을 호출부가 넘긴다).
function CameraShake.trigger(durationSeconds, studsAmplitude)
	shakeDurationSeconds = durationSeconds
	shakeAmplitudeStuds = studsAmplitude
	shakeUntil = os.clock() + durationSeconds
end

return CameraShake
