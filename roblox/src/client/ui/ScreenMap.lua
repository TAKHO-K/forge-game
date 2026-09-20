-- 화면 영역 고정 지도(30-0 S06, PRD 20.81 [D-2]). 구역 10개(TL TC TR ML MR C BL BC BR XP)와 구역별 슬롯의 좌표를 한 파일에 상수로 둔다.
-- 새 UI는 Position을 직접 적지 않고 ScreenMap.place(frame, zone, slotName)로 자리를 받는다 - 겹침 검사(UiSelfCheck)가 이 표 한 곳을 기준으로 한다.
--
-- 슬롯 status:
--   "existing" - 지금 HUD 스크립트가 **직접** Position을 적어 쓰는 좌표를 그대로 옮겨 적은 것이다(2026-09-20 코드 기준, 출처 파일은 note). 이 세션에서는 표만 만들고
--                기존 HUD는 이 함수를 아직 쓰지 않는다 - HUD를 옮기는 순서는 PRD 20.81 [D-6](S16 ~ 마지막).
--   "new"      - 새 기능이 받을 자리(PRD [D-2] 값). 아직 그 자리에 그려지는 것이 없다.
-- 값이 PRD 지도와 다른 곳은 코드가 맞다(20.81 [D-2] 지도의 경험치바 26px → 코드 15px 등).
-- instanceName: 겹침 검사가 PlayerGui에서 이 이름의 인스턴스를 찾아 화면에 보이는 동안의 AbsolutePosition · AbsoluteSize를 잰다.
-- below = { zone, slot, gap }: 고정 y를 쓰지 않고 그 슬롯(인스턴스)의 아래 끝 + gap에 놓인다 - ScreenMap.followBelow가 그 인스턴스 크기를 따라 내려간다. position은 그 슬롯이 비어 있을 때의 자리다.
--   size = nil은 AutomaticSize(내용 크기)다. 슬롯 하나가 자식 여럿을 품는 스택이면(chipStack) 자식은 따로 적지 않는다(겹침 검사에서 부모와 겹친 것으로 잘못 잡히지 않게).

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

-- 구역: 앵커(가장자리 기준점). C는 슬롯이 없다("영구히 없음" - window · overlay 제외).
ScreenMap.zones = {
	TL = { anchor = Vector2.new(0, 0), note = "로블록스 채팅창 - 손대지 않는다" },
	TC = { anchor = Vector2.new(0.5, 0), note = "레벨업 연출 · 시스템 토스트 줄(y 64 ~ 210) · 태초 서버 전체 알림 배너(4초)" },
	TR = { anchor = Vector2.new(1, 0), note = "칩 스택(골드 · 레벨 · 스테이지 · 설정 · 견습) · 그 아래 드랍 피드" },
	ML = { anchor = Vector2.new(0, 0.5), note = "파티 목록 · 메뉴바" },
	MR = { anchor = Vector2.new(1, 0.5), note = "요청 배너(파티 투표 · 초대)" },
	C = { anchor = Vector2.new(0.5, 0.5), note = "전투 시야 - 비운다(화면 중앙 40% × 50%에 2D UI 없음)" },
	BL = { anchor = Vector2.new(0, 1), note = "모바일 조이스틱 - 예약(좌 40% × 하 45%), 슬롯 없음" },
	BC = { anchor = Vector2.new(0.5, 1), note = "버프 줄 → 스킬 슬롯 → 체력바 · 획득 팝업" },
	BR = { anchor = Vector2.new(1, 1), note = "모바일 공격 · 스킬 · 대시 - 예약(우 30% × 하 50%), 슬롯 없음" },
	XP = { anchor = Vector2.new(0.5, 1), note = "경험치바(전체 폭)" },
}

