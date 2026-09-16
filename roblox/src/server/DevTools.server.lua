-- 밸런스 테스트 도구(19-3a). 채팅 명령 "/gg ..."로 현재 프로필을 원하는 조건(레벨·장비·
-- 강화·직업·무한 스테이지)으로 즉시 세팅하고, 그 조건에서 생존 타수·60초 평타 총딜을
-- BalanceSim으로 계산해 서버 콘솔에 출력한다. 실제 클릭 왕복으로 처치 시간을 재는 대신
-- 수식 시뮬레이터(BalanceSim)를 쓰는 이유는 그쪽 모듈 주석 참고.
--
-- 안전장치(지시 그대로, 반드시 지킨다):
--   1) RunService:IsStudio()가 아니면 이 스크립트는 완전히 죽는다 - 라이브 서버에서는
--      DevToolsConfig.allowedUserIds에 뭐가 들었든 명령 자체가 등록되지 않는다.
--   2) allowedUserIds가 비어 있지 않으면 그 목록의 UserId만 명령을 쓸 수 있다(Team Create
--      다중 접속 대비 2차 방어) - 비어 있으면 "Studio 안의 아무나"를 허용한다.
--   3) 세팅은 세션 메모리(PlayerProfile)만 바꾼다. 첫 명령 실행 시 원본 상태를 자동
--      백업하고(snapshotForDevTools), 그 플레이어의 저장을 SaveCoordinator에서 차단한다 -
--      자동저장(60초)이나 퇴장저장이 가짜 조건을 DataStore에 남기지 못한다. "/gg reset"이나
--      퇴장 시 원본으로 복원 + 저장 차단 해제.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local ItemVisualData = require(ReplicatedStorage.Shared.data.ItemVisualData)
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
local BalanceAnchorConfig = require(ReplicatedStorage.Shared.data.BalanceAnchorConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local CharacterLevelConfig = require(ReplicatedStorage.Shared.data.CharacterLevelConfig)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local PlayerProfile = require(script.Parent.PlayerProfile)
-- 26-3 자동 검증 블록이 인벤토리·보석 상태를 직접 되돌린 뒤 클라이언트에 다시 밀 때 씀.
local InventorySync = require(script.Parent.InventorySync)
local GemSync = require(script.Parent.GemSync)
local SaveCoordinator = require(script.Parent.SaveCoordinator)
-- 21-3 보스 검증 명령(/gg boss, /gg pattern)용.
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local BossRules = require(ReplicatedStorage.Shared.BossRules)
local BossEncounter = require(script.Parent.BossEncounter)
local BossPatterns = require(script.Parent.BossPatterns)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local CombatResolution = require(script.Parent.CombatResolution)
-- 22-2 변종 검증 명령(/gg variant, /gg chesttest)용.
local MonsterPrefixData = require(ReplicatedStorage.Shared.data.MonsterPrefixData)
-- 22-4 Y축 지형 검증 명령(/gg terrain)용.
local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local TerrainConfig = require(ReplicatedStorage.Shared.data.TerrainConfig)
local ZoneTerrainData = require(ReplicatedStorage.Shared.data.ZoneTerrainData)
local ZoneTerrain = require(script.Parent.ZoneTerrain)
local GroundProbe = require(script.Parent.GroundProbe)
local ItemDropSpawner = require(script.Parent.ItemDropSpawner)
local ServerStorage = game:GetService("ServerStorage")
-- 23-1 견습 모드 검증 명령(/gg tutorial)용.
local TutorialState = require(script.Parent.TutorialState)
local TutorialData = require(ReplicatedStorage.Shared.data.TutorialData)
-- 23-2 환생·보석 검증 명령(/gg rebirth, /gg rebirthdo, /gg gem)용.
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
-- 26-1 옵션 통합 순수 함수 검증 명령(/gg option table)용.
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local Option = require(ReplicatedStorage.Shared.Option)
-- 26-2 자동 검증 블록(아래 "===26-2 검증 시작===")용.
local SkillData = require(ReplicatedStorage.Shared.data.SkillData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local PlayerState = require(script.Parent.PlayerState)
-- 24-1 파티 검증 명령(/gg party dummy|info|table|killsim)용.
local PartyState = require(script.Parent.PartyState)
local PartyConfig = require(ReplicatedStorage.Shared.data.PartyConfig)
local BuffState = require(script.Parent.BuffState)
-- 24-2 크로스서버 파티 검증 명령(/gg party server|join|fakeremote|xtest)용.
local PartyCrossServer = require(script.Parent.PartyCrossServer)
local InfiniteStageConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)
-- 25-1 레벨 곡선 검증 명령(/gg curve, /gg curve migrate)용.
local SaveSystem = require(script.Parent.SaveSystem)
local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)

-- 앵커 조건(지시 [1] - "최소한 앵커 조건은 하나로 불러올 수 있어야 한다"): 레벨100 +
-- 일반등급 itemLevel100 3부위 + 강화+0 + 무기등급 일반(0), 스테이지 100. 무기 등급은
-- 20-1 [3](가) 측정("등급 0~6 × 4직업 처치 시간")의 고정 기준점이라 앵커 자체는 항상
-- 일반(0)에서 시작한다 - 등급은 별도로 "/gg weapon <n>"으로 바꿔가며 잰다.
local ANCHOR = {
	level = 100,
	gearGrade = "normal",
	gearItemLevel = 100,
	weaponLevel = 0,
	weaponGrade = 0,
	stage = 100,
}

local function isAllowed(player)
	if #DevToolsConfig.allowedUserIds == 0 then
		return true
	end
	for _, userId in ipairs(DevToolsConfig.allowedUserIds) do
		if userId == player.UserId then
			return true
		end
	end
	return false
end

local backups = {} -- [Player] = { classId = 백업 시점 classId, snapshot = PlayerProfile.snapshotForDevTools 결과 }

-- 이 세션에서 처음 개입하는 순간에만 백업한다 - 두 번째 "/gg anchor"가 방금 세팅한 가짜
-- 값을 "원본"으로 덮어써버리면 되돌릴 방법이 없어진다.
local function ensureBackup(player)
	if backups[player] then
		return
	end
	backups[player] = {
		classId = PlayerProfile.getClassId(player),
		snapshot = PlayerProfile.snapshotForDevTools(player),
	}
	SaveCoordinator.setDevToolsSuspended(player, true)
	print(("[DevTools] %s 원본 프로필 백업 완료 - 저장이 차단됩니다(/gg reset으로 복원)"):format(player.Name))
end

local function restore(player)
	local backup = backups[player]
	if not backup then
		print(("[DevTools] %s - 백업이 없습니다(아직 아무 명령도 쓰지 않았습니다)"):format(player.Name))
		return
	end
	PlayerProfile.restoreForDevTools(player, backup.snapshot)
	SaveCoordinator.setDevToolsSuspended(player, false)
	backups[player] = nil
	print(("[DevTools] %s 원본 프로필로 복원 완료 - 저장 차단 해제"):format(player.Name))
end

local function reply(player, message)
	print(("[DevTools] %s: %s"):format(player.Name, message))
end

-- 26-3 수정: classId를 받아 Option.rollFor로 옵션을 굴린다 - 이 헬퍼가 23-3부터 옵션
-- 없이 아이템을 만들어서, 이 헬퍼로 만든 아이템으로는 26-3 옵션 표시·리롤을 테스트할 수
-- 없었다(실제 드랍(Loot.lua)은 처음부터 옵션을 굴렸다 - 여기만 빠져 있었다).
local function buildGearItem(part, grade, itemLevel, stage, classId)
	return {
		grade = grade,
		part = part,
		dropStage = stage or 1,
		itemLevel = itemLevel,
		tierIndex = 1,
		locked = true,
		option = Option.rollFor(grade, classId),
	}
end

local function isValidGrade(grade)
	return ArmorData.grades[grade] ~= nil and ItemVisualData.gradeVisuals[grade] ~= nil
end

-- 23-3: "/gg additem <grade> [itemLevel]" - 분해·판매 UI 클릭 검증용으로 인벤토리(장착이
-- 아니라)에 잠기지 않은 아이템 하나를 직접 넣는다. buildGearItem은 locked=true라 분해가
-- 막히므로 여기선 false로 만든다 - applyGear(장착)와 다른 목적의 별도 헬퍼.
local function applyAddItem(player, part, grade, itemLevel)
	if not isValidGrade(grade) then
		reply(player, ("알 수 없는 등급: %s (사용 가능: %s)"):format(tostring(grade), table.concat(ArmorData.gradeOrder, "/")))
		return false
	end
	local item = buildGearItem(part, grade, itemLevel, nil, PlayerProfile.getClassId(player))
	item.locked = false
	return PlayerProfile.addArmorDrop(player, item)
end

-- 갑옷·장갑·신발 3부위 전부 같은 등급·itemLevel로 즉시 장착시킨다.
local function applyGear(player, grade, itemLevel)
	if not isValidGrade(grade) then
		reply(player, ("알 수 없는 등급: %s (사용 가능: %s)"):format(tostring(grade), table.concat(ArmorData.gradeOrder, "/")))
		return false
	end
	local classId = PlayerProfile.getClassId(player)
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		PlayerProfile.setEquippedDirect(player, part, buildGearItem(part, grade, itemLevel, nil, classId))
	end
	return true
end

-- 25-1: 곡선은 환생 회차와 무관하게 하나다(CharacterLevel.lua 주석) - 그 레벨의 임계값에 정확히
-- 세운다(레벨 내 진행률 0).
local function applyLevel(player, level)
	PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(level))
end

local function applyEnhance(player, level)
	level = math.clamp(level, 0, EnhanceConfig.maxLevel)
	PlayerProfile.setWeaponLevel(player, level)
end

