-- 보스 스킬 상태 머신(21-3 → 29-2 재편, PRD-forge-game-roblox.md 20.75). MonsterAI.server.lua가 매 Heartbeat마다
-- step()을 부르고, 반환값이 true(스킬 진행 중 - 보스 구속)면 추격·평타를 건너뛴다. 판정은 전부 서버가 한다 -
-- 클라는 어떤 상태도 보고하지 않고(점프 여부조차), BossPatternEvent로 받은 예고·연출만 그린다
-- (BossPatternVisuals.client.lua).
--
-- 29-2: 두 가지가 이 파일에서 빠져나갔다.
--   · "어느 스킬을 언제 시작하는가" → shared/BossScheduler.lua(쿨타임 + 우선순위 + 전역 쿨 + 굶주림 + 연속 금지 +
--     자리 비우기). 모형(BossSim)과 같은 함수를 쓴다. 이 파일은 시계(os.clock)와 발동 조건의 실제 값을 댈 뿐이다.
--   · "스킬 하나가 어떻게 도는가" → 아래 HANDLERS 표. 키는 스킬의 primitive(circleBoss·ring·circleTarget·charge·
--     line·gimmick)이고 보스 이름이 들어간 함수는 없다(CLAUDE.md "조각 조합으로 정의한다"). 같은 핸들러가
--     파라미터만 달리 받아 6종의 스킬을 전부 처리한다 - 기본형 강공격과 서리 거인의 빙결 강타, 심해 군주의
--     도넛 휩쓸기, 수정 여왕의 2연속 펄스가 전부 circleBoss다.
--
-- 상태는 MonsterState.getBossPatternState(model)이 돌려주는 테이블 하나에 산다 - 보스가 죽거나 물러나
-- MonsterState.clear가 불리면 같이 사라진다. 겹침 방지: phase가 "normal"일 때만 새 스킬을 고른다.
--
-- 22-4 높이 규칙(PRD 20.50 [2]): 모든 판정은 XZ 수평 + |ΔY| ≤ TerrainConfig.heightToleranceStuds. 파동·원·직선은
-- "그 스킬의 지면 Y"(보스 발밑 또는 낙하점 지면) 기준이라 8 넘게 높은 언덕 위에는 닿지 않는다. 돌진 이동은 매 틱
-- 지면 Y를 따르고, 경사 한계를 넘는 단차를 만나면 그 자리에서 끝난다(헤롱 시작).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local PlayerState = require(script.Parent.PlayerState)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local GroundProbe = require(script.Parent.GroundProbe)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossScheduler = require(ReplicatedStorage.Shared.BossScheduler)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossMechanics = require(script.Parent.BossMechanics)
-- 29-3: 동적 지형의 논리 상태(얼음 기둥). 이 파일은 스킬의 "결과 조각"(onImpact·onResolve·blockedByProp)을 실행하고
-- 바뀐 내용을 멤버에게 알린다. 보스별 파훼 판정·구출 동작은 BossGimmicks가 뼈대의 훅에 꽂는다(require만 하면 된다).
local BossArenaProps = require(script.Parent.BossArenaProps)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local BossTrap = require(script.Parent.BossTrap)
-- 29-5: 분열의 분신은 구출 대상(얼음 덩어리)과 같은 타격 대상 엔티티다(MonsterSpawner.spawnRescueTarget).
local MonsterSpawner = require(script.Parent.MonsterSpawner)
require(script.Parent.BossGimmicks)
-- P3a C: 원형 아레나의 자르기(ArenaShape) · 구조물(돌진 충돌 · 뺑뺑이 방지 · 기믹 지형이 구조물 위에 서지 않게).
local ArenaShape = require(ReplicatedStorage.Shared.ArenaShape)
local ArenaContainment = require(ReplicatedStorage.Shared.ArenaContainment) -- P3c A5: 넉백 상한 · 착지 경계(클라와 같은 함수)
local BossArenaMap = require(script.Parent.BossArenaMap)
local BossArenaMapData = require(ReplicatedStorage.Shared.data.BossArenaMapData)
local BossArenaContainment = require(script.Parent.BossArenaContainment) -- P3d B2: 맵 이탈 복귀 보호(넉백 건너뛰기)
local HeightGuard = require(script.Parent.HeightGuard) -- G2a: 넉백 · 회오리 동안 서버 높이 검증 예외
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)

local BossPatterns = {}

-- 클라 연출 채널. 아레나 안 멤버 전원(st.members - 24-1 파티, 솔로면 그 한 명)에게 보낸다.
local patternEvent = Instance.new("RemoteEvent")
patternEvent.Name = "BossPatternEvent"
patternEvent.Parent = ReplicatedStorage

local scatterRng = Random.new()

