-- G1-3 자동 검증(docs/phase/G1-3-report.md) - 환생의 의미(레벨차 계수 + 무료 폭) · 환생 자리 = 제단 한 곳.
--   (가) 레벨차 계수 경계(설계 대응 L + 167 · 무료 폭 = 힘 비율 1.02^100) · 하한 · 상한 · 검증 스위치 · 환생 자리 판정
--   (나) 실제 Player: Lv.1 · 스테이지 500에서 받는 피해 ×3 · 주는 피해 ×0.25(잡몹 실제 applyDamage) · 레벨을 올리면 1 · 되돌림

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)

local G1_3Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-3][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

function G1_3Verify.runPure()
	print("===G1-3 검증 시작(가)===")
	local r = newRecorder("가")
	local config = CharacterLevelConfig.levelGap

	r.section("레벨차 계수", function()
		local free = InfiniteStage.stagesForPowerRatio(config.freePowerRatio)
		local offset = CharacterLevelConfig.levelStageOffset
		local saved = CharacterLevel.debugLevelGapOff
		CharacterLevel.debugLevelGapOff = false
		local edge = 1 + offset + free -- Lv.1이 벌점 없이 설 수 있는 가장 높은 스테이지
		local atEdge = CharacterLevel.levelGapStages(1, edge)
		local plus10 = { CharacterLevel.levelGapDealMultiplier(1, edge + 10), CharacterLevel.levelGapTakeMultiplier(1, edge + 10) }
		local far = { CharacterLevel.levelGapDealMultiplier(1, 5000), CharacterLevel.levelGapTakeMultiplier(1, 5000) }
		local leveled = { CharacterLevel.levelGapDealMultiplier(4800, 5000), CharacterLevel.levelGapTakeMultiplier(4800, 5000) }
		CharacterLevel.debugLevelGapOff = true
		local off = { CharacterLevel.levelGapDealMultiplier(1, 5000), CharacterLevel.levelGapTakeMultiplier(1, 5000) }
		CharacterLevel.debugLevelGapOff = saved
		r.check(("무료 폭 %.2f칸(기대 100 - 힘 비율 1.02^100) · Lv.1 경계 스테이지 %.0f(= 1 + %d + 100) 칸 %.4f(기대 0) · +10칸 주는 ×%.2f 받는 ×%.2f(기대 0.90 · 1.20) · 스테이지 5000 ×%.2f · ×%.2f(기대 하한 %.2f · 상한 %.0f) · Lv.4800 ×%.2f · ×%.2f(기대 1 · 1) · 검증 스위치 ×%.0f · ×%.0f(기대 1 · 1)"):format(
			free, edge, offset, atEdge, plus10[1], plus10[2], far[1], far[2], config.dealFloor, config.takeCap, leveled[1], leveled[2], off[1], off[2]),
			near(free, 100, 1e-9) and near(atEdge, 0, 1e-9) and near(plus10[1], 0.9, 1e-9) and near(plus10[2], 1.2, 1e-9) and far[1] == config.dealFloor and far[2] == config.takeCap
				and leveled[1] == 1 and leveled[2] == 1 and off[1] == 1 and off[2] == 1)
	end)

	r.section("환생 자리", function()
		local RebirthAccess = require(script.Parent.RebirthAccess)
		local station = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
		local okStation, whyStation = RebirthAccess.evaluate({ position = station + Vector3.new(2, 0, 0) })
		local okAltar, whereAltar = RebirthAccess.evaluate({ position = RebirthAccess.altarPosition() + Vector3.new(2, 0, 0) })
		r.check(("강화대 앞 %s(%s - 기대 거절 out_of_range) · 제단 앞 %s(%s - 기대 altar)"):format(tostring(okStation), tostring(whyStation), tostring(okAltar), tostring(whereAltar)),
			okStation == false and whyStation == "out_of_range" and okAltar == true and whereAltar == "altar")
	end)

	local pass, count = r.summary()
	print(("===G1-3 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

function G1_3Verify.runLive(player, env)
	print("===G1-3 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PlayerDamage = require(script.Parent.PlayerDamage)
	local MonsterState = require(script.Parent.MonsterState)
	local saved = CharacterLevel.debugLevelGapOff
	CharacterLevel.debugLevelGapOff = false -- 체인이 꺼 둔 계수를 이 항목에서만 켠다(끝에서 되돌린다)

	r.section("실제 Player", function()
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(1))
		env.applyStage(player, 500)
		local take = PlayerDamage.getLevelGapTakeMultiplier(player)
		-- 주는 피해: 같은 잡몹에 같은 피해를 계수 켜고 · 끄고 넣어 hpRatio 감소를 비교한다(실제 MonsterState.applyDamage)
		local model = nil
		for _, m in ipairs(MonsterState.getAllModels()) do
			local data = MonsterState.getData(m)
			if data and not data.isBoss and not MonsterState.isChest(m) and not MonsterState.isRescueTarget(m) and not model and MonsterState.getHpRatio(m) > 0.9 then
				model = m
			end
		end
		assert(model, "잡몹이 없다")
		local hp = InfiniteStage.getMonsterHp(MonsterState.getData(model).hp, 500)
		local r0 = MonsterState.getHpRatio(model)
		MonsterState.applyDamage(model, hp * 0.01, 500, player)
		local withGap = r0 - MonsterState.getHpRatio(model)
		CharacterLevel.debugLevelGapOff = true
		local r1 = MonsterState.getHpRatio(model)
		MonsterState.applyDamage(model, hp * 0.01, 500, player)
		local without = r1 - MonsterState.getHpRatio(model)
		CharacterLevel.debugLevelGapOff = false
		MonsterState.clearPlayerContributions(player)
		local required = math.ceil(500 - CharacterLevelConfig.levelStageOffset - 100)
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(required))
		local takeLeveled = PlayerDamage.getLevelGapTakeMultiplier(player)
		r.check(("Lv.1 · 스테이지 500: 받는 피해 ×%.2f(기대 %.0f) · 주는 피해 비 %.4f(기대 %.2f - 같은 피해의 HP 감소 %.5f ÷ %.5f) · Lv.%d로 올리면 받는 ×%.2f(기대 1)"):format(
			take, CharacterLevelConfig.levelGap.takeCap, withGap / math.max(without, 1e-12), CharacterLevelConfig.levelGap.dealFloor, withGap, without, required, takeLeveled),
			take == CharacterLevelConfig.levelGap.takeCap and near(withGap / without, CharacterLevelConfig.levelGap.dealFloor, 1e-6) and takeLeveled == 1)
	end)

	CharacterLevel.debugLevelGapOff = saved
	env.restore(player)
	local pass, count = r.summary()
	print(("===G1-3 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G1_3Verify
