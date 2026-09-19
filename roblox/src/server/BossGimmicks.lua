-- 보스별 파훼 판정과 구출 동작(29-3, PRD 20.76) - 29-1 뼈대가 남긴 두 훅에 꽂는다.
--   · BossMechanics.registerJudge(kind, fn)            "이 사람은 이번 기믹을 풀었는가"
--   · BossTrap.registerRescueHandler(rescueType, ...)  "구출 진행은 언제 얼마나 차는가"
-- 키는 보스 이름이 아니라 종류다(behindProp·noHit / hitCount·push) - 같은 종류를 쓰는 보스가 늘어도 이 파일은 그대로다.
-- 29-5: 구출 입력은 F 홀드 하나로 통일됐다(BossTrap) - 여기의 구출 핸들러는 종류별 조건·그림·비용 조각만 갖는다.
-- 수치는 전부 BossData.mechanics.rescue·dodge에 있다. BossPatterns가 require해서 서버가 뜰 때 한 번 등록된다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossMechanics = require(script.Parent.BossMechanics)
local BossTrap = require(script.Parent.BossTrap)
local BossArenaProps = require(script.Parent.BossArenaProps)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local PlayerState = require(script.Parent.PlayerState)

local BossGimmicks = {}

-- 자동 검증의 스탠드인(테이블 Player)도 Character를 가질 수 있다 - Instance인지 묻지 않는다(29-3 Play: 스탠드인 구출자가
-- 여기서 걸러져 밀기 검증이 한 걸음도 못 나갔다. 로컬 하네스의 typeof 스텁은 스탠드인을 Instance로 쳐서 통과했었다).
local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- ─────────────────────────── 파훼 판정 ───────────────────────────

-- behindProp(서리 거인의 포효): 보스 중심 → 플레이어 선분이 cfg.safeProp 지형에 가려지는가. 가장자리는 플레이어에게
-- 유리하게 - 몸통 반폭만큼 너그럽다(shared/BossPropMath.isShielded). 가려 준 지형에는 표시를 남긴다 - 판정 뒤
-- onResolve의 destroyProps { which = "shielding" }이 그것만 부순다.
BossMechanics.registerJudge("behindProp", function(model, _, victim, cfg)
	local bossRoot = model.PrimaryPart
	if not bossRoot then
		return true
	end
	local prop = BossArenaProps.shieldingProp(model, cfg.safeProp, bossRoot.Position, victim.root.Position,
		BossData.mechanics.dodge.characterHalfWidthStuds)
	if prop then
		prop.shielded = true
		return true
	end
	return false
end)

-- noHit(전갈 여왕의 갑각 태세): 태세 동안 반사를 한 번도 받지 않았는가. 반사는 "태세가 선 뒤에 시작한 직접 공격"에만
-- 돌아가므로(BossMechanics.beginReflect), 날아가던 화살이 태세 중에 닿은 사람은 풀어낸 것으로 친다.
BossMechanics.registerJudge("noHit", function(model, _, victim)
	return BossMechanics.reflectCount(model, victim.player) == 0
end)

-- onZone(심해 군주의 범람, 29-4): 판정 순간 cfg.safeZone.tag 구역(아레나 kit의 단) 위에 있고, 그 단이 **이 사람에게** 아직
-- 가라앉지 않았는가(BossMechanics.zoneHolds - 멤버별 시계). 가장자리는 몸통 반폭만큼 너그럽다. 같은 단에 선 친구가 언제
-- 밟았는지는 보지 않는다 - 한 사람의 시계가 다른 사람을 벌하지 않는다.
BossMechanics.registerJudge("onZone", function(model, data, victim, cfg)
	local arena = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if not arena or not cfg.safeZone then
		return true
	end
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	for _, zone in ipairs(BossPropMath.kitZones(data.arenaKit, arena.center, 0, cfg.safeZone.tag)) do
		if BossPropMath.insideBox(victim.root.Position, zone.center, zone.size, half) then
			return BossMechanics.zoneHolds(model, victim.player, zone.index)
		end
	end
	return false
end)

