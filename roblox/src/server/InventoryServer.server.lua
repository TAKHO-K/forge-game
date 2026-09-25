-- 장비 착용/해제 서버 권위 처리(12-1 [4] 신설 → 16-6에서 갑옷 전용 → 3부위 공용으로
-- 일반화). 클라이언트는 인벤토리 안의 위치(index, 착용용) 또는 부위 이름(part, 해제용)만
-- 보낸다 - 그 자리에 실제로 뭐가 있는지, 착용이 유효한지는 전부 여기서(정확히는
-- PlayerProfile.equipItem/unequipItem 안에서) 검증한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerProfile = require(script.Parent.PlayerProfile)
local ImmediateSave = require(script.Parent.ImmediateSave)
local ItemEquip = require(script.Parent.ItemEquip)

local equipRequest = Instance.new("RemoteEvent")
equipRequest.Name = "EquipRequest"
equipRequest.Parent = ReplicatedStorage

-- S20d: 착용 · 해제 요청의 결과(success, reason, action, part) - 클라 ItemActions가 요청 중 잠금을 풀고 거절 이유를 보인다(GemEquipResult와 같은 역할).
--   reason은 ItemEquip.lua 머리 주석의 이유 코드. part는 unequip 요청일 때만 온다.
local equipResult = Instance.new("RemoteEvent")
equipResult.Name = "EquipResult"
equipResult.Parent = ReplicatedStorage

-- action: "sell"(index 필요) 또는 "sellBulk"(gradeId 필요, 13-1).
local sellRequest = Instance.new("RemoteEvent")
sellRequest.Name = "SellRequest"
sellRequest.Parent = ReplicatedStorage

-- 잠금 토글(13-1). index, locked(boolean) 필요.
local lockRequest = Instance.new("RemoteEvent")
lockRequest.Name = "LockRequest"
lockRequest.Parent = ReplicatedStorage

-- 일괄판매 기준 등급 선택(20-3). gradeId(string) 필요 - ArmorData.bulkSellMaxGrade
-- 이하인지는 PlayerProfile.setBulkSellCutoffGrade가 검증한다.
local bulkSellCutoffRequest = Instance.new("RemoteEvent")
bulkSellCutoffRequest.Name = "BulkSellCutoffRequest"
bulkSellCutoffRequest.Parent = ReplicatedStorage

-- 장비창 위치 저장(23-5, 지시 "재접속해도 유지되게"). x, y(둘 다 number, 픽셀 좌표) 필요 -
-- 드래그가 끝날 때(마우스 업) 한 번만 쏜다(매 프레임 쏘지 않는다).
local setInventoryWindowPositionRequest = Instance.new("RemoteEvent")
setInventoryWindowPositionRequest.Name = "SetInventoryWindowPosition"
setInventoryWindowPositionRequest.Parent = ReplicatedStorage

-- action: "equip"(arg=index, 인벤토리 위치) 또는 "unequip"(arg=part, 16-6부터 부위를
-- 명시해야 한다 - 갑옷 하나뿐이던 12-1 시절엔 필요 없었지만 이제 어느 슬롯을 벗을지
-- 클라이언트가 골라야 한다). EquipSlots.order에 없는 문자열은 PlayerProfile.unequipItem이
-- classState.equipment[part]를 nil 조회로 조용히 거른다(19-1부터 활성 직업 아래) - 여기선
-- 타입만 확인한다.
equipRequest.OnServerEvent:Connect(function(player, action, arg)
	-- S20d: 판정은 ItemEquip.handle(요청 모양 검사 + PlayerProfile) 한 곳이고, 결과(성공 여부 · 이유 코드)를 요청한 클라에 알린다 - 옛 코드는 실패하면 아무 신호도 안 보냈다.
	-- InventorySync는 PlayerProfile 안에서 이미 밀렸으므로 결과 이벤트는 항상 그 스냅샷 뒤에 온다.
	local success, reason = ItemEquip.handle(player, action, arg)
	equipResult:FireClient(player, success, reason, action, type(arg) == "string" and arg or nil)

	-- 착용/해제는 되돌릴 수 있는 사건이다(12-1 [4] 판단) - 골드를 쓰는 것도, 되돌릴 수
	-- 없는 결과가 확정되는 것도 아니라 다시 반대로 누르면 그만이다. 그래서 강화·클래스
	-- 선택과 달리 즉시저장하지 않고 주기저장(60초)·퇴장저장에 맡긴다. 다만 이 요청
	-- 직후에 바로 나가도 [0]에서 고친 flush가 마지막 상태를 붙잡아 준다.
end)

