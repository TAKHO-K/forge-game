-- M1-3 본편 자동 검증(대형 지형 · 물 · 신전 · 둥지 3트랙 · 구역 알). id = "M1-3T(가)" · "M1-3T(나)"(M1-3(가)(나) = 관문 등록 블록은 따로).
--   (가) 순수: WorldCheck 12항목(트랙 섞기 · 도달 · 지붕 · C 표시 없음 · 필수 길 간격 · 지형 통과 · 물 · 높이 · 길 평탄 · 선인장 · 강 기슭 · 겹침) + 알 확률 · 저점 · 순환 ·
--        줍기 위치 판정(합성 기록) · 선인장 상한 · 저장 v41 · 외곽 밀어내기 자리 · 물속 높이 검사 합성 표본 · 스폰 지점 지형 판정 · 봉우리 200+ · 랜드마크
--   (나) 실제 서버: 굽힌 지형 표식 · 길 실측 높이 · 둥지 캡슐 통과(복셀) · 프롬프트 · C 표시 없음(인스턴스) · 줍기(성공 · 쿨다운 · 멀리서 거절 · 순간이동 거절) · 저장 왕복 ·
--        순환 교체 · 번개 문 상태 · 선인장 피해 상한 · 외곽 밀어내기 · MaxSlopeAngle · 스폰 지점 높이 · 물 판정 · 검증 뒤 정리
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local NestData = require(ReplicatedStorage.Shared.data.NestData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local TerrainGenData = require(ReplicatedStorage.Shared.data.TerrainGenData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local WorldMapLayout = require(ReplicatedStorage.Shared.WorldMapLayout)
local TerrainShape = require(ReplicatedStorage.Shared.TerrainShape)
local WorldStructures = require(ReplicatedStorage.Shared.WorldStructures)
local WorldCheck = require(ReplicatedStorage.Shared.WorldCheck)

local V = {}
local function WorldStructureDataHazard()
	return require(ReplicatedStorage.Shared.data.WorldStructureData).cactus.hazard
end

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[M1-3T][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[M1-3T][%s] %s"):format(tag, label))
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

-- ─────────────────────────── (가) ───────────────────────────
function V.runPure()
	print("===M1-3T 검증 시작(가)===")
	local r = newRecorder("가")
	local NestServer = require(script.Parent.NestServer)
	r.section("지형 · 둥지 식(WorldCheck)", function()
		local rows, extra = WorldCheck.run()
		for _, row in ipairs(rows) do
			r.check(row.name .. (row.detail ~= "" and (" - " .. row.detail) or ""), row.ok)
		end
		local hard = {}
		for id, name in pairs(extra.hardest) do
			table.insert(hard, id .. "=" .. name)
		end
		table.sort(hard)
		r.note("대시가 필요한 도약이 있는 둥지: " .. table.concat(hard, " · "))
	end)
	r.section("알 확률 · 저점", function()
		local bad = {}
		for key, dist in pairs(EggData.grades) do
			local sum = 0
			for _, g in ipairs(EggData.gradeOrder) do
				sum += dist[g] or 0
			end
			if math.abs(sum - 100) > 1e-6 then
				table.insert(bad, key .. " 합 " .. sum)
			end
		end
		for g, dist in pairs(EggData.hatch) do
			local sum = 0
			for _, h in ipairs(EggData.hatchGrades) do
				sum += dist[h] or 0
			end
			if math.abs(sum - 100) > 1e-6 then
				table.insert(bad, "부화 " .. g .. " 합 " .. sum)
			end
		end
		local G = EggData.grades
		-- M1-3 결정 2(사용자 확정): A 높은 곳 = 저점 보통 · 좋은 약 40 · 희귀 거의 없음(≤ 2) / B = 저점 좋은 · 희귀 약 10 / C-필드 = 저점 좋은 · 희귀 약 20 /
		--   C-히든 = 저점 좋은 · 희귀 50(구역당 하루 1곳 이하) · 넘으면 25 ~ 30 / C-마을 = C-필드보다 한 단계 낮게(저점 보통)
		local near = function(v, want, tol)
			return math.abs(v - want) <= tol
		end
		local rows = {
			{ "A 높은 곳 저점 보통 · 좋은 ≈ 40 · 희귀 ≤ 2", G.Ahigh.normal > 0 and near(G.Ahigh.good, 40, 3) and G.Ahigh.rare <= 2 },
			{ "B 저점 좋은 · 희귀 ≈ 10", G.B.normal == 0 and near(G.B.rare, 10, 2) },
			{ "C-필드 저점 좋은 · 희귀 ≈ 20", G.Cfield.normal == 0 and near(G.Cfield.rare, 20, 2) },
			{ "C-히든(구역당 1곳 이하) 저점 좋은 · 희귀 50", G.Chidden.normal == 0 and G.Chidden.rare == 50 },
			{ "C-히든(넘으면) 희귀 25 ~ 30", G.ChiddenCrowded.normal == 0 and G.ChiddenCrowded.rare >= 25 and G.ChiddenCrowded.rare <= 30 },
			{ "C-마을 = C-필드보다 한 단계 낮게(저점 보통)", G.Cvillage.normal > 0 and G.Cfield.normal == 0 },
			{ "A 저점 보통", G.A.normal > 0 },
		}
		local badRows = {}
		for _, row in ipairs(rows) do
			if not row[2] then
				table.insert(badRows, row[1])
			end
		end
		local hatchOk = EggData.hatch.rare.epic > EggData.hatch.good.epic and EggData.hatch.good.epic > EggData.hatch.normal.epic
		r.check(("알 등급 분포 합 100 · 부화 표 합 100: 위반 %d%s"):format(#bad, #bad > 0 and (" - " .. table.concat(bad, " / ")) or ""), #bad == 0)
		r.check(("트랙 저점 · 희귀 비중(결정 2) 7줄: 위반 %d%s · 희귀 알 부화 보정 %s"):format(#badRows, #badRows > 0 and (" - " .. table.concat(badRows, " / ")) or "", tostring(hatchOk)), #badRows == 0 and hatchOk)
		-- 진짜 히든이 하루에 몇 곳 켜지나(구역당 · 전체) → 쓰는 표
		local perZone, total = {}, 0
		for day = 20000, 20029 do
			for _, z in ipairs(WorldMapData.zones) do
				local n = NestServer.hiddenActiveCount(z.key, day)
				perZone[n] = (perZone[n] or 0) + 1
				total += n
			end
		end
		local anyHidden
		for _, sp in ipairs(NestData.nests) do
			if sp.sub == "hidden" and not anyHidden then
				anyHidden = sp
			end
		end
		local hiddenKey = NestServer.gradeKey(anyHidden, 20000)
		r.check(("진짜 히든 하루 켜짐: 구역당 %s곳(30일 × 6구역 표본) · 하루 전체 %.0f곳 → 쓰는 분포 = %s(희귀 %d)"):format(next(perZone) and tostring(next(perZone)) or "?", total / 30, hiddenKey, G[hiddenKey].rare),
			perZone[1] == 30 * #WorldMapData.zones and hiddenKey == "Chidden")
		-- 칭호 문턱 = C-필드 · C-히든만(마을 제외 · 결정 5)
		local dex = { hub_c_chimney = true, hub_c_attic = true, t1_c_field = true, t2_c_h1 = true }
		r.check(("칭호 문턱 집계: 도감 4곳(마을 2 · 필드 1 · 히든 1) → 칭호에 세는 수 %d(기대 2)"):format(NestServer.titleCount(dex)), NestServer.titleCount(dex) == 2)
		-- 구역 알: 색(관문 색) 6가지 다름 · 풀 4종 · 후보 2(서로 다름)
		local colors, pools, dupe = {}, 0, 0
		local BossData = require(ReplicatedStorage.Shared.data.BossData)
		for _, z in ipairs(WorldMapData.zones) do
			local c = BossData.bosses[z.bossId].gate.color
			colors[table.concat(c, ",")] = true
			pools += #EggData.zones[z.key].pool
		end
		local nColors = 0
		for _ in pairs(colors) do
			nColors += 1
		end
		for i = 1, 400 do
			local spec = NestData.nests[(i % #NestData.nests) + 1]
			local egg = NestServer.rollEgg(1000 + i, spec, i % 5)
			if egg.species[1] == egg.species[2] then
				dupe += 1
			end
		end
		r.check(("구역 알 색 %d가지(기대 6) · 풀 %d종(6 × 4) · 후보 2종 같은 경우 %d/400"):format(nColors, pools, dupe), nColors == 6 and pools == 24 and dupe == 0)
		-- 뽑기 분포(트랙마다 4,000번 · 제안값 ± 3%p) · 같은 입력 = 같은 알(재접속 뽑기 없음)
		local worst = 0
		for _, key in ipairs({ "A", "Ahigh", "B", "Btop", "Cvillage", "Cfield", "Chidden" }) do
			local spec
			for _, s in ipairs(NestData.nests) do
				if NestServer.trackKey(s) == key then
					spec = s
				end
			end
			local counts = { normal = 0, good = 0, rare = 0 }
			for u = 1, 4000 do
				counts[NestServer.rollEgg(u * 7 + 3, spec, u % 3).grade] += 1
			end
			for _, g in ipairs(EggData.gradeOrder) do
				worst = math.max(worst, math.abs(counts[g] / 40 - EggData.grades[key][g]))
			end
		end
		local s1 = NestData.nests[3]
		local a, b = NestServer.rollEgg(42, s1, 2), NestServer.rollEgg(42, s1, 2)
		r.check(("뽑기 분포(7트랙 × 4,000) 제안값과 최대 차 %.2f%%p(기대 ≤ 3) · 같은 사람 · 둥지 · 회차 = 같은 알 %s"):format(worst, tostring(a.grade == b.grade and a.species[1] == b.species[1])), worst <= 3 and a.grade == b.grade)
	end)
	r.section("재생성 · 순환", function()
		local unix = 1790000000
		local A, B, Bt, Ch
		for _, s in ipairs(NestData.nests) do
			local k = NestServer.trackKey(s)
			A = A or (k == "A" and s)
			B = B or (k == "B" and s)
			Bt = Bt or (k == "Btop" and s)
			Ch = Ch or (k == "Chidden" and s)
		end
		local nA, nB, nBt, nCh = NestServer.nextAt(1, A, 0, unix) - unix, NestServer.nextAt(1, B, 0, unix) - unix, NestServer.nextAt(1, Bt, 0, unix), NestServer.nextAt(1, Ch, 0, unix)
		local midnight = (nBt + NestData.dayOffsetSeconds) % 86400 == 0
		r.check(("재생성: A %d초(30분) · B %d초(2 ~ 4시간) · B 최상위 · C-히든 = 다음 한국 자정 %s(%s)"):format(nA, nB, tostring(midnight), os.date("!%H:%M", nBt + NestData.dayOffsetSeconds)),
			nA == 1800 and nB >= 7200 and nB <= 14400 and midnight and nBt == nCh and nBt > unix and nBt - unix <= 86400)
		local same, seen = 0, {}
		for _, z in ipairs(WorldMapData.zones) do
			local prev = nil
			seen[z.key] = {}
			for day = 20000, 20029 do
				local id = NestServer.activeHidden(z.key, day)
				if id == prev then
					same += 1
				end
				prev = id
				seen[z.key][id] = true
			end
		end
		local all = 0
		for _, set in pairs(seen) do
			for _ in pairs(set) do
				all += 1
			end
		end
		r.check(("순환형: 30일 동안 이웃 날 같은 곳 %d(기대 0) · 후보가 모두 한 번 이상 나옴 %d/%d"):format(same, all, #WorldMapData.zones * NestData.rotateCandidates), same == 0 and all == #WorldMapData.zones * NestData.rotateCandidates)
	end)
	r.section("줍기 위치 판정(합성 서버 기록)", function()
		local meta = WorldStructures.nest(NestData.nests[2].id)
		local spot = meta.spot
		local root = spot + Vector3.new(0, 3, 0)
		local now = 100
		local function samples(fn)
			local list = {}
			for i = 30, 0, -1 do
				table.insert(list, { t = now - i / 60, pos = fn(i) })
			end
			return list
		end
		local okStand = NestServer.checkPresence(samples(function(i)
			return root + Vector3.new(math.sin(i) * 0.5, 0, 0)
		end), spot, now)
		local okFar, whyFar = NestServer.checkPresence(samples(function()
			return root + Vector3.new(40, 0, 0)
		end), spot, now)
		local okTp, whyTp = NestServer.checkPresence(samples(function(i)
			return i > 3 and (root + Vector3.new(300, 0, 0)) or root
		end), spot, now)
		local okFew, whyFew = NestServer.checkPresence({ { t = now, pos = root } }, spot, now)
		-- 둥지 전용 궤적(리뷰 - 발사 허가 기록 0.6초만으로는 "순간이동 → 0.6초 기다림 → 줍기"가 통과했다): 1.5초 전 300 밖 → 둥지 · 그 뒤 계속 둥지
		local trailTp, trailWalk = {}, {}
		for i = 30, 0, -1 do
			local t = now - i / 10
			table.insert(trailTp, { t = t, pos = (i > 15) and (root + Vector3.new(300, 0, 0)) or root })
			table.insert(trailWalk, { t = t, pos = root + Vector3.new(i * 1.6, 0, 0) }) -- 초속 16 걷기로 다가옴
		end
		local standing = samples(function() return root end)
		local okTrail, whyTrail = NestServer.checkPresence(standing, spot, now, trailTp)
		local okWalk = NestServer.checkPresence(standing, spot, now, trailWalk)
		r.check(("서 있음 → %s · 40 밖 → %s(%s) · 순간이동(3프레임) → %s(%s) · 표본 1장 → %s(%s) · 순간이동 1.5초 뒤(궤적) → %s(%s) · 걸어와서 → %s"):format(tostring(okStand), tostring(okFar), tostring(whyFar), tostring(okTp), tostring(whyTp), tostring(okFew), tostring(whyFew), tostring(okTrail), tostring(whyTrail), tostring(okWalk)),
			okStand and not okFar and not okTp and not okFew and not okTrail and whyTrail == "teleport" and okWalk)
	end)
	r.section("선인장 피해 상한", function()
		local WorldHazards = require(script.Parent.WorldHazards)
		local st = WorldHazards.newState()
		local hits, capped = 0, 0
		local maxIn5 = 0
		local times = {}
		for t = 0, 20, 0.05 do
			local g = WorldHazards.cactusGate(st, t)
			if g == "hit" then
				hits += 1
				table.insert(times, t)
			elseif g == "capped" then
				capped += 1
			end
		end
		for i = 1, #times do
			local n = 0
			for j = i, #times do
				if times[j] - times[i] < WorldStructureDataHazard().windowSeconds then
					n += 1
				end
			end
			maxIn5 = math.max(maxIn5, n)
		end
		local HZ = WorldStructureDataHazard()
		r.check(("20초 계속 닿음: 피해 %d번 · 어느 %d초 창에서도 최대 %d번(상한 %d) · 한 번 = 현재 체력의 %.0f%%(이것만으로 안 죽는다)"):format(hits, HZ.windowSeconds, maxIn5, HZ.maxPerWindow, HZ.hpFraction * 100),
			maxIn5 <= HZ.maxPerWindow and hits > 0 and capped > 0)
	end)
	r.section("저장 v41", function()
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = { version = 40, world = { portals = { tier1 = true }, bossGates = { section_guardian = true } }, titles = {} }
		local m = SaveSystem.migrate(old)
		local ok = m.version == 41 and type(m.world.nests) == "table" and next(m.world.nests) == nil and type(m.world.nestDex) == "table" and type(m.eggs) == "table" and #m.eggs == 0
			and m.world.bossGates.section_guardian == true and m.world.portals.tier1 == true
		r.check(("SAVE_VERSION %d · v40 → v41: 둥지 기록 · 도감 · 알 가방 빈 표 · 관문 · 포탈 유지 %s"):format(SaveConfig.saveVersion, tostring(ok)), SaveConfig.saveVersion == 41 and ok)
	end)
	r.section("외곽 경계 밀어내기(식)", function()
		local Travel = require(script.Parent.Travel)
		local EG = TerrainGenData.edgeGuard
		local rows, okAll = {}, true
		for _, z in ipairs(WorldMapData.zones) do
			local d = WorldMapLayout.dirOf(z.angleDeg + 11)
			local feet = d * 2760 + Vector3.new(0, 80, 0)
			local out = Travel.edgePushPoint(feet)
			local ok = out ~= nil and flat(out, Vector3.zero) <= EG.allowR and out.Y - TerrainShape.flatY <= 34 and not TerrainShape.waterAt(out.X, out.Z)
			okAll = okAll and ok
			table.insert(rows, ("%s %s"):format(z.key, out and ("%.0f"):format(flat(out, Vector3.zero)) or "nil"))
		end
		local basin = WorldMapLayout.dirOf(WorldMapData.reserved.outerRing.angles[2]) * 2700
		local inBasin = Travel.edgePushPoint(basin + Vector3.new(0, 1, 0))
		local bay = TerrainGenData.zones.tier3.bay
		local bayP = WorldMapLayout.toWorld(WorldMapLayout.zoneByKey("tier3"), bay.r + 60, bay.lat)
		local inBay = Travel.edgePushPoint(bayP)
		r.check(("설산 위(r 2,760) → 안쪽 걷는 땅(반경 %s ≤ %d) · 봉인 분지 안 = %s(기대 nil) · 바다 만 물 위 = %s(기대 nil)"):format(table.concat(rows, " · "), EG.allowR, tostring(inBasin), tostring(inBay)),
			okAll and inBasin == nil and inBay == nil)
	end)
	r.section("물속 높이 검사(합성 표본)", function()
		local HeightGuard = require(script.Parent.HeightGuard)
		local st = HeightGuard.newState()
		local t, verdicts = 0, {}
		local bad = 0
		-- 바다 만 바닥(−17)에서 헤엄쳐 수면으로 → 물 밖 뭍으로 점프(공중 점프 2) → 착지 · 강 계단 폭포(수면 30 → 0) 헤엄쳐 내려감
		local path = {}
		for y = -17, 0, 1 do
			table.insert(path, { feet = y, grounded = true })
		end
		for _, y in ipairs({ 3, 7, 12, 17, 19, 15, 8, 1.6 }) do
			table.insert(path, { feet = y, grounded = false })
		end
		table.insert(path, { feet = 1.6, grounded = true })
		for y = 31, 1, -2 do
			table.insert(path, { feet = y, grounded = true })
		end
		for i, s in ipairs(path) do
			t += 0.25
			local v = HeightGuard.evaluate(st, { feetY = s.feet, pos = Vector3.new(i, s.feet + 3, 0), grounded = s.grounded }, t)
			verdicts[v] = (verdicts[v] or 0) + 1
			if v == "revert" then
				bad += 1
			end
		end
		r.check(("물속 → 수면 → 뭍 점프 → 계단 폭포 헤엄(표본 %d · 헤엄 = 서 있음): 되돌림 %d(기대 0) · ok %d"):format(#path, bad, verdicts.ok or 0), bad == 0)
		r.check(("물 규칙 데이터: 물속 대시 %s · 물속 충전 %s(둘 다 false)"):format(tostring(MovementConfig.water.dashInWater), tostring(MovementConfig.water.rechargeInWater)),
			MovementConfig.water.dashInWater == false and MovementConfig.water.rechargeInWater == false)
	end)
	r.section("스폰 지점(지형 판정)", function()
		local bad, total = {}, 0
		local S = WorldMapData.spawnSites
		for _, z in ipairs(WorldMapData.zones) do
			local pts = WorldMapLayout.huntPoints(z)
			total += #pts
			for _, p in ipairs(pts) do
				local lo, hi = math.huge, -math.huge
				for _, q in ipairs({ p.position, p.slots[1], p.slots[2], p.slots[3] }) do
					local c = TerrainShape.column(q.X, q.Z)
					if c.water then
						table.insert(bad, z.key .. " 물")
					end
					lo, hi = math.min(lo, c.h), math.max(hi, c.h)
				end
				if hi - lo > S.terrain.maxRelief + 0.01 or hi - TerrainShape.flatY > S.terrain.maxAbove then
					table.insert(bad, ("%s %d 경사 %.1f"):format(z.key, p.index, hi - lo))
				end
				for _, c in ipairs(WorldStructures.data().cactus or {}) do
					if flat(Vector3.new(c.x, 0, c.z), p.position) < S.group.radius + 8 then
						table.insert(bad, z.key .. " 선인장")
					end
				end
			end
		end
		r.check(("스폰 지점 %d곳(구역 %d × %d): 물 · 경사(≤ %d) · 절벽 위 · 선인장 위반 %d%s"):format(total, #WorldMapData.zones, S.pointsPerRange, S.terrain.maxRelief, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ", 1, math.min(#bad, 6))) or ""),
			#bad == 0 and total == #WorldMapData.zones * S.pointsPerRange)
	end)
	r.section("봉우리 · 랜드마크 · 높은 곳 규칙", function()
		local maxByZone = {}
		for _, z in ipairs(WorldMapData.zones) do
			maxByZone[z.key] = 0
		end
		for _, p in ipairs(TerrainShape.peaks) do
			maxByZone[p.zone] = math.max(maxByZone[p.zone], p.h)
		end
		for _, pk in ipairs(TerrainShape.edgePeaks) do
			local z = TerrainShape.zoneAt(pk.x, pk.z)
			maxByZone[z.key] = math.max(maxByZone[z.key], pk.h)
		end
		local rows, ok = {}, true
		for _, z in ipairs(WorldMapData.zones) do
			table.insert(rows, ("%s %.0f"):format(z.key, maxByZone[z.key]))
			ok = ok and maxByZone[z.key] >= 200
		end
		r.check("구역마다 200+ 봉우리: " .. table.concat(rows, " · "), ok)
		local S = WorldStructures.data()
		local lm = { tier1 = "돌기둥 폐허 · 수호자 봉 · 비석 고리", tier2 = "수정 동굴 · 수정 군집 · 수정 첨탑", tier3 = "수중 신전 · 물살 강 · 바다 만", tier4 = "피라미드 · 선인장 밭 · 오아시스",
			tier5 = "천둥 신전 · 흔들다리 · 폭풍 첨탑", tier6 = "산 중턱 호수 · 빙벽 · 얼음 벽" }
		local have = S.structures.colonnade ~= nil and #(S.cactus or {}) > 0 and WorldStructures.nest("t5_b_thunder") ~= nil and WorldStructures.nest("t5_b_bridge") ~= nil
			and WorldStructures.nest("t3_b_temple") ~= nil and WorldStructures.nest("t2_b_cave") ~= nil and WorldStructures.nest("t6_b_icewall") ~= nil
		local list = {}
		for _, z in ipairs(WorldMapData.zones) do
			table.insert(list, z.key .. " " .. lm[z.key])
		end
		r.check("랜드마크 구역마다 1개 이상: " .. table.concat(list, " / "), have)
		local maxReach = 0
		for _, n in ipairs(WorldStructures.nestList()) do
			maxReach = math.max(maxReach, n.spot.Y - WorldMapData.floorTopY)
		end
		r.check(("높은 곳 규칙: 설계한 오를 곳 최고 %.0f < standMaxY %d(봉우리 200+는 경치 - 기어오르면 기존 규칙대로 허브)"):format(maxReach, WorldMapData.progress.standMaxY), maxReach < WorldMapData.progress.standMaxY)
	end)
	local pass, total = r.summary()
	print(("===M1-3T 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) ───────────────────────────
function V.runLive(player, env)
	print("===M1-3T 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local SaveSystem = require(script.Parent.SaveSystem)
	local HeightGuard = require(script.Parent.HeightGuard)
	local NestServer = require(script.Parent.NestServer)
	local TerrainBake = require(script.Parent.TerrainBake)
	local WorldHazards = require(script.Parent.WorldHazards)
	local Travel = require(script.Parent.Travel)
	local PlayerState = require(script.Parent.PlayerState)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	assert(root and humanoid, "캐릭터 없음")
	local guardOff = HeightGuard.debugOff
	HeightGuard.debugOff = true
	local function put(p)
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(p)
		HeightGuard.reset(player)
	end
	local profile = PlayerProfile.getProfile(player)
	r.section("굽힌 지형", function()
		local bad = TerrainBake.checkVersion()
		local cells = Workspace.Terrain:CountCells()
		r.check(("지형 셀 %d · 표식(버전 · 서명) 불일치 %d%s"):format(cells, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ")) or ""), cells > 0 and #bad == 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		local worst, n = 0, 0
		for _, e in ipairs(WorldCheck.essentials()) do
			if e.kind == "road" then
				for k = 0, 4 do
					local p = e.a:Lerp(e.b, k / 4)
					local hit = Workspace:Raycast(Vector3.new(p.X, 60, p.Z), Vector3.new(0, -120, 0), params)
					n += 1
					worst = math.max(worst, hit and math.abs(hit.Position.Y - TerrainShape.flatY) or 99)
				end
			end
		end
		r.check(("필수 길 실측(복셀 · 표본 %d): 지형 윗면 − 평지 최대 %.2f(기대 ≤ 1)"):format(n, worst), worst <= 1)
	end)
	r.section("둥지 캡슐 통과(굽기 뒤 복셀)", function()
		local bad, checked = TerrainBake.capsuleCheck(WorldStructures.nestList())
		r.check(("입구 → 둥지 캐릭터 몸통(폭 1.8 · 발 위 1.2 ~ 5.0) 점 %d: 막힘 %d%s"):format(checked, #bad, #bad > 0 and (" - " .. table.concat(bad, " / ", 1, math.min(#bad, 8))) or ""), #bad == 0)
	end)
	r.section("프롬프트 · C 표시 없음", function()
		local day = NestServer.dayIndex(os.time())
		local active, prompts, cLabels = 0, 0, {}
		for _, spec in ipairs(NestData.nests) do
			if NestServer.isActive(spec, day) then
				active += 1
				local a = NestServer.anchor(spec.id)
				if a and a.prompt.Enabled and a.prompt.KeyboardKeyCode == Enum.KeyCode.F and a.prompt.HoldDuration == 0 then
					prompts += 1
				end
			end
			if spec.track == "C" then
				local model = Workspace.Ground:FindFirstChild("Nest_" .. spec.id, true)
				for _, d in ipairs(model and model:GetDescendants() or {}) do
					if d:IsA("BillboardGui") or d:IsA("Highlight") or (d:IsA("BasePart") and (d:GetAttribute("Label") or d:GetAttribute("ExploreName"))) then
						table.insert(cLabels, spec.id)
					end
				end
			end
		end
		r.check(("오늘 켜진 둥지 %d(A 30 · B 18 · C 고정 6 · 순환 6 · 마을 4 = 64) · F 프롬프트 %d · C 둥지 이름표 · 빛 표지 %d"):format(active, prompts, #cLabels), active == 64 and prompts == active and #cLabels == 0)
		local guided = player:GetAttribute("BossGateId")
		r.check(("C 둥지는 길 안내 · 목표 추적 대상이 아니다(길 안내 = 관문만: %s)"):format(tostring(guided)), true)
	end)
	r.section("줍기", function()
		local spec = NestData.nests[2] -- t1_a_rock(A)
		local meta = WorldStructures.nest(spec.id)
		profile.world.nests[spec.id] = nil
		local eggsBefore = #profile.eggs
		put(meta.spot + Vector3.new(0, 3.2, 0))
		task.wait(1.0)
		local okEarly, whyEarly = NestServer.tryPickup(player, spec.id)
		r.check(("순간이동 1초 뒤 줍기 → %s(%s · 기대 teleport - 둥지 궤적 3초)"):format(tostring(okEarly), tostring(whyEarly)), not okEarly and whyEarly == "teleport")
		task.wait(2.6)
		local ok, egg = NestServer.tryPickup(player, spec.id)
		local rec = PlayerProfile.getNestRecord(player, spec.id)
		r.check(("A 둥지 위에서 줍기 → %s · 알 %s %s · 가방 %d → %d · 다음 = %d초 뒤(30분)"):format(tostring(ok), ok and egg.zone or "-", ok and egg.grade or tostring(egg), eggsBefore, #profile.eggs, rec.next - os.time()),
			ok and #profile.eggs == eggsBefore + 1 and math.abs(rec.next - os.time() - 1800) <= 2)
		task.wait(0.6)
		local ok2, why2 = NestServer.tryPickup(player, spec.id)
		r.check(("바로 다시 줍기 → %s(%s · 기대 cooldown) · 다른 사람 기준은 따로(개인 기록)"):format(tostring(ok2), tostring(why2)), not ok2 and why2 == "cooldown")
		-- 멀리서
		local far = WorldStructures.nest("t1_b_ruins")
		profile.world.nests[far.id] = nil
		put(WorldMapLayout.spawnPoint() + Vector3.new(0, 4, 0))
		task.wait(0.8)
		local ok3, why3 = NestServer.tryPickup(player, far.id)
		r.check(("허브에서 신전 둥지 줍기 요청 → %s(%s · 기대 far)"):format(tostring(ok3), tostring(why3)), not ok3 and why3 == "far")
		-- 순간이동 줍기: 허브에 서 있다가 둥지로 옮기자마자
		task.wait(0.7)
		put(far.spot + Vector3.new(0, 3.2, 0))
		task.wait(0.05)
		local ok4, why4 = NestServer.tryPickup(player, far.id)
		r.check(("순간이동 직후 줍기 → %s(%s · 기대 teleport 또는 far)"):format(tostring(ok4), tostring(why4)), not ok4 and (why4 == "teleport" or why4 == "far"))
		task.wait(3.4)
		local ok5 = NestServer.tryPickup(player, far.id)
		r.check(("그 자리에 3.4초 머문 뒤 줍기 → %s(B 둥지 · 사당 안)"):format(tostring(ok5)), ok5)
		-- 저장 왕복
		local okSave, why = SaveSystem.saveProfile(player, profile)
		local loaded = SaveSystem.loadProfile(player)
		local kept = loaded and loaded.world.nests[spec.id] and loaded.world.nests[spec.id].next == profile.world.nests[spec.id].next and #loaded.eggs == #profile.eggs
		r.check(("저장 %s(%s) → 다시 읽기: 개인 쿨다운 · 알 %d개 유지 %s"):format(tostring(okSave), tostring(why), #profile.eggs, tostring(kept)), okSave and kept)
	end)
	r.section("순환 · 번개 문", function()
		local zoneKey = "tier1"
		local today = NestServer.activeHidden(zoneKey, NestServer.dayIndex(os.time()))
		NestServer.debugDayShift = 1
		NestServer.refreshActive()
		local tomorrow = NestServer.activeHidden(zoneKey, NestServer.dayIndex(os.time()))
		local a = NestServer.anchor(today)
		local okInactive, why = NestServer.tryPickup(player, today)
		r.check(("하루 뒤(날짜 +1): T1 순환 둥지 %s → %s · 어제 곳 프롬프트 %s · 줍기 %s(%s · 기대 inactive)"):format(today, tostring(tomorrow), tostring(a and a.prompt.Enabled), tostring(okInactive), tostring(why)),
			tomorrow ~= today and a and not a.prompt.Enabled and not okInactive and why == "inactive")
		NestServer.debugDayShift = 0
		NestServer.refreshActive()
		local open = NestServer.timedOpen(Workspace:GetServerTimeNow())
		local doors, consistent = 0, true
		for _, d in ipairs(Workspace.Ground:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("TimedDoor") then
				doors += 1
				consistent = consistent and (d.CanCollide == not open)
			end
		end
		r.check(("번개 문 %d개 · 지금 열림 %s · 충돌 상태 일치 %s(주기 %d초 중 %d초 열림)"):format(doors, tostring(open), tostring(consistent), NestData.timedDoor.periodSeconds, NestData.timedDoor.openSeconds), doors == 1 and consistent)
	end)
	r.section("선인장 · 물 · 외곽", function()
		local c = WorldStructures.data().cactus[1]
		local hp0 = PlayerState.getHp(player)
		local hits0, cap0 = WorldHazards.stats.cactusHits, WorldHazards.stats.cactusCapped
		local st = WorldHazards.getState(player)
		if st then
			st.hits, st.lastHitAt = {}, -math.huge
		end
		put(Vector3.new(c.x + c.touch + 1.2, c.y + 3.1, c.z))
		local minHp = hp0
		for _ = 1, 18 do -- 4.5초(상한 창 5초 안 - 5초를 넘기면 창 경계에서 4번째가 정상으로 난다: Play 1)
			task.wait(0.25)
			root.CFrame = CFrame.new(Vector3.new(c.x + c.touch + 1.2, c.y + 3.1, c.z))
			minHp = math.min(minHp, PlayerState.getHp(player) or 0)
		end
		local hits = WorldHazards.stats.cactusHits - hits0
		r.check(("선인장 곁 4.5초: 피해 %d번(상한 %d) · 막힘 %d · 체력 %.0f → 최저 %.0f(0 아님)"):format(hits, WorldStructureDataHazard().maxPerWindow, WorldHazards.stats.cactusCapped - cap0, hp0 or 0, minHp or 0),
			hits >= 1 and hits <= WorldStructureDataHazard().maxPerWindow and (minHp or 0) > 0)
		PlayerState.setHp(player, PlayerState.getMaxHp(player))
		-- 물 판정(복셀) · 강 흐름(식)
		local zone = WorldMapLayout.zoneByKey("tier3")
		local R = TerrainGenData.zones.tier3.river
		local rp = WorldMapLayout.toWorld(zone, R.pts[5][1], R.pts[5][2])
		local wy, flow = TerrainShape.waterAt(rp.X, rp.Z)
		local inWater = WorldHazards.inWater(Vector3.new(rp.X, (wy or 0) - 2, rp.Z))
		local onLand = WorldHazards.inWater(WorldMapLayout.spawnPoint() + Vector3.new(0, 2, 0))
		r.check(("강 한가운데 물 판정 %s · 허브 %s · 흐름 %.1f(하류)"):format(tostring(inWater), tostring(onLand), flow and flow.Magnitude or 0), inWater and not onLand and flow ~= nil and flow.Magnitude > 0)
		-- 외곽 밀어내기(실제 폴링)
		HeightGuard.debugOff = guardOff
		-- 허용 반경 밖 · 높은 곳 복귀(standMaxY) 아래 비탈을 찾는다(Play 1: 212 비탈은 높은 곳 복귀가 먼저 허브로 보냈다 - 규칙대로)
		local q, top
		for a = -89, 89, 3 do
			for rr = TerrainGenData.edgeGuard.allowR + 15, 2900, 10 do
				local p = WorldMapLayout.dirOf(a) * rr
				local h = TerrainShape.height(p.X, p.Z)
				if not q and h - TerrainShape.flatY > 25 and h - TerrainShape.flatY < WorldMapData.progress.standMaxY - 30 and not TerrainShape.waterAt(p.X, p.Z) and TerrainShape.edgeAllowR(p.X, p.Z) < rr then
					q, top = p, h
				end
			end
		end
		assert(q, "시험 비탈 없음")
		local before = Travel.stateOf(player).edgePushes or 0
		put(Vector3.new(q.X, top + 3.2, q.Z))
		task.wait(1.2)
		local after = Travel.stateOf(player).edgePushes or 0
		local R2 = flat(root.Position, Vector3.zero)
		r.check(("설산 비탈(r %.0f · 높이 %.0f)에 서면 → 밀어내기 %d번 · 지금 반경 %.0f(≤ %d)"):format(flat(q, Vector3.zero), top - TerrainShape.flatY, after - before, R2, TerrainGenData.edgeGuard.allowR), after > before and R2 <= TerrainGenData.edgeGuard.allowR)
		HeightGuard.debugOff = true
		r.check(("MaxSlopeAngle(지금 캐릭터) = %.0f°(TerrainConfig 45 - 걷는 경사 한계)"):format(humanoid.MaxSlopeAngle), math.abs(humanoid.MaxSlopeAngle - 45) < 0.5)
	end)
	r.section("스폰 지점 실측 높이", function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain, Workspace.Ground }
		params.IgnoreWater = false
		local worst, water, n = 0, 0, 0
		for _, z in ipairs(WorldMapData.zones) do
			for _, p in ipairs(WorldMapLayout.huntPoints(z)) do
				for _, s in ipairs(p.slots) do
					local hit = Workspace:Raycast(Vector3.new(s.X, s.Y + 40, s.Z), Vector3.new(0, -80, 0), params)
					n += 1
					if hit and hit.Material == Enum.Material.Water then
						water += 1
					end
					worst = math.max(worst, hit and math.abs(hit.Position.Y - s.Y) or 99)
				end
			end
		end
		r.check(("스폰 슬롯 %d곳 실측: 지면 높이 차 최대 %.2f(기대 ≤ 1.5) · 물 %d"):format(n, worst, water), worst <= 1.5 and water == 0)
	end)
	-- 정리
	NestServer.debugDayShift = 0
	NestServer.refreshActive()
	put(WorldMapLayout.spawnPoint() + Vector3.new(0, 5, 0))
	HeightGuard.debugOff = guardOff
	env.restore(player)
	NestServer.sync(player)
	local pass, total = r.summary()
	print(("===M1-3T 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
