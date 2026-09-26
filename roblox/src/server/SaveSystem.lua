-- 골드 등 영구 저장 데이터의 DataStore 입출력 전담. 세션(Player) 메모리 상태는 다루지
-- 않는다 - 그건 PlayerProfile이 한다. 이 모듈은 "키 하나를 읽고/쓴다"와 스키마
-- 기본값·버전 이관만 안다 - 웹 core/save.js와 같은 역할, 같은 패턴(SAVE_VERSION+migrate()).

local DataStoreService = game:GetService("DataStoreService")
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
-- 28-1 S03: 강화 천장 게이지(weapon.enhanceGauge)의 상한 검사용(v24->v25 · isValidProfile).
local EnhanceConfig = require(ReplicatedStorage.Shared.data.EnhanceConfig)
-- 28-1 S04: 강화 재료 보유량(profile.materials)의 기본값 · 이관(v25->v26) · isValidProfile 검사용.
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
-- S19b 사전 작업 2: 검증 모드(verifyArmed - Studio에서 터미널이 켠 때만)의 저장 키 분리용.
local DevToolsConfig = require(ReplicatedStorage.Shared.data.DevToolsConfig)

local SaveSystem = {}

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

local store = DataStoreService:GetDataStore(SaveConfig.dataStoreName)

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
	return store:GetAsync(profileKey(player))
end

