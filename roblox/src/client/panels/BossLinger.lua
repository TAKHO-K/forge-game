-- G1-4 보스맵 잔류 선택 창(server/BossLinger - Remote BossLinger · BossLingerChoice). 보스를 잡으면 열린다: [다음 스테이지] · [다시 도전] · [마을] + 남은 초.
-- 남은 초가 0이 되면 서버가 다음 스테이지로 옮긴다(클라는 세기만). 창을 닫아도 선택은 남아 있다 - HUD 대신 창을 다시 여는 방법은 G1-5 이동 제한 안내와 같이 본다.
-- kind = window(다른 창을 닫는다) · 폰에서도 버튼 높이 44 이상(Theme.buttonHeight) · 문구는 TextData.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local BossLingerPanel = {}
BossLingerPanel.id = "bossLinger"

local PANEL_SIZE = Vector2.new(420, 214) -- 스크린샷: 비활성 버튼의 이유 줄이 창 아래로 잘려 버튼 아래에 한 줄 자리를 둔다
local PAD = 12

local _ = Players.LocalPlayer
local choiceEvent = ReplicatedStorage:WaitForChild("BossLingerChoice")

local built
local state = nil -- { stage, deadline, isParty, isLeader, canNext }

local function build()
	local panel = Panel.create({
		id = BossLingerPanel.id,
		kind = "window",
		title = Text.get("linger.title"),
		size = PANEL_SIZE,
	})
	local line = Theme.label(panel.content, "", "body", "textPrimary")
	line.Name = "Line"
	line.TextWrapped = true
	line.Position = UDim2.new(0, PAD, 0, PAD)
	line.Size = UDim2.new(1, -PAD * 2, 0, 44)
	local width = math.floor((PANEL_SIZE.X - PAD * 4) / 3)
	local function make(name, key, x, kind, choice)
		return Button.build({
			parent = panel.content, name = name, text = Text.get(key), kind = kind, width = width,
			position = UDim2.new(0, x, 1, -(Theme.buttonHeight + PAD + Theme.textSize("caption") + 6)),
			onActivated = function()
				choiceEvent:FireServer(choice)
			end,
		})
	end
	built = {
		panel = panel, line = line,
		next = make("NextButton", "linger.next", PAD, "primary", "next"),
		retry = make("RetryButton", "linger.retry", PAD * 2 + width, "secondary", "retry"),
		town = make("TownButton", "linger.town", PAD * 3 + width * 2, "secondary", "town"),
	}
end

local function render()
	if not built or not state then
		return
	end
	local seconds = math.max(0, math.ceil(state.deadline - os.clock()))
	built.line.Text = Text.get(state.canNext and "linger.line" or "linger.lineNoNext", { stage = state.stage, next = state.stage + 1, seconds = seconds })
	built.next.setEnabled(state.canNext, state.canNext and nil or Text.get("linger.noNextReason"))
	local retryOk = not state.isParty or state.isLeader
	built.retry.setText(Text.get(state.isParty and "linger.retryVote" or "linger.retry"))
	built.retry.setEnabled(retryOk, retryOk and nil or Text.get("linger.leaderOnly"))
end

