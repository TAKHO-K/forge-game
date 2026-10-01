-- QUEUE-ALL5 A3 모르는 id 보관(SaveSystem.quarantineUnknownIds) 하네스 - 실제 SaveSystem · shared/IdRegistry · 데이터 표.
-- 실행: LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=SaveSystem ECON_RES=res_quar.txt python build_run.py id_quarantine_test.luau
local pass, total = 0, 0
local function check(label, ok, detail)
	total += 1
	if ok then pass += 1 end
	print(("[QUAR] %s %s %s"):format(label, detail or "", ok and "O" or "X"))
end

local ok, err = pcall(function()
	local SaveSystem, IdRegistry = MODS.SaveSystem, MODS.IdRegistry
	local lists = IdRegistry.lists()
	local CLASS = MODS.ClassData.order[1]

	-- 모든 종류의 아는 id를 다 가진 프로필(오탐 0 확인)
	local function fullProfile()
		local p = SaveSystem.migrate({})
		for i, grade in ipairs(lists.grade) do
			for _, part in ipairs(lists.part) do
				table.insert(p.inventory, { grade = grade, part = part, itemLevel = 10, locked = false, setZone = lists.setZone[(i % #lists.setZone) + 1],
					option = { id = lists.option[(i % #lists.option) + 1], roll = 0.5 }, skillVariant = { classId = CLASS, slot = "E", id = lists.skillVariant[(i % #lists.skillVariant) + 1] },
					special = grade == "transcendent" and lists.special[1] or nil })
			end
		end
		p.inventory[1].option = nil -- 옵션 없는 장비
		local cs = p.classes[CLASS]
		cs.equipment.armor = { grade = "epic", part = "armor", option = { id = lists.option[1], roll = 0.3 } }
		cs.weapon.gems[1] = { option = { id = lists.option[2], roll = 0.4 } }
		table.insert(cs.gemInventory, { option = { id = lists.option[3], roll = 0.4 } })
		for _, id in ipairs(lists.cosmeticTheme) do p.cosmetics.themes[id] = true end
		for _, id in ipairs(lists.gliderSkin) do p.cosmetics.gliderSkins[id] = true end
		p.cosmetics.equipped.dashTrail = lists.cosmeticTheme[1]
		p.cosmetics.equipped.gliderSkin = lists.gliderSkin[1]
		p.cosmetics.equipped.nameplateColor = MODS.MonetizationData.gamePasses.nameplateColor.colors[1] -- 리뷰: 게임패스 선택값(테마 id 아님)
		p.cosmetics.equipped.nameplateBadge = MODS.MonetizationData.gamePasses.nameplateBadge.badges[1]
		for _, id in ipairs(lists.title) do p.titles[id] = true end
		if type(p.codex) == "table" then p.codex.title = lists.title[1] end
		return p
	end

	local p0 = fullProfile()
	local invN = #p0.inventory
	local m0, r0 = SaveSystem.quarantineUnknownIds(p0)
	check(("아는 id만(장비 %d · 등급 %d × 부위 %d · 옵션 · 직업옵션 · 초월 특수 · 보석 · 치장 · 칭호 %d) = 옮김 0"):format(invN, #lists.grade, #lists.part, #lists.title),
		#m0 == 0 and r0 == 0 and #p0.inventory == invN and SaveSystem.isValidProfile(p0), table.concat(m0, ","))
	local fresh = SaveSystem.migrate({})
	local mf = SaveSystem.quarantineUnknownIds(fresh)
	check("새 계정 = 옮김 0 · quarantine 빈 목록(v63)", #mf == 0 and type(fresh.quarantine) == "table" and #fresh.quarantine == 0 and fresh.version == MODS.SaveConfig.saveVersion)

	-- 종류마다 모르는 id
	local p = fullProfile()
	p.inventory[2].option = { id = "goneOption", roll = 0.9 }
	p.inventory[3].grade = "mythic"
	p.inventory[4].part = "helmet"
	p.inventory[5].skillVariant = { classId = CLASS, slot = "E", id = "goneVariant" }
	p.inventory[6].special = "goneSpecial"
	p.inventory[7].setZone = "goneZone" -- 세트 구역은 보관 안 함(세트 아님으로 동작)
	local cs = p.classes[CLASS]
	cs.equipment.gloves = { grade = "epic", part = "gloves", option = { id = "goneOption2" } }
	cs.weapon.gems[2] = { option = { id = "goneGemOption" } }
	table.insert(cs.gemInventory, { option = { id = "goneGemOption" } })
	p.materials.goneStone = 12
	p.cosmetics.themes.goneTheme = true
	p.cosmetics.gliderSkins.goneGlider = true
	p.cosmetics.equipped.jumpFx = "goneTheme"
	p.cosmetics.equipped.gliderSkin = "goneGlider"
	p.titles.goneTitle = true
	if type(p.codex) == "table" then p.codex.title = "goneTitle" end
	local before = #p.inventory
	check("고치기 전: 모르는 옵션이면 isValidProfile = false(옛 = 계정 로드 실패)", not SaveSystem.isValidProfile(p))
	local moved, restored, resets = SaveSystem.quarantineUnknownIds(p)
	check("이름표 색 · 배지(게임패스 선택값)는 그대로 · 선택 해제 = 세트 칸 · 글라이더 · 칭호 3", p.cosmetics.equipped.nameplateColor ~= nil and p.cosmetics.equipped.nameplateBadge ~= nil and #resets == 3,
		("%s · %s · 해제 [%s]"):format(tostring(p.cosmetics.equipped.nameplateColor), tostring(p.cosmetics.equipped.nameplateBadge), table.concat(resets, ",")))
	local kinds = {}
	for _, e in ipairs(p.quarantine) do kinds[e.kind] = (kinds[e.kind] or 0) + 1 end
	check("모르는 id = 보관(장비 6 · 보석 2 · 재료 1 · 테마 1 · 글라이더 1 · 칭호 1) · 로드 가능", (kinds.item or 0) == 6 and (kinds.gem or 0) == 2 and kinds.material == 1 and kinds.cosmeticTheme == 1
		and kinds.gliderSkin == 1 and kinds.title == 1 and SaveSystem.isValidProfile(p), ("옮김 %d: %s"):format(#moved, table.concat(moved, ",")))
	local zoneKept = false
	for _, item in ipairs(p.inventory) do zoneKept = zoneKept or item.setZone == "goneZone" end
	check("가방에서 5개 빠짐 · 세트 구역만 모르는 장비는 남음", #p.inventory == before - 5 and zoneKept, ("%d → %d"):format(before, #p.inventory))
	check("착용 장갑 비움 · 박힌 보석 칸 false · 보석 가방에서 빠짐", cs.equipment.gloves == nil and cs.weapon.gems[2] == false and #cs.gemInventory == 1 and cs.equipment.armor ~= nil)
	check("재료 · 치장 · 칭호에서 빠짐 · 장착 치장 기본으로 · 고른 칭호 해제", p.materials.goneStone == nil and p.cosmetics.themes.goneTheme == nil and p.cosmetics.gliderSkins.goneGlider == nil
		and p.cosmetics.equipped.jumpFx == nil and p.cosmetics.equipped.gliderSkin == nil and p.titles.goneTitle == nil and (type(p.codex) ~= "table" or p.codex.title == nil))
	local m2, r2 = SaveSystem.quarantineUnknownIds(p)
	check("두 번째 로드 = 옮김 0 · 되돌림 0(멱등) · 보관 그대로", #m2 == 0 and r2 == 0 and #p.quarantine == 12, ("보관 %d"):format(#p.quarantine))

	-- 저장 왕복(JSON 비슷한 깊은 복사) 뒤에도 보관 칸 유지
	local function deep(v)
		if type(v) ~= "table" then return v end
		local c = {}
		for k, x in pairs(v) do c[k] = deep(x) end
		return c
	end
	local round = SaveSystem.migrate(deep(p))
	check("저장 왕복 뒤 보관 칸 12 그대로", #round.quarantine == 12)

	-- 같은 id가 데이터에 다시 생기면 제자리로
	MODS.OptionData.options.goneOption = { displayName = "되살린 옵션", category = "dps", baseValue = 0.1 }
	MODS.OptionData.options.goneGemOption = { displayName = "되살린 보석 옵션", category = "dps", baseValue = 0.1 }
	MODS.EnhanceMaterialData.order[#MODS.EnhanceMaterialData.order + 1] = "goneStone"
	MODS.TitleData.titles.goneTitle = { name = "되살린 칭호" }
	IdRegistry.reset()
	local inv0, gem0 = #round.inventory, #round.classes[CLASS].gemInventory
	local m3, r3 = SaveSystem.quarantineUnknownIds(round)
	check("id가 다시 생김 = 제자리로(가방 장비 1 · 보석 2 → 보석 가방 · 재료 +12 · 칭호) · 나머지 7은 보관", r3 == 5 and #round.inventory == inv0 + 1 and #round.classes[CLASS].gemInventory == gem0 + 2
		and round.materials.goneStone == 12 and round.titles.goneTitle == true and #round.quarantine == 7 and #m3 == 0, ("되돌림 %d · 보관 %d"):format(r3, #round.quarantine))
	MODS.OptionData.options.goneOption, MODS.OptionData.options.goneGemOption, MODS.TitleData.titles.goneTitle = nil, nil, nil
	table.remove(MODS.EnhanceMaterialData.order)
	IdRegistry.reset()

	-- 이관: v62 표본 → v63 quarantine 빈 목록 · 백업 대상
	local v62 = SaveSystem.migrate({})
	v62.version, v62.quarantine = 62, nil
	local m63 = SaveSystem.migrate(v62)
	check("v62 표본 → 최신(v64): quarantine 빈 목록", m63.version == MODS.SaveConfig.saveVersion and type(m63.quarantine) == "table" and #m63.quarantine == 0)
	-- QUEUE-ALL6 H: v63 표본(cosmetics.items 없음) → v64 = 빈 소품 표 · 모르는 소품 id = 보관 · 장착 칸 비움
	local v63 = SaveSystem.migrate({})
	v63.version, v63.cosmetics.items = 63, nil
	local m64 = SaveSystem.migrate(v63)
	check("v63 표본 → v64: cosmetics.items 빈 표", m64.version == 64 and type(m64.cosmetics.items) == "table" and next(m64.cosmetics.items) == nil)
	local q = SaveSystem.migrate({})
	q.cosmetics.items = { rocketPop = true, ghostItem = true }
	q.cosmetics.equipped.killFx = "ghostItem"
	local moved = SaveSystem.quarantineUnknownIds(q)
	check(("모르는 소품 id 보관 · 아는 것 그대로 · 장착 칸 비움: 옮김 %d"):format(#moved), q.cosmetics.items.rocketPop == true and q.cosmetics.items.ghostItem == nil and q.cosmetics.equipped.killFx == nil and #moved >= 1)
	check("IdRegistry 종류 11(cosmeticItem 추가) · 빈 목록 없음", #IdRegistry.kinds == 11 and (function()
		for _, kind in ipairs(IdRegistry.kinds) do if not lists[kind] or #lists[kind] == 0 then return false end end
		return true
	end)())
end)
if not ok then print("[QUAR] 하네스 에러 " .. tostring(err)) end
print(("[QUAR] 끝 %d/%d"):format(pass, total))
