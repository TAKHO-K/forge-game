-- S19b 자동 검증 - 보스 체력바 서버 쪽(A) · 파티 연결 끊김 유예(B).
--   (가) runPure  - PartyState 유예 규칙(스탠드인 멤버 - 테이블 Player): 유예 시작 · 자리 · 입장 인원 · 복귀 · 재합류 · 추방 · 파티장 승계 · 만료 자동 탈퇴 · 즉시 탈퇴 조건 · 리스너.
--   (나) runLive  - 실제 Player + 실제 보스 스폰: 보스 모델 Attribute(BossHpRatio · BossName · BossEncounterId) · 머리 위 바 없음(잡몹은 있음) · HP 전달 · 파티 보스에서 끊긴 멤버는 입장 인원(HP 배수)에 안 든다 ·
--                 복귀해도 보스 HP 불변 · 복귀한 멤버는 보스전 밖 · 보스전이 끝나면 Attribute가 지워진다.
-- env = { ensureBackup, restore, applyStage } - DevTools의 로컬 헬퍼. 검증이 만든 것(보스 · 파티 · 더미 · 프로필 값)은 끝에서 전부 되돌리고 "encounter 없는 보스 모델 0"을 마지막에 찍는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BossRules = require(ReplicatedStorage.Shared.BossRules)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossEncounter = require(script.Parent.BossEncounter)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)
local PartyState = require(script.Parent.PartyState)
local PlayerProfile = require(script.Parent.PlayerProfile)
local PlayerState = require(script.Parent.PlayerState)

local S19bVerify = {}

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S19b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function near(actual, expected, tolerance)
	return actual ~= nil and math.abs(actual - expected) <= tolerance
end

local function standIn(name, userId)
	return { Name = name, DisplayName = name, UserId = userId, Parent = workspace, Character = nil }
end

local function recordOf(party, userId)
	for _, record in ipairs(PartyState.getMemberRecords(party)) do
		if record.userId == userId then
			return record
		end
	end
	return nil
end

local function indexOf(party, userId)
	for index, record in ipairs(PartyState.getMemberRecords(party)) do
		if record.userId == userId then
			return index
		end
	end
	return nil
end

-- 3인 파티(A 리더 · B · C)를 새로 만든다. 스탠드인은 서로 다른 userId를 쓴다(다른 검증과 안 겹치게 음수 대역).
local function makeParty(seed)
	local a, b, c = standIn("점검A" .. seed, -190000 - seed * 10 - 1), standIn("점검B" .. seed, -190000 - seed * 10 - 2), standIn("점검C" .. seed, -190000 - seed * 10 - 3)
	local party = PartyState.create(a)
	PartyState.attachMember(party, b)
	PartyState.attachMember(party, c)
	return party, a, b, c
end

local function disbandAll(party, list)
	for _, member in ipairs(list) do
		PartyState.leave(member, "leave")
	end
	return PartyState.getAllParties()[party.id] == nil
end

-- ─────────────────────────── (가) 파티 연결 끊김 유예 ───────────────────────────

