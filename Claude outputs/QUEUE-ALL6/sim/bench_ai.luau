-- B3 마이크로 벤치: MonsterAI 어그로 탐색(옛 = 몬스터마다 GetPlayers · FindFirstChild · canChase 먼저 / 새 = 틱 목록 · 거리 먼저)
local NP, NM, TICKS = 24, 130, 2000
local function vec(x, z) return { X = x, Y = 0, Z = z } end
local players = {}
for i = 1, NP do
	local root = { Position = vec(math.random(-1500, 1500), math.random(-1500, 1500)), Parent = true }
	local char = { HumanoidRootPart = root }
	function char:FindFirstChild(n) return self[n] end
	players[i] = { Character = char }
end
local function GetPlayers() local t = table.create(NP) for i = 1, NP do t[i] = players[i] end return t end
local mobs = {}
for i = 1, NM do mobs[i] = vec(math.random(-1500, 1500), math.random(-1500, 1500)) end
local function hdist(a, b) local dx, dz = a.X - b.X, a.Z - b.Z return math.sqrt(dx * dx + dz * dz) end
local function sameLayer() return true end
local function canChase() -- MobShare.refresh + isBlocked + tooWeakFor 대역(표 몇 번 읽기)
	local s = 0 for k = 1, 12 do s += k end return s > 0
end
local function stage() return 100 end
local function oldScan(pos, range)
	local nr, np, nd = nil, nil, math.huge
	for _, p in ipairs(GetPlayers()) do
		local c = p.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if r and canChase(nil, p, stage(p)) then
			local d = hdist(r.Position, pos)
			if d <= range and d < nd and sameLayer() then nr, np, nd = r, p, d end
		end
	end
	return np, nr
end
local tick = {}
local function newScan(pos, range)
	local nr, np, nd = nil, nil, math.huge
	for _, e in ipairs(tick) do
		local r = e.root
		if r.Parent then
			local d = hdist(r.Position, pos)
			if d <= range and d < nd and sameLayer() and canChase(nil, e.player, stage(e.player)) then nr, np, nd = r, e.player, d end
		end
	end
	return np, nr
end
local t0 = os.clock()
for _ = 1, TICKS do for _, m in ipairs(mobs) do oldScan(m, 40) end end
local tOld = os.clock() - t0
t0 = os.clock()
for _ = 1, TICKS do
	table.clear(tick)
	for _, p in ipairs(GetPlayers()) do local r = p.Character:FindFirstChild("HumanoidRootPart") if r then table.insert(tick, { player = p, root = r }) end end
	for _, m in ipairs(mobs) do newScan(m, 40) end
end
local tNew = os.clock() - t0
-- 결과 같음 확인
local same = true
table.clear(tick) for _, p in ipairs(players) do table.insert(tick, { player = p, root = p.Character.HumanoidRootPart }) end
for _, m in ipairs(mobs) do local a = oldScan(m, 400) local b = newScan(m, 400) if a ~= b then same = false end end
print(("[B3] %d인 · 몬스터 %d · %d틱: 옛 %.3f ms/틱 · 새 %.3f ms/틱 (%.0f%% 감소) · 고른 대상 같음 %s"):format(NP, NM, TICKS, tOld / TICKS * 1000, tNew / TICKS * 1000, (1 - tNew / tOld) * 100, tostring(same)))
