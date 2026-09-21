-- 크로스서버 파티(24-2, PRD 20.63) - "서버 경계 밖"을 담당하는 유일한 모듈. PartyState는 이 서버 안의
-- 멤버십만 알고, 이 모듈이 그 상태를 서버 밖으로 내보내고(MemoryStore 레코드), 다른 서버의 요청을
-- 받아(MessagingService) 사람을 실제로 옮긴다(TeleportService). 세 플랫폼 서비스의 역할 분담:
--
--   · MemoryStoreService 해시맵 두 개 - 진실의 출처. ForgeParty_v1[code] = 파티 레코드(리더 서버가
--     소유·하트비트로 갱신, TTL 90초 - 리더 서버가 크래시로 사라져도 90초 안에 레코드가 소멸해 대기자가
--     풀린다). ForgePartyMember_v1[userId] = "이 사람은 code 파티의 targetJobId 서버로 가는 중"(합류자의
--     출발 서버가 쓰고 도착 서버가 소비한다 - 텔레포트 데이터는 클라이언트가 볼 수 있고 위조할 수 있으므로
--     권위 있는 값은 항상 이쪽이다, 텔레포트 데이터는 힌트일 뿐).
--   · MessagingService 토픽 하나 - 알림 전용(best effort, 유실될 수 있다). 다른 서버의 사람에게 초대를
--     띄우고, 좌석 예약·해제를 리더 서버에 빨리 알린다. 유실되면 리더 서버의 하트비트가 레코드에서 좌석을
--     다시 읽어 맞춘다(reconcile) - 메시지는 지연을 줄일 뿐 정확성을 책임지지 않는다.
--   · TeleportService:TeleportAsync + TeleportOptions.ServerInstanceId(= 리더 서버 game.JobId) - 이동.
--     Studio에서는 동작하지 않는다(공식 문서: "does not work during playtesting in Roblox Studio") -
--     그래서 텔레포트 직전까지의 파이프라인과 도착 처리는 DevTools "/gg party join <code>"가 텔레포트를
--     건너뛰고(simulateArrival) 같은 코드 경로로 검증한다.
--
-- 합류 파이프라인(requestJoin) - 출발 서버(B)에서 실행:
--   1 검사(프로필·견습·이미 파티·이미 합류 중) → 2 레코드 읽기(없으면 "파티 없음") → 3 같은 서버면 즉시
--   로컬 합류 → 4 좌석 예약(UpdateAsync 원자 연산 - 두 명이 동시에 마지막 자리를 잡으면 한 명만 성공) +
--   멤버 레코드(같은 사람이 두 파티에 동시에 붙는 것을 막는다) → 5 대기(보스전 중 / 서버 정원 초과면
--   joinPollSeconds마다 다시 읽는다, 레코드가 사라지면 취소) → 6 저장 flush + 저장 동결(도착 서버 로드와
--   출발 서버 퇴장 저장의 경합을 없앤다 - 마지막 쓰기가 텔레포트 호출보다 먼저 끝난다) → 7 TeleportAsync.
--   실패(pcall 에러 또는 TeleportInitFailed)면 좌석 해제·동결 해제·알림 - 플레이어는 원래 자리에 그대로다.
-- 도착 처리(handleArrival) - 리더 서버(A)에서 실행: 프로필 로드 후 멤버 레코드를 소비 → 파티가 없으면
--   "해산" 알림(리스폰 마을에 그대로 남는다) → 보스전 중이면 보류(arrivalWaiting, 끝나면 자동 합류) →
--   붙인다. 어디로 떨어지는가: 로블록스 기본 접속 지점(리스폰 마을). 리더 옆으로 옮기지 않는다.

local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)
local BossEncounter = require(script.Parent.BossEncounter)
local ImmediateSave = require(script.Parent.ImmediateSave)
local SaveCoordinator = require(script.Parent.SaveCoordinator)

local PartyCrossServer = {}

-- S19b 사전 작업 2(확장): 검증 모드(DevToolsConfig.verifyArmed)에서는 파티 레코드 · 멤버 레코드 · 메시지 토픽을 모두 "_verify" 이름의 별도 저장소로 돌린다. Studio도 같은 유니버스의 MemoryStore ·
-- MessagingService에 붙으므로, 검증이 만든 가짜 파티(스탠드인 · 임의 코드)가 라이브 서버의 파티 레코드 · 초대 메시지와 섞이지 않게 한다. 꺼져 있으면(사용자가 그냥 누른 Play · 라이브) 이름이 그대로다.
local storeSuffix = DevToolsConfig.verifyArmed and "_verify" or ""
local messagingTopic = PartyConfig.messagingTopic .. storeSuffix
local partyMap = MemoryStoreService:GetHashMap(PartyConfig.partyMapName .. storeSuffix)
local memberMap = MemoryStoreService:GetHashMap(PartyConfig.memberMapName .. storeSuffix)

-- [Player] = { code, phase = "reserving"|"waiting"|"saving"|"teleporting", cancelled, seatReserved, standIn }
local joinState = {}
-- [Player] = { code, fromName, thread } - 다른 서버에서 온 초대(로컬 초대는 PartyState.invites).
local remoteInvites = {}
-- [Player] = party - 도착했지만 보스전 중이라 보류 중(끝나면 붙인다).
local arrivalWaiting = {}
-- [userId] = os.time() - 최근에 이 서버가 회수·해제한 좌석. 하트비트 reconcile이 옛 레코드에서 되살리지 않게.
local recentlyReleased = {}
-- 플랫폼 서비스 실패는 한 종류당 한 번만 warn한다(Studio에서 API 접근이 꺼져 있으면 매 하트비트마다 찍힌다).
local warnedOnce = {}