local function xz(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- 보스가 속한 아레나 zone(WorldConfig.zones.bossArenaN). 없으면(DevTools로 사냥터에 띄운 경우 등) 스폰 지점
-- 중심의 같은 크기 정사각형으로 대신한다.
local function zoneOf(model)
	local zone = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if zone then
		return zone
	end
	return { center = xz(MonsterState.getSpawnPosition(model)), halfSize = WorldConfig.bossArena.halfSizeStuds }
end

-- origin에서 XZ 단위벡터 dir 방향으로 아레나(margin만큼 안쪽) 안에 머무는 최대 거리.
-- 돌진 도착점·직선 길이가 이걸로 잘려 담장 밖으로 절대 안 나간다. P3a C: 원형 아레나는 원까지(ArenaShape - 정사각형 구역은 옛 AABB 그대로).
local function clipToZone(origin, dir, zone, margin)
	return ArenaShape.clip(zone, origin, dir, margin)
end

local function clampToZone(position, zone, margin)
	return ArenaShape.clamp(zone, position, margin)
end

-- 대상 원(circleTarget)의 자리를 벽 안쪽으로 누르는 여백. 원형 아레나 = BossArenaMapData.geometry.circleTargetMarginStuds(0 - P3a C2 측정: 여백 2면 벽 1stud의
-- 대상 곁 독침이 48칸 중 3칸 실패, 0이면 0칸), 옛 정사각형 구역(DevTools로 사냥터에 띄운 보스) = 옛 값 2.
local function circleTargetMargin(zone)
	return zone.radius and BossArenaMapData.geometry.circleTargetMarginStuds or 2
end

-- 점 p에서 선분 a-b(XZ)까지의 거리.
local function distanceToSegment(p, a, b)
	local ab = b - a
	local len2 = ab:Dot(ab)
	if len2 < 1e-6 then
		return (p - a).Magnitude
	end
	local t = math.clamp((p - a):Dot(ab) / len2, 0, 1)
	return (p - (a + ab * t)).Magnitude
end

-- 공중 판정(ring). 21-3 실측(서버 시점): Humanoid 상태(Jumping/Freefall)는 점프 시작 순간 즉시 복제되지만
-- FloorMaterial은 약 0.2초 늦고 착지 상태는 아직 3~6stud 높이에서 먼저 바뀐다 - 그래서 "지면 거리"를 레이캐스트로
-- 직접 재는 것을 주 판정으로, 상태는 점프 시작 직후의 보조 판정으로만 쓴다.
local function isAirborne(character, clearanceStuds)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then
		return false
	end
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall then
		return true
	end
	local standing = humanoid.HipHeight + rootPart.Size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = Workspace:Raycast(rootPart.Position, Vector3.new(0, -(standing + clearanceStuds + 2), 0), params)
	return hit == nil or hit.Distance > standing + clearanceStuds
end

local function floorYUnder(position)
	-- 22-4: 지면 폴더만 본다(GroundProbe) - 옛 무필터 Raycast는 보스 자기 몸통을 맞힐 수 있었다.
	return GroundProbe.surfaceY(position.X, position.Z, position.Y) or (position.Y - TerrainConfig.monsterFootOffsetStuds)
end

local function setBodyColor(model, color)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = color
	end
end

-- P3a D1 계측(자동 검증 전용 - 평소엔 nil이라 아무 일도 안 한다). debugSendHook(kind, payload, 서버 시각) = 멤버에게 보낸 모든 예고 · 연출.
-- debugJudgeHook(record) = 장판 판정 한 번(원 · 강타 · 직선): { at, serverTime, skill, primitive, shape, members, hits = { [멤버] = 들어간 피해 }, floorY, model }.
-- 둘 다 검증(P3aVerify D)이 "보인 장판 = 판정"을 멤버마다 대조할 때만 건다.
BossPatterns.debugSendHook = nil
BossPatterns.debugJudgeHook = nil
-- P3c D 계측(자동 검증 전용 - 평소엔 nil): debugEventHook(kind, record) - "chargeTarget"(돌진 대상 확정 · 전조 시작) · "launch"(넉백 높이 · 거리 · 함께 맞은 수) ·
-- "trackLock"(번개 추적 고정 자리) · "chargeHit"(돌진 판정 - 몇 번째 돌진인가).
BossPatterns.debugEventHook = nil

local function debugEvent(kind, record)
	if BossPatterns.debugEventHook then
		BossPatterns.debugEventHook(kind, record)
	end
end
local judgeHits = nil

local function send(st, kind, payload)
	if BossPatterns.debugSendHook then
		BossPatterns.debugSendHook(kind, payload, serverNow(), st)
	end
	for _, member in ipairs(st.members or {}) do
		if typeof(member) == "Instance" and member.Parent then -- 자동 검증의 스탠드인 멤버(테이블)에게는 보내지 않는다
			patternEvent:FireClient(member, kind, payload)
		end
	end
end

-- 한 사람에게만(29-4: 내 단이 가라앉는 시계처럼 그 사람의 화면에만 뜻이 있는 사실).
local function sendTo(player, kind, payload)
	if typeof(player) == "Instance" and player.Parent then
		patternEvent:FireClient(player, kind, payload)
	end
end

-- 아레나 kit의 논리 구역(tag가 붙은 정적 파트 - 심해 군주의 단·폭풍 군주의 피뢰침). kit은 보스전 내내 그대로라 한 번만 만든다.
local function kitZones(model, st, data, tag)
	st.kitZones = st.kitZones or {}
	local zones = st.kitZones[tag]
	if not zones then
		zones = BossPropMath.kitZones(data.arenaKit, zoneOf(model).center, st.floorY, tag)
		st.kitZones[tag] = zones
	end
	return zones
end

-- 24-1 파티: 판정 대상 = 아레나 안 멤버 전원(각자 따로 맞는다). 캐릭터가 없거나 이미 죽은 멤버는 뺀다.
-- P3a D3: 바닥 장판(원 · 강타 · 직선 · 돌진)의 높이 판정은 **발** 높이로 잰다. 높이차 상한 8의 뜻은 "점프(7.2)로 닿는 높이는 같은 층"(TerrainConfig)인데,
-- 루트(발 + 약 3)로 재면 점프 도중 약 0.25초 동안 바닥 장판 판정에서 빠졌다(P3a D1 실측 - 원 안에 보이는데 판정 없음). 진동파(ring)는 점프로 피하는 게
-- 규칙이라 그대로 루트 · 공중 판정을 쓴다. 발 = 루트 − (HipHeight + 루트 반높이). 스탠드인(테이블)은 Humanoid가 없어 기본 서 있는 높이 3을 뺀다.
local STANDING_ROOT_HEIGHT = 3

local function feetOf(character, root)
	local humanoid = character.FindFirstChildOfClass and character:FindFirstChildOfClass("Humanoid")
	local standing = (humanoid and root.Size) and (humanoid.HipHeight + root.Size.Y / 2) or STANDING_ROOT_HEIGHT
	return root.Position - Vector3.new(0, standing, 0)
end

-- 보스 모델 루트(발 + monsterFootOffset) → 보스의 발(바닥 판정의 기준 높이).
local function footOf(position)
	return Vector3.new(position.X, position.Y - TerrainConfig.monsterFootOffsetStuds, position.Z)
end

-- G1-0(D0 추가 2 · 기존 문제 1): 바닥 판정(보스 중심 원 · 원 장판 · 돌진 · 직선 · 마무리)의 높이 기준 = **발밑 지면**. 단상(윗면 3.5) 위에서 1단 점프만 해도
-- 발이 아레나 바닥 기준 8을 넘는 0.33초 동안 판정이 빠졌다(보이는 장판 = 판정 위반). 단상 발자국 위에서 윗면 이상에 있으면 발 높이에서 단상 높이를 빼고 잰다 -
-- 평지 점프와 같은 "지면 + 7.2"가 된다. 지진파(단상 밑으로 지나감)와 재생성 접촉은 실제 발(feet)을 그대로 쓴다.
function BossPatterns.groundFeet(zoneKey, floorY, feet)
	local id = zoneKey and BossArenaMap.daisUnderFeet(zoneKey, feet)
	if not id then
		return feet
	end
	return feet - Vector3.new(0, BossArenaMap.obstacleTop(zoneKey, id) - (floorY or 0), 0)
end

local function groundFeetOf(st, feet)
	return BossPatterns.groundFeet(st.zoneKey, st.floorY, feet)
end

local function victims(st)
	local list = {}
	for _, member in ipairs(st.members or {}) do
		local character = member.Parent and member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (PlayerState.getHp(member) or 0) > 0 then
			local feet = feetOf(character, root)
			table.insert(list, { player = member, root = root, feet = feet, groundFeet = groundFeetOf(st, feet) })
		end
	end
	return list
end

-- 판정 한 번의 피해. attack 배율은 감소식을 거친 피해에 곱한다(21-3 - 방어가 먹힌다). %최대체력은 방어를
-- 무시하고, 한 번의 발동에서 한 사람이 받는 합이 mechanics.gimmickFailMaxHpFraction을 넘지 않는다(BossMechanics).
local function applySkillDamage(model, data, skill, player)
	local damage = skill.damage
	local dealt
	if damage.kind == "maxHp" then
		dealt = BossMechanics.applyGimmickDamage(model, player, damage.fraction, skill.damageLabel)
	else
		dealt = PlayerDamage.applyHit(player, data.attack, skill.damageLabel, damage.multiplier)
		if dealt > 0 then
			BossTrap.noteSkillHit(player) -- 29-5: 예고가 있는 피격은 누르고 있던 구출을 처음으로 돌린다(%피해 쪽은 BossMechanics가 부른다)
		end
	end
	if judgeHits then
		judgeHits[player] = (judgeHits[player] or 0) + (dealt or 0) -- P3a D1 계측: 판정이 이 사람에게 닿았다(피해 0이어도 판정은 있었다)
	end
end

-- P3a D1 계측: 판정 한 번의 시작 · 끝(훅이 없으면 아무것도 안 한다).
local function judgeBegin()
	if BossPatterns.debugJudgeHook then
		judgeHits = {}
	end
end

local function judgeEnd(c, shape)
	local hook, hits = BossPatterns.debugJudgeHook, judgeHits
	judgeHits = nil
	if hook and hits then
		hook({ at = os.clock(), serverTime = serverNow(), skill = c.st.current, primitive = c.skill and c.skill.primitive, shape = shape,
			members = c.st.members, hits = hits, floorY = c.st.floorY, model = c.model })
	end
end

-- 헤롱 자세 해제 - 똑바로 세운다(돌진 종료·중단·리셋 공통).
local function clearDaze(model, st)
	if st.dazeBase then
		model:PivotTo(CFrame.new(st.dazeBase))
		st.dazeBase = nil
	end
end

-- ─────────────────────────── 발동 조건(실제 월드) ───────────────────────────
-- 조각의 뜻은 BossScheduler.lua 주석. notAfter는 스케줄러가 직접 판정한다.
local function conditionMet(model, st, data, condition)
	local kind = condition.type
	if kind == "hpBelow" then
		return MonsterState.getHpRatio(model) <= condition.value
	elseif kind == "hpAbove" then
		return MonsterState.getHpRatio(model) > condition.value
	elseif kind == "targetWithin" or kind == "targetBeyond" then
		local targetRoot = st.targetRoot
		if not targetRoot then
			return false
		end
		local distance = Reach.horizontalDistance(targetRoot.Position, st.position)
		if kind == "targetWithin" then
			return distance <= condition.studs
		end
		return distance > condition.studs
	elseif kind == "membersClustered" then
		local list = victims(st)
		for _, a in ipairs(list) do
			local near = 0
			for _, b in ipairs(list) do
				if Reach.horizontalDistance(a.root.Position, b.root.Position) <= condition.studs then
					near += 1
				end
			end
			if near >= condition.count then
				return true
			end
		end
		return false
	elseif kind == "gateArmed" then
		return BossMechanics.isGateArmed(model) == condition.value
	elseif kind == "gateArmedFor" then
		return BossMechanics.gateArmedSeconds(model) >= condition.seconds
	elseif kind == "membersNearSafeSpot" then
		-- 29-3 선행 조건(포효): 살아 있는(안 잡힌) 멤버 전원에게 studs 안에 그 지형의 "뒤 자리"가 있는가. 지형이 하나도
		-- 없으면 거리가 무한대라 거짓이다 - 스케줄러가 포효 대신 낙빙을 시작한다(BossScheduler 규칙 ⑦).
		for _, v in ipairs(victims(st)) do
			if not BossTrap.isTrapped(v.player)
				and BossArenaProps.nearestSafeSpot(model, condition.prop, st.position, v.root.Position, condition.marginStuds) > condition.studs then
				return false
			end
		end
		return true
	elseif kind == "memberWithin" then
		-- 29-5 분열: 성공이 파티 단위(한 명이 진짜를 때리면 전원이 산다)라 닿을 수 있는 사람이 한 명이면 된다.
		for _, v in ipairs(victims(st)) do
			if not BossTrap.isTrapped(v.player) and Reach.horizontalDistance(v.root.Position, st.position) <= condition.studs then
				return true
			end
		end
		return false
	elseif kind == "membersNearZone" then
		-- 29-4 과충전: 살아 있는(안 잡힌) 멤버 전원이 그 kit 구역(피뢰침)에서 studs 안인가 - 예고 안에 안전지대에 닿을 수 없는
		-- 사람이 하나라도 있으면 쏘지 않는다(피할 수 없는 과충전은 없다).
		local zones = kitZones(model, st, data, condition.tag)
		for _, v in ipairs(victims(st)) do
			if not BossTrap.isTrapped(v.player) then
				local nearest = math.huge
				for _, zone in ipairs(zones) do
					nearest = math.min(nearest, Reach.horizontalDistance(v.root.Position, zone.center))
				end
				if nearest > condition.studs then
					return false
				end
			end
		end
		return true
	end
	return true
end

-- 시계를 "지금"부터 새로 잰다 - 스폰·어그로 시작·사망 리셋 때 부른다(재도전 = 처음부터).
-- 견습 모드는 data.skills가 부분집합이다(BossRules.buildTutorialInstanceData) - 없는 스킬은 시계 자체가 없다.
local function restartClocks(st, data, now)
	st.sched = BossScheduler.newState(data.skills, data.skillOrder, now)
end

local function ensureState(model, data)
	local st = MonsterState.getBossPatternState(model)
	if st and not st.phase then
		local now = os.clock()
		st.phase = "normal"
		st.phaseEndsAt = 0
		st.graceUntil = now + (data.scheduler.entryGraceSeconds or 0)
		st.waves = {}
		st.floorY = floorYUnder(MonsterState.getSpawnPosition(model))
		st.zoneKey = MonsterState.getZoneKey(model) -- G1-0: 바닥 판정의 발밑 지면(단상)을 찾을 때(victims)
		st.position = MonsterState.getSpawnPosition(model)
		-- 스케줄러에 넘기는 문맥은 한 번만 만든다(매 틱 클로저를 새로 만들지 않는다).
		st.pickCtx = {
			conditionMet = function(condition)
				return conditionMet(model, st, data, condition)
			end,
			boundSeconds = function(id)
				return BossSkillMath.boundSeconds(data.skills[id], zoneOf(model).halfSize)
			end,
		}
		restartClocks(st, data, now)
	end
	return st
end

local runEffects -- 아래 "결과 조각"에서 정의한다(endSkill이 onEnd 조각을 돌린다)

local function endSkill(model, st, data, now, interrupted)
	local id = st.current
	if id then
		print(("[forge-game] 보스 패턴 종료: %s (%.2f초 소요)"):format(id, now - (st.currentStartedAt or now)))
	end
	-- 29-3: 스킬이 어떻게 끝나든(정상·중단·리셋) onEnd 조각이 돈다 - 그 스킬이 깔아 둔 것(모래 구덩이)을 치우는 자리.
	if st.skill and st.skill.onEnd then
		runEffects({ model = model, st = st, data = data, position = st.position }, st.skill.onEnd, {})
	end
	-- P3d D1: onComplete 조각은 **정상으로 끝났을 때만** 돈다(중단 · 리셋 · 전멸이면 안 돈다) - 지형 재생성(regrowObstacles)의 자리.
	if st.skill and st.skill.onComplete and not interrupted then
		runEffects({ model = model, st = st, data = data, position = st.position, now = now, skill = st.skill }, st.skill.onComplete, {})
	end
	st.phase = "normal"
	st.current = nil
	st.skill = nil
	BossScheduler.onSkillEnd(st.sched, data.skills, id, now)
	MonsterState.setLastAttackTick(model, now) -- 스킬 직후 바로 평타가 또 나가지 않게(15-1과 같다)
end

-- ─────────────────────────── 결과 조각(29-3) ───────────────────────────
-- 스킬 데이터의 onImpact(판정 순간)·onResolve(기믹 판정 뒤) = { { type = ... }, ... }. 핸들러는 "무슨 일이 어디서
-- 일어났는가"(info)만 넘기고, 그 결과로 지형이 생기거나 부서지는 것은 데이터가 정한다 - 보스 이름이 들어간 분기는 없다.
--   spawnProp { prop }                    info.positions마다 그 지형을 세운다(낙빙 → 얼음 기둥)
--   destroyProps { prop }                 info.center·info.radius 원에 걸친 그 지형을 부순다(빙결 강타)
--   destroyProps { prop, which = "shielding" } 이번 판정에서 누군가를 가려 준 지형을 부순다(포효)
--   destroyProps { prop, which = "all" }  그 지형을 전부 치운다(스킬이 끝나면 사라지는 모래 구덩이 - onEnd)
--   spawnPropsAround { prop, count, minStuds, maxStuds, clearStuds }
--                                         대상 주변 min~max 거리에 count개를 세운다(onStart). 어떤 멤버에게서도 반경 + clearStuds
--                                         안에는 세우지 않는다 - 발밑에 위험이 "생기는" 일이 없다. 자리를 못 찾으면 덜 세운다.
-- onHit(판정에 맞은 사람마다, runHitEffects):
--   launch { heightStuds, distanceStuds } 맞은 사람이 판정 중심 반대쪽으로 튕겨 난다(폭풍 군주의 낙뢰). 서버는 그 사람의 클라에
--                                         알릴 뿐이다 - 캐릭터 물리는 클라 소유다(BossStormView). 높이는 판정의 높이차 상한(8)보다 낮아야 한다.
--   launch { …, holdSeconds, spinRadiusStuds, immuneSeconds }
--                                         29-4 회오리: 같은 조각에 파라미터가 늘었다 - 제자리(distance 0)에서 떠올라 holdSeconds 동안
--                                         중심 둘레를 돈다. 그동안은 맞지 않는다(immuneSeconds). 보스는 뜬 대상을 놓치지 않는다(MonsterAI).
--   chargeZone { tag, seconds, reachStuds } 29-4(onImpact): 판정의 원 안의 아레나 kit 구역(피뢰침)이 충전된다 - 아래 chargeZones.
-- 서버에는 인스턴스가 없다 - 논리 목록(BossArenaProps)만 바꾸고 멤버에게 알린다. 그리기·충돌은 클라 몫이다.
local function sendPropsRemoved(st, ids)
	if #ids > 0 then
		send(st, "propRemove", { ids = ids })
	end
end

-- 구역 충전(29-4, onImpact = chargeZone { tag, seconds, reachStuds } - 폭풍 군주의 피뢰침): 판정의 원(info.positions · info.radius)
-- 안(+ reachStuds - 가장자리는 플레이어에게 유리하게)에 그 kit 구역이 있으면 seconds 동안 충전된다. 서버는 "언제까지
-- 충전인가"만 갖고(인스턴스 속성은 안 바꾼다) 멤버에게 알린다 - 빛나는 그림은 클라가 그린다.
-- 그 스킬이 게이트의 판정이면(skill.gate.zoneTag) 모든 구역이 동시에 충전 상태가 된 **그 순간** 게이트가 열린다 + 구역은
-- 방전된다. 스킬이 끝날 때까지 못 채웠으면 게이트가 선다(circleTarget 핸들러의 끝) - "게이트는 판정 때만 바뀐다"(29-1) 그대로다.
local function chargeZones(c, effect, info)
	local st = c.st
	local zones = kitZones(c.model, st, c.data, effect.tag)
	st.zoneCharges = st.zoneCharges or {}
	local charges = st.zoneCharges[effect.tag] or {}
	st.zoneCharges[effect.tag] = charges
	local reach = (info.radius or 0) + effect.reachStuds
	for _, zone in ipairs(zones) do
		for _, position in ipairs(info.positions) do
			if Reach.horizontalDistance(position, zone.center) <= reach then
				charges[zone.index] = c.now + effect.seconds
				print(("[forge-game] 구역 충전: %s %d번 - %.0f초"):format(effect.tag, zone.index, effect.seconds))
				send(st, "zoneCharge", { tag = effect.tag, index = zone.index, center = zone.center, size = zone.size, seconds = effect.seconds })
				break
			end
		end
	end
	local gate = c.skill and c.skill.gate
	if gate and gate.zoneTag == effect.tag and not st.gateJudged then
		local all = #zones > 0
		for _, zone in ipairs(zones) do
			all = all and (charges[zone.index] or 0) > c.now
		end
		if all then
			st.gateJudged = true
			st.zoneCharges[effect.tag] = {}
			BossMechanics.judgeGate(c.model, true, gate.breakWindow, "zonesCharged")
			send(st, "zoneDischarge", { tag = effect.tag })
			send(st, "gimmickResolve", { broken = true, windowSeconds = gate.breakWindow and gate.breakWindow.seconds or nil })
		end
	end
end

-- ─────────────────────────── 지형 재생성(P3d D · E - 규칙 = BossArenaMapData.regrow 주석) ───────────────────────────
-- onComplete = { { type = "regrowObstacles", count } }. 자리는 BossArenaMap.planRegrow(= ArenaLayout.regrowSpot - 기존 구조물 · 단상 · 모래 구덩이 · 얼음 기둥 · 보스 · 킷 ·
-- 둔덕 · 입장 방위와 겹치지 않고 갇힘이 없는 자리) → 멤버에게 전조(그림자 + 금 가는 빛)를 보내고 telegraphSeconds 뒤 솟는다. 솟는 순간 몸이 충돌 원에 닿은 사람:
-- 피해(regrow.damage - 방어 적용 · G1-0: 밀림 · 끼임 같음)를 받고, 가장자리면 원 밖으로 밀려나고(끼임은 무적 아님), 안쪽(원 반경 − encaseCoreInsetStuds 안)이거나 밀려날 자리가 막혔으면 끼인다(BossArenaMap.encase).
local REGROW = BossArenaMapData.regrow
local REGROW_SKILL = { damage = REGROW.damage, damageLabel = REGROW.damageLabel } -- applySkillDamage가 읽는 모양

local function regrowObstacles(c, effect)
	local st, model, data = c.st, c.model, c.data
	if data.isTutorial then
		return -- 견습 보스전에는 솟지 않는다(배우는 자리 - 29-3 자동회복 예외와 같은 이유)
	end
	local zoneKey = MonsterState.getZoneKey(model)
	local members, keepOut = {}, {}
	for _, v in ipairs(victims(st)) do
		table.insert(members, v.root.Position)
	end
	for _, prop in ipairs(BossArenaProps.list(model)) do -- 모래 구덩이 · 얼음 기둥(동적 지형) 위에는 솟지 않는다(E1)
		table.insert(keepOut, { position = prop.position, radius = prop.radius })
	end
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	local bossAt = c.position
	local token = BossArenaMap.regrowToken(zoneKey) -- 스킬이 끝난 순간의 보스전(리셋 · 종료 뒤의 계획은 버린다)
	if not token then
		return -- P3d-F: 끝난 순간 이 슬롯에 보스전이 없으면 계획하지 않는다(nil 토큰은 planRegrow의 대조를 건너뛰어 다음 보스전에 솟을 수 있었다)
	end
	debugEvent("regrowQueue", { zoneKey = zoneKey, token = token, at = os.clock() }) -- P3d-F A1 계측: 등록(자리 찾기 대기)
	-- P3d Play 2: 자리 찾기(연결 검사 - 격자 BFS, 한 번에 수 ms)를 step 밖에서 돈다(task.defer) - step 안에서 돌면 그 틱이 튀어 29-2 step 평균이 40 → 118마이크로초였다.
	task.defer(function()
		for _ = 1, effect.count or 1 do
			local planStartedAt = os.clock()
			local plan, why = BossArenaMap.planRegrow(zoneKey, { members = members, boss = bossAt, pits = keepOut, token = token, sliced = true })
			if not plan then
				print(("[forge-game] 지형 재생성 건너뜀: %s - %s"):format(zoneKey, tostring(why)))
				debugEvent("regrowSkip", { reason = why, at = os.clock(), zoneKey = zoneKey, token = token })
				break
			end
			print(("[forge-game] 지형 재생성 자리: %s #%d %s - 시도 %d · %.1fms(%d프레임 · 한 프레임 최대 %.2fms)"):format(zoneKey, plan.item.id, plan.item.kind, plan.tries or 0,
				(os.clock() - planStartedAt) * 1000, plan.frames or 1, plan.maxSliceMs or 0))
			send(st, "regrowTelegraph", { id = plan.item.id, colliders = plan.worldColliders, seconds = REGROW.telegraphSeconds, color = plan.item.spec.color, floorY = st.floorY })
			debugEvent("regrowPlan", { plan = plan, at = os.clock(), zoneKey = zoneKey, token = token })
			local planned = os.clock()
			local function spotContext()
				local now = {}
				for _, prop in ipairs(BossArenaProps.list(model)) do
					table.insert(now, { position = prop.position, radius = prop.radius })
				end
				local bossNow = model.Parent and model.PrimaryPart and (BossPatterns.getLogicalPosition(model) or model.PrimaryPart.Position) or nil
				return { boss = bossNow, pits = now }
			end
			task.delay(REGROW.telegraphSeconds - REGROW.recheckLeadSeconds, function()
				-- 리뷰 6: 솟기 직전 자리를 다시 본다 - 지금 보스 자리 · 지금 동적 지형(전조 사이 들어왔으면 이번엔 안 솟는다).
				-- G1-0: 연결 검사까지 하는 무거운 다시 보기는 recheckLeadSeconds 앞서 여러 프레임에 나눠 하고, 솟는 순간에는 싼 자리 검사만(솟는 시각 = 전조 끝 그대로).
				local fits, fitWhy = BossArenaMap.precheckRegrow(zoneKey, plan, spotContext())
				if not fits then
					print(("[forge-game] 지형 재생성 취소(솟기 전 자리 다시 봄): %s #%d - %s"):format(zoneKey, plan.item.id, tostring(fitWhy)))
					debugEvent("regrowSkip", { reason = fitWhy, at = os.clock(), atSpawn = true, zoneKey = zoneKey, token = token, id = plan.item.id })
					return
				end
				local remain = planned + REGROW.telegraphSeconds - os.clock()
				if remain > 0 then
					task.wait(remain)
				end
				local context = spotContext()
				context.skipOpen = true
				local obstacle, why = BossArenaMap.spawnRegrown(zoneKey, plan, context)
				if not obstacle then
					debugEvent("regrowSkip", { reason = why, at = os.clock(), atSpawn = true, zoneKey = zoneKey, token = token, id = plan.item.id })
					return
				end
				local outcomes = {}
				for _, v in ipairs(victims(st)) do
					local collider, d = BossArenaMap.colliderContact(obstacle, v.feet, half)
					if collider and Reach.sameLayer(v.feet, Vector3.new(0, st.floorY, 0)) then
						local outcome = "encase"
						if d > collider.r - REGROW.encaseCoreInsetStuds then
							local away = Vector3.new(v.root.Position.X - collider.center.X, 0, v.root.Position.Z - collider.center.Z)
							away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(1, 0, 0)
							local target = collider.center + away * (collider.r + REGROW.pushOutStuds)
							if not BossArenaMap.overlapsObstacle(zoneKey, target, half, 0) then
								outcome = "push"
								local to = Vector3.new(target.X, v.root.Position.Y, target.Z)
								if typeof(v.root) == "Instance" then
									v.root.CFrame = CFrame.new(to) * v.root.CFrame.Rotation
								else
									v.root.Position = to
								end
							end
						end
						-- G1-0(P3d-F 결정 2): 솟는 순간 닿은 사람은 밀리든 끼이든 같은 피해(regrow.damage = 평타 ×2). 끼인 동안 무적은 없다.
						applySkillDamage(model, data, REGROW_SKILL, v.player)
						if outcome == "encase" and (PlayerState.getHp(v.player) or 0) <= 0 then
							outcome = "dead" -- 리뷰 5: 그 피해로 죽었으면 끼우지 않는다(죽은 캐릭터 고정 · 탈출 표시 · 교체 제외 방지)
						end
						if outcome == "encase" then
							BossArenaMap.encase(zoneKey, obstacle, v.player, v.root)
						end
						table.insert(outcomes, { player = v.player, outcome = outcome, depth = collider.r - d })
					end
				end
				send(st, "regrowSpawn", { id = obstacle.id, colliders = plan.worldColliders, color = plan.item.spec.color, floorY = st.floorY })
				debugEvent("regrowSpawn", { id = obstacle.id, plan = plan, outcomes = outcomes, at = os.clock(), telegraph = os.clock() - planned, zoneKey = zoneKey, token = token })
			end)
		end
	end)
end

runEffects = function(c, effects, info)
	for _, effect in ipairs(effects or {}) do
		if effect.type == "chargeZone" then
			chargeZones(c, effect, info)
			continue
		elseif effect.type == "regrowObstacles" then
			regrowObstacles(c, effect) -- P3d D
			continue
		end
		local def = c.data.props and c.data.props[effect.prop]
		if not def then
			continue
		end
		if effect.type == "spawnProp" then
			for _, position in ipairs(info.positions) do
				-- P3a(사용자 지시): 기믹 지형(얼음 기둥)은 맵 구조물 위 · 곁(겹침)에 세우지 않는다 - 옆으로 밀어 세우면 구조물 사이로 피한 사람이 갇힐 수 있어 그 기둥만 건너뛴다.
				if BossArenaMap.overlapsObstacle(MonsterState.getZoneKey(c.model), position, def.radiusStuds, 1) then
					print(("[forge-game] 기믹 지형 생략: %s - 구조물과 겹친다(%.0f, %.0f)"):format(effect.prop, position.X, position.Z))
					continue
				end
				local prop, evicted = BossArenaProps.spawn(c.model, effect.prop, def, position)
				sendPropsRemoved(c.st, evicted)
				send(c.st, "propSpawn", { id = prop.id, kind = prop.kind, position = position, radius = prop.radius, height = prop.height, color = def.color })
			end
		elseif effect.type == "spawnPropsAround" then
			local zone = zoneOf(c.model)
			local anchor = xz((c.targetRoot and c.targetRoot.Position) or c.position)
			local members = victims(c.st)
			local made = 0
			for _ = 1, effect.count * 8 do
				if made >= effect.count then
					break
				end
				local angle = scatterRng:NextNumber(0, 2 * math.pi)
				local distance = scatterRng:NextNumber(effect.minStuds, effect.maxStuds)
				local spot = clampToZone(anchor + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance, zone, def.radiusStuds + 4)
				local clear = true
				for _, v in ipairs(members) do
					clear = clear and Reach.horizontalDistance(v.root.Position, spot) >= def.radiusStuds + effect.clearStuds
				end
				for _, other in ipairs(BossArenaProps.list(c.model)) do
					clear = clear and Reach.horizontalDistance(other.position, spot) >= def.radiusStuds + other.radius
				end
				-- P3a: 구조물과 겹치지 않게. P3d E2(사용자 요청): 구조물을 부수는 지형(def.breaksObstacles - 모래 구덩이)은 구조물 위에도 생긴다 - 그 구조물이 달그락거리다 부서진다(tickHazards).
				clear = clear and (def.breaksObstacles ~= nil or not BossArenaMap.overlapsObstacle(MonsterState.getZoneKey(c.model), spot, def.radiusStuds, 2))
				if clear then
					-- P3d 리뷰 4: 구조물 위에 생기는 지형(breaksObstacles)은 바닥 높이 - 구조물 윗면을 지면으로 잡으면 무너진 뒤 원판이 허공에 남는다.
					local surface = def.breaksObstacles and c.st.floorY or (GroundProbe.surfaceY(spot.X, spot.Z, c.st.floorY) or c.st.floorY)
					local position = Vector3.new(spot.X, surface, spot.Z)
					local prop, evicted = BossArenaProps.spawn(c.model, effect.prop, def, position)
					prop.armedAt = os.clock() + (def.armSeconds or 0)
					prop.lastTickAt = {}
					sendPropsRemoved(c.st, evicted)
					send(c.st, "propSpawn", {
						id = prop.id, kind = prop.kind, position = position, radius = prop.radius, color = def.color,
						coreRadius = def.coreRadiusStuds, armSeconds = def.armSeconds, pullStudsPerSecond = def.pullStudsPerSecond,
					})
					made += 1
				end
			end
		elseif effect.type == "destroyProps" then
			sendPropsRemoved(c.st, BossArenaProps.removeWhere(c.model, function(prop)
				if prop.kind ~= effect.prop then
					return false
				elseif effect.which == "shielding" then
					return prop.shielded == true
				elseif effect.which == "all" then
					return true
				end
				return Reach.horizontalDistance(prop.position, info.center) <= info.radius + prop.radius
			end))
		end
	end
end

-- 판정에 맞은 한 사람에게 도는 조각(onHit). from = 그 판정의 중심. coHits(P3c A4) = 이 판정에 함께 맞은 사람 수(자기 포함).
local function runHitEffects(c, effects, v, from, coHits)
	for _, effect in ipairs(effects or {}) do
		if effect.type == "launch" and not BossTrap.isTrapped(v.player) and not BossArenaContainment.isProtected(v.player) then -- P3d B2: 맵 이탈 복귀 직후 보호 중이면 안 뜬다
			c.st.lastLaunch = { player = v.player, at = c.now, effect = effect } -- 자동 검증이 읽는다
			-- 29-5 탱커 훅 ③: 무게 계수(지금은 전원 1.0 - BossMechanics.weightFactorOf). 무거울수록 낮게·가까이·짧게 뜬다 -
			-- 높이·거리·체공·면역 시간을 계수로 나눈다(조작을 잃는 시간이 짧아지면 면역도 같이 짧아져야 공짜 면역이 안 된다).
			local weight = BossMechanics.weightFactorOf(v.player)
			-- 29-4 회오리(holdSeconds): 떠서 도는 동안은 조작을 잃는다 - 그동안은 맞지 않는다(immuneSeconds). 이 스킬의 피해는 이미 들어갔다.
			if effect.immuneSeconds then
				PlayerState.setInvulnerableUntil(v.player, effect.immuneSeconds / weight, "launchHold") -- P3d-F B6: 출처별 무적
			end
			-- 도는 원(spinRadiusStuds)이 벽을 넘지 않게 중심을 그만큼 안쪽으로 자른다(맵 밖으로는 안 나간다 - 20.77 [1]).
			local zone = zoneOf(c.model)
			if effect.spinRadiusStuds then
				from = clampToZone(from, zone, effect.spinRadiusStuds + 2)
			end
			-- P3c A4: 함께 맞은 사람이 많을수록 높이 뜬다(상한 maxHeightStuds). A5: 높이 · 거리 상한과 착지 경계는 클라가 같은 함수(ArenaContainment.limitLaunch)로
			-- 자른다 - 서버는 구역을 실어 보내고, 검증 계측에는 서버에서 같은 계산을 한 값을 남긴다.
			local height = effect.heightStuds + (effect.extraHeightPerCoHit or 0) * math.max((coHits or 1) - 1, 0)
			height = math.min(height, effect.maxHeightStuds or height) / weight
			local distance = effect.distanceStuds / weight
			-- 한가운데서 맞으면(판정 원이 발밑) 클라가 아무 방향으로나 튕긴다 - 계측은 가장 나쁜 방향(아레나 바깥쪽)으로 잘린 거리를 남긴다.
			local away = v.root.Position - from
			if Vector3.new(away.X, 0, away.Z).Magnitude < 0.5 then
				away = v.root.Position - zone.center
			end
			local limitedHeight, limitedDistance = ArenaContainment.limitLaunch(zone, v.root.Position, away, height, distance)
			debugEvent("launch", { player = v.player, coHits = coHits or 1, heightStuds = height, limitedHeight = limitedHeight,
				distanceStuds = distance, limitedDistance = limitedDistance, from = from, rootPosition = v.root.Position })
			HeightGuard.exempt(v.player, JumpMath.launchAirSeconds(height) + (effect.holdSeconds and effect.holdSeconds / weight or 0))
			sendTo(v.player, "launch", {
				from = from, heightStuds = height, distanceStuds = distance,
				holdSeconds = effect.holdSeconds and effect.holdSeconds / weight, spinRadiusStuds = effect.spinRadiusStuds,
				zoneCenter = zone.center, zoneRadius = zone.radius,
			})
		end
	end
end

-- 위험 지형의 틱(29-3 모래 구덩이): 중심부(coreRadiusStuds) 안에 있는 사람에게 coreTickSeconds마다 %최대체력 피해.
-- 구덩이를 깐 스킬의 발동당 1인 상한(55%)을 같이 쓴다(applyGimmickDamage) - 돌진에 다 맞고 구덩이에 빠져도 55%다.
-- 지형 데이터가 없는 보스는 첫 줄에서 돌아간다. 잡힌 사람은 면역이다(PlayerDamage).
local function tickHazards(model, st, data, now)
	if not data.props then
		return
	end
	for _, prop in ipairs(BossArenaProps.list(model)) do
		local def = data.props[prop.kind]
		-- P3d E2: 구조물 위에 생긴 모래 구덩이 - 틱(coreTickSeconds)마다 걸친 구조물이 달그락거리고 breaksObstacles.ticks번째에 무너진다(위 사람은 떨어지기만).
		if def and def.breaksObstacles and now >= (prop.armedAt or 0) and now - (prop.lastRattleAt or 0) >= def.coreTickSeconds then
			prop.lastRattleAt = now
			local zoneKey = MonsterState.getZoneKey(model)
			for _, id in ipairs(BossArenaMap.obstaclesInCircle(zoneKey, prop.position, def.radiusStuds)) do
				local ticks, broke = BossArenaMap.pitRattle(zoneKey, id, def.breaksObstacles.ticks)
				debugEvent("pitRattle", { id = id, ticks = ticks, broke = broke, at = now, pit = prop.id })
			end
		end
		if def and def.coreRadiusStuds and now >= (prop.armedAt or 0) then
			for _, v in ipairs(victims(st)) do
				local last = prop.lastTickAt[v.player]
				if Reach.horizontalDistance(v.root.Position, prop.position) <= def.coreRadiusStuds and (not last or now - last >= def.coreTickSeconds) then
					prop.lastTickAt[v.player] = now
					BossMechanics.applyGimmickDamage(model, v.player, def.coreFraction, def.damageLabel)
				end
			end
		end
	end
end

-- ─────────────────────────── 프리미티브 핸들러 ───────────────────────────
-- 핸들러 = { start(c), step(c), bubbleSeconds(c), interrupt(c)? }. c = { model, st, data, skill, now, position, targetRoot }.
-- step은 스킬이 끝났으면 endSkill을 부른다. phase 이름은 21-3부터 쓰던 것을 그대로 둔다(로그·검증 블록 호환).

local HANDLERS = {}

-- ── circleBoss: 보스 중심 원. innerRadiusStuds가 있으면 도넛(안쪽이 안전), pulses가 있으면 연속 펄스 ──
-- 25-4: 판정이 "보스 좌표에서 반경 안"이라 위험 범위 도형도 보스 중심이다. 예고가 끝나는 순간의 거리만 본다 -
-- 그 사이 벗어났으면 완전히 무효(15-1 그대로).
local function beginPulse(c)
	local st, skill = c.st, c.skill
	local pulse = BossSkillMath.pulsesOf(skill)[st.pulseIndex]
	st.phase = "heavyTelegraph"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	setBodyColor(c.model, c.data.telegraphColor)
	send(st, "heavyTelegraph", {
		center = Vector3.new(c.position.X, st.floorY, c.position.Z),
		radius = pulse.radiusStuds,
		innerRadius = (pulse.innerRadiusStuds or 0) > 0 and pulse.innerRadiusStuds or nil,
		seconds = skill.telegraphSeconds,
	})
end

HANDLERS.circleBoss = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds * #BossSkillMath.pulsesOf(c.skill)
	end,
	start = function(c)
		c.st.pulseIndex = 1
		beginPulse(c)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		local pulses = BossSkillMath.pulsesOf(skill)
		local pulse = pulses[st.pulseIndex]
		local inner = pulse.innerRadiusStuds or 0
		judgeBegin()
		for _, v in ipairs(victims(st)) do
			if Reach.horizontalDistance(v.root.Position, c.position) <= pulse.radiusStuds and Reach.sameLayer(v.groundFeet, footOf(c.position)) -- 22-4 수평 + 높이차 상한(P3a D3: 발 기준)
				and Reach.horizontalDistance(v.root.Position, c.position) >= inner then
				applySkillDamage(c.model, c.data, skill, v.player)
			end
		end
		judgeEnd(c, { kind = "circle", centers = { Vector3.new(c.position.X, st.floorY, c.position.Z) }, radius = pulse.radiusStuds, inner = inner })
		-- 25-4: 판정 순간 흰 섬광 - "임팩트 = 흰색".
		send(st, "heavyImpact", {
			center = Vector3.new(c.position.X, st.floorY, c.position.Z),
			radius = pulse.radiusStuds,
			innerRadius = inner > 0 and inner or nil,
		})
		runEffects(c, skill.onImpact, { center = c.position, radius = pulse.radiusStuds })
		if st.pulseIndex < #pulses then
			st.pulseIndex += 1
			beginPulse(c)
			return
		end
		setBodyColor(c.model, c.data.bodyColor)
		endSkill(c.model, st, c.data, c.now)
	end,
	interrupt = function(c)
		setBodyColor(c.model, c.data.bodyColor)
	end,
}

