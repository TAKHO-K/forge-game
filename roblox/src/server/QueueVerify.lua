-- QUEUE-10h 자동 검증(가) - 순수 값(docs/phase/QUEUE-10h-report.md). 항목마다 section 하나씩 붙인다.
--   Q0: 결정 1(드랍 개수 = killUnits × 티어 보정) · 결정 2(잡몹 태초 2/3/3 · 보스 첫 클리어 0.1%) · Q0-6 알림 범위(태초 = 같은 서버 / 초월 = 전 서버).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local V = {}

function V.runPure()
	print("===Q 검증 시작(가)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[Q][가] %s %s"):format(label, ok and "O" or "X"))
	end
	local function section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end

	section("Q0 알림 범위", function()
		-- 출처는 알림 범위를 바꾸지 않는다(범위 = 등급만의 함수) - 파티 여부 두 경우 모두 본다
		for _, inParty in ipairs({ false, true }) do
			check(("태초 = 같은 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("primordial", inParty) == "server")
			check(("초월 = 전 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("transcendent", inParty) == "global")
			check(("고대 = 같은 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("ancient", inParty) == "server")
		end
		local globals = {}
		for grade in pairs(DropNoticeData.globalGrades) do
			table.insert(globals, grade)
		end
		check(("전 서버 등급 = 초월만(%s)"):format(table.concat(globals, ",")), #globals == 1 and globals[1] == "transcendent")
	end)

	section("Q0 결정 2 드랍 가중치", function()
		local expect = { 2, 3, 3 }
		for band, w in ipairs(DropTableData.fieldGradeWeights) do
			check(("잡몹 구간 %d 태초 가중치 %d = %d · 일반 %d"):format(band, w.primordial, expect[band], w.normal), w.primordial == expect[band] and w.normal == 6100000)
		end
		local first, sum = DropTableData.bossGrades.firstClear, 0
		for _, p in pairs(first) do
			sum += p
		end
		check(("보스 첫 클리어 태초 %.4f%% · 합 %.12f"):format(first.primordial * 100, sum), math.abs(first.primordial - 0.001) < 1e-12 and math.abs(sum - 1) < 1e-9)
	end)

	section("Q0 결정 1 드랍 개수", function()
		check(("개수 식 = %s"):format(DropTableData.dropCountBasis), DropTableData.dropCountBasis == "killUnits")
		for tierIndex, key in ipairs(MonsterData.tierOrder) do
			local d = MonsterData[key]
			local want = d.killUnits * DropTableData.fieldDropCountAdjust[tierIndex]
			check(("T%d 개수 배율 %.4f = killUnits %.4f × 보정"):format(tierIndex, d.dropCountMultiplier, d.killUnits), math.abs(d.dropCountMultiplier - want) < 1e-9)
		end
	end)

	section("Q1 푸른 드래곤", function()
		local MobAttackShape = require(ReplicatedStorage.Shared.MobAttackShape)
		local SpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
		local RigSpec = require(ReplicatedStorage.Shared.data.MonsterRigSpec)
		local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
		local def = SpeciesData.species.blue_dragon
		local rig = RigSpec.rigs.blue_dragon
		check(("종 blue_dragon T%d · 무리 %d ~ %d · 링크 %s · 선공"):format(def.tier, def.groupSize[1], def.groupSize[2], tostring(def.linkAggro)),
			def.tier == 6 and def.groupSize[1] == 1 and def.groupSize[2] == 2 and def.linkAggro == false and def.aggro == "aggressive")
		check(("리그 %d파트(≤ 14) · 몸체 = MonsterData.species 연결"):format(#rig.joints), #rig.joints <= 14 and MonsterData.species.blue_dragon.rig == rig)
		local joints = {}
		for _, j in ipairs(rig.joints) do
			joints[j.name] = true
		end
		local missing = {}
		for _, attack in ipairs(def.attacks) do
			for jointName in pairs(attack.windup.poses) do
				if not joints[jointName] then
					table.insert(missing, attack.id .. "." .. jointName)
				end
			end
		end
		for jointName in pairs(def.alertPose.poses) do
			if not joints[jointName] then
				table.insert(missing, "alert." .. jointName)
			end
		end
		check(("전조 · 포효 포즈 관절 이름 = 리그 관절(없는 것 %d: %s)"):format(#missing, table.concat(missing, ",")), #missing == 0)
		local t6 = WorldMapData.zones[6]
		local pool = {}
		for _, m in ipairs(t6.hunt.monsters) do
			pool[m.species] = true
		end
		check("T6 스폰 풀 = 얼음 골렘 + 푸른 드래곤(눈토끼 retired · 데이터 유지)", pool.blue_dragon and pool.ice_golem and not pool.snow_rabbit and SpeciesData.species.snow_rabbit.retiredBy == "blue_dragon")
		local spacing = WorldMapData.spawnSites.pointSpacing
		check(("스폰 간격 %d ≥ 감지 %d × 2 + 10"):format(spacing, def.detectRadius), spacing >= def.detectRadius * 2 + 10)
		-- 모양 판정(몹 원점 · 앞 = −Z)
		local o, f = Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)
		local by = {}
		for _, a in ipairs(def.attacks) do
			by[a.id] = a
		end
		local breath, tail, gust = by.frostBreath, by.tailSweep, by.wingGust
		check("서리 숨결: 앞 10 맞음 · 옆 45° 안 맞음 · 뒤 안 맞음", MobAttackShape.contains(breath, o, f, Vector3.new(0, 0, -10))
			and not MobAttackShape.contains(breath, o, f, Vector3.new(7.07, 0, -7.07)) and not MobAttackShape.contains(breath, o, f, Vector3.new(0, 0, 5)))
		check("꼬리 휩쓸기: 뒤 8 · 옆 90° 맞음 · 앞 안 맞음", MobAttackShape.contains(tail, o, f, Vector3.new(0, 0, 8))
			and MobAttackShape.contains(tail, o, f, Vector3.new(8, 0, 0)) and not MobAttackShape.contains(tail, o, f, Vector3.new(0, 0, -5)))
		check("날개 돌풍: 원 안 맞음 · 밖 안 맞음 · 높이 차 9 안 맞음 · 넉백 조각만", MobAttackShape.contains(gust, o, f, Vector3.new(6, 0, 6))
			and not MobAttackShape.contains(gust, o, f, Vector3.new(0, 0, 11)) and not MobAttackShape.contains(gust, o, f, Vector3.new(0, 9, 0)) and gust.launch ~= nil)
		local a1 = MobAttackShape.choose(def.attacks, true, 0)
		local b1, c1 = MobAttackShape.choose(def.attacks, false, 0)
		local b2 = MobAttackShape.choose(def.attacks, false, c1)
		check(("공격 고르기: 등 뒤 = %s · 앞 = %s → %s"):format(a1.id, b1.id, b2.id), a1.id == "tailSweep" and b1.id == "frostBreath" and b2.id == "wingGust")
		local far1, cf = MobAttackShape.choose(def.attacks, false, 1, 11) -- 차례상 돌풍(10)이지만 거리 11 = 건너뛰고 숨결(14)
		local none = MobAttackShape.choose(def.attacks, false, 0, 15)
		check(("거리 조건: 11 → %s · 15 → %s"):format(far1 and far1.id or "없음", none and none.id or "없음"), far1 and far1.id == "frostBreath" and cf == 3 and none == nil)
		local Reach = require(ReplicatedStorage.Shared.Reach)
		check("몸 반경 도달: BodyRadius 없는 대상 = Reach.within과 같음", Reach.withinModel(nil, Vector3.new(10, 0, 0), Vector3.new(0, 0, 0), 10) and not Reach.withinModel(nil, Vector3.new(10.5, 0, 0), Vector3.new(0, 0, 0), 10))
		-- 초당 피해 ≈ 티어 평타(1초 주기 × 1.0): 공격 배율 ÷ 주기(전조 + 회복 + cooldown)
		local worst = 0
		for _, a in ipairs(def.attacks) do
			worst = math.max(worst, a.damage / (a.windup.seconds + a.recover + a.cooldown))
		end
		check(("한 사람 초당 피해(평타 대비) 최대 %.2f ≤ 1.0"):format(worst), worst <= 1.0 + 1e-9)
		check(("전조 초: 숨결 %.1f · 꼬리 %.1f · 돌풍 %.1f"):format(breath.windup.seconds, tail.windup.seconds, gust.windup.seconds),
			breath.windup.seconds == 0.8 and tail.windup.seconds == 0.6 and gust.windup.seconds == 0.7)
	end)

	section("Q3 보스 드랍표", function()
		local BossData = require(ReplicatedStorage.Shared.data.BossData)
		local DropTable = require(ReplicatedStorage.Shared.DropTable)
		local raidSum = 0
		for _, w in pairs(DropTableData.raidWeights) do
			raidSum += w
		end
		check(("토벌 정수 가중치 합 %d = %d"):format(raidSum, DropTableData.fieldWeightDenominator), raidSum == DropTableData.fieldWeightDenominator)
		check("보상 표시 = 굴림 표(첫 클리어 · 토벌 같은 표)", DropTable.bossFirstClearGradeTable(0) == DropTableData.bossGrades.firstClear and DropTable.bossRetryGradeTable() == DropTableData.bossGrades.raid)
		local units, gold = {}, {}
		for _, id in ipairs(BossData.pools[1].bossIds) do
			local b = BossData.bosses[id]
			table.insert(units, ("%s %.1f"):format(id, b.rewardKillUnits or b.hpMultiplier))
			gold[b.goldMultiplier or 0] = true
		end
		local sameUnits = true
		local first = BossData.bosses[BossData.pools[1].bossIds[1]]
		for _, id in ipairs(BossData.pools[1].bossIds) do
			local b = BossData.bosses[id]
			sameUnits = sameUnits and math.abs((b.rewardKillUnits or b.hpMultiplier) - (first.rewardKillUnits or first.hpMultiplier)) < 1e-9
		end
		check(("6종 강화석 단위 같음(%s)"):format(table.concat(units, " · ")), sameUnits)
		local short, full = DropTable.bossRetryGradeTable(12), DropTable.bossRetryGradeTable(200)
		local sumShort = 0
		for _, p in pairs(short) do
			sumShort += p
		end
		check(("토벌 전투 시간 공정성: 12초 태초 %.6f%% · 120초 이상 %.6f%% · 합 %.9f"):format(short.primordial * 100, full.primordial * 100, sumShort),
			math.abs(short.primordial - full.primordial * 0.1) < 1e-12 and full == DropTableData.bossGrades.raid and math.abs(sumShort - 1) < 1e-9)
	end)

	section("Q4 판매가", function()
		local Loot = require(ReplicatedStorage.Shared.Loot)
		local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
		local bad = {}
		for tierIndex = 1, 6 do
			local prev = -1
			for _, gradeId in ipairs(ArmorData.gradeOrder) do
				if gradeId ~= "transcendent" then
					local price = Loot.getSellPrice({ tierIndex = tierIndex, grade = gradeId, dropStage = 100 })
					if price <= 0 or price < prev then
						table.insert(bad, ("T%d %s %d"):format(tierIndex, gradeId, price))
					end
					prev = price
				end
			end
		end
		check(("판매가 모드 %s · 전 티어 등급 순서(위 등급 ≥ 아래 · 0 없음) 위반 %d: %s"):format(ArmorData.sellPriceMode, #bad, table.concat(bad, ", ")), #bad == 0)
		check("초월 판매가 0(판매 불가)", Loot.getSellPrice({ tierIndex = 6, grade = "transcendent", dropStage = 100 }) == 0)
		local Inherit = require(ReplicatedStorage.Shared.Inherit)
		local InheritConfig = require(ReplicatedStorage.Shared.data.InheritConfig)
		local a = { grade = "legendary", part = "gloves", itemLevel = 10 }
		local bP = { grade = "primordial", part = "gloves", itemLevel = 10, locked = false }
		check("계승 결과 태초 = 잠김", Inherit.resultItem(a, bP, "b").locked == true)
		check("계승 결과 전설 = 안 잠김", Inherit.resultItem(bP, { grade = "legendary", part = "gloves", itemLevel = 10, locked = true }, "b").locked == nil)
		check("초월 = 계승 재료 불가", Inherit.blockReason({ grade = "transcendent", part = "gloves", itemLevel = 10 }, { grade = "primordial", part = "gloves", itemLevel = 10 }, "b", true) == "a_transcendent")
		local prev, okCost = 0, true
		for _, gradeId in ipairs(ArmorData.gradeOrder) do
			local v = InheritConfig.goldKillEquivalent[gradeId]
			okCost = okCost and v ~= nil and v > prev
			prev = v or prev
		end
		check("계승비 등급 순서(초월 칸 포함)", okCost)
	end)

	section("Q5 BR2 세트 · 태그 · 저장 · 토벌", function()
		local SetBonus = require(ReplicatedStorage.Shared.SetBonus)
		local SetData = require(ReplicatedStorage.Shared.data.SetData)
		check("출처 → 세트 계열: 보스 = 관문 구역 · 잡몹 = 사냥 구역 · 개발 = 없음",
			SetBonus.zoneFromSource({ kind = "boss", bossId = "crystal_queen" }) == "tier2" and SetBonus.zoneFromSource({ kind = "raid", bossId = "frost_giant" }) == "tier6"
				and SetBonus.zoneFromSource({ kind = "field", zone = "tier3" }) == "tier3" and SetBonus.zoneFromSource({ kind = "dev" }) == nil)
		check(("세트 이름 = 구역 테마 + 세트: %s · 세대 %s"):format(tostring(SetBonus.setName("tier1", 100)), tostring(SetBonus.setName("tier1", 17500))),
			SetBonus.setName("tier1", 100) == "수호자의 석조 평원 세트" and SetBonus.setName("tier1", 17500) == "잿빛 수호자의 석조 평원 세트")
		local function eq(z1, z2, z3, stage)
			return { armor = { setZone = z1, dropStage = stage or 100 }, gloves = { setZone = z2, dropStage = stage or 100 }, shoes = { setZone = z3, dropStage = stage or 100 } }
		end
		local was = SetData.enabled
		SetData.enabled = true
		local hp2 = SetBonus.extraValues(eq("tier1", "tier1", "tier2"), "maxHpPercent")
		local fd2 = SetBonus.extraValues(eq("tier1", "tier1", "tier2"), "finalDamage")
		local fd3 = SetBonus.extraValues(eq("tier1", "tier1", "tier1"), "finalDamage")
		local fdGen = SetBonus.extraValues(eq("tier1", "tier1", "tier1", 17500), "finalDamage")
		SetData.enabled = false
		local off = SetBonus.extraValues(eq("tier1", "tier1", "tier1"), "finalDamage")
		SetData.enabled = was
		check(("2부위 = 최대 체력 %.2f · 최종 피해 없음 / 3부위 최종 피해 %.2f · 세대 1 %.3f · 스위치 끔 = 없음"):format(hp2 and hp2[1] or -1, fd3 and fd3[1] or -1, fdGen and fdGen[1] or -1),
			hp2 and hp2[1] == 0.05 and fd2 == nil and fd3 and fd3[1] == 0.05 and fdGen and math.abs(fdGen[1] - 0.055) < 1e-9 and off == nil)
		-- 저장 이관 왕복(v48 → v49): setZone은 없는 필드만 채우고 한 번 더 돌려도 같다
		local SaveSystem = require(script.Parent.SaveSystem)
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local old = { version = 48, gold = 0, classes = { greatsword = { equipment = { armor = { grade = "epic", part = "armor", source = { kind = "boss", bossId = "storm_lord" } } } } },
			inventory = { { grade = "rare", part = "gloves", source = { kind = "field", zone = "tier4" } }, { grade = "rare", part = "shoes" }, { grade = "epic", part = "shoes", setZone = "tier1", source = { kind = "field", zone = "tier3" } } } }
		local ok, migrated = pcall(SaveSystem.migrate, old)
		local m = ok and migrated or {}
		check(("이관 v48 → v%s(현재 %d): 보스 갑옷 %s · 잡몹 장갑 %s · 태그 없음 %s · 이미 있음 유지 %s"):format(tostring(m.version), SaveConfig.saveVersion,
			tostring(m.classes and m.classes.greatsword.equipment.armor.setZone), tostring(m.inventory and m.inventory[1].setZone), tostring(m.inventory and m.inventory[2].setZone), tostring(m.inventory and m.inventory[3].setZone)),
			ok and m.version == SaveConfig.saveVersion and SaveConfig.saveVersion >= 49 and m.classes.greatsword.equipment.armor.setZone == "tier5" and m.inventory[1].setZone == "tier4"
				and m.inventory[2].setZone == nil and m.inventory[3].setZone == "tier1")
		local ok2, again = pcall(SaveSystem.migrate, m)
		check("이관 두 번 = 같음(멱등)", ok2 and again.inventory[1].setZone == "tier4" and again.version == m.version)
		-- 토벌 규칙(순수 - C1 RaidRules): 스테이지 = min(선택, 최근 클리어 보스) · 미클리어 보스 스테이지 불가
		local RaidRules = require(ReplicatedStorage.Shared.RaidRules)
		local s1 = select(3, RaidRules.check({ currentStage = 47, bestBossCleared = 45, bossId = "section_guardian", remote = false }))
		local okU, whyU = RaidRules.check({ currentStage = 50, bestBossCleared = 45, bossId = "section_guardian", remote = false })
		local okR, whyR = RaidRules.check({ currentStage = 47, bestBossCleared = 45, bossId = "section_guardian", remote = true, gateUsable = false })
		check(("토벌 스테이지 47/45 → %s · 미클리어 보스 50 → %s · 원격 미등록 → %s"):format(tostring(s1), tostring(whyU), tostring(whyR)), s1 == 45 and okU == false and whyU == "boss_stage_uncleared" and okR == false and whyR == "gate_unregistered")
	end)

	section("Q6 G3 수련 · 능력 · 퀘스트", function()
		local Training = require(ReplicatedStorage.Shared.Training)
		local Quest = require(ReplicatedStorage.Shared.Quest)
		local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
		local atk = Training.statDef("attack")
		check(("수련 상한 = 최고 스테이지 ÷ 10: 스테이지 95 → %d · 능력 상한 50: 스테이지 9,999 → %d"):format(Training.capFor(atk, 95), Training.capFor(Training.abilityDef("bow", "bow_might"), 9999)),
			Training.capFor(atk, 95) == 9 and Training.capFor(Training.abilityDef("bow", "bow_might"), 9999) == 50)
		check("수련 가격 단계마다 오름 · 스테이지 따라 오름", Training.costFor(atk, 5, 100) > Training.costFor(atk, 4, 100) and Training.costFor(atk, 5, 500) > Training.costFor(atk, 5, 100))
		local bonus = Training.bucketBonus({ attack = 10, hp = 4 }, { gs_might = 5 }, "greatsword", "attack")
		local want = 10 * atk.perLevel + 5 * Training.abilityDef("greatsword", "gs_might").perLevel
		check(("공격 버킷 합연산 = %.4f · 다른 직업 능력 무시"):format(bonus), math.abs(bonus - want) < 1e-12
			and math.abs(Training.bucketBonus({ attack = 10 }, { gs_might = 5 }, "bow", "attack") - 10 * atk.perLevel) < 1e-12)
		local def = Training.axisValues({ defense = 4 }, { gs_guard = 3 }, "greatsword", "defensePercent")
		check("방어 축 = 수련 + 철벽", def and math.abs(def[1] - (4 * Training.statDef("defense").perLevel + 3 * Training.abilityDef("greatsword", "gs_guard").perLevel)) < 1e-12)
		check(("수련 최대 단계 %d(스테이지 99,999에서도)"):format(Training.capFor(atk, 99999)), Training.capFor(atk, 99999) == atk.maxLevel)
		-- 퀘스트: 같은 날 = 같은 목록(중복 없음) · 진행 → 받기 → 두 번 못 받음 · 상자 = 전부 완료 뒤
		local day = 20000
		local listA, listB = Quest.dailyFor(day), Quest.dailyFor(day)
		local ids, dup = {}, false
		for i, q in ipairs(listA) do
			dup = dup or ids[q.id] ~= nil or listB[i].id ~= q.id
			ids[q.id] = true
		end
		check(("일간 %d개 · 날짜 시드 고정 · 중복 없음"):format(#listA), #listA == QuestData.dailyCount and not dup)
		local seen, kinds = {}, 0
		for d = 20000, 20059 do
			for _, q in ipairs(Quest.dailyFor(d)) do
				if not seen[q.id] then
					seen[q.id] = true
					kinds += 1
				end
			end
		end
		check(("60일 동안 일간 풀 %d/%d종 등장(리뷰 4 - 옛 LCG는 3종 고정)"):format(kinds, #QuestData.dailyPool), kinds == #QuestData.dailyPool)
		local now = day * 86400 + 3600
		local st = Quest.newState(now)
		local first = listA[1]
		local none = Quest.claim(st, "daily", first.id, now)
		Quest.note(st, first.event, first.target, now)
		local r1 = Quest.claim(st, "daily", first.id, now)
		local r2, why2 = Quest.claim(st, "daily", first.id, now)
		check("일간: 미완료 거부 → 완료 받기 → 다시 거부(claimed)", none == nil and r1 ~= nil and r2 == nil and why2 == "claimed")
		local chestBefore = Quest.claim(st, "chest", nil, now)
		for _, q in ipairs(listA) do
			Quest.note(st, q.event, q.target, now)
		end
		local chest = Quest.claim(st, "chest", nil, now)
		local login1, login2 = Quest.claim(st, "login", nil, now), Quest.claim(st, "login", nil, now)
		check("상자 = 일간 전부 뒤 1회 · 접속 보상 하루 1회", chestBefore == nil and chest ~= nil and login1 ~= nil and login2 == nil)
		Quest.roll(st, now + 86400)
		check("날짜 넘김 = 일간 진행 · 접속 초기화", next(st.daily) == nil and Quest.claim(st, "login", nil, now + 86400) ~= nil)
		local mainNo = Quest.claim(st, "main", nil, now, { tutorialDone = false })
		local mainOk = Quest.claim(st, "main", nil, now, { tutorialDone = true })
		check(("메인: 견습 전 거부 → 뒤 받기(다음 단계 %d)"):format(st.main), mainNo == nil and mainOk ~= nil and st.main == 2)
		local SaveSystem = require(script.Parent.SaveSystem)
		local ok, m = pcall(SaveSystem.migrate, { version = 49, gold = 0, classes = { bow = { equipment = {} } }, inventory = {} })
		check(("이관 v49 → v%s: training · abilities · quests 채움"):format(ok and tostring(m.version) or "에러"),
			ok and m.version >= 50 and type(m.training) == "table" and m.training.attack == 0 and type(m.classes.bow.abilities) == "table" and type(m.quests) == "table" and m.quests.main == 1)
	end)

	section("Q8 K3 영혼", function()
		local SoulService = require(script.Parent.SoulService)
		local SoulData = require(ReplicatedStorage.Shared.data.SoulData)
		local enc = { id = "t1", model = {} }
		local a, b, c = { Name = "A", UserId = 1 }, { Name = "B", UserId = 2 }, { Name = "C", UserId = 3 }
		SoulService.onDied(a, enc, Vector3.new(0, 0, 0))
		local becameSoul = SoulService.consumePending(a, enc)
		check("보스전 사망 → 리스폰 = 영혼 · 공격 거부", becameSoul and SoulService.isSoul(a) and SoulService.rejectAction(a, "공격") and not SoulService.rejectAction(b, "공격"))
		SoulService.onDied(b, { id = "tut", isTutorial = true }, Vector3.new(0, 0, 0))
		check("견습 보스전 = 영혼 없음(옛 즉시 리스폰)", not SoulService.consumePending(b, { id = "tut", isTutorial = true }) and not SoulService.isSoul(b))
		SoulService.onDied(c, enc, Vector3.new(100, 0, 0))
		SoulService.consumePending(c, enc)
		local sanct = { center = Vector3.new(0, 0, 0), radius = 16, startedAt = os.clock() - 5 }
		local other = SoulService.reviveSanctuary(sanct, { id = "다른 보스전" })
		local d = { Name = "D", UserId = 4 }
		SoulService.onDied(d, enc, Vector3.new(2, 0, 0)) -- 리스폰 대기 중
		local n = SoulService.reviveSanctuary(sanct, enc)
		check(("성역 끝 부활 = 시전자 보스전 · 성역 안 사망자만(다른 보스전 %d명 · %d명 · A 풀림 · C 남음)"):format(other, n), other == 0 and n == 2 and not SoulService.isSoul(a) and SoulService.isSoul(c))
		local dSoul = SoulService.consumePending(d, enc)
		check("리스폰 대기 중 성역 끝 = 리스폰 때 영혼 대신 부활", not dSoul and not SoulService.isSoul(d))
		SoulService.onDied(d, { id = "잔류", model = {}, lingering = true }, Vector3.new(0, 0, 0))
		check("잔류(처치 뒤) 창 사망 = 영혼 아님", not SoulService.consumePending(d, { id = "잔류" }) and not SoulService.isSoul(d))
		SoulService.clearEncounter(enc)
		check("보스전 끝 · 전멸 = 영혼 전원 풀림", not SoulService.isSoul(c) and #SoulService.soulsOf(enc) == 0)
		local was = SoulData.enabled
		SoulData.enabled = false
		SoulService.onDied(a, enc, Vector3.new(0, 0, 0))
		local off = SoulService.consumePending(a, enc)
		SoulData.enabled = was
		check(("스위치 끔 = 영혼 없음 · 부활 체력 %.0f%%"):format(SoulData.reviveHpFraction * 100), not off and SoulData.reviveHpFraction == 0.3)
	end)

	section("Q9 K4 스킬 변형", function()
		local SkillVariant = require(ReplicatedStorage.Shared.SkillVariant)
		local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
		local sumsOk = true
		for _, classId in ipairs(ClassData.order) do
			local sum = 0
			for _, row in ipairs(SkillVariant.rows(classId)) do
				sum += row.chance
				sumsOk = sumsOk and row.slot ~= "T"
			end
			sumsOk = sumsOk and math.abs(sum - 1) < 1e-9
		end
		check("직업마다 변형 확률 합 1 · 궁극기(T) 없음", sumsOk)
		local rng = Random.new(7)
		local counts, N = {}, 20000
		for _ = 1, N do
			local v = SkillVariant.roll("bow", rng)
			local key = v.slot .. v.id
			counts[key] = (counts[key] or 0) + 1
		end
		local worst = 0
		for _, row in ipairs(SkillVariant.rows("bow")) do
			worst = math.max(worst, math.abs((counts[row.slot .. row.id] or 0) / N - row.chance))
		end
		check(("굴림 {N}회 = 공개 표(최대 오차 %.4f ≤ 0.015)"):format(worst):gsub("{N}", tostring(N)), worst <= 0.015)
		local eq = { armor = { grade = "epic", skillVariant = { classId = "bow", slot = "Q", id = "swift" } }, gloves = { grade = "relic", skillVariant = { classId = "bow", slot = "Q", id = "heavy" } },
			shoes = { grade = "legendary", skillVariant = { classId = "greatsword", slot = "E", id = "wide" } } }
		local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
		local rank = function(g)
			return table.find(ArmorData.gradeOrder, g) or 0
		end
		local q = SkillVariant.modsFor(eq, "bow", "Q", rank)
		local gsE = SkillVariant.modsFor(eq, "bow", "E", rank)
		check(("칸당 높은 등급 하나(유물 묵직하게 피해 ×%.2f) · 다른 직업 변형 = 꺼짐(×%.2f)"):format(q.damage, gsE.damage), q.id == "heavy" and q.damage == 1.05 and gsE.damage == 1 and gsE.range == 1)
		local d = SkillVariant.describe(eq.shoes.skillVariant, "bow")
		check("툴팁: 다른 직업 = 꺼짐 표시 대상", d and d.active == false and d.text:find("넓게") ~= nil)
		local sw = SkillVariant.describe({ classId = "greatsword", slot = "E", id = "swift" }, "greatsword")
		check(("툴팁 반올림: 재빠르게 = −5%%(Play E에서 −6%%로 보였다) → %s"):format(sw and sw.text or "nil"), sw and sw.text:find("피해 -5%", 1, true) ~= nil and sw.text:find("쿨다운 -5%", 1, true) ~= nil)
		local SaveSystem = require(script.Parent.SaveSystem)
		local ok, m = pcall(SaveSystem.migrate, { version = 50, gold = 0, classes = {}, inventory = { { grade = "epic", part = "armor" } }, training = { attack = 0, hp = 0, defense = 0 }, quests = { main = 1 } })
		check(("이관 v50 → v%s(변형 없는 옛 장비 그대로)"):format(ok and tostring(m.version) or "에러"), ok and m.version >= 51 and m.inventory[1].skillVariant == nil)
	end)

	section("Q11 펫", function()
		local Pet = require(ReplicatedStorage.Shared.Pet)
		local PetData = require(ReplicatedStorage.Shared.data.PetData)
		local EggData = require(ReplicatedStorage.Shared.data.EggData)
		local sumsOk, upOk = true, true
		for level = 1, #PetData.levels do
			for _, eg in ipairs(EggData.gradeOrder) do
				local t = Pet.hatchTable(eg, level)
				local sum = 0
				for _, g in ipairs(EggData.hatchGrades) do
					sum += t[g]
				end
				sumsOk = sumsOk and math.abs(sum - 100) < 1e-9
				if level > 1 then
					local prev = Pet.hatchTable(eg, level - 1)
					upOk = upOk and t.epic >= prev.epic and t.common <= prev.common
				end
			end
		end
		check("부화 확률표 = 레벨 · 알 등급마다 합 100 · 레벨이 오르면 영웅 ↑ 일반 ↓", sumsOk and upOk)
		check(("부화 레벨: 0회 %d · 3회 %d · 49회 %d · 50회 %d"):format(Pet.levelOf(0), Pet.levelOf(3), Pet.levelOf(49), Pet.levelOf(50)), Pet.levelOf(0) == 1 and Pet.levelOf(3) == 2 and Pet.levelOf(49) == 4 and Pet.levelOf(50) == 5)
		local rng = Random.new(11)
		local egg = { zone = "tier2", grade = "good", species = { "crystalBat", "prismLizard" } }
		local N, counts, first = 20000, {}, 0
		for _ = 1, N do
			local r = Pet.rollHatch(egg, 3, rng)
			counts[r.grade] = (counts[r.grade] or 0) + 1
			if r.species == "crystalBat" then
				first += 1
			end
		end
		local t, worst = Pet.hatchTable("good", 3), 0
		for _, g in ipairs(EggData.hatchGrades) do
			worst = math.max(worst, math.abs((counts[g] or 0) / N * 100 - t[g]))
		end
		check(("부화 {N}회 = 공개 표(최대 오차 %.2f%%p ≤ 1) · 종 반반 %.3f"):format(worst, first / N):gsub("{N}", tostring(N)), worst <= 1 and math.abs(first / N - 0.5) < 0.015)
		check("해금: 자동 줍기 200 · 대기열 +1 300", not Pet.unlocked(199, "autoPickup") and Pet.unlocked(200, "autoPickup") and Pet.queueCap(299) == 1 and Pet.queueCap(300) == 2)
		local bodyOk, partsOk = true, true
		for id in pairs(EggData.species) do
			bodyOk = bodyOk and PetData.rigs[PetData.bodyOf[id] or ""] ~= nil
		end
		for _, rig in pairs(PetData.rigs) do
			partsOk = partsOk and #rig <= 8
		end
		check("종 24 = 몸 틀(강아지 · 고양이 · 새끼 용) 지정 · 리그 파트 ≤ 8", bodyOk and partsOk)
		local SaveSystem = require(script.Parent.SaveSystem)
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local ok, m = pcall(SaveSystem.migrate, { version = 51, gold = 0, classes = {}, inventory = {}, eggs = { egg }, training = { attack = 0, hp = 0, defense = 0 }, quests = { main = 1 } })
		check(("이관 v51 → v%s(≥ 52): pets 빈 상태 · 알 가방 유지 · SAVE_VERSION %d"):format(ok and tostring(m.version) or "에러", SaveConfig.saveVersion),
			ok and m.version >= 52 and SaveConfig.saveVersion >= 52 and type(m.pets) == "table" and #m.pets.list == 0 and m.pets.hatchCount == 0 and #m.eggs == 1)
	end)

	section("Q12 첫 5분 이정표 · 7일 출석", function()
		local Quest = require(ReplicatedStorage.Shared.Quest)
		local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
		local now = 1790000000
		local st = Quest.newState(now)
		local _, wrong = Quest.note(st, "enhance", 1, now)
		local seq, okSeq = {}, true
		for _, step in ipairs(QuestData.ftue) do
			local _, adv = Quest.note(st, step.event, 1, now)
			okSeq = okSeq and adv ~= nil and adv.id == step.id
			table.insert(seq, step.id)
		end
		check(("이정표 %d단계 = 순서대로(엉뚱한 이벤트 무시) · 끝 = nil · 퍼널 이름 전부"):format(#QuestData.ftue), wrong == nil and okSeq and st.guide == nil)
		local funnelOk, ultStep = true, nil
		for _, step in ipairs(QuestData.ftue) do
			funnelOk = funnelOk and type(step.funnel) == "string"
			if step.fillUlt then
				ultStep = step.id
			end
		end
		check(("궁극기 맛보기 단계 %s · 스킬 안내 카드 1장"):format(tostring(ultStep)), funnelOk and ultStep == "g_ult")
		local a = Quest.newState(now)
		Quest.roll(a, now)
		local c1 = a.attendance.count
		Quest.roll(a, now + 3600)
		local same = a.attendance.count
		Quest.roll(a, now + 86400 * 5)
		local r1 = Quest.claim(a, "attendance", "1", now + 86400 * 5)
		local r1b, why1b = Quest.claim(a, "attendance", "1", now + 86400 * 5)
		local r3, why3 = Quest.claim(a, "attendance", "3", now + 86400 * 5)
		local r2 = Quest.claim(a, "attendance", "2", now + 86400 * 5)
		check(("출석: 첫날 %d · 같은 날 %d · 며칠 뒤 %d(빠진 날 = 다음 칸) · 1일차 알 · 다시 %s · 3일차 %s · 2일차 무료권"):format(c1, same, a.attendance.count, tostring(why1b), tostring(why3)),
			c1 == 1 and same == 1 and a.attendance.count == 2 and r1 and r1.egg == 1 and r1b == nil and why1b == "claimed" and r3 == nil and why3 == "not_done" and r2 and r2.rebirthTicket == 1)
		for d = 6, 20 do
			Quest.roll(a, now + 86400 * d)
		end
		check("출석 7칸에서 멈춤", a.attendance.count == #QuestData.attendance and #QuestData.attendance == 7)
		local SaveSystem = require(script.Parent.SaveSystem)
		local ok, m = pcall(SaveSystem.migrate, { version = 49, gold = 0, classes = {}, inventory = {} })
		check(("이관 옛 계정 → v%s: 이정표 · 출석 없음(새 계정만)"):format(ok and tostring(m.version) or "에러"), ok and m.version >= 53 and type(m.quests) == "table" and m.quests.guide == nil and m.quests.attendance == nil)
		local okNew, fresh = pcall(SaveSystem.migrate, {})
		check("새 계정(저장 없음 → 빈 표 이관) = 이정표 1 · 출석 0(리뷰 치명)", okNew and fresh.quests and fresh.quests.guide == 1 and type(fresh.quests.attendance) == "table" and fresh.quests.attendance.count == 0)
	end)

	section("Q13 가방 · 일괄 분해 · 확률 공개(몬테카를로 10만 회)", function()
		local Loot = require(ReplicatedStorage.Shared.Loot)
		local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
		local InventorySync = require(script.Parent.InventorySync)
		check(("가방 칸 = 저장 20 + 스위치 %d → %d(저장값 그대로)"):format(SaveConfig.bagBaseSlots, InventorySync.capacity({ inventorySlots = 20 })), InventorySync.capacity({ inventorySlots = 20 }) == SaveConfig.bagBaseSlots and SaveConfig.bagBaseSlots >= 30 and SaveConfig.bagBaseSlots <= 40)
		local t = Loot.isBulkDismantleTarget
		check("일괄 분해 대상: 영웅 ~ 기준 · 잠금 · 초월 · 태초 · 희귀 · 기준 초과 제외", t({ grade = "epic" }, "legendary") and t({ grade = "legendary" }, "legendary")
			and not t({ grade = "epic", locked = true }, "legendary") and not t({ grade = "transcendent" }, "legendary") and not t({ grade = "primordial" }, "legendary")
			and not t({ grade = "rare" }, "legendary") and not t({ grade = "legendary" }, "epic") and not t({ grade = "relic" }, "relic"))
		local Disclosure = require(ReplicatedStorage.Shared.Disclosure)
		local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
		local d1 = Disclosure.build()
		local offId = OptionData.commonOrder[1]
		OptionData.disabled[offId] = true
		local d2 = Disclosure.build()
		OptionData.disabled[offId] = nil
		local d3 = Disclosure.build()
		check(("옵션 비활성 스위치 = 공개 표 즉시 반영(풀 %d → %d) · 버전 %s → %s → 되돌리면 %s"):format(#d1.options.bow, #d2.options.bow, d1.version, d2.version, d3.version), #d2.options.bow == #d1.options.bow - 1 and d1.version ~= d2.version and d1.version == d3.version)
		local N = 100000
		local rng = Random.new(2029)
		local errs = {}
		-- ① 잡몹 등급(서버 rollArmorDrop의 등급 가지 = 태초 따로 굴림 + 나머지 정규화) vs 공개 표
		local DropTable = require(ReplicatedStorage.Shared.DropTable)
		local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
		local worstField = 0
		for tier, rows in ipairs(d1.drop.field) do
			local counts = {}
			local pr = DropTable.primordialBaseRate(tier)
			local gt = MonsterData.dropGradeTableByTier[tier] or MonsterData.dropGradeTableByTier[1]
			for _ = 1, N do
				local g = rng:NextNumber() < pr and "primordial" or Loot.gradeForRoll(gt, rng:NextNumber(), "primordial")
				counts[g] = (counts[g] or 0) + 1
			end
			for _, r in ipairs(rows) do
				worstField = math.max(worstField, math.abs((counts[r.id] or 0) / N - r.chance))
			end
		end
		errs.field = worstField
		-- ② 강화(서버 Enhance.rollResult) 표본 단계
		local Enhance = require(ReplicatedStorage.Shared.Enhance)
		local worstEnh = 0
		for _, level in ipairs({ 0, 10, 18, 22, 29 }) do
			local o = Enhance.getOutcomeTable(level, false, false, false)
			local counts = {}
			for _ = 1, N do
				local k = Enhance.rollResult(o, rng:NextNumber())
				counts[k] = (counts[k] or 0) + 1
			end
			for k, v in pairs(o) do
				worstEnh = math.max(worstEnh, math.abs((counts[k] or 0) / N - v))
			end
		end
		errs.enhance = worstEnh
		-- ③ 옵션(서버 Option.rollFor - 영웅)
		local Option = require(ReplicatedStorage.Shared.Option)
		local oc = {}
		for _ = 1, N do
			local o = Option.rollFor("epic", "bow")
			oc[o.id] = (oc[o.id] or 0) + 1
		end
		local worstOpt = 0
		for _, r in ipairs(d1.options.bow) do
			worstOpt = math.max(worstOpt, math.abs((oc[r.id] or 0) / N - r.chance))
		end
		errs.option = worstOpt
		-- ④ 스킬 변형(서버 SkillVariant.roll)
		local SkillVariant = require(ReplicatedStorage.Shared.SkillVariant)
		local vc = {}
		for _ = 1, N do
			local v = SkillVariant.roll("greatsword", rng)
			vc[v.slot .. v.id] = (vc[v.slot .. v.id] or 0) + 1
		end
		local worstVar = 0
		for _, r in ipairs(d1.variants.classes.greatsword) do
			worstVar = math.max(worstVar, math.abs((vc[r.slot .. r.id] or 0) / N - r.chance))
		end
		errs.variant = worstVar
		-- ⑤ 부화(서버 Pet.rollHatch) - 희귀 알 · 부화 레벨 5
		local Pet = require(ReplicatedStorage.Shared.Pet)
		local hc = {}
		for _ = 1, N do
			local r = Pet.rollHatch({ zone = "tier1", grade = "rare", species = { "stoneTurtle", "mossHare" } }, 5, rng)
			hc[r.grade] = (hc[r.grade] or 0) + 1
		end
		local worstHatch = 0
		for g, v in pairs(d1.hatch.levels[5].byEgg.rare) do
			worstHatch = math.max(worstHatch, math.abs((hc[g] or 0) / N - v / 100))
		end
		errs.hatch = worstHatch
		print(("[Q13][몬테카를로] 10만 회 최대 절대 오차(%%p): 잡몹 %.3f · 강화 %.3f · 옵션 %.3f · 변형 %.3f · 부화 %.3f"):format(errs.field * 100, errs.enhance * 100, errs.option * 100, errs.variant * 100, errs.hatch * 100))
		local ok = true
		for _, e in pairs(errs) do
			ok = ok and e <= 0.005
		end
		check("몬테카를로 10만 회 = 공개 표(모든 표 최대 오차 ≤ 0.5%p)", ok)
	end)

	print(("===Q 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

return V
