-- UI-1b 1절 3(I v1 spec 0-2): 창 제목 옆 [?] = 원 36(폰 28) · 하늘 테 · 누르면 A 설명 창(InfoTip - HelpData 틀: 이름 한 단어 + "항목: 글" 줄).
--   PC = 누르면 열림 / 다시 누르면 닫힘 · 폰 = 누르면 열림 · 바깥 누르면 닫힘(InfoTip 공통) · 처음 1번 = 작은 점(설정 helpSeen에 없을 때).
--   HelpButton.attach(parent, id, props) → 버튼 · props = { position, anchor, rows(추가 줄 표 또는 함수 - 창이 넘기는 지금 값), title(제목 덮어쓰기 - 설정 줄 이름) }
--   HelpButton.besideLabel(label, id, props) = 글자 끝 바로 오른쪽(TextBounds 따라감)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Text = require(ReplicatedStorage.Shared.Text)
local HelpData = require(ReplicatedStorage.Shared.data.HelpData)
local D = require(ReplicatedStorage.Shared.data.UiLayoutData).helpButton
local UiKit = require(script.Parent.UiKit)
local InfoTip = require(script.Parent.InfoTip)

local HelpButton = {}
local player = Players.LocalPlayer

local function seenSet()
	local out = {}
	for id in tostring(player:GetAttribute("HelpSeen") or ""):gmatch("[^,]+") do
		out[id] = true
	end
	return out
end

local function markSeen(id)
	local s = seenSet()
	if s[id] or not HelpData.ids[id] then
		return
	end
	local list = {}
	for k in pairs(s) do
		table.insert(list, k)
	end
	table.insert(list, id)
	table.sort(list)
	local value = table.concat(list, ",")
	player:SetAttribute("HelpSeen", value) -- 바로 점 끔(서버 저장 뒤 같은 값이 다시 옴)
	ReplicatedStorage:WaitForChild("SettingsSave"):FireServer("helpSeen", value)
end

function HelpButton.content(id, extraRows, title)
	local e = HelpData.ids[id]
	local rows = {}
	for _, r in ipairs(e and e.rows or {}) do
		table.insert(rows, { Text.get(r[1]), Text.get(r[2]) })
	end
	for _, r in ipairs(extraRows or {}) do
		table.insert(rows, r)
	end
	return { title = title or (e and Text.get(e.title)) or "", rows = rows }
end

function HelpButton.attach(parent, id, props)
	props = props or {}
	local phone = UiKit.isPhone()
	local size = phone and D.phoneSize or D.pcSize
	local b = Instance.new("TextButton")
	b.Name = "Help_" .. id
	b.AutoButtonColor = false
	b.BackgroundColor3 = Color3.fromHex(D.bg)
	b.Size = UDim2.fromOffset(size, size)
	b.AnchorPoint = props.anchor or Vector2.new(0, 0.5)
	b.Position = props.position or UDim2.new(0, 0, 0.5, 0)
	b.Font = UiKit.font("number")
	b.Text = "?"
	b.TextSize = math.floor(size * 0.6)
	b.TextColor3 = Color3.fromHex(D.stroke)
	b.ZIndex = (props.zIndex or 5)
	b.Parent = parent
	UiKit.corner(b, size / 2)
	local st = Instance.new("UIStroke")
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Color = Color3.fromHex(D.stroke)
	st.Thickness = D.strokeW
	st.Parent = b
	local dot = Instance.new("Frame")
	dot.Name = "NewDot"
	dot.BackgroundColor3 = Color3.fromHex(D.dot)
	dot.AnchorPoint = Vector2.new(0.5, 0.5)
	dot.Position = UDim2.fromScale(0.86, 0.14)
	dot.Size = UDim2.fromOffset(D.dotSize, D.dotSize)
	dot.ZIndex = b.ZIndex + 1
	dot.Parent = b
	UiKit.corner(dot, D.dotSize / 2)
	local function refreshDot()
		dot.Visible = not seenSet()[id]
	end
	player:GetAttributeChangedSignal("HelpSeen"):Connect(refreshDot)
	refreshDot()
	UiKit.attachPress(b, { onActivated = function()
		markSeen(id)
		InfoTip.toggle(b, "help:" .. id .. ":" .. (props.title or ""), HelpButton.content(id, type(props.rows) == "function" and props.rows() or props.rows, props.title))
	end })
	return b
end

-- 글자 칸 바로 오른쪽(글자 끝 + gap · 세로 가운데)에 붙임 - 글자가 바뀌면 따라감
function HelpButton.besideLabel(label, id, props)
	props = props or {}
	local b = HelpButton.attach(label.Parent, id, props)
	b.AnchorPoint = Vector2.new(0, 0.5)
	local function place()
		local scale, o = 1, label.Parent -- 조상 UIScale 곱(TextBounds = 화면 px · 자리 = 부모 기준 px)
		while o and not o:IsA("LayerCollector") do
			local u = o:FindFirstChildOfClass("UIScale")
			if u then
				scale *= u.Scale
			end
			o = o.Parent
		end
		local tb = label.TextBounds.X / math.max(scale, 0.01)
		local x = label.Position.X.Offset + (label.TextXAlignment == Enum.TextXAlignment.Left and tb or label.Size.X.Offset) + D.gap
		local p, s = label.Position, label.Size
		b.Position = UDim2.new(p.X.Scale, x, p.Y.Scale + s.Y.Scale / 2, p.Y.Offset + s.Y.Offset / 2)
	end
	label:GetPropertyChangedSignal("TextBounds"):Connect(place)
	place()
	return b
end

return HelpButton