-- ── ring: 퍼지는 띠(진동파). 보스가 떠올랐다 찍는 동작이 예고, 찍는 순간 파동이 퍼진다. 점프로만 피한다 ──
local function startHop(c, seconds)
	local st, skill = c.st, c.skill
	st.phase = "shockHop"
	st.hopStartedAt = c.now
	st.hopSeconds = seconds
	st.phaseEndsAt = c.now + seconds
	send(st, "shockTelegraph", {
		center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
		seconds = seconds,
		hopHeight = skill.hopHeightStuds,
		bossId = c.data.id, waveIndex = st.wavesSpawned + 1, waveCount = #st.ringWaves, -- P3d A1: 클라가 보스별 찍기 모션(BossFxData.bosses)을 고른다(연출만)
	})
end

-- 매 틱 모든 살아있는 파동에 대해: 파동 띠[반경-두께, 반경]가 대상을 지나는 동안 한 순간이라도 공중이면 회피,
-- 띠가 완전히 지나갔는데 한 번도 공중이 아니었으면 피격. 24-1: 멤버마다 touched/dodged/resolved를 따로 기록한다 -
-- 한 파동이 네 사람을 서로 다른 시각에 지나간다. 파동은 최대 반경까지 살아 있다.
-- P3d C1: 단상(올라갈 수 있는 큰 블록) 윗면에 선 사람은 파동이 발밑으로 지나간다(보이는 파동 띠 높이 1.6 < 윗면 3.5). 그 단상이 이 파동에 무너졌으면 위에 있던 사람은
-- **그 파동(모든 겹)**을 안 맞는다(리뷰 1 - 시간 유예 0.6초는 단상 먼 쪽 가장자리 · 느린 파동(18 · 20)에서 모자랐다). 파동 번호는 스킬마다 새로 세므로 스킬 시작 시각과 같이 적는다.
local function onDais(c, v, wave)
	local dropped = c.st.daisDropped and c.st.daisDropped[v.player]
	if dropped and dropped.skillAt == c.st.currentStartedAt and dropped.waveIndex == wave.waveIndex then
		return true
	end
	return BossArenaMap.daisUnderFeet(MonsterState.getZoneKey(c.model), v.feet) ~= nil
