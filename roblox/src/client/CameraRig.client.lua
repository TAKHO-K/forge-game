-- 카메라(G2a → M1-0). 로블록스 기본 카메라(좌우 · 위아래 회전 · 휠/핀치 줌)는 그대로 두고 수치만 건다(MovementConfig.camera):
--   - 기본(free): 줌 범위만(기본 거리를 가깝게 - 캐릭터가 작아 보이지 않게). 각도는 자유.
--   - 탑다운 시점(topDown - 설정창에서 켠 사람만, LocalPlayer Attribute "CameraTopDown"): G2a 값 - 내려다보는 각을 범위 안으로 조인다.
--     이번 접속 동안만 기억한다(저장은 P4 설정창에서 설정 묶음으로).
--   - 줌 범위: Player.CameraMinZoomDistance / CameraMaxZoomDistance(엔진이 지킨다).
--   - 스폰 · 방식 전환 때 기본 거리로 맞춘다: 최소 = 최대 = 기본으로 한 번 묶었다가 푼다(카메라 모듈의 줌 상태를 바꾸는 유일한 공개 경로). 탑다운이면 기본 각도도.
--   - 각도 조임: 카메라 모듈 뒤(RenderPriority.Camera + 2 - CameraShake(+1) 뒤)에서 내려다보는 각이 범위 밖이면 같은 방위 · 같은 거리로 범위 끝에 돌려놓는다.
--     카메라 모듈은 다음 프레임에 지금 카메라 방향에서 이어 돌리므로 조인 값이 유지된다. 범위 안이면 아무것도 안 한다(흔들림 · 회오리 카메라 그대로).
--   - 보스전 중(Player Attribute BossEncounterId - M1-0 결정 ②)에는 어느 방식이든 내려다보는 각 최소 bossPitchMinDeg(30°). 위쪽은 자유.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local player = Players.LocalPlayer
local cfg = MovementConfig.camera

local function isTopDown()
	return player:GetAttribute("CameraTopDown") == true
end

local function current()
	return isTopDown() and cfg.topDown or cfg.free
end

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

local defaultPitchUntil = 0 -- 탑다운: 스폰 · 전환 직후 이 시각까지는 기본 각도로 맞춘다(카메라 대상이 붙는 첫 프레임들)

RunService:BindToRenderStep("CameraRig", Enum.RenderPriority.Camera.Value + 2, function()
	local inBoss = player:GetAttribute("BossEncounterId") ~= nil -- M1-0 결정 ②: 보스전 중에만 최소 각
	if not isTopDown() and not inBoss then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local focus = camera.Focus.Position
	local distance = (camera.CFrame.Position - focus).Magnitude
	if distance < 1 then
		return
	end
	local pitchDeg = math.deg(math.asin(math.clamp(-camera.CFrame.LookVector.Y, -1, 1)))
	local target
	if isTopDown() then
		local m = cfg.topDown
		target = os.clock() < defaultPitchUntil and m.pitchDeg or math.clamp(pitchDeg, math.max(m.pitchMinDeg, inBoss and cfg.bossPitchMinDeg or 0), m.pitchMaxDeg)
	else
		target = math.max(pitchDeg, cfg.bossPitchMinDeg)
	end
	if math.abs(target - pitchDeg) > 0.05 then
		camera.CFrame = placeAt(camera, focus, target, distance)
	end
end)

local snapToken = 0

-- 기본 거리(탑다운이면 각도도)로 맞춘다: 한 번 줌을 기본값 하나로 묶는다(카메라 모듈이 범위 안으로 끌어온다) → 그 방식의 범위로 푼다.
local function snap()
	local m = current()
	snapToken += 1
	local token = snapToken
	player.CameraMinZoomDistance = m.zoomStuds
	player.CameraMaxZoomDistance = m.zoomStuds
	defaultPitchUntil = isTopDown() and os.clock() + cfg.spawnSnapSeconds or 0
	task.delay(cfg.spawnSnapSeconds, function()
		if token ~= snapToken then
			return
		end
		local now = current()
		player.CameraMinZoomDistance = now.zoomMinStuds
		player.CameraMaxZoomDistance = now.zoomMaxStuds
	end)
end

-- A2-M1 보스별 카메라 거리: 보스전에 들어서면(BossEncounterId) 지금 거리가 그 보스의 cameraZoomStuds보다 가까울 때만 한 번 그 거리로 물린다(큰 보스가 화면을 넘치지 않게) → 곧 원래 범위로 푼다(휠 자유).
local CollectionService = game:GetService("CollectionService")
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local function bossZoomFor(encounterId)
	for _, m in ipairs(CollectionService:GetTagged("Monster")) do
		if m:GetAttribute("BossEncounterId") == encounterId then
			local boss = BossData.bosses[m:GetAttribute("BossRig") or ""]
			return boss and boss.cameraZoomStuds, m:GetAttribute("BossRig")
		end
	end
	return nil
end
local function snapTo(zoom, holdSeconds)
	snapToken += 1
	local token = snapToken
	player.CameraMinZoomDistance = zoom
	player.CameraMaxZoomDistance = zoom
	task.delay(holdSeconds or cfg.spawnSnapSeconds, function()
		if token ~= snapToken then
			return
		end
		local now = current()
		player.CameraMinZoomDistance = now.zoomMinStuds
		player.CameraMaxZoomDistance = math.max(now.zoomMaxStuds, zoom)
	end)
end
player:GetAttributeChangedSignal("BossEncounterId"):Connect(function()
	local id = player:GetAttribute("BossEncounterId")
	if not id then
		return
	end
	task.spawn(function() -- 보스 모델 복제를 기다린다(A2-N3: 0.5초 한 번 → 0.25초 간격 최대 4초 - 진입 직후 보스가 아직 안 와서 거리 맞춤을 건너뛰던 일)
		local zoom, rigId
		local tries = Workspace:GetAttribute("ArtStyleV1") and 16 or 1 -- 끔 = 옛 동작(0.5초 한 번)
		for _ = 1, tries do
			task.wait(tries > 1 and 0.25 or 0.5)
			if player:GetAttribute("BossEncounterId") ~= id then
				return
			end
			zoom, rigId = bossZoomFor(id)
			if zoom then
				break
			end
		end
		local camera = Workspace.CurrentCamera
		if zoom and camera and Workspace:GetAttribute("ArtStyleV1") then
			snapTo(zoom * ((cfg.bossZoomFactorOf and cfg.bossZoomFactorOf[rigId or ""]) or cfg.bossZoomFactor), cfg.bossZoomHoldSeconds) -- A2-N3 결정 ①: 보스 크기에 맞춘 거리 × 0.88로 맞춘다(가깝게도 멀게도 - 그 뒤 휠 자유 · 0.3초면 줌 스프링이 다 못 와 22에서 멈췄다 → 1초)
		elseif zoom and camera and (camera.CFrame.Position - camera.Focus.Position).Magnitude < zoom - 1 then
			snapTo(zoom)
		end
	end)
end)

player.CharacterAdded:Connect(snap)
player:GetAttributeChangedSignal("CameraTopDown"):Connect(snap)
player.CameraMinZoomDistance = cfg.free.zoomMinStuds
player.CameraMaxZoomDistance = cfg.free.zoomMaxStuds
if player.Character then
	snap()
end
