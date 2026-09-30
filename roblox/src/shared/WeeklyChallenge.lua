-- QUEUE-ALL1 P4 §3 주간 도전 순수 규칙(서버 · 검증 같은 식). 수치 = shared/data/WeeklyChallengeData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local D = require(ReplicatedStorage.Shared.data.WeeklyChallengeData)
local BossSkillMath = require(ReplicatedStorage.Shared.BossSkillMath)
local Quest = require(ReplicatedStorage.Shared.Quest)

local WeeklyChallenge = {}

function WeeklyChallenge.weekOf(unix)
	return Quest.weekOf(unix or os.time())
end

function WeeklyChallenge.entryOf(week)
	return D.cycle[(week - 1) % #D.cycle + 1]
end

-- 인스턴스 데이터(buildInstanceData 결과)에 변형을 건 사본 - 건드리는 경로만 복사한다(원본 · 공유 표 불변)
function WeeklyChallenge.apply(data, mods)
	local out = table.clone(data)
	for _, m in ipairs(mods or {}) do
		local node = out
		for i = 1, #m.path - 1 do
			local k = m.path[i]
			if type(node[k]) ~= "table" then
				node = nil
				break
			end
			node[k] = table.clone(node[k])
			node = node[k]
		end
		local field = m.path[#m.path]
		if node and type(node[field]) == "number" then
			local v = node[field] * m.mul
			if math.floor(node[field]) == node[field] then
				v = math.floor(v + 0.5)
			end
			if m.max then
				v = math.min(v, m.max)
			end
			node[field] = v
		end
	end
	out.isWeekly = true
	return out
end

-- 회피 부등식 검사(모든 스킬) - 반환 ok, 실패 목록
function WeeklyChallenge.check(data)
	local fails = {}
	local walk = require(ReplicatedStorage.Shared.data.WorldConfig).playerWalkSpeedStuds
	for id, skill in pairs(data.skills or {}) do
		local ok, rows = pcall(BossSkillMath.dodgeChecks, skill, 8, walk) -- BR1(가)와 같은 자리(근접 8 · 걷기 속도)
		if ok and type(rows) == "table" then
			for _, r in ipairs(rows) do
				if r.ok == false then
					table.insert(fails, ("%s %s"):format(id, tostring(r.label or r.kind or "")))
				end
			end
		end
	end
	table.sort(fails)
	return #fails == 0, fails
end

return WeeklyChallenge
