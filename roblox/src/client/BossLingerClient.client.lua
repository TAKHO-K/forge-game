-- G1-4: 서버 BossLinger 신호 → 잔류 선택 창을 열고 닫는다(client/panels/BossLinger).
-- QUEUE-ALL2 P4 2순위: 아트 켬이면 창 전에 "처치!" 도장(FxMoment.stamp · 1초) → 도장이 끝난 뒤 창(FxMomentData.bossStamp). 서버 남은 초는 그대로 - 창만 늦게 연다.
--   연출 세기 끔(FxScale 0) · 아트 끔 = 옛 동작(바로 창).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossLingerPanel = require(script.Parent.panels.BossLinger)
local FxMoment = require(script.Parent.FxMoment)
local FxMomentData = require(ReplicatedStorage.Shared.data.FxMomentData)
local Text = require(ReplicatedStorage.Shared.Text)

local S = FxMomentData.bossStamp
local showToken = 0

ReplicatedStorage:WaitForChild("BossLinger").OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	showToken += 1
	if payload.kind == "start" then
		if FxMoment.scale() <= 0 then
			BossLingerPanel.show(payload)
			return
		end
		local mine = showToken
		task.delay(S.stampDelay, function()
			if mine == showToken then
				FxMoment.stamp(Text.get("moment.bossStamp"))
				require(script.Parent.SoundSheet).play(S.sound)
			end
		end)
		task.delay(S.windowDelay, function()
			if mine == showToken then -- 그 사이 "end"(복귀)가 왔으면 열지 않는다
				local late = table.clone(payload)
				late.seconds = math.max(0, (payload.seconds or 90) - S.windowDelay) -- 창 카운트다운 = 서버 남은 초
				BossLingerPanel.show(late)
			end
		end)
	elseif payload.kind == "end" then
		BossLingerPanel.hide()
	end
end)
