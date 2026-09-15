-- 보석 상태(5슬롯 + 보석 인벤토리 + 옵션 변환권 보유량)를 클라이언트로 미는 통로 하나
-- (23-2, InventorySync.lua와 완전히 같은 이유·같은 패턴). 인벤토리와 마찬가지로 배열/
-- 테이블이라 Attribute(스칼라 전용)에 못 담아 전용 RemoteEvent로 전체 스냅샷을 보낸다.
--
-- PlayerProfile의 보석 뮤테이터(rebirth·dismantleItem·equipGem·rerollGemOption)가 전부
-- 이 모듈 하나를 거쳐 push한다 - 호출부(RebirthServer/GemServer.server.lua)가 각자
-- push를 잊는 사고를 막는다(실제로 이번 세션에 났던 버그 - 환생 직후 보석 탭이 갱신되지
-- 않았다. RebirthServer.server.lua에만 push를 추가했다가, DevTools "/gg rebirthdo"처럼
-- PlayerProfile.rebirth를 직접 부르는 경로는 여전히 안 됐다 - 호출부마다 따로 챙기는 대신
-- PlayerProfile 자신이 push하게 만들어야 이런 누락이 구조적으로 안 생긴다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gemSync = Instance.new("RemoteEvent")
gemSync.Name = "GemSync"
gemSync.Parent = ReplicatedStorage

-- 클라이언트 스크립트가 붙는 시점과 무관하게 초기 상태를 받을 수 있어야 한다(InventoryFetch와
-- 같은 이유) - "지금 상태 알려줘"를 RemoteFunction으로 따로 둔다.
local gemFetch = Instance.new("RemoteFunction")
gemFetch.Name = "GemFetch"
gemFetch.Parent = ReplicatedStorage

local PlayerProfile

local GemSync = {}

local function snapshot(player)
	PlayerProfile = PlayerProfile or require(script.Parent.PlayerProfile)
	local weapon = PlayerProfile.getWeapon(player)
	if not weapon then
		return {
			gems = { false, false, false, false, false },
			slotUnlocked = { false, false, false, false, false },
			gemInventory = {},
			rerollTickets = { ancient = 0, primordial = 0 },
		}
	end
	return {
		gems = weapon.gems,
		-- 23-4: 클라이언트가 매번 rebirthCount에서 잠금 여부를 다시 계산하지 않고 저장된
		-- 값을 그대로 받는다(Gem.isSlotUnlocked, GemData.slotUnlockRequiredRebirth 주석 참고).
		slotUnlocked = weapon.slotUnlocked,
		gemInventory = PlayerProfile.getGemInventory(player),
		rerollTickets = PlayerProfile.getOptionRerollTickets(player),
	}
end

function GemSync.push(player)
	gemSync:FireClient(player, snapshot(player))
end

gemFetch.OnServerInvoke = function(player)
	return snapshot(player)
end

return GemSync
