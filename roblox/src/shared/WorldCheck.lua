-- M1-3 지형 · 둥지 순수 검사(검증 M1-3T(가) · 로컬 하네스 공용). 반환 = { { name, ok, detail } }.
-- 굽기 전 식(TerrainShape)으로 잰다 - 굽기 뒤 실제 복셀 검사(캐릭터 캡슐)는 서버 TerrainBake.capsuleCheck가 한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NestData = require(ReplicatedStorage.Shared.data.NestData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)

local WorldCheck = {}
local FLOOR = WorldMapData.floorTopY
local FLAT = TerrainShape.flatY

local function flatDist(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
local function segDist(p, a, b)
	return (TerrainShape.segDist(p.X, p.Z, a.X, a.Z, b.X, b.Z))
end

-- 필수 길 · 캠프 · 사냥 지대 · 관문(구역마다)
local function essentials()
	local list = {}
	for _, z in ipairs(WorldMapData.zones) do
		-- M1-4: 길 = 곡선(RoadNet 본길 · 갈림길) - 표본 선분(8 간격 · 높이 = 길 높이)
		local RoadNet = require(game:GetService("ReplicatedStorage").Shared.RoadNet)
		for _, path in ipairs({ RoadNet.zonePath(z), RoadNet.branchPath(z) }) do
			local P = path.pts
			for i = 1, #P - 1 do
				local a, b = P[i], P[i + 1]
				table.insert(list, { kind = "road", a = Vector3.new(a.x, a.y, a.z), b = Vector3.new(b.x, b.y, b.z), r = WorldMapData.layout.roadWidth / 2, zone = z.key, name = ("%s 길 %.0f"):format(path.kind == "main" and "본" or "갈림", a.s) })
			end
		end
		for _, g in ipairs(WorldMapLayout.grounds(z)) do
			table.insert(list, { kind = "ground", p = g.center, r = g.radius, zone = z.key, name = "사냥 지대 " .. g.index })
		end
		table.insert(list, { kind = "camp", p = WorldMapLayout.camp(z), r = WorldMapData.layout.camp.radius, zone = z.key, name = "캠프" })
		table.insert(list, { kind = "gate", p = WorldMapLayout.gate(z), r = 40, zone = z.key, name = "관문" })
	end
	return list
end
WorldCheck.essentials = essentials

local function clearOf(p, margin)
	for _, e in ipairs(essentials()) do
		local d = e.kind == "road" and segDist(p, e.a, e.b) or flatDist(p, e.p)
		if d < e.r + margin then
			return false, ("%s %s(%.0f)"):format(e.zone, e.name, d)
		end
	end
	return true
end
WorldCheck.clearOf = clearOf

-- 캐릭터가 서는 자리(발 p)가 지형에 막히지 않는가(식): 발 위 0.5 ~ 5 사이에 지형 윗면이 있으면 그 점이 보호 부피 · 굴 안이어야 한다
local function standClear(p)
	local c = TerrainShape.column(p.X, p.Z)
	if c.h <= p.Y + 0.6 then
		return true
	end
	local near = TerrainShape.airVolumesNear(p.X, p.Z)
	for y = p.Y + 0.5, p.Y + 5, 0.75 do
		if y < c.h and not TerrainShape.airAt(p.X, y, p.Z, near) then
			return false, ("지형 윗면 %.1f > 발 %.1f"):format(c.h, p.Y)
		end
	end
	return true
end
WorldCheck.standClear = standClear

function WorldCheck.run()
	local rows = {}
	local function add(name, ok, detail)
		table.insert(rows, { name = name, ok = ok, detail = detail or "" })
	end
	local nests = WorldStructures.nestList()
	-- 1 트랙 비율(구역당 A 5 · B 3 · C 2 · 허브 C-마을 4) + 순환 후보 5
	local per = {}
	for _, n in ipairs(nests) do
		local k = n.zone
		per[k] = per[k] or { A = 0, B = 0, Cf = 0, Ch = 0, Cv = 0 }
		if n.track == "A" then
			per[k].A += 1
		elseif n.track == "B" then
			per[k].B += 1
		elseif n.sub == "hidden" then
			per[k].Ch += 1
		elseif n.sub == "village" then
			per[k].Cv += 1
		else
			per[k].Cf += 1
		end
	end
	local mixBad = {}
	for _, z in ipairs(WorldMapData.zones) do
		local c = per[z.key] or {}
		if c.A ~= 5 or c.B ~= 3 or c.Cf ~= 1 or c.Ch ~= NestData.rotateCandidates then
			table.insert(mixBad, ("%s A%d B%d C고정%d C순환%d"):format(z.key, c.A or 0, c.B or 0, c.Cf or 0, c.Ch or 0))
		end
	end
	add(("트랙 섞기: 구역마다 A 5 · B 3 · C 2(고정 1 + 순환 후보 %d) · 허브 C-마을 %d"):format(NestData.rotateCandidates, per.hub and per.hub.Cv or 0), #mixBad == 0 and per.hub and per.hub.Cv == 4, table.concat(mixBad, " / "))
	-- 2 도달: 도약마다 이동표(공중 점프 2 + 대시 한도 안 · 80% 여유)
	local bad, hardest = {}, {}
	for _, n in ipairs(nests) do
		for i, l in ipairs(n.leaps or {}) do
			local skill, name = WorldMapLayout.moveSkill(l.rise, l.gap)
			if not skill then
				table.insert(bad, ("%s #%d(오름 %.1f · 간격 %.1f)"):format(n.id, i, l.rise, l.gap))
			elseif skill == "hard" then
				hardest[n.id] = name
			end
		end
	end
	add(("둥지 도달 경로: 도약 전부 공중 점프 2 + 대시 한도 안 - 불가 %d"):format(#bad), #bad == 0, table.concat(bad, " / "))
	-- 3 B · C = 위에서 활강 착지 불가(지붕 또는 지형 지붕 · 입구 폭)
	local roofBad = {}
	for _, n in ipairs(nests) do
		if n.track ~= "A" then
			local ok = false
			if n.roof then
				local c, s = n.roof.center, n.spot
				local cf = n.cf and n.cf.Rotation or CFrame.new()
				local l = CFrame.new(c) * cf
				local lp = l:PointToObjectSpace(s)
				ok = math.abs(lp.X) <= n.roof.halfX + 0.5 and math.abs(lp.Z) <= n.roof.halfZ + 0.5 and n.roof.y >= s.Y + 4
			elseif n.terrainRoof then
				local h = TerrainShape.column(n.spot.X, n.spot.Z).h
				ok = h >= n.spot.Y + 6
			end
			if not ok then
				table.insert(roofBad, n.id)
			end
		end
	end
	add(("B · C 지붕(위에서 착지 불가): 없음 %d"):format(#roofBad), #roofBad == 0, table.concat(roofBad, " / "))
	-- 4 C = 길 안내 · 지도 · 표시 없음(탐험 지점 · 이름표 · 빛 표지와 겹치지 않는다) - 도형 쪽은 검증(나)가 실제 인스턴스로 본다
	local explore = {}
	for _, z in ipairs(WorldMapData.zones) do
		for _, f in ipairs(z.features) do
			if f.explore then
				table.insert(explore, WorldMapLayout.toWorld(z, f.r, f.lat))
			end
		end
	end
	local cBad = {}
	for _, n in ipairs(nests) do
		if n.track == "C" then
			for _, e in ipairs(explore) do
				if flatDist(e, n.spot) < 12 then
					table.insert(cBad, n.id)
				end
			end
		end
	end
	add(("C 둥지가 탐험 지점(발견 목록)과 겹침 %d"):format(#cBad), #cBad == 0, table.concat(cBad, " / "))
	-- 5 둥지가 필수 길 · 캠프 · 사냥 지대 · 관문 밖
	local near = {}
	for _, n in ipairs(nests) do
		if n.zone ~= "hub" and n.kit ~= "feature" and n.kit ~= "landmark" then
			local ok, why = clearOf(n.spot, 18)
			if not ok then
				table.insert(near, n.id .. "↔" .. why)
			end
		end
	end
	add(("둥지 ↔ 필수 길 · 캠프 · 사냥 지대 · 관문 간격 ≥ 18: 위반 %d"):format(#near), #near == 0, table.concat(near, " / "))
	-- 6 지형 통과(식): 둥지 자리 + 입구 → 둥지 경로 점마다 캐릭터 높이(5)만큼 지형이 비었다
	local blocked = {}
	for _, n in ipairs(nests) do
		local pts = { n.spot }
		for _, p in ipairs(n.path or {}) do
			table.insert(pts, p)
		end
		for i = 2, #pts do -- 경로 사이도 2 간격으로
			local a, b = pts[i - 1], pts[i]
			local steps = math.max(1, math.floor((b - a).Magnitude / 2))
			for k = 1, steps - 1 do
				table.insert(pts, a:Lerp(b, k / steps))
			end
		end
		for _, p in ipairs(pts) do
			local ok, why = standClear(p)
			if not ok then
				table.insert(blocked, ("%s(%.0f, %.1f, %.0f %s)"):format(n.id, p.X, p.Y, p.Z, why))
				break
			end
		end
	end
	add(("지형 통과(식 · 캐릭터 높이 5): 막힘 %d"):format(#blocked), #blocked == 0, table.concat(blocked, " / "))
	-- 7 물: 헤엄 둥지 밖은 둥지 자리가 물 위 · 물속이 아니다
	local wet = {}
	for _, n in ipairs(nests) do
		local w = TerrainShape.waterAt(n.spot.X, n.spot.Z)
		if w and w > n.spot.Y - 0.5 and not (n.id == "t3_b_temple") then
			table.insert(wet, n.id)
		end
	end
	add(("둥지 자리 물 잠김(수중 신전 제외) %d"):format(#wet), #wet == 0, table.concat(wet, " / "))
	-- 8 높이 상한: 설계한 오를 곳 ≤ standMaxY − 10 · 외곽 경계 안
	local high, edge = {}, {}
	for _, n in ipairs(nests) do
		if n.spot.Y - FLOOR > WorldMapData.progress.standMaxY - 10 then
			table.insert(high, ("%s %.0f"):format(n.id, n.spot.Y - FLOOR))
		end
		if flatDist(n.spot, Vector3.zero) > TerrainShape.edgeAllowR(n.spot.X, n.spot.Z) - 10 then
			table.insert(edge, n.id)
		end
	end
	add(("둥지 높이 ≤ %d(높은 곳 복귀 규칙) · 외곽 경계 안: 넘음 %d · 밖 %d"):format(WorldMapData.progress.standMaxY - 10, #high, #edge), #high == 0 and #edge == 0, table.concat(high, " / ") .. " " .. table.concat(edge, " / "))
	-- 9 필수 길(M1-4 곡선 · 지형 높이): 가운데 선 4 간격 표본 - 지형 = 길 높이 ± 0.5 · 물 없음 · 길 방향 경사 ≤ 25°(RoadData.capGradeDeg) · 가로 기울기(반폭) ≤ 1
	local RoadData = require(game:GetService("ReplicatedStorage").Shared.data.RoadData)
	local roadBad, samples, maxGrade = {}, 0, 0
	local capTan = math.tan(math.rad(RoadData.capGradeDeg))
	for _, e in ipairs(essentials()) do
		if e.kind == "road" then
			local L = flatDist(e.a, e.b)
			local prevH = nil
			for s = 0, L, 4 do
				local p = e.a:Lerp(e.b, s / math.max(L, 1))
				local c = TerrainShape.column(p.X, p.Z)
				samples += 1
				local dir = Vector3.new(e.b.X - e.a.X, 0, e.b.Z - e.a.Z).Unit
				local side = Vector3.new(-dir.Z, 0, dir.X) * (RoadData.half - 1)
				local cross = math.max(math.abs(TerrainShape.column(p.X + side.X, p.Z + side.Z).h - c.h), math.abs(TerrainShape.column(p.X - side.X, p.Z - side.Z).h - c.h))
				local grade = prevH and math.abs(c.h - prevH) / 4 or 0
				maxGrade = math.max(maxGrade, grade)
				prevH = c.h
				if math.abs(c.h - p.Y) > 0.5 or c.water or grade > capTan or cross > 1 then
					table.insert(roadBad, ("%s %s(%.0f, %.0f) 길 %.1f · 지형 %.1f · 경사 %.0f° · 가로 %.1f%s"):format(e.zone, e.name, p.X, p.Z, p.Y - FLAT, c.h - FLAT, math.deg(math.atan(grade)), cross, c.water and " 물" or ""))
					break
				end
			end
		end
	end
	add(("필수 길(곡선 · 표본 %d · 지형 = 길 높이 ± 0.5 · 물 0 · 경사 ≤ %d° · 가로 ≤ 1 · 최대 경사 %.1f°): 위반 %d"):format(samples, RoadData.capGradeDeg, math.deg(math.atan(maxGrade)), #roadBad), #roadBad == 0, table.concat(roadBad, " / "))
	-- 10 선인장: 필수 길 · 사냥 지대 · 캠프 밖(여유 12)
	local S = WorldStructures.data()
	local cactusBad = {}
	for _, c in ipairs(S.cactus or {}) do
		local ok, why = clearOf(Vector3.new(c.x, 0, c.z), 12)
		if not ok then
			table.insert(cactusBad, why)
		end
	end
	add(("선인장 %d개 - 필수 길 · 사냥 지대 · 캠프 위 %d"):format(#(S.cactus or {}), #cactusBad), #cactusBad == 0 and #(S.cactus or {}) > 0, table.concat(cactusBad, " / "))
	-- 11 물살 강 기슭: 5 간격 표본마다 20 안에 빠져나갈 곳(계곡 = 기슭 계단 · 그 밖 = 둑 경사 ≤ 40°)
	local exitBad, rsamples, worstAt = 0, 0, nil
	local worst = 0
	for _, z in ipairs(WorldMapData.zones) do
		local R = TerrainGenData.zones[z.key] and TerrainGenData.zones[z.key].river
		if R then
			for i = 3, #R.pts - 1 do -- 평지 강(샘 · 계단 폭포 · 바다 끝 제외)
				local a, b = WorldMapLayout.toWorld(z, R.pts[i][1], R.pts[i][2]), WorldMapLayout.toWorld(z, R.pts[i + 1][1], R.pts[i + 1][2])
				local L = flatDist(a, b)
				local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
				local side = Vector3.new(-dir.Z, 0, dir.X)
				local gorge = R.gorge and i >= R.gorge.from and i < R.gorge.to
				for s = 0, L, 5 do
					rsamples += 1
					local p = a + dir * s
					local nearest = math.huge
					for _, e in ipairs(S.gorgeExits or {}) do -- 기슭 계단(계곡 벽이 끝나는 둘레까지)
						nearest = math.min(nearest, flatDist(e.pos, p) - R.width / 2)
					end
					if not gorge then
						for _, sx in ipairs({ -1, 1 }) do -- 둑: 물가(수면 높이)에서 8 들어가며 경사
							local q0 = p + side * sx * (R.width / 2)
							local h0 = TerrainShape.column(q0.X, q0.Z).h
							local q1 = q0 + side * sx * 8
							local h1 = TerrainShape.column(q1.X, q1.Z).h
							if math.deg(math.atan((h1 - h0) / 8)) <= 40 then
								nearest = 0
							end
						end
					end
					worst = math.max(worst, nearest)
					if nearest > 20 then
						exitBad += 1
						worstAt = worstAt or ("(%.0f, %.0f)%s"):format(p.X, p.Z, gorge and " 계곡" or "")
					end
				end
			end
		end
	end
	add(("물살 강 기슭(표본 %d · 20 안에 빠져나갈 곳): 없음 %d · 가장 먼 %.1f"):format(rsamples, exitBad, worst), exitBad == 0 and rsamples > 0, worstAt)
	-- 12 구조물 겹침: 둥지(받침 반경) ↔ 둥지 · 옛 지형 · 랜드마크 · 폐허(같은 구조물 안 = 신전 뒤 번개 문은 제외)
	local solids = {}
	for _, n in ipairs(nests) do
		local spec = nil
		for _, sp in ipairs(NestData.nests) do
			if sp.id == n.id then
				spec = sp
			end
		end
		-- 랜드마크 고리 안(쓰러진 돌판 밑 - 고리 가운데는 비어 있다)은 일부러 겹친다
		if n.zone ~= "hub" and n.kit ~= "feature" and n.kit ~= "landmark" and n.kit ~= "sunken" and n.kit ~= "bridgeHut" and not (spec and spec.inLandmark) then
			local c = n.cf and n.cf.Position or n.spot
			local r = (n.pads and n.pads[1] and n.pads[1].radius) or 8
			table.insert(solids, { name = n.id, p = c, r = math.min(r, 30) })
		end
	end
	for _, z in ipairs(WorldMapData.zones) do
		for i, f in ipairs(z.features) do
			local fp = math.max(f.w or 0, f.d or 0, (f.size or 0) * 1.5 + 12) / 2 + ((f.kind == "plateau") and f.h / math.tan(math.rad(33)) or 0)
			table.insert(solids, { name = ("%s 옛 지형 %d(%s)"):format(z.key, i, f.kind), p = WorldMapLayout.toWorld(z, f.r, f.lat), r = fp })
		end
		table.insert(solids, { name = z.key .. " 랜드마크", p = WorldMapLayout.toWorld(z, z.landmark.r + 90, 0), r = z.landmark.radius + 10 })
	end
	if S.structures.colonnade then
		table.insert(solids, { name = "폐허", p = S.structures.colonnade.center, r = 40 })
	end
	local overlap = {}
	for i = 1, #solids do
		for j = i + 1, #solids do
			local a, b = solids[i], solids[j]
			if flatDist(a.p, b.p) < a.r + b.r + 4 and not (a.name:find("t5_c_h1") or b.name:find("t5_c_h1")) then
				table.insert(overlap, a.name .. "↔" .. b.name)
			end
		end
	end
	add(("구조물 겹침(둥지 · 옛 지형 · 랜드마크 · 폐허 %d개): %d"):format(#solids, #overlap), #overlap == 0, table.concat(overlap, " / "))
	return rows, { hardest = hardest }
end

return WorldCheck
