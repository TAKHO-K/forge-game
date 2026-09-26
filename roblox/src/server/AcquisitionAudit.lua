-- S1 획득 보안(태초) · 속도 봉투 · 확률 검사 · 처치 속도(자동 제재 없음 - 격리 · 보류 · 검토 대기 · 로그). 수치 = shared/data/AuditConfig.
--   2-3 발급 원장: 태초가 굴려진 순간 굴림 id(GUID) · 출처 · 그 굴림의 태초 확률 · 스테이지 · 시각 · JobId · 세계 번호를 원장 저장소에 쓴다(PrimordialRegistry.claim).
--       아이템 각인(item.primordial)에 rollId를 둔다. 원장 없는 태초(각인에 rollId 없음 · 원장 키 없음) = 격리(quarantined - 명예의 전당 · 리더보드 · 번호 집계 · 칭호 제외 · 아이템은 그대로).
--   2-4 집계: 드랍 출처(AuditConfig.countableSources)만 · 동점 = 먼저 달성(리더보드 값 인코딩) · 회수 번호 = 결번(번호 카운터는 되돌리지 않는다 · 제외 목록).
--   2-5 속도 봉투: 계정 최고 스테이지 > 봉투(플레이 시간) × margin = 리더보드 등재 보류(Leaderboard.eligibility) + 검토 대기.
--   2-6 확률 검사: λ = 굴린 태초 확률 합 · P(X ≥ 보유 수 | λ) < 문턱 = 검토 대기.
--   2-7 처치 · 보스 클리어 속도: 창 안 개수 상한 초과 = 로그 + 검토 대기.
--   저장: profile.audit = { lambda, primordialRolls, playSeconds }(v44).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AuditConfig = require(ReplicatedStorage.Shared.data.AuditConfig)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local AuditMath = require(ReplicatedStorage.Shared.AuditMath)

local AcquisitionAudit = {}
local C = AuditConfig
local isStudio = RunService:IsStudio()

local function keyOf(k)
	return (isStudio and C.testKeyPrefix or "") .. k
end
local stores = {}
local function store(name)
	if not stores[name] then
		local ok, s = pcall(function()
			return DataStoreService:GetDataStore(name)
		end)
		stores[name] = ok and s or false
	end
	return stores[name] or nil
end

AcquisitionAudit.log = {} -- 서버 메모리 검토 기록(최근 100 - 검증 · 운영 확인)
AcquisitionAudit.debugNoStore = false -- 검증(가)가 저장소 없이 순수 경로만 볼 때

-- ─────────────────────────── 검토 대기(flag) ───────────────────────────
function AcquisitionAudit.flag(player, kind, detail)
	local entry = { userId = typeof(player) == "Instance" and player.UserId or 0, name = typeof(player) == "Instance" and player.Name or "?", kind = kind, detail = detail, at = os.time(), jobId = game.JobId }
	table.insert(AcquisitionAudit.log, entry)
	while #AcquisitionAudit.log > 100 do
		table.remove(AcquisitionAudit.log, 1)
	end
	warn(("[forge-game] 검토 대기(%s): %s - %s"):format(kind, entry.name, tostring(detail)))
	if AcquisitionAudit.debugNoStore or entry.userId <= 0 then
		return entry
	end
	task.spawn(function()
		local s = store(C.reviewStore)
		if s then
			pcall(function()
				s:UpdateAsync(keyOf("u" .. entry.userId), function(list)
					list = type(list) == "table" and list or {}
					table.insert(list, 1, entry)
					while #list > C.reviewKeep do
						table.remove(list)
					end
					return list
				end)
			end)
		end
	end)
	return entry
end

-- ─────────────────────────── 2-3 원장 ───────────────────────────
function AcquisitionAudit.newRollId()
	return HttpService:GenerateGUID(false)
end

