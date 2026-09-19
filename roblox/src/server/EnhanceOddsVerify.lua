-- S07 자동 검증(PRD 20.72 [1-8] · 20.89) - 강화 UI가 읽는 순수 함수. (가) 하나뿐이다(UI 자체의 검증은 클라 콘솔 · 스크린샷).
-- 화면의 확률표는 Enhance.getOutcomeTable(= 서버 판정과 같은 함수)에서 나온다. 이 블록은 그 표가 모든 칸에서 합 1이고, 토글을 쓸 수 없는 단계에서 켜도 서버가 실제로 쓰는 표와 같은지,
-- 그리고 화면이 "되는 단계" · "위험 시작 단계" · "최악의 단계"를 읽는 함수가 PRD의 예시 값과 맞는지 본다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local Enhance = require(ReplicatedStorage.Shared.Enhance)

local EnhanceOddsVerify = {}

local RESULT_KEYS = { "success", "maintain", "down1", "down2", "reset" }

local function sumOf(outcomes)
	local sum = 0
	for _, key in ipairs(RESULT_KEYS) do
		sum += outcomes[key]
	end
	return sum
end

local function sameTable(a, b)
	for _, key in ipairs(RESULT_KEYS) do
		if math.abs(a[key] - b[key]) > 1e-12 then
			return false
		end
	end
	return true
end

function EnhanceOddsVerify.runPure()
	print("===S07 검증 시작(가: 강화 UI가 읽는 순수 함수)===")
	local passCount, totalCount = 0, 0
	local function check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S07][가] %s %s"):format(label, ok and "O" or "X"))
	end

	-- 1. 0 ~ 24강 × 토글 4조합 × 기운 가득 / 아님 = 200칸: 합 1(1e-9).
	local cells, badSum = 0, 0
	for level = 0, EnhanceConfig.maxLevel - 1 do
		for _, gaugeFull in ipairs({ false, true }) do
			for _, useDrop in ipairs({ false, true }) do
				for _, useReset in ipairs({ false, true }) do
					cells += 1
					if math.abs(sumOf(Enhance.getOutcomeTable(level, gaugeFull, useDrop, useReset)) - 1) > 1e-9 then
						badSum += 1
					end
				end
			end
		end
	end
	check(("표의 합: %d칸 중 합이 1에서 어긋난 칸 %d(기대 200 · 0)"):format(cells, badSum), cells == 200 and badSum == 0)

	-- 2. 토글이 쓸 수 없는 단계 · 기운 가득에서 켜도 서버가 실제로 쓰는 표와 같다: 서버는 resolveProtectionFlags로 플래그를 거른 뒤(보유는 넉넉히 5장) 그 값으로 판정한다.
	local mismatches, serverCells = 0, 0
	for level = 0, EnhanceConfig.maxLevel - 1 do
		for _, gaugeFull in ipairs({ false, true }) do
			for _, wantDrop in ipairs({ false, true }) do
				for _, wantReset in ipairs({ false, true }) do
					serverCells += 1
					local useDrop, useReset = Enhance.resolveProtectionFlags(level, gaugeFull, wantDrop, wantReset, 5, 5)
					if not sameTable(Enhance.getOutcomeTable(level, gaugeFull, wantDrop, wantReset), Enhance.getOutcomeTable(level, gaugeFull, useDrop, useReset)) then
						mismatches += 1
					end
				end
			end
		end
	end
	check(("토글 요청 표 = 서버가 거른 뒤의 표: %d칸 중 다른 칸 %d(기대 0)"):format(serverCells, mismatches), mismatches == 0)

	-- 3. "되는 단계" 열(PRD 20.72 [1-8] 예시): +19 = 20 · 19 · 18, +23 = 24 · 23 · 22 · 21 · 12, +10은 유지(10)만 값이 있다.
	local function levels(level)
		local cellsOut = {}
		for _, key in ipairs(RESULT_KEYS) do
			table.insert(cellsOut, Enhance.getResultLevel(level, key))
		end
		return table.concat(cellsOut, "/")
	end
	check(("되는 단계 열(성공/유지/1강/2강/초기화): +19 = %s(기대 20/19/18/18/12) · +23 = %s(기대 24/23/22/21/12)"):format(levels(19), levels(23)),
		levels(19) == "20/19/18/18/12" and levels(23) == "24/23/22/21/12")
	local table10 = Enhance.getOutcomeTable(10, false, false, false)
	check(("+10 표: 성공 %.2f · 유지 %.2f · 하락 · 초기화 0(기대 0.62 · 0.38 · 0)"):format(table10.success, table10.maintain),
		math.abs(table10.success - 0.62) < 1e-12 and math.abs(table10.maintain - 0.38) < 1e-12 and table10.down1 + table10.down2 + table10.reset == 0)

	-- 4. 위험 시작 단계(화면의 확인창 · 도움말이 읽는다) = 19 · 22, 방지권이 쓰이는 단계와 같은 값.
	local dropFrom, resetFrom = Enhance.getRiskStartLevels()
	check(("위험 시작 단계: 하락 %s · 초기화 %s(기대 19 · 22) · 방지권 사용 단계 %d · %d와 같음"):format(tostring(dropFrom), tostring(resetFrom),
		EnhanceConfig.protection.drop.usableFromLevel, EnhanceConfig.protection.reset.usableFromLevel),
		dropFrom == 19 and resetFrom == 22 and dropFrom == EnhanceConfig.protection.drop.usableFromLevel and resetFrom == EnhanceConfig.protection.reset.usableFromLevel)

	-- 5. 최악의 단계: 0 ~ 18강은 그대로(하락 없음) · 19강 = 18 · 20강 = 18 · 21강 = 19 · 22 ~ 24강 = 초기화 단계 12 · 상한은 nil.
	local worst = {}
	for _, level in ipairs({ 0, 10, 18, 19, 20, 21, 22, 23, 24 }) do
		table.insert(worst, ("%d→%s"):format(level, tostring(Enhance.getWorstLevel(level))))
	end
	local okWorst = Enhance.getWorstLevel(0) == 0 and Enhance.getWorstLevel(10) == 10 and Enhance.getWorstLevel(18) == 18
		and Enhance.getWorstLevel(19) == 18 and Enhance.getWorstLevel(20) == 18 and Enhance.getWorstLevel(21) == 19
		and Enhance.getWorstLevel(22) == EnhanceConfig.resetToLevel and Enhance.getWorstLevel(23) == EnhanceConfig.resetToLevel
		and Enhance.getWorstLevel(24) == EnhanceConfig.resetToLevel and Enhance.getWorstLevel(EnhanceConfig.maxLevel) == nil
	check(("최악의 단계: %s · 상한 nil(기대 0→0 · 10→10 · 18→18 · 19→18 · 20→18 · 21→19 · 22 ~ 24→12 · 상한 nil)"):format(table.concat(worst, " ")), okWorst)

	print(("===S07 검증 끝(가)=== %d/%d 통과"):format(passCount, totalCount))
end

return EnhanceOddsVerify
