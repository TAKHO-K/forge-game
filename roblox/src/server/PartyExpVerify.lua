-- S09 자동 검증(PRD 20.73 [5-1] · 30-0 S09) - 파티 경험치 +10 / 15 / 20% · Attribute PartyExpBonus.
--   (가) 순수 함수 - 서버 시작 때(플레이어 없이): 배수표 12칸(솔로 / 2 / 3 / 4인 × 옵션 0 / 12.5 / 25%) · "합이 아니라 곱" · p · b 불변.
--   (나) 실제 Player - 보스 검증 체인의 끝에서: 솔로 · 더미 3명(인원에 안 든다) · 스탠드인 2 ~ 4인 · 실제 처치 경험치 · 탈퇴 · 추방 · 해산 뒤 Attribute.
-- env = { ensureBackup, restore } - DevTools의 로컬 헬퍼. 검증이 바꾼 것(직업 · 장비 · 경험치 · 가방 · 파티)은 (나)가 끝날 때 전부 되돌린다.
-- 스탠드인(테이블 Player)은 SetAttribute · FireClient가 없다 - 파티 인원은 실제 Player 표(PartyState의 멤버 수)로만 흉내 낸다(다중 클라 불가). 그래서 스탠드인의 Attribute는 읽지 않고
-- 실제 Player(리더)의 Attribute와 서버 판정(PlayerProfile.getExpGainMultiplier)만 읽는다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local Option = require(ReplicatedStorage.Shared.Option)
local CombatResolution = require(script.Parent.CombatResolution)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ItemDropState = require(script.Parent.ItemDropState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local MonsterState = require(script.Parent.MonsterState)
local PartyState = require(script.Parent.PartyState)
local PartyExpBonus = require(script.Parent.PartyExpBonus)
local PlayerProfile = require(script.Parent.PlayerProfile)
local TutorialState = require(script.Parent.TutorialState)

local PartyExpVerify = {}

local EPSILON = 1e-9

-- 이 세션 전(2026-09-20, 커밋 ff88ba0)의 p · b. 입력(BossData.stageInterval · InfiniteStageConfig.growthRate · PartyConfig.maxMembers · healerDpsRatio)은 이 세션이 안 건드린다 -
-- p = 1 - 5 × ln(1.155) / ln(4) · b = 4 / (3 + 0.9491) - 1을 밖에서(python) 계산해 적었다.
-- P2.5a: k가 1.02로 바뀌었지만 p는 BossData.intervalPowerRatio(= 옛 1.155^5)에서 나와 그대로다.
local BASELINE_P = 0.4802678708966678
local BASELINE_B = 0.012889012686434942

local function newRecorder(tag)
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S09][%s] %s %s"):format(tag, label, ok and "O" or "X"))
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

local function near(a, b)
	return math.abs(a - b) < EPSILON
end

