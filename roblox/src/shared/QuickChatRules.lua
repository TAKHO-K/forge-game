-- UI-1 7c 빠른 말 규칙(순수 - 서버 QuickChatService · 하네스 quick_chat): 정해진 번호만 · 같은 말 연속 n번 = 쉬기 · 최소 간격.
--   state = { lastKey, streak, pauseUntil, lastAt } (사람마다 서버가 들고 있음)
local QuickChatData = require(script.Parent.data.QuickChatData)

local QuickChatRules = {}

-- kind = "phrase" | "emote" · index = 1부터 → 맞으면 true
function QuickChatRules.valid(kind, index)
	if type(index) ~= "number" or index ~= math.floor(index) then
		return false
	end
	if kind == "phrase" then
		return QuickChatData.phrases[index] ~= nil
	elseif kind == "emote" then
		return QuickChatData.emotes[index] ~= nil
	end
	return false
end

-- 보내도 되나: 반환 = ok, 이유("invalid" · "fast" · "pause") · state를 고친다
function QuickChatRules.allow(state, kind, index, now)
	if not QuickChatRules.valid(kind, index) then
		return false, "invalid"
	end
	if state.pauseUntil and now < state.pauseUntil then
		return false, "pause"
	end
	if state.lastAt and now - state.lastAt < QuickChatData.minGap then
		return false, "fast"
	end
	local key = kind .. ":" .. index
	state.streak = (state.lastKey == key) and (state.streak or 0) + 1 or 1
	state.lastKey = key
	state.lastAt = now
	if state.streak >= QuickChatData.repeatLimit then -- 이번 것은 보내고 그 뒤 쉬기
		state.pauseUntil = now + QuickChatData.repeatPause
		state.streak = 0
		state.lastKey = nil
	end
	return true
end

return QuickChatRules
