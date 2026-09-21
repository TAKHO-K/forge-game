-- 파티 요청 · 알림 HUD(S18 - 옛 PartyHud.client.lua의 [2] 초대 토스트 · 알림 토스트 + [3] 스테이지 이동 투표 패널. 25-3, PRD 20.70).
--   · 초대(PartyInviteNotice)와 스테이지 이동 투표(PartyVoteNotice)는 수락 / 거절이 필요한 요청이라 **같은 요청 배너**(hud/RequestBanner.lua - MR 구역 · 한 번에 하나 · 대기열)로 온다.
--   · 짧은 알림(PartyNotice) · 친구 입장(FriendJoinedNotice)은 Toast TC 줄 한 행이다. 친구 입장의 [파티 초대]는 글 조각의 누르는 부분(onActivate)이다(모바일 터치 폭 44).
-- 새 창을 만들지 않는다 - 초대 · 탈퇴 · 추방 조작은 파티창(panels/Party.lua)에 있다. 서버 판정은 그대로다(PartyRequest FireServer 5종: accept · decline · invite · vote_agree · vote_reject).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local PartyAway = require(script.Parent.PartyAway)
local RequestBanner = require(script.Parent.RequestBanner)
local Toast = require(script.Parent.Parent.ui.kit.Toast)

local partyInviteNotice = ReplicatedStorage:WaitForChild("PartyInviteNotice")
local partyNotice = ReplicatedStorage:WaitForChild("PartyNotice")
local friendJoinedNotice = ReplicatedStorage:WaitForChild("FriendJoinedNotice")
local partyRequest = ReplicatedStorage:WaitForChild("PartyRequest")
local partyVoteNotice = ReplicatedStorage:WaitForChild("PartyVoteNotice")

local RESULT_PASSED_SECONDS, RESULT_FAILED_SECONDS = 1.5, 2 -- 투표 결과 안내를 남기는 시간(옛 패널 그대로)

script:SetAttribute("Signals", "PartyInviteNotice,PartyNotice,FriendJoinedNotice,PartyVoteNotice")

-- ═══ 요청 배너: 초대 ═══
partyInviteNotice.OnClientEvent:Connect(function(data)
	if data.reconnect then
		-- S20 사전 작업 1: 다른 서버로 재접속한 끊긴 멤버의 복귀 초대 - 일반 원격 초대 문구와 구분하고, 남은 시간(= 파티 유예)을 글 · 게이지에 같이 센다.
		RequestBanner.push({
			key = "invite",
			title = "파티로 돌아가기",
			bodyFn = function(remaining)
				return PartyAway.reconnectBody(data.inviterName, remaining)
			end,
			seconds = data.seconds,
			accept = { text = "돌아가기", onActivated = function()
				partyRequest:FireServer("accept")
			end },
			decline = { text = "나중에", onActivated = function()
				partyRequest:FireServer("decline")
			end },
		})
		return
	end
	-- 24-2: 다른 서버에서 온 초대(remote)는 수락하면 그 서버로 이동한다는 점을 문구로 알린다 - 버튼은 같다.
	local text = data.remote and ("%s님이 파티에 초대했습니다 (다른 서버 - 수락 시 이동)"):format(data.inviterName)
		or ("%s님이 파티에 초대했습니다"):format(data.inviterName)
	RequestBanner.push({
		key = "invite",
		title = "파티 초대",
		body = text,
		seconds = data.seconds or PartyConfig.inviteTimeoutSeconds,
		accept = { text = "수락", onActivated = function()
			partyRequest:FireServer("accept")
		end },
		decline = { text = "거절", onActivated = function()
			partyRequest:FireServer("decline")
		end },
	})
end)

-- ═══ 요청 배너: 스테이지 이동 투표(25-3) ═══
-- 리더는 정보 배너(버튼 없음), 나머지는 [동의] · [거절]. 누르면 서버로 보내고 버튼만 사라진다(keepOpen) - 서버가 passed / failed를 보내면 결과 안내로 바뀌었다가 닫힌다.
partyVoteNotice.OnClientEvent:Connect(function(data)
	if data.result == "start" then
		local seconds = data.seconds or PartyConfig.stageVoteTimeoutSeconds
		if data.isLeader then
			RequestBanner.push({
				key = "vote", title = "스테이지 이동 투표", seconds = seconds,
				body = ("스테이지 %d 보스 진입 투표 중 (1명 동의 시 성립)"):format(data.stage),
			})
		else
			RequestBanner.push({
				key = "vote", title = "스테이지 이동 투표", seconds = seconds,
				body = ("%s님이 스테이지 %d 보스로 이동하려 합니다"):format(data.leaderName, data.stage),
				accept = { text = "동의", keepOpen = true, onActivated = function()
					partyRequest:FireServer("vote_agree")
				end },
				decline = { text = "거절", keepOpen = true, onActivated = function()
					partyRequest:FireServer("vote_reject")
				end },
			})
		end
	elseif data.result == "passed" then
		RequestBanner.resolve("vote", { title = "스테이지 이동 투표", body = "투표 통과 - 이동합니다", seconds = RESULT_PASSED_SECONDS })
	elseif data.result == "failed" then
		RequestBanner.resolve("vote", { title = "스테이지 이동 투표", body = "투표가 성립하지 않았습니다", seconds = RESULT_FAILED_SECONDS })
	end
end)

-- ═══ Toast: 짧은 알림 · 친구 입장 ═══
partyNotice.OnClientEvent:Connect(function(text)
	Toast.push("TC", { text = text })
end)

-- S12: 친구가 같은 서버에 들어왔다는 알림의 [파티 초대] - 기존 초대 요청("invite")을 그대로 쏜다. 행이 남아 있어도 같은 사람에게는 초대 제한 시간 동안 한 번만 보낸다(옛 토스트는 누르면 사라졌다).
local invited = {}
friendJoinedNotice.OnClientEvent:Connect(function(data)
	local userId = data.userId
	Toast.push("TC", {
		seconds = data.seconds,
		richParts = {
			{ text = ("친구 %s님이 들어왔습니다  "):format(data.name) },
			{ text = "[파티 초대]", bold = true, colorName = "gold", onActivate = function()
				if invited[userId] then
					return
				end
				invited[userId] = true
				partyRequest:FireServer("invite", userId)
				task.delay(PartyConfig.inviteTimeoutSeconds, function()
					invited[userId] = nil
				end)
			end },
		},
	})
end)
