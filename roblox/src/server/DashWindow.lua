-- FINAL-1 3 MOVE-2: 대시 회피 창(한 곳) - 대시 중 받는 피해 감소(DashConfig.incomingDamageMultiplier)와 "대시 중이면 통과"(수정 여왕 마법 미사일 passThrough)를
-- 여기서만 시작 · 판정한다. 나중의 PERFECT DODGE(대시 시작 직후 짧은 창에 맞을 뻔함 = 보상)는 DashWindow.elapsed(player)로 같은 자리에 붙인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DashConfig = require(ReplicatedStorage.Shared.data.DashConfig)
local PlayerState = require(script.Parent.PlayerState)

local DashWindow = {}
DashWindow.sourceKey = "dash" -- PlayerState 받는 피해 배율 출처 이름(옛 그대로 - 검증 모듈이 이 이름을 쓴다)

local startedAt = {} -- [Player] = os.clock()

function DashWindow.begin(player, durationSeconds)
	startedAt[player] = os.clock()
	PlayerState.setIncomingDamageMultiplierUntil(player, DashConfig.incomingDamageMultiplier, durationSeconds, DashWindow.sourceKey)
end

-- 지금 대시 창 안인가(피해 감소 · 통과 판정 공용)
function DashWindow.isActive(player)
	return PlayerState.hasIncomingSource(player, DashWindow.sourceKey)
end

-- 마지막 대시 시작 뒤 지난 초(없으면 nil) - PERFECT DODGE 자리
function DashWindow.elapsed(player)
	local t = startedAt[player]
	return t and os.clock() - t or nil
end

Players.PlayerRemoving:Connect(function(player)
	startedAt[player] = nil
end)

return DashWindow
