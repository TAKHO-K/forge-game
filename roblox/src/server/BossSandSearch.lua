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
local SandShell = require(game:GetService("ReplicatedStorage").Shared.SandShell)
local BossData = require(game:GetService("ReplicatedStorage").Shared.data.BossData)
local WorldConfig = require(game:GetService("ReplicatedStorage").Shared.data.WorldConfig)

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
			-- QUEUE-ALL1 01 D-1: 네모 판 → 둥근 모래 언덕(판정 몸은 그대로 - 겉 메시만 · 아래쪽은 바닥에 묻힌다)
			local dome = Instance.new("SpecialMesh")
			dome.MeshType = Enum.MeshType.Sphere
			dome.Scale = Vector3.new(1.15, 2.6, 1.15) -- 꼭대기 = 몸 가운데 + 몸 높이(Play 캡처: 1.5는 납작한 원판)
			dome.Offset = Vector3.new(0, -body.Size.Y * 0.3, 0)
			dome.Parent = body
		end
		if head then
			head.Transparency = 1
		end
		if (i == sand.realIndex or (spec.shell and spec.shell.enabled)) and body then
			-- 빛나는 꼬리 끝(작지만 알면 보인다 - 폰에서도 보이게 몸 위로 솟은 침) · A2-N4: 가짜에도 같은 꼬리(모래색 · 안 빛남) - 진짜만 클라가 켰다 껐다(BossGimmick13View)
			-- QUEUE-ALL1 01 D-1: 쐐기 하나 → 모래에서 튀어나와 앞으로 휘는 꼬리(마디 TailSeg 4 + 침 TailTip - 빛나는 건 침만)
			local shellOn = spec.shell and spec.shell.enabled
			local function piece(className, name, size, cf)
				local part = Instance.new(className)
				part.Name = name
				part.Anchored = true
				part.CanCollide = false
				part.CanQuery = false
				part.Material = Enum.Material.Sand
				part.Color = spec.color
				part.Size = size
				part.CFrame = cf
				part.Parent = entry.model
				return part
			end
			local root = body.CFrame * CFrame.new(0, body.Size.Y * 0.72, body.Size.Z * 0.3) -- 언덕 뒤쪽 비탈에서 솟는다
			local cf = root
			local segColor = spec.color:Lerp(Color3.new(0, 0, 0), 0.25) -- 언덕보다 조금 어둡게(꼬리 윤곽)
			for k = 1, 5 do -- 뒤에서 솟아 위로 · 앞으로 말린다(마디마다 30°씩 앞으로)
				cf = cf * CFrame.Angles(math.rad(k == 1 and 10 or -30), 0, 0) * CFrame.new(0, 0.9, 0)
				piece("Part", "TailSeg", Vector3.new(2.0 - k * 0.2, 1.9, 2.0 - k * 0.2), cf).Color = segColor
				cf = cf * CFrame.new(0, 0.9, 0)
			end
			local tip = piece("WedgePart", "TailTip", Vector3.new(1.0, 2.4, 1.4), cf * CFrame.Angles(math.rad(-45), 0, 0) * CFrame.new(0, 0.9, 0))
			tip.Material = shellOn and Enum.Material.Sand or Enum.Material.Neon
			tip.Color = shellOn and spec.color or Color3.fromRGB(255, 214, 90)
		end
		list[i] = entry
	end
	sand.phase = "search"
	sand.openedAt = os.clock()
	local limit = BossSkillMath.gimmickLimitSeconds(skill, #st.members)
	sand.endsAt = c.now + limit
	sand.blastAt = {}
	local S = spec.shell
	if S and S.enabled and S.dark then -- QUEUE-ALL1 01 D-1: 공개 → 불 꺼짐 → 멈춤
		local darkSeconds = (st.hintLevel or 0) >= 1 and S.dark.hintSeconds or S.dark.seconds
		sand.mode = "reveal"
		sand.stopAt = sand.endsAt - S.stopSeconds
		sand.darkAt = sand.stopAt - darkSeconds
	end
	local tail = (spec.shell and spec.shell.enabled and spec.tail) and { onSeconds = spec.tail.onSeconds, offSeconds = spec.tail.offSeconds, glowColor = spec.tail.glowColor, sandColor = spec.color } or nil
	kit.send(st, "sandStart", { realIndex = sand.realIndex, count = count, seconds = limit, footprintEvery = skill.clue.footprintEverySeconds, footprintSeconds = skill.clue.footprintSeconds, floorY = st.floorY, tail = tail })
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
		-- 둔덕이 돌아다닌다(걷기보다 느리게 - 웨이포인트를 차례로) · A2-N4: 야바위(자리 바꾸기 → 멈춤)
		local spec = skill.mound
		if sand.mode == "reveal" and c.now >= sand.darkAt then
			sand.mode = "dark"
			kit.send(st, "sandDark", { seconds = sand.stopAt - c.now })
		elseif sand.mode == "dark" and c.now >= sand.stopAt then
			sand.mode = "stopped"
			BossSandSearch.stepShell(c, sand, spec, moundsOf[c.model] or {}, 0) -- 멈추는 순간의 겹침 풀기(SandShell settle)를 먼저 - 도달 시간은 그 자리로 잰다(리뷰 3)
			-- 도달 시간 보장: 산 멤버 각자에서 가장 먼 둔덕까지(회피 부등식과 같은 식)
			local D = BossData.mechanics.dodge
			local far = 0
			for _, v in ipairs(aliveVictims(st)) do
				for _, m in ipairs(moundsOf[c.model] or {}) do
					far = math.max(far, (kit.xz(v.root.Position) - kit.xz(m.position)).Magnitude)
				end
			end
			local reach = D.perceptionSeconds + far / WorldConfig.playerWalkSpeedStuds * D.marginFactor
			if c.now + reach > sand.endsAt then
				print(("[forge-game] 진짜 전갈 찾기: 멈춤 - 가장 먼 둔덕 %.0f · 도달 %.1f초 > 남은 %.1f초 → 제한 연장"):format(far, reach, sand.endsAt - c.now))
				sand.endsAt = c.now + reach
			end
			kit.send(st, "sandStop", { seconds = sand.endsAt - c.now })
		end
		if spec.shell and spec.shell.enabled then
			BossSandSearch.stepShell(c, sand, spec, moundsOf[c.model] or {})
		end
		local step = spec.speedStuds * (st.dt or 1 / 60)
		for _, m in ipairs((spec.shell and spec.shell.enabled) and {} or (moundsOf[c.model] or {})) do
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

-- A2-N4 §2-7 야바위 이동 = shared/SandShell(순수 - 검증이 같은 함수를 부른다) + 모델 자리 맞춤
function BossSandSearch.stepShell(c, sand, spec, mounds, dt)
	SandShell.step(sand, spec, mounds, c.now, dt or c.st.dt or 1 / 60, rng)
	for _, m in ipairs(mounds) do
		if m.model and m.model.Parent then
			m.model:PivotTo(CFrame.new(Vector3.new(m.position.X, c.position.Y, m.position.Z)) * m.model:GetPivot().Rotation)
		end
	end
end

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
