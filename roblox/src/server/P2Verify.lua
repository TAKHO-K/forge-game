-- P2 자동 검증 - 경제 · 성장 · 보석 · 태초 · 치유사 · 파티 경험치(docs/phase/P2-log.md). DevTools.server.lua가 부른다.
--   (가) runPure = 순수 함수 · 합성 데이터(서버 시작 때, 플레이어 없이): 환생표 · GoldCost · 상대 정밀도 · NumberFormat · 보석 곡선 · 드랍표 · 치유사 · 파티 조건.
--   (나) runLive = 실제 Player(보스 검증 체인의 끝): 파티 경험치 조건의 배선(PlayerProfile.getExpGainMultiplier) · 실제 처치 경로의 태초 드랍(itemLevel = 사냥 스테이지) ·
--        조회 API(DropTableQuery.forPlayer) = 서버 굴림과 같은 확률. 검증이 바꾼 것(파티 · 스탠드인 · 드랍표 칸 · 스테이지 · 몬스터 · 땅의 드랍)은 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Option = require(ReplicatedStorage.Shared.Option)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local PartyState = require(script.Parent.PartyState)
local PartyExpBonus = require(script.Parent.PartyExpBonus)
local PlayerProfile = require(script.Parent.PlayerProfile)
local DropTableQuery = require(script.Parent.DropTableQuery)

local P2Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

local function near(a, b, tolerance)
	return math.abs(a - b) <= (tolerance or 1e-9) * math.max(1, math.abs(b))
end

local function isFinite(value)
	return value == value and math.abs(value) < math.huge
end

-- P2 전 MonsterData 표(tier 공정성 r(t)의 입력) - 드랍표를 DropTableData로 옮긴 뒤에도 몬스터 수치가 한 자리도 안 바뀌었는지 대조한다.
local OLD_GRADE_TABLE = {
	{ normal = 0.90, rare = 0.10 },
	{ normal = 0.70, rare = 0.27, epic = 0.03 },
	{ normal = 0.45, rare = 0.40, epic = 0.14, legendary = 0.01 },
	{ normal = 0.20, rare = 0.40, epic = 0.30, legendary = 0.09, relic = 0.01 },
	{ normal = 0.05, rare = 0.25, epic = 0.40, legendary = 0.25, relic = 0.045, ancient = 0.005 },
	{ rare = 0.10, epic = 0.30, legendary = 0.40, relic = 0.18, ancient = 0.019, primordial = 0.001 },
}

local function oldRewardRatio(tierIndex)
	local function expected(row)
		local sum = 0
		for gradeId, chance in pairs(row) do
			sum += chance * ArmorData.grades[gradeId].fairnessMultiplier -- D1: 공정성 입력 = 옛 배율 고정(갑옷 배율 defenseGradeMultiplier는 D1 위력표)
		end
		return sum
	end
	return expected(OLD_GRADE_TABLE[tierIndex]) / expected(OLD_GRADE_TABLE[1])
end

-- NumberFormat 표본(값, 기대 문자열) - 1e15 미만은 P2 전 출력 그대로, 알파벳 구간은 부동소수 결함을 고친 값.
-- P2.5a: 이 블록의 값 검사 중 P2.5a가 바꾼 것(환생표 · 강화 비용 기준 · 보석 p · 태초 tier 배수 · 감쇠 · 딜링모드 배율)은 새 값을 기대한다(근거 = docs/phase/P25a-log.md).
local NUMBER_SAMPLES = {
	{ 7, "7" }, { 9999, "9,999" }, { 10000, "10K" }, { 12345, "12.3K" }, { 999999, "999.9K" }, { 1234567, "1.2M" }, { 9.99e8, "999M" }, { 1e9, "1B" },
	{ 2.5e11, "250B" }, { 1e12, "1T" }, { 999.99e12, "999.9T" }, { 1e15, "1aa" }, { 1.5e18, "1.5ab" }, { 3.3e33, "3.3ag" }, { 1e45, "1ak" }, { 1e60, "1ap" },
	{ 1e100, "10bc" }, { 7.7e245, "770cy" }, { 1e300, "1dr" }, { 1e308, "100dt" }, { 1.7976931348623157e308, "179.7dt" },
}

