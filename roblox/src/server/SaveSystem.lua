-- 골드 등 영구 저장 데이터의 DataStore 입출력 전담. 세션(Player) 메모리 상태는 다루지
-- 않는다 - 그건 PlayerProfile이 한다. 이 모듈은 "키 하나를 읽고/쓴다"와 스키마
-- 기본값·버전 이관만 안다 - 웹 core/save.js와 같은 역할, 같은 패턴(SAVE_VERSION+migrate()).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SaveConfig = require(ReplicatedStorage.Shared.data.SaveConfig)
local WeaponData = require(ReplicatedStorage.Shared.data.WeaponData)

local SaveSystem = {}

-- 신규/구버전 프로필에 지급하는 시작 무기. 등급·기본공격력 등 정적 스탯은 WeaponData에만
-- 있다 - 여기(저장 데이터)엔 계속 바뀌는 값(강화 단계)과 어떤 무기인지(id)만 남긴다.
local function defaultWeapon()
	return { id = WeaponData.starterId, level = 0 }
end

local store = DataStoreService:GetDataStore(SaveConfig.dataStoreName)

local function profileKey(player)
	return "Player_" .. player.UserId
end

-- 저장 구조 기본값. 지금 실제로 쓰는 필드는 gold·equipment.weapon뿐이지만, 곧 들어올
-- 필드(클래스·나머지 장비·스테이지 진행도·인벤토리 칸 수·게임패스)의 자리를 미리
-- 만들어 둔다 - 그래야 그 기능이 생길 때 SAVE_VERSION을 또 올리지 않고 채워 넣을 수 있다.
local function defaultProfile()
	return {
		version = SaveConfig.saveVersion,
		savedAt = 0, -- migrate() 시점 데이터는 항상 "가장 오래된 것"으로 본다(웹 core/save.js와 같은 원칙)
		gold = 0,

		-- 캐릭터 레벨(13-2) - 누적 경험치만 저장하고 레벨은 항상 CharacterLevel.getLevelFromExp로
		-- 파생시킨다(웹 core/save.js가 weaponExp만 저장하고 weaponExpLevel은 저장 안 하는 것과
		-- 같은 원칙 - 파생값을 저장하면 곡선을 고칠 때마다 저장분과 어긋난다).
		characterExp = 0,

		-- 클래스 선택(10-3). 필드는 있지만 값은 nil - "아직 안 골랐다"가 지금은 실제로
		-- 맞는 상태이고, 이 nil이 곧 클라이언트가 선택 UI를 띄우는 조건이 된다
		-- (ClassSelectUI.client.lua, PlayerProfile.init이 Attribute로 옮길 때 빈 문자열로
		-- 바꾼다 - Attribute는 nil을 담지 못한다). 억지 기본값(첫 클래스 자동 지정)을 넣으면
		-- 이미 고른 것으로 착각해 선택 UI가 영원히 안 뜬다.
		classId = nil,

		-- 웹 core/equipment.js ITEM_PARTS(무기/갑옷/장갑/신발)와 같은 4슬롯. 무기만 시작
		-- 지급한다(10-2 [1]) - 강화할 대상이 있어야 하기 때문이다. 갑옷·장갑·신발은 드랍으로만
		-- 얻는다 - 가짜 기본 장비를 채우지 않는다(16-6부터 셋 다 실제로 드랍·장착된다,
		-- 그 전엔 갑옷만 있었다). 필드명은 "shoes" - v8까지 쓰던 "boots"는 실제로 한 번도
		-- 값이 채워진 적 없는 죽은 이름이라(드랍 시스템 자체가 없었다) migrate()에서
		-- 그냥 이름만 바꾼다(아래 v9 참고).
		equipment = { weapon = defaultWeapon(), armor = nil, gloves = nil, shoes = nil },

		-- 일반/무한 모드 진행도(11-1 개정). 무한 모드가 이 게임의 유일한 모드가 되면서
		-- "미진입=0" 개념이 없어졌다 - 접속하면 바로 1단계다. infiniteBest(최고 도달
		-- 단계)는 현재 단계와 분리한다 - 파밍하러 내려가면 현재 단계는 낮아져도 최고
		-- 기록은 그대로 남아야 한다(PRD 20.12 경쟁 축과도 맞다).
		-- bestBossCleared(15-1): 최고로 깬 보스 스테이지 - "0"은 아직 하나도 못 깼다는
		-- 뜻이다(무한 진입 즉시 1단계인 infinite와 달리, 보스는 실제로 깨기 전엔 0이
		-- 맞는 초기값이다). StageServer의 게이트 검사가 이 값을 기준으로 삼는다.
		stageProgress = { normal = 1, infinite = 1, infiniteBest = 1, bestBossCleared = 0 },

		inventorySlots = SaveConfig.defaultInventorySlots,

		-- 인벤토리 실제 내용물(12-1). 갑옷 드랍만 담는다 - { grade = "normal"/"rare",
		-- dropStage = 주운 스테이지 }. 슬롯 수(inventorySlots)와 분리된 필드다 - 슬롯 수는
		-- "몇 칸인가"고 이건 "무엇이 들었는가"다.
		inventory = {},

		-- 구매한 게임패스 id 집합. {[id]=true} 형태. 상점이 없어 항상 빈 테이블이다.
		gamepasses = {},
	}
