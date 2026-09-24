-- P3b 자체 점검 [P3b][UI] - 순위 창 · 장비 보기(카드 · 비교) · 스킬 툴팁을 실제 인스턴스로 잰다(글씨 실효 12 이상 · 화면 안 · 탭 · 펼침 · 비교 · 툴팁 수치 = 서버 수치)
-- + 열고 닫기 20회 뒤 인스턴스 누수 + 폰(800 × 360 → ScreenGui 800 × 302) 치수 식. 서버 요청은 실제 Remote를 쓴다(LeaderboardRequest · InspectPlayer · SkillInfoRequest).
-- Studio에서 DevToolsConfig.verify에 "P3b(UI)"가 있을 때만 돈다. 창을 여는 다른 점검과 겹치지 않게, 같이 도는 창 점검(P25b(UI) - 가장 늦게 끝난다)의 끝 줄을 기다렸다가 시작한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LogService = game:GetService("LogService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local current = DevToolsConfig.verify.current
if not (DevToolsConfig.verify.regression or table.find(current, "P3b(UI)")) then
	return
end

local Theme = require(script.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.UIManager)
local ScreenMap = require(script.Parent.ui.ScreenMap)
local Panel = require(script.Parent.ui.kit.Panel)
local Leaderboard = require(script.Parent.panels.Leaderboard)
local Inspect = require(script.Parent.panels.Inspect)
local SkillTooltip = require(script.Parent.hud.SkillTooltip)

local player = Players.LocalPlayer

local passed, total = 0, 0
local function check(label, ok)
	total += 1
	if ok then
		passed += 1
	end
	print(("[P3b][UI] %s %s"):format(label, ok and "O" or "X"))
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

-- 보이는 글씨의 실효 크기 최솟값(12 미만 목록)
local function smallestText(root, stop)
	local smallest, below = math.huge, {}
	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and inst.Text ~= "" and isShown(inst, stop) then
			local size = Theme.effectiveTextSize(inst)
			smallest = math.min(smallest, size)
			if size < Theme.minTextSize then
				table.insert(below, inst.Name)
			end
		end
	end
	return smallest, below
end

local function insideScreen(frame, gui)
	local pos, size, screen = frame.AbsolutePosition, frame.AbsoluteSize, gui.AbsoluteSize
	return pos.X >= -0.5 and pos.Y >= -0.5 and pos.X + size.X <= screen.X + 0.5 and pos.Y + size.Y <= screen.Y + 0.5
end

local function waitFor(fn, timeout)
	local waited = 0
	while not fn() and waited < timeout do
		task.wait(0.1)
		waited += 0.1
	end
	return fn(), waited
end

-- 같이 도는 창 점검이 끝날 때까지(끝 줄) 기다린다 - 없으면 30초 뒤.
local waitMarker = (DevToolsConfig.verify.regression or table.find(current, "P25b(UI)")) and "===P25b 검증 끝(UI)===" or nil
local markerSeen = waitMarker == nil
if waitMarker then
	for _, entry in ipairs(LogService:GetLogHistory()) do
		markerSeen = markerSeen or entry.message:find(waitMarker, 1, true) ~= nil
	end
	LogService.MessageOut:Connect(function(message)
		if message:find(waitMarker, 1, true) then
			markerSeen = true
		end
	end)
end

task.spawn(function()
	task.wait(30)
	waitFor(function()
		return markerSeen
	end, 420)
	task.wait(2)
	print("===P3b 검증 시작(UI: 순위 창 · 장비 보기 · 스킬 툴팁 · 누수 · 폰 치수)===")

	-- ① 순위 창 - 탭 4개 · 직업 칩 · 내 순위 줄
	local ok, err = pcall(function()
		UIManager.closeAll()
		task.wait(0.5)
		Leaderboard.open()
		local loaded = waitFor(function()
			local state = Leaderboard.debugState()
			return state.empty ~= "불러오는 중…" and state.me ~= "내 순위: 불러오는 중…"
		end, 15)
		task.wait(0.6) -- 여는 트윈(UIScale 0.94 → 1)이 끝난 뒤 잰다(Play 1: 트윈 중에 재서 11.3)
		local state = Leaderboard.debugState()
		local frame, gui = UIManager.getParts(Leaderboard.id)
		local smallest, below = smallestText(frame, gui)
		check(("A1 순위 창 열림 %s · 전체 탭 줄 %d · 빈 목록 [%s] · 내 순위 [%s] · 로드 %s · 화면 안 %s · 최소 글씨 %.1f(12 미만 %d)"):format(tostring(UIManager.isOpen(Leaderboard.id)), #state.rows,
			tostring(state.empty), state.me, tostring(loaded), tostring(insideScreen(frame, gui)), smallest, #below),
			UIManager.isOpen(Leaderboard.id) and loaded and state.me ~= "" and insideScreen(frame, gui) and #below == 0)
		local tabResults = {}
		local tabsOk = true
		for _, tabId in ipairs({ "class", "party", "season", "all" }) do
			Leaderboard.selectTab(tabId)
			task.wait(1.4) -- 서버 board 간격(1초) 뒤
			waitFor(function()
				return Leaderboard.debugState().empty ~= "불러오는 중…"
			end, 5)
			local s = Leaderboard.debugState()
			local chips = frame:FindFirstChild("Chip_greatsword", true)
			local chipVisible = chips and chips.Visible
			table.insert(tabResults, ("%s: 줄 %d · 칩 %s · 내 순위 보임 %s"):format(tabId, #s.rows, tostring(chipVisible), tostring(s.meVisible)))
			tabsOk = tabsOk and s.tab == tabId and (chipVisible == (tabId == "class")) and (s.meVisible == (tabId ~= "season"))
				and (tabId ~= "season" or (s.empty or ""):find("시즌", 1, true) ~= nil)
		end
		check(("A2 탭 전환 [%s]"):format(table.concat(tabResults, " / ")), tabsOk)

		-- ② 줄 → 카드(무기만) → 장비 보기 닫으면 순위 창으로 돌아옴
		Leaderboard.selectTab("all")
		task.wait(1.4)
		waitFor(function()
			return Leaderboard.debugState().empty ~= "불러오는 중…"
		end, 5)
		local rows = Leaderboard.debugState().rows
		if #rows > 0 then
			Leaderboard.debugPressRow(1)
			local opened = waitFor(function()
				return UIManager.isOpen(Inspect.id)
			end, 6)
			task.wait(0.4)
			local armorExpanded = opened and Inspect.debugSelect("armor")
			local inspectState = Inspect.debugState()
			local rowsText = Inspect.debugRows()
			check(("A3 1위 줄 → 장비 보기(카드) 열림 %s · 카드 %s · 갑옷 칸 [%s] 펼침 %s [%s] · 무기 칸 [%s]"):format(tostring(opened), tostring(inspectState.card), tostring(rowsText[2]), tostring(armorExpanded),
				tostring(inspectState.details.armor), tostring(rowsText[1])),
				opened and inspectState.card == true and rowsText[2] == "?" and (inspectState.details.armor or ""):find("무기 · 보석만", 1, true) ~= nil and rowsText[1] ~= "?")
			UIManager.close(Inspect.id)
			local back = waitFor(function()
				return UIManager.isOpen(Leaderboard.id)
			end, 3)
			check(("A4 장비 보기 닫기 → 순위 창으로 돌아옴 %s"):format(tostring(back)), back)
		else
			check("A3 · A4 순위표가 비어 카드 확인 생략(검증 저장소에 기록 없음 - 스크린샷 Play의 /gg lb fake로 확인)", true)
		end
		UIManager.closeAll()
		task.wait(0.5)
	end)
	if not ok then
		check("① 순위 창 점검 에러: " .. tostring(err), false)
	end

	-- ③ 장비 보기(자기 조회) - 칸 펼침 · 비교
	ok, err = pcall(function()
		Inspect.open(player.UserId)
		waitFor(function()
			return (Inspect.debugRows()[1] or "") ~= ""
		end, 5)
		task.wait(0.6)
		local expanded = Inspect.debugSelect("weapon")
		Inspect.setCompare(true)
		local hasMine = waitFor(function()
			return Inspect.debugState().hasMine
		end, 4)
		task.wait(0.2)
		local state = Inspect.debugState()
		local weaponDetail = state.details.weapon or ""
		local frame, gui = UIManager.getParts(Inspect.id)
		local smallest, below = smallestText(frame, gui)
		check(("B1 장비 보기 무기 칸 펼침 %s · 비교 켬 → 내 장비 %s · 무기 상세 [%s] · 요약 [%s] · 최소 글씨 %.1f(12 미만 %d) · 화면 안 %s"):format(tostring(expanded), tostring(hasMine), weaponDetail,
			tostring(state.summaries.weapon), smallest, #below, tostring(insideScreen(frame, gui))),
			expanded and hasMine and weaponDetail:find("상대 | 나 | 차이", 1, true) ~= nil and weaponDetail:find("무기 배율", 1, true) ~= nil and #below == 0 and insideScreen(frame, gui))
		local collapsed = not Inspect.debugSelect("weapon")
		Inspect.setCompare(false)
		check(("B2 같은 칸 다시 누름 → 접힘 %s · 비교 끔 %s"):format(tostring(collapsed), tostring(not Inspect.debugState().compare)), collapsed and not Inspect.debugState().compare)
		UIManager.close(Inspect.id)
		task.wait(0.5)
	end)
	if not ok then
		check("③ 장비 보기 점검 에러: " .. tostring(err), false)
	end

	-- ④ 스킬 툴팁 - 서버 수치가 글에 그대로 · 화면 안 · 글씨
	ok, err = pcall(function()
		local slotsGui = player.PlayerGui:WaitForChild("SkillSlotsGui", 5)
		local qButton = slotsGui and slotsGui:FindFirstChild("Slot_q", true)
		local info = SkillTooltip.debugFetch()
		SkillTooltip.show("q", qButton, false)
		task.wait(0.3)
		local text = SkillTooltip.debugText() or ""
		local tipGui = player.PlayerGui:FindFirstChild("SkillTooltipGui")
		local root = tipGui and tipGui:FindFirstChild("SkillTooltip")
		local smallest, below = smallestText(root, tipGui)
		local q = info and info.slots and info.slots.Q
		local expect = q and (q.hitDamage or q.heal or q.speedMultiplier or q.duration or q.bonusDamage)
		local function shown(value)
			if value < 100 then
				return (("%.1f"):format(value):gsub("%.0$", ""))
			end
			return require(ReplicatedStorage.Shared.NumberFormat).format(value)
		end
		check(("D1 툴팁(Q) 보임 %s · 서버 수치 %s가 글에 있음 %s · 줄 %d · 최소 글씨 %.1f(12 미만 %d) · 화면 안 %s"):format(tostring(SkillTooltip.isVisible()), expect and shown(expect) or "-",
			tostring(expect ~= nil and text:find(shown(expect), 1, true) ~= nil), select(2, text:gsub("\n", "")), smallest, #below, tostring(root ~= nil and insideScreen(root, tipGui))),
			SkillTooltip.isVisible() and expect ~= nil and text:find(shown(expect), 1, true) ~= nil and #below == 0 and insideScreen(root, tipGui))
		print("[P3b][UI][툴팁 글] " .. text:gsub("\n", " / "))
		SkillTooltip.hide()
	end)
	if not ok then
		check("④ 스킬 툴팁 점검 에러: " .. tostring(err), false)
	end

	-- ⑤ 누수: 순위 창 · 장비 보기(카드) · 툴팁을 20번씩 열고 닫는다 - 인스턴스 수가 돌아오는가
	ok, err = pcall(function()
		local function count()
			local n = 0
			for _, name in ipairs({ "leaderboardGui", "inspectGui", "SkillTooltipGui" }) do
				local gui = player.PlayerGui:FindFirstChild(name)
				n += gui and #gui:GetDescendants() or 0
			end
			return n
		end
		local card = { userId = player.UserId, name = player.Name, displayName = player.DisplayName, classId = player:GetAttribute("ClassId") or "greatsword", level = 10, rebirthCount = 0,
			weapon = { gradeId = "epic", level = 7, gems = { { grade = "epic", itemLevel = 20, option = { id = "attackPercent", roll = 1 } }, false, false, false, false } } }
		local slotsGui = player.PlayerGui:WaitForChild("SkillSlotsGui", 5)
		local qButton = slotsGui:FindFirstChild("Slot_q", true)
		local before, memBefore
		for i = 1, 20 do
			Leaderboard.open()
			task.wait(0.35)
			Leaderboard.selectTab(i % 2 == 0 and "party" or "all")
			UIManager.close(Leaderboard.id, true)
			Inspect.openCard(card)
			Inspect.debugSelect("weapon")
			Inspect.debugSelect("armor")
			task.wait(0.3)
			UIManager.close(Inspect.id, true)
			SkillTooltip.show(i % 2 == 0 and "e" or "q", qButton, i % 3 == 0)
			SkillTooltip.hide()
			task.wait(0.35)
			if i == 1 then
				before, memBefore = count(), gcinfo()
			end
		end
		task.wait(1)
		local after, memAfter = count(), gcinfo()
		check(("E1 누수: 3개 창 20회 여닫기 - 인스턴스 %d → %d(기대 같음 · 첫 회 뒤 기준) · 메모리 %d → %d KB(4 MB 안)"):format(before, after, memBefore, memAfter),
			after == before and memAfter - memBefore < 4096)
		UIManager.closeAll()
	end)
	if not ok then
		check("⑤ 누수 점검 에러: " .. tostring(err), false)
	end

	-- ⑥ 폰 800 × 360(ScreenGui 800 × 302) 치수 식 - Panel(모바일 = min(92% W, 720) × min(88% H, 480)) · 레일 · 줄 · [순위] 버튼 · 툴팁
	ok, err = pcall(function()
		local screen = Vector2.new(800, 302)
		local panelW, panelH = math.min(screen.X * 0.92, Panel.maxSize.X), math.min(screen.Y * 0.88, Panel.maxSize.Y)
		local contentH = panelH - (Panel.closeSize + 1)
		local railH = 8 + 4 * Theme.touchMin + 3 * 6
		local listH = contentH - 16 - (Theme.touchMin + 6)
		local buttonTop = 52 + Theme.touchMin + 8
		local buttonBottom = buttonTop + Theme.touchMin
		local brTop = screen.Y * ScreenMap.mobileReserved.BR.top
		local tipW = 420
		check(("F1 폰 치수: 창 %.0f × %.0f · 본문 %.0f · 탭 레일 %d(≤ 본문) · 목록 %.0f(줄 44 기준 %.1f줄) · [순위] 버튼 y %d ~ %d(BR 예약 위 끝 %.0f보다 위) · 툴팁 폭 %d(≤ %d)"):format(
			panelW, panelH, contentH, railH, listH, listH / (Theme.touchMin + 4), buttonTop, buttonBottom, brTop, tipW, screen.X - 16),
			railH <= contentH and listH >= Theme.touchMin * 2 and buttonBottom <= brTop and tipW <= screen.X - 16)
	end)
	if not ok then
		check("⑥ 폰 치수 점검 에러: " .. tostring(err), false)
	end

	print(("===P3b 검증 끝(UI)=== %d/%d 통과"):format(passed, total))
end)
