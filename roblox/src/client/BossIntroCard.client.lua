-- BR1-2 첫 만남 전멸기 카드(docs/design/boss-br1-2.md §2). 서버 BossEncounter가 그 보스를 처음 만난 사람에게만 BossIntroEvent(bossId, memberCount)를 쏜다(저장 hints.bossIntroSeen).
-- QUEUE-ALL2 P2(ref 18): 카드 = 제목(보스 · 기믹) + 그림 3컷(① 보이는 것 → ② 할 일 → ③ 실패하면 - 실패 숫자는 BossData) + 40자 이하 한 줄 + [도움말] [확인].
--   그림 · 한 줄은 BossIntroDiagram.buildCard(도움말 창 "보스 기믹"이 같은 함수) · 컷 목록 · 문구 키 = HelpCodexData.gimmickCards.
--   폰(ScreenGui 800 × 302 · 667 × 317)에서도 화면 안: 높이 = 12 + 제목 28 + 6 + 카드(컷 96 + 말 + 한 줄) + 8 + 버튼 44 + 10 ≈ 264.
-- 8초 뒤 또는 [확인]으로 닫힌다. [도움말] = 도움말 창의 그 보스 기믹 항목(HelpPanel.open).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local HelpCodexData = require(ReplicatedStorage.Shared.data.HelpCodexData)
local Text = require(ReplicatedStorage.Shared.Text)
local Theme = require(script.Parent.ui.kit.Theme)
local Button = require(script.Parent.ui.kit.Button)
local BossIntroDiagram = require(script.Parent.BossIntroDiagram)

local player = Players.LocalPlayer
local SHOW_SECONDS = 8
local MAX_WIDTH = 640
local PAD = 12
local TITLE_H = 28

local current = nil

local function close(gui)
	if gui.Parent then
		gui:Destroy()
	end
	if current == gui then
		current = nil
	end
end

