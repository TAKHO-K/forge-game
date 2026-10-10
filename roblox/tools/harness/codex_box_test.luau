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
	-- UI-1b 0절(VERIFY-5): 옛 합계를 손으로 계산한 고정값(같은 식 반복 X) · 받은 장부 하나 · 스위치 왕복 이중 수령 0 · 열어만 둔 점수판 → 해당 상자
	check("옛 점수판 합 고정값 = 골드 몫 4445 · 강화석 442", t.goldKills == 4445 and t.enhanceStone == 442, ("%d · %d"):format(t.goldKills, t.enhanceStone))
	local function sumBoard(boardClaimed, boxClaimed, keys)
		local g = { goldKills = 0, enhanceStone = 0 }
		for _, k in ipairs(keys) do
			local d = R.boardPay(k, boardClaimed, boxClaimed)
			g.goldKills += d.goldKills
			g.enhanceStone += d.enhanceStone
			boardClaimed[k] = true
		end
		return g
	end
	local function sumBox(boardClaimed, boxClaimed, ns)
		local g = { goldKills = 0, enhanceStone = 0 }
		for _, n in ipairs(ns) do
			local p = R.boxPay(n, boardClaimed)
			-- 상자 경로는 장부 증가분(= boxPay)을 준다
			local before = R.paidLedger(boardClaimed, boxClaimed)
			boxClaimed[tostring(n)] = true
			local after = R.paidLedger(boardClaimed, boxClaimed)
			check(("상자 %d 지급 = 장부 증가분"):format(n), p.goldKills == after.goldKills - before.goldKills and p.enhanceStone == after.enhanceStone - before.enhanceStone)
			g.goldKills += p.goldKills
			g.enhanceStone += p.enhanceStone
		end
		return g
	end
	local allKeys = {}
	for _, th in ipairs(C.board) do table.insert(allKeys, tostring(th)) end
	-- ① 상자 10개 다 받음 → 스위치 끔 → 점수판 29개 다 받기 = 추가 0
	local bc, xc = {}, {}
	local g1 = sumBox(bc, xc, { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
	local g2 = sumBoard(bc, xc, allKeys)
	check("상자 다 받은 뒤 점수판(스위치 끔) = 추가 0 · 합 = 옛 합계", g2.goldKills == 0 and g2.enhanceStone == 0 and g1.goldKills == 4445 and g1.enhanceStone == 442, ("%d · %d"):format(g2.goldKills, g2.enhanceStone))
	-- ② 점수판 일부 → 상자 3개 → 점수판 나머지 → 상자 나머지 = 합 4445 · 442(이중 0 · 손실 0)
	bc, xc = {}, {}
	local a = sumBoard(bc, xc, { "5", "10", "15", "60", "330" })
	local b = sumBox(bc, xc, { 1, 2, 3 })
	local c = sumBoard(bc, xc, allKeys)
	local d = sumBox(bc, xc, { 4, 5, 6, 7, 8, 9, 10 })
	local gk, es = a.goldKills + b.goldKills + c.goldKills + d.goldKills, a.enhanceStone + b.enhanceStone + c.enhanceStone + d.enhanceStone
	check("점수판 ↔ 상자 섞어 받기 = 합 4445 · 442", gk == 4445 and es == 442, ("%d · %d"):format(gk, es))
	-- ③ 열어만 두고 안 받은 점수판(5 ~ 100 = 13개) → 해당 상자까지 열림 · 누적 몫 ≤ 열린 몫
	local done = {}
	local open = { goldKills = 0, enhanceStone = 0 }
	for _, th in ipairs(C.board) do
		if th <= 100 then
			done[tostring(th)] = 5
			local r = C.boardReward(th)
			open.goldKills += r.goldKills
			open.enhanceStone += r.enhanceStone
		end
	end
	local nOpen = R.boxesOpenedByBoard(done)
	local cumN, cumN1 = R.boxCumulative(nOpen), R.boxCumulative(math.min(nOpen + 1, 10))
	check("열린 점수판 몫 → 상자 n까지 열림(넘치지 않음 · 다음 상자는 넘침)", nOpen >= 1 and cumN.goldKills <= open.goldKills and (nOpen == 10 or cumN1.goldKills > open.goldKills or cumN1.enhanceStone > open.enhanceStone), ("열린 몫 %d · 상자 %d(누적 %d)"):format(open.goldKills, nOpen, cumN.goldKills))
	check("아무것도 안 연 계정 = 0", R.boxesOpenedByBoard({}) == 0)
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
