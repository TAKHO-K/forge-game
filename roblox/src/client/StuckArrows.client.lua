-- 꽂히는 화살(20-5 [2]) 시각 표시 - 서버(StuckArrowState.lua)가 유일한 진실이다. 이
-- 스크립트는 "꽂혔다"/"터졌다"/"전부 지워라" 세 이벤트를 받아 작은 Part를 붙였다 뗄
-- 뿐, 데미지·타이밍 판단은 전혀 하지 않는다(BuffHud.client.lua와 같은 원칙).
--
-- 자기 전투만 표시(PRD-forge-game-roblox.md 20.13 C안과 같은 방향 - AttackServer.
-- server.lua도 attackResult/attackLaunched를 FireClient 하나로만 보낸다) - 서버가
-- 애초에 화살을 꽂은 플레이어에게만 이 이벤트를 보내므로, 남의 화살은 이 클라이언트에
-- 아예 도착하지 않는다.
--
-- 위치 고정은 WeldConstraint 하나로 끝낸다 - HitEffects.lua 주석이 남긴 경고("Root/Body/
-- Head는 서버가 매 프레임 위치를 되돌려 놓으므로 CFrame을 직접 건드리면 안 된다")는
-- "매 프레임 스크립트로 따라가려는" 접근에만 해당한다. WeldConstraint는 물리 엔진이
-- 알아서 Part1(Head)을 따라가게 만드는 관계라 매 프레임 스크립트 비용이 0이고, 서버가
-- Head 위치를 되돌리는 것과 충돌하지 않는다(오히려 그 되돌려진 위치를 그대로 따라간다).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HitEffects = require(script.Parent.HitEffects)
local DamageNumbers = require(script.Parent.DamageNumbers)

local stuckArrowAttach = ReplicatedStorage:WaitForChild("StuckArrowAttach")
local stuckArrowResult = ReplicatedStorage:WaitForChild("StuckArrowResult")
local stuckArrowClear = ReplicatedStorage:WaitForChild("StuckArrowClear")

-- [id] = Part. 서버가 주는 id는 전역 증가값이라 플레이어 하나 안에서 충돌하지 않는다.
local stuckParts = {}

-- 실기 확인(20-5 검증) - 처음 잡은 값(두께 0.05, 파묻힘 0.4)은 몬스터 몸 안에 거의
-- 다 파묻혀 화면에서 거의 안 보였다("이 그림이 이번 작업의 목적 그 자체다"라는 지시와
-- 정면으로 어긋난다). 두께를 키우고 파묻히는 깊이를 얕게 줄여 몸 밖으로 확실히
-- 튀어나오게 고쳤다 - 그래도 몬스터 자체보다는 작다("작은 Part", 지시).
local ARROW_SIZE = Vector3.new(0.16, 0.16, 1.2)
local ARROW_COLOR = Color3.fromRGB(255, 140, 40) -- 하늘색(Projectiles.lua 쪽 배색)은 배경 하늘과 섞여 눈에 안 띄었다 - 대비가 강한 주황으로 바꿨다.
local EMBED_DEPTH_STUDS = 0.15 -- 표면에 살짝만 박히고 대부분 밖으로 나온다.
local JITTER_RADIUS_STUDS = 0.5 -- 여러 개가 겹쳐 보이지 않도록 매번 살짝 다른 자리에 꽂는다.

local jitterRng = Random.new()

local function randomJitter()
	return Vector3.new(
		(jitterRng:NextNumber() - 0.5) * JITTER_RADIUS_STUDS,
		(jitterRng:NextNumber() - 0.5) * JITTER_RADIUS_STUDS,
		(jitterRng:NextNumber() - 0.5) * JITTER_RADIUS_STUDS
	)
end

stuckArrowAttach.OnClientEvent:Connect(function(monsterModel, id, hitDirection)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return -- 도착 전에 몬스터가 이미 사라진 드문 경우(Projectiles.lua의 같은 종류 가드와 동일 이유) - 붙일 대상이 없다.
	end

	local direction = (typeof(hitDirection) == "Vector3" and hitDirection.Magnitude > 1e-3) and hitDirection.Unit or Vector3.new(0, 0, 1)
	-- 실기 확인(20-5 검증) - head.Position은 구의 "중심"이다. EMBED_DEPTH_STUDS를 중심
	-- 기준으로 빼면 반지름(약 1.6stud)짜리 구 안 깊숙이 파묻혀 화면에 아예 안 보였다
	-- (처음 실수 - 20.43 참고). 표면 지점(중심 + 반지름만큼 날아온 방향 반대쪽)에서
	-- EMBED_DEPTH_STUDS만큼만 얕게 파고들게 고쳤다.
	local headRadius = head.Size.X / 2
	local surfacePoint = head.Position - direction * headRadius
	local embedPosition = surfacePoint + direction * EMBED_DEPTH_STUDS + randomJitter()

	local part = Instance.new("Part")
	part.Name = "StuckArrow"
	part.Size = ARROW_SIZE
	part.Color = ARROW_COLOR
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	part.Anchored = false
	-- 화살이 날아온 방향(direction)을 그대로 꽂힌 방향으로 쓴다("날아온 방향과 맞으면
	-- 더 자연스럽다", 지시) - 꼬리가 날아온 쪽을 향하게 180도 돌려 놓는다.
	part.CFrame = CFrame.lookAt(embedPosition, embedPosition - direction)
	part.Parent = monsterModel

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = head
	weld.Parent = part

	if stuckParts[id] then
		stuckParts[id]:Destroy() -- 방어적 가드 - 같은 id가 재사용될 일은 없지만(nextId는 계속 증가), 혹시를 대비.
	end
	stuckParts[id] = part

	-- 이 화살 자신이 터지지 않은 채로 몬스터가 죽어 모델 전체가 Destroy될 수도 있다
	-- (StuckArrowResult가 안 오는 경로 - StuckArrowState.explode가 죽은 몬스터를 보고
	-- 조용히 끝나는 경우). Destroying은 그 cascade로 이 Part가 없어질 때도 불려서,
	-- stuckParts에 죽은 Instance 참조가 계속 쌓이는 걸 막는다.
	part.Destroying:Connect(function()
		if stuckParts[id] == part then
			stuckParts[id] = nil
		end
	end)
end)

-- 터지는 순간(지시 - "터지는 순간이 보여야 한다. 작은 섬광이나 파티클") - HitEffects의
-- 기존 피격 버스트를 그대로 재사용한다(새 함수를 만들지 않는다는 원칙) - 사망 시엔
-- 사망 연출로 대체하는 것도 AttackInput.client.lua의 showResult와 같은 원칙이다.
stuckArrowResult.OnClientEvent:Connect(function(monsterModel, id, damage, isCrit, isDead)
	if monsterModel then
		DamageNumbers.show(monsterModel, damage, isCrit)
		if isDead then
			HitEffects.playDeath(monsterModel)
		else
			HitEffects.playHit(monsterModel, isCrit)
		end
	end

	local part = stuckParts[id]
	if part then
		stuckParts[id] = nil
		part:Destroy()
	end
end)

-- 퇴장·직업 변경(StuckArrowState.clearForPlayer) - 데미지 없이 조용히 남은 화살을
-- 전부 지운다(폭발 이펙트 없이 - "터졌다"가 아니라 "취소됐다"이므로).
stuckArrowClear.OnClientEvent:Connect(function()
	for id, part in pairs(stuckParts) do
		part:Destroy()
		stuckParts[id] = nil
	end
end)
