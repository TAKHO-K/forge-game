-- 화면 영역 고정 지도(30-0 S06, PRD 20.81 [D-2]). 구역 10개(TL TC TR ML MR C BL BC BR XP)와 구역별 슬롯의 좌표를 한 파일에 상수로 둔다.
-- 새 UI는 Position을 직접 적지 않고 ScreenMap.place(frame, zone, slotName)로 자리를 받는다 - 겹침 검사(UiSelfCheck)가 이 표 한 곳을 기준으로 한다.
--
-- 슬롯 status:
--   "existing" - 지금 HUD 스크립트가 **직접** Position을 적어 쓰는 좌표를 그대로 옮겨 적은 것이다(2026-09-20 코드 기준, 출처 파일은 note). 이 세션에서는 표만 만들고
--                기존 HUD는 이 함수를 아직 쓰지 않는다 - HUD를 옮기는 순서는 PRD 20.81 [D-6](S16 ~ 마지막).
--   "new"      - 새 기능이 받을 자리(PRD [D-2] 값). 아직 그 자리에 그려지는 것이 없다.
-- 값이 PRD 지도와 다른 곳은 코드가 맞다(20.81 [D-2] 지도의 경험치바 26px → 코드 15px 등).
-- instanceName: 겹침 검사가 PlayerGui에서 이 이름의 인스턴스를 찾아 화면에 보이는 동안의 AbsolutePosition · AbsoluteSize를 잰다.
-- below = { zone, slot, gap }: 고정 y를 쓰지 않고 그 슬롯(인스턴스)의 아래 끝 + gap에 놓인다 - FeedLayout(ui/FeedLayout.lua)이 그 인스턴스 크기를 따라 재고, 남은 자리만큼만 줄을 세운다. position은 그 슬롯이 비어 있을 때의 자리다.
-- fallback = { zone, slot, gap }: below 자리에 한 줄도 안 들어갈 때 옮겨 가는 자리(그 슬롯의 좌표, 상단 가운데 띠). 태초 배너가 떠 있으면 배너 아래 끝 + gap.
-- blocksDropFeed = true: 이 HUD가 보이는 동안 드랍 피드가 그 위 끝 아래로 못 내려온다(FeedLayout이 읽는다). 새 HUD를 피드 아래에 놓으면 여기에 표시한다.
--   size = nil은 AutomaticSize(내용 크기)다. 슬롯 하나가 자식 여럿을 품는 스택이면(chipStack) 자식은 따로 적지 않는다(겹침 검사에서 부모와 겹친 것으로 잘못 잡히지 않게).
-- **새 UI를 놓기 전에 이 표에 없는 기존 HUD가 있는지 먼저 확인한다**(COMMON.md §2). 화면에 뜨는 HUD 전수 = PlayerGui의 ScreenGui(DisplayOrder 0 ~ 8) 직계 GuiObject - UiSelfCheck가 표에 없는 것을 [S06][UI][미등록]으로 찍는다.
-- 표에 안 넣는 것(사유): 창(window · station · overlay - UIManager · PanelRegistry가 자리를 정한다 · 직업 선택창 ClassSelectPanel · ClassConfirmPanel은 ScreenMap.windowNames) · 월드에 붙는 BillboardGui(데미지 숫자 · 골드 · 재료 팝업 · 보스 머리 위 표시) · 로블록스 CoreGui(채팅 · 플레이어 목록 · TouchGui).

local ScreenMap = {}

ScreenMap.edgeMargin = 14 -- 가장자리 여백(px)

local function slot(status, anchorX, anchorY, position, size, instanceName, note, below)
	return {
		status = status,
		anchor = Vector2.new(anchorX, anchorY),
		position = position,
		size = size,
		instanceName = instanceName,
		note = note,
		below = below,
	}
end

local function blocksFeed(entry)
	entry.blocksDropFeed = true
	return entry
end

-- 창으로 취급해 HUD 표에서 뺀 인스턴스 이름(UiSelfCheck의 미등록 탐지가 건너뛴다). 이 밖의 창은 DisplayOrder 10 이상 ScreenGui라 자동으로 빠진다.
ScreenMap.windowNames = { ClassSelectPanel = true, ClassConfirmPanel = true }

