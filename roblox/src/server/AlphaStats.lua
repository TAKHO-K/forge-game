-- 알파 통계(T1 계측) - 서버 메모리 카운터. 규칙을 바꾸지 않고 세기만 한다. 읽기 = AlphaStats.snapshot() · DevTools `/gg stats` · 라이브 운영 `/ops stats [all]`(S1 후속 0-5).
-- 서버 종료(BindToClose) 때 요약 한 줄을 DataStore(AuditConfig.alphaStatsStore - 키 "summaries" 최근 alphaStatsKeep개)에 남긴다 - 서버 메모리가 사라져도 알파 수치가 남는다.
-- C1 마무리(결정 6 계측): 탱커 끌어오기 = 쫓기기만 하던 몹(잡는 사람 없음)의 기준 스테이지가 첫 타격 한 번에 stealStageGap 넘게 오른 사건.
--   pullCount = 횟수 · pullSeconds = 끌기 시간 합(쫓기기 시작 → 첫 타격) · pullAvoidedHits = 끌기 동안 약하게 맞은 공격 수 추정(끌기 시간 ÷ 몹 공격 주기) ·
--   pullMaxJump = 가장 큰 기준 상승폭. 이득 환산 = C1 시뮬 j 잔여(끌기 1초 +13% · 2초 +33% - docs/phase/C1-final-report.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local AuditConfig = require(ReplicatedStorage.Shared.data.AuditConfig)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)

local AlphaStats = {}
local startedAt = os.time()

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

function AlphaStats.describe(snap)
	return ("끌어오기 %d회 · 합 %.1f초 · 평균 %.2f초 · 약하게 맞은 공격 추정 %.1f · 최대 기준 상승 %d"):format(snap.pullCount, snap.pullSeconds, snap.pullAvgSeconds, snap.pullAvoidedHits, snap.pullMaxJump)
end

-- 저장소 · 키(Studio = 시험 키 접두사 · 검증 모드 = "_verify" 저장소 - COMMON §3 새 저장소 규칙)
local function store()
	return DataStoreService:GetDataStore(AuditConfig.alphaStatsStore .. (DevToolsConfig.verifyArmed and "_verify" or ""))
end
local KEY = (RunService:IsStudio() and AuditConfig.testKeyPrefix or "") .. "summaries"

-- 서버 종료 요약 한 줄 저장(BindToClose). 반환: ok
function AlphaStats.saveSummary()
	if counters.pullCount == 0 then -- 리뷰 6: 빈 서버 요약은 남기지 않는다(한 키에 동시 종료가 몰릴 때 쓰기 수를 줄이고 100칸을 밀어내지 않게)
		return true, nil
	end
	local entry = { at = os.time(), jobId = game.JobId, uptime = os.time() - startedAt, counters = table.clone(counters) }
	local ok = pcall(function()
		store():UpdateAsync(KEY, function(list)
			list = type(list) == "table" and list or {}
			table.insert(list, 1, entry)
			while #list > AuditConfig.alphaStatsKeep do
				table.remove(list)
			end
			return list
		end)
	end)
	return ok, entry
end

-- 저장된 요약 합(운영 /ops stats all). 반환: snap(카운터 합 · pullMaxJump = 최대) · 서버 수 · 가동 시간 합(초) - 실패 = nil
function AlphaStats.loadTotals()
	local ok, list = pcall(function()
		return store():GetAsync(KEY)
	end)
	if not ok then
		return nil
	end
	local total = { pullCount = 0, pullSeconds = 0, pullAvoidedHits = 0, pullMaxJump = 0 }
	local uptime = 0
	for _, e in ipairs(type(list) == "table" and list or {}) do
		local c = type(e.counters) == "table" and e.counters or {}
		total.pullCount += tonumber(c.pullCount) or 0
		total.pullSeconds += tonumber(c.pullSeconds) or 0
		total.pullAvoidedHits += tonumber(c.pullAvoidedHits) or 0
		total.pullMaxJump = math.max(total.pullMaxJump, tonumber(c.pullMaxJump) or 0)
		uptime += tonumber(e.uptime) or 0
	end
	total.pullAvgSeconds = total.pullCount > 0 and total.pullSeconds / total.pullCount or 0
	return total, type(list) == "table" and #list or 0, uptime
end

function AlphaStats.start()
	if AlphaStats.started then
		return
	end
	AlphaStats.started = true
	game:BindToClose(function()
		AlphaStats.saveSummary()
	end)
end

function AlphaStats.reset()
	for key in pairs(counters) do
		counters[key] = 0
	end
end

return AlphaStats
