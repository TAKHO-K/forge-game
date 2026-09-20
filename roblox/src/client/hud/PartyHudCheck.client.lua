-- S18 자체 점검 [S18][UI] - PartyHud 분할(목록 · 요청 배너 · 알림) 검증. Studio에서 DevToolsConfig.verify에 "S18(UI)"가 있을 때만(또는 회귀 전체).
-- 실제 서버 신호(RemoteEvent → 배너 · 토스트)와 실제 클릭은 별도 스크린샷 Play가 한다(서버 execute_luau FireClient + user_mouse_input). 여기서는:
--   ① 신호 대조: 옛 PartyHud가 듣던 RemoteEvent 5개 + FireServer 대상이 새 스크립트로 옮겨졌고 옛 스크립트 · 옛 인스턴스(PartyToast · PartyVotePanel)가 없다.
--   ② 목록 뷰를 PC · 모바일 축약형 두 모드로 직접 지어(테스트 ScreenGui) 합성 4인으로 크기 · 색 · 값 · 글씨 실효 12를 본다.
--   ③ 폰 가로(폭 844)에서 파티 4인 목록 × 대시 버튼 · 체력바 · 조이스틱 구역 겹침 0 - 화면 높이 388 · 414 · 534를 계산으로 재구성한다(Studio 뷰포트는 높이 534가 최대 - 옛 배치가 낸 겹침도 같은 식으로 찍어 재현 확인).
--   ④ 요청 배너: 한 번에 하나 · 대기열 순서 · 도착 시각부터 세는 만료 · 같은 key 교체 · keepOpen · resolve · 정보 배너 · 게이지 · 글씨 실효 12 · 자리.
-- 다른 클라 점검이 Toast · 배너 자리를 다 쓴 뒤에 돈다(CHECK_DELAY).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local TextAudit = require(script.Parent.Parent.ui.TextAudit)
local PartyListView = require(script.Parent.PartyListView)
local RequestBanner = require(script.Parent.RequestBanner)

