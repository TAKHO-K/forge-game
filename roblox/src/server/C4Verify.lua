-- C4 자동 검증(가) - 순수 값: 치명 출처 · 오버치명 전환 · 잡몹 HP 구간 배율 · 보스 공격 완화 · 원거리 지연 보정 반경 · 치명 옵션 툴팁 · 권장 표시 단조.
--   실제 피해 경로(타수 · 오버치명 공격력)는 Play에서 /gg c4 hits · /gg c4 overcrit로 잰다(docs/phase/C4-report.md).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossCurveData = require(ReplicatedStorage.Shared.data.BossCurveData)
local AimPicker = require(ReplicatedStorage.Shared.AimPicker)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)

local V = {}

function V.runPure()
	print("===C4 검증 시작(가)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[C4][가] %s %s"):format(label, ok and "O" or "X"))
	end
	local function section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end

	section("치명 출처", function()
		local bow = ClassData.classes.bow
		local r0 = PlayerCombat.resolveCrit("bow", 1, 0, 0)
		check(("활 레벨 1 · 환생 0 = 직업 %.2f + 레벨 %.2f = %.2f"):format(bow.critRate, PlayerCombat.getLevelCritBonus(1), bow.critRate + r0), math.abs(bow.critRate + r0 - (bow.critRate + CombatConfig.critCurve[1].bonus)) < 1e-9)
		check(("환생 보상 = 환생 × %.2f(상한 5회: 7회 = %.2f)"):format(CombatConfig.critRebirthBonus, PlayerCombat.getRebirthCritBonus(7)), math.abs(PlayerCombat.getRebirthCritBonus(7) - 5 * CombatConfig.critRebirthBonus) < 1e-9)
		local r5 = PlayerCombat.resolveCrit("bow", 1, 5, 0)
		check(("활 환생 5 직후(레벨 1 · 옵션 0) = %.2f(목표 약 0.5 - 보석 몫 전)"):format(bow.critRate + r5), bow.critRate + r5 >= 0.4 and bow.critRate + r5 <= 0.55)
		local r500, over500 = PlayerCombat.resolveCrit("bow", 500, 5, 0.12)
		local raw = bow.critRate + PlayerCombat.getLevelCritBonus(500) + PlayerCombat.getRebirthCritBonus(5) + 0.12
		check(("활 레벨 500 · 환생 5 · 옵션 0.12 = 합 %.3f → 확률 %.3f(≤ 1) · 넘친 확률 %.3f"):format(raw, bow.critRate + r500, over500),
			math.abs(bow.critRate + r500 - math.min(raw, 1)) < 1e-9 and math.abs(over500 - math.max(raw - 1, 0)) < 1e-9) -- PROG-2B-1 4: 둘째 값 = 넘친 확률(전환은 attackPercentWithOverflow)
		local _, over110 = PlayerCombat.resolveCrit("bow", 1, 0, 1.1 - bow.critRate - PlayerCombat.getLevelCritBonus(1))
		local m = bow.critDmg
		local conv110 = select(2, PlayerCombat.attackPercentWithOverflow(0, 0.5, over110, m, 0))
		check(("넘침 110%% → 같은 기대 피해: 위력 +%.4f = 0.1 × (m − 1)/m × (1 + 0.5)(m %.2f)"):format(conv110, m), math.abs(conv110 - 0.1 * (m - 1) / m * 1.5) < 1e-9
			and math.abs((1.5 + conv110) / 1.5 - (1 + 0.1 * (m - 1) / m)) < 1e-9)
		local cap = OptionData.options.attackPercent.cap
		check(("위력 버킷 상한: 옵션 %.2f + 전환 0.5 → %.2f(상한 %.2f)"):format(cap - 0.1, PlayerCombat.capAttackPercentOption(cap - 0.1, 0.5), cap), PlayerCombat.capAttackPercentOption(cap - 0.1, 0.5) == cap)
		local curveOk, prev = true, -1
		for level = 1, 2000, 7 do
			local v = PlayerCombat.getLevelCritBonus(level)
			curveOk = curveOk and v >= prev - 1e-12
			prev = v
		end
		check("레벨 치명 곡선 단조 증가(1 ~ 2,000)", curveOk)
		-- BalanceSim(EconSim)도 같은 함수: 치명 옵션 보석 1개 · 환생 5
		local L = BalanceSim.buildLoadout({ classId = "bow", level = 500, weaponLevel = 20, weaponGrade = 5, rebirth = 5,
			gems = { { grade = "primordial", itemLevel = 2000, option = { id = "crit", roll = 1, roll2 = 1 } }, false, false, false, false } })
		local optRate = select(1, require(ReplicatedStorage.Shared.Option).critBonus({ { grade = "primordial", itemLevel = 2000, option = { id = "crit", roll = 1, roll2 = 1 } } }, "bow"))
		local expectRate, expectOverRate = PlayerCombat.resolveCrit("bow", 500, 5, optRate)
		local expectOver = expectOverRate > 0 and (L.overCritAttackPercent or 0) > 0 or expectOverRate == 0 -- PROG-2B-1 4: 전환 값은 위력 · 공속에 따라(같은 기대 피해) - 있으면 양수
		check(("BalanceSim 대표 치명 = 게임 함수(%.3f · 전환 %.4f)"):format(L.critRate, L.overCritAttackPercent or -1), math.abs(L.critRate - (bow.critRate + expectRate)) < 1e-9 and expectOver)
	end)

	section("잡몹 HP 구간 배율", function()
		local mono, prev = true, 0
		for stage = 1, 6000 do
			local hp = InfiniteStage.getTrashHp(MonsterData.tier1.hp, stage)
			mono = mono and hp > prev
			prev = hp
		end
		for stage = 6097, 34230, 97 do -- C5 파트 0(Play 1 X): 6000에서 다시 시작하면 같은 값끼리 비교돼 X(검증 쪽 원인)
			local hp = InfiniteStage.getTrashHp(MonsterData.tier1.hp, stage)
			mono = mono and hp > prev
			prev = hp
		end
		check("잡몹 HP = 스테이지에 단조 증가(1 ~ 34,230)", mono)
		check("스테이지 1 ~ 10 배율 1", InfiniteStage.getTrashHp(100, 5) == InfiniteStage.getMonsterHp(100, 5))
		local boss = BossRules.buildInstanceData(1000, BossRules.bossIdForStage(1000), 1)
		check(("보스 HP는 구간 배율 밖(1,000: %.4g)"):format(boss.hp), boss.hp > 0)
	end)

	section("보스 공격 완화", function()
		local function ratio(stage)
			local data = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), 1)
			return data.attack / (InfiniteStage.getMonsterAttack(MonsterData.tier1.attack, stage) * CombatConfig.hpScale) -- PROG-2B-1 5: 보스 공격 = 체력 눈금 포함
		end
		local expect = InfiniteStage.interpBand(BossCurveData.attackEase, 1000)
		check(("보스 공격 ÷ 옛 값: 500 = %.3f · 1,000 = %.3f(표 %.3f) · 3,000 = %.3f"):format(ratio(500), ratio(1000), expect, ratio(3000)), math.abs(ratio(500) - 1) < 1e-9 and math.abs(ratio(1000) - expect) < 1e-6 and math.abs(ratio(3000) - 1) < 1e-9)
		local mono, prev = true, 0
		for stage = 5, 5000, 5 do
			local data = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), 1)
			mono = mono and data.attack >= prev
			prev = data.attack
		end
		check("보스 공격 = 스테이지에 단조(되돌림 기울기 < k)", mono)
	end)

	section("원거리 지연 보정 반경", function()
		local function mob(x, z)
			return { PrimaryPart = { Position = Vector3.new(x, 0, z) }, Parent = workspace }
		end
		local origin = Vector3.new(0, 0.5, 0)
		local aim = Vector3.new(0, 0, -12)
		local m = mob(3.8, -12) -- 경로(몸 반경 2.2) 밖 · 조준점에서 3.8
		local a = AimPicker.pickPath(origin, aim, 40, { m }, nil, 1)
		local b = AimPicker.pickPath(origin, aim, 40, { m }, nil, 1, function()
			return 8 * 0.125 -- 속도 8 × 편도 0.125
		end)
		local far = mob(5.6, -12)
		local c = AimPicker.pickPath(origin, aim, 40, { far }, nil, 1, function()
			return 10
		end)
		local A = CombatConfig.rangedAim
		check(("반경 %.1f 밖 몹: 보정 없음 = 빗나감 · 속도 8 × 편도 0.125 = 맞음 · 상한 %.1f 밖 = 빗나감"):format(A.assistRadiusStuds, A.assistMaxStuds), a[1] == nil and b[1] == m and c[1] == nil)
	end)

	section("툴팁 · 권장 표시", function()
		local desc = ItemDescribe.item({ part = "gloves", grade = "legendary", itemLevel = 100, option = { id = "crit", roll = 1, roll2 = 1 } }, "bow")
		local plain = ItemDescribe.item({ part = "gloves", grade = "legendary", itemLevel = 100, option = { id = "attackPercent", roll = 1 } }, "bow")
		check(("치명 옵션 툴팁 한 줄: \"%s\" · 다른 옵션 없음"):format(tostring(desc.note)), desc.note ~= nil and plain.note == nil)
		local mono, prev = true, 0
		for stage = 1, 34230, 13 do
			local rec = CombatFormula.displayRecommendedPower(stage)
			mono = mono and rec >= prev
			prev = rec
		end
		check("권장 전투력 표시 = 스테이지에 단조", mono)
	end)

	section("스테이지 1 ~ 10 누구나 한 방", function()
		-- 맨몸(레벨 1 · 강화 0 · 장비 없음) 4직업 비치명 한 타(한 타 배율 포함 · 3타 강공격 제외)가 tier1 ~ 6 HP(구간 배율 · 공식 배율 포함)를 넘는가 - 기록만(목표 = 대표)
		local rows = {}
		for _, classId in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
			local L = BalanceSim.buildLoadout({ classId = classId, level = 1, weaponLevel = 0, weaponGrade = 0 })
			local _, scale, hits = PlayerCombat.getAttackTempo(classId, 0, 1)
			local worst = 0
			for stage = 1, 10 do
				for tier = 1, 6 do
					local hp = InfiniteStage.getTrashHp(MonsterData[MonsterData.tierOrder[tier]].hp, stage) / CombatFormula.dealMultiplier(CombatFormula.offensePower(L), stage, MonsterData[MonsterData.tierOrder[tier]].hp)
					worst = math.max(worst, hp / (L.atk * scale * hits))
				end
			end
			table.insert(rows, ("%s 최악 %.2f타"):format(classId, worst))
		end
		print("[C4][가] 참고 - 맨몸 스테이지 1 ~ 10 tier1 ~ 6 비치명 타수(최악): " .. table.concat(rows, " · "))
	end)

	print(("===C4 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

return V
