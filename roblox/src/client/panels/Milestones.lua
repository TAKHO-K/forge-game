-- 성장 보상 창(P2.5b D2 - 환생 후 레벨 마일스톤). 달성 토스트의 [보상 목록] · 강화대 환생 탭의 [성장 보상]이 연다.
--   ① 지금: 환생 회차 · 레벨 · 영구 능력치(공격력 · 최대 체력 ×배율 = 스테이지 환산 +n) ② 다음 능력치 보상까지 남은 레벨 · 다음 해금까지 남은 레벨
--   ③ 해금 표(100 · 200 · 300 · 400 · 500 - 받음 / 남은 레벨 / 예약) ④ 회차별 받은 능력치 마일스톤.
-- 값은 서버(MilestoneFetch → PlayerProfile.getMilestoneSummary)에서 받고, 규칙 계산(다음 레벨 · 배율)은 shared/Milestone을 그대로 쓴다. kind = window · 본문은 스크롤(폰에서도 글씨 실효 12 이상).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local Milestone = require(ReplicatedStorage.Shared.Milestone)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UIManager = require(script.Parent.Parent.UIManager)

local MilestonesPanel = {}
MilestonesPanel.id = "milestones"

local PANEL_SIZE = Vector2.new(560, 420)
local PAD = 12

local player = Players.LocalPlayer
local fetchRemote = ReplicatedStorage:WaitForChild("MilestoneFetch")

local built
local summary -- 서버 요약(없으면 Attribute에서 만든 임시 값)

local function build()
	local panel = Panel.create({
		id = MilestonesPanel.id,
		kind = "window",
		title = "성장 보상 - 환생 후 레벨 마일스톤",
		size = PANEL_SIZE,
		help = ("첫 환생부터, 한 회차 안에서 레벨 %d마다 영구 능력치(%s - 스테이지 %.1f칸 몫)를 받습니다. 환생해도 사라지지 않고 회차마다 다시 받습니다.\n레벨 %d마다 시스템 해금이 하나씩 열립니다(계정 공유 · 한 번만)."):format(
			MilestoneData.statInterval, Milestone.statText(), MilestoneData.statStagesPerMilestone, MilestoneData.unlockInterval),
	})
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Body"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.new(1, 0, 1, 0)
	scroll.ScrollBarThickness = 4
	scroll.ScrollBarImageColor3 = Theme.color("rim")
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.Parent = panel.content
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, PAD)
	pad.PaddingRight = UDim.new(0, PAD + 4)
	pad.PaddingTop = UDim.new(0, PAD)
	pad.PaddingBottom = UDim.new(0, PAD)
	pad.Parent = scroll
	built = { panel = panel, scroll = scroll }
end

local order = 0
local function line(text, sizeName, colorName, name)
	order += 1
	local label = Theme.label(built.scroll, text, sizeName, colorName)
	label.Name = name or ("Line" .. order)
	label.LayoutOrder = order
	label.TextWrapped = true
	label.Size = UDim2.new(1, 0, 0, Theme.textSize(sizeName) + 8)
	return label
end

-- 표 한 줄: 왼쪽 레벨 · 가운데 이름 · 오른쪽 상태.
local function row(name, levelText, nameText, stateText, stateColor, dim)
	order += 1
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.LayoutOrder = order
	frame.BackgroundColor3 = Theme.color("slot")
	frame.BackgroundTransparency = Theme.colors.slotTransparency
	frame.Size = UDim2.new(1, 0, 0, Theme.textSize("body") + 14)
	frame.Parent = built.scroll
	Theme.corner(frame, Theme.corner.chip)
	local levelLabel = Theme.label(frame, levelText, "body", dim and "textTertiary" or "textPrimary")
	levelLabel.Position = UDim2.new(0, 10, 0, 0)
	levelLabel.Size = UDim2.new(0, 80, 1, 0)
	local nameLabel = Theme.label(frame, nameText, "body", dim and "textTertiary" or "textPrimary")
	nameLabel.Position = UDim2.new(0, 92, 0, 0)
	nameLabel.Size = UDim2.new(0.55, -92, 1, 0)
	local stateLabel = Theme.label(frame, stateText, "caption", stateColor or "textSecondary")
	stateLabel.TextXAlignment = Enum.TextXAlignment.Right
	stateLabel.AnchorPoint = Vector2.new(1, 0)
	stateLabel.Position = UDim2.new(1, -10, 0, 0)
	stateLabel.Size = UDim2.new(0.45, -10, 1, 0)
	return frame
end

