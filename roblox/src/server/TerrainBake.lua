-- M1-3 지형 굽기(Studio 전용 도구 - 런타임 생성 금지). 식 = shared/TerrainShape(결정적) · 수치 = data/TerrainGenData.
--   Rojo는 Terrain 복셀을 동기화하지 않는다 → 생성기만 git에 두고 결과는 place에 굽는다(docs/perf/streaming-settings.md "place 전용 항목").
--   굽기: Studio **edit 모드** 명령줄(또는 MCP execute_luau)에서 require(game.ServerScriptService.TerrainBake).build("tier1") → 구역마다 → place 저장.
--         Play 중 "/gg terrain build <구역>"은 미리보기(Play가 끝나면 사라진다).
--   구역 = 방위 쐐기(허브 반경 안 = "hub"). 덩어리(CHUNK 칸)마다 기존 복셀을 읽어 이 구역 열만 바꿔 쓴다(이웃 구역을 지우지 않는다).
--   보호 부피(둥지 · 통로 · 굴): 1차 = 복셀 계산에서 공기 · 2차 = 굽기 끝에 FillBlock/FillBall(Air · 물 부피는 Water)로 한 번 더(사용자 보강 ① - 매끄럽게 처리 · 번짐 대비).
--   표식: Terrain Attribute TerrainVersion_<구역>(TerrainGenData.version) · TerrainSig_<구역>(표본 높이 해시) - 서버 시작 때 다르면 경고만(checkVersion).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)

local TerrainBake = {}
local G = TerrainGenData
local V = G.voxel
local CHUNK = 64 -- 칸(= 256 stud)
local CEILING = 640 -- 지형이 닿을 수 있는 가장 높은 곳보다 위(봉우리 최대 약 470)
local FLOOR = WorldMapData.floorTopY

local function ownerOf(x, z)
	if x * x + z * z < G.hub.radius * G.hub.radius then
		return "hub"
	end
	return TerrainShape.zoneAt(x, z).key
end
TerrainBake.ownerOf = ownerOf

-- 구역 쐐기의 칸 범위(월드 경계 상자)
local function boundsOf(key)
	local R = G.edge.outer
	if key == "hub" then
		local r = G.hub.radius + 8
		return -r, -r, r, r
	end
	local zone
	for _, z in ipairs(WorldMapData.zones) do
		if z.key == key then
			zone = z
		end
	end
	assert(zone, "구역 없음: " .. tostring(key))
	local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
	for a = zone.angleDeg - 31, zone.angleDeg + 31, 2 do
		for _, r in ipairs({ G.hub.radius - 8, R }) do
			local x, z = math.cos(math.rad(a)) * r, math.sin(math.rad(a)) * r
			minX, maxX, minZ, maxZ = math.min(minX, x), math.max(maxX, x), math.min(minZ, z), math.max(maxZ, z)
		end
	end
	return minX, minZ, maxX, maxZ
end

local MATERIALS = {}
local function mat(name)
	local m = MATERIALS[name]
	if not m then
		m = Enum.Material[name]
		MATERIALS[name] = m
	end
	return m
end

