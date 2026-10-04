-- QUEUE-MENU2 B 캐릭터 칸 저장 - 순수 함수(DataStore 호출 없음 · 하네스가 그대로 부른다). 키 읽기 · 쓰기 = SaveSystem.
--   메모리 안 프로필 = 옛 단일 프로필 모양 그대로 → 저장 때 split(계정 shared + 캐릭터 data) · 읽을 때 compose. 설계 = docs/design/menu2-slot-save.md.
--   account = { slotVersion, slots = { [칸] = 요약 | false }, archive = { 요약 }, lastSlot, nextCharId, shared, migratedAt, legacy }
--   요약 = { charId, classId, createdAt, lastPlayedAt, level, stage, best, rebirth, weaponGrade, weaponLevel, transcend, playSeconds }
--   character = { charId, classId, data = { <characterTop 필드>, nested = { ["부모.키"] = 값 }, classState } }
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local D = require(ReplicatedStorage.Shared.data.SlotSaveData)
local ClassData = require(ReplicatedStorage.Shared.data.ClassData)
local CharacterLevel = require(ReplicatedStorage.Shared.CharacterLevel)

local SlotSave = {}
SlotSave.data = D

local CHAR_TOP = {}
for _, k in ipairs(D.characterTop) do
	CHAR_TOP[k] = true
end
local META = { classes = true, classId = true, version = true, savedAt = true, sessionId = true }

local function deepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in pairs(v) do
		out[deepCopy(k)] = deepCopy(x)
	end
	return out
end
SlotSave.deepCopy = deepCopy

function SlotSave.slotCount()
	return #ClassData.order -- 출시 직업 수(신직업 데이터 추가 = 칸 +1)
end

-- 계정 공유 부분(캐릭터 필드 · 직업 칸 · 메타를 뺀 나머지 전부)
function SlotSave.extractShared(profile)
	local shared = {}
	for k, v in pairs(profile) do
		if not CHAR_TOP[k] and not META[k] then
			shared[k] = deepCopy(v)
		end
	end
	for _, pair in ipairs(D.characterNested) do
		if type(shared[pair[1]]) == "table" then
			shared[pair[1]][pair[2]] = nil
		end
	end
	return shared
end

-- 캐릭터 부분(classId 직업 칸 + 캐릭터 필드)
function SlotSave.extractCharacter(profile, classId)
	local data = { nested = {} }
	for _, k in ipairs(D.characterTop) do
		data[k] = deepCopy(profile[k])
	end
	for _, pair in ipairs(D.characterNested) do
		local parent = profile[pair[1]]
		if type(parent) == "table" and parent[pair[2]] ~= nil then
			data.nested[pair[1] .. "." .. pair[2]] = deepCopy(parent[pair[2]])
		end
	end
	data.classState = deepCopy(profile.classes and profile.classes[classId])
	return data
end

-- 합치기: base = SaveSystem.defaultProfile()(새 표 - 여기서 채운다) · character = nil이면 캐릭터 없음(classId nil - 직업 선택 = 새 캐릭터)
function SlotSave.compose(base, shared, character)
	local p = base
	for k, v in pairs(shared or {}) do
		p[k] = deepCopy(v)
	end
	if character then
		local data = character.data or {}
		for _, k in ipairs(D.characterTop) do
			if data[k] ~= nil then
				p[k] = deepCopy(data[k])
			end
		end
		for key, v in pairs(data.nested or {}) do
			local parent, sub = key:match("^([^%.]+)%.(.+)$")
			if parent then
				if type(p[parent]) ~= "table" then
					p[parent] = {}
				end
				p[parent][sub] = deepCopy(v)
			end
		end
		if type(data.classState) == "table" and p.classes then
			p.classes[character.classId] = deepCopy(data.classState)
		end
		p.classId = character.classId
	else
		p.classId = nil
	end
	if type(p.quests) == "table" then -- 메인 퀘스트 사슬 = 캐릭터별(새 캐릭터 = 처음부터 · Quest.newState와 같은 시작값)
		p.quests.main = p.quests.main or 1
		p.quests.mainN = p.quests.mainN or 0
	end
	return p
end

-- 직업 칸에 진행이 있는가(이관 때 캐릭터로 만들지)
function SlotSave.hasProgress(cs)
	if type(cs) ~= "table" then
		return false
	end
	local sp = type(cs.stageProgress) == "table" and cs.stageProgress or {}
	local w = type(cs.weapon) == "table" and cs.weapon or {}
	local eq = type(cs.equipment) == "table" and cs.equipment or {}
	if (tonumber(cs.characterExp) or 0) > 0 or (tonumber(sp.infiniteBest) or 1) > 1 or (tonumber(cs.rebirthCount) or 0) > 0 then
		return true
	end
	if (tonumber(w.level) or 0) > 0 or (tonumber(w.grade) or 0) > 0 then
		return true
	end
	if eq.armor or eq.gloves or eq.shoes then
		return true
	end
	if type(cs.gemInventory) == "table" and #cs.gemInventory > 0 then
		return true
	end
	return false
