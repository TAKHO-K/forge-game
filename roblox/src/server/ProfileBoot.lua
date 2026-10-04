-- QUEUE-MENU2: 프로필 로드 뒤 처리(옛 SaveServer.loadForPlayer 뒷부분) - 접속(첫 로드)과 캐릭터 전환(메뉴 → 다른 칸 · 새 캐릭터)이 같은 길을 탄다.
--   전환(opts.switch)일 때는 캐릭터에 딸린 것만 다시 민다(가방 · 보석 · 메인 퀘스트 · 도감 · 펫 속성 · 쿨/게이지/위치) - 계정 단위(복귀 부스트 · 감사 · 선물함 · 설정 · 결제 · 첫 스폰)는 접속 때만.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileBoot = {}

function ProfileBoot.apply(player, profile, err, opts)
	opts = opts or {}
	local SaveSystem = require(script.Parent.SaveSystem)
	local PlayerProfile = require(script.Parent.PlayerProfile)
	local SaveCoordinator = require(script.Parent.SaveCoordinator)
	local InventorySync = require(script.Parent.InventorySync)
	if not profile then
		warn(("[forge-game] 저장 데이터 불러오기 실패: %s - %s"):format(player.Name, tostring(err)))
		profile = SaveSystem.defaultProfile()
		PlayerProfile.init(player, profile)
		SaveCoordinator.notify(player, "저장 데이터를 불러오지 못했습니다. 이번 접속에서의 변경사항은 저장되지 않습니다.")
	else
		PlayerProfile.init(player, profile)
	end
	-- 인벤토리 UI는 Attribute가 아니라 이 이벤트로 초기 상태를 받는다 - 접속 · 전환 직후 한 번 밀어준다(이후 변경은 PlayerProfile의 각 뮤테이터가 push).
	InventorySync.push(player, profile)
	-- A2-N3: 클라 보석 탭의 첫 GemFetch가 로드 전에 돌면 빈 스냅샷 - 접속 · 전환 때 보석도 민다.
	require(script.Parent.GemSync).push(player)
	local classState = profile.classId and profile.classes and profile.classes[profile.classId]
	require(script.Parent.CharacterRuntime).restore(player, classState, opts.restorePosition) -- QUEUE-MENU2 D: 쿨 · 궁 게이지 · 마지막 위치
	if not opts.switch then
		if PlayerProfile.grantComebackIfAway(player) then -- C5-5 복귀 부스트(7일 이상 뒤 접속 → 60분 ×1.5) - 토스트
			require(script.Parent.Telemetry).custom(player, "Comeback", 1)
			task.spawn(function() -- 묶음 A 리뷰: AutoStage.server가 SystemNotice를 만들기 전 첫 접속자 경합 - 로드를 막지 않고 기다린다
				local notice = ReplicatedStorage:WaitForChild("SystemNotice", 10)
				if notice and player.Parent then
					notice:FireClient(player, require(ReplicatedStorage.Shared.Text).get("comeback.welcome"))
				end
			end)
		end
		task.spawn(require(script.Parent.AcquisitionAudit).auditProfile, player) -- S1: 원장 없는 태초 격리 · 확률 검사(자동 제재 없음)
	end
	require(script.Parent.QuestService).onLoaded(player) -- Q6: 날짜 넘김 · 화면 표(메인 퀘스트 = 캐릭터별)
	require(script.Parent.PetService).onLoaded(player) -- Q11: 데리고 다니는 펫 Attribute · 화면 표
	if not opts.switch then
		require(script.Parent.CommunityGoalService).onLoaded(player) -- QUEUE-ALL1 P3 §4
		require(script.Parent.WeeklyChallengeService).onLoaded(player) -- QUEUE-ALL1 P4 §3
		require(script.Parent.SocialRewardService).onLoaded(player) -- QUEUE-ALL1 P4 §1
	end
	require(script.Parent.CodexService).onLoaded(player) -- QUEUE-ALL1 P5: 도감 칸 판정 · 고른 칭호 Attribute
	if not opts.switch then
		if PlayerProfile.isFreshProfile(player) then -- QUEUE-ALL1 R1: 신규 첫 스폰 = 밝은 허브 광장(첫 캐릭터만)
			task.spawn(function()
				local character = player.Character or player.CharacterAdded:Wait()
				character:WaitForChild("HumanoidRootPart", 10)
				task.wait(0.5)
				require(script.Parent.Travel).placeFirstSpawn(player)
			end)
		end
		require(script.Parent.SettingsService).onLoaded(player) -- Q14: 저장된 설정을 Attribute로
		require(script.Parent.MonetizationService).onLoaded(player) -- QUEUE-B1 B2
	end
	return profile
end

return ProfileBoot