end

-- P3d C2: 한 번 찍은 파동(첫 겹)이 단상 한가운데를 지나면 센다 - 금 → 무너짐. 무너지는 순간 그 위에 선 사람은 떨어지는 동안 파동을 안 맞는다.
local function waveOverDaises(c, wave, radius, targets)
	if wave.layer ~= 1 then
		return
	end
	local zoneKey = MonsterState.getZoneKey(c.model)
	wave.daisPassed = wave.daisPassed or {}
	wave.daisWarned = wave.daisWarned or {}
	for _, dais in ipairs(BossArenaMap.daises(zoneKey)) do
		local distance = (xz(dais.center) - wave.center).Magnitude
		-- P3d-F B3: 이 파동에 무너질 단상(금 간 상태)이면 닿기 collapseWarnSeconds 전에 예고(흔들림 · 먼지 - 클라). 파동이 그보다 가까이서 태어나면 태어난 순간 남은 시간만큼.
		if not wave.daisWarned[dais.id] and not wave.daisPassed[dais.id] and BossArenaMap.daisBreaksNext(zoneKey, dais.id) then
			local lead = (distance - radius) / wave.speed
			if lead <= BossArenaMapData.obstacle.daisWave.collapseWarnSeconds then
				wave.daisWarned[dais.id] = true
				BossArenaMap.warnDais(zoneKey, dais.id, math.max(lead, 0))
				debugEvent("daisWarn", { id = dais.id, lead = lead, waveIndex = wave.waveIndex, at = c.now })
			end
		end
		if not wave.daisPassed[dais.id] and distance <= radius then
			wave.daisPassed[dais.id] = true
			local onTop = {}
			for _, v in ipairs(targets) do
				if BossArenaMap.daisUnderFeet(zoneKey, v.feet) == dais.id then
					table.insert(onTop, v.player)
				end
			end
			local result = BossArenaMap.waveHitDais(zoneKey, dais.id)
			debugEvent("daisWave", { id = dais.id, result = result, waveIndex = wave.waveIndex, at = c.now, onTop = onTop })
			if result == "break" then
				c.st.daisDropped = c.st.daisDropped or {}
				for _, player in ipairs(onTop) do
					c.st.daisDropped[player] = { skillAt = c.st.currentStartedAt, waveIndex = wave.waveIndex }
				end
			end
		end
	end
end

local function updateWaves(c)
	local st, skill = c.st, c.skill
	local maxRadius = BossSkillMath.WAVE_MAX_RADIUS_STUDS
	local alive = {}
	local targets = victims(st)
	for _, wave in ipairs(st.waves) do
		local radius = (c.now - wave.startedAt) * wave.speed -- P3c A1: 파동마다 속도가 다를 수 있다(리듬)
		wave.byPlayer = wave.byPlayer or {}
		waveOverDaises(c, wave, radius, targets) -- P3d C2: 판정보다 먼저 - 무너지는 단상 위 사람에게 떨어지는 유예를 준 뒤 판정한다
		for _, v in ipairs(targets) do
			local rec = wave.byPlayer[v.player]
			if not rec then
				rec = {}
				wave.byPlayer[v.player] = rec
			end
			local d = (xz(v.root.Position) - wave.center).Magnitude
			-- 22-4: 파동은 지면을 타고 퍼진다 - 파동 중심 지면(floorY)에서 높이차 상한 너머(절벽 위)는 안 닿는다.
			-- P3d C1: 단상 윗면(또는 무너지며 떨어지는 중)은 파동이 밑으로 지나간다.
			local inBand = d <= radius and d >= radius - skill.waveThicknessStuds
				and Reach.sameLayer(v.root.Position, Vector3.new(0, st.floorY, 0)) and not onDais(c, v, wave)
			if inBand then
				rec.touched = true
				if isAirborne(v.player.Character, skill.airborneClearanceStuds) then
					rec.dodged = true
				end
			elseif rec.touched and not rec.resolved and d < radius - skill.waveThicknessStuds then
				rec.resolved = true
				if not rec.dodged then
					applySkillDamage(c.model, c.data, skill, v.player)
					debugEvent("waveHit", { player = v.player, at = c.now }) -- P3c 계측: 파동 판정(피해가 0이어도 판정은 났다)
				end
			end
		end
		if radius <= maxRadius then
			table.insert(alive, wave)
		end
	end
	st.waves = alive
end

-- 한 번 찍을 때 파동을 layers개 낸다 - 겹마다 startedAt을 layerGapSeconds만큼 늦춰 서로 다른 링으로 퍼지게 한다.
-- P3c A1: 겹 수 · 겹 간격 · 속도는 이번 파동의 리듬 칸(BossSkillMath.ringWaves)에서 읽는다. 클라는 파동마다 받은 속도로 그리고,
-- 내 자리에 닿는 순간을 거꾸로 세는 "뛰어라" 표시(점프 틈)를 띄운다(BossRhythmView) - 판정은 서버의 이 목록 그대로다.
local function slam(c)
	local st, skill = c.st, c.skill
	c.model:PivotTo(CFrame.new(st.hopBase))
	local maxRadius = BossSkillMath.WAVE_MAX_RADIUS_STUDS
	local wave = st.ringWaves[st.wavesSpawned + 1]
	for layer = 1, wave.layers do
		local delay = (layer - 1) * wave.layerGapSeconds
		table.insert(st.waves, { center = xz(st.hopBase), startedAt = c.now + delay, speed = wave.speedStuds, waveIndex = st.wavesSpawned + 1, layer = layer })
		send(st, "shockwave", {
			center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
			serverStart = serverNow() + delay,
			speed = wave.speedStuds,
			thickness = skill.waveThicknessStuds,
			maxRadius = maxRadius,
			waveIndex = st.wavesSpawned + 1, layer = layer, waveCount = #st.ringWaves,
			bossId = c.data.id, -- P3d A2 · A3: 임팩트 모션 · 풍압 · 땅 파도(연출만)
			floorColor = (BossArenaMap.getTheme(MonsterState.getZoneKey(c.model)) or BossArenaMapData.default).floor.color,
		})
	end
	st.wavesSpawned += 1
end

