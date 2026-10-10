-- UI-1 7c 빠른 말 규칙 하네스(순수 - 서버와 같은 함수): 정해진 번호만 · 같은 말 3번 연속 = 그 뒤 5초 쉬기 · 최소 간격 · 다른 말은 연속으로 안 셈.
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[QCHAT] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local R, D = MODS.QuickChatRules, MODS.QuickChatData
	check("말 8 · 이모트 4", #D.phrases == 8 and #D.emotes == 4)
	check("정해진 번호만(0 · 9 · 소수 · 글 = 거절)", not R.valid("phrase", 0) and not R.valid("phrase", 9) and not R.valid("phrase", 1.5) and not R.valid("text", 1) and R.valid("emote", 4))
	local st, t = {}, 0
	local a1 = R.allow(st, "phrase", 1, t)
	local a2 = R.allow(st, "phrase", 1, t + 1)
	local a3 = R.allow(st, "phrase", 1, t + 2)
	local a4, why = R.allow(st, "phrase", 2, t + 3)
	check("같은 말 3번 = 3번째까지 보내고 그 뒤 쉬기", a1 and a2 and a3 and not a4 and why == "pause", tostring(why))
	check("5초 지나면 다시", R.allow(st, "phrase", 2, t + 2 + D.repeatPause + 0.1) == true)
	local st2 = {}
	local ok1 = R.allow(st2, "phrase", 1, 0)
	local ok2, why2 = R.allow(st2, "phrase", 2, 0.1)
	check("최소 간격 안 = 거절", ok1 and not ok2 and why2 == "fast")
	local st3 = {}
	local all = true
	for i = 1, 6 do
		all = all and R.allow(st3, "phrase", (i % 2) + 1, i) == true
	end
	check("번갈아 보내면 쉬기 없음", all)
end)
if not okRun then
	print("[QCHAT] 하네스 에러 " .. tostring(err))
end
print(("[QCHAT] 끝 %d/%d"):format(pass, total))
