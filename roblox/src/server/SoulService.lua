-- QUEUE-10h Q8 K3 영혼 상태(서버 판정 - 규칙 = shared/data/SoulData.lua 머리). 상태 = 서버 표 + Player Attribute SoulState(클라 모습 · 화면용).
--   BossEncounter가 사망(onDied) · 리스폰(consumePending) · 전멸/끝(clearEncounter · clearPlayer) · 재접속(noteDisconnect · takeRejoin)을 부른다.
--   공격 · 스킬 · 줍기 · 피해 입구는 isSoul로 막는다(AttackServer · SkillServer · ItemDropServer · PlayerDamage).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SoulData = require(ReplicatedStorage.Shared.data.SoulData)
local PlayerState = require(script.Parent.PlayerState)

local SoulService = {}

local souls = {} -- [Player] = { encounter, diedAt, deathPos }
local pending = {} -- [Player] = { encounter, diedAt, deathPos } - 죽었고 리스폰을 기다리는 중
local disconnected = {} -- [userId] = { encounter, at, oldPlayer }
local lastReject = {}

function SoulService.isSoul(player)
	return souls[player] ~= nil
end

function SoulService.soulsOf(encounter)
	local list = {}
	for player, s in pairs(souls) do
		if s.encounter == encounter then
			table.insert(list, player)
		end
	end
	return list
end

-- 보스전 사망 순간(BossEncounter Humanoid.Died): 영혼 대기로 적어 둔다(전멸이면 곧 clearEncounter가 지운다)
function SoulService.onDied(player, encounter, position)
	if not SoulData.enabled or not encounter or encounter.isTutorial or encounter.lingering or not encounter.model then -- 잔류(처치 뒤) 창 사망 = 영혼 아님
		return
	end
	pending[player] = { encounter = encounter, diedAt = os.clock(), deathPos = position }
end

-- 리스폰(CharacterAdded - 아레나로 옮긴 뒤): 대기 중이면 영혼이 된다. 반환 = 영혼이 됐는가
function SoulService.consumePending(player, encounter)
	local p = pending[player]
	pending[player] = nil
	if not p or p.encounter ~= encounter then
		return false
	end
	if p.reviveOnSpawn then -- 리스폰 대기 중에 성역이 끝났다 = 영혼 대신 부활 체력으로 선다
		local maxHp = PlayerState.getMaxHp(player)
		if maxHp then
			PlayerState.setHp(player, math.max(1, maxHp * SoulData.reviveHpFraction))
			require(script.Parent.PlayerDamage).syncHud(player)
		end
		print(("[K3] 부활: %s(%s) - 체력 %.0f%%"):format(tostring(player.Name), p.reviveOnSpawn, SoulData.reviveHpFraction * 100))
		return false
	end
	souls[player] = p
	if typeof(player) == "Instance" then
		player:SetAttribute("SoulState", true)
	end
	print(("[K3] 영혼: %s(보스전 %s)"):format(tostring(player.Name), tostring(encounter.id)))
	return true
end

local function release(player)
	souls[player] = nil
	pending[player] = nil
	if typeof(player) == "Instance" and player.Parent then
		player:SetAttribute("SoulState", nil)
	end
end

-- 부활(성역 · 기도 · 개발 명령): 영혼을 풀고 체력 = reviveHpFraction
function SoulService.revive(player, reason)
	if not souls[player] then
		return false
	end
	release(player)
	local maxHp = PlayerState.getMaxHp(player)
	if maxHp then
		PlayerState.setHp(player, math.max(1, maxHp * SoulData.reviveHpFraction))
		require(script.Parent.PlayerDamage).syncHud(player)
	end
	print(("[K3] 부활: %s(%s) - 체력 %.0f%%"):format(tostring(player.Name), tostring(reason), SoulData.reviveHpFraction * 100))
	return true
end

-- 성역 끝: 시전자의 보스전에서 그 성역 안 · 성역 동안 죽은 사람만(sanctuary = { center, radius, startedAt }) - 영혼은 바로 부활 · 리스폰 대기(pending)는 리스폰 때 부활
function SoulService.reviveSanctuary(sanctuary, encounter)
	local function inside(s)
		local p = s.deathPos
		return encounter ~= nil and s.encounter == encounter and p ~= nil and s.diedAt >= (sanctuary.startedAt or 0)
			and (Vector3.new(p.X - sanctuary.center.X, 0, p.Z - sanctuary.center.Z)).Magnitude <= sanctuary.radius
	end
	local n = 0
	for player, s in pairs(souls) do
		if inside(s) and SoulService.revive(player, "성역") then
			n += 1
		end
	end
	for _, p in pairs(pending) do
		if inside(p) then
			p.reviveOnSpawn = "성역"
			n += 1
		end
	end
	return n
end

-- 전멸 · 보스전 끝: 이 보스전의 영혼 · 대기 전부 풀기(전원 복귀)
function SoulService.clearEncounter(encounter)
	for player, s in pairs(souls) do
		if s.encounter == encounter then
			release(player)
		end
	end
	for player, p in pairs(pending) do
		if p.encounter == encounter then
			pending[player] = nil
		end
	end
end

function SoulService.clearPlayer(player)
	release(player)
end

-- 공격 · 스킬 요청 거부(영혼) - 로그는 사람당 초당 1줄. 반환 = 막았는가
function SoulService.rejectAction(player, what)
	if not souls[player] then
		return false
	end
	local now = os.clock()
	if not lastReject[player] or now - lastReject[player] >= SoulData.rejectLogSeconds then
		lastReject[player] = now
		print(("[K3] 영혼 %s 거부: %s"):format(tostring(what), tostring(player.Name)))
	end
	return true
end

-- 튕김: 보스전이 이어지는 동안 다시 들어오면 영혼으로 관전 복귀(BossEncounter.rejoin이 takeRejoin을 읽는다)
function SoulService.noteDisconnect(player, encounter)
	if not SoulData.enabled or not encounter or encounter.isTutorial then
		return
	end
	disconnected[player.UserId] = { encounter = encounter, at = os.clock(), oldPlayer = player }
	print(("[K3] 튕김 기록: %s - %d초 안에 다시 들어오면 영혼으로 관전 복귀"):format(tostring(player.Name), SoulData.reconnectGraceSeconds))
	release(player)
	lastReject[player] = nil
end

function SoulService.takeRejoin(player)
	local rec = disconnected[player.UserId]
	disconnected[player.UserId] = nil
	if not rec or os.clock() - rec.at > SoulData.reconnectGraceSeconds then
		return nil
	end
	return rec
end

return SoulService
