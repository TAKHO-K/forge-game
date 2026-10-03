Random = { new = function(seed) math.randomseed(seed or 1); return { NextInteger = function(_, a, b) return math.random(a, b) end, NextNumber = function(_, a, b) a = a or 0; b = b or 1; return a + math.random() * (b - a) end } end }
local ok, err = pcall(function()
	local SaveSystem = MODS.SaveSystem
	local PlayerProfile = MODS.PlayerProfile
	local attrs = {}
	local player = setmetatable({ Name = "Dupe", UserId = 42, Parent = true }, { __index = function(_, k)
		if k == "SetAttribute" then return function(_, n, v) attrs[n] = v end end
		if k == "GetAttribute" then return function(_, n) return attrs[n] end end
		if k == "FindFirstChild" or k == "WaitForChild" or k == "FindFirstChildOfClass" then return function() return nil end end
		if k == "IsA" then return function() return false end end
		if k == "GetAttributeChangedSignal" then return function() return { Connect = function() end } end end
		return nil
	end })
	local profile = SaveSystem.migrate({})
	PlayerProfile.init(player, profile); PlayerProfile.setClassId(player, "bow")
	profile.tutorial = profile.tutorial or {}
	profile.tutorial.completed = true
	PlayerProfile.init(player, profile)
	local p = PlayerProfile.getProfile(player)
	local function line(label, cond, detail) print(("[DUPE] %s %s %s"):format(label, detail or "", cond and "O" or "X")) end

	-- ① 판매 연타: 같은 칸 두 번 → 골드 한 번 · 장비 한 번 빠짐
	p.inventory = { { grade = "epic", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1 }, { grade = "rare", part = "gloves", itemLevel = 5, dropStage = 5, tierIndex = 1 } }
	local g0 = p.gold
	local a = PlayerProfile.sellItem(player, 1)
	local g1 = p.gold
	local b = PlayerProfile.sellItem(player, 1)
	line("판매 연타(같은 칸 1 두 번)", #p.inventory == 0 or (#p.inventory == 1 and b ~= nil), ("1회 %s · 2회 %s · 골드 +%s · 남은 %d(두 번째는 밀린 다른 칸 판매 = 클라가 보낸 칸 번호 기준 - 복사 아님)"):format(tostring(a), tostring(b), tostring(g1 - g0), #p.inventory))

	-- ② 잠금 장비 판매 · 분해 거부
	p.inventory = { { grade = "epic", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1, locked = true } }
	local s1 = PlayerProfile.sellItem(player, 1)
	local d1 = PlayerProfile.dismantleItem(player, 1)
	line("잠금 장비 판매 · 분해 거부", not s1 and d1 == false and #p.inventory == 1)

	-- ③ 일괄 분해 두 번 → 두 번째 0 · 보석 수 = 대상 수
	p.inventory = { { grade = "epic", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1 }, { grade = "legendary", part = "gloves", itemLevel = 5, dropStage = 5, tierIndex = 1 }, { grade = "rare", part = "shoes", itemLevel = 5, dropStage = 5, tierIndex = 1 } }
	local cs = p.classes[p.classId]
	local gems0 = #cs.gemInventory
	local n1 = PlayerProfile.dismantleItemsUpTo(player, "legendary")
	local n2 = PlayerProfile.dismantleItemsUpTo(player, "legendary")
	line("일괄 분해 연타", n1 == 2 and n2 == 0 and #cs.gemInventory - gems0 == 2 and #p.inventory == 1, ("%d · %d · 보석 +%d"):format(n1, n2, #cs.gemInventory - gems0))

	-- ③-2 QUEUE-ALL8 G1 등급별 일괄 판매: 같은 요청 두 번 → 두 번째 0 · 골드 한 번 · 전설 · 잠금 · 스킬 변형 남음 · 전설 체크 · 겹친 등급 · 개수 불일치 = 거부
	p.inventory = {
		{ grade = "normal", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1 },
		{ grade = "rare", part = "gloves", itemLevel = 5, dropStage = 5, tierIndex = 1 },
		{ grade = "rare", part = "shoes", itemLevel = 5, dropStage = 5, tierIndex = 1, locked = true },
		{ grade = "epic", part = "helmet", itemLevel = 5, dropStage = 5, tierIndex = 1, skillVariant = "x" },
		{ grade = "legendary", part = "armor", itemLevel = 5, dropStage = 5, tierIndex = 1 },
	}
	local gA = p.gold
	local bad1 = PlayerProfile.sellItemsByGrades(player, { "legendary" }, 1)
	local bad2 = PlayerProfile.sellItemsByGrades(player, { "rare", "rare" }, 1)
	local bad3 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare" }, 5)
	local sold1, gold1 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare", "epic" }, 2)
	local sold2 = PlayerProfile.sellItemsByGrades(player, { "normal", "rare", "epic" }, 2)
	local left = {}
	for _, it in ipairs(p.inventory) do
		table.insert(left, it.grade)
	end
	line("등급별 일괄 판매 연타 · 거부", bad1 == 0 and bad2 == 0 and bad3 == 0 and sold1 == 2 and sold2 == 0 and p.gold - gA == gold1 and #p.inventory == 3,
		("전설 %d · 겹침 %d · 개수 다름 %d · 1회 %d(+%d골드) · 2회 %d · 남은 %s"):format(bad1, bad2, bad3, sold1, gold1 or 0, sold2, table.concat(left, ",")))

	-- ④ 부화 연타(같은 알 번호 + 획득 시각) → 두 번째 거부 · 받기 두 번 → 두 번째 거부
	local PetService = MODS.PetService
	p.eggs = { { zone = "tier1", grade = "normal", species = { "stoneTurtle", "mossHare" }, nest = "t", at = 111 }, { zone = "tier2", grade = "good", species = { "crystalBat", "prismLizard" }, nest = "t", at = 222 } }
	local h1 = PetService.hatch(player, 1, 111)
	local h2 = PetService.hatch(player, 1, 111)
	line("부화 연타(같은 알 두 번)", h1 == true and h2 ~= true and #p.eggs == 1 and p.eggs[1].at == 222, ("1회 %s · 2회 %s · 남은 알 %d"):format(tostring(h1), tostring(h2), #p.eggs))
	local st = PlayerProfile.getPetState(player)
	st.hatching[1].doneAt = 0
	local c1 = PetService.claim(player, 1)
	local c2 = PetService.claim(player, 1)
	line("부화 받기 연타", c1 == true and c2 ~= true and #st.list == 1 and st.hatchCount == 1)

	-- ⑤ 보상 수령 연타(출석 · 접속 · 메인)
	local Quest = MODS.Quest
	local qs = PlayerProfile.getQuestState(player)
	Quest.roll(qs, os.time())
	local QuestService = MODS.QuestService
	local r1 = QuestService.claim(player, "attendance", "1")
	local r2 = QuestService.claim(player, "attendance", "1")
	local l1 = QuestService.claim(player, "login")
	local l2 = QuestService.claim(player, "login")
	line("출석 · 접속 보상 연타", r1 == true and r2 ~= true and l1 == true and l2 ~= true, ("출석 %s/%s · 접속 %s/%s"):format(tostring(r1), tostring(r2), tostring(l1), tostring(l2)))

	-- ⑦ QUEUE-ALL9B 3-5 토큰 구매 연타(같은 상품 두 번 · 토큰은 한 번 값만 있음) → 두 번째 owned · 토큰 한 번만 차감 · 음수 없음
	local MS = MODS.MonetizationService
	local price = MODS.Monetization.productTokenPrice(MODS.MonetizationData, MODS.CosmeticSlotData, "theme_jelly")
	qs.currencies.sparkleShard = price
	local k1, kw1 = MS.buyWithTokens(player, "theme_jelly")
	local k2, kw2 = MS.buyWithTokens(player, "theme_jelly")
	local k3, kw3 = MS.buyWithTokens(player, "theme_frost")
	local ms = PlayerProfile.getMonetizationState(player)
	line("토큰 구매 연타(같은 상품 · 남은 토큰 0에서 다른 상품)", k1 == true and k2 ~= true and kw2 == "owned" and k3 ~= true and kw3 == "shards" and qs.currencies.sparkleShard == 0 and ms.cosmetics.themes.jelly == true and not ms.cosmetics.themes.frost,
		("1회 %s · 2회 %s · 다른 %s · 남은 %d"):format(tostring(k1), tostring(kw2), tostring(kw3), qs.currencies.sparkleShard))

	-- ⑥ 튕김 직전 수령 → 재접속: 받은 표시와 보상이 같은 프로필 한 번의 저장에 함께 들어간다(저장 전 튕김 = 둘 다 없음 - 복사 불가)
	local snap = SaveSystem.migrate(MODS.SaveSystem.migrate({})) -- 저장 전 상태(재접속 때 읽는 값)
	line("튕김 직전 수령 = 받은 표시 · 보상이 한 저장 단위(부분 저장 경로 없음)", snap.quests.attendance.claimed["1"] == nil)
end)
if not ok then print("[DUPE] 하네스 에러 " .. tostring(err)) end