-- 덩어리 하나 굽기. 반환: 바꾼 열 수 · 쓴 복셀 수
local function bakeChunk(terrain, key, cx, cz)
	local x0, z0 = cx * CHUNK * V, cz * CHUNK * V
	-- 열 계산(+1 테두리 - 기울기)
	local cols = {}
	local owned = 0
	local topY, lowY = -math.huge, math.huge
	local topAll = -math.huge -- 이 덩어리 모든 열(이웃 구역 포함)의 새 최고 높이 - 그 위에 남은 옛 복셀을 비운다
	for i = 0, CHUNK + 1 do
		cols[i] = {}
		for k = 0, CHUNK + 1 do
			local x, z = x0 + (i - 0.5) * V, z0 + (k - 0.5) * V
			local inWorld = x * x + z * z <= G.edge.outer * G.edge.outer
			if inWorld then
				local c = TerrainShape.column(x, z)
				c.x, c.z = x, z
				c.own = (i >= 1 and i <= CHUNK and k >= 1 and k <= CHUNK) and ownerOf(x, z) == key
				cols[i][k] = c
				if i >= 1 and i <= CHUNK and k >= 1 and k <= CHUNK then
					topAll = math.max(topAll, c.h, c.water or -math.huge)
				end
				if c.own then
					owned += 1
					topY = math.max(topY, c.h, c.water or -math.huge)
					lowY = math.min(lowY, c.h)
				end
			end
		end
	end
	if owned == 0 then
		return 0, 0
	end
	local y0 = math.floor((FLOOR + G.bottomY) / V) * V
	local airTop = 0
	for i = 1, CHUNK do
		for k = 1, CHUNK do
			local c = cols[i][k]
			if c and c.own then
				c.air = TerrainShape.airVolumesNear(c.x, c.z)
				if c.air then
					for _, v in ipairs(c.air) do
						airTop = math.max(airTop, v.maxY)
					end
				end
			end
		end
	end
	local y1 = math.ceil((math.max(topY, airTop) + V) / V) * V
	local ny = (y1 - y0) / V
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + CHUNK * V, y1, z0 + CHUNK * V)):ExpandToGrid(V)
	local mats, occs = terrain:ReadVoxels(region, V)
	local written = 0
	local air, water = Enum.Material.Air, Enum.Material.Water
	for i = 1, CHUNK do
		for k = 1, CHUNK do
			local c = cols[i][k]
			if c and c.own then
				-- 기울기(도) = 이웃 열 높이 차
				local e, w, n, s = cols[i + 1][k], cols[i - 1][k], cols[i][k + 1], cols[i][k - 1]
				local dx = ((e and e.h or c.h) - (w and w.h or c.h)) / (2 * V)
				local dz = ((n and n.h or c.h) - (s and s.h or c.h)) / (2 * V)
				local slope = math.deg(math.atan(math.sqrt(dx * dx + dz * dz)))
				local solid = mat(TerrainShape.material(c.x, c.z, c, slope))
				-- 공기 부피 칸 표시(위에서 아래로 - 공기 칸 바로 아래 칸은 부피 바닥에 맞춘다)
				local airCell, airFloor = nil, nil
				if c.air then
					airCell, airFloor = {}, {}
					for j = 1, ny do
						local yc = y0 + (j - 1) * V + V / 2
						if yc < c.h + V then
							local inside, _, floor = TerrainShape.airAt(c.x, yc, c.z, c.air)
							if inside then
								airCell[j], airFloor[j] = true, floor
							end
						end
					end
				end
				for j = 1, ny do
					local yb = y0 + (j - 1) * V
					local yc = yb + V / 2
					-- 표면 = 가장 위 칸 바닥 + V/2 + V × 점유율(Studio 실측 - 점유율 0.01 → +2.05 · 0.5 → +4 · 1 → +6) → 점유율 = (h − V/2 − 칸 바닥) / V
					local occ = math.clamp((c.h - V / 2 - yb) / V, 0, 1)
					if airCell and not airCell[j] and airCell[j + 1] and airFloor[j + 1] then
						occ = math.min(occ, math.clamp((airFloor[j + 1] - V / 2 - yb) / V, 0, 1)) -- 부피 바닥 바로 아래 칸(바닥이 칸 위로 솟지 않게)
					end
					local m = occ > 0 and solid or air
					if c.air and occ > 0 and airCell and airCell[j] then
						local inside, wy = TerrainShape.airAt(c.x, yc, c.z, c.air)
						if inside then
							if wy and yb < wy then
								m, occ = water, math.clamp((wy - V / 2 - yb) / V, 0, 1)
							else
								m, occ = air, 0
							end
						end
					end
					if occ < 0.5 and c.water and yb < c.water - V / 2 then
						m, occ = water, math.clamp((c.water - V / 2 - yb) / V, 0, 1)
					end
					if occ <= 0 then
						m, occ = air, 0
					end
					mats[i][j][k] = m
					occs[i][j][k] = occ
					written += 1
				end
			end
		end
	end
	terrain:WriteVoxels(region, V, mats, occs)
	-- 옛 굽기가 더 높게 쌓은 복셀(모양을 낮춘 뒤 떠 있는 판으로 남았다 - M1-3 스크린샷): 이 덩어리 새 최고 높이 + 공기 부피 위를 천장까지 비운다
	local clearFrom = math.ceil((math.max(topAll, airTop) + V * 2) / V) * V
	if clearFrom < CEILING then
		terrain:FillBlock(CFrame.new(x0 + CHUNK * V / 2, (clearFrom + CEILING) / 2, z0 + CHUNK * V / 2), Vector3.new(CHUNK * V, CEILING - clearFrom, CHUNK * V), Enum.Material.Air)
	end
	return owned, written
end

