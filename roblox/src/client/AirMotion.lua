-- 공중 점프 · 대시 모션(M1-0 - 그리기만, 판정 없음). 캐릭터 루트 관절(Part0 = HumanoidRootPart인 Motor6D)의 C0 앞에 회전을 곱한다 - Animator는 Transform만 덮어써서 C0는 남는다.
-- 회전축 = 루트의 오른쪽 축(R15 · R6 공통) · 앞으로 도는 방향. 입력 즉시 시작한다(준비 동작 없음). 자기 캐릭터는 입력한 클라가, 남의 캐릭터는 서버 중계(AirMoveFx)를 받은 클라가 부른다.
--   flip = 앞으로 한 바퀴(seconds 동안 · 끝으로 갈수록 느려짐) / lean = 앞으로 leanDeg까지 기울었다가 돌아옴(대시 시간 동안).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MovementConfig = require(ReplicatedStorage.Shared.data.MovementConfig)

local AirMotion = {}

local cfg = MovementConfig.airMotion
local active = {} -- [Motor6D] = { base = C0, kind, startedAt, seconds }

local function rootJoint(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 == root then
			return d
		end
	end
	return nil
end

function AirMotion.play(character, kind, seconds)
	local joint = rootJoint(character)
	if not joint or not seconds or seconds <= 0 then
		return
	end
	local running = active[joint]
	active[joint] = { base = running and running.base or joint.C0, kind = kind, startedAt = os.clock(), seconds = seconds }
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for joint, st in pairs(active) do
		local p = (now - st.startedAt) / st.seconds
		if p >= 1 or not joint.Parent then
			joint.C0 = st.base
			active[joint] = nil
		else
			local angle
			if st.kind == "flip" then
				angle = -2 * math.pi * (1 - (1 - p) ^ 2)
			else
				angle = -math.rad(cfg.leanDeg) * math.sin(math.pi * p)
			end
			joint.C0 = CFrame.Angles(angle, 0, 0) * st.base
		end
	end
end)

return AirMotion