local function localSummary()
	local count = player:GetAttribute("MilestoneStatCount") or 0
	return {
		rebirthCount = player:GetAttribute("RebirthCount") or 0,
		level = player:GetAttribute("CharacterLevel") or 1,
		cycles = {},
		statCount = count,
		multiplier = Milestone.multiplier(count),
		unlockCount = player:GetAttribute("MilestoneUnlockCount") or 0,
	}
end

function MilestonesPanel.render()
	if not built or not UIManager.isOpen(MilestonesPanel.id) then
		return
	end
	for _, child in ipairs(built.scroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	order = 0
	local data = summary or localSummary()
	local rebirthCount, level = data.rebirthCount or 0, data.level or 1

	line(("환생 %d회 · 지금 레벨 %d"):format(rebirthCount, level), "header", "textPrimary", "Heading")
	line(("영구 능력치: %s ×%.3f(마일스톤 %d회 = 스테이지 환산 +%.1f)"):format(Milestone.statText(), data.multiplier or 1, data.statCount or 0, Milestone.stageEquivalent(data.statCount or 0)), "body", "success", "StatTotal")
	if rebirthCount < 1 then
		line("첫 환생을 하면 이 회차부터 보상이 열립니다", "body", "textSecondary", "Locked")
	else
		local nextStat = Milestone.nextStatLevel(level)
		line(("다음 능력치 보상: Lv.%d - 남은 레벨 %d"):format(nextStat, nextStat - level), "body", "textPrimary", "NextStat")
	end
	local unlockCount = data.unlockCount or 0
	local nextUnlock = MilestoneData.unlocks[unlockCount + 1]
	if nextUnlock then
		local at = Milestone.unlockLevel(unlockCount + 1)
		line(("다음 해금: %s - 환생 뒤 Lv.%d%s"):format(nextUnlock.name, at, (rebirthCount >= 1 and level < at) and (" · 남은 레벨 %d"):format(at - level) or ""), "body", "textPrimary", "NextUnlock")
	else
		line("해금은 전부 받았습니다", "body", "textSecondary", "NextUnlock")
	end

	line(("시스템 해금(환생 뒤 레벨 %d마다 · 계정 공유)"):format(MilestoneData.unlockInterval), "caption", "textSecondary", "UnlockHeader")
	for index, entry in ipairs(MilestoneData.unlocks) do
		local at = Milestone.unlockLevel(index)
		local got = index <= unlockCount
		local stateText, stateColor
		if got then
			stateText, stateColor = entry.reserved and "받음 · 그 시스템이 생기면 적용" or "받음", "success"
		elseif rebirthCount >= 1 and level < at then
			stateText = ("남은 레벨 %d"):format(at - level)
		else
			stateText = "환생 뒤 열림"
		end
		row("Unlock_" .. entry.id, ("Lv.%d"):format(at), entry.name, stateText, stateColor, not got)
	end

	line(("회차별 능력치 마일스톤(레벨 %d마다)"):format(MilestoneData.statInterval), "caption", "textSecondary", "CycleHeader")
	local shown = 0
	local lastCycle = math.max(rebirthCount, 0)
	for key in pairs(data.cycles or {}) do
		lastCycle = math.max(lastCycle, tonumber(key) or 0) -- 기록이 있는 회차는 전부 보인다(개발 도구로 회차를 되돌린 계정 등)
	end
	for cycle = 1, lastCycle do
		local claimed = (data.cycles and data.cycles[tostring(cycle)]) or 0
		local times = math.floor(claimed / MilestoneData.statInterval)
		local current = cycle == rebirthCount
		row("Cycle_" .. cycle, ("%d회차"):format(cycle), current and "지금 회차" or "지난 회차", ("Lv.%d까지 %d회"):format(claimed, times), times > 0 and "success" or nil, times == 0)
		shown += 1
	end
	if shown == 0 then
		line("아직 받은 능력치 마일스톤이 없습니다", "body", "textTertiary", "NoCycle")
	end
end

function MilestonesPanel.open()
	if not built then
		build()
	end
	summary = nil
	if not UIManager.open(MilestonesPanel.id) then
		return false
	end
	MilestonesPanel.render()
	task.spawn(function()
		local ok, result = pcall(function()
			return fetchRemote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			summary = result
			MilestonesPanel.render()
		end
	end)
	return true
end

-- 점검용(P25b(UI) · 스크린샷): 서버 요약 대신 합성 요약으로 연다.
function MilestonesPanel.debugOpen(fakeSummary)
	if not built then
		build()
	end
	summary = fakeSummary
	if not UIManager.isOpen(MilestonesPanel.id) and not UIManager.open(MilestonesPanel.id) then
		return false
	end
	MilestonesPanel.render()
	return true
end

function MilestonesPanel.debugState()
	return { open = UIManager.isOpen(MilestonesPanel.id), refs = built, summary = summary }
end

return MilestonesPanel
