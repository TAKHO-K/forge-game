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
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local Reach = require(ReplicatedStorage.Shared.Reach)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)
local BuffState = require(script.Parent.BuffState)
local SummonState = require(script.Parent.SummonState)
local DashEndpoint = require(script.Parent.DashEndpoint)
local PartyState = require(script.Parent.PartyState)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)

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
-- forceCrit·critDmgBonus(20-6, 쌍검 Q 확정 치명타) - 기본 nil이라 기존 호출부(대검 Q/E,
-- 이 아래 castLineAttack/castCircleChannel)는 그대로 동작한다.
local function strikeTarget(player, classId, atk, target, coefficient, attackerStage, forceCrit, critDmgBonus)
	local base = atk * coefficient
	-- 26-2(PRD 20.67 [14] 4단계 "치명") - 장비·보석 치명 옵션 합을 더한다. critDmgBonus는
	-- 호출부(쌍검 Q 확정 치명타)가 넘긴 값이 있으면 거기에 더한다(둘 다 기본 0/nil).
	local optionCritRate, optionCritDmg = PlayerProfile.getCritBonus(player)
	local damage, isCrit = PlayerCombat.calcDamage(base, classId, optionCritRate, forceCrit, (critDmgBonus or 0) + optionCritDmg)
	-- 힐러 버프(24-3, PRD 20.64) - 방어력 감소·치명타 등 모든 계산이 끝난 "최종 피해"에
	-- 곱한다. calcDamage가 크리까지 이미 반영한 damage가 이 시점의 값이고, 이 아래에는
	-- 더 이상 배율을 곱하는 계산이 없다(15-1의 "감소식 앞에 곱해 앵커가 어긋난" 실수를
	-- 반복하지 않는다). 버프가 없으면 getField가 기본값 1을 돌려줘 기존과 동일하다.
	damage *= BuffState.getField(player, "healerBuff", "multiplier", 1)
	-- 29-1: 둘째 반환값 = 실제로 들어간 피해(보스 파훼 게이트 ×g 반영) - 숫자·흡혈이 이 값을 쓴다.
	local isDead, dealt = MonsterState.applyDamage(target, damage, attackerStage, player)
	damage = dealt
	MonsterSpawner.updateHpLabel(target)
	PlayerProfile.applyLifesteal(player, damage) -- 26-2, AttackServer 평타와 같은 지점(damage 확정 직후)
	CombatResolution.resolveHit(player, target, isDead)
	return { target = target, damage = damage, isCrit = isCrit, isDead = isDead }
end

