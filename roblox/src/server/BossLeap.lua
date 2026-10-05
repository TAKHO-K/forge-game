-- GUARDIAN-V3 도약(primitive = "leap" - 보스 이름이 들어간 분기 없음 · 수호자 새 몸의 반응 스킬이 쓴다 · 수치 = 스킬 데이터).
-- 흐름:
--   준비 telegraphSeconds: 착지 자리 = 대상 자리에서 landShortStuds(몸 가장자리 반폭)만큼 보스 쪽(몸 끝이 대상 자리에 닿는다) · 거리 상한 maxLeapStuds ·
--     아레나 안 · 무너진 바닥이면 보스 쪽으로 당긴다. 끝 lockSeconds 전까지 대상을 따라 갱신(leapAim 0.1초마다) → 고정.
--   비행 flightSeconds: 서버가 포물선(꼭대기 apexStuds)으로 몸을 옮긴다(PivotTo).
--   착지: 착지 자리에서 radiusStuds(몸 가장자리 + 12 - BossFramework.applyV3) 안 · 같은 층 전원에게 피해 + onHit(넉백 launch). 판정 = 클라의 균열 원과 같은 자리 · 반경.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Reach = require(ReplicatedStorage.Shared.Reach)
local BossEnvironment = require(script.Parent.BossEnvironment)

local BossLeap = {}

local kit
local AIM_SECONDS = 0.1

local function landingOf(c)
	local st, skill = c.st, c.skill
	local from = kit.xz(c.position)
	local target = c.targetRoot and kit.xz(c.targetRoot.Position) or from
	local delta = target - from
	local dist = delta.Magnitude
	local dir = dist > 1e-3 and delta.Unit or Vector3.new(0, 0, 1)
	local travel = math.clamp(dist - (skill.landShortStuds or 0), 0, skill.maxLeapStuds)
	local zone = kit.zoneOf(c.model)
	local spot = kit.clampToZone(from + dir * travel, zone, 4)
	-- 무너진 바닥(지반 붕괴)이면 보스 쪽으로 4 stud씩 당긴다(보스는 꺼진 조각에 서지 않는다 - MonsterAI와 같은 규칙)
	local pull = 0
	while pull < travel and BossEnvironment.blocksBoss(c.model, Vector3.new(spot.X, c.position.Y, spot.Z)) do
		pull += 4
		spot = kit.clampToZone(from + dir * math.max(travel - pull, 0), zone, 4)
	end
	return Vector3.new(spot.X, st.floorY, spot.Z)
end

local function sendAim(c, phase)
	local st, skill = c.st, c.skill
	kit.send(st, phase, {
		center = st.leapTo, radius = skill.radiusStuds, seconds = skill.telegraphSeconds, lockSeconds = skill.lockSeconds,
		bossId = c.data.id, markStyle = "crack",
	})
end

function BossLeap.register(handlers, k)
	kit = k
	handlers.leap = {
		bubbleSeconds = function(c)
			return c.skill.telegraphSeconds + c.skill.flightSeconds
		end,
		start = function(c)
			local st, skill = c.st, c.skill
			st.phase = "leapPrep"
			st.phaseEndsAt = c.now + skill.telegraphSeconds
			st.leapLockAt = st.phaseEndsAt - skill.lockSeconds
			st.leapFrom = c.position
			st.leapTo = landingOf(c)
			st.leapAimAt = c.now
			sendAim(c, "leapTelegraph")
		end,
		step = function(c)
			local st, skill = c.st, c.skill
			if st.phase == "leapPrep" then
				if c.now < st.leapLockAt and c.now - st.leapAimAt >= AIM_SECONDS then
					st.leapAimAt = c.now
					st.leapTo = landingOf(c)
					sendAim(c, "leapAim")
				end
				if c.now >= st.phaseEndsAt then
					st.phase = "leapFlight"
					st.leapFrom = c.model:GetPivot().Position
					st.leapStartedAt = c.now
					st.phaseEndsAt = c.now + skill.flightSeconds
					kit.send(st, "leapJump", { from = st.leapFrom, to = st.leapTo, seconds = skill.flightSeconds, apex = skill.apexStuds, serverStart = kit.serverNow(), bossId = c.data.id })
				end
				return
			end
			-- 비행: 수평 = 선형 · 높이 = 포물선(4h · u(1 − u)) · 착지 높이 = 이륙 높이(아레나 바닥 기준 같은 발 높이)
			local from, to = st.leapFrom, st.leapTo
			local u = math.clamp((c.now - st.leapStartedAt) / skill.flightSeconds, 0, 1)
			local lift = 4 * skill.apexStuds * u * (1 - u)
			local at = Vector3.new(from.X + (to.X - from.X) * u, from.Y + lift, from.Z + (to.Z - from.Z) * u)
			c.model:PivotTo(CFrame.new(at))
			if u < 1 then
				return
			end
			local landing = Vector3.new(to.X, from.Y, to.Z)
			c.model:PivotTo(CFrame.new(landing))
			kit.judgeBegin()
			for _, v in ipairs(kit.victims(st)) do
				if Reach.horizontalDistance(v.root.Position, landing) <= skill.radiusStuds and Reach.sameLayer(v.groundFeet, kit.footOf(landing)) then
					kit.applySkillDamage(c.model, c.data, skill, v.player)
					if skill.onHit then
						kit.runHitEffects(c, skill.onHit, v, landing, 1)
					end
				end
			end
			kit.judgeEnd(c, { kind = "circle", centers = { st.leapTo }, radius = skill.radiusStuds, inner = 0 })
			kit.send(st, "leapImpact", { center = st.leapTo, radius = skill.radiusStuds, bossId = c.data.id, markStyle = "crack" })
			kit.endSkill(c.model, st, c.data, c.now)
		end,
		interrupt = function(c)
			local st = c.st
			if st.phase == "leapFlight" and st.leapFrom and st.leapTo then
				c.model:PivotTo(CFrame.new(Vector3.new(st.leapTo.X, st.leapFrom.Y, st.leapTo.Z))) -- 공중에서 끊기면 착지 자리에 내려놓는다
			end
		end,
	}
end

return BossLeap
