-- M2 성향 카드(MonsterSpeciesData) 판정 - MonsterAI가 부른다. 종이 없는 몹(옛 티어 data · 보스 · 검증 표본)은 옛 규칙 그대로(어그로 25.6 · 리쉬 38.4).
--   선공(aggressive) · 매복(ambush) = detectRadius 안 가장 가까운 사람 · 추적(chase) = 같되 이미 추적형 chaseCapPerPlayer마리에게 쫓기는 사람은 건너뜀 ·
--   비선공(passive) · 무리(pack) = 맞은 뒤에만 반격(가장 가까운 사람 - 리쉬 거리 안) · 무리는 같은 PackId의 쉬는 몹도 같이 반격(linkAggro).
--   안전 지대(허브 잎 덮개 · 구역 캠프) 안의 사람은 새로 노리지 않고, 쫓던 사람이 들어가면 놓고 돌아간다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MonsterState = require(script.Parent.MonsterState)

local T = {}

local RETALIATE_SECONDS = 1.5 -- 비선공: 맞은 뒤 이 시간 안이면 반격을 건다

-- 안전 지대 원(수평) 목록 - 허브 + 구역 캠프마다
local safeCircles = {}
do
	local margin = MonsterSpeciesData.safeZoneMarginStuds
	local hub = WorldMapLayout.hubPoint(0, 0)
	table.insert(safeCircles, { x = hub.X, z = hub.Z, r = WorldMapData.hub.safeRadius + margin })
	for _, zone in ipairs(WorldMapData.zones) do
		local camp = WorldMapLayout.camp(zone)
		table.insert(safeCircles, { x = camp.X, z = camp.Z, r = WorldMapData.layout.camp.radius + margin })
	end
end

function T.inSafeZone(position)
	for _, c in ipairs(safeCircles) do
		local dx, dz = position.X - c.x, position.Z - c.z
		if dx * dx + dz * dz <= c.r * c.r then
			return true
		end
	end
	return false
end

function T.speciesOf(data)
	return data and not data.isBoss and data.species or nil
end

function T.leashOf(data)
	local s = T.speciesOf(data)
	return s and s.leashDistance or WorldConfig.aggro.leashRangeStuds
end

-- 이 사람을 지금 쫓는 추적형 수
function T.chaseCount(player)
	local n = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		if MonsterState.getAiTarget(model) == player then
			local s = T.speciesOf(MonsterState.getData(model))
			if s and s.aggro == "chase" then
				n += 1
			end
		end
	end
	return n
end

-- idle 몹이 새로 노릴 사람. findNearest(position, range, model, filter) = MonsterAI의 가장 가까운 사람 찾기. 반환: player, root, 이유("detect" | "retaliate")
function T.acquire(model, data, position, findNearest)
	local s = T.speciesOf(data)
	if not s then
		local p, r = findNearest(position, WorldConfig.aggro.rangeStuds, model)
		return p, r, "detect"
	end
	local notSafe = function(root)
		return not T.inSafeZone(root.Position)
	end
	if s.aggro == "aggressive" or s.aggro == "ambush" or s.aggro == "chase" then
		local filter = notSafe
		if s.aggro == "chase" then
			filter = function(root, player)
				return notSafe(root) and T.chaseCount(player) < MonsterSpeciesData.chaseCapPerPlayer
			end
		end
		local p, r = findNearest(position, s.detectRadius, model, filter)
		if p then
			return p, r, "detect"
		end
	end
	-- 맞았으면 반격(모든 성향 - 선공도 감지 반경 밖에서 맞으면 돌아본다)
	local hitAt = MonsterState.getLastDamagedAt(model)
	if hitAt and os.clock() - hitAt <= RETALIATE_SECONDS then
		local p, r = findNearest(position, s.leashDistance, model, notSafe)
		if p then
			return p, r, "retaliate"
		end
	end
	return nil
end

-- 무리 반격: 같은 PackId의 쉬는 몹을 같은 사람에게. begin(model, player) = MonsterAI의 추격 시작(눈금 설정 포함).
function T.linkPack(model, data, player, begin)
	local s = T.speciesOf(data)
	local pack = model:GetAttribute("PackId")
	if not (s and s.linkAggro and pack) then
		return 0
	end
	local n = 0
	for _, other in ipairs(MonsterState.getAllModels()) do
		if other ~= model and other:GetAttribute("PackId") == pack and MonsterState.getAiState(other) == "idle" then
			begin(other, MonsterState.getData(other), player)
			n += 1
		end
	end
	return n
end

-- 알림 모션(클라 연출용 Attribute - 판정 없음)
function T.alert(model, data)
	local s = T.speciesOf(data)
	if s and s.alertMotion then
		model:SetAttribute("MobAlert", s.alertMotion .. "|" .. tostring(os.clock()))
	end
end

-- 복귀 도착: 체력 회복(잡몹 = 비율 HP · 기여 초기화 - 이탈 뒤 공짜 처치 방지)
function T.onReturnedHome(model, data)
	if T.speciesOf(data) then
		MonsterState.resetTrash(model)
		require(script.Parent.MonsterSpawner).updateHpLabel(model)
	end
end

return T
