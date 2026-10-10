-- 골드 등 영구 저장 데이터의 DataStore 입출력 전담. 세션(Player) 메모리 상태는 다루지
-- 않는다 - 그건 PlayerProfile이 한다. 이 모듈은 "키 하나를 읽고/쓴다"와 스키마
-- 기본값·버전 이관만 안다 - 웹 core/save.js와 같은 역할, 같은 패턴(SAVE_VERSION+migrate()).

local print = require(game:GetService("ReplicatedStorage").Shared.Log).info -- SEC-FIX-1 9: 라이브 = WARN(이 파일 print = INFO · 꺼짐) · Studio = 그대로
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
-- 26-1 옵션 통합 이관(v22->v23)·isValidProfile 검사용.
local GemData = require(ReplicatedStorage.Shared.data.GemData)
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData) -- G1-2: 자동 처리 기준 등급 검사(v36)
local AUTO_GRADE = require(ReplicatedStorage.Shared.data.UiV2Flags).bag and "normal" or "epic" -- UI-1b 0절: 자동 정리 기본 등급(새 계정 · v36 이관 · 복구 같은 값) · bag 스위치 끔 = 옛 epic
-- 28-1 S03: 강화 천장 게이지(weapon.enhanceGauge)의 상한 검사용(v24->v25 · isValidProfile).
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
-- 28-1 S04: 강화 재료 보유량(profile.materials)의 기본값 · 이관(v25->v26) · isValidProfile 검사용.
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
-- S19b 사전 작업 2: 검증 모드(verifyArmed - Studio에서 터미널이 켠 때만)의 저장 키 분리용.
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)
local SlotSaveData = require(ReplicatedStorage.Shared.data.SlotSaveData) -- QUEUE-MENU2 B 캐릭터 칸 저장 스위치
local SlotSave = require(script.Parent.SlotSave)

local SaveSystem = {}

-- 약한 세션 잠금(QUEUE-6h-b 후속 · v55): 이 서버의 표식. 저장할 때 sessionId에 쓰고, 퇴장 · 종료 저장은 ""(놓음)로 쓴다.
-- game.JobId는 Studio에서 빈 문자열이라 서버 시작 때 GUID를 따로 만든다.
local SERVER_SESSION_ID = HttpService:GenerateGUID(false)
SaveSystem.serverSessionId = SERVER_SESSION_ID
local releasing = {} -- [Player] = true: 다음 저장이 마지막(퇴장 · 종료) - sessionId를 놓는다

-- 재료 id마다 0. defaultProfile · migrate 둘이 같은 모양을 만든다.
local function defaultMaterials()
	local materials = {}
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		materials[materialId] = 0
	end
	return materials
end

-- 신규/구버전 프로필에 지급하는 시작 무기. 등급·기본공격력 등 정적 스탯은 WeaponData에만
-- 있다 - 여기(저장 데이터)엔 계속 바뀌는 값(강화 단계)과 어떤 무기인지(id)만 남긴다.
-- gems(23-2, PRD 20.38 [2]) - 5슬롯 고정 배열. 빈 슬롯은 nil이 아니라 false를 쓴다 -
-- DataStore 왕복(테이블→JSON→테이블) 과정에서 배열 중간에 진짜 nil이 끼면 자리가 통째로
-- 사라져 구멍(sparse array) 문제가 생길 수 있다(bossFirstClearStages처럼 "존재하는 키만
-- 채우는" 딕셔너리와 달리, 이건 5칸 전부가 항상 "존재해야" 한다 - 슬롯 번호=배열 위치가
-- 곧 등급을 뜻하므로 구멍이 뚫리면 안 된다). 채워진 슬롯은 항상 테이블(Gem.buildGrantedGem
-- 참고, Gem.isFilled가 type()으로 구분한다).
-- slotUnlocked(23-4) - 슬롯별 해금 여부를 매번 rebirthCount에서 계산하지 않고 저장한다
-- (GemData.slotUnlockRequiredRebirth 주석 참고 - PlayerProfile.rebirth가 조건을 만족하는
-- 순간 여기 기록한다).
local function defaultWeapon()
	return {
		id = WeaponData.starterId,
		level = 0,
		grade = 0,
		-- 강화 천장 게이지(28-1 S03, PRD 20.72 [1-6] 3번) - 0 ~ EnhanceConfig.gauge.max의 정수(천분율). 모든 강화 실패가 채우고 성공하면 0이 된다.
		enhanceGauge = 0,
		gems = { false, false, false, false, false },
		slotUnlocked = { false, false, false, false, false },
	}
end

-- 직업 하나가 갖는 상태(19-1) - 캐릭터 레벨·무기·착용 장비 3부위·무한 모드 진행도.
-- 4직업이 각자 이 테이블을 하나씩 갖는다(profile.classes[classId]). 골드·인벤토리처럼
-- 계정 전체가 공유하는 값은 여기 들어오지 않는다 - defaultProfile 쪽 주석 참고.
local function defaultClassState()
	return {
		characterExp = 0,
		weapon = defaultWeapon(),
		equipment = { armor = nil, gloves = nil, shoes = nil },

		-- 무한 모드 진행도(11-1 개정, 19-1에서 직업별로 이동). infiniteBest(최고 도달
		-- 단계)는 현재 단계와 분리한다 - 파밍하러 내려가면 현재 단계는 낮아져도 최고
		-- 기록은 그대로 남아야 한다(PRD 20.12 경쟁 축과도 맞다). bestBossCleared(15-1):
		-- 최고로 깬 보스 스테이지 - "0"은 아직 하나도 못 깼다는 뜻이다. bossFirstClearStages
		-- (20-4): "그 스테이지 보스를 확정 보상으로 이미 받았는가" 집합({[tostring(stage)]=true} - 키는 문자열, v28) -
		-- bestBossCleared와 별개다. bestBossCleared는 StageServer 게이트가 쓰는 단조증가
		-- 최고 기록이고, 이건 "재입장해도 확정 보상은 한 번만"만 판정한다(지시 [1]
		-- "재입장 무제한 + 확정 보상 무한 파밍" 방지).
		stageProgress = { infinite = 1, infiniteBest = 1, bestBossCleared = 0, bossFirstClearStages = {} },

		-- 환생 횟수(20-4, 23-2부터 실제 환생 시스템이 이 값을 올리는 유일한 통로가 됐다 -
		-- PlayerProfile.rebirth). 0~5(GemData.maxRebirthCount) - 무기 등급(weapon.grade)·
		-- 보석 슬롯 개방(weapon.gems)과 1:1로 맞물린다(20.38 [2]).
		rebirthCount = 0,

		-- 분해로만 얻는 미장착 보석 보관함(23-2, PRD 20.37 [3] "2~5번 슬롯은 오직 분해로만
		-- 얻는 보석"). 무기·보석은 무기에 딸린 자산이라 계정 공유가 아니라 직업별이다(20.37
		-- [6] 저장 스키마 결정 - gold·inventory와 다른 층). 원소는 weapon.gems의 채워진
		-- 슬롯과 같은 모양({ optionId }). 칸 수 상한을 두지 않는다(PRD가 값을 정해 두지
		-- 않았고, 분해 한 번에 방어구 한 개를 소모해야만 늘어나는 값이라 실제로는 많이
		-- 쌓이지 않는다 - "임의 결정" 목록 참고).
		gemInventory = {},

		-- 환생 후 레벨 마일스톤(P2.5c B2, v33 - v32의 회차별 표 milestones를 대신한다) - 이 직업이 받은 마지막 능력치 마일스톤 레벨(0 = 없음 · 200 · 250 …).
		-- 직업별(레벨 · 환생이 직업별이다). 버킷 값은 이 레벨에서 계산한다. 규칙 = shared/Milestone.lua.
		milestoneLevel = 0,
		abilities = {}, -- QUEUE-10h Q6(v50): 직업 고유 능력 단계({ [능력 id] = 단계 } - TrainingData.classAbilities)
		-- C5-2(v46) 되찾기 기준: 환생 순간 레벨의 회차 누적 최대(0 = 환생 전). 이 레벨 미만에서는 캐릭터 경험치 × reclaimDivisors[환생 횟수](CharacterLevel.getReclaimMultiplier).
		reclaimLevel = 0,
		-- QUEUE-ALL9E1 LOOK2(v73): 갑옷 착용 중 내 아바타 옷 보이기(true = 본인 2D · 레이어드 옷 + 갑옷 판 · false = 게임 바닥층 2D 옷 · 레이어드 숨김) - 직업(캐릭터)별 · MENU2 때 캐릭터 칸 키로 옮긴다
		showOwnClothes = false,
		-- QUEUE-MENU2(v74): 캐릭터 칸 저장 - 총 플레이 시간(초 · 이어하기 카드) · runtime = 쿨 종료 시각(os.time 기준 { [칸] = 초 }) · 궁 게이지 · 마지막 위치(구역 · 좌표 - 메뉴 왕복 · 재접속 복원)
		playSeconds = 0,
		runtime = { cooldownEnds = {}, ultGauge = 0, lastZone = nil, lastPos = nil },

		-- ⚠ 29-5부터 **아무도 읽지 않는다**: 보스의 정체는 스테이지 번호만의 함수가 됐다(BossRules.bossIdForStage, PRD 20.80 [A]).
		-- 필드는 지우지 않는다 - 옛 세이브가 검증(아래 type 검사)·이관을 그대로 통과하고, 되돌릴 일이 생겨도 데이터가 남아 있다.
		-- 아래는 23-5 당시의 뜻이다.
		-- 무한 모드 보스 순환(23-5, PRD 20.50 [5]) - "비복원 추출 + 주기 재셔플"의 상태.
		-- order: 이번 바퀴에 섞인 6종 순서. index: 다음에 뽑을 위치(1~7 - 7이면 다 썼다는
		-- 뜻, 다음 뽑기에서 재셔플). pending: 지금 확정돼 있고 아직 못 깬 보스({stage=,
		-- bossId=} 또는 false) - 사망 리셋·재도전은 이 값을 그대로 쓰고, 처치하면 지운다
		-- (PlayerProfile.clearBossRotationPending). history: 실제로 등장 확정된 보스 id
		-- 순서(관측용, 최근 50개만 - "임의 결정" 목록 참고, 순환 알고리즘 자체엔 안 쓰인다).
		-- debugForceNextId: "/gg boss force" 전용 - 다음 뽑기를 한 번만 이 값으로 강제한다.
		-- 직업별이다(19-4 개인 인스턴스 진행도와 같은 층 - 무한 모드 진행도 자체가 직업별).
		-- 환생 시 초기화하지 않는다(PlayerProfile.rebirth가 이 필드를 건드리지 않는다 -
		-- 20.50 [5] "환생은 진행 상태가 아니라 연출 다양성이므로 초기화하면 안 된다").
		bossRotation = { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false },
	}
end

-- ClassData.order를 순회해 만든다 - 직업이 4개든 6개든 이 함수는 그대로다(코드에 "4"를
-- 박지 않는다는 19-1 지시).
local function defaultClasses()
	local classes = {}
	for _, classId in ipairs(ClassData.order) do
		classes[classId] = defaultClassState()
	end
	return classes
end

-- SEC-FIX-1 11: 라이브 이름 자리(server/LiveStoreConfig - nil = 옛 이름 그대로 · Studio = 늘 SaveConfig 이름)
local liveStoreName = not RunService:IsStudio() and require(script.Parent.LiveStoreConfig).playerDataStoreName or nil
SaveSystem.storeName = liveStoreName or SaveConfig.dataStoreName
local store = DataStoreService:GetDataStore(SaveSystem.storeName)

local function profileKey(player)
	return "Player_" .. player.UserId
end

-- S19b 사전 작업 2 - 검증용 저장 분리. 검증 모드(DevToolsConfig.verifyArmed)에서는 실제 프로필 키(Player_<id>)를 **읽기만** 하고, 쓰기 · 다시 읽기는 전부
-- Player_<id>_verify 키로 한다. 그래서 검증 블록이 프로필을 바꿔 놓은 채 Play가 멈춰도(S19 실측: S12(나) 도중 정지 → 견습 상태가 저장에 남음) 실제 프로필은
-- 그대로다. 이 서버에서 그 플레이어를 처음 읽을 때 검증 키를 비워 실제 프로필로 새로 시작한다(지난 Play의 검증 상태가 이어지지 않는다). 검증 모드가 꺼져
-- 있으면(사용자가 그냥 누른 Play · 라이브 서버) 이 함수는 항상 실제 키다.
-- M1-3 전(M1-2 결정 3 - 사용자 확정 A): 검증 모드가 아닌 Studio Play(수동 Play)도 같은 장치로 Player_<id>_manual 키에 쓴다 - 개발 계정 실제 프로필 오염 방지.
--   수동 Play 진행은 다음 Play에 남지 않는다(서버마다 실제 프로필로 새로 시작). 라이브 서버는 항상 실제 키.
local function studioSuffix()
	if DevToolsConfig.verifyArmed then
		return "_verify"
	end
	if RunService:IsStudio() then
		return "_manual"
	end
	return nil
end

local function storeKey(player)
	return profileKey(player) .. (studioSuffix() or "")
end

local verifySeeded = {} -- userId → true(이 서버에서 검증 · 수동 키를 비운 플레이어)

-- 저장된 원본(raw)을 읽는다. 검증 · 수동 Play의 첫 읽기 = 그 키를 비우고 실제 프로필을 시드로 읽는다. 그 뒤(재접속 · 왕복 검증)는 그 키를 먼저 본다.
local function readStored(player)
	if not studioSuffix() then
		return store:GetAsync(profileKey(player))
	end
	if not verifySeeded[player.UserId] then
		store:RemoveAsync(storeKey(player))
		verifySeeded[player.UserId] = true
		print(("[SaveSystem] %s: %s 저장 키 = %s (실제 %s는 읽기만 - 쓰지 않는다)"):format(DevToolsConfig.verifyArmed and "검증 모드" or "수동 Play", player.Name, storeKey(player), profileKey(player)))
	end
	local raw = store:GetAsync(storeKey(player))
	if raw ~= nil then
		return raw
	end
	-- QUEUE-ALL1 ★0 신규 계정 재현(Studio 전용 - studioSuffix가 있을 때만): edit 모드에서 ReplicatedStorage Attribute StudioFreshProfile = true →
	--   실제 프로필을 시드로 읽지 않고 빈 프로필(처음 들어온 계정)로 시작한다. 쓰기는 위 _manual · _verify 키뿐이라 실제 프로필은 그대로다.
	if ReplicatedStorage:GetAttribute("StudioFreshProfile") == true then
		print(("[SaveSystem] %s: StudioFreshProfile - 신규 계정으로 시작(%s)"):format(player.Name, storeKey(player)))
		return nil
	end
	return store:GetAsync(profileKey(player))
end

-- 저장 구조 기본값. 지금 실제로 쓰는 필드는 gold·equipment.weapon뿐이지만, 곧 들어올
-- 필드(클래스·나머지 장비·스테이지 진행도·인벤토리 칸 수·게임패스)의 자리를 미리
-- 만들어 둔다 - 그래야 그 기능이 생길 때 SAVE_VERSION을 또 올리지 않고 채워 넣을 수 있다.
-- QUEUE-ALL1 P5(v59) 도감 v2 빈 기록
function SaveSystem.newCodex()
	return { armor = {}, prim = {}, trans = {}, pet = {}, mkill = {}, msparkle = {}, boss = {}, cls = {}, clsT = {}, done = {}, claimed = {}, boardDone = {}, boardClaimed = {}, title = nil }
end