-- 구역: 앵커(가장자리 기준점). C는 슬롯이 없다("영구히 없음" - window · overlay 제외).
ScreenMap.zones = {
	TL = { anchor = Vector2.new(0, 0), note = "로블록스 채팅창 - 손대지 않는다" },
	TC = { anchor = Vector2.new(0.5, 0), note = "시스템 토스트 줄(저장 · 레벨업 · 구역 차단 · 보물상자 - S17부터 hud/SystemToasts) · 태초 서버 전체 알림 배너(4초) · 드랍 피드가 자리 없을 때 옮겨 오는 띠" },
	TR = { anchor = Vector2.new(1, 0), note = "칩 스택(골드 · 레벨 · 스테이지 · 설정 · 견습) · 그 왼쪽 파티 버튼(S12b) · 칩 스택 아래 드랍 피드" },
	ML = { anchor = Vector2.new(0, 0.5), note = "파티 목록 · 메뉴바" },
	MR = { anchor = Vector2.new(1, 0.5), note = "가방 버튼 · 요청 배너(파티 투표 · 초대)" },
	C = { anchor = Vector2.new(0.5, 0.5), note = "전투 시야 - 비운다(화면 중앙 40% × 50%에 2D UI 없음)" },
	BL = { anchor = Vector2.new(0, 1), note = "직업 변경 버튼 · 모바일 조이스틱 - 예약(좌 40% × 하 45%)" },
	BC = { anchor = Vector2.new(0.5, 1), note = "버프 줄 → 스킬 슬롯 → 체력바 · 획득 팝업" },
	BR = { anchor = Vector2.new(1, 1), note = "모바일 공격 · 스킬 · 대시 - 예약(우 30% × 하 50%), 슬롯 없음" },
	XP = { anchor = Vector2.new(0.5, 1), note = "경험치바(전체 폭)" },
}

