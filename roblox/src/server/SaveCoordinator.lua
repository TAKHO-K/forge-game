-- 저장 시도 하나의 공통 처리(성공 로그·실패 재시도 결과 안내·세션 중단 플래그). 10-1에서는
-- 주기 자동저장(SaveServer.server.lua)만 이 경로를 썼지만, 10-2부터 강화 등 즉시저장
-- 트리거(EnhanceServer.server.lua)도 같은 경로를 쓴다 - 실패·중단 처리를 호출부마다 따로
-- 만들면 한쪽만 고치고 잊어버리기 쉽다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SaveSystem = require(script.Parent.SaveSystem)
local PlayerProfile = require(script.Parent.PlayerProfile)

local saveNotice = Instance.new("RemoteEvent")
saveNotice.Name = "SaveNotice"
saveNotice.Parent = ReplicatedStorage

local SaveCoordinator = {}

-- 불러오기에 실패했거나(future_version/invalid_schema/재시도 소진) 저장이 다른 서버에
-- 밀린(stale_session) 플레이어는 이후 저장을 더 시도하지 않는다 - 잘못된(빈) 상태나 낡은
-- 상태를 실제 저장 위에 덮어쓸 위험을 원천 차단한다. 안내는 발생 시점에 한 번이면 된다.
-- 약한 키 테이블 - 플레이어가 나가면 Player 인스턴스를 계속 붙들고 있을 이유가 없다
-- (AttackInput.client.lua의 activeStacks와 같은 이유, 퇴장 때 수동으로 지울 필요가 없다).
local saveSuspended = setmetatable({}, { __mode = "k" })

-- 19-3a: 밸런스 테스트 도구(DevTools.server.lua) 전용 저장 차단. saveSuspended와 일부러
-- 분리한다 - 그쪽은 "저장이 실패해 안내가 필요한" 에러 상태고, 이건 "지금 프로필이 가짜
-- 테스트값이라 정상 상태다"라는 다른 이유다. 여기 걸리면 클라이언트 알림(SaveNotice)도
-- warn 로그도 없다 - 개발자가 의도적으로 켠 상태이지 사고가 아니다. 주기 자동저장
-- (SaveServer.server.lua)과 퇴장 즉시저장(ImmediateSave.flush) 둘 다 saveForPlayer
-- 하나만 거치므로, 여기 한 곳만 막으면 두 경로 모두 안전하다.
local devToolsSuspended = setmetatable({}, { __mode = "k" })

-- 24-2 크로스서버 파티(PRD 20.63) 전용 저장 동결. PartyCrossServer가 텔레포트 직전에 ImmediateSave.flush로
-- 마지막 저장을 끝낸 뒤 이 플래그를 켠다 - 그 뒤 출발 서버에서 일어나는 퇴장 저장(PlayerRemoving → flush)·
-- 주기 자동저장은 전부 건너뛴다. 이유: 텔레포트로 나간 플레이어는 도착 서버에서 곧바로 프로필을 읽는데,
-- 출발 서버의 퇴장 저장이 그보다 늦게 끝나면 도착 서버가 옛 값을 읽고(손실) 도착 서버의 다음 저장은
-- savedAt 비교에서 stale_session으로 밀린다(저장 중단). "마지막 쓰기 = 텔레포트 호출 전에 끝난 flush"로
-- 고정하면 이 경합이 구조적으로 사라진다. 텔레포트가 실패하면 PartyCrossServer가 다시 끈다.
local teleportFrozen = setmetatable({}, { __mode = "k" })