-- 쌍검 Q 확정 치명타(20-6) 해석 - BuffState 조회는 이 서버 스크립트에서만 하고, 실제
-- forceCrit/critDmgBonus 판단은 PlayerCombat.resolveGuaranteedCrit(순수 함수)에 맡긴다
-- (AttackServer.server.lua의 평타 경로도 똑같이 이 함수를 부른다 - 계산 지점을 하나로 유지).
local function resolveGuaranteedCrit(player, classId)
	local isActive = BuffState.get(player, "guaranteedCrit") ~= nil
	-- 26-2: 유효 치확(효과 100% 초과 판정)에 옵션 치확도 포함해야 "이미 100%를 넘겼다"는
	-- 조건이 옵션 장착 여부와 무관하게 일관된다.
	local optionCritRate = PlayerProfile.getCritBonus(player)
	return PlayerCombat.resolveGuaranteedCrit(classId, isActive, optionCritRate)
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
-- 공유하는 "돌진형" 판정의 공통부 - 방향만 서로 다르다). 21-2부터 DashEndpoint.lua
-- 모듈이다 - 대시(DashServer.server.lua)까지 세 곳이 같은 판정을 쓴다.
local function computeDashEndpoint(player, startPos, direction, rangeStuds)
	return DashEndpoint.compute(player, startPos, direction, rangeStuds)
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

	-- 26-2(PRD 20.67 [2] "관통돌진 - Q coefficient ×(1+x)").
	local coefficient = def.coefficient * (1 + PlayerProfile.getOptionBonus(player, "skill_greatsword_Q"))
	local hits = {}
	for _, target in ipairs(targets) do
		table.insert(hits, strikeTarget(player, classId, atk, target, coefficient, attackerStage))
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
-- AttackServer.server.lua의 backstepShotBuff 소비 지점 참고). cooldownSeconds(26-2)는
-- 호출부(dispatch)가 옵션 반영까지 끝낸 실제 값을 넘긴다 - 쿨다운 게이트가 본 값과 클라
-- 표시값이 어긋나면 안 된다.
local function castDashBuff(player, slot, def, rootPart, cooldownSeconds)
	local lookFlat = Vector3.new(rootPart.CFrame.LookVector.X, 0, rootPart.CFrame.LookVector.Z)
	local direction = lookFlat.Magnitude > 1e-3 and -lookFlat.Unit or Vector3.new(0, 0, 1)
	local startPos = rootPart.Position
	local finalEnd = computeDashEndpoint(player, startPos, direction, def.rangeStuds)

	BuffState.apply(player, "backstepShotBuff", {
		chargesRemaining = def.chargesGranted,
		critRateBonus = def.critRateBonus,
		damageCoefficient = def.damageCoefficient,
		rangeMultiplier = def.rangeMultiplier, -- 20-4 [2] - 사거리 2배(실제 상한은 PlayerCombat.getBuffedAttackRange)
		displayName = def.name,
		colorName = "success",
	})

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "dash",
		cooldownSeconds = cooldownSeconds,
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
	-- 26-2(PRD 20.67 [2] "속사 - 속사 공속 배율 ×(1+x), 기존 attackSpeedCap 유지") - 옵션
	-- 배율은 cap으로 자르기 전에 곱한다(상한은 그대로 2.5).
	local optionMultiplier = 1 + PlayerProfile.getOptionBonus(player, "skill_bow_Q")
	local multiplier = math.min(def.attackSpeedCap, (def.attackSpeedBase + critRate * def.attackSpeedCritCoefficient) * optionMultiplier)

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
	-- 21-1 [1]-C: 채널링 중 평타 차단(PRD 4.3 "채널링 3초는 평타 시간에서 뺀다") - 이게
	-- 계수 프리미엄의 대가다. AttackServer가 PlayerState.isChanneling으로 거부한다.
	PlayerState.setChannelingUntil(player, def.channelSeconds)

	local tickInterval = def.channelSeconds / def.tickCount
	-- 26-2(PRD 20.67 [2] "회전베기 - E 틱 피해 ×(1+x)").
	local perTickCoefficient = def.coefficient * (1 + PlayerProfile.getOptionBonus(player, "skill_greatsword_E")) / def.tickCount

	for tickIndex = 1, def.tickCount do
		task.wait(tickInterval)

		-- 채널링 도중 캐릭터가 사라지면(사망·퇴장) 조용히 멈춘다 - WalkSpeed 복구는
		-- 캐릭터가 없으면 의미가 없으니 건너뛴다.
		character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then
			PlayerState.clearChanneling(player)
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

