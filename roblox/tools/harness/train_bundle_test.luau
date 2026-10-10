-- UI-1b 1-b 17: 수련 · 직업 능력 묶음 구매 = 경제 영향 0(묶음 비용 합 = 단계 비용 합 · 끝 단계 = 상한 · 묶음 = 목표 % 이상 또는 마지막 자투리) · EconSim은 단계 가격 그대로
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[TBUN] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local T, D = MODS.Training, MODS.TrainingData
	local function run(def, kind, best)
		local cap = T.capFor(def, best)
		local level, bundles, sumB, sumL, bad = 0, 0, 0, 0, 0
		for i = 0, cap - 1 do
			sumL += T.costFor(def, i, best)
		end
		while true do
			local k = T.bundleLevels(def, level, cap, D.bundle[kind])
			if k == 0 then
				break
			end
			if k * def.perLevel < D.bundle[kind] - 1e-9 and level + k < cap then
				bad += 1 -- 목표 % 미만인데 마지막이 아님
			end
			sumB += T.bundleCost(def, level, k, best)
			level += k
			bundles += 1
		end
		return level == cap, math.abs(sumB - sumL) <= 1e-6 * math.max(1, sumL), bad, bundles, cap
	end
	local okAll, sameAll, badAll, info = true, true, 0, {}
	for _, best in ipairs({ 37, 400, 1000, 20000 }) do
		for _, def in ipairs(D.stats) do
			local a, b, c, n, cap = run(def, "stat", best)
			okAll, sameAll, badAll = okAll and a, sameAll and b, badAll + c
			if best == 20000 then table.insert(info, ("%s %d단계 = %d번"):format(def.id, cap, n)) end
		end
		for _, list in pairs(D.classAbilities) do
			for _, def in ipairs(list) do
				local a, b, c = run(def, "ability", best)
				okAll, sameAll, badAll = okAll and a, sameAll and b, badAll + c
			end
		end
	end
	check("묶음으로 끝까지 = 상한 단계(최대치 동일)", okAll)
	check("묶음 비용 합 = 단계 비용 합(경제 영향 0)", sameAll)
	check("묶음 = 목표 %(수련 1% · 능력 5%) 이상 · 아니면 마지막 자투리", badAll == 0, tostring(badAll))
	check("공격 수련 50단계 = 5번(+1%씩)", (function()
		local cap = T.capFor(D.stats[1], 20000)
		return cap == 50 and T.bundleLevels(D.stats[1], 0, cap, D.bundle.stat) == 10
	end)(), table.concat(info, " · "))
	check("상한 = 묶음 0", T.bundleLevels(D.stats[1], 50, 50, D.bundle.stat) == 0)
end)
if not okRun then
	print("[TBUN] 하네스 에러 " .. tostring(err))
end
print(("[TBUN] 끝 %d/%d"):format(pass, total))
