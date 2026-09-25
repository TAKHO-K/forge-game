-- 잡힘/구출 UI(29-1, PRD 20.73 [2-8] A-2 "구출 UI"). 서버(BossTrap.lua)가 Player Attribute로 내보내는
-- 사실만 그린다 - BossTrapKind(상태)·BossTrapRescueType(구출 동작)·BossTrapStartedAt/ReleaseAt(서버
-- 시계)·BossTrapRescue(구출 진행 0~1). Attribute는 전 클라에 복제되므로 파티원의 잡힘도 그대로 보인다.
--   · 잡힌 본인: 화면 아래 가운데 고정 크기 패널 - 상태 이름 + 흰 막대(자동 해제까지 남은 시간이 줄어든다)
--     + 파랑 막대(구출 진행이 차오른다). 조작이 안 되는 이유가 항상 보인다.
--   · 남(구출자 시점): 잡힌 사람 머리 위 BillboardGui - 구출 동작 픽토그램 + 같은 두 막대.
--   · 구출 입력(29-5, PRD 20.80 [B]): 서버가 잡힌 사람의 루트에 단 ProximityPrompt(F 홀드 - 모바일은 화면 버튼, 게임패드는
--     버튼이 로블록스 기본 UI로 붙는다). 누르는 사람에게는 프롬프트의 원형 진행 + 친구 머리 위 파랑 막대가 같이 찬다.
--     여기서 하는 일은 둘뿐이다: (1) 누를 수 없는 사람(잡힌 본인 · 자기도 잡혀 있는 사람)의 화면에서는 프롬프트를 끈다 -
--     보이는 것 = 되는 것. (2) 서버가 "피격으로 끊겼다"(BossRescueHoldBroken)를 알리면 내 화면의 홀드를 끊는다.
-- 색은 25-4 전조 색 언어 그대로다: 흰색 = 남은 시간·정보, 파랑 = 기회("여기서 할 일이 있다" - 헤롱
-- 말풍선과 같은 값). 새 색·새 파티클·새 에셋 없음. 고정 크기만 쓴다(AutomaticSize 없음, 20.70 [5]).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Text = require(ReplicatedStorage.Shared.Text)

local BossTrapView = {}

local INFO_COLOR = Color3.new(1, 1, 1)
local OPPORTUNITY_COLOR = Color3.fromRGB(120, 200, 255) -- BossPatternVisuals의 헤롱 말풍선과 같은 값

-- 표시 문자열(수치 아님). kind·rescueType은 BossData SPECIES_MECHANICS의 값이다.
local KIND_NAMES = {
	frozen = "빙결",
	submerged = "침수",
	crystallized = "결정화",
	buried = "속박",
	shocked = "감전",
	grabbed = "대공 잡기", -- BR1
}
-- 29-5: 구출 입력이 F 홀드 하나로 통일됐다 - 픽토그램은 "손"(꾹 누른다) 하나이고, 다른 길이 있는 종류만 그 길을 덧붙인다
-- (빙결 = 얼음을 때려도 된다 · 결정화 = 진짜를 찾아 때린다).
local RESCUE_ICONS = {
	hitCount = "✋ ⚔",
	proximity = "✋",
	gimmick = "?",
	push = "✋",
	touch = "✋",
	grab = "✋ ⚔", -- BR1 대공 잡기: 곁에서 F 홀드 또는 손을 때린다
}
local PROMPT_NAME = "BossRescuePrompt" -- 서버 BossTrap.createPrompt와 같은 이름
local HOLD_BREAK_SECONDS = 0.2 -- 피격으로 끊긴 뒤 프롬프트를 꺼 두는 시간(꺼지는 순간 홀드가 끝난다)

local PANEL_WIDTH, PANEL_HEIGHT = 260, 58
local BAR_HEIGHT = 8

local function newBar(parent, y, color)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -24, 0, BAR_HEIGHT)
	track.Position = UDim2.new(0, 12, 0, y)
	track.BackgroundColor3 = UIColors.slot
	track.BackgroundTransparency = UIColors.slotTransparency
	track.BorderSizePixel = 0
	track.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	return fill
end

local function stylePanel(frame)
	frame.BackgroundColor3 = UIColors.panel
	frame.BackgroundTransparency = UIColors.panelTransparency
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = UIColors.rim
	stroke.Transparency = UIColors.rimTransparency
	stroke.Parent = frame
end

-- 남은 시간 비율(1 → 0)과 구출 진행(0 → 1). 서버 시계 기준이라 서버의 자동 해제 순간과 같이 0에 닿는다.
local function readBars(target)
	local startedAt = target:GetAttribute("BossTrapStartedAt")
	local releaseAt = target:GetAttribute("BossTrapReleaseAt")
	local remaining = 0
	if startedAt and releaseAt and releaseAt > startedAt then
		remaining = math.clamp((releaseAt - Workspace:GetServerTimeNow()) / (releaseAt - startedAt), 0, 1)
	end
	return remaining, math.clamp(target:GetAttribute("BossTrapRescue") or 0, 0, 1)
end