-- 그림자분신용 반투명 복제(20-6 [2], 지시 "새 모델을 만들지 마라. 기존 캐릭터를
-- 복제하거나 단순 도형으로 대체해라" - 복제를 택했다). Script/LocalScript는 전부 지운다
-- (Animate·Health 등 원본 캐릭터 전용 스크립트가 복제본에서 그대로 돌면 예측 못 할
-- 부작용이 생길 수 있다 - 분신은 순수 정적 장식이라 스크립트가 전혀 필요 없다). 모든
-- BasePart를 Anchor해 물리 시뮬레이션 없이 클론 당시 포즈 그대로 고정한다("그 자리에"
-- 분신 생성 - PRD 4.3) - 그래서 별도 위치 지정도 필요 없다(clone이 원본과 같은 CFrame을
-- 그대로 들고 있다). CanCollide/CanQuery를 끄는 이유는 실제 캐릭터 이동·Raycast(SkillServer
-- 관통돌진 담장 판정 등)를 방해하면 안 되기 때문 - 몬스터의 목표 지점으로만 쓰인다.
local DECOY_MIN_TRANSPARENCY = 0.5

local function buildDecoyModel(character)
	-- 플레이어 Character는 기본적으로 Archivable=false다(로블록스 기본값) - 이 상태로는
	-- Clone()이 에러 없이 조용히 nil을 돌려준다(실기 검증 중 발견 - "attempt to index nil
	-- with 'GetDescendants'"로 재현됨). 복제하는 동안만 잠깐 true로 바꿨다가 원래대로
	-- 되돌린다 - 원본 캐릭터의 Archivable 값 자체를 바꾸는 게 목적이 아니다.
	local originalArchivable = character.Archivable
	character.Archivable = true
	local decoy = character:Clone()
	character.Archivable = originalArchivable
	for _, inst in ipairs(decoy:GetDescendants()) do
		if inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
			inst.Color = UIColors.classAccent.dualblade -- #A64DFF, 지시 원문 색 그대로
			inst.Transparency = math.max(inst.Transparency, DECOY_MIN_TRANSPARENCY)
		end
	end
	decoy.Name = "DualbladeDecoy"
	decoy.PrimaryPart = decoy:FindFirstChild("HumanoidRootPart")
	decoy.Parent = Workspace
	return decoy
end

-- 그림자분신(쌍검 Q, 20-6 [2]) - 분신을 소환해 SummonState에 등록(생명주기는 그 모듈이
-- 전담)하고, 같은 지속시간 동안 확정 치명타 버프를 건다(스킬 자체는 아무도 때리지 않는다 -
-- PRD 4.3 "분신이 적을 도발해 어그로 유지"일 뿐 자체 피해가 없다, 20-6 [0] 확인).
local function castSummonDecoy(player, slot, def, character)
	local decoy = buildDecoyModel(character)
	-- 26-2(PRD 20.67 [2] "그림자분신 - 지속 ×(1+x)", 상한 180% = OptionData.
	-- skill_dualblade_Q.cap - 5×(1+1.8)=14=def.cooldownSeconds와 정확히 일치, 20.67 [7]
	-- "지속 ≤ 쿨다운 14초"). 분신 생존시간과 확정 치명타 창이 이 값을 그대로 공유한다
	-- (SkillData.lua 주석 그대로 유지).
	local durationSeconds = def.durationSeconds * (1 + PlayerProfile.getOptionBonus(player, "skill_dualblade_Q"))
	SummonState.spawn(player, def.summonId, decoy, durationSeconds)

	BuffState.apply(player, "guaranteedCrit", {
		durationSeconds = durationSeconds,
		displayName = def.name,
		colorName = "success",
	})

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "summon",
		cooldownSeconds = def.cooldownSeconds,
		durationSeconds = durationSeconds,
		hits = {},
	})
end

-- 난무(쌍검 E, 20-6 [3]) - 시전 시점에 고른 단일 대상을 tickCount번에 걸쳐 나눠 때린다
-- (castCircleChannel과 같은 "채널링+틱분할" 뼈대를 재사용하되, 대상이 원 안 전원이 아니라
-- 시전 시점에 고정된 하나뿐이라는 점만 다르다). 대상이 죽거나 사거리를 벗어나면 그 자리에서
-- 멈춘다(재탐색하지 않는다 - SkillData.lua dualblade.E 주석 참고).
local function castSingleChannel(player, slot, def, classId, atk, rootPart, attackerStage)
	local candidates = filterSameZone(rootPart.Position, MonsterState.getAllModels())
	local lockedTarget = AimPicker.pick(rootPart.Position, nil, def.rangeStuds, candidates)
	if not lockedTarget then
		reject(player, slot, "noTarget")
		return
	end

	markCast(player, slot)
	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "channelStart",
		cooldownSeconds = def.cooldownSeconds,
		channelSeconds = def.channelSeconds,
	})

	-- 21-1 [1]-C: 난무 1초 동안도 평타 차단(대검 회전베기와 같은 규칙 - 채널형 공통).
	-- 대상 사망·이탈로 일찍 끝나면 그 자리에서 풀어 평타를 바로 다시 열어 준다.
	PlayerState.setChannelingUntil(player, def.channelSeconds)

	local tickInterval = def.channelSeconds / def.tickCount
	-- 26-2(PRD 20.67 [2] "난무 - E 틱 피해 ×(1+x)").
	local perTickCoefficient = def.coefficient * (1 + PlayerProfile.getOptionBonus(player, "skill_dualblade_E")) / def.tickCount

	for tickIndex = 1, def.tickCount do
		task.wait(tickInterval)

		local character = player.Character
		local rootNow = character and character:FindFirstChild("HumanoidRootPart")
		if not rootNow then
			PlayerState.clearChanneling(player)
			return -- 캐스터가 사라졌다(사망·퇴장) - 조용히 멈춘다(castCircleChannel과 같은 가드)
		end

		if not (lockedTarget.Parent and MonsterState.getData(lockedTarget)) then
			PlayerState.clearChanneling(player)
			return -- 대상이 이미 죽었거나 사라졌다 - 남은 타격은 손실(재탐색 안 함)
		end
		local targetRoot = lockedTarget.PrimaryPart
		if not targetRoot or not Reach.within(targetRoot.Position, rootNow.Position, def.rangeStuds) then
			PlayerState.clearChanneling(player)
			return -- 대상이 사거리를 벗어났다(22-4: 수평 거리 + 높이차 상한)
		end

		local forceCrit, critDmgBonus = nil, nil
		if tickIndex <= (def.guaranteedCritHits or 0) then
			forceCrit, critDmgBonus = resolveGuaranteedCrit(player, classId)
		end

		local hit = strikeTarget(player, classId, atk, lockedTarget, perTickCoefficient, attackerStage, forceCrit, critDmgBonus)

		skillCastResult:FireClient(player, slot, {
			ok = true,
			kind = "flurryTick",
			tickIndex = tickIndex,
			tickCount = def.tickCount,
			hits = { hit },
		})

		if hit.isDead then
			PlayerState.clearChanneling(player)
			return
		end
	end