local REASON_TEXT = {
	party_not_found = "그 코드의 파티가 없습니다(해산됐거나 코드가 틀립니다)",
	party_full = "파티가 가득 찼습니다(최대 4인)",
	already_member = "이미 그 파티의 멤버입니다",
	already_in_party = "이미 파티에 속해 있습니다",
	already_joining = "이미 다른 파티에 합류 중입니다",
	tutorial_self = "견습 모드 중에는 파티에 들어갈 수 없습니다",
	no_profile = "아직 준비되지 않은 플레이어입니다",
	service_unavailable = "파티 서비스에 연결할 수 없습니다. 잠시 후 다시 시도하세요",
	cancelled = "합류를 취소했습니다",
	teleport_failed = "서버 이동에 실패했습니다. 지금 자리에 그대로 있습니다",
	party_gone = "파티가 해산되었습니다",
	wrong_server = "파티 서버에 도착하지 못했습니다. 다시 합류하세요",
}
PartyCrossServer.REASON_TEXT = REASON_TEXT

local function notify(player, reason)
	PartyState.notify(player, REASON_TEXT[reason] or reason)
end

local function isInstance(player)
	return typeof(player) == "Instance"
end

-- pcall 래퍼 - 실패하면 종류별 한 번만 warn하고 nil을 돌려준다. 호출부는 "nil = 서비스 실패"로 다룬다.
local function call(label, fn, ...)
	local ok, result = pcall(fn, ...)
	if not ok then
		if not warnedOnce[label] then
			warnedOnce[label] = true
			warn(("[forge-game] 크로스서버 파티 %s 실패: %s"):format(label, tostring(result)))
		end
		return nil, tostring(result)
	end
	return result, nil
end

-- ═══ 정원 ═══

-- 이 서버가 크로스서버 합류를 받아 줄 상한. 설계값 16(= 12 + 파티 1팀)과 플랫폼 하드캡(Players.MaxPlayers -
-- 대시보드 설정, 스크립트로 못 바꾼다) 중 작은 쪽. MaxPlayers를 넘는 텔레포트는 플랫폼이 GameFull로 거절한다.
function PartyCrossServer.capacity()
	return math.min(PartyConfig.serverCapacity, Players.MaxPlayers)
end

-- ═══ 레코드 ═══

local function buildRecord(party)
	local members, pending = {}, {}
	for _, record in ipairs(PartyState.getMemberRecords(party)) do
		if record.awayUntil then
			-- S19b: 연결 끊김 유예 중인 멤버는 "지금 이 서버에 없는 사람의 예약 좌석"과 같다 - 다른 서버의 재접속 합류(reserveSeat)가 already_member로 막히지 않고, 자리는 유예가 끝날 때까지 잡혀 있다.
			table.insert(pending, { userId = record.userId, name = record.name, since = os.time(), awayUntil = record.awayUntil })
		else
			table.insert(members, { userId = record.userId, name = record.name })
		end
	end
	for _, seat in ipairs(PartyState.getPendingSeats(party)) do
		table.insert(pending, { userId = seat.userId, name = seat.name, since = seat.since })
	end
	return {
		code = party.code,
		leaderUserId = party.leader.userId,
		leaderName = party.leader.name,
		jobId = game.JobId,
		placeId = game.PlaceId,
		members = members,
		pending = pending,
		bossActive = party.bossActive or false,
		playerCount = #Players:GetPlayers(),
		capacity = PartyCrossServer.capacity(),
		updatedAt = os.time(),
	}
end

local function seatExpired(seat)
	if type(seat.awayUntil) == "number" then
		return os.time() >= seat.awayUntil -- S19b: 연결 끊김 유예 좌석 · 재접속 표식은 유예 끝까지(seatTimeoutSeconds가 아니라)
	end
	return type(seat.since) ~= "number" or os.time() - seat.since >= PartyConfig.seatTimeoutSeconds
end

-- 리더 서버가 레코드를 다시 쓴다. 다른 서버가 UpdateAsync로 끼워 넣은 좌석(pending) 중 이 서버가 아직
-- 모르는 것은 로컬 파티에 반영한다 - MessagingService "seat" 메시지가 유실됐을 때의 안전망(reconcile).
local function writeRecordNow(party)
	local newSeats = {}
	call("레코드 갱신", function()
		return partyMap:UpdateAsync(party.code, function(old)
			local record = buildRecord(party)
			if type(old) == "table" and old.jobId == game.JobId and type(old.pending) == "table" then
				for _, seat in ipairs(old.pending) do
					if not PartyState.hasPendingSeat(party, seat.userId) and not PartyState.isMemberUserId(party, seat.userId)
						and not seatExpired(seat) and not recentlyReleased[seat.userId] then
						table.insert(record.pending, seat)
						newSeats[seat.userId] = seat
					end
				end
			end
			return record
		end, PartyConfig.recordTtlSeconds)
	end)
	for _, seat in pairs(newSeats) do
		PartyState.addPendingSeat(party, seat.userId, seat.name, seat.since)
	end
end

