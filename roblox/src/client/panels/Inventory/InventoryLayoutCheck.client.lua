-- S20b 자체 점검 [S20][UI][장비창] - 장비창 재구성(UIScale 제거 · 폰 1단 + 탭 3개 + 하단 시트)의 실제 인스턴스 점검. Studio에서 DevToolsConfig.verify에 "S20(UI)"가 있을 때만(또는 회귀 전체) 돈다.
--   ① 배치 순수 함수(Layout.compute)를 4 해상도(800 × 360 · 667 × 375 · 842 × 388 · 1024 × 768 - 상단 인셋 58을 뺀 ScreenGui 크기)로 불러 폰 / PC 판정 · 창이 화면 안 · 열 수를 잰다.
--   ② 지금 화면(PC)에서 창을 열고: UIScale 0개 · 글씨 실효 12 미만 0개(장비 탭 · 보석 탭) · 구조 프레임 화면 밖 0.
--   ③ 폰 배치를 가상 화면으로 강제해(R.debugForceScreen) 실제 인스턴스로 잰다: 탭 3개 각각 - 글씨 실효 12 미만 0개 · 화면 밖 0 · 버튼 터치 44 이상 · 헤더 겹침 0 · 가방 칸이 폭 안 · 시트(선택 시 올라옴 · 닫기 44 · 창 안) · 시트 닫으면 숨음.
--   PC 화면에서 폰 배치를 재는 방법: 창 · 프레임 크기는 전부 배치(L)에서 정해지므로 가상 화면 크기를 주면 실제 폰과 같은 크기 · 자리가 된다(글씨는 PC 단 12 · 실제 폰은 ×1.15라 더 크다 - 12 이상 판정은 더 안전한 쪽).
-- 클릭은 못 한다 - 창을 연 채 실제 클릭 · B 키는 스크린샷 Play에서 본다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20(UI)")) then
	return
end