-- gradeArg: 숫자 인덱스(0~6) 또는 등급명(ArmorData.gradeOrder의 id, 예 "ancient") 둘 다
-- 받는다 - 채팅에서 숫자가 외우기 번거로울 수 있어 이름도 허용한다(gear 명령과 달리
-- weapon은 숫자 축이 기본이라 둘 다 지원).
local function applyWeaponGrade(player, gradeArg)
	local gradeIndex = tonumber(gradeArg)
	if not gradeIndex then
		for i, id in ipairs(ArmorData.gradeOrder) do
			if id == gradeArg then
				gradeIndex = i - 1
				break
			end
		end
	end
	if not gradeIndex or not ArmorData.gradeOrder[gradeIndex + 1] then
		reply(player, ("알 수 없는 무기 등급: %s (0~%d 또는 등급명: %s)"):format(
			tostring(gradeArg), #ArmorData.gradeOrder - 1, table.concat(ArmorData.gradeOrder, "/")))
		return false
	end
	PlayerProfile.setWeaponGrade(player, gradeIndex)
	return true
end

local function applyClass(player, classId)
	if not ClassData.classes[classId] then
		reply(player, ("알 수 없는 직업: %s (사용 가능: %s)"):format(tostring(classId), table.concat(ClassData.order, "/")))
		return false
	end
	PlayerProfile.setClassId(player, classId)
	return true
end

local function applyStage(player, stage)
	PlayerProfile.setInfiniteStageDirect(player, stage)
end

-- "/gg rebirth <0-5>" - rebirthCount만 강제로 바꾼다(20-4 [1]에서 신설된 스텁 용도 그대로
-- 유지 - 보스 첫 처치 드랍표 분기, 보석 슬롯 개방 표시를 무기 등급·레벨과 무관하게 빠르게
-- 확인할 때 쓴다). 실제 환생 전체 흐름(레벨 조건·무기 등급·보석 자동 지급)을 검증하려면
-- "/gg rebirthdo"를 쓴다.
local function applyRebirth(player, count)
	count = math.clamp(count, 0, GemData.maxRebirthCount)
	PlayerProfile.setRebirthCountDirect(player, count)
	return count
end

-- "/gg gem <slot> <id>" - 슬롯(1~5)에 보석을 강제로 채운다(23-2 검증용). id가 "-"면
-- optionId 없이 채운다(영웅~유물처럼 옵션 풀이 없는 등급 검증용), 그 외 문자열이면 그
-- 이름으로 강제 지정한다(고대·태초 옵션 표시 검증용) - Studio MCP execute_luau가
-- PlayerProfile을 직접 require하지 못해(DevTools.server.lua 상단 주석 패턴과 같은 제약)
-- 이미 로드된 이 스크립트를 거쳐야 한다. 23-4: grade 필드가 생겨(등급 상한제) 그 슬롯의
-- 현재 상한으로 채운다 - 실제 장착 검증(등급 상한 이하만 허용)은 PlayerProfile.equipGem이
-- 따로 한다, 이 명령은 그 검증을 우회하는 강제 주입용이다.
local function applyGemSlot(player, slot, id)
	local weapon = PlayerProfile.getWeapon(player)
	if not weapon then
		return false, "no_weapon"
	end
	if slot < 1 or slot > Gem.slotCount then
		return false, "slot_range"
	end
	weapon.gems[slot] = { optionId = (id ~= "-" and id) or nil, grade = Gem.gradeCapForSlot(slot) }
	return true
end

-- "/gg option set <slot 1-5|armor|gloves|shoes> <optionId|-> [grade] [min|mid|max|roll숫자]"
-- (26-2, PRD 20.67 [14] 3~5단계 검증용 - "/gg gem"은 옛 4개 이름만 다룬다, 이 명령이 새
-- 통합 옵션 체계를 강제 배정한다). id="-"면 옵션을 지운다(option=nil, 등급·itemLevel은
-- 유지). grade·roll을 생략하면 기존 값(비어 있으면 태초·기댓값)을 그대로 쓴다 - 등급별
-- min/mid/max 대조표를 뽑을 때 등급만 갈아 끼우거나 롤만 갈아 끼우기 쉽게 하기 위함.
local OPTION_ROLL_KEYWORDS = { min = OptionData.rollMin, mid = 1.0, max = OptionData.rollMax }
local OPTION_SET_EQUIP_PARTS = { armor = true, gloves = true, shoes = true }

local function parseOptionRollArg(arg)
	if arg == nil then
		return 1.0
	end
	if OPTION_ROLL_KEYWORDS[arg] then
		return OPTION_ROLL_KEYWORDS[arg]
	end
	return tonumber(arg)
end

local function applyOptionSet(player, targetArg, optionIdArg, gradeArg, rollArg)
	local weapon = PlayerProfile.getWeapon(player)
	if not weapon then
		return false, "no_weapon"
	end

	local slot = tonumber(targetArg)
	local isGemTarget = slot ~= nil
	if isGemTarget and (slot < 1 or slot > Gem.slotCount) then
		return false, "slot_range"
	end
	if not isGemTarget and not OPTION_SET_EQUIP_PARTS[targetArg] then
		return false, "bad_target"
	end

	local option = nil
	if optionIdArg ~= "-" then
		if not OptionData.options[optionIdArg] then
			return false, "bad_option"
		end
		local roll = parseOptionRollArg(rollArg)
		if not roll then
			return false, "bad_roll"
		end
		option = { id = optionIdArg, roll = roll }
		if OptionData.options[optionIdArg].critRateBase then
			option.roll2 = roll -- 치확·치피 같은 롤로 강제(검증 편의 - 실제 굴림은 독립).
		end
	end

	local current = isGemTarget
		and (Gem.isFilled(weapon.gems, slot) and weapon.gems[slot] or nil)
		or PlayerProfile.getEquipped(player, targetArg)
	local grade = gradeArg or (current and current.grade) or "primordial"
	if not ItemVisualData.gradeVisuals[grade] then
		return false, "bad_grade"
	end
	local itemLevel = (current and current.itemLevel) or 100

	if isGemTarget then
		weapon.gems[slot] = { grade = grade, itemLevel = itemLevel, option = option }
		-- maxHpPercent·speedPercent는 PlayerState에 캐시돼 있다(setEquippedDirect는 이미
		-- 갱신하지만 보석 슬롯 직접 대입은 그 경로를 안 탄다) - 여기서 직접 갱신한다.
		PlayerProfile.refreshMaxHp(player)
		PlayerProfile.refreshMovementSpeed(player)
	else
		local item = buildGearItem(targetArg, grade, itemLevel)
		item.option = option
		PlayerProfile.setEquippedDirect(player, targetArg, item) -- 부위별로 이미 refreshMaxHp/refreshMovementSpeed를 호출한다.
	end
	return true
end

-- "/gg option stack <id>" - 26-3, PRD 20.67 [14] 8단계 "8개 몰빵 후 /gg measure - [7] 표
-- 재현". 장비 3부위 + 보석 5개 전부를 태초 등급·최대 롤로 그 옵션 하나로 채운다(applyOptionSet
-- 재사용 - 새 계산 경로를 만들지 않는다). 실패하면 그 자리에서 멈추고 이유를 돌려준다.
local OPTION_STACK_TARGETS = { "armor", "gloves", "shoes", "1", "2", "3", "4", "5" }
local function applyOptionStack(player, optionId)
	if not OptionData.options[optionId] then
		return false, "bad_option"
	end
	for _, target in ipairs(OPTION_STACK_TARGETS) do
		local success, reason = applyOptionSet(player, target, optionId, "primordial", "max")
		if not success then
			return false, ("%s(%s)"):format(reason, target)
		end
	end
	return true
end

-- "/gg option show" - 옵션을 가질 수 있는 8자리(장비 3부위 + 보석 5개) 각각의 id·등급·
-- 롤값·실제 적용 수치를 전부 찍고, 마지막에 8축(위력·신속·방어·건강·성장·재생·흡혈·치명)
-- 합산까지 낸다 - PlayerProfile.getOptionBonus/getCritBonus 그대로(서버 실전 경로와 같은
-- 함수) - 확률 뽑기에 기대지 않고 특정 값을 강제 배정해 바로 대조할 수 있다.
local function describeOptionSource(label, source, classId)
	if not source then
		print(("[DevTools]   %s: 미착용"):format(label))
		return
	end
	if not source.option then
		print(("[DevTools]   %s: %s등급 itemLevel%s, 옵션 없음"):format(label, tostring(source.grade), tostring(source.itemLevel)))
		return
	end
	local value = Option.valueOf(source.option, source.grade, source.itemLevel, classId)
	local valueText
	if type(value) == "table" then
		valueText = ("치확+%.2f%%p 치피+%.3f"):format(value.critRate * 100, value.critDmg * 100)
	else
		valueText = ("%.3f%%"):format(value * 100)
	end
	print(("[DevTools]   %s: %s등급 itemLevel%s, 옵션=%s 롤=%.4f(roll2=%s) -> %s"):format(
		label, tostring(source.grade), tostring(source.itemLevel), source.option.id, source.option.roll,
		source.option.roll2 and ("%.4f"):format(source.option.roll2) or "-", valueText))
end

local function printOptionShow(player)
	local classId = PlayerProfile.getClassId(player)
	local weapon = PlayerProfile.getWeapon(player)
	if not classId or not weapon then
		reply(player, "직업을 먼저 선택해야 합니다")
		return
	end

	print(("[DevTools] === 옵션 장착 현황(직업=%s) ==="):format(classId))
	describeOptionSource("armor", PlayerProfile.getEquipped(player, "armor"), classId)
	describeOptionSource("gloves", PlayerProfile.getEquipped(player, "gloves"), classId)
	describeOptionSource("shoes", PlayerProfile.getEquipped(player, "shoes"), classId)
	for slot = 1, Gem.slotCount do
		describeOptionSource("gem" .. slot, Gem.isFilled(weapon.gems, slot) and weapon.gems[slot] or nil, classId)
	end

	local optionCritRate, optionCritDmg = PlayerProfile.getCritBonus(player)
	print(("[DevTools] === 합산(장비+보석 옵션, 상한 적용됨) === 위력=%.3f%% 신속=%.3f%% 방어=%.3f%% 건강=%.3f%% 성장=%.3f%% 재생=%.3f%% 흡혈=%.3f%% 치확=%.3f%%p 치피=%.4f"):format(
		PlayerProfile.getOptionBonus(player, "attackPercent") * 100,
		PlayerProfile.getOptionBonus(player, "speedPercent") * 100,
		PlayerProfile.getOptionBonus(player, "defensePercent") * 100,
		PlayerProfile.getOptionBonus(player, "maxHpPercent") * 100,
		PlayerProfile.getOptionBonus(player, "expGain") * 100,
		PlayerProfile.getOptionBonus(player, "healingPower") * 100,
		PlayerProfile.getOptionBonus(player, "lifesteal") * 100,
		optionCritRate * 100, optionCritDmg))
	reply(player, "옵션 장착 현황을 콘솔에 출력했습니다")
end

-- "/gg option lifesteal" - 26-2, PRD 20.67 [6-1] 실측. AttackRequest는 RemoteEvent라
-- execute_luau 클라이언트가 FireServer를 못 쏜다(Studio MCP 제약, 3D 월드 클릭도 자동화
-- 불가) - 그래서 실전 경로가 실제로 부르는 함수(PlayerProfile.applyLifesteal →
-- PlayerState.tryLifesteal, AttackServer/strikeTarget과 정확히 같은 호출)를 서버 스크립트
-- 안에서 실시간(os.clock() 기준 task.wait)으로 반복 호출해 초당 회복량을 직접 잰다 - 새
-- 계산 경로를 만들지 않는다. 요청량을 maxHp의 10배로 크게 잡아 "%가 아무리 커도 상한을
-- 못 넘는지"를 확인한다.
local function runLifestealSelfTest(player)
	local maxHp = PlayerState.getMaxHp(player)
	if not maxHp then
		reply(player, "캐릭터가 로드되지 않았습니다")
		return
	end
	PlayerState.setHp(player, maxHp * 0.5) -- 회복 관찰 여지를 만든다(만피면 상한에 막혀도 안 보인다).
	local hugeDamage = maxHp * 10
	local startHp = PlayerState.getHp(player)
	local startAt = os.clock()
	local sampleCount = 30
	for _ = 1, sampleCount do
		task.wait(0.1)
		PlayerProfile.applyLifesteal(player, hugeDamage)
	end
	local elapsedSeconds = os.clock() - startAt
	local recovered = math.min(PlayerState.getHp(player), maxHp) - startHp
	local fractionPerSecond = recovered / maxHp / elapsedSeconds
	print(("[DevTools] === 흡혈 초당 상한 실측(20.67 [6-1]) === %.2f초 동안 회복 %.2f/%.2f maxHp -> 초당 %.4f%%(상한 %.2f%%)"):format(
		elapsedSeconds, recovered, maxHp, fractionPerSecond * 100, CombatConfig.lifestealMaxHpFractionPerSecond * 100))
	reply(player, ("흡혈 초당 회복 실측 %.4f%% (상한 %.2f%%, 못 넘으면 정상)"):format(
		fractionPerSecond * 100, CombatConfig.lifestealMaxHpFractionPerSecond * 100))
end

-- "/gg measure [stage]" - 지금 이 플레이어가 실제로 들고 있는 레벨·장비·강화·직업
-- 그대로(합성 조건이 아니라 실측) 생존 타수와 60초 평타 총딜을 계산해 콘솔에 낸다.
-- stage를 생략하면 지금 프로필의 무한 스테이지를 쓴다.
local function measure(player, stageOverride)
	local classId = PlayerProfile.getClassId(player)
	if not classId then
		reply(player, "직업을 먼저 선택해야 합니다")
		return
	end
	local level = PlayerProfile.getCharacterLevel(player)
	local weapon = PlayerProfile.getWeapon(player)
	local equipment = {
		armor = PlayerProfile.getEquipped(player, "armor"),
		gloves = PlayerProfile.getEquipped(player, "gloves"),
		shoes = PlayerProfile.getEquipped(player, "shoes"),
	}
	local stage = stageOverride or PlayerProfile.getInfiniteStage(player) or 1

	local loadout = BalanceSim.buildLoadoutFromEquipment(classId, level, weapon.level, weapon.grade, equipment, weapon.gems)
	local autoAttack60 = BalanceSim.simulateAutoAttack(loadout, 60)

	-- 20-7: 순수 평타(비행시간·콤보 카운터 반영) / 실전 로테이션(Q+E) / 광역(동시 2마리 - 격자
	-- 64stud·어그로 25.6·리쉬 38.4 관계상 한 플레이어가 동시에 끌 수 있는 실질 최대치) /
	-- tier1 1마리 처치 시간(새 대상으로 돌아서는 회전 지연 포함) - 전부 BalanceSim.simulateCombat.
	-- 21-1: 생존 타수·처치 시간은 BalanceSim.measurePoint("/gg curve"와 같은 함수)로 뽑고,
	-- 총딜은 raw와 함께 atk-단위(무기 기본 atk 기준 - PRD-forge-game.md 4.4 표와 같은 눈금)로도 찍는다.
	local point = BalanceSim.measurePoint(loadout, stage)
	local auto60 = BalanceSim.simulateCombat(loadout, { useSkills = false })
	local rotation60 = BalanceSim.simulateCombat(loadout, { useSkills = true })
	local aoe60 = BalanceSim.simulateCombat(loadout, { useSkills = true, targetCount = 2 })
	local unit = point.unit

	print(("[DevTools] === %s 실측 (직업=%s, 레벨=%d, 무기등급=%s, 강화=+%d, 스테이지=%d, 권장 스테이지 rec(L)=%d / rec(L,g)=%d) ==="):format(
		player.Name, classId, level, ArmorData.gradeOrder[(weapon.grade or 0) + 1] or tostring(weapon.grade), weapon.level, stage,
		BalanceSim.recommendedStage(level, weapon.grade, false), BalanceSim.recommendedStage(level, weapon.grade, true)))
	print(("[DevTools] 공격력=%.2f 방어력=%.2f 최대체력=%.2f 공격쿨다운=%.3f초 (atk-단위 1 = %.2f)"):format(
		loadout.atk, loadout.defense, loadout.maxHp, loadout.attackCooldown, unit))
	-- 23-4: BalanceSim이 이제 weapon.gems를 읽는다 - 보석 장착 전/후 차이가 실제로
	-- 반영됐는지 콘솔에서 바로 보이도록 축별 보너스를 따로 찍는다.
	-- 26-2: Gem.total*PercentBonus 폐기(PRD 20.67 [14] 3단계) - PlayerProfile.getOptionBonus
	-- 하나로 장비 3부위 옵션 + 보석 5개를 통합해 읽는다(장갑·신발·갑옷의 "기본효과"는 이
	-- 값에 안 잡힌다 - 옛 "보석 보너스"와 같은 의미, 옵션 층만 따로 보는 진단 라인이다).
	print(("[DevTools] 옵션 보너스(장비+보석): 위력+%.1f%% 신속+%.1f%% 방어+%.1f%% 건강+%.1f%%"):format(
		PlayerProfile.getOptionBonus(player, "attackPercent") * 100, PlayerProfile.getOptionBonus(player, "speedPercent") * 100,
		PlayerProfile.getOptionBonus(player, "defensePercent") * 100, PlayerProfile.getOptionBonus(player, "maxHpPercent") * 100))
	print(("[DevTools] tier1 몬스터 평타(스테이지%d 적용)=%.3f -> 실제 피해=%.3f/대 -> 생존 타수=%.2f대"):format(
		stage, point.monsterAttack, point.dmgPerHit, point.surviveHits))
	print(("[DevTools] 60초 순수 평타 총딜(평균 근사)=%.1f (%.1f회 타격, 평균 %.2f/타) / 시뮬레이션=%.1f (%d회) = atk-단위 %.1f"):format(
		autoAttack60.totalDamage, autoAttack60.hits, autoAttack60.avgHit, auto60.totalDamage, auto60.autoHits, auto60.totalDamage / unit))
	local skillParts = {}
	for name, casts in pairs(rotation60.casts) do
		table.insert(skillParts, ("%s×%d=%.1f"):format(name, casts, rotation60.skillDamage[name] or 0))
	end
	table.sort(skillParts)
	print(("[DevTools] 60초 실전 로테이션(Q+E) 단일 총딜=%.1f (평타 %.1f + 스킬 %.1f: %s) = atk-단위 %.1f"):format(
		rotation60.totalDamage, rotation60.autoDamage, rotation60.skillDamageTotal, table.concat(skillParts, ", "), rotation60.totalDamage / unit))
	print(("[DevTools] 60초 광역(동시 2마리) 총딜=%.1f = atk-단위 %.1f"):format(aoe60.totalDamage, aoe60.totalDamage / unit))
	print(("[DevTools] tier1 1마리(HP %.1f) 처치 시간: 평타만=%.2f초(%d타), 로테이션=%.2f초"):format(
		point.monsterHp, point.killAutoSeconds, point.killAutoHits, point.killRotationSeconds))
end

-- "/gg curve anchor [classId]"(25-1 전엔 "/gg curve") - 앵커 곡선(21-1 [2], BalanceAnchorConfig) 위의 격자(레벨×무기등급)를
-- 전부 재서 콘솔에 표로 낸다. 직업을 생략하면 지금 프로필의 직업. 원본 상수(α·계수·k·g·
-- tier1 HP)가 바뀔 때마다 이 한 줄로 곡선을 다시 뽑는다 - 파생 표를 손으로 다시 계산하지 않는다.
local function printCurve(player, classIdArg)
	local classId = classIdArg or PlayerProfile.getClassId(player)
	if not classId or not ClassData.classes[classId] then
		reply(player, ("알 수 없는 직업: %s (사용 가능: %s)"):format(tostring(classIdArg), table.concat(ClassData.order, "/")))
		return
	end
	local offset = BalanceSim.solveKillOffset()
	print(("[DevTools] === 앵커 곡선 (%s) rec(L) = L %+.2f (기준 %s 레벨%d에서 로테이션 처치 %.1f초 역산) ==="):format(
		classId, offset, BalanceAnchorConfig.referenceClassId, BalanceAnchorConfig.referenceLevel, BalanceAnchorConfig.killTargetSeconds))
	print("[DevTools] 레벨 | 등급(Δ) | rec(L): 생존/처치 | rec(L,g): 생존/처치 | rec(L,g)+갑옷등급 짝: 생존/처치")
	for _, row in ipairs(BalanceSim.measureCurve(classId)) do
		print(("[DevTools] L%d | g%d(Δ%.1f) | S%d: %.2f타 / %.2f초 | S%d: %.2f타 / %.2f초 | S%d: %.2f타 / %.2f초"):format(
			row.level, row.grade, BalanceSim.gradeStageShift(row.grade),
			row.recFree, row.free.surviveHits, row.free.killRotationSeconds,
			row.recGrade, row.graded.surviveHits, row.graded.killRotationSeconds,
			row.recGrade, row.paired.surviveHits, row.paired.killRotationSeconds))
	end
end

-- "/gg curve" - 25-1 레벨 곡선. 레벨 1~125의 목표 마릿수 K(L)(CharacterLevelConfig.
-- killTargetAnchors 보간)와, 그 레벨 임계값에서 스테이지 L의 tier1만 잡을 때 실제로 계산되는
-- 마릿수(CharacterLevel.getExpectedKills - 정수 경험치라 올림)를 지금 배수(PlayerProfile.
-- getExpGainMultiplier)와 +25% 가정(다음 세션 옵션 최대치) 둘 다로 찍는다. 앵커·회차 합계도
-- 같이 낸다 - 원본(앵커·k·경험치 계수)이 바뀔 때마다 이 한 줄로 표를 다시 뽑는다.
local LEVEL_CURVE_MAX = 125
local LEVEL_CURVE_OPTION_MAX = 1.25
local function printLevelCurve(player)
	local mult = PlayerProfile.getExpGainMultiplier(player)
	print(("[DevTools] === 레벨 곡선(25-1) - 목표 K(L) vs 실제(경험치 배수 ×%.2f) vs +25%% 가정(×%.2f) - 전제: 스테이지=레벨에서 tier1 사냥 ==="):format(
		mult, LEVEL_CURVE_OPTION_MAX))
	print("[DevTools] L | K(L) | E(L)=tier1 경험치 | L→L+1 필요 경험치 | 실제 마릿수 | +25% 마릿수 | 누적 경험치")
	local sumTarget, sumActual, sumOption = 0, 0, 0
	local segments = { 25, 50, 75, 100, 125 }
	local segIndex, segStart = 1, 1
	local segTarget, segActual, segOption = 0, 0, 0
	for level = 1, LEVEL_CURVE_MAX do
		local k = CharacterLevel.getTargetKills(level)
		local e = CharacterLevel.getMonsterExpAtLevel(level)
		local need = CharacterLevel.getExpToNextLevel(level)
		local actual = CharacterLevel.getExpectedKills(level, mult)
		local option = CharacterLevel.getExpectedKills(level, mult * LEVEL_CURVE_OPTION_MAX)
		print(("[DevTools] L%d | %.3f | %d | %d | %d | %d | %d"):format(
			level, k, e, need, actual, option, CharacterLevel.getExpForLevel(level)))
		if level < LEVEL_CURVE_MAX then
			sumTarget += k
			sumActual += actual
			sumOption += option
			segTarget += k
			segActual += actual
			segOption += option
		end
		if level + 1 == segments[segIndex] then
			print(("[DevTools]   구간 %d→%d 합계: 목표 %.1f / 실제 %d / +25%% %d"):format(
				segStart, segments[segIndex], segTarget, segActual, segOption))
			segIndex += 1
			segStart = level + 1
			segTarget, segActual, segOption = 0, 0, 0
		end
	end
	print(("[DevTools] 1→%d 전체 합계: 목표 %.1f / 실제 %d / +25%% %d"):format(LEVEL_CURVE_MAX, sumTarget, sumActual, sumOption))
	for _, anchor in ipairs(CharacterLevelConfig.killTargetAnchors) do
		print(("[DevTools]   앵커 L%d: 목표 %d → K(L)=%.3f"):format(anchor.level, anchor.kills, CharacterLevel.getTargetKills(anchor.level)))
	end
	-- 연속성: 인접 레벨 간 K(L) 차이의 최대값(계단이면 여기서 튄다).
	local maxStep = 0
	for level = 1, LEVEL_CURVE_MAX - 1 do
		maxStep = math.max(maxStep, CharacterLevel.getTargetKills(level + 1) - CharacterLevel.getTargetKills(level))
	end
	print(("[DevTools]   연속성: 인접 레벨 K(L) 최대 증가폭 %.4f마리(계단 없음 기준 < 1)"):format(maxStep))
end

-- "/gg curve migrate" - v21(옛 두 곡선) 형태의 characterExp를 SaveSystem.migrate에 실제로 통과시켜
-- 레벨이 그대로 유지되고 경험치가 음수가 되지 않는지 확인한다(25-1). 실제 세이브(DataStore)
-- 이관은 Play 재시작으로 따로 본다 - 이건 경계값(0·표 끝·환생 직후)까지 합성해서 도는 자체검증.
local function runMigrateSelfTest(player)
	local legacy = SaveSystem.legacyCurveV21
	local cases = {
		{ rebirth = 0, exp = 0, label = "신규(0)" },
		{ rebirth = 0, exp = 49, label = "레벨1 98%" },
		{ rebirth = 0, exp = 3831, label = "표 안(레벨13 45%)" },
		{ rebirth = 0, exp = 25000, label = "표 끝(레벨25 경계)" },
		{ rebirth = 0, exp = legacy.getExpForLevel(60, false), label = "표+지수식 이어붙임(레벨60)" },
		{ rebirth = 1, exp = 0, label = "환생 직후(0)" },
		{ rebirth = 1, exp = legacy.getExpForLevel(40, true) * 1.0 + 0.5 * (legacy.getExpForLevel(41, true) - legacy.getExpForLevel(40, true)), label = "지수식(레벨40 50%)" },
		{ rebirth = 3, exp = legacy.getExpForLevel(100, true), label = "지수식(레벨100)" },
		{ rebirth = 5, exp = legacy.getExpForLevel(125, true), label = "지수식(레벨125)" },
	}
	local pass = 0
	for _, case in ipairs(cases) do
		local profile = SaveSystem.defaultProfile()
		profile.version = 21
		local classState = profile.classes[ClassData.order[1]]
		classState.rebirthCount = case.rebirth
		classState.characterExp = case.exp
		local useExponential = case.rebirth > 0
		local expectLevel = legacy.getLevelFromExp(case.exp, useExponential)
		local from, to = legacy.getExpForLevel(expectLevel, useExponential), legacy.getExpForLevel(expectLevel + 1, useExponential)
		local expectRatio = to > from and (case.exp - from) / (to - from) or 0

		local migrated = SaveSystem.migrate(profile)
		local newExp = migrated.classes[ClassData.order[1]].characterExp
		local newLevel = CharacterLevel.getLevelFromExp(newExp)
		local progress = CharacterLevel.getProgress(newExp, newLevel)
		local ok = migrated.version == SaveConfig.saveVersion and newLevel == expectLevel and newExp >= 0
			and math.abs(progress.ratio - expectRatio) < 1e-6 and SaveSystem.isValidProfile(migrated)
		pass += ok and 1 or 0
		print(("[curvemigrate] %s %s: rebirth=%d exp %.2f → %.2f, 레벨 %d → %d, 진행률 %.3f → %.3f"):format(
			ok and "O" or "X", case.label, case.rebirth, case.exp, newExp, expectLevel, newLevel, expectRatio, progress.ratio))
	end
	reply(player, ("curve migrate 자체검증 %d/%d 통과"):format(pass, #cases))
end

-- "/gg option table" - 26-1, PRD 20.67 [14] 1단계 검증. Option.lua는 아직 게임에 연결되지
-- 않았다(어떤 서버 모듈도 require하지 않는다) - 이 명령이 유일한 호출부다. [3]의 등급별
-- 구간표·레벨 계수 동결·롤 분포 세 가지를 콘솔에 찍어 그 절과 직접 대조한다.
local OPTION_TABLE_GRADES = { "epic", "legendary", "relic", "ancient", "primordial" }
local OPTION_TABLE_ITEM_LEVEL = 100
local function printOptionTable(player)
	print("[DevTools] === 옵션 통합 구간표(20.67 [3], itemLevel100 기준, 최소/기댓값/최대) ===")
	print("[DevTools] 옵션 | 영웅 | 전설 | 유물 | 고대 | 태초")
	for _, optionId in ipairs(OptionData.commonOrder) do
		local def = OptionData.options[optionId]
		local cells = {}
		for _, gradeId in ipairs(OPTION_TABLE_GRADES) do
			local range = Option.rangeOf(optionId, gradeId, OPTION_TABLE_ITEM_LEVEL, nil)
			if def.critRateBase then
				-- 치명은 {critRate, critDmg} 테이블 - 치확만 표에 찍는다(치피는 같은 배율의
				-- 다른 단위라 숫자가 같다, OptionData.crit 주석 참고).
				table.insert(cells, ("%.2f/%.2f/%.2f"):format(range.min.critRate * 100, range.mid.critRate * 100, range.max.critRate * 100))
			else
				table.insert(cells, ("%.2f/%.2f/%.2f"):format(range.min * 100, range.mid * 100, range.max * 100))
			end
		end
		print(("[DevTools] %s | %s"):format(def.displayName, table.concat(cells, " | ")))
	end

	print("[DevTools] === 레벨 계수 f(L)(20.67 [3], 기준100=1.0, 동결125) ===")
	local levelSamples = { 1, 10, 25, 50, 75, 100, 125, 130 }
	local levelCells = {}
	for _, level in ipairs(levelSamples) do
		table.insert(levelCells, ("L%d=%.3f"):format(level, Option.levelFactor(level)))
	end
	print("[DevTools] " .. table.concat(levelCells, " | "))
	print(("[DevTools]   동결 확인: f(125)=%.4f, f(130)=%.4f (같아야 함)"):format(Option.levelFactor(125), Option.levelFactor(130)))
	print(("[DevTools]   절대 최대 계수(20.67 [3]) = rollMax × f(125) = %.3f × %.4f = %.4f (기대 1.368)"):format(
		OptionData.rollMax, Option.levelFactor(125), OptionData.rollMax * Option.levelFactor(125)))

	local rollCount = 1000
	local sum, minRoll, maxRoll = 0, math.huge, -math.huge
	for _ = 1, rollCount do
		local roll = Option.rollValue()
		sum += roll
		minRoll = math.min(minRoll, roll)
		maxRoll = math.max(maxRoll, roll)
	end
	print(("[DevTools] === 롤 분포(1000회) === 평균=%.4f(기대 1.0) 최소=%.4f 최대=%.4f (범위 [%.3f, %.3f] 안이어야 함)"):format(
		sum / rollCount, minRoll, maxRoll, OptionData.rollMin, OptionData.rollMax))

	reply(player, "옵션 구간표·레벨계수·롤 분포를 콘솔에 출력했습니다")
end

-- "/gg option migrate" - 26-1, PRD 20.67 [14] 2단계 검증. v22 형태(gem.optionId)의 합성
-- 보석을 실제 SaveSystem.migrate에 통과시켜 [13] 이관 규칙(옛 이름→새 옵션 id 기댓값 롤,
-- 영웅~유물 무조건 승격, 고대·태초 미배정 유지, itemLevel 백필)을 자체검증한다("/gg curve
-- migrate"와 같은 패턴 - 합성 프로필을 실제 migrate에 통과시킨다).
local OPTION_MIGRATE_OLD_AXIS_ID = {
	["연속격"] = "attackPercent", ["속사의 흔적"] = "speedPercent",
	["심판의 표식"] = "defensePercent", ["삼위일체"] = "maxHpPercent",
}
local function runOptionMigrateSelfTest(player)
	local classId = ClassData.order[1]
	local cases = {
		{ grade = "ancient", optionId = "연속격", rebirth = 1, level = 25, label = "고대+연속격(옛 이름)" },
		{ grade = "primordial", optionId = "삼위일체", rebirth = 5, level = 125, label = "태초+삼위일체(옛 이름)" },
		{ grade = "epic", optionId = nil, rebirth = 1, level = 25, label = "영웅 무조건 공격력%(옵션 풀 없는 등급)" },
		{ grade = "legendary", optionId = nil, rebirth = 2, level = 50, label = "전설 무조건 공격력%" },
		{ grade = "relic", optionId = nil, rebirth = 3, level = 75, label = "유물 무조건 공격력%" },
		{ grade = "ancient", optionId = nil, rebirth = 4, level = 100, label = "고대 옵션 미배정(nil 유지)" },
		{ grade = "primordial", optionId = nil, rebirth = 5, level = 125, label = "태초 옵션 미배정(nil 유지)" },
	}

	local pass = 0
	for _, case in ipairs(cases) do
		local profile = SaveSystem.defaultProfile()
		profile.version = 22
		local classState = profile.classes[classId]
		classState.rebirthCount = case.rebirth
		classState.characterExp = CharacterLevel.getExpForLevel(case.level)
		classState.weapon.gems[1] = { grade = case.grade, optionId = case.optionId }

		local migrated = SaveSystem.migrate(profile)
		local gem = migrated.classes[classId].weapon.gems[1]

		local expectOptionId
		if case.optionId then
			expectOptionId = OPTION_MIGRATE_OLD_AXIS_ID[case.optionId]
		elseif not GemData.optionPoolByGrade[case.grade] then
			expectOptionId = "attackPercent"
		end
		local expectedItemLevel = math.max(25 * case.rebirth, case.level, 1)

		local optionOk = (expectOptionId == nil and gem.option == nil)
			or (gem.option and gem.option.id == expectOptionId and gem.option.roll == 1.0)
		local ok = migrated.version == SaveConfig.saveVersion and gem.optionId == nil
			and optionOk and gem.itemLevel == expectedItemLevel and SaveSystem.isValidProfile(migrated)
		pass += ok and 1 or 0
		print(("[optionmigrate] %s %s: option=%s itemLevel=%d (기대 id=%s itemLevel=%d)"):format(
			ok and "O" or "X", case.label, gem.option and gem.option.id or "nil", gem.itemLevel,
			tostring(expectOptionId), expectedItemLevel))
	end
	reply(player, ("option migrate 자체검증 %d/%d 통과"):format(pass, #cases))
end

-- "/gg anchor [classId]" - classId를 주면 먼저 그 직업으로 전환한 뒤 앵커 조건을 건다.
local function applyAnchor(player, classId)
	ensureBackup(player)
	if classId and not applyClass(player, classId) then
		return
	end
	applyLevel(player, ANCHOR.level)
	applyGear(player, ANCHOR.gearGrade, ANCHOR.gearItemLevel)
	applyEnhance(player, ANCHOR.weaponLevel)
	applyWeaponGrade(player, ANCHOR.weaponGrade)
	applyStage(player, ANCHOR.stage)
	reply(player, ("앵커 조건 적용 완료(레벨%d, %s등급 itemLevel%d 3부위, 강화+%d, 무기등급%d, 스테이지%d) - 직업=%s"):format(
		ANCHOR.level, ANCHOR.gearGrade, ANCHOR.gearItemLevel, ANCHOR.weaponLevel, ANCHOR.weaponGrade, ANCHOR.stage,
		tostring(PlayerProfile.getClassId(player))))
	measure(player, ANCHOR.stage)
end

-- ═══ 22-4 테스트 지형 - tier1 구역 중앙 슬롯 둘레에 세운다 ═══
-- 고원(높이 9.6 > 높이차 상한 8) 위에 중앙 슬롯이 놓여 스폰 스냅을 시험하고, 네 변이 각각
-- 30° 경사로(-Z, 오를 수 있음) / 계단 6단×1.6(+Z, 오를 수 있음) / 70° 경사(-X, 막힘) /
-- 수직 절벽(+X, 막힘)이다. 여기에 tier1 바닥을 갈라 폭 12의 도랑(심연, 바닥 없음)을 오른쪽
-- 슬롯 열(중심 +64)의 집에서 6~18 자리에 낸다(리쉬 38.4 안이라 몬스터가 실제로 도랑 앞까지
-- 온다) - 그 몬스터가 도랑 앞에서 멈추는지, 떨어진 플레이어가 입구로 복귀하는지 본다.
-- 22-5: 바닥이 조각 여러 개(웅덩이 구멍)라 도랑 x 범위와 겹치는 조각 전부를 가른다. 실제 지형
-- (언덕·웅덩이)과 겹쳐 세워지므로 이 명령은 접지·부하·드랍 검증(cost/ground/drop/rules) 보조용이다.
-- "/gg terrain clear"가 전부 되돌린다.
local TERRAIN_TEST_TAG = "TerrainTest"
local TERRAIN_PLATEAU_HEIGHT = 9.6
local terrainOriginalFloors = {} -- 22-5: 가른 바닥 조각들(ServerStorage에 치워 둔다)
local terrainOriginalBases = {} -- 맵 밑판 조각들 - 도랑이 진짜 심연이 되도록 테스트 중엔 치운다(복도도 심연이 된다).

local function terrainPart(name, size, cframe, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.Material = Enum.Material.Slate
	part.Color = color or Color3.fromRGB(150, 130, 110)
	part:AddTag(TERRAIN_TEST_TAG)
	part.Parent = GroundProbe.folder()
	return part
end

local function buildTestTerrain(player)
	if #game:GetService("CollectionService"):GetTagged(TERRAIN_TEST_TAG) > 0 then
		reply(player, "테스트 지형이 이미 있습니다 - /gg terrain clear 먼저")
		return
	end
	local zone = WorldConfig.zones.tier1
	local cx, cz = zone.center.X, zone.center.Z
	local floorTop = 1
	local h = TERRAIN_PLATEAU_HEIGHT

	-- 고원 20×20, 윗면 floorTop+h
	terrainPart("TestPlateau", Vector3.new(20, h, 20), CFrame.new(cx, floorTop + h / 2, cz), Color3.fromRGB(120, 110, 100))

	-- -Z 변: 30° 경사로. 수평 run = h/tan30, 판 길이 L = sqrt(run²+h²). +Z 끝(고원 쪽)이 높다.
	local angle30 = math.rad(30)
	local run30 = h / math.tan(angle30)
	local length30 = math.sqrt(run30 * run30 + h * h)
	local thickness = 0.6
	terrainPart("TestRamp30", Vector3.new(12, thickness, length30),
		CFrame.new(cx, floorTop + h / 2 - (thickness / 2) / math.cos(angle30), cz - 10 - run30 / 2) * CFrame.Angles(-angle30, 0, 0),
		Color3.fromRGB(110, 150, 110))

	-- +Z 변: 계단 6단 × 1.6 (깊이 3). 고원에 가까운 단이 높다.
	local stepCount = 6
	local stepRise = h / stepCount
	for i = 1, stepCount do
		local z = cz + 10 + 3 * (stepCount - i) + 1.5
		terrainPart("TestStair" .. i, Vector3.new(12, stepRise * i, 3), CFrame.new(cx, floorTop + stepRise * i / 2, z), Color3.fromRGB(110, 130, 160))
	end

	-- -X 변: 70° 급경사(막혀야 한다). +X 끝(고원 쪽)이 높다.
	local angle70 = math.rad(70)
	local run70 = h / math.tan(angle70)
	local length70 = math.sqrt(run70 * run70 + h * h)
	terrainPart("TestRamp70", Vector3.new(length70, thickness, 12),
		CFrame.new(cx - 10 - run70 / 2, floorTop + h / 2 - (thickness / 2) / math.cos(angle70), cz) * CFrame.Angles(0, 0, angle70),
		Color3.fromRGB(170, 100, 100))
	-- +X 변: 수직 절벽(고원 옆면 그대로).

	-- 도랑: 도랑 x 범위와 겹치는 tier1 바닥 조각을 ServerStorage로 치우고 좌우 조각으로 다시 깐다.
	local gapMin = cx + WorldConfig.zoneMonsterGrid.spacingStuds + 6
	local gapMax = gapMin + 12
	for _, floor in ipairs(GroundProbe.folder():GetChildren()) do
		if floor:IsA("BasePart") and floor.Name:sub(1, #"ZoneFloor_tier1") == "ZoneFloor_tier1" then
			local minX, maxX = floor.Position.X - floor.Size.X / 2, floor.Position.X + floor.Size.X / 2
			if gapMin < maxX and gapMax > minX then
				table.insert(terrainOriginalFloors, floor)
				for _, span in ipairs({ { minX, math.max(minX, gapMin) }, { math.min(maxX, gapMax), maxX } }) do
					local width = span[2] - span[1]
					if width > 0.01 then
						local piece = terrainPart("TestFloorPiece", Vector3.new(width, floor.Size.Y, floor.Size.Z),
							CFrame.new((span[1] + span[2]) / 2, floor.Position.Y, floor.Position.Z), floor.Color)
						piece.Material = floor.Material
					end
				end
				floor.Parent = ServerStorage
			end
		end
	end
	for _, base in ipairs(GroundProbe.folder():GetChildren()) do
		if base:IsA("BasePart") and base.Name:sub(1, #"MapBase") == "MapBase" then
			table.insert(terrainOriginalBases, base)
			base.Parent = ServerStorage
		end
	end

	reply(player, ("테스트 지형 생성: 고원 %.1f(상한 %d 초과) / 30° 경사로(-Z) / 계단 6×%.1f(+Z) / 70° 경사(-X) / 절벽(+X) / 도랑 x∈[%d,%d]. 중앙 슬롯 몬스터는 다음 리스폰부터 고원 위에 스폰")
		:format(h, TerrainConfig.heightToleranceStuds, stepRise, gapMin, gapMax))
end

local function clearTestTerrain(player)
	for _, part in ipairs(game:GetService("CollectionService"):GetTagged(TERRAIN_TEST_TAG)) do
		part:Destroy()
	end
	for _, floor in ipairs(terrainOriginalFloors) do
		floor.Parent = GroundProbe.folder()
	end
	terrainOriginalFloors = {}
	for _, base in ipairs(terrainOriginalBases) do
		base.Parent = GroundProbe.folder()
	end
	terrainOriginalBases = {}
	reply(player, "테스트 지형 제거 + tier1 바닥·맵 밑판 복원")
end

-- 22-5: 배치 규칙 강제 검증. (1) 실제 tier1 데이터는 위반 0이어야 하고, (2) 일부러 규칙을 어긴 합성
-- 요소 목록(도달원 안 절벽 박스·60° 경사·키 큰 바위·구멍·높이 9 언덕·절벽 단, 그리고 구역 밖 요소)은
-- 전부 거부돼야 한다. 인스턴스를 만들지 않는 dry-run(ZoneTerrain.plan)이라 게임 상태를 안 건드린다.
local function reportTerrainRules(player)
	local zone = WorldConfig.zones.tier1
	local floorTopY, floorThickness = 1, 2
	local lines = {}
	-- 22-6: 데이터가 있는 구역 전부를 검사한다(tier1·tier2·spawn…).
	for _, key in ipairs(WorldConfig.zoneOrder) do
		local data = ZoneTerrainData.zones[key]
		if data then
			local real = ZoneTerrain.plan(WorldConfig.zones[key], data.features, floorTopY, floorThickness)
			table.insert(lines, ("[규칙] 실제 %s 데이터: 요소 %d, 위반 %d"):format(key, real.featureCount, #real.violations))
			for _, v in ipairs(real.violations) do
				table.insert(lines, "  ! " .. v)
			end
		end
	end
	local bad = {
		{ kind = "box", x = 0, z = 0, size = { 8, 4, 8 }, ground = true, surface = "rock" }, -- 슬롯 위 절벽(단차 4)
		{ kind = "wedge", x = 20, z = 0, size = { 8, 7, 4 }, tallDir = "+x", ground = true, surface = "rock" }, -- 60° 경사
		{ kind = "box", x = -20, z = 20, size = { 4, 3, 4 }, surface = "rock" }, -- 키 큰 충돌 바위(높이 3)
		{ kind = "hole", x = 0, z = 40, w = 10, d = 10 }, -- 심연
		{ kind = "hill", x = 30, z = 30, top = { 10, 10 }, height = 9, run = 12, surface = "grass" }, -- 높이차 상한 초과
		{ kind = "terrace", x = 60, z = 60, w = 20, d = 20, height = 4, stairsSide = "-z", surface = "grass" }, -- 절벽 면이 도달원 안
		{ kind = "box", x = 130, z = 0, size = { 4, 3, 4 }, surface = "rock" }, -- 구역 밖
		{ kind = "box", x = 112, z = 112, size = { 4, 3, 4 }, surface = "rock" }, -- 띠 안 - 통과해야 한다
		{ kind = "hill", x = 32, z = -32, top = { 8, 8 }, height = 2, run = 6, surface = "grass" }, -- 도달원 안 완만 - 통과해야 한다
	}
	local synthetic = ZoneTerrain.plan(zone, bad, floorTopY, floorThickness)
	table.insert(lines, ("[규칙] 합성 목록 %d개 중 거부 %d(기대 7), 통과 %d(기대 2)"):format(#bad, #synthetic.violations, #synthetic.accepted))
	for _, v in ipairs(synthetic.violations) do
		table.insert(lines, "  - " .. v)
	end
	reply(player, table.concat(lines, "\n"))
end

-- 22-5: 파트 수 실측(예산 20.49 [1] 대조). 서버 Workspace 기준 - 클라이언트 화면 내 수는 스트리밍
-- 때문에 클라에서 따로 센다.
local function reportPartCounts(player)
	local total, ground, decor, monsters, perZone = 0, 0, 0, 0, {}
	local groundFolder = GroundProbe.folder()
	local decorFolder = workspace:FindFirstChild("ZoneDecor")
	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst:IsA("BasePart") then
			total += 1
			if inst:IsDescendantOf(groundFolder) then
				ground += 1
			elseif decorFolder and inst:IsDescendantOf(decorFolder) then
				decor += 1
			end
			local zoneKey = inst:GetAttribute("ZoneKey")
			if zoneKey then
				perZone[zoneKey] = (perZone[zoneKey] or 0) + 1
			end
			if inst.Parent and inst.Parent:IsA("Model") and inst.Parent:HasTag("Monster") then
				monsters += 1
			end
		end
	end
	local zoneLines = {}
	for _, key in ipairs(WorldConfig.zoneOrder) do
		table.insert(zoneLines, ("%s=%d"):format(key, perZone[key] or 0))
	end
	reply(player, ("[파트] Workspace BasePart 총 %d / 지면 폴더 %d / 장식 폴더 %d / 몬스터 %d / 구역별 지형(바닥 포함): %s"):format(
		total, ground, decor, monsters, table.concat(zoneLines, " ")))
end

-- 지면 프로브 부하 실측: (1) 합성 벤치 - 지금 지면 폴더에 대해 10,000회 Raycast 소요 시간 →
-- 1회당 µs, (2) 실측 - 5초 동안 실제 AI가 쏜 횟수·ms(GroundProbe.stats 두 시점 차).
local function reportProbeCost(player)
	local zone = WorldConfig.zones.tier1
	local benchCount = 10000
	local started = os.clock()
	for i = 1, benchCount do
		GroundProbe.groundY(zone.center.X + (i % 100) - 50, zone.center.Z + (i % 37) - 18, 1)
	end
	local benchSeconds = os.clock() - started
	local perProbeMicro = benchSeconds / benchCount * 1e6
	local monsterCount = #MonsterState.getAllModels()
	local probesPerSecondWorst = monsterCount / TerrainConfig.probeIntervalSeconds
	reply(player, ("[벤치] Raycast %d회 %.1fms → 1회 %.2fµs. 최악(%d마리 전부 이동, %.1f초 주기) %d회/초 ≈ %.2fms/초 = 서버 시간의 %.3f%%")
		:format(benchCount, benchSeconds * 1000, perProbeMicro, monsterCount, TerrainConfig.probeIntervalSeconds,
			probesPerSecondWorst, probesPerSecondWorst * perProbeMicro / 1000, probesPerSecondWorst * perProbeMicro / 1000 / 10))
	local count0, seconds0 = GroundProbe.stats()
	task.delay(5, function()
		local count1, seconds1 = GroundProbe.stats()
		reply(player, ("[실측 5초] AI 지면 프로브 %d회(%.1f회/초), %.2fms(%.3fms/초)")
			:format(count1 - count0, (count1 - count0) / 5, (seconds1 - seconds0) * 1000, (seconds1 - seconds0) * 1000 / 5))
	end)
end

-- 지형 검증 보조: 살아있는 몬스터 전부의 발 Y − 그 자리 지면 Y를 표로 찍는다(땅속·공중 검사).
local function reportMonsterGrounding(player, zoneKey)
	zoneKey = zoneKey or "tier1"
	local lines = {}
	local sunk, floating = 0, 0
	for _, model in ipairs(MonsterState.getAllModels()) do
		local root = model.PrimaryPart
		local data = MonsterState.getData(model)
		if root and data and not data.isBoss then
			local footY = root.Position.Y - TerrainConfig.monsterFootOffsetStuds
			local groundY = GroundProbe.surfaceY(root.Position.X, root.Position.Z, root.Position.Y)
			local gap = groundY and footY - groundY or nil
			if gap and gap < -0.3 then sunk += 1 end
			if gap and gap > 0.3 then floating += 1 end
			if MonsterState.getZoneKey(model) == zoneKey then
				table.insert(lines, ("  %s @(%.0f,%.1f,%.0f) 지면=%s 간격=%s %s"):format(model.Name, root.Position.X, root.Position.Y, root.Position.Z,
					groundY and ("%.2f"):format(groundY) or "없음", gap and ("%.2f"):format(gap) or "-", MonsterState.getAiState(model)))
			end
		end
	end
	reply(player, ("[접지] 전체 잡몹 중 땅속(<-0.3) %d, 공중(>0.3) %d\n%s"):format(sunk, floating, table.concat(lines, "\n")))
end

local HELP_TEXT = table.concat({
	"/gg anchor [classId] - 앵커 조건 적용(레벨100+일반itemLevel100 3부위+강화0+스테이지100)",
	"/gg level <n> - 캐릭터 레벨 직접 지정",
	"/gg gear <grade> <itemLevel> - 갑옷/장갑/신발 3부위 동일 조건으로 장착",
	"/gg additem <part> <grade> <itemLevel> - 잠기지 않은 아이템 1개를 인벤토리에 직접 추가(분해·판매 UI 클릭 검증용, part=armor/gloves/shoes)",
	"/gg enhance <n> - 무기 강화 단계 지정(0~" .. EnhanceConfig.maxLevel .. ")",
	"/gg weapon <n|등급명> - 무기 등급 지정(0~6 또는 " .. table.concat(ArmorData.gradeOrder, "/") .. ")",
	"/gg class <classId> - 직업 전환(greatsword/dualblade/bow/healer)",
	"/gg stage <n> - 무한 스테이지 지정(생존타수/보상 배율 계산용, 물리적 이동 아님)",
	"/gg measure [stage] - 지금 조건의 생존 타수·60초 총딜·처치 시간·권장 스테이지를 콘솔에 출력",
	"/gg curve - 레벨 1~125의 레벨당 목표 마릿수·실제 계산 마릿수·+25% 가정 마릿수 표를 콘솔에 출력(25-1)",
	"/gg curve anchor [classId] - 앵커 곡선(레벨×무기등급 격자)의 생존 타수·처치 시간 표를 콘솔에 출력(25-1 전엔 /gg curve)",
	"/gg curve migrate - v21 세이브 형태(옛 두 곡선)의 경험치를 migrate에 통과시켜 레벨·진행률 유지를 자체검증(25-1)",
	"/gg option table - 옵션 통합 등급별 구간표·레벨계수 동결·롤 분포(1000회)를 콘솔에 출력(26-1, PRD 20.67 [3] 대조용 - Option.lua는 아직 게임에 연결 안 됨)",
	"/gg option migrate - v22 세이브 형태(gem.optionId)의 보석을 migrate에 통과시켜 옵션 이관 규칙(20.67 [13])을 자체검증(26-1)",
	"/gg option set <슬롯1-5|armor|gloves|shoes> <옵션id|-> [등급] [min|mid|max|롤숫자] - 그 자리에 옵션을 강제 배정(26-2, 등급·롤 생략 시 기존값 유지)",
	"/gg option show - 옵션 8자리(장비3+보석5) 각각의 id·등급·롤·실제 수치 + 8축 합산(상한 적용됨)을 콘솔에 출력(26-2)",
	"/gg option lifesteal - 흡혈 초당 회복 실측(3초, 요청량을 maxHp×10으로 크게 잡아 상한이 실제로 잘리는지 확인, 20.67 [6-1])",
	"/gg option stack <id> - 장비3+보석5 전부를 태초·최대롤로 그 옵션 하나로 채운 뒤 /gg measure(26-3, PRD 20.67 [7] 표 재현)",
	"/gg rebirth <0-5> - 환생 횟수 강제 지정(무기 등급·보석 슬롯은 안 건드림, 보스 첫 처치 드랍 등급표 분기·슬롯 개방 표시 검증용)",
	"/gg rebirthdo - 실제 환생 실행(PlayerProfile.rebirth 그대로 - 레벨 조건 검증 + 무기 등급·보석 자동 지급까지 전체 흐름 검증용)",
	"/gg gem <slot 1-5> <id|-> - 그 슬롯에 보석을 강제로 채운다(23-2 검증용, id=-면 옵션 없이)",
	"/gg bossreset [stage] - 보스 첫 처치 확정 드랍 기록 초기화(생략 시 전부, 재검증용)",
	"/gg variant <sparkle|chest|frail|sturdy|giant|none> - 가장 가까운 잡몹을 그 변종으로 즉시 교체(22-2 검증용)",
	"/gg chesttest - 가장 가까운 잡몹을 상자로 바꾼 뒤 피격 간격·다중 타격자·기록 정리를 서버 로그로 검증(22-2)",
	"/gg killtest - 가장 가까운 잡몹을 실제 처치 경로(applyDamage→resolveHit)로 즉시 잡고 골드·경험치·드랍 변화를 로그로 출력(22-2)",
	"/gg boss [stage] - 보스 스테이지(기본 5)로 이동해 개인 아레나 보스전 시작(21-3 검증용)",
	"/gg boss next - 다음(또는 지금 대기 중인) 보스가 누구인지 출력(23-5)",
	"/gg boss history - 이 플레이어의 보스 등장 이력 출력(23-5)",
	"/gg boss force <id> - 다음 보스 순환 뽑기를 강제 지정(1회용, 23-5)",
	"/gg pattern <heavy|shockwave|meteor|charge|cross> - 지금 보스에게 그 패턴을 즉시 시작시킨다",
	"/gg bossinfo - 지금 보스 인스턴스의 주력 패턴·패턴별 간격·변형 필드·실루엣을 콘솔에 출력(23-6 검증용)",
	"/gg bossdmg <비율> - 지금 보스 HP를 최대치의 비율만큼 깎는다(사망 리셋 검증용, 예: 0.5)",
	"/gg bosskilltest - 지금 보스를 실제 처치 경로(applyDamage→resolveHit)로 즉시 잡는다(견습/무한 모드 처치 파이프라인 검증용, 23-1)",
	"/gg terrain [clear|cost|ground|drop|rules|parts] - tier1에 테스트 지형(고원·30°경사·계단·70°경사·절벽·도랑) 생성 / 제거 / 지면 Raycast 부하 실측 / 잡몹 접지 상태 / 발밑 시험 드랍(22-4) / 배치 규칙 강제 검증 / 파트 수 실측(22-5)",
	"/gg tutorial <0-7> - 견습 단계 강제 이동(0=미시작으로 리셋, 1~7=그 단계로 즉시 진입)",
	"/gg tutorial off - 견습 종료하고 무한 모드로 복귀(완료 처리)",
	"/gg party dummy <n> - 더미 파티원 n명을 붙인다(0이면 더미 제거) - 보스 HP 배수·HUD 검증용(24-1)",
	"/gg party info - 지금 파티 상태·입장 밴드·적용 중인 보스 HP 배수(N^p)·기여도를 콘솔에 출력(24-1)",
	"/gg party table [stage] - 1~4인 예상 보스 처치 시간표(지금 장비 + 앵커 4직업)를 콘솔에 출력(24-1)",
	"/gg party killsim [uptime] - 지금 보스를 봇 DPS(로테이션 총딜×uptime×인원)로 실시간 처치해 시간을 잰다(24-1, 기본 uptime 0.65)",
	"/gg party selftest - 스탠드인(가짜 Player) 3명으로 결성·만원·추방·승계·해산·접속종료·보스전 중 이탈·기여도 제외를 서버 로그로 검증(24-1)",
	"/gg party server - 현재 서버 jobId·인원·플랫폼 정원·크로스서버 상한·파티/코드/원격 좌석/합류 대기 상태 출력(24-2)",
	"/gg party join <code> - 텔레포트 없이 코드 합류 파이프라인(레코드·좌석·대기·도착 처리)만 밟아 파티 상태를 붙인다(24-2, Studio는 TeleportService 불가)",
	"/gg party fakeremote [boss|full|clear] - 다른 서버에 있는 것처럼 꾸민 가짜 파티 레코드를 MemoryStore에 쓴다(코드 출력) - boss=보스전 중, full=서버 정원 초과(24-2)",
	"/gg heal buff - 힐러 버프(파티 최종피해 +b, b=N/(N-1+r)-1)의 현재 b·r값과 내게 걸린 버프의 남은 시간을 출력(24-3, b 재도출 24-4)",
	"/gg party xtest - 크로스서버 규칙 자체검증 16항목: 코드 발급·로컬 코드 합류·동시 좌석 예약·만원·텔레포트 실패 회수·두 파티 동시 합류 차단·보스전 대기·정원 대기·취소·해산 도착·보스전 중 도착 보류·승계·해산(24-2)",
	"/gg reset - 백업된 원본 프로필로 복원 + 저장 차단 해제",
	"/gg save unlock - 원본 복원 없이 저장 차단만 영구 해제(백업 삭제, 지금 상태가 실제로 저장됨) - 재접속 지속성 검증 전용, 기본은 차단 유지(23-6)",
}, "\n")

local function handleCommand(player, args)
	local sub = args[1]

	if sub == "help" or sub == nil then
		reply(player, "\n" .. HELP_TEXT)
	elseif sub == "anchor" then
		applyAnchor(player, args[2])
	elseif sub == "level" and tonumber(args[2]) then
		ensureBackup(player)
		applyLevel(player, math.floor(tonumber(args[2])))
		reply(player, "레벨 " .. args[2] .. " 적용")
	elseif sub == "gear" and args[2] and tonumber(args[3]) then
		ensureBackup(player)
		if applyGear(player, args[2], math.floor(tonumber(args[3]))) then
			reply(player, ("장비 3부위를 %s등급 itemLevel%s로 적용"):format(args[2], args[3]))
		end
	elseif sub == "additem" and args[2] and args[3] and tonumber(args[4]) then
		ensureBackup(player)
		if applyAddItem(player, args[2], args[3], math.floor(tonumber(args[4]))) then
			reply(player, ("인벤토리에 %s %s등급 itemLevel%s 추가"):format(args[2], args[3], args[4]))
		else
			reply(player, "실패(인벤토리 가득 또는 잘못된 등급)")
		end
	elseif sub == "enhance" and tonumber(args[2]) then
		ensureBackup(player)
		applyEnhance(player, math.floor(tonumber(args[2])))
		reply(player, "무기 강화 +" .. args[2] .. " 적용")
	elseif sub == "weapon" and args[2] then
		ensureBackup(player)
		if applyWeaponGrade(player, args[2]) then
			reply(player, "무기 등급 " .. args[2] .. " 적용")
		end
	elseif sub == "class" and args[2] then
		ensureBackup(player)
		if applyClass(player, args[2]) then
			reply(player, "직업 " .. args[2] .. "로 전환")
		end
	elseif sub == "stage" and tonumber(args[2]) then
		ensureBackup(player)
		applyStage(player, math.floor(tonumber(args[2])))
		reply(player, "무한 스테이지 " .. args[2] .. " 적용")
	elseif sub == "measure" then
		measure(player, tonumber(args[2]))
	elseif sub == "curve" and args[2] == "anchor" then
		printCurve(player, args[3])
	elseif sub == "curve" and args[2] == "migrate" then
		runMigrateSelfTest(player)
	elseif sub == "curve" then
		printLevelCurve(player)
	elseif sub == "option" and args[2] == "table" then
		printOptionTable(player)
	elseif sub == "option" and args[2] == "migrate" then
		runOptionMigrateSelfTest(player)
	elseif sub == "option" and args[2] == "set" and args[3] and args[4] then
		ensureBackup(player)
		local success, reason = applyOptionSet(player, args[3], args[4], args[5], args[6])
		if success then
			reply(player, ("옵션 배정 완료: %s = %s%s%s"):format(
				args[3], args[4], args[5] and (" " .. args[5]) or "", args[6] and (" roll=" .. args[6]) or ""))
		else
			reply(player, "실패: " .. tostring(reason))
		end
	elseif sub == "option" and args[2] == "show" then
		printOptionShow(player)
	elseif sub == "option" and args[2] == "lifesteal" then
		runLifestealSelfTest(player)
	elseif sub == "option" and args[2] == "stack" and args[3] then
		ensureBackup(player)
		local success, reason = applyOptionStack(player, args[3])
		if success then
			reply(player, ("옵션 8개 몰빵 완료(태초·최대롤): %s"):format(args[3]))
			measure(player)
		else
			reply(player, "실패: " .. tostring(reason))
		end
	elseif sub == "rebirth" and tonumber(args[2]) then
		ensureBackup(player)
		local applied = applyRebirth(player, math.floor(tonumber(args[2])))
		reply(player, "환생 횟수(스텁) " .. applied .. " 적용")
	elseif sub == "rebirthdo" then
		ensureBackup(player)
		local success, reasonOrCount, requiredLevel = PlayerProfile.rebirth(player)
		if success then
			reply(player, ("환생 실행 성공 - rebirthCount %d"):format(reasonOrCount))
		else
			reply(player, ("환생 실행 실패 - %s%s"):format(reasonOrCount, requiredLevel and (" (필요 레벨 " .. requiredLevel .. ")") or ""))
		end
	elseif sub == "gem" and tonumber(args[2]) and args[3] then
		ensureBackup(player)
		local success, reason = applyGemSlot(player, math.floor(tonumber(args[2])), args[3])
		if success then
			reply(player, ("보석 슬롯 %s 강제 지정 완료(id=%s)"):format(args[2], args[3]))
		else
			reply(player, "실패: " .. tostring(reason))
		end
	elseif sub == "boss" and args[2] == "next" then
		-- 23-5 검증용 - 순환 알고리즘을 실제로 호출하지 않고(=뽑지 않고) 지금 상태만 읽는다.
		-- pending이 있으면 그게 다음 진입에서 나올 확정값, 없으면 order[index]가 "정상
		-- 순환대로면" 다음에 뽑힐 후보다(디버그 강제(force)가 걸려 있으면 그게 우선한다는
		-- 사실도 같이 보여준다 - PlayerProfile.getBossForStage와 같은 우선순위).
		local rotation = PlayerProfile.getBossRotationInfo(player)
		if not rotation then
			reply(player, "직업을 먼저 선택해야 합니다")
		elseif rotation.debugForceNextId then
			reply(player, ("다음 보스(강제 지정됨): %s"):format(rotation.debugForceNextId))
		elseif rotation.pending then
			reply(player, ("다음 보스(이미 확정, 스테이지 %d 대기 중): %s"):format(rotation.pending.stage, rotation.pending.bossId))
		elseif rotation.order and rotation.order[rotation.index] then
			reply(player, ("다음 보스(순환 예정, %d/%d번째): %s"):format(
				rotation.index, #rotation.order, rotation.order[rotation.index]))
		else
			reply(player, "다음 보스: 아직 안 뽑음(첫 진입 때 새로 섞습니다)")
		end
	elseif sub == "boss" and args[2] == "history" then
		local rotation = PlayerProfile.getBossRotationInfo(player)
		if not rotation then
			reply(player, "직업을 먼저 선택해야 합니다")
		elseif not rotation.history or #rotation.history == 0 then
			reply(player, "보스 이력 없음(아직 한 번도 등장 확정 안 됨)")
		else
			reply(player, ("보스 이력(%d회, 오래된 순): %s"):format(#rotation.history, table.concat(rotation.history, " -> ")))
		end
	elseif sub == "boss" and args[2] == "force" and args[3] then
		if PlayerProfile.forceBossRotationNext(player, args[3]) then
			reply(player, ("다음 보스를 강제 지정했습니다: %s (다음 보스 스테이지 진입 시 적용, 정상 순환은 그대로 보존됨)"):format(args[3]))
		else
			reply(player, "실패: 직업 미선택 또는 알 수 없는 보스 id " .. args[3])
		end
	elseif sub == "boss" then
		ensureBackup(player)
		local stage = tonumber(args[2]) and math.floor(tonumber(args[2])) or BossData.stageInterval
		if not BossRules.isBossStage(stage) then
			reply(player, ("스테이지 %d은(는) 보스 스테이지가 아닙니다(%d의 배수)"):format(stage, BossData.stageInterval))
			return
		end
		BossEncounter.despawnFor(player)
		applyStage(player, stage)
		-- 24-1: 파티 리더면 파티 보스(멤버 전원 텔레포트 + N^p HP). 입장 검사는 검증 편의상
		-- 우회하되 결과는 찍는다 - 실제 경로(StageServer)는 막힌다.
		local party = PartyState.getParty(player)
		if party and PartyState.isLeader(player) then
			local blocked = BossEncounter.checkPartyEntry(party, stage)
			for _, entry in ipairs(blocked) do
				reply(player, ("  (검사) %s 막힘: %s - DevTools라 우회"):format(entry.player.Name, entry.reason))
			end
			BossEncounter.spawnForParty(party, player, stage)
			reply(player, ("파티 보스 스테이지 %d 진입 - 인원 %d, HP 배수 %.3f"):format(
				stage, PartyState.getSize(party), BossRules.partySizeHpMultiplier(PartyState.getSize(party))))
		else
			BossEncounter.spawnFor(player, stage)
			reply(player, ("보스 스테이지 %d 진입 - 아레나로 이동"):format(stage))
		end
	elseif sub == "pattern" and args[2] then
		local model = BossEncounter.getActive(player)
		local data = model and MonsterState.getData(model)
		if not data then
			reply(player, "활성 보스가 없습니다(/gg boss 먼저)")
		elseif BossPatterns.force(model, data, args[2]) then
			reply(player, "패턴 강제 시작: " .. args[2])
		else
			reply(player, "알 수 없는 패턴: " .. args[2])
		end
	elseif sub == "bossdmg" and tonumber(args[2]) then
		local model = BossEncounter.getActive(player)
		local data = model and MonsterState.getData(model)
		if not data then
			reply(player, "활성 보스가 없습니다(/gg boss 먼저)")
		else
			MonsterState.applyDamage(model, data.hp * tonumber(args[2]), TutorialState.getMonsterStage(player), player)
			MonsterSpawner.updateHpLabel(model)
			reply(player, ("보스 HP %.0f%% 차감 - 남은 비율 %.2f"):format(tonumber(args[2]) * 100, MonsterState.getHpRatio(model)))
		end
	elseif sub == "tutorialstatus" then
		-- 23-1 검증용 - execute_luau는 PlayerProfile을 직접 require하지 못해(별개 인스턴스가
		-- 생긴다) 내부 상태를 못 읽는다 - 이 스크립트는 이미 로드된 실제 인스턴스를 갖고
		-- 있으니 그 상태를 콘솔로 노출한다.
		local weapon = PlayerProfile.getWeapon(player)
		local parts = {}
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			local item = PlayerProfile.getEquipped(player, part)
			table.insert(parts, ("%s=%s"):format(part, item and item.grade or "none"))
		end
		local baseline = PlayerProfile.getTutorialLendBaseline(player)
		reply(player, ("step=%s completed=%s weaponGrade=%d %s lendBaseline=%s"):format(
			tostring(PlayerProfile.getTutorialStep(player)), tostring(PlayerProfile.getTutorialCompleted(player)),
			weapon.grade, table.concat(parts, " "), baseline and ("weaponGrade=" .. baseline.weaponGrade) or "nil"))
	elseif sub == "bosskilltest" then
		-- 23-1 검증용 - /gg bossdmg는 사망 리셋(플레이어 사망) 검증 전용이라 HP를 0으로
		-- 만들어도 CombatResolution.resolveHit(처치 처리)을 부르지 않는다(killtest와 같은
		-- 이유로, 실제 클릭 평타 없이도 견습/무한 모드 보스 처치 파이프라인 전체를 검증하려면
		-- 이 경로가 필요하다).
		local model = BossEncounter.getActive(player)
		local data = model and MonsterState.getData(model)
		if not data then
			reply(player, "활성 보스가 없습니다")
		else
			local isDead = MonsterState.applyDamage(model, data.hp * 10, TutorialState.getMonsterStage(player), player)
			MonsterSpawner.updateHpLabel(model)
			CombatResolution.resolveHit(player, model, isDead)
			reply(player, "bosskilltest 완료 - 서버 로그 참고")
		end
	elseif sub == "variant" and args[2] then
		-- 가장 가까운 잡몹(보스·상자 제외)을 보상 없이 지우고 같은 자리에 지정 변종으로 다시
		-- 스폰한다. 저장에 손대지 않으므로 ensureBackup이 필요 없다.
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end
		local kind = args[2]
		local forced
		if kind == "sparkle" then
			forced = { isSparkle = true }
		elseif kind == "chest" then
			forced = { isChest = true }
		elseif kind == "none" then
			forced = {}
		elseif MonsterPrefixData.byId[kind] then
			forced = { prefix = MonsterPrefixData.byId[kind] }
		else
			reply(player, "알 수 없는 변종: " .. kind)
			return
		end
		local nearest, nearestDist = nil, math.huge
		for _, model in ipairs(MonsterState.getAllModels()) do
			local data = MonsterState.getData(model)
			if data and not data.isBoss and not data.isChest and model.PrimaryPart then
				local d = (model.PrimaryPart.Position - rootPart.Position).Magnitude
				if d < nearestDist then
					nearest, nearestDist = model, d
				end
			end
		end
		if not nearest then
			reply(player, "근처에 잡몹이 없습니다")
			return
		end
		local data = MonsterState.getData(nearest)
		local spawnPosition = MonsterState.getSpawnPosition(nearest)
		local zoneKey = MonsterState.getZoneKey(nearest)
		MonsterState.tryClaimDeath(nearest)
		MonsterState.clear(nearest)
		nearest:Destroy()
		local model = MonsterSpawner.spawn(data, spawnPosition, zoneKey, forced)
		reply(player, ("변종 스폰: %s (%s)"):format(model.Name, kind))
	elseif sub == "chesttest" then
		-- 22-2 [3] 검증: 실제 MonsterState.applyDamage/CombatResolution.resolveHit 경로로 (1) 1초
		-- 안의 연타는 1회만 세는지, (2) 서로 다른 타격자 키가 각자 따로 세어지는지, (3) 퇴장
		-- 정리(clearPlayerContributions)가 기록을 지우는지, (4) 파괴 후 entry가 사라지는지를
		-- 로그로 찍는다. 두 번째 타격자는 Player가 아닌 스탠드인 테이블(Parent=nil)이라 파괴
		-- 보상 루프의 Parent 가드에 걸러진다 - 그 가드가 실제로 동작하는지도 같이 본다.
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end
		local nearest, nearestDist = nil, math.huge
		for _, model in ipairs(MonsterState.getAllModels()) do
			local data = MonsterState.getData(model)
			if data and not data.isBoss and not data.isChest and model.PrimaryPart then
				local d = (model.PrimaryPart.Position - rootPart.Position).Magnitude
				if d < nearestDist then
					nearest, nearestDist = model, d
				end
			end
		end
		if not nearest then
			reply(player, "근처에 잡몹이 없습니다")
			return
		end
		local data = MonsterState.getData(nearest)
		local spawnPosition = MonsterState.getSpawnPosition(nearest)
		local zoneKey = MonsterState.getZoneKey(nearest)
		MonsterState.tryClaimDeath(nearest)
		MonsterState.clear(nearest)
		nearest:Destroy()
		local chest = MonsterSpawner.spawn(data, spawnPosition, zoneKey, { isChest = true })
		local stage = TutorialState.getMonsterStage(player)
		local function hitters()
			local n = 0
			for _ in pairs(MonsterState.getChestHitters(chest)) do
				n += 1
			end
			return n
		end
		task.spawn(function()
			-- (1) 연타 20회를 0.05초 간격으로 - 유효 피격은 1회여야 한다.
			for _ = 1, 20 do
				MonsterState.applyDamage(chest, 999, stage, player)
				task.wait(0.05)
			end
			MonsterSpawner.updateHpLabel(chest)
			-- 20회 × 0.05초 ≈ 1.0~1.2초라 1초 경계를 한 번 넘는다 - 유효 피격은 1~2회.
			print(("[chesttest] 연타 20회(약 1.1초) 후 HP비율 %.4f (기대 %.4f~%.4f = 1~2회만 인정), 타격자 %d명"):format(
				MonsterState.getHpRatio(chest), 1 - 2 / 15, 1 - 1 / 15, hitters()))

			-- (2) 스탠드인 타격자 - 같은 시각에 때려도 자기 간격은 따로 센다.
			local standIn = { Name = "StandIn", Parent = nil }
			MonsterState.applyDamage(chest, 1, stage, standIn)
			print(("[chesttest] 스탠드인 1타 후 HP비율 %.4f (직전보다 1/15 감소), 타격자 %d명(기대 2)"):format(
				MonsterState.getHpRatio(chest), hitters()))

			-- (3) 퇴장 정리 - 스탠드인 기록을 지우면 타격자 1명으로 돌아가야 한다.
			MonsterState.clearPlayerContributions(standIn)
			print(("[chesttest] 스탠드인 정리 후 타격자 %d명(기대 1)"):format(hitters()))

			-- (4) 혼자 1초 간격으로 남은 13회 - 첫 유효 피격부터 파괴까지 걸린 시간.
			local startedAt = os.clock() - 20 * 0.05
			local isDead = false
			while not isDead do
				task.wait(1.0)
				isDead = MonsterState.applyDamage(chest, 999, stage, player)
				MonsterSpawner.updateHpLabel(chest)
			end
			local elapsed = os.clock() - startedAt
			CombatResolution.resolveHit(player, chest, isDead)
			print(("[chesttest] 혼자 파괴까지 %.1f초 (기대 ≥ 14초 = 15타 사이 14간격), 파괴 후 entry=%s"):format(
				elapsed, tostring(MonsterState.getData(chest))))
		end)
		reply(player, "chesttest 시작 - 서버 로그를 보세요(약 15초)")
	elseif sub == "killtest" then
		-- 22-2 검증: 잡몹 처치 경로(MonsterState.applyDamage → CombatResolution.resolveHit →
		-- grantKillReward → ItemDropSpawner)가 변종 배율을 포함해 그대로 동작하는지. 평타
		-- 입력(AttackRequest)만 건너뛴다 - 그 파일의 이번 변경은 꽂히는 화살의 상자 가드 한 줄뿐.
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not rootPart then
			return
		end
		local nearest, nearestDist = nil, math.huge
		for _, model in ipairs(MonsterState.getAllModels()) do
			local data = MonsterState.getData(model)
			if data and not data.isBoss and not data.isChest and model.PrimaryPart then
				local d = (model.PrimaryPart.Position - rootPart.Position).Magnitude
				if d < nearestDist then
					nearest, nearestDist = model, d
				end
			end
		end
		if not nearest then
			reply(player, "근처에 잡몹이 없습니다")
			return
		end
		local prefix = MonsterState.getPrefix(nearest)
		local wasSparkle = MonsterState.isSparkle(nearest) -- resolveHit이 entry를 지우므로 미리 읽는다
		local goldBefore = player:GetAttribute("Gold")
		local expBefore = player:GetAttribute("CharacterExp")
		local dropsBefore = 0
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name == "ItemDrop" then
				dropsBefore += 1
			end
		end
		local stage = TutorialState.getMonsterStage(player)
		local isDead = MonsterState.applyDamage(nearest, 1e12, stage, player)
		MonsterSpawner.updateHpLabel(nearest)
		CombatResolution.resolveHit(player, nearest, isDead)
		local dropsAfter = 0
		for _, c in ipairs(workspace:GetChildren()) do
			if c.Name == "ItemDrop" then
				dropsAfter += 1
			end
		end
		print(("[killtest] %s (접두사=%s, 반짝이=%s) 처치 - 골드 %d→%d (+%d), 경험치 %d→%d (+%d), 드랍 +%d"):format(
			nearest.Name, prefix and prefix.id or "없음", tostring(wasSparkle),
			goldBefore, player:GetAttribute("Gold"), player:GetAttribute("Gold") - goldBefore,
			expBefore, player:GetAttribute("CharacterExp"), player:GetAttribute("CharacterExp") - expBefore,
			dropsAfter - dropsBefore))
		reply(player, "killtest 완료 - 서버 로그 참고")
	elseif sub == "terrain" then
		if args[2] == "clear" then
			clearTestTerrain(player)
		elseif args[2] == "cost" then
			reportProbeCost(player)
		elseif args[2] == "ground" then
			reportMonsterGrounding(player, args[3])
		elseif args[2] == "rules" then
			reportTerrainRules(player)
		elseif args[2] == "parts" then
			reportPartCounts(player)
		elseif args[2] == "drop" then
			-- 지금 서 있는 자리(루트 위치 = 지면보다 약 3 위)에 시험 드랍을 떨어뜨린다 - 경사면·고원
			-- 위에서 스냅 Y를 확인한다(ItemDropSpawner.spawn이 지면으로 내린다).
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local model = ItemDropSpawner.spawn(buildGearItem("armor", "normal", 1, 1), root.Position, player)
				task.delay(ItemDropSpawner.bounceSeconds + 0.1, function()
					if model.Parent and model.PrimaryPart then
						local p = model.PrimaryPart.Position
						local groundY = GroundProbe.surfaceY(p.X, p.Z, p.Y)
						reply(player, ("시험 드랍 정지 위치 (%.1f, %.2f, %.1f) / 지면 %s / 지면 위 %.2f"):format(p.X, p.Y, p.Z,
							groundY and ("%.2f"):format(groundY) or "없음", groundY and (p.Y - groundY) or -1))
					end
				end)
			end
		else
			buildTestTerrain(player)
		end
	elseif sub == "tutorial" and args[2] then
		ensureBackup(player)
		if args[2] == "off" then
			TutorialState.stop(player, true)
			reply(player, "견습 종료 - 완료 처리, 무한 모드로 복귀")
		elseif tonumber(args[2]) and tonumber(args[2]) >= 0 and tonumber(args[2]) <= TutorialData.stepCount then
			local step = math.floor(tonumber(args[2]))
			if step == 0 then
				TutorialState.stop(player, false)
				PlayerProfile.setTutorialStep(player, 0)
				PlayerProfile.setTutorialCompleted(player, false)
				reply(player, "견습 진행도 초기화(0=미시작)")
			else
				TutorialState.stop(player, false) -- 이전 대여가 있었으면 먼저 반납
				PlayerProfile.setTutorialCompleted(player, false)
				TutorialState.start(player, step)
				reply(player, ("견습 %d단계로 강제 이동"):format(step))
			end
		else
			reply(player, "사용법: /gg tutorial <0-7> 또는 /gg tutorial off")
		end
	elseif sub == "bossinfo" then
		-- 23-6 검증 전용 - 지금 아레나의 보스 인스턴스 데이터(패턴 간격·변형 필드·실루엣)를
		-- 콘솔에 찍는다. execute_luau가 ModuleScript require를 capability 오류로 막아
		-- BossData를 직접 못 읽으므로, 실제로 스폰된 인스턴스에서 값을 그대로 읽는다.
		local model = BossEncounter.getActive(player)
		local d = model and MonsterState.getData(model)
		if not d then
			reply(player, "지금 진행 중인 보스가 없습니다")
		else
			reply(player, ("%s primary=%s heavyInterval=%.3f telegraph=%.3f aspect=(%.2f,%.2f,%.2f) attachments=%d"):format(
				d.id, tostring(d.primaryPattern), d.heavyAttackIntervalSeconds, d.telegraphWarmupSeconds,
				d.bodyAspect.X, d.bodyAspect.Y, d.bodyAspect.Z, #d.attachments))
			reply(player, ("  shockwave interval=%.3f mul=%s layers=%s gap=%s"):format(
				d.patterns.shockwave.intervalSeconds, tostring(d.patterns.shockwave.damageMultiplier),
				tostring(d.patterns.shockwave.layers), tostring(d.patterns.shockwave.layerGapSeconds)))
			reply(player, ("  charge interval=%.3f dashCount=%s frac=%s"):format(
				d.patterns.charge.intervalSeconds, tostring(d.patterns.charge.dashCount), tostring(d.patterns.charge.damageMaxHpFraction)))
			reply(player, ("  meteor interval=%.3f count=%s radius=%s"):format(
				d.patterns.meteor.intervalSeconds, tostring(d.patterns.meteor.count), tostring(d.patterns.meteor.radiusStuds)))
			reply(player, ("  cross interval=%.3f rotates=%s"):format(
				d.patterns.cross.intervalSeconds, tostring(d.patterns.cross.rotates)))
		end
	elseif sub == "bossreset" then
		ensureBackup(player)
		PlayerProfile.clearBossFirstClearRewards(player, tonumber(args[2]))
		reply(player, args[2] and ("스테이지 " .. args[2] .. " 첫 처치 기록 초기화") or "첫 처치 기록 전부 초기화")
	elseif sub == "save" and args[2] == "unlock" then
		-- 23-6 [4]: "/gg reset"과 달리 원본으로 되돌리지 않는다 - 지금(테스트로 바뀐) 상태를
		-- 그대로 "정상 상태"로 승격시켜 실제 저장이 되게 한다. backups[player]를 지워야
		-- PlayerRemoving 핸들러(아래)가 나갈 때 자동으로 restore()를 불러 이 상태를 도로
		-- 덮어쓰는 일이 없다 - "재접속 후에도 유지되는가"를 검증하려면 원본 복원 안전장치
		-- 자체를 반드시 꺼야 한다(기본값은 여전히 차단 유지 - 이 명령을 쓸 때만 해제된다).
		if not backups[player] then
			reply(player, "저장 차단 상태가 아닙니다(백업 없음) - 이미 정상 저장 중입니다")
		else
			backups[player] = nil
			SaveCoordinator.setDevToolsSuspended(player, false)
			SaveCoordinator.saveForPlayer(player)
			reply(player, "저장 차단 해제 - 지금 상태(테스트 값 포함)가 실제로 저장됩니다. 원본 복원 불가(백업 삭제됨, 재접속 지속성 검증 전용)")
		end
	elseif sub == "party" and args[2] == "dummy" and tonumber(args[3]) then
		local n = math.floor(tonumber(args[3]))
		if n <= 0 then
			reply(player, ("더미 %d명 제거"):format(PartyState.clearDummies(player)))
		else
			local level = PlayerProfile.getCharacterLevel(player) or 1
			local stage = PlayerProfile.getInfiniteStage(player) or 1
			local ok, added = PartyState.addDummies(player, n, function(index)
				return { classId = ClassData.order[(index - 1) % #ClassData.order + 1], level = level, stage = stage, hp = 1, maxHp = 1 }
			end)
			if ok then
				local party = PartyState.getParty(player)
				reply(player, ("더미 %d명 추가 - 파티 인원 %d/%d, 다음 보스 HP 배수 %.3f (p=%.4f)"):format(
					added, PartyState.getSize(party), PartyConfig.maxMembers,
					BossRules.partySizeHpMultiplier(PartyState.getSize(party)), BossRules.partyHpExponent()))
			else
				reply(player, "실패: " .. tostring(added))
			end
		end
	elseif sub == "party" and args[2] == "info" then
		local p = BossRules.partyHpExponent()
		reply(player, ("p = 1 - stageInterval(%d) × ln(k=%.3f) / ln(maxMembers=%d) = %.4f | N^p: 1→%.3f 2→%.3f 3→%.3f 4→%.3f"):format(
			BossData.stageInterval, InfiniteStageConfig.growthRate, PartyConfig.maxMembers, p,
			BossRules.partySizeHpMultiplier(1), BossRules.partySizeHpMultiplier(2), BossRules.partySizeHpMultiplier(3), BossRules.partySizeHpMultiplier(4)))
		local level = PlayerProfile.getCharacterLevel(player) or 1
		reply(player, ("내 입장 밴드: 레벨 %d → 권장 %d + band %d = 보스 스테이지 ≤ %d"):format(
			level, BalanceSim.recommendedStage(level, 0, false), BossRules.partyEntryBand(), BossRules.partyEntryStageCap(level)))
		local party = PartyState.getParty(player)
		if not party then
			reply(player, "파티 없음")
		else
			local names = {}
			for _, record in ipairs(PartyState.getMemberRecords(party)) do
				table.insert(names, ("%s%s%s"):format(record.name, record.isDummy and "(더미)" or "", record == party.leader and "★" or ""))
			end
			reply(player, ("파티 #%d 인원 %d/%d [%s] 리더=%s"):format(party.id, PartyState.getSize(party), PartyConfig.maxMembers,
				table.concat(names, ", "), tostring(PartyState.getLeader(party) and PartyState.getLeader(party).Name)))
		end
		local encounter = BossEncounter.getEncounter(player)
		if not encounter then
			reply(player, "활성 보스전 없음")
		else
			local hp, maxHp = MonsterState.getBossHp(encounter.model)
			local memberNames = {}
			for _, member in ipairs(encounter.members) do
				table.insert(memberNames, member.Name)
			end
			reply(player, ("보스전: 스테이지 %d, 입장 인원 %d(실제 %d: %s), 적용 HP 배수 %.3f, 보스 HP %.0f/%.0f (솔로 기준 %.0f), 생존 %d명, 순환 소모=%s"):format(
				encounter.stage, encounter.size, #encounter.members, table.concat(memberNames, ","),
				encounter.data.partyHpMultiplier or 1, hp or 0, maxHp or 0, (maxHp or 0) / (encounter.data.partyHpMultiplier or 1),
				BossEncounter.livingMemberCount(encounter), encounter.rotationOwner and encounter.rotationOwner.Name or "-"))
			local contrib = {}
			for member, ratio in pairs(MonsterState.getContributors(encounter.model)) do
				table.insert(contrib, ("%s=%.1f%%"):format(member.Name, ratio * 100))
			end
			reply(player, "기여도: " .. (#contrib > 0 and table.concat(contrib, " ") or "없음"))
		end
	elseif sub == "party" and args[2] == "table" then
		-- 1~4인 예상 처치 시간표. 보스 HP(N) = trashHp(S)×20×N^p, 파티 DPS = N × (60초 로테이션
		-- 총딜/60) × uptime(회피 35% → 0.65, PRD 20.44 (가)). T_N = HP(N) / DPS_N.
		local stage = tonumber(args[3]) and math.floor(tonumber(args[3])) or (PlayerProfile.getInfiniteStage(player) or 1)
		local uptime = 0.65
		local p = BossRules.partyHpExponent()
		local trashHp = BalanceSim.getMonsterHp(stage)
		local bossSoloHp = trashHp * BossData.bosses[BossData.pools[1].bossIds[1]].hpMultiplier
		local function rowFor(label, loadout)
			local rotation = BalanceSim.simulateCombat(loadout, { useSkills = true })
			local dps = rotation.totalDamage / 60
			local parts = {}
			for n = 1, PartyConfig.maxMembers do
				local hp = bossSoloHp * (n ^ p)
				local pure = hp / (n * dps)
				table.insert(parts, ("%d인 %.1f초(순딜 %.1f)"):format(n, pure / uptime, pure))
			end
			reply(player, ("%s DPS=%.1f/s: %s"):format(label, dps, table.concat(parts, " | ")))
		end
		reply(player, ("=== 예상 처치 시간표 (스테이지 %d, 보스 솔로 HP %.0f, p=%.4f, uptime %.2f) ==="):format(stage, bossSoloHp, p, uptime))
		local classId = PlayerProfile.getClassId(player)
		if classId then
			local weapon = PlayerProfile.getWeapon(player)
			local equipment = { armor = PlayerProfile.getEquipped(player, "armor"), gloves = PlayerProfile.getEquipped(player, "gloves"), shoes = PlayerProfile.getEquipped(player, "shoes") }
			rowFor(("[지금 장비 %s L%d]"):format(classId, PlayerProfile.getCharacterLevel(player) or 1),
				BalanceSim.buildLoadoutFromEquipment(classId, PlayerProfile.getCharacterLevel(player) or 1, weapon.level, weapon.grade, equipment, weapon.gems))
		end
		for _, id in ipairs(ClassData.order) do
			rowFor(("[앵커 %s L%d g0]"):format(id, stage), BalanceSim.buildAnchorLoadout(id, stage, 0))
		end
	elseif sub == "party" and args[2] == "selftest" then
		-- 24-1 검증: Studio 단일 클라이언트로는 실제 2~4인 파티를 못 만든다 - chesttest의 standIn과 같은
		-- 기법으로 Player 필드(Name/UserId/Parent)만 흉내 낸 테이블 3개를 멤버로 넣어 PartyState·
		-- BossEncounter의 규칙을 실제 코드 경로로 돌린다. 스탠드인은 캐릭터·프로필이 없어 텔레포트·
		-- 피격·보상 대상에서 자연히 빠지므로(각 모듈의 nil 가드가 그대로 동작하는지도 함께 본다),
		-- 보상 검사는 "기여 10% 미만 제외" 경로만 스탠드인으로 밟고 실제 지급은 이 플레이어가 받는다.
		if PartyState.getParty(player) then
			reply(player, "먼저 파티를 나가세요(/gg party dummy 0 또는 탈퇴)")
			return
		end
		ensureBackup(player)
		local function standIn(name, userId)
			return { Name = name, UserId = userId, Parent = workspace, Character = nil }
		end
		local B, C, D, E = standIn("StandInB", -9001), standIn("StandInC", -9002), standIn("StandInD", -9003), standIn("StandInE", -9004)
		local results = {}
		local function check(label, ok)
			table.insert(results, ("%s %s"):format(ok and "O" or "X", label))
		end
		local function sizeOf()
			return PartyState.getSize(PartyState.getParty(player) or PartyState.getParty(B) or PartyState.getParty(C))
		end
		-- S1 결성(초대→수락) 2인
		local ok = PartyState.invite(player, B)
		local ok2, why = PartyState.respondInvite(B, true)
		check(("S1 결성 2인: invite=%s accept=%s(%s) size=%d leader=%s"):format(tostring(ok), tostring(ok2), tostring(why), sizeOf(), tostring(PartyState.isLeader(player))),
			ok and ok2 and sizeOf() == 2 and PartyState.isLeader(player))
		-- S2 리더 아닌 사람의 초대
		local _, r2 = PartyState.invite(B, C)
		check("S2 파티원 초대 거부: " .. tostring(r2), r2 == "not_leader")
		-- S3 3·4인
		PartyState.invite(player, C); PartyState.respondInvite(C, true)
		PartyState.invite(player, D); PartyState.respondInvite(D, true)
		check("S3 4인 결성: size=" .. sizeOf(), sizeOf() == 4)
		-- S4 만원 초대
		local _, r4 = PartyState.invite(player, E)
		check("S4 만원 초대 거부: " .. tostring(r4), r4 == "party_full")
		-- S5 추방
		local k5 = PartyState.kick(player, D.UserId)
		check(("S5 추방: %s size=%d"):format(tostring(k5), sizeOf()), k5 and sizeOf() == 3)
		-- S6 리더 이탈 → 최고참 승계
		PartyState.leave(player, "leave")
		local partyB = PartyState.getParty(B)
		check(("S6 리더 이탈 승계: 새 리더=%s size=%d 나=%s"):format(tostring(partyB and PartyState.getLeader(partyB) and PartyState.getLeader(partyB).Name), partyB and PartyState.getSize(partyB) or 0, tostring(PartyState.getParty(player))),
			partyB ~= nil and PartyState.getLeader(partyB) == B and PartyState.getSize(partyB) == 2 and PartyState.getParty(player) == nil)
		-- S7 1명 남으면 해산
		PartyState.leave(C, "leave")
		check("S7 1명 남아 해산: B파티=" .. tostring(PartyState.getParty(B)), PartyState.getParty(B) == nil)
		-- S8 접속 종료
		PartyState.invite(player, B); PartyState.respondInvite(B, true)
		PartyState.invite(player, C); PartyState.respondInvite(C, true)
		PartyState.leave(C, "disconnect")
		check("S8 접속 종료 처리: size=" .. sizeOf(), sizeOf() == 2)
		-- S9 보스전 중 이탈 - HP·배수 고정, 기여 10% 미만 제외
		BossEncounter.despawnFor(player)
		local stage = BossData.stageInterval * 20 -- 100
		applyStage(player, stage)
		local party = PartyState.getParty(player)
		BossEncounter.spawnForParty(party, player, stage)
		local encounter = BossEncounter.getEncounter(player)
		local model = encounter and encounter.model
		local _, maxHpBefore = MonsterState.getBossHp(model)
		local mult = encounter and encounter.data.partyHpMultiplier or 0
		MonsterState.applyDamage(model, maxHpBefore * 0.05, stage, B) -- B 5% (제외돼야 한다)
		MonsterState.applyDamage(model, maxHpBefore * 0.30, stage, player)
		PartyState.leave(B, "disconnect") -- 보스전 도중 접속 끊김
		local hpAfter, maxHpAfter = MonsterState.getBossHp(model)
		local enc2 = BossEncounter.getEncounter(player)
		check(("S9a 보스전 중 이탈: 배수 %.3f(기대 1.395) 최대HP 유지=%s 남은HP=%.0f%% 멤버=%d 입장인원=%d"):format(
			mult, tostring(maxHpAfter == maxHpBefore), hpAfter / maxHpAfter * 100, enc2 and #enc2.members or 0, enc2 and enc2.size or 0),
			math.abs(mult - BossRules.partySizeHpMultiplier(2)) < 1e-6 and maxHpAfter == maxHpBefore and enc2 and #enc2.members == 1 and enc2.size == 2)
		local goldBefore = player:GetAttribute("Gold")
		local isDead = MonsterState.applyDamage(model, maxHpBefore, stage, player)
		MonsterSpawner.updateHpLabel(model)
		CombatResolution.resolveHit(player, model, isDead)
		check(("S9b 처치 보상: 골드 %d→%d, 보스전 종료=%s"):format(goldBefore, player:GetAttribute("Gold"), tostring(BossEncounter.getEncounter(player) == nil)),
			player:GetAttribute("Gold") > goldBefore and BossEncounter.getEncounter(player) == nil)
		-- 정리
		PartyState.leave(player, "leave")
		check("S10 정리: 내 파티=" .. tostring(PartyState.getParty(player)), PartyState.getParty(player) == nil)
		reply(player, "selftest 결과:\n" .. table.concat(results, "\n"))
	elseif sub == "party" and args[2] == "server" then
		reply(player, PartyCrossServer.describeServer())
	elseif sub == "party" and args[2] == "join" and type(args[3]) == "string" then
		-- 24-2: 실제 플레이어로 코드 합류 파이프라인을 밟되 텔레포트만 건너뛴다(simulateArrival) - 레코드 읽기·
		-- 좌석 예약·대기·저장 flush·도착 처리(handleArrival) 전부 라이브 경로 그대로.
		if BossEncounter.getActive(player) then
			BossEncounter.despawnFor(player)
		end
		task.spawn(PartyCrossServer.requestJoin, player, args[3], { simulateArrival = true })
	elseif sub == "party" and args[2] == "fakeremote" then
		local mode = args[3]
		local code = "FAKE" .. (mode == "boss" and "BS" or mode == "full" and "FL" or "RM")
		if mode == "clear" then
			for _, c in ipairs({ "FAKERM", "FAKEBS", "FAKEFL" }) do
				PartyCrossServer.debugRemoveRecord(c)
			end
			reply(player, "가짜 원격 레코드 3종 삭제")
		else
			PartyCrossServer.debugWriteRecord(code, {
				code = code, leaderUserId = -7777, leaderName = "RemoteLeader", jobId = "FAKE-REMOTE-JOB", placeId = game.PlaceId,
				members = { { userId = -7777, name = "RemoteLeader" } }, pending = {},
				bossActive = mode == "boss", playerCount = mode == "full" and 99 or 1, capacity = PartyConfig.serverCapacity,
			})
			reply(player, ("가짜 원격 파티 레코드 작성: 코드 %s (jobId FAKE-REMOTE-JOB, 보스전=%s, 인원 %s) - /gg party join %s 로 합류 시도"):format(
				code, tostring(mode == "boss"), mode == "full" and "99(정원 초과)" or "1", code))
		end
	elseif sub == "party" and args[2] == "xtest" then
		-- 24-2 크로스서버 자체검증. 스탠드인(가짜 Player 테이블)으로 requestJoin/handleArrival을 실제 코드 경로로
		-- 돌린다. MemoryStore는 Studio에서도 실제로 동작한다(API 접근 활성, 데이터는 프로덕션과 격리). 텔레포트만
		-- Studio에서 불가 - 스탠드인은 Instance가 아니라 TeleportAsync가 에러를 내고, 그 실패 회수 경로가 곧 검증 대상이다.
		if PartyState.getParty(player) then
			reply(player, "먼저 파티를 나가세요(/gg party dummy 0 또는 탈퇴)")
			return
		end
		ensureBackup(player)
		task.spawn(function()
			local function standIn(name, userId)
				return { Name = name, UserId = userId, Parent = workspace, Character = nil }
			end
			local results = {}
			local function check(label, ok)
				table.insert(results, ("%s %s"):format(ok and "O" or "X", label))
			end
			local function waitUntil(fn, timeout)
				local deadline = os.clock() + (timeout or 10)
				while os.clock() < deadline do
					if fn() then
						return true
					end
					task.wait(0.25)
				end
				return fn()
			end
			local function fakeRecord(code, fields)
				local record = {
					code = code, leaderUserId = -7777, leaderName = "RemoteLeader", jobId = "FAKE-REMOTE-JOB", placeId = game.PlaceId,
					members = { { userId = -7777, name = "RemoteLeader" } }, pending = {}, bossActive = false, playerCount = 1,
					capacity = PartyConfig.serverCapacity,
				}
				for k, v in pairs(fields or {}) do
					record[k] = v
				end
				PartyCrossServer.debugWriteRecord(code, record)
			end
			local function pendingCount(code)
				local record = PartyCrossServer.debugReadRecord(code)
				return record and #record.pending or -1
			end
			-- X1 코드 발급
			local party = PartyState.create(player)
			waitUntil(function() return party.code ~= nil end, 10)
			local code = party.code
			check("X1 파티 만들기 + 코드 발급: " .. tostring(code), code ~= nil and #code == PartyConfig.codeLength)
			if not code then
				reply(player, "xtest 중단 - MemoryStore 코드 발급 실패(위 warn 참고):\n" .. table.concat(results, "\n"))
				PartyState.leave(player, "leave")
				return
			end
			local record = PartyCrossServer.debugReadRecord(code)
			check(("X2 레코드 내용: jobId 일치=%s 리더=%s 멤버 %d"):format(tostring(record and record.jobId == game.JobId), tostring(record and record.leaderName), record and #record.members or 0),
				record ~= nil and record.jobId == game.JobId and record.leaderUserId == player.UserId and #record.members == 1)
			-- X3 같은 서버 코드 합류(스탠드인 B) - 텔레포트 없이 로컬 attach
			local B = standIn("XStandB", -9101)
			PartyCrossServer.requestJoin(B, code, { standIn = true })
			check("X3 같은 서버 코드 합류: size=" .. PartyState.getSize(party), PartyState.getSize(party) == 2 and PartyState.getParty(B) == party)
			-- X4 틀린 코드
			local C = standIn("XStandC", -9102)
			local okWrong = PartyCrossServer.requestJoin(C, "ZZZZZZ", { standIn = true })
			check("X4 없는 코드 거절: " .. tostring(okWrong), okWrong == false and PartyState.getParty(C) == nil)
			-- X5 이미 파티인 사람의 다른 코드 합류
			local okDup = PartyCrossServer.requestJoin(B, "ZZZZZZ", { standIn = true })
			check("X5 파티원의 다른 파티 합류 거절: " .. tostring(okDup), okDup == false)
			-- X6 가짜 원격 파티(다른 jobId) - 동시 좌석 예약 4명 → 3명만 좌석, 텔레포트 실패로 전원 좌석 회수
			local fakeCode = "FAKEXT"
			fakeRecord(fakeCode)
			local joiners = { standIn("XStandF", -9111), standIn("XStandG", -9112), standIn("XStandH", -9113), standIn("XStandI", -9114) }
			local outcomes, reserved, done = {}, 0, 0
			for i, J in ipairs(joiners) do
				task.spawn(function()
					outcomes[i] = PartyCrossServer.requestJoin(J, fakeCode, { standIn = true })
					done += 1
				end)
			end
			-- 좌석이 실제로 잡힌 순간을 잡는다(텔레포트 실패로 곧 풀리므로 예약 직후 상태를 폴링).
			waitUntil(function()
				for _, J in ipairs(joiners) do
					local st = PartyCrossServer.getJoinState(J)
					if st and st.seatReserved then
						reserved = math.max(reserved, pendingCount(fakeCode))
					end
				end
				return done == #joiners
			end, 30)
			local successes = 0
			for _, ok in pairs(outcomes) do
				if ok then successes += 1 end
			end
			check(("X6 동시 좌석 4명: 관측 최대 pending %d(기대 ≤3), 텔레포트 불가라 성공 0(=%d), 실패 후 남은 pending %d(기대 0)"):format(
				reserved, successes, pendingCount(fakeCode)), reserved <= 3 and successes == 0 and pendingCount(fakeCode) == 0 and not PartyCrossServer.isJoining(joiners[1]))
			-- X7 만원 판정 - pending 3칸이 이미 찬 가짜 레코드에 온 사람은 party_full
			fakeRecord(fakeCode, { pending = { { userId = -9201, name = "P1", since = os.time() }, { userId = -9202, name = "P2", since = os.time() }, { userId = -9203, name = "P3", since = os.time() } } })
			local K = standIn("XStandK", -9121)
			local okFull = PartyCrossServer.requestJoin(K, fakeCode, { standIn = true })
			check(("X7 만원 파티 합류 거절: 반환 %s, pending 유지 %d"):format(tostring(okFull), pendingCount(fakeCode)), okFull == false and pendingCount(fakeCode) == 3)
			-- X8 보스전 중 대기 → 풀리면 진행 / 같은 사람 두 파티 차단
			fakeRecord(fakeCode, { bossActive = true })
			local L = standIn("XStandL", -9131)
			local lResult = nil
			task.spawn(function() lResult = PartyCrossServer.requestJoin(L, fakeCode, { standIn = true }) end)
			waitUntil(function() local st = PartyCrossServer.getJoinState(L) return st ~= nil and st.phase == "waiting" end, 10)
			local stL = PartyCrossServer.getJoinState(L)
			check("X8a 보스전 중 합류 → 대기 phase=" .. tostring(stL and stL.phase), stL ~= nil and stL.phase == "waiting")
			local okTwo = PartyCrossServer.requestJoin(L, code, { standIn = true })
			check("X8b 합류 대기 중 두 번째 파티 합류 거절: " .. tostring(okTwo), okTwo == false)
			local M = standIn("XStandM", -9141)
			PartyCrossServer.debugWriteMemberRecord(M.UserId, "OTHERC", "SOME-JOB")
			local okM = PartyCrossServer.requestJoin(M, fakeCode, { standIn = true })
			local recM = PartyCrossServer.debugReadRecord(fakeCode)
			local mSeatLeft = false
			for _, seat in ipairs(recM and recM.pending or {}) do if seat.userId == M.UserId then mSeatLeft = true end end
			check(("X8c 다른 파티로 가는 중인 사람(멤버 레코드) 차단: 반환 %s, 좌석 회수=%s"):format(tostring(okM), tostring(not mSeatLeft)), okM == false and not mSeatLeft)
			local recBoss = PartyCrossServer.debugReadRecord(fakeCode)
			recBoss.bossActive = false
			PartyCrossServer.debugWriteRecord(fakeCode, recBoss)
			waitUntil(function() return lResult ~= nil end, PartyConfig.joinPollSeconds + 10)
			check(("X8d 보스전 종료 후 진행: 반환 %s(텔레포트 불가라 false), 남은 pending %d(기대 0)"):format(tostring(lResult), pendingCount(fakeCode)),
				lResult == false and pendingCount(fakeCode) == 0)
			-- X9 서버 정원 초과 대기 → 취소
			fakeRecord(fakeCode, { playerCount = 99 })
			local N = standIn("XStandN", -9151)
			local nResult = nil
			task.spawn(function() nResult = PartyCrossServer.requestJoin(N, fakeCode, { standIn = true }) end)
			waitUntil(function() local st = PartyCrossServer.getJoinState(N) return st ~= nil and st.phase == "waiting" end, 10)
			local stN = PartyCrossServer.getJoinState(N)
			local cancelled = PartyCrossServer.cancelJoin(N)
			waitUntil(function() return nResult ~= nil end, PartyConfig.joinPollSeconds + 10)
			check(("X9 정원 초과 대기(phase=%s) → 취소 %s → 좌석 회수 pending %d"):format(tostring(stN and stN.phase), tostring(cancelled), pendingCount(fakeCode)),
				stN ~= nil and stN.phase == "waiting" and cancelled and nResult == false and pendingCount(fakeCode) == 0)
			-- X10 합류 대기 중 파티 해산(레코드 삭제) → 취소
			fakeRecord(fakeCode, { bossActive = true })
			local O = standIn("XStandO", -9161)
			local oResult = nil
			task.spawn(function() oResult = PartyCrossServer.requestJoin(O, fakeCode, { standIn = true }) end)
			waitUntil(function() local st = PartyCrossServer.getJoinState(O) return st ~= nil and st.phase == "waiting" end, 10)
			PartyCrossServer.debugRemoveRecord(fakeCode)
			waitUntil(function() return oResult ~= nil end, PartyConfig.joinPollSeconds + 10)
			check("X10 대기 중 파티 해산(레코드 소멸) → 취소: 반환 " .. tostring(oResult) .. " 합류중=" .. tostring(PartyCrossServer.isJoining(O)), oResult == false and not PartyCrossServer.isJoining(O))
			-- X11 도착 처리 - 파티가 없는 코드로 도착
			local P = standIn("XStandP", -9171)
			PartyCrossServer.debugWriteMemberRecord(P.UserId, "GONE00", game.JobId)
			local handledP = PartyCrossServer.handleArrival(P, true)
			check(("X11 도착했는데 파티 해산: 처리=%s 멤버 레코드 소비=%s 파티 없음=%s"):format(tostring(handledP), tostring(PartyCrossServer.debugReadMemberRecord(P.UserId) == nil), tostring(PartyState.getParty(P) == nil)),
				handledP == true and PartyCrossServer.debugReadMemberRecord(P.UserId) == nil and PartyState.getParty(P) == nil)
			-- X12 도착 처리 - 정상(좌석 예약돼 있던 사람이 도착)
			local Q = standIn("XStandQ", -9181)
			PartyState.addPendingSeat(party, Q.UserId, Q.Name, os.time())
			PartyCrossServer.debugWriteMemberRecord(Q.UserId, code, game.JobId)
			PartyCrossServer.handleArrival(Q, true)
			check(("X12 도착 → 좌석이 멤버로: size=%d pending=%d"):format(PartyState.getSize(party), #PartyState.getPendingSeats(party)),
				PartyState.getParty(Q) == party and PartyState.getSize(party) == 3 and #PartyState.getPendingSeats(party) == 0)
			-- X13 보스전 중 도착 → 보류 → 종료 후 합류(실제 파티 보스 스폰/철수)
			BossEncounter.despawnFor(player)
			applyStage(player, BossData.stageInterval * 20)
			BossEncounter.spawnForParty(party, player, BossData.stageInterval * 20)
			waitUntil(function() return party.bossActive end, 5)
			local R = standIn("XStandR", -9191)
			PartyState.addPendingSeat(party, R.UserId, R.Name, os.time())
			PartyCrossServer.debugWriteMemberRecord(R.UserId, code, game.JobId)
			PartyCrossServer.handleArrival(R, true)
			local heldDuringBoss = PartyCrossServer.debugIsArrivalWaiting(R) and PartyState.getParty(R) == nil
			local encounter = BossEncounter.getEncounter(player)
			local sizeN = encounter and encounter.size or -1
			BossEncounter.despawnFor(player)
			waitUntil(function() return PartyState.getParty(R) == party end, 5)
			check(("X13 보스전 중 도착 보류=%s(보스 N=%d, 좌석 미포함) → 종료 후 합류=%s size=%d"):format(tostring(heldDuringBoss), sizeN, tostring(PartyState.getParty(R) == party), PartyState.getSize(party)),
				heldDuringBoss and sizeN == 3 and PartyState.getParty(R) == party and PartyState.getSize(party) == 4)
			-- X14 만원 파티에 코드 합류
			local S = standIn("XStandS", -9195)
			local okS = PartyCrossServer.requestJoin(S, code, { standIn = true })
			check("X14 만원(4/4) 파티 코드 합류 거절: " .. tostring(okS), okS == false)
			-- X15 리더 이탈 → 승계 + 레코드 리더 갱신
			PartyState.leave(player, "leave")
			task.wait(1)
			local recLead = PartyCrossServer.debugReadRecord(code)
			check(("X15 리더 이탈 승계: 새 리더 %s, 레코드 리더 %s"):format(tostring(PartyState.getLeader(party) and PartyState.getLeader(party).Name), tostring(recLead and recLead.leaderName)),
				PartyState.getLeader(party) == B and recLead ~= nil and recLead.leaderName == "XStandB")
			-- X16 해산 → 레코드 삭제
			PartyState.leave(B, "leave"); PartyState.leave(Q, "leave"); PartyState.leave(R, "leave")
			task.wait(1)
			check("X16 해산 후 레코드 삭제: " .. tostring(PartyCrossServer.debugReadRecord(code)), PartyCrossServer.debugReadRecord(code) == nil and PartyState.getPartyByCode(code) == nil)
			PartyCrossServer.debugRemoveRecord(fakeCode)
			reply(player, "xtest 결과:\n" .. table.concat(results, "\n"))
		end)
	elseif sub == "party" and args[2] == "killsim" then
		-- 봇 DPS 실측: 실제 보스 인스턴스(실제 HP·배수)에 "입장 인원 × 내 로테이션 DPS × uptime"을
		-- 0.25초마다 실제 applyDamage 경로로 넣고, 죽을 때까지의 벽시계 시간을 잰다. 클릭이 아니라
		-- 봇이라 "예상표가 실제 HP·배수·처치 파이프라인에서 재현되는가"를 확인하는 도구다.
		local encounter = BossEncounter.getEncounter(player)
		if not encounter then
			reply(player, "활성 보스전이 없습니다(/gg boss 먼저)")
			return
		end
		local classId = PlayerProfile.getClassId(player)
		local weapon = PlayerProfile.getWeapon(player)
		local equipment = { armor = PlayerProfile.getEquipped(player, "armor"), gloves = PlayerProfile.getEquipped(player, "gloves"), shoes = PlayerProfile.getEquipped(player, "shoes") }
		local loadout = BalanceSim.buildLoadoutFromEquipment(classId, PlayerProfile.getCharacterLevel(player) or 1, weapon.level, weapon.grade, equipment, weapon.gems)
		local uptime = tonumber(args[3]) or 0.65
		local dps = BalanceSim.simulateCombat(loadout, { useSkills = true }).totalDamage / 60
		local totalDps = dps * encounter.size * uptime
		local model = encounter.model
		local _, maxHp = MonsterState.getBossHp(model)
		local predicted = maxHp / totalDps
		reply(player, ("killsim 시작: 인원 %d, HP 배수 %.3f, 보스 HP %.0f, 봇 DPS %.1f×%d×%.2f=%.1f/s → 예상 %.1f초"):format(
			encounter.size, encounter.data.partyHpMultiplier or 1, maxHp, dps, encounter.size, uptime, totalDps, predicted))
		task.spawn(function()
			local startedAt = os.clock()
			local stage = TutorialState.getMonsterStage(player)
			local tick = 0.25
			while model.Parent and MonsterState.getData(model) do
				task.wait(tick)
				local isDead = MonsterState.applyDamage(model, totalDps * tick, stage, player)
				MonsterSpawner.updateHpLabel(model)
				if isDead then
					local elapsed = os.clock() - startedAt
					CombatResolution.resolveHit(player, model, isDead)
					reply(player, ("killsim 완료: 실측 %.1f초 (예상 %.1f초, 오차 %+.1f%%)"):format(elapsed, predicted, (elapsed / predicted - 1) * 100))
					return
				end
			end
			reply(player, "killsim 중단: 보스가 사라졌습니다")
		end)
	elseif sub == "heal" and args[2] == "buff" then
		-- 24-3(PRD 20.64) 검증용, 24-4에서 b 재도출에 맞춰 출력도 r·부등식 근거로 교체.
		local b = PartyConfig.healerBuffFraction
		local r = PartyConfig.healerDpsRatio
		local multiplier = 1 + b
		local buff = BuffState.get(player, "healerBuff")
		if buff then
			reply(player, ("힐러 버프: b=%.4f(N/(N-1+r)-1, r=%.4f) → 최종피해 ×%.3f, 남은시간 %.1f초"):format(
				b, r, buff.multiplier, buff.expiresAt - os.clock()))
		else
			reply(player, ("힐러 버프: b=%.4f(N/(N-1+r)-1, r=%.4f) → 최종피해 ×%.3f, 현재 비활성"):format(
				b, r, multiplier))
		end
	elseif sub == "reset" then
		restore(player)
	else
		reply(player, "알 수 없는 명령입니다. /gg help 참고")
	end
end

-- 같은 메시지가 Chatted와 TextChatCommand.Triggered 양쪽에서 들어오는 경우(플랫폼 버전에 따라 다르다)를 한 번만 처리한다.
local lastCommand = setmetatable({}, { __mode = "k" }) -- [Player] = { text, at }

local function onChatMessage(player, message)
	if not message:match("^/gg%s*") then
		return
	end
	if not isAllowed(player) then
		return -- 조용히 무시 - 허용 목록 밖 계정에게 "이런 명령이 존재한다"는 신호도 주지 않는다
	end
	local last = lastCommand[player]
	if last and last.text == message and os.clock() - last.at < 0.5 then
		return
	end
	lastCommand[player] = { text = message, at = os.clock() }

	local args = {}
	for word in message:gmatch("%S+") do
		table.insert(args, word)
	end
	table.remove(args, 1) -- "/gg" 자체를 뗀다

	local ok, err = pcall(handleCommand, player, args)
	if not ok then
		warn(("[DevTools] 명령 처리 실패: %s"):format(tostring(err)))
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		onChatMessage(player, message)
	end)
end)

-- 24-2 실측: TextChatService가 "/"로 시작하는 메시지를 명령으로 해석해 Player.Chatted에 넘기지 않는다(같은 세션에서
-- "hello"는 Chatted에 닿고 "/gg ..."는 닿지 않았다). 명령을 정식으로 등록해 Triggered로 받는다 - 실제 채팅창 입력과
-- 클라 TextChannel:SendAsync 둘 다 이 경로로 들어온다.
local TextChatService = game:GetService("TextChatService")
local ggCommand = Instance.new("TextChatCommand")
ggCommand.Name = "ForgeGG"
ggCommand.PrimaryAlias = "/gg"
ggCommand.Parent = TextChatService
ggCommand.Triggered:Connect(function(textSource, text)
	local player = Players:GetPlayerByUserId(textSource.UserId)
	if player then
		onChatMessage(player, text)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	if backups[player] then
		restore(player)
	end
end)

print("[DevTools] 밸런스 테스트 도구 로드됨(Studio 전용) - 채팅창에 /gg help")

-- ═══ 26-2 자동 검증 블록 ═══════════════════════════════════════════════════
-- 서버가 Studio에서 시작될 때 한 번 돌고 결과를 전부 print한다(플레이어 접속과 무관 -
-- 순수 함수·합성 데이터만 쓴다). execute_luau로 shared 모듈을 require하는 경로는 Edit·
-- Play 모드 둘 다 Capabilities 제약으로 막혀 있어(2026-09-16 실측) 이 파일 자체(정상적으로
-- Rojo가 동기화하고 Roblox 엔진이 그대로 불러오는 스크립트)에 검증 코드를 둔다 - 이 파일은
-- 이미 이 지점까지 오는 동안 Option/OptionData/SkillData 등을 정상적으로 require해 왔다
-- (그 require들은 execute_luau 브릿지를 거치지 않는다).
-- RunService:IsStudio()로 다시 감싼다 - 파일 맨 위의 가드와 이중이지만(중복이라도) 이 블록만
-- 떼어 다른 곳에 옮겨도 안전하도록 명시적으로 남긴다.
if RunService:IsStudio() then
	task.spawn(function()
		local function checkmark(actual, expected, tolerance)
			return math.abs(actual - expected) <= tolerance
		end

		print("===26-2 검증 시작===")
		local passCount, totalCount = 0, 0
		local function record(ok)
			totalCount += 1
			if ok then
				passCount += 1
			end
			return ok and "O" or "X"
		end

		-- [1] 기존 4축(위력·신속·방어·건강) 등급별 최소·중앙·최대 - PRD 20.67 [3] 구간표 대조.
		print("[26-2][1] 기존 4축 등급별 구간표 (itemLevel100, %) - PRD 20.67 [3] 대조")
		local AXIS_GRADE_EXPECTED = {
			attackPercent = {
				epic = { 3.50, 4.00, 4.50 }, legendary = { 5.25, 6.00, 6.75 }, relic = { 7.88, 9.00, 10.12 },
				ancient = { 14.00, 16.00, 18.00 }, primordial = { 26.25, 30.00, 33.75 },
			},
			speedPercent = {
				epic = { 3.50, 4.00, 4.50 }, legendary = { 5.25, 6.00, 6.75 }, relic = { 7.88, 9.00, 10.12 },
				ancient = { 14.00, 16.00, 18.00 }, primordial = { 26.25, 30.00, 33.75 },
			},
			maxHpPercent = {
				epic = { 1.17, 1.33, 1.50 }, legendary = { 1.75, 2.00, 2.25 }, relic = { 2.62, 3.00, 3.38 },
				ancient = { 4.67, 5.33, 6.00 }, primordial = { 8.75, 10.00, 11.25 },
			},
			defensePercent = {
				epic = { 1.98, 2.27, 2.55 }, legendary = { 2.97, 3.40, 3.82 }, relic = { 4.46, 5.10, 5.73 },
				ancient = { 7.93, 9.06, 10.20 }, primordial = { 14.87, 16.99, 19.12 },
			},
		}
		local AXIS_ORDER = { "attackPercent", "speedPercent", "defensePercent", "maxHpPercent" }
		local GRADE_ORDER = { "epic", "legendary", "relic", "ancient", "primordial" }
		for _, axisId in ipairs(AXIS_ORDER) do
			for _, gradeId in ipairs(GRADE_ORDER) do
				local expected = AXIS_GRADE_EXPECTED[axisId][gradeId]
				local range = Option.rangeOf(axisId, gradeId, 100, nil)
				local minPct, midPct, maxPct = range.min * 100, range.mid * 100, range.max * 100
				local ok = checkmark(minPct, expected[1], 0.02) and checkmark(midPct, expected[2], 0.02) and checkmark(maxPct, expected[3], 0.02)
				print(("[26-2][1]   %s %s: 실측 %.3f/%.3f/%.3f (기대 %.2f/%.2f/%.2f) %s"):format(
					OptionData.options[axisId].displayName, gradeId, minPct, midPct, maxPct,
					expected[1], expected[2], expected[3], record(ok)))
			end
		end

		-- [2] 새 옵션 12종(치명·성장·재생·흡혈 + 직업 특화 8종) 적용 전/후 수치(태초, itemLevel100, 최대롤).
		print("[26-2][2] 새 옵션 12종 적용 전/후(태초·itemLevel100·최대롤 1.125)")
		local ROLL_MAX = OptionData.rollMax
		local function expectedRaw(optionId)
			return OptionData.options[optionId].baseValue * ROLL_MAX
		end

		-- 공통 4종(축 자체가 곧 "전/후"다 - 배수 1.00 또는 흡혈률 0%가 "전").
		local commonExpected = {
			{ id = "expGain", before = 1.0, after = function(v) return 1 + v end, label = "성장(경험치 배수)" },
			{ id = "healingPower", before = 1.0, after = function(v) return 1 + v end, label = "재생(회복 배수)" },
			{ id = "lifesteal", before = 0.0, after = function(v) return v end, label = "흡혈(피해→회복 비율)" },
		}
		for _, spec in ipairs(commonExpected) do
			local value = Option.valueOf({ id = spec.id, roll = ROLL_MAX }, "primordial", 100, nil)
			local expected = expectedRaw(spec.id)
			local ok = checkmark(value, expected, 0.0005)
			print(("[26-2][2]   %s: %.6f -> %.6f (raw옵션값 기대 %.6f) %s"):format(
				spec.label, spec.before, spec.after(value), expected, record(ok)))
		end
		-- 치명(치확·치피 둘 다 독립 롤이지만 여기선 둘 다 최대롤로 검산).
		do
			local value = Option.valueOf({ id = "crit", roll = ROLL_MAX, roll2 = ROLL_MAX }, "primordial", 100, nil)
			local expectedCrit = OptionData.options.crit.critRateBase * ROLL_MAX
			local expectedDmg = OptionData.options.crit.critDmgBase * ROLL_MAX
			local ok = checkmark(value.critRate, expectedCrit, 0.0005) and checkmark(value.critDmg, expectedDmg, 0.0005)
			print(("[26-2][2]   치명: 치확+0%%p 치피+0 -> 치확+%.4f%%p 치피+%.4f (기대 치확+%.4f%%p 치피+%.4f) %s"):format(
				value.critRate * 100, value.critDmg, expectedCrit * 100, expectedDmg, record(ok)))
		end
		-- 직업 특화 8종 - SkillData의 실제 노브(coefficient·cooldownSeconds·durationSeconds·
		-- drainPercentPerSecond)에 적용 전/후를 그대로 보여준다.
		local CLASS_SKILL_KNOBS = {
			{ id = "skill_greatsword_Q", classId = "greatsword", slot = "Q", knob = "coefficient", label = "관통돌진 coefficient" },
			{ id = "skill_greatsword_E", classId = "greatsword", slot = "E", knob = "coefficient", label = "회전베기 coefficient" },
			{ id = "skill_bow_Q", classId = "bow", slot = "Q", knob = nil, label = "속사 옵션 배율(기준 1.00)" },
			{ id = "skill_bow_E", classId = "bow", slot = "E", knob = "cooldownSeconds", label = "백스텝샷 cooldownSeconds" },
			{ id = "skill_dualblade_Q", classId = "dualblade", slot = "Q", knob = "durationSeconds", label = "그림자분신 durationSeconds" },
			{ id = "skill_dualblade_E", classId = "dualblade", slot = "E", knob = "coefficient", label = "난무 coefficient" },
			{ id = "skill_healer_Q", classId = "healer", slot = "Q", knob = "cooldownSeconds", label = "치유 cooldownSeconds" },
			{ id = "skill_healer_E", classId = "healer", slot = "E", knob = "drainPercentPerSecond", label = "딜링모드 drainPercentPerSecond" },
		}
		for _, spec in ipairs(CLASS_SKILL_KNOBS) do
			local value = Option.valueOf({ id = spec.id, roll = ROLL_MAX }, "primordial", 100, spec.classId)
			local expectedValue = expectedRaw(spec.id)
			local base = spec.knob and SkillData[spec.classId][spec.slot][spec.knob] or 1.0
			local after = base * (1 + value)
			local expectedAfter = base * (1 + expectedValue)
			local ok = checkmark(value, expectedValue, 0.0005) and checkmark(after, expectedAfter, 0.0005)
			print(("[26-2][2]   %s: %.4f -> %.4f (raw옵션값 %.6f, 기대 %.6f) %s"):format(
				spec.label, base, after, value, expectedValue, record(ok)))
		end

		-- [3] 직업 특화 옵션이 다른 직업에서 어떻게 처리되는가(20.67 [8] "직업 불일치 - 효과 없음").
		print("[26-2][3] 직업 특화 옵션의 직업 불일치 처리(기대: 전부 0)")
		local MISMATCH_CASES = {
			{ id = "skill_bow_Q", wrongClassId = "greatsword" },
			{ id = "skill_healer_E", wrongClassId = "dualblade" },
			{ id = "skill_dualblade_Q", wrongClassId = "healer" },
			{ id = "skill_greatsword_E", wrongClassId = "bow" },
		}
		for _, case in ipairs(MISMATCH_CASES) do
			local value = Option.valueOf({ id = case.id, roll = ROLL_MAX }, "primordial", 100, case.wrongClassId)
			local ok = value == 0
			print(("[26-2][3]   %s를 %s가 착용: %s (기대 0) %s"):format(case.id, case.wrongClassId, tostring(value), record(ok)))
		end

		-- [4] 건강·방어 8개 몰빵 합산 상한(Σ≤20%/Σ≤32%) + 그 조합의 생존 타수(9.98타 기대).
		print("[26-2][4] 건강·방어 8개 몰빵 합산 상한 + 생존 타수(PRD 20.67 [6-2])")
		local function repeatSource(optionId, count)
			local sources = {}
			for _ = 1, count do
				table.insert(sources, { option = { id = optionId, roll = 1.0 }, grade = "primordial", itemLevel = 100 })
			end
			return sources
		end
		do
			local healthSum = Option.sumAxisBonus(repeatSource("maxHpPercent", 8), "maxHpPercent", nil)
			local ok = checkmark(healthSum * 100, 20.0, 0.01)
			print(("[26-2][4]   건강 8개 몰빵(태초·기댓값) Σ=%.3f%% (기대 20.000%%, 상한=%.0f%%) %s"):format(
				healthSum * 100, OptionData.options.maxHpPercent.cap * 100, record(ok)))
		end
		do
			local defenseSum = Option.sumAxisBonus(repeatSource("defensePercent", 8), "defensePercent", nil)
			local ok = checkmark(defenseSum * 100, 32.0, 0.01)
			print(("[26-2][4]   방어 8개 몰빵(태초·기댓값) Σ=%.3f%% (기대 32.000%%, 상한=%.0f%%) %s"):format(
				defenseSum * 100, OptionData.options.defensePercent.cap * 100, record(ok)))
		end
		do
			-- 앵커(레벨100·bow·일반등급 itemLevel100 3부위·스테이지100) + 보석 5개(건강2+방어3,
			-- 태초·기댓값) - 명세 계산은 7×1.20×1.188=9.98타(20.67 [6-2] 표 그대로).
			local gearSpec = { grade = "normal", itemLevel = 100 }
			local gems = {
				{ grade = "primordial", itemLevel = 100, option = { id = "maxHpPercent", roll = 1.0 } },
				{ grade = "primordial", itemLevel = 100, option = { id = "maxHpPercent", roll = 1.0 } },
				{ grade = "primordial", itemLevel = 100, option = { id = "defensePercent", roll = 1.0 } },
				{ grade = "primordial", itemLevel = 100, option = { id = "defensePercent", roll = 1.0 } },
				{ grade = "primordial", itemLevel = 100, option = { id = "defensePercent", roll = 1.0 } },
			}
			local loadout = BalanceSim.buildLoadout({
				classId = BalanceAnchorConfig.referenceClassId, level = BalanceAnchorConfig.referenceLevel,
				weaponLevel = 0, weaponGrade = 0,
				gear = { armor = gearSpec, gloves = gearSpec, shoes = gearSpec },
				gems = gems,
			})
			local point = BalanceSim.measurePoint(loadout, BalanceAnchorConfig.referenceLevel)
			local ok = checkmark(point.surviveHits, 9.98, 0.05)
			print(("[26-2][4]   건강2+방어3(태초·기댓값) 장착 후 생존 타수=%.3f대 (기대 9.98대) %s"):format(
				point.surviveHits, record(ok)))
		end

		-- [5] 경험치 8개 몰빵 합산 상한(Σ≤25%).
		do
			local expSum = Option.sumAxisBonus(repeatSource("expGain", 8), "expGain", nil)
			local ok = checkmark(expSum * 100, 25.0, 0.01)
			print(("[26-2][5] 경험치 8개 몰빵(태초·기댓값) Σ=%.3f%% (기대 25.000%%, 상한=%.0f%%) %s"):format(
				expSum * 100, OptionData.options.expGain.cap * 100, record(ok)))
		end

		-- [6] 흡혈 초당 상한 실측(20.67 [6-1]) - 토큰 버킷을 먼저 완전히 비운 뒤(초기 가득 찬
		-- 버킷이 평균을 왜곡하지 않도록), 그 다음 구간에서 실제 시간 경과(os.clock()) 동안
		-- maxHp×10짜리 요청(어떤 직업의 DPS보다도 훨씬 큰 극단값)을 계속 넣어 정상 상태 회복률을
		-- 잰다 - PlayerState.tryLifesteal은 AttackServer/SkillServer.strikeTarget이 실전에서
		-- 부르는 그 함수 그대로다(합성 player 키만 다르다).
		do
			local fakePlayer = {}
			local maxHp = 1e8
			PlayerState.init(fakePlayer)
			PlayerState.setMaxHp(fakePlayer, maxHp)
			local hugeRequest = maxHp * 10
			PlayerState.tryLifesteal(fakePlayer, hugeRequest) -- 초기 가득 찬 버킷을 비운다.

			local totalGranted = 0
			local startAt = os.clock()
			for _ = 1, 20 do
				task.wait(0.1)
				totalGranted += PlayerState.tryLifesteal(fakePlayer, hugeRequest)
			end
			local elapsed = os.clock() - startAt
			local ratePerSecond = (totalGranted / maxHp) / elapsed
			local cap = CombatConfig.lifestealMaxHpFractionPerSecond
			local ok = ratePerSecond <= cap + 0.005 -- 타이밍 오차 여유 0.5%p
			print(("[26-2][6] 흡혈 초당 상한 실측: %.2f초 동안 회복 %.4f%%(maxHp 기준) -> 초당 %.4f%% (상한 %.2f%%, 못 넘으면 O) %s"):format(
				elapsed, totalGranted / maxHp * 100, ratePerSecond * 100, cap * 100, record(ok)))
			PlayerState.clear(fakePlayer) -- 합성 키 정리(실제 플레이어와 무관하지만 남겨둘 이유가 없다).
		end

		print(("===26-2 검증 끝=== %d/%d 통과"):format(passCount, totalCount))
	end)
end

-- ═══ 26-3 자동 검증 블록 ═══════════════════════════════════════════════════
-- 26-2와 같은 이유(execute_luau의 require 제약) - 서버가 Studio에서 시작될 때 실제로
-- 접속한 플레이어 프로필로 한 번 돈다(6단계 리롤 확장은 PlayerProfile 내부의 `profiles[player]`
-- 상태가 필요해 26-2처럼 완전히 플레이어 없이는 못 돈다 - GemSync.push 등이 실제 Player
-- 인스턴스를 요구한다). ensureBackup/restore(이 파일 기존 함수)로 감싸 실제 세이브를
-- 건드리지 않는다 - 다만 restoreForDevTools는 profile.classes(직업별 상태)만 되돌리고
-- profile.inventory·profile.purchases(계정 공유, 최상위)는 안 건드리므로 그 둘만 따로
-- 스냅샷·복원한다.
if RunService:IsStudio() then
	local ran26_3 = false
	local function run26_3Verification(player)
		if ran26_3 then
			return
		end
		ran26_3 = true
		task.spawn(function()
			local waited = 0
			while not PlayerProfile.getProfile(player) and waited < 10 do
				task.wait(0.5)
				waited += 0.5
			end
			local profile = PlayerProfile.getProfile(player)
			if not profile then
				print("[26-3] 프로필 로드 실패(10초 대기) - 검증을 건너뜁니다")
				return
			end

			print("===26-3 검증 시작===")
			local passCount, totalCount = 0, 0
			local function record(ok)
				totalCount += 1
				if ok then
					passCount += 1
				end
				return ok and "O" or "X"
			end

			ensureBackup(player)
			-- classes(직업별 상태)는 restoreForDevTools가 되돌린다 - inventory·purchases는
			-- 최상위(계정 공유)라 여기서 직접 스냅샷한다.
			local originalTickets = {
				ancient = profile.purchases.optionRerollTickets.ancient,
				primordial = profile.purchases.optionRerollTickets.primordial,
			}

			local classId = PlayerProfile.getClassId(player)
			if not classId then
				classId = ClassData.order[1]
				PlayerProfile.setClassId(player, classId)
			end
			local weapon = PlayerProfile.getWeapon(player)
			weapon.slotUnlocked[1] = true -- 슬롯 해금 여부와 무관하게 장착 경로만 검증한다.
			profile.purchases.optionRerollTickets.primordial = 10

			-- [1] 전체 경로: 드랍(합성) -> 분해 -> 보석 -> 장착(20.67 [14] 1~3단계가 이미
			-- 만든 함수들을 실전과 같은 순서로 그대로 부른다 - 새 경로를 만들지 않는다).
			local dropItem = {
				grade = "primordial", part = "armor", dropStage = 1, itemLevel = 77,
				tierIndex = 1, locked = false, option = { id = "lifesteal", roll = 1.1 },
			}
			table.insert(profile.inventory, dropItem)
			local dropIndex = #profile.inventory

			local dismantleOk = PlayerProfile.dismantleItem(player, dropIndex)
			local gemInv = PlayerProfile.getGemInventory(player)
			local newGem = gemInv[#gemInv]
			local transferOk = dismantleOk and newGem ~= nil and newGem.grade == "primordial" and newGem.itemLevel == 77
				and newGem.option ~= nil and newGem.option.id == "lifesteal" and math.abs(newGem.option.roll - 1.1) < 1e-6
			print(("[26-3][1] 드랍(합성,옵션=lifesteal roll1.1,itemLevel77) -> 분해 -> 보석 이전(옵션·itemLevel 그대로 보존): %s"):format(record(transferOk)))

			local equipOk = PlayerProfile.equipGem(player, 1, #gemInv)
			local equippedGem = weapon.gems[1]
			local equipVerified = equipOk and type(equippedGem) == "table" and equippedGem.option ~= nil
				and equippedGem.option.id == "lifesteal" and equippedGem.itemLevel == 77
			print(("[26-3][1] 보석 -> 슬롯1 장착(옵션·itemLevel 유지): %s"):format(record(equipVerified)))

			-- [2] 리롤 확장(20.67 [10]) - 보석(gemSlot)·착용(equipped)·가방(bag) 세 경로.
			local rerollGemOk, rerollGemId = PlayerProfile.rerollGemOption(player, 1)
			local rerollGemVerified = rerollGemOk and weapon.gems[1].option ~= nil and OptionData.options[weapon.gems[1].option.id] ~= nil
			print(("[26-3][2] 보석 리롤(슬롯1) -> %s: %s"):format(tostring(rerollGemId), record(rerollGemVerified)))

			PlayerProfile.setEquippedDirect(player, "armor", {
				grade = "primordial", part = "armor", dropStage = 1, itemLevel = 100,
				tierIndex = 1, locked = false, option = nil,
			})
			local rerollEquipOk, rerollEquipId = PlayerProfile.rerollEquippedOption(player, "armor")
			local equippedArmorAfter = PlayerProfile.getEquipped(player, "armor")
			local rerollEquipVerified = rerollEquipOk and equippedArmorAfter.option ~= nil and OptionData.options[equippedArmorAfter.option.id] ~= nil
			print(("[26-3][2] 착용 장비 리롤(armor) -> %s: %s"):format(tostring(rerollEquipId), record(rerollEquipVerified)))

			table.insert(profile.inventory, {
				grade = "primordial", part = "gloves", dropStage = 1, itemLevel = 100,
				tierIndex = 1, locked = false, option = nil,
			})
			local bagIndex = #profile.inventory
			local rerollBagOk, rerollBagId = PlayerProfile.rerollBagItemOption(player, bagIndex)
			local bagItemAfter = profile.inventory[bagIndex]
			local rerollBagVerified = rerollBagOk and bagItemAfter.option ~= nil and OptionData.options[bagItemAfter.option.id] ~= nil
			print(("[26-3][2] 가방 장비 리롤(gloves) -> %s: %s"):format(tostring(rerollBagId), record(rerollBagVerified)))

			-- [3] 리롤 등급 게이트(20.67 [10] "영웅·전설·유물은 리롤 불가 = 드랍 운") - 영웅
			-- 등급은 변환권이 있어도 거부돼야 한다.
			PlayerProfile.setEquippedDirect(player, "shoes", {
				grade = "epic", part = "shoes", dropStage = 1, itemLevel = 100,
				tierIndex = 1, locked = false, option = nil,
			})
			local rerollEpicOk, rerollEpicReason = PlayerProfile.rerollEquippedOption(player, "shoes")
			print(("[26-3][3] 영웅 등급 리롤 거부(기대 false,\"not_rerollable\"): %s,%s %s"):format(
				tostring(rerollEpicOk), tostring(rerollEpicReason),
				record(rerollEpicOk == false and rerollEpicReason == "not_rerollable")))

			-- 인벤토리·변환권(계정 공유, restoreForDevTools 대상 밖)을 직접 되돌린다.
			if profile.inventory[bagIndex] then
				table.remove(profile.inventory, bagIndex)
			end
			profile.purchases.optionRerollTickets.ancient = originalTickets.ancient
			profile.purchases.optionRerollTickets.primordial = originalTickets.primordial
			InventorySync.push(player, profile)
			GemSync.push(player)

			restore(player)
			print(("===26-3 검증 끝=== %d/%d 통과"):format(passCount, totalCount))
		end)
	end

	for _, existing in ipairs(Players:GetPlayers()) do
		run26_3Verification(existing)
	end
	Players.PlayerAdded:Connect(run26_3Verification)
end