-- 파티당 쓰기 하나만 동시에 나간다(직렬화 + 합치기). 이탈이 연달아 세 번 일어나면 UpdateAsync가 같은 키에 동시에
-- 셋 나가 MemoryStore가 InternalError를 냈다(24-2 xtest 실측) - 변경 표시(dirty)만 세우고 쓰기 코루틴 하나가
-- 마지막 상태를 한 번에 쓴다. 해산되면 남은 쓰기는 버린다(removeRecord가 뒤따른다).
local writers = {} -- [party] = { running, dirty }
local function publishRecord(party)
	local writer = writers[party]
	if not writer then
		writer = { running = false, dirty = false }
		writers[party] = writer
	end
	writer.dirty = true
	if writer.running then
		return
	end
	writer.running = true
	task.spawn(function()
		while writer.dirty do
			writer.dirty = false
			if not party.code or not PartyState.getAllParties()[party.id] then
				break
			end
			writeRecordNow(party)
		end
		writer.running = false
	end)
end

-- 진행 중인 쓰기가 끝난 뒤 지운다 - 지운 키 위에 늦은 UpdateAsync가 얹히면 빈 파티 레코드가 되살아난다.
local function removeRecord(code, party)
	if not code then
		return
	end
	task.spawn(function()
		local writer = party and writers[party]
		if writer then
			writer.dirty = false
			while writer.running do
				task.wait()
			end
			writers[party] = nil
		end
		call("레코드 삭제", function()
			return partyMap:RemoveAsync(code)
		end)
	end)
end

local function randomCode()
	local alphabet = PartyConfig.codeAlphabet
	local chars = {}
	for _ = 1, PartyConfig.codeLength do
		local i = math.random(1, #alphabet)
		table.insert(chars, alphabet:sub(i, i))
	end
	return table.concat(chars)
end

-- 코드 발급 - "비어 있을 때만 쓴다"를 UpdateAsync로 원자적으로 보장한다(충돌 시 재시도).
local allocating = {} -- [party] = true
function PartyCrossServer.ensureCode(party)
	if party.code or allocating[party] then
		return party.code
	end
	allocating[party] = true
	for _ = 1, 5 do
		local code = randomCode()
		local taken = false
		local result = call("코드 발급", function()
			return partyMap:UpdateAsync(code, function(old)
				if old ~= nil then
					taken = true
					return nil
				end
				local record = buildRecord(party)
				record.code = code
				return record
			end, PartyConfig.recordTtlSeconds)
		end)
		if result ~= nil and not taken then
			if PartyState.getAllParties()[party.id] then
				PartyState.setCode(party, code)
				print(("[forge-game] 파티 코드 발급: #%d = %s"):format(party.id, code))
			else
				removeRecord(code, party) -- 발급 도중 파티가 해산됐다
			end
			break
		end
		if result == nil and not taken then
			break -- 서비스 실패 - 코드 없이 로컬 파티로만 동작한다(warn은 call이 한 번 찍었다)
		end
	end
	allocating[party] = nil
	return party.code
end

-- ═══ 메시징 ═══

local function publish(message)
	message.fromJobId = game.JobId
	call("메시지 발행", function()
		return MessagingService:PublishAsync(messagingTopic, message)
	end)
end

local function clearRemoteInvite(player)
	local invite = remoteInvites[player]
	if invite then
		if invite.thread then
			task.cancel(invite.thread)
		end
		remoteInvites[player] = nil
	end
end

local partyInviteNotice = ReplicatedStorage:WaitForChild("PartyInviteNotice")

local function onMessage(message)
	local data = message.Data
	if type(data) ~= "table" or data.fromJobId == game.JobId then
		return -- 내 서버가 보낸 메시지는 로컬 경로가 이미 처리했다
	end
	if data.type == "invite" then
		local target = Players:GetPlayerByUserId(data.toUserId)
		if not target or PartyState.getParty(target) or PartyState.hasPendingInvite(target) or joinState[target] then
			return
		end
		clearRemoteInvite(target)
		local invite = { code = data.code, fromName = data.fromName }
		remoteInvites[target] = invite
		invite.thread = task.delay(PartyConfig.inviteTimeoutSeconds, function()
			if remoteInvites[target] == invite then
				remoteInvites[target] = nil
			end
		end)
		partyInviteNotice:FireClient(target, { inviterName = data.fromName, seconds = PartyConfig.inviteTimeoutSeconds, remote = true })
		print(("[forge-game] 크로스서버 초대 수신: %s -> %s (코드 %s)"):format(data.fromName, target.Name, data.code))
	elseif data.type == "seat" or data.type == "cancel_seat" then
		local party = PartyState.getPartyByCode(data.code)
		if not party then
			return
		end
		if data.type == "seat" then
			PartyState.addPendingSeat(party, data.userId, data.name, data.since)
		else
			recentlyReleased[data.userId] = os.time()
			PartyState.removePendingSeat(party, data.userId)
		end
	end
end

-- ═══ 좌석 예약/해제(출발 서버) ═══

-- 반환: "ok" | "party_not_found" | "party_full" | "already_member" | "service_unavailable"
local function reserveSeat(code, player)
	local outcome = "party_not_found"
	local result = call("좌석 예약", function()
		return partyMap:UpdateAsync(code, function(old)
			if type(old) ~= "table" then
				outcome = "party_not_found"
				return nil
			end
			old.pending = old.pending or {}
			for _, member in ipairs(old.members or {}) do
				if member.userId == player.UserId then
					outcome = "already_member"
					return nil
				end
			end
			local live = 0
			for i = #old.pending, 1, -1 do
				local seat = old.pending[i]
				if seat.userId == player.UserId or seatExpired(seat) then
					table.remove(old.pending, i) -- 내 옛 좌석·만료 좌석은 지우고 다시 잡는다
				else
					live += 1
				end
			end
			if #(old.members or {}) + live >= PartyConfig.maxMembers then
				outcome = "party_full"
				return nil
			end
			table.insert(old.pending, { userId = player.UserId, name = player.Name, since = os.time() })
			old.updatedAt = os.time()
			outcome = "ok"
			return old
		end, PartyConfig.recordTtlSeconds)
	end)
	if result == nil and outcome == "ok" then
		return "service_unavailable"
	end
	return outcome
end

local function releaseSeat(code, userId)
	recentlyReleased[userId] = os.time()
	call("좌석 해제", function()
		return partyMap:UpdateAsync(code, function(old)
			if type(old) ~= "table" or type(old.pending) ~= "table" then
				return nil
			end
			for i = #old.pending, 1, -1 do
				if old.pending[i].userId == userId then
					table.remove(old.pending, i)
				end
			end
			return old
		end, PartyConfig.recordTtlSeconds)
	end)
	call("멤버 레코드 삭제", function()
		return memberMap:RemoveAsync(tostring(userId))
	end)
	publish({ type = "cancel_seat", code = code, userId = userId })
end

-- 멤버 레코드 - 같은 사람이 두 파티에 동시에 붙는 것을 서버 경계 밖에서도 막는다.
local function writeMemberRecord(player, code, targetJobId)
	local outcome = "ok"
	local result = call("멤버 레코드 쓰기", function()
		return memberMap:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) == "table" and old.code ~= code and not seatExpired(old) then
				outcome = "already_joining"
				return nil
			end
			return { code = code, targetJobId = targetJobId, since = os.time() }
		end, PartyConfig.seatTimeoutSeconds)
	end)
	if result == nil and outcome == "ok" then
		return "service_unavailable"
	end
	return outcome
