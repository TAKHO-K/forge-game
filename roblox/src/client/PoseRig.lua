-- W1 캐릭터 관절 포즈 · 직접 FK · 두 관절 IK(그리기만 - 판정 없음 · 루트(HumanoidRootPart)는 절대 안 움직인다 = 이동 판정 무관).
--   관절 = AnimationConstraint(아바타 관절 업그레이드 - 이 place) · Motor6D(옛 리그) 둘 다 Transform. 애니메이터가 매 프레임 쓴 Transform 위에
--   가중치로 섞어 덮어쓴다(RenderStepped - 애니메이터 다음). 가중치 0 관절 = 애니메이터 그대로(걷기 다리 · 수납 중 팔).
--   FK = 부착점 프레임(c0 · c1)으로 직접 계산(파트 CFrame은 한 프레임 늦다) → 손 · 무기 자리가 이번 프레임 포즈와 맞는다.
--   IK = 어깨 · 팔꿈치(팔꿈치 = X축 경첩) · 팔꿈치 방향(pole) - 양손 무기 보조 손 · 활 시위 당기는 오른손.
local PoseRig = {}

local NAMES = { "Root", "Waist", "Neck", "RightShoulder", "RightElbow", "RightWrist", "LeftShoulder", "LeftElbow", "LeftWrist", "RightHip", "RightKnee", "LeftHip", "LeftKnee", "RightAnkle", "LeftAnkle" }
PoseRig.NAMES = NAMES
local ARM = {
	Right = { shoulder = "RightShoulder", elbow = "RightElbow", wrist = "RightWrist", hand = "RightHand" },
	Left = { shoulder = "LeftShoulder", elbow = "LeftElbow", wrist = "LeftWrist", hand = "LeftHand" },
}

local cache = setmetatable({}, { __mode = "k" })

local function scan(character)
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("AnimationConstraint") and d.Attachment0 and d.Attachment1 then
			joints[d.Name] = { inst = d, kind = "constraint", part0 = d.Attachment0.Parent, part1 = d.Attachment1.Parent, a0 = d.Attachment0, a1 = d.Attachment1 }
		elseif d:IsA("Motor6D") and d.Part0 and d.Part1 then
			joints[d.Name] = { inst = d, kind = "motor", part0 = d.Part0, part1 = d.Part1 }
		end
	end
	return joints
end

-- 관절 표(캐릭터마다 캐시 - 관절 하나라도 사라지면(외형 늦게 로드 · 팔 교체) 다시 찾는다 · 못 찾으면 0.5초 뒤 재시도).
local CHECK = { "Waist", "RightShoulder", "LeftShoulder", "RightWrist", "LeftWrist" }
local retryAt = setmetatable({}, { __mode = "k" })
function PoseRig.get(character)
	local rig = cache[character]
	if rig then
		local ok = true
		for _, name in ipairs(CHECK) do
			local j = rig.joints[name]
			if j and not j.inst.Parent then
				ok = false
				break
			end
		end
		if ok then
			return rig
		end
	end
	if (retryAt[character] or 0) > os.clock() then
		return nil
	end
	local joints = scan(character)
	if not joints.Root or not joints.Waist then
		retryAt[character] = os.clock() + 0.5
		return nil
	end
	rig = { joints = joints, root = character:FindFirstChild("HumanoidRootPart"), written = {} } -- 캐릭터를 값에 담지 않는다(약한 키 표 - 리뷰 4)
	cache[character] = rig
	return rig
end

local function c0Of(j)
	return j.kind == "constraint" and j.a0.CFrame or j.inst.C0
end
local function c1Of(j)
	return j.kind == "constraint" and j.a1.CFrame or j.inst.C1
end

-- 가중치 포즈 적용: pose[name] = CFrame(회전) · weight[name] = 0 ~ 1. 반환 = 이번 프레임 최종 Transform 표(FK용).
--   섞는 기준 = 애니메이터가 이번 프레임에 쓴 값. 애니메이터가 안 쓴 관절(지난 프레임 우리 값이 그대로 = Root · 발목 · 멈춘 트랙)은 항등을 기준으로(리뷰 3 - 누적 · 굳음 방지).
function PoseRig.apply(rig, pose, weight)
	local out = {}
	local written = rig.written
	for name, j in pairs(rig.joints) do
		local anim = j.inst.Transform
		if written[name] and anim == written[name] then
			anim = CFrame.identity
		end
		local w = weight[name] or 0
		local target = pose[name]
		if target and w > 0 then
			local t = w >= 1 and target or anim:Lerp(target, w)
			j.inst.Transform = t
			out[name] = t
			written[name] = t
		else
			if written[name] then -- 가중치가 0이 됐다 - 애니메이터가 안 쓰는 관절이면 항등으로 돌려준다
				j.inst.Transform = anim
				written[name] = nil
			end
			out[name] = anim
		end
	end
	return out
end

-- FK: 파트 이름 → 월드 CFrame(루트 파트에서 관절 사슬로). T = apply의 반환(없으면 지금 Transform).
function PoseRig.fk(rig, T)
	local root = rig.root
	if not root then
		return nil
	end
	local cf = { [root.Name] = root.CFrame }
	local pending = {}
	for name, j in pairs(rig.joints) do
		pending[name] = j
	end
	for _ = 1, 8 do -- 사슬 깊이(루트 → 몸통 → 어깨 → 팔꿈치 → 손목)
		local progressed = false
		for name, j in pairs(pending) do
			local p0 = cf[j.part0.Name]
			if p0 then
				cf[j.part1.Name] = p0 * c0Of(j) * ((T and T[name]) or j.inst.Transform) * c1Of(j):Inverse()
				pending[name] = nil
				progressed = true
			end
		end
		if not progressed then
			break
		end
	end
	return cf