-- 저장 구조 기본값. 지금 실제로 쓰는 필드는 gold·equipment.weapon뿐이지만, 곧 들어올
-- 필드(클래스·나머지 장비·스테이지 진행도·인벤토리 칸 수·게임패스)의 자리를 미리
-- 만들어 둔다 - 그래야 그 기능이 생길 때 SAVE_VERSION을 또 올리지 않고 채워 넣을 수 있다.
local function defaultProfile()
	return {
		version = SaveConfig.saveVersion,
		savedAt = 0, -- migrate() 시점 데이터는 항상 "가장 오래된 것"으로 본다(웹 core/save.js와 같은 원칙)

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

		-- 구매한 게임패스 id 집합. {[id]=true} 형태. 상점이 없어 항상 빈 테이블이다.
		gamepasses = {},

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
		hints = { gemMerchantUsed = false, bossIntroSeen = {}, stealLockSeen = false },

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

		-- 보석 가루(P2.5b C, v31) - 계정 공유(gold · materials와 같은 층). 보석 분해로만 늘고(PlayerProfile.dismantleGem · dismantleGemsUpTo) 재련 · 변환권 구매가 쓴다(trySpendGemDust).
		gemDust = 0,

		-- 환생 후 해금 마일스톤 받은 개수(P2.5b D, v32) - 계정 공유(가방 칸 · 계승 할인 같은 계정 효과). MilestoneData.unlocks의 앞에서부터 이 개수만큼 열렸다.
		milestoneUnlocks = 0,

		-- 리더보드 기록 제외(P3a B3, v34) - 계정 단위. 이 계정에서 /gg(개발 명령)가 한 번이라도 돌면 true(PlayerProfile.markLeaderboardTainted) - "/gg로 만든 진도는 기록하지 않는다".
		leaderboardTainted = false,

		-- 줍는 순간 자동 처리(G1-2, v36) - 계정 단위(bulkSellCutoffGrade와 같은 층). enabled = 켜짐 · maxGrade = 이 등급 이하(ArmorData.autoProcessGradeChoices 중 하나).
		autoProcess = { enabled = false, maxGrade = "epic" },
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
		-- 옛 곡선(v34 - 필요 경험치 = round(K × E), 배수 없음)으로 레벨과 진행률을 읽고, 새 곡선에서 같은 레벨 · 같은 진행률의 값으로 옮긴다(126 아래 · 0은 그대로).
		local base = CharacterLevel.getExpForLevel(126)
		local function oldNeed(level)
			return math.floor(CharacterLevel.getTargetKills(level) * CharacterLevel.getMonsterExpAtLevel(level) + 0.5)
		end
		for _, classState in pairs(data.classes) do
			local exp = classState.characterExp
			if type(exp) == "number" and exp == exp and exp > base and exp < math.huge then
				local level, threshold = 126, base
				while level < 1000000 do
					local need = oldNeed(level)
					if exp < threshold + need then
						break
					end
					threshold += need
					level += 1
				end
				local fraction = (exp - threshold) / oldNeed(level)
				classState.characterExp = CharacterLevel.getExpForLevel(level) + fraction * CharacterLevel.getExpToNextLevel(level)
			end
		end
		data.version = 35
	end

	if data.version < 36 then
		-- G1-2: 줍는 순간 자동 처리 필터 신설 - 기본 끔(옛 동작 = 전부 가방에 보관).
		data.autoProcess = { enabled = false, maxGrade = "epic" }
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

	data.savedAt = data.savedAt or 0
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
		if not isValidOption(item.option) then
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

-- 불러오기. 성공하면 profile을 돌려준다(신규 플레이어면 defaultProfile 형태를 migrate에
-- 통과시킨 값). 실패하면 nil + 이유를 돌려준다 - 호출부(SaveServer.server.lua)가 이유에
-- 따라 다르게 안내한다.
--   "future_version" - 저장된 버전이 지금 코드보다 높다(예: 롤백). 여기서 손대면 원본을
--                       잃을 수 있어 손상으로 취급하고 건드리지 않는다.
--   "invalid_schema" - migrate 후에도 필수 필드가 이상하다.
--   그 외 문자열      - DataStore 호출 자체가 재시도 끝에 계속 실패했다(pcall 에러 메시지).
function SaveSystem.loadProfile(player)
	local lastErr
	local totalAttempts = SaveConfig.saveRetryCount + 1 -- 첫 시도 + 재시도 횟수

	for attempt = 1, totalAttempts do
		local ok, result = pcall(function()
			return readStored(player)
		end)

		if ok then
			local raw = result
			if raw ~= nil and type(raw.version) == "number" and raw.version > SaveConfig.saveVersion then
				return nil, "future_version"
			end

			local profile = migrate(raw or {})
			if not isValidProfile(profile) then
				return nil, "invalid_schema"
			end

			return profile
		end

		lastErr = result
		if attempt < totalAttempts then
			task.wait(SaveConfig.saveRetryDelaysSeconds[attempt])
		end
	end

	return nil, lastErr
end

-- 저장. profile.savedAt은 "내가 마지막으로 읽은/저장에 성공한 시점"의 값이어야 한다 -
-- 낙관적 동시성 제어(타임스탬프 비교, 웹 core/save.js "두 탭 동시 저장 감지"와 같은
-- 원리)의 기준값이다. UpdateAsync의 old가 이 값보다 최신이면 - 즉 내가 모르는 사이
-- 다른 서버가 이미 더 최근 저장을 남겼으면 - 내 메모리 상태로 덮어쓰지 않고 포기한다.
-- 성공하면 true, 실패하면 false + 이유("stale_session" 또는 에러 메시지)를 돌려준다.
function SaveSystem.saveProfile(player, profile)
	local key = storeKey(player)
	local baselineSavedAt = profile.savedAt or 0
	local newSavedAt = os.time()
	local lastErr
	local totalAttempts = SaveConfig.saveRetryCount + 1 -- 첫 시도 + 재시도 횟수

	for attempt = 1, totalAttempts do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				if old ~= nil and type(old.savedAt) == "number" and old.savedAt > baselineSavedAt then
					return nil -- 콜백이 nil을 돌려주면 UpdateAsync가 쓰기를 취소한다(로블록스 API 규칙)
				end
				sanitizeForSave(profile, old, "profile") -- S21-0 A3: NaN·inf가 저장 전체를 실패시키기 전에 그 필드만 되돌린다.
				profile.savedAt = newSavedAt
				profile.version = SaveConfig.saveVersion
				return profile
			end)
		end)

		if ok then
			if result == nil then
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

	return false, lastErr
end

return SaveSystem