if not (RunService:IsStudio() and (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S18(UI)"))) then
	return
end

local player = Players.LocalPlayer
local CHECK_DELAY = 125
-- SkillSlots.client.lua 터치 레이아웃의 값(대시 버튼 = 왼쪽 24 · 크기 54 · 아래 끝 = 점프 버튼 자리(작은 화면 = 화면 짧은 변 ≤ 500이면 70 + 20 · 아니면 120 × 1.75) + 여백 16). 그 파일이 바뀌면 여기도 바꾼다.
-- 폰 배율 스크린샷 Play(S18, 842 × 534 - 짧은 변 592 > 500이라 큰 화면 값)의 실제 인스턴스 대시 (24, 254) 54 × 54와 이 식이 같음을 확인했다.
local TOUCH = { dashLeft = 24, dashSize = 54, smallAxis = 500, smallBottom = 70 + 20, largeBottom = 120 * 1.75, margin = 16 }
local function dashBottom(width, screenHeight, inset)
	return (math.min(width, screenHeight + inset) <= TOUCH.smallAxis and TOUCH.smallBottom or TOUCH.largeBottom) + TOUCH.margin
end
local OLD_LIST = { width = 196, height = 222 } -- 옛 PartyHud 목록(폭 196 · 4행 44 · 간격 6 · 경험치 칩 22 + 6) - 겹침 재현용

local function rect(x, y, w, h)
	return { min = Vector2.new(x, y), max = Vector2.new(x + w, y + h) }
end

local function overlapSize(a, b)
	local w = math.min(a.max.X, b.max.X) - math.max(a.min.X, b.min.X)
	local h = math.min(a.max.Y, b.max.Y) - math.max(a.min.Y, b.min.Y)
	if w > 0 and h > 0 then
		return w, h
	end
	return 0, 0
end

local function selfCheck()
	local pass, total = 0, 0
	print("===S18 검증 시작(UI: PartyHud 분할 - 목록 · 요청 배너)===")
	local function check(label, passed)
		total += 1
		if passed then
			pass += 1
		end
		print(("[S18][UI] %s %s"):format(label, passed and "O" or "X"))
	end

	local playerGui = player:WaitForChild("PlayerGui")
	local testGui = Instance.new("ScreenGui")
	testGui.Name = "PartyHudCheckGui"
	testGui.Parent = playerGui

	local ok, err = pcall(function()
		-- ① 신호 대조표
		local scripts = player:WaitForChild("PlayerScripts"):FindFirstChild("hud")
		local listScript, requestScript = scripts and scripts:FindFirstChild("PartyList"), scripts and scripts:FindFirstChild("PartyRequests")
		local function hasSignals(script, names)
			local attribute = script and script:GetAttribute("Signals") or ""
			for _, name in ipairs(names) do
				if not attribute:find(name, 1, true) or not ReplicatedStorage:FindFirstChild(name) then
					return false
				end
			end
			return true
		end
		local hudGui = playerGui:FindFirstChild("PartyHudGui")
		local hudChildren = {}
		for _, child in ipairs(hudGui and hudGui:GetChildren() or {}) do
			table.insert(hudChildren, child.Name)
		end
		local oldScript = player.PlayerScripts:FindFirstChild("PartyHud")
		check(("신호 대조: PartyList가 PartyStateChanged %s · PartyRequests가 PartyInviteNotice · PartyNotice · FriendJoinedNotice · PartyVoteNotice %s · FireServer 대상 PartyRequest 있음 %s · 옛 PartyHud 스크립트 %s(기대 없음) · PartyHudGui 자식 [%s](기대 PartyList만) · 옛 PartyToast · PartyVotePanel %s(기대 없음)"):format(
			tostring(hasSignals(listScript, { "PartyStateChanged" })), tostring(hasSignals(requestScript, { "PartyInviteNotice", "PartyNotice", "FriendJoinedNotice", "PartyVoteNotice" })),
			tostring(ReplicatedStorage:FindFirstChild("PartyRequest") ~= nil), tostring(oldScript ~= nil), table.concat(hudChildren, ","),
			tostring(playerGui:FindFirstChild("PartyToast", true) ~= nil or playerGui:FindFirstChild("PartyVotePanel", true) ~= nil)),
			hasSignals(listScript, { "PartyStateChanged" }) and hasSignals(requestScript, { "PartyInviteNotice", "PartyNotice", "FriendJoinedNotice", "PartyVoteNotice" })
				and ReplicatedStorage:FindFirstChild("PartyRequest") ~= nil and oldScript == nil and #hudChildren == 1 and hudChildren[1] == "PartyList"
				and playerGui:FindFirstChild("PartyToast", true) == nil and playerGui:FindFirstChild("PartyVotePanel", true) == nil)

		-- ② 목록 뷰 두 모드 - 합성 4인(파티장 · 환생 · 쉴드 · 버프 · 체력 각각)
		local classNames = { "대검", "활", "쌍검", "힐러" }
		local members = {}
		for index = 1, 4 do
			members[index] = { nameText = "멤버" .. index, level = 30 + index, rebirth = index == 2 and 1 or nil, className = classNames[index], stage = 12,
				ratio = ({ 1, 0.5, 0.25, 0 })[index], shieldRatio = index == 3 and 0.4 or 0, buffActive = index == 4, isLeader = index == 1 }
		end
		local viewport = testGui.AbsoluteSize

		local pc = PartyListView.build({ parent = testGui, compact = false })
		pc.list.Name = "PartyListCheckPc"
		pc.setMembers(members)
		pc.setExpBonus(0.15)
		pc.applyPosition(viewport.Y)
		task.wait(0.5)
		local pcReport = TextAudit.report(testGui)
		local titles = {}
		for index = 1, 4 do
			titles[index] = pc.rows[index].title.Text:gsub("<[^>]+>", "")
		end
		local blockSize = pc.rows[1].block.AbsoluteSize
		local expectPc = PartyListView.heightFor(4, true, false)
		check(("PC 목록 4인: 행 %d · 블록 %d × %d(기대 220 × 52 = ListRow 40 + 2 + Gauge 10) · 목록 %d × %d(기대 220 × %d) · 제목 [%s](기대 파티장 이름에 '멤버1' · 환생 ★1) · 부제 '%s'(기대 '대검 · 스테이지 12') · 왼쪽 칸 '%s'(기대 '대')"):format(
			pc.rowCount(), blockSize.X, blockSize.Y, pc.list.AbsoluteSize.X, pc.list.AbsoluteSize.Y, expectPc, table.concat(titles, " | "),
			pc.rows[1].row.root:FindFirstChild("Subtitle").Text, pc.rows[1].icon.Text),
			pc.rowCount() == 4 and blockSize.X == 220 and blockSize.Y == 52 and math.abs(pc.list.AbsoluteSize.X - 220) < 1 and math.abs(pc.list.AbsoluteSize.Y - expectPc) < 1
				and titles[1]:find("멤버1", 1, true) ~= nil and titles[2]:find("★1", 1, true) ~= nil and pc.rows[1].row.root:FindFirstChild("Subtitle").Text == "대검 · 스테이지 12" and pc.rows[1].icon.Text == "대")
		local shieldRow = pc.rows[3]
		check(("PC 색 · 값: 파티장 이름 금색 %s · 다른 멤버 기본색 %s · 체력 줄 값 %.2f/%.2f/%.2f/%.2f(기대 1/0.5/0.25/0) · 쉴드 띠 3번 %s 폭 %.2f(기대 true 0.40) · 1번 %s(기대 false) · 버프 링 4번 초록 %s · 다른 멤버 링 기본 %s · 경험치 칩 '%s' 보임 %s(기대 '경험치 +15%%' true)"):format(
			tostring(pc.rows[1].title.TextColor3 == UIColors.gold), tostring(pc.rows[2].title.TextColor3 == UIColors.textPrimary),
			pc.rows[1].gauge.getValue(), pc.rows[2].gauge.getValue(), pc.rows[3].gauge.getValue(), pc.rows[4].gauge.getValue(),
			tostring(shieldRow.shield.Visible), shieldRow.shield.Size.X.Scale, tostring(pc.rows[1].shield.Visible), tostring(pc.rows[4].stroke.Color == UIColors.success),
			tostring(pc.rows[1].stroke.Color == UIColors.rim), pc.chip.Text.Text, tostring(pc.chipHolder.Visible)),
			pc.rows[1].title.TextColor3 == UIColors.gold and pc.rows[2].title.TextColor3 == UIColors.textPrimary
				and pc.rows[1].gauge.getValue() == 1 and pc.rows[2].gauge.getValue() == 0.5 and pc.rows[3].gauge.getValue() == 0.25 and pc.rows[4].gauge.getValue() == 0
				and shieldRow.shield.Visible and math.abs(shieldRow.shield.Size.X.Scale - 0.4) < 1e-6 and not pc.rows[1].shield.Visible
				and pc.rows[4].stroke.Color == UIColors.success and pc.rows[1].stroke.Color == UIColors.rim and pc.chip.Text.Text == "경험치 +15%" and pc.chipHolder.Visible)
		local centerRect = ScreenMap.centerRect(viewport)
		local listRight = pc.list.AbsolutePosition.X + pc.list.AbsoluteSize.X
		check(("PC 자리: 목록 오른쪽 끝 %d ≤ 중앙 금지 구역 왼쪽 %d(기대 true) · 글씨 실효 12 미만 %d개 [%s](기대 0 - 보이는 글 %d개 · 최소 %.1f)"):format(
			listRight, centerRect.min.X, #pcReport.low, table.concat(pcReport.low, ","), pcReport.count, pcReport.minEffective), listRight <= centerRect.min.X and #pcReport.low == 0 and pcReport.count >= 8)
		pc.setExpBonus(0)
		task.wait(0.3)
		check(("경험치 칩 0이면 숨음: 칩 보임 %s(기대 false) · 목록 높이 %d(기대 %d)"):format(tostring(pc.chipHolder.Visible), pc.list.AbsoluteSize.Y, PartyListView.heightFor(4, false, false)),
			not pc.chipHolder.Visible and math.abs(pc.list.AbsoluteSize.Y - PartyListView.heightFor(4, false, false)) < 1)
		pc.destroy()

		local compact = PartyListView.build({ parent = testGui, compact = true })
		compact.list.Name = "PartyListCheckCompact"
		compact.setMembers(members)
		compact.setExpBonus(0.15)
		compact.applyPosition(viewport.Y)
		task.wait(0.5)
		local dots, gaugeWidths, rowSizes = {}, {}, {}
		for index, row in ipairs(compact.rows) do
			dots[index] = row.dot.Visible
			gaugeWidths[index] = row.gauge.root.AbsoluteSize.X
			rowSizes[index] = row.block.AbsoluteSize.X .. "×" .. row.block.AbsoluteSize.Y
		end
		local expectCompact = PartyListView.heightFor(4, true, true)
		check(("모바일 축약형 4인: 목록 %d × %d(기대 96 × %d = 행 44 × 4 + 칩 26) · 행 [%s](기대 96×44) · 체력 줄 폭 [%s](기대 78) · 파티장 ● [%s](기대 true false false false) · 이름 표시 없음(Title 라벨 %s · 처음에 이름 팁 %s)"):format(
			compact.list.AbsoluteSize.X, compact.list.AbsoluteSize.Y, expectCompact, table.concat(rowSizes, ","), table.concat(gaugeWidths, ","), table.concat({ tostring(dots[1]), tostring(dots[2]), tostring(dots[3]), tostring(dots[4]) }, " "),
			tostring(compact.list:FindFirstChild("Title", true) ~= nil), tostring(compact.rows[2].tip.Visible)),
			math.abs(compact.list.AbsoluteSize.X - 96) < 1 and math.abs(compact.list.AbsoluteSize.Y - expectCompact) < 1 and dots[1] and not dots[2] and not dots[3] and not dots[4]
				and gaugeWidths[1] == 78 and gaugeWidths[4] == 78 and rowSizes[3] == "96×44" and compact.list:FindFirstChild("Title", true) == nil and not compact.rows[2].tip.Visible)
		compact.rows[2].showTip() -- 행 Activated와 같은 함수
		local shownAtOnce = compact.rows[2].tip.Visible
		local tipText = compact.rows[2].tipLabel.Text:gsub("<[^>]+>", "")
		task.wait(PartyListView.compact.tipSeconds + 0.4)
		check(("모바일 이름 표시: 행을 누르면 이름 팁 보임 %s('%s' - 기대 true '★1 Lv.32 멤버2') · %d초 뒤 사라짐 %s(기대 true)"):format(tostring(shownAtOnce), tipText, PartyListView.compact.tipSeconds, tostring(not compact.rows[2].tip.Visible)),
			shownAtOnce and tipText:find("멤버2", 1, true) ~= nil and not compact.rows[2].tip.Visible)

		-- ③ 폰 가로 폭 844: 파티 4인 + 경험치 칩(가장 큰 경우) 목록 × 대시 버튼 · 체력바 · 조이스틱 구역
		local phoneWidth = 844
		local healthSlot = ScreenMap.slot("BC", "healthBar")
		local listSlot = ScreenMap.slot("ML", "partyList")
		local lines, allClear = {}, true
		local inset = game:GetService("GuiService"):GetGuiInset().Y
		-- 388 · 414 = 폰 가로(작은 화면 값) - 겹침 0이어야 한다. 534 = Studio 뷰포트 최대(큰 화면 값 - 대시가 더 높이 올라온다): 실측 겹침(대시 8 × 40)이 재현되는지만 본다(참고 - 합격 조건 아님).
		for _, height in ipairs({ 388, 414, 534 }) do
			local listHeight = PartyListView.heightFor(4, true, true)
			local shift = ScreenMap.mobileMenuBarShiftUp(height, listHeight)
			local left = listSlot.position.X.Offset
			local listRect = rect(left, height / 2 - listHeight / 2 - shift, PartyListView.compact.width, listHeight)
			local dashY = height - dashBottom(phoneWidth, height, inset)
			local dash = rect(TOUCH.dashLeft, dashY - TOUCH.dashSize, TOUCH.dashSize, TOUCH.dashSize)
			local health = rect((phoneWidth - healthSlot.size.X.Offset) / 2, height + healthSlot.position.Y.Offset - healthSlot.size.Y.Offset, healthSlot.size.X.Offset, healthSlot.size.Y.Offset)
			local joystick = ScreenMap.rectFromFractions(ScreenMap.mobileReserved.BL, Vector2.new(phoneWidth, height))
			local dashW, dashH = overlapSize(listRect, dash)
			local healthW, healthH = overlapSize(listRect, health)
			local joyW, joyH = overlapSize(listRect, { min = joystick.min, max = joystick.max })
			local oldRect = rect(left, height / 2 - OLD_LIST.height / 2, OLD_LIST.width, OLD_LIST.height)
			local oldDashW, oldDashH = overlapSize(oldRect, dash)
			local oldHealthW, oldHealthH = overlapSize(oldRect, health)
			local clear = dashW == 0 and healthW == 0 and joyW == 0 and listRect.min.Y >= ScreenMap.menuBar.topMargin - 1e-6
			if height <= 414 then
				allClear = allClear and clear
			else
				allClear = allClear and dashW == 8 and dashH == 40 -- 참고 재현: 폰 배율 Play 실측 대시 8 × 40
			end
			allClear = allClear and (height ~= 388 or (oldDashW > 0 and oldHealthW > 0)) -- 388에서는 옛 배치의 겹침(대시 · 체력바)이 재현돼야 계산이 맞다
			table.insert(lines, ("H%d 위로 %.0f → 목록 (%d, %.0f) ~ 아래 %.0f · 대시 %d×%d · 체력바 %d×%d · 조이스틱 %d×%d %s / 옛 배치 대시 %d×%d · 체력바 %d×%d"):format(
				height, shift, left, listRect.min.Y, listRect.max.Y, dashW, dashH, healthW, healthH, joyW, joyH, clear and "O" or "X", oldDashW, oldDashH, oldHealthW, oldHealthH))
		end
		check("폰 가로 844 · 파티 4인 겹침 0(388 · 414 재구성 · 534는 참고 재현): " .. table.concat(lines, " · "), allClear)
		compact.destroy()

		-- ④ 요청 배너
		RequestBanner.clear()
		local log, counts = {}, { accept = 0, decline = 0 }
		local function request(key, seconds, extra)
			local req = { key = key, title = "제목" .. key, body = "본문" .. key, seconds = seconds,
				onClose = function(reason)
					table.insert(log, key .. ":" .. reason)
				end,
				accept = { text = "수락", onActivated = function()
					counts.accept += 1
				end },
				decline = { text = "거절", onActivated = function()
					counts.decline += 1
				end } }
			for k, v in pairs(extra or {}) do
				req[k] = v
			end
			return req
		end
		local function visibleBanners()
			local n = 0
			for _, inst in ipairs(playerGui:GetDescendants()) do
				if inst.Name == "RequestBanner" and inst:IsA("GuiObject") and inst.Visible then
					n += 1
				end
			end
			return n
		end

		local r1 = RequestBanner.push(request("invite", 15))
		local r2 = RequestBanner.push(request("vote", 10))
		local state = RequestBanner.debugState()
		task.wait(0.3)
		local bannerReport = TextAudit.report(playerGui:FindFirstChild("RequestBannerGui"))
		local frame = state.frame
		check(("한 번에 하나: push 결과 %s/%s(기대 shown/queued) · 보이는 것 %s · 대기 [%s](기대 invite · vote) · 화면에 보이는 배너 %d개(기대 1) · 제목 '%s' · 게이지 %.2f(기대 1에 가까움) · 버튼 %s"):format(
			r1, r2, tostring(state.showing), table.concat(state.queued, ","), visibleBanners(), state.title, state.gaugeValue, tostring(state.buttonsShown)),
			r1 == "shown" and r2 == "queued" and state.showing == "invite" and #state.queued == 1 and state.queued[1] == "vote" and visibleBanners() == 1 and state.gaugeValue > 0.9 and state.buttonsShown)
		local viewportNow = frame.Parent.AbsoluteSize
		check(("배너 모양 · 자리: 크기 %d × %d(기대 224 × %d = 슬롯 표) · 오른쪽 끝 %d ≤ 화면 %d · 중앙 금지 구역 오른쪽 %d 밖 %s · DisplayOrder %d(기대 150 초과 200 미만) · 글씨 실효 12 미만 %d개 [%s](기대 0 - 보이는 글 %d개 = 제목 · 본문 · 수락 · 거절)"):format(
			frame.AbsoluteSize.X, frame.AbsoluteSize.Y, ScreenMap.slot("MR", "requestBanner").size.Y.Offset, frame.AbsolutePosition.X + frame.AbsoluteSize.X, viewportNow.X,
			ScreenMap.centerRect(viewportNow).max.X, tostring(frame.AbsolutePosition.X >= ScreenMap.centerRect(viewportNow).max.X), frame.Parent.DisplayOrder, #bannerReport.low, table.concat(bannerReport.low, ","), bannerReport.count),
			math.abs(frame.AbsoluteSize.X - 224) < 1 and math.abs(frame.AbsoluteSize.Y - ScreenMap.slot("MR", "requestBanner").size.Y.Offset) < 1 and frame.AbsolutePosition.X + frame.AbsoluteSize.X <= viewportNow.X + 0.5
				and frame.AbsolutePosition.X >= ScreenMap.centerRect(viewportNow).max.X and frame.Parent.DisplayOrder > 150 and frame.Parent.DisplayOrder < 200 and #bannerReport.low == 0 and bannerReport.count == 4)

		-- PC 겹침: 화면에 보이는 ScreenMap 슬롯(가방 버튼 · 칩 스택 · 파티 버튼 등)과 겹치는 자리가 0개(투표 패널이 가방 버튼과 겹치던 옛 배치의 개선)
		local bannerRect = rect(frame.AbsolutePosition.X, frame.AbsolutePosition.Y, frame.AbsoluteSize.X, frame.AbsoluteSize.Y)
		local bannerHits, compared = {}, 0
		for zone, name, slot in ScreenMap.each() do
			local inst = slot.instanceName and slot.instanceName ~= "RequestBanner" and playerGui:FindFirstChild(slot.instanceName, true)
			if inst and inst:IsA("GuiObject") and inst.Visible and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 then
				compared += 1
				local w = overlapSize(bannerRect, rect(inst.AbsolutePosition.X, inst.AbsolutePosition.Y, inst.AbsoluteSize.X, inst.AbsoluteSize.Y))
				if w > 0 then
					table.insert(bannerHits, zone .. "." .. name)
				end
			end
		end
		check(("배너 PC 겹침: 보이는 슬롯 %d개와 비교 · 겹친 것 %d개 [%s](기대 0)"):format(compared, #bannerHits, table.concat(bannerHits, ",")), #bannerHits == 0 and compared >= 3)

		RequestBanner.debugPress("decline")
		local afterDecline = RequestBanner.debugState()
		RequestBanner.debugPress("accept")
		local afterAccept = RequestBanner.debugState()
		check(("대기열 순서: 거절 → 거절 콜백 %d회(기대 1) · 닫힘 이유 %s · 그다음 vote가 뜸 %s(기대 vote) · 수락 → 수락 콜백 %d회(기대 1) · 이유 %s · 배너 닫힘 %s"):format(
			counts.decline, log[1] or "-", tostring(afterDecline.showing), counts.accept, log[2] or "-", tostring(not afterAccept.visible)),
			counts.decline == 1 and log[1] == "invite:decline" and afterDecline.showing == "vote" and counts.accept == 1 and log[2] == "vote:accept" and afterAccept.showing == nil and not afterAccept.visible)

		-- keepOpen(투표) + resolve
		log = {}
		RequestBanner.push(request("vote", 10, { accept = { text = "동의", keepOpen = true, onActivated = function()
			counts.accept += 1
		end } }))
		RequestBanner.debugPress("accept")
		local kept = RequestBanner.debugState()
		RequestBanner.resolve("vote", { title = "제목vote", body = "투표 통과 - 이동합니다", seconds = 0.6 })
		local resolved = RequestBanner.debugState()
		task.wait(1.0)
		check(("keepOpen + resolve: 동의 뒤 배너 남음 %s · 버튼 사라짐 %s(기대 true · true) · 결과 안내 본문 '%s' · 버튼 %s(기대 false) · 0.6초 뒤 닫힘 %s · 이유 %s(기대 vote:resolved)"):format(
			tostring(kept.showing == "vote"), tostring(not kept.buttonsShown), resolved.body, tostring(resolved.buttonsShown), tostring(RequestBanner.debugState().showing == nil), log[1] or "-"),
			kept.showing == "vote" and not kept.buttonsShown and resolved.body == "투표 통과 - 이동합니다" and not resolved.buttonsShown and RequestBanner.debugState().showing == nil and log[1] == "vote:resolved")

		-- 도착 시각부터 세는 만료: 대기 중에 지난 요청은 차례가 와도 띄우지 않는다
		log = {}
		RequestBanner.push(request("a", 5))
		RequestBanner.push(request("b", 1))
		task.wait(1.4)
		RequestBanner.debugPress("decline")
		local skipped = RequestBanner.debugState()
		check(("만료는 도착 시각부터: a(5초)가 떠 있는 동안 b(1초)가 대기 → 1.4초 뒤 a를 거절해도 b가 안 뜸 %s(기대 nil) · b 이유 %s(기대 b:timeout)"):format(tostring(skipped.showing), table.concat(log, ",")),
			skipped.showing == nil and log[1] == "a:decline" and log[2] == "b:timeout")

		-- 같은 key 교체 · 정보 배너
		log = {}
		local first = RequestBanner.push(request("x", 5))
		local replaced = RequestBanner.push(request("x", 5, { body = "새 본문" }))
		local bodyAfter = RequestBanner.debugState().body
		RequestBanner.push(request("y", 5))
		local queuedAgain = RequestBanner.push(request("y", 5))
		local queuedCount = #RequestBanner.debugState().queued
		RequestBanner.clear()
		local withButtons = frame.AbsoluteSize.Y
		RequestBanner.push({ key = "info", title = "정보", body = "파티장 화면", seconds = 3 })
		task.wait(0.2)
		local info = RequestBanner.debugState()
		local infoHeight = info.frame.AbsoluteSize.Y
		check(("같은 key 교체 · 정보 배너: 첫 %s · 같은 key 다시 %s(기대 shown · replaced) · 본문 '%s'(기대 '새 본문') · 대기 key 교체 %s 대기 수 %d(기대 queued 1) · 정보 배너 버튼 %s(기대 false) · 높이 %d < 버튼 있는 %d %s"):format(
			first, replaced, bodyAfter, queuedAgain, queuedCount, tostring(info.buttonsShown), infoHeight, withButtons, tostring(infoHeight < withButtons)),
			first == "shown" and replaced == "replaced" and bodyAfter == "새 본문" and queuedAgain == "queued" and queuedCount == 1 and not info.buttonsShown and infoHeight < withButtons)
		RequestBanner.clear()

		-- 남은 시간 게이지
		RequestBanner.push(request("t", 1.2))
		task.wait(0.7)
		local mid = RequestBanner.debugState().gaugeValue
		task.wait(0.8)
		local ended = RequestBanner.debugState()
		check(("남은 시간 게이지: 0.7초 뒤 %.2f(기대 0.2 ~ 0.6) · 1.5초 뒤 닫힘 %s(기대 true)"):format(mid, tostring(ended.showing == nil)), mid > 0.2 and mid < 0.6 and ended.showing == nil)
	end)
	if not ok then
		check(("자체 점검 실행 중 에러: %s"):format(tostring(err)), false)
	end
	RequestBanner.clear()
	testGui:Destroy()
	print(("===S18 검증 끝(UI)=== %d/%d 통과"):format(pass, total))
end

task.delay(CHECK_DELAY, selfCheck)
