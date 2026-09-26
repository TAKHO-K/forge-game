-- M1-3 필드 환경 규칙(서버): 물 판정 · 물살 속도 상한 기록 · 선인장 피해(상한) + 밀림 신호 · 흔들다리는 클라 연출만(여기 없음).
--   부르는 곳: TerrainServer 0.25초 폴링(poll) · DashServer(물속 대시 거절 - inWater) · 검증 M1-3T.
--   수치 = MovementConfig.water · WorldStructureData.cactus.hazard · 흐름 = TerrainShape(클라와 같은 식).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local WorldStructureData = require(ReplicatedStorage.Shared.data.WorldStructureData)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
local PlayerDamage = require(script.Parent.PlayerDamage)

local WorldHazards = {}
local W = MovementConfig.water
local HZ = WorldStructureData.cactus.hazard
WorldHazards.stats = { flowSamples = 0, flowOverCap = 0, flowWarned = 0, cactusHits = 0, cactusCapped = 0, maxFlowSpeed = 0 }

local state = {} -- [Player] = { lastPos, lastAt, over, hits = { t… }, lastHitAt }

local function stateOf(player)
	local st = state[player]
	if not st then
		st = { over = 0, hits = {}, lastHitAt = -math.huge }
		state[player] = st
	end
	return st
end

-- 루트 자리가 물속인가(복셀 - Terrain 물 · 점유율). 루트 칸 또는 그 아래 칸(수면에 떠 있으면 루트가 수면 위 칸에 걸린다: 리뷰)
local function waterCell(position)
	local cell = Vector3.new(math.floor(position.X / 4) * 4, math.floor(position.Y / 4) * 4, math.floor(position.Z / 4) * 4)
	local mats, occs = Workspace.Terrain:ReadVoxels(Region3.new(cell, cell + Vector3.new(4, 4, 4)), 4)
	return mats[1][1][1] == Enum.Material.Water and occs[1][1][1] >= W.inWaterOccupancy
end
function WorldHazards.inWater(position)
	return waterCell(position) or waterCell(position - Vector3.new(0, 2.5, 0))
end

-- 선인장 목록(구조물 빌드와 같은 식 - 도형이 아니라 자리만)
local cactusList = nil
local function cactus()
	if not cactusList then
		cactusList = WorldStructures.data().cactus or {}
	end
	return cactusList
end
local fieldBounds = nil
local function nearCactusField(pos)
	if not fieldBounds then
		fieldBounds = {}
		local zone
		local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
		zone = WorldMapLayout.zoneByKey(WorldStructureData.cactus.zone)
		for _, f in ipairs(WorldStructureData.cactus.fields) do
			local c = WorldMapLayout.toWorld(zone, f.r, f.lat)
			table.insert(fieldBounds, { x = c.X, z = c.Z, r = f.outer + 10 })
		end
	end
	for _, b in ipairs(fieldBounds) do
		if (pos.X - b.x) ^ 2 + (pos.Z - b.z) ^ 2 <= b.r * b.r then
			return true
		end
	end
	return false
end

-- 순수: 선인장 피해를 줄 수 있는가(쿨다운 · 창 상한). hits = 최근 피해 시각 목록(창 밖은 지운다). 반환: "hit" | "cooldown" | "capped"
function WorldHazards.cactusGate(st, now)
	if now - st.lastHitAt < HZ.cooldownSeconds then
		return "cooldown"
	end
	local keep = {}
	for _, t in ipairs(st.hits) do
		if now - t < HZ.windowSeconds then
			table.insert(keep, t)
		end
	end
	st.hits = keep
	if #keep >= HZ.maxPerWindow then
		return "capped"
	end
	st.lastHitAt = now
	table.insert(st.hits, now)
	return "hit"
end
WorldHazards.newState = function()
	return { over = 0, hits = {}, lastHitAt = -math.huge }
end

-- 닿은 선인장(발 높이 · 평면 반경) - 반환: 선인장 또는 nil
function WorldHazards.touchingCactus(rootPos)
	local feet = rootPos.Y - MovementConfig.rootAboveFeetStuds
	for _, c in ipairs(cactus()) do
		local dx, dz = rootPos.X - c.x, rootPos.Z - c.z
		if dx * dx + dz * dz <= (c.touch + HZ.touchStuds) ^ 2 and feet <= c.y + c.h and feet >= c.y - 2 then
			return c
		end
	end
	return nil
end

local pushRemote = nil
function WorldHazards.poll(player, now)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local st = stateOf(player)
	local pos = root.Position
	-- 물살 속도 상한(기록 · 경고만)
	if st.lastPos and st.lastAt and now > st.lastAt then
		local waterY, flow = TerrainShape.waterAt(pos.X, pos.Z)
		if flow and waterY and pos.Y < waterY + 2 then
			local dt = now - st.lastAt
			local v = Vector3.new(pos.X - st.lastPos.X, 0, pos.Z - st.lastPos.Z).Magnitude / dt
			WorldHazards.stats.flowSamples += 1
			WorldHazards.stats.maxFlowSpeed = math.max(WorldHazards.stats.maxFlowSpeed, v)
			local cap = MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier + flow.Magnitude + W.capMarginStuds
			if v > cap and v < W.teleportIgnoreSpeed then -- 그보다 빠름 = 순간이동(Travel이 따로 처리)
				st.over += 1
				WorldHazards.stats.flowOverCap += 1
				if st.over >= W.capStrikes then
					st.over = 0
					WorldHazards.stats.flowWarned += 1
					warn(("[forge-game] 물살 속도 상한 초과: %s 수평 %.1f > %.1f(%d회 연속)"):format(player.Name, v, cap, W.capStrikes))
				end
			else
				st.over = 0
			end
		end
	end
	st.lastPos, st.lastAt = pos, now
	-- 선인장(피해 = 현재 체력 비율 · 이것만으로 안 죽는다 · 쿨다운 · 창 상한 · 밀림 = 클라)
	if nearCactusField(pos) then
		local c = WorldHazards.touchingCactus(pos)
		if c then
			local gate = WorldHazards.cactusGate(st, now)
			if gate == "hit" then
				PlayerDamage.applyCurrentHpFraction(player, HZ.hpFraction, "선인장")
				WorldHazards.stats.cactusHits += 1
				local away = Vector3.new(pos.X - c.x, 0, pos.Z - c.z)
				away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(1, 0, 0)
				if pushRemote then
					pushRemote:FireClient(player, away * HZ.pushSpeed)
				end
			elseif gate == "capped" then
				WorldHazards.stats.cactusCapped += 1
			end
		end
	end
end

function WorldHazards.start()
	if pushRemote then
		return
	end
	pushRemote = Instance.new("RemoteEvent")
	pushRemote.Name = "HazardPush"
	pushRemote.Parent = ReplicatedStorage
	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)
end

function WorldHazards.getState(player)
	return state[player]
end

return WorldHazards
