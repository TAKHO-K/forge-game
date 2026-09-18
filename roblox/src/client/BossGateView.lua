-- 파훼 게이트 표시 + 힌트 화살표(29-1, PRD 20.73 [2-8] A-3 · [1-5]).
--   · 게이트: 서버(BossMechanics)가 보스 모델에 Attribute "GateArmed"를 건다. 서 있는 동안 보스 머리 위에
--     작은 흰 표식(◈)을 띄운다 - "지금은 딜이 덜 들어간다, 기믹을 풀어라"는 상태 정보다(흰색 = 정보).
--     28-2 [2-0] 3번 "보스의 상태는 색이 아니라 실루엣·말풍선으로"에 맞춰 몸 색은 건드리지 않는다.
--     파훼 순간의 파랑 말풍선(기회)은 BossPatternVisuals가 "gimmickResolve"에서 띄운다.
--   · 힌트 화살표: 같은 보스에게 전멸한 적이 있으면(힌트 1단계+) 서버가 기믹 예고에 안전지대 좌표를
--     실어 보낸다 - 그 자리 위에 흰 ▼를 세운다.
-- 새 색·새 파티클·새 에셋 없음.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BossGateView = {}

local INFO_COLOR = Color3.new(1, 1, 1)
local ARROW_HEIGHT_STUDS = 7

local function refresh(model)
	local head = model:FindFirstChild("Head")
	local existing = head and head:FindFirstChild("BossGateMark")
	local armed = model:GetAttribute("GateArmed") == true
	if not armed or not head then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossGateMark"
	gui.Size = UDim2.new(0, 44, 0, 44)
	gui.StudsOffset = Vector3.new(0, 3.2, 0) -- 패턴 말풍선(오프셋 6) 아래
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Adornee = head
	gui.Parent = head

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 1, 0)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.Text = "◈"
	icon.TextColor3 = INFO_COLOR
	icon.TextStrokeTransparency = 0.3
	icon.Parent = gui
end

local function watch(model)
	model:GetAttributeChangedSignal("GateArmed"):Connect(function()
		refresh(model)
	end)
	refresh(model)
end

function BossGateView.start()
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		watch(model)
	end
	CollectionService:GetInstanceAddedSignal("Monster"):Connect(watch)
end

-- positions = { Vector3(지면 좌표), ... } - seconds 동안 그 위에 흰 ▼가 위아래로 흔들린다.
function BossGateView.showHintArrows(positions, seconds)
	for _, position in ipairs(positions) do
		local anchor = Instance.new("Part")
		anchor.Name = "BossHintArrow"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Position = position + Vector3.new(0, ARROW_HEIGHT_STUDS, 0)
		anchor.Parent = Workspace

		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.new(0, 56, 0, 56)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 400
		gui.Adornee = anchor
		gui.Parent = anchor

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 1, 0)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBlack
		icon.TextScaled = true
		icon.Text = "▼"
		icon.TextColor3 = INFO_COLOR
		icon.TextStrokeTransparency = 0.3
		icon.Parent = gui

		TweenService:Create(anchor, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = anchor.Position - Vector3.new(0, 1.5, 0),
		}):Play()
		task.delay(seconds, function()
			anchor:Destroy()
		end)
	end
end

return BossGateView
