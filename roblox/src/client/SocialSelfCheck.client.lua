-- S12b 클라 자체 점검(Studio 전용 · DevToolsConfig.verify.current에 "S12b(UI)"가 있을 때): 머리 위 이름표 · 파티창(열기 / 닫기 · P 키 등록 · 장비창 파티 탭 제거) · 장비 보기 창(실제 서버 조회) ·
-- 장비창 · 파티창 · 장비 보기 · 메뉴의 글씨 크기(12 미만 0개 · 4단 밖 0개 · 잘림 = 줄임표) · 새 HUD 버튼의 겹침. 알림 · 이름 메뉴 · 타이머는 hud/DropFeed.client.lua의 selfTestS12b가 본다.
-- 결과: `===S12b 검증 시작(UI: 창 · 글씨)===` … `[S12b][UI] … O/X` … `===S12b 검증 끝(UI: 창 · 글씨)=== n/m 통과`. P 키 실제 입력(채팅 중 무시)은 MCP Play에서 사람 손 대신 키를 보내 확인한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local UIManager = require(script.Parent.UIManager)
local Inspect = require(script.Parent.panels.Inspect)
local Party = require(script.Parent.panels.Party)
local PlayerMenu = require(script.Parent.panels.PlayerMenu)
local PanelRegistry = require(script.Parent.ui.PanelRegistry)
local ScreenMap = require(script.Parent.ui.ScreenMap)
local Theme = require(script.Parent.ui.kit.Theme)

if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S12b(UI)")) then
	return
end

local player = Players.LocalPlayer
local START_DELAY = 50 -- S10 · S12b(알림) 자체 점검이 끝난 뒤(둘 다 Toast를 쓴다)

local function rectOf(inst)
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

local function intersects(a, b)
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

-- root 아래 글 요소를 훑는다: 보이는 것만(자기와 조상이 모두 Visible) · TextSize 목록 · 실효 12 미만(TextSize × 조상 UIScale 누적 배율 - COMMON.md §2) · 4단 밖(명목 TextSize) · 넘치는데 줄임표가 없는 것 · 줄임표가 걸린 채 실제로 잘린 것.
local function scanText(root, tipRoot)
	local allowed = {}
	for _, name in ipairs({ "title", "header", "body", "caption" }) do
		allowed[Theme.textSize(name)] = true
	end
	local result = { count = 0, min = math.huge, minEffective = math.huge, below12 = {}, offTier = {}, overflowNoEllipsis = {}, ellipsized = {}, sizes = {} }
	for _, inst in ipairs(root:GetDescendants()) do
		if (inst:IsA("TextLabel") or inst:IsA("TextButton")) and (tipRoot == nil or not inst:IsDescendantOf(tipRoot)) then
			local shown = true
			local node = inst
			while node and node ~= root.Parent do
				if node:IsA("GuiObject") and not node.Visible then
					shown = false
					break
				end
				node = node.Parent
			end
			if shown and inst.Text ~= "" and inst.AbsoluteSize.X > 0 then
				result.count += 1
				local effective = Theme.effectiveTextSize(inst)
				result.min = math.min(result.min, inst.TextSize)
				result.minEffective = math.min(result.minEffective, effective)
				result.sizes[inst.TextSize] = (result.sizes[inst.TextSize] or 0) + 1
				if effective < Theme.minTextSize - 0.01 then
					table.insert(result.below12, ("%s=%g×%.2f"):format(inst.Name, inst.TextSize, effective / inst.TextSize))
				end
				if not allowed[inst.TextSize] then
					table.insert(result.offTier, inst.Name .. "=" .. inst.TextSize)
				end
				local overflow = not inst.TextWrapped and inst.TextBounds.X > inst.AbsoluteSize.X + 0.5
				if overflow and inst.TextTruncate ~= Enum.TextTruncate.AtEnd then
					table.insert(result.overflowNoEllipsis, inst.Name .. "(" .. inst.Text:sub(1, 12) .. ")")
				elseif overflow then
					table.insert(result.ellipsized, inst.Name .. "(" .. inst.Text:sub(1, 10) .. ")")
				end
			end
		end
	end
	return result
end

local function sizesLine(sizes)
	local keys = {}
	for size in pairs(sizes) do
		table.insert(keys, size)
	end
	table.sort(keys)
	local parts = {}
	for _, size in ipairs(keys) do
		table.insert(parts, ("%d×%d"):format(size, sizes[size]))
	end
	return table.concat(parts, " ")
end

