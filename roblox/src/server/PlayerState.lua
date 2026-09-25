-- 플레이어 런타임 HP 단일 관리 통로. Humanoid.Health에 HP를 두지 않는다 - MonsterState와
-- 같은 이유(devforum: Humanoid.Health는 내부적으로 32비트 float라 정밀도 문제가 있고,
-- 우리 시스템은 나중에 bignum{m,e}까지 가야 한다). Humanoid.Health는 죽었다는 신호를
-- 로블록스 엔진(리스폰 처리)에 보내는 용도로만 쓴다 - 실제 HP 판정은 여기서만 한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerShield = require(script.Parent.PlayerShield)

local PlayerState = {}

-- [Player] = { hp, maxHp, lastCombatActionAt(17-1 도입, 19-1에서 의미 확장 - 자동회복
-- 5초 대기 타이머 기준 시각, os.clock()), incomingMultipliers·invulnerableUntil(P3d-F B6 - 출처별)
-- (20-2a, 대검 E "받는 피해 50% 감소" - os.clock() 기준 만료 시각), channelingUntil(21-1,
-- 채널링 스킬 진행 중 - 이 시각 전엔 평타 요청을 거부한다), lifestealTokens·
-- lifestealTokensUpdatedAt(26-2, 흡혈 초당 상한 토큰 버킷 - PlayerState.tryLifesteal) }
local players = {}

function PlayerState.init(player)
	players[player] = {
		hp = CombatConfig.playerMaxHp,
		maxHp = CombatConfig.playerMaxHp,
		lastCombatActionAt = nil,
		incomingMultipliers = nil, -- P3d-F B6: { [출처] = { multiplier, untilAt } } (아래 setIncomingDamageMultiplierUntil)
		invulnerableUntil = nil, -- P3d-F B6: { [출처] = untilAt } (setInvulnerableUntil)
		channelingUntil = nil,
		lifestealTokens = nil, -- 첫 사용 시 가득 찬 것으로 취급(아래 tryLifesteal)
		lifestealTokensUpdatedAt = nil,
	}
end

-- 캐릭터가 (리)스폰될 때 호출한다. 죽었다가 살아난 것도, 첫 입장도 항상 풀피로 시작한다.
function PlayerState.reset(player)
	local entry = players[player]
	if entry then
		entry.hp = entry.maxHp
		entry.trapDamageMultiplier = nil -- 29-1: 리스폰하면 잡힘도 풀린다(BossTrap이 기록도 같이 지운다)
		entry.anchorHolds = nil -- P3d-F: 새 캐릭터는 고정 없이 시작한다
		entry.moveSpeedMultipliers = nil -- P3d-F: 끊긴 채널링의 감속이 남지 않게
	end
	PlayerShield.clear(player) -- S13b: 리스폰하면 쉴드도 풀린다
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

-- S13b: HP를 **깎는** 곳은 PlayerDamage.takeDamage 하나뿐이다(쉴드 흡수 → HP 순서 - 여기서 직접 낮추면 쉴드를 우회한다). setHp는 회복(HealCast · PlayerRegen · 흡혈) · 복구 · 검증 세팅용이다.
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

