-- QUEUE-B1 B2 치장(P4c 골격 - 서버 권위). 저장 = profile.cosmetics(v56) · 목록 = shared/data/CosmeticSlotData(sets · gliderSkins) · 가격 = MonetizationData.shardPrices.
--   테마 세트 1개 = 4칸(dashTrail · jumpFx · glideTrail · footstep) 해금 → 칸마다 산 세트 중 아무거나 섞어 장착. 글라이더 스킨 = 칸 하나(gliderSkin).
--   장착 결과 = Player Attribute "Cosmetic_<칸>"(세트 id · 없으면 nil = 기본 모습) - 클라 훅(CosmeticSlotData.slots[].hook)은 이 Attribute만 읽는다(외형 에셋은 A가 채움).
--   사는 법 = 반짝 조각(profile.quests.currencies.sparkleShard - QuestService가 쓰는 칸) 또는 로벅스 상품(MonetizationService가 grant로 부른다). **골드로는 못 산다.**
--   조각 새 출처(MonetizationData.shardSources): 나무 정거장 처음 오르기 · 비밀 둥지 도감 새 칸 · 칭호 새로 받음 - 지급은 QuestService.grant 한 곳(§7-6).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CosmeticSlotData = require(ReplicatedStorage.Shared.data.CosmeticSlotData)
local MonetizationData = require(ReplicatedStorage.Shared.data.MonetizationData)
local Monetization = require(ReplicatedStorage.Shared.Monetization)
local PlayerProfile = require(script.Parent.PlayerProfile)

local CosmeticService = {}

local SET_SLOTS = {}
for _, slot in ipairs(CosmeticSlotData.setSlots) do
	SET_SLOTS[slot] = true
end

local function questService()
	return require(script.Parent.QuestService) -- 늦은 require(QuestService → PlayerProfile 순환 방지)
end

local function state(player)
	return PlayerProfile.getMonetizationState(player)
end

function CosmeticService.shards(player)
	local quests = PlayerProfile.getQuestState(player)
	return quests and quests.currencies and quests.currencies.sparkleShard or 0
end

-- 반짝 조각 쓰기(모자라면 false). 증가는 QuestService.grant 한 곳 - 빼는 것만 여기.
local function spendShards(player, amount)
	local quests = PlayerProfile.getQuestState(player)
	if not quests or (quests.currencies.sparkleShard or 0) < amount then
		return false
	end
	quests.currencies.sparkleShard -= amount
	require(script.Parent.Telemetry).economy(player, "sparkleShard", "sink", amount, "Shop")
	return true
end

function CosmeticService.ownsTheme(player, id)
	local s = state(player)
	return s ~= nil and s.cosmetics.themes[id] == true
end
function CosmeticService.ownsGlider(player, id)
	local s = state(player)
	return s ~= nil and s.cosmetics.gliderSkins[id] == true
end

-- 장착 결과를 Attribute로(클라 훅이 읽는다)
function CosmeticService.applyAttributes(player)
	local s = state(player)
	if not s or typeof(player) ~= "Instance" then
		return
	end
	for _, slot in ipairs(CosmeticSlotData.slots) do
		player:SetAttribute("Cosmetic_" .. slot.id, s.cosmetics.equipped[slot.id])
	end
	local color = s.cosmetics.equipped.nameplateColor
	player:SetAttribute("NameplateColor", s.gamepasses.nameplateColor and color or nil)
	player:SetAttribute("NameplateBadge", s.gamepasses.nameplateBadge and s.cosmetics.equipped.nameplateBadge or nil) -- QUEUE-ALL1 P6 이름표 배지(패스 있을 때만)
end

-- 지급(상품 · 시즌 줄 · 선물 공통). 반환: 새로 얻었나, 이유. 이미 있으면 false("owned") - 멱등(영수증 재시도가 두 번 불러도 같다).
function CosmeticService.grant(player, kind, id)
	local s = state(player)
	if not s then
		return false, "no_profile"
	end
	if not Monetization.findCosmetic(CosmeticSlotData, kind, id) then
		return false, "unknown"
	end
	local owned = kind == "cosmeticTheme" and s.cosmetics.themes or s.cosmetics.gliderSkins
	if owned[id] then
		return false, "owned"
	end
	owned[id] = true
	print(("[B2] 치장 지급: %s - %s %s"):format(player.Name, kind, id))
	return true
