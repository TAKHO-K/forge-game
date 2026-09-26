-- M1-4 자동 검증(지형 채우기 · 커브길 · 무리 스폰 · 외곽 테마 경계 · 심해 신전 · 관문 틀 · 나무). id = "M1-4(가)" · "M1-4(나)".
--   (가) 순수: 소품 라이브러리 틀 · 배치 · 빈 공간 비율(전/후) · 보호 부피 · 필수 길 침범 0 · 길(WorldCheck) · 이동 거리 · 스폰 지점 · 무리 · 상한 합성 틱 ·
--        외곽 허용 반경 · 밀어내기 도착 · 능선 둥지 · 바다 · 관문 자리 · 사다리 · 나무 잎 안쪽 가장자리
--   (나) 실제 서버: 지형 표식(버전 2) · 캡슐 통과(파트 포함) · 소품 지형 붙이기 · 라이브러리 모델 · 사다리 곁 "서 있음" · 능선 위/너머 밀어내기 · 관문 발판 자리 · 무리 스폰 상한 · 검증 뒤 정리
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local PropData = require(ReplicatedStorage.Shared.data.PropData)
local PropScatterData = require(ReplicatedStorage.Shared.data.PropScatterData)
local RoadData = require(ReplicatedStorage.Shared.data.RoadData)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
local WorldCheck = require(ReplicatedStorage.Shared.WorldCheck)
local PropScatter = require(ReplicatedStorage.Shared.PropScatter)
local RoadNet = require(ReplicatedStorage.Shared.RoadNet)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1-4][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1-4][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

local function flat(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- 빈 공간 비율(보고서 식과 같다 - 로그 M1-4 "빈 공간 측정 정의"): withRelief = 지형 변화 포함 · before = 채우기 소품 · 사다리 빼고
function V.emptyRatio(prims, withRelief, before, threshold)
	local pois = {}
	local function add(x, z, r)
		table.insert(pois, { x = x, z = z, r = r or 0 })
	end
	local skip = { Road = true, EdgeWall = true, Camp = true }
	for _, p in ipairs(prims) do
		local top = p.model:match("^[^%.]+")
		local isNew = top:match("^Fill_") or top:match("_ladder")
		if not skip[p.name] and top ~= "Edge" and not top:match("^Floor") and top ~= "GatePillars" and not (before and isNew) then
			local c = p.cf.Position
			add(c.X, c.Z, p.size and math.min(math.max(p.size.X, p.size.Z) / 2, 20) or 0)
		end
	end
	for _, zone in ipairs(WorldMapData.zones) do
		local zd = TerrainGenData.zones[zone.key] or {}
		local function w(r, lat)
			local q = WorldMapLayout.toWorld(zone, r, lat)
			return q.X, q.Z
		end
		for _, pk in ipairs(zd.peaks or {}) do
			add(w(pk.r, pk.lat))
		end
		for _, m in ipairs(zd.mesas or {}) do
			add(w(m.r, m.lat))
		end
		local function line(pts)
			for i = 2, #pts do
				local ax, az = w(pts[i - 1][1], pts[i - 1][2])
				local bx, bz = w(pts[i][1], pts[i][2])
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				for t = 0, len, 30 do
					add(ax + (bx - ax) * t / len, az + (bz - az) * t / len)
				end
			end
		end
		for _, v in ipairs(zd.valleys or {}) do
			line(v.pts)
		end
		for _, v in ipairs(zd.trails or {}) do
			line(v.pts)
		end
		for _, v in ipairs(zd.caves or {}) do
			line(v.pts)
		end
		if zd.river then
			line(zd.river.pts)
		end
		for _, l in ipairs(zd.lakes or {}) do
			add(w(l.r, l.lat))
		end
		if zd.bay then
			add(w(zd.bay.r, zd.bay.lat))
		end
	end
	if withRelief then
		for x = -2720, 2720, 40 do
			for z = -2720, 2720, 40 do
				local R = math.sqrt(x * x + z * z)
				if R > 380 and R < 2800 then
					local lo, hi = math.huge, -math.huge
					for _, o in ipairs({ { 0, 0 }, { 20, 0 }, { -20, 0 }, { 0, 20 }, { 0, -20 } }) do
						local h = TerrainShape.column(x + o[1], z + o[2]).h
						lo, hi = math.min(lo, h), math.max(hi, h)
					end
					if hi - lo >= 8 then
						add(x, z)
					end
				end
			end
			task.wait()
		end
	end
	local B = 64
	local bk = {}
	for _, p in ipairs(pois) do
		local k = math.floor(p.x / B) * 100000 + math.floor(p.z / B)
		bk[k] = bk[k] or {}
		table.insert(bk[k], p)
	end
	local function nearest(x, z, lim)
		local best = lim
		local rr = math.ceil((lim + 20) / B)
		local ix, iz = math.floor(x / B), math.floor(z / B)
		for i = ix - rr, ix + rr do
			for j = iz - rr, iz + rr do
				for _, p in ipairs(bk[i * 100000 + j] or {}) do
					local d = math.max(0, math.sqrt((p.x - x) ^ 2 + (p.z - z) ^ 2) - p.r)
					if d < best then
						best = d
					end
				end
			end
		end
		return best
	end
	local total, over = 0, 0
	local hubR = WorldMapData.hub.safeRadius
	for x = -2700, 2700, 20 do
		for z = -2700, 2700, 20 do
			local R = math.sqrt(x * x + z * z)
			if R > hubR and R <= TerrainGenData.edgeGuard.allowR then
				local c = TerrainShape.column(x, z)
				if not c.water then
					local h1, h2 = TerrainShape.column(x + 4, z).h, TerrainShape.column(x, z + 4).h
					local slope = math.deg(math.atan(math.sqrt(((h1 - c.h) / 4) ^ 2 + ((h2 - c.h) / 4) ^ 2)))
					if slope <= 45 and c.h - TerrainShape.flatY <= 150 then
						total += 1
						if nearest(x, z, 140) > threshold then
							over += 1
						end
					end
				end
			end
		end
		task.wait()
	end
	return over / math.max(total, 1), total
end

-- ─────────────────────────── (가) ───────────────────────────
function V.runPure()
	print("===M1-4 검증 시작(가)===")
	local r = newRecorder("가")
	local prims = WorldMapLayout.buildAll()
	r.section("카툰 대비 소품 라이브러리", function()
		local bad, names, maxParts = {}, 0, 0
		for name, t in pairs(PropData.templates) do
			names += 1
			maxParts = math.max(maxParts, #t.parts)
			if not name:match("^[%a%d]+_[%a%d]+$") or not (name:match("^T%d_") or name:match("^Common_") or name:match("^Hub_") or name:match("^Gate_")) then
				table.insert(bad, name)
			end
		end
		local placed, unknown, byModel = 0, 0, {}
		for _, p in ipairs(prims) do
			if p.prop then
				placed += 1
				if not PropData.templates[p.prop] then
					unknown += 1
				end
				local top = p.model:match("^[^%.]+")
				byModel[top:match("^(%a+)_") or top] = true
			end
		end
		r.check(("틀 %d종(이름 규칙 <테마>_<종류> 위반 %d%s · 틀당 도형 ≤ 8: 최대 %d) · 맵 배치 %d(없는 틀 %d)"):format(names, #bad, #bad > 0 and (" - " .. table.concat(bad, ", ")) or "", maxParts, placed, unknown),
			#bad == 0 and maxParts <= 8 and placed > 1000 and unknown == 0)
		local migrated = 0
		for _, n in ipairs({ "T2_CrystalCluster", "T4_Cactus", "T1_RuinPillar", "T1_Monolith", "T2_CrystalSpire", "T6_IceWallSlab", "Common_LeafClump", "Common_Bird" }) do
			for _, p in ipairs(prims) do
				if p.prop == n then
					migrated += 1
					break
				end
			end
		end
		r.check(("옛 소품 옮김(수정 군집 · 선인장 · 폐허 기둥 · 비석 · 수정 첨탑 · 얼음 벽 · 잎 · 새) %d/8 - 맵 도형이 틀 이름으로 배치됨"):format(migrated), migrated == 8)
		local mv = TerrainGenData.materialVariants
		r.check(("MaterialVariant 자리: 이름 규칙 %s<재질> · 구역 재질 표(palette) %d구역"):format(mv.prefix, 6), mv.prefix == "Terrain_")
	end)
	r.section("빈 공간 채우기", function()
		local S = PropScatter.data()
		local before = V.emptyRatio(prims, true, true, PropScatterData.emptyStuds)
		local after, samples = V.emptyRatio(prims, true, false, PropScatterData.emptyStuds)
		local beforeA = V.emptyRatio(prims, false, true, PropScatterData.emptyStuds)
		local afterA = V.emptyRatio(prims, false, false, PropScatterData.emptyStuds)
		r.check(("빈 곳(가장 가까운 볼거리 > %d · 걷는 격자 %d점): 소품 · 구조물 기준 %.1f%% → %.1f%% · 지형 변화 포함 %.1f%% → %.1f%%(목표 ≤ 15%%) · 소품 %d"):format(
			PropScatterData.emptyStuds, samples, beforeA * 100, afterA * 100, before * 100, after * 100, #S.placements), after <= 0.15 and afterA < beforeA)
		-- 보호 부피 · 필수 길 · 스폰 슬롯 침범 0
		local protect = WorldStructures.data().protect
		local hitProtect, hitRoad = 0, {}
		for _, p in ipairs(S.placements) do
			for _, v in ipairs(protect) do
				local lo, hi = PropScatter.protectBounds(v)
				if p.x + p.fp > lo.X and p.x - p.fp < hi.X and p.z + p.fp > lo.Z and p.z - p.fp < hi.Z then
					hitProtect += 1
				end
			end
			local ok, why = WorldCheck.clearOf(Vector3.new(p.x, 0, p.z), p.fp + 2)
			if not ok then
				table.insert(hitRoad, why)
			end
		end
		r.check(("소품 %d: 둥지 보호 부피 침범 %d · 필수 길 · 캠프 · 사냥 지대 · 관문 겹침 %d%s"):format(#S.placements, hitProtect, #hitRoad, #hitRoad > 0 and (" - " .. table.concat(hitRoad, " / ", 1, math.min(#hitRoad, 5))) or ""),
			hitProtect == 0 and #hitRoad == 0)
		local ladders = S.ladders
		local lrows, lok = {}, true
		for _, ld in ipairs(ladders) do
			table.insert(lrows, ("%s %.0f"):format(ld.zone, ld.top - TerrainShape.flatY))
			lok = lok and ld.top - TerrainShape.flatY <= WorldMapData.progress.standMaxY - 30 and ld.height % 2 == 0
		end
		r.check(("사다리 %d(절벽 3 + 외곽 벽 자동 %d): 꼭대기 높이 %s ≤ %d · TrussPart 높이 2의 배수"):format(#ladders, #ladders - #PropScatterData.cliffLadders, table.concat(lrows, " · "), WorldMapData.progress.standMaxY - 30),
			lok and #ladders >= #PropScatterData.cliffLadders + 3)
	end)
	r.section("커브길 · 이동 거리", function()
		local rows = WorldCheck.run()
		local okAll, failed = true, {}
		for _, row in ipairs(rows) do
			okAll = okAll and row.ok
			if not row.ok then
				table.insert(failed, row.name)
			end
		end
		r.check(("WorldCheck %d항목(곡선 길: 지형 = 길 높이 · 경사 ≤ %d° · 가로 ≤ 1 · 트랙 = A 5 + 능선 1 포함) 전부 %s%s"):format(#rows, RoadData.capGradeDeg, tostring(okAll), #failed > 0 and (" - " .. table.concat(failed, " / ")) or ""), okAll)
		local lrows, ok = {}, true
		for _, z in ipairs(WorldMapData.zones) do
			local he = WorldMapLayout.route(z)[1].p
			local sp = WorldMapLayout.spawnPoint()
			local toEntry = flat(sp, he) + WorldMapLayout.routeLength(z, "hubEdge", "barrierGate")
			local toGate = WorldMapLayout.routeLength(z, "camp", "gate")
			table.insert(lrows, ("%s 리스폰→입구 %.0f(%.0f초) · 캠프→관문 %.0f(%.0f초)"):format(z.key, toEntry, toEntry / 16, toGate, toGate / 16))
			ok = ok and toGate <= 2500 and toEntry <= 1100
		end
		r.check("이동 거리(곡선 · 걷기 16): " .. table.concat(lrows, " / "), ok)
		local signs = RoadNet.signs()
		local branches = 0
		for _, z in ipairs(WorldMapData.zones) do
			branches += RoadNet.branchPath(z) and 1 or 0
		end
		r.check(("갈림길(관문 → 랜드마크) %d · 표지판 %d(결계 문 6 + 갈림길)"):format(branches, #signs), branches == 5 and #signs == 6 + branches)
	end)
	r.section("무리 스폰", function()
		local S = WorldMapData.spawnSites
		local SpawnSites = require(script.Parent.SpawnSites)
		local list = SpawnSites.buildPoints()
		local byZone = {}
		for _, p in ipairs(list) do
			byZone[p.zoneKey] = (byZone[p.zoneKey] or 0) + 1
		end
		local okCount = true
		for _, z in ipairs(WorldMapData.zones) do
			okCount = okCount and byZone[z.key] == S.pointsPerRange
		end
		r.check(("스폰 지점 %d곳(구역마다 %d - 옛 34의 %.2f배) · 슬롯 %d(반경 %d)"):format(#list, S.pointsPerRange, S.pointsPerRange / 34, #list[1].slots, S.group.radius), okCount and #list[1].slots == S.group.maxSize)
		-- 무리 크기 표
		local t1, other = {}, {}
		for i = 1, 4000 do
			local a = SpawnSites.pickSize("tier1", (i - 0.5) / 4000)
			local b = SpawnSites.pickSize("tier4", (i - 0.5) / 4000)
			t1[a] = (t1[a] or 0) + 1
			other[b] = (other[b] or 0) + 1
		end
		r.check(("무리 크기: T1 3/4/5 = %d/%d/%d%% · 다른 구역 %d/%d/%d%% (3 ~ 5 · T1 3 위주)"):format((t1[3] or 0) / 40, (t1[4] or 0) / 40, (t1[5] or 0) / 40, (other[3] or 0) / 40, (other[4] or 0) / 40, (other[5] or 0) / 40),
			(t1[3] or 0) > 2800 and (t1[5] or 0) == 0 and (other[5] or 0) > 800)
		-- 상한 합성 틱: 사람 30명을 지점 위에 흩어 세운다 → 서버 합 ≤ 상한 · 사람당 곁 무리 ≤ 상한(앞 지점 예외 1)
		local alive = {}
		local hooks = {
			spawn = function(point, slot)
				local m = { point = point }
				alive[m] = true
				return m
			end,
			alive = function(m)
				return alive[m] == true
			end,
			engaged = function()
				return false
			end,
			claim = function()
				return true
			end,
			remove = function(m)
				alive[m] = nil
			end,
		}
		local foci = {}
		for i = 1, 30 do
			table.insert(foci, list[(i * 13) % #list + 1].position)
		end
		local maxAlive, maxNear = 0, 0
		for t = 1, 20 do
			SpawnSites.tick(list, foci, t, hooks)
			local n = 0
			for _ in pairs(alive) do
				n += 1
			end
			maxAlive = math.max(maxAlive, n)
			for fi, f in ipairs(foci) do
				local near = 0
				for _, p in ipairs(list) do
					if p.active and p.nearFocus == fi and flat(p.position, f) <= S.activateRadius then
						near += 1
					end
				end
				maxNear = math.max(maxNear, near)
			end
		end
		r.check(("상한 합성(사람 30 · 20틱): 동시 몬스터 최대 %d(≤ %d) · 사람당 곁 무리 최대 %d(≤ %d)"):format(maxAlive, S.caps.maxMonsters, maxNear, S.caps.maxGroupsPerPlayer), maxAlive <= S.caps.maxMonsters and maxNear <= S.caps.maxGroupsPerPlayer)
		-- 잔류: 모두 떠나면 12초 뒤 정리
		for t = 21, 21 + S.idleSeconds + 2 do
			SpawnSites.tick(list, {}, t, hooks)
		end
		local left = 0
		for _ in pairs(alive) do
			left += 1
		end
		r.check(("모두 떠나고 %d초 뒤 남은 몬스터 %d(기대 0 - 잔류 규칙 그대로)"):format(S.idleSeconds + 2, left), left == 0)
		-- 걷는 사냥꾼(처치 4초 · 15분) - 앞 지점이 켜지는가(첫 구현 버그 회귀)
		local M1_2Verify = require(script.Parent.M1_2Verify)
		local walk = M1_2Verify.simulateHunter("walk", 4, 0.25, 1)
		r.check(("걷는 사냥꾼(T1 · 처치 4초 · 15분): 분당 %.1f(전 6.9) · 공급 부족 %.0f%% · 동시 최대 %d"):format(walk.killsPerHour / 60, walk.waitFraction * 100, walk.aliveMax), walk.killsPerHour / 60 >= 7.5)
	end)
	r.section("외곽 테마 경계", function()
		local ES = TerrainGenData.edgeStyles
		local rows, ok = {}, true
		local Travel = require(script.Parent.Travel)
		for _, z in ipairs(WorldMapData.zones) do
			local st = ES[z.key]
			local ang = z.angleDeg + ((st.lookout and st.lookout.deg) or -2) -- 전망 지점(바다 = 곶 사이)
			local allow = TerrainShape.edgeAllowRAt(ang)
			local d = WorldMapLayout.dirOf(ang)
			if st.kind == "sea" then
				local c = TerrainShape.column(d.X * (TerrainShape.coastR(ang) + 120), d.Z * (TerrainShape.coastR(ang) + 120))
				table.insert(rows, ("%s 바다(해안 %.0f · 물 %s)"):format(z.key, TerrainShape.coastR(ang), tostring(c.water ~= nil)))
				ok = ok and c.water ~= nil
			else
				local cr = TerrainShape.crestR(ang)
				local crestH = TerrainShape.height(d.X * (cr + ES.crestWidth / 2), d.Z * (cr + ES.crestWidth / 2)) - TerrainShape.flatY
				local push = Travel.edgePushPoint(d * (allow + 30) + Vector3.new(0, 100, 0))
				local stay = Travel.edgePushPoint(d * (cr + ES.crestWidth / 2) + Vector3.new(0, crestH + 3, 0))
				table.insert(rows, ("%s %s 능선 %.0f(높이 %.0f) · 허용 %.0f · 너머 → %s · 능선 위 = %s"):format(z.key, st.kind, cr, crestH, allow, push and ("%.0f"):format(flat(push, Vector3.zero)) or "nil", tostring(stay)))
				ok = ok and push ~= nil and flat(push, Vector3.zero) <= allow and stay == nil and math.abs(crestH - st.crestH) <= 12 and crestH <= WorldMapData.progress.standMaxY - 30
			end
		end
		r.check("구역별 경계 · 능선(전망 지점) · 밀어내기 = 능선 너머만: " .. table.concat(rows, " / "), ok)
		local crest, cok = 0, true
		for _, n in ipairs(WorldStructures.nestList()) do
			if n.crest then
				crest += 1
				local allow = TerrainShape.edgeAllowR(n.spot.X, n.spot.Z)
				cok = cok and flat(n.spot, Vector3.zero) <= allow - 10 and n.high
			end
		end
		r.check(("능선 둥지 %d(트랙 A 높은 곳 · 허용 반경 안 · T3 바다 제외)"):format(crest), crest == 5 and cok)
	end)
	r.section("관문 · 심해 신전", function()
		local gates = WorldMapLayout.bossGates()
		local T3 = WorldMapLayout.zoneByKey("tier3")
		local site = WorldMapLayout.gateSite(T3)
		local g3 = WorldMapLayout.bossGate(T3.bossId)
		local posOk = g3 and flat(g3.position, WorldMapLayout.toWorld(T3, site.r, site.lat)) < 0.1 and math.abs(g3.position.Y - (WorldMapData.floorTopY + site.y)) < 0.1
		local water = TerrainShape.waterAt(g3.position.X, g3.position.Z)
		local route = WorldMapLayout.route(T3)
		local hasShore = route[#route - 1].id == "shore"
		local parts = { plaza = 0, causeway = 0, pad = 0, prompt = 0, stair = 0 }
		for _, p in ipairs(prims) do
			if p.name == "TemplePlaza" then
				parts.plaza += 1
			elseif p.name == "Causeway" then
				parts.causeway += 1
			elseif p.name == "SeaStair" then
				parts.stair += 1
			elseif p.name == "BossGatePad" and p.attrs and p.attrs.BossId == T3.bossId then
				parts.pad += 1
				posOk = posOk and math.abs(p.cf.Position.Y - (g3.position.Y + 0.45)) < 0.1
			elseif p.name == "PromptAnchor" and p.attrs and p.attrs.GatePrompt == T3.bossId then
				parts.prompt += 1
			end
		end
		r.check(("심해 관문 = 만 위 신전(r %d · 판 윗면 = 수면 위 %.1f · 아래 물 %s) · 길 → 기슭(shore) %s · 둑길 %d조각 · 광장 %d · 물속 계단 %d · 발판 %d · 프롬프트 %d"):format(site.r, g3.position.Y - (water or 0), tostring(water ~= nil), tostring(hasShore), parts.causeway, parts.plaza, parts.stair, parts.pad, parts.prompt),
			posOk and water ~= nil and hasShore and parts.causeway >= 8 and parts.plaza == 1 and parts.stair == 5 and parts.pad == 1 and parts.prompt == 1)
		-- 공통 틀: 관문마다 발판 1 · 프롬프트 1 · 문양 2 · 빛기둥 1 · 장식(style)
		local per = {}
		for _, g in ipairs(gates) do
			per[g.bossId] = { pad = 0, prompt = 0, emblem = 0, pillar = 0, decor = 0, style = g.style or "default" }
		end
		local decorNames = { GateBanner = true, GateCoral = true, GateWave = true, GateRod = true, GateBolt = true, GateSpike = true, GateSeaweed = true, GateShell = true, GateRodTip = true }
		for _, p in ipairs(prims) do
			local a = p.attrs or {}
			local id = p.model:match("^BossGate_(.+)$")
			if a.BossId and p.name == "BossGatePad" then
				per[a.BossId].pad += 1
			elseif a.GatePrompt then
				per[a.GatePrompt].prompt += 1
			elseif a.GateEmblem then
				per[a.GateEmblem].emblem += 1
			elseif a.GatePillar then
				per[a.BossId].pillar += 1
			elseif id and per[id] and decorNames[p.name] then
				per[id].decor += 1
			end
		end
		local rows, ok = {}, true
		for id, c in pairs(per) do
			table.insert(rows, ("%s(%s) 발판 %d · 프롬프트 %d · 문양 %d · 빛기둥 %d · 장식 %d"):format(id, c.style, c.pad, c.prompt, c.emblem, c.pillar, c.decor))
			ok = ok and c.pad == 1 and c.prompt == 1 and c.emblem == 2 and c.pillar == 1 and c.decor >= 2
		end
		table.sort(rows)
		r.check(("관문 %d = 공통 틀 + 장식 모듈: %s"):format(#gates, table.concat(rows, " / ")), ok and #gates == 6 and per.abyssal_lord.style == "abyss" and per.storm_lord.style == "storm")
	end)
	r.section("중앙 나무", function()
		local minIn, lumps = math.huge, 0
		local CS = WorldMapData.hub.tree.crownShape
		for _, p in ipairs(prims) do
			if p.name == "LeafLump" then
				lumps += 1
				local c = p.cf.Position
				if c.Y < WorldMapData.floorTopY + CS.shoulderY then
					minIn = math.min(minIn, Vector3.new(c.X, 0, c.Z).Magnitude - p.size.X / 2)
				end
			end
		end
		local st = WorldMapLayout.stations()
		r.check(("잎 덩어리 %d · 어깨 아래 안쪽 가장자리 %.1f ≥ %d(점프맵 길 밖) · 정거장 %d · 줄기 혹 · 밑동 퍼짐 충돌 없음"):format(lumps, minIn, CS.clearRadius, #st), lumps > 60 and minIn >= CS.clearRadius - 0.01 and #st == 5)
	end)
	local pass, total = r.summary()
	print(("===M1-4 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function V.runLive(player, env)
	print("===M1-4 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local HeightGuard = require(script.Parent.HeightGuard)
	local TerrainBake = require(script.Parent.TerrainBake)
	local PropLibrary = require(script.Parent.PropLibrary)
	local Travel = require(script.Parent.Travel)
	local SpawnSites = require(script.Parent.SpawnSites)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	assert(root, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	HeightGuard.debugOff = true
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
		HeightGuard.reset(player)
	end
	r.section("굽힌 지형 · 캡슐", function()
		local bad = TerrainBake.checkVersion()
		r.check(("지형 표식(버전 %d · 서명) 불일치 %d%s"):format(TerrainGenData.version.tier1, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ")) or ""), #bad == 0)
		local blocked, checked = TerrainBake.capsuleCheck(WorldStructures.nestList())
		r.check(("둥지 캡슐 통과(파트 · 소품 포함 실제 서버) 점 %d: 막힘 %d%s"):format(checked, #blocked, #blocked > 0 and (" - " .. table.concat(blocked, " / ", 1, math.min(#blocked, 6))) or ""), #blocked == 0)
	end)
	r.section("소품 라이브러리 · 지형 붙이기", function()
		local folder = ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Props")
		local lib = folder and #folder:GetChildren() or 0
		local n, templ = 0, 0
		for _, m in ipairs(folder and folder:GetChildren() or {}) do
			if m:GetAttribute("PropSource") == "template" then
				templ += 1
			end
		end
		for _, m in ipairs(Workspace:GetDescendants()) do
			if m:IsA("Model") and m:GetAttribute("Prop") then
				n += 1
			end
		end
		local sn = PropLibrary.snapStats()
		r.check(("라이브러리 %d종(틀 %d · 교체 %d) · 맵 소품 %d · 지형 붙이기 %d중 옮김 %d(최대 차 %.2f - 다시 굽기 뒤 ≤ 2.5 · 옮김 ≤ 3%% 기대 - 복셀 4 해상도)"):format(lib, templ, lib - templ, n, sn.checked, sn.moved, sn.maxDelta),
			lib == #(function()
				local t = {}
				for k in pairs(PropData.templates) do
					table.insert(t, k)
				end
				return t
			end)() and n > 1000 and sn.maxDelta <= 2.5 and sn.moved <= sn.checked * 0.03)
	end)
	r.section("사다리 = 서 있음(곁에 TrussPart)", function()
		local ld = PropScatter.data().ladders[1]
		local mid = ld.base + Vector3.new(0, ld.height / 2, 0) - ld.out * 1.2
		put(mid)
		task.wait(0.2)
		local near = HeightGuard.nearClimbable(character, root)
		put(mid + ld.out * 25)
		task.wait(0.2)
		local far = HeightGuard.nearClimbable(character, root)
		r.check(("사다리(%s · 높이 %d) 곁 = %s · 25 떨어지면 = %s(기대 true · false - 오르는 중 상태 위조로 높이 검사를 못 피한다)"):format(ld.zone, ld.height, tostring(near), tostring(far)), near and not far)
	end)
	r.section("능선 위 · 너머 밀어내기(실제 폴링)", function()
		HeightGuard.debugOff = true
		local T2 = WorldMapLayout.zoneByKey("tier2")
		local ES = TerrainGenData.edgeStyles
		local ang = T2.angleDeg + ES.tier2.lookout.deg
		local d = WorldMapLayout.dirOf(ang)
		local on = d * (ES.crestR + ES.crestWidth / 2)
		local onY = TerrainShape.height(on.X, on.Z)
		local before = Travel.stateOf(player).edgePushes or 0
		put(Vector3.new(on.X, onY + 3.2, on.Z))
		task.wait(1.2)
		local mid = Travel.stateOf(player).edgePushes or 0
		local allow = TerrainShape.edgeAllowRAt(ang)
		local beyond = d * (allow + 25)
		local by = TerrainShape.height(beyond.X, beyond.Z)
		put(Vector3.new(beyond.X, by + 3.2, beyond.Z))
		task.wait(1.2)
		local after = Travel.stateOf(player).edgePushes or 0
		local R2 = flat(root.Position, Vector3.zero)
		r.check(("T2 능선 전망 판(높이 %.0f) 밀어내기 %d번(기대 0) · 너머(r %.0f · 높이 %.0f) %d번 → 반경 %.0f ≤ 허용 %.0f"):format(onY - TerrainShape.flatY, mid - before, flat(beyond, Vector3.zero), by - TerrainShape.flatY, after - mid, R2, allow),
			mid == before and after > mid and R2 <= allow)
	end)
	r.section("관문 발판 자리(심해 신전)", function()
		local T3 = WorldMapLayout.zoneByKey("tier3")
		local pad
		for _, p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "BossGatePad" and p:GetAttribute("BossId") == T3.bossId then
				pad = p
			end
		end
		local plaza
		for _, p in ipairs(Workspace:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "TemplePlaza" then
				plaza = p
			end
		end
		local g = WorldMapLayout.bossGate(T3.bossId)
		r.check(("심해 관문 발판 %s · 광장 %s · 광장 윗면 %.2f = 관문 %.2f"):format(tostring(pad ~= nil), tostring(plaza ~= nil), plaza and (plaza.Position.Y + plaza.Size.Y / 2) or -1, g.position.Y),
			pad ~= nil and plaza ~= nil and math.abs(plaza.Position.Y + plaza.Size.Y / 2 - g.position.Y) < 0.2)
	end)
	r.section("무리 스폰 상한(실제 서버 · 가짜 초점)", function()
		local pts = SpawnSites.points()
		local foci = {}
		for i = 1, 40 do
			local p = pts[(i * 11) % #pts + 1].position
			table.insert(foci, ("%.0f,%.0f"):format(p.X, p.Z))
		end
		ReplicatedStorage:SetAttribute("DebugSpawnFoci", table.concat(foci, ";"))
		task.wait(WorldMapData.spawnSites.checkSeconds * 3.5)
		local active, alive = SpawnSites.stats()
		ReplicatedStorage:SetAttribute("DebugSpawnFoci", nil)
		task.wait(WorldMapData.spawnSites.idleSeconds + WorldMapData.spawnSites.checkSeconds * 3)
		local active2, alive2 = SpawnSites.stats()
		local leaks, orphans = SpawnSites.audit()
		r.check(("가짜 초점 40 → 켜진 무리 %d · 몬스터 %d(≤ %d) / 떠난 뒤 %d초 → 무리 %d · 몬스터 %d · 누수 %d · 주인 없음 %d"):format(active, alive, WorldMapData.spawnSites.caps.maxMonsters, WorldMapData.spawnSites.idleSeconds,
			active2, alive2, leaks, orphans), alive <= WorldMapData.spawnSites.caps.maxMonsters and alive > 60 and leaks == 0 and orphans == 0)
	end)
	HeightGuard.debugOff = guardOff
	put(require(ReplicatedStorage.Shared.data.WorldConfig).zones.spawn.arrival + Vector3.new(0, 5, 0))
	env.restore(player)
	local pass, total = r.summary()
	print(("===M1-4 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
