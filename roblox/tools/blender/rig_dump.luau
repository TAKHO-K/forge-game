-- B3 리그 규격 → JSON(Blender 스크립트 make_rig_mesh.py의 입력). rig_dump.py가 첫 줄에 `local RIG_ID = "<리그 id>"`를 붙이고
-- harness/build_run.py로 돌린다(prelude + shared 모듈). 좌표 = Roblox 리그 공간(sizeScale 1 · 루트 = 원점 · 앞 = −Z · 위 = +Y · stud).
-- 값은 전부 shared/MeshImportCheck.expected(검사기와 같은 FK)와 BossRigSpec.colorOf(스폰과 같은 색 역할)에서 나온다 - 여기서 숫자를 만들지 않는다.

do -- prelude Color3 보강(colorOf의 Lerp)
	local C3MT = {}
	C3MT.__index = {
		Lerp = function(a, b, t)
			return Color3.new(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t)
		end,
	}
	Color3.new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3MT)
	end
	Color3.fromRGB = function(r, g, b)
		return Color3.new((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end
end

local function enc(v)
	local t = type(v)
	if t == "number" then
		return (("%.6f"):format(v):gsub("0+$", ""):gsub("%.$", ".0"))
	elseif t == "string" then
		return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "table" then
		if #v > 0 or next(v) == nil then
			local out = {}
			for _, x in ipairs(v) do
				table.insert(out, enc(x))
			end
			return "[" .. table.concat(out, ", ") .. "]"
		end
		local keys = {}
		for k in pairs(v) do
			table.insert(keys, k)
		end
		table.sort(keys)
		local out = {}
		for _, k in ipairs(keys) do
			table.insert(out, enc(tostring(k)) .. ": " .. enc(v[k]))
		end
		return "{" .. table.concat(out, ", ") .. "}"
	end
	return "null"
end

local Check = MODS.MeshImportCheck
local Data = MODS.MeshImportCheckData
local BossRigSpec = MODS.BossRigSpec
local exp = Check.expected(RIG_ID, 1)
assert(exp, "리그 id 없음: " .. tostring(RIG_ID))
local look, rigProxy = Check.lookFor(RIG_ID)
local parts = {}
for _, name in ipairs(exp.order) do
	local e = exp.parts[name]
	local shape = "block"
	for _, j in ipairs(exp.rig.joints) do
		if j.part == name then
			shape = j.shape or "block"
		end
	end
	local c = look and BossRigSpec.colorOf(e.color, look, rigProxy or {}) or Color3.new(0.64, 0.64, 0.65)
	table.insert(parts, {
		name = name, jointName = e.jointName, parent = e.parent, shape = shape, size = e.size, joint = e.joint, center = e.center,
		rotation = e.jointFrame.R, colorRole = e.color, color = { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) },
		material = e.material or "SmoothPlastic",
	})
end
print("===RIGJSON===")
print(enc({
	rigId = RIG_ID, kind = exp.kind, units = "stud", space = "roblox(+Y 위 · -Z 앞)", referenceRoot = Data.referenceRootName,
	triBudget = Data.triBudget[exp.kind], triAttribute = Data.triAttribute, parts = parts,
}))
print("===RIGJSON END===")