HANDLERS.ring = {
	bubbleSeconds = function(c)
		local waves = BossSkillMath.ringWaves(c.skill)
		return waves[#waves].startSeconds
	end,
	start = function(c)
		local st = c.st
		st.hopBase = xz(c.position) + Vector3.new(0, MonsterState.getSpawnPosition(c.model).Y, 0)
		st.wavesSpawned = 0
		st.waves = {}
		st.ringWaves = BossSkillMath.ringWaves(c.skill)
		startHop(c, st.ringWaves[1].startSeconds)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		updateWaves(c)
		if st.phase == "shockHop" then
			if c.now < st.phaseEndsAt then
				local progress = (c.now - st.hopStartedAt) / st.hopSeconds
				c.model:PivotTo(CFrame.new(st.hopBase + Vector3.new(0, skill.hopHeightStuds * math.sin(math.pi * progress), 0)))
				return
			end
			slam(c)
			if st.wavesSpawned < #st.ringWaves then
				local waves = st.ringWaves
				startHop(c, waves[st.wavesSpawned + 1].startSeconds - waves[st.wavesSpawned].startSeconds)
			else
				st.phase = "shockWait"
			end
		elseif #st.waves == 0 then -- shockWait
			endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		if c.st.hopBase then
			c.model:PivotTo(CFrame.new(c.st.hopBase))
		end
	end,
}

-- ── circleTarget: 대상 위치의 원. 기본은 count개 동시 산개(낙석), sequential이면 하나가 터진 뒤 그 순간의 대상 위치에 다음 것 ──
-- count는 입장 인원에 비례할 수 있다(countPerMember - 서리 거인 낙빙 N+2).
local function circleCount(data, skill)
	return skill.count + (skill.countPerMember or 0) * (data.partySize or 1)
end

local function groundAt(st, p)
	-- 22-4: 낙하점 Y는 그 자리 지면(언덕 위면 언덕 위). 못 찾으면 보스 발밑.
	return Vector3.new(p.X, GroundProbe.surfaceY(p.X, p.Z, st.floorY) or st.floorY, p.Z)
end

-- trackers(P3c A4, 선택) = { [원 번호] = 따라갈 멤버의 victims 항목 } - 그 원은 st.trackLockAt까지 그 사람을 따라가다 멈춘다(updateTrackers).
local function beginCircles(c, positions, seconds, trackers, trackSeconds)
	local st, skill = c.st, c.skill
	for i, p in ipairs(positions) do
		positions[i] = groundAt(st, p)
	end
	st.meteorPositions = positions
	st.phase = "meteorTelegraph"
	st.phaseEndsAt = c.now + seconds
	st.trackers = trackers
	st.trackLockAt = trackers and (c.now + trackSeconds) or nil
	local track = nil
	if trackers then
		track = {}
		for index, v in pairs(trackers) do
			table.insert(track, { index = index, userId = typeof(v.player) == "Instance" and v.player.UserId or nil })
		end
	end
	send(st, "meteor", { positions = positions, radius = skill.radiusStuds, seconds = seconds, style = skill.impactStyle, track = track, lockIn = trackers and trackSeconds or nil })
end

-- P3c A4 번개 추적: 추적 중인 원을 그 사람의 지금 자리(벽 안쪽으로 자른 발밑 지면)로 옮기고, trackLockAt이 되면 멈춘다 - 멈춘 자리를 멤버에게 보내
-- 클라가 그 자리로 원을 옮긴다(멈춘 뒤의 원 = 판정 자리). 판정은 phaseEndsAt(멈춘 뒤 lockTelegraphSeconds)에 난다.
local function updateTrackers(c)
	local st = c.st
	local zone = zoneOf(c.model)
	for index, v in pairs(st.trackers) do
		if typeof(v.root) ~= "Instance" or v.root.Parent then
			st.meteorPositions[index] = groundAt(st, clampToZone(xz(v.root.Position), zone, circleTargetMargin(zone)))
		end
	end
	if c.now >= st.trackLockAt then
		local locked = {}
		for index, v in pairs(st.trackers) do
			table.insert(locked, { player = v.player, position = st.meteorPositions[index], index = index })
		end
		st.trackers = nil
		send(st, "meteorLock", { positions = st.meteorPositions, radius = c.skill.radiusStuds, seconds = st.phaseEndsAt - c.now, style = c.skill.impactStyle })
		debugEvent("trackLock", { locked = locked, at = c.now, judgeAt = st.phaseEndsAt, positions = st.meteorPositions })
	end
end

-- 조준 자리: 대상의 자리 + (perMember면) 안 잡힌 다른 멤버 각자의 자리(29-3 낙빙 · 29-4 낙뢰의 두 발 모두).
-- 반환: 자리 목록, 자리마다 주인(victims 항목 - 대상이 멤버 목록에 없으면 nil).
local function aimPositions(c, zone)
	local positions, owners = { clampToZone(xz(c.targetRoot.Position), zone, circleTargetMargin(zone)) }, {}
	local list = victims(c.st)
	for _, v in ipairs(list) do
		if v.root == c.targetRoot then
			owners[1] = v
		end
	end
	if c.skill.perMember then
		for _, v in ipairs(list) do
			if v.root ~= c.targetRoot and not BossTrap.isTrapped(v.player) then
				table.insert(positions, clampToZone(xz(v.root.Position), zone, circleTargetMargin(zone)))
				owners[#positions] = v
			end
		end
	end
	return positions, owners
end

-- 게이트의 판정 스킬(skill.gate - 폭풍 군주의 낙뢰)은 기믹 스킬과 같은 힌트를 받는다(20.73 [1-5]): 2단계 = 예고 × 1.5.
local function hintedSeconds(st, skill, seconds)
	if skill.gate and (st.hintLevel or 0) >= BossData.mechanics.hint.maxLevel then
		return seconds * BossData.mechanics.hint.telegraphMultiplier
	end
	return seconds
end

local function circleBubbleSeconds(c)
	local skill = c.skill
	if skill.sequential then
		return hintedSeconds(c.st, skill, skill.telegraphSeconds + BossSkillMath.repeatSeconds(skill) * (circleCount(c.data, skill) - 1))
	end
	return hintedSeconds(c.st, skill, skill.telegraphSeconds)
end

HANDLERS.circleTarget = {
	bubbleSeconds = circleBubbleSeconds,
	start = function(c)
		local skill = c.skill
		local zone = zoneOf(c.model)
		local first = xz(c.targetRoot.Position)
		local positions = aimPositions(c, zone)
		c.st.shotIndex = 1
		if skill.gate then
			-- 29-4: 이 스킬이 게이트의 판정이다 - 첫 예고와 함께 게이트가 서고(29-1 규칙 ①), 이번 회차의 판정은 아직 안 났다.
			c.st.gateJudged = false
			BossMechanics.armGateOnce(c.model)
			if (c.st.hintLevel or 0) >= 1 then -- 힌트 1단계: 채워야 할 구역(피뢰침) 위에 흰 화살표
				local spots = {}
				for _, z in ipairs(kitZones(c.model, c.st, c.data, skill.gate.zoneTag)) do
					table.insert(spots, Vector3.new(z.center.X, c.st.floorY, z.center.Z))
				end
				send(c.st, "hintArrows", { positions = spots, seconds = circleBubbleSeconds(c) })
			end
		end
		if not skill.sequential then
			local scattered = circleCount(c.data, skill) - #positions -- 29-3: 멤버 각자의 발밑에 하나씩 - 나머지만 대상 주변에 흩는다
			for _ = 1, scattered do
				local offset = Vector3.new(scatterRng:NextNumber(-1, 1), 0, scatterRng:NextNumber(-1, 1))
				if offset.Magnitude > 1 then
					offset = offset.Unit
				end
				table.insert(positions, clampToZone(first + offset * skill.scatterStuds, zone, circleTargetMargin(zone)))
			end
		end
		beginCircles(c, positions, hintedSeconds(c.st, skill, skill.telegraphSeconds))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.trackers then
			updateTrackers(c)
		end
		if c.now < st.phaseEndsAt then
			return
		end
		judgeBegin()
		local hits = {}
		for _, v in ipairs(victims(st)) do
			local p = xz(v.root.Position)
			for spotIndex, spot in ipairs(st.meteorPositions) do
				if (p - xz(spot)).Magnitude <= skill.radiusStuds and Reach.sameLayer(v.groundFeet, spot) then -- 22-4(P3a D3: 발 기준)
					applySkillDamage(c.model, c.data, skill, v.player)
					table.insert(hits, { v = v, spot = spot, spotIndex = spotIndex })
					break
				end
			end
		end
		-- P3c A4: 넉백은 판정이 다 끝난 뒤에 - 함께 맞은 사람 수가 높이를 정한다. P3d G-f(사용자 결정): "함께" = **같은 원** 안에서 실제로 함께 맞은 사람(옛 = 회차 전체).
		-- 원이 겹친 자리의 사람은 먼저 찾은 원 하나에만 센다(판정도 원 하나 - 위 break).
		local perSpot = {}
		for _, hit in ipairs(hits) do
			perSpot[hit.spotIndex] = (perSpot[hit.spotIndex] or 0) + 1
		end
		for _, hit in ipairs(hits) do
			runHitEffects(c, skill.onHit, hit.v, hit.spot, perSpot[hit.spotIndex])
		end
		judgeEnd(c, { kind = "circle", centers = st.meteorPositions, radius = skill.radiusStuds, inner = 0 })
		send(st, "meteorImpact", { positions = st.meteorPositions, radius = skill.radiusStuds, style = skill.impactStyle })
		runEffects(c, skill.onImpact, { positions = st.meteorPositions, radius = skill.radiusStuds })
		if skill.sequential and st.shotIndex < circleCount(c.data, skill) and c.targetRoot then
			st.shotIndex += 1
			local positions, owners = aimPositions(c, zoneOf(c.model))
			local track = skill.trackAfterHit
			if track and #hits > 0 then
				-- P3c A4 번개 추적: 맞은 사람의 원은 그 사람을 따라간다(그 사람 몫의 원이 없으면 하나 더한다).
				local trackers = {}
				for _, hit in ipairs(hits) do
					local index = nil
					for i, owner in pairs(owners) do
						if owner.player == hit.v.player then
							index = i
						end
					end
					if not index then
						table.insert(positions, clampToZone(xz(hit.v.root.Position), zoneOf(c.model), circleTargetMargin(zoneOf(c.model)))) -- 리뷰 6: 다른 원과 같이 벽 안쪽으로
						index = #positions
					end
					trackers[index] = hit.v
				end
				beginCircles(c, positions, hintedSeconds(st, skill, track.trackSeconds + track.lockTelegraphSeconds), trackers, track.trackSeconds)
				return
			end
			beginCircles(c, positions, hintedSeconds(st, skill, skill.repeatTelegraphSeconds or skill.telegraphSeconds))
			return
		end
		if skill.gate and not st.gateJudged then
			-- 29-4: 회차가 끝났는데 구역을 다 못 채웠다 - 게이트가 선다/남는다(실패의 대가는 게이트뿐이다 - 낙뢰 회차는 잡지 않는다).
			st.gateJudged = true
			BossMechanics.judgeGate(c.model, false, nil, "zonesCharged")
		end
		endSkill(c.model, st, c.data, c.now)
	end,
}

-- P3c A2 돌진 대상 = 전조가 시작되는 순간 보스에서 가장 가까운 멤버(잡힌 사람 제외 · 동률이면 무작위 - BossSkillMath.nearestIndex). 전조 동안 바뀌지 않는다
-- (대상 · 좌표 모두 이 순간에 고정). 멤버가 없으면(스탠드인 없이 DevTools로 띄운 경우) 어그로 대상 그대로. 반환: 대상의 victims 항목(없으면 nil), 루트.
local function pickChargeTarget(c, origin)
	local candidates, positions = {}, {}
	for _, v in ipairs(victims(c.st)) do
		if not BossTrap.isTrapped(v.player) then
			table.insert(candidates, v)
			table.insert(positions, v.root.Position)
		end
	end
	local index = BossSkillMath.nearestIndex(origin, positions, function()
		return scatterRng:NextNumber()
	end)
	if index then
		return candidates[index], candidates[index].root
	end
	return nil, c.targetRoot
end

-- ── charge: 정신집중 → 돌진. 느낌표가 뜨는 순간의 대상 좌표를 고정한다(이후 추적 안 함). dashCount만큼 잇는다 ──
local function startDash(c, fromPosition, dashIndex)
	local st, skill = c.st, c.skill
	local zone = zoneOf(c.model)
	local origin = xz(fromPosition)
	local target, targetRoot = pickChargeTarget(c, origin)
	local snapshot = xz(targetRoot.Position)
	local dir = snapshot - origin
	if dir.Magnitude < 1e-3 then
		local look = c.model.PrimaryPart.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	dir = dir.Unit
	local length = clipToZone(origin, dir, zone, skill.arenaMarginStuds)
	-- P3a C(사용자 지시): 경로에 구조물이 있으면 몸통이 닿는 자리에서 멈춘다 - 예고 선도 거기까지(보이는 것 = 판정). 도착하면 구조물이 부서지고 헤롱이 길어진다.
	local obstacleId, contact = BossArenaMap.firstOnPath(MonsterState.getZoneKey(c.model), origin, dir, length, BossArenaMapData.obstacle.chargeBodyHalfStuds)
	if obstacleId then
		length = contact
	end
	st.chargeObstacle = obstacleId
	st.chargeDashIndex = dashIndex
	st.chargeFrom = Vector3.new(origin.X, fromPosition.Y, origin.Z)
	st.chargeTo = st.chargeFrom + dir * length
	st.chargeHitBy = {} -- 24-1: 돌진 한 번에 멤버마다 한 번씩만(경로 위 전원 대상). P3c A3: 돌진마다 새로 비운다 - 1회차에 맞은 사람도 2회차 판정을 받는다
	st.chargeTarget = target and target.player or nil
	st.focusStartedAt = c.now
	st.phase = "focus"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	local targetPlayer = target and target.player
	local targetUserId = typeof(targetPlayer) == "Instance" and targetPlayer.UserId or nil
	send(st, "focus", {
		bossPosition = st.chargeFrom,
		endPosition = st.chargeTo,
		halfWidth = skill.pathHalfWidthStuds,
		seconds = skill.telegraphSeconds,
		floorY = st.floorY,
		targetUserId = targetUserId, -- P3c A2: 클라가 이 사람 머리 위에 표식을 띄운다(방향선 = 위 경로선)
		bossId = c.data.id, dashIndex = dashIndex, burrow = skill.burrow ~= nil, -- P3d A4: 발 긁기 · 잠행 연출(연출만)
	})
	print(("[forge-game] 돌진 대상 확정: %s(%d번째 돌진) - 보스에서 %.1fstud, 경로 %.1fstud%s"):format(
		tostring(targetPlayer and targetPlayer.Name or "어그로 대상"), dashIndex, (snapshot - origin).Magnitude, length, obstacleId and (" · 구조물 #" .. obstacleId .. "에서 멈춤") or ""))
	debugEvent("chargeTarget", { player = targetPlayer, dashIndex = dashIndex, at = c.now, origin = origin, snapshot = snapshot, obstacleId = obstacleId, length = length })
end

-- 잠행(29-3, skill.burrow = { depthStuds, enterSeconds, exitSeconds, visibleParts }): 돌진의 **겉모습**만 바꾼다 - 첫 예고
-- 동안 땅속으로 내려가고(enterSeconds), 돌진 중에는 visibleParts(꼬리)만 보이고, 마지막 돌진 뒤에 솟아올라(exitSeconds)
-- 헤롱에 들어간다. 경로·속도·판정·지면 추적은 돌진 그대로다: 계산은 전부 "지표의 논리 위치"(st.burrowLogical)로 하고
-- 모델만 depthStuds 아래에 그린다. MonsterAI도 그동안 보스의 위치로 논리 위치를 쓴다(getLogicalPosition) - 가라앉은
-- 루트로 높이차를 재면 점프한 대상을 놓친다. 다 내려가면 visibleParts 말고는 투명하게 가린다(머리는 몸통보다 높다).
local function setBurrowHidden(c, hidden)
	local st = c.st
	if hidden and not st.burrowHidden then
		st.burrowHidden = {}
		local visible = c.skill.burrow.visibleParts
		for _, part in ipairs(c.model:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not table.find(visible, part.Name) then
				st.burrowHidden[part] = part.Transparency
				part.Transparency = 1
			end
		end
	elseif not hidden and st.burrowHidden then
		for part, transparency in pairs(st.burrowHidden) do
			if part.Parent then
				part.Transparency = transparency
			end
		end
		st.burrowHidden = nil
	end
end

-- 잠행을 끝낸다(중단·리셋) - 가린 파트를 되돌리고 지표로 올린다.
local function surfaceNow(c)
	local st = c.st
	setBurrowHidden(c, false)
	if st.burrowLogical then
		c.model:PivotTo(CFrame.new(st.burrowLogical))
		st.burrowLogical = nil
	end
	st.emergeFrom = nil
end

HANDLERS.charge = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		if c.skill.burrow then
			c.st.burrowLogical = c.position
		end
		startDash(c, c.position, 1)
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		local burrow = skill.burrow
		if st.phase == "focus" then
			if burrow and st.chargeDashIndex == 1 then -- 들어가는 모션: 첫 예고의 앞 enterSeconds 동안 내려간다
				local progress = math.min((c.now - st.focusStartedAt) / burrow.enterSeconds, 1)
				c.model:PivotTo(CFrame.new(st.burrowLogical - Vector3.new(0, burrow.depthStuds * progress, 0)))
				if progress >= 1 then
					setBurrowHidden(c, true)
				end
			end
			if c.now < st.phaseEndsAt then
				return
			end
			local length = (st.chargeTo - st.chargeFrom).Magnitude
			st.phase = "charge"
			st.chargeStartedAt = c.now
			st.chargeSeconds = length / skill.speedStuds
			send(st, "charge", { startPosition = st.chargeFrom, endPosition = st.chargeTo, durationSeconds = st.chargeSeconds,
				bossId = c.data.id, burrow = skill.burrow ~= nil, targetUserId = typeof(st.chargeTarget) == "Instance" and st.chargeTarget.UserId or nil, crashed = st.chargeObstacle ~= nil }) -- P3d A4(연출만)
		elseif st.phase == "charge" then
			local position = st.burrowLogical or c.position -- 잠행 중에는 모델이 땅속에 있다 - 계산은 지표의 논리 위치로
			local prev = xz(position)
			local progress = math.min((c.now - st.chargeStartedAt) / math.max(st.chargeSeconds, 1e-3), 1)
			local newPos = st.chargeFrom:Lerp(st.chargeTo, progress)
			-- 22-4: 돌진도 지면을 따른다. 계단 한 단(maxStepHeight)보다 큰 단차·심연이면 여기서 돌진을 끝낸다.
			local footY = position.Y - TerrainConfig.monsterFootOffsetStuds
			local groundY = GroundProbe.groundY(newPos.X, newPos.Z, footY)
			if groundY == nil or math.abs(groundY - footY) > TerrainConfig.maxStepHeightStuds then
				newPos = position
				progress = 1
			else
				newPos = Vector3.new(newPos.X, groundY + TerrainConfig.monsterFootOffsetStuds, newPos.Z)
			end
			if burrow then
				st.burrowLogical = newPos
				c.model:PivotTo(CFrame.new(newPos - Vector3.new(0, burrow.depthStuds, 0)))
			else
				c.model:PivotTo(CFrame.new(newPos))
			end
			for _, v in ipairs(victims(st)) do
				if not st.chargeHitBy[v.player] and distanceToSegment(xz(v.root.Position), prev, xz(newPos)) <= skill.pathHalfWidthStuds
					and Reach.sameLayer(v.groundFeet, footOf(newPos)) then -- P3a D3: 발 기준
					st.chargeHitBy[v.player] = true
					applySkillDamage(c.model, c.data, skill, v.player)
					debugEvent("chargeHit", { player = v.player, dashIndex = st.chargeDashIndex, at = c.now })
				end
			end
			if progress >= 1 then
				-- P3a C: 구조물에 부딪혀 멈췄다 - 구조물이 부서지고, 남은 돌진은 없이 바로 헤롱(길어진다).
				local crashed = st.chargeObstacle and BossArenaMap.breakObstacle(MonsterState.getZoneKey(c.model), st.chargeObstacle, "charge")
				st.chargeObstacle = nil
				if not crashed and st.chargeDashIndex < (skill.dashCount or 1) and c.targetRoot then
					-- 헤롱 없이 바로 다음 돌진(현재 위치·현재 대상 좌표로 재조준). 마지막 돌진에서만 헤롱.
					startDash(c, newPos, st.chargeDashIndex + 1)
				else
					-- 헤롱(주저앉기) - 몸을 내려 기울인다. 끝날 때(endSkill/interrupt) 똑바로 되돌린다.
					-- 29-3: 마지막 돌진이 아레나 kit의 논리 구역(tag) 안에서 끝났으면 헤롱이 길어진다(전갈 여왕의 유사 웅덩이).
					local recoverSeconds = skill.recoverSeconds + (crashed and BossArenaMapData.obstacle.chargeStunBonusSeconds or 0)
					local bonus = skill.recoverInZone
					if bonus and c.data.arenaKit then
						local zoneCenter = zoneOf(c.model).center
						for _, part in ipairs(c.data.arenaKit.parts) do
							if part.tag == bonus.tag and Reach.horizontalDistance(newPos, zoneCenter + part.offset) <= part.radiusStuds then
								recoverSeconds = math.max(recoverSeconds, bonus.seconds)
							end
						end
					end
					st.phase = "chargeRecover"
					st.phaseEndsAt = c.now + recoverSeconds
					st.dazeBase = newPos
					if burrow then -- 나오는 모션: 가린 파트를 되돌리고 exitSeconds 동안 헤롱 자세까지 솟아오른다(아래 chargeRecover)
						setBurrowHidden(c, false)
						st.burrowLogical = newPos -- 다 올라올 때까지는 논리 위치를 유지한다(getLogicalPosition)
						st.emergeFrom = c.now
					else
						c.model:PivotTo(CFrame.new(newPos - Vector3.new(0, skill.dazeSinkStuds, 0)) * CFrame.Angles(0, 0, math.rad(skill.dazeTiltDeg)))
					end
					runEffects(c, skill.onEnd, {}) -- 헤롱(딜타임)에는 구덩이가 없다 - 다가가 때릴 수 있어야 한다
					send(st, "daze", { seconds = recoverSeconds })
					debugEvent("chargeEnd", { crashed = crashed == true, recoverSeconds = recoverSeconds, dashIndex = st.chargeDashIndex, at = c.now, position = newPos })
				end
			end
		elseif c.now >= st.phaseEndsAt then -- chargeRecover
			st.emergeFrom = nil
			st.burrowLogical = nil
			clearDaze(c.model, st)
			endSkill(c.model, st, c.data, c.now)
		elseif st.emergeFrom then
			local progress = math.min((c.now - st.emergeFrom) / burrow.exitSeconds, 1)
			local sink = burrow.depthStuds + (skill.dazeSinkStuds - burrow.depthStuds) * progress
			c.model:PivotTo(CFrame.new(st.dazeBase - Vector3.new(0, sink, 0)) * CFrame.Angles(0, 0, math.rad(skill.dazeTiltDeg)))
			if progress >= 1 then
				st.emergeFrom = nil
				st.burrowLogical = nil
			end
		end
	end,
	interrupt = function(c)
		surfaceNow(c)
		clearDaze(c.model, c.st)
	end,
}

-- ── line: 보스 중심에서 벽까지 뻗는 직선 directions개. 첫 빔은 대상 방향(centered면 부채의 한가운데가 대상 방향),
--    빔 사이 각 stepDeg. volleys만큼 반복 - 다음 볼리는 rotateDeg 돌리거나(십자) 그 순간의 대상으로 다시 겨눈다(reaim) ──
local function angleToTarget(c)
	local toTarget = xz(c.targetRoot.Position) - xz(c.position)
	return toTarget.Magnitude > 1e-3 and math.deg(math.atan2(toTarget.Z, toTarget.X)) or 0
end

local function firstBeamAngle(c)
	local skill = c.skill
	local spread = skill.centered and skill.stepDeg * ((skill.directions or 1) - 1) / 2 or 0
	return angleToTarget(c) - spread
end

local function startVolley(c, angleDeg)
	local st, skill = c.st, c.skill
	local zone = zoneOf(c.model)
	local origin = xz(c.model.PrimaryPart.Position)
	local beams, lengths = {}, {}
	for k = 0, (skill.directions or 1) - 1 do
		local a = math.rad(angleDeg + skill.stepDeg * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = clipToZone(origin, dir, zone, 1)
		-- 29-3: 지형에 닿으면 거기서 끊긴다 - 예고 띠도 끊긴 길이로 그려진다(보이는 것 = 맞는 것). 막아 준 지형은 발사 때 부서진다.
		local blocker = nil
		if skill.blockedByProp then
			local prop, hitDistance = BossArenaProps.firstHitOnRay(c.model, skill.blockedByProp, origin, dir, length, skill.halfWidthStuds)
			if prop then
				length, blocker = hitDistance, prop.id
			end
		end
		table.insert(beams, { dir = dir, length = length, blocker = blocker })
		lengths[k + 1] = length
	end
	st.crossOrigin = origin
	st.crossBeams = beams
	st.crossAngle = angleDeg
	st.phase = "crossTelegraph"
	st.phaseEndsAt = c.now + skill.telegraphSeconds
	send(st, "cross", {
		center = Vector3.new(origin.X, st.floorY, origin.Z),
		angleDeg = angleDeg,
		stepDeg = skill.stepDeg,
		lengths = lengths,
		halfWidth = skill.halfWidthStuds,
		seconds = skill.telegraphSeconds,
	})
end

HANDLERS.line = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds * (c.skill.volleys or 1)
	end,
	start = function(c)
		c.st.crossVolley = 1
		startVolley(c, firstBeamAngle(c))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if c.now < st.phaseEndsAt then
			return
		end
		judgeBegin()
		for _, v in ipairs(victims(st)) do
			local rel = xz(v.root.Position) - st.crossOrigin
			for _, beam in ipairs(st.crossBeams) do
				local along = rel:Dot(beam.dir)
				if along >= 0 and along <= beam.length and (rel - beam.dir * along).Magnitude <= skill.halfWidthStuds
					and Reach.sameLayer(v.groundFeet, Vector3.new(0, st.floorY, 0)) then -- 22-4: 지면을 탄다(P3a D3: 발 기준)
					applySkillDamage(c.model, c.data, skill, v.player)
					break
				end
			end
		end
		judgeEnd(c, { kind = "beams", origin = Vector3.new(st.crossOrigin.X, st.floorY, st.crossOrigin.Z), beams = st.crossBeams, halfWidth = skill.halfWidthStuds })
		send(st, "crossFire", { angleDeg = st.crossAngle })
		if skill.blockedByProp then
			sendPropsRemoved(st, BossArenaProps.removeWhere(c.model, function(prop)
				for _, beam in ipairs(st.crossBeams) do
					if beam.blocker == prop.id then
						return true
					end
				end
				return false
			end))
		end
		if st.crossVolley < (skill.volleys or 1) then
			st.crossVolley += 1
			startVolley(c, (skill.reaim and c.targetRoot) and firstBeamAngle(c) or (st.crossAngle + skill.rotateDeg))
			return
		end
		endSkill(c.model, st, c.data, c.now)
	end,
}

-- ── gimmick: 전역 기믹의 뼈대(29-1). 예고(게이트가 선다) → 판정(보스별 파훼 조건은 BossMechanics.registerJudge) ──
-- 힌트 단계(20.73 [1-5]): 1 = 말풍선 ×bubbleScale + 안전지대 흰 화살표, 2 이상 = 예고 ×telegraphMultiplier.
-- 29-3에서 붙은 조각(전부 선택 - 없으면 29-1 뼈대 그대로다):
--   safeProp = 지형 종류      그 지형의 "뒤"가 안전지대다 - 클라가 바닥 전체를 빨강으로 깔고 그림자만 비운다 · 힌트 화살표의 자리
--   onResolve = { 조각 }      판정 뒤 실행(가려 준 기둥이 부서진다)
--   stance = { afterSeconds, damageTakenMultiplier, ringRadiusStuds, sinkStuds }
--                             예고 afterSeconds 뒤부터 판정까지 보스가 "태세"다 - 받는 피해 배율이 바뀌고, 그동안 때린 사람에게
--                             반사가 돌아간다(BossMechanics.beginReflect). 힌트 2단계는 태세가 아니라 그 앞의 예고를 늘린다.
--   finisher = { telegraphSeconds, radiusStuds, offsetStuds, damage, damageLabel, trapOnHit }
--                             판정과 같은 순간의 마무리 일격(보스 앞쪽 원). 예고는 판정 telegraphSeconds 전에 뜬다. trapOnHit이면
--                             맞은 사람이 그 자리에 잡힌다(전갈 여왕의 꼬리 내려찍기 → 모래 무덤).
--   recoverPose = true        recoverSeconds 동안 헤롱 자세(dazeSinkStuds·dazeTiltDeg) - "지금 때려라"를 돌진 뒤 헤롱과 같은 그림으로
local function gimmickTelegraphSeconds(st, skill)
	local multiplier = (st.hintLevel or 0) >= BossData.mechanics.hint.maxLevel and BossData.mechanics.hint.telegraphMultiplier or 1
	if skill.stance then
		return skill.telegraphSeconds + skill.stance.afterSeconds * (multiplier - 1)
	end
	return skill.telegraphSeconds * multiplier
end

local function endStance(c)
	if c.st.stanceOn then
		c.st.stanceOn = false
		BossMechanics.endReflect(c.model)
		send(c.st, "stanceEnd", {})
	end
end

-- 시한 안전 구역(29-4, skill.safeZone = { tag, sinkSeconds, shakeSeconds, waterRiseStuds } - 심해 군주의 단): 예고가 도는 동안
-- 멤버가 그 구역(아레나 kit의 tag 파트)을 **처음 밟는 순간**을 멤버별로 적고 그 사람의 클라에만 알린다 - 가라앉는 그림과
-- 발밑 충돌은 각자의 클라가 자기 시계로 한다(서버 인스턴스는 그대로다 - 누가 밟아도 남의 단은 안 움직인다).
-- 잡힌 사람은 밟지 못한다. 가장자리는 몸통 반폭만큼 너그럽다(안전지대는 넓게 판정한다 - 29-3 기둥 그림자와 같다).
local function trackZoneSteps(c)
	local st, safeZone = c.st, c.skill.safeZone
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	for _, v in ipairs(victims(st)) do
		if not BossTrap.isTrapped(v.player) then
			for _, zone in ipairs(kitZones(c.model, st, c.data, safeZone.tag)) do
				if BossPropMath.insideBox(v.root.Position, zone.center, zone.size, half)
					and BossMechanics.noteZoneStep(c.model, v.player, zone.index, c.now + st.zoneSinkSeconds) then
					print(("[forge-game] 단 밟음: %s - %d번, %.2f초 뒤 가라앉는다(판정까지 %.2f초)"):format(
						tostring(v.player.Name), zone.index, st.zoneSinkSeconds, st.phaseEndsAt - c.now))
					sendTo(v.player, "zoneStep", {
						index = zone.index, center = zone.center, size = zone.size, floorY = st.floorY,
						sinkSeconds = st.zoneSinkSeconds, shakeSeconds = safeZone.shakeSeconds,
					})
				end
			end
		end
	end
end

local function endZones(c)
	if c.skill.safeZone then
		send(c.st, "zonesReset", {}) -- 범람이 끝나면(정상·중단·리셋) 가라앉은 단이 전부 돌아온다
	end
end

-- ── 분열(29-5, skill.split = { count, radiusStuds, circleRadiusStuds } - 수정 여왕의 프리즘 분열: 대상 선택) ──
-- 예고가 시작되는 틱에 보스가 분열 중심(지금 자리 - 네 자리가 아레나 안에 들어오게 자른다)의 네 방위 중 한 자리로 옮겨 가고
-- 나머지 자리에 분신이 선다. **분신·빨강 원·진짜의 흰 카운트다운이 같은 틱에 나온다** - 분신을 때릴 수 있는 순간에는 이미
-- 진짜를 가릴 단서가 있다(20.79 [J]의 시작 확인). 분신은 겉모습이 진짜와 완전히 같다(MonsterSpawner.spawnRescueTarget
-- lookLike - 체격·색·부착물·이름·HP바·게이트 표식). 구분은 색이 아니라 **움직임**이다: 진짜의 원에서만 흰 원이 자란다.
--   · 진짜를 때리면: 그 틱에 판정으로 넘어간다 → 전원 성공(성공은 파티 단위) → 분신 소멸 · 결정화 전원 해제 · 기절(기회 창).
--   · 분신을 때리면: 그 분신이 깨지고 **때린 사람에게만** 부분 실패 피해(55% ÷ 3) + 결정화. 제한 시간이 지나면 파편 폭풍
--     (판정 실패 = 55%, 잡힘 없음 - failTraps = false). 둘 다 발동당 1인 상한(applyGimmickDamage)을 같이 쓴다 → 한 번의
--     분열에서 받는 %피해의 합은 55%를 넘지 않는다(셋 다 틀린 사람에게 폭풍은 0이다).
--   · 막을 수 없는 벌은 벌이 아니다(29-3 갑각 반사와 같은 원칙 - 같은 hitInfo를 본다): ① 분열 **전에** 시작한 공격(날아가던
--     화살·이미 돌던 채널)은 분신을 깨지도 벌하지도 않고, 진짜에 닿아도 풀어 주지 않는다 ② 지연 폭발(indirect)은 언제나 무시
--     ③ 같은 틱에 진짜도 같이 때린 광역기는 벌이 없다(벌은 그 틱이 끝난 뒤에 매긴다) ④ 벌은 reflect.windowSeconds(0.75초)에
--     한 번 - 광역기 한 번에 분신 둘이 깨져도 한 번이다.
-- 분신의 목록은 st가 아니라 이 표에 둔다 - 보스가 처치되면 MonsterState가 st를 비우므로(clearProps 주석) 끝나는 모든 길
-- (판정·중단·전멸 리셋·처치·이탈)에서 치우려면 모델로 찾을 수 있어야 한다.
local decoysOf = {} -- [보스 Model] = { [자리 번호] = 분신 Model }

local function removeDecoys(model)
	local decoys = decoysOf[model]
	if decoys then
		decoysOf[model] = nil
		for _, decoy in pairs(decoys) do
			MonsterSpawner.removeRescueTarget(decoy)
		end
	end
end

local function endSplit(c, solved)
	local st = c.st
	if not st.split then
		return
	end
	st.split.resolved = true
	st.split = nil
	MonsterState.setHitListener(c.model, nil)
	removeDecoys(c.model)
	send(st, "splitEnd", { solved = solved == true })
end

local function beginSplit(c, seconds)
	local st, skill, split = c.st, c.skill, c.skill.split
	local zone = zoneOf(c.model)
	local center = clampToZone(xz(c.position), zone, split.radiusStuds + split.circleRadiusStuds)
	local realIndex = scatterRng:NextInteger(1, split.count)
	local spots = {}
	for i = 1, split.count do
		local angle = (i - 1) / split.count * 2 * math.pi
		spots[i] = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * split.radiusStuds
	end
	local state = { startedAt = c.now, realIndex = realIndex, spots = spots, solved = false, resolved = false, lastPunishAt = {} }
	st.split = state
	c.model:PivotTo(CFrame.new(Vector3.new(spots[realIndex].X, c.position.Y, spots[realIndex].Z)))

	local model, data = c.model, c.data
	local mechanics = BossData.mechanics
	local fraction = mechanics.gimmickFailMaxHpFraction / mechanics.partialFailDivisor
	local function blockedOrLate(hitInfo)
		return (hitInfo and hitInfo.indirect) or ((hitInfo and hitInfo.committedAt) or os.clock()) < state.startedAt
	end
	local decoys = {}
	decoysOf[model] = decoys
	for i = 1, split.count do
		if i ~= realIndex then
			local decoy
			decoy = MonsterSpawner.spawnRescueTarget({
				lookLike = data,
				position = Vector3.new(spots[i].X, c.position.Y, spots[i].Z),
				remaining = function()
					return MonsterState.getHpRatio(model) -- HP바도 진짜와 같다
				end,
				onHit = function(player, hitInfo)
					if state.resolved or decoys[i] ~= decoy or blockedOrLate(hitInfo) then
						return
					end
					decoys[i] = nil
					MonsterSpawner.removeRescueTarget(decoy)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					send(st, "splitBreak", { index = i, to = root and root.Position or spots[i] })
					task.defer(function() -- 같은 틱에 진짜도 맞았으면(광역기) 벌이 없다
						local now = os.clock()
						local last = state.lastPunishAt[player]
						if state.solved or (last and now - last < mechanics.reflect.windowSeconds) then
							return
						end
						state.lastPunishAt[player] = now
						BossMechanics.applyGimmickDamage(model, player, fraction, split.decoyLabel)
						if (PlayerState.getHp(player) or 0) > 0 then
							BossMechanics.trapMember(model, data, player)
						end
					end)
				end,
			}, MonsterState.getZoneKey(model))
			decoy:SetAttribute("GateArmed", true) -- 게이트 표식(◈)도 진짜와 같게 - 예고와 함께 게이트가 선 뒤다
			decoys[i] = decoy
		end
	end
	MonsterState.setHitListener(model, function(player, hitInfo)
		if state.resolved or state.solved or blockedOrLate(hitInfo) then
			return
		end
		state.solved = true
		state.solvedBy = player
		st.phaseEndsAt = os.clock() -- 다음 틱에 판정으로 넘어간다(제한 시간 전에 풀었다)
	end)
	local floorSpots = {}
	for i, spot in ipairs(spots) do
		floorSpots[i] = Vector3.new(spot.X, st.floorY, spot.Z)
	end
	send(st, "splitStart", { spots = floorSpots, realIndex = realIndex, radius = split.circleRadiusStuds, seconds = seconds })
	print(("[forge-game] 분열: 진짜 = %d번 자리, 분신 %d체, 제한 %.1f초"):format(realIndex, split.count - 1, seconds))
	return floorSpots[realIndex]
end

HANDLERS.gimmick = {
	bubbleSeconds = function(c)
		return gimmickTelegraphSeconds(c.st, c.skill)
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		local seconds = gimmickTelegraphSeconds(st, skill)
		local hintLevel = st.hintLevel or 0
		local zone = zoneOf(c.model)
		BossMechanics.onGimmickStart(c.model)
		st.phase = "gimmickTelegraph"
		st.phaseEndsAt = c.now + seconds
		local realSpot = skill.split and beginSplit(c, seconds) or nil -- 29-5: 게이트가 선 뒤에(분신의 표식이 진짜와 같게)
		st.stanceAt = skill.stance and (c.now + seconds - (skill.telegraphSeconds - skill.stance.afterSeconds)) or nil
		st.stanceOn = false
		st.finisherCenter = nil
		if skill.safeProp then
			print(("[forge-game] 기믹 예고: %s - %s %d개"):format(tostring(skill.kind), skill.safeProp, BossArenaProps.count(c.model, skill.safeProp)))
		end
		-- 29-4 시한 안전 구역: 힌트 2단계로 예고가 늘어나면 가라앉는 시간도 같은 만큼 늘린다 - "너무 이른" 창(예고 − sinkSeconds)은
		-- 늘 같은 길이다(예고만 늘리면 친절해지는 게 아니라 일찍 밟아 실패하는 창이 1초 → 4초로 넓어진다).
		local safeZone = skill.safeZone
		local zones = safeZone and kitZones(c.model, st, c.data, safeZone.tag) or nil
		local zoneSpots = nil
		-- 29-4 원형 안전지대(skill.safeCircles = { tag } - 폭풍 군주의 과충전: 피뢰침 곁): 클라가 빨강 바닥에서 그 원만 비운다.
		local safeCircles = nil
		if skill.safeCircles then
			safeCircles, zoneSpots = {}, {}
			for _, z in ipairs(kitZones(c.model, st, c.data, skill.safeCircles.tag)) do
				table.insert(safeCircles, { center = Vector3.new(z.center.X, st.floorY, z.center.Z), radius = z.radius })
				table.insert(zoneSpots, Vector3.new(z.center.X, st.floorY, z.center.Z))
			end
		end
		if safeZone then
			st.zoneSinkSeconds = safeZone.sinkSeconds + (seconds - skill.telegraphSeconds)
			BossMechanics.beginZones(c.model, st.phaseEndsAt)
			print(("[forge-game] 기믹 예고: %s - %s %d곳, 밟은 뒤 %.1f초에 가라앉는다"):format(tostring(skill.kind), safeZone.tag, #zones, st.zoneSinkSeconds))
			zoneSpots = {}
			for _, zone in ipairs(zones) do
				table.insert(zoneSpots, zone.center + Vector3.new(0, zone.size.Y / 2, 0))
			end
		end
		send(st, "gimmickTelegraph", {
			kind = skill.kind,
			center = Vector3.new(c.position.X, st.floorY, c.position.Z),
			seconds = seconds,
			hintLevel = hintLevel,
			safeProp = skill.safeProp,
			zoneCenter = Vector3.new(zone.center.X, st.floorY, zone.center.Z),
			zoneHalfSize = zone.halfSize,
			zoneRadius = zone.radius, -- P3a C: 원형 아레나면 클라가 빨강 바닥을 원으로 깐다
			floorColor = (BossArenaMap.getTheme(MonsterState.getZoneKey(c.model)) or BossArenaMapData.default).floor.color, -- 그림자 띠(안전지대)를 맵 바닥색으로
			-- 29-4: 시한 안전 구역(단)의 자리와 시계 - 클라가 물(위험색 판이 차오른다)과 "아직 이르다"(윗면 빨강)를 그린다.
			safeZone = safeZone and {
				zones = zones, sinkSeconds = st.zoneSinkSeconds, earlySeconds = seconds - st.zoneSinkSeconds,
				riseStuds = safeZone.waterRiseStuds,
			} or nil,
			safeCircles = safeCircles,
			-- 힌트 1단계부터 클라가 흰 화살표를 세우는 자리.
			safeSpots = hintLevel >= 1 and (zoneSpots or (realSpot and { realSpot }) or (skill.safeProp and BossArenaProps.safeSpots(c.model, skill.safeProp, c.position, 2))) or nil,
		})
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "gimmickTelegraph" then
			if skill.stance and not st.stanceOn and c.now >= st.stanceAt and c.now < st.phaseEndsAt then
				st.stanceOn = true
				BossMechanics.beginReflect(c.model, skill.stance, skill.damageLabel, function(player)
					local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
					send(st, "reflectHit", { from = c.position, to = root and root.Position or c.position })
				end)
				st.dazeBase = c.position
				c.model:PivotTo(CFrame.new(c.position - Vector3.new(0, skill.stance.sinkStuds, 0)))
				send(st, "stanceStart", {
					center = Vector3.new(c.position.X, st.floorY, c.position.Z),
					radius = skill.stance.ringRadiusStuds,
					seconds = st.phaseEndsAt - c.now,
				})
			end
			local finisher = skill.finisher
			if finisher and not st.finisherCenter and c.now >= st.phaseEndsAt - finisher.telegraphSeconds then
				-- 마무리 일격의 자리 = 보스에서 지금 대상 쪽으로 offsetStuds. 예고가 뜬 뒤에는 움직이지 않는다.
				local origin = xz(st.dazeBase or c.position)
				local toTarget = c.targetRoot and (xz(c.targetRoot.Position) - origin) or Vector3.new(0, 0, -1)
				local dir = toTarget.Magnitude > 1e-3 and toTarget.Unit or Vector3.new(0, 0, -1)
				local center = clampToZone(origin + dir * finisher.offsetStuds, zoneOf(c.model), 2)
				st.finisherCenter = Vector3.new(center.X, st.floorY, center.Z)
				send(st, "heavyTelegraph", { center = st.finisherCenter, radius = finisher.radiusStuds, seconds = st.phaseEndsAt - c.now })
			end
			if skill.safeZone then
				trackZoneSteps(c) -- 판정 틱에도 먼저 돈다 - 마지막 순간에 올라선 사람도 기록된 뒤에 판정받는다
			end
			if c.now < st.phaseEndsAt then
				return
			end
			endStance(c)
			local list = victims(st)
			local broken = BossMechanics.resolveGimmick(c.model, c.data, skill, list, skill.damageLabel)
			if st.split then
				-- 29-5: 진짜를 찾았으면 결정화된 친구가 전부 풀린다("진짜를 찾아 때린다" - F 홀드와 나란히 있는 이 보스만의 길)
				if broken then
					for _, v in ipairs(list) do
						local record = BossTrap.getRecord(v.player)
						if record and record.kind == c.data.mechanics.trapKind then
							BossTrap.release(v.player, "rescued")
						end
					end
				end
				endSplit(c, broken)
			end
			if finisher and st.finisherCenter then
				for _, v in ipairs(list) do
					if Reach.horizontalDistance(v.root.Position, st.finisherCenter) <= finisher.radiusStuds and Reach.sameLayer(v.groundFeet, st.finisherCenter) and not BossTrap.isTrapped(v.player) then -- P3a D3: 발 기준
						applySkillDamage(c.model, c.data, finisher, v.player)
						if finisher.trapOnHit and (PlayerState.getHp(v.player) or 0) > 0 then
							BossMechanics.trapMember(c.model, c.data, v.player)
						end
					end
				end
				send(st, "heavyImpact", { center = st.finisherCenter, radius = finisher.radiusStuds })
			end
			runEffects(c, skill.onResolve, {})
			send(st, "gimmickResolve", {
				broken = broken,
				windowSeconds = broken and skill.breakWindow and skill.breakWindow.seconds or nil,
			})
			if (skill.recoverSeconds or 0) > 0 then
				st.phase = "gimmickRecover"
				st.phaseEndsAt = c.now + skill.recoverSeconds
				if skill.recoverPose then
					local base = st.dazeBase or c.position
					st.dazeBase = base
					c.model:PivotTo(CFrame.new(base - Vector3.new(0, skill.dazeSinkStuds, 0)) * CFrame.Angles(0, 0, math.rad(skill.dazeTiltDeg)))
					if not broken then
						send(st, "daze", { seconds = skill.recoverSeconds }) -- 파훼했으면 파랑 말풍선(gateBroken)이 이미 떠 있다
					end
				end
				return
			end
		elseif c.now < st.phaseEndsAt then -- gimmickRecover
			return
		end
		clearDaze(c.model, st)
		endZones(c)
		endSkill(c.model, st, c.data, c.now)
	end,
	interrupt = function(c)
		endStance(c)
		endZones(c)
		endSplit(c, false)
		clearDaze(c.model, c.st)
	end,
}

-- ─────────────────────────── 틱 ───────────────────────────

local function context(model, st, data, now, position, targetRoot)
	local c = st.context
	if not c then
		c = { model = model, st = st, data = data }
		st.context = c
	end
	c.skill = st.skill
	c.now = now
	c.position = position
	c.targetRoot = targetRoot
	return c
end

local function startSkill(model, st, data, id, now, position, targetRoot)
	local skill = data.skills[id]
	st.current = id
	st.skill = skill
	st.currentStartedAt = now
	BossScheduler.onSkillStart(st.sched, id)
	BossMechanics.beginActivation(model) -- %최대체력 피해의 발동당 1인 누적을 비운다
	print(("[forge-game] 보스 패턴 시작: %s (직전 종료 후 %.2f초)"):format(id, now - st.sched.lastEndAt))
	local c = context(model, st, data, now, position, targetRoot)
	local handler = HANDLERS[skill.primitive]
	-- 전조 말풍선 - 모든 스킬이 예고 시작 순간 하나씩 띄운다. 그림은 클라(BossPatternVisuals)가 bubble 키로 고른다.
	send(st, "bubble", {
		pattern = skill.bubble or id,
		seconds = handler.bubbleSeconds(c),
		scale = ((skill.primitive == "gimmick" or skill.gate) and (st.hintLevel or 0) >= 1) and BossData.mechanics.hint.bubbleScale or nil,
	})
	handler.start(c)
	runEffects(c, skill.onStart, {}) -- 29-3: 스킬이 시작되며 까는 것(모래 구덩이)
end

-- 반환: true면 스킬 진행 중(보스 구속 - MonsterAI는 추격·평타를 건너뛴다).
-- members(24-1): 이 보스와 싸우는 멤버 목록(BossEncounter.getMembersOfModel) - 피해·연출 대상. 생략하면 target 하나.
function BossPatterns.step(model, data, position, target, targetRoot, dt, members)
	local st = ensureState(model, data)
	if not st then
		return false
	end
	st.target = target
	st.targetRoot = targetRoot
	st.position = position
	st.members = (members and #members > 0) and members or { target }
	local now = os.clock()
	BossMechanics.tick(st.members, dt) -- 29-1: 잡힌 멤버의 구출 핸들러
	tickHazards(model, st, data, now) -- 29-3: 위험 지형(모래 구덩이)의 중심부 피해

	if st.phase == "normal" then
		local pickCtx = st.pickCtx
		pickCtx.now = now
		pickCtx.graceUntil = st.graceUntil
		-- 격노(HP ≤ enragedHpFraction)에서만 전역 쿨이 짧아진다(사용자 지시 - 연속 사용은 체력 20% 이하에서만).
		pickCtx.enraged = MonsterState.getHpRatio(model) <= data.scheduler.enragedHpFraction
		local pick = BossScheduler.pick(st.sched, data.skills, data.skillOrder, data.scheduler, pickCtx)
		-- P3a의 "구조물 곁을 5바퀴 맴돌면 보스가 부순다"는 P3c C8에서 없앴다 - 돌진 대상이 가장 가까운 사람이라 구조물 뒤에 숨으면 돌진이 온다(구조물 파괴 + 기절).
		if pick then
			startSkill(model, st, data, pick, now, position, targetRoot)
			return true
		end
		return false
	end

	local handler = HANDLERS[st.skill.primitive]
	handler.step(context(model, st, data, now, position, targetRoot))
	return true
end

-- 진행 중인 스킬을 즉시 취소한다(대상 사망·퇴장·리쉬). 안 하면 다음에 다시 어그로를 잡았을 때 지난 예고가
-- 그대로 남아 재회 즉시 "공짜 강타"가 나가거나, 색·높이가 예고 상태로 멈춘 채 남는다.
function BossPatterns.interrupt(model, data)
	local st = MonsterState.getBossPatternState(model)
	if not st or not st.phase or st.phase == "normal" then
		return
	end
	setBodyColor(model, data.bodyColor)
	local handler = st.skill and HANDLERS[st.skill.primitive]
	if handler and handler.interrupt then
		handler.interrupt(context(model, st, data, os.clock(), st.position, st.targetRoot))
	end
	clearDaze(model, st)
	st.waves = {}
	send(st, "reset", {})
	endSkill(model, st, data, os.clock(), true) -- P3d D1: 중단이면 onComplete(재생성)를 건너뛴다
end

-- 29-5 탱커 훅 ②(PRD 20.80 [F]) - 도발 인터럽트의 진입점. 탱커의 도발 스킬이 생기면 SkillServer가 여기를 부른다.
-- 지금은 **아무것도 바꾸지 않는다**: 시각만 적고(스케줄러·st) false를 돌려준다 - 스킬을 끊지도, 대상을 바꾸지도, 반격을 열지도 않는다.
-- 채울 때 할 일(설계): ① 진행 중인 스킬이 interruptible이면 끊는다(interrupt) ② 대상을 도발한 사람으로 고정(MonsterAI가 st.tauntTarget을
-- 읽는다) ③ BossScheduler가 전역 쿨을 건너뛰고 다음 스킬을 고른다(반격 - 도발이 공짜 스턴이 되지 않게).
-- 반환: 도발이 먹혔는가(지금은 늘 false).
function BossPatterns.onTaunt(model, data, player)
	local st = ensureState(model, data)
	if not st then
		return false
	end
	st.lastTaunt = { player = player, at = os.clock() }
	BossScheduler.noteTaunt(st.sched, os.clock())
	return false
end

-- 어그로가 붙는 순간(idle→chasing) 시계를 새로 잰다 - "첫 예고는 전투 시작 뒤 쿨만큼"을 재도전·재어그로에도 유지한다.
function BossPatterns.onAggro(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
	end
end

-- 플레이어 사망 리셋(21-3 [1], BossEncounter.resetFor) - 스킬·파동·연출·게이트 전부 처음 상태로.
function BossPatterns.reset(model, data)
	BossPatterns.interrupt(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
		st.target = nil
		st.zoneCharges = nil -- 29-4: 충전된 피뢰침도 처음 상태로(클라는 "reset"에서 빛을 끈다)
	end
	BossMechanics.reset(model)
	BossPatterns.clearProps(model)
end

-- 29-3: 동적 지형을 전부 치운다 - 전멸 리셋(재도전 = 처음부터)과 보스전 종료(BossEncounter.endEncounter).
-- members를 직접 받는다 - 보스가 처치된 뒤에는 MonsterState가 이미 비워져 st.members를 읽을 수 없다.
function BossPatterns.clearProps(model, members)
	local st = MonsterState.getBossPatternState(model)
	BossArenaProps.clear(model)
	removeDecoys(model) -- 29-5: 분열 도중에 보스전이 끝나도(처치·이탈) 분신이 남지 않는다
	for _, member in ipairs(members or (st and st.members) or {}) do
		BossPatterns.clearPropsFor(member)
	end
end

-- P3a D3: 한 사람의 화면에 떠 있는 예고(원 · 선 · 말풍선 · 파동)를 전부 지운다 - 보스전이 끝나거나 그 사람이 빠질 때(BossEncounter). 판정이 더는 없는
-- 장판이 화면에 남지 않게 한다("보이는 장판 = 실제 판정"). 클라의 "reset" 처리 그대로다.
function BossPatterns.clearTelegraphsFor(player)
	if typeof(player) == "Instance" and player.Parent then
		patternEvent:FireClient(player, "reset", {})
	end
end

-- 한 사람의 화면에서만 치운다(보스전 이탈 - 같은 슬롯의 다음 보스전에 옛 기둥이 남아 있으면 안 된다).
function BossPatterns.clearPropsFor(player)
	if typeof(player) == "Instance" and player.Parent then
		patternEvent:FireClient(player, "propsClear", {})
	end
end

-- 입장·재도전 유예(20.44 [3](다)) - 이 시각 전엔 스킬을 시작하지 않는다.
function BossPatterns.setGrace(model, data, seconds)
	local st = ensureState(model, data)
	if st then
		st.graceUntil = os.clock() + seconds
	end
end

-- DevTools 전용 - 진행 중인 스킬을 끊고 다음 틱에 특정 스킬을 강제로 시작한다(전역 쿨·유예·쿨·조건 전부 무시).
function BossPatterns.force(model, data, id)
	local st = ensureState(model, data)
	if not st or not data.skills[id] then -- 견습 모드는 data.skills가 부분집합이다 - 없는 스킬은 강제도 막는다
		return false
	end
	BossPatterns.interrupt(model, data)
	BossScheduler.force(st.sched, id)
	st.graceUntil = 0
	return true
end

-- 29-3 잠행: 모델이 땅속에 그려져 있는 동안의 "지표의 논리 위치"(아니면 nil). MonsterAI가 보스의 위치로 이것을 쓴다 -
-- 가라앉은 루트 좌표로 대상과의 높이차를 재면 점프한 대상을 "다른 층"으로 보고 추격을 포기(= 스킬 중단)한다.
function BossPatterns.getLogicalPosition(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.burrowLogical or nil
end

function BossPatterns.getPhase(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.phase or "normal"
end

-- 29-1 힌트 단계(PRD 20.73 [1-5]) - BossEncounter가 스폰·전멸 리셋 때 넣는다.
function BossPatterns.setHintLevel(model, data, level)
	local st = ensureState(model, data)
	if st then
		st.hintLevel = level
	end
end

function BossPatterns.getHintLevel(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.hintLevel or 0
end

-- 자동 검증 전용 - 스킬별 "다음에 쓸 수 있을 때까지 남은 시간(초)" 사본, 시계가 시작된 시각(os.clock 기준), 지금 도는 스킬.
-- 시계는 어그로가 붙는 순간 다시 시작되므로(onAggro) 실시간 검증은 반드시 이 시각을 기준으로 잰다(29-1의 교훈).
function BossPatterns.debugClocks(model)
	local st = MonsterState.getBossPatternState(model)
	local clocks = {}
	if st and st.sched then
		local now = os.clock()
		for id, at in pairs(st.sched.readyAt) do
			clocks[id] = at - now
		end
		return clocks, st.sched.startedAt, st.current
	end
	return clocks, nil, nil
end

return BossPatterns
