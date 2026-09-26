-- G1-2 자동 검증(docs/phase/G1-2-report.md) - 드랍 공정성 보정 · 분해 기준 데이터 · 줍는 순간 자동 처리.
--   (가) 보정 식(한 방 = 1/H · 느린 처치 = 1 · tier1 = 1 · 세기 0 = 1) · 시간당 장비 가치 tier 간 같음 · 옛 호출(처치 시간 없음) 불변 · 분해 문턱 = 옵션 문턱 · 저장 v36 이관 · 검사
--   (나) 실제 Player: 자동 처리(영웅 → 보석 · 희귀 → 골드 · 전설 → 가방 · 잠긴 영웅 → 가방 · 끔 → 가방) · 처치 시간 측정(MonsterState.getKillSecondsFor)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local Loot = require(ReplicatedStorage.Shared.Loot)

local G1_2Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			r.check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end
	function r.summary()
		return passCount, totalCount
	end
	return r
end

local function near(a, b, tol)
	return math.abs(a - b) <= (tol or 1e-9)
end

local function hpUnits(tierIndex)
	return MonsterData[MonsterData.tierOrder[tierIndex]].rewardRatio ^ MonsterData.fairnessExponent
end

function G1_2Verify.runPure()
	print("===G1-2 검증 시작(가)===")
	local r = newRecorder("가")
	local config = DropTableData.fairness

	-- G2a: 데이터 세기 = 0.5(사용자 결정). 식 자체는 세기 1(전부)에서 재고, 지금 값은 따로 본다.
	local liveStrength = config.strength
	r.section("세기 데이터", function()
		local H6 = hpUnits(6)
		local c = DropTable.timeFairnessFactor(0.05, H6)
		r.check(("세기 %.2f(기대 0.5 - G2a 사용자 결정) · 드래곤 한 방 c %.4f(기대 1 − 0.5 × (1 − 1/H) = %.4f)"):format(liveStrength, c, 1 - 0.5 * (1 - 1 / H6)),
			liveStrength == 0.5 and near(c, 1 - 0.5 * (1 - 1 / H6), 1e-9))
	end)
	config.strength = 1

	r.section("보정 식", function()
		local H6 = hpUnits(6)
		local oneShot = DropTable.timeFairnessFactor(0.05, H6)
		local slow = DropTable.timeFairnessFactor(600, H6)
		local tier1 = DropTable.timeFairnessFactor(0.05, 1)
		local noTime = DropTable.timeFairnessFactor(nil, H6)
		local saved = config.strength
		config.strength = 0
		local off = DropTable.timeFairnessFactor(0.05, H6)
		config.strength = saved
		r.check(("드래곤 H %.2f: 한 방 c %.4f(기대 1/H %.4f) · 600초 c %.4f(기대 ≥ 0.98 - 이동 시간이 작아질수록 1) · tier1 %.2f · 처치 시간 없음 %.2f · 세기 0 %.2f(기대 1 · 1 · 1)"):format(
			H6, oneShot, 1 / H6, slow, tier1, noTime, off),
			near(oneShot, 1 / H6, 1e-9) and slow >= 0.98 and tier1 == 1 and noTime == 1 and off == 1)
		-- 옛 호출(처치 시간 없음)은 옛 값 그대로
		local tierData = MonsterData[MonsterData.tierOrder[6]]
		local old = ArmorData.dropChance * tierData.dropCountMultiplier * 1.5
		r.check(("옛 호출 Loot.expectedArmorDropCount(6, 1.5) = %.6f(기대 %.6f - 처치 시간을 안 주면 보정 없음)"):format(Loot.expectedArmorDropCount(6, 1.5), old),
			near(Loot.expectedArmorDropCount(6, 1.5), old, 1e-12))
	end)

	r.section("시간당 장비 가치 tier 간 같음", function()
		-- tier1을 k1초에 잡는 사람: tier t 처치 시간 = k1 × H(t). 시간당 가치 = 처치당 가치(H × c) ÷ (max(k, 하한) + 이동). tier1 대비 비.
		local lines, ok = {}, true
		for _, k1 in ipairs({ 0.1, 0.5, 1, 3 }) do
			local base = 1 / (math.max(k1, config.killFloorSeconds) + config.travelSeconds)
			local parts = {}
			for tierIndex = 1, #MonsterData.tierOrder do
				local H = hpUnits(tierIndex)
				local k = k1 * H
				local spent = math.max(k, config.killFloorSeconds) + config.travelSeconds
				local before = H / spent / base
				local after = H * DropTable.timeFairnessFactor(k, H) / spent / base
				ok = ok and after <= 1 + 1e-9 and after >= 0.999
				table.insert(parts, ("t%d %.2f→%.2f"):format(tierIndex, before, after))
			end
			table.insert(lines, ("tier1 %.1f초: %s"):format(k1, table.concat(parts, " ")))
		end
		r.check(("시간당 장비 가치(tier1 = 1, 보정 전 → 후 · 세기 1) %s(기대 보정 후 전부 1.00)"):format(table.concat(lines, " | ")), ok)
	end)
	config.strength = liveStrength

	r.section("분해 문턱 · 자동 처리 데이터", function()
		local choices = ArmorData.autoProcessGradeChoices
		local maxIndex = table.find(ArmorData.gradeOrder, choices[1])
		r.check(("분해 문턱 %d = 옵션 문턱 %d · 자동 처리 기준 [%s](가장 높은 = %s · 번호 %d = 분해 문턱 이하)"):format(ArmorData.dismantleMinGradeIndex, OptionData.minGradeIndex,
			table.concat(choices, ","), choices[1], maxIndex or -1),
			ArmorData.dismantleMinGradeIndex == OptionData.minGradeIndex and maxIndex == ArmorData.dismantleMinGradeIndex)
	end)

	r.section("저장 v36", function()
		local SaveSystem = require(script.Parent.SaveSystem)
		local old = SaveSystem.defaultProfile()
		old.version = 35
		old.autoProcess = nil
		local migrated = SaveSystem.migrate(old)
		local bad = SaveSystem.defaultProfile()
		bad.autoProcess = { enabled = true, maxGrade = "legendary" }
		local bad2 = SaveSystem.defaultProfile()
		bad2.autoProcess = { enabled = "yes", maxGrade = "epic" }
		r.check(("SAVE_VERSION %d(기대 36) · v35 → v%d autoProcess 끔 %s · 기준 %s · 검사 %s · 전설 기준 거절 %s · 잘못된 켜짐 값 거절 %s"):format(SaveConfig.saveVersion, migrated.version,
			tostring(migrated.autoProcess and migrated.autoProcess.enabled == false), tostring(migrated.autoProcess and migrated.autoProcess.maxGrade),
			tostring(SaveSystem.isValidProfile(migrated)), tostring(not SaveSystem.isValidProfile(bad)), tostring(not SaveSystem.isValidProfile(bad2))),
			SaveConfig.saveVersion == 36 and migrated.version == 36 and migrated.autoProcess.enabled == false and migrated.autoProcess.maxGrade == "epic"
				and SaveSystem.isValidProfile(migrated) and not SaveSystem.isValidProfile(bad) and not SaveSystem.isValidProfile(bad2))
	end)

	local pass, count = r.summary()
	print(("===G1-2 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

function G1_2Verify.runLive(player, env)
	print("===G1-2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local MonsterState = require(script.Parent.MonsterState)

	r.section("자동 처리", function()
		local profile = PlayerProfile.getProfile(player)
		local classState = profile.classes[profile.classId]
		local function item(grade, locked)
			local made = Loot.rollBossRetryDrop(100, profile.classId)
			made.grade, made.locked = grade, locked == true
			return made
		end
		local function run(label, enabled, grade, locked, expect)
			PlayerProfile.setAutoProcess(player, enabled, "epic")
			local bag, gems, gold = #profile.inventory, #classState.gemInventory, profile.gold
			local it = item(grade, locked)
			local price = Loot.getSellPrice(it)
			local ok = PlayerProfile.addArmorDrop(player, it)
			local dBag, dGems, dGold = #profile.inventory - bag, #classState.gemInventory - gems, profile.gold - gold
			local pass = ok and ((expect == "gem" and dBag == 0 and dGems == 1 and dGold == 0) or (expect == "gold" and dBag == 0 and dGems == 0 and dGold == price)
				or (expect == "bag" and dBag == 1 and dGems == 0 and dGold == 0))
			r.check(("%s: 가방 %+d · 보석 %+d · 골드 %+d(판매가 %d) - 기대 %s"):format(label, dBag, dGems, dGold, price, expect), pass)
		end
		-- 가방이 가득이면 "가방" 경우가 거절되므로 한 칸 비운다(백업이 되돌림)
		if #profile.inventory >= profile.inventorySlots then
			table.remove(profile.inventory)
		end
		run("켜짐(영웅 이하) · 영웅", true, "epic", false, "gem")
		run("켜짐 · 희귀", true, "rare", false, "gold")
		run("켜짐 · 전설(기준 위)", true, "legendary", false, "bag")
		if #profile.inventory >= profile.inventorySlots then
			table.remove(profile.inventory)
		end
		run("켜짐 · 잠긴 영웅", true, "epic", true, "bag")
		if #profile.inventory >= profile.inventorySlots then
			table.remove(profile.inventory)
		end
		run("꺼짐 · 영웅", false, "epic", false, "bag")
		local attr = player:GetAttribute("AutoProcess")
		PlayerProfile.setAutoProcess(player, true, "rare")
		local attrOn = player:GetAttribute("AutoProcess")
		local rejected = not PlayerProfile.setAutoProcess(player, true, "legendary")
		r.check(("Attribute: 끔 %s(기대 off) · 희귀 이하 %s(기대 rare) · 전설 기준 거절 %s"):format(tostring(attr), tostring(attrOn), tostring(rejected)),
			attr == "off" and attrOn == "rare" and rejected)
	end)

	r.section("처치 시간 측정", function()
		local model = nil
		for _, m in ipairs(MonsterState.getAllModels()) do
			local data = MonsterState.getData(m)
			if data and not data.isBoss and not MonsterState.isChest(m) and not MonsterState.isRescueTarget(m) and not model and MonsterState.getKillSecondsFor(m, player) == nil then
				model = m
			end
		end
		assert(model, "잡몹이 없다")
		local before = MonsterState.getKillSecondsFor(model, player)
		-- C1: 실제 공격과 같은 스테이지로 때린다(옛 = 1 고정 - 몹이 이 Player를 쫓으면 MonsterAI의 참여 기록(실제 스테이지)과 달라 기록이 지워졌다)
		MonsterState.applyDamage(model, 0, require(script.Parent.TutorialState).getMonsterStage(player), player)
		local hitAt = os.clock()
		task.wait(0.3)
		local measured = MonsterState.getKillSecondsFor(model, player)
		local elapsed = os.clock() - hitAt -- Play 3: 경제 시뮬과 겹치면 task.wait가 늘어난다 - 기대는 실제 경과
		MonsterState.clearPlayerContributions(player)
		local cleared = MonsterState.getKillSecondsFor(model, player)
		r.check(("잡몹 한 대 뒤: 측정 %s → %.2f초(기대 실제 경과 %.2f · 한 대 상한 %.1f 이하) · 퇴장 정리 뒤 %s(기대 nil)"):format(tostring(before), measured or -1, elapsed,
			DropTableData.fairness.maxSecondsPerHit, tostring(cleared)),
			measured ~= nil and near(measured, math.min(elapsed, DropTableData.fairness.maxSecondsPerHit), 0.05) and cleared == nil)
	end)

	env.restore(player)
	local pass, count = r.summary()
	print(("===G1-2 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G1_2Verify
