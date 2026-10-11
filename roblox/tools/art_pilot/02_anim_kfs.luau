-- ART-PILOT-1 Studio 2단계(Edit · execute_luau): *.anim.json(art_pilot_anim.py 출력) → KeyframeSequence(뼈 Pose = Bone.Transform).
--   JSON 받기 = 로컬 `python -m http.server 8765 --bind 127.0.0.1`(roblox/art/pilot/art_pilot_1에서) + HttpService:GetAsync - 코드 붙여 넣기보다 싸다.
--   축: Blender 월드 → Roblox = x → −x · y → z · z → y(뼈 머리 위치 맞춤 오차 0.0013 / 0.0005 stud) · 배율은 쉬는 자세 뼈 위치로 최소제곱.
--   뿌리 뼈 아래 Pose는 회전만 남긴다(Meshy 애니의 1.058배 늘어남이 자식 뼈 이동으로 새는 것 막기 - 10-11 사용자 확인: 흐느적거림은 그대로).
--   01_load.luau로 넣고 크기를 맞춘 뒤 실행. 결과 KeyframeSequence = _ArtPilot[모델][애니 이름] · 재생 = KeyframeSequenceProvider:RegisterKeyframeSequence.
local H = game:GetService("HttpService")
local root = workspace._ArtPilot
local jobs = { { "boar_b1", "boar_walk" }, { "smith_a2", "smith_Walking" }, { "smith_a2", "smith_Heavy_Hammer_Swing" } }
local M = CFrame.fromMatrix(Vector3.zero, -Vector3.xAxis, Vector3.zAxis, Vector3.yAxis)
local Mi = M:Inverse()
local out = {}
for _, job in ipairs(jobs) do
	local m = root[job[1]]:FindFirstChildWhichIsA("Model")
	local d = H:JSONDecode(H:GetAsync("http://127.0.0.1:8765/" .. job[2] .. ".anim.json"))
	local bones = {}
	for _, b in ipairs(m:GetDescendants()) do
		if b:IsA("Bone") then b.Transform = CFrame.identity; bones[b.Name] = b end
	end
	local B, Rw = {}, {}
	for _, bi in ipairs(d.bones) do
		local b = bones[bi.name]
		if b then table.insert(B, Vector3.new(table.unpack(bi.restHead))); table.insert(Rw, b.WorldPosition) end
	end
	local cb, cr = Vector3.zero, Vector3.zero
	for i = 1, #B do cb += B[i]; cr += Rw[i] end
	cb /= #B; cr /= #B
	local num, den = 0, 0
	for i = 1, #B do local v = B[i] - cb; num += (M * v):Dot(Rw[i] - cr); den += v:Dot(v) end
	local s = num / den
	local function mapP(v) return cr + (M * (v - cb)) * s end
	local rest = {}
	for n, b in pairs(bones) do rest[n] = b.WorldCFrame end
	local idx = {}
	for i, bi in ipairs(d.bones) do idx[bi.name] = i end
	local kfs = Instance.new("KeyframeSequence"); kfs.Name = job[2]; kfs.Loop = true
	local rp
	for _, b in pairs(bones) do local p = b.Parent; while p:IsA("Bone") do p = p.Parent end; rp = p; break end
	for f, fr in ipairs(d.delta) do
		local anim, tr = {}, {}
		local function world(b)
			if anim[b] then return anim[b] end
			local pw = b.Parent:IsA("Bone") and world(b.Parent) or b.Parent.CFrame
			local i = idx[b.Name]
			local tgt
			if i then
				local q = fr[i]
				local c0, c1, c2 = Vector3.new(q[1], q[5], q[9]), Vector3.new(q[2], q[6], q[10]), Vector3.new(q[3], q[7], q[11])
				local hb = Vector3.new(table.unpack(d.bones[i].restHead))
				local pos = mapP(c0 * hb.X + c1 * hb.Y + c2 * hb.Z + Vector3.new(q[4], q[8], q[12]))
				local Rd = CFrame.fromMatrix(Vector3.zero, c0.Unit, c1.Unit, c2.Unit):Orthonormalize()
				tgt = CFrame.new(pos) * (M * Rd * Mi) * rest[b.Name].Rotation
			else
				tgt = pw * b.CFrame
			end
			tr[b] = (pw * b.CFrame):Inverse() * tgt
			if b.Parent:IsA("Bone") then tr[b] = tr[b] - tr[b].Position end
			anim[b] = tgt
			return tgt
		end
		for _, b in pairs(bones) do world(b) end
		local kf = Instance.new("Keyframe"); kf.Time = (f - 1) / d.fps
		local pr = Instance.new("Pose"); pr.Name = rp.Name; pr.Weight = 0; pr.Parent = kf
		local poses = {}
		local function pose(b)
			if poses[b] then return poses[b] end
			local par = b.Parent:IsA("Bone") and pose(b.Parent) or pr
			local p = Instance.new("Pose"); p.Name = b.Name; p.CFrame = tr[b]; p.Parent = par
			poses[b] = p
			return p
		end
		for _, b in pairs(bones) do pose(b) end
		kf.Parent = kfs
	end
	for _, b in pairs(bones) do b.Transform = CFrame.identity end
	local old = root[job[1]]:FindFirstChild(job[2]); if old then old:Destroy() end
	kfs.Parent = root[job[1]]
	table.insert(out, ("%s/%s s=%.3f kf=%d"):format(job[1], job[2], s, #kfs:GetChildren()))
	task.wait()
end
return table.concat(out, "\n")
