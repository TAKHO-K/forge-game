-- QUEUE-UI2 UI2-4 잠긴 스킬 칸(02_hud/v5 "잠긴 스킬 칸 말풍선"): 잠김 = SkillIconData.unlockRebirth[칸] > 지금 환생 횟수(RebirthCount) - 칸 툴팁(hud/SkillTooltip)과 같은 데이터.
--   표시 = 자물쇠 + "환생 N"(폰 큰 글자 = 숫자 N만) · PC 마우스 올림 / 폰 누름 = "환생 N에서 열림" 말풍선(1.5초 · 마우스 나가면 닫힘) · 누름 = 흔들림만.
--   지금 데이터 = 전부 0(Q · E · R · T 처음부터 열림 · 서버 SkillServer도 환생 조건 없음) → 잠긴 칸 0개. 값이 생기면 이 스크립트가 그 칸을 덮는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HudData = require(ReplicatedStorage.Shared.data.HudData)
if not HudData.menuV5 then
	return
end
local SkillIconData = require(ReplicatedStorage.Shared.data.SkillIconData)
local Layout = require(ReplicatedStorage.Shared.data.UiLayoutData).hud
local Text = require(ReplicatedStorage.Shared.Text)
local client = script.Parent.Parent
local UiKit = require(client.ui.v2.UiKit)

local player = Players.LocalPlayer
local covers = {}

local function slotFrame(id)
	local gui = player.PlayerGui:FindFirstChild("SkillSlotsGui")
	if not gui then
		return nil
	end
	if id == "t" then
		return gui:FindFirstChild("UltButton", true)
	end
	return gui:FindFirstChild("Slot_" .. id, true)
end

local function bubble(slot, n)
	local old = slot:FindFirstChild("LockBubble")
	if old then
		old:Destroy()
	end
	local B = Layout.phone.lockedBubble
	local b = UiKit.label(slot, Text.get("hud.skill.lockedAt", { n = tostring(n) }), "caption", "text.primary", { name = "LockBubble", align = Enum.TextXAlignment.Center, font = "korean" })
	b.BackgroundTransparency = 0
	b.BackgroundColor3 = UiKit.color("bg.deep")
	b.AnchorPoint = Vector2.new(0.5, 1)
	b.Position = UDim2.new(0.5, 0, 0, -8)
	b.Size = UDim2.fromOffset(B.w, B.h)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.ZIndex = 50
	UiKit.corner(b, 8)
	UiKit.stroke(b, "title.sub", 2) -- 00 spec 말풍선 테두리 #FFE7A3
	task.delay(B.seconds, function()
		if b.Parent then
			b:Destroy()
		end
	end)
	return b
end

local function cover(id, slot, n)
	local c = covers[id]
	if c and c.Parent == slot then
		c.Visible = n ~= nil
		if n then
			c:FindFirstChild("Num").Text = (UiKit.textStep() ~= "normal") and tostring(n) or Text.get("hud.skill.lockedShort", { n = tostring(n) })
		end
		return
	end
	if not n then
		return
	end
	c = Instance.new("TextButton") -- 덮개(누름 = 흔들림 + 말풍선 · 발동 없음 - 밑 칸 입력을 가로챈다)
	c.Name = "LockCover"
	c.Text = ""
	c.AutoButtonColor = false
	c.BackgroundColor3 = UiKit.color("panel.locked")
	c.BackgroundTransparency = 0.2
	c.Size = UDim2.fromScale(1, 1)
	c.ZIndex = 40
	UiKit.corner(c, 10)
	local lock = UiKit.icon(c, "lock", 22, { center = true })
	lock.Position = UDim2.fromScale(0.5, 0.38)
	lock.ZIndex = 41
	local num = UiKit.label(c, "", "micro", "text.secondary", { name = "Num", align = Enum.TextXAlignment.Center, font = "korean" })
	num.Position = UDim2.fromScale(0, 0.62)
	num.Size = UDim2.fromScale(1, 0.34)
	num.ZIndex = 41
	c.Parent = slot
	covers[id] = c
	local ctl = UiKit.attachPress(c, {})
	ctl.setEnabled(false) -- 비활성 = 누르면 흔들림만
	c.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			bubble(slot, c:GetAttribute("Need"))
		end
	end)
	c.MouseEnter:Connect(function()
		if UserInputService.MouseEnabled and not UserInputService.TouchEnabled then
			bubble(slot, c:GetAttribute("Need"))
		end
	end)
	c.MouseLeave:Connect(function()
		local b = slot:FindFirstChild("LockBubble")
		if b then
			b:Destroy()
		end
	end)
	cover(id, slot, n)
end

local function refresh()
	local rebirth = player:GetAttribute("RebirthCount") or 0
	for _, id in ipairs({ "q", "e", "r", "t" }) do
		local need = SkillIconData.unlockRebirth[id] or 0
		local slot = slotFrame(id)
		if slot then
			local n = need > rebirth and need or nil
			cover(id, slot, n)
			if covers[id] then
				covers[id]:SetAttribute("Need", n)
			end
		end
	end
end

for _, name in ipairs({ "RebirthCount", "ClassId", "UiTextScale" }) do
	player:GetAttributeChangedSignal(name):Connect(refresh)
end
task.spawn(function()
	player.PlayerGui:WaitForChild("SkillSlotsGui", 60)
	task.wait(1)
	refresh()
end)
