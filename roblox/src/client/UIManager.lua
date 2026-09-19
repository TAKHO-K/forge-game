-- GUI 창 관리 프레임워크(18-1 [1] 신설). 가방/장비창(16-3)까지는 창마다 자기 열기·닫기·
-- 트윈·ESC 처리를 따로 갖고 있었다 - 앞으로 강화대·상점·스테이지 선택·설정·다른 유저
-- 정보·아이템 분해·이벤트/뽑기 창이 붙을 때마다 같은 버그(입력 안 막힘, 모바일 닫기
-- 버튼 누락, 리스폰 후 유령 상태 등)를 여러 파일에서 반복해서 고치게 된다 - 그래서
-- 열림 스택·입력 차단·트윈·모바일 처리를 여기 한 곳에 모은다.
--
-- 18-1 [2]: ESC는 로블록스 CoreGUI 전용 액션이라 VirtualInput조차 주입을 거부한다
-- (실기 확인 - UserInputService.InputBegan에 이벤트가 전혀 도달하지 않았다). 그래서
-- "맨 위 창 닫기"는 ESC 대신 X/Backspace 두 키에 바인딩한다(사용자 지시, Tab은 과거
-- CoreGUI 액션 충돌 이력이 있어 제외).

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local PanelRegistry = require(script.Parent.ui.PanelRegistry)

local UIManager = {}

local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- 종류별 DisplayOrder 대역(30-0 S06, PRD 20.81 [D-1]): station 10 ~ 19 · window 100 ~ 149 · overlay 200 ~ 249. 다른 HUD ScreenGui(기본값 0 ~ 8)보다 항상 위.
-- window의 값은 S06 전과 같다(BASE 100 + 스택 안 순번 = 가방 101).
local KIND_BASE_ORDER = { station = 10, window = 100, overlay = 200 }
local CLOSE_TOP_KEYS = { [Enum.KeyCode.X] = true, [Enum.KeyCode.Backspace] = true }

local windows = {} -- id -> config(register가 받은 것 그대로)
local stack = {} -- 열린 창 id들, LIFO(맨 뒤 = 맨 위)
local debounce = {} -- id -> true(트윈 재생 중 - 이 동안 그 id의 열기/닫기 요청을 무시한다)
local overlayParents = {} -- overlay id -> 지금 열려 있는 동안의 부모 패널 id(부모가 닫히면 같이 닫힌다)
local bossFight = false -- true인 동안 window의 딤(tweens 중 isDim = true)을 끈다

-- 설정창이 아직 없어서(이번 단계에서 만들지 않는다) 열린 창이 하나도 없을 때 ESC 역할
-- 대체 키를 누르면 할 일이 없다 - 나중에 설정창이 register될 때 이 훅만 채우면 된다.
UIManager.onEmptyStackAction = nil

local function isModalOpen()
	for _, id in ipairs(stack) do
		if windows[id].modal then
			return true
		end
	end
	return false
end
UIManager.isModalOpen = isModalOpen

-- 스택 순서(맨 뒤 = 맨 위)대로, 같은 종류끼리 순번을 세어 그 종류 대역 안에서 DisplayOrder를 준다.
local function applyStackOrder()
	local rank = { station = 0, window = 0, overlay = 0 }
	for _, id in ipairs(stack) do
		local win = windows[id]
		rank[win.kind] += 1
		if win.screenGui then
			win.screenGui.DisplayOrder = KIND_BASE_ORDER[win.kind] + rank[win.kind]
		end
	end
end

local function updateModalEnabled()
	-- 모바일 터치 조이스틱·카메라 조작을 modal 창이 하나라도 열려 있는 동안 숨긴다.
	-- 창이 여러 개 겹쳐 있어도 마지막 하나가 닫힐 때만 꺼야 한다(지시) - isModalOpen()이
	-- 스택 전체를 보고 판단하므로 개별 open/close가 서로의 몫을 덮어쓰지 않는다.
	UserInputService.ModalEnabled = isModalOpen()
end

local function applyTweenTargets(win, open, instant)
	for _, t in ipairs(win.tweens or {}) do
		-- 보스전 중(setBossFight)에는 딤 트윈(isDim)이 열릴 때도 닫힌 값(투명)을 쓴다.
		local value = (open and not (bossFight and t.isDim)) and t.open or t.closed
		if instant then
			t.instance[t.property] = value
		else
			TweenService:Create(t.instance, TWEEN_INFO, { [t.property] = value }):Play()
		end
	end
