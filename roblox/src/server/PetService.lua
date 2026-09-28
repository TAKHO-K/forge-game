-- QUEUE-10h Q11 펫 서버(판정 · 부화 · 데리고 다니기 = 서버 · 모습 = 클라 PetView). 규칙 = shared/Pet.lua · 데이터 = PetData · EggData.
--   Remote: PetRequest(action, a) - "view" · "hatch"(알 가방 번호) · "claim"(대기열 번호) · "equip"(펫 번호 | nil = 내려놓기) / PetSync(서버 → 클라: 화면 표)
--   데리고 다니는 펫 = Player Attribute PetSpecies · PetBody · PetZone · PetGrade(모든 클라가 그 사람 옆에 그린다 - 서버는 위치를 보내지 않는다).
--   자동 줍기(캐릭터 레벨 PetData.unlocks.autoPickup 이상 + 펫 동행) = ItemDropServer가 PetService.pickupRange로 반경만 넓힌다(줍기 · 칸 확인 · 바닥 제거는 그쪽 한 곳).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Pet = require(ReplicatedStorage.Shared.Pet)
local PetData = require(ReplicatedStorage.Shared.data.PetData)
local EggData = require(ReplicatedStorage.Shared.data.EggData)
local PlayerProfile = require(script.Parent.PlayerProfile)

local PetService = {}

local syncRemote
local lastRequest = {}

local function applyAttributes(player, state)
	local pet = state and state.equipped and state.list[state.equipped]
	if typeof(player) ~= "Instance" then
		return
	end
	player:SetAttribute("PetSpecies", pet and pet.species or nil)
	player:SetAttribute("PetBody", pet and Pet.bodyOf(pet.species) or nil)
	player:SetAttribute("PetZone", pet and pet.zone or nil)
	player:SetAttribute("PetGrade", pet and pet.grade or nil)
end

function PetService.view(player)
	local state = PlayerProfile.getPetState(player)
	if not state then
		return nil
	end
	local level = PlayerProfile.getCharacterLevel(player) or 1
	local pets = {}
	for i, p in ipairs(state.list) do
		table.insert(pets, { index = i, species = p.species, name = EggData.species[p.species] or p.species, body = Pet.bodyOf(p.species), grade = p.grade, zone = p.zone, equipped = state.equipped == i })
	end
	local hatching = {}
	for i, h in ipairs(state.hatching) do
		table.insert(hatching, { index = i, zone = h.egg.zone, grade = h.egg.grade, doneAt = h.doneAt })
	end
	return {
		unix = os.time(),
		pets = pets,
		hatching = hatching,
		queueCap = Pet.queueCap(level),
		hatchCount = state.hatchCount,
		hatchLevel = Pet.levelOf(state.hatchCount),
		autoPickup = Pet.unlocked(level, "autoPickup"),
		unlocks = PetData.unlocks,
		petCap = PetData.petCap,
	}
end

local function push(player)
	if syncRemote and typeof(player) == "Instance" then
		syncRemote:FireClient(player, PetService.view(player))
	end
end

-- 부화 시작: 알 가방 index번 알 → 대기열(대기열이 가득이면 거절 - 알은 가방에 그대로)
function PetService.hatch(player, index)
	local state = PlayerProfile.getPetState(player)
	if not PetData.enabled or not state then
		return false, "off"
	end
	if #state.hatching >= Pet.queueCap(PlayerProfile.getCharacterLevel(player) or 1) then
		return false, "queue_full"
	end
	local egg = PlayerProfile.takeEgg(player, index)
	if not egg then
		return false, "no_egg"
	end
	table.insert(state.hatching, { egg = egg, doneAt = os.time() + (PetData.hatchSeconds[egg.grade] or PetData.hatchSeconds.normal) })
	print(("[Q11] 부화 시작: %s %s %s알 → %d초"):format(player.Name, tostring(egg.zone), tostring(egg.grade), PetData.hatchSeconds[egg.grade] or PetData.hatchSeconds.normal))
	require(script.Parent.NestServer).sync(player) -- 알 가방 화면
	push(player)
	return true
end

-- 부화 받기: 시간이 다 된 대기열 index번 → 펫(보관 상한이면 거절 - 알은 대기열에 남는다)
function PetService.claim(player, index, rng)
	local state = PlayerProfile.getPetState(player)
	local h = state and type(index) == "number" and state.hatching[index]
	if not h then
		return false, "no_hatch"
	end
	if os.time() < h.doneAt then
		return false, "not_ready"
	end
	if #state.list >= PetData.petCap then
		return false, "pet_full"
	end
	local pet = Pet.rollHatch(h.egg, Pet.levelOf(state.hatchCount), rng or Random.new())
	pet.at = os.time()
	table.remove(state.hatching, index)
	table.insert(state.list, pet)
	state.hatchCount += 1
	if not state.equipped then
		state.equipped = #state.list -- 첫 펫은 바로 데리고 다닌다
		applyAttributes(player, state)
	end
	print(("[Q11] 부화: %s → %s(%s · %s) · 누적 %d(부화 레벨 %d)"):format(player.Name, tostring(EggData.species[pet.species]), Pet.bodyOf(pet.species), pet.grade, state.hatchCount, Pet.levelOf(state.hatchCount)))
	require(script.Parent.ImmediateSave).request(player)
	push(player)
	return true, pet
end

function PetService.equip(player, index)
	local state = PlayerProfile.getPetState(player)
	if not state then
		return false
	end
	if index ~= nil and not (type(index) == "number" and state.list[index]) then
		return false
	end
	state.equipped = index
	applyAttributes(player, state)
	push(player)
	return true
end

-- 자동 줍기 반경(ItemDropServer) - 0 = 평소 줍기만
function PetService.pickupRange(player)
	local state = PlayerProfile.getPetState(player)
	if not PetData.enabled or not state or not state.equipped then
		return 0, 0
	end
	if not Pet.unlocked(PlayerProfile.getCharacterLevel(player) or 1, "autoPickup") then
		return 0, 0
	end
	return PetData.autoPickupRange, PetData.autoPickupHeight
end

function PetService.onLoaded(player)
	local state = PlayerProfile.getPetState(player)
	if state then
		if state.equipped and not state.list[state.equipped] then
			state.equipped = nil
		end
		applyAttributes(player, state)
		push(player)
	end
end

function PetService.start()
	local remote = ReplicatedStorage:FindFirstChild("PetRequest") or Instance.new("RemoteEvent")
	remote.Name = "PetRequest"
	remote.Parent = ReplicatedStorage
	syncRemote = ReplicatedStorage:FindFirstChild("PetSync") or Instance.new("RemoteEvent")
	syncRemote.Name = "PetSync"
	syncRemote.Parent = ReplicatedStorage
	remote.OnServerEvent:Connect(function(player, action, a)
		local now = os.clock()
		local key = tostring(action)
		lastRequest[player] = lastRequest[player] or {}
		if lastRequest[player][key] and now - lastRequest[player][key] < 0.2 then
			return
		end
		lastRequest[player][key] = now
		if action == "view" then
			push(player)
		elseif action == "hatch" and type(a) == "number" then
			PetService.hatch(player, math.floor(a))
		elseif action == "claim" and type(a) == "number" then
			PetService.claim(player, math.floor(a))
		elseif action == "equip" and (a == nil or type(a) == "number") then
			PetService.equip(player, a and math.floor(a) or nil)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return PetService
