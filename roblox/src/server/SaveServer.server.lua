-- 골드 등 영구 데이터의 로드/자동저장/퇴장저장/서버종료저장 배선. 실제 DataStore 호출은
-- SaveSystem에, 메모리 상태는 PlayerProfile에 맡기고 여기서는 "언제 부를지"만 잡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SaveSystem = require(script.Parent.SaveSystem)
local PlayerProfile = require(script.Parent.PlayerProfile)

local saveNotice = Instance.new("RemoteEvent")
saveNotice.Name = "SaveNotice"
saveNotice.Parent = ReplicatedStorage

-- 불러오기에 실패했거나(future_version/invalid_schema/재시도 소진) 저장이 다른 서버에
-- 밀린(stale_session) 플레이어는 이후 자동저장을 더 시도하지 않는다 - 잘못된(빈) 상태나
-- 낡은 상태를 실제 저장 위에 덮어쓸 위험을 원천 차단한다. 안내는 발생 시점에 한 번이면 된다.
local saveSuspended = {}

local function notify(player, message)
	saveSuspended[player] = true
	saveNotice:FireClient(player, message)
	warn(("[forge-game] 저장 중단: %s - %s"):format(player.Name, message))
end

local function loadForPlayer(player)
	local profile, err = SaveSystem.loadProfile(player)
	if not profile then
		warn(("[forge-game] 저장 데이터 불러오기 실패: %s - %s"):format(player.Name, tostring(err)))
		PlayerProfile.init(player, SaveSystem.defaultProfile())
		notify(player, "저장 데이터를 불러오지 못했습니다. 이번 접속에서 얻는 골드는 저장되지 않습니다.")
		return
	end
	PlayerProfile.init(player, profile)
end

local function saveForPlayer(player)
	if saveSuspended[player] then
		return
	end

	local profile = PlayerProfile.getProfile(player)
	if not profile then
		return
	end

	local ok, err = SaveSystem.saveProfile(player, profile)
	if ok then
		print(("[forge-game] 저장 성공: %s - gold=%d"):format(player.Name, profile.gold))
	else
		if err == "stale_session" then
			notify(player, "다른 서버에 더 최근 저장이 있어 지금 상태는 저장하지 않았습니다. 다시 접속해 주세요.")
		else
			warn(("[forge-game] 저장 실패: %s - %s"):format(player.Name, tostring(err)))
			notify(player, "저장에 반복 실패했습니다. 지금까지의 골드가 저장되지 않았을 수 있습니다.")
		end
	end
end

Players.PlayerAdded:Connect(loadForPlayer)

Players.PlayerRemoving:Connect(function(player)
	saveForPlayer(player)
	PlayerProfile.clear(player)
	saveSuspended[player] = nil
end)

-- 주기 자동저장. 간격 근거는 SaveConfig.autosaveIntervalSeconds 주석 참고.
task.spawn(function()
	while true do
		task.wait(SaveConfig.autosaveIntervalSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			saveForPlayer(player)
		end
	end
end)

-- 서버 종료 시 마지막 저장. BindToClose는 콜백이 끝날 때까지 서버 종료를 미룬다 - 그
-- 안에 남은 플레이어를 전부 저장한다.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveForPlayer(player)
	end
end)
