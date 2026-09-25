-- 인벤토리 상태를 클라이언트로 미는 통로 하나(12-1). 인벤토리는 Attribute로 못 담는
-- 배열이라(Gold·ClassId 같은 스칼라와 다르다) 전용 RemoteEvent로 전체 스냅샷을 보낸다 -
-- PlayerProfile의 여러 뮤테이터(드랍 추가·착용·해제)가 전부 이 모듈 하나를 거쳐 push하므로,
-- 클라이언트가 놓치는 변경이 생기지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local inventorySync = Instance.new("RemoteEvent")
inventorySync.Name = "InventorySync"
inventorySync.Parent = ReplicatedStorage

-- G1-2: 줍는 순간 자동 처리 알림(클라 토스트) - { kind = "dismantle" | "sell", grade, part, gold }.
local autoProcessed = Instance.new("RemoteEvent")
autoProcessed.Name = "AutoProcessed"
autoProcessed.Parent = ReplicatedStorage

function InventorySync.notifyAutoProcessed(player, info)
	if typeof(player) == "Instance" and player:IsA("Player") then
		autoProcessed:FireClient(player, info)
	end
end

local inventoryFull = Instance.new("RemoteEvent")
inventoryFull.Name = "InventoryFull"
inventoryFull.Parent = ReplicatedStorage

-- 클라이언트 스크립트가 언제 시작되는지(접속 직후 push보다 늦게 붙을 수 있다)와 무관하게
-- 초기 상태를 받을 수 있어야 한다 - Gold 등 Attribute 기반 HUD는 "지금 값을 바로 읽고,
-- 이후 변경은 이벤트로" 패턴이 되지만 인벤토리는 Attribute가 아니라 이벤트뿐이라 같은
-- 패턴을 못 쓴다. 그래서 RemoteFunction으로 "지금 상태 알려줘"를 따로 둔다.
local inventoryFetch = Instance.new("RemoteFunction")
inventoryFetch.Name = "InventoryFetch"
inventoryFetch.Parent = ReplicatedStorage

local PlayerProfile

local InventorySync = {}

-- 19-1: 장비는 이제 profile.classes[profile.classId] 아래에 있다. classId 미선택이면
-- (classes 인덱스 자체가 없다) 셋 다 nil로 취급한다 - 아직 착용할 직업이 없는 상태다.
local function activeEquipment(profile)
	local classState = profile.classId and profile.classes[profile.classId]
	return classState and classState.equipment or { armor = nil, gloves = nil, shoes = nil }
end

-- 스냅샷 한 모양(push · fetch · 검증이 같은 함수). slots = 가방 칸 수의 단일 출처(profile.inventorySlots) - 클라는 이 값으로 "n / 칸 수" · 빈 칸 · 해제 미리 판정을 그린다(상수를 읽지 않는다).
function InventorySync.snapshot(profile)
	local equipment = activeEquipment(profile)
	return {
		inventory = profile.inventory,
		slots = profile.inventorySlots,
		armor = equipment.armor,
		gloves = equipment.gloves,
		shoes = equipment.shoes,
	}
end

function InventorySync.push(player, profile)
	inventorySync:FireClient(player, InventorySync.snapshot(profile))
end

inventoryFetch.OnServerInvoke = function(player)
	-- 순환 require 방지: PlayerProfile이 이 모듈을 require하므로, 여기서는 호출 시점에만
	-- 늦게(lazy) require한다.
	PlayerProfile = PlayerProfile or require(script.Parent.PlayerProfile)
	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return { inventory = {}, armor = nil, gloves = nil, shoes = nil }
	end
	return InventorySync.snapshot(profile)
end

-- 칸이 가득 차서 줍지 못했을 때 한 번 알린다(12-1 [3]에서는 "드랍 자체를 포기"였으나
-- 14-1부터는 "땅에 있는 아이템을 줍지 못했다"는 뜻으로 바뀌었다 - 아이템은 땅에 그대로
-- 남는다, ItemDropServer.server.lua 참고).
function InventorySync.notifyFull(player)
	inventoryFull:FireClient(player)
end

return InventorySync
