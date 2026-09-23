-- S12 자동 검증(나)(PRD 20.73 [7-2] · 30-0 S12) - 견습 중에도 파티 결성 · 파티 보스는 견습 멤버를 뺀다 · 견습 보스는 싱글 · 보상 기준 · 친구 알림 payload.
-- env = { ensureBackup, restore, applyStage, partySelfTest } - DevTools의 로컬 헬퍼. 실제 Player 1명 + 스탠드인(테이블 Player) 여럿으로 돈다(다중 클라 불가).
-- 스탠드인을 "견습 중"으로 만드는 법: 제품 코드에 스탠드인 분기를 넣지 않고, 이 검증이 TutorialState.isActive · PlayerProfile.getProfile을 **잠깐 감싼다**(끝나면 원래 함수로 되돌린다).
--   (Attribute는 실제 Player에만 쓰인다 - 스탠드인 상태는 서버 모듈의 상태 함수로 읽는다. COMMON.md §3.)
-- 실제 Player를 견습으로 만드는 경로(6 · 7번)는 진짜 TutorialState.start / requestChallenge다 - 끝나면 프로필의 견습 진행도를 원래 값으로 되돌린다.
-- 검증이 바꾼 것(직업 · 장비 · 골드 · 가방 · 파티 · 견습 진행도 · 위치)은 끝날 때 전부 되돌리고 "남긴 것 0"을 마지막 항목으로 찍는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local TutorialData = require(ReplicatedStorage.Shared.data.TutorialData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossEncounter = require(script.Parent.BossEncounter)
local CombatResolution = require(script.Parent.CombatResolution)
local FriendNotice = require(script.Parent.FriendNotice)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)
local PartyJoinRules = require(script.Parent.PartyJoinRules)
local PartyState = require(script.Parent.PartyState)
local PartyExpBonus = require(script.Parent.PartyExpBonus)
local PartyVote = require(script.Parent.PartyVote)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)

local PartyTutorialVerify = {}

local BOSS_STAGE = BossData.stageInterval * 20 -- 100 - party selftest S9와 같은 스테이지
local FRIEND_STAGE = 12 -- 견습이 아닌 쪽이 자기 스테이지로 잡을 일반 스테이지(보스 스테이지가 아니다)

