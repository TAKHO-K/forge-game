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
local UIManager = require(script.Parent.Parent.UIManager)

local player = Players.LocalPlayer
local CHECK_DELAY = 30 -- PanelFitCheck(10초부터 패널을 차례로 연다)가 끝난 뒤

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
