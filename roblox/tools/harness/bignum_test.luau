-- 큰 골드 숫자 안전성 하네스(골드 점검 2): 저장 왕복 · 서버 골드 계산 · 화면 표기를 1e12 ~ 1e18 · 2^53 경계에서 확인한다(보고 전용 - 고치지 않는다 · 정밀도 4건 = KNOWN 표).
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$(python deps.py PlayerProfile,PetService,QuestService,SaveSystem) ECON_RES=res_big.txt python build_run.py bignum_test.luau
--   결과 = %TEMP%/res_big.txt · "[BIG] ... O/X" 줄 + "[BIG] 끝 n/m"
Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local pass, total = 0, 0
-- QUEUE-ALL9C 0-2: 알려진 문제(이름 = check 라벨 그대로 고정 - 다른 X는 여기에 숨지 않는다). 사유 · 관련 결정. 고쳐져 O가 되면 "해결됨"으로 찍히니 표에서 뺀다.
local KNOWN = {
	["addGold 2^53 - 1 + 2 = 2^53 + 1 정확"] = "2^53 넘는 정수는 double로 정확히 못 담음(1 잃음) · ALL9B 결정 필요 8 → ALL9C 0-11 안전망 · 0-12 소모처 결정 뒤",
	["addGold 1.09e18 보유에 처치당 9.6e11 × 1,000회 정확"] = "1e18 근처 ulp 128 - 처치 골드 반올림 누적(상대 오차 3e-11) · 같은 결정",
	["trySpendGold 1.09e18 - 12,345 정확"] = "1e18 근처 ulp 128 - 작은 비용이 128 단위로 깎임 · 같은 결정",
	["addGold 1e18 + 50 정확(작은 보상)"] = "1e18 근처 ulp 128 - 64 미만 보상 사라짐 · 같은 결정(0-11 사라지는 보상 목록)",
}
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
	local expectFormat = { [1e12] = "1T", [1e15] = "1aa", [9e15] = "9aa", [1e16] = "10aa", [1e18] = "1ab" }
	local expectKo = { [1e12] = "1조", [1e15] = "1,000조", [9e15] = "9,000조", [P53] = "9,007조", [1e16] = "1경", [1e18] = "100경", [TOP_6M] = "109경" }
	local expectEn = { [1e12] = "1T" }
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
		check(("저장 왕복 gold = %s"):format(label), valid and back.gold == g and #repaired == 0, ("→ %.17g · 유효 %s · 고친 칸 %d"):format(back.gold, tostring(valid), #repaired))
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
	local function setGold(g) p.gold = g end

	-- 3-1. 2^53 미만: 처치당 골드를 1,000번 더해도 정확
	setGold(P53 - 1000 * 7 - 1)
	local start = p.gold
	for _ = 1, 1000 do PlayerProfile.addGold(player, 7) end
	check("addGold 2^53 바로 아래까지 1,000회(+7) 정확", p.gold - start == 7000 and p.gold == P53 - 1 and attrs.Gold == p.gold, ("→ %.17g"):format(p.gold))
	-- 3-2. 2^53 넘기는 1회
	setGold(P53 - 1)
	PlayerProfile.addGold(player, 2)
	check("addGold 2^53 - 1 + 2 = 2^53 + 1 정확", p.gold == P53 + 1 and p.gold - (P53 - 1) == 2, ("→ %.17g(정답 9007199254740993)"):format(p.gold))
	-- 3-3. 최종 스테이지 처치당 골드(9.6e11)를 6개월 보유(1.09e18)에 1,000회 더하기 - 정수 정밀도
	setGold(TOP_6M)
	local base = p.gold
	local ulp = 2 ^ (math.floor(math.log(base, 2)) - 52)
	for _ = 1, 1000 do PlayerProfile.addGold(player, PER_KILL_END + 37) end
	local want = PER_KILL_END * 1000 + 37000
	local got = p.gold - base
	check("addGold 1.09e18 보유에 처치당 9.6e11 × 1,000회 정확", got == want, ("증가 %.17g · 정답 %.17g · 오차 %.0f골드(ulp %.0f · 상대 %.2g)"):format(got, want, got - want, ulp, math.abs(got - want) / want))
	-- 3-4. trySpendGold: 큰 보유에서 작은 비용(수련 · 보석 재련급) 차감 정확
	setGold(TOP_6M)
	local spentOk = PlayerProfile.trySpendGold(player, 12345)
	check("trySpendGold 1.09e18 - 12,345 정확", spentOk and TOP_6M - p.gold == 12345, ("실제 차감 %.17g"):format(TOP_6M - p.gold))
	setGold(P53 - 100)
	local spent2 = PlayerProfile.trySpendGold(player, 12345)
	check("trySpendGold 2^53 아래 - 12,345 정확", spent2 and p.gold == P53 - 100 - 12345, ("→ %.17g"):format(p.gold))
	-- 3-5. 부족 판정 · 같은 값 차감(큰 값)
	setGold(1e18)
	check("trySpendGold 보유 = 비용(1e18) → 0", PlayerProfile.trySpendGold(player, 1e18) and p.gold == 0, ("→ %.17g"):format(p.gold))
	setGold(1e18)
	check("trySpendGold 보유 < 비용(1e18 + 1e3) → 거부 · 그대로", not PlayerProfile.trySpendGold(player, 1e18 + 1024) and p.gold == 1e18, ("→ %.17g"):format(p.gold))
	-- 3-6. inf · nan 오염 차단(기존 가드)
	setGold(TOP_6M)
	PlayerProfile.addGold(player, math.huge)
	PlayerProfile.addGold(player, 0 / 0)
	check("addGold inf · nan = 0으로 건너뜀(1.09e18 그대로)", p.gold == TOP_6M, ("→ %.17g"):format(p.gold))
	-- 3-7. 1e18 이상에서 작은 보상(출석 · 패스 골드 몇 천)이 사라지는가
	setGold(1e18)
	PlayerProfile.addGold(player, 50)
	check("addGold 1e18 + 50 정확(작은 보상)", p.gold - 1e18 == 50, ("실제 증가 %.17g(ulp 128)"):format(p.gold - 1e18))
end)
if not ok then
	print("[BIG] 하네스 에러 " .. tostring(err))
end
print(("[BIG] 끝 %d/%d · 알려진 문제 %d%s"):format(pass, total, knownHit, #knownFixed > 0 and (" · 해결됨 " .. #knownFixed) or ""))
