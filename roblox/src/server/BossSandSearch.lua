-- BR1-3 전갈 여왕 전멸기 "진짜 전갈 찾기"(사용자 - 갑각 태세 대체). primitive = "sandSearch"(보스 이름이 들어간 분기 없음 - 수치 = 스킬 데이터 · BossData 주석).
-- 흐름: 파고들기(telegraphSeconds - 보스 모델을 depthStuds 아래로 · 논리 위치는 지표) → 둔덕 N개(구출 대상 엔티티 - 때릴 수 있다)가 wanderRadiusStuds 안을 돌아다닌다 →
--   진짜를 때리면 성공(여왕이 그 자리로 튀어나와 기절 + 게이트 열림) · 가짜를 때리면 작은 모래 폭발(때린 사람) · 제한 시간이 지나면 전원 90%(보호막 무시).
-- 진짜 둔덕만 꼬리 끝(서버 파트 "TailTip" - 모두에게 보인다)이 빛난다 · 발자국은 클라(BossSandView)가 진짜 둔덕 뒤에 찍는다. 판정은 서버.
local BossTrap = require(script.Parent.BossTrap)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossMechanics = require(script.Parent.BossMechanics)
local BossSkillMath = require(game:GetService("ReplicatedStorage").Shared.BossSkillMath)

local BossSandSearch = {}

local kit
local rng = Random.new()
local moundsOf = {} -- [보스 Model] = { { model, position, waypoint } } - 끝나는 모든 길(판정 · 중단 · 처치)에서 치운다
local WINDOW = 0.75 -- 가짜 폭발은 한 사람 0.75초에 한 번(BossData.mechanics.reflect.windowSeconds와 같은 값)

local function aliveVictims(st)
	local list = {}
	for _, v in ipairs(kit.victims(st)) do
		if not BossTrap.isTrapped(v.player) and (PlayerState.getHp(v.player) or 0) > 0 then
			table.insert(list, v)
		end
	end
	return list
end

