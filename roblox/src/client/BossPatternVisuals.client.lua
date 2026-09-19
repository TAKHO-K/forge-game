-- 보스 패턴 예고·연출(21-3). 서버(BossPatterns.lua)가 BossPatternEvent로 보내는 사실만
-- 그린다 - 판정에는 아무 영향이 없다(파동 링이 캐릭터를 통과해도 피해는 서버가 자기
-- 시계로 계산한 반경으로 정한다. 그래서 링 반경은 workspace:GetServerTimeNow() 기준으로
-- 그려 서버 판정과 같은 시각을 따른다). 이미지 에셋 없이 Part + Tween만 쓴다(지시, 20.27
-- 아트 동결) - SkillEffects.lua와 같은 계열. 모든 연출 파트는 CanQuery=false라 서버의
-- 레이캐스트(공중 판정·대시 담장 판정)에 걸리지 않는다.
--
-- 25-4: 기술명 텍스트(말풍선 이름표)와 화면 중앙 경고 문장을 전부 지웠다(지시 "글자를
-- 없애고 그림으로 알려준다") - 이제 전조는 순수하게 그림(말풍선 그림 문자 + 지면 도형)
-- 뿐이다. 예고 종류: 모든 패턴 공통으로 보스 머리 위 말풍선 그림 문자(강타 "!", 돌진
-- "‼", 낙석 "?", 진동파 "◎", 십자 "✚") + 패턴별 바닥 예고: 강공격(보스 중심 고정 원),
-- 진동파(보스 발밑 원판, 찍는 순간 실제 파동 링), 돌진(바닥 경로선), 낙석(표적 원판 →
-- 낙하 기둥), 십자 화염(4방향 선 → 점화). 색 언어는 danger(위험 범위, 한 가지)/impact
-- (임팩트 순간, 흰색) 두 가지로 통일했다 - PRD 20.71 표 참고. 돌진 뒤 헤롱(주저앉기)에는
-- 어지럼 말풍선(위험이 아니라 기회 신호라 파랑 유지). "reset"(사망 리셋·중단)이 오면
-- 살아있는 연출을 전부 지운다 - 재도전 직후 남은 파동이 플레이어를 때리는 일이 판정
-- (서버)에서도 연출(여기)에서도 없게.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIColors = require(ReplicatedStorage.Shared.data.UIColors)
-- 29-1: 힌트 화살표(기믹 예고에 안전지대 좌표가 실려 오면 그 위에 흰 ▼) - 그리기는 그 모듈에 있다.
local BossGateView = require(script.Parent.BossGateView)
-- 29-3: 동적 지형(얼음 기둥)·전역 기믹 전조(빨강 바닥 + 그림자)와 보스 태세(빨강 고리·반사 선) - 그리기는 각 모듈에 있다.
local BossArenaPropsView = require(script.Parent.BossArenaPropsView)
local BossStanceView = require(script.Parent.BossStanceView)
local BossStormView = require(script.Parent.BossStormView) -- 29-3: 낙뢰(하늘에서 꽂히는 번개) · 맞으면 튕겨 나는 넉백

local patternEvent = ReplicatedStorage:WaitForChild("BossPatternEvent")
local player = Players.LocalPlayer

-- 25-4: 위험 범위는 전부 이 한 색(UIColors.danger, hp와 동일값)으로 통일한다 - 패턴은
-- 스케줄러가 절대 동시에 안 돌게 막아서(BossPatterns.lua 상단 주석) 색을 하나로 합쳐도
-- "지금 뭐가 위험한지" 헷갈릴 일이 없다. 흰색은 "임팩트(방금 명중/폭발)"라는 별개 의미로만 쓴다.
local DANGER_COLOR = UIColors.danger
local IMPACT_COLOR = Color3.new(1, 1, 1)

local WAVE_SEGMENTS = 48
local WAVE_HEIGHT_STUDS = 1.6

-- 살아있는 연출 전부(파트·연결) - reset 때 한 번에 지운다.
local live = {}

local function track(part)
	live[part] = true
	return part
end

local function destroy(part)
	if live[part] then
		live[part] = nil
		part:Destroy()
	end
end

local function newPart(size, color, transparency)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.Transparency = transparency or 0.4
	part.Parent = Workspace
	return track(part)
end

-- 바닥에 눕힌 원판(Cylinder는 로컬 X축이 높이 방향 - Z축으로 90도 돌려 눕힌다).
local function newDisc(center, radius, color, transparency)
	local disc = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, transparency)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(center + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

local function fadeOut(part, seconds)
	if not live[part] then
		return
	end
	TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
	}):Play()
	task.delay(seconds, function()
		destroy(part)
	end)
