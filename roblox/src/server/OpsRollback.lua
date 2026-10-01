-- QUEUE-ALL6 F4 되돌리기(/ops rollback - 그 사람만): 저장 버전 고르기(버전 문자열 또는 UTC 시각) → 미리보기(지금 vs 그때 요약) → 확인 번호 → 실행.
--   실행 순서: 지금 저장본을 백업 저장소에 복사(실패 = 중단 · 아무것도 안 바뀜) → 고른 버전을 읽어 savedAt = 지금 · sessionId = ""로 덮기
--   (다른 서버에 남은 옛 세션의 다음 저장은 "더 최신 저장이 있다"로 거절된다 - SaveSystem 낙관적 동시성) → 쓰기 실패 = 원래 그대로(백업만 남음).
--   저장소 접근은 deps로 받는다(하네스가 가짜 저장소로 시험 - roblox/tools/harness/ops_security_test.luau).
local OpsRollback = {}

-- 순수: versions = { { version, createdTime(ms) } … }(최신 먼저) · target = 버전 문자열 또는 unix 초(숫자) → 고른 항목 | nil
function OpsRollback.pick(versions, target)
	if type(target) == "number" then
		for _, v in ipairs(versions) do
			if v.createdTime / 1000 <= target and not v.isDeleted then
				return v
			end
		end
		return nil
	end
	for _, v in ipairs(versions) do
		if v.version == target then
			return v
		end
	end
	return nil
end

-- 순수: "2026-10-01T12:30"(UTC) · unix 숫자 문자열 → unix | nil(그 밖 = 버전 문자열로 본다)
function OpsRollback.parseTime(text)
	if type(text) ~= "string" then
		return nil
	end
	local n = tonumber(text)
	if n and n > 1e9 then
		return math.floor(n)
	end
	local y, mo, d, h, mi = text:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)$")
	if y then
		return DateTime.fromUniversalTime(tonumber(y), tonumber(mo), tonumber(d), tonumber(h), tonumber(mi), 0).UnixTimestamp
	end
	return nil
end

-- 순수: 프로필 요약(미리보기 · inspect)
function OpsRollback.summary(data)
	if type(data) ~= "table" then
		return nil
	end
	local best, rebirth = 0, 0
	for _, cs in pairs(type(data.classes) == "table" and data.classes or {}) do
		local sp = type(cs) == "table" and cs.stageProgress
		best = math.max(best, sp and tonumber(sp.infiniteBest) or 0)
		rebirth = math.max(rebirth, type(cs) == "table" and tonumber(cs.rebirthCount) or 0)
	end
	local prim, trans, items = 0, 0, 0
	local function count(item)
		if type(item) == "table" then
			items += 1
			prim += item.grade == "primordial" and 1 or 0
			trans += item.grade == "transcendent" and 1 or 0
		end
	end
	for _, item in ipairs(type(data.inventory) == "table" and data.inventory or {}) do
		count(item)
	end
	for _, cs in pairs(type(data.classes) == "table" and data.classes or {}) do
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			count(type(cs) == "table" and cs.equipment and cs.equipment[part])
		end
	end
	return { gold = tonumber(data.gold) or 0, best = best, rebirth = rebirth, items = items, primordial = prim, transcendent = trans, savedAt = tonumber(data.savedAt) or 0, version = data.version }
end

function OpsRollback.describe(s)
	if not s then
		return "없음"
	end
	return ("골드 %d · 최고 스테이지 %d · 환생 %d · 장비 %d(태초 %d · 초월 %d) · 저장 %s"):format(s.gold, s.best, s.rebirth, s.items, s.primordial, s.transcendent,
		s.savedAt > 0 and os.date("!%m-%d %H:%M", s.savedAt) or "-")
end

