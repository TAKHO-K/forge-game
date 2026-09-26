-- P0 자동 검증(가) - 경제 시뮬(EconSim). DevTools.server.lua의 verifyEnabled("P0(가)") 블록이 부른다(플레이어 불필요 · 순수 계산).
-- ① Studio 전용 스위치 ② what-if 덮어쓰기 복원(정상 · 에러) ③ 기준선 전체 실행(/gg econ all baseline과 같은 함수 - 보고서 줄을 출력 창에 남긴다)
-- ④ 표본 대조(S21a · S21-0) ⑤ E3 · E6 결과 모양 ⑥ 실행 뒤 게임 데이터 표가 그대로인지.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local GoldCostConfig = require(ReplicatedStorage.Shared.data.GoldCostConfig)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local EconSim = require(script.Parent.EconSim)
local EconSimReport = require(script.Parent.EconSimReport)

local EconSimVerify = {}

local function newRecorder()
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[P0][가] %s %s"):format(label, ok and "O" or "X"))
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

-- 게임 데이터 표의 지금 값(덮어쓰기가 되돌아왔는지 비교용).
local function snapshot()
	return {
		growthRate = InfiniteStageConfig.growthRate,
		weaponGrowthRate = CharacterLevelConfig.weaponMultGrowthRate,
		dealing = SkillData.healer.E.attackMultiplier,
		goldCost = EnhanceConfig.goldCost,
		bowClass = ClassData.classes.bow,
		healerClass = ClassData.classes.healer,
		bowQuickShotBase = SkillData.bow.Q.attackSpeedBase,
		-- P2 덮어쓰기 칸(p2before what-if)
		rebirthLevels = CharacterLevelConfig.rebirth.requiredLevels,
		levelLogSlope = OptionData.levelLogSlope,
		enhanceAnchor = GoldCostConfig.anchorStage.enhance,
		dragonOverTier = DropTableData.primordial.dragonOverTier,
		decayPerLevel = DropTableData.primordial.levelDecay.perLevel,
		healerAtk = ClassData.classes.healer.atk,
	}
end

local function sameSnapshot(a, b)
	for key, value in pairs(a) do
		if b[key] ~= value then
			return false, key
		end
	end
	return true
end

