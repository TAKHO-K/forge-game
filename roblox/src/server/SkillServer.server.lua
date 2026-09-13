-- 서버 권위 스킬 판정(20-2a) - AttackServer.server.lua와 같은 원칙(클라는 "쓰겠다"는
-- 의사만 보내고, 쿨다운·판정·데미지는 전부 여기서 계산한다). 이번에 판정 유형 두 가지가
-- 처음 생긴다 - Q(관통돌진)는 "이동 + 선분 판정", E(회전베기)는 "채널링 + 원형 판정".
-- 나머지 6종 스킬 대부분이 이 둘의 변형이라 이 파일이 앞으로의 기준이 된다.
--
-- 이동(Q)은 서버가 직접 캐릭터를 옮기지 않는다 - 서버는 사거리·담장·판정만 계산해
-- "여기까지 갔다"는 결과(dashEndPosition)를 클라이언트에 알려주고, 실제 시각적 이동은
-- 그 결과를 받은 클라(SkillInput.client.lua)가 자기 캐릭터를 움직인다(그 클라가 원래
-- 이 캐릭터의 네트워크 소유자라 서버가 CFrame을 강제로 밀어넣으면 소유권 충돌로 위치가
-- 튀거나 되돌아간다 - AttackServer가 사거리 판정에 rootPart.Position을 그대로 신뢰하는 것과
-- 같은 신뢰 모델이다, 이 게임은 애초에 서버가 이동 자체를 소유하지 않는다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local SkillCombat = require(ReplicatedStorage.Shared.SkillCombat)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)
local BuffState = require(script.Parent.BuffState)

local skillRequest = Instance.new("RemoteEvent")
skillRequest.Name = "SkillRequest"
skillRequest.Parent = ReplicatedStorage

-- 캐스트 결과 - Q는 kind="dash"로 한 번, E는 kind="tick"으로 채널링 중 tickCount번(20-2a
-- [3], PRD 4.3 "지속 타격") 나눠서 온다. ok=false면 거부(쿨다운 등) - reason만 있고
-- hits는 없다. 슬롯별 쿨다운 소스는 항상 이 이벤트다(SkillSlots.client.lua가 구독).
local skillCastResult = Instance.new("RemoteEvent")
skillCastResult.Name = "SkillCastResult"
skillCastResult.Parent = ReplicatedStorage

-- [Player][slot] = os.clock() 마지막 캐스트 시각.
local lastCastTick = {}

local function isOnCooldown(player, slot, cooldownSeconds)
	local perPlayer = lastCastTick[player]
	local last = perPlayer and perPlayer[slot]
	return last ~= nil and (os.clock() - last) < cooldownSeconds
end

local function markCast(player, slot)
	lastCastTick[player] = lastCastTick[player] or {}
	lastCastTick[player][slot] = os.clock()
end

local function reject(player, slot, reason)
	skillCastResult:FireClient(player, slot, { ok = false, reason = reason })
end

-- 몬스터 하나를 때린다 - 데미지 계산(계수×atk, 치명타는 calcDamage가 판정) + 적용 + 죽음
-- 처리(CombatResolution, AttackServer와 같은 경로). 여러 대상을 때리는 Q/E가 공유한다.
-- coefficient는 이미 "이번 타격 1회분"이다(E는 호출부가 tickCount로 미리 나눠서 넘긴다).
local function strikeTarget(player, classId, atk, target, coefficient, attackerStage)
	local base = atk * coefficient
	local damage, isCrit = PlayerCombat.calcDamage(base, classId)
	local isDead = MonsterState.applyDamage(target, damage, attackerStage, player)
	MonsterSpawner.updateHpLabel(target)
	CombatResolution.resolveHit(player, target, isDead)
	return { target = target, damage = damage, isCrit = isCrit, isDead = isDead }
end

-- 후보 몬스터 중 캐스터와 같은 구역(ZoneBounds) 안에 있는 것만 남긴다 - AttackServer의
-- "구역 밖 공격 차단"(19-4 [4]-나)과 같은 2차 방어. 담장(물리 충돌)이 1차 방어다.
local function filterSameZone(casterPosition, candidates)
	local filtered = {}
	for _, model in ipairs(candidates) do
		if ZoneBounds.isInside(casterPosition, MonsterState.getZoneKey(model)) then
			table.insert(filtered, model)
		end
	end
	return filtered
end

