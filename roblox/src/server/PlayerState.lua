-- 플레이어 런타임 HP 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다 - MonsterState와
-- 같은 이유(devforum: Humanoid.Health는 내부적으로 32비트 float라 정밀도 문제가 있고,
-- 우리 시스템은 나중에 bignum{m,e}까지 가야 한다). Humanoid.Health는 죽었다는 신호를
-- 로블록스 엔진(리스폰 처리)에 보내는 용도로만 쓴다 - 실제 HP 판정은 여기서만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local PlayerState = {}

-- [Player] = { hp, maxHp, lastCombatActionAt(17-1 도입, 19-1에서 의미 확장 - 자동회복
-- 5초 대기 타이머 기준 시각, os.clock()), incomingDamageMultiplier·incomingDamageMultiplierUntil
-- (20-2a, 대검 E "받는 피해 50% 감소" - os.clock() 기준 만료 시각), channelingUntil(21-1,
-- 채널링 스킬 진행 중 - 이 시각 전엔 평타 요청을 거부한다) }
local players = {}

function PlayerState.init(player)
	players[player] = {
		hp = CombatConfig.playerMaxHp,
		maxHp = CombatConfig.playerMaxHp,
		lastCombatActionAt = nil,
		incomingDamageMultiplier = 1,
		incomingDamageMultiplierUntil = nil,
		channelingUntil = nil,
	}
end

-- 캐릭터가 (리)스폰될 때 호출한다. 죽었다가 살아난 것도, 첫 입장도 항상 풀피로 시작한다.
function PlayerState.reset(player)
	local entry = players[player]
	if entry then
		entry.hp = entry.maxHp
	end
	PlayerState.clearChanneling(player)
end

-- 채널링 중 평타 차단(21-1 [1]-C). PRD-forge-game.md 4.3 "채널링 3초는 평타 시간에서
-- 뺀다"가 명세이고, 20-7까지의 코드는 채널링 중에도 AttackRequest를 그대로 받아
-- 대가 없이 계수 프리미엄(0.15×(1-channelMoveSpeedMultiplier))만 받고 있었다 - 명세대로
-- 고친다. 채널형 스킬(SkillServer castCircleChannel/castSingleChannel)이 시작할 때
-- 부르고, AttackServer가 매 요청마다 isChanneling으로 거부한다. 클라(AttackInput.client.lua)는
-- 서버 전용인 이 모듈을 못 읽으니 Attribute "IsChanneling"으로 같은 사실을 알린다
-- (BuffState의 AttackSpeedBuffMultiplier와 같은 이유) - 클라 쪽은 스윙 모션·요청 자체를
-- 안 보내는 UX 1차 방어일 뿐, 판정은 언제나 서버다.
function PlayerState.setChannelingUntil(player, durationSeconds)
	local entry = players[player]
	if not entry then
		return
	end
	local untilAt = os.clock() + durationSeconds
	entry.channelingUntil = untilAt
	player:SetAttribute("IsChanneling", true)
	-- 만료 시각에 Attribute를 내린다 - 그 사이 새 채널링이 시작돼 untilAt이 바뀌었으면
	-- 그쪽 task.delay가 맡는다(BuffState의 "아무도 안 치워서 남는 유령 상태" 방지와 같은 원칙).
	task.delay(durationSeconds, function()
		if entry.channelingUntil == untilAt then
			PlayerState.clearChanneling(player)
		end
	end)
end

-- 채널링이 도중에 끊겼을 때(캐스터 사망·퇴장, 리스폰) 즉시 내린다.
function PlayerState.clearChanneling(player)
	local entry = players[player]
	if entry then
		entry.channelingUntil = nil
	end
	if player.Parent then
		player:SetAttribute("IsChanneling", false)
	end
end

function PlayerState.isChanneling(player)
	local entry = players[player]
	return entry ~= nil and entry.channelingUntil ~= nil and os.clock() < entry.channelingUntil
end

function PlayerState.getHp(player)
	local entry = players[player]
	return entry and entry.hp
end

function PlayerState.getMaxHp(player)
	local entry = players[player]
	return entry and entry.maxHp
end

function PlayerState.setHp(player, value)
	local entry = players[player]
	if entry then
		entry.hp = value
	end
end

-- 갑옷 장착/해제·로드 직후마다 호출한다(17-1, PlayerProfile.refreshMaxHp). 최대체력이
-- 늘어도 현재 체력을 자동으로 채우지 않는다 - 자동회복(PlayerRegen.server.lua)이 곧 채운다.
-- 줄어드는 경우(장비 해제)엔 현재 체력을 새 상한으로 clamp만 한다 - 장비를 벗었다고
-- 즉사하면 안 된다.
function PlayerState.setMaxHp(player, newMaxHp)
	local entry = players[player]
	if not entry then
		return
	end
	entry.maxHp = newMaxHp
	entry.hp = math.min(entry.hp, entry.maxHp)
end

function PlayerState.getLastCombatActionAt(player)
	local entry = players[player]
	return entry and entry.lastCombatActionAt
end

-- 피격마다(MonsterAI.server.lua의 applyHitToPlayer) + 공격을 시도할 때마다(AttackServer.
-- server.lua, 헛스윙 포함) 호출한다 - 자동회복의 "전투 없이 5초" 타이머 기준점이다(19-1
-- 전엔 피격만 봤다 - 공격 중에도 회복되는 게 이상하다는 지적으로 범위를 넓혔다,
-- PRD-forge-game-roblox.md 20.36 참고).
function PlayerState.setLastCombatActionAt(player, value)
	local entry = players[player]
	if entry then
		entry.lastCombatActionAt = value
	end
end

-- 받는 피해 배율을 durationSeconds 동안 걸어 둔다(20-2a, PRD-forge-game.md 4.3 대검
-- 회전베기 "받는 피해 50% 감소"). 만료 시각을 넘기면 getIncomingDamageMultiplier가
-- 자동으로 1(정상)을 돌려준다 - 별도 해제 호출이 필요 없다(타이머 정리를 깜빡할 일이 없다).
function PlayerState.setIncomingDamageMultiplierUntil(player, multiplier, durationSeconds)
	local entry = players[player]
	if not entry then
		return
	end
	entry.incomingDamageMultiplier = multiplier
	entry.incomingDamageMultiplierUntil = os.clock() + durationSeconds
end

-- MonsterAI.server.lua의 applyHitToPlayer가 매 피격마다 곱한다. 활성 구간이 아니면 1.
function PlayerState.getIncomingDamageMultiplier(player)
	local entry = players[player]
	if not entry or not entry.incomingDamageMultiplierUntil then
		return 1
	end
	if os.clock() >= entry.incomingDamageMultiplierUntil then
		return 1
	end
	return entry.incomingDamageMultiplier
end

function PlayerState.clear(player)
	players[player] = nil
end

return PlayerState
