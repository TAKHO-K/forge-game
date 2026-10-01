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
	old = table.clone(old)
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
	reason = tostring(reason or ""):sub(1, require(game:GetService("ReplicatedStorage").Shared.data.SecurityOpsConfig).ban.maxReasonChars)
	if reason == "" then
		return nil, "need_reason"
	end
	return { UserIds = { userId }, Duration = seconds, DisplayReason = reason, PrivateReason = "ops: " .. reason, ExcludeAltAccounts = false, ApplyToUniverse = true }
end

return OpsRollback