-- 받는 피해 배율(20-2a, PRD-forge-game.md 4.3 대검 회전베기 "받는 피해 50% 감소").
-- P3d-F B6: 출처(sourceKey)마다 따로 둔다 - 옛 구조는 칸 하나를 대시 · 회전베기 · 복귀 보호 · 끼임 · 회오리 · 잡힘 유예가
-- 같이 써서, 한 출처의 설정이 다른 출처를 덮고(복귀 보호 0배가 회전베기 0.5배를 덮은 뒤 끝나면 남은 감소가 사라졌다) 해제가 남의 것을 지웠다.
-- 최종 배율 = 살아 있는 출처 배율의 곱. 완전 무적(0배)은 배율이 아니라 별도 플래그(setInvulnerableUntil)다. 만료 시각을 넘긴 출처는
-- 읽을 때 저절로 빠진다(해제 호출이 필요 없다) · 푸는 쪽은 자기 키만 지운다.
-- [Player] 칸: incomingMultipliers = { [sourceKey] = { multiplier, untilAt } } · invulnerableUntil = { [sourceKey] = untilAt }
function PlayerState.setIncomingDamageMultiplierUntil(player, multiplier, durationSeconds, sourceKey)
	assert(sourceKey, "setIncomingDamageMultiplierUntil: sourceKey가 필요하다(출처별 칸)")
	local entry = players[player]
	if not entry then
		return
	end
	entry.incomingMultipliers = entry.incomingMultipliers or {}
	local newUntil = os.clock() + durationSeconds
	-- 21-2: 같은 출처를 다시 걸 때 이미 같거나 더 강한 감소가 더 오래 살아 있으면 그대로 둔다(짧은 쪽이 긴 쪽의 만료를 당기지 않게).
	local existing = entry.incomingMultipliers[sourceKey]
	if existing and existing.untilAt > os.clock() and existing.multiplier <= multiplier and existing.untilAt >= newUntil then
		return
	end
	entry.incomingMultipliers[sourceKey] = { multiplier = multiplier, untilAt = newUntil }
end

-- 이 출처의 배율만 푼다(다른 출처는 그대로).
function PlayerState.clearIncomingDamageMultiplierSource(player, sourceKey)
	local entry = players[player]
	if entry and entry.incomingMultipliers then
		entry.incomingMultipliers[sourceKey] = nil
	end
end

-- 완전 무적(받는 피해 0) - 출처마다 따로. 같은 출처를 다시 걸면 더 늦은 만료를 남긴다.
function PlayerState.setInvulnerableUntil(player, durationSeconds, sourceKey)
	assert(sourceKey, "setInvulnerableUntil: sourceKey가 필요하다(출처별 칸)")
	local entry = players[player]
	if not entry then
		return
	end
	entry.invulnerableUntil = entry.invulnerableUntil or {}
	entry.invulnerableUntil[sourceKey] = math.max(entry.invulnerableUntil[sourceKey] or 0, os.clock() + durationSeconds)
end

function PlayerState.clearInvulnerable(player, sourceKey)
	local entry = players[player]
	if entry and entry.invulnerableUntil then
		entry.invulnerableUntil[sourceKey] = nil
	end
end

function PlayerState.isInvulnerable(player)
	local entry = players[player]
	local now = os.clock()
	for _, untilAt in pairs(entry and entry.invulnerableUntil or {}) do
		if untilAt > now then
			return true
		end
	end
	return false
end

-- P3c: 걸려 있는 받는 피해 배율 · 무적을 **전부** 바로 푼다(검증 블록이 앞 블록의 면역을 이어받지 않게 - P3b(나) D3의 0배 40초가 P3c(나)까지 남았다). 게임 코드는 출처별 해제를 쓴다.
function PlayerState.clearIncomingDamageMultiplier(player)
	local entry = players[player]
	if entry then
		entry.incomingMultipliers = nil
		entry.invulnerableUntil = nil
	end
end

-- 지금 살아 있는 출처 목록(검증 · 로그용): { [sourceKey] = 배율 } · 무적 출처는 배율 0으로 넣는다.
function PlayerState.debugIncomingSources(player)
	local entry = players[player]
	local now, list = os.clock(), {}
	for key, rec in pairs(entry and entry.incomingMultipliers or {}) do
		if rec.untilAt > now then
			list[key] = rec.multiplier
		end
	end
	for key, untilAt in pairs(entry and entry.invulnerableUntil or {}) do
		if untilAt > now then
			list[key] = 0
		end
	end
	return list
end

