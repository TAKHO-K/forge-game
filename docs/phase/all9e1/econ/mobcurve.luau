REF_S0_IN = 8570
-- QUEUE-ALL9E1 0-6 실제 몹 곡선: MonsterStats(서버 · UI · 시뮬 같은 함수)로 스테이지 1 ~ 25,300 잡몹(tier1 · tier6) · 보스(그 스테이지 보스) · 관문(구역 관문 보스 = 보스 6종 중 그 구간 것과 같은 식 - 여기서는 section_guardian · frost_giant) 체력 · 공격 · 방어
--   off = 스위치 끔 · on = 켬(전역 재조정만 - 계승 안 한 사람) · onRef = 켬 + 중앙값 계승자(계승 스테이지 = REF_S0 · 돌파 계수 포함)
local MS, MD, BR = MODS.MonsterStats, MODS.MonsterData, MODS.BossRules
local REF_S0 = tonumber(REF_S0_IN) or 8570
print("CSV|stage|mode|t1_hp|t1_atk|t1_def|t6_hp|t6_atk|t6_def|boss_id|boss_hp|boss_atk|gate1_hp|gate1_atk|gate6_hp|gate6_atk|break")
local stages = { 1 }
for s = 100, 25300, 100 do table.insert(stages, s) end
for _, mode in ipairs({ "off", "on", "onRef" }) do
	ATTR.All10Economy = mode ~= "off"
	local inh = mode == "onRef" and REF_S0 or nil
	for _, s in ipairs(stages) do
		local t1, t6 = MS.trash(MD.tier1, s, nil, inh), MS.trash(MD.tier6, s, nil, inh)
		local bid = BR.bossIdForStage(s)
		local nan = { hp = 0 / 0, attack = 0 / 0 }
		local b = bid and BR.buildInstanceData(s, bid, 1) or nan
		local g1 = BR.buildInstanceData(s, "section_guardian", 1) or nan
		local g6 = BR.buildInstanceData(s, "frost_giant", 1) or nan
		local bf = MS.breakFactor(s, inh)
		print(("CSV|%d|%s|%.6g|%.6g|%.6g|%.6g|%.6g|%.6g|%s|%.6g|%.6g|%.6g|%.6g|%.6g|%.6g|%.6g"):format(s, mode, t1.hp, t1.attack, t1.defense, t6.hp, t6.attack, t6.defense,
			tostring(bid), b.hp * bf, b.attack, g1.hp * bf, g1.attack, g6.hp * bf, g6.attack, bf))
	end
end
