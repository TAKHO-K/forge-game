-- 패널 종류 규칙 · 부품 규격 자가 검사(30-0 S06, 합격 기준 2 · 4 · 5). `/gg ui check`가 부른다 - 클라 콘솔에 `[S06][UI][규칙] … O/X`와 요약을 찍는다.
-- 실제 UIManager · 실제 kit 부품 · 실제 전시장을 순서대로 열고 닫아 본다(트윈 0.12초 때문에 단계 사이에 잠깐 기다린다). 끝나면 전부 닫고 되돌린다.
-- 실제 키 입력(I)과 딤 뒤 클릭이 막히는지는 여기서 못 본다 - 그건 Play 2의 MCP 입력 검사(PRD 기록)가 맡는다.

local Badge = require(script.Parent.Parent.Parent.ui.kit.Badge)
local Confirm = require(script.Parent.Parent.Parent.ui.kit.Confirm)
local Gauge = require(script.Parent.Parent.Parent.ui.kit.Gauge)
local ListRow = require(script.Parent.Parent.Parent.ui.kit.ListRow)
local PanelRegistry = require(script.Parent.Parent.Parent.ui.PanelRegistry)
local Tabs = require(script.Parent.Parent.Parent.ui.kit.Tabs)
local Theme = require(script.Parent.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.Parent.Parent.UIManager)

local RuleCheck = {}

local STEP_WAIT = 0.3 -- 트윈(0.12초) + 여유

local function inBand(order, low, high)
	return order >= low and order <= high
end

local function countBadText(root, minSize)
	local bad = 0
	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" and inst.TextSize < minSize then
			bad += 1
		end
	end
	return bad
end

local function countAutomaticSize(root)
	local count = 0
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("GuiObject") and inst.AutomaticSize ~= Enum.AutomaticSize.None then
			count += 1
		end
	end
	return count
end

