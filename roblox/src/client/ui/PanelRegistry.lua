-- 패널 표(30-0 S06, PRD 20.81 [D-1] · [D-4]): { id, kind, hotkey, menuOrder, iconKey } 목록. UIManager의 단축키 루프가 이 표를 읽는다.
-- 가방(B, S20 사전 작업에서 I → B) · 파티(P, S12b) · 스테이지 선택(M, S15) - 나머지(상점 · 펫 · 보상)는 그 창을 만드는 세션이 한 줄씩 넣는다(O는 못 쓴다 - 아래 swallowedKeys). menuOrder가 있는 항목이 메뉴바(hud/MenuBar.client.lua)의 칸이 된다(S16).
-- 금지 키(PRD 20.81 [D-1]): W A S D Q E F Space Shift X Backspace Tab Esc + 숫자열(스킬 슬롯 확장 몫) - 등록하면 error.

local Text = require(game:GetService("ReplicatedStorage").Shared.Text)

local PanelRegistry = {}

PanelRegistry.forbiddenKeys = {
	[Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
	[Enum.KeyCode.Q] = true, [Enum.KeyCode.E] = true, [Enum.KeyCode.F] = true, [Enum.KeyCode.R] = true, [Enum.KeyCode.T] = true, -- K1 · K2: R 스킬 · T 궁극기
	[Enum.KeyCode.Space] = true, [Enum.KeyCode.X] = true, [Enum.KeyCode.Backspace] = true, [Enum.KeyCode.Tab] = true,
	[Enum.KeyCode.Escape] = true, [Enum.KeyCode.LeftShift] = true, [Enum.KeyCode.RightShift] = true,
	[Enum.KeyCode.One] = true, [Enum.KeyCode.Two] = true, [Enum.KeyCode.Three] = true, [Enum.KeyCode.Four] = true, [Enum.KeyCode.Five] = true,
	[Enum.KeyCode.Six] = true, [Enum.KeyCode.Seven] = true, [Enum.KeyCode.Eight] = true, [Enum.KeyCode.Nine] = true, [Enum.KeyCode.Zero] = true,
}

-- 엔진이 먼저 가져가는 키(S20 사전 작업 실측): 로블록스 기본 카메라의 줌 키 I · O는 **수정자 없이 누르면 KeyDown이 UserInputService · ContextActionService(우선순위 3000)에 도달하지 않는다**
-- (KeyUp만 온다 - Shift + I는 온다. 한/영 상태와 무관하고 P · M · U · K는 정상). 가상 입력(MCP)은 통과해서 자동 입력 테스트가 이 결함을 못 잡았다. 그래서 단축키로 등록할 수 없다.
PanelRegistry.swallowedKeys = { [Enum.KeyCode.I] = true, [Enum.KeyCode.O] = true }

-- QUEUE-ALL2 P2(09 문서 B-3 최종 단축키 표 · 사용자 10-01): G 가방 · C 캐릭터 · M 지도 · N 구역 선택(옛 "맵 선택" M) · J 퀘스트 · K 도감 · U 수련 · P 파티 · L 순위 · B 귀환(행동 키).
--   왼쪽 메뉴 = menuOrder 순 7칸(가방 · 캐릭터 · 지도 상시 - menuPinned) · menuMore = "더보기"(…) 안으로(파티 · 설정 - ALL7B 2: 순위는 허브 명예의 전당 · L 키). 모든 창 = 같은 키로 열고 닫기 + X · Backspace 닫기(Esc = 로블록스 메뉴 전용 - 18-1 [2]).
--   opener(선택) = 등록 전(처음 열 때 짓는) 창을 여는 모듈 이름(panels/<이름>.toggle) - 메뉴 버튼 · 단축키가 그 함수를 부른다.
PanelRegistry.panels = {
	{ id = "inventory", kind = "window", hotkey = Enum.KeyCode.G, menuOrder = 1, iconKey = "bag", menuLabel = Text.get("ui.panel.menu.inventory"), menuPinned = true },
	{ id = "character", kind = "window", hotkey = Enum.KeyCode.C, menuOrder = 2, iconKey = "character", menuLabel = Text.get("ui.panel.menu.character"), menuPinned = true, menuHiddenWhile = { "noClass" } }, -- 성장 · 능력치 · 직업 변경(panels/Character)
	{ id = "worldMap", kind = "window", hotkey = Enum.KeyCode.M, menuOrder = 3, iconKey = "map", menuLabel = Text.get("ui.panel.menu.worldMap"), menuPinned = true }, -- 전체 지도 · 핀 · 자동 이동 · 체크포인트(panels/WorldMapPanel)
	-- S15: 구역(스테이지) 선택(StageSelectPanel.lua) - QUEUE-ALL2: 키 M → N · 이름 "구역 선택". 견습 중에는 UIManager의 canOpen이 막는다.
	{ id = "stageSelect", kind = "station", hotkey = Enum.KeyCode.N, menuOrder = 4, iconKey = "zone_select", menuLabel = Text.get("ui.panel.menu.stageSelect"), menuHiddenWhile = { "tutorial", "noClass" } },
	{ id = "quests", kind = "window", hotkey = Enum.KeyCode.J, menuOrder = 5, iconKey = "quest", menuLabel = Text.get("ui.panel.menu.quests"), menuHiddenWhile = { "noClass" } }, -- QUEUE-10h Q7(panels/Quests) · QUEUE-ALL3 Q3 탭
	{ id = "codex", kind = "window", hotkey = Enum.KeyCode.K, menuOrder = 6, iconKey = "codex", menuLabel = Text.get("ui.panel.menu.codex"), menuHiddenWhile = { "tutorial", "noClass" }, menuMore = true }, -- QUEUE-ALL1 P5 도감 v2(panels/Codex) · QUEUE-ALL9C 1-7 L2: 더보기 안(가끔 확인 - K · 알림 점은 더보기 버튼으로)
	{ id = "training", kind = "window", hotkey = Enum.KeyCode.U, menuOrder = 7, iconKey = "training", menuLabel = Text.get("ui.panel.menu.training"), menuHiddenWhile = { "tutorial", "noClass" } }, -- QUEUE-ALL3 Q2(panels/Training - 옛 퀘스트 창 수련 줄)
	{ id = "party", kind = "window", hotkey = Enum.KeyCode.P, iconKey = "party", menuLabel = Text.get("ui.panel.menu.party") }, -- S12b 파티창(panels/Party.lua) · 친구 초대 = 창 맨 위 · QUEUE-ALL9C 1-4: 더보기에서 뺌 - 열기 = HUD [파티] 버튼 · P 하나(창 안 탭 = 내 파티 · 파티 찾기)
	{ id = "leaderboard", kind = "window", hotkey = Enum.KeyCode.L, menuOrder = 9, iconKey = "rank", menuLabel = Text.get("ui.panel.menu.leaderboard"), opener = "Leaderboard", menuMore = true }, -- QUEUE-ALL9C 1-7 L2: 더보기 안(허브 명예의 전당 · L 그대로) -- QUEUE-ALL7B 2: 메뉴 칸 없음(허브 명예의 전당 · L 키) -- panels/Leaderboard(처음 열 때 짓는다)
	{ id = "settings", kind = "window", menuOrder = 10, iconKey = "settings", menuLabel = Text.get("ui.panel.menu.settings"), menuMore = true, opener = "Settings" }, -- panels/Settings(분류 탭 · 단축키 보기)
}

-- 창이 아닌 단축키(버튼 동작) - 패널 단축키 · 금지 키와 겹치면 validate가 error. 처리 = 그 버튼 코드(귀환 = WorldClient - 시전 중 다시 누르면 취소).
PanelRegistry.actionKeys = {
	{ id = "hubReturn", hotkey = Enum.KeyCode.B }, -- QUEUE-ALL2: H → B(리그 오브 레전드 귀환 키)
}

-- 메뉴 칸 상한(ref 16 "7개 넘으면 더보기"): menuMore가 아닌 menuOrder 항목만 센다.
PanelRegistry.menuSlotLimit = 7

-- 설정 "단축키 보기" 표(09 문서 B-3) - 패널 · 행동 키 + 전투 키(글자 = TextData)
PanelRegistry.hotkeySheet = {
	{ keys = "WASD · Space · Shift", text = "hotkeys.move" },
	{ keys = "Q · E · R · T", text = "hotkeys.skills" },
	{ keys = "Ctrl", text = "hotkeys.lock" },
	{ keys = "F", text = "hotkeys.interact" },
	{ keys = "B", text = "hotkeys.recall" },
	{ keys = "G", text = "hotkeys.bag" },
	{ keys = "C", text = "hotkeys.character" },
	{ keys = "U", text = "hotkeys.training" },
	{ keys = "M", text = "hotkeys.map" },
	{ keys = "N", text = "hotkeys.zone" },
	{ keys = "J", text = "hotkeys.quests" },
	{ keys = "K", text = "hotkeys.codex" },
	{ keys = "P", text = "hotkeys.party" },
	{ keys = "L", text = "hotkeys.rank" },
	{ keys = "X · Backspace", text = "hotkeys.close" },
}

function PanelRegistry.assertAllowed(keyCode, ownerId)
	assert(not PanelRegistry.swallowedKeys[keyCode], ("PanelRegistry: %s는 엔진(기본 카메라 줌 키)이 먼저 가져가 단축키로 못 쓴다 - '%s'"):format(tostring(keyCode), tostring(ownerId)))
	assert(not PanelRegistry.forbiddenKeys[keyCode], ("PanelRegistry: 금지 키 %s를 '%s'에 등록할 수 없다"):format(tostring(keyCode), tostring(ownerId)))
end

-- 표 검사: id 겹침 · 금지 키 · 단축키 겹침 · 메뉴 칸 상한. 어긋나면 error. 자체 점검이 합성 표로 이 함수를 그대로 부른다.
function PanelRegistry.validate(panels, actionKeys)
	local seenIds, seenKeys, menuCount = {}, {}, 0
	for _, a in ipairs(actionKeys or {}) do
		PanelRegistry.assertAllowed(a.hotkey, a.id)
		assert(not seenKeys[a.hotkey], ("PanelRegistry: 단축키가 겹친다 - %s"):format(tostring(a.hotkey)))
		seenKeys[a.hotkey] = true
	end
	for _, entry in ipairs(panels) do
		assert(not seenIds[entry.id], "PanelRegistry: id가 겹친다 - " .. entry.id)
		seenIds[entry.id] = true
		if entry.hotkey then
			PanelRegistry.assertAllowed(entry.hotkey, entry.id)
			assert(not seenKeys[entry.hotkey], ("PanelRegistry: 단축키가 겹친다 - %s"):format(tostring(entry.hotkey)))
			seenKeys[entry.hotkey] = true
		end
		if entry.menuOrder and not entry.menuMore then
			menuCount += 1
			assert(menuCount <= PanelRegistry.menuSlotLimit, ("PanelRegistry: 메뉴바 칸이 %d개를 넘는다('%s') - 더보기(menuMore)로 넣어라"):format(PanelRegistry.menuSlotLimit, entry.id))
		end
	end
end

PanelRegistry.validate(PanelRegistry.panels, PanelRegistry.actionKeys)

function PanelRegistry.actionKey(id)
	for _, a in ipairs(PanelRegistry.actionKeys) do
		if a.id == id then
			return a.hotkey
		end
	end
	return nil
end

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

-- 메뉴바에 놓을 항목(menuOrder 순서, 사본 목록). more = true면 더보기 안 항목만 · 아니면 줄 위 항목만.
function PanelRegistry.menuEntries(more)
	local list = {}
	for _, entry in ipairs(PanelRegistry.panels) do
		if entry.menuOrder and (entry.menuMore == true) == (more == true) then
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return a.menuOrder < b.menuOrder
	end)
	return list
end

return PanelRegistry
