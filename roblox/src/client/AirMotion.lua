-- 공중 점프 · 대시 모션(M1-0 - 그리기만, 판정 없음). 캐릭터 루트 관절(루트 파트에 붙은 관절)의 루트 쪽 프레임 앞에 회전을 곱한다 - Animator는 Transform만 덮어써서 이 프레임은 남는다.
--   관절 종류: Motor6D(옛 리그) = C0 · AnimationConstraint(아바타 관절 업그레이드 - Studio Play 실측, Motor6D가 없다) = Attachment0.CFrame. 둘 다 "루트 파트 공간에서 본 관절 자리"라 같은 식이다.
-- 회전축 = 루트의 오른쪽 축(R15 · R6 공통) · 앞으로 도는 방향. 입력 즉시 시작한다(준비 동작 없음). 자기 캐릭터는 입력한 클라가, 남의 캐릭터는 서버 중계(AirMoveFx)를 받은 클라가 부른다.
--   flip = 앞으로 한 바퀴(seconds 동안 · 끝으로 갈수록 느려짐) / lean = 앞으로 leanDeg까지 기울었다가 돌아옴(대시 시간 동안).
--   MV1 spin = 제자리 한 바퀴(deg - 공중 회전 베기) · hold(character, key, deg) = 풀 때까지 그 각으로 기울인 자세(활강 = 앞으로 눕기 · 낙하 쓰러짐 = 뒤로 눕기) · release(character, key)로 푼다. 유지 자세가 있으면 flip · lean보다 우선한다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local AirMotion = {}

local cfg = MovementConfig.airMotion
local active = {} -- [프레임을 가진 인스턴스(Motor6D 또는 Attachment)] = { base, prop, kind, startedAt, seconds }
local holds = {} -- [관절] = { base, prop, key, angle(목표 rad), current(rad) }
local HOLD_EASE_PER_SECOND = 8 -- 유지 자세로 들어가고 나오는 빠르기(1/초 - 지수 접근)

-- 반환: 회전을 걸 인스턴스, 그 속성 이름.
local function rootJoint(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 == root then
			return d, "C0"
		elseif d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment0.Parent == root then
			return d.Attachment0, "CFrame"
		end
	end
	return nil
end

function AirMotion.hold(character, key, deg)
	local joint, prop = rootJoint(character)
	if not joint then
		return
	end
	local running = active[joint]
	local base = (holds[joint] and holds[joint].base) or (running and running.base) or joint[prop]
	active[joint] = nil
	holds[joint] = { base = base, prop = prop, key = key, angle = -math.rad(deg), current = holds[joint] and holds[joint].current or 0 }
end

function AirMotion.release(character, key)
	local joint = rootJoint(character)
	local h = joint and holds[joint]
	if h and (key == nil or h.key == key) then
		h.angle, h.releasing = 0, true
	end
end

-- deg(선택): lean의 기울기(양수 = 앞 · 음수 = 뒤 - 없으면 MovementConfig.airMotion.leanDeg). MV1 공중 공격 자세가 쓴다.
function AirMotion.play(character, kind, seconds, deg)
	local joint, prop = rootJoint(character)
	if not joint or not seconds or seconds <= 0 then
		return
	end
	if holds[joint] then
		return -- 유지 자세가 우선(활강 중 공중 점프 · 대시 모션은 건너뛴다)
	end
	local running = active[joint]
	active[joint] = { base = running and running.base or joint[prop], prop = prop, kind = kind, startedAt = os.clock(), seconds = seconds, deg = deg }
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for joint, h in pairs(holds) do
		h.current += (h.angle - h.current) * math.min(1, dt * HOLD_EASE_PER_SECOND)
		if not joint.Parent or (h.releasing and math.abs(h.current) < 0.01) then
			if joint.Parent then
				joint[h.prop] = h.base
			end
			holds[joint] = nil
		else
			joint[h.prop] = CFrame.Angles(h.current, 0, 0) * h.base
		end
	end
	for joint, st in pairs(active) do
		local p = (now - st.startedAt) / st.seconds
		if p >= 1 or not joint.Parent then
			joint[st.prop] = st.base
			active[joint] = nil
		else
			local rot
			if st.kind == "flip" then
				rot = CFrame.Angles(-2 * math.pi * (1 - (1 - p) ^ 2), 0, 0)
			elseif st.kind == "spin" then
				rot = CFrame.Angles(0, -math.rad(st.deg or 360) * (1 - (1 - p) ^ 2), 0) -- MV1 공중 회전 베기(몸이 제자리에서 한 바퀴)
			else
				rot = CFrame.Angles(-math.rad(st.deg or cfg.leanDeg) * math.sin(math.pi * p), 0, 0)
			end
			joint[st.prop] = rot * st.base
		end
	end
end)

return AirMotion
