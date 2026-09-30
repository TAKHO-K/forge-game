-- A2-N4 §4-4 파티 모집 1단계(같은 서버 게시판 · 태그 선택식 - 자유 글 없음 · 빠른 참가). 데이터 = PartyConfig.board.
--   글 올리기(post): 리더(또는 솔로 - 파티를 만든다 = PartyState.create) · 태그 = 스테이지(올린 사람의 지금 무한 스테이지 - 서버가 채운다) · 역할(board.roles 번호) · 목표 인원(board.sizes 번호).
--   빠른 참가(join): 글 주인 파티에 바로 붙는다 - 금지 조건은 초대 · 수락과 같은 공통 입구(PartyJoinRules.checkJoinable · 보스전 · 합류 중) 뒤 PartyState.attachMember(코드 합류와 같은 마지막 단계).
--   글은 파티가 목표 인원에 닿거나 · 사라지거나 · 주인이 리더가 아니게 되거나 · 수명(ttlSeconds)이 지나면 지운다. 게시판 목록은 바뀔 때 모두에게 보낸다(PartyBoardSync).
--   서버 간 매칭은 설계만(docs/design/party-board.md).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PartyState = require(script.Parent.PartyState)
local PartyJoinRules = require(script.Parent.PartyJoinRules)
local PlayerProfile = require(script.Parent.PlayerProfile)

local PartyBoard = {}

local B = PartyConfig.board
local posts = {} -- [리더 UserId] = { leader = Player, stage, role(번호), size, createdAt }

local sync = Instance.new("RemoteEvent")
sync.Name = "PartyBoardSync"
sync.Parent = ReplicatedStorage

local function listFor()
	local list = {}
	for userId, p in pairs(posts) do
		local party = PartyState.getParty(p.leader)
		table.insert(list, {
			leaderUserId = userId, leaderName = p.leader.DisplayName, stage = p.stage, role = p.role, size = p.size,
			count = party and PartyState.getSize(party) or 1, classId = PlayerProfile.getClassId(p.leader),
		})
	end
	table.sort(list, function(a, b)
		return a.stage > b.stage
	end)
	return list
end

local function broadcast()
	sync:FireAllClients(listFor())
end

-- 살아 있는 글인가(아니면 지운다)
local function alive(p, now)
	if not p.leader.Parent or now - p.createdAt > B.ttlSeconds then
		return false
	end
	local party = PartyState.getParty(p.leader)
	if party and not PartyState.isLeader(p.leader) then
		return false
	end
	return not party or PartyState.getSize(party) < p.size
end

local function sweep()
	local now = os.clock()
	local changed = false
	for userId, p in pairs(posts) do
		if not alive(p, now) then
			posts[userId] = nil
			changed = true
		end
	end
	if changed then
		broadcast()
	end
end

-- 순수 태그 검사(요청 인자 = { role = 번호, size = 번호 } - 자유 글 없음)
function PartyBoard.validTags(arg)
	return type(arg) == "table" and type(arg.role) == "number" and type(arg.size) == "number" and B.roles[arg.role] ~= nil and B.sizes[arg.size] ~= nil
end

-- 반환: ok, 실패 이유(PartyServer REASON_TEXT 키 또는 board_* - 새 키는 TextData party.board.*)
function PartyBoard.post(player, arg)
	if not PartyBoard.validTags(arg) then
		return false, "board_bad_tags"
	end
	local party = PartyState.getParty(player)
	if party and not PartyState.isLeader(player) then
		return false, "not_leader"
	end
	if not party then
		local _, reason = PartyState.create(player)
		if reason then
			return false, reason
		end
	end
	posts[player.UserId] = { leader = player, stage = PlayerProfile.getInfiniteStage(player) or 1, role = arg.role, size = B.sizes[arg.size], createdAt = os.clock() }
	broadcast()
	return true
end

function PartyBoard.remove(player)
	if posts[player.UserId] then
		posts[player.UserId] = nil
		broadcast()
	end
	return true
end

-- blockers(선택) = PartyServer가 넘기는 보스전 · 합류 중 검사(순환 require를 피한다) - 이유 문자열 또는 nil
function PartyBoard.join(player, leaderUserId, blockers)
	local p = type(leaderUserId) == "number" and posts[leaderUserId]
	if not p or not alive(p, os.clock()) then
		sweep()
		return false, "board_gone"
	end
	if p.leader == player then
		return false, "self"
	end
	if PartyState.getParty(player) then
		return false, "already_in_party"
	end
	local blocked = (blockers and blockers(player)) or PartyJoinRules.checkJoinable(p.leader, player)
	if blocked then
		return false, blocked
	end
	local role, classId = B.roles[p.role], PlayerProfile.getClassId(player)
	if (role.classId and classId ~= role.classId) or (role.notClass and classId == role.notClass) then
		return false, "board_role"
	end
	local party = PartyState.getParty(p.leader)
	if not party or PartyState.getSeatCount(party) >= math.min(p.size, PartyConfig.maxMembers) then
		return false, "party_full"
	end
	PartyState.attachMember(party, player)
	sweep()
	broadcast()
	return true
end

function PartyBoard.snapshot()
	return listFor()
end

Players.PlayerAdded:Connect(function(player)
	task.delay(3, function()
		if player.Parent then
			sync:FireClient(player, listFor())
		end
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	if posts[player.UserId] then
		posts[player.UserId] = nil
		task.defer(broadcast)
	end
end)
task.spawn(function()
	while true do
		task.wait(B.sweepSeconds)
		sweep()
	end
end)

return PartyBoard