local function defaultProfile()
	return {
		version = SaveConfig.saveVersion,
		savedAt = 0, -- migrate() 시점 데이터는 항상 "가장 오래된 것"으로 본다(웹 core/save.js와 같은 원칙)
		sessionId = "", -- v55 약한 세션 잠금: 마지막으로 저장한 서버의 표식("" = 퇴장 · 종료 저장으로 놓음)

		-- 계정 전체 공유(19-1 확정 - 직업을 바꿔도 빈털터리가 되지 않고, 다른 직업이 쓸
		-- 장비를 자유롭게 넘길 수 있어야 한다는 설계). 직업별로 갈라지는 값은 전부
		-- classes 아래에 있다 - 이 아래(gold·inventory*·gamepasses)엔 절대 넣지 않는다.
		gold = 0,
		inventorySlots = SaveConfig.defaultInventorySlots,

		-- 일괄판매 기준 등급(20-3) - 계정 전체 공유(gold·inventory와 같은 층). 매번 다시
		-- 고르게 하지 않으려고 저장한다. 가장 안전한 기본값(일반)으로 시작한다 - 처음
		-- 켰을 때 실수로 비싼 등급까지 팔리는 사고를 막는다.
		bulkSellCutoffGrade = "normal",

		-- 장비창 위치(23-5, 지시 "재접속해도 유지되게") - 계정 전체 공유(gold·
		-- bulkSellCutoffGrade와 같은 층, UI 배치는 직업과 무관한 화면 설정이다).
		-- false = "한 번도 직접 옮긴 적 없다"(InventoryUI.client.lua가 채팅·HUD를 피하는
		-- 기본 계산 위치를 그대로 쓴다). 옮기면 {x=, y=} 픽셀 좌표를 그대로 저장한다 -
		-- 뷰포트가 달라지면 클라이언트가 매번 화면 안으로 다시 잘라 넣는다(fitWindow).
		inventoryWindowPosition = false,

		-- 인벤토리 실제 내용물(12-1). 갑옷 드랍만 담는다 - { grade = "normal"/"rare",
		-- dropStage = 주운 스테이지 }. 슬롯 수(inventorySlots)와 분리된 필드다 - 슬롯 수는
		-- "몇 칸인가"고 이건 "무엇이 들었는가"다.
		inventory = {},

		-- 구매한 게임패스 집합. QUEUE-B1 B2(v56): { [MonetizationData.gamePasses 키] = true } - 접속 때 UserOwnsGamePassAsync로 다시 맞추는 캐시
		-- (조회 실패면 이 값을 쓴다 - 산 사람이 혜택을 잃지 않게). 진실 = Roblox 소유 기록.
		gamepasses = {},

		-- QUEUE-ALL1 P3 §4(v57): 주간 합동 목표 - week = Quest.weekOf(월요일 UTC) · contributed = 그 주 내 기여(받을 자격 ≥ 1) · claimed = { [칸 번호 문자열] = true }(주가 바뀌면 CommunityGoalService가 비운다)
		communityGoal = { week = 0, contributed = 0, claimed = {} },
		-- QUEUE-ALL1 P4(v58): 코드(대문자 코드 → 받은 unix 초 - 계정당 1회) · 주간 도전(week · best = 그 주 최고 처치 초 · rewarded = 참여 보상 · rankClaimedWeek = 순위 보상을 확인한 주)
		redeemedCodes = {},
		weeklyChallenge = { week = 0, rewarded = false, rankClaimedWeek = 0 },
		-- QUEUE-ALL1 P5(v59): 도감 v2 기록(shared/CodexRules 머리 주석) · done/boardDone = { [칸] = 완료 순간 계정 최고 스테이지 } · claimed/boardClaimed = 받음 · title = 고른 칭호 id(nil = 없음)
		codex = SaveSystem.newCodex(),

		-- 옵션 변환권(23-2, PRD 20.37 [6] "계정 공유(신규)"). 골드로만 구매(20.5-1 - 로벅스
		-- 판매 금지)하고 등급별로 따로 센다(고대 보석엔 고대 변환권만, 태초는 태초만) -
		-- 두 등급만 있는 이유는 GemData.optionPoolByGrade가 그 둘만 옵션 풀을 갖기 때문이다
		-- (영웅·전설·유물 보석은 재굴림할 옵션 자체가 없다).
		-- protectionTickets(28-1 S05) = 방지권 보유 장수(하락 · 초기화). protectionClaimedStages = { [tostring(보스 스테이지)] = true } - 보스 계정 첫 클리어 지급을 이미
		-- 받은 스테이지(계정 단위 - 직업별 bossFirstClearStages와 별개 집합이라 부캐로 같은 스테이지를 다시 깨도 방지권은 안 나온다). 키는 문자열이다 - DataStore 왕복이
		-- 숫자 키를 문자열로 바꾸므로(PlayerProfile.hasClaimedProtectionStage 주석) 처음부터 문자열로 쓴다.
		purchases = {
			optionRerollTickets = { ancient = 0, primordial = 0 },
			protectionTickets = { drop = 0, reset = 0 },
			protectionClaimedStages = {},
			bagSources = {}, -- QUEUE-ALL9C 1-6(v69): 가방 칸 출처 { starter = true } - MonetizationData.bagSources(출처별 한 번)
			shopViews = 0, -- QUEUE-ALL9C 1-6(v69): 상점 연 횟수(스타터 팩 노출 = 첫 보스 처치 또는 두 번째 방문)
			receipts = {}, -- QUEUE-B1 B2(v56): { { id = PurchaseId 문자열, at } } 최근 MonetizationData.receiptKeep개 - ProcessReceipt 중복 지급 방지
			log = {}, -- QUEUE-B1 B2(v56): 구매 기록 { { at, key, purchaseId, robux, result } } 최근 logKeep줄
			-- bossCodex(30-0 S11) = { [bossId] = true } - 기여 10% 이상으로 처치한 보스 종(계정 공유 · 표시는 스테이지 선택 패널의 도감 줄뿐, 성능 보상 없음). 키는 BossData.bosses의 id.
			bossCodex = {},
		},

		-- 강화 재료 보유량(28-1 S04) - 계정 공유(gold · purchases와 같은 층). 무기는 직업별이지만 재료는 4직업이 나눠 쓴다. 처치 보상으로만 늘고
		-- 강화(19 ~ 24강 시도)가 소모한다 - 증감은 PlayerProfile.addMaterial · trySpendMaterial 하나뿐이다.
		materials = defaultMaterials(),

		-- 클래스 선택(10-3, 19-1부터 "현재 활성 직업" 포인터로 의미 확장). 필드는 있지만
		-- 값은 nil - "아직 하나도 안 골랐다"가 지금은 실제로 맞는 상태이고, 이 nil이 곧
		-- 클라이언트가 선택 UI를 띄우는 조건이 된다(ClassSelectUI.client.lua,
		-- PlayerProfile.init이 Attribute로 옮길 때 빈 문자열로 바꾼다 - Attribute는 nil을
		-- 담지 못한다). 억지 기본값(첫 클래스 자동 지정)을 넣으면 이미 고른 것으로 착각해
		-- 선택 UI가 영원히 안 뜬다. 4직업 전부 classes 아래에 이미 만들어져 있으므로
		-- (defaultClasses), classId는 "그중 어느 걸 지금 쓰고 있는가"만 가리킨다.
		classId = nil,

		-- 직업별 분리 데이터(19-1) - 캐릭터 레벨·무기·착용 장비 3부위·무한 모드 진행도.
		-- 4직업 전부 처음부터 만들어 둔다(선택 여부와 무관) - 그래야 나중에 다른 직업으로
		-- 갈아타도 그 직업은 이미 자기 자리를 갖고 있다.
		classes = defaultClasses(),

		-- 견습 모드 진행도(23-1, 계정 전체 공유 - PRD 20.47[3] "완료 플래그는 계정 단위").
		-- step: 0=미시작, 1~7=진행 중인 단계, completed=true가 되면 7단계를 깬 뒤다(step은
		-- 7에 남아 있다 - "완료했다"는 사실은 completed 하나로만 판정한다, step 값 자체로
		-- 겸용하지 않는다). granted: 재플레이 중복 지급 방지({[tostring(stepIndex)]=true} - 키는 문자열, v28, 1~3단계
		-- 확정 지급 + 7단계 완료 보상). lendBaseline: 대여 복원 원본(nil=대여 중 아님).
		tutorial = { completed = false, step = 0, granted = {}, lendBaseline = nil },

		-- 안내 플래그(30-0 S20e, v30) - 계정 전체 공유. 한 번 하고 나면 안내 표시가 줄어드는 종류의 "본 적 있다/해 본 적 있다" 기록이다(값이 없으면 false로 본다).
		--   gemMerchantUsed: 보석상인에서 변환 · 리롤(변환권 구매 포함)을 한 번이라도 성공했는가 - true면 보석 탭의 위치 안내 줄이 작은 회색 한 줄로 줄어든다.
		--   bossIntroSeen(BR1-2, v37): 전멸기 설명 카드를 본 보스 id 집합({ [bossId 문자열] = true }) - 처음 만난 보스만 카드가 뜬다.
		--   stealLockSeen(C1 마무리, v42): 잠긴 몹(다른 유저가 사냥 중)을 처음 때렸을 때 말풍선을 봤는가 - 계정당 1회.
		--   bossAssist(GUARDIAN-V3, v75): 첫 보스 도움 기록({ [bossId 문자열] = { fails = 전멸 수, cleared = 처치했는가 } }) - 처치 전까지 전멸마다 받는 피해 −10%(최대 −30%).
		hints = { gemMerchantUsed = false, bossIntroSeen = {}, stealLockSeen = false, bossAssist = {} },

		-- M1(v38): 세계 이동 - portals = 입구 캠프 첫 방문으로 연 포탈({ [구역 키 문자열] = true }) · 계정 공유.
		-- M1-3(v40): bossGates = 관문을 직접 찾아가 등록한 보스({ [bossId 문자열] = true }) - 등록된 보스는 어디서든 원격 입장(파티 = 한 명이라도 등록).
		-- M1-3(v41): nests = 둥지별 개인 기록({ [둥지 id 문자열] = { next = 다시 주울 수 있는 unix 초, picks = 주운 횟수 } }) · nestDex = 처음 찾은 비밀 둥지({ [id] = true } - 칭호 · 꾸미기만).
		world = { portals = {}, bossGates = {}, nests = {}, nestDex = {} },
		-- M1(v38): 역대 최고 캐릭터 레벨(직업 · 환생 무관 최대 - 내려가지 않는다). 나무 가지 정거장 개방 기준.
		peakLevel = 1,
		-- M1(v39): 칭호(계정 - 전투력 없음) - { [칭호 id 문자열] = true }. 첫 칭호 = 호기심 대장(봉인 입구 틈까지 올라감).
		titles = {},
		-- M1-3(v41): 알 가방(부화 · 펫은 펫 단계) - { { zone = 구역 키, grade = "normal" | "good" | "rare", species = { 후보 id 2 }, nest = 둥지 id, at = unix 초 } } · 상한 NestData.eggCap.
		eggs = {},
		audit = { lambda = 0, primordialRolls = 0, playSeconds = 0 }, -- S1(v44): 획득 감사(AcquisitionAudit)
		training = { attack = 0, hp = 0, defense = 0, advanced = 50, guard = 0 }, -- QUEUE-10h Q6(v50): 공용 수련 단계(계정 - TrainingData.stats) · QUEUE-ALL10(v70) advanced = 고급 수련 단계(50 = 아직 없음 ~ 100) · guard = 방어 수련(0 ~ 30) - 효과는 초월 무기 직업에만
		-- QUEUE-ALL10(v70): 초월 보석(계정 귀속 · 기본 잠금 · 판매/분해 불가) - list = { { id = "TG<n>", grade = "transcendent", itemLevel, option = { id, roll }, locked = true, socket = nil | { classId, slot }, at, source } } · seq = 번호
		--   무기 칸(weapon.gems[slot])에는 사본(transcendGemId = id)이 들어간다 - 진실 = 이 목록(추출 = 칸 비움 + socket = nil · 100% 보존).
		transcendGems = { list = {}, seq = 0 },
		quests = nil, -- QUEUE-10h Q6(v50): 퀘스트 상태(shared/Quest.newState - 로드 때 채움)
		checkpoints = { found = {} }, -- QUEUE-ALL3 Q5(v61): 체크포인트 발견 id 목록(WorldMapData.checkpoints.list)
		pets = nil, -- QUEUE-10h Q11(v52): 펫 상태(shared/Pet.newState - { list, equipped, hatchCount, hatching })
		settings = nil, -- QUEUE-10h Q14(v54): 설정({ [SettingsData 키] = 값 } - 없는 키 = 기본값 · SettingsService가 검증)
		comeback = { untilAt = 0 }, -- C5-5(v48): 복귀 부스트 만료 unix 초(0 = 없음) - SaveServer가 로드 직후 마지막 저장 savedAt과 비교해 준다
		-- QUEUE-B1 B2(v56) 수익화 골격: 치장(산 테마 세트 · 글라이더 스킨 · 칸별 장착 · 나무 정거장 조각 받은 기록 - 키는 전부 문자열) · 선물함 · 시즌 패스.
		--   purchases.receipts(영수증 중복 방지 - 최근 PurchaseId) · purchases.log(구매 기록)는 아래 purchases 안.
		cosmetics = { themes = {}, gliderSkins = {}, equipped = {}, treeStations = {}, items = {} }, -- QUEUE-ALL6 H(v64) items = 꾸미기 소품
		quarantine = {}, -- QUEUE-ALL5 A3(v63): 보관 칸 - 데이터에서 없어진 id를 가진 값({ kind, why, value, classId?, at }). 로드 실패 대신 여기로 · 그 id가 다시 생기면 제자리로(SaveSystem.quarantineUnknownIds)
		mailbox = { gifts = {}, seq = 0, claimedIds = {} }, -- gifts = { { id, kind, itemId | amount, from, note, at } } · seq = 이 계정 안 선물 번호 · claimedIds(v62) = 받은 선물 id(최근 MonetizationData.gifts.claimedIdsKeep개 - 재지급 방지)
		seasonPass = { season = 0, premium = false, claimedFree = {}, claimedPaid = {}, skipBought = 0, skipTiers = {}, skipDay = -1 }, -- season = 기록한 시즌 번호(바뀌면 경험치 · 받음 · 유료 초기화) · QUEUE-ALL9B v66 skipBought(이번 시즌 구매로 오른 칸) · skipTiers(건너뛴 칸 - 문자열 키)

		-- 보석 가루(P2.5b C, v31) - 계정 공유(gold · materials와 같은 층). 보석 분해로만 늘고(PlayerProfile.dismantleGem · dismantleGemsUpTo) 재련 · 변환권 구매가 쓴다(trySpendGemDust).
		gemDust = 0,

		-- 환생 후 해금 마일스톤 받은 개수(P2.5b D, v32) - 계정 공유(가방 칸 · 계승 할인 같은 계정 효과). MilestoneData.unlocks의 앞에서부터 이 개수만큼 열렸다.
		milestoneUnlocks = 0,

		-- 리더보드 기록 제외(P3a B3, v34) - 계정 단위. 이 계정에서 /gg(개발 명령)가 한 번이라도 돌면 true(PlayerProfile.markLeaderboardTainted) - "/gg로 만든 진도는 기록하지 않는다".
		leaderboardTainted = false,

		-- 줍는 순간 자동 처리(G1-2, v36) - 계정 단위(bulkSellCutoffGrade와 같은 층). enabled = 켜짐 · maxGrade = 이 등급 이하(ArmorData.autoProcessGradeChoices 중 하나).
		autoProcess = { enabled = false, maxGrade = AUTO_GRADE }, -- UI-1 4단계: 기본 = 가장 낮은 등급(일반)부터(사용자 10-10 · 옛 기본 epic)
	}
end

-- 25-1까지 쓰던 캐릭터 레벨 곡선(v11~v21 시절)을 리터럴로 보존한다 - CharacterLevel/
-- CharacterLevelConfig는 이미 새 곡선(목표 마릿수 역산)으로 바뀌어 있어 재사용할 수 없다
-- (migrate v11이 v10 공식을 리터럴로 남긴 것과 같은 원칙). 두 곳이 쓴다: v10->v11(그 시절
-- "새 공식"이 곧 이 곡선이었다 - 여기서 CharacterLevel(지금 곡선)을 쓰면 v22 블록이 v21
-- 곡선으로 레벨을 다시 읽을 때 어긋난다)과 v21->v22(레벨 보존 이관).
local LegacyCurveV21 = {}
do
	local WEAPON_LEVEL_EXP = {
		0, 50, 150, 300, 500, -- Lv1~5
		600, 800, 1100, 1500, 2000, -- Lv6~10
		2250, 2700, 3400, 4350, 5500, -- Lv11~15
		5950, 6800, 8100, 9850, 12000, -- Lv16~20
		12850, 14600, 17200, 20650, 25000, -- Lv21~25
	}
	local MAX_FINITE_LEVEL = #WEAPON_LEVEL_EXP -- 25
	local BASE, RATIO, DIVISOR = 50, 1.155, 0.155

	local function formula(level)
		return BASE * (RATIO ^ (level - 1) - 1) / DIVISOR
	end
	local peakFormula = formula(MAX_FINITE_LEVEL)

	-- useExponential: rebirthCount>=1인 직업은 1~25도 순수 지수식이었다(23-2).
	function LegacyCurveV21.getExpForLevel(level, useExponential)
		if useExponential then
			return formula(level)
		end
		if level <= MAX_FINITE_LEVEL then
			return WEAPON_LEVEL_EXP[level]
		end
		return WEAPON_LEVEL_EXP[MAX_FINITE_LEVEL] + (formula(level) - peakFormula)
	end

	function LegacyCurveV21.getLevelFromExp(exp, useExponential)
		local level = 1
		while exp >= LegacyCurveV21.getExpForLevel(level + 1, useExponential) do
			level += 1
		end
		return level
	end
end

-- 키를 전부 문자열로 바꾼 새 집합을 돌려준다(값은 그대로). 숫자 5와 문자열 "5"가 같이 있으면 하나("5")로 합쳐진다. v27->v28 이관 전용.
local function normalizeKeySet(set)
	local normalized = {}
	for key, value in pairs(set or {}) do
		normalized[tostring(key)] = value
	end
	return normalized
end

-- QUEUE-ALL10 1-1: 초월 계승 저장 값 정리(매 로드 - 이관 뒤 손상 · 개발 명령 값도). 숫자 = 정수 · NaN/inf → 기본 · 음수 → 하한.
--   리뷰 반영: 위쪽은 데이터 상한(maxLevel)으로 자르지 않는다(넉넉한 SANE_MAX만) - 상한을 올렸다 롤백해도 산 단계가 깎이지 않게. 상한은 계산할 때만(shared/All10이 clamp).
--   모양이 틀린 값은 지우지 않고 보관 칸(quarantine - kind "all10")으로 옮긴 뒤 기본값을 넣는다(초월 무기 grade 7이면 transcend = { level = 0, slot = 0 }).
local SANE_MAX = 1e6
local function int(v, lo, default)
	v = tonumber(v)
	if v == nil or v ~= v or v == math.huge or v == -math.huge then
		return default
	end
	return math.clamp(math.floor(v), lo, SANE_MAX)
