-- QUEUE-ALL6 F 하네스: 되돌리기(버전 고르기 · 백업 · 실패 시 원상태) · 차단 인자 · 탐지 판정 · 감사 기록 병합.
--   실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=OpsRollback,SuspicionMonitor,AuditTrail ECON_RES=res_ops.txt python build_run.py ops_security_test.luau
-- 대역: DateTime.fromUniversalTime(로블록스 전역 - 하네스 prelude에 없음) = 그레고리력 → unix(UTC)
if DateTime.fromUniversalTime == nil then -- prelude DateTime(now만)에 더한다
	DateTime.fromUniversalTime = function(y, m, d, h, mi, sec)
		local a = m <= 2 and 1 or 0
		local yy, mm = y - a, m + 12 * a - 3
		local days = d + (153 * mm + 2) // 5 + 365 * yy + yy // 4 - yy // 100 + yy // 400 - 719469
		return { UnixTimestamp = days * 86400 + h * 3600 + mi * 60 + (sec or 0) }
	end
end
local R = MODS.OpsRollback
local SM = MODS.SuspicionMonitor
local AT = MODS.AuditTrail
local C = MODS.SecurityOpsConfig
local pass, total = 0, 0
local function check(label, ok)
	total += 1
	pass += ok and 1 or 0
	print(("[OPS] %s %s"):format(label, ok and "O" or "X"))
end

-- 1. 버전 고르기
local versions = {
	{ version = "v5", createdTime = 5000 * 1000 }, { version = "v4", createdTime = 4000 * 1000 }, { version = "v3", createdTime = 3000 * 1000, isDeleted = true }, { version = "v2", createdTime = 2000 * 1000 },
}
check("버전 문자열로 고르기 = v4", (R.pick(versions, "v4") or {}).version == "v4")
check("시각 4500 = 그 시각 이전 최신 v4", (R.pick(versions, 4500) or {}).version == "v4")
check("시각 3500 = 지운 v3 건너뛰고 v2", (R.pick(versions, 3500) or {}).version == "v2")
check("시각 1000(가장 옛것보다 이전) = 없음", R.pick(versions, 1000) == nil)
check("없는 버전 문자열 = 없음", R.pick(versions, "v9") == nil)
check("시각 글자 2026-10-01T12:30 = unix", R.parseTime("2026-10-01T12:30") == 1790857800 and R.parseTime("1790857800") == 1790857800 and R.parseTime("abc") == nil)

-- 2. 실행(가짜 저장소)
local function world()
	local w = { profile = { gold = 999999, savedAt = 900, sessionId = "other", classes = {} }, versions = { v2 = { gold = 100, savedAt = 200, sessionId = "old", classes = {} } }, backups = {}, failBackup = false, failWrite = false }
	w.deps = {
		readCurrent = function() return table.clone(w.profile), nil end,
		readVersion = function(_, v) return w.versions[v] end,
		writeBackup = function(key, value) if w.failBackup then return false end w.backups[key] = value return true end,
		writeProfile = function(_, data) if w.failWrite then return false, "boom" end w.profile = data return true end,
		now = 1000,
	}
	return w
end
local w = world()
local ok, why, key = R.execute(w.deps, 42, "v2")
check(("정상: %s(%s) · 골드 999999 → %d · 백업 %s"):format(tostring(ok), tostring(why), w.profile.gold, tostring(key)), ok and why == "rolled_back" and w.profile.gold == 100 and w.backups[key] and w.backups[key].data.gold == 999999)
check("덮은 저장: savedAt = 지금(1000 - 다른 서버 옛 세션 저장이 거절됨) · sessionId 빈칸", w.profile.savedAt == 1000 and w.profile.sessionId == "")
check("버전 원본은 그대로(복사본을 고침)", w.versions.v2.savedAt == 200 and w.versions.v2.sessionId == "old")
w = world()
w.failBackup = true
ok, why = R.execute(w.deps, 42, "v2")
check(("백업 실패 = 중단 · 프로필 그대로: %s(%s) · 골드 %d"):format(tostring(ok), tostring(why), w.profile.gold), not ok and why == "backup_failed" and w.profile.gold == 999999)
w = world()
ok, why = R.execute(w.deps, 42, "v7")
check(("버전 데이터 없음 = 중단 · 프로필 그대로: %s"):format(tostring(why)), not ok and why == "no_version_data" and w.profile.gold == 999999)
w = world()
w.failWrite = true
ok, why = R.execute(w.deps, 42, "v2")
check(("쓰기 실패 = 원래 그대로 · 백업은 남음: %s"):format(tostring(why)), not ok and why == "write_failed" and w.profile.gold == 999999 and next(w.backups) ~= nil)

-- 3. 요약
local s = R.summary({ gold = 5, classes = { greatsword = { stageProgress = { infiniteBest = 300 }, rebirthCount = 2, equipment = { armor = { grade = "transcendent" } } } }, inventory = { { grade = "primordial" }, { grade = "epic" } } })
check(("요약: 최고 %d · 환생 %d · 장비 %d · 태초 %d · 초월 %d"):format(s.best, s.rebirth, s.items, s.primordial, s.transcendent), s.best == 300 and s.rebirth == 2 and s.items == 3 and s.primordial == 1 and s.transcendent == 1)

-- 4. 차단 인자(Players:BanAsync 설정)
local cfg = R.banConfig(123, "7d", "속도 핵")
check("차단 7d = 604800초 · 경험 전체 · 부계정 포함", cfg and cfg.Duration == 604800 and cfg.ApplyToUniverse == true and cfg.ExcludeAltAccounts == false and cfg.UserIds[1] == 123)
check("차단 perm = -1", (R.banConfig(123, "perm", "x") or {}).Duration == -1)
local bad1, w1 = R.banConfig(123, "2y", "x")
local bad2, w2 = R.banConfig(123, "1d", "")
local bad3 = R.banConfig(0, "1d", "x")
check("잘못된 기간 · 사유 없음 · userId 0 = 거절", bad1 == nil and w1 == "bad_args" and bad2 == nil and w2 == "need_reason" and bad3 == nil)

-- 5. 탐지 판정(순수)
local D = C.detect
local quiet = SM.evaluate({ reverts = 2, gold = 1500, hits = 1200, drops = 5 })
check("정상 플레이(되돌림 2 · 골드 1,500마리 몫 · 명중 1,200 · 버림 5) = 기록 0", #quiet == 0)
local loud = SM.evaluate({ reverts = D.moveRevertsPerMin, gold = D.goldKillEqPerMin, hits = D.hitsPerMin, drops = D.gateDropsPerMin })
check(("기준 도달 = 4종 전부 기록(%d)"):format(#loud), #loud == 4)

-- 6. 감사 기록 병합(나이 · 개수 상한)
local now = 100 * 86400
local old = {}
for i = 1, C.trail.keep do
	table.insert(old, { k = "x", d = "", at = now - i })
end
table.insert(old, { k = "ancient", d = "", at = now - (C.trail.maxAgeDays + 1) * 86400 })
local merged = AT.merge(old, { { k = "new", d = "", at = now } }, now)
check(("병합: 새 줄 맨 앞 · 개수 %d(상한 %d) · 90일 지난 줄 버림"):format(#merged, C.trail.keep), merged[1].k == "new" and #merged == C.trail.keep and merged[#merged].k ~= "ancient")

print(("[OPS] 끝 %d/%d"):format(pass, total))
