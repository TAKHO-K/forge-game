-- 스테이지 선택 자체 점검 S15(UI)(PRD 20.81 [C-4] · [D-1]). Studio에서만, DevToolsConfig.verify에 "S15(UI)"가 있을 때(또는 회귀 전체)만 돈다.
-- 순수 함수(창 정렬 · 칩 묶음 · 칩 상태 · 칩 글) + 실제 패널의 격자 · 칩 · 등록 규칙. 서버 없이 클라만으로 돈다.
-- 로컬 Attribute(InfiniteStageBest · BestBossCleared · Tutorial*)를 잠깐 바꿔 그리고 끝에 원래 값으로 돌린다. 클릭 · 키 입력은 여기서 못 한다 - 사람이 확인하는 별도 Play(실제 입력)가 한다.
-- 결과: `[S15][UI] … O/X` + 요약 `===S15 검증 끝(UI)=== n/m 통과`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S15(UI)")) then
	return
end

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local PanelRegistry = require(script.Parent.PanelRegistry)
local StageRewardBand = require(script.Parent.Parent.StageRewardBand)
local StageSelectPanel = require(script.Parent.Parent.StageSelectPanel)
local Theme = require(script.Parent.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local CHECK_DELAY = 30 -- PanelFitCheck(10초부터 패널을 차례로 연다)가 끝난 뒤

-- WCAG 상대 휘도 · 명암비(sRGB) + "바탕 위에 반투명 색을 얹었을 때 보이는 색"(transparency = Roblox 투명도, 0이 불투명).
local function channel(value)
	return value <= 0.03928 and value / 12.92 or ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color)
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

local function contrast(a, b)
	local la, lb = luminance(a), luminance(b)
	return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
end

local function blend(top, transparency, under)
	return Color3.new(
		top.R * (1 - transparency) + under.R * transparency,
		top.G * (1 - transparency) + under.G * transparency,
		top.B * (1 - transparency) + under.B * transparency
	)
end

local function lineCount(text)
	local count = 1
	for _ in text:gmatch("\n") do
		count += 1
	end
	return count
end

local function flat(text)
	return (text:gsub("\n", "/"))
end