end
function SaveSystem.sanitizeAll10(data)
	local A = require(ReplicatedStorage.Shared.data.All10Data)
	data.quarantine = type(data.quarantine) == "table" and data.quarantine or {}
	local function park(why, value, classId)
		table.insert(data.quarantine, { kind = "all10", why = why, value = value, classId = classId, at = os.time() })
	end
	if type(data.training) == "table" then
		data.training.advanced = int(data.training.advanced, A.advancedTraining.fromLevel - 1, A.advancedTraining.fromLevel - 1)
		data.training.guard = int(data.training.guard, 0, 0)
	end
	if type(data.transcendGems) ~= "table" then
		if data.transcendGems ~= nil then
			park("transcendGems_shape", data.transcendGems)
		end
		data.transcendGems = { list = {}, seq = 0 }
	end
	local tg = data.transcendGems
	if type(tg.list) ~= "table" then
		park("transcendGems_list_shape", tg.list)
		tg.list = {}
	end
	tg.seq = math.max(int(tg.seq, 0, 0), #tg.list) -- id 중복 방지(번호 < 개수면 끌어올림)
	for classId, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
		if type(classState) == "table" and classState.showOwnClothes ~= nil and type(classState.showOwnClothes) ~= "boolean" then -- QUEUE-ALL9E1 LOOK2(v73): 참/거짓만(모양 틀림 = 보관 칸 + 끔)
			park("showOwnClothes_shape", classState.showOwnClothes, classId)
			classState.showOwnClothes = false
		end
		local weapon = type(classState) == "table" and classState.weapon
		if type(weapon) == "table" and (weapon.transcend ~= nil or weapon.grade == A.inherit.toGrade) then
			if type(weapon.transcend) ~= "table" then
				if weapon.transcend ~= nil then
					park("weapon_transcend_shape", weapon.transcend, classId)
				end
				weapon.transcend = weapon.grade == A.inherit.toGrade and { level = 0, slot = 0, fails = 0 } or nil -- 초월 무기면 기본 단계로(없던 값을 만들지 않는다 - grade 7이 아니면 그대로 없음)
			end
			if weapon.transcend then
				weapon.transcend.level = int(weapon.transcend.level, 0, 0)
				weapon.transcend.slot = int(weapon.transcend.slot, 0, 0)
				weapon.transcend.fails = int(weapon.transcend.fails, 0, 0) -- QUEUE-ALL9E1 0-4(v71) 불씨
				if weapon.transcendSlots ~= nil then -- QUEUE-ALL9E1-ADD B(v72) 초월 홈: 1 ~ 5번만 · 값 true만(모양 틀림 = 보관 칸 + 비움)
					local ok = type(weapon.transcendSlots) == "table"
					local clean = {}
					for k, v in pairs(ok and weapon.transcendSlots or {}) do
						local n = tonumber(k)
						if n and n >= 1 and n <= 5 and n == math.floor(n) and v == true then
							clean[n] = true
						else
							ok = false
						end
					end
					if not ok then
						park("weapon_transcendSlots_shape", weapon.transcendSlots, classId)
					end
					weapon.transcendSlots = clean
				end
			end
		end
		local rec = type(classState) == "table" and classState.transcendInherit
		if rec ~= nil then
			if type(rec) ~= "table" then
				park("transcendInherit_shape", rec, classId)
				classState.transcendInherit = nil
			else
				local best = type(classState.stageProgress) == "table" and tonumber(classState.stageProgress.infiniteBest) or 1
				rec.stage = int(rec.stage, 1, math.max(1, math.floor(best or 1))) -- 손상 = 지금 최고 스테이지(돌파가 이미 끝난 쪽 - 이득 없음)
				rec.at = int(rec.at, 0, 0)
			end
		end
	end
end

-- data.version < SaveConfig.saveVersion일 때 순차 변환(웹 core/save.js와 같은 패턴).
-- 다음 필드 추가 절차: 1) defaultProfile에 필드 추가 2) SaveConfig.saveVersion을 올린다
-- 3) 아래에 `if data.version < N then ... data.version = N end` 블록을 추가한다.
-- 지금은 16단계 - 0(스키마 버전 개념 자체가 없던 상태) -> 1(골드 도입) -> 2(시작 무기
-- 지급) -> 3(클래스 선택 필드 도입) -> 4(무한 모드 스테이지 현재/최고 분리)
-- -> 5(인벤토리 배열 도입) -> 6(인벤토리 아이템 locked 필드 도입) -> 7(캐릭터 레벨 도입 +
-- 아이템 itemLevel 필드 도입) -> 8(보스 처치 기록 bestBossCleared 도입, 15-1)
-- -> 9(equipment.boots -> shoes 이름 정리, 16-6) -> 10(아이템 part 필드 소급 도입, 16-6)
-- -> 11(캐릭터 레벨 EXP 곡선 26+ 구간 재보정, 17-1) -> 12(아이템 tierIndex 필드 소급
-- 도입, 17-1) -> 13(characterExp·무기·장비 3부위·무한 모드 진행도를 classes[classId]
-- 아래로 직업별 분리, 19-1) -> 14(무기 등급 grade 필드 도입, 20-1) -> 15(일괄판매 기준
-- 등급 선택 bulkSellCutoffGrade 필드 도입, 20-3) -> 16(보스 첫 처치 확정 드랍 기록
-- bossFirstClearStages + 환생 횟수 rebirthCount 스텁 도입, 20-4) -> 17(견습 모드 진행도
-- 도입, 23-1) -> 18(무기 보석 슬롯 도입, 23-2) -> 19(옵션 변환권 도입, 23-2) -> 20(보석
-- 등급이 슬롯 고정에서 상한제로 바뀌며 gem.grade 필드 신설 + 슬롯 해금 상태 저장 필드
-- weapon.slotUnlocked 신설, 23-4) -> 21(무한 모드 보스 순환 상태 bossRotation 필드 +
-- 장비창 위치 저장 필드 inventoryWindowPosition 신설, 23-5) -> 22(캐릭터 레벨 곡선을 목표
-- 마릿수 역산 하나로 통일 - characterExp를 같은 레벨·진행률 위치로 재배치, 25-1) -> 23(보석·
-- 장비 옵션 통합 - gem.optionId를 gem.option({id, roll})으로 치환 + itemLevel 백필, 26-1) -> 24(옛 규칙으로
-- 부풀려진 장비 itemLevel을 min(itemLevel, dropStage + 2)로 절단 - 스키마 변화 없음, 30-0 S02) -> 25(강화 천장 게이지
-- weapon.enhanceGauge 신설 - 전부 0, 30-0 S03) -> 26(강화 재료 보유량 materials 신설 - 전부 0, 30-0 S04) -> 27(방지권 purchases.protectionTickets · protectionClaimedStages 신설 - 0장 · 빈 집합, 30-0 S05) -> 28(bossFirstClearStages · tutorial.granted의 키를 문자열로 통일 - 스키마 변화 없음, 30-0 S05 후속) -> 29(보스 도감 도장 purchases.bossCodex 신설 - 빈 집합, 30-0 S11) -> 30(안내 플래그 hints, S20e) -> 31(보석 가루 gemDust 신설 - 0, P2.5b C) -> 32(환생 후 마일스톤 milestones · milestoneUnlocks 신설 - 빈 표 · 0, P2.5b D) -> 33(마일스톤 재설계 - milestones 표를 milestoneLevel 숫자로, P2.5c B2) -> 34(리더보드 기록 제외 leaderboardTainted 신설 - 보스 클리어가 있던 세이브는 true, P3a B3).
local function migrate(data)
	local isNewAccount = data.version == nil -- Q12 리뷰(치명): 새 계정 = 저장 없음(raw nil → {}) - 빈 표도 이관 체인을 다 탄다
	data.version = data.version or 0

	if data.version < 1 then
		data.gold = data.gold or 0
		data.equipment = data.equipment or { weapon = nil, armor = nil, gloves = nil, shoes = nil }
		data.stageProgress = data.stageProgress or { normal = 1, infinite = 0 }
		data.inventorySlots = data.inventorySlots or SaveConfig.defaultInventorySlots
		data.gamepasses = data.gamepasses or {}
		data.version = 1
	end

	if data.version < 2 then
		-- 10-2 도입 시점에 이미 있던 v1 저장은 equipment.weapon이 nil이다(그때는 무기
		-- 자체가 없었으니 당연하다) - 강화할 대상이 있어야 하므로 지금 지급한다.
		data.equipment.weapon = data.equipment.weapon or defaultWeapon()
		data.version = 2
	end

	if data.version < 3 then
		-- classId는 기본값이 nil이라 채울 값이 없다(defaultProfile 주석과 같은 이유) - 이
		-- 블록은 스키마 버전을 명시적으로 올리는 용도다(SAVE_VERSION 규칙, CLAUDE.md).
		data.version = 3
	end

	if data.version < 4 then
		-- v3까지 infinite=0은 "무한 모드 미진입"의 잠정 자리였다(defaultProfile의 이전
		-- 주석 참고) - 11-1부터 무한 모드가 유일한 모드가 되면서 그 개념이 없어졌다.
		-- 기존 0은 실제로 아무 진행도 없었다는 뜻이라 1로 승격해도 정보 손실이 없다.
		-- infiniteBest는 이번에 처음 생기는 필드라, 지금까지의 유일한 기준점(현재
		-- 단계)을 그대로 최고 기록으로 물려받는다.
		data.stageProgress.infinite = math.max(data.stageProgress.infinite or 0, 1)
		data.stageProgress.infiniteBest = data.stageProgress.infiniteBest or data.stageProgress.infinite
		data.version = 4
	end

	if data.version < 5 then
		-- v4까지 인벤토리라는 실체 자체가 없었다(inventorySlots는 칸 "수"만 있었다) -
		-- 이번에 처음 생기는 필드라 빈 배열이 정확한 기본값이다.
		data.inventory = data.inventory or {}
		data.version = 5
	end

	if data.version < 6 then
		-- v5까지 있던 아이템엔 locked 필드 자체가 없었다(13-1에서 처음 생겼다) - "잠긴 적
		-- 없다"가 정확한 과거 상태이므로 false로 채운다. 착용 중인 아이템(인벤토리 배열
		-- 밖, equipment.armor)도 나중에 해제되면 인벤토리로 돌아가므로 같이 채워둔다.
		for _, item in ipairs(data.inventory) do
			item.locked = item.locked or false
		end
		if data.equipment.armor then
			data.equipment.armor.locked = data.equipment.armor.locked or false
		end
		data.version = 6
	end

	if data.version < 7 then
		-- v6까지 characterExp 필드 자체가 없었다(13-2에서 처음 생겼다) - 과거 경험치를
		-- 복원할 데이터가 없으니 0(레벨1)으로 시작한다(유일하게 가능한 값).
		data.characterExp = data.characterExp or 0

		-- v6까지 아이템엔 itemLevel이 없었다(방어력이 dropStage 기준이었다, 12-1). 레벨1로
		-- 채우면 기존 장비가 전부 최약체가 되어 "저장 무손실 승계" 취지에 반한다(v2->v3
		-- 마이그레이션 때와 같은 원칙, 14장 참고) - 대신 이 게임 자체가 이미 정의해 둔
		-- 관계식(PRD 20.8-3 recommendedStage = characterLevel - 25의 역함수)을 그대로 써서
		-- itemLevel = dropStage + 25로 추정한다. 임의의 짐작이 아니라 게임의 1:1 대응
		-- 규칙을 반대로 적용한 것이다. dropStage 필드는 지우지 않는다 - getSellPrice가
		-- 계속 쓴다(Loot.lua 주석 참고).
		for _, item in ipairs(data.inventory) do
			item.itemLevel = item.itemLevel or ((item.dropStage or 1) + 25)
		end
		if data.equipment.armor then
			data.equipment.armor.itemLevel = data.equipment.armor.itemLevel or ((data.equipment.armor.dropStage or 1) + 25)
		end
		data.version = 7
	end

	if data.version < 8 then
		-- v7까지 bestBossCleared 필드 자체가 없었다(보스가 15-1에서 처음 생겼다) - "아직
		-- 하나도 못 깼다"가 정확한 과거 상태이므로 0으로 채운다(defaultProfile과 같은 값,
		-- 유일하게 가능한 값이기도 하다 - 이 필드가 생기기 전엔 보스 자체가 없었으니
		-- "이미 깬 보스"가 있을 수 없다).
		data.stageProgress.bestBossCleared = data.stageProgress.bestBossCleared or 0
		data.version = 8
	end

	if data.version < 9 then
		-- v8까지 "boots" 필드는 존재는 했지만(v1부터) 실제로 채워진 적이 없다(장갑·신발
		-- 드랍 자체가 16-6 전엔 없었다) - 값을 옮길 데이터가 없으므로 이름만 정리한다.
		-- 혹시 모를 값(예: 수동 편집된 저장)이 있으면 안전하게 이어받는다.
		if data.equipment then
			data.equipment.shoes = data.equipment.shoes or data.equipment.boots
			data.equipment.boots = nil
		end
		data.version = 9
	end

	if data.version < 10 then
		-- v9까지 아이템엔 part 필드 자체가 없었다(16-6 전엔 갑옷만 드랍됐으니 부위 구분이
		-- 필요 없었다) - "그 시절 나온 아이템은 전부 갑옷이었다"가 정확한 과거 상태이므로
		-- armor로 채운다. 이걸 안 하면 equipItem이 item.part 없이는 착용을 거부해(그대로
		-- 조회) 예전에 얻은 아이템을 영영 착용할 수 없게 된다.
		for _, item in ipairs(data.inventory) do
			item.part = item.part or "armor"
		end
		if data.equipment and data.equipment.armor then
			data.equipment.armor.part = data.equipment.armor.part or "armor"
		end
		data.version = 10
	end

	if data.version < 11 then
		-- 17-1: 캐릭터 레벨 EXP 곡선 26+ 구간 공비를 1.216/0.216 -> 1.155/0.155로 바꿨다
		-- (CharacterLevelConfig.lua 주석 참고). 이 재보정만으로 기존 characterExp가 새
		-- 공식에서 다른 레벨로 재해석되면 안 된다 - 옛 공식(아래에 리터럴로 그대로 남긴다,
		-- CharacterLevelConfig는 이미 새 값으로 바뀌어 있어 재사용할 수 없다)으로 먼저
		-- 레벨을 구하고, 그 레벨의 새 공식 상 필요 누적치로 characterExp를 다시 맞춘다 -
		-- 레벨은 그대로 유지되고 레벨 내 진행률만 0으로 리셋된다(레벨이 오르내리는 것보다
		-- 안전한 쪽 - v7 마이그레이션의 "저장 무손실 승계" 원칙과 같다).
		local OLD_RATIO, OLD_DIVISOR, OLD_BASE = 1.216, 0.216, 50
		local MAX_FINITE_LEVEL = 25 -- 그 시절 weaponLevelExp 표 길이, 바뀐 적 없다
		local OLD_TABLE_EXP = function(level) return LegacyCurveV21.getExpForLevel(level, false) end -- 1~25 표 그대로

		local function oldExpFormula(level)
			return OLD_BASE * (OLD_RATIO ^ (level - 1) - 1) / OLD_DIVISOR
		end
		local oldPeakFormula = oldExpFormula(MAX_FINITE_LEVEL)

		local function oldGetExpForLevel(level)
			if level <= MAX_FINITE_LEVEL then
				return OLD_TABLE_EXP(level)
			end
			return OLD_TABLE_EXP(MAX_FINITE_LEVEL) + (oldExpFormula(level) - oldPeakFormula)
		end

		local function oldGetLevelFromExp(exp)
			local level = 1
			for i = 1, MAX_FINITE_LEVEL do
				if exp >= OLD_TABLE_EXP(i) then
					level = i
				else
					return level
				end
			end
			while exp >= oldGetExpForLevel(level + 1) do
				level += 1
			end
			return level
		end

		local oldLevel = oldGetLevelFromExp(data.characterExp or 0)
		if oldLevel > MAX_FINITE_LEVEL then
			-- 25-1: 이 시점의 "새 공식"은 v21까지의 곡선이다(LegacyCurveV21) - 지금의
			-- CharacterLevel을 쓰면 아래 v22 블록이 레벨을 잘못 읽는다.
			data.characterExp = LegacyCurveV21.getExpForLevel(oldLevel, false)
		end
		data.version = 11
	end

	if data.version < 12 then
		-- 17-1: 드랍표를 tier별로 실제 연결하면서 아이템에 tierIndex 필드가 처음 생겼다 -
		-- 그 전엔 몬스터 tier 구분 없이 tier1의 확률표 하나로만 굴렸으니(v10까지)
		-- "그 시절 나온 아이템은 전부 tier1"이 정확한 과거 상태다(v10의 part 소급과 같은
		-- 원칙).
		for _, item in ipairs(data.inventory) do
			item.tierIndex = item.tierIndex or 1
		end
		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			if data.equipment and data.equipment[part] then
				data.equipment[part].tierIndex = data.equipment[part].tierIndex or 1
			end
		end
		data.version = 12
	end

	if data.version < 13 then
		-- 19-1: 직업별 저장 분리. characterExp·무기·착용 장비 3부위·무한 모드 진행도가
		-- classes[classId] 아래로 옮겨간다. gold·인벤토리·게임패스는 계정 전체 공유라
		-- 최상위에 그대로 둔다(움직이지 않는다).
		local classes = defaultClasses()

		if data.classId and classes[data.classId] then
			-- 이미 직업을 골랐던 유저 - 지금까지 쌓아온 진행도는 "지금 하던 그 직업"으로만
			-- 옮긴다(유일하게 맞는 귀속처 - 20.35 α 재보정 때처럼 "저장 무손실 승계"
			-- 원칙, v7 마이그레이션과 같다). 나머지 3직업은 defaultClassState() 그대로
			-- 둔다 - 한 번도 플레이한 적 없으니 레벨1·시작무기가 정확한 초기 상태다.
			classes[data.classId] = {
				characterExp = data.characterExp or 0,
				weapon = data.equipment.weapon or defaultWeapon(),
				equipment = {
					armor = data.equipment.armor,
					gloves = data.equipment.gloves,
					shoes = data.equipment.shoes,
				},
				stageProgress = {
					infinite = data.stageProgress.infinite or 1,
					infiniteBest = data.stageProgress.infiniteBest or 1,
					bestBossCleared = data.stageProgress.bestBossCleared or 0,
				},
			}
		end
		-- classId가 nil이면(한 번도 선택 안 한 계정) 옮길 데이터 자체가 없다 - 위에서 만든
		-- 4직업 전부 초기 상태 그대로 둔다. classId는 계속 nil이라 클라이언트가 여전히
		-- 선택 UI를 띄운다(defaultProfile과 같은 동작).

		data.classes = classes
		-- 예전 최상위 필드는 이제 이 자리에 없다 - 지우지 않으면 두 곳에 값이 남아 어느
		-- 쪽이 진짜인지 헷갈린다(isValidProfile도 이 필드들의 부재를 전제로 검사한다).
		data.characterExp = nil
		data.equipment = nil
		data.stageProgress = nil
		-- data.classId 자체는 지우지 않는다 - 값 그대로(선택했으면 그 문자열, 아니면 nil)
		-- "현재 활성 직업" 포인터로 의미만 넓어진다.
		data.version = 13
	end

	if data.version < 14 then
		-- 20-1: 무기 등급 축 신설. v13까지 weapon엔 grade 필드 자체가 없었다(무기 등급이라는
		-- 개념이 이번에 처음 생겼다) - "그 시절 무기는 전부 일반 등급이었다"가 정확한 과거
		-- 상태이므로 0(일반)으로 채운다(v10의 part 소급과 같은 원칙). 강화 단계(weapon.level)는
		-- 이 블록이 건드리지 않는다 - 그대로 보존된다.
		for _, classState in pairs(data.classes) do
			classState.weapon.grade = classState.weapon.grade or 0
		end
		data.version = 14
	end

	if data.version < 15 then
		-- 20-3: 일괄판매 기준 등급 선택 신설. v14까지는 이 선택 개념 자체가 없었다(항상
		-- "잠긴 것만 빼고 전부") - 가장 안전한 기본값(일반)으로 시작한다.
		data.bulkSellCutoffGrade = data.bulkSellCutoffGrade or "normal"
		data.version = 15
	end

	if data.version < 16 then
		-- 20-4: 보스 첫 처치 확정 드랍 규칙 신설(지시 [1]) - bossFirstClearStages(그
		-- 스테이지 보스를 확정 보상으로 이미 받았는가)와 rebirthCount(환생 횟수 스텁,
		-- 환생 시스템 자체는 아직 없다) 두 필드가 처음 생긴다. bossFirstClearStages는
		-- 일부러 bestBossCleared에서 역산해 채우지 않는다 - 빈 집합으로 시작하면 기존
		-- 계정도 이미 깬 보스를 한 번은 다시 확정 보상으로 받는다(지시 원문 그대로 채택 -
		-- "다르게 해야 할 이유가 있으면 보고해라"에 대한 결정). rebirthCount는 과거 어떤
		-- 계정도 환생한 적이 없으므로(환생 시스템 자체가 없었다) 0이 유일하게 맞는 값이다.
		for _, classState in pairs(data.classes) do
			classState.stageProgress.bossFirstClearStages = classState.stageProgress.bossFirstClearStages or {}
			classState.rebirthCount = classState.rebirthCount or 0
		end
		data.version = 16
	end

	if data.version < 17 then
		-- 23-1: 견습 모드 진행도 신설. 기존 계정(어느 직업이든 이미 보스를 한 번이라도 깬
		-- 적이 있으면)은 견습을 완료한 것으로 간주한다(지시 원문 그대로 - "이미 무한을
		-- 플레이 중인 기존 플레이어는 견습 완료로 간주한다"). step은 무의미해지므로 완료
		-- 표시와 함께 7(마지막 단계)로 채운다 - 0으로 두면 "완료했는데 미시작"이라는 모순된
		-- 조합이 생긴다. 신규 계정(어느 직업도 보스를 못 깼음)은 completed=false, step=0 -
		-- defaultProfile과 같은 시작 상태다.
		local hasBeatenAnyBoss = false
		for _, classState in pairs(data.classes) do
			if (classState.stageProgress.bestBossCleared or 0) >= BossData.stageInterval then
				hasBeatenAnyBoss = true
				break
			end
		end
		data.tutorial = data.tutorial or {
			completed = hasBeatenAnyBoss,
			step = hasBeatenAnyBoss and 7 or 0,
			granted = {},
			lendBaseline = nil,
		}
		data.version = 17
	end

	if data.version < 18 then
		-- 23-2: 무기 보석 슬롯 신설(PRD 20.38 [2]). v17까지 weapon.gems·classState.
		-- gemInventory 필드 자체가 없었다(보석 시스템 자체가 없었다) - "그 시절 무기는
		-- 슬롯이 하나도 안 열려 있었다"가 정확한 과거 상태이므로 5칸 전부 빈 슬롯(false)으로
		-- 채운다(v14의 weapon.grade 소급과 같은 원칙). rebirthCount는 이미 v16에서 스텁으로
		-- 생겼으므로 손대지 않는다 - 그 값이 곧 "몇 번째 슬롯까지 열렸어야 하는가"를 뜻하지만,
		-- 과거에 DevTools "/gg rebirth"로 스텁을 올려놨던 계정이라 해도 그건 정식 환생이
		-- 아니었으니(보스 첫 처치 드랍표 분기 검증용) 슬롯까지 소급 개방하지 않는다 - 실제
		-- 슬롯 보석은 이 버전부터 진짜 환생(PlayerProfile.rebirth)에서만 나온다.
		for _, classState in pairs(data.classes) do
			classState.weapon.gems = classState.weapon.gems or { false, false, false, false, false }
			classState.gemInventory = classState.gemInventory or {}
		end
		data.version = 18
	end

	if data.version < 19 then
		-- 23-2: 옵션 변환권 신설(PRD 20.37 [6]). v18까지 이 통화 개념 자체가 없었다 - 0개
		-- 보유가 정확한 과거 상태다.
		data.purchases = data.purchases or { optionRerollTickets = { ancient = 0, primordial = 0 } }
		data.version = 19
	end

	if data.version < 20 then
		-- 23-4: 보석 슬롯이 "고정 등급"에서 "등급 상한"으로 바뀌었다(GemData.slotGradeCap).
		-- v19까지 gems[slot]엔 grade 필드 자체가 없었다 - 그때는 슬롯 번호가 곧 등급이라
		-- (그 시절의 slotGradeOrder, 지금은 이름이 바뀐 slotGradeCap과 값이 다르다) 따로
		-- 저장할 필요가 없었다. 지금 새로 도입되는 slotGradeCap을 쓰면 과거 보석의 실제
		-- 등급이 왜곡된다(예: 옛 슬롯1은 영웅이었는데 새 상한표는 슬롯1=태초다) - 그래서
		-- 옛 매핑을 리터럴로 남겨 그 시절 실제 등급 그대로 백필한다(migrate v11의 "옛 공식
		-- 리터럴 보존"과 같은 원칙). slotUnlocked도 이번에 처음 생기는 저장 필드라, 과거
		-- 유일한 판정 기준이었던 "rebirthCount >= slot"으로 지금까지의 해금 상태를 그대로
		-- 복원한다(정보 손실 없음 - 지금 조건표도 값이 같다).
		local OLD_SLOT_GRADE_ORDER = { "epic", "legendary", "relic", "ancient", "primordial" }
		for _, classState in pairs(data.classes) do
			local gems = classState.weapon.gems
			for slot = 1, 5 do
				local gem = gems[slot]
				if type(gem) == "table" and gem.grade == nil then
					gem.grade = OLD_SLOT_GRADE_ORDER[slot]
				end
			end
			classState.weapon.slotUnlocked = classState.weapon.slotUnlocked or {}
			for slot = 1, 5 do
				if classState.weapon.slotUnlocked[slot] == nil then
					classState.weapon.slotUnlocked[slot] = (classState.rebirthCount or 0) >= slot
				end
			end
		end
		data.version = 20
	end

	if data.version < 21 then
		-- 23-5: 무한 모드 보스 순환(PRD 20.50 [5]) + 장비창 위치 저장(23-4 후속 지시) 신설.
		-- v20까지 둘 다 개념 자체가 없었다 - "빈 순환"(첫 진입 시 첫 뽑기가 알아서 채운다,
		-- BossRules.nextRotationBossId가 order가 비었을 때 셔플하는 분기와 같다)과 "한 번도
		-- 안 옮김"이 정확한 과거 상태이므로 defaultClassState/defaultProfile과 같은 값으로
		-- 채운다 - 정보 손실이 없다(옛 세이브엔 애초에 없던 값).
		for _, classState in pairs(data.classes) do
			classState.bossRotation = classState.bossRotation
				or { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false }
		end
		data.inventoryWindowPosition = data.inventoryWindowPosition or false
		data.version = 21
	end

	if data.version < 22 then
		-- 25-1: 캐릭터 레벨 곡선을 "목표 마릿수 역산" 하나로 통일했다(CharacterLevel 주석). v21까지는
		-- 직업별로 두 곡선(rebirthCount 0 = 1~25 손튜닝표+26+ 지수식 / rebirthCount>=1 = 순수
		-- 지수식) 중 하나였다 - 같은 characterExp가 새 곡선에서 다른 레벨로 읽히면 안 되므로,
		-- 옛 곡선(LegacyCurveV21)으로 레벨과 레벨 내 진행률을 구한 뒤 새 곡선의 같은 레벨·같은
		-- 진행률 위치로 characterExp를 다시 놓는다. 레벨은 정확히 유지되고(오르내림 없음), 새
		-- 임계값은 0 이상 단조증가라 결과도 항상 0 이상이다. v11이 진행률을 버렸던 것과 달리
		-- 진행률까지 옮긴다 - 비용이 같고 잃을 이유가 없다.
		for _, classState in pairs(data.classes) do
			local exp = classState.characterExp or 0
			local useExponential = (classState.rebirthCount or 0) > 0
			local level = LegacyCurveV21.getLevelFromExp(exp, useExponential)
			local oldFrom = LegacyCurveV21.getExpForLevel(level, useExponential)
			local oldTo = LegacyCurveV21.getExpForLevel(level + 1, useExponential)
			local ratio = oldTo > oldFrom and math.clamp((exp - oldFrom) / (oldTo - oldFrom), 0, 1) or 0
			local newFrom = CharacterLevel.getExpForLevel(level)
			local newTo = CharacterLevel.getExpForLevel(level + 1)
			classState.characterExp = newFrom + ratio * (newTo - newFrom)
		end
		data.version = 22
	end

	if data.version < 23 then
		-- 26-1: 보석·장비 옵션 통합(PRD-forge-game-roblox.md 20.67 [13]). v22까지 보석은
		-- optionId(이름 문자열 또는 nil)만 가졌다 - 그 자리를 option({id, roll} 또는 nil)으로
		-- 바꾼다. 장비(가방·착용)는 이번에 처음 option 필드가 생긴다 - "그 시절 장비는 옵션
		-- 개념 자체가 없었다"가 정확한 과거 상태이므로 손대지 않는다(nil, v10 part 소급과
		-- 다르게 채울 값 자체가 없다 - 이번 세션부터 생성되는 장비만 Loot의 옵션 굴림을 거친다).
		for _, classState in pairs(data.classes) do
			local function migrateGem(gem)
				if type(gem) ~= "table" then
					return
				end
				local oldOptionId = gem.optionId
				gem.optionId = nil
				local newAxisId = oldOptionId and GemData.optionAxis[oldOptionId]
				if newAxisId then
					-- 옛 이름 있는 보석(연속격·속사의 흔적·심판의 표식·삼위일체) - 새 옵션 id로
					-- 치환하고 기댓값 롤(1.0)을 준다. 값 자체는 옛 값과 다르다 - 20.67 [5]의
					-- 재조정 자체가 이번 세션의 의도다.
					gem.option = { id = newAxisId, roll = 1.0 }
				elseif not GemData.optionPoolByGrade[gem.grade] then
					-- 영웅·전설·유물(옛 "무조건 공격력%", 옵션 풀 자체가 없어 optionId가 항상
					-- nil이던 등급) - attackPercent 기댓값으로 승격한다. 효과가 소리 없이
					-- 사라지지 않게 하기 위함(20.67 [13] 임의 결정 13).
					gem.option = { id = "attackPercent", roll = 1.0 }
				else
					-- 고대·태초의 옵션 미배정(nil) - nil 유지.
					gem.option = nil
				end
				-- itemLevel 백필 - 환생 지급 보석의 실제 지급 레벨(25×회차)을 넘지 않는 결정적
				-- 값(20.67 [13]). characterExp는 이 시점 이미 v22 블록을 거쳐 새 곡선 위다.
				gem.itemLevel = gem.itemLevel
					or math.max(25 * (classState.rebirthCount or 0), CharacterLevel.getLevelFromExp(classState.characterExp or 0), 1)
			end

			for slot = 1, 5 do
				migrateGem(classState.weapon.gems[slot])
			end
			for _, gem in ipairs(classState.gemInventory) do
				migrateGem(gem)
			end
		end
		data.version = 23
	end

	if data.version < 24 then
		-- 30-0 S02(PRD 20.72 [2-7]): 드랍 itemLevel이 "캐릭터 레벨 × tier 보너스"에서 "기준 스테이지 ± 2"로 바뀌었다(S01).
		-- 옛 규칙으로 얻은 장비(레벨 100이 tier6을 잡으면 420)를 새 규칙에서 가능한 최댓값 dropStage + 2로 자른다.
		-- **되돌릴 수 없다**(원래 값을 버린다). 대상은 가방 + 모든 직업의 착용 장비 3부위뿐이다 - 보석은 dropStage가 없고
		-- 옵션 계수 f(125에서 동결)에만 쓰여 부풀려진 값도 영향이 없다. 무기 · 강화 단계 · 옵션 · 등급 · dropStage · tierIndex는
		-- 그대로다. dropStage가 없는 항목은 건드리지 않고 개수만 남긴다. 절단이라 두 번 돌려도 결과가 같다(멱등).
		local total, cutCount, noStageCount = 0, 0, 0
		local maxBefore, maxAfter
		local function clampItem(item)
			if type(item) ~= "table" then
				return
			end
			total += 1
			if type(item.itemLevel) ~= "number" then
				return
			end
			if type(item.dropStage) ~= "number" then
				noStageCount += 1
				return
			end
			local clamped = math.min(item.itemLevel, item.dropStage + 2)
			if clamped ~= item.itemLevel then
				cutCount += 1
				if not maxBefore or item.itemLevel > maxBefore then
					maxBefore, maxAfter = item.itemLevel, clamped
				end
				item.itemLevel = clamped
			end
		end
		for _, item in ipairs(data.inventory) do
			clampItem(item)
		end
		for _, classState in pairs(data.classes) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				clampItem(classState.equipment[part])
			end
		end
		if cutCount > 0 then
			print(("[forge-game] v24 이관: 장비 %d개 중 %d개 itemLevel 절단(최대 %d → %d)"):format(total, cutCount, maxBefore, maxAfter))
		else
			print(("[forge-game] v24 이관: 장비 %d개 중 0개 itemLevel 절단"):format(total))
		end
		if noStageCount > 0 then
			print(("[forge-game] v24 이관: dropStage가 없는 장비 %d개는 건드리지 않았다"):format(noStageCount))
		end
		data.version = 24
	end

	if data.version < 25 then
		-- 30-0 S03(PRD 20.72 [1-7]): 강화 천장 게이지 신설. v24까지 이 개념 자체가 없었다 - 0(게이지 비어 있음)이 정확한 과거 상태다.
		-- 강화 단계(weapon.level)는 건드리지 않는다(이미 20강 이상인 무기는 그 단계에서 새 규칙을 다음 시도부터 적용받는다 - 소급 없음).
		for _, classState in pairs(data.classes) do
			classState.weapon.enhanceGauge = classState.weapon.enhanceGauge or 0
		end
		data.version = 25
	end

	if data.version < 26 then
		-- 30-0 S04(PRD 20.72 [1-5](나)): 강화 재료 신설. v25까지 이 개념 자체가 없었다 - 전부 0이 정확한 과거 상태다(소급 지급 없음).
		data.materials = data.materials or defaultMaterials()
		data.version = 26
	end

	if data.version < 27 then
		-- 30-0 S05(PRD 20.72 [1-7]): 방지권 신설. 0장 · 빈 집합이 정확한 과거 상태다 - protectionClaimedStages는 이미 깬 보스에서 역산하지 않는다(빈 집합에서 시작 -
		-- 이미 깬 보스도 한 번 더 깨면 받는다. 20.40 v16의 bossFirstClearStages와 같은 원칙).
		data.purchases.protectionTickets = data.purchases.protectionTickets or { drop = 0, reset = 0 }
		data.purchases.protectionClaimedStages = data.purchases.protectionClaimedStages or {}
		data.version = 27
	end

	if data.version < 28 then
		-- 30-0 S05 후속: 스테이지 · 단계 번호를 키로 쓰는 저장 집합의 키를 문자열로 통일한다. DataStore 왕복이 숫자 키를 문자열로 바꿔 돌려주므로(1 ~ n이 빈틈없이 이어진
		-- 집합은 배열로 저장돼 숫자 키로 돌아오기도 한다) 저장된 것은 숫자 · 문자열이 섞여 있다. 값은 그대로 옮기고 키만 tostring으로 맞춘다.
		for _, classState in pairs(data.classes) do
			classState.stageProgress.bossFirstClearStages = normalizeKeySet(classState.stageProgress.bossFirstClearStages)
		end
		data.tutorial.granted = normalizeKeySet(data.tutorial.granted)
		data.version = 28
	end

	if data.version < 29 then
		-- 30-0 S11(PRD 20.73 [4-1]): 보스 도감 도장 신설. 빈 집합이 정확한 과거 상태다 - 이미 깬 보스에서 역산하지 않는다(한 번 더 깨면 찍힌다. protectionClaimedStages와 같은 원칙).
		data.purchases.bossCodex = data.purchases.bossCodex or {}
		data.version = 29
	end

	if data.version < 30 then
		-- 30-0 S20e: 안내 플래그 표 신설. false가 정확한 과거 상태다 - 이미 변환 · 리롤을 해 본 계정도 보석상인은 처음이므로 안내가 한 번 보이고, 보석상인에서 한 번 성공하면 줄어든다.
		data.hints = data.hints or {}
		if data.hints.gemMerchantUsed == nil then
			data.hints.gemMerchantUsed = false
		end
		data.version = 30
	end

	if data.version < 31 then
		-- P2.5b C: 보석 가루 신설. 0이 정확한 과거 상태다(가루는 이 버전부터 생긴다 - 이미 가진 보석은 그대로 두고, 분해하면 그때 가루가 된다).
		data.gemDust = data.gemDust or 0
		data.version = 31
	end

	if data.version < 32 then
		-- P2.5b D: 환생 후 마일스톤 기록 신설. 빈 표 · 0에서 시작한다 - 지금 회차의 지금 레벨까지는 PlayerProfile.init이 접속 때 채운다(지난 회차의 최고 레벨은 저장된 적이 없어 소급하지 않는다).
		for _, classState in pairs(data.classes) do
			classState.milestones = classState.milestones or {}
		end
		data.milestoneUnlocks = data.milestoneUnlocks or 0
		data.version = 32
	end

	if data.version < 33 then
		-- P2.5c B2: 마일스톤 재설계 - 회차마다 반복되던 50레벨 곱연산 공격력(회차별 표 milestones)을 없애고, 환생 5회 뒤 레벨 200 · 250 … 사다리(받은 마지막 레벨 하나)로 바꿨다.
		-- 옛 표는 새 규칙과 뜻이 달라 옮기지 않고 0에서 시작한다 - 환생 5회를 마친 직업은 PlayerProfile.init이 접속 때 지금 레벨까지 채운다.
		-- 받은 해금 개수(milestoneUnlocks)와 이미 늘어난 가방 칸은 그대로 둔다(되돌리지 않는다 - 새 규칙의 해금 순서가 옛 순서와 같다).
		for _, classState in pairs(data.classes) do
			classState.milestones = nil
			classState.milestoneLevel = classState.milestoneLevel or 0
		end
		data.version = 33
	end

	if data.version < 34 then
		-- P3a(v34): 리더보드 기록 제외 표시 신설. 이관 규칙(개발 계정뿐이라 단순하게 - 로그 결정): 보스를 하나라도 깬 기존 세이브는 그 진도가
		-- /gg로 만든 것인지 가릴 수 없어 true(기록 제외), 아직 보스 클리어가 없는 세이브는 false. 진도 값(infiniteBest = 도달 · bestBossCleared = 보스 클리어)은 그대로 둔다 -
		-- 두 값은 원래 따로 있었고, 이번 단계부터 순위 · 기록은 bestBossCleared(보스 클리어)만 본다.
		local cleared = false
		for _, classState in pairs(data.classes) do
			cleared = cleared or ((classState.stageProgress and classState.stageProgress.bestBossCleared) or 0) > 0
		end
		data.leaderboardTainted = cleared
		data.version = 34
	end

	if data.version < 35 then
		-- P3c C4: 레벨 126부터 필요 경험치가 레벨별 배수(CharacterLevel.getExpScale - 획득도 같은 배수, 처치 수는 그대로). 누적 임계값은 126까지 옛 값과 같다.
		-- 옛 곡선(v34 - 필요 경험치 = round(K × E), 배수 없음)으로 레벨과 진행률을 읽고, v35 곡선(126+ 배수)에서 같은 레벨 · 같은 진행률의 값으로 옮긴다(126 아래 · 0은 그대로).
		-- QUEUE-B1 결정 14: 두 곡선 모두 **그 시절 리터럴**로 적는다(K = v45 단계의 OLD와 같은 표 · 배수 = 20,000 ÷ 150 × 0.99^(L − 126)). 옛 코드는 지금 CharacterLevel로
		-- 읽고 써서, 곡선이 바뀐 뒤(C3 v45)에는 v34 레벨 200 → 127처럼 레벨이 떨어졌다(결과를 v45 단계가 한 번 더 옮긴다 - 여기 결과는 v44 곡선 값이어야 한다).
		local OLD = { { 1, 5 }, { 25, 15 }, { 50, 60 }, { 75, 350 }, { 100, 2500 }, { 125, 20000 } }
		local function oldKills(level)
			if level <= OLD[1][1] then
				return OLD[1][2]
			end
			for i = 2, #OLD do
				local a, b = OLD[i - 1], OLD[i]
				if level <= b[1] then
					return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1])
				end
			end
			return 150
		end
		local function oldNeed(level) -- v34
			return math.floor(oldKills(level) * CharacterLevel.getMonsterExpAtLevel(level) + 0.5)
		end
		local function newNeed(level) -- v35 ~ v44
			local scale = level > 125 and math.max((20000 / 150) * 0.99 ^ (level - 126), 1) or 1
			return math.floor(oldKills(level) * CharacterLevel.getMonsterExpAtLevel(level) * scale + 0.5)
		end
		local base = 0 -- 126 도달 누적(두 곡선이 같다)
		for level = 1, 125 do
			base += oldNeed(level)
		end
		for _, classState in pairs(data.classes) do
			local exp = classState.characterExp
			if type(exp) == "number" and exp == exp and exp > base and exp < math.huge then
				local level, threshold, newThreshold = 126, base, base
				while level < 1000000 do
					local need = oldNeed(level)
					if exp < threshold + need then
						break
					end
					threshold += need
					newThreshold += newNeed(level)
					level += 1
				end
				local fraction = math.clamp((exp - threshold) / math.max(oldNeed(level), 1), 0, 1)
				classState.characterExp = newThreshold + fraction * newNeed(level)
			end
		end
		data.version = 35
	end

	if data.version < 36 then
		-- G1-2: 줍는 순간 자동 처리 필터 신설 - 기본 끔(옛 동작 = 전부 가방에 보관).
		data.autoProcess = { enabled = false, maxGrade = AUTO_GRADE } -- UI-1b 0절(VERIFY-5 상1): 새 계정도 이 단계를 타므로 defaultProfile과 같은 값(옛 "epic")
		data.version = 36
	end

	if data.version < 37 then
		-- BR1-2: 첫 만남 전멸기 카드 - 본 보스 집합(빈 표 = 아무것도 안 봤다. 기존 유저도 다음 보스전에서 한 번씩 본다).
		data.hints = data.hints or {}
		data.hints.bossIntroSeen = data.hints.bossIntroSeen or {}
		data.version = 37
	end

	if data.version < 38 then
		-- M1: 포탈 개방 기록(빈 표 - 캠프를 한 번 더 밟으면 열린다) · 역대 최고 레벨(지금 직업들 레벨 중 최대 - 환생 전 기록은 없어 복원 불가).
		data.world = data.world or { portals = {} }
		data.world.portals = data.world.portals or {}
		local peak = 1
		for _, classState in pairs(data.classes or {}) do
			peak = math.max(peak, CharacterLevel.getLevelFromExp(classState.characterExp or 0))
		end
		data.peakLevel = math.max(data.peakLevel or 1, peak)
		data.version = 38
	end

	if data.version < 39 then
		-- M1 봉인 입구: 칭호 집합(빈 표)
		data.titles = data.titles or {}
		data.version = 39
	end

	if data.version < 40 then
		-- M1-3 관문 등록: 빈 표(기존 유저도 관문을 한 번 찾아가야 원격 입장 - 사용자 규칙: 구역을 한 번은 가로지르게)
		data.world = data.world or { portals = {} }
		data.world.bossGates = data.world.bossGates or {}
		data.version = 40
	end

	if data.version < 41 then
		-- M1-3 둥지 3트랙 · 구역 알: 빈 기록(모든 둥지를 바로 주울 수 있다) · 빈 도감 · 빈 알 가방
		data.world = data.world or { portals = {}, bossGates = {} }
		data.world.nests = data.world.nests or {}
		data.world.nestDex = data.world.nestDex or {}
		data.eggs = data.eggs or {}
		data.version = 41
	end

	if data.version < 42 then
		-- C1 마무리: 잠긴 몹 말풍선 1회 기록(기존 유저도 처음 한 번 본다)
		data.hints = data.hints or {}
		data.hints.stealLockSeen = data.hints.stealLockSeen == true
		data.version = 42
	end

	if data.version < 43 then
		-- D1: 장비에 태초 각인(primordial - 세계 번호 · 최초 획득자 · 날짜 · 출처) · 출처 태그(source)가 생겼다. 옛 태초 = 번호 없는 "이전 태초"(세계 번호는 1번부터 새로)
		--   + 기본 잠금(D1 ⑦). 옛 장비의 source는 없음(모름). 칭호는 v39 titles 그대로(새 칭호 "태초의 선택"은 다음 태초부터).
		local function stampLegacy(item)
			if type(item) == "table" and item.grade == "primordial" and item.primordial == nil then
				item.primordial = { legacy = true }
				item.locked = true
			end
		end
		for _, item in ipairs(data.inventory or {}) do
			stampLegacy(item)
		end
		for _, classState in pairs(data.classes or {}) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				stampLegacy(classState.equipment and classState.equipment[part])
			end
		end
		data.version = 43
	end

	if data.version < 44 then
		-- S1: 획득 감사. λ = 0부터(옛 드랍 확률은 기록이 없다 - 옛 태초는 원장이 없어 격리 대상이라 확률 검사에 안 들어간다).
		--   플레이 시간 = 옛 계정 최고 스테이지에 합법으로 닿는 최소 시간(속도 봉투 역함수 - 옛 진도를 보류하지 않게).
		local best = 1
		for _, cs in pairs(data.classes or {}) do
			local sp = type(cs) == "table" and cs.stageProgress
			if type(sp) == "table" and type(sp.infiniteBest) == "number" then
				best = math.max(best, sp.infiniteBest)
			end
		end
		local AuditMath = require(game:GetService("ReplicatedStorage").Shared.AuditMath)
		data.audit = { lambda = 0, primordialRolls = 0, playSeconds = math.floor(AuditMath.hoursForStage(best) * 3600) }
		-- 리뷰 1: D1 ~ S1 사이 정상 발급 태초(번호 있음 · 원장 id 없음) = preLedger(격리 안 함 · 집계 대상 - 원장 제도 전 발급)
		local function markPre(item)
			local stamp = type(item) == "table" and item.grade == "primordial" and item.primordial
			if type(stamp) == "table" and not stamp.legacy and not stamp.rollId then
				stamp.preLedger = true
			end
		end
		for _, item in ipairs(data.inventory or {}) do
			markPre(item)
		end
		for _, cs in pairs(data.classes or {}) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				markPre(cs.equipment and cs.equipment[part])
			end
		end
		data.version = 44
	end

	if data.version < 45 then
		-- C3 0-3: 캐릭터 경험치 곡선 변경(목표 마릿수 앵커 50 · 75 · 100 · 125 = 60 · 350 · 2,500 · 20,000 → 240 · 1,400 · 10,000 · 170,000 · 126+ 배수 20,000 ÷ 150 → 170,000 ÷ 150).
		-- 옛 곡선(v44 - 리터럴로 보존)으로 레벨과 진행률을 읽고 새 곡선에서 같은 레벨 · 같은 진행률로 옮긴다(v35와 같은 방식 - 레벨이 내려가지 않게).
		local OLD = { { 1, 5 }, { 25, 15 }, { 50, 60 }, { 75, 350 }, { 100, 2500 }, { 125, 20000 } }
		local function oldKills(level)
			if level <= OLD[1][1] then
				return OLD[1][2]
			end
			for i = 2, #OLD do
				local a, b = OLD[i - 1], OLD[i]
				if level <= b[1] then
					return a[2] + (b[2] - a[2]) * (level - a[1]) / (b[1] - a[1])
				end
			end
			return 150
		end
		local function oldNeed(level)
			local scale = level > 125 and math.max((20000 / 150) * 0.99 ^ (level - 126), 1) or 1
			return math.floor(oldKills(level) * CharacterLevel.getMonsterExpAtLevel(level) * scale + 0.5)
		end
		for _, classState in pairs(data.classes or {}) do
			local exp = type(classState) == "table" and classState.characterExp
			if type(exp) == "number" and exp == exp and exp > 0 and exp < math.huge then
				local level, threshold = 1, 0
				while level < 1000000 do
					local need = oldNeed(level)
					if exp < threshold + need then
						break
					end
					threshold += need
					level += 1
				end
				local fraction = math.clamp((exp - threshold) / math.max(oldNeed(level), 1), 0, 1)
				classState.characterExp = CharacterLevel.getExpForLevel(level) + fraction * CharacterLevel.getExpToNextLevel(level)
			end
		end
		data.version = 45
	end

	if data.version < 46 then
		-- C5-2 되찾기 기준 레벨: 옛 세이브는 환생 순간 레벨 기록이 없다 → 그 회차의 필요 레벨(25 × 환생 횟수 - CharacterLevel.getRebirthRequiredLevel(횟수 − 1))로 본다(보수적 - 실제는 그 이상).
		local CharacterLevelForReclaim = require(game:GetService("ReplicatedStorage").Shared.CharacterLevel)
		for _, classState in pairs(data.classes or {}) do
			if type(classState) == "table" and type(classState.reclaimLevel) ~= "number" then
				local count = type(classState.rebirthCount) == "number" and classState.rebirthCount or 0
				classState.reclaimLevel = count > 0 and (CharacterLevelForReclaim.getRebirthRequiredLevel(count - 1) or 0) or 0
			end
		end
		data.version = 46
	end

	if data.version < 47 then
		-- C5-7 초월: 장비 special(부위 고정 특수 옵션) · 각인 grade - 옛 세이브에 초월은 없다(태초 각인에 grade를 채운다).
		local function stampGrade(item)
			if type(item) == "table" and type(item.primordial) == "table" and item.primordial.grade == nil then
				item.primordial.grade = item.grade
			end
		end
		for _, item in ipairs(data.inventory or {}) do
			stampGrade(item)
		end
		for _, cs in pairs(data.classes or {}) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				stampGrade(cs.equipment and cs.equipment[part])
			end
		end
		data.version = 47
	end

	if data.version < 48 then
		data.comeback = type(data.comeback) == "table" and data.comeback or { untilAt = 0 } -- C5-5 복귀 부스트
		data.version = 48
	end

	if data.version < 49 then
		-- QUEUE-10h Q5 BR2: 장비 세트 계열 item.setZone(구역 키) - 옛 장비는 출처 태그(source - v43)로 채운다(보스 = 관문 구역 · 잡몹 · 반짝이 = 사냥 구역 · 그 밖 = 세트 아님).
		--   값을 지우거나 바꾸지 않는다(없는 필드만 채움) - 태그가 없는 옛 장비(v43 전 드랍)는 세트 아님으로 남는다.
		local SetBonus = require(ReplicatedStorage.Shared.SetBonus)
		local function stampSet(item)
			if type(item) == "table" and item.setZone == nil then
				item.setZone = SetBonus.zoneFromSource(item.source)
			end
		end
		for _, item in ipairs(data.inventory or {}) do
			stampSet(item)
		end
		for _, cs in pairs(data.classes or {}) do
			for _, part in ipairs({ "armor", "gloves", "shoes" }) do
				stampSet(cs.equipment and cs.equipment[part])
			end
		end
		data.version = 49
	end

	if data.version < 50 then
		-- QUEUE-10h Q6 G3: 공용 수련(training) · 직업 고유 능력(classes[].abilities) · 퀘스트(quests) - 없는 필드만 채운다(옛 값 보존).
		data.training = type(data.training) == "table" and data.training or { attack = 0, hp = 0, defense = 0 }
		for _, cs in pairs(data.classes or {}) do
			if type(cs) == "table" then
				cs.abilities = type(cs.abilities) == "table" and cs.abilities or {}
			end
		end
		if type(data.quests) ~= "table" then
			data.quests = require(ReplicatedStorage.Shared.Quest).newState(os.time())
		end
		data.version = 50
	end

	if data.version < 51 then
		-- QUEUE-10h Q9 K4: 장비 item.skillVariant(스킬 변형 { classId, slot, id }) - 옛 장비는 없음(nil = 변형 없음 · 채울 값 없음). 버전만 올린다(규칙 - 저장 구조 변경 표시).
		data.version = 51
	end

	if data.version < 52 then
		-- QUEUE-10h Q11: 펫(pets) - 없으면 빈 상태(옛 알 가방 eggs는 그대로 = 부화 재료).
		if type(data.pets) ~= "table" then
			data.pets = require(ReplicatedStorage.Shared.Pet).newState()
		end
		data.version = 52
	end

	if data.version < 53 then
		-- QUEUE-10h Q12: quests.guide(첫 5분 이정표) · quests.attendance(7일 출석)는 새 계정만 - 옛 계정(이미 이관된 상태 · 위 v50 단계가 방금 만든 상태 포함)은 둘 다 없음.
		if type(data.quests) == "table" and not isNewAccount then -- 새 계정은 위 v50 단계의 Quest.newState(이정표 1 · 출석 0)를 그대로 둔다
			data.quests.guide = nil
			data.quests.attendance = nil
		end
		data.version = 53
	end

	if data.version < 54 then
		-- QUEUE-10h Q14: settings(설정 저장) - 옛 계정 = 빈 표(전부 기본값 = 지금까지의 "이번 접속 동안" 기본과 같다).
		if type(data.settings) ~= "table" then
			data.settings = {}
		end
		data.version = 54
	end

	if data.version < 55 then
		-- QUEUE-6h-b 후속: sessionId(약한 세션 잠금) - 옛 계정 = ""(놓음 - 기다리지 않는다).
		if type(data.sessionId) ~= "string" then
			data.sessionId = ""
		end
		data.version = 55
	end

	if data.version < 56 then
		-- QUEUE-B1 B2 수익화 골격: 치장 · 선물함 · 시즌 패스 · 영수증 · 구매 기록 - 옛 계정 = 빈 표(산 것 없음). gamepasses(옛 예약 칸)는 표로만 맞춘다.
		if type(data.cosmetics) ~= "table" then
			data.cosmetics = { themes = {}, gliderSkins = {}, equipped = {}, treeStations = {} }
		end
		if type(data.mailbox) ~= "table" then
			data.mailbox = { gifts = {}, seq = 0 }
		end
		if type(data.seasonPass) ~= "table" then
			data.seasonPass = { season = 0, premium = false, claimedFree = {}, claimedPaid = {} }
		end
		if type(data.gamepasses) ~= "table" then
			data.gamepasses = {}
		end
		data.purchases = type(data.purchases) == "table" and data.purchases or {}
		if type(data.purchases.receipts) ~= "table" then
			data.purchases.receipts = {}
		end
		if type(data.purchases.log) ~= "table" then
			data.purchases.log = {}
		end
		data.version = 56
	end

	if data.version < 57 then
		-- QUEUE-ALL1 P3 §4: communityGoal(주간 합동 목표) - 옛 계정 = 기여 0 · 받은 칸 없음(이번 주부터 센다)
		if type(data.communityGoal) ~= "table" then
			data.communityGoal = { week = 0, contributed = 0, claimed = {} }
		end
		data.version = 57
	end

	if data.version < 58 then
		-- QUEUE-ALL1 P4: redeemedCodes · weeklyChallenge - 옛 계정 = 받은 코드 없음 · 주간 기록 없음
		if type(data.redeemedCodes) ~= "table" then
			data.redeemedCodes = {}
		end
		if type(data.weeklyChallenge) ~= "table" then
			data.weeklyChallenge = { week = 0, rewarded = false, rankClaimedWeek = 0 }
		end
		data.version = 58
	end

	if data.version < 59 then
		-- QUEUE-ALL1 P5: codex(도감 v2) - 옛 계정 소급 = 지금 남은 기록으로 채울 수 있는 것만(docs/phase/QUEUE-ALL1-state.md P5 규칙):
		--   장비 = 가방 + 모든 직업 착용 중 드랍 출처(source) · 세트(setZone)가 있는 것 1개 = 1회 · 펫 = 지금 가진 펫(종 · 부화 등급) · 보스 = 도장(bossCodex) 찍힌 보스 1회
		--   직업 = 지금 무기 등급 · 둥지 = nestDex 그대로(따로 안 옮김) · 몬스터 처치 수 = 기록이 없어 0부터. 완료 스테이지 = 첫 확인 때의 계정 최고.
		if type(data.codex) ~= "table" then
			local c = SaveSystem.newCodex()
			local function addItem(item)
				if type(item) == "table" and type(item.source) == "table" and item.source.kind ~= "dev" and type(item.setZone) == "string" and item.part then
					if item.grade == "transcendent" then
						c.trans[item.setZone] = true
					elseif item.grade == "primordial" then
						c.prim[item.setZone] = true
					else
						local key = ("%s|%s|%s"):format(item.setZone, tostring(item.grade), item.part)
						c.armor[key] = (c.armor[key] or 0) + 1
					end
				end
			end
			for _, item in ipairs(type(data.inventory) == "table" and data.inventory or {}) do
				addItem(item)
			end
			for classId, cs in pairs(type(data.classes) == "table" and data.classes or {}) do
				for _, item in pairs(type(cs) == "table" and type(cs.equipment) == "table" and cs.equipment or {}) do
					addItem(item)
				end
				if type(cs) == "table" and type(cs.weapon) == "table" and type(cs.weapon.grade) == "number" then
					c.cls[classId] = cs.weapon.grade
				end
			end
			for _, pet in ipairs(type(data.pets) == "table" and type(data.pets.list) == "table" and data.pets.list or {}) do
				if type(pet) == "table" and pet.species and pet.grade then
					c.pet[pet.species .. "|" .. pet.grade] = true
				end
			end
			for bossId, stamped in pairs(type(data.purchases) == "table" and type(data.purchases.bossCodex) == "table" and data.purchases.bossCodex or {}) do
				if stamped == true then
					c.boss[bossId] = 1
				end
			end
			data.codex = c
		end
		data.version = 59
	end

	if data.version < 60 then
		-- QUEUE-ALL3 Q3: 초반 여정(메인 사슬 10 → 32단계) - quests.main = 옛 번호 → 같은 id의 새 번호(Quest.migrateMainIndex · 옛 단계가 없어졌으면 그다음 옛 단계) · mainN = 0(지금 단계 이벤트 수)
		if type(data.quests) == "table" then
			local oldMain = tonumber(data.quests.main) or 1
			data.quests.main = require(ReplicatedStorage.Shared.Quest).migrateMainIndex(oldMain)
			data.quests.mainN = 0
		end
		data.version = 60
	end

	if data.version < 61 then
		-- QUEUE-ALL3 Q5: checkpoints(체크포인트 발견 기록 - 옛 계정 = 아무것도 안 찾음 · 허브는 가까이 가면 곧 찾는다)
		if type(data.checkpoints) ~= "table" then
			data.checkpoints = { found = {} }
		end
		data.version = 61
	end

	if data.version < 62 then
		-- QUEUE-ALL5 A1: mailbox.claimedIds(받은 선물 id - 재지급 방지) - 옛 계정 = 빈 목록(이미 받은 선물은 선물함에서 지워져 대기열에도 없다 · 대기열에 남은 건 아직 안 받은 것)
		if type(data.mailbox) == "table" and type(data.mailbox.claimedIds) ~= "table" then
			data.mailbox.claimedIds = {}
		end
		data.version = 62
	end

	if data.version < 63 then
		-- QUEUE-ALL5 A3: quarantine(보관 칸) - 옛 계정 = 빈 목록(모르는 id 검사는 로드 때마다 SaveSystem.quarantineUnknownIds가 한다)
		if type(data.quarantine) ~= "table" then
			data.quarantine = {}
		end
		data.version = 63
	end

	if data.version < 64 then
		-- QUEUE-ALL6 H: cosmetics.items(꾸미기 소품 - 칸 하나짜리 · { [id] = true }) - 옛 계정 = 빈 표
		if type(data.cosmetics) == "table" and type(data.cosmetics.items) ~= "table" then
			data.cosmetics.items = {}
		end
		data.version = 64
	end

	if data.version < 65 then
		-- QUEUE-ALL9B 2-4: 공용 수련 최대 100 → 50단계(TrainingData.stats maxLevel). 기존 단계는 유지 · 새 최대 안으로(51 이상 = 50). 직업 능력(classes[].abilities)은 그대로.
		if type(data.training) == "table" then
			for _, id in ipairs({ "attack", "hp", "defense" }) do
				local v = tonumber(data.training[id])
				if v and v > 50 then
					data.training[id] = 50
				end
			end
		end
		data.version = 65
	end

	if data.version < 66 then
		-- QUEUE-ALL9B 4-8 · 6-1: seasonPass.skipBought(이번 시즌 구매로 오른 칸 수) · skipTiers(건너뛰기로 얻은 칸 - 무료 줄 알 · 성장 재화 = 토큰) - 옛 계정 = 0 · 빈 표
		if type(data.seasonPass) == "table" then
			data.seasonPass.skipBought = tonumber(data.seasonPass.skipBought) or 0
			data.seasonPass.skipTiers = type(data.seasonPass.skipTiers) == "table" and data.seasonPass.skipTiers or {}
		end
		data.version = 66
	end

	if data.version < 67 then
		-- QUEUE-ALL9B 5: quests.board(시즌 출석판 - season · count · lastDay · claimed · bonusDay) - 옛 계정 = 빈 판(다음 roll이 이번 시즌으로 바꾸고 오늘을 1칸으로 센다)
		if type(data.quests) == "table" and type(data.quests.board) ~= "table" then
			data.quests.board = require(ReplicatedStorage.Shared.Quest).newBoard(0)
		end
		data.version = 67
	end

	if data.version < 68 then
		-- QUEUE-ALL9B G(사용자 10-03): 방지권(소모품) 폐지 → 보유 장수 × 폐지 시점 상점가(계정 최고 스테이지 기준 - Enhance.getProtectionPrice)를 골드로 환산 지급(손해 0).
		--   키는 지우지 않고 0장으로 둔다(id 비활성). 환산 기록 = purchases.protectionRefund { drop, reset, gold }(한 번만 - 이관 멱등).
		local p = data.purchases
		if type(p) == "table" and type(p.protectionTickets) == "table" and p.protectionRefund == nil then
			local best = 1
			for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
				local progress = type(classState) == "table" and classState.stageProgress
				best = math.max(best, type(progress) == "table" and tonumber(progress.infiniteBest) or 1)
			end
			best = math.min(best, require(ReplicatedStorage.Shared.data.InfiniteStageConfig).hardMaxStage) -- 리뷰: 손상된 큰 스테이지가 환산을 부풀리거나 inf × 0 = NaN이 되지 않게
			local Enhance = require(ReplicatedStorage.Shared.Enhance)
			local refund = { drop = 0, reset = 0, gold = 0, stage = best }
			for _, kind in ipairs({ "drop", "reset" }) do
				local count = math.max(0, math.floor(tonumber(p.protectionTickets[kind]) or 0))
				if count ~= count or count == math.huge then
					count = 0
				end
				refund[kind] = count
				if count > 0 then
					refund.gold += count * Enhance.getProtectionPrice(kind, best)
				end
				p.protectionTickets[kind] = 0
			end
			data.gold = (tonumber(data.gold) or 0) + refund.gold
			p.protectionRefund = refund
		end
		data.version = 68
	end
	if data.version < 69 then
		-- QUEUE-ALL9C 1-6: 가방 칸 출처 · 상점 연 횟수(빈 값 - 옛 계정은 스타터를 산 적이 없다)
		if type(data.purchases) == "table" then
			data.purchases.bagSources = type(data.purchases.bagSources) == "table" and data.purchases.bagSources or {}
			data.purchases.shopViews = tonumber(data.purchases.shopViews) or 0
		end
		data.version = 69
	end
	if data.version < 70 then
		-- QUEUE-ALL10 1-1: 초월 계승 자리(옛 계정 = 계승 없음 · 고급 수련 50 · 방어 수련 0 · 초월 보석 0개). 값 정리는 아래 sanitizeAll10(매 로드).
		if type(data.training) == "table" then
			data.training.advanced = data.training.advanced or 50
			data.training.guard = data.training.guard or 0
		end
		data.transcendGems = type(data.transcendGems) == "table" and data.transcendGems or { list = {}, seq = 0 }
		data.version = 70
	end
	if data.version < 71 then
		-- QUEUE-ALL9E1 0-4: 초월 강화 +6 ~ 확률 단계의 불씨(weapon.transcend.fails - 이번 단계 실패 횟수 · 천장 판정). 옛 초월 무기 = 0. 값 정리는 sanitizeAll10.
		for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
			local t = type(classState) == "table" and type(classState.weapon) == "table" and classState.weapon.transcend
			if type(t) == "table" then
				t.fails = t.fails or 0
			end
		end
		data.version = 71
	end
	if data.version < 72 then
		-- QUEUE-ALL9E1-ADD B: 무기 초월 홈(weapon.transcendSlots = { [slot] = true } · 계승 때 생김). 옛 계승 무기 = 태초 상한 홈 중 열린 홈 → 초월 홈(B1과 같은 규칙) · 그 밖 = 없음.
		for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
			local w = type(classState) == "table" and classState.weapon
			if type(w) == "table" and w.grade == 7 and type(w.transcend) == "table" and w.transcendSlots == nil and type(w.slotUnlocked) == "table" then
				local set = {}
				for slot, cap in ipairs(GemData.slotGradeCap) do
					if cap == "primordial" and w.slotUnlocked[slot] == true then
						set[slot] = true
					end
				end
				w.transcendSlots = set
			end
		end
		data.version = 72
	end
	if data.version < 73 then
		-- QUEUE-ALL9E1 LOOK2: 직업별 showOwnClothes(기본 끔 - 옛 직업 = false). 값 정리는 sanitizeAll10.
		for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
			if type(classState) == "table" and classState.showOwnClothes == nil then
				classState.showOwnClothes = false
			end
		end
		data.version = 73
	end
	if data.version < 74 then
		-- QUEUE-MENU2 B: 직업(캐릭터) 칸 playSeconds · runtime(쿨 종료 시각 · 궁 게이지 · 마지막 위치) - 옛 값 없음 = 0 · 빈 표
		for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
			if type(classState) == "table" then
				classState.playSeconds = tonumber(classState.playSeconds) or 0
				if type(classState.runtime) ~= "table" then
					classState.runtime = { cooldownEnds = {}, ultGauge = 0 }
				end
			end
		end
		data.version = 74
	end
	if data.version < 75 then
		-- GUARDIAN-V3 6: 첫 보스 도움 기록(hints.bossAssist) - 옛 세이브 = 빈 표(전멸 0 · 처치 기록 없음 - 추가만)
		data.hints = type(data.hints) == "table" and data.hints or {}
		if type(data.hints.bossAssist) ~= "table" then
			data.hints.bossAssist = {}
		end
		data.version = 75
	end
	if data.version < 76 then
		-- FINAL-1b 결정 6: 도감 직업 초월 칸 기록(codex.clsT[직업] = true) - 옛 세이브 = 지금 초월(계승)한 무기가 있는 직업만 채움(추가만)
		if type(data.codex) == "table" then
			data.codex.clsT = type(data.codex.clsT) == "table" and data.codex.clsT or {}
			for classId, cs in pairs(type(data.classes) == "table" and data.classes or {}) do
				if type(cs) == "table" and type(cs.weapon) == "table" and cs.weapon.grade == 7 and type(cs.weapon.transcend) == "table" then
					data.codex.clsT[classId] = true
				end
			end
		end
		data.version = 76
	end
	if data.version < 77 then
		-- SEC-FIX-1 8(사용자 결정 10-11 "칸 건너뛰기 = 못 한 출석 따라잡기"): seasonPass.skipDay = 마지막으로 칸 건너뛰기를 산 UTC 날짜(하루 1번) - 옛 세이브 = -1(추가만)
		if type(data.seasonPass) == "table" then
			data.seasonPass.skipDay = tonumber(data.seasonPass.skipDay) or -1
		end
		data.version = 77
	end
	if data.version < 78 then
		-- PROG-2B-1 2(GOLD-CURVE-1 G8 - 사용자 확정): 골드 곡선 C(1,000 뒤 √ 완만) - 보유 골드 × M_새(계정 최고) ÷ M_옛(계정 최고)(가치 보존 = 같은 "사냥 몇 분").
		--   기록 goldCurveRescale = { from, to, stage }(추가만 · 한 번만 - 있으면 건너뜀). 계정 최고 1,000 이하 = 배율 1(숫자 그대로). 새 계정 = 건너뜀(골드 0 · 기록 없음).
		if not isNewAccount and type(data.gold) == "number" and data.gold == data.gold and data.goldCurveRescale == nil then
			local best = 1
			for _, classState in pairs(type(data.classes) == "table" and data.classes or {}) do
				local progress = type(classState) == "table" and classState.stageProgress
				best = math.max(best, type(progress) == "table" and tonumber(progress.infiniteBest) or 1)
			end
			local IsConfig = require(ReplicatedStorage.Shared.data.InfiniteStageConfig)
			best = math.clamp(math.floor(best), 1, IsConfig.hardMaxStage) -- 손상된 큰 스테이지가 환산을 부풀리지 않게(v68과 같은 규칙)
			local ratio = require(ReplicatedStorage.Shared.InfiniteStage).getGoldMultiplier(best) / IsConfig.goldGrowthRate ^ (best - 1)
			local to = math.floor(math.max(0, data.gold) * ratio)
			data.goldCurveRescale = { from = data.gold, to = to, stage = best }
			data.gold = to
		end
		data.version = 78
	end

	data.savedAt = data.savedAt or 0
	SaveSystem.clampStageCap(data) -- S1 리뷰 7: 불러온 옛 값도 상한으로
	SaveSystem.clampGold(data) -- PROG-2B-1 2: 불러온 골드도 2^53 상한
	SaveSystem.sanitizeAll10(data) -- QUEUE-ALL10 1-1: 초월 계승 숫자(빈 값 · 큰 수 · NaN) 매 로드 정리
	return data