ScreenMap.slots = {
	TC = {
		zoneBoundary = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 100), UDim2.new(0, 420, 0, 48), "ZoneWarningLabel", "ZoneBoundaryWarning.client.lua"),
		tutorialToast = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 160), UDim2.new(0, 480, 0, 0), "TutorialToast", "TutorialHud.client.lua - 높이는 내용(AutomaticSize.Y)"),
		partyToast = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 210), UDim2.new(0, 420, 0, 40), "PartyToast", "PartyHud.client.lua(TOAST_Y = 210)"),
		toastLane = slot("new", 0.5, 0, UDim2.new(0.5, 0, 0, 64), UDim2.new(0, 480, 0, 40), "ToastLane_TC", "Toast 줄 TC(시스템 · 1행 · 3초)"),
	},
	TR = {
		chipStack = slot("existing", 1, 0, UDim2.new(1, -14, 0, 52), nil, "TopChipsRow", "StageUI.client.lua - 골드(LayoutOrder 1) · 레벨(2) · 스테이지(3) · 설정(4) · 견습(5) 세로 스택, 간격 8. PRD 지도의 '골드 · 스테이지 칩'이 코드에서는 이 스택이다"),
		partyToggle = slot("existing", 1, 0, UDim2.new(1, -99, 0, 52), UDim2.new(0, 72, 0, 36), "PartyToggleButton",
			"panels/Party.lua(S12b) - '파티' 열기 버튼(P 키와 같은 창). 칩 스택 **왼쪽**, 위 끝을 칩 스택과 맞춘다(y 52). 오른쪽 끝 = 칩 스택 왼쪽 끝 - 8 - 칩 스택 폭이 늘면(골드 자릿수) 따라 움직인다(Party.lua followChipStack). 여기 기본값(-99)은 스택 폭 77일 때다. 세로 중앙 열(가방 버튼 · 투표 패널)은 이미 겹침이 있어 새 버튼을 놓지 않았다. 모바일은 높이 44"),
		dropFeed = slot("new", 1, 0, UDim2.new(1, -14, 0, 52), UDim2.new(0, 300, 0, 78), "ToastLane_TR",
			"Toast 줄 TR(드랍 피드 · 최대 3줄 · 새 알림이 위 · 4초 뒤 흐려짐 · 넘치면 오래된 줄 밀림) - 사용자 결정 2026-09-20(PRD 20.93 · 보완): 칩 스택 바로 아래(아래 끝 + 8)에 남은 자리만큼(가방 버튼 · 투표 패널 · 터치 구역 · 중앙 구역 위 끝까지, 최대 3줄), 0줄이면 상단 가운데 띠 1줄(태초 배너가 있으면 그 아래 3)",
			{ zone = "TR", slot = "chipStack", gap = 8 }),
	},
	ML = {
		-- S16: 파티 목록은 메뉴바 오른쪽 옆(x = 14 + 48 + 8 - 모바일 버튼 폭 48 기준이라 PC(44)에서는 4px 더 뜬다)으로 옮겼다. 모바일 축약형(이름 없이 체력 줄 4개 · 폭 96)은 S18.
		partyList = slot("existing", 0, 0.5, UDim2.new(0, ScreenMap.edgeMargin + 48 + 8, 0.5, 0), nil, "PartyList", "PartyHud.client.lua - 행 196 × 44 · 메뉴바 오른쪽 옆(S16)"),
		menuBar = slot("existing", 0, 0.5, UDim2.new(0, ScreenMap.edgeMargin, 0.5, 0), nil, "MenuBar",
			"hud/MenuBar.client.lua(S16) - 세로 1열 · 버튼 44(모바일 48) · 간격 6 · 칸 = PanelRegistry의 menuOrder(상한 5) · 크기는 보이는 칸 수로 정해진다(고정 크기 - 칸이 숨거나 나타날 때 다시 잰다). 모바일은 아래 끝이 BL 터치 예약 구역(위 끝 = 화면 높이 × 0.55)에 닿으면 mobileMenuBarShiftUp만큼 위로 민다"),
	},
	BL = {
		classReopen = slot("existing", 0, 1, UDim2.new(0, 24, 1, -34), UDim2.new(0, 90, 0, 36), "ClassReopenButton", "ClassSelectUI.client.lua - '직업 변경' 상시 버튼(y 오프셋 34는 경험치바와 8px 띄운 값). 모바일에서는 조이스틱 예약 구역 안이다(기존)"),
	},
	MR = {
		inventoryToggle = blocksFeed(slot("existing", 1, 0.5, UDim2.new(1, -16, 0.5, 0), UDim2.new(0, 90, 0, 36), "InventoryToggleButton", "InventoryUI.client.lua - '가방' 열기 버튼(항상 보임). 투표 패널과 같은 세로 중앙이라 투표 중에는 서로 겹친다(기존 - 20.94 미결)")),
		partyVote = blocksFeed(slot("existing", 1, 0.5, UDim2.new(1, -14, 0.5, 0), UDim2.new(0, 210, 0, 84), "PartyVotePanel", "PartyHud.client.lua")),
	},
	BC = {
		buffRow = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -141), nil, "BuffHudAnchor", "PlayerHealthBar.client.lua - 버프 아이콘 28px 행(BOTTOM_OFFSET 94 + 체력바 19 + 8 + 10 + 10)"),
		comboPips = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -121), UDim2.new(0, 0, 0, 0), "ComboPipsAnchor", "PlayerHealthBar.client.lua - 콤보 점 자리(크기 0 - AttackInput이 자식을 끼운다)"),
		healthBar = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -94), UDim2.new(0, 394, 0, 19), "HealthBar", "PlayerHealthBar.client.lua"),
		skillRow = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -31), nil, "CentralRow", "SkillSlots.client.lua - 슬롯 54 · 높이 54(모바일 터치 배치는 SkillSlots가 따로 정한다)"),
		pickupPopup = slot("new", 0.5, 1, UDim2.new(0.5, 0, 1, -140), UDim2.new(0, 360, 0, 40), "ToastLane_BC", "Toast 줄 BC(획득 팝업 · 1행 · 묶기)"),
		bossTrap = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -170), UDim2.new(0, 260, 0, 58), "BossTrapPanel", "BossTrapView.lua - 보스 잡기 기믹에 잡혔을 때만 뜨는 카운트다운 · 구출 막대 패널(평소엔 숨김)"),
	},
	XP = {
		expBar = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, 0), UDim2.new(1, 0, 0, 15), "ExpTrack", "ExpBar.client.lua - 높이 15(PRD 지도의 26px이 아니라 코드 값)"),
	},
}

