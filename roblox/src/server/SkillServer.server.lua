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
local ZoneBounds = require(ReplicatedStorage.Shared.ZoneBounds)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local Reach = require(ReplicatedStorage.Shared.Reach)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local DamageFeed = require(script.Parent.DamageFeed) -- W2-3 서버 확정 피해 방송
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)
local PlayerState = require(script.Parent.PlayerState)
local CombatResolution = require(script.Parent.CombatResolution)
local BuffState = require(script.Parent.BuffState)
local SummonState = require(script.Parent.SummonState)
local DashEndpoint = require(script.Parent.DashEndpoint)
local HealCast = require(script.Parent.HealCast)
local SkillStats = require(script.Parent.SkillStats)
local UltimateService = require(script.Parent.UltimateService) -- K1 궁극기(T)

local skillRequest = Instance.new("RemoteEvent")
skillRequest.Name = "SkillRequest"
skillRequest.Parent = ReplicatedStorage

-- 캐스트 결과 - Q는 kind="dash"로 한 번, E는 kind="tick"으로 채널링 중 tickCount번(20-2a
-- [3], PRD 4.3 "지속 타격") 나눠서 온다. ok=false면 거부(쿨다운 등) - reason만 있고
-- hits는 없다. 슬롯별 쿨다운 소스는 항상 이 이벤트다(SkillSlots.client.lua가 구독).
local skillCastResult = Instance.new("RemoteEvent")
skillCastResult.Name = "SkillCastResult"
skillCastResult.Parent = ReplicatedStorage

-- 결과 전송(P3b D) - 클라에 보내고, Studio 검증이 이 플레이어의 결과를 모으는 중이면(debugCapture) 같은 표를 쌓는다.
local debugCapture = {}
local function sendResult(player, slot, payload)
	skillCastResult:FireClient(player, slot, payload)
	if payload.ok and slot ~= "T" and payload.tickIndex == nil and payload.kind ~= "tick" and payload.kind ~= "ultHit" and payload.kind ~= "flurryTick" then -- Q12 이정표: 스킬 시전(틱 · 적중 · 덫 발동 빼고 - 리뷰) · 궁극기는 T 시전 성공 한 곳(아래)
		require(script.Parent.QuestService).note(player, "skill", 1)
		require(script.Parent.QuestService).note(player, "skill:" .. tostring(slot), 1) -- QUEUE-ALL3 Q3 초반 여정(새 스킬 E · R 써 보기)
	end
	local sink = debugCapture[player]
	if sink then
		table.insert(sink, { slot = slot, payload = payload })
	end
end

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
	sendResult(player, slot, { ok = false, reason = reason })
end

-- 몬스터 하나를 때린다 - 데미지 계산(계수×atk, 치명타는 calcDamage가 판정) + 적용 + 죽음
-- 처리(CombatResolution, AttackServer와 같은 경로). 여러 대상을 때리는 Q/E가 공유한다.
-- coefficient는 이미 "이번 타격 1회분"이다(E는 호출부가 tickCount로 미리 나눠서 넘긴다).
-- forceCrit·critDmgBonus(20-6, 쌍검 Q 확정 치명타) - 기본 nil이라 기존 호출부(대검 Q/E,
-- 이 아래 castLineAttack/castCircleChannel)는 그대로 동작한다.
-- committedAt(29-3, 선택): 이 타격이 속한 시전을 시작한 시각 - 채널링 틱만 넘긴다(즉발 스킬은 nil = 지금). 보스의 반사
-- 태세가 "태세가 선 뒤에 시작한 공격"만 반사하는 데 쓴다(이미 돌던 회전베기·난무는 0 피해로 끝날 뿐이다).
local function strikeTarget(player, classId, atk, target, coefficient, attackerStage, forceCrit, critDmgBonus, committedAt, extraDamage, noCharge)
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
	damage *= UltimateService.damageMultiplier(player) -- K1 대검 파괴의 화신(공격력 +30% = 최종 피해 배율)
	damage *= BuffState.getField(player, "warcryBuff", "multiplier", 1) -- K2 대검 전장의 포효(파티 공격력 +10%)
	damage += extraDamage or 0 -- K1 쌍검 궁극기: 표식이 모은 피해(이미 치명 · 버프가 곱해진 값 - 배율 뒤에 더한다 · 리뷰 4)
	-- 29-1: 둘째 반환값 = 실제로 들어간 피해(보스 파훼 게이트 ×g 반영) - 숫자·흡혈이 이 값을 쓴다.
	local hitPosition = target.PrimaryPart and target.PrimaryPart.Position -- W2-3 서버 적중 지점
	local isDead, dealt = MonsterState.applyDamage(target, damage, attackerStage, player, committedAt and { committedAt = committedAt } or nil)
	damage = dealt
	DamageFeed.emit(target, hitPosition, dealt, "skill", player, isCrit) -- W2-3(프로토타입 - 플래그 꺼짐)
	MonsterSpawner.updateHpLabel(target)
	PlayerProfile.applyLifesteal(player, damage) -- 26-2, AttackServer 평타와 같은 지점(damage 확정 직후)
	CombatResolution.resolveHit(player, target, isDead)
	local casterRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not noCharge then -- 궁극기 자신의 타격은 게이지를 다시 채우지 않는다(리뷰 3 - 연속 발동 방지)
		UltimateService.onDealt(player, classId, coefficient, damage, isCrit, casterRoot and hitPosition and (casterRoot.Position - hitPosition).Magnitude or 0, target) -- K1 충전(스킬 타격)
	end
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

