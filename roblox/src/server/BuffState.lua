-- 자기 자신에게 거는 지속 효과의 단일 관리 통로(20-2b [1] - 20-2a가 세운 스킬 프레임워크
-- 확장). 활 Q(속사)만을 위한 게 아니다 - 쌍검 Q(확정 치명타), 힐러 E(딜링모드)도 나중에
-- 여기 얹일 예정이라 처음부터 범용으로 짠다. 서버가 유일한 진실이다 - 클라(BuffHud.
-- client.lua)는 BuffUpdate 이벤트를 받아 표시만 한다.
--
-- 버프 하나는 { expiresAt(시간 기반, os.clock() 기준) 또는 chargesRemaining(횟수 기반) 중
-- 최소 하나, + 호출부가 원하는 임의 필드(value·critRateBonus·damageCoefficient 등) } 로
-- 구성된다 - 종류마다 무엇을 담을지 다르므로(공속 배율 하나면 충분한 것도 있고, 활
-- 백스텝샷처럼 여러 값을 동시에 담아야 하는 것도 있다) 스키마를 고정하지 않고 config를
-- 그대로 저장한다. 실제 전투 계산이 이 값을 어디서 읽는지는 호출부(AttackServer.
-- server.lua 등)가 정한다 - 이 모듈은 "지금 이 버프가 살아있는가/값이 뭔가"만 안다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local buffUpdate = Instance.new("RemoteEvent")
buffUpdate.Name = "BuffUpdate"
buffUpdate.Parent = ReplicatedStorage

local BuffState = {}

-- [Player][buffId] = 버프 레코드.
local buffs = {}

-- 공속 버프(활 속사)만 예외적으로 Attribute도 같이 맞춘다 - PlayerCombat.getAttackCooldown이
-- 서버·클라 양쪽에서 호출되는데(AttackServer.server.lua는 BuffState를 직접 읽지만,
-- AttackInput.client.lua는 서버 전용 모듈을 못 읽으니 신발 공속 보너스(SpeedPercentBonus)와
-- 같은 자리에 Attribute로 올려 클라가 스윙 애니메이션 재생 여부를 예측할 때 쓴다). 다른
-- 버프 종류는 HUD 표시만 필요해 BuffUpdate 이벤트로 충분하다 - 이 한 종류만 특별하다.
local function notify(player, buffId, buff)
	if buffId == "quickShot" then
		player:SetAttribute("AttackSpeedBuffMultiplier", buff and buff.value or 1)
	end

	if buff then
		buffUpdate:FireClient(player, buffId, {
			active = true,
			displayName = buff.displayName,
			colorName = buff.colorName,
			remainingSeconds = buff.expiresAt and (buff.expiresAt - os.clock()) or nil,
			chargesRemaining = buff.chargesRemaining,
		})
	else
		buffUpdate:FireClient(player, buffId, { active = false })
	end
end

