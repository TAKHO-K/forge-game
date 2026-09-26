-- W1 모션 시각 계산(순수 - 클라 재생 · 서버 원거리 발사 시각 · 검증 시각표가 같은 함수를 쓴다).
--   공격 클립 = 전조(ant) → 동작(act) → 회복(rec) · 타격 프레임 = 전조 끝(PlayerMotionData 머리 주석).
--   공격 속도 배율(상한 CombatConfig.attackSpeedMaxMultiplier ×2.5 · 버프는 그 위에 곱) → 전체 길이 = 원래 ÷ 배율.
--   줄이는 순서(W1-3): 전조 → 회복 → 동작(타격 프레임이 보이게 동작은 마지막 · 최소 길이 보장).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)

local MotionTiming = {}

local RANGED = { bow = true, healer = true }

-- 콤보 수(1부터) → 1 ~ 3타.
function MotionTiming.comboIndex(comboCount)
	return ((math.max(comboCount or 1, 1) - 1) % 3) + 1
end

function MotionTiming.isRanged(classId)
	return RANGED[classId] == true
end

-- 클립 원본(없으면 nil). air = 공중 공격 · 3타 강공격도 attacks[3](느리게는 scale이).
function MotionTiming.clip(classId, index, air)
	local w = PlayerMotionData.weapons[classId]
	if not w then
		return nil
	end
	if air and w.air then
		return w.air
	end
	return w.attacks[math.clamp(index or 1, 1, #w.attacks)]
end

-- 배율 적용 구간 길이. 반환 { ant, act, rec, total, hit(= ant) }.
function MotionTiming.scale(clip, speed, heavy)
	local S = PlayerMotionData.speedScale
	local ant, act, rec = clip.ant, clip.act, clip.rec
	if heavy then
		act /= PlayerMotionData.heavySlow
		rec /= PlayerMotionData.heavySlow
	end
	speed = math.max(speed or 1, 1)
	local total = ant + act + rec
	local over = total - total / speed
	local function take(value, minValue)
		local cut = math.clamp(value - minValue, 0, over)
		over -= cut
		return value - cut
	end
	ant = take(ant, math.min(ant, math.max(ant * S.antMinFraction, S.antMinSeconds)))
	rec = take(rec, rec * S.recMinFraction)
	act = take(act, math.min(act, math.max(act * S.actMinFraction, S.actMinSeconds)))
	if over > 1e-9 then -- 최소 길이로도 못 맞추면: 회복 → 전조를 더(0.01까지) 줄이고, 그래도 넘으면 셋을 같은 비율로(타격 프레임은 여전히 전조 끝)
		rec = take(rec, math.min(rec, 0.01))
		ant = take(ant, math.min(ant, 0.01))
		if over > 1e-9 then
			local k = (ant + act + rec - over) / (ant + act + rec)
			ant, act, rec = ant * k, act * k, rec * k
		end
	end
	return { ant = ant, act = act, rec = rec, total = ant + act + rec, hit = ant }
end

-- 애니메이션 타격 프레임(요청 순간 = 0부터 초).
function MotionTiming.hitSeconds(classId, index, speed, heavy, air)
	local clip = MotionTiming.clip(classId, index, air)
	return clip and MotionTiming.scale(clip, speed, heavy).hit or 0
end

-- 서버 피해 시각(요청을 받은 순간 = 0부터 · 투사체 비행 시간 제외): 근접 = 즉시(0) · 원거리 = 발사 = 이 함수(서버 AttackServer가 부른다).
function MotionTiming.serverSeconds(classId, index, speed, heavy, air)
	if not RANGED[classId] then
		return 0
	end
	return MotionTiming.hitSeconds(classId, index, speed, heavy, air)
end

-- 시각표(W1-4 검증 · 보고서): 무기 × 타(1 · 2 · 3 · 강 · 공중) × 배율 → { classId, label, speed, anim, server, diff }.
function MotionTiming.table(speeds)
	local rows = {}
	local order = { "greatsword", "dualblade", "bow", "healer", "paladin" }
	for _, classId in ipairs(order) do
		if PlayerMotionData.weapons[classId] then
			for _, speed in ipairs(speeds or { 1, 2.5 }) do
				for _, hit in ipairs({ { "1타", 1 }, { "2타", 2 }, { "3타", 3 }, { "강공격", 3, true }, { "공중", 1, false, true } }) do
					local anim = MotionTiming.hitSeconds(classId, hit[2], speed, hit[3], hit[4])
					local server = MotionTiming.serverSeconds(classId, hit[2], speed, hit[3], hit[4])
					table.insert(rows, { classId = classId, label = hit[1], speed = speed, anim = anim, server = server, diff = math.abs(anim - server) })
				end
			end
		end
	end
	return rows
end

return MotionTiming