end

-- 두 관절 IK: side("Right" | "Left")의 손바닥 점(palm - 손 로컬)이 target(월드)에 오도록 어깨 · 팔꿈치 Transform을 푼다.
--   pole = 팔꿈치가 향할 방향(몸통 로컬 - 예: 왼팔 보조 손 = (−1, −1, 0.2)). wristT = 손목 Transform(없으면 0). 결과를 관절에 쓰고 T 표도 고친다.
--   반환: 손바닥 점과 target 사이 남은 거리(팔이 닿지 않으면 > 0).
function PoseRig.solveArm(rig, T, cf, side, target, pole, palm, wristT, weight)
	local names = ARM[side]
	local sh, el, wr = rig.joints[names.shoulder], rig.joints[names.elbow], rig.joints[names.wrist]
	if not sh or not el or not wr then
		return math.huge
	end
	local torsoCF = cf[sh.part0.Name]
	if not torsoCF then
		return math.huge
	end
	wristT = wristT or CFrame.identity
	local S = torsoCF * c0Of(sh) -- 어깨 관절 프레임(월드)
	local E0 = c1Of(sh):Inverse() * c0Of(el) -- 위팔 프레임에서 팔꿈치 관절
	local Wv = (c1Of(el):Inverse() * c0Of(wr) * wristT * c1Of(wr):Inverse() * CFrame.new(palm)).Position -- 팔꿈치 관절에서 손바닥 점
	local function reach(beta)
		return (E0 * CFrame.Angles(beta, 0, 0) * CFrame.new(Wv)).Position
	end
	local t = S:PointToObjectSpace(target)
	local D = t.Magnitude
	-- 팔꿈치 각: 0(펴짐) ~ 150°에서 |reach| = D(단조 감소 - 이분법)
	local lo, hi = 0, math.rad(150)
	local dMax, dMin = reach(lo).Magnitude, reach(hi).Magnitude
	local beta
	if D >= dMax then
		beta = lo
	elseif D <= dMin then
		beta = hi
	else
		for _ = 1, 22 do
			local mid = (lo + hi) / 2
			if reach(mid).Magnitude > D then
				lo = mid
			else
				hi = mid
			end
		end
		beta = (lo + hi) / 2
	end
	local p = reach(beta)
	-- 어깨: p → t 방향으로 돌리고, t 축으로 비틀어 팔꿈치를 pole 쪽으로
	local R1 = CFrame.identity
	if p.Magnitude > 1e-6 and D > 1e-6 then
		local a, b = p.Unit, t.Unit
		local axis = a:Cross(b)
		local ang = math.acos(math.clamp(a:Dot(b), -1, 1))
		if axis.Magnitude > 1e-6 then
			R1 = CFrame.fromAxisAngle(axis.Unit, ang)
		elseif ang > 3 then
			R1 = CFrame.fromAxisAngle(Vector3.xAxis, math.pi)
		end
	end
	local R = R1
	if pole and D > 1e-6 then
		local tu = t.Unit
		local e = R1 * E0.Position
		local ea = e - tu * e:Dot(tu)
		local pb = pole - tu * pole:Dot(tu)
		if ea.Magnitude > 1e-4 and pb.Magnitude > 1e-4 then
			local ang = math.atan2(ea.Unit:Cross(pb.Unit):Dot(tu), ea.Unit:Dot(pb.Unit))
			R = CFrame.fromAxisAngle(tu, ang) * R1
		end
	end
	local shT, elT = R, CFrame.Angles(beta, 0, 0)
	if weight and weight < 1 then -- 리뷰 5: 전환 중에는 포즈 값과 섞는다(보조 팔이 튀지 않게)
		shT = (T[names.shoulder] or CFrame.identity):Lerp(shT, weight)
		elT = (T[names.elbow] or CFrame.identity):Lerp(elT, weight)
		wristT = (T[names.wrist] or CFrame.identity):Lerp(wristT, weight)
	end
	sh.inst.Transform, el.inst.Transform, wr.inst.Transform = shT, elT, wristT
	rig.written[names.shoulder], rig.written[names.elbow], rig.written[names.wrist] = shT, elT, wristT
	T[names.shoulder], T[names.elbow], T[names.wrist] = shT, elT, wristT
	local upper = S * shT * c1Of(sh):Inverse()
	cf[sh.part1.Name] = upper
	local lower = upper * c0Of(el) * elT * c1Of(el):Inverse()
	cf[el.part1.Name] = lower
	local hand = lower * c0Of(wr) * wristT * c1Of(wr):Inverse()
	cf[wr.part1.Name] = hand
	return ((hand * CFrame.new(palm)).Position - target).Magnitude
end

-- 우리가 쓴 관절을 전부 항등으로 돌려준다(그리기 범위 밖으로 나갈 때 - 누운 자세 Root 이동 등이 남지 않게: 리뷰 3). 애니메이터가 쓰는 관절은 다음 프레임에 다시 덮는다.
function PoseRig.release(rig)
	for name in pairs(rig.written) do
		local j = rig.joints[name]
		if j and j.inst.Parent then
			j.inst.Transform = CFrame.identity
		end
	end
	rig.written = {}
end

-- 오일러(도) → 회전 · 선택 이동 v[4 ~ 6](stud - 루트 관절로 몸을 내린다: 누움 · 무릎).
function PoseRig.rot(v)
	local r = CFrame.Angles(math.rad(v[1]), math.rad(v[2]), math.rad(v[3]))
	if v[4] or v[5] or v[6] then
		return CFrame.new(v[4] or 0, v[5] or 0, v[6] or 0) * r
	end
	return r
end

return PoseRig
