-- 파티원 드랍 알림 표시(30-0 S10, PRD 20.73 [5-3]). 서버(DropNotice)가 유물 · 고대 · 태초 장비가 굴려진 순간 { name, grade, part, itemLevel, scope }를 보낸다 - 판정 · 수신자는 전부 서버다.
--   scope "party"  → 드랍 피드(Toast TR): "OOO: 유물 장갑 Lv.52"(등급명만 등급색). 칩 스택 바로 아래 남은 자리만큼(최대 3줄 - FeedLayout, 0줄이면 상단 띠 1줄) · 새 알림이 위 · 4초 뒤 흐려짐 · 넘치면 오래된 줄이 밀림. 같은 사람 1초 안 여러 건은 "… 외 1".
--   scope "server" → 태초: 피드가 아니라 화면 상단 가운데 배너 한 줄(Toast TC · 4초 · 무지개 테두리) + 채팅 시스템 메시지 1줄.
-- 끄기 설정은 없다. Studio에서는 접속 12초 뒤 합성 이벤트로 자체 점검(selfTest)을 돌려 [S10][UI] 줄을 찍는다(DevToolsConfig.verify에 S10(가)가 있을 때만).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local GradeColor = require(ReplicatedStorage.Shared.GradeColor)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local PlayerMenu = require(script.Parent.Parent.panels.PlayerMenu)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local FeedLayout = require(script.Parent.Parent.ui.FeedLayout)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local dropNotice = ReplicatedStorage:WaitForChild("DropNotice")

local function gradeAndPart(payload)
	local grade = ArmorData.grades[payload.grade]
	local gradeName = grade and grade.displayName or tostring(payload.grade)
	local partName = ItemVisualData.partDisplayNames[payload.part or "armor"] or "장비"
	return gradeName, partName
end

local function primalLine(payload)
	local gradeName, partName = gradeAndPart(payload)
	-- G1-1: 채팅 줄도 등급 색(옛: 색 지정 없음 - 흰 글씨)
	return Text.get("chat.primalDrop", { name = PlayerLabelFormat.plain(payload.name, payload.level, payload.rebirth), color = GradeColor.hex(payload.grade), item = ("%s %s"):format(gradeName, partName) })
end

-- S12b: 알림의 이름 조각들("★n Lv.35 표시이름") - 이름을 누르면 이름 클릭 메뉴(userId가 있을 때만 - 합성 검증 이벤트에는 없다).
local function nameParts(payload)
	local parts = PlayerLabelFormat.parts(payload.name, payload.level, payload.rebirth, Theme.textSize("caption"), "textPrimary")
	for _, part in ipairs(parts) do
		if part.isName and payload.userId then
			part.onActivate = function()
				PlayerMenu.open({ userId = payload.userId, displayName = payload.name, level = payload.level, rebirth = payload.rebirth })
			end
		end
	end
	return parts
end

-- S12b: 아이템 이름 조각(굵게) - 누르면 옵션 툴팁 토글. 옵션은 드랍 순간 스냅샷(payload.option)이라 이후 강화 · 판매와 무관하다.
local function itemPart(payload, gradeName, partName)
	local visual = ItemVisualData.gradeVisuals[payload.grade]
	local desc = ItemDescribe.item({ grade = payload.grade, part = payload.part or "armor", itemLevel = tonumber(payload.itemLevel) or 0, option = payload.option }, payload.classId)
	return {
		text = ("%s %s"):format(gradeName, partName),
		color = visual and visual.color,
		colorName = "textPrimary",
		bold = true,
		onActivate = function(handle)
			handle.toggleTooltip(desc)
		end,
	}
end

local function showFeed(payload)
	local gradeName, partName = gradeAndPart(payload)
	local parts = nameParts(payload)
	table.insert(parts, { text = ": ", colorName = "textPrimary" })
	table.insert(parts, itemPart(payload, gradeName, partName))
	table.insert(parts, { text = (" Lv.%d"):format(tonumber(payload.itemLevel) or 0), colorName = "textPrimary" })
	return Toast.push("TR", {
		richParts = parts,
		seconds = DropNoticeData.seconds,
		fadeSeconds = DropNoticeData.fadeSeconds,
		groupKey = payload.name,
		moreFormat = DropNoticeData.moreFormat,
	})
end

