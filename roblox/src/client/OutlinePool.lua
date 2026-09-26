-- A1 외곽선 풀(클라 전용). Highlight는 Enabled = false여도 동시 255 슬롯을 차지한다(사용자 전제) → 대상마다 미리 만들어 두지 않고,
-- 가까운 순 · 우선순위로 고른 상위 maxActive개에만 풀의 Highlight를 옮겨 단다(Adornee 교체). 남는 것은 spare개만 남기고 지운다(슬롯 반환).
-- 대상당 동시 1개: 조준(AimTarget)도 같은 풀 - 조준 대상은 우선순위 0 · 색만 조준색으로(옛 몬스터마다 꺼진 AimHighlight 120개 = 슬롯 120 점유를 없앴다).
-- 카툰 프로필(Workspace Attribute CartoonStyle의 outline.enabled)에서만 어두운 외곽선을 달고, base에서는 조준 외곽선만(옛 동작과 같다).
-- 수치 · 색 = CartoonStyleData.outline. 후보 = 플레이어 캐릭터 · 태그 Monster(보스 = Attribute BossName · 아레나 장애물 제외) · 태그 OutlineTarget(관문 · NPC · 둥지).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)

local OutlinePool = {}

local O = CartoonStyleData.outline
local player = Players.LocalPlayer

local folder = nil
local assigned = {} -- [model] = Highlight
local free = {} -- 쓰지 않는 Highlight(spare개까지 보관)
local aimModel, aimColor = nil, nil
local partyUserIds = {} -- [userId] = true
local lastSelected = 0

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function ensureFolder()
	if folder and folder.Parent then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "OutlinePool"
	folder.Parent = workspace.CurrentCamera -- 이 클라만(복제 안 됨)
	return folder
end

local function takeHighlight()
	local h = table.remove(free)
	if h then
		return h
	end
	h = Instance.new("Highlight")
	h.Name = "PooledOutline"
	h.FillTransparency = O.fillTransparency
	h.OutlineTransparency = O.outlineTransparency
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = ensureFolder()
	return h
end

local function release(h)
	h.Adornee = nil
	if #free < O.spare then
		table.insert(free, h)
	else
		h:Destroy() -- 슬롯 반환
	end
end

function OutlinePool.setParty(userIds)
	partyUserIds = userIds or {}
end

-- 조준 대상 · 색(nil = 조준 없음). AimTarget이 대상이 바뀌거나 강공격 준비 색이 바뀔 때 부른다.
function OutlinePool.setAim(model, color)
	aimModel, aimColor = model, color
	OutlinePool.update()
end

local function enabledNow()
	local profile = CartoonStyleData.profiles[workspace:GetAttribute("CartoonStyle") or "base"]
	return profile ~= nil and profile.outline.enabled
end

-- 후보 목록(순수에 가깝게 - 검증이 가짜 후보로도 부른다): { model, priority, distance, isAim }
function OutlinePool.collect(cameraPosition, extra)
	local cats = O.categories
	local list = {}
	local seen = {}
	local function add(model, cat, isAim)
		if not model or seen[model] or not model.Parent then
			return
		end
		local pivot = model:IsA("Model") and model:GetPivot().Position or model.Position
		local distance = (pivot - cameraPosition).Magnitude
		if distance <= cat.distance then
			seen[model] = true
			table.insert(list, { model = model, priority = cat.priority, distance = distance, isAim = isAim })
		end
	end
	add(aimModel, cats.aim, true)
	if enabledNow() then
		for _, other in ipairs(Players:GetPlayers()) do
			local character = other.Character
			if other == player then
				add(character, cats.self)
			elseif partyUserIds[other.UserId] then
				add(character, cats.party)
			else
				add(character, cats.player)
			end
		end
		for _, model in ipairs(CollectionService:GetTagged("Monster")) do
			if not CollectionService:HasTag(model, "ArenaObstacle") then
				add(model, model:GetAttribute("BossName") and cats.boss or cats.monster)
			end
		end
		for _, model in ipairs(CollectionService:GetTagged(O.tag)) do
			add(model, cats.interact)
		end
	end
	for _, item in ipairs(extra or {}) do
		add(item.model, cats[item.category])
	end
	table.sort(list, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority
		end
		return a.distance < b.distance
	end)
	return list
end

function OutlinePool.update(extra)
	local list = OutlinePool.collect(workspace.CurrentCamera.CFrame.Position, extra)
	local selected = {}
	local count = math.min(#list, O.maxActive)
	for i = 1, count do
		selected[list[i].model] = list[i]
	end
	for model, h in pairs(assigned) do
		if not selected[model] then
			assigned[model] = nil
			release(h)
		end
	end
	for model, item in pairs(selected) do
		local h = assigned[model]
		if not h then
			h = takeHighlight()
			assigned[model] = h
		end
		h.Adornee = model
		h.OutlineColor = item.isAim and (aimColor or rgb(O.aimColor)) or rgb(O.color)
		h.Enabled = true
	end
	lastSelected = count
	return count, #list
end

-- 검증 · 보고: 지금 풀이 가진 Highlight 수(할당 + 보관) · 할당 수
function OutlinePool.stats()
	local n = 0
	for _ in pairs(assigned) do
		n += 1
	end
	return { assigned = n, spare = #free, selected = lastSelected }
end

function OutlinePool.start()
	local partyChanged = ReplicatedStorage:WaitForChild("PartyStateChanged", 10)
	if partyChanged then
		partyChanged.OnClientEvent:Connect(function(state)
			local ids = {}
			for _, member in ipairs(state and state.members or {}) do
				if member.userId then
					ids[member.userId] = true
				end
			end
			OutlinePool.setParty(ids)
		end)
	end
	task.spawn(function()
		while true do
			OutlinePool.update()
			task.wait(O.tickSeconds)
		end
	end)
end

return OutlinePool
