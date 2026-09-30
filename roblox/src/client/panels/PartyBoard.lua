-- A2-N4 §4-4 파티 모집 게시판(같은 서버 - 독립 window). 열기 = 파티창 [모집 게시판] 버튼. 판정은 전부 서버(server/PartyBoard - 여기는 요청만).
--   위: 내 모집 조건(역할 · 인원 칩 - 태그만, 자유 글 없음) + [모집 올리기] · [모집 내리기] · 아래: 이 서버 모집 목록(스테이지 · 역할 · 인원) + [참가].
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local Text = require(ReplicatedStorage.Shared.Text)
local UIManager = require(script.Parent.Parent.UIManager)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)

local PartyBoard = {}
PartyBoard.id = "partyBoard"

local UIColors = Theme.colors
local player = Players.LocalPlayer
local partyRequest = ReplicatedStorage:WaitForChild("PartyRequest")
local boardSync = ReplicatedStorage:WaitForChild("PartyBoardSync")
local B = PartyConfig.board

local WIDTH = 460
local posts = {}
local refs

local function chip(parent, text, x, y, w, h)
	local b = Instance.new("TextButton")
	b.Position = UDim2.new(0, x, 0, y)
	b.Size = UDim2.new(0, w, 0, h)
	b.Font = Theme.font
	b.TextSize = Theme.textSize("caption")
	b.Text = text
	b.TextColor3 = UIColors.textPrimary
	b.BackgroundColor3 = UIColors.panel
	b.BackgroundTransparency = UIColors.panelTransparency
	b.Parent = parent
	Theme.corner(b, 12)
	Theme.stroke(b)
	return b
end

local function setSelected(b, on)
	b.BackgroundColor3 = on and UIColors.gold or UIColors.panel
	b.BackgroundTransparency = on and 0.1 or UIColors.panelTransparency
	b.TextColor3 = on and Color3.new(0, 0, 0) or UIColors.textPrimary
end

local function build()
	local H = Theme.isMobile and Theme.touchMin or 30
	local ROW = Theme.isMobile and 52 or 40
	local panel = Panel.create({
		id = PartyBoard.id,
		kind = "window",
		title = Text.get("party.board.title"),
		size = Vector2.new(WIDTH + 28, 420),
		onOpen = function()
			if refs then
				refs.update()
			end
		end,
	})
	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, 0, 1, 0)
	body.ScrollBarThickness = 4
	body.AutomaticCanvasSize = Enum.AutomaticSize.None
	body.Parent = panel.content

	local sel = { role = 1, size = #B.sizes }
	local y = 10
	local roleLabel = Theme.label(body, Text.get("party.board.role"), "caption", "textTertiary")
	roleLabel.Position = UDim2.new(0, 14, 0, y)
	roleLabel.Size = UDim2.new(0, 60, 0, H)
	local roleChips = {}
	for i, r in ipairs(B.roles) do
		roleChips[i] = chip(body, r.label, 74 + (i - 1) * 96, y, 88, H)
		roleChips[i].Activated:Connect(function()
			sel.role = i
			refs.update()
		end)
	end
	y += H + 8
	local sizeLabel = Theme.label(body, Text.get("party.board.size"), "caption", "textTertiary")
	sizeLabel.Position = UDim2.new(0, 14, 0, y)
	sizeLabel.Size = UDim2.new(0, 60, 0, H)
	local sizeChips = {}
	for i, n in ipairs(B.sizes) do
		sizeChips[i] = chip(body, ("%d"):format(n), 74 + (i - 1) * 64, y, 56, H)
		sizeChips[i].Activated:Connect(function()
			sel.size = i
			refs.update()
		end)
	end
	y += H + 8
	local postButton = chip(body, Text.get("party.board.post"), 14, y, 150, H)
	setSelected(postButton, true)
	postButton.Activated:Connect(function()
		partyRequest:FireServer("board_post", { role = sel.role, size = sel.size })
	end)
	local removeButton = chip(body, Text.get("party.board.remove"), 172, y, 150, H)
	removeButton.Activated:Connect(function()
		partyRequest:FireServer("board_remove")
	end)
	y += H + 14
	local listTop = y
	local empty = Theme.label(body, Text.get("party.board.empty"), "caption", "textSecondary")
	empty.Position = UDim2.new(0, 14, 0, listTop)
	empty.Size = UDim2.new(0, WIDTH, 0, 20)

	local rows = {}
	local function update()
		for i, b in ipairs(roleChips) do
			setSelected(b, i == sel.role)
		end
		for i, b in ipairs(sizeChips) do
			setSelected(b, i == sel.size)
		end
		local mine = false
		for _, p in ipairs(posts) do
			mine = mine or p.leaderUserId == player.UserId
		end
		removeButton.Visible = mine
		for i = #rows + 1, #posts do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(0, WIDTH, 0, ROW)
			row.BackgroundColor3 = UIColors.slot
			row.BackgroundTransparency = UIColors.slotTransparency
			row.Parent = body
			Theme.corner(row, 8)
			Theme.stroke(row)
			local name = Theme.label(row, "", "body", "textPrimary")
			name.Font = Theme.font
			name.Position = UDim2.new(0, 10, 0, 2)
			name.Size = UDim2.new(1, -110, 0.5, 0)
			local meta = Theme.label(row, "", "caption", "textSecondary")
			meta.Position = UDim2.new(0, 10, 0.5, 0)
			meta.Size = UDim2.new(1, -110, 0.5, -2)
			local join = chip(row, Text.get("party.board.join"), 0, 0, 84, H)
			join.AnchorPoint = Vector2.new(1, 0.5)
			join.Position = UDim2.new(1, -8, 0.5, 0)
			setSelected(join, true)
			rows[i] = { frame = row, name = name, meta = meta, join = join }
		end
		for i, row in ipairs(rows) do
			local p = posts[i]
			row.frame.Visible = p ~= nil
			if p then
				row.frame.Position = UDim2.new(0, 14, 0, listTop + (i - 1) * (ROW + 6))
				local class = p.classId and ClassData.classes[p.classId]
				row.name.Text = ("%s%s"):format(p.leaderName, class and (" · " .. class.displayName) or "")
				row.meta.Text = Text.get("party.board.row", { stage = tostring(p.stage), role = (B.roles[p.role] or B.roles[1]).label, count = tostring(p.count), size = tostring(p.size) })
				row.join.Visible = p.leaderUserId ~= player.UserId
				if row.conn then
					row.conn:Disconnect()
				end
				local leaderUserId = p.leaderUserId
				row.conn = row.join.Activated:Connect(function()
					partyRequest:FireServer("board_join", leaderUserId)
				end)
			end
		end
		empty.Visible = #posts == 0
		body.CanvasSize = UDim2.new(0, WIDTH + 28, 0, listTop + math.max(#posts, 1) * (ROW + 6) + 10)
	end
	refs = { update = update, body = body }
end

function PartyBoard.init()
	build()
	boardSync.OnClientEvent:Connect(function(list)
		posts = type(list) == "table" and list or {}
		refs.update()
	end)
end

function PartyBoard.open()
	UIManager.open(PartyBoard.id)
end

function PartyBoard.debugState()
	return { posts = #posts }
end

return PartyBoard
