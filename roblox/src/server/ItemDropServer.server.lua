-- 땅에 떨어진 아이템의 줍기 판정(14-1). "가까이 가면 자동으로 줍는다"(모바일 유저가
-- 다수라는 지시 - 별도 버튼 없이 서버가 거리만 보고 판정한다). 줍기 자체는 항상 서버가
-- 한다 - 클라이언트가 "주웠다"고 보내는 경로는 없다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local Reach = require(ReplicatedStorage.Shared.Reach)
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

	local added, processed = PlayerProfile.addArmorDrop(owner, item)
	if added then
		ItemDropSpawner.despawn(model)
		if item.grade == "primordial" then
			require(script.Parent.ImmediateSave).request(owner) -- D1: 태초(가방이 가득이라 땅에 있던 것)를 주우면 즉시 저장
		end
		if not processed then -- G1-2 리뷰 3: 자동 처리됐으면 "획득" 대신 자동 처리 알림만(InventorySync)
			itemPickedUp:FireClient(owner, item)
		end
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
					-- 22-4: 수평 2stud + 높이차 상한 4(TerrainConfig.pickupHeightToleranceStuds) - 발밑만.
					-- 언덕 아래 아이템은 위에서 못 줍는다(내려가야 한다).
					if Reach.within(root.Position, model.PrimaryPart.Position, WorldConfig.items.pickupRangeStuds,
						TerrainConfig.pickupHeightToleranceStuds) then
						tryPickup(model, owner)
					end
				end
			end
		end
	end
end)
