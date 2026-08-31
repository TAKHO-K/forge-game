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
-- classId는 필드 자체를 안 넣는다(nil) - 클래스 선택 UI가 없는 지금은 "선택 안 함"이
-- 유일하게 맞는 값이고, 억지 기본값(예: 첫 클래스 자동 지정)을 넣으면 나중에 클래스
-- 선택 화면이 생겼을 때 "이미 골랐다"고 착각하게 만든다.
local function defaultProfile()
	return {
		version = SaveConfig.saveVersion,
		savedAt = 0, -- migrate() 시점 데이터는 항상 "가장 오래된 것"으로 본다(웹 core/save.js와 같은 원칙)
		gold = 0,

		-- 웹 core/equipment.js ITEM_PARTS(무기/갑옷/장갑/신발)와 같은 4슬롯. 무기만 시작
		-- 지급한다(10-2 [1]) - 강화할 대상이 있어야 하기 때문이다. 갑옷·장갑·신발은 드랍
		-- 시스템이 아직 없어 그대로 비어 있다(nil = 미장착) - 가짜 기본 장비를 채우지 않는다.
		equipment = { weapon = defaultWeapon(), armor = nil, gloves = nil, boots = nil },

		-- 일반/무한 모드 진행도. 스테이지 시스템이 없는 지금도 "1스테이지부터"는 실제로
		-- 맞는 시작값이라 0이 아니라 1을 넣는다(무한 모드는 미진입 상태가 곧 0).
		stageProgress = { normal = 1, infinite = 0 },

		inventorySlots = SaveConfig.defaultInventorySlots,

		-- 구매한 게임패스 id 집합. {[id]=true} 형태. 상점이 없어 항상 빈 테이블이다.
		gamepasses = {},
	}
end

-- data.version < SaveConfig.saveVersion일 때 순차 변환(웹 core/save.js와 같은 패턴).
-- 다음 필드 추가 절차: 1) defaultProfile에 필드 추가 2) SaveConfig.saveVersion을 올린다
-- 3) 아래에 `if data.version < N then ... data.version = N end` 블록을 추가한다.
-- 지금은 두 단계 - 0(스키마 버전 개념 자체가 없던 상태) -> 1(골드 도입) -> 2(시작 무기 지급).
local function migrate(data)
	data.version = data.version or 0

	if data.version < 1 then
		data.gold = data.gold or 0
		data.equipment = data.equipment or { weapon = nil, armor = nil, gloves = nil, boots = nil }
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

	data.savedAt = data.savedAt or 0
	return data
end

-- 저장 데이터가 게임에 바로 쓸 수 있는 최소 형태인지 검증(웹 isValidSaveData와 같은 목적).
local function isValidProfile(data)
	return type(data) == "table"
		and type(data.version) == "number"
		and type(data.gold) == "number"
		and type(data.equipment) == "table"
		and type(data.equipment.weapon) == "table"
		and type(data.equipment.weapon.level) == "number"
		and type(data.stageProgress) == "table"
		and type(data.inventorySlots) == "number"
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
