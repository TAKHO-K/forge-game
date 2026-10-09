local BossOrigin, BossRules, BossFramework = MODS.BossOrigin, MODS.BossRules, MODS.BossFramework
local Data = MODS.BossOriginData
local walk = MODS.WorldConfig.playerWalkSpeedStuds
for _, rigKey in ipairs({ "section_guardian_v2", "frost_giant_v2", "storm_lord_v2", "abyssal_lord_v2", "crystal_queen_v2", "scorpion_queen_v2" }) do
	local bossId = rigKey:gsub("_v2", "")
	local d = BossRules.buildInstanceData(100, bossId, 1)
	local g = BossFramework.applyV3(BossFramework.applyBodyEdge(d, rigKey, walk), rigKey)
	local ids = {}
	for id in pairs(Data[rigKey]) do table.insert(ids, id) end
	table.sort(ids)
	print(("EDGE\t%s\tedge %.2f\tchaseStop %.2f\tsize %.3f"):format(bossId, g.bodyEdgeStuds or 0, g.chaseStopDistanceStuds or 0, d.sizeScale or 1))
	for _, id in ipairs(ids) do
		local e = Data[rigKey][id]
		local sk = g.skills[id]
		for _, form in ipairs({ "before", "after" }) do
			local hp = form == "after" and 0.4 or 1
			local p = e[form] and BossOrigin.point(rigKey, d.sizeScale, hp, id, Vector3.zero, Vector3.new(0, 0, -100), 0)
			if p then
				local fwd, side = -p.Z, p.X
				local r = sk and (sk.radiusStuds or 0) or 0
				local extra = ""
				if sk then
					if sk.primitive == "ring" then
						extra = ("maxR %s speed %s"):format(tostring(sk.maxRadiusStuds), tostring(sk.waveSpeedStuds))
					elseif sk.primitive == "line" then
						extra = ("len %s halfW %s"):format(tostring(sk.lengthStuds), tostring(sk.halfWidthStuds))
					elseif sk.primitive == "sector" then
						extra = ("angle %s"):format(tostring(sk.angleDeg))
					elseif sk.primitive == "projectile" or sk.primitive == "boomerang" then
						extra = ("speed %s height %s"):format(tostring(sk.speedStuds), tostring(sk.heightMode))
					end
				end
				print(("REACH\t%s\t%s\t%s\t%s\tfwd %.1f\tside %.1f\tR %.1f\t%s"):format(bossId, id, form, sk and sk.primitive or "?", fwd, side, r, extra))
			end
		end
	end
end