-- 판매는 되돌릴 수 없는 사건이다(13-1 [3]) - 강화·클래스 선택과 같은 즉시저장 경로
-- (ImmediateSave.request)를 그대로 재사용한다. 가격 계산·잠금 검증은 전부
-- PlayerProfile.sellItem/sellItemsBulkUpTo 안에서 서버가 한다 - 클라이언트는 "이
-- 슬롯을(또는 이 등급 이하를) 팔겠다"는 의사만 보낸다.
sellRequest.OnServerEvent:Connect(function(player, action, arg)
	if not PlayerProfile.getProfile(player) then
		return
	end

	if action == "sell" then
		if type(arg) ~= "number" then
			return
		end
		local price = PlayerProfile.sellItem(player, math.floor(arg))
		if price then
			ImmediateSave.request(player)
		end
	elseif action == "sellBulk" then
		if type(arg) ~= "string" then
			return
		end
		local soldCount = PlayerProfile.sellItemsBulkUpTo(player, arg)
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

-- G1-2: 줍는 순간 자동 처리 설정(enabled · maxGrade) - 되돌릴 수 있는 설정이라 즉시저장하지 않는다. 값 검사는 PlayerProfile.setAutoProcess.
local autoProcessRequest = Instance.new("RemoteEvent")
autoProcessRequest.Name = "AutoProcessRequest"
autoProcessRequest.Parent = ReplicatedStorage
autoProcessRequest.OnServerEvent:Connect(function(player, enabled, maxGrade)
	if not PlayerProfile.getProfile(player) then
		return
	end
	PlayerProfile.setAutoProcess(player, enabled, maxGrade)
end)

-- 일괄판매 기준 등급 선택도 잠금과 같은 되돌릴 수 있는 사건이다 - 즉시저장하지 않는다.
bulkSellCutoffRequest.OnServerEvent:Connect(function(player, gradeId)
	if not PlayerProfile.getProfile(player) then
		return
	end
	if type(gradeId) ~= "string" then
		return
	end
	PlayerProfile.setBulkSellCutoffGrade(player, gradeId)
end)

-- P2.5b A: 장비 계승 - 미리보기(RemoteFunction: 서버가 계산한 전후 능력치 · 비용 · 환급) · 실행(RemoteEvent) · 결과(성공 여부 · 이유 코드 또는 환급 종류).
-- 계승은 골드를 쓰고 두 장비를 되돌릴 수 없게 바꾼다 - 판매와 같은 즉시저장.
local ItemInherit = require(script.Parent.ItemInherit)

local inheritPreview = Instance.new("RemoteFunction")
inheritPreview.Name = "InheritPreview"
inheritPreview.Parent = ReplicatedStorage

local inheritRequest = Instance.new("RemoteEvent")
inheritRequest.Name = "InheritRequest"
inheritRequest.Parent = ReplicatedStorage

local inheritResult = Instance.new("RemoteEvent")
inheritResult.Name = "InheritResult"
inheritResult.Parent = ReplicatedStorage

inheritPreview.OnServerInvoke = function(player, part, bagIndex)
	local result, reason = ItemInherit.preview(player, part, bagIndex)
	return result or { error = reason }
end

inheritRequest.OnServerEvent:Connect(function(player, part, bagIndex, keep)
	local success, reason = ItemInherit.handle(player, part, bagIndex, keep)
	if success then
		ImmediateSave.request(player)
	end
	inheritResult:FireClient(player, success, reason)
end)

-- 장비창 위치도 잠금·일괄판매 기준과 같은 되돌릴 수 있는 UI 사건이다 - 즉시저장하지 않는다.
setInventoryWindowPositionRequest.OnServerEvent:Connect(function(player, x, y)
	if not PlayerProfile.getProfile(player) then
		return
	end
	PlayerProfile.setInventoryWindowPosition(player, x, y)
end)
