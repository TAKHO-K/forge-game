-- QUEUE-ALL9E1 1-1 장비 v3 하네스: ① 등급 8 × 세트 6 = 48조합 예약 색(흰 + 자홍 = 태초만 · 검정 + 금 = 초월만 · 초월 + 모래 = 금 대신 모래) ② 구역 · 문 부품 판정
--   ③ 메시 메타: 직업 4 × 부위 3 × 단계 5 = 60 + 문장 6 키가 MeshMeta.armor_wear에 있고 조각 이름의 구역이 규격 8개 안 · 1인 MeshPart ≤ 24(문 부품은 그 등급만)
-- 실행: EXTRA_FILES=client/ArmorColors.lua,shared/MeshMeta/armor_wear.lua ECON_RES=res_gear.txt python build_run.py gear_v3_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[GV3] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local AC, G, Wear, Armor = MODS.ArmorColors, MODS.GearV3Data, MODS.armor_wear, MODS.ArmorData
	local function near(c, rgb, tol)
		return math.abs(c.R - rgb[1] / 255) + math.abs(c.G - rgb[2] / 255) + math.abs(c.B - rgb[3] / 255) <= (tol or 0.12)
	end
	local WHITE, MAGENTA = { 247, 245, 239 }, { 233, 91, 200 }
	local BLACK, GOLDS = { 32, 33, 39 }, { { 216, 185, 110 }, { 198, 154, 69 } }
	local ZONES = { "Body", "Trim", "Inner", "Attach", "Gem", "CoreGem", "Float", "Crack", "Emblem" }
	-- ① 48조합
	local bad, n = {}, 0
	for _, grade in ipairs(Armor.gradeOrder) do
		for setZone in pairs(G.sets) do
			n += 1
			local col = {}
			for _, z in ipairs(ZONES) do
				col[z] = AC.colorOfGearV3("X_" .. z, setZone, grade)
			end
			local body = col.Body
			local function any(target)
				for _, z in ipairs({ "Trim", "Inner", "Attach", "Gem", "Emblem" }) do
					if near(col[z], target) then return true end
				end
				return false
			end
			if grade ~= "primordial" and near(body, WHITE) and any(MAGENTA) then
				table.insert(bad, grade .. "/" .. setZone .. " 흰+자홍")
			end
			if grade ~= "transcendent" and near(body, BLACK) and (any(GOLDS[1]) or any(GOLDS[2])) then
				table.insert(bad, grade .. "/" .. setZone .. " 검정+금")
			end
			if grade == "transcendent" and setZone == "tier4" and (near(col.Gem, GOLDS[2], 0.02) or near(col.Emblem, GOLDS[2], 0.02)) then
				table.insert(bad, "transcendent/tier4 금 남음")
			end
			if not near(body, { body.R * 255, body.G * 255, body.B * 255 }, 0) then
				table.insert(bad, grade .. "/" .. setZone .. " 색 없음")
			end
		end
	end
	check("48조합 예약 색(흰 + 자홍 = 태초만 · 검정 + 금 = 초월만 · 초월 + 모래 = 금 대신 모래)", n == 48 and #bad == 0, ("%d조합 · 위반 %d %s"):format(n, #bad, table.concat(bad, ", ")))
	local sandOk = near(AC.colorOfGearV3("Chest_Gem", "tier4", "transcendent"), G.sets.tier4.color1, 0.02) and near(AC.colorOfGearV3("Chest_Gem", "tier4", "legendary"), G.sets.tier4.color2, 0.02)
	check("초월 + 모래 유적 = 보조 보석 모래 #D8BC83 · 다른 등급 = 금 #C69A45", sandOk)
	-- ② 구역 · 문
	local z1, g1 = AC.gearV3Zone("Shoulder_L_Body")
	local z2, g2 = AC.gearV3Zone("Chest_Trim_An")
	local z3, g3 = AC.gearV3Zone("Chest_CoreGem_Re")
	check("구역 · 문 이름 판정(Shoulder_L_Body = Body · Chest_Trim_An = Trim/An · Chest_CoreGem_Re = CoreGem/Re)", z1 == "Body" and g1 == nil and z2 == "Trim" and g2 == "An" and z3 == "CoreGem" and g3 == "Re")
	local gateOk = AC.gearV3Visible("Chest_Gem_Ep", "epic") and not AC.gearV3Visible("Chest_Gem_Ep", "rare") and AC.gearV3Visible("Chest_CoreGem_Re", "relic") and not AC.gearV3Visible("Chest_CoreGem_Re", "ancient")
		and AC.gearV3Visible("Chest_Crack_Tr", "transcendent") and not AC.gearV3Visible("Chest_Crack_Tr", "primordial") and AC.gearV3Visible("Chest_Body", "normal")
	check("문 부품 = 그 등급만(영웅 Ep · 유물 Re · 고대 An · 초월 Tr)", gateOk)
	local neonOk = select(2, AC.colorOfGearV3("X_Crack", "tier1", "transcendent")) == true and select(2, AC.colorOfGearV3("X_Float", "tier1", "relic")) == true
		and select(2, AC.colorOfGearV3("X_Body", "tier1", "transcendent")) == false and select(2, AC.colorOfGearV3("X_Gem", "tier1", "normal")) == false
	check("발광: 균열 · 부유 = Neon · 본체 = 아님 · 일반 보조 보석 = 아님(발광 0)", neonOk)
	-- 무기(5절 ⑤): 초월 = 흑요석 몸 + 금 균열(보라 = 영웅 색 금지) · 태초 = 백색 몸 · 균열(Tr)은 초월만
	local GV = MODS.GearV3
	local EPIC = { 117, 69, 198 }
	local purple = false
	for _, z in ipairs({ "Body", "Trim", "Inner", "CoreGem", "Float", "Crack" }) do
		if near(GV.weaponColor("Blade_" .. z, "transcendent"), EPIC, 0.25) then purple = true end
	end
	local wOk = near(GV.weaponColor("Blade_Body", "transcendent"), BLACK, 0.02) and near(GV.weaponColor("Crack1_Crack_Tr", "transcendent"), GOLDS[1], 0.02)
		and near(GV.weaponColor("Blade_Body", "primordial"), WHITE, 0.02) and not purple and GV.visible("Crack1_Crack_Tr", "transcendent") and not GV.visible("Crack1_Crack_Tr", "primordial")
	check("무기 색: 초월 = 흑요석 #202127 + 균열 #D8B96E · 보라 없음 · 태초 = 백색 · 균열은 초월만", wOk)
	-- ③ 메시 메타
	local missing, badZone, worst, worstKey = {}, {}, 0, ""
	local zoneSet = {}
	for _, z in ipairs(ZONES) do zoneSet[z] = true end
	for _, cls in ipairs({ "greatsword", "dualblade", "bow", "healer" }) do
		for _, grade in ipairs(Armor.gradeOrder) do
			local parts = 0
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				local key = ("%s_%s_%s"):format(part, cls, G.stageOfGrade[grade])
				local pieces = Wear.pieces[key]
				if not pieces then
					missing[key] = true
				else
					for name in pairs(pieces) do
						local z = AC.gearV3Zone(name)
						if not zoneSet[z] then table.insert(badZone, key .. "/" .. name) end
						if AC.gearV3Visible(name, grade) then parts += 1 end
					end
				end
			end
			parts += 1 -- 문장
			if parts > worst then worst, worstKey = parts, cls .. "/" .. grade end
		end
	end
	local nMissing = 0
	for _ in pairs(missing) do nMissing += 1 end
	for _, s in pairs(G.sets) do
		if not Wear.pieces["emblem_" .. s.emblem] then nMissing += 1 end
	end
	check("메시 메타 60 + 문장 6 키 있음 · 조각 구역 = 규격 9개 안", nMissing == 0 and #badZone == 0, ("빠짐 %d · 구역 밖 %d"):format(nMissing, #badZone))
	check("1인 방어구 MeshPart ≤ 24(문 부품은 그 등급만 · 문장 포함)", worst <= G.budget.meshPartsPerPlayer, ("최대 %d(%s)"):format(worst, worstKey))
end)
if not ok then
	print("[GV3] 에러 " .. tostring(err))
end
print(("[GV3] 끝 %d/%d"):format(pass, total))
