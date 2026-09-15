-- 보스 패턴 예고·연출(21-3). 서버(BossPatterns.lua)가 BossPatternEvent로 보내는 사실만
-- 그린다 - 판정에는 아무 영향이 없다(파동 링이 캐릭터를 통과해도 피해는 서버가 자기
-- 시계로 계산한 반경으로 정한다. 그래서 링 반경은 workspace:GetServerTimeNow() 기준으로
-- 그려 서버 판정과 같은 시각을 따른다). 이미지 에셋 없이 Part + Tween만 쓴다(지시, 20.27
-- 아트 동결) - SkillEffects.lua와 같은 계열. 모든 연출 파트는 CanQuery=false라 서버의
-- 레이캐스트(공중 판정·대시 담장 판정)에 걸리지 않는다.
--
-- 예고 종류: 모든 패턴 공통으로 보스 머리 위 말풍선(사용자 지시 - 느낌표·물음표·바닥 그림
-- 으로 "스킬을 쓰겠구나"를 읽게: 강타 "!", 돌진 "‼", 낙석 "?", 진동파 "◎"(바닥 원), 십자
-- "✚") + 패턴별 바닥 예고: 진동파(보스 발밑 원판, 찍는 순간 실제 파동 링), 돌진(화면 경고 +
-- 바닥 경로선), 낙석(표적 원판 → 낙하 기둥), 십자 화염(4방향 선 → 점화). 강공격은 15-1
-- 그대로 서버가 몸 색을 바꾼다 + 말풍선. 돌진 뒤 헤롱(주저앉기)에는 어지럼 말풍선.
-- "reset"(사망 리셋·중단)이 오면 살아있는 연출을 전부 지운다 - 재도전 직후 남은 파동이
-- 플레이어를 때리는 일이 판정(서버)에서도 연출(여기)에서도 없게.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local patternEvent = ReplicatedStorage:WaitForChild("BossPatternEvent")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WAVE_COLOR = Color3.fromRGB(255, 140, 40)
local TELEGRAPH_COLOR = Color3.fromRGB(230, 40, 40)
local CHARGE_COLOR = Color3.fromRGB(255, 60, 60)
local METEOR_COLOR = Color3.fromRGB(255, 90, 30)
local CROSS_COLOR = Color3.fromRGB(255, 120, 20)

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

-- ─────────────────────────── 화면 경고 ───────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BossWarningGui"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 4
screenGui.Parent = playerGui

local warningLabel = Instance.new("TextLabel")
warningLabel.AnchorPoint = Vector2.new(0.5, 0)
warningLabel.Position = UDim2.new(0.5, 0, 0, 160)
warningLabel.Size = UDim2.new(0, 360, 0, 52)
warningLabel.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
warningLabel.BackgroundTransparency = 1
warningLabel.TextTransparency = 1
warningLabel.BorderSizePixel = 0
warningLabel.Font = Enum.Font.GothamBlack
warningLabel.TextSize = 26
warningLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
warningLabel.Text = ""
warningLabel.Parent = screenGui

local warningCorner = Instance.new("UICorner")
warningCorner.CornerRadius = UDim.new(0, 8)
warningCorner.Parent = warningLabel

local warningStroke = Instance.new("UIStroke")
warningStroke.Color = Color3.fromRGB(255, 60, 60)
warningStroke.Transparency = 1
warningStroke.Parent = warningLabel

local warningToken = 0

local function showWarning(text, seconds)
	warningToken += 1
	local token = warningToken
	warningLabel.Text = text
	local tweenIn = TweenInfo.new(0.1)
	TweenService:Create(warningLabel, tweenIn, { BackgroundTransparency = 0.2, TextTransparency = 0 }):Play()
	TweenService:Create(warningStroke, tweenIn, { Transparency = 0 }):Play()
	task.delay(seconds, function()
		if warningToken == token then
			local tweenOut = TweenInfo.new(0.3)
			TweenService:Create(warningLabel, tweenOut, { BackgroundTransparency = 1, TextTransparency = 1 }):Play()
			TweenService:Create(warningStroke, tweenOut, { Transparency = 1 }):Play()
		end
	end)
end

local function hideWarning()
	warningToken += 1
	warningLabel.BackgroundTransparency = 1
	warningLabel.TextTransparency = 1
	warningStroke.Transparency = 1
end

-- 보스 머리 위 느낌표(지시 [3] "멀리서도 보여야 한다" - BillboardGui + 화면 경고 둘 다).
-- 보스 모델은 Monster 태그 + isBoss 이름표뿐이라 "지금 내 보스"는 가장 가까운 Monster
-- 모델 중 BossArena 안에 있는 것으로 찾는다 - 개인 아레나엔 몬스터가 하나뿐이다.
local function findBossModel(nearPosition)
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(game:GetService("CollectionService"):GetTagged("Monster")) do
		local root = model.PrimaryPart
		if root then
			local d = (root.Position - nearPosition).Magnitude
			if d < bestDistance then
				best, bestDistance = model, d
			end
		end
	end
	return best
end