-- config: { durationSeconds(선택, 시간 기반), chargesRemaining(선택, 횟수 기반),
-- displayName, colorName(HUD 아이콘 색 - UIColors 키 이름), mode("refresh"|"stack",
-- 기본 refresh) + 그 외 임의 필드(value·critRateBonus·damageCoefficient 등). 같은
-- buffId를 다시 걸 때 mode="stack"이면 stacks를 늘리고 지속시간을 갱신, 기본(refresh)은
-- 그냥 통째로 새 값으로 덮어쓴다(지시 [1] - "갱신인지 중첩인지 버프마다 정할 수 있어야
-- 한다").
function BuffState.apply(player, buffId, config)
	buffs[player] = buffs[player] or {}
	local existing = buffs[player][buffId]

	local buff = table.clone(config)
	buff.expiresAt = config.durationSeconds and (os.clock() + config.durationSeconds) or nil
	if config.mode == "stack" and existing then
		buff.stacks = (existing.stacks or 1) + 1
	end

	buffs[player][buffId] = buff
	notify(player, buffId, buff)
end

local function isExpired(buff)
	if buff.expiresAt and os.clock() >= buff.expiresAt then
		return true
	end
	if buff.chargesRemaining and buff.chargesRemaining <= 0 then
		return true
	end
	return false
end

-- 살아있는 버프 레코드를 돌려준다(만료됐으면 지우고 nil). 전투 계산이 값을 여러 개
-- 읽어야 할 때(예: 백스텝샷의 critRateBonus + damageCoefficient) 이 함수로 통째로 받아
-- 직접 필드에 접근해도 되고, 아래 getField/getValue 편의 함수를 써도 된다.
function BuffState.get(player, buffId)
	local playerBuffs = buffs[player]
	local buff = playerBuffs and playerBuffs[buffId]
	if not buff then
		return nil
	end
	if isExpired(buff) then
		playerBuffs[buffId] = nil
		notify(player, buffId, nil)
		return nil
	end
	return buff
end

-- 단일 값 버프(예: 공속 배율) 전용 편의 함수 - config.value를 그대로 돌려준다.
function BuffState.getValue(player, buffId, default)
	local buff = BuffState.get(player, buffId)
	return buff and buff.value or default
end

function BuffState.getField(player, buffId, field, default)
	local buff = BuffState.get(player, buffId)
	if not buff or buff[field] == nil then
		return default
	end
	return buff[field]
end

-- 횟수 기반 버프를 한 번 소모한다("다음 N회 평타" 방식) - 소모 후 0이 되면 사라진다.
-- 이 타격에 버프가 실제로 적용됐는지(활성 상태였는지)를 돌려준다.
function BuffState.consumeCharge(player, buffId)
	local buff = BuffState.get(player, buffId)
	if not buff then
		return false
	end
	if buff.chargesRemaining then
		buff.chargesRemaining -= 1
		if buff.chargesRemaining <= 0 then
			buffs[player][buffId] = nil
			notify(player, buffId, nil)
		else
			notify(player, buffId, buff)
		end
	end
	return true
end

function BuffState.clear(player, buffId)
	local playerBuffs = buffs[player]
	if not playerBuffs or not playerBuffs[buffId] then
		return
	end
	playerBuffs[buffId] = nil
	notify(player, buffId, nil)
end

-- 죽거나 직업을 바꾸거나 퇴장하면 전부 정리한다(지시 [1] - 19-4가 겪은 유령 상태 문제를
-- 반복하지 않는다). 호출부(PlayerState.reset 경로·ClassServer 등)가 이 함수 하나만
-- 부르면 된다 - 개별 버프 종류를 하나씩 아는 곳이 여러 군데로 늘어나지 않는다.
function BuffState.clearAll(player)
	local playerBuffs = buffs[player]
	if not playerBuffs then
		return
	end
	for buffId in pairs(playerBuffs) do
		notify(player, buffId, nil)
	end
	buffs[player] = nil
end

-- 죽어서(리)스폰해도 버프가 이어지면 안 된다(지시 [1]) - CharacterAdded가 최초 입장과
-- 사망 후 리스폰 둘 다에서 불린다는 점을 그대로 이용한다(MonsterAI.server.lua의
-- PlayerState.reset 훅과 같은 패턴). 최초 입장 시점엔 clearAll이 그냥 빈 테이블에
-- 대고 아무 것도 안 지우는 것과 같아 안전하다.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		BuffState.clearAll(player)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	buffs[player] = nil
end)

-- 시간 기반 버프의 실제 만료는 지금까지 "누군가 읽을 때"(BuffState.get)만 감지됐다 -
-- 전투 계산이 그 사이 한 번도 안 불리면(예: 버프를 걸어놓고 아무것도 안 때리는 동안)
-- Attribute·BuffUpdate 알림이 만료 시점을 놓치고 지나간다. HUD(클라 로컬 카운트다운)는
-- 어차피 스스로 사라지니 상관없지만, AttackSpeedBuffMultiplier 같은 Attribute는 다음
-- 실제 판정 때까지 낡은 값을 들고 있게 된다 - 19-4가 겪은 것과 같은 종류의 "아무도
-- 안 치워서 남는" 유령 상태다. 0.5초마다 살아있는 버프를 전부 한 번씩 읽어(get이
-- 만료 감지+notify를 이미 갖고 있다) 그 문제를 없앤다 - 새 정리 로직을 또 만들지 않는다.
local SWEEP_INTERVAL_SECONDS = 0.5
local sweepAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	sweepAccumulator += dt
	if sweepAccumulator < SWEEP_INTERVAL_SECONDS then
		return
	end
	sweepAccumulator = 0

	for player, playerBuffs in pairs(buffs) do
		for buffId in pairs(playerBuffs) do
			BuffState.get(player, buffId)
		end
	end
end)

return BuffState
