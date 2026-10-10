-- UI-1 7b단계 보스 관문 창(08 v7-map-settings §3 · pc_03 · ph_03): 초상 · "스테이지 n · 구역 · 보스 관문" · 이름 · 추천 전투력 vs 내 전투력(낮아도 경고색 없음 · 추천 값 없으면 칸 숨김) ·
--   보상 띠(StageRewardBand.describe - 구역 선택 띠와 같은 문장 · 서버 BossRewardPreview 값) · 처음 만나는 보스 = "처음 보는 기술 안내가 나와요" · [혼자 도전] = 기존 StageMoveRequest(→ 진입 카드) ·
--   [파티 찾기] = BOSS-PARTY 전까지 비활성 + 이유 한 줄. 여는 곳 = 구역 선택 보스 칸 [도전] · 관문 앞 상호작용(F · 서버 등록과 같이) · 스위치 UiV2Flags.map.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local CombatFormula = require(ReplicatedStorage.Shared.CombatFormula)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)
local Text = require(ReplicatedStorage.Shared.Text)
local UiModel = require(ReplicatedStorage.Shared.UiModel)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local PD = require(ReplicatedStorage.Shared.data.BossPortraitData)
local L = require(ReplicatedStorage.Shared.data.UiLayoutData).bossGate.v7
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local UiKit = require(script.Parent.Parent.ui.v2.UiKit)
local BossPortrait = require(script.Parent.Parent.ui.v2.BossPortrait)
local StageRewardBand = require(script.Parent.Parent.StageRewardBand)
local UIManager = require(script.Parent.Parent.UIManager)

local BossGateWindow = {}
BossGateWindow.id = "bossGateV7"

local player = Players.LocalPlayer
local stageMoveRequest = ReplicatedStorage:WaitForChild("StageMoveRequest")
local previewRequest = ReplicatedStorage:WaitForChild("BossRewardPreviewRequest")
local previewResult = ReplicatedStorage:WaitForChild("BossRewardPreviewResult")
local built, current = nil, nil -- current = { stage, bossId, entry }

local function hex(h)
	return Color3.fromHex(h)
end
local function px(n)
	return math.floor(n * UiModel.textMul(UiKit.textStep(), UiKit.platformTextName()) + 0.5)
end
local function label(parent, text, size, color, font, align)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = UiKit.font(font or "koreanBold")
	l.TextSize = size
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextXAlignment = align or Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.RichText = true
	l.Text = text or ""
	l.Parent = parent
	return l