end

local function readRecord(code)
	local result, err = call("레코드 읽기", function()
		return partyMap:GetAsync(code)
	end)
	if err then
		return nil, "service_unavailable"
	end
	if type(result) ~= "table" then
		return nil, "party_not_found"
	end
	return result
end

-- ═══ 합류(출발 서버) ═══

local function finishJoin(player, reason)
	local state = joinState[player]
	joinState[player] = nil
	if state and state.seatReserved and reason ~= "teleporting" then
		releaseSeat(state.code, player.UserId)
	end
	if isInstance(player) then
		SaveCoordinator.setTeleportFrozen(player, false)
	end
	if reason and reason ~= "teleporting" and reason ~= "joined" then
		notify(player, reason)
	end
end

function PartyCrossServer.isJoining(player)
	return joinState[player] ~= nil
end

function PartyCrossServer.getJoinState(player)
	return joinState[player]
end

function PartyCrossServer.cancelJoin(player)
	local state = joinState[player]
	if state and state.phase ~= "teleporting" and state.phase ~= "saving" then
		state.cancelled = true
		return true
	end
	return false
end

-- 로컬(같은 서버) 합류 - 정원·보스전만 본다. 보스전 중이면 false, "in_boss"(호출부가 대기로 돌린다).
local function attachLocal(player, party)
	if party.bossActive then
		return false, "in_boss"
	end
	if PartyState.getSeatCount(party) >= PartyConfig.maxMembers and not PartyState.hasPendingSeat(party, player.UserId) then
		return false, "party_full"
	end
	if isInstance(player) and BossEncounter.getActive(player) then
		BossEncounter.despawnFor(player) -- 파티원의 보스전은 리더가 여는 파티 보스뿐(PartyServer 수락 경로와 같다)
	end
	PartyState.attachMember(party, player)
	PartyState.notify(player, ("%s님의 파티에 합류했습니다"):format(party.leader.name))
	return true
end

-- ═══ S19b 연결 끊김 재접속 표식 ═══
-- 파티 서버(이 파티가 있는 서버)가 멤버의 연결이 끊긴 순간 memberMap[userId] = { code, targetJobId = 이 서버, reconnect = true, awayUntil }을 쓴다(TTL = 남은 유예).
-- 그 사람이 어느 서버로 재접속하든 handleArrival이 이 표식을 읽는다 - 같은 서버면 PartyState.reclaim이 이미 복귀시켰고, 다른 서버면 복귀 초대를 띄운다.
local function writeReconnectMarker(party, record)
	if not party.code then
		return
	end
	task.spawn(function()
		call("재접속 표식 쓰기", function()
			return memberMap:SetAsync(tostring(record.userId), {
				code = party.code, targetJobId = game.JobId, since = os.time(), reconnect = true, leaderName = party.leader.name, awayUntil = record.awayUntil,
			}, math.max(1, record.awayUntil - os.time()))
		end)
	end)
end

-- 복귀 · 추방 · 만료로 유예가 끝났을 때 표식을 지운다(이 파티의 표식일 때만 - 그 사이 다른 파티 합류 기록으로 바뀌었으면 건드리지 않는다).
local function clearReconnectMarker(userId, code)
	task.spawn(function()
		local old = call("재접속 표식 읽기", function()
			return memberMap:GetAsync(tostring(userId))
		end)
		if type(old) == "table" and old.reconnect and old.code == code then
			call("재접속 표식 삭제", function()
				return memberMap:RemoveAsync(tostring(userId))
			end)
		end
	end)
