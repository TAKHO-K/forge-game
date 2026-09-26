-- D1 자동 검증(드랍 등급 개편 · 상위 등급 위력 가속 · 태초 각성 · 태초 낭만). id = "D1(가)" · "D1(나)".
--   (가) 순수: 드랍표 3종(합 1 · 지시 값 · 원칙) · 등급 경계값 · 1,000만 회 표본 vs 해석 계산 · 등급 위력표(드랍 장비만 · 무기/보석/공정성 불변) · 스테이지 환산 ·
--        판매가 불변 · 각성 판정/비용 · 알림 범위 · 각인 문구 · 저장 v43 이관(옛 태초 = 이전 태초 + 잠금)
--   (나) 실제 서버: 세계 번호 카운터 동시성(시험 키) · 알림 없이 명예의 전당 복원 · 드랍 경로(/gg drop force - 각인 · 출처 · 칭호 · 빛기둥 · 착용 표시) ·
--        잠금(판매 · 분해 · 이중 확인 없는 해제 거절) · 각성(비용 · 상한 · 고대 거절 · 골드 부족)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Awaken = require(ReplicatedStorage.Shared.Awaken)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local PrimordialStamp = require(ReplicatedStorage.Shared.PrimordialStamp)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[D1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[D1][%s] %s"):format(tag, label))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return pass, total
	end
	return r
end

local function near(a, b, eps)
	return math.abs(a - b) <= (eps or 1e-9)
end

local function sum(row)
	local s = 0
	for _, v in pairs(row) do
		s += v
	end
	return s
end

-- 잡몹 장비 1개 굴림(Loot.rollArmorDrop과 같은 순서: 태초 먼저 · 아니면 태초를 뺀 표) - 굴림값을 넣어 쓴다.
local function fieldGrade(tierIndex, u1, u2)
	local rate = DropTable.primordialBaseRate(tierIndex)
	if u1 < rate then
		return "primordial"
	end
	return Loot.gradeForRoll(DropTable.armorGradeTable(tierIndex), u2, "primordial")
end

function V.runPure()
	print("===D1 검증 시작(가)===")
	local r = newRecorder("가")
	local order = ArmorData.gradeOrder

	r.section("드랍표 3종 - 합 · 지시 값 · 원칙", function()
		local fc, raid = DropTableData.bossGrades.firstClear, DropTableData.bossGrades.raid
		r.check(("첫 클리어 합 %.12f · 영웅 62 · 전설 32.6 · 유물 5 · 고대 0.39 · 태초 0.01%%(일반 · 희귀 없음 = 영웅 이상 보장)"):format(sum(fc)),
			near(sum(fc), 1, 1e-12) and fc.epic == 0.62 and fc.legendary == 0.326 and fc.relic == 0.05 and fc.ancient == 0.0039 and fc.primordial == 0.0001 and not fc.normal and not fc.rare)
		r.check(("토벌 합 %.12f · 영웅 78 · 전설 20.948 · 유물 1 · 고대 0.05 · 태초 0.002%%"):format(sum(raid)),
			near(sum(raid), 1, 1e-12) and raid.epic == 0.78 and raid.legendary == 0.20948 and raid.relic == 0.01 and raid.ancient == 0.0005 and raid.primordial == 0.00002)
		for tierIndex = 1, 6 do
			local row = DropTable.gradeRow(tierIndex)
			local base = DropTableData.fairnessGradeByTier[tierIndex]
			-- 일반 ~ 전설 비율 유지: 새 표의 (등급 ÷ 일반~전설 합) = 옛 표의 같은 값
			local newSub, oldSub = 0, 0
			for _, g in ipairs({ "normal", "rare", "epic", "legendary" }) do
				newSub += DropTable.armorGradeTable(tierIndex)[g] or 0
				oldSub += base[g] or 0
			end
			local ratioOk = true
			for _, g in ipairs({ "normal", "rare", "epic", "legendary" }) do
				if base[g] then
					ratioOk = ratioOk and near((DropTable.armorGradeTable(tierIndex)[g] or 0) / newSub, base[g] / oldSub, 1e-12)
				end
			end
			r.check(("잡몹 tier%d 합 %.12f · 유물 %.3f%% ≤ 0.5 · 고대 %.4f%% · 태초 %.6f%%(감쇠 전) · 일반 ~ 전설 비율 유지 %s"):format(tierIndex, sum(row), (row.relic or 0) * 100,
				(row.ancient or 0) * 100, (row.primordial or 0) * 100, tostring(ratioOk)),
				near(sum(row), 1, 1e-12) and (row.relic or 0) <= 0.005 + 1e-15 and ((row.ancient or 0) == 0 or near(row.ancient, 0.00002, 0.00002 * 1e-5)) -- 태초 별도 굴림만큼(× (1 − 태초)) 줄어든다
					and (row.primordial or 0) <= 0.000001 + 1e-18 and ratioOk)
		end
		r.check("잡몹 tier6 고대 0.002% · 태초 0.0001%(지시 값)", near(DropTable.gradeRow(6).ancient, 0.00002, 1e-15) and near(DropTable.primordialBaseRate(6), 0.000001, 1e-18))
		-- 원칙: 토벌 1회 > 잡몹(장비 1개) · 토벌 ≪ 첫 클리어
		local f6 = DropTable.gradeRow(6)
		r.check(("원칙: 태초 잡몹 %.1e < 토벌 %.1e < 첫 클리어 %.1e · 고대 %.1e < %.1e < %.1e · 토벌 ≤ 첫 클리어 ÷ 5"):format(f6.primordial, raid.primordial, fc.primordial, f6.ancient, raid.ancient, fc.ancient),
			f6.primordial < raid.primordial and raid.primordial * 5 <= fc.primordial and f6.ancient < raid.ancient and raid.ancient * 5 <= fc.ancient)
		r.check("천장(확정 보상) 없음: 보스 첫 클리어 표 = 환생과 무관(상향표 폐지)", DropTable.bossFirstClearGradeTable(0) == DropTable.bossFirstClearGradeTable(3))
		-- 확률 공개 데이터
		local disclosure = DropTable.disclosure()
		local okAll = #disclosure.field == 6
		for _, rows in ipairs({ disclosure.firstClear, disclosure.raid, table.unpack(disclosure.field) }) do
			local s = 0
			for _, row in ipairs(rows) do
				s += row.chance
			end
			okAll = okAll and near(s, 1, 1e-12)
		end
		r.check("확률 공개 데이터 3종(첫 클리어 · 토벌 · 잡몹 tier 6줄) - 각 합 1", okAll)
	end)

	r.section("경계값(굴림값 → 등급)", function()
		local fc = DropTableData.bossGrades.firstClear
		local acc, okAll, rows = 0, true, {}
		local present = {}
		for _, g in ipairs(order) do
			if fc[g] then
				table.insert(present, g)
			end
		end
		for i, g in ipairs(present) do
			local lo = acc
			acc += fc[g]
			local atLo = Loot.gradeForRoll(fc, lo)
			local justBelowHi = Loot.gradeForRoll(fc, math.max(lo, acc - 1e-12))
			okAll = okAll and atLo == g and justBelowHi == g
			if i < #present then
				okAll = okAll and Loot.gradeForRoll(fc, acc) == present[i + 1]
			end
			table.insert(rows, ("%s[%.6f, %.6f)"):format(g, lo, acc))
		end
		r.check("첫 클리어 구간 경계(아래 끝 = 그 등급 · 위 끝 − 1e-12 = 그 등급 · 위 끝 = 다음 등급): " .. table.concat(rows, " "), okAll)
		r.check(("u = 0 → %s · u = 1 − 1e-15 → %s(태초 · 끝)"):format(tostring(Loot.gradeForRoll(fc, 0)), tostring(Loot.gradeForRoll(fc, 1 - 1e-15))),
			Loot.gradeForRoll(fc, 0) == "epic" and Loot.gradeForRoll(fc, 1 - 1e-15) == "primordial")
		local rate = DropTable.primordialBaseRate(6)
		r.check(("잡몹 tier6 태초 경계: u1 = %.1e − ε → 태초 · u1 = %.1e → 아님"):format(rate, rate), fieldGrade(6, rate - 1e-18, 0.5) == "primordial" and fieldGrade(6, rate, 0.5) ~= "primordial")
	end)

	r.section("1,000만 회 표본 vs 해석 계산", function()
		local N = 10000000
		local rng = Random.new(20260927)
		local function sample(label, analytic, draw)
			local counts = {}
			for i = 1, N do
				local g = draw()
				counts[g] = (counts[g] or 0) + 1
				if i % 250000 == 0 then
					task.wait()
				end
			end
			local okAll, cells = true, {}
			for _, g in ipairs(order) do
				local p = analytic[g] or 0
				if p > 0 or counts[g] then
					local expected = N * p
					local sigma = math.sqrt(N * p * (1 - p))
					local obs = counts[g] or 0
					local ok = math.abs(obs - expected) <= 4.5 * sigma + 1
					okAll = okAll and ok and p > 0
					table.insert(cells, ("%s %d/%.1f"):format(g, obs, expected))
				end
			end
			r.check(("SAMPLE|%s|%s(관측/기대 · 허용 4.5σ)"):format(label, table.concat(cells, " · ")), okAll)
		end
		sample("첫 클리어", DropTableData.bossGrades.firstClear, function()
			return Loot.gradeForRoll(DropTableData.bossGrades.firstClear, rng:NextNumber())
		end)
		sample("토벌", DropTableData.bossGrades.raid, function()
			return Loot.gradeForRoll(DropTableData.bossGrades.raid, rng:NextNumber())
		end)
		sample("잡몹 tier6(태초 별도 굴림)", DropTable.gradeRow(6), function()
			return fieldGrade(6, rng:NextNumber(), rng:NextNumber())
		end)
	end)

	r.section("등급 위력표(드랍 장비만)", function()
		local expect = { 1, 1.45, 2.1025, 2.1025 * 1.5, 2.1025 * 1.5 * 1.7, 2.1025 * 1.5 * 1.7 * 2, 2.1025 * 1.5 * 1.7 * 2 * 2.5 }
		local okAll, cells = true, {}
		for i, g in ipairs(order) do
			local grade = ArmorData.grades[g]
			okAll = okAll and near(grade.dropPower, expect[i], 1e-12) and near(grade.defenseGradeMultiplier, 1.184 * expect[i], 1e-12)
				and near(grade.fairnessMultiplier, 1.184 * 1.45 ^ (i - 1), 1e-12) and near(ItemVisualData.gradeVisuals[g].statMultiplier, 1.45 ^ (i - 1), 1e-12)
			table.insert(cells, ("%s %.3f"):format(g, grade.dropPower))
		end
		r.check("TABLE|드랍 위력 누적 " .. table.concat(cells, " · ") .. " · 갑옷 = 1.184 × 위력 · 무기 환생/보석 기준(statMultiplier 1.45^n) · 공정성 입력(옛 배율) 불변", okAll)
		r.check(("무기 태초(환생 등급 6) 배율 %.3f = 옛 값 · 장갑 태초 %.3f(위력표)"):format(PlayerCombat.gradeMultiplier(6), Loot.getGlovesAttackPercent({ grade = "primordial", itemLevel = 25 })),
			near(PlayerCombat.gradeMultiplier(6), 1.45 ^ 6, 1e-9) and near(Loot.getGlovesAttackPercent({ grade = "primordial", itemLevel = 25 }) / Loot.getGlovesAttackPercent({ grade = "normal", itemLevel = 25 }), expect[7], 1e-9))
		-- 몬스터 공정성 r(t) 불변(옛 식 직접 계산과 같음)
		local okR = true
		local base
		for t = 1, 6 do
			local e = 0
			for g, c in pairs(DropTableData.fairnessGradeByTier[t]) do
				e += c * 1.184 * 1.45 ^ (table.find(order, g) - 1)
			end
			base = base or e
			okR = okR and near(MonsterData.getRewardRatio(t), e / base, 1e-12)
		end
		r.check("몬스터 tier 공정성 r(t) = D1 전 표 · 옛 배율(몬스터 HP · 골드 · 드랍 개수 불변)", okR)
		-- 스테이지 환산(k)
		local k = InfiniteStageConfig.growthRate
		local stepCells = {}
		for i = 2, #order do
			table.insert(stepCells, ("%s→%s %.1f"):format(order[i - 1], order[i], math.log(expect[i] / expect[i - 1]) / math.log(k)))
		end
		local pl = math.log(expect[7] / expect[4]) / math.log(k)
		r.note("STAGE|한 단계 = " .. table.concat(stepCells, " · ") .. (" · 태초 vs 전설 %.1f스테이지"):format(pl))
		r.check(("태초 vs 전설 = %.1f스테이지(지시 예상 약 108)"):format(pl), pl > 105 and pl < 111)
	end)

	r.section("판매가 불변 · 각성 · 알림 범위 · 각인 문구", function()
		local function oldPrice(grade, tierIndex, stage)
			local chance = DropTableData.fairnessGradeByTier[tierIndex][grade] or (grade == "primordial" and 0.001 / DropTableData.primordial.dragonOverTier[tierIndex])
			return math.floor(1 / (ArmorData.dropChance * chance) * InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage) * ArmorData.sellRecoveryRate)
		end
		local okSell = true
		for _, c in ipairs({ { "ancient", 6, 500 }, { "primordial", 6, 500 }, { "relic", 4, 100 }, { "primordial", 1, 30 }, { "legendary", 5, 1000 } }) do
			okSell = okSell and Loot.getSellPrice({ grade = c[1], tierIndex = c[2], dropStage = c[3] }) == oldPrice(c[1], c[2], c[3])
		end
		r.check("판매가 = D1 전 식 그대로(고대 · 태초 · 유물 · 전설 표본 5)", okSell)
		local best = 1200
		local cost = Awaken.cost(best)
		r.check(("각성 비용 = tier1 골드 × %d마리 × 골드 성장(스테이지 %d) = %d"):format(PrimordialData.awakenGoldKills, best, cost),
			cost == GoldCost.cost(MonsterData.tier1.goldDrop * PrimordialData.awakenGoldKills, best, "awaken") and cost > 0)
		r.check("각성 판정: 태초 낮은 레벨 = 가능 · 레벨 = 최고 → 이미 최고 · 최고보다 높음 → 이미 최고 · 고대 → 태초만 · 없음 → 못 찾음",
			Awaken.blockReason({ grade = "primordial", itemLevel = 900 }, best) == nil and Awaken.blockReason({ grade = "primordial", itemLevel = best }, best) == "already_max"
				and Awaken.blockReason({ grade = "primordial", itemLevel = best + 5 }, best) == "already_max" and Awaken.blockReason({ grade = "ancient", itemLevel = 1 }, best) == "not_primordial"
				and Awaken.blockReason(nil, best) == "not_found")
		local DropNotice = require(script.Parent.DropNotice)
		r.check(("알림 범위: 태초 = %s(세계 기록 모듈) · 고대 솔로 = %s · 고대 파티 = %s · 유물 솔로 = %s · 유물 파티 = %s"):format(tostring(DropNotice.scopeFor("primordial", false)),
			tostring(DropNotice.scopeFor("ancient", false)), tostring(DropNotice.scopeFor("ancient", true)), tostring(DropNotice.scopeFor("relic", false)), tostring(DropNotice.scopeFor("relic", true))),
			DropNotice.scopeFor("primordial", true) == nil and DropNotice.scopeFor("ancient", false) == "server" and DropNotice.scopeFor("relic", false) == nil and DropNotice.scopeFor("relic", true) == "party")
		local line = PrimordialStamp.detailLine({ no = 37, ownerName = "호영", at = 1790910000, source = { kind = "boss", bossId = "scorpion_queen", stage = 20 } })
		r.check(("각인 문구 \"%s\" · 이전 태초 \"%s\""):format(tostring(line), tostring(PrimordialStamp.detailLine({ legacy = true }))),
			line == "★ 세계 37번째 태초 · 최초 획득 호영 · 2026-10-02 · 전갈 여왕 · 스테이지 20" and PrimordialStamp.detailLine({ legacy = true }) == "★ 이전 태초")
	end)

	r.section("저장 v43 이관", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = SaveSystem.defaultProfile()
		old.version = 42
		old.inventory = { { grade = "primordial", part = "gloves", dropStage = 50, itemLevel = 50, tierIndex = 6, locked = false }, { grade = "ancient", part = "armor", dropStage = 50, itemLevel = 50, tierIndex = 6, locked = false } }
		local anyClass = next(old.classes)
		old.classes[anyClass].equipment.shoes = { grade = "primordial", part = "shoes", dropStage = 40, itemLevel = 40, tierIndex = 6, locked = false }
		local migrated = SaveSystem.migrate(old)
		local bagP, bagA, eq = migrated.inventory[1], migrated.inventory[2], migrated.classes[anyClass].equipment.shoes
		r.check(("v42 → v%d · 옛 태초(가방 · 착용) = 이전 태초 + 잠금 · 고대는 그대로 · isValidProfile %s"):format(migrated.version, tostring(SaveSystem.isValidProfile(migrated))),
			migrated.version == 43 and bagP.primordial and bagP.primordial.legacy == true and bagP.locked == true and eq.primordial and eq.primordial.legacy == true and eq.locked == true
				and bagA.primordial == nil and bagA.locked == false and SaveSystem.isValidProfile(migrated))
		local bad = SaveSystem.migrate(SaveSystem.defaultProfile())
		bad.inventory = { { grade = "primordial", part = "armor", itemLevel = 1, tierIndex = 1, locked = true, primordial = "숫자" } }
		r.check("각인이 표가 아니면 isValidProfile 거절", not SaveSystem.isValidProfile(bad))
	end)

	local pass, total = r.summary()
	print(("===D1 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===D1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local Registry = require(script.Parent.PrimordialRegistry)
	local HallOfFame = require(script.Parent.HallOfFame)
	local hook = game:GetService("ServerStorage"):FindFirstChild("DevCommandHook")

	r.section("세계 번호 카운터 동시성(시험 키)", function()
		local results, done = {}, 0
		local N = 20
		for i = 1, N do
			task.spawn(function()
				results[i] = Registry.nextNumber(true)
				done += 1
			end)
		end
		local t0 = os.clock()
		while done < N and os.clock() - t0 < 60 do
			task.wait(0.1)
		end
		local seen, dup, minNo, maxNo, missing = {}, 0, math.huge, -math.huge, 0
		for i = 1, N do
			local no = results[i]
			if not no then
				missing += 1
			elseif seen[no] then
				dup += 1
			else
				seen[no] = true
				minNo, maxNo = math.min(minNo, no), math.max(maxNo, no)
			end
		end
		r.check(("동시 %d요청(같은 서버 스레드 %d개 - UpdateAsync) → 발급 %d · 중복 %d · 실패 %d · 연속 %s(%s ~ %s)"):format(N, N, N - missing, dup, missing,
			tostring(maxNo - minNo + 1 == N - missing), tostring(minNo), tostring(maxNo)), dup == 0 and missing == 0 and maxNo - minNo + 1 == N)
		r.check(("키 = %s(Studio는 항상 시험 키 - 실제 세계 번호 불변)"):format(Registry.keyFor(PrimordialData.counterKey, false)), Registry.keyFor(PrimordialData.counterKey, false):sub(1, #PrimordialData.testKeyPrefix) == PrimordialData.testKeyPrefix)
	end)

	r.section("드랍 경로 · 각인 · 명예의 전당 복원", function()
		local before = #PlayerProfile.getProfile(player).inventory
		local titlesBefore = PlayerProfile.hasTitle(player, PrimordialData.titleId)
		hook:Invoke(player, "/gg drop force primordial gloves")
		local profile = PlayerProfile.getProfile(player)
		local item = profile.inventory[#profile.inventory]
		local stamp = item and item.primordial
		local t0 = os.clock()
		while stamp and stamp.pending and os.clock() - t0 < 15 do -- 번호는 비동기(리뷰 2)
			task.wait(0.1)
		end
		r.check(("태초 가방 %d → %d · 각인 번호 %s · 최초 %s · 출처 %s · 잠금 %s · 칭호 %s(전 %s) · 흰 빛기둥 %s"):format(before, #profile.inventory, tostring(stamp and stamp.no),
			tostring(stamp and stamp.ownerName), tostring(stamp and stamp.source and stamp.source.kind), tostring(item and item.locked), tostring(PlayerProfile.hasTitle(player, PrimordialData.titleId)),
			tostring(titlesBefore), tostring(workspace:FindFirstChild("PrimordialBeacon") ~= nil)),
			item and item.grade == "primordial" and stamp and type(stamp.no) == "number" and stamp.ownerId == player.UserId and item.source and item.source.kind == "dev"
				and item.locked == true and PlayerProfile.hasTitle(player, PrimordialData.titleId) and workspace:FindFirstChild("PrimordialBeacon") ~= nil)
		task.wait(4) -- 원본 기록(비동기 UpdateAsync) 기다림
		HallOfFame.debugForget()
		local empty = #HallOfFame.shownNumbers()
		local readOk = HallOfFame.refresh()
		local shown = HallOfFame.shownNumbers()
		r.check(("알림 누락 흉내(석판 비움 %d건) → 원본 다시 읽기 %s → 첫 줄 #%s(방금 번호 %s) · %d건"):format(empty, tostring(readOk), tostring(shown[1]), tostring(stamp and stamp.no), #shown),
			empty == 0 and readOk and stamp and table.find(shown, stamp.no) ~= nil)
		-- 착용 표시
		local index = #profile.inventory
		PlayerProfile.equipItem(player, index)
		task.wait(0.2)
		r.check(("태초 장갑 착용 → Attribute PrimordialEquipped = %s"):format(tostring(player:GetAttribute("PrimordialEquipped"))), player:GetAttribute("PrimordialEquipped") == true)
		-- 고대: 같은 서버 알림 · 태초 기록 안 함
		local claimsBefore = Registry.stats().claims
		hook:Invoke(player, "/gg drop force ancient armor ground")
		r.check(("고대 드랍 → 세계 번호 발급 없음(발급 수 %d → %d)"):format(claimsBefore, Registry.stats().claims), Registry.stats().claims == claimsBefore)
		local pillarOk = true
		for _, grade in ipairs(ArmorData.gradeOrder) do
			local model = require(script.Parent.ItemDropSpawner).spawn({ grade = grade, part = "shoes", itemLevel = 1, dropStage = 1, tierIndex = 1, locked = false },
				(player.Character and player.Character.HumanoidRootPart.Position or Vector3.zero) + Vector3.new(0, 0, 20), player)
			local lightOk = true
			local root = model.PrimaryPart
			local light = root and root:FindFirstChildOfClass("PointLight")
			if grade == "normal" then
				lightOk = light == nil and model.DropRing.Material == Enum.Material.SmoothPlastic -- 일반 = 회색 · 빛 없음
			end
			pillarOk = pillarOk and model:GetAttribute("BoltHeight") == PrimordialData.pillarHeights[grade] and model:FindFirstChild("DropRing") ~= nil
				and typeof(model:GetAttribute("BoltGround")) == "Vector3" and root.Color == PrimordialData.silhouetteColor and lightOk
			require(script.Parent.ItemDropSpawner).despawn(model)
		end
		r.check("드랍 번개 7단계 높이 = 0 · 0 · 6 · 13 · 18 · 23 · 30(클라 번개 자리) · 바닥 원 · 본체 = 어두운 실루엣 · 일반 = 회색 · 빛 없음", pillarOk)
	end)

	r.section("잠금 · 각성", function()
		local profile = PlayerProfile.getProfile(player)
		PlayerProfile.unequipItem(player, "gloves")
		local index
		for i, item in ipairs(profile.inventory) do
			if item.grade == "primordial" and item.primordial and item.primordial.no then
				index = i
			end
		end
		assert(index, "시험 태초 없음")
		local sold, sellReason = PlayerProfile.sellItem(player, index)
		local dis, disReason = PlayerProfile.dismantleItem(player, index)
		local unlockPlain = PlayerProfile.setItemLocked(player, index, false)
		r.check(("잠긴 태초: 판매 %s(%s) · 분해 %s(%s) · 이중 확인 없는 해제 %s → 여전히 잠김 %s"):format(tostring(sold), tostring(sellReason), tostring(dis), tostring(disReason), tostring(unlockPlain),
			tostring(profile.inventory[index].locked)), not sold and sellReason == "locked" and not dis and disReason == "locked" and not unlockPlain and profile.inventory[index].locked == true)
		local unlockConfirmed = PlayerProfile.setItemLocked(player, index, false, PlayerProfile.PRIMORDIAL_UNLOCK_TOKEN)
		local unlockedNow = profile.inventory[index].locked == false
		PlayerProfile.setItemLocked(player, index, true)
		r.check(("이중 확인 표식 있는 해제 → %s · 다시 잠금 %s"):format(tostring(unlockConfirmed and unlockedNow), tostring(profile.inventory[index].locked)), unlockConfirmed and unlockedNow and profile.inventory[index].locked == true)
		-- 각성
		local best = PlayerProfile.getAccountBestStage(player)
		profile.inventory[index].itemLevel = math.max(1, best - 30)
		local cost = Awaken.cost(best)
		PlayerProfile.addGold(player, cost * 2 - PlayerProfile.getGold(player))
		local goldBefore = PlayerProfile.getGold(player)
		local ok, value = PlayerProfile.awakenItem(player, "bag", index)
		local spent = goldBefore - PlayerProfile.getGold(player)
		local ok2, reason2 = PlayerProfile.awakenItem(player, "bag", index)
		r.check(("각성(최고 %d) → %s · itemLevel %d · 쓴 골드 %d(= 비용 %d) · 다시 → %s"):format(best, tostring(ok), profile.inventory[index].itemLevel, spent, cost, tostring(reason2)),
			ok and value == best and profile.inventory[index].itemLevel == best and spent == cost and not ok2 and reason2 == "already_max")
		profile.inventory[index].itemLevel = math.max(1, best - 30)
		PlayerProfile.addGold(player, -PlayerProfile.getGold(player))
		local ok3, reason3 = PlayerProfile.awakenItem(player, "bag", index)
		PlayerProfile.addArmorDrop(player, { grade = "ancient", part = "armor", itemLevel = 1, dropStage = 1, tierIndex = 6, locked = false }, { noAutoProcess = true })
		local ancientIndex
		for i, item in ipairs(profile.inventory) do
			if item.grade == "ancient" then
				ancientIndex = i
			end
		end
		local ok4, reason4
		if ancientIndex then
			ok4, reason4 = PlayerProfile.awakenItem(player, "bag", ancientIndex)
		end
		r.check(("골드 0 → %s(%s) · 레벨 그대로 %s · 고대 → %s(%s)"):format(tostring(ok3), tostring(reason3), tostring(profile.inventory[index].itemLevel == math.max(1, best - 30)), tostring(ok4), tostring(reason4)),
			not ok3 and reason3 == "no_gold" and profile.inventory[index].itemLevel == math.max(1, best - 30) and ancientIndex ~= nil and not ok4 and reason4 == "not_primordial")
	end)

	env.restore(player) -- 시험 태초 · 고대 · 칭호 · 골드를 원본으로(체인 끝 가방 검사 S04)
	local pass, total = r.summary()
	print(("===D1 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
