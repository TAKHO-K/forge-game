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

	print(("===Q 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

return V
