-- W1 무기 모델 규격 검사(WeaponRigSpec): 새(교체) 모델을 넣으면 손잡이 · 축 · 크기 · 보조 손 · 시위 점이 규격에 맞는지 O/X.
--   check(classId, pieceName, model) - model = BasePart 또는 Model(부착점 Grip · Tip · Support · StringNock - 이름 = WeaponRigSpec.attachments).
--     축 · 길이는 모델 기준 프레임(Model = WorldPivot · BasePart = CFrame)의 로컬 좌표로 잰다(월드 배치 무관).
--   specRows() - 규격 데이터 자체 점검(쥔 방향 직교 · 손잡이 점이 길이 안 · 수납 축 · 보조 손 거리).
--   반환: ok(bool), rows = { { label, ok } }.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponRigSpec = require(ReplicatedStorage.Shared.data.WeaponRigSpec)

local WeaponRigCheck = {}

local AXES = { ["+X"] = Vector3.xAxis, ["-X"] = -Vector3.xAxis, ["+Y"] = Vector3.yAxis, ["-Y"] = -Vector3.yAxis, ["+Z"] = Vector3.zAxis, ["-Z"] = -Vector3.zAxis }
WeaponRigCheck.AXES = AXES

local function pieceOf(classId, pieceName)
	local w = WeaponRigSpec.weapons[classId]
	if not w then
		return nil
	end
	for _, p in ipairs(w.pieces) do
		if (p.name or "main") == (pieceName or "main") then
			return p, w
		end
	end
	return nil
end
WeaponRigCheck.pieceOf = pieceOf

local function frameOf(model)
	if model:IsA("Model") then
		return model.WorldPivot
	end
	return model.CFrame
end

local function findAttachment(model, name)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Attachment") and d.Name == name then
			return d
		end
	end
	return nil
end

-- 모델 전체의 로컬 경계(기준 프레임) - 파트 8모서리.
local function localBounds(model, frame)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local parts = model:IsA("BasePart") and { model } or {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in ipairs(parts) do
		local h = p.Size / 2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local q = frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
					lo, hi = lo:Min(q), hi:Max(q)
				end
			end
		end
	end
	return lo, hi
end

function WeaponRigCheck.check(classId, pieceName, model)
	local rows = {}
	local function add(label, ok)
		table.insert(rows, { label = label, ok = ok })
	end
	local piece = pieceOf(classId, pieceName)
	if not piece or typeof(model) ~= "Instance" then
		add("규격 없음 또는 모델 아님", false)
		return false, rows
	end
	local A, C = WeaponRigSpec.attachments, WeaponRigSpec.check
	if model:IsA("Model") then
		add("Model이면 PrimaryPart(강화 이펙트 · 발사 자리가 붙는 파트)", model.PrimaryPart ~= nil) -- W1 리뷰 8
	end
	local frame = frameOf(model)
	local grip = findAttachment(model, A.grip)
	add(("부착점 %s"):format(A.grip), grip ~= nil)
	if not grip then
		return false, rows
	end
	local gripL = frame:PointToObjectSpace(grip.WorldPosition)
	local axis = AXES[piece.tipAxis]
	local lo, hi = localBounds(model, frame)
	local length = math.abs((hi - lo):Dot(axis))
	add(("길이 %.2f(기준 %.2f ± %d%%)"):format(length, piece.refLength, C.lengthTolerance * 100), math.abs(length - piece.refLength) <= piece.refLength * C.lengthTolerance)
	local tip = findAttachment(model, A.tip)
	if tip then
		-- 축 = 모델이 가장 긴 축(경계 상자)이 규격 축과 같고 · Tip이 손잡이보다 + 쪽(활은 손잡이가 날개 축에서 비껴 있어 "손잡이 → Tip" 각도는 못 쓴다)
		local size = hi - lo
		local ax = Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z))
		local along = math.abs(size:Dot(ax))
		local longest = along >= math.max(size.X, size.Y, size.Z) - 1e-6
		local tipAhead = (frame:PointToObjectSpace(tip.WorldPosition) - gripL):Dot(axis)
		add(("끝 축 %s(가장 긴 축 %s · Tip이 손잡이보다 끝 쪽 %.2f)"):format(piece.tipAxis, tostring(longest), tipAhead), longest and tipAhead > 0)
	else
		add(("부착점 %s(축 검사)"):format(A.tip), false)
	end
	-- 손잡이 점이 모델 안(끝 축 방향 경계 안)
	local along = gripL:Dot(axis)
	local a0, a1 = math.min(lo:Dot(axis), hi:Dot(axis)), math.max(lo:Dot(axis), hi:Dot(axis))
	add("손잡이 점이 모델 길이 안", along >= a0 - 0.05 and along <= a1 + 0.05)
	if piece.support then
		local sup = findAttachment(model, A.support)
		local d = sup and (sup.WorldPosition - grip.WorldPosition).Magnitude or 0
		add(("보조 손 %s(손잡이에서 %.2f)"):format(A.support, d), sup ~= nil and d >= C.supportMinStuds and d <= C.supportMaxStuds)
	end
	if piece.stringNock then
		add(("시위 점 %s"):format(A.stringNock), findAttachment(model, A.stringNock) ~= nil)
	end
	local ok = true
	for _, r in ipairs(rows) do
		ok = ok and r.ok
	end
	return ok, rows