local function showPrimalBanner(payload, silentChat)
	local gradeName, partName = gradeAndPart(payload)
	local parts = { { text = "★ ", colorName = "textPrimary" } }
	for _, part in ipairs(nameParts(payload)) do
		table.insert(parts, part)
	end
	table.insert(parts, { text = "님이 ", colorName = "textPrimary" })
	table.insert(parts, itemPart(payload, gradeName, partName))
	table.insert(parts, { text = "을 얻었습니다", colorName = "textPrimary" })
	Toast.push("TC", {
		richParts = parts,
		seconds = DropNoticeData.seconds,
		fadeSeconds = DropNoticeData.fadeSeconds,
		rainbow = true,
	})
	if not silentChat then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local general = channels and channels:FindFirstChild("RBXGeneral")
		if general then
			general:DisplaySystemMessage(primalLine(payload))
		end
	end
end

local function handle(payload, silentChat)
	if payload.scope == "server" then
		showPrimalBanner(payload, silentChat)
	else
		showFeed(payload)
	end
end

dropNotice.OnClientEvent:Connect(function(payload)
	handle(payload, false)
end)

-- ── Studio 자체 점검: 합성 이벤트 12건(유물 9 · 고대 2 · 태초 1)을 넣고 피드 규칙을 읽는다. 서버 없이 클라만으로 도는 (가)다. ──
-- 피드 줄 수(capacity)는 화면에 따라 1 ~ 3이다(남은 자리 - FeedLayout). 기대값은 지금 화면의 capacity로 계산한다.

local function intersects(a, b)
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

local function rectOfGui(inst)
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

