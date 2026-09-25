-- BR1-3 수정 여왕 전멸기 "수정 오르골"(사용자 - 프리즘 분열 대체). primitive = "orgel"(수치 = 스킬 데이터 · BossData 주석).
-- 흐름: 왕관을 든다(telegraphSeconds) → 종 bells개가 여왕 둘레에 선다(구출 대상 엔티티 - 때릴 수 있다) → 순서(sequenceLength · 무작위 · 중복 허용)를 한 번 보여 준다
--   (간격 = BossSkillMath.orgelShowInterval - 스테이지 곡선) → 입력 limitSeconds: 같은 순서로 친다(누가 쳐도 인정 · 틀리면 처음부터 + 때린 사람 전기 충격).
--   성공 = 왕관이 깨지고 기절 + 게이트 열림 · 실패 = 수정 조각상 연출(전원 잡힘 "statue" - 무적 · 고정) → 여왕이 거닐며 감상 → 찰칵 → 톡 → 와장창 + 90%(보호막 무시).
-- 판정 · 시계는 서버, 종 흔들림 · 반짝 · 음 · 진행 "2/5" · 조각상 포즈 · 화면 번쩍은 클라(BossOrgelView).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local BossTrap = require(script.Parent.BossTrap)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local BossMechanics = require(script.Parent.BossMechanics)
local HeightGuard = require(script.Parent.HeightGuard)

local BossOrgel = {}

local kit
local rng = Random.new()
local bellsOf = {} -- [보스 Model] = { [번호] = 종 Model }
local POSES = 4 -- 조각상 포즈 종류(클라 BossOrgelView: 만세 · 엉덩방아 · 놀람 · 발끝) - 사람마다 다르게 돌린다

local function userIdOf(player)
	return typeof(player) == "Instance" and player.UserId or 0
end

local function removeBells(model)
	local bells = bellsOf[model]
	bellsOf[model] = nil
	for _, bell in pairs(bells or {}) do
		MonsterSpawner.removeRescueTarget(bell)
	end
end

local function spawnBells(c)
	local st, skill, o = c.st, c.skill, c.st.orgel
	local bells = {}
	bellsOf[c.model] = bells
	o.bellPositions = {}
	local offset = rng:NextNumber(0, 2 * math.pi)
	for i = 1, skill.bells do
		local a = offset + (i - 1) / skill.bells * 2 * math.pi
		local at = o.center + Vector3.new(math.cos(a), 0, math.sin(a)) * skill.bellRingStuds
		local spec = skill.palette[i]
		local model, data = c.model, c.data
		local bell = MonsterSpawner.spawnRescueTarget({
			lookLike = { displayName = "수정 종 " .. spec.symbol, bodyColor = spec.color, headColor = spec.color, sizeScale = skill.bellLook.sizeScale, bodyAspect = skill.bellLook.bodyAspect },
			position = Vector3.new(at.X, c.position.Y, at.Z),
			remaining = function()
				return MonsterState.getHpRatio(model)
			end,
			onHit = function(player, hitInfo)
				BossOrgel.onBellHit(model, st, data, skill, i, player, hitInfo)
			end,
		}, MonsterState.getZoneKey(c.model))
		bell:SetAttribute("OrgelBell", i)
		local body = bell:FindFirstChild("Body")
		if body then
			body.Material = Enum.Material.Glass
			body.Transparency = 0.15
			-- 몸통 모양 표시(● ▲ ■ ◆ ★ - 색 · 모양 이중 구분). AlwaysOnTop이 아니다(캡처 · 가림이 자연스럽게)
			local gui = Instance.new("BillboardGui")
			gui.Name = "BellSymbol"
			gui.Size = UDim2.new(0, 64, 0, 64)
			gui.StudsOffset = Vector3.new(0, 0, 0)
			gui.LightInfluence = 0
			gui.Adornee = body
			gui.Parent = body
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = spec.symbol
			label.TextScaled = true
			label.Font = Enum.Font.GothamBlack
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0.2
			label.Parent = gui
		end
		bells[i] = bell
		o.bellPositions[i] = Vector3.new(at.X, st.floorY, at.Z)
	end
end

