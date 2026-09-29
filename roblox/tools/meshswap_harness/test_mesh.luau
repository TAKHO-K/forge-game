REALMETA = {rock_boar={parts={["Body"]={origin={0.0,-0.1,0.0},center={-0.0,-0.0,0.035}},["Head"]={origin={0.0,-0.05,-1.5},center={0.0,-0.051,-1.95}},["Eyes"]={origin={0.0,0.15,-2.47},center={0.0,0.2,-2.24}},["Tusk_L"]={origin={-0.45,-0.3,-2.45},center={-0.775,0.193,-2.667}},["Tusk_R"]={origin={0.45,-0.3,-2.45},center={0.769,0.165,-2.651}},["Moss"]={origin={0.0,0.75,0.1},center={0.08,0.963,-0.115}},["Leg_FL"]={origin={-0.6,-0.85,-1.0},center={-0.6,-1.165,-1.0}},["Leg_FR"]={origin={0.6,-0.85,-1.0},center={0.6,-1.165,-1.0}},["Leg_BL"]={origin={-0.6,-0.85,1.0},center={-0.6,-1.165,1.0}},["Leg_BR"]={origin={0.6,-0.85,1.0},center={0.6,-1.165,1.0}}}},blue_dragon={parts={["Body"]={origin={0.0,0.9,0.0},center={0.0,1.034,-0.05}},["Leg_FL"]={origin={-1.1,-0.1,-1.5},center={-1.1,-0.807,-1.649}},["Leg_FR"]={origin={1.1,-0.1,-1.5},center={1.1,-0.807,-1.649}},["Leg_BL"]={origin={-1.1,-0.1,1.5},center={-1.1,-0.804,1.314}},["Leg_BR"]={origin={1.1,-0.1,1.5},center={1.1,-0.804,1.314}},["Neck1"]={origin={0.0,1.8,-2.0},center={0.0,3.025,-2.449}},["Head"]={origin={0.0,4.4311,-2.9577},center={-0.007,5.282,-3.186}},["Jaw"]={origin={0.0,4.1311,-3.2577},center={0.0,4.076,-4.083}},["Eyes"]={origin={0.0,4.9311,-4.6577},center={0.0,4.931,-4.558}},["Wing_L"]={origin={-1.5,1.7,-0.4},center={-4.092,3.032,-0.474}},["Wing_R"]={origin={1.5,1.7,-0.4},center={4.092,3.032,-0.474}},["Tail1"]={origin={0.0,1.2,2.3},center={0.0,1.038,3.569}},["Tail2"]={origin={0.0,0.7485,4.8605},center={0.0,0.599,6.032}},["Tail3"]={origin={0.0,0.3318,7.224},center={0.04,0.127,8.439}}}},sand_scorpion={parts={["Body"]={origin={0.0,-0.9,0.0},center={0.0,-0.9,-0.03}},["Head"]={origin={0.0,-0.85,-1.3},center={0.0,-0.869,-1.675}},["Eyes"]={origin={0.0,-0.7,-1.86},center={0.0,-0.66,-1.8}},["Claw_L"]={origin={-0.8,-0.9,-1.6},center={-0.84,-0.817,-1.916}},["Claw_R"]={origin={0.8,-0.9,-1.6},center={0.846,-0.82,-1.916}},["Leg_L"]={origin={-0.85,-1.25,0.1},center={-1.055,-1.167,0.025}},["Leg_R"]={origin={0.85,-1.25,0.1},center={1.055,-1.167,0.025}},["Tail1"]={origin={0.0,-0.6,1.0},center={0.013,-0.11,1.331}},["Tail2"]={origin={0.0,0.383,1.6883},center={0.012,0.861,1.431}},["Tail3"]={origin={0.0,1.3356,1.1383},center={0.0,1.098,0.709}}}},ice_golem={parts={["Body"]={origin={0.0,0.4,0.0},center={0.016,0.601,-0.016}},["Head"]={origin={0.0,1.4,-0.1},center={-0.001,1.8,-0.116}},["Eyes"]={origin={0.0,1.85,-0.56},center={0.0,1.85,-0.7}},["Arm_L"]={origin={-1.6,1.0,0.0},center={-1.591,0.4,-0.005}},["Arm_R"]={origin={1.6,1.0,0.0},center={1.609,0.4,-0.005}},["Fist_L"]={origin={-1.6,-0.4,0.0},center={-1.568,-0.8,-0.011}},["Fist_R"]={origin={1.6,-0.4,0.0},center={1.639,-0.8,-0.014}},["Leg_L"]={origin={-0.6,-0.6,0.0},center={-0.617,-1.05,0.001}},["Leg_R"]={origin={0.6,-0.6,0.0},center={0.583,-1.05,0.001}}}}}
-- A2-N2 3절 하네스: 회전 0으로 구운 메시(A2-N1 FBX)를 메타 center로 정렬 + 관절 다시 걸기가 옛 회전 파트와 같은 움직임을 내는가
local MeshImportCheck = require("MeshImportCheck")
local MeshSwap = require("MeshSwap")

-- 3 × 3 회전(행 우선) + 위치 = 작은 CFrame
local function mul(A, B) -- A · B
	local R = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += A.R[i * 3 + k + 1] * B.R[k * 3 + j + 1]
			end
			R[i * 3 + j + 1] = s
		end
	end
	local p = {}
	for i = 0, 2 do
		p[i + 1] = A.p[i + 1] + A.R[i * 3 + 1] * B.p[1] + A.R[i * 3 + 2] * B.p[2] + A.R[i * 3 + 3] * B.p[3]
	end
	return { R = R, p = p }