function BossTrapView.start()
	local localPlayer = Players.LocalPlayer

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BossTrapGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = localPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "BossTrapPanel" -- ScreenMap 슬롯 표(BC.bossTrap)가 이 이름으로 찾는다
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -170) -- 스킬 단축바·경험치 바 위
	panel.Size = UDim2.new(0, PANEL_WIDTH, 0, PANEL_HEIGHT)
	panel.Visible = false
	panel.Parent = screenGui
	stylePanel(panel)

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Position = UDim2.new(0, 12, 0, 4)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = UIColors.textPrimary
	title.Parent = panel

	local ownCountdown = newBar(panel, 30, INFO_COLOR)
	local ownRescue = newBar(panel, 42, OPPORTUNITY_COLOR)

	-- [Player] = { gui, countdown, rescue, icon } - 남의 머리 위 표시.
	local billboards = {}

	-- 29-3 모래 무덤(속박 - "밀어서 꺼낸다"): 잡힌 자리에 흰 원(정보 = 흰색)을 그린다 - 묻힌 친구가 이 원 밖으로 밀려
	-- 나오면 풀린다. 어느 방향이든 원 밖이면 되므로 "어느 쪽으로 미는가"의 답이 그림에 있다: 가장 가까운 테두리 쪽.
	-- [Player] = Part. 자리(BossTrapOrigin)는 서버가 잡는 순간 한 번 정하고, 밀려도 원은 그 자리에 남는다.
	local graves = {}
	local function updateGrave(target, kind)
		local origin = kind == "buried" and target:GetAttribute("BossTrapOrigin") or nil
		local grave = graves[target]
		if not origin then
			if grave then
				graves[target] = nil
				grave:Destroy()
			end
			return
		end
		if not grave then
			local radius = BossData.mechanics.rescue.push.graveRadiusStuds
			grave = Instance.new("Part")
			grave.Name = "BossTrapGrave"
			grave.Shape = Enum.PartType.Cylinder
			grave.Anchored = true
			grave.CanCollide = false
			grave.CanQuery = false
			grave.CanTouch = false
			grave.CastShadow = false
			grave.Material = Enum.Material.Neon
			grave.Color = INFO_COLOR
			grave.Transparency = 0.6
			grave.Size = Vector3.new(0.2, radius * 2, radius * 2)
			-- 루트 중심은 발에서 3stud 위다(HipHeight 2 + 루트 반높이 1).
			grave.CFrame = CFrame.new(origin - Vector3.new(0, 2.85, 0)) * CFrame.Angles(0, 0, math.rad(90))
			grave.Parent = Workspace
			graves[target] = grave
		end
	end

	-- 29-5: 서버가 "예고 있는 피격으로 구출 홀드가 끊겼다"고 알리면 잠깐 프롬프트를 꺼서 내 화면의 홀드도 끊는다.
	local promptsOffUntil = 0
	ReplicatedStorage:WaitForChild("BossRescueHoldBroken").OnClientEvent:Connect(function()
		promptsOffUntil = os.clock() + HOLD_BREAK_SECONDS
	end)

	local function removeBillboard(target)
		local entry = billboards[target]
		if entry then
			billboards[target] = nil
			entry.gui:Destroy()
		end
	end

	local function ensureBillboard(target)
		local character = target.Character
		local head = character and character:FindFirstChild("Head")
		local entry = billboards[target]
		if entry and entry.gui.Adornee == head and head then
			return entry
		end
		removeBillboard(target)
		if not head then
			return nil
		end
		local gui = Instance.new("BillboardGui")
		gui.Name = "BossTrapBillboard"
		gui.Size = UDim2.new(0, 120, 0, 66)
		gui.StudsOffset = Vector3.new(0, 3.2, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 250
		gui.Adornee = head
		gui.Parent = head

		local box = Instance.new("Frame")
		box.Size = UDim2.new(1, 0, 1, 0)
		box.Parent = gui
		stylePanel(box)

		local icon = Instance.new("TextLabel")
		icon.Size = UDim2.new(1, 0, 0, 34)
		icon.BackgroundTransparency = 1
		icon.Font = Enum.Font.GothamBlack
		icon.TextSize = 26
		icon.TextColor3 = OPPORTUNITY_COLOR
		icon.Parent = box

		entry = {
			gui = gui,
			icon = icon,
			countdown = newBar(box, 38, INFO_COLOR),
			rescue = newBar(box, 50, OPPORTUNITY_COLOR),
		}
		billboards[target] = entry
		return entry
	end

	RunService.RenderStepped:Connect(function()
		local canRescue = localPlayer:GetAttribute("BossTrapKind") == nil and os.clock() >= promptsOffUntil
		for _, target in ipairs(Players:GetPlayers()) do
			local kind = target:GetAttribute("BossTrapKind")
			updateGrave(target, kind)
			if kind then
				-- 프롬프트는 서버 것이고 서버는 Enabled를 다시 쓰지 않는다 - 내 화면에서만 끄고 켠다.
				local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
				local prompt = root and root:FindFirstChild(PROMPT_NAME)
				if prompt then
					prompt.Enabled = canRescue and target ~= localPlayer
				end
			end
			if target == localPlayer then
				panel.Visible = kind ~= nil
				if kind then
					local remaining, rescue = readBars(target)
					title.Text = (kind == "grabbed" and rescue <= 0) and Text.get("boss.grab.struggle") -- BR1: 점프 연타로 발버둥(남은 시간이 준다)
						or (rescue > 0 and "%s - 친구가 구하는 중" or "%s - 움직일 수 없습니다"):format(KIND_NAMES[kind] or "잡힘")
					ownCountdown.Size = UDim2.new(remaining, 0, 1, 0)
					ownRescue.Size = UDim2.new(rescue, 0, 1, 0)
				end
			elseif kind then
				local entry = ensureBillboard(target)
				if entry then
					local remaining, rescue = readBars(target)
					entry.icon.Text = RESCUE_ICONS[target:GetAttribute("BossTrapRescueType") or ""] or "!"
					entry.countdown.Size = UDim2.new(remaining, 0, 1, 0)
					entry.rescue.Size = UDim2.new(rescue, 0, 1, 0)
				end
			elseif billboards[target] then
				removeBillboard(target)
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(target)
		removeBillboard(target)
		updateGrave(target, nil)
	end)
end

return BossTrapView