local function run()
	local debug = StageSelectPanel.debug
	local pass, total = 0, 0
	print("===S15 검증 시작(UI: 10칸 구간 · 구간 칩 · station 등록)===")
	local function check(label, passed)
		total += 1
		if passed then
			pass += 1
		end
		print(("[S15][UI] %s %s"):format(label, passed and "O" or "X"))
	end

	local touched = { "InfiniteStageBest", "BestBossCleared", "TutorialCompleted", "TutorialStep" }
	local saved = {}
	for index, name in ipairs(touched) do
		saved[index] = player:GetAttribute(name) -- nil이면 되돌릴 때 속성을 지운다(pairs가 아니라 인덱스로 돈다)
	end

	local ok, err = pcall(function()
		local alignedStart, chipGroupOf, chipState = debug.alignedStart, debug.chipGroupOf, debug.chipState
		local cells, chips = debug.cells, debug.chips

		-- 순수 함수
		check(("창 정렬: 48 → %d · 1 → %d · 10 → %d · 11 → %d · 51 → %d · 12341 → %d · 12340 → %d(기대 41 · 1 · 1 · 11 · 51 · 12341 · 12331)"):format(
			alignedStart(48), alignedStart(1), alignedStart(10), alignedStart(11), alignedStart(51), alignedStart(12341), alignedStart(12340)),
			alignedStart(48) == 41 and alignedStart(1) == 1 and alignedStart(10) == 1 and alignedStart(11) == 11 and alignedStart(51) == 51 and alignedStart(12341) == 12341 and alignedStart(12340) == 12331)
		check(("칩 묶음 시작: 1 → %d · 50 → %d · 51 → %d · 12341 → %d(기대 1 · 1 · 51 · 12301)"):format(chipGroupOf(1), chipGroupOf(50), chipGroupOf(51), chipGroupOf(12341)),
			chipGroupOf(1) == 1 and chipGroupOf(50) == 1 and chipGroupOf(51) == 51 and chipGroupOf(12341) == 12301)
		check(("칩 상태(best 47 · 보스 45까지): 1-10 %s · 41-50 %s · 51-60 %s(기대 cleared · front · locked)"):format(
			chipState(1, 10, 47, 45), chipState(41, 50, 47, 45), chipState(51, 60, 47, 45)),
			chipState(1, 10, 47, 45) == "cleared" and chipState(41, 50, 47, 45) == "front" and chipState(51, 60, 47, 45) == "locked")
		check(("칩 상태 경계: best 49(최전선 50) 41-50 %s · best 50(최전선 51) 41-50 %s(보스 50까지) · 51-60 %s · 일부만 깬 구간(best 60 · 보스 45) 41-50 %s(기대 front · cleared · front · open)"):format(
			chipState(41, 50, 49, 45), chipState(41, 50, 50, 50), chipState(51, 60, 50, 50), chipState(41, 50, 60, 45)),
			chipState(41, 50, 49, 45) == "front" and chipState(41, 50, 50, 50) == "cleared" and chipState(51, 60, 50, 50) == "front" and chipState(41, 50, 60, 45) == "open")

		-- 칩 글: 실제 자(TextService)로 폭 ≤ 칩 글자 자리 · 줄 수 ≤ 2
		local sampleOk, sampleText = true, {}
		for _, range in ipairs({ { 41, 50 }, { 101, 110 }, { 1001, 1010 }, { 12341, 12350 }, { 99991, 100000 } }) do
			local text = debug.chipText("●", range[1], range[2], debug.chipTextRoom, debug.measureChipText)
			local width = debug.measureChipText(text)
			table.insert(sampleText, ("%s(%dpx · %d줄)"):format(flat(text), width, lineCount(text)))
			-- 5자리까지는 자리 안에 들어가야 한다. 6자리(100000)는 자리가 모자랄 수 있어 보고만 한다.
			if range[1] < 100000 and (width > debug.chipTextRoom or lineCount(text) > 2) then
				sampleOk = false
			end
		end
		check(("칩 글(자리 %dpx, 글씨 %d 고정): %s(기대 5자리까지 자리 안 · 2줄 이내)"):format(debug.chipTextRoom, debug.chipTextSize, table.concat(sampleText, " · ")), sampleOk)

		-- 실제 패널: 견습 아님 · 최고 47 · 보스 45
		player:SetAttribute("TutorialCompleted", true)
		player:SetAttribute("InfiniteStageBest", 47)
		player:SetAttribute("BestBossCleared", 45)
		UIManager.closeAll()
		local opened = UIManager.open("stageSelect")
		task.wait(0.4)
		local windowStart, chipStart = debug.getWindow()
		check(("최고 47에서 열림: 열림=%s · 창 시작 %d · 칩 묶음 시작 %d(기대 true · 41 · 1)"):format(tostring(opened), windowStart, chipStart), opened and windowStart == 41 and chipStart == 1)
		check(("첫 칸 %d · 다섯 번째 칸 %d · 열 번째 칸 %d(기대 41 · 45 · 50 - 보스 칸이 5 · 10번째 자리)"):format(cells[1].stage or -1, cells[5].stage or -1, cells[10].stage or -1),
			cells[1].stage == 41 and cells[5].stage == 45 and cells[10].stage == 50)
		check(("칩 5 = %s(기대 ● 포함 · ember색) · 칩 1 = %s(기대 ✓ 포함 · textTertiary색) · 보고 있는 구간 칩의 테두리 두께 %.1f(기대 2)"):format(
			flat(chips[5].button.Text), flat(chips[1].button.Text), chips[5].stroke.Thickness),
			chips[5].button.Text:find("●", 1, true) ~= nil and chips[5].button.TextColor3 == UIColors.ember
				and chips[1].button.Text:find("✓", 1, true) ~= nil and chips[1].button.TextColor3 == UIColors.textTertiary and chips[5].stroke.Thickness == 2)

		-- 어느 구간을 봐도 보스 칸이 5 · 10번째 자리(★진짜 합격 기준 ①)
		local bossPlaceOk, bossPlaceText = true, {}
		for _, start in ipairs({ 1, 11, 41, 51, 12341, 99991 }) do
			debug.showWindow(start)
			local bossPositions = {}
			for i, cell in ipairs(cells) do
				if StageRewardBand.isBossStage(cell.stage) then
					table.insert(bossPositions, i)
				end
			end
			table.insert(bossPlaceText, ("%d~ → 보스 칸 %s"):format(start, table.concat(bossPositions, "·")))
			if #bossPositions ~= 2 or bossPositions[1] ~= 5 or bossPositions[2] ~= 10 then
				bossPlaceOk = false
			end
		end
		check(("★어느 구간을 봐도 보스 칸이 5 · 10번째 자리: %s(기대 전부 5·10)"):format(table.concat(bossPlaceText, " · ")), bossPlaceOk)

		-- 매우 큰 최고 스테이지(12,340): 칩 글이 칩 폭을 넘지 않는다(TextBounds ≤ 칩 폭)
		player:SetAttribute("InfiniteStageBest", 12340)
		player:SetAttribute("BestBossCleared", 12335)
		UIManager.closeAll()
		task.wait(0.2)
		UIManager.open("stageSelect")
		task.wait(0.4)
		local overflow, widest = 0, 0
		for _, chip in ipairs(chips) do
			local bounds = chip.button.TextBounds.X
			widest = math.max(widest, bounds)
			if bounds > chip.button.AbsoluteSize.X - 2 then
				overflow += 1
			end
		end
		windowStart = debug.getWindow()
		check(("최고 12,340: 창 시작 %d · 칩 글이 칩 폭을 넘는 칩 %d개 · 가장 넓은 글 %.0fpx / 칩 폭 %.0fpx(기대 12341 · 0개)"):format(windowStart, overflow, widest, chips[1].button.AbsoluteSize.X),
			windowStart == 12341 and overflow == 0)

		-- S16 사전 작업 1: 잠긴 칩 글씨 대비(칩 바탕 · 패널 바탕 - 세계 검정/흰색 양쪽 최악) ≥ 4.5. 값은 실제 인스턴스에서 읽는다.
		player:SetAttribute("InfiniteStageBest", 12)
		player:SetAttribute("BestBossCleared", 0)
		UIManager.closeAll()
		task.wait(0.2)
		UIManager.open("stageSelect")
		task.wait(0.4)
		local lockedChip = chips[3].button -- 최고 12 → 최전선 13(11-20)이라 21-30부터 잠김
		local panelFrame = debug.panel
		local worst = math.huge
		local panelWorst = math.huge
		for _, world in ipairs({ Color3.new(0, 0, 0), Color3.new(1, 1, 1) }) do
			local panelSeen = blend(panelFrame.BackgroundColor3, panelFrame.BackgroundTransparency, world)
			local chipSeen = blend(lockedChip.BackgroundColor3, lockedChip.BackgroundTransparency, panelSeen)
			worst = math.min(worst, contrast(lockedChip.TextColor3, chipSeen))
			panelWorst = math.min(panelWorst, contrast(lockedChip.TextColor3, panelSeen))
		end
		check(("잠긴 칩 글씨(%s) 대비: 칩 바탕 최악 %.2f · 패널 바탕 최악 %.2f(기대 둘 다 ≥ 4.5 · 예전 lockedIcon은 칩 바탕 %.2f) · 색 = UIColors.lockedText %s"):format(
			flat(lockedChip.Text), worst, panelWorst, contrast(UIColors.lockedIcon, blend(lockedChip.BackgroundColor3, lockedChip.BackgroundTransparency, blend(panelFrame.BackgroundColor3, panelFrame.BackgroundTransparency, Color3.new(1, 1, 1)))),
			tostring(lockedChip.TextColor3 == UIColors.lockedText)),
			worst >= 4.5 and panelWorst >= 4.5 and lockedChip.TextColor3 == UIColors.lockedText)

		-- S16 사전 작업(사용자 결정): 색만으로 구분하지 않는다 - 잠긴 칩에는 자물쇠 그림. 그림 · 글 모두 실효 12px 이상 · 명암비 4.5 이상 · 서로 안 겹침 · 안 잠긴 칩에는 없다.
		local function lockLayout(chip)
			local button = chip.button
			local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
			local iconWorst = math.huge
			local chipPos, chipSize = button.AbsolutePosition, button.AbsoluteSize
			for _, world in ipairs({ Color3.new(0, 0, 0), Color3.new(1, 1, 1) }) do
				local seen = blend(button.BackgroundColor3, button.BackgroundTransparency, blend(panelFrame.BackgroundColor3, panelFrame.BackgroundTransparency, world))
				for _, part in ipairs(chip.lock:GetChildren()) do
					if part:IsA("Frame") then
						iconWorst = math.min(iconWorst, contrast(part.BackgroundColor3, seen))
					end
				end
			end
			for _, part in ipairs(chip.lock:GetChildren()) do
				if part:IsA("Frame") then
					minX, minY = math.min(minX, part.AbsolutePosition.X), math.min(minY, part.AbsolutePosition.Y)
					maxX, maxY = math.max(maxX, part.AbsolutePosition.X + part.AbsoluteSize.X), math.max(maxY, part.AbsolutePosition.Y + part.AbsoluteSize.Y)
				end
			end
			local pad = chip.padding.PaddingLeft.Offset
			local textLeft = chipPos.X + pad + (chipSize.X - pad - button.TextBounds.X) / 2
			local textRight = textLeft + button.TextBounds.X
			local insideChip = minX >= chipPos.X - 2 and maxX <= chipPos.X + chipSize.X and minY >= chipPos.Y and maxY <= chipPos.Y + chipSize.Y
			return {
				drawnW = maxX - minX, drawnH = maxY - minY, iconWorst = iconWorst, gap = textLeft - maxX, insideChip = insideChip,
				textInside = textRight <= chipPos.X + chipSize.X - 1, visible = chip.lock.Visible,
			}
		end
		local lockInfo = lockLayout(chips[3])
		local unlockedNoLock = not chips[1].lock.Visible and not chips[2].lock.Visible and chips[2].padding.PaddingLeft.Offset == 0
		check(("잠긴 칩 자물쇠(%s): 그려진 크기 %.1f × %.1f px(기대 ≥ 12) · 명암비 최악 %.2f(기대 ≥ 4.5) · 칩 안 %s · 글과의 간격 %.1fpx(기대 ≥ 1) · 글 안 잘림 %s · 안 잠긴 칩에는 없음 %s"):format(
			flat(chips[3].button.Text), lockInfo.drawnW, lockInfo.drawnH, lockInfo.iconWorst, tostring(lockInfo.insideChip), lockInfo.gap, tostring(lockInfo.textInside), tostring(unlockedNoLock)),
			lockInfo.visible and lockInfo.drawnW >= 12 and lockInfo.drawnH >= 12 and lockInfo.iconWorst >= 4.5 and lockInfo.insideChip and lockInfo.gap >= 1 and lockInfo.textInside and unlockedNoLock)
		-- 잠긴 칩 4자리(두 줄) · 3자리 글도 자물쇠와 안 겹치고 칩 안에 든다.
		local lockSamples, lockSamplesOk = {}, true
		for _, best in ipairs({ 100, 1000 }) do
			player:SetAttribute("InfiniteStageBest", best)
			player:SetAttribute("BestBossCleared", best - 5)
			UIManager.closeAll()
			task.wait(0.2)
			UIManager.open("stageSelect")
			task.wait(0.4)
			for index, chip in ipairs(chips) do
				if chip.lock.Visible then
					local info = lockLayout(chip)
					table.insert(lockSamples, ("최고 %d 칩%d %s(%.0f × %.0f · 간격 %.1f)"):format(best, index, flat(chip.button.Text), info.drawnW, info.drawnH, info.gap))
					lockSamplesOk = lockSamplesOk and info.insideChip and info.gap >= 1 and info.textInside and lineCount(chip.button.Text) <= 2
					break
				end
			end
		end
		check(("잠긴 칩 3 · 4자리 글: %s(기대 칩 안 · 자물쇠와 간격 ≥ 1 · 2줄 이내)"):format(table.concat(lockSamples, " · ")), #lockSamples == 2 and lockSamplesOk)
		player:SetAttribute("InfiniteStageBest", 12)
		player:SetAttribute("BestBossCleared", 0)
		UIManager.closeAll()
		task.wait(0.2)
		UIManager.open("stageSelect")
		task.wait(0.4)

		-- S16 사전 작업(사용자 결정): 칸 번호 색 - 칸 바탕 대비 4.5 이상(10칸, 세계 검정/흰색 최악)
		local numberWorst = math.huge
		for _, cell in ipairs(cells) do
			for _, world in ipairs({ Color3.new(0, 0, 0), Color3.new(1, 1, 1) }) do
				local seen = blend(cell.button.BackgroundColor3, cell.button.BackgroundTransparency, blend(panelFrame.BackgroundColor3, panelFrame.BackgroundTransparency, world))
				numberWorst = math.min(numberWorst, contrast(cell.number.TextColor3, seen))
			end
		end
		check(("칸 번호 색 대비: 10칸 최악 %.2f(기대 ≥ 4.5 · 예전 textTertiary는 %.2f) · 색 = textSecondary %s"):format(
			numberWorst, contrast(UIColors.textTertiary, blend(cells[1].button.BackgroundColor3, cells[1].button.BackgroundTransparency, blend(panelFrame.BackgroundColor3, panelFrame.BackgroundTransparency, Color3.new(1, 1, 1)))),
			tostring(cells[1].number.TextColor3 == UIColors.textSecondary)), numberWorst >= 4.5 and cells[1].number.TextColor3 == UIColors.textSecondary)

		-- S16 사전 작업 2: 칸 번호 실효 글씨 ≥ 12(10칸) · X 버튼 터치 영역 ≥ 44 × 44 · 칸 · 칩이 패널 폭 안(잘림 없음)
		local smallest, smallCount = math.huge, 0
		for _, cell in ipairs(cells) do
			local size = Theme.effectiveTextSize(cell.number)
			smallest = math.min(smallest, size)
			if size < Theme.minTextSize then
				smallCount += 1
			end
		end
		check(("칸 번호 실효 글씨: 최소 %.1fpx · 12 미만 %d칸 / %d칸(기대 0 · 최소 ≥ 12)"):format(smallest, smallCount, #cells), smallCount == 0 and #cells == 10 and smallest >= Theme.minTextSize)
		local closeSize, dotSize = debug.closeButton.AbsoluteSize, debug.closeDot.AbsoluteSize
		local closeCenter = debug.closeButton.AbsolutePosition + closeSize / 2
		local dotCenter = debug.closeDot.AbsolutePosition + dotSize / 2
		local panelPos, panelSize = panelFrame.AbsolutePosition, panelFrame.AbsoluteSize
		local closeInside = debug.closeButton.AbsolutePosition.X >= panelPos.X and debug.closeButton.AbsolutePosition.Y >= panelPos.Y
			and debug.closeButton.AbsolutePosition.X + closeSize.X <= panelPos.X + panelSize.X and debug.closeButton.AbsolutePosition.Y + closeSize.Y <= panelPos.Y + panelSize.Y
		check(("X 버튼: 터치 %.0f × %.0f(기대 ≥ 44 × 44) · 보이는 원 %.0f × %.0f · 두 중심 차 %.1fpx · 패널 안 %s"):format(
			closeSize.X, closeSize.Y, dotSize.X, dotSize.Y, (closeCenter - dotCenter).Magnitude, tostring(closeInside)),
			closeSize.X >= 44 and closeSize.Y >= 44 and (closeCenter - dotCenter).Magnitude < 1 and closeInside)
		local clipped = 0
		local function insideWidth(inst)
			local left, right = inst.AbsolutePosition.X, inst.AbsolutePosition.X + inst.AbsoluteSize.X
			return left >= panelPos.X - 0.5 and right <= panelPos.X + panelSize.X + 0.5
		end
		for _, cell in ipairs(cells) do
			clipped += insideWidth(cell.button) and 0 or 1
		end
		for _, chip in ipairs(chips) do
			clipped += insideWidth(chip.button) and 0 or 1
		end
		clipped += insideWidth(debug.chipPrevButton) and 0 or 1
		clipped += insideWidth(debug.chipNextButton) and 0 or 1
		local viewport = panelFrame:FindFirstAncestorOfClass("ScreenGui").AbsoluteSize
		check(("폭 %.0f × 높이 %.0f 화면: 패널 폭 %.0f 안에서 잘린 칸 · 칩 · ◀ ▶ %d개(기대 0) · 패널 폭 ≤ 화면 폭 %s"):format(
			viewport.X, viewport.Y, panelSize.X, clipped, tostring(panelSize.X <= viewport.X)), clipped == 0 and panelSize.X <= viewport.X)

		-- 등록 규칙: 단축키 M · station · 가방(window)을 열면 닫힘 · window가 열려 있으면 안 열림 · 견습 중 안 열림
		UIManager.closeAll()
		task.wait(0.3)
		UIManager.open("stageSelect")
		task.wait(0.3)
		local wasOpen = UIManager.isOpen("stageSelect")
		UIManager.open("inventory")
		task.wait(0.3)
		local closedByWindow = not UIManager.isOpen("stageSelect")
		local blockedByWindow = UIManager.open("stageSelect") == false
		UIManager.closeAll()
		task.wait(0.3)
		player:SetAttribute("TutorialCompleted", false)
		player:SetAttribute("TutorialStep", 2)
		local blockedByTutorial = UIManager.open("stageSelect") == false and not UIManager.isOpen("stageSelect")
		player:SetAttribute("TutorialCompleted", true)
		check(("등록: 단축키 %s(기대 M) · 종류 %s(기대 station) · 열린 뒤 가방(window)을 열면 닫힘=%s · window가 열려 있으면 안 열림=%s · 견습 중 안 열림=%s(기대 전부 true)"):format(
			tostring(PanelRegistry.hotkeyOf("stageSelect")), tostring(UIManager.getKind("stageSelect")), tostring(wasOpen and closedByWindow), tostring(blockedByWindow), tostring(blockedByTutorial)),
			PanelRegistry.hotkeyOf("stageSelect") == Enum.KeyCode.M and UIManager.getKind("stageSelect") == "station" and wasOpen and closedByWindow and blockedByWindow and blockedByTutorial)
	end)
	if not ok then
		check(("자체 점검 실행 중 에러: %s"):format(tostring(err)), false)
	end
	UIManager.closeAll()
	for index, name in ipairs(touched) do
		player:SetAttribute(name, saved[index])
	end
	print(("===S15 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

task.delay(CHECK_DELAY, run)