end

-- 보스 머리 위 느낌표(지시 [3] "멀리서도 보여야 한다" - BillboardGui).
-- 보스 모델은 Monster 태그 + isBoss 이름표뿐이라 "지금 내 보스"는 가장 가까운 Monster
-- 모델 중 BossArena 안에 있는 것으로 찾는다 - 개인 아레나엔 몬스터가 하나뿐이다.
local function findBossModel(nearPosition)
	local best, bestDistance = nil, math.huge
	local CollectionService = game:GetService("CollectionService")
	for _, model in ipairs(CollectionService:GetTagged("Monster")) do
		local root = model.PrimaryPart
		-- 29-3: 구출 대상(빙결된 친구의 얼음 덩어리)도 "Monster" 태그다 - 보스 말풍선이 거기 붙으면 안 된다.
		if root and not CollectionService:HasTag(model, "RescueTarget") then
			local d = (root.Position - nearPosition).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

-- 25-4: 패턴별 말풍선 그림+색만 남긴다(기술명 텍스트 제거 - 지시 "글자를 없애고
-- 그림으로 알려준다"). 그림 문자(!/‼/?/◎/✚)는 이름이 아니라 패턴마다 다른 모양의
-- 픽토그램이라 남긴다 - 색약 대응(모양으로도 구분)에도 쓰인다. daze(헤롱)는 위험이
-- 아니라 기회(반격 타이밍) 신호라 danger/impact와 다른 색(파랑)을 그대로 유지한다.
local BUBBLES = {
	heavy = { icon = "!", color = Color3.fromRGB(230, 40, 40) },
	charge = { icon = "‼", color = Color3.fromRGB(255, 60, 60) },
	meteor = { icon = "?", color = Color3.fromRGB(255, 120, 30) },
	shockwave = { icon = "◎", color = Color3.fromRGB(255, 150, 40) },
	cross = { icon = "✚", color = Color3.fromRGB(255, 120, 20) },
	daze = { icon = "@_@", color = Color3.fromRGB(120, 200, 255) },
	-- 29-1 공통 기믹 패턴의 자리(보스별 세션이 kind마다 자기 픽토그램으로 바꾼다) - 색은 강공격과 같은 위험색.
	gimmick = { icon = "※", color = Color3.fromRGB(230, 40, 40) },
	-- 29-3 보스별 기믹 픽토그램(색은 같은 위험색 - 모양으로 구분한다): 포효 = 눈꽃, 갑각 태세 = "때리지 마라".
	roar = { icon = "❄", color = Color3.fromRGB(230, 40, 40) },
	shell = { icon = "✖", color = Color3.fromRGB(230, 40, 40) },
	-- 29-1 파훼 성공 = 기회(헤롱과 같은 파랑).
	gateBroken = { icon = "◇", color = Color3.fromRGB(120, 200, 255) },
}

local currentBubble = nil

-- 보스 머리 위 말풍선(사용자 지시 "패턴별 전조에 느낌표·물음표·바닥 그림이 있는 말풍선 UI를
-- 잘 보이게"). 흰 둥근 상자 + 아래 꼬리 + 큰 그림 글자 + 작은 이름. 한 번에 하나만 - 새
-- 말풍선이 오면 이전 것을 지운다.
-- scale(29-1, 선택): 힌트 1단계부터 기믹 말풍선이 BossData.mechanics.hint.bubbleScale배로 커진다.
local function showBubble(kind, seconds, scale)
	local spec = BUBBLES[kind]
	local player_root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local model = findBossModel(player_root and player_root.Position or Vector3.zero)
	local head = model and model:FindFirstChild("Head")
	if not spec or not head then
		return
	end
	if currentBubble then
		destroy(currentBubble)
		currentBubble = nil
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossBubble"
	gui.Size = UDim2.new(0, 150 * (scale or 1), 0, 120 * (scale or 1))
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Adornee = head
	gui.Parent = head
	track(gui)
	currentBubble = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 62)
	box.BackgroundColor3 = Color3.new(1, 1, 1)
	box.BorderSizePixel = 0
	box.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 18)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = spec.color
	stroke.Parent = box

	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 1, 0)
	tail.Size = UDim2.new(0, 18, 0, 18)
	tail.Rotation = 45
	tail.BackgroundColor3 = Color3.new(1, 1, 1)
	tail.BorderSizePixel = 0
	tail.Parent = box

	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.new(1, 0, 0, 62)
	icon.BackgroundTransparency = 1
	icon.Font = Enum.Font.GothamBlack
	icon.TextScaled = true
	icon.Text = spec.icon
	icon.TextColor3 = spec.color
	icon.Parent = box

	-- 그림 글자가 두근거린다 - 정지 그림보다 눈에 띈다.
	TweenService:Create(icon, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Size = UDim2.new(1, 0, 0, 52),
	}):Play()
	task.delay(seconds, function()
		if currentBubble == gui then
			currentBubble = nil
		end
		destroy(gui)
	end)
