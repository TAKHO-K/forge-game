-- QUEUE-ALL1 P3 §2 "구경 가기"(후보 · 마지막 순서 - docs/design/v2/04): 다른 서버 초월 알림을 받은 사람이 그 서버(jobId)로 이동. 빛기둥 60초 · 오라 5분 동안 의미가 있다.
--   요청 = RemoteEvent SpectateRequest(jobId) · 검사 = 문자열 · 이 서버가 아님 · 1인 쿨다운 · 보스전 중 금지. 실패(꽉 참 · 서버 없음) = SpectateResult로 안내.
--   Studio는 TeleportService가 동작하지 않는다(요청 · 검사까지만 확인 가능).
local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local request = Instance.new("RemoteEvent")
request.Name = "SpectateRequest"
request.Parent = ReplicatedStorage
local result = Instance.new("RemoteEvent")
result.Name = "SpectateResult"
result.Parent = ReplicatedStorage

local RequestGate = require(script.Parent.RequestGate) -- QUEUE-ALL4 B: 1인 쿨다운 = 공통 요청 제한(RequestLimitConfig.remotes.SpectateRequest - 옛 COOLDOWN 20 하드코딩)

request.OnServerEvent:Connect(function(player, jobId)
	if type(jobId) ~= "string" or #jobId < 8 or #jobId > 64 or jobId == game.JobId then
		return
	end
	if not RequestGate.allow(player, "SpectateRequest") then
		result:FireClient(player, { ok = false, message = "잠시 뒤에 다시" })
		return
	end
	if player:GetAttribute("BossEncounterId") ~= nil then
		result:FireClient(player, { ok = false, message = "보스전 중에는 갈 수 없어요" })
		return
	end
	if RunService:IsStudio() then
		result:FireClient(player, { ok = false, message = "Studio에서는 서버 이동이 안 돼요(요청은 정상)" })
		print(("[forge-game] 구경 가기 요청(Studio): %s → %s"):format(player.Name, jobId))
		return
	end
	local ok, err = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player)
	end)
	if not ok then
		result:FireClient(player, { ok = false, message = "그 서버가 꽉 찼거나 닫혔어요" })
		warn("[forge-game] 구경 가기 실패: " .. tostring(err))
	end
end)

TeleportService.TeleportInitFailed:Connect(function(player, _, message)
	result:FireClient(player, { ok = false, message = "그 서버가 꽉 찼거나 닫혔어요" })
	warn("[forge-game] 구경 가기 이동 실패: " .. tostring(message))
end)
