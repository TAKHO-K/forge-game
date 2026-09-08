-- 피격·사망 반응(14-2). 몬스터 9마리가 동시에 맞고 죽는 게 정상 시나리오라(지시 사항),
-- 타격마다 Instance.new/Destroy를 하지 않는다 - 고정 개수 파트를 미리 만들어 두고
-- 라운드로빈으로 재사용한다(풀링). TweenService는 같은 인스턴스의 같은 프로퍼티를
-- 다시 Play()하면 이전 트윈을 자동으로 덮어써서 별도 취소 로직이 필요 없다.
--
-- 풀 크기 근거(숫자로): "9마리 동시" 시나리오 + 여유 3개 = 12. 이펙트 하나의 수명이
-- 0.18~0.4초로 짧아(아래 DURATION 상수) 실제로 동시에 "재생 중"인 이펙트가 12개를
-- 넘는 상황은 광역 스킬이 생기기 전까지는 거의 없다 - 넘어서도 라운드로빈이라 오래된
-- 이펙트를 새 이펙트가 밀어내는 것뿐(끊긴 채로 재생되는 정도)이라 에러는 안 난다.
-- 파트 12개(Neon Ball, 메시 없음)는 모바일 기준으로도 무시할 수준이다 - 이 사냥터에
-- 이미 상시 존재하는 파트가 몬스터 9마리×3파트(Root·Body·Head)=27개인데 그 절반도 안
-- 된다.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local HitEffects = {}

local POOL_SIZE = 12
local pool = {}
local poolIndex = 0

local NORMAL_COLOR = Color3.fromRGB(255, 250, 210)
local NORMAL_DURATION = 0.18
local NORMAL_MAX_SIZE = 1.6

local CRIT_COLOR = Color3.fromRGB(255, 90, 30)
local CRIT_DURATION = 0.26
local CRIT_MAX_SIZE = 2.6

local DEATH_COLOR_FALLBACK = Color3.fromRGB(255, 240, 200)
local DEATH_DURATION = 0.35
local DEATH_MAX_SIZE = 3.2

local FLASH_COLOR = Color3.new(1, 1, 1)
local FLASH_BACK_SECONDS = 0.15

for i = 1, POOL_SIZE do
	local part = Instance.new("Part")
	part.Name = "HitBurst"
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Parent = Workspace
	pool[i] = part
end

local function nextSlot()
	poolIndex = (poolIndex % POOL_SIZE) + 1
	return pool[poolIndex]
end

local function burst(position, color, maxSize, duration)
	local part = nextSlot()
	part.Color = color
	part.Size = Vector3.new(0.3, 0.3, 0.3)
	part.Position = position
	part.Transparency = 0.1

	TweenService:Create(part, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(maxSize, maxSize, maxSize),
		Transparency = 1,
	}):Play()
end

-- 몬스터 반응 - 색만 순간 바꾼다(밀림/넉백은 일부러 뺐다: Root/Body/Head는 서버
-- MonsterAI.server.lua가 매 프레임 위치를 되돌려 놓으므로, 클라이언트에서 CFrame을
-- 건드리면 다음 서버 리플리케이션에 즉시 덮어써져 흔들리거나 안 보일 위험이 크다.
-- Color3는 서버가 손대지 않는 프로퍼티라 이 충돌이 없다).
local function flashMonster(monsterModel)
	for _, partName in ipairs({ "Body", "Head" }) do
		local part = monsterModel:FindFirstChild(partName)
		if part then
			local originalColor = part.Color
			part.Color = FLASH_COLOR
			TweenService:Create(part, TweenInfo.new(FLASH_BACK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = originalColor,
			}):Play()
		end
	end
end

-- 일반/치명타 둘 다 이 진입점 하나 - 크기·색·지속시간만 다르다(치명타가 더 크고 진한
-- 색, 숫자 크기·폰트 구분과 같은 원칙).
function HitEffects.playHit(monsterModel, isCrit)
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not head then
		return
	end

	if isCrit then
		burst(head.Position, CRIT_COLOR, CRIT_MAX_SIZE, CRIT_DURATION)
	else
		burst(head.Position, NORMAL_COLOR, NORMAL_MAX_SIZE, NORMAL_DURATION)
	end
	flashMonster(monsterModel)
end

-- 사망 연출 - 큰 버스트(색은 몬스터 Body 색을 그대로 재사용, "이 몬스터가 터졌다"는
-- 인상) + Body/Head를 그 자리에서 줄어들며 사라지게 한다(위치는 그대로 두고 크기·
-- 투명도만 바꾼다 - Body/Head가 서로 다른 절대 위치를 갖고 있어(머리는 몸통 위 2.3stud
-- 고정) 자리를 다시 계산해 옮기려 하지 않는다, 그러면 "흩어짐"이 아니라 "겹쳐짐"이
-- 될 위험이 있다). MonsterSpawner.despawn이 damageNumberLifetimeSeconds(0.8초) 뒤에
-- 실제로 Destroy하므로, 이 연출(0.35초)이 그 안에 여유 있게 끝난다.
function HitEffects.playDeath(monsterModel)
	local body = monsterModel and monsterModel:FindFirstChild("Body")
	local head = monsterModel and monsterModel:FindFirstChild("Head")
	if not body then
		return
	end

	burst(body.Position, body.Color or DEATH_COLOR_FALLBACK, DEATH_MAX_SIZE, DEATH_DURATION)

	for _, part in ipairs({ body, head }) do
		if part then
			TweenService:Create(part, TweenInfo.new(DEATH_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
				Size = Vector3.new(0.05, 0.05, 0.05),
				Transparency = 1,
			}):Play()
		end
	end
end

return HitEffects
