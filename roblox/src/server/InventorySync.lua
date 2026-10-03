-- 인벤토리 상태를 클라이언트로 미는 통로 하나(12-1). 인벤토리는 Attribute로 못 담는
-- 배열이라(Gold·ClassId 같은 스칼라와 다르다) 전용 RemoteEvent로 전체 스냅샷을 보낸다 -
-- PlayerProfile의 여러 뮤테이터(드랍 추가·착용·해제)가 전부 이 모듈 하나를 거쳐 push하므로,
-- 클라이언트가 놓치는 변경이 생기지 않는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArtImportData = require(ReplicatedStorage.Shared.data.ArtImportData) -- A2-N3 착용 표시 Attribute 이름
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local inventorySync = Instance.new("RemoteEvent")
inventorySync.Name = "InventorySync"
inventorySync.Parent = ReplicatedStorage

-- G1-2: 줍는 순간 자동 처리 알림(클라 토스트) - { kind = "dismantle" | "sell", grade, part, gold }.
local autoProcessed = Instance.new("RemoteEvent")
autoProcessed.Name = "AutoProcessed"
autoProcessed.Parent = ReplicatedStorage

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
local RequestGate = require(script.Parent.RequestGate) -- QUEUE-6h-b 후속: 공통 요청 제한
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData) -- QUEUE-B1 B2: 가방 확장 게임패스

local InventorySync = {}

-- QUEUE-10h Q13 가방 칸 수(식 한 곳): 저장값(inventorySlots = 옛 기본 20 + 마일스톤) + 실험 스위치(SaveConfig.bagBaseSlots − 20). 저장은 건드리지 않는다.
--   주의(리뷰): defaultInventorySlots(20)는 "저장값의 기준"으로 고정한다 - 새 계정 기본 칸을 늘리고 싶으면 이 값이 아니라 bagBaseSlots를 올린다(둘 다 올리면 이중으로 더해지거나 0이 된다).
function InventorySync.capacity(profile)
	-- QUEUE-B1 B2: 게임패스 bagExpand(편의) = + bonusSlots(캐시 profile.gamepasses - 패스를 잃으면 칸만 줄고 든 장비는 그대로 · 더 넣기만 막힌다)
	local passBonus = profile and type(profile.gamepasses) == "table" and profile.gamepasses.bagExpand and MonetizationData.gamePasses.bagExpand.bonusSlots or 0
	-- QUEUE-ALL9C 1-6: 가방 칸 출처(스타터 팩 +20 · 출처별 한 번 - purchases.bagSources) · 합계 상한 bagMaxSlots(75)
	local sourceBonus = 0
	local sources = profile and type(profile.purchases) == "table" and type(profile.purchases.bagSources) == "table" and profile.purchases.bagSources or {}
	for id, source in pairs(MonetizationData.bagSources or {}) do
		if sources[id] then
			sourceBonus += source.slots
		end
	end
	local total = (profile and profile.inventorySlots or 0) + math.max(0, (SaveConfig.bagBaseSlots or SaveConfig.defaultInventorySlots) - SaveConfig.defaultInventorySlots) + passBonus + sourceBonus
	return math.min(total, math.max(MonetizationData.bagMaxSlots or total, profile and profile.inventorySlots or 0))
end

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
		slots = InventorySync.capacity(profile), -- Q13: 실험 스위치 포함
		armor = equipment.armor,
		gloves = equipment.gloves,
		shoes = equipment.shoes,
	}
end

-- D1 ⑤: 태초 착용 여부 → Player Attribute PrimordialEquipped(클라 흰 오라 · 이름표 문양 · 살펴보기가 읽는다). 착용 · 해제 · 직업 변경이 전부 push를 거친다.
function InventorySync.primordialEquipped(profile)
	local equipment = activeEquipment(profile)
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		if equipment[part] and equipment[part].grade == "primordial" then
			return true
		end
	end
	return false
end

-- D1-2: 착용한 태초 부위 목록("gloves,shoes" 모양 · 없으면 "") → Player Attribute PrimordialParts(클라 PrimordialFx: 장갑 = 강공격 흰 번개 · 신발 = 자리만 - 발자국은 D1-3에서 삭제).
function InventorySync.primordialParts(profile)
	local equipment = activeEquipment(profile)
	local parts = {}
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		if equipment[part] and equipment[part].grade == "primordial" then
			table.insert(parts, part)
		end
	end
	return table.concat(parts, ",")
end

function InventorySync.push(player, profile)
	inventorySync:FireClient(player, InventorySync.snapshot(profile))
	if typeof(player) == "Instance" and player:IsA("Player") then
		player:SetAttribute("PrimordialEquipped", InventorySync.primordialEquipped(profile))
		player:SetAttribute("PrimordialParts", InventorySync.primordialParts(profile))
		local equipment = activeEquipment(profile) -- A2-N3 방어구 착용 표시(화면 전용 복사본 · 저장 아님): ArmorLook_<부위> = "<구역>|<등급>" · 안 입음 = nil
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			local item = equipment[part]
			player:SetAttribute(ArtImportData.armorLookAttribute .. part, item and (ArtMeshKit.armorZone(item) .. "|" .. tostring(item.grade)) or nil)
		end
	end
end

inventoryFetch.OnServerInvoke = function(player)
	-- 순환 require 방지: PlayerProfile이 이 모듈을 require하므로, 여기서는 호출 시점에만
	-- 늦게(lazy) require한다.
	PlayerProfile = PlayerProfile or require(script.Parent.PlayerProfile)
	return RequestGate.invoke(player, "InventoryFetch", "", function() -- QUEUE-6h-b 후속: 공통 요청 제한
		local profile = PlayerProfile.getProfile(player)
		if not profile then
			return { inventory = {}, armor = nil, gloves = nil, shoes = nil }
		end
		return InventorySync.snapshot(profile)
	end)
end

-- 칸이 가득 차서 줍지 못했을 때 한 번 알린다(12-1 [3]에서는 "드랍 자체를 포기"였으나
-- 14-1부터는 "땅에 있는 아이템을 줍지 못했다"는 뜻으로 바뀌었다 - 아이템은 땅에 그대로
-- 남는다, ItemDropServer.server.lua 참고).
function InventorySync.notifyFull(player)
	inventoryFull:FireClient(player)
end

-- G1-2: 줍는 순간 자동 처리 알림.
function InventorySync.notifyAutoProcessed(player, info)
	if typeof(player) == "Instance" and player:IsA("Player") then
		autoProcessed:FireClient(player, info)
	end
end

return InventorySync
