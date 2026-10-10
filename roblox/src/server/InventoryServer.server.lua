-- 장비 착용/해제 서버 권위 처리(12-1 [4] 신설 → 16-6에서 갑옷 전용 → 3부위 공용으로
-- 일반화). 클라이언트는 인벤토리 안의 위치(index, 착용용) 또는 부위 이름(part, 해제용)만
-- 보낸다 - 그 자리에 실제로 뭐가 있는지, 착용이 유효한지는 전부 여기서(정확히는
-- PlayerProfile.equipItem/unequipItem 안에서) 검증한다.

local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RequestGate = require(script.Parent.RequestGate) -- QUEUE-6h-b 후속: 공통 요청 제한
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

-- action: "sell"(index 필요) · "sellGrades"(체크한 등급 + 확인 개수 - QUEUE-ALL8 G1) · "dismantleBulk". 옛 "sellBulk"(기준 이하)는 닫힘.
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
	if not RequestGate.allow(player, "EquipRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
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
sellRequest.OnServerEvent:Connect(function(player, action, arg, signature)
	if not RequestGate.allow(player, "SellRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return
	end

	if action == "sell" then
		if type(arg) ~= "number" then
			return
		end
		-- QUEUE-6h-b R2 · 리뷰: 칸 번호가 밀려(연타 · 지연) 다른 장비가 팔리지 않게 클라가 본 장비의 확인값과 대조(시간 간격은 지연이 길면 못 막고 정상 연속 판매를 버렸다)
		local item = profile.inventory[math.floor(arg)]
		if type(signature) ~= "string" or require(ReplicatedStorage.Shared.Loot).itemSignature(item) ~= signature then
			return
		end
		local price = PlayerProfile.sellItem(player, math.floor(arg))
		if price then
			ImmediateSave.request(player)
		end
	elseif action == "sellGrades" then -- QUEUE-ALL8 G1: 체크한 등급(쉼표 문자열 · 최대 3개) + 확인 창 개수(signature 자리) - 검사 · 판매는 서버(PlayerProfile.sellItemsByGrades)
		if type(arg) ~= "string" or #arg > 40 or type(signature) ~= "number" then
			return
		end
		local grades = string.split(arg, ",")
		local soldCount, _, why = PlayerProfile.sellItemsByGrades(player, grades, signature)
		if soldCount > 0 then
			ImmediateSave.request(player)
		elseif why == "count_mismatch" then -- QUEUE-ALL9A 2-2: 같은 Remote로 결과를 돌려준다(클라가 안내 + 새 개수로 확인 창 다시)
			sellRequest:FireClient(player, "sellGrades", false, why)
		end
	elseif action == "sellList" or action == "dismantleList" then -- UI-1 4단계(03 v3 §8 선택해서 정리): arg = { { index, signature } … }(최대 가방 칸) · 확인값 대조 · 큰 번호부터(앞 칸이 안 밀리게) · 잠금 · 판매 불가는 각 함수가 거른다
		if type(arg) ~= "table" or #arg == 0 or #arg > 200 then
			return
		end
		local Loot = require(ReplicatedStorage.Shared.Loot)
		-- UI-1b 0절(VERIFY-5): 같은 번호가 두 번 오면 첫 판매 뒤 한 칸 당겨진 다른 장비가 팔렸다 → 번호 중복 거름 + 처리 직전 확인값 다시 대조
		-- (착용 장비는 가방 밖 equipment라 번호로 닿지 않음 · 잠금 · 초월은 sellItem/dismantleItem이 거절)
		local list, seen = {}, {}
		for _, e in ipairs(arg) do
			if type(e) == "table" and type(e[1]) == "number" and type(e[2]) == "string" then
				local i = math.floor(e[1])
				local item = profile.inventory[i]
				if not seen[i] and item and Loot.itemSignature(item) == e[2] then
					seen[i] = true
					table.insert(list, { i, e[2] })
				end
			end
		end
		table.sort(list, function(a, b)
			return a[1] > b[1]
		end)
		local done = 0
		for _, e in ipairs(list) do
			local i, ok = e[1], false
			if Loot.itemSignature(profile.inventory[i]) ~= e[2] then
				continue
			end
			if action == "sellList" then
				ok = PlayerProfile.sellItem(player, i)
			else
				ok = PlayerProfile.dismantleItem(player, i)
			end
			if ok then
				done += 1
			end
		end
		if done > 0 then
			ImmediateSave.request(player)
		end
	elseif action == "sellBulk" then -- QUEUE-ALL8 G1: 옛 "기준 등급 이하" 일괄 판매(상한 전설) = 닫음 - 가방 UI가 sellGrades로 바뀌었다(전설 이상 일괄 판매 경로를 남기지 않는다)
		return
	elseif action == "dismantleBulk" then -- Q13: 등급 선택 일괄 분해(무료 · 잠금 · 초월 · 태초 보호 = Loot.isBulkDismantleTarget)
		if type(arg) ~= "string" or type(signature) ~= "number" then -- SEC-FIX-1 7: 확인 창 개수(signature 자리) 필수 - 판매(sellGrades)와 같은 모양
			return
		end
		local n, why = PlayerProfile.dismantleItemsUpTo(player, arg, math.floor(signature))
		if n > 0 then
			print(("[Q13] 일괄 분해: %s ~%s → 보석 %d개"):format(player.Name, arg, n))
			ImmediateSave.request(player)
		elseif why == "count_mismatch" then
			sellRequest:FireClient(player, "dismantleBulk", false, why) -- 클라 = 안내 + 새 개수로 확인 창 다시(판매와 같은 길)
		end
	else
		return
	end
end)

-- 잠금 토글은 착용/해제와 같은 되돌릴 수 있는 사건이다 - 즉시저장하지 않는다.
lockRequest.OnServerEvent:Connect(function(player, index, locked, confirmToken)
	if not RequestGate.allow(player, "LockRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
	if not PlayerProfile.getProfile(player) then
		return
	end
	if type(index) ~= "number" or type(locked) ~= "boolean" then
		return
	end
	PlayerProfile.setItemLocked(player, math.floor(index), locked, type(confirmToken) == "string" and confirmToken or nil)
end)

-- D1 [3] 태초 각성: (kind "bag" + 칸 index | "equip" + 부위) → 결과(AwakenResult: ok, 새 itemLevel | 이유). 골드를 쓰는 되돌릴 수 없는 사건 → 즉시 저장.
local awakenRequest = Instance.new("RemoteEvent")
awakenRequest.Name = "AwakenRequest"
awakenRequest.Parent = ReplicatedStorage
local awakenResult = Instance.new("RemoteEvent")
awakenResult.Name = "AwakenResult"
awakenResult.Parent = ReplicatedStorage
local lastAwakenAt = {}
awakenRequest.OnServerEvent:Connect(function(player, kind, key, expectedNo)
	if not PlayerProfile.getProfile(player) or (kind ~= "bag" and kind ~= "equip") then
		return
	end
	if os.clock() - (lastAwakenAt[player] or 0) < 0.5 then
		return
	end
	lastAwakenAt[player] = os.clock()
	if kind == "bag" and type(key) ~= "number" or kind == "equip" and type(key) ~= "string" then
		return
	end
	local ok, value = PlayerProfile.awakenItem(player, kind, kind == "bag" and math.floor(key) or key, type(expectedNo) == "number" and expectedNo or nil)
	if ok then
		ImmediateSave.request(player)
	end
	awakenResult:FireClient(player, ok, value)
end)
game:GetService("Players").PlayerRemoving:Connect(function(player)
	lastAwakenAt[player] = nil
end)

-- G1-2: 줍는 순간 자동 처리 설정(enabled · maxGrade) - 되돌릴 수 있는 설정이라 즉시저장하지 않는다. 값 검사는 PlayerProfile.setAutoProcess.
local autoProcessRequest = Instance.new("RemoteEvent")
autoProcessRequest.Name = "AutoProcessRequest"
autoProcessRequest.Parent = ReplicatedStorage
autoProcessRequest.OnServerEvent:Connect(function(player, enabled, maxGrade)
	if not RequestGate.allow(player, "AutoProcessRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
	if not PlayerProfile.getProfile(player) then
		return
	end
	PlayerProfile.setAutoProcess(player, enabled, maxGrade)
end)

-- 일괄판매 기준 등급 선택도 잠금과 같은 되돌릴 수 있는 사건이다 - 즉시저장하지 않는다.
bulkSellCutoffRequest.OnServerEvent:Connect(function(player, gradeId)
	if not RequestGate.allow(player, "BulkSellCutoffRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
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
	return RequestGate.invoke(player, "InheritPreview", tostring(part) .. ":" .. tostring(bagIndex), function() -- QUEUE-6h-b 후속: 공통 요청 제한
		local result, reason = ItemInherit.preview(player, part, bagIndex)
		return result or { error = reason }
	end)
end

inheritRequest.OnServerEvent:Connect(function(player, part, bagIndex, keep)
	if not RequestGate.allow(player, "InheritRequest") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
	local success, reason = ItemInherit.handle(player, part, bagIndex, keep)
	if success then
		ImmediateSave.request(player)
	end
	inheritResult:FireClient(player, success, reason)
end)

-- 장비창 위치도 잠금·일괄판매 기준과 같은 되돌릴 수 있는 UI 사건이다 - 즉시저장하지 않는다.
setInventoryWindowPositionRequest.OnServerEvent:Connect(function(player, x, y)
	if not RequestGate.allow(player, "SetInventoryWindowPosition") then
		return -- QUEUE-6h-b 후속: 공통 요청 제한(RequestLimitConfig)
	end
	if not PlayerProfile.getProfile(player) then
		return
	end
	PlayerProfile.setInventoryWindowPosition(player, x, y)
end)
