-- 로드/자동저장/퇴장저장/서버종료저장 배선. 실제 DataStore 호출은 SaveSystem, 실패·중단
-- 공통 처리는 SaveCoordinator, 메모리 상태는 PlayerProfile에 맡기고 여기서는 "언제
-- 부를지"만 잡는다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local SaveSystem = require(script.Parent.SaveSystem)
SaveSystem.runtimeHook = require(script.Parent.CharacterRuntime).capture -- QUEUE-MENU2 D: 저장 직전 쿨 · 게이지 · 위치
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)
local ImmediateSave = require(script.Parent.ImmediateSave)
local AcquisitionAudit = require(script.Parent.AcquisitionAudit)
AcquisitionAudit.start()
local QuestService = require(script.Parent.QuestService) -- Q6 G3 퀘스트 · 수련 Remote
QuestService.start()
local PetService = require(script.Parent.PetService) -- Q11 펫 Remote
PetService.start()
local CommunityGoalService = require(script.Parent.CommunityGoalService) -- QUEUE-ALL1 P3 §4 주간 합동 목표
CommunityGoalService.start()
local WeeklyChallengeService = require(script.Parent.WeeklyChallengeService) -- QUEUE-ALL1 P4 §3 주간 도전
WeeklyChallengeService.start()
require(script.Parent.CodexService) -- QUEUE-ALL1 P5 도감 v2(불러오는 순간 Remote 준비 - onLoaded = ProfileBoot)
local SocialRewardService = require(script.Parent.SocialRewardService) -- QUEUE-ALL1 P4 §1 · §2 초대 보상 · 코드
SocialRewardService.start()
local SettingsService = require(script.Parent.SettingsService) -- Q14 설정 저장 Remote
SettingsService.start()
local MonetizationService = require(script.Parent.MonetizationService) -- QUEUE-B1 B2 수익화(영수증 · 게임패스 · 정책 · 상점 창구 · 선물함)
MonetizationService.start()
require(script.Parent.Telemetry).start() -- Q15 T1 통계(몇 분마다 · 퇴장 때 전송 · Studio = 드라이런)

local function loadForPlayer(player)
	local profile, err, loadInfo = SaveSystem.loadProfile(player)
	if not player.Parent then
		-- QUEUE-ALL5 D②: 읽는(잠금 대기 최대 10초) 동안 나갔다 - PlayerRemoving(flush · clear)은 이미 지나갔으므로 여기서 init하면 프로필이 서버 수명 내내 남았다
		return
	end
	if loadInfo and loadInfo.negativeGold then -- QUEUE-6h-b 후속: 손상 저장 음수 골드 → 0(SaveSystem) - 통계 이벤트
		require(script.Parent.Telemetry).custom(player, "SaveNegativeGold", loadInfo.negativeGold)
	end
	if loadInfo and loadInfo.lockWaitedSeconds then -- 약한 세션 잠금 대기(초 · 풀리지 않았으면 음수)
		require(script.Parent.Telemetry).custom(player, "SaveSessionLockWait", loadInfo.lockReleased and loadInfo.lockWaitedSeconds or -loadInfo.lockWaitedSeconds)
	end
	if loadInfo and loadInfo.repaired then -- QUEUE-ALL4 C: 손상 저장 고침(SaveSystem.repairProfile) - 고친 칸 수
		require(script.Parent.Telemetry).custom(player, "SaveRepaired", #loadInfo.repaired)
	end
	if loadInfo and loadInfo.quarantined then -- QUEUE-ALL5 A3: 모르는 id 보관(옮긴 수 · 되돌린 수는 SaveQuarantineRestored · 0이면 안 보냄)
		if #loadInfo.quarantined > 0 then
			require(script.Parent.Telemetry).custom(player, "SaveQuarantined", #loadInfo.quarantined)
		end
		if (loadInfo.quarantineRestored or 0) > 0 then
			require(script.Parent.Telemetry).custom(player, "SaveQuarantineRestored", loadInfo.quarantineRestored)
		end
	end
	-- QUEUE-MENU2: 로드 뒤 처리 = ProfileBoot(캐릭터 전환과 같은 길) · 이어하기 위치 = 그 캐릭터 마지막 자리(첫 접속 계정은 허브 첫 스폰)
	require(script.Parent.ProfileBoot).apply(player, profile, err, { restorePosition = profile ~= nil and (tonumber(profile.savedAt) or 0) > 0 })
end

Players.PlayerAdded:Connect(loadForPlayer)

-- ImmediateSave.flush를 쓴다(12-1 [0]) - 단순히 SaveCoordinator.saveForPlayer를 바로
-- 부르면, 예약돼 있던 trailing 저장(ImmediateSave.request)이 나중에 따로 또 fire되면서
-- 지금 이 저장과 겹쳐 경합할 수 있었다(낙관적 동시성 검사가 더 최신 저장을 stale로
-- 오판하는 사례를 11-1 테스트 중 실제로 재현했다). flush는 그 예약을 취소하고 지금
-- 한 번만 저장한다.
local leavingCount = 0 -- QUEUE-ALL4 C: 퇴장 처리 중인 사람 수(종료 저장이 이것까지 기다린다 - 마지막 사람이 나가며 서버가 닫힐 때 퇴장 저장이 잘리지 않게)
Players.PlayerRemoving:Connect(function(player)
	leavingCount += 1
	pcall(function()
		require(script.Parent.Telemetry).onLeaving(player) -- Q15: 프로필을 지우기 전에 통계 전송
	end)
	SaveSystem.markReleasing(player, true) -- QUEUE-6h-b 후속: 퇴장 저장 = 마지막 저장 - 세션 잠금을 놓는다
	pcall(ImmediateSave.flush, player)
	SaveSystem.markReleasing(player, false)
	PlayerProfile.clear(player)
	SaveSystem.forgetSlotSession(player) -- QUEUE-MENU2 B: 캐릭터 칸 세션
	leavingCount -= 1
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
-- QUEUE-ALL4 C: 동시에 내보내고 퇴장 저장 · 진행 중 저장까지 마감(SaveConfig.shutdownSaveDeadlineSeconds) 안에 기다린다(ImmediateSave.flushAllForShutdown).
game:BindToClose(function()
	local done, seconds = ImmediateSave.flushAllForShutdown(Players:GetPlayers(), SaveConfig.shutdownSaveDeadlineSeconds, function(player)
		SaveSystem.markReleasing(player, true) -- 서버 종료 저장도 잠금을 놓는다
	end, function()
		return leavingCount > 0
	end)
	print(("[forge-game] 종료 저장: %s · %.1f초"):format(done and "전부 끝" or "마감 넘음(남은 저장은 잘릴 수 있다)", seconds))
end)
