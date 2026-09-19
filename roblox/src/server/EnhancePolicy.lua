-- 강화 규제 관문(28-1 S05, PRD 20.72 [1-6] 4번) - 2026-05-26 로블록스 "유료 랜덤 아이템" 정책 대응의 자리. 지금 강화에 들어가는 것은 골드 · 재료 · 방지권이고 전부
-- 플레이로만 얻으므로 EnhanceConfig.paidInputIds(Robux로 살 수 있는 투입물의 id)는 **빈 표**다 - 이 관문은 **지금은 절대 안 걸린다**. Robux 재료가 붙는 날 그 재료의
-- id를 paidInputIds에 넣기만 하면 제한 지역에서 그 재료를 쓰는 시도가 거부된다.
--
-- PolicyService:GetPolicyInfoForPlayerAsync는 yield한다. EnhanceRequest 핸들러는 골드 차감 ~ 판정 사이에 yield가 없어야 하므로(PRD 20.18 [3] 원자성) 접속 시 1회
-- 조회해 캐시하고 핸들러는 캐시만 읽는다(canAttempt - yield 없음). 조회가 실패하면 기본값은 "제한됨"이고, 캐시가 아직 없을 때(조회 진행 중)도 "제한됨"으로 본다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PolicyService = game:GetService("PolicyService")

local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)

local EnhancePolicy = {}

-- [Player] = ArePaidRandomItemsRestricted(boolean). 없으면 아직 조회 전이거나 실패한 것(제한됨으로 본다).
local restrictedByPlayer = setmetatable({}, { __mode = "k" })

-- 접속 시 1회 조회(yield) - 실패하면 "제한됨"(true).
function EnhancePolicy.cacheFor(player)
	local ok, info = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)
	local restricted = true
	if ok and type(info) == "table" and info.ArePaidRandomItemsRestricted ~= nil then
		restricted = info.ArePaidRandomItemsRestricted == true
	end
	if player.Parent then
		restrictedByPlayer[player] = restricted
	end
	return restricted
end

-- 관문의 순수 핵심: inputIds 중 paidInputIds에 든 것이 있고 restricted면 거부한다. canAttempt가 실제 표(EnhanceConfig.paidInputIds)와 캐시로 부르고, 검증은 표 사본 ·
-- 제한 값을 직접 넣어 부른다(제품 데이터 표를 안 건드린다).
function EnhancePolicy.evaluate(inputIds, paidInputIds, restricted)
	if not restricted then
		return true
	end
	for _, inputId in ipairs(inputIds) do
		for _, paidId in ipairs(paidInputIds) do
			if inputId == paidId then
				return false, "paid_random_restricted"
			end
		end
	end
	return true
end

-- 이번 시도가 소모하는 것들의 id(gold · 재료 id · dropTicket · resetTicket)를 받아 시도할 수 있는지 돌려준다. **캐시만 읽는다 - yield 없음.**
function EnhancePolicy.canAttempt(player, inputIds)
	return EnhancePolicy.evaluate(inputIds, EnhanceConfig.paidInputIds, restrictedByPlayer[player] ~= false)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(EnhancePolicy.cacheFor, player)
end)
for _, existing in ipairs(Players:GetPlayers()) do
	task.spawn(EnhancePolicy.cacheFor, existing)
end
Players.PlayerRemoving:Connect(function(player)
	restrictedByPlayer[player] = nil
end)

return EnhancePolicy
