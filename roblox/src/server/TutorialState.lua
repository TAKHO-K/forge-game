-- 견습 모드(튜토리얼, 23-1) 진행 단일 관리 통로. PRD-forge-game-roblox.md 20.29/20.47을
-- 구현한다. PlayerState(전투 중 HP)/PlayerProfile(영구 저장)과 같은 분리 원칙 - 이 모듈은
-- "지금 이 세션에서 견습이 진행 중인가"라는 세션 상태만 들고 있고, 실제로 남아야 하는 값
-- (몇 단계인지·완료했는지·무엇을 받았는지)은 PlayerProfile.getTutorial*/setTutorial*를 거쳐
-- 저장 데이터(profile.tutorial)에 둔다 - 서버가 죽어도 진행도 자체는 살아남는다.
--
-- 지시 "읽는 쪽이 현재 모드를 보고 어느 값을 쓸지 고른다" - TutorialState.getMonsterStage가
-- 그 판단 지점 하나다. 이전에 여러 서버 스크립트가 각자 PlayerProfile.getInfiniteStage를
-- 직접 읽던 자리(AttackServer/SkillServer/MonsterAI/CombatResolution)를 전부 이 함수
-- 호출로 바꿨다 - 무한 모드 stageProgress.infinite 자체는 절대 건드리지 않는다(견습 중에도
-- 그 값은 그대로 저장돼 있다가, 견습을 나가는 순간 다시 읽힌다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TutorialData = require(ReplicatedStorage.Shared.data.TutorialData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local EquipSlots = require(ReplicatedStorage.Shared.data.EquipSlots)
local Loot = require(ReplicatedStorage.Shared.Loot)
local PlayerProfile = require(script.Parent.PlayerProfile)
local MonsterState = require(script.Parent.MonsterState)
local BossEncounter = require(script.Parent.BossEncounter)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ImmediateSave = require(script.Parent.ImmediateSave)

local TutorialState = {}

local tutorialStepNotice = Instance.new("RemoteEvent")
tutorialStepNotice.Name = "TutorialStepNotice"
tutorialStepNotice.Parent = ReplicatedStorage

local tutorialChallengeBossRequest = Instance.new("RemoteEvent")
tutorialChallengeBossRequest.Name = "TutorialChallengeBossRequest"
tutorialChallengeBossRequest.Parent = ReplicatedStorage

-- [Player] = 지금 진행 중인 단계(1~7). 견습 중이 아니면 nil - 이 하나로 "지금 모드"를
-- 판단한다(BossEncounter.activeBosses의 "테이블에 있으면 활성"과 같은 단일 진실 원천 원칙).
local activeStep = {}
local killCounts = {} -- [Player] = 이번 단계에서 처치한 수(재접속·재도전 시 0으로 리셋)
local timerThreads = {} -- [Player] = 단계 상한(5분) task.delay 핸들

-- 대여 적용(23-1 (나) 권장안 - 별도 슬롯 대신 classState.weapon.grade/equipment를 직접
-- 덮어쓴다, "임의 결정" 목록 참고). 무기는 EquipSlots 대상이 아니라(WeaponData.lua 주석 -
-- 무기는 하나뿐이고 grade만 바뀐다) setWeaponGrade 하나로 충분하다 - 대여 무기를 플레이어가
-- "해제"할 방법 자체가 게임에 없어 되돌려받지 못할 경로가 구조적으로 없다. 갑옷 3부위는
-- 해제가 가능한 슬롯이라 locked=true로 최소한 판매만 막는다(완전한 반납 강제는 전용 슬롯이
-- 있어야 한다 - 이번 세션 범위 밖, 보고서 참고).
local function applyLend(player, lend, tierIndex)
	if PlayerProfile.getTutorialLendBaseline(player) == nil then
		local weapon = PlayerProfile.getWeapon(player)
		PlayerProfile.setTutorialLendBaseline(player, {
			weaponGrade = weapon.grade,
			armor = PlayerProfile.getEquipped(player, "armor"),
			gloves = PlayerProfile.getEquipped(player, "gloves"),
			shoes = PlayerProfile.getEquipped(player, "shoes"),
		})
	end

	PlayerProfile.setWeaponGrade(player, lend.weaponGrade)
	if lend.armorGrade then
		local level = PlayerProfile.getCharacterLevel(player) or 1
		for _, part in ipairs(EquipSlots.order) do
			PlayerProfile.setEquippedDirect(player, part, {
				grade = lend.armorGrade,
				part = part,
				dropStage = TutorialData.monsterStage,
				itemLevel = level,
				tierIndex = tierIndex,
				locked = true,
			})
		end
	end
end

-- 반납(23-1 (라)) - 대여 시작 전 원래 값으로 되돌린다. baseline이 없으면(대여를 한 번도
-- 안 한 상태, 1~3단계만 하고 끝난 경우 등) 아무 일도 안 한다.
local function restoreLendBaseline(player)
	local baseline = PlayerProfile.getTutorialLendBaseline(player)
	if not baseline then
		return
	end
	PlayerProfile.setWeaponGrade(player, baseline.weaponGrade)
	PlayerProfile.setEquippedDirect(player, "armor", baseline.armor)
	PlayerProfile.setEquippedDirect(player, "gloves", baseline.gloves)
	PlayerProfile.setEquippedDirect(player, "shoes", baseline.shoes)
	PlayerProfile.setTutorialLendBaseline(player, nil)
end

local function cancelTimer(player)
	if timerThreads[player] then
		task.cancel(timerThreads[player])
		timerThreads[player] = nil
	end
end

function TutorialState.isActive(player)
	return activeStep[player] ~= nil
end

function TutorialState.getActiveStep(player)
	return activeStep[player]
end

-- 잡몹·보스 전투 계산이 "지금 어느 stage를 쓸지" 고르는 유일한 지점(지시 그대로 - "무한
-- stage를 덮어썼다가 되돌리는" 방식이 아니라 읽는 쪽이 고른다).
function TutorialState.getMonsterStage(player)
	if activeStep[player] then
		return TutorialData.monsterStage
	end
	return PlayerProfile.getInfiniteStage(player) or 1
end

-- 그 처치가 "지금 단계가 가르치는 구역"에서 일어났는가(CombatResolution의 잡몹 처치 루프가
-- 부른다) - 다른 구역에서 잡아도(같은 서버에 잡몹이 상시 존재하므로 물리적으로는 가능하다)
-- 이번 단계 처치 수엔 안 들어간다.
function TutorialState.isTutorialZoneKill(player, model)
	local step = activeStep[player]
	if not step then
		return false
	end
	return MonsterState.getZoneKey(model) == TutorialData.steps[step].zoneKey
end

function TutorialState.registerKill(player)
	local step = activeStep[player]
	if not step then
		return
	end
	killCounts[player] = (killCounts[player] or 0) + 1
	player:SetAttribute("TutorialKillCount", killCounts[player])
	if killCounts[player] >= TutorialData.steps[step].killTarget then
		player:SetAttribute("TutorialCanChallenge", true)
	end
end

-- 단계 하나를 시작한다(새로 시작하거나 재접속으로 재개하거나 다음 단계로 넘어가거나 전부
-- 이 함수 하나를 거친다 - 멱등: 몇 번을 다시 불러도 "지금은 이 단계"라는 결과가 같다).
function TutorialState.start(player, step)
	cancelTimer(player)
	local stepData = TutorialData.steps[step]
	if not stepData then
		return
	end

	PlayerProfile.setTutorialStep(player, step)
	activeStep[player] = step
	killCounts[player] = 0
	player:SetAttribute("TutorialKillTarget", stepData.killTarget)
	player:SetAttribute("TutorialKillCount", 0)
	player:SetAttribute("TutorialCanChallenge", false)

	if stepData.lend then
		applyLend(player, stepData.lend, stepData.tierIndex)
	end

	local zoneName = MonsterData[stepData.zoneKey].displayName
	tutorialStepNotice:FireClient(player, {
		step = step,
		stepCount = TutorialData.stepCount,
		text = stepData.lessonText,
		zoneName = zoneName,
		killTarget = stepData.killTarget,
	})

	-- 단계 상한(20.47[1](마), 300초) - 목표를 못 채워도 만료되면 자동으로 보스 도전을 시작한다.
	timerThreads[player] = task.delay(TutorialData.stepTimeLimitSeconds, function()
		timerThreads[player] = nil
		TutorialState.requestChallenge(player, true)
	end)

	print(("[forge-game] 견습 %d단계 시작: %s (%s 구역, 목표 %d마리)"):format(
		step, player.Name, zoneName, stepData.killTarget))
end

-- 보스 도전(클라 버튼 또는 단계 상한 만료). forced=true면 목표 미달성이어도 강제로 시작한다
-- (자동 진입). 클라이언트가 만드는 버튼은 TutorialCanChallenge가 true일 때만 활성화되므로
-- 정상 경로에서 forced=false인데 미달성인 요청은 오지 않는다 - 그래도 서버가 다시 확인한다
-- (클라이언트가 보낸 값을 그대로 믿지 않는다는 이 프로젝트 원칙).
function TutorialState.requestChallenge(player, forced)
	local step = activeStep[player]
	if not step then
		return
	end
	if not forced and not player:GetAttribute("TutorialCanChallenge") then
		return
	end
	if BossEncounter.getActive(player) then
		return -- 이미 보스전 중
	end
	cancelTimer(player)

	local stepData = TutorialData.steps[step]
	local weaponMultiplier = TutorialData.bossWeaponMultiplier(step)
	BossEncounter.spawnTutorialFor(player, stepData.tierIndex, TutorialData.monsterStage,
		stepData.bossPatternKeys, stepData.bossHpScale, weaponMultiplier)
end

-- CombatResolution.resolveHit이 견습 보스(monsterData.isTutorial) 처치 직후 부른다 - target이
-- 아직 안 지워진 시점(despawn 전)이라 위치를 읽을 수 있다.
function TutorialState.onBossCleared(player, target)
	local step = activeStep[player]
	if not step then
		return
	end
	local stepData = TutorialData.steps[step]
	local deathPosition = target.PrimaryPart.Position

	if not PlayerProfile.hasTutorialGrant(player, step) then
		if stepData.grant then
			local level = PlayerProfile.getCharacterLevel(player) or 1
			local item = Loot.buildFixedArmorDrop(stepData.grant.grade, stepData.grant.part,
				TutorialData.monsterStage, level, stepData.tierIndex)
			ItemDropSpawner.spawn(item, deathPosition, player)
			print(("[forge-game] 견습 확정 드랍: %s - %s등급 %s"):format(player.Name, item.grade, item.part))
		elseif stepData.isFinal then
			PlayerProfile.addGold(player, TutorialData.tutorialCompletionGold)
			print(("[forge-game] 견습 완료 보상: %s +%d 골드"):format(player.Name, TutorialData.tutorialCompletionGold))
		end
		PlayerProfile.markTutorialGrant(player, step)
	end

	cancelTimer(player)
	activeStep[player] = nil
	killCounts[player] = nil
	player:SetAttribute("TutorialCanChallenge", false)
	BossEncounter.clearFor(player)

	if stepData.isFinal then
		restoreLendBaseline(player)
		PlayerProfile.setTutorialCompleted(player, true)
		tutorialStepNotice:FireClient(player, {
			step = step,
			stepCount = TutorialData.stepCount,
			completed = true,
			text = "견습 졸업! 무한 모드가 열렸습니다.",
		})
		ImmediateSave.request(player)
		print(("[forge-game] 견습 완료: %s"):format(player.Name))
		return
	end

	ImmediateSave.request(player)
	TutorialState.start(player, step + 1)
end

-- /gg tutorial off 전용(DevTools.server.lua) + 비상 정지. markCompleted=true면 즉시 완료
-- 처리(개발 편의 - "종료하고 무한 모드로 복귀"). false면 진행 중단만 하고 완료 표시는 안
-- 한다(다음 접속 시 tryResumeTutorial이 같은 단계에서 다시 시작한다).
function TutorialState.stop(player, markCompleted)
	cancelTimer(player)
	activeStep[player] = nil
	killCounts[player] = nil
	player:SetAttribute("TutorialCanChallenge", false)
	if BossEncounter.getActive(player) then
		BossEncounter.despawnFor(player)
	end
	restoreLendBaseline(player)
	if markCompleted then
		PlayerProfile.setTutorialCompleted(player, true)
	end
end

local function tryResumeTutorial(player)
	if not PlayerProfile.getProfile(player) then
		return
	end
	if not PlayerProfile.getClassId(player) then
		return -- 아직 직업 선택 전 - ClassSelectUI가 먼저다
	end
	if PlayerProfile.getTutorialCompleted(player) then
		return
	end
	if activeStep[player] then
		return -- 이미 진행 중(중복 호출 방어)
	end
	local step = PlayerProfile.getTutorialStep(player)
	TutorialState.start(player, (step and step > 0) and step or 1)
end

tutorialChallengeBossRequest.OnServerEvent:Connect(function(player)
	TutorialState.requestChallenge(player, false)
end)

Players.PlayerAdded:Connect(function(player)
	player:GetAttributeChangedSignal("ClassId"):Connect(function()
		tryResumeTutorial(player)
	end)
	-- 클래스 Attribute 변경 신호를 놓쳤을 경우(스크립트 로드 순서 경합)의 대비 - 프로필 로드가
	-- 끝나는 시점에 한 번 더 확인한다(StageServer.server.lua의 같은 폴링 패턴).
	task.spawn(function()
		while player.Parent and not PlayerProfile.getProfile(player) do
			task.wait()
		end
		if player.Parent then
			tryResumeTutorial(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	cancelTimer(player)
	activeStep[player] = nil
	killCounts[player] = nil
end)

return TutorialState