end

-- 칸 요약(메뉴 카드 · 순위) - 캐릭터 키를 다 읽지 않고 메뉴를 그리게 계정 키에 복사해 둔다
function SlotSave.summarize(character, now, prev)
	local cs = character.data and character.data.classState or {}
	local sp = type(cs.stageProgress) == "table" and cs.stageProgress or {}
	local w = type(cs.weapon) == "table" and cs.weapon or {}
	return {
		charId = character.charId,
		classId = character.classId,
		createdAt = prev and prev.createdAt or now,
		lastPlayedAt = prev and prev.lastPlayedAt or now,
		level = CharacterLevel.getLevelFromExp(tonumber(cs.characterExp) or 0),
		stage = tonumber(sp.infinite) or 1,
		best = tonumber(sp.infiniteBest) or 1,
		rebirth = tonumber(cs.rebirthCount) or 0,
		weaponGrade = tonumber(w.grade) or 0,
		weaponLevel = tonumber(w.level) or 0,
		transcend = type(w.transcend) == "table" and tonumber(w.transcend.level) or nil,
		playSeconds = tonumber(cs.playSeconds) or 0,
	}
end

-- 새 계정 기록(캐릭터 없음)
function SlotSave.newAccount(shared, now)
	local slots = {}
	for i = 1, SlotSave.slotCount() do
		slots[i] = false
	end
	return { slotVersion = 1, slots = slots, archive = {}, lastSlot = nil, nextCharId = 1, shared = shared, migratedAt = now }
end

-- 옛 단일 프로필(이관 끝난 모양) → 계정 + 캐릭터 목록. defaults = SaveSystem.defaultProfile()(다른 캐릭터의 재화 기본값)
function SlotSave.splitLegacy(profile, defaults, now)
	local account = SlotSave.newAccount(SlotSave.extractShared(profile), now)
	account.legacy = { savedAt = profile.savedAt, version = profile.version, migratedAt = now }
	local order = {}
	if profile.classId and profile.classes and profile.classes[profile.classId] then
		table.insert(order, profile.classId)
	end
	for _, classId in ipairs(ClassData.order) do
		if classId ~= profile.classId and profile.classes and SlotSave.hasProgress(profile.classes[classId]) then
			table.insert(order, classId)
		end
	end
	local characters = {}
	local made = {}
	for i, classId in ipairs(order) do
		if i > SlotSave.slotCount() then
			break
		end
		local data = SlotSave.extractCharacter(profile, classId)
		if classId ~= profile.classId then
			for _, k in ipairs(D.characterTop) do
				if not D.copyToAllOnMigrate[k] then
					data[k] = deepCopy(defaults[k])
				end
			end
			data.nested = {}
		end
		local ch = { charId = account.nextCharId, classId = classId, data = data }
		account.nextCharId += 1
		characters[i] = ch
		made[classId] = ch
	end
	-- 초월 보석: 박힌 직업 캐릭터로 · 안 박힌 것 · 캐릭터가 없는 직업에 박힌 것 = 첫 캐릭터(지금 직업)
	local tg = profile.transcendGems
	if type(tg) == "table" and type(tg.list) == "table" and #characters > 0 then
		for _, ch in ipairs(characters) do
			ch.data.transcendGems = { list = {}, seq = tg.seq or 0 }
		end
		for _, gem in ipairs(tg.list) do
			local owner = type(gem.socket) == "table" and made[gem.socket.classId] or characters[1]
			table.insert(owner.data.transcendGems.list, deepCopy(gem))
		end
	end
	for i, ch in ipairs(characters) do
		account.slots[i] = SlotSave.summarize(ch, now)
	end
	account.lastSlot = #characters > 0 and 1 or nil
	return account, characters
end

