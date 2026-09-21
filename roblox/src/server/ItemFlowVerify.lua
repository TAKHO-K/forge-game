-- S20d 자동 검증(서버) - 장비 빠른 장착 · 해제 입력 재구성이 기대는 서버 규칙 · 미리 판정 · 보석 자동 장착 미리보기.
--   runPure()             (가) 순수 함수: Equip.equipBlockReason · Equip.unequipBlockReason · Gem.replacePreview (플레이어 불필요)
--   runLive(player, env)  (나) 실제 Player · 실제 프로필: ItemEquip.handle의 이유 코드 · 교체 규칙(기존 장비는 가방 맨 끝으로 · 칸 수 불변) · 해제 규칙(가방 가득 차면 full · 장비 소실 0) ·
--                         클라 미리 판정(Equip)이 서버 결과와 전 조합에서 같은가. 끝에서 프로필을 원래대로 되돌린다(env.restore).
-- 서버 규칙은 이 세션에서 바뀌지 않는다(착용 = 항상 교체 · 해제 = 가방에 빈 칸이 있을 때만). 이 검증이 그 규칙을 못 박는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local Equip = require(ReplicatedStorage.Shared.Equip)
local Gem = require(ReplicatedStorage.Shared.Gem)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ItemEquip = require(script.Parent.ItemEquip)
local InventorySync = require(script.Parent.InventorySync)

local ItemFlowVerify = {}

local function tally(label)
	local self = { pass = 0, total = 0 }
	function self.check(name, ok)
		self.total += 1
		if ok then
			self.pass += 1
		end
		print(("[S20d][%s] %s %s"):format(label, name, ok and "O" or "X"))
	end
	return self
end

local function item(part, grade, itemLevel)
	return { grade = grade, part = part, dropStage = 1, itemLevel = itemLevel, tierIndex = 1, locked = false }
end

local function itemKey(it)
	return it and (it.part .. ":" .. it.grade .. ":" .. tostring(it.itemLevel)) or "-"
end

local function fingerprint(player)
	local parts = {}
	for _, it in ipairs(PlayerProfile.getInventory(player)) do
		table.insert(parts, itemKey(it))
	end
	table.insert(parts, "|")
	for _, part in ipairs(EquipSlots.order) do
		table.insert(parts, itemKey(PlayerProfile.getEquipped(player, part)))
	end
	return table.concat(parts, ",")
end

-- ═══ (가) 순수 함수 ═══
function ItemFlowVerify.runPure()
	print("===S20d 검증 시작(가: 착용 · 해제 판정 · 보석 교체 미리보기)===")
	local t = tally("가")
	local bag = { item("armor", "epic", 11), item("gloves", "rare", 12), { grade = "epic", itemLevel = 5 } } -- 3번은 부위 없는 옛 아이템
	t.check("직업 없음 -> no_class", Equip.equipBlockReason(bag, 1, false) == "no_class")
	t.check("없는 칸 -> not_found", Equip.equipBlockReason(bag, 9, true) == "not_found")
	t.check("부위 없는 아이템 -> not_found", Equip.equipBlockReason(bag, 3, true) == "not_found")
	t.check("정상 착용 -> nil", Equip.equipBlockReason(bag, 1, true) == nil)
	t.check("가방이 가득 차도 착용은 된다(교체라 칸 수 불변)", Equip.equipBlockReason(bag, 2, true) == nil)
	local equipped = { armor = item("armor", "relic", 20), gloves = nil, shoes = nil }
	t.check("해제: 직업 없음 -> no_class", Equip.unequipBlockReason(equipped, "armor", 3, 20, false) == "no_class")
	t.check("해제: 착용 안 한 부위 -> not_equipped", Equip.unequipBlockReason(equipped, "gloves", 3, 20, true) == "not_equipped")
	t.check("해제: 모르는 부위 이름 -> not_equipped", Equip.unequipBlockReason(equipped, "weapon", 3, 20, true) == "not_equipped")
	t.check("해제: 가방 19/20 -> nil(마지막 한 칸까지는 된다)", Equip.unequipBlockReason(equipped, "armor", 19, 20, true) == nil)
	t.check("해제: 가방 20/20 -> full", Equip.unequipBlockReason(equipped, "armor", 20, 20, true) == "full")
	t.check("해제: 직업 없음이 가득 참보다 먼저", Equip.unequipBlockReason(equipped, "armor", 20, 20, false) == "no_class")

	local all5, only2 = { true, true, true, true, true }, { false, true, false, false, false }
	local gems = { { grade = "primordial", itemLevel = 21 }, { grade = "epic", itemLevel = 22 }, { grade = "legendary", itemLevel = 23 }, { grade = "relic", itemLevel = 24 }, { grade = "ancient", itemLevel = 25 } }
	local replaced, slot = Gem.replacePreview(all5, gems, "epic")
	t.check("영웅 보석 -> 2번 홈의 보석(영웅 22)이 밀려난다", slot == 2 and replaced == gems[2])
	replaced, slot = Gem.replacePreview(all5, gems, "primordial")
	t.check("태초 보석 -> 1번 홈의 보석(태초 21)이 밀려난다", slot == 1 and replaced == gems[1])
	replaced = Gem.replacePreview(all5, { gems[1], false, gems[3], gems[4], gems[5] }, "epic")
	t.check("자동 대상 홈이 비어 있으면 교체 없음(nil)", replaced == nil)
	replaced = Gem.replacePreview({ false, false, false, false, false }, gems, "epic")
	t.check("열린 홈이 없으면 nil", replaced == nil)
	replaced = Gem.replacePreview(only2, gems, "ancient")
	t.check("열린 홈(2번 - 영웅 상한)이 못 받는 등급이면 nil", replaced == nil)
	local consistent = true
	for _, grade in ipairs({ "epic", "legendary", "relic", "ancient", "primordial" }) do
		local target = Gem.autoSlot(all5, gems, grade)
		local shown, shownSlot = Gem.replacePreview(all5, gems, grade)
		consistent = consistent and target ~= nil and shownSlot == target and shown == gems[target]
	end
	t.check("미리보기 대상 홈 = 자동 장착 대상 홈(5등급 전부)", consistent)
	print(("===S20d 검증 끝(가)=== %d/%d 통과"):format(t.pass, t.total))
