KG_N = 20000
-- QUEUE-ALL9E1 0-3 방지 배수 k 격자: 구간마다 "방지 항상 켬" 기대 골드 ÷ "방지 없이(복구 포함)" 기대 골드 - 실제 Enhance 모듈(확률 · 불씨 · 비용 · 도착점)
local E, C = MODS.Enhance, MODS.EnhanceConfig
local STAGE = 1950
local N = tonumber(KG_N) or 20000
local seed = 12345
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function run(from, to, guard)
	local level, gauge, gold, resets = from, 0, 0, 0
	local n = 0
	while level < to and n < 100000 do
		n += 1
		local full = gauge >= C.gauge.max
		local useDrop, useReset = E.resolveProtectionFlags(level, full, guard, guard)
		gold += E.getCost(level, STAGE, useDrop, useReset)
		local r = E.tryEnhance(level, gauge, { useDrop, useReset }, rnd())
		if r.result == "reset" then resets += 1 end
		level, gauge = r.level, r.gauge
	end
	return gold, resets
end
local bands = { { 19, 22, 1 }, { 22, 26, 2 }, { 26, 30, 3 } }
for _, mode in ipairs({ false, true }) do
	ATTR.ResetMinus4 = mode
	-- 방지 없이(구간별 · 22 → 30 전체 · 초기화 경험 비율)
	local base = {}
	for _, b in ipairs(bands) do
		local s = 0
		for _ = 1, N do s += (run(b[1], b[2], false)) end
		base[b[3]] = s / N
	end
	local exp, s2230 = 0, 0
	for _ = 1, N do
		local g, r = run(22, 30, false)
		s2230 += g
		if r > 0 then exp += 1 end
	end
	print(("BASE|minus4=%s|19-22=%.4g|22-26=%.4g|26-30=%.4g|22-30=%.4g|resetExp=%.4f"):format(tostring(mode), base[1], base[2], base[3], s2230 / N, exp / N))
	for _, b in ipairs(bands) do
		local row = {}
		for k10 = 15, 30 do
			C.guardBands[b[3]].costMultiplier = k10 / 10
			local s = 0
			for _ = 1, N do s += (run(b[1], b[2], true)) end
			table.insert(row, ("%.1f:%.3f"):format(k10 / 10, s / N / base[b[3]]))
		end
		C.guardBands[b[3]].costMultiplier = ({ 1.7, 3.0, 2.1 })[b[3]]
		print(("GRID|minus4=%s|band=%d-%d|%s"):format(tostring(mode), b[1], b[2], table.concat(row, " ")))
	end
end
