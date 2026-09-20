-- 장비 보기 서버 조회(S12b B). 클라가 "이 userId의 장비를 보여 줘"를 물으면 같은 서버에 있는 그 플레이어의 **공개 필드만** 돌려준다.
--   공개 = 표시이름 · @username · 레벨 · 환생 · 직업 · 무기(등급 · 강화 단계 · 보석 5칸) · 착용 장비 3부위(등급 · 부위 · itemLevel · 옵션). 골드 · 재료 · 가방 · 잠금 · dropStage · 진행도 등은 안 나간다.
--   buildSnapshot이 화이트리스트로 필드를 하나씩 옮겨 담는다(통째 복사하지 않는다 - 저장 필드가 늘어도 자동으로 새지 않는다).
-- 같은 서버가 아니거나 없는 id면 거절, 요청자별 최소 간격(SocialData.inspect.minIntervalSeconds) 안의 재요청은 거절(잘못된 요청도 간격을 소모한다).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)
local Gem = require(ReplicatedStorage.Shared.Gem)
local SocialData = require(ReplicatedStorage.Shared.data.SocialData)
local PlayerProfile = require(script.Parent.PlayerProfile)

local PlayerInspect = {}

-- 화이트리스트(검증이 이 표와 실제 반환값의 키를 대조한다).
PlayerInspect.publicKeys = {
	root = { "userId", "name", "displayName", "classId", "level", "rebirthCount", "weapon", "equipment" },
	weapon = { "gradeId", "level", "gems" },
	item = { "grade", "part", "itemLevel", "option" }, -- 장비 · 보석 공통(보석은 part 없음)
	option = { "id", "roll", "roll2" },
}

local remote = Instance.new("RemoteFunction")
remote.Name = "InspectPlayer"
remote.Parent = ReplicatedStorage

local lastRequestAt = setmetatable({}, { __mode = "k" })

local function publicOption(option)
	if type(option) ~= "table" then
		return nil
	end
	return { id = option.id, roll = option.roll, roll2 = option.roll2 }
end

local function publicItem(item)
	if type(item) ~= "table" then
		return false
	end
	return { grade = item.grade, part = item.part, itemLevel = item.itemLevel, option = publicOption(item.option) }
end

-- 순수 함수: info = { userId, name, displayName, classId, classState } → 공개 스냅샷. classState = profile.classes[classId](characterExp · rebirthCount · weapon · equipment).
function PlayerInspect.buildSnapshot(info)
	local classState = info.classState
	local weapon = classState.weapon
	local gems = {}
	for slot = 1, Gem.slotCount do
		gems[slot] = publicItem(weapon.gems[slot]) -- 빈 칸(false)은 false 그대로
	end
	local equipment = {}
	for _, part in ipairs({ "armor", "gloves", "shoes" }) do
		local item = classState.equipment[part]
		equipment[part] = item and publicItem(item) or nil
	end
	return {
		userId = info.userId,
		name = info.name,
		displayName = info.displayName,
		classId = info.classId,
		level = CharacterLevel.getLevelFromExp(classState.characterExp),
		rebirthCount = classState.rebirthCount,
		weapon = {
			gradeId = ArmorData.gradeOrder[weapon.grade + 1],
			level = weapon.level,
			gems = gems,
		},
		equipment = equipment,
	}
end

-- 요청 하나. 반환 { ok = true, data = 스냅샷 } | { ok = false, reason }. reason: rate_limited · bad_request · not_in_server · no_class.
-- now는 검증이 시간을 주입할 때만 쓴다(기본 os.clock()).
function PlayerInspect.handle(requester, targetUserId, now)
	now = now or os.clock()
	local last = lastRequestAt[requester]
	if last and now - last < SocialData.inspect.minIntervalSeconds then
		return { ok = false, reason = "rate_limited" }
	end
	lastRequestAt[requester] = now

	if type(targetUserId) ~= "number" or targetUserId ~= targetUserId or targetUserId % 1 ~= 0 then
		return { ok = false, reason = "bad_request" }
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target or target.Parent ~= Players then
		return { ok = false, reason = "not_in_server" } -- 다른 서버 · 없는 id · 나간 사람
	end
	local profile = PlayerProfile.getProfile(target)
	local classState = profile and profile.classId and profile.classes[profile.classId]
	if not classState then
		return { ok = false, reason = "no_class" } -- 프로필 로드 전 · 직업 미선택
	end
	return {
		ok = true,
		data = PlayerInspect.buildSnapshot({
			userId = target.UserId,
			name = target.Name,
			displayName = target.DisplayName,
			classId = profile.classId,
			classState = classState,
		}),
	}
end

remote.OnServerInvoke = function(requester, targetUserId)
	return PlayerInspect.handle(requester, targetUserId)
end

return PlayerInspect
