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
	-- Attribute는 nil을 담지 못한다 - "선택 안 함"을 빈 문자열로 옮긴다. 클라이언트
	-- (ClassSelectUI.client.lua)는 "" 또는 미설정을 "선택 안 함"으로 취급한다.
	player:SetAttribute("ClassId", profile.classId or "")
	-- 무한 모드 스테이지(11-1). 둘 다 nil일 수 없는 필드라(SaveSystem.migrate v4 참고)
	-- classId처럼 빈 문자열로 바꿔치기할 필요가 없다.
	player:SetAttribute("InfiniteStage", profile.stageProgress.infinite)
	player:SetAttribute("InfiniteStageBest", profile.stageProgress.infiniteBest)
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

function PlayerProfile.getClassId(player)
	local profile = profiles[player]
	return profile and profile.classId
end

-- 서버만 호출한다(ClassServer의 검증 직후). 클라이언트가 보낸 classId를 그대로 믿지 않는다 -
-- 존재하는 클래스인지는 호출부(ClassServer.server.lua)가 ClassData로 이미 확인했다.
function PlayerProfile.setClassId(player, classId)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.classId = classId
	player:SetAttribute("ClassId", classId)
end

function PlayerProfile.getInfiniteStage(player)
	local profile = profiles[player]
	return profile and profile.stageProgress.infinite
end

function PlayerProfile.getInfiniteStageBest(player)
	local profile = profiles[player]
	return profile and profile.stageProgress.infiniteBest
end

-- 서버만 호출한다(StageServer의 검증 직후). 새 최고 기록을 세웠으면 true를 돌려준다 -
-- 호출부가 그때만 즉시저장(ImmediateSave)을 건다. 단순 이동(현재 스테이지 변경)은
-- 골드처럼 잃을 자원이 없는 되돌릴 수 있는 사건이라 주기저장(60초)·퇴장저장으로
-- 충분하다고 판단했다 - 최고 기록만 "다시 오르면 그만"이 아니라 경쟁 축(PRD 20.12)의
-- 실제 성취라 크래시로 잃으면 아쉬움이 다르다.
function PlayerProfile.setInfiniteStage(player, stage)
	local profile = profiles[player]
	if not profile then
		return false
	end
	profile.stageProgress.infinite = stage
	player:SetAttribute("InfiniteStage", stage)

	local isNewBest = stage > profile.stageProgress.infiniteBest
	if isNewBest then
		profile.stageProgress.infiniteBest = stage
		player:SetAttribute("InfiniteStageBest", stage)
	end
	return isNewBest
end

function PlayerProfile.clear(player)
	profiles[player] = nil
end

return PlayerProfile