end

-- 규격 데이터 자체 점검(모든 무기 · 조각).
function WeaponRigCheck.specRows()
	local rows = {}
	for classId, w in pairs(WeaponRigSpec.weapons) do
		for _, p in ipairs(w.pieces) do
			local key = classId .. "." .. (p.name or "main")
			local h = p.hold
			local ortho = math.abs(h.RightVector:Dot(h.UpVector)) < 1e-6 and math.abs(h.UpVector:Dot(h.LookVector)) < 1e-6 and math.abs(h.RightVector:Cross(h.UpVector):Dot(-h.LookVector) - 1) < 1e-6
			local scale = WeaponRigSpec.scaleOf(p)
			local gripAlong = (p.grip * scale):Dot(AXES[p.tipAxis])
			local sheathOk = p.sheath and (p.sheath.mount == "back" or p.sheath.mount == "hip") and p.sheath.z.Magnitude > 0
			local supportOk = true
			if p.support then
				local d = ((p.support - p.grip) * scale).Magnitude
				supportOk = d >= WeaponRigSpec.check.supportMinStuds and d <= WeaponRigSpec.check.supportMaxStuds
			end
			local handOk = p.hand == "RightHand" or p.hand == "LeftHand"
			table.insert(rows, { label = key, ok = ortho and math.abs(gripAlong) < p.refLength / 2 and sheathOk and supportOk and handOk and AXES[p.tipAxis] ~= nil,
				detail = ("쥔 방향 직교 %s · 손잡이 %.2f(반 길이 %.2f 안) · 수납 %s · 보조 손 %s · 손 %s"):format(tostring(ortho), gripAlong, p.refLength / 2, tostring(sheathOk), tostring(supportOk), p.hand) })
		end
	end
	table.sort(rows, function(a, b)
		return a.label < b.label
	end)
	return rows
end

-- 규격에 맞는 시험 모델(검증 · 교체 모델 견본): 기준 크기 막대 + Grip · Tip · Support · StringNock. bad = "reverse"(끝 반대) | "long"(×1.5) | "noGrip".
function WeaponRigCheck.sampleModel(classId, pieceName, bad)
	local piece = pieceOf(classId, pieceName)
	local axis = AXES[piece.tipAxis]
	local scale = WeaponRigSpec.scaleOf(piece)
	local len = piece.refLength * (bad == "long" and 1.5 or 1)
	local part = Instance.new("Part")
	part.Name = "W1Sample_" .. classId
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(0.3, 0.3, 0.3) + Vector3.new(math.abs(axis.X), math.abs(axis.Y), math.abs(axis.Z)) * (len - 0.3)
	part.CFrame = CFrame.new(0, -500, 0)
	local function att(name, pos)
		local a = Instance.new("Attachment")
		a.Name = name
		a.Position = pos
		a.Parent = part
	end
	local A = WeaponRigSpec.attachments
	local grip = piece.grip * scale
	if bad ~= "noGrip" then
		att(A.grip, grip)
	end
	att(A.tip, axis * (bad == "reverse" and -1 or 1) * len / 2)
	if piece.support then
		att(A.support, piece.support * scale)
	end
	if piece.stringNock then
		att(A.stringNock, piece.stringNock * scale)
	end
	return part
end

return WeaponRigCheck