end
local function inv(A)
	local R = { A.R[1], A.R[4], A.R[7], A.R[2], A.R[5], A.R[8], A.R[3], A.R[6], A.R[9] }
	local p = {}
	for i = 0, 2 do
		p[i + 1] = -(R[i * 3 + 1] * A.p[1] + R[i * 3 + 2] * A.p[2] + R[i * 3 + 3] * A.p[3])
	end
	return { R = R, p = p }
end
local function point(A, x)
	return mul(A, { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = x }).p
end
local function rotX(deg)
	local c, s = math.cos(math.rad(deg)), math.sin(math.rad(deg))
	return { R = { 1, 0, 0, 0, c, -s, 0, s, c }, p = { 0, 0, 0 } }
end
local function dist(a, b)
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

local fails = 0
local function check(ok, line)
	print((ok and "O " or "X ") .. line)
	if not ok then
		fails += 1
	end
end

for _, case in ipairs({ { rig = "rock_boar", parts = { "Tusk_L", "Tusk_R", "Head" } }, { rig = "blue_dragon", parts = { "Neck1", "Head", "Wing_L", "Tail2" } } }) do
	local exp = MeshImportCheck.expected(case.rig, 1)
	assert(exp, case.rig)
	-- ① 메타 정렬: 메타 center = 휴식 자세 경계 가운데(파트 가운데 + 구운 모양 탓 어긋남) · 가져오기 = 알 수 없는 이동 T
	local T = { 13.2, -4.7, 88.1 }
	local meta, points = { parts = {} }, {}
	local rotated = 0
	for i, name in ipairs(exp.order) do
		local e = exp.parts[name]
		local c = { e.center[1] + 0.03 * i, e.center[2] - 0.02 * i, e.center[3] + 0.01 * i }
		meta.parts[name] = { center = c }
		table.insert(points, { name = name, center = { c[1] - T[1], c[2] - T[2], c[3] - T[3] } })
		if math.abs(e.jointFrame.R[1] - 1) > 1e-6 or math.abs(e.jointFrame.R[5] - 1) > 1e-6 then
			rotated += 1
		end
	end
	local off, res, used = MeshSwap.alignFromMeta(points, meta, 1)
	check(dist(off, T) < 1e-9 and res < 1e-9 and used == #exp.order, ("%s 메타 정렬: 이동 %.3f %.3f %.3f · 어긋남 %.2e · 파트 %d(회전 관절 %d)"):format(case.rig, off[1], off[2], off[3], res, used, rotated))
	-- 한 파트 축이 뒤집혀 가져와지면(Y↔Z) 어긋남이 문턱을 넘어야 한다
	local broken = table.clone(points)
	local b = broken[2]
	broken[2] = { name = b.name, center = { b.center[1], b.center[3], b.center[2] } }
	local _, res2 = MeshSwap.alignFromMeta(broken, meta, 1)
	check(res2 > 0.05, ("%s 깨진 배치 감지: 어긋남 %.3f > 0.05"):format(case.rig, res2))

	-- ② 관절 다시 걸기: 옛 파트(회전 있음)와 새 메시(회전 0 · 경계 가운데)가 같은 관절 회전에서 같은 자리로 가는가
	for _, name in ipairs(case.parts) do
		local e = exp.parts[name]
		assert(e, name)
		local J = e.jointFrame
		-- 옛 파트 월드 = 관절 프레임 · (-pivot) 이동(expected가 쓰는 식 그대로) = partFrame. 여기서는 center와 관절 회전으로 다시 만든다.
		local oldF = { R = J.R, p = e.center }
		local mc = meta.parts[name].center
		local newF = { R = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, p = mc }
		local C1old, C1new = mul(inv(oldF), J), mul(inv(newF), J)
		local worst = 0
		for _, deg in ipairs({ 0, 25, -40, 70 }) do
			local posedOld = mul(mul(J, rotX(deg)), inv(C1old))
			local posedNew = mul(mul(J, rotX(deg)), inv(C1new))
			for _, lp in ipairs({ { 0, 0, 0 }, { 0.3, -0.2, -0.6 }, { -0.5, 0.4, 0.2 } }) do
				local x = point(oldF, lp) -- 옛 파트 위 한 점(월드 휴식)
				local xNewLocal = point(inv(newF), x) -- 구운 메시에서 같은 점
				worst = math.max(worst, dist(point(posedOld, lp), point(posedNew, xNewLocal)))
			end
		end
		local jointStill = dist(point(mul(mul(J, rotX(55)), inv(C1new)), point(inv(newF), J.p)), J.p)
		check(worst < 1e-9 and jointStill < 1e-9, ("%s.%s 관절 회전 4각도: 옛 파트와 차 %.2e · 관절점 고정 %.2e"):format(case.rig, name, worst, jointStill))
	end
end
-- ③ 실제 A2-N1 메타(center · origin): origin = 규격 관절 자리와 같은가 · 정렬은 실제 center로
for rig, m in pairs(REALMETA) do
	local exp = MeshImportCheck.expected(rig, 1)
	local worst, missing = 0, 0
	local pts = {}
	for name, e in pairs(exp.parts) do
		local mp = m.parts[name]
		if mp then
			worst = math.max(worst, dist(mp.origin, e.joint))
			table.insert(pts, { name = name, center = { mp.center[1] + 5, mp.center[2] - 2, mp.center[3] + 1 } })
		else
			missing += 1
		end
	end
	local off, res = MeshSwap.alignFromMeta(pts, m, 1)
	check(worst < 0.01 and missing == 0 and res < 1e-6 and math.abs(off[1] + 5) < 1e-6, ("실제 메타 %s: origin ↔ 규격 관절 최대 %.4f · 빠진 파트 %d · 정렬 어긋남 %.1e"):format(rig, worst, missing, res))
end
print(fails == 0 and "===MESH 하네스 O===" or ("===MESH 하네스 X " .. fails .. "==="))
