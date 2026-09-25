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

local CollectionService = game:GetService("CollectionService")
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
local BossSplitView = require(script.Parent.BossSplitView) -- 29-5 수정 여왕의 프리즘 분열(빨강 원 넷 + 진짜의 흰 카운트다운)
local BossStormView = require(script.Parent.BossStormView) -- 29-3: 낙뢰(하늘에서 꽂히는 번개) · 맞으면 튕겨 나는 넉백
local BossFloodView = require(script.Parent.BossFloodView) -- 29-4: 심해 군주의 단(내 시계로 가라앉는다) · "아직 이르다" 윗면 빨강
local BossRhythmView = require(script.Parent.BossRhythmView) -- P3c A: 점프 틈 · 돌진 대상 표식 · 번개 추적 원
local BossRegrowView = require(script.Parent.BossRegrowView) -- P3d D: 지형 재생성 전조(그림자 + 금 빛) · 솟음 · 끼임 표시
local BossMotionView = require(script.Parent.BossMotionView) -- P3d A1 · A2 · A4: 보스 찍기 · 돌진 모션(인형) · 풍압 · 속도감
local BossFx = require(script.Parent.BossFx) -- P3d A5: 연출 조각 풀
local BossFxData = require(ReplicatedStorage.Shared.data.BossFxData)
-- BR1: 새 조각(부채꼴 · 투사체 · 소용돌이 · 연쇄 · 잠행) · 대공 잡기 · 환경 변화 - 그리기는 각 모듈에 있다.
local BossBR1View = require(script.Parent.BossBR1View)
local BossGrabView = require(script.Parent.BossGrabView)
local BossSonicView = require(script.Parent.BossSonicView) -- BR1-2 음파 포효
local BossColorView = require(script.Parent.BossColorView) -- BR1-2 색 맞추기
local BossInnerCircleView = require(script.Parent.BossInnerCircleView) -- BR1-2 근접 원형 구역 · 낫 휘두르기 평타
local BossRodsView = require(script.Parent.BossRodsView) -- BR1-2 번개 조준경
local BossEnvironmentView = require(script.Parent.BossEnvironmentView)
local BossBR13View = require(script.Parent.BossBR13View) -- BR1-3 강화 평타 테두리 · 에네르기파 · 분신 부메랑 · 아르마딜로 · 기절 별
local BossGimmick13View = require(script.Parent.BossGimmick13View) -- BR1-3 진짜 전갈 찾기 · 수정 오르골

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

-- P3c B4 바닥 둔덕: 예고 도형이 걸친 둔덕(서버가 "BossArenaMound" 태그를 단 층 원판)의 가장 높은 윗면만큼 도형을 띄운다 - 둔덕 속에 묻혀
-- 안 보이는 장판이 없게("보이는 것 = 판정" - 판정은 높이차 상한 8 안이라 둔덕 위아래가 모두 맞는다). 둔덕이 없는 곳은 0(옛 그림 그대로).
local function moundLift(center, radius)
	local lift = 0
	for _, part in ipairs(CollectionService:GetTagged("BossArenaMound")) do
		local dx, dz = part.Position.X - center.X, part.Position.Z - center.Z
		local reach = part.Size.Y / 2 + radius
		if dx * dx + dz * dz <= reach * reach then
			lift = math.max(lift, part.Position.Y + part.Size.X / 2 - center.Y)
		end
	end
	return math.clamp(lift, 0, 4)
end

-- 선분(a → b, 반폭 halfWidth)이 실제로 걸친 둔덕만 본다(리뷰 2 - 선분을 감싸는 원으로 재면 둔덕을 안 지나는 선도 떴다).
local function moundLiftSegment(a, b, halfWidth)
	local lift = 0
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local len2 = ab:Dot(ab)
	for _, part in ipairs(CollectionService:GetTagged("BossArenaMound")) do
		local p = Vector3.new(part.Position.X - a.X, 0, part.Position.Z - a.Z)
		local t = len2 > 1e-6 and math.clamp(p:Dot(ab) / len2, 0, 1) or 0
		local closest = p - ab * t
		if closest.Magnitude <= part.Size.Y / 2 + halfWidth then
			lift = math.max(lift, part.Position.Y + part.Size.X / 2 - a.Y)
		end
	end
	return math.clamp(lift, 0, 4)
