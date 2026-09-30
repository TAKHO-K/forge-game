-- QUEUE-ALL1 ★0 길 안내 자동 검사(수동 호출 - 서버 execute_luau에서 require(...).run()). 서버는 맵 전체가 있어(스트리밍 없음) 끝까지 지면을 읽는다.
--   6구역 × 시작점 perZone개: 길 주변 후보를 뿌려 언덕 꼭대기 · 절벽 · 나무 옆 · 물가 · 무작위로 고른다 → GuidePath.build(클라와 같은 코드)로 관문까지 경로 →
--   점 · 선분 가운데가 지면 아래인 수(under) = 0이어야 통과. 길찾기 성공 · 지면 못 읽은 점 · 가파른 선분(벽 오르기)도 센다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local GuidePath = require(ReplicatedStorage.Shared.GuidePath)
local RoadNet = require(ReplicatedStorage.Shared.RoadNet)
local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local GuideVerify = {}

local KINDS = { "hill", "cliff", "tree", "water", "random" }

local function params()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(list, p.Character)
		end
	end
	return GuidePath.rayParams(list)
end

local function hitAt(pos, rp)
	return Workspace:Raycast(Vector3.new(pos.X, pos.Y + 120, pos.Z), Vector3.new(0, -400, 0), rp)
end

-- 후보 한 곳의 성질(높이 · 둘레 높이 차 · 물 · 나무)
local function describe(pos, road, rp, trunks)
	local hit = hitAt(pos, rp)
	if not hit then
		return nil
	end
	local y = hit.Position.Y
	local relief, water = 0, hit.Material == Enum.Material.Water
	for k = 0, 7 do
		local a = k * math.pi / 4
		local q = pos + Vector3.new(math.cos(a) * 6, 0, math.sin(a) * 6)
		local h = hitAt(q, rp)
		if h then
			relief = math.max(relief, math.abs(h.Position.Y - y))
			water = water or h.Material == Enum.Material.Water
		end
	end
	local i = GuidePath.nextIndex(road, pos)
	local tree = false
	for _, t in ipairs(trunks) do
		if (Vector3.new(t.X - pos.X, 0, t.Z - pos.Z)).Magnitude <= 10 then
			tree = true
			break
		end
	end
	return { pos = Vector3.new(pos.X, y + 0.1, pos.Z), above = y - road[i].Y, relief = relief, water = water and hit.Material ~= Enum.Material.Water, tree = tree, onWater = hit.Material == Enum.Material.Water }
end