-- 담장에 막히는지 Raycast로 확인해 최종 도착점을 정한다(20-2a 관통돌진, 20-2b 백스텝샷이
-- 공유하는 "돌진형" 판정의 공통부 - 방향만 서로 다르다). 몬스터 Body/Head는 기본
-- CanQuery=true라 그냥 두면 Raycast가 "몬스터에 막혔다"고 오판한다(몬스터는 담장이
-- 아니다) - 캐릭터 자신 + 살아있는 몬스터 전원을 제외해 담장·지형에만 막히게 한다.
local function computeDashEndpoint(player, startPos, direction, rangeStuds)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	local excluded = { player.Character }
	for _, model in ipairs(MonsterState.getAllModels()) do
		table.insert(excluded, model)
	end
	raycastParams.FilterDescendantsInstances = excluded
	local rayResult = Workspace:Raycast(startPos, direction * rangeStuds, raycastParams)

	-- 벽에 막히면 그 앞에서 멈춘다(19-4 구역 담장을 뚫지 않는다). 1stud 여유를 둬 캐릭터가
	-- 벽에 파묻히지 않게 한다.
	local finalDistance = rangeStuds
	if rayResult then
		finalDistance = math.max(rayResult.Distance - 1, 0)
	end
	return startPos + direction * finalDistance
end

-- 관통돌진(대검 Q): "바라보는 방향"(rootPart.CFrame.LookVector, 클라 aimPoint를 안 믿는다)
-- 으로 돌진하며 시작점~도착점 선분 위 적 전원을 즉시 때린다. 실제 이동은 이 결과를 받은
-- 클라가 재생한다.
local function castLineAttack(player, slot, def, classId, atk, rootPart, attackerStage)
	local lookFlat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	if lookFlat.Magnitude < 1e-3 then
		return
	end
	local direction = lookFlat.Unit
	local startPos = rootPart.Position
	local finalEnd = computeDashEndpoint(player, startPos, direction, def.rangeStuds)

	local candidates = filterSameZone(startPos, MonsterState.getAllModels())
	local targets = SkillCombat.hitsOnSegment(startPos, finalEnd, def.hitRadiusStuds, candidates)

	local hits = {}
	for _, target in ipairs(targets) do
		table.insert(hits, strikeTarget(player, classId, atk, target, def.coefficient, attackerStage))
	end

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "dash",
		cooldownSeconds = def.cooldownSeconds,
		startPosition = startPos,
		endPosition = finalEnd,
		durationSeconds = def.durationSeconds,
		hits = hits,
	})
end

-- 백스텝샷(활 E, 20-2b [1][4], PRD-forge-game.md 4.3): "바라보는 방향의 반대"로 짧게
-- 물러나며 아무도 때리지 않는다 - 대신 다음 평타 5발에 붙는 버프를 건다([1] 프레임워크,
-- AttackServer.server.lua의 backstepShotBuff 소비 지점 참고).
local function castDashBuff(player, slot, def, rootPart)
	local lookFlat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	local direction = lookFlat.Magnitude > 1e-3 and -lookFlat.Unit or Vector3.new(0, 0, 1)
	local startPos = rootPart.Position
	local finalEnd = computeDashEndpoint(player, startPos, direction, def.rangeStuds)

	BuffState.apply(player, "backstepShotBuff", {
		chargesRemaining = def.chargesGranted,
		critRateBonus = def.critRateBonus,
		damageCoefficient = def.damageCoefficient,
		displayName = def.name,
		colorName = "success",
	})

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "dash",
		cooldownSeconds = def.cooldownSeconds,
		startPosition = startPos,
		endPosition = finalEnd,
		durationSeconds = def.durationSeconds,
		hits = {}, -- 백스텝샷 자체는 아무도 안 때린다 - 다음 평타들이 버프를 소모한다.
	})
end

-- 속사(활 Q, 20-2b [1][3], PRD-forge-game.md 4.3): 순수 자기 버프 - [1] 프레임워크의
-- 첫 사용자. 공식(웹·PRD 완전 일치): 공속배율 = min(cap, base + 치명타확률×critCoefficient).
-- 치명타확률이 오르면 이 배율도 같이 오른다(ClassData.classes[classId].critRate를 그
-- 순간 다시 읽으므로 - 확정된 값을 캐싱하지 않는다).
local function castSelfBuff(player, slot, def, classId)
	local critRate = ClassData.classes[classId].critRate
	local multiplier = math.min(def.attackSpeedCap, def.attackSpeedBase + critRate * def.attackSpeedCritCoefficient)

	BuffState.apply(player, "quickShot", {
		durationSeconds = def.durationSeconds,
		value = multiplier,
		displayName = def.name,
		colorName = "ember",
	})

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "selfBuff",
		cooldownSeconds = def.cooldownSeconds,
	})
end

