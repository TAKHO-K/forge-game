-- C2 자동 검증 - 전투 공식(CombatFormulaV2) + W2 마무리(파트 A) 순수 값.
--   (가) 순수: 곡선 연속 · 단조 · 기준점(1.0 = 대표 · 1.5 = 시원 · 0.5 = 벽) · 스위치 끔 = 옛 공식(배율 1 · 레벨차 계수 되살아남) · 권장 전투력 양수 ·
--        파트 A(활 공중 발사 < 공중 정지 · 휘두르기 타격 = 서버 발사 시각 · 당김 고정점 = 머리 뒷면 앞).
--   (나) 실제 Player: 전투력 Attribute = 서버 계산 · 스테이지 5 · 100 · 1,000 × 비율 0.7 · 1.0 · 1.5에서 tier1 몹 실제 applyDamage 처치 타수 = 식 ·
--        받는 피해 배율 = 식. 검증 체인이 꺼 둔 공식(CombatFormula.debugOff)을 이 항목에서만 켠다(끝에서 되돌린다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local CombatFormulaData = require(ReplicatedStorage.Shared.data.CombatFormulaData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MotionTiming = require(ReplicatedStorage.Shared.MotionTiming)
local PlayerMotionData = require(ReplicatedStorage.Shared.data.PlayerMotionData)
local AttackMotionData = require(ReplicatedStorage.Shared.data.AttackMotionData)
local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)

local V = {}

local function newRecorder(tag)
	local pass, total = 0, 0
	local r = {}
	function r.check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[C2][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function r.note(label)
		print(("[C2][%s] %s"):format(tag, label))
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

function V.runPure()
	print("===C2 검증 시작(가)===")
	local r = newRecorder("가")
	local savedOff = CombatFormula.debugOff
	CombatFormula.debugOff = false

	r.section("곡선", function()
		r.check(("스위치 기본 = 켜짐(%s)"):format(tostring(CombatFormulaData.enabled)), CombatFormulaData.enabled == true)
		local prev, prevT, mono = 0, math.huge, true
		for i = 1, 400 do
			local x = i / 100
			local m, t = CombatFormula.dealMultiplierForRatio(x), CombatFormula.takeMultiplierForRatio(x)
			mono = mono and m >= prev - 1e-9 and t <= prevT + 1e-9
			prev, prevT = m, t
		end
		r.check("0.01 ~ 4.00: 주는 배율 단조 증가 · 받는 배율 단조 감소(400칸)", mono)
		local gap = 0
		for _, c in ipairs({ CombatFormulaData.deal, CombatFormulaData.take }) do
			for _, k in ipairs({ c.kneeLow, c.flatLow, c.flatHigh }) do
				gap = math.max(gap, math.abs(CombatFormula.curve(c, k - 1e-7) - CombatFormula.curve(c, k + 1e-7)))
			end
		end
		r.check(("경계점(무릎 · 평탄 양 끝) 좌우 차이 최대 %.2e < 1e-4(끊김 없음)"):format(gap), gap < 1e-4)
		local k1, k15, k07, k05 = CombatFormula.killTimeFactor(1), CombatFormula.killTimeFactor(1.5), CombatFormula.killTimeFactor(0.7), CombatFormula.killTimeFactor(0.5)
		r.check(("처치 시간 배수: 1.0 = %.3f(대표) · 1.5 = %.3f(≤ 0.6 시원) · 0.7 = %.3f · 0.5 = %.3f(≥ 4 벽)"):format(k1, k15, k07, k05),
			math.abs(k1 - 1) < 1e-9 and k15 <= 0.6 and k05 >= 4 and k05 / k07 >= 2.5)
	end)

	r.section("권장 전투력 · 방어", function()
		local ok = true
		for _, s in ipairs({ 1, 5, 20, 100, 500, 1000, 5000, 25300, 34230 }) do
			local p, d = CombatFormula.recommendedPower(s), CombatFormula.recommendedDefense(s)
			ok = ok and p > 0 and p < math.huge and d > 0 and d < math.huge
			r.note(("스테이지 %d: 권장 전투력 %.4g · 대표 한 대 수 %.3f · 권장 방어 %.4g"):format(s, p, CombatFormula.representativeHits(s), d))
		end
		r.check("권장 전투력 · 방어 유한 양수(9칸)", ok)
		local s = 1000
		local t1, t5 = CombatFormula.recommendedPower(s, MonsterData.tier1.hp), CombatFormula.recommendedPower(s)
		r.check(("몹 기준 권장: tier1 ÷ 기준 구역 = %.4f = HP 비 %.4f"):format(t1 / t5, MonsterData.tier1.hp / MonsterData[MonsterData.tierOrder[CombatFormulaData.representative.referenceTier]].hp),
			math.abs(t1 / t5 - MonsterData.tier1.hp / MonsterData[MonsterData.tierOrder[CombatFormulaData.representative.referenceTier]].hp) < 1e-9)
	end)

	r.section("스위치 끔 = 옛 공식", function()
		CombatFormulaData.enabled = false
		local ok, deal, take, gapOld = pcall(function() -- 리뷰 8: 에러가 나도 스위치를 되돌린다
			return CombatFormula.dealMultiplier(1, 100), CombatFormula.takeMultiplier(1, 100, 10), CharacterLevel.levelGapDealMultiplier(1, 1000)
		end)
		CombatFormulaData.enabled = true
		assert(ok, deal)
		local gapNew = CharacterLevel.levelGapDealMultiplier(1, 1000)
		r.check(("끔: 주는 %.3f · 받는 %.3f = 1 · 레벨차 계수 되살아남 %.3f < 1 · 켬: 레벨차 %.3f = 1(통합)"):format(deal, take, gapOld, gapNew),
			deal == 1 and take == 1 and gapOld < 1 and gapNew == 1)
	end)

	r.section("파트 A", function()
		local airRel = MotionTiming.releaseSeconds("bow", true)
		local hover = AttackMotionData.bow.air.hoverSeconds
		r.check(("활 공중 발사 %.3f < 공중 정지 %.2f · 지상 발사 불변 %.4f(0.429)"):format(airRel, hover, MotionTiming.releaseSeconds("bow", false)), airRel < hover and math.abs(MotionTiming.releaseSeconds("bow", false) - 0.429) < 1e-9)
		r.check(("활 공중 클립 전조 %.3f = 공중 발사"):format(PlayerMotionData.weapons.bow.air.ant), math.abs(PlayerMotionData.weapons.bow.air.ant - airRel) < 1e-9)
		for _, classId in ipairs({ "bow", "healer" }) do
			local clip = PlayerMotionData.weapons[classId].closeSwing
			r.check(("%s 휘두르기 타격(전조) %.4f = 서버 발사 %.4f"):format(classId, clip.ant, MotionTiming.releaseSeconds(classId)), math.abs(clip.ant - MotionTiming.releaseSeconds(classId)) < 1e-9)
		end
		local bow = WeaponRigSpec.weapons.bow.pieces[1]
		local kicked = bow.drawAnchor + bow.releaseKick
		r.check(("당김 고정점 z %.2f · 튕김 z %.2f ≤ 뒤 한계 %.2f < 머리 뒷면 0.6"):format(bow.drawAnchor.Z, kicked.Z, bow.handBackLimit), bow.drawAnchor.Z <= bow.handBackLimit and kicked.Z <= bow.handBackLimit and bow.handBackLimit < 0.6)
	end)

	CombatFormula.debugOff = savedOff
	local pass, total = r.summary()
	print(("===C2 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

function V.runLive(player, env)
	print("===C2 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local MonsterState = require(script.Parent.MonsterState)
	local MonsterSpawner = require(script.Parent.MonsterSpawner)
	local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
	local Loot = require(ReplicatedStorage.Shared.Loot)
	local savedOff = CombatFormula.debugOff
	CombatFormula.debugOff = false
	local PlayerState = require(script.Parent.PlayerState)
	local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local stageBefore = PlayerProfile.getInfiniteStage(player)
	local before = {}
	for _, m in ipairs(MonsterState.getAllModels()) do
		before[m] = true
	end
	PlayerState.setIncomingDamageMultiplierUntil(player, 0, 40, "c2verify") -- 표본 잡몹 리스폰이 개발 캐릭터를 치지 않게(P3b 함정)

	r.section("전투력 동기화", function()
		task.wait(1.2)
		local attr, calc = player:GetAttribute("CombatPower"), PlayerProfile.getCombatPower(player)
		r.check(("Attribute CombatPower %.6g = 서버 계산 %.6g"):format(attr or -1, calc), type(attr) == "number" and math.abs(attr - calc) <= math.abs(calc) * 1e-9)
	end)

	r.section("처치 타수 실측(tier1 · 실제 applyDamage)", function()
		assert(root, "캐릭터 없음")
		for _, stage in ipairs({ 5, 100, 1000 }) do
			PlayerProfile.setInfiniteStageDirect(player, stage)
			for _, ratio in ipairs({ 0.7, 1.0, 1.5 }) do
				local mob = MonsterSpawner.spawn(MonsterData.tier1, root.Position + Vector3.new(0, 0, 40), nil, {})
				assert(mob, "몹 스폰 실패")
				mob.PrimaryPart.Anchored = true
				local rec = CombatFormula.recommendedPower(stage, MonsterData.tier1.hp)
				local power = rec * ratio
				local hits, dead = 0, false
				while not dead and hits < 2000 do
					player:SetAttribute("CombatPower", power) -- 동기화 루프가 덮기 전(같은 프레임)
					dead = MonsterState.applyDamage(mob, power, stage, player)
					hits += 1
				end
				local expect = CombatFormula.representativeHits(stage) / (ratio * CombatFormula.dealMultiplierForRatio(ratio))
				r.check(("스테이지 %d · 비율 %.1f: 실측 %d타 · 식 %.2f타(올림 %d) · 처치 시간 배수 %.2f(대표 1.0)"):format(stage, ratio, hits, expect, math.max(1, math.ceil(expect - 1e-6)), CombatFormula.killTimeFactor(ratio)),
					math.abs(hits - math.max(1, math.ceil(expect - 1e-6))) <= 1)
				MonsterSpawner.despawn(mob)
			end
		end
		PlayerProfile.setInfiniteStageDirect(player, stageBefore or 1)
	end)

	r.section("받는 피해 배율", function()
		local classId = PlayerProfile.getClassId(player)
		local defense = PlayerCombat.getDefense(classId, Loot.getArmorDefense(PlayerProfile.getEquippedArmor(player)), PlayerProfile.getDefensePercentBonus(player))
		local stage = PlayerProfile.getInfiniteStage(player)
		local attack = InfiniteStage.getMonsterAttack(MonsterData.tier1.attack, stage)
		local got, want = PlayerDamage.getCombatTakeMultiplier(player, attack, stage), CombatFormula.takeMultiplier(defense, stage, attack)
		r.check(("스테이지 %d · 방어 %.4g · 권장 %.4g: 받는 피해 배율 %.4f = 식 %.4f"):format(stage, defense, CombatFormula.recommendedDefense(stage, attack), got, want), math.abs(got - want) < 1e-9)
	end)

	CombatFormula.debugOff = savedOff
	task.wait((WorldConfig.respawnDelaySeconds or 5) + 1) -- 표본 리스폰분까지 정리
	for _, m in ipairs(MonsterState.getAllModels()) do
		local d = MonsterState.getData(m)
		if not before[m] and m.Parent and not (d and d.isBoss) then
			MonsterSpawner.despawn(m)
		end
	end
	env.restore(player)
	local pass, total = r.summary()
	print(("===C2 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return V
