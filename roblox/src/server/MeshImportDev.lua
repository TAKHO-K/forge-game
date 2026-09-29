-- B3 메시 가져오기 개발 명령 본체(DevTools.server.lua의 "/gg mesh" 분기가 부른다 - 개발자 판정 = DevTools isAllowed · Studio 전용 그대로).
--   /gg mesh check <리그id> [모델경로]          - 검사기(shared/MeshImportCheck) 결과표를 출력 창에 줄마다([MeshCheck] …)
--   /gg mesh swap <리그id> [모델경로] [배율]    - 내 앞에 기준 자세 리그(BossRig.build)를 세우고 메시를 1:1로 끼운다(shared/MeshSwap) · 검사 결과도 같이
--   /gg mesh clear                              - 미리보기(Workspace.MeshPreview) 지움
--   모델경로 = 점으로 이은 경로(예: Workspace.moss_slime · ReplicatedStorage.Shared.MonsterModels.moss_slime). 생략하면
--     ReplicatedStorage.Shared.<MonsterModels | BossModels>.<리그id> → Workspace.<리그id> 순서로 찾는다.
--   Blender 메타(삼각형 수) = ReplicatedStorage.Shared.MeshMeta.<모델 이름>(ModuleScript) - 파트 Attribute TriCount가 없을 때 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MeshImportCheck = require(ReplicatedStorage.Shared.MeshImportCheck)
local MeshSwap = require(ReplicatedStorage.Shared.MeshSwap)
local BossRig = require(ReplicatedStorage.Shared.BossRig)

local MeshImportDev = {}

local USAGE = "/gg mesh check <리그id> [모델경로] | swap <리그id> [모델경로] [배율] | clear"

local function resolvePath(path)
	local node
	for seg in path:gmatch("[^%.]+") do
		if not node then
			node = game:FindFirstChild(seg)
			if not node then
				local ok, svc = pcall(game.GetService, game, seg)
				node = ok and svc or nil
			end
		else
			node = node:FindFirstChild(seg)
		end
		if not node then
			return nil
		end
	end
	return node
end

local function findModel(rigId, path, kind)
	if path then
		local m = resolvePath(path)
		return (m and m:IsA("Model")) and m or nil
	end
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild(Data.modelFolders[kind] or "")
	local m = folder and folder:FindFirstChild(rigId)
	if m and m:IsA("Model") then
		return m
	end
	m = workspace:FindFirstChild(rigId)
	return (m and m:IsA("Model")) and m or nil
end

local function metaFor(model)
	local shared = ReplicatedStorage:FindFirstChild("Shared")
	local folder = shared and shared:FindFirstChild(Data.metaFolder)
	local mod = folder and folder:FindFirstChild(model.Name)
	if mod and mod:IsA("ModuleScript") then
		local ok, meta = pcall(require, mod)
		if ok and type(meta) == "table" then
			return meta
		end
	end
	return nil
end

local function runCheck(model, rigId)
	local ok, lines = MeshImportCheck.check(MeshImportCheck.describe(model, { meta = metaFor(model) }), rigId, { scale = 1 })
	for _, line in ipairs(lines) do
		print(line)
	end
	return ok, lines[#lines]
end

local function buildPreview(player, rigId, scale)
	local rig = MeshImportCheck.rigOf(rigId)
	local look = MeshImportCheck.lookFor(rigId)
	if look then
		look.sizeScale = scale
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not (rig and look and hrp) then
		return nil
	end
	local folder = workspace:FindFirstChild(Data.swap.previewFolder)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Data.swap.previewFolder
		folder.Parent = workspace
	end
	local old = folder:FindFirstChild(rigId)
	if old then
		old:Destroy()
	end
	local model = Instance.new("Model")
	model.Name = rigId
	model.Parent = folder
	local ahead = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	local position = hrp.Position + (ahead.Magnitude > 0 and ahead.Unit or Vector3.new(0, 0, -1)) * Data.swap.previewDistance
	local root = BossRig.build(model, rig, look, position)
	model.PrimaryPart = root
	return model
end

function MeshImportDev.handle(player, args: { string }, reply)
	local what, rigId = args[2], args[3]
	if what == "clear" then
		local folder = workspace:FindFirstChild(Data.swap.previewFolder)
		if folder then
			folder:Destroy()
		end
		reply(player, "메시 미리보기 지움")
		return
	end
	if (what ~= "check" and what ~= "swap") or not rigId then
		reply(player, USAGE)
		return
	end
	local rig, kind = MeshImportCheck.rigOf(rigId)
	if not rig then
		reply(player, ("리그 id %s 없음(MonsterRigSpec · BossRigSpec의 키 - 예: moss_slime · section_guardian)"):format(rigId))
		return
	end
	local path = args[4]
	local model = findModel(rigId, path, kind)
	if not model then
		reply(player, ("모델 없음: %s(경로를 주거나 Shared.%s.%s · Workspace.%s에 둔다)"):format(tostring(path), tostring(Data.modelFolders[kind]), rigId, rigId))
		return
	end
	local ok, summary = runCheck(model, rigId)
	if what == "check" then
		reply(player, ("메시 검사 %s → %s: %s(항목은 출력 창 [MeshCheck])"):format(model:GetFullName(), rigId, summary))
		return
	end
	local scale = tonumber(args[5]) or 1
	local preview = buildPreview(player, rigId, scale)
	if not preview then
		reply(player, "미리보기 리그를 못 지었다(캐릭터 · 색 데이터 확인)")
		return
	end
	local _, lines = MeshSwap.swap(preview, model, rigId, { scale = scale })
	for _, line in ipairs(lines) do
		print(line)
	end
	reply(player, ("메시 교체 미리보기 Workspace.%s.%s(검사 %s) - %s"):format(Data.swap.previewFolder, rigId, ok and "O" or "X", lines[#lines]))
end

return MeshImportDev
