-- BR1-2 수정 여왕 환경 변화 "수정 부수기"(docs/design/boss-br1-2.md §6-4 · 사용자 보강 C) - 점프맵 · 수정 · 투명 벽 · 체크포인트(서버 파트).
--   서버 시작: BossJumpMapData의 코스 전부를 ServerStorage.BossJumpMaps에 모델로 짓는다(평소엔 저장 공간 - 아레나에 없다).
--   환경 변화 때: 수정 자리 2곳(서로 반대 방위)마다 코스 1개를 무작위로(서로 다른 것) 꺼내 복제 → 발판을 자리에 맞춰 놓는다(Workspace.Ground - 서버 지면 탐지 · 높이 검증이 지면으로 본다).
--     마지막 발판 = 수정(구출 대상과 같은 타격 대상 - 평타 · 스킬 · 투사체 · 1인 hitIntervalSeconds에 1번 · hits번이면 깨진다).
--     아레나 가장자리에 투명 벽(원을 도는 조각 - 끝나면 치운다) · 체크포인트 발판을 밟은 사람은 코스에서 떨어지면 그 체크포인트로 돌아간다(그 코스의 수정이 깨지기 전까지).
--   두 수정이 다 깨지면 성공(BossEnvironment가 보호막을 풀고 끝낸다). 시간 제한 없음.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local BossJumpMapData = require(ReplicatedStorage.Shared.data.BossJumpMapData)
local BossJumpCourseMath = require(ReplicatedStorage.Shared.BossJumpCourseMath)
local MonsterSpawner = require(script.Parent.MonsterSpawner)
local GroundProbe = require(script.Parent.GroundProbe)
local HeightGuard = require(script.Parent.HeightGuard)
local LaunchPermit = require(script.Parent.LaunchPermit) -- M1-2c
local JumpMath = require(ReplicatedStorage.Shared.JumpMath)
local ROOT_ABOVE = require(ReplicatedStorage.Shared.data.MovementConfig).rootAboveFeetStuds

local BossJumpCourse = {}

local rng = Random.new()
local STEP_COLOR = Color3.fromRGB(150, 110, 200)
local CHECKPOINT_COLOR = Color3.fromRGB(110, 210, 150)

-- ─────────────────────────── 저장 공간(서버 시작 때 한 번) ───────────────────────────
local storage = ServerStorage:FindFirstChild("BossJumpMaps") or Instance.new("Folder")
storage.Name = "BossJumpMaps"
storage.Parent = ServerStorage
for index, course in ipairs(BossJumpMapData.courses) do
	local model = Instance.new("Model")
	model.Name = ("Course%d_%s"):format(index, course.name)
	for _, p in ipairs(BossJumpCourseMath.layout(course)) do
		local part = Instance.new("Part")
		part.Name = ("Step%d"):format(p.index)
		part.Anchored = true
		part.Size = Vector3.new(p.width, BossJumpMapData.platformThicknessStuds, p.width)
		part.CFrame = CFrame.new(p.position - Vector3.new(0, BossJumpMapData.platformThicknessStuds / 2, 0))
		part.Material = p.checkpoint and Enum.Material.Neon or Enum.Material.Glass
		part.Color = p.checkpoint and CHECKPOINT_COLOR or STEP_COLOR
		part.Transparency = p.checkpoint and 0.2 or 0.1
		part.TopSurface = Enum.SurfaceType.Smooth
		part:SetAttribute("Checkpoint", p.checkpoint or nil)
		part:SetAttribute("Crystal", p.crystal or nil)
		part.Parent = model
	end
	model.Parent = storage
end

-- ─────────────────────────── 환경 변화 한 번 ───────────────────────────
local active = {} -- [보스 Model] = { parts, walls, crystals = { [i] = { model, hits, lastBy, broken, position } }, checkpoints = { [player] = { course, position } }, courseParts = { [i] = { Part } } }

