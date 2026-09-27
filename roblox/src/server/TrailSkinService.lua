-- W2 궤적 스킨 적용(서버 권위): 플레이어별 스킨 id 한 칸 = Player Attribute "TrailSkin"(복제 - 남의 화면도 이 값으로 그린다).
--   소유 확인 뒤에만 건다: 기본(default) = 누구나 · 개발 전용(devOnly) = Studio + 개발 계정만 · 판매 스킨 = P4c(상품 · 가격 · 저장 - 지금은 소유 목록 없음).
--   스킨은 색 · 질감 · 파티클만(shared/TrailSkin.check) - 금지 색 검사를 통과 못 한 스킨은 걸지 않는다.
--   저장 안 함(세션) - 저장 칸은 P4c에서 SAVE_VERSION과 함께.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TrailData = require(ReplicatedStorage.Shared.data.TrailData)
local TrailSkin = require(ReplicatedStorage.Shared.TrailSkin)
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)

local TrailSkinService = {}

local function isDevAccount(player)
	if not RunService:IsStudio() then
		return false
	end
	if #DevToolsConfig.allowedUserIds == 0 then
		return true
	end
	return table.find(DevToolsConfig.allowedUserIds, player.UserId) ~= nil
end

-- 소유 확인(P4c에서 구매 기록을 여기서 본다). 반환: 쓸 수 있나, 이유
function TrailSkinService.owns(player, id)
	local skin = TrailData.skins[id or ""]
	if not skin then
		return false, "없는 스킨"
	end
	local ok, reasons = TrailSkin.check(skin)
	if not ok then
		return false, "금지 검사 X: " .. table.concat(reasons, " · ")
	end
	if id == TrailData.defaultSkin then
		return true
	end
	if skin.devOnly then
		return isDevAccount(player), "개발 전용"
	end
	return false, "소유 안 함(판매 = P4c)"
end

function TrailSkinService.set(player, id)
	local ok, why = TrailSkinService.owns(player, id)
	if not ok then
		return false, why
	end
	player:SetAttribute("TrailSkin", id)
	return true
end

function TrailSkinService.get(player)
	return select(2, TrailSkin.resolve(player:GetAttribute("TrailSkin")))
end

local function onPlayer(player)
	if player:GetAttribute("TrailSkin") == nil then
		player:SetAttribute("TrailSkin", TrailData.defaultSkin)
	end
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

return TrailSkinService
