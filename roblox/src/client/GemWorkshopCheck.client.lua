-- S20e 자체 점검 [S20e][UI] - "보석 공방" 창 · [위치 안내] 마커 · 진입점 토스트 · 서버 반경 거절(실제 RemoteEvent) · station 상호 닫힘 · 폰 치수를 실제 인스턴스로 잰다.
-- Studio에서 DevToolsConfig.verify에 "S20e(UI)"가 있을 때만 돈다. 서버 없이 창에 상태를 직접 넣어 그리고(GemWorkshop.debugApply), 요청은 실제 RemoteEvent로 보낸다 -
-- 이 캐릭터는 보석상인 반경 밖이라 서버가 out_of_range로 거절하고 상태는 안 바뀐다(거절 경로가 바로 이 점검의 대상 - 성공 경로는 서버 (나)가 잰다).
-- 마우스 입력(창 연 상태의 실제 클릭)은 못 한다 - 수동 Play(user_mouse_input)에서 본다(입력 층 결함은 자체 점검이 못 잡는다 - COMMON §2).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S20e(UI)")) then
	return
end

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local GemWorkshop = require(script.Parent.panels.GemWorkshop)
local Guide = require(script.Parent.panels.GemWorkshop.Guide)
local Hint = require(script.Parent.panels.GemWorkshop.Hint)
local TextAudit = require(script.Parent.ui.TextAudit)
local Toast = require(script.Parent.ui.kit.Toast)
local UIManager = require(script.Parent.UIManager)

local player = Players.LocalPlayer
local START_DELAY = 215 -- 창을 여는 다른 점검(S20d(UI) 150초 + 약 40초)이 끝난 뒤
local TOUCH_MIN = 44

local function item(part, grade, itemLevel)
	return { grade = grade, part = part, dropStage = 1, itemLevel = itemLevel, tierIndex = 1, locked = false, option = nil }
end

