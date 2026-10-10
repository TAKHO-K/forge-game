-- UI-1 1단계 내 상태 아이콘 줄(00 v8 §4 · 02 v6 §6): 내 체력바 바로 위 한 줄 · PC 36(최대 7 + "+n") · 폰 30(최대 5) · 누르면 설명 창(PC 다시 누르면 닫힘 · 폰 4초).
--   데이터 = StatusIconData.icons(src · trapKinds) + BuffUpdate(서버 BuffState) · 자리 = UiLayoutData.hud.v6 statusRow(HudPlace) · 스위치 UiV2Flags.status(끄면 옛 BuffHud).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Flags = require(ReplicatedStorage.Shared.data.UiV2Flags)
if not Flags.status then
	return
end
local StatusIconData = require(ReplicatedStorage.Shared.data.StatusIconData)
local HudPlace = require(ReplicatedStorage.Shared.HudPlace)
local V6 = require(ReplicatedStorage.Shared.data.UiLayoutData).hud.v6
local client = script.Parent.Parent
local Theme = require(client.ui.kit.Theme)
local UiParts = require(client.ui.v2.UiParts)

local player = Players.LocalPlayer
local buffs = {} -- buffId → { endsAt(서버 시각) | nil, total, charges }

local gui = Instance.new("ScreenGui")
gui.Name = "StatusHudGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local phone = Theme.isMobile
local spec = phone and V6.phone.statusRow or V6.pc.statusRow
local holder = Instance.new("Frame")
holder.Name = "StatusRowHolder"
holder.BackgroundTransparency = 1
holder.Size = UDim2.fromOffset(spec[3] + 200, spec[4])
holder.Parent = gui
local scale = Instance.new("UIScale")
scale.Parent = holder
local row = UiParts.statusRow({ parent = holder, place = "row", tappable = true, name = "MyStatus", info = function(id)
	return UiParts.readStatus(id, { player = player, character = player.Character, buffs = buffs }, "player")
end })

local function place()
	local view = workspace.CurrentCamera.ViewportSize
	local m = HudPlace.scale(view.X, view.Y, phone)
	local ax, ox, ay, oy = HudPlace.udim(spec, spec.anchor, m, phone)
	holder.Position = UDim2.new(ax, ox, ay, oy)
	scale.Scale = m
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(place)
place()

require(client.UIManager).changed:Connect(function(_, isOpen)
	if isOpen then
		UiParts.closeTip() -- 창이 열리면 설명 창 닫기
	end
end)

ReplicatedStorage:WaitForChild("BuffUpdate").OnClientEvent:Connect(function(buffId, data)
	if not data or not data.active then
		buffs[buffId] = nil
		return
	end
	local now = workspace:GetServerTimeNow()
	local old = buffs[buffId]
	local endsAt = data.remainingSeconds and (now + data.remainingSeconds) or nil
	buffs[buffId] = {
		endsAt = endsAt,
		total = (old and old.endsAt and endsAt and endsAt <= old.endsAt + 0.05) and old.total or data.remainingSeconds, -- 갱신(새로 걸림) = 새 전체 시간
		charges = data.chargesRemaining,
	}
end)

local ids = {}
for id, def in pairs(StatusIconData.icons) do
	if not def.unused then
		table.insert(ids, id)
	end
end
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then
		return
	end
	acc = 0
	local now = workspace:GetServerTimeNow()
	for id, b in pairs(buffs) do
		if b.endsAt and b.endsAt <= now then
			buffs[id] = nil
		end
	end
	local ctx = { player = player, character = player.Character, buffs = buffs }
	local list = {}
	for _, id in ipairs(ids) do
		local st = UiParts.readStatus(id, ctx, "player")
		if st then
			st.id = id
			table.insert(list, st)
		end
	end
	row.update(list)
	gui.Enabled = player:GetAttribute("InMainMenu") ~= true
end)

-- Studio 촬영 · 점검 훅: Player Attribute DebugUi1 = "ct:break" | "ct:dodge" | "banner:rift" | "banner:golden" | "gauge"(A 부품 표본 창)
if RunService:IsStudio() then
	player:GetAttributeChangedSignal("DebugUi1"):Connect(function()
		local v = player:GetAttribute("DebugUi1")
		if type(v) ~= "string" then
			return
		end
		local kind, arg = v:match("^(%w+):?(.*)$")
		if kind == "ct" then
			UiParts.combatText(arg)
		elseif kind == "banner" then
			local Text = require(ReplicatedStorage.Shared.Text)
			UiParts.banner({ kind = arg, title = Text.get("ui1.banner." .. arg .. ".title"), line = Text.get("ui1.banner." .. arg .. ".line", { zone = "tier2", reward = "+20%" }) })
		elseif kind == "gauge" then
			local g = gui:FindFirstChild("GaugeSample")
			if g then
				g:Destroy()
				return
			end
			g = Instance.new("Frame")
			g.Name = "GaugeSample"
			g.BackgroundTransparency = 1
			g.Position = UDim2.fromOffset(40, 140)
			g.Size = UDim2.fromOffset(420, 200)
			g.Parent = gui
			local D = require(ReplicatedStorage.Shared.data.UiPartsData)
			local list = {}
			for i, key in ipairs({ "exp", "ember", "serverGoal", "contribution" }) do
				list[i] = UiParts.gauge(g, { w = 360, h = 18, color = D.gaugeColors[key], position = UDim2.fromOffset(20, 20 + (i - 1) * 40), value = 0.2 })
			end
			task.spawn(function()
				task.wait(0.5)
				for i, gg in ipairs(list) do
					gg.set(0.25 + i * 0.18)
				end
			end)
		end
	end)
end
