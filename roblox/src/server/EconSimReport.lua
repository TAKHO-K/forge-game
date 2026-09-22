-- 경제 시뮬 보고서(P0 E3 ~ E8). EconSim(진행) · EconSimTables(표)를 한 번 돌려 결과를 Studio 출력 창에 찍는다:
--   [ECON] BEGIN/END 줄 사이에 [ECONMD] 마크다운 줄 · [ECONCSV:<표>] CSV 줄. docs/econ/_extract.py가 로그 파일에서 가장 최근 실행을 골라
--   docs/econ/E1-<what-if>.md + E1-<what-if>-<표>.csv로 옮긴다(Studio 서버는 저장소 파일을 직접 못 쓴다).
-- 채팅(DevTools reply)에는 run()이 돌려주는 요약 한 줄만 간다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local EconSim = require(script.Parent.EconSim)
local EconSimTables = require(script.Parent.EconSimTables)

local EconSimReport = {}

local function num(value, digits)
	if value == nil then
		return "-"
	end
	if value ~= value then
		return "NaN"
	end
	if value == math.huge then
		return "∞"
	end
	local magnitude = math.abs(value)
	if magnitude >= 1e6 then
		return ("%.3e"):format(value)
	end
	return ("%." .. tostring(digits or 1) .. "f"):format(value)
end
EconSimReport.num = num

local function pct(value)
	return value and ("%.1f%%"):format(value * 100) or "-"
end

-- 출력기: 줄을 모았다가 finish에서 한꺼번에 찍는다(계산 도중의 경고와 섞이지 않게).
local function newWriter(runId)
	local writer = { md = {}, csv = {}, csvOrder = {} }
	function writer.line(text)
		table.insert(writer.md, text or "")
	end
	function writer.row(tableName, cells)
		if not writer.csv[tableName] then
			writer.csv[tableName] = {}
			table.insert(writer.csvOrder, tableName)
		end
		local escaped = {}
		for index, cell in ipairs(cells) do
			local text = tostring(cell)
			if text:find("[,\"]") then
				text = '"' .. text:gsub('"', '""') .. '"'
			end
			escaped[index] = text
		end
		table.insert(writer.csv[tableName], table.concat(escaped, ","))
	end
	function writer.flush(header)
		print(("[ECON] BEGIN %s"):format(header))
		for index, text in ipairs(writer.md) do
			print(("[ECONMD] %s"):format(text))
			if index % 200 == 0 then
				task.wait() -- 출력 창 버퍼가 한 틱에 넘치지 않게
			end
		end
		for _, tableName in ipairs(writer.csvOrder) do
			for _, text in ipairs(writer.csv[tableName]) do
				print(("[ECONCSV:%s] %s"):format(tableName, text))
			end
		end
		print(("[ECON] END %s"):format(runId))
	end
	return writer
end

local function hours(seconds)
	return seconds / 3600
end