-- 모든 피격 경로의 마지막 공통 지점(PlayerDamage.applyFinalDamage)이 매 피격마다 곱한다. 무적이면 0, 아니면 살아 있는 출처 배율의 곱(없으면 1).
function PlayerState.getIncomingDamageMultiplier(player)
	local entry = players[player]
	if not entry then
		return 1
	end
	if PlayerState.isInvulnerable(player) then
		return 0
	end
	local now, product = os.clock(), 1
	for key, rec in pairs(entry.incomingMultipliers or {}) do
		if rec.untilAt > now then
			product *= rec.multiplier
		else
			entry.incomingMultipliers[key] = nil
		end
	end
	return product
end

-- 이동속도 배율도 출처별(P3d-F B6 전수 점검 B): 옛 회전베기는 시작할 때 WalkSpeed를 저장했다가 끝날 때 되돌려, 채널링 중 신발 · 보석을 바꾸면
-- 감속이 사라지고 끝날 때 옛 신발 속도로 돌아갔다. 이제 WalkSpeed = 기본 × 신발 배율 × 이 곱(PlayerProfile.refreshMovementSpeed) - 건 쪽이 자기 키만 지우고 다시 계산한다.
-- durationSeconds(선택) = 만료 시각(Play 2: 채널링 스레드가 끝 처리 전에 끊기면 감속 키가 리스폰까지 남았다 - 만료가 있으면 읽을 때 저절로 빠진다).
-- 만료되면 onExpire(선택 - 보통 PlayerProfile.refreshMovementSpeed)를 불러 WalkSpeed를 다시 맞춘다.
function PlayerState.setMoveSpeedMultiplier(player, sourceKey, multiplier, durationSeconds, onExpire)
	local entry = players[player]
	if not entry then
		return
	end
	entry.moveSpeedMultipliers = entry.moveSpeedMultipliers or {}
	if multiplier == nil then
		entry.moveSpeedMultipliers[sourceKey] = nil
		return
	end
	local rec = { multiplier = multiplier, untilAt = durationSeconds and (os.clock() + durationSeconds) or math.huge }
	entry.moveSpeedMultipliers[sourceKey] = rec
	if durationSeconds and onExpire then
		task.delay(durationSeconds + 0.05, function()
			-- 리뷰 4: 리스폰(reset)이 표를 지운 뒤에도 다시 계산한다(새 캐릭터에 옛 감속이 먼저 걸렸을 수 있다). 같은 키를 새로 건 것이면 건드리지 않는다.
			local current = entry.moveSpeedMultipliers and entry.moveSpeedMultipliers[sourceKey]
			if current == rec or current == nil then
				if current == rec then
					entry.moveSpeedMultipliers[sourceKey] = nil
				end
				onExpire(player)
			end
		end)
	end
end

function PlayerState.getMoveSpeedMultiplier(player)
	local entry = players[player]
	local now, product = os.clock(), 1
	for key, rec in pairs(entry and entry.moveSpeedMultipliers or {}) do
		if rec.untilAt > now then
			product *= rec.multiplier
		else
			entry.moveSpeedMultipliers[key] = nil
		end
	end
	return product
end

-- 검증 · 로그용: 살아 있는 이동속도 출처 { [키] = 배율 }.
function PlayerState.debugMoveSpeedSources(player)
	local entry = players[player]
	local now, list = os.clock(), {}
	for key, rec in pairs(entry and entry.moveSpeedMultipliers or {}) do
		if rec.untilAt > now then
			list[key] = rec.multiplier
		end
	end
	return list
end

-- 체력바 눈금 기준(Attribute TickDamage)도 출처(몬스터 모델)별(P3d-F 전수 점검 D): 옛 칸 하나는 나중에 붙은 몹이 앞 몹의 값을 덮고, 그 몹이 돌아가며 0으로
-- 지워 앞 몹이 아직 때리는데 눈금이 사라졌다. 보이는 값 = 살아 있는 출처 중 가장 큰 평타(가장 위협적인 몹). value nil/0 = 이 출처를 지운다.
function PlayerState.setTickDamageSource(player, source, value)
	local entry = players[player]
	if not entry or typeof(player) ~= "Instance" then
		return
	end
	entry.tickSources = entry.tickSources or setmetatable({}, { __mode = "k" })
	entry.tickSources[source] = (value and value > 0) and value or nil
	local best = 0
	for model, v in pairs(entry.tickSources) do
		if typeof(model) == "Instance" and model.Parent then
			best = math.max(best, v)
		else
			entry.tickSources[model] = nil
		end
	end
	player:SetAttribute("TickDamage", best)
