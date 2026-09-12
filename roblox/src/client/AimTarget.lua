-- 조준 대상 판정(16-7) - "지금 누구를 때리려는가"를 화면에 보여주는 쪽. 실제 공격 판정은
-- 여전히 AttackServer.server.lua가 서버에서 다시 한다 - 여기서 고른 대상은 표시(HP바 위
-- 이름 + Highlight)와 공격 요청에 실어 보내는 조준 방향 힌트일 뿐, 클라이언트가 데미지나
-- 사거리를 확정하지 않는다.
--
-- 판정 방식: 사거리 안 몬스터 중 "조준 방향(플레이어->조준점)에 가장 가까운" 것을 고른다
-- (화면 픽셀로 직접 클릭하는 방식이 아니다 - 작은 몬스터를 정확히 클릭하기 어렵고, 이
-- 게임은 탑다운이라 방향 기반이 자연스럽다). 방향과 안 맞는 각도(뒤쪽)뿐이면 사거리 안
-- 가장 가까운 몬스터로 대체한다 - 조준 대상이 아예 없는 순간이 길게 이어지면 안 된다는
-- 지시 때문이다.
--
-- PC는 매 틱 마우스 위치로 갱신(호버만으로 실시간 갱신). 모바일은 터치 중이면 그 위치,
-- 터치가 없으면 마지막으로 조준했던 지점을 그대로 얼려 쓴다(그 지점 근처 몬스터가
-- 죽거나 벗어나면 사거리 안 최근접으로 자동 대체된다).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)

local AimTarget = {}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local TICK_SECONDS = 0.1 -- 지시: "매 프레임 하지 말고 0.1초 간격 정도로 충분하다"
local RAYCAST_DISTANCE_STUDS = 500

local activeTouchPosition = nil -- Vector2, 터치 중일 때만
local lastAimPoint = nil -- Vector3, 마지막으로 구한 조준점(터치 뗀 뒤에도 얼려서 재사용)
local currentTarget = nil -- Model

-- 화면 좌표 -> 바닥 위 월드 좌표. 실제 지형·몬스터에 레이캐스트해 맞으면 그 지점을,
-- 아무것도 안 맞으면 플레이어 발밑 높이의 수평면과의 교차점을 쓴다(카메라가 하늘을
-- 향한 각도라 아무것도 안 맞는 경우 대비).
function AimTarget.getWorldPointFromScreen(screenPos)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return nil
	end

	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * RAYCAST_DISTANCE_STUDS, params)
	if result then
		return result.Position
	end

	local groundY = rootPart.Position.Y
	local dirY = ray.Direction.Y
	if math.abs(dirY) < 1e-4 then
		return nil
	end
	local t = (groundY - ray.Origin.Y) / dirY
	if t < 0 then
		return nil
	end
	return ray.Origin + ray.Direction * t
end

local function setVisual(model, on)
	if not model then
		return
	end
	local highlight = model:FindFirstChild("AimHighlight")
	if highlight then
		highlight.Enabled = on
	end
	local head = model:FindFirstChild("Head")
	local nameplateGui = head and head:FindFirstChild("NameplateGui")
	local nameLabel = nameplateGui and nameplateGui:FindFirstChild("NameLabel")
	if nameLabel then
		nameLabel.Visible = on
	end
end

local function setTarget(model)
	if model == currentTarget then
		return
	end
	setVisual(currentTarget, false)
	currentTarget = model
	setVisual(currentTarget, true)
end

-- 지금 조준점을 즉시 반영한다(클릭·탭 순간 호버 틱을 기다리지 않고 바로 갱신하기 위해
-- AttackInput.client.lua가 부른다). aimPoint가 nil이면 마지막 조준점을 그대로 쓴다.
function AimTarget.refresh(aimPoint)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end
	if aimPoint then
		lastAimPoint = aimPoint
	end
	local candidates = CollectionService:GetTagged("Monster")
	setTarget(AimPicker.pick(rootPart.Position, lastAimPoint, CombatConfig.attackRangeStuds, candidates))
end

function AimTarget.getCurrentTarget()
	return currentTarget
end

function AimTarget.getLastAimPoint()
	return lastAimPoint
end

UserInputService.TouchStarted:Connect(function(touch, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	activeTouchPosition = Vector2.new(touch.Position.X, touch.Position.Y)
end)

UserInputService.TouchMoved:Connect(function(touch, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	activeTouchPosition = Vector2.new(touch.Position.X, touch.Position.Y)
end)

UserInputService.TouchEnded:Connect(function()
	activeTouchPosition = nil
end)

task.spawn(function()
	while true do
		task.wait(TICK_SECONDS)
		local screenPos = nil
		if activeTouchPosition then
			screenPos = activeTouchPosition
		elseif UserInputService.MouseEnabled then
			local mouseLocation = UserInputService:GetMouseLocation()
			screenPos = mouseLocation
		end

		if screenPos then
			AimTarget.refresh(AimTarget.getWorldPointFromScreen(screenPos))
		else
			AimTarget.refresh(nil) -- 마지막 조준점을 그대로 재평가(대상이 죽었으면 최근접으로 대체)
		end
	end
end)

return AimTarget
