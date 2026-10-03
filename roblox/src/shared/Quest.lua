-- QUEUE-10h Q6 G3 퀘스트 계산(순수 - 서버 · 클라 · 하네스 공용). 데이터 = shared/data/QuestData.lua.
--   저장 모양(profile.quests - SAVE v50): { day, daily = { [id] = { n, claimed } }, week, weekly = { [id] = { n, claimed } }, loginDay, chestDay, main = 다음 메인 단계 번호, currencies = { sparkleShard, passExp } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
local SeasonBoardData = require(ReplicatedStorage.Shared.data.SeasonBoardData)

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

-- QUEUE-ALL9B 5 시즌 출석판 상태(profile.quests.board - SAVE v67): season = 판의 시즌 번호 · count = 센 칸(하루 첫 접속 1칸 · 32까지) · lastDay = 마지막으로 센 UTC 날짜 ·
--   claimed = { ["칸"] = true } · bonusDay = 32칸 뒤 남은 날 보너스를 받은 날짜
function Quest.newBoard(season)
	return { season = season or 0, count = 0, lastDay = -1, claimed = {}, bonusDay = -1 }
end

function Quest.newState(now)
	return { day = Quest.dayOf(now), daily = {}, week = Quest.weekOf(now), weekly = {}, loginDay = -1, chestDay = -1, main = 1, currencies = { sparkleShard = 0, passExp = 0 },
		guide = 1, attendance = { count = 0, lastDay = -1, claimed = {} }, mainN = 0, board = Quest.newBoard(0) } -- QUEUE-ALL3 Q3(v60): mainN = 지금 메인 단계(cond event)에 들어선 뒤 센 수 -- Q12(v53): 첫 5분 이정표 · 7일 출석(새 계정만 - 옛 계정은 이관에서 nil)
end

-- 날짜 · 주가 바뀌었으면 진행을 비운다(되돌리기 없음 - 받은 보상은 이미 들어갔다). 반환 = 바뀌었는가
function Quest.roll(state, now, season)
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
	local att = state.attendance -- Q12: 접속한 날마다 한 칸(7칸까지)
	if type(att) == "table" and att.lastDay ~= day and att.count < #QuestData.attendance then
		att.count += 1
		att.lastDay = day
		changed = true
	end
	if season then -- QUEUE-ALL9B 5 시즌 출석판(시즌 번호를 아는 호출부만 - 서버 QuestService)
		if type(state.board) ~= "table" or state.board.season ~= season then
			state.board = Quest.newBoard(season)
			changed = true
		end
		local b = state.board
		if b.lastDay ~= day then
			if b.count < #SeasonBoardData.cells then
				b.count += 1
			end
			b.lastDay = day
			changed = true
		end
	end
	return changed
end

-- 출석판 오늘 받을 것: "cell"(칸 번호) | "bonus"(32칸 뒤 남은 날) | nil(오늘 다 받음)
function Quest.boardToday(state)
	local b = state.board
	if type(b) ~= "table" or b.count < 1 then
		return nil
	end
	for n = 1, b.count do
		if not b.claimed[tostring(n)] then
			return "cell", n
		end
	end
	if b.count >= #SeasonBoardData.cells and b.lastDay == state.day and b.bonusDay ~= state.day then
		return "bonus"
	end
	return nil
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
	-- QUEUE-ALL3 Q3: 지금 메인 단계가 이 이벤트를 세면 mainN(목표에서 멈춤)
	local mainStep = QuestData.main[state.main]
	if mainStep and mainStep.cond == "event" and mainStep.event == event then
		local before = state.mainN or 0
		state.mainN = math.min(mainStep.target, before + (amount or 1))
		if before < mainStep.target and state.mainN >= mainStep.target then
			table.insert(reached, mainStep.id)
		end
	end
	local guideStep = state.guide and QuestData.ftue[state.guide] -- Q12 이정표: 지금 단계의 이벤트면 다음 단계로
	local advanced = nil
	if guideStep and guideStep.event == event then
		advanced = guideStep
		state.guide = state.guide < #QuestData.ftue and state.guide + 1 or nil
	end
	return reached, advanced
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
function Quest.claim(state, kind, id, now, facts, season)
	Quest.roll(state, now, season)
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
		if not Quest.mainDone(step, facts, state) then
			return nil, "not_done"
		end
		state.main += 1
		state.mainN = 0 -- 다음 단계는 새로 센다
		return step.reward
	elseif kind == "attendance" then -- Q12: id = 날짜 칸 번호(문자열) · 센 날까지만 · 한 번씩
		local att = state.attendance
		local n = tonumber(id)
		local entry = n and QuestData.attendance[n]
		if type(att) ~= "table" or not entry then
			return nil, "unknown"
		end
		if n > att.count then
			return nil, "not_done"
		end
		if att.claimed[tostring(n)] then
			return nil, "claimed"
		end
		att.claimed[tostring(n)] = true -- 문자열 키(DataStore 왕복 뒤에도 같은 키)
		return entry.reward
	elseif kind == "board" then -- QUEUE-ALL9B 5: id = 칸 번호 · 센 칸까지만 · 한 번씩
		local b, n = state.board, tonumber(id)
		local cell = n and SeasonBoardData.cells[n]
		if type(b) ~= "table" or not cell then
			return nil, "unknown"
		end
		if n > b.count then
			return nil, "not_done"
		end
		if b.claimed[tostring(n)] then
			return nil, "claimed"
		end
		b.claimed[tostring(n)] = true
		return cell
	elseif kind == "boardBonus" then -- 32칸 뒤 남은 날: 오늘 접속했고 오늘 아직 안 받음
		local b = state.board
		if type(b) ~= "table" or b.count < #SeasonBoardData.cells then
			return nil, "not_done"
		end
		for n = 1, #SeasonBoardData.cells do
			if not b.claimed[tostring(n)] then
				return nil, "not_done"
			end
		end
		if b.lastDay ~= state.day or b.bonusDay == state.day then
			return nil, "claimed"
		end
		b.bonusDay = state.day
		return SeasonBoardData.after
	end
	return nil, "unknown"
end

-- 메인 단계 진행(표시 · 판정 공용): 반환 n, 목표. state = 퀘스트 상태(cond event의 mainN)
function Quest.mainProgress(step, facts, state)
	facts = facts or {}
	local need = step.target or step.value or 1
	if step.cond == "event" then
		return math.min(state and state.mainN or 0, need), need
	elseif step.cond == "tutorial" then
		return facts.tutorialDone and 1 or 0, 1
	end
	local key = ({ bossCleared = "bestBossCleared", weaponLevel = "weaponLevel", gemSocketed = "gemSocketed", eggs = "eggs", rebirth = "rebirth", level = "level", checkpoints = "checkpoints" })[step.cond]
	return math.min(key and facts[key] or 0, need), need
end

-- 메인 단계 조건(facts = { tutorialDone, bestBossCleared, weaponLevel, gemSocketed, eggs, rebirth, level, checkpoints } - 서버가 프로필에서 채운다 · state = event 단계의 mainN)
function Quest.mainDone(step, facts, state)
	facts = facts or {}
	if step.cond == "event" or step.cond == "level" or step.cond == "checkpoints" then -- QUEUE-ALL3 Q3
		local n, need = Quest.mainProgress(step, facts, state)
		return n >= need
	elseif step.cond == "tutorial" then
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

-- 표시용 문장("몬스터 150마리 처치"). template = 번역한 틀(QUEUE-ALL6 A4 - 서버가 Text.nameFor로 바꾼 틀에 채운다 · 생략 = 원문)
function Quest.nameOf(q, template)
	return ((template or q.name):gsub("{n}", tostring(q.target or q.value or "")))
end

-- QUEUE-ALL3 Q3 v60 이관: 옛 메인 번호(QuestData.legacyMainIds 순) → 새 번호(같은 id · 없으면 그다음 옛 단계의 id) · 다 끝났으면 #main + 1
function Quest.migrateMainIndex(oldIndex)
	local legacy = QuestData.legacyMainIds
	for k = oldIndex, #legacy do
		for i, step in ipairs(QuestData.main) do
			if step.id == legacy[k] then
				return i
			end
		end
	end
	return #QuestData.main + 1
end

return Quest
