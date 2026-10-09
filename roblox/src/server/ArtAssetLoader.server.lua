-- A2-N3 Open Cloud 메시 로더: shared/data/ArtAssetIds(생성 파일)의 Model을 InsertService:LoadAsset으로 불러 ReplicatedStorage.ArtMeshCache.<키>에 둔다.
--   ArtStyleV1 스위치가 켜질 때만(개발 기본 켬 · 라이브 = ArtStyleV1Data.enabled). 로드 실패 · 심사 대기 = 그 키만 빠진다(쓰는 쪽이 지금 모델 그대로 - 경고 1줄).
--   가져온 모델은 shared/ArtMeshKit.normalize로 리그 공간(stud · 앞 −Z)으로 맞춘 뒤 캐시에 넣는다. 쓰는 곳 = MonsterSpawner(몬스터 · 보스) · WeaponVisual(무기).
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.ArtImportData)
local ArtAssetIds = require(ReplicatedStorage.Shared.data.ArtAssetIds)
local ArtStyleV1Data = require(ReplicatedStorage.Shared.data.ArtStyleV1Data)
local ArtMeshKit = require(ReplicatedStorage.Shared.ArtMeshKit)

local started = false

local function loadAll()
	if started then
		return
	end
	started = true
	local folder = ReplicatedStorage:FindFirstChild(Data.cacheFolder) or Instance.new("Folder")
	folder.Name = Data.cacheFolder
	folder.Parent = ReplicatedStorage
	local queue = {}
	for key, e in pairs(ArtAssetIds) do
		if e.kind == "Model" and e.status == "Approved" and not key:find("^weapons/paladin_") then
			table.insert(queue, { key = key, id = e.id })
		end
	end
	table.sort(queue, function(a, b)
		return a.key < b.key
	end)
	-- 1단계 = 소품(맵 · 제단이 부팅 때 기다린다) → PropsReady · 2단계 = 나머지
	local first, priority, rest = {}, {}, {}
	local V4 = require(ReplicatedStorage.Shared.data.WeaponV4Data)
	local function isPriority(key) -- 우선 순위(접두사 순서 · 없으면 nil)
		if V4.enabled and V4.priorityOnly and key:sub(1, 8) == "weapons/" and key:sub(1, #V4.prefix) ~= V4.prefix then
			return nil -- FINAL-1 2: v4가 켜져 있으면 옛 무기 메시(되돌림 예비)는 우선 묶음에서 빼 Ready_weapons를 앞당긴다
		end
		for i, prefix in ipairs(Data.priorityPrefixes or {}) do
			if key:sub(1, #prefix) == prefix then
				return i
			end
		end
		return nil
	end
	for _, item in ipairs(queue) do
		if item.key:sub(1, #Data.propsFirstPrefix) == Data.propsFirstPrefix then
			table.insert(first, item)
		else
			table.insert(isPriority(item.key) and priority or rest, item) -- FINAL-1 0: 무기 · 펫 · 보스 · 잡몹 먼저(서버 첫 순간 블록 몸)
		end
	end
	table.sort(priority, function(a, b)
		local pa, pb = isPriority(a.key), isPriority(b.key)
		if pa ~= pb then
			return pa < pb
		end
		return a.key < b.key
	end)
	local t0 = os.clock()
	local ok, failed, running = 0, {}, 0
	-- FINAL-1b 결정 5: 접속한 사람이 낀 v4 무기만 먼저(큐와 따로 1개씩) - 받은 키는 아래 큐가 건너뛴다
	local own = {} -- [키] = true(받는 중 · 받음)
	local function loadOwn(key)
		local e = key and ArtAssetIds[key]
		if not e or own[key] or folder:FindFirstChild(key) or e.kind ~= "Model" or e.status ~= "Approved" then
			return
		end
		own[key] = true
		local t = os.clock()
		local success, result = pcall(InsertService.LoadAsset, InsertService, e.id)
		local model = success and result and result:FindFirstChildWhichIsA("Model")
		if model and not folder:FindFirstChild(key) then
			model.Name = key
			ArtMeshKit.normalize(model)
			model.Parent = folder
			print(("[ArtAssetLoader] 낀 무기 먼저 %s · %.1f초(로더 시작 뒤 %.1f초)"):format(key, os.clock() - t, os.clock() - t0))
		end
		if success and result then
			result:Destroy()
		end
	end
	if Data.ownWeaponFirst and V4.enabled then
		local ArmorData = require(ReplicatedStorage.Shared.data.ArmorData)
		local function watch(player)
			local function go()
				local classId = player:GetAttribute("ClassId")
				local gradeId = ArmorData.gradeOrder[(player:GetAttribute("WeaponGrade") or 0) + 1]
				if type(classId) == "string" and classId ~= "" and gradeId then
					task.spawn(loadOwn, (V4.key(classId, gradeId)))
					task.spawn(loadOwn, (V4.key(classId, gradeId, true))) -- 쌍검 왼손(없는 키 = 건너뜀)
				end
			end
			player:GetAttributeChangedSignal("ClassId"):Connect(go)
			player:GetAttributeChangedSignal("WeaponGrade"):Connect(go)
			go()
		end
		local Players = game:GetService("Players")
		Players.PlayerAdded:Connect(watch)
		for _, player in ipairs(Players:GetPlayers()) do
			watch(player)
		end
	end
	local nextIndex = 1
	local function worker()
		while nextIndex <= #queue do
			local item = queue[nextIndex]
			nextIndex += 1
			if own[item.key] or folder:FindFirstChild(item.key) then
				ok += 1 -- FINAL-1b: 낀 무기 먼저 받은 키
				continue
			end
			local success, result = pcall(InsertService.LoadAsset, InsertService, item.id)
			local model = success and result and result:FindFirstChildWhichIsA("Model")
			if model then
				model.Name = item.key
				ArtMeshKit.normalize(model)
				model.Parent = folder
				result:Destroy()
				ok += 1
			else
				if success and result then
					result:Destroy()
				end
				table.insert(failed, item.key)
			end
		end
		running -= 1
	end
	local function runAll(list)
		queue, nextIndex = list, 1
		for _ = 1, math.min(Data.loadConcurrency, #queue) do
			running += 1
			task.spawn(worker)
		end
		while running > 0 do
			task.wait(0.05)
		end
	end
	runAll(first)
	folder:SetAttribute(Data.propsReadyAttribute, true)
	-- 소품 메시 입히기(맵 완성 신호 뒤 - 맵을 기다리게 하지 않는다): 킷 틀 소품 + 환생 제단 · 실패해도 2단계 · 준비 신호는 계속 간다
	task.spawn(function()
		local t = os.clock()
		while not workspace:GetAttribute(Data.mapBuiltAttribute) and os.clock() - t < 90 do
			task.wait(0.2)
		end
		local okSkin, err = pcall(function()
			local skinned = require(script.Parent.PropLibrary).applyArtMeshes()
			local altar = workspace:FindFirstChild("RebirthAltar")
			local frame = altar and altar:GetAttribute("ArtMeshFrame")
			if frame then
				ArtMeshKit.skin(altar, "props/rebirth_altar", frame)
			end
			print(("[ArtAssetLoader] 소품 메시 입힘 %d · 제단 %s"):format(skinned, tostring(altar and altar:GetAttribute("ArtMesh") ~= nil)))
		end)
		if not okSkin then
			warn("[ArtAssetLoader] 소품 메시 입히기 실패(지금 모습 그대로): " .. tostring(err))
		end
		-- QUEUE-ALL7B 3: 허브 건물 · NPC · 게시판 메시(server/HubArt) · FINAL-1 0: 소품 묶음(props/)만 쓰므로 전체 완료(약 50초) 대신 소품 직후
		local okHub, buildings, npcs = pcall(require(script.Parent.HubArt).apply)
		if okHub then
			print(("[ArtAssetLoader] 허브 건물 메시 %d · NPC %d"):format(buildings, npcs))
		else
			warn("[ArtAssetLoader] 허브 메시 실패(지금 모습 그대로): " .. tostring(buildings))
		end
	end)
	for i, prefix in ipairs(Data.priorityPrefixes or {}) do -- 접두사 묶음마다 받고 신호(Ready_weapons 등 - 클라 무기 · 펫이 바로 다시 짓는다)
		local group = {}
		for _, item in ipairs(priority) do
			if isPriority(item.key) == i then
				table.insert(group, item)
			end
		end
		runAll(group)
		folder:SetAttribute("Ready_" .. prefix:gsub("/", ""), true)
	end
	folder:SetAttribute(Data.priorityReadyAttribute, true)
	print(("[ArtAssetLoader] 우선 메시(무기 · 펫 · 보스 · 잡몹) %d개 · %.1f초"):format(#priority, os.clock() - t0))
	runAll(rest)
	folder:SetAttribute("Loaded", ok)
	folder:SetAttribute(Data.readyAttribute, true)
	-- A2-N4 §3-3(A2-N3 결정 ⑧): 관문 틀 메시 · 보스별 관문 장식(장식 = 2단계 extras라 전부 준비된 뒤)
	task.spawn(function()
		local t = os.clock()
		while not workspace:GetAttribute(Data.mapBuiltAttribute) and os.clock() - t < 90 do
			task.wait(0.2)
		end
		local okGate, frames, decors = pcall(require(script.Parent.BossGateArt).apply)
		if okGate then
			print(("[ArtAssetLoader] 관문 틀 메시 %d · 관문 장식 %d"):format(frames, decors))
		else
			warn("[ArtAssetLoader] 관문 메시 실패(지금 모습 그대로): " .. tostring(frames))
		end
	end)
	print(("[ArtAssetLoader] 메시 캐시 %d/%d(소품 %d 먼저) · %.1f초"):format(ok, #first + #priority + #rest, #first, os.clock() - t0))
	if #failed > 0 then
		warn(("[ArtAssetLoader] 로드 실패 %d개(지금 모델 그대로): %s"):format(#failed, table.concat(failed, ", ")))
	end
end

task.defer(function()
	if workspace:GetAttribute(ArtStyleV1Data.attribute) then
		loadAll()
	end
end)
workspace:GetAttributeChangedSignal(ArtStyleV1Data.attribute):Connect(function()
	if workspace:GetAttribute(ArtStyleV1Data.attribute) then
		loadAll()
	end
end)
