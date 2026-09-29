-- QUEUE-6h-b 후속 안전장치 ① 약한 세션 잠금 · ② 손상 저장 음수 골드 → 0 하네스(실제 SaveSystem + 가짜 DataStore).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem ECON_RES=res_lock.txt python build_run.py save_lock_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[LOCK] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

-- 가짜 DataStore(키 → 값) · 읽기 훅(n번째 GetAsync에 값을 바꿔 "옛 서버의 퇴장 저장이 도착"을 흉내)
local DATA, reads, onRead = {}, 0, nil
local fakeStore = {
	GetAsync = function(_, key) reads += 1; if onRead then onRead(reads, key) end; return DATA[key] end,
	RemoveAsync = function(_, key) DATA[key] = nil end,
	UpdateAsync = function(_, key, fn) local v = fn(DATA[key]); if v ~= nil then DATA[key] = v end; return v end,
}
local baseGetService = game.GetService
game.GetService = function(self, name)
	if name == "DataStoreService" then return { GetDataStore = function() return fakeStore end } end
	if name == "HttpService" then return { GenerateGUID = function() return "SERVER-ME" end } end
	return baseGetService(self, name)
end

local ok, err = pcall(function()
	local SaveSystem = MODS.SaveSystem
	local SaveConfig = MODS.SaveConfig
	local player = { Name = "Lock", UserId = 42, Parent = true }
	local KEY = "Player_42"
	local now = os.time()
	local function stored(fields)
		local d = SaveSystem.migrate({})
		for k, v in pairs(fields) do d[k] = v end
		return d
	end

	-- 1. 판정(순수)
	local H = SaveSystem.heldElsewhere
	check("판정: 다른 서버 · 신선 = 잠김", H({ sessionId = "OTHER", savedAt = now - 5 }, now) == true)
	check("판정: 놓음(\"\") = 안 잠김", H({ sessionId = "", savedAt = now - 5 }, now) == false)
	check("판정: 이 서버 = 안 잠김", H({ sessionId = "SERVER-ME", savedAt = now - 5 }, now) == false)
	check("판정: 오래됨(신선 기준 넘음) = 안 잠김", H({ sessionId = "OTHER", savedAt = now - SaveConfig.sessionLockFreshSeconds - 1 }, now) == false)
	check("판정: 옛 계정(sessionId 없음) = 안 잠김", H({ savedAt = now - 5 }, now) == false)

	-- 2. 이관: 새 계정 · 옛 계정 v54 → v55 sessionId ""
	local m = SaveSystem.migrate({})
	local old54 = SaveSystem.migrate({}); old54.version = 54; old54.sessionId = nil
	local m54 = SaveSystem.migrate(old54)
	check("이관: 새 계정 · v54 → 현재 버전 · sessionId \"\"", m.version == SaveConfig.saveVersion and m.sessionId == "" and m54.sessionId == "" and SaveSystem.isValidProfile(m54), ("v%d"):format(m.version))

	-- 3. 옮겨 접속: 옛 서버가 쥔 채(신선) → 3번째 읽기에 옛 서버 퇴장 저장 도착(놓음 · 골드 999) → 기다렸다 새 값으로 로드
	DATA[KEY] = stored({ sessionId = "OTHER", savedAt = now - 3, gold = 100 })
	reads = 0
	local arrived = false
	onRead = function(n, key) if n >= 3 and key == KEY and not arrived then arrived = true; DATA[KEY] = stored({ sessionId = "", savedAt = now, gold = 999 }) end end
	local p1, e1, info1 = SaveSystem.loadProfile(player)
	check("옮겨 접속: 기다린 뒤 퇴장 저장 값으로 로드", p1 and p1.gold == 999 and info1.lockWaitedSeconds and info1.lockWaitedSeconds <= SaveConfig.sessionLockMaxWaitSeconds and info1.lockReleased == true,
		("골드 %s · 대기 %s초 · 풀림 %s · 에러 %s"):format(tostring(p1 and p1.gold), tostring(info1 and info1.lockWaitedSeconds), tostring(info1 and info1.lockReleased), tostring(e1)))

	-- 4. 안 풀림(다른 서버가 계속 쥠) → 상한까지만 기다리고 진행(막지 않는다)
	DATA[KEY] = stored({ sessionId = "OTHER", savedAt = now - 3, gold = 100 })
	onRead = nil
	local p2, _, info2 = SaveSystem.loadProfile(player)
	check("안 풀림: 상한까지 기다리고 진행", p2 and p2.gold == 100 and info2.lockWaitedSeconds == SaveConfig.sessionLockMaxWaitSeconds and info2.lockReleased == false,
		("대기 %s초"):format(tostring(info2 and info2.lockWaitedSeconds)))

	-- 5. 잠금 없음(놓음) → 기다리지 않음
	DATA[KEY] = stored({ sessionId = "", savedAt = now - 3, gold = 50 })
	local p3, _, info3 = SaveSystem.loadProfile(player)
	check("놓인 저장: 기다리지 않음", p3 and p3.gold == 50 and info3.lockWaitedSeconds == nil)

	-- 6. 저장이 쓰는 표식: 평소 = 이 서버 · 마지막 저장(markReleasing) = ""
	local okSave = SaveSystem.saveProfile(player, p3)
	local held = DATA["Player_42_manual"] and DATA["Player_42_manual"].sessionId
	SaveSystem.markReleasing(player, true)
	local okSave2 = SaveSystem.saveProfile(player, p3)
	SaveSystem.markReleasing(player, false)
	local released = DATA["Player_42_manual"] and DATA["Player_42_manual"].sessionId
	check("저장 표식: 평소 = 이 서버 · 퇴장 저장 = 놓음", okSave and okSave2 and held == "SERVER-ME" and released == "", ("%s → %s"):format(tostring(held), tostring(released)))

	-- 7. 손상 저장 음수 골드 → 0 + 알림 정보
	DATA[KEY] = stored({ sessionId = "", savedAt = now - 3, gold = -500 })
	DATA["Player_42_manual"] = nil
	local p4, _, info4 = SaveSystem.loadProfile(player)
	check("음수 골드 → 0 · 이벤트 값", p4 and p4.gold == 0 and info4.negativeGold == -500, ("골드 %s · 저장값 %s"):format(tostring(p4 and p4.gold), tostring(info4 and info4.negativeGold)))
	DATA[KEY] = stored({ sessionId = "", savedAt = now - 3, gold = 10 })
	local p5, _, info5 = SaveSystem.loadProfile(player)
	check("정상 골드는 그대로", p5 and info5.negativeGold == nil)
end)
if not ok then print("[LOCK] 에러 " .. tostring(err)) end
print(("[LOCK] 끝 %d/%d"):format(pass, total))