-- 회전베기(대검 E): 채널링 3초간 이동속도를 낮추고(느려질 뿐 멈추지 않는다), 받는 피해를
-- 50% 줄인 채로(PRD 4.3), tickCount번에 걸쳐 나눠 원형 판정으로 때린다(20-2a [0]/[3] -
-- "채널링이 끝나는 시점에 한 번"이 아니라 PRD 4.3의 "지속 타격"을 따른다, 명세 상이 보고).
-- 피격되어도 채널링은 끊기지 않는다(지시 [1] - 몬스터가 많을수록 못 쓰는 스킬이 되면
-- 안 된다는 이유 그대로 채택, PlayerState의 HP 차감과 이 task.spawn 루프는 서로 무관하다).
local function castCircleChannel(player, slot, def, classId, atk, attackerStage)
	markCast(player, slot)
	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "channelStart",
		cooldownSeconds = def.cooldownSeconds,
		channelSeconds = def.channelSeconds,
	})

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local originalWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = originalWalkSpeed * def.channelMoveSpeedMultiplier
	PlayerState.setIncomingDamageMultiplierUntil(player, def.incomingDamageMultiplier, def.channelSeconds)

	local tickInterval = def.channelSeconds / def.tickCount
	local perTickCoefficient = def.coefficient / def.tickCount

	for tickIndex = 1, def.tickCount do
		task.wait(tickInterval)

		-- 채널링 도중 캐릭터가 사라지면(사망·퇴장) 조용히 멈춘다 - WalkSpeed 복구는
		-- 캐릭터가 없으면 의미가 없으니 건너뛴다.
		character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then
			return
		end

		local casterPosition = rootPart.Position
		local candidates = filterSameZone(casterPosition, MonsterState.getAllModels())
		local targets = SkillCombat.hitsInCircle(casterPosition, def.radiusStuds, candidates)

		local hits = {}
		for _, target in ipairs(targets) do
			table.insert(hits, strikeTarget(player, classId, atk, target, perTickCoefficient, attackerStage))
		end

		skillCastResult:FireClient(player, slot, {
			ok = true,
			kind = "tick",
			tickIndex = tickIndex,
			tickCount = def.tickCount,
			casterPosition = casterPosition,
			radiusStuds = def.radiusStuds,
			hits = hits,
		})
	end

	humanoid.WalkSpeed = originalWalkSpeed
end

skillRequest.OnServerEvent:Connect(function(player, slot)
	if slot ~= "Q" and slot ~= "E" then
		return
	end

	local classId = PlayerProfile.getClassId(player)
	local weapon = PlayerProfile.getWeapon(player)
	if not classId or not weapon then
		return -- 로드 미완료·직업 미선택 - 헛스윙 취급(AttackServer와 같은 원칙)
	end

	-- 20-2a: 지금은 대검만 채워져 있다(SkillData.lua) - 나머지 직업은 빈 테이블이라
	-- def가 nil이면 조용히 무시한다(지시 [5] 검증 7 - 에러가 나면 안 된다).
	local classSkills = SkillData[classId]
	local def = classSkills and classSkills[slot]
	if not def then
		return
	end

	if isOnCooldown(player, slot, def.cooldownSeconds) then
		reject(player, slot, "cooldown")
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local characterLevel = PlayerProfile.getCharacterLevel(player)
	local atk = PlayerCombat.getAttack(weapon, classId, characterLevel, PlayerProfile.getAttackPercentBonus(player))
	local attackerStage = PlayerProfile.getInfiniteStage(player) or 1

	-- 20-2b: 슬롯(Q/E)이 아니라 판정 유형(shape)으로 분기한다 - 대검 Q=line/E=circle이던
	-- 우연한 대응이 깨졌다(활 Q=selfBuff/E=dash). "채널형"(castCircleChannel)만 자체적으로
	-- markCast를 부른다(채널 시작 즉시 쿨다운이 걸려야 채널링 도중 같은 스킬 재요청 경합을
	-- 막는다) - 나머지는 여기서 공통으로 찍는다.
	if def.shape == "line" then
		markCast(player, slot)
		castLineAttack(player, slot, def, classId, atk, rootPart, attackerStage)
	elseif def.shape == "circle" then
		castCircleChannel(player, slot, def, classId, atk, attackerStage)
	elseif def.shape == "selfBuff" then
		markCast(player, slot)
		castSelfBuff(player, slot, def, classId)
	elseif def.shape == "dash" then
		markCast(player, slot)
		castDashBuff(player, slot, def, rootPart)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastCastTick[player] = nil
end)

print("[forge-game] SkillServer 로드됨 - 대검 Q/E, 활 Q(속사)/E(백스텝샷) 판정 활성")