end

-- option 필드 형태 검사(26-1, PRD 20.67 [13] "isValidProfile에 option 형태 검사 추가") -
-- nil(미배정)이거나, {id=OptionData에 있는 문자열, ...} 테이블이어야 한다. item(장비)·gem(보석)
-- 둘 다 이 형태를 공유한다(20.67 [1] "장비 옵션 1개 ≙ 보석 1개").
local function isValidOption(option)
	return option == nil or (type(option) == "table" and type(option.id) == "string" and OptionData.options[option.id] ~= nil)
end

-- 저장 데이터가 게임에 바로 쓸 수 있는 최소 형태인지 검증(웹 isValidSaveData와 같은 목적).
-- 19-1: classes[classId]마다 weapon.level 존재를 확인한다 - part 필드 소급을 빠뜨려
-- 기존 장비를 영영 착용 못 하게 됐던 사고(16-6)와 같은 종류의 실수를 막는 지점이다.
local function isValidProfile(data)
	if type(data) ~= "table"
		or type(data.version) ~= "number"
		or type(data.gold) ~= "number"
		or (data.classId ~= nil and type(data.classId) ~= "string")
		or type(data.classes) ~= "table"
		or type(data.inventorySlots) ~= "number"
		or type(data.inventory) ~= "table"
		or type(data.gamepasses) ~= "table"
		or type(data.bulkSellCutoffGrade) ~= "string"
		or type(data.tutorial) ~= "table"
		or type(data.tutorial.completed) ~= "boolean"
		or type(data.tutorial.step) ~= "number"
		or type(data.tutorial.granted) ~= "table"
		or type(data.purchases) ~= "table"
		or type(data.purchases.optionRerollTickets) ~= "table"
		or type(data.purchases.optionRerollTickets.ancient) ~= "number"
		or type(data.purchases.optionRerollTickets.primordial) ~= "number"
		or (data.inventoryWindowPosition ~= false and type(data.inventoryWindowPosition) ~= "table")
		or type(data.materials) ~= "table"
		or type(data.purchases.protectionTickets) ~= "table"
		or type(data.purchases.protectionClaimedStages) ~= "table"
		or type(data.purchases.bossCodex) ~= "table"
		or type(data.hints) ~= "table"
		or (data.hints.gemMerchantUsed ~= nil and type(data.hints.gemMerchantUsed) ~= "boolean")
		or (data.hints.bossIntroSeen ~= nil and type(data.hints.bossIntroSeen) ~= "table") -- v37
		or (data.hints.bossAssist ~= nil and type(data.hints.bossAssist) ~= "table") -- v75
		or (data.hints.stealLockSeen ~= nil and type(data.hints.stealLockSeen) ~= "boolean") -- v42
		or type(data.world) ~= "table" or type(data.world.portals) ~= "table" -- v38
		or type(data.peakLevel) ~= "number" or data.peakLevel < 1 -- v38
		or type(data.titles) ~= "table" -- v39
		or type(data.world.bossGates) ~= "table" -- v40
		or type(data.world.nests) ~= "table" or type(data.world.nestDex) ~= "table" or type(data.eggs) ~= "table" -- v41
		or type(data.gemDust) ~= "number" or data.gemDust % 1 ~= 0 or data.gemDust < 0
		or type(data.milestoneUnlocks) ~= "number" or data.milestoneUnlocks % 1 ~= 0 or data.milestoneUnlocks < 0
		or type(data.leaderboardTainted) ~= "boolean" -- 리더보드 기록 제외(v34)
		or type(data.autoProcess) ~= "table" or type(data.autoProcess.enabled) ~= "boolean" -- 자동 처리(v36)
		or not table.find(ArmorData.autoProcessGradeChoices, data.autoProcess.maxGrade)
	then
		return false
	end

	-- 도감 도장(30-0 S11): 키는 BossData에 있는 보스 id, 값은 true뿐.
	for bossId, stamped in pairs(data.purchases.bossCodex) do
		if type(bossId) ~= "string" or BossData.bosses[bossId] == nil or stamped ~= true then
			return false
		end
	end

	-- 방지권 보유 장수(28-1 S05): 하락 · 초기화 둘 다 0 이상의 정수(음수 · 소수는 거절).
	for _, kind in ipairs({ "drop", "reset" }) do
		local count = data.purchases.protectionTickets[kind]
		if type(count) ~= "number" or count % 1 ~= 0 or count < 0 then
			return false
		end
	end

	-- 재료 보유량(28-1 S04): 재료 id마다 0 이상의 정수(음수 · 소수는 거절).
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		local amount = data.materials[materialId]
		if type(amount) ~= "number" or amount % 1 ~= 0 or amount < 0 then
			return false
		end
	end

	for _, item in ipairs(data.inventory) do
		if not isValidOption(item.option)
			or (item.primordial ~= nil and type(item.primordial) ~= "table") -- v43 태초 각인
			or (item.source ~= nil and type(item.source) ~= "table") -- v43 출처 태그
		then
			return false
		end
	end

	for _, classId in ipairs(ClassData.order) do
		local classState = data.classes[classId]
		if type(classState) ~= "table"
			or type(classState.characterExp) ~= "number"
			or type(classState.weapon) ~= "table"
			or type(classState.weapon.level) ~= "number"
			or type(classState.weapon.grade) ~= "number"
			or type(classState.weapon.enhanceGauge) ~= "number"
			or classState.weapon.enhanceGauge % 1 ~= 0
			or classState.weapon.enhanceGauge < 0
			or classState.weapon.enhanceGauge > EnhanceConfig.gauge.max
			or type(classState.weapon.gems) ~= "table"
			or type(classState.weapon.slotUnlocked) ~= "table"
			or type(classState.equipment) ~= "table"
			or type(classState.stageProgress) ~= "table"
			or type(classState.rebirthCount) ~= "number"
			or type(classState.gemInventory) ~= "table"
			or type(classState.bossRotation) ~= "table"
			or type(classState.milestoneLevel) ~= "number" or classState.milestoneLevel % 1 ~= 0 or classState.milestoneLevel < 0 -- 마일스톤 기록(v33): 0 이상 정수
			or type(classState.reclaimLevel) ~= "number" or classState.reclaimLevel < 0 -- C5-2 되찾기 기준(v46): 0 이상
		then
			return false
		end

		for _, part in ipairs({ "armor", "gloves", "shoes" }) do
			local item = classState.equipment[part]
			if item and not isValidOption(item.option) then
				return false
			end
		end
		for slot = 1, 5 do
			local gem = classState.weapon.gems[slot]
			if type(gem) == "table" and not isValidOption(gem.option) then
				return false
			end
		end
		for _, gem in ipairs(classState.gemInventory) do
			if not isValidOption(gem.option) then
				return false
			end
		end
	end

	return true
