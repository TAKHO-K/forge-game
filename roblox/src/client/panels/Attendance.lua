-- 접속 보상 · 7일 출석 창(QUEUE-ALL2 P2 B-4 ④). 하루 첫 접속 때 한 번 자동으로 뜬다(받을 칸이 있을 때만 · 이번 접속에 한 번). 닫으면 퀘스트 빨간 점(서버 QuestClaimable)이 남는다.
--   보상 = 기존 QuestData.attendance · 첫 접속 보상(loginReward) 재사용 - 새 보상 없음. 받기 = QuestRequest("claim", "attendance", 칸) · ("claim", "login").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestData = require(ReplicatedStorage.Shared.data.QuestData)
local Text = require(ReplicatedStorage.Shared.Text)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local RewardIcons = require(script.Parent.Parent.ui.RewardIcons)
local UIManager = require(script.Parent.Parent.UIManager)
local ClaimFx = require(script.Parent.Parent.ui.AttendanceClaimFx) -- QUEUE-ALL9B A 받기 연출(공통)

local Attendance = {}
Attendance.id = "attendance"
local V2 = require(ReplicatedStorage.Shared.data.UiV2Flags).auto -- UI-1 7단계: 출석 + 시즌판 = AttendanceV2 창 하나(이 창 · 자동 열림은 끔 - 스위치 끄면 그대로)

local player = Players.LocalPlayer
local PANEL_SIZE = Vector2.new(680, 330)
local GREEN = Color3.fromRGB(76, 196, 110)
local requestRemote = ReplicatedStorage:WaitForChild("QuestRequest")
local updateRemote = ReplicatedStorage:WaitForChild("QuestUpdate")

local built, view
local autoShown = false

local function build()
	local panel = Panel.create({ id = Attendance.id, kind = "window", title = Text.get("attendance.windowTitle"), size = PANEL_SIZE, onOpen = function()
		task.defer(Attendance.render)
	end, onClose = function() -- QUEUE-ALL9B 5-4: 닫으면 시즌 출석판(받을 것이 있을 때만)
		if V2 then
			return
		end
		task.delay(0.3, function()
			require(script.Parent.SeasonBoard).openIfReady()
		end)
	end })
	local grid = Instance.new("Frame")
	grid.Name = "Days"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(12, 10)
	grid.Size = UDim2.new(1, -24, 0, 180)
	grid.Parent = panel.content
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(1 / 7, -6, 1, 0)
	layout.CellPadding = UDim2.fromOffset(6, 0)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	local login = Button.build({ parent = panel.content, kind = "claim", width = 220, height = Theme.isMobile and 60 or 48, text = Text.get("attendance.login"),
		position = UDim2.new(0.5, 0, 1, -12), anchorPoint = Vector2.new(0.5, 1), onActivated = function()
			requestRemote:FireServer("claim", "login")
		end })
	login.root.Name = "LoginClaim"
	-- QUEUE-ALL9A 1-4: 빠진 날이 있어도 다음 접속에 이어서 센다(센 날 = 접속한 날 - 연속 아님)는 것을 한 줄로
	local note = Theme.label(panel.content, Text.get("attendance.missedNote"), "caption", "textSecondary")
	note.Name = "MissedNote"
	note.TextXAlignment = Enum.TextXAlignment.Center
	note.Position = UDim2.fromOffset(12, 194)
	note.Size = UDim2.new(1, -24, 0, 18)
	built = { panel = panel, grid = grid, login = login }
end