local function selfTest()
	print("===S12b 검증 시작(UI: 창 · 글씨)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[S12b][UI] %s %s"):format(label, ok and "O" or "X"))
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local screen = playerGui:FindFirstChild("PartyToggleGui") and playerGui.PartyToggleGui.AbsoluteSize or Vector2.new(0, 0)
	print(("[S12b][UI][측정] 화면 %d × %d(%s)"):format(screen.X, screen.Y, Theme.isMobile and "모바일" or "PC"))

	-- 머리 위 이름표
	local character = player.Character or player.CharacterAdded:Wait()
	local billboard = character:WaitForChild("PlayerNameplate", 5)
	local nameLabel = billboard and billboard:FindFirstChildOfClass("TextLabel")
	local expectedPlain = PlayerLabelFormat.plain(player.DisplayName, player:GetAttribute("CharacterLevel"), player:GetAttribute("RebirthCount"))
	local shownPlain = nameLabel and (nameLabel.Text:gsub("<[^>]+>", "")) or "-"
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local buttonCount = 0
	for _, descendant in ipairs(billboard and billboard:GetDescendants() or {}) do
		if descendant:IsA("GuiButton") then
			buttonCount += 1
		end
	end
	check(("머리 위 이름표: 있음 %s · 글 [%s](기대 %s) · 최대 거리 %s(기대 60) · 클릭 없음(TextButton %d개, 기대 0) · 기본 이름표 %s(기대 None)"):format(
		tostring(billboard ~= nil), shownPlain, expectedPlain, billboard and tostring(billboard.MaxDistance) or "-", buttonCount, humanoid and tostring(humanoid.DisplayDistanceType) or "-"),
		billboard ~= nil and shownPlain == expectedPlain and billboard.MaxDistance == 60 and buttonCount == 0 and humanoid ~= nil and humanoid.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None)

	-- 파티창: P 키 등록 · HUD 버튼 · 열기 / 닫기 · 장비창 파티 탭 제거
	local partyButton = playerGui:FindFirstChild("PartyToggleGui") and playerGui.PartyToggleGui:FindFirstChild("PartyToggleButton")
	check(("파티창 등록: P 키 %s(기대 Enum.KeyCode.P) · 등록 종류 %s(기대 window) · HUD 버튼 있음 %s · 버튼 높이 %s(모바일이면 44 이상)"):format(
		tostring(PanelRegistry.hotkeyOf("party")), tostring(UIManager.getKind("party")), tostring(partyButton ~= nil), partyButton and tostring(partyButton.AbsoluteSize.Y) or "-"),
		PanelRegistry.hotkeyOf("party") == Enum.KeyCode.P and UIManager.getKind("party") == "window" and partyButton ~= nil and (not Theme.isMobile or partyButton.AbsoluteSize.Y >= 44))
	local opened = UIManager.open("party")
	task.wait(0.6)
	local partyFrame, partyGui = UIManager.getParts("party")
	local partyState = Party.debugState()
	local fits = partyFrame and partyGui and partyFrame.AbsoluteSize.Y <= partyGui.AbsoluteSize.Y and partyFrame.AbsolutePosition.Y >= 0 and partyFrame.AbsolutePosition.X >= 0
	check(("파티창 열기: open=%s · 열림 %s · 보임 %s · 제목 [%s](기대 내 파티 (0/4) 꼴) · 화면 안 %s(기대 true) · 캔버스 %s"):format(
		tostring(opened), tostring(UIManager.isOpen("party")), tostring(partyFrame and partyFrame.Visible), partyState.myTitle, tostring(fits), tostring(partyState.canvas)),
		opened == true and UIManager.isOpen("party") and partyFrame.Visible and partyState.myTitle:find("내 파티", 1, true) ~= nil and fits == true)
	local partyScan = scanText(partyGui)
	check(("파티창 글씨: 요소 %d개 · 최소 %s(실효 %.1f) · 실효 12 미만 %d개(기대 0) · 4단 밖 %d개 [%s](기대 0) · 넘치는데 줄임표 없음 %d개 [%s](기대 0) · 줄임표로 잘림 %d개 · 크기 %s"):format(
		partyScan.count, tostring(partyScan.min), partyScan.minEffective, #partyScan.below12, #partyScan.offTier, table.concat(partyScan.offTier, ","), #partyScan.overflowNoEllipsis, table.concat(partyScan.overflowNoEllipsis, ","),
		#partyScan.ellipsized, sizesLine(partyScan.sizes)), #partyScan.below12 == 0 and #partyScan.offTier == 0 and #partyScan.overflowNoEllipsis == 0)
	UIManager.close("party")
	task.wait(0.4)
	check(("파티창 닫기: 열림 %s(기대 false)"):format(tostring(UIManager.isOpen("party"))), not UIManager.isOpen("party"))

	-- 장비창: 파티 탭이 빠졌다 + 글씨 4단
	local inventoryGui = playerGui:FindFirstChild("InventoryGui")
	UIManager.open("inventory")
	task.wait(0.8)
	local tabRow = inventoryGui and inventoryGui.Window and inventoryGui.Window.Content.TabRow
	local tabNames = {}
	if tabRow then
		for _, child in ipairs(tabRow:GetChildren()) do
			if child:IsA("TextButton") then
				table.insert(tabNames, child.Text)
			end
		end
	end
	table.sort(tabNames)
	local contentScale = inventoryGui and inventoryGui.Window.Content:FindFirstChildOfClass("UIScale")
	local inventoryScan = scanText(inventoryGui.Window.Content, nil)
	check(("장비창 탭 [%s](기대 보석 · 장비 - 파티 탭 없음)"):format(table.concat(tabNames, " · ")), #tabNames == 2 and tabNames[1] == "보석" and tabNames[2] == "장비")
	check(("장비창 글씨(장비 탭): 요소 %d개 · 최소 %s(실효 %.1f) · 실효 12 미만 %d개 [%s](기대 0 - 알려진 X: S19 · S20에서 폰용 스크롤 창으로 재구성하면 해소) · 4단 밖 %d개 [%s](기대 0) · 넘치는데 줄임표 없음 %d개 [%s](기대 0) · 줄임표로 잘림 %d개 [%s] · 크기 %s"):format(
		inventoryScan.count, tostring(inventoryScan.min), inventoryScan.minEffective, #inventoryScan.below12, table.concat(inventoryScan.below12, ",", 1, math.min(#inventoryScan.below12, 6)), #inventoryScan.offTier, table.concat(inventoryScan.offTier, ","), #inventoryScan.overflowNoEllipsis,
		table.concat(inventoryScan.overflowNoEllipsis, ","), #inventoryScan.ellipsized, table.concat(inventoryScan.ellipsized, ","), sizesLine(inventoryScan.sizes)),
		#inventoryScan.below12 == 0 and #inventoryScan.offTier == 0 and #inventoryScan.overflowNoEllipsis == 0)
	print(("[S12b][UI][측정] 장비창 안쪽 UIScale %.3f → 화면에서 보이는 최소 글씨 %.1f px(명목 %s · 조상 UIScale 전부 곱한 실효값)"):format(contentScale and contentScale.Scale or 1, inventoryScan.minEffective, tostring(inventoryScan.min)))
	UIManager.close("inventory")
	task.wait(0.4)

	-- 장비 보기 창(실제 서버 조회: 자기 자신)
	Inspect.open(player.UserId)
	local waited = 0
	local rowsText = Inspect.debugRows()
	while (rowsText[1] == "" or rowsText[1] == nil) and waited < 3 do
		task.wait(0.25)
		waited += 0.25
		rowsText = Inspect.debugRows()
	end
	local _, inspectGui = UIManager.getParts("inspect")
	local usernameLabel = inspectGui and inspectGui:FindFirstChild("Username", true)
	local tipVisible, tipTitle = Inspect.debugSelect("weapon")
	check(("장비 보기(자기 조회 %.2f초): 열림 %s · @이름 [%s](기대 @%s) · 무기 줄 [%s](기대 ○○ 기본 무기) · 갑옷 [%s] · 보석1 [%s] · 무기 줄 탭 → 툴팁 %s [%s]"):format(
		waited, tostring(UIManager.isOpen("inspect")), usernameLabel and usernameLabel.Text or "-", player.Name, rowsText[1] or "-", rowsText[2] or "-", rowsText[5] or "-", tostring(tipVisible), tostring(tipTitle)),
		UIManager.isOpen("inspect") and usernameLabel ~= nil and usernameLabel.Text == "@" .. player.Name and (rowsText[1] or ""):find("기본 무기", 1, true) ~= nil and tipVisible == true)
	local inspectScan = scanText(inspectGui, inspectGui:FindFirstChild("InspectTooltip"))
	local tipAfterSecondTap = Inspect.debugSelect("weapon") -- 같은 줄을 다시 탭하면 닫힌다
	check(("장비 보기 툴팁 토글: 같은 줄 다시 탭 → 툴팁 보임 %s(기대 false) · 실효 글씨 12 미만 %d개(기대 0) · 4단 밖 %d개 [%s](기대 0) · 넘치는데 줄임표 없음 %d개(기대 0) · 크기 %s"):format(
		tostring(tipAfterSecondTap), #inspectScan.below12, #inspectScan.offTier, table.concat(inspectScan.offTier, ","), #inspectScan.overflowNoEllipsis, sizesLine(inspectScan.sizes)),
		tipAfterSecondTap == false and #inspectScan.below12 == 0 and #inspectScan.offTier == 0 and #inspectScan.overflowNoEllipsis == 0)
	UIManager.close("inspect")
	task.wait(0.4)

	-- 이름 클릭 메뉴 글씨(열어 놓고 잰다 - 자기 이름이라 [장비 보기] 한 줄)
	PlayerMenu.open({ userId = player.UserId, displayName = player.DisplayName, level = player:GetAttribute("CharacterLevel"), rebirth = player:GetAttribute("RebirthCount") })
	task.wait(0.5)
	local _, menuGui = UIManager.getParts("playerMenu")
	if menuGui then
		local menuScan = scanText(menuGui)
		check(("이름 클릭 메뉴 글씨: 요소 %d개 · 실효 12 미만 %d개(기대 0) · 4단 밖 %d개 [%s](기대 0) · 크기 %s"):format(menuScan.count, #menuScan.below12, #menuScan.offTier, table.concat(menuScan.offTier, ","), sizesLine(menuScan.sizes)),
			menuScan.count >= 2 and #menuScan.below12 == 0 and #menuScan.offTier == 0)
		UIManager.close("playerMenu", true)
	end

	-- 새 HUD 버튼(MR.partyToggle) 겹침: 화면에 보이는 다른 슬롯 · 투표 패널 자리(계획) · 중앙 금지 구역
	if partyButton then
		local buttonRect = rectOf(partyButton)
		local hits, tested = {}, 0
		for zone, name, slot in ScreenMap.each() do
			local inst = slot.instanceName and slot.instanceName ~= "PartyToggleButton" and playerGui:FindFirstChild(slot.instanceName, true)
			if inst and inst:IsA("GuiObject") and inst.Visible and inst.AbsoluteSize.X > 0 and inst.AbsoluteSize.Y > 0 then
				tested += 1
				if intersects(buttonRect, rectOf(inst)) then
					table.insert(hits, zone .. "." .. name)
				end
			end
		end
		-- 투표 패널은 평소 숨어 있다 - 슬롯 표(고정 크기)의 자리를 그대로 계산해 본다.
		local vote = ScreenMap.slot("MR", "partyVote")
		local viewport = partyButton:FindFirstAncestorOfClass("ScreenGui").AbsoluteSize
		local voteHeight, voteWidth = vote.size.Y.Offset, vote.size.X.Offset
		local voteRect = {
			min = Vector2.new(viewport.X + vote.position.X.Offset - voteWidth, viewport.Y * vote.position.Y.Scale + vote.position.Y.Offset - voteHeight * vote.anchor.Y),
		}
		voteRect.max = voteRect.min + Vector2.new(voteWidth, voteHeight)
		local hitsVote = intersects(buttonRect, voteRect)
		local centerRect = ScreenMap.centerRect(viewport)
		local inCenter = intersects(buttonRect, { min = centerRect.min, max = centerRect.max })
		local mobileHit = false
		if Theme.isMobile then
			for _, fractions in pairs(ScreenMap.mobileReserved) do
				local reserved = ScreenMap.rectFromFractions(fractions, viewport)
				mobileHit = mobileHit or intersects(buttonRect, { min = reserved.min, max = reserved.max })
			end
		end
		print(("[S12b][UI][측정] 파티 버튼 (%d, %d) %d × %d · 비교한 보이는 슬롯 %d개"):format(buttonRect.min.X, buttonRect.min.Y, partyButton.AbsoluteSize.X, partyButton.AbsoluteSize.Y, tested))
		check(("파티 버튼 겹침: 보이는 슬롯과 %d개 [%s](기대 0) · 투표 패널 자리 %s(기대 false) · 중앙 금지 구역 %s(기대 false) · 모바일 예약 구역 %s(기대 false)"):format(
			#hits, table.concat(hits, ","), tostring(hitsVote), tostring(inCenter), tostring(mobileHit)), #hits == 0 and not hitsVote and not inCenter and not mobileHit)
	end

	print(("===S12b 검증 끝(UI: 창 · 글씨)=== %d/%d 통과"):format(pass, total))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(selfTest)
	if not ok then
		warn("[S12b][UI] 자체 점검 에러: " .. tostring(err))
	end
end)
