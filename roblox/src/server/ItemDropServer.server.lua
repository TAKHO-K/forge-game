-- 땅에 떨어진 아이템의 줍기 판정(14-1). "가까이 가면 자동으로 줍는다"(모바일 유저가
-- 다수라는 지시 - 별도 버튼 없이 서버가 거리만 보고 판정한다). 줍기 자체는 항상 서버가
-- 한다 - 클라이언트가 "주웠다"고 보내는 경로는 없다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local ItemDropState = require(script.Parent.ItemDropState)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local PlayerProfile = require(script.Parent.PlayerProfile)
local InventorySync = require(script.Parent.InventorySync)

-- 줍는 순간의 반응(14-1 "줍는 순간의 반응")용. 인벤토리 자체는 InventorySync가 이미
-- 밀어주므로, 이 이벤트는 "방금 이걸 주웠다"는 일회성 연출 신호만 보낸다(goldGained와
-- 같은 패턴).
local itemPickedUp = Instance.new("RemoteEvent")
itemPickedUp.Name = "ItemPickedUp"
itemPickedUp.Parent = ReplicatedStorage

-- 인벤토리가 가득 찬 상태에서 아이템 위에 서 있으면 매 프레임 시도하게 되므로, 알림은
-- ItemDropState.fullNotified로 한 번만 보낸다(SaveCoordinator의 "알림은 발생 시점에
-- 한 번이면 된다"와 같은 원칙).
local function tryPickup(model, owner)
	local item = ItemDropState.getItem(model)
	if not item then
		return
	end

	local added = PlayerProfile.addArmorDrop(owner, item)
	if added then
		ItemDropSpawner.despawn(model)
		itemPickedUp:FireClient(owner, item)
	elseif not ItemDropState.isFullNotified(model) then
		-- 인벤토리가 가득 차도 드랍 자체는 취소하지 않는다(14-1 판단 - "땅에는 있는데 못
		-- 줍는" 상태로 둔다. 눈앞에 두고 못 주우면 정리하고 싶어지고, 판매 기능(13-1)이
		-- 이미 그 해소 수단이다). 이 아이템은 계속 땅에 남아 수명이 다하거나 칸을 비우고
		-- 다시 지나가면 주울 수 있다.
		ItemDropState.setFullNotified(model, true)
		InventorySync.notifyFull(owner)
	end
end

RunService.Heartbeat:Connect(function()
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if model.Parent then
			local spawnedAt = ItemDropState.getSpawnedAt(model)
			-- 튀어오르는 연출을 다 보기 전에는 줍지 않는다(즉시 주워지면 연출을 볼 수
			-- 없다 - ItemDropSpawner.bounceSeconds 참고).
			if spawnedAt and os.clock() - spawnedAt >= WorldConfig.items.pickupDelaySeconds then
				local ownerId = ItemDropState.getOwnerId(model)
				local owner = ownerId and Players:GetPlayerByUserId(ownerId)
				local character = owner and owner.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if root and model.PrimaryPart then
					local distance = (root.Position - model.PrimaryPart.Position).Magnitude
					if distance <= WorldConfig.items.pickupRangeStuds then
						tryPickup(model, owner)
					end
				end
			end
		end
	end
end)
