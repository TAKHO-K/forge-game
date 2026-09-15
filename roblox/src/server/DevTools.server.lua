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
local BalanceSim = require(ReplicatedStorage.Shared.BalanceSim)
local PlayerProfile = require(script.Parent.PlayerProfile)
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

-- "/gg rebirth <n>" - 20-4 [1] 검증용. 환생 시스템 자체는 없다 - rebirthCount를 직접
-- 세팅해 보스 첫 처치 확정 드랍 등급표 분기(Loot.rollBossFirstClearDrop)만 바꿔본다.
local function applyRebirth(player, count)
	PlayerProfile.setRebirthCountDirect(player, count)
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

	local loadout = BalanceSim.buildLoadoutFromEquipment(classId, level, weapon.level, weapon.grade, equipment)
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

-- "/gg curve [classId]" - 앵커 곡선(21-1 [2], BalanceAnchorConfig) 위의 격자(레벨×무기등급)를
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
	local real = ZoneTerrain.plan(zone, ZoneTerrainData.zones.tier1.features, floorTopY, floorThickness)
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
	local lines = { ("[규칙] 실제 tier1 데이터: 요소 %d, 위반 %d"):format(real.featureCount, #real.violations) }
	for _, v in ipairs(real.violations) do
		table.insert(lines, "  ! " .. v)
	end
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
local function reportMonsterGrounding(player)
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
			if MonsterState.getZoneKey(model) == "tier1" then
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
	"/gg enhance <n> - 무기 강화 단계 지정(0~" .. EnhanceConfig.maxLevel .. ")",
	"/gg weapon <n|등급명> - 무기 등급 지정(0~6 또는 " .. table.concat(ArmorData.gradeOrder, "/") .. ")",
	"/gg class <classId> - 직업 전환(greatsword/dualblade/bow/healer)",
	"/gg stage <n> - 무한 스테이지 지정(생존타수/보상 배율 계산용, 물리적 이동 아님)",
	"/gg measure [stage] - 지금 조건의 생존 타수·60초 총딜·처치 시간·권장 스테이지를 콘솔에 출력",
	"/gg curve [classId] - 앵커 곡선(레벨×무기등급 격자)의 생존 타수·처치 시간 표를 콘솔에 출력",
	"/gg rebirth <n> - 환생 횟수 스텁 직접 지정(보스 첫 처치 드랍 등급표 분기 검증용)",
	"/gg bossreset [stage] - 보스 첫 처치 확정 드랍 기록 초기화(생략 시 전부, 재검증용)",
	"/gg variant <sparkle|chest|frail|sturdy|giant|none> - 가장 가까운 잡몹을 그 변종으로 즉시 교체(22-2 검증용)",
	"/gg chesttest - 가장 가까운 잡몹을 상자로 바꾼 뒤 피격 간격·다중 타격자·기록 정리를 서버 로그로 검증(22-2)",
	"/gg killtest - 가장 가까운 잡몹을 실제 처치 경로(applyDamage→resolveHit)로 즉시 잡고 골드·경험치·드랍 변화를 로그로 출력(22-2)",
	"/gg boss [stage] - 보스 스테이지(기본 5)로 이동해 개인 아레나 보스전 시작(21-3 검증용)",
	"/gg pattern <heavy|shockwave|meteor|charge|cross> - 지금 보스에게 그 패턴을 즉시 시작시킨다",
	"/gg bossdmg <비율> - 지금 보스 HP를 최대치의 비율만큼 깎는다(사망 리셋 검증용, 예: 0.5)",
	"/gg terrain [clear|cost|ground|drop|rules|parts] - tier1에 테스트 지형(고원·30°경사·계단·70°경사·절벽·도랑) 생성 / 제거 / 지면 Raycast 부하 실측 / 잡몹 접지 상태 / 발밑 시험 드랍(22-4) / 배치 규칙 강제 검증 / 파트 수 실측(22-5)",
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
	elseif sub == "curve" then
		printCurve(player, args[2])
	elseif sub == "rebirth" and tonumber(args[2]) then
		ensureBackup(player)
		applyRebirth(player, math.floor(tonumber(args[2])))
		reply(player, "환생 횟수(스텁) " .. args[2] .. " 적용")
	elseif sub == "boss" then
		ensureBackup(player)
		local stage = tonumber(args[2]) and math.floor(tonumber(args[2])) or BossData.stageInterval
		if not BossRules.isBossStage(stage) then
			reply(player, ("스테이지 %d은(는) 보스 스테이지가 아닙니다(%d의 배수)"):format(stage, BossData.stageInterval))
			return
		end
		BossEncounter.despawnFor(player)
		applyStage(player, stage)
		BossEncounter.spawnFor(player, stage)
		reply(player, ("보스 스테이지 %d 진입 - 아레나로 이동"):format(stage))
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
			MonsterState.applyDamage(model, data.hp * tonumber(args[2]), PlayerProfile.getInfiniteStage(player) or 1, player)
			MonsterSpawner.updateHpLabel(model)
			reply(player, ("보스 HP %.0f%% 차감 - 남은 비율 %.2f"):format(tonumber(args[2]) * 100, MonsterState.getHpRatio(model)))
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
		local stage = PlayerProfile.getInfiniteStage(player) or 1
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
		local stage = PlayerProfile.getInfiniteStage(player) or 1
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
			reportMonsterGrounding(player)
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
	elseif sub == "bossreset" then
		ensureBackup(player)
		PlayerProfile.clearBossFirstClearRewards(player, tonumber(args[2]))
		reply(player, args[2] and ("스테이지 " .. args[2] .. " 첫 처치 기록 초기화") or "첫 처치 기록 전부 초기화")
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
