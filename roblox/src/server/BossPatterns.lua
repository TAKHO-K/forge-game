-- 보스 패턴 상태 머신 + 스케줄러(21-3, PRD-forge-game-roblox.md 20.44 [3](나) 설계의 구현).
-- 15-1의 tryBossAttack(예고 후 강한 일격 하나)을 "패턴 5종이 한 번에 하나씩 도는" 구조로
-- 일반화했다. MonsterAI.server.lua는 매 Heartbeat마다 step()을 부르고, 반환값이 true(패턴
-- 진행 중 - 보스 구속)면 추격·평타를 건너뛴다. 판정은 전부 서버가 한다 - 클라는 어떤 상태도
-- 보고하지 않고(점프 여부조차), BossPatternEvent로 받은 예고·연출만 그린다(BossPatternVisuals.
-- client.lua). 상수는 전부 BossData.bosses[id].patterns(단일 출처)에서 읽는다.
--
-- 상태는 MonsterState.getBossPatternState(model)이 돌려주는 테이블 하나에 산다 - 보스가
-- 죽거나 물러나 MonsterState.clear가 불리면 같이 사라진다(별도 정리 코드가 필요 없다).
--
-- 스케줄러 규칙(겹침 방지가 이 파일의 존재 이유 - 지시 [5]):
--   (1) phase가 "normal"일 때만 새 패턴을 시작한다 → 두 패턴이 동시에 도는 일이 구조적으로
--       없다. (2) 직전 패턴 종료 후 patternMinGapSeconds가 지나야 한다. (3) 입장·재도전
--       유예(graceUntil) 중엔 시작하지 않는다. (4) 후보(자기 nextAt이 지난 패턴) 중 가장
--       오래 기다린 것부터. 각 패턴의 nextAt은 "그 패턴이 끝난 시각 + intervalSeconds"다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local PlayerState = require(script.Parent.PlayerState)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local MonsterState = require(script.Parent.MonsterState)
local PlayerDamage = require(script.Parent.PlayerDamage)
local GroundProbe = require(script.Parent.GroundProbe)
-- 29-1(PRD 20.73 [2-8]): 기믹 실패 피해·파훼 게이트·잡힘 구출 틱. 힌트 상수는 BossData.mechanics.hint.
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossMechanics = require(script.Parent.BossMechanics)

local BossPatterns = {}

-- 22-4 높이 규칙(다음 세션 보스맵이 그대로 쓴다, PRD 20.50 [2]):
--   · 모든 패턴 판정은 XZ 수평 + |ΔY| ≤ TerrainConfig.heightToleranceStuds(8). 파동·낙석·십자
--     화염은 "그 패턴의 지면 Y"(파동 중심 = 보스 발밑, 낙석 = 낙하점 지면, 십자 = 보스 발밑)
--     기준이라 8 넘게 높은 언덕 위 플레이어에겐 닿지 않는다(절벽 = 안전지대, 의도).
--   · 돌진 이동은 매 틱 지면 Y를 따른다(GroundProbe) - 경사에서 땅에 박히거나 뜨지 않는다.
--     경사 한계를 넘는 단차를 만나면 그 자리에서 돌진이 끝난다(헤롱 시작).
--   · 낙석 낙하점 Y는 그 XZ의 지면 Y(못 찾으면 보스 발밑 floorY).

-- 클라 연출 채널. 아레나 안 멤버 전원(st.members - 24-1 파티, 솔로면 그 한 명)에게 보낸다.
local patternEvent = Instance.new("RemoteEvent")
patternEvent.Name = "BossPatternEvent"
patternEvent.Parent = ReplicatedStorage

-- 파동 최대 반경 - 아레나 대각선 반(96×√2≈136)보다 조금 크게. 여기까지 퍼지면 파동을 지운다.
local WAVE_MAX_RADIUS_FACTOR = math.sqrt(2) + 0.05

-- 29-1: "gimmick"은 6종 공통 기믹 패턴의 자리다(예고 → 파훼 판정, 아래 startGimmick) - data.patterns.gimmick이
-- 있는 보스에서만 시계가 생긴다. 지금은 어느 보스 데이터에도 없다(보스별 세션에서 채운다) - 기존 5패턴
-- 보스는 이 항목이 없는 것과 완전히 같게 돈다.
local PATTERN_ORDER = { "heavy", "shockwave", "meteor", "charge", "cross", "gimmick" }

local scatterRng = Random.new()

