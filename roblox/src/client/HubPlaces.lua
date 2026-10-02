-- QUEUE-ALL7B 4 허브 이름 자리 목록(지도 창 이름 · 미니맵 말풍선 공용): 마을 기능(HubServiceData) · 이름 있는 건물(HubArtData.buildingNames) · 아이콘 있는 NPC.
--   항목 = { kind = "service" | "building" | "npc", icon(없으면 이름만), name(내 언어), position, priority(작을수록 먼저 자리 잡음) } · 같은 자리(8 stud 안) 마을 기능이 있는 NPC는 뺀다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubServiceData = require(ReplicatedStorage.Shared.data.HubServiceData)
local HubArtData = require(ReplicatedStorage.Shared.data.HubArtData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local Text = require(ReplicatedStorage.Shared.Text)

local HubPlaces = {}

function HubPlaces.list()
	local out = {}
	for _, s in ipairs(HubServiceData.services) do
		local pos = WorldMapLayout.spot(s.spot)
		if pos then
			table.insert(out, { kind = "service", icon = s.icon, name = Text.get(s.nameKey), position = pos, priority = 2 })
		end
	end
	for _, name in ipairs(WorldMapLayout.facilityOrder) do
		for _, b in ipairs(WorldMapLayout.rowBuildings(name)) do
			local label = b.kind and HubArtData.buildingNames[b.kind]
			if label then
				table.insert(out, { kind = "building", name = Text.name(label), position = b.cf.Position, priority = 1 })
			end
		end
	end
	for _, n in ipairs(HubArtData.npcs) do
		local pos = WorldMapLayout.spot(n.spot)
		if pos and n.icon then
			local off = n.offset or { 0, 0 }
			pos += Vector3.new(off[1], 0, off[2])
			local dup = false
			for _, e in ipairs(out) do
				if e.kind == "service" and ((e.position - pos) * Vector3.new(1, 0, 1)).Magnitude < 8 then
					dup = true
				end
			end
			if not dup then
				table.insert(out, { kind = "npc", icon = n.icon, name = Text.name(n.name), position = pos, priority = 3 })
			end
		end
	end
	return out
end

return HubPlaces