-- 순수: 인원 n의 둔덕 수.
function BossSandSearch.moundCount(skill, memberCount)
	local list = skill.mound.countByParty
	return list[math.clamp(memberCount or 1, 1, #list)]
end

local function removeMounds(model)
	local list = moundsOf[model]
	moundsOf[model] = nil
	for _, m in ipairs(list or {}) do
		MonsterSpawner.removeRescueTarget(m.model)
	end
end

local function surface(c, at)
	local st = c.st
	local base = st.burrowLogical or c.position
	st.burrowLogical = nil
	local to = at and Vector3.new(at.X, base.Y, at.Z) or base
	c.model:PivotTo(CFrame.new(to))
	st.position = to
end

local function randomSpot(center, radius)
	local a = rng:NextNumber(0, 2 * math.pi)
	local d = math.sqrt(rng:NextNumber()) * radius
	return center + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

local function spawnMounds(c)
	local st, skill, sand = c.st, c.skill, c.st.sand
	local spec = skill.mound
	local count = BossSandSearch.moundCount(skill, #st.members)
	sand.realIndex = rng:NextInteger(1, count)
	local look = { displayName = "모래 둔덕", bodyColor = spec.color, headColor = spec.color, sizeScale = spec.sizeScale, bodyAspect = spec.bodyAspect }
	local list = {}
	moundsOf[c.model] = list
	for i = 1, count do
		local a = (i - 1) / count * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
		local at = sand.center + Vector3.new(math.cos(a), 0, math.sin(a)) * spec.wanderRadiusStuds * 0.55
		local entry = { position = at, waypoint = randomSpot(sand.center, spec.wanderRadiusStuds) }
		local model, data = c.model, c.data
		entry.model = MonsterSpawner.spawnRescueTarget({
			lookLike = look,
			position = Vector3.new(at.X, c.position.Y, at.Z),
			remaining = function()
				return MonsterState.getHpRatio(model)
			end,
			onHit = function(player, hitInfo)
				BossSandSearch.onMoundHit(model, st, data, skill, i, player, hitInfo)
			end,
		}, MonsterState.getZoneKey(c.model))
		entry.model:SetAttribute("SandMound", i)
		local body, head = entry.model:FindFirstChild("Body"), entry.model:FindFirstChild("Head")
		if body then
			body.Material = Enum.Material.Sand
		end
		if head then
			head.Transparency = 1
		end
		if i == sand.realIndex and body then
			-- 빛나는 꼬리 끝(작지만 알면 보인다 - 폰에서도 보이게 몸 위로 솟은 네온 쐐기)
			local tip = Instance.new("WedgePart")
			tip.Name = "TailTip"
			tip.Anchored = true
			tip.CanCollide = false
			tip.CanQuery = false
			tip.Material = Enum.Material.Neon
			tip.Color = Color3.fromRGB(255, 214, 90)
			tip.Size = Vector3.new(1.2, 3.4, 2.2)
			tip.CFrame = body.CFrame * CFrame.new(0, body.Size.Y / 2 + 0.8, body.Size.Z * 0.3) * CFrame.Angles(math.rad(-20), 0, 0)
			tip.Parent = entry.model
		end
		list[i] = entry
	end
	sand.phase = "search"
	sand.openedAt = os.clock()
	local limit = BossSkillMath.gimmickLimitSeconds(skill, #st.members)
	sand.endsAt = c.now + limit
	sand.blastAt = {}
	kit.send(st, "sandStart", { realIndex = sand.realIndex, count = count, seconds = limit, footprintEvery = skill.clue.footprintEverySeconds, footprintSeconds = skill.clue.footprintSeconds, floorY = st.floorY })
	print(("[forge-game] 진짜 전갈 찾기: 둔덕 %d개(진짜 %d번) · 제한 %.1f초"):format(count, sand.realIndex, limit))
end

-- 둔덕이 맞았다(구출 대상의 onHit). 설치형 규칙: 둔덕이 나오기 전에 시작한 공격 · 지연 폭발은 판정하지 않는다.
function BossSandSearch.onMoundHit(model, st, data, skill, index, player, hitInfo)
	local sand = st.sand
	if not sand or sand.phase ~= "search" or sand.solvedBy then
		return
	end
	if (hitInfo and hitInfo.indirect) or ((hitInfo and hitInfo.committedAt) or os.clock()) < sand.openedAt then
		return
	end
	if index == sand.realIndex then
		sand.solvedBy = player -- 다음 틱에 성공으로 넘어간다
		return
	end
	local now = os.clock()
	if sand.blastAt[player] and now - sand.blastAt[player] < WINDOW then
		return
	end
	sand.blastAt[player] = now
	local entry = moundsOf[model] and moundsOf[model][index]
	local blast = skill.decoyBlast
	kit.applySkillDamage(model, data, { damage = { kind = "attack", multiplier = blast.multiplier }, damageLabel = blast.damageLabel }, player)
	-- M1-2 C안: 파티면 오답 공동 책임(전원 최대 체력 비율 - 인원별 표)
	local share = blast.partyShareMaxHpByParty and blast.partyShareMaxHpByParty[math.min(#st.members, #blast.partyShareMaxHpByParty)] or 0
	if share > 0 then
		for _, v in ipairs(aliveVictims(st)) do
			PlayerDamage.applyMaxHpFraction(v.player, share, blast.partyShareLabel)
		end
	end
	kit.send(st, "sandBlast", { position = entry and Vector3.new(entry.position.X, st.floorY, entry.position.Z) or nil, radius = blast.radiusStuds })
	kit.debugEvent("sandBlast", { player = player, index = index, at = now })
end

local function finish(c, success)
	local st, skill, sand = c.st, c.skill, c.st.sand
	local list = moundsOf[c.model] or {}
	local realAt = list[sand.realIndex] and list[sand.realIndex].position or nil
	local positions = {}
	for _, m in ipairs(list) do
		table.insert(positions, Vector3.new(m.position.X, st.floorY, m.position.Z))
	end
	removeMounds(c.model)
	st.sand = nil
	surface(c, success and realAt or nil)
	kit.send(st, "sandEnd", { success = success, position = realAt and Vector3.new(realAt.X, st.floorY, realAt.Z) or nil, positions = positions })
	if success then
		BossMechanics.judgeGate(c.model, true, skill.breakWindow, "sandSearch")
		kit.send(st, "gimmickResolve", { broken = true, windowSeconds = skill.stunSeconds })
		print(("[forge-game] 진짜 전갈 찾기 성공(%s) → 기절 %.1f초"):format(tostring(sand.solvedBy and sand.solvedBy.Name), skill.stunSeconds))
		kit.endSkill(c.model, st, c.data, c.now)
		kit.stun(c.model, st, c.data, skill.stunSeconds)
		return
	end
	for _, v in ipairs(aliveVictims(st)) do
		PlayerDamage.applyMaxHpFraction(v.player, skill.failMaxHpFraction, skill.damageLabel, { ignoresShield = true })
		BossTrap.noteSkillHit(v.player)
	end
	BossMechanics.judgeGate(c.model, false, nil, "sandSearch")
	kit.send(st, "gimmickResolve", { broken = false })
	print(("[forge-game] 진짜 전갈 찾기 실패 → 둔덕 폭발 %.0f%%"):format(skill.failMaxHpFraction * 100))
	kit.endSkill(c.model, st, c.data, c.now)
end

BossSandSearch.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		BossMechanics.onGimmickStart(c.model)
		local zone = kit.zoneOf(c.model)
		local center = kit.clampToZone(kit.xz(c.position), zone, skill.mound.wanderRadiusStuds + 6)
		st.sand = { phase = "dig", endsAt = c.now + skill.telegraphSeconds, center = center }
		st.phase = "sandSearch"
		st.burrowLogical = c.position
		c.model:PivotTo(CFrame.new(c.position - Vector3.new(0, skill.depthStuds, 0)))
		MonsterState.setDamageTakenMultiplier(c.model, 0) -- 모래 속 - 맞지 않는다(판정 · 결과가 게이트로 되돌린다)
		kit.send(st, "sandDig", { center = Vector3.new(c.position.X, st.floorY, c.position.Z), seconds = skill.telegraphSeconds, bossId = c.data.id })
	end,
	step = function(c)
		local st, skill, sand = c.st, c.skill, c.st.sand
		if not sand then
			return
		end
		if sand.phase == "dig" then
			if c.now >= sand.endsAt then
				spawnMounds(c)
			end
			return
		end
		-- 둔덕이 돌아다닌다(걷기보다 느리게 - 웨이포인트를 차례로)
		local spec = skill.mound
		local step = spec.speedStuds * (st.dt or 1 / 60)
		for _, m in ipairs(moundsOf[c.model] or {}) do
			local to = m.waypoint - m.position
			if to.Magnitude <= step then
				m.position = m.waypoint
				m.waypoint = randomSpot(sand.center, spec.wanderRadiusStuds)
			else
				m.position += to.Unit * step
			end
			if m.model.Parent then
				local look = to.Magnitude > 1e-3 and to.Unit or Vector3.new(0, 0, -1)
				m.model:PivotTo(CFrame.lookAt(Vector3.new(m.position.X, c.position.Y, m.position.Z), Vector3.new(m.position.X + look.X, c.position.Y, m.position.Z + look.Z)))
			end
		end
		if sand.solvedBy then
			finish(c, true)
		elseif c.now >= sand.endsAt then
			finish(c, false)
		end
	end,
	interrupt = function(c)
		if c.st.sand then
			removeMounds(c.model)
			c.st.sand = nil
			surface(c, nil)
			BossMechanics.endReflect(c.model) -- 받는 피해 배율을 게이트 상태로(0에서)
			kit.send(c.st, "sandEnd", { success = false, interrupted = true })
		end
	end,
}

-- 보스전이 끝나면(처치 · 이탈) 둔덕을 남기지 않는다(BossPatterns.clearProps).
function BossSandSearch.clear(model)
	removeMounds(model)
end

-- 자동 검증 · 하네스 전용
function BossSandSearch.debugMounds(model)
	return moundsOf[model]
end

function BossSandSearch.register(handlers, patternKit)
	kit = patternKit
	handlers.sandSearch = BossSandSearch.handler
end

return BossSandSearch
