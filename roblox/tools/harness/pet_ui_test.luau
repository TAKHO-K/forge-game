-- UI-1 7c 알 · 펫 하네스(순수): 알 등급마다 · 부화 레벨마다 결과 확률 합 = 100 · 네 등급 모두 있음 · 놓아주기 판정(데리고 다님 · 잠금 = 거절) · 놓은 뒤 데리고 다니는 번호 맞춤.
-- 실행: LUAU=<luau.exe> ECON_RES=res_petui.txt python build_run.py pet_ui_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[PETUI] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local Pet, EggData, PetData = MODS.Pet, MODS.EggData, MODS.PetData
	local bad = {}
	for _, egg in ipairs(EggData.gradeOrder) do
		for lv = 1, #PetData.levels do
			local t = Pet.hatchTable(egg, lv)
			local sum = 0
			for _, g in ipairs(EggData.hatchGrades) do
				sum += t[g] or 0
				if t[g] == nil or t[g] < 0 then
					table.insert(bad, ("%s Lv%d %s 없음/음수"):format(egg, lv, g))
				end
			end
			if math.abs(sum - 100) > 1e-6 then
				table.insert(bad, ("%s Lv%d 합 %.4f"):format(egg, lv, sum))
			end
		end
	end
	check("알마다 · 부화 레벨마다 합 100 · 네 등급(" .. #EggData.gradeOrder .. " × " .. #PetData.levels .. ")", #bad == 0, table.concat(bad, " "))
	check("표시 등급 4(일반 · 희귀 · 영웅 · 전설)", #EggData.hatchGrades == 4)
	local st = { list = { { species = "a", at = 1 }, { species = "b", at = 2, locked = true }, { species = "c", at = 3 } }, equipped = 1 }
	check("데리고 다니는 펫 = 거절", select(2, Pet.canRelease(st, 1)) == "equipped")
	check("잠근 펫 = 거절", select(2, Pet.canRelease(st, 2)) == "locked")
	check("없는 번호 = 거절", select(2, Pet.canRelease(st, 9)) == "none")
	check("보통 펫 = 허락", Pet.canRelease(st, 3) == true)
	local st2 = { list = { { species = "a" }, { species = "b" }, { species = "c" } }, equipped = 3 }
	Pet.removeAt(st2, 1)
	check("앞 번호를 놓으면 데리고 다니는 번호 한 칸 앞으로", st2.equipped == 2 and st2.list[2].species == "c", tostring(st2.equipped))
end)
if not okRun then
	print("[PETUI] 하네스 에러 " .. tostring(err))
end
print(("[PETUI] 끝 %d/%d"):format(pass, total))
