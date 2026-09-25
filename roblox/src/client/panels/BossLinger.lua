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

function BossLingerPanel.show(payload)
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
