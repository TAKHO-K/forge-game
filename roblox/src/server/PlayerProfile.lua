-- 플레이어 영구 저장 데이터(골드 등) 단일 관리 통로. PlayerState(전투 중 HP)와 일부러
-- 분리했다 - HP는 리스폰마다 초기화되지만 골드는 그러면 안 된다. 같은 테이블에 두면
-- PlayerState.reset() 같은 리스폰 훅이 실수로 같이 건드릴 위험이 생긴다.
-- 실제 로드/저장(DataStore)은 SaveSystem이 한다 - 이 모듈은 서버 메모리에 올라온
-- 프로필을 들고 있다가 값을 읽고 쓰는 것만 한다.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loot = require(ReplicatedStorage.Shared.Loot)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local CombatConfig = require(ReplicatedStorage.Shared.data.CombatConfig)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local JumpMath = require(ReplicatedStorage.Shared.JumpMath) -- G2a: 걷기 배율 상한
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local Gem = require(ReplicatedStorage.Shared.Gem)
local Equip = require(ReplicatedStorage.Shared.Equip) -- S20d: 착용 · 해제 판정(클라 미리 판정과 같은 함수)
-- 26-2(PRD 20.67 [14] 3~5단계): 장비 3부위 옵션 + 보석 5개의 축 합산·치명·직업 특화 전부
-- Option.lua 순수 함수(valueOf·sumWithCap·sumAxisBonus·critBonus)가 유일한 출처다.
local Option = require(ReplicatedStorage.Shared.Option)
local InventorySync = require(script.Parent.InventorySync)
local GemSync = require(script.Parent.GemSync)
local PlayerState = require(script.Parent.PlayerState)
-- 30-0 S09: 파티 경험치 보너스(getExpGainMultiplier). PartyState는 PartyConfig만 require하므로 순환이 없다.
local PartyState = require(script.Parent.PartyState)
-- 28-1 S04: 강화 재료 보유량(profile.materials)의 Attribute 이름 · 순서를 데이터에서 읽는다.
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
-- 30-0 S11: 보스 도감 도장(purchases.bossCodex)의 키 검사(BossData.bosses의 id).
local BossData = require(ReplicatedStorage.Shared.data.BossData)
-- S21-0 A2: 보상 계산 출구(NaN·inf 오염 차단).
local Sanitize = require(ReplicatedStorage.Shared.Sanitize)
-- P2.5b A: 장비 계승 규칙(클라 미리 판정과 같은 순수 함수).
local Inherit = require(ReplicatedStorage.Shared.Inherit)
local Awaken = require(ReplicatedStorage.Shared.Awaken) -- D1 태초 각성
-- P2.5b C · B: 보석 분해(가루) · 재련 규칙.
local GemCraft = require(ReplicatedStorage.Shared.GemCraft)
-- P2.5b D: 환생 후 레벨 마일스톤(영구 능력치 · 해금).
local Milestone = require(ReplicatedStorage.Shared.Milestone)
local MilestoneData = require(ReplicatedStorage.Shared.data.MilestoneData)
local MilestoneNotice = require(script.Parent.MilestoneNotice)

local PlayerProfile = {}

-- 9-1이 확정한 StarterPlayer.CharacterWalkSpeed 기본값 - 신발 배율(16-6)의 기준점이다.
local BASE_WALK_SPEED_STUDS = 16

-- [Player] = profile 테이블(SaveSystem.defaultProfile()/migrate()와 같은 스키마)
local profiles = {}

-- 직업별 분리 데이터(19-1)로 가는 유일한 진입점 - 캐릭터 레벨·무기·착용 장비·무한 모드
-- 진행도를 다루는 함수는 전부 이 함수를 거쳐야 한다(profile 최상위에 그 필드들을 직접
-- 두지 않는다는 스키마 배치가 곧 "공유/직업별 경계"의 강제 수단이다 - Luau엔 이걸
-- 컴파일타임에 막을 도구가 없어 이 인디렉션 하나로 관례를 지킨다). classId를 아직 안
-- 골랐으면(nil) nil을 돌려준다 - 호출부가 그 경우를 각자 처리한다.
local function activeClassState(profile)
	return profile.classId and profile.classes[profile.classId]
end

-- 26-2(PRD 20.67 [14] 3단계): 옵션을 가질 수 있는 모든 자리(장비 3부위 + 보석 5칸)를 한
-- 목록으로 모은다. 각 원소는 { option, grade, itemLevel }를 갖는 아이템/보석 테이블 그대로
-- 다시 쓴다(Option.sumAxisBonus·Option.critBonus가 이 모양을 그대로 읽는다, 20.67 [1]
-- "장비 옵션 1개 ≙ 보석 1개" - 자리 종류가 달라도 값 계산식은 하나다).
local function buildOptionSources(classState)
	local sources = {}
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		local item = classState.equipment[part]
		if item then
			table.insert(sources, item)
		end
	end
	local gems = classState.weapon.gems
	for slot = 1, Gem.slotCount do
		if Gem.isFilled(gems, slot) then
			table.insert(sources, gems[slot])
		end
	end
	return sources
end

-- 옵션 하나(axisId)가 지금 이 플레이어에게 실제로 얼마를 주는지 - 장비 3부위 옵션 + 보석
-- 5개를 합쳐 Option.sumAxisBonus(=Option.valueOf + Option.sumWithCap 합성)로 계산한다.
-- classId 불일치인 직업 특화 옵션은 Option.valueOf가 이미 0으로 처리한다(20.67 [8]).
-- 위력·신속·방어·건강 4축(아래 getAttackPercentBonus 등)과 성장·재생·흡혈·직업 특화 8종이
-- 전부 이 함수 하나로 계산된다 - Option.lua 밖에 새 계산식을 두지 않는다.
function PlayerProfile.getOptionBonus(player, axisId)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return 0
	end
	return Option.sumAxisBonus(buildOptionSources(classState), axisId, profile.classId)
end

