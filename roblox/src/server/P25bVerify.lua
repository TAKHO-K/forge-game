-- P2.5b 자동 검증 - 장비 계승 · 보석 재련 · 보석 분해(가루) · 환생 후 레벨 마일스톤(docs/phase/P25b-log.md). DevTools.server.lua가 부른다.
--   (가) runPure = 순수 함수 · 합성 데이터(서버 시작 때, 플레이어 없이) - shared 모듈만 쓴다(하네스에서도 돈다).
--   (나) runLive = 실제 Player(보스 검증 체인의 끝): 실제 서버 경로(PlayerProfile · ItemInherit · 요청 모듈)로 규칙 · 비용 · 되돌리기 불가 동작 · 저장 필드를 잰다.
--        검증이 바꾼 것(장비 · 가방 · 보석 · 골드 · 가루 · 마일스톤)은 env.ensureBackup/restore가 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local InheritConfig = require(ReplicatedStorage.Shared.data.InheritConfig)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local Milestone = require(ReplicatedStorage.Shared.Milestone)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Option = require(ReplicatedStorage.Shared.Option)

local P25bVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P25b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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
	return math.abs(a - b) <= (tolerance or 1e-9) * math.max(1, math.abs(a), math.abs(b))
end

-- 합성 장비(Loot 모양 그대로 - 판정 함수는 part · grade · itemLevel · option · locked만 본다).
local function item(part, grade, itemLevel, optionId, roll, extra)
	local result = { part = part, grade = grade, itemLevel = itemLevel, tierIndex = 1, dropStage = itemLevel }
	if optionId then
		result.option = { id = optionId, roll = roll or 1, roll2 = optionId == "crit" and (roll or 1) or nil }
	end
	for key, value in pairs(extra or {}) do
		result[key] = value
	end
	return result
end
P25bVerify.item = item

