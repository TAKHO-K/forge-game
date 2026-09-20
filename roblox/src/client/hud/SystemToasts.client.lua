-- 시스템 토스트 5종(S17, PRD 20.81 [D-3] · [D-6] 6번). 옛 SaveNoticeHud · LevelUpHud · ZoneBlockedHud · TreasureChestHud · ItemPickupHud는 각자 Frame을 세우고 y를 따로 잡아서
-- 동시에 뜨면 겹쳤다(레벨업 글씨가 구역 차단 배너에 가려졌다). 이제 Toast 줄 한 곳으로 모인다 - 문구 · 색 · 표시 시간 · 뜨는 조건(서버 RemoteEvent)은 그대로고 자리만 지도(ScreenMap)의 줄이다.
--   TC(시스템 줄): 저장 · 레벨업 · 구역 차단 · 보물상자 / BC(획득 팝업 줄): 아이템 줍기 - 1초 안의 여러 건은 groupKey로 묶는다("전설 장갑 획득 (Lv.52) 외 2").
--   색: 옛 배경색(구역 차단 ember · 보물상자 gold 바탕)은 Toast 모양(panel 바탕)에 맞춰 글씨색으로 옮겼다. 레벨업 xp · 아이템 등급색은 옛 글씨색 그대로다.
--   등급(S17 미결 결정 2026-09-20, PRD 20.103 [10]): 저장 실패 = critical(빨간 바탕 16pt · 최소 6초 · 밀리지 않음) · 레벨업 = important(16pt 굵게 + xp 색) · 나머지 = 일반. 모양 · 시간 규칙은 Toast.grades.
--   표시 시간 = 옛 DISPLAY_SECONDS 그대로(6 · 2 · 2 · 5 · 1.6), 사라지는 트윈이 있던 것은 fadeSeconds로 옮겼다(저장 0.5 · 레벨업 0.5 · 구역 0.3 · 상자 0.3). 아이템 줍기는 옛 1.6초 내내 서서히 사라졌다 → 0.8 + 흐림 0.8(총 1.6).
-- 새 시스템 알림은 아래 SIGNALS 표에 한 줄 넣는다(자체 점검이 표와 실제 연결을 대조한다). 자체 점검(`[S17][UI]`)은 이 파일 끝에 있다: Studio에서 DevToolsConfig.verify에 "S17(UI)"가 있을 때만(또는 회귀 전체).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local player = Players.LocalPlayer

-- 신호 표: 서버 RemoteEvent 이름 → 줄 · 토스트 항목을 만드는 함수(받은 값 → Toast.push의 item).
local SIGNALS = {
	{ remote = "SaveNotice", lane = "TC", make = function(message)
		return { text = message, grade = "critical", seconds = 6, fadeSeconds = 0.5 }
	end },
	{ remote = "LevelUp", lane = "TC", make = function(newLevel)
		return { text = ("레벨업! Lv.%d"):format(newLevel), grade = "important", colorName = "xp", seconds = 2, fadeSeconds = 0.5 }
	end },
	{ remote = "ZoneBlockedNotice", lane = "TC", make = function(message)
		return { text = message, colorName = "ember", seconds = 2, fadeSeconds = 0.3 }
	end },
	{ remote = "TreasureChestNotice", lane = "TC", make = function(message)
		return { text = message, colorName = "gold", seconds = 5, fadeSeconds = 0.3 }
	end },
	{ remote = "ItemPickedUp", lane = "BC", make = function(item)
		local grade = ArmorData.grades[item.grade]
		local visual = ItemVisualData.gradeVisuals[item.grade]
		local partName = ItemVisualData.partDisplayNames[item.part or "armor"] or "장비"
		local text = ("%s %s 획득 (Lv.%d)"):format(grade and grade.displayName or item.grade, partName, item.itemLevel)
		return {
			richParts = { { text = text, color = visual and visual.color or Color3.new(1, 1, 1), size = visual and visual.toastTextSize or 18 } },
			groupKey = "itemPickup", moreFormat = " 외 %d", seconds = 0.8, fadeSeconds = 0.8,
		}
	end },
}

local connected = {} -- remote 이름 → 연결됨(자체 점검이 표와 대조한다)
for _, signal in ipairs(SIGNALS) do
	task.spawn(function()
		local remote = ReplicatedStorage:WaitForChild(signal.remote)
		remote.OnClientEvent:Connect(function(...)
			Toast.push(signal.lane, signal.make(...))
		end)
		connected[signal.remote] = true
	end)
