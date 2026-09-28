-- Q1 잡몹 모양 공격 판정(순수 함수 - 서버 MonsterAI 판정 · 클라 MobAttackView 예고 모양 · 하네스가 같은 함수를 쓴다).
--   attack = MonsterSpeciesData.species[id].attacks[n] 조각: shape = "cone"(앞 부채꼴 - range · halfAngle 도) · "rearArc"(뒤 반원 - range) · "circle"(주변 원 - range).
--   facing = 전조를 시작한 순간 몹이 보던 수평 방향(전조 동안 고정 - 옆으로 빠지면 피한다). 높이 차는 heightStuds(기본 8 = Reach 높이 상한과 같은 값) 안만.
local MobAttackShape = {}

local DEFAULT_HEIGHT = 8

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

-- origin(몹 루트) · facing(수평 단위 벡터) · point(맞는 사람 루트)
function MobAttackShape.contains(attack, origin, facing, point)
	if math.abs(point.Y - origin.Y) > (attack.heightStuds or DEFAULT_HEIGHT) then
		return false
	end
	local d = flat(point - origin)
	local dist = d.Magnitude
	if dist > attack.range then
		return false
	end
	if attack.shape == "circle" then
		return true
	end
	if dist < 1e-6 then
		return true -- 발밑 = 어느 모양이든 맞는다
	end
	local cosA = flat(facing).Unit:Dot(d / dist)
	if attack.shape == "cone" then
		return cosA >= math.cos(math.rad(attack.halfAngle or 35)) - 1e-6
	elseif attack.shape == "rearArc" then
		return cosA <= 1e-6 -- 등 뒤 반원(옆 90°까지)
	end
	return false
end

-- 대상이 등 뒤에 있는가(prefer = "behind" 공격을 고를 때)
function MobAttackShape.isBehind(origin, facing, point)
	local d = flat(point - origin)
	if d.Magnitude < 1e-6 then
		return false
	end
	return flat(facing).Unit:Dot(d.Unit) < 0
end

-- 다음 공격 고르기: 대상이 등 뒤면 prefer = "behind" 공격 · 아니면 prefer 없는 공격을 차례로(counter = 몹마다 센 횟수).
-- distance(선택) = 대상까지 수평 거리 - 범위(range)가 그보다 짧은 공격은 뺀다(Q1 리뷰: 돌풍 10 < 전조 거리 12). 반환 = attack(없으면 nil), 새 counter
function MobAttackShape.choose(attacks, behind, counter, distance)
	local function fits(attack)
		return distance == nil or attack.range >= distance
	end
	if behind then
		for _, attack in ipairs(attacks) do
			if attack.prefer == "behind" and fits(attack) then
				return attack, counter
			end
		end
	end
	local front = {}
	for _, attack in ipairs(attacks) do
		if attack.prefer ~= "behind" then
			table.insert(front, attack)
		end
	end
	if #front == 0 then
		return nil, counter
	end
	local nextCounter = counter or 0
	for _ = 1, #front do -- 차례대로 보되 범위가 안 맞는 공격은 건너뛴다(차례는 넘긴다)
		nextCounter += 1
		local attack = front[(nextCounter - 1) % #front + 1]
		if fits(attack) then
			return attack, nextCounter
		end
	end
	return nil, counter
end

return MobAttackShape