-- ═══ E3 ═══
local function writeE3(w, runs, profileIds)
	w.line("## E3 도달 시간 곡선")
	w.line("")
	w.line("누적 = 그 스테이지에 처음 설 수 있게 된 순간(그 아래 보스를 전부 깬 순간)까지의 플레이 시간. 달력 일수 = 누적 ÷ 하루 플레이 시간. 칸의 괄호 = 그 순간 레벨 · 환생 · 강화.")
	w.line("")
	local header = { "스테이지" }
	local sep = { "---" }
	for _, id in ipairs(profileIds) do
		local profile = EconSimConfig.profiles[id]
		table.insert(header, ("%s 누적(시간)"):format(profile.displayName))
		table.insert(header, ("%s 달력(일)"):format(profile.displayName))
		table.insert(sep, "---")
		table.insert(sep, "---")
	end
	w.line("| " .. table.concat(header, " | ") .. " |")
	w.line("|" .. table.concat(sep, "|") .. "|")
	w.row("e3", { "profile", "stage", "play_hours", "calendar_days", "level", "rebirth", "weapon_level", "weapon_grade", "status" })
	local milestones = runs[profileIds[1]].milestones
	for _, milestone in ipairs(milestones) do
		local cells = { tostring(milestone) .. (milestone == InfiniteStageConfig.safeStageCap and "(SafeStageCap)" or "") }
		for _, id in ipairs(profileIds) do
			local run = runs[id]
			local profile = EconSimConfig.profiles[id]
			local record = run.reached[milestone]
			if record then
				local h = hours(record.seconds)
				table.insert(cells, ("%s (Lv%d · 환생%d · +%d)"):format(num(h, 1), record.level, record.rebirth, record.weaponLevel))
				table.insert(cells, num(h / profile.hoursPerDay, 1))
				w.row("e3", { id, milestone, ("%.3f"):format(h), ("%.2f"):format(h / profile.hoursPerDay), record.level, record.rebirth, record.weaponLevel, record.weaponGrade, "ok" })
			else
				table.insert(cells, "[없음]")
				table.insert(cells, "[없음]")
				w.row("e3", { id, milestone, "", "", "", "", "", "", "none" })
			end
		end
		w.line("| " .. table.concat(cells, " | ") .. " |")
	end
	w.line("")
	for _, id in ipairs(profileIds) do
		local run = runs[id]
		local final = run.final
		local profile = EconSimConfig.profiles[id]
		local total = final.huntSeconds + final.bossSeconds
		w.line(("- **%s**: 최종 최고 스테이지 %d · 레벨 %d(환생 %d) · 강화 +%d · 누적 %s시간(%s일) · 사냥 %s : 보스 %s · 보스 클리어 %d회 · 강화 시도 %d회 · 변환권 %d장. %s"):format(
			profile.displayName, final.reach, final.level, final.rebirth, final.weaponLevel, num(hours(final.seconds), 1), num(hours(final.seconds) / profile.hoursPerDay, 1),
			pct(total > 0 and final.huntSeconds / total or 0), pct(total > 0 and final.bossSeconds / total or 0), final.bossClears, final.enhanceAttempts, final.rerollTickets,
			run.stall and ("**진행 정지([없음] 사유)**: " .. run.stall) or "SafeStageCap 도달."))
	end
	w.line("")
end

-- ═══ E4 ═══
local function segmentBounds()
	local list = {}
	for _, pair in ipairs(EconSimConfig.segments) do
		local hi = pair[2] == "cap" and InfiniteStageConfig.safeStageCap or pair[2]
		table.insert(list, { lo = pair[1], hi = hi, label = ("%d ~ %d"):format(pair[1], hi) })
	end
	return list
end