-- 종이 맞았다. 입력 창에서만 · 설치형 규칙(입력이 열리기 전에 시작한 공격 · 지연 폭발은 안 센다) · 한 사람 hitDebounceSeconds에 한 번.
function BossOrgel.onBellHit(model, st, data, skill, bell, player, hitInfo)
	local o = st.orgel
	if not o or o.phase ~= "input" or o.done then
		return
	end
	if (hitInfo and hitInfo.indirect) or ((hitInfo and hitInfo.committedAt) or os.clock()) < o.openedAt then
		return
	end
	local now = os.clock()
	if o.lastHitAt[player] and now - o.lastHitAt[player] < skill.hitDebounceSeconds then
		return
	end
	o.lastHitAt[player] = now
	local progress, ok = BossSkillMath.orgelAdvance(o.progress, o.sequence, bell)
	o.progress = progress
	kit.send(st, "orgelHit", { bell = bell, ok = ok, progress = progress, length = #o.sequence })
	kit.debugEvent("orgelHit", { player = player, bell = bell, ok = ok, progress = progress, at = now })
	if not ok then
		local shock = skill.wrongShock
		kit.applySkillDamage(model, data, { damage = { kind = "attack", multiplier = shock.multiplier }, damageLabel = shock.damageLabel }, player)
	elseif progress >= #o.sequence then
		o.done = true
		o.success = true
	end
end

local function succeed(c)
	local st, skill = c.st, c.skill
	removeBells(c.model)
	st.orgel = nil
	kit.send(st, "orgelEnd", { success = true })
	BossMechanics.judgeGate(c.model, true, skill.breakWindow, "orgel")
	kit.send(st, "gimmickResolve", { broken = true, windowSeconds = skill.stunSeconds })
	print(("[forge-game] 수정 오르골 성공 → 왕관 깨짐 · 기절 %.1f초"):format(skill.stunSeconds))
	kit.endSkill(c.model, st, c.data, c.now)
	kit.stun(c.model, st, c.data, skill.stunSeconds)
end

-- 실패: 전원 조각상(잡힘 "statue" - 무적 · 고정 · 높이 검증 예외) → 여왕이 거닐고 → 찰칵 → 톡 → 와장창(shatterAt) + 피해.
local function beginStatues(c)
	local st, skill, o = c.st, c.skill, c.st.orgel
	removeBells(c.model)
	o.phase = "statue"
	o.statueAt = c.now
	o.statues = {}
	local userIds, poses, positions = {}, {}, {}
	local poseOffset = rng:NextInteger(0, POSES - 1)
	for i, v in ipairs(kit.victims(st)) do
		if not BossTrap.isTrapped(v.player) and (PlayerState.getHp(v.player) or 0) > 0 then
			if BossTrap.trap(v.player, {
				kind = "statue", rescueType = "none", autoReleaseSeconds = skill.statue.seconds + 1, -- 안전장치(와장창이 먼저 푼다)
				context = { origin = v.root.Position, zoneKey = MonsterState.getZoneKey(c.model), bossModel = c.model },
			}) then
				HeightGuard.exempt(v.player, skill.statue.seconds + 2)
				table.insert(o.statues, { player = v.player, position = v.root.Position })
				table.insert(userIds, userIdOf(v.player))
				table.insert(poses, (poseOffset + i - 1) % POSES + 1)
				table.insert(positions, v.root.Position)
			end
		end
	end
	o.strollIndex = 1
	kit.send(st, "orgelStatue", {
		userIds = userIds, poses = poses, positions = positions, seconds = skill.statue.seconds,
		flashAt = skill.statue.flashAt, tapAt = skill.statue.tapAt, shatterAt = skill.statue.shatterAt,
	})
	print(("[forge-game] 수정 오르골 실패 → 조각상 %d명"):format(#o.statues))
end

local function shatter(c)
	local st, skill, o = c.st, c.skill, c.st.orgel
	for _, s in ipairs(o.statues) do
		if BossTrap.getRecord(s.player) and BossTrap.getRecord(s.player).kind == "statue" then
			BossTrap.release(s.player, "shatter") -- 해제 유예 없이(피해가 바로 뒤에 들어간다)
		end
		PlayerDamage.applyMaxHpFraction(s.player, skill.failMaxHpFraction, skill.damageLabel, { ignoresShield = true })
		BossTrap.noteSkillHit(s.player)
	end
	st.orgel = nil
	kit.send(st, "orgelEnd", { success = false })
	BossMechanics.judgeGate(c.model, false, nil, "orgel")
	kit.send(st, "gimmickResolve", { broken = false })
	print(("[forge-game] 수정 오르골: 와장창 → %.0f%%"):format(skill.failMaxHpFraction * 100))
	kit.endSkill(c.model, st, c.data, c.now)
end

BossOrgel.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		BossMechanics.onGimmickStart(c.model)
		local zone = kit.zoneOf(c.model)
		local interval = BossSkillMath.orgelShowInterval(skill, c.data.stageNumber)
		st.phase = "orgel"
		st.orgel = {
			phase = "crown", endsAt = c.now + skill.telegraphSeconds, center = kit.clampToZone(kit.xz(c.position), zone, skill.bellRingStuds + 6),
			sequence = BossSkillMath.orgelSequence(skill, function() return rng:NextNumber() end, #st.members), interval = interval,
			progress = 0, lastHitAt = {}, shown = 0,
		}
		spawnBells(c)
		local o = st.orgel
		local palette = {}
		for i, spec in ipairs(skill.palette) do
			palette[i] = { color = spec.color, symbol = spec.symbol, note = spec.note }
		end
		kit.send(st, "orgelStart", { center = Vector3.new(o.center.X, st.floorY, o.center.Z), bells = o.bellPositions, palette = palette, seconds = skill.telegraphSeconds, interval = interval, length = #o.sequence, bossId = c.data.id })
		print(("[forge-game] 수정 오르골: 순서 %s · 간격 %.2f초(스테이지 %s)"):format(table.concat(o.sequence, "-"), interval, tostring(c.data.stageNumber)))
	end,
	step = function(c)
		local st, skill, o = c.st, c.skill, c.st.orgel
		if not o then
			return
		end
		if o.phase == "crown" then
			if c.now >= o.endsAt then
				o.phase = "show"
				o.endsAt = c.now
			end
			return
		end
		if o.phase == "show" then
			if c.now >= o.endsAt then
				if o.shown >= #o.sequence then
					o.phase = "input"
					o.openedAt = os.clock()
					o.endsAt = c.now + skill.limitSeconds
					kit.send(st, "orgelInput", { length = #o.sequence, seconds = skill.limitSeconds })
					return
				end
				o.shown += 1
				o.endsAt = c.now + o.interval
				local bell = o.sequence[o.shown]
				kit.send(st, "orgelRing", { bell = bell, step = o.shown, seconds = o.interval * 0.8 })
				kit.debugEvent("orgelRing", { bell = bell, step = o.shown, at = c.now })
			end
			return
		end
		if o.phase == "input" then
			if o.success then
				succeed(c)
			elseif c.now >= o.endsAt then
				beginStatues(c)
			end
			return
		end
		-- statue: 여왕이 조각상 사이를 거닌다(strollSeconds 동안 차례로) → 찰칵 · 톡(클라 시계) → 와장창
		local t = c.now - o.statueAt
		local target = o.statues[o.strollIndex]
		if t < skill.statue.strollSeconds and target then
			local from = kit.xz(c.model:GetPivot().Position)
			local to = kit.xz(target.position) + Vector3.new(4, 0, 0)
			local step = (c.data.moveSpeedStuds or 7) * 3 * (st.dt or 1 / 60)
			local d = to - from
			if d.Magnitude <= step then
				o.strollIndex = o.strollIndex % #o.statues + 1
			else
				local at = from + d.Unit * step
				c.model:PivotTo(CFrame.lookAt(Vector3.new(at.X, c.position.Y, at.Z), Vector3.new(to.X, c.position.Y, to.Z)))
			end
		end
		if t >= skill.statue.shatterAt then
			shatter(c)
		end
	end,
	interrupt = function(c)
		local o = c.st.orgel
		if o then
			removeBells(c.model)
			for _, s in ipairs(o.statues or {}) do
				if BossTrap.getRecord(s.player) and BossTrap.getRecord(s.player).kind == "statue" then
					BossTrap.release(s.player, "reset")
				end
			end
			c.st.orgel = nil
			kit.send(c.st, "orgelEnd", { success = false, interrupted = true })
		end
	end,
}

function BossOrgel.clear(model)
	removeBells(model)
end

function BossOrgel.register(handlers, patternKit)
	kit = patternKit
	handlers.orgel = BossOrgel.handler
end

return BossOrgel