-- 스위치 끔(손실 0): 계정 + 모든 캐릭터 → 옛 모양 한 프로필. lastCharId = 지금 직업이 될 캐릭터
function SlotSave.mergeToLegacy(base, account, characters, lastCharId)
	local p = SlotSave.compose(base, account.shared, nil)
	local best = {}
	local last = nil
	local function score(cs)
		local sp = type(cs) == "table" and type(cs.stageProgress) == "table" and cs.stageProgress or {}
		return (tonumber(cs and cs.characterExp) or 0) + (tonumber(sp.infiniteBest) or 0) * 1e9
	end
	p.gold, p.gemDust, p.inventory = 0, 0, {}
	p.transcendGems = { list = {}, seq = 0 }
	for _, ch in ipairs(characters) do
		local d = ch.data or {}
		p.gold += tonumber(d.gold) or 0
		p.gemDust += tonumber(d.gemDust) or 0
		for _, item in ipairs(type(d.inventory) == "table" and d.inventory or {}) do
			table.insert(p.inventory, deepCopy(item))
		end
		if type(d.materials) == "table" then
			for k, v in pairs(d.materials) do
				if type(v) == "number" then
					p.materials[k] = (tonumber(p.materials[k]) or 0) + v
				end
			end
		end
		if type(d.training) == "table" then
			for k, v in pairs(d.training) do
				if type(v) == "number" and v > (tonumber(p.training[k]) or 0) then
					p.training[k] = v
				end
			end
		end
		if type(d.transcendGems) == "table" then
			for _, g in ipairs(d.transcendGems.list or {}) do
				table.insert(p.transcendGems.list, deepCopy(g))
			end
			p.transcendGems.seq = math.max(p.transcendGems.seq, tonumber(d.transcendGems.seq) or 0)
		end
		local rr = d.nested and d.nested["purchases.optionRerollTickets"]
		if type(rr) == "table" and type(p.purchases) == "table" then
			p.purchases.optionRerollTickets = p.purchases.optionRerollTickets or {}
			for k, v in pairs(rr) do
				if type(v) == "number" then
					p.purchases.optionRerollTickets[k] = (tonumber(p.purchases.optionRerollTickets[k]) or 0) + v
				end
			end
		end
		if ch.classId and type(d.classState) == "table" and (not best[ch.classId] or score(d.classState) > score(best[ch.classId])) then
			best[ch.classId] = d.classState
		end
		if ch.charId == lastCharId then
			last = ch
		end
	end
	for classId, cs in pairs(best) do
		p.classes[classId] = deepCopy(cs)
	end
	last = last or characters[1]
	if last then
		for key, v in pairs(last.data and last.data.nested or {}) do
			local parent, sub = key:match("^([^%.]+)%.(.+)$")
			if parent and key ~= "purchases.optionRerollTickets" then
				p[parent] = type(p[parent]) == "table" and p[parent] or {}
				p[parent][sub] = deepCopy(v)
			end
		end
		p.classId = last.classId
	end
	return p
end

-- 칸 찾기 · 다음 번호(같은 직업 = ① ② …)
function SlotSave.slotOfChar(account, charId)
	for i, s in ipairs(account.slots or {}) do
		if s and s.charId == charId then
			return i
		end
	end
	return nil
end

function SlotSave.freeSlot(account)
	for i = 1, SlotSave.slotCount() do
		if not (account.slots and account.slots[i]) then
			return i
		end
	end
	return nil
end

-- 새 캐릭터 칸 잡기(직업 선택 순간) → 칸 번호 · 캐릭터 번호 | nil, "full"
function SlotSave.claimSlot(account, classId, now)
	local slot = SlotSave.freeSlot(account)
	if not slot then
		return nil, "full"
	end
	local charId = account.nextCharId or 1
	account.nextCharId = charId + 1
	account.slots[slot] = { charId = charId, classId = classId, createdAt = now, lastPlayedAt = now, level = 1, stage = 1, best = 1, rebirth = 0, weaponGrade = 0, weaponLevel = 0, playSeconds = 0 }
	account.lastSlot = slot
	return slot, charId
end

-- 보관(삭제 대신): 칸에서 빼 보관함으로 | nil, 이유
function SlotSave.archiveSlot(account, slot)
	local s = account.slots and account.slots[slot]
	if not s then
		return nil, "empty"
	end
	if #(account.archive or {}) >= D.maxArchive then
		return nil, "archive_full"
	end
	account.archive = account.archive or {}
	table.insert(account.archive, s)
	account.slots[slot] = false
	if account.lastSlot == slot then
		account.lastSlot = nil
	end
	return true
end

-- 복구: 보관함 index → 빈 칸 | nil, 이유
function SlotSave.restoreArchived(account, index)
	local s = account.archive and account.archive[index]
	if not s then
		return nil, "missing"
	end
	local slot = SlotSave.freeSlot(account)
	if not slot then
		return nil, "full"
	end
	table.remove(account.archive, index)
	account.slots[slot] = s
	return slot
end

-- 같은 직업 번호(칸 순서 기준 - 만든 순서 createdAt) → 1, 2, …
function SlotSave.classNumber(account, slot)
	local s = account.slots[slot]
	if not s then
		return nil
	end
	local n = 0
	for i, o in ipairs(account.slots) do
		if o and o.classId == s.classId and ((o.createdAt or 0) < (s.createdAt or 0) or ((o.createdAt or 0) == (s.createdAt or 0) and i <= slot)) then
			n += 1
		end
	end
	return n
end

return SlotSave
