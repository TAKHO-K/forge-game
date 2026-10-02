-- QUEUE-ALL7 D2 지도 굽기 1단계: 서버 execute_luau(Play 중 - 맵이 지어진 뒤)로 위에서 아래로 격자 레이캐스트 → 줄마다 압축 문자열.
--   셀 = 분류 1글자 + 높이 1글자(chr(40 + 높이 단계)) · 같은 셀이 이어지면 "~개수;" (줄 압축). 줄 사이 = "\n".
--   분류: W 물 · T 나무 · B 건물 · R 길 · K 바위(지형 Rock · Slate · Basalt) · S 모래 · N 눈 · I 얼음 · G 풀 · D 흙(Ground · Mud · 길이 아닌 흙) · C 수정 · H 허브 광장(낮은 판) · P 기타 파트(다시 쏴서 지형) · X 없음
--   빼는 것: 둥지(Nest_* - 지도 표시 금지) · 캐릭터 · 먼 산(DistantMountains) · 투명/안 막는 파트(다시 쏜다).
-- QUEUE-ALL7 D2 지도 굽기 표본(Studio 전용 - 라이브에서는 아무것도 안 한다). 서버 execute_luau: require(game.ServerScriptService.MapGenSample)(row0, rows)
--   → 줄마다 "[MAPGEN] z.조각:압축"(x 256칸씩 4조각) 을 출력(로그 파일) · roblox/tools/mapgen/render.py가 로그에서 읽어 PNG를 굽는다. 형식 설명 = 아래.
return function(ROW0, ROWS)
	if not game:GetService("RunService"):IsStudio() then
		return "studio only"
	end
	local N = 1024 -- 한 변 셀 수(세계 2 × edge.radius = 5,920 stud → 약 5.78 stud/셀)
	local EDGE = require(game:GetService("ReplicatedStorage").Shared.data.WorldMapData).edge.radius
	local Y0, YSTEP = -40, 10 -- 높이 단계 = (y − Y0) / YSTEP(0 ~ 85)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = {}
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local ground = workspace:FindFirstChild("Ground")
	for _, m in ipairs(ground and ground:GetChildren() or {}) do
		if m.Name:match("^Nest_") then
			table.insert(exclude, m)
		end
	end
	for _, name in ipairs({ "DistantMountains" }) do
		if workspace:FindFirstChild(name) then
			table.insert(exclude, workspace[name])
		end
	end
	for _, c in ipairs(workspace:GetChildren()) do
		if c:IsA("Model") and c:FindFirstChildOfClass("Humanoid") then
			table.insert(exclude, c)
		end
	end
	params.FilterDescendantsInstances = exclude

	local TERRAIN = {
		[Enum.Material.Water] = "W", [Enum.Material.Rock] = "K", [Enum.Material.Slate] = "K", [Enum.Material.Basalt] = "K", [Enum.Material.Limestone] = "K", [Enum.Material.Pavement] = "R",
		[Enum.Material.Sand] = "S", [Enum.Material.Sandstone] = "S", [Enum.Material.Snow] = "N", [Enum.Material.Glacier] = "I", [Enum.Material.Ice] = "I",
		[Enum.Material.Grass] = "G", [Enum.Material.LeafyGrass] = "G", [Enum.Material.Ground] = "D", [Enum.Material.Mud] = "D", [Enum.Material.Salt] = "S", [Enum.Material.CrackedLava] = "K",
	}
	local terrainOnly = RaycastParams.new()
	terrainOnly.FilterType = Enum.RaycastFilterType.Include
	terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
	local function terrainY(x, z)
		local t = workspace:Raycast(Vector3.new(x, 1600, z), Vector3.new(0, -3200, 0), terrainOnly)
		return t and t.Position.Y or nil
	end
	local function classOfPart(part, hitPos)
		local chain = ""
		local node = part
		for _ = 1, 6 do
			if not node or node == workspace then
				break
			end
			chain = chain .. "/" .. node.Name
			node = node.Parent
		end
		local l = chain:lower()
		if part.Material == Enum.Material.Water or l:find("water") then
			return "W"
		elseif l:find("tree") or l:find("treecourse") or l:find("bigtree") or l:find("leaf") or l:find("canopy") or l:find("pine") or l:find("foliage") or l:find("bush") then
			return "T"
		elseif l:find("road") or l:find("path") or l:find("bridge") or l:find("plaza") then
			return "R"
		elseif l:find("crystal") then
			return "C"
		elseif l:find("/hub") or l:find("struct_") or l:find("landmark") or l:find("bossgate") or l:find("sealed") or l:find("station") or l:find("altar") or l:find("merchant") or l:find("halloffame") or l:find("gatepillars") then
			-- 그 자리 지형보다 3 stud 이상 솟은 파트 = 건물 B · 낮은 판(바닥 · 광장 · 계단) = 허브 광장 H(허브) · 기타 P
			local ty = hitPos and terrainY(hitPos.X, hitPos.Z)
			if ty and hitPos.Y - ty >= 3 and not (l:find("floor") or l:find("plaza")) then
				return "B"
			end
			return l:find("/hub") and "H" or "P"
		end
		return "P"
	end

	local rows = {}
	for z = ROW0, math.min(N - 1, ROW0 + ROWS - 1) do
		local wz = -EDGE + (z + 0.5) * (2 * EDGE / N)
		local out, last, run = {}, nil, 0
		local function flush()
			if last then
				table.insert(out, run > 1 and (last .. "~" .. run .. ";") or last)
			end
		end
		local SEG = 256 -- Studio 로그가 약 1,000자에서 줄을 자른다 → 한 줄을 x 256칸 조각으로 나눠 찍는다("[MAPGEN] z.조각:압축")
		for x = 0, N - 1 do
			if x > 0 and x % SEG == 0 then
				flush()
				print(("[MAPGEN] %d.%d:%s"):format(z, x // SEG - 1, table.concat(out)))
				out, last, run = {}, nil, 0
			end
			local wx = -EDGE + (x + 0.5) * (2 * EDGE / N)
			local origin = Vector3.new(wx, 1600, wz)
			local cell = "X" .. string.char(40)
			for _ = 1, 4 do
				local hit = workspace:Raycast(origin, Vector3.new(0, -3200, 0), params)
				if not hit then
					break
				end
				local inst = hit.Instance
				local pc = inst ~= workspace.Terrain and inst:IsA("BasePart") and classOfPart(inst, hit.Position) or nil
				-- 다시 쏘기(그 밑 지형): 투명 · 둥지 이름 파트 · 소품(P - 바위 · 수정 기둥 같은 들판 소품은 지도에 안 그린다) · 나무가 아닌 안 막는 파트
				--   QUEUE-ALL7B 3b: 허브 건물 충돌 상자(HubBuilding)는 메시를 입으면 투명이지만 건물 자리 = 그대로 B
				if pc and ((inst.Transparency > 0.85 and not inst:GetAttribute("HubBuilding")) or inst.Name:match("^Nest") or pc == "P" or (not inst.CanCollide and pc ~= "T")) then
					origin = hit.Position - Vector3.new(0, 0.05, 0)
				else
					local c = pc or (TERRAIN[hit.Material] or "G")
					local h = math.clamp(math.floor((hit.Position.Y - Y0) / YSTEP), 0, 85)
					cell = c .. string.char(40 + h)
					break
				end
			end
			if cell == last then
				run += 1
			else
				flush()
				last, run = cell, 1
			end
		end
		flush()
		print(("[MAPGEN] %d.%d:%s"):format(z, (N - 1) // SEG, table.concat(out)))
		rows[#rows + 1] = z
	end
	return ("rows %d"):format(#rows)
end
