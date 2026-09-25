-- D0 (b): 환생 직후 Lv.1 보스 재도전 가능 여부 + what-if 3안. 저장소 코드는 그대로, 이 하네스 안에서만 EconSim 소스에 훅을 붙였다(d0_mk.py).
local VARIANTS = VARIANTS_OVERRIDE or { "base", "W1", "W1b", "W2", "W3a", "W3b" }
local PROFILES = PROFILES_OVERRIDE or { "casual", "normal", "top" }
local MARKS = { 50, 100, 150, 200, 300, 400, 500, 700, 1000 }
local HOURS_CAP = 1500

D0 = {}
local mode
local function gapOf(state, stage)
	return math.max(0, stage - state.level - (D0.freeGap or 0))
end
function D0.deal(state, stage)
	if mode ~= "W1" and mode ~= "W1b" then return 1 end
	return math.max(0.25, 1 - 0.01 * gapOf(state, stage))
end
function D0.take(state, stage)
	if mode ~= "W1" and mode ~= "W1b" then return 1 end
	return math.min(3, 1 + 0.02 * gapOf(state, stage))
end
function D0.gearFor(state)
	local limit
	if mode == "W3a" then
		limit = MODS.CharacterLevel.getStageForLevel(state.level)
	elseif mode == "W3b" then
		limit = state.level + 20
	end
	if not limit then return state.gear end
	local copy = {}
	for part, item in pairs(state.gear) do
		if type(item) == "table" and item.itemLevel and item.itemLevel > limit then
			local c = table.clone(item)
			c.itemLevel = limit
			copy[part] = c
		else
			copy[part] = item
		end
	end
	return copy
end

local BossRules = MODS.BossRules
local BalanceSim = MODS.BalanceSim
local PlayerCombat = MODS.PlayerCombat
local EconSim = MODS.EconSim
local BossData = MODS.BossData

local function canClear(state, profile, loadout, stage)
	local data = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), profile.partySize)
	local hits = BalanceSim.getSurviveHits(loadout, data.attack, PlayerCombat.getNewbieDamageMultiplier(stage) * D0.take(state, stage))
	local effectiveHp = data.hp / (profile.bossDpsEfficiency * profile.partySize) / D0.deal(state, stage)
	local seconds = EconSim.killSeconds(loadout, effectiveHp, 100000)
	local ok = hits >= profile.minSurviveHits and seconds <= profile.bossKillLimitSeconds
	return ok, hits, seconds
end

local cur
function D0.onRebirth(state, profile, pre, post, levelAtRebirth, preReach)
	local lastBoss = preReach - BossData.stageInterval
	local rec = { k = state.rebirth, level = levelAtRebirth, preReach = preReach, lastBoss = lastBoss, at = state.seconds, atkRatio = post.atk / pre.atk, preAtk = pre.atk }
	-- 직후 Lv.1(post, 레벨 1)로 직전 보스(lastBoss) 재도전
	local savedLevel = state.level
	rec.preOk, rec.preHits, rec.preSec = canClear({ level = levelAtRebirth }, profile, pre, lastBoss)
	rec.postOk, rec.postHits, rec.postSec = canClear(state, profile, post, lastBoss)
	state.level = savedLevel
	if mode == "W2" then
		state.reach = BossData.stageInterval
		rec.reclimbTarget = preReach
	end
	table.insert(cur.rebirths, rec)
end

function D0.afterChunk(state, run, profile)
	local hours = state.seconds / 3600
	for _, rec in ipairs(cur.rebirths) do
		if not rec.recoverAt and EconSim.loadoutFor(state).atk >= rec.preAtk then
			rec.recoverAt = state.seconds
		end
		if rec.reclimbTarget and not rec.reclimbAt and state.reach >= rec.reclimbTarget then
			rec.reclimbAt = state.seconds
		end
	end
	cur.maxReach = math.max(cur.maxReach, state.reach)
	for _, m in ipairs(MARKS) do
		if not cur.marks[m] and cur.maxReach >= m then
			cur.marks[m] = state.seconds
		end
	end
	local last = cur.rebirths[#cur.rebirths]
	if hours > HOURS_CAP then
		D0.stop = true
	elseif #cur.rebirths >= 5 and last.recoverAt and (not last.reclimbTarget or last.reclimbAt) and cur.maxReach >= 1000 then
		D0.stop = true
	end
end

local function h(s) return s and ("%.2f"):format(s / 3600) or "-" end

for _, variant in ipairs(VARIANTS) do
	mode = variant
	D0.freeGap = (variant == "W1b") and 100 or 0
	for _, pid in ipairs(PROFILES) do
		D0.stop = false
		EconSim.clearCaches()
		cur = { rebirths = {}, marks = {}, maxReach = 0 }
		local t0 = os.clock()
		local run = EconSim.runProgress(pid, {})
		print(("== %s · %s · 계산 %.1fs · 끝 %.1fh 레벨 %d reach %d stall=%s"):format(variant, pid, os.clock() - t0, run.final.seconds / 3600, run.final.level, run.final.reach, tostring(run.stall)))
		for _, r in ipairs(cur.rebirths) do
			print(("  환생%d @%sh Lv%d reach%d 직전보스%d | 공격비 %.3f | 직전 ok=%s(버팀%d·%.0fs) → 직후 ok=%s(버팀%d·%.0fs) | 회복 %sh 뒤 | 재등반 %s"):format(
				r.k, h(r.at), r.level, r.preReach, r.lastBoss, r.atkRatio, tostring(r.preOk), r.preHits, r.preSec, tostring(r.postOk), r.postHits, math.min(r.postSec, 99999),
				r.recoverAt and h(r.recoverAt - r.at) or "-", r.reclimbAt and (h(r.reclimbAt - r.at) .. "h") or "-"))
		end
		local parts = {}
		for _, m in ipairs(MARKS) do table.insert(parts, ("%d:%sh"):format(m, h(cur.marks[m]))) end
		print("  도달 " .. table.concat(parts, " "))
	end
end
