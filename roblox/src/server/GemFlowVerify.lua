-- S20c 자동 검증(서버) - 보석 장착 입력 재구성이 기대는 서버 규칙 · 미리 판정.
--   runPure()        (가) 순수 함수: Gem.autoSlot · Gem.socketBlockReason · Gem.displayOrder (플레이어 불필요)
--   runLive(player, env)  (나) 실제 Player · 실제 프로필: GemEquip.handle의 이유 코드 6종 · 교체 규칙(기존 보석은 보석칸 맨 끝으로 · 보석칸 수 불변 · 해제 함수 없음) · 클라 미리 판정(Gem.socketBlockReason)과 서버 결과가
--                    5홈 × 6보석 전 조합에서 같은가 · 자동 장착 대상을 서버가 받는가. 끝에서 프로필을 원래대로 되돌린다(env.restore).
--   seed(player)     테스트 상태를 프로필에 넣는다(홈 1 ~ 4 열림 · 채움, 홈 5 잠김 · 보석칸 6개) - (나)와 `/gg gemflow`(수동 Play)가 함께 쓴다.
-- 서버 규칙은 이 세션에서 바뀌지 않는다(장착 = 항상 교체 · 해제 없음). 이 검증이 그 규칙을 못 박는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local PlayerProfile = require(script.Parent.PlayerProfile)
local GemSync = require(script.Parent.GemSync)
local GemEquip = require(script.Parent.GemEquip)
local GemMerchantAccess = require(script.Parent.GemMerchantAccess)

local GemFlowVerify = {}

-- 시험 상태: 홈 1 ~ 4는 열려 있고 그 상한 등급 보석으로 채워져 있다(홈이 열리는 순간 자동 지급되는 실제 규칙 그대로) · 홈 5는 잠김.
local SEED_UNLOCKED = { true, true, true, true, false }
local SEED_SLOT_ITEM_LEVEL = 25
-- 보석칸(서버 index 1 ~ 6): itemLevel로 어느 보석인지 구별한다.
local SEED_INVENTORY = {
	{ grade = "epic", itemLevel = 11 },
	{ grade = "legendary", itemLevel = 12 },
	{ grade = "primordial", itemLevel = 13 },
	{ grade = "relic", itemLevel = 14 },
	{ grade = "epic", itemLevel = 15 },
	{ grade = "ancient", itemLevel = 16 },
}

local function tally(label)
	local self = { pass = 0, total = 0 }
	function self.check(name, ok)
		self.total += 1
		if ok then
			self.pass += 1
		end
		print(("[S20c][%s] %s %s"):format(label, name, ok and "O" or "X"))
	end
	return self
end