function Attendance.render()
	if not built or not view then
		return
	end
	for _, c in ipairs(built.grid:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local att = view.attendance
	for _, entry in ipairs(QuestData.attendance) do
		local key = tostring(entry.day)
		local claimed = att and att.claimed[key] == true
		local ready = att and entry.day <= att.count and not claimed
		local today = att and entry.day == att.count
		local cell = Instance.new("Frame")
		cell.Name = "Day" .. key
		cell.LayoutOrder = entry.day
		cell.BackgroundColor3 = Theme.color("slot")
		cell.BackgroundTransparency = claimed and 0.55 or 0.15
		cell.Parent = built.grid
		Theme.corner(cell, 10)
		local stroke = Theme.stroke(cell)
		stroke.Color = ready and GREEN or (today and Theme.color("gold") or Theme.color("rim"))
		stroke.Thickness = ready and 3 or 1
		local day = Theme.label(cell, Text.get("attendance.dayShort", { day = key }), "body", "textPrimary")
		day.Size = UDim2.new(1, 0, 0, 24)
		day.TextXAlignment = Enum.TextXAlignment.Center
		-- QUEUE-ALL6 C: 오늘 칸 = 금색 "오늘" 띠 · 받은 칸 = 큰 체크 · 앞으로 받을 칸도 보상 그림을 누르면 상세(RewardIcons 칸 = RewardDetail)
		if today then
			local badge = Theme.label(cell, Text.get("item.attendance.today"), "caption", "panel")
			badge.Name = "TodayBadge"
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = Theme.color("gold")
			badge.TextXAlignment = Enum.TextXAlignment.Center
			badge.AnchorPoint = Vector2.new(0.5, 0.5)
			badge.Position = UDim2.new(0.5, 0, 0, 0)
			badge.Size = UDim2.fromOffset(48, 18)
			badge.ZIndex = 3
			Theme.corner(badge, 6)
		end
		if claimed then
			local check = Theme.label(cell, "✓", "title", "success")
			check.Name = "ClaimedCheck"
			check.TextXAlignment = Enum.TextXAlignment.Right
			check.Position = UDim2.new(1, -24, 0, 0)
			check.Size = UDim2.fromOffset(20, 24)
		end
		local icons = RewardIcons.row(cell, entry.reward, 28, { frameSize = UDim2.new(1, -8, 0, 64), position = UDim2.fromOffset(4, 30) })
		icons.UIListLayout.FillDirection = Enum.FillDirection.Vertical
		icons.UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		local b = Button.build({ parent = cell, kind = "claim", width = 80, height = 44, text = claimed and "✓" or Text.get("quests.claim"),
			position = UDim2.new(0.5, 0, 1, -6), anchorPoint = Vector2.new(0.5, 1), onActivated = function()
				requestRemote:FireServer("claim", "attendance", key)
			end })
		b.root.Name = "Claim"
		b.root.Size = UDim2.new(1, -8, 0, 44)
		b.setEnabled(ready == true)
	end
	built.login.setEnabled(view.loginReady == true)
	built.login.setText(view.loginReady and Text.get("attendance.login") or Text.get("quests.claimed"))
end

local function hasClaimable(v)
	if not v then
		return false
	end
	if v.loginReady then
		return true
	end
	local att = v.attendance
	for _, entry in ipairs(att and att.rewards or {}) do
		if entry.day <= att.count and att.claimed[tostring(entry.day)] ~= true then
			return true
		end
	end
	return false
end

Attendance.hasClaimable = require(ReplicatedStorage.Shared.RewardHub).attendance -- QUEUE-UI2: HUD [보상] 점과 같은 판정 한 곳(위 지역 함수와 같은 규칙)

function Attendance.open()
	if V2 then
		return require(script.Parent.AttendanceV2).open("week")
	end
	UIManager.switchTo(Attendance.id)
end

-- QUEUE-UI2 UI2-4: 마지막 QuestUpdate 값(HUD [보상] 점 - 늦게 뜬 HUD도 접속 때 받은 값을 쓴다)
function Attendance.currentView()
	return view
end

-- QUEUE-ALL9B A: 서버 확정 지급(QuestClaimResult) → 연출 · A6 접속 보상 연출이 끝나고 받을 칸이 없으면 창을 닫는다(닫히면 시즌 출석판 - onClose)
local function afterFx()
	Attendance.render()
	local att = view and view.attendance
	local nextDay = att and built and built.grid:FindFirstChild("Day" .. tostring((att.count or 0) + 1))
	if nextDay then
		ClaimFx.markNext(nextDay, view and view.resetIn)
	end
	if not hasClaimable(view) and UIManager.isOpen(Attendance.id) then
		task.delay(0.4, function()
			UIManager.close(Attendance.id)
		end)
	end
end
local function onClaimResult(kind, id, granted)
	if not built or not UIManager.isOpen(Attendance.id) or (kind ~= "login" and kind ~= "attendance") then
		return
	end
	local cell = kind == "login" and built.login.root or built.grid:FindFirstChild("Day" .. tostring(id))
	local nextCell = kind == "attendance" and built.grid:FindFirstChild("Day" .. tostring((tonumber(id) or 0) + 1)) or nil
	ClaimFx.play({ cell = cell, nextCell = nextCell, granted = granted, resetIn = view and view.resetIn, onDone = afterFx })
end

function Attendance.init()
	build()
	ReplicatedStorage:WaitForChild("QuestClaimResult").OnClientEvent:Connect(onClaimResult)
	updateRemote.OnClientEvent:Connect(function(v)
		if v and v.loginReady and view and view.loginReady == false then
			autoShown = false -- QUEUE-ALL9B A: 접속 중 날짜가 바뀌면(서버 UTC 자정 · Studio /gg day) 다시 자동으로
		end
		view = v
		if UIManager.isOpen(Attendance.id) and not ClaimFx.isPlaying() then -- 연출 중엔 칸을 다시 그리지 않는다(끝난 뒤 그림)
			Attendance.render()
		end
		-- 하루 첫 접속 자동 1회: 견습을 마쳤고 · 받을 칸이 있고 · 다른 창이 안 열렸을 때
		if not V2 and not autoShown and hasClaimable(v) and player:GetAttribute("TutorialCompleted") == true and #UIManager.getStack() == 0 then
			autoShown = true
			task.delay(2, function()
				if #UIManager.getStack() == 0 then
					UIManager.open(Attendance.id)
				end
			end)
		end
	end)
end

return Attendance
