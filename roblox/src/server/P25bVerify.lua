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
		local expected = { "no_class", "not_equipped", "not_found", "part_mismatch", "locked", "locked", "invalid", "b_grade_lower" }
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

	env.restore(player)
	local pass, total = r.summary()
	print(("===P25b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return P25bVerify
