-- UI-1 5단계 도감 진행 상자 하네스(순수): 옛 점수판 29단계 합(골드 몫 · 강화석) = 상자 10개 합(1 단위까지) · 점수판을 다 받은 사람 = 상자 추가 0 · 일부 받은 사람 = 합 그대로 · 토큰 총합.
-- 실행: LUAU=<luau.exe> EXTRA_SERVER=SecretNestData ECON_RES=res_codexbox.txt python build_run.py codex_box_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[CBOX] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local C = MODS.CodexData
	local R = MODS.CodexRules
	check("옛 점수판 = 29단계", #C.board == 29, tostring(#C.board))
	local t = R.boardTotals()
	local sum = { goldKills = 0, enhanceStone = 0 }
	for n = 1, C.boxes.count do
		local s = R.boxShare(n)
		sum.goldKills += s.goldKills
		sum.enhanceStone += s.enhanceStone
	end
	check("총량 그대로: 골드 몫 합(옛 = 새)", sum.goldKills == t.goldKills, ("%d = %d"):format(t.goldKills, sum.goldKills))
	check("총량 그대로: 강화석 합(옛 = 새)", sum.enhanceStone == t.enhanceStone, ("%d = %d"):format(t.enhanceStone, sum.enhanceStone))
	check("상자마다 ÷ 10 · 나머지 = 100% 상자", R.boxShare(1).goldKills == math.floor(t.goldKills / 10) and R.boxShare(10).goldKills == t.goldKills - 9 * math.floor(t.goldKills / 10))
	local all = {}
	for _, th in ipairs(C.board) do
		all[tostring(th)] = true
	end
	local extra = 0
	for n = 1, 10 do
		local p = R.boxPay(n, all)
		extra += p.goldKills + p.enhanceStone
	end
	check("점수판을 다 받은 사람 = 상자 골드 · 강화석 0(두 번 안 받음)", extra == 0, tostring(extra))
	local some = { ["5"] = true, ["10"] = true, ["60"] = true }
	local got = { goldKills = 0, enhanceStone = 0 }
	for k in pairs(some) do
		local r = C.boardReward(tonumber(k))
		got.goldKills += r.goldKills
		got.enhanceStone += r.enhanceStone
	end
	for n = 1, 10 do
		local p = R.boxPay(n, some)
		got.goldKills += p.goldKills
		got.enhanceStone += p.enhanceStone
	end
	check("일부 받은 사람 = 받은 점수판 + 상자 = 옛 총량", got.goldKills == t.goldKills and got.enhanceStone == t.enhanceStone, ("%d · %d"):format(got.goldKills, got.enhanceStone))
	local tok = 0
	for n = 1, 10 do
		tok += R.boxShare(n).sparkleShard or 0
	end
	check("상자 토큰 = 60% · 70% 각 70(합 140)", tok == 140 and C.boxes.tokensAt[6] == 70 and C.boxes.tokensAt[7] == 70, tostring(tok))
	local nests = {} -- 서버 CodexService와 같은 둥지 목록(SecretNestData track C · 마을 제외)
	for _, spec in ipairs(MODS.SecretNestData or {}) do
		if spec.track == "C" and spec.sub ~= "village" and C.zoneShort[spec.zone] then
			nests[spec.zone] = nests[spec.zone] or {}
			table.insert(nests[spec.zone], spec.id)
		end
	end
	local book = R.build(nests)
	local cellTok = R.totalTokens(book)
	print(("[CBOX] 칸 · 줄 토큰 합 = %d(초월 칸 포함) · 전체 점수 칸 = %d"):format(cellTok, book.totalScore))
	check("칸 · 줄 토큰 합 = 600(초월 칸 4 포함)", cellTok == 600, tostring(cellTok))
	check("전체 점수 칸 = 362(장비 108 · 펫 96 · 탐험 36 · 몬스터 60 · 보스 30 · 직업 32)", book.totalScore == 362, tostring(book.totalScore))
	check("상자 10 = 전체 점수 칸 10%마다(100% = 전체)", R.boxThreshold(10, book.totalScore) == book.totalScore and R.boxThreshold(1, book.totalScore) == math.ceil(book.totalScore / 10))
end)
if not okRun then
	print("[CBOX] 하네스 에러 " .. tostring(err))
end
print(("[CBOX] 끝 %d/%d"):format(pass, total))
