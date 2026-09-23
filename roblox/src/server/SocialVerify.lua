-- S12b 자동 검증 - 이름 표시 형식 · 장비 조회(PlayerInspect) · 환생 접근(RebirthAccess) · 알림 옵션 스냅샷 · 제단 물체.
--   (가) 순수 함수 · 합성 데이터 - 서버 시작 때(플레이어 없이): 표시 형식 · 툴팁 글 · 조회 화이트리스트 · 속도 제한 · 환생 접근 판정표 · 데이터 정합.
--   (나) 실제 Player - 보스 검증 체인의 끝에서: 실제 조회 · 반경 안 / 밖 환생 · 조건 충족 환생 · 보스전 중 · 강화 중 · 제단 물체 · 기본 이름표 끔. 검증이 바꾼 것(프로필 · 위치 · 보스)은 끝날 때 되돌린다.
-- 클라 쪽(이름 클릭 메뉴 · 알림 툴팁 · 타이머 정지 · P 키 · 겹침 · 글씨 표)은 client/SocialSelfCheck.client.lua가 클라 콘솔에 [S12b][UI]로 찍는다.
-- env = { ensureBackup, restore } - DevTools의 로컬 헬퍼.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local BossData = require(ReplicatedStorage.Shared.data.BossData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local ItemDescribe = require(ReplicatedStorage.Shared.ItemDescribe)
local PlayerLabelFormat = require(ReplicatedStorage.Shared.PlayerLabelFormat)
local BossEncounter = require(script.Parent.BossEncounter)
local EnhanceService = require(script.Parent.EnhanceService)
local MonsterState = require(script.Parent.MonsterState)
local PlayerInspect = require(script.Parent.PlayerInspect)
local PlayerProfile = require(script.Parent.PlayerProfile)
local RebirthAccess = require(script.Parent.RebirthAccess)

local SocialVerify = {}

local BOSS_STAGE = BossData.stageInterval * 20

local function newRecorder()
	local passCount, totalCount = 0, 0
	local recorder = {}
	function recorder.check(tag, label, ok)
		totalCount += 1
		if ok then
			passCount += 1
		end
		print(("[S12b][%s] %s %s"):format(tag, label, ok and "O" or "X"))
	end
	function recorder.section(tag, label, fn)
		local ok, err = pcall(fn)
		if not ok then
			recorder.check(tag, ("%s 실행 중 에러: %s"):format(label, tostring(err)), false)
		end
	end
	function recorder.summary()
		return passCount, totalCount
	end
	return recorder
end

-- 표의 키가 전부 허용 목록 안에 있는가(허용 밖 키 목록을 돌려준다).
local function extraKeys(tableValue, allowedList)
	local allowed = {}
	for _, key in ipairs(allowedList) do
		allowed[key] = true
	end
	local extra = {}
	for key in pairs(tableValue) do
		if not allowed[key] then
			table.insert(extra, tostring(key))
		end
	end
	table.sort(extra)
	return extra
end

-- 스냅샷 전체를 화이트리스트로 훑어 허용 밖 키를 "경로:키"로 모은다.
local function forbiddenPaths(snapshot)
	local keys = PlayerInspect.publicKeys
	local found = {}
	local function walk(label, tableValue, allowed)
		for _, key in ipairs(extraKeys(tableValue, allowed)) do
			table.insert(found, label .. ":" .. key)
		end
	end
	local function walkItem(label, item)
		if type(item) ~= "table" then
			return
		end
		walk(label, item, keys.item)
		if item.option then
			walk(label .. ".option", item.option, keys.option)
		end
	end
	walk("root", snapshot, keys.root)
	walk("weapon", snapshot.weapon, keys.weapon)
	for slot, gem in pairs(snapshot.weapon.gems) do
		walkItem("gem" .. tostring(slot), gem)
	end
	for part, item in pairs(snapshot.equipment) do
		walkItem(part, item)
	end
	return found
end

-- 독을 탄 합성 classState: 공개 밖 필드(locked · dropStage · secret · 진행도 · 재료)가 곳곳에 있다.
local function poisonedClassState()
	return {
		characterExp = CharacterLevel.getExpForLevel(35),
		rebirthCount = 2,
		gold = 999999,
		materials = { enhanceStone = 5 },
		stageProgress = { infinite = 50, infiniteBest = 60 },
		weapon = {
			grade = 2,
			level = 12,
			enhanceGauge = 33,
			secret = "w",
			slotUnlocked = { true, true, false, false, false },
			gems = {
				{ grade = "primordial", itemLevel = 25, option = { id = "attackPercent", roll = 1.05, roll2 = nil, secret = "g" }, locked = true },
				false,
				false,
				false,
				false,
			},
		},
		equipment = {
			armor = { grade = "relic", part = "armor", itemLevel = 52, dropStage = 40, locked = true, secret = "a", option = { id = "crit", roll = 1.1, roll2 = 0.9, x = 1 } },
			gloves = { grade = "ancient", part = "gloves", itemLevel = 61, dropStage = 55, tierIndex = 4 },
		},
	}
end

-- ─────────────────────────── (가) 순수 함수 ───────────────────────────

function SocialVerify.runPure()
	print("===S12b 검증 시작(가)===")
	local r = newRecorder()

	r.section("가", "표시 형식", function()
		local a = PlayerLabelFormat.plain("철수", 35, 2)
		local b = PlayerLabelFormat.plain("철수", 35, 0)
		local c = PlayerLabelFormat.plain("철수", 35, nil)
		local d = PlayerLabelFormat.plain("철수", nil, nil)
		r.check("가", ("표시 형식: 환생 2 → [%s](기대 ★2 Lv.35 철수) · 환생 0 → [%s](기대 Lv.35 철수) · nil → [%s](기대 Lv.35 철수) · 레벨 없음 → [%s](기대 철수)"):format(a, b, c, d),
			a == "★2 Lv.35 철수" and b == "Lv.35 철수" and c == "Lv.35 철수" and d == "철수")

		local steps = SocialData.label.sizeSteps
		local sizes = { [20] = 16, [16] = 14, [14] = 12, [12] = 12, [18] = 16, [11] = 12 }
		local ok, detail = true, {}
		for size, expected in pairs(sizes) do
			local got = PlayerLabelFormat.levelSize(size)
			ok = ok and got == expected
			table.insert(detail, ("%d→%d"):format(size, got))
		end
		table.sort(detail)
		r.check("가", ("한 단계 작은 글씨: [%s](기대 11→12 · 12→12 · 14→12 · 16→14 · 18→16 · 20→16) · 단 최솟값 %d(기대 12 - 12 미만 없음)"):format(table.concat(detail, " "), steps[#steps]), ok and steps[#steps] == 12)

		local parts = PlayerLabelFormat.parts("철수", 35, 2, 16)
		local rich = PlayerLabelFormat.richText("철수", 35, 2, 16)
		r.check("가", ("조각 %d개(기대 3 - ★ · Lv · 이름) · ★·Lv 크기 %s/%s(기대 14) · 이름 크기 %s(기대 nil) · Lv 색 %s · 이름 표시 %s"):format(
			#parts, tostring(parts[1].size), tostring(parts[2].size), tostring(parts[3].size), tostring(parts[2].colorName), tostring(parts[3].isName)),
			#parts == 3 and parts[1].size == 14 and parts[2].size == 14 and parts[3].size == nil and parts[2].colorName == SocialData.label.levelColorName and parts[3].isName == true
				and rich:find('<font size="14"', 1, true) ~= nil)
		local escaped = PlayerLabelFormat.richText("<b>&x", 1, 0, 14)
		r.check("가", ("이름의 태그 글자는 이스케이프: [%s](기대 &lt;b&gt;&amp;x 포함)"):format(escaped), escaped:find("&lt;b&gt;&amp;x", 1, true) ~= nil)
	end)

	r.section("가", "툴팁 글", function()
		local classId = ClassData.order[1]
		local item = { grade = "relic", part = "gloves", itemLevel = 52, option = { id = "attackPercent", roll = 1.0 } }
		local desc = ItemDescribe.item(item, classId)
		r.check("가", ("장비 툴팁: 제목 [%s](기대 유물 장갑) · 메타 [%s](기대 장갑 · Lv.52 · 공격력 포함) · 옵션 %d줄(기대 1) [%s]"):format(
			desc.title, desc.meta, #desc.options, desc.options[1] and desc.options[1].text or ""),
			desc.title == "유물 장갑" and desc.meta:find("Lv.52", 1, true) ~= nil and desc.meta:find("공격력", 1, true) ~= nil and #desc.options == 1
				and desc.options[1].text:find("위력", 1, true) ~= nil)
		local crit = ItemDescribe.item({ grade = "ancient", part = "armor", itemLevel = 70, option = { id = "crit", roll = 1.0, roll2 = 1.0 } }, classId)
		r.check("가", ("치명 옵션은 2줄(치확 · 치피): %d줄 [%s | %s]"):format(#crit.options, crit.options[1] and crit.options[1].text or "", crit.options[2] and crit.options[2].text or ""),
			#crit.options == 2 and crit.options[1].text:find("치확", 1, true) ~= nil and crit.options[2].text:find("치피", 1, true) ~= nil)
		local none = ItemDescribe.item({ grade = "relic", part = "shoes", itemLevel = 40 }, classId)
		local gem = ItemDescribe.gem({ grade = "epic", itemLevel = 25, option = { id = "attackPercent", roll = 1.0 } }, classId)
		local weapon = ItemDescribe.weapon("legendary", 7)
		r.check("가", ("옵션 없음 %d줄(기대 0) · 보석 제목 [%s](기대 ○○ 위력 보석 · Lv.25) · 무기 [%s | %s](기대 ○○ 기본 무기 | 무기 · +7)"):format(#none.options, gem.title, weapon.title, weapon.meta),
			#none.options == 0 and gem.title:find("위력 보석 · Lv.25", 1, true) ~= nil and weapon.meta == "무기 · +7" and weapon.title:find("기본 무기", 1, true) ~= nil)
	end)

	r.section("가", "장비 조회 공개 필드", function()
		local state = poisonedClassState()
		local snapshot = PlayerInspect.buildSnapshot({ userId = 12345, name = "user_a", displayName = "표시", classId = ClassData.order[1], classState = state })
		local forbidden = forbiddenPaths(snapshot)
		r.check("가", ("공개 필드만: 허용 밖 키 %d개(기대 0) [%s]"):format(#forbidden, table.concat(forbidden, ",")), #forbidden == 0)
		r.check("가", ("값: 레벨 %s(기대 35) · 환생 %s(기대 2) · 무기 %s +%s(기대 등급 있음 · +12) · 보석 칸 %d(기대 5 · 빈 칸 false) · 갑옷 옵션 roll2 %s(기대 0.9) · 장갑 옵션 %s(기대 nil) · 신발 %s(기대 nil)"):format(
			tostring(snapshot.level), tostring(snapshot.rebirthCount), tostring(snapshot.weapon.gradeId), tostring(snapshot.weapon.level), #snapshot.weapon.gems,
			tostring(snapshot.equipment.armor and snapshot.equipment.armor.option.roll2), tostring(snapshot.equipment.gloves and snapshot.equipment.gloves.option), tostring(snapshot.equipment.shoes)),
			snapshot.level == 35 and snapshot.rebirthCount == 2 and snapshot.weapon.gradeId ~= nil and snapshot.weapon.level == 12 and #snapshot.weapon.gems == 5
				and snapshot.weapon.gems[2] == false and snapshot.equipment.armor.option.roll2 == 0.9 and snapshot.equipment.gloves.option == nil and snapshot.equipment.shoes == nil)
		-- 원본과 분리(스냅샷은 값 복사): 원본 옵션을 바꿔도 이미 만든 스냅샷은 그대로
		state.equipment.armor.option.roll = 0.1
		r.check("가", ("스냅샷은 원본과 분리: 원본 roll을 1.1 → 0.1로 바꿔도 스냅샷 roll %s(기대 1.1)"):format(tostring(snapshot.equipment.armor.option.roll)), snapshot.equipment.armor.option.roll == 1.1)
	end)

	r.section("가", "장비 조회 거절 · 속도 제한", function()
		local requester = {}
		local interval = SocialData.inspect.minIntervalSeconds
		local first = PlayerInspect.handle(requester, 987654321, 100)
		local second = PlayerInspect.handle(requester, 987654321, 100 + interval * 0.4)
		local third = PlayerInspect.handle(requester, 987654321, 100 + interval * 0.4 + interval * 1.01)
		r.check("가", ("없는 id → [%s](기대 not_in_server) · %.2f초 뒤 재요청 → [%s](기대 rate_limited) · 간격(%.1f초) 지난 뒤 → [%s](기대 not_in_server)"):format(
			tostring(first.reason), interval * 0.4, tostring(second.reason), interval, tostring(third.reason)),
			first.ok == false and first.reason == "not_in_server" and second.reason == "rate_limited" and third.reason == "not_in_server")
		local bad = {}
		local reasons, t = {}, 200
		for _, value in ipairs({ "abc", 1.5, 0 / 0, -8888888, 0 }) do
			t += interval * 2
			local result = PlayerInspect.handle(bad, value, t)
			table.insert(reasons, tostring(result.reason))
		end
		t += interval * 2
		local nilResult = PlayerInspect.handle(bad, nil, t)
		r.check("가", ("잘못된 요청: 문자열 · 1.5 · NaN · -8888888 · 0 → [%s](기대 bad_request · bad_request · bad_request · not_in_server · not_in_server) · nil → [%s](기대 bad_request)"):format(table.concat(reasons, " · "), tostring(nilResult.reason)),
			table.concat(reasons, ",") == "bad_request,bad_request,bad_request,not_in_server,not_in_server" and nilResult.reason == "bad_request")
		local burst = {}
		local burstHits = 0
		for index = 1, 20 do
			if PlayerInspect.handle(burst, 1, 500 + index * 0.01).reason == "rate_limited" then
				burstHits += 1
			end
		end
		r.check("가", ("0.2초 안에 20번 연속 요청 → 거절 %d번(기대 19)"):format(burstHits), burstHits == 19)
		-- 스탠드인(더미 · 다른 서버)은 Players에 없다 → 거절
		local standIn = { Name = "Stand", UserId = -7777, Parent = Workspace }
		local dummy = PlayerInspect.handle({}, standIn.UserId, 900)
		r.check("가", ("스탠드인 userId → [%s](기대 not_in_server)"):format(tostring(dummy.reason)), dummy.ok == false and dummy.reason == "not_in_server")
	end)

	r.section("가", "환생 접근 판정표", function()
		local altar = RebirthAccess.altarPosition()
		local station = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
		local altarRange, stationRange = WorldConfig.rebirthAltar.interactionRangeStuds, WorldConfig.enhance.interactionRangeStuds
		local function outcome(state)
			local ok, why = RebirthAccess.evaluate(state)
			return ok and ("ok:" .. why) or why
		end
		local cases = {
			{ "제단 앞(3 stud)", { position = altar + Vector3.new(3, 0, 0) }, "ok:altar" },
			{ "제단 반경 안 끝", { position = altar + Vector3.new(altarRange - 0.1, 0, 0) }, "ok:altar" },
			{ "제단 반경 밖 끝", { position = altar + Vector3.new(altarRange + 0.1, 0, 0) }, "out_of_range" },
			{ "제단에서 100 stud", { position = altar + Vector3.new(100, 0, 0) }, "out_of_range" },
			{ "강화대 앞(기존 경로)", { position = station + Vector3.new(2, 0, 0) }, "ok:station" },
			{ "강화대 반경 밖 끝", { position = station + Vector3.new(stationRange + 0.1, 0, 0) }, "out_of_range" },
			{ "원점(어느 쪽도 아님)", { position = Vector3.new(0, 0, 0) }, "out_of_range" },
			{ "캐릭터 없음", { position = nil }, "no_character" },
			{ "제단 앞 + 보스전 중", { position = altar, inBossFight = true }, "boss_fight" },
			{ "강화대 앞 + 보스전 중", { position = station, inBossFight = true }, "boss_fight" },
			{ "제단 앞 + 강화 중", { position = altar, enhancing = true }, "enhancing" },
			{ "반경 밖 + 보스전 중(위치가 먼저)", { position = Vector3.new(0, 0, 0), inBossFight = true }, "out_of_range" },
		}
		local allOk, lines = true, {}
		for _, case in ipairs(cases) do
			local got = outcome(case[2])
			allOk = allOk and got == case[3]
			table.insert(lines, ("%s → %s%s"):format(case[1], got, got == case[3] and "" or ("(기대 " .. case[3] .. ")")))
		end
		r.check("가", ("환생 접근 판정표 %d건: %s"):format(#cases, table.concat(lines, " · ")), allOk)
	end)

	r.section("가", "데이터 정합", function()
		local altar = WorldConfig.rebirthAltar
		local building = 20 -- 커뮤니티 센터 블록 반폭(HuntingGround: 40 × 40 발자국)
		r.check("가", ("제단 값: 프롬프트 거리 %s < 서버 반경 %s · 센터 블록 밖(오프셋 |z| %s > %d + 2) · 반경 > 0"):format(
			tostring(altar.promptDistanceStuds), tostring(altar.interactionRangeStuds), tostring(math.abs(altar.offsetFromCommunity.Z)), building),
			altar.promptDistanceStuds < altar.interactionRangeStuds and math.abs(altar.offsetFromCommunity.Z) > building + 2 and altar.interactionRangeStuds > 0)
		local nameplate = SocialData.nameplate
		local minSize = SocialData.label.sizeSteps[#SocialData.label.sizeSteps]
		r.check("가", ("이름표 값: 글씨 %s(기대 12 이상 · 4단 중 하나) · 거리 %s · 조회 간격 %s초(기대 0.5)"):format(tostring(nameplate.textSize), tostring(nameplate.maxDistanceStuds), tostring(SocialData.inspect.minIntervalSeconds)),
			nameplate.textSize >= minSize and table.find(SocialData.label.sizeSteps, nameplate.textSize) ~= nil and nameplate.maxDistanceStuds > 0 and SocialData.inspect.minIntervalSeconds == 0.5)
	end)

	local pass, total = r.summary()
	print(("===S12b 검증 끝(가)=== %d/%d 통과"):format(pass, total))
end

-- ─────────────────────────── (나) 실제 Player ───────────────────────────

local function rootOf(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function moveTo(player, position)
	local root = rootOf(player)
	if root then
		root.Anchored = true
		root.CFrame = CFrame.new(position)
		task.wait(0.2)
	end
end

function SocialVerify.runLive(player, env)
	print("===S12b 검증 시작(나)===")
	local r = newRecorder()
	local root = rootOf(player)
	if not PlayerProfile.getProfile(player) or not root then
		r.check("나", "프로필 또는 캐릭터가 없어 검증을 건너뜀", false)
		local pass, total = r.summary()
		print(("===S12b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
		return
	end

	env.ensureBackup(player)
	local savedCFrame, savedAnchored = root.CFrame, root.Anchored
	local monstersBefore = {}
	for _, model in ipairs(MonsterState.getAllModels()) do
		monstersBefore[model] = true
	end
	if not PlayerProfile.getClassId(player) then
		PlayerProfile.setClassId(player, ClassData.order[1])
	end
	BossEncounter.despawnFor(player)
	local altar = RebirthAccess.altarPosition()
	local station = WorldConfig.huntingGround.center + WorldConfig.enhance.stationOffset
	local standHeight = Vector3.new(0, 4, 0) -- 캐릭터 루트 높이(지면 위)

	-- [1] 제단 물체: 월드에 있고 프롬프트가 서버 반경 안이다. 위치는 서버 판정 좌표와 같다.
	r.section("나", "[1] 제단 물체", function()
		local model = Workspace:FindFirstChild("RebirthAltar")
		local orb = model and model:FindFirstChild("Orb")
		local prompt = orb and orb:FindFirstChildOfClass("ProximityPrompt")
		local base = model and model:FindFirstChild("Base")
		local drift = base and (Vector3.new(base.Position.X, 0, base.Position.Z) - Vector3.new(altar.X, 0, altar.Z)).Magnitude or math.huge
		local center = Workspace:FindFirstChild("CommunityCenter")
		local inside = center and (math.abs(base.Position.X - center.Position.X) <= center.Size.X / 2 and math.abs(base.Position.Z - center.Position.Z) <= center.Size.Z / 2) or false
		r.check("나", ("제단 물체: 모델 %s · 프롬프트 %s(이름 %s · 거리 %s ≤ 반경 %s · 키 %s · 대기 %s) · 서버 판정 좌표와의 XZ 차이 %.3f(기대 ≈ 0) · 센터 블록 안에 겹침 %s(기대 false)"):format(
			tostring(model ~= nil), tostring(prompt ~= nil), prompt and prompt.Name or "-", prompt and tostring(prompt.MaxActivationDistance) or "-",
			tostring(WorldConfig.rebirthAltar.interactionRangeStuds), prompt and tostring(prompt.KeyboardKeyCode) or "-", prompt and tostring(prompt.HoldDuration) or "-", drift, tostring(inside)),
			model ~= nil and prompt ~= nil and prompt.Name == "RebirthAltarPrompt" and prompt.MaxActivationDistance <= WorldConfig.rebirthAltar.interactionRangeStuds
				and prompt.KeyboardKeyCode == Enum.KeyCode.E and prompt.HoldDuration == 0 and drift < 0.01 and not inside)
	end)

	-- [2] 환생 요청 - 반경 밖 거절 / 반경 안 허용(조건 충족) / 조건 미달 / 기존 경로(강화대) 유지.
	r.section("나", "[2] 환생 요청", function()
		local classState = PlayerProfile.getProfile(player).classes[PlayerProfile.getClassId(player)]
		PlayerProfile.setRebirthCountDirect(player, 0)
		-- P2.5a: 필요 레벨은 표(CharacterLevel.getRebirthRequiredLevel)에서 읽는다 - 옛 25 · 50 → 78 · 155.
		local firstLevel, secondLevel = CharacterLevel.getRebirthRequiredLevel(0), CharacterLevel.getRebirthRequiredLevel(1)
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(firstLevel)) -- 1회차 필요 레벨
		local before = classState.rebirthCount

		local farPosition = altar + Vector3.new(40, 0, 0) + standHeight
		moveTo(player, farPosition)
		local farPayload = RebirthAccess.attempt(player, rootOf(player).Position)
		r.check("나", ("반경 밖(제단에서 %.0f stud): 요청 결과 %s(기대 nil - 조용히 거절) · 환생 횟수 %d → %d(기대 0 → 0)"):format(
			(rootOf(player).Position - altar).Magnitude, tostring(farPayload), before, classState.rebirthCount), farPayload == nil and classState.rebirthCount == before)

		moveTo(player, altar + Vector3.new(4, 0, 0) + standHeight)
		local nearPayload = RebirthAccess.attempt(player, rootOf(player).Position)
		r.check("나", ("반경 안(제단 앞 4 stud) + 레벨 %d: 결과 success=%s 회차 %s(기대 true · 1) · 저장 환생 횟수 %d(기대 1) · Attribute RebirthCount %s(기대 1) · 레벨 %s(기대 1)"):format(
			firstLevel, tostring(nearPayload and nearPayload.success), tostring(nearPayload and nearPayload.rebirthCount), classState.rebirthCount, tostring(player:GetAttribute("RebirthCount")), tostring(player:GetAttribute("CharacterLevel"))),
			nearPayload ~= nil and nearPayload.success == true and nearPayload.rebirthCount == 1 and classState.rebirthCount == 1 and player:GetAttribute("RebirthCount") == 1 and player:GetAttribute("CharacterLevel") == 1)

		local lowPayload = RebirthAccess.attempt(player, rootOf(player).Position)
		r.check("나", ("반경 안 + 조건 미달(레벨 1 · 2회차 필요 %d): 결과 reason=%s 필요 %s(기대 level_too_low · %d) · 회차 %d(기대 1 그대로)"):format(
			secondLevel, tostring(lowPayload and lowPayload.reason), tostring(lowPayload and lowPayload.requiredLevel), secondLevel, classState.rebirthCount),
			lowPayload ~= nil and lowPayload.success == false and lowPayload.reason == "level_too_low" and lowPayload.requiredLevel == secondLevel and classState.rebirthCount == 1)

		-- 기존 경로: 강화대 앞에서도 같은 조건으로 허용된다.
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(secondLevel))
		moveTo(player, station + Vector3.new(3, 0, 0) + standHeight)
		local stationPayload = RebirthAccess.attempt(player, rootOf(player).Position)
		r.check("나", ("기존 경로(강화대 앞) + 레벨 %d: success=%s 회차 %s(기대 true · 2) · 같은 위치에서 환생 조건은 제단과 같은 함수(PlayerProfile.rebirth)"):format(
			secondLevel, tostring(stationPayload and stationPayload.success), tostring(stationPayload and stationPayload.rebirthCount)),
			stationPayload ~= nil and stationPayload.success == true and stationPayload.rebirthCount == 2)
	end)

	-- [3] 강화 중 · 보스전 중 거절.
	r.section("나", "[3] 강화 중 · 보스전 중", function()
		local classState = PlayerProfile.getProfile(player).classes[PlayerProfile.getClassId(player)]
		PlayerProfile.setRebirthCountDirect(player, 0)
		PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(25))
		moveTo(player, altar + Vector3.new(4, 0, 0) + standHeight)

		EnhanceService.handleRequest(player) -- 제단 앞이라 강화대 밖 - 조용히 무시되지만 요청 시각은 기록된다(isBusy의 기준)
		local busyAt = os.clock()
		local busyPayload = RebirthAccess.attempt(player, rootOf(player).Position)
		r.check("나", ("강화 요청 직후(%.2f초): 결과 reason=%s(기대 enhancing) · 회차 %d(기대 0 그대로)"):format(os.clock() - busyAt, tostring(busyPayload and busyPayload.reason), classState.rebirthCount),
			busyPayload ~= nil and busyPayload.success == false and busyPayload.reason == "enhancing" and classState.rebirthCount == 0)
		task.wait(EnhanceService.requestCooldownSeconds + 0.2)
		local idleAllowed = RebirthAccess.check(player, rootOf(player).Position)
		r.check("나", ("쿨다운(%.1f초) 지난 뒤: 접근 허용 %s(기대 true)"):format(EnhanceService.requestCooldownSeconds, tostring(idleAllowed)), idleAllowed == true)

		BossEncounter.spawnFor(player, BOSS_STAGE)
		local encounter = BossEncounter.getEncounter(player)
		-- 보스전 중 플레이어는 아레나로 옮겨져 있다 - 요청 위치를 제단으로 넘겨도(=클라가 어디서 눌렀든) 서버는 보스전 상태로 거절한다.
		local bossPayload = RebirthAccess.attempt(player, altar + Vector3.new(4, 0, 0) + standHeight)
		r.check("나", ("보스전 중(encounter %s): 결과 reason=%s(기대 boss_fight) · 회차 %d(기대 0 그대로)"):format(tostring(encounter ~= nil), tostring(bossPayload and bossPayload.reason), classState.rebirthCount),
			encounter ~= nil and bossPayload ~= nil and bossPayload.success == false and bossPayload.reason == "boss_fight" and classState.rebirthCount == 0)
		BossEncounter.despawnFor(player)
		task.wait(0.3)
		moveTo(player, altar + Vector3.new(4, 0, 0) + standHeight)
		local afterBoss = RebirthAccess.check(player, rootOf(player).Position)
		r.check("나", ("보스전 종료 뒤: 접근 허용 %s(기대 true)"):format(tostring(afterBoss)), afterBoss == true)
	end)

	-- [4] 장비 조회 - 실제 Player: 자기 자신 조회 · 공개 필드 · 속도 제한.
	r.section("나", "[4] 실제 장비 조회", function()
		PlayerProfile.setEquippedDirect(player, "armor", { grade = "relic", part = "armor", itemLevel = 52, dropStage = 40, locked = true, secret = "x", option = { id = "attackPercent", roll = 1.0, hidden = 1 } })
		local weapon = PlayerProfile.getWeapon(player)
		local savedLevel = weapon.level
		weapon.level = 9
		-- 요청자는 스탠드인 표를 쓴다(속도 제한 기록이 실제 플레이어의 클라 요청과 섞이지 않게).
		local requester = {}
		local now = os.clock() + 1000
		local result = PlayerInspect.handle(requester, player.UserId, now)
		local forbidden = result.ok and forbiddenPaths(result.data) or { "(조회 실패:" .. tostring(result.reason) .. ")" }
		r.check("나", ("자기 조회: ok=%s · 표시이름 [%s](기대 %s) · @이름 [%s](기대 %s) · 무기 +%s(기대 9) · 갑옷 %s(기대 relic) · 허용 밖 키 %d개(기대 0) [%s]"):format(
			tostring(result.ok), result.ok and result.data.displayName or "-", player.DisplayName, result.ok and result.data.name or "-", player.Name,
			result.ok and tostring(result.data.weapon.level) or "-", result.ok and tostring(result.data.equipment.armor and result.data.equipment.armor.grade) or "-", #forbidden, table.concat(forbidden, ",")),
			result.ok == true and result.data.displayName == player.DisplayName and result.data.name == player.Name and result.data.weapon.level == 9
				and result.data.equipment.armor.grade == "relic" and #forbidden == 0)
		local again = PlayerInspect.handle(requester, player.UserId, now + 0.1)
		local later = PlayerInspect.handle(requester, player.UserId, now + 0.1 + SocialData.inspect.minIntervalSeconds + 0.01)
		r.check("나", ("바로 다시 조회 → [%s](기대 rate_limited) · 간격 뒤 → ok=%s(기대 true)"):format(tostring(again.reason), tostring(later.ok)), again.reason == "rate_limited" and later.ok == true)
		weapon.level = savedLevel
		local model = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		r.check("나", ("기본 이름표 끔: Humanoid.DisplayDistanceType = %s(기대 None)"):format(model and tostring(model.DisplayDistanceType) or "-"),
			model ~= nil and model.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None)
	end)

	-- [5] 되돌리기: 프로필 · 위치 · 보스.
	BossEncounter.despawnFor(player)
	env.restore(player)
	local currentRoot = rootOf(player)
	if currentRoot then
		currentRoot.CFrame = savedCFrame
		currentRoot.Anchored = savedAnchored
	end
	local orphans, leftover = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and data.isBoss and not BossEncounter.getEncounterByModel(model) then
			orphans += 1
		end
		if not monstersBefore[model] then
			leftover += 1
		end
	end
	r.check("나", ("검증 뒤 되돌림: encounter 없는 보스 모델 %d · 남은 몬스터 %d(기대 0 · 0) · 환생 횟수 %s"):format(orphans, leftover, tostring(PlayerProfile.getRebirthCount(player))), orphans == 0 and leftover == 0)

	local pass, total = r.summary()
	print(("===S12b 검증 끝(나)=== %d/%d 통과"):format(pass, total))
end

return SocialVerify