end

SaveSystem.defaultProfile = defaultProfile
SaveSystem.migrate = migrate
SaveSystem.isValidProfile = isValidProfile

-- S21-0 A3: 저장 직전 NaN·inf 오염 차단. 실측(S21-0(나), Studio DataStore) - UpdateAsync에
-- NaN·inf가 든 테이블을 넘겨도 에러 없이 "성공"하고 다시 읽으면 그 값 그대로 돌아온다(저장
-- 실패도 값 변형도 아니다 - 그대로 저장된다). 즉 막지 않으면 NaN·inf가 DataStore에 영구히
-- 남는다(실제 배포 서버의 클라우드 DataStore 동작까지는 이번 감사에서 확인 못함 - Studio
-- 안에서만 테스트할 수 있었다). UpdateAsync 콜백의 old(그 키의 지금 DataStore 저장값)가
-- 있으면 그 자리의 마지막 정상값으로 되돌리고, old에도 없으면(신규 필드 등) 0으로 둔다.
-- 경고는 필드 경로당 1회.
local warnedSaveFields = {}
local function warnSaveField(path, value)
	if warnedSaveFields[path] then
		return
	end
	warnedSaveFields[path] = true
	warn(("[SaveSystem] 저장 직전 비정상 값(%s) 발견 - %s 필드를 이전 값으로 되돌림"):format(tostring(value), path))
