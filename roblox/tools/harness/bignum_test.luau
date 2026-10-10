-- 큰 골드 숫자 안전성 하네스(골드 점검 2): 저장 왕복 · 서버 골드 계산 · 화면 표기를 1e12 ~ 1e18 · 2^53 경계에서 확인한다(보고 전용 - 고치지 않는다 · 옛 정밀도 4건 = PROG-2B-1 2^53 상한으로 해결 · 일반 검사).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem) ECON_RES=res_big.txt python build_run.py bignum_test.luau
--   결과 = %TEMP%/res_big.txt · "[BIG] ... O/X" 줄 + "[BIG] 끝 n/m"
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
-- QUEUE-ALL9C 0-2: 알려진 문제(이름 = check 라벨 그대로 고정 - 다른 X는 여기에 숨지 않는다). 사유 · 관련 결정. 고쳐져 O가 되면 "해결됨"으로 찍히니 표에서 뺀다.
-- PROG-2B-1 2: 옛 4건(2^53 넘는 보유의 정수 정밀도)은 골드 내부 안전 상한 2^53(NumberGuard · changeGold · 저장 · 로드)으로 해결 → 일반 검사로 바꿈(상한에서 멈춤 · 상한 안은 정확).
local KNOWN = {}
local knownHit, knownFixed = 0, {}
local function check(label, ok, detail)
	if KNOWN[label] then
		if ok then
			table.insert(knownFixed, label)
			print(("[BIG] (알려진 문제 해결됨 - KNOWN 표에서 빼기) %s %s O"):format(label, detail or ""))
		else
			knownHit += 1
			print(("[BIG] (알려진 문제) %s %s - %s"):format(label, detail or "", KNOWN[label]))
		end
		return
	end
	total += 1
	if ok then pass += 1 end
	print(("[BIG] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local function info(label, detail)
	print(("[BIG] (정보) %s %s"):format(label, detail or ""))
end
local P53 = 2 ^ 53
-- EconSim 상위 1% 6개월(12h × 182일 = 2,184h) 보유 · 누적 수입 상한(goldcheck 실측 1.09e18)과 최종 스테이지 처치당(약 9.6e11 ~ 1.13e12)
local TOP_6M = 1.0929e18
local PER_KILL_END = 958507000000

local ok, err = pcall(function()
	local SaveSystem = MODS.SaveSystem
	local PlayerProfile = MODS.PlayerProfile
	local NumberFormat = MODS.NumberFormat

	-- ═══ 1. 화면 표기 ═══
	local function sane(s)
		return type(s) == "string" and not s:find("inf") and not s:find("nan") and not s:find("e[+-]") and not s:find("∞") and s ~= "—" and not s:find("E")
	end
	local VALUES = { 1e12, 1e15, 9e15, P53, 1e16, 1e18, TOP_6M }
	local expectFormat = { [1e12] = "1T", [1e15] = "1Qa", [9e15] = "9Qa", [1e16] = "10Qa", [1e18] = "1Qi" } -- QUEUE-ALL9C 0-8
	local expectKo = { [1e12] = "1.0조", [1e15] = "1,000.0조", [9e15] = "9,000.0조", [P53] = "9,007.1조", [1e16] = "1.0경", [1e18] = "100.0경", [TOP_6M] = "109.2경" }
	local expectEn = { [1e12] = "1.0T", [1e15] = "1.0Qa", [1e18] = "1.0Qi", [TOP_6M] = "1.0Qi" }
	for _, v in ipairs(VALUES) do
		local f = NumberFormat.format(v)
		check(("format(%.6g)"):format(v), sane(f) and (expectFormat[v] == nil or f == expectFormat[v]), ("= %q%s"):format(f, expectFormat[v] and (" (기대 " .. expectFormat[v] .. ")") or ""))
		local ko = NumberFormat.currency(v, "ko")
		check(("currency ko(%.6g)"):format(v), sane(ko) and (expectKo[v] == nil or ko == expectKo[v]), ("= %q (기대 %s)"):format(ko, tostring(expectKo[v])))
		local en = NumberFormat.currency(v, "en")
		check(("currency en(%.6g)"):format(v), sane(en) and (expectEn[v] == nil or en == expectEn[v]), ("= %q"):format(en))
		if v >= 1e15 and not en:find("Qa") then
			info(("currency en(%.6g) 단위"):format(v), ("%q - 1e15 이상은 Qa가 아니라 format의 알파벳 단위(aa · ab ...)로 넘어간다"):format(en))
		end
		local c = NumberFormat.commas(v)
		local digitsOnly = type(c) == "string" and c:gsub(",", ""):match("^%d+$") ~= nil
		check(("commas(%.6g) 정확한 값 표기(재화 칸 마우스 올리기)"):format(v), sane(c) and digitsOnly, ("= %q"):format(tostring(c)))
	end
	-- 경계 inf · nan은 기존 가드 그대로
	check("format(inf · nan) 가드", NumberFormat.format(math.huge) == "∞" and NumberFormat.format(0 / 0) == "—", "")
	-- QUEUE-ALL9C 0-8 큰 수 표기 경계값(currency = HUD · 가방 · 상점 · 강화 창 공통)
	local BOUND = {
		{ 999, "999", "999" }, { 1000, "1.0K", "1,000" }, { 999999, "999.9K", "99.9만" }, { 1e6, "1.0M", "100.0만" }, { 9999, "9.9K", "9,999" }, { 1e4, "10.0K", "1.0만" },
		{ 1e15, "1.0Qa", "1,000.0조" }, { 1e21, "1.0Sx", "10.0해" }, { 1e24, "1.0Sp", "1.0자" }, { 1e33, "1.0Dc", "10.0구" }, { 1e36, "1.0aa", "1.0간" }, { 1e39, "1.0ab", "1,000.0간" },
		{ 0, "0", "0" }, { -5, "-5", "-5" }, { -12345, "-12.3K", "-1.2만" }, { 0 / 0, "—", "—" }, { math.huge, "∞", "∞" },
	}
	for _, b in ipairs(BOUND) do
		local en, ko = NumberFormat.currency(b[1], "en"), NumberFormat.currency(b[1], "ko")
		check(("0-8 표기 경계 %.6g"):format(b[1]), en == b[2] and ko == b[3], ("en %q(기대 %q) · ko %q(기대 %q)"):format(en, b[2], ko, b[3]))
	end

	-- ═══ 2. 저장 왕복(가짜 DataStore = 숫자를 %.17g 문자열로 직렬화 → 다시 숫자 · migrate · repairProfile · isValidProfile · sanitizeForSave) ═══
	local function roundTrip(node)
		if type(node) == "number" then
			return tonumber(("%.17g"):format(node))
		elseif type(node) == "table" then
			local out = {}
			for k, v in pairs(node) do out[k] = roundTrip(v) end
			return out
		end
		return node
	end
	local SAVE_VALUES = { { "1e12", 1e12 }, { "1e15", 1e15 }, { "9e15", 9e15 }, { "2^53 - 1", P53 - 1 }, { "2^53", P53 }, { "2^53 + 1(리터럴)", P53 + 1 }, { "2^53 + 2", P53 + 2 }, { "1e16", 1e16 }, { "상위 1% 6개월 1.09e18", TOP_6M }, { "1e18", 1e18 } }
	for _, pair in ipairs(SAVE_VALUES) do
		local label, g = pair[1], pair[2]
		local p = SaveSystem.migrate({})
		p.gold = g
		SaveSystem.sanitizeForSave(p, nil, "profile")
		local back = roundTrip(p)
		back = SaveSystem.migrate(back)
		local repaired = SaveSystem.repairProfile(back)
		local valid = SaveSystem.isValidProfile(back)
		check(("저장 왕복 gold = %s"):format(label), valid and back.gold == math.min(g, P53) and #repaired == 0, ("→ %.17g · 유효 %s · 고친 칸 %d(PROG-2B-1: 2^53 넘으면 상한)"):format(back.gold, tostring(valid), #repaired))
	end
	info("2^53 + 1 리터럴", ("double로 이미 %.17g(= 2^53) - 저장 이전에 정수 하나가 사라진다"):format(P53 + 1))

	-- ═══ 3. 서버 골드 계산(PlayerProfile.addGold · trySpendGold - 실제 함수) ═══
	local attrs = {}
	local player = setmetatable({ Name = "Big", UserId = 4242, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	profile.tutorial.completed = true
	PlayerProfile.init(player, profile)
	PlayerProfile.setClassId(player, "bow")
	local p = PlayerProfile.getProfile(player)
	local function setGold(g) p.gold = g; attrs.Gold = g end

	-- 3-1. 2^53 미만: 처치당 골드를 1,000번 더해도 정확
	setGold(P53 - 1000 * 7 - 1)
	local start = p.gold
	for _ = 1, 1000 do PlayerProfile.addGold(player, 7) end
	check("addGold 2^53 바로 아래까지 1,000회(+7) 정확", p.gold - start == 7000 and p.gold == P53 - 1 and attrs.Gold == p.gold, ("→ %.17g"):format(p.gold))
	-- 3-2. 2^53 넘기는 1회
	setGold(P53 - 1)
	PlayerProfile.addGold(player, 2)
	check("addGold 2^53 - 1 + 2 = 2^53(PROG-2B-1 안전 상한 - 넘는 몫 버림)", p.gold == P53, ("→ %.17g"):format(p.gold))
	-- 3-3. 상한 근처에서 옛 최종 처치당 골드(9.6e11) × 1,000회 = 2^53에서 멈춤(넘지 않음 · 유한)
	setGold(P53 - 1000)
	for _ = 1, 1000 do PlayerProfile.addGold(player, PER_KILL_END + 37) end
	check("addGold 상한 근처 처치당 9.6e11 × 1,000회 = 2^53에서 멈춤", p.gold == P53 and attrs.Gold == P53, ("→ %.17g"):format(p.gold))
	-- 3-4. trySpendGold: 상한 보유에서 작은 비용(수련 · 보석 재련급) 차감 정확
	setGold(P53)
	local spentOk = PlayerProfile.trySpendGold(player, 12345)
	check("trySpendGold 2^53 - 12,345 정확", spentOk and P53 - p.gold == 12345, ("실제 차감 %.17g"):format(P53 - p.gold))
	setGold(P53 - 100)
	local spent2 = PlayerProfile.trySpendGold(player, 12345)
	check("trySpendGold 2^53 아래 - 12,345 정확", spent2 and p.gold == P53 - 100 - 12345, ("→ %.17g"):format(p.gold))
	-- 3-5. 부족 판정 · 같은 값 차감(큰 값)
	setGold(1e18)
	check("trySpendGold 보유 = 비용(1e18) → 0", PlayerProfile.trySpendGold(player, 1e18) and p.gold == 0, ("→ %.17g"):format(p.gold))
	setGold(1e18)
	check("trySpendGold 보유 < 비용(1e18 + 1e3) → 거부 · 그대로", not PlayerProfile.trySpendGold(player, 1e18 + 1024) and p.gold == 1e18, ("→ %.17g"):format(p.gold))
	-- 3-6. inf · nan 오염 차단(기존 가드)
	setGold(P53 - 5)
	PlayerProfile.addGold(player, math.huge)
	PlayerProfile.addGold(player, 0 / 0)
	check("addGold inf · nan = 0으로 건너뜀(2^53 − 5 그대로)", p.gold == P53 - 5, ("→ %.17g"):format(p.gold))
	-- 3-7. 상한 안 큰 보유에서 작은 보상(출석 · 패스 골드 몇 천)이 사라지지 않음
	setGold(P53 - 100)
	PlayerProfile.addGold(player, 50)
	check("addGold 2^53 − 100 + 50 정확(작은 보상)", p.gold == P53 - 50, ("→ %.17g"):format(p.gold))

	-- ═══ 4. QUEUE-ALL9C 0-11 안전망: 골드 증감 한 곳(changeGold) · 비정상 금액 · 1e16 / 1e18 / 1e20 ═══
	setGold(5000)
	local nanSpend = PlayerProfile.trySpendGold(player, 0 / 0)
	local negSpend = PlayerProfile.trySpendGold(player, -500)
	local infSpend = PlayerProfile.trySpendGold(player, math.huge)
	local strSpend = PlayerProfile.trySpendGold(player, "100")
	check("0-11 trySpendGold NaN · 음수 · inf · 문자열 = 거부 · 골드 그대로", not nanSpend and not negSpend and not infSpend and not strSpend and p.gold == 5000 and p.gold == p.gold,
		("→ %.17g(옛 코드 = NaN · 5,500)"):format(p.gold))
	PlayerProfile.addGold(player, -math.huge)
	PlayerProfile.addGold(player, -99999)
	check("0-11 addGold −inf = 건너뜀 · 큰 음수 = 0에서 멈춤(음수 골드 없음)", p.gold == 0, ("→ %.17g"):format(p.gold))
	setGold(1000)
	local took = PlayerProfile.takeGold(player, 5000)
	check("0-11 운영 회수 takeGold = 가진 만큼만(1,000) · 0", took == 1000 and p.gold == 0, ("뺀 양 %s"):format(tostring(took)))
	local Enhance = MODS.Enhance
	for _, g in ipairs({ 1e16, 1e18, 1e20 }) do
		-- 저장 왕복
		local sp = SaveSystem.migrate({})
		sp.gold = g
		SaveSystem.sanitizeForSave(sp, nil, "profile")
		local back = SaveSystem.migrate(roundTrip(sp))
		local okSave = SaveSystem.isValidProfile(back) and back.gold == math.min(g, P53) and #SaveSystem.repairProfile(back) == 0 -- PROG-2B-1: 로드 = 2^53 상한
		-- 구매 가능 비교(같은 값 · 1ulp 넘게 큰 값 · 작은 값)
		local ulpG = 2 ^ (math.floor(math.log(g, 2)) - 52)
		setGold(g)
		local cmpOk = not PlayerProfile.trySpendGold(player, g + ulpG * 4) and p.gold == g
		-- 판매(가방 장비 1개 → 판매가만큼 늘어남 · 유한)
		p.inventory = { { id = "big1", grade = "normal", part = "armor", tierIndex = 1, dropStage = 1, itemLevel = 1 } }
		local price = MODS.Loot.getSellPrice(p.inventory[1])
		local sold = PlayerProfile.sellItem(player, 1)
		local sellOk = sold and p.gold == math.min(g + price, P53) and p.gold == p.gold and p.gold < math.huge -- PROG-2B-1: 증감 = 2^53 상한
		-- 강화 비용 차감(스테이지 25,300 · +26 방지 켬 = 최대 단일 비용)
		setGold(g)
		local cost = Enhance.getCost(26, 25300, true, true)
		local spent = PlayerProfile.trySpendGold(player, cost)
		local enhOk = (spent == (g >= cost)) and p.gold == (spent and math.min(g - cost, P53) or g) and p.gold >= 0 -- 보유 ≥ 비용일 때만 차감 · PROG-2B-1: 증감 = 2^53 상한
		-- 표시
		local en, ko = NumberFormat.currency(p.gold, "en"), NumberFormat.currency(p.gold, "ko")
		local dispOk = sane(en) and sane(ko) and attrs.Gold == p.gold
		check(("0-11 보유 %.0e: 저장 왕복 · 비교 · 판매 · 강화 비용 차감 · 표시"):format(g), okSave and cmpOk and sellOk and enhOk and dispOk,
			("저장 %s · 비교 %s · 판매 %s(+%s) · 강화 %s(비용 %.3g) · 표시 %s / %s"):format(tostring(okSave), tostring(cmpOk), tostring(sellOk), tostring(price), tostring(enhOk), cost, en, ko))
	end
end)
if not ok then
	print("[BIG] 하네스 에러 " .. tostring(err))
end
print(("[BIG] 끝 %d/%d · 알려진 문제 %d%s"):format(pass, total, knownHit, #knownFixed > 0 and (" · 해결됨 " .. #knownFixed) or ""))