-- 드랍 피드가 남은 자리에 한 줄도 안 들어갈 때 옮겨 가는 자리 = 상단 가운데 토스트 줄(태초 배너가 있으면 그 아래 3px).
ScreenMap.slots.TR.dropFeed.fallback = { zone = "TC", slot = "toastLane", gap = 3 }

-- 모바일 터치 컨트롤 예약 구역(화면 비율) - 슬롯 없음. { left, top, right, bottom } 비율.
ScreenMap.mobileReserved = {
	BL = { left = 0, top = 0.55, right = 0.4, bottom = 1 },
	BR = { left = 0.7, top = 0.5, right = 1, bottom = 1 },
}

-- 메뉴바 규격(PRD 20.81 [D-2]): 버튼 44 × 44(모바일 48) · 간격 6 · 위로 밀 때 화면 위 끝에서 남기는 여백.
ScreenMap.menuBar = { button = 44, mobileButton = 48, gap = 6, topMargin = 8 }

-- 모바일에서 세로 중앙에 놓인 메뉴바(높이 barHeight)의 아래 끝이 BL 터치 예약 구역 위 끝(화면 높이 × mobileReserved.BL.top)에 닿으면, 닿지 않을 만큼(= 겹침이 0이 되는 최소 이동)만 위로 민다.
-- 위 끝이 topMargin 아래로는 못 올라간다 - 그래도 못 피하면(칸이 많고 화면이 낮을 때) 밀 수 있는 만큼만 민다(그 경우는 자체 점검이 X로 찍는다). 반환 = 올릴 px(0 이상).
function ScreenMap.mobileMenuBarShiftUp(screenHeight, barHeight)
	local limit = screenHeight * ScreenMap.mobileReserved.BL.top
	local bottom = screenHeight / 2 + barHeight / 2
	local shift = math.max(0, bottom - limit)
	local room = math.max(0, screenHeight / 2 - barHeight / 2 - ScreenMap.menuBar.topMargin)
	return math.min(shift, room)
end

-- C 구역(전투 시야): 화면 중앙 40% × 50%.
ScreenMap.centerFraction = { left = 0.3, top = 0.25, right = 0.7, bottom = 0.75 }

function ScreenMap.slot(zone, slotName)
	local zoneSlots = ScreenMap.slots[zone]
	local found = zoneSlots and zoneSlots[slotName]
	assert(found, ("ScreenMap: 없는 슬롯 - %s.%s"):format(tostring(zone), tostring(slotName)))
	return found
end

-- 슬롯의 AnchorPoint · Position을 frame에 넣는다. 크기는 넣지 않는다(호출부가 정한다 - 슬롯 표의 size는 참고값).
function ScreenMap.place(frame, zone, slotName)
	local found = ScreenMap.slot(zone, slotName)
	frame.AnchorPoint = found.anchor
	frame.Position = found.position
	return found
end

-- 슬롯을 (zone, name, slot)로 돌려주는 반복자.
function ScreenMap.each()
	local entries = {}
	for zone, zoneSlots in pairs(ScreenMap.slots) do
		for name, found in pairs(zoneSlots) do
			table.insert(entries, { zone = zone, name = name, slot = found })
		end
	end
	table.sort(entries, function(a, b)
		if a.zone ~= b.zone then
			return a.zone < b.zone
		end
		return a.name < b.name
	end)
	local index = 0
	return function()
		index += 1
		local entry = entries[index]
		if entry then
			return entry.zone, entry.name, entry.slot
		end
		return nil
	end
end

-- 뷰포트 크기(Vector2) 안의 비율 구역을 { min = Vector2, max = Vector2 }로 바꾼다.
function ScreenMap.rectFromFractions(fractions, viewport)
	return {
		min = Vector2.new(fractions.left * viewport.X, fractions.top * viewport.Y),
		max = Vector2.new(fractions.right * viewport.X, fractions.bottom * viewport.Y),
	}
end

function ScreenMap.centerRect(viewport)
	return ScreenMap.rectFromFractions(ScreenMap.centerFraction, viewport)
end

return ScreenMap
