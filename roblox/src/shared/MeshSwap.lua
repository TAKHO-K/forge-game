-- B3 메시 교체 도우미: 가져온 모델(Blender → Studio)의 메시를 같은 이름 리그 파트 자리에 1:1로 끼운다.
--   swap(rigModel, importModel, rigId, opts) - rigModel = shared/BossRig.build로 지은 기준 자세 리그(Motor6D.Transform = 기본 · 루트 Anchored - 개발 미리보기).
--     ① 가져온 파트를 기준 루트(MeshImportCheckData.referenceRootName) 기준 자리 그대로 리그 루트 기준으로 옮긴다(× sizeScale).
--     ② 옛 파트의 Motor6D · 부착점(Rig_*)을 새 메시로 옮기고, 관절 C0 · C1은 규격 관절 프레임(MeshImportCheck.expected)으로 다시 계산한다
--        → 모션(관절 이름 · 계층)은 그대로 · 메시의 피벗이 가져오기에서 어긋나도 관절은 규격 자리에서 돈다.
--     ③ 물리 속성(CanCollide · CanTouch 끔 · CanQuery = 옛 파트 그대로 · Massless)과 색(MeshImportCheckData.swap.recolor)을 옛 파트에서 옮긴다.
--     가져온 모델에 없는 파트는 옛 파트 그대로 둔다(반쯤 만든 모델도 미리볼 수 있다).
--   반환: count(끼운 수), lines(결과 줄 - "[MeshSwap] …"), refCF(가져온 모델 기준 프레임 - 남는 메시를 같은 자리에 둘 때).
--   opts.lift(A2-N3) = 보스 접지 높이(BossRig.rootLift) · 스폰 연결 = shared/ArtMeshKit.applyRig(ArtStyleV1 뒤).
--   스폰(MonsterSpawner · BossRig.build)에는 아직 연결하지 않는다 - 연결 자리 = docs/art/blender-to-studio.md §8.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MeshImportCheck = require(ReplicatedStorage.Shared.MeshImportCheck)

local MeshSwap = {}

-- A2-N2: 기준 루트 없는 가져오기(A2-N1 FBX)를 Blender 메타로 맞춘다. 메시는 휴식 자세 월드 방향으로 구워져 있다(회전 0) → 가져온 모델 안 상대 배치는 그대로고
--   모르는 것은 평행 이동 하나뿐. 파트마다 (메타 경계 가운데 center - 가져온 파트 가운데)의 평균 = 이동량 · 가장 큰 어긋남 = 배치가 깨졌는지 검사(Data.swap.metaResidualStuds).
--   points = { { name, center = {x,y,z} 가져온 모델 기준 } } · meta = { parts = { [이름] = { center = {x,y,z} } } } (리그 공간 · 배율 1). 반환 offset {x,y,z} · residual · 쓴 수.
function MeshSwap.alignFromMeta(points, meta, scale)
	local S = scale or 1
	local sum, n = { 0, 0, 0 }, 0
	local pairsUsed = {}
	for _, p in ipairs(points) do
		local m = meta and meta.parts and meta.parts[p.name]
		if m and m.center then
			local d = { m.center[1] * S - p.center[1], m.center[2] * S - p.center[2], m.center[3] * S - p.center[3] }
			for k = 1, 3 do
				sum[k] += d[k]
			end
			n += 1
			table.insert(pairsUsed, d)
		end
	end
	if n == 0 then
		return nil, math.huge, 0
	end
	local offset = { sum[1] / n, sum[2] / n, sum[3] / n }
	local residual = 0
	for _, d in ipairs(pairsUsed) do
		residual = math.max(residual, math.sqrt((d[1] - offset[1]) ^ 2 + (d[2] - offset[2]) ^ 2 + (d[3] - offset[3]) ^ 2))
	end
	return offset, residual, n
end