end

-- data.version < SaveConfig.saveVersion일 때 순차 변환(웹 core/save.js와 같은 패턴).
-- 다음 필드 추가 절차: 1) defaultProfile에 필드 추가 2) SaveConfig.saveVersion을 올린다
-- 3) 아래에 `if data.version < N then ... data.version = N end` 블록을 추가한다.
-- 지금은 열 단계 - 0(스키마 버전 개념 자체가 없던 상태) -> 1(골드 도입) -> 2(시작 무기
-- 지급) -> 3(클래스 선택 필드 도입) -> 4(무한 모드 스테이지 현재/최고 분리)
-- -> 5(인벤토리 배열 도입) -> 6(인벤토리 아이템 locked 필드 도입) -> 7(캐릭터 레벨 도입 +
-- 아이템 itemLevel 필드 도입) -> 8(보스 처치 기록 bestBossCleared 도입, 15-1)
-- -> 9(equipment.boots -> shoes 이름 정리, 16-6) -> 10(아이템 part 필드 소급 도입, 16-6).
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

	data.savedAt = data.savedAt or 0
	return data
end

-- 저장 데이터가 게임에 바로 쓸 수 있는 최소 형태인지 검증(웹 isValidSaveData와 같은 목적).
local function isValidProfile(data)
	return type(data) == "table"
		and type(data.version) == "number"
		and type(data.gold) == "number"
		and type(data.characterExp) == "number"
		and type(data.equipment) == "table"
		and type(data.equipment.weapon) == "table"
		and type(data.equipment.weapon.level) == "number"
		and (data.classId == nil or type(data.classId) == "string")
		and type(data.stageProgress) == "table"
		and type(data.inventorySlots) == "number"
		and type(data.inventory) == "table"
		and type(data.gamepasses) == "table"
end

SaveSystem.defaultProfile = defaultProfile
SaveSystem.migrate = migrate
SaveSystem.isValidProfile = isValidProfile

-- 불러오기. 성공하면 profile을 돌려준다(신규 플레이어면 defaultProfile 형태를 migrate에
-- 통과시킨 값). 실패하면 nil + 이유를 돌려준다 - 호출부(SaveServer.server.lua)가 이유에
-- 따라 다르게 안내한다.
--   "future_version" - 저장된 버전이 지금 코드보다 높다(예: 롤백). 여기서 손대면 원본을
--                       잃을 수 있어 손상으로 취급하고 건드리지 않는다.
--   "invalid_schema" - migrate 후에도 필수 필드가 이상하다.
--   그 외 문자열      - DataStore 호출 자체가 재시도 끝에 계속 실패했다(pcall 에러 메시지).
function SaveSystem.loadProfile(player)
	local key = profileKey(player)
	local lastErr
	local totalAttempts = SaveConfig.saveRetryCount + 1 -- 첫 시도 + 재시도 횟수

	for attempt = 1, totalAttempts do
		local ok, result = pcall(function()
			return store:GetAsync(key)
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
	local key = profileKey(player)
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