end

-- ─────────────────────────── 보스 중심 원(강공격류) ───────────────────────────

-- 29-2: 도넛(innerRadius가 있는 보스 중심 원 - 몸 쪽이 안전하다). 로블록스엔 속이 빈 원판이 없어 진동파 링과
-- 같은 방식으로 얇은 파트를 원둘레에 놓되, 두께를 (바깥 - 안쪽)으로 잡아 띠 전체를 덮는다. 빈 가운데가 곧
-- "빨강이 없는 곳 = 안전"(20.73 [2-0] 1번)이다.
local RING_SEGMENTS = 40

local function newRingBand(center, innerRadius, outerRadius, color, transparency)
	local parts = {}
	local mid = (innerRadius + outerRadius) / 2
	local segmentLength = 2 * math.pi * outerRadius / RING_SEGMENTS * 1.08
	for i = 1, RING_SEGMENTS do
		local angle = (i / RING_SEGMENTS) * 2 * math.pi
		local part = newPart(Vector3.new(segmentLength, 0.2, outerRadius - innerRadius), color, transparency)
		part.CFrame = CFrame.new(center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * mid + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, -angle, 0)
		parts[i] = part
	end
	return parts
end

-- 원판 하나 또는 도넛 띠(파트 여러 개)를 같은 방식으로 다루기 위한 목록.
local function newCircleShape(data, color, transparency)
	if data.innerRadius then
		return newRingBand(data.center, data.innerRadius, data.radius, color, transparency)
	end
	return { newDisc(data.center, data.radius, color, transparency) }
end

-- 25-4: 보스 중심 고정 반경 원 - shockTelegraph와 같은 "예고 시간 동안 진해진다" 기법을
-- 쓰되 크기는 안 자란다(사거리가 고정이라 진동파의 "자라는 원"과 모양으로 구분된다).
local function heavyTelegraph(data)
	for _, part in ipairs(newCircleShape(data, DANGER_COLOR, 0.85)) do
		TweenService:Create(part, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 0.25,
		}):Play()
		task.delay(data.seconds, function()
			fadeOut(part, 0.2)
		end)
	end
end

local function heavyImpact(data)
	for _, part in ipairs(newCircleShape(data, IMPACT_COLOR, 0.1)) do
		fadeOut(part, 0.35)
	end
end

-- ─────────────────────────── 진동파 ───────────────────────────

local function shockTelegraph(data)
	-- 보스 발밑 원판 - 예고 시간 동안 점점 진해진다(찍는 순간을 예측할 수 있게).
	local disc = newDisc(data.center, 8, DANGER_COLOR, 0.85)
	TweenService:Create(disc, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 0.25,
		Size = Vector3.new(0.2, 24, 24),
	}):Play()
	task.delay(data.seconds, function()
		fadeOut(disc, 0.2)
	end)
end

