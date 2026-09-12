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

local function notify(player, message)
	saveSuspended[player] = true
	saveNotice:FireClient(player, message)
	warn(("[forge-game] 저장 중단: %s - %s"):format(player.Name, message))
end

function SaveCoordinator.notify(player, message)
	notify(player, message)
end

function SaveCoordinator.saveForPlayer(player)
	if saveSuspended[player] then
		return
	end

	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return
	end

	local ok, err = SaveSystem.saveProfile(player, profile)
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
