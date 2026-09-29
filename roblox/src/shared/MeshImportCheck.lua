-- B3 메시 가져오기 검사기: Blender → FBX → Studio 3D Importer로 가져온 모델이 리그 규격(MonsterRigSpec · BossRigSpec)에 맞는지 항목별 O/X.
--   절차 · 규칙 = docs/art/blender-to-studio.md · 수치 = shared/data/MeshImportCheckData(여기에 숫자를 두지 않는다).
--   check(desc, rigId, opts) - 순수 함수(표 기술자만 읽는다 - 로컬 하네스 roblox/tools/harness/mesh_import_test.luau가 가짜 모델로 돈다).
--     desc = { name, reference(기준 루트 있음), parts = { { name, className, joint = {x,y,z}, center, min, max(기준 루트 공간 · stud), color = {r,g,b}(0 ~ 255),
--              material(이름), transparency, triCount(nil = 모름), textureId, forbidden = { 클래스 이름 } } } }
--     opts = { scale(기본 1 - 규격 sizeScale), look = { bodyColor, headColor }(색 역할 - 기본 = 종 · 보스 데이터) }
--     반환: ok, lines(결과표 문자열 줄 - "[MeshCheck] ①-1 … O"), rows({ id, label, ok, detail })
--   describe(model, opts) - 실제 Model(Instance) → 표 기술자(Studio에서만 - server/MeshImportDev가 부른다). opts.meta = Blender 메타(MeshMeta 모듈 표).
--   expected(rigId, scale) - 규격의 기준 자세(FK): 관절 자리 · 파트 경계 · 관절 프레임(교체 도우미 shared/MeshSwap도 이걸 쓴다).
--   FK는 CFrame 없이 숫자로 푼다(CFrame.Angles(rx, ry, rz) = Rx · Ry · Rz와 같은 순서 - BossRig.jointFrames와 같은 뜻).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.data.MeshImportCheckData)
local MonsterRigSpec = require(ReplicatedStorage.Shared.data.MonsterRigSpec)
local BossRigSpec = require(ReplicatedStorage.Shared.data.BossRigSpec)
local MonsterSpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
local CartoonStyleData = require(ReplicatedStorage.Shared.data.CartoonStyleData)

local MeshImportCheck = {}

-- ─────────────── 숫자 3D(표 {x, y, z} · 3 × 3 행 우선 9칸) ───────────────
local function v3(v)
	return { v.X, v.Y, v.Z }
end

local function rotXYZ(rot)
	if not rot then
		return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
	end
	local a, b, c = math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z)
	local ca, sa, cb, sb, cc, sc = math.cos(a), math.sin(a), math.cos(b), math.sin(b), math.cos(c), math.sin(c)
	-- Rx · Ry · Rz
	return {
		cb * cc, -cb * sc, sb,
		ca * sc + sa * sb * cc, ca * cc - sa * sb * sc, -sa * cb,
		sa * sc - ca * sb * cc, sa * cc + ca * sb * sc, ca * cb,
	}
end

local function mulMM(A, B)
	local out = {}
	for r = 0, 2 do
		for c = 0, 2 do
			out[r * 3 + c + 1] = A[r * 3 + 1] * B[c + 1] + A[r * 3 + 2] * B[c + 4] + A[r * 3 + 3] * B[c + 7]
		end
	end
	return out
end

local function mulMV(A, v)
	return {
		A[1] * v[1] + A[2] * v[2] + A[3] * v[3],
		A[4] * v[1] + A[5] * v[2] + A[6] * v[3],
		A[7] * v[1] + A[8] * v[2] + A[9] * v[3],
	}
end

local function add(a, b)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

local function scaled(a, s)
	return { a[1] * s, a[2] * s, a[3] * s }
end

local function dist(a, b)
	local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- 프레임 { R, p } 합성: A · B
local function compose(A, B)
	return { R = mulMM(A.R, B.R), p = add(mulMV(A.R, B.p), A.p) }
end

