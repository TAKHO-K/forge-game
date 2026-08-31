-- 로드/자동저장/퇴장저장/서버종료저장 배선. 실제 DataStore 호출은 SaveSystem, 실패·중단
-- 공통 처리는 SaveCoordinator, 메모리 상태는 PlayerProfile에 맡기고 여기서는 "언제
-- 부를지"만 잡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SaveSystem = require(script.Parent.SaveSystem)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)

local function loadForPlayer(player)
	local profile, err = SaveSystem.loadProfile(player)
	if not profile then
		warn(("[forge-game] 저장 데이터 불러오기 실패: %s - %s"):format(player.Name, tostring(err)))
		PlayerProfile.init(player, SaveSystem.defaultProfile())
		SaveCoordinator.notify(player, "저장 데이터를 불러오지 못했습니다. 이번 접속에서의 변경사항은 저장되지 않습니다.")
		return
	end
	PlayerProfile.init(player, profile)
end

Players.PlayerAdded:Connect(loadForPlayer)

Players.PlayerRemoving:Connect(function(player)
	SaveCoordinator.saveForPlayer(player)
	PlayerProfile.clear(player)
end)

-- 주기 자동저장. 간격 근거는 SaveConfig.autosaveIntervalSeconds 주석 참고.
task.spawn(function()
	while true do
		task.wait(SaveConfig.autosaveIntervalSeconds)
		for _, player in ipairs(Players:GetPlayers()) do
			SaveCoordinator.saveForPlayer(player)
		end
	end
end)

-- 서버 종료 시 마지막 저장. BindToClose는 콜백이 끝날 때까지 서버 종료를 미룬다 - 그
-- 안에 남은 플레이어를 전부 저장한다.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		SaveCoordinator.saveForPlayer(player)
	end
end)