end

-- 도착 처리(리더 서버). 멤버 레코드가 이 서버를 가리키면 그 파티에 붙인다. simulate=true(DevTools)는 JobId
-- 검사를 건너뛴다 - Studio에서 텔레포트 없이 같은 경로를 밟기 위해.
local function handleArrival(player, simulate)
	local record = call("멤버 레코드 읽기", function()
		return memberMap:GetAsync(tostring(player.UserId))
	end)
	if type(record) ~= "table" or seatExpired(record) then
		return false
	end
	if record.reconnect then
		-- S19b: 파티에서 연결이 끊겼던 사람의 재접속. 같은 서버면 PartyState.reclaim이 이미 복귀시켰다(표식만 치운다).
		if record.targetJobId == game.JobId then
			clearReconnectMarker(player.UserId, record.code)
			return true
		end
		-- 다른 서버면 파티는 targetJobId 서버에 남아 있다 - 복귀 초대를 띄운다. 수락하면 코드 합류와 같은 경로(requestJoin)로 그 서버로 이동한다(강제 이동은 안 한다).
		if not PartyState.getParty(player) and not joinState[player] and not remoteInvites[player] and readRecord(record.code) then
			local invite = { code = record.code, fromName = record.leaderName or "파티" }
			remoteInvites[player] = invite
			invite.thread = task.delay(PartyConfig.reconnectOfferSeconds, function()
				if remoteInvites[player] == invite then
					remoteInvites[player] = nil
				end
			end)
			partyInviteNotice:FireClient(player, { inviterName = invite.fromName, seconds = PartyConfig.reconnectOfferSeconds, remote = true })
			print(("[forge-game] 재접속 복귀 초대: %s -> 코드 %s (파티 서버 %s)"):format(player.Name, record.code, tostring(record.targetJobId)))
		end
		return true
	end
	if not simulate and record.targetJobId ~= game.JobId then
		return false -- 다른 서버로 가는 사람이 우연히 여기 접속했다(텔레포트 실패 후 재접속 등) - 그쪽 좌석은 TTL로 회수된다
	end
	call("멤버 레코드 삭제", function()
		return memberMap:RemoveAsync(tostring(player.UserId))
	end)
	local party = PartyState.getPartyByCode(record.code)
	if not party then
		releaseSeat(record.code, player.UserId)
		notify(player, "party_gone")
		print(("[forge-game] 크로스서버 도착: %s - 코드 %s 파티 없음(해산)"):format(player.Name, record.code))
		return true
	end
	if PartyState.getParty(player) then
		return true
	end
	if isInstance(player) and TutorialState.isActive(player) then
		PartyState.removePendingSeat(party, player.UserId)
		notify(player, "tutorial_self")
		return true
	end
	local ok, why = attachLocal(player, party)
	if not ok and why == "in_boss" then
		arrivalWaiting[player] = party
		-- 좌석이 만료되지 않게 갱신 - 보스전은 2분 리듬이라 seatTimeout(90초)을 넘길 수 있다.
		for _, seat in ipairs(PartyState.getPendingSeats(party)) do
			if seat.userId == player.UserId then
				seat.since = os.time()
			end
		end
		PartyState.notify(player, "파티가 보스전 중입니다 - 끝나면 자동으로 합류합니다")
		print(("[forge-game] 크로스서버 도착 보류: %s - 파티 #%d 보스전 중"):format(player.Name, party.id))
	elseif not ok then
		PartyState.removePendingSeat(party, player.UserId)
		notify(player, why)
	else
		print(("[forge-game] 크로스서버 합류 완료: %s -> 파티 #%d(코드 %s)"):format(player.Name, party.id, record.code))
	end
	return true
end
PartyCrossServer.handleArrival = handleArrival

