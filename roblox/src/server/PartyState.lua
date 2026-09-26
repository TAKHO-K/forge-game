-- 파티 멤버십 단일 관리 통로(24-1, PRD 20.47 [5]). 세션 메모리만 쓴다 - 저장하지 않는다
-- (서버가 바뀌면 파티도 끝, SAVE_VERSION 영향 없음). 이 모듈은 "누가 어느 파티에 있는가"만
-- 안다 - 보스전(BossEncounter)·견습(TutorialState)은 모른다. 그쪽이 이 모듈을 require하고,
-- 이 모듈은 멤버가 빠질 때 리스너(onMemberRemoved)로 알리기만 한다 - 순환 require를
-- 구조적으로 막는다(BossEncounter → PartyState, TutorialState → PartyState, 역방향 없음).
--
-- 규칙(지시 그대로):
--   · 최대 PartyConfig.maxMembers(4)명. 리더 하나 - 초대·추방은 리더만, 탈퇴는 아무나.
--   · 파티가 없는 사람이 초대하면 그 순간 자기가 리더인 파티가 생긴다(별도 "결성" 조작 없음 -
--     "초대·수락·탈퇴는 최소한의 조작으로").
--   · 리더 퇴장 시 가장 오래된 멤버가 승계(PRD (라)). 멤버가 1명 이하로 줄면 파티는 해산된다
--     (혼자 남은 파티는 의미가 없다 - 임의 결정, 보고서 참고).
--   · 더미 멤버(DevTools "/gg party dummy") - Player 인스턴스가 없는 가짜 멤버. 인원수(보스 HP
--     배수)·HUD 목록에는 들어가지만 텔레포트·피격·보상 대상이 아니다(isDummy).
--
-- 24-2 크로스서버(PRD 20.63): 이 모듈은 여전히 "이 서버 안의 멤버십"만 안다. 서버 밖(MemoryStore
-- 레코드·MessagingService·텔레포트)은 PartyCrossServer.lua가 맡고, 이 모듈은 그쪽이 필요로 하는 세
-- 가지만 더 든다 - (1) party.code(다른 서버에서 이 파티를 가리키는 6자리 코드, PartyCrossServer가
-- 발급해 setCode로 넣는다), (2) party.pending(다른 서버에서 좌석을 예약하고 텔레포트 중인 사람 -
-- 정원 계산에는 들어가고 보스 HP 배수 N에는 안 들어간다, 아직 여기 없으니까), (3) onChanged 리스너
-- (결성·합류·이탈·승계·좌석 변화를 밖에 알린다 - PartyCrossServer가 레코드를 다시 쓴다). 역방향
-- require는 여전히 없다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)

local PartyState = {}

-- 멤버 전원에게 파티 상태 스냅샷을 민다(클라 PartyHud/InventoryUI 파티 탭이 읽는다).
-- 파티에서 빠진 사람에게는 nil을 보낸다 - "파티 없음"도 상태다.
local partyStateChanged = Instance.new("RemoteEvent")
partyStateChanged.Name = "PartyStateChanged"
partyStateChanged.Parent = ReplicatedStorage

-- 초대 팝업(받는 쪽) - { inviterName, expiresAt }.
local partyInviteNotice = Instance.new("RemoteEvent")
partyInviteNotice.Name = "PartyInviteNotice"
partyInviteNotice.Parent = ReplicatedStorage

-- 짧은 문자열 알림(거절 사유·입장 불가 사유 등) - 클라 PartyHud가 토스트로 띄운다.
local partyNotice = Instance.new("RemoteEvent")
partyNotice.Name = "PartyNotice"
partyNotice.Parent = ReplicatedStorage