end

-- 치유(힐러 Q, 20-6 [5]) - 결과 포맷 확장([4])의 첫 사용자: hits 배열 대신 self 필드
-- ({healAmount, isCrit})를 보낸다. 기존 4종(대검 Q/E, 활 Q/E)은 이 필드를 아예 안 보내므로
-- (위 함수들 그대로) 회귀 위험이 없다 - 클라(SkillInput.client.lua)도 kind로만 분기한다.
-- cooldownSeconds(26-2)는 castDashBuff와 같은 이유로 dispatch가 넘긴다.
local function castHeal(player, slot, def, classId, cooldownSeconds)
	markCast(player, slot)
	local maxHp = PlayerState.getMaxHp(player)
	local hp = PlayerState.getHp(player)
	-- 26-2(PRD 20.67 [2] "재생 - 힐러 치유 회복량 ×(1+x)") - PlayerProfile.
	-- getHealingPowerMultiplier가 자동회복(PlayerRegen.server.lua)과 같은 배수를 쓴다.
	local baseHeal = maxHp * def.healPercentOfMaxHp * PlayerProfile.getHealingPowerMultiplier(player)
	-- calcDamage를 그대로 쓰지 않는다 - 크리 롤(RNG 소스 하나로 통일)만 재사용하고, 배율은
	-- SkillData의 critHealMultiplier(고정 2배, PRD 4.3)로 따로 곱한다. class.critDmg를 그대로
	-- 썼다면 힐러 기준 1.8배가 나와 PRD 수치와 어긋난다.
	local _, isCrit = PlayerCombat.calcDamage(baseHeal, classId)
	local healAmount = isCrit and baseHeal * def.critHealMultiplier or baseHeal
	local newHp = math.min(hp + healAmount, maxHp)
	PlayerState.setHp(player, newHp)
	player:SetAttribute("Hp", newHp) -- PlayerState가 유일한 HP 소스 - 바꾸는 모든 지점에서 동기화(MonsterAI.server.lua의 syncHud와 같은 원칙)

	-- 힐러 버프(24-3, PRD 20.64) - 파티에서만 발동한다(지시 6, 솔로 자기힐로 자기버프를
	-- 받아 딜을 올리는 경로 차단 - PartyState.getParty가 nil이면 여기서 끝난다). 멤버
	-- 전원(힐러 자신 포함, PRD 20.64 [1] "힐러 자신도 대상이다")에게 서버가 직접 건다 -
	-- 클라이언트가 버프를 주장할 길이 없다. 같은 buffId를 다시 걸면 BuffState.apply의
	-- 기본 동작(mode 미지정 = refresh)이 그대로 덮어써 지속시간만 갱신되고 중첩되지 않는다.
	local party = PartyState.getParty(player)
	if party then
		local multiplier = 1 + PartyConfig.healerBuffFraction
		-- 26-2: 실제(옵션 반영) 쿨다운에서 파생시킨다 - 치유 쿨다운이 짧아지면 버프도 그만큼
		-- 자주 갱신되므로 지속시간도 같이 짧아져야 SkillData.lua의 "제때 힐을 돌리면 안
		-- 끊긴다" 관계가 유지된다.
		local durationSeconds = cooldownSeconds * def.partyBuffDurationMultiplier
		for _, member in ipairs(PartyState.getMemberPlayers(party)) do
			BuffState.apply(member, "healerBuff", {
				durationSeconds = durationSeconds,
				multiplier = multiplier,
				displayName = "치유 버프",
				colorName = "success",
			})
		end
	end

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "heal",
		cooldownSeconds = cooldownSeconds,
		hits = {},
		self = { healAmount = healAmount, isCrit = isCrit },
	})