-- nearZone(폭풍 군주의 과충전, 29-4): 판정 순간 cfg.safeCircles.tag 구역(피뢰침)의 안전 반경(kit 파트의 radiusStuds) 안인가.
-- 충전 여부는 보지 않는다 - 피뢰침은 늘 거기 있고, 과충전을 보게 되는 사람은 피뢰침을 못 채운 바로 그 사람이다.
BossMechanics.registerJudge("nearZone", function(model, data, victim, cfg)
	local arena = WorldConfig.zones[MonsterState.getZoneKey(model) or ""]
	if not arena or not cfg.safeCircles then
		return true
	end
	local half = BossData.mechanics.dodge.characterHalfWidthStuds
	for _, zone in ipairs(BossPropMath.kitZones(data.arenaKit, arena.center, 0, cfg.safeCircles.tag)) do
		if Reach.horizontalDistance(victim.root.Position, zone.center) <= zone.radius + half then
			return true
		end
	end
	return false
end)

-- hitReal(수정 여왕의 프리즘 분열, 29-5): 제한 시간 안에 누군가 진짜를 때렸는가. 성공은 파티 단위다 - 한 명이 찾으면
-- 전원이 파편 폭풍을 면한다(분신을 때린 값은 그 사람이 그 순간에 이미 치렀다 - BossPatterns.beginSplit).
BossMechanics.registerJudge("hitReal", function(model)
	local st = MonsterState.getBossPatternState(model)
	return st ~= nil and st.split ~= nil and st.split.solved == true
end)

-- ─────────────────────────── 구출: F 홀드의 보스별 조각(29-5) ───────────────────────────
-- 입력은 6종 공통이다(BossTrap의 F 홀드 - 거리·생존·잡힘·피격 리셋·둘이면 절반은 거기서 본다). 여기는 종류마다 다른 것만:
--   touch(감전)     몸이 닿는 거리(reachStuds 3). rescuerMaxHpFraction > 0이면 구출자가 풀어 주는 순간 그만큼 나눠 받고,
--                   체력이 그 이하면 누를 수 없다(구출로 죽는 일은 없다) - 지금 값은 0이다(BossData.mechanics.rescue.touch 주석).
--   proximity(침수) 조각 없음 - 곁(6stud) 어디서나. 방전은 이미 지나갔고 7.5초 동안 새 판정이 없다.
--   hitCount(빙결)  얼음 곁(6stud)에서 홀드 + 아래의 "얼음을 때린다"가 같은 진행을 채운다.
--   push(속박)      아래 - 홀드가 차는 만큼 묻힌 친구가 구출자 쪽으로 끌려 나온다.
BossTrap.registerRescueHandler("touch", {
	canHold = function(_, _, rescuer)
		local cost = BossData.mechanics.rescue.touch.rescuerMaxHpFraction
		return cost <= 0 or (PlayerState.getHp(rescuer) or 0) > (PlayerState.getMaxHp(rescuer) or 0) * cost
	end,
	onComplete = function(_, _, rescuer)
		local cost = BossData.mechanics.rescue.touch.rescuerMaxHpFraction
		if cost > 0 then
			BossMechanics.applyMaxHpDamage(rescuer, cost, "감전 구출")
		end
	end,
})

-- ─────────────────────────── 구출: 때려서 깬다(hitCount) ───────────────────────────
-- 잡힌 친구를 감싼 얼음 덩어리를 타격 대상으로 세운다(MonsterSpawner.spawnRescueTarget - 평타·스킬·투사체가 그대로
-- 맞는다, 근접·원거리 구분 없음). 유효 타격은 구출자 1인당 hitIntervalSeconds에 한 번, requiredHits번이면 풀린다 -
-- 구출자마다 따로 세므로 둘이 때리면 절반이다. 얼음은 풀리는 순간(구출·자동 해제·리셋) 치운다.
local iceBlocks = {} -- [잡힌 Player] = { model, lastHitAt = { [구출자] = os.clock } }

