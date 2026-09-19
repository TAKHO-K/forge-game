-- 보스 아레나 논리 지형의 기하(29-3, PRD 20.76) - 순수 함수. 서버 판정(BossArenaProps·BossGimmicks), 클라 그리기
-- (BossArenaPropsView), 로컬 하네스가 같은 식을 쓴다. 전부 XZ 평면이다(기둥은 세로 원기둥이라 위에서 본 원).
--
-- "기둥 뒤"의 정의(서리 거인의 포효): 보스 중심 → 플레이어 선분이 기둥 원을 지나가고, 플레이어가 기둥 중심보다
-- 보스에서 멀다. 가장자리에 걸친 경우는 **플레이어에게 유리하게** 친다 - 선분이 기둥 중심에서 (기둥 반경 + 몸통 반폭)
-- 안을 지나면 가려진 것이다(몸이 그림자에 조금이라도 걸쳤으면 산다). 다른 패턴의 "빨강 안이면 맞는다"는 루트
-- 좌표 한 점으로 재지만, 안전지대는 거꾸로 "좁게 그리고 넓게 판정한다" - 화면에 그린 그림자(폭 = 기둥 지름의 띠)
-- 안에 서 있으면 반드시 안전하고, 그 바깥 1stud까지도 안전하다. "보이는 것보다 덜 맞는" 쪽으로만 어긋난다.

local BossPropMath = {}

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- 점 c에서 선분 a-b(XZ)까지의 거리.
function BossPropMath.distanceToSegment(c, a, b)
	a, b, c = flat(a), flat(b), flat(c)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (c - a).Magnitude
	end
	local t = math.clamp((c - a):Dot(ab) / len2, 0, 1)
	return (c - (a + ab * t)).Magnitude
end

-- from(보스 중심)에서 본 to(플레이어)가 기둥(center·radius)에 가려지는가.
function BossPropMath.isShielded(from, to, center, radiusStuds, bodyHalfWidthStuds)
	if BossPropMath.distanceToSegment(center, from, to) > radiusStuds + bodyHalfWidthStuds then
		return false
	end
	-- 기둥 "안"은 뒤가 아니다 - 낙빙을 맞고 그 자리에 선 채로(기둥은 그 사람이 빠져나올 때까지 그 사람에게만 충돌이
	-- 꺼져 있다, BossArenaPropsView) 포효까지 넘기는 길을 막는다. 빠져나와 뒤로 돌아가는 데는 몇 걸음이면 된다.
	if (flat(to) - flat(center)).Magnitude < radiusStuds then
		return false
	end
	local axis = flat(center) - flat(from)
	if axis.Magnitude < 1e-3 then
		return false
	end
	-- 보스 → 기둥 축으로 잰 플레이어의 거리가 기둥 중심 이상이어야 "뒤"다(기둥 앞에 붙어 선 것은 뒤가 아니다).
	return (flat(to) - flat(from)):Dot(axis.Unit) >= axis.Magnitude
end

-- 기둥 뒤에 서는 자리 - 기둥 중심에서 보스 반대쪽으로 (반경 + marginStuds). 힌트 화살표·포효 선행 조건이 쓴다.
function BossPropMath.safeSpot(from, center, radiusStuds, marginStuds)
	local axis = flat(center) - flat(from)
	local dir = axis.Magnitude > 1e-3 and axis.Unit or Vector3.new(0, 0, 1)
	return Vector3.new(center.X, center.Y, center.Z) + dir * (radiusStuds + marginStuds)
end

-- origin에서 단위벡터 dir 방향으로 뻗는 반폭 halfWidth의 띠가 기둥에 처음 닿는 거리(안 닿으면 nil).
-- 얼음 가시가 기둥에서 끊기는 자리다 - 띠의 가장자리만 스쳐도 막힌 것으로 친다(막아 주는 쪽이 플레이어에게 유리하다).
function BossPropMath.rayHitDistance(origin, dir, maxLengthStuds, halfWidthStuds, center, radiusStuds)
	local rel = flat(center) - flat(origin)
	local along = rel:Dot(dir)
	if along <= 0 or along - radiusStuds > maxLengthStuds then
		return nil
	end
	local side = (rel - dir * along).Magnitude
	if side > radiusStuds + halfWidthStuds then
		return nil
	end
	return math.max(along - radiusStuds, 0)
end

return BossPropMath
