-- BR1-3 플레이어 기절(BossData.mechanics.stun - 강화 평타의 onHit "stun"). 기절 = seconds 동안 루트 고정(PlayerState 출처 "stun") + 속성 BossStunned(클라가 머리 위 별을 그린다).
-- 기절이 풀린 뒤 immuneSeconds 동안은 다시 기절하지 않는다(연속 기절 방지). 같은 면역을 대공 잡기의 얼림도 본다(BossAirGrab) · 잡힘(BossTrap)이 풀려도 면역이 붙는다.
-- 무적(복귀 보호 · 해제 유예 · 회오리) · 잡힌 사람 · 죽은 사람은 기절하지 않는다(피해가 안 들어간 타격은 기절도 없다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PlayerState = require(script.Parent.PlayerState)
local BossTrap = require(script.Parent.BossTrap)

local PlayerStun = {}

local CONFIG = BossData.mechanics.stun
local stunnedUntil = setmetatable({}, { __mode = "k" })
local immuneUntil = setmetatable({}, { __mode = "k" })

local function realPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

function PlayerStun.isStunned(player)
	return (stunnedUntil[player] or 0) > os.clock()
end

-- 기절 중이거나 풀린 뒤 면역 창 안이면 true.
function PlayerStun.isImmune(player)
	local now = os.clock()
	return (stunnedUntil[player] or 0) > now or (immuneUntil[player] or 0) > now
end

function PlayerStun.grantImmunity(player, seconds)
	immuneUntil[player] = math.max(immuneUntil[player] or 0, os.clock() + (seconds or CONFIG.immuneSeconds))
end

-- 반환: 기절했는가.
function PlayerStun.stun(player, seconds)
	if PlayerStun.isImmune(player) or BossTrap.isTrapped(player) or PlayerState.isInvulnerable(player) or (PlayerState.getHp(player) or 0) <= 0 then
		return false
	end
	local now = os.clock()
	local endsAt = now + seconds
	stunnedUntil[player] = endsAt
	immuneUntil[player] = endsAt + CONFIG.immuneSeconds
	if realPlayer(player) then
		PlayerState.setAnchorHold(player, "stun", true)
		player:SetAttribute("BossStunned", true)
	end
	task.delay(seconds, function()
		if stunnedUntil[player] == endsAt then
			stunnedUntil[player] = nil
			if realPlayer(player) then
				PlayerState.setAnchorHold(player, "stun", false)
				player:SetAttribute("BossStunned", nil)
			end
		end
	end)
	print(("[forge-game] 기절: %s - %.2f초(뒤 면역 %.1f초)"):format(tostring(player.Name), seconds, CONFIG.immuneSeconds))
	return true
end

-- 잡힘(얼음 · 손 · 가둠 · 무덤 …)이 풀리면 기절 면역 - "잡힘 → 곧바로 기절"을 막는다.
BossTrap.onReleased(function(player)
	PlayerStun.grantImmunity(player)
end)

return PlayerStun