-- 파동 링 - 얇은 파트 WAVE_SEGMENTS개를 원둘레에 접선 방향으로 놓고 매 프레임 반경만큼
-- 밀어낸다(로블록스엔 속이 빈 원통 프리미티브가 없다). 반경은 서버 시계 기준 - 서버 판정
-- 과 같은 반경이 그려진다.
local function shockwave(data)
	local segments = {}
	for i = 1, WAVE_SEGMENTS do
		local part = newPart(Vector3.new(1, WAVE_HEIGHT_STUDS, data.thickness), DANGER_COLOR, 0.25)
		segments[i] = part
	end
	local center = data.center + Vector3.new(0, WAVE_HEIGHT_STUDS / 2, 0)
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local radius = (Workspace:GetServerTimeNow() - data.serverStart) * data.speed
		if radius > data.maxRadius or not live[segments[1]] then
			connection:Disconnect()
			for _, part in ipairs(segments) do
				destroy(part)
			end
			return
		end
		-- 띠의 안쪽 가장자리~바깥 가장자리 = [반경-두께, 반경] (서버와 같은 정의).
		local mid = math.max(radius - data.thickness / 2, 0)
		local segmentLength = 2 * math.pi * math.max(radius, 1) / WAVE_SEGMENTS * 1.08
		for i, part in ipairs(segments) do
			local angle = (i / WAVE_SEGMENTS) * 2 * math.pi
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			part.Size = Vector3.new(segmentLength, WAVE_HEIGHT_STUDS, data.thickness)
			part.CFrame = CFrame.new(center + offset * mid) * CFrame.Angles(0, -angle, 0)
		end
	end)
end

-- ─────────────────────────── 돌진 ───────────────────────────

local chargeLine = nil

local function focus(data)
	local delta = data.endPosition - data.bossPosition
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = (data.bossPosition + data.endPosition) / 2
	local line = newPart(Vector3.new(data.halfWidth * 2, 0.2, length), DANGER_COLOR, 0.8)
	line.CFrame = CFrame.lookAt(Vector3.new(mid.X, data.floorY + 0.15, mid.Z), Vector3.new(data.endPosition.X, data.floorY + 0.15, data.endPosition.Z))
	-- 예고 시간 동안 점점 진해진다.
	TweenService:Create(line, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 0.35,
	}):Play()
	chargeLine = line
end

local function charge(data)
	local line = chargeLine
	chargeLine = nil
	-- 돌진 동안 선을 유지했다가 도착하면 지운다 + 도착 지점 충격 링.
	task.delay(data.durationSeconds, function()
		if line then
			fadeOut(line, 0.3)
		end
		local ring = newDisc(Vector3.new(data.endPosition.X, data.endPosition.Y - 1.3, data.endPosition.Z), 2, IMPACT_COLOR, 0.2)
		TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.2, 16, 16),
			Transparency = 1,
		}):Play()
		task.delay(0.4, function()
			destroy(ring)
		end)
	end)
end

-- ─────────────────────────── 낙석 ───────────────────────────

local meteorDiscs = {}

local function meteor(data)
	for _, position in ipairs(data.positions) do
		local disc = newDisc(position, data.radius, DANGER_COLOR, 0.8)
		TweenService:Create(disc, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 0.3,
		}):Play()
		-- 안쪽에서 커지는 두 번째 원판 - "떨어지기까지 남은 시간"이 읽히게(세 번째 색 의미).
		local inner = newDisc(position, 0.5, IMPACT_COLOR, 0.5)
		TweenService:Create(inner, TweenInfo.new(data.seconds, Enum.EasingStyle.Linear), {
			Size = Vector3.new(0.2, data.radius * 2, data.radius * 2),
		}):Play()
		table.insert(meteorDiscs, disc)
		table.insert(meteorDiscs, inner)
	end
end

local function meteorImpact(data)
	for _, disc in ipairs(meteorDiscs) do
		destroy(disc)
	end
	meteorDiscs = {}
	for _, position in ipairs(data.positions) do
		if data.style == "lightning" then
			-- 29-3: 낙석 기둥 대신 번개(꺾인 흰 선). 색 언어는 같다 - 임팩트 = 흰색.
			BossStormView.bolt(position)
			fadeOut(newDisc(position, data.radius, IMPACT_COLOR, 0.1), 0.35)
			continue
		end
		-- 위에서 내리꽂히는 기둥 + 바닥 섬광.
		local pillar = newPart(Vector3.new(data.radius * 1.2, 30, data.radius * 1.2), IMPACT_COLOR, 0.3)
		pillar.CFrame = CFrame.new(position + Vector3.new(0, 30, 0))
		TweenService:Create(pillar, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(position + Vector3.new(0, 15, 0)),
		}):Play()
		task.delay(0.12, function()
			fadeOut(pillar, 0.25)
		end)
		local flash = newDisc(position, data.radius, IMPACT_COLOR, 0.1)
		fadeOut(flash, 0.35)
	end
end

-- ─────────────────────────── 십자 화염 ───────────────────────────

local crossLines = {}

