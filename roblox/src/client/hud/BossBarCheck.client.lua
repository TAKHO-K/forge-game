-- S19b(UI) 자체 점검 [S19b][UI] - 보스 체력바(hud/BossBar.client.lua). Studio에서 DevToolsConfig.verify에 "S19b(UI)"가 있을 때만(또는 회귀 전체) 돈다.
-- 서버 없이 클라만으로 실제 경로를 돈다: 로컬에서 Monster 태그 모델 2개(내 보스 · 남의 보스)를 만들고 내 Player Attribute BossEncounterId를 걸면 BossBar가 0.1초 안에 그 모델을 찾아 그린다.
-- 서버가 하는 일(모델 Attribute 전달 · 번호 부여 · 머리 위 바 없음)은 서버 검증 (가)(나)가 잰다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
if not (DevToolsConfig.verify.regression or table.find(DevToolsConfig.verify.current, "S19b(UI)")) then
	return
end

local ScreenMap = require(script.Parent.Parent.ui.ScreenMap)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local PartyAway = require(script.Parent.PartyAway)
local PartyListView = require(script.Parent.PartyListView)
local UIColors = require(ReplicatedStorage.Shared.data.UIColors)

local player = Players.LocalPlayer
local START_DELAY = 62 -- 다른 클라 점검(S10 · S12b · S17 · S18)이 토스트를 쓰는 동안이 끝난 뒤

local function rectOf(inst)
	return { min = inst.AbsolutePosition, max = inst.AbsolutePosition + inst.AbsoluteSize }
end

local function intersects(a, b)
	return a.min.X < b.max.X and b.min.X < a.max.X and a.min.Y < b.max.Y and b.min.Y < a.max.Y
end

local function describe(rect)
	return ("(%d, %d) %d × %d"):format(rect.min.X, rect.min.Y, rect.max.X - rect.min.X, rect.max.Y - rect.min.Y)
end

local function isShown(inst)
	local node = inst
	while node and node ~= game do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		if node:IsA("ScreenGui") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- 슬롯 표만으로 계산한 자리(size가 있고 below가 아닌 슬롯).
local function plannedRect(slot, screen)
	if not slot.size or slot.below then
		return nil
	end
	local width = slot.size.X.Scale * screen.X + slot.size.X.Offset
	local height = slot.size.Y.Scale * screen.Y + slot.size.Y.Offset
	local x = slot.position.X.Scale * screen.X + slot.position.X.Offset - slot.anchor.X * width
	local y = slot.position.Y.Scale * screen.Y + slot.position.Y.Offset - slot.anchor.Y * height
	return { min = Vector2.new(x, y), max = Vector2.new(x + width, y + height) }
end

local function near2(actual, expected, tolerance)
	return math.abs(actual - expected) <= tolerance
end

local function makeBossModel(id, name, ratio)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("BossEncounterId", id)
	model:SetAttribute("BossName", name)
	model:SetAttribute("BossHpRatio", ratio)
	CollectionService:AddTag(model, "Monster")
	model.Parent = workspace
	return model
end

