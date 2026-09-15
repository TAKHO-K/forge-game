-- 분해 + 보석 슬롯 장착 + 옵션 변환권 서버 권위 처리(23-2, PRD 20.37/20.38). 전부 강화대
-- 상호작용 허브에 속한다(20.37 [3] "분해 UI는 강화대에 둔다") - EnhanceServer.server.lua와
-- 같은 근접 판정(isNearStation)을 그대로 재사용한다.
--
-- 클라이언트로 미는 보석 상태 스냅샷(GemSync RemoteEvent)은 여기서 만들지 않는다 -
-- PlayerProfile.dismantleItem/equipGem/rerollGemOption/tryBuyOptionRerollTicket이 성공할
-- 때마다 PlayerProfile 자신이 GemSync.push를 부른다(GemSync.lua 주석 참고 - 호출부마다
-- push를 챙기게 하면 잊는 사고가 난다, 이번 세션에 실제로 난 버그).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)

local dismantleRequest = Instance.new("RemoteEvent")
dismantleRequest.Name = "DismantleRequest"
dismantleRequest.Parent = ReplicatedStorage

local gemEquipRequest = Instance.new("RemoteEvent")
gemEquipRequest.Name = "GemEquipRequest"
gemEquipRequest.Parent = ReplicatedStorage

local rerollRequest = Instance.new("RemoteEvent")
rerollRequest.Name = "GemRerollRequest"
rerollRequest.Parent = ReplicatedStorage

local buyRerollTicketRequest = Instance.new("RemoteEvent")
buyRerollTicketRequest.Name = "BuyRerollTicketRequest"
buyRerollTicketRequest.Parent = ReplicatedStorage

-- 옵션 변환권 가격(20.37 [5] "그 순간 몬스터 1마리당 골드 × N") - 배수는 GemData.
-- rerollTicketGoldMultiplier(클라이언트 표시용과 단일 출처).
local function rerollTicketPrice(player)
	local stage = PlayerProfile.getInfiniteStage(player) or 1
	return InfiniteStage.getGoldReward(MonsterData.tier1.goldDrop, stage) * GemData.rerollTicketGoldMultiplier
end

local function isNearStation(rootPart)
	local stationPosition = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	return (rootPart.Position - stationPosition).Magnitude <= WorldConfig.enhance.interactionRangeStuds
end

-- 분해는 판매(SellRequest)와 같은 층의 되돌릴 수 없는 사건이다 - 즉시저장.
dismantleRequest.OnServerEvent:Connect(function(player, index)
	if type(index) ~= "number" then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return
	end

	local success, gradeOrReason = PlayerProfile.dismantleItem(player, math.floor(index))
	if success then
		ImmediateSave.request(player)
		print(("[forge-game] 분해: %s - %s 등급 보석 획득"):format(player.Name, gradeOrReason))
	end
end)

-- 보석 슬롯 장착(교체)도 판매·분해와 같은 층이다 - 되돌릴 수 없지는 않지만(다시 교체하면
-- 그만) 무기 전투력이 바로 바뀌는 사건이라 즉시저장한다(강화 결과와 같은 판단).
gemEquipRequest.OnServerEvent:Connect(function(player, slot, gemInventoryIndex)
	if type(slot) ~= "number" or type(gemInventoryIndex) ~= "number" then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return
	end

	local success = PlayerProfile.equipGem(player, math.floor(slot), math.floor(gemInventoryIndex))
	if success then
		ImmediateSave.request(player)
	end
end)

rerollRequest.OnServerEvent:Connect(function(player, slot)
	if type(slot) ~= "number" then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return
	end

	local success = PlayerProfile.rerollGemOption(player, math.floor(slot))
	if success then
		ImmediateSave.request(player)
	end
end)

-- gradeId: "ancient" 또는 "primordial"만 유효하다(GemData.optionPoolByGrade). 가격은
-- 클라이언트가 보낸 값을 절대 믿지 않는다 - 여기서 매번 다시 계산한다(EnhanceServer의
-- Enhance.getCost와 같은 원칙).
buyRerollTicketRequest.OnServerEvent:Connect(function(player, gradeId)
	if gradeId ~= "ancient" and gradeId ~= "primordial" then
		return
	end
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not isNearStation(rootPart) then
		return
	end

	local cost = rerollTicketPrice(player)
	local success = PlayerProfile.tryBuyOptionRerollTicket(player, gradeId, cost)
	if success then
		ImmediateSave.request(player)
		print(("[forge-game] 변환권 구매: %s - %s (비용 %d)"):format(player.Name, gradeId, cost))
	end
end)
