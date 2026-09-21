-- S20c 자체 점검 [S20c][UI] - 보석 홈 표현(잠김 · 채움 · 열린 빈 홈 + 끼울 수 있음 · 없음 · 선택 표시) · 보석칸 정렬 · NEW · 강화대 상태 · [장착] 버튼 · 폰 치수를 실제 인스턴스로 잰다.
-- Studio에서 DevToolsConfig.verify에 "S20c(UI)"가 있을 때만 돈다. 서버 없이 R.gemTab.debugApply로 보석 상태를 넣어 그린다(끝에서 원래 상태로 되돌린다).
-- 클릭 · 드래그 · 더블클릭 · 우클릭은 못 한다 - 실제 마우스 입력은 수동 Play(user_mouse_input)에서 본다(입력 층 결함은 자체 점검이 못 잡는다 - COMMON §2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20c(UI)")) then
	return
end

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Store = require(script.Parent.Store)
local GemActions = require(script.Parent.GemActions)
local TextAudit = require(script.Parent.Parent.Parent.ui.TextAudit)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local START_DELAY = 122 -- 창을 여는 다른 점검(S12(UI) · S12b(UI) · S20(UI) 보석 탭 78초 · 장비창 96초)이 끝난 뒤
local INSET = 58
local TOUCH_MIN = 44

local function colorEq(a, b)
	return math.abs(a.R - b.R) < 0.01 and math.abs(a.G - b.G) < 0.01 and math.abs(a.B - b.B) < 0.01
end

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20c][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20c(UI) 검증 시작(보석 홈 표현 · 정렬 · NEW · 변환 · 리롤 안내 줄 · 폰 치수)===")

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("InventoryGui")
	local R = Store.R
	local gemTab = R and R.gemTab
	if not (gui and gemTab) then
		check("InventoryGui · R.gemTab을 못 찾음", false)
		print(("===S20c(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
		return
	end
	local gemBody = gemTab.frame
	local originalState = gemTab.state()

	-- 시험 상태: 홈 1 ~ 3 채움(태초 · 영웅 · 전설 상한) · 4 · 5 잠김 · 보석칸 5개(영웅 · 전설 · 태초 · 유물 · 영웅)
	local function gemOf(grade, itemLevel)
		return { grade = grade, itemLevel = itemLevel }
	end
	local function state(gems, unlocked, inventory)
		return { gems = gems, slotUnlocked = unlocked, gemInventory = inventory, rerollTickets = { ancient = 0, primordial = 0 } }
	end
	local function inventory5()
		return { gemOf("epic", 11), gemOf("legendary", 12), gemOf("primordial", 13), gemOf("relic", 14), gemOf("epic", 15) }
	end
	local stateA = state({ gemOf("primordial", 25), gemOf("epic", 25), gemOf("legendary", 25), false, false }, { true, true, true, false, false }, inventory5())

	UIManager.open("inventory")
	task.wait(0.8)
	R.debugForceScreen(Vector2.new(800, 360 - INSET)) -- 폰 800 × 360(ScreenGui 800 × 302)
	task.wait(0.4)
	R.selectTab("보석")
	task.wait(0.3)
	Store.selectedKind, Store.selectedValue = nil, nil
	gemTab.debugApply(stateA)
	task.wait(0.3)
	R.selectTab("장비") -- 이 탭을 한 번 보고 떠났다 = 지금 보석칸은 전부 "본 것"(NEW 없음)에서 시작한다
	task.wait(0.2)
	R.selectTab("보석")
	task.wait(0.3)

	local function chip(slot)
		return gemBody:FindFirstChild("Socket" .. slot, true)
	end
	local function strokeColor(inst)
		local stroke = inst and inst:FindFirstChildOfClass("UIStroke")
		return stroke and stroke.Color
	end
	local function visibleChild(inst, name)
		local child = inst and inst:FindFirstChild(name)
		return child ~= nil and child.Visible
	end

	-- ① 홈 3상태: 잠김 · 채움(등급 색 테두리 + 안쪽 음영 + 보석 원) · 열린 빈 홈(홈 등급 색 테두리 + 음영, 보석 원 없음)
	do
		local filledOk, notes = true, {}
		for slot = 1, 3 do
			local c = chip(slot)
			local gradeColor = GemActions.gradeColor(stateA.gems[slot].grade)
			local dot = c and c:FindFirstChild("Gem")
			local ok = c ~= nil and visibleChild(c, "Well") and visibleChild(c, "Gem") and not visibleChild(c, "Lock")
				and dot ~= nil and colorEq(dot.BackgroundColor3, gradeColor) and strokeColor(c) ~= nil and colorEq(strokeColor(c), gradeColor)
			filledOk = filledOk and ok
			table.insert(notes, ("홈%d %s"):format(slot, ok and "O" or "X"))
		end
		check("채워진 홈 3개: 안쪽 음영 · 보석 원(등급 색) · 등급 색 테두리 - " .. table.concat(notes, " "), filledOk)
		local lockedOk = true
		for slot = 4, 5 do
			local c = chip(slot)
			lockedOk = lockedOk and c ~= nil and visibleChild(c, "Lock") and not visibleChild(c, "Well") and not visibleChild(c, "Gem")
		end
		check("잠긴 홈 2개(4 · 5): 자물쇠만 · 음영 · 보석 없음", lockedOk)
		gemTab.debugApply(state({ gemOf("primordial", 25), gemOf("epic", 25), false, false, false }, { true, true, true, false, false }, inventory5()))
		task.wait(0.2)
		local c3 = chip(3)
		local capColor = GemActions.gradeColor(Gem.gradeCapForSlot(3))
		check("열린 빈 홈(홈 3 - 옛 개발 계정에만 생김): 홈 등급(전설) 색 테두리 · 음영 · 보석 원 없음",
			c3 ~= nil and visibleChild(c3, "Well") and not visibleChild(c3, "Gem") and not visibleChild(c3, "Lock") and colorEq(strokeColor(c3), capColor))
		gemTab.debugApply(stateA)
		task.wait(0.2)
	end

	-- ② 보석칸 정렬(등급 높은 순 · 같은 등급은 획득 순) · 서버 index는 셀 이름에 그대로
	do
		local cells = {}
		for _, inst in ipairs(gemBody:GetDescendants()) do
			if inst:IsA("TextButton") and inst.Name:match("^GemCell%d+$") then
				table.insert(cells, inst)
			end
		end
		table.sort(cells, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		local names = {}
		for _, cell in ipairs(cells) do
			table.insert(names, cell.Name)
		end
		check(("보석칸 표시 순서 = 태초 · 유물 · 전설 · 영웅 · 영웅(서버 index 3 · 4 · 2 · 1 · 5): %s"):format(table.concat(names, ",")), table.concat(names, ",") == "GemCell3,GemCell4,GemCell2,GemCell1,GemCell5")
	end

	-- ③ 보석 먼저: 전설 보석(index 2)을 고르면 끼울 수 있는 홈(1 · 3)은 강조 · 나머지(2 영웅 상한 · 4 · 5 잠김)는 어둡게 + ×
	do
		Store.selectedKind, Store.selectedValue = "gemBag", 2
		gemTab.debugPaint()
		task.wait(0.2)
		local expectOk = { [1] = true, [3] = true }
		local marksOk, notes = true, {}
		for slot = 1, 5 do
			local c = chip(slot)
			local dimmed = visibleChild(c, "Dimmer")
			local okStroke = strokeColor(c) ~= nil and colorEq(strokeColor(c), UIColors.success)
			local good = expectOk[slot] and (okStroke and not dimmed) or (not expectOk[slot] and dimmed)
			marksOk = marksOk and good
			table.insert(notes, ("홈%d %s"):format(slot, expectOk[slot] and (good and "강조" or "강조X") or (good and "어둡게" or "어둡게X")))
		end
		check("전설 보석 선택 → " .. table.concat(notes, " "), marksOk)
		-- 선택한 셀에 강조 링
		local ring = gemBody:FindFirstChild("GemCell2", true) and gemBody:FindFirstChild("GemCell2", true):FindFirstChild("Ring")
		check("선택한 보석 셀에 링", ring ~= nil and ring.Visible)
	end

	-- ④ 홈 먼저: 영웅 상한 홈 2를 고르면 보석칸에서 영웅(1 · 5)만 밝게 · 나머지(전설 · 태초 · 유물)는 어둡게
	do
		gemTab.debugArm(2)
		task.wait(0.2)
		local expectOk = { [1] = true, [5] = true }
		local ok, notes = true, {}
		for index = 1, 5 do
			local cell = gemBody:FindFirstChild("GemCell" .. index, true)
			local dimmer = cell and cell:FindFirstChild("Dimmer")
			local ring = cell and cell:FindFirstChild("Ring")
			local good = cell ~= nil and ((expectOk[index] and ring.Visible and not dimmer.Visible) or (not expectOk[index] and dimmer.Visible))
			ok = ok and good
			table.insert(notes, ("%d번 %s"):format(index, good and "O" or "X"))
		end
		local chip2Selected = strokeColor(chip(2)) ~= nil and colorEq(strokeColor(chip(2)), UIColors.ember)
		check("홈 2 고름 → 밝은 보석 = 영웅 2개만 · 홈 2에 선택 표시 - " .. table.concat(notes, " "), ok and chip2Selected)
		Store.selectedKind, Store.selectedValue = nil, nil
		gemTab.debugPaint()
	end

	-- ⑤ NEW: 분해로 보석이 늘면(보석칸 맨 끝) NEW · 이 탭을 떠났다 돌아오면 사라진다 · 탭이 안 보일 때 늘면 "보석 획득 [보석 탭 열기]" 토스트
	do
		local grown = inventory5()
		table.insert(grown, gemOf("legendary", 16))
		gemTab.debugApply(state(stateA.gems, stateA.slotUnlocked, grown))
		task.wait(0.2)
		local newCell = gemBody:FindFirstChild("GemCell6", true)
		local oldCell = gemBody:FindFirstChild("GemCell1", true)
		check("탭이 보이는 동안 새로 늘어난 보석(6번)에 NEW · 기존 보석에는 없음",
			newCell ~= nil and newCell:FindFirstChild("NewBadge").Visible and oldCell ~= nil and not oldCell:FindFirstChild("NewBadge").Visible)
		R.selectTab("장비")
		task.wait(0.2)
		R.selectTab("보석")
		task.wait(0.3)
		newCell = gemBody:FindFirstChild("GemCell6", true)
		check("탭을 떠났다 돌아오면 NEW가 사라진다(한 번 보면 사라짐)", newCell ~= nil and not newCell:FindFirstChild("NewBadge").Visible)

		Toast.clear()
		R.selectTab("장비")
		task.wait(0.2)
		local grown2 = {}
		for _, gem in ipairs(grown) do
			table.insert(grown2, gem)
		end
		table.insert(grown2, gemOf("epic", 17))
		gemTab.debugApply(state(stateA.gems, stateA.slotUnlocked, grown2))
		task.wait(0.3)
		local texts = Toast.debugTexts("TC")
		check(("탭이 안 보일 때 보석이 늘면 토스트 \"보석 획득 [보석 탭 열기]\": %s"):format(table.concat(texts, " / ")), #texts == 1 and texts[1]:find("보석 획득", 1, true) ~= nil and texts[1]:find("[보석 탭 열기]", 1, true) ~= nil)
		Toast.clear()
		R.selectTab("보석")
		task.wait(0.3)
		gemTab.debugApply(stateA)
		task.wait(0.2)
	end

	-- ⑥ S20e: 변환 · 리롤 안내 줄(안 써 봤다 = 눈에 띄는 [위치 안내] 줄 · 써 본 뒤 = 작은 회색 줄 + ? 도움말) + 상세 [장착] 버튼은 자리와 무관하게 활성(강화대 제한 제거)
	do
		local function equipButton()
			for _, inst in ipairs(gui:GetDescendants()) do
				if inst:IsA("TextButton") and inst.Text == "장착" then
					return inst
				end
			end
			return nil
		end
		local guide = gemBody:FindFirstChild("GuideLine")
		local small = gemBody:FindFirstChild("GuideLineSmall")
		local help = gemBody:FindFirstChild("HelpToggle")
		local originalUsed = player:GetAttribute("GemMerchantUsed")
		player:SetAttribute("GemMerchantUsed", false)
		task.wait(0.4)
		local unusedOk = guide ~= nil and guide.Visible and guide.Active and guide.AbsoluteSize.Y >= 26 and guide.Text:find("위치 안내", 1, true) ~= nil and guide.Text:find("보석상인", 1, true) ~= nil
			and colorEq(guide.TextColor3, UIColors.gold) and (help == nil or not help.Visible) and (small == nil or not small.Visible)
		check(("안내 줄(안 써 봤다): 눈에 띄는 버튼 %s(높이 %d · \"%s\") · ? 없음"):format(tostring(unusedOk), guide and guide.AbsoluteSize.Y or -1, guide and guide.Text or "?"), unusedOk)
		local unusedHeight = guide and guide.AbsoluteSize.Y or 0
		player:SetAttribute("GemMerchantUsed", true)
		task.wait(0.4)
		local usedOk = guide ~= nil and not guide.Visible and small ~= nil and small.Visible and small.AbsoluteSize.Y <= unusedHeight and small.Text:find("보석상인", 1, true) ~= nil
			and colorEq(small.TextColor3, UIColors.textTertiary) and help ~= nil and help.Visible
		check(("안내 줄(써 봤다): 작은 회색 글 한 줄 %s(높이 %d ≤ 버튼 %d) · ? 도움말 있음 %s · 버튼은 숨음"):format(tostring(usedOk), small and small.AbsoluteSize.Y or -1, unusedHeight, tostring(help ~= nil and help.Visible)), usedOk)
		-- 폰 800 × 360에서도 써 본 상태의 ? 도움말은 터치 44 · 작은 회색 줄은 버튼이 아니다(눈에 띄는 줄 버튼은 숨음)
		R.debugForceScreen(Vector2.new(800, 360 - INSET))
		task.wait(0.5)
		local phoneSmall = gemBody:FindFirstChild("GuideLineSmall")
		local phoneHelp = gemBody:FindFirstChild("HelpToggle")
		check(("안내 줄(써 봤다) 폰 800 × 360: ? 도움말 %d × %d(기대 44 이상) · 글 줄 버튼 아님 %s · 눈에 띄는 줄 버튼 숨음 %s"):format(phoneHelp and phoneHelp.AbsoluteSize.X or -1, phoneHelp and phoneHelp.AbsoluteSize.Y or -1, tostring(phoneSmall ~= nil and phoneSmall:IsA("TextLabel")), tostring(guide ~= nil and not guide.Visible)),
			phoneHelp ~= nil and phoneHelp.AbsoluteSize.X >= TOUCH_MIN - 0.5 and phoneHelp.AbsoluteSize.Y >= TOUCH_MIN - 0.5 and phoneSmall ~= nil and phoneSmall:IsA("TextLabel") and guide ~= nil and not guide.Visible)
		R.debugForceScreen(nil)
		task.wait(0.4)
		Store.selectedKind, Store.selectedValue = "gemBag", 1
		Store.refreshDetail()
		task.wait(0.3)
		local button = equipButton()
		check(("상세 [장착] 버튼: 강화대 · 보석상인 근처가 아니어도 활성 %s(자리 제한 없음)"):format(tostring(button ~= nil and button.Active)), button ~= nil and button.Active)
		player:SetAttribute("GemMerchantUsed", originalUsed)
		Store.selectedKind, Store.selectedValue = nil, nil
		task.wait(0.4)
	end

	-- ⑦ 폰 800 × 360 · 667 × 375 · 842 × 388: 홈 칩 터치 44 이상 · 보석 셀 · 행 버튼 · 글씨 실효 12 이상 · 폭 안 · UIScale 0
	for _, size in ipairs({ { 800, 360 }, { 667, 375 }, { 842, 388 } }) do
		R.debugForceScreen(Vector2.new(size[1], size[2] - INSET))
		task.wait(0.4)
		R.selectTab("보석")
		task.wait(0.3)
		gemTab.debugApply(stateA)
		task.wait(0.2)
		local small, outside = {}, {}
		for slot = 1, 5 do
			local c = chip(slot)
			if c.AbsoluteSize.X < TOUCH_MIN - 0.5 or c.AbsoluteSize.Y < TOUCH_MIN - 0.5 then
				table.insert(small, ("Socket%d %d×%d"):format(slot, c.AbsoluteSize.X, c.AbsoluteSize.Y))
			end
			if c.AbsolutePosition.X + c.AbsoluteSize.X > gemBody.AbsolutePosition.X + gemBody.AbsoluteSize.X + 0.5 then
				table.insert(outside, "Socket" .. slot)
			end
		end
		local report = TextAudit.report(gemBody)
		local scales = 0
		for _, inst in ipairs(gemBody:GetDescendants()) do
			if inst:IsA("UIScale") then
				scales += 1
			end
		end
		check(("폰 %d × %d: 홈 칩 터치 44 미만 %d개 [%s] · 폭 밖 %d개 · 글씨 %d개 최소 %.1f · 12 미만 %d개 · UIScale %d개"):format(
			size[1], size[2], #small, table.concat(small, ","), #outside, report.count, report.minEffective, #report.low, scales),
			#small == 0 and #outside == 0 and #report.low == 0 and scales == 0)
	end

	-- ⑧ PC 배치(창 그대로): 홈 칩 한 줄이 무기 칸(폭 220) 안 · 글씨 실효 12 이상
	do
		R.debugForceScreen(nil)
		task.wait(0.4)
		R.selectTab("보석")
		task.wait(0.3)
		gemTab.debugApply(stateA)
		task.wait(0.2)
		local pane = gemBody:FindFirstChild("WeaponPane")
		local rowOk = pane ~= nil
		for slot = 1, 5 do
			local c = chip(slot)
			if not pane or c.AbsolutePosition.X + c.AbsoluteSize.X > pane.AbsolutePosition.X + pane.AbsoluteSize.X + 0.5 then
				rowOk = false
			end
		end
		local y1, y5 = chip(1).AbsolutePosition.Y, chip(5).AbsolutePosition.Y
		local report = TextAudit.report(gemBody)
		check(("PC 배치: 홈 5칸이 한 줄(y %d = %d) · 무기 칸 폭 안 %s · 글씨 12 미만 %d개"):format(y1, y5, tostring(rowOk), #report.low), y1 == y5 and rowOk and #report.low == 0)
	end

	-- 정리: 원래 상태 · 화면 · 창으로
	Store.selectedKind, Store.selectedValue = nil, nil
	gemTab.debugApply(originalState)
	R.debugForceScreen(nil)
	R.selectTab("장비")
	UIManager.close("inventory")
	task.wait(0.5)
	print(("===S20c(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20c][UI] 점검 에러: " .. tostring(err))
			UIManager.close("inventory", true)
	end
end)