end
local function corner(inst, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = inst
end

-- 이 보스의 지금 스테이지: 마지막으로 깬 보스 다음 보스 스테이지부터 · 최고 + 1 이하에서 이 보스가 나오는 가장 가까운 스테이지(없으면 다음에 나오는 곳)
function BossGateWindow.stageFor(bossId, best, bestBossCleared)
	local step = BossData.stageInterval
	local cap = (best or 0) + 1
	local s = ((bestBossCleared or 0) // step + 1) * step
	for _ = 1, 200 do
		if BossRules.bossIdForStage(s) == bossId then
			return s, s <= cap
		end
		s += step
	end
	return nil, false
end

local function zoneOf(bossId)
	for _, z in ipairs(WorldMapData.zones) do
		if z.bossId == bossId then
			return z
		end
	end
	return nil
end

local function build()
	Theme.recompute()
	local phone = Theme.isMobile
	local base = phone and HudPlace.base.phone or HudPlace.base.pc
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossGateV7Gui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local dim = Instance.new("TextButton")
	dim.Name = "Dim"
	dim.Text = ""
	dim.AutoButtonColor = false
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.55
	dim.Size = UDim2.fromScale(1, 1)
	dim.Parent = gui
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromOffset(base.w, base.h)
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = root
	local function fit()
		local v = gui.AbsoluteSize
		if v.X > 1 then
			scale.Scale = math.min(v.X / base.w, v.Y / base.h)
		end
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	built = { gui = gui, root = root, phone = phone }
	UIManager.register(BossGateWindow.id, {
		kind = "window",
		screenGui = gui,
		hasCloseButton = true,
		onOpen = function()
			gui.Enabled = true
			gui.DisplayOrder = math.max(gui.DisplayOrder, L.displayOrder)
			BossGateWindow.render()
		end,
		onClose = function()
			gui.Enabled = false
		end,
	})
end

function BossGateWindow.render()
	local B = built
	if not B or not B.gui.Enabled or not current then
		return
	end
	if B.win then
		B.win:Destroy()
	end
	local phone = B.phone
	local P = phone and L.phone or L.pc
	local boss = BossData.bosses[current.bossId] or {}
	local color = hex((PD.bosses[current.bossId] or {}).color or PD.fallbackColor)
	local win = Instance.new("Frame")
	win.Name = "Window"
	win.BackgroundColor3 = hex(L.colors.window)
	win.Position = UDim2.fromOffset(P.x, P.y)
	win.Size = UDim2.fromOffset(P.w, P.h)
	win.Parent = B.root
	corner(win, phone and 14 or 18)
	local ws = Instance.new("UIStroke")
	ws.Color = hex(L.colors.stroke)
	ws.Thickness = 3
	ws.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	ws.Parent = win
	B.win = win
	UiKit.closeButton({ parent = win, name = "Close", rect = { P.w - P.close - 10, 10, P.close, P.close }, onActivated = function()
		UIManager.close(BossGateWindow.id)
	end })
	-- 왼쪽 초상 카드(대표 색 판)
	local card = Instance.new("Frame")
	card.Name = "PortraitCard"
	card.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.55)
	card.Position = UDim2.fromOffset(P.pad, P.pad)
	card.Size = UDim2.fromOffset(P.portrait, P.h - P.pad * 2)
	card.Parent = win
	corner(card, 14)
	local p = BossPortrait.make(card, current.bossId, P.portrait - 20)
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.Position = UDim2.fromScale(0.5, 0.5)
	-- 오른쪽
	local x0 = P.pad * 2 + P.portrait
	local w = P.w - x0 - P.pad - P.close - 10
	local zone = zoneOf(current.bossId)
	local y = P.pad
	local head = label(win, Text.get("ui1.gate.head", { stage = tostring(current.stage or "-"), zone = zone and zone.theme or "" }), px(phone and 12 or 16), color)
	head.Position = UDim2.fromOffset(x0, y)
	head.Size = UDim2.fromOffset(w, phone and 16 or 22)
	y += phone and 16 or 26
	local name = label(win, Text.name(boss.displayName or current.bossId), px(phone and 22 or 44), Color3.new(1, 1, 1), "korean")
	name.Position = UDim2.fromOffset(x0, y)
	name.Size = UDim2.fromOffset(w, phone and 26 or 52)
	y += phone and 30 or 60
	-- 추천 vs 내 전투력(나란히 · 낮아도 같은 색)
	local rec = current.stage and CombatFormula.enabled() and CombatFormula.displayRecommendedPower(current.stage)
	local boxW = math.floor(((P.w - x0 - P.pad) - P.gap) / 2)
	if rec then
		for i, item in ipairs({ { key = "ui1.gate.recPower", v = CombatFormula.display(rec) }, { key = "ui1.gate.myPower", v = CombatFormula.display(player:GetAttribute("CombatPower") or 0) } }) do
			local box = Instance.new("Frame")
			box.Name = i == 1 and "RecPower" or "MyPower"
			box.BackgroundColor3 = hex(L.colors.box)
			box.Position = UDim2.fromOffset(x0 + (i - 1) * (boxW + P.gap), y)
			box.Size = UDim2.fromOffset(boxW, P.powerH)
			box.Parent = win
			corner(box, 10)
			local t = label(box, Text.get(item.key), px(phone and 11 or 14), Color3.fromRGB(170, 176, 200))
			t.Position = UDim2.fromOffset(10, 4)
			t.Size = UDim2.new(1, -20, 0, phone and 14 or 18)
			local v = label(box, NumberFormat.format(item.v), px(phone and 16 or 26), Color3.new(1, 1, 1), "number")
			v.Position = UDim2.fromOffset(10, phone and 16 or 24)
			v.Size = UDim2.new(1, -20, 0, phone and 18 or 32)
		end
		y += P.powerH + P.gap
	end
	-- 보상 띠(금 판)
	local band = Instance.new("Frame")
	band.Name = "RewardBand"
	band.BackgroundColor3 = hex(L.colors.band)
	band.Position = UDim2.fromOffset(x0, y)
	band.Size = UDim2.fromOffset(P.w - x0 - P.pad, P.bandH)
	band.Parent = win
	corner(band, 10)
	local bst = Instance.new("UIStroke")
	bst.Color = hex(L.colors.bandStroke)
	bst.Parent = band
	local lines = {}
	if current.entry and current.stage then
		local d = StageRewardBand.describe(current.stage, current.entry, player:GetAttribute("RebirthCount") or 0)
		for _, r in ipairs(d.rows) do
			if r.plain and r.plain ~= "" then
				table.insert(lines, (r.head ~= "" and (r.head .. " ") or "") .. r.plain)
			end
		end
	else
		table.insert(lines, Text.get("ui1.gate.loading"))
	end
	local bt = label(band, table.concat(lines, "\n", 1, math.min(#lines, phone and 2 or 4)), px(phone and 11 or 14), hex(L.colors.bandText))
	bt.Position = UDim2.fromOffset(10, 6)
	bt.Size = UDim2.new(1, -20, 1, -12)
	bt.TextYAlignment = Enum.TextYAlignment.Top
	bt.TextTruncate = Enum.TextTruncate.AtEnd
	y += P.bandH + P.gap
	if current.firstMeet then
		local note = label(win, Text.get("ui1.gate.firstMeet"), px(phone and 11 or 15), hex(L.colors.info))
		note.Name = "FirstMeetNote"
		note.Position = UDim2.fromOffset(x0, y)
		note.Size = UDim2.fromOffset(P.w - x0 - P.pad, phone and 14 or 20)
		y += phone and 16 or 24
	end
	local party = label(win, Text.get("ui1.gate.partyHint"), px(phone and 11 or 14), Color3.fromRGB(150, 156, 180))
	party.Position = UDim2.fromOffset(x0, y)
	party.Size = UDim2.fromOffset(P.w - x0 - P.pad, phone and 14 or 18)
	-- 버튼: [파티 찾기](비활성 + 이유) [혼자 도전](노랑)
	local bw, bh = P.button[1], P.button[2]
	local by = P.h - P.pad - bh - (phone and 0 or 18)
	local solo = UiKit.button({ parent = win, kind = "primary", name = "Solo", text = Text.get("ui1.gate.solo"), align = Enum.TextXAlignment.Center,
		rect = { P.w - P.pad - bw, by, bw, bh }, onActivated = function()
			if current and current.stage and current.reachable then
				stageMoveRequest:FireServer(current.stage)
				UIManager.close(BossGateWindow.id)
			end
		end })
	solo.setEnabled(current.reachable == true)
	local partyBtn = UiKit.button({ parent = win, kind = "secondary", name = "PartyFind", text = Text.get("ui1.gate.partyFind"), align = Enum.TextXAlignment.Center,
		rect = { P.w - P.pad - bw * 2 - P.gap, by, bw, bh } })
	partyBtn.setEnabled(false)
	local reason = label(win, Text.get(current.reachable and "ui1.gate.partyReason" or "ui1.gate.notYet", { n = tostring(current.stage or 0) }), px(phone and 10 or 13), Color3.fromRGB(150, 156, 180), "koreanBold", Enum.TextXAlignment.Right)
	reason.Name = "Reason"
	reason.Position = UDim2.fromOffset(x0, by + bh + 2)
	reason.Size = UDim2.fromOffset(P.w - x0 - P.pad, phone and 0 or 16)
	reason.Visible = not phone
end

-- 열기: opts = { stage } 또는 { bossId } (+ entry = 구역 선택이 이미 받은 보상 미리보기)
function BossGateWindow.open(opts)
	local best = player:GetAttribute("InfiniteStageBest") or 1 -- 구역 선택과 같은 값(StageSelectPanel attrs)
	local bestBoss = player:GetAttribute("BestBossCleared") or 0
	local stage, bossId = opts.stage, opts.bossId
	local reachable
	if stage then
		bossId = BossRules.bossIdForStage(stage)
		reachable = stage <= best + 1
	else
		stage, reachable = BossGateWindow.stageFor(bossId, best, bestBoss)
	end
	if not bossId then
		return false
	end
	current = { stage = stage, bossId = bossId, entry = opts.entry, reachable = reachable, firstMeet = stage ~= nil and stage > bestBoss }
	if not built then
		build()
	end
	if stage and not current.entry then
		previewRequest:FireServer({ stage })
	end
	if UIManager.isOpen(BossGateWindow.id) then
		BossGateWindow.render()
		return true
	end
	return UIManager.open(BossGateWindow.id)
end

function BossGateWindow.init()
	previewResult.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or not payload.ok or not current then
			return
		end
		for _, e in ipairs(payload.entries or {}) do
			if e.stage == current.stage then
				current.entry = e
				BossGateWindow.render()
			end
		end
	end)
	-- 관문 앞 상호작용(F) = 서버가 등록하고 · 이 창이 열린다
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who == player and prompt.Name == "GateRegisterPrompt" and prompt.Parent then
			local bossId = prompt.Parent:GetAttribute("GatePrompt")
			if bossId then
				task.defer(BossGateWindow.open, { bossId = bossId })
			end
		end
	end)
end

return BossGateWindow
