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
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local PlayerProfile = require(script.Parent.PlayerProfile)
local SaveCoordinator = require(script.Parent.SaveCoordinator)

-- 앵커 조건(지시 [1] - "최소한 앵커 조건은 하나로 불러올 수 있어야 한다"): 레벨100 +
-- 일반등급 itemLevel100 3부위 + 강화+0, 스테이지 100.
local ANCHOR = {
	level = 100,
	gearGrade = "normal",
	gearItemLevel = 100,
	weaponLevel = 0,
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

local function buildGearItem(part, grade, itemLevel, stage)
	return {
		grade = grade,
		part = part,
		dropStage = stage or 1,
		itemLevel = itemLevel,
		tierIndex = 1,
		locked = true,
	}
end

local function isValidGrade(grade)
	return ArmorData.grades[grade] ~= nil and ItemVisualData.gradeVisuals[grade] ~= nil
end

-- 갑옷·장갑·신발 3부위 전부 같은 등급·itemLevel로 즉시 장착시킨다.
local function applyGear(player, grade, itemLevel)
	if not isValidGrade(grade) then
		reply(player, ("알 수 없는 등급: %s (사용 가능: %s)"):format(tostring(grade), table.concat(ArmorData.gradeOrder, "/")))
		return false
	end
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		PlayerProfile.setEquippedDirect(player, part, buildGearItem(part, grade, itemLevel))
	end
	return true
end

local function applyLevel(player, level)
	PlayerProfile.setCharacterExpDirect(player, CharacterLevel.getExpForLevel(level))
end

local function applyEnhance(player, level)
	level = math.clamp(level, 0, EnhanceConfig.maxLevel)
	PlayerProfile.setWeaponLevel(player, level)
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

	local loadout = BalanceSim.buildLoadoutFromEquipment(classId, level, weapon.level, equipment)
	local monsterAttack = BalanceSim.getMonsterAttack(stage, "tier1")
	local surviveHits, dmgPerHit = BalanceSim.getSurviveHits(loadout, monsterAttack)
	local autoAttack60 = BalanceSim.simulateAutoAttack(loadout, 60)

	print(("[DevTools] === %s 실측 (직업=%s, 레벨=%d, 강화=+%d, 스테이지=%d) ==="):format(
		player.Name, classId, level, weapon.level, stage))
	print(("[DevTools] 공격력=%.2f 방어력=%.2f 최대체력=%.2f 공격쿨다운=%.3f초"):format(
		loadout.atk, loadout.defense, loadout.maxHp, loadout.attackCooldown))
	print(("[DevTools] tier1 몬스터 평타(스테이지%d 적용)=%.3f -> 실제 피해=%.3f/대 -> 생존 타수=%.2f대"):format(
		stage, monsterAttack, dmgPerHit, surviveHits))
	print(("[DevTools] 60초 순수 평타 총딜(스킬 없음)=%.1f (%.1f회 타격, 평균 %.2f/타)"):format(
		autoAttack60.totalDamage, autoAttack60.hits, autoAttack60.avgHit))
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
	applyStage(player, ANCHOR.stage)
	reply(player, ("앵커 조건 적용 완료(레벨%d, %s등급 itemLevel%d 3부위, 강화+%d, 스테이지%d) - 직업=%s"):format(
		ANCHOR.level, ANCHOR.gearGrade, ANCHOR.gearItemLevel, ANCHOR.weaponLevel, ANCHOR.stage,
		tostring(PlayerProfile.getClassId(player))))
	measure(player, ANCHOR.stage)
end

local HELP_TEXT = table.concat({
	"/gg anchor [classId] - 앵커 조건 적용(레벨100+일반itemLevel100 3부위+강화0+스테이지100)",
	"/gg level <n> - 캐릭터 레벨 직접 지정",
	"/gg gear <grade> <itemLevel> - 갑옷/장갑/신발 3부위 동일 조건으로 장착",
	"/gg enhance <n> - 무기 강화 단계 지정(0~" .. EnhanceConfig.maxLevel .. ")",
	"/gg class <classId> - 직업 전환(greatsword/dualblade/bow/healer)",
	"/gg stage <n> - 무한 스테이지 지정(생존타수/보상 배율 계산용, 물리적 이동 아님)",
	"/gg measure [stage] - 지금 조건의 생존 타수·60초 평타 총딜을 콘솔에 출력",
	"/gg reset - 백업된 원본 프로필로 복원 + 저장 차단 해제",
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
	elseif sub == "enhance" and tonumber(args[2]) then
		ensureBackup(player)
		applyEnhance(player, math.floor(tonumber(args[2])))
		reply(player, "무기 강화 +" .. args[2] .. " 적용")
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
	elseif sub == "reset" then
		restore(player)
	else
		reply(player, "알 수 없는 명령입니다. /gg help 참고")
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if not message:match("^/gg%s*") then
			return
		end
		if not isAllowed(player) then
			return -- 조용히 무시 - 허용 목록 밖 계정에게 "이런 명령이 존재한다"는 신호도 주지 않는다
		end

		local args = {}
		for word in message:gmatch("%S+") do
			table.insert(args, word)
		end
		table.remove(args, 1) -- "/gg" 자체를 뗀다

		local ok, err = pcall(handleCommand, player, args)
		if not ok then
			warn(("[DevTools] 명령 처리 실패: %s"):format(tostring(err)))
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	if backups[player] then
		restore(player)
	end
end)

print("[DevTools] 밸런스 테스트 도구 로드됨(Studio 전용) - 채팅창에 /gg help")
