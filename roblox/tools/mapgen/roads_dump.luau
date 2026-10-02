-- QUEUE-ALL7 D2: 길(RoadNet.all) · 알려진 지점(허브 시설 · 캠프 · 사냥 지대 · 관문)을 줄로 출력 → render.py가 읽는다.
--   실행: cd roblox/tools/harness && LUAU=<luau.exe> ECON_RES=res_roads.txt python build_run.py ../mapgen/roads_dump.luau
local RoadNet, Layout, D = MODS.RoadNet, MODS.WorldMapLayout, MODS.WorldMapData
for _, road in ipairs(RoadNet.all()) do
	local pts = {}
	for i, p in ipairs(road.pts) do
		if i % 3 == 1 or i == #road.pts then
			table.insert(pts, ("%.1f,%.1f"):format(p.x, p.z))
		end
	end
	print(("[ROAD] %s %s %s"):format(road.kind, road.zone, table.concat(pts, ";")))
end
print(("[POINT] hub 허브 0,0"))
for _, name in ipairs(Layout.facilityOrder) do
	local p = Layout.facility(name)
	print(("[POINT] facility %s %.1f,%.1f"):format(name, p.X, p.Z))
end
for _, zone in ipairs(D.zones) do
	local c = Layout.camp(zone)
	print(("[POINT] camp %s %.1f,%.1f"):format(zone.key, c.X, c.Z))
	for i, g in ipairs(Layout.grounds(zone)) do
		local p = g.center or g.position or g.p or g
		if typeof and typeof(p) == "Vector3" or type(p) == "table" and p.X then
			print(("[POINT] ground %s_%d %.1f,%.1f"):format(zone.key, i, p.X, p.Z))
		end
	end
	local lw = Layout.toWorld(zone, zone.landmark.r + 90, 0) -- QUEUE-ALL8 D5: 실제 놓는 자리(PropScatter · WorldCheck와 같은 식 - 옛 = r만이라 90 stud 어긋난 기준점)
	print(("[POINT] landmark %s %.1f,%.1f"):format(zone.key, lw.X, lw.Z))
	local gate = Layout.gate(zone)
	local gp = gate.position or gate.center or gate
	print(("[POINT] gate %s %.1f,%.1f"):format(zone.key, gp.X, gp.Z))
end
print("[ROADS] 끝")