function GuideVerify.pickStarts(zone, road, perZone, rng, rp, trunks)
	local cands = {}
	for _ = 1, perZone * 14 do
		local base = road[rng:NextInteger(1, #road)]
		local a = rng:NextNumber() * math.pi * 2
		local d = rng:NextNumber(12, 280)
		local c = describe(base + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d), road, rp, trunks)
		if c and not c.onWater then
			table.insert(cands, c)
		end
	end
	-- 나무 옆은 후보가 드물어 줄기 둘레에서 따로 뽑는다
	for _, t in ipairs(trunks) do
		if (Vector3.new(t.X, 0, t.Z) - Vector3.new(road[#road].X, 0, road[#road].Z)).Magnitude < 2600 and GuidePath.nextIndex(road, t) and #cands < perZone * 20 then
			local a = rng:NextNumber() * math.pi * 2
			local c = describe(t + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5), road, rp, trunks)
			if c and not c.onWater and c.tree then
				local i = GuidePath.nextIndex(road, c.pos)
				if (Vector3.new(road[i].X - c.pos.X, 0, road[i].Z - c.pos.Z)).Magnitude < 320 then
					table.insert(cands, c)
				end
			end
		end
	end
	local picks, used = {}, {}
	local quota = math.ceil(perZone / #KINDS)
	local function take(kind, score)
		table.sort(cands, function(x, y)
			return score(x) > score(y)
		end)
		local n = 0
		for _, c in ipairs(cands) do
			if n >= quota then
				break
			end
			if not used[c] and score(c) > -math.huge then
				used[c] = true
				n += 1
				table.insert(picks, { kind = kind, pos = c.pos, above = c.above, relief = c.relief })
			end
		end
	end
	take("hill", function(c) return c.above end)
	take("cliff", function(c) return c.relief end)
	take("tree", function(c) return c.tree and 1 or -math.huge end)
	take("water", function(c) return c.water and 1 or -math.huge end)
	for _, c in ipairs(cands) do
		c.r = rng:NextNumber()
	end
	take("random", function(c) return c.r end)
	quota = perZone - #picks -- 나무 · 물가 후보가 없는 구역은 무작위로 채운다
	take("random", function(c) return c.r end)
	return picks
end

-- 반환 { rows = { 구역별 요약 }, fails = { 실패 시작점 } }
function GuideVerify.run(opts)
	opts = opts or {}
	local perZone = opts.perZone or 55
	local rng = Random.new(opts.seed or 20260930)
	local rp = params()
	local trunks = {}
	for _, d in ipairs(Workspace:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Trunk" and d.CanCollide then
			table.insert(trunks, d.Position)
		end
	end
	local rows, fails = {}, {}
	for _, zone in ipairs(WorldMapData.zones) do
		if not opts.zone or opts.zone == zone.key then
			local road = RoadNet.guidePoints(zone)
			local starts = GuideVerify.pickStarts(zone, road, perZone, rng, rp, trunks)
			local row = { zone = zone.key, starts = #starts, pass = 0, pathfound = 0, under = 0, unground = 0, steep = 0, drops = 0, dropRoutes = 0, endGap = 0, maxStep = 0, minGap = math.huge, kinds = {} }
			for _, s in ipairs(starts) do
				local route = GuidePath.build(s.pos, road, rp, math.huge)
				local minGap, under = GuidePath.clearance(route, rp)
				local hidden, longest = GuidePath.hiddenRuns(route, rp)
				row.hidden = (row.hidden or 0) + hidden
				row.longestHidden = math.max(row.longestHidden or 0, longest)
				-- 묻힌 점 · 조각은 그리지 않는다(segmentVisible) → 화면에 보이는 묻힌 조각 = 0. 통과 = 숨긴 구간이 짧다(안내가 끊겨 보이지 않음)
				local gapOk = longest <= WorldMapData.guide.maxHiddenStuds
				local unground, steep, drops = 0, 0, 0
				local treeR = WorldMapData.progress.treeRadius
				-- 이어짐: 끝점 = 관문(길 마지막 점) · 이웃 점 수평 간격 최대(끊긴 곳 없음)
				local last = route.points[#route.points]
				row.endGap = math.max(row.endGap, Vector3.new(last.X - road[#road].X, 0, last.Z - road[#road].Z).Magnitude)
				for k = 1, #route.points do
					unground += route.ok[k] and 0 or 1
					if k > 1 then
						local a, b = route.points[k - 1], route.points[k]
						local h = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
						row.maxStep = math.max(row.maxStep, h)
						-- 낙하 피해 높이를 넘는 내려감(나무 둘레 · 물 제외 전 - 정보)
						if a.Y - b.Y > MovementConfig.fall.safeHeight and Vector3.new(a.X, 0, a.Z).Magnitude > treeR then
							drops += 1
						end
						if math.abs(b.Y - a.Y) > math.max(h, 1) * WorldMapData.guide.steepRatio then
							steep += 1
						end
					end
				end
				row.kinds[s.kind] = (row.kinds[s.kind] or 0) + 1
				row.pathfound += route.pathfound and 1 or 0
				row.under += under
				row.unground += unground
				row.steep += steep
				row.drops += drops
				row.dropRoutes += drops > 0 and 1 or 0
				row.minGap = math.min(row.minGap, minGap)
				if gapOk and unground == 0 then
					row.pass += 1
				else
					local at = {}
					for k = 1, #route.points do
						if GuidePath.buried(route.points[k], rp) or (k > 1 and GuidePath.buried((route.points[k] + route.points[k - 1]) / 2, rp)) then
							table.insert(at, ("k%d/%d(%.0f,%.1f,%.0f)"):format(k, route.joinIndex, route.points[k].X, route.points[k].Y, route.points[k].Z))
						end
					end
					table.insert(fails, { zone = zone.key, kind = s.kind, pos = s.pos, under = under, unground = unground, minGap = minGap, at = table.concat(at, " ") })
				end
				task.wait()
			end
			table.insert(rows, row)
		end
	end
	return { rows = rows, fails = fails }
end

-- 자동 이동 도착률(봇 = 실제 client/AutoWalk): 시작점마다 순간이동 → 목적지 = 길 합류점 + roadAhead점(약 24 stud 간격) → 복제 Attribute로 클라 안내 · 자동 이동 켜기 →
--   도착(목적지 arriveStuds + 2 안) · 멈춤(stillSeconds 동안 1 stud 미만 이동) · 시간 초과(경로 길이 ÷ 10 + 40초). 한 명(Studio Play 개발 계정)으로 돈다.
--   반환 { rows = { zone, kind, arrived, seconds, left } } - 멈춘 이유는 클라 Attribute AutoWalkStop(로컬)이라 클라 쪽에서 따로 모은다.
function GuideVerify.walkBot(opts)
	local player = Players:GetPlayers()[1]
	local character = player and player.Character
	if not character then
		return { error = "no character" }
	end
	local root = character:WaitForChild("HumanoidRootPart")
	local rng = Random.new(opts.seed or 20260930)
	local rp = params()
	local rows = {}
	for _, zone in ipairs(WorldMapData.zones) do
		if not opts.zone or opts.zone == zone.key then
			local road = RoadNet.guidePoints(zone)
			local starts = GuideVerify.pickStarts(zone, road, opts.perZone or 5, rng, rp, {})
			for n, s in ipairs(starts) do
				if n > (opts.perZone or 5) then
					break
				end
				root.Anchored = true
				character:PivotTo(CFrame.new(s.pos + Vector3.new(0, 3.5, 0)))
				task.wait(2.5)
				root.Anchored = false
				local i = GuidePath.nextIndex(road, s.pos)
				local parts, len = {}, 0
				local last = math.min(#road, i + (opts.roadAhead or 10))
				for k = 1, last do
					table.insert(parts, ("%.2f,%.2f,%.2f"):format(road[k].X, road[k].Y, road[k].Z))
					if k > i then
						len += (road[k] - road[k - 1]).Magnitude
					end
				end
				len += (road[i] - s.pos).Magnitude
				local goal = road[last]
				player:SetAttribute("GuideDebugPoints", table.concat(parts, ";"))
				task.wait(1.5)
				player:SetAttribute("AutoWalkDebug", os.clock())
				local t0, stillAt, stillPos = os.clock(), os.clock(), root.Position
				local limit = len / 10 + 40
				local result = "timeout"
				while os.clock() - t0 < limit do
					task.wait(0.5)
					if (Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)).Magnitude <= WorldMapData.guide.arriveStuds + 2 then
						result = "arrived"
						break
					end
					if (root.Position - stillPos).Magnitude >= 1 then
						stillPos, stillAt = root.Position, os.clock()
					elseif os.clock() - stillAt >= (opts.stillSeconds or 12) then
						result = "stopped"
						break
					end
				end
				table.insert(rows, { zone = zone.key, kind = s.kind, result = result, seconds = os.clock() - t0, left = (Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)).Magnitude, len = len, start = s.pos })
				player:SetAttribute("AutoWalkDebug", nil)
				player:SetAttribute("GuideDebugPoints", "")
				task.wait(0.5)
			end
		end
	end
	return { rows = rows }
end

return GuideVerify
