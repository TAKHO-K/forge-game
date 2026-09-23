-- 성능 기준선 측정(P2.5a B - docs/perf/baseline.md). 개발자 · Studio 전용 - DevTools.server.lua만 부른다(`/gg perf` · Play 전 edit 모드에서
-- ReplicatedStorage Attribute `PerfAutoRunUntil`(os.time() 기준 만료 시각)을 켜 두면 접속 25초 뒤 자동 실행). 게임 판정은 바꾸지 않는다.
--
-- 장면(workspace Attribute `PerfScene` - 클라 수집기가 이 값으로 장면을 나눈다): town(중앙 안전지대) → hunt(사냥 구역, 평타 부하) →
-- transition(일반 스테이지 전환 20회) → boss(보스 스폰 → 보스전 → 퇴장). 장면마다 서버 줄 `[PERF] scene=… key=value …`를 찍는다.
-- 사냥 부하: 가장 가까운 잡몹에게 직업 평타 쿨다운마다 "최대 HP ÷ hitsPerKill" 피해 - 실제 평타 경로(AttackServer)와 같은 세 단계
-- (MonsterState.applyDamage → AttackResult:FireClient → CombatResolution.resolveHit)를 그대로 부른다(클라 데미지 숫자 · 피격 연출 · 드랍 · 리스폰까지 실제와 같다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local CollectionService = game:GetService("CollectionService")

local WorldConfig = require(ReplicatedStorage.Shared.data.WorldConfig)
local BossData = require(ReplicatedStorage.Shared.data.BossData)
local PlayerCombat = require(ReplicatedStorage.Shared.PlayerCombat)
local InfiniteStage = require(ReplicatedStorage.Shared.InfiniteStage)
local PlayerProfile = require(script.Parent.PlayerProfile)
local MonsterState = require(script.Parent.MonsterState)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local CombatResolution = require(script.Parent.CombatResolution)
local BossEncounter = require(script.Parent.BossEncounter)
local TutorialState = require(script.Parent.TutorialState)

local PerfProbe = {}

local SAMPLE_SECONDS = { town = 10, hunt = 15, boss = 12 }
local HITS_PER_KILL = 6
local HUNT_ZONE_INDEX = 3 -- tierZoneOrder의 세 번째 구역(오크) - 가운데 구역

local remoteCounts = {}
local hooked = false

local function hookRemotes()
	if hooked then
		return
	end
	hooked = true
	for _, inst in ipairs(ReplicatedStorage:GetDescendants()) do
		if inst:IsA("RemoteEvent") then
			inst.OnServerEvent:Connect(function()
				local scene = workspace:GetAttribute("PerfScene") or "-"
				remoteCounts[scene] = (remoteCounts[scene] or 0) + 1
			end)
		end
	end
end

local function countInstances()
	local total, parts = 0, 0
	for _, inst in ipairs(workspace:GetDescendants()) do
		total += 1
		if inst:IsA("BasePart") then
			parts += 1
		end
	end
	return total, parts
end

local function percentile(list, p)
	if #list == 0 then
		return 0
	end
	local sorted = table.clone(list)
	table.sort(sorted)
	return sorted[math.clamp(math.ceil(#sorted * p), 1, #sorted)]
end

local function teleport(player, position)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

-- seconds 동안 서버 Heartbeat 간격 · Stats를 모은다. tick(dt)가 있으면 매 Heartbeat 부른다(부하 발생기).
local function sample(scene, seconds, tick)
	workspace:SetAttribute("PerfScene", scene)
	remoteCounts[scene] = 0
	local dts, hbMs = {}, {}
	local memMax = 0
	local conn = RunService.Heartbeat:Connect(function(dt)
		table.insert(dts, dt * 1000)
		table.insert(hbMs, Stats.HeartbeatTimeMs)
		if tick then
			tick(dt)
		end
	end)
	local t0 = os.clock()
	while os.clock() - t0 < seconds do
		memMax = math.max(memMax, Stats:GetTotalMemoryUsageMb())
		task.wait(0.5)
	end
	conn:Disconnect()
	local elapsed = os.clock() - t0
	local total, parts = countInstances()
	local sum = 0
	for _, v in ipairs(dts) do
		sum += v
	end
	local hbSum = 0
	for _, v in ipairs(hbMs) do
		hbSum += v
	end
	local line = ("[PERF] scene=%s seconds=%.1f frameMsAvg=%.2f frameMsP95=%.2f frameMsMax=%.2f heartbeatMsAvg=%.2f heartbeatMsP95=%.2f memMb=%.0f instances=%d parts=%d monsters=%d remotesInPerSec=%.1f"):format(
		scene, elapsed, sum / math.max(1, #dts), percentile(dts, 0.95), percentile(dts, 1),
		hbSum / math.max(1, #hbMs), percentile(hbMs, 0.95), memMax, total, parts,
		#CollectionService:GetTagged("Monster"), (remoteCounts[scene] or 0) / elapsed)
	print(line)
	return line
end

local function nearestMonster(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, model in ipairs(MonsterState.getAllModels()) do
		local data = MonsterState.getData(model)
		if data and not data.isBoss and not data.isChest and model.PrimaryPart then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = model, d
			end
		end
	end
	return best
end

-- 사냥 부하: 직업 평타 쿨다운마다 가장 가까운 잡몹을 때린다(서버 · 클라 경로 = 실제 평타와 같다).
local function huntLoad(player)
	local attackResult = ReplicatedStorage:WaitForChild("AttackResult")
	local cooldown = PlayerCombat.getAttackCooldown(PlayerProfile.getClassId(player), 0)
	local acc = 0
	local hits, kills = 0, 0
	local function tick(dt)
		acc += dt
		if acc < cooldown then
			return
		end
		acc -= cooldown
		local target = nearestMonster(player)
		if not target then
			return
		end
		local stage = TutorialState.getMonsterStage(player)
		local prefix = MonsterState.getPrefix(target)
		local maxHp = InfiniteStage.getMonsterHp(MonsterState.getData(target).hp, stage) * (prefix and prefix.hpMultiplier or 1)
		local isDead, dealt = MonsterState.applyDamage(target, maxHp / HITS_PER_KILL, stage, player)
		MonsterSpawner.updateHpLabel(target)
		hits += 1
		if isDead then
			kills += 1
		end
		attackResult:FireClient(player, target, dealt or maxHp / HITS_PER_KILL, false, isDead, false, false, false)
		CombatResolution.resolveHit(player, target, isDead)
	end
	return tick, function()
		return hits, kills
	end
end

function PerfProbe.run(player)
	assert(RunService:IsStudio(), "PerfProbe: Studio 전용")
	hookRemotes()
	print("[PERF] 시작 - " .. player.Name)
	local originalStage = PlayerProfile.getInfiniteStage(player) or 1
	if BossEncounter.getActive(player) then
		BossEncounter.despawnFor(player)
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	-- 1) 마을(중앙 안전지대)
	PlayerProfile.setInfiniteStage(player, 1)
	teleport(player, WorldConfig.zones.spawn.center + Vector3.new(0, 5, 0))
	task.wait(4)
	sample("town", SAMPLE_SECONDS.town)

	-- 2) 사냥(가운데 tier 구역 중심 - 격자 9마리가 둘러싼 자리). 스테이지 1이라 플레이어가 죽지 않는다.
	local zoneKey = WorldConfig.tierZoneOrder[HUNT_ZONE_INDEX]
	teleport(player, WorldConfig.zones[zoneKey].center + Vector3.new(0, 5, 0))
	task.wait(4)
	local tick, counts = huntLoad(player)
	sample("hunt", SAMPLE_SECONDS.hunt, tick)
	local hits, kills = counts()
	print(("[PERF] scene=hunt hits=%d kills=%d hitsPerKill=%d"):format(hits, kills, HITS_PER_KILL))

	-- 3) 일반 스테이지 전환 20회(잡몹 스테이지 사이 - StageServer.performMove가 하는 일 = setInfiniteStage뿐)
	workspace:SetAttribute("PerfScene", "transition")
	local before = countInstances()
	local t0 = os.clock()
	for i = 1, 20 do
		PlayerProfile.setInfiniteStage(player, (i % 4) + 1)
	end
	local trashMs = (os.clock() - t0) * 1000 / 20
	task.wait(1)
	local after = countInstances()
	print(("[PERF] scene=transition kind=trash perMoveMs=%.4f instanceDelta=%d"):format(trashMs, after - before))

	-- 4) 보스 스테이지 진입(스폰) → 보스전 → 퇴장(파괴). 스폰 · 파괴 시간과 인스턴스 증감.
	local bossStage = BossData.stageInterval * 3
	teleport(player, WorldConfig.zones.spawn.center + Vector3.new(0, 5, 0))
	task.wait(2)
	workspace:SetAttribute("PerfScene", "bossSpawn")
	before = countInstances()
	t0 = os.clock()
	PlayerProfile.setInfiniteStage(player, bossStage)
	BossEncounter.spawnFor(player, bossStage)
	local spawnMs = (os.clock() - t0) * 1000
	local afterSpawn = countInstances()
	print(("[PERF] scene=transition kind=bossSpawn ms=%.2f instanceDelta=%d"):format(spawnMs, afterSpawn - before))
	task.wait(3)
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	sample("boss", SAMPLE_SECONDS.boss)
	workspace:SetAttribute("PerfScene", "bossDespawn")
	local beforeDespawn = countInstances()
	t0 = os.clock()
	BossEncounter.despawnFor(player)
	local despawnMs = (os.clock() - t0) * 1000
	task.wait(1)
	print(("[PERF] scene=transition kind=bossDespawn ms=%.2f instanceDelta=%d(1초 뒤)"):format(despawnMs, countInstances() - beforeDespawn))

	PlayerProfile.setInfiniteStage(player, originalStage)
	workspace:SetAttribute("PerfScene", "done")
	print("[PERF] 끝")
end

return PerfProbe