-- 24-2: 플레이어당 저장 하나만 동시에 나간다. 주기 자동저장이 UpdateAsync를 기다리는 사이(yield) 다른 경로
-- (텔레포트 직전 flush·강화 즉시저장)가 같은 baseline(savedAt)으로 두 번째 UpdateAsync를 시작하면, 먼저 끝난
-- 쪽이 savedAt을 올려 두 번째가 stale_session으로 오판된다 - 그 순간부터 그 플레이어의 저장이 전부 중단된다
-- (24-2 크로스서버 검증 중 실제 발생: 자동저장 60초 틱과 flush가 같은 초에 겹쳤다). 두 번째 요청은 앞선 저장이
-- 끝날 때까지 기다린 뒤 갱신된 baseline으로 저장한다 - ImmediateSave.flush가 "예약된" trailing 저장을 취소하는
-- 것과 별개로, "이미 나간" 저장과의 겹침은 여기서 막는다.
local saving = setmetatable({}, { __mode = "k" })

-- SEC-FIX-1 1: 캐릭터 칸 전환 중 저장 잠금(SlotSwitch가 전환 flush 뒤 켜고 새 프로필 · 세션이 자리 잡으면 끈다). 옛 = 새 칸을 읽는(yield) 사이 자동저장이
-- 옛 프로필 · 옛 세션으로 계정 키를 써서 새 세션의 기준 시각이 낡았다 → 그 뒤 계정 키 저장이 전부 stale_session(캐릭터 키만 써져 "받음" 표시가 빠짐 = 재접속 후 다시 받기).
local switchLocked = setmetatable({}, { __mode = "k" })
function SaveCoordinator.setSwitchLocked(player, on)
	switchLocked[player] = on and true or nil
end