function MeshSwap.swap(rigModel, importModel, rigId, opts)
	opts = opts or {}
	local lines = {}
	local S = opts.scale or 1
	local exp = MeshImportCheck.expected(rigId, S)
	local root = rigModel:FindFirstChild("HumanoidRootPart")
	if not exp or not root then
		table.insert(lines, ("[MeshSwap] 리그 %s 규격 또는 루트 없음 X"):format(tostring(rigId)))
		return 0, lines
	end
	local refCF, ref = MeshImportCheck.referenceFrame(importModel)
	local rootCF = root.CFrame * CFrame.new(0, opts.lift or 0, 0) -- A2-N3: 보스 접지(BossRig.rootLift) - 루트에 붙는 관절이 올라간 만큼 메시 · 관절 자리도 올린다
	local sources = {}
	for _, d in ipairs(importModel:GetDescendants()) do
		if d:IsA("BasePart") and d ~= ref and not Data.ignoreNames[d.Name] then
			sources[d.Name] = sources[d.Name] or d
		end
	end
	-- 기준 루트가 없고 메타(center)가 있으면: 기준 = 모델 피벗의 위치만(회전 0 - 구운 방향) + 메타 평균 이동량
	local metaShift = nil
	if not ref and opts.meta then
		local base = CFrame.new(importModel:GetPivot().Position)
		local points = {}
		for name, src in pairs(sources) do
			local c = base:PointToObjectSpace(src.Position)
			table.insert(points, { name = name, center = { c.X, c.Y, c.Z } })
		end
		local offset, residual, used = MeshSwap.alignFromMeta(points, opts.meta, 1) -- 가져온 모델 단위(배율 전) - 아래 rel × S
		if offset then
			refCF = base * CFrame.new(-offset[1], -offset[2], -offset[3])
			metaShift = { residual = residual, used = used }
			table.insert(lines, ("[MeshSwap] 메타 정렬: 파트 %d · 가장 큰 어긋남 %.3f stud %s"):format(used, residual, residual <= Data.swap.metaResidualStuds and "O" or "X(배치 깨짐 - 가져오기 축 · 배율 확인)"))
		end
	end

	local replaced = {} -- [옛 파트] = 새 메시
	local kept = {}
	for _, name in ipairs(exp.order) do
		local old = rigModel:FindFirstChild(name)
		local src = sources[name]
		if old and old:IsA("BasePart") and src then
			local mesh = src:Clone()
			for _, c in ipairs(mesh:GetChildren()) do
				if not c:IsA("Attachment") then
					c:Destroy() -- 가져온 파트에 딸린 스크립트 · 조인트 · 표면 효과는 옮기지 않는다
				end
			end
			if S ~= 1 then
				mesh.Size = mesh.Size * S
			end
			local rel = refCF:ToObjectSpace(src.CFrame)
			mesh.CFrame = rootCF * (CFrame.new(rel.Position * S) * rel.Rotation)
			mesh.Name = name
			mesh.Anchored = false
			mesh.Massless = true
			mesh.CanCollide = false
			mesh.CanTouch = false
			mesh.CanQuery = old.CanQuery
			mesh.CastShadow = old.CastShadow
			if Data.swap.recolor then
				mesh.Color = old.Color
				mesh.Material = old.Material -- A2-N3: 리그 재질(Neon 눈 · 룬)도 같이
			end
			mesh:SetAttribute("MeshSwapFrom", importModel:GetFullName())
			mesh.Parent = rigModel
			for _, c in ipairs(old:GetChildren()) do
				if c:IsA("Motor6D") then
					c.Parent = mesh
				elseif c:IsA("Attachment") then
					c.CFrame = mesh.CFrame:ToObjectSpace(old.CFrame * c.CFrame)
					c.Parent = mesh
				end
			end
			replaced[old] = mesh
		else
			table.insert(kept, name)
		end
	end

	-- 관절 다시 걸기: 바뀐 파트에 닿은 Motor6D만(Part1 이름 = 규격 파트 이름 → 규격 관절 프레임)
	local rejoined = 0
	for _, m in ipairs(rigModel:GetDescendants()) do
		if m:IsA("Motor6D") then
			local p0, p1 = replaced[m.Part0], replaced[m.Part1]
			if p0 or p1 then
				m.Part0 = p0 or m.Part0
				m.Part1 = p1 or m.Part1
				local e = m.Part1 and exp.parts[m.Part1.Name]
				if e and m.Part0 then
					local jointWorld = rootCF * MeshImportCheck.toCFrame(e.jointFrame)
					m.C0 = m.Part0.CFrame:ToObjectSpace(jointWorld)
					m.C1 = m.Part1.CFrame:ToObjectSpace(jointWorld)
					rejoined += 1
				end
			end
		end
	end
	local count = 0
	for old in pairs(replaced) do
		old:Destroy()
		count += 1
	end
	rigModel:SetAttribute("MeshSwapped", count)
	table.insert(lines, ("[MeshSwap] %s ← %s(%s): 끼움 %d/%d · 관절 다시 걸기 %d%s %s"):format(rigId, importModel:GetFullName(), ref and "기준 루트" or (metaShift and "메타" or "모델 피벗"), count, #exp.order, rejoined,
		#kept > 0 and (" · 그대로(파트) " .. table.concat(kept, ", ")) or "", count == #exp.order and "O" or "X"))
	return count, lines, refCF
end

return MeshSwap