end

-- ═══ 자체 점검 [S17][UI] (Studio · verify에 "S17(UI)"가 있을 때) ═══
-- 다른 클라 점검(S16 메뉴바 75초 + 약 15초)이 Toast 줄을 쓰므로 그 뒤에 돈다. 실제 RemoteEvent 발신(서버 → 클라)은 여기서 못 한다 - 별도 스크린샷 Play가 서버 execute_luau로 쏜다.
-- 여기서는 연결이 걸린 RemoteEvent 5개가 표와 같은지 보고, 신호가 부르는 것과 같은 함수(make → Toast.push)를 합성 값으로 불러 문구 · 색 · 시간 · 줄을 옛 코드 값과 대조한다.
local CHECK_DELAY = 100

local function selfCheck()
	local pass, total = 0, 0
	print("===S17 검증 시작(UI: 시스템 토스트 5종 → Toast)===")
	local function check(label, passed)
		total += 1
		if passed then
			pass += 1
		end
		print(("[S17][UI] %s %s"):format(label, passed and "O" or "X"))
	end
	local function laneRow(laneName)
		local gui = player.PlayerGui:FindFirstChild("ToastGui")
		local lane = gui and gui:FindFirstChild(laneName == "TC" and "ToastLane_TC" or "ToastLane_BC")
		return lane and lane:FindFirstChild("ToastRow")
	end

	local ok, err = pcall(function()
		Toast.clear()

		-- 옛 코드의 값(대조표). 문구 · 색 · 표시 시간 · 사라짐 트윈 · 줄 - 옛 파일에서 그대로 옮겼다.
		local sampleItem = { grade = "legendary", part = "gloves", itemLevel = 52 }
		local visual = ItemVisualData.gradeVisuals.legendary
		local pickupText = ("%s %s 획득 (Lv.%d)"):format(ArmorData.grades.legendary.displayName, ItemVisualData.partDisplayNames.gloves, 52)
		local cases = {
			{ remote = "SaveNotice", value = "저장에 반복 실패했습니다. 지금까지의 변경사항이 저장되지 않았을 수 있습니다.", lane = "TC", text = "저장에 반복 실패했습니다. 지금까지의 변경사항이 저장되지 않았을 수 있습니다.", color = "textPrimary", grade = "critical", seconds = 6, fade = 0.5 },
			{ remote = "LevelUp", value = 41, lane = "TC", text = "레벨업! Lv.41", color = "xp", grade = "important", seconds = 2, fade = 0.5 },
			{ remote = "ZoneBlockedNotice", value = "구역 안으로 들어가야 공격할 수 있습니다", lane = "TC", text = "구역 안으로 들어가야 공격할 수 있습니다", color = "ember", seconds = 2, fade = 0.3 },
			{ remote = "TreasureChestNotice", value = "보물상자가 tier 3 숲의 정령 구역에 나타났습니다! 함께 부수면 모두가 보상을 받습니다", lane = "TC", text = "보물상자가 tier 3 숲의 정령 구역에 나타났습니다! 함께 부수면 모두가 보상을 받습니다", color = "gold", seconds = 5, fade = 0.3 },
			{ remote = "ItemPickedUp", value = sampleItem, lane = "BC", text = pickupText, rich = true, seconds = 0.8, fade = 0.8 },
		}

		-- 1. 신호 표 대조: 표 5줄 = 옛 RemoteEvent 5개 · 서버에 실제로 있고 · 연결이 걸렸다 · 옛 ScreenGui 5개는 없다
		local rows, tableOk = {}, #SIGNALS == #cases
		for index, case in ipairs(cases) do
			local signal = SIGNALS[index]
			local exists = ReplicatedStorage:FindFirstChild(case.remote) ~= nil
			local rowOk = signal ~= nil and signal.remote == case.remote and signal.lane == case.lane and exists and connected[case.remote] == true
			tableOk = tableOk and rowOk
			table.insert(rows, ("%s → %s(서버 있음 %s · 연결 %s)"):format(case.remote, case.lane, tostring(exists), tostring(connected[case.remote] == true)))
		end
		local oldGuis = {}
		for _, name in ipairs({ "SaveNoticeGui", "LevelUpHudGui", "ZoneBlockedGui", "TreasureChestGui", "ItemPickupHudGui" }) do
			if player.PlayerGui:FindFirstChild(name) then
				table.insert(oldGuis, name)
			end
		end
		check(("신호 표 대조: 표 %d줄(기대 5) %s · 옛 알림 ScreenGui %d개(기대 0) %s"):format(#SIGNALS, table.concat(rows, " · "), #oldGuis, table.concat(oldGuis, ",")), tableOk and #oldGuis == 0)

		-- 2. 신호마다: make(값)의 문구 · 색 · 시간 · 흐림을 옛 값과 대조하고, 같은 함수로 실제로 띄워 줄 · 글씨색 · 실효 글씨 크기를 본다
		for index, case in ipairs(cases) do
			Toast.clear()
			local item = SIGNALS[index].make(case.value)
			local shownText = item.text or (item.richParts and item.richParts[1].text)
			local specOk = shownText == case.text and item.seconds == case.seconds and item.fadeSeconds == case.fade and item.grade == case.grade
			local colorText
			if case.rich then
				local part = item.richParts[1]
				specOk = specOk and part.color == visual.color and part.size == visual.toastTextSize and item.groupKey == "itemPickup"
				colorText = ("등급색 %s · 글씨 %d(등급표 %d)"):format(tostring(part.color), part.size, visual.toastTextSize)
			else
				specOk = specOk and item.colorName == case.color
				colorText = "글씨색 " .. tostring(item.colorName)
			end
			local result = Toast.push(SIGNALS[index].lane, item)
			task.wait(0.2)
			local row = laneRow(case.lane)
			local label = row and row:FindFirstChild("Text")
			local textAtScreen = (Toast.debugTexts(case.lane)[1] or "")
			local shown = result == "shown" and row ~= nil and label ~= nil and textAtScreen == case.text
			local colorOk = case.rich or (label ~= nil and label.TextColor3 == UIColors[case.color])
			local sizeOk = label ~= nil and Theme.effectiveTextSize(label) >= Theme.minTextSize
			if case.grade and label then -- 등급 모양: 글씨 = 등급 크기(낮은 화면이면 12) · 굵게 · 치명은 빨간 바탕
				local gradeDef = Toast.grades[case.grade]
				sizeOk = sizeOk and label.TextSize == Toast.gradeTextSize(row.AbsoluteSize.Y, gradeDef) and label.Font == Theme.font
				sizeOk = sizeOk and (gradeDef.backgroundName == nil or row.BackgroundColor3 == UIColors[gradeDef.backgroundName])
			end
			check(("%s 대조: 문구 %s · %s · 표시 %s초 + 흐림 %s(옛 %s + %s) · 줄 %s · 실제로 뜸 %s(%s) · 실제 글씨색 %s · 글씨 실효 12 이상 %s"):format(
				case.remote, tostring(shownText == case.text), colorText, tostring(item.seconds), tostring(item.fadeSeconds), tostring(case.seconds), tostring(case.fade), case.lane,
				tostring(shown), tostring(result), tostring(colorOk), tostring(sizeOk)),
				specOk and shown and colorOk and sizeOk)
		end

		-- 3. 동시 발생: 저장 + 레벨업 + 구역 차단 + 보물상자를 한 프레임에 → 한 줄만 보이고(겹치는 행 없음) 나머지는 대기열에서 순서대로 나온다
		Toast.clear()
		local results = {}
		for _, index in ipairs({ 1, 2, 3, 4 }) do
			table.insert(results, Toast.push(SIGNALS[index].lane, SIGNALS[index].make(cases[index].value)))
		end
		task.wait(0.2)
		local state = Toast.debugState("TC")
		local visibleRows = 0
		local rowRects = {}
		local gui = player.PlayerGui:FindFirstChild("ToastGui")
		local tcLane = gui and gui:FindFirstChild("ToastLane_TC")
		for _, child in ipairs(tcLane and tcLane:GetChildren() or {}) do
			if child.Name == "ToastRow" then
				visibleRows += 1
				table.insert(rowRects, { min = child.AbsolutePosition, max = child.AbsolutePosition + child.AbsoluteSize })
			end
		end
		local overlaps = 0
		for a = 1, #rowRects do
			for b = a + 1, #rowRects do
				if rowRects[a].min.X < rowRects[b].max.X and rowRects[b].min.X < rowRects[a].max.X and rowRects[a].min.Y < rowRects[b].max.Y and rowRects[b].min.Y < rowRects[a].max.Y then
					overlaps += 1
				end
			end
		end
		local texts = Toast.debugTexts("TC")
		check(("동시 발생(저장 · 레벨업 · 구역 차단 · 보물상자): push 결과 %s · 보이는 행 %d(TC 줄 %d행) · 대기 %d(기대 3) · 겹친 행 %d쌍(기대 0) · 지금 보이는 것 = 첫 알림(저장) %s"):format(
			table.concat(results, "/"), visibleRows, state.maxRows, state.queued, overlaps, tostring(texts[1] == cases[1].text)),
			visibleRows == 1 and state.queued == 3 and overlaps == 0 and texts[1] == cases[1].text and results[1] == "shown" and results[2] == "queued")

		-- 4. 아이템 3개를 한 번에: 한 행으로 묶인다("… 외 2") - 등급색 · 크기는 첫 아이템 그대로
		Toast.clear()
		local grades = { "rare", "legendary", "primordial" }
		local pushes = {}
		for index, grade in ipairs(grades) do
			table.insert(pushes, Toast.push("BC", SIGNALS[5].make({ grade = grade, part = "armor", itemLevel = 40 + index })))
		end
		task.wait(0.2)
		local bcState = Toast.debugState("BC")
		local firstText = ("%s %s 획득 (Lv.%d)"):format(ArmorData.grades.rare.displayName, ItemVisualData.partDisplayNames.armor, 41)
		local bcTexts = Toast.debugTexts("BC")
		check(("아이템 3개 묶음: push 결과 %s(기대 shown/merged/merged) · 행 %d · 대기 %d(기대 1 · 0) · 글 '%s'(기대 '%s 외 2')"):format(
			table.concat(pushes, "/"), bcState.rows, bcState.queued, tostring(bcTexts[1]), firstText),
			pushes[1] == "shown" and pushes[2] == "merged" and pushes[3] == "merged" and bcState.rows == 1 and bcState.queued == 0 and bcTexts[1] == firstText .. " 외 2")

		-- 5. 낮은 화면 · 가로(사전 작업 결정 2026-09-20): 등급 글씨 16이 1행 칸(높이 40 · 글자 폭 460)에 들어가는지, 화면 높이 416 미만에서 행이 줄어도 중앙 금지 구역 위 경계를 안 넘고 글씨가 행 안에 드는지
		local slotDef = ScreenMap.slot("TC", "toastLane")
		local longest = "다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다. 다시 접속해 주세요." -- 서버 SaveCoordinator의 가장 긴 문구
		local critical = Toast.grades.critical
		local textWidth = TextService:GetTextSize(longest, critical.textSize, Theme.font, Vector2.new(2000, 100)).X
		local heights, cells, allOk = { 484, 416, 415, 388, 375, 360, 356, 355, 344 }, {}, textWidth <= slotDef.size.X.Offset - 20
		for _, screenHeight in ipairs(heights) do
			local compact = Toast.centerSafeRowHeight(screenHeight)
			local rowHeight = compact or slotDef.size.Y.Offset
			local size = Toast.gradeTextSize(rowHeight, critical)
			local textHeight = TextService:GetTextSize("가", size, Theme.font, Vector2.new(2000, 100)).Y
			local zoneTop = math.floor(screenHeight * ScreenMap.centerFraction.top)
			local cellOk = textHeight <= rowHeight and (compact == nil or slotDef.position.Y.Offset + rowHeight < zoneTop) and (size == critical.textSize) == (rowHeight >= critical.textSize + 8)
			allOk = allOk and cellOk
			table.insert(cells, ("%d→행 %d · 글씨 %d(높이 %d) %s"):format(screenHeight, rowHeight, size, textHeight, cellOk and "O" or "X"))
		end
		check(("치명 16pt가 칸에 들어간다: 가장 긴 문구 폭 %d ≤ %d(글자 영역) · 화면 높이별 %s"):format(textWidth, slotDef.size.X.Offset - 20, table.concat(cells, " / ")), allOk)

		-- 6. 대기 규칙: 대기열이 없으면 일반 행은 전체 시간(보물상자 5초)을 채우고, 뒤에 알림이 있으면 2초(+ 흐림 0.3)에 넘어간다
		Toast.clear()
		Toast.push("TC", SIGNALS[4].make(cases[4].value))
		task.wait(4)
		local aloneStillShown = Toast.debugTexts("TC")[1] == cases[4].text
		Toast.clear()

		local function watchTC(maxSeconds) -- 0.05초마다 TC 줄을 읽어 "새로 보인 행"마다 { at, text, size, bold, danger }를 모은다(행 · 대기가 모두 없어지면 끝)
			local events, lastText = {}, nil
			local start = os.clock()
			while os.clock() - start < maxSeconds do
				local row = laneRow("TC")
				local label = row and row:FindFirstChild("Text")
				local text = label and label.Text
				if text and text ~= lastText then
					table.insert(events, { at = os.clock() - start, text = Toast.debugTexts("TC")[1] or "", size = label.TextSize, bold = label.Font == Theme.font, danger = row.BackgroundColor3 == UIColors.danger, height = row.AbsoluteSize.Y })
				end
				lastText = text
				if not row and Toast.debugState("TC").queued == 0 then
					break
				end
				task.wait(0.05)
			end
			return events, os.clock() - start
		end

		Toast.push("TC", SIGNALS[4].make(cases[4].value))
		Toast.push("TC", SIGNALS[3].make(cases[3].value))
		local passEvents = watchTC(6)
		local passAt = passEvents[2] and passEvents[2].at or -1
		check(("대기 규칙: 단독 보물상자 4초 뒤에도 남음 %s(기대 true) · 뒤에 구역 차단이 대기하면 다음 행이 %.2f초에 보임(기대 2.0 ~ 2.8 = 2초 + 흐림 0.3 - 보물상자 원래 5초)"):format(tostring(aloneStillShown), passAt),
			aloneStillShown and passEvents[2] ~= nil and passEvents[2].text == cases[3].text and passAt >= 2.0 and passAt <= 2.8)

		-- 7. 동시 발생 3개(저장 실패 + 레벨업 + 일반 알림): 순서 · 크기 · 시간. 치명은 대기열이 있어도 6초를 채우고(2초에 안 넘어간다) 그 뒤 흐림 0.5, 레벨업(중요)은 2초 + 0.5, 일반은 그 뒤에 나온다
		Toast.clear()
		Toast.push("TC", SIGNALS[1].make(cases[1].value))
		Toast.push("TC", SIGNALS[2].make(cases[2].value))
		Toast.push("TC", SIGNALS[3].make(cases[3].value))
		local events, total = watchTC(14)
		local function line(event)
			return event and ("%.2f초 '%s'(글씨 %d · 굵게 %s · 빨간 바탕 %s · 행 높이 %d)"):format(event.at, event.text:sub(1, 8), event.size, tostring(event.bold), tostring(event.danger), event.height) or "없음"
		end
		local sequenceOk = #events == 3
			and events[1].text == cases[1].text and events[2].text == cases[2].text and events[3].text == cases[3].text
			and events[1].at < 0.5 and events[1].danger and events[1].bold and events[1].size == Toast.gradeTextSize(events[1].height, Toast.grades.critical)
			and events[2].at >= 6.2 and events[2].at <= 7.0 and not events[2].danger and events[2].bold and events[2].size == Toast.gradeTextSize(events[2].height, Toast.grades.important)
			and events[3].at >= 8.7 and events[3].at <= 9.5 and not events[3].danger and not events[3].bold and events[3].size >= Theme.minTextSize
			and total >= 10.9 and total <= 11.9
		check(("동시 3개 순서 · 크기 · 시간: ① 저장(치명) %s ② 레벨업(중요) %s ③ 구역 차단(일반) %s · 전체 %.2f초(기대 ② 6.2 ~ 7.0초 = 6 + 0.5 · ③ 8.7 ~ 9.5초 = + 2 + 0.5 · 전체 10.9 ~ 11.9초)"):format(
			line(events[1]), line(events[2]), line(events[3]), total), sequenceOk)
	end)
	if not ok then
		check(("자체 점검 실행 중 에러: %s"):format(tostring(err)), false)
	end
	Toast.clear()
	print(("===S17 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

if RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S17(UI)")) then
	task.delay(CHECK_DELAY, selfCheck)
end
