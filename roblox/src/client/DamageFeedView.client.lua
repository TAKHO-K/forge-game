-- W2-3 몬스터 피해 숫자 프로토타입(꺼짐 - DamageNumberData.enabled). 서버 확정 이벤트(DamageFeed)만 그린다 - 클라 예측 숫자 없음.
--   ① 같은 대상 · 같은 공격자 mergeSeconds 안의 피해 = 한 숫자로 합친다(떠 있는 숫자를 키운다)
--   ② 동시 상한 maxShown · 풀링(BillboardGui 재사용 - 매번 Instance.new 안 함)
--   ③ 남이 준 피해 = 작게(others.scale) 또는 끄기(others.mode)
--   ④ 자리 = 서버 적중 지점(hitPosition) 위 - 대상이 사라져도 제자리에서 끝난다
--   ⑤ 시각 = 이벤트 도착 순간(지연 감안 규칙은 보고서 W2-3 제안 - U1) · 알파벳 단위 = NumberFormat
-- 최종 스타일(글꼴 · 색 · 움직임)은 U1. 옛 client/DamageNumbers는 그대로(켜는 시점에 옛 것을 끈다).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local D = require(ReplicatedStorage.Shared.data.DamageNumberData)
local NumberFormat = require(ReplicatedStorage.Shared.NumberFormat)

if not D.enabled then
	return
end

local player = Players.LocalPlayer
local event = ReplicatedStorage:WaitForChild("DamageFeed")

local anchorFolder = Instance.new("Folder")
anchorFolder.Name = "DamageFeedAnchors"
anchorFolder.Parent = Workspace

local KIND_COLOR = {
	normal = Color3.fromRGB(255, 255, 255),
	heavy = Color3.fromRGB(230, 242, 255), -- 궤적 기본색 계열(강공격)
	skill = Color3.fromRGB(150, 220, 255),
}
local CRIT_COLOR = Color3.fromRGB(255, 214, 90)

-- 풀: { anchor(Part) · gui · label · entry }
local slots, nextSlot = {}, 0
local function newSlot()
	local anchor = Instance.new("Part")
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency, anchor.Size = 1, Vector3.one * 0.1
	anchor.Parent = anchorFolder
	local gui = Instance.new("BillboardGui")
	gui.AlwaysOnTop, gui.Enabled = true, false
	gui.Size = UDim2.new(0, 160, 0, 40)
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	return { anchor = anchor, gui = gui, label = label }
end
for i = 1, D.maxShown do
	slots[i] = newSlot()
end

local open = {} -- [target][attackerUserId] = slot(합치는 중)
local function takeSlot()
	nextSlot = nextSlot % D.maxShown + 1
	local slot = slots[nextSlot]
	if slot.entry and open[slot.entry.target] then
		open[slot.entry.target][slot.entry.attacker] = nil
	end
	return slot
end

local function paint(slot)
	local e = slot.entry
	slot.label.Text = NumberFormat.format(e.amount)
	slot.label.TextColor3 = e.isCrit and CRIT_COLOR or KIND_COLOR[e.kind] or KIND_COLOR.normal
	local px = D.minePx * (e.mine and 1 or D.others.scale) * (e.kind == "heavy" and 1.25 or 1)
	slot.label.TextSize = math.floor(px)
	slot.label.TextTransparency = e.mine and 0 or D.others.transparency
end

local function show(target, hitPosition, amount, kind, attackerUserId, isCrit)
	local mine = attackerUserId == player.UserId
	if not mine and D.others.mode == "off" then
		return
	end
	local now = os.clock()
	open[target] = open[target] or {}
	local slot = open[target][attackerUserId]
	if slot and slot.entry and now - slot.entry.firstAt <= D.mergeSeconds then
		slot.entry.amount += amount -- ① 합치기
		slot.entry.isCrit = slot.entry.isCrit or isCrit
		paint(slot)
		return
	end
	slot = takeSlot()
	slot.entry = { target = target, attacker = attackerUserId, amount = amount, kind = kind, isCrit = isCrit, mine = mine, firstAt = now, base = hitPosition + Vector3.new(0, 2.6, 0) }
	open[target][attackerUserId] = slot
	slot.anchor.Position = slot.entry.base
	slot.gui.Enabled = true
	paint(slot)
end

event.OnClientEvent:Connect(function(target, hitPosition, amount, kind, attackerUserId, isCrit)
	if typeof(hitPosition) ~= "Vector3" or type(amount) ~= "number" then
		return
	end
	show(target, hitPosition, amount, kind, attackerUserId, isCrit)
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, slot in ipairs(slots) do
		local e = slot.entry
		if e then
			local t = (now - e.firstAt) / D.lifeSeconds
			if t >= 1 then
				slot.gui.Enabled = false
				if open[e.target] then
					open[e.target][e.attacker] = nil
					if next(open[e.target]) == nil then
						open[e.target] = nil -- 몬스터 참조가 남지 않게(리뷰)
					end
				end
				slot.entry = nil
			else
				slot.anchor.Position = e.base + Vector3.new(0, D.riseStuds * t, 0)
				slot.label.TextTransparency = math.max(slot.label.TextTransparency, t > 0.6 and (t - 0.6) / 0.4 or 0)
			end
		end
	end
end)