end

local function isBadNumber(value)
	return value ~= value or math.abs(value) == math.huge
end

local function sanitizeForSave(node, oldNode, path)
	for key, value in pairs(node) do
		local fieldPath = path .. "." .. tostring(key)
		if type(value) == "number" and isBadNumber(value) then
			local fallback = 0
			if type(oldNode) == "table" and type(oldNode[key]) == "number" and not isBadNumber(oldNode[key]) then
				fallback = oldNode[key]
			end
			warnSaveField(fieldPath, value)
			node[key] = fallback
		elseif type(value) == "table" then
			sanitizeForSave(value, type(oldNode) == "table" and oldNode[key] or nil, fieldPath)
		end
	end
end
SaveSystem.sanitizeForSave = sanitizeForSave -- 검증(S21-0 (나))이 직접 부른다.
-- 25-1: DevTools "/gg curve migrate" 자체검증 전용(옛 곡선 값을 합성해 migrate에 넣는다).
SaveSystem.legacyCurveV21 = LegacyCurveV21

-- QUEUE-ALL4 C 손상 저장 고침(로드 때 · migrate 뒤 · isValidProfile 앞). "뜻이 분명한 것"만 고친다:
--   NaN · inf → 0(트리 전체) · 숫자 칸의 숫자 문자열 → 숫자 · 개수 칸의 음수 · 소수 → 0 이상 정수 · 빠지거나 모양이 틀린 부가 표(안내 플래그 · 세계 기록 · 칭호 ·
--   알 가방 · 재료 · 방지권 · 자동 처리) → 기본값 · 데이터에서 없어진 보스 id 도장 → 뺌 · ClassData에 새로 생긴 직업 → 그 직업 기본 상태(한 번도 안 한 직업).
--   진행의 몸통(classes 자체 · 직업의 무기 · 장비 · 진도 · 보석 가방 · inventory · tutorial · purchases 자체)이 없거나 모양이 틀리면 고치지 않는다 -
--   빈 값으로 채워 저장하면 남은 진행까지 덮어쓰므로 그대로 invalid_schema(저장 중단 + 안내 · 운영 복구 opsRestoreVersion).
-- 반환: 고친 칸 경로 목록(정상 프로필이면 빈 목록 - 아무것도 바꾸지 않는다). 순수 함수(하네스 save_launch_test가 부른다).
function SaveSystem.repairProfile(data)
	local fixed = {}
	local function note(path)
		if #fixed < 50 then
			table.insert(fixed, path)
		end
	end
	local function scrub(node, path, depth)
		if depth > 12 then
			return
		end
		for key, value in pairs(node) do
			if type(value) == "number" and isBadNumber(value) then
				node[key] = 0
				note(path .. "." .. tostring(key))
			elseif type(value) == "table" then
				scrub(value, path .. "." .. tostring(key), depth + 1)
			end
		end
	end
	scrub(data, "profile", 0)

	-- kind: nil = 숫자로만 · "count" = 0 이상 정수 · "nonneg" = 0 이상
	local function num(tbl, key, path, kind)
		local v = tbl[key]
		if type(v) == "string" and tonumber(v) and not isBadNumber(tonumber(v)) then
			v = tonumber(v)
			tbl[key] = v
			note(path)
		end
		if type(v) ~= "number" then
			return
		end
		local good = v
		if kind == "count" then
			good = math.max(0, math.floor(v))
		elseif kind == "nonneg" then
			good = math.max(0, v)
		end
		if good ~= v then
			tbl[key] = good
			note(path)
		end
	end
	local function tableAt(parent, key, path, default)
		if type(parent[key]) ~= "table" then
			parent[key] = default
			note(path)
		end
		return parent[key]
	end

	num(data, "version", "version")
	num(data, "savedAt", "savedAt")
	num(data, "gold", "gold") -- 음수는 loadProfile이 따로 0으로(통계 SaveNegativeGold)
	num(data, "inventorySlots", "inventorySlots", "count")
	num(data, "gemDust", "gemDust", "count")
	num(data, "milestoneUnlocks", "milestoneUnlocks", "count")
	num(data, "peakLevel", "peakLevel")
	if type(data.peakLevel) == "number" and data.peakLevel < 1 then
		data.peakLevel = 1
		note("peakLevel")
	end
	if type(data.bulkSellCutoffGrade) ~= "string" then
		data.bulkSellCutoffGrade = "normal"
		note("bulkSellCutoffGrade")
	end
	if data.inventoryWindowPosition ~= false and type(data.inventoryWindowPosition) ~= "table" then
		data.inventoryWindowPosition = false
		note("inventoryWindowPosition")
	end
	tableAt(data, "gamepasses", "gamepasses", {}) -- 캐시(접속 때 Roblox 소유 기록으로 다시 맞춘다)
	if type(data.leaderboardTainted) ~= "boolean" then
		data.leaderboardTainted = true -- 모르면 기록 제외 쪽(안전)
		note("leaderboardTainted")
	end

	local materials = tableAt(data, "materials", "materials", {})
	for _, materialId in ipairs(EnhanceMaterialData.order) do
		if materials[materialId] == nil then
			materials[materialId] = 0
			note("materials." .. materialId)
		end
		num(materials, materialId, "materials." .. materialId, "count")
	end

	if type(data.purchases) == "table" then
		local p = data.purchases
		local reroll = tableAt(p, "optionRerollTickets", "purchases.optionRerollTickets", {})
		local tickets = tableAt(p, "protectionTickets", "purchases.protectionTickets", {})
		for _, pair in ipairs({ { reroll, "ancient", "optionRerollTickets" }, { reroll, "primordial", "optionRerollTickets" }, { tickets, "drop", "protectionTickets" }, { tickets, "reset", "protectionTickets" } }) do
			local t, k, name = pair[1], pair[2], pair[3]
			if t[k] == nil then
				t[k] = 0
				note(("purchases.%s.%s"):format(name, k))
			end
			num(t, k, ("purchases.%s.%s"):format(name, k), "count")
		end
		tableAt(p, "protectionClaimedStages", "purchases.protectionClaimedStages", {})
		local codex = tableAt(p, "bossCodex", "purchases.bossCodex", {})
		for bossId, stamped in pairs(table.clone(codex)) do
			if type(bossId) ~= "string" or BossData.bosses[bossId] == nil or stamped ~= true then
				codex[bossId] = nil -- 표시 전용 도장(성능 보상 없음) - 없어진 보스 id 하나 때문에 계정 전체가 로드 실패하지 않게
				note("purchases.bossCodex." .. tostring(bossId))
			end
		end
	end

	local hints = tableAt(data, "hints", "hints", {})
	if hints.gemMerchantUsed ~= nil and type(hints.gemMerchantUsed) ~= "boolean" then
		hints.gemMerchantUsed = false
		note("hints.gemMerchantUsed")
	end
	if hints.bossIntroSeen ~= nil and type(hints.bossIntroSeen) ~= "table" then
		hints.bossIntroSeen = {}
		note("hints.bossIntroSeen")
	end
	if hints.bossAssist ~= nil and type(hints.bossAssist) ~= "table" then -- v75
		hints.bossAssist = {}
		note("hints.bossAssist")
	end
	if hints.stealLockSeen ~= nil and type(hints.stealLockSeen) ~= "boolean" then
		hints.stealLockSeen = false
		note("hints.stealLockSeen")
	end
	local world = tableAt(data, "world", "world", {})
	for _, key in ipairs({ "portals", "bossGates", "nests", "nestDex" }) do
		tableAt(world, key, "world." .. key, {})
	end
	-- QUEUE-ALL4 리뷰 6: titles · eggs는 소유 자산 - 빠짐(nil)만 빈 표로 채우고, 표 아닌 값은 비우지 않는다(invalid_schema → 저장 중단 + 운영 복구)
	for _, key in ipairs({ "titles", "eggs" }) do
		if data[key] == nil then
			tableAt(data, key, key, {})
		end
	end
	local auto = tableAt(data, "autoProcess", "autoProcess", { enabled = false, maxGrade = AUTO_GRADE })
	if type(auto.enabled) ~= "boolean" then
		auto.enabled = false
		note("autoProcess.enabled")
	end
	if not table.find(ArmorData.autoProcessGradeChoices, auto.maxGrade) then
		auto.maxGrade = table.find(ArmorData.autoProcessGradeChoices, AUTO_GRADE) and AUTO_GRADE or ArmorData.autoProcessGradeChoices[1] -- defaultProfile과 같은 값
		auto.enabled = false
		note("autoProcess.maxGrade")
	end

	if type(data.tutorial) == "table" then
		num(data.tutorial, "step", "tutorial.step", "count")
		tableAt(data.tutorial, "granted", "tutorial.granted", {})
	end

	if type(data.classes) == "table" and next(data.classes) ~= nil then -- 빈 classes(전부 사라짐)는 고치지 않는다 - invalid_schema로 남긴다
		for _, classId in ipairs(ClassData.order) do
			local cs = data.classes[classId]
			if cs == nil then
				data.classes[classId] = defaultClassState() -- 데이터에 새로 생긴 직업 = 한 번도 안 한 직업
				note("classes." .. classId)
			elseif type(cs) == "table" then
				local path = "classes." .. classId
				num(cs, "characterExp", path .. ".characterExp", "nonneg")
				num(cs, "rebirthCount", path .. ".rebirthCount", "count")
				num(cs, "milestoneLevel", path .. ".milestoneLevel", "count")
				num(cs, "reclaimLevel", path .. ".reclaimLevel", "nonneg")
				if cs.milestoneLevel == nil then
					cs.milestoneLevel = 0
					note(path .. ".milestoneLevel")
				end
				if cs.reclaimLevel == nil then
					cs.reclaimLevel = 0
					note(path .. ".reclaimLevel")
				end
				if type(cs.bossRotation) ~= "table" then
					cs.bossRotation = { order = {}, index = 1, pending = false, history = {}, debugForceNextId = false } -- 아무도 안 읽는 필드(29-5)
					note(path .. ".bossRotation")
				end
				if type(cs.weapon) == "table" then
					local w = cs.weapon
					num(w, "level", path .. ".weapon.level", "count")
					num(w, "grade", path .. ".weapon.grade", "count")
					num(w, "enhanceGauge", path .. ".weapon.enhanceGauge", "count")
					if type(w.enhanceGauge) == "number" and w.enhanceGauge > EnhanceConfig.gauge.max then
						w.enhanceGauge = EnhanceConfig.gauge.max
						note(path .. ".weapon.enhanceGauge")
					end
					tableAt(w, "gems", path .. ".weapon.gems", { false, false, false, false, false })
					tableAt(w, "slotUnlocked", path .. ".weapon.slotUnlocked", { false, false, false, false, false })
				end
			end
		end
	end
	return fixed
end

