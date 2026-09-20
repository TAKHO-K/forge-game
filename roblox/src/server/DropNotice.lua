-- 파티원 드랍 알림(30-0 S10, PRD 20.73 [5-3]) - 유물 · 고대 · 태초 장비가 굴려진 순간 같은 파티(태초는 같은 서버 전원)에게 "누가 무엇을 얻었다"를 보낸다.
-- 서버는 판정과 수신자 결정만 한다. 어디에 어떻게 그리는지(피드 · 배너 · 채팅 줄)는 클라(client/hud/DropFeed.client.lua)다.
-- publish는 CombatResolution.grantKillReward에서만 부른다 - 견습의 확정 지급 · 대여(TutorialState) · 분해로 나온 보석 · 상점 구매가 자동으로 빠지는 이유다.
-- 다른 서버로는 안 보낸다(MessagingService 없음) - 같은 로블록스 서버 인스턴스 안의 Player에게만.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local PartyState = require(script.Parent.PartyState)

local DropNotice = {}

local remote = Instance.new("RemoteEvent")
remote.Name = "DropNotice"
remote.Parent = ReplicatedStorage

-- 검증용 카운터(CombatResolution.dropStats와 같은 결): 부른 횟수 · 파티로 보낸 횟수 · 서버 전체로 보낸 횟수.
local stats = { calls = 0, party = 0, server = 0 }

function DropNotice.stats()
	return stats.calls, stats.party, stats.server
end

-- 순수 함수: 이 등급의 드랍이 (파티 여부에 따라) 누구에게 가는가. "server" · "party" · nil(안 보냄).
function DropNotice.scopeFor(grade, inParty)
	if DropNoticeData.serverWideGrades[grade] then
		return "server"
	end
	if inParty and DropNoticeData.partyGrades[grade] then
		return "party"
	end
	return nil
end

-- 클라로 가는 내용. 이름 · 등급 · 부위 · itemLevel(+ 어디까지 알리는지)만 싣는다 - 옵션 · 능력치는 싣지 않는다(PRD 20.73 [5-3] 전송).
function DropNotice.buildPayload(name, item, scope)
	return { name = name, grade = item.grade, part = item.part, itemLevel = item.itemLevel, scope = scope }
end

-- 실제 Player 인스턴스에만 보낸다(더미 · 검증 스탠드인은 Player가 아니라 FireClient 대상이 될 수 없다).
local function isRealPlayer(candidate)
	return typeof(candidate) == "Instance" and candidate:IsA("Player") and candidate.Parent ~= nil
end

-- 수신자 목록. 파티: 같은 서버의 파티 멤버 전원(본인 포함 - 파티 기록에서 빠져 있어도 본인은 넣는다). 서버 전체: 접속한 전원.
local function recipientsFor(scope, recipient, party)
	local list, seen = {}, {}
	local function add(candidate)
		if isRealPlayer(candidate) and not seen[candidate] then
			seen[candidate] = true
			table.insert(list, candidate)
		end
	end
	if scope == "server" then
		for _, player in ipairs(Players:GetPlayers()) do
			add(player)
		end
	else
		add(recipient)
		for _, member in ipairs(PartyState.getMemberPlayers(party)) do
			add(member)
		end
	end
	return list
end

-- 굴려진 아이템 하나를 알린다. item = 방금 굴려진 장비. nameOverride · forceScope는 DevTools(/gg dropnotice)만 쓴다(솔로여도 자기 화면에 띄워 보려고 "party"로 강제).
-- 돌려주는 값: scope("server" · "party" · nil), 실제로 보낸 Player 목록(검증이 읽는다).
function DropNotice.publish(recipient, item, nameOverride, forceScope)
	stats.calls += 1
	local party = PartyState.getParty(recipient)
	local scope = DropNotice.scopeFor(item.grade, party ~= nil) or forceScope -- forceScope는 원래 안 나갈 때만 채운다(태초는 그대로 서버 전체)
	if not scope then
		return nil, {}
	end
	local payload = DropNotice.buildPayload(nameOverride or recipient.DisplayName, item, scope)
	local sent = recipientsFor(scope, recipient, party)
	for _, player in ipairs(sent) do
		remote:FireClient(player, payload)
	end
	stats[scope] += 1
	return scope, sent
end

return DropNotice