-- party = { id, leader = record, members = { record, ... }(가입 순), nextDummyIndex,
--           code = string|nil(24-2), pending = { {userId, name, since}, ... }(24-2 원격 좌석), bossActive = bool(24-2) }
-- record = { player = Player|nil, name, userId, isDummy, joinedAt, dummy = { classId, level, stage }|nil }
local parties = {} -- [id] = party (살아 있는 파티만)
-- [Player] = party. D1-2: 쓰는 곳이 여럿(결성 · 합류 · 복귀 · 탈퇴 · 끊김)이라 대리 표로 받아 Player Attribute PartyId(파티 번호 · 없으면 nil)를 같이 맞춘다 -
-- 잡몹 막힘의 파티원 예외(shared/MobShare - 서버 isBlocked · 클라 자물쇠 MobLockView)가 읽는다. 스탠드인(테이블)은 Attribute가 없어 건너뛴다(시뮬 · 검증은 who.party).
local partyOfStore = {}
local partyOf = setmetatable({}, {
	__index = partyOfStore,
	__newindex = function(_, player, party)
		partyOfStore[player] = party
		if typeof(player) == "Instance" and player:IsA("Player") then
			player:SetAttribute("PartyId", party and party.id or nil)
		end
	end,
})
local invites = {} -- [invitee Player] = { party, inviter = Player, expiresAt, thread }
local nextPartyId = 1
local removedListeners = {} -- fn(player, party, reason)
local changedListeners = {} -- fn(party, event, record) - event: "create"/"join"/"leave"/"leader"/"seat"/"boss"/"disband"/"away"(S19b 연결 끊김 유예 시작)/"return"(유예 중이던 멤버가 복귀)

-- 아래 좌석 헬퍼들이 먼저 쓰므로 선언 직후에 정의한다(Lua 지역 함수는 정의 순서를 따른다).
local function fireChanged(party, event, record)
	for _, fn in ipairs(changedListeners) do
		task.spawn(fn, party, event, record) -- record: "away"/"leave"/"leader"/"join"에서 그 멤버 기록(S19b - PartyCrossServer가 재접속 표식을 쓰고 지운다)
	end
end

local function now()
	return os.clock()
end

-- 실제 Player 인스턴스에만 보낸다. DevTools "/gg party selftest"가 넣는 스탠드인(Player 필드만
-- 흉내 낸 테이블, chesttest의 standIn과 같은 기법)은 FireClient 대상이 될 수 없어 여기서 걸러진다.
local function fireClient(remote, player, ...)
	if typeof(player) == "Instance" and player.Parent then
		remote:FireClient(player, ...)
	end
end

-- 30-0 S09: 파티 경험치 보너스를 클라(파티 목록의 "경험치 +N%" 칩)가 읽을 Attribute로 내린다. 스탠드인(테이블)에는 Attribute가 없어 여기서 걸러진다.
local function syncExpBonusAttribute(player, bonus)
	if typeof(player) == "Instance" and player.Parent then
		player:SetAttribute("PartyExpBonus", bonus)
	end
end

local function recordOf(party, player)
	for _, record in ipairs(party.members) do
		if record.player == player then
			return record
		end
	end
	return nil
end

function PartyState.getParty(player)
	return partyOf[player]
end

function PartyState.isLeader(player)
	local party = partyOf[player]
	return party ~= nil and party.leader.player == player
end

function PartyState.getLeader(party)
	return party and party.leader.player
end

-- 인원수 - 더미 포함(보스 HP 배수는 "입장 머릿수"다, PRD 20.47 [6](가)). S19b: 연결이 끊겨 유예 중인 멤버(awayUntil)는 지금 입장할 수 없으므로 세지 않는다 -
-- 자리(getSeatCount)는 그대로 차지하지만 보스 HP 배수 N에는 안 들어간다(좌석 예약과 같은 처리).
function PartyState.getSize(party)
	local count = 0
	if party then
		for _, record in ipairs(party.members) do
			if not record.awayUntil then
				count += 1
			end
		end
	end
	return count
end

-- 30-0 S09(PRD 20.73 [5-1]): 파티 경험치 보너스. 인원 = 실제 Player 멤버 수(더미 · 텔레포트 중인 원격 좌석은 안 센다).
-- P2 G부터 실제 지급(PlayerProfile.getExpGainMultiplier)은 조건부 getExpBonusFor를 쓴다. P2.5a(결정 7)부터 클라 칩(Attribute)도 조건부 값(지급 순간 · pushState)이다 - 이 함수는 인원표 조회용.
function PartyState.getExpBonusForCount(memberCount)
	return PartyConfig.expBonusByMemberCount[memberCount] or 0
