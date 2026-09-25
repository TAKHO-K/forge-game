-- P3c A5 맵 이탈 방지의 계산(순수 함수 - 서버 · 클라 · 검증 시뮬이 같은 함수를 쓴다). 규칙과 수치 = BossArenaMapData.containment 주석.
--   limitLaunch  넉백 한 번의 높이 · 수평 거리를 상한으로 자르고, 착지점이 벽에서 innerMarginStuds 안쪽을 넘지 않게 거리를 줄인다(클라 BossStormView가 부른다)
--   isOutside    원 밖(outsideToleranceStuds 넘게) · 바닥 아래(fallDepthStuds)인가(서버 BossArenaContainment가 부른다)
--   rescuePoint  복귀 자리 = 지금 방위로 벽에서 rescueInsetStuds 안쪽 - 구조물(blocked)이면 중심 쪽으로 더 들어간다
--   simulate     무작위 패턴 조합 trials회(검증 P3c(가) - 이탈 0이어야 한다)
-- 전부 XZ 평면 기준이고 Y는 바닥 윗면(floorTopY)에서 잰다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)

local CONTAINMENT = BossArenaMapData.containment

local ArenaContainment = {}

-- 넉백 한 번. zone = { center, radius }(원형 아레나) · position = 지금 루트 · away = 수평 방향(단위 아니어도 된다 - 0이면 거리 0).
-- 반환: 높이, 수평 거리(상한 · 착지 경계를 거친 값).
function ArenaContainment.limitLaunch(zone, position, away, heightStuds, distanceStuds)
	local height = math.clamp(heightStuds or 0, 0, CONTAINMENT.maxLaunchHeightStuds)
	local distance = math.clamp(distanceStuds or 0, 0, CONTAINMENT.maxLaunchDistanceStuds)
	if zone and zone.radius and distance > 0 then
		local flat = Vector3.new(away.X, 0, away.Z)
		if flat.Magnitude < 1e-3 then
			return height, 0
		end
		distance = math.min(distance, ArenaShape.clip(zone, position, flat.Unit, CONTAINMENT.innerMarginStuds))
	end
	return height, distance
end

function ArenaContainment.isOutside(zone, position, floorTopY)
	if not ArenaShape.contains(zone, position, -CONTAINMENT.outsideToleranceStuds) then
		return true, "outside"
	end
	if floorTopY and position.Y < floorTopY - CONTAINMENT.fallDepthStuds then
		return true, "fell"
	end
	return false, nil
end

-- G1-0: 발(feetY)이 "바닥 위가 아닌" 높이인가 - 벽 윗면 − offFloorBelowWallTopStuds 이상(벽 위에 선 사람). 시간 조건(offFloorReturnSeconds)은 호출자가 잰다.
function ArenaContainment.isOffFloorHeight(feetY, floorTopY, wallHeightStuds)
	return feetY >= floorTopY + wallHeightStuds - CONTAINMENT.offFloorBelowWallTopStuds
end

-- blocked(point) → bool(선택): 그 자리가 구조물 안인가. 반환: 복귀 자리(XZ, Y = 들어온 값 그대로 - 호출자가 바닥 위로 올린다).
function ArenaContainment.rescuePoint(zone, position, blocked)
	local inset = CONTAINMENT.rescueInsetStuds
	local point = ArenaShape.clamp(zone, position, inset)
	local toCenter = Vector3.new(zone.center.X - point.X, 0, zone.center.Z - point.Z)
	for _ = 1, 40 do
		if not blocked or not blocked(point) then
			return point
		end
		if toCenter.Magnitude < 1 then
			break
		end
		point += toCenter.Unit * 2
	end
	return Vector3.new(zone.center.X, position.Y, zone.center.Z)
end

