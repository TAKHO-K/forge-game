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

local UIManager = {}

local TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local BASE_DISPLAY_ORDER = 100 -- 다른 HUD ScreenGui(기본값 0)보다 항상 위.
local CLOSE_TOP_KEYS = { [Enum.KeyCode.X] = true, [Enum.KeyCode.Backspace] = true }

local windows = {} -- id -> config(register가 받은 것 그대로)
local stack = {} -- 열린 창 id들, LIFO(맨 뒤 = 맨 위)
local debounce = {} -- id -> true(트윈 재생 중 - 이 동안 그 id의 열기/닫기 요청을 무시한다)

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

local function applyStackOrder()
	for order, id in ipairs(stack) do
		local win = windows[id]
		if win.screenGui then
			win.screenGui.DisplayOrder = BASE_DISPLAY_ORDER + order
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
		local value = open and t.open or t.closed
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

-- config: { screenGui, frame, hotkey, modal, exclusive, hasCloseButton, tweens, extraVisible, onOpen, onClose }
-- screenGui: 스택 순서에 따라 DisplayOrder를 재계산할 대상(창마다 별도 ScreenGui를 쓰는
--   이 프로젝트 구조상 ZIndex 대신 이 값으로 위아래를 가른다).
-- frame: 열림/닫힘에 따라 Visible을 토글할 창 본체. extraVisible: 같이 토글할 것들(딤 등).
-- tweens: { {instance, property, open=값, closed=값}, ... } - 공통 타이밍(TWEEN_INFO)으로
--   매니저가 재생한다. 창마다 트윈을 직접 만들지 않는다(지시).
function UIManager.register(id, config)
	assert(not windows[id], "UIManager.register: 이미 등록된 id - " .. tostring(id))
	if config.hasCloseButton ~= true then
		warn(("UIManager: '%s' 창에 닫기 버튼이 없다 - 모바일에서 닫을 방법이 없어진다"):format(id))
	end
	windows[id] = config
end

function UIManager.open(id)
	local win = windows[id]
	if not win or debounce[id] or UIManager.isOpen(id) then
		return
	end

	if win.exclusive then
		for _, otherId in ipairs(table.clone(stack)) do
			if otherId ~= id and windows[otherId].exclusive then
				UIManager.close(otherId)
			end
		end
	end

	table.insert(stack, id)
	applyStackOrder()
	setWindowVisualState(id, true, false)
	updateModalEnabled()
	if win.onOpen then
		win.onOpen()
	end
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
	applyStackOrder()
	setWindowVisualState(id, false, instant)
	updateModalEnabled()
	if win.onClose then
		win.onClose()
	end
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
		if win.hotkey == input.KeyCode then
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
