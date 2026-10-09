-- BOSS-NIGHT-2 3 발생 지점 표 만들기(오프라인 FK - 서버는 애니메이션을 재생하지 않는다 = ②안):
--   스킬 · 폼마다 접촉 프레임(동작 contactTime · 지진파 = 폼별 찍기 착지)에 때리는 부위(동작 세트 flash)의 자리를 보스 루트 기준 리그 단위로 잰다.
--   ground = 그 부위 가운데의 수평 자리(서버가 바닥으로 내림 · 여러 부위 = 평균 - 두 주먹 사이) · launch = 부위 가운데(높이 = 지면 위). 출력 줄 = ORG <리그> <스킬> <폼> <종류> x y z
--   실행: PRELUDE=motion_prelude.luau ECON_RES=origin.txt python build_run.py boss_origin_dump.luau → tools/harness/boss_origin_gen.py가 data/BossOriginData.lua를 쓴다.
local BossMotion, BossRig, BossRigSpec, BossClipSet = MODS.BossMotion, MODS.BossRig, MODS.BossRigSpec, MODS.BossClipSet
local BossFramework, BossRules = MODS.BossFramework, MODS.BossRules
local walk = MODS.WorldConfig.playerWalkSpeedStuds
-- [보스] = { { 스킬, 종류, 부위(없으면 세트 flash) } } · 예외(표에 없음 = 몸 중심): 수호자 earthSplit(부채가 대상 좌/우 무작위 · 보이는 손이 반대쪽 - Studio 차 16 stud) · 전갈 stingJab(꼬리 끝이 몸 위 · 뒤)
local LIST = {
	section_guardian = { { "shockwave", "ground", { "Hand_L", "Hand_R" } }, { "heavy", "ground" }, { "cross", "ground" }, { "banana", "launch", { "Hand_R" } }, { "orbs", "launch" } },
	frost_giant = { { "slam", "ground" }, { "stomp", "ground" }, { "spike", "ground" }, { "snowball", "launch" }, { "tuskShot", "launch" } },
	storm_lord = { { "thunderRing", "ground" }, { "discharge", "ground" }, { "boltSpear", "launch" }, { "stormOrbs", "launch", { "Gauntlet_R", "Gauntlet_L" } }, { "swordWave", "ground", { "StaffOrb" } }, { "tornado", "ground", { "StaffOrb" } } },
	abyssal_lord = { { "tide", "ground", { "TridentHead" } }, { "bubbles", "launch" }, { "tridentThrow", "launch", { "TridentHead" } } },
	crystal_queen = { { "magicMissiles", "launch", { "ScepterGem" } }, { "shards", "launch" } },
	scorpion_queen = { { "claw", "ground" } }, -- stingJab = 예외(접촉 때 꼬리 끝이 몸 위 · 뒤 - 몸 중심 유지)
}
for _, bossId in ipairs({ "section_guardian", "frost_giant", "storm_lord", "abyssal_lord", "crystal_queen", "scorpion_queen" }) do
	local rigId = bossId .. "_v2"
	local rig = BossRigSpec.rigs[rigId]
	local d = BossRules.buildInstanceData(15, bossId, 1)
	local g = BossFramework.applyV3(BossFramework.applyBodyEdge(d, rigId, walk), rigId)
	local rest = BossMotion.prepare(rig)
	local sizes = {}
	for _, j in ipairs(rig.joints) do
		sizes[j.part] = j.size
	end
	local set = BossClipSet.get(rigId)
	for _, form in ipairs({ "before", "after" }) do
		local F = set.forms[form]
		if F then
			for _, e in ipairs(LIST[bossId]) do
				local sid, kind = e[1], e[2]
				local sk = g.skills[sid]
				if sk then
					local ctx = BossMotion.context(rigId, rig, g.skills, g.moveSpeedStuds)
					local parts = e[3] or (F.flash and F.flash[sid]) or set.flash[sid] or { "Hand_R" }
					local st, t
					if sk.primitive == "ring" then
						local hs = 1.5
						st = { form = form, inCombat = true, speed = 0, gait = 0, act = sid, actAt = 0, actHit = sk.telegraphSeconds, hopAt = 0, hopSeconds = hs }
						t = hs + 0.03
					else
						local clip = BossMotion.clip(rigId, rig, BossMotion.clipNameForSkill(rigId, rig, sid, sk, form) or "")
						st = { form = form, inCombat = true, speed = 0, gait = 0, act = sid, actAt = 0, actHit = sk.telegraphSeconds }
						t = clip and BossMotion.contactTime(clip, sk.telegraphSeconds) + 0.01 or sk.telegraphSeconds
					end
					local pose = BossMotion.evaluate(ctx, st, t)
					local fr = BossRig.solve(rig, CFrame.identity, 1, BossMotion.toTransforms(rest, 1, pose))
					local sum, n, low, lowXZ = Vector3.zero, 0, math.huge, Vector3.zero
					for _, part in ipairs(parts) do
						local cf, s = fr[part], sizes[part]
						if cf and s then
							sum += cf.Position
							n += 1
							local plow, pat = math.huge, cf.Position
							for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do for _, sz in ipairs({ -1, 1 }) do
								local p = (cf * CFrame.new(sx * s.X / 2, sy * s.Y / 2, sz * s.Z / 2)).Position
								if p.Y < plow then plow, pat = p.Y, p end
							end end end
							low = math.min(low, plow)
							lowXZ += Vector3.new(pat.X, 0, pat.Z)
						end
					end
					if n > 0 then
						local p = kind == "ground" and Vector3.new(sum.X / n, low + 1.5, sum.Z / n) or Vector3.new(sum.X / n, sum.Y / n + 1.5, sum.Z / n) -- 수평 = 부위 가운데(Studio 보이는 부위와 비교 · 여러 부위 = 평균)
						print(("ORG\t%s\t%s\t%s\t%s\t%.3f\t%.3f\t%.3f\t%s\t%.2f"):format(rigId, sid, form, kind, p.X, p.Y, p.Z, table.concat(parts, ","), t))
					end
				end
			end
		end
	end
end
