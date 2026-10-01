-- QUEUE-ALL1 P3 §4 합동 목표 순수 규칙(서버 CommunityGoalService · 검증이 같은 식). 수치 = shared/data/CommunityGoalData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local D = require(ReplicatedStorage.Shared.data.CommunityGoalData)

local Rules = {}

-- QUEUE-ALL7 B: 가장 가까운 D.roundTo(100) 배수
function Rules.round(x)
	return math.floor((x or 0) / D.roundTo + 0.5) * D.roundTo
end

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
	return Rules.finalTarget(target) -- QUEUE-ALL7 B1: 제한 → 반올림(순서 고정)
end

function Rules.week1Target(total24)
	return Rules.finalTarget((total24 or 0) * 7 * D.week1Factor) -- QUEUE-ALL7 B2
end

-- QUEUE-ALL7 B: 마무리 = 반올림 · 최솟값 · 마지막 칸(100%) 문턱과 같게(작은 목표 300은 85% 칸과 겹쳐 100% 칸이 +100 → 목표도 그 값 - 진행 %와 칸이 어긋나지 않게)
function Rules.finalTarget(x)
	local target = math.max(D.minTarget, Rules.round(x))
	local th = Rules.thresholds(target)
	return math.max(target, th[#th] or target)
end

-- QUEUE-ALL7 B3: 칸 문턱(진행값이 이만큼 이상이면 그 칸) = fraction × 목표를 각각 반올림 · 반올림 뒤 앞 칸과 같거나 작으면 +roundTo(항상 오름차순)
function Rules.thresholds(target)
	local out = {}
	if not (type(target) == "number" and target > 0) then
		return out
	end
	if target % D.roundTo ~= 0 then -- 리뷰: 이미 정해진 옛 목표(00 아님 - 배포 전 주) = 옛 문턱 그대로(주 중간에 닿은 칸이 뒤로 가지 않게)
		for i, t in ipairs(D.tiers) do
			out[i] = t.fraction * target
		end
		return out
	end
	for i, t in ipairs(D.tiers) do
		local v = math.max(D.roundTo, Rules.round(t.fraction * target))
		if i > 1 and v <= out[i - 1] then
			v = out[i - 1] + D.roundTo
		end
		out[i] = v
	end
	return out
end

-- 닿은 칸 수(0 ~ #tiers)
function Rules.tiersReached(total, target)
	if not (type(target) == "number" and target > 0) then
		return 0
	end
	local n = 0
	for i, v in ipairs(Rules.thresholds(target)) do -- QUEUE-ALL7 B3: 00 문턱(화면에 보이는 숫자 그대로)
		if total >= v then
			n = i
		end
	end
	return n
end

return Rules
