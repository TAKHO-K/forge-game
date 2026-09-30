-- QUEUE-ALL3 Q3 퀘스트 [길 안내] 목적지(QuestData.main[].guide → 월드 자리). 퀘스트 창 · 오늘의 목표 칸이 같이 쓴다. 안내 · 자동 이동 = MapPins.go(Wayfinder owner "mapPin").
--   gate = 다음 보스 관문(계정 최고 보스 + 5 스테이지의 보스) · hunt = 지금(또는 가장 먼 열린) 구역 사냥 지대 1 · forge = 대장간 · altar = 환생 제단(커뮤니티 광장) · hub = 허브 가운데
--   lookout = 큰 나무 코스 시작(뿌리 정거장 쪽 - 위로는 발판을 따라) · zone:<key> = 그 구역 입구 캠프 · checkpoint = 가장 가까운 안 찾은 체크포인트(없으면 nil).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local MapPins = require(script.Parent.MapPins)

local QuestGuide = {}

local player = Players.LocalPlayer

local function currentZone()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local zone = root and WorldMapLayout.zoneAt(root.Position)
	if zone then
		return zone
	end
	local unlocked = player:GetAttribute("ZonesUnlocked") or WorldMapData.progress.startUnlocked
	return WorldMapData.zones[math.clamp(unlocked, 1, #WorldMapData.zones)]
end

-- 반환 position, 이름(빛기둥 글씨) | nil
function QuestGuide.target(guide)
	if not guide then
		return nil
	end
	if guide == "gate" then
		local BossRules = require(ReplicatedStorage.Shared.BossRules)
		local best = player:GetAttribute("BestBossCleared") or 0
		local bossId = BossRules.bossIdForStage(best - best % 5 + 5)
		local gate = bossId and WorldMapLayout.bossGate(bossId)
		if gate then
			return gate.position, gate.name
		end
	elseif guide == "hunt" then
		local zone = currentZone()
		return WorldMapLayout.grounds(zone)[1].center, zone.hunt.name
	elseif guide == "forge" then
		return WorldMapLayout.facility("forge"), WorldMapData.hub.facilities.forge.displayName
	elseif guide == "altar" then
		return WorldMapLayout.facility("community"), WorldMapData.hub.facilities.community.displayName
	elseif guide == "hub" or guide == "lookout" then
		return WorldMapLayout.spawnPoint(), guide == "lookout" and "큰 나무 오르기" or "허브"
	elseif guide:sub(1, 5) == "zone:" then
		local zone = WorldMapLayout.zoneByKey(guide:sub(6))
		if zone then
			return WorldMapLayout.camp(zone), zone.theme
		end
	elseif guide == "checkpoint" and WorldMapData.checkpoints then
		local found = "," .. tostring(player:GetAttribute("CheckpointsFound") or "") .. ","
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestD, bestName
		for _, cp in ipairs(WorldMapData.checkpoints.list) do
			if not found:find("," .. cp.id .. ",", 1, true) then
				local pos = cp.zone and WorldMapLayout.camp(WorldMapLayout.zoneByKey(cp.zone)) or WorldMapLayout.spawnPoint()
				local d = root and (pos - root.Position).Magnitude or 0
				if not bestD or d < bestD then
					best, bestD, bestName = pos, d, cp.name
				end
			end
		end
		return best, bestName
	end
	return nil
end

-- 길 안내 켜기(auto = 자동 이동도). 반환 = 켰나
function QuestGuide.go(guide, auto)
	local pos, name = QuestGuide.target(guide)
	if not pos then
		return false
	end
	return MapPins.go(pos, name, auto)
end

return QuestGuide