function GemFlowVerify.seed(player)
	if not PlayerProfile.getWeapon(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	local weapon = PlayerProfile.getWeapon(player)
	for slot = 1, Gem.slotCount do
		weapon.slotUnlocked[slot] = SEED_UNLOCKED[slot]
		weapon.gems[slot] = SEED_UNLOCKED[slot] and { grade = Gem.gradeCapForSlot(slot), itemLevel = SEED_SLOT_ITEM_LEVEL } or false
	end
	local inventory = PlayerProfile.getGemInventory(player)
	for index = #inventory, 1, -1 do
		table.remove(inventory, index)
	end
	for _, gem in ipairs(SEED_INVENTORY) do
		table.insert(inventory, { grade = gem.grade, itemLevel = gem.itemLevel })
	end
	GemSync.push(player)
end

local function fingerprint(player)
	local weapon = PlayerProfile.getWeapon(player)
	local parts = {}
	for slot = 1, Gem.slotCount do
		local gem = weapon.gems[slot]
		table.insert(parts, type(gem) == "table" and (gem.grade .. ":" .. tostring(gem.itemLevel)) or "-")
	end
	table.insert(parts, "|")
	for _, gem in ipairs(PlayerProfile.getGemInventory(player)) do
		table.insert(parts, gem.grade .. ":" .. tostring(gem.itemLevel))
	end
	return table.concat(parts, ",")
end

-- ═══ (가) 순수 함수 ═══
function GemFlowVerify.runPure()
	print("===S20c 검증 시작(가: 자동 장착 대상 · 미리 판정 사유 · 표시 순서)===")
	local t = tally("가")
	local all5, u12, none = { true, true, true, true, true }, { true, true, false, false, false }, { false, false, false, false, false }
	local full = { { grade = "x" }, { grade = "x" }, { grade = "x" }, { grade = "x" }, { grade = "x" } }
	t.check("영웅 보석 -> 2번(상한 영웅 - 가장 낮은 홈)", Gem.autoSlot(all5, full, "epic") == 2)
	t.check("전설 보석 -> 3번", Gem.autoSlot(all5, full, "legendary") == 3)
	t.check("유물 보석 -> 4번", Gem.autoSlot(all5, full, "relic") == 4)
	t.check("고대 보석 -> 5번", Gem.autoSlot(all5, full, "ancient") == 5)
	t.check("태초 보석 -> 1번(태초를 받는 홈은 1번뿐)", Gem.autoSlot(all5, full, "primordial") == 1)
	t.check("홈 1 · 2만 열림 + 전설 보석 -> 1번", Gem.autoSlot(u12, full, "legendary") == 1)
	local noSlot, noReason = Gem.autoSlot(none, full, "epic")
	t.check("열린 홈 없음 -> nil + no_slot_open", noSlot == nil and noReason == "no_slot_open")
	local tooHigh, tooHighReason = Gem.autoSlot({ false, true, false, false, false }, full, "primordial")
	t.check("열린 홈이 받지 못함 -> nil + grade_too_high", tooHigh == nil and tooHighReason == "grade_too_high")
	t.check("빈 홈 우선: 4번이 비어 있으면 전설 보석도 4번", Gem.autoSlot(all5, { full[1], full[2], full[3], false, full[5] }, "legendary") == 4)
	t.check("잠긴 홈 -> slot_locked", Gem.socketBlockReason(u12, 3, "epic") == "slot_locked")
	t.check("영웅 상한 홈에 전설 -> grade_too_high", Gem.socketBlockReason(all5, 2, "legendary") == "grade_too_high")
	t.check("가능하면 nil", Gem.socketBlockReason(all5, 1, "primordial") == nil)
	local consistent = true
	for slot = 1, Gem.slotCount do
		for _, grade in ipairs({ "epic", "legendary", "relic", "ancient", "primordial" }) do
			if (Gem.socketBlockReason(all5, slot, grade) == nil) ~= Gem.canSocket(grade, slot) then
				consistent = false
			end
		end
	end
	t.check("미리 판정이 Gem.canSocket과 5홈 × 5등급에서 같다", consistent)
	local inventory = { { grade = "epic" }, { grade = "primordial" }, { grade = "epic" }, { grade = "ancient" }, { grade = "primordial" } }
	t.check("표시 순서 = 등급 높은 순 · 같은 등급은 획득 순", table.concat(Gem.displayOrder(inventory), ",") == "2,5,4,1,3")
	t.check("표시 순서가 원본을 바꾸지 않는다", inventory[1].grade == "epic" and inventory[2].grade == "primordial")
	print(("===S20c 검증 끝(가)=== %d/%d 통과"):format(t.pass, t.total))
end

-- ═══ (나) 실제 Player ═══
function GemFlowVerify.runLive(player, env)
	print("===S20c 검증 시작(나: 실제 프로필 - 이유 코드 · 교체 규칙 · 미리 판정 = 서버)===")
	local t = tally("나")
	env.ensureBackup(player)
	if not PlayerProfile.getWeapon(player) then
		PlayerProfile.setClassId(player, ClassData.order[1]) -- 직업을 아직 안 골랐으면 첫 직업(백업이 복원한다)
	end
	local originalPrint = fingerprint(player) -- 시험 전 원본(복원 확인용)
	GemFlowVerify.seed(player)
	local weapon = PlayerProfile.getWeapon(player)
	local inventory = PlayerProfile.getGemInventory(player)
	local seededPrint = fingerprint(player)

	t.check("시험 상태 적용: 보석칸 6 · 홈 1 ~ 4 열림 · 홈 5 잠김", #inventory == 6 and weapon.slotUnlocked[4] == true and weapon.slotUnlocked[5] == false and weapon.gems[5] == false)

	local ok2, why2 = GemEquip.handle(player, "x", 1)
	t.check("인자 모양이 틀리면 invalid", ok2 == false and why2 == "invalid")
	local ok3, why3 = GemEquip.handle(player, 5, 1)
	t.check("잠긴 홈 -> slot_locked + 상태 불변", ok3 == false and why3 == "slot_locked" and fingerprint(player) == seededPrint)
	local ok4, why4 = GemEquip.handle(player, 2, 99)
	t.check("없는 보석 -> not_found + 상태 불변", ok4 == false and why4 == "not_found" and fingerprint(player) == seededPrint)
	local ok5, why5 = GemEquip.handle(player, 2, 2)
	t.check("영웅 상한 홈에 전설 보석 -> grade_too_high + 상태 불변", ok5 == false and why5 == "grade_too_high" and fingerprint(player) == seededPrint)

	-- 교체 규칙: 홈 2(영웅 상한 · 25)에 보석칸 1번(영웅 · 11)을 끼운다 -> 기존 보석은 보석칸 맨 끝으로
	local inMerchantRange = GemMerchantAccess.check(player) -- S20e: 이 검증 캐릭터는 보석상인 반경 밖이다(장착은 자리와 무관해야 한다)
	local ok6, why6 = GemEquip.handle(player, 2, 1)
	local last = inventory[#inventory]
	t.check(("정상 장착 -> 성공 + 이유 없음(S20e: 보석상인 · 강화대 반경 밖에서도 성공 - 반경 안 %s)"):format(tostring(inMerchantRange)), ok6 == true and why6 == nil and inMerchantRange == false)
	t.check("홈 2가 새 보석(itemLevel 11)으로 바뀌었다", weapon.gems[2].itemLevel == 11 and weapon.gems[2].grade == "epic")
	t.check("기존 보석(itemLevel 25)이 보석칸 맨 끝으로 돌아왔다(옵션 · itemLevel 그대로)", last.itemLevel == SEED_SLOT_ITEM_LEVEL and last.grade == "epic")
	t.check("보석칸 수 불변(6) · 나머지 index가 하나씩 당겨졌다(1번 = 전설 12)", #inventory == 6 and inventory[1].itemLevel == 12)
	local allFilled = true
	for slot = 1, 4 do
		allFilled = allFilled and Gem.isFilled(weapon.gems, slot)
	end
	t.check("열린 홈은 여전히 전부 채워져 있다(빈 홈이 안 생긴다)", allFilled)
	t.check("서버에 해제 함수가 없다(PlayerProfile.unequipGem == nil) - 해제는 이번 세션 범위 밖", PlayerProfile.unequipGem == nil)

	-- 미리 판정(shared/Gem.socketBlockReason)이 서버 결과와 5홈 × 6보석 전 조합에서 같은가
	local mismatches, combos = 0, 0
	for slot = 1, Gem.slotCount do
		for index = 1, #SEED_INVENTORY do
			GemFlowVerify.seed(player)
			local gem = inventory[index]
			local predicted = Gem.socketBlockReason(weapon.slotUnlocked, slot, gem.grade)
			local success, reason = GemEquip.handle(player, slot, index)
			combos += 1
			if (predicted == nil) ~= success or (predicted ~= nil and predicted ~= reason) then
				mismatches += 1
			end
		end
	end
	t.check(("미리 판정 = 서버 결과 %d/%d 조합"):format(combos - mismatches, combos), mismatches == 0 and combos == 30)

	-- 자동 장착 대상을 서버가 실제로 받는가(6개 보석 전부)
	local autoBad, autoCount = 0, 0
	for index = 1, #SEED_INVENTORY do
		GemFlowVerify.seed(player)
		local gem = inventory[index]
		local slot = Gem.autoSlot(weapon.slotUnlocked, weapon.gems, gem.grade)
		if slot then
			autoCount += 1
			local success = GemEquip.handle(player, slot, index)
			if not success then
				autoBad += 1
			end
		end
	end
	t.check(("자동 장착 대상을 서버가 받는다 %d/%d(홈 5 잠김이라 고대 보석은 1번 태초 홈)"):format(autoCount - autoBad, autoCount), autoBad == 0 and autoCount == 6)

	env.restore(player)
	GemSync.push(player) -- 복원(DevTools)은 클라 스냅샷을 밀지 않는다 - 안 밀면 같은 Play의 클라 점검(S20 보석 탭 칸 수 · S20c)이 시험 상태의 옛 보석칸을 계속 본다
	t.check("검증 뒤 프로필(홈 · 보석칸)이 원래대로 돌아왔다", fingerprint(player) == originalPrint)
	print(("===S20c 검증 끝(나)=== %d/%d 통과"):format(t.pass, t.total))
end

return GemFlowVerify