local function countRows(built, prefix)
	local count = 0
	for name in pairs(built.rows) do
		if name:sub(1, #prefix) == prefix then
			count += 1
		end
	end
	return count
end

local function insideScreen(frame, gui)
	local top, bottom = frame.AbsolutePosition.Y, frame.AbsolutePosition.Y + frame.AbsoluteSize.Y
	local left, right = frame.AbsolutePosition.X, frame.AbsolutePosition.X + frame.AbsoluteSize.X
	local gTop, gLeft = gui.AbsolutePosition.Y, gui.AbsolutePosition.X
	return top >= gTop - 1 and bottom <= gTop + gui.AbsoluteSize.Y + 1 and left >= gLeft - 1 and right <= gLeft + gui.AbsoluteSize.X + 1
end

local function run()
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ok)
		print(("[S20e][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end
	print("===S20e(UI) 검증 시작(보석 공방 창 · 위치 안내 마커 · 진입점 토스트 · 서버 반경 거절 · station 상호 닫힘 · 폰 치수)===")

	local originalGold = player:GetAttribute("Gold")
	GemWorkshop.debugSkipRangeClose(true) -- 이 캐릭터는 반경 밖 - 걸어서 벗어나면 닫히는 규칙은 아래에서 따로 잰다
	local function closeAll()
		UIManager.close("gemWorkshop", true)
		UIManager.close("stageSelect", true)
		UIManager.close("inventory", true)
		task.wait(0.3)
	end
	closeAll()

	-- ① 창 열기: station · 상태를 넣어 그리면 행이 만들어진다(변환권 2행 + 대상 = 홈 2 · 착용 1 · 가방 2)
	local opened = GemWorkshop.open()
	task.wait(0.5)
	local built = GemWorkshop.debugBuilt()
	check(("보석 공방 열림(open %s) · station 종류(%s) · 창 프레임 있음"):format(tostring(opened), tostring(UIManager.getKind("gemWorkshop"))),
		opened == true and UIManager.isOpen("gemWorkshop") and UIManager.getKind("gemWorkshop") == "station" and built ~= nil)
	if not built then
		print(("===S20e(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
		return
	end

	player:SetAttribute("Gold", 1e12) -- 이 클라에서만 보이는 값(구매 버튼이 활성이려면 골드가 가격 이상이어야 한다) - 끝에서 되돌린다
	GemWorkshop.debugApply({
		gems = { { grade = "primordial", itemLevel = 30 }, { grade = "epic", itemLevel = 30 }, { grade = "ancient", itemLevel = 30 }, false, false },
		tickets = { ancient = 1, primordial = 0 },
		inventory = { item("gloves", "ancient", 21), item("shoes", "epic", 22), item("armor", "primordial", 23) },
		equipment = { armor = item("armor", "ancient", 20) },
	})
	task.wait(0.3)
	local tickets = countRows(built, "Ticket_")
	local targets = countRows(built, "Target_")
	check(("행: 변환권 %d(기대 2 - 고대 · 태초) · 리롤 대상 %d(기대 5 - 홈 2 · 착용 1 · 가방 2, 영웅은 제외)"):format(tickets, targets), tickets == 2 and targets == 5 and built.rows["Target_gem_2"] == nil and built.rows["Target_bag_2"] == nil)
	check(("버튼 상태: 고대(변환권 1장) 행 활성 %s · 태초(0장) 행 회색 %s · 구매 버튼 활성(골드 충분) %s"):format(tostring(built.rows["Target_gem_3"].getVisual() ~= "disabled"), tostring(built.rows["Target_gem_1"].getVisual() == "disabled"), tostring(built.rows["Ticket_ancient"].getVisual() ~= "disabled")),
		built.rows["Target_gem_3"].getVisual() ~= "disabled" and built.rows["Target_gem_1"].getVisual() == "disabled" and built.rows["Ticket_ancient"].getVisual() ~= "disabled")
	local low = TextAudit.report(built.panel.frame).low
	check(("글씨 실효 12 이상(12 미만 %d개 %s)"):format(#low, table.concat(low, ", ")), #low == 0)
	check("창이 화면 안(위 · 아래 · 좌우)", insideScreen(built.panel.frame, built.panel.screenGui))

	-- ② station 상호 닫힘: 다른 station을 열면 닫히고(열려 있는 동안 서로 하나씩), window(가방)가 열려 있으면 station은 열리지 않는다
	local stageOpened = UIManager.open("stageSelect")
	task.wait(0.4)
	check(("station 상호 닫힘: 스테이지 선택을 열면(%s) 보석 공방이 닫힌다(열림 %s)"):format(tostring(stageOpened), tostring(UIManager.isOpen("gemWorkshop"))), stageOpened == true and not UIManager.isOpen("gemWorkshop") and UIManager.isOpen("stageSelect"))
	local reopened = GemWorkshop.open()
	task.wait(0.4)
	check(("보석 공방을 다시 열면(%s) 스테이지 선택이 닫힌다(열림 %s)"):format(tostring(reopened), tostring(UIManager.isOpen("stageSelect"))), reopened == true and UIManager.isOpen("gemWorkshop") and not UIManager.isOpen("stageSelect"))
	UIManager.open("inventory")
	task.wait(0.5)
	check("window(가방)를 열면 보석 공방이 닫힌다", UIManager.isOpen("inventory") and not UIManager.isOpen("gemWorkshop"))
	local blocked = GemWorkshop.open()
	task.wait(0.3)
	check(("가방이 열려 있는 동안 보석 공방은 열리지 않는다(open %s)"):format(tostring(blocked)), blocked == false and not UIManager.isOpen("gemWorkshop"))
	UIManager.close("inventory", true)
	task.wait(0.3)

	-- ③ 서버 반경 거절(실제 RemoteEvent): 이 캐릭터는 보석상인 반경 밖 - 클라가 요청을 직접 보내도 서버가 거절한다(창이 열려 있든 아니든 상관없다)
	do
		local result = ReplicatedStorage:WaitForChild("GemWorkshopResult")
		local got = {}
		local connection = result.OnClientEvent:Connect(function(action, success, reason)
			table.insert(got, { action = action, success = success, reason = reason })
		end)
		ReplicatedStorage.GemRerollRequest:FireServer("gem", 1)
		ReplicatedStorage.BuyRerollTicketRequest:FireServer("primordial")
		ReplicatedStorage.GemRerollRequest:FireServer("hat", 1)
		local waited = 0
		while #got < 3 and waited < 4 do
			task.wait(0.2)
			waited += 0.2
		end
		connection:Disconnect()
		local function has(action, reason)
			for _, entry in ipairs(got) do
				if entry.action == action and entry.success == false and entry.reason == reason then
					return true
				end
			end
			return false
		end
		check(("실제 요청: 리롤 → out_of_range %s · 변환권 구매 → out_of_range %s · 모르는 kind → invalid %s (받은 결과 %d개)"):format(tostring(has("reroll", "out_of_range")), tostring(has("buy", "out_of_range")), tostring(has("reroll", "invalid")), #got),
			has("reroll", "out_of_range") and has("buy", "out_of_range") and has("reroll", "invalid"))
	end

	-- ④ [위치 안내] 마커: 보석상인 위 앵커 + 표지 + 선(Beam) · guideSeconds 뒤 저절로 사라진다 · 공방을 열면 꺼진다
	do
		local shown = Guide.show()
		task.wait(0.3)
		local anchor = Workspace:FindFirstChild("GemMerchantGuideAnchor")
		local marker = anchor and anchor:FindFirstChild("GemMerchantGuideMarker")
		local beam = anchor and anchor:FindFirstChildWhichIsA("Beam")
		local expected = Guide.merchantPosition() + Vector3.new(0, 9, 0)
		check(("위치 안내 표시(show %s): 앵커가 보석상인 위 %s · 표지 %s · 선 %s · 표시 중 %s"):format(tostring(shown), tostring(anchor and (anchor.Position - expected).Magnitude < 0.5), tostring(marker ~= nil), tostring(beam ~= nil and beam.Attachment0 ~= nil and beam.Attachment1 ~= nil), tostring(Guide.isShowing())),
			shown == true and anchor ~= nil and (anchor.Position - expected).Magnitude < 0.5 and marker ~= nil and beam ~= nil and beam.Attachment0 ~= nil and beam.Attachment1 ~= nil and Guide.isShowing())
		task.wait(WorldConfig.gemMerchant.guideSeconds + 1.5)
		check(("%d초 뒤 저절로 사라진다(앵커 %s · 표시 중 %s)"):format(WorldConfig.gemMerchant.guideSeconds, tostring(Workspace:FindFirstChild("GemMerchantGuideAnchor") ~= nil), tostring(Guide.isShowing())),
			Workspace:FindFirstChild("GemMerchantGuideAnchor") == nil and not Guide.isShowing())
		Guide.show()
		task.wait(0.2)
		GemWorkshop.open()
		task.wait(0.5)
		check("보석 공방을 열면 위치 안내가 꺼진다(찾아왔으니)", Workspace:FindFirstChild("GemMerchantGuideAnchor") == nil and not Guide.isShowing())
		UIManager.close("gemWorkshop", true)
		task.wait(0.3)
	end

	-- ⑤ 진입점 토스트: "보석상인에게서 가능 [위치 안내]"(창 위 notice 등급)
	do
		Toast.clear()
		Hint.toast()
		task.wait(0.4)
		local texts = Toast.debugTexts("TC")
		check(("진입점 토스트: \"%s\""):format(texts[1] or "(없음)"), #texts == 1 and texts[1]:find("보석상인에게서 가능", 1, true) ~= nil and texts[1]:find("[위치 안내]", 1, true) ~= nil)
		Toast.clear()
	end

	-- ⑥ 폰 배치(ForceTouchLayout): 버튼 터치 44 이상 · 글씨 실효 12 이상 · 창이 화면 안
	do
		player:SetAttribute("ForceTouchLayout", true)
		task.wait(0.3)
		GemWorkshop.open()
		task.wait(0.6)
		built = GemWorkshop.debugBuilt()
		GemWorkshop.debugApply({
			gems = { { grade = "primordial", itemLevel = 30 }, false, { grade = "ancient", itemLevel = 30 }, false, false },
			tickets = { ancient = 1, primordial = 0 },
			inventory = { item("gloves", "ancient", 21), item("armor", "primordial", 23) },
			equipment = { armor = item("armor", "ancient", 20) },
		})
		task.wait(0.4)
		local small = {}
		for name, button in pairs(built.rows) do
			if button.root.AbsoluteSize.Y < TOUCH_MIN - 0.5 then
				table.insert(small, ("%s %d"):format(name, button.root.AbsoluteSize.Y))
			end
		end
		check(("폰 배치: 모든 버튼 높이 44 이상(작은 것 %d개 %s · 행 %d개 - 변환권 2 + 대상 5)"):format(#small, table.concat(small, ", "), countRows(built, "Ticket_") + countRows(built, "Target_")), #small == 0 and countRows(built, "Target_") == 5)
		local lowPhone = TextAudit.report(built.panel.frame).low
		check(("폰 배치: 글씨 실효 12 이상(12 미만 %d개) · 창이 화면 안 %s"):format(#lowPhone, tostring(insideScreen(built.panel.frame, built.panel.screenGui))), #lowPhone == 0 and insideScreen(built.panel.frame, built.panel.screenGui))
		UIManager.close("gemWorkshop", true)
		player:SetAttribute("ForceTouchLayout", nil)
		task.wait(0.3)
	end

	-- ⑦ 걸어서 반경을 벗어나면 저절로 닫힌다(표시 편의 - 판정은 서버): 이 캐릭터는 반경 밖이라 열자마자 닫혀야 한다
	do
		GemWorkshop.debugSkipRangeClose(false)
		GemWorkshop.open()
		task.wait(0.8)
		check(("반경 밖에서 열면 저절로 닫힌다(열림 %s)"):format(tostring(UIManager.isOpen("gemWorkshop"))), not UIManager.isOpen("gemWorkshop"))
		GemWorkshop.debugSkipRangeClose(true)
	end

	-- 정리
	GemWorkshop.debugSkipRangeClose(false)
	player:SetAttribute("Gold", originalGold)
	GemWorkshop.debugReset()
	closeAll()
	print(("===S20e(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S20e][UI] 점검 에러: " .. tostring(err))
		GemWorkshop.debugSkipRangeClose(false)
		UIManager.close("gemWorkshop", true)
		player:SetAttribute("ForceTouchLayout", nil)
	end
end)
