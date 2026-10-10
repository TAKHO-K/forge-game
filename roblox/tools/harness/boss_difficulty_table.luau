-- BOSS-NIGHT-3 7단계: 난이도 표(BossDifficultySim · 새 몸 · 발생 지점 켬 · 스테이지 100 · 솔로) - 보스 하나 × 근/원 × 아는/처음 × 대시 끔/켬.
-- PRELUDE=motion_prelude.luau(발생 지점 = CFrame 대역). 첫 줄에 SIM_BOSS(필수) · SIM_RUNS(기본 600) · SIM_REBIRTH(기본 0 - 수정 여왕 빔 점프 회피)를 붙여 실행. ECON_SRC로 옛 src 사본과 같은 파일 비교.
--   줄 = DIFF 보스 역할 숙련 대시 전멸% 받은피해% 처치p50 대시(긴 · 짧은 · 보호만 · 보호됨 · 반응)
local Sim = MODS.BossDifficultySim
local RUNS = SIM_RUNS or 600
local BOSS = SIM_BOSS
for _, role in ipairs({ "ranged", "melee" }) do
	for _, fam in ipairs({ true, false }) do
		for _, dash in ipairs({ false, true }) do
			local r = Sim.monteCarlo(BOSS, { partySize = 1, role = role, familiar = fam, stage = 100, bodyEdgeRig = BOSS .. "_v2", origin = true, dash = dash, rebirth = SIM_REBIRTH or 0 }, RUNS)
			local u = r.dashUsesPerRun or {}
			print(("DIFF\t%s\t%s\t%s\t%s\t%.1f\t%.1f\t%.1f\t%.2f\t%.2f\t%.2f\t%.2f\t%.2f"):format(BOSS, role, fam and "familiar" or "first", dash and "on" or "off",
				r.wipeRate * 100, r.takenMean * 100, r.p50, u.long or 0, u.short or 0, u.protectOnly or 0, u.protected or 0, u.reactive or 0))
		end
	end
end