-- 원장 한 건 쓰기(재시도 3). 반환: 성공.
function AcquisitionAudit.writeLedger(entry)
	if AcquisitionAudit.debugNoStore then
		AcquisitionAudit.memoryLedger = AcquisitionAudit.memoryLedger or {}
		AcquisitionAudit.memoryLedger[entry.rollId] = entry
		return true
	end
	local s = store(C.ledgerStore)
	if not s then
		return false
	end
	for _ = 1, 3 do
		local ok = pcall(function()
			s:UpdateAsync(keyOf("roll_" .. entry.rollId), function()
				return entry
			end)
		end)
		if ok then
			return true
		end
		task.wait(0.5)
	end
	return false
end

function AcquisitionAudit.readLedger(rollId)
	if AcquisitionAudit.debugNoStore then
		return AcquisitionAudit.memoryLedger and AcquisitionAudit.memoryLedger[rollId], true
	end
	local s = store(C.ledgerStore)
	if not s then
		return nil, false
	end
	local ok, value = pcall(function()
		return s:GetAsync(keyOf("roll_" .. rollId))
	end)
	return ok and value or nil, ok
end

-- 드랍 굴림마다(CombatResolution): λ += 그 굴림의 태초 확률 × 굴린 개수.
function AcquisitionAudit.addLambda(player, p, count)
	local profile = PlayerProfile.getProfile(player)
	if not profile or type(p) ~= "number" or p <= 0 or (count or 0) <= 0 then
		return
	end
	profile.audit = profile.audit or { lambda = 0, primordialRolls = 0, playSeconds = 0 }
	profile.audit.lambda = (profile.audit.lambda or 0) + p * count
	profile.audit.primordialRolls = (profile.audit.primordialRolls or 0) + count
end

-- ─────────────────────────── 2-4 집계 ───────────────────────────
-- 집계 대상 태초인가: 드랍 출처 · 원장 id · 격리 · 회수 · 옛 태초가 아님.
function AcquisitionAudit.isCountable(item)
	local stamp = type(item) == "table" and item.grade == "primordial" and item.primordial
	if type(stamp) ~= "table" or stamp.legacy or stamp.quarantined or stamp.revoked or not (stamp.rollId or stamp.preLedger) then
		return false
	end
	local kind = type(item.source) == "table" and item.source.kind
	return C.countableSources[kind] == true
end

-- 계정의 모든 태초 장비(가방 + 직업마다 착용).
function AcquisitionAudit.primordialItems(profile)
	local list = {}
	if type(profile) ~= "table" then
		return list
	end
	for _, item in ipairs(profile.inventory or {}) do
		if type(item) == "table" and item.grade == "primordial" then
			table.insert(list, item)
		end
	end
	for _, cs in pairs(profile.classes or {}) do
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			local item = cs.equipment and cs.equipment[part]
			if type(item) == "table" and item.grade == "primordial" then
				table.insert(list, item)
			end
		end
	end
	return list
end

function AcquisitionAudit.countableCount(profile)
	local n, firstAt = 0, nil
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		if AcquisitionAudit.isCountable(item) then
			n += 1
			local at = item.primordial.at or 0
			firstAt = firstAt and math.max(firstAt, at) or at -- 이 개수에 "도달한" 시각 = 가장 늦게 받은 것
		end
	end
	return n, firstAt
end

-- 제외 번호(회수 · 격리) - 명예의 전당 · 번호 집계에서 뺀다. 캐시 + 저장소.
local excluded = nil
function AcquisitionAudit.excludedNumbers()
	if excluded then
		return excluded
	end
	excluded = {}
	if not AcquisitionAudit.debugNoStore then
		local s = store(C.excludedStore)
		if s then
			local ok, value = pcall(function()
				return s:GetAsync(keyOf("numbers"))
			end)
			if ok and type(value) == "table" then
				excluded = value
			end
		end
	end
	return excluded
end
-- 운영 해제 · 오판 복구: 제외 목록에서 뺀다(리뷰 2).
function AcquisitionAudit.includeNumber(no)
	if not no then
		return
	end
	AcquisitionAudit.excludedNumbers()[tostring(no)] = nil
	if AcquisitionAudit.debugNoStore then
		return
	end
	local s = store(C.excludedStore)
	if s then
		pcall(function()
			s:UpdateAsync(keyOf("numbers"), function(value)
				value = type(value) == "table" and value or {}
				value[tostring(no)] = nil
				return value
			end)
		end)
	end