-- 두 자리의 배치(순수 - 전조 때 클라에 보낸다). 반환 = { { courseIndex, siteAngle, platforms = { { index, position, width, checkpoint, crystal } } }, ... }
function BossJumpCourse.plan(center, floorY, arenaRadius)
	local base = rng:NextNumber(0, 2 * math.pi)
	local first = rng:NextInteger(1, #BossJumpMapData.courses)
	local second = first
	while second == first and #BossJumpMapData.courses > 1 do
		second = rng:NextInteger(1, #BossJumpMapData.courses)
	end
	local plan = {}
	for site, courseIndex in ipairs({ first, second }) do
		local angle = base + (site - 1) * math.pi
		local platforms = BossJumpCourseMath.place(BossJumpMapData.courses[courseIndex], angle, center, floorY, arenaRadius)
		table.insert(plan, { courseIndex = courseIndex, name = BossJumpMapData.courses[courseIndex].name, siteAngle = angle, platforms = platforms or {} })
	end
	return plan
end

local function buildWalls(center, floorY, radius, height)
	local walls = {}
	local n = 36
	for i = 1, n do
		local a = (i - 0.5) / n * 2 * math.pi
		local wall = Instance.new("Part")
		wall.Name = "BossArenaWall"
		wall.Anchored = true
		wall.CanCollide = true
		wall.Transparency = 1
		wall.Size = Vector3.new(radius * 2 * math.pi / n + 1, height, 2)
		wall.CFrame = CFrame.new(center.X + math.cos(a) * (radius + 1), floorY + height / 2, center.Z + math.sin(a) * (radius + 1)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		wall.Parent = Workspace
		table.insert(walls, wall)
	end
	return walls
end

-- 활성 순간: 저장 공간의 코스를 복제해 놓고 · 수정 · 벽을 세운다. onCrystal(index, broken) = 수정이 맞을 때마다.
function BossJumpCourse.build(model, plan, center, floorY, arenaRadius, zoneKey, spec, onCrystal, onHelp)
	BossJumpCourse.clear(model)
	local state = { parts = {}, walls = {}, crystals = {}, checkpoints = {}, courseParts = {}, plan = plan, builtAt = os.clock(), helpStage = 0, onHelp = onHelp, floorY = floorY, pads = {} }
	active[model] = state
	for site, course in ipairs(plan) do
		local source = storage:FindFirstChild(("Course%d_%s"):format(course.courseIndex, course.name))
		local clone = source and source:Clone()
		state.courseParts[site] = {}
		for _, p in ipairs(course.platforms) do
			local part = clone and clone:FindFirstChild(("Step%d"):format(p.index))
			if part then
				part.CFrame = CFrame.new(p.position - Vector3.new(0, BossJumpMapData.platformThicknessStuds / 2, 0))
				part:SetAttribute("CourseSite", site)
				part.Parent = GroundProbe.folder()
				table.insert(state.parts, part)
				table.insert(state.courseParts[site], part)
			end
			if p.crystal then
				local crystal = { hits = 0, lastBy = {}, broken = false, position = p.position }
				state.crystals[site] = crystal
				crystal.model = MonsterSpawner.spawnRescueTarget({
					displayName = "수정",
					color = spec.color,
					bodyAspect = Vector3.new(1.2, 1.6, 1.2),
					footPosition = p.position,
					onHit = function(hitter)
						local now = os.clock()
						if crystal.broken or active[model] ~= state or (crystal.lastBy[hitter] and now - crystal.lastBy[hitter] < BossJumpMapData.crystal.hitIntervalSeconds) then
							return
						end
						crystal.lastBy[hitter] = now
						crystal.hits += 1
						if crystal.hits >= BossJumpMapData.crystal.hits then
							crystal.broken = true
							MonsterSpawner.removeRescueTarget(crystal.model)
						end
						onCrystal(site, crystal.broken, crystal.hits)
					end,
					remaining = function()
						return 1 - crystal.hits / BossJumpMapData.crystal.hits
					end,
				}, zoneKey)
			end
		end
		if clone then
			clone:Destroy() -- 발판은 Ground로 옮겼다 - 빈 껍데기만 남는다
		end
	end
	state.walls = buildWalls(center, floorY, arenaRadius, spec.wallHeightStuds)
	return state
end

function BossJumpCourse.brokenCount(model)
	local state = active[model]
	local n = 0
	for _, crystal in pairs(state and state.crystals or {}) do
		n += crystal.broken and 1 or 0
	end
	return n, state and #state.plan or 0
end

-- ─────────────────────────── BR1-2 도움 단계(BossJumpMapData.help) ───────────────────────────
local CollectionService = game:GetService("CollectionService")
local HELP = BossJumpMapData.help

local function newPad(name, size, position, color)
	local pad = Instance.new("Part")
	pad.Name = name
	pad.Anchored = true
	pad.Size = size
	pad.CFrame = CFrame.new(position)
	pad.Material = Enum.Material.Neon
	pad.Color = color
	pad.TopSurface = Enum.SurfaceType.Smooth
	CollectionService:AddTag(pad, "BossJumpPad") -- 클라 BossEnvironmentView가 밟은 사람을 띄운다(LaunchHeight · LaunchTarget)
	pad.Parent = GroundProbe.folder()
	return pad
end

-- M1-2c 발사 허가: 클라(BossEnvironmentView)가 발판 위 루트(발판 중심 위 0 ~ 5)에서 띄우는 것과 같은 식의 최고 발 높이 + 공중 점프 몫
function BossJumpCourse.padLaunchSpec(pad)
	local PL = BossJumpMapData.padLaunch
	local top = pad.Position.Y + pad.Size.Y / 2
	local rootMax = pad.Position.Y + PL.probeRootStuds -- 클라가 "밟았다"로 읽는 루트 높이 상한
	local target = pad:GetAttribute("LaunchTarget")
	local apexFeet
	if typeof(target) == "Vector3" then
		apexFeet = math.max(pad:GetAttribute("LaunchApexY") or target.Y + PL.defaultApexAboveTargetStuds, rootMax + PL.apexMinAboveRootStuds, target.Y + PL.targetClearStuds) - ROOT_ABOVE
	else
		apexFeet = rootMax - ROOT_ABOVE + (pad:GetAttribute("LaunchHeight") or PL.defaultBoostHeightStuds)
	end
	return { top = top, center = pad.Position, radius = math.max(pad.Size.X, pad.Size.Z) / 2, apexFeetY = apexFeet + JumpMath.airJumpsOnlyStuds(), source = "수정 부수기 " .. pad.Name }
end

local function registerPad(pad)
	LaunchPermit.register(pad, BossJumpCourse.padLaunchSpec(pad))
end

-- 1단계: 코스 발판 boostEvery칸마다 윗면에 높이 점프 발판(마지막 수정 발판 제외).
local function helpStage1(state)
	local placed = {}
	for site, course in ipairs(state.plan) do
		for _, p in ipairs(course.platforms) do
			if not p.crystal and (p.index % HELP.boostEvery) == 1 then
				local pad = newPad("CourseBoostPad", Vector3.new(HELP.boostPadStuds, 0.3, HELP.boostPadStuds), p.position + Vector3.new(0, 0.15, 0), Color3.fromRGB(120, 230, 255))
				pad:SetAttribute("LaunchHeight", HELP.boostHeightStuds)
				pad:SetAttribute("CourseSite", site)
				registerPad(pad)
				table.insert(state.parts, pad)
				table.insert(state.pads, pad)
				table.insert(placed, pad.Position)
			end
		end
	end
	return placed
end

-- 2단계: 코스 시작 곁 바닥에 발사 발판 - 수정 발판 윗면 + 3을 겨눈다(클라가 포물선 속도를 계산 - LaunchTarget · LaunchApex).
function BossJumpCourse.launchPadFor(course, floorY)
	local first, crystal = course.platforms[1], nil
	for _, p in ipairs(course.platforms) do
		if p.crystal then
			crystal = p
		end
	end
	if not (first and crystal) then
		return nil
	end
	local away = Vector3.new(first.position.X - crystal.position.X, 0, first.position.Z - crystal.position.Z)
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.new(1, 0, 0)
	local at = Vector3.new(first.position.X, floorY, first.position.Z) + away * HELP.launchOffsetStuds
	return at, crystal.position + Vector3.new(0, 3, 0), crystal.position.Y + HELP.launchApexAboveStuds
end

local function helpStage2(state)
	local placed = {}
	for site, course in ipairs(state.plan) do
		local at, target, apexY = BossJumpCourse.launchPadFor(course, state.floorY)
		if at then
			local pad = newPad("CourseLaunchPad", Vector3.new(HELP.launchPadStuds, 0.4, HELP.launchPadStuds), at + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 200, 80))
			pad:SetAttribute("LaunchTarget", target)
			pad:SetAttribute("LaunchApexY", apexY)
			pad:SetAttribute("CourseSite", site)
			registerPad(pad)
			table.insert(state.parts, pad)
			table.insert(state.pads, pad)
			table.insert(placed, pad.Position)
		end
	end
	return placed
end

-- 매 틱: 체크포인트를 밟으면 적고 · 코스에서 떨어지면(방금 코스 높이에 있었는데 바닥 가까이) 마지막 체크포인트로 돌려놓는다(그 코스의 수정이 깨지기 전까지).
function BossJumpCourse.step(model, victims, floorY, now)
	local state = active[model]
	if not state then
		return
	end
	-- 도움 단계(전투 시계 - 파티 공통)
	local elapsed = now - state.builtAt
	if state.helpStage < 1 and elapsed >= HELP.stage1Seconds then
		state.helpStage = 1
		local placed = helpStage1(state)
		print(("[forge-game] 수정 부수기 도움 1단계(%.0f초): 높이 점프 발판 %d"):format(elapsed, #placed))
		if state.onHelp then
			state.onHelp(1, placed)
		end
	elseif state.helpStage < 2 and elapsed >= HELP.stage2Seconds then
		state.helpStage = 2
		local placed = helpStage2(state)
		print(("[forge-game] 수정 부수기 도움 2단계(%.0f초): 발사 발판 %d"):format(elapsed, #placed))
		if state.onHelp then
			state.onHelp(2, placed)
		end
	end
	for _, v in ipairs(victims) do
		local feet = v.feet or v.root.Position - Vector3.new(0, 3, 0)
		-- 도움 발판 위: 클라가 띄우며 LaunchPermitRequest를 보낸다 → 서버 위치 기록으로 확인해 설계 정점까지 허가(M1-2c - 옛 틱 검사는 틱 사이에 밟고 떠난 사람을 놓쳤다)
		local on = nil
		for _, part in ipairs(state.parts) do
			local rel = feet - part.Position
			if math.abs(rel.X) <= part.Size.X / 2 + 0.5 and math.abs(rel.Z) <= part.Size.Z / 2 + 0.5 and rel.Y >= -0.5 and rel.Y <= part.Size.Y / 2 + 2 then
				on = part
				break
			end
		end
		local record = state.checkpoints[v.player]
		if on then
			local site = on:GetAttribute("CourseSite")
			if on:GetAttribute("Checkpoint") then
				state.checkpoints[v.player] = { site = site, position = on.Position + Vector3.new(0, on.Size.Y / 2 + 3, 0), onCourseAt = now }
			elseif record then
				record.onCourseAt = now
			end
		elseif record and feet.Y - floorY < 1.5 and now - record.onCourseAt < 3 then
			local crystal = state.crystals[record.site]
			if crystal and not crystal.broken then
				if typeof(v.root) == "Instance" then
					v.root.CFrame = CFrame.new(record.position)
					v.root.AssemblyLinearVelocity = Vector3.zero
				else
					v.root.Position = record.position
				end
				if typeof(v.player) == "Instance" then
					HeightGuard.exempt(v.player, 2)
				end
				record.onCourseAt = now
				print(("[forge-game] 점프맵 체크포인트로 되돌림: %s"):format(tostring(v.player.Name)))
			else
				state.checkpoints[v.player] = nil
			end
		end
	end
end

function BossJumpCourse.clear(model)
	local state = active[model]
	active[model] = nil
	if not state then
		return
	end
	for _, part in ipairs(state.parts) do
		part:Destroy()
	end
	for _, wall in ipairs(state.walls) do
		wall:Destroy()
	end
	for _, crystal in pairs(state.crystals) do
		if crystal.model and not crystal.broken then
			MonsterSpawner.removeRescueTarget(crystal.model)
		end
	end
end

-- 검증 전용: 도움 단계 · 도움 발판 수 · 시계를 당긴다(builtAt을 seconds만큼 앞으로)
function BossJumpCourse.debugHelp(model, advanceSeconds)
	local state = active[model]
	if not state then
		return 0, 0
	end
	if advanceSeconds then
		state.builtAt -= advanceSeconds
	end
	return state.helpStage, #state.pads
end

-- 검증 전용: 지금 코스 파트 수 · 벽 수 · 수정 수
function BossJumpCourse.debugCounts(model)
	local state = active[model]
	if not state then
		return 0, 0, 0
	end
	local crystals = 0
	for _ in pairs(state.crystals) do
		crystals += 1
	end
	return #state.parts, #state.walls, crystals
end

return BossJumpCourse