local IDENTITY = { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = { 0, 0, 0 } }

local function fmt3(v)
	return ("(%.2f, %.2f, %.2f)"):format(v[1], v[2], v[3])
end

-- ─────────────── 규격 ───────────────
function MeshImportCheck.rigOf(rigId)
	if MonsterRigSpec.rigs[rigId] then
		return MonsterRigSpec.rigs[rigId], "monster"
	elseif BossRigSpec.rigs[rigId] then
		return BossRigSpec.rigs[rigId], "boss"
	end
	return nil, nil
end

-- 색 역할용 look · accent(몬스터 = MonsterSpeciesData · 보스 = BossData - BossRig.build가 받는 것과 같은 값)
function MeshImportCheck.lookFor(rigId)
	local rig, kind = MeshImportCheck.rigOf(rigId)
	if kind == "monster" then
		local s = MonsterSpeciesData.species[rigId]
		if s then
			return { sizeScale = 1, bodyColor = s.body, headColor = s.head }, { accent = s.accent or rig.accent }, "tier" .. tostring(s.tier)
		end
	elseif kind == "boss" then
		local BossData = require(ReplicatedStorage.Shared.data.BossData)
		local b = BossData.bosses and BossData.bosses[rigId]
		local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
		local zoneKey
		for _, z in ipairs(WorldMapData.zones or {}) do
			if z.bossId == rigId then
				zoneKey = z.key
			end
		end
		if b then
			return { sizeScale = 1, bodyColor = b.bodyColor, headColor = b.headColor }, rig, zoneKey
		end
	end
	return nil, rig, nil
end

-- 기준 자세 FK. 반환: { kind, rig, order = { 파트 이름 }, parts = { [이름] = { joint, jointFrame, center, min, max, size, longest, material, query, color } }, min, max, hitbox }
function MeshImportCheck.expected(rigId, scale)
	local rig, kind = MeshImportCheck.rigOf(rigId)
	if not rig then
		return nil
	end
	local S = scale or 1
	local frames = { HumanoidRootPart = IDENTITY }
	local out = { kind = kind, rig = rig, order = {}, parts = {} }
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, j in ipairs(rig.joints) do
		local parentF = frames[j.parent] or IDENTITY
		local jointF = compose(parentF, { R = rotXYZ(j.rot), p = scaled(v3(j.at), S) })
		local partF = compose(jointF, { R = IDENTITY.R, p = scaled(v3(j.pivot or Vector3.new(0, 0, 0)), -S) })
		frames[j.part] = partF
		local half = scaled(v3(j.size), S / 2)
		local e: { number } = {}
		for r = 0, 2 do
			e[r + 1] = math.abs(partF.R[r * 3 + 1]) * half[1] + math.abs(partF.R[r * 3 + 2]) * half[2] + math.abs(partF.R[r * 3 + 3]) * half[3]
		end
		local pmin: { number } = { partF.p[1] - e[1], partF.p[2] - e[2], partF.p[3] - e[3] }
		local pmax: { number } = { partF.p[1] + e[1], partF.p[2] + e[2], partF.p[3] + e[3] }
		for k = 1, 3 do
			lo[k] = math.min(lo[k], pmin[k])
			hi[k] = math.max(hi[k], pmax[k])
		end
		table.insert(out.order, j.part)
		out.parts[j.part] = {
			joint = jointF.p, jointFrame = jointF, jointName = j.name, parent = j.parent, center = partF.p, min = pmin, max = pmax,
			size = scaled(v3(j.size), S), longest = math.max(j.size.X, j.size.Y, j.size.Z) * S,
			material = j.material, query = j.query == true, color = j.color,
		}
	end
	out.min, out.max = lo, hi
	if kind == "monster" then
		local s = MonsterSpeciesData.species[rigId]
		local box = s and s.hitbox
		if box then
			out.hitbox = { size = scaled(v3(box.size), S), center = scaled(v3(box.center), S) }
		else
			local d = Data.defaultMonsterHitbox
			out.hitbox = { size = scaled(d.size, S), center = scaled(d.center, S) }
		end
	end
	return out