end

-- 바닥에 눕힌 원판(Cylinder는 로컬 X축이 높이 방향 - Z축으로 90도 돌려 눕힌다).
local function newDisc(center, radius, color, transparency)
	local disc = newPart(Vector3.new(0.2, radius * 2, radius * 2), color, transparency)
	disc.Shape = Enum.PartType.Cylinder
	disc.CFrame = CFrame.new(center + Vector3.new(0, 0.15 + moundLift(center, radius), 0)) * CFrame.Angles(0, 0, math.rad(90))
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
	-- 29-4: 범람 = 물결.
	flood = { icon = "≈", color = Color3.fromRGB(230, 40, 40) },
	-- 29-4 폭풍 군주: 회오리 = 소용돌이(낙석 계열의 색), 과충전 = 번개.
	whirl = { icon = "§", color = Color3.fromRGB(255, 120, 30) },
	overcharge = { icon = "ϟ", color = Color3.fromRGB(230, 40, 40) },
	-- 29-1 파훼 성공 = 기회(헤롱과 같은 파랑).
	gateBroken = { icon = "◇", color = Color3.fromRGB(120, 200, 255) },
	-- BR1: 강화 평타 = 짧은 휘두르기(작은 무게 - 주황), 대공 잡기 = 손바닥(큰 무게 - 위험색).
	swipe = { icon = "›", color = Color3.fromRGB(255, 120, 30) },
	grab = { icon = "✋", color = Color3.fromRGB(230, 40, 40) },
	-- BR1-2 투사체 반사 = 거울(원거리는 쏘지 마라)
	mirror = { icon = "◈", color = Color3.fromRGB(230, 40, 40) },
	-- BR1-3: 에네르기파 = 반원(휩쓰는 쪽) · 아르마딜로 = 손바닥(때리지 마 - 노랑) · 진짜 전갈 찾기 = 모래 물결 · 수정 오르골 = 음표
	sweep = { icon = "◐", color = Color3.fromRGB(230, 40, 40) },
	armadillo = { icon = "✋", color = Color3.fromRGB(255, 200, 40) },
	sandSearch = { icon = "≋", color = Color3.fromRGB(230, 40, 40) },
	orgel = { icon = "♪", color = Color3.fromRGB(230, 40, 40) },
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
	center += Vector3.new(0, moundLift(center, outerRadius), 0) -- P3c B4
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
-- M1: 보스 테마색을 바닥과 밝기 대비가 나게(상대 휘도 차 ≥ minLumaGap) 맞춘다
local function luma(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end
local function contrastColor(theme, floor)
	local gap = BossFxData.quakeLook.minLumaGap
	local target = luma(floor) > 0.5 and Color3.new(0, 0, 0) or Color3.new(1, 1, 1)
	local c = theme
	for step = 0, 10 do
		c = theme:Lerp(target, step / 10)
		if math.abs(luma(c) - luma(floor)) >= gap then
			break
		end
	end
	return c
end
local BossDataForLook = require(ReplicatedStorage.Shared.data.BossData)

local function shockwave(data)
	-- P3c B4(리뷰 2): 띠를 띄우지 않고 **키운다** - 바닥에서 둔덕 윗면 위까지 덮는 띠(평지에서도 바닥에 붙어 있고, 둔덕 위를 지날 때도 보인다).
	-- (P3d: 옛 코드는 이 값을 선언 전에 읽어 첫 크기가 nil이었다 - 첫 프레임에 다시 잡혀 겉으로는 안 보였다. 선언을 앞으로 옮겼다.)
	local waveHeight = WAVE_HEIGHT_STUDS + moundLift(data.center, data.maxRadius)
	local airLift = 0
	if data.air then
		-- BR1 공중 파동: 발 높이 [min, max] 띠를 그 높이에 그린다(루트 = 발 + 3 - 띠가 몸통을 지나는 높이). 땅에 서 있으면 띠가 머리 위로 지나간다.
		waveHeight = data.air.maxStuds - data.air.minStuds
		airLift = data.air.minStuds + 1.5
	end
	local segments = {}
	local edges = {} -- 공중 파동의 흰 테두리(위 · 아래 선)
	local blades = {} -- M1: 공중 파동의 칼날(띠 가운데 얇은 네온)
	local look = BossFxData.quakeLook
	local bossLook = BossDataForLook.bosses[data.bossId or ""]
	local floorColor = data.floorColor or Color3.fromRGB(120, 110, 100)
	local themeColor = contrastColor(bossLook and bossLook.headColor or DANGER_COLOR, floorColor)
	for i = 1, WAVE_SEGMENTS do
		local part = newPart(Vector3.new(1, waveHeight, data.thickness), themeColor, data.air and look.bandTransparency or look.groundTransparency)
		if not data.air then
			part.Material = Enum.Material.Slate -- 두꺼운 흙물결(빛나는 벽이 아니라 땅)
		end
		segments[i] = part
		if data.air then
			-- 사용자 결정(가) → M1: 공중 파동 = 머리 높이 얇은 칼날 고리(네온) + 옅은 판정 띠 + 흰 테두리 두 줄. 땅 파동(두꺼운 흙물결)과 모양으로 구분한다. 판정은 그대로.
			edges[i] = { newPart(Vector3.new(1, 0.35, data.thickness), IMPACT_COLOR, 0.1), newPart(Vector3.new(1, 0.35, data.thickness), IMPACT_COLOR, 0.1) }
			blades[i] = newPart(Vector3.new(1, look.bladeHeight, data.thickness * 1.4), themeColor, 0)
		end
	end
	-- M1: 땅 파동이 지나간 자리의 바닥 들썩임(파동 안쪽 behindStuds - 작은 블록이 솟았다 가라앉는다)
	local heave = {}
	if (data.layer or 1) == 1 and not data.air then
		for i = 1, look.heave.segments do
			local part = newPart(Vector3.new(1, 0.2, look.heave.width), floorColor:Lerp(themeColor, 0.35), 0)
			part.Material = Enum.Material.Slate
			heave[i] = part
		end
	end
	local center = data.center + Vector3.new(0, waveHeight / 2 + airLift, 0)
	-- P3d A3 땅 파도: 첫 겹에만 흙 마루(맵 바닥색을 밝게 - 솟았다 꺼지며 굴러간다)를 띠 안에 세운다. 마루 = 띠와 같은 자리 · 띠보다 낮고 좁다(빨강 띠가 겉을 감싸 전조가 가려지지 않는다).
	local ground = BossFxData.groundWave
	local crest = {}
	if (data.layer or 1) == 1 and not data.air then
		local earth = themeColor:Lerp(floorColor, 0.25) -- M1: 흙 마루도 테마색 쪽(바닥과 대비)
		for i = 1, ground.segments do
			local part = BossFx.acquirePart("block")
			part.Color = earth
			part.Size = Vector3.new(1, 0.1, data.thickness * 0.8)
			crest[i] = part
		end
	end
	local connection
	connection = RunService.RenderStepped:Connect(function()
		local radius = (Workspace:GetServerTimeNow() - data.serverStart) * data.speed
		if radius > data.maxRadius or not live[segments[1]] then
			connection:Disconnect()
			for _, part in ipairs(segments) do
				destroy(part)
			end
			for _, pair in pairs(edges) do
				destroy(pair[1])
				destroy(pair[2])
			end
			for _, part in pairs(blades) do
				destroy(part)
			end
			for _, part in ipairs(heave) do
				destroy(part)
			end
			for _, part in ipairs(crest) do
				BossFx.releasePart(part, "block")
			end
			crest = {}
			return
		end
		-- 띠의 안쪽 가장자리~바깥 가장자리 = [반경-두께, 반경] (서버와 같은 정의).
		local mid = math.max(radius - data.thickness / 2, 0)
		local segmentLength = 2 * math.pi * math.max(radius, 1) / WAVE_SEGMENTS * 1.08
		for i, part in ipairs(segments) do
			local angle = (i / WAVE_SEGMENTS) * 2 * math.pi
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			part.Size = Vector3.new(segmentLength, waveHeight, data.thickness)
			part.CFrame = CFrame.new(center + offset * mid) * CFrame.Angles(0, -angle, 0)
			if blades[i] then
				blades[i].Size = Vector3.new(segmentLength, look.bladeHeight, data.thickness * 1.4)
				blades[i].CFrame = CFrame.new(center + offset * mid) * CFrame.Angles(0, -angle, 0)
			end
			local pair = edges[i]
			if pair then
				for k, edge in ipairs(pair) do
					edge.Size = Vector3.new(segmentLength, 0.35, data.thickness)
					edge.CFrame = CFrame.new(center + offset * mid + Vector3.new(0, (k == 1 and 1 or -1) * waveHeight / 2, 0)) * CFrame.Angles(0, -angle, 0)
				end
			end
		end
		if #heave > 0 then
			local H = look.heave
			local t = Workspace:GetServerTimeNow() - data.serverStart
			local r = math.max(mid - data.thickness / 2 - H.behindStuds, 0.5)
			local len = 2 * math.pi * r / H.segments * 1.05
			for i, part in ipairs(heave) do
				local angle = (i / H.segments) * 2 * math.pi
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local h = 0.2 + H.amplitude * math.max(0, math.sin(angle * H.waves + t * H.speed))
				part.Size = Vector3.new(len, h, H.width)
				part.CFrame = CFrame.new(data.center + offset * r + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, -angle, 0)
			end
		end
		if #crest > 0 then
			local t = Workspace:GetServerTimeNow() - data.serverStart
			local crestLength = 2 * math.pi * math.max(radius, 1) / ground.segments * 1.1
			local rise = math.clamp(radius / 6, 0, 1) -- 보스 곁에서 솟아나기 시작한다
			for i, part in ipairs(crest) do
				local angle = (i / ground.segments) * 2 * math.pi
				local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
				-- 마루 높이가 둘레를 따라 굴러간다(솟았다 꺼진다) - 띠 높이보다 낮다
				local h = ground.crestHeight * rise * (0.65 + 0.35 * math.sin(angle * ground.rollWaves + t * ground.rollSpeed))
				part.Size = Vector3.new(crestLength, math.max(h, 0.05), data.thickness * 0.8)
				part.CFrame = CFrame.new(data.center + offset * mid + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, -angle, math.rad(8 * math.sin(angle * ground.rollWaves + t * ground.rollSpeed)))
			end
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
	local y = data.floorY + 0.15 + moundLiftSegment(Vector3.new(data.bossPosition.X, data.floorY, data.bossPosition.Z), Vector3.new(data.endPosition.X, data.floorY, data.endPosition.Z), data.halfWidth) -- P3c B4
	line.CFrame = CFrame.lookAt(Vector3.new(mid.X, y, mid.Z), Vector3.new(data.endPosition.X, y, data.endPosition.Z))
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
	local followed = {}
	for _, entry in ipairs(data.track or {}) do
		if entry.userId then
			followed[entry.index] = entry.userId
		end
	end
	for index, position in ipairs(data.positions) do
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
		if followed[index] then -- P3c A4: 맞아서 튕겨 난 사람을 따라가는 원(멈추면 서버가 meteorLock으로 멈춘 자리를 보낸다)
			BossRhythmView.follow({ disc, inner }, followed[index], data.lockIn or 0.5)
		end
	end
end

-- P3c A4: 추적이 멈췄다 - 지금 원을 지우고 서버가 멈춘 자리에 남은 시간만큼 다시 그린다(멈춘 뒤의 원 = 판정 자리).
local function meteorLock(data)
	for _, disc in ipairs(meteorDiscs) do
		destroy(disc)
	end
	meteorDiscs = {}
	meteor({ positions = data.positions, radius = data.radius, seconds = data.seconds, style = data.style })
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
		elseif data.motion == "fist" then
			-- BR1 쌍권 연타: 낙석 기둥 대신 주먹이 내려찍는다(임팩트 = 흰색).
			BossBR1View.fistSlam(position, data.radius)
			fadeOut(newDisc(position, data.radius, IMPACT_COLOR, 0.1), 0.35)
			continue
		elseif data.style == "whirl" then
			-- 29-4: 회오리 - 흰 띠가 나선으로 돌며 솟는다(임팩트 = 흰색).
			BossStormView.whirl(position, data.radius)
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
			local up = Vector3.new(0, 0.15 + moundLiftSegment(data.center, data.center + dir * length, data.halfWidth), 0) -- P3c B4
			line.CFrame = CFrame.lookAt(mid + up, data.center + dir * length + up)
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
	-- BR1 반사 레이저: 벽에서 꺾인 선분(시작점 · 각 · 길이 - 서버 판정의 두 번째 선분 그대로).
	for _, segment in ipairs(data.segments or {}) do
		local a = math.rad(segment.angleDeg)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local line = newPart(Vector3.new(data.halfWidth * 2, 0.2, segment.length), DANGER_COLOR, 0.8)
		line.CFrame = CFrame.lookAt(segment.origin + dir * (segment.length / 2) + Vector3.new(0, 0.15, 0), segment.origin + dir * segment.length + Vector3.new(0, 0.15, 0))
		TweenService:Create(line, TweenInfo.new(data.seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 0.35 }):Play()
		table.insert(crossLines, line)
	end
end

local function crossFire(data)
	for _, line in ipairs(crossLines) do
		if live[line] and data and data.motion == "mirrorDash" then
			-- BR1 분신 돌격: 선을 따라 달리는 흰 잔상(인형 대신 조각 - 그림만)
			local look = line.CFrame.LookVector
			local back = line.Position - look * (line.Size.Z / 2)
			for k = 0, 4 do
				BossFx.streak(back + look * (line.Size.Z * k / 5) + Vector3.new(0, 2.5, 0), look, 6, 1.2, IMPACT_COLOR, 0.35 + k * 0.05, 30)
			end
		end
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
		if data.safeProp or data.safeZone or data.safeCircles then
			BossArenaPropsView.showGlobalTelegraph(data)
		end
		if data.safeZone then
			BossFloodView.telegraph(data.safeZone)
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
		BossFloodView.reset()
		BossStormView.dischargeRods(false)
		BossSplitView.clear()
		BossEnvironmentView.reset() -- BR1: 보스전이 끝났다(환경 그림 · 빙판 · 점프대 힘)
	elseif kind == "splitStart" then
		BossSplitView.start(data)
	elseif kind == "splitBreak" then
		BossSplitView.breakDecoy(data)
	elseif kind == "splitShuffle" then
		BossSplitView.shuffle(data)
	elseif kind == "gardenCoreHit" then
		BossEnvironmentView.coreHit(data)
	elseif kind == "splitEnd" then
		BossSplitView.clear()
	elseif kind == "stanceStart" then
		BossStanceView.start(data)
	elseif kind == "stanceEnd" then
		BossStanceView.clear()
	elseif kind == "reflectHit" then
		BossStanceView.reflect(data)
	elseif kind == "launch" then
		BossStormView.launch(data)
	elseif kind == "hintArrows" then
		BossGateView.showHintArrows(data.positions, data.seconds)
	elseif kind == "zoneCharge" then
		BossStormView.chargeRod(data)
	elseif kind == "zoneDischarge" then
		BossStormView.dischargeRods(true)
	elseif kind == "zoneStep" then
		BossFloodView.step(data)
	elseif kind == "zonesReset" then
		BossFloodView.reset()
	elseif kind == "daze" then
		showBubble("daze", data.seconds)
	elseif kind == "heavyTelegraph" then
		heavyTelegraph(data)
	elseif kind == "heavyImpact" then
		heavyImpact(data)
	elseif kind == "shockTelegraph" then
		shockTelegraph(data)
		BossMotionView.slamWindup(data) -- P3d A1: 크게 들어 올리는 예비 동작
	elseif kind == "shockwave" then
		shockwave(data)
		BossRhythmView.waveCue(data)
		if (data.layer or 1) == 1 then
			BossMotionView.slamImpact(data) -- P3d A2: 내려찍는 순간 풍압 · 흔들림
		end
	elseif kind == "focus" then
		focus(data)
		BossRhythmView.chargeTarget(data)
		BossMotionView.chargeWindup(data) -- P3d A4: 발 긁기
	elseif kind == "charge" then
		charge(data)
		BossMotionView.chargeRun(data) -- P3d A4: 속도선 · 잔상 · 먼지 꼬리 · 도착 임팩트
	elseif kind == "meteor" then
		meteor(data)
	elseif kind == "meteorLock" then
		meteorLock(data)
	elseif kind == "meteorImpact" then
		meteorImpact(data)
	elseif kind == "cross" then
		cross(data)
	elseif kind == "crossFire" then
		crossFire(data)
	elseif kind == "sector" then
		BossBR1View.sector(data)
		if data.outline then
			BossBR13View.swipeOutline(data)
		end
	elseif kind == "sectorImpact" then
		BossBR1View.sectorImpact(data)
	elseif kind == "projTelegraph" then
		BossBR1View.projTelegraph(data)
	elseif kind == "projSpawn" then
		BossBR1View.projSpawn(data)
	elseif kind == "projSync" then
		BossBR1View.projSync(data)
	elseif kind == "projBounce" then
		BossBR1View.projBounce(data)
	elseif kind == "projEnd" then
		BossBR1View.projEnd(data)
	elseif kind == "vortex" then
		BossBR1View.vortex(data)
	elseif kind == "vortexBurst" then
		BossBR1View.vortexBurst(data)
	elseif kind == "chain" then
		BossBR1View.chain(data)
	elseif kind == "chainImpact" then
		BossBR1View.chainImpact(data)
	elseif kind == "ambushDig" then
		BossBR1View.ambushDig(data)
	elseif kind == "ambushEmerge" then
		BossBR1View.ambushEmerge(data)
	elseif kind == "grabTelegraph" then
		BossGrabView.telegraph(data)
	elseif kind == "grabMark" then
		BossGrabView.mark(data)
	elseif kind == "grabFreeze" then
		BossGrabView.freeze(data)
	elseif kind == "grabPick" then
		BossGrabView.pick(data)
	elseif kind == "grabRelease" then
		BossGrabView.unfreeze(data.userId)
	elseif kind == "grabThrow" then
		BossGrabView.throw(data)
	elseif kind == "bubbleTrap" then
		BossGrabView.bubble(data)
	elseif kind == "reflectTelegraph" and data.style == "armadillo" then
		BossBR13View.armadilloTelegraph(data)
	elseif kind == "reflectStance" and data.style == "armadillo" then
		BossBR13View.armadilloStance(data)
	elseif kind == "reflectTelegraph" then
		BossBR1View.reflectTelegraph(data)
	elseif kind == "reflectStance" then
		BossBR1View.reflectStance(data)
	elseif kind == "reflectShot" then
		BossBR1View.reflectShot(data)
	elseif kind == "reflectEnd" then
		BossBR1View.reflectEnd()
		BossBR13View.armadilloEnd()
	elseif kind == "spikeMark" then
		BossBR13View.spikeMark(data)
	elseif kind == "spikeImpact" then
		BossBR13View.spikeImpact(data)
	elseif kind == "playerStun" then
		BossBR13View.playerStun(data)
	elseif kind == "sweepTelegraph" then
		BossBR13View.sweepTelegraph(data)
	elseif kind == "sweepFire" then
		BossBR13View.sweepFire(data)
	elseif kind == "sweepEnd" then
		BossBR13View.sweepEnd()
	elseif kind == "boomTelegraph" then
		BossBR13View.boomTelegraph(data)
	elseif kind == "boomRun" then
		BossBR13View.boomRun()
	elseif kind == "boomEnd" then
		BossBR13View.boomEnd()
	elseif kind == "sandDig" then
		BossGimmick13View.sandDig(data)
	elseif kind == "sandStart" then
		BossGimmick13View.sandStart(data)
	elseif kind == "sandBlast" then
		BossGimmick13View.sandBlast(data)
	elseif kind == "sandEnd" then
		BossGimmick13View.sandEnd(data)
	elseif kind == "orgelStart" then
		BossGimmick13View.orgelStart(data)
	elseif kind == "orgelRing" then
		BossGimmick13View.orgelRing(data)
	elseif kind == "orgelInput" then
		BossGimmick13View.orgelInput(data)
	elseif kind == "orgelHit" then
		BossGimmick13View.orgelHit(data)
	elseif kind == "orgelStatue" then
		BossGimmick13View.orgelStatue(data)
	elseif kind == "orgelEnd" then
		BossGimmick13View.orgelEnd(data)
	elseif kind == "voidFall" then
		BossEnvironmentView.voidFall(data)
	elseif kind == "sonicTelegraph" then
		BossSonicView.telegraph(data)
	elseif kind == "sonicTick" then
		BossSonicView.tick(data)
	elseif kind == "colorStart" then
		BossColorView.start(data)
	elseif kind == "colorFlip" then
		BossColorView.flip(data)
	elseif kind == "colorResolve" then
		BossColorView.resolve(data)
	elseif kind == "colorEnd" then
		BossColorView.finish()
	elseif kind == "basicSweep" then
		BossInnerCircleView.sweep(data)
	elseif kind == "bossAirborne" then -- BR1-2 보스 에어본: 발밑 먼지 고리 + 흔들림(보스 몸은 서버가 띄운다)
		BossFx.ring(data.position - Vector3.new(0, 1.5, 0), 2, 12, Color3.new(1, 1, 1), 0.4)
		BossFx.shake(data.position, 0.7)
	elseif kind == "bossLand" then -- 떨어짐: 큰 먼지 고리 + 크게 흔들림
		BossFx.ring(data.position - Vector3.new(0, 1.5, 0), 3, 20, Color3.fromRGB(235, 228, 214), 0.6)
		BossFx.shake(data.position, 1.0)
	elseif kind == "courseHelp" then
		BossEnvironmentView.courseHelp(data)
	elseif kind == "starTwinkle" then
		BossEnvironmentView.starTwinkle(data)
	elseif kind == "rodsStart" then
		BossRodsView.start(data)
	elseif kind == "rodsStatus" then
		BossRodsView.status(data)
	elseif kind == "rodsTarget" then
		BossRodsView.target(data)
	elseif kind == "rodsLock" then
		BossRodsView.lock(data)
	elseif kind == "rodsStrike" then
		BossRodsView.strike(data)
	elseif kind == "rodsAmbient" then
		BossRodsView.ambient(data)
	elseif kind == "rodsAmbientHit" then
		BossRodsView.ambientHit(data)
	elseif kind == "rodsEnd" then
		BossRodsView.clear()
	elseif kind == "grabEnd" or kind == "grabMiss" then
		BossGrabView.clear()
	elseif kind == "envTelegraph" then
		BossEnvironmentView.telegraph(data)
	elseif kind == "envStart" then
		BossEnvironmentView.start(data)
	elseif kind == "envWind" then
		BossEnvironmentView.wind(data)
	elseif kind == "envEnd" then
		BossEnvironmentView.clear()
	elseif kind == "field" then
		BossEnvironmentView.field(data)
	elseif kind == "regrowTelegraph" then
		BossRegrowView.telegraph(data)
	elseif kind == "regrowSpawn" then
		BossRegrowView.spawn(data)
	elseif kind == "reset" then
		resetAll()
		BossRhythmView.clear()
		BossMotionView.reset()
		BossRegrowView.clear() -- 리뷰 2: 끼임 표시도(서버가 풀었다는 알림을 못 받았어도 리셋이면 지운다)
		BossArenaPropsView.clearTelegraph() -- 기둥 자체는 남는다(서버가 propsClear로 따로 치운다)
		BossStanceView.clear()
		BossSplitView.clear()
		BossFloodView.reset()
		BossStormView.dischargeRods(false)
		BossBR1View.reset() -- BR1
		BossGrabView.reset()
		BossSonicView.reset()
		BossColorView.finish()
		BossRodsView.clear()
		BossBR13View.reset() -- BR1-3
		BossGimmick13View.reset()
		-- 환경 그림은 여기서 안 지운다(리뷰 4 - 스킬 중단 · 대상 이탈의 "reset"에도 서버 환경은 계속 돈다): envEnd · propsClear에서
	end
end)

BossArenaPropsView.start()

-- 내 캐릭터가 죽어 리스폰될 때도 남은 연출을 지운다(서버 reset과 이중 방어).
player.CharacterAdded:Connect(function()
	resetAll()
	BossMotionView.reset()
	BossRegrowView.clear()
end)
