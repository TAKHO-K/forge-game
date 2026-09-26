-- S10 자동 검증(PRD 20.73 [5-3] · 30-0 S10) - 파티원 드랍 알림(DropNotice).
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이): 7등급 × 솔로 / 파티의 발신 범위 · 데이터 표 정합 · payload 모양(옵션 · 능력치 없음).
--   (나) 실제 Player - 보스 검증 체인의 끝에서: 더미 파티 · 스탠드인 파티(에러 0) · 솔로 유물 · 솔로 태초 · 견습 확정 지급 경로 · 보스 첫 클리어(가방 직행).
-- 클라 쪽(피드 3줄 · 밀림 · 묶음 · 흐림 · 태초 배너)은 client/hud/DropFeed.client.lua의 selfTest가 클라 콘솔에 [S10][UI]로 찍는다.
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(파티 · 견습 진행도 · 가방 · 보스 · 땅의 드랍 · DropNoticeData 필터)은 (나)가 끝날 때 전부 되돌린다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local BossEncounter = require(script.Parent.BossEncounter)
local CombatResolution = require(script.Parent.CombatResolution)
local DropNotice = require(script.Parent.DropNotice)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local LootRuleVerify = require(script.Parent.LootRuleVerify)
local MonsterState = require(script.Parent.MonsterState)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)

local DropNoticeVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S10][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function sortedKeys(set)
	local keys = {}
	for key in pairs(set) do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

-- ─────────────────────────── (가) 순수 함수 ───────────────────────────

function DropNoticeVerify.runPure()
	print("===S10 검증 시작(가: 순수 함수 · 발신 범위)===")
	local r = newRecorder("가")

	-- 7등급 × (솔로 / 파티): PRD 20.73 [5-3] - 유물 · 고대는 파티만, 태초는 솔로여도 서버 전체, 그 아래 등급(일반 ~ 전설)은 어디로도 안 간다.
	local expected = {
		normal = { solo = "-", party = "-" },
		rare = { solo = "-", party = "-" },
		epic = { solo = "-", party = "-" },
		legendary = { solo = "-", party = "-" },
		relic = { solo = "-", party = "party" },
		ancient = { solo = "server", party = "server" }, -- D1 ⑧: 고대 = 같은 서버 알림
		primordial = { solo = "-", party = "-" }, -- D1: 태초 = PrimordialRegistry(세계 번호 · 전 서버) - DropNotice는 안 보낸다
	}
	local mismatches, rows = {}, {}
	for _, grade in ipairs(ArmorData.gradeOrder) do
		local want = expected[grade]
		local solo, party = DropNotice.scopeFor(grade, false) or "-", DropNotice.scopeFor(grade, true) or "-"
		table.insert(rows, ("%s(솔로 %s · 파티 %s)"):format(grade, solo, party))
		if not want or solo ~= want.solo or party ~= want.party then
			table.insert(mismatches, grade)
		end
	end
	r.check(("등급 필터 7등급: %s(기대 영웅 · 전설까지 발신 0 · 유물 = 파티만 · 고대 = 서버 전체 · 태초 = 세계 기록 모듈 - D1) 어긋난 등급 %d개"):format(table.concat(rows, " · "), #mismatches), #mismatches == 0 and #ArmorData.gradeOrder == 7)

	-- 데이터 표 정합: 등급 id가 실제 등급이고, 서버 전체 등급은 파티 등급의 부분집합이다. 사용자 결정 값(3줄 · 4초 · 묶기 1초).
	local unknown = {}
	for _, key in ipairs(sortedKeys(DropNoticeData.partyGrades)) do
		if not ArmorData.grades[key] then
			table.insert(unknown, key)
		end
	end
	for _, key in ipairs(sortedKeys(DropNoticeData.serverWideGrades)) do
		if not ArmorData.grades[key] or not DropNoticeData.partyGrades[key] or DropNoticeData.registryGrades[key] then
			table.insert(unknown, key)
		end
	end
	r.check(("DropNoticeData 정합: 등급 id 오류 %d개(기대 0) · 3줄=%s · 4초=%s · 묶기 %s초(기대 3 · 4 · 1 - 사용자 결정 2026-09-20)"):format(
		#unknown, tostring(DropNoticeData.feedRows), tostring(DropNoticeData.seconds), tostring(DropNoticeData.groupWindowSeconds)),
		#unknown == 0 and DropNoticeData.feedRows == 3 and DropNoticeData.seconds == 4 and DropNoticeData.groupWindowSeconds == 1)

	-- payload: S12b가 옵션 스냅샷 · 누가(userId · 레벨 · 환생 · 직업)를 더했다(사용자 지시 2026-09-20 - 알림을 눌러 옵션을 본다). 그 밖의 필드(dropStage · locked · 방어력 · 공격력)는 여전히 안 나간다.
	local item = {
		grade = "relic", part = "gloves", itemLevel = 52, dropStage = 40, tierIndex = 6, locked = false,
		option = { id = "expGain", roll = 0.9, roll2 = 0.4, secret = "x" }, defense = 123, attackPercent = 0.5,
	}
	local payload = DropNotice.buildPayload("철수", item, "party", { userId = 77, level = 35, rebirth = 2, classId = "warrior" })
	local keys = sortedKeys(payload)
	local optionKeys = sortedKeys(payload.option or {})
	local expectedKeys = "classId,grade,itemLevel,level,name,option,part,rebirth,scope,userId"
	r.check(("payload 필드 [%s](기대 %s - dropStage · locked · 방어력 · 공격력 없음) · 옵션 [%s](기대 id,roll,roll2 - 임의 필드 없음) · 값 %s %s %s"):format(
		table.concat(keys, ","), expectedKeys, table.concat(optionKeys, ","), payload.name, payload.grade, tostring(payload.itemLevel)),
		table.concat(keys, ",") == expectedKeys and table.concat(optionKeys, ",") == "id,roll,roll2" and payload.name == "철수" and payload.grade == "relic"
			and payload.itemLevel == 52 and payload.userId == 77 and payload.level == 35 and payload.rebirth == 2)

	-- 스냅샷은 값 복사다: 드랍 뒤 원본 옵션이 바뀌어도(강화 · 재굴림) payload는 그대로.
	item.option.roll = 0.1
	r.check(("옵션 스냅샷은 원본과 분리된다: 원본 roll을 0.9 → 0.1로 바꿔도 payload roll %s(기대 0.9)"):format(tostring(payload.option.roll)), payload.option.roll == 0.9)

	local pass, total = r.summary()
	print(("===S10 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 Player ───────────────────────────

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function groundSet()
	local set = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		set[model] = true
	end
	return set
end

local function newGroundDrops(player, before)
	local list = {}
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not before[model] and ItemDropState.getOwnerId(model) == player.UserId and model.Parent then
			table.insert(list, model)
		end
	end
	return list
end

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

local function relicItem()
	return { grade = "relic", part = "gloves", itemLevel = 52, dropStage = 40, tierIndex = 6, locked = false }
end

-- 부른 횟수 · 파티로 보낸 횟수 · 서버 전체로 보낸 횟수의 두 시점 차.
local function statDelta(before)
	local calls, party, server = DropNotice.stats()
	return calls - before[1], party - before[2], server - before[3]
end

local function statSnapshot()
	local calls, party, server = DropNotice.stats()
	return { calls, party, server }
end

function DropNoticeVerify.runLive(player, env)
	print("===S10 검증 시작(나: 실제 Player · 실제 PartyState · 실제 처치 경로)===")
	local r = newRecorder("나")
	local root = rootOf(player)
	local profile = PlayerProfile.getProfile(player)
	if not profile or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S10 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	if PartyState.getParty(player) or TutorialState.isActive(player) then
		r.check("이미 파티에 있거나 견습 진행 중이라 검증을 건너뜀(파티를 나가고 견습을 끝낸 뒤 다시)", false)
		local pass, total = r.summary()
		print(("===S10 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	local savedCFrame = root.CFrame
	local savedInventory = table.clone(profile.inventory)
	local groundBefore = groundSet()
	local savedPartyGrades = table.clone(DropNoticeData.partyGrades)
	local dummyTemplate = function(index)
		return { classId = ClassData.order[(index - 1) % #ClassData.order + 1], level = 1, stage = 1, hp = 1, maxHp = 1 } -- "/gg party dummy"와 같은 모양
	end
	local B = standIn("S10StandB", -9401)

	r.section("[1] 더미 파티 · 유물 → 실제 Player 1명에게만(에러 0)", function()
		local ok, added = PartyState.addDummies(player, 3, dummyTemplate)
		local party = PartyState.getParty(player)
		local before = statSnapshot()
		local publishOk, scope, sent = pcall(DropNotice.publish, player, relicItem())
		local calls, partyCount, serverCount = statDelta(before)
		r.check(("더미 3명 파티(인원 %s · 실제 %d)에서 유물: 에러 없음=%s · 범위 %s(기대 party) · 보낸 Player %d명(기대 1 - 본인) · 부른 %d · 파티 %d · 서버 %d(기대 1 · 1 · 0) ★진짜 합격 기준"):format(
			tostring(party and PartyState.getSize(party)), #PartyState.getMemberPlayers(party), tostring(publishOk), tostring(scope), publishOk and #sent or -1, calls, partyCount, serverCount),
			ok and added == 3 and publishOk and scope == "party" and #sent == 1 and sent[1] == player and calls == 1 and partyCount == 1 and serverCount == 0)
		PartyState.clearDummies(player)
	end)

	r.section("[2] 스탠드인(테이블 Player) 파티 · 유물 → 에러 0", function()
		local ok1 = PartyState.invite(player, B)
		local ok2 = PartyState.respondInvite(B, true)
		local party = PartyState.getParty(player)
		local memberCount = #PartyState.getMemberPlayers(party)
		local publishOk, scope, sent = pcall(DropNotice.publish, player, relicItem())
		r.check(("스탠드인 1명 합류(invite=%s accept=%s · 파티 멤버 표 %d개)에서 유물: 에러 없음=%s · 범위 %s(기대 party) · 보낸 Player %d명(기대 1 - 테이블은 못 받는다) ★진짜 합격 기준"):format(
			tostring(ok1), tostring(ok2), memberCount, tostring(publishOk), tostring(scope), publishOk and #sent or -1),
			ok1 and ok2 and memberCount == 2 and publishOk and scope == "party" and #sent == 1 and sent[1] == player)
		PartyState.leave(B, "leave")
		if PartyState.getParty(player) then
			PartyState.leave(player, "leave")
		end
	end)

	r.section("[3] 솔로 · 유물 · 영웅 · 전설 → 발신 0 / 파티 · 전설 → 발신 0(D1: 고대는 [4]에서 서버 전체)", function()
		local before = statSnapshot()
		local scopes, totalSent = {}, 0
		for _, grade in ipairs({ "relic", "epic", "legendary" }) do
			local item = relicItem()
			item.grade = grade
			local scope, sent = DropNotice.publish(player, item)
			table.insert(scopes, ("%s=%s"):format(grade, tostring(scope)))
			totalSent += #sent
		end
		local calls, partyCount, serverCount = statDelta(before)
		PartyState.addDummies(player, 1, dummyTemplate)
		local legendary = relicItem()
		legendary.grade = "legendary"
		local partyScope, partySent = DropNotice.publish(player, legendary)
		PartyState.clearDummies(player)
		r.check(("솔로 4등급 [%s] · 보낸 Player %d명 · 부른 %d · 파티 %d · 서버 %d(기대 전부 nil · 0 · 3 · 0 · 0) / 파티 전설: 범위 %s · 보낸 %d명(기대 nil · 0)"):format(
			table.concat(scopes, " "), totalSent, calls, partyCount, serverCount, tostring(partyScope), #partySent),
			totalSent == 0 and calls == 3 and partyCount == 0 and serverCount == 0 and partyScope == nil and #partySent == 0)
	end)

	r.section("[4] 솔로 · 고대 → 서버 전원(D1 ⑧ - 태초는 PrimordialRegistry가 세계 번호와 함께 - D1(나))", function()
		local before = statSnapshot()
		local item = relicItem()
		item.grade = "ancient"
		local scope, sent = DropNotice.publish(player, item)
		local calls, partyCount, serverCount = statDelta(before)
		local includesSelf = table.find(sent, player) ~= nil
		r.check(("솔로 고대: 범위 %s(기대 server) · 보낸 Player %d명(기대 접속 전원 %d명 · 본인 포함=%s) · 부른 %d · 파티 %d · 서버 %d(기대 1 · 0 · 1) - 채팅 1줄은 이 신호를 받은 클라가 만든다(클라 selfTest · 스크린샷)"):format(
			tostring(scope), #sent, #Players:GetPlayers(), tostring(includesSelf), calls, partyCount, serverCount),
			scope == "server" and #sent == #Players:GetPlayers() and includesSelf and calls == 1 and partyCount == 0 and serverCount == 1)
	end)

	r.section("[5] 견습 확정 지급 경로 → 발신 0", function()
		-- 실제 TutorialState.onBossCleared를 탄다(1단계 확정 지급 = 일반 갑옷을 땅에 스폰). 기록(profile.tutorial)은 끝에 원래대로 돌려놓는다.
		local tutorial = profile.tutorial
		local saved = { step = tutorial.step, completed = tutorial.completed, granted = table.clone(tutorial.granted), lendBaseline = tutorial.lendBaseline }
		tutorial.granted["1"] = nil
		local ground = groundSet()
		local bagBefore = #profile.inventory
		local before = statSnapshot()
		local ok, err = pcall(function()
			TutorialState.start(player, 1)
			TutorialState.onBossCleared(player, { PrimaryPart = { Position = root.Position } })
		end)
		local calls, partyCount, serverCount = statDelta(before)
		task.wait(0.3) -- 지면이 없는 자리면 땅의 드랍이 주인 발밑 자동 줍기로 가방에 들어갈 수 있다 - 둘 중 어느 쪽이든 "지급 경로가 돌았다"의 증거다
		local spawned = newGroundDrops(player, ground)
		local bagGrew = #profile.inventory - bagBefore
		local grantMarked = PlayerProfile.hasTutorialGrant(player, 1)
		TutorialState.stop(player, false)
		tutorial.step, tutorial.completed, tutorial.granted, tutorial.lendBaseline = saved.step, saved.completed, saved.granted, saved.lendBaseline
		player:SetAttribute("TutorialStep", saved.step)
		player:SetAttribute("TutorialCompleted", saved.completed)
		for _, model in ipairs(spawned) do
			ItemDropSpawner.despawn(model)
		end
		r.check(("견습 1단계 확정 지급(에러 없음=%s%s): 땅에 스폰 %d개 · 가방 +%d · 지급 표시=%s(경로가 실제로 돌았다: 스폰 + 가방 ≥ 1 · true) · DropNotice 부른 %d · 파티 %d · 서버 %d(기대 0 · 0 · 0)"):format(
			tostring(ok), ok and "" or " - " .. tostring(err), #spawned, bagGrew, tostring(grantMarked), calls, partyCount, serverCount),
			ok and #spawned + bagGrew >= 1 and grantMarked and calls == 0 and partyCount == 0 and serverCount == 0)
	end)

	r.section("[6] 보스 첫 클리어(가방 직행)에서도 발신된다", function()
		-- 처치 등급은 난수라 유물 미만이 나올 수 있다 - 이 항목만 필터를 임시로 전 등급으로 열어 "이 경로가 publish를 부른다"를 등급과 무관하게 확정하고, 끝에서 원래 표로 되돌린다.
		local stage = 2 * BossData.stageInterval
		for _, grade in ipairs(ArmorData.gradeOrder) do
			DropNoticeData.partyGrades[grade] = true
		end
		PartyState.addDummies(player, 1, dummyTemplate) -- 솔로면 유물 · 고대는 안 나간다 - 파티(더미 1명)로 만든다
		PlayerProfile.clearBossFirstClearRewards(player, stage)
		table.clear(profile.inventory)
		local model, data = LootRuleVerify.spawnBossAt(player, env, stage)
		if not model then
			r.check("보스 스폰 실패", false)
			return
		end
		local before = statSnapshot()
		local bagBefore = #profile.inventory
		local toBagBefore = CombatResolution.dropStats()
		LootRuleVerify.killBoss(player, model, data, stage)
		local toBagAfter = CombatResolution.dropStats()
		local calls, partyCount, serverCount = statDelta(before)
		local item = profile.inventory[#profile.inventory]
		r.check(("보스 첫 클리어(스테이지 %d): 가방 %d → %d(기대 +1) · 가방 직행 %d회(기대 1) · 아이템 %s · DropNotice 부른 %d · 파티 %d · 서버 %d(기대 1 · 파티 + 서버 합 1)"):format(
			stage, bagBefore, #profile.inventory, toBagAfter - toBagBefore, tostring(item and item.grade), calls, partyCount, serverCount),
			#profile.inventory == bagBefore + 1 and toBagAfter - toBagBefore == 1 and calls == 1 and partyCount + serverCount == 1)
	end)

	-- 되돌리기: 필터 표 · 파티 · 보스 · 가방 · 땅의 드랍 · 위치. 검증이 만든 것은 없어야 한다.
	table.clear(DropNoticeData.partyGrades)
	for grade, value in pairs(savedPartyGrades) do
		DropNoticeData.partyGrades[grade] = value
	end
	PartyState.clearDummies(player)
	if PartyState.getParty(player) then
		PartyState.leave(player, "leave")
	end
	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	for _, model in ipairs(newGroundDrops(player, groundBefore)) do
		ItemDropSpawner.despawn(model)
	end
	table.clear(profile.inventory)
	for index, item in ipairs(savedInventory) do
		profile.inventory[index] = item
	end
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end

	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	local leftovers = #newGroundDrops(player, groundBefore)
	local gradesRestored = table.concat(sortedKeys(DropNoticeData.partyGrades), ",") == table.concat(sortedKeys(savedPartyGrades), ",")
	r.check(("검증 뒤 되돌림: encounter 없는 보스 모델 %d개 · 검증이 남긴 땅의 드랍 %d개 · 가방 %d → %d칸 · 파티 %s · 견습 진행 중=%s · 필터 표 복구=%s(기대 0 · 0 · 같은 칸 · nil · false · true)"):format(
		orphans, leftovers, #savedInventory, #profile.inventory, tostring(PartyState.getParty(player)), tostring(TutorialState.isActive(player)), tostring(gradesRestored)),
		orphans == 0 and leftovers == 0 and #profile.inventory == #savedInventory and PartyState.getParty(player) == nil and not TutorialState.isActive(player) and gradesRestored)

	local pass, total = r.summary()
	print(("===S10 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return DropNoticeVerify
