-- 패널 표(30-0 S06, PRD 20.81 [D-1] · [D-4]): { id, kind, hotkey, menuOrder, iconKey } 목록. UIManager의 단축키 루프가 이 표를 읽는다.
-- 가방(I) · 파티(P, S12b) - 나머지(M 스테이지 · O 상점 · K 펫 · J 보상)는 그 창을 만드는 세션(S16 ~)이 한 줄씩 넣는다.
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
	{ id = "inventory", kind = "window", hotkey = Enum.KeyCode.I, menuOrder = 1, iconKey = "bag" },
	{ id = "party", kind = "window", hotkey = Enum.KeyCode.P, menuOrder = 2, iconKey = "party" }, -- S12b: 파티창(panels/Party.lua). 채팅 입력 중 P는 UIManager가 gameProcessed로 무시한다.
}

function PanelRegistry.assertAllowed(keyCode, ownerId)
	assert(not PanelRegistry.forbiddenKeys[keyCode], ("PanelRegistry: 금지 키 %s를 '%s'에 등록할 수 없다"):format(tostring(keyCode), tostring(ownerId)))
end

local byId = {}
local byHotkey = {}
for _, entry in ipairs(PanelRegistry.panels) do
	assert(not byId[entry.id], "PanelRegistry: id가 겹친다 - " .. entry.id)
	if entry.hotkey then
		PanelRegistry.assertAllowed(entry.hotkey, entry.id)
		assert(not byHotkey[entry.hotkey], ("PanelRegistry: 단축키가 겹친다 - %s"):format(tostring(entry.hotkey)))
		byHotkey[entry.hotkey] = entry.id
	end
	byId[entry.id] = entry
end

function PanelRegistry.get(id)
	return byId[id]
end

function PanelRegistry.hotkeyOf(id)
	local entry = byId[id]
	return entry and entry.hotkey or nil
end

return PanelRegistry
