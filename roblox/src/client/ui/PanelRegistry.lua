-- 패널 표(30-0 S06, PRD 20.81 [D-1] · [D-4]): { id, kind, hotkey, menuOrder, iconKey } 목록. UIManager의 단축키 루프가 이 표를 읽는다.
-- 가방(I) · 파티(P, S12b) · 스테이지 선택(M, S15) - 나머지(O 상점 · K 펫 · J 보상)는 그 창을 만드는 세션이 한 줄씩 넣는다. menuOrder가 있는 항목이 메뉴바(hud/MenuBar.client.lua)의 칸이 된다(S16).
-- 금지 키(PRD 20.81 [D-1]): W A S D Q E F Space Shift X Backspace Tab Esc + 숫자열(스킬 슬롯 확장 몫) - 등록하면 error.

local PanelRegistry = {}

PanelRegistry.forbiddenKeys = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Q] = true, [Enum.KeyCode.E] = true, [Enum.KeyCode.F] = true,
	[Enum.KeyCode.Space] = true, [Enum.KeyCode.X] = true, [Enum.KeyCode.Backspace] = true, [Enum.KeyCode.Tab] = true,
	[Enum.KeyCode.Escape] = true, [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.One] = true, [Enum.KeyCode.Two] = true, [Enum.KeyCode.Three] = true, [Enum.KeyCode.Four] = true, [Enum.KeyCode.Five] = true,
	[Enum.KeyCode.Six] = true, [Enum.KeyCode.Seven] = true, [Enum.KeyCode.Eight] = true, [Enum.KeyCode.Nine] = true, [Enum.KeyCode.Zero] = true,
}

PanelRegistry.panels = {
	{ id = "inventory", kind = "window", hotkey = Enum.KeyCode.I, menuOrder = 1, iconKey = "bag", menuLabel = "가방" },
	{ id = "party", kind = "window", hotkey = Enum.KeyCode.P, menuOrder = 2, iconKey = "party", menuLabel = "파티" }, -- S12b: 파티창(panels/Party.lua). 채팅 입력 중 P는 UIManager가 gameProcessed로 무시한다.
	-- S15: 스테이지 선택(StageSelectPanel.lua). 견습 중에는 UIManager의 canOpen이 막는다. S16: 메뉴바도 견습 중 · 직업 선택 전에는 이 버튼을 숨긴다(menuHiddenWhile).
	{ id = "stageSelect", kind = "station", hotkey = Enum.KeyCode.M, menuOrder = 3, iconKey = "stage", menuLabel = "스테이지", menuHiddenWhile = { "tutorial", "noClass" } },
	-- 예약(창이 없어 아직 등록하지 않는다 - 창을 만드는 세션이 한 줄 넣는다. PRD 20.81 [D-1] · [D-2]): O 상점(menuOrder 4) · K 펫(5) · J 보상(6번째부터는 "보상" 창의 탭으로 들어간다 - 출석 · 복귀 · 시즌패스 · 계절 토큰).
}

-- 메뉴바 칸 상한(PRD 20.81 [D-2]): 상시 5칸(가방 · 파티 · 상점 · 펫 · 보상). menuOrder가 있는 항목만 센다.
PanelRegistry.menuSlotLimit = 5

function PanelRegistry.assertAllowed(keyCode, ownerId)
	assert(not PanelRegistry.forbiddenKeys[keyCode], ("PanelRegistry: 금지 키 %s를 '%s'에 등록할 수 없다"):format(tostring(keyCode), tostring(ownerId)))
end

-- 표 검사: id 겹침 · 금지 키 · 단축키 겹침 · 메뉴 칸 상한. 어긋나면 error. 자체 점검이 합성 표로 이 함수를 그대로 부른다.
function PanelRegistry.validate(panels)
	local seenIds, seenKeys, menuCount = {}, {}, 0
	for _, entry in ipairs(panels) do
		assert(not seenIds[entry.id], "PanelRegistry: id가 겹친다 - " .. entry.id)
		seenIds[entry.id] = true
		if entry.hotkey then
			PanelRegistry.assertAllowed(entry.hotkey, entry.id)
			assert(not seenKeys[entry.hotkey], ("PanelRegistry: 단축키가 겹친다 - %s"):format(tostring(entry.hotkey)))
			seenKeys[entry.hotkey] = true
		end
		if entry.menuOrder then
			menuCount += 1
			assert(menuCount <= PanelRegistry.menuSlotLimit, ("PanelRegistry: 메뉴바 칸이 %d개를 넘는다('%s') - 보상 창의 탭으로 넣어라 - PRD 20.81 [D-2]"):format(PanelRegistry.menuSlotLimit, entry.id))
		end
	end
end

PanelRegistry.validate(PanelRegistry.panels)

local byId = {}
local byHotkey = {}
for _, entry in ipairs(PanelRegistry.panels) do
	byId[entry.id] = entry
	if entry.hotkey then
		byHotkey[entry.hotkey] = entry.id
	end
end

function PanelRegistry.get(id)
	return byId[id]
end

function PanelRegistry.hotkeyOf(id)
	local entry = byId[id]
	return entry and entry.hotkey or nil
end

-- 메뉴바에 놓을 항목(menuOrder 순서, 사본 목록).
function PanelRegistry.menuEntries()
	local list = {}
	for _, entry in ipairs(PanelRegistry.panels) do
		if entry.menuOrder then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return a.menuOrder < b.menuOrder
	end)
	return list
end

return PanelRegistry