local function selfTest()
	print("===S10 검증 시작(UI: 클라 자체 점검)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[S10][UI] %s %s"):format(label, ok and "O" or "X"))
	end
	local function relic(index)
		return { name = "유물러" .. index, grade = "relic", part = "armor", itemLevel = 50 + index, scope = "party" }
	end

	Toast.clear()
	handle(relic(0), true) -- 줄을 처음 세운다(ToastGui가 이때 만들어진다)
	task.wait(0.3) -- 배치가 자리를 잡게
	local capacity = Toast.debugState("TR").capacity
	Toast.clear()

	for index = 1, 9 do
		handle(relic(index), true)
	end
	local afterRelics = Toast.debugState("TR")
	local topAfterRelics = Toast.debugTexts("TR")[1] or ""
	for index = 1, 2 do
		handle({ name = "고대러" .. index, grade = "ancient", part = "gloves", itemLevel = 70 + index, scope = "party" }, true)
	end
	handle({ name = "태초러", grade = "primordial", part = "shoes", itemLevel = 99, scope = "server" }, true)
	local feed, banner = Toast.debugState("TR"), Toast.debugState("TC")
	local feedTexts = Toast.debugTexts("TR")
	check(("합성 12건(유물 9 · 고대 2 · 태초 1): 지금 화면의 줄 수 %d(기대 1 ~ %d · %s) · 피드 표시 %d줄(기대 %d) · 대기 %d(기대 0 - 대기열 없음) · 밀려난 줄 %d(기대 %d = 피드 11건 - %d줄) · 태초 배너 %d줄(기대 1)"):format(
		capacity, DropNoticeData.feedRows, feed.strip and "상단 띠" or "칩 스택 아래", feed.rows, capacity, feed.queued, feed.evicted, 11 - capacity, capacity, banner.rows),
		capacity >= 1 and capacity <= DropNoticeData.feedRows and feed.rows == capacity and feed.queued == 0 and feed.evicted == 11 - capacity and banner.rows == 1)
	local expectedOrder = { "고대러2", "고대러1", "유물러9", "유물러8", "유물러7" } -- 위에서부터(새 알림이 위)
	local orderOk = #feedTexts == capacity and afterRelics.rows == capacity and string.find(topAfterRelics, "유물러9", 1, true) ~= nil
	for index = 1, capacity do
		orderOk = orderOk and feedTexts[index] ~= nil and string.find(feedTexts[index], expectedOrder[index], 1, true) ~= nil
	end
	check(("새 알림이 맨 위: 유물 9건 뒤 맨 위 [%s](기대 유물러9) · 12건 뒤 위에서부터 [%s](기대 %s)"):format(topAfterRelics, table.concat(feedTexts, " | "),
		table.concat(table.move(expectedOrder, 1, capacity, 1, {}), " · ")), orderOk)
	check(("피드에 태초가 없다: 피드 글 [%s] 중 '태초' 포함 %s(기대 false)"):format(table.concat(feedTexts, " | "), tostring(string.find(table.concat(feedTexts), "태초", 1, true) ~= nil)),
		string.find(table.concat(feedTexts), "태초", 1, true) == nil)

	-- 측정 A(태초 배너 없음): 피드 프레임이 실제로 어떤 자리와도 겹치지 않는다(가방 버튼 · 투표 패널 · 터치 구역 · 중앙 금지 구역 · 화면 아래)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local function measure()
		task.wait(0.3)
		local toastGui = playerGui:WaitForChild("ToastGui")
		local screen = toastGui.AbsoluteSize
		local feedFrame, bannerFrame = toastGui:FindFirstChild("ToastLane_TR"), playerGui:FindFirstChild("ToastLane_TC", true) -- TC 줄은 자기 ScreenGui(ToastGuiTC - S19)
		local state = Toast.debugState("TR")
		local feedRect = rectOfGui(feedFrame)
		local hits, targets = {}, {}
		for _, blocker in ipairs(FeedLayout.blockers(playerGui, screen)) do
			table.insert(targets, blocker.label)
			if intersects(feedRect, blocker) then
				table.insert(hits, blocker.label)
			end
		end
		local bannerRect = bannerFrame.Visible and rectOfGui(bannerFrame) or nil
		print(("[S10][UI][측정] 화면 %d × %d(%s) · 피드 (%d, %d) %d × %d · %s %d줄 · 피해야 할 자리 %s · 배너 %s"):format(screen.X, screen.Y, Theme.isMobile and "모바일" or "PC",
			feedRect.min.X, feedRect.min.Y, feedFrame.AbsoluteSize.X, feedFrame.AbsoluteSize.Y, state.strip and "상단 띠" or "칩 스택 아래", state.rows, table.concat(targets, " · "),
			bannerRect and ("(%d, %d) %d × %d"):format(bannerRect.min.X, bannerRect.min.Y, bannerFrame.AbsoluteSize.X, bannerFrame.AbsoluteSize.Y) or "없음"))
		return { hits = hits, feedRect = feedRect, bannerRect = bannerRect, state = state, screen = screen }
	end
	Toast.clear()
	handle(relic(1), true)
	local plain = measure()
	check(("피드 프레임이 겹치는 자리 %d개(기대 0 - 태초 배너 없음): [%s]"):format(#plain.hits, table.concat(plain.hits, " · ")), #plain.hits == 0)

	-- 측정 B(태초 배너 있음): 사용자 규칙 - 띠(0줄일 때)는 배너 바로 아래에 붙는다. 낮은 화면에서는 이 자리가 중앙 금지 구역에 닿을 수 있다(PRD 20.94 미결) - 규칙대로인지만 검사하고 닿는 양은 참고로 찍는다.
	handle({ name = "태초러", grade = "primordial", part = "shoes", itemLevel = 99, scope = "server" }, true)
	local withBanner = measure()
	if withBanner.state.strip then
		local gap = withBanner.feedRect.min.Y - withBanner.bannerRect.max.Y
		check(("태초 배너가 떠 있고 피드가 상단 띠일 때: 띠 위 끝 %d - 배너 아래 끝 %d = %d(기대 3 - 바로 아래)"):format(withBanner.feedRect.min.Y, withBanner.bannerRect.max.Y, gap), math.abs(gap - 3) <= 1)
	else
		check("태초 배너가 떠 있고 피드가 칩 스택 아래일 때: 배너와 겹치지 않는다", not intersects(withBanner.feedRect, withBanner.bannerRect))
	end
	local centerRect = ScreenMap.centerRect(withBanner.screen)
	print(("[S10][UI][측정][참고] 배너 + 피드 동시: 피드 (%d ~ %d) vs 중앙 금지 구역 위 경계 %d → %s"):format(withBanner.feedRect.min.Y, withBanner.feedRect.max.Y, centerRect.min.Y,
		intersects(withBanner.feedRect, centerRect) and "닿음(미결)" or "안 닿음"))

	Toast.clear()
	handle({ name = "같은이", grade = "relic", part = "gloves", itemLevel = 52, scope = "party" }, true)
	handle({ name = "같은이", grade = "ancient", part = "shoes", itemLevel = 60, scope = "party" }, true)
	local grouped = Toast.debugState("TR")
	local groupedText = Toast.debugTexts("TR")[1] or ""
	check(("같은 사람 2건(1초 안) 묶음: 줄 %d(기대 1) · 글 [%s](기대 '… 외 1' 끝)"):format(grouped.rows, groupedText),
		grouped.rows == 1 and string.find(groupedText, "외 1", 1, true) ~= nil)

	-- 줄 수가 줄어들면(창이 작아짐 · 투표 패널이 뜸) 오래된 줄부터 밀린다 - 재배치와 같은 함수로 강제 확인
	Toast.clear()
	Toast.debugSetCapacity("TR", 3)
	for index = 1, 3 do
		handle(relic(index), true)
	end
	local beforeShrink = Toast.debugState("TR")
	Toast.debugSetCapacity("TR", 1)
	local afterShrink = Toast.debugState("TR")
	local shrinkTop = Toast.debugTexts("TR")[1] or ""
	handle(relic(4), true)
	local afterNew = Toast.debugState("TR")
	local newTop = Toast.debugTexts("TR")[1] or ""
	check(("줄 수 3 → 1: 3줄 %d → %d줄(기대 3 → 1) · 남은 줄 [%s](기대 유물러3 - 가장 오래된 줄부터 밀림) · 밀려난 +%d(기대 2) · 새 알림 뒤 %d줄 [%s](기대 1줄 유물러4) · 밀려난 +%d(기대 3)"):format(
		beforeShrink.rows, afterShrink.rows, shrinkTop, afterShrink.evicted - beforeShrink.evicted, afterNew.rows, newTop, afterNew.evicted - beforeShrink.evicted),
		beforeShrink.rows == 3 and afterShrink.rows == 1 and string.find(shrinkTop, "유물러3", 1, true) ~= nil and afterShrink.evicted - beforeShrink.evicted == 2
			and afterNew.rows == 1 and string.find(newTop, "유물러4", 1, true) ~= nil and afterNew.evicted - beforeShrink.evicted == 3)
	Toast.clear() -- 실제 줄 수로 되돌린다

	-- 줄 수 계산(순수): 칩 스택 아래 y 238 · 가로 1007 ~ 1307 · 줄 24 · 간격 3
	local function block(minX, minY, maxX, maxY)
		return { min = Vector2.new(minX, minY), max = Vector2.new(maxX, maxY) }
	end
	local function fit(...)
		return FeedLayout.fitRows(238, 1007, 1307, 24, 3, 3, { ... })
	end
	local fitOk = fit() == 3 -- 막는 것 없음
		and fit(block(1215, 316, 1305, 352)) == 3 -- 위 끝 316 = 3줄이 딱 들어감(238 + 78)
		and fit(block(1215, 315, 1305, 351)) == 2
		and fit(block(1215, 289, 1305, 325)) == 2 -- 2줄 = 51
		and fit(block(1215, 288, 1305, 324)) == 1
		and fit(block(1215, 262, 1305, 298)) == 1
		and fit(block(1215, 261, 1305, 297)) == 0
		and fit(block(1215, 224, 1305, 260)) == 0 -- 피드 위 끝이 가방 버튼 안 - 0줄(띠로)
		and fit(block(0, 262, 900, 298)) == 3 -- 가로가 안 겹치면 무시
		and fit(block(1215, 100, 1305, 200)) == 3 -- 이미 지나간(위쪽) HUD는 무시
		and fit(block(1215, 316, 1305, 352), block(1100, 262, 1305, 346)) == 1 -- 여럿이면 가장 위 끝
	check("줄 수 계산(순수 11건: 막는 것 없음 3 · 위 끝 316/315/289/288/262/261/224 → 3/2/2/1/1/0/0 · 가로 밖 · 지나간 HUD 무시 · 여럿이면 가장 위 끝)", fitOk)

	-- 배너 행 높이(순수): 화면 높이 416 미만에서만 줄고, 줄인 배너는 중앙 금지 구역 위 경계 안에 든다
	local compact388, compact415 = Toast.centerSafeRowHeight(388), Toast.centerSafeRowHeight(415)
	check(("배너 행 높이: 388 → %s(기대 32 - 슬롯 y 64 + 32 = 96 < 위 경계 97) · 415 → %s(기대 38) · 416 → %s · 484 → %s(기대 nil nil) · 글씨 %d(기대 12 이상)"):format(
		tostring(compact388), tostring(compact415), tostring(Toast.centerSafeRowHeight(416)), tostring(Toast.centerSafeRowHeight(484)), Theme.text.caption),
		compact388 == 32 and compact415 == 38 and Toast.centerSafeRowHeight(416) == nil and Toast.centerSafeRowHeight(484) == nil and Theme.text.caption >= 12)

	Toast.clear()
	handle(relic(1), true)
	task.wait(DropNoticeData.seconds + DropNoticeData.fadeSeconds + 0.3)
	local gone = Toast.debugState("TR")
	check(("%s초 + 흐림 %s초 뒤 줄 %d(기대 0)"):format(DropNoticeData.seconds, DropNoticeData.fadeSeconds, gone.rows), gone.rows == 0)

	Toast.clear()
	print(("===S10 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

if RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S10(가)")) then
	task.delay(12, function()
		local ok, err = pcall(selfTest)
		if not ok then
			warn("[S10][UI] 자체 점검 에러: " .. tostring(err))
		end
	end)
end

-- ── S12b 자체 점검: 알림 속 이름 · 아이템(누르기 · 옵션 툴팁 · 스냅샷) · 누르고 있는 동안 타이머 정지 · 이름 클릭 메뉴. 사람 손 대신 Toast.debugRows의 같은 핸들러를 부른다. ──
-- S10 자체 점검(접속 12초 뒤 · 약 10초)이 줄을 쓰므로 그 뒤(32초)에 돈다. 실제 서버 → 클라 경로(DropNotice.publish)는 MCP Play에서 /gg dropnotice로 본다.

local function selfTestS12b()
	print("===S12b 검증 시작(UI: 알림 · 이름 메뉴)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[S12b][UI] %s %s"):format(label, ok and "O" or "X"))
	end
	local UIManager = require(script.Parent.Parent.UIManager)
	local classId = Players.LocalPlayer:GetAttribute("ClassId")
	local ABSENT_ID = 8888888

	-- 행의 글 조각 중 key(isName = 이름 · bold = 아이템)가 있는 조각의 번호. ★n · Lv 조각이 앞에 붙으므로 번호는 고정이 아니다.
	local function partIndex(row, key)
		for index, part in ipairs(row.parts) do
			if part[key] then
				return index
			end
		end
		return nil
	end

	local function payloadOf(name, userId, option)
		return { name = name, userId = userId, level = 35, rebirth = 1, classId = classId, grade = "relic", part = "gloves", itemLevel = 52, scope = "party", option = option }
	end

	Toast.clear()
	local option = { id = "attackPercent", roll = 1.05 }
	local expectedDesc = ItemDescribe.item({ grade = "relic", part = "gloves", itemLevel = 52, option = { id = "attackPercent", roll = 1.05 } }, classId)
	handle(payloadOf("철수", ABSENT_ID, option), true)
	task.wait(0.3)
	local rows = Toast.debugRows("TR")
	local text = Toast.debugTexts("TR")[1] or ""
	check(("알림 글 [%s](기대 ★1 Lv.35 철수: 유물 장갑 Lv.52) · 누르는 조각 %d개(기대 2 - 이름 · 아이템)"):format(text, rows[1] and rows[1].hitCount() or 0),
		text == "★1 Lv.35 철수: 유물 장갑 Lv.52" and rows[1] ~= nil and rows[1].hitCount() == 2)

	-- 이름 클릭 → 메뉴(서버를 떠난 사람: 세 버튼 모두 비활성 + 이유)
	if rows[1] then
		rows[1].activate(partIndex(rows[1], "isName"))
		task.wait(0.4)
		local state = PlayerMenu.debugState()
		local friend, whisper, inspect = state.friend, state.whisper, state.inspect
		local menuOk = UIManager.isOpen("playerMenu") and friend ~= nil and whisper ~= nil and inspect ~= nil
			and friend.visible and whisper.visible and inspect.visible
			and not friend.enabled and not whisper.enabled and not inspect.enabled
			and friend.reason == "서버를 떠난 플레이어" and inspect.reason == "서버를 떠난 플레이어"
		check(("이름 클릭 → 메뉴 열림 %s · 서버를 떠난 사람: 친구 %s/%s · 귓속말 %s/%s · 장비 보기 %s/%s(기대 모두 보임 · 비활성 · 이유 표시) · 제목 [%s]"):format(
			tostring(UIManager.isOpen("playerMenu")), tostring(friend and friend.visible), tostring(friend and friend.enabled), tostring(whisper and whisper.visible), tostring(whisper and whisper.enabled),
			tostring(inspect and inspect.visible), tostring(inspect and inspect.enabled), (tostring(state.title):gsub("<[^>]+>", ""))), menuOk)
		UIManager.close("playerMenu", true)
		check(("메뉴 닫기: 열림 %s(기대 false)"):format(tostring(UIManager.isOpen("playerMenu"))), not UIManager.isOpen("playerMenu"))
	else
		check("이름 클릭 메뉴: 알림 행이 없다", false)
	end
	Toast.clear()

	-- 자기 이름 → 장비 보기만
	handle(payloadOf(Players.LocalPlayer.DisplayName, Players.LocalPlayer.UserId, option), true)
	task.wait(0.3)
	local selfRows = Toast.debugRows("TR")
	if selfRows[1] then
		selfRows[1].activate(partIndex(selfRows[1], "isName"))
		task.wait(0.4)
		local state = PlayerMenu.debugState()
		check(("자기 이름 클릭: 친구 보임=%s · 귓속말 보임=%s · 장비 보기 보임=%s 활성=%s(기대 false · false · true · true)"):format(
			tostring(state.friend and state.friend.visible), tostring(state.whisper and state.whisper.visible), tostring(state.inspect and state.inspect.visible), tostring(state.inspect and state.inspect.enabled)),
			state.friend ~= nil and not state.friend.visible and not state.whisper.visible and state.inspect.visible and state.inspect.enabled == true)
		UIManager.close("playerMenu", true)
	else
		check("자기 이름 클릭: 알림 행이 없다", false)
	end
	Toast.clear()

	-- 아이템 클릭 → 옵션 툴팁 토글 + 드랍 순간 스냅샷
	option = { id = "attackPercent", roll = 1.05 }
	handle(payloadOf("철수", ABSENT_ID, option), true)
	task.wait(0.3)
	rows = Toast.debugRows("TR")
	option.roll = 0.05 -- 드랍 뒤 원본이 바뀌어도(재굴림 · 강화) 알림의 옵션은 그대로여야 한다
	if rows[1] then
		local itemIndex = partIndex(rows[1], "bold")
		rows[1].activate(itemIndex)
		local openAfterTap, pinnedAfterTap = rows[1].tooltipOpen(), rows[1].pinned()
		local toastGui = Players.LocalPlayer.PlayerGui:FindFirstChild("ToastGui")
		local tip = toastGui and toastGui:FindFirstChild("ToastItemTooltip")
		local shownTitle = tip and tip:FindFirstChild("Title") and tip.Title.Text or ""
		local shownOption = tip and tip:FindFirstChild("Option1") and tip.Option1.Text or ""
		local expectedOption = expectedDesc.options[1] and expectedDesc.options[1].text or "?"
		check(("아이템 탭 → 툴팁 열림 %s · 타이머 정지 %s · 제목 [%s](기대 %s) · 옵션 [%s](기대 %s - 원본 roll을 0.05로 바꿔도 드랍 순간 값)"):format(
			tostring(openAfterTap), tostring(pinnedAfterTap), shownTitle, expectedDesc.title, shownOption, expectedOption),
			openAfterTap == true and pinnedAfterTap == true and shownTitle == expectedDesc.title and shownOption == expectedOption)
		rows[1].activate(itemIndex)
		check(("같은 아이템 다시 탭 → 툴팁 닫힘 %s(기대 true) · 타이머 정지 해제 %s(기대 true)"):format(tostring(not rows[1].tooltipOpen()), tostring(not rows[1].pinned())), not rows[1].tooltipOpen() and not rows[1].pinned())
	else
		check("아이템 툴팁: 알림 행이 없다", false)
	end
	Toast.clear()

	-- 타이머 정지: 누르고 있는 동안 · 툴팁이 열린 동안 안 사라진다. 놓으면 seconds를 다시 센다.
	local function shortRow()
		local shortPayload = payloadOf("타이머", ABSENT_ID, { id = "attackPercent", roll = 1.0 })
		local parts = nameParts(shortPayload)
		table.insert(parts, { text = ": ", colorName = "textPrimary" })
		table.insert(parts, itemPart(shortPayload, "유물", "장갑"))
		Toast.push("TR", { richParts = parts, seconds = 1, fadeSeconds = 0.2 })
		task.wait(0.2)
		return Toast.debugRows("TR")[1]
	end
	local pressRow = shortRow()
	pressRow.press()
	task.wait(1.9) -- 1초 + 흐림 0.2를 지나도
	local stillWhileHeld = not pressRow.removed()
	pressRow.release()
	task.wait(0.6)
	local stillAfterRelease = not pressRow.removed() -- 놓은 순간부터 1초를 다시 센다
	task.wait(1.0)
	check(("누르고 있는 동안: 1.9초 뒤에도 남음 %s(기대 true) · 놓고 0.6초 뒤 남음 %s(기대 true - 다시 셈) · 놓고 1.6초 뒤 사라짐 %s(기대 true)"):format(tostring(stillWhileHeld), tostring(stillAfterRelease), tostring(pressRow.removed())),
		stillWhileHeld and stillAfterRelease and pressRow.removed())
	Toast.clear()

	local tipRow = shortRow()
	tipRow.activate(partIndex(tipRow, "bold"))
	task.wait(1.9)
	local stillWithTooltip = not tipRow.removed() and tipRow.tooltipOpen()
	tipRow.activate(partIndex(tipRow, "bold")) -- 툴팁 닫기 = 정지 해제
	task.wait(0.6)
	local stillAfterClose = not tipRow.removed()
	task.wait(1.0)
	check(("툴팁이 열린 동안: 1.9초 뒤에도 남음 %s(기대 true) · 닫고 0.6초 뒤 남음 %s(기대 true) · 닫고 1.6초 뒤 사라짐 %s(기대 true)"):format(tostring(stillWithTooltip), tostring(stillAfterClose), tostring(tipRow.removed())),
		stillWithTooltip and stillAfterClose and tipRow.removed())
	Toast.clear()

	-- 툴팁이 열린 행이 밀려나면 툴팁도 닫힌다(줄 수 1로 강제).
	Toast.debugSetCapacity("TR", 1)
	local evictRow = shortRow()
	evictRow.activate(partIndex(evictRow, "bold"))
	local wasOpen = evictRow.tooltipOpen()
	handle(payloadOf("새치기", ABSENT_ID, nil), true)
	task.wait(0.2)
	check(("툴팁이 열린 행이 밀려남: 열림 %s → 행 사라짐 %s · 툴팁 %s(기대 true · true · 닫힘)"):format(tostring(wasOpen), tostring(evictRow.removed()), evictRow.tooltipOpen() and "열림" or "닫힘"),
		wasOpen == true and evictRow.removed() and not evictRow.tooltipOpen())
	Toast.clear()

	-- 태초 배너(TC): 이름 · 아이템 두 조각이 눌린다.
	handle({ name = "태초러", userId = ABSENT_ID, level = 99, rebirth = 5, classId = classId, grade = "primordial", part = "shoes", itemLevel = 99, scope = "server" }, true)
	task.wait(0.3)
	local bannerRows = Toast.debugRows("TC")
	local bannerText = Toast.debugTexts("TC")[1] or ""
	check(("태초 배너: 글 [%s](기대 ★ ★5 Lv.99 태초러님이 태초 신발을 얻었습니다) · 누르는 조각 %d개(기대 2)"):format(bannerText, bannerRows[1] and bannerRows[1].hitCount() or 0),
		bannerText == "★ ★5 Lv.99 태초러님이 태초 신발을 얻었습니다" and bannerRows[1] ~= nil and bannerRows[1].hitCount() == 2)
	Toast.clear()

	print(("===S12b 검증 끝(UI: 알림 · 이름 메뉴)=== %d/%d 통과"):format(pass, total))
end

if RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S12b(UI)")) then
	task.delay(32, function()
		local ok, err = pcall(selfTestS12b)
		if not ok then
			warn("[S12b][UI] 알림 자체 점검 에러: " .. tostring(err))
		end
	end)
end
