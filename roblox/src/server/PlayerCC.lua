-- BOSS-NIGHT-3 2단계 CC(docs/design/boss-bible/CC-DEFS.md · 값 = BossData.mechanics.cc). 기절은 PlayerStun 그대로 - 여기는 경직 · 넉백/띄움 면역 · 둔화 · 수정 표식.
--   경직 = 걷기 배율 0(출처 "stagger") - 루트 고정(Anchor) 없음 · 대시 됨 · 경직 면역은 기절과 따로.
--   둔화 = 걷기 배율 × walkMultiplier(출처 "slow") - 대시 거리는 이속 보너스만 보므로(DashServer) 안 줄어든다.
--   상태 Attribute(플레이어) = Status<이름>Until(서버 시계 workspace:GetServerTimeNow 기준 끝 시각) - StatusIconData가 읽는 이름.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PlayerState = require(script.Parent.PlayerState)

local PlayerCC = {}

local CC = BossData.mechanics.cc
local staggerImmuneUntil = setmetatable({}, { __mode = "k" })
local launchImmune = setmetatable({}, { __mode = "k" }) -- [player] = { untilAt, airborne }
local airborneDashAt = setmetatable({}, { __mode = "k" })
local marks = setmetatable({}, { __mode = "k" }) -- [player] = { bossId, untilAt }

local function realPlayer(player)
	return typeof(player) == "Instance" and player:IsA("Player")
end

local function setStatus(player, name, seconds)
	if realPlayer(player) then
		player:SetAttribute("Status" .. name .. "Until", workspace:GetServerTimeNow() + seconds)
	end
end

local function refreshSpeed(player)
	if realPlayer(player) then
		require(script.Parent.PlayerProfile).refreshMovementSpeed(player)
	end
end

local function blocked(player)
	return require(script.Parent.BossTrap).isTrapped(player) or PlayerState.isInvulnerable(player) or (PlayerState.getHp(player) or 0) <= 0
		or (realPlayer(player) and require(script.Parent.UltimateService).isUnstoppable(player))
end

-- 경직(보스 평타 · 수정 미사일 마지막 발). 반환 = 걸렸는가.
function PlayerCC.stagger(player)
	local now = os.clock()
	if (staggerImmuneUntil[player] or 0) > now or blocked(player) then
		return false
	end
	local s = CC.stagger
	staggerImmuneUntil[player] = now + s.seconds + s.immuneSeconds
	PlayerState.setMoveSpeedMultiplier(player, "stagger", 0, s.seconds, refreshSpeed)
	refreshSpeed(player)
	setStatus(player, "Stagger", s.seconds)
	return true
end

function PlayerCC.isAirborneHeight(heightStuds)
	return heightStuds >= CC.airborneMinHeightStuds
end

-- 넉백/띄움 한 번(runHitEffects launch 분기 · BossPatterns.launchPlayer 두 입구). airSeconds = 체공 + 붙잡힘(면역은 그 뒤부터).
-- escape(잡기 던짐) = 면역 검사 없이 기록만. 반환 = 띄워도 되는가.
function PlayerCC.tryLaunch(player, heightStuds, airSeconds, escape)
	local now = os.clock()
	local airborne = PlayerCC.isAirborneHeight(heightStuds)
	local imm = launchImmune[player]
	if not escape and imm and imm.untilAt > now and (imm.airborne or not airborne) then
		return false
	end
	local kind = airborne and CC.airborne or CC.knockback
	launchImmune[player] = { untilAt = now + (airSeconds or 0) + kind.immuneSeconds, airborne = airborne }
	setStatus(player, airborne and "Airborne" or "Knockback", airSeconds or 0)
	if airborne then
		airborneDashAt[player] = now + CC.airborne.dashAfterSeconds
		if realPlayer(player) then
			player:SetAttribute("CCDashAt", workspace:GetServerTimeNow() + CC.airborne.dashAfterSeconds) -- 클라 DashInput이 같은 조건으로 거른다
		end
	end
	return true
end

-- 대시 거절 이유(DashServer · 클라도 같은 조건): 기절 중 = "stunned" · 띄워진 직후 = "launched".
function PlayerCC.dashBlockedReason(player)
	if require(script.Parent.PlayerStun).isStunned(player) then
		return "stunned"
	end
	if (airborneDashAt[player] or 0) > os.clock() then
		return "launched"
	end
	return nil
end

function PlayerCC.slow(player)
	if blocked(player) then
		return false
	end
	local s = CC.slow
	PlayerState.setMoveSpeedMultiplier(player, "slow", s.walkMultiplier, s.seconds, refreshSpeed) -- 새로 고침만(같은 키 덮어쓰기)
	refreshSpeed(player)
	setStatus(player, "Slow", s.seconds)
	return true
end

-- 수정 표식: bossId가 주는 피해 × multiplier. 새로 고침만(겹치지 않음).
function PlayerCC.crystalMark(player, bossId)
	if (PlayerState.getHp(player) or 0) <= 0 then
		return false
	end
	local s = CC.crystalMark
	marks[player] = { bossId = bossId, untilAt = os.clock() + s.seconds }
	setStatus(player, "CrystalMark", s.seconds)
	return true
end

function PlayerCC.markMultiplier(player, bossId)
	local m = marks[player]
	if m and bossId and m.bossId == bossId and m.untilAt > os.clock() then
		return CC.crystalMark.multiplier
	end
	return 1
end

function PlayerCC.clear(player)
	staggerImmuneUntil[player], launchImmune[player], airborneDashAt[player], marks[player] = nil, nil, nil, nil
end

return PlayerCC
