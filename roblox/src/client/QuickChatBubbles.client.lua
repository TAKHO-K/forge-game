-- UI-1 7c 빠른 말 말풍선: QuickChatShow(userId, kind, index) → 그 사람 머리 위 3초(글 = 내 언어 표 · 이모트 = 그림). 그리기만 - 규칙은 서버.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuickChatData = require(ReplicatedStorage.Shared.data.QuickChatData)
local Text = require(ReplicatedStorage.Shared.Text)
local ArtImage = require(script.Parent.ui.ArtImage)

local current = {} -- [userId] = 말풍선(새 말이면 옛 것 지움)

ReplicatedStorage:WaitForChild("QuickChatShow").OnClientEvent:Connect(function(userId, kind, index)
	local who = Players:GetPlayerByUserId(userId)
	local head = who and who.Character and who.Character:FindFirstChild("Head")
	if not head then
		return
	end
	if current[userId] then
		current[userId]:Destroy()
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "QuickChatBubble"
	bb.Adornee = head
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(kind == "emote" and 64 or 200, kind == "emote" and 64 or 44)
	bb.StudsOffset = Vector3.new(0, 3.2, 0)
	bb.MaxDistance = 120
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromHex("161A2B")
	frame.BackgroundTransparency = kind == "emote" and 1 or 0.1
	frame.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 14)
	c.Parent = frame
	if kind == "emote" then
		local e = QuickChatData.emotes[index]
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = e and (ArtImage.get(e.image) or "") or ""
		img.Parent = frame
	else
		local key = QuickChatData.phrases[index]
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, -12, 1, 0)
		t.Position = UDim2.fromOffset(6, 0)
		t.Font = Enum.Font.GothamBold
		t.TextSize = 18
		t.TextColor3 = Color3.new(1, 1, 1)
		t.Text = key and Text.get(key) or ""
		t.Parent = frame
	end
	bb.Parent = head
	current[userId] = bb
	task.delay(QuickChatData.bubbleSeconds, function()
		if current[userId] == bb then
			current[userId] = nil
		end
		bb:Destroy()
	end)
end)