end

local function setVisible(win, visible)
	if win.frame then
		win.frame.Visible = visible
	end
	for _, inst in ipairs(win.extraVisible or {}) do
		inst.Visible = visible
	end
end

local function setWindowVisualState(id, open, instant)
	local win = windows[id]
	if open then
		setVisible(win, true)
	end
	applyTweenTargets(win, open, instant)

	local function finish()
		if not open then
			setVisible(win, false)
		end
		debounce[id] = false
	end

	if instant then
		finish()
	else
		debounce[id] = true
		task.delay(TWEEN_INFO.Time, finish)
	end
end

function UIManager.isOpen(id)
	return table.find(stack, id) ~= nil
end

-- config: { kind, parentId, screenGui, frame, hotkey, modal, exclusive, hasCloseButton, tweens, extraVisible, onOpen, onClose }
-- kind(30-0 S06, PRD 20.81 [D-1]): "window"(기본 - 안 준 기존 등록(가방)은 그대로 window) · "station" · "overlay".
--   window: 열리면 다른 window · station을 닫는다. 모달. / station: 열리면 다른 station을 닫고, window가 열려 있으면 **열리지 않는다**. 모달이 아니다(걸을 수 있다).
--   overlay: 맨 위에 1개 - 열리면 다른 overlay를 닫는다. 모달. parentId(config 또는 open의 opts)의 패널이 닫히면 같이 닫힌다.
-- tweens 항목의 isDim = true: 딤 트윈 표시 - UIManager.setBossFight(true)인 동안 열려도 투명으로 둔다.
-- screenGui: 스택 순서에 따라 DisplayOrder를 재계산할 대상(창마다 별도 ScreenGui를 쓰는
--   이 프로젝트 구조상 ZIndex 대신 이 값으로 위아래를 가른다).
-- frame: 열림/닫힘에 따라 Visible을 토글할 창 본체. extraVisible: 같이 토글할 것들(딤 등).
-- tweens: { {instance, property, open=값, closed=값}, ... } - 공통 타이밍(TWEEN_INFO)으로
--   매니저가 재생한다. 창마다 트윈을 직접 만들지 않는다(지시).
function UIManager.register(id, config)
	assert(not windows[id], "UIManager.register: 이미 등록된 id - " .. tostring(id))
	config.kind = config.kind or "window"
	assert(KIND_BASE_ORDER[config.kind], ("UIManager.register: 알 수 없는 kind - %s (%s)"):format(tostring(config.kind), tostring(id)))
	if config.kind == "station" then
		config.modal = false -- station은 걸을 수 있다
	elseif config.modal == nil then
		config.modal = true -- window · overlay는 기본이 모달
	end
	if config.hotkey then
		PanelRegistry.assertAllowed(config.hotkey, id)
	end
	if config.hasCloseButton ~= true then
		warn(("UIManager: '%s' 창에 닫기 버튼이 없다 - 모바일에서 닫을 방법이 없어진다"):format(id))
	end
	windows[id] = config
end

-- 열렸으면 true, 규칙 · 트윈 중이라 안 열렸으면 false. opts.parentId = overlay의 부모 패널 id(config.parentId보다 우선).
function UIManager.open(id, opts)
	local win = windows[id]
	if not win or debounce[id] or UIManager.isOpen(id) then
		return false
	end

	local kind = win.kind
	if kind == "station" then
		-- window가 열려 있으면 station은 열리지 않는다. 다른 station은 닫는다.
		for _, otherId in ipairs(stack) do
			if windows[otherId].kind == "window" then
				return false
			end
		end
		for _, otherId in ipairs(table.clone(stack)) do
			if windows[otherId].kind == "station" then
				UIManager.close(otherId)
			end
		end
	elseif kind == "window" then
		-- 다른 window · station을 닫는다(overlay는 부모가 닫히면서 같이 닫힌다).
		for _, otherId in ipairs(table.clone(stack)) do
			if windows[otherId].kind ~= "overlay" then
				UIManager.close(otherId)
			end
		end
	else
		for _, otherId in ipairs(table.clone(stack)) do
			if windows[otherId].kind == "overlay" then
				UIManager.close(otherId, true)
			end
		end
		overlayParents[id] = (opts and opts.parentId) or win.parentId
	end

	table.insert(stack, id)
	applyStackOrder()
	setWindowVisualState(id, true, false)
	updateModalEnabled()
	if win.onOpen then
		win.onOpen()
	end
	return true
