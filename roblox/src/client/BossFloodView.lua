-- 심해 군주의 단(29-4, PRD 20.79). 서버는 "누가 어느 단을 언제 밟았는가"만 갖고, 단이 가라앉는 그림과 발밑 충돌은
-- **각자의 클라가 자기 시계로** 한다 - 그래서 친구가 먼저 밟은 단이 내 발밑에서 꺼지는 일이 구조적으로 없다.
--   · 단은 서버의 정적 kit 파트(FloodPlatform)다. 여기서는 그 파트의 CFrame을 **이 클라에서만** 내린다 - 서버 인스턴스는
--     한 번도 움직이지 않는다(서버가 CFrame을 다시 쓰지 않으므로 로컬 변경이 유지된다). 캐릭터 물리는 클라 소유라 내
--     캐릭터는 가라앉는 단과 함께 실제로 물에 빠진다.
--   · 전조: 예고 뒤 earlySeconds 동안은 단 윗면도 빨강이다("지금 올라가면 방전 전에 가라앉는다" - 빨강 = 지금 여기 있으면
--     맞는다, 25-4). 빨강이 걷히면 올라간다. 수면(위험색 판)이 차오르는 것은 BossArenaPropsView가 그린다.
--   · 내가 밟은 단: 윗면에서 흰 네모가 자란다 - 다 차면 가라앉는다(낙석의 "안쪽에서 자라는 흰 원"과 같은 언어: 흰색 =
--     남은 시간). 마지막 shakeSeconds 동안 단이 흔들린다.
-- 새 색·새 파티클·새 에셋 없음.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local BossFloodView = {}

local DANGER_COLOR = UIColors.danger
local INFO_COLOR = Color3.new(1, 1, 1)
local PLATFORM_NAME = "FloodPlatform" -- BossData abyssalKitParts의 파트 이름
local SINK_SECONDS = 0.4
local SINK_EXTRA_STUDS = 0.6 -- 윗면이 바닥 밑으로 이만큼 더 내려간다(수면 아래로 완전히 사라진다)

local overlays = {} -- 이번 범람이 만든 그림(빨강 윗면·흰 네모)
local sunk = {} -- [part] = 원래 CFrame
local generation = 0 -- 범람이 끝나면 올라간다 - 늦게 깨어난 task.delay가 다음 범람의 단을 건드리지 않게

local function newPlate(center, size, color, transparency)
	local plate = Instance.new("Part")
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CastShadow = false
	plate.Material = Enum.Material.Neon
	plate.Color = color
	plate.Transparency = transparency
	plate.Size = size
	plate.CFrame = CFrame.new(center)
	plate.Parent = Workspace
	table.insert(overlays, plate)
	return plate
end

local function topOf(zone)
	return zone.center + Vector3.new(0, zone.size.Y / 2 + 0.06, 0)
end

-- 그 단을 이루는 서버 파트(윗단 + 아랫단) - 이름이 같고 XZ 중심이 같은 것.
local function platformParts(zone)
	local parts = {}
	local ground = Workspace:FindFirstChild("Ground")
	for _, part in ipairs(ground and ground:GetChildren() or {}) do
		if part.Name == PLATFORM_NAME and math.abs(part.Position.X - zone.center.X) < 1 and math.abs(part.Position.Z - zone.center.Z) < 1 then
			table.insert(parts, part)
		end
	end
	return parts
end

-- data = gimmickTelegraph 이벤트의 safeZone = { zones = { { index, center, size } }, sinkSeconds, earlySeconds, riseStuds }
function BossFloodView.telegraph(safeZone)
	BossFloodView.reset()
	if safeZone.earlySeconds <= 0 then
		return
	end
	for _, zone in ipairs(safeZone.zones) do
		local plate = newPlate(topOf(zone), Vector3.new(zone.size.X, 0.1, zone.size.Z), DANGER_COLOR, 0.4)
		task.delay(safeZone.earlySeconds, function()
			plate:Destroy() -- 빨강이 걷혔다 = 이제 올라가도 방전까지 버틴다
		end)
	end
end

-- data = { index, center, size, floorY(아레나 바닥 윗면), sinkSeconds, shakeSeconds } - 내가 방금 밟은 단.
function BossFloodView.step(data)
	local mine = generation
	local clock = newPlate(topOf(data), Vector3.new(1, 0.12, 1), INFO_COLOR, 0.35)
	TweenService:Create(clock, TweenInfo.new(data.sinkSeconds, Enum.EasingStyle.Linear), {
		Size = Vector3.new(data.size.X, 0.12, data.size.Z),
	}):Play()

	local parts = platformParts(data)
	task.delay(math.max(data.sinkSeconds - data.shakeSeconds, 0), function()
		if mine ~= generation then
			return
		end
		for _, part in ipairs(parts) do
			sunk[part] = sunk[part] or part.CFrame
			-- 흔들림: 0.1초짜리 작은 오르내림을 shakeSeconds 동안 되풀이한다.
			TweenService:Create(part, TweenInfo.new(0.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.max(math.floor(data.shakeSeconds / 0.2) - 1, 0), true), {
				CFrame = sunk[part] + Vector3.new(0, 0.25, 0),
			}):Play()
		end
	end)
	task.delay(data.sinkSeconds, function()
		if mine ~= generation then
			return
		end
		clock:Destroy()
		for _, part in ipairs(parts) do
			sunk[part] = sunk[part] or part.CFrame
			local drop = (sunk[part].Position.Y + part.Size.Y / 2) - data.floorY + SINK_EXTRA_STUDS
			TweenService:Create(part, TweenInfo.new(SINK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				CFrame = sunk[part] - Vector3.new(0, drop, 0),
			}):Play()
		end
	end)
end

-- 범람이 끝났다(정상·중단·리셋·보스전 종료) - 가라앉은 단을 전부 제자리로, 그림은 지운다.
function BossFloodView.reset()
	generation += 1
	for _, plate in ipairs(overlays) do
		plate:Destroy()
	end
	overlays = {}
	for part, original in pairs(sunk) do
		if part.Parent then
			TweenService:Create(part, TweenInfo.new(SINK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = original }):Play()
		end
	end
	sunk = {}
end

return BossFloodView