local Layout = require(script.Parent.Layout)
local Store = require(script.Parent.Store)
local TextAudit = require(script.Parent.Parent.Parent.ui.TextAudit)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local START_DELAY = 84 -- GemTabCheck(78) 뒤 - 같은 창을 열고 닫는다
local INSET = 58 -- GetGuiInset 상단. ScreenGui 높이 = 뷰포트 높이 - INSET.
local RESOLUTIONS = { { 800, 360 }, { 667, 375 }, { 842, 388 }, { 1024, 768 } }
local TOUCH_MIN = 44

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20][UI][장비창] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20b(UI) 검증 시작(장비창 재구성)===")

	-- ① 순수 함수
	do
		local rows, allOk = {}, true
		for _, size in ipairs(RESOLUTIONS) do
			local screenW, screenH = size[1], size[2] - INSET
			local L = Layout.compute(screenW, screenH)
			local expectPhone = size[1] ~= 1024
			local inside = L.winW <= screenW - 2 * Layout.margin and L.winH <= screenH - 2 * Layout.margin and L.bodyH > 100
			local ok = (L.mode == "phone") == expectPhone and inside
			allOk = allOk and ok
			table.insert(rows, ("%d × %d(ScreenGui %d × %d) → %s · 창 %d × %d · 본문 높이 %d · 장비 %d열 · 가방 %d열 · 탭 %d개 %s"):format(
				size[1], size[2], screenW, screenH, L.mode == "phone" and "폰" or "PC", L.winW, L.winH, L.bodyH, L.gearCols, L.bagCols, #L.tabNames, ok and "안" or "X"))
		end
		check(("배치 판정(폭 < %d 또는 높이 < %d = 폰) · 창이 화면 안(여백 %d): %s"):format(Layout.phoneWidthBelow, Layout.phoneHeightBelow, Layout.margin, table.concat(rows, " / ")), allOk)
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local gui = playerGui:FindFirstChild("InventoryGui")
	local R = Store.R
	if not (gui and R) then
		check("InventoryGui · Store.R를 못 찾음", false)
		print(("===S20b(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
		return
	end
	local win = gui:FindFirstChild("Window")
	local content = win and win:FindFirstChild("Content")

	local function insideScreen(inst, screen)
		local position, size = inst.AbsolutePosition, inst.AbsoluteSize
		return position.X >= -0.5 and position.Y >= -0.5 and position.X + size.X <= screen.X + 0.5 and position.Y + size.Y <= screen.Y + 0.5
	end

	-- 보이는 TextButton 중 터치 44 미만(허용 목록 제외: 홈 점 - 드롭 대상이지 누르는 조작이 아니다)
	local function smallTouch(root)
		local list = {}
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("TextButton") and not inst.Name:match("^Socket%d") then
				local shown, node = true, inst
				while node and node ~= root.Parent do
					if node:IsA("GuiObject") and not node.Visible then
						shown = false
						break
					end
					node = node.Parent
				end
				if shown and (inst.AbsoluteSize.X < TOUCH_MIN - 0.5 or inst.AbsoluteSize.Y < TOUCH_MIN - 0.5) then
					table.insert(list, ("%s %d×%d"):format(inst.Name ~= "" and inst.Name or inst.Text, inst.AbsoluteSize.X, inst.AbsoluteSize.Y))
				end
			end
		end
		return list
	end

	-- ② 지금 화면(PC)
	UIManager.open("inventory")
	task.wait(0.8)
	R.debugForceScreen(nil)
	task.wait(0.3)
	do
		local scales = 0
		for _, inst in ipairs(win:GetDescendants()) do
			if inst:IsA("UIScale") then
				scales += 1
			end
		end
		local L = R.layout
		local screen = gui.AbsoluteSize
		local lowLines, structureOk = {}, true
		for _, tab in ipairs({ "장비", "보석" }) do
			R.selectTab(tab)
			task.wait(0.15)
			local report = TextAudit.report(content)
			table.insert(lowLines, ("%s 탭 글씨 %d개 · 최소 %.1f · 12 미만 %d개%s"):format(tab, report.count, report.minEffective, #report.low, #report.low > 0 and (" [" .. table.concat(report.low, ",", 1, math.min(#report.low, 4)) .. "]") or ""))
			if #report.low > 0 then
				structureOk = false
			end
		end
		R.selectTab("장비")
		task.wait(0.1)
		local outside = {}
		for _, inst in ipairs({ win, content:FindFirstChild("Header"), content:FindFirstChild("TabRow"), R.gearFrame, R.bagFrame, R.detail }) do
			if inst and inst.Visible and not insideScreen(inst, screen) then
				table.insert(outside, inst.Name)
			end
		end
		check(("지금 화면 %d × %d(%s): UIScale %d개(기대 0) · %s · 화면 밖 프레임 %d개 [%s](기대 0) · 창 %d × %d"):format(
			screen.X, screen.Y, L.mode == "phone" and "폰" or "PC", scales, table.concat(lowLines, " / "), #outside, table.concat(outside, ","), win.AbsoluteSize.X, win.AbsoluteSize.Y),
			scales == 0 and structureOk and #outside == 0)
	end

	-- ③ 폰 배치를 가상 화면으로 강제해 실제 인스턴스로 잰다
	for _, size in ipairs({ { 800, 360 }, { 667, 375 }, { 842, 388 } }) do
		local screenW, screenH = size[1], size[2] - INSET
		local screen = Vector2.new(screenW, screenH)
		local L = R.debugForceScreen(screen)
		task.wait(0.4)
		local notes, allOk = {}, L.mode == "phone"
		for _, tab in ipairs({ "장비", "가방", "보석" }) do
			R.selectTab(tab)
			task.wait(0.15)
			local report = TextAudit.report(content)
			local small = smallTouch(content)
			local outside = {}
			for _, inst in ipairs({ win, content:FindFirstChild("Header"), content:FindFirstChild("TabRow"), R.gearFrame, R.bagFrame, R.gemFrame }) do
				if inst and inst.Visible and not insideScreen(inst, screen) then
					table.insert(outside, inst.Name)
				end
			end
			-- 헤더 겹침: 왼쪽 묶음(제목 · 개수)이 오른쪽 묶음(정렬 · 기준 · 일괄판매 · 닫기)과 안 겹친다
			local header = content:FindFirstChild("Header")
			local headerOk = true
			if header then
				local pieces = {}
				for _, child in ipairs(header:GetChildren()) do
					if child:IsA("Frame") and child.AbsoluteSize.X > 0 and child.AutomaticSize == Enum.AutomaticSize.X then
						table.insert(pieces, child)
					end
				end
				table.sort(pieces, function(a, b)
					return a.AbsolutePosition.X < b.AbsolutePosition.X
				end)
				for i = 2, #pieces do
					if pieces[i - 1].AbsolutePosition.X + pieces[i - 1].AbsoluteSize.X > pieces[i].AbsolutePosition.X + 0.5 then
						headerOk = false
					end
				end
			end
			-- 칸이 폭 안(가방 셀 · 장비 칸)
			local widthOk = true
			local frame = tab == "장비" and R.gearFrame or (tab == "가방" and R.bagFrame or R.gemFrame)
			for _, inst in ipairs(frame:GetDescendants()) do
				if inst:IsA("GuiButton") and (inst.Name:match("^Cell_") or inst.Name:match("^Gear_") or inst.Name:match("^GemCell")) then
					if inst.AbsolutePosition.X + inst.AbsoluteSize.X > frame.AbsolutePosition.X + frame.AbsoluteSize.X + 0.5 then
						widthOk = false
					end
				end
			end
			local ok = #report.low == 0 and #small == 0 and #outside == 0 and headerOk and widthOk
			allOk = allOk and ok
			table.insert(notes, ("%s(글씨 %d개 · 12 미만 %d · 터치 44 미만 %d%s · 화면 밖 %d · 헤더 겹침 %s · 칸 폭 안 %s)"):format(
				tab, report.count, #report.low, #small, #small > 0 and (" [" .. table.concat(small, ",", 1, math.min(#small, 3)) .. "]") or "", #outside, tostring(not headerOk), tostring(widthOk)))
		end
		check(("폰 %d × %d(ScreenGui %d × %d · 창 %d × %d · 본문 %d · 가방 %d열): %s"):format(size[1], size[2], screenW, screenH, L.winW, L.winH, L.bodyH, L.bagCols, table.concat(notes, " / ")), allOk)

		-- 시트: 선택이 있으면 올라오고(창 안 · 버튼 44) 닫으면(선택 비움) 숨는다
		R.selectTab("장비")
		Store.selectedKind, Store.selectedValue = "equip", "weapon"
		Store.refreshDetail()
		task.wait(0.15)
		local detail = R.detail
		local winRect = { win.AbsolutePosition, win.AbsoluteSize }
		local sheetInside = detail.Visible and detail.AbsolutePosition.X >= winRect[1].X - 0.5 and detail.AbsolutePosition.Y >= winRect[1].Y - 0.5
			and detail.AbsolutePosition.X + detail.AbsoluteSize.X <= winRect[1].X + winRect[2].X + 0.5 and detail.AbsolutePosition.Y + detail.AbsoluteSize.Y <= winRect[1].Y + winRect[2].Y + 0.5
		local sheetSmall = smallTouch(detail)
		local closeButton = R.sheetClose
		local closeOk = closeButton.Visible and closeButton.AbsoluteSize.X >= TOUCH_MIN and closeButton.AbsoluteSize.Y >= TOUCH_MIN
		-- 텍스트 라벨이 시트 밖으로 안 나간다(이름 · 메타 · 옵션 줄)
		local textOutside = 0
		for _, inst in ipairs(TextAudit.visibleTexts(detail)) do
			if inst.AbsolutePosition.X + inst.AbsoluteSize.X > detail.AbsolutePosition.X + detail.AbsoluteSize.X + 0.5 or inst.AbsolutePosition.Y + inst.AbsoluteSize.Y > detail.AbsolutePosition.Y + detail.AbsoluteSize.Y + 0.5 then
				textOutside += 1
			end
		end
		Store.selectedKind, Store.selectedValue = nil, nil
		Store.refreshDetail()
		task.wait(0.1)
		check(("폰 %d × %d 상세 시트(%s): 올라옴 %s · 창 안 %s(시트 %d × %d) · 버튼 44 미만 %d개 [%s] · 닫기 버튼 %d × %d %s · 시트 밖으로 나간 글 %d개(기대 0) · 선택 비우면 숨음 %s"):format(
			size[1], size[2], L.sheetWide and "한 줄" or "두 줄", tostring(detail.Visible or sheetInside), tostring(sheetInside), detail.AbsoluteSize.X, detail.AbsoluteSize.Y, #sheetSmall, table.concat(sheetSmall, ","),
			closeButton.AbsoluteSize.X, closeButton.AbsoluteSize.Y, tostring(closeOk), textOutside, tostring(not detail.Visible)),
			sheetInside and #sheetSmall == 0 and closeOk and textOutside == 0 and not detail.Visible)
	end

	R.debugForceScreen(nil)
	R.selectTab("장비")
	UIManager.close("inventory")
	task.wait(0.5)
	print(("===S20b(UI) 검증 끝(장비창 재구성)=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20][UI][장비창] 점검 에러: " .. tostring(err))
		local R = Store.R
		if R then
			R.debugForceScreen(nil)
		end
		UIManager.close("inventory", true)
	end
end)
