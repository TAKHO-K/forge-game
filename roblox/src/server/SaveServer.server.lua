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
local AcquisitionAudit = require(script.Parent.AcquisitionAudit)
AcquisitionAudit.start()
local QuestService = require(script.Parent.QuestService) -- Q6 G3 퀘스트 · 수련 Remote
QuestService.start()
local PetService = require(script.Parent.PetService) -- Q11 펫 Remote
PetService.start()
local SettingsService = require(script.Parent.SettingsService) -- Q14 설정 저장 Remote
SettingsService.start()
local MonetizationService = require(script.Parent.MonetizationService) -- QUEUE-B1 B2 수익화(영수증 · 게임패스 · 정책 · 상점 창구 · 선물함)
MonetizationService.start()
require(script.Parent.Telemetry).start() -- Q15 T1 통계(몇 분마다 · 퇴장 때 전송 · Studio = 드라이런)

local function loadForPlayer(player)
	local profile, err, loadInfo = SaveSystem.loadProfile(player)
	if loadInfo and loadInfo.negativeGold then -- QUEUE-6h-b 후속: 손상 저장 음수 골드 → 0(SaveSystem) - 통계 이벤트
		require(script.Parent.Telemetry).custom(player, "SaveNegativeGold", loadInfo.negativeGold)
	end
	if loadInfo and loadInfo.lockWaitedSeconds then -- 약한 세션 잠금 대기(초 · 풀리지 않았으면 음수)
		require(script.Parent.Telemetry).custom(player, "SaveSessionLockWait", loadInfo.lockReleased and loadInfo.lockWaitedSeconds or -loadInfo.lockWaitedSeconds)
	end
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
	if PlayerProfile.grantComebackIfAway(player) then -- C5-5 복귀 부스트(7일 이상 뒤 접속 → 60분 ×1.5) - 토스트
		require(script.Parent.Telemetry).custom(player, "Comeback", 1) -- Q15 T1: 복귀(7일 이상 뒤 접속)
		task.spawn(function() -- 묶음 A 리뷰: AutoStage.server가 SystemNotice를 만들기 전 첫 접속자 경합 - 로드를 막지 않고 기다린다
			local notice = ReplicatedStorage:WaitForChild("SystemNotice", 10)
			if notice and player.Parent then
				notice:FireClient(player, require(ReplicatedStorage.Shared.Text).get("comeback.welcome"))
			end
		end)
	end
	task.spawn(AcquisitionAudit.auditProfile, player) -- S1: 원장 없는 태초 격리 · 확률 검사(자동 제재 없음)
	QuestService.onLoaded(player) -- Q6: 날짜 넘김 · 화면 표
	PetService.onLoaded(player) -- Q11: 데리고 다니는 펫 Attribute · 화면 표
	SettingsService.onLoaded(player) -- Q14: 저장된 설정을 Attribute로
	MonetizationService.onLoaded(player) -- QUEUE-B1 B2: 시즌 넘김 · 치장 Attribute · 게임패스 · 정책 · 선물함 팝업
end

Players.PlayerAdded:Connect(loadForPlayer)

-- ImmediateSave.flush를 쓴다(12-1 [0]) - 단순히 SaveCoordinator.saveForPlayer를 바로
-- 부르면, 예약돼 있던 trailing 저장(ImmediateSave.request)이 나중에 따로 또 fire되면서
-- 지금 이 저장과 겹쳐 경합할 수 있었다(낙관적 동시성 검사가 더 최신 저장을 stale로
-- 오판하는 사례를 11-1 테스트 중 실제로 재현했다). flush는 그 예약을 취소하고 지금
-- 한 번만 저장한다.
Players.PlayerRemoving:Connect(function(player)
	require(script.Parent.Telemetry).onLeaving(player) -- Q15: 프로필을 지우기 전에 통계 전송
	SaveSystem.markReleasing(player, true) -- QUEUE-6h-b 후속: 퇴장 저장 = 마지막 저장 - 세션 잠금을 놓는다
	ImmediateSave.flush(player)
	SaveSystem.markReleasing(player, false)
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
		SaveSystem.markReleasing(player, true) -- 서버 종료 저장도 잠금을 놓는다
		ImmediateSave.flush(player)
	end
end)
