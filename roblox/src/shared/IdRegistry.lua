-- QUEUE-ALL5 A3 출시 뒤 id 삭제 금지 · 안전 로드: 저장에 남는 데이터 id의 "지금 목록"을 한 곳에서 만든다(순수 - 데이터 모듈만 읽음).
--   쓰는 곳: server/SaveSystem.quarantineUnknownIds(로드 때 모르는 id = 계정 로드 실패 대신 보관 칸으로) ·
--            roblox/tools/ids/id_registry.py(스냅숏 docs/design/id-registry.md · roblox/tools/ids/id_registry_snapshot.json 대비 사라진 id = 실패).
--   종류(저장 자리): option(장비 · 보석 option.id) · material(materials 키) · grade · part · setZone · skillVariant · special(장비 · 아이템 몸) ·
--   cosmeticTheme(cosmetics.themes 키 · equipped 값) · gliderSkin(cosmetics.gliderSkins 키 · equipped.gliderSkin) · title(titles 키 · codex.title).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local OptionData = require(ReplicatedStorage.Shared.data.OptionData)
local EnhanceMaterialData = require(ReplicatedStorage.Shared.data.EnhanceMaterialData)
local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
local SetData = require(ReplicatedStorage.Shared.data.SetData)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local SkillVariantData = require(ReplicatedStorage.Shared.data.SkillVariantData)
local TranscendentData = require(ReplicatedStorage.Shared.data.TranscendentData)
local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local TitleData = require(ReplicatedStorage.Shared.data.TitleData)

local IdRegistry = {}

IdRegistry.kinds = { "option", "material", "grade", "part", "setZone", "skillVariant", "special", "cosmeticTheme", "gliderSkin", "title", "cosmeticItem", "protectionTicket" } -- QUEUE-ALL6 H cosmeticItem · QUEUE-ALL9B G protectionTicket
-- QUEUE-ALL9B G(사용자 10-03): 비활성 id - 데이터 · 저장 키는 남기고 얻는 길 · 표시만 뺐다(방지권 폐지 → 강화 창 방지 옵션 · 보유분 골드 환산 SAVE v68).
IdRegistry.retired = { protectionTicket = { drop = true, reset = true } }

local function keysOf(map)
	local out = {}
	for k in pairs(map) do
		table.insert(out, tostring(k))
	end
	return out
end

-- 반환: { [종류] = { id 문자열, ... }(정렬) }
function IdRegistry.lists()
	local zones = {}
	for _, z in ipairs(WorldMapData.zones) do
		table.insert(zones, z.key)
	end
	local themes, gliders = {}, {}
	for _, s in ipairs(CosmeticSlotData.sets) do
		table.insert(themes, s.id)
	end
	for _, g in ipairs(CosmeticSlotData.gliderSkins) do
		table.insert(gliders, g.id)
	end
	local items = {}
	for _, it in ipairs(CosmeticSlotData.items or {}) do
		table.insert(items, it.id)
	end
	local lists = {
		option = keysOf(OptionData.options),
		material = table.clone(EnhanceMaterialData.order),
		grade = table.clone(ArmorData.gradeOrder),
		part = table.clone(SetData.parts),
		setZone = zones,
		skillVariant = keysOf(SkillVariantData.templates),
		special = keysOf(TranscendentData.specialNames),
		cosmeticTheme = themes,
		gliderSkin = gliders,
		cosmeticItem = items,
		title = keysOf(TitleData.titles),
		protectionTicket = { "drop", "reset" }, -- purchases.protectionTickets 키(비활성 - IdRegistry.retired)
	}
	for _, list in pairs(lists) do
		table.sort(list)
	end
	return lists
end

local cached = nil
-- 반환: { [종류] = { [id] = true } }
function IdRegistry.known()
	if not cached then
		cached = {}
		for kind, list in pairs(IdRegistry.lists()) do
			local set = {}
			for _, id in ipairs(list) do
				set[id] = true
			end
			cached[kind] = set
		end
	end
	return cached
end
-- 데이터 표를 바꾼 뒤 다시 읽게(하네스가 "지운 id가 다시 생김"을 흉내 낼 때만 - 게임은 데이터가 실행 중 안 바뀐다)
function IdRegistry.reset()
	cached = nil
end

-- 장비(가방 · 착용) 한 개가 모르는 id를 가졌나. 반환: 첫 문제 "종류:id" | nil
function IdRegistry.unknownInItem(item)
	local k = IdRegistry.known()
	if type(item) ~= "table" then
		return nil
	end
	if type(item.option) == "table" and not k.option[tostring(item.option.id)] then
		return "option:" .. tostring(item.option.id)
	end
	if item.grade ~= nil and not k.grade[tostring(item.grade)] then
		return "grade:" .. tostring(item.grade)
	end
	if item.part ~= nil and not k.part[tostring(item.part)] then
		return "part:" .. tostring(item.part)
	end
	-- setZone(세트 계열)은 보지 않는다: 모르는 구역이면 SetBonus가 "세트 아님"으로 다뤄 장비는 그대로 쓸 수 있다(보관하면 오히려 손해) - 삭제 금지 검사(스냅숏)만 한다
	if type(item.skillVariant) == "table" and not k.skillVariant[tostring(item.skillVariant.id)] then
		return "skillVariant:" .. tostring(item.skillVariant.id)
	end
	if item.special ~= nil and not k.special[tostring(item.special)] then
		return "special:" .. tostring(item.special)
	end
	return nil
end

-- 보석 한 개(옵션만 id). 반환: "option:id" | nil
function IdRegistry.unknownInGem(gem)
	if type(gem) == "table" and type(gem.option) == "table" and not IdRegistry.known().option[tostring(gem.option.id)] then
		return "option:" .. tostring(gem.option.id)
	end
	return nil
end

return IdRegistry
