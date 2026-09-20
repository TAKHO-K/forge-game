-- 보스 첫 클리어 보상 미리보기 RemoteEvent 연결(30-0 S11). 클라는 보스 스테이지 배열만 보낸다 - 검사 · 조회는 BossRewardPreview.handle이 한다(자동 검증도 같은 함수).
--   BossRewardPreviewRequest(stages)   - 클라 → 서버
--   BossRewardPreviewResult(payload)   - 서버 → 클라 { ok, entries, codex } 또는 { ok = false, reason }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRewardPreview = require(script.Parent.BossRewardPreview)

local request = Instance.new("RemoteEvent")
request.Name = "BossRewardPreviewRequest"
request.Parent = ReplicatedStorage

local result = Instance.new("RemoteEvent")
result.Name = "BossRewardPreviewResult"
result.Parent = ReplicatedStorage

request.OnServerEvent:Connect(function(player, stages)
	local ok, payload = pcall(BossRewardPreview.handle, player, stages)
	if not ok then
		warn(("[BossRewardPreview] 처리 에러(%s): %s"):format(player.Name, tostring(payload)))
		payload = { ok = false, reason = "error" }
	end
	result:FireClient(player, payload)
end)

Players.PlayerRemoving:Connect(BossRewardPreview.forget)