end

-- 반짝 조각으로 사기. 반환: ok, 이유
function CosmeticService.buyWithShards(player, kind, id)
	local price = kind == "cosmeticTheme" and MonetizationData.shardPrices.theme or kind == "gliderSkin" and MonetizationData.shardPrices.gliderSkin or nil
	if not price or not Monetization.findCosmetic(CosmeticSlotData, kind, id) then
		return false, "unknown"
	end
	if (kind == "cosmeticTheme" and CosmeticService.ownsTheme(player, id)) or (kind == "gliderSkin" and CosmeticService.ownsGlider(player, id)) then
		return false, "owned"
	end
	if not spendShards(player, price) then
		return false, "shards"
	end
	CosmeticService.grant(player, kind, id)
	require(script.Parent.ImmediateSave).request(player)
	return true
end

-- 장착: slot = CosmeticSlotData 칸 id · id = 세트 id(gliderSkin 칸은 스킨 id) · nil = 기본 모습. 반환: ok, 이유
function CosmeticService.equip(player, slot, id)
	local s = state(player)
	if not s then
		return false, "no_profile"
	end
	if slot == "nameplateColor" then
		if not s.gamepasses.nameplateColor then
			return false, "no_pass"
		end
		if id ~= nil and not table.find(MonetizationData.gamePasses.nameplateColor.colors, id) then
			return false, "unknown"
		end
	elseif slot == "nameplateBadge" then -- QUEUE-ALL1 P6
		if not s.gamepasses.nameplateBadge then
			return false, "no_pass"
		end
		if id ~= nil and not table.find(MonetizationData.gamePasses.nameplateBadge.badges, id) then
			return false, "unknown"
		end
	elseif SET_SLOTS[slot] then
		if id ~= nil and not s.cosmetics.themes[id] then
			return false, "not_owned"
		end
	elseif slot == "gliderSkin" then
		if id ~= nil and not s.cosmetics.gliderSkins[id] then
			return false, "not_owned"
		end
	else
		return false, "bad_slot"
	end
	s.cosmetics.equipped[slot] = id
	CosmeticService.applyAttributes(player)
	require(script.Parent.ImmediateSave).request(player)
	return true
end

-- ── 조각 새 출처(한 번씩) ──
local function awardShards(player, amount, why)
	if amount and amount > 0 then
		local summary = questService().grant(player, { sparkleShard = amount })
		print(("[B2] 반짝 조각 출처: %s - %s → %s"):format(player.Name, why, summary))
	end
end

-- 나무 정거장에 처음 올라섬(Travel이 부른다). viaTeleport = 리프트 · 순간이동 도착(오르기가 아니라 제외)
function CosmeticService.onTreeStation(player, stationIndex, viaTeleport)
	local s = state(player)
	if not s or viaTeleport or type(stationIndex) ~= "number" then
		return false
	end
	local key = tostring(stationIndex) -- DataStore 왕복 = 문자열 키(메모리: 숫자 키 집합)
	if s.cosmetics.treeStations[key] then
		return false
	end
	s.cosmetics.treeStations[key] = true
	awardShards(player, MonetizationData.shardSources.treeStation, "나무 정거장 " .. key)
	require(script.Parent.ImmediateSave).request(player)
	return true
end

function CosmeticService.onNestDex(player, nestId)
	awardShards(player, MonetizationData.shardSources.nestDex, "비밀 둥지 도감 " .. tostring(nestId))
end

function CosmeticService.onTitle(player, titleId)
	awardShards(player, MonetizationData.shardSources.title, "칭호 " .. tostring(titleId))
end

function CosmeticService.onLoaded(player)
	CosmeticService.applyAttributes(player)
end

return CosmeticService