end

function PartyState.getExpBonus(party)
	if not party then
		return 0
	end
	return PartyState.getExpBonusForCount(#PartyState.getMemberPlayers(party))
end

-- ═══ P2 G: 조건부 파티 경험치 보너스 ═══
-- 활동 기록 = 마지막으로 적에게 명중한 시각(P2.5a 결정 10 - CombatResolution.resolveHit가 부른다. 옛: 공격 · 스킬 요청 순간). 표 키라 검증 스탠드인(테이블)도 된다.
local lastActivityAt = {}

-- P2.5a D(결정 10): 활동 = 적에게 실제로 명중한 순간만(CombatResolution.resolveHit - 평타 · 스킬 피해 공통). 헛스윙 · 치유 시전은 활동이 아니다.
function PartyState.noteActivity(player, at)
	lastActivityAt[player] = at or now()
end

-- P2.5a D(결정 7): 경험치 지급 순간 실제로 적용한 파티 보너스를 칩(Attribute PartyExpBonus)에 내린다(PlayerProfile.getExpGainMultiplier가 부른다).
function PartyState.showAppliedExpBonus(player, bonus)
	syncExpBonusAttribute(player, bonus)
end

-- C1: 스테이지를 바꾸면 활동 기록을 지운다(파티 보너스 인원 = 지금 스테이지에서 쌓은 활동만).
function PartyState.clearActivity(player)
	lastActivityAt[player] = nil
end

function PartyState.getLastActivity(player)
	return lastActivityAt[player]
end

-- 판정 함수 fn(recipient, member) → boolean은 server/PartyExpBonus.lua가 등록한다(그쪽이 BossEncounter · 위치를 안다 - 이 모듈은 둘을 모른다, 순환 require 방지).
local expEligibility = nil

function PartyState.setExpEligibility(fn)
	expEligibility = fn
end

-- 받는 사람 기준 보너스 = 조건을 만족한 실제 멤버 수(받는 사람 포함)의 보너스. PlayerProfile.getExpGainMultiplier(경험치 · 재료 지급)가 부른다.
-- 판정 함수가 아직 없으면(서버 시작 전) 아무도 세지 않는다(보너스 0 - 조건 없는 옛 보너스로 새지 않게).
function PartyState.getExpBonusFor(player)
	local party = partyOf[player]
	if not party then
		return 0
	end
	local count = 1
	for _, member in ipairs(PartyState.getMemberPlayers(party)) do
		if member ~= player and expEligibility and expEligibility(player, member) then
			count += 1
		end
	end
	return PartyState.getExpBonusForCount(count)
end

-- ═══ 24-2 크로스서버 보조 ═══

-- 정원 계산용 좌석 수 = 멤버(더미 포함) + 텔레포트 중인 원격 좌석. 초대·수락·코드 합류의 "만원" 판정은
-- 전부 이 값으로 한다 - 좌석을 먼저 잡아 두지 않으면 "텔레포트하는 동안 파티가 찼다"가 생긴다.
function PartyState.getSeatCount(party)
	return party and (#party.members + #party.pending) or 0
end

function PartyState.getPendingSeats(party)
	return party and party.pending or {}
end

function PartyState.hasPendingSeat(party, userId)
	for _, seat in ipairs(party.pending) do
		if seat.userId == userId then
			return true
		end
	end
	return false
end

function PartyState.isMemberUserId(party, userId)
	for _, record in ipairs(party.members) do
		if record.userId == userId then
			return true
		end
	end
	return false
end

-- 원격 좌석 추가(다른 서버에서 좌석을 예약하고 텔레포트를 시작한 사람). since는 예약 시각(os.time) -
-- 리더 서버가 seatTimeoutSeconds가 지난 좌석을 회수한다(PartyCrossServer 하트비트).
function PartyState.addPendingSeat(party, userId, name, since)
	if PartyState.hasPendingSeat(party, userId) or PartyState.isMemberUserId(party, userId) then
		return false
	end
	table.insert(party.pending, { userId = userId, name = name, since = since or os.time() })
	PartyState.pushState(party)
	fireChanged(party, "seat")
	print(("[forge-game] 파티 원격 좌석 예약: #%d %s (좌석 %d/%d)"):format(party.id, name, PartyState.getSeatCount(party), PartyConfig.maxMembers))
	return true
end

-- silent=true면 pushState/리스너를 부르지 않는다(attachMember처럼 바로 뒤에 더 큰 변화가 따라올 때).
function PartyState.removePendingSeat(party, userId, silent)
	for i, seat in ipairs(party.pending) do
		if seat.userId == userId then
			table.remove(party.pending, i)
			if not silent then
				PartyState.pushState(party)
				fireChanged(party, "seat")
				print(("[forge-game] 파티 원격 좌석 해제: #%d %s"):format(party.id, seat.name))
			end
			return true
		end
	end
	return false
end

function PartyState.setCode(party, code)
	party.code = code
	PartyState.pushState(party)
end

function PartyState.getPartyByCode(code)
	for _, party in pairs(parties) do
		if party.code == code then
			return party
		end
	end
	return nil
end

function PartyState.getAllParties()
	return parties
end

-- 보스전 진행 중 표시(BossEncounter가 파티 보스를 시작/끝낼 때 PartyCrossServer가 넣는다). 다른 서버의
-- 합류 대기자가 이 값을 레코드에서 읽어 "보스전이 끝날 때까지" 기다린다.
function PartyState.setBossActive(party, active)
	if party.bossActive == active then
		return
	end
	party.bossActive = active
	PartyState.pushState(party)
	fireChanged(party, "boss")
end

-- 실제 Player만(텔레포트·보상·피격 대상).
function PartyState.getMemberPlayers(party)
	local list = {}
	if party then
		for _, record in ipairs(party.members) do
			if record.player then
				table.insert(list, record.player)
			end
		end
	end
	return list
end

function PartyState.getMemberRecords(party)
	return party and party.members or {}
end

-- 클라이언트에 보낼 스냅샷. 실제 플레이어의 HP·레벨·직업은 Player Attribute(Hp/MaxHp/ClassId/
-- CharacterLevel/InfiniteStage - 전 클라에 복제된다)로 클라가 직접 읽으므로 여기엔 안 넣는다.
-- 더미만 값이 없어서 스냅샷에 실어 보낸다.
local function snapshot(party)
	local members = {}
	for _, record in ipairs(party.members) do
		table.insert(members, {
			userId = record.userId,
			name = record.name,
			isDummy = record.isDummy,
			isLeader = record == party.leader,
			dummy = record.dummy,
			-- S19b: 연결 끊김 유예 중이면 남은 초(클라가 받은 시각 기준으로 m:ss를 센다 - 서버 · 클라 시계를 맞출 필요가 없다)와 끊기기 직전의 직업 · 레벨 · 스테이지
			awayRemaining = record.awayUntil and math.max(0, record.awayUntil - os.time()) or nil,
			last = record.last,
		})
	end
	local pending = {}
	for _, seat in ipairs(party.pending) do
		table.insert(pending, { userId = seat.userId, name = seat.name })
	end
	return {
		id = party.id,
		leaderUserId = party.leader.userId,
		members = members,
		pending = pending,
		code = party.code,
		bossActive = party.bossActive or false,
		maxMembers = PartyConfig.maxMembers,
	}
end

PartyState.debugSnapshot = snapshot -- S19b 검증 전용(스냅샷을 클라 없이 읽는다)

function PartyState.pushState(party)
	local data = snapshot(party)
	for _, player in ipairs(PartyState.getMemberPlayers(party)) do
		fireClient(partyStateChanged, player, data)
		-- P2.5a D(결정 7): 칩 = 실제로 적용되는 보너스(조건 판정 getExpBonusFor - 인원 보너스가 아니다).
		syncExpBonusAttribute(player, PartyState.getExpBonusFor(player))
	end
end

function PartyState.notify(player, text)
	fireClient(partyNotice, player, text)
end

function PartyState.onMemberRemoved(fn)
	table.insert(removedListeners, fn)
end

local function fireRemoved(player, party, reason)
	for _, fn in ipairs(removedListeners) do
		task.spawn(fn, player, party, reason)
	end
end

-- 24-2: 파티 구성이 바뀔 때마다 밖에 알린다(PartyCrossServer가 MemoryStore 레코드를 다시 쓴다).
function PartyState.onChanged(fn)
	table.insert(changedListeners, fn)
end

local function createParty(leader)
	local record = { player = leader, name = leader.Name, userId = leader.UserId, isDummy = false, joinedAt = now() }
	local party = { id = nextPartyId, leader = record, members = { record }, nextDummyIndex = 1, pending = {}, bossActive = false }
	nextPartyId += 1
	parties[party.id] = party
	partyOf[leader] = party
	print(("[forge-game] 파티 결성: #%d 리더 %s"):format(party.id, leader.Name))
	fireChanged(party, "create")
	return party
end

-- 24-2: 초대 없이 파티만 만든다(장비창 "파티 만들기" - 다른 서버의 친구에게 줄 코드를 먼저 받기 위해).
-- 이미 파티가 있으면 그 파티를 돌려준다(멱등).
function PartyState.create(leader)
	local party = partyOf[leader]
	if party then
		return party, "already_in_party"
	end
	party = createParty(leader)
	PartyState.pushState(party)
	return party
end

local function cancelInvite(invitee)
	local invite = invites[invitee]
	if invite then
		if invite.thread then
			task.cancel(invite.thread)
		end
		invites[invitee] = nil
	end
end

-- 멤버 하나를 뺀다(탈퇴·추방·퇴장·견습 진입·해산 공통). 리더가 빠지면 가장 오래된 멤버
-- (members[1] - 가입 순 배열이라 항상 그게 최고참)가 승계한다. 1명 이하로 줄면 해산.
local function removeRecord(party, record, reason)
	local index = table.find(party.members, record)
	if not index then
		return
	end
	table.remove(party.members, index)
	if record.player then
		partyOf[record.player] = nil
		fireClient(partyStateChanged, record.player, nil)
		syncExpBonusAttribute(record.player, 0)
		fireRemoved(record.player, party, reason)
	end

	local wasLeader = party.leader == record
	-- 멤버(더미 포함)가 1명 이하로 줄면 해산 - 혼자 남은 파티는 의미가 없다(초대 직후의 1인 파티는
	-- 수락 대기 상태라 예외 - 여기는 "빠져서" 1명이 된 경우만 온다).
	if #party.members <= 1 and reason ~= "disband" then
		print(("[forge-game] 파티 해산: #%d (남은 인원 %d)"):format(party.id, #party.members))
		for _, remaining in ipairs(table.clone(party.members)) do
			-- 25-4(B1 결함 수정): 추방 시엔 알림이 있는데(448행) 자동 해산엔 없었다 - 남은
			-- 멤버(더미 제외)에게 알린다. removeRecord가 partyOf를 지우기 전에 보낸다.
			if remaining.player then
				PartyState.notify(remaining.player, "파티가 해산되었습니다")
			end
			removeRecord(party, remaining, "disband")
		end
		party.pending = {}
		parties[party.id] = nil
		fireChanged(party, "disband")
		return
	end
	if reason == "disband" then
		return -- 해산 루프 안의 개별 제거 - 위에서 한 번만 알린다
	end
	if wasLeader then
		for _, candidate in ipairs(party.members) do
			if candidate.player then
				party.leader = candidate
				print(("[forge-game] 파티 리더 승계: #%d -> %s"):format(party.id, candidate.name))
				break
			end
		end
	end
	PartyState.pushState(party)
	fireChanged(party, wasLeader and "leader" or "leave", record)
end

-- S19b 연결 끊김 유예: 끊긴 멤버 기록(record.awayUntil = 유예가 끝나는 os.time · record.player = nil · record.last = 끊기기 직전 직업 · 레벨 · 스테이지)은 members에 그대로 남아
-- 자리를 차지한다(getSeatCount) - 접속 중인 멤버 목록(getMemberPlayers) · 입장 인원(getSize) · 경험치 보너스 인원에는 안 들어간다.
local function findAway(party, userId)
	for _, record in ipairs(party.members) do
		if record.awayUntil and record.userId == userId then
			return record
		end
	end
	return nil
end

-- 유예 중이던 기록에 새 Player를 붙여 복귀시킨다(가입 순서 · 이전 자리 그대로. 파티장 자리는 이미 승계됐으므로 일반 멤버로 돌아온다).
local function reviveRecord(party, record, player)
	record.player = player
	record.awayUntil = nil
	record.awayToken = nil
	record.last = nil
	record.name = player.Name
	partyOf[player] = party
	PartyState.pushState(party)
	PartyState.notify(player, "파티에 복귀했습니다")
	print(("[forge-game] 파티 복귀: #%d %s (%d/%d)"):format(party.id, player.Name, #party.members, PartyConfig.maxMembers))
	fireChanged(party, "return", record)
end

-- 초대. 반환: ok, reason. inviter가 파티가 없으면 새 파티를 만들어 리더가 된다.
-- 견습·보스전 중 검사는 호출부(PartyServer.server.lua)가 이 함수 전에 한다(이 모듈은
-- TutorialState/BossEncounter를 모른다 - 파일 상단 주석).
function PartyState.invite(inviter, invitee)
	if inviter == invitee then
		return false, "self"
	end
	if partyOf[invitee] then
		return false, "target_in_party"
	end
	if invites[invitee] then
		return false, "target_has_invite"
	end
	local party = partyOf[inviter]
	if party and party.leader.player ~= inviter then
		return false, "not_leader"
	end
	if party and PartyState.getSeatCount(party) >= PartyConfig.maxMembers then
		return false, "party_full"
	end
	if not party then
		party = createParty(inviter)
		PartyState.pushState(party)
	end

	local expiresAt = now() + PartyConfig.inviteTimeoutSeconds
	local invite = { party = party, inviter = inviter, expiresAt = expiresAt }
	invites[invitee] = invite
	invite.thread = task.delay(PartyConfig.inviteTimeoutSeconds, function()
		if invites[invitee] == invite then
			invites[invitee] = nil
			PartyState.notify(inviter, ("%s님이 초대에 응답하지 않았습니다"):format(invitee.Name))
		end
	end)
	fireClient(partyInviteNotice, invitee, { inviterName = inviter.Name, seconds = PartyConfig.inviteTimeoutSeconds })
	print(("[forge-game] 파티 초대: #%d %s -> %s"):format(party.id, inviter.Name, invitee.Name))
	return true
end

-- 수락/거절. 수락 시점에 파티가 사라졌거나 꽉 찼으면 실패 - 초대 시점이 아니라 지금을 본다.
function PartyState.respondInvite(invitee, accept)
	local invite = invites[invitee]
	if not invite then
		return false, "no_invite"
	end
	cancelInvite(invitee)
	local party = invite.party
	local inviter = invite.inviter
	if not accept then
		PartyState.notify(inviter, ("%s님이 초대를 거절했습니다"):format(invitee.Name))
		return true, "declined"
	end
	if partyOf[invitee] then
		return false, "already_in_party"
	end
	if partyOf[inviter] ~= party or #party.members == 0 then
		return false, "party_gone"
	end
	if PartyState.getSeatCount(party) >= PartyConfig.maxMembers and not PartyState.hasPendingSeat(party, invitee.UserId) then
		return false, "party_full"
	end
	PartyState.attachMember(party, invitee)
	return true, "joined"
end

-- 24-2: 초대 절차 없이 멤버로 붙인다(수락 확정·코드 합류·원격 도착 공통 마지막 단계). 이 사람의
-- 원격 좌석(pending)이 있으면 그 좌석이 실제 멤버로 바뀐다. 정원 검사는 호출부가 한다.
function PartyState.attachMember(party, player)
	PartyState.removePendingSeat(party, player.UserId, true)
	local away = findAway(party, player.UserId)
	if away then
		reviveRecord(party, away, player) -- S19b: 코드 합류 · 도착 · 수락으로 돌아온 사람이 유예 중이던 그 사람이면 새 기록을 만들지 않고 자리를 되찾는다
		return away
	end
	local record = { player = player, name = player.Name, userId = player.UserId, isDummy = false, joinedAt = now() }
	table.insert(party.members, record)
	partyOf[player] = party
	PartyState.pushState(party)
	print(("[forge-game] 파티 합류: #%d %s (%d/%d)"):format(party.id, player.Name, #party.members, PartyConfig.maxMembers))
	fireChanged(party, "join")
	return record
end

function PartyState.hasPendingInvite(player)
	return invites[player] ~= nil
end

function PartyState.getPendingInviteParty(player)
	local invite = invites[player]
	return invite and invite.party
end

-- 탈퇴(자발·퇴장·견습 진입 전부). reason은 리스너용 - "leave"/"disconnect"/"tutorial"/"kick".
function PartyState.leave(player, reason)
	cancelInvite(player)
	local party = partyOf[player]
	if not party then
		return false
	end
	local record = recordOf(party, player)
	print(("[forge-game] 파티 이탈: #%d %s (%s)"):format(party.id, player.Name, reason or "leave"))
	removeRecord(party, record, reason or "leave")
	return true
end

-- S19b: 끊긴 순간의 직업 · 레벨 · 스테이지(Player Attribute - 유예 중에는 Player가 없어 클라가 못 읽는다). 스탠드인(검증용 테이블)에는 없다.
local function readLast(player)
	if typeof(player) ~= "Instance" then
		return nil
	end
	return {
		classId = player:GetAttribute("ClassId"),
		level = player:GetAttribute("CharacterLevel"),
		rebirth = player:GetAttribute("RebirthCount"),
		stage = player:GetAttribute("InfiniteStage"),
		displayName = player.DisplayName,
	}
end

-- S19b 연결 끊김(PlayerRemoving). 접속 중인 다른 실제 멤버가 있으면 바로 탈퇴시키지 않고 유예(graceSeconds - 기본 PartyConfig.disconnectGraceSeconds)를 준다:
-- 그 사이 파티 목록에는 "연결 끊김 m:ss"로 남고(파티장은 추방할 수 있다), 같은 사람이 다시 접속하면 복귀(reclaim · attachMember), 시간이 지나면 자동 탈퇴한다.
-- 유예를 못 주는 경우(파티 없음 · 유예 0 · 남은 접속자 없음 - 혼자 남거나 전원이 끊김)는 옛 동작 그대로 즉시 탈퇴(leave). 반환: true = 파티에서 빠졌거나 유예가 시작됨.
-- 리스너(onMemberRemoved)에는 "disconnect"로 즉시 알린다 - 보스전에서 빠지고(BossEncounter) 진행 중이던 투표가 취소된다(PartyVote). 보스 HP 배수는 입장 순간 고정이라 안 바뀐다.
function PartyState.disconnect(player, graceSeconds)
	graceSeconds = graceSeconds or PartyConfig.disconnectGraceSeconds
	local party = partyOf[player]
	local hasOtherConnected = false
	if party then
		for _, other in ipairs(party.members) do
			if other.player and other.player ~= player then
				hasOtherConnected = true
				break
			end
		end
	end
	if not party or graceSeconds <= 0 or not hasOtherConnected then
		return PartyState.leave(player, "disconnect")
	end

	cancelInvite(player)
	local record = recordOf(party, player)
	record.awayUntil = os.time() + graceSeconds
	record.last = readLast(player)
	local token = {}
	record.awayToken = token
	record.player = nil
	partyOf[player] = nil
	print(("[forge-game] 파티 연결 끊김: #%d %s (유예 %d초)"):format(party.id, record.name, graceSeconds))
	fireRemoved(player, party, "disconnect")
	if party.leader == record then
		for _, candidate in ipairs(party.members) do
			if candidate.player then
				party.leader = candidate
				print(("[forge-game] 파티 리더 승계: #%d -> %s"):format(party.id, candidate.name))
				break
			end
		end
	end
	PartyState.pushState(party)
	fireChanged(party, "away", record)
	task.delay(graceSeconds, function()
		-- 그 사이 복귀 · 추방 · 해산이 있었으면(토큰이 지워졌거나 기록이 members에 없다) 아무것도 안 한다.
		if record.awayToken == token and table.find(party.members, record) then
			print(("[forge-game] 파티 유예 만료 - 자동 탈퇴: #%d %s"):format(party.id, record.name))
			removeRecord(party, record, "grace")
		end
	end)
	return true
end

-- S19b: 새로 접속한 Player가 어느 파티의 유예 중인 멤버였으면 그 파티로 복귀시킨다(같은 서버로 돌아온 경우 - PartyCrossServer가 프로필 로드 뒤에 부른다). 다른 서버로 접속했으면
-- 이 서버에는 그 파티가 없어 못 찾는다 - 그 경우는 PartyCrossServer가 재접속 표식(memberMap)을 읽어 복귀 초대를 띄운다. 반환: true, party | false.
function PartyState.reclaim(player)
	for _, party in pairs(parties) do
		local record = findAway(party, player.UserId)
		if record then
			reviveRecord(party, record, player)
			return true, party
		end
	end
	return false
end

function PartyState.kick(leader, targetUserId)
	local party = partyOf[leader]
	if not party or party.leader.player ~= leader then
		return false, "not_leader"
	end
	for _, record in ipairs(party.members) do
		if record.userId == targetUserId and record ~= party.leader then
			print(("[forge-game] 파티 추방: #%d %s"):format(party.id, record.name))
			if record.player then
				PartyState.notify(record.player, "파티에서 추방되었습니다")
			end
			removeRecord(party, record, "kick")
			return true
		end
	end
	return false, "not_member"
end

-- ═══ 더미 멤버(DevTools 검증 전용) ═══
-- Player가 없는 가짜 멤버 n명을 붙인다. 파티가 없으면 이 플레이어를 리더로 새로 만든다.
-- 더미는 실제 플레이어 수에 안 들어가므로(getMemberPlayers) 혼자+더미 파티는 해산 규칙
-- (실제 1명 이하 → 해산)의 예외로 둔다 - removeRecord가 아니라 여기서만 직접 관리한다.
function PartyState.addDummies(player, count, template)
	local party = partyOf[player]
	if party and party.leader.player ~= player then
		return false, "not_leader"
	end
	if not party then
		party = createParty(player)
	end
	local added = 0
	while added < count and PartyState.getSeatCount(party) < PartyConfig.maxMembers do
		local index = party.nextDummyIndex
		party.nextDummyIndex += 1
		table.insert(party.members, {
			player = nil,
			name = ("더미%d"):format(index),
			userId = -index,
			isDummy = true,
			joinedAt = now(),
			dummy = template(index),
		})
		added += 1
	end
	PartyState.pushState(party)
	fireChanged(party, "join")
	return true, added
end

function PartyState.clearDummies(player)
	local party = partyOf[player]
	if not party then
		return 0
	end
	local removed = 0
	for i = #party.members, 1, -1 do
		if party.members[i].isDummy then
			table.remove(party.members, i)
			removed += 1
		end
	end
	if #party.members <= 1 then
		-- 더미를 걷어내고 1명만 남으면 해산(더미가 없었다면 애초에 못 서 있는 파티).
		for _, remaining in ipairs(table.clone(party.members)) do
			removeRecord(party, remaining, "disband")
		end
		party.pending = {}
		parties[party.id] = nil
		fireChanged(party, "disband")
	else
		PartyState.pushState(party)
		fireChanged(party, "leave")
	end
	return removed
end

Players.PlayerRemoving:Connect(function(player)
	PartyState.disconnect(player)
	lastActivityAt[player] = nil
end)

return PartyState
