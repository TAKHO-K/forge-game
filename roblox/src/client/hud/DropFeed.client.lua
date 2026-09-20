-- 파티원 드랍 알림 표시(30-0 S10, PRD 20.73 [5-3]). 서버(DropNotice)가 유물 · 고대 · 태초 장비가 굴려진 순간 { name, grade, part, itemLevel, scope }를 보낸다 - 판정 · 수신자는 전부 서버다.
--   scope "party"  → 드랍 피드(Toast TR): "OOO: 유물 장갑 Lv.52"(등급명만 등급색). 칩 스택 바로 아래 3줄 · 새 알림이 위 · 4초 뒤 흐려짐 · 3줄 넘으면 오래된 줄이 밀림. 같은 사람 1초 안 여러 건은 "… 외 1".
--   scope "server" → 태초: 피드가 아니라 화면 상단 가운데 배너 한 줄(Toast TC · 4초 · 무지개 테두리) + 채팅 시스템 메시지 1줄.
-- 끄기 설정은 없다. Studio에서는 접속 12초 뒤 합성 이벤트로 자체 점검(selfTest)을 돌려 [S10][UI] 줄을 찍는다(DevToolsConfig.verify에 S10(가)가 있을 때만).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
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
	return ("★ %s님이 %s %s을 얻었습니다"):format(tostring(payload.name), gradeName, partName)
end

local function showFeed(payload)
	local gradeName, partName = gradeAndPart(payload)
	local visual = ItemVisualData.gradeVisuals[payload.grade]
	return Toast.push("TR", {
		richParts = {
			{ text = ("%s: "):format(tostring(payload.name)), colorName = "textPrimary" },
			{ text = ("%s %s"):format(gradeName, partName), color = visual and visual.color, colorName = "textPrimary" },
			{ text = (" Lv.%d"):format(tonumber(payload.itemLevel) or 0), colorName = "textPrimary" },
		},
		seconds = DropNoticeData.seconds,
		fadeSeconds = DropNoticeData.fadeSeconds,
		groupKey = payload.name,
		moreFormat = DropNoticeData.moreFormat,
	})
end

local function showPrimalBanner(payload, silentChat)
	local gradeName, partName = gradeAndPart(payload)
	local visual = ItemVisualData.gradeVisuals[payload.grade]
	Toast.push("TC", {
		richParts = {
			{ text = ("★ %s님이 "):format(tostring(payload.name)), colorName = "textPrimary" },
			{ text = ("%s %s"):format(gradeName, partName), color = visual and visual.color, colorName = "textPrimary" },
			{ text = "을 얻었습니다", colorName = "textPrimary" },
		},
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
	check(("합성 12건(유물 9 · 고대 2 · 태초 1): 피드 표시 %d줄(기대 %d) · 대기 %d(기대 0 - 대기열 없음) · 밀려난 줄 %d(기대 8 = 피드 11건 - 3줄) · 태초 배너 %d줄(기대 1)"):format(
		feed.rows, DropNoticeData.feedRows, feed.queued, feed.evicted, banner.rows),
		feed.rows == DropNoticeData.feedRows and feed.queued == 0 and feed.evicted == 8 and banner.rows == 1)
	check(("새 알림이 맨 위: 유물 9건 뒤 맨 위 [%s](기대 유물러9) · 12건 뒤 위에서부터 [%s](기대 고대러2 · 고대러1 · 유물러9)"):format(topAfterRelics, table.concat(feedTexts, " | ")),
		string.find(topAfterRelics, "유물러9", 1, true) ~= nil and #feedTexts == 3 and string.find(feedTexts[1], "고대러2", 1, true) ~= nil
			and string.find(feedTexts[2], "고대러1", 1, true) ~= nil and string.find(feedTexts[3], "유물러9", 1, true) ~= nil and afterRelics.rows == 3)
	check(("피드에 태초가 없다: 피드 글 [%s] 중 '태초' 포함 %s(기대 false)"):format(table.concat(feedTexts, " | "), tostring(string.find(table.concat(feedTexts), "태초", 1, true) ~= nil)),
		string.find(table.concat(feedTexts), "태초", 1, true) == nil)

	Toast.clear()
	handle({ name = "같은이", grade = "relic", part = "gloves", itemLevel = 52, scope = "party" }, true)
	handle({ name = "같은이", grade = "ancient", part = "shoes", itemLevel = 60, scope = "party" }, true)
	local grouped = Toast.debugState("TR")
	local groupedText = Toast.debugTexts("TR")[1] or ""
	check(("같은 사람 2건(1초 안) 묶음: 줄 %d(기대 1) · 글 [%s](기대 '… 외 1' 끝)"):format(grouped.rows, groupedText),
		grouped.rows == 1 and string.find(groupedText, "외 1", 1, true) ~= nil)

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