local function show(bossId, memberCount)
	local boss = BossData.bosses[bossId]
	local cardData = HelpCodexData.gimmickCards[bossId]
	if not (boss and cardData) then
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

	local camera = workspace.CurrentCamera
	local screenW = camera and camera.ViewportSize.X or MAX_WIDTH
	local width = math.min(MAX_WIDTH, screenW - 16)
	-- UI-1 3단계 F 첫 만남 카드(08 v5-auto-boss §8): 남색 #161A2B 96% + 테 #3A4466 3 + 윗줄 6 = 보스 대표 색 · 초상 원 56 · 제목 = 대표 색 · 노랑 [알겠어요] 200 ·
	--   빨간 테 · 빨강 제목 · 주황 [확인] 제거(보스 경고색을 일반 강조에 안 씀) · 그림 = 지금 BossIntroDiagram 도형 그대로. 스위치 UiV2Flags.boss = false → 옛 카드.
	local v6 = require(ReplicatedStorage.Shared.data.UiV2Flags).boss
	local PD = require(ReplicatedStorage.Shared.data.BossPortraitData)
	local headPx = v6 and (mobile and PD.size.firstMeet.phone or PD.size.firstMeet.pc) or 0
	if v6 then
		width = math.min(mobile and 660 or 1100, screenW - 16)
	end
	local innerW = width - PAD * 2
	local layout = BossIntroDiagram.cardLayout(innerW, mobile)
	local buttonH = Theme.buttonHeight
	local height = PAD + TITLE_H + 6 + layout.height + 8 + buttonH + 10
	local topY = mobile and 8 or 90
	if v6 then
		height += math.max(headPx - TITLE_H, 0) + 6
	end

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.new(0.5, 0, 0, topY)
	card.Size = UDim2.new(0, width, 0, height)
	card.BackgroundColor3 = Theme.color("panel")
	card.BackgroundTransparency = 0.05
	card.Parent = gui
	Theme.corner(card, Theme.corner.panel)
	local stroke = Theme.stroke(card, "danger", 0)
	stroke.Thickness = 2

	local title = Theme.label(card, Text.get("gimmick.cardTitle", { boss = boss.displayName, gimmick = Text.get(cardData.titleKey) }), "title", "danger")
	title.Name = "Title"
	title.Position = UDim2.new(0, PAD, 0, PAD)
	title.Size = UDim2.new(1, -PAD * 2, 0, TITLE_H)
	local diagramY = PAD + TITLE_H + 6
	if v6 then
		local BossPortrait = require(script.Parent.ui.v2.BossPortrait)
		local color = BossPortrait.color(bossId)
		card.BackgroundColor3 = Color3.fromHex(PD.firstMeet.bg)
		card.BackgroundTransparency = PD.firstMeet.bgTransparency
		stroke.Color = Color3.fromHex(PD.firstMeet.stroke)
		stroke.Transparency = 0
		stroke.Thickness = 3
		local topLine = Instance.new("Frame")
		topLine.Name = "TopLine"
		topLine.BorderSizePixel = 0
		topLine.BackgroundColor3 = color
		topLine.Size = UDim2.new(1, 0, 0, PD.firstMeet.topLine)
		topLine.Parent = card
		Theme.corner(topLine, Theme.corner.panel)
		local portrait = BossPortrait.make(card, bossId, headPx)
		portrait.Position = UDim2.fromOffset(PAD, PAD + 4)
		local headX = PAD + headPx + 10
		local head = Theme.label(card, Text.get("ui1.firstMeet.head", { boss = Text.name(boss.displayName) }), "caption", "textPrimary")
		head.Name = "Head"
		head.TextColor3 = color
		head.Position = UDim2.new(0, headX, 0, PAD + 2)
		head.Size = UDim2.new(0.5, 0, 0, 18)
		title.Text = Text.get(cardData.titleKey)
		title.TextColor3 = Color3.new(1, 1, 1)
		title.Position = UDim2.new(0, headX, 0, PAD + 20)
		title.Size = UDim2.new(1, -(headX + PAD), 0, TITLE_H)
		local once = Theme.label(card, Text.get("ui1.firstMeet.once"), "caption", "textSecondary")
		once.Name = "Once"
		once.TextXAlignment = Enum.TextXAlignment.Right
		once.AnchorPoint = Vector2.new(1, 0)
		once.Position = UDim2.new(1, -PAD, 0, PAD + 2)
		once.Size = UDim2.new(0.5, -PAD, 0, 18)
		diagramY = PAD + math.max(headPx, TITLE_H + 20) + 10
	end

	BossIntroDiagram.buildCard(card, bossId, {
		width = innerW,
		position = UDim2.new(0, PAD, 0, diagramY),
		mobile = mobile,
		memberCount = memberCount,
	})

	local okW = 96
	if v6 then -- 노랑 [알겠어요] 200(폰 = 칸 폭에 맞춤)
		okW = mobile and 140 or 200
		local UiKit = require(script.Parent.ui.v2.UiKit)
		local ok = UiKit.button({ kind = "primary", text = Text.get("ui1.firstMeet.ok"), parent = card, name = "Close", onActivated = function()
			close(gui)
		end })
		ok.root.AnchorPoint = Vector2.new(1, 1)
		ok.root.Position = UDim2.new(1, -PAD, 1, -10)
		ok.root.Size = UDim2.fromOffset(okW, buttonH)
	else
		Button.build({
			parent = card,
			name = "Close",
			kind = "primary",
			text = Text.get("gimmick.ok"),
			width = 96,
			anchorPoint = Vector2.new(1, 1),
			position = UDim2.new(1, -PAD, 1, -10),
			onActivated = function()
				close(gui)
			end,
		})
	end
	Button.build({
		parent = card,
		name = "Help",
		kind = "secondary",
		text = Text.get("help.open"),
		width = 96,
		anchorPoint = Vector2.new(1, 1),
		position = UDim2.new(1, -(PAD + okW + 8), 1, -10),
		onActivated = function()
			close(gui)
			require(script.Parent.panels.Help).open("bossGimmick", bossId)
		end,
	})

	gui.Parent = player:WaitForChild("PlayerGui")
	card.Position = UDim2.new(0.5, 0, 0, -height)
	TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, topY) }):Play()
	task.delay(SHOW_SECONDS, function()
		close(gui)
	end)
end

local event = ReplicatedStorage:WaitForChild("BossIntroEvent", 30)
if event then
	event.OnClientEvent:Connect(show)
end