-- SEC-FIX-1 2(AUDIT1 #15): 같은 서버 재접속 - 퇴장 저장(옛 Player 인스턴스)이 아직 진행 중이면 새 로드가 그 저장보다 먼저 읽어(같은 서버 표식이라 세션 잠금 대기도 없음)
--   옛 값으로 시작하고, 늦게 끝난 퇴장 저장이 savedAt을 올려 새 세션 저장이 그 접속 내내 stale_session으로 멈췄다.
--   퇴장 저장을 UserId로 세고(saving은 Player 키라 새 인스턴스와 이어지지 않음) 로드가 그것이 끝날 때까지 기다린다(상한 SaveConfig.leaveSaveWaitMaxSeconds).
local leavingByUserId = {}
function SaveCoordinator.beginLeave(userId)
	leavingByUserId[userId] = (leavingByUserId[userId] or 0) + 1
end
function SaveCoordinator.endLeave(userId)
	local n = (leavingByUserId[userId] or 1) - 1
	leavingByUserId[userId] = n > 0 and n or nil
end
-- 반환: 기다린 초(0 = 진행 중인 퇴장 저장 없음) · 상한 안에 끝났나
function SaveCoordinator.waitForLeaveSave(userId)
	local waited = 0
	while leavingByUserId[userId] and waited < SaveConfig.leaveSaveWaitMaxSeconds do
		waited += task.wait(0.1)
	end
	return waited, leavingByUserId[userId] == nil
end

-- QUEUE-ALL4 C 출시 감사: 진행 중인 saveForPlayer 수(종료 대기용) · 에러 실패 누계(관측) · 실패 안내 마지막 시각(사람별 간격).
local activeSaves = 0
local saveFailures = 0
local lastFailureNoticeAt = setmetatable({}, { __mode = "k" })
function SaveCoordinator.activeSaves()
	return activeSaves
end
function SaveCoordinator.failureCount()
	return saveFailures
end
function SaveCoordinator.isSuspended(player)
	return saveSuspended[player] == true
end

local function notify(player, message)
	saveSuspended[player] = true
	saveNotice:FireClient(player, message)
	warn(("[forge-game] 저장 중단: %s - %s"):format(player.Name, message))
end

function SaveCoordinator.notify(player, message)
	notify(player, message)
end

-- DevTools.server.lua만 호출한다. suspended=true인 동안 saveForPlayer는 조용히
-- 아무것도 하지 않는다 - 테스트 조건이 DataStore에 반영되는 일을 원천 차단한다.
-- QUEUE-ALL10: DevTools 백업 세션(/gg 뒤 - 그 세션 저장을 일부러 멈춤)인가 - 즉시 저장을 확인하는 흐름(초월 계승)이 Studio에서 이 경우를 저장 실패로 오인하지 않게
function SaveCoordinator.isDevToolsSuspended(player)
	return devToolsSuspended[player] == true
end

function SaveCoordinator.setDevToolsSuspended(player, suspended)
	if suspended then
		devToolsSuspended[player] = true
	else
		devToolsSuspended[player] = nil
	end
end

function SaveCoordinator.setTeleportFrozen(player, frozen)
	if frozen then
		teleportFrozen[player] = true
	else
		teleportFrozen[player] = nil
	end
end

-- 반환: 이번 호출이 실제로 저장에 성공했나(건너뜀 · 실패 = false)
function SaveCoordinator.saveForPlayer(player)
	if devToolsSuspended[player] then
		return false
	end
	if teleportFrozen[player] then
		return false
	end
	if saveSuspended[player] then
		return false
	end
	if switchLocked[player] then
		return false
	end

	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return false
	end

	activeSaves += 1 -- QUEUE-ALL4 C: 종료(BindToClose)가 진행 중인 저장을 기다린다(앞 저장 대기 포함)
	while saving[player] do
		task.wait()
	end
	if PlayerProfile.getProfile(player) ~= profile or teleportFrozen[player] or saveSuspended[player] or switchLocked[player] then
		activeSaves -= 1
		return false -- 기다리는 동안 프로필이 지워졌거나(퇴장) 동결·중단 · 칸 전환이 시작됐다
	end
	saving[player] = true
	local okCall, ok, err = pcall(SaveSystem.saveProfile, player, profile)
	if not okCall then
		ok, err = false, tostring(ok) -- 저장 함수 자체 에러도 잠금 · 카운터를 풀고 실패로 다룬다(옛 = saving이 안 풀려 그 사람 저장이 영영 멈춤)
	end
	saving[player] = nil
	activeSaves -= 1
	if ok then
		-- 19-1: 무기는 이제 활성 직업(profile.classId)에 딸려 있다 - 아직 직업을 안 골랐으면
		-- (classId=nil) weapon 자체가 없으니 로그에서도 그 상태를 그대로 보여준다.
		local weapon = PlayerProfile.getWeapon(player)
		print(("[forge-game] 저장 성공: %s - gold=%d, classId=%s, weaponLevel=%s"):format(
			player.Name, profile.gold, tostring(profile.classId), weapon and tostring(weapon.level) or "없음"))
	else
		if err == "stale_session" then
			notify(player, "다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다. 다시 접속해 주세요.")
		else
			-- QUEUE-ALL4 C: 에러(DataStore 장애 · 한도 초과 · 크기 초과)는 저장을 멈추지 않는다 - 다음 주기 · 퇴장 때 다시 시도한다(옛 = 한 번 실패하면
			-- 그 세션 저장이 전부 멈춰 퇴장 저장까지 빠졌다 - 일시 장애가 그 접속의 진행 전체 손실이 됐다). 다시 써도 안전하다: 다른 서버의 더 새 저장은
			-- saveProfile의 savedAt 비교가 여전히 막는다(stale_session = 위 분기 · 중단 유지). 안내는 saveFailureNoticeGapSeconds에 한 번.
			saveFailures += 1
			warn(("[forge-game] 저장 실패(다음에 다시 시도): %s - %s"):format(player.Name, tostring(err)))
			local now = os.clock()
			if not lastFailureNoticeAt[player] or now - lastFailureNoticeAt[player] >= SaveConfig.saveFailureNoticeGapSeconds then
				lastFailureNoticeAt[player] = now
				saveNotice:FireClient(player, "저장에 반복 실패했습니다. 지금까지의 변경사항이 저장되지 않았을 수 있습니다.")
			end
		end
	end
	return ok == true -- QUEUE-B1 B2: 구매 처리(ProcessReceipt)가 저장 성공을 확인한 뒤에만 PurchaseGranted를 돌려준다
end

return SaveCoordinator
