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
	local t0 = os.clock()
	local ok, failed, running = 0, {}, 0
	local nextIndex = 1
	local function worker()
		while nextIndex <= #queue do
			local item = queue[nextIndex]
			nextIndex += 1
			local success, result = pcall(InsertService.LoadAsset, InsertService, item.id)
			local model = success and result and result:FindFirstChildWhichIsA("Model")
			if model then
				model.Name = item.key
				ArtMeshKit.normalize(model)
				model.Parent = folder
				result:Destroy()
				ok += 1
			else
				table.insert(failed, item.key)
			end
		end
		running -= 1
	end
	for _ = 1, math.min(Data.loadConcurrency, #queue) do
		running += 1
		task.spawn(worker)
	end
	while running > 0 do
		task.wait(0.1)
	end
	folder:SetAttribute("Loaded", ok)
	folder:SetAttribute(Data.readyAttribute, true)
	print(("[ArtAssetLoader] 메시 캐시 %d/%d · %.1f초"):format(ok, #queue, os.clock() - t0))
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