ScreenMap.slots = {
	TC = {
		saveNotice = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 64), UDim2.new(0, 480, 0, 40), "SaveNoticeLabel", "SaveNoticeHud.client.lua"),
		zoneBoundary = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 100), UDim2.new(0, 420, 0, 48), "ZoneWarningLabel", "ZoneBoundaryWarning.client.lua"),
		zoneBlocked = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 108), UDim2.new(0, 360, 0, 36), "ZoneBlockedLabel", "ZoneBlockedHud.client.lua"),
		treasureChest = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 150), UDim2.new(0, 440, 0, 36), "TreasureChestLabel", "TreasureChestHud.client.lua"),
		tutorialToast = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 160), UDim2.new(0, 480, 0, 0), "TutorialToast", "TutorialHud.client.lua - 높이는 내용(AutomaticSize.Y)"),
		partyToast = slot("existing", 0.5, 0, UDim2.new(0.5, 0, 0, 210), UDim2.new(0, 420, 0, 40), "PartyToast", "PartyHud.client.lua(TOAST_Y = 210)"),
		levelUp = slot("existing", 0.5, 0.5, UDim2.new(0.5, 0, 0.3, 0), UDim2.new(0, 320, 0, 56), "LevelUpLabel", "LevelUpHud.client.lua - 화면 높이 30%(C 구역 위쪽 경계 25% ~ 75% 안)의 일시 연출"),
		toastLane = slot("new", 0.5, 0, UDim2.new(0.5, 0, 0, 64), UDim2.new(0, 480, 0, 40), "ToastLane_TC", "Toast 줄 TC(시스템 · 1행 · 3초)"),
	},
	TR = {
		chipStack = slot("existing", 1, 0, UDim2.new(1, -14, 0, 52), nil, "TopChipsRow", "StageUI.client.lua - 골드(LayoutOrder 1) · 레벨(2) · 스테이지(3) · 설정(4) · 견습(5) 세로 스택, 간격 8. PRD 지도의 '골드 · 스테이지 칩'이 코드에서는 이 스택이다"),
		dropFeed = slot("new", 1, 0, UDim2.new(1, -14, 0, 52), UDim2.new(0, 300, 0, 78), "ToastLane_TR",
			"Toast 줄 TR(드랍 피드 · 3줄 · 새 알림이 위 · 4초 뒤 흐려짐 · 3줄 넘으면 오래된 줄 밀림) - 사용자 결정 2026-09-20(PRD 20.93): 칩 스택 바로 아래 같은 세로 줄. 고정 y 없이 칩 스택의 아래 끝 + 8을 따라 내려간다(칩이 0개면 52 = 칩 스택 윗줄 자리)",
			{ zone = "TR", slot = "chipStack", gap = 8 }),
	},
	ML = {
		partyList = slot("existing", 0, 0.5, UDim2.new(0, 14, 0.5, 0), nil, "PartyList", "PartyHud.client.lua - 행 196 × 44"),
		menuBar = slot("new", 0, 0.5, UDim2.new(0, 14, 0.5, 0), nil, "MenuBar", "메뉴바(S16) - PRD [D-2] 값. 파티 목록이 x = 14 + 48 + 8로 옮겨가야 한다(S18)"),
	},
	MR = {
		partyVote = slot("existing", 1, 0.5, UDim2.new(1, -14, 0.5, 0), UDim2.new(0, 210, 0, 84), "PartyVotePanel", "PartyHud.client.lua"),
	},
	BC = {
		buffRow = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -141), nil, "BuffHudAnchor", "PlayerHealthBar.client.lua - 버프 아이콘 28px 행(BOTTOM_OFFSET 94 + 체력바 19 + 8 + 10 + 10)"),
		comboPips = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -121), UDim2.new(0, 0, 0, 0), "ComboPipsAnchor", "PlayerHealthBar.client.lua - 콤보 점 자리(크기 0 - AttackInput이 자식을 끼운다)"),
		healthBar = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -94), UDim2.new(0, 394, 0, 19), "HealthBar", "PlayerHealthBar.client.lua"),
		skillRow = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -31), nil, "CentralRow", "SkillSlots.client.lua - 슬롯 54 · 높이 54(모바일 터치 배치는 SkillSlots가 따로 정한다)"),
		itemPickup = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, -140), UDim2.new(0, 360, 0, 40), "ItemPickupLabel", "ItemPickupHud.client.lua"),
		pickupPopup = slot("new", 0.5, 1, UDim2.new(0.5, 0, 1, -140), UDim2.new(0, 360, 0, 40), "ToastLane_BC", "Toast 줄 BC(획득 팝업 · 1행 · 묶기)"),
	},
	XP = {
		expBar = slot("existing", 0.5, 1, UDim2.new(0.5, 0, 1, 0), UDim2.new(1, 0, 0, 15), "ExpTrack", "ExpBar.client.lua - 높이 15(PRD 지도의 26px이 아니라 코드 값)"),
	},
}

-- 모바일 터치 컨트롤 예약 구역(화면 비율) - 슬롯 없음. { left, top, right, bottom } 비율.
ScreenMap.mobileReserved = {
	BL = { left = 0, top = 0.55, right = 0.4, bottom = 1 },
	BR = { left = 0.7, top = 0.5, right = 1, bottom = 1 },
}

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

-- 슬롯이 다른 슬롯의 "바로 아래"(slot.below)로 정해져 있으면, 그 인스턴스의 아래 끝 + gap을 frame.Position의 y로 따라간다(크기가 바뀔 때마다 - 칩이 늘고 줄어도 겹치지 않는다).
-- root = 그 인스턴스를 찾을 PlayerGui. 아직 없으면 생기는 순간 붙는다. 그 슬롯이 비어 있으면(높이 0) 이 슬롯 자신의 position.y다.
-- 가정: 대상 인스턴스는 y 앵커 0 · Position.Y.Scale 0이고 이 frame과 같은 ScreenGui 좌표계(같은 IgnoreGuiInset)에 있다(칩 스택 TopChipsRow가 그렇다).
function ScreenMap.followBelow(frame, zone, slotName, root)
	local found = ScreenMap.slot(zone, slotName)
	local below = found.below
	assert(below, ("ScreenMap.followBelow: below가 없는 슬롯 - %s.%s"):format(zone, slotName))
	local target = ScreenMap.slot(below.zone, below.slot)
	local function apply(inst)
		local y = found.position.Y.Offset
		if inst.AbsoluteSize.Y > 0 then
			y = inst.Position.Y.Offset + inst.AbsoluteSize.Y + below.gap
		end
		frame.Position = UDim2.new(found.position.X.Scale, found.position.X.Offset, 0, y)
	end
	local function bind(inst)
		apply(inst)
		inst:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			apply(inst)
		end)
	end
	local inst = root:FindFirstChild(target.instanceName, true)
	if inst then
		bind(inst)
		return
	end
	local connection
	connection = root.DescendantAdded:Connect(function(added)
		if added.Name == target.instanceName then
			connection:Disconnect()
			bind(added)
		end
	end)
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
