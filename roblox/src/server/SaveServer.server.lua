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
local CommunityGoalService = require(script.Parent.CommunityGoalService) -- QUEUE-ALL1 P3 §4 주간 합동 목표
CommunityGoalService.start()
local WeeklyChallengeService = require(script.Parent.WeeklyChallengeService) -- QUEUE-ALL1 P4 §3 주간 도전
WeeklyChallengeService.start()
local CodexService = require(script.Parent.CodexService) -- QUEUE-ALL1 P5 도감 v2
local SocialRewardService = require(script.Parent.SocialRewardService) -- QUEUE-ALL1 P4 §1 · §2 초대 보상 · 코드
SocialRewardService.start()
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
	if loadInfo and loadInfo.repaired then -- QUEUE-ALL4 C: 손상 저장 고침(SaveSystem.repairProfile) - 고친 칸 수
		require(script.Parent.Telemetry).custom(player, "SaveRepaired", #loadInfo.repaired)
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
	-- A2-N3 버그 수정(가방 보석 탭 0 vs 서버 1): 클라 보석 탭의 첫 GemFetch가 로드 전에 돌면 빈 스냅샷(무기 없음)을 받고, 접속 때 보석은 밀지 않아 다음 보석 변경 전까지 0에 머물렀다.
	require(script.Parent.GemSync).push(player)
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
	CommunityGoalService.onLoaded(player) -- QUEUE-ALL1 P3 §4: 내 기여 · 받은 칸 Attribute
	WeeklyChallengeService.onLoaded(player) -- QUEUE-ALL1 P4 §3: 지난주 순위 보상
	SocialRewardService.onLoaded(player) -- QUEUE-ALL1 P4 §1: 초대받은 첫 접속 보상
	CodexService.onLoaded(player) -- QUEUE-ALL1 P5: 도감 칸 판정 · 고른 칭호 Attribute
	if PlayerProfile.isFreshProfile(player) then -- QUEUE-ALL1 R1: 신규 첫 스폰 = 밝은 허브 광장(첫 캐릭터만)
		task.spawn(function()
			local character = player.Character or player.CharacterAdded:Wait()
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.5)
			require(script.Parent.Travel).placeFirstSpawn(player)
		end)
	end
	SettingsService.onLoaded(player) -- Q14: 저장된 설정을 Attribute로
	MonetizationService.onLoaded(player) -- QUEUE-B1 B2: 시즌 넘김 · 치장 Attribute · 게임패스 · 정책 · 선물함 팝업
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
