-- S20d 자체 점검 [S20d][UI] - 장비 빠른 장착(상세 [장착] / [해제] 버튼 · 이유 한 줄 · 거절 연출 · 요청 중 잠금 · 더블클릭 판정기) · 보석 자동 장착 미리보기 한 줄 · 폰 치수를 실제 인스턴스로 잰다.
-- Studio에서 DevToolsConfig.verify에 "S20d(UI)"가 있을 때만 돈다. 서버 없이 Store(S)에 가방 · 착용 상태를 직접 넣어 그린다(끝에서 원래 상태로 되돌린다). 요청을 실제로 보내는 시험은 하지 않는다 -
-- 요청 잠금은 send를 바꿔 끼운 ItemActions로 잰다(실제 EquipRequest가 나가면 서버 프로필이 바뀐다).
-- 마우스 입력(더블클릭 · 우클릭 · 호버 툴팁)은 못 한다 - 실제 마우스는 수동 Play(user_mouse_input)에서 본다(입력 층 결함은 자체 점검이 못 잡는다 - COMMON §2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20d(UI)")) then
	return
end

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Store = require(script.Parent.Store)
local ItemActions = require(script.Parent.ItemActions)
local TextAudit = require(script.Parent.Parent.Parent.ui.TextAudit)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local START_DELAY = 150 -- 창을 여는 다른 점검(S20(UI) 96초 · S20c(UI) 122초 + 약 25초)이 끝난 뒤
local INSET = 58
local TOUCH_MIN = 44
local SLOTS = SaveConfig.defaultInventorySlots

local function item(part, grade, itemLevel)
	return { grade = grade, part = part, dropStage = 1, itemLevel = itemLevel, tierIndex = 1, locked = false }
end

local function colorEq(a, b)
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

local function rect(inst)
	local p, s = inst.AbsolutePosition, inst.AbsoluteSize
	return { x0 = p.X, y0 = p.Y, x1 = p.X + s.X, y1 = p.Y + s.Y }
end

local function inside(inner, outer)
	return inner.x0 >= outer.x0 - 0.5 and inner.y0 >= outer.y0 - 0.5 and inner.x1 <= outer.x1 + 0.5 and inner.y1 <= outer.y1 + 0.5
end

local function overlaps(a, b)
	return a.x0 < b.x1 - 0.5 and b.x0 < a.x1 - 0.5 and a.y0 < b.y1 - 0.5 and b.y0 < a.y1 - 0.5
end

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20d][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20d(UI) 검증 시작(장비 [장착] / [해제] 버튼 · 이유 한 줄 · 거절 연출 · 요청 잠금 · 보석 교체 미리보기 · 폰 치수)===")

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("InventoryGui")
	local R = Store.R
	local gemTab = R and R.gemTab
	if not (gui and gemTab and Store.itemActions) then
		check("InventoryGui · R.gemTab · Store.itemActions를 못 찾음", false)
		print(("===S20d(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
		return
	end

	-- 원래 상태(끝에서 되돌린다)
	local saved = { inventory = Store.inventory, armor = Store.equippedArmor, gloves = Store.equippedGloves, shoes = Store.equippedShoes, classId = player:GetAttribute("ClassId") }
	local originalGemState = gemTab.state()
	if not saved.classId or saved.classId == "" then
		player:SetAttribute("ClassId", ClassData.order[1]) -- 이 클라에서만 보이는 값(서버에 안 간다) - 직업이 있어야 착용 판정이 열린다
	end
	player:SetAttribute("DebugGemNear", true)

	local function setState(inventory, armor)
		Store.inventory = inventory
		Store.equippedArmor, Store.equippedGloves, Store.equippedShoes = armor, nil, nil
		Store.rebuildGearSlots()
		Store.rebuildGrid()
	end
	local function bagOf(count)
		local bag = {}
		for index = 1, count do
			bag[index] = index == 1 and item("armor", "epic", 11) or item("gloves", "rare", 10 + index)
		end
		return bag
	end
	local function detailButtons()
		local found = {}
		for _, inst in ipairs(R.detail:GetDescendants()) do
			if inst:IsA("TextButton") and (inst.Text == "장착" or inst.Text == "해제") then
				table.insert(found, inst)
			end
		end
		return found
	end
	local function equipButton()
		return detailButtons()[1]
	end
	local function hintLabel()
		return R.detail:FindFirstChild("DetailHint")
	end
	local function select(kind, value)
		Store.selectedKind, Store.selectedValue = kind, value
		Store.refreshDetail()
		task.wait(0.15)
	end

	UIManager.open("inventory")
	task.wait(0.8)
	R.debugForceScreen(nil)
	task.wait(0.4)
	R.selectTab("장비")
	task.wait(0.3)

	-- ① PC: 가방 장비 선택 → [장착] 활성 · 이유 없음
	do
		setState(bagOf(4), nil)
		select("bag", 1)
		local button, hint = equipButton(), hintLabel()
		check(("PC 가방 장비 선택: [장착] 활성 · 이유 줄 없음 (글자 %s · Active %s · 이유 줄 %s)"):format(button and button.Text or "?", tostring(button and button.Active), tostring(hint and hint.Visible)),
			button ~= nil and button.Text == "장착" and button.Active and hint ~= nil and not hint.Visible)
	end

	-- ② PC: 착용 중 갑옷 선택 → [해제] · 가방 여유 → 활성 / 가방 가득 → 회색 + 이유 한 줄(빨강)
	do
		setState(bagOf(SLOTS - 1), item("armor", "relic", 20))
		select("equip", "armor")
		local button, hint = equipButton(), hintLabel()
		check(("PC 착용 중 갑옷 선택(가방 %d/%d): [해제] 활성 · 이유 줄 없음"):format(SLOTS - 1, SLOTS), button ~= nil and button.Text == "해제" and button.Active and not hint.Visible)

		setState(bagOf(SLOTS), item("armor", "relic", 20))
		select("equip", "armor")
		button, hint = equipButton(), hintLabel()
		local expected = ItemActions.reasonText("full")
		check(("PC 가방 가득(%d/%d)에서 갑옷 선택: [해제] 회색(Active %s) · 이유 \"%s\" · 빨강 %s"):format(SLOTS, SLOTS, tostring(button and button.Active), hint.Text, tostring(colorEq(hint.TextColor3, UIColors.danger))),
			button ~= nil and button.Text == "해제" and not button.Active and hint.Visible and hint.Text == expected and colorEq(hint.TextColor3, UIColors.danger))
		local dactRect = rect(button.Parent)
		local hintRect = rect(hint)
		check(("PC 이유 줄이 버튼 묶음 바로 위(아래끝 %d ≤ 묶음 위 %d) · 상세 바 안 · 글씨 실효 12 이상"):format(hintRect.y1, dactRect.y0),
			hintRect.y1 <= dactRect.y0 + 0.5 and inside(hintRect, rect(R.detail)) and #TextAudit.report(R.detail).low == 0)

		select("bag", 1)
		button, hint = equipButton(), hintLabel()
		check("PC 가방 가득이어도 가방 장비 [장착]은 활성(교체라 칸 수 불변) · 이유 줄 없음", button.Text == "장착" and button.Active and not hint.Visible)
	end

	-- ③ 거절 연출: 가방 가득에서 S.unequipToBag → 요청 안 나감(false) · 이유 토스트 · 유령이 오갔다가 사라진다
	do
		Toast.clear()
		setState(bagOf(SLOTS), item("armor", "relic", 20))
		select("equip", "armor")
		local sent = Store.unequipToBag("armor")
		task.wait(0.05)
		local ghost = R.screenGui:FindFirstChild("GemDragProxy")
		local texts = Toast.debugTexts("TC")
		check(("가방 가득에서 해제 입력: 요청 안 나감 %s · 이유 토스트 %s · 거절 유령 %s"):format(tostring(sent == false), texts[1] or "(없음)", tostring(ghost ~= nil)),
			sent == false and texts[1] == ItemActions.reasonText("full") and ghost ~= nil)
		task.wait(GemData.ui.returnTweenSeconds + 0.4)
		check("거절 유령이 원래 칸으로 돌아간 뒤 사라진다", R.screenGui:FindFirstChild("GemDragProxy") == nil)
		Toast.clear()
	end

	-- ④ 연출 좌표: PC에서는 장비 칸 · 가방 칸 · 가방 영역이 모두 보인다(폰의 다른 탭이면 nil)
	do
		setState(bagOf(4), item("armor", "relic", 20))
		task.wait(0.2)
		check("PC 연출 좌표: 갑옷 칸 · 가방 1번 칸 · 가방 영역 중심이 있다", Store.gearSlotCenter("armor") ~= nil and Store.bagCellCenter(1) ~= nil and Store.bagAreaCenter() ~= nil)
	end

	-- ⑤ 요청 중 입력 잠금(send를 바꿔 끼운 ItemActions - 실제 요청은 안 나간다)
	do
		local sentCount, doneCount = 0, 0
		local state = { inventory = bagOf(4), equipped = { armor = item("armor", "relic", 20) }, slots = SLOTS }
		local stub = ItemActions.create({
			screenGui = R.screenGui,
			getState = function()
				return state
			end,
			hasClass = function()
				return true
			end,
			onPending = function()
				doneCount += 1
			end,
			onDone = function() end,
			send = function()
				sentCount += 1
			end,
		})
		local first = stub.equip(1, {})
		local second = stub.equip(2, {})
		local third = stub.unequip("armor", {})
		local canEquip, why = stub.canEquip(2)
		check(("요청 중 잠금: 첫 입력 요청 %s · 연타 2개 무시 %s · 요청 %d번 · 요청 중 [장착] 불가 이유 %s"):format(tostring(first), tostring(second == false and third == false), sentCount, tostring(why)),
			first == true and second == false and third == false and sentCount == 1 and canEquip == false and why == "busy" and stub.isPending())
		task.wait(GemData.ui.resultTimeoutSeconds + 0.4)
		check("결과가 안 와도 대기 한도(resultTimeoutSeconds) 뒤에는 잠금이 풀리고 다시 요청할 수 있다", not stub.isPending() and stub.equip(2, {}) == true and sentCount == 2)
		task.wait(GemData.ui.resultTimeoutSeconds + 0.4)
	end

	-- ⑥ 더블클릭 판정기: 0.35초 안의 같은 대상 = 더블 · 판정 뒤 세 번째는 아님 · 다른 대상 · 시간 초과는 아님
	do
		local tracker = ItemActions.doubleClickTracker()
		local first = tracker("armor")
		local second = tracker("armor")
		local third = tracker("armor")
		local other = tracker("gloves")
		local otherAgain = tracker("shoes")
		task.wait(GemData.ui.doubleClickSeconds + 0.1)
		local late1, late2 = tracker("shoes"), tracker("shoes")
		check(("더블클릭 판정기: 첫 %s · 두 번째(더블) %s · 세 번째 %s · 다른 대상 %s · 시간 초과 %s"):format(tostring(first), tostring(second), tostring(third), tostring(other or otherAgain), tostring(late1)),
			first == false and second == true and third == false and other == false and otherAgain == false and late1 == false and late2 == true)
	end

	-- ⑦ 보석 자동 장착 미리보기 한 줄(상세 시트 [장착] 위): 밀려날 보석 글 · 빈 홈이면 없음 · 멀면 없음
	do
		local function gemOf(grade, itemLevel)
			return { grade = grade, itemLevel = itemLevel }
		end
		local function gemState(gems)
			return { gems = gems, slotUnlocked = { true, true, true, true, false }, gemInventory = { gemOf("epic", 11), gemOf("legendary", 12) }, rerollTickets = { ancient = 0, primordial = 0 } }
		end
		R.selectTab("보석")
		task.wait(0.3)
		gemTab.debugApply(gemState({ gemOf("primordial", 25), gemOf("epic", 26), gemOf("legendary", 27), gemOf("relic", 28), false }))
		task.wait(0.3)
		select("gemBag", 1) -- 영웅 보석 → 자동 대상 2번 홈(영웅 26)
		local hint = hintLabel()
		local text = hint.Text
		check(("보석 [장착] 위 한 줄: \"%s\" (교체될 보석 · 영웅 · 2번 홈 · 표시 %s - 시험 보석은 옵션이 없어 제목에 Lv가 안 붙는다)"):format(text, tostring(hint.Visible)),
			hint.Visible and text:find("교체될 보석:", 1, true) ~= nil and text:find("(2번 홈)", 1, true) ~= nil and text:find("영웅", 1, true) ~= nil and colorEq(hint.TextColor3, UIColors.textSecondary))
		gemTab.debugApply(gemState({ gemOf("primordial", 25), false, gemOf("legendary", 27), gemOf("relic", 28), false }))
		task.wait(0.3)
		select("gemBag", 1)
		check("자동 대상 홈이 비어 있으면(교체 없음) 한 줄이 안 보인다", not hintLabel().Visible)
		gemTab.debugApply(gemState({ gemOf("primordial", 25), gemOf("epic", 26), gemOf("legendary", 27), gemOf("relic", 28), false }))
		player:SetAttribute("DebugGemNear", false)
		task.wait(0.7)
		select("gemBag", 1)
		check("강화대에서 멀어 [장착]이 회색이면 미리보기 줄도 없다", not equipButton().Active and not hintLabel().Visible)
		player:SetAttribute("DebugGemNear", true)
		task.wait(0.7)
		select("gemBag", 1)
	end

	-- ⑧ 폰 800 × 360 · 667 × 375 · 842 × 388: 상세 시트의 [장착] / [해제] 터치 44 · 이유 줄 · 미리보기 줄이 시트 안 · 버튼 묶음과 안 겹침 · 글씨 실효 12 이상
	for _, size in ipairs({ { 800, 360 }, { 667, 375 }, { 842, 388 } }) do
		R.debugForceScreen(Vector2.new(size[1], size[2] - INSET))
		task.wait(0.4)
		R.selectTab("장비")
		task.wait(0.3)
		local notes, allOk = {}, true
		local function probe(label, kind, value, wantHint)
			select(kind, value)
			task.wait(0.15)
			local button, hint = equipButton(), hintLabel()
			local detailRect = rect(R.detail)
			local winRect = rect(R.win)
			local ok = button ~= nil and button.AbsoluteSize.X >= TOUCH_MIN - 0.5 and button.AbsoluteSize.Y >= TOUCH_MIN - 0.5 and R.detail.Visible and inside(detailRect, winRect)
			local hintOk = true
			if wantHint then
				local hintRect = rect(hint)
				hintOk = hint.Visible and inside(hintRect, detailRect) and hintRect.y1 <= rect(button.Parent).y0 + 0.5 and (not R.sheetClose.Visible or not overlaps(hintRect, rect(R.sheetClose)))
			end
			local report = TextAudit.report(R.detail)
			ok = ok and hintOk and #report.low == 0
			allOk = allOk and ok
			table.insert(notes, ("%s %s"):format(label, ok and "O" or "X"))
		end
		setState(bagOf(SLOTS), item("armor", "relic", 20))
		probe("[해제] 회색 + 이유", "equip", "armor", true)
		probe("[장착](가득이어도 활성)", "bag", 1, false)
		R.selectTab("보석")
		task.wait(0.3)
		gemTab.debugApply({ gems = { { grade = "primordial", itemLevel = 25 }, { grade = "epic", itemLevel = 26 }, { grade = "legendary", itemLevel = 27 }, { grade = "relic", itemLevel = 28 }, false }, slotUnlocked = { true, true, true, true, false },
			gemInventory = { { grade = "epic", itemLevel = 11 } }, rerollTickets = { ancient = 0, primordial = 0 } })
		task.wait(0.3)
		probe("보석 [장착] + 미리보기", "gemBag", 1, true)
		local scales = 0
		for _, inst in ipairs(R.detail:GetDescendants()) do
			if inst:IsA("UIScale") then
				scales += 1
			end
		end
		check(("폰 %d × %d: 상세 시트 %s · UIScale %d개"):format(size[1], size[2], table.concat(notes, " · "), scales), allOk and scales == 0)
	end

	-- 정리: 원래 상태 · 화면 · 창으로
	player:SetAttribute("DebugGemNear", nil)
	player:SetAttribute("ClassId", saved.classId)
	Store.selectedKind, Store.selectedValue = nil, nil
	gemTab.debugApply(originalGemState)
	R.debugForceScreen(nil)
	task.wait(0.3)
	setState(saved.inventory, saved.armor)
	Store.equippedGloves, Store.equippedShoes = saved.gloves, saved.shoes
	Store.rebuildGearSlots()
	R.selectTab("장비")
	UIManager.close("inventory")
	Toast.clear()
	task.wait(0.5)
	print(("===S20d(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20d][UI] 점검 에러: " .. tostring(err))
		player:SetAttribute("DebugGemNear", nil)
		UIManager.close("inventory", true)
	end
end)
