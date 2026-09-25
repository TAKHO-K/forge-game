-- BR1-2 첫 만남 전멸기 카드(docs/design/boss-br1-2.md §2). 서버 BossEncounter가 그 보스를 처음 만난 사람에게만 BossIntroEvent(bossId)를 쏜다(저장 hints.bossIntroSeen).
-- 카드 = 그림(작은 아레나 도식 - 보스 · 나 · 안전한 곳) + 제목 + 한 줄(BossData 보스의 intro). 폰에서도 읽히게 한 줄은 본문 단(모바일 16) 이상 · 두 줄까지 감싼다.
-- 8초 뒤 또는 [확인]으로 닫힌다. 도식 그리기는 BossIntroCard.drawDiagram - 보스 선택 창 "기믹 도움말"이 같은 함수를 쓴다(StageRewardBand).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local Theme = require(script.Parent.ui.kit.Theme)
local BossIntroDiagram = require(script.Parent.BossIntroDiagram)

local player = Players.LocalPlayer
local SHOW_SECONDS = 8

local current = nil

-- BR1-2: 문구의 {N} = 그 보스 전멸기의 필요 수(인원에 따라 - 번개 조준경: 2 + (인원 − 1), 피뢰침 수 상한)
local function introLine(boss, memberCount)
	local intro = boss.intro
	local skill = intro.countKey and boss.skills[intro.countKey]
	if not skill then
		return intro.sub and (intro.line .. "\n" .. intro.sub) or intro.line -- BR1-3 보조 한 줄(수정 오르골)
	end
	local rodCount = 0
	for _, part in ipairs(boss.arenaKit and boss.arenaKit.parts or {}) do
		rodCount += part.tag == skill.rodTag and 1 or 0
	end
	local n = math.min(skill.requiredBase + skill.requiredPerExtra * math.max((memberCount or 1) - 1, 0), rodCount > 0 and rodCount or math.huge)
	return (intro.line:gsub("{N}", tostring(n)))
end

local function show(bossId, memberCount)
	local boss = BossData.bosses[bossId]
	local intro = boss and boss.intro
	if not intro then
		return
	end
	if current then
		current:Destroy()
	end
	Theme.recompute()
	local mobile = Theme.isMobile
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossIntroCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = false
	current = gui

	local width = mobile and 380 or 460
	local height = mobile and 178 or 160 -- BR1-2: 긴 한 줄(번개 조준경)이 폰에서 3줄까지
	if intro.sub then
		height += mobile and 44 or 30 -- BR1-3 보조 한 줄
	end
	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, mobile and 56 or 90)
	card.Size = UDim2.new(0, width, 0, height)
	card.BackgroundColor3 = Theme.color("panel")
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	Theme.corner(card, Theme.corner.panel)
	local stroke = Theme.stroke(card, "danger", 0)
	stroke.Thickness = 2

	local diagram = Instance.new("Frame")
	diagram.Name = "Diagram"
	diagram.BackgroundTransparency = 1
	diagram.Position = UDim2.new(0, 12, 0, 12)
	diagram.Size = UDim2.new(0, height - 24, 0, height - 24)
	diagram.Parent = card
	BossIntroDiagram.draw(diagram, intro.diagram)

	local textLeft = height - 12 + 8
	local title = Theme.label(card, ("%s  %s · 전멸기"):format(intro.icon, boss.displayName), "title", "danger")
	title.Name = "Title"
	title.Position = UDim2.new(0, textLeft, 0, 12)
	title.Size = UDim2.new(1, -textLeft - 12, 0, 28)
	local name = Theme.label(card, intro.title, "header", "textPrimary")
	name.Name = "Gimmick"
	name.Position = UDim2.new(0, textLeft, 0, 42)
	name.Size = UDim2.new(1, -textLeft - 12, 0, 22)
	local line = Theme.label(card, introLine(boss, memberCount), "body", "textPrimary")
	line.Name = "Line"
	line.TextWrapped = true
	line.TextTruncate = Enum.TextTruncate.None
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.Position = UDim2.new(0, textLeft, 0, 68)
	line.Size = UDim2.new(1, -textLeft - 12, 1, -68 - 40) -- 아래 [확인] 자리를 남긴다

	local ok = Instance.new("TextButton")
	ok.Name = "Close"
	ok.AnchorPoint = Vector2.new(1, 1)
	ok.Position = UDim2.new(1, -10, 1, -8)
	ok.Size = UDim2.new(0, mobile and 72 or 64, 0, mobile and 32 or 26)
	ok.BackgroundColor3 = Theme.color("slot")
	ok.Font = Theme.font
	ok.TextSize = Theme.textSize("caption")
	ok.TextColor3 = Theme.color("textPrimary")
	ok.Text = "확인"
	ok.Parent = card
	Theme.corner(ok, Theme.corner.button)
	ok.Activated:Connect(function()
		gui:Destroy()
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	card.Position = UDim2.new(0.5, 0, 0, -height)
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, mobile and 56 or 90) }):Play()
	task.delay(SHOW_SECONDS, function()
		if gui.Parent then
			gui:Destroy()
		end
		if current == gui then
			current = nil
		end
	end)
end

local event = ReplicatedStorage:WaitForChild("BossIntroEvent", 30)
if event then
	event.OnClientEvent:Connect(show)
end