-- UI-1 3단계 F 잔류 막대(08 v5-auto-boss §9 · F v2 0절 2): 보스 바 자리(위 가운데 · (600, 120) · 720) · 초상 원 88 + "{보스} 처치" + "보상은 가방에 넣었어요"(실제 동작 = 보스 장비 가방 직행) ·
--   [여기 더 있기](보조 - 막대만 닫음) [다음 스테이지] [다시 도전](보조) [마을로](노랑) · 카운트다운 없음 · 서버 상한(lingerSeconds = 90 · 안 고르면 다음 스테이지) = 고정 문구 한 줄. 스위치 UiV2Flags.boss = false → 옛 창.
local v6 = nil
local function showV6(payload)
	local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
	local BossPortrait = require(script.Parent.Parent.ui.v2.BossPortrait)
	local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
	local PD = require(ReplicatedStorage.Shared.data.BossPortraitData)
	local phone = Theme.isMobile
	if v6 then
		v6.gui:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossLingerV6"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.DisplayOrder = 120
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	local view = workspace.CurrentCamera.ViewportSize
	local m = HudPlace.scale(view.X, view.Y, phone)
	local W, H = phone and 520 or 720, phone and 150 or 210
	local bar = Instance.new("Frame")
	bar.Name = "LingerBar"
	bar.BackgroundColor3 = Color3.fromHex(PD.firstMeet.bg)
	bar.BackgroundTransparency = PD.firstMeet.bgTransparency
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Size = UDim2.fromOffset(W, H)
	bar.Position = UDim2.new(0.5, 0, 0, HudPlace.topY(phone and 62 or 120, 0, 0, m, phone and HudPlace.base.phone or HudPlace.base.pc))
	bar.Parent = gui
	local sc = Instance.new("UIScale")
	sc.Scale = m
	sc.Parent = bar
	UiKit.corner(bar, 16)
	local color = BossPortrait.color(payload.bossId)
	local st = Instance.new("UIStroke")
	st.Color = Color3.fromHex(PD.firstMeet.stroke)
	st.Thickness = 3
	st.Parent = bar
	local top = Instance.new("Frame")
	top.BorderSizePixel = 0
	top.BackgroundColor3 = color
	top.Size = UDim2.new(1, 0, 0, PD.firstMeet.topLine)
	top.Parent = bar
	UiKit.corner(top, 16)
	local ps = phone and PD.size.linger.phone or PD.size.linger.pc
	local portrait = BossPortrait.make(bar, payload.bossId, ps)
	portrait.Position = UDim2.fromOffset(16, 18)
	local x = ps + 30
	local title = UiKit.label(bar, Text.get("ui1.linger.title", { boss = Text.name(payload.bossName or "") }), "heading", "text.primary", { name = "Title", font = "korean" })
	title.Position, title.Size = UDim2.fromOffset(x, 16), UDim2.new(1, -(x + 16), 0, phone and 26 or 36)
	-- UI-1b 3절 9: 숫자 없는 고정 문구 한 줄(서버 상한 lingerSeconds는 그대로)
	local line = UiKit.label(bar, Text.get("ui1.linger.reward") .. "\n" .. Text.get("ui1b.linger.auto"), "caption", "text.secondary", { name = "Line", font = "korean", wrap = true })
	line.Position, line.Size = UDim2.fromOffset(x, phone and 44 or 56), UDim2.new(1, -(x + 16), 0, phone and 40 or 48)
	local bh = phone and 44 or 52
	local defs = {
		{ key = "ui1.linger.stay", kind = "secondary", w = phone and 108 or 150, act = function()
			gui.Enabled = false -- 막대만 닫음(서버 선택은 그대로 · 상한 = 고정 문구)
		end },
		{ key = "ui1.linger.next", kind = "secondary", w = phone and 108 or 150, choice = "next", enabled = payload.canNext ~= false },
		{ key = payload.isParty and "linger.retryVote" or "ui1.linger.retry", kind = "secondary", w = phone and 108 or 150, choice = "retry", enabled = not payload.isParty or payload.isLeader },
		{ key = "ui1.linger.town", kind = "primary", w = phone and 108 or 200, choice = "town" },
	}
	local bx = 16
	for i, d in ipairs(defs) do
		local b = UiKit.button({ kind = d.kind, text = Text.get(d.key), parent = bar, name = "Linger" .. i, textSize = "caption", padX = 8, align = Enum.TextXAlignment.Center, onActivated = function()
			if d.choice then
				choiceEvent:FireServer(d.choice)
			elseif d.act then
				d.act()
			end
		end })
		b.root.Position = UDim2.new(0, bx, 1, -(bh + 12))
		b.root.Size = UDim2.fromOffset(d.w, bh)
		if d.enabled == false then
			b.setEnabled(false)
		end
		bx += d.w + 8
	end
	v6 = { gui = gui }
end

function BossLingerPanel.show(payload)
	if require(ReplicatedStorage.Shared.data.UiV2Flags).boss then
		state = { stage = payload.stage, deadline = os.clock() + (payload.seconds or 90), isParty = payload.isParty == true, isLeader = payload.isLeader == true, canNext = payload.canNext ~= false }
		showV6(payload)
		return
	end
	if not built then
		build()
	end
	state = {
		stage = payload.stage, deadline = os.clock() + (payload.seconds or 90),
		isParty = payload.isParty == true, isLeader = payload.isLeader == true, canNext = payload.canNext ~= false,
	}
	UIManager.open(BossLingerPanel.id)
	render()
end

function BossLingerPanel.hide()
	state = nil
	if v6 then
		v6.gui:Destroy()
		v6 = nil
	end
	if built and UIManager.isOpen(BossLingerPanel.id) then
		UIManager.close(BossLingerPanel.id)
	end
end

function BossLingerPanel.debugState()
	return { built = built, state = state, open = UIManager.isOpen(BossLingerPanel.id) }
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc >= 0.25 and state and UIManager.isOpen(BossLingerPanel.id) then
		acc = 0
		render()
	end
end)

return BossLingerPanel
