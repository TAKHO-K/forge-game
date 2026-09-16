-- 저장 시도 하나의 공통 처리(성공 로그·실패 재시도 결과 안내·세션 중단 플래그). 10-1에서는
-- 주기 자동저장(SaveServer.server.lua)만 이 경로를 썼지만, 10-2부터 강화 등 즉시저장
-- 트리거(EnhanceServer.server.lua)도 같은 경로를 쓴다 - 실패·중단 처리를 호출부마다 따로
-- 만들면 한쪽만 고치고 잊어버리기 쉽다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveSystem = require(script.Parent.SaveSystem)
local PlayerProfile = require(script.Parent.PlayerProfile)

local saveNotice = Instance.new("RemoteEvent")
saveNotice.Name = "SaveNotice"
saveNotice.Parent = ReplicatedStorage

local SaveCoordinator = {}

-- 불러오기에 실패했거나(future_version/invalid_schema/재시도 소진) 저장이 다른 서버에
-- 밀린(stale_session) 플레이어는 이후 저장을 더 시도하지 않는다 - 잘못된(빈) 상태나 낡은
-- 상태를 실제 저장 위에 덮어쓸 위험을 원천 차단한다. 안내는 발생 시점에 한 번이면 된다.
-- 약한 키 테이블 - 플레이어가 나가면 Player 인스턴스를 계속 붙들고 있을 이유가 없다
-- (AttackInput.client.lua의 activeStacks와 같은 이유, 퇴장 때 수동으로 지울 필요가 없다).
local saveSuspended = setmetatable({}, { __mode = "k" })

-- 19-3a: 밸런스 테스트 도구(DevTools.server.lua) 전용 저장 차단. saveSuspended와 일부러
-- 분리한다 - 그쪽은 "저장이 실패해 안내가 필요한" 에러 상태고, 이건 "지금 프로필이 가짜
-- 테스트값이라 정상 상태다"라는 다른 이유다. 여기 걸리면 클라이언트 알림(SaveNotice)도
-- warn 로그도 없다 - 개발자가 의도적으로 켠 상태이지 사고가 아니다. 주기 자동저장
-- (SaveServer.server.lua)과 퇴장 즉시저장(ImmediateSave.flush) 둘 다 saveForPlayer
-- 하나만 거치므로, 여기 한 곳만 막으면 두 경로 모두 안전하다.
local devToolsSuspended = setmetatable({}, { __mode = "k" })

-- 24-2 크로스서버 파티(PRD 20.63) 전용 저장 동결. PartyCrossServer가 텔레포트 직전에 ImmediateSave.flush로
-- 마지막 저장을 끝낸 뒤 이 플래그를 켠다 - 그 뒤 출발 서버에서 일어나는 퇴장 저장(PlayerRemoving → flush)·
-- 주기 자동저장은 전부 건너뛴다. 이유: 텔레포트로 나간 플레이어는 도착 서버에서 곧바로 프로필을 읽는데,
-- 출발 서버의 퇴장 저장이 그보다 늦게 끝나면 도착 서버가 옛 값을 읽고(손실) 도착 서버의 다음 저장은
-- savedAt 비교에서 stale_session으로 밀린다(저장 중단). "마지막 쓰기 = 텔레포트 호출 전에 끝난 flush"로
-- 고정하면 이 경합이 구조적으로 사라진다. 텔레포트가 실패하면 PartyCrossServer가 다시 끈다.
local teleportFrozen = setmetatable({}, { __mode = "k" })

-- 24-2: 플레이어당 저장 하나만 동시에 나간다. 주기 자동저장이 UpdateAsync를 기다리는 사이(yield) 다른 경로
-- (텔레포트 직전 flush·강화 즉시저장)가 같은 baseline(savedAt)으로 두 번째 UpdateAsync를 시작하면, 먼저 끝난
-- 쪽이 savedAt을 올려 두 번째가 stale_session으로 오판된다 - 그 순간부터 그 플레이어의 저장이 전부 중단된다
-- (24-2 크로스서버 검증 중 실제 발생: 자동저장 60초 틱과 flush가 같은 초에 겹쳤다). 두 번째 요청은 앞선 저장이
-- 끝날 때까지 기다린 뒤 갱신된 baseline으로 저장한다 - ImmediateSave.flush가 "예약된" trailing 저장을 취소하는
-- 것과 별개로, "이미 나간" 저장과의 겹침은 여기서 막는다.
local saving = setmetatable({}, { __mode = "k" })

local function notify(player, message)
	saveSuspended[player] = true
	saveNotice:FireClient(player, message)
	warn(("[forge-game] 저장 중단: %s - %s"):format(player.Name, message))
end

function SaveCoordinator.notify(player, message)
	notify(player, message)
end

-- DevTools.server.lua만 호출한다. suspended=true인 동안 saveForPlayer는 조용히
-- 아무것도 하지 않는다 - 테스트 조건이 DataStore에 반영되는 일을 원천 차단한다.
function SaveCoordinator.setDevToolsSuspended(player, suspended)
	if suspended then
		devToolsSuspended[player] = true
	else
		devToolsSuspended[player] = nil
	end
end

function SaveCoordinator.setTeleportFrozen(player, frozen)
	if frozen then
		teleportFrozen[player] = true
	else
		teleportFrozen[player] = nil
	end
end

function SaveCoordinator.saveForPlayer(player)
	if devToolsSuspended[player] then
		return
	end
	if teleportFrozen[player] then
		return
	end
	if saveSuspended[player] then
		return
	end

	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return
	end

	while saving[player] do
		task.wait()
	end
	if PlayerProfile.getProfile(player) ~= profile or teleportFrozen[player] or saveSuspended[player] then
		return -- 기다리는 동안 프로필이 지워졌거나(퇴장) 동결·중단됐다
	end
	saving[player] = true
	local ok, err = SaveSystem.saveProfile(player, profile)
	saving[player] = nil
	if ok then
		-- 19-1: 무기는 이제 활성 직업(profile.classId)에 딸려 있다 - 아직 직업을 안 골랐으면
		-- (classId=nil) weapon 자체가 없으니 로그에서도 그 상태를 그대로 보여준다.
		local weapon = PlayerProfile.getWeapon(player)
		print(("[forge-game] 저장 성공: %s - gold=%d, classId=%s, weaponLevel=%s"):format(
			player.Name, profile.gold, tostring(profile.classId), weapon and tostring(weapon.level) or "없음"))
	else
		if err == "stale_session" then
			notify(player, "다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다. 다시 접속해 주세요.")
		else
			warn(("[forge-game] 저장 실패: %s - %s"):format(player.Name, tostring(err)))
			notify(player, "저장에 반복 실패했습니다. 지금까지의 변경사항이 저장되지 않았을 수 있습니다.")
		end
	end
end

return SaveCoordinator