local function newRecorder()
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S12][나] %s %s"):format(label, ok and "O" or "X"))
	end
	function recorder.section(label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

local function monsterSet()
	local set = {}
	for _, model in ipairs(MonsterState.getAllModels()) do
		set[model] = true
	end
	return set
end

local function groundSet()
	local set = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		set[model] = true
	end
	return set
end

-- 플레이어에게서 가장 먼 tier 구역의 중심(지면 위 5) - S04 사전 작업의 교훈(지면 없는 곳의 드랍은 주인 발밑 자동 줍기로 가방을 채운다).
local function farSpotFrom(player)
	local root = rootOf(player)
	local best, bestDistance = nil, -1
	for _, zoneKey in ipairs(WorldConfig.tierZoneOrder) do
		local center = WorldConfig.zones[zoneKey].center
		local distance = root and (center - root.Position).Magnitude or 0
		if distance > bestDistance then
			best, bestDistance = center, distance
		end
	end
	return best + Vector3.new(0, 5, 0)
end

-- 실제 처치 경로로 tier1 기본형 1마리를 잡고 (스테이지, 골드 증가, 경험치 증가)를 돌려준다. 스폰한 몬스터 · 땅의 드랍은 치운다.
local function killOne(player)
	local classState = PlayerProfile.getProfile(player).classes[PlayerProfile.getClassId(player)]
	local expBefore, goldBefore = classState.characterExp, PlayerProfile.getGold(player)
	local monstersBefore, groundBefore = monsterSet(), groundSet()
	local stage = TutorialState.getMonsterStage(player)
	local model = MonsterSpawner.spawn(MonsterData.tier1, farSpotFrom(player), nil, {})
	local isDead = MonsterState.applyDamage(model, 1e12, stage, player)
	CombatResolution.resolveHit(player, model, isDead)
	task.wait(WorldConfig.zoneMonsterGrid.respawnDelaySeconds + 1)
	local expGain, goldGain = classState.characterExp - expBefore, PlayerProfile.getGold(player) - goldBefore
	for _, leftover in ipairs(MonsterState.getAllModels()) do
		if not monstersBefore[leftover] then
			MonsterState.clear(leftover)
			if leftover.Parent then
				leftover:Destroy()
			end
		end
	end
	for _, dropModel in ipairs(ItemDropState.getAllModels()) do
		if not groundBefore[dropModel] and ItemDropState.getOwnerId(dropModel) == player.UserId and dropModel.Parent then
			ItemDropSpawner.despawn(dropModel)
		end
	end
	return stage, goldGain, expGain
end

local function contains(list, value)
	return table.find(list, value) ~= nil
end

local function blockedPlayers(blocked)
	local list = {}
	for _, entry in ipairs(blocked) do
		table.insert(list, entry.player)
	end
	return list
end

function PartyTutorialVerify.runLive(player, env)
	print("===S12 검증 시작(나: 견습 중 파티 · 파티 보스 견습 멤버 제외 · 견습 보스 싱글 · 보상 기준)===")
	local r = newRecorder()
	local root = rootOf(player)
	if not PlayerProfile.getProfile(player) or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S12 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	if PartyState.getParty(player) then
		r.check("이미 파티에 있어 검증을 건너뜀(먼저 파티를 나가세요)", false)
		local pass, total = r.summary()
		print(("===S12 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	-- [0] 기존 party selftest 11항목(회귀) - DevTools의 같은 함수를 그대로 돌린다.
	r.section("[0] 기존 party selftest", function()
		local results, blockedMessage = env.partySelfTest(player)
		if not results then
			r.check("기존 party selftest 실행 불가: " .. tostring(blockedMessage), false)
			return
		end
		local okCount = 0
		for _, line in ipairs(results) do
			if line:sub(1, 1) == "O" then
				okCount += 1
			end
			print("[S12][나][기존 party selftest] " .. line)
		end
		r.check(("기존 party selftest: %d/%d 통과(기대 11/11)"):format(okCount, #results), okCount == 11 and #results == 11)
	end)
	env.restore(player)
	if PartyState.getParty(player) then
		PartyState.leave(player, "leave")
	end
	BossEncounter.despawnFor(player)

	env.ensureBackup(player)
	local savedCFrame = rootOf(player).CFrame
	local monstersBefore, groundBefore = monsterSet(), groundSet()
	local originalTutorialStep, originalTutorialCompleted = PlayerProfile.getTutorialStep(player), PlayerProfile.getTutorialCompleted(player)
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	-- 기준 상태: 착용 장비 · 보석을 비워 경험치 배수가 파티 보너스만 남게 한다(S04 · S09 (나)와 같다).
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		PlayerProfile.setEquippedDirect(player, part, nil)
	end
	local weapon = PlayerProfile.getWeapon(player)
	for slot = 1, #weapon.gems do
		weapon.gems[slot] = false
	end
	TutorialState.stop(player, false) -- 개발 계정이 견습 중이 아니게(실제 견습 검증은 아래에서 직접 시작한다)

	local B, C, D, E = standIn("S12StandB", -9501), standIn("S12StandC", -9502), standIn("S12StandD", -9503), standIn("S12StandE", -9504)

	-- 견습 상태를 스탠드인에 주는 잠깐의 감싸기(끝나면 반드시 되돌린다).
	local fakeTutorial = {}
	local realIsActive = TutorialState.isActive
	local realNotify = PartyState.notify
	local notified = {} -- [수신자] = 받은 문구 목록
	TutorialState.isActive = function(target)
		if fakeTutorial[target] then
			return true
		end
		return realIsActive(target)
	end
	PartyState.notify = function(target, text)
		notified[target] = notified[target] or {}
		table.insert(notified[target], text)
		return realNotify(target, text)
	end

	local function form(members)
		for _, member in ipairs(members) do
			PartyState.invite(player, member)
			PartyState.respondInvite(member, true)
		end
	end
	local function dissolve()
		for _, member in ipairs({ E, D, C, B }) do
			if PartyState.getParty(member) then
				PartyState.leave(member, "leave")
			end
		end
		if PartyState.getParty(player) then
			PartyState.leave(player, "leave")
		end
	end

	r.section("[1] 견습 중인 사람도 초대 · 수락된다", function()
		-- checkJoinable의 프로필 검사만 스탠드인에게 통과시킨다(스탠드인은 프로필이 없다) - 이 항목 안에서만 감싸고 끝나면 되돌린다.
		local realGetProfile = PlayerProfile.getProfile
		PlayerProfile.getProfile = function(target)
			if type(target) == "table" then
				return { standIn = true }
			end
			return realGetProfile(target)
		end
		local ok, err = pcall(function()
		-- 1a: 견습 중인 스탠드인을 초대한다.
		fakeTutorial[D] = true
		local blockedA = PartyJoinRules.checkJoinable(player, D)
		local invited = PartyState.invite(player, D)
		local accepted = PartyState.respondInvite(D, true)
		r.check(("견습 중인 스탠드인 초대: 거절 사유 %s(기대 nil) · invite=%s accept=%s · 파티 인원 %d(기대 2)"):format(
			tostring(blockedA), tostring(invited), tostring(accepted), PartyState.getSize(PartyState.getParty(player))),
			blockedA == nil and invited and accepted and PartyState.getSize(PartyState.getParty(player)) == 2)
		dissolve()
		fakeTutorial[D] = nil
		-- 1b: 견습 중인 쪽이 초대한다.
		fakeTutorial[player] = true
		local blockedB = PartyJoinRules.checkJoinable(player, E)
		local invitedB = PartyState.invite(player, E)
		local acceptedB = PartyState.respondInvite(E, true)
		r.check(("견습 중인 쪽이 초대: 거절 사유 %s(기대 nil) · invite=%s accept=%s · 파티 인원 %d(기대 2)"):format(
			tostring(blockedB), tostring(invitedB), tostring(acceptedB), PartyState.getSize(PartyState.getParty(player))),
			blockedB == nil and invitedB and acceptedB and PartyState.getSize(PartyState.getParty(player)) == 2)
		-- 친구 알림 payload(같은 파티 상태를 쓴다): 친구 · 초대 가능이면 있다 / 친구가 아니거나 이미 다른 파티면 없다.
		local always, never = function() return true end, function() return false end
		local friendPayload = FriendNotice.payloadFor(player, B, always)
		local notFriend = FriendNotice.payloadFor(player, B, never)
		local inParty = FriendNotice.payloadFor(player, E, always)
		r.check(("친구 알림 payload: 친구 · 초대 가능 → %s(기대 userId %d) · 친구 아님 → %s(기대 nil) · 이미 파티에 있는 사람 → %s(기대 nil)"):format(
			friendPayload and tostring(friendPayload.userId) or "nil", B.UserId, tostring(notFriend), tostring(inParty)),
			friendPayload ~= nil and friendPayload.userId == B.UserId and notFriend == nil and inParty == nil)
		dissolve()
		fakeTutorial[player] = nil
		end)
		PlayerProfile.getProfile = realGetProfile
		if not ok then
			error(err)
		end
	end)

	-- [3 ~ 5]는 4인 파티 [나(리더) · B · C · D]에서 D(또는 여럿)를 견습으로 둔다.
	r.section("[3] 4인 파티 중 1명 견습 → 파티 보스", function()
		form({ B, C })
		fakeTutorial[D] = true
		form({ D })
		local party = PartyState.getParty(player)
		local blockedNow = blockedPlayers(BossEncounter.checkPartyEntry(party, BOSS_STAGE))
		fakeTutorial[D] = nil
		local blockedContrast = blockedPlayers(BossEncounter.checkPartyEntry(party, BOSS_STAGE))
		fakeTutorial[D] = true
		r.check(("입장 검사: 견습 D는 검사에서 빠진다(막힘 목록에 D %s · 기대 false) / 견습 아니면 D도 검사된다(막힘 목록에 D %s · 기대 true - 스탠드인은 프로필이 없다)"):format(
			tostring(contains(blockedNow, D)), tostring(contains(blockedContrast, D))),
			not contains(blockedNow, D) and contains(blockedContrast, D))

		env.applyStage(player, BOSS_STAGE)
		notified[D] = nil
		BossEncounter.spawnForParty(party, player, BOSS_STAGE)
		local encounter = BossEncounter.getEncounter(player)
		local multiplier = encounter and encounter.data.partyHpMultiplier or 0
		r.check(("파티 보스 입장: 멤버 %d(기대 3) · 입장 인원 N %d(기대 3) · HP 배수 %.4f(기대 3인분 %.4f) · 견습 D는 보스전 %s(기대 nil) · 파티 인원은 그대로 %d(기대 4) ★진짜 합격 기준"):format(
			encounter and #encounter.members or 0, encounter and encounter.size or 0, multiplier, BossRules.partySizeHpMultiplier(3),
			tostring(BossEncounter.getEncounter(D)), PartyState.getSize(party)),
			encounter ~= nil and #encounter.members == 3 and encounter.size == 3 and math.abs(multiplier - BossRules.partySizeHpMultiplier(3)) < 1e-9
				and BossEncounter.getEncounter(D) == nil and PartyState.getSize(party) == 4)
		local told = notified[D] and notified[D][1]
		r.check(("견습 D는 사냥터에 남고 알림을 받는다: '%s'(기대 '파티가 보스전에 들어갔습니다')"):format(tostring(told)), told == "파티가 보스전에 들어갔습니다")
		BossEncounter.despawnFor(player)

		-- [4] 투표: 동의자도 견습 아닌 멤버에서만 센다.
		local resolved = nil
		local started = PartyVote.start(party, player, BOSS_STAGE, function(passed)
			resolved = passed
		end)
		PartyVote.cast(party, D, true) -- 견습 D의 동의는 대상이 아니라 세지 않는다
		local afterTutorialVote = resolved
		PartyVote.cast(party, B, true) -- 견습 아닌 B의 동의 - 리더 + B = 2명으로 성립
		r.check(("투표(4인 중 D 견습): 시작=%s · D의 동의 뒤 결과 %s(기대 nil - 안 셈) · B의 동의 뒤 결과 %s(기대 true)"):format(
			tostring(started), tostring(afterTutorialVote), tostring(resolved)), started and afterTutorialVote == nil and resolved == true)
		PartyVote.cancel(party)
	end)
	BossEncounter.despawnFor(player)

	r.section("[5] 리더 빼고 전원 견습 → 솔로처럼 즉시 입장", function()
		local party = PartyState.getParty(player)
		fakeTutorial[B], fakeTutorial[C], fakeTutorial[D] = true, true, true
		local resolved = nil
		local started = PartyVote.start(party, player, BOSS_STAGE, function(passed)
			resolved = passed
		end)
		r.check(("투표 없이 즉시 성립: 시작=%s · 결과 %s(기대 true)"):format(tostring(started), tostring(resolved)), started and resolved == true)
		BossEncounter.spawnForParty(party, player, BOSS_STAGE)
		local encounter = BossEncounter.getEncounter(player)
		local multiplier = encounter and encounter.data.partyHpMultiplier or 0
		-- 입장 검사는 리더만 본다(스테이지 게이트 · 밴드는 개발 계정 값에 달렸으니 리더가 막히는지는 따지지 않는다) - 견습 멤버 셋은 막힘 목록에 없어야 한다.
		local blockedNow = blockedPlayers(BossEncounter.checkPartyEntry(party, BOSS_STAGE))
		local tutorialBlocked = contains(blockedNow, B) or contains(blockedNow, C) or contains(blockedNow, D)
		r.check(("입장: 멤버 %d(기대 1) · N %d(기대 1) · HP 배수 %.4f(기대 1인분 %.4f) · 검사 막힘 목록에 견습 멤버 %s(기대 false - 리더만 검사)"):format(
			encounter and #encounter.members or 0, encounter and encounter.size or 0, multiplier, BossRules.partySizeHpMultiplier(1), tostring(tutorialBlocked)),
			encounter ~= nil and #encounter.members == 1 and encounter.size == 1 and math.abs(multiplier - BossRules.partySizeHpMultiplier(1)) < 1e-9
				and not tutorialBlocked)
		BossEncounter.despawnFor(player)
		fakeTutorial[B], fakeTutorial[C], fakeTutorial[D] = nil, nil, nil
		dissolve()
	end)

	-- [2 · 6 · 7]은 실제 Player가 진짜 견습에 들어간다.
	r.section("[2] 견습 시작 → 파티 유지", function()
		form({ B })
		local partyBefore = PartyState.getParty(player)
		PlayerProfile.setTutorialCompleted(player, false)
		TutorialState.start(player, 1)
		r.check(("견습 1단계 시작: 견습 중=%s(기대 true) · 파티 유지=%s(기대 true - 같은 파티) · 인원 %d(기대 2)"):format(
			tostring(TutorialState.isActive(player)), tostring(PartyState.getParty(player) == partyBefore), PartyState.getSize(PartyState.getParty(player))),
			TutorialState.isActive(player) and PartyState.getParty(player) == partyBefore and PartyState.getSize(partyBefore) == 2)
	end)

	r.section("[6] 견습 멤버의 견습 보스는 싱글", function()
		local party = PartyState.getParty(player)
		local blockedList = BossEncounter.checkPartyEntry(party, BOSS_STAGE)
		r.check(("견습 중인 리더는 파티 보스를 열 수 없다: 막힘 %d명 · 사유 %s(기대 1명 · tutorial)"):format(#blockedList, blockedList[1] and blockedList[1].reason or "-"),
			#blockedList == 1 and blockedList[1].player == player and blockedList[1].reason == "tutorial")
		TutorialState.requestChallenge(player, true)
		local encounter = BossEncounter.getEncounter(player)
		r.check(("견습 보스: 견습 보스전=%s(기대 true) · 멤버 %d(기대 1 - 나만) · 파티원 B는 보스전 %s(기대 nil) · 파티 연결 %s(기대 nil) ★진짜 합격 기준"):format(
			tostring(encounter and encounter.isTutorial), encounter and #encounter.members or 0, tostring(BossEncounter.getEncounter(B)), tostring(encounter and encounter.party)),
			encounter ~= nil and encounter.isTutorial == true and #encounter.members == 1 and BossEncounter.getEncounter(B) == nil and encounter.party == nil)
		BossEncounter.despawnFor(player)
	end)

	r.section("[7] 보상 기준: 견습 = 견습 스테이지 · 친구 = 자기 스테이지(파티 보너스는 둘 다)", function()
		env.applyStage(player, FRIEND_STAGE)
		-- P2 G: 파티 보너스는 조건(같은 구역 · 반경 · 최근 활동)을 만족한 파티원만 센다 - 스탠드인 B를 실제 Player와 같은 가상 구역 · 자리에 두고 방금 활동한 것으로 기록한다.
		local presence = { zone = "S12-verify", position = Vector3.new(0, 0, 0) }
		PartyExpBonus.debugSetPresence(player, presence)
		PartyExpBonus.debugSetPresence(B, presence)
		PartyState.noteActivity(B)
		local partyBonus = PartyState.getExpBonusFor(player)
		local tutorialStage, tutorialGold, tutorialExp = killOne(player) -- 지금 견습 중
		TutorialState.stop(player, false)
		local friendStage, friendGold, friendExp = killOne(player) -- 견습 아님 = 같은 파티의 친구 처지
		local expectedTutorial = InfiniteStage.getExpReward(MonsterData.tier1.expReward, TutorialData.monsterStage) * (1 + partyBonus)
		local expectedFriend = InfiniteStage.getExpReward(MonsterData.tier1.expReward, FRIEND_STAGE) * (1 + partyBonus)
		print(("[S12][나] 처치 로그 1(견습 중): 스테이지 %s · 골드 +%d · 경험치 +%.4f"):format(tostring(tutorialStage), tutorialGold, tutorialExp))
		print(("[S12][나] 처치 로그 2(친구): 스테이지 %s · 골드 +%d · 경험치 +%.4f"):format(tostring(friendStage), friendGold, friendExp))
		r.check(("견습 중 처치: 기준 스테이지 %s(기대 %d) · 경험치 +%.4f(기대 %.4f = 견습 스테이지 기준 × 파티 보너스 ×%.2f)"):format(
			tostring(tutorialStage), TutorialData.monsterStage, tutorialExp, expectedTutorial, 1 + partyBonus),
			tutorialStage == TutorialData.monsterStage and math.abs(tutorialExp - expectedTutorial) <= 1)
		r.check(("친구(견습 아님) 처치: 기준 스테이지 %s(기대 %d) · 경험치 +%.4f(기대 %.4f = 자기 스테이지 기준 × 파티 보너스 ×%.2f) · 견습 쪽보다 골드 %d > %d(기대 참)"):format(
			tostring(friendStage), FRIEND_STAGE, friendExp, expectedFriend, 1 + partyBonus, friendGold, tutorialGold),
			friendStage == FRIEND_STAGE and math.abs(friendExp - expectedFriend) <= 1 and friendGold > tutorialGold)
	end)
	-- P2 G: 가짜 위치는 섹션 밖에서 해제한다(섹션 도중 에러가 나도 남지 않게 - 리뷰 지적 7).
	PartyExpBonus.debugSetPresence(player, nil)
	PartyExpBonus.debugSetPresence(B, nil)

	-- [8] 되돌리기: 파티 · 견습 진행도 · 감싼 함수 · 직업 · 장비 · 골드 · 가방 · 위치. 검증이 만든 것은 없어야 한다.
	dissolve()
	BossEncounter.despawnFor(player)
	TutorialState.stop(player, false)
	PlayerProfile.setTutorialStep(player, originalTutorialStep or 0)
	PlayerProfile.setTutorialCompleted(player, originalTutorialCompleted == true)
	TutorialState.isActive = realIsActive
	PartyState.notify = realNotify
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end
	local orphans, leftoverMonsters, leftoverGround = 0, 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
		if not monstersBefore[model] then
			leftoverMonsters += 1
		end
	end
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not groundBefore[model] then
			leftoverGround += 1
		end
	end
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d · 남은 몬스터 %d · 땅의 드랍 %d(기대 0 · 0 · 0) · 파티 %s / 스탠드인 파티 %s %s %s %s(기대 nil) · 견습 진행도 %s/%s → %s/%s(기대 같음) · isActive 복구 %s"):format(
		orphans, leftoverMonsters, leftoverGround, tostring(PartyState.getParty(player)), tostring(PartyState.getParty(B)), tostring(PartyState.getParty(C)),
		tostring(PartyState.getParty(D)), tostring(PartyState.getParty(E)), tostring(originalTutorialStep), tostring(originalTutorialCompleted),
		tostring(PlayerProfile.getTutorialStep(player)), tostring(PlayerProfile.getTutorialCompleted(player)),
		tostring(TutorialState.isActive == realIsActive)),
		orphans == 0 and leftoverMonsters == 0 and leftoverGround == 0 and PartyState.getParty(player) == nil and PartyState.getParty(B) == nil
			and PartyState.getParty(C) == nil and PartyState.getParty(D) == nil and PartyState.getParty(E) == nil
			and (PlayerProfile.getTutorialStep(player) or 0) == (originalTutorialStep or 0) and PlayerProfile.getTutorialCompleted(player) == (originalTutorialCompleted == true)
			and TutorialState.isActive == realIsActive)

	local pass, total = r.summary()
	print(("===S12 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return PartyTutorialVerify
