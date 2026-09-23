-- P2.5b 자체 점검 [P25b][UI] - 계승 창 · 보석 가공 창 · 성장 보상 창 · 상세 바의 [계승] · [재련] · [분해]를 실제 인스턴스로 잰다(글씨 실효 12 이상 · 터치 · 화면 안 · 규칙별 표시)
-- + 열고 닫기 20회 반복 뒤 인스턴스 · 메모리 누수(E). 서버 요청은 보내지 않는다(창은 debugOpen의 합성 값으로 연다 - 판정 경로는 P25b(나)가 서버에서 잰다).
-- Studio에서 DevToolsConfig.verify에 "P25b(UI)"가 있을 때만 돈다. 창을 여는 다른 점검과 겹치지 않게 그 점검들이 끝난 뒤 시작한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local current = DevToolsConfig.verify.current
if not (DevToolsConfig.verify.regression or table.find(current, "P25b(UI)")) then
	return
end

local Theme = require(script.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.UIManager)
local InheritPanel = require(script.Parent.panels.Inherit)
local GemForge = require(script.Parent.panels.GemForge)
local MilestonesPanel = require(script.Parent.panels.Milestones)
local Store = require(script.Parent.panels.Inventory.Store)

local player = Players.LocalPlayer
-- 창을 여는 다른 점검(S20d(UI) 150초 · S20e(UI) 215초)이 같이 돌면 그 뒤에 시작한다.
local START_DELAY = (DevToolsConfig.verify.regression or table.find(current, "S20e(UI)")) and 255 or (table.find(current, "S20d(UI)") and 195 or 45)

local passed, total = 0, 0
local function check(label, ok)
	total += 1
	if ok then
		passed += 1
	end
	print(("[P25b][UI] %s %s"):format(label, ok and "O" or "X"))
end

local function item(part, grade, itemLevel, optionId, roll)
	return { grade = grade, part = part, dropStage = itemLevel, itemLevel = itemLevel, tierIndex = 1, locked = false, option = optionId and { id = optionId, roll = roll or 1, roll2 = roll or 1 } or nil }
end

local function isShown(inst, stop)
	local node = inst
	while node and node ~= stop do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return true
end

