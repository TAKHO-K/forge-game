-- QUEUE-ALL1 P3 §4 합동 목표 순수 규칙(서버 CommunityGoalService · 검증이 같은 식). 수치 = shared/data/CommunityGoalData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local D = require(ReplicatedStorage.Shared.data.CommunityGoalData)

local Rules = {}

-- history = { { total, target? } 지난주부터 } → 이번 주 목표(nil = 기록 없음 - 1주차 규칙)
function Rules.targetFromHistory(history)
	local sum, wsum = 0, 0
	for i, w in ipairs(D.baselineWeights) do
		local h = history[i]
		if h and type(h.total) == "number" and h.total > 0 then
			sum += h.total * w
			wsum += w
		end
	end
	if wsum <= 0 then
		return nil
	end
	local baseline = sum / wsum
	local target = baseline * D.targetFactor
	local prev = history[1] and history[1].target
	if type(prev) == "number" and prev > 0 then
		target = math.clamp(target, prev * (1 - D.weeklyChangeCap), prev * (1 + D.weeklyChangeCap))
	end
	return math.max(1, math.floor(target + 0.5))
end

function Rules.week1Target(total24)
	return math.max(1, math.floor((total24 or 0) * 7 * D.week1Factor + 0.5))
end

-- 닿은 칸 수(0 ~ #tiers)
function Rules.tiersReached(total, target)
	if not (type(target) == "number" and target > 0) then
		return 0
	end
	local n = 0
	for i, t in ipairs(D.tiers) do
		if total >= t.fraction * target then
			n = i
		end
	end
	return n
end

return Rules
