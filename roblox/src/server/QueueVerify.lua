-- QUEUE-10h 자동 검증(가) - 순수 값(docs/phase/QUEUE-10h-report.md). 항목마다 section 하나씩 붙인다.
--   Q0: 결정 1(드랍 개수 = killUnits × 티어 보정) · 결정 2(잡몹 태초 2/3/3 · 보스 첫 클리어 0.1%) · Q0-6 알림 범위(태초 = 같은 서버 / 초월 = 전 서버).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DropTableData = require(ReplicatedStorage.Shared.data.DropTableData)
local DropNoticeData = require(ReplicatedStorage.Shared.data.DropNoticeData)
local MonsterData = require(ReplicatedStorage.Shared.data.MonsterData)

local V = {}

function V.runPure()
	print("===Q 검증 시작(가)===")
	local pass, total = 0, 0
	local function check(label, ok)
		total += 1
		if ok then
			pass += 1
		end
		print(("[Q][가] %s %s"):format(label, ok and "O" or "X"))
	end
	local function section(name, fn)
		local ok, err = pcall(fn)
		if not ok then
			check(("%s 실행 중 에러: %s"):format(name, tostring(err)), false)
		end
	end

	section("Q0 알림 범위", function()
		-- 출처는 알림 범위를 바꾸지 않는다(범위 = 등급만의 함수) - 파티 여부 두 경우 모두 본다
		for _, inParty in ipairs({ false, true }) do
			check(("태초 = 같은 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("primordial", inParty) == "server")
			check(("초월 = 전 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("transcendent", inParty) == "global")
			check(("고대 = 같은 서버(파티 %s)"):format(tostring(inParty)), DropNoticeData.announceScope("ancient", inParty) == "server")
		end
		local globals = {}
		for grade in pairs(DropNoticeData.globalGrades) do
			table.insert(globals, grade)
		end
		check(("전 서버 등급 = 초월만(%s)"):format(table.concat(globals, ",")), #globals == 1 and globals[1] == "transcendent")
	end)

	section("Q0 결정 2 드랍 가중치", function()
		local expect = { 2, 3, 3 }
		for band, w in ipairs(DropTableData.fieldGradeWeights) do
			check(("잡몹 구간 %d 태초 가중치 %d = %d · 일반 %d"):format(band, w.primordial, expect[band], w.normal), w.primordial == expect[band] and w.normal == 6100000)
		end
		local first, sum = DropTableData.bossGrades.firstClear, 0
		for _, p in pairs(first) do
			sum += p
		end
		check(("보스 첫 클리어 태초 %.4f%% · 합 %.12f"):format(first.primordial * 100, sum), math.abs(first.primordial - 0.001) < 1e-12 and math.abs(sum - 1) < 1e-9)
	end)

	section("Q0 결정 1 드랍 개수", function()
		check(("개수 식 = %s"):format(DropTableData.dropCountBasis), DropTableData.dropCountBasis == "killUnits")
		for tierIndex, key in ipairs(MonsterData.tierOrder) do
			local d = MonsterData[key]
			local want = d.killUnits * DropTableData.fieldDropCountAdjust[tierIndex]
			check(("T%d 개수 배율 %.4f = killUnits %.4f × 보정"):format(tierIndex, d.dropCountMultiplier, d.killUnits), math.abs(d.dropCountMultiplier - want) < 1e-9)
		end
	end)

	section("Q1 푸른 드래곤", function()
		local MobAttackShape = require(ReplicatedStorage.Shared.MobAttackShape)
		local SpeciesData = require(ReplicatedStorage.Shared.data.MonsterSpeciesData)
		local RigSpec = require(ReplicatedStorage.Shared.data.MonsterRigSpec)
		local WorldMapData = require(ReplicatedStorage.Shared.data.WorldMapData)
		local def = SpeciesData.species.blue_dragon
		local rig = RigSpec.rigs.blue_dragon
		check(("종 blue_dragon T%d · 무리 %d ~ %d · 링크 %s · 선공"):format(def.tier, def.groupSize[1], def.groupSize[2], tostring(def.linkAggro)),
			def.tier == 6 and def.groupSize[1] == 1 and def.groupSize[2] == 2 and def.linkAggro == false and def.aggro == "aggressive")
		check(("리그 %d파트(≤ 14) · 몸체 = MonsterData.species 연결"):format(#rig.joints), #rig.joints <= 14 and MonsterData.species.blue_dragon.rig == rig)
		local joints = {}
		for _, j in ipairs(rig.joints) do
			joints[j.name] = true
		end
		local missing = {}
		for _, attack in ipairs(def.attacks) do
			for jointName in pairs(attack.windup.poses) do
				if not joints[jointName] then
					table.insert(missing, attack.id .. "." .. jointName)
				end
			end
		end
		for jointName in pairs(def.alertPose.poses) do
			if not joints[jointName] then
				table.insert(missing, "alert." .. jointName)
			end
		end
		check(("전조 · 포효 포즈 관절 이름 = 리그 관절(없는 것 %d: %s)"):format(#missing, table.concat(missing, ",")), #missing == 0)
		local t6 = WorldMapData.zones[6]
		local pool = {}
		for _, m in ipairs(t6.hunt.monsters) do
			pool[m.species] = true
		end
		check("T6 스폰 풀 = 얼음 골렘 + 푸른 드래곤(눈토끼 retired · 데이터 유지)", pool.blue_dragon and pool.ice_golem and not pool.snow_rabbit and SpeciesData.species.snow_rabbit.retiredBy == "blue_dragon")
		local spacing = WorldMapData.spawnSites.pointSpacing
		check(("스폰 간격 %d ≥ 감지 %d × 2 + 10"):format(spacing, def.detectRadius), spacing >= def.detectRadius * 2 + 10)
		-- 모양 판정(몹 원점 · 앞 = −Z)
		local o, f = Vector3.new(0, 0, 0), Vector3.new(0, 0, -1)
		local by = {}
		for _, a in ipairs(def.attacks) do
			by[a.id] = a
		end
		local breath, tail, gust = by.frostBreath, by.tailSweep, by.wingGust
		check("서리 숨결: 앞 10 맞음 · 옆 45° 안 맞음 · 뒤 안 맞음", MobAttackShape.contains(breath, o, f, Vector3.new(0, 0, -10))
			and not MobAttackShape.contains(breath, o, f, Vector3.new(7.07, 0, -7.07)) and not MobAttackShape.contains(breath, o, f, Vector3.new(0, 0, 5)))
		check("꼬리 휩쓸기: 뒤 8 · 옆 90° 맞음 · 앞 안 맞음", MobAttackShape.contains(tail, o, f, Vector3.new(0, 0, 8))
			and MobAttackShape.contains(tail, o, f, Vector3.new(8, 0, 0)) and not MobAttackShape.contains(tail, o, f, Vector3.new(0, 0, -5)))
		check("날개 돌풍: 원 안 맞음 · 밖 안 맞음 · 높이 차 9 안 맞음 · 넉백 조각만", MobAttackShape.contains(gust, o, f, Vector3.new(6, 0, 6))
			and not MobAttackShape.contains(gust, o, f, Vector3.new(0, 0, 11)) and not MobAttackShape.contains(gust, o, f, Vector3.new(0, 9, 0)) and gust.launch ~= nil)
		local a1 = MobAttackShape.choose(def.attacks, true, 0)
		local b1, c1 = MobAttackShape.choose(def.attacks, false, 0)
		local b2 = MobAttackShape.choose(def.attacks, false, c1)
		check(("공격 고르기: 등 뒤 = %s · 앞 = %s → %s"):format(a1.id, b1.id, b2.id), a1.id == "tailSweep" and b1.id == "frostBreath" and b2.id == "wingGust")
		-- 초당 피해 ≈ 티어 평타(1초 주기 × 1.0): 공격 배율 ÷ 주기(전조 + 회복 + cooldown)
		local worst = 0
		for _, a in ipairs(def.attacks) do
			worst = math.max(worst, a.damage / (a.windup.seconds + a.recover + a.cooldown))
		end
		check(("한 사람 초당 피해(평타 대비) 최대 %.2f ≤ 1.0"):format(worst), worst <= 1.0 + 1e-9)
		check(("전조 초: 숨결 %.1f · 꼬리 %.1f · 돌풍 %.1f"):format(breath.windup.seconds, tail.windup.seconds, gust.windup.seconds),
			breath.windup.seconds == 0.8 and tail.windup.seconds == 0.6 and gust.windup.seconds == 0.7)
	end)

	print(("===Q 검증 끝(가)=== %d/%d 통과"):format(pass, total))
	return pass, total
end

return V
