-- 알파 통계(T1 계측) - 서버 메모리 카운터. 규칙을 바꾸지 않고 세기만 한다. 읽기 = AlphaStats.snapshot() · DevTools `/gg stats`.
-- C1 마무리(결정 6 계측): 탱커 끌어오기 = 쫓기기만 하던 몹(잡는 사람 없음)의 기준 스테이지가 첫 타격 한 번에 stealStageGap 넘게 오른 사건.
--   pullCount = 횟수 · pullSeconds = 끌기 시간 합(쫓기기 시작 → 첫 타격) · pullAvoidedHits = 끌기 동안 약하게 맞은 공격 수 추정(끌기 시간 ÷ 몹 공격 주기) ·
--   pullMaxJump = 가장 큰 기준 상승폭. 이득 환산 = C1 시뮬 j 잔여(끌기 1초 +13% · 2초 +33% - docs/phase/C1-final-report.md).

local AlphaStats = {}

local counters = {
	pullCount = 0,
	pullSeconds = 0,
	pullAvoidedHits = 0,
	pullMaxJump = 0,
}

function AlphaStats.notePull(seconds, jump, attackCooldownSeconds)
	counters.pullCount += 1
	counters.pullSeconds += seconds
	counters.pullAvoidedHits += seconds / math.max(attackCooldownSeconds, 0.1)
	counters.pullMaxJump = math.max(counters.pullMaxJump, jump)
end

function AlphaStats.snapshot()
	local copy = table.clone(counters)
	copy.pullAvgSeconds = counters.pullCount > 0 and counters.pullSeconds / counters.pullCount or 0
	return copy
end

function AlphaStats.reset()
	for key in pairs(counters) do
		counters[key] = 0
	end
end

return AlphaStats