-- 2차 비우기(보호 부피 - 이 구역 것만): 상자 = FillBlock · 굴 = FillBall 줄. 물 부피는 물로(물 높이 아래만).
function TerrainBake.reclear(terrain, key)
	local _, struct = TerrainShape.masks()
	local count = 0
	local m = G.protectMargin
	for _, v in ipairs(struct and struct.air or {}) do
		local cx, cz = (v.minX + v.maxX) / 2, (v.minZ + v.maxZ) / 2
		if ownerOf(cx, cz) == key then
			if v.kind == "box" then
				local size = v.half * 2 + Vector3.new(m * 2, m, m * 2)
				terrain:FillBlock(v.cf * CFrame.new(0, m / 2, 0), size, v.water and Enum.Material.Water or Enum.Material.Air)
			elseif v.kind == "tunnel" then
				for i = 2, #v.pts do
					local a, b = v.pts[i - 1], v.pts[i]
					local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
					for t = 0, 1, 2 / math.max(L, 2) do
						local y = a[3] + (b[3] - a[3]) * t + v.radius * 0.6
						local p = Vector3.new(a[1] + (b[1] - a[1]) * t, y, a[2] + (b[2] - a[2]) * t)
						terrain:FillBall(p, v.radius, (v.water and y < v.water) and Enum.Material.Water or Enum.Material.Air)
					end
				end
			end
			count += 1
		end
	end
	return count
end

-- 재질 색 · 물 모양(place 속성 - 굽기가 정한다)
function TerrainBake.applyLook(terrain)
	for name, c in pairs(G.materialColors) do
		terrain:SetMaterialColor(Enum.Material[name], Color3.fromRGB(c[1], c[2], c[3]))
	end
	local W = G.water
	terrain.WaterColor = Color3.fromRGB(W.color[1], W.color[2], W.color[3])
	terrain.WaterTransparency = W.transparency
	terrain.WaterWaveSize = W.waveSize
	terrain.WaterWaveSpeed = W.waveSpeed
	terrain.WaterReflectance = W.reflectance
end

-- 표본 높이 해시(데이터를 바꾸고 다시 안 구웠는지 - 버전 숫자를 안 올린 경우도 잡는다)
function TerrainBake.signature(key)
	local x0, z0, x1, z1 = boundsOf(key)
	local h = 17
	local n = 0
	for i = 0, 19 do
		for k = 0, 19 do
			local x, z = x0 + (x1 - x0) * (i + 0.5) / 20, z0 + (z1 - z0) * (k + 0.5) / 20
			if x * x + z * z <= G.edge.outer ^ 2 and ownerOf(x, z) == key then
				local c = TerrainShape.column(x, z)
				h = (h * 31 + math.floor(c.h * 4 + 0.5) + (c.water and 7 or 0)) % 1000000007
				n += 1
			end
		end
	end
	return ("%d-%d"):format(n, h)
end

-- 한 구역 굽기. 반환: { key, chunks, columns, voxels, protect, seconds }
function TerrainBake.build(key, opts)
	opts = opts or {}
	local terrain = Workspace.Terrain
	local t0 = os.clock()
	TerrainShape.reset()
	TerrainBake.applyLook(terrain)
	local x0, z0, x1, z1 = boundsOf(key)
	local span = CHUNK * V
	local chunks, columns, voxels = 0, 0, 0
	local idx = 0
	for cx = math.floor(x0 / span), math.floor(x1 / span) do
		for cz = math.floor(z0 / span), math.floor(z1 / span) do
			idx += 1
			if (not opts.from or idx >= opts.from) and (not opts.to or idx <= opts.to) then
				local c, v = bakeChunk(terrain, key, cx, cz)
				if c > 0 then
					chunks += 1
					columns += c
					voxels += v
				end
				if opts.yield then
					task.wait()
				end
			end
		end
	end
	local protect = 0
	if not opts.to or opts.final then
		protect = TerrainBake.reclear(terrain, key)
		terrain:SetAttribute("TerrainVersion_" .. key, G.version[key])
		terrain:SetAttribute("TerrainSig_" .. key, TerrainBake.signature(key))
		terrain:SetAttribute("TerrainBakedAt_" .. key, os.time())
	end
	local out = { key = key, chunks = chunks, columns = columns, voxels = voxels, protect = protect, seconds = os.clock() - t0, chunkIndexMax = idx }
	print(("[forge-game] 지형 굽기 %s: 덩어리 %d · 열 %d · 복셀 %d · 보호 부피 다시 비움 %d · %.1f초"):format(key, chunks, columns, voxels, protect, out.seconds))
	return out
end

function TerrainBake.buildAll(opts)
	local list = { "hub" }
	for _, z in ipairs(WorldMapData.zones) do
		table.insert(list, z.key)
	end
	local out = {}
	for _, key in ipairs(list) do
		table.insert(out, TerrainBake.build(key, opts))
	end
	return out
end

function TerrainBake.clear()
	Workspace.Terrain:Clear()
	for name in pairs(Workspace.Terrain:GetAttributes()) do
		if name:match("^Terrain") then
			Workspace.Terrain:SetAttribute(name, nil)
		end
	end
end