function RuleCheck.run(gallery)
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[S06][UI][규칙] %s %s"):format(label, ok and "O" or "X"))
	end
	local function stackText()
		return "[" .. table.concat(UIManager.getStack(), ", ") .. "]"
	end

	print("===S06 UI 규칙 검사 시작===")
	UIManager.setBossFight(false)
	gallery.open() -- 닫고 · 다시 짓고 · window 열기
	task.wait(STEP_WAIT)
	local ids = gallery.ids
	local refs = gallery.refs()

	-- ① window 1개 · 대역 · 모달
	local windowOrder = refs.window.screenGui.DisplayOrder
	check(("① window(전시장) 열림: 스택 %s · DisplayOrder %d(기대 100 ~ 149) · 모달 isInputBlocked=%s(기대 true)"):format(
		stackText(), windowOrder, tostring(UIManager.isInputBlocked())),
		UIManager.isOpen(ids.window) and inBand(windowOrder, 100, 149) and UIManager.isInputBlocked())

	-- ② window를 연 채 다른 window(가방)를 열면 전시장이 닫히고 가방이 열린다(★진짜 합격 기준 2)
	UIManager.open("inventory")
	task.wait(STEP_WAIT)
	check(("② 전시장을 연 채 가방 열기: 스택 %s(기대 [inventory]) ★진짜 합격 기준"):format(stackText()),
		UIManager.isOpen("inventory") and not UIManager.isOpen(ids.window) and #UIManager.getStack() == 1)
	UIManager.close("inventory")
	task.wait(STEP_WAIT)
	check(("③ 가방 닫기: 스택 %s(기대 []) · 모달 해제 isInputBlocked=%s(기대 false)"):format(stackText(), tostring(UIManager.isInputBlocked())),
		#UIManager.getStack() == 0 and not UIManager.isInputBlocked())

	-- ④ station: window가 없을 때 열린다 · 비모달 · 대역 · station 사이 교체
	local openedA = UIManager.open(ids.stationA)
	task.wait(STEP_WAIT)
	local stationOrder = refs.stationA.screenGui.DisplayOrder
	check(("④ window 없이 station A 열기: 열림=%s · DisplayOrder %d(기대 10 ~ 19) · 비모달 isInputBlocked=%s(기대 false)"):format(
		tostring(openedA), stationOrder, tostring(UIManager.isInputBlocked())),
		openedA and UIManager.isOpen(ids.stationA) and inBand(stationOrder, 10, 19) and not UIManager.isInputBlocked())
	UIManager.open(ids.stationB)
	task.wait(STEP_WAIT)
	check(("⑤ station B 열기 → station A는 닫힌다: 스택 %s(기대 [%s])"):format(stackText(), ids.stationB),
		UIManager.isOpen(ids.stationB) and not UIManager.isOpen(ids.stationA) and #UIManager.getStack() == 1)

	-- ⑥ window를 열면 열려 있던 station이 닫힌다 · window가 열려 있으면 station은 안 열린다(★)
	UIManager.open(ids.window)
	task.wait(STEP_WAIT)
	check(("⑥ station을 연 채 window 열기: 스택 %s(기대 [%s])"):format(stackText(), ids.window),
		UIManager.isOpen(ids.window) and not UIManager.isOpen(ids.stationB) and #UIManager.getStack() == 1)
	local blocked = UIManager.open(ids.stationA)
	task.wait(STEP_WAIT)
	check(("⑦ window가 열린 채 station 열기: 반환 %s(기대 false) · 스택 %s(기대 [%s]) ★진짜 합격 기준"):format(tostring(blocked), stackText(), ids.window),
		blocked == false and not UIManager.isOpen(ids.stationA) and #UIManager.getStack() == 1)

	-- ⑧ overlay: 맨 위 · 1개 · 뒤 입력 차단 · 부모를 닫으면 같이 닫힘(★)
	local answers = {}
	Confirm.ask({ title = "검사", body = "첫 물음", parentId = ids.window }, function(accepted)
		table.insert(answers, accepted)
	end)
	task.wait(STEP_WAIT)
	local confirmRefs = { screenGui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild(Confirm.id .. "Gui") }
	local overlayOrder = confirmRefs.screenGui and confirmRefs.screenGui.DisplayOrder or -1
	local dim = confirmRefs.screenGui and confirmRefs.screenGui:FindFirstChild("Dim")
	check(("⑧ 전시장 위에 확인창(overlay): 스택 %s · DisplayOrder %d(기대 200 ~ 249, 전시장 %d보다 위) · 딤이 화면 전체를 덮는 TextButton=%s · 모달=%s"):format(
		stackText(), overlayOrder, windowOrder, tostring(dim ~= nil and dim:IsA("TextButton") and dim.Visible and dim.Size == UDim2.new(1, 0, 1, 0)), tostring(UIManager.isInputBlocked())),
		UIManager.isOpen(Confirm.id) and inBand(overlayOrder, 200, 249) and overlayOrder > windowOrder and dim ~= nil and dim:IsA("TextButton")
			and dim.Visible and UIManager.isInputBlocked())
	Confirm.ask({ title = "검사", body = "두 번째 물음", parentId = ids.window }, function(accepted)
		table.insert(answers, accepted)
	end)
	task.wait(STEP_WAIT)
	local overlayCount = 0
	for _, id in ipairs(UIManager.getStack()) do
		if UIManager.getKind(id) == "overlay" then
			overlayCount += 1
		end
	end
	check(("⑨ 확인창을 또 열면 overlay는 그대로 1개: %d개(기대 1) · 첫 물음은 취소(false)로 끝남: %s(기대 [false])"):format(overlayCount, "[" .. table.concat(
		(function() local t = {} for _, v in ipairs(answers) do table.insert(t, tostring(v)) end return t end)(), ", ") .. "]"),
		overlayCount == 1 and #answers == 1 and answers[1] == false)
	UIManager.close(ids.window)
	task.wait(STEP_WAIT)
	check(("⑩ 부모(전시장)를 닫으면 확인창도 같이 닫힘: 스택 %s(기대 []) · 두 번째 물음도 취소로 끝남 %d건(기대 2) ★진짜 합격 기준"):format(stackText(), #answers),
		#UIManager.getStack() == 0 and #answers == 2 and answers[2] == false and not UIManager.isInputBlocked())

	-- ⑪ 보스전 딤 끄기
	UIManager.open(ids.window)
	task.wait(STEP_WAIT)
	local windowDim = refs.window.dim
	local dimOpen = windowDim.BackgroundTransparency
	UIManager.setBossFight(true)
	local dimBoss = windowDim.BackgroundTransparency
	UIManager.setBossFight(false)
	local dimAfter = windowDim.BackgroundTransparency
	check(("⑪ 보스전 딤 끄기: 평소 %.2f → 보스전 %.2f(기대 1) → 해제 %.2f(기대 %.2f)"):format(dimOpen, dimBoss, dimAfter, Theme.colors.overlayDimTransparency),
		math.abs(dimOpen - Theme.colors.overlayDimTransparency) < 0.01 and dimBoss == 1 and math.abs(dimAfter - Theme.colors.overlayDimTransparency) < 0.01)

	-- ⑫ 금지 키 · 부품 규격 오류
	local okForbidden = pcall(UIManager.register, "ruleCheckTmp", { hotkey = Enum.KeyCode.Q, hasCloseButton = true })
	local okTab = pcall(PanelRegistry.assertAllowed, Enum.KeyCode.Tab, "tmp")
	local okIKey = pcall(PanelRegistry.assertAllowed, Enum.KeyCode.I, "tmp")
	check(("⑫ 금지 키 등록: Q → 성공=%s(기대 false) · Tab → 성공=%s(기대 false) · 허용 키 I → 성공=%s(기대 true) · 등록 안 남음=%s"):format(
		tostring(okForbidden), tostring(okTab), tostring(okIKey), tostring(UIManager.getKind("ruleCheckTmp") == nil)),
		not okForbidden and not okTab and okIKey and UIManager.getKind("ruleCheckTmp") == nil)
	local probe = Instance.new("Frame")
	local okSixTabs = pcall(Tabs.build, { parent = probe, tabs = { { id = "1", text = "1" }, { id = "2", text = "2" }, { id = "3", text = "3" }, { id = "4", text = "4" }, { id = "5", text = "5" }, { id = "6", text = "6" } } })
	local okBadRow = pcall(ListRow.build, { parent = probe, height = 30, title = "x" })
	local okBadGauge = pcall(Gauge.build, { parent = probe, height = 12 })
	local okBadBadge = pcall(Badge.build, { parent = probe, kind = "star" })
	probe:Destroy()
	check(("⑬ 부품 규격 위반은 error: 탭 6개 → %s · 행 높이 30 → %s · 게이지 높이 12 → %s · 배지 kind star → %s(기대 전부 false)"):format(
		tostring(okSixTabs), tostring(okBadRow), tostring(okBadGauge), tostring(okBadBadge)),
		not okSixTabs and not okBadRow and not okBadGauge and not okBadBadge)

	-- ⑭ 토스트: TR 3행 · 대기열 · 묶기
	Toast.clear()
	for index = 1, 5 do
		Toast.push("TR", { text = "항목 " .. index, priority = index, seconds = 30 })
	end
	local afterFive = Toast.debugState("TR")
	for index = 6, 16 do
		Toast.push("TR", { text = "항목 " .. index, priority = index, seconds = 30 })
	end
	local afterMany = Toast.debugState("TR")
	Toast.clear()
	Toast.push("TR", { text = "묶음", groupKey = "g", seconds = 30 })
	local merged = Toast.push("TR", { text = "묶음", groupKey = "g", seconds = 30 })
	local afterGroup = Toast.debugState("TR")
	Toast.clear()
	check(("⑭ 토스트 TR: 5개 → 보이는 행 %d(기대 3) · 대기 %d(기대 2) / 16개 → 대기 %d(기대 8, 넘치면 낮은 priority부터 버림) / 같은 groupKey 두 번 → %s · 행 %d(기대 merged · 1)"):format(
		afterFive.rows, afterFive.queued, afterMany.queued, merged, afterGroup.rows),
		afterFive.rows == 3 and afterFive.queued == 2 and afterMany.rows == 3 and afterMany.queued == Toast.queueMax and merged == "merged" and afterGroup.rows == 1)

	-- ⑮ 전시장 안: 글씨 12 미만 0 · 버튼 높이 · AutomaticSize 0
	local gui = refs.window.screenGui
	local smallText, smallButtons, buttonCount = countBadText(gui, 12), 0, 0
	for _, inst in ipairs(gui:GetDescendants()) do
		if inst:IsA("TextButton") and (inst.Name == "Button" or inst.Name:sub(1, 4) == "Btn_") then
			buttonCount += 1
			if inst.AbsoluteSize.Y < Theme.buttonHeight then
				smallButtons += 1
			end
		end
	end
	local closeSize = refs.window.closeButton.AbsoluteSize
	check(("⑮ 전시장 안 검사(%s): 글씨 12 미만 %d개(기대 0) · Button %d개 중 높이 %d 미만 %d개(기대 0) · X 버튼 %d × %d(기대 44 × 44 이상) · AutomaticSize %d개(기대 0)"):format(
		Theme.isMobile and "모바일" or "PC", smallText, buttonCount, Theme.buttonHeight, smallButtons, closeSize.X, closeSize.Y, countAutomaticSize(gui)),
		smallText == 0 and buttonCount > 0 and smallButtons == 0 and closeSize.X >= 44 and closeSize.Y >= 44 and countAutomaticSize(gui) == 0)

	-- 되돌리기
	UIManager.setBossFight(false)
	gallery.close()
	Toast.clear()
	check(("⑯ 정리: 열린 패널 %d개(기대 0) · 모달 %s(기대 false)"):format(#UIManager.getStack(), tostring(UIManager.isInputBlocked())),
		#UIManager.getStack() == 0 and not UIManager.isInputBlocked())
	print(("===S06 UI 규칙 검사 끝=== %d/%d 통과"):format(pass, total))
end

return RuleCheck
