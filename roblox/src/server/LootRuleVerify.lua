-- S01 자동 검증(PRD 20.82) - 드랍 itemLevel = 기준 스테이지 ± 2 · 보스 드랍 가방 직행 · 계정 최고 스테이지.
-- 26-2 · 29-x 검증과 같은 모양이고 DevTools가 부른다.
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이). Loot · MonsterData의 규칙 그대로.
--   (나) 실제 경로 - 실제 Player의 프로필 · 실제 처치 경로(applyDamage → resolveHit)를 그대로 탄다. 보스 검증 체인의 끝에서 돈다.
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼.
-- 검증이 만든 것(땅의 드랍 모델 · 가방 안의 아이템 · 보스 · 프로필 값 · 캐릭터 위치)은 (나)가 끝날 때 전부 되돌린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local Loot = require(ReplicatedStorage.Shared.Loot)
local BossEncounter = require(script.Parent.BossEncounter)
local CombatResolution = require(script.Parent.CombatResolution)
local InventorySync = require(script.Parent.InventorySync)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)

local LootRuleVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S01][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

-- ─────────────────────────── (가) 순수 함수 ───────────────────────────

-- 삼각 분포 90,000회 / 보스 60,000회 - 표본 오차의 6σ 안쪽이라 정상 코드에서 우연히 실패하지 않는다.
local function checkDeltaDistribution(r)
	r.section("[1][2] 일반 δ 분포", function()
		local counts, minLevel, maxLevel = {}, math.huge, -math.huge
		local samples = 90000
		for _ = 1, samples do
			local level = Loot.rollItemLevel(100, ArmorData.itemLevelDelta)
			counts[level] = (counts[level] or 0) + 1
			minLevel, maxLevel = math.min(minLevel, level), math.max(maxLevel, level)
		end
		local expected = { [98] = 1 / 9, [99] = 2 / 9, [100] = 3 / 9, [101] = 2 / 9, [102] = 1 / 9 }
		local rows, allOk = {}, true
		for level = 98, 102 do
			local share = (counts[level] or 0) / samples
			allOk = allOk and math.abs(share - expected[level]) <= 0.01
			table.insert(rows, ("%d=%.1f%%"):format(level, share * 100))
		end
		r.check(("① rollItemLevel(100) %d회: %s (기대 11.1/22.2/33.3/22.2/11.1 ±1%%p) · 최소 %d 최대 %d(기대 98 · 102)"):format(
			samples, table.concat(rows, " "), minLevel, maxLevel), allOk and minLevel == 98 and maxLevel == 102)

		local below = 0
		for _ = 1, 10000 do
			if Loot.rollItemLevel(1, ArmorData.itemLevelDelta) < 1 then
				below += 1
			end
		end
		r.check(("② rollItemLevel(1) 10,000회 중 1 미만 %d건(기대 0)"):format(below), below == 0)
	end)
end

local function checkBossDelta(r)
	r.section("[3] 보스 δ 분포", function()
		local counts, negative = {}, 0
		local samples = 60000
		for _ = 1, samples do
			local delta = Loot.rollItemLevel(100, ArmorData.bossItemLevelDelta) - 100
			counts[delta] = (counts[delta] or 0) + 1
			if delta < 0 then
				negative += 1
			end
		end
		-- P2.5c 결정 6: 편차는 표에서 읽는다(+0 · +7 · +15 - 옛 +0 · +1 · +2의 힘 비율 환산). 가중치 3 : 2 : 1은 그대로.
		local expected, totalWeight = {}, 0
		for _, entry in ipairs(ArmorData.bossItemLevelDelta) do
			totalWeight += entry.weight
		end
		for _, entry in ipairs(ArmorData.bossItemLevelDelta) do
			expected[entry.delta] = entry.weight / totalWeight
		end
		local rows, allOk = {}, true
		for _, entry in ipairs(ArmorData.bossItemLevelDelta) do
			local delta = entry.delta
			local share = (counts[delta] or 0) / samples
			allOk = allOk and math.abs(share - expected[delta]) <= 0.01
			table.insert(rows, ("+%d=%.1f%%"):format(delta, share * 100))
		end
		allOk = allOk and #ArmorData.bossItemLevelDelta == 3 and ArmorData.bossItemLevelDelta[2].delta == 7 and ArmorData.bossItemLevelDelta[3].delta == 15
		r.check(("보스 δ %d회: %s (기대 +0 · +7 · +15 = 50/33.3/16.7 ±1%%p) · 음수 %d건(기대 0)"):format(samples, table.concat(rows, " "), negative),
			allOk and negative == 0)
	end)
end

local function checkExpectedCounts(r)
	r.section("[4] tier별 기대 드랍 수", function()
		-- P2.5a: 등급 배율 ×1.45(R3)가 tier 공정성 r(t)의 입력이라 기대 개수(= dropChance × r(t))가 바뀌었다 - 옛 0.25 · 0.31 · 0.40 · 0.57 · 0.79 · 1.05.
		local expected = {}
		for tierIndex = 1, 6 do
			expected[tierIndex] = ArmorData.dropChance * MonsterData.getRewardRatio(tierIndex)
		end
		local rows, allOk = {}, true
		for tierIndex = 1, #expected do
			local value = Loot.expectedArmorDropCount(tierIndex, 1)
			allOk = allOk and math.abs(value - expected[tierIndex]) <= 0.01
			table.insert(rows, ("tier%d=%.4f"):format(tierIndex, value))
		end
		r.check(("rewardMultiplier=1: %s (기대 dropChance × r(t) ±0.01 - P2.5a 등급 배율)"):format(table.concat(rows, " ")), allOk)
	end)
end

-- tier6 · 보상 배율 3으로 20,000회 - [5]와 [6]이 같은 표본을 쓴다(나온 아이템 전부의 itemLevel).
local function checkTier6Drops(r)
	r.section("[5][6] tier6 다중 드랍 · itemLevel", function()
		local classId = ClassData.order[1]
		local rolls, total = 20000, 0
		local countKinds, itemCount, lowest, highest, over102 = {}, 0, math.huge, -math.huge, 0
		for _ = 1, rolls do
			local items = Loot.rollArmorDrop(100, 6, 3, classId)
			countKinds[#items] = (countKinds[#items] or 0) + 1
			total += #items
			for _, item in ipairs(items) do
				itemCount += 1
				lowest, highest = math.min(lowest, item.itemLevel), math.max(highest, item.itemLevel)
				if item.itemLevel > 102 then
					over102 += 1
				end
			end
		end
		local mean = total / rolls
		-- P2.5a: 기대 = 3 × tier6 기대 개수(r(t)가 바뀌어 옛 3.15가 아니다) · 나오는 개수는 그 값의 내림 또는 올림만.
		local expectedMean = 3 * Loot.expectedArmorDropCount(6, 1)
		local onlyThreeOrFour = true
		local kinds = {}
		for count, times in pairs(countKinds) do
			onlyThreeOrFour = onlyThreeOrFour and (count == math.floor(expectedMean) or count == math.floor(expectedMean) + 1)
			table.insert(kinds, ("%d개=%d회"):format(count, times))
		end
		table.sort(kinds)
		r.check(("⑤ tier6 · 배율 3 · %d회: 평균 %.4f개(기대 %.4f ±0.05) · %s(내림 또는 올림만)"):format(
			rolls, mean, expectedMean, table.concat(kinds, " ")), math.abs(mean - expectedMean) <= 0.05 and onlyThreeOrFour)
		r.check(("⑥ tier6 · 스테이지 100 · 아이템 %d개 전부의 itemLevel: 최소 %d 최대 %d · 102 초과 %d건(기대 98 ~ 102 · 420 같은 값 0건) ★진짜 합격 기준"):format(
			itemCount, lowest, highest, over102), itemCount > 0 and lowest >= 98 and highest <= 102 and over102 == 0)
	end)
end

local function checkBossRetryAndFixed(r)
	r.section("[7] 보스 재도전 드랍", function()
		local tier1Table = MonsterData.dropGradeTableByTier[1]
		local classId = ClassData.order[1]
		local bossStage, samples = 50, 1000
		local badGrade, belowStage, notSingle, badTier = 0, 0, 0, 0
		for _ = 1, samples do
			local item = Loot.rollBossRetryDrop(bossStage, classId)
			if type(item) ~= "table" or item.grade == nil then
				notSingle += 1 -- 배열이 아니라 아이템 하나여야 한다(확정 1개)
			else
				if not tier1Table[item.grade] then
					badGrade += 1
				end
				if item.itemLevel < bossStage then
					belowStage += 1
				end
				if item.tierIndex ~= 1 or item.dropStage ~= bossStage then
					badTier += 1
				end
			end
		end
		r.check(("rollBossRetryDrop(%d) %d회: 확정 1개 아님 %d · tier1 표에 없는 등급 %d · itemLevel < 보스 스테이지 %d · tierIndex/dropStage 어긋남 %d (기대 전부 0)"):format(
			bossStage, samples, notSingle, badGrade, belowStage, badTier), notSingle == 0 and badGrade == 0 and belowStage == 0 and badTier == 0)
	end)

	r.section("[8] 고정 지급", function()
		local item = Loot.buildFixedArmorDrop("rare", "gloves", 12, 2, ClassData.order[1])
		r.check(("buildFixedArmorDrop(stage 12): itemLevel=%d dropStage=%d grade=%s part=%s (기대 12 · 12 · rare · gloves)"):format(
			item.itemLevel, item.dropStage, item.grade, item.part),
			item.itemLevel == 12 and item.dropStage == 12 and item.grade == "rare" and item.part == "gloves" and item.tierIndex == 2)
	end)
end

-- 이름만 바뀌었다(itemLevelBonus → dropCountMultiplier) - 공정성 항등식 rewardPerTime은 S01 전과 같아야 한다.
-- 1.3053은 S01 착수 전 로컬 하네스로 잰 tier1 ~ 6 공통값이다. P2.5a: 등급 배율 ×1.45(R3)로 공통값이 1.2373이 됐다 - 항등식(tier 전부 같은 값)은 그대로.
local FAIRNESS_BASELINE = 1.23728

local function checkFairness(r)
	r.section("[9] 공정성 항등식", function()
		local rows, allOk = {}, #MonsterData.fairnessCheck == 6
		for _, row in ipairs(MonsterData.fairnessCheck) do
			allOk = allOk and math.abs(row.rewardPerTime - FAIRNESS_BASELINE) <= 1e-5
			table.insert(rows, ("tier%d=%.6f"):format(row.tier, row.rewardPerTime))
		end
		r.check(("fairnessCheck rewardPerTime: %s (기대 전부 %.4f - P2.5a 등급 배율 뒤의 공통값)"):format(table.concat(rows, " "), FAIRNESS_BASELINE), allOk)
	end)
end

function LootRuleVerify.runPure()
	print("===S01 검증 시작(가: 드랍 규칙 순수 함수)===")
	local r = newRecorder("가")
	checkDeltaDistribution(r)
	checkBossDelta(r)
	checkExpectedCounts(r)
	checkTier6Drops(r)
	checkBossRetryAndFixed(r)
	checkFairness(r)
	local pass, total = r.summary()
	print(("===S01 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 경로 ───────────────────────────

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

-- 이 플레이어 것인 땅의 드랍 모델 중 before(집합)에 없는 것.
local function newGroundDrops(player, before)
	local found = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not before[model] and ItemDropState.getOwnerId(model) == player.UserId and model.Parent then
			table.insert(found, model)
		end
	end
	return found
end

local function groundSet()
	local set = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		set[model] = true
	end
	return set
end

local function clearGroundDrops(models)
	for _, model in ipairs(models) do
		if model.Parent then
			ItemDropSpawner.despawn(model)
		end
	end
end

-- 실제 tier 구역 잡몹을 실제 처치 경로로 want마리 잡는다(구역 몬스터는 5초 뒤 스스로 리스폰하므로 부족하면 기다렸다 다시 훑는다).
-- 몬스터는 플레이어에게서 먼 구역에 있어 드랍이 발밑에 떨어져 자동 줍기(가방 변경)가 일어나는 일이 없다 - 그래도 가방은 따로 읽는다.
local function killZoneMobs(player, tierIndex, want, stage)
	local killed, rounds = 0, 0
	while killed < want and rounds < 10 do
		rounds += 1
		for _, model in ipairs(MonsterState.getAllModels()) do
			if killed >= want then
				break
			end
			local data = MonsterState.getData(model)
			if data and data.tierIndex == tierIndex and not data.isBoss and not data.isChest and not MonsterState.isRescueTarget(model)
				and MonsterState.getZoneKey(model) and model.PrimaryPart then
				local isDead = MonsterState.applyDamage(model, 1e12, stage, player)
				MonsterSpawner.updateHpLabel(model)
				CombatResolution.resolveHit(player, model, isDead)
				killed += 1
			end
		end
		if killed < want then
			task.wait(WorldConfig.zoneMonsterGrid.respawnDelaySeconds + 1)
		end
	end
	return killed, rounds
end

local function spawnBossAt(player, env, stage)
	BossEncounter.despawnFor(player)
	env.applyStage(player, stage)
	BossEncounter.spawnFor(player, stage)
	local model = BossEncounter.getActive(player)
	return model, model and MonsterState.getData(model)
end

-- 보스를 실제 처치 경로로 잡는다(bosskilltest와 같은 호출 - resolveHit이 handleBossDeath · 복귀 텔레포트 · despawn까지 전부 탄다).
local function killBoss(player, model, data, stage)
	local isDead = MonsterState.applyDamage(model, data.hp * 100, stage, player)
	MonsterSpawner.updateHpLabel(model)
	CombatResolution.resolveHit(player, model, isDead)
end

local function runTier6Mobs(player, env, r, profile, root)
	local stageWanted, kills = 40, 30
	r.section("[10] 레벨 100 · 스테이지 40 · tier6 잡몹 처치", function()
		local classId = PlayerProfile.getClassId(player)
		if not classId then
			classId = ClassData.order[1]
			PlayerProfile.setClassId(player, classId)
		end
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(100))
		env.applyStage(player, stageWanted)
		local level, monsterStage = PlayerProfile.getCharacterLevel(player), TutorialState.getMonsterStage(player)
		if monsterStage ~= stageWanted then
			r.check(("준비 실패: 처치 기준 스테이지 %s(기대 %d) - 견습 진행 중이면 그 단계의 스테이지가 쓰인다"):format(tostring(monsterStage), stageWanted), false)
			return
		end

		local before = groundSet()
		local bagBefore = #profile.inventory
		local killed, rounds = killZoneMobs(player, 6, kills, stageWanted)

		local levels, lowest, highest = {}, math.huge, -math.huge
		local function take(item)
			table.insert(levels, item.itemLevel)
			lowest, highest = math.min(lowest, item.itemLevel), math.max(highest, item.itemLevel)
		end
		local models = newGroundDrops(player, before)
		for _, model in ipairs(models) do
			take(ItemDropState.getItem(model))
		end
		for index = bagBefore + 1, #profile.inventory do -- 혹시 자동 줍기가 일어났어도 놓치지 않는다
			take(profile.inventory[index])
			profile.inventory[index] = nil
		end
		clearGroundDrops(models)
		r.check(("레벨 %s · 스테이지 %d · tier6 %d마리 처치(%d회 훑음) → 드랍 %d개, itemLevel %s ~ %s (기대 전부 %d ~ %d - 레벨 100이 아니라 스테이지 40을 따른다) ★진짜 합격 기준"):format(
			tostring(level), stageWanted, killed, rounds, #levels, tostring(lowest), tostring(highest), stageWanted - 2, stageWanted + 2),
			killed == kills and #levels > 0 and lowest >= stageWanted - 2 and highest <= stageWanted + 2)
	end)
end

-- 첫 클리어(가방에 빈칸) → 가방에 바로 들어온다 / 재도전 + 가방 가득 → 복귀한 자리 발밑에 1개
local function runBossDrops(player, env, r, profile, root)
	local stage = 2 * BossData.stageInterval

	r.section("[11] 보스 첫 클리어 · 가방 직행", function()
		PlayerProfile.clearBossFirstClearRewards(player, stage)
		table.clear(profile.inventory)
		local model, data = spawnBossAt(player, env, stage)
		if not model then
			r.check("보스 스폰 실패", false)
			return
		end
		local arenaPosition = model.PrimaryPart.Position
		local before = groundSet()
		local bagBefore = #profile.inventory
		local toBagBefore = CombatResolution.dropStats()
		killBoss(player, model, data, stage)
		local toBagAfter = CombatResolution.dropStats()
		local grounded = newGroundDrops(player, before)
		local item = profile.inventory[#profile.inventory]
		local levelOk = item ~= nil and item.itemLevel >= stage and item.itemLevel <= stage + 2 and item.dropStage == stage and item.tierIndex == 1
		clearGroundDrops(grounded)
		r.check(("첫 클리어 처치(스테이지 %d, 아레나 z=%.0f): 가방 %d → %d(기대 +1) · 땅의 드랍 모델 %d개(기대 0) · ItemPickedUp 발신 %d회(기대 1) · 아이템 itemLevel=%s dropStage=%s(기대 %d ~ %d · %d) · 첫 클리어 표시=%s ★진짜 합격 기준"):format(
			stage, arenaPosition.Z, bagBefore, #profile.inventory, #grounded, toBagAfter - toBagBefore, tostring(item and item.itemLevel),
			tostring(item and item.dropStage), stage, stage + 2, stage, tostring(PlayerProfile.hasBossFirstClearReward(player, stage))),
			#profile.inventory == bagBefore + 1 and #grounded == 0 and toBagAfter - toBagBefore == 1 and levelOk
				and PlayerProfile.hasBossFirstClearReward(player, stage))
	end)

	r.section("[12] 보스 재도전 · 가방 가득 → 복귀한 자리 발밑", function()
		local filler = { grade = "normal", part = "armor", dropStage = 1, itemLevel = 1, tierIndex = 1, locked = true }
		table.clear(profile.inventory)
		for index = 1, profile.inventorySlots do
			profile.inventory[index] = table.clone(filler)
		end
		local model, data = spawnBossAt(player, env, stage)
		if not model then
			r.check("보스 스폰 실패", false)
			return
		end
		local arenaPosition = model.PrimaryPart.Position
		local before = groundSet()
		local toBagBefore, toGroundBefore, noticesBefore = CombatResolution.dropStats()
		killBoss(player, model, data, stage)
		local toBagAfter, toGroundAfter, noticesAfter = CombatResolution.dropStats()
		local grounded = newGroundDrops(player, before)
		local afterRoot = rootOf(player)
		local drop = grounded[1]
		local dropItem = drop and ItemDropState.getItem(drop)
		local distanceToPlayer = (drop and drop.PrimaryPart and afterRoot) and (drop.PrimaryPart.Position - afterRoot.Position).Magnitude or math.huge
		local distanceToArena = (drop and drop.PrimaryPart) and (drop.PrimaryPart.Position - arenaPosition).Magnitude or 0
		local returned = afterRoot ~= nil and (afterRoot.Position - BossEncounter.huntingGroundReturnPosition()).Magnitude <= 10
		local gradeOk = dropItem ~= nil and MonsterData.dropGradeTableByTier[1][dropItem.grade] ~= nil
			and dropItem.itemLevel >= stage and dropItem.itemLevel <= stage + 2
		local alreadyNotified = drop ~= nil and ItemDropState.isFullNotified(drop)
		local bagUnchanged = #profile.inventory == profile.inventorySlots
		clearGroundDrops(grounded)
		r.check(("재도전 처치(가방 가득): 땅의 드랍 모델 %d개(기대 1) · 플레이어까지 %.1fstud(기대 ≤ 10) · 아레나까지 %.0fstud(기대 멀리) · 캐릭터가 사냥터로 복귀=%s · 가방 직행 %d회(기대 0) · 땅 스폰 %d회(기대 1) · 가득 알림 %d회(기대 1) · 줍기 판정의 중복 알림 차단=%s · 가방 그대로=%s · 아이템 등급/itemLevel 정상=%s ★진짜 합격 기준"):format(
			#grounded, distanceToPlayer, distanceToArena, tostring(returned), toBagAfter - toBagBefore, toGroundAfter - toGroundBefore,
			noticesAfter - noticesBefore, tostring(alreadyNotified), tostring(bagUnchanged), tostring(gradeOk)),
			#grounded == 1 and distanceToPlayer <= 10 and distanceToArena > 500 and returned and toBagAfter - toBagBefore == 0
				and toGroundAfter - toGroundBefore == 1 and noticesAfter - noticesBefore == 1 and alreadyNotified and bagUnchanged and gradeOk)
	end)
end

local function runAccountBestStage(player, env, r, profile)
	r.section("[13] 계정 최고 스테이지", function()
		local classA, classB = ClassData.order[1], ClassData.order[2]
		profile.classes[classA].stageProgress.infiniteBest = 3000 -- P2.5a: 골드 성장률 1.001이라 80과 1의 가격이 같아 3000으로(가격 차이가 보이는 값)
		profile.classes[classB].stageProgress.infiniteBest = 10
		env.applyStage(player, 1) -- 지금 서 있는 스테이지 1 - Attribute 갱신도 이 호출이 탄다
		local activeBest = PlayerProfile.getInfiniteStageBest(player)
		local accountBest = PlayerProfile.getAccountBestStage(player)
		local attribute = player:GetAttribute("AccountBestStage")
		-- 가격 식은 GemServer의 지역 함수라 직접 부를 수 없다 - 같은 식(InfiniteStage.getGoldReward × 배수)에 계정 최고를 넣은 값과,
		-- 지금 스테이지(1)를 넣은 값이 서로 다름(= 스테이지 1로 내려가 싸게 사는 길이 닫혔다)을 확인한다.
		local priceAtBest = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, accountBest) * GemData.rerollTicketGoldMultiplier
		local priceAtStage1 = InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, 1) * GemData.rerollTicketGoldMultiplier
		r.check(("직업 %s best 3000 · 직업 %s best 10 · 지금 스테이지 1(활성 직업 best %s): getAccountBestStage=%d(기대 3000) · Attribute AccountBestStage=%s(기대 3000) · 변환권 가격 = 스테이지 3000 기준 %.0f(스테이지 1 기준 %.0f보다 큼=%s)"):format(
			classA, classB, tostring(activeBest), accountBest, tostring(attribute), priceAtBest, priceAtStage1, tostring(priceAtBest > priceAtStage1)),
			accountBest == 3000 and attribute == 3000 and priceAtBest > priceAtStage1)
	end)
end

function LootRuleVerify.runLive(player, env)
	print("===S01 검증 시작(나: 실제 서버 경로)===")
	local r = newRecorder("나")
	local profile = PlayerProfile.getProfile(player)
	local root = rootOf(player)
	if not profile or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S01 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	-- 되돌릴 것: 가방(S04 사전 작업부터 restoreForDevTools도 되돌리지만 이 검증은 가방을 직접 채우고 비우므로 자기 손으로 한 번 더) · 캐릭터 위치 · 골드 · 땅의 드랍 모델.
	local savedInventory = table.clone(profile.inventory)
	local savedCFrame = root.CFrame
	local goldBefore = PlayerProfile.getGold(player)
	local groundBefore = groundSet()

	runTier6Mobs(player, env, r, profile, root)
	runBossDrops(player, env, r, profile, root)
	runAccountBestStage(player, env, r, profile)

	-- [14] 되돌리기
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	clearGroundDrops(newGroundDrops(player, groundBefore))
	table.clear(profile.inventory)
	for index, item in ipairs(savedInventory) do
		profile.inventory[index] = item
	end
	InventorySync.push(player, profile)
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end

	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	local leftovers = #newGroundDrops(player, groundBefore)
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d개 · 검증이 남긴 땅의 드랍 %d개 · 가방 %d → %d칸 · 골드 %s → %s · 활성 직업 스테이지 Attribute=%s (기대 0 · 0 · 같은 칸 · 같은 골드)"):format(
		orphans, leftovers, #savedInventory, #profile.inventory, tostring(goldBefore), tostring(PlayerProfile.getGold(player)),
		tostring(player:GetAttribute("InfiniteStage"))),
		orphans == 0 and leftovers == 0 and #profile.inventory == #savedInventory and PlayerProfile.getGold(player) == goldBefore)

	local pass, total = r.summary()
	print(("===S01 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

-- S05b(SaveKeyVerify)가 같은 보스 스폰 · 처치 헬퍼를 쓴다.
LootRuleVerify.spawnBossAt = spawnBossAt
LootRuleVerify.killBoss = killBoss

return LootRuleVerify
