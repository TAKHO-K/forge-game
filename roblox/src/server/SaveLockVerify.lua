-- QUEUE-6h-b 후속 자동 검증 6hbF(나) - 안전장치 ① 약한 세션 잠금 · ② 손상 저장 음수 골드 → 0 · 새 계정 첫 로드 · 저장 왕복을 실제 DataStore(검증용 키)로 확인.
--   새 계정 = 저장이 한 번도 없는 가짜 userId 스탠드인(검증 모드 저장 키 Player_<id>_verify - 끝에 지운다) · 저장 왕복은 실제 개발 계정(검증 키)도 한 번.
--   잠금 대기는 실제로 기다린다(안 풀림 10초 + 풀림 약 4초) - 체인 안에서 약 20초.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData)
local SaveSystem = require(script.Parent.SaveSystem)
local SaveCoordinator = require(script.Parent.SaveCoordinator)
local PlayerProfile = require(script.Parent.PlayerProfile)

local SaveLockVerify = {}

local STANDIN_USER_ID = 7700001 -- 이 게임에 저장이 없는 userId(새 계정 흉내)

function SaveLockVerify.runLive(player, env)
	print("===6hbF 검증 시작(나: 새 계정 첫 로드 · 저장 왕복 · 약한 세션 잠금 · 음수 골드)===")
	local pass, total = 0, 0
	local function check(name, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[6hbF][나] %s %s"):format(name, ok and "O" or "X"))
	end
	local store = DataStoreService:GetDataStore(SaveConfig.dataStoreName)
	local standin = { UserId = STANDIN_USER_ID, Name = "NewAcct6hbF", Parent = true }
	-- MENU2 B1: 캐릭터 칸 저장 = 잠금 · 표식은 계정 키(Acct_) · 골드는 캐릭터 키(Char_) - 끔 = 옛 키(Player_)
	local slot = SlotSaveData.enabled
	local key = slot and (SaveSystem.accountKeyBase(STANDIN_USER_ID) .. "_verify") or ("Player_" .. STANDIN_USER_ID .. "_verify")
	local function raw()
		return store:GetAsync(key)
	end

	-- A. 새 계정 첫 로드: 저장 없음 → 기본값 · 현재 버전 · 잠금 대기 없음
	local p, err, info = SaveSystem.loadProfile(standin)
	check(("A 새 계정 첫 로드: v%s · 골드 %s · sessionId \"%s\" · 견습 완료 %s · 대기 %s · 에러 %s (기대 v%d · 0 · \"\" · false · 없음)"):format(
		tostring(p and p.version), tostring(p and p.gold), tostring(p and p.sessionId), tostring(p and p.tutorial.completed), tostring(info and info.lockWaitedSeconds), tostring(err), SaveConfig.saveVersion),
		p ~= nil and p.version == SaveConfig.saveVersion and p.gold == 0 and p.sessionId == "" and p.tutorial.completed == false and info.lockWaitedSeconds == nil and SaveSystem.isValidProfile(p))

	-- B. 저장 왕복: 저장 = 이 서버 표식 · 다시 읽기 = 같은 값 · 대기 없음(칸 저장 = 직업을 골라 캐릭터 1을 만든다 - 골드는 캐릭터 키)
	if slot then
		p.classId = "greatsword"
	end
	p.gold = 4321
	local okSave = SaveSystem.saveProfile(standin, p)
	local r1 = raw()
	local p2, _, info2 = SaveSystem.loadProfile(standin)
	check(("B 저장 왕복: 저장 %s · 저장된 sessionId = 이 서버 %s · 다시 읽은 골드 %s · 대기 %s"):format(tostring(okSave), tostring(r1 and r1.sessionId == SaveSystem.serverSessionId),
		tostring(p2 and p2.gold), tostring(info2 and info2.lockWaitedSeconds)),
		okSave == true and r1 and r1.sessionId == SaveSystem.serverSessionId and p2 and p2.gold == 4321 and info2.lockWaitedSeconds == nil)

	-- C. 퇴장 저장 = 잠금 놓음("")
	SaveSystem.markReleasing(standin, true)
	local okRelease = SaveSystem.saveProfile(standin, p2)
	SaveSystem.markReleasing(standin, false)
	local r2 = raw()
	check(("C 퇴장 저장 = 놓음: 저장 %s · sessionId \"%s\""):format(tostring(okRelease), tostring(r2 and r2.sessionId)), okRelease == true and r2 and r2.sessionId == "")

	-- D. 다른 서버가 쥔 채 안 풀림 → 상한(10초)까지만 기다리고 진행
	local held = table.clone(r2)
	held.sessionId, held.savedAt, held.gold = "OTHER-SERVER", os.time(), 555
	store:SetAsync(key, held)
	local function mark(prof) -- 다른 서버 값을 읽었는가: 옛 키 = 골드 555/777 · 칸 = 계정 savedAt(골드는 계정 키에 없다)
		if slot then
			return prof and prof.savedAt
		end
		return prof and prof.gold
	end
	local t0 = os.clock()
	local p3, _, info3 = SaveSystem.loadProfile(standin)
	local waitedD = os.clock() - t0
	check(("D 안 풀림: 대기 %s초(실제 %.1f초) · 풀림 %s · 표식 %s (기대 %d초 · false · %s - 막지 않고 진행)"):format(tostring(info3 and info3.lockWaitedSeconds), waitedD,
		tostring(info3 and info3.lockReleased), tostring(mark(p3)), SaveConfig.sessionLockMaxWaitSeconds, tostring(slot and held.savedAt or 555)),
		p3 and mark(p3) == (slot and held.savedAt or 555) and info3.lockWaitedSeconds == SaveConfig.sessionLockMaxWaitSeconds and info3.lockReleased == false and waitedD >= SaveConfig.sessionLockMaxWaitSeconds - 0.5)

	-- E. 옛 서버의 퇴장 저장이 3초 뒤 도착 → 기다렸다 새 값으로
	held.savedAt = os.time()
	store:SetAsync(key, held)
	local releasedMark = nil
	task.delay(3, function()
		local released = table.clone(held)
		released.sessionId, released.savedAt, released.gold = "", os.time(), 777
		releasedMark = slot and released.savedAt or 777
		store:SetAsync(key, released)
	end)
	t0 = os.clock()
	local p4, _, info4 = SaveSystem.loadProfile(standin)
	local waitedE = os.clock() - t0
	check(("E 3초 뒤 풀림: 대기 %s초(실제 %.1f초) · 풀림 %s · 표식 %s (기대 풀림 true · %s · 10초 안)"):format(tostring(info4 and info4.lockWaitedSeconds), waitedE,
		tostring(info4 and info4.lockReleased), tostring(mark(p4)), tostring(releasedMark)),
		p4 and mark(p4) == releasedMark and info4.lockReleased == true and info4.lockWaitedSeconds < SaveConfig.sessionLockMaxWaitSeconds)

	-- F. 손상 저장 음수 골드 → 0
	local bad = table.clone(held)
	bad.sessionId, bad.savedAt, bad.gold = "", os.time() - 3600, -500
	store:SetAsync(key, bad)
	local charKey = nil
	if slot then -- 칸: 골드는 캐릭터 키 - 캐릭터 1 키에 음수 골드
		local s1 = type(bad.slots) == "table" and bad.slots[1]
		charKey = s1 and (SaveSystem.characterKeyBase(STANDIN_USER_ID, s1.charId) .. "_verify")
		local ch = charKey and store:GetAsync(charKey)
		if type(ch) == "table" and type(ch.data) == "table" then
			ch.data.gold = -500
			store:SetAsync(charKey, ch)
		end
	end
	local p5, _, info5 = SaveSystem.loadProfile(standin)
	check(("F 음수 골드: 로드 골드 %s · 이벤트 값 %s (기대 0 · -500)"):format(tostring(p5 and p5.gold), tostring(info5 and info5.negativeGold)),
		p5 and p5.gold == 0 and info5.negativeGold == -500)

	-- G. 실제 개발 계정 저장 왕복(검증 키): 저장 → 이 서버 표식 · 다시 읽기 골드 같음 · 대기 없음
	if env and env.restore then
		env.restore(player) -- 앞 블록이 남긴 백업(저장 차단)을 풀어야 실제 저장 경로가 돈다
	end
	local profile = PlayerProfile.getProfile(player)
	local goldBefore = profile and profile.gold
	SaveCoordinator.saveForPlayer(player)
	local realRaw = store:GetAsync((slot and SaveSystem.accountKeyBase(player.UserId) or ("Player_" .. player.UserId)) .. "_verify")
	local p6, _, info6 = SaveSystem.loadProfile(player)
	check(("G 개발 계정 왕복: 저장 표식 = 이 서버 %s · 다시 읽은 골드 %s = 메모리 %s · v%s · 대기 %s"):format(tostring(realRaw and realRaw.sessionId == SaveSystem.serverSessionId),
		tostring(p6 and p6.gold), tostring(goldBefore), tostring(p6 and p6.version), tostring(info6 and info6.lockWaitedSeconds)),
		realRaw and realRaw.sessionId == SaveSystem.serverSessionId and p6 and p6.gold == goldBefore and p6.version == SaveConfig.saveVersion and info6.lockWaitedSeconds == nil)

	store:RemoveAsync(key) -- 검증이 만든 스탠드인 _verify 키만(실제 키 아님)
	if charKey then
		store:RemoveAsync(charKey)
	end
	if slot then
		SaveSystem.forgetSlotSession(standin)
	end
	check(("정리: 스탠드인 저장 키 지움 %s"):format(tostring(store:GetAsync(key) == nil)), store:GetAsync(key) == nil)
	print(("===6hbF 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return SaveLockVerify
