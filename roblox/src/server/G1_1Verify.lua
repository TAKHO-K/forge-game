-- G1-1 자동 검증(docs/phase/G1-1-report.md) - 표시 · 문구 묶음.
--   (가) 등급 색 단일 출처 · 태초 색 구분 · Text 템플릿 · 보스 등급표 분리(값 불변) · 재도전 굴림 분포
--   (나) 보상 띠 서버 응답의 강화석 = 지급과 같은 식(경험치 배수 포함 - 옵션을 붙이면 같이 오른다)
-- 클라 쪽(3타 고리 · 2단 도움말 · 확률표 이름 · 보상 띠 문자열)은 client/G1_1UiCheck.client.lua([G1-1][UI]) · S11(UI)가 본다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local TextData = require(ReplicatedStorage.Shared.data.TextData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local Loot = require(ReplicatedStorage.Shared.Loot)
local Text = require(ReplicatedStorage.Shared.Text)

local G1_1Verify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local r = {}
	function r.check(label, ok)
		totalCount += 1
		passCount += ok and 1 or 0
		print(("[G1-1][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function colorDistance(a, b)
	return math.sqrt((a.R - b.R) ^ 2 + (a.G - b.G) ^ 2 + (a.B - b.B) ^ 2) * 255
end

function G1_1Verify.runPure()
	print("===G1-1 검증 시작(가)===")
	local r = newRecorder("가")

	r.section("등급 색", function()
		local primordial = GradeColor.of("primordial")
		local nearest, nearestId = math.huge, nil
		for _, gradeId in ipairs(ArmorData.gradeOrder) do
			if gradeId ~= "primordial" then
				local d = colorDistance(primordial, GradeColor.of(gradeId))
				if d < nearest then
					nearest, nearestId = d, gradeId
				end
			end
		end
		local white = colorDistance(primordial, Color3.new(1, 1, 1))
		r.check(("태초 색 %s: 가장 가까운 등급 %s까지 %.0f(기대 ≥ 80) · 흰색까지 %.0f(기대 ≥ 150) · GradeColor.of = ItemVisualData 값 %s · hex %s"):format(
			GradeColor.hex("primordial"), tostring(nearestId), nearest, white, tostring(primordial == ItemVisualData.gradeVisuals.primordial.color), GradeColor.hex("primordial")),
			nearest >= 80 and white >= 150 and primordial == ItemVisualData.gradeVisuals.primordial.color and GradeColor.hex("primordial") == "#ff3cc8")
	end)

	r.section("Text 템플릿", function()
		local filled = Text.get("gemForge.fodderHeader", { count = 3 })
		local missingArgs = 0
		for key, template in pairs(TextData.ko) do
			local _, n = template:gsub("{([%w_]+)}", "")
			if n > 0 then
				local probe = Text.get(key, setmetatable({}, { __index = function() return "x" end }))
				missingArgs += probe:find("{", 1, true) and not probe:find("<font", 1, true) and 1 or 0
			end
		end
		r.check(("이름 인자 채움: [%s](기대 '3개' 포함 · '{' 없음) · 모든 키 인자 채움 뒤 남은 자리 %d(기대 0)"):format(filled, missingArgs),
			filled:find("3개", 1, true) ~= nil and filled:find("{", 1, true) == nil and missingArgs == 0)
	end)

	r.section("보스 등급표 분리 · 값(D1 개편)", function()
		-- D1(2026-09-27): 첫 클리어 = 영웅 이상 보장 표(잡몹 tier6과 분리 · 환생 0회 상향표 폐지) · 재도전 = 토벌 표. 옛 기대(tier6 · tier1 값 · 환생 0회 태초 2%)는 D1 결정으로 바뀌었다.
		local firstClear, raid = DropTableData.bossGrades.firstClear, DropTableData.bossGrades.raid
		local sumF, sumR = 0, 0
		for _, chance in pairs(firstClear) do
			sumF += chance
		end
		for _, chance in pairs(raid) do
			sumR += chance
		end
		r.check(("첫 클리어 표(합 %.4f · 태초 %.4f%%) ≠ 잡몹 tier6 표 %s · 재도전 = 토벌 표(합 %.4f) · 환생 0회 = 1회 표 %s"):format(sumF, (firstClear.primordial or 0) * 100,
			tostring(firstClear ~= DropTableData.armorGradeByTier[6]), sumR, tostring(DropTable.bossFirstClearGradeTable(0) == DropTable.bossFirstClearGradeTable(1))),
			math.abs(sumF - 1) < 1e-9 and math.abs(sumR - 1) < 1e-9 and firstClear ~= DropTableData.armorGradeByTier[6] and DropTable.bossRetryGradeTable() == raid
				and DropTable.bossFirstClearGradeTable(0) == firstClear and DropTable.bossFirstClearGradeTable(1) == firstClear)
	end)

	r.section("재도전(토벌) 굴림 분포", function()
		local counts, n = {}, 20000
		for _ = 1, n do
			local item = Loot.rollBossRetryDrop(100, "greatsword")
			counts[item.grade] = (counts[item.grade] or 0) + 1
		end
		local epic, legendary = (counts.epic or 0) / n, (counts.legendary or 0) / n
		local below = (counts.normal or 0) + (counts.rare or 0)
		r.check(("재도전 %d회: 영웅 %.3f · 전설 %.3f(기대 0.78 · 0.209 ± 0.01) · 일반 · 희귀 %d(기대 0)"):format(n, epic, legendary, below),
			math.abs(epic - 0.78) < 0.01 and math.abs(legendary - 0.20948) < 0.01 and below == 0)
	end)

	local pass, count = r.summary()
	print(("===G1-1 검증 끝(가)=== %d/%d 통과"):format(pass, count))
end

function G1_1Verify.runLive(player, env)
	print("===G1-1 검증 시작(나)===")
	local r = newRecorder("나")
	env.ensureBackup(player)
	local BossRewardPreview = require(script.Parent.BossRewardPreview)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local PartyState = require(script.Parent.PartyState)
	local grantStage = nil
	for _, material in pairs(EnhanceMaterialData.materials) do
		grantStage = math.max(grantStage or 0, material.minStage)
	end
	-- 모든 재료가 나오는 첫 보스 스테이지
	local stage = math.ceil(grantStage / BossData.stageInterval) * BossData.stageInterval

	r.section("강화석 기대 = 지급 식(경험치 배수 포함)", function()
		local function check(label)
			local entry = BossRewardPreview.build(player, { stage }).entries[1]
			local multiplier = PlayerProfile.combineExpMultiplier(PlayerProfile.getOptionBonus(player, "expGain"), PartyState.getExpBonusFor(player))
			local units = BossData.bosses[entry.bossId].hpMultiplier
			local ok, parts = #entry.stones == #EnhanceMaterialData.order, {}
			for _, stone in ipairs(entry.stones) do
				local expected = Loot.expectedMaterialCount(stone.id, units, multiplier)
				ok = ok and math.abs(stone.expected - expected) < 1e-9
				table.insert(parts, ("%s %.3f(기대 %.3f)"):format(stone.id, stone.expected, expected))
			end
			r.check(("%s 스테이지 %d: 경험치 배수 %.3f · %s"):format(label, stage, multiplier, table.concat(parts, " · ")), ok)
			return entry.stones[1] and entry.stones[1].expected or 0, multiplier
		end
		env.applyOptionStack(player, "attackPercent")
		local before, m0 = check("옵션 없음")
		env.applyOptionStack(player, "expGain")
		local after, m1 = check("성장 옵션 스택")
		r.check(("성장 옵션을 붙이면 띠의 강화석도 오른다: %.3f → %.3f(배수 %.3f → %.3f · 비 %.4f = %.4f)"):format(before, after, m0, m1, after / math.max(before, 1e-9), m1 / math.max(m0, 1e-9)),
			m1 > m0 and math.abs(after / before - m1 / m0) < 1e-6)
	end)

	env.restore(player)
	local pass, count = r.summary()
	print(("===G1-1 검증 끝(나)=== %d/%d 통과"):format(pass, count))
end

return G1_1Verify
