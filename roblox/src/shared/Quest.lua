-- QUEUE-10h Q6 G3 퀘스트 계산(순수 - 서버 · 클라 · 하네스 공용). 데이터 = shared/data/QuestData.lua.
--   저장 모양(profile.quests - SAVE v50): { day, daily = { [id] = { n, claimed } }, week, weekly = { [id] = { n, claimed } }, loginDay, chestDay, main = 다음 메인 단계 번호, currencies = { sparkleShard, passExp } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestData = require(ReplicatedStorage.Shared.data.QuestData)

local Quest = {}

-- UTC 날짜 번호(1970-01-01 = 0) · 주 번호(월요일 시작)
function Quest.dayOf(unix)
	return math.floor((unix or os.time()) / 86400)
end

function Quest.weekOf(unix)
	return math.floor((Quest.dayOf(unix) + 3) / 7) -- 1970-01-01 = 목요일 → +3 = 월요일 시작
end

-- 그날 일간 목록(날짜 시드 - 모두 같다 · 중복 없음)
function Quest.dailyFor(day)
	-- 리뷰 4: 옛 LCG(곱이 2^53을 넘어 하위 비트 소실 → 거의 늘 같은 3개 · pool 4 · 8개면 무한 루프) → Random.new(날짜) + Fisher-Yates(끝이 보장된다)
	local pool = QuestData.dailyPool
	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	local rng = Random.new(day)
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local picked = {}
	for i = 1, math.min(QuestData.dailyCount, #pool) do
		table.insert(picked, pool[order[i]])
	end
	return picked
end

function Quest.newState(now)
	return { day = Quest.dayOf(now), daily = {}, week = Quest.weekOf(now), weekly = {}, loginDay = -1, chestDay = -1, main = 1, currencies = { sparkleShard = 0, passExp = 0 } }
end

-- 날짜 · 주가 바뀌었으면 진행을 비운다(되돌리기 없음 - 받은 보상은 이미 들어갔다). 반환 = 바뀌었는가
function Quest.roll(state, now)
	local changed = false
	local day, week = Quest.dayOf(now), Quest.weekOf(now)
	if state.day ~= day then
		state.day, state.daily = day, {}
		changed = true
	end
	if state.week ~= week then
		state.week, state.weekly = week, {}
		changed = true
	end
	return changed
end

-- 이벤트 하나 → 진행(일간 · 주간). 반환 = 새로 목표에 닿은 퀘스트 id 목록
function Quest.note(state, event, amount, now)
	Quest.roll(state, now)
	local reached = {}
	local function bump(list, progress)
		for _, q in ipairs(list) do
			if q.event == event then
				local p = progress[q.id] or { n = 0 }
				progress[q.id] = p
				local before = p.n
				p.n = math.min(q.target, p.n + (amount or 1))
				if before < q.target and p.n >= q.target then
					table.insert(reached, q.id)
				end
			end
		end
	end
	bump(Quest.dailyFor(state.day), state.daily)
	bump(QuestData.weekly, state.weekly)
	return reached
end

local function find(list, id)
	for _, q in ipairs(list) do
		if q.id == id then
			return q
		end
	end
	return nil
end

-- 받기: kind = "daily" | "weekly" | "login" | "chest" | "main". 반환 = 보상 표 | nil, 이유
function Quest.claim(state, kind, id, now, facts)
	Quest.roll(state, now)
	if kind == "login" then
		if state.loginDay == state.day then
			return nil, "claimed"
		end
		state.loginDay = state.day
		return QuestData.loginReward
	elseif kind == "chest" then
		if state.chestDay == state.day then
			return nil, "claimed"
		end
		for _, q in ipairs(Quest.dailyFor(state.day)) do
			local p = state.daily[q.id]
			if not (p and p.n >= q.target) then
				return nil, "not_done"
			end
		end
		state.chestDay = state.day
		return QuestData.dailyChest
	elseif kind == "daily" or kind == "weekly" then
		local list = kind == "daily" and Quest.dailyFor(state.day) or QuestData.weekly
		local progress = kind == "daily" and state.daily or state.weekly
		local q = find(list, id)
		local p = q and progress[q.id]
		if not q then
			return nil, "unknown"
		end
		if not (p and p.n >= q.target) then
			return nil, "not_done"
		end
		if p.claimed then
			return nil, "claimed"
		end
		p.claimed = true
		return q.reward
	elseif kind == "main" then
		local step = QuestData.main[state.main]
		if not step then
			return nil, "finished"
		end
		if not Quest.mainDone(step, facts) then
			return nil, "not_done"
		end
		state.main += 1
		return step.reward
	end
	return nil, "unknown"
end

-- 메인 단계 조건(facts = { tutorialDone, bestBossCleared, weaponLevel, gemSocketed, eggs, rebirth } - 서버가 프로필에서 채운다)
function Quest.mainDone(step, facts)
	facts = facts or {}
	if step.cond == "tutorial" then
		return facts.tutorialDone == true
	elseif step.cond == "bossCleared" then
		return (facts.bestBossCleared or 0) >= step.value
	elseif step.cond == "weaponLevel" then
		return (facts.weaponLevel or 0) >= step.value
	elseif step.cond == "gemSocketed" then
		return (facts.gemSocketed or 0) >= step.value
	elseif step.cond == "eggs" then
		return (facts.eggs or 0) >= step.value
	elseif step.cond == "rebirth" then
		return (facts.rebirth or 0) >= step.value
	end
	return false
end

-- 표시용 문장("몬스터 150마리 처치")
function Quest.nameOf(q)
	return (q.name:gsub("{n}", tostring(q.target or q.value or "")))
end

return Quest
