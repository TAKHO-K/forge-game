-- S20(UI) 자체 점검 [S20][UI] - 요청 배너 화면 안전 영역 · 파티 복귀 문구(사전 작업 1 · 2). Studio에서 DevToolsConfig.verify에 "S20(UI)"가 있을 때만(또는 회귀 전체) 돈다.
--   ① 배너 자리 순수 함수(`RequestBanner.placementFor`)를 모바일 기준 해상도 4개(800 × 360 · 667 × 375 · 842 × 388 · 1024 × 768 - 상단 인셋 58을 뺀 ScreenGui 높이)로 불러
--      위 끝 >= 8 · 아래 끝 <= 높이 - 8(화면 밖 0) · 모바일 버튼 44 이상 · 본문 줄 수를 잰다. 폰(모바일 기하) · PC 기하 둘 다.
--   ② 복귀 문구: `PartyAway.reconnectBody` 문구 · 배너에 실제로 밀어 넣어 남은 시간이 0.1초 단위로 줄어드는지(글 · 게이지).
--   ③ 지금 화면에서 실제 배너가 ScreenGui 안에 그려지는지.

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

local PartyAway = require(script.Parent.PartyAway)
local RequestBanner = require(script.Parent.RequestBanner)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local player = Players.LocalPlayer
local START_DELAY = 66 -- 다른 클라 점검이 토스트 · 요청 배너를 쓰는 동안이 끝난 뒤
local INSET = 58 -- GetGuiInset 상단(1321 × 542 Play 실측). 해상도별 ScreenGui 높이 = 뷰포트 높이 - INSET.
local SAFE = 8

local RESOLUTIONS = { { 800, 360 }, { 667, 375 }, { 842, 388 }, { 1024, 768 } }

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20(UI) 검증 시작(요청 배너 안전 영역 · 복귀 문구)===")

	-- ① 자리 순수 함수 - 4 해상도 × (모바일 · PC 기하) × (게이지 있음 · 버튼 있음 = 가장 큰 배너)
	for _, mobile in ipairs({ true, false }) do
		local rows, allInside, buttonsOk, linesText = {}, true, true, {}
		for _, size in ipairs(RESOLUTIONS) do
			local screenHeight = size[2] - INSET
			local lines, top, height = RequestBanner.placementFor(screenHeight, mobile, true, true)
			local inside = top >= SAFE - 1e-6 and top + height <= screenHeight - SAFE + 1e-6
			allInside = allInside and inside
			table.insert(rows, ("%d × %d(ScreenGui 높이 %d) → 위 %.0f · 아래 %.0f · 본문 %d줄 %s"):format(size[1], size[2], screenHeight, top, top + height, lines, inside and "안" or "밖"))
			table.insert(linesText, lines)
		end
		buttonsOk = Theme.buttonHeightFor(mobile) >= (mobile and 44 or 0)
		check(("%s 기하 배너 화면 안(위 여백 %d · 아래 여백 %d): %s · 수락 · 거절 버튼 높이 %d(모바일 기대 44 이상)"):format(mobile and "모바일" or "PC", SAFE, SAFE, table.concat(rows, " / "), Theme.buttonHeightFor(mobile)), allInside and buttonsOk)
	end
	-- 버튼 폭: (배너 폭 224 - 좌우 여백 20 - 버튼 사이 8) ÷ 2
	local buttonWidth = (RequestBanner.width - 20 - 8) / 2
	check(("수락 · 거절 버튼 폭 %.0f(터치 44 이상)"):format(buttonWidth), buttonWidth >= 44)

	-- ② 복귀 문구 · 카운트다운
	local body = PartyAway.reconnectBody("홍길동", 161)
	check(("복귀 문구: '%s'(기대 '홍길동님의 파티로 돌아가기 (남은 시간 2:41)')"):format(body), body == "홍길동님의 파티로 돌아가기 (남은 시간 2:41)")
	RequestBanner.clear()
	RequestBanner.push({
		key = "reconnectCheck",
		title = "파티로 돌아가기",
		bodyFn = function(remaining)
			return PartyAway.reconnectBody("홍길동", remaining)
		end,
		seconds = 3,
		accept = { text = "돌아가기" },
		decline = { text = "나중에" },
	})
	local first = RequestBanner.debugState()
	task.wait(1.3)
	local second = RequestBanner.debugState()
	check(("복귀 배너 카운트다운: 처음 '%s' → 1.3초 뒤 '%s'(기대 0:03 → 0:02 · 게이지 %.2f → %.2f 줄어듦) · 제목 '%s' · 버튼 %s"):format(
		first.body, second.body, first.gaugeValue, second.gaugeValue, second.title, tostring(second.buttonsShown)),
		first.body:find("남은 시간 0:03", 1, true) ~= nil and second.body:find("남은 시간 0:02", 1, true) ~= nil and second.gaugeValue < first.gaugeValue and second.title == "파티로 돌아가기" and second.buttonsShown)

	-- ③ 실제 배너가 지금 ScreenGui 안에 그려진다
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("RequestBannerGui")
	local frame = second.frame
	if gui and frame then
		local position, size, screen = frame.AbsolutePosition, frame.AbsoluteSize, gui.AbsoluteSize
		local inside = position.Y >= SAFE - 0.5 and position.Y + size.Y <= screen.Y - SAFE + 0.5 and position.X >= 0 and position.X + size.X <= screen.X
		check(("실제 배너(지금 화면 %d × %d): 위치 (%d, %d) 크기 %d × %d → 안전 영역 안 %s"):format(screen.X, screen.Y, position.X, position.Y, size.X, size.Y, tostring(inside)), inside)
	else
		check("실제 배너 프레임을 못 찾음", false)
	end
	RequestBanner.clear()

	print(("===S20(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20][UI] 점검 에러: " .. tostring(err))
		RequestBanner.clear()
	end
end)