end

-- ─────────────── 팔레트 ───────────────
local function to255(c)
	if type(c) == "table" and c[1] then
		return c
	end
	return { c.R * 255, c.G * 255, c.B * 255 }
end

function MeshImportCheck.allowedColors(rigId, opts)
	opts = opts or {}
	local list = {}
	local function push(c, label)
		if c then
			table.insert(list, { rgb = to255(c), label = label })
		end
	end
	local look, rigProxy, zoneKey = MeshImportCheck.lookFor(rigId)
	look = opts.look or look
	local zones = {}
	for key, zone in pairs(CartoonStyleData.palette or {}) do
		if not zoneKey or key == zoneKey then
			zones[key] = zone
		end
	end
	for key, zone in pairs(zones) do
		for role, c in pairs(zone) do
			push(c, key .. "." .. role)
		end
	end
	push(CartoonStyleData.outline and CartoonStyleData.outline.color, "outline")
	if look and look.bodyColor and look.headColor then
		for _, role in ipairs(Data.palette.roles) do
			push(BossRigSpec.colorOf(role, look, rigProxy or {}), "rig." .. role)
		end
	end
	local out = {}
	for _, base in ipairs(list) do
		for _, t in ipairs(Data.palette.tones) do
			table.insert(out, {
				rgb = { math.min(base.rgb[1] * t, 255), math.min(base.rgb[2] * t, 255), math.min(base.rgb[3] * t, 255) },
				label = t == 1 and base.label or ("%s×%.2f"):format(base.label, t),
			})
		end
	end
	return out
end

local function nearestColor(rgb, allowed)
	local best, bestLabel = math.huge, nil
	for _, a in ipairs(allowed) do
		local d = math.max(math.abs(rgb[1] - a.rgb[1]), math.abs(rgb[2] - a.rgb[2]), math.abs(rgb[3] - a.rgb[3]))
		if d < best then
			best, bestLabel = d, a.label
		end
	end
	return best, bestLabel
end

local function hex(rgb)
	return ("#%02X%02X%02X"):format(math.floor(rgb[1] + 0.5), math.floor(rgb[2] + 0.5), math.floor(rgb[3] + 0.5))
end

