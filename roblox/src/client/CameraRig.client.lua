-- 카메라(G2a - 맵 크기 판단 기준). 로블록스 기본 Classic 카메라(좌우 회전 · 휠/핀치 줌)는 그대로 두고 수치만 건다(MovementConfig.camera):
--   - 줌 범위: Player.CameraMinZoomDistance / CameraMaxZoomDistance(엔진이 지킨다).
--   - 스폰마다 기본 거리 · 기본 각도로 맞춘다: 거리는 최소 = 최대 = 기본으로 한 프레임 묶었다가 푼다(카메라 모듈의 줌 상태를 바꾸는 유일한 공개 경로).
--   - 각도 범위: 카메라 모듈 뒤(RenderPriority.Camera + 2 - CameraShake(+1) 뒤)에서 내려다보는 각이 범위 밖이면 같은 방위 · 같은 거리로 범위 끝에 돌려놓는다.
--     카메라 모듈은 다음 프레임에 지금 카메라 방향에서 이어 돌리므로 조인 값이 유지된다. 범위 안이면 아무것도 안 한다(흔들림 · 회오리 카메라 그대로).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local player = Players.LocalPlayer
local cfg = MovementConfig.camera

player.CameraMinZoomDistance = cfg.zoomMinStuds
player.CameraMaxZoomDistance = cfg.zoomMaxStuds

-- 초점에서 방위(yaw)는 그대로, 내려다보는 각만 pitchDeg로 · 거리 distance로 놓은 카메라 CFrame.
local function placeAt(camera, focus, pitchDeg, distance)
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	flat = flat.Unit
	local pitch = math.rad(pitchDeg)
	local dir = flat * math.cos(pitch) - Vector3.new(0, math.sin(pitch), 0) -- 카메라 → 초점
	return CFrame.lookAt(focus - dir * distance, focus)
end

local defaultPitchUntil = 0 -- 스폰 직후 이 시각까지는 기본 각도로 맞춘다(카메라 대상이 붙는 첫 프레임들)

RunService:BindToRenderStep("CameraRig", Enum.RenderPriority.Camera.Value + 2, function()
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local distance = offset.Magnitude
	if distance < 1 then
		return
	end
	local pitchDeg = math.deg(math.asin(math.clamp(-camera.CFrame.LookVector.Y, -1, 1)))
	local target = os.clock() < defaultPitchUntil and cfg.pitchDeg or math.clamp(pitchDeg, cfg.pitchMinDeg, cfg.pitchMaxDeg)
	if math.abs(target - pitchDeg) > 0.05 then
		camera.CFrame = placeAt(camera, focus, target, distance)
	end
end)

local function onCharacter()
	-- 기본 거리: 한 프레임 동안 줌을 기본값 하나로 묶는다(카메라 모듈이 범위 안으로 끌어온다) → 원래 범위로 푼다.
	player.CameraMinZoomDistance = cfg.zoomStuds
	player.CameraMaxZoomDistance = cfg.zoomStuds
	defaultPitchUntil = os.clock() + 0.3
	task.delay(0.2, function()
		player.CameraMinZoomDistance = cfg.zoomMinStuds
		player.CameraMaxZoomDistance = cfg.zoomMaxStuds
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	onCharacter()
end