-- QUEUE-ALL5 A3(결정 - 출시 뒤 id 삭제 금지 + 안전 로드): 데이터에서 없어진 id(옵션 · 재료 · 장비 몸(등급 · 부위 · 세트 구역 · 직업옵션 · 초월 특수) · 치장 · 칭호)를
--   가진 값을 계정 로드 실패(invalid_schema) · 실행 중 에러 대신 보관 칸 data.quarantine으로 옮긴다(세트 구역 setZone은 모르면 "세트 아님"으로 동작해 옮기지 않는다). id 목록 = shared/IdRegistry(스냅숏 검사 = roblox/tools/ids/id_registry.py).
--   먼저 보관 칸에서 지금은 아는 id가 된 것을 제자리로 돌린다(장비 = 가방 · 보석 = 그 직업 보석 가방 · 재료 = 더함 · 치장 · 칭호 = 다시 가짐 - 착용 · 장착 자리는 비운 채).
--   착용 장비 · 박힌 보석을 옮기면 그 자리는 비운다(장비 nil · 보석 칸 false). 장착 중 치장 · 고른 칭호가 모르는 id면 기본값으로(자산이 아니라 선택이라 보관 안 함).
-- 반환: 보관 칸에 넣은 것 목록("종류:이유"), 되돌린 수, 기본값으로 돌린 선택값 목록. 순수(DataStore 안 씀 - 결과는 다음 저장 때 써진다). 진행 몸통이 표가 아니면 손대지 않는다(검사는 isValidProfile).
function SaveSystem.quarantineUnknownIds(data)
	local IdRegistry = require(ReplicatedStorage.Shared.IdRegistry)
	local known = IdRegistry.known()
	if type(data.quarantine) ~= "table" then
		data.quarantine = {}
	end
	local now = os.time()
	local moved, restored, resets = {}, 0, {} -- resets = 보관하지 않고 기본값으로 돌린 선택값(장착 치장 · 고른 칭호)
	local function put(kind, why, value, classId)
		table.insert(data.quarantine, { kind = kind, why = why, value = value, classId = classId, at = now })
		table.insert(moved, kind .. ":" .. why)
	end
	local classes = type(data.classes) == "table" and data.classes or {}
	local cosmetics = type(data.cosmetics) == "table" and data.cosmetics or nil

	-- ① 되돌리기(그 id가 데이터에 다시 생김)
	local kept = {}
	for _, e in ipairs(data.quarantine) do
		local back = false
		if type(e) == "table" then
			local v = e.value
			if e.kind == "item" and type(v) == "table" and type(data.inventory) == "table" and not IdRegistry.unknownInItem(v) then
				table.insert(data.inventory, v)
				back = true
			elseif e.kind == "gem" and type(v) == "table" and not IdRegistry.unknownInGem(v) and type(classes[e.classId]) == "table" and type(classes[e.classId].gemInventory) == "table" then
				table.insert(classes[e.classId].gemInventory, v)
				back = true
			elseif e.kind == "material" and type(v) == "table" and known.material[tostring(v.id)] and type(data.materials) == "table" then
				data.materials[v.id] = (tonumber(data.materials[v.id]) or 0) + (tonumber(v.amount) or 0)
				back = true
			elseif (e.kind == "cosmeticTheme" or e.kind == "gliderSkin" or e.kind == "cosmeticItem") and cosmetics and known[e.kind][tostring(v)] then
				local bag = e.kind == "cosmeticTheme" and cosmetics.themes or e.kind == "gliderSkin" and cosmetics.gliderSkins or cosmetics.items
				if type(bag) == "table" then
					bag[v] = true
					back = true
				end
			elseif e.kind == "title" and known.title[tostring(v)] and type(data.titles) == "table" then
				data.titles[v] = true
				back = true
			end
		end
		if back then
			restored += 1
		else
			table.insert(kept, e)
		end
	end
	data.quarantine = kept

	-- ② 옮기기
	if type(data.inventory) == "table" then
		local bag = {}
		for _, item in ipairs(data.inventory) do
			local why = IdRegistry.unknownInItem(item)
			if why then
				put("item", why, item)
			else
				table.insert(bag, item)
			end
		end
		if #bag ~= #data.inventory then
			table.clear(data.inventory)
			for i, item in ipairs(bag) do
				data.inventory[i] = item
			end
		end
	end
	for classId, cs in pairs(classes) do
		if type(cs) == "table" then
			if type(cs.equipment) == "table" then
				for part, item in pairs(table.clone(cs.equipment)) do
					local why = IdRegistry.unknownInItem(item)
					if why then
						cs.equipment[part] = nil
						put("item", why, item, classId)
					end
				end
			end
			if type(cs.weapon) == "table" and type(cs.weapon.gems) == "table" then
				for slot, gem in pairs(table.clone(cs.weapon.gems)) do
					local why = IdRegistry.unknownInGem(gem)
					if why then
						cs.weapon.gems[slot] = false
						put("gem", why, gem, classId)
					end
				end
			end
			if type(cs.gemInventory) == "table" then
				local gems = {}
				for _, gem in ipairs(cs.gemInventory) do
					local why = IdRegistry.unknownInGem(gem)
					if why then
						put("gem", why, gem, classId)
					else
						table.insert(gems, gem)
					end
				end
				if #gems ~= #cs.gemInventory then
					cs.gemInventory = gems
				end
			end
		end
	end
	if type(data.materials) == "table" then
		for id, amount in pairs(table.clone(data.materials)) do
			if not known.material[tostring(id)] then
				data.materials[id] = nil
				put("material", tostring(id), { id = id, amount = amount })
			end
		end
	end
	if cosmetics then
		for _, pair in ipairs({ { "cosmeticTheme", cosmetics.themes }, { "gliderSkin", cosmetics.gliderSkins }, { "cosmeticItem", cosmetics.items } }) do -- QUEUE-ALL6 H
			if type(pair[2]) == "table" then
				for id in pairs(table.clone(pair[2])) do
					if not known[pair[1]][tostring(id)] then
						pair[2][id] = nil
						put(pair[1], tostring(id), id)
					end
				end
			end
		end
		if type(cosmetics.equipped) == "table" then
			-- 리뷰(QUEUE-ALL5 A3): equipped에는 세트 칸 · 글라이더 말고도 이름표 색 · 배지(게임패스 선택값 - 테마 id 아님)가 있다 → 세트 칸 · 글라이더만 본다
			local setSlot, itemSlot = {}, {}
			local CSD = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
			for _, slotId in ipairs(CSD.setSlots) do
				setSlot[slotId] = true
			end
			for _, slotId in ipairs(CSD.itemSlots or {}) do
				itemSlot[slotId] = true -- QUEUE-ALL6 H 꾸미기 소품 칸
			end
			for slot, id in pairs(table.clone(cosmetics.equipped)) do
				local kind = slot == "gliderSkin" and "gliderSkin" or (setSlot[slot] and "cosmeticTheme" or (itemSlot[slot] and "cosmeticItem" or nil))
				if kind and type(id) == "string" and not known[kind][id] then
					cosmetics.equipped[slot] = nil -- 기본 모습으로(선택값 - 보관 안 함)
					table.insert(resets, "equipped." .. tostring(slot) .. ":" .. id)
				end
			end
		end
	end
	if type(data.titles) == "table" then
		for id in pairs(table.clone(data.titles)) do
			if not known.title[tostring(id)] then
				data.titles[id] = nil
				put("title", tostring(id), id)
			end
		end
	end
	if type(data.codex) == "table" and type(data.codex.title) == "string" and not known.title[data.codex.title] then
		table.insert(resets, "codexTitle:" .. data.codex.title)
		data.codex.title = nil
	end
	return moved, restored, resets
end

