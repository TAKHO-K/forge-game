-- 갑옷 착용/해제 서버 권위 처리(12-1 [4]). 클라이언트는 인벤토리 안의 위치(index)만
-- 보낸다 - 그 자리에 실제로 뭐가 있는지, 착용이 유효한지는 전부 여기서(정확히는
-- PlayerProfile.equipArmor/unequipArmor 안에서) 검증한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)

local equipRequest = Instance.new("RemoteEvent")
equipRequest.Name = "EquipRequest"
equipRequest.Parent = ReplicatedStorage

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
