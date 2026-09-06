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

function ImmediateSave.request(player)
	local now = os.clock()
	local last = lastSaveAt[player]
	if not last or now - last >= IMMEDIATE_SAVE_THROTTLE_SECONDS then
		lastSaveAt[player] = now
		SaveCoordinator.saveForPlayer(player)
		return
	end

	if pendingSaveScheduled[player] then
		return -- 이미 이번 창 끝에 저장이 예약돼 있다 - 최신 상태는 그 저장이 알아서 반영한다
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
	SaveCoordinator.saveForPlayer(player)
end

return ImmediateSave
