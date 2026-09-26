-- D1-2 자동 검증(경제 보정 - 공격 속도 상한 · 딜 부위 태초 · 반짝이 · 파티원 예외 · 칭호 조건 · 무기 태초 표시). id = "D1-2(가)" · "D1-2(나)".
--   (가) 순수: 상한 전/후 공격 간격(직업 4 × 신발 등급) · 태초 신발 = 공격 · 이동 상한 + 대시 · 태초 장갑 치명 피해(상한 안) · 딜 부위 태초 배율 · 갑옷 ×2.5 유지 ·
--        반짝이 표(합 1 · 첫 클리어 절반 · 경계 · 표본) · 골드 25마리분 · 확률 공개 · 파티원 예외(서버 판정 · 클라 자물쇠 문자열) · 칭호 획득 조건 · 무기 태초 문구
--   (나) 실제 서버: 태초 신발 · 장갑 착용 → Attribute · 공격 간격 · 걷기 속도 · 대시 배율 · 치명 피해 / 파티 결성 → PartyId · 막힘 예외 / 되돌림
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)
local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local RareMonsterConfig = require(ReplicatedStorage.Shared.data.RareMonsterConfig)
local PrimordialData = require(ReplicatedStorage.Shared.data.PrimordialData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Loot = require(ReplicatedStorage.Shared.Loot)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local MobShare = require(ReplicatedStorage.Shared.MobShare)
local Text = require(ReplicatedStorage.Shared.Text)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		pass += ok and 1 or 0
		print(("[D1-2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[D1-2][%s] %s"):format(tag, label))
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

local CLASSES = { "greatsword", "dualblade", "bow", "healer" }
local D1_PRIMORDIAL_SHOES = 9.811 -- D1 커밋의 태초 신발 속도%(위력 26.8 · itemLevel 25 동결) - 상한 전 비교용

function V.runPure()
	print("===D1-2 검증 시작(가)===")
	local r = newRecorder("가")
	local cap = CombatConfig.attackSpeedMaxMultiplier

	r.section("공격 속도 상한", function()
		r.check(("상한 ×%.2f(지시 범위 ×2.0 ~ ×2.5)"):format(cap), cap >= 2.0 and cap <= 2.5)
		for _, classId in ipairs(CLASSES) do
			local cells, ok = {}, true
			for _, g in ipairs({ "legendary", "relic", "ancient", "primordial" }) do
				local x = Loot.getShoesSpeedPercent({ grade = g, itemLevel = 1000 })
				local base = CombatConfig.attackCooldownSeconds / ClassData.classes[classId].atkSpeed
				local after = PlayerCombat.getAttackCooldown(classId, x)
				local before = base / (1 + (g == "primordial" and D1_PRIMORDIAL_SHOES or x))
				table.insert(cells, ("%s %.3f → %.3f초"):format(g, before, after))
				ok = ok and near(after, base / math.min(1 + x, cap), 1e-12) and after >= base / cap - 1e-12
			end
			r.check(("INTERVAL|%s|%s"):format(classId, table.concat(cells, " · ")), ok)
		end
		local q = require(ReplicatedStorage.Shared.data.SkillData).bow.Q.attackSpeedCap
		local bowQ = PlayerCombat.getAttackCooldown("bow", 99, q)
		r.check(("활 속사(×%.1f 따로) + 상한 신발 = %.3f초(= 기본 ÷ %.2f)"):format(q, bowQ, cap * q), near(bowQ, CombatConfig.attackCooldownSeconds / ClassData.classes.bow.atkSpeed / (cap * q), 1e-12))
		r.check(("이동 속도 상한 ×%.2f 그대로(JumpMath) · 공격 속도 배율 99 → ×%.2f"):format(MovementConfig.moveSpeedMaxMultiplier, PlayerCombat.getSpeedMultiplier(99)),
			JumpMath.moveSpeedMultiplier(99) == MovementConfig.moveSpeedMaxMultiplier and PlayerCombat.getSpeedMultiplier(99) == cap)
	end)

	r.section("딜 부위 태초 · 고유 효과", function()
		local anc, pri = ArmorData.grades.ancient, ArmorData.grades.primordial
		r.check(("장갑 · 신발 태초 위력 = 고대 %.3f × %.2f = %.3f · 갑옷 태초 방어 = 고대 × %.2f(×2.5 유지)"):format(anc.dropPower, ArmorData.dpsPrimordialStep, pri.dropPower,
			pri.defenseGradeMultiplier / anc.defenseGradeMultiplier), near(pri.dropPower, anc.dropPower * ArmorData.dpsPrimordialStep, 1e-12) and near(pri.defenseGradeMultiplier / anc.defenseGradeMultiplier, 2.5, 1e-12))
		local shoes = { grade = "primordial", itemLevel = 25 }
		local speed = Loot.getShoesSpeedPercent(shoes)
		r.check(("태초 신발: 공격 속도 ×%.2f(상한) · 이동 ×%.2f(상한) · 대시 ×%.3f(상한 %.3f) · 고대 신발 대시 ×%.3f"):format(PlayerCombat.getSpeedMultiplier(speed), JumpMath.moveSpeedMultiplier(speed),
			Loot.getShoesDashMultiplier(shoes), DashConfig.rangeMaxMultiplier, Loot.getShoesDashMultiplier({ grade = "ancient", itemLevel = 25 })),
			PlayerCombat.getSpeedMultiplier(speed) == cap and JumpMath.moveSpeedMultiplier(speed) == MovementConfig.moveSpeedMaxMultiplier
				and Loot.getShoesDashMultiplier(shoes) == DashConfig.rangeMaxMultiplier and Loot.getShoesDashMultiplier({ grade = "ancient", itemLevel = 25 }) == 1)
		r.check(("대시 상한 %.1fstud ≤ 대검 관통돌진 18(회피기가 공격 돌진보다 멀리 가지 않음)"):format(DashConfig.rangeStuds * DashConfig.rangeMaxMultiplier), DashConfig.rangeStuds * DashConfig.rangeMaxMultiplier <= 18 + 1e-9)
		local gloves = { grade = "primordial", itemLevel = 25 }
		local withP = BalanceSim.buildLoadout({ classId = "bow", level = 100, gear = { gloves = { grade = "primordial", itemLevel = 25 } } })
		local withA = BalanceSim.buildLoadout({ classId = "bow", level = 100, gear = { gloves = { grade = "ancient", itemLevel = 25 } } })
		r.check(("태초 장갑 치명 피해 +%.2f(고대 0) · 시뮬 치명 피해 %.2f → %.2f · 상한 +%.2f"):format(Loot.getGlovesCritDmgBonus(gloves), withA.critDmg, withP.critDmg, CombatConfig.critDmgBonusCap),
			Loot.getGlovesCritDmgBonus(gloves) == PrimordialData.unique.glovesCritDmgBonus and Loot.getGlovesCritDmgBonus({ grade = "ancient", itemLevel = 25 }) == 0
				and near(withP.critDmg - withA.critDmg, PrimordialData.unique.glovesCritDmgBonus, 1e-12) and PrimordialData.unique.glovesCritDmgBonus <= CombatConfig.critDmgBonusCap)
	end)

	r.section("반짝이 표 · 골드", function()
		local t, fc = RareMonsterConfig.sparkleGradeChances, DropTableData.bossGrades.firstClear
		local s = 0
		for _, v in pairs(t) do
			s += v
		end
		r.check(("TABLE|반짝이 영웅 %.4g · 전설 %.4g · 유물 %.4g · 고대 %.4g · 태초 %.4g(합 %.12f)"):format(t.epic, t.legendary, t.relic, t.ancient, t.primordial, s), near(s, 1, 1e-12))
		r.check(("태초 · 고대 = 첫 클리어의 절반(%.5g · %.5g) · 영웅 이상 확정(일반 · 희귀 없음)"):format(fc.primordial / 2, fc.ancient / 2),
			near(t.primordial, fc.primordial / 2, 1e-15) and near(t.ancient, fc.ancient / 2, 1e-15) and t.normal == nil and t.rare == nil)
		-- 경계: 등급 순서(영웅 → 태초)로 누적 - u = 0 → 영웅 · 1 − 1e-15 → 태초 · 각 경계 바로 아래/위
		local order = { "epic", "legendary", "relic", "ancient", "primordial" }
		local acc, okB = 0, Loot.gradeForRoll(t, 0) == "epic" and Loot.gradeForRoll(t, 1 - 1e-15) == "primordial"
		for i = 1, #order - 1 do
			acc += t[order[i]]
			okB = okB and Loot.gradeForRoll(t, acc - 1e-12) == order[i] and Loot.gradeForRoll(t, acc + 1e-12) == order[i + 1]
		end
		r.check("경계값: u = 0 영웅 · 1 − 1e-15 태초 · 누적 경계 ±1e-12 = 아래/위 등급", okB)
		local rng, N, count = Random.new(20260927), 2000000, {}
		for _ = 1, N do
			local g = Loot.gradeForRoll(t, rng:NextNumber())
			count[g] = (count[g] or 0) + 1
		end
		local okS, cells = true, {}
		for _, g in ipairs(order) do
			local mean = N * t[g]
			local sigma = math.sqrt(mean * (1 - t[g]))
			okS = okS and math.abs((count[g] or 0) - mean) <= 4.5 * math.max(sigma, 1)
			table.insert(cells, ("%s %d/%.0f"):format(g, count[g] or 0, mean))
		end
		r.check(("표본 %d회: %s(±4.5σ)"):format(N, table.concat(cells, " · ")), okS)
		r.check(("골드 보너스 %d마리분 · 재료 %d마리분(옛 값) · 사냥 골드 몫 ≈ %.1f%%(목표 10 ~ 15)"):format(RareMonsterConfig.goldBonusKillEquivalent, RareMonsterConfig.materialBonusKillEquivalent,
			RareMonsterConfig.sparkleChance * (RareMonsterConfig.goldMultiplier - 1 + RareMonsterConfig.goldBonusKillEquivalent) / (1 + RareMonsterConfig.sparkleChance * (RareMonsterConfig.goldMultiplier - 1 + RareMonsterConfig.goldBonusKillEquivalent)) * 100),
			RareMonsterConfig.materialBonusKillEquivalent == 10 and RareMonsterConfig.goldBonusKillEquivalent > 10)
		local rows = DropTable.disclosure().sparkle
		r.check(("확률 공개 반짝이 %d줄(영웅 ~ 태초)"):format(rows and #rows or 0), rows ~= nil and #rows == 5 and rows[1].id == "epic" and rows[5].id == "primordial")
		local fx = RareMonsterConfig.coinFountain
		r.check(("금화 분수 입자 예산 = 한 번 %d개 · %.1f초"):format(fx.count, fx.lifeSeconds), fx.count <= 24 and fx.lifeSeconds <= 2)
	end)

	r.section("파티원 예외(막힘)", function()
		local owner = { stage = 100, level = 30, rebirth = 0, party = 7 }
		local strong = { stage = 100, level = 400, rebirth = 2, party = 7 }
		local other = { stage = 100, level = 400, rebirth = 2, party = 8 }
		local solo = { stage = 100, level = 400, rebirth = 2 }
		local function blockedOn(hunter, who)
			local entry = MobShare.fresh({})
			MobShare.touch(entry, hunter, hunter.stage, 0)
			return MobShare.isBlocked(entry, who, who.stage, 0.5)
		end
		r.check(("같은 파티 강한 계정 → 초보 몹 막힘 %s · 다른 파티 %s · 파티 없음 %s"):format(tostring(blockedOn(owner, strong)), tostring(blockedOn(owner, other)), tostring(blockedOn(owner, solo))),
			blockedOn(owner, strong) == false and blockedOn(owner, other) == true and blockedOn(owner, solo) == true)
		r.check("파티 번호 0 · nil은 같은 파티가 아님", not MobShare.sameParty({ party = 0 }, { party = 0 }) and not MobShare.sameParty({}, {}))
		local entry = MobShare.fresh({})
		MobShare.touch(entry, owner, 100, 0)
		local enc = MobShare.encodeHunters(entry, 0, function(at)
			return 1000 + at
		end)
		local lockedSame = MobShare.lockedFor(enc, { userId = 99, stage = 100, level = 400, rebirth = 2, party = 7 }, 1001)
		local lockedOther = MobShare.lockedFor(enc, { userId = 99, stage = 100, level = 400, rebirth = 2, party = 8 }, 1001)
		r.check(("클라 자물쇠 문자열 \"%s\" → 같은 파티 잠김 %s · 다른 파티 %s"):format(enc, tostring(lockedSame), tostring(lockedOther)), lockedSame == false and lockedOther == true)
		r.check("어그로 필터(tooWeakFor)는 파티와 무관하게 유지(약한 파티원이 강한 파티원 기준 몹에 즉사하지 않게)",
			MobShare.tooWeakFor((function()
				local e = MobShare.fresh({})
				MobShare.touch(e, { stage = 3000, level = 400, rebirth = 2, party = 7 }, 3000, 0)
				return e
			end)(), owner, 100) == true)
	end)

	r.section("칭호 획득 조건 · 무기 태초 문구", function()
		local Registry = require(script.Parent.PrimordialRegistry)
		local acquire = TitleData.titles[PrimordialData.titleId].acquire
		local function gear(kind, part, grade)
			return { grade = grade or "primordial", part = part or "gloves", source = kind and { kind = kind } or nil }
		end
		local cases = {
			{ "잡몹 태초 장갑", gear("field"), true }, { "보스 첫 클리어 태초 갑옷", gear("boss", "armor"), true }, { "토벌 태초 신발", gear("raid", "shoes"), true },
			{ "반짝이 태초", gear("sparkle"), true }, { "태초 보석(부위 없음)", { grade = "primordial", itemLevel = 100, option = { id = "attackPercent", roll = 1 } }, false },
			{ "출처 없는 태초(계승 결과 등)", gear(nil), false }, { "시험 출처(/gg drop force)", gear("dev"), false }, { "고대 장갑", gear("field", "gloves", "ancient"), false },
		}
		local ok, cells = true, {}
		for _, c in ipairs(cases) do
			local got = Registry.titleEarnedBy(c[2])
			ok = ok and got == c[3]
			table.insert(cells, ("%s %s"):format(c[1], got and "O" or "-"))
		end
		r.check(("칭호 \"%s\" 조건 kind = %s: %s"):format(TitleData.titles[PrimordialData.titleId].name, acquire.kind, table.concat(cells, " · ")), ok and acquire.kind == "dropPrimordial")
		local text = Text.get("rebirth.weaponPrimordialRule", { max = GemData.maxRebirthCount, slots = #GemData.slotGradeCap })
		r.check(("무기 태초 문구 \"%s\" = 코드 조건(환생 %d회 + 보석 홈 %d칸)"):format(text, GemData.maxRebirthCount, #GemData.slotGradeCap),
			text:find(("환생 %d회"):format(GemData.maxRebirthCount), 1, true) ~= nil and text:find(("%d칸"):format(#GemData.slotGradeCap), 1, true) ~= nil)
	end)

	local pass, total = r.summary()
	print(("===D1-2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

function V.runLive(player, env)
	print("===D1-2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PartyState = require(script.Parent.PartyState)
	local classId = PlayerProfile.getClassId(player)
	local base = CombatConfig.attackCooldownSeconds / ClassData.classes[classId].atkSpeed

	r.section("태초 신발 착용", function()
		PlayerProfile.setEquippedDirect(player, "shoes", { grade = "primordial", part = "shoes", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		task.wait(0.2)
		local bonus = PlayerProfile.getSpeedPercentBonus(player)
		local cooldown = PlayerCombat.getAttackCooldown(classId, bonus)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local parts = player:GetAttribute("PrimordialParts")
		r.check(("공격 간격 %.3f초(= 기본 %.3f ÷ %.2f) · 걷기 %.2f(×%.2f) · 대시 배율 %.3f · Attribute PrimordialParts \"%s\""):format(cooldown, base, CombatConfig.attackSpeedMaxMultiplier,
			humanoid and humanoid.WalkSpeed or -1, MovementConfig.moveSpeedMaxMultiplier, PlayerProfile.getDashRangeMultiplier(player), tostring(parts)),
			near(cooldown, base / CombatConfig.attackSpeedMaxMultiplier, 1e-9) and PlayerProfile.getDashRangeMultiplier(player) == DashConfig.rangeMaxMultiplier
				and type(parts) == "string" and parts:find("shoes", 1, true) ~= nil and (humanoid == nil or near(humanoid.WalkSpeed, MovementConfig.walkSpeedStuds * MovementConfig.moveSpeedMaxMultiplier, 0.01)))
		PlayerProfile.setEquippedDirect(player, "shoes", { grade = "legendary", part = "shoes", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		task.wait(0.1)
		local legendary = PlayerCombat.getAttackCooldown(classId, PlayerProfile.getSpeedPercentBonus(player))
		r.check(("전설 신발 공격 간격 %.3f초(상한 아래 - 속도%% %.3f) · 대시 배율 %.3f"):format(legendary, PlayerProfile.getSpeedPercentBonus(player), PlayerProfile.getDashRangeMultiplier(player)),
			legendary > base / CombatConfig.attackSpeedMaxMultiplier and PlayerProfile.getDashRangeMultiplier(player) == 1)
	end)

	r.section("태초 장갑 착용", function()
		PlayerProfile.setEquippedDirect(player, "gloves", { grade = "ancient", part = "gloves", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		local _, dmgA = PlayerProfile.getCritBonus(player)
		PlayerProfile.setEquippedDirect(player, "gloves", { grade = "primordial", part = "gloves", itemLevel = 100, dropStage = 100, tierIndex = 1, locked = true })
		task.wait(0.1)
		local _, dmgP = PlayerProfile.getCritBonus(player)
		local parts = player:GetAttribute("PrimordialParts")
		r.check(("치명 피해 추가분 고대 %.3f → 태초 %.3f(+%.2f · 상한 %.2f) · PrimordialParts \"%s\""):format(dmgA, dmgP, PrimordialData.unique.glovesCritDmgBonus, CombatConfig.critDmgBonusCap, tostring(parts)),
			near(dmgP, math.min(dmgA + PrimordialData.unique.glovesCritDmgBonus, CombatConfig.critDmgBonusCap), 1e-9) and type(parts) == "string" and parts:find("gloves", 1, true) ~= nil)
		r.check("원격 PrimordialGlovesBolt · SparkleCoinFountain 있음", ReplicatedStorage:FindFirstChild("PrimordialGlovesBolt") ~= nil and ReplicatedStorage:FindFirstChild("SparkleCoinFountain") ~= nil)
	end)

	r.section("파티 결성 → PartyId · 막힘 예외", function()
		local already = PartyState.getParty(player) ~= nil -- 리뷰 6: 원래 파티에 있으면 탈퇴하지 않는다
		local party = PartyState.getParty(player) or PartyState.create(player)
		task.wait(0.1)
		local id = player:GetAttribute("PartyId")
		local entry = MobShare.fresh({})
		local strong = { stage = 100, level = 9000, rebirth = 5, party = id }
		MobShare.touch(entry, strong, 100, 0)
		local me = MobShare.profileOf(player, 100)
		r.check(("Attribute PartyId = %s(파티 #%s) · 내 판정 단위 party = %s · 같은 파티 강한 주인 몹 막힘 %s"):format(tostring(id), tostring(party and party.id), tostring(me.party),
			tostring(MobShare.isBlocked(entry, player, 100, 0.5))), id ~= nil and id == party.id and me.party == id and MobShare.isBlocked(entry, player, 100, 0.5) == false)
		if not already then
			PartyState.leave(player, "verify")
			task.wait(0.1)
			r.check(("탈퇴 → PartyId = %s"):format(tostring(player:GetAttribute("PartyId"))), player:GetAttribute("PartyId") == nil)
		end
	end)

	env.restore(player)
	local pass, total = r.summary()
	print(("===D1-2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