-- 서버 시작: 굽힌 지형의 버전 · 서명이 데이터와 같은가(경고만 - 런타임 생성 금지). 반환: 불일치 목록
function TerrainBake.checkVersion()
	local terrain = Workspace.Terrain
	local bad = {}
	local keys = { "hub" }
	for _, z in ipairs(WorldMapData.zones) do
		table.insert(keys, z.key)
	end
	for _, key in ipairs(keys) do
		local v = terrain:GetAttribute("TerrainVersion_" .. key)
		local sig = terrain:GetAttribute("TerrainSig_" .. key)
		local want = TerrainBake.signature(key)
		if v ~= G.version[key] or sig ~= want then
			table.insert(bad, ("%s(버전 %s/%s · 서명 %s/%s)"):format(key, tostring(v), tostring(G.version[key]), tostring(sig), want))
		end
	end
	if #bad > 0 then
		warn("[forge-game] 지형 표식 불일치 - Studio에서 다시 굽고 place 저장 필요(docs/perf/streaming-settings.md): " .. table.concat(bad, " / "))
	else
		print("[forge-game] 지형 표식 일치(구역 7)")
	end
	return bad
end

-- ─────────────────────────── 굽기 뒤 캐릭터 캡슐 통과 검사(사용자 보강 ①) ───────────────────────────
-- 경로 점(발)마다: 몸통 상자(폭 1.8 · 높이 3.8 · 발 위 1.2부터 - 캐릭터는 2 이하 턱을 저절로 넘는다: 0.5에서 재면 걷는 요철에 스쳤다)를 이웃 점까지 양방향으로 밀어 보고(Blockcast) · 점마다 가로 광선 6 + 위 광선으로 막힘을 찾는다.
-- 지형 + 충돌 파트(쿼리 가능)만 막힘 - 통과 덮개(가짜 벽 · 덩굴 · 폭포)는 쿼리가 없어 안 걸린다. 시간 문(TimedDoor)은 열린 때로 친다. 물은 막힘이 아니다.
local capsuleParams = RaycastParams.new()
capsuleParams.FilterType = Enum.RaycastFilterType.Exclude
capsuleParams.IgnoreWater = true
local BODY = Vector3.new(1.8, 3.8, 1.8)
local FOOT_CLEAR = 1.2
local function exclusions()
	local list = {}
	for _, p in ipairs(Workspace:GetDescendants()) do
		if p:IsA("BasePart") and (p:GetAttribute("TimedDoor") or p:GetAttribute("NestId") or p:FindFirstAncestorOfClass("Model") and p:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid")) then
			table.insert(list, p)
		end
	end
	return list
end
function TerrainBake.capsuleCheck(nests)
	capsuleParams.FilterDescendantsInstances = exclusions()
	local bad = {}
	local checked = 0
	for _, n in ipairs(nests) do
		local pts = {}
		for _, p in ipairs(n.path or {}) do
			table.insert(pts, p)
		end
		table.insert(pts, n.spot)
		local hit = nil
		-- 점프맵 둥지(도약 표가 있다): 입구 → 둥지 직선 쓸기는 하지 않는다(벽 · 발판을 뚫고 지나가는 선 - 도약은 검증 (가)가 이동표로 잰다) · 점 검사는 한다
		local jump = n.leaps ~= nil and #n.leaps > 0
		for i, p in ipairs(pts) do
			local center = p + Vector3.new(0, FOOT_CLEAR + BODY.Y / 2, 0)
			for a = 0, 5 do
				local d = Vector3.new(math.cos(a * math.pi / 3), 0, math.sin(a * math.pi / 3)) * (BODY.X / 2)
				for _, dy in ipairs({ -1.4, 0, 1.4 }) do
					local r = Workspace:Raycast(center + Vector3.new(0, dy, 0), d, capsuleParams)
					if r then
						hit = hit or ("점 %d 옆 %s"):format(i, r.Instance.Name)
					end
				end
			end
			local up = Workspace:Raycast(center, Vector3.new(0, BODY.Y / 2 + 0.3, 0), capsuleParams)
			if up then
				hit = hit or ("점 %d 머리 %s"):format(i, up.Instance.Name)
			end
			local dist = i > 1 and (pts[i - 1] - p).Magnitude or 0
			if i > 1 and dist > 0.5 and not (jump and i == #pts) then
				local from = pts[i - 1] + Vector3.new(0, FOOT_CLEAR + BODY.Y / 2, 0)
				for _, dir in ipairs({ { from, center }, { center, from } }) do
					local r = Workspace:Blockcast(CFrame.new(dir[1]), BODY, dir[2] - dir[1], capsuleParams)
					if r then
						hit = hit or ("구간 %d→%d %s"):format(i - 1, i, r.Instance.Name)
					end
				end
			end
			checked += 1
		end
		if hit then
			table.insert(bad, n.id .. " " .. hit)
		end
	end
	return bad, checked
end

return TerrainBake
