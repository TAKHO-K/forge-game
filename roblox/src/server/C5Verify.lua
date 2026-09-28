-- C5 자동 검증(가) - 순수 값(docs/design/growth-curve-v2.md): C5-1 딜 부위 지수 몫 · 뒤처짐 신호 · 스테이지 15 타수 신호 · 앵커 불변.
--   실제 피해 경로(Play)는 /gg gear <grade> <itemLevel> [part] + 표본 몹(C3Immortal)으로 잰다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local CombatFormulaData = require(ReplicatedStorage.Shared.data.CombatFormulaData)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)

local V = {}

function V.runPure()
	print("===C5 검증 시작(가)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[C5][가] %s %s"):format(label, ok and "O" or "X"))
	end
	local function section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	local k = InfiniteStageConfig.growthRate
	local rule = CharacterLevelConfig.dealGear

	section("C5-1 지수 몫", function()
		check(("dealGear.share = %.2f(0 < share < 1) · 부위 %d"):format(rule.share, #rule.parts), rule.share > 0 and rule.share < 1 and #rule.parts == 2)
		-- 앵커 불변: 레벨 L · 딜 부위 itemLevel L → 레벨 배율 × 장비 배율 = 정점 × 성장부(L)(share를 옮기기 전 값)
		local ok = true
		for _, level in ipairs({ 26, 100, 500, 1000, 5000, 25300 }) do
			local combined = CharacterLevel.getWeaponExpMultiplier(level) * CharacterLevel.getDealGearMultiplier({ gloves = level, shoes = level })
			local old = CharacterLevel.getWeaponExpMultiplier(25) * CharacterLevel.growthPart(level)
			ok = ok and math.abs(math.log(combined) - math.log(old)) < 1e-9
		end
		check("앵커(딜 부위 itemLevel = 레벨) 레벨 × 장비 배율 = 옛 레벨 배율(불변)", ok)
		-- 25 이하 · 미착용 = 1
		check(("itemLevel 25 이하 · 미착용 배율 1: %.3f · %.3f"):format(CharacterLevel.getDealGearPartMultiplier(25), CharacterLevel.getDealGearMultiplier(nil)),
			CharacterLevel.getDealGearPartMultiplier(25) == 1 and CharacterLevel.getDealGearMultiplier(nil) == 1)
		-- 한 부위 100칸 = k^(share × 100 ÷ 2)
		local expect = k ^ (rule.share * 100 / #rule.parts)
		check(("장갑 itemLevel 125 ÷ 25 = ×%.3f(= k^(share × 100 ÷ 2) %.3f)"):format(CharacterLevel.getDealGearPartMultiplier(125), expect), math.abs(CharacterLevel.getDealGearPartMultiplier(125) - expect) < 1e-9)
		-- 처치 앵커 = BalanceAnchorConfig.killTargetSeconds(레벨 100 · 1,000 - 구간 배율 전 원 HP)
		local kills = {}
		local anchorOk = true
		for _, level in ipairs({ 100, 1000 }) do
			local loadout = BalanceSim.buildAnchorLoadout(BalanceAnchorConfig.referenceClassId, level, 0)
			local stage = CharacterLevel.getStageForLevel(level)
			local result = BalanceSim.simulateCombat(loadout, { useSkills = true, targetHp = InfiniteStage.getMonsterHp(MonsterData.tier1.hp, stage), durationSeconds = 600, turnDelaySeconds = 0.125 })
			local seconds = result.killTime or math.huge
			table.insert(kills, ("%d → %.3f초"):format(level, seconds))
			anchorOk = anchorOk and math.abs(seconds - BalanceAnchorConfig.killTargetSeconds) <= 0.1
		end
		check(("처치 앵커 %s(기대 %.2f ± 0.1)"):format(table.concat(kills, " · "), BalanceAnchorConfig.killTargetSeconds), anchorOk)
	end)

	section("C5-1 뒤처짐 신호", function()
		local lag = CombatFormulaData.gearLag
		check(("스테이지 15 · 최고 딜 부위 5(부족 10 = N) → ×%.3f(기대 0.5) · 15 → ×%.3f(기대 1) · 스테이지 10 이하 = 1: %.3f"):format(
			CombatFormula.gearLagMultiplier(5, 15), CombatFormula.gearLagMultiplier(15, 15), CombatFormula.gearLagMultiplier(0, 10)),
			math.abs(CombatFormula.gearLagMultiplier(5, 15) - 0.5) < 1e-9 and CombatFormula.gearLagMultiplier(15, 15) == 1 and CombatFormula.gearLagMultiplier(0, 10) == 1)
		check(("중반 2,000 · N %.0f: 부족 49 → 1 · 50 → ×0.5 = %.3f · %.3f / 후반 5,000 · N %.0f: 부족 200 → ×%.3f(기대 0.333)"):format(
			InfiniteStage.interpBand(lag.lagStages, 2000), CombatFormula.gearLagMultiplier(1951, 2000), CombatFormula.gearLagMultiplier(1950, 2000), InfiniteStage.interpBand(lag.lagStages, 5000), CombatFormula.gearLagMultiplier(4800, 5000)),
			CombatFormula.gearLagMultiplier(1951, 2000) == 1 and math.abs(CombatFormula.gearLagMultiplier(1950, 2000) - 0.5) < 1e-9 and math.abs(CombatFormula.gearLagMultiplier(4800, 5000) - 1 / 3) < 1e-9)
		local mono = true
		local prev = 1
		for best = 5000, 0, -25 do
			local m = CombatFormula.gearLagMultiplier(best, 5000)
			mono = mono and m <= prev + 1e-12 and m > 0
			prev = m
		end
		check("부족분이 클수록 배율 단조 감소(> 0)", mono)
		check("보스는 미적용(호출부) · nil = 1", CombatFormula.gearLagMultiplier(nil, 5000) == 1)
	end)

	section("C5-3 잡몹 공격 구간 배율", function()
		local mono, prev = true, 0
		for stage = 1, 4000 do
			local a = InfiniteStage.getTrashAttack(MonsterData.tier1.attack, stage)
			mono = mono and a > prev
			prev = a
		end
		check("잡몹 공격 = 스테이지에 단조 증가(1 ~ 4,000 - 되돌림 기울기 < k)", mono)
		local band = InfiniteStageConfig.trashAttackBand
		check(("표 밖 = 1: 스테이지 1 ×%.3f · 5,000 ×%.3f · 보스는 그대로(BossRules 잡몹 기준 공격 = getMonsterAttack)"):format(InfiniteStage.interpBand(band, 1), InfiniteStage.interpBand(band, 5000)),
			InfiniteStage.interpBand(band, 1) == 1 and InfiniteStage.interpBand(band, 5000) == 1)
	end)

	section("스테이지 15 타수 신호(대표 활)", function()
		-- 대표 = 권장 전투력(비율 1.0) · 레벨 = 15(초반 대표) · 옛 장비 = 딜 부위 itemLevel 1 · 새 장비 1부위 = 장갑 itemLevel 15
		local stage = 15
		local bow = ClassData.classes.bow
		local rec = CombatFormula.recommendedPower(stage)
		local function hitsFor(bestDeal, crit)
			local critRate = math.min(bow.critRate + PlayerCombat.resolveCrit("bow", stage, 0, 0), 1)
			local atk = rec / (1 + critRate * (bow.critDmg - 1))
			local _, scale = PlayerCombat.getAttackTempo("bow", 0, 1)
			local damage = atk * scale * (crit and bow.critDmg or 1) * CombatFormula.dealMultiplier(rec, stage, MonsterData.tier1.hp) * CombatFormula.gearLagMultiplier(bestDeal, stage)
			return math.ceil(InfiniteStage.getTrashHp(MonsterData.tier1.hp, stage) / damage - 1e-9)
		end
		-- 지시의 절대 타수(옛 장비 3방 · 새 장비 비치명 2방)는 스테이지 15 대표가 T1을 약 2.6배 과잉 처치하는 지금 곡선(1 ~ 10 누구나 한 방 · 초반 편안)과 양립하지 않는다(결정 필요) → 상대 신호로 본다: 옛 장비 = 새 장비 타수 × 2 이상.
		local oldNon, newNon, newCrit = hitsFor(1, false), hitsFor(15, false), hitsFor(15, true)
		-- 묶음 A-4a(사용자 확정): 절대 타수 점검 폐기 → 상대 신호 ×2만 본다(새 장비 치명 타수는 기록만).
		check(("T1 비치명: 옛 장비만(itemLevel 1) %d방 · 해당 레벨 1부위 %d방 · 치명 %d방(기대 옛 ≥ 새 × 2)"):format(oldNon, newNon, newCrit), oldNon >= newNon * 2)
	end)

	section("C5-7 초월", function()
		local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
		local DropTable = require(ReplicatedStorage.Shared.DropTable)
		local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
		local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
		local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
		local Loot = require(ReplicatedStorage.Shared.Loot)
		local Awaken = require(ReplicatedStorage.Shared.Awaken)
		local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
		check(("등급 순서 끝 = 초월 · 무기 등급 상한 index %d = 태초"):format(ArmorData.maxWeaponGradeIndex), ArmorData.gradeOrder[#ArmorData.gradeOrder] == "transcendent" and ArmorData.gradeOrder[ArmorData.maxWeaponGradeIndex + 1] == "primordial")
		local g = ArmorData.grades
		check(("딜 부위 위력: 초월 %.2f = 고대 %.2f × 1.5 · 갑옷 방어 초월 = 태초 × %.1f"):format(g.transcendent.dropPower, g.ancient.dropPower, TranscendentData.armorStep),
			math.abs(g.transcendent.dropPower - g.ancient.dropPower * 1.5) < 1e-9 and math.abs(g.transcendent.defenseGradeMultiplier - g.primordial.defenseGradeMultiplier * TranscendentData.armorStep) < 1e-9)
		local function sum(t)
			local x = 0
			for _, v in pairs(t) do
				x += v
			end
			return x
		end
		check(("드랍표 합 1(첫 클리어 %.10f · 토벌 %.10f · 반짝이 %.10f) · 초월 확률 0.001%% · 0.0002%% · 0.0005%%"):format(sum(DropTableData.bossGrades.firstClear), sum(DropTableData.bossGrades.raid), sum(RareMonsterConfig.sparkleGradeChances)),
			math.abs(sum(DropTableData.bossGrades.firstClear) - 1) < 1e-9 and math.abs(sum(DropTableData.bossGrades.raid) - 1) < 1e-9 and math.abs(sum(RareMonsterConfig.sparkleGradeChances) - 1) < 1e-9
				and DropTableData.bossGrades.firstClear.transcendent == 0.00001 and DropTableData.bossGrades.raid.transcendent == 0.000002 and RareMonsterConfig.sparkleGradeChances.transcendent == 0.000005)
		local rowOk = true
		for tier = 1, 6 do
			local row = DropTable.gradeRow(tier)
			rowOk = rowOk and math.abs(sum(row) - 1) < 1e-9 and (row.transcendent or 0) > 0
		end
		check(("잡몹 분포 합 1(초월 별도 굴림 tier1 %.9f · tier6 %.9f = ×0.7 / ×1.4)"):format(DropTable.transcendentBaseRate(1), DropTable.transcendentBaseRate(6)),
			rowOk and math.abs(DropTable.transcendentBaseRate(1) - 0.0000001 * 0.7) < 1e-15 and math.abs(DropTable.transcendentBaseRate(6) - 0.0000001 * 1.4) < 1e-15)
		local item = Loot.buildFixedArmorDrop("transcendent", "gloves", 100, 1, "bow")
		check(("초월 드랍 = special %s(장갑 = 환영) · 기본 잠금 %s"):format(tostring(item.special), tostring(item.locked)), item.special == "phantom" and item.locked == true)
		check(("각성: 초월 무료(비용 %d) · 허용 · 분해 금지 · 판매 금지 데이터"):format(Awaken.cost(1000, item)), Awaken.cost(1000, item) == 0 and Awaken.blockReason(item, 1000) == nil and TranscendentData.dismantleBlocked and TranscendentData.sellBlocked)
		local color = GradeColor.hex("transcendent")
		check(("등급 색 %s(금 - 보스 경고색 밖) · 특수 옵션 3부위(환영 · 광폭 · 비상)"):format(color), color == "#d6b03e" and TranscendentData.specialByPart.gloves == "phantom" and TranscendentData.specialByPart.armor == "frenzy" and TranscendentData.specialByPart.shoes == "soar")
	end)

	print(("===C5 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

return V
