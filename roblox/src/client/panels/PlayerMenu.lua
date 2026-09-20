-- 이름 클릭 메뉴(S12b A) - overlay. 진입점: 드랍 피드 · 태초 배너 · 파티창의 플레이어 이름(머리 위 이름표는 오터치 때문에 클릭이 없다).
--   [친구 추가]  StarterGui:SetCore("PromptSendFriendRequest", player) - 이미 친구면 비활성.
--   [귓속말]     TextChatService 기본 귓속말만 쓴다: 기본 채팅 입력창(ChatInputBarConfiguration.TextBox)에 "/w 표시이름 "을 채우고 커서를 둔다. 문자열을 RemoteEvent로 보내지 않는다(채팅 필터 정책).
--                나나 상대가 채팅 제한이면(CanUserChatAsync · CanUsersChatAsync) 비활성 + 이유 한 줄.
--   [장비 보기]  InspectWindow(장비 보기 창)를 연다.
-- 자기 이름이면 [장비 보기]만. 대상이 서버를 떠났으면 세 버튼 모두 비활성 + "서버를 떠난 플레이어".
-- 처음 열 때 만든다(Confirm과 같은 방식). PlayerMenu.open(target) - target = { userId, displayName, level, rebirth }.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")

local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local UIManager = require(script.Parent.Parent.UIManager)
local Button = require(script.Parent.Parent.ui.kit.Button)
local Panel = require(script.Parent.Parent.ui.kit.Panel)
local Theme = require(script.Parent.Parent.ui.kit.Theme)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local PlayerMenu = {}

PlayerMenu.id = "playerMenu"
local PANEL_WIDTH = 300
local PAD = 16

local localPlayer = Players.LocalPlayer
local built -- { panel, rows = { friend, whisper, inspect } }
local handlers = {} -- 버튼 이름 -> 눌렀을 때 하는 일(검사가 사람 손 대신 같은 함수를 부른다)
local current -- 지금 열린 메뉴의 대상 { userId, displayName, player }
local openToken = 0 -- 비동기 확인(친구 여부 · 채팅 제한)이 옛 메뉴의 결과를 덮지 않게

local function build()
	local rowHeight = Theme.buttonHeight + Theme.textSize("caption") + 4 + 10
	local titleHeight = Theme.isMobile and Panel.closeSize or 40
	local panel = Panel.create({
		id = PlayerMenu.id,
		kind = "overlay",
		title = "",
		size = Vector2.new(PANEL_WIDTH, titleHeight + 1 + 12 + rowHeight * 3 + 6),
	})
	panel.titleLabel.RichText = true

	local rows = {}
	local function makeRow(name, text, order, onActivated)
		handlers[name] = onActivated
		local reasonLabel = Theme.label(panel.content, "", "caption", "textTertiary")
		reasonLabel.Name = name .. "Reason"
		reasonLabel.Position = UDim2.new(0, PAD, 0, 12 + (order - 1) * rowHeight + Theme.buttonHeight + 4)
		reasonLabel.Size = UDim2.new(1, -PAD * 2, 0, Theme.textSize("caption") + 2)
		local button = Button.build({
			parent = panel.content,
			name = name,
			kind = name == "InspectButton" and "primary" or "secondary",
			text = text,
			width = PANEL_WIDTH - PAD * 2,
			position = UDim2.new(0, PAD, 0, 12 + (order - 1) * rowHeight),
			onActivated = onActivated,
		})
		rows[name] = { button = button, reasonLabel = reasonLabel, order = order, enabled = true }
		return rows[name]
	end
	rows.friend = makeRow("FriendButton", "친구 추가", 1, function()
		if current and current.player then
			local ok, err = pcall(StarterGui.SetCore, StarterGui, "PromptSendFriendRequest", current.player)
			if not ok then
				warn("[PlayerMenu] PromptSendFriendRequest 실패: " .. tostring(err))
				Toast.push("TC", { text = "친구 요청 창을 열 수 없습니다", colorName = "danger" })
			end
		end
		UIManager.close(PlayerMenu.id)
	end)
	rows.whisper = makeRow("WhisperButton", "귓속말", 2, function()
		local displayName = current and current.displayName
		if displayName and PlayerMenu.fillWhisper(displayName) then
			UIManager.close(PlayerMenu.id)
		else
			Toast.push("TC", { text = "귓속말 입력창을 열 수 없습니다", colorName = "danger" })
		end
	end)
	rows.inspect = makeRow("InspectButton", "장비 보기", 3, function()
		local userId = current and current.userId
		UIManager.close(PlayerMenu.id, true)
		if userId then
			require(script.Parent.Inspect).open(userId)
		end
	end)
	built = { panel = panel, rows = rows }
end