-- 29-2: 직선 빔은 보스 중심에서 angleDeg + stepDeg × k 방향으로 #lengths개다 - 십자(4개·90°)뿐 아니라 부채꼴
-- (3개·35°)·단발(1개)도 같은 이벤트로 온다. stepDeg가 없으면 90(기존 십자). 23-6의 회전 스윕은 없앴다(20.73
-- [1-2] 폐기 - 화면의 띠는 도는데 판정은 마지막 각도 하나라 "보이는 것 = 맞는 것"이 아니었다).
local function placeCrossBeams(angleDeg, data)
	local stepDeg = data.stepDeg or 90
	for k = 0, #data.lengths - 1 do
		local line = crossLines[k + 1]
		if line then
			local a = math.rad(angleDeg + stepDeg * k)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local length = data.lengths[k + 1]
			local mid = data.center + dir * (length / 2)
			line.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), data.center + dir * length + Vector3.new(0, 0.15, 0))
		end
	end
end

local function cross(data)
	for _, line in ipairs(crossLines) do
		if line then
			destroy(line)
		end
	end
	crossLines = {}
	for k = 0, #data.lengths - 1 do
		local length = data.lengths[k + 1]
		if length > 1 then
			local line = newPart(Vector3.new(data.halfWidth * 2, 0.2, length), DANGER_COLOR, 0.8)
			TweenService:Create(line, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 0.35,
			}):Play()
			crossLines[k + 1] = line
		else
			crossLines[k + 1] = false
		end
	end
	placeCrossBeams(data.angleDeg, data)
end

local function crossFire()
	for _, line in ipairs(crossLines) do
		if live[line] then
			line.Color = IMPACT_COLOR
			line.Size = Vector3.new(line.Size.X, 3, line.Size.Z)
			line.CFrame = line.CFrame + Vector3.new(0, 1.4, 0)
			line.Transparency = 0
			fadeOut(line, 0.4)
		end
	end
	crossLines = {}
end

-- ─────────────────────────── 리셋 ───────────────────────────

local function resetAll()
	for part in pairs(live) do
		part:Destroy()
	end
	live = {}
	meteorDiscs = {}
	crossLines = {}
	chargeLine = nil
	currentBubble = nil
end

patternEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "bubble" then
		showBubble(data.pattern, data.seconds, data.scale)
	elseif kind == "gimmickTelegraph" then
		if data.safeProp then
			BossArenaPropsView.showGlobalTelegraph(data)
		end
		if data.safeSpots then
			BossGateView.showHintArrows(data.safeSpots, data.seconds)
		end
	elseif kind == "gimmickResolve" then
		BossArenaPropsView.resolveTelegraph()
		if data.broken then
			showBubble("gateBroken", data.windowSeconds or 2)
		end
	elseif kind == "propSpawn" then
		BossArenaPropsView.spawn(data)
	elseif kind == "propRemove" then
		BossArenaPropsView.remove(data.ids)
	elseif kind == "propsClear" then
		BossArenaPropsView.clear()
	elseif kind == "stanceStart" then
		BossStanceView.start(data)
	elseif kind == "stanceEnd" then
		BossStanceView.clear()
	elseif kind == "reflectHit" then
		BossStanceView.reflect(data)
	elseif kind == "launch" then
		BossStormView.launch(data)
	elseif kind == "daze" then
		showBubble("daze", data.seconds)
	elseif kind == "heavyTelegraph" then
		heavyTelegraph(data)
	elseif kind == "heavyImpact" then
		heavyImpact(data)
	elseif kind == "shockTelegraph" then
		shockTelegraph(data)
	elseif kind == "shockwave" then
		shockwave(data)
	elseif kind == "focus" then
		focus(data)
	elseif kind == "charge" then
		charge(data)
	elseif kind == "meteor" then
		meteor(data)
	elseif kind == "meteorImpact" then
		meteorImpact(data)
	elseif kind == "cross" then
		cross(data)
	elseif kind == "crossFire" then
		crossFire()
	elseif kind == "reset" then
		resetAll()
		BossArenaPropsView.clearTelegraph() -- 기둥 자체는 남는다(서버가 propsClear로 따로 치운다)
		BossStanceView.clear()
	end
end)

BossArenaPropsView.start()

-- 내 캐릭터가 죽어 리스폰될 때도 남은 연출을 지운다(서버 reset과 이중 방어).
player.CharacterAdded:Connect(resetAll)