-- 합류 요청. opts.simulateArrival(DevTools) - 텔레포트 대신 이 서버에서 도착 처리를 바로 실행한다.
-- opts.standIn - 스탠드인(가짜 Player 테이블) - 프로필·견습 검사를 건너뛴다.
function PartyCrossServer.requestJoin(player, code, opts)
	opts = opts or {}
	code = type(code) == "string" and code:upper() or ""
	if #code ~= PartyConfig.codeLength then
		notify(player, "party_not_found")
		return false
	end
	if joinState[player] then
		notify(player, "already_joining")
		return false
	end
	if PartyState.getParty(player) then
		notify(player, "already_in_party")
		return false
	end
	if not opts.standIn then
		if not PlayerProfile.getProfile(player) then
			notify(player, "no_profile")
			return false
		end
		if TutorialState.isActive(player) then
			notify(player, "tutorial_self")
			return false
		end
	end

	local state = { code = code, phase = "reserving", cancelled = false, seatReserved = false, standIn = opts.standIn }
	joinState[player] = state

	local record, err = readRecord(code)
	if not record then
		finishJoin(player, err)
		return false
	end

	-- 같은 서버 - 텔레포트 없이 바로 붙인다(보스전 중이면 아래 대기 루프로).
	local localParty = PartyState.getPartyByCode(code)
	if record.jobId == game.JobId and localParty then
		local ok, why = attachLocal(player, localParty)
		if ok then
			finishJoin(player, "joined")
			return true
		elseif why ~= "in_boss" then
			finishJoin(player, why)
			return false
		end
	end

	-- 좌석 예약(원자) + 멤버 레코드(두 파티 동시 합류 차단).
	local outcome = reserveSeat(code, player)
	if outcome ~= "ok" then
		finishJoin(player, outcome)
		return false
	end
	state.seatReserved = true
	local memberOutcome = writeMemberRecord(player, code, record.jobId)
	if memberOutcome ~= "ok" then
		finishJoin(player, memberOutcome)
		return false
	end
	publish({ type = "seat", code = code, userId = player.UserId, name = player.Name, since = os.time() })
	if localParty then
		PartyState.addPendingSeat(localParty, player.UserId, player.Name, os.time())
	end

	-- 대기 - 보스전 중이거나 서버 정원이 찼으면 풀릴 때까지 레코드를 다시 읽는다.
	state.phase = "waiting"
	local noticed = nil
	while true do
		if state.cancelled or (isInstance(player) and not player.Parent) then
			finishJoin(player, state.cancelled and "cancelled" or nil)
			return false
		end
		local blocked = nil
		if record.bossActive then
			blocked = "파티가 보스전 중입니다 - 끝나면 이동합니다"
		elseif (record.playerCount or 0) >= (record.capacity or PartyCrossServer.capacity()) and record.jobId ~= game.JobId then
			blocked = ("파티 서버가 가득 찼습니다(%d/%d) - 자리가 나면 이동합니다"):format(record.playerCount or 0, record.capacity or 0)
		end
		if not blocked then
			break
		end
		if noticed ~= blocked then
			noticed = blocked
			PartyState.notify(player, blocked)
			print(("[forge-game] 크로스서버 합류 대기: %s - %s"):format(player.Name, blocked))
		end
		task.wait(PartyConfig.joinPollSeconds)
		record, err = readRecord(code)
		if not record then
			finishJoin(player, err == "party_not_found" and "party_gone" or err)
			return false
		end
	end

	-- 같은 서버(보스전이 끝났다) - 로컬로 붙인다.
	if record.jobId == game.JobId then
		local party = PartyState.getPartyByCode(code)
		if not party then
			finishJoin(player, "party_gone")
			return false
		end
		local ok, why = attachLocal(player, party)
		finishJoin(player, ok and "joined" or why)
		return ok
	end

	-- 저장 flush 뒤 동결 - 이 시점 이후 출발 서버는 이 플레이어를 저장하지 않는다(퇴장 저장 포함). 도착
	-- 서버가 읽는 값은 항상 이 flush 결과다(낙관적 동시성 savedAt 경합 없음).
	state.phase = "saving"
	if isInstance(player) then
		ImmediateSave.flush(player)
		SaveCoordinator.setTeleportFrozen(player, true)
	end

	if opts.simulateArrival then
		state.phase = "teleporting"
		joinState[player] = nil
		if isInstance(player) then
			SaveCoordinator.setTeleportFrozen(player, false)
		end
		print(("[forge-game] 크로스서버 합류(시뮬레이션): %s - 텔레포트 생략, 도착 처리 실행"):format(player.Name))
		handleArrival(player, true)
		return true
	end

	state.phase = "teleporting"
	local options = Instance.new("TeleportOptions")
	options.ServerInstanceId = record.jobId
	options:SetTeleportData({ partyCode = code }) -- 힌트 - 권위는 멤버 레코드
	PartyState.notify(player, ("%s님의 파티 서버로 이동합니다"):format(record.leaderName or "?"))
	print(("[forge-game] 크로스서버 텔레포트 시작: %s -> jobId %s (코드 %s)"):format(player.Name, record.jobId, code))
	local ok, teleportErr = pcall(function()
		return TeleportService:TeleportAsync(record.placeId or game.PlaceId, { player }, options)
	end)
	if not ok then
		warn(("[forge-game] 크로스서버 텔레포트 호출 실패: %s - %s"):format(player.Name, tostring(teleportErr)))
		finishJoin(player, "teleport_failed")
		return false
	end
	return true
end

-- 텔레포트가 시작된 뒤 마지막 순간에 실패하면(서버 종료·정원 초과·플러드) 플레이어는 이 서버에 남는다 -
-- 좌석·동결을 풀고 이유를 알린다. 결과별 문구는 Enum.TeleportResult 공식 설명 그대로.
TeleportService.TeleportInitFailed:Connect(function(player, teleportResult, errorMessage)
	local state = joinState[player]
	if not state then
		return
	end
	warn(("[forge-game] 크로스서버 텔레포트 실패: %s - %s (%s)"):format(player.Name, tostring(teleportResult), tostring(errorMessage)))
	local text = REASON_TEXT.teleport_failed
	if teleportResult == Enum.TeleportResult.GameFull then
		text = "파티 서버가 가득 찼습니다(플랫폼 정원). 지금 자리에 그대로 있습니다"
	elseif teleportResult == Enum.TeleportResult.GameEnded or teleportResult == Enum.TeleportResult.GameNotFound then
		text = "파티 서버가 종료되었습니다. 지금 자리에 그대로 있습니다"
	elseif teleportResult == Enum.TeleportResult.Flooded then
		text = "이동 요청이 너무 잦습니다. 잠시 후 다시 시도하세요"
	end
	joinState[player] = nil
	if state.seatReserved then
		releaseSeat(state.code, player.UserId)
	end
	SaveCoordinator.setTeleportFrozen(player, false)
	PartyState.notify(player, text)
end)

-- ═══ 초대(리더 서버 → 다른 서버) ═══