local function runPure()
	print("===S19b 검증 시작(가: 파티 연결 끊김 유예 - PartyState 스탠드인)===")
	local r = newRecorder("가")
	local grace = PartyConfig.disconnectGraceSeconds
	local removedLog = {}
	local listenerActive = true
	PartyState.onMemberRemoved(function(player, _, reason)
		if listenerActive then
			table.insert(removedLog, { player = player, reason = reason })
		end
	end)

	r.section("[1] 유예 시작", function()
		local party, a, b, c = makeParty(1)
		local okStart = PartyState.disconnect(b)
		local record = recordOf(party, b.UserId)
		local snapshot = PartyState.debugSnapshot(party)
		local snapshotB
		for _, member in ipairs(snapshot.members) do
			if member.userId == b.UserId then
				snapshotB = member
			end
		end
		r.check(("1 접속 끊김 → 바로 탈퇴하지 않고 유예: 반환 %s · 파티 유지 %s · 기록 %s · 접속 중 멤버 %d(기대 2) · 자리 %d(기대 3) · 입장 인원 %d(기대 2) · B의 파티 %s(기대 nil)"):format(
			tostring(okStart), tostring(PartyState.getAllParties()[party.id] ~= nil), tostring(record ~= nil and record.awayUntil ~= nil), #PartyState.getMemberPlayers(party),
			PartyState.getSeatCount(party), PartyState.getSize(party), tostring(PartyState.getParty(b))),
			okStart == true and PartyState.getAllParties()[party.id] ~= nil and record ~= nil and record.awayUntil ~= nil and #PartyState.getMemberPlayers(party) == 2
				and PartyState.getSeatCount(party) == 3 and PartyState.getSize(party) == 2 and PartyState.getParty(b) == nil)
		r.check(("2 스냅샷: awayRemaining %s(기대 %d · 설정값) · 이름 %s · 나머지 멤버는 nil"):format(tostring(snapshotB and snapshotB.awayRemaining), grace, tostring(snapshotB and snapshotB.name)),
			snapshotB ~= nil and near(snapshotB.awayRemaining, grace, 1) and snapshot.members[1].awayRemaining == nil)
		local lastRemoved = removedLog[#removedLog]
		r.check(("3 리스너에 disconnect로 즉시 알림(보스전 이탈 · 투표 취소 통로): %s"):format(lastRemoved and tostring(lastRemoved.reason) or "없음"), lastRemoved ~= nil and lastRemoved.player == b and lastRemoved.reason == "disconnect")
		disbandAll(party, { a, c })
	end)

	r.section("[2] 복귀", function()
		local party, a, b, c = makeParty(2)
		local before = indexOf(party, b.UserId)
		PartyState.disconnect(b)
		local b2 = standIn("점검B2", b.UserId) -- 같은 계정이 새 Player로 접속
		local ok, foundParty = PartyState.reclaim(b2)
		local record = recordOf(party, b.UserId)
		r.check(("4 같은 서버 재접속 → 복귀: reclaim %s · 같은 파티 %s · 가입 순서 %s → %s · 유예 표시 %s(기대 nil) · 자리 %d · 입장 인원 %d(기대 3) · 새 Player가 파티 소속 %s"):format(
			tostring(ok), tostring(foundParty == party), tostring(before), tostring(indexOf(party, b.UserId)), tostring(record and record.awayUntil), PartyState.getSeatCount(party), PartyState.getSize(party), tostring(PartyState.getParty(b2) == party)),
			ok == true and foundParty == party and before == indexOf(party, b.UserId) and record ~= nil and record.awayUntil == nil and PartyState.getSize(party) == 3 and PartyState.getParty(b2) == party)
		-- 다른 계정은 복귀되지 않는다.
		local stranger = standIn("점검낯선이", -199999)
		r.check("5 유예 중이 아닌 계정은 reclaim이 false", PartyState.reclaim(stranger) == false)
		disbandAll(party, { a, b2, c })
	end)

	r.section("[3] 코드 합류로 돌아온 경우(attachMember)", function()
		local party, a, b, c = makeParty(3)
		PartyState.disconnect(b)
		local b3 = standIn("점검B3", b.UserId)
		PartyState.attachMember(party, b3) -- requestJoin · 도착 · 수락이 마지막에 부르는 함수
		r.check(("6 attachMember: 새 기록을 만들지 않고 자리를 되찾는다 - 기록 수 %d(기대 3) · B의 기록 Player 일치 %s · 유예 표시 %s(기대 nil)"):format(
			#PartyState.getMemberRecords(party), tostring(recordOf(party, b.UserId).player == b3), tostring(recordOf(party, b.UserId).awayUntil)),
			#PartyState.getMemberRecords(party) == 3 and recordOf(party, b.UserId).player == b3 and recordOf(party, b.UserId).awayUntil == nil)
		disbandAll(party, { a, b3, c })
	end)

	r.section("[4] 파티장 추방", function()
		local party, a, b, c = makeParty(4)
		PartyState.disconnect(b)
		local kicked, why = PartyState.kick(a, b.UserId)
		r.check(("7 유예 중인 멤버를 파티장이 즉시 추방: kick=%s(%s) · 기록 %d개(기대 2) · B 기록 %s(기대 없음)"):format(tostring(kicked), tostring(why), #PartyState.getMemberRecords(party), tostring(recordOf(party, b.UserId))),
			kicked == true and #PartyState.getMemberRecords(party) == 2 and recordOf(party, b.UserId) == nil)
		disbandAll(party, { a, c })
	end)

	r.section("[5] 파티장이 끊김", function()
		local party, a, b, c = makeParty(5)
		PartyState.disconnect(a)
		local newLeader = PartyState.getLeader(party)
		local a2 = standIn("점검A2", a.UserId)
		PartyState.reclaim(a2)
		r.check(("8 파티장이 끊기면 접속 중인 가장 오래된 멤버가 승계: 새 파티장 %s(기대 %s) · A 복귀 뒤 파티장 %s(기대 %s 그대로) · A 가입 순서 %s(기대 1)"):format(
			tostring(newLeader and newLeader.Name), b.Name, tostring(PartyState.getLeader(party) and PartyState.getLeader(party).Name), b.Name, tostring(indexOf(party, a.UserId))),
			newLeader == b and PartyState.getLeader(party) == b and indexOf(party, a.UserId) == 1)
		disbandAll(party, { a2, b, c })
	end)

	r.section("[6] 만료 자동 탈퇴(실제 타이머)", function()
		local party, a, b, c = makeParty(6)
		local removedBefore = #removedLog
		PartyState.disconnect(c, 1) -- 유예 1초로 짧게 - 실제 task.delay 경로
		local heldAt = recordOf(party, c.UserId) ~= nil
		task.wait(2.5)
		r.check(("9 유예가 지나면 자동 탈퇴: 유예 중에는 기록 있음 %s · 지난 뒤 기록 %s(기대 없음) · 파티 유지(2명) %s"):format(
			tostring(heldAt), tostring(recordOf(party, c.UserId)), tostring(PartyState.getAllParties()[party.id] ~= nil and #PartyState.getMemberRecords(party) == 2)),
			heldAt and recordOf(party, c.UserId) == nil and PartyState.getAllParties()[party.id] ~= nil and #PartyState.getMemberRecords(party) == 2)
		-- 남은 둘 중 B가 끊겼다가 만료 → 접속 중인 A 혼자 → 파티 해산.
		PartyState.disconnect(b, 1)
		task.wait(2.5)
		r.check(("10 마지막으로 남은 접속자가 혼자가 되면 해산: A의 파티 %s(기대 nil) · 파티 표에 남음 %s(기대 false)"):format(tostring(PartyState.getParty(a)), tostring(PartyState.getAllParties()[party.id] ~= nil)),
			PartyState.getParty(a) == nil and PartyState.getAllParties()[party.id] == nil)
		local disconnectCount, graceCount = 0, 0
		for index = removedBefore + 1, #removedLog do
			if removedLog[index].reason == "disconnect" then
				disconnectCount += 1
			elseif removedLog[index].reason == "grace" then
				graceCount += 1
			end
		end
		r.check(("11 리스너 알림은 끊긴 순간 한 번뿐(disconnect %d건 · 기대 2 = C · B) - 자동 탈퇴(만료) 때 다시 알리지 않는다(grace %d건 · 기대 0)"):format(disconnectCount, graceCount), disconnectCount == 2 and graceCount == 0)
	end)

	r.section("[7] 즉시 탈퇴 조건", function()
		-- 접속 중인 다른 멤버가 없으면(전원이 끊김) 유예 없이 바로 탈퇴 → 남은 것이 끊긴 사람뿐이라 해산.
		local a, b = standIn("점검단A", -198001), standIn("점검단B", -198002)
		local party = PartyState.create(a)
		PartyState.attachMember(party, b)
		PartyState.disconnect(b) -- A가 접속 중이라 유예
		local heldB = recordOf(party, b.UserId) ~= nil
		PartyState.disconnect(a) -- 접속 중인 다른 멤버가 없다 → 즉시 탈퇴 → 남은 B(끊김)만 → 해산
		r.check(("12 전원이 끊기면 유예 없이 정리: B 유예 중이었음 %s · A 끊김 뒤 파티 표에 남음 %s(기대 false)"):format(tostring(heldB), tostring(PartyState.getAllParties()[party.id] ~= nil)),
			heldB and PartyState.getAllParties()[party.id] == nil)
		-- 파티가 없는 사람 · 유예 0
		local solo = standIn("점검솔로", -198003)
		r.check("13 파티가 없는 사람의 끊김은 false(할 일 없음)", PartyState.disconnect(solo) == false)
		local party2, a2, b2, c2 = makeParty(7)
		PartyState.disconnect(b2, 0)
		r.check(("14 유예 0이면 옛 동작(즉시 탈퇴): B 기록 %s(기대 없음) · 기록 %d개(기대 2)"):format(tostring(recordOf(party2, b2.UserId)), #PartyState.getMemberRecords(party2)),
			recordOf(party2, b2.UserId) == nil and #PartyState.getMemberRecords(party2) == 2)
		disbandAll(party2, { a2, c2 })
	end)

	listenerActive = false
	local leftover = 0
	for _, party in pairs(PartyState.getAllParties()) do
		for _, record in ipairs(PartyState.getMemberRecords(party)) do
			if record.userId <= -190000 and record.userId >= -199999 then
				leftover += 1
			end
		end
	end
	r.check(("15 검증이 만든 점검 멤버가 파티에 남지 않았다: %d(기대 0)"):format(leftover), leftover == 0)
	local pass, total = r.summary()
	print(("===S19b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 보스 · 파티 ───────────────────────────

local function farSpotFrom(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
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

local function overheadBar(model)
	local head = model:FindFirstChild("Head")
	local gui = head and head:FindFirstChild("NameplateGui")
	return gui and gui:FindFirstChild("HpBarBackground"), gui and gui:FindFirstChild("NameLabel")
end

local function runLive(player, env)
	print("===S19b 검증 시작(나: 실제 보스 · 파티 - 체력바 Attribute · 끊긴 멤버 · HP 불변)===")
	local r = newRecorder("나")
	local function finish()
		local pass, total = r.summary()
		print(("===S19b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
	end
	local character = player.Character
	if not PlayerProfile.getProfile(player) or not (character and character:FindFirstChild("HumanoidRootPart")) then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		return finish()
	end
	env.ensureBackup(player)
	local STAGE = 5
	local guardian = "section_guardian"

	local ok, err = pcall(function()
		-- ── 솔로 보스 ──
		BossEncounter.despawnFor(player)
		env.applyStage(player, STAGE)
		BossEncounter.setDebugForcedBoss(player, guardian)
		BossEncounter.spawnFor(player, STAGE)
		local model = BossEncounter.getActive(player)
		local data = model and MonsterState.getData(model)
		if not model then
			r.check("솔로 보스 스폰 실패", false)
			return
		end
		local bar, nameLabel = overheadBar(model)
		r.check(("1 보스 모델 Attribute: BossHpRatio %s(기대 1) · BossName '%s'(기대 '%s') · BossEncounterId %s · 내 Attribute %s(같아야 한다)"):format(
			tostring(model:GetAttribute("BossHpRatio")), tostring(model:GetAttribute("BossName")), data.displayName, tostring(model:GetAttribute("BossEncounterId")), tostring(player:GetAttribute("BossEncounterId"))),
			model:GetAttribute("BossHpRatio") == 1 and model:GetAttribute("BossName") == data.displayName and type(model:GetAttribute("BossEncounterId")) == "number"
				and model:GetAttribute("BossEncounterId") == player:GetAttribute("BossEncounterId"))
		r.check(("2 보스 머리 위에는 체력바가 없다(이름표는 있다): HpBarBackground %s(기대 없음) · NameLabel %s"):format(tostring(bar), tostring(nameLabel ~= nil)), bar == nil and nameLabel ~= nil)

		-- HP 전달: 서버가 계산한 비율이 Attribute로 그대로 나간다.
		local _, maxHp = MonsterState.getBossHp(model)
		MonsterState.applyDamage(model, maxHp * 0.3, STAGE, player)
		MonsterSpawner.updateHpLabel(model)
		local afterHit = model:GetAttribute("BossHpRatio")
		MonsterState.applyDamage(model, maxHp * 0.5, STAGE, player)
		MonsterSpawner.updateHpLabel(model)
		r.check(("3 피해 뒤 Attribute = 서버 비율: 30%% 피해 → %s(기대 0.7) · 50%% 더 → %s(기대 0.2 · MonsterState.getHpRatio %.4f와 같다)"):format(
			tostring(afterHit), tostring(model:GetAttribute("BossHpRatio")), MonsterState.getHpRatio(model)),
			near(afterHit, 0.7, 1e-6) and near(model:GetAttribute("BossHpRatio"), 0.2, 1e-6) and near(model:GetAttribute("BossHpRatio"), MonsterState.getHpRatio(model), 1e-9))

		-- 잡몹은 그대로(머리 위 바 있음 · 보스 Attribute 없음).
		local mob = MonsterSpawner.spawn(MonsterData.tier1, farSpotFrom(player), nil, {})
		local mobBar = overheadBar(mob)
		r.check(("4 잡몹은 머리 위 바가 그대로: HpBarBackground %s(기대 있음) · BossHpRatio %s(기대 nil)"):format(tostring(mobBar ~= nil), tostring(mob:GetAttribute("BossHpRatio"))), mobBar ~= nil and mob:GetAttribute("BossHpRatio") == nil)
		MonsterState.clear(mob)
		mob:Destroy()

		-- 보스전이 끝나면 Attribute가 지워진다.
		BossEncounter.despawnFor(player)
		r.check(("5 보스전이 끝나면 내 BossEncounterId가 지워진다: %s(기대 nil)"):format(tostring(player:GetAttribute("BossEncounterId"))), player:GetAttribute("BossEncounterId") == nil)

		-- ── 파티 보스: 끊긴 멤버 ──
		env.applyStage(player, STAGE)
		local soloHp = BossRules.buildInstanceData(STAGE, guardian, 1).hp
		local b = standIn("점검끊김B", -197001)
		local party = PartyState.create(player)
		PartyState.attachMember(party, b)
		PartyState.disconnect(b) -- 보스 입장 전에 끊김
		BossEncounter.setDebugForcedBoss(player, guardian)
		local spawned = BossEncounter.spawnForParty(party, player, STAGE)
		local partyModel = BossEncounter.getActive(player)
		local hp0, maxHp0 = nil, nil
		if partyModel then
			hp0, maxHp0 = MonsterState.getBossHp(partyModel)
		end
		r.check(("6 끊긴 멤버는 입장 인원(HP 배수 N)에 안 든다: 스폰 %s · 파티 인원 %d(끊긴 멤버 포함 자리 %d) · 보스 최대 HP %s(기대 솔로 값 %s와 같다)"):format(
			tostring(spawned), PartyState.getSize(party), PartyState.getSeatCount(party), tostring(maxHp0), tostring(soloHp)),
			spawned == true and partyModel ~= nil and PartyState.getSize(party) == 1 and PartyState.getSeatCount(party) == 2 and near(maxHp0, soloHp, soloHp * 1e-9))

		-- 보스전 도중 복귀 - 보스전 밖(필드)으로 들어오고 HP는 그대로.
		if partyModel then
			MonsterState.applyDamage(partyModel, maxHp0 * 0.25, STAGE, player)
			MonsterSpawner.updateHpLabel(partyModel)
			local hpBefore = MonsterState.getBossHp(partyModel)
			local b2 = standIn("점검끊김B2", b.UserId)
			local reclaimed = PartyState.reclaim(b2)
			local hpAfter, maxAfter = MonsterState.getBossHp(partyModel)
			r.check(("7 보스전 중 복귀: reclaim %s · 파티 소속 %s · 보스전 밖(getActive nil) %s · 보스 HP 그대로 %s → %s · 최대 HP 그대로 %s → %s · 보스전 멤버 수 %d(기대 1)"):format(
				tostring(reclaimed), tostring(PartyState.getParty(b2) == party), tostring(BossEncounter.getActive(b2) == nil), tostring(hpBefore), tostring(hpAfter), tostring(maxHp0), tostring(maxAfter),
				#BossEncounter.getMembersOfModel(partyModel)),
				reclaimed == true and PartyState.getParty(b2) == party and BossEncounter.getActive(b2) == nil and hpBefore == hpAfter and maxHp0 == maxAfter and #BossEncounter.getMembersOfModel(partyModel) == 1)
			r.check(("8 파티 보스 모델 Attribute도 같은 규칙: BossHpRatio %s(기대 %.4f) · 내 BossEncounterId = 모델 %s"):format(
				tostring(partyModel:GetAttribute("BossHpRatio")), MonsterState.getHpRatio(partyModel), tostring(player:GetAttribute("BossEncounterId") == partyModel:GetAttribute("BossEncounterId"))),
				near(partyModel:GetAttribute("BossHpRatio"), MonsterState.getHpRatio(partyModel), 1e-9) and player:GetAttribute("BossEncounterId") == partyModel:GetAttribute("BossEncounterId"))
			PartyState.leave(b2, "leave")
		end
		PartyState.leave(player, "leave")
	end)
	if not ok then
		r.check(("(나) 실행 중 에러: %s"):format(tostring(err)), false)
	end

	BossEncounter.despawnFor(player)
	BossEncounter.debugClearHints(player)
	PartyState.leave(player, "leave")
	PlayerState.setHp(player, PlayerState.getMaxHp(player))
	local orphans = 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
	end
	local leftoverParty = PartyState.getParty(player) ~= nil
	r.check(("9 검증 뒤 encounter 없는 보스 모델 %d개(기대 0) · 파티 남음 %s(기대 false) · 내 BossEncounterId %s(기대 nil)"):format(orphans, tostring(leftoverParty), tostring(player:GetAttribute("BossEncounterId"))),
		orphans == 0 and not leftoverParty and player:GetAttribute("BossEncounterId") == nil)
	env.restore(player)
	finish()
end

S19bVerify.runPure = runPure
S19bVerify.runLive = runLive

return S19bVerify
