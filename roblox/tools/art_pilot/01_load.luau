-- ART-PILOT-1 Studio 1단계(Edit · execute_luau에 붙여 넣기): 시범 에셋을 Workspace._ArtPilot 하나에 넣고 구조를 덤프한다.
--   규칙: 시험물 = _ArtPilot 폴더 하나(Rojo 관리 밖) · 끝나면 폴더 제거 · 폴더 있는 동안 place 저장/퍼블리시 금지.
--   id = roblox/art/pilot/art_pilot_1/pilot-asset-ids.json · boar_now = ArtAssetIds["monsters/rock_boar"].
local IS = game:GetService("InsertService")
local root = workspace:FindFirstChild("_ArtPilot") or Instance.new("Folder")
root.Name = "_ArtPilot"
root.Parent = workspace
local ids = { boar_b1 = 128414478880334, boar_b2 = 89766282306898, boar_now = 87912718220821, smith_a2 = 124875843859881 }
local tex = { boar_b1 = 108013967024403, smith_a2 = 86038080068377 }
local out = {}
local function p(s) table.insert(out, s) end
for name, id in pairs(ids) do
	if not root:FindFirstChild(name) then
		local ok, m = pcall(function() return IS:LoadAsset(id) end)
		if not ok then p(name .. " LOAD ERR " .. tostring(m)) continue end
		m.Name = name
		m.Parent = root
	end
	local m = root[name]
	local counts, bones, anims = {}, 0, {}
	for _, d in ipairs(m:GetDescendants()) do
		counts[d.ClassName] = (counts[d.ClassName] or 0) + 1
		if d:IsA("Bone") then bones += 1 end
		if d:IsA("KeyframeSequence") or d:IsA("AnimationClip") or d:IsA("Animation") then table.insert(anims, d:GetFullName()) end
	end
	local cs = {}
	for k, v in pairs(counts) do table.insert(cs, k .. "=" .. v) end
	table.sort(cs)
	p(("== %s (%d) %s"):format(name, id, table.concat(cs, " ")))
	if #anims > 0 then p("  anims: " .. table.concat(anims, ", ")) end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("MeshPart") then
			p(("  MeshPart %s size=%.2f,%.2f,%.2f pos=%.2f,%.2f,%.2f pivotOff=%.2f,%.2f,%.2f"):format(d.Name, d.Size.X, d.Size.Y, d.Size.Z,
				d.Position.X, d.Position.Y, d.Position.Z, d.PivotOffset.X, d.PivotOffset.Y, d.PivotOffset.Z))
		end
	end
end
for name, id in pairs(tex) do
	local ok, m = pcall(function() return IS:LoadAsset(id) end)
	local dec = ok and m:FindFirstChildWhichIsA("Decal", true)
	p(("tex %s decal=%d image=%s"):format(name, id, dec and dec.Texture or ("ERR " .. tostring(m))))
	if ok then m:Destroy() end
end
return table.concat(out, "\n")
