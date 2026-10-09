-- BOSS-NIGHT-2 C ★ 보스 발밑 안전지대: 발생 지점 표의 바닥 패턴마다 "보스 몸에 붙은 사람"(몸 가장자리 + 0.5)이 맞는지 - 발생 지점 = 몸 중심(전) ↔ 부위(후)
-- 붙은 자리 = 보스 둘레 원(36방향 · 0° = 대상 쪽) · 앞 붙음 = 0°(보스와 대상 사이). 판정 모형 = 서버 BossPatterns(원 · 부채 · 빔 · 파동)과 같은 도형(벽 · 지형 무시).
local BossOrigin, BossRules, BossFramework, BossSkillMath = MODS.BossOrigin, MODS.BossRules, MODS.BossFramework, MODS.BossSkillMath
local Spec = MODS.BossRigSpec
local Data = MODS.BossOriginData
local walk = MODS.WorldConfig.playerWalkSpeedStuds
local WAVE = BossSkillMath.WAVE_MAX_RADIUS_STUDS
local function covered(sk, O, p, aimDeg)
	local v = Vector3.new(p.X - O.X, 0, p.Z - O.Z)
	local dist = v.Magnitude
	local prim = sk.primitive
	if prim == "circleBoss" then
		local best = false
		for _, pulse in ipairs(BossSkillMath.pulsesOf(sk)) do
			if dist <= pulse.radiusStuds and dist >= (pulse.innerRadiusStuds or 0) then best = true end
		end
		return best
	elseif prim == "ring" then
		return dist <= WAVE, "jump"
	elseif prim == "sector" then
		for _, volley in ipairs(BossSkillMath.volleysOf(sk)) do
			if dist <= (volley.radiusStuds or 140) and dist >= (sk.innerRadiusStuds or 0) then
				if volley.angleDeg >= 360 then return true end
				local a = math.deg(math.atan2(v.Z, v.X))
				local centers = sk.facing == "randomSide" and { aimDeg + 90, aimDeg - 90 } or { aimDeg }
				for _, cdeg in ipairs(centers) do
					local diff = math.abs((a - cdeg + 540) % 360 - 180)
					if diff <= volley.angleDeg / 2 or dist < 1e-3 then return true end
				end
			end
		end
		return false
	elseif prim == "line" then
		local spread = sk.centered and sk.stepDeg * ((sk.directions or 1) - 1) / 2 or 0
		local hw = 0
		for _, volley in ipairs(BossSkillMath.volleysOf(sk)) do hw = math.max(hw, volley.halfWidthStuds or sk.halfWidthStuds) end
		for k = 0, (sk.directions or 1) - 1 do
			local a = math.rad(aimDeg - spread + (sk.stepDeg or 0) * k)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local t = math.clamp(v:Dot(dir), 0, 200)
			local perp = (v - dir * t).Magnitude
			if perp <= hw then return true end
		end
		return false
	end
	return nil
end
for _, rigKey in ipairs({ "section_guardian_v2", "frost_giant_v2", "storm_lord_v2", "abyssal_lord_v2", "crystal_queen_v2", "scorpion_queen_v2" }) do
	local bossId = rigKey:gsub("_v2", "")
	local d = BossRules.buildInstanceData(100, bossId, 1)
	local g = BossFramework.applyV3(BossFramework.applyBodyEdge(d, rigKey, walk), rigKey)
	local rig = Spec.rigs[rigKey]
	local hug = (rig.edgeHalfWidth or rig.baseEdgeHalfWidth or 2) * (d.sizeScale or 1) * (rig.scale or 1) + 0.5
	local ids = {}
	for id in pairs(Data[rigKey]) do table.insert(ids, id) end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local sk = g.skills[id]
		if sk and Data[rigKey][id].kind == "ground" then
			for _, form in ipairs({ "before", "after" }) do
				local e = Data[rigKey][id]
				if e[form] and (form == "before" or e.after ~= e.before) then
					local aimDeg = -90 -- 대상 = (0, 0, −100) → atan2(−100, 0)
					local P = BossOrigin.point(rigKey, d.sizeScale, form == "after" and 0.4 or 1, id, Vector3.zero, Vector3.new(0, 0, -100), 0)
					local function scan(O)
						local hit, front, tag = 0, false, nil
						for i = 0, 35 do
							local th = math.rad(aimDeg + i * 10)
							local c, t = covered(sk, O, Vector3.new(math.cos(th) * hug, 0, math.sin(th) * hug), aimDeg)
							tag = t or tag
							if c then hit += 1; if i == 0 then front = true end end
						end
						return hit, front, tag
					end
					local h0, f0, tag = scan(Vector3.zero)
					local h1, f1 = scan(P)
					print(("SAFE\t%s\t%s\t%s\t%s\thug %.1f\tfwd %.1f\t전 %d/36 앞 %s\t후 %d/36 앞 %s%s"):format(bossId, id, form, sk.primitive, hug, -P.Z, h0, f0 and "맞음" or "안전", h1, f1 and "맞음" or "안전", tag == "jump" and "\t(점프 회피)" or ""))
				end
			end
		end
	end
end
