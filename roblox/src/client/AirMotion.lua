-- 공중 점프 · 대시 모션(M1-0 - 그리기만, 판정 없음). 캐릭터 루트 관절(루트 파트에 붙은 관절)의 루트 쪽 프레임 앞에 회전을 곱한다 - Animator는 Transform만 덮어써서 이 프레임은 남는다.
--   관절 종류: Motor6D(옛 리그) = C0 · AnimationConstraint(아바타 관절 업그레이드 - Studio Play 실측, Motor6D가 없다) = Attachment0.CFrame. 둘 다 "루트 파트 공간에서 본 관절 자리"라 같은 식이다.
-- 회전축 = 루트의 오른쪽 축(R15 · R6 공통) · 앞으로 도는 방향. 입력 즉시 시작한다(준비 동작 없음). 자기 캐릭터는 입력한 클라가, 남의 캐릭터는 서버 중계(AirMoveFx)를 받은 클라가 부른다.
--   flip = 앞으로 한 바퀴(seconds 동안 · 끝으로 갈수록 느려짐) / lean = 앞으로 leanDeg까지 기울었다가 돌아옴(대시 시간 동안).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local AirMotion = {}

local cfg = MovementConfig.airMotion
local active = {} -- [프레임을 가진 인스턴스(Motor6D 또는 Attachment)] = { base, prop, kind, startedAt, seconds }

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

function AirMotion.play(character, kind, seconds)
	local joint, prop = rootJoint(character)
	if not joint or not seconds or seconds <= 0 then
		return
	end
	local running = active[joint]
	active[joint] = { base = running and running.base or joint[prop], prop = prop, kind = kind, startedAt = os.clock(), seconds = seconds }
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for joint, st in pairs(active) do
		local p = (now - st.startedAt) / st.seconds
		if p >= 1 or not joint.Parent then
			joint[st.prop] = st.base
			active[joint] = nil
		else
			local angle
			if st.kind == "flip" then
				angle = -2 * math.pi * (1 - (1 - p) ^ 2)
			else
				angle = -math.rad(cfg.leanDeg) * math.sin(math.pi * p)
			end
			joint[st.prop] = CFrame.Angles(angle, 0, 0) * st.base
		end
	end
end)

return AirMotion