-- 불러오기. 성공하면 profile을 돌려준다(신규 플레이어면 defaultProfile 형태를 migrate에
-- 통과시킨 값). 실패하면 nil + 이유를 돌려준다 - 호출부(SaveServer.server.lua)가 이유에
-- 따라 다르게 안내한다.
--   "future_version" - 저장된 버전이 지금 코드보다 높다(예: 롤백). 여기서 손대면 원본을
--                       잃을 수 있어 손상으로 취급하고 건드리지 않는다.
--   "invalid_schema" - migrate 후에도 필수 필드가 이상하다.
--   그 외 문자열      - DataStore 호출 자체가 재시도 끝에 계속 실패했다(pcall 에러 메시지).
-- 읽은 원본(raw) → 이관 · 손상 고침 · 모르는 id 보관 · 검사 · 음수 골드. QUEUE-MENU2 B: 옛 키 원본과 슬롯 합친 프로필(계정 + 캐릭터)이 같은 길을 탄다.
local function finishLoad(player, raw, info)
	if type(raw) == "table" and type(raw.version) == "string" and tonumber(raw.version) then
		raw.version = tonumber(raw.version) -- QUEUE-ALL4 C: 버전 숫자 문자열(손상)은 이관 전에 숫자로(안 그러면 migrate의 비교가 에러)
	end
	if raw ~= nil and type(raw) ~= "table" then
		return nil, "invalid_schema" -- QUEUE-ALL4 리뷰 5: 표가 아닌 저장값(손상)
	end
	if raw ~= nil and type(raw.version) == "number" and raw.version > SaveConfig.saveVersion then
		return nil, "future_version"
	end

	-- QUEUE-ALL4 C: 손상 저장(버전이 문자열 · 표 자리에 숫자 등)이면 migrate가 에러를 던져 loadProfile 자체가 터졌다(호출부에 프로필이 아예 안 생김).
	-- 에러는 invalid_schema와 같게 다룬다(원본은 건드리지 않음 - 저장 중단 + 안내 · 운영 복구 opsRestoreVersion).
	local okMigrate, profile = pcall(migrate, raw or {})
	if not okMigrate then
		warn(("[SaveSystem] 이관 중 에러(손상 저장): %s - %s"):format(player.Name, tostring(profile)))
		return nil, "invalid_schema"
	end
	local okRepair, repaired = pcall(SaveSystem.repairProfile, profile)
	if okRepair and #repaired > 0 then
		info.repaired = repaired
		warn(("[SaveSystem] 손상 저장 고침: %s - %s"):format(player.Name, table.concat(repaired, " · ")))
	end
	-- QUEUE-ALL5 A3: 모르는 id = 보관 칸으로(로드 실패 대신) · 다시 생긴 id = 제자리로
	local okQ, quarantined, restoredN, resets = pcall(SaveSystem.quarantineUnknownIds, profile)
	if okQ and (#quarantined > 0 or restoredN > 0 or #resets > 0) then
		info.quarantined, info.quarantineRestored = quarantined, restoredN
		warn(("[SaveSystem] 모르는 id 보관: %s - 옮김 %d(%s%s) · 되돌림 %d · 선택 해제 %d(%s)"):format(player.Name, #quarantined, table.concat(quarantined, " · ", 1, math.min(#quarantined, 10)),
			#quarantined > 10 and " …" or "", restoredN, #resets, table.concat(resets, " · ", 1, math.min(#resets, 10))))
	elseif not okQ then
		warn(("[SaveSystem] 보관 처리 에러: %s - %s"):format(player.Name, tostring(quarantined)))
	end
	local okValid, valid = pcall(isValidProfile, profile) -- QUEUE-ALL4 리뷰 5: 칸 자리에 표 아닌 값이면 검사 자체가 에러
	if not okRepair or not okValid or not valid then
		return nil, "invalid_schema"
	end
	-- 손상 저장 음수 골드 → 0(save-audit-alpha 결정 3). 게임 경로로는 못 생긴다 - 생기면 로그 + 통계(SaveServer)로 알린다.
	if profile.gold < 0 then
		info.negativeGold = profile.gold
		profile.gold = 0
		warn(("[SaveSystem] 손상 저장 음수 골드 → 0: %s (저장값 %s)"):format(player.Name, tostring(info.negativeGold)))
	end

	return profile, nil, info
end
SaveSystem.finishLoad = finishLoad

function SaveSystem.loadProfile(player)
	if SlotSaveData.enabled then
		return SaveSystem.loadSlotProfile(player) -- QUEUE-MENU2 B: 계정 키 + 캐릭터 키
	end
	local lastErr
	local totalAttempts = SaveConfig.saveRetryCount + 1 -- 첫 시도 + 재시도 횟수

	for attempt = 1, totalAttempts do
		local ok, result = pcall(function()
			return readStored(player)
		end)

		if ok then
			local raw = result
			local info = {}
			-- 약한 세션 잠금: 다른 서버가 쥐고 있고(놓지 않음) 그 저장이 신선하면 잠깐 기다렸다 다시 읽는다 - 옛 서버의 퇴장 저장이 끝나면
			-- sessionId가 ""가 되거나 savedAt이 바뀐다. 상한까지 안 풀리면 읽은 값으로 진행한다(막지 않는다 - 늦게 온 저장은 기존 stale_session이 막는다).
			local waited = 0
			while SaveSystem.heldElsewhere(raw, os.time()) and waited < SaveConfig.sessionLockMaxWaitSeconds and player.Parent do
				task.wait(SaveConfig.sessionLockPollSeconds)
				waited += SaveConfig.sessionLockPollSeconds
				local okAgain, again = pcall(readStored, player)
				if okAgain then
					raw = again
				end
			end
			if waited > 0 then
				info.lockWaitedSeconds = waited
				info.lockReleased = not SaveSystem.heldElsewhere(raw, os.time())
				print(("[SaveSystem] 세션 잠금 대기: %s %d초 · 풀림=%s"):format(player.Name, waited, tostring(info.lockReleased)))
			end
			-- QUEUE-MENU2 B6: 스위치를 끈 뒤 = 켜 둔 동안의 진행(계정 + 캐릭터 키)을 옛 모양으로 합쳐 읽는다(손실 0) · 읽기 실패 = 로드 실패(옛 값으로 진행하면 그 진행을 덮는다)
			local okMerge, merged = pcall(SaveSystem.mergeSlotsIfNewer, player, raw)
			if not okMerge then
				return nil, tostring(merged)
			end
			if merged ~= raw then
				info.slotMerged = true
			end
			return finishLoad(player, merged, info)
		end

		lastErr = result
		if attempt < totalAttempts then
			task.wait(SaveConfig.saveRetryDelaysSeconds[attempt])
		end
	end

	return nil, lastErr
end

-- ═══ QUEUE-MENU2 B 캐릭터 칸 저장(계정 키 + 캐릭터 키) - 설계 docs/design/menu2-slot-save.md · 나누기/합치기 = server/SlotSave(순수) ═══
--   세션(slotSession[player]) = { account, acctSavedAt, charId, classId, slot, charSavedAt, playMark } - 메모리 프로필은 옛 모양 그대로.
local slotSession = {}
function SaveSystem.slotSessionOf(player)
	return slotSession[player]
end
function SaveSystem.forgetSlotSession(player)
	slotSession[player] = nil
end

local function accountKeyBase(userId)
	return SlotSaveData.accountKeyPrefix .. tostring(userId)
end
local function characterKeyBase(userId, charId)
	return SlotSaveData.characterKeyPrefix .. tostring(userId) .. "_" .. tostring(charId)
end
SaveSystem.accountKeyBase, SaveSystem.characterKeyBase = accountKeyBase, characterKeyBase

-- Studio(수동 · 검증 Play) = 키마다 이 서버 첫 읽기에 접미사 키를 비우고 실제 키를 읽기만(시드) - 쓴 키는 이미 시드된 것으로 친다(방금 쓴 값을 지우지 않게)
local seededKeys = {}
local function readKey(base)
	local suffix = studioSuffix()
	if not suffix then
		return store:GetAsync(base)
	end
	local key = base .. suffix
	if not seededKeys[key] then
		store:RemoveAsync(key)
		seededKeys[key] = true
	end
	local raw = store:GetAsync(key)
	if raw ~= nil then
		return raw
	end
	if ReplicatedStorage:GetAttribute("StudioFreshProfile") == true then
		return nil
	end
	return store:GetAsync(base)
end

-- 키 하나 쓰기(낙관적 동시성 - 저장값 savedAt이 baseline보다 새롭고 내 메아리가 아니면 취소) → true, nil, 새 savedAt | false, 이유
local function updateKey(player, base, baselineSavedAt, payloadFn)
	local key = base .. (studioSuffix() or "")
	if studioSuffix() and not seededKeys[key] then
		pcall(function()
			store:RemoveAsync(key) -- Studio: 이 서버가 처음 만지는 접미사 키 = 지난 Play 값(읽기 시드와 같은 규칙 - 안 비우면 이관 쓰기가 stale)
		end)
	end
	seededKeys[key] = true
	local newSavedAt = os.time()
	local lastErr
	for attempt = 1, SaveConfig.saveRetryCount + 1 do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				local ownEcho = type(old) == "table" and old.savedAt == newSavedAt and old.sessionId == SERVER_SESSION_ID
				if type(old) == "table" and type(old.savedAt) == "number" and old.savedAt > (baselineSavedAt or 0) and not ownEcho then
					return nil
				end
				local v = payloadFn(old)
				sanitizeForSave(v, old, base)
				v.savedAt = newSavedAt
				v.version = SaveConfig.saveVersion
				v.sessionId = releasing[player] and "" or SERVER_SESSION_ID
				return v
			end)
		end)
		if ok then
			if result == nil then
				return false, "stale_session"
			end
			return true, nil, newSavedAt
		end
		lastErr = result
		if attempt <= SaveConfig.saveRetryCount then
			task.wait(SaveConfig.saveRetryDelaysSeconds[attempt])
		end
	end
	return false, tostring(lastErr)
end

-- 계정 키 잠금 대기(옛 키와 같은 약한 잠금)
local function readAccountWithLock(player, info)
	local acct = readKey(accountKeyBase(player.UserId))
	local waited = 0
	while SaveSystem.heldElsewhere(acct, os.time()) and waited < SaveConfig.sessionLockMaxWaitSeconds and player.Parent do
		task.wait(SaveConfig.sessionLockPollSeconds)
		waited += SaveConfig.sessionLockPollSeconds
		local okAgain, again = pcall(readKey, accountKeyBase(player.UserId))
		if okAgain then
			acct = again
		end
	end
	if waited > 0 then
		info.lockWaitedSeconds = waited
		info.lockReleased = not SaveSystem.heldElsewhere(acct, os.time())
	end
	return acct
end

-- 옛 키 → 계정 + 캐릭터(이관) · 키 쓰기. old = 지금 계정 키(다시 켬 재이관이면 - 번호 · 보관함 이어감)
local function migrateLegacyToSlots(player, legacyProfile, old, info)
	local now = os.time()
	local account, characters = SlotSave.splitLegacy(legacyProfile, defaultProfile(), now)
	if type(old) == "table" then
		local offset = math.max(0, (tonumber(old.nextCharId) or 1) - 1)
		for _, ch in ipairs(characters) do
			ch.charId += offset
		end
		for _, s in ipairs(account.slots) do
			if s then
				s.charId += offset
			end
		end
		account.nextCharId += offset
		account.archive = type(old.archive) == "table" and old.archive or {}
		info.slotRemigrated = true
	end
	for _, ch in ipairs(characters) do
		local ok, err = updateKey(player, characterKeyBase(player.UserId, ch.charId), 0, function()
			return { charId = ch.charId, classId = ch.classId, data = ch.data }
		end)
		if not ok then
			return nil, nil, err
		end
	end
	local ok, err, at = updateKey(player, accountKeyBase(player.UserId), type(old) == "table" and old.savedAt or 0, function()
		return account
	end)
	if not ok then
		return nil, nil, err
	end
	account.savedAt = at
	info.slotMigrated = #characters
	print(("[SaveSystem] 캐릭터 칸 이관: %s - 캐릭터 %d · 옛 키 그대로(legacy)"):format(player.Name, #characters))
	return account, characters
end

-- 슬롯 로드: wantSlot = 칸 번호(nil = 마지막 플레이 · "new" = 캐릭터 없이 - 직업 선택이 새 캐릭터)
function SaveSystem.loadSlotProfile(player, wantSlot)
	local info = {}
	local okA, acct = pcall(readAccountWithLock, player, info)
	if not okA then
		return nil, tostring(acct)
	end
	if acct ~= nil and type(acct) ~= "table" then
		return nil, "invalid_schema"
	end
	if type(acct) == "table" and type(acct.version) == "number" and acct.version > SaveConfig.saveVersion then
		return nil, "future_version"
	end
	local account, characters
	local legacyRaw = nil
	if acct == nil or SlotSaveData.legacyRecheck then -- 옛 키 = 계정 키가 없을 때(첫 이관) · 운영이 다시 켬 재확인을 켰을 때만(평소 접속 읽기 = 계정 + 캐릭터)
		local okL, rawL = pcall(readStored, player)
		if not okL then
			return nil, tostring(rawL)
		end
		legacyRaw = rawL
	end
	local legacyNewer = type(acct) == "table" and type(legacyRaw) == "table" and (tonumber(legacyRaw.savedAt) or 0) > (tonumber(acct.savedAt) or 0)
	if acct == nil or legacyNewer then
		local legacyProfile, err = finishLoad(player, legacyRaw, info)
		if not legacyProfile then
			return nil, err
		end
		local mErr
		account, characters, mErr = migrateLegacyToSlots(player, legacyProfile, acct, info)
		if not account then
			return nil, mErr
		end
	else
		account = acct
	end
	local slot = nil
	if wantSlot ~= "new" then
		slot = tonumber(wantSlot) or account.lastSlot
	end
	local summary = slot and type(account.slots) == "table" and account.slots[slot] or nil
	local character, charSavedAt, charVersion = nil, 0, SaveConfig.saveVersion
	if summary then
		for _, ch in ipairs(characters or {}) do
			if ch.charId == summary.charId then
				character = ch
			end
		end
		if not character then
			local okC, raw = pcall(readKey, characterKeyBase(player.UserId, summary.charId))
			if not okC then
				return nil, tostring(raw)
			end
			if type(raw) ~= "table" or type(raw.data) ~= "table" then
				return nil, "missing_character" -- 칸은 있는데 캐릭터 키가 없다(손상) - 빈 캐릭터로 덮지 않는다
			end
			character, charSavedAt, charVersion = { charId = raw.charId or summary.charId, classId = raw.classId or summary.classId, data = raw.data }, tonumber(raw.savedAt) or 0, tonumber(raw.version) or SaveConfig.saveVersion
		else
			charSavedAt = account.savedAt or 0
		end
	end
	if character and SlotSave.legacyPlayTarget(account) == character.charId then -- QUEUE-UI1F-1: 이 수정 전에 이관된 계정 - 옛 플레이 시간을 이관 첫 캐릭터로(한 번)
		if SlotSave.addLegacyPlay(character.data, type(account.shared) == "table" and type(account.shared.audit) == "table" and account.shared.audit.playSeconds) and summary then
			summary.playSeconds = character.data.classState.playSeconds -- 메뉴 카드 = 다음 저장 전에도 바로
		end
	end
	local composed = SlotSave.compose(defaultProfile(), account.shared, character)
	composed.version = math.min(tonumber(account.version) or SaveConfig.saveVersion, charVersion)
	composed.savedAt = tonumber(account.savedAt) or 0
	local profile, err, outInfo = finishLoad(player, composed, info)
	if not profile then
		return nil, err
	end
	slotSession[player] = {
		account = account, acctSavedAt = tonumber(account.savedAt) or 0,
		charId = character and character.charId, classId = character and character.classId, slot = character and slot or nil,
		charSavedAt = charSavedAt, playMark = os.time(),
	}
	return profile, nil, outInfo
end

-- 저장 직전 고친 숫자(NaN · inf → 이전 정상값 - sanitizeForSave)를 메모리 프로필에도 되돌린다(옛 경로는 프로필 자체를 고쳤다 - 칸 경로는 사본을 쓰므로 S21-0(나) 2단계가 X였다)
local function pullSanitized(dst, src)
	for k, v in pairs(src) do
		local d = dst[k]
		if type(v) == "number" and type(d) == "number" and v ~= d then
			dst[k] = v
		elseif type(v) == "table" and type(d) == "table" then
			pullSanitized(d, v)
		end
	end
end

-- 슬롯 저장: 계정 키 → 캐릭터 키(새 캐릭터 첫 저장만 캐릭터 키 먼저). 직업 선택(캐릭터 없음 → 직업 생김) = 새 칸 잡기
--   SEC-FIX-1 1: 옛 = 캐릭터 키 → 계정 키라 계정 키만 실패(stale_session · 장애)하면 보상(골드 · 가방 = 캐릭터 키)은 남고 "받음" 표시(도감 · 시즌 · 출석 · 퀘스트 · 보스 첫 처치 = 계정 키)는
--   빠져 재접속 후 다시 받을 수 있었다. 이제 계정 키를 먼저 써서 성공해야 캐릭터 키를 쓴다 - 계정 키 실패 = 둘 다 안 써짐(다음 저장이 함께 다시) · 다른 서버가 더 새로우면 캐릭터 키도 안 덮음.
--   새 캐릭터(charSavedAt 0 = 키 아직 없음)는 캐릭터 키 먼저 - 계정 칸이 없는 키를 가리키면 다음 로드가 missing_character로 실패한다.
function SaveSystem.saveSlotProfile(player, profile)
	local sess = slotSession[player]
	if not sess then
		return false, "no_slot_session"
	end
	local bad = SaveSystem.clampStageCap(profile)
	if #bad > 0 then
		warn(("[forge-game] 저장 전 스테이지 하드 상한으로 자름: %s - %s"):format(tostring(player and player.Name), table.concat(bad, " · ")))
	end
	if SaveSystem.clampGold(profile) then -- PROG-2B-1 2
		warn(("[forge-game] 저장 전 골드 안전 상한 2^53으로 자름: %s → %s"):format(tostring(player and player.Name), tostring(profile.gold)))
	end
	local now = os.time()
	if profile.classId and not sess.charId then
		local slot, charId = SlotSave.claimSlot(sess.account, profile.classId, now)
		if not slot then
			return false, "slots_full"
		end
		sess.charId, sess.classId, sess.slot, sess.charSavedAt = charId, profile.classId, slot, 0
	end
	local ch, cs = nil, nil
	local function writeCharacter()
		local ok, err, at = updateKey(player, characterKeyBase(player.UserId, sess.charId), sess.charSavedAt, function()
			return { charId = ch.charId, classId = ch.classId, data = ch.data }
		end)
		if not ok then
			return false, err
		end
		for _, k in ipairs(SlotSaveData.characterTop) do
			if type(profile[k]) == "number" and type(ch.data[k]) == "number" then
				profile[k] = ch.data[k]
			elseif type(profile[k]) == "table" and type(ch.data[k]) == "table" then
				pullSanitized(profile[k], ch.data[k])
			end
		end
		if type(cs) == "table" and type(ch.data.classState) == "table" then
			pullSanitized(cs, ch.data.classState)
		end
		sess.charSavedAt = at
		return true
	end
	local characterFirst = sess.charId ~= nil and (tonumber(sess.charSavedAt) or 0) <= 0
	if sess.charId then
		if profile.classId ~= sess.classId then
			warn(("[SaveSystem] 캐릭터 직업 고정 - 프로필 직업 %s ≠ 캐릭터 %s(%s) · 캐릭터 직업으로 저장"):format(tostring(profile.classId), tostring(sess.classId), player.Name))
		end
		cs = profile.classes and profile.classes[sess.classId]
		if type(cs) == "table" and SaveSystem.runtimeHook then
			pcall(SaveSystem.runtimeHook, player, cs) -- QUEUE-MENU2 D: 쿨 · 궁 게이지 · 마지막 위치(CharacterRuntime.capture - 서버가 시작 때 건다 · 하네스는 없음)
		end
		if type(cs) == "table" then
			cs.playSeconds = (tonumber(cs.playSeconds) or 0) + math.max(0, now - (sess.playMark or now))
			sess.playMark = now
		end
		ch = { charId = sess.charId, classId = sess.classId, data = SlotSave.extractCharacter(profile, sess.classId) }
		if characterFirst then
			local ok, err = writeCharacter()
			if not ok then
				return false, err
			end
		end
		local sum = SlotSave.summarize(ch, now, sess.account.slots[sess.slot] or nil)
		sum.lastPlayedAt = now
		sess.account.slots[sess.slot] = sum
		sess.account.lastSlot = sess.slot
	end
	sess.account.shared = SlotSave.extractShared(profile)
	local ok, err, at = updateKey(player, accountKeyBase(player.UserId), sess.acctSavedAt, function()
		return sess.account
	end)
	if not ok then
		return false, err
	end
	pullSanitized(profile, sess.account.shared)
	sess.acctSavedAt = at
	profile.savedAt = at
	if ch and not characterFirst then
		local okC, errC = writeCharacter()
		if not okC then
			return false, errC
		end
	end
	return true
end

-- 스위치 끔(옛 경로): 계정 키가 옛 키보다 새로우면 계정 + 모든 캐릭터(보관 포함)를 옛 모양으로 합친다(손실 0). 읽기 에러 = 던진다(로드 실패).
function SaveSystem.mergeSlotsIfNewer(player, legacyRaw)
	if not SlotSaveData.mergeOnDisable then
		return legacyRaw
	end
	local acct = readKey(accountKeyBase(player.UserId))
	if type(acct) ~= "table" then
		return legacyRaw
	end
	if type(legacyRaw) == "table" and (tonumber(legacyRaw.savedAt) or 0) >= (tonumber(acct.savedAt) or 0) then
		return legacyRaw
	end
	local chars = {}
	local lastCharId = acct.lastSlot and type(acct.slots) == "table" and acct.slots[acct.lastSlot] and acct.slots[acct.lastSlot].charId
	local list = {}
	for _, s in ipairs(type(acct.slots) == "table" and acct.slots or {}) do
		if s then
			table.insert(list, s)
		end
	end
	for _, s in ipairs(type(acct.archive) == "table" and acct.archive or {}) do
		table.insert(list, s)
	end
	for _, s in ipairs(list) do
		local raw = readKey(characterKeyBase(player.UserId, s.charId))
		if type(raw) == "table" and type(raw.data) == "table" then
			table.insert(chars, { charId = s.charId, classId = raw.classId or s.classId, data = raw.data })
		end
	end
	local merged = SlotSave.mergeToLegacy(defaultProfile(), acct, chars, lastCharId)
	merged.version = tonumber(acct.version) or SaveConfig.saveVersion
	merged.savedAt = type(legacyRaw) == "table" and tonumber(legacyRaw.savedAt) or 0 -- 옛 키 쓰기의 낙관적 기준 = 옛 키 값
	merged.sessionId = type(legacyRaw) == "table" and legacyRaw.sessionId or nil
	print(("[SaveSystem] SlotSave 끔: %s - 캐릭터 %d를 옛 모양으로 합쳐 읽음"):format(player.Name, #chars))
	return merged
end

-- 저장. profile.savedAt은 "내가 마지막으로 읽은/저장에 성공한 시점"의 값이어야 한다 -
-- 낙관적 동시성 제어(타임스탬프 비교, 웹 core/save.js "두 탭 동시 저장 감지"와 같은
-- 원리)의 기준값이다. UpdateAsync의 old가 이 값보다 최신이면 - 즉 내가 모르는 사이
-- 다른 서버가 이미 더 최근 저장을 남겼으면 - 내 메모리 상태로 덮어쓰지 않고 포기한다.
-- 성공하면 true, 실패하면 false + 이유("stale_session" 또는 에러 메시지)를 돌려준다.
-- 약한 세션 잠금 판정(순수 - 하네스 · 검증이 부른다): 저장값 raw를 다른 서버가 쥐고 있고(놓지 않음) 그 저장이 신선한가.
function SaveSystem.heldElsewhere(raw, now)
	return type(raw) == "table"
		and type(raw.sessionId) == "string" and raw.sessionId ~= "" and raw.sessionId ~= SERVER_SESSION_ID
		and type(raw.savedAt) == "number" and now - raw.savedAt < SaveConfig.sessionLockFreshSeconds
end

-- 다음 저장이 이 서버의 마지막 저장이다(퇴장 · 서버 종료) - sessionId를 ""로 써서 잠금을 놓는다. 새 로드(init)가 풀어 준다.
function SaveSystem.markReleasing(player, on)
	releasing[player] = on and true or nil
end

-- S1 2-8 운영: 저장 버전 목록 · 복구(DataStore 버전 = 30일 보관 - 탐지 · 복구는 30일 안). userId 키(Studio = 수동 · 검증 키 - 실제 프로필을 건드리지 않는다).
--   복구는 그 사람이 이 서버에 없을 때만(있으면 메모리 상태가 곧 덮어쓴다 - 다른 서버 접속은 알 수 없다: 운영 절차로 확인).
-- MENU2 B1(10-05): 캐릭터 칸 저장이 켜져 있고 계정 키가 있으면 운영 기본 대상 = 계정 키(Acct_) · which = "legacy"(옛 Player_) | "acct" | 캐릭터 번호.
local function legacyOpsKey(userId)
	return "Player_" .. userId .. (studioSuffix() or "")
end
local function acctOpsKey(userId)
	return accountKeyBase(userId) .. (studioSuffix() or "")
end
local function charOpsKey(userId, charId)
	return characterKeyBase(userId, charId) .. (studioSuffix() or "")
end
local function rawGet(key)
	local ok, data = pcall(function()
		return store:GetAsync(key)
	end)
	if not ok then
		return nil, tostring(data)
	end
	return data, nil
end
-- 이 사람이 칸 저장 구조인가(스위치 켬 + 계정 키 있음) → 계정 원본 | nil
function SaveSystem.opsSlotAccount(userId)
	if not SlotSaveData.enabled then
		return nil
	end
	local acct = rawGet(acctOpsKey(userId))
	return type(acct) == "table" and acct or nil
end
-- 계정 원본의 모든 캐릭터 번호(칸 + 보관함)
local function charIdsOf(acct)
	local ids, seen = {}, {}
	local function add(s)
		if type(s) == "table" and s.charId and not seen[s.charId] then
			seen[s.charId] = true
			table.insert(ids, s.charId)
		end
	end
	for _, s in ipairs(type(acct.slots) == "table" and acct.slots or {}) do
		add(s)
	end
	for _, s in ipairs(type(acct.archive) == "table" and acct.archive or {}) do
		add(s)
	end
	return ids
end
function SaveSystem.opsSlotKeys(userId)
	local acct = SaveSystem.opsSlotAccount(userId)
	if not acct then
		return nil, "no_slot_account"
	end
	local chars = {}
	for _, id in ipairs(charIdsOf(acct)) do
		table.insert(chars, charOpsKey(userId, id))
	end
	return { acct = acctOpsKey(userId), chars = chars }
end
local function opsKey(userId, which)
	if which == "legacy" then
		return legacyOpsKey(userId)
	elseif tonumber(which) then
		return charOpsKey(userId, tonumber(which))
	elseif which == "acct" or SaveSystem.opsSlotAccount(userId) then
		return acctOpsKey(userId)
	end
	return legacyOpsKey(userId)
end
-- 키 단위 입구(되돌리기 executeSlots deps)
function SaveSystem.opsListVersionsKey(key, count)
	local ok, pages = pcall(function()
		return store:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, count or 10)
	end)
	if not ok then
		return nil, tostring(pages)
	end
	local list = {}
	for _, info in ipairs(pages:GetCurrentPage()) do
		table.insert(list, { version = info.Version, createdTime = info.CreatedTime, isDeleted = info.IsDeleted })
	end
	return list
end
SaveSystem.opsReadKey = rawGet
function SaveSystem.opsReadKeyVersion(key, version)
	local ok, data = pcall(function()
		return store:GetVersionAsync(key, version)
	end)
	return ok and data or nil
end
function SaveSystem.opsWriteKey(key, data)
	local ok, err = pcall(function()
		store:SetAsync(key, data)
	end)
	return ok, ok and nil or tostring(err)
end
-- 칸 저장 보기(미리보기 · inspect): 계정 + 모든 캐릭터를 옛 모양 한 프로필로 합친다(요약 전용 - 쓰지 않는다). atTime = 그 시각 버전(없으면 지금)
--   잠금 판정(heldElsewhere)이 그대로 쓰게 savedAt · sessionId = 계정 키 값.
function SaveSystem.opsSlotView(userId, atTime)
	local keys = SaveSystem.opsSlotKeys(userId)
	if not keys then
		return nil
	end
	local function at(key)
		if not atTime then
			return (rawGet(key))
		end
		local list = SaveSystem.opsListVersionsKey(key, 50)
		local pick = list and require(script.Parent.OpsRollback).pick(list, atTime)
		return pick and SaveSystem.opsReadKeyVersion(key, pick.version) or nil
	end
	local acct = at(keys.acct)
	if type(acct) ~= "table" then
		return nil
	end
	local chars = {}
	for _, id in ipairs(charIdsOf(acct)) do
		local raw = at(charOpsKey(userId, id))
		if type(raw) == "table" and type(raw.data) == "table" then
			table.insert(chars, { charId = id, classId = raw.classId, data = raw.data })
		end
	end
	local view = SlotSave.mergeToLegacy(defaultProfile(), acct, chars, nil)
	view.savedAt, view.sessionId, view.version = acct.savedAt, acct.sessionId, acct.version
	view.slotCharacters = #chars
	return view
end
function SaveSystem.opsListVersions(userId, count, which)
	local ok, pages = pcall(function()
		return store:ListVersionsAsync(opsKey(userId, which), Enum.SortDirection.Descending, nil, nil, count or 10)
	end)
	if not ok then
		return nil, tostring(pages)
	end
	local list = {}
	for _, info in ipairs(pages:GetCurrentPage()) do
		table.insert(list, { version = info.Version, createdTime = info.CreatedTime, isDeleted = info.IsDeleted })
	end
	return list
end
function SaveSystem.opsRestoreVersion(userId, version, which)
	local key = opsKey(userId, which)
	local ok, data = pcall(function()
		return store:GetVersionAsync(key, version)
	end)
	if not ok or type(data) ~= "table" then
		return false, ok and "no_data" or tostring(data)
	end
	data = table.clone(data)
	data.savedAt = os.time() -- 다른 서버의 옛 세션 저장이 이 값을 보고 포기한다(되돌리기와 같은 규칙 - MENU2 B1)
	data.sessionId = ""
	local okSet, err = pcall(function()
		store:SetAsync(key, data)
	end)
	return okSet, okSet and "ok" or tostring(err)
end
-- QUEUE-ALL6 F4 되돌리기(OpsRollback) 저장소 입구: 지금 값 · 버전 값 읽기 · 통째로 쓰기(같은 키 규칙 opsKey)
--   MENU2 B1: 칸 저장이면 지금 값 = 계정 + 캐릭터 합친 보기(요약 · 잠금 판정용 - opsSlotView) · 버전 읽기 · 통째 쓰기는 옛 키 전용(칸 = executeSlots)
function SaveSystem.opsReadCurrent(userId)
	if SaveSystem.opsSlotAccount(userId) then
		local view = SaveSystem.opsSlotView(userId)
		if view then
			return view, nil
		end
	end
	return rawGet(legacyOpsKey(userId))
end
function SaveSystem.opsReadVersion(userId, version)
	local ok, data = pcall(function()
		return store:GetVersionAsync(legacyOpsKey(userId), version)
	end)
	return ok and data or nil
end
function SaveSystem.opsWriteProfile(userId, data)
	local ok, err = pcall(function()
		store:SetAsync(legacyOpsKey(userId), data)
	end)
	return ok, ok and nil or tostring(err)
end

-- S1 2-1: 하드 상한을 넘는 스테이지 필드(직업마다 infinite · infiniteBest · bestBossCleared) 목록 - 있으면 그 저장을 거부한다(옛 값 유지 · 로그).
function SaveSystem.stageCapViolations(profile)
	local cap = require(game:GetService("ReplicatedStorage").Shared.data.InfiniteStageConfig).hardMaxStage
	local bad = {}
	for classId, cs in pairs(type(profile) == "table" and profile.classes or {}) do
		local sp = type(cs) == "table" and cs.stageProgress
		if type(sp) == "table" then
			for _, field in ipairs({ "infinite", "infiniteBest", "bestBossCleared" }) do
				if type(sp[field]) == "number" and sp[field] > cap then
					table.insert(bad, ("%s.%s=%s"):format(tostring(classId), field, tostring(sp[field])))
				end
			end
		end
	end
	return bad
end

-- 리뷰 7: 넘는 값은 상한으로 자른다(저장 전체 거부 = 골드 · 아이템까지 못 쓰게 된다) + 로그. 반환: 자른 칸 목록.
function SaveSystem.clampStageCap(profile)
	local bad = SaveSystem.stageCapViolations(profile)
	if #bad > 0 then
		local cap = require(game:GetService("ReplicatedStorage").Shared.data.InfiniteStageConfig).hardMaxStage
		for _, cs in pairs(profile.classes or {}) do
			local sp = type(cs) == "table" and cs.stageProgress
			if type(sp) == "table" then
				for _, field in ipairs({ "infinite", "infiniteBest", "bestBossCleared" }) do
					if type(sp[field]) == "number" and sp[field] > cap then
						sp[field] = cap
					end
				end
			end
		end
		SaveSystem.capClamped = (SaveSystem.capClamped or 0) + 1
	end
	return bad
end

-- PROG-2B-1 2: 저장 직전 · 로드 직후 골드 내부 안전 상한(NumberGuard.SAFE_MAX = 2^53 - 넘으면 자름). 반환 = 바뀌었나
--   NaN · inf · 음수는 여기서 안 고친다 - sanitizeForSave(저장) · 손상 판정(로드)이 고치고 "고친 칸"을 기록한다(먼저 고치면 기록이 사라짐).
function SaveSystem.clampGold(profile)
	local NumberGuard = require(ReplicatedStorage.Shared.NumberGuard)
	if type(profile) ~= "table" or type(profile.gold) ~= "number" or not (profile.gold > NumberGuard.SAFE_MAX) or profile.gold == math.huge then
		return false
	end
	profile.gold = NumberGuard.SAFE_MAX
	return true
end

function SaveSystem.saveProfile(player, profile)
	if SlotSaveData.enabled then
		return SaveSystem.saveSlotProfile(player, profile) -- QUEUE-MENU2 B: 옛 키(Player_)는 켬 동안 쓰지 않는다(legacy 보존)
	end
	local bad = SaveSystem.clampStageCap(profile)
	if #bad > 0 then
		warn(("[forge-game] 저장 전 스테이지 하드 상한으로 자름: %s - %s"):format(tostring(player and player.Name), table.concat(bad, " · ")))
	end
	if SaveSystem.clampGold(profile) then -- PROG-2B-1 2
		warn(("[forge-game] 저장 전 골드 안전 상한 2^53으로 자름: %s → %s"):format(tostring(player and player.Name), tostring(profile.gold)))
	end
	local key = storeKey(player)
	local baselineSavedAt = profile.savedAt or 0
	local newSavedAt = os.time()
	local lastErr
	local totalAttempts = SaveConfig.saveRetryCount + 1 -- 첫 시도 + 재시도 횟수

	for attempt = 1, totalAttempts do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				-- QUEUE-ALL4 C: 앞 시도가 실제로는 써졌는데 호출이 에러로 끝난 경우(타임아웃 등) 재시도가 "내가 방금 쓴 값"을 다른 서버 저장으로 오판해
				-- stale_session(그 세션 저장 중단)이 됐다. 저장값의 savedAt이 이번 저장의 시각과 같고 표식이 이 서버 것이면 내 메아리로 본다.
				-- 놓음("")은 메아리로 치지 않는다 - 옮겨 간 서버의 퇴장 저장도 ""라 같은 초에 겹치면 남의 마지막 저장을 덮는다(하네스 [LOCK] 실측).
				-- 퇴장 저장의 메아리는 그대로 stale로 끝나지만 첫 시도가 이미 써졌으므로 잃는 것은 없다.
				local ownEcho = old ~= nil and old.savedAt == newSavedAt and old.sessionId == SERVER_SESSION_ID
				if old ~= nil and type(old.savedAt) == "number" and old.savedAt > baselineSavedAt and not ownEcho then
					return nil -- 콜백이 nil을 돌려주면 UpdateAsync가 쓰기를 취소한다(로블록스 API 규칙)
				end
				sanitizeForSave(profile, old, "profile") -- S21-0 A3: NaN·inf가 저장 전체를 실패시키기 전에 그 필드만 되돌린다.
				profile.savedAt = newSavedAt
				profile.version = SaveConfig.saveVersion
				profile.sessionId = releasing[player] and "" or SERVER_SESSION_ID -- v55 약한 세션 잠금
				return profile
			end)
		end)

		if ok then
			if result == nil then
				profile.savedAt = baselineSavedAt -- QUEUE-ALL4 리뷰 7: 콜백이 앞당긴 기준을 되돌린다(쓰기 안 됨)
				return false, "stale_session"
			end
			profile.savedAt = newSavedAt
			return true
		end

		lastErr = result
		if attempt < totalAttempts then
			task.wait(SaveConfig.saveRetryDelaysSeconds[attempt])
		end
	end

	profile.savedAt = baselineSavedAt -- QUEUE-ALL4 리뷰 7: 실패 뒤 다음 주기에 다시 저장하므로 기준(stale 판정)을 읽은 값으로 되돌린다
	return false, lastErr
end

return SaveSystem