end

function AcquisitionAudit.isNumberExcluded(no)
	return no ~= nil and AcquisitionAudit.excludedNumbers()[tostring(no)] ~= nil
end
function AcquisitionAudit.excludeNumber(no, reason)
	if not no then
		return
	end
	AcquisitionAudit.excludedNumbers()[tostring(no)] = reason or "?"
	if AcquisitionAudit.debugNoStore then
		return
	end
	local s = store(C.excludedStore)
	if s then
		pcall(function()
			s:UpdateAsync(keyOf("numbers"), function(value)
				value = type(value) == "table" and value or {}
				value[tostring(no)] = reason or "?"
				return value
			end)
		end)
	end
end

-- 칭호 "태초의 선택" 유지 조건 = 집계 대상 태초 중 칭호 부위(TitleData acquire)가 하나라도(운영 회수도 같은 함수 - 리뷰 9).
function AcquisitionAudit.titleStillEarned(profile)
	local acquire = TitleData.titles[PrimordialData.titleId].acquire
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		if AcquisitionAudit.isCountable(item) and table.find(acquire.parts, item.part) then
			return true
		end
	end
	return false
end

-- 격리(원장 없음): 아이템 그대로 · 각인에 표시 · 번호 제외 · 칭호 조건 다시 본다.
function AcquisitionAudit.quarantine(player, item, why)
	local stamp = item.primordial
	if type(stamp) ~= "table" or stamp.quarantined then
		return false
	end
	stamp.quarantined = why or "no_ledger"
	AcquisitionAudit.excludeNumber(stamp.no, "quarantine")
	AcquisitionAudit.flag(player, "quarantine", ("태초 %s(번호 %s · %s)"):format(tostring(item.part), tostring(stamp.no), stamp.quarantined))
	return true
end

-- 로드 뒤(SaveServer): 태초마다 원장 확인 → 없으면 격리 · 칭호 다시 · 확률 · 속도 봉투 검사. 반환(검증): { checked, quarantined }.
function AcquisitionAudit.auditProfile(player)
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return nil
	end
	local result = { checked = 0, quarantined = 0 }
	for _, item in ipairs(AcquisitionAudit.primordialItems(profile)) do
		local stamp = item.primordial
		-- 리뷰 1 · 2: preLedger(v44 이관 - 원장 이전에 정상 발급) · 운영 해제(releasedByOps)는 다시 보지 않는다
		if type(stamp) == "table" and not stamp.legacy and not stamp.quarantined and not stamp.revoked and not stamp.preLedger and not stamp.releasedByOps then
			result.checked += 1
			if not stamp.rollId then
				if AcquisitionAudit.quarantine(player, item, "no_roll_id") then
					result.quarantined += 1
				end
			else
				local entry, ok = AcquisitionAudit.readLedger(stamp.rollId)
				if ok and type(entry) ~= "table" and (stamp.ledger == "failed" or stamp.ledger == nil) and stamp.p ~= nil then
					-- 리뷰 2: 이 서버가 발급했는데 원장 쓰기가 실패했거나 아직 안 끝났다(각인에 굴림 확률이 남아 있다) - 격리 대신 다시 쓴다
					local rewrote = AcquisitionAudit.writeLedger({ rollId = stamp.rollId, userId = player.UserId, source = item.source, p = stamp.p, stage = item.source and item.source.stage,
						at = stamp.at, jobId = game.JobId, no = stamp.no, part = item.part, rewritten = true })
					stamp.ledger = rewrote and "ok" or "failed"
					result.rewritten = (result.rewritten or 0) + (rewrote and 1 or 0)
				elseif ok and (type(entry) ~= "table" or entry.userId ~= player.UserId) then
					if AcquisitionAudit.quarantine(player, item, "no_ledger") then
						result.quarantined += 1
					end
				end
			end
		end
	end
	if result.quarantined > 0 then
		if PlayerProfile.hasTitle(player, PrimordialData.titleId) and not AcquisitionAudit.titleStillEarned(profile) then
			PlayerProfile.revokeTitle(player, PrimordialData.titleId)
		end
		PlayerProfile.pushInventory(player)
	end
	AcquisitionAudit.checkProbability(player)
	return result