-- 패턴별 말풍선 그림·이름·색. 글자 하나가 "그림"이다(이미지 에셋 없이).
local BUBBLES = {
	heavy = { icon = "!", label = "강타", color = Color3.fromRGB(230, 40, 40) },
	charge = { icon = "‼", label = "돌진", color = Color3.fromRGB(255, 60, 60) },
	meteor = { icon = "?", label = "낙석", color = Color3.fromRGB(255, 120, 30) },
	shockwave = { icon = "◎", label = "진동파", color = Color3.fromRGB(255, 150, 40) },
	cross = { icon = "✚", label = "십자 화염", color = Color3.fromRGB(255, 120, 20) },
	daze = { icon = "@_@", label = "헤롱… 뒤를 쳐라!", color = Color3.fromRGB(120, 200, 255) },
}

local currentBubble = nil

-- 보스 머리 위 말풍선(사용자 지시 "패턴별 전조에 느낌표·물음표·바닥 그림이 있는 말풍선 UI를
-- 잘 보이게"). 흰 둥근 상자 + 아래 꼬리 + 큰 그림 글자 + 작은 이름. 한 번에 하나만 - 새
-- 말풍선이 오면 이전 것을 지운다.
local function showBubble(kind, seconds)
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
	gui.Size = UDim2.new(0, 150, 0, 120)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.Adornee = head
	gui.Parent = head
	track(gui)
	currentBubble = gui

	local box = Instance.new("Frame")
	box.Size = UDim2.new(1, 0, 0, 96)
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

	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 0, 0, 62)
	name.Size = UDim2.new(1, 0, 0, 28)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 18
	name.Text = spec.label
	name.TextColor3 = Color3.fromRGB(40, 30, 30)
	name.Parent = box

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

-- ─────────────────────────── 진동파 ───────────────────────────

local function shockTelegraph(data)
	-- 보스 발밑 원판 - 예고 시간 동안 점점 진해진다(찍는 순간을 예측할 수 있게).
	local disc = newDisc(data.center, 8, TELEGRAPH_COLOR, 0.85)
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
		local part = newPart(Vector3.new(1, WAVE_HEIGHT_STUDS, data.thickness), WAVE_COLOR, 0.25)
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
	showWarning("!! 돌진 - 옆으로 피하세요 !!", data.seconds)

	local delta = data.endPosition - data.bossPosition
	local length = delta.Magnitude
	if length < 1 then
		return
	end
	local mid = (data.bossPosition + data.endPosition) / 2
	local line = newPart(Vector3.new(data.halfWidth * 2, 0.2, length), CHARGE_COLOR, 0.8)
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
		local ring = newDisc(Vector3.new(data.endPosition.X, data.endPosition.Y - 1.3, data.endPosition.Z), 2, CHARGE_COLOR, 0.2)
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
		local disc = newDisc(position, data.radius, METEOR_COLOR, 0.8)
		TweenService:Create(disc, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 0.3,
		}):Play()
		-- 안쪽에서 커지는 두 번째 원판 - "떨어지기까지 남은 시간"이 읽히게.
		local inner = newDisc(position, 0.5, Color3.new(1, 1, 1), 0.5)
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
		-- 위에서 내리꽂히는 기둥 + 바닥 섬광.
		local pillar = newPart(Vector3.new(data.radius * 1.2, 30, data.radius * 1.2), METEOR_COLOR, 0.3)
		pillar.CFrame = CFrame.new(position + Vector3.new(0, 30, 0))
		TweenService:Create(pillar, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = CFrame.new(position + Vector3.new(0, 15, 0)),
		}):Play()
		task.delay(0.12, function()
			fadeOut(pillar, 0.25)
		end)
		local flash = newDisc(position, data.radius, Color3.new(1, 1, 1), 0.1)
		fadeOut(flash, 0.35)
	end
end

-- ─────────────────────────── 십자 화염 ───────────────────────────

local crossLines = {}

local function cross(data)
	for _, line in ipairs(crossLines) do
		destroy(line)
	end
	crossLines = {}
	for k = 0, 3 do
		local a = math.rad(data.angleDeg + 90 * k)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local length = data.lengths[k + 1]
		if length > 1 then
			local mid = data.center + dir * (length / 2)
			local line = newPart(Vector3.new(data.halfWidth * 2, 0.2, length), CROSS_COLOR, 0.8)
			line.CFrame = CFrame.lookAt(mid + Vector3.new(0, 0.15, 0), data.center + dir * length + Vector3.new(0, 0.15, 0))
			TweenService:Create(line, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Transparency = 0.35,
			}):Play()
			table.insert(crossLines, line)
		end
	end
end

local function crossFire()
	for _, line in ipairs(crossLines) do
		if live[line] then
			line.Color = Color3.new(1, 1, 1)
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
	hideWarning()
end

patternEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "bubble" then
		showBubble(data.pattern, data.seconds)
	elseif kind == "daze" then
		showBubble("daze", data.seconds)
		showWarning("보스가 헤롱거린다 - 백어택 찬스!", math.min(data.seconds, 2.5))
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
	end
end)

-- 내 캐릭터가 죽어 리스폰될 때도 남은 연출을 지운다(서버 reset과 이중 방어).
player.CharacterAdded:Connect(resetAll)
