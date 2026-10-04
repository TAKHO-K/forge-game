-- QUEUE-ALL9E1 기능(디자인 보류 중 · 사용자 10-04 밤): ① 보석 탭 무기 그림 = 장착 무기(직업 × 등급) 아이콘 키 · 다시 그리는 신호 ② 보석 아이콘 한 소스(종류 × 등급 · 빠진 칸 0 · 박힌 채 등급 상승)
--   ③ 초월 강화 → 무기 이펙트 단계 번호(+0/5/10/15/20/21 · 연결 = WeaponEnhanceVisual)
-- 실행: EXTRA_FILES=client/ItemIcons.lua ECON_RES=res_gemhome.txt python build_run.py gem_home_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[GEMHOME] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local Icons, Armor, Ids, GemData, OptionData = MODS.ItemIcons, MODS.ArmorData, MODS.ArtAssetIds, MODS.GemData, MODS.OptionData
	local classes = { "greatsword", "dualblade", "bow", "healer" }

	-- ① 무기 그림 키 = 장비 탭과 같은 소스 · 장착 변경 · 계승 · 캐릭터 전환 · 강화 장면에서 장착 무기와 일치
	local function gemTabKey(attrs) -- GemTab.updateGemTab → GemHeader.update(weaponGradeId(), ClassId) 와 같은 계산
		return Icons.keyFor("weapon", Armor.gradeOrder[(attrs.WeaponGrade or 0) + 1], nil, attrs.ClassId)
	end
	local missing, wrong = {}, {}
	for _, c in ipairs(classes) do
		for gi, g in ipairs(Armor.gradeOrder) do
			local key = gemTabKey({ ClassId = c, WeaponGrade = gi - 1 })
			if key ~= ("icons/weapons/%s_%s"):format(c, g) then table.insert(wrong, c .. "/" .. g) end
			if not (Ids[key] and Ids[key].image) then table.insert(missing, key) end
		end
	end
	check("무기 키 = 직업 × 등급(32)", #wrong == 0, table.concat(wrong, ","))
	check("무기 아이콘 그림 있음(32 · 없으면 도형)", true, ("그림 없음 %d개 %s"):format(#missing, table.concat(missing, ",")))
	local scenes = {
		{ "장착(대검 전설 +12)", { ClassId = "greatsword", WeaponGrade = 3, WeaponLevel = 12 }, "icons/weapons/greatsword_legendary" },
		{ "강화(+12 → +13 · 키 그대로)", { ClassId = "greatsword", WeaponGrade = 3, WeaponLevel = 13 }, "icons/weapons/greatsword_legendary" },
		{ "환생 등급 상승(태초)", { ClassId = "greatsword", WeaponGrade = 6, WeaponLevel = 0 }, "icons/weapons/greatsword_primordial" },
		{ "계승(태초 → 초월)", { ClassId = "greatsword", WeaponGrade = 7, WeaponLevel = 30 }, "icons/weapons/greatsword_transcendent" },
		{ "캐릭터 전환(활 영웅)", { ClassId = "bow", WeaponGrade = 2, WeaponLevel = 4 }, "icons/weapons/bow_epic" },
		{ "직업 없음 = 도형(키 없음)", { WeaponGrade = 2 }, nil },
	}
	for _, s in ipairs(scenes) do
		local key = gemTabKey(s[2])
		check("장면 " .. s[1], key == s[3], tostring(key))
	end
	-- 다시 그리는 신호(GemTab 속성 구독) · 홈/가방 연결 · WeaponEnhanceVisual 신호 = luau CLI에 io가 없어 여기선 못 본다 → Play에서 확인

	-- ② 보석 아이콘 한 소스: 종류(옵션 id) × 등급 전부 키가 나온다(그림 없으면 temp:<등급> = 등급색 원)
	local kinds = {}
	for id in pairs(OptionData.options) do table.insert(kinds, id) end
	table.sort(kinds)
	local none, temp, art = 0, 0, 0
	for _, g in ipairs(Armor.gradeOrder) do
		for _, k in ipairs(kinds) do
			local key, hasArt = Icons.gemKey({ grade = g, option = { id = k } })
			if not key then none += 1 elseif hasArt then art += 1 else temp += 1 end
		end
		local key = Icons.gemKey({ grade = g }) -- 옵션 없는 보석
		if not key then none += 1 end
	end
	check("보석 아이콘 빠진 종류/등급 0", none == 0, ("조합 %d × %d · 그림 %d · 임시 %d"):format(#Armor.gradeOrder, #kinds, art, temp))
	local gem = { grade = "relic", option = { id = kinds[1] } }
	local before = Icons.gemKey(gem)
	gem.grade = "ancient" -- 박힌 채 등급 상승(GemSync가 같은 표로 다시 옴 → GemSlots.paint가 ItemIcons.gem을 다시 부름)
	local after = Icons.gemKey(gem)
	check("박힌 채 등급 상승 → 키 바뀜", before ~= after and after:find("ancient", 1, true) ~= nil, before .. " → " .. after)

	-- ③ 무기 이펙트 단계(사용자 10-04 밤): 초월 +0 ~ +25 → 0 ~ 25 · 요소 표 하나(WeaponFxStepData) · 계승 전 +20 ~ +30 색 띠
	local Fx, FxD = MODS.WeaponFx, MODS.WeaponFxStepData
	local T = FxD.transcend
	local contiguous = #T == 26
	for i, row in ipairs(T) do
		if row.step ~= i - 1 then contiguous = false end
	end
	check("초월 표 0 ~ 25 연속(26줄)", contiguous, tostring(#T))
	local majors = {}
	for _, row in ipairs(T) do
		if row.major then table.insert(majors, row.step) end
	end
	check("큰 변화 = +0 · 5 · 10 · 15 · 20", table.concat(majors, ",") == "0,5,10,15,20", table.concat(majors, ","))
	local KEYS = { "crackLines", "embers", "rays", "pulse", "ringShards", "prism", "constellation", "trail", "smokeAura", "hitShards", "bodyAura", "goldDust", "lightning" }
	local TRAIL = { none = 0, short = 1, long = 2, dual = 3 }
	local function num(v)
		if type(v) == "boolean" then return v and 1 or 0 end
		if type(v) == "string" then return TRAIL[v] end
		return v
	end
	local same, changes, decrease = {}, {}, {}
	for i = 2, #T do
		local diff = false
		for _, k in ipairs(KEYS) do
			if T[i][k] ~= T[i - 1][k] then diff = true end
			if num(T[i][k]) < num(T[i - 1][k]) then table.insert(decrease, ("+%d %s"):format(i - 1, k)) end
		end
		if diff then table.insert(changes, i - 1) else table.insert(same, i - 1) end
	end
	check("+1 ~ +4 = +0과 같다 · +5부터 매 단계 달라진다", table.concat(same, ",") == "1,2,3,4", "같음 " .. table.concat(same, ","))
	check("값 감소 없음(누적)", #decrease == 0, table.concat(decrease, ","))
	check("+21 ~ 25 별자리 점 1 ~ 5", T[22].constellation == 1 and T[26].constellation == 5)
	local bands = {}
	for lv = 19, 30 do
		local f = Fx.stepOf("primordial", lv, nil)
		table.insert(bands, ("%d=%s"):format(lv, f and f.band.band or "-"))
	end
	check("계승 전 +20 ~ +30 띠(은 · 민트 · 하늘 · 아쿠아 · 흰하늘 · 백금)", table.concat(bands, ",") == "19=-,20=silver,21=silver,22=mint,23=mint,24=sky,25=sky,26=aqua,27=aqua,28=whiteSky,29=whiteSky,30=platinum", table.concat(bands, ","))
	local function stepOfAttrs(a)
		local f = Fx.stepOf(Armor.gradeOrder[(a.WeaponGrade or 0) + 1], a.WeaponLevel, a.TranscendLevel)
		return f and (f.kind .. ":" .. tostring(f.step)) or "nil"
	end
	local scenes2 = {
		{ "태초 +29", { WeaponGrade = 6, WeaponLevel = 29 }, "enhanceHigh:29" },
		{ "강화 성공 +30(백금)", { WeaponGrade = 6, WeaponLevel = 30 }, "enhanceHigh:30" },
		{ "계승 → 초월 +0", { WeaponGrade = 7, WeaponLevel = 30, TranscendLevel = 0 }, "transcend:0" },
		{ "초월 강화 성공 +7 → +8", { WeaponGrade = 7, WeaponLevel = 30, TranscendLevel = 8 }, "transcend:8" },
		{ "캐릭터 전환(전설 +12)", { WeaponGrade = 3, WeaponLevel = 12 }, "nil" },
		{ "범위 밖 +40 → 25", { WeaponGrade = 7, WeaponLevel = 30, TranscendLevel = 40 }, "transcend:25" },
	}
	for _, sc in ipairs(scenes2) do
		local got = stepOfAttrs(sc[2])
		check("단계 장면 " .. sc[1], got == sc[3], got)
	end
	local R = FxD.rules
	check("이펙트 규칙(오라 ≤ 1.5 · 화면 오라/바닥 금지 · 보스전 남 ×0.5)", R.auraMaxStuds <= 1.5 and R.screenAura == false and R.groundFx == false and R.othersInBossMultiplier == 0.5)
end)
if not ok then
	print("하네스 에러 " .. tostring(err))
end
print(("끝 %d/%d"):format(pass, total))
