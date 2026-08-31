-- 플레이어 영구 저장 데이터(골드 등) 단일 관리 통로. PlayerState(전투 중 HP)와 일부러
-- 분리했다 - HP는 리스폰마다 초기화되지만 골드는 그러면 안 된다. 같은 테이블에 두면
-- PlayerState.reset() 같은 리스폰 훅이 실수로 같이 건드릴 위험이 생긴다.
-- 실제 로드/저장(DataStore)은 SaveSystem이 한다 - 이 모듈은 서버 메모리에 올라온
-- 프로필을 들고 있다가 값을 읽고 쓰는 것만 한다.

local PlayerProfile = {}

-- [Player] = profile 테이블(SaveSystem.defaultProfile()/migrate()와 같은 스키마)
local profiles = {}

-- 로드가 끝난 뒤(SaveServer.server.lua) 호출한다. Gold·WeaponLevel Attribute도 여기서
-- 같이 맞춰서 HUD·강화 UI가 접속 직후부터 정확한 값을 보게 한다.
function PlayerProfile.init(player, profile)
	profiles[player] = profile
	player:SetAttribute("Gold", profile.gold)
	player:SetAttribute("WeaponLevel", profile.equipment.weapon.level)
end

-- 저장 시점에 SaveSystem이 통째로 넘겨받아 쓴다.
function PlayerProfile.getProfile(player)
	return profiles[player]
end

function PlayerProfile.getGold(player)
	local profile = profiles[player]
	return profile and profile.gold
end

-- 서버만 호출한다(AttackServer의 몬스터 처치 판정 직후). 클라이언트가 보낸 값으로
-- 골드를 늘리는 경로는 없다 - 이 함수가 유일한 증가 통로다.
function PlayerProfile.addGold(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.gold += amount
	player:SetAttribute("Gold", profile.gold)
end

-- 골드가 충분하면 차감하고 true, 부족하면 아무것도 바꾸지 않고 false(10-2 [3] - 확인과
-- 차감을 분리하면 그 사이에 값이 바뀔 여지가 생긴다. 여긴 한 함수 안에서 원자적으로 처리).
function PlayerProfile.trySpendGold(player, amount)
	local profile = profiles[player]
	if not profile or profile.gold < amount then
		return false
	end
	profile.gold -= amount
	player:SetAttribute("Gold", profile.gold)
	return true
end

function PlayerProfile.getWeapon(player)
	local profile = profiles[player]
	return profile and profile.equipment.weapon
end

-- 서버만 호출한다(EnhanceServer의 강화 판정 직후). 클라이언트가 보낸 값을 믿지 않는다.
function PlayerProfile.setWeaponLevel(player, level)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.equipment.weapon.level = level
	player:SetAttribute("WeaponLevel", level)
end

function PlayerProfile.clear(player)
	profiles[player] = nil
end

return PlayerProfile