-- 치명(crit) 전용 - {critRate, critDmg} 두 값을 같이 돌려준다(20.67 [6-3], Option.critBonus
-- 참고 - 둘 다 상한 없음).
function PlayerProfile.getCritBonus(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return 0, 0
	end
	return Option.critBonus(buildOptionSources(classState), profile.classId)
end

-- 등급 하나의 ArmorData.gradeOrder 안 위치(1부터 시작). 목록에 없는 등급이면 nil -
-- 오타·유효하지 않은 값을 조용히 걸러내는 신호로 쓴다(sellItemsBulkUpTo·
-- setBulkSellCutoffGrade 공용, 20-3).
local function gradeIndex(gradeId)
	for i, id in ipairs(ArmorData.gradeOrder) do
		if id == gradeId then
			return i
		end
	end
	return nil
end

-- 계정 최고 스테이지(28-2 [8] 3번) = 전 직업 infiniteBest의 최댓값(최소 1). 옵션 변환권 가격(GemServer)과 클라의 가격 표시가
-- 이 값 하나를 쓴다 - 지금 서 있는 스테이지가 아니라 "가장 멀리 간 기록"이 기준이라, 스테이지 1로 내려가 싸게 사는 길이 없다.
-- 직업별 상태는 classes[classId] 아래에 전부 남아 있으므로(19-1) 활성 직업이 아니어도 읽힌다.
local function accountBestStageOf(profile)
	local best = 1
	for _, classState in pairs(profile.classes) do
		best = math.max(best, classState.stageProgress.infiniteBest)
	end
	return best
end

-- 클라가 가격을 미리 보여 줄 수 있게 Attribute로 내린다. infiniteBest가 바뀌는 자리(로드·전환·새 기록·직접 지정)에서 부른다.
local function syncAccountBestStage(player, profile)
	player:SetAttribute("AccountBestStage", accountBestStageOf(profile))
end

-- P2.5b D · P2.5c B2: 마일스톤 Attribute - MilestoneUnlockCount(계정) · MilestoneLevel(활성 직업이 받은 마지막 능력치 마일스톤 레벨) ·
-- MilestoneMultiplier(활성 직업 공격력 배율 - 버킷이 최대 체력 쪽이면 1. 가방 창 공격력 표시 · 성장 보상 창이 읽는다).
local function syncMilestoneAttributes(player, profile)
	player:SetAttribute("MilestoneUnlockCount", profile.milestoneUnlocks)
	local classState = activeClassState(profile)
	local claimed = classState and classState.milestoneLevel or 0
	player:SetAttribute("MilestoneLevel", claimed)
	player:SetAttribute("MilestoneMultiplier", Milestone.attackMultiplier(claimed))
end

-- 로드 직후(PlayerProfile.init)와 직업 전환 직후(setClassId) 둘 다 "지금 활성 직업의
-- 상태를 Attribute에 그대로 반영"해야 하므로 공유한다. classId가 nil이면(아직 선택 전)
-- 직업별 Attribute는 건드리지 않는다 - ClassSelectUI가 빈 문자열로 이미 선택 UI를 띄운다.
local function syncActiveClassAttributes(player, profile)
	player:SetAttribute("ClassId", profile.classId or "")
	syncAccountBestStage(player, profile)
	syncMilestoneAttributes(player, profile)

	local classState = activeClassState(profile)
	if not classState then
		return
	end

	player:SetAttribute("WeaponLevel", classState.weapon.level)
	player:SetAttribute("WeaponGrade", classState.weapon.grade)
	player:SetAttribute("EnhanceGauge", classState.weapon.enhanceGauge or 0) -- 불씨(28-1 S07) - 강화 UI가 접속 · 직업 전환 직후부터 읽는다
	-- 환생 횟수(23-2) - 환생 UI(레벨 상한 표시)가 이 Attribute로 판정한다(25-1까지는 ExpBar의
	-- 곡선 분기도 봤지만, 곡선이 회차 무관 하나가 되면서 그 용도는 없어졌다).
	player:SetAttribute("RebirthCount", classState.rebirthCount)
	-- 캐릭터 레벨(13-2) - 저장에는 누적 경험치만 있고 레벨은 항상 여기서 파생시킨다(단일
	-- 소스 원칙, InfiniteStage의 stage/multiplier 관계와 같은 구조).
	player:SetAttribute("CharacterExp", classState.characterExp)
	player:SetAttribute("CharacterLevel", CharacterLevel.getLevelFromExp(classState.characterExp))
	-- 무한 모드 스테이지(11-1). 둘 다 nil일 수 없는 필드라(SaveSystem.migrate v4 참고)
	-- classId처럼 빈 문자열로 바꿔치기할 필요가 없다.
	player:SetAttribute("InfiniteStage", classState.stageProgress.infinite)
	player:SetAttribute("InfiniteStageBest", classState.stageProgress.infiniteBest)
	-- 최고로 깬 보스 스테이지(15-1). StageServer의 게이트 검사가 쓰는 값과 같은 소스다.
	player:SetAttribute("BestBossCleared", classState.stageProgress.bestBossCleared)
	PlayerProfile.notePeakLevel(player) -- M1: 역대 최고 레벨(PeakLevel Attribute - 나무 정거장)
	-- 신발 배율(16-6)·최대체력(17-1) - 로드/전환된 직업에 이미 장비가 있을 수 있으니 매번 맞춘다.
	PlayerProfile.refreshMovementSpeed(player)
	PlayerProfile.refreshMaxHp(player)
end

-- 재료 보유량 Attribute(28-1 S04) - 골드와 같은 방식이다(클라는 Attribute만 읽는다). 이름은 "Material" + 재료 id의 첫 글자를 대문자로
-- (enhanceStone → MaterialEnhanceStone, highEnhanceStone → MaterialHighEnhanceStone).
local function materialAttributeName(materialId)
	return "Material" .. materialId:sub(1, 1):upper() .. materialId:sub(2)
end

local function syncMaterialAttributes(player, profile)
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		player:SetAttribute(materialAttributeName(materialId), profile.materials[materialId])
	end
end

-- 방지권 보유 장수 Attribute(28-1 S05) - 재료와 같은 방식이다. kind "drop" / "reset" → ProtectionDrop / ProtectionReset.
local PROTECTION_KINDS = { "drop", "reset" }

local function protectionAttributeName(kind)
	return "Protection" .. kind:sub(1, 1):upper() .. kind:sub(2)
end

local function syncProtectionAttributes(player, profile)
	for _, kind in ipairs(PROTECTION_KINDS) do
		player:SetAttribute(protectionAttributeName(kind), profile.purchases.protectionTickets[kind])
	end
end

-- 로드가 끝난 뒤(SaveServer.server.lua) 호출한다. Gold Attribute도 여기서 같이 맞춰서
-- HUD·강화 UI가 접속 직후부터 정확한 값을 보게 한다.
function PlayerProfile.init(player, profile)
	profiles[player] = profile
	player:SetAttribute("Gold", profile.gold)
	player:SetAttribute("PrimordialEquipped", InventorySync.primordialEquipped(profile)) -- D1 ⑤
	do -- D1: 칭호 목록도 접속 때 내린다(옛 코드는 새로 받을 때만 - 이름표 칭호 줄이 재접속 뒤 사라졌다)
		local keys = {}
		for k in pairs(profile.titles or {}) do
			table.insert(keys, k)
		end
		table.sort(keys)
		player:SetAttribute("Titles", table.concat(keys, ","))
	end
	syncMaterialAttributes(player, profile)
	syncProtectionAttributes(player, profile)
	player:SetAttribute("BulkSellCutoffGrade", profile.bulkSellCutoffGrade)
	player:SetAttribute("GemMerchantUsed", profile.hints.gemMerchantUsed == true) -- 보석 탭 안내 줄(눈에 띄게 / 작게)이 읽는다
	player:SetAttribute("GemDust", profile.gemDust) -- P2.5b C: 보석 가루 - 보석 가공 창 · 보석상인 창이 읽는다
	player:SetAttribute("AutoProcess", profile.autoProcess.enabled and profile.autoProcess.maxGrade or "off") -- G1-2: 가방 자동 처리 토글이 읽는다
	-- 23-5: 저장된 적 있을 때만 Attribute를 세운다 - false(한 번도 안 옮김)면 안 세워서
	-- 클라가 GetAttribute nil을 "기본 위치 계산"의 신호로 그대로 쓸 수 있게 한다.
	if profile.inventoryWindowPosition then
		player:SetAttribute("InventoryWindowX", profile.inventoryWindowPosition.x)
		player:SetAttribute("InventoryWindowY", profile.inventoryWindowPosition.y)
	end
	player:SetAttribute("TutorialStep", profile.tutorial.step)
	player:SetAttribute("TutorialCompleted", profile.tutorial.completed)
	PlayerProfile.claimMilestones(player, false) -- P2.5b D: 지금 회차의 지금 레벨까지 기록을 채운다(v32 이관 전 계정 · 알림 없음)
	syncActiveClassAttributes(player, profile)
end

-- 저장 시점에 SaveSystem이 통째로 넘겨받아 쓴다.
-- D1: 가방 · 착용 스냅샷을 다시 보낸다(태초 세계 번호가 비동기로 채워진 뒤 - PrimordialRegistry).
function PlayerProfile.pushInventory(player)
	local profile = profiles[player]
	if profile then
		InventorySync.push(player, profile)
	end
end

function PlayerProfile.getProfile(player)
	return profiles[player]
end

function PlayerProfile.getGold(player)
	local profile = profiles[player]
	return profile and profile.gold
end

-- 서버만 호출한다(AttackServer의 몬스터 처치 판정 직후). 클라이언트가 보낸 값으로
-- 골드를 늘리는 경로는 없다 - 이 함수가 유일한 증가 통로다.
function PlayerProfile.addGold(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.gold += Sanitize.number(amount, 0) -- S21-0 A2: 보상 계산 출구 - 오염된 보상은 이번만 0으로 건너뛴다
	player:SetAttribute("Gold", profile.gold)
end

-- 골드가 충분하면 차감하고 true, 부족하면 아무것도 바꾸지 않고 false(10-2 [3] - 확인과
-- 차감을 분리하면 그 사이에 값이 바뀔 여지가 생긴다. 여긴 한 함수 안에서 원자적으로 처리).
function PlayerProfile.trySpendGold(player, amount)
	local profile = profiles[player]
	if not profile or profile.gold < amount then
		return false
	end
	profile.gold -= amount
	player:SetAttribute("Gold", profile.gold)
	return true
end

-- 강화 재료(28-1 S04) - 계정 공유. 증가 통로는 addMaterial 하나(서버의 처치 보상 지급뿐), 감소 통로는 trySpendMaterial 하나(강화 시도)다.
function PlayerProfile.getMaterial(player, materialId)
	local profile = profiles[player]
	return profile and profile.materials[materialId]
end

function PlayerProfile.addMaterial(player, materialId, amount)
	local profile = profiles[player]
	if not profile or profile.materials[materialId] == nil then
		return
	end
	profile.materials[materialId] += amount
	player:SetAttribute(materialAttributeName(materialId), profile.materials[materialId])
end

-- 충분하면 차감하고 true, 부족하면 아무것도 바꾸지 않고 false(trySpendGold와 같은 원자성).
function PlayerProfile.trySpendMaterial(player, materialId, amount)
	local profile = profiles[player]
	if not profile or (profile.materials[materialId] or 0) < amount then
		return false
	end
	profile.materials[materialId] -= amount
	player:SetAttribute(materialAttributeName(materialId), profile.materials[materialId])
	return true
end

-- 방지권(28-1 S05) - 계정 공유(purchases.protectionTickets). 증가 통로는 addProtectionTicket(보스 계정 첫 클리어 지급 · 상점 구매 · DevTools), 감소 통로는
-- trySpendProtectionTicket 하나(강화가 실제로 막았을 때 1장)다. kind = "drop" / "reset".
function PlayerProfile.getProtectionTicket(player, kind)
	local profile = profiles[player]
	return profile and profile.purchases.protectionTickets[kind]
end

function PlayerProfile.addProtectionTicket(player, kind, amount)
	local profile = profiles[player]
	if not profile or profile.purchases.protectionTickets[kind] == nil then
		return
	end
	profile.purchases.protectionTickets[kind] += amount
	player:SetAttribute(protectionAttributeName(kind), profile.purchases.protectionTickets[kind])
end

function PlayerProfile.trySpendProtectionTicket(player, kind, amount)
	local profile = profiles[player]
	if not profile or (profile.purchases.protectionTickets[kind] or 0) < amount then
		return false
	end
	profile.purchases.protectionTickets[kind] -= amount
	player:SetAttribute(protectionAttributeName(kind), profile.purchases.protectionTickets[kind])
	return true
end

-- "그 보스 스테이지의 방지권을 계정으로 이미 받았는가" - 직업별 bossFirstClearStages와 별개 집합(계정 공유)이다. **키는 문자열(tostring(stage))이다**: DataStore를 왕복하면
-- 숫자 키가 문자열 키로 바뀌어 돌아온다(실측 - 개발 계정의 bossFirstClearStages가 로드 뒤 "5" · "10" · "20"이었다). 숫자 키로 저장하고 숫자로 조회하면 재접속 뒤 조회가
-- 실패해 "계정 단위 1회"가 접속마다 풀린다 - 그래서 처음부터 문자열 키로 쓰고 읽는다.
function PlayerProfile.hasClaimedProtectionStage(player, stage)
	local profile = profiles[player]
	return profile ~= nil and profile.purchases.protectionClaimedStages[tostring(stage)] == true
end

function PlayerProfile.markProtectionStageClaimed(player, stage)
	local profile = profiles[player]
	if profile then
		profile.purchases.protectionClaimedStages[tostring(stage)] = true
	end
end

-- 보스 도감 도장(30-0 S11, PRD 20.73 [4-1]) - purchases.bossCodex(계정 공유). 서버만 부른다: CombatResolution.handleBossDeath(기여 10% 이상 수령자 · 견습 보스 제외).
-- markBossCodex는 새로 찍혔을 때만 true(호출부가 그때만 즉시 저장을 챙긴다). 이 집합은 Attribute로 복제하지 않는다 - 클라는 BossRewardPreview 응답으로 읽는다.
function PlayerProfile.hasBossCodex(player, bossId)
	local profile = profiles[player]
	return profile ~= nil and profile.purchases.bossCodex[bossId] == true
end

function PlayerProfile.markBossCodex(player, bossId)
	local profile = profiles[player]
	if not profile or BossData.bosses[bossId] == nil or profile.purchases.bossCodex[bossId] == true then
		return false
	end
	profile.purchases.bossCodex[bossId] = true
	return true
end

-- 도감 도장 사본({ [bossId] = true }) - 스테이지 선택 패널의 응답용.
function PlayerProfile.getBossCodex(player)
	local profile = profiles[player]
	local copy = {}
	if profile then
		for bossId, stamped in pairs(profile.purchases.bossCodex) do
			copy[bossId] = stamped
		end
	end
	return copy
end

-- DevTools "/gg ticket clear" 전용 - 방지권 보유 · 받은 스테이지 기록을 전부 비운다(Attribute 동기화 포함).
function PlayerProfile.clearProtectionForDevTools(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.purchases.protectionTickets = { drop = 0, reset = 0 }
	profile.purchases.protectionClaimedStages = {}
	syncProtectionAttributes(player, profile)
end

-- 받은 스테이지 목록(오름차순 숫자) - 키(문자열)를 숫자로 읽어 돌려준다.
function PlayerProfile.getProtectionClaimedStages(player)
	local profile = profiles[player]
	local stages = {}
	if profile then
		for key in pairs(profile.purchases.protectionClaimedStages) do
			table.insert(stages, tonumber(key) or key)
		end
	end
	table.sort(stages, function(a, b) return (tonumber(a) or 0) < (tonumber(b) or 0) end)
	return stages
end

function PlayerProfile.getCharacterLevel(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and CharacterLevel.getLevelFromExp(classState.characterExp)
end

-- 서버만 호출한다(AttackServer의 몬스터 처치 판정 직후, 골드와 같은 경로). 클라이언트가
-- 보낸 값으로 경험치를 늘리는 경로는 없다 - 이 함수가 유일한 증가 통로다. 레벨업이
-- 일어났으면(oldLevel ~= newLevel) 호출부가 그 사실로 연출(레벨업 알림)을 띄운다 -
-- 이 함수 자체는 판정만 하고 연출은 모른다(단일 책임, AttackServer가 RemoteEvent를 쏜다).
-- 19-1: 활성 직업의 경험치만 오른다 - 다른 3직업은 지금 안 쓰고 있으니 그대로 멈춰 있다.
--
-- 25-1: 회차 배수(23-2의 ×(rebirthCount+1), 23-3의 firstRunExpMultiplier)는 없앴다 - 경험치
-- 요구치 자체가 "레벨당 목표 마릿수" 곡선(CharacterLevel, 회차 무관 하나)에서 역산되므로
-- 배수로 마릿수를 조정할 이유가 사라졌다. 몬스터가 주는 경험치는 그대로 더하고, 아래
-- getExpGainMultiplier만 곱한다 - 여기 한 곳에서만 곱한다(호출부 CombatResolution.
-- grantKillReward는 몬스터가 주는 원래 경험치만 넘긴다 - "증가 통로가 여기 하나" 원칙).

-- 경험치 획득량 배수 = (1 + 성장 옵션 합) × (1 + 파티 보너스). 옵션 합은 26-2(PRD 20.67 [14] 4단계 "성장")가 상한 25%(OptionData.expGain.cap)로 자른 값이고,
-- 파티 보너스는 30-0 S09(PRD 20.73 [5-1])의 같은 서버 실제 Player 인원별 값이다 - 같은 축 안은 합, 축끼리는 곱(20.67 [7]). 순수 식이라 검증이 표로 대조한다.
function PlayerProfile.combineExpMultiplier(optionBonus, partyBonus)
	return (1 + optionBonus) * (1 + partyBonus)
end

-- addCharacterExp · 재료 기대 개수(CombatResolution.grantMaterials) · /gg curve(DevTools)가 이 함수 하나만 본다.
-- P2 G: 파티 보너스는 조건(같은 구역 · 반경 · 최근 활동)을 만족한 파티원만 센다(PartyState.getExpBonusFor - 지급 순간 판정).
function PlayerProfile.getExpGainMultiplier(player)
	local partyBonus = PartyState.getExpBonusFor(player)
	PartyState.showAppliedExpBonus(player, partyBonus) -- P2.5a D(결정 7): 칩 = 이번에 실제로 적용한 보너스
	return PlayerProfile.combineExpMultiplier(PlayerProfile.getOptionBonus(player, "expGain"), partyBonus)
end

-- 재생(healingPower, 26-2) 배수 - 자동회복(PlayerRegen.server.lua)·힐러 치유(SkillServer
-- castHeal) 둘 다 이 함수 하나로 회복량에 곱한다(20.67 [2] "회복량 ×(1+x). 흡혈엔 적용
-- 안 함" - 흡혈은 이 함수를 안 쓴다, PlayerProfile.applyLifesteal 참고).
function PlayerProfile.getHealingPowerMultiplier(player)
	return 1 + PlayerProfile.getOptionBonus(player, "healingPower")
end

-- ═══ M1 세계 이동 · 역대 최고 레벨(v38 - 계정) ═══
-- 지금 레벨이 기록보다 높으면 올린다(내려가지 않는다 - 환생 · 직업 전환 무관). PeakLevel Attribute(클라 - 나무 정거장 표시).
function PlayerProfile.notePeakLevel(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	profile.peakLevel = math.max(profile.peakLevel or 1, CharacterLevel.getLevelFromExp(classState.characterExp))
	player:SetAttribute("PeakLevel", profile.peakLevel)
end

function PlayerProfile.getPeakLevel(player)
	local profile = profiles[player]
	return profile and profile.peakLevel or 1
end

-- 계정의 가장 높은 보스 기록(직업 중 최대 - 구역 개방 기준).
function PlayerProfile.getAccountBestBossCleared(player)
	local profile = profiles[player]
	local best = 0
	for _, classState in pairs(profile and profile.classes or {}) do
		best = math.max(best, classState.stageProgress.bestBossCleared or 0)
	end
	return best
end

function PlayerProfile.isPortalOpen(player, zoneKey)
	local profile = profiles[player]
	return profile ~= nil and profile.world.portals[zoneKey] == true
end

-- 반환: 새로 열었는가
function PlayerProfile.openPortal(player, zoneKey)
	local profile = profiles[player]
	if not profile or profile.world.portals[zoneKey] then
		return false
	end
	profile.world.portals[zoneKey] = true
	return true
end

-- 칭호(v39 - 계정 · 전투력 없음). 반환: 새로 받았는가. Titles Attribute(쉼표 목록 - 클라 표시용).
function PlayerProfile.grantTitle(player, titleId)
	local profile = profiles[player]
	if not profile or profile.titles[titleId] then
		return false
	end
	profile.titles[titleId] = true
	local keys = {}
	for k in pairs(profile.titles) do
		table.insert(keys, k)
	end
	table.sort(keys)
	player:SetAttribute("Titles", table.concat(keys, ","))
	return true
end

function PlayerProfile.hasTitle(player, titleId)
	local profile = profiles[player]
	return profile ~= nil and profile.titles[titleId] == true
end

-- M1-3 둥지(v41 - 계정): 개인 쿨다운 · 줍기 횟수 · 비밀 둥지 발견 도감 · 알 가방. 서버 NestServer만 쓴다.
local function copyTree(v) -- (deepCopy는 이 파일 아래에 있어 여기서 안 보인다)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[k] = copyTree(x)
	end
	return out
end
function PlayerProfile.getNestRecord(player, nestId)
	local profile = profiles[player]
	local rec = profile and profile.world.nests[nestId]
	return rec and { next = rec.next or 0, picks = rec.picks or 0 } or { next = 0, picks = 0 }
end
-- 줍기 기록 + 알 넣기. 반환: 넣었는가(가방이 차면 false - 기록도 안 바꾼다)
function PlayerProfile.recordNestPick(player, nestId, nextAt, egg, cap)
	local profile = profiles[player]
	if not profile or #profile.eggs >= cap then
		return false
	end
	local rec = profile.world.nests[nestId] or { next = 0, picks = 0 }
	rec.next, rec.picks = nextAt, (rec.picks or 0) + 1
	profile.world.nests[nestId] = rec
	table.insert(profile.eggs, egg)
	return true
end
-- 비밀 둥지 처음 발견. 반환: 새로 찾았는가, 찾은 개수
function PlayerProfile.discoverNest(player, nestId)
	local profile = profiles[player]
	if not profile then
		return false, 0
	end
	local new = not profile.world.nestDex[nestId]
	profile.world.nestDex[nestId] = true
	local n = 0
	for _ in pairs(profile.world.nestDex) do
		n += 1
	end
	return new, n
end
function PlayerProfile.getEggs(player)
	local profile = profiles[player]
	return profile and copyTree(profile.eggs) or {}
end
function PlayerProfile.getNestDex(player)
	local profile = profiles[player]
	return profile and copyTree(profile.world.nestDex) or {}
end

-- M1-3 관문 등록(v40 - 계정). 반환: 새로 등록했는가
function PlayerProfile.registerBossGate(player, bossId)
	local profile = profiles[player]
	if not profile or profile.world.bossGates[bossId] then
		return false
	end
	profile.world.bossGates[bossId] = true
	return true
end

function PlayerProfile.isBossGateRegistered(player, bossId)
	local profile = profiles[player]
	return profile ~= nil and profile.world.bossGates[bossId] == true
end

-- 등록된 보스 id 목록(정렬)
function PlayerProfile.getRegisteredBossGates(player)
	local profile = profiles[player]
	local list = {}
	for id in pairs(profile and profile.world.bossGates or {}) do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

function PlayerProfile.getOpenPortals(player)
	local profile = profiles[player]
	return profile and profile.world.portals or {}
end

function PlayerProfile.addCharacterExp(player, amount)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return nil, nil
	end
	local oldLevel = CharacterLevel.getLevelFromExp(classState.characterExp)
	-- S21-0 A2: 보상 계산 출구.
	-- P2.5c 결정 3: 환생 회차 배율(CharacterLevel.getRebirthExpMultiplier)은 캐릭터 경험치에만 - 재료 기대 개수가 쓰는 getExpGainMultiplier에는 안 넣는다.
	-- P3c C4: 레벨 126부터 필요 경험치와 같은 배수(CharacterLevel.getExpScale - 지금 레벨 기준)를 곱한다 - 처치 수는 그대로.
	classState.characterExp += Sanitize.number(amount * PlayerProfile.getExpGainMultiplier(player) * CharacterLevel.getRebirthExpMultiplier(classState.rebirthCount)
		* CharacterLevel.getExpScale(oldLevel), 0)
	local newLevel = CharacterLevel.getLevelFromExp(classState.characterExp)
	player:SetAttribute("CharacterExp", classState.characterExp)
	if newLevel ~= oldLevel then
		player:SetAttribute("CharacterLevel", newLevel)
		PlayerProfile.notePeakLevel(player)
		PlayerProfile.claimMilestones(player, true) -- P2.5b D · P2.5c B2: 마일스톤 레벨을 넘었으면 보상 + 토스트
	end
	return oldLevel, newLevel
end

-- ═══ 환생 후 레벨 마일스톤(P2.5b D · P2.5c B2) ═══
-- 공격력 배율 = 1 + 마일스톤 버킷(버킷이 공격력 쪽일 때 - Milestone.attackMultiplier). 활성 직업이 받은 마지막 마일스톤 레벨에서 나온다.
function PlayerProfile.getMilestoneMultiplier(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return 1
	end
	return Milestone.attackMultiplier(classState.milestoneLevel or 0)
end

-- 최대 체력 배율(버킷이 최대 체력 쪽일 때만 1이 아니다 - Milestone.maxHpMultiplier).
function PlayerProfile.getMilestoneMaxHpMultiplier(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return 1
	end
	return Milestone.maxHpMultiplier(classState.milestoneLevel or 0)
end

-- 해금 효과를 그 순간 적용한다(계정 효과 - 한 번만). 예약(reserved) 해금은 기록만 남는다.
local function applyMilestoneUnlock(player, profile, entry)
	if entry.bagSlots then
		profile.inventorySlots += entry.bagSlots
		InventorySync.push(player, profile)
	end
end

-- 활성 직업의 지금 레벨로 마일스톤 기록을 갱신하고 새로 받은 보상을 적용한다(Milestone.plan). notify = 토스트용 알림을 보낸다.
-- 부르는 곳: 레벨이 바뀔 때(addCharacterExp · setCharacterExpDirect) · 로드(init) · 직업 전환(setClassId). 반환: 알림 표 | nil(새로 받은 것 없음).
function PlayerProfile.claimMilestones(player, notify)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return nil
	end
	local level = CharacterLevel.getLevelFromExp(classState.characterExp)
	local plan = Milestone.plan(classState.rebirthCount, level, classState.milestoneLevel or 0, profile.milestoneUnlocks)
	if not plan or (plan.statGained <= 0 and plan.unlockTo < plan.unlockFrom) then
		return nil
	end
	if plan.statGained > 0 then
		classState.milestoneLevel = plan.claimedLevel
	end
	local unlocked = {}
	for index = plan.unlockFrom, plan.unlockTo do
		local entry = MilestoneData.unlocks[index]
		applyMilestoneUnlock(player, profile, entry)
		table.insert(unlocked, { index = index, id = entry.id, name = entry.name, level = Milestone.unlockLevel(index), reserved = entry.reserved == true })
	end
	profile.milestoneUnlocks = math.max(profile.milestoneUnlocks, plan.unlockTo)
	syncMilestoneAttributes(player, profile)
	if plan.statGained > 0 then
		PlayerProfile.refreshMaxHp(player)
	end
	local claimed = classState.milestoneLevel or 0
	local payload = { level = level, statGained = plan.statGained, claimedLevel = claimed, bonus = Milestone.bonusFor(claimed), multiplier = Milestone.multiplier(claimed), unlocks = unlocked }
	if notify then
		MilestoneNotice.push(player, payload)
	end
	return payload
end

-- 성장 보상 창(MilestoneFetch)이 그리는 값. 직업을 안 골랐으면 빈 요약.
function PlayerProfile.getMilestoneSummary(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return { rebirthCount = 0, level = 1, claimedLevel = 0, bonus = 0, unlockCount = profile and profile.milestoneUnlocks or 0 }
	end
	local claimed = classState.milestoneLevel or 0
	return {
		rebirthCount = classState.rebirthCount,
		level = CharacterLevel.getLevelFromExp(classState.characterExp),
		claimedLevel = claimed,
		bonus = Milestone.bonusFor(claimed),
		unlockCount = profile.milestoneUnlocks,
	}
end

function PlayerProfile.getWeapon(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.weapon
end

-- 강화 천장 게이지(28-1 S03) - 지금 직업의 무기에 딸린 0 ~ EnhanceConfig.gauge.max 정수. 서버만 쓴다(EnhanceService의 강화 판정 직후). 값이 바뀌면 Attribute
-- EnhanceGauge(S07)로 내린다 - 클라(강화 UI)는 이 Attribute만 읽는다(WeaponLevel과 같은 방식).
function PlayerProfile.getEnhanceGauge(player)
	local weapon = PlayerProfile.getWeapon(player)
	return weapon and weapon.enhanceGauge or 0
end

function PlayerProfile.setEnhanceGauge(player, value)
	local weapon = PlayerProfile.getWeapon(player)
	if weapon then
		weapon.enhanceGauge = value
		player:SetAttribute("EnhanceGauge", value)
	end
end

-- 서버만 호출한다(EnhanceServer의 강화 판정 직후). 클라이언트가 보낸 값을 믿지 않는다.
function PlayerProfile.setWeaponLevel(player, level)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.weapon.level = level
	player:SetAttribute("WeaponLevel", level)
end

-- 서버만 호출한다(DevTools.server.lua "/gg weapon" - 20-1 [1], 정상 플레이 경로엔 아직
-- 등급을 올리는 수단이 없다. 환생이 유일한 경로가 될 예정이고 그건 이번 범위 밖이다).
function PlayerProfile.setWeaponGrade(player, grade)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.weapon.grade = grade
	player:SetAttribute("WeaponGrade", grade)
end

function PlayerProfile.getClassId(player)
	local profile = profiles[player]
	return profile and profile.classId
end

-- 서버만 호출한다(ClassServer의 검증 직후). 클라이언트가 보낸 classId를 그대로 믿지 않는다 -
-- 존재하는 클래스인지는 호출부(ClassServer.server.lua)가 ClassData로 이미 확인했다.
-- 19-1: 직업이 바뀌어도 각 직업의 진행도는 classes[classId] 아래에 그대로 남는다(삭제·
-- 초기화 없음) - classId는 그중 "지금 어느 걸 쓰는가"만 가리키는 포인터로 바뀐다.
function PlayerProfile.setClassId(player, classId)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.classId = classId
	PlayerProfile.claimMilestones(player, false) -- P2.5b D: 그 직업의 지금 회차 기록을 채운다(알림 없음)
	syncActiveClassAttributes(player, profile)
	InventorySync.push(player, profile)
end

function PlayerProfile.getInfiniteStage(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.stageProgress.infinite
end

function PlayerProfile.getInfiniteStageBest(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.stageProgress.infiniteBest
end

function PlayerProfile.getAccountBestStage(player)
	local profile = profiles[player]
	return profile and accountBestStageOf(profile) or 1
end

-- 서버만 호출한다(StageServer의 검증 직후). 새 최고 기록을 세웠으면 true를 돌려준다 -
-- 호출부가 그때만 즉시저장(ImmediateSave)을 건다. 단순 이동(현재 스테이지 변경)은
-- 골드처럼 잃을 자원이 없는 되돌릴 수 있는 사건이라 주기저장(60초)·퇴장저장으로
-- 충분하다고 판단했다 - 최고 기록만 "다시 오르면 그만"이 아니라 경쟁 축(PRD 20.12)의
-- 실제 성취라 크래시로 잃으면 아쉬움이 다르다.
function PlayerProfile.setInfiniteStage(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false
	end
	classState.stageProgress.infinite = stage
	player:SetAttribute("InfiniteStage", stage)

	local isNewBest = stage > classState.stageProgress.infiniteBest
	if isNewBest then
		classState.stageProgress.infiniteBest = stage
		player:SetAttribute("InfiniteStageBest", stage)
		syncAccountBestStage(player, profile)
	end
	return isNewBest
end

function PlayerProfile.getBestBossCleared(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.stageProgress.bestBossCleared
end

-- 서버만 호출한다(AttackServer의 보스 처치 판정 직후). stage가 이미 기록된 값 이하면
-- 아무것도 안 한다 - 이 값은 "최고 기록"이라 내려갈 일이 없다(infiniteBest와 같은 원칙).
function PlayerProfile.setBossCleared(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState or stage <= classState.stageProgress.bestBossCleared then
		return
	end
	classState.stageProgress.bestBossCleared = stage
	player:SetAttribute("BestBossCleared", stage)
end

-- P3a A: 보스 클리어로 개인 최고가 오른 멤버의 도달(infiniteBest)도 그 보스 스테이지까지 끌어올린다 - 파티원은 보스 스테이지로 직접 갈 수 없어(리더만)
-- 옛 코드에서는 파티 보스를 깨도 도달이 안 올라 다음 스테이지로 못 갔다("리더만 갱신"). 지금 스테이지(infinite)는 건드리지 않는다. 오르면 true.
function PlayerProfile.raiseInfiniteBest(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState or stage <= classState.stageProgress.infiniteBest then
		return false
	end
	classState.stageProgress.infiniteBest = stage
	player:SetAttribute("InfiniteStageBest", stage)
	syncAccountBestStage(player, profile)
	return true
end

-- P3a B3: "/gg 명령으로 만든 진도는 기록하지 않는다" - 이 계정에서 /gg가 한 번이라도 돌면 켜진다(계정 단위 · 저장 v34). 켜진 계정은 리더보드에 쓰지 않는다.
function PlayerProfile.markLeaderboardTainted(player)
	local profile = profiles[player]
	if profile and not profile.leaderboardTainted then
		profile.leaderboardTainted = true
	end
end

function PlayerProfile.isLeaderboardTainted(player)
	local profile = profiles[player]
	return profile == nil or profile.leaderboardTainted == true
end

-- 자동 검증 전용 - 검증이 쓰기 경로를 재려고 잠깐 끈다(스냅샷 복원이 원래 값으로 되돌린다).
function PlayerProfile.setLeaderboardTaintedForDevTools(player, value)
	local profile = profiles[player]
	if profile then
		profile.leaderboardTainted = value == true
	end
end

-- 29-5: 보스의 정체는 스테이지 번호만의 함수다(BossRules.bossIdForStage) - 23-5의 플레이어별 순환(getBossForStage ·
-- pending · "/gg boss force"의 debugForceNextId)은 여기서 없앴다. 세이브의 classState.bossRotation 필드는 그대로 두고
-- 읽지 않는다(SaveSystem - 옛 세이브가 검증·이관을 그대로 통과한다).

-- 20-4 [1] 신설, 23-2부터 PlayerProfile.rebirth가 이 값을 올리는 유일한 정식 통로다 -
-- 보스 첫 처치 확정 드랍 등급표 분기(Loot.rollBossFirstClearDrop)도 여전히 이 값을 본다.
function PlayerProfile.getRebirthCount(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return (classState and classState.rebirthCount) or 0
end

-- 서버만 호출한다(DevTools "/gg rebirth <n>" 전용 - rebirthCount만 강제로 바꾼다, 무기
-- 등급·보석 슬롯은 건드리지 않는다 - 슬롯 UI가 "몇 칸 열렸는가"만 빠르게 확인하려는
-- 용도라 실제 환생의 부수효과까지 재현할 필요가 없다. 실제 환생 전체 흐름 검증은
-- PlayerProfile.rebirth를 직접 타는 "/gg rebirthdo"를 쓴다. snapshotForDevTools/
-- restoreForDevTools의 deepCopy(profile.classes)가 rebirthCount도 같이 백업/복원한다).
function PlayerProfile.setRebirthCountDirect(player, count)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.rebirthCount = count
end

-- 환생 실행(23-2, PRD 20.38 [1][2]). 되돌릴 수 없는 조작이다 - 서버에서만 처리하고
-- (RebirthServer.server.lua의 RebirthRequest 핸들러가 이 함수만 부른다), 확인 없이 즉시
-- 실행되지 않도록 클라이언트(EnhanceUI.client.lua 환생 탭)가 확인창을 먼저 띄운다(지시 그대로).
--
-- 반환값: (성공 여부, 실패 이유 또는 새 rebirthCount, 실패 시 필요 레벨).
--   "no_class"       - 아직 직업을 안 골랐다.
--   "max_rebirth"     - 이미 5회 전부 마쳤다(GemData.maxRebirthCount).
--   "level_too_low"   - 그 회차의 목표 레벨(CharacterLevel.getRebirthRequiredLevel - P2 전 25×(rebirthCount+1))에 아직 못 미쳤다.
--
-- 25-1: 레벨 곡선은 환생 회차와 무관하게 하나다(CharacterLevel 주석) - 환생은 characterExp를
-- 0으로 되돌릴 뿐 곡선 분기를 바꾸지 않는다.
function PlayerProfile.rebirth(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	if classState.rebirthCount >= GemData.maxRebirthCount then
		return false, "max_rebirth"
	end

	local requiredLevel = CharacterLevel.getRebirthRequiredLevel(classState.rebirthCount)
	local currentLevel = CharacterLevel.getLevelFromExp(classState.characterExp)
	if currentLevel < requiredLevel then
		return false, "level_too_low", requiredLevel
	end

	classState.rebirthCount += 1
	classState.characterExp = 0
	-- 무한 스테이지도 1로 되돌린다(PRD에 명시된 문구는 없다 - "임의 결정" 목록 참고).
	-- 근거: 목표 마릿수 곡선(25-1, CharacterLevelConfig.killTargetAnchors)은 "몬스터 스테이지=
	-- 캐릭터 레벨(rec(L)=L, 20.44 앵커)에서 사냥할 때"가 전제다. 레벨은 1로 리셋되는데
	-- 스테이지가 예전 그대로면(예: 환생 전 스테이지500) 몬스터가 압도적으로 강해 그라인드
	-- 자체가 성립하지 않는다. infiniteBest(최고 기록)는 건드리지 않는다 - 그건 영구
	-- 성취 기록이라 파밍 위치가 낮아져도 내려가면 안 된다(setInfiniteStage와 같은 원칙).
	classState.stageProgress.infinite = 1
	-- 무기 등급 = 환생 회차(0~5가 1~5 등급 index와 그대로 대응, 20.38 [2] 표).
	classState.weapon.grade = classState.rebirthCount

	-- 슬롯 k(=이번 회차)가 지금 열리고, 그 자리에 확정 보석 1개가 자동 지급된다(20.38 [2]
	-- "슬롯이 열릴 때 그 등급의 보석 1개가 확정 지급된다", 23-4부터 등급은 그 슬롯의 상한).
	local slot = classState.rebirthCount
	-- P2.5a D(결정 9): 환생 지급 보석의 itemLevel = 환생 순간의 캐릭터 레벨을 스테이지 척도로 옮긴 값(CharacterLevel.getStageForLevel - 태초 보석(= 사냥 스테이지)과
	-- 같은 척도, C10). 옛 값 25 × 회차.
	classState.weapon.gems[slot] = Gem.buildGrantedGem(slot, profile.classId, CharacterLevel.getStageForLevel(currentLevel))

	-- 23-4: 해금 상태를 저장 필드에 기록한다(GemData.slotUnlockRequiredRebirth 주석 참고) -
	-- 매번 rebirthCount에서 다시 계산하지 않는다. 지금 조건은 여전히 1:1(slot i = 환생
	-- i회)이라 이번 환생으로 딱 하나(slot)만 새로 열리지만, 나중에 조건표가 바뀌어도(예:
	-- 한 회차에 두 슬롯이 같이 열림) 이 루프가 그대로 맞다.
	for s = 1, Gem.slotCount do
		if classState.rebirthCount >= GemData.slotUnlockRequiredRebirth[s] then
			classState.weapon.slotUnlocked[s] = true
		end
	end

	-- 태초(index6)는 환생만으로 못 간다 - "환생 5회 + 보석 5칸 전부 장착"이 별도 조건
	-- (20.38 [2]). 슬롯이 열릴 때마다 자동으로 채워지므로(바로 위 줄) 5회차에 도달한
	-- 순간 이 조건이 항상 같이 성립한다(PlayerProfile.equipGem은 "교체"만 하지 슬롯을
	-- 비우지 않으므로, 나중에 다시 빈 슬롯이 생길 방법이 없다) - 그 우연한 정합성을
	-- 20.38 [2]가 이미 기록해 뒀다.
	if classState.rebirthCount == GemData.maxRebirthCount and Gem.allSlotsFilled(classState.weapon.gems) then
		classState.weapon.grade = 6
	end

	-- 레벨·무기 등급·보석 슬롯 Attribute를 한 번에 맞춘다(setClassId와 같은 지점 - 과거
	-- InventorySync.push를 빠뜨렸던 버그와 같은 종류의 실수를 막는다). 장비(갑옷/장갑/
	-- 신발)는 환생으로 바뀌지 않지만, 무기 등급이 오르며 itemLevel 상대 가치가 달라지는
	-- 것과 무관하게 인벤토리 스냅샷은 항상 최신으로 밀어 둔다.
	syncActiveClassAttributes(player, profile)
	InventorySync.push(player, profile)
	GemSync.push(player)

	return true, classState.rebirthCount
end

-- 상위 5등급(영웅~태초, ArmorData.gradeOrder index 3~7) 방어구 → 같은 등급 보석 1개
-- (23-2, PRD 20.38 [3] "분해 가능 등급을 상위 5등급으로 확장"). 분해는 골드 없이 보석만
-- 준다(20.37 [3] "분해는 보석만, 판매는 골드만" - 판매(sellItem)와 상호 배타적인 자원이라
-- 별도 배율 조정이 필요 없다는 설계). 잠긴 아이템은 판매와 같은 이유로 분해도 막는다.
--
-- 23-3: optionId를 더 이상 여기서 굴리지 않는다(예전엔 Gem.rollOption(item.grade)를
-- 불렀다) - 고대·태초 방어구를 반복 분해하면 옵션 변환권 없이 옵션을 공짜로 재굴림하는
-- 구멍이었다(GemData.lua "[옵션 배정]" 주석).
-- 26-1(PRD 20.67 [1][13]): "분해 시 옵션 처리는 그대로 이전(재굴림 없음)"으로 바뀐다 - 위
-- 23-3 결정(공짜 재굴림 방지)은 그대로 유지되면서(여기서 새로 옵션을 굴리지 않는다), 그
-- 아이템이 생성 시점에 이미 가진 option·itemLevel을 그대로 보석으로 옮긴다.
local DISMANTLE_MIN_GRADE_INDEX = ArmorData.dismantleMinGradeIndex -- G1-2: 데이터로(ArmorData - 영웅부터, 값 그대로)

function PlayerProfile.dismantleItem(player, index)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	local item = profile.inventory[index]
	if not item then
		return false, "not_found"
	end
	if item.locked then
		return false, "locked"
	end
	local itemGradeIndex = gradeIndex(item.grade)
	if not itemGradeIndex or itemGradeIndex < DISMANTLE_MIN_GRADE_INDEX then
		return false, "grade_too_low"
	end

	table.remove(profile.inventory, index)
	table.insert(classState.gemInventory, { grade = item.grade, itemLevel = item.itemLevel, option = item.option })
	InventorySync.push(player, profile)
	GemSync.push(player)
	return true, item.grade
end

-- ═══ 보석 가루(P2.5b C) ═══
-- 증감 통로는 이 함수 하나(분해가 더하고 재련 · 변환권 구매가 뺀다 - 빼는 쪽은 호출부가 먼저 잔량을 확인한다). Attribute GemDust로 클라에 내린다.
function PlayerProfile.addGemDust(player, amount)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.gemDust = math.max(0, profile.gemDust + math.floor(Sanitize.number(amount, 0)))
	player:SetAttribute("GemDust", profile.gemDust)
end

function PlayerProfile.getGemDust(player)
	local profile = profiles[player]
	return profile and profile.gemDust or 0
end

-- 보석 가방의 보석 1개 → 가루(C1). 홈에 낀 보석은 대상이 아니다(가방 index만 받는다). 반환: true, 가루 | false, 이유("no_class" · "not_found").
function PlayerProfile.dismantleGem(player, index)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	local gem = classState.gemInventory[index]
	if not gem then
		return false, "not_found"
	end
	local dust = GemCraft.dustYield(gem)
	table.remove(classState.gemInventory, index)
	PlayerProfile.addGemDust(player, dust)
	GemSync.push(player)
	return true, dust
end

-- P3c E4: 보석 판매 - 가방의 보석 1개 → 골드(GemCraft.sellPrice · 계정 최고 스테이지). 홈에 낀 보석은 대상이 아니다(분해와 같다). 반환: 성공, 판매가 | 이유.
function PlayerProfile.sellGem(player, index)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	local gem = classState.gemInventory[index]
	if not gem then
		return false, "not_found"
	end
	local price = Sanitize.number(GemCraft.sellPrice(gem, PlayerProfile.getAccountBestStage(player)), 0) -- S21-0 A2: 보상 계산 출구
	table.remove(classState.gemInventory, index)
	profile.gold += price
	player:SetAttribute("Gold", profile.gold)
	GemSync.push(player)
	return true, price
end

-- 일괄 분해(C2): 가방 보석 중 cutoffGradeId 이하 등급 전부 → 가루. 목록을 먼저 다 계산한 뒤 한 번에 바꾼다(sellItemsBulkUpTo와 같은 원칙 - 중간 yield 없음). 반환: 개수, 가루.
function PlayerProfile.dismantleGemsUpTo(player, cutoffGradeId)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState or type(cutoffGradeId) ~= "string" then
		return 0, 0
	end
	local remaining, count, dust = {}, 0, 0
	for _, gem in ipairs(classState.gemInventory) do
		if GemCraft.isBulkTarget(gem, cutoffGradeId) then
			count += 1
			dust += GemCraft.dustYield(gem)
		else
			table.insert(remaining, gem)
		end
	end
	if count == 0 then
		return 0, 0
	end
	classState.gemInventory = remaining
	PlayerProfile.addGemDust(player, dust)
	GemSync.push(player)
	return count, dust
end

-- 보석 재련(P2.5b B): 대상(홈 targetKind = "slot" · key = 홈 번호 / 가방 "bag" · key = index)에 가방 보석(fodderIndex)을 먹여 대상 itemLevel = 먹이 itemLevel.
-- 등급 · 옵션(종류 · 굴림)은 그대로 - 수치는 Option.valueOf가 새 레벨로 다시 계산한다. 먹이는 사라진다. 장착 중인 보석도 그대로 된다(해제 불필요 - B2).
-- 비용 = 골드(GemCraft.refineCost - 계정 최고 스테이지) + 가루. 가루를 먼저 확인한다(골드만 빠지고 실패하는 일이 없다). 되돌릴 수 없다(호출부가 즉시저장).
-- 반환: true, 새 레벨 | false, 이유("no_class" · "invalid" · GemCraft.refineBlockReason의 코드 · "no_dust" · "no_gold").
function PlayerProfile.refineGem(player, targetKind, targetKey, fodderIndex)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	local target
	if targetKind == "slot" then
		target = Gem.isFilled(classState.weapon.gems, targetKey) and classState.weapon.gems[targetKey] or nil
	elseif targetKind == "bag" then
		target = classState.gemInventory[targetKey]
	else
		return false, "invalid"
	end
	local fodder = classState.gemInventory[fodderIndex]
	local reason = GemCraft.refineBlockReason(target, fodder)
	if reason then
		return false, reason
	end
	local goldCost, dustCost = GemCraft.refineCost(target.grade, accountBestStageOf(profile))
	if profile.gemDust < dustCost then
		return false, "no_dust"
	end
	if not PlayerProfile.trySpendGold(player, goldCost) then
		return false, "no_gold"
	end
	PlayerProfile.addGemDust(player, -dustCost)
	target.itemLevel = fodder.itemLevel
	table.remove(classState.gemInventory, fodderIndex)
	GemSync.push(player)
	if targetKind == "slot" then
		PlayerProfile.refreshMaxHp(player) -- 장착 중 보석의 수치가 바뀌었다(건강 · 신속 축이면 그 자리에서 반영 - equipGem과 같은 이유)
		PlayerProfile.refreshMovementSpeed(player)
	end
	return true, target.itemLevel
end

function PlayerProfile.getGemInventory(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.gemInventory
end

function PlayerProfile.getWeaponGems(player)
	local weapon = PlayerProfile.getWeapon(player)
	return weapon and weapon.gems
end

-- 보석 인벤토리의 한 개를 슬롯에 장착한다(20.38 [2] "분해로 얻는 보석은 슬롯에 교체
-- 장착하는 용도"). 슬롯은 항상 미리 자동 지급된 보석으로 채워져 있으므로(rebirth 참고)
-- 이 동작은 언제나 "교체"다 - 기존 슬롯 보석은 버려지지 않고 인벤토리로 돌아간다
-- (equipItem의 "먼저 빼고 나중에 넣는다" 순서와 같은 원칙). 23-4: "등급 일치"가 아니라
-- "등급 상한 이하"로 검증한다(Gem.canSocket) - 낮은 등급 보석을 높은 등급 홈에 꽂을 수
-- 있다(지시 "높은 등급 홈에는 그 이하 등급 보석을 모두 장착할 수 있다").
function PlayerProfile.equipGem(player, slot, gemInventoryIndex)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	if not Gem.isSlotUnlocked(classState.weapon.slotUnlocked, slot) then
		return false, "slot_locked"
	end
	local pending = classState.gemInventory[gemInventoryIndex]
	if not pending then
		return false, "not_found"
	end
	if not Gem.canSocket(pending.grade, slot) then
		return false, "grade_too_high"
	end

	table.remove(classState.gemInventory, gemInventoryIndex)
	if Gem.isFilled(classState.weapon.gems, slot) then
		-- 26-1: itemLevel·option(PRD 20.67 [13])도 같이 옮긴다 - 안 옮기면 슬롯 교체마다
		-- 그 보석이 생성 시점에 굴린 옵션이 조용히 사라진다(optionId만 옮기던 23-2 그대로
		-- 두면 새 필드가 여기서 빠진다).
		local previous = classState.weapon.gems[slot]
		table.insert(classState.gemInventory, {
			grade = previous.grade, optionId = previous.optionId,
			itemLevel = previous.itemLevel, option = previous.option,
		})
	end
	classState.weapon.gems[slot] = {
		optionId = pending.optionId, grade = pending.grade,
		itemLevel = pending.itemLevel, option = pending.option,
	}
	GemSync.push(player)
	-- 23-3: 교체된 보석의 축이 방어력·최대체력이면 그 자리에서 바로 반영해야 한다(장갑·
	-- 갑옷 교체와 같은 지점, refreshMaxHp/refreshMovementSpeed 주석 참고) - 공격력·공속은
	-- 다음 평타/이동 판정 때 PlayerProfile.getAttackPercentBonus/getSpeedPercentBonus가
	-- 매번 새로 계산하므로 별도 갱신이 필요 없지만, 최대체력(PlayerState 캐시)과 WalkSpeed
	-- (Humanoid 프로퍼티)는 그 지점에서만 반영되는 값이라 여기서 강제로 재계산해야 한다.
	PlayerProfile.refreshMaxHp(player)
	PlayerProfile.refreshMovementSpeed(player)
	return true
end

function PlayerProfile.getOptionRerollTickets(player)
	local profile = profiles[player]
	return profile and profile.purchases.optionRerollTickets
end

-- 골드로 변환권 하나를 산다(20.37 [5] - 가격은 "그 순간 몬스터 1마리당 골드×N", 계산은
-- 호출부(GemServer.server.lua)가 InfiniteStage.getGoldReward로 매번 다시 구해 cost로
-- 넘긴다 - 여기선 이미 계산된 가격을 원자적으로 차감·지급만 한다, EnhanceServer의 골드
-- 확인+차감 분리 원칙과 같다).
-- P2.5b C: 변환권 1장 = 골드 + 보석 가루(GemCraft.ticketDust). 둘 다 있어야 산다(가루 먼저 확인 - 골드만 빠지고 실패하는 일이 없다). 반환: true | false, 이유("invalid" · "no_dust" · "no_gold").
function PlayerProfile.tryBuyOptionRerollTicket(player, gradeId, cost)
	local profile = profiles[player]
	if not profile or not profile.purchases.optionRerollTickets[gradeId] then
		return false, "invalid"
	end
	local dust = GemCraft.ticketDust(gradeId)
	if profile.gemDust < dust then
		return false, "no_dust"
	end
	if not PlayerProfile.trySpendGold(player, cost) then
		return false, "no_gold"
	end
	PlayerProfile.addGemDust(player, -dust)
	profile.purchases.optionRerollTickets[gradeId] += 1
	GemSync.push(player)
	return true
end

-- 고대·태초 등급 보석의 옵션을 재굴림한다(20.5-1 "옵션 변환권", GemData.optionPoolByGrade가
-- 그 두 등급만 풀을 가져 재굴림 대상도 그 둘뿐이다 - Gem.isRerollableGrade). 변환권 1장을
-- 소모한다. 26-3(PRD 20.67 [10]): 옛 4개 이름 풀(Gem.rollOption)이 아니라 통합 옵션 풀
-- (Option.rollFor, 공통 8 + 현재 직업 특화 2)에서 id·롤 둘 다 새로 굴린다 - "얼마나 잘
-- 뽑았는지"가 보여야 리롤 욕구가 생긴다는 지시 그대로(옛 optionId 필드는 더 이상 쓰지
-- 않는다 - 3단계에서 이미 폐기된 옛값 경로다).
function PlayerProfile.rerollGemOption(player, slot)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	if not Gem.isFilled(classState.weapon.gems, slot) then
		return false, "empty_slot"
	end
	local gem = classState.weapon.gems[slot]
	if not Gem.isRerollableGrade(gem.grade) then
		return false, "not_rerollable"
	end
	local tickets = profile.purchases.optionRerollTickets
	if (tickets[gem.grade] or 0) < 1 then
		return false, "no_ticket"
	end

	tickets[gem.grade] -= 1
	gem.optionId = nil
	gem.option = Option.rollFor(gem.grade, profile.classId)
	GemSync.push(player)
	-- 23-3: equipGem과 같은 이유(축이 바뀌면 최대체력·이동속도가 그 자리에서 바뀔 수 있다).
	PlayerProfile.refreshMaxHp(player)
	PlayerProfile.refreshMovementSpeed(player)
	return true, gem.option and gem.option.id
end

-- 26-3(PRD 20.67 [10]): 착용 중인 장비도 보석과 같은 규칙으로 리롤한다(고대·태초만, 변환권
-- 소모, 옵션 id·롤 둘 다 새로 굴림) - Gem.isRerollableGrade·Option.rollFor를 그대로
-- 재사용한다(새 계산식을 만들지 않는다).
function PlayerProfile.rerollEquippedOption(player, part)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "no_class"
	end
	local item = classState.equipment[part]
	if not item then
		return false, "not_equipped"
	end
	if not Gem.isRerollableGrade(item.grade) then
		return false, "not_rerollable"
	end
	local tickets = profile.purchases.optionRerollTickets
	if (tickets[item.grade] or 0) < 1 then
		return false, "no_ticket"
	end

	tickets[item.grade] -= 1
	item.option = Option.rollFor(item.grade, profile.classId)
	InventorySync.push(player, profile)
	GemSync.push(player) -- 변환권 잔량도 이 스냅샷에 실려 간다(gem 탭·이 리롤 버튼 둘 다 이 값을 본다).
	PlayerProfile.refreshMaxHp(player)
	PlayerProfile.refreshMovementSpeed(player)
	return true, item.option and item.option.id
end

-- 26-3: 가방 안(미착용) 장비 리롤 - 착용 리롤과 같은 규칙, 최대체력·이동속도에 영향이
-- 없으므로 refresh 호출이 없다(미착용 아이템은 전투 스탯에 기여하지 않는다).
function PlayerProfile.rerollBagItemOption(player, index)
	local profile = profiles[player]
	if not profile then
		return false, "no_class"
	end
	local item = profile.inventory[index]
	if not item then
		return false, "not_found"
	end
	if not Gem.isRerollableGrade(item.grade) then
		return false, "not_rerollable"
	end
	local tickets = profile.purchases.optionRerollTickets
	if (tickets[item.grade] or 0) < 1 then
		return false, "no_ticket"
	end

	tickets[item.grade] -= 1
	item.option = Option.rollFor(item.grade, profile.classId)
	InventorySync.push(player, profile)
	GemSync.push(player)
	return true, item.option and item.option.id
end

-- "그 스테이지 보스를 확정 보상으로 이미 받았는가"(20-4 [1]) - bestBossCleared(단조증가
-- 최고 기록, StageServer 게이트가 쓴다)와 별개의 집합이다. 재입장 자체는 막지 않되
-- (지시 원문) 확정 보상은 스테이지당 한 번만 나가야 하므로 이 기록으로 판정한다.
function PlayerProfile.hasBossFirstClearReward(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState ~= nil and classState.stageProgress.bossFirstClearStages[tostring(stage)] == true
end

-- 서버만 호출한다(CombatResolution.grantKillReward, 확정 드랍을 이미 지급한 직후).
-- bossFirstClearStages · tutorial.granted의 키는 문자열(tostring)이다(v28) - DataStore 왕복이 숫자 키를 문자열로 바꿔 돌려주므로 숫자 키로 조회하면 재접속 뒤 못 찾는다
-- (hasClaimedProtectionStage 주석). 바깥 API는 그대로 숫자를 받는다.
function PlayerProfile.markBossFirstClearReward(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.stageProgress.bossFirstClearStages[tostring(stage)] = true
end

-- 서버만 호출한다(DevTools "/gg bossreset [stage]" 전용 - 같은 스테이지를 다른 rebirthCount
-- 조건으로 반복 검증하려면 첫 처치 기록을 지워야 한다). stage를 생략하면 전부 지운다.
function PlayerProfile.clearBossFirstClearRewards(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	if stage then
		classState.stageProgress.bossFirstClearStages[tostring(stage)] = nil
	else
		classState.stageProgress.bossFirstClearStages = {}
	end
end

-- 23-1 견습 모드 진행도(profile.tutorial) - 계정 전체 공유(gold·classId와 같은 층, PRD
-- 20.47[3] "완료 플래그는 계정 단위" 그대로). 직업별 진행도(classes[classId])와 절대 섞지
-- 않는다 - 지시 "무한 모드 stage 필드는 건드리지 마라"의 구조적 보장이다.
function PlayerProfile.getTutorialStep(player)
	local profile = profiles[player]
	return profile and profile.tutorial.step
end

function PlayerProfile.getTutorialCompleted(player)
	local profile = profiles[player]
	return profile ~= nil and profile.tutorial.completed
end

-- 서버만 호출한다(TutorialState). Attribute도 같이 맞춰 클라이언트 HUD(TutorialHud.client.lua)가
-- 읽을 수 있게 한다 - InfiniteStage와 같은 패턴.
function PlayerProfile.setTutorialStep(player, step)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.tutorial.step = step
	player:SetAttribute("TutorialStep", step)
end

function PlayerProfile.setTutorialCompleted(player, completed)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.tutorial.completed = completed
	player:SetAttribute("TutorialCompleted", completed)
end

-- "그 단계의 영구 지급(grant)을 이미 받았는가" - bossFirstClearStages와 같은 목적(재플레이
-- 중복 지급 방지). 완료 보상(7단계, TutorialData.tutorialCompletionGold)도 stepIndex=7로
-- 같은 집합을 쓴다 - 7단계는 grant 아이템이 없지만 완료 보상도 "그 단계 보상"이라는 점에서
-- 동일하다.
function PlayerProfile.hasTutorialGrant(player, stepIndex)
	local profile = profiles[player]
	return profile ~= nil and profile.tutorial.granted[tostring(stepIndex)] == true
end

function PlayerProfile.markTutorialGrant(player, stepIndex)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.tutorial.granted[tostring(stepIndex)] = true
end

-- 대여 복원 원본(23-1) - 4단계 이상에서 무기 등급·장비 3부위를 일시적으로 덮어쓰기 전
-- 원래 값을 저장해 둔다. 세션 메모리(TutorialState)가 아니라 저장 데이터에 두는 이유:
-- 대여 중 자동저장(60초)이나 서버 크래시가 끼어들면 세션 메모리는 날아가도 이 값은
-- 남아 있어야 재접속 시 무엇을 돌려줘야 할지 알 수 있다("빌린 태초 무기가 영구히 남는"
-- 사고를 막는 유일한 안전장치). nil이면 "지금 대여 중이 아니다"라는 뜻이다.
function PlayerProfile.getTutorialLendBaseline(player)
	local profile = profiles[player]
	return profile and profile.tutorial.lendBaseline
end

function PlayerProfile.setTutorialLendBaseline(player, baseline)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.tutorial.lendBaseline = baseline
end

-- 직업 변경 확인창(19-1)이 "레벨 X · 최고 스테이지 Y로 이어집니다"를 보여주기 위해
-- 4직업 전부의 요약을 한 번에 돌려준다. Attribute(CharacterLevel 등)는 활성 직업 하나만
-- 알아서, 아직 켜지 않은 나머지 직업을 미리 보여줄 수 없어 따로 둔다(ClassServer의
-- ClassSummaryFetch가 그대로 클라이언트에 전달).
function PlayerProfile.getClassSummaries(player)
	local profile = profiles[player]
	if not profile then
		return {}
	end
	local summaries = {}
	for classId, classState in pairs(profile.classes) do
		summaries[classId] = {
			level = CharacterLevel.getLevelFromExp(classState.characterExp),
			stageBest = classState.stageProgress.infiniteBest,
		}
	end
	return summaries
end

function PlayerProfile.getInventory(player)
	local profile = profiles[player]
	return profile and profile.inventory
end

-- 부위 무관 공용 조회(16-6, EquipSlots.order의 아무 부위나 받는다). 19-1부터 활성
-- 직업의 장비를 본다 - 직업을 안 골랐으면(classState 없음) nil.
function PlayerProfile.getEquipped(player, part)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	return classState and classState.equipment[part]
end

function PlayerProfile.getEquippedArmor(player)
	return PlayerProfile.getEquipped(player, "armor")
end

-- 신발 이동+공속 비율 보너스(16-6, 기존 장비 기본효과 - 옵션과 별개 층, 20.67 [1] "부위
-- 기본 스탯 축을 제외하지 않는다") + 장비 3부위 옵션 + 보석 5개의 speedPercent 옵션 합
-- (26-2, PlayerProfile.getOptionBonus) - PlayerCombat.getAttackCooldown과
-- refreshMovementSpeed(WalkSpeed) 둘 다 이 함수 하나를 거치므로 새 곱셈 지점 없이 자동으로
-- 공속·이속 모두에 반영된다. 미착용/미배정이면 0.
function PlayerProfile.getSpeedPercentBonus(player)
	local shoesBonus = Loot.getShoesSpeedPercent(PlayerProfile.getEquipped(player, "shoes"))
	return shoesBonus + PlayerProfile.getOptionBonus(player, "speedPercent")
end

-- 장갑 공격력 비율 보너스(16-6, 기존 장비 기본효과) + 장비 3부위 옵션 + 보석 5개의
-- attackPercent 옵션 합(26-2) - AttackServer/SkillServer가 PlayerCombat.getAttack에 그대로
-- 넘기는 단일 배율 자리다(PlayerCombat.lua 주석 "attackPercentBonus" 참고, 둘 다 같은
-- 자리를 공유한다 - 보석 전용 곱셈 지점을 새로 만들지 않는다).
function PlayerProfile.getAttackPercentBonus(player)
	local glovesBonus = Loot.getGlovesAttackPercent(PlayerProfile.getEquipped(player, "gloves"))
	return glovesBonus + PlayerProfile.getOptionBonus(player, "attackPercent")
end

-- 장비 3부위 옵션 + 보석 5개의 defensePercent 옵션 합(26-2, PRD 20.67 [14] 3단계) -
-- PlayerDamage.computeHitDamage가 PlayerCombat.getDefense의 세 번째 자리로 그대로 넘긴다.
-- 방어력엔 장비 기본효과 층이 없다(갑옷 기본 방어력은 Loot.getArmorDefense가 절대값으로
-- 따로 준다) - 옵션 합 자체가 전체 값이다.
function PlayerProfile.getDefensePercentBonus(player)
	return PlayerProfile.getOptionBonus(player, "defensePercent")
end

-- 최대체력 재계산(17-1) - 갑옷 장착/해제·로드 직후마다 호출한다(refreshMovementSpeed와
-- 같은 패턴). 갑옷 미착용이면 Loot.getMaxHpBonus가 0을 돌려줘 CombatConfig.playerMaxHp
-- 그대로 유지된다. 26-2: 장비 3부위 옵션 + 보석 5개의 maxHpPercent 옵션 합(PlayerProfile.
-- getOptionBonus)은 갑옷 보너스까지 합친 총합에 ×(1+x)로 곱한다(getDefense의
-- defensePercentBonus와 같은 자리 배치 - "기본값+장비보너스 전체에 곱한다"는 20.11-4
-- 원칙 재사용). Hp/MaxHp Attribute도 여기서 같이 맞춘다 - PlayerState가 유일한 HP 소스라는
-- 원칙대로, HP가 바뀌는 이 지점에서도 클라이언트(PlayerHealthBar.client.lua)가 보는
-- Attribute를 동기화해야 한다(MonsterAI.server.lua의 syncHud와 같은 이유 - 그쪽은 피격·
-- 리스폰 경로만 알고 장비 교체는 모른다). 캐릭터가 아직 없어 PlayerState.init 전이면(로드
-- 중) get 함수들이 nil을 돌려주는데, Attribute에 nil을 주면 그 값이 지워지므로 안전하게
-- 건너뛴다.
-- P2.5b: 최대체력 식 한 곳(refreshMaxHp · 능력치 요약 getStatSummary가 같이 쓴다).
local function computeMaxHp(player)
	local bonus = Loot.getMaxHpBonus(PlayerProfile.getEquipped(player, "armor"))
	local optionMaxHpPercent = PlayerProfile.getOptionBonus(player, "maxHpPercent")
	return (CombatConfig.playerMaxHp + bonus) * (1 + optionMaxHpPercent) * PlayerProfile.getMilestoneMaxHpMultiplier(player) -- P2.5b D · P2.5c B2: 마일스톤 버킷(MilestoneData.stat = "survival"일 때만 - 기본 1)
end

function PlayerProfile.refreshMaxHp(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	PlayerState.setMaxHp(player, computeMaxHp(player))
	local hp, maxHp = PlayerState.getHp(player), PlayerState.getMaxHp(player)
	if hp and maxHp then
		player:SetAttribute("Hp", hp)
		player:SetAttribute("MaxHp", maxHp)
	end
end

-- 흡혈(lifesteal, 26-2, PRD 20.67 [6-1]) - 피해 확정 지점에서 호출한다(AttackServer 평타
-- 2경로 + SkillServer.strikeTarget). 옵션 합(fraction, %상한 없음)이 0 이하면 아무 일도
-- 안 한다 - 흡혈 옵션이 없는 압도적 다수의 호출에서 여기서 바로 끝난다. 실제 회복은
-- PlayerState.tryLifesteal의 토큰 버킷(초당 상한 CombatConfig.lifestealMaxHpFractionPerSecond)
-- 을 거친다 - %가 아무리 커도 결과량 상한을 못 넘는다(20.67 [6-1] "회복량 자체에 초당
-- 상한을 둔다").
function PlayerProfile.applyLifesteal(player, damage)
	local fraction = PlayerProfile.getOptionBonus(player, "lifesteal")
	if fraction <= 0 or not damage or damage <= 0 then
		return
	end
	local granted = PlayerState.tryLifesteal(player, damage * fraction)
	if granted <= 0 then
		return
	end
	local hp, maxHp = PlayerState.getHp(player), PlayerState.getMaxHp(player)
	if not hp or not maxHp then
		return
	end
	local newHp = math.min(hp + granted, maxHp)
	PlayerState.setHp(player, newHp)
	player:SetAttribute("Hp", newHp)
end

-- 신발 착용/해제·로드 직후마다 호출한다(16-6) - 실제 이동속도(Humanoid.WalkSpeed)와
-- 클라이언트가 공격 쿨다운 예측에 쓰는 Attribute를 같이 맞춘다. 캐릭터가 아직 없으면
-- (로드 중·리스폰 사이) WalkSpeed는 건너뛴다 - 아래 PlayerAdded/CharacterAdded 훅이
-- 캐릭터가 생기는 시점에 다시 불러 결국 맞춰준다.
function PlayerProfile.refreshMovementSpeed(player)
	local bonus = PlayerProfile.getSpeedPercentBonus(player)
	player:SetAttribute("SpeedPercentBonus", bonus)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = BASE_WALK_SPEED_STUDS * JumpMath.moveSpeedMultiplier(bonus) * PlayerState.getMoveSpeedMultiplier(player) -- P3d-F: 출처별 이동속도 배율(회전베기 감속 등)
		-- G2a: 걷기 배율은 MovementConfig.moveSpeedMaxMultiplier(×1.5)에서 멈춘다 - 공격 속도(SpeedPercentBonus Attribute · PlayerCombat.getAttackCooldown)는 상한 없이 그대로.
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- 리스폰마다 WalkSpeed가 로블록스 기본값으로 되돌아간다 - 신발 배율을 매번 다시 건다.
		PlayerProfile.refreshMovementSpeed(player)
	end)
end)

-- 서버만 호출한다(14-1부터 ItemDropServer.server.lua의 줍기 판정 직후 - 12-1 시점엔
-- AttackServer의 드랍 판정 직후 바로 호출했으나, 14-1이 "바닥에 떨어뜨리고 나중에 줍는다"로
-- 바꾸면서 호출 시점이 옮겨졌다). 칸이 가득 찼으면 false - 인벤토리에 반영하지 않는다.
-- 14-1부터는 이게 "드랍 자체가 취소된다"는 뜻이 아니다 - 땅의 아이템은 그대로 남아
-- 나중에 칸을 비우고 다시 주우러 오면 된다(호출부가 알림을 준다).
-- G1-2 자동 처리 설정. enabled = 켜짐, maxGrade = ArmorData.autoProcessGradeChoices 중 하나(아니면 거절). 되돌릴 수 있는 설정이라 즉시저장하지 않는다(일괄판매 기준과 같음).
function PlayerProfile.setAutoProcess(player, enabled, maxGrade)
	local profile = profiles[player]
	if not profile or type(enabled) ~= "boolean" or not table.find(ArmorData.autoProcessGradeChoices, maxGrade) then
		return false
	end
	profile.autoProcess = { enabled = enabled, maxGrade = maxGrade }
	player:SetAttribute("AutoProcess", enabled and maxGrade or "off")
	return true
end

-- G1-2: 줍는 순간 자동 처리. 켜짐 · 기준 등급 이하 · 잠기지 않은 장비만 - 분해 가능 등급이면 보석(dismantleItem과 같은 보석), 아니면 판매 골드(sellItem과 같은 값).
-- 반환: 처리했으면 { kind = "dismantle" | "sell", grade, part, gold }, 아니면 nil(가방에 넣는다).
function PlayerProfile.autoProcessDrop(player, item)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	local setting = profile and profile.autoProcess
	if not classState or not setting or not setting.enabled or item.locked then
		return nil
	end
	local index, cutoff = gradeIndex(item.grade), gradeIndex(setting.maxGrade)
	if not index or not cutoff or index > cutoff then
		return nil
	end
	if index >= DISMANTLE_MIN_GRADE_INDEX then
		table.insert(classState.gemInventory, { grade = item.grade, itemLevel = item.itemLevel, option = item.option })
		GemSync.push(player)
		return { kind = "dismantle", grade = item.grade, part = item.part, gold = 0 }
	end
	local price = Loot.getSellPrice(item)
	profile.gold += price
	player:SetAttribute("Gold", profile.gold)
	return { kind = "sell", grade = item.grade, part = item.part, gold = price }
end

-- 반환: 넣었는가(또는 처리됐는가), 자동 처리 결과(G1-2 - 처리됐으면 표, 가방에 넣었으면 nil). options.noAutoProcess = 개발 명령 · 검증이 가방에 그대로 넣을 때.
function PlayerProfile.addArmorDrop(player, item, options)
	local profile = profiles[player]
	if not profile then
		return false
	end
	-- G1-2: 자동 처리 대상이면 가방에 넣지 않고 바로 분해 · 판매(가방이 가득이어도 처리된다 - 줍기 성공)
	local processed = not (options and options.noAutoProcess) and PlayerProfile.autoProcessDrop(player, item) or nil
	if processed then
		InventorySync.notifyAutoProcessed(player, processed)
		return true, processed
	end
	-- D1(리뷰 3): 태초는 칸이 가득이어도 가방에 넣는다(options.force) - 땅에 두면 주인이 나갈 때 세계 번호가 붙은 아이템이 사라진다. 칸 초과는 판매 · 분해로 풀린다.
	if #profile.inventory >= profile.inventorySlots and not (options and options.force) then
		return false
	end
	table.insert(profile.inventory, item)
	InventorySync.push(player, profile)
	return true
end

-- 서버만 호출한다(InventoryServer의 검증 직후). index는 인벤토리 배열의 1부터 시작하는
-- 위치 - 그 자리 아이템을 착용하고, 기존에 그 부위에 착용 중이던 아이템(있다면)은
-- 인벤토리로 되돌린다. 먼저 빼고 나중에 넣으므로(순서 고정) 칸 수가 항상 그대로 맞아
-- 용량 검사가 필요 없다 - 착용은 "교체"일 뿐 순수 추가가 아니다. 어느 부위에 착용할지는
-- item.part를 그대로 읽는다(16-6부터 갑옷·장갑·신발 3부위 전부 이 함수 하나로 처리 -
-- 이전엔 equipArmor로 갑옷만 다뤘다). S20d: 거절 판정은 shared/Equip(클라 미리 판정과 같은 함수) - 규칙은 그대로이고 실패하면 이유 코드(no_class · not_found)를 함께 돌려준다.
function PlayerProfile.equipItem(player, index)
	local profile = profiles[player]
	if not profile then
		return false, "no_class"
	end
	local classState = activeClassState(profile)
	local reason = Equip.equipBlockReason(profile.inventory, index, classState ~= nil)
	if reason then
		return false, reason
	end
	local item = profile.inventory[index]

	local part = item.part
	table.remove(profile.inventory, index)
	local previous = classState.equipment[part]
	if previous then
		table.insert(profile.inventory, previous)
	end
	classState.equipment[part] = item

	InventorySync.push(player, profile)
	if part == "shoes" then
		PlayerProfile.refreshMovementSpeed(player)
	elseif part == "armor" then
		PlayerProfile.refreshMaxHp(player)
	end
	return true
end

-- 서버만 호출한다. part(갑옷/장갑/신발) 착용을 해제해 인벤토리로 되돌린다 - 순수 추가라
-- 칸이 가득 차 있으면 실패한다(false, "full") - 벗을 자리가 없으면 벗을 수 없다. S20d: 판정은 shared/Equip(no_class · not_equipped · full).
function PlayerProfile.unequipItem(player, part)
	local profile = profiles[player]
	if not profile then
		return false, "no_class"
	end
	local classState = activeClassState(profile)
	local reason = Equip.unequipBlockReason(classState and classState.equipment or {}, part, #profile.inventory, profile.inventorySlots, classState ~= nil)
	if reason then
		return false, reason
	end
	local current = classState.equipment[part]

	classState.equipment[part] = nil
	table.insert(profile.inventory, current)

	InventorySync.push(player, profile)
	if part == "shoes" then
		PlayerProfile.refreshMovementSpeed(player)
	elseif part == "armor" then
		PlayerProfile.refreshMaxHp(player)
	end
	return true
end

-- ═══ 장비 계승(P2.5b A) ═══
-- 지금 활성 직업의 최종 능력치(계승 미리보기가 전후를 비교한다). 실제 전투가 쓰는 함수 그대로 - 공격력 = PlayerCombat.getAttack(AttackServer와 같은 인자) ·
-- 방어력 = PlayerCombat.getDefense(PlayerDamage와 같은 인자) · 최대체력 = refreshMaxHp와 같은 식 · 속도 = 신발 + 옵션 · 치명 = 옵션 합.
function PlayerProfile.getStatSummary(player)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return nil
	end
	local level = CharacterLevel.getLevelFromExp(classState.characterExp)
	local critRate, critDmg = PlayerProfile.getCritBonus(player)
	return {
		attack = PlayerCombat.getAttack(classState.weapon, profile.classId, level, PlayerProfile.getAttackPercentBonus(player), PlayerProfile.getOptionBonus(player, "finalDamage"), PlayerProfile.getMilestoneMultiplier(player)),
		defense = PlayerCombat.getDefense(profile.classId, Loot.getArmorDefense(classState.equipment.armor), PlayerProfile.getDefensePercentBonus(player)),
		maxHp = computeMaxHp(player),
		speedPercent = PlayerProfile.getSpeedPercentBonus(player),
		critRate = critRate,
		critDmg = critDmg,
	}
end

-- 계승 비용(골드) - 서버 차감과 미리보기가 같은 값. 기준 = 계정 최고 스테이지(변환권과 같은 규칙) · 마일스톤 해금 "계승 비용 할인"(P2.5b D).
PlayerProfile.PRIMORDIAL_UNLOCK_TOKEN = "primordial-confirmed-twice" -- D1 ⑦(클라 DetailSheet 이중 확인 뒤에만 보낸다 - 우발 해제 방지용 표식 · 보안 장치 아님)

-- D1 [3] 태초 각성(shared/Awaken 판정 · 비용). kind = "bag"(가방 칸 index) | "equip"(부위 이름). 반환: 성공, 새 itemLevel | 실패 이유. 되돌릴 수 없는 골드 사용 → 호출부가 즉시 저장.
function PlayerProfile.awakenItem(player, kind, key, expectedNo)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false, "not_found"
	end
	local item
	if kind == "bag" then
		item = profile.inventory[key]
	elseif kind == "equip" and (key == "armor" or key == "gloves" or key == "shoes") then
		item = classState.equipment[key]
	end
	local best = PlayerProfile.getAccountBestStage(player)
	-- 리뷰 7: 판매 · 분해로 칸이 당겨진 뒤 옛 칸 번호가 오면 다른 태초가 각성된다 → 클라가 본 세계 번호와 대조(번호 없는 태초는 nil끼리)
	if item and expectedNo ~= nil and not (item.primordial and item.primordial.no == expectedNo) then
		return false, "not_found"
	end
	local reason = Awaken.blockReason(item, best)
	if reason then
		return false, reason
	end
	if not PlayerProfile.trySpendGold(player, Awaken.cost(best)) then
		return false, "no_gold"
	end
	item.itemLevel = best
	InventorySync.push(player, profile)
	PlayerProfile.refreshMaxHp(player)
	PlayerProfile.refreshMovementSpeed(player)
	return true, best
end

function PlayerProfile.getInheritCost(player, bGradeId)
	local profile = profiles[player]
	local discount = profile and Milestone.inheritDiscount(profile.milestoneUnlocks) or 0
	return Inherit.cost(bGradeId, PlayerProfile.getAccountBestStage(player), discount)
end

-- 계승 미리보기(A6): { cost, gold, keepABlock, refund = { a, b }, stats = { current, a, b } }. a · b = 그 세트를 남겼을 때 계승 뒤 능력치(A 세트를 못 고르면 a = nil).
-- 착용 칸을 잠깐 결과 장비로 바꿔 getStatSummary로 잰 뒤 되돌린다 - 중간에 yield가 없고, 에러가 나도 pcall 뒤에 반드시 되돌린다.
-- 반환: 표 | nil, 이유 코드(Inherit.blockReason과 같은 코드 - keep 판정 전까지).
function PlayerProfile.previewInherit(player, part, bagIndex)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	local a = classState and classState.equipment[part]
	local b = profile and profile.inventory[bagIndex]
	local reason = Inherit.blockReason(a, b, "b", classState ~= nil)
	if reason then
		return nil, reason
	end
	local keepABlock = Inherit.keepABlockReason(a, b)
	local result = {
		cost = PlayerProfile.getInheritCost(player, b.grade),
		gold = profile.gold,
		keepABlock = keepABlock,
		refund = { a = Inherit.refund(a, b, "a"), b = Inherit.refund(a, b, "b") },
		stats = { current = PlayerProfile.getStatSummary(player) },
	}
	local ok, err = pcall(function()
		for _, keep in ipairs({ "a", "b" }) do
			if keep == "b" or not keepABlock then
				classState.equipment[part] = Inherit.resultItem(a, b, keep)
				result.stats[keep] = PlayerProfile.getStatSummary(player)
			end
		end
	end)
	classState.equipment[part] = a
	if not ok then
		warn(("[PlayerProfile] 계승 미리보기 에러: %s"):format(tostring(err)))
		return nil, "invalid"
	end
	return result
end

-- 계승 실행(A1 ~ A5) - 되돌릴 수 없다(호출부가 즉시저장). keep = "a"(착용 장비 A의 옵션 세트) | "b"(새 장비 B의 옵션 세트).
-- 순서: 판정(Inherit.blockReason) → 비용(서버가 다시 계산) → 골드 차감 → B를 결과 장비로 바꿔 착용 · 가방에서 제거 → A 환급(보석 가방 또는 골드).
-- 반환: true, 환급 종류("gem" | "gold") | false, 이유 코드(Inherit.blockReason의 코드 + no_gold).
function PlayerProfile.inheritItem(player, part, bagIndex, keep)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	local a = classState and classState.equipment[part]
	local b = profile and profile.inventory[bagIndex]
	local reason = Inherit.blockReason(a, b, keep, classState ~= nil)
	if reason then
		return false, reason
	end
	local cost = PlayerProfile.getInheritCost(player, b.grade)
	if not PlayerProfile.trySpendGold(player, cost) then
		return false, "no_gold"
	end

	local refund = Inherit.refund(a, b, keep)
	local newItem = Inherit.resultItem(a, b, keep)
	table.remove(profile.inventory, bagIndex)
	classState.equipment[part] = newItem
	if refund.kind == "gem" then
		table.insert(classState.gemInventory, refund.gem)
	else
		PlayerProfile.addGold(player, refund.gold)
	end

	InventorySync.push(player, profile)
	GemSync.push(player)
	PlayerProfile.refreshMaxHp(player)
	PlayerProfile.refreshMovementSpeed(player)
	return true, refund.kind
end

-- 서버만 호출한다(InventoryServer의 SellRequest 처리 직후, 13-1). 잠긴 아이템은 개별 판매도 막는다([2] 판단 -
-- 오클릭 방지가 목적이라면 일괄 판매만 막아서는 부족하다, 개별 판매 버튼도 같은 위험이 있다).
-- 성공하면 실제로 받은 골드(0 이상의 수)를, 실패하면 false + 이유("not_found"/"locked")를
-- 돌려준다 - 판매 자체는 되돌릴 수 없는 사건이라 호출부가 성공 시 ImmediateSave를 건다.
-- 이름이 sellArmor였다가 sellItem으로 바뀌었다(16-6) - 인벤토리엔 이제 갑옷 말고도
-- 장갑·신발이 들어오는데, index 하나로 아무 부위나 파는 로직 자체는 원래도 부위를
-- 몰랐다(item.grade만 본다) - 이름만 실제 동작을 안 속이게 고쳤다.
function PlayerProfile.sellItem(player, index)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local item = profile.inventory[index]
	if not item then
		return false, "not_found"
	end
	if item.locked then
		return false, "locked"
	end

	local price = Loot.getSellPrice(item)
	table.remove(profile.inventory, index)
	profile.gold += price
	player:SetAttribute("Gold", profile.gold)
	InventorySync.push(player, profile)
	return price
end

-- 서버만 호출한다(13-1). "gradeId 등급 이하 전부" 일괄 판매 - ArmorData.gradeOrder의 순서를
-- 기준으로 삼는다. ArmorData.bulkSellMaxGrade보다 높은 등급을 gradeId로 보내면(클라이언트가
-- 목록에 안 보여주는 것과 별개로) 여기서도 거부한다(20-3 - 클라이언트가 보낸 값을 그대로
-- 믿지 않는다는 원칙, 유물 이상은 어떤 경로로도 일괄판매되지 않는다).
-- 잠긴 아이템은 대상에서 제외한다. 착용 중인 장비(classState.equipment)는 이 반복이 아예
-- 모르는 자리다 - profile.inventory 배열만 순회하므로 착용품은 구조적으로 항상 제외된다
-- (나중에 인벤토리·착용 자료구조를 합치려는 시도가 있다면 이 보호가 사라지지 않게 유의).
-- 파는 아이템 목록·총 골드를 먼저 전부 계산한 뒤 한 번에 반영한다(중간에 task.wait 등
-- yield 지점이 없다 - 다른 요청이 이 사이에 끼어들 수 없으므로 "절반만 팔리는" 상태가
-- 구조적으로 생기지 않는다). 반환값: (판매 개수, 총 골드).
function PlayerProfile.sellItemsBulkUpTo(player, gradeId)
	local profile = profiles[player]
	if not profile then
		return 0, 0
	end

	local cutoffIndex = gradeIndex(gradeId)
	local maxIndex = gradeIndex(ArmorData.bulkSellMaxGrade)
	if not cutoffIndex or cutoffIndex > maxIndex then
		return 0, 0
	end

	local remaining = {}
	local totalGold = 0
	local soldCount = 0
	for _, item in ipairs(profile.inventory) do
		local itemGradeIndex = gradeIndex(item.grade)
		if not item.locked and itemGradeIndex and itemGradeIndex <= cutoffIndex then
			totalGold += Loot.getSellPrice(item)
			soldCount += 1
		else
			table.insert(remaining, item)
		end
	end

	if soldCount == 0 then
		return 0, 0
	end

	profile.inventory = remaining
	profile.gold += totalGold
	player:SetAttribute("Gold", profile.gold)
	InventorySync.push(player, profile)
	return soldCount, totalGold
end

function PlayerProfile.getBulkSellCutoffGrade(player)
	local profile = profiles[player]
	return profile and profile.bulkSellCutoffGrade
end

-- 서버만 호출한다(InventoryServer의 BulkSellCutoffRequest 처리 직후, 20-3). 이 선택 자체는
-- 되돌릴 수 있는 사건이라(잠금·착용해제와 같은 부류) 즉시저장하지 않는다 - 주기저장·퇴장
-- 저장에 맡긴다. ArmorData.bulkSellMaxGrade보다 높은 등급이나 존재하지 않는 등급은 조용히
-- 거부한다(false) - sellItemsBulkUpTo와 같은 상한을 여기서도 강제해야, 클라이언트 목록에
-- 없는 값이 어떤 경로로든 저장되는 일이 없다.
-- 보석상인에서 변환 · 리롤(변환권 구매 포함)을 한 번이라도 성공했다는 기록(S20e - 보석 탭 안내 줄이 눈에 띄는 모양에서 작은 회색 한 줄로 줄어든다). 새로 true가 되면 true, 이미 true였으면 false.
-- 저장은 호출부(GemServer)가 성공 뒤 ImmediateSave로 이미 건다.
function PlayerProfile.markGemMerchantUsed(player)
	local profile = profiles[player]
	if not profile or profile.hints.gemMerchantUsed == true then
		return false
	end
	profile.hints.gemMerchantUsed = true
	player:SetAttribute("GemMerchantUsed", true)
	return true
end

-- BR1-2(v37): 첫 만남 전멸기 카드 - 이 보스를 처음 만나면 true를 돌려주고 본 것으로 적는다(저장은 다음 정기 저장 - 카드를 한 번 더 보는 것은 무해하다).
-- M1 BR1-3 후속: 이 보스(종)를 전에 만났는가(첫 만남 카드를 이미 봤는가) - 구간 수호자 2회차 체력 배율이 읽는다.
function PlayerProfile.hasSeenBoss(player, bossId)
	local profile = profiles[player]
	return profile ~= nil and profile.hints.bossIntroSeen ~= nil and profile.hints.bossIntroSeen[bossId] == true
end

function PlayerProfile.markBossIntroSeen(player, bossId)
	local profile = profiles[player]
	if not profile or type(bossId) ~= "string" then
		return false
	end
	profile.hints.bossIntroSeen = profile.hints.bossIntroSeen or {}
	if profile.hints.bossIntroSeen[bossId] then
		return false
	end
	profile.hints.bossIntroSeen[bossId] = true
	return true
end

-- C1 마무리(v42): 잠긴 몹을 처음 때렸는가 - 처음이면 본 것으로 적고 true(말풍선 1회 · 저장은 다음 정기 · 퇴장 저장).
function PlayerProfile.markStealLockSeen(player)
	local profile = profiles[player]
	if not profile or profile.hints.stealLockSeen == true then
		return false
	end
	profile.hints.stealLockSeen = true
	return true
end

-- 검증 · 스크린샷 전용(/gg stealhint reset): 말풍선을 다시 보게.
function PlayerProfile.debugResetStealLockSeen(player)
	local profile = profiles[player]
	if profile then
		profile.hints.stealLockSeen = false
	end
end

-- 검증 · 스크린샷 전용(/gg bossintro reset): 본 보스 집합을 비운다.
function PlayerProfile.debugResetBossIntro(player)
	local profile = profiles[player]
	if profile then
		profile.hints.bossIntroSeen = {}
	end
end

function PlayerProfile.hasUsedGemMerchant(player)
	local profile = profiles[player]
	return profile ~= nil and profile.hints.gemMerchantUsed == true
end

function PlayerProfile.setBulkSellCutoffGrade(player, gradeId)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local index = gradeIndex(gradeId)
	local maxIndex = gradeIndex(ArmorData.bulkSellMaxGrade)
	if not index or index > maxIndex then
		return false
	end
	profile.bulkSellCutoffGrade = gradeId
	player:SetAttribute("BulkSellCutoffGrade", gradeId)
	return true
end

-- 장비창 위치(23-5, 지시 "재접속해도 유지되게" - bulkSellCutoffGrade와 같은 계정 전체
-- 공유 층). false면 "한 번도 안 옮김" - Attribute 자체를 안 세운다(nil로 남는다, 클라가
-- 기본 계산 위치를 쓴다). 되돌릴 수 있는 UI 배치일 뿐이라(위 setBulkSellCutoffGrade와
-- 같은 판단) 즉시저장하지 않는다.
function PlayerProfile.getInventoryWindowPosition(player)
	local profile = profiles[player]
	return profile and profile.inventoryWindowPosition or false
end

-- 서버만 호출한다(InventoryServer의 SetInventoryWindowPosition 처리 직후). 숫자 좌표만
-- 받는다 - 클라이언트가 보낸 값을 그대로 믿지 않는다는 원칙 그대로, 여기서 타입만
-- 검증한다(정확한 화면 범위 클램프는 클라가 매 프레임 다시 하므로 서버는 "숫자인가"만
-- 확인해도 안전하다 - 저장된 값이 다음 접속 때 화면 밖이면 클라 fitWindow가 다시 잘라
-- 넣는다).
function PlayerProfile.setInventoryWindowPosition(player, x, y)
	local profile = profiles[player]
	if not profile or type(x) ~= "number" or type(y) ~= "number" then
		return false
	end
	profile.inventoryWindowPosition = { x = x, y = y }
	player:SetAttribute("InventoryWindowX", x)
	player:SetAttribute("InventoryWindowY", y)
	return true
end

-- 서버만 호출한다(13-1). 잠금은 착용/해제와 같은 되돌릴 수 있는 사건이라(다시 누르면 그만)
-- 즉시저장하지 않는다.
function PlayerProfile.setItemLocked(player, index, locked, confirmToken)
	local profile = profiles[player]
	if not profile then
		return false
	end
	local item = profile.inventory[index]
	if not item then
		return false
	end
	-- D1 ⑦: 태초 잠금 해제는 이중 확인을 거친 요청만(클라 확인 창 두 번 → 토큰). 잠그기는 그대로.
	if not locked and item.grade == "primordial" and confirmToken ~= PlayerProfile.PRIMORDIAL_UNLOCK_TOKEN then
		return false
	end
	item.locked = locked
	InventorySync.push(player, profile)
	return true
end

function PlayerProfile.clear(player)
	profiles[player] = nil
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- 19-3a: 밸런스 테스트 도구(DevTools.server.lua) 전용 스냅샷/복원 + 직접 세팅 함수.
-- 일반 게임플레이 경로(강화·드랍·레벨업 등)는 절대 이 함수들을 쓰지 않는다 - 전부
-- "서버가 검증한 결과"를 반영하는 기존 함수를 그대로 쓴다. 이 함수들은 개발자가
-- 임의 조건을 즉시 세팅하기 위한 우회로이므로 DevTools 밖에서 호출하지 않는다.

-- 활성 직업 하나의 전체 상태(직업 자체는 안 바뀐다 - classId는 snapshot 밖에서 별도 관리)를
-- 깊은 복사로 백업한다. DevTools가 테스트 시작 전 원본을 보존하는 유일한 지점.
-- 가방(inventory)도 백업한다(28-1 S04 사전 작업) - 보스를 실제 처치 경로로 잡는 옛 검증 블록이 S01 이후 보스 장비를
-- 가방으로 바로 넣게 되면서 Play마다 실제 가방에 장비를 남겼다(PRD 20.83 [8]).
function PlayerProfile.snapshotForDevTools(player)
	local profile = profiles[player]
	if not profile then
		return nil
	end
	return {
		classId = profile.classId,
		gold = profile.gold,
		classes = deepCopy(profile.classes),
		inventory = deepCopy(profile.inventory),
		materials = deepCopy(profile.materials), -- 28-1 S04: 처치 보상이 재료를 실제 프로필에 쌓는다 - 가방과 같은 이유로 되돌린다.
		-- 28-1 S05: 보스 처치가 방지권 · 지급 기록을 실제 프로필에 쌓는다 - purchases 전체가 아니라 이 둘만 되돌린다(옵션 변환권은 그것을 만지는 검증 블록이 각자 되돌린다).
		protectionTickets = deepCopy(profile.purchases.protectionTickets),
		protectionClaimedStages = deepCopy(profile.purchases.protectionClaimedStages),
		bossCodex = deepCopy(profile.purchases.bossCodex), -- 30-0 S11: 보스 처치가 도감 도장을 실제 프로필에 찍는다 - 같은 이유로 되돌린다.
		milestoneUnlocks = profile.milestoneUnlocks, -- P2.5b D: 마일스톤 검증이 해금 개수 · 가방 칸 수를 바꾼다 - 같은 이유로 되돌린다.
		inventorySlots = profile.inventorySlots,
		gemDust = profile.gemDust, -- P2.5b C: 보석 분해 · 재련 · 변환권 구매 검증이 가루를 바꾼다 - 같은 이유로 되돌린다.
		hints = deepCopy(profile.hints), -- 30-0 S20e: 수동 Play에서 보석상인을 쓰면 안내 플래그가 켜지고 Play 종료 때 실제 프로필에 저장됐다(S20e 실측) - 같은 이유로 되돌린다.
		autoProcess = deepCopy(profile.autoProcess), -- G1-2(v36): 새 저장 필드는 백업 대상(COMMON §1)
		world = deepCopy(profile.world), -- M1(v38): 포탈 개방 - 새 저장 필드는 백업 대상(COMMON §1)
		peakLevel = profile.peakLevel, -- M1(v38)
		titles = deepCopy(profile.titles), -- M1(v39): 칭호(봉인 입구 검증이 지급한다)
		eggs = deepCopy(profile.eggs), -- M1-3(v41): 알 가방(둥지 검증이 줍는다) - world(nests · nestDex)는 위 world 통째 복사에 들어 있다
		leaderboardTainted = profile.leaderboardTainted, -- P3a(v34): 검증이 기록 경로를 재려고 끈 값을 되돌린다(COMMON §1 "새 저장 필드는 백업 대상에").
	}
end

-- snapshotForDevTools가 만든 백업을 통째로 되돌린다 - 저장(DataStore)에는 손대지 않는다
-- (세션 메모리만 복원). 게임패스(purchases)는 백업 대상이 아니다(DevTools가 건드리지 않는
-- 필드라 원본 그대로 남아 있다 - 건드리는 검증 블록이 각자 되돌린다). 가방은 표를 새로 만들지 않고 제자리에서
-- 되돌린다 - 검증 블록이 profile.inventory를 지역 변수로 들고 있어도 같은 표를 본다.
function PlayerProfile.restoreForDevTools(player, snapshot)
	local profile = profiles[player]
	if not profile or not snapshot then
		return
	end
	profile.classId = snapshot.classId
	profile.gold = snapshot.gold
	profile.classes = deepCopy(snapshot.classes)
	local restoredBag = deepCopy(snapshot.inventory)
	table.clear(profile.inventory)
	for index, item in ipairs(restoredBag) do
		profile.inventory[index] = item
	end
	profile.materials = deepCopy(snapshot.materials)
	syncMaterialAttributes(player, profile)
	profile.purchases.protectionTickets = deepCopy(snapshot.protectionTickets)
	profile.purchases.protectionClaimedStages = deepCopy(snapshot.protectionClaimedStages)
	profile.purchases.bossCodex = deepCopy(snapshot.bossCodex)
	profile.hints = deepCopy(snapshot.hints)
	player:SetAttribute("GemMerchantUsed", profile.hints.gemMerchantUsed == true)
	profile.gemDust = snapshot.gemDust or profile.gemDust
	player:SetAttribute("GemDust", profile.gemDust)
	profile.milestoneUnlocks = snapshot.milestoneUnlocks or profile.milestoneUnlocks
	profile.inventorySlots = snapshot.inventorySlots or profile.inventorySlots
	profile.leaderboardTainted = snapshot.leaderboardTainted
	profile.world = snapshot.world and deepCopy(snapshot.world) or profile.world
	profile.peakLevel = snapshot.peakLevel or profile.peakLevel
	profile.titles = snapshot.titles and deepCopy(snapshot.titles) or profile.titles
	profile.eggs = snapshot.eggs and deepCopy(snapshot.eggs) or profile.eggs
	if snapshot.autoProcess then
		profile.autoProcess = deepCopy(snapshot.autoProcess)
		player:SetAttribute("AutoProcess", profile.autoProcess.enabled and profile.autoProcess.maxGrade or "off")
	end
	syncProtectionAttributes(player, profile)
	player:SetAttribute("Gold", profile.gold)
	syncActiveClassAttributes(player, profile)
	InventorySync.push(player, profile)
	GemSync.push(player) -- P2.5b: 보석(홈 · 가방)도 되돌렸다 - 안 밀면 클라 보석 탭이 검증 도중의 마지막 스냅샷에 남는다(P25b Play 1 S20(UI) X)
end

-- 캐릭터 레벨을 경험치로 직접 지정한다(addCharacterExp와 달리 "더하기"가 아니라 "그
-- 값으로 고정" - 정상 플레이 경로엔 이런 연산이 없다, 몬스터 처치로만 오른다).
function PlayerProfile.setCharacterExpDirect(player, exp)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.characterExp = exp
	player:SetAttribute("CharacterExp", exp)
	player:SetAttribute("CharacterLevel", CharacterLevel.getLevelFromExp(exp))
	PlayerProfile.notePeakLevel(player)
	PlayerProfile.claimMilestones(player, true) -- P2.5b D: 개발 도구로 레벨을 옮겨도 정상 레벨업과 같이 마일스톤을 받는다
end

-- 인벤토리 경유 없이 장비를 직접 장착한다(equipItem과 달리 인벤토리 인덱스가 아니라
-- 아이템 테이블을 직접 받는다 - 인벤토리에 있지도 않은 합성 아이템을 착용시켜야 해서다).
-- 기존 착용품은 그냥 버린다 - 되돌릴 원본은 snapshotForDevTools가 이미 갖고 있다.
function PlayerProfile.setEquippedDirect(player, part, item)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.equipment[part] = item
	InventorySync.push(player, profile)
	if part == "shoes" then
		PlayerProfile.refreshMovementSpeed(player)
	elseif part == "armor" then
		PlayerProfile.refreshMaxHp(player)
	end
end

-- 무한 모드 스테이지를 StageServer의 이동 규칙(최고+1까지만, 보스 게이트) 없이 즉시
-- 지정한다. best가 그 값보다 낮으면 같이 끌어올린다 - 안 그러면 다른 화면(HUD 등)이
-- 모순된 값을 보여준다(19-4부터 잡몹 피해·보상도 매 타격마다 이 stage를 직접 읽으므로
-- - MonsterState.applyDamage/getAttackFor 등 - 이 값 자체가 즉시 실제 난이도에 반영된다).
function PlayerProfile.setInfiniteStageDirect(player, stage)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return
	end
	classState.stageProgress.infinite = stage
	if stage > classState.stageProgress.infiniteBest then
		classState.stageProgress.infiniteBest = stage
	end
	player:SetAttribute("InfiniteStage", stage)
	player:SetAttribute("InfiniteStageBest", classState.stageProgress.infiniteBest)
	syncAccountBestStage(player, profile)
end

-- G1-0(P3d-F 결정 4): 검증 전용 - 최고 도달 · 보스 게이트를 **낮추는 것까지** 강제로 맞춘다(위 함수들은 올리기만 한다 - 개발 계정이 진행하면
-- 27-4처럼 "최고 7 · 게이트 5"를 기대하는 검증이 계정 상태를 따라 X가 됐다). 호출한 검증이 DevTools 백업 · 복원으로 되돌린다.
function PlayerProfile.debugForceStageProgress(player, best, bossCleared)
	local profile = profiles[player]
	local classState = profile and activeClassState(profile)
	if not classState then
		return false
	end
	classState.stageProgress.infiniteBest = best
	classState.stageProgress.bestBossCleared = bossCleared
	player:SetAttribute("InfiniteStageBest", best)
	player:SetAttribute("BestBossCleared", bossCleared)
	return true
end

return PlayerProfile