end

-- ─────────────────────────── 2-6 확률 검사 ───────────────────────────
function AcquisitionAudit.checkProbability(player)
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return nil
	end
	local k = AcquisitionAudit.countableCount(profile)
	local lambda = profile.audit and profile.audit.lambda or 0
	local tail = AuditMath.poissonTail(k, lambda)
	if k > 0 and tail < C.poissonThreshold then
		AcquisitionAudit.flag(player, "luck", ("태초 %d개 · λ %.3g · P(X ≥ %d) = %.3g < %.0e"):format(k, lambda, k, tail, C.poissonThreshold))
		return false, tail
	end
	return true, tail
end

-- ─────────────────────────── 2-5 속도 봉투 ───────────────────────────
-- 리더보드 보류인가(계정 최고 스테이지 > 봉투 × margin). 반환: hold, detail
function AcquisitionAudit.velocityHold(player)
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return false
	end
	local hours = (profile.audit and profile.audit.playSeconds or 0) / 3600
	local best = PlayerProfile.getAccountBestStage(player)
	local allowed = AuditMath.envelopeStage(hours) * C.envelope.margin
	if best > allowed then
		local detail = ("최고 %d > 봉투 %.0f(플레이 %.1f시간 × %.1f)"):format(best, allowed, hours, C.envelope.margin)
		local st = AcquisitionAudit.stateOf(player)
		if (st.velocityFlaggedAt or -math.huge) < os.clock() - 600 then
			st.velocityFlaggedAt = os.clock()
			AcquisitionAudit.flag(player, "velocity", detail)
		end
		return true, detail
	end
	return false
end

-- ─────────────────────────── 2-7 처치 속도 · 플레이 시간 ───────────────────────────
local states = {}
function AcquisitionAudit.stateOf(player)
	local st = states[player]
	if not st then
		st = { kills = {}, bossClears = {}, rateFlaggedAt = -math.huge }
		states[player] = st
	end
	return st
end

local function noteIn(list, now, window)
	table.insert(list, now)
	while list[1] and now - list[1] > window do
		table.remove(list, 1)
	end
	return #list
end

function AcquisitionAudit.noteKill(player, now)
	local st = AcquisitionAudit.stateOf(player)
	now = now or os.clock()
	local n = noteIn(st.kills, now, C.killRate.windowSeconds)
	if n > C.killRate.maxKills and now - st.rateFlaggedAt > 600 then
		st.rateFlaggedAt = now
		AcquisitionAudit.flag(player, "kill_rate", ("%d초에 처치 %d > %d"):format(C.killRate.windowSeconds, n, C.killRate.maxKills))
		return false
	end
	return true
end

function AcquisitionAudit.noteBossClear(player, now)
	local st = AcquisitionAudit.stateOf(player)
	now = now or os.clock()
	local n = noteIn(st.bossClears, now, C.killRate.bossWindowSeconds)
	if n > C.killRate.maxBossClears and now - st.rateFlaggedAt > 600 then
		st.rateFlaggedAt = now
		AcquisitionAudit.flag(player, "boss_rate", ("%d초에 보스 클리어 %d > %d"):format(C.killRate.bossWindowSeconds, n, C.killRate.maxBossClears))
		return false
	end
	return true
end

function AcquisitionAudit.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < C.playTickSeconds then
			return
		end
		local add = acc
		acc = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = PlayerProfile.getProfile(player)
			if profile then
				profile.audit = profile.audit or { lambda = 0, primordialRolls = 0, playSeconds = 0 }
				profile.audit.playSeconds = (profile.audit.playSeconds or 0) + add
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return AcquisitionAudit