function EconSimVerify.runPure()
	print("===P0 검증 시작(가)===")
	local r = newRecorder()
	local before = snapshot()

	r.section("[1] 스위치", function()
		r.check(("1 EconSim.isAllowed() = %s(기대 true - Studio + DevToolsConfig.econSim)"):format(tostring(EconSim.isAllowed())), EconSim.isAllowed() == true)
	end)

	r.section("[2] 덮어쓰기 복원", function()
		local whatIf = { growthRate = 1.2, weaponGrowthRate = 1.3, dealingMultiplier = 0.5, enhanceCostScale = 2 }
		local inside = EconSim.withOverrides(whatIf, function()
			return { InfiniteStageConfig.growthRate, CharacterLevelConfig.weaponMultGrowthRate, SkillData.healer.E.attackMultiplier, EnhanceConfig.goldCost[1] }
		end)
		local restored = sameSnapshot(before, snapshot())
		r.check(("2 정상 경로: 안 %s · %s · %s · %s(기대 1.2 · 1.3 · 절반 · 2배) → 밖 되돌림 %s"):format(tostring(inside[1]), tostring(inside[2]), tostring(inside[3]), tostring(inside[4]), tostring(restored)),
			inside[1] == 1.2 and inside[2] == 1.3 and inside[3] == before.dealing * 0.5 and inside[4] == before.goldCost[1] * 2 and restored)
		local ok, err = pcall(EconSim.withOverrides, whatIf, function()
			error("의도한 에러")
		end)
		local restoredAfterError, key = sameSnapshot(before, snapshot())
		r.check(("3 에러 경로: 에러 전달 %s(%s) · 되돌림 %s%s"):format(tostring(not ok), tostring(err), tostring(restoredAfterError), key and (" - 어긋난 칸 " .. key) or ""), not ok and restoredAfterError)
	end)

	local data
	r.section("[3] 기준선 전체 실행", function()
		local started = os.clock()
		local summary
		summary, data = EconSimReport.run({ profileArg = "all", whatIfName = "baseline" })
		print(("[P0][가][요약] %s"):format(summary))
		r.check(("4 /gg econ all baseline과 같은 함수 실행 성공 - %.1f초"):format(os.clock() - started), data ~= nil)
	end)

	if data then
		r.section("[4] 표본 대조", function()
			for index, sample in ipairs(data.samples) do
				r.check(("5.%d 표본 %s: 시뮬 %.4f · 기대 %.4f"):format(index, sample.id, sample.value, sample.expected), sample.ok)
			end
		end)
		r.section("[5] 결과 모양", function()
			for _, id in ipairs(EconSimConfig.profileOrder) do
				local run = data.runs[id]
				local last = -1
				local monotone = true
				for _, milestone in ipairs(run.milestones) do
					local record = run.reached[milestone]
					if record then
						monotone = monotone and record.seconds >= last
						last = record.seconds
					end
				end
				local reached100 = run.reached[100] ~= nil
				local finished = run.stall ~= nil or run.final.reach >= InfiniteStageConfig.safeStageCap
				r.check(("6 %s: 스테이지 100 도달 %s · 이정표 시간 단조 %s · 끝 = %s(최고 %d)"):format(id, tostring(reached100), tostring(monotone), run.stall and "진행 정지 사유 있음" or "SafeStageCap", run.final.reach),
					reached100 and monotone and finished)
			end
			-- P2 F: 치유모드에도 딜 옵션이 100% 들어가(게임과 같은 모형) 장비 단계가 올라도 비중이 거의 안 변한다 - 세 단계 모두 목표 이상인지(결과 모양).
			local tiers = data.healer.tiers
			local target = EconSimConfig.healer.shareTarget
			r.check(("7 E6 도적 3 + 치유사 1 비중 없음 %.2f%% · 평균 %.2f%% · 상위 %.2f%%(기대 전부 ≥ %.0f%%)"):format(tiers.none.share.dualblade * 100, tiers.average.share.dualblade * 100, tiers.top.share.dualblade * 100, target * 100),
				tiers.none.share.dualblade >= target and tiers.average.share.dualblade >= target and tiers.top.share.dualblade >= target)
			-- P2.5a 목표(결과 모양): 일반 환생 5회차 약 12시간 · 첫 12시간 레벨업 평균 ≤ 5분 · 스테이지 10 ≤ 30분 · 상위 1% 설계 최대 도달 ≈ 2,190시간(±10%).
			local normal, top = data.runs.normal, data.runs.top
			local rebirth5 = normal.rebirthAt[5] and normal.rebirthAt[5] / 3600 or math.huge
			local t, n, sum = 0, 0, 0
			for _, chunk in ipairs(normal.chunks) do
				local dur = chunk.seconds + chunk.bossSeconds
				t += dur
				if t > 12 * 3600 then
					break
				end
				n += 1
				sum += dur
			end
			local avgMinutes = n > 0 and sum / n / 60 or math.huge
			local stage10 = normal.reached[10] and normal.reached[10].seconds / 3600 or math.huge
			local design = InfiniteStageConfig.designMaxStage
			local topDesign = top.reached[design] and top.reached[design].seconds / 3600 or math.huge
			local goal = EconSimConfig.targets -- D1-3: 목표 = 현실 모형 기준(허용 = ±tolerance에 모형 오차 modelNoise를 더한 폭)
			local lo, hi = goal.topDesignHours * (1 - goal.topDesignTolerance) * (1 - goal.modelNoise), goal.topDesignHours * (1 + goal.topDesignTolerance) * (1 + goal.modelNoise)
			r.check(("9 P2.5a 일반: 환생 5회차 %.2f시간(기대 11 ~ 13) · 첫 12시간 레벨업 평균 %.2f분(기대 ≤ 5) · 스테이지 10 %.2f시간(기대 ≤ 0.5) / 상위 1%% 설계 최대 %d 도달 %.0f시간(기대 %.0f ~ %.0f)"):format(
				rebirth5, avgMinutes, stage10, design, topDesign, lo, hi),
				rebirth5 >= 11 and rebirth5 <= 13 and avgMinutes <= 5 and stage10 <= 0.5 and topDesign >= lo and topDesign <= hi)
			-- D1-3: 캐주얼 스테이지 1,000 도달(현실 모형 목표 - EconSimConfig.targets.casualStage1000Hours)
			local casual = data.runs.casual
			local casual1000 = casual and casual.reached[1000] and casual.reached[1000].seconds / 3600 or math.huge
			local band = goal.casualStage1000Hours
			r.check(("9b D1-3 캐주얼 스테이지 1,000 도달 %.1f시간(기대 %d ~ %d)"):format(casual1000, band[1], band[2]), casual1000 >= band[1] and casual1000 <= band[2])
		end)
	end

	r.section("[6] 게임 데이터 표 불변", function()
		local same, key = sameSnapshot(before, snapshot())
		r.check(("8 실행 뒤 InfiniteStageConfig · CharacterLevelConfig · SkillData · EnhanceConfig · ClassData · OptionData · GoldCostConfig · DropTableData가 실행 전과 같은 값 · 같은 표 %s%s"):format(tostring(same), key and (" - 어긋난 칸 " .. key) or ""), same)
	end)

	local pass, total = r.summary()
	print(("===P0 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

return EconSimVerify
