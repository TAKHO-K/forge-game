-- 플레이어 런타임 HP 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다 - MonsterState와
-- 같은 이유(devforum: Humanoid.Health는 내부적으로 32비트 float라 정밀도 문제가 있고,
-- 우리 시스템은 나중에 bignum{m,e}까지 가야 한다). Humanoid.Health는 죽었다는 신호를
-- 로블록스 엔진(리스폰 처리)에 보내는 용도로만 쓴다 - 실제 HP 판정은 여기서만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)

local PlayerState = {}

-- [Player] = { hp, maxHp }
local players = {}

function PlayerState.init(player)
	players[player] = {
		hp = CombatConfig.playerMaxHp,
		maxHp = CombatConfig.playerMaxHp,
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

function PlayerState.clear(player)
	players[player] = nil
end

return PlayerState
