-- 되돌릴 수 없는 사건(강화 결과 10-2, 클래스 선택 10-3) 공통 즉시저장 스로틀. 10-2에서는
-- EnhanceServer.server.lua 안에 있었지만, 클래스 선택도 같은 경로가 필요해지면서 여기로
-- 뽑았다 - 두 이벤트가 각자 따로 타이머를 들고 있으면 합산 저장 빈도가 예산 검산(아래)을
-- 벗어날 수 있어 플레이어당 타이머 하나를 공유한다.
--
-- leading + trailing 스로틀: 마지막 저장 후 이 시간(초)이 지났으면 즉시 저장(leading),
-- 아니면 이번 창이 끝나는 시점에 한 번만 몰아서 저장한다(trailing) - 연타로 저장 요청이
-- 몰려도 DataStore 호출이 스팸이 되지 않는다.
--
-- 예산 검산(N=100명 동시접속 가정): DataStore 쓰기 예산은 로블록스 공식 문서 기준 분당
-- 60+인원수×10 = 100명이면 분당 1060회. 6초 스로틀이면 1인당 분당 최대 10회 - 100명 전원이
-- (강화든 클래스 변경이든) 쉬지 않고 연타해도 분당 1000회로 예산 안에 들어온다. 1초로
-- 잡으면 100명이 전부 연타할 때 분당 6000회로 예산을 5배 넘긴다.

local SaveCoordinator = require(script.Parent.SaveCoordinator)

local IMMEDIATE_SAVE_THROTTLE_SECONDS = 6
local lastSaveAt = setmetatable({}, { __mode = "k" })
local pendingSaveScheduled = setmetatable({}, { __mode = "k" })
-- task.delay가 돌려주는 스레드 핸들(12-1 [0]) - flush가 이 핸들로 예약된 trailing 저장을
-- 취소할 수 있어야 한다. pendingSaveScheduled(bool)만으로는 "예약돼 있다"는 알지만
-- 취소할 방법이 없었다.
local pendingSaveThread = setmetatable({}, { __mode = "k" })

local ImmediateSave = {}

-- request 호출 누계(검증용 카운터 - CombatResolution.dropStats와 같은 결) - 두 시점의 차로 "그 사건이 즉시 저장을 요청했는가"를 읽는다. 저장 자체는
-- 스로틀되거나(DevTools 백업 중에는) 건너뛰어질 수 있어 요청 횟수가 가장 정직한 관측값이다.
local requestCount = 0

function ImmediateSave.getRequestCount()
	return requestCount
end

function ImmediateSave.request(player)
	requestCount += 1
	local now = os.clock()
	local last = lastSaveAt[player]
	if pendingSaveScheduled[player] then
		return -- 이미 이번 창 끝에 저장이 예약돼 있다(QUEUE-ALL5 D②: leading보다 먼저 본다 - 예약 시각과 같은 순간의 요청이 leading으로 한 번 더 쓰던 것)
	end
	if not last or now - last >= IMMEDIATE_SAVE_THROTTLE_SECONDS then
		lastSaveAt[player] = now
		-- QUEUE-ALL5 D②: 부른 쪽을 멈추지 않는다(옛 = 그 자리에서 UpdateAsync를 기다렸다 - 처치 처리(resolveHit)가 MonsterAI · 덫 Heartbeat 안에서
		--   멈춰 죽은 보스가 저장 대기 동안 계속 휘두르고 · 낡은 목록 · 낡은 인덱스로 이어졌다). 저장 겹침은 SaveCoordinator의 saving 잠금이 그대로 막는다.
		task.spawn(SaveCoordinator.saveForPlayer, player)
		return
	end

	pendingSaveScheduled[player] = true
	pendingSaveThread[player] = task.delay(IMMEDIATE_SAVE_THROTTLE_SECONDS - (now - last), function()
		pendingSaveScheduled[player] = nil
		pendingSaveThread[player] = nil
		lastSaveAt[player] = os.clock()
		SaveCoordinator.saveForPlayer(player)
	end)
end

-- 세션 종료 전용(PlayerRemoving/BindToClose, 12-1 [0]). "곧 저장될 예정"인 trailing
-- 저장이 남아 있으면 그 예약을 취소하고 - 안 그러면 나중에(이미 지워진 프로필을 대상으로
-- 공회전하거나, 지금 여기서 하는 저장과 겹쳐 낙관적 동시성 검사(SaveSystem.saveProfile의
-- savedAt 비교)에서 서로 경합해 더 최신 쪽이 오히려 stale로 밀릴 수 있다 - 두 UpdateAsync
-- 호출이 겹치면 안 된다 - 지금 이 자리에서 최신 상태를 즉시 한 번만 저장한다. 세션이
-- 끝나는 순간이라 스로틀(다음 요청으로부터 DataStore 예산을 지키는 목적)을 지킬 이유도
-- 없다 - 항상 지금 저장한다.
function ImmediateSave.flush(player)
	local thread = pendingSaveThread[player]
	if thread then
		task.cancel(thread)
		pendingSaveThread[player] = nil
		pendingSaveScheduled[player] = nil
	end
	lastSaveAt[player] = os.clock()
	return SaveCoordinator.saveForPlayer(player) -- QUEUE-B1 B2: 저장 성공 여부(구매 처리가 본다)
end

-- QUEUE-ALL4 C: 서버 종료(BindToClose) 전용. 남은 사람을 **동시에** flush하고(옛 = 한 명씩 - 재시도 대기가 사람 수만큼 쌓여 30초를 넘을 수 있었다),
-- 이미 진행 중인 저장(퇴장 저장 포함 - SaveCoordinator.activeSaves)과 extraBusy()가 참인 동안 deadlineSeconds까지 기다린다.
-- beforeEach(player) = 그 사람 flush 직전(세션 잠금 놓기 표시). 반환: 마감 전에 다 끝났는가, 걸린 초.
function ImmediateSave.flushAllForShutdown(players, deadlineSeconds, beforeEach, extraBusy)
	local started = os.clock()
	local pending = 0
	for _, player in ipairs(players) do
		pending += 1
		task.spawn(function()
			if beforeEach then
				beforeEach(player)
			end
			pcall(ImmediateSave.flush, player)
			pending -= 1
		end)
	end
	while (pending > 0 or SaveCoordinator.activeSaves() > 0 or (extraBusy and extraBusy())) and os.clock() - started < deadlineSeconds do
		task.wait(0.1)
	end
	local done = pending == 0 and SaveCoordinator.activeSaves() == 0 and not (extraBusy and extraBusy())
	return done, os.clock() - started
end

return ImmediateSave
