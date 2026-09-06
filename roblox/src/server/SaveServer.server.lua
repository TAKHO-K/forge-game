-- 로드/자동저장/퇴장저장/서버종료저장 배선. 실제 DataStore 호출은 SaveSystem, 실패·중단
-- 공통 처리는 SaveCoordinator, 메모리 상태는 PlayerProfile에 맡기고 여기서는 "언제
-- 부를지"만 잡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SaveSystem = require(script.Parent.SaveSystem)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)
local ImmediateSave = require(script.Parent.ImmediateSave)
local InventorySync = require(script.Parent.InventorySync)

local function loadForPlayer(player)
	local profile, err = SaveSystem.loadProfile(player)
	if not profile then
		warn(("[forge-game] 저장 데이터 불러오기 실패: %s - %s"):format(player.Name, tostring(err)))
		profile = SaveSystem.defaultProfile()
		PlayerProfile.init(player, profile)
		SaveCoordinator.notify(player, "저장 데이터를 불러오지 못했습니다. 이번 접속에서의 변경사항은 저장되지 않습니다.")
	else
		PlayerProfile.init(player, profile)
	end
	-- 인벤토리 UI(InventoryUI.client.lua)는 Attribute가 아니라 이 이벤트로 초기 상태를
	-- 받는다 - 접속 직후에도 한 번 밀어준다(이후 변경은 PlayerProfile의 각 뮤테이터가 push).
	InventorySync.push(player, profile)
end

Players.PlayerAdded:Connect(loadForPlayer)

-- ImmediateSave.flush를 쓴다(12-1 [0]) - 단순히 SaveCoordinator.saveForPlayer를 바로
-- 부르면, 예약돼 있던 trailing 저장(ImmediateSave.request)이 나중에 따로 또 fire되면서
-- 지금 이 저장과 겹쳐 경합할 수 있었다(낙관적 동시성 검사가 더 최신 저장을 stale로
-- 오판하는 사례를 11-1 테스트 중 실제로 재현했다). flush는 그 예약을 취소하고 지금
-- 한 번만 저장한다.
Players.PlayerRemoving:Connect(function(player)
	ImmediateSave.flush(player)
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
-- 안에 남은 플레이어를 전부 저장한다. PlayerRemoving과 같은 이유로 flush를 쓴다.
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		ImmediateSave.flush(player)
	end
end)