function P2Verify.runPure()
	print("===P2 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("[B] 환생 필요 레벨표", function()
		local expected = { 25, 50, 75, 100, 125 } -- P2.5c 결정 3(옛 P2.5a 78 · 155 · 202 · 248 · 279 · P2 25 · 50 · 65 · 80 · 90)
		local ok = true
		local got = {}
		for count = 0, 4 do
			got[count + 1] = CharacterLevel.getRebirthRequiredLevel(count)
			ok = ok and got[count + 1] == expected[count + 1]
		end
		r.check(("B1 환생 0 ~ 4회 → 필요 레벨 %s(기대 25 · 50 · 75 · 100 · 125 - P2.5c) · 5회(최대) → %s(기대 nil) · 최대 회차 %d(기대 5)"):format(
			table.concat(got, " · "), tostring(CharacterLevel.getRebirthRequiredLevel(5)), GemData.maxRebirthCount),
			ok and CharacterLevel.getRebirthRequiredLevel(5) == nil and GemData.maxRebirthCount == 5)
	end)

	r.section("[C1] GoldCost", function()
		-- P2.5a C8: 강화 비용 기준 스테이지 100 → 1 · 배수는 골드 성장률(InfiniteStage.getGoldMultiplier) - 최고 1 · 없음은 표 그대로, 그 위는 표 × 골드 배수.
		local ok = true
		for level = 0, EnhanceConfig.maxLevel - 1 do
			ok = ok and Enhance.getCost(level, 1) == EnhanceConfig.goldCost[level + 1] and Enhance.getCost(level) == EnhanceConfig.goldCost[level + 1]
			for _, stage in ipairs({ 50, 100 }) do
				ok = ok and Enhance.getCost(level, stage) == math.floor(EnhanceConfig.goldCost[level + 1] * InfiniteStage.getGoldMultiplier(stage))
			end
		end
		r.check(("C1.1 강화 0 ~ %d강 × 계정 최고 1 · 없음 = 표 그대로 · 50 · 100 = 표 × 골드 배수(P2.5a 기준 1) %s"):format(EnhanceConfig.maxLevel - 1, tostring(ok)), ok)
		local at101, at500 = Enhance.getCost(19, 101), Enhance.getCost(19, 500)
		-- P2.5c 결정 4: 19강 1회 표 값은 EnhanceConfig에서 읽는다(옛 235,000 → 18,500).
		local cost19 = EnhanceConfig.goldCost[20]
		local expected101, expected500 = math.floor(cost19 * InfiniteStage.getGoldMultiplier(101)), math.floor(cost19 * InfiniteStage.getGoldMultiplier(500))
		r.check(("C1.2 19강 최고 101 = %.0f(기대 floor(%d × 골드 배수) = %.0f) · 500 = %.4g(기대 %.4g)"):format(at101, cost19, expected101, at500, expected500),
			at101 == expected101 and near(at500, expected500, 1e-12))
		local same = true
		for _, stage in ipairs({ 1, 50, 83, 250, 1000, 4738 }) do
			local perKill = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage)
			same = same and Enhance.getProtectionPrice("drop", stage) == perKill * EnhanceConfig.protection.drop.priceKillEquivalent
				and Enhance.getProtectionPrice("reset", stage) == perKill * EnhanceConfig.protection.reset.priceKillEquivalent
				and GoldCost.cost(MonsterData.tier1.goldDrop, stage, "rerollTicket") * GemData.rerollTicketGoldMultiplier == perKill * GemData.rerollTicketGoldMultiplier
		end
		r.check(("C1.3 방지권 2종 · 변환권 가격(최고 1 · 50 · 83 · 250 · 1000 · 4738) = P2 전 식(잡몹 1마리 골드 × 배수)과 같다 %s"):format(tostring(same)), same)
		local ratioOk = true
		for _, stage in ipairs({ 150, 800, 2500, 4000 }) do
			-- P2.5c: 20강 1회가 766,000 → 20,000이라 floor(정수 골드)의 상대 오차가 1e-6을 넘는다 - 허용치 = 1원 ÷ 비용.
			-- P3c C1: +20 이상은 천장 구간(레벨 2,500 ~ 4,500 척도)에서 보정 배수가 곱해져 이 비가 골드 증가율과 달라진다(의도) - 보정이 없는 +19 → +20 1회로 잰다.
			ratioOk = ratioOk and near(Enhance.getCost(19, stage + 1) / Enhance.getCost(19, stage), InfiniteStage.getGoldReward(1e6, stage + 1) / InfiniteStage.getGoldReward(1e6, stage), 2 / Enhance.getCost(19, stage))
		end
		local top = Enhance.getCost(24, 4738)
		r.check(("C1.4 한 스테이지당 비용 증가율 = 잡몹 골드 증가율(P2.5a 골드 성장률) %s · 24강 최고 4738 = %.3g(유한 %s)"):format(tostring(ratioOk), top, tostring(isFinite(top))), ratioOk and isFinite(top))
		local bad = GoldCost.cost(100, 0 / 0, "enhance")
		r.check(("C1.5 스테이지 NaN → 비용 %s(기대 math.huge - Sanitize가 끊어 공짜로 새지 않는다)"):format(tostring(bad)), bad == math.huge)
	end)

	r.section("[C2] 골드 상대 정밀도", function()
		local balance, gain = 9.58e250, 1.08e245
		local after = balance + gain
		r.check(("C2 보유 %.3g + 처치 %.3g(상대 %.2g) → 증가분 %.4g(기대 %.4g ± 1e-9 상대) - double 상대 정밀도 2^-53 = %.2g"):format(balance, gain, gain / balance, after - balance, gain, 2 ^ -53),
			after > balance and near(after - balance, gain, 1e-9))
	end)

	r.section("[C3] NumberFormat 표본", function()
		local wrong = {}
		for _, sample in ipairs(NUMBER_SAMPLES) do
			local text = NumberFormat.format(sample[1])
			if text ~= sample[2] then
				table.insert(wrong, ("%.6g → %s(기대 %s)"):format(sample[1], text, sample[2]))
			end
		end
		r.check(("C3.1 표본 %d개(1e15 미만 = P2 전 그대로 · 알파벳 구간 = 결함 고친 값) - 어긋남 %d%s"):format(#NUMBER_SAMPLES, #wrong, #wrong > 0 and (": " .. table.concat(wrong, " / ")) or ""), #wrong == 0)
		local bad = 0
		for e = 15, 308 do
			for _, m in ipairs({ 1, 2, 5, 9.99 }) do
				local value = m * 10 ^ e
				if value < math.huge then
					local lead = tonumber(NumberFormat.format(value):match("^[%d%.]+"))
					if not lead or math.abs(lead - math.floor(m * 10 ^ (e % 3) * 10 + 1e-6) / 10) > 1e-9 then
						bad += 1
					end
				end
			end
		end
		r.check(("C3.2 알파벳 구간 경계 10^15 ~ 10^308의 1 · 2 · 5 · 9.99배: 앞자리 틀림 %d개(기대 0)"):format(bad), bad == 0)
	end)

	r.section("[D] 보석 곡선", function()
		local f125 = (1 + 0.06 * 124) / (1 + 0.06 * 99)
		local p = OptionData.levelLogSlope
		local oldOk = true
		for level = 1, 125 do
			oldOk = oldOk and near(Option.levelFactor(level), (1 + 0.06 * (level - 1)) / (1 + 0.06 * 99), 1e-12)
		end
		r.check(("D1.1 레벨 1 ~ 125 = P2 전 식 그대로 %s · p = %.3f(기대 0.025 - P2.5a C10)"):format(tostring(oldOk), p), oldOk and p == 0.025)
		r.check(("D1.2 f(250) = %.6f(기대 f(125) × (1 + p) = %.6f) · f(4738) = %.6f(기대 f(125) × (1 + p × log2(4738/125)) = %.6f)"):format(
			Option.levelFactor(250), f125 * (1 + p), Option.levelFactor(4738), f125 * (1 + p * math.log(4738 / 125, 2))),
			near(Option.levelFactor(250), f125 * (1 + p), 1e-12) and near(Option.levelFactor(4738), f125 * (1 + p * math.log(4738 / 125, 2)), 1e-12))
		local bad, prev = 0, 0
		for level = 1, 4738 do
			local f = Option.levelFactor(level)
			if not isFinite(f) or f < prev then
				bad += 1
			end
			prev = f
			if level % 7 == 0 or level == 4738 then
				for id in pairs(OptionData.options) do
					for _, gradeId in ipairs(ArmorData.gradeOrder) do
						local value = Option.valueOf({ id = id, roll = OptionData.rollMax, roll2 = OptionData.rollMax }, gradeId, level, OptionData.options[id].classId)
						local values = type(value) == "table" and { value.critRate, value.critDmg } or { value }
						for _, x in ipairs(values) do
							if not isFinite(x) then
								bad += 1
							end
						end
					end
				end
			end
		end
		r.check(("D2 레벨 1 ~ 4738 levelFactor 단조 · 유한 + 옵션 16종 × 등급 7종 × 최대 롤 값 유한: 틀림 %d(기대 0)"):format(bad), bad == 0)
	end)

	r.section("[E] 드랍표 단일 소스 · 태초", function()
		local divisors = { 1.30, 1.20, 1.08, 1 / 0.94, 1 / 0.97, 1 } -- P2.5c 결정 7(드래곤 최고 - tier4 · 5 = ×0.94 · ×0.97) · P2.5a C9 0.85 · 0.64 · 옛 1.9 · 1.7 · 1.35 · 1.1 · 1.05
		local ok = true
		local cells = {}
		for tier = 1, 6 do
			local rate = DropTable.primordialBaseRate(tier)
			cells[tier] = ("%.5f%%"):format(rate * 100)
			ok = ok and near(rate, DropTableData.primordial.dragonRate / divisors[tier], 1e-18) -- D1: dragonRate 0.001 → 0.000001(비율 구조 그대로)
		end
		r.check(("E2 tier1 ~ 6 태초 기본 확률 %s(기대 dragonRate(D1 0.0001%%) ÷ 1.30 · 1.20 · 1.08 · 1/0.94 · 1/0.97 · 1 - P2.5c)"):format(table.concat(cells, " · ")), ok)
		local decays = {}
		-- P2.5a C9: 시작 70 · 1칸당 1.4%(옛 5 · 10%)
		local expectedDecay = { [0] = 1, [69] = 1, [70] = 0.986, [100] = 0.566, [140] = 0.006, [141] = 0, [200] = 0 }
		local decayOk = true
		for gap, expected in pairs(expectedDecay) do
			local value = DropTable.levelDecay(100 + gap, 100)
			table.insert(decays, ("격차 %d → %.2f"):format(gap, value))
			decayOk = decayOk and near(value, expected, 1e-12)
		end
		table.sort(decays)
		r.check(("E3 레벨 감쇠 %s(기대 70 미만 1 · 70부터 한 칸마다 −1.4%% · 0 아래 없음 - P2.5a) · 최고 없음 = %.2f(기대 1)"):format(table.concat(decays, ", "), DropTable.levelDecay(nil, 50)),
			decayOk and DropTable.levelDecay(nil, 50) == 1)
		local eff = DropTable.effectiveRate({ bestStage = 200 }, { tierIndex = 1 }, 111)
		r.check(("E3.2 effectiveRate(최고 200 · tier1 · 사냥 111 - 격차 89) = %.6f%%(기대 기본 × 0.72 = %.6f%%)"):format(eff * 100, DropTable.primordialBaseRate(1) * 0.72 * 100), near(eff, DropTable.primordialBaseRate(1) * 0.72, 1e-9))
		local sumOk = true
		for tier = 1, 6 do
			for _, rate in ipairs({ DropTable.primordialBaseRate(tier), 0, 0.3 }) do
				local sum = 0
				for _, chance in pairs(DropTable.gradeRow(tier, rate)) do
					sum += chance
				end
				sumOk = sumOk and near(sum, 1, 1e-12)
			end
		end
		local tier6Same = true
		for gradeId, chance in pairs(DropTableData.armorGradeByTier[6]) do -- D1: tier6 기본 표 = D1 표(옛 = OLD_GRADE_TABLE)
			tier6Same = tier6Same and near(DropTable.gradeChance(6, gradeId), chance, 1e-12)
		end
		r.check(("E1.1 등급 분포 합 = 1(tier 6종 × 태초 확률 3종) %s · tier6 감쇠 없음 = 기본 표(D1)와 같다 %s"):format(tostring(sumOk), tostring(tier6Same)), sumOk and tier6Same)
		local fairOk = true
		for tier = 1, 6 do
			fairOk = fairOk and MonsterData.getRewardRatio(tier) == oldRewardRatio(tier)
		end
		r.check(("E1.2 tier 공정성 r(t)(몬스터 HP · 골드 · 경험치의 입력) = P2 전 표로 계산한 값과 비트까지 같다 %s · tier6 HP %.4f"):format(tostring(fairOk), MonsterData.tier6.hp), fairOk)
		local all = Loot.rollArmorDrop(37, 1, 400, "bow", 1)
		local allPrimordial = #all > 0
		for _, item in ipairs(all) do
			allPrimordial = allPrimordial and item.grade == "primordial" and item.itemLevel == 37 and item.dropStage == 37
		end
		local none = Loot.rollArmorDrop(37, 6, 400, "bow", 0)
		local nonePrimordial = #none > 0
		for _, item in ipairs(none) do
			nonePrimordial = nonePrimordial and item.grade ~= "primordial"
		end
		r.check(("E4 태초 확률 1 → %d개 전부 태초 · itemLevel = 사냥 스테이지 37(편차 없음) %s · 확률 0(tier6) → %d개 중 태초 0 %s"):format(#all, tostring(allPrimordial), #none, tostring(nonePrimordial)),
			allPrimordial and nonePrimordial)
		local hits, total = 0, 0
		for _ = 1, 40 do
			for _, item in ipairs(Loot.rollArmorDrop(20, 3, 400, "bow", 0.25)) do
				total += 1
				hits += item.grade == "primordial" and 1 or 0
			end
		end
		local sigma = math.sqrt(total * 0.25 * 0.75)
		r.check(("E1.3 태초 확률 0.25 굴림: %d / %d = %.4f(기대 0.25 ± 4σ = ±%.4f)"):format(hits, total, hits / total, 4 * sigma / total), math.abs(hits - total * 0.25) <= 4 * sigma)
		local relicPrice = Loot.getSellPrice({ grade = "relic", tierIndex = 6, dropStage = 80 })
		local expectedRelic = math.floor(1 / (ArmorData.dropChance * 0.18) * InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 80) * ArmorData.sellRecoveryRate)
		local primPrice = Loot.getSellPrice({ grade = "primordial", tierIndex = 1, dropStage = 80 })
		local oldSame = true
		for tier = 1, 5 do
			for gradeId, chance in pairs(OLD_GRADE_TABLE[tier]) do
				local expected = math.floor(1 / (ArmorData.dropChance * chance) * InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 300) * ArmorData.sellRecoveryRate)
				oldSame = oldSame and Loot.getSellPrice({ grade = gradeId, tierIndex = tier, dropStage = 300 }) == expected
			end
		end
		r.check(("E1.4b tier1 ~ 5 기존 등급 판매가(스테이지 300) = P2 전 식과 한 자리도 같다 %s(리뷰 지적 1)"):format(tostring(oldSame)), oldSame)
		r.check(("E1.4 판매가: tier6 유물 %d(기대 P2 전 식 %d) · tier1 태초 %d(기대 > 0 - 전에는 표에 없어 0)"):format(relicPrice, expectedRelic, primPrice), relicPrice == expectedRelic and primPrice > 0)
		local described = DropTableQuery.describe({ bestStage = 100 }, 3, 90, 1)
		local gradeSum = 0
		for _, entry in ipairs(described.grades) do
			gradeSum += entry.chance
		end
		r.check(("E1.5 조회 API describe(최고 100 · tier3 · 사냥 90): 태초 %.6f%%(기대 effectiveRate %.6f%%) · 등급 합 %.12f · 재료 %d종 · 장비/처치 %.4f(기대 Loot.expectedArmorDropCount)"):format(
			described.primordial.effectiveRate * 100, DropTable.effectiveRate({ bestStage = 100 }, { tierIndex = 3 }, 90) * 100, gradeSum, #described.materials, described.armorPerKill),
			described.primordial.effectiveRate == DropTable.effectiveRate({ bestStage = 100 }, { tierIndex = 3 }, 90) and near(gradeSum, 1, 1e-12) and described.armorPerKill == Loot.expectedArmorDropCount(3, 1))
	end)

	r.section("[F] 치유사", function()
		local weapon = { id = WeaponData.starterId, level = 0, grade = 0 }
		local base = PlayerCombat.getAttack(weapon, "healer", 100, 0)
		local boosted = PlayerCombat.getAttack(weapon, "healer", 100, 0.5)
		local cooldown, fast = PlayerCombat.getAttackCooldown("healer", 0, 1), PlayerCombat.getAttackCooldown("healer", 0.3, 1)
		local crits = 0
		for _ = 1, 200 do
			local _, isCrit = PlayerCombat.calcDamage(100, "healer", 1, false, 0)
			crits += isCrit and 1 or 0
		end
		r.check(("F1 치유사 평타 식의 옵션 자리(모드 무관 - AttackServer가 그대로 넘긴다): 위력 +50%% → atk ×%.4f(기대 1.5) · 신속 +30%% → 쿨다운 %.3f → %.3f(줄어듦) · 치명 +100%% → 200번 중 치명 %d(기대 200)"):format(
			boosted / base, cooldown, fast, crits), near(boosted / base, 1.5, 1e-12) and fast < cooldown and crits == 200)
		r.check(("F2 · F3 데이터: ClassData.healer.atk %.3f(기대 0.66) · SkillData.healer.E.attackMultiplier %.3f(기대 1.574 - P2.5a 평균 투자 기준)"):format(ClassData.classes.healer.atk, SkillData.healer.E.attackMultiplier),
			ClassData.classes.healer.atk == 0.66 and SkillData.healer.E.attackMultiplier == 1.574)
		local EconSim = require(script.Parent.EconSim)
		if EconSim.isAllowed() then
			local healer = require(script.Parent.EconSimTables).healer()
			local shares, okShare = {}, true
			for _, tier in ipairs(EconSimConfig.healer.gearTiers) do
				local share = healer.tiers[tier.id].share.dualblade
				table.insert(shares, ("%.2f%%"):format(share * 100))
				okShare = okShare and share >= EconSimConfig.healer.shareTarget
			end
			local rDealing = healer.tiers.average.rDealing
			r.check(("F2 도적 3 + 치유사 1 비중(없음 · 평균 · 상위) %s(기대 전부 ≥ 12%%) · F3 딜링모드 ÷ 검사(평균 투자 - P2.5a) %.4f(기대 0.85 ~ 0.9)"):format(table.concat(shares, " · "), rDealing),
				okShare and rDealing >= 0.85 and rDealing <= 0.9)
		else
			r.check("F2 · F3 EconSim이 꺼져 있어(DevToolsConfig.econSim) 비중 · 딜링모드 비를 못 잰다", false)
		end
	end)

	r.section("[G] 파티 경험치 조건(순수)", function()
		local condition = PartyConfig.expBonusCondition
		local now = 1000
		local zone = "zone:tier1"
		local here = { zone = zone, position = Vector3.new(0, 0, 0), lastActiveAt = now }
		local function member(zoneId, distance, secondsAgo)
			return { zone = zoneId, position = Vector3.new(distance, 0, 0), lastActiveAt = secondsAgo and (now - secondsAgo) or nil }
		end
		local boss, otherBoss = {}, {}
		local cases = {
			{ "같은 구역 · 10 · 5초 전", here, member(zone, 10, 5), true },
			{ "반경 경계 150", here, member(zone, condition.radiusStuds, 5), true },
			{ "반경 밖 151", here, member(zone, condition.radiusStuds + 1, 5), false },
			{ "다른 구역", here, member("zone:tier2", 10, 5), false },
			{ "활동 60초 전(경계)", here, member(zone, 10, condition.activeWithinSeconds), true },
			{ "활동 61초 전", here, member(zone, 10, condition.activeWithinSeconds + 1), false },
			{ "활동 기록 없음", here, member(zone, 10, nil), false },
			{ "받는 사람이 구역 밖", { zone = nil, position = Vector3.new(0, 0, 0) }, member(nil, 10, 5), false },
			{ "같은 보스 인스턴스", { zone = boss, position = Vector3.new(0, 0, 0) }, member(boss, 40, 5), true },
			{ "다른 보스 인스턴스", { zone = boss, position = Vector3.new(0, 0, 0) }, member(otherBoss, 40, 5), false },
		}
		local wrong = {}
		for _, case in ipairs(cases) do
			if PartyExpBonus.isEligible(case[2], case[3], now) ~= case[4] then
				table.insert(wrong, case[1])
			end
		end
		r.check(("G1 조건 판정 %d가지(구역 · 반경 %d · 활동 %d초 · 보스 인스턴스): 틀림 %d%s"):format(#cases, condition.radiusStuds, condition.activeWithinSeconds, #wrong,
			#wrong > 0 and (" - " .. table.concat(wrong, ", ")) or ""), #wrong == 0 and condition.radiusStuds == 150 and condition.activeWithinSeconds == 60)
		r.check(("G2 파티 없는 플레이어의 조건부 보너스 = %s(기대 0) · 인원표 2 · 3 · 4인 = %.2f · %.2f · %.2f(기대 0.10 · 0.15 · 0.20 그대로)"):format(tostring(PartyState.getExpBonusFor({})),
			PartyState.getExpBonusForCount(2), PartyState.getExpBonusForCount(3), PartyState.getExpBonusForCount(4)),
			PartyState.getExpBonusFor({}) == 0 and PartyState.getExpBonusForCount(2) == 0.10 and PartyState.getExpBonusForCount(3) == 0.15 and PartyState.getExpBonusForCount(4) == 0.20)
	end)

	local pass, total = r.summary()
	print(("===P2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ── (나) ──

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

local function modelSet(list)
	local set = {}
	for _, model in ipairs(list) do
		set[model] = true
	end
	return set
end

function P2Verify.runLive(player, env)
	print("===P2 검증 시작(나: 실제 Player · 실제 PartyState · 실제 처치 경로)===")
	local r = newRecorder("나")
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local MonsterState = require(script.Parent.MonsterState)
	local CombatResolution = require(script.Parent.CombatResolution)
	local ItemDropState = require(script.Parent.ItemDropState)
	local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
	local TutorialState = require(script.Parent.TutorialState)
	if not PlayerProfile.getProfile(player) or not rootOf(player) or PartyState.getParty(player) then
		r.check("프로필 · 캐릭터가 없거나 이미 파티에 있어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===P2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	env.ensureBackup(player) -- classes(스테이지 · 경험치 · 장비) · gold · 가방은 env.restore가 되돌린다
	local savedDivisors = DropTableData.primordial.dragonOverTier
	local monstersBefore, groundBefore = modelSet(MonsterState.getAllModels()), modelSet(ItemDropState.getAllModels())
	local B, C, D = standIn("P2StandB", -9701), standIn("P2StandC", -9702), standIn("P2StandD", -9703)

	r.section("[G] 조건부 파티 경험치 - 실제 PlayerProfile.getExpGainMultiplier", function()
		for _, member in ipairs({ B, C, D }) do
			PartyState.invite(player, member)
			PartyState.respondInvite(member, true)
		end
		local party = PartyState.getParty(player)
		local optionMultiplier = 1 + PlayerProfile.getOptionBonus(player, "expGain")
		local function bonusNow()
			return PlayerProfile.getExpGainMultiplier(player) / optionMultiplier - 1
		end
		local zone = "P2-verify-zone"
		PartyExpBonus.debugSetPresence(player, { zone = zone, position = Vector3.new(0, 0, 0) })
		PartyExpBonus.debugSetPresence(B, { zone = zone, position = Vector3.new(10, 0, 0) })
		PartyExpBonus.debugSetPresence(C, { zone = zone, position = Vector3.new(200, 0, 0) })
		PartyExpBonus.debugSetPresence(D, { zone = zone, position = Vector3.new(0, 0, 20) })
		PartyState.noteActivity(B)
		PartyState.noteActivity(C)
		PartyState.noteActivity(D, os.clock() - PartyConfig.expBonusCondition.activeWithinSeconds - 1)
		local steps = {}
		local function step(label, expected)
			local value = bonusNow()
			table.insert(steps, { label = label, value = value, expected = expected })
		end
		step("B만(C 반경 밖 200 · D 61초 전)", 0.10)
		PartyExpBonus.debugSetPresence(C, { zone = zone, position = Vector3.new(149, 0, 0) })
		step("C 반경 안 149", 0.15)
		PartyState.noteActivity(D)
		step("D 방금 활동", 0.20)
		PartyExpBonus.debugSetPresence(B, { zone = "P2-other-zone", position = Vector3.new(10, 0, 0) })
		step("B 다른 구역", 0.15)
		PartyExpBonus.debugSetPresence(player, { zone = nil, position = Vector3.new(0, 0, 0) })
		step("받는 사람이 사냥 구역 밖", 0)
		local cells, ok = {}, PartyState.getSize(party) == 4
		for _, entry in ipairs(steps) do
			table.insert(cells, ("%s %.2f(기대 %.2f)"):format(entry.label, entry.value, entry.expected))
			ok = ok and near(entry.value, entry.expected, 1e-9)
		end
		r.check(("G 4인 파티(스탠드인 3) · 인원표 potential %.2f: %s ★진짜 합격 기준"):format(PartyState.getExpBonus(party), table.concat(cells, " · ")), ok and near(PartyState.getExpBonus(party), 0.20))
		for _, member in ipairs({ player, B, C, D }) do
			PartyExpBonus.debugSetPresence(member, nil)
		end
		for _, member in ipairs({ D, C, B }) do
			PartyState.leave(member, "leave")
		end
		if PartyState.getParty(player) then
			PartyState.leave(player, "leave")
		end
	end)

	r.section("[E] 실제 처치 경로의 태초 드랍 · 조회 API", function()
		local best = PlayerProfile.getInfiniteStageBest(player) or 1
		env.applyStage(player, best) -- 사냥 스테이지 = 최고(감쇠 없음)
		local stage = TutorialState.getMonsterStage(player)
		local query = DropTableQuery.forPlayer(player, 1)
		local expectedRate = DropTable.effectiveRate({ bestStage = PlayerProfile.getInfiniteStageBest(player) }, { tierIndex = 1 }, stage)
		r.check(("E1 조회 API(실제 Player · tier1): 사냥 %d · 최고 %s · 태초 %.6f%%(기대 서버 굴림과 같은 effectiveRate %.6f%%) · 감쇠 %.2f"):format(
			stage, tostring(query and query.bestStage), (query and query.primordial.effectiveRate or -1) * 100, expectedRate * 100, query and query.primordial.levelDecay or -1),
			query ~= nil and query.primordial.effectiveRate == expectedRate and query.huntStage == stage)
		-- 태초 확률을 1로(드래곤 확률 0.1% ÷ 0.001) 잠깐 바꾸고 tier1을 실제 경로로 잡는다 - 장비가 나올 때까지(기대 개수 0.25/마리) 최대 60마리.
		DropTableData.primordial.dragonOverTier = { DropTableData.primordial.dragonRate, 1.7, 1.35, 1.1, 1.05, 1 }
		local drops = {}
		local spot = WorldConfig.zones[WorldConfig.tierZoneOrder[1]].center + Vector3.new(0, 5, 0)
		for _ = 1, 60 do
			local seen = modelSet(ItemDropState.getAllModels())
			local model = MonsterSpawner.spawn(MonsterData.tier1, spot, nil, {})
			local isDead = MonsterState.applyDamage(model, 1e300, stage, player)
			CombatResolution.resolveHit(player, model, isDead)
			for _, dropModel in ipairs(ItemDropState.getAllModels()) do
				if not seen[dropModel] and ItemDropState.getOwnerId(dropModel) == player.UserId then
					table.insert(drops, ItemDropState.getItem(dropModel))
				end
			end
			if #drops > 0 then
				break
			end
		end
		DropTableData.primordial.dragonOverTier = savedDivisors
		local ok = #drops > 0
		local cells = {}
		for _, item in ipairs(drops) do
			table.insert(cells, ("%s itemLevel %s"):format(tostring(item.grade), tostring(item.itemLevel)))
			ok = ok and item.grade == "primordial" and item.itemLevel == stage
		end
		r.check(("E4 실제 처치(CombatResolution → Loot, 태초 확률 1로 덮어씀): 드랍 %d개 [%s](기대 전부 태초 · itemLevel = 사냥 스테이지 %d) ★진짜 합격 기준"):format(#drops, table.concat(cells, ", "), stage), ok)
	end)

	-- 되돌리기
	DropTableData.primordial.dragonOverTier = savedDivisors
	for _, member in ipairs({ player, B, C, D }) do
		PartyExpBonus.debugSetPresence(member, nil)
	end
	if PartyState.getParty(player) then
		PartyState.leave(player, "leave")
	end
	env.restore(player)
	local leftoverMonsters, leftoverGround = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		if not monstersBefore[model] then
			MonsterState.clear(model)
			if model.Parent then
				model:Destroy()
			end
			leftoverMonsters += 1
		end
	end
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not groundBefore[model] and model.Parent then
			ItemDropSpawner.despawn(model)
			leftoverGround += 1
		end
	end
	r.check(("검증 뒤 되돌림: 파티 %s(기대 nil) · 스탠드인 파티 %s %s %s · 드랍표 칸 복원 %s · 치운 몬스터 %d · 치운 땅의 드랍 %d(검증이 만든 것 - 치운 뒤 남은 것 0)"):format(
		tostring(PartyState.getParty(player)), tostring(PartyState.getParty(B)), tostring(PartyState.getParty(C)), tostring(PartyState.getParty(D)),
		tostring(DropTableData.primordial.dragonOverTier == savedDivisors), leftoverMonsters, leftoverGround),
		PartyState.getParty(player) == nil and PartyState.getParty(B) == nil and PartyState.getParty(C) == nil and PartyState.getParty(D) == nil
			and DropTableData.primordial.dragonOverTier == savedDivisors)

	local pass, total = r.summary()
	print(("===P2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return P2Verify
