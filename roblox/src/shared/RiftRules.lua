-- QUEUE-ALL1 P3 §3 균열 시간표(순수 - 서버 RiftService · 클라 RiftView · 검증이 같은 식을 부른다). 수치 = shared/data/RiftData.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RiftData = require(ReplicatedStorage.Shared.data.RiftData)

local RiftRules = {}

-- unix 초 → { active, startsAt, endsAt, nextStartsAt } (UTC 기준 · 모든 서버가 같은 시계라 동시에 열린다)
function RiftRules.stateAt(unix, data)
	data = data or RiftData
	local dayStart = unix - unix % 86400
	local best = nil
	local nextStart = math.huge
	for _, w in ipairs(data.windowsUtc) do
		for dayOffset = -1, 1 do
			local s = dayStart + dayOffset * 86400 + w.hour * 3600 + w.minute * 60
			local e = s + data.durationSeconds
			if unix >= s and unix < e then
				best = { active = true, startsAt = s, endsAt = e }
			elseif s > unix then
				nextStart = math.min(nextStart, s)
			end
		end
	end
	best = best or { active = false }
	best.nextStartsAt = nextStart
	return best
end

return RiftRules