function PartyCrossServer.inviteRemote(leader, targetUserId)
	local target = Players:GetPlayerByUserId(targetUserId)
	if target then
		return PartyState.invite(leader, target) -- 같은 서버면 로컬 초대
	end
	local party = PartyState.getParty(leader)
	if party and PartyState.getLeader(party) ~= leader then
		return false, "not_leader"
	end
	if party and PartyState.getSeatCount(party) >= PartyConfig.maxMembers then
		return false, "party_full"
	end
	if not party then
		party = PartyState.create(leader)
	end
	local code = PartyCrossServer.ensureCode(party)
	if not code then
		return false, "service_unavailable"
	end
	publish({ type = "invite", toUserId = targetUserId, code = code, fromName = leader.Name, fromUserId = leader.UserId })
	print(("[forge-game] 크로스서버 초대 발송: %s -> userId %d (코드 %s)"):format(leader.Name, targetUserId, code))
	return true
end

function PartyCrossServer.hasRemoteInvite(player)
	return remoteInvites[player] ~= nil
end

function PartyCrossServer.respondRemoteInvite(player, accept)
	local invite = remoteInvites[player]
	if not invite then
		return false, "no_invite"
	end
	clearRemoteInvite(player)
	if not accept then
		return true, "declined"
	end
	task.spawn(PartyCrossServer.requestJoin, player, invite.code)
	return true, "joining"
end

-- 온라인 친구 목록(다른 서버에 있는 사람만 - 같은 서버 친구는 "서버 플레이어" 목록에 이미 있다).
function PartyCrossServer.getOnlineFriendsElsewhere(player)
	local list = {}
	local pages = call("친구 목록", function()
		return Players:GetFriendsAsync(player.UserId)
	end)
	if not pages then
		return list
	end
	local ok = pcall(function()
		while true do
			for _, friend in ipairs(pages:GetCurrentPage()) do
				if friend.IsOnline and not Players:GetPlayerByUserId(friend.Id) then
					table.insert(list, { userId = friend.Id, name = friend.Username, displayName = friend.DisplayName })
				end
			end
			if pages.IsFinished then
				break
			end
			pages:AdvanceToNextPageAsync()
		end
	end)
	if not ok and not warnedOnce["친구 페이지"] then
		warnedOnce["친구 페이지"] = true
		warn("[forge-game] 친구 목록 페이지 넘김 실패")
	end
	table.sort(list, function(a, b)
		return a.name < b.name
	end)
	return list
end

-- ═══ 진단(/gg party server) ═══

