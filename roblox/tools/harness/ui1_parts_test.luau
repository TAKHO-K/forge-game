-- UI-1 1단계 A 공용 부품 하네스(순수): 상태 아이콘 표(StatusIconData.icons) · 그림 업로드 기록 · 글자 ko/en 짝 · 색 규칙 · 데이터 연결 목록.
-- 실행: LUAU=<luau.exe> ECON_RES=res_ui1parts.txt python build_run.py ui1_parts_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[UI1P] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end
local okRun, err = pcall(function()
	local S = MODS.StatusIconData
	local D = MODS.UiPartsData
	local A = MODS.ArtAssetIds
	local T = MODS.TextData
	local n, used, noImg, noText, noData, badCat = 0, 0, {}, {}, {}, {}
	for id, def in pairs(S.icons) do
		n += 1
		if not def.unused then
			used += 1
		end
		local e = A["ui/ds/status-" .. id]
		if not (e and e.image) then
			table.insert(noImg, id)
		end
		for _, lang in ipairs({ "ko", "en" }) do
			for _, k in ipairs({ ".name", ".desc" }) do
				if not T[lang]["ui1.status." .. id .. k] then
					table.insert(noText, lang .. ":" .. id .. k)
				end
			end
		end
		if not (def.src or def.trapKinds) and not def.unused then
			table.insert(noData, id)
		end
		if not D.statusColors[def.cat or ""] then
			table.insert(badCat, id)
		end
	end
	table.sort(noData)
	check("상태 아이콘 39 + 옛 이름 1(dash-invuln = 안 씀)", n == 40 and used == 39 and S.icons["dash-invuln"].unused == true, ("%d/%d"):format(used, n))
	check("모든 아이콘 그림 업로드 기록(이미지 id)", #noImg == 0, table.concat(noImg, ","))
	check("이름 · 효과 한 줄 = ko · en 짝", #noText == 0, table.concat(noText, ","))
	check("범주 = cc · debuff · buff(색 3개 · 초록 없음)", #badCat == 0 and D.statusColors.cc == "D32F2F" and D.statusColors.debuff == "FFC400" and D.statusColors.buff == "2F9BFF")
	check("v2 확정: dash-guard = 이로운 효과(대시 보호) · 격노 = 보스 Attribute(BossEnraged)", S.icons["dash-guard"].cat == "buff" and S.icons["boss-enrage"].src[1].attr == "BossEnraged")
	local kinds, dup = {}, {}
	for id, def in pairs(S.icons) do
		for _, k in ipairs(def.trapKinds or {}) do
			if kinds[k] then
				table.insert(dup, k)
			end
			kinds[k] = id
		end
	end
	check("잡힘 종류 → 아이콘 하나씩(겹침 없음)", #dup == 0, table.concat(dup, ","))
	print(("[UI1P] 데이터 연결 없음(안 보임) %d: %s"):format(#noData, table.concat(noData, ", ")))
	local parts = { "toggle", "gauge", "cooldown", "tip", "banner", "combatText", "loading", "empty" }
	local missing = {}
	local function walk(t)
		for k, v in pairs(t) do
			if type(v) == "string" and v:match("^ui/ds/") then
				local e = A[v]
				if not (e and e.image) then
					table.insert(missing, v)
				end
			elseif type(v) == "table" then
				walk(v)
			end
		end
	end
	for _, p in ipairs(parts) do
		walk(D[p])
	end
	walk({ D.status.frameMore, D.status.glow })
	check("부품 그림(토글 · 게이지 · 덮개 · 설명 창 · 배너 · 빛살 · 받기 전 · 빈 상태) 업로드 기록", #missing == 0, table.concat(missing, ","))
	local ctOk = true
	for _, k in pairs(D.combatText.kinds) do
		ctOk = ctOk and T.ko[k.textKey] ~= nil and T.en[k.textKey] ~= nil
	end
	check("전투 문구 4 = 큰 영어 + 한국어 줄 키", ctOk)
end)
if not okRun then
	print("[UI1P] 하네스 에러 " .. tostring(err))
end
print(("[UI1P] 끝 %d/%d"):format(pass, total))