-- K1: 궁극기 타격 = 스킬과 같은 피해 경로(치명 · 힐러 버프 · 보상 · 숫자). 결과는 슬롯 "T" 틱으로 클라에 보낸다(피해 숫자 · 적중 연출).
UltimateService.register(function(player, classId, target, coefficient, extraDamage)
	local weapon = PlayerProfile.getWeapon(player)
	if not weapon or not target.Parent or not MonsterState.getData(target) then
		return nil
	end
	local hit = strikeTarget(player, classId, SkillStats.attack(player, classId, weapon), target, coefficient, TutorialState.getMonsterStage(player), nil, nil, nil, extraDamage, true)
	sendResult(player, "T", { ok = true, kind = "ultHit", hits = { hit } })
	return hit
end, function(position) -- 리뷰 1: 궁극기 대상 후보 = 스킬과 같은 구역 필터
	return filterSameZone(position, MonsterState.getAllModels())
end)

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
	local coefficient = SkillStats.hitCoefficient(player, classId, slot, def) -- P3b D: 툴팁과 같은 함수(옵션 ×(1+x))
	local hits = {}
	for _, target in ipairs(targets) do
		table.insert(hits, strikeTarget(player, classId, atk, target, coefficient, attackerStage))
	end

	sendResult(player, slot, {
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

	sendResult(player, slot, {
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
	-- 26-2(PRD 20.67 [2] "속사 - 속사 공속 배율 ×(1+x), 기존 attackSpeedCap 유지") - 옵션
	-- 배율은 cap으로 자르기 전에 곱한다(상한은 그대로 2.5). P3b D: 식은 SkillStats 하나(툴팁과 같은 함수).
	local multiplier = SkillStats.quickShotMultiplier(player, classId, def)

	BuffState.apply(player, "quickShot", {
		durationSeconds = def.durationSeconds,
		value = multiplier,
		displayName = def.name,
		colorName = "ember",
	})

	sendResult(player, slot, {
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
	sendResult(player, slot, {
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
	-- P3d-F: 감속은 출처별 배율로 건다(옛 "시작 값 저장 → 끝에 되돌림"은 채널링 중 신발 · 보석 교체를 덮었다)
	local sourceKey = ("skill:%s:%s"):format(tostring(classId), tostring(slot))
	local function endChannel()
		PlayerState.setMoveSpeedMultiplier(player, sourceKey, nil)
		PlayerProfile.refreshMovementSpeed(player)
		PlayerState.clearIncomingDamageMultiplierSource(player, sourceKey)
		PlayerState.clearChanneling(player)
	end
	PlayerState.setMoveSpeedMultiplier(player, sourceKey, def.channelMoveSpeedMultiplier, def.channelSeconds + 0.5, PlayerProfile.refreshMovementSpeed) -- 끝 처리가 끊겨도 채널 뒤 저절로 풀린다
	PlayerProfile.refreshMovementSpeed(player)
	PlayerState.setIncomingDamageMultiplierUntil(player, def.incomingDamageMultiplier, def.channelSeconds, sourceKey, true) -- P3d-F B6: 출처 = 이 스킬(대시 · 복귀 보호와 곱해진다) · BR1-4a: 기술 감소(전멸기 · 기믹 피해에도 먹는다)
	-- 21-1 [1]-C: 채널링 중 평타 차단(PRD 4.3 "채널링 3초는 평타 시간에서 뺀다") - 이게
	-- 계수 프리미엄의 대가다. AttackServer가 PlayerState.isChanneling으로 거부한다.
	PlayerState.setChannelingUntil(player, def.channelSeconds)

	local tickInterval = def.channelSeconds / def.tickCount
	local castAt = os.clock() -- 29-3: 채널링을 시작한 시각(strikeTarget의 committedAt)
	-- 26-2(PRD 20.67 [2] "회전베기 - E 틱 피해 ×(1+x)").
	local perTickCoefficient = SkillStats.hitCoefficient(player, classId, slot, def) -- P3b D: 툴팁과 같은 함수(옵션 ×(1+x) ÷ 틱 수)

	for tickIndex = 1, def.tickCount do
		task.wait(tickInterval)

		-- 채널링 도중 캐릭터가 사라지면(사망·퇴장) 조용히 멈춘다 - WalkSpeed 복구는
		-- 캐릭터가 없으면 의미가 없으니 건너뛴다.
		character = player.Character
		humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not rootPart then
			endChannel()
			return
		end
		if PlayerState.isTrapped(player) then
			endChannel() -- P3d-F 전수 점검 C: 잡히면 채널링이 끝난다(옛: 잡힘이 채널링 칸만 지우고 틱 피해는 계속 들어갔다)
			return
		end

		local casterPosition = rootPart.Position
		local candidates = filterSameZone(casterPosition, MonsterState.getAllModels())
		local targets = SkillCombat.hitsInCircle(casterPosition, def.radiusStuds, candidates)

		local hits = {}
		for _, target in ipairs(targets) do
			table.insert(hits, strikeTarget(player, classId, atk, target, perTickCoefficient, attackerStage, nil, nil, castAt))
		end

		sendResult(player, slot, {
			ok = true,
			kind = "tick",
			tickIndex = tickIndex,
			tickCount = def.tickCount,
			casterPosition = casterPosition,
			radiusStuds = def.radiusStuds,
			hits = hits,
		})
	end

	endChannel()
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
	local durationSeconds = SkillStats.decoyDuration(player, "dualblade", def) -- P3b D: 툴팁과 같은 함수
	SummonState.spawn(player, def.summonId, decoy, durationSeconds)

	BuffState.apply(player, "guaranteedCrit", {
		durationSeconds = durationSeconds,
		displayName = def.name,
		colorName = "success",
	})

	sendResult(player, slot, {
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
	sendResult(player, slot, {
		ok = true,
		kind = "channelStart",
		cooldownSeconds = def.cooldownSeconds,
		channelSeconds = def.channelSeconds,
	})

	-- 21-1 [1]-C: 난무 1초 동안도 평타 차단(대검 회전베기와 같은 규칙 - 채널형 공통).
	-- 대상 사망·이탈로 일찍 끝나면 그 자리에서 풀어 평타를 바로 다시 열어 준다.
	PlayerState.setChannelingUntil(player, def.channelSeconds)

	local tickInterval = def.channelSeconds / def.tickCount
	local castAt = os.clock() -- 29-3: 채널링을 시작한 시각(strikeTarget의 committedAt)
	-- 26-2(PRD 20.67 [2] "난무 - E 틱 피해 ×(1+x)").
	local perTickCoefficient = SkillStats.hitCoefficient(player, classId, slot, def) -- P3b D: 툴팁과 같은 함수(옵션 ×(1+x) ÷ 틱 수)

	for tickIndex = 1, def.tickCount do
		task.wait(tickInterval)

		local character = player.Character
		local rootNow = character and character:FindFirstChild("HumanoidRootPart")
		if not rootNow then
			PlayerState.clearChanneling(player)
			return -- 캐스터가 사라졌다(사망·퇴장) - 조용히 멈춘다(castCircleChannel과 같은 가드)
		end
		if PlayerState.isTrapped(player) then
			PlayerState.clearChanneling(player)
			return -- P3d-F 전수 점검 C: 잡히면 난무도 끝난다
		end

		if not (lockedTarget.Parent and MonsterState.getData(lockedTarget)) then
			PlayerState.clearChanneling(player)
			return -- 대상이 이미 죽었거나 사라졌다 - 남은 타격은 손실(재탐색 안 함)
		end
		local targetRoot = lockedTarget.PrimaryPart
		if not targetRoot or not Reach.withinModel(lockedTarget, targetRoot.Position, rootNow.Position, def.rangeStuds) then -- Q1 리뷰: 고른 판정(AimPicker)과 같은 몸 반경
			PlayerState.clearChanneling(player)
			return -- 대상이 사거리를 벗어났다(22-4: 수평 거리 + 높이차 상한)
		end

		local forceCrit, critDmgBonus = nil, nil
		if tickIndex <= (def.guaranteedCritHits or 0) then
			forceCrit, critDmgBonus = resolveGuaranteedCrit(player, classId)
		end

		local hit = strikeTarget(player, classId, atk, lockedTarget, perTickCoefficient, attackerStage, forceCrit, critDmgBonus, castAt)

		sendResult(player, slot, {
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
-- cooldownSeconds(26-2)는 castDashBuff와 같은 이유로 dispatch가 넘긴다. 회복 · 버프 · 파티 회복(S13)의
-- 서버 판정은 HealCast 모듈이 한다(자동 검증이 실제 경로를 밟게 모듈로 뺐다).
local function castHeal(player, slot, def, classId, cooldownSeconds)
	markCast(player, slot)
	local shieldMode = HealCast.usesShield(player, def)
	local healAmount, isCrit, healed, shielded = HealCast.cast(player, def, classId, cooldownSeconds)
	-- K1 치유사 충전: 받은 사람 수 × 한 사람 몫(최대 체력 비율)
	local share = def.healPercentOfMaxHp * HealCast.healingPower(player) * (shieldMode and def.shield and def.shield.healRatio or 1)
	UltimateService.onHeal(player, share * (1 + #(healed or {}) + #(shielded or {})), 1)

	sendResult(player, slot, {
		ok = true,
		kind = "heal",
		cooldownSeconds = cooldownSeconds,
		hits = {},
		-- S13b: 딜링모드 쉴드 시전이면 healAmount = 0이고 shieldMode = true - 클라는 숫자 대신 링만 그린다.
		self = { healAmount = healAmount, isCrit = isCrit, shieldMode = shieldMode },
	})
end

-- ═══ K2 R 스킬(묶음 F3) ═══
local function nearestMonster(position, rangeStuds)
	local best, bestD = nil, rangeStuds
	for _, model in ipairs(filterSameZone(position, MonsterState.getAllModels())) do
		local data = MonsterState.getData(model)
		local root = model.PrimaryPart
		if root and data and not data.isChest and not data.isRescueTarget then
			local d = Reach.horizontalDistance(root.Position, position)
			if d <= bestD then
				best, bestD = model, d
			end
		end
	end
	return best
end

-- 쌍검 암영 표식: 20 stud 안 가장 가까운 대상 뒤로 순간이동(이동 = 클라 재생 · 대시 결과와 같은 모양) + 6초 표식(그 대상에게 치명 +20%p - AttackServer)
local function castShadowMark(player, slot, def, rootPart, cooldownSeconds)
	local target = nearestMonster(rootPart.Position, def.rangeStuds)
	if not target then
		reject(player, slot, "no_target") -- 대상이 없으면 쿨을 쓰지 않는다
		return
	end
	markCast(player, slot)
	local tpos = target.PrimaryPart.Position
	local away = Vector3.new(tpos.X - rootPart.Position.X, 0, tpos.Z - rootPart.Position.Z)
	local direction = away.Magnitude > 1e-3 and away.Unit or Vector3.new(0, 0, 1)
	local finalEnd = computeDashEndpoint(player, rootPart.Position, direction, away.Magnitude + def.behindStuds)
	BuffState.apply(player, "shadowMark", { durationSeconds = def.markSeconds, target = target, critRateBonus = def.critRateBonus, displayName = def.name, colorName = "danger" })
	target:SetAttribute("ShadowMarkBy", player.UserId)
	task.delay(def.markSeconds, function()
		if target.Parent and target:GetAttribute("ShadowMarkBy") == player.UserId then
			target:SetAttribute("ShadowMarkBy", nil)
		end
	end)
	sendResult(player, slot, { ok = true, kind = "dash", cooldownSeconds = cooldownSeconds, startPosition = rootPart.Position, endPosition = finalEnd, durationSeconds = def.durationSeconds, hits = {} })
end

-- 활 사냥꾼의 덫: 클릭 지점(40 stud 안)에 설치 · 최대 2개(넘으면 가장 오래된 것 제거) · 20초. 몹이 반경 안에 들어오면 1회 발동:
--   잡몹 = 피해(계수) + 2초 속박 · 보스 = 속박 대신 받는 피해 +10% 4초(MonsterState.setVulnerable - 모든 공격자).
local traps = {} -- [Player] = { { position, untilAt, part, def } }
local function castHunterTrap(player, slot, def, rootPart, aimPoint, cooldownSeconds)
	if typeof(aimPoint) ~= "Vector3" or aimPoint ~= aimPoint or Reach.horizontalDistance(aimPoint, rootPart.Position) > def.maxCastStuds then
		reject(player, slot, "aim")
		return
	end
	markCast(player, slot)
	traps[player] = traps[player] or {}
	local list = traps[player]
	if #list >= def.maxTraps then
		local old = table.remove(list, 1)
		if old.part then
			old.part:Destroy()
		end
	end
	local part = Instance.new("Part")
	part.Name = "HunterTrap"
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(0.3, def.triggerRadiusStuds * 2, def.triggerRadiusStuds * 2)
	part.CFrame = CFrame.new(aimPoint) * CFrame.Angles(0, 0, math.rad(90))
	part.Color = UIColors.classAccent.bow or Color3.fromRGB(120, 220, 120)
	part.Material = Enum.Material.Neon
	part.Transparency = 0.55
	part.Parent = Workspace
	table.insert(list, { position = aimPoint, untilAt = os.clock() + def.lifeSeconds, part = part, def = def })
	sendResult(player, slot, { ok = true, kind = "trap", cooldownSeconds = cooldownSeconds, position = aimPoint, hits = {} })
end

game:GetService("RunService").Heartbeat:Connect(function()
	local now = os.clock()
	for player, list in pairs(traps) do
		for i = #list, 1, -1 do
			local trap = list[i]
			local fired = false
			if now < trap.untilAt and player.Parent then
				for _, model in ipairs(filterSameZone(trap.position, MonsterState.getAllModels())) do -- 리뷰 1: 구역 필터 · 같은 층
					local root = model.PrimaryPart
					local data = MonsterState.getData(model)
					if root and data and not data.isChest and not data.isRescueTarget and Reach.horizontalDistance(root.Position, trap.position) <= trap.def.triggerRadiusStuds and Reach.sameLayer(root.Position, trap.position) then
						fired = true
						if data.isBoss then
							MonsterState.setVulnerable(model, 1 + trap.def.bossDamageTakenBonus, trap.def.bossDebuffSeconds)
						else
							MonsterState.setRooted(model, trap.def.rootSeconds)
							local weapon = PlayerProfile.getWeapon(player)
							local classId = PlayerProfile.getClassId(player)
							if weapon and classId then
								local hit = strikeTarget(player, classId, SkillStats.attack(player, classId, weapon), model, trap.def.coefficient, TutorialState.getMonsterStage(player))
								sendResult(player, "R", { ok = true, kind = "ultHit", hits = { hit } })
							end
						end
						print(("[K2] 사냥꾼의 덫 발동: %s → %s(%s)"):format(player.Name, model.Name, data.isBoss and "보스 약점" or "속박"))
						break
					end
				end
			end
			if fired or now >= trap.untilAt or not player.Parent then
				if trap.part then
					trap.part:Destroy()
				end
				table.remove(list, i)
			end
		end
	end
end)

-- 대검 전장의 포효: 반경 12 잡몹 도발 3초(나를 쫓게 - 보스 도발은 BossPatterns.onTaunt 훅 단계) · 자신 받는 피해 ×0.75 5초 · 파티 공격력 +10% 6초
local function castWarcry(player, slot, def, rootPart, cooldownSeconds)
	markCast(player, slot)
	local taunted = 0
	for _, model in ipairs(SkillCombat.hitsInCircle(rootPart.Position, def.radiusStuds, filterSameZone(rootPart.Position, MonsterState.getAllModels()))) do
		local data = MonsterState.getData(model)
		if data and not data.isBoss and not data.isChest and not data.isRescueTarget then
			MonsterState.setAiState(model, "chasing")
			MonsterState.setAiTarget(model, player)
			taunted += 1
		end
	end
	PlayerState.setIncomingDamageMultiplierUntil(player, def.selfIncomingMultiplier, def.selfSeconds, "skill:greatsword:R")
	local PartyState = require(script.Parent.PartyState)
	local party = PartyState.getParty(player)
	for _, member in ipairs(party and PartyState.getMemberPlayers(party) or { player }) do
		if typeof(member) == "Instance" then
			BuffState.apply(member, "warcryBuff", { durationSeconds = def.partySeconds, multiplier = 1 + def.partyAttackBonus, displayName = def.name, colorName = "ember" })
		end
	end
	print(("[K2] 전장의 포효: %s 도발 %d"):format(player.Name, taunted))
	sendResult(player, slot, { ok = true, kind = "tick", cooldownSeconds = cooldownSeconds, casterPosition = rootPart.Position, radiusStuds = def.radiusStuds, hits = {}, taunted = taunted })
end

-- 치유사 구원의 기도: 반경 20 파티원(자신 포함) 최대 체력 30% 회복 · 부활은 K3(영혼 상태) 뒤
local function castPrayer(player, slot, def, rootPart, cooldownSeconds)
	markCast(player, slot)
	local PartyState = require(script.Parent.PartyState)
	local party = PartyState.getParty(player)
	local healedCount = 0
	for _, member in ipairs(party and PartyState.getMemberPlayers(party) or { player }) do
		local character = typeof(member) == "Instance" and member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local hp, maxHp = PlayerState.getHp(member), PlayerState.getMaxHp(member)
		if root and require(script.Parent.SoulService).isSoul(member) and Reach.horizontalDistance(root.Position, rootPart.Position) <= def.radiusStuds then
			require(script.Parent.SoulService).revive(member, "구원의 기도") -- Q8 K3: 기도 = 반경 안 영혼 부활(회복 대신)
			healedCount += 1
		elseif root and hp and hp > 0 and maxHp and Reach.horizontalDistance(root.Position, rootPart.Position) <= def.radiusStuds then
			local newHp = math.min(hp + maxHp * def.healMaxHpFraction, maxHp)
			PlayerState.setHp(member, newHp)
			require(script.Parent.PlayerDamage).syncHud(member)
			healedCount += 1
			UltimateService.onHeal(player, newHp - hp, maxHp) -- K1 충전 = 실제 회복량(만피 파티원은 0 - 리뷰 2)
		end
	end
	print(("[K2] 구원의 기도: %s 회복 %d명"):format(player.Name, healedCount))
	sendResult(player, slot, { ok = true, kind = "tick", cooldownSeconds = cooldownSeconds, casterPosition = rootPart.Position, radiusStuds = def.radiusStuds, hits = {}, healed = healedCount })
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
			investmentScaling = def.investmentScaling, -- P2.5a D(결정 8) - AttackServer가 PlayerCombat.getInvestmentScale로 읽는다
			displayName = def.name,
			colorName = "danger",
		})
	end

	sendResult(player, slot, {
		ok = true,
		kind = "toggle",
		cooldownSeconds = def.cooldownSeconds,
		active = not wasActive,
		hits = {},
	})
end

local function handleSkill(player, slot, aimPoint)
	if slot ~= "Q" and slot ~= "E" and slot ~= "R" and slot ~= "T" then
		return
	end
	if require(script.Parent.SoulService).rejectAction(player, "스킬 " .. slot) then -- Q8: 영혼 = 스킬 · 궁극기 불가(서버 거부)
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
	-- K1 궁극기(T): 게이지 · 대상 · 조준 검사 = UltimateService.cast(서버 판정 - 클라는 "쓰겠다" + 클릭 지점만)
	if slot == "T" then
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end
		local ok, result = UltimateService.cast(player, classId, rootPart, aimPoint)
		if ok then
			result.ok = true
			sendResult(player, slot, result)
			require(script.Parent.QuestService).note(player, "ult", 1) -- Q12 이정표: 궁극기 맛보기
		else
			reject(player, slot, result)
		end
		return
	end

	local classSkills = SkillData[classId]
	local def = classSkills and classSkills[slot]
	if not def then
		return
	end
	def = SkillStats.effectiveDef(player, classId, slot, def) -- QUEUE-10h Q9 K4: 범위 변형(사거리 · 반경만 - 사본)

	-- 26-2(PRD 20.67 [2] "백스텝샷/치유 - 쿨다운 ×(1-x)") - 옵션 baseValue가 음수라 1+합산이
	-- 곧 (1-x)다(Option.sumWithCap이 상한을 ±50%로 대칭 clamp해 0 이하로 못 내려간다). 이
	-- 두 슬롯 외에는 1(옵션 없음)로 원래 쿨다운 그대로다.
	local cooldownSeconds = SkillStats.cooldown(player, classId, slot, def) -- P3b D: 식은 SkillStats 하나(툴팁과 같은 함수)
	if isOnCooldown(player, slot, cooldownSeconds) then
		reject(player, slot, "cooldown")
		return
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		return
	end

	local atk = SkillStats.attack(player, classId, weapon) -- P2.5a R5: 최종 데미지 버킷 · P2.5b D: 마일스톤 영구 배율 · P3b D: 툴팁과 같은 함수
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
	elseif def.shape == "shadowMark" then -- K2 R(대상 없으면 거부 - 쿨 안 씀)
		castShadowMark(player, slot, def, rootPart, cooldownSeconds)
	elseif def.shape == "hunterTrap" then
		castHunterTrap(player, slot, def, rootPart, aimPoint, cooldownSeconds)
	elseif def.shape == "warcry" then
		castWarcry(player, slot, def, rootPart, cooldownSeconds)
	elseif def.shape == "prayer" then
		castPrayer(player, slot, def, rootPart, cooldownSeconds)
	end
end
skillRequest.OnServerEvent:Connect(handleSkill)

-- Studio 검증 전용(P3b D3 - 툴팁 값 = 실제 피해 대조): 클라 요청과 같은 handleSkill을 서버에서 부르고 그 시전의 결과 이벤트를 모아 돌려준다.
-- 쿨다운 기록은 지우고 시작한다(검증이 연달아 여러 스킬을 쓴다). 채널형은 채널이 끝날 때까지 기다린다(handleSkill이 그 동안 양보한다).
if game:GetService("RunService"):IsStudio() then
	local debugCast = Instance.new("BindableFunction")
	debugCast.Name = "SkillCastDebug"
	debugCast.Parent = game:GetService("ServerStorage")
	debugCast.OnInvoke = function(player, slot, aimPoint)
		lastCastTick[player] = nil
		debugCapture[player] = {}
		local ok, err = pcall(handleSkill, player, slot, aimPoint) -- K1: T는 클릭 지점(위조 검사)
		local captured = debugCapture[player]
		debugCapture[player] = nil
		return ok and captured or { error = tostring(err) }
	end
end

Players.PlayerRemoving:Connect(function(player)
	for _, trap in ipairs(traps[player] or {}) do
		if trap.part then
			trap.part:Destroy()
		end
	end
	traps[player] = nil
	lastCastTick[player] = nil
	debugCapture[player] = nil
end)

print("[forge-game] SkillServer 로드됨 - 검사 Q/E, 궁수 Q/E, 도적 Q(그림자분신)/E(난무), 치유사 Q(치유)/E(딜링모드) 판정 활성")