end

-- ═══ (나) 실제 Player ═══
function ItemFlowVerify.runLive(player, env)
	print("===S20d 검증 시작(나: 실제 프로필 - 착용 · 해제 규칙 · 이유 코드 · 미리 판정 = 서버)===")
	local t = tally("나")
	env.ensureBackup(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1]) -- 직업을 아직 안 골랐으면 첫 직업(백업이 복원한다)
	end
	local originalPrint = fingerprint(player)
	local profile = PlayerProfile.getProfile(player)
	local classState = profile.classes[profile.classId]
	local bag = PlayerProfile.getInventory(player)
	local slots = profile.inventorySlots

	local function seed()
		table.clear(bag)
		table.insert(bag, item("armor", "epic", 11))
		table.insert(bag, item("gloves", "rare", 12))
		table.insert(bag, item("shoes", "relic", 13))
		table.insert(bag, item("armor", "rare", 14))
		for _, part in ipairs(EquipSlots.order) do
			classState.equipment[part] = nil
		end
	end
	local function fillBagToFull()
		while #bag < slots do
			table.insert(bag, item("gloves", "normal", 1))
		end
	end
	seed()
	local seeded = fingerprint(player)

	-- 사전 작업(가방 칸 수 서버 전달): 클라가 받는 스냅샷의 slots는 프로필 값 그대로다(push · fetch가 같은 InventorySync.snapshot).
	local snap = InventorySync.snapshot(profile)
	t.check(("스냅샷 slots = 프로필 칸 수(%s · %s) · 가방 배열 그대로"):format(tostring(snap.slots), tostring(slots)), snap.slots == slots and type(snap.slots) == "number" and snap.inventory == bag)

	local ok1, why1 = ItemEquip.handle(player, "sell", 1)
	t.check("모르는 action -> invalid", ok1 == false and why1 == "invalid")
	local ok2, why2 = ItemEquip.handle(player, "equip", "1")
	t.check("착용 인자가 숫자가 아니면 invalid", ok2 == false and why2 == "invalid")
	local ok3, why3 = ItemEquip.handle(player, "unequip", 1)
	t.check("해제 인자가 문자열이 아니면 invalid", ok3 == false and why3 == "invalid")
	t.check("invalid는 상태를 안 바꾼다", fingerprint(player) == seeded)
	local ok4, why4 = ItemEquip.handle(player, "equip", 99)
	t.check("없는 칸 -> not_found + 상태 불변", ok4 == false and why4 == "not_found" and fingerprint(player) == seeded)
	local ok5, why5 = ItemEquip.handle(player, "unequip", "armor")
	t.check("착용 안 한 부위 해제 -> not_equipped + 상태 불변", ok5 == false and why5 == "not_equipped" and fingerprint(player) == seeded)
	local savedClassId = profile.classId
	profile.classId = nil
	local ok6, why6 = ItemEquip.handle(player, "equip", 1)
	local ok7, why7 = ItemEquip.handle(player, "unequip", "armor")
	profile.classId = savedClassId
	t.check("직업 미선택 -> 착용 · 해제 모두 no_class + 상태 불변", ok6 == false and why6 == "no_class" and ok7 == false and why7 == "no_class" and fingerprint(player) == seeded)

	-- 착용: 빈 부위 -> 가방에서 빠진다(칸 수 -1)
	local ok8, why8 = ItemEquip.handle(player, "equip", 1)
	t.check("빈 부위에 착용 -> 성공 + 이유 없음", ok8 == true and why8 == nil)
	t.check("갑옷 칸에 영웅 갑옷(Lv.11)이 들어갔다 · 가방 3칸", itemKey(PlayerProfile.getEquipped(player, "armor")) == "armor:epic:11" and #bag == 3)

	-- 교체: 찬 부위에 다른 갑옷을 착용 -> 기존 갑옷은 가방 맨 끝으로 · 칸 수 불변
	local rareIndex
	for index, it in ipairs(bag) do
		if itemKey(it) == "armor:rare:14" then
			rareIndex = index
		end
	end
	local before = #bag
	local ok9 = ItemEquip.handle(player, "equip", rareIndex)
	t.check("찬 부위에 착용 -> 교체 성공", ok9 == true and itemKey(PlayerProfile.getEquipped(player, "armor")) == "armor:rare:14")
	t.check("기존 갑옷(영웅 11)이 가방 맨 끝으로 돌아왔다 · 칸 수 불변", itemKey(bag[#bag]) == "armor:epic:11" and #bag == before)

	-- 해제: 착용 중 -> 가방 맨 끝(칸 수 +1)
	local ok10, why10 = ItemEquip.handle(player, "unequip", "armor")
	t.check("해제 -> 성공 · 칸 수 +1 · 그 장비가 맨 끝에", ok10 == true and why10 == nil and #bag == before + 1 and itemKey(bag[#bag]) == "armor:rare:14" and PlayerProfile.getEquipped(player, "armor") == nil)

	-- 가방 가득 참: 해제 거절 · 장비 소실 0 · 착용(교체)은 된다
	seed()
	ItemEquip.handle(player, "equip", 1) -- 갑옷 착용(영웅 11)
	fillBagToFull()
	local fullPrint = fingerprint(player)
	local ok11, why11 = ItemEquip.handle(player, "unequip", "armor")
	t.check(("가방 %d/%d에서 해제 -> full + 상태 불변(장비 소실 0)"):format(#bag, slots), ok11 == false and why11 == "full" and fingerprint(player) == fullPrint and PlayerProfile.getEquipped(player, "armor") ~= nil)
	local swapIndex
	for index, it in ipairs(bag) do
		if it.part == "armor" then
			swapIndex = index
		end
	end
	local fullCount = #bag
	local ok12 = ItemEquip.handle(player, "equip", swapIndex)
	t.check("가방이 가득 차도 교체 착용은 된다 · 칸 수 불변", ok12 == true and #bag == fullCount)

	-- 미리 판정(shared/Equip) = 서버 결과: 가방 index 1 ~ (칸+2) × 3부위 + 무기(해제 대상 아님) × (여유 · 가득) 전 조합. 조합마다 같은 출발선(갑옷 · 장갑 착용 + 가방)에서 시작한다.
	local mismatches, combos, expected = 0, 0, 0
	local function startLine(full)
		seed()
		ItemEquip.handle(player, "equip", 1) -- 갑옷 착용
		ItemEquip.handle(player, "equip", 1) -- 장갑 착용(가방 1번이 바뀌어 있다 - 무엇이든 착용되면 된다)
		if full then
			fillBagToFull()
		end
	end
	local function equippedTable()
		local result = {}
		for _, part in ipairs(EquipSlots.order) do
			result[part] = PlayerProfile.getEquipped(player, part)
		end
		return result
	end
	for _, full in ipairs({ false, true }) do
		startLine(full)
		local base = fingerprint(player)
		expected += (#bag + 2) + 4 -- 착용: 가방 칸 + 범위 밖 2 · 해제: 갑옷 · 장갑 · 신발 · 무기
		for index = 1, #bag + 2 do
			local predicted = Equip.equipBlockReason(bag, index, true)
			local success, reason = ItemEquip.handle(player, "equip", index)
			combos += 1
			if (predicted == nil) ~= success or (predicted ~= nil and predicted ~= reason) then
				mismatches += 1
			end
			startLine(full)
		end
		for _, part in ipairs({ "armor", "gloves", "shoes", "weapon" }) do
			local predicted = Equip.unequipBlockReason(equippedTable(), part, #bag, slots, true)
			local success, reason = ItemEquip.handle(player, "unequip", part)
			combos += 1
			if (predicted == nil) ~= success or (predicted ~= nil and predicted ~= reason) then
				mismatches += 1
			end
			startLine(full)
		end
		t.check(("가방 %s 출발선이 조합마다 같다(%d칸)"):format(full and "가득" or "여유", #bag), fingerprint(player) == base)
	end
	t.check(("미리 판정 = 서버 결과 %d/%d 조합"):format(combos - mismatches, combos), mismatches == 0 and combos == expected)

	env.restore(player)
	t.check("검증 뒤 프로필(가방 · 착용)이 원래대로 돌아왔다", fingerprint(player) == originalPrint)
	print(("===S20d 검증 끝(나)=== %d/%d 통과"):format(t.pass, t.total))
end

return ItemFlowVerify