end

function UIManager.close(id, instant)
	local win = windows[id]
	if not win then
		return
	end
	if debounce[id] and not instant then
		return
	end
	local index = table.find(stack, id)
	if not index then
		return
	end

	table.remove(stack, index)
	overlayParents[id] = nil
	applyStackOrder()
	setWindowVisualState(id, false, instant)
	updateModalEnabled()
	if win.onClose then
		win.onClose()
	end
	-- 부모가 닫히면 그 부모의 overlay도 같이 닫는다(트윈을 기다리지 않는다).
	if win.kind ~= "overlay" then
		for _, otherId in ipairs(table.clone(stack)) do
			if windows[otherId].kind == "overlay" and overlayParents[otherId] == id then
				UIManager.close(otherId, true)
			end
		end
	end
end

-- 등록을 지운다(열려 있으면 즉시 닫는다). 전시장처럼 같은 id를 다시 지어야 하는 개발용 패널이 쓴다.
function UIManager.unregister(id)
	if not windows[id] then
		return
	end
	UIManager.close(id, true)
	windows[id] = nil
	debounce[id] = nil
	overlayParents[id] = nil
end

function UIManager.toggle(id)
	if UIManager.isOpen(id) then
		UIManager.close(id)
	else
		UIManager.open(id)
	end
end

function UIManager.closeTop()
	if #stack == 0 then
		if UIManager.onEmptyStackAction then
			UIManager.onEmptyStackAction()
		end
		return
	end
	UIManager.close(stack[#stack])
end

-- 리스폰 시 유령 상태 방지용으로도 쓴다(아래 CharacterAdded 훅) - 트윈 없이 즉시 정리.
function UIManager.closeAll()
	for _, id in ipairs(table.clone(stack)) do
		UIManager.close(id, true)
	end
end

function UIManager.getKind(id)
	return windows[id] and windows[id].kind
end

-- 열린 패널 id들(맨 뒤 = 맨 위). 복사본이다.
function UIManager.getStack()
	return table.clone(stack)
end

-- 보스전 중에는 window의 딤을 끈다(보스 전조가 비쳐 보이게 - PRD 20.81 [D-1]). 이 함수를 부르는 감시자(BossFightWatcher)는 S06에서 만들지 않았다 -
-- 클라가 보스전 여부를 아는 기존 신호가 없다(PRD 20.88 미결). 열려 있는 window의 딤은 바로 바뀐다.
function UIManager.setBossFight(active)
	bossFight = active == true
	for _, id in ipairs(stack) do
		local win = windows[id]
		if win.kind == "window" then
			for _, t in ipairs(win.tweens or {}) do
				if t.isDim then
					t.instance[t.property] = bossFight and t.closed or t.open
				end
			end
		end
	end
end

-- 창 위 클릭·탭 기본공격을 막을 때 gameProcessedEvent만 믿지 말고 이 값도 같이 보라는
-- 지시(18-1 [3]) - AttackInput.client.lua가 참조한다.
UIManager.isInputBlocked = isModalOpen

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then
		return
	end
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end

	if CLOSE_TOP_KEYS[input.KeyCode] then
		UIManager.closeTop()
		return
	end

	for id, win in pairs(windows) do
		if (PanelRegistry.hotkeyOf(id) or win.hotkey) == input.KeyCode then
			UIManager.toggle(id)
			return
		end
	end
end)

-- ResetOnSpawn=false로 만든 ScreenGui들이라 캐릭터가 죽어도 Frame 자체는 안 사라지지만,
-- 창을 열어 둔 채 죽으면(예: 강화대 근처) 리스폰 후에도 스택·모달 차단이 남아있을 수
-- 있다 - 새 캐릭터가 생길 때마다 강제로 다 닫는다(지시 - 검증 시나리오 8번).
local player = Players.LocalPlayer
player.CharacterAdded:Connect(function()
	UIManager.closeAll()
end)

return UIManager