-- ═══ (가) ═══
function P25bVerify.runPure()
	print("===P25b 검증 시작(가: 계승 · 재련 · 분해 · 마일스톤 - 순수 함수)===")
	local r = newRecorder("가")

	r.section("[A] 계승 규칙", function()
		local a = item("armor", "legendary", 120, "attackPercent", 1.1)
		local b = item("armor", "relic", 300, "speedPercent", 0.9)
		local low = item("armor", "epic", 400, "crit", 1.0)
		r.check(("A1 판정: 정상 B · keep a/b = nil · %s / %s"):format(tostring(Inherit.blockReason(a, b, "a", true)), tostring(Inherit.blockReason(a, b, "b", true))),
			Inherit.blockReason(a, b, "a", true) == nil and Inherit.blockReason(a, b, "b", true) == nil)
		local reasons = {
			Inherit.blockReason(a, b, "b", false), Inherit.blockReason(nil, b, "b", true), Inherit.blockReason(a, nil, "b", true),
			Inherit.blockReason(a, item("gloves", "relic", 300), "b", true), Inherit.blockReason(item("armor", "legendary", 120, nil, nil, { locked = true }), b, "b", true),
			Inherit.blockReason(a, item("armor", "relic", 300, nil, nil, { locked = true }), "b", true), Inherit.blockReason(a, b, "c", true), Inherit.blockReason(a, low, "a", true),
		}
		local expected = { "no_class", "not_equipped", "not_found", "part_mismatch", "a_locked", "locked", "invalid", "b_grade_lower" }
		local same = true
		for i = 1, #expected do
			same = same and reasons[i] == expected[i]
		end
		r.check(("A3 · A6 거절 이유 8종 = %s(기대 %s)"):format(table.concat(reasons, " · "), table.concat(expected, " · ")), same)
		r.check(("A3 B 등급이 낮아도 B 세트는 가능: %s(기대 nil)"):format(tostring(Inherit.blockReason(a, low, "b", true))), Inherit.blockReason(a, low, "b", true) == nil)

		-- A2: 옵션 종류 + 굴림 위치만 옮기고 수치는 B의 등급 · 레벨로 다시 계산.
		local keptA = Inherit.resultItem(a, b, "a")
		local valueOnA = Option.valueOf(a.option, a.grade, a.itemLevel, "greatsword")
		local valueOnB = Option.valueOf(keptA.option, b.grade, b.itemLevel, "greatsword")
		-- 값 식(Option.valueOf 주석) = 기본값 × (등급 배율 ÷ 태초 배율) × levelFactor(itemLevel) × 굴림 - B의 등급 · 레벨 · A의 굴림으로 직접 계산해 대조한다.
		local expectedOnB = OptionData.options.attackPercent.baseValue
			* (ItemVisualData.gradeVisuals.relic.statMultiplier / ItemVisualData.gradeVisuals.primordial.statMultiplier) * Option.levelFactor(300) * 1.1
		r.check(("A2 A 세트: 옵션 %s · 굴림 %.3f(= A 1.100) · A에서 %.4f → B에서 %.4f(기대 %.4f = B 등급 · Lv.300으로 재계산) · B의 등급 · 레벨 그대로(%s · %d)"):format(
			keptA.option.id, keptA.option.roll, valueOnA, valueOnB, expectedOnB, keptA.grade, keptA.itemLevel),
			keptA.option.id == "attackPercent" and keptA.option.roll == 1.1 and near(valueOnB, expectedOnB, 1e-9) and valueOnB > valueOnA and keptA.grade == "relic" and keptA.itemLevel == 300)
		r.check("A2 결과 장비의 옵션 표는 A의 표와 다른 사본(나중에 한쪽을 바꿔도 다른 쪽이 안 바뀐다)", keptA.option ~= a.option)
		local keptB = Inherit.resultItem(a, b, "b")
		r.check(("A2 B 세트: 옵션 %s · 굴림 %.3f(= B 그대로)"):format(keptB.option.id, keptB.option.roll), keptB.option.id == "speedPercent" and keptB.option.roll == 0.9)
		-- A3: 옵션 개수 = B 등급 한도(희귀 = 0개).
		local rareB = item("armor", "rare", 300, nil)
		local rareA = item("armor", "normal", 100, nil)
		r.check(("A3 옵션 칸: 일반 %d · 희귀 %d · 영웅 %d · 태초 %d(기대 0 · 0 · 1 · 1)"):format(Option.optionSlotsFor("normal"), Option.optionSlotsFor("rare"), Option.optionSlotsFor("epic"), Option.optionSlotsFor("primordial")),
			Option.optionSlotsFor("normal") == 0 and Option.optionSlotsFor("rare") == 0 and Option.optionSlotsFor("epic") == 1 and Option.optionSlotsFor("primordial") == 1)
		r.check("A3 희귀 B에 계승(옵션 칸 0) → 결과 옵션 없음", Inherit.resultItem(rareA, rareB, "a").option == nil)

		-- A5: 환급 = 분해와 같은 재료(보석 - 등급 · itemLevel = A) + 고르지 않은 쪽 옵션(총량 보존) / 분해 불가 등급은 판매가.
		local refundA, refundB = Inherit.refund(a, b, "a"), Inherit.refund(a, b, "b")
		r.check(("A5 A 세트를 남기면 보석(%s Lv.%d) 옵션 = B의 옛 옵션 %s · B 세트면 A 옵션 %s(= 보통 분해)"):format(
			refundA.gem.grade, refundA.gem.itemLevel, refundA.gem.option.id, refundB.gem.option.id),
			refundA.kind == "gem" and refundA.gem.grade == "legendary" and refundA.gem.itemLevel == 120 and refundA.gem.option.id == "speedPercent"
				and refundB.gem.option.id == "attackPercent" and refundB.gem.option.roll == 1.1)
		local rareRefund = Inherit.refund(rareA, rareB, "b")
		r.check(("A5 분해 불가(일반) A → 판매가 골드 %s(기대 %s)"):format(tostring(rareRefund.gold), tostring(Loot.getSellPrice(rareA))), rareRefund.kind == "gold" and rareRefund.gold == Loot.getSellPrice(rareA))

		-- A1 비용 = GoldCost(골드 소모처) · 할인.
		local cost1 = Inherit.cost("relic", 1, 0)
		local cost1000 = Inherit.cost("relic", 1000, 0)
		local expected1000 = GoldCost.cost(MonsterData.tier1.goldDrop * InheritConfig.goldKillEquivalent.relic, 1000, "inherit")
		r.check(("A1 비용: 유물 스테이지 1 = %d(기대 %d) · 1000 = %d(기대 %d - GoldCost 곡선) · 10%% 할인 %d"):format(
			cost1, MonsterData.tier1.goldDrop * InheritConfig.goldKillEquivalent.relic, cost1000, expected1000, Inherit.cost("relic", 1000, 0.1)),
			cost1 == MonsterData.tier1.goldDrop * InheritConfig.goldKillEquivalent.relic and cost1000 == expected1000 and Inherit.cost("relic", 1000, 0.1) == math.floor(expected1000 * 0.9))
		local rising = true
		for i = 2, #ArmorData.gradeOrder do
			rising = rising and Inherit.cost(ArmorData.gradeOrder[i], 500, 0) > Inherit.cost(ArmorData.gradeOrder[i - 1], 500, 0)
		end
		r.check("A1 비용은 B 등급이 오를수록 커진다(7등급)", rising)

		-- A7: B가 더 좋을 때만.
		r.check(("A7 [계승] 노출: 좋은 B %s · 나쁜 B %s · 다른 부위 %s · 착용 없음 %s(기대 true · false · false · false)"):format(
			tostring(Inherit.isUpgrade(a, b)), tostring(Inherit.isUpgrade(b, a)), tostring(Inherit.isUpgrade(a, item("gloves", "primordial", 999))), tostring(Inherit.isUpgrade(nil, b))),
			Inherit.isUpgrade(a, b) and not Inherit.isUpgrade(b, a) and not Inherit.isUpgrade(a, item("gloves", "primordial", 999)) and not Inherit.isUpgrade(nil, b))
	end)

	r.section("[C] 보석 분해 · 가루", function()
		local yields = {}
		local rising = true
		local previous = 0
		for _, gradeId in ipairs(GemCraft.bulkGradeChoices()) do
			local dust = GemCraft.dustYield({ grade = gradeId, itemLevel = 100 })
			table.insert(yields, ("%s %d"):format(gradeId, dust))
			rising = rising and dust > previous
			previous = dust
		end
		r.check(("C1 등급 기준(Lv.100 = levelFactor 1): %s - 등급이 오를수록 많다 · 기준량과 같다"):format(table.concat(yields, " · ")),
			rising and GemCraft.dustYield({ grade = "primordial", itemLevel = 100 }) == GemData.dust.dustYield.primordial and #GemCraft.bulkGradeChoices() == 5)
		local low, mid, high = GemCraft.dustYield({ grade = "relic", itemLevel = 1 }), GemCraft.dustYield({ grade = "relic", itemLevel = 100 }), GemCraft.dustYield({ grade = "relic", itemLevel = 20000 })
		r.check(("C1 레벨 기준: 유물 Lv.1 %d · Lv.100 %d · Lv.20000 %d(오른다 · 최소 1) · 일반 등급 0"):format(low, mid, high),
			low >= 1 and low < mid and mid < high and high == math.max(1, math.floor(GemData.dust.dustYield.relic * Option.levelFactor(20000) + 0.5)) and GemCraft.dustYield({ grade = "normal", itemLevel = 100 }) == 0)
		local bag = { { grade = "epic", itemLevel = 100 }, { grade = "relic", itemLevel = 100 }, { grade = "primordial", itemLevel = 100 }, { grade = "legendary", itemLevel = 100 } }
		local count, dust, highest = GemCraft.bulkEstimate(bag, "relic")
		local expectedDust = GemData.dust.dustYield.epic + GemData.dust.dustYield.relic + GemData.dust.dustYield.legendary
		r.check(("C2 일괄(유물 이하): %d개 · 가루 %d(기대 3 · %d) · 최고 %s(기대 relic) · 태초는 빠진다"):format(count, dust, expectedDust, tostring(highest)),
			count == 3 and dust == expectedDust and highest == "relic" and not GemCraft.isBulkTarget(bag[3], "relic") and not GemCraft.isBulkTarget(bag[1], "nonsense"))
		local refineDusts = {}
		for _, gradeId in ipairs(GemCraft.bulkGradeChoices()) do
			local _, dustCost = GemCraft.refineCost(gradeId, 1)
			table.insert(refineDusts, tostring(dustCost))
		end
		r.check(("C1 가루 소모처: 변환권 고대 %d · 태초 %d · 재련 가루(영웅 ~ 태초) %s"):format(GemCraft.ticketDust("ancient"), GemCraft.ticketDust("primordial"), table.concat(refineDusts, " · ")),
			GemCraft.ticketDust("ancient") > 0 and GemCraft.ticketDust("primordial") > GemCraft.ticketDust("ancient") and GemCraft.ticketDust("epic") == 0)
	end)

	r.section("[B] 보석 재련", function()
		local target = { grade = "primordial", itemLevel = 40, option = { id = "maxHpPercent", roll = 1.05 } }
		local fodder = { grade = "epic", itemLevel = 2500, option = { id = "crit", roll = 0.9, roll2 = 0.9 } }
		local same = { grade = "relic", itemLevel = 40, option = { id = "attackPercent", roll = 1 } }
		r.check(("B1 판정: 정상 %s · 먹이 없음 %s · 같은 보석 %s · 같은 레벨 %s · 낮은 레벨 %s(기대 nil · not_found · same_gem · no_gain · no_gain)"):format(
			tostring(GemCraft.refineBlockReason(target, fodder)), tostring(GemCraft.refineBlockReason(target, nil)), tostring(GemCraft.refineBlockReason(target, target)),
			tostring(GemCraft.refineBlockReason(target, same)), tostring(GemCraft.refineBlockReason(fodder, target))),
			GemCraft.refineBlockReason(target, fodder) == nil and GemCraft.refineBlockReason(target, nil) == "not_found" and GemCraft.refineBlockReason(target, target) == "same_gem"
				and GemCraft.refineBlockReason(target, same) == "no_gain" and GemCraft.refineBlockReason(fodder, target) == "no_gain")
		local after = GemCraft.refinedGem(target, fodder)
		local before = Option.valueOf(target.option, target.grade, target.itemLevel, "greatsword")
		local now = Option.valueOf(after.option, after.grade, after.itemLevel, "greatsword")
		local expected = OptionData.options.maxHpPercent.baseValue * Option.levelFactor(2500) * 1.05 -- 태초 등급 몫 = 1
		r.check(("B1 재련 뒤: 등급 %s(그대로) · 레벨 %d → %d · 옵션 %s 굴림 %.2f(그대로) · 수치 %.4f → %.4f(기대 %.4f = 새 레벨로 재계산) · 원본 불변(%d)"):format(
			after.grade, target.itemLevel, after.itemLevel, after.option.id, after.option.roll, before, now, expected, target.itemLevel),
			after.grade == "primordial" and after.itemLevel == 2500 and after.option == target.option and near(now, expected, 1e-9) and now > before and target.itemLevel == 40)
		local rising = true
		local gold1 = GemCraft.refineCost("primordial", 1)
		local gold1000 = GemCraft.refineCost("primordial", 1000)
		local grades = GemCraft.bulkGradeChoices()
		for i = 2, #grades do
			local goldA, dustA = GemCraft.refineCost(grades[i - 1], 500)
			local goldB, dustB = GemCraft.refineCost(grades[i], 500)
			rising = rising and goldB > goldA and dustB > dustA
		end
		r.check(("B2 비용: 태초 스테이지 1 = %d골드(기대 %d) · 1000 = %d(GoldCost %d) · 등급이 오를수록 골드 · 가루가 커진다 %s"):format(gold1, MonsterData.tier1.goldDrop * GemData.dust.refineGoldKills.primordial,
			gold1000, GoldCost.cost(MonsterData.tier1.goldDrop * GemData.dust.refineGoldKills.primordial, 1000, "refine"), tostring(rising)),
			gold1 == MonsterData.tier1.goldDrop * GemData.dust.refineGoldKills.primordial and gold1000 == GoldCost.cost(MonsterData.tier1.goldDrop * GemData.dust.refineGoldKills.primordial, 1000, "refine") and rising)
	end)

	r.section("[D] 환생 후 레벨 마일스톤", function()
		local k = InfiniteStageConfig.growthRate
		local per = MilestoneData.statStagesPerMilestone
		r.check(("D1 1회 배율 %.6f(기대 k^%.1f = %.6f · 스테이지 환산 %.1f ∈ [1, 2]) · 10회 %.4f(= 1회^10)"):format(Milestone.multiplier(1), per, k ^ per, Milestone.stageEquivalent(1), Milestone.multiplier(10)),
			near(Milestone.multiplier(1), k ^ per, 1e-12) and per >= 1 and per <= 2 and near(Milestone.multiplier(10), (k ^ per) ^ 10, 1e-9) and Milestone.multiplier(0) == 1)
		local plan0 = Milestone.plan(0, 300, {}, 0)
		local plan1 = Milestone.plan(1, 155, {}, 0)
		local plan1b = Milestone.plan(1, 160, { ["1"] = 150 }, 1)
		local plan5 = Milestone.plan(5, 20000, { ["1"] = 150, ["2"] = 200 }, 2)
		r.check(("D1 기록: 환생 0회 = %s(기대 nil) · 1회차 Lv.155 → 받을 레벨 %d · +%d회 · 해금 %d ~ %d(기대 150 · 3 · 1 ~ 1) · 이미 받음(150) Lv.160 → +%d(기대 0) · 5회차 Lv.20000 → +%d회 · 해금 %d ~ %d(기대 400 · 3 ~ 5)"):format(
			tostring(plan0), plan1.claimedLevel, plan1.statGained, plan1.unlockFrom, plan1.unlockTo, plan1b.statGained, plan5.statGained, plan5.unlockFrom, plan5.unlockTo),
			plan0 == nil and plan1.claimedLevel == 150 and plan1.statGained == 3 and plan1.unlockFrom == 1 and plan1.unlockTo == 1 and plan1b.statGained == 0 and plan1b.unlockTo < plan1b.unlockFrom
				and plan5.statGained == 400 and plan5.unlockFrom == 3 and plan5.unlockTo == #MilestoneData.unlocks)
		r.check(("D1 누적(환생 반복): 회차 150 · 200 · 200 → %d회(기대 3 + 4 + 4 = 11) · 해금 수 Lv.99 %d · 100 %d · 550 %d · 1e4 %d(기대 0 · 1 · 5 · 5)"):format(
			Milestone.statCount({ ["1"] = 150, ["2"] = 200, ["3"] = 200 }), Milestone.unlockCountFor(99), Milestone.unlockCountFor(100), Milestone.unlockCountFor(550), Milestone.unlockCountFor(10000)),
			Milestone.statCount({ ["1"] = 150, ["2"] = 200, ["3"] = 200 }) == 11 and Milestone.unlockCountFor(99) == 0 and Milestone.unlockCountFor(100) == 1 and Milestone.unlockCountFor(550) == #MilestoneData.unlocks)
		local reserved = 0
		for _, entry in ipairs(MilestoneData.unlocks) do
			reserved += entry.reserved and 1 or 0
		end
		r.check(("D1 해금 표: %d개 · 가방 칸 +%d(해금 1개) · 계승 할인 %.0f%%(해금 2개) · 예약 %d개 · 1번 = 가방 · 2번 = 계승 할인"):format(#MilestoneData.unlocks, Milestone.bagSlotsBonus(1), Milestone.inheritDiscount(2) * 100, reserved),
			#MilestoneData.unlocks == 5 and Milestone.bagSlotsBonus(1) == 5 and near(Milestone.inheritDiscount(2), 0.10) and Milestone.inheritDiscount(1) == 0 and reserved == 3)
		-- 전투 식: 공격력 · 최대체력에 배율이 곱해진다(BalanceSim = EconSim이 쓰는 같은 식).
		local base = BalanceSim.buildLoadout({ classId = "greatsword", level = 200, weaponLevel = 10, weaponGrade = 2 })
		local boosted = BalanceSim.buildLoadout({ classId = "greatsword", level = 200, weaponLevel = 10, weaponGrade = 2, permanentMultiplier = Milestone.multiplier(7), permanentHpMultiplier = Milestone.maxHpMultiplier(7) })
		local hpExpected = MilestoneData.survival and Milestone.multiplier(7) or 1
		r.check(("D1 공격력 ×%.4f(기대 %.4f) · 최대체력 ×%.4f(기대 %.4f - survival %s) · 방어력 그대로 %s"):format(boosted.atk / base.atk, Milestone.multiplier(7), boosted.maxHp / base.maxHp, hpExpected,
			tostring(MilestoneData.survival), tostring(boosted.defense == base.defense)),
			near(boosted.atk / base.atk, Milestone.multiplier(7), 1e-9) and near(boosted.maxHp / base.maxHp, hpExpected, 1e-9) and boosted.defense == base.defense)
	end)

	r.section("[C] 저장 v31 gemDust", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = SaveSystem.defaultProfile()
		old.version = 30
		old.gemDust = nil
		local migrated = SaveSystem.migrate(old)
		local bad = SaveSystem.defaultProfile()
		bad.gemDust = -1
		local frac = SaveSystem.defaultProfile()
		frac.gemDust = 1.5
		r.check(("C 저장: SAVE_VERSION %d(기대 ≥ 31) · v30 → v%d gemDust = %s · isValid %s · 음수 %s · 소수 %s(기대 거절) · 기본 프로필 0"):format(
			SaveConfig.saveVersion, migrated.version, tostring(migrated.gemDust), tostring(SaveSystem.isValidProfile(migrated)), tostring(SaveSystem.isValidProfile(bad)), tostring(SaveSystem.isValidProfile(frac))),
			SaveConfig.saveVersion >= 31 and migrated.version == SaveConfig.saveVersion and migrated.gemDust == 0 and SaveSystem.isValidProfile(migrated)
				and not SaveSystem.isValidProfile(bad) and not SaveSystem.isValidProfile(frac) and SaveSystem.defaultProfile().gemDust == 0)
	end)

	r.section("[D] 저장 v32 milestones · milestoneUnlocks", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = SaveSystem.defaultProfile()
		old.version = 31
		old.milestoneUnlocks = nil
		for _, classState in pairs(old.classes) do
			classState.milestones = nil
		end
		local migrated = SaveSystem.migrate(old)
		local allEmpty = true
		for _, classState in pairs(migrated.classes) do
			allEmpty = allEmpty and type(classState.milestones) == "table" and next(classState.milestones) == nil
		end
		local badKey = SaveSystem.defaultProfile()
		local someClass = next(badKey.classes)
		badKey.classes[someClass].milestones = { [1] = 50 } -- 숫자 키(DataStore가 문자열로 바꾸는 키 - 쓰는 쪽은 항상 문자열)
		local badValue = SaveSystem.defaultProfile()
		badValue.classes[someClass].milestones = { ["1"] = 12.5 }
		local badUnlock = SaveSystem.defaultProfile()
		badUnlock.milestoneUnlocks = -1
		local good = SaveSystem.defaultProfile()
		good.classes[someClass].milestones = { ["1"] = 150, ["2"] = 200 }
		good.milestoneUnlocks = 2
		r.check(("D 저장: SAVE_VERSION %d(기대 ≥ 32) · v31 → v%d 빈 표 %s · 해금 %s · 숫자 키 %s · 소수 %s · 음수 해금 %s(기대 거절) · 정상 %s"):format(SaveConfig.saveVersion, migrated.version, tostring(allEmpty),
			tostring(migrated.milestoneUnlocks), tostring(SaveSystem.isValidProfile(badKey)), tostring(SaveSystem.isValidProfile(badValue)), tostring(SaveSystem.isValidProfile(badUnlock)), tostring(SaveSystem.isValidProfile(good))),
			SaveConfig.saveVersion >= 32 and migrated.version == SaveConfig.saveVersion and allEmpty and migrated.milestoneUnlocks == 0 and SaveSystem.isValidProfile(migrated)
				and not SaveSystem.isValidProfile(badKey) and not SaveSystem.isValidProfile(badValue) and not SaveSystem.isValidProfile(badUnlock) and SaveSystem.isValidProfile(good))
	end)

	local pass, total = r.summary()
	print(("===P25b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

-- ═══ (나) ═══
function P25bVerify.runLive(player, env)
	print("===P25b 검증 시작(나: 실제 Player · 계승 · 재련 · 분해 · 마일스톤)===")
	local r = newRecorder("나")
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local ItemInherit = require(script.Parent.ItemInherit)
	local profile = PlayerProfile.getProfile(player)
	if not profile or not profile.classId then
		r.check("프로필 · 직업이 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===P25b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	env.ensureBackup(player) -- 장비 · 가방 · 보석 · 골드는 env.restore가 되돌린다
	local classState = profile.classes[profile.classId]

	r.section("[A] 계승 실제 경로", function()
		local a = item("armor", "legendary", 120, "attackPercent", 1.1)
		local b = item("armor", "relic", 300, "speedPercent", 0.9)
		PlayerProfile.setEquippedDirect(player, "armor", a)
		table.insert(profile.inventory, b)
		local bIndex = #profile.inventory
		local gemsBefore = #classState.gemInventory
		profile.gold = 1e12
		player:SetAttribute("Gold", profile.gold)

		local preview = ItemInherit.preview(player, "armor", bIndex)
		local cost = PlayerProfile.getInheritCost(player, "relic")
		r.check(("A6 미리보기: 비용 %s(= getInheritCost %s) · 현재 · A 세트 · B 세트 능력치 %s · %s · %s · 방어력 현재 %.1f → 계승 후 %.1f · 착용 칸 원상 %s"):format(
			tostring(preview and preview.cost), tostring(cost), tostring(preview and preview.stats.current ~= nil), tostring(preview and preview.stats.a ~= nil), tostring(preview and preview.stats.b ~= nil),
			preview and preview.stats.current.defense or -1, preview and preview.stats.b.defense or -1, tostring(classState.equipment.armor == a)),
			preview ~= nil and preview.cost == cost and preview.stats.a ~= nil and preview.stats.b ~= nil and preview.stats.b.defense > preview.stats.current.defense and classState.equipment.armor == a)
		local speedA = preview and preview.stats.a.speedPercent or 0
		local speedB = preview and preview.stats.b.speedPercent or 0
		r.check(("A6 세트별 차이: A 세트(위력) 속도 %.4f · B 세트(신속) 속도 %.4f(B 세트가 크다) · A 세트 공격력 %.1f > B 세트 %.1f"):format(speedA, speedB, preview.stats.a.attack, preview.stats.b.attack),
			speedB > speedA and preview.stats.a.attack > preview.stats.b.attack)

		-- 거절: 잠금 · B 등급 낮음(A 세트) · 골드 부족 - 아무것도 바뀌지 않는다.
		b.locked = true
		local okLocked, reasonLocked = ItemInherit.handle(player, "armor", bIndex, "a")
		b.locked = nil
		local low = item("armor", "epic", 500, "crit", 1)
		table.insert(profile.inventory, low)
		local okLow, reasonLow = ItemInherit.handle(player, "armor", #profile.inventory, "a")
		table.remove(profile.inventory, #profile.inventory)
		profile.gold = cost - 1
		local okGold, reasonGold = ItemInherit.handle(player, "armor", bIndex, "a")
		local okShape, reasonShape = ItemInherit.handle(player, "weapon", bIndex, "a")
		r.check(("A6 거절: 잠금 %s · B 등급 낮음 %s · 골드 부족 %s · 무기 부위 %s · 그대로(착용 A · 가방 B · 골드 %s)"):format(
			tostring(reasonLocked), tostring(reasonLow), tostring(reasonGold), tostring(reasonShape), tostring(profile.gold == cost - 1)),
			not okLocked and reasonLocked == "locked" and not okLow and reasonLow == "b_grade_lower" and not okGold and reasonGold == "no_gold" and not okShape and reasonShape == "invalid"
				and classState.equipment.armor == a and profile.inventory[bIndex] == b and profile.gold == cost - 1)

		-- 성공(A 세트): 골드 = 비용만큼 · B 착용(옵션 = A 종류 · 굴림) · 가방에서 B 제거 · 환급 보석(A 등급 · 레벨 + B 옛 옵션).
		profile.gold = cost + 1000
		local bagBefore = #profile.inventory
		local ok, refundKind = ItemInherit.handle(player, "armor", bIndex, "a")
		local worn = classState.equipment.armor
		local refundGem = classState.gemInventory[#classState.gemInventory]
		r.check(("A1 · A2 · A5 성공: %s · 골드 %s(기대 1000) · 착용 %s Lv.%d 옵션 %s 굴림 %.2f · 가방 %d → %d · 보석 +%d(%s Lv.%d 옵션 %s) · 환급 %s"):format(
			tostring(ok), tostring(profile.gold), worn.grade, worn.itemLevel, worn.option.id, worn.option.roll, bagBefore, #profile.inventory,
			#classState.gemInventory - gemsBefore, refundGem.grade, refundGem.itemLevel, refundGem.option and refundGem.option.id or "없음", tostring(refundKind)),
			ok and profile.gold == 1000 and worn.grade == "relic" and worn.itemLevel == 300 and worn.option.id == "attackPercent" and worn.option.roll == 1.1
				and #profile.inventory == bagBefore - 1 and #classState.gemInventory == gemsBefore + 1 and refundGem.grade == "legendary" and refundGem.itemLevel == 120
				and refundGem.option.id == "speedPercent" and refundKind == "gem")
		r.check(("A2 실제 능력치: 계승 뒤 방어력 %.1f = 미리보기 A 세트 %.1f"):format(PlayerProfile.getStatSummary(player).defense, preview.stats.a.defense),
			near(PlayerProfile.getStatSummary(player).defense, preview.stats.a.defense, 1e-9))
	end)

	r.section("[C] 보석 분해 실제 경로", function()
		local GemCraftRequest = require(script.Parent.GemCraftRequest)
		local GemWorkshop = require(script.Parent.GemWorkshop)
		local gems = classState.gemInventory
		table.clear(gems)
		table.insert(gems, { grade = "epic", itemLevel = 100, option = { id = "attackPercent", roll = 1 } })
		table.insert(gems, { grade = "primordial", itemLevel = 300, option = { id = "crit", roll = 1, roll2 = 1 } })
		table.insert(gems, { grade = "legendary", itemLevel = 50, option = { id = "speedPercent", roll = 1 } })
		profile.gemDust = 0
		local expectOne = GemCraft.dustYield(gems[1])
		local ok1, why1, data1 = GemCraftRequest.handle(player, "dismantle", 1)
		r.check(("C1 한 개: %s · 가루 %s(기대 %d) · 보석 %d개(기대 2) · Attribute %s"):format(tostring(ok1), tostring(data1 and data1.dust), expectOne, #gems, tostring(player:GetAttribute("GemDust"))),
			ok1 and why1 == nil and data1.dust == expectOne and profile.gemDust == expectOne and #gems == 2 and player:GetAttribute("GemDust") == expectOne)
		local okBad, whyBad = GemCraftRequest.handle(player, "dismantle", 99)
		local okShape, whyShape = GemCraftRequest.handle(player, "dismantle", "1")
		local okNone, whyNone = GemCraftRequest.handle(player, "dismantleBulk", "normal")
		r.check(("C 거절: 없는 칸 %s · 문자열 index %s · 대상 없음 %s(기대 not_found · invalid · none) · 가루 그대로"):format(tostring(whyBad), tostring(whyShape), tostring(whyNone)),
			not okBad and whyBad == "not_found" and not okShape and whyShape == "invalid" and not okNone and whyNone == "none" and profile.gemDust == expectOne)
		local expectBulk = GemCraft.dustYield(gems[1]) + GemCraft.dustYield(gems[2])
		local okBulk, _, dataBulk = GemCraftRequest.handle(player, "dismantleBulk", "primordial")
		r.check(("C2 일괄(태초 이하): %d개 · 가루 +%s(기대 2 · +%d) · 보석 가방 %d개(기대 0) · 홈의 보석은 그대로(%s)"):format(dataBulk and dataBulk.count or -1, tostring(dataBulk and dataBulk.dust), expectBulk, #classState.gemInventory, tostring(classState.weapon.gems[1] ~= nil)),
			okBulk and dataBulk.count == 2 and dataBulk.dust == expectBulk and #classState.gemInventory == 0 and profile.gemDust == expectOne + expectBulk)
		-- 변환권 = 골드 + 가루: 가루가 모자라면 no_dust(골드 그대로) · 있으면 둘 다 빠진다.
		local alwaysNear = function()
			return true
		end
		profile.gemDust = GemCraft.ticketDust("ancient") - 1
		profile.gold = 1e9
		local tickets = profile.purchases.optionRerollTickets
		local ticketsBefore = tickets.ancient
		local okNoDust, whyNoDust = GemWorkshop.buyTicket(player, "ancient", 1000, alwaysNear)
		local goldAfterFail = profile.gold
		profile.gemDust = GemCraft.ticketDust("ancient")
		local okBuy = GemWorkshop.buyTicket(player, "ancient", 1000, alwaysNear)
		r.check(("C1 변환권: 가루 부족 %s(기대 no_dust · 골드 그대로 %s) · 충분 %s · 가루 %d(기대 0) · 골드 -1000 · 변환권 +1"):format(tostring(whyNoDust), tostring(goldAfterFail == 1e9), tostring(okBuy), profile.gemDust),
			not okNoDust and whyNoDust == "no_dust" and goldAfterFail == 1e9 and okBuy and profile.gemDust == 0 and profile.gold == 1e9 - 1000 and tickets.ancient == ticketsBefore + 1)
		tickets.ancient = ticketsBefore -- purchases는 DevTools 백업 대상이 아니다(옵션 변환권은 만지는 블록이 되돌린다)
		profile.hints.gemMerchantUsed = false -- buyTicket이 켠 안내 플래그(hints는 백업 대상 - env.restore가 원래 값으로 되돌린다)
	end)

	r.section("[B] 보석 재련 실제 경로(장착 중 홈)", function()
		local GemCraftRequest = require(script.Parent.GemCraftRequest)
		local gems = classState.gemInventory
		table.clear(gems)
		local socket = { grade = "primordial", itemLevel = 40, option = { id = "maxHpPercent", roll = 1.05 } }
		-- 다른 건강 옵션 출처를 비운다(합산 상한 20%에 걸리면 최대 체력 변화가 안 보인다) - env.restore가 되돌린다.
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			classState.equipment[part] = nil
		end
		for slot = 2, #classState.weapon.gems do
			classState.weapon.gems[slot] = false
		end
		classState.weapon.gems[1] = socket
		PlayerProfile.refreshMaxHp(player)
		local maxHpBefore = PlayerProfile.getStatSummary(player).maxHp
		table.insert(gems, { grade = "epic", itemLevel = 30, option = { id = "attackPercent", roll = 1 } }) -- 1: 낮은 레벨
		table.insert(gems, { grade = "epic", itemLevel = 2500, option = { id = "crit", roll = 0.9, roll2 = 0.9 } }) -- 2: 먹이
		local goldCost, dustCost = GemCraft.refineCost("primordial", PlayerProfile.getAccountBestStage(player))
		profile.gold = goldCost + 5
		profile.gemDust = dustCost - 1
		local okNoDust, whyNoDust = GemCraftRequest.handle(player, "refine", "slot", 1, 2)
		profile.gemDust = dustCost + 3
		profile.gold = goldCost - 1
		local okNoGold, whyNoGold = GemCraftRequest.handle(player, "refine", "slot", 1, 2)
		profile.gold = goldCost + 5
		local okLow, whyLow = GemCraftRequest.handle(player, "refine", "slot", 1, 1)
		local okSame, whySame = GemCraftRequest.handle(player, "refine", "bag", 2, 2)
		local okKind, whyKind = GemCraftRequest.handle(player, "refine", "weapon", 1, 2)
		r.check(("B 거절: 가루 부족 %s · 골드 부족 %s · 낮은 먹이 %s · 같은 보석 %s · 모양 %s(기대 no_dust · no_gold · no_gain · same_gem · invalid) · 그대로(레벨 %d · 가방 %d · 골드 %s)"):format(
			tostring(whyNoDust), tostring(whyNoGold), tostring(whyLow), tostring(whySame), tostring(whyKind), socket.itemLevel, #gems, tostring(profile.gold == goldCost + 5)),
			not okNoDust and whyNoDust == "no_dust" and not okNoGold and whyNoGold == "no_gold" and not okLow and whyLow == "no_gain" and not okSame and whySame == "same_gem"
				and not okKind and whyKind == "invalid" and socket.itemLevel == 40 and #gems == 2 and profile.gold == goldCost + 5 and profile.gemDust == dustCost + 3)
		local ok, why, data = GemCraftRequest.handle(player, "refine", "slot", 1, 2)
		local maxHpAfter = PlayerProfile.getStatSummary(player).maxHp
		r.check(("B1 · B2 성공(장착 중 1번 홈 - 해제 없이): %s · 레벨 40 → %s · 옵션 %s 굴림 %.2f 그대로 · 먹이 사라짐(가방 %d) · 골드 %s(기대 5) · 가루 %d(기대 3) · 최대 체력 %.1f → %.1f(건강 옵션 수치가 새 레벨로)"):format(
			tostring(ok), tostring(data and data.itemLevel), socket.option.id, socket.option.roll, #gems, tostring(profile.gold), profile.gemDust, maxHpBefore, maxHpAfter),
			ok and why == nil and data.itemLevel == 2500 and classState.weapon.gems[1] == socket and socket.itemLevel == 2500 and socket.grade == "primordial" and socket.option.id == "maxHpPercent"
				and socket.option.roll == 1.05 and #gems == 1 and gems[1].itemLevel == 30 and profile.gold == 5 and profile.gemDust == 3 and maxHpAfter > maxHpBefore)
	end)

	r.section("[D] 마일스톤 실제 경로", function()
		classState.rebirthCount = 1
		classState.milestones = {}
		profile.milestoneUnlocks = 0
		local slotsBefore = profile.inventorySlots
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(49))
		local statsBefore = PlayerProfile.getStatSummary(player)
		local nothing = PlayerProfile.claimMilestones(player, false)
		classState.characterExp = CharacterLevel.getExpForLevel(155)
		local payload = PlayerProfile.claimMilestones(player, false)
		local expected = Milestone.multiplier(3)
		r.check(("D1 1회차 Lv.49 → 없음(%s) · Lv.155 → +%d회 · 해금 %d개(%s) · 기록 1회차 = %s(기대 150) · 가방 칸 %d → %d(+5) · Attribute 배율 %.4f(기대 %.4f)"):format(
			tostring(nothing), payload and payload.statGained or -1, payload and #payload.unlocks or -1, payload and payload.unlocks[1] and payload.unlocks[1].name or "-",
			tostring(classState.milestones["1"]), slotsBefore, profile.inventorySlots, player:GetAttribute("MilestoneMultiplier") or -1, expected),
			nothing == nil and payload ~= nil and payload.statGained == 3 and #payload.unlocks == 1 and payload.unlocks[1].id == "bagSlots" and classState.milestones["1"] == 150
				and profile.inventorySlots == slotsBefore + 5 and profile.milestoneUnlocks == 1 and near(player:GetAttribute("MilestoneMultiplier"), expected, 1e-9))
		-- 공격력 · 최대체력(실제 전투가 쓰는 함수): 레벨이 같은 상태에서 배율만 비교한다.
		classState.characterExp = CharacterLevel.getExpForLevel(49)
		local attackWith = PlayerProfile.getStatSummary(player)
		local hpExpected = MilestoneData.survival and expected or 1
		r.check(("D1 실제 능력치(같은 레벨 49): 공격력 ×%.4f(기대 %.4f) · 최대 체력 ×%.4f(기대 %.4f - survival %s) · 전투 배율 함수 %.4f"):format(attackWith.attack / statsBefore.attack, expected,
			attackWith.maxHp / statsBefore.maxHp, hpExpected, tostring(MilestoneData.survival), PlayerProfile.getMilestoneMultiplier(player)),
			near(attackWith.attack / statsBefore.attack, expected, 1e-9) and near(attackWith.maxHp / statsBefore.maxHp, hpExpected, 1e-9) and near(PlayerProfile.getMilestoneMultiplier(player), expected, 1e-12))
		-- 환생 뒤 새 회차: 레벨 1부터 다시 받고, 지난 회차 몫은 남는다(누적) · Lv.200 = 2번째 해금(계승 할인).
		classState.rebirthCount = 2
		classState.characterExp = CharacterLevel.getExpForLevel(210)
		local fullCost = Inherit.cost("relic", PlayerProfile.getAccountBestStage(player), 0)
		local payload2 = PlayerProfile.claimMilestones(player, false)
		r.check(("D1 2회차 Lv.210 → +%d회(기대 4) · 누적 %d회(기대 7) · 해금 %s · 계승 비용 %d → %d(기대 ×0.9 = %d) · 저장 모양 유효 %s"):format(
			payload2 and payload2.statGained or -1, Milestone.statCount(classState.milestones), payload2 and payload2.unlocks[1] and payload2.unlocks[1].id or "-",
			fullCost, PlayerProfile.getInheritCost(player, "relic"), math.floor(fullCost * 0.9), tostring(require(script.Parent.SaveSystem).isValidProfile(profile))),
			payload2 ~= nil and payload2.statGained == 4 and Milestone.statCount(classState.milestones) == 7 and payload2.unlocks[1].id == "inheritDiscount"
				and PlayerProfile.getInheritCost(player, "relic") == math.floor(fullCost * 0.9) and require(script.Parent.SaveSystem).isValidProfile(profile))
		local summary = PlayerProfile.getMilestoneSummary(player)
		r.check(("D2 보상 목록 값: 회차 %d · 레벨 %d · 누적 %d회 · 해금 %d개 · 회차별 %s · %s"):format(summary.rebirthCount, summary.level, summary.statCount, summary.unlockCount, tostring(summary.cycles["1"]), tostring(summary.cycles["2"])),
			summary.rebirthCount == 2 and summary.level == 210 and summary.statCount == 7 and summary.unlockCount == 2 and summary.cycles["1"] == 150 and summary.cycles["2"] == 200)
	end)

	env.restore(player)
	local pass, total = r.summary()
	print(("===P25b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return P25bVerify
