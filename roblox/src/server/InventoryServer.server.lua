-- 갑옷 착용/해제 서버 권위 처리(12-1 [4]). 클라이언트는 인벤토리 안의 위치(index)만
-- 보낸다 - 그 자리에 실제로 뭐가 있는지, 착용이 유효한지는 전부 여기서(정확히는
-- PlayerProfile.equipArmor/unequipArmor 안에서) 검증한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)

local equipRequest = Instance.new("RemoteEvent")
equipRequest.Name = "EquipRequest"
equipRequest.Parent = ReplicatedStorage

-- action: "sell"(index 필요) 또는 "sellBulk"(gradeId 필요, 13-1).
local sellRequest = Instance.new("RemoteEvent")
sellRequest.Name = "SellRequest"
sellRequest.Parent = ReplicatedStorage

-- 잠금 토글(13-1). index, locked(boolean) 필요.
local lockRequest = Instance.new("RemoteEvent")
lockRequest.Name = "LockRequest"
lockRequest.Parent = ReplicatedStorage

-- action: "equip"(index 필요) 또는 "unequip"(index 없음).
equipRequest.OnServerEvent:Connect(function(player, action, index)
	if not PlayerProfile.getProfile(player) then
		return -- 프로필 로드가 아직 안 끝났다
	end

	if action == "equip" then
		if type(index) ~= "number" then
			return
		end
		PlayerProfile.equipArmor(player, math.floor(index))
	elseif action == "unequip" then
		PlayerProfile.unequipArmor(player)
	else
		return
	end

	-- 착용/해제는 되돌릴 수 있는 사건이다(12-1 [4] 판단) - 골드를 쓰는 것도, 되돌릴 수
	-- 없는 결과가 확정되는 것도 아니라 다시 반대로 누르면 그만이다. 그래서 강화·클래스
	-- 선택과 달리 즉시저장하지 않고 주기저장(60초)·퇴장저장에 맡긴다. 다만 이 요청
	-- 직후에 바로 나가도 [0]에서 고친 flush가 마지막 상태를 붙잡아 준다.
end)

-- 판매는 되돌릴 수 없는 사건이다(13-1 [3]) - 강화·클래스 선택과 같은 즉시저장 경로
-- (ImmediateSave.request)를 그대로 재사용한다. 가격 계산·잠금 검증은 전부
-- PlayerProfile.sellArmor/sellArmorBulkUpTo 안에서 서버가 한다 - 클라이언트는 "이
-- 슬롯을(또는 이 등급 이하를) 팔겠다"는 의사만 보낸다.
sellRequest.OnServerEvent:Connect(function(player, action, arg)
	if not PlayerProfile.getProfile(player) then
		return
	end

	if action == "sell" then
		if type(arg) ~= "number" then
			return
		end
		local price = PlayerProfile.sellArmor(player, math.floor(arg))
		if price then
			ImmediateSave.request(player)
		end
	elseif action == "sellBulk" then
		if type(arg) ~= "string" then
			return
		end
		local soldCount = PlayerProfile.sellArmorBulkUpTo(player, arg)
		if soldCount > 0 then
			ImmediateSave.request(player)
		end
	else
		return
	end
end)

-- 잠금 토글은 착용/해제와 같은 되돌릴 수 있는 사건이다 - 즉시저장하지 않는다.
lockRequest.OnServerEvent:Connect(function(player, index, locked)
	if not PlayerProfile.getProfile(player) then
		return
	end
	if type(index) ~= "number" or type(locked) ~= "boolean" then
		return
	end
	PlayerProfile.setItemLocked(player, math.floor(index), locked)
end)