local function run()
	local playerGui = player:WaitForChild("PlayerGui")
	local results, passed = {}, 0
	local function check(label, ok)
		table.insert(results, ("%s %s"):format(label, ok and "O" or "X"))
		print(("[S19b][UI] %s %s"):format(label, ok and "O" or "X"))
		if ok then
			passed += 1
		end
	end

	print("===S19b(UI) 검증 시작===")
	local gui = playerGui:FindFirstChild("BossBarGui")
	local root = gui and gui:FindFirstChild("BossBar")
	check("HUD가 있다(BossBarGui.BossBar)", root ~= nil)
	if not root then
		print("===S19b(UI) 검증 끝=== " .. passed .. "/1 통과")
		return
	end
	check("보스전이 없을 때는 안 보인다", root.Visible == false)

	local mine = makeBossModel(9001, "점검 보스", 0.62)
	local other = makeBossModel(9002, "남의 보스", 0.1)
	player:SetAttribute("BossEncounterId", 9001)
	task.wait(0.5)

	local nameLabel = root:FindFirstChild("BossName")
	local gaugeRoot = root:FindFirstChild("BossHpGauge")
	local fill = gaugeRoot and gaugeRoot:FindFirstChild("Fill")
	local number = gaugeRoot and gaugeRoot:FindFirstChild("Number")
	check(("내 보스가 뜬다: 보임 %s · 이름 '%s'(기대 '점검 보스' - 번호 다른 '남의 보스' 무시)"):format(tostring(root.Visible), nameLabel and nameLabel.Text or "?"),
		root.Visible and nameLabel ~= nil and nameLabel.Text == "점검 보스")
	check(("체력바 62%%: 채움 %.3f · 숫자 '%s'(기대 0.62 · '62%%')"):format(fill and fill.Size.X.Scale or -1, number and number.Text or "?"),
		fill ~= nil and math.abs(fill.Size.X.Scale - 0.62) < 0.01 and number ~= nil and number.Text == "62%")

	mine:SetAttribute("BossHpRatio", 0.5)
	task.wait(0.5)
	check(("값이 바뀌면 따라간다: 채움 %.3f · 숫자 '%s'(기대 0.5 · '50%%')"):format(fill.Size.X.Scale, number.Text), math.abs(fill.Size.X.Scale - 0.5) < 0.01 and number.Text == "50%")
	mine:SetAttribute("BossHpRatio", 0.004)
	task.wait(0.5)
	check(("거의 0이어도 0%%로 안 보인다: 숫자 '%s'(기대 '1%%' - 올림)"):format(number.Text), number.Text == "1%")

	-- 자리 · 겹침: 지금 그려진 슬롯은 실제 자리, 안 그려진 슬롯은 표의 자리로 잰다.
	local screen = gui.AbsoluteSize
	local barRect = rectOf(root)
	local slot = ScreenMap.slot("TC", "bossBar")
	local hits = {}
	for zone, slotName, other_slot in ScreenMap.each() do
		if not (zone == "TC" and slotName == "bossBar") then
			local drawn = other_slot.instanceName and playerGui:FindFirstChild(other_slot.instanceName, true)
			local rect
			if drawn and drawn:IsA("GuiObject") and isShown(drawn) and drawn.AbsoluteSize.X > 0 and drawn.AbsoluteSize.Y > 0 then
				rect = rectOf(drawn)
			else
				rect = plannedRect(other_slot, screen)
			end
			if rect and intersects(barRect, rect) then
				table.insert(hits, ("%s.%s %s"):format(zone, slotName, describe(rect)))
			end
		end
	end
	check(("다른 HUD 슬롯과 겹침 %d개(기대 0 - 태초 배너 · 토스트 줄 · 칩 스택 · 파티 버튼 · 존 경고 · 견습 토스트 포함): 보스 바 %s %s"):format(#hits, describe(barRect), table.concat(hits, " · ")), #hits == 0)

	local center = ScreenMap.centerRect(screen)
	check(("중앙 금지 구역 밖: 보스 바 %s · C 구역 %s"):format(describe(barRect), describe(center)), not intersects(barRect, center))
	check(("화면 안: 화면 %d × %d"):format(screen.X, screen.Y), barRect.min.X >= 0 and barRect.min.Y >= 0 and barRect.max.X <= screen.X and barRect.max.Y <= screen.Y)
	local expectedWidth = slot.size.X.Offset
	if Theme.isMobile then -- 폰: 축약형 파티 목록 오른쪽 끝 + 8 안쪽으로만(BossBar.applyWidth)
		expectedWidth = math.clamp(screen.X - 2 * (ScreenMap.edgeMargin + ScreenMap.menuBar.mobileButton + 8 + PartyListView.compact.width + 8), 160, slot.size.X.Offset)
	end
	check(("슬롯 표 크기와 같다(폰은 폭만 좁힘): 실제 %d × %d · 기대 %d × %d"):format(root.AbsoluteSize.X, root.AbsoluteSize.Y, expectedWidth, slot.size.Y.Offset),
		root.AbsoluteSize.X == expectedWidth and root.AbsoluteSize.Y == slot.size.Y.Offset)

	local nameSize = nameLabel and Theme.effectiveTextSize(nameLabel) or 0
	local numberSize = number and Theme.effectiveTextSize(number) or 0
	check(("글씨 실효 크기 12 이상: 이름 %.1f · 퍼센트 %.1f"):format(nameSize, numberSize), nameSize >= Theme.minTextSize and numberSize >= Theme.minTextSize)

	-- 정리: 보스전이 끝나면(Attribute 삭제) 사라진다.
	player:SetAttribute("BossEncounterId", nil)
	task.wait(0.4)
	check("보스전이 끝나면 사라진다", root.Visible == false)
	mine:Destroy()
	other:Destroy()

	-- B: 파티 목록의 "연결 끊김 m:ss"(뷰 · 시간 계산). 서버 스냅샷 없이 뷰에 합성 멤버를 넣어 읽는다.
	local memberSoon = { awayRemaining = 161, awayEndsAt = os.clock() + 161 }
	local memberDone = { awayRemaining = 0, awayEndsAt = os.clock() - 5 }
	check(("연결 끊김 글: PC '%s'(기대 '연결 끊김 2:41') · 모바일 '%s'(기대 '끊김 2:41') · 끝난 시각 '%s'(기대 '연결 끊김 0:00') · 유예 아님 %s(기대 nil)"):format(
		tostring(PartyAway.text(memberSoon, false)), tostring(PartyAway.text(memberSoon, true)), tostring(PartyAway.text(memberDone, false)), tostring(PartyAway.text({}, false))),
		PartyAway.text(memberSoon, false) == "연결 끊김 2:41" and PartyAway.text(memberSoon, true) == "끊김 2:41" and PartyAway.text(memberDone, false) == "연결 끊김 0:00" and PartyAway.text({}, false) == nil)
	local stamped = PartyAway.stamp({ members = { { awayRemaining = 90 }, {} } })
	local firstEnds, secondEnds = stamped.members[1].awayEndsAt, stamped.members[2].awayEndsAt
	PartyAway.stamp(stamped) -- 같은 표를 다시 받아도(여러 리스너) 끝나는 시각이 안 늘어난다
	check(("스냅샷 도장: 남은 90초 → 끝나는 시각 %.1f초 뒤 · 두 번 찍어도 같다 %s · 유예 아닌 멤버 %s(기대 nil)"):format(firstEnds - os.clock(), tostring(stamped.members[1].awayEndsAt == firstEnds), tostring(secondEnds)),
		near2(firstEnds - os.clock(), 90, 1) and stamped.members[1].awayEndsAt == firstEnds and secondEnds == nil)

	local testGui = Instance.new("ScreenGui")
	testGui.Name = "S19bAwayTestGui"
	testGui.Parent = playerGui
	local awayMember = { nameText = "끊긴이", level = 35, rebirth = 0, classId = "healer", className = "치유사", stage = 12, ratio = 0, shieldRatio = 0, buffActive = false, isLeader = false, awayText = "연결 끊김 2:41" }
	local liveMember = { nameText = "접속중", level = 35, rebirth = 0, classId = "bow", className = "궁수", stage = 12, ratio = 1, shieldRatio = 0, buffActive = false, isLeader = true }
	local pcView = PartyListView.build({ parent = testGui, compact = false })
	pcView.setMembers({ liveMember, awayMember })
	local pcSubtitle = pcView.rows[2].row.root:FindFirstChild("Subtitle")
	local pcLive = pcView.rows[1].row.root:FindFirstChild("Subtitle")
	check(("PC 목록: 끊긴 멤버 부제 '%s'(기대 '연결 끊김 2:41 · 치유사 · 스테이지 12') · 이름 회색 %s · 접속 중 멤버 부제 '%s'(변화 없음) · 체력 0"):format(
		pcSubtitle and pcSubtitle.Text or "?", tostring(pcView.rows[2].title.TextColor3 == UIColors.textSecondary), pcLive and pcLive.Text or "?"),
		pcSubtitle ~= nil and pcSubtitle.Text == "연결 끊김 2:41 · 치유사 · 스테이지 12" and pcView.rows[2].title.TextColor3 == UIColors.textSecondary
			and pcLive ~= nil and pcLive.Text == "궁수 · 스테이지 12" and pcView.rows[2].gauge.getValue() == 0)
	local compactView = PartyListView.build({ parent = testGui, compact = true })
	awayMember.awayText = "끊김 2:41"
	compactView.setMembers({ liveMember, awayMember })
	local classLabel = compactView.rows[2].block:FindFirstChild("ClassName")
	local liveClassLabel = compactView.rows[1].block:FindFirstChild("ClassName")
	check(("모바일 축약형: 끊긴 멤버 줄 위 글 '%s'(기대 '끊김 2:41') · 회색 %s · 접속 중 멤버 '%s'(기대 '궁수') · 글이 폭 안에 들어감(실효 %.1f px 글씨)"):format(
		classLabel and classLabel.Text or "?", tostring(classLabel ~= nil and classLabel.TextColor3 == UIColors.textSecondary), liveClassLabel and liveClassLabel.Text or "?", classLabel and Theme.effectiveTextSize(classLabel) or 0),
		classLabel ~= nil and classLabel.Text == "끊김 2:41" and classLabel.TextColor3 == UIColors.textSecondary and liveClassLabel ~= nil and liveClassLabel.Text == "궁수"
			and classLabel.TextBounds.X <= classLabel.AbsoluteSize.X)
	testGui:Destroy()
	print(("===S19b(UI) 검증 끝=== %d/%d 통과"):format(passed, #results))
end

task.delay(START_DELAY, function()
	local ok, err = pcall(run)
	if not ok then
		warn("[S19b][UI] 점검 에러: " .. tostring(err))
		player:SetAttribute("BossEncounterId", nil)
	end
end)