-- 실행. deps = { readCurrent(userId) → data|nil, err · readVersion(userId, version) → data|nil, err · writeBackup(key, data) → ok · writeProfile(userId, data) → ok, err · now }
-- 순수: 되돌린 저장(old)에 지금 저장(current)의 "돈 · 한 번만" 기록을 얹는다(QUEUE-ALL6 I 리뷰: 통째로 덮으면 그 사이 로벅스 구매 ·
--   치장 · 시즌 유료 줄이 사라지고 - 영수증은 이미 지급됨이라 로블록스가 다시 안 준다 - 코드 · 선물을 두 번 받을 수 있었다).
--   유지 = purchases(영수증 · 산 소모품) · gamepasses · 산 치장(합집합) · 같은 시즌 유료 줄 · 받은 선물 id · 받은 코드. 나머지(골드 · 장비 · 진행)는 그 버전.
function OpsRollback.keepPaid(old, current)
	if type(old) ~= "table" or type(current) ~= "table" then
		return old
	end
	local function tbl(v)
		return type(v) == "table" and v or nil
	end
	if tbl(current.purchases) then
		old.purchases = table.clone(current.purchases)
	end
	if tbl(current.gamepasses) then
		old.gamepasses = table.clone(current.gamepasses)
	end
	local cc, oc = tbl(current.cosmetics), tbl(old.cosmetics)
	if cc then
		oc = oc and table.clone(oc) or {}
		for _, bag in ipairs({ "themes", "gliderSkins", "items" }) do
			local merged = table.clone(tbl(oc[bag]) or {})
			for id, owned in pairs(tbl(cc[bag]) or {}) do
				if owned then
					merged[id] = owned
				end
			end
			oc[bag] = merged
		end
		old.cosmetics = oc
	end
	local cs, os_ = tbl(current.seasonPass), tbl(old.seasonPass)
	if cs then
		if os_ and os_.season == cs.season then
			os_ = table.clone(os_)
			os_.premium = os_.premium == true or cs.premium == true
			old.seasonPass = os_
		elseif not os_ or (tonumber(cs.season) or 0) > (tonumber(os_.season) or 0) then
			old.seasonPass = table.clone(cs) -- 그 사이 시즌이 바뀌었으면 지금 시즌 기록 그대로
		end
	end
	local cm = tbl(current.mailbox)
	if cm and tbl(cm.claimedIds) then
		local om = table.clone(tbl(old.mailbox) or { gifts = {}, seq = 0 })
		local seen, ids = {}, {}
		for _, id in ipairs(cm.claimedIds) do
			if not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
		for _, id in ipairs(tbl(om.claimedIds) or {}) do
			if not seen[id] then
				seen[id] = true
				table.insert(ids, id)
			end
		end
		om.claimedIds = ids
		om.seq = math.max(tonumber(om.seq) or 0, tonumber(cm.seq) or 0)
		local gifts = {}
		for _, gift in ipairs(tbl(om.gifts) or {}) do
			if not (type(gift) == "table" and seen[gift.id]) then -- 그 버전 선물함에 남아 있었지만 그 뒤 받은 것 = 빼기(두 번 받기 방지)
				table.insert(gifts, gift)
			end
		end
		om.gifts = gifts
		old.mailbox = om
	end
	if tbl(current.redeemedCodes) then
		local merged = table.clone(tbl(old.redeemedCodes) or {})
		for code, at in pairs(current.redeemedCodes) do
			merged[code] = merged[code] or at
		end
		old.redeemedCodes = merged
	end
	return old
end

--   반환 ok, 이유 코드("rolled_back" · "backup_failed" · "no_version_data" · "write_failed")
function OpsRollback.execute(deps, userId, version)
	local current, errCur = deps.readCurrent(userId)
	if errCur then
		return false, "read_failed"
	end
	local backupKey = ("u%d_%d"):format(userId, deps.now)
	if not deps.writeBackup(backupKey, { at = deps.now, version = version, data = current }) then
		return false, "backup_failed"
	end
	local old = deps.readVersion(userId, version)
	if type(old) ~= "table" then
		return false, "no_version_data"
	end
	old = OpsRollback.keepPaid(table.clone(old), current)
	old.savedAt = deps.now -- 다른 서버의 옛 세션 저장이 이 값을 보고 포기한다
	old.sessionId = ""
	local ok = deps.writeProfile(userId, old)
	if not ok then
		return false, "write_failed"
	end
	return true, "rolled_back", backupKey
end

-- 순수: 차단 인자 → BanAsync 설정 | nil, 이유
function OpsRollback.banConfig(userId, durationKey, reason)
	local seconds = require(game:GetService("ReplicatedStorage").Shared.data.SecurityOpsConfig).ban.durations[tostring(durationKey)]
	if not userId or userId <= 0 or not seconds then
		return nil, "bad_args"
	end
	reason = require(script.Parent.AuditTrail).clip(reason, require(game:GetService("ReplicatedStorage").Shared.data.SecurityOpsConfig).ban.maxReasonChars) -- QUEUE-ALL6R: 글자 수로 자른다(옛 바이트 자르기 = 한글 사유가 끊겨 UTF-8이 깨졌다 - 감사 기록과 같은 버그)
	if reason == "" then
		return nil, "need_reason"
	end
	return { UserIds = { userId }, Duration = seconds, DisplayReason = reason, PrivateReason = "ops: " .. reason, ExcludeAltAccounts = false, ApplyToUniverse = true }
end

-- QUEUE-ALL6R 결정 8 순수(입구 주입 - 하네스 OPS가 가짜 저장 · 시계로 부른다): 저장을 다른 서버가 쥐고 있으면 내보내기를 한 번 부탁하고 놓을 때까지 기다린다.
-- io = { read(userId) → raw, held(raw) → bool, publish(userId), wait(초) } · 반환: true(이제 덮어도 된다) | false, "still_held"
function OpsRollback.awaitRelease(userId, io)
	local cfg = require(game:GetService("ReplicatedStorage").Shared.data.SecurityOpsConfig).rollback
	if not io.held(io.read(userId)) then
		return true
	end
	io.publish(userId)
	local waited = 0
	while waited < cfg.releaseWaitSeconds do
		io.wait(cfg.releasePollSeconds)
		waited += cfg.releasePollSeconds
		if not io.held(io.read(userId)) then
			return true
		end
	end
	return false, "still_held"
end

return OpsRollback