function PartyExpVerify.runPure()
	print("===S09 검증 시작(가: 순수 함수 · 배수표)===")
	local r = newRecorder("가")

	-- 옵션 합은 실제 경로와 같이 Option.sumWithCap을 거친다: 0 = 옵션 없음 / 0.125 = 태초 1개 / 상한 = 태초 2개(0.25) 아니라 3개(0.375) - 상한을 넘는 값이 1.25에서 잘리는지도 같이 본다.
	local optionColumns = {
		{ label = "옵션 0%", values = {} },
		{ label = "옵션 12.5%(태초 1개)", values = { 0.125 } },
		{ label = "옵션 상한(합 37.5% → 25%로 잘림)", values = { 0.125, 0.125, 0.125 } },
	}
	-- PRD 20.73 [5-1] 표(소수 셋째 자리 반올림 전 값). 행 = 파티 인원 1(솔로) ~ 4.
	local expected = {
		[1] = { 1.000, 1.125, 1.250 },
		[2] = { 1.100, 1.2375, 1.375 },
		[3] = { 1.150, 1.29375, 1.4375 },
		[4] = { 1.200, 1.350, 1.500 },
	}
	for memberCount = 1, PartyConfig.maxMembers do
		for column, optionColumn in ipairs(optionColumns) do
			local optionBonus = Option.sumWithCap(optionColumn.values, "expGain")
			local partyBonus = PartyState.getExpBonusForCount(memberCount)
			local multiplier = PlayerProfile.combineExpMultiplier(optionBonus, partyBonus)
			r.check(("배수표 %s · %s: 옵션 합 %.3f · 파티 보너스 %.2f → ×%.5f(기대 ×%.5f)"):format(
				memberCount == 1 and "솔로" or memberCount .. "인", optionColumn.label, optionBonus, partyBonus, multiplier, expected[memberCount][column]),
				near(multiplier, expected[memberCount][column]))
		end
	end

	-- 합이 아니라 곱: 4인 + 옵션 상한 = 1.25 × 1.2 = 1.500(합이면 1.45). ★진짜 합격 기준 1
	local capped = Option.sumWithCap({ 0.125, 0.125, 0.125 }, "expGain")
	local product = PlayerProfile.combineExpMultiplier(capped, PartyState.getExpBonusForCount(4))
	r.check(("4인 + 옵션 상한 = ×%.4f(기대 1.5000 - 곱. 합이면 %.4f) ★진짜 합격 기준"):format(product, 1 + capped + PartyState.getExpBonusForCount(4)), near(product, 1.5) and not near(product, 1.45))

	-- p · b 불변: 파티 경험치는 보스 HP 배수 지수 p · 힐러 버프 b를 안 읽는다(PRD 20.73 [5-1]). 이 세션 전 값과 같은 값인가.
	local p, b = BossRules.partyHpExponent(), PartyConfig.healerBuffFraction
	r.check(("p · b 불변: BossRules.partyHpExponent = %.10f(기대 %.10f) · PartyConfig.healerBuffFraction = %.10f(기대 %.10f)"):format(p, BASELINE_P, b, BASELINE_B),
		near(p, BASELINE_P) and near(b, BASELINE_B))

	local pass, total = r.summary()
	print(("===S09 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ── (나) 처치 · 정리 헬퍼(EnhanceVerify의 killMobs와 같은 방식 - 실제 스폰 → applyDamage → resolveHit) ──

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
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

-- 플레이어에게서 가장 먼 tier 구역의 중심(지면 위 5) - 지면이 없는 곳이면 드랍이 주인 발밑에 떨어져 자동 줍기가 가방을 채운다(S04 사전 작업의 교훈).
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

-- 실제 처치 경로로 tier1 기본형 1마리를 잡고 그 처치가 준 경험치(프로필의 characterExp 증가량)를 돌려준다. 스폰한 몬스터 · 땅의 드랍은 치운다.
local function killOneAndMeasureExp(player)
	local classState = PlayerProfile.getProfile(player).classes[PlayerProfile.getClassId(player)]
	local expBefore = classState.characterExp
	local monstersBefore, groundBefore = monsterSet(), groundSet()
	local stage = TutorialState.getMonsterStage(player)
	local model = MonsterSpawner.spawn(MonsterData.tier1, farSpotFrom(player), nil, {})
	local isDead = MonsterState.applyDamage(model, 1e12, stage, player)
	CombatResolution.resolveHit(player, model, isDead)
	task.wait(WorldConfig.zoneMonsterGrid.respawnDelaySeconds + 1)
	local gained = classState.characterExp - expBefore
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
	return gained, stage
end

local function standIn(name, userId)
	return { Name = name, UserId = userId, Parent = workspace, Character = nil }
end

-- 지금 파티 상태 한 줄: 인원(더미 포함) · 실제 Player 수 · 서버 판정 배수 · 실제 Player의 Attribute.
local function partyLine(player)
	local party = PartyState.getParty(player)
	return ("파티 인원 %d(실제 %d) · 보너스 %.2f · 배수 ×%.4f · Attribute %s"):format(
		PartyState.getSize(party), #PartyState.getMemberPlayers(party), PartyState.getExpBonus(party), PlayerProfile.getExpGainMultiplier(player), tostring(player:GetAttribute("PartyExpBonus")))
end

function PartyExpVerify.runLive(player, env)
	print("===S09 검증 시작(나: 실제 Player · 실제 PartyState · 실제 처치 경로)===")
	local r = newRecorder("나")
	local root = rootOf(player)
	if not PlayerProfile.getProfile(player) or not root then
		r.check("프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S09 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end
	if PartyState.getParty(player) then
		r.check("이미 파티에 있어 검증을 건너뜀(먼저 파티를 나가세요)", false)
		local pass, total = r.summary()
		print(("===S09 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player) -- classes(직업 · 장비 · 보석 · 경험치) · gold · 가방은 env.restore가 되돌린다
	local savedCFrame = root.CFrame
	local savedClassId = PlayerProfile.getClassId(player)
	local monstersBefore, groundBefore = monsterSet(), groundSet()
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end

	-- 기준 상태: 착용 장비 · 보석을 비워 성장 옵션이 0이 되게 한다(개발 계정의 옵션이 기대값을 흔들지 않게 - S04 (나)와 같다). 옵션 상한 항목만 성장 옵션 장비를 낀다.
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		PlayerProfile.setEquippedDirect(player, part, nil)
	end
	local weapon = PlayerProfile.getWeapon(player)
	for slot = 1, #weapon.gems do
		weapon.gems[slot] = false
	end
	local optionBonus = PlayerProfile.getOptionBonus(player, "expGain")
	print(("[S09][나] 기준 상태: 성장 옵션 합 %.3f(기대 0.000) · 직업 %s"):format(optionBonus, tostring(PlayerProfile.getClassId(player))))

	local B, C, D = standIn("S09StandB", -9301), standIn("S09StandC", -9302), standIn("S09StandD", -9303)
	-- P2 G: 파티 보너스는 "같은 구역 · 반경 150 · 최근 60초 활동"을 만족한 파티원만 센다. 이 블록은 인원 → 배수(+10/15/20%)를 재는 옛 검증이라
	-- 스탠드인 셋과 실제 Player를 같은 가상 구역 · 같은 자리에 두고(PartyExpBonus.debugSetPresence - Studio 전용) 스탠드인이 방금 활동한 것으로 기록한다.
	-- 조건 자체의 검증은 P2(가) · P2(나)가 한다.
	local presence = { zone = "S09-verify", position = Vector3.new(0, 0, 0) }
	for _, member in ipairs({ player, B, C, D }) do
		PartyExpBonus.debugSetPresence(member, presence)
	end
	for _, member in ipairs({ B, C, D }) do
		PartyState.noteActivity(member)
	end

	r.section("[1] 솔로", function()
		r.check(("솔로: %s(기대 인원 0 · 보너스 0.00 · 배수 ×1.0000 · Attribute 없음 또는 0)"):format(partyLine(player)),
			PartyState.getParty(player) == nil and near(PlayerProfile.getExpGainMultiplier(player), 1) and (player:GetAttribute("PartyExpBonus") or 0) == 0)
	end)

	local soloGain, soloStage
	r.section("[2] 솔로 처치 1마리", function()
		soloGain, soloStage = killOneAndMeasureExp(player)
		r.check(("솔로 tier1 1마리 처치(스테이지 %s): 경험치 +%.4f(기대 > 0)"):format(tostring(soloStage), soloGain), soloGain > 0)
	end)

	r.section("[3] 더미 3명 - 인원에 안 든다", function()
		local level = PlayerProfile.getCharacterLevel(player) or 1
		local ok, added = PartyState.addDummies(player, 3, function(index)
			return { classId = ClassData.order[(index - 1) % #ClassData.order + 1], level = level, stage = soloStage or 1, hp = 1, maxHp = 1 } -- "/gg party dummy"와 같은 모양
		end)
		local party = PartyState.getParty(player)
		r.check(("더미 3명과 파티: addDummies=%s(%s명) · %s(기대 인원 4 · 실제 1 · 보너스 0.00 · 배수 ×1.0000 · Attribute 0) ★진짜 합격 기준"):format(tostring(ok), tostring(added), partyLine(player)),
			ok and PartyState.getSize(party) == 4 and #PartyState.getMemberPlayers(party) == 1 and near(PartyState.getExpBonus(party), 0)
				and near(PlayerProfile.getExpGainMultiplier(player), 1) and player:GetAttribute("PartyExpBonus") == 0)
		PartyState.clearDummies(player)
		r.check(("더미 제거 뒤: 파티 %s(기대 nil - 혼자 남으면 해산) · Attribute %s(기대 0)"):format(tostring(PartyState.getParty(player)), tostring(player:GetAttribute("PartyExpBonus"))),
			PartyState.getParty(player) == nil and player:GetAttribute("PartyExpBonus") == 0)
	end)

	r.section("[4] 실제 Player 표 2 ~ 4명(스탠드인)", function()
		local ok1 = PartyState.invite(player, B)
		local ok2 = PartyState.respondInvite(B, true)
		r.check(("스탠드인 1명 합류: invite=%s accept=%s · %s(기대 인원 2 · 보너스 0.10 · 배수 ×1.1000 · Attribute 0.1)"):format(tostring(ok1), tostring(ok2), partyLine(player)),
			ok1 and ok2 and near(PartyState.getExpBonus(PartyState.getParty(player)), 0.10) and near(PlayerProfile.getExpGainMultiplier(player), 1.10) and near(player:GetAttribute("PartyExpBonus") or -1, 0.10))
		PartyState.invite(player, C)
		PartyState.respondInvite(C, true)
		r.check(("3명: %s(기대 인원 3 · 보너스 0.15 · 배수 ×1.1500 · Attribute 0.15)"):format(partyLine(player)),
			near(PartyState.getExpBonus(PartyState.getParty(player)), 0.15) and near(PlayerProfile.getExpGainMultiplier(player), 1.15) and near(player:GetAttribute("PartyExpBonus") or -1, 0.15))
		PartyState.invite(player, D)
		PartyState.respondInvite(D, true)
		r.check(("4명: %s(기대 인원 4 · 보너스 0.20 · 배수 ×1.2000 · Attribute 0.2)"):format(partyLine(player)),
			near(PartyState.getExpBonus(PartyState.getParty(player)), 0.20) and near(PlayerProfile.getExpGainMultiplier(player), 1.20) and near(player:GetAttribute("PartyExpBonus") or -1, 0.20))

		-- 같은 잡몹(tier1 기본형 · 같은 스테이지)의 처치 경험치가 솔로의 1.2배인가.
		local gain, stage = killOneAndMeasureExp(player)
		r.check(("4인 tier1 1마리 처치(스테이지 %s): 경험치 +%.4f / 솔로 +%.4f = ×%.4f(기대 ×1.2000 · 같은 스테이지 %s)"):format(
			tostring(stage), gain, soloGain or 0, soloGain and gain / soloGain or 0, tostring(soloStage)),
			soloGain ~= nil and stage == soloStage and math.abs(gain / soloGain - 1.2) < 1e-6)
	end)

	r.section("[5] 옵션 상한 + 4인 = ×1.500", function()
		-- 성장 옵션 태초 3부위(최대 롤 - 합이 상한 25%를 넘는다): 26-2 검증이 옵션 장비를 만드는 방식(setEquippedDirect + option 테이블)을 따른다.
		-- P2.5c: 태초 등급 몫 0.65로 중앙 롤 3개 합이 24.4%(< 상한)라 최대 롤(1.125)로 올렸다(합 약 27.5%).
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			PlayerProfile.setEquippedDirect(player, part, {
				grade = "primordial", part = part, dropStage = 100, itemLevel = 100, tierIndex = 1, locked = true, option = { id = "expGain", roll = 1.125 },
			})
		end
		local capBonus = PlayerProfile.getOptionBonus(player, "expGain")
		local multiplier = PlayerProfile.getExpGainMultiplier(player)
		r.check(("성장 옵션 3부위(최대 롤 - 합 > 25%%) · 4인: 옵션 합 %.3f(기대 0.250 - 상한) · 배수 ×%.4f(기대 ×1.5000 - 곱. 합이면 ×1.4500) ★진짜 합격 기준"):format(capBonus, multiplier),
			near(capBonus, 0.25) and near(multiplier, 1.5))
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			PlayerProfile.setEquippedDirect(player, part, nil)
		end
	end)

	r.section("[6] 추방 · 탈퇴 · 해산 뒤 Attribute", function()
		local kicked = PartyState.kick(player, D.UserId)
		r.check(("추방(4 → 3명): kick=%s · %s(기대 인원 3 · 보너스 0.15 · Attribute 0.15)"):format(tostring(kicked), partyLine(player)),
			kicked == true and near(PartyState.getExpBonus(PartyState.getParty(player)), 0.15) and near(player:GetAttribute("PartyExpBonus") or -1, 0.15))
		PartyState.leave(C, "leave")
		r.check(("탈퇴(3 → 2명): %s(기대 인원 2 · 보너스 0.10 · Attribute 0.1)"):format(partyLine(player)),
			near(PartyState.getExpBonus(PartyState.getParty(player)), 0.10) and near(player:GetAttribute("PartyExpBonus") or -1, 0.10))
		PartyState.leave(B, "leave")
		r.check(("마지막 탈퇴(2 → 1명 - 해산): 파티 %s(기대 nil) · 배수 ×%.4f(기대 ×1.0000) · Attribute %s(기대 0)"):format(
			tostring(PartyState.getParty(player)), PlayerProfile.getExpGainMultiplier(player), tostring(player:GetAttribute("PartyExpBonus"))),
			PartyState.getParty(player) == nil and near(PlayerProfile.getExpGainMultiplier(player), 1) and player:GetAttribute("PartyExpBonus") == 0)
	end)

	-- 되돌리기: 파티 · 직업 · 장비 · 경험치 · 가방 · 위치. 검증이 만든 것(스탠드인 파티 · 몬스터 · 땅의 드랍)은 없어야 한다.
	for _, member in ipairs({ D, C, B }) do
		PartyState.leave(member, "leave")
	end
	for _, member in ipairs({ player, B, C, D }) do
		PartyExpBonus.debugSetPresence(member, nil)
	end
	if PartyState.getParty(player) then
		PartyState.leave(player, "leave")
	end
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
	end
	local leftoverMonsters, leftoverGround = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		if not monstersBefore[model] then
			leftoverMonsters += 1
		end
	end
	for _, model in ipairs(ItemDropState.getAllModels()) do
		if not groundBefore[model] then
			leftoverGround += 1
		end
	end
	r.check(("검증 뒤 되돌림: 파티 %s(기대 nil) · 스탠드인 파티 %s %s %s(기대 nil) · Attribute %s(기대 0) · 직업 %s → %s · 검증이 남긴 몬스터 %d · 땅의 드랍 %d(기대 0 · 0)"):format(
		tostring(PartyState.getParty(player)), tostring(PartyState.getParty(B)), tostring(PartyState.getParty(C)), tostring(PartyState.getParty(D)),
		tostring(player:GetAttribute("PartyExpBonus")), tostring(savedClassId), tostring(PlayerProfile.getClassId(player)), leftoverMonsters, leftoverGround),
		PartyState.getParty(player) == nil and PartyState.getParty(B) == nil and PartyState.getParty(C) == nil and PartyState.getParty(D) == nil
			and player:GetAttribute("PartyExpBonus") == 0 and PlayerProfile.getClassId(player) == savedClassId and leftoverMonsters == 0 and leftoverGround == 0)

	local pass, total = r.summary()
	print(("===S09 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return PartyExpVerify