end

-- 루트 고정(Anchored)도 출처별로 잡는다(P3d-F B6 전수 점검 A): 잡힘(BossTrap)과 끼임(BossArenaMap)이 같은 Anchored 한 칸을 켜고 꺼서,
-- 끼인 채 잡히면 끼임이 부서질 때 잡힌 사람이 풀려 걸어 다녔고 · 잡힌 채 끼이면 잡힘이 풀릴 때 끼임에서 빠져나갔다. 고정 = 잡은 출처가 하나라도 있으면.
function PlayerState.setAnchorHold(player, sourceKey, on)
	local entry = players[player]
	if not entry then
		return
	end
	entry.anchorHolds = entry.anchorHolds or {}
	entry.anchorHolds[sourceKey] = on and true or nil
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = next(entry.anchorHolds) ~= nil
		if on then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end
end

function PlayerState.hasAnchorHold(player, sourceKey)
	local entry = players[player]
	return entry ~= nil and entry.anchorHolds ~= nil and entry.anchorHolds[sourceKey] == true
end

-- 흡혈 토큰 버킷(26-2, PRD 20.67 [6-1]) - 용량·충전 모두 maxHp×
-- CombatConfig.lifestealMaxHpFractionPerSecond(초당). 호출마다 마지막 계산 이후 지난 시간만큼
-- 채우고(용량을 넘지 않게), requestedAmount와 남은 잔량 중 작은 쪽만 내어준다 - "타격마다
-- min(피해×Σls, 잔량)만 회복"(20.67 [6-1] 구현 문구 그대로). 처음 쓰는 순간은 가득 찬
-- 버킷으로 취급한다(lifestealTokens=nil). maxHp는 그때그때(장비 교체로 바뀔 수 있다) 다시
-- 읽는다 - 캐싱하지 않는다.
function PlayerState.tryLifesteal(player, requestedAmount)
	local entry = players[player]
	if not entry or not entry.maxHp then
		return 0
	end
	local capacity = entry.maxHp * CombatConfig.lifestealMaxHpFractionPerSecond
	local now = os.clock()
	local elapsed = entry.lifestealTokensUpdatedAt and (now - entry.lifestealTokensUpdatedAt) or 0
	local available = math.min(capacity, (entry.lifestealTokens or capacity) + capacity * elapsed)
	local granted = math.min(requestedAmount, available)
	entry.lifestealTokens = available - granted
	entry.lifestealTokensUpdatedAt = now
	return granted
end

-- 잡힘(29-1, PRD 20.73 [2-8] A-2) - BossTrap.lua가 걸고 푼다. 값은 "잡힌 동안 받는 피해 배율"
-- (BossData.mechanics.trap.damageTakenMultiplier, 0 = 면역)이고 nil이면 안 잡힌 상태다.
-- PlayerDamage(피해)·AttackServer/SkillServer/DashServer(행동 거절)·HealerDealingMode(소모 정지)가 읽는다.
function PlayerState.setTrapped(player, damageTakenMultiplier)
	local entry = players[player]
	if entry then
		entry.trapDamageMultiplier = damageTakenMultiplier
	end
end

function PlayerState.isTrapped(player)
	local entry = players[player]
	return entry ~= nil and entry.trapDamageMultiplier ~= nil
end

function PlayerState.getTrapDamageMultiplier(player)
	local entry = players[player]
	return entry and entry.trapDamageMultiplier
end

function PlayerState.clear(player)
	players[player] = nil
	PlayerShield.clear(player)
end

return PlayerState