-- 기본 채팅 입력창에 "/w 표시이름 "을 채운다. 반환: 채웠으면 true. 입력창(ChatInputBarConfiguration.TextBox)이 없으면 false - 우회하지 않는다.
function PlayerMenu.fillWhisper(displayName)
	local ok, box = pcall(function()
		local config = TextChatService:FindFirstChild("ChatInputBarConfiguration")
		return config and config.Enabled and config.TextBox or nil
	end)
	if not ok or not box then
		return false
	end
	local text = ("%s %s "):format(SocialData.whisper.command, displayName)
	box:CaptureFocus()
	box.Text = text
	box.CursorPosition = #text + 1
	return true
end

local function setRow(row, visible, enabled, reason)
	row.enabled = enabled
	row.button.root.Visible = visible
	row.button.setEnabled(enabled)
	row.reasonLabel.Visible = visible
	row.reasonLabel.Text = reason or ""
end

-- target = { userId, displayName, level, rebirth }. level · rebirth는 그 사람이 아직 서버에 있으면 Attribute의 지금 값으로 다시 읽는다.
function PlayerMenu.open(target)
	if not built then
		build()
	end
	openToken += 1
	local token = openToken
	local targetPlayer = Players:GetPlayerByUserId(target.userId)
	local isSelf = target.userId == localPlayer.UserId
	local level, rebirth = target.level, target.rebirth
	if targetPlayer then
		level = targetPlayer:GetAttribute("CharacterLevel") or level
		rebirth = targetPlayer:GetAttribute("RebirthCount") or rebirth
	end
	current = { userId = target.userId, displayName = (targetPlayer and targetPlayer.DisplayName) or target.displayName, player = targetPlayer }

	built.panel.titleLabel.Text = PlayerLabelFormat.richText(current.displayName, level, rebirth, Theme.textSize("header"))
	local rows = built.rows
	local left = targetPlayer == nil
	local leftReason = "서버를 떠난 플레이어"

	-- 세로 자리: 보이는 버튼이 위에서부터 차곡차곡(자기 이름이면 [장비 보기]만 첫 줄).
	local visibleOrder = 0
	local function place(row, visible)
		if visible then
			visibleOrder += 1
			local y = 12 + (visibleOrder - 1) * (Theme.buttonHeight + Theme.textSize("caption") + 4 + 10)
			row.button.root.Position = UDim2.new(0, PAD, 0, y)
			row.reasonLabel.Position = UDim2.new(0, PAD, 0, y + Theme.buttonHeight + 4)
		end
	end
	place(rows.friend, not isSelf)
	place(rows.whisper, not isSelf)
	place(rows.inspect, true)

	setRow(rows.friend, not isSelf, not left, (not isSelf and left) and leftReason or nil)
	setRow(rows.whisper, not isSelf, not left, (not isSelf and left) and leftReason or nil)
	setRow(rows.inspect, true, not left, left and leftReason or nil)

	if not UIManager.open(PlayerMenu.id) then
		return false
	end

	-- 비동기 확인: 이미 친구인가 · 채팅이 막혀 있는가. 실패(pcall false)하면 막지 않는다(기능을 조용히 죽이지 않는다).
	if not isSelf and targetPlayer then
		task.spawn(function()
			local ok, isFriend = pcall(localPlayer.IsFriendsWith, localPlayer, target.userId)
			if ok and isFriend and openToken == token then
				setRow(rows.friend, true, false, "이미 친구입니다")
			end
		end)
		task.spawn(function()
			local okSelf, canChatSelf = pcall(TextChatService.CanUserChatAsync, TextChatService, localPlayer.UserId)
			if openToken ~= token then
				return
			end
			if okSelf and canChatSelf == false then
				setRow(rows.whisper, true, false, "내 계정의 채팅이 제한되어 있습니다")
				return
			end
			local okPair, canChatPair = pcall(TextChatService.CanUsersChatAsync, TextChatService, localPlayer.UserId, target.userId)
			if okPair and canChatPair == false and openToken == token then
				setRow(rows.whisper, true, false, "상대의 채팅이 제한되어 있습니다")
			end
		end)
	end
	return true
end

-- 검사용: 세 버튼의 지금 상태({ visible, enabled, reason }).
function PlayerMenu.debugState()
	local state = {}
	if built then
		for key, row in pairs(built.rows) do
			state[key] = { visible = row.button.root.Visible, enabled = row.enabled, reason = row.reasonLabel.Text }
		end
		state.title = built.panel.titleLabel.Text
	end
	return state
end

-- 검사용: 버튼을 누른 것과 같은 일을 한다(name = FriendButton · WhisperButton · InspectButton). 비활성 버튼은 사람도 못 누르므로 아무 일도 안 한다.
function PlayerMenu.debugPress(name)
	local row = built and (name == "FriendButton" and built.rows.friend or name == "WhisperButton" and built.rows.whisper or name == "InspectButton" and built.rows.inspect)
	if row and row.enabled and handlers[name] then
		handlers[name]()
	end
end

return PlayerMenu