-- ─────────────────────────── 이탈 시뮬레이션(P3c A5) ───────────────────────────
-- 한 조합 = 무작위 시작 자리(절반은 벽 5stud 안 - 가장 위험한 곳) + 사건 1 ~ maxEvents개. 사건은 실제 패턴의 파라미터를 그대로 쓴다(params):
--   strike  낙뢰 넉백 - 판정 원 중심이 원 반경 안 무작위, 함께 맞은 사람 1 ~ 4명(높이 가산 · 상한)
--   topBreak 구조물 파편 넉백(구조물 위에 서 있다가) · whirl 회오리(중심을 벽에서 spin + 2 안쪽으로 자르고 그 둘레 spin) · push 모래 무덤 끌기(ArenaShape.clamp 2)
--   dash    대시(벽에 막힌다 - DashEndpoint의 Raycast = 벽 앞 1stud에서 멈춘다) · walk 걷기(벽이 막는다)
-- 넉백은 limitLaunch를 거친 착지점, 정점 높이 = 발판 높이(사건마다 30%는 큰 블록 위 - perchHeightStuds) + 넉백 높이. 이탈 = isOutside(착지 · 매 사건 뒤) 또는 정점이 벽 윗면 이상.
-- params = { strike = { heightStuds, distanceStuds, extraHeightPerCoHit, maxHeightStuds, radiusStuds }, topBreak = { heightStuds, distanceStuds },
--   whirlSpinStuds, pushStuds, dashStuds, walkStuds, perchHeightStuds(구조물 윗면), wallHeightStuds }
function ArenaContainment.simulate(zone, params, trials, seed, maxEvents)
	local state = seed or 1
	local function rand()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local function randomDir()
		local angle = rand() * 2 * math.pi
		return Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local radius = zone.radius
	local counts = { trials = 0, exits = 0, overWall = 0, maxApex = 0, maxRadial = 0, byKind = {} }
	for _ = 1, trials do
		counts.trials += 1
		local r = rand() < 0.5 and (radius - 1 - rand() * 4) or (math.sqrt(rand()) * (radius - 1))
		local position = zone.center + randomDir() * r
		local escaped = false
		for _ = 1, 1 + math.floor(rand() * (maxEvents or 6)) do
			local kinds = { "strike", "topBreak", "whirl", "push", "dash", "walk" }
			local kind = kinds[1 + math.floor(rand() * #kinds)]
			counts.byKind[kind] = (counts.byKind[kind] or 0) + 1
			local apex = 0
			local perch = rand() < 0.3 and params.perchHeightStuds or 0
			if kind == "strike" then
				local p = params.strike
				local from = position + randomDir() * (rand() * p.radiusStuds)
				local coHits = 1 + math.floor(rand() * 4)
				local height = math.min(p.heightStuds + (p.extraHeightPerCoHit or 0) * (coHits - 1), p.maxHeightStuds or math.huge)
				local away = position - from
				local h, d = ArenaContainment.limitLaunch(zone, position, away, height, p.distanceStuds)
				if away.Magnitude > 1e-3 then
					position += Vector3.new(away.X, 0, away.Z).Unit * d
				end
				apex = perch + h
			elseif kind == "topBreak" then
				local p = params.topBreak
				local away = randomDir()
				local h, d = ArenaContainment.limitLaunch(zone, position, away, p.heightStuds, p.distanceStuds)
				position += away * d
				apex = params.perchHeightStuds + h
			elseif kind == "whirl" then
				local center = ArenaShape.clamp(zone, position, params.whirlSpinStuds + 2)
				position = center + randomDir() * params.whirlSpinStuds
				apex = perch + math.min(params.whirlHeightStuds or 0, CONTAINMENT.maxLaunchHeightStuds)
			elseif kind == "push" then
				position = ArenaShape.clamp(zone, position + randomDir() * params.pushStuds, 2)
			elseif kind == "dash" then
				local dir = randomDir()
				position += dir * math.min(params.dashStuds, math.max(ArenaShape.clip(zone, position, dir, 1), 0))
			else
				local dir = randomDir()
				position += dir * math.min(rand() * params.walkStuds, math.max(ArenaShape.clip(zone, position, dir, 1), 0))
			end
			counts.maxApex = math.max(counts.maxApex, apex)
			local dx, dz = position.X - zone.center.X, position.Z - zone.center.Z
			counts.maxRadial = math.max(counts.maxRadial, math.sqrt(dx * dx + dz * dz))
			if apex >= params.wallHeightStuds then
				counts.overWall += 1
				escaped = true
			end
			if ArenaContainment.isOutside(zone, position, nil) then
				escaped = true
			end
		end
		if escaped then
			counts.exits += 1
		end
	end
	return counts
end

-- ─────────────────────────── 이탈 · 복귀 시뮬레이션(P3d B3) ───────────────────────────
-- ①②가 뚫렸다고 치고(넉백을 상한 없이 원래 값 × 1 ~ 3으로 준다 - 이탈을 억지로 만든다) ③ 복귀 규칙만 잰다. 한 조합 = 멤버 1명(파티 1 ~ 4명 중 순번) · 무작위 시작 ·
-- 사건 1 ~ maxEvents개(사건 사이 0.05 ~ 1.5초). 복귀 = 스폰 자리(params.spawns[순번]) · 체력 비율과 기믹 누적은 그대로 · 보호 protectSeconds(넉백 무시 · 받는 피해 0).
-- 셈: exits(이탈) · returns(복귀) · chainExits(복귀 뒤 보호 + 검사 간격 안에 다시 이탈) · hpChanged · stacksChanged(복귀가 바꾼 것) · spawnOutside(스폰 자리가 원 밖) ·
-- suppressed(보호로 무시한 넉백).
-- params = { spawns = { [파티 인원] = { [순번] = Vector3 } }, launchDistance, damagePerHit(최대체력 비율), protectSeconds, checkSeconds, walkStuds, dashStuds,
--   chainWindowSeconds(연쇄로 볼 복귀 뒤 창 - 생략 = 보호 + 검사 간격. 보호 0과 비교할 때는 같은 창을 준다) }
function ArenaContainment.simulateReturn(zone, params, trials, seed, maxEvents)
	local state = seed or 1
	local function rand()
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	local function randomDir()
		local angle = rand() * 2 * math.pi
		return Vector3.new(math.cos(angle), 0, math.sin(angle))
	end
	local counts = { trials = 0, exits = 0, returns = 0, chainExits = 0, hpChanged = 0, stacksChanged = 0, spawnOutside = 0, suppressed = 0, events = 0 }
	for _ = 1, trials do
		counts.trials += 1
		local size = 1 + math.floor(rand() * 4)
		local index = 1 + math.floor(rand() * size)
		local spawn = params.spawns[size][index]
		if ArenaContainment.isOutside(zone, spawn, nil) then
			counts.spawnOutside += 1
		end
		local r = rand() < 0.5 and (zone.radius - 1 - rand() * 4) or (math.sqrt(rand()) * (zone.radius - 1))
		local position = zone.center + randomDir() * r
		local hp = 0.2 + rand() * 0.8
		local stacks = { gimmickDamage = math.floor(rand() * 4) * 0.1375, reflects = math.floor(rand() * 3), zoneSteps = math.floor(rand() * 2) }
		local t, protectUntil, lastReturn = 0, -math.huge, -math.huge
		for _ = 1, 1 + math.floor(rand() * (maxEvents or 6)) do
			counts.events += 1
			t += 0.05 + rand() * 1.45
			local protected = t < protectUntil
			local kind = rand()
			if kind < 0.5 then -- 넉백(낙뢰 · 구조물 파편 · 회오리 무리)
				if protected then
					counts.suppressed += 1
				else
					hp = math.max(hp - params.damagePerHit, 0.01) -- 그 기술의 피해는 받는다
					local scale = 1 + rand() * 2
					position += randomDir() * params.launchDistance * scale
				end
			elseif kind < 0.75 then -- 대시(벽에 막힌다)
				local dir = randomDir()
				position += dir * math.min(params.dashStuds, math.max(ArenaShape.clip(zone, position, dir, 1), 0))
			else -- 걷기(벽이 막는다)
				local dir = randomDir()
				position += dir * math.min(rand() * params.walkStuds, math.max(ArenaShape.clip(zone, position, dir, 1), 0))
			end
			if ArenaContainment.isOutside(zone, position, nil) then
				counts.exits += 1
				if t <= lastReturn + (params.chainWindowSeconds or (params.protectSeconds + params.checkSeconds)) then
					counts.chainExits += 1
				end
				-- ③ 복귀: 스폰 자리로 순간이동만 - 체력 · 누적은 그대로
				local hpBefore, stacksBefore = hp, table.clone(stacks)
				position = spawn
				counts.returns += 1
				if hp ~= hpBefore then
					counts.hpChanged += 1
				end
				for key, value in pairs(stacksBefore) do
					if stacks[key] ~= value then
						counts.stacksChanged += 1
					end
				end
				protectUntil = t + params.protectSeconds
				lastReturn = t
			end
		end
	end
	return counts
end

return ArenaContainment