-- 창 하나: 보이는 글씨의 실효 크기 최솟값 · 주어진 버튼들의 높이 · 창이 화면 안인가.
local function measure(refs, buttonNames)
	local frame = refs.panel.frame
	local gui = refs.panel.screenGui
	local smallest, smallName = math.huge, "-"
	for _, inst in ipairs(frame:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" and isShown(inst, gui) then
			local size = Theme.effectiveTextSize(inst)
			if size < smallest then
				smallest, smallName = size, inst.Name
			end
		end
	end
	local minButton = Theme.isMobile and Theme.touchMin or Theme.buttonHeight
	local shortButtons = {}
	for _, name in ipairs(buttonNames) do
		local found = frame:FindFirstChild(name, true)
		if not found or found.AbsoluteSize.Y < minButton - 0.5 then
			table.insert(shortButtons, ("%s(%s)"):format(name, found and tostring(found.AbsoluteSize.Y) or "없음"))
		end
	end
	local pos, size, screen = frame.AbsolutePosition - gui.AbsolutePosition, frame.AbsoluteSize, gui.AbsoluteSize
	local inside = pos.X >= -0.5 and pos.Y >= -0.5 and pos.X + size.X <= screen.X + 0.5 and pos.Y + size.Y <= screen.Y + 0.5
	return smallest, smallName, shortButtons, inside, ("%dx%d @ %d,%d / 화면 %dx%d"):format(size.X, size.Y, pos.X, pos.Y, screen.X, screen.Y)
end

local function countGui()
	return #player.PlayerGui:GetDescendants()
end

local function run()
	print("===P25b 검증 시작(UI: 계승 · 보석 가공 · 성장 보상 창 · 상세 바 · 누수)===")
	local savedGold, savedDust, savedStage = player:GetAttribute("Gold"), player:GetAttribute("GemDust"), player:GetAttribute("AccountBestStage")
	local ok, err = pcall(function()
		UIManager.closeAll()
		task.wait(0.4)
		player:SetAttribute("Gold", 1e12) -- 이 클라에서만 보이는 값(버튼 활성 판정) - 끝에서 되돌린다
		player:SetAttribute("GemDust", 1e6)

		-- ① 계승 창: 합성 A(착용) · B(가방) + 합성 미리보기(서버 모양 그대로).
		local a = item("armor", "legendary", 120, "attackPercent", 1.1)
		local b = item("armor", "relic", 300, "speedPercent", 0.9)
		local stats = function(attack, defense)
			return { attack = attack, defense = defense, maxHp = 5000, speedPercent = 0.3, critRate = 0.05, critDmg = 0.2 }
		end
		local preview = { cost = 5211, gold = 1e12, refund = { a = { kind = "gem", gem = { grade = "legendary", itemLevel = 120, option = b.option } }, b = { kind = "gem", gem = { grade = "legendary", itemLevel = 120, option = a.option } } },
			stats = { current = stats(1000, 300), a = stats(1200, 900), b = stats(1000, 900) } }
		InheritPanel.debugOpen("armor", 1, a, b, preview, "a")
		task.wait(0.5)
		local state = InheritPanel.debugState()
		local refs = state.refs
		local smallest, smallName, short, inside, geometry = measure(refs, { "InheritButton", "CancelButton", "KeepA", "KeepB" })
		check(("① 계승 창(%s · %s): 열림 %s · 최소 글씨 %.1f(%s - 기대 ≥ 12) · 짧은 버튼 [%s] · 화면 안 %s"):format(Theme.isMobile and "모바일" or "PC", geometry, tostring(state.open), smallest, smallName, table.concat(short, ", "), tostring(inside)),
			state.open and smallest >= 12 and #short == 0 and inside)
		local cardA, cardB = refs.cardA, refs.cardB
		check(("① A 세트 선택 표시: A 테두리 ember %s · B 테두리 rim %s · 비교 표 공격력 '%s' → '%s' 변화 '%s' · 환급 '%s' · 비용 '%s' · [계승] 활성 %s"):format(
			tostring(cardA.stroke.Color == Theme.color("ember")), tostring(cardB.stroke.Color == Theme.color("rim")), refs.statRows[1].now.Text, refs.statRows[1].after.Text, refs.statRows[1].delta.Text,
			refs.refund.Text, refs.cost.Text, tostring(refs.inheritButton.getVisual() ~= "disabled")),
			cardA.stroke.Color == Theme.color("ember") and refs.statRows[1].after.Text ~= "-" and refs.statRows[1].delta.Text == "+20.0%" and refs.refund.Text:find("A 환급") ~= nil
				and refs.inheritButton.getVisual() ~= "disabled")
		-- B 등급이 낮으면 A 세트 불가(회색 + 이유) · 선택이 B로 돌아간다.
		local low = item("armor", "epic", 500, "crit", 1)
		local lowPreview = table.clone(preview)
		lowPreview.keepABlock = "b_grade_lower"
		lowPreview.stats = { current = stats(1000, 300), b = stats(1000, 1200) }
		InheritPanel.debugOpen("armor", 1, a, low, lowPreview, "a")
		task.wait(0.3)
		check(("① A3 B 등급 낮음: A 카드 이유 '%s' 보임 %s · 선택 %s(기대 b) · A 카드 입력 막힘 %s"):format(cardA.reason.Text, tostring(cardA.reason.Visible), InheritPanel.debugState().keep, tostring(cardA.root.Active == false)),
			cardA.reason.Visible and cardA.reason.Text:find("낮아") ~= nil and InheritPanel.debugState().keep == "b" and cardA.root.Active == false)
		-- 골드 부족 → [계승] 회색 + 이유.
		player:SetAttribute("Gold", 10)
		InheritPanel.render()
		task.wait(0.2)
		check(("① 골드 부족: [계승] %s(기대 disabled) · 비용 줄 색 danger %s"):format(refs.inheritButton.getVisual(), tostring(refs.cost.TextColor3 == Theme.color("danger"))),
			refs.inheritButton.getVisual() == "disabled" and refs.cost.TextColor3 == Theme.color("danger"))
		player:SetAttribute("Gold", 1e12)
		UIManager.close(InheritPanel.id, true)
		task.wait(0.3)

		-- ② 보석 가공 창: 홈 1 = 태초 Lv.40(대상) · 가방 = 먹이 후보(높은 레벨 2 · 낮은 레벨 1).
		local gemState = {
			gems = { { grade = "primordial", itemLevel = 40, option = { id = "maxHpPercent", roll = 1.05 } }, false, false, false, false },
			slotUnlocked = { true, false, false, false, false },
			gemInventory = {
				{ grade = "epic", itemLevel = 2500, option = { id = "crit", roll = 0.9, roll2 = 0.9 } },
				{ grade = "relic", itemLevel = 30, option = { id = "attackPercent", roll = 1 } },
				{ grade = "legendary", itemLevel = 900, option = { id = "speedPercent", roll = 1 } },
			},
			rerollTickets = { ancient = 0, primordial = 0 },
		}
		GemForge.debugOpen(gemState, "slot", 1, "refine", 1)
		task.wait(0.5)
		local forge = GemForge.debugState()
		local fr = forge.refs
		local fodderRows = 0
		for name in pairs(fr.rows) do
			if name:find("^Fodder_") then
				fodderRows += 1
			end
		end
		local previewLine = fr.scroll:FindFirstChild("PreviewLine")
		local fs, fsName, fshort, finside, fgeo = measure(fr, { "ActionButton", "BackButton", "RefineTab", "BulkTab", "Pick" })
		check(("② 재련 탭(%s): 먹이 후보 %d(기대 2 - Lv.30은 대상보다 낮아 빠진다) · 미리보기 '%s' · [재련] 활성 %s · 최소 글씨 %.1f(%s) · 짧은 버튼 [%s] · 화면 안 %s"):format(
			fgeo, fodderRows, previewLine and previewLine.Text or "없음", tostring(fr.action.getVisual() ~= "disabled"), fs, fsName, table.concat(fshort, ", "), tostring(finside)),
			fodderRows == 2 and previewLine ~= nil and previewLine.Text:find("Lv.40 → Lv.2500") ~= nil and fr.action.getVisual() ~= "disabled" and fs >= 12 and #fshort == 0 and finside)
		player:SetAttribute("GemDust", 0)
		GemForge.render()
		task.wait(0.2)
		check(("② 가루 부족: [재련] %s(기대 disabled) · 비용 줄 '%s'"):format(fr.action.getVisual(), fr.cost.Text), fr.action.getVisual() == "disabled")
		player:SetAttribute("GemDust", 1e6)
		GemForge.setMode("bulk")
		task.wait(0.3)
		local gradeRows = 0
		for name in pairs(fr.rows) do
			if name:find("^Grade_") then
				gradeRows += 1
			end
		end
		check(("② 일괄 분해 탭: 등급 행 %d(기대 5) · 아래 줄 '%s' · [일괄 분해] 활성 %s"):format(gradeRows, fr.cost.Text, tostring(fr.action.getVisual() ~= "disabled")),
			gradeRows == 5 and fr.cost.Text:find("1개") ~= nil and fr.action.getVisual() ~= "disabled")
		UIManager.close(GemForge.id, true)
		task.wait(0.3)

		-- ③ 성장 보상 창.
		MilestonesPanel.debugOpen({ rebirthCount = 2, level = 180, cycles = { ["1"] = 150, ["2"] = 150 }, statCount = 6, multiplier = 1.1941, unlockCount = 1 })
		task.wait(0.5)
		local ms = MilestonesPanel.debugState()
		local mr = ms.refs
		local unlockRows, cycleRows = 0, 0
		for _, child in ipairs(mr.scroll:GetChildren()) do
			if child.Name:find("^Unlock_") then
				unlockRows += 1
			elseif child.Name:find("^Cycle_") then
				cycleRows += 1
			end
		end
		local nextStat = mr.scroll:FindFirstChild("NextStat")
		local nextUnlock = mr.scroll:FindFirstChild("NextUnlock")
		local ms1, ms1Name, _, minside, mgeo = measure(mr, {})
		check(("③ 성장 보상 창(%s): 해금 행 %d(기대 5) · 회차 행 %d(기대 2) · '%s' · '%s' · 최소 글씨 %.1f(%s) · 화면 안 %s"):format(mgeo, unlockRows, cycleRows, nextStat and nextStat.Text or "-", nextUnlock and nextUnlock.Text or "-", ms1, ms1Name, tostring(minside)),
			unlockRows == 5 and cycleRows == 2 and nextStat ~= nil and nextStat.Text:find("Lv.200") ~= nil and nextStat.Text:find("남은 레벨 20") ~= nil
				and nextUnlock ~= nil and nextUnlock.Text:find("남은 레벨 20") ~= nil and ms1 >= 12 and minside)
		UIManager.close(MilestonesPanel.id, true)
		task.wait(0.3)

		-- ④ 상세 바: 가방 장비가 착용품보다 좋을 때만 [계승] · 보석(가방)은 [분해] 활성 + [재련].
		local S = Store
		local savedInv, savedArmor, savedKind, savedValue = S.inventory, S.equippedArmor, S.selectedKind, S.selectedValue
		UIManager.open("inventory")
		task.wait(0.5)
		S.inventory = { b, item("armor", "normal", 10) }
		S.equippedArmor = a
		S.selectedKind, S.selectedValue = "bag", 1
		S.refreshDetail()
		task.wait(0.2)
		local detail = S.R.detail
		local inheritButton = detail:FindFirstChild("InheritButton", true)
		local craftButton = detail:FindFirstChild("CraftButton", true)
		local hint = detail:FindFirstChild("DetailHint")
		local shownGood = inheritButton and inheritButton.Visible
		S.selectedValue = 2
		S.refreshDetail()
		task.wait(0.2)
		local shownBad = inheritButton and inheritButton.Visible
		check(("④ 상세 바: 좋은 B [계승] %s · 나쁜 B %s(기대 true · false) · 비교 줄 '%s'"):format(tostring(shownGood), tostring(shownBad), hint and hint.Text or "-"),
			shownGood == true and shownBad == false and hint ~= nil and hint.Text:find("착용 대비") ~= nil)
		S.inventory, S.equippedArmor, S.selectedKind, S.selectedValue = savedInv, savedArmor, savedKind, savedValue
		S.refreshDetail()
		UIManager.close("inventory", true)
		task.wait(0.3)
		check(("④ [재련] 버튼 있음 %s(보석을 고를 때만 보인다 - 지금 %s)"):format(tostring(craftButton ~= nil), tostring(craftButton and craftButton.Visible)), craftButton ~= nil and craftButton.Visible == false)

		-- ⑤ 누수(E): 세 창을 20번씩 열고 닫는다(열 때마다 본문을 새로 그린다) - 인스턴스 수 · 메모리가 돌아오는가.
		task.wait(0.5)
		local before, memBefore = countGui(), gcinfo()
		for _ = 1, 20 do
			InheritPanel.debugOpen("armor", 1, a, b, preview, "a")
			task.wait(0.05)
			UIManager.close(InheritPanel.id, true)
			GemForge.debugOpen(gemState, "slot", 1, "refine", 1)
			GemForge.setMode("bulk")
			GemForge.setMode("refine")
			task.wait(0.05)
			UIManager.close(GemForge.id, true)
			MilestonesPanel.debugOpen({ rebirthCount = 2, level = 180, cycles = { ["1"] = 150, ["2"] = 150 }, statCount = 6, multiplier = 1.19, unlockCount = 1 })
			task.wait(0.05)
			UIManager.close(MilestonesPanel.id, true)
		end
		task.wait(1)
		local after, memAfter = countGui(), gcinfo()
		check(("⑤ 열고 닫기 20회 × 3창: PlayerGui 인스턴스 %d → %d(차이 %d · 기대 0) · 메모리 %.0f → %.0f KB(차이 %.0f KB · 기대 < 2048)"):format(before, after, after - before, memBefore, memAfter, memAfter - memBefore),
			after == before and memAfter - memBefore < 2048)
	end)
	if not ok then
		check(("실행 중 에러: %s"):format(tostring(err)), false)
	end
	UIManager.closeAll()
	player:SetAttribute("Gold", savedGold)
	player:SetAttribute("GemDust", savedDust)
	player:SetAttribute("AccountBestStage", savedStage)
	print(("===P25b 검증 끝(UI)=== %d/%d 통과"):format(passed, total))
end

task.delay(START_DELAY, run)
