-- QUEUE-ALL9C 1-8(Q1 · 결정 6) 창 위치: PC · 태블릿에서 주요 창(Panel kind "window")의 제목줄을 끌어 옮기고 위치를 저장한다. 폰(Theme.isMobile) = 고정.
--   저장 = 설정 키 windowPositions(서버 SettingsService - 문자열 "id:x,y;id:x,y" · 화면 가운데 기준 픽셀 · Attribute WindowPositions) - 설정 표라 이관 없음.
--   화면 밖으로 못 나가게 끄는 동안 자르고(창 전체가 화면 안), 해상도가 바뀌면 UIManager.fitToScreen이 다시 안으로 민다(가운데 기준이라 비율도 크게 안 틀어진다).
--   가방 창은 옛 저장(SetInventoryWindowPosition)을 그대로 쓴다 · [창 위치 초기화] = 둘 다 지운다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WindowPositions = {}

local player = Players.LocalPlayer
local ATTR = "WindowPositions"
local MAX_ENTRIES = 24

local function decode(text)
	local map = {}
	for id, x, y in tostring(text or ""):gmatch("([%w_]+):(%-?%d+),(%-?%d+)") do
		map[id] = Vector2.new(tonumber(x), tonumber(y))
	end
	return map
end

local function encode(map)
	local ids = {}
	for id in pairs(map) do
		table.insert(ids, id)
	end
	table.sort(ids)
	local parts = {}
	for i, id in ipairs(ids) do
		if i > MAX_ENTRIES then
			break
		end
		table.insert(parts, ("%s:%d,%d"):format(id, math.floor(map[id].X + 0.5), math.floor(map[id].Y + 0.5)))
	end
	return table.concat(parts, ";")
end
WindowPositions.decode, WindowPositions.encode = decode, encode

local function save(map)
	local remote = ReplicatedStorage:FindFirstChild("SettingsSave")
	local text = encode(map)
	player:SetAttribute(ATTR, text) -- 바로 반영(서버가 같은 값을 다시 내린다)
	if remote then
		remote:FireServer("windowPositions", text)
	end
end

function WindowPositions.get(id)
	return decode(player:GetAttribute(ATTR))[id]
end

function WindowPositions.set(id, offset)
	local map = decode(player:GetAttribute(ATTR))
	map[id] = offset
	save(map)
end

-- [창 위치 초기화](설정 - 게임 탭): 저장 비우기 + 가방 창 옛 저장 지우기
function WindowPositions.reset()
	save({})
	local inventory = ReplicatedStorage:FindFirstChild("SetInventoryWindowPosition")
	if inventory then
		inventory:FireServer("reset")
	end
end

-- 창 하나에 제목줄 끌기를 단다(Panel.create가 부른다). frame = 가운데 기준(AnchorPoint 0.5) 창 · handle = 제목줄 칸
function WindowPositions.attach(id, frame, handle, screenGui)
	local UserInputService = game:GetService("UserInputService")
	local function apply()
		local saved = WindowPositions.get(id)
		frame.Position = saved and UDim2.new(0.5, saved.X, 0.5, saved.Y) or UDim2.new(0.5, 0, 0.5, 0)
	end
	apply()
	player:GetAttributeChangedSignal(ATTR):Connect(apply)
	local dragging, startInput, startOffset = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, startInput = true, input.Position
			startOffset = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		end
	end)
	local function clamp(offset)
		local view = screenGui.AbsoluteSize
		local size = frame.AbsoluteSize
		local margin = require(script.Parent.Parent.UIManager).safeMargin -- fitToScreen과 같은 여백(다시 열 때 튀지 않게)
		local maxX = math.max(0, (view.X - size.X) / 2 - margin)
		local maxY = math.max(0, (view.Y - size.Y) / 2 - margin)
		return Vector2.new(math.clamp(offset.X, -maxX, maxX), math.clamp(offset.Y, -maxY, maxY))
	end
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - startInput
			local offset = clamp(startOffset + Vector2.new(delta.X, delta.Y))
			frame.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			local offset = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
			if (offset - startOffset).Magnitude >= 2 then
				WindowPositions.set(id, offset)
			end
		end
	end)
end

return WindowPositions
