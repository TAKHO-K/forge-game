-- BR1-2 색 맞추기 전멸기(docs/design/boss-br1-2.md §6-3 - 심해 군주, 옛 "범람"을 대신한다). primitive = "colorMatch"(보스 이름이 들어간 분기 없음).
-- 흐름(수치 = 스킬 데이터):
--   시작: 멤버마다 머리 위 표시 = 빨강 ● / 파랑 ▲(색약 대비 - 모양도 다르다) · 아레나 kit의 발판(tag = platformTag)마다 무작위 색(둘 다 하나 이상)
--   전조 telegraphSeconds 동안: 누군가 발판에 **올라서는 순간**마다 그 발판 색이 뒤집힌다(남이 밟아도 내 발판 색이 바뀐다 - 협동 혼란)
--   판정(전조 끝): 자기 표시와 **같은 색 발판 위**(윗면에 서 있음)면 생존 · 아니면 최대 체력 × failMaxHpFraction(보호막 무시 - 진짜 즉사는 K)
-- 판정은 서버(발판 = BossPropMath.kitZones · 발 높이), 색칠 · 표시는 클라(BossColorView).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossPropMath = require(ReplicatedStorage.Shared.BossPropMath)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossTrap = require(script.Parent.BossTrap)
local PlayerDamage = require(script.Parent.PlayerDamage)
local PlayerState = require(script.Parent.PlayerState)
local MonsterState = require(script.Parent.MonsterState)

local BossColorMatch = {}

local kit
local rng = Random.new()
local COLORS = { "red", "blue" }

local function platformsOf(c)
	local arena = WorldConfig.zones[MonsterState.getZoneKey(c.model) or ""]
	local center = arena and arena.center or kit.zoneOf(c.model).center
	return BossPropMath.kitZones(c.data.arenaKit, center, c.st.floorY, c.skill.platformTag)
end

-- 이 사람이 서 있는 발판 번호(윗면 위 - 발이 윗면 −0.5 ~ +standToleranceStuds). 없으면 nil.
function BossColorMatch.platformUnder(platforms, feet, skill)
	for _, p in ipairs(platforms) do
		local top = p.center.Y + p.size.Y / 2
		if BossPropMath.insideBox(feet, p.center, p.size, 0) and feet.Y >= top - 0.5 and feet.Y <= top + skill.standToleranceStuds then
			return p.index
		end
	end
	return nil
end

BossColorMatch.handler = {
	bubbleSeconds = function(c)
		return c.skill.telegraphSeconds
	end,
	start = function(c)
		local st, skill = c.st, c.skill
		st.phase = "colorTelegraph"
		st.phaseEndsAt = c.now + skill.telegraphSeconds
		st.colorPlatforms = platformsOf(c)
		st.colorOf = {}
		for _, p in ipairs(st.colorPlatforms) do
			st.colorOf[p.index] = COLORS[rng:NextInteger(1, 2)]
		end
		if #st.colorPlatforms >= 2 then -- 두 색 모두 하나 이상
			st.colorOf[1], st.colorOf[2] = "red", "blue"
		end
		st.colorMark, st.colorOn = {}, {}
		local marks, list = {}, {}
		for _, v in ipairs(kit.victims(st)) do
			local color = COLORS[rng:NextInteger(1, 2)]
			st.colorMark[v.player] = color
			st.colorOn[v.player] = BossColorMatch.platformUnder(st.colorPlatforms, v.feet or v.groundFeet, skill) -- 이미 서 있던 발판은 "올라선" 것이 아니다
			table.insert(marks, { userId = typeof(v.player) == "Instance" and v.player.UserId or 0, color = color })
		end
		for _, p in ipairs(st.colorPlatforms) do
			table.insert(list, { index = p.index, center = p.center, size = p.size, color = st.colorOf[p.index] })
		end
		kit.send(st, "colorStart", { seconds = skill.telegraphSeconds, marks = marks, platforms = list, bossId = c.data.id })
		print(("[forge-game] 색 맞추기: 발판 %d · 멤버 %d · %.1f초"):format(#list, #marks, skill.telegraphSeconds))
	end,
	step = function(c)
		local st, skill = c.st, c.skill
		if st.phase == "colorTelegraph" then
			-- 올라서는 순간 뒤집기
			for _, v in ipairs(kit.victims(st)) do
				local now = BossColorMatch.platformUnder(st.colorPlatforms, v.feet or v.groundFeet, skill)
				if now and now ~= st.colorOn[v.player] then
					st.colorOf[now] = st.colorOf[now] == "red" and "blue" or "red"
					kit.send(st, "colorFlip", { index = now, color = st.colorOf[now] })
					kit.debugEvent("colorFlip", { player = v.player, index = now, color = st.colorOf[now], at = c.now })
				end
				st.colorOn[v.player] = now
			end
			if c.now < st.phaseEndsAt then
				return
			end
			local safe, failed = {}, {}
			kit.judgeBegin()
			for _, v in ipairs(kit.victims(st)) do
				if not BossTrap.isTrapped(v.player) and (PlayerState.getHp(v.player) or 0) > 0 then
					local on = BossColorMatch.platformUnder(st.colorPlatforms, v.feet or v.groundFeet, skill)
					local id = typeof(v.player) == "Instance" and v.player.UserId or 0
					if on and st.colorOf[on] == st.colorMark[v.player] then
						table.insert(safe, id)
					else
						table.insert(failed, id)
						PlayerDamage.applyMaxHpFraction(v.player, skill.failMaxHpFraction, skill.damageLabel, { ignoresShield = true })
						BossTrap.noteSkillHit(v.player)
					end
					kit.debugEvent("colorJudge", { player = v.player, on = on, platformColor = on and st.colorOf[on], mark = st.colorMark[v.player], safe = on ~= nil and st.colorOf[on] == st.colorMark[v.player], at = c.now })
				end
			end
			kit.judgeEnd(c, { kind = "colorMatch" })
			kit.send(st, "colorResolve", { safe = safe, failed = failed })
			print(("[forge-game] 색 맞추기 판정: 생존 %d · 실패 %d"):format(#safe, #failed))
			st.phase = "colorRecover"
			st.phaseEndsAt = c.now + (skill.recoverSeconds or 1)
			return
		end
		if c.now >= st.phaseEndsAt then
			kit.send(st, "colorEnd", {})
			kit.endSkill(c.model, st, c.data, c.now)
		end
	end,
	interrupt = function(c)
		kit.send(c.st, "colorEnd", {})
	end,
}

function BossColorMatch.register(handlers, patternKit)
	kit = patternKit
	handlers.colorMatch = BossColorMatch.handler
end

return BossColorMatch
