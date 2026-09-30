-- A2-M1 보스 디테일 → JSON(Blender make_boss.py가 읽는다 - 새 관절 · 장식 · 부위 색 · 테마 색). detail_dump.py가 harness/build_run.py로 돌린다.
-- 좌표 = BossDetailSpec 그대로(sizeScale 1 · 부모 부위 공간) - 여기서 숫자를 만들지 않는다.
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


local D = MODS.BossDetailSpec
local function v3(v)
	return v and { v.X, v.Y, v.Z } or nil
end
local function c3(c)
	return typeof(c) == "Color3" and { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) } or c
end
local out = {}
for id, b in pairs(D.bosses) do
	local joints, deco = {}, {}
	for _, j in ipairs(b.joints or {}) do
		table.insert(joints, { name = j.name, parent = j.parent, part = j.part, size = v3(j.size), shape = j.shape or "block", color = c3(j.color), material = j.material or "SmoothPlastic",
			at = v3(j.at), pivot = v3(j.pivot), rot = v3(j.rot) })
	end
	for _, d in ipairs(b.deco or {}) do
		table.insert(deco, { name = d.name, parent = d.parent, size = v3(d.size), shape = d.shape or "block", color = c3(d.color), material = d.material or "SmoothPlastic",
			at = v3(d.at), rot = v3(d.rot), lod = d.lod or 1 })
	end
	local rec = {}
	for k, v in pairs(b.recolor or {}) do
		rec[k] = v
	end
	out[id] = { joints = joints, deco = deco, recolor = rec, themeColors = { body = c3(b.themeColors.body), head = c3(b.themeColors.head), accent = c3(b.themeColors.accent) } }
end
print("===DETAILJSON===")
print(enc(out))
print("===DETAILJSON END===")