function PartyCrossServer.describeServer()
	local lines = {}
	table.insert(lines, ("jobId=%s placeId=%d 인원 %d / 크로스서버 상한 %d (설계 %d = %d×%d + %d) / 플랫폼 MaxPlayers=%d PreferredPlayers=%d"):format(
		game.JobId ~= "" and game.JobId or "(Studio 빈 값)", game.PlaceId, #Players:GetPlayers(), PartyCrossServer.capacity(),
		PartyConfig.serverCapacity, PartyConfig.maxMembers, PartyConfig.partiesPerServer, PartyConfig.maxMembers,
		Players.MaxPlayers, Players.PreferredPlayers))
	local count = 0
	for _, party in pairs(PartyState.getAllParties()) do
		count += 1
		local names = {}
		for _, record in ipairs(PartyState.getMemberRecords(party)) do
			table.insert(names, record.name .. (record == party.leader and "★" or ""))
		end
		local seats = {}
		for _, seat in ipairs(PartyState.getPendingSeats(party)) do
			table.insert(seats, ("%s(%ds)"):format(seat.name, os.time() - (seat.since or os.time())))
		end
		table.insert(lines, ("파티 #%d 코드=%s 멤버 %d [%s] 원격 좌석 %d [%s] 보스전=%s"):format(
			party.id, tostring(party.code), #names, table.concat(names, ","), #seats, table.concat(seats, ","), tostring(party.bossActive)))
	end
	if count == 0 then
		table.insert(lines, "파티 없음")
	end
	for player, state in pairs(joinState) do
		table.insert(lines, ("합류 중: %s -> %s (%s)"):format(player.Name, state.code, state.phase))
	end
	for player, party in pairs(arrivalWaiting) do
		table.insert(lines, ("도착 보류: %s -> 파티 #%d"):format(player.Name, party.id))
	end
	return table.concat(lines, "\n")
end

-- ═══ 배선 ═══

-- 파티 변화 → 레코드. "create"는 코드 발급(레코드도 그때 처음 쓴다), "disband"는 삭제, 나머지는 갱신.
PartyState.onChanged(function(party, event, record)
	if event == "create" then
		PartyCrossServer.ensureCode(party)
	elseif event == "away" then
		publishRecord(party)
		writeReconnectMarker(party, record)
	elseif event == "return" then
		publishRecord(party)
		clearReconnectMarker(record.userId, party.code)
	elseif (event == "leave" or event == "leader") and record and record.awayUntil then
		publishRecord(party) -- 유예 중이던 멤버가 추방 · 만료로 빠졌다
		clearReconnectMarker(record.userId, party.code)
	elseif event == "disband" then
		removeRecord(party.code, party)
		for player, waiting in pairs(arrivalWaiting) do
			if waiting == party then
				arrivalWaiting[player] = nil
				notify(player, "party_gone")
			end
		end
	else
		publishRecord(party)
	end
end)

-- 보스전 시작/종료 → bossActive. 종료 시 보류 중이던 도착자를 붙인다.
BossEncounter.onEncounterStarted(function(encounter)
	if encounter.party then
		PartyState.setBossActive(encounter.party, true)
	end
end)
BossEncounter.onEncounterEnded(function(encounter)
	local party = encounter.party
	if not party then
		return
	end
	PartyState.setBossActive(party, false)
	for player, waiting in pairs(arrivalWaiting) do
		if waiting == party then
			arrivalWaiting[player] = nil
			if (not isInstance(player) or player.Parent) and not PartyState.getParty(player) then
				local ok, why = attachLocal(player, party)
				if not ok then
					PartyState.removePendingSeat(party, player.UserId)
					notify(player, why)
				end
			end
		end
	end
end)

-- 하트비트 - 레코드 TTL 갱신 + 만료 좌석 회수 + 유실 메시지 reconcile.
task.spawn(function()
	while true do
		task.wait(PartyConfig.heartbeatSeconds)
		for userId, at in pairs(recentlyReleased) do
			if os.time() - at >= PartyConfig.seatTimeoutSeconds then
				recentlyReleased[userId] = nil
			end
		end
		for _, party in pairs(PartyState.getAllParties()) do
			for _, seat in ipairs(table.clone(PartyState.getPendingSeats(party))) do
				local holder = Players:GetPlayerByUserId(seat.userId)
				if seatExpired(seat) and not (holder and arrivalWaiting[holder]) then
					print(("[forge-game] 파티 원격 좌석 만료 회수: #%d %s"):format(party.id, seat.name))
					recentlyReleased[seat.userId] = os.time()
					PartyState.removePendingSeat(party, seat.userId)
				end
			end
			if party.code then
				publishRecord(party)
			else
				PartyCrossServer.ensureCode(party) -- 발급 실패했던 파티 재시도
			end
		end
	end
end)

call("토픽 구독", function()
	return MessagingService:SubscribeAsync(messagingTopic, onMessage)
end)

Players.PlayerAdded:Connect(function(player)
	-- 프로필 로드 뒤 도착 처리(StageServer.server.lua의 같은 폴링 패턴).
	while player.Parent and not PlayerProfile.getProfile(player) do
		task.wait()
	end
	if player.Parent then
		PartyState.reclaim(player) -- S19b: 같은 서버로 재접속한 끊긴 멤버는 유예 안에서 파티로 복귀한다(프로필이 로드된 뒤 - 클라가 파티 상태를 받을 준비가 된 때)
		handleArrival(player, false)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	arrivalWaiting[player] = nil
	clearRemoteInvite(player)
	local state = joinState[player]
	if state then
		-- 텔레포트로 나가는 중이면 좌석은 도착 서버가 소비한다. 그 외(대기 중 접속 종료)는 회수.
		joinState[player] = nil
		if state.seatReserved and state.phase ~= "teleporting" then
			releaseSeat(state.code, player.UserId)
		end
	end
end)

game:BindToClose(function()
	for _, party in pairs(PartyState.getAllParties()) do
		if party.code then
			call("레코드 삭제", function()
				return partyMap:RemoveAsync(party.code)
			end)
		end
	end
	for player, state in pairs(joinState) do
		if state.seatReserved and state.phase ~= "teleporting" then
			releaseSeat(state.code, player.UserId)
		end
	end
end)

do
	local capacity = PartyCrossServer.capacity()
	local note = ""
	if Players.MaxPlayers ~= PartyConfig.serverCapacity or Players.PreferredPlayers ~= PartyConfig.serverPreferredPlayers then
		note = (" - 설정 확인 필요: 대시보드 Max Players=%d, 매치메이킹 정원=%d 로 맞춰야 설계(12+4)와 일치한다"):format(
			PartyConfig.serverCapacity, PartyConfig.serverPreferredPlayers)
	end
	print(("[forge-game] PartyCrossServer 로드됨 - 플랫폼 MaxPlayers=%d PreferredPlayers=%d, 크로스서버 상한 %d%s"):format(
		Players.MaxPlayers, Players.PreferredPlayers, capacity, note))
end

-- ═══ DevTools 전용(/gg party fakeremote·xtest) - 레코드를 직접 읽고 쓴다. 라이브 코드 경로는 부르지 않는다. ═══

function PartyCrossServer.debugWriteRecord(code, record)
	record.updatedAt = os.time()
	return call("디버그 레코드 쓰기", function()
		return partyMap:SetAsync(code, record, PartyConfig.recordTtlSeconds)
	end)
end

function PartyCrossServer.debugReadRecord(code)
	return (call("디버그 레코드 읽기", function()
		return partyMap:GetAsync(code)
	end))
end

function PartyCrossServer.debugRemoveRecord(code)
	call("디버그 레코드 삭제", function()
		return partyMap:RemoveAsync(code)
	end)
end

function PartyCrossServer.debugWriteMemberRecord(userId, code, targetJobId)
	return call("디버그 멤버 레코드 쓰기", function()
		return memberMap:SetAsync(tostring(userId), { code = code, targetJobId = targetJobId, since = os.time() }, PartyConfig.seatTimeoutSeconds)
	end)
end

function PartyCrossServer.debugReadMemberRecord(userId)
	return (call("디버그 멤버 레코드 읽기", function()
		return memberMap:GetAsync(tostring(userId))
	end))
end

function PartyCrossServer.debugIsArrivalWaiting(player)
	return arrivalWaiting[player] ~= nil
end

return PartyCrossServer