end

-- 딜링모드(힐러 E, 20-6 [6]) - 만료 없는 토글. 실제 체력 소모·평타 배율 적용은 여기서 하지
-- 않는다(HealerDealingMode.server.lua가 Heartbeat로 소모를, AttackServer.server.lua가
-- attackMultiplier를 각각 담당) - 이 함수는 BuffState를 켜고 끄는 스위치 역할만 한다.
local function castToggle(player, slot, def)
	local wasActive = BuffState.get(player, "dealingMode") ~= nil
	if wasActive then
		BuffState.clear(player, "dealingMode")
	else
		BuffState.apply(player, "dealingMode", {
			attackMultiplier = def.attackMultiplier,
			displayName = def.name,
			colorName = "danger",
		})
	end

	skillCastResult:FireClient(player, slot, {
		ok = true,
		kind = "toggle",
		cooldownSeconds = def.cooldownSeconds,
		active = not wasActive,
		hits = {},
	})
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
	-- 29-1(PRD 20.73 [2-8] A-2): 잡힌 동안엔 스킬을 못 쓴다(쿨다운도 안 돈다 - 요청이 없던 것과 같다).
	if PlayerState.isTrapped(player) then
		reject(player, slot, "trapped")
		return
	end

	-- 20-2a: 지금은 대검만 채워져 있다(SkillData.lua) - 나머지 직업은 빈 테이블이라
	-- def가 nil이면 조용히 무시한다(지시 [5] 검증 7 - 에러가 나면 안 된다).
	local classSkills = SkillData[classId]
	local def = classSkills and classSkills[slot]
	if not def then
		return
	end

	-- 26-2(PRD 20.67 [2] "백스텝샷/치유 - 쿨다운 ×(1-x)") - 옵션 baseValue가 음수라 1+합산이
	-- 곧 (1-x)다(Option.sumWithCap이 상한을 ±50%로 대칭 clamp해 0 이하로 못 내려간다). 이
	-- 두 슬롯 외에는 1(옵션 없음)로 원래 쿨다운 그대로다.
	local cooldownSeconds = def.cooldownSeconds
	if classId == "bow" and slot == "E" then
		cooldownSeconds *= 1 + PlayerProfile.getOptionBonus(player, "skill_bow_E")
	elseif classId == "healer" and slot == "Q" then
		cooldownSeconds *= 1 + PlayerProfile.getOptionBonus(player, "skill_healer_Q")
	end
	if isOnCooldown(player, slot, cooldownSeconds) then
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
	-- 23-1: 견습 중이면 무한 stage 대신 그 단계의 잡몹 stage를 쓴다.
	local attackerStage = TutorialState.getMonsterStage(player)

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
		castDashBuff(player, slot, def, rootPart, cooldownSeconds)
	elseif def.shape == "summon" then
		markCast(player, slot)
		castSummonDecoy(player, slot, def, character)
	elseif def.shape == "singleChannel" then
		-- castSingleChannel 자체가 대상을 못 찾으면 markCast 없이 거부한다(대상이 없으면
		-- 쿨다운을 태우지 않는다 - "헛스윙도 쿨다운 소모" 원칙과 다른 지점이지만, 이 스킬은
		-- 사거리 안에 아무도 없으면 시전 자체가 무의미해 되돌려주는 쪽이 낫다고 판단했다).
		castSingleChannel(player, slot, def, classId, atk, rootPart, attackerStage)
	elseif def.shape == "heal" then
		castHeal(player, slot, def, classId, cooldownSeconds)
	elseif def.shape == "toggle" then
		markCast(player, slot)
		castToggle(player, slot, def)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastCastTick[player] = nil
end)

print("[forge-game] SkillServer 로드됨 - 대검 Q/E, 활 Q/E, 쌍검 Q(그림자분신)/E(난무), 힐러 Q(치유)/E(딜링모드) 판정 활성")
