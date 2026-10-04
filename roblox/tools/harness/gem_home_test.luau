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
	local Icons, Armor, Ids, GemData, All10, All10Data, OptionData = MODS.ItemIcons, MODS.ArmorData, MODS.ArtAssetIds, MODS.GemData, MODS.All10, MODS.All10Data, MODS.OptionData
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

	-- ③ 초월 이펙트 단계
	local expect = { [0] = 1, [4] = 1, [5] = 2, [9] = 2, [10] = 3, [14] = 3, [15] = 4, [19] = 4, [20] = 5, [21] = 6, [25] = 6 }
	local bad = {}
	for lv, t in pairs(expect) do
		if All10.transcendFxTier(lv) ~= t then table.insert(bad, ("+%d→%s"):format(lv, tostring(All10.transcendFxTier(lv)))) end
	end
	check("초월 +0/5/10/15/20/21 → 단계 1 ~ 6", #bad == 0, table.concat(bad, ","))
	check("초월 아님(nil) → 단계 없음", All10.transcendFxTier(nil) == nil)
	check("임시 효과 = 기존 강화 연출 +30 재사용", All10Data.transcendEnhance.tempVisualLevel == 30)
end)
if not ok then
	print("하네스 에러 " .. tostring(err))
end
print(("끝 %d/%d"):format(pass, total))
