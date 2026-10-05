-- BOSS-FRAMEWORK 3 2차 움직임(새 몸 리그 v2 전용 - 옛 몸은 BossAnimator stepSprings 그대로): 관절 사슬마다 마디별 감쇠 스프링.
--   첫 마디 = 몸 가속(보이는 루트 - 앞뒤 · 좌우) + 방향 전환 속도에 늦게 반응 · 다음 마디 = 앞 마디 휨을 carry만큼 늦게 따라감(꼬리 · 날개 · 망토 · 코 · 털 · 수정이 물결처럼).
--   종류별 강성 · 감쇠 = shared/data/BossFrameworkData.springs(kind) · 폰 · 낮은 그래픽 = springLiteRate(0.5 = 두 프레임에 한 번 · 그 사이는 마지막 값 유지).
--   판정 무관(보이는 몸만) · 잡기 중에는 끈다(서버 잡기 FK와 같은 자세 - BossAnimator가 부르지 않는다).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Frame = require(ReplicatedStorage.Shared.data.BossFrameworkData)
local GraphicsMode = require(script.Parent.GraphicsMode)

local BossSpring = {}

function BossSpring.new(rig)
	local chains = {}
	for _, c in ipairs(rig.chains or {}) do
		local spec = Frame.springs[c.kind or "cloth"] or Frame.springs.cloth
		local s = { spec = spec, joints = {}, x = {}, z = {}, vx = {}, vz = {} }
		for i, joint in ipairs(c) do
			s.joints[i] = joint
			s.x[i], s.z[i], s.vx[i], s.vz[i] = 0, 0, 0, 0
		end
		table.insert(chains, s)
	end
	return { chains = chains, acc = 0, frame = 0 }
end

-- 이 기기가 절반 갱신인가(폰 · lite - 0.5초마다 다시 본다)
local liteCache, liteAt = false, -1
local function isLite()
	local now = os.clock()
	if now - liteAt > 0.5 then
		liteAt = now
		local ok, lite = pcall(GraphicsMode.isLite)
		liteCache = (ok and lite) or game:GetService("Players").LocalPlayer:GetAttribute("A2M1ForcePhone") == true
	end
	return liteCache
end
BossSpring.isLite = isLite

-- accelLocal = 보이는 루트 가속(몸 공간 · 이미 작게 줄인 값 - 옛 stepSprings와 같은 단위) · turn = 방향 전환 속도(rad/s)
local function step(state, dt, accelLocal, turn)
	for _, s in ipairs(state.chains) do
		local P = s.spec
		local k, c, carry, maxA = P.k, P.c, P.carry, P.max
		for i = 1, #s.joints do
			local tx, tz
			if i == 1 then
				tx = accelLocal.Z * 0.9 * P.gain
				tz = -accelLocal.X * 0.9 * P.gain - turn * P.turnGain
			else
				tx, tz = s.x[i - 1] * carry, s.z[i - 1] * carry
			end
			s.vx[i] += (k * (tx - s.x[i]) - c * s.vx[i]) * dt
			s.vz[i] += (k * (tz - s.z[i]) - c * s.vz[i]) * dt
			s.x[i] = math.clamp(s.x[i] + s.vx[i] * dt, -maxA, maxA)
			s.z[i] = math.clamp(s.z[i] + s.vz[i] * dt, -maxA, maxA)
		end
	end
end

-- 매 프레임 부른다: 갱신(전체 또는 절반) 뒤 자세에 더한다. 반환 = 이번 프레임에 스프링을 계산했는가(측정용)
function BossSpring.apply(state, pose, dt, accelLocal, turn)
	state.frame += 1
	state.acc += dt
	local rate = isLite() and Frame.springLiteRate or 1
	local stepped = false
	if rate >= 1 or state.frame % math.max(1, math.round(1 / rate)) == 0 then
		local h = math.min(state.acc, 1 / 15) -- 긴 멈춤 뒤 폭주 방지
		-- 안정성: 큰 dt는 반으로 나눠 두 번
		if h > 1 / 45 then
			step(state, h / 2, accelLocal, turn)
			step(state, h / 2, accelLocal, turn)
		else
			step(state, h, accelLocal, turn)
		end
		state.acc = 0
		stepped = true
	end
	for _, s in ipairs(state.chains) do
		for i, joint in ipairs(s.joints) do
			local v = pose[joint]
			if v then
				pose[joint] = { (v[1] or 0) + s.x[i], v[2] or 0, (v[3] or 0) + s.z[i], v[4] or 0, v[5] or 0, v[6] or 0, v[7] }
			else
				pose[joint] = { s.x[i], 0, s.z[i], 0, 0, 0 }
			end
		end
	end
	return stepped
end

return BossSpring
