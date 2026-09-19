-- 보스별 파훼 판정과 구출 동작(29-3, PRD 20.76) - 29-1 뼈대가 남긴 두 훅에 꽂는다.
--   · BossMechanics.registerJudge(kind, fn)            "이 사람은 이번 기믹을 풀었는가"
--   · BossTrap.registerRescueHandler(rescueType, ...)  "구출 진행은 언제 얼마나 차는가"
-- 키는 보스 이름이 아니라 종류다(behindProp·noHit / hitCount·push) - 같은 종류를 쓰는 보스가 늘어도 이 파일은 그대로다.
-- 수치는 전부 BossData.mechanics.rescue·dodge에 있다. BossPatterns가 require해서 서버가 뜰 때 한 번 등록된다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
local BossMechanics = require(script.Parent.BossMechanics)
local BossTrap = require(script.Parent.BossTrap)
local BossArenaProps = require(script.Parent.BossArenaProps)
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

-- ─────────────────────────── 구출: 밀어서 꺼낸다(push) ───────────────────────────
-- 이 게임의 이동은 서버 PivotTo 기반이고 잡힌 사람의 루트는 서버가 고정(Anchored)해 둔다 - 물리로 밀리지 않는다.
-- 그래서 "밀기"는 논리다: 구출자가 reachStuds 안에서 묻힌 친구 쪽으로 걷고 있으면(Humanoid.MoveDirection - 입력
-- 방향이라 몸이 막혀 속도가 0이어도 읽힌다) 서버가 친구를 그 방향으로 옮기고 진행을 채운다. 속도 = 무덤 반경 ÷
-- trap.rescueSeconds, 구출자마다 더해진다. 진행은 밀기를 멈춰도 줄지 않는다. 다 차면(= 무덤 반경만큼 밀렸으면) 풀린다.
BossTrap.registerRescueHandler("push", {
	tick = function(trapped, record, members, dt)
		local root = rootOf(trapped)
		if not root then
			return
		end
		local config = BossData.mechanics.rescue.push
		local speed = config.graveRadiusStuds / BossData.mechanics.trap.rescueSeconds
		local zone = record.context and WorldConfig.zones[record.context.zoneKey or ""]
		for _, rescuer in ipairs(members) do
			local rescuerRoot = rescuer ~= trapped and rootOf(rescuer)
			local humanoid = rescuerRoot and rescuer.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and (PlayerState.getHp(rescuer) or 0) > 0 and not BossTrap.isTrapped(rescuer)
				and Reach.horizontalDistance(rescuerRoot.Position, root.Position) <= config.reachStuds then
				local move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
				local toward = Vector3.new(root.Position.X - rescuerRoot.Position.X, 0, root.Position.Z - rescuerRoot.Position.Z)
				if move.Magnitude > 0.1 and toward.Magnitude > 1e-3 and move.Unit:Dot(toward.Unit) >= config.towardDot then
					local target = root.Position + move.Unit * speed * dt
					if zone then
						target = Vector3.new(
							math.clamp(target.X, zone.center.X - zone.halfSize + 2, zone.center.X + zone.halfSize - 2),
							target.Y,
							math.clamp(target.Z, zone.center.Z - zone.halfSize + 2, zone.center.Z + zone.halfSize - 2))
					end
					root.CFrame = root.CFrame.Rotation + target
					if BossTrap.addRescueProgress(trapped, rescuer, speed * dt / config.graveRadiusStuds) then
						return
					end
				end
			end
		end
	end,
})

return BossGimmicks