local ICE_BODY_ASPECT = Vector3.new(1.7, 1.8, 3.4) -- buildModel의 몸통(2.4 × 3 × 1.2)을 캐릭터를 감싸는 4.1 × 5.4 × 4.1 덩어리로

BossTrap.onTrapped(function(player, record)
	if record.rescueType ~= "hitCount" or typeof(player) ~= "Instance" then -- 얼음 덩어리는 실제 플레이어에게만(진행 Attribute를 읽는다)
		return
	end
	local root = rootOf(player)
	if not root then
		return
	end
	local config = BossData.mechanics.rescue.hitCount
	local entry = { lastHitAt = {} }
	iceBlocks[player] = entry
	local foot = root.Position - Vector3.new(0, 3, 0) -- 루트 중심은 발에서 3stud 위(HipHeight 2 + 루트 반높이 1)
	entry.model = MonsterSpawner.spawnRescueTarget({
		displayName = "얼음",
		color = config.blockColor,
		bodyAspect = ICE_BODY_ASPECT,
		footPosition = foot,
		onHit = function(rescuer)
			local now = os.clock()
			local last = entry.lastHitAt[rescuer]
			if rescuer == player or (last and now - last < config.hitIntervalSeconds) then
				return
			end
			entry.lastHitAt[rescuer] = now
			BossTrap.addRescueProgress(player, rescuer, 1 / config.requiredHits)
		end,
		remaining = function()
			return 1 - (player:GetAttribute("BossTrapRescue") or 0)
		end,
	}, record.context and record.context.zoneKey)
end)

BossTrap.onReleased(function(player)
	local entry = iceBlocks[player]
	if entry then
		iceBlocks[player] = nil
		if entry.model then
			MonsterSpawner.removeRescueTarget(entry.model)
		end
	end
end)

-- ─────────────────────────── 구출: 끌어낸다(push) ───────────────────────────
-- 잡힌 사람의 루트는 서버가 고정(Anchored)해 둔다 - 물리로 움직이지 않는다. 그래서 "끌려 나온다"는 논리다: 홀드의 진행이
-- 차는 만큼 서버가 친구를 **처음 당긴 구출자 쪽으로** 옮긴다(진행 1 = 무덤 반경, 단 구출자 앞 standoffStuds까지만).
-- 구출자마다 더해진다 - 둘이 당기면 두 배로 빠르다. 29-3은 "붙어서 친구 쪽으로 걷는다"였다 - 입력만 F 홀드로 바뀌었고,
-- 흰 원(무덤)과 "원 밖으로 끌려 나온다"는 그림은 그대로다.
BossTrap.registerRescueHandler("push", {
	onProgress = function(trapped, record, rescuer, amount)
		local root, rescuerRoot = rootOf(trapped), rootOf(rescuer)
		if not (root and rescuerRoot) then
			return
		end
		-- 방향과 거리는 처음 당긴 순간에 정한다 - 끌려오는 동안 다시 재면 구출자를 지나치는 순간 방향이 뒤집힌다.
		local config = BossData.mechanics.rescue.push
		local pull = record.pull
		if not pull then
			local toward = Vector3.new(rescuerRoot.Position.X - root.Position.X, 0, rescuerRoot.Position.Z - root.Position.Z)
			pull = {
				direction = toward.Magnitude > 1e-3 and toward.Unit or Vector3.new(1, 0, 0),
				distance = math.clamp(toward.Magnitude - config.standoffStuds, 0, config.graveRadiusStuds),
			}
			record.pull = pull
		end
		local target = root.Position + pull.direction * pull.distance * amount
		local zone = record.context and WorldConfig.zones[record.context.zoneKey or ""]
		if zone then
			target = Vector3.new(
				math.clamp(target.X, zone.center.X - zone.halfSize + 2, zone.center.X + zone.halfSize - 2),
				target.Y,
				math.clamp(target.Z, zone.center.Z - zone.halfSize + 2, zone.center.Z + zone.halfSize - 2))
		end
		root.CFrame = root.CFrame.Rotation + target
	end,
})

return BossGimmicks