-- ─────────────── 검사 ───────────────
function MeshImportCheck.check(desc, rigId, opts)
	opts = opts or {}
	local rows, lines = {}, {}
	local function row(id, label, ok, detail)
		table.insert(rows, { id = id, label = label, ok = ok, detail = detail })
		table.insert(lines, ("[MeshCheck] %s %s%s %s"):format(id, label, detail and detail ~= "" and (" - " .. detail) or "", ok and "O" or "X"))
	end
	local hints = {}
	local S = opts.scale or 1
	local exp = MeshImportCheck.expected(rigId, S)
	if not exp or type(desc) ~= "table" or type(desc.parts) ~= "table" then
		row("0", "규격 · 모델", false, ("리그 id %s 없음 또는 기술자 아님"):format(tostring(rigId)))
		return false, lines, rows
	end
	table.insert(lines, 1, ("[MeshCheck] 모델 %s → 리그 %s(%s · 파트 %d · 배율 %.2f)"):format(tostring(desc.name), rigId, exp.kind, #exp.order, S))

	-- 이름 표
	local byName, dup = {}, {}
	for _, p in ipairs(desc.parts) do
		if not Data.ignoreNames[p.name] then
			if byName[p.name] then
				table.insert(dup, p.name)
			end
			byName[p.name] = p
		end
	end

	-- ① 파트 이름
	row("①-0", "기준 루트 " .. Data.referenceRootName, desc.reference == true, desc.reference and "" or "없음 - 모델 피벗을 기준으로 잰다")
	local missing, extra = {}, {}
	for _, name in ipairs(exp.order) do
		if not byName[name] then
			table.insert(missing, name)
		end
	end
	for name in pairs(byName) do
		if not exp.parts[name] then
			table.insert(extra, name)
		end
	end
	table.sort(extra)
	row("①-1", "빠진 리그 파트 없음", #missing == 0, #missing > 0 and ("빠짐: " .. table.concat(missing, ", ")) or ("%d/%d"):format(#exp.order, #exp.order))
	row("①-2", "남는 · 중복 파트 없음", #extra == 0 and #dup == 0, (#extra > 0 and ("남음: " .. table.concat(extra, ", ")) or "") .. (#dup > 0 and (" 중복: " .. table.concat(dup, ", ")) or ""))

	-- ② 관절(피벗) 자리
	local tol = Data.jointToleranceStuds * S
	local bad, atCenter, measured, worst = {}, 0, 0, 0
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p then
			if not p.joint then
				table.insert(bad, name .. "(관절 모름)")
			else
				measured += 1
				local d = dist(p.joint, exp.parts[name].joint)
				worst = math.max(worst, d)
				if d > tol then
					table.insert(bad, ("%s %.2f"):format(name, d))
					if p.center and dist(p.joint, p.center) <= Data.pivotAtCenterEpsilon then
						atCenter += 1
					end
				end
			end
		end
	end
	row("②", ("관절 자리 오차 ≤ %.2f"):format(tol), #bad == 0 and measured > 0, #bad > 0 and table.concat(bad, ", ") or ("최대 %.3f"):format(worst))
	if atCenter > 0 and atCenter * 2 >= #bad then
		table.insert(hints, ("② X %d개의 측정 관절 = 파트 경계 가운데 → 가져오기가 피벗(Blender 원점)을 옮겼다: 파트에 Attachment \"%s\"를 관절 자리에 두거나 피벗 편집(문서 §7)"):format(atCenter, Data.jointAttachmentName))
	end

	-- ③ 삼각형 예산
	local unknown, total = {}, 0
	for name, p in pairs(byName) do
		if type(p.triCount) == "number" then
			total += p.triCount
		else
			table.insert(unknown, name)
		end
	end
	table.sort(unknown)
	local budget = Data.triBudget[exp.kind]
	row("③-1", "파트별 삼각형 수 알려짐(Attribute " .. Data.triAttribute .. " 또는 메타)", #unknown == 0, #unknown > 0 and ("모름: " .. table.concat(unknown, ", ")) or "")
	row("③-2", ("삼각형 합 ≤ %d(%s)"):format(budget, exp.kind), #unknown == 0 and total <= budget, ("합 %d"):format(total))

	-- ④ 크기 · 판정
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in pairs(byName) do
		if p.min and p.max then
			for k = 1, 3 do
				lo[k] = math.min(lo[k], p.min[k])
				hi[k] = math.max(hi[k], p.max[k])
			end
		end
	end
	local R = Data.size
	local ratios, okOverall = {}, lo[1] < math.huge
	for k = 1, 3 do
		local want = exp.max[k] - exp.min[k]
		local got = hi[k] - lo[k]
		local r = want > 0 and got / want or 0
		ratios[k] = r
		okOverall = okOverall and r >= R.overallRatio.min and r <= R.overallRatio.max
	end
	row("④-1", ("전체 크기 ÷ 규격(축마다 %.2f ~ %.2f)"):format(R.overallRatio.min, R.overallRatio.max), okOverall, ("x %.2f · y %.2f · z %.2f"):format(ratios[1] or 0, ratios[2] or 0, ratios[3] or 0))
	if not okOverall and lo[1] < math.huge then
		local mean = (ratios[1] + ratios[2] + ratios[3]) / 3
		for _, h in ipairs(R.unitHints) do
			if math.abs(mean / h.ratio - 1) <= R.unitHintTolerance then
				table.insert(hints, ("④-1 전체 비율 약 %.3f = 단위 %s 같다 → 3D Importer 단위(Stud) · Blender 단위 배율 확인(문서 §7)"):format(mean, h.label))
			end
		end
	end
	if exp.hitbox then
		-- 겉모습 경계 중 판정 상자와 겹치는 부피 비율 - 규격 모양(판정 상자를 맞춘 기준)보다 많이 줄면 "보이는 곳 ≠ 맞는 곳"
		local c, h = exp.hitbox.center, exp.hitbox.size
		local hbMin = { c[1] - h[1] / 2, c[2] - h[2] / 2, c[3] - h[3] / 2 }
		local hbMax = { c[1] + h[1] / 2, c[2] + h[2] / 2, c[3] + h[3] / 2 }
		local function coverage(a, b)
			local inter, vol = 1, 1
			for k = 1, 3 do
				inter *= math.max(0, math.min(b[k], hbMax[k]) - math.max(a[k], hbMin[k]))
				vol *= math.max(b[k] - a[k], 1e-6)
			end
			return inter / vol
		end
		local want = coverage(exp.min, exp.max)
		local got = lo[1] < math.huge and coverage(lo, hi) or 0
		row("④-2", ("판정 상자(Hitbox)와 겹치는 비율 ≥ 규격 − %.2f"):format(R.hitboxCoverageDrop), got >= want - R.hitboxCoverageDrop,
			("겹침 %.2f(규격 %.2f) · 상자 %s @ %s"):format(got, want, fmt3(h), fmt3(c)))
	else
		local badQ = {}
		for _, name in ipairs(exp.order) do
			local e, p = exp.parts[name], byName[name]
			if e.query and p and p.min then
				for k = 1, 3 do
					local r = (p.max[k] - p.min[k]) / math.max(e.max[k] - e.min[k], 1e-6)
					if r < R.queryPartRatio.min or r > R.queryPartRatio.max then
						table.insert(badQ, ("%s 축%d %.2f"):format(name, k, r))
						break
					end
				end
			end
		end
		row("④-2", ("판정 파트(query) 크기 ÷ 규격 %.2f ~ %.2f"):format(R.queryPartRatio.min, R.queryPartRatio.max), #badQ == 0, table.concat(badQ, ", "))
	end
	local badPart = {}
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p and p.min then
			local longest = math.max(p.max[1] - p.min[1], p.max[2] - p.min[2], p.max[3] - p.min[3])
			local r = longest / math.max(exp.parts[name].longest, 1e-6)
			if r < R.partLongestRatio.min or r > R.partLongestRatio.max then
				table.insert(badPart, ("%s %.2f"):format(name, r))
			end
		end
	end
	row("④-3", ("파트 가장 긴 변 ÷ 규격(%.2f ~ %.2f)"):format(R.partLongestRatio.min, R.partLongestRatio.max), #badPart == 0, table.concat(badPart, ", "))

	-- ⑤ 팔레트
	local allowed = MeshImportCheck.allowedColors(rigId, opts)
	local badColor = {}
	for _, name in ipairs(exp.order) do
		local p = byName[name]
		if p and p.color then
			local d = nearestColor(p.color, allowed)
			if d > Data.palette.toleranceRGB then
				table.insert(badColor, ("%s %s"):format(name, hex(p.color)))
			end
		end
	end
	row("⑤", ("팔레트 색만(허용 %d색 · 채널 차 ≤ %d)"):format(#allowed, Data.palette.toleranceRGB), #badColor == 0, table.concat(badColor, ", "))

	-- ⑥ 클래스 · 투명 · 재질 · 텍스처
	local badClass, badAlpha, badMat, badTex = {}, {}, {}, {}
	for name, p in pairs(byName) do
		if not Data.allowedClasses[p.className or ""] then
			table.insert(badClass, ("%s(%s)"):format(name, tostring(p.className)))
		end
		if (p.transparency or 0) > Data.maxTransparency then
			table.insert(badAlpha, ("%s %.2f"):format(name, p.transparency))
		end
		local e = exp.parts[name]
		local mat = p.material or "SmoothPlastic"
		if not (Data.allowedMaterials[mat] or (e and e.material == mat)) then
			table.insert(badMat, ("%s %s"):format(name, mat))
		end
		if (p.textureId and p.textureId ~= "") or (p.forbidden and #p.forbidden > 0) then
			table.insert(badTex, ("%s %s"):format(name, (p.forbidden and #p.forbidden > 0) and table.concat(p.forbidden, "/") or "TextureID"))
		end
	end
	for _, t in ipairs({ badClass, badAlpha, badMat, badTex }) do
		table.sort(t)
	end
	row("⑥-1", "클래스 MeshPart", #badClass == 0, table.concat(badClass, ", "))
	row("⑥-2", ("투명도 ≤ %s"):format(tostring(Data.maxTransparency)), #badAlpha == 0, table.concat(badAlpha, ", "))
	row("⑥-3", "재질 SmoothPlastic(규격이 정한 재질만 예외)", #badMat == 0, table.concat(badMat, ", "))
	row("⑥-4", "텍스처 · SurfaceAppearance · Decal 없음", #badTex == 0, table.concat(badTex, ", "))

	local pass = 0
	for _, r in ipairs(rows) do
		if r.ok then
			pass += 1
		end
	end
	for _, h in ipairs(hints) do
		table.insert(lines, "[MeshCheck] 힌트: " .. h)
	end
	table.insert(lines, ("[MeshCheck] 결과 %d/%d 통과"):format(pass, #rows))
	return pass == #rows, lines, rows
end

-- ─────────────── Instance → 기술자(Studio) ───────────────
local function localBounds(part, refCF)
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	local h = part.Size / 2
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local q = refCF:PointToObjectSpace(part.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz)))
				lo = { math.min(lo[1], q.X), math.min(lo[2], q.Y), math.min(lo[3], q.Z) }
				hi = { math.max(hi[1], q.X), math.max(hi[2], q.Y), math.max(hi[3], q.Z) }
			end
		end
	end
	return lo, hi
end

function MeshImportCheck.referenceFrame(model)
	local ref = model:FindFirstChild(Data.referenceRootName, true)
	if ref and ref:IsA("BasePart") then
		return ref.CFrame, ref
	end
	return model:GetPivot(), nil
end

function MeshImportCheck.describe(model, opts)
	opts = opts or {}
	local meta = opts.meta
	local refCF, ref = MeshImportCheck.referenceFrame(model)
	local desc = { name = model.Name, reference = ref ~= nil, parts = {} }
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= ref then
			local att = d:FindFirstChild(Data.jointAttachmentName)
			local jointWorld = (att and att:IsA("Attachment")) and att.WorldPosition or d:GetPivot().Position
			local lo, hi = localBounds(d, refCF)
			local forbidden = {}
			for _, c in ipairs(d:GetChildren()) do
				if Data.forbiddenChildren[c.ClassName] then
					table.insert(forbidden, c.ClassName)
				end
			end
			local tri = d:GetAttribute(Data.triAttribute)
			if type(tri) ~= "number" and meta and meta.parts and meta.parts[d.Name] then
				tri = meta.parts[d.Name].tris
			end
			table.insert(desc.parts, {
				name = d.Name, className = d.ClassName, joint = v3(refCF:PointToObjectSpace(jointWorld)), center = v3(refCF:PointToObjectSpace(d.Position)),
				min = lo, max = hi, color = { d.Color.R * 255, d.Color.G * 255, d.Color.B * 255 }, material = d.Material.Name, transparency = d.Transparency,
				triCount = type(tri) == "number" and tri or nil, textureId = d:IsA("MeshPart") and d.TextureID or "", forbidden = forbidden,
			})
		end
	end
	return desc
end

-- 기준 자세 관절 프레임 → CFrame(교체 도우미)
function MeshImportCheck.toCFrame(F)
	local R, p = F.R, F.p
	return CFrame.new(p[1], p[2], p[3], R[1], R[2], R[3], R[4], R[5], R[6], R[7], R[8], R[9])
end

return MeshImportCheck