local function writeE4(w, runs, profileIds, enhanceTable)
	w.line("## E4 구간별 경제표")
	w.line("")
	w.line("구간 = 그 청크(레벨업 1회) 동안의 최고 스테이지. 골드 · EXP/분 = 구간 전체(사냥 + 보스) 합 ÷ 시간. 강화 비용 = 구간 끝 강화 단계 기준(다음 1회 = `Enhance.getCost`, 다음 단계 기대 = 몬테카를로 표). 구매력 = 골드/분 ÷ 다음 1회 비용. 보석 = 구간 끝(칸 수 · 평균 itemLevel · 위력 합).")
	w.line("")
	w.line("| 구간 | 프로필 | 골드/분 | EXP/분 | 다음 강화 1회 | 다음 단계 기대 골드 | 구매력 | 장비 교체 간격(분) | 보석 칸 · 평균 레벨 · 위력 합 | 레벨 범위 | 사냥 스테이지 범위 |")
	w.line("|---|---|---|---|---|---|---|---|---|---|---|")
	w.row("e4", { "segment", "profile", "gold_per_min", "exp_per_min", "next_attempt_cost", "next_level_expected_gold", "purchasing_power", "gear_replace_interval_min", "gem_slots", "gem_avg_level", "gem_attack_bonus", "enhance_level", "minutes" })
	for _, segment in ipairs(segmentBounds()) do
		for _, id in ipairs(profileIds) do
			local run = runs[id]
			local profile = EconSimConfig.profiles[id]
			local seconds, gold, exp, replaced = 0, 0, 0, 0
			local last, first = nil, nil
			for _, chunk in ipairs(run.chunks) do
				if chunk.reach >= segment.lo and chunk.reach <= segment.hi then
					seconds += chunk.seconds + chunk.bossSeconds
					gold += chunk.gold + chunk.bossGold
					exp += chunk.exp + chunk.bossExp
					replaced += chunk.gearReplaced
					first = first or chunk
					last = chunk
				end
			end
			if not last or seconds <= 0 then
				w.line(("| %s | %s | [없음] | | | | | | | | 이 구간에 닿기 전에 진행 정지 |"):format(segment.label, profile.displayName))
				w.row("e4", { segment.label, id, "", "", "", "", "", "", "", "", "", "", "" })
			else
				local minutes = seconds / 60
				local goldPerMin, expPerMin = gold / minutes, exp / minutes
				local cost = Enhance.getCost(last.weaponLevel)
				local expected = enhanceTable[last.weaponLevel]
				local power = cost and goldPerMin / cost or nil
				local interval = replaced > 0 and minutes / replaced or nil
				w.line(("| %s | %s | %s | %s | %s | %s | %s | %s | %d칸 · %s · %s | %d ~ %d | %d ~ %d |"):format(
					segment.label, profile.displayName, num(goldPerMin, 0), num(expPerMin, 0),
					cost and ("+%d→+%d %s"):format(last.weaponLevel, last.weaponLevel + 1, num(cost, 0)) or ("+%d 최대 [없음]"):format(last.weaponLevel),
					expected and num(expected.gold, 0) or "[없음]", power and num(power, 1) or "[없음]", interval and num(interval, 1) or "교체 없음",
					last.gemCount, num(last.gemAvgLevel, 0), pct(last.gemAttackBonus), first.level, last.level, first.stage, last.stage))
				w.row("e4", { segment.label, id, goldPerMin, expPerMin, cost or "", expected and expected.gold or "", power or "", interval or "", last.gemCount, last.gemAvgLevel, last.gemAttackBonus, last.weaponLevel, minutes })
			end
		end
	end
	w.line("")
	w.line("### 강화 단계별 기대 비용(몬테카를로 - `Enhance.tryEnhance` 그대로, 천장 · 하락 · 초기화 포함, 방지권 없음)")
	w.line("")
	w.line("| 단계 | 1회 비용 | 기대 시도 | 기대 골드 | 기대 재료 |")
	w.line("|---|---|---|---|---|")
	w.row("enhance", { "from_level", "attempt_cost", "expected_attempts", "expected_gold", "expected_materials" })
	for level = 0, EnhanceConfig.maxLevel - 1 do
		local row = enhanceTable[level]
		local mats = {}
		for id, count in pairs(row.materials) do
			table.insert(mats, ("%s %s"):format(id, num(count, 1)))
		end
		table.sort(mats)
		w.line(("| +%d→+%d | %s | %s | %s | %s |"):format(level, level + 1, num(Enhance.getCost(level), 0), num(row.attempts, 2), num(row.gold, 0), #mats > 0 and table.concat(mats, " · ") or "-"))
		w.row("enhance", { level, Enhance.getCost(level), row.attempts, row.gold, table.concat(mats, " ") })
	end
	w.line("")
end

-- ═══ E5 ═══
local function writeE5(w, rows, whatIf)
	local cfg = EconSimConfig.primordial
	w.line("## E5 태초 선택지 손익분기(what-if 전용 - 게임 코드 무변경)")
	w.line("")
	w.line(("비교: (A) tier%d를 사냥 스테이지 − Δ에서 vs (B) tier%d를 사냥 스테이지 sB에서(sB = '일반' 프로필 기준 목표 처치 초 안에 잡히는 가장 높은 스테이지, 앵커 장비). 값 = A의 태초 기대 가치/분 ÷ B의 것(태초 위력 옵션 값 × 태초 개수/분). 1 초과 = A 우세(낮은 레벨 고tier가 태초 기준 지배 전략 후보). 스위치 ① 보석 레벨 = 잡은 몬스터 레벨: %s. 태초 확률: A = %s, B = A ÷ 배수%s."):format(
		cfg.highTier, cfg.lowTier, cfg.gemLevelIsMonsterLevel and "켬" or "끔", pct(EconSimTables.primordialChance(cfg.highTier, whatIf)),
		(whatIf and whatIf.primordialByTier) and "(what-if 표 사용 - 배수 대신 표의 tier 확률)" or ""))
	w.line("")
	w.line("현재 게임(tier1 ~ 5 태초 0%)에서는 B의 태초가 0이라 모든 칸이 A 우세(∞)다 - 아래 배수 표는 \"B에도 태초를 준다면\"의 what-if다.")
	w.line("")
	w.row("e5", { "label", "player_level", "delta", "stage_a", "stage_b", "freeze", "multiplier", "p_a", "p_b", "value_a", "value_b", "kill_a", "kill_b", "ratio", "gold_ratio", "exp_ratio" })
	local custom = whatIf and whatIf.primordialByTier
	local multipliers = custom and { "표" } or cfg.probabilityMultipliers
	local groups = {}
	for _, row in ipairs(rows) do
		w.row("e5", { row.label, row.playerLevel, row.delta, row.stageA, row.stageB, row.freeze and "on" or "off", row.multiplier, row.pA, row.pB, row.valueA, row.valueB, row.killA, row.killB, row.ratio, row.breakEven, row.goldRatio, row.expRatio })
		local key = ("%s|%d|%d|%d"):format(row.label, row.playerLevel, row.stageA, row.stageB)
		if not groups[key] then
			groups[key] = { first = row, ratios = { [true] = {}, [false] = {} }, breakEven = {} }
			table.insert(groups, groups[key])
		end
		table.insert(groups[key].ratios[row.freeze], row.ratio)
		groups[key].breakEven[row.freeze] = row.breakEven
		groups[key].value = groups[key].value or {}
		groups[key].value[row.freeze] = { row.valueA, row.valueB }
	end
	w.line("| 플레이어 레벨 | Δ | sA → sB | 처치 A · B(초) | 보석 값 A · B(동결 있음 / 없음) | 손익분기 배수 M*(동결 있음 · 없음) | " .. (function()
		local heads = {}
		for _, multiplier in ipairs(multipliers) do
			table.insert(heads, ("배수 %s: A÷B(동결 있음 · 없음)"):format(tostring(multiplier)))
		end
		return table.concat(heads, " | ")
	end)() .. " | 골드/분 A÷B |")
	w.line("|" .. string.rep("---|", 7 + #multipliers))
	for _, group in ipairs(groups) do
		local row = group.first
		local cells = {}
		for index = 1, #multipliers do
			local on, off = group.ratios[true][index], group.ratios[false][index]
			local function mark(ratio)
				return ratio > 1 and ("**%s**"):format(num(ratio, 2)) or num(ratio, 2)
			end
			table.insert(cells, ("%s · %s"):format(mark(on), mark(off)))
		end
		w.line(("| %s%d | %d | %d → %d | %s · %s | %s · %s / %s · %s | %s · %s | %s | %s |"):format(row.label == "example" and "예시 " or "", row.playerLevel, row.delta, row.stageA, row.stageB,
			num(row.killA, 2), num(row.killB, 2), pct(group.value[true][1]), pct(group.value[true][2]), pct(group.value[false][1]), pct(group.value[false][2]),
			custom and "-" or num(group.breakEven[true], 2), custom and "-" or num(group.breakEven[false], 2), table.concat(cells, " | "), ("%.3g"):format(row.goldRatio)))
	end
	w.line("")
	w.line("굵은 글씨 = A÷B > 1(A 우세). **배수 ≤ M*이면 낮은 레벨 고tier가 태초 기준 지배 전략이 아니다** - M*가 그 Δ에서 \"B(저tier · 자기 레벨)의 태초 확률을 A의 몇 분의 1까지 낮춰도 되는가\"다.")
	w.line("")
	w.line("### 지배 전략이 안 되는 (Δ, 배수) - 격자 칸 중 A÷B ≤ 1")
	w.line("")
	for _, freeze in ipairs({ true, false }) do
		for _, playerLevel in ipairs(cfg.playerLevels) do
			local safe = {}
			for _, row in ipairs(rows) do
				if row.label == "grid" and row.freeze == freeze and row.playerLevel == playerLevel and row.ratio <= 1 then
					table.insert(safe, ("Δ%d×%s"):format(row.delta, tostring(row.multiplier)))
				end
			end
			w.line(("- 동결 %s · 레벨 %d: %s"):format(freeze and "있음" or "없음", playerLevel, #safe > 0 and table.concat(safe, ", ") or "없음(전 칸 A 우세)"))
		end
	end
	w.line("")
end

-- ═══ E6 ═══
local function className(classId)
	return ClassData.classes[classId].displayName
end

local function writeE6(w, healer)
	local cfg = EconSimConfig.healer
	w.line("## E6 치유사 r과 장비 성장")
	w.line("")
	w.line(("앵커: 레벨 100 · 무기 등급 0 · +0강(S21-0 D2와 같은 조건). 60초 로테이션 총딜, 치명 옵션은 평타에만(AttackServer와 같다). 치유모드 치유사 딜 = 딜 옵션 미적용 딜링모드 총딜 × 보스전 전투 비율 %.4f(PartyShieldSim · 치유 모드 · 회복 0 = S21-0 D2의 0.266 - 쉴드 모드였다면 %.4f). r = 그 딜 ÷ 검사 딜(같은 장비 단계). 비중 = r ÷ (딜러 3 + r). 보상 문턱 = %s(CombatConfig)."):format(
		healer.fightRatio.heal, healer.fightRatio.shield, pct(healer.contributionThreshold)))
	w.line("")
	w.line("| 장비 단계 | 검사 · 도적 · 궁수 60초 딜(atk 단위) | 검사 배율 | 치유사(딜 옵션 적용 시) 배율 | 치유모드 r | 4인 보스전 비중 | r(딜러 궁수 · 도적 · 검사) | 딜링모드 r(옵션 적용) |")
	w.line("|---|---|---|---|---|---|---|---|")
	w.row("e6_tiers", { "tier", "gs_dps", "dual_dps", "bow_dps", "dealer_gain", "healer_own_gain", "r_heal", "share", "r_bow", "r_dual", "r_gs", "r_dealing" })
	local dropTier = nil
	for _, tier in ipairs(cfg.gearTiers) do
		local row = healer.tiers[tier.id]
		if not dropTier and row.share < cfg.shareFloor then
			dropTier = tier.displayName
		end
		w.line(("| %s | %s · %s · %s | ×%s | ×%s | %s | %s %s | %s · %s · %s | %s |"):format(row.displayName,
			num(row.dps.greatsword / healer.units.greatsword, 1), num(row.dps.dualblade / healer.units.dualblade, 1), num(row.dps.bow / healer.units.bow, 1),
			num(row.dealerGain, 3), num(row.healerOwnGain, 3), num(row.r, 4), pct(row.share), row.share >= cfg.shareFloor and "O" or "**X(10% 미만)**",
			num(row.rByDealer.bow, 4), num(row.rByDealer.dualblade, 4), num(row.rByDealer.greatsword, 4), num(row.rDealing, 4)))
		w.row("e6_tiers", { tier.id, row.dps.greatsword, row.dps.dualblade, row.dps.bow, row.dealerGain, row.healerOwnGain, row.r, row.share, row.rByDealer.bow, row.rByDealer.dualblade, row.rByDealer.greatsword, row.rDealing })
	end
	w.line("")
	w.line(("- 10%% 아래로 떨어지는 장비 단계: **%s**. 연속값으로는 검사 딜이 장비로 ×%s가 되는 순간 비중이 10%%가 된다(r ÷ 1/3)."):format(dropTier or "없음(세 단계 모두 10% 이상)", num(healer.dealerGainAtFloor, 3)))
	w.line("")
	w.line("### (가) 치유모드에 딜 옵션 적용률 a")
	w.line("")
	w.line("| a | " .. (function()
		local heads = {}
		for _, tier in ipairs(cfg.gearTiers) do
			table.insert(heads, tier.displayName .. " 비중")
		end
		return table.concat(heads, " | ")
	end)() .. " |")
	w.line("|" .. string.rep("---|", 1 + #cfg.gearTiers))
	w.row("e6_a", { "a", "none", "average", "top" })
	for _, row in ipairs(healer.applyRates) do
		local cells = {}
		local csv = { row.a }
		for _, tier in ipairs(cfg.gearTiers) do
			table.insert(cells, pct(row.shares[tier.id]))
			table.insert(csv, row.shares[tier.id])
		end
		w.line(("| %s | %s |"):format(num(row.a, 2), table.concat(cells, " | ")))
		w.row("e6_a", csv)
	end
	w.line("")
	w.line(("- 세 단계 모두 비중 ≥ %s가 되는 a: **%s**."):format(pct(cfg.shareTarget), healer.minApplyRate and ("a ≥ " .. num(healer.minApplyRate, 2)) or "[없음] - a = 1(딜러와 똑같이 적용)이어도 모자라다"))
	w.line("")
	w.line("### (나) 치유모드 전용 보석 계수 m(태초 기준값 - 위력 0.30과 같은 눈금, 칸 수 · 등급 · 레벨 · roll은 그 장비 단계 그대로)")
	w.line("")
	w.line("| m | " .. (function()
		local heads = {}
		for _, tier in ipairs(cfg.gearTiers) do
			table.insert(heads, tier.displayName .. " 비중")
		end
		return table.concat(heads, " | ")
	end)() .. " |")
	w.line("|" .. string.rep("---|", 1 + #cfg.gearTiers))
	w.row("e6_m", { "m", "none", "average", "top" })
	for _, row in ipairs(healer.gemCoefficients) do
		local cells = {}
		local csv = { row.m }
		for _, tier in ipairs(cfg.gearTiers) do
			table.insert(cells, pct(row.shares[tier.id]))
			table.insert(csv, row.shares[tier.id])
		end
		w.line(("| %s | %s |"):format(num(row.m, 2), table.concat(cells, " | ")))
		w.row("e6_m", csv)
	end
	w.line("")
	w.line(("- 세 단계 모두 비중 ≥ %s가 되는 m: **%s**. (장비 '없음' 단계는 보석이 없어 m이 아무리 커도 그대로다 - 그 단계의 비중이 문턱 아래면 m만으로는 못 맞춘다.)"):format(
		pct(cfg.shareTarget), healer.minGemCoefficient and ("m ≥ " .. num(healer.minGemCoefficient, 2)) or "[없음] - 격자(0 ~ 3) 안에서 못 맞춘다"))
	if healer.whatIfRow then
		local cells = {}
		for _, tier in ipairs(cfg.gearTiers) do
			table.insert(cells, ("%s %s"):format(tier.displayName, pct(healer.whatIfRow.shares[tier.id])))
		end
		w.line(("- what-if a = %s · m = %s: %s"):format(num(healer.whatIfRow.a, 2), num(healer.whatIfRow.m, 2), table.concat(cells, " · ")))
	end
	w.line("")
	w.line(("### 딜링모드 배율(지금 r = %s = 치유사 %s ÷ 검사 %s atk 단위, 장비 없음)"):format(num(healer.healerDealing / healer.greatswordBase, 4),
		num(healer.healerDealing / healer.units.healer, 1), num(healer.greatswordBase / healer.units.greatsword, 1)))
	w.line("")
	w.line("| 딜러 | 딜러 딜(atk 단위) | 목표 | 필요한 딜링모드 배율 | attackMultiplier(지금 값 × 배율) | 덮어써 다시 잰 치유사 ÷ 딜러 |")
	w.line("|---|---|---|---|---|---|")
	w.row("e6_dealing", { "dealer", "dealer_dps", "target", "factor", "attack_multiplier", "check_ratio" })
	for _, row in ipairs(healer.dealers) do
		for _, target in ipairs(row.targets) do
			w.line(("| %s | %s | × %s | × %s | %s | %s |"):format(className(row.classId), num(row.dealer / healer.units[row.classId], 1), num(target.target, 2), num(target.factor, 4), num(target.attackMultiplier, 3), num(target.checkRatio, 4)))
			w.row("e6_dealing", { row.classId, row.dealer, target.target, target.factor, target.attackMultiplier, target.checkRatio })
		end
	end
	w.line("")
end

local function writeSamples(w, samples)
	w.line("## 표본 대조(S21a · S21-0)")
	w.line("")
	w.line("| 표본 | 기대 | 시뮬 | O/X |")
	w.line("|---|---|---|---|")
	w.row("samples", { "id", "expected", "value", "ok" })
	for _, sample in ipairs(samples) do
		w.line(("| %s | %s | %s | %s |"):format(sample.id, num(sample.expected, 4), num(sample.value, 4), sample.ok and "O" or "**X**"))
		w.row("samples", { sample.id, sample.expected, sample.value, sample.ok and "O" or "X" })
	end
	w.line("")
end

local function writeProfiles(w, profileIds)
	w.line("## 프로필([가정] - `shared/data/EconSimConfig.lua`)")
	w.line("")
	w.line("| 프로필 | 하루(시간) | 직업 · 구역(최대 tier) | 목표 처치(초) · 최소 생존(타) | 조작 효율 · 이동(초/마리) | 보스: 효율 · 한계(초) · 시도/클리어 · 파티 | 강화 목표 · 방지권 | 가방 점검(분) · 보석 변환 |")
	w.line("|---|---|---|---|---|---|---|---|")
	for _, id in ipairs(profileIds) do
		local p = EconSimConfig.profiles[id]
		w.line(("| %s | %s | %s · ≤ tier%d | %s · %d | %s · %s | %s · %d · %s · %d인 | +%d · %s | %s · %s |"):format(p.displayName, num(p.hoursPerDay, 1), className(p.classId), p.huntTierMax,
			num(p.targetKillSeconds, 1), p.minSurviveHits, pct(p.dpsEfficiency), num(p.moveOverheadSeconds, 1), pct(p.bossDpsEfficiency), p.bossKillLimitSeconds, num(p.bossAttemptsPerClear, 1),
			p.partySize, p.enhanceTarget, p.useProtection and "씀" or "안 씀", num(p.gearCheckMinutes, 0), p.gemReroll and ("씀(roll " .. num(p.gemRoll, 2) .. ")") or "안 씀"))
	end
	w.line("")
end

-- opts = { profileArg = "all" | 프로필 id, whatIfName = 이름(기본 baseline) }. 반환: 요약 문자열, 결과 표(검증 블록이 읽는다).
function EconSimReport.run(opts)
	assert(EconSim.isAllowed(), "EconSim은 Studio + DevToolsConfig.econSim 전용이다")
	opts = opts or {}
	local whatIfName = opts.whatIfName or "baseline"
	local whatIf = EconSimConfig.whatIfs[whatIfName]
	if not whatIf then
		local names = {}
		for name in pairs(EconSimConfig.whatIfs) do
			table.insert(names, name)
		end
		table.sort(names)
		error(("알 수 없는 what-if '%s' - 가능: %s"):format(whatIfName, table.concat(names, ", ")), 0)
	end
	local profileArg = opts.profileArg or "all"
	local profileIds = {}
	if profileArg == "all" then
		profileIds = table.clone(EconSimConfig.profileOrder)
	elseif EconSimConfig.profiles[profileArg] then
		profileIds = { profileArg }
	else
		error(("알 수 없는 프로필 '%s' - all · %s"):format(profileArg, table.concat(EconSimConfig.profileOrder, " · ")), 0)
	end

	local started = os.clock()
	EconSim.clearCaches()
	local runs = {}
	for _, id in ipairs(profileIds) do
		runs[id] = EconSim.runProgress(id, whatIf)
		task.wait()
	end
	local enhanceTable = EconSim.withOverrides(whatIf, EconSim.enhanceExpectedTable, EconSimConfig.enhanceMonteCarloTrials, EconSimConfig.seed)
	task.wait()
	local primordial = EconSim.withOverrides(whatIf, EconSimTables.primordial, whatIf)
	task.wait()
	local healer = EconSim.withOverrides(whatIf, EconSimTables.healer, whatIf)
	task.wait()
	local samples = EconSimTables.samples(EconSim.withOverrides({}, EconSimTables.healer, nil))
	local elapsed = os.clock() - started

	local runId = ("%s-%s"):format(whatIfName, profileArg)
	local w = newWriter(runId)
	w.line(("# E1 경제 시뮬 - what-if `%s` · 프로필 `%s`"):format(whatIfName, profileArg))
	w.line("")
	w.line(("`/gg econ %s %s`로 Studio에서 생성(계산 %.1f초, 시드 %d). 게임 공식은 실제 모듈을 불러 계산했고, 플레이어 모형만 [가정]이다. SafeStageCap = %d."):format(
		profileArg, whatIfName, elapsed, EconSimConfig.seed, InfiniteStageConfig.safeStageCap))
	local overrides = {}
	for key, value in pairs(whatIf) do
		table.insert(overrides, ("%s = %s"):format(key, type(value) == "table" and "표" or tostring(value)))
	end
	table.sort(overrides)
	w.line(("what-if 덮어쓰기: %s"):format(#overrides > 0 and table.concat(overrides, " · ") or "없음(기준선)"))
	w.line("")
	writeProfiles(w, profileIds)
	writeE3(w, runs, profileIds)
	writeE4(w, runs, profileIds, enhanceTable)
	writeE5(w, primordial, whatIf)
	writeE6(w, healer)
	writeSamples(w, samples)
	w.flush(("run=%s whatif=%s profiles=%s"):format(runId, whatIfName, profileArg))

	-- 채팅 요약
	local parts = {}
	for _, id in ipairs(profileIds) do
		local run = runs[id]
		table.insert(parts, ("%s 최고 %d(%s시간)%s"):format(EconSimConfig.profiles[id].displayName, run.final.reach, num(run.final.seconds / 3600, 0), run.stall and " 정지" or ""))
	end
	local okSamples = 0
	for _, sample in ipairs(samples) do
		if sample.ok then
			okSamples += 1
		end
	end
	local summary = ("econ %s: %s · 치유사 4인 보스전 비중 %s → %s → %s · 표본 %d/%d O · %.1f초 - 전체 표는 출력 창 [ECONMD](docs/econ/_extract.py)"):format(
		runId, table.concat(parts, " · "), pct(healer.tiers.none.share), pct(healer.tiers.average.share), pct(healer.tiers.top.share), okSamples, #samples, elapsed)
	return summary, { runs = runs, enhance = enhanceTable, primordial = primordial, healer = healer, samples = samples }
end

return EconSimReport
