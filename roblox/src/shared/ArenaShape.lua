-- 구역 모양 판정의 단일 출처(P3a C). zone = WorldConfig.zones[...] - radius가 있으면 원(보스 아레나), 없으면 옛 정사각형(halfSize, 사냥 구역).
-- 보스 패턴의 자르기(원 중심 · 돌진 도착점 · 직선 길이 · 분열 자리 · 회오리 중심) · 구역 경계(MonsterAI 리쉬 · ZoneBounds) · 모래 무덤 밀기가 같은 함수를 쓴다.
-- 전부 XZ 평면 - Y는 건드리지 않는다.

local ArenaShape = {}

-- 점이 구역 안인가(margin만큼 안쪽 경계 - 기본 0).
function ArenaShape.contains(zone, position, margin)
	margin = margin or 0
	local dx, dz = position.X - zone.center.X, position.Z - zone.center.Z
	if zone.radius then
		local limit = zone.radius - margin
		return dx * dx + dz * dz <= limit * limit
	end
	local limit = zone.halfSize - margin
	return math.abs(dx) <= limit and math.abs(dz) <= limit
end

-- 점을 구역 안(margin만큼 안쪽)으로 누른다. 원이면 중심 방향으로(가장 가까운 안쪽 점), 정사각형이면 축마다 자른다.
function ArenaShape.clamp(zone, position, margin)
	margin = margin or 0
	if zone.radius then
		local dx, dz = position.X - zone.center.X, position.Z - zone.center.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		local limit = math.max(zone.radius - margin, 0)
		if distance <= limit then
			return position
		end
		local scale = limit / distance
		return Vector3.new(zone.center.X + dx * scale, position.Y, zone.center.Z + dz * scale)
	end
	return Vector3.new(
		math.clamp(position.X, zone.center.X - zone.halfSize + margin, zone.center.X + zone.halfSize - margin),
		position.Y,
		math.clamp(position.Z, zone.center.Z - zone.halfSize + margin, zone.center.Z + zone.halfSize - margin)
	)
end

-- origin에서 XZ 단위벡터 dir 방향으로 구역(margin만큼 안쪽) 안에 머무는 최대 거리(0 이상). origin이 밖이고 바깥쪽을 향하면 0.
-- P3c A3: origin이 경계 **위나 아주 조금 밖**(돌진이 벽 여백에서 멈춘 자리 - 부동소수로 limit보다 1e-13쯤 크다)이어도 안쪽을 향하면 반대편 경계까지를 돌려준다.
-- 옛 식은 c > 0이면 0이라 전갈 여왕의 둘째 돌진(벽에서 멈춘 자리에서 다시 출발)이 길이 0이 됐다(P3c Play 1 - "경로 0.0stud").
function ArenaShape.clip(zone, origin, dir, margin)
	margin = margin or 0
	if zone.radius then
		local limit = zone.radius - margin
		local ox, oz = origin.X - zone.center.X, origin.Z - zone.center.Z
		-- |o + t·d|² = limit² 의 큰 근(d는 단위벡터).
		local b = ox * dir.X + oz * dir.Z
		local c = ox * ox + oz * oz - limit * limit
		local discriminant = b * b - c
		if discriminant < 0 or (c > 0 and b >= 0) then
			return 0
		end
		return math.max(-b + math.sqrt(discriminant), 0)
	end
	local tMax = math.huge
	for _, axis in ipairs({ "X", "Z" }) do
		local d = dir[axis]
		if math.abs(d) > 1e-6 then
			local lo = zone.center[axis] - zone.halfSize + margin
			local hi = zone.center[axis] + zone.halfSize - margin
			tMax = math.min(tMax, ((d > 0 and hi or lo) - origin[axis]) / d)
		end
	end
	return math.max(tMax, 0)
end

-- 구역을 덮는 반폭(원이면 반경) - 크기에 기대는 값(스케줄러 상한 · 전역 기믹 바닥)이 쓴다.
function ArenaShape.extent(zone)
	return zone.radius or zone.halfSize
end

return ArenaShape
