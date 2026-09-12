-- 플레이어 런타임 HP 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다 - MonsterState와
-- 같은 이유(devforum: Humanoid.Health는 내부적으로 32비트 float라 정밀도 문제가 있고,
-- 우리 시스템은 나중에 bignum{m,e}까지 가야 한다). Humanoid.Health는 죽었다는 신호를
-- 로블록스 엔진(리스폰 처리)에 보내는 용도로만 쓴다 - 실제 HP 판정은 여기서만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local PlayerState = {}

-- [Player] = { hp, maxHp, lastHitAt(17-1, 자동회복 5초 대기 타이머 기준 시각, os.clock()) }
local players = {}

function PlayerState.init(player)
	players[player] = {
		hp = CombatConfig.playerMaxHp,
		maxHp = CombatConfig.playerMaxHp,
		lastHitAt = nil,
	}
end

-- 캐릭터가 (리)스폰될 때 호출한다. 죽었다가 살아난 것도, 첫 입장도 항상 풀피로 시작한다.
function PlayerState.reset(player)
	local entry = players[player]
	if entry then
		entry.hp = entry.maxHp
	end
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

function PlayerState.getLastHitAt(player)
	local entry = players[player]
	return entry and entry.lastHitAt
end

-- 피격마다 호출한다(MonsterAI.server.lua의 applyHitToPlayer) - 자동회복의 "마지막 피격
-- 후 5초" 타이머 기준점이다.
function PlayerState.setLastHitAt(player, value)
	local entry = players[player]
	if entry then
		entry.lastHitAt = value
	end
end

function PlayerState.clear(player)
	players[player] = nil
end

return PlayerState
