-- 경제 시뮬 보고서(P0 E3 ~ E8). EconSim(진행) · EconSimTables(표)를 한 번 돌려 결과를 Studio 출력 창에 찍는다:
--   [ECON] BEGIN/END 줄 사이에 [ECONMD] 마크다운 줄 · [ECONCSV:<표>] CSV 줄. docs/econ/_extract.py가 로그 파일에서 가장 최근 실행을 골라
--   docs/econ/E1-<what-if>.md + E1-<what-if>-<표>.csv로 옮긴다(Studio 서버는 저장소 파일을 직접 못 쓴다).
-- 채팅(DevTools reply)에는 run()이 돌려주는 요약 한 줄만 간다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconSimConfig = require(ReplicatedStorage.Shared.data.EconSimConfig)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local Enhance = require(ReplicatedStorage.Shared.Enhance)
local GoldCost = require(ReplicatedStorage.Shared.GoldCost)
local DropTable = require(ReplicatedStorage.Shared.DropTable)
local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
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
	w.line("구간 = 그 청크(레벨업 1회) 동안의 최고 스테이지. 골드 · EXP/분 = 구간 전체(사냥 + 보스) 합 ÷ 시간. 강화 비용 = 구간 끝 강화 단계 · 구간 끝 최고 스테이지 기준(다음 1회 = `Enhance.getCost` - P2부터 GoldCost, 다음 단계 기대 = 몬테카를로 표 × 같은 GoldCost 배수). 구매력 = 골드/분 ÷ 다음 1회 비용. 보석 = 구간 끝(칸 수 · 평균 itemLevel · 위력 합).")
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
				local cost = Enhance.getCost(last.weaponLevel, last.reach) -- P2 C1: 구간 끝 최고 스테이지 기준(GoldCost)
				local expected = enhanceTable[last.weaponLevel]
				local scale = GoldCost.scale(last.reach, "enhance") -- 몬테카를로 표는 기본 비용 기준 - 같은 배수를 곱한다
				local power = cost and goldPerMin / cost or nil
				local interval = replaced > 0 and minutes / replaced or nil
				w.line(("| %s | %s | %s | %s | %s | %s | %s | %s | %d칸 · %s · %s | %d ~ %d | %d ~ %d |"):format(
					segment.label, profile.displayName, num(goldPerMin, 0), num(expPerMin, 0),
					cost and ("+%d→+%d %s"):format(last.weaponLevel, last.weaponLevel + 1, num(cost, 0)) or ("+%d 최대 [없음]"):format(last.weaponLevel),
					expected and num(expected.gold * scale, 0) or "[없음]", power and num(power, 1) or "[없음]", interval and num(interval, 1) or "교체 없음",
					last.gemCount, num(last.gemAvgLevel, 0), pct(last.gemAttackBonus), first.level, last.level, first.stage, last.stage))
				w.row("e4", { segment.label, id, goldPerMin, expPerMin, cost or "", expected and expected.gold * scale or "", power or "", interval or "", last.gemCount, last.gemAvgLevel, last.gemAttackBonus, last.weaponLevel, minutes })
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
local function writeE5(w, rows)
	local cfg = EconSimConfig.primordial
	w.line("## E5 태초 선택지 손익분기(게임 드랍표 그대로 - DropTable.effectiveRate · 레벨 감쇠 포함)")
	w.line("")
	w.line(("비교: (A) 드래곤(tier%d)을 자기 스테이지 − Δ에서 vs (B) tier t를 자기 스테이지 sB에서(sB = '일반' 프로필 기준 tier1이 목표 처치 초 안에 잡히는 가장 높은 스테이지 = 최고 스테이지로 본다, 앵커 장비). 값 = A의 태초 기대 가치/분 ÷ B의 것(태초 위력 옵션 값 × 태초 개수/분, 보석 레벨 = 잡은 스테이지). 1 초과 = A 우세(지배 전략). M* = 드래곤 ÷ tier t 확률 배수가 이 값 이하면 A가 우세하지 않다(A÷B는 배수에 비례). 감쇠 = 사냥 스테이지가 최고보다 %d 이상 낮으면 (격차 − %d + 1) × %s씩 깎는다."):format(
		cfg.highTier, DropTableData.primordial.levelDecay.startGap, DropTableData.primordial.levelDecay.startGap - 1, pct(DropTableData.primordial.levelDecay.perLevel)))
	w.line("")
	w.row("e5", { "label", "player_level", "low_tier", "delta", "stage_a", "stage_b", "rate_a", "rate_b", "decay_a", "value_a", "value_b", "kill_a", "kill_b", "ratio", "break_even", "multiplier", "gold_ratio", "exp_ratio" })
	for _, row in ipairs(rows) do
		w.row("e5", { row.label, row.playerLevel, row.lowTier, row.delta, row.stageA, row.stageB, row.rateA, row.rateB, row.decayA, row.valueA, row.valueB, row.killA, row.killB, row.ratio, row.breakEven, row.multiplier, row.goldRatio, row.expRatio })
	end
	-- tier별 요약: 지금 배수 · Δ ≤ dominanceMaxDelta의 최소 M* · 지배 전략 여부
	w.line("| tier | 몬스터 | 드래곤 대비 배수(지금) | 기본 확률(장비 1개당) | M* 최소(Δ ≤ " .. cfg.dominanceMaxDelta .. ", 레벨 " .. table.concat(cfg.playerLevels, " · ") .. ") | Δ ≤ " .. cfg.dominanceMaxDelta .. " 지배 전략 |")
	w.line("|---|---|---|---|---|---|")
	for _, tier in ipairs(cfg.lowTiers) do
		local minM, dominated = math.huge, {}
		local multiplier = nil
		for _, row in ipairs(rows) do
			if row.label == "grid" and row.lowTier == tier and row.delta <= cfg.dominanceMaxDelta then
				minM = math.min(minM, row.breakEven)
				multiplier = row.multiplier
				if row.ratio > 1 then
					table.insert(dominated, ("L%d Δ%d"):format(row.playerLevel, row.delta))
				end
			end
		end
		w.line(("| %d | %s | %s | %s | %s | %s |"):format(tier, EconSim.tierData(tier).displayName, multiplier == math.huge and "태초 없음" or ("×" .. num(multiplier, 2)),
			("%.4f%%"):format(DropTable.primordialBaseRate(tier) * 100), num(minM, 2), #dominated > 0 and ("**있음** (" .. table.concat(dominated, ", ") .. ")") or "없음"))
	end
	w.line("")
	w.line("| 플레이어 레벨 | tier | sB | A÷B: Δ1 · Δ2 · Δ3 · Δ4 · Δ5 | Δ10 · Δ30 | M*: Δ1 ~ Δ5 | 감쇠 A(Δ5 · Δ10) | 골드/분 A÷B(Δ5) |")
	w.line("|---|---|---|---|---|---|---|---|")
	for _, playerLevel in ipairs(cfg.playerLevels) do
		for _, tier in ipairs(cfg.lowTiers) do
			local byDelta, stageB = {}, nil
			for _, row in ipairs(rows) do
				if row.label == "grid" and row.playerLevel == playerLevel and row.lowTier == tier then
					byDelta[row.delta] = row
					stageB = row.stageB
				end
			end
			local function ratioAt(delta)
				local row = byDelta[delta]
				if not row then
					return "-"
				end
				return row.ratio > 1 and ("**%s**"):format(num(row.ratio, 2)) or num(row.ratio, 2)
			end
			local function mAt(delta)
				return byDelta[delta] and num(byDelta[delta].breakEven, 2) or "-"
			end
			w.line(("| %d | %d | %d | %s · %s · %s · %s · %s | %s · %s | %s · %s · %s · %s · %s | %s · %s | %s |"):format(playerLevel, tier, stageB or 0,
				ratioAt(1), ratioAt(2), ratioAt(3), ratioAt(4), ratioAt(5), ratioAt(10), ratioAt(30), mAt(1), mAt(2), mAt(3), mAt(4), mAt(5),
				byDelta[5] and num(byDelta[5].decayA, 2) or "-", byDelta[10] and num(byDelta[10].decayA, 2) or "-", byDelta[5] and ("%.3g"):format(byDelta[5].goldRatio) or "-"))
		end
	end
	for _, row in ipairs(rows) do
		if row.label == "example" then
			w.line("")
			w.line(("예시(사용자 설계): 레벨 10 플레이어 - 스테이지 %d 드래곤 vs 스테이지 %d 슬라임: A÷B %s · M* %s · 감쇠 A %s · 골드/분 A÷B %.3g."):format(row.stageA, row.stageB, num(row.ratio, 2), num(row.breakEven, 2), num(row.decayA, 2), row.goldRatio))
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
	w.line("## E6 치유사(P2 F)")
	w.line("")
	w.line(("앵커: 레벨 100 · 무기 등급 0 · +0강(S21-0 D2와 같은 조건). 60초 로테이션 총딜, 치명 옵션은 평타에만(AttackServer와 같다). **치유모드 딜 = 딜링모드를 끈 평타(배율 1) · 딜 옵션 100%%**(게임 AttackServer가 모드와 무관하게 옵션을 넣는다 - F1) × 보스전 전투 비율 %s([가정]). 비중 = 치유사 ÷ (딜러 3 + 치유사). 지금 값: `ClassData.healer.atk` %s · `SkillData.healer.E.attackMultiplier` %s · 힐러 버프 b %s. 보상 문턱 = %s(CombatConfig)."):format(
		num(healer.healModeFightRatio, 2), num(ClassData.classes.healer.atk, 3), num(SkillData.healer.E.attackMultiplier, 3), pct(healer.healerBuff), pct(healer.contributionThreshold)))
	w.line("")
	w.line("| 장비 단계 | 검사 · 도적 · 궁수 60초 딜 | 치유모드 딜 | 비중: 도적 3 · 검사 3 · 궁수 3 · 혼합(각 1) | 딜링모드 ÷ 검사 |")
	w.line("|---|---|---|---|---|")
	w.row("e6_tiers", { "tier", "gs_dps", "dual_dps", "bow_dps", "heal_mode", "dealing_mode", "share_dual3", "share_gs3", "share_bow3", "share_mixed", "r_dealing" })
	for _, tier in ipairs(cfg.gearTiers) do
		local row = healer.tiers[tier.id]
		local function mark(value)
			return value < cfg.shareTarget and ("**%s**"):format(pct(value)) or pct(value)
		end
		w.line(("| %s | %s · %s · %s | %s | %s · %s · %s · %s | %s |"):format(tier.displayName, num(row.dps.greatsword, 0), num(row.dps.dualblade, 0), num(row.dps.bow, 0), num(row.healMode, 0),
			mark(row.share.dualblade), mark(row.share.greatsword), mark(row.share.bow), mark(row.share.mixed), num(row.rDealing, 4)))
		w.row("e6_tiers", { tier.id, row.dps.greatsword, row.dps.dualblade, row.dps.bow, row.healMode, row.dealingMode, row.share.dualblade, row.share.greatsword, row.share.bow, row.share.mixed, row.rDealing })
	end
	w.line("")
	w.line(("굵은 글씨 = 목표 %s 미만. F2 풀이: \"도적 3 + 치유사 1\"이 세 장비 단계 모두 ≥ %s가 되는 최소 `ClassData.healer.atk` = **%s**(지금 %s). F3 풀이: 그 atk에서 딜링모드 = 검사 × %s(장비 없음)가 되는 `attackMultiplier` = **%s**(지금 %s)."):format(
		pct(cfg.shareTarget), pct(cfg.shareTarget), num(healer.solvedAtk, 4), num(ClassData.classes.healer.atk, 3), num(cfg.dealingTarget, 3), num(healer.solvedDealingMultiplier, 4), num(SkillData.healer.E.attackMultiplier, 3)))
	w.line("")
	w.line(("참고(딜링모드로 싸우는 치유사 - S13b 모형): 보스전 전투 비율 쉴드 %s · 치유 %s · 필드 가동률 %s."):format(num(healer.fightRatio.shield, 4), num(healer.fightRatio.heal, 4), num(healer.fieldUptime, 4)))
	w.line("")
	w.line("### F4 파티 구성 속도(보스 처치 속도 ÷ 딜러 4명 - 보스 HP는 4인 배율로 같다)")
	w.line("")
	w.line("| 장비 | 딜러 | 치유사 모드 | 딜러4 · 딜러3+치유사1 · 딜러2+치유사2 · 딜러1+치유사3 · 치유사4 | 목표 순서(딜러4 ≈ 3+1 > 2+2 > 1+3 · 4) |")
	w.line("|---|---|---|---|---|")
	w.row("e6_comp", { "tier", "dealer", "mode", "d4", "d3h1", "d2h2", "d1h3", "h4" })
	for _, entry in ipairs(healer.compositions) do
		for _, mode in ipairs({ "healMode", "dealingMode", "rebuiltBuff" }) do
			local v = {}
			for index, speed in ipairs(entry.speeds) do
				v[index] = speed[mode]
			end
			-- ≈ = 딜러4의 90% 이상(판정 기준 - 로그에 적었다)
			local ok = v[2] >= 0.9 * v[1] and v[2] > v[3] and v[3] > math.max(v[4], v[5])
			local modeName = mode == "healMode" and "치유모드" or (mode == "dealingMode" and "딜링모드" or ("치유모드 · 참고: b 재산정 %s"):format(pct(entry.rebuiltBuff)))
			w.line(("| %s | %s | %s | %s · %s · %s · %s · %s | %s |"):format(entry.tier, className(entry.dealerClass), modeName,
				num(v[1], 3), num(v[2], 3), num(v[3], 3), num(v[4], 3), num(v[5], 3), ok and "O" or "**X**"))
			w.row("e6_comp", { entry.tier, entry.dealerClass, mode, v[1], v[2], v[3], v[4], v[5] })
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
	local primordial = EconSim.withOverrides(whatIf, EconSimTables.primordial)
	task.wait()
	local healer = EconSim.withOverrides(whatIf, EconSimTables.healer)
	task.wait()
	-- 표본(S21a · S21-0)은 P2 전 게임 값에서 잰 것이라 p2before 덮어쓰기 안에서 대조한다(도구가 옛 값을 그대로 재현하는가).
	local samples = EconSim.withOverrides(EconSimConfig.whatIfs.p2before, function()
		return EconSimTables.samples(EconSimTables.healer())
	end)
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
	EconSim.withOverrides(whatIf, writeE4, w, runs, profileIds, enhanceTable) -- 강화 1회 비용(Enhance.getCost)도 what-if(enhanceCostScale)를 따른다(리뷰 지적 3)
	writeE5(w, primordial)
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
	local summary = ("econ %s: %s · 치유사(도적 3 + 1) 비중 %s → %s → %s · 표본 %d/%d O · %.1f초 - 전체 표는 출력 창 [ECONMD](docs/econ/_extract.py)"):format(
		runId, table.concat(parts, " · "), pct(healer.tiers.none.share.dualblade), pct(healer.tiers.average.share.dualblade), pct(healer.tiers.top.share.dualblade), okSamples, #samples, elapsed)
	return summary, { runs = runs, enhance = enhanceTable, primordial = primordial, healer = healer, samples = samples }
end

return EconSimReport
