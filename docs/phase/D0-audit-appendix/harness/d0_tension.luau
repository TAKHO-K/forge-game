D0 = { stop = false }
function D0.deal() return 1 end
function D0.take() return 1 end
function D0.gearFor(state) return state.gear end
function D0.onRebirth() end
local BossRules, BalanceSim, PlayerCombat, EconSim, BossData = MODS.BossRules, MODS.BalanceSim, MODS.PlayerCombat, MODS.EconSim, MODS.BossData
local MARKS = { 10, 20, 30, 40, 50, 75, 100, 150, 200, 300, 500, 1000 }
local seen
function D0.afterChunk(state, run, profile)
	for _, m in ipairs(MARKS) do
		if not seen[m] and state.reach >= m then
			seen[m] = true
			local stage = m - m % 5
			local lo = EconSim.loadoutFor(state)
			local data = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), profile.partySize)
			local newbie = PlayerCombat.getNewbieDamageMultiplier(stage)
			local hits = BalanceSim.getSurviveHits(lo, data.attack, newbie)
			local solo = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), 1)
			local secEff = EconSim.killSeconds(lo, data.hp / (profile.bossDpsEfficiency * profile.partySize), 1e6)
			local secSolo100 = EconSim.killSeconds(lo, solo.hp, 1e6)
			print(("  %s 보스%d 도달시 Lv%d 환생%d | 평타 버팀 %d타 | 처치(프로필 효율·인원) %.1fs | 솔로 순딜 %.1fs"):format(profile.displayName, stage, state.level, state.rebirth, hits, secEff, secSolo100))
		end
	end
	if state.reach >= 1000 then D0.stop = true end
end
for _, pid in ipairs({ "casual", "normal", "top" }) do
	seen = {}
	D0.stop = false
	EconSim.clearCaches()
	EconSim.runProgress(pid, {})
end
-- 기준: 레벨 = 스테이지 척도, 장비 itemLevel = 스테이지, 일반 등급, 강화 0 (anchor 꼴)
print("== 앵커(레벨 L · 장비 일반 itemLevel = 스테이지 · 강화 0 · 궁수) 보스 처치")
for _, stage in ipairs({ 20, 40, 60, 100, 200 }) do
	for _, L in ipairs({ stage, math.max(1, stage - 167) }) do
		local gear = {}
		for _, part in ipairs(MODS.EquipSlots.order) do gear[part] = { grade = "normal", part = part, itemLevel = stage } end
		local lo = BalanceSim.buildLoadout({ classId = "bow", level = L, weaponLevel = 0, weaponGrade = 0, gear = gear, gems = {} })
		local d = BossRules.buildInstanceData(stage, BossRules.bossIdForStage(stage), 1)
		print(("  스테이지 %d · Lv%d | 버팀 %d타 | 솔로 순딜 %.1fs"):format(stage, L, BalanceSim.getSurviveHits(lo, d.attack, MODS.PlayerCombat.getNewbieDamageMultiplier(stage)), EconSim.killSeconds(lo, d.hp, 1e6)))
	end
end
