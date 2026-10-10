-- UI-1 0단계 레이아웃 하네스(순수): 02_hud/v6 배치표(UiLayoutData.hud.v6) + HudPlace 계산 → 해상도 5종 × 평상시 · 보스전 × 요소 전부.
--   판정: 화면 밖 0 · 상단 바 58(화면 px - 우리 배율과 무관) 침범 0 · 폰 누르는 것 44 미만 0 · 오른쪽 열 접기 단계(02 v6 §9 표) · 폰 전투 버튼 간격 8 · 화면 끝 8 · 엄지 영역.
--   겹침 = 목록 출력(실패 아님 - 보고서용). Studio 뷰포트 높이 한계(592) 대신 실제 해상도 판정은 이 하네스로.
-- 실행: LUAU=<luau.exe> ECON_RES=res_hudlayout.txt python build_run.py hud_layout_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[HUDL] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local P = MODS.HudPlace
	local V6 = MODS.UiLayoutData.hud.v6
	local combat = MODS.UiLayoutData.hud.phone.combat
	local TOPBAR = 58
	local VIEWS = {
		{ name = "PC 1920×1080", w = 1920, h = 1080, phone = false, text = 1 },
		{ name = "PC 1366×768", w = 1366, h = 768, phone = false, text = 1 },
		{ name = "PC 1280×720", w = 1280, h = 720, phone = false, text = 1 },
		{ name = "PC 1280×720 글자 1.3", w = 1280, h = 720, phone = false, text = 1.3 },
		{ name = "폰 800×360", w = 800, h = 360, phone = true, text = 1 },
		{ name = "폰 800×360 글자 1.3", w = 800, h = 360, phone = true, text = 1.3 },
		{ name = "폰 844×390", w = 844, h = 390, phone = true, text = 1 },
	}
	check("폰 판정: 짧은 변 ≤ 500 = 폰(터치 + 키보드여도) · 터치만 = 폰 · PC 큰 화면 = PC",
		P.isPhone(800, 360, true, true) and P.isPhone(1920, 1080, true, false) and not P.isPhone(1920, 1080, true, true) and not P.isPhone(1366, 768, false, true) and P.isPhone(800, 450, false, true))
	check("배율 m 하나: 1920 = 1 · 1366×768 = 0.75(하한) · 2560×1440 = 1.25(상한) · 폰 800×360 = 1",
		P.scale(1920, 1080, false) == 1 and P.scale(1366, 768, false) == 0.75 and P.scale(2560, 1440, false) == 1.25 and P.scale(800, 360, true) == 1)

	local overlaps, offs, tops, touches = {}, 0, 0, 0
	for _, v in ipairs(VIEWS) do
		local m = P.scale(v.w, v.h, v.phone)
		local tbl = v.phone and V6.phone or V6.pc
		for _, mode in ipairs({ "normal", "boss" }) do
			local rects = {}
			for name, r in pairs(tbl) do
				if r.x and r.size and not r[1] then -- 폰 메뉴 줄(menuTop = x · y · 칸 크기 · 간격 - UI-1 2단계) → 3칸(가방 · 보상 · 더보기) 줄 사각형
					r = { r.x, r.y, 3 * r.size + 2 * r.gap, r.size }
				end
				if r[4] and (r.reserve or (r.modes and r.modes[mode]) or (not r.modes and not r.reserve)) then
					local rr = { r[1], r[2], r[3], r[4] + (r.text or 0) * (v.text - 1) }
					if name == "rightColumn" then -- 접기 결과 크기
						local f = P.rightFold(V6.rightFold, 5, v.h, m, v.text)
						local cols = f.inner > 0 and 2 or 1
						rr = { r[1] - (cols - 1) * (V6.rightFold.size + V6.rightFold.innerGap), r[2], V6.rightFold.size * cols + (cols - 1) * V6.rightFold.innerGap, f.need - V6.rightFold.y }
					end
					local s = P.screenRect(rr, r.anchor, v.w, v.h, m, v.phone)
					table.insert(rects, { name = name, s = s, reserve = r.reserve, touch = r.touch })
					if not r.reserve then
						if s[1] < -0.5 or s[2] < -0.5 or s[1] + s[3] > v.w + 0.5 or s[2] + s[4] > v.h + 0.5 then
							offs += 1
							print(("[HUDL]   화면 밖 %s %s %s (%.0f, %.0f, %.0f, %.0f)"):format(v.name, mode, name, s[1], s[2], s[3], s[4]))
						end
						if name ~= "exp" and s[2] < TOPBAR - 0.5 then
							tops += 1
							print(("[HUDL]   상단 바 침범 %s %s %s y %.1f"):format(v.name, mode, name, s[2]))
						end
					end
				end
			end
			if v.phone then
				for id, c in pairs(combat) do
					local s = P.screenRect(c, V6.phoneCombatAnchor, v.w, v.h, m, true)
					table.insert(rects, { name = "combat." .. id, s = s, touch = true, combat = true })
					if math.min(s[3], s[4]) < 44 - 0.01 then
						touches += 1
						print(("[HUDL]   터치 44 미만 %s %s %.1f"):format(v.name, id, math.min(s[3], s[4])))
					end
				end
				local menu = P.screenRect(tbl.menuRow, tbl.menuRow.anchor, v.w, v.h, m, true)
				if menu[4] < 44 - 0.01 then
					touches += 1
					print(("[HUDL]   터치 44 미만 %s 메뉴 줄 %.1f"):format(v.name, menu[4]))
				end
			end
			table.sort(rects, function(a, b) return a.name < b.name end)
			for i = 1, #rects do
				for j = i + 1, #rects do
					local a, b = rects[i], rects[j]
					if not (a.reserve and b.reserve) and not (a.combat and b.combat) then
						local w, h = P.overlap(a.s, b.s)
						if w > 0.5 and h > 0.5 then
							table.insert(overlaps, ("%s · %s · %s ↔ %s (%.0f × %.0f px)"):format(v.name, mode, a.name, b.name, w, h))
						end
					end
				end
			end
		end
	end
	check("화면 밖 0(해상도 7 × 평상시 · 보스전)", offs == 0, tostring(offs))
	check("상단 바 58 침범 0", tops == 0, tostring(tops))
	check("폰 누르는 것 44 미만 0", touches == 0, tostring(touches))
	print(("[HUDL] 겹침 %d건(목록 - 실패 아님)"):format(#overlaps))
	for _, line in ipairs(overlaps) do
		print("[HUDL]   겹침 " .. line)
	end

	-- 오른쪽 열 접기 단계(02 v6 §9 표)
	local function stage(w, h, text)
		return P.rightFold(V6.rightFold, 5, h, P.scale(w, h, false), text).stage
	end
	check("접기: 1366×768 · 1280×720 = 1단계(글자 1.3도 1단계)", stage(1366, 768, 1) == 1 and stage(1280, 720, 1) == 1 and stage(1280, 720, 1.3) == 1 and stage(1366, 768, 1.3) == 1)
	check("접기: 1024×576 = 2단계(바깥 3 · 안쪽 2)", stage(1024, 576, 1) == 2 and P.rightFold(V6.rightFold, 5, 576, 0.75, 1).inner == 2)
	local f3 = P.rightFold(V6.rightFold, 5, 450, 0.75, 1)
	check("접기: PC 배치 800×450 = 3단계(바깥 2 · 안쪽 1 · 더보기로 2)", f3.stage == 3 and f3.outer == 2 and f3.inner == 1 and f3.toMore == 2)
	check("접기: 마지막 이름표 높이 포함(1080 = 336 + 5 × 97 + 4 × 14 = 877)", P.rightFold(V6.rightFold, 5, 1080, 1, 1).need == 877)

	-- 폰 전투 버튼: 원 사이 8 이상 · 화면 끝 8 이상 · 엄지(조이스틱) 영역 밖
	local minGap, minEdge, inThumb = math.huge, math.huge, {}
	local ids = {}
	for id in pairs(combat) do table.insert(ids, id) end
	table.sort(ids)
	for i, a in ipairs(ids) do
		local A = combat[a]
		local ca = { A[1] + A[3] / 2, A[2] + A[4] / 2, A[3] / 2 }
		minEdge = math.min(minEdge, 800 - (A[1] + A[3]), 360 - (A[2] + A[4]))
		local jw, jh = P.overlap(A, V6.phone.joystick)
		if jw > 0 and jh > 0 then table.insert(inThumb, a) end
		for j = i + 1, #ids do
			local B = combat[ids[j]]
			local cb = { B[1] + B[3] / 2, B[2] + B[4] / 2, B[3] / 2 }
			local d = math.sqrt((ca[1] - cb[1]) ^ 2 + (ca[2] - cb[2]) ^ 2) - ca[3] - cb[3]
			minGap = math.min(minGap, d)
		end
	end
	check("폰 전투 버튼 원 사이 ≥ 8", minGap >= 8 - 0.01, ("%.1f"):format(minGap))
	check("폰 전투 버튼 화면 끝 ≥ 8", minEdge >= 8, tostring(minEdge))
	check("폰 전투 버튼 엄지(조이스틱) 영역 밖", #inThumb == 0, table.concat(inThumb, ","))
	check("폰 고정 = 가운데 (638, 186) · 대시 = (570, 232)", combat.lockon[1] + 22 == 638 and combat.lockon[2] + 22 == 186 and combat.dash[1] + 26 == 570 and combat.dash[2] + 26 == 232)
	-- UI-1b 0절(VERIFY-5 상3): 실제 화면 판정 함수(Studio HudRealCheck와 같은 함수) - VERIFY-5 사례(칩 줄 y 6 ~ 152 × 다음 목표 y 96)를 잡는가
	local HR = MODS.HudRealRules
	local res = HR.check({ { id = "chips/Gold", x = 552, y = 6, w = 240, h = 146 }, { id = "nextGoal", x = 530, y = 96, w = 262, h = 44 }, { id = "exp", x = 0, y = 290, w = 800, h = 10 } }, { w = 800, h = 302 })
	check("실제 판정: 칩 줄 × 다음 목표 겹침 잡음 · 떨어진 칸 없음", #res.overlaps == 1 and res.overlaps[1][2] == "nextGoal", tostring(#res.overlaps))
	local edge = HR.check({ { id = "a", x = -2, y = 10, w = 50, h = 20 }, { id = "b", x = 100, y = -5, w = 20, h = 20 }, { id = "c", x = 780, y = 290, w = 30, h = 20 } }, { w = 800, h = 302 })
	check("실제 판정: 화면 밖 2 · 상단 바 1", #edge.offscreen == 2 and #edge.topbar == 1, ("%d · %d"):format(#edge.offscreen, #edge.topbar))
	check("실제 판정: allow 짝은 겹침에서 뺌", #HR.check({ { id = "x/1", x = 0, y = 0, w = 10, h = 10 }, { id = "y", x = 5, y = 5, w = 10, h = 10 } }, { w = 100, h = 100 }, { { "x", "y" } }).overlaps == 0)
	local units = MODS.UiLayoutData.realCheck.units
	check("실제 검사 대상 13칸(빈 목록이면 통과 못 함)", #units == 13, tostring(#units))
end)
if not okRun then
	print("[HUDL] 하네스 에러 " .. tostring(err))
end
print(("[HUDL] 끝 %d/%d"):format(pass, total))
