-- FINAL-1 3 MOVE-2 보스 밀어내기: 보스 파트는 충돌이 꺼져 있어(BossLook - 판정은 거리) 캐릭터가 보스 몸 안으로 들어가 버린다 → 내 캐릭터가 보스 몸(BossPushRadius) 안이면
-- 바깥으로 MovementConfig.bossPush.speedStuds/s씩 민다(겉모습 · 조작감 - 판정 무변경). 캐릭터 물리는 이 클라가 소유(서버가 CFrame을 밀면 튄다) · 서버는 겹친 동안 이동 허가(MovementServer).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local cfg = MovementConfig.bossPush
local player = Players.LocalPlayer

local bosses = {} -- 보스 모델 목록(scanSeconds마다 다시 모은다)
local lastScan = -math.huge
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function scan()
	table.clear(bosses)
	for _, m in ipairs(workspace:GetChildren()) do
		if m:IsA("Model") and m:GetAttribute("BossPushRadius") and m.PrimaryPart then
			table.insert(bosses, m)
		end
	end
end

local function blocked(root, dir, dist, character)
	params.FilterDescendantsInstances = { character, table.unpack(bosses) }
	return workspace:Raycast(root.Position, dir * (dist + 0.6), params) ~= nil
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	if now - lastScan >= cfg.scanSeconds then
		lastScan = now
		scan()
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or root.Anchored or #bosses == 0 then
		return
	end
	for _, boss in ipairs(bosses) do
		local center = boss.PrimaryPart and boss.PrimaryPart.Position
		if center and math.abs(root.Position.Y - center.Y) <= cfg.verticalStuds then
			local flat = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
			local radius = boss:GetAttribute("BossPushRadius") + cfg.playerRadius
			local depth = radius - flat.Magnitude
			if depth > cfg.minDepth then
				local dir = flat.Magnitude > 1e-3 and flat.Unit or -Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
				local step = math.min(depth, math.min(cfg.speedStuds, depth * cfg.gain) * dt) -- 깊이 비례(경계에서 걷기와 부드럽게 균형 - 고정 속도는 매 프레임 들어갔다 나왔다 떨림)
				if blocked(root, dir, step, character) then -- 바깥이 벽 → 옆으로(벽을 따라 빠져나간다) · 둘 다 막히면 그대로(끼임 떨림 방지)
					local side = Vector3.new(-dir.Z, 0, dir.X)
					dir = (not blocked(root, side, step, character) and side) or (not blocked(root, -side, step, character) and -side) or nil
				end
				if dir then
					root.CFrame += dir * step
				end
			end
		end
	end
end)
