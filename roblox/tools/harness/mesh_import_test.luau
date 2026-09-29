-- B3 메시 가져오기 검사기 하네스: 표 기술자(가짜 가져온 모델)로 shared/MeshImportCheck.check의 항목별 O/X가 기대대로 나오는지 본다.
-- 정상 모델 = 규격 기준 자세(MeshImportCheck.expected)에서 만든 기술자 → 항목 하나씩 망가뜨려 그 항목만 X인지 확인.
-- 실행(이 폴더에서): LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_mesh.txt python build_run.py mesh_import_test.luau   # 결과 = %TEMP%/res_mesh.txt
-- (서버 모듈 의존 없음 - shared · shared/data만. Studio · Instance 쪽(describe · MeshSwap)은 Play에서 /gg mesh로 확인)

-- prelude의 Color3에는 Lerp가 없다(BossRigSpec.colorOf가 쓴다) - 이 테스트에서만 보강한다.
do
	local C3MT = {}
	C3MT.__index = {
		Lerp = function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end,
	}
	Color3.new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3MT)
	end
	Color3.fromRGB = function(r, g, b)
		return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end
end

local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then
		pass += 1
	end
	print(("[MESH] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local Check = MODS.MeshImportCheck
	local BossRigSpec = MODS.BossRigSpec

	local function copy3(v)
		return { v[1], v[2], v[3] }
	end

	-- 정상 기술자: 규격 기준 자세 그대로 · 색 = 리그 색 역할 · 삼각형 100씩
	local function good(rigId)
		local exp = Check.expected(rigId, 1)
		local look, rigProxy = Check.lookFor(rigId)
		local desc = { name = rigId, reference = true, parts = {} }
		for _, name in ipairs(exp.order) do
			local e = exp.parts[name]
			local c = BossRigSpec.colorOf(e.color, look, rigProxy or {})
			table.insert(desc.parts, {
				name = name, className = "MeshPart", joint = copy3(e.joint), center = copy3(e.center), min = copy3(e.min), max = copy3(e.max),
				color = { c.R * 255, c.G * 255, c.B * 255 }, material = e.material or "SmoothPlastic", transparency = 0, triCount = 100, textureId = "", forbidden = {},
			})
		end
		return desc, exp
	end
	local function part(desc, name)
		for _, p in ipairs(desc.parts) do
			if p.name == name then
				return p
			end
		end
		error("no part " .. name)
	end
	local function scaleBox(p, f, about)
		about = about or { 0, 0, 0 }
		for k = 1, 3 do
			p.min[k] = about[k] + (p.min[k] - about[k]) * f
			p.max[k] = about[k] + (p.max[k] - about[k]) * f
		end
	end

	-- 기대: X가 나와야 하는 항목 id 집합(나머지는 전부 O)
	local function expectX(label, desc, rigId, xs, extra)
		local okAll, lines, rows = Check.check(desc, rigId, { scale = 1 })
		local want = {}
		for _, id in ipairs(xs) do
			want[id] = true
		end
		local wrong = {}
		for _, r in ipairs(rows) do
			if (not r.ok) ~= (want[r.id] == true) then
				table.insert(wrong, ("%s=%s(%s)"):format(r.id, r.ok and "O" or "X", r.detail or ""))
			end
		end
		local good_ = #wrong == 0 and okAll == (#xs == 0)
		if extra then
			good_ = good_ and extra(lines)
		end
		check(label, good_, ("X 기대 {%s} · 어긋남 %s"):format(table.concat(xs, ","), #wrong > 0 and table.concat(wrong, " ") or "없음"))
		if not good_ then
			for _, l in ipairs(lines) do
				print("   " .. l)
			end
		end
		return lines
	end
	local function hasLine(pattern)
		return function(lines)
			for _, l in ipairs(lines) do
				if l:find(pattern, 1, true) then
					return true
				end
			end
			return false
		end
	end

	-- 1. 정상: 13종 잡몹 규격 그대로 = 전부 O(규격 자체와 검사기가 맞물린다)
	local speciesIds = {}
	for id in pairs(MODS.MonsterRigSpec.rigs) do
		table.insert(speciesIds, id)
	end
	table.sort(speciesIds)
	local allGood, badIds = true, {}
	for _, id in ipairs(speciesIds) do
		local okOne, lines = Check.check((good(id)), id, { scale = 1 })
		if not okOne then
			allGood = false
			table.insert(badIds, id)
			for _, l in ipairs(lines) do
				print("   " .. l)
			end
		end
	end
	check(("정상 잡몹 %d종 전부 O"):format(#speciesIds), allGood, #badIds > 0 and table.concat(badIds, ",") or "")

	-- 결과표 모양(항목 14줄 + 머리 + 결과 줄)
	local _, lines0, rows0 = Check.check((good("moss_slime")), "moss_slime")
	check("결과표 항목 14 · 첫 줄 머리 · 끝 줄 결과", #rows0 == 14 and lines0[1]:find("모델 moss_slime", 1, true) ~= nil and lines0[#lines0]:find("14/14 통과", 1, true) ~= nil, ("%d항목 · %d줄"):format(#rows0, #lines0))
	for _, l in ipairs(lines0) do
		print("   " .. l)
	end

	-- ① 이름
	local d = good("moss_slime")
	table.remove(d.parts, 4) -- Eye_R
	expectX("① 빠진 파트(Eye_R)", d, "moss_slime", { "①-1" })
	d = good("moss_slime")
	table.insert(d.parts, { name = "Hat", className = "MeshPart", joint = { 0, 0.4, 0 }, center = { 0, 0.4, 0 }, min = { -0.2, 0.3, -0.2 }, max = { 0.2, 0.5, 0.2 }, color = { 25, 18, 22 }, material = "SmoothPlastic", transparency = 0, triCount = 10 })
	expectX("① 남는 파트(Hat)", d, "moss_slime", { "①-2" })
	d = good("moss_slime")
	local dupe = table.clone(part(d, "Head"))
	table.insert(d.parts, dupe)
	expectX("① 중복 이름(Head ×2)", d, "moss_slime", { "①-2" })
	d = good("moss_slime")
	d.reference = false
	expectX("① 기준 루트 없음", d, "moss_slime", { "①-0" })
	d = good("moss_slime")
	table.insert(d.parts, { name = "HumanoidRootPart", className = "MeshPart", min = { -0.1, -0.1, -0.1 }, max = { 0.1, 0.1, 0.1 } })
	expectX("① 무시 이름(HumanoidRootPart)은 남는 파트 아님", d, "moss_slime", {})

	-- ② 관절
	d = good("moss_slime")
	part(d, "Head").joint[2] += 0.5
	expectX("② 관절 0.5 어긋남(Head)", d, "moss_slime", { "②" })
	d = good("moss_slime")
	part(d, "Head").joint[1] += 0.1
	expectX("② 허용 오차 안(0.1)", d, "moss_slime", {})
	d = good("rock_boar")
	local head = part(d, "Head")
	head.joint = copy3(head.center) -- 가져오기가 피벗을 경계 가운데로 옮긴 경우
	expectX("② 피벗 = 가운데 → 힌트 줄", d, "rock_boar", { "②" }, hasLine("피벗(Blender 원점)을 옮겼다"))
	d = good("moss_slime")
	part(d, "Body").joint = nil
	expectX("② 관절 모름", d, "moss_slime", { "②" })

	-- ③ 삼각형
	d = good("moss_slime")
	part(d, "Eye_L").triCount = nil
	expectX("③ 삼각형 모름(Eye_L)", d, "moss_slime", { "③-1", "③-2" })
	d = good("moss_slime")
	part(d, "Body").triCount = 1300 -- 1300 + 100 × 3 = 1600 > 1500
	expectX("③ 몬스터 예산 초과(1600 > 1500)", d, "moss_slime", { "③-2" })
	d = good("moss_slime")
	part(d, "Body").triCount = 1200 -- 1500 = 경계
	expectX("③ 예산 경계(1500)", d, "moss_slime", {})

	-- ④ 크기 · 판정
	d = good("moss_slime")
	for _, p in ipairs(d.parts) do
		scaleBox(p, 100)
		p.joint = { p.joint[1] * 100, p.joint[2] * 100, p.joint[3] * 100 }
	end
	expectX("④ 단위 ×100(cm) → 힌트", d, "moss_slime", { "②", "④-1", "④-2", "④-3" }, hasLine("cm → stud"))
	d = good("moss_slime")
	for _, p in ipairs(d.parts) do
		scaleBox(p, 0.75)
	end
	expectX("④ 전체 ×0.75", d, "moss_slime", { "④-1" })
	d = good("moss_slime")
	for _, p in ipairs(d.parts) do
		p.min[1] += 6
		p.max[1] += 6
	end
	expectX("④ 겉모습이 판정 상자 밖(x +6)", d, "moss_slime", { "④-2" })
	d = good("moss_slime")
	local eye = part(d, "Eye_L")
	scaleBox(eye, 3, eye.center)
	expectX("④ 파트 하나 ×3(Eye_L)", d, "moss_slime", { "④-3" })

	-- ⑤ 팔레트
	d = good("moss_slime")
	part(d, "Body").color = { 255, 0, 255 }
	expectX("⑤ 팔레트 밖 색(#FF00FF)", d, "moss_slime", { "⑤" })
	d = good("moss_slime")
	local b = part(d, "Body")
	b.color = { b.color[1] * 0.72, b.color[2] * 0.72, b.color[3] * 0.72 }
	expectX("⑤ 3톤 그늘(×0.72)은 허용", d, "moss_slime", {})
	d = good("moss_slime")
	part(d, "Body").color = { 0x7B, 0xC9, 0x50 } -- T1 바닥 #7BC950(구역 팔레트)
	expectX("⑤ 구역 팔레트 색(T1 #7BC950) 허용", d, "moss_slime", {})
	d = good("moss_slime")
	part(d, "Body").color = { 0x4B, 0x3A, 0x8C } -- T2 바닥 - 이끼 슬라임(T1) 구역 밖
	expectX("⑤ 다른 구역 팔레트 색(T2)은 X", d, "moss_slime", { "⑤" })

	-- ⑥ 재질 · 투명 · 텍스처 · 클래스
	d = good("moss_slime")
	part(d, "Head").transparency = 0.5
	expectX("⑥ 투명 0.5", d, "moss_slime", { "⑥-2" })
	d = good("moss_slime")
	part(d, "Body").material = "Neon"
	expectX("⑥ 규격 밖 Neon(Body)", d, "moss_slime", { "⑥-3" })
	d = good("crystal_beetle") -- Eyes = 규격 Neon
	expectX("⑥ 규격 Neon(딱정벌레 Eyes)은 허용", d, "crystal_beetle", {})
	d = good("moss_slime")
	part(d, "Body").className = "Part"
	expectX("⑥ MeshPart 아님(Part)", d, "moss_slime", { "⑥-1" })
	d = good("moss_slime")
	part(d, "Body").textureId = "rbxassetid://1"
	part(d, "Head").forbidden = { "SurfaceAppearance" }
	expectX("⑥ 텍스처 · SurfaceAppearance", d, "moss_slime", { "⑥-4" })

	-- 여러 항목 동시
	d = good("moss_slime")
	table.remove(d.parts, 3) -- Eye_L
	part(d, "Head").transparency = 1
	part(d, "Body").triCount = 5000
	expectX("동시: 빠짐 + 투명 + 예산", d, "moss_slime", { "①-1", "③-2", "⑥-2" })

	-- 보스(BossData 색 · 판정 파트 query)
	local okBoss, bossErr = pcall(function()
		d = good("section_guardian")
		expectX("보스 정상(section_guardian)", d, "section_guardian", {})
		d = good("section_guardian")
		scaleBox(part(d, "Head"), 1.6, part(d, "Head").center)
		expectX("보스 판정 파트 Head ×1.6", d, "section_guardian", { "④-2" })
		d = good("section_guardian")
		for _, p in ipairs(d.parts) do
			p.triCount = 400 -- 파트 20 × 400 = 8000 > 6000
		end
		local nParts = #d.parts
		expectX(("보스 예산 초과(%d × 400 = %d)"):format(nParts, nParts * 400), d, "section_guardian", nParts * 400 > 6000 and { "③-2" } or {})
	end)
	check("보스 묶음 실행", okBoss, okBoss and "" or tostring(bossErr))

	-- 없는 리그
	local okNone, linesNone = Check.check({ parts = {} }, "no_such_rig")
	check("없는 리그 id = X · 0행", okNone == false and linesNone[1]:find("없음", 1, true) ~= nil)

	-- FK 한 점 손계산: 전갈 Tail2 관절 = Body.at(0,-0.9,0) + Tail1.at(0,0.3,1.0) + Rx(35°) · (Tail1 pivot 역(0,0.6,0) + Tail2.at(0,0.6,0)) = (0, -0.6 + 1.2cos35°, 1.0 + 1.2sin35°)
	local e = Check.expected("sand_scorpion", 1).parts.Tail2.joint
	local wantY, wantZ = -0.6 + 1.2 * math.cos(math.rad(35)), 1.0 + 1.2 * math.sin(math.rad(35))
	check("FK 손계산(전갈 Tail2 관절)", math.abs(e[1]) < 1e-6 and math.abs(e[2] - wantY) < 1e-6 and math.abs(e[3] - wantZ) < 1e-6, ("(%.4f, %.4f, %.4f) 기대 (0, %.4f, %.4f)"):format(e[1], e[2], e[3], wantY, wantZ))
end)
if not ok then
	print("[MESH] 실행 오류 " .. tostring(err) .. " X")
	total += 1
end
print(("[MESH] 결과 %d/%d 통과"):format(pass, total))