local function xz(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- 보스가 속한 아레나 zone(WorldConfig.zones.bossArenaN). 없으면(DevTools로 사냥터에 띄운
-- 경우 등) 스폰 지점 중심의 같은 크기 정사각형으로 대신한다.
local function zoneOf(model)
	local zone = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if zone then
		return zone
	end
	return { center = xz(MonsterState.getSpawnPosition(model)), halfSize = WorldConfig.bossArena.halfSizeStuds }
end

-- origin에서 XZ 단위벡터 dir 방향으로 아레나 AABB(margin만큼 안쪽) 안에 머무는 최대 거리.
-- 돌진 도착점·십자 화염 길이가 이걸로 잘려 담장 밖으로 절대 안 나간다(지시 [3]).
local function clipToZone(origin, dir, zone, margin)
	local tMax = math.huge
	for _, axis in ipairs({ "X", "Z" }) do
		local d = dir[axis]
		if math.abs(d) > 1e-6 then
			local lo = zone.center[axis] - zone.halfSize + margin
			local hi = zone.center[axis] + zone.halfSize - margin
			local t = ((d > 0 and hi or lo) - origin[axis]) / d
			tMax = math.min(tMax, t)
		end
	end
	return math.max(tMax, 0)
end

local function clampToZone(position, zone, margin)
	return Vector3.new(
		math.clamp(position.X, zone.center.X - zone.halfSize + margin, zone.center.X + zone.halfSize - margin),
		position.Y,
		math.clamp(position.Z, zone.center.Z - zone.halfSize + margin, zone.center.Z + zone.halfSize - margin)
	)
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

-- 공중 판정(진동파). 21-3 실측(서버 시점): Humanoid 상태(Jumping/Freefall)는 점프 시작 순간
-- 즉시 복제되지만 FloorMaterial은 약 0.2초 늦고 착지 상태(Landed/Running)는 아직 3~6stud
-- 높이에서 먼저 바뀐다 - 그래서 "지면 거리"를 레이캐스트로 직접 재는 것을 주 판정으로,
-- 상태는 점프 시작 직후(아직 높이가 안 붙은 0.1초)의 보조 판정으로만 쓴다. 서 있을 때의
-- 지면 거리 = HipHeight + 루트 반높이(R15 기본 2+1=3, 아바타 스케일이 달라도 이 식은 같다).
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

local function intervalOf(data, id)
	if id == "heavy" then
		return data.heavyAttackIntervalSeconds
	end
	return data.patterns[id].intervalSeconds
end

-- 패턴 시계를 "지금"부터 새로 잰다 - 스폰·어그로 시작·사망 리셋 때 부른다(재도전 = 처음부터).
-- 23-1: 견습 모드는 data.patterns가 부분집합이다(BossRules.buildTutorialInstanceData) - 없는
-- 패턴은 시계 자체를 만들지 않는다(nextAt에 없으면 아래 스케줄러가 자연히 후보에서 뺀다).
-- 29-1: 패턴 cfg에 firstAtSeconds가 있으면 첫 발동만 그 시각이다(이후는 intervalSeconds). seen은
-- "이 시계 주기에서 한 번이라도 시작했는가" - 아래 자리 비우기(reservedUntil)가 읽는다.
local function restartClocks(st, data, now)
	st.nextAt = {}
	st.seen = {}
	for _, id in ipairs(PATTERN_ORDER) do
		if id == "heavy" or data.patterns[id] then
			local cfg = data.patterns[id]
			st.nextAt[id] = now + ((cfg and cfg.firstAtSeconds) or intervalOf(data, id))
		end
	end
	st.lastPatternEndAt = now
end

local function isPriority(data, id)
	local cfg = data.patterns[id]
	return cfg ~= nil and cfg.priority == true
end

-- 패턴 하나가 보스를 구속하는 시간의 상한(자리 비우기 전용 - 넉넉하게 잡는다). 돌진은 아레나를
-- 끝에서 끝까지 달리는 경우, 진동파는 마지막 파동이 최대 반경에 닿아 사라질 때까지.
local function boundSecondsOf(model, data, id)
	if id == "heavy" then
		return data.telegraphWarmupSeconds
	end
	local cfg = data.patterns[id]
	if id == "shockwave" then
		local maxRadius = zoneOf(model).halfSize * WAVE_MAX_RADIUS_FACTOR
		return cfg.telegraphSeconds + cfg.repeatIntervalSeconds * (cfg.waveCount - 1)
			+ (cfg.layerGapSeconds or 0) * ((cfg.layers or 1) - 1) + maxRadius / cfg.waveSpeedStuds
	elseif id == "charge" then
		local maxLength = zoneOf(model).halfSize * 2
		return (cfg.focusSeconds + maxLength / cfg.speedStuds) * (cfg.dashCount or 1) + cfg.recoverSeconds
	elseif id == "cross" then
		return cfg.telegraphSeconds * cfg.volleys
	end
	return cfg.telegraphSeconds
end

-- 자리 비우기(29-1, PRD 20.73 [2-0] 5번 (가)): firstAtSeconds를 가진 우선 패턴이 아직 한 번도 안
-- 나왔으면, 그 시각을 넘겨 끝날 비우선 패턴은 시작하지 않는다. 없으면 6초에 시작한 강공격이 7.5초에
-- 끝나고 최소 간격이 붙어 첫 기믹이 10초가 아니라 13.5초로 밀린다. 우선 패턴이 없는 보스(구간
-- 수호자)는 항상 nil이라 기존 스케줄과 한 틱도 다르지 않다.
local function reservedUntil(st, data)
	local earliest = nil
	for _, id in ipairs(PATTERN_ORDER) do
		local cfg = data.patterns[id]
		if cfg and cfg.priority and cfg.firstAtSeconds and st.nextAt[id] and not st.seen[id] then
			if not earliest or st.nextAt[id] < earliest then
				earliest = st.nextAt[id]
			end
		end
	end
	return earliest
end

local function ensureState(model, data)
	local st = MonsterState.getBossPatternState(model)
	if st and not st.phase then
		local now = os.clock()
		st.phase = "normal"
		st.phaseEndsAt = 0
		st.graceUntil = now + (data.entryGraceSeconds or 0)
		st.waves = {}
		st.floorY = floorYUnder(MonsterState.getSpawnPosition(model))
		restartClocks(st, data, now)
	end
	return st
end

local function setBodyColor(model, color)
	local body = model:FindFirstChild("Body")
	if body then
		body.Color = color
	end
end

local function send(st, kind, payload)
	for _, member in ipairs(st.members or {}) do
		if member.Parent then
			patternEvent:FireClient(member, kind, payload)
		end
	end
end

-- 24-1 파티: 패턴 피해 판정 대상 = 아레나 안 멤버 전원(각자 따로 맞는다 - PRD 20.47 [6](나)
-- 진동파·강공격·낙석·십자는 원래 범위 공격이라 전원 대상, 돌진은 경로 위 전원). 캐릭터가
-- 없거나(리스폰 대기) 이미 죽은 멤버는 뺀다. 솔로면 st.members = { target } 하나뿐이라 21-3과
-- 완전히 같은 판정이다.
local function victims(st)
	local list = {}
	for _, member in ipairs(st.members or {}) do
		local character = member.Parent and member.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (PlayerState.getHp(member) or 0) > 0 then
			table.insert(list, { player = member, root = root })
		end
	end
	return list
end

-- 헤롱 자세 해제 - 똑바로 세운다(돌진 종료·중단·리셋 공통).
local function clearDaze(model, st)
	if st.dazeBase then
		model:PivotTo(CFrame.new(st.dazeBase))
		st.dazeBase = nil
	end
end

local function endPattern(model, st, data, now)
	local id = st.current
	if id then
		print(("[forge-game] 보스 패턴 종료: %s (%.2f초 소요)"):format(id, now - (st.currentStartedAt or now)))
	end
	st.phase = "normal"
	st.current = nil
	st.lastPatternEndAt = now
	if id then
		st.nextAt[id] = now + intervalOf(data, id)
	end
	MonsterState.setLastAttackTick(model, now) -- 패턴 직후 바로 평타가 또 나가지 않게(15-1과 같다)
end

-- ─────────────────────────── 패턴 시작 ───────────────────────────

-- 25-4: 강공격은 원래 지면 예고 도형이 없었다(몸 색 변화 + 말풍선뿐) - 사거리 원을
-- 하나 보낸다. 새 상수 없음 - data.attackRangeStuds·data.telegraphWarmupSeconds
-- 둘 다 기존 필드(변형 적용 시 이미 조정된 값이 그대로 들어온다, BossData VARIANTS.heavy
-- 참고). 보스 중심 고정 반경인 이유: 피해 판정 자체가 Reach.within(맞은 사람, position
-- (보스 좌표), attackRangeStuds)라 "대상 발밑"이 아니라 "보스 중심"이 실제 위험 범위다.
local function startHeavy(model, st, data, now, position)
	st.phase = "heavyTelegraph"
	st.phaseEndsAt = now + data.telegraphWarmupSeconds
	setBodyColor(model, data.telegraphColor)
	send(st, "heavyTelegraph", {
		center = Vector3.new(position.X, st.floorY, position.Z),
		radius = data.attackRangeStuds,
		seconds = data.telegraphWarmupSeconds,
	})
end

local function startShockHop(model, st, data, now, seconds)
	local cfg = data.patterns.shockwave
	st.phase = "shockHop"
	st.hopStartedAt = now
	st.hopSeconds = seconds
	st.phaseEndsAt = now + seconds
	send(st, "shockTelegraph", {
		center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
		seconds = seconds,
		hopHeight = cfg.hopHeightStuds,
	})
end

local function startShockwave(model, st, data, now, position)
	local base = xz(position) + Vector3.new(0, MonsterState.getSpawnPosition(model).Y, 0)
	st.hopBase = base
	st.wavesSpawned = 0
	st.waves = {}
	startShockHop(model, st, data, now, data.patterns.shockwave.telegraphSeconds)
end

-- dashIndex(23-6, 돌진 2연속 변형 - PRD 20.50[6]과 무관하게 순수 지시 [2] 구현): 몇 번째
-- 돌진인지. 첫 시작(startPattern)은 항상 1을 넘긴다 - cfg.dashCount(기본 1, 전갈 여왕만 2)에
-- 도달할 때까지 step()의 charge 단계 종료 분기가 이 함수를 다시 불러 다음 돌진을 잇는다.
local function startCharge(model, st, data, now, position, targetRoot, dashIndex)
	local cfg = data.patterns.charge
	local zone = zoneOf(model)
	local origin = xz(position)
	-- 느낌표가 뜨는 "이 순간"의 좌표를 고정한다(지시 [3] - 이후 추적 안 함).
	local snapshot = xz(targetRoot.Position)
	local dir = snapshot - origin
	if dir.Magnitude < 1e-3 then
		local look = model.PrimaryPart.CFrame.LookVector
		dir = Vector3.new(look.X, 0, look.Z)
		if dir.Magnitude < 1e-3 then
			dir = Vector3.new(0, 0, -1)
		end
	end
	dir = dir.Unit
	local length = clipToZone(origin, dir, zone, cfg.arenaMarginStuds)
	local y = position.Y
	st.chargeDashIndex = dashIndex
	st.chargeFrom = Vector3.new(origin.X, y, origin.Z)
	st.chargeTo = st.chargeFrom + dir * length
	st.chargeDir = dir
	st.chargeHitBy = {} -- 24-1: 돌진 한 번에 멤버마다 한 번씩만(경로 위 전원 대상)
	st.phase = "focus"
	st.phaseEndsAt = now + cfg.focusSeconds
	send(st, "focus", {
		bossPosition = st.chargeFrom,
		endPosition = st.chargeTo,
		halfWidth = cfg.pathHalfWidthStuds,
		seconds = cfg.focusSeconds,
		floorY = st.floorY,
	})
end

local function startMeteor(model, st, data, now, targetRoot)
	local cfg = data.patterns.meteor
	local zone = zoneOf(model)
	local first = xz(targetRoot.Position)
	local positions = { clampToZone(first, zone, 2) }
	for _ = 2, cfg.count do
		local offset = Vector3.new(scatterRng:NextNumber(-1, 1), 0, scatterRng:NextNumber(-1, 1))
		if offset.Magnitude > 1 then
			offset = offset.Unit
		end
		table.insert(positions, clampToZone(first + offset * cfg.scatterStuds, zone, 2))
	end
	for i, p in ipairs(positions) do
		-- 22-4: 낙하점 Y는 그 자리 지면(언덕 위면 언덕 위). 못 찾으면 보스 발밑.
		positions[i] = Vector3.new(p.X, GroundProbe.surfaceY(p.X, p.Z, st.floorY) or st.floorY, p.Z)
	end
	st.meteorPositions = positions
	st.phase = "meteorTelegraph"
	st.phaseEndsAt = now + cfg.telegraphSeconds
	send(st, "meteor", { positions = positions, radius = cfg.radiusStuds, seconds = cfg.telegraphSeconds })
end

local function crossBeams(model, st, data, angleDeg)
	local zone = zoneOf(model)
	local origin = xz(model.PrimaryPart.Position)
	local beams = {}
	for k = 0, 3 do
		local a = math.rad(angleDeg + 90 * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		table.insert(beams, { dir = dir, length = clipToZone(origin, dir, zone, 1) })
	end
	return origin, beams
end

-- 23-6 [2] 십자 회전 변형(storm_lord 전용, cfg.rotates): 판정(beams·lengths·angleDeg)은
-- 한 글자도 안 바꾸고, previousAngle이 있으면 클라 연출에 rotateFromDeg를 얹어 보낸다 -
-- BossPatternVisuals.client.lua가 그 값이 있을 때만 스윕 애니메이션을 그린다(순수 연출,
-- 피해는 여전히 telegraphSeconds가 끝나는 순간의 angleDeg 하나로만 판정된다).
local function startCrossVolley(model, st, data, now, angleDeg)
	local cfg = data.patterns.cross
	local origin, beams = crossBeams(model, st, data, angleDeg)
	local previousAngle = st.crossAngle
	st.crossOrigin = origin
	st.crossBeams = beams
	st.crossAngle = angleDeg
	st.phase = "crossTelegraph"
	st.phaseEndsAt = now + cfg.telegraphSeconds
	local lengths = {}
	for i, b in ipairs(beams) do
		lengths[i] = b.length
	end
	local payload = {
		center = Vector3.new(origin.X, st.floorY, origin.Z),
		angleDeg = angleDeg,
		lengths = lengths,
		halfWidth = cfg.halfWidthStuds,
		seconds = cfg.telegraphSeconds,
	}
	if cfg.rotates and previousAngle then
		payload.rotateFromDeg = previousAngle
	end
	send(st, "cross", payload)
end

local function startCross(model, st, data, now, position, targetRoot)
	local toTarget = xz(targetRoot.Position) - xz(position)
	local angle = toTarget.Magnitude > 1e-3 and math.deg(math.atan2(toTarget.Z, toTarget.X)) or 0
	st.crossVolley = 1
	startCrossVolley(model, st, data, now, angle)
end

-- 말풍선이 떠 있는 시간 = 그 패턴이 "예고 중"인 전체 구간(진동파는 세 번 찍기까지, 십자는
-- 두 볼리까지). 돌진은 정신집중 동안만 - 이후 헤롱 말풍선이 따로 뜬다.
local function bubbleSecondsOf(data, id)
	if id == "heavy" then
		return data.telegraphWarmupSeconds
	elseif id == "charge" then
		return data.patterns.charge.focusSeconds
	elseif id == "shockwave" then
		local cfg = data.patterns.shockwave
		return cfg.telegraphSeconds + cfg.repeatIntervalSeconds * (cfg.waveCount - 1)
	elseif id == "cross" then
		local cfg = data.patterns.cross
		return cfg.telegraphSeconds * cfg.volleys
	end
	return data.patterns[id].telegraphSeconds
end

-- ─────────────────────────── 기믹(29-1 공통 뼈대) ───────────────────────────

-- 힌트 단계(PRD 20.73 [1-5]) - BossEncounter가 전멸 횟수로 정해 setHintLevel로 넣는다.
--   0 기본 / 1 말풍선 ×bubbleScale + 안전지대 흰 화살표 / 2 이상 위에 더해 기믹 예고 ×telegraphMultiplier.
local function gimmickTelegraphSeconds(st, data)
	local seconds = data.patterns.gimmick.telegraphSeconds
	if (st.hintLevel or 0) >= BossData.mechanics.hint.maxLevel then
		seconds *= BossData.mechanics.hint.telegraphMultiplier
	end
	return seconds
end

-- 6종 공통 기믹 패턴의 뼈대: 예고(게이트가 서고 1인 누적 %피해가 비워진다) → 판정(보스별 파훼 조건은
-- BossMechanics.registerJudge로 꽂힌다). 모양(전역 빨강 + 안전지대 비우기 등)은 보스별 세션이
-- cfg.kind에 맞춰 클라에 그린다 - 뼈대는 kind·시간·힌트 단계·안전지대 좌표만 실어 보낸다.
local function startGimmick(model, st, data, now, position)
	local cfg = data.patterns.gimmick
	local seconds = gimmickTelegraphSeconds(st, data)
	local hintLevel = st.hintLevel or 0
	BossMechanics.onGimmickStart(model)
	st.phase = "gimmickTelegraph"
	st.phaseEndsAt = now + seconds
	send(st, "gimmickTelegraph", {
		kind = cfg.kind,
		center = Vector3.new(position.X, st.floorY, position.Z),
		seconds = seconds,
		hintLevel = hintLevel,
		-- 힌트 1단계부터 클라가 흰 화살표를 세우는 자리. 보스별 세션이 cfg.safeSpots(model, data)를 채운다.
		safeSpots = (hintLevel >= 1 and cfg.safeSpots) and cfg.safeSpots(model, data) or nil,
	})
end

local function startPattern(model, st, data, id, now, position, targetRoot)
	st.current = id
	st.currentStartedAt = now
	st.seen[id] = true
	print(("[forge-game] 보스 패턴 시작: %s (직전 종료 후 %.2f초)"):format(id, now - st.lastPatternEndAt))
	-- 전조 말풍선(사용자 지시 - 느낌표·물음표·바닥 그림으로 "스킬을 쓰겠구나"를 읽게) -
	-- 모든 패턴이 예고 시작 순간 하나씩 띄운다. 그림은 클라(BossPatternVisuals)가 고른다.
	if id == "gimmick" then
		send(st, "bubble", {
			pattern = id,
			seconds = gimmickTelegraphSeconds(st, data),
			scale = (st.hintLevel or 0) >= 1 and BossData.mechanics.hint.bubbleScale or nil,
		})
		startGimmick(model, st, data, now, position)
		return
	end
	send(st, "bubble", { pattern = id, seconds = bubbleSecondsOf(data, id) })
	if id == "heavy" then
		startHeavy(model, st, data, now, position)
	elseif id == "shockwave" then
		startShockwave(model, st, data, now, position)
	elseif id == "charge" then
		startCharge(model, st, data, now, position, targetRoot, 1)
	elseif id == "meteor" then
		startMeteor(model, st, data, now, targetRoot)
	elseif id == "cross" then
		startCross(model, st, data, now, position, targetRoot)
	end
end

-- ─────────────────────────── 진동파 판정 ───────────────────────────

-- 매 틱 모든 살아있는 파동에 대해: 파동 띠[반경-두께, 반경]가 대상 플레이어를 지나는 동안
-- 한 순간이라도 공중이면 회피, 띠가 완전히 지나갔는데 한 번도 공중이 아니었으면 피격.
-- "지나는 동안 한 순간이라도"라 점프 입력 창 = 체공 + 통과 시간(BossData 주석 참고).
-- 24-1: 멤버마다 touched/dodged/resolved를 따로 기록한다(wave.byPlayer[player]) - 한 파동이 네
-- 사람을 서로 다른 시각에 지나가므로 판정도 사람마다 독립이다. 파동은 최대 반경까지 살아 있다
-- (예전엔 "대상 하나가 resolved되면 제거"였지만 이제 뒤에 선 멤버가 아직 남아 있을 수 있다).
local function updateWaves(model, st, data, now)
	local cfg = data.patterns.shockwave
	local maxRadius = zoneOf(model).halfSize * WAVE_MAX_RADIUS_FACTOR
	local alive = {}
	local targets = victims(st)
	for _, wave in ipairs(st.waves) do
		local radius = (now - wave.startedAt) * cfg.waveSpeedStuds
		wave.byPlayer = wave.byPlayer or {}
		for _, v in ipairs(targets) do
			local rec = wave.byPlayer[v.player]
			if not rec then
				rec = {}
				wave.byPlayer[v.player] = rec
			end
			local d = (xz(v.root.Position) - wave.center).Magnitude
			-- 22-4: 파동은 지면을 타고 퍼진다 - 파동 중심 지면(floorY)에서 높이차 상한 너머(절벽 위)는 안 닿는다.
			local inBand = d <= radius and d >= radius - cfg.waveThicknessStuds
				and Reach.sameLayer(v.root.Position, Vector3.new(0, st.floorY, 0))
			if inBand then
				rec.touched = true
				if isAirborne(v.player.Character, cfg.airborneClearanceStuds) then
					rec.dodged = true
				end
			elseif rec.touched and not rec.resolved and d < radius - cfg.waveThicknessStuds then
				rec.resolved = true
				if not rec.dodged then
					PlayerDamage.applyHit(v.player, data.attack, "진동파", cfg.damageMultiplier)
				end
			end
		end
		if radius <= maxRadius then
			table.insert(alive, wave)
		end
	end
	st.waves = alive
end

-- 23-6 [2] 진동파 두 겹 변형(abyssal_lord 전용, cfg.layers=2): 한 번 찍을 때 파동을
-- layers개 낸다 - 겹마다 startedAt을 layerGapSeconds(두께÷속도, 파생값)만큼 늦춰 서로
-- 다른 링으로 퍼지게 한다. 각 겹은 독립된 wave라 updateWaves가 항상 그래왔듯 겹마다
-- 따로 판정한다 - cfg.damageMultiplier 자체가 이미 절반(BossData VARIANTS.shockwave)이라
-- 둘 다 맞으면 원래(1겹 전체 피해)와 같아진다.
local function slam(model, st, data, now)
	local cfg = data.patterns.shockwave
	model:PivotTo(CFrame.new(st.hopBase))
	local layers = cfg.layers or 1
	local gap = cfg.layerGapSeconds or 0
	local maxRadius = zoneOf(model).halfSize * WAVE_MAX_RADIUS_FACTOR
	for layer = 1, layers do
		local delay = (layer - 1) * gap
		table.insert(st.waves, { center = xz(st.hopBase), startedAt = now + delay })
		send(st, "shockwave", {
			center = Vector3.new(st.hopBase.X, st.floorY, st.hopBase.Z),
			serverStart = serverNow() + delay,
			speed = cfg.waveSpeedStuds,
			thickness = cfg.waveThicknessStuds,
			maxRadius = maxRadius,
		})
	end
	st.wavesSpawned += 1
end

-- ─────────────────────────── 틱 ───────────────────────────

-- 반환: true면 패턴 진행 중(보스 구속 - MonsterAI는 추격·평타를 건너뛴다).
-- members(24-1): 이 보스와 싸우는 멤버 목록(BossEncounter.getMembersOfModel) - 피해·연출 대상.
-- 생략하면 target 하나(솔로 호출부 호환).
function BossPatterns.step(model, data, position, target, targetRoot, dt, members)
	local st = ensureState(model, data)
	if not st then
		return false
	end
	st.target = target
	st.members = (members and #members > 0) and members or { target }
	local now = os.clock()
	BossMechanics.tick(st.members, dt) -- 29-1: 잡힌 멤버의 구출 핸들러

	if st.phase == "normal" then
		-- 격노(HP ≤ 20%)에서만 패턴을 연속으로 쓴다(사용자 지시) - 평소엔 긴 간격.
		local enraged = MonsterState.getHpRatio(model) <= data.enragedHpFraction
		local gap = enraged and data.enragedPatternMinGapSeconds or data.patternMinGapSeconds
		if now < st.graceUntil or now < st.lastPatternEndAt + gap then
			return false
		end
		-- 29-1: 시간이 된 후보 중 우선 패턴(priority - 기믹)이 먼저다. 같은 급 안에서는 기존 규칙 그대로
		-- 가장 오래 기다린 것부터. 비우선 후보는 자리 비우기(reservedUntil)에 걸리면 건너뛴다.
		local reserved = reservedUntil(st, data)
		local pick, pickAt, pickPriority = nil, math.huge, false
		for _, id in ipairs(PATTERN_ORDER) do
			local at = st.nextAt[id]
			if at and now >= at then
				local priority = isPriority(data, id)
				local blocked = not priority and reserved ~= nil and now + boundSecondsOf(model, data, id) + gap > reserved
				if not blocked and ((priority and not pickPriority) or (priority == pickPriority and at < pickAt)) then
					pick, pickAt, pickPriority = id, at, priority
				end
			end
		end
		if pick then
			startPattern(model, st, data, pick, now, position, targetRoot)
			return true
		end
		return false
	end

	if st.phase == "gimmickTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.gimmick
		local broken = BossMechanics.resolveGimmick(model, data, cfg, victims(st), "기믹 실패")
		send(st, "gimmickResolve", {
			broken = broken,
			windowSeconds = broken and cfg.breakWindow and cfg.breakWindow.seconds or nil,
		})
		endPattern(model, st, data, now)
		return true
	end

	if st.phase == "heavyTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		-- 예고가 끝나는 이 순간의 거리만 본다 - 그 사이 벗어났으면 완전히 무효(15-1 그대로).
		-- 24-1: 사거리 안 멤버 전원(범위 공격 - PRD 20.47 [6](나) "범위 안 전원 피격").
		for _, v in ipairs(victims(st)) do
			if Reach.within(v.root.Position, position, data.attackRangeStuds) then -- 22-4: 수평 + 높이차 상한
				PlayerDamage.applyHit(v.player, data.attack, "강공격", data.heavyAttackMultiplier)
			end
		end
		-- 25-4: 판정 순간 흰 섬광 - 낙석·십자 화염과 같은 "임팩트 = 흰색" 언어를 강공격에도 맞춘다.
		send(st, "heavyImpact", { center = Vector3.new(position.X, st.floorY, position.Z), radius = data.attackRangeStuds })
		setBodyColor(model, data.bodyColor)
		endPattern(model, st, data, now)
		return true
	end

	if st.phase == "shockHop" then
		updateWaves(model, st, data, now)
		local cfg = data.patterns.shockwave
		if now < st.phaseEndsAt then
			local progress = (now - st.hopStartedAt) / st.hopSeconds
			model:PivotTo(CFrame.new(st.hopBase + Vector3.new(0, cfg.hopHeightStuds * math.sin(math.pi * progress), 0)))
			return true
		end
		slam(model, st, data, now)
		if st.wavesSpawned < cfg.waveCount then
			startShockHop(model, st, data, now, cfg.repeatIntervalSeconds)
		else
			st.phase = "shockWait"
		end
		return true
	end

	if st.phase == "shockWait" then
		updateWaves(model, st, data, now)
		if #st.waves == 0 then
			endPattern(model, st, data, now)
		end
		return true
	end

	if st.phase == "focus" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.charge
		local length = (st.chargeTo - st.chargeFrom).Magnitude
		st.phase = "charge"
		st.chargeStartedAt = now
		st.chargeSeconds = length / cfg.speedStuds
		send(st, "charge", { startPosition = st.chargeFrom, endPosition = st.chargeTo, durationSeconds = st.chargeSeconds })
		return true
	end

	if st.phase == "charge" then
		local cfg = data.patterns.charge
		local prev = xz(position)
		local progress = math.min((now - st.chargeStartedAt) / math.max(st.chargeSeconds, 1e-3), 1)
		local newPos = st.chargeFrom:Lerp(st.chargeTo, progress)
		-- 22-4: 돌진도 지면을 따른다. 발밑 기준 프로브 창(±4) 안에 지면이 있으면 그 위로, 계단 한
		-- 단(maxStepHeight)보다 큰 단차·심연이면 여기서 돌진을 끝낸다(진행도 1로 강제 → 헤롱).
		local footY = position.Y - TerrainConfig.monsterFootOffsetStuds
		local groundY = GroundProbe.groundY(newPos.X, newPos.Z, footY)
		if groundY == nil or math.abs(groundY - footY) > TerrainConfig.maxStepHeightStuds then
			newPos = position
			progress = 1
		else
			newPos = Vector3.new(newPos.X, groundY + TerrainConfig.monsterFootOffsetStuds, newPos.Z)
		end
		model:PivotTo(CFrame.new(newPos))
		for _, v in ipairs(victims(st)) do
			if not st.chargeHitBy[v.player] and distanceToSegment(xz(v.root.Position), prev, xz(newPos)) <= cfg.pathHalfWidthStuds
				and Reach.sameLayer(v.root.Position, newPos) then
				st.chargeHitBy[v.player] = true
				-- 29-1: %최대체력 피해는 6종 공통 문으로(PRD 20.73 [2-8] A-1 - 돌진이 그 원칙의 첫 사례). 값은 그대로.
				BossMechanics.applyMaxHpDamage(v.player, cfg.damageMaxHpFraction, "돌진")
			end
		end
		if progress >= 1 then
			-- 23-6 [2] 돌진 2연속 변형: cfg.dashCount(기본 1)에 아직 못 미쳤으면 헤롱 없이
			-- 바로 다음 돌진을 잇는다(현재 위치·현재 대상 좌표로 재조준 - startCharge가
			-- 그 순간 좌표를 새로 고정한다). 마지막 돌진에서만 기존 헤롱(daze) 보상 구간으로
			-- 진입한다.
			if st.chargeDashIndex < (cfg.dashCount or 1) then
				startCharge(model, st, data, now, newPos, targetRoot, st.chargeDashIndex + 1)
			else
				-- 헤롱(주저앉기) - 몸을 내려 기울인다. 이 상태의 위치·기울기는 st.dazeBase로
				-- 기억해 끝날 때(endPattern/interrupt) 똑바로 되돌린다.
				st.phase = "chargeRecover"
				st.phaseEndsAt = now + cfg.recoverSeconds
				st.dazeBase = newPos
				model:PivotTo(CFrame.new(newPos - Vector3.new(0, cfg.dazeSinkStuds, 0)) * CFrame.Angles(0, 0, math.rad(cfg.dazeTiltDeg)))
				send(st, "daze", { seconds = cfg.recoverSeconds })
			end
		end
		return true
	end

	if st.phase == "chargeRecover" then
		if now >= st.phaseEndsAt then
			clearDaze(model, st)
			endPattern(model, st, data, now)
		end
		return true
	end

	if st.phase == "meteorTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.meteor
		for _, v in ipairs(victims(st)) do
			local p = xz(v.root.Position)
			for _, spot in ipairs(st.meteorPositions) do
				if (p - xz(spot)).Magnitude <= cfg.radiusStuds and Reach.sameLayer(v.root.Position, spot) then -- 22-4
					PlayerDamage.applyHit(v.player, data.attack, "낙석", cfg.damageMultiplier)
					break
				end
			end
		end
		send(st, "meteorImpact", { positions = st.meteorPositions, radius = cfg.radiusStuds })
		endPattern(model, st, data, now)
		return true
	end

	if st.phase == "crossTelegraph" then
		if now < st.phaseEndsAt then
			return true
		end
		local cfg = data.patterns.cross
		for _, v in ipairs(victims(st)) do
			local rel = xz(v.root.Position) - st.crossOrigin
			for _, beam in ipairs(st.crossBeams) do
				local along = rel:Dot(beam.dir)
				if along >= 0 and along <= beam.length and (rel - beam.dir * along).Magnitude <= cfg.halfWidthStuds
					and Reach.sameLayer(v.root.Position, Vector3.new(0, st.floorY, 0)) then -- 22-4: 화염은 지면을 탄다
					PlayerDamage.applyHit(v.player, data.attack, "십자 화염", cfg.damageMultiplier)
					break
				end
			end
		end
		send(st, "crossFire", { angleDeg = st.crossAngle })
		if st.crossVolley < cfg.volleys then
			st.crossVolley += 1
			startCrossVolley(model, st, data, now, st.crossAngle + cfg.rotateDeg)
		else
			endPattern(model, st, data, now)
		end
		return true
	end

	return false
end

-- 진행 중인 패턴을 즉시 취소한다(대상 사망·퇴장·리쉬 - 15-1 resetBossPhaseIfNeeded의 일반화).
-- 안 하면 다음에 다시 어그로를 잡았을 때 지난 예고가 그대로 남아 재회 즉시 "공짜 강타"가
-- 나가거나, 색·높이가 예고 상태로 멈춘 채 남는다.
function BossPatterns.interrupt(model, data)
	local st = MonsterState.getBossPatternState(model)
	if not st or not st.phase or st.phase == "normal" then
		return
	end
	setBodyColor(model, data.bodyColor)
	if st.hopBase and (st.phase == "shockHop" or st.phase == "shockWait") then
		model:PivotTo(CFrame.new(st.hopBase))
	end
	clearDaze(model, st)
	st.waves = {}
	send(st, "reset", {})
	endPattern(model, st, data, os.clock())
end

-- 어그로가 붙는 순간(idle→chasing) 패턴 시계를 새로 잰다 - "첫 예고는 전투 시작 뒤 주기만큼"
-- 이라는 15-1의 체감(스폰 6초 뒤 첫 강공격)을 재도전·재어그로에도 그대로 유지한다.
function BossPatterns.onAggro(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
	end
end

-- 플레이어 사망 리셋(21-3 [1], BossEncounter.resetFor) - 패턴·파동·연출 전부 처음 상태로.
function BossPatterns.reset(model, data)
	BossPatterns.interrupt(model, data)
	local st = ensureState(model, data)
	if st then
		restartClocks(st, data, os.clock())
		st.target = nil
	end
	BossMechanics.reset(model) -- 29-1: 게이트도 처음 상태(안 선 상태)로
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

-- 29-1 자동 검증 전용 - 각 패턴의 다음 발동까지 남은 시간(초) 사본.
function BossPatterns.debugClocks(model)
	local st = MonsterState.getBossPatternState(model)
	local clocks = {}
	if st and st.nextAt then
		local now = os.clock()
		for id, at in pairs(st.nextAt) do
			clocks[id] = at - now
		end
	end
	return clocks
end

-- 입장·재도전 유예(20.44 [3](다)) - 이 시각 전엔 패턴을 시작하지 않는다.
function BossPatterns.setGrace(model, data, seconds)
	local st = ensureState(model, data)
	if st then
		st.graceUntil = os.clock() + seconds
	end
end

-- DevTools 전용 - 진행 중인 패턴을 끊고 다음 틱에 특정 패턴을 강제로 시작한다(간격·유예·
-- 시계 전부 무시).
function BossPatterns.force(model, data, id)
	local st = ensureState(model, data)
	-- 23-1: 견습 모드는 data.patterns가 부분집합이다 - 지금 이 보스에 없는 패턴은 강제 시작도 막는다.
	if not st or not table.find(PATTERN_ORDER, id) or (id ~= "heavy" and not data.patterns[id]) then
		return false
	end
	BossPatterns.interrupt(model, data)
	st.nextAt[id] = -math.huge -- 가장 오래 기다린 패턴이 되어 다음 틱에 뽑힌다
	st.lastPatternEndAt = -math.huge
	st.graceUntil = 0
	return true
end

function BossPatterns.getPhase(model)
	local st = MonsterState.getBossPatternState(model)
	return st and st.phase or "normal"
end

return BossPatterns
