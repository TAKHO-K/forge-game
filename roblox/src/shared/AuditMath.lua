-- S1 획득 감사 순수 계산(서버 AcquisitionAudit · 저장 이관 SaveSystem · 검증이 같이 쓴다). 수치 = data/AuditConfig.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AuditConfig = require(ReplicatedStorage.Shared.data.AuditConfig)

local AuditMath = {}
local C = AuditConfig

-- P(X ≥ k | λ) - 포아송 꼬리(1 − Σ_{i<k} e^−λ λ^i / i!). λ가 작고 k가 크면 첫 항이 지배한다 - 로그로 합쳐 밑넘침 없이.
function AuditMath.poissonTail(k, lambda)
	if k <= 0 then
		return 1
	end
	if lambda <= 0 then
		return 0
	end
	if lambda > 30 then -- 큰 λ = 정규 근사(여기서는 검사가 안 걸린다)
		local z = (k - 0.5 - lambda) / math.sqrt(lambda)
		return 0.5 * (1 - math.tanh(z * 0.7978845608 * (1 + 0.044715 * z * z)))
	end
	-- 꼬리를 직접 합한다(i = k … k + 60): e^−λ λ^i / i!
	local logTerm = -lambda + k * math.log(lambda)
	for i = 2, k do
		logTerm -= math.log(i)
	end
	local sum, term = 0, math.exp(logTerm)
	for i = k, k + 60 do
		sum += term
		term = term * lambda / (i + 1)
		if term < sum * 1e-15 then
			break
		end
	end
	return math.min(sum, 1)
end

function AuditMath.envelopeStage(hours)
	local curve = C.envelope.curve
	if hours <= curve[1][1] then
		return curve[1][2]
	end
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if hours <= b[1] then
			return a[2] + (b[2] - a[2]) * (hours - a[1]) / (b[1] - a[1])
		end
	end
	local a, b = curve[#curve - 1], curve[#curve]
	return b[2] + (b[2] - a[2]) / (b[1] - a[1]) * (hours - b[1])
end

-- 봉투 역함수(이 스테이지에 합법적으로 닿는 최소 시간) - v44 이관(옛 계정 = 합법으로 간주한 플레이 시간).
function AuditMath.hoursForStage(stage)
	local curve = C.envelope.curve
	for i = 2, #curve do
		local a, b = curve[i - 1], curve[i]
		if stage <= b[2] then
			return a[1] + (b[1] - a[1]) * math.max(stage - a[2], 0) / math.max(b[2] - a[2], 1)
		end
	end
	local a, b = curve[#curve - 1], curve[#curve]
	return b[1] + (stage - b[2]) * (b[1] - a[1]) / (b[2] - a[2])
end

-- 태초 리더보드 값: 개수 × 1e10 + (9999999999 − 달성 unix) - 개수가 같으면 먼저 달성한 쪽이 크다(동점 = 먼저 달성).
function AuditMath.boardValue(count, reachedAt)
	return count * 1e10 + (9999999999 - math.clamp(math.floor(reachedAt or 0), 0, 9999999999))
end

return AuditMath
