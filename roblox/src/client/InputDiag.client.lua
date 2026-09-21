-- [InputDiag] 임시 입력 진단 로거(S20 사전 작업). 수동 Play에서도 돈다(Studio 전용). 실제 키보드의 I · P · M이 어느 단계에서 끊기는지 한 줄씩 남긴다:
--   ① 이 로거의 InputBegan(모든 입력: KeyCode · 입력 종류 · gameProcessedEvent · 포커스된 TextBox) ② UIManager 단축키 루프(UIManager.inputDiag) ③ 창 열림 결과.
-- 로블록스 기본 카메라(CameraModule)가 I · O를 줌 키로 ContextActionService에 묶어 먼저 처리하는지 보려고, I가 눌릴 때 그 키에 묶인 액션 목록도 찍는다.
-- 원인 확인 뒤 제거한다.

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

if not RunService:IsStudio() or not require(game:GetService("ReplicatedStorage").Shared.data.DevToolsConfig).inputDiag then
	return -- 기본 꺼짐(DevToolsConfig.inputDiag = true로 켠다)
end

local UIManager = require(script.Parent.UIManager)

local function log(text)
	print("[InputDiag] " .. text)
end

UIManager.inputDiag = log

local function boundActionsFor(keyCode)
	local names = {}
	for name, info in pairs(ContextActionService:GetAllBoundActionInfo()) do
		for _, bound in ipairs(info.inputTypes or {}) do
			if bound == keyCode then
				table.insert(names, ("%s(우선순위 %s · 스택 %s)"):format(name, tostring(info.priorityLevel), tostring(info.stackOrder)))
				break
			end
		end
	end
	return #names > 0 and table.concat(names, " · ") or "없음"
end

log(("시작 - 키보드 %s · 터치 %s · 게임패드 %s · 창 포커스 %s"):format(tostring(UserInputService.KeyboardEnabled), tostring(UserInputService.TouchEnabled), tostring(UserInputService.GamepadEnabled), tostring(UserInputService:GetFocusedTextBox() == nil)))
UserInputService.WindowFocused:Connect(function()
	log("Studio 창 포커스 얻음(WindowFocused)")
end)
UserInputService.WindowFocusReleased:Connect(function()
	log("Studio 창 포커스 잃음(WindowFocusReleased)")
end)
UserInputService.TextBoxFocused:Connect(function(box)
	log("TextBox 포커스 얻음: " .. box:GetFullName())
end)
UserInputService.TextBoxFocusReleased:Connect(function(box)
	log("TextBox 포커스 풀림: " .. box:GetFullName())
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		return
	end
	local box = UserInputService:GetFocusedTextBox()
	local extra = ""
	if input.KeyCode == Enum.KeyCode.I or input.KeyCode == Enum.KeyCode.O or input.KeyCode == Enum.KeyCode.P or input.KeyCode == Enum.KeyCode.M then
		extra = " · 이 키에 묶인 액션: " .. boundActionsFor(input.KeyCode)
	end
	log(("입력 key=%s type=%s gameProcessed=%s 포커스TextBox=%s 메뉴열림=%s 열린창=%s%s"):format(
		input.KeyCode.Name, input.UserInputType.Name, tostring(gameProcessedEvent), box and box:GetFullName() or "없음", tostring(GuiService.MenuIsOpen), table.concat(UIManager.getStack(), ",") ~= "" and table.concat(UIManager.getStack(), ",") or "없음", extra))
end)

-- ── 2차 진단: 이벤트가 아예 안 오는 키를 좁힌다 ──
-- ① 원시 키 상태 폴링: UserInputService:GetKeysPressed()에 키가 잡히는데 InputBegan이 안 오면 이벤트 전달만 막힌 것이고, 폴링에도 안 잡히면 엔진이 그 키를 못 받는 것이다.
-- ② ContextActionService에 I · O · U · K를 Pass로 묶어 본다(우선순위 최상): 여기 도달하는지.
do
	local previous = {}
	RunService.Heartbeat:Connect(function()
		local current = {}
		for _, input in ipairs(UserInputService:GetKeysPressed()) do
			current[input.KeyCode] = true
			if not previous[input.KeyCode] then
				log(("원시 키 눌림(GetKeysPressed): %s"):format(input.KeyCode.Name))
			end
		end
		for keyCode in pairs(previous) do
			if not current[keyCode] then
				log(("원시 키 뗌(GetKeysPressed): %s"):format(keyCode.Name))
			end
		end
		previous = current
	end)
	ContextActionService:BindActionAtPriority("InputDiagWatch", function(_, state, input)
		log(("CAS 도달: key=%s state=%s"):format(input.KeyCode.Name, state.Name))
		return Enum.ContextActionResult.Pass
	end, false, 3000, Enum.KeyCode.I, Enum.KeyCode.O, Enum.KeyCode.U, Enum.KeyCode.K)
	log("2차 진단 시작 - GetKeysPressed 폴링 + CAS 감시(I · O · U · K)")
end
