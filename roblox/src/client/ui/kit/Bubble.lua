-- 말풍선(QUEUE-ALL2 P2 · ref 18 ① 안내창 3종 중 둘째). 안내창 3종의 역할:
--   토스트(Toast.push "TC") = 짧은 알림 · 화면 위 가운데 · 3초 / 말풍선(이 파일) = **처음 1회만** · 대상 머리 위 · 누르면 도움말 백과사전 항목 /
--   확인 창(Confirm.ask) = 되돌릴 수 없는 것만 · 위험 버튼 빨강 · 오른쪽.
-- Bubble.show(props) -> bool(띄웠는가). props = { key, adornee, text, sub, seconds, helpCategory, helpEntry, force, offsetStuds }
--   key       "한 번만" 기록 키(이 세션 안). 저장되는 1회(계정 단위)는 서버가 hints에 적고 신호를 보낼 때만 띄우는 방식이라(예: hints.stealLockSeen)
--             그 경우 호출부가 force = true로 부른다 - 이 파일은 저장 구조를 건드리지 않는다.
--   adornee   BasePart 또는 Model(Head → PrimaryPart 순). 말풍선은 그 머리 위(offsetStuds - 없으면 크기에서 계산).
--   text/sub  본문 한 줄(40자 이하 - TextData 문장) · 작은 보조 줄(선택).
--   helpCategory/helpEntry  누르면 도움말 창의 그 항목(setHelpOpener로 꽂힌 함수 - kit가 패널을 require하지 않게).
-- BillboardGui는 PlayerGui 아래(누를 수 있게 - 월드에 두면 입력을 못 받는다) · Adornee로 따라간다. 말풍선 전체가 버튼(터치 44 이상).
local Players = game:GetService("Players")

local Theme = require(script.Parent.Theme)

local Bubble = {}

Bubble.defaultSeconds = 4
local INK = Color3.fromRGB(24, 26, 36)
local INK_SUB = Color3.fromRGB(90, 95, 110)
local PAPER = Color3.new(1, 1, 1)

local seenKeys = {}
local openByKey = {}
local helpOpener = nil

function Bubble.setHelpOpener(fn)
	helpOpener = fn
end

function Bubble.seen(key)
	return seenKeys[key] == true
end

function Bubble.markSeen(key)
	seenKeys[key] = true
end

local function anchorPart(adornee)
	if adornee:IsA("BasePart") then
		return adornee, adornee.Size.Y
	end
	if adornee:IsA("Model") then
		local part = adornee:FindFirstChild("Head") or adornee.PrimaryPart or adornee:FindFirstChildWhichIsA("BasePart", true)
		if part then
			local height = part.Name == "Head" and part.Size.Y or adornee:GetExtentsSize().Y
			return part, height
		end
	end
	return nil
end

local function build(props, part, height)
	local mobile = Theme.isMobile
	local width = mobile and 300 or 280
	local boxH = props.sub and (mobile and 64 or 58) or (mobile and 48 or 44)
	local tailH = 10

	local gui = Instance.new("BillboardGui")
	gui.Name = "Bubble_" .. tostring(props.key)
	gui.ResetOnSpawn = false
	gui.Adornee = part
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.LightInfluence = 0
	gui.MaxDistance = 150
	gui.Size = UDim2.fromOffset(width, boxH + tailH)
	gui.StudsOffsetWorldSpace = Vector3.new(0, props.offsetStuds or (height / 2 + 2), 0)

	local box = Instance.new("TextButton")
	box.Name = "Box"
	box.Text = ""
	box.AutoButtonColor = false
	box.Size = UDim2.new(1, 0, 0, boxH)
	box.BackgroundColor3 = PAPER
	box.BorderSizePixel = 0
	box.Parent = gui
	Theme.corner(box, Theme.corner.panel)

	local tail = Instance.new("Frame")
	tail.Name = "Tail"
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0, 40, 0, boxH)
	tail.Size = UDim2.fromOffset(14, 14)
	tail.Rotation = 45
	tail.BackgroundColor3 = PAPER
	tail.BorderSizePixel = 0
	tail.ZIndex = 0
	tail.Parent = gui

	local hasHelp = props.helpCategory ~= nil
	local textRight = hasHelp and 44 or 12
	local title = Theme.label(box, props.text or "", "body", "textPrimary")
	title.Name = "Text"
	title.Font = Theme.font
	title.TextColor3 = INK
	title.Position = UDim2.new(0, 14, 0, props.sub and 8 or 0)
	title.Size = UDim2.new(1, -(14 + textRight), 0, props.sub and Theme.textSize("body") + 6 or boxH)
	if props.sub then
		local sub = Theme.label(box, props.sub, "caption", "textSecondary")
		sub.Name = "Sub"
		sub.TextColor3 = INK_SUB
		sub.Position = UDim2.new(0, 14, 0, 8 + Theme.textSize("body") + 6)
		sub.Size = UDim2.new(1, -(14 + textRight), 0, Theme.textSize("caption") + 4)
	end
	if hasHelp then
		-- "?" 표시(도움말로 이어진다는 모양 - 누르는 곳은 말풍선 전체)
		local mark = Theme.label(box, "?", "body", "textPrimary")
		mark.Name = "HelpMark"
		mark.Font = Theme.font
		mark.TextXAlignment = Enum.TextXAlignment.Center
		mark.BackgroundTransparency = 0
		mark.BackgroundColor3 = Theme.color("ember")
		mark.TextColor3 = PAPER
		mark.AnchorPoint = Vector2.new(1, 0.5)
		mark.Position = UDim2.new(1, -10, 0.5, 0)
		mark.Size = UDim2.fromOffset(26, 26)
		Theme.corner(mark, 13)
	end
	return gui, box
end

function Bubble.show(props)
	local key = props.key or "?"
	if not props.force and seenKeys[key] then
		return false
	end
	if not props.adornee then
		return false
	end
	local part, height = anchorPart(props.adornee)
	if not part then
		return false
	end
	seenKeys[key] = true
	if openByKey[key] then
		openByKey[key]:Destroy()
	end
	Theme.recompute()
	local gui, box = build(props, part, height)
	openByKey[key] = gui
	local function close()
		if openByKey[key] == gui then
			openByKey[key] = nil
		end
		gui:Destroy()
	end
	box.Activated:Connect(function()
		close()
		if props.helpCategory and helpOpener then
			helpOpener(props.helpCategory, props.helpEntry)
		end
	end)
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			close()
		end
	end)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	task.delay(props.seconds or Bubble.defaultSeconds, close)
	return true
end

return Bubble
