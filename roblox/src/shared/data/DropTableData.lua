-- 드랍표 단일 소스(P2 E1, 결정 6B). 몬스터 종류(사냥 구역 tier)별 드랍 항목 · 기본 확률은 전부 여기 있고, 계산은 shared/DropTable.lua 한 곳이다.
-- 서버의 실제 굴림(Loot · CombatResolution) · 화면용 조회(DropTableQuery RemoteFunction - UI는 P4) · 경제 시뮬(EconSim)이 같은 함수(DropTable.effectiveRate 등)를 부른다.
--
-- armorGradeByTier: 잡몹 장비 1개의 등급 분포(웹 data/items.js DROP_GRADE_TABLE - 16-5 조사값, index = tier). 옛 MonsterData.dropGradeTableByTier가 이 표를 가리킨다.
--   이 표는 tier 공정성 식(MonsterData - r(t) → HP · 공격 · 골드 · 경험치 배율)의 입력이기도 하다. 그래서 P2의 tier1 ~ 5 태초는 이 표에 넣지 않고 아래 primordial의
--   별도 굴림으로 준다 - 몬스터 수치가 한 자리도 안 바뀐다. tier6의 태초(0.1%)는 원래부터 이 표에 있던 값이고 primordial.dragonRate가 그 값을 채운다(숫자 하나).
-- primordial(P2 E2 · E3): 잡몹 장비 1개가 태초일 확률 = dragonRate ÷ dragonOverTier[t] × 레벨 감쇠(DropTable.levelDecay). 칸이 없는 tier는 0.
--   dragonOverTier = "드래곤 확률 ÷ 이 tier 확률"(2면 드래곤의 1/2). tier가 낮을수록 크다(확률이 낮다). 값 1.9 · 1.7 · 1.35 · 1.1 · 1.05 = E5 손익분기 M*
--   (Δ ≤ 5, 레벨 10 · 150 · 1000 최소 - tier1 1.94 · tier2 1.71 · tier3 1.39 · tier4 0.94 · tier5 0.71) 아래로 고른 것. tier4 · 5는 M*가 1 미만이라 "드래곤보다 낮게"와
--   동시에 못 맞춘다 - 1에 가깝게 두었다.
--   근거 · 대안 = docs/phase/P2-log.md.
--   levelDecay: 사냥 스테이지가 본인 최고 스테이지보다 startGap 이상 낮으면, (격차 − startGap + 1)칸마다 perLevel씩 깎는다(0 미만 금지).
--   태초 장비의 itemLevel = 그 몬스터를 잡은 사냥 스테이지("몬스터 레벨" - 편차 δ 없음, E4). 분해하면 그 레벨의 태초 보석이 된다.
-- 보스(첫 처치 · 재도전) · 반짝이 · 견습 드랍은 이 굴림을 안 탄다(결정 9A - 보스 드랍 유지).

local dragonRate = 0.001

return {
	armorGradeByTier = {
		{ normal = 0.90, rare = 0.10 },
		{ normal = 0.70, rare = 0.27, epic = 0.03 },
		{ normal = 0.45, rare = 0.40, epic = 0.14, legendary = 0.01 },
		{ normal = 0.20, rare = 0.40, epic = 0.30, legendary = 0.09, relic = 0.01 },
		{ normal = 0.05, rare = 0.25, epic = 0.40, legendary = 0.25, relic = 0.045, ancient = 0.005 },
		{ rare = 0.10, epic = 0.30, legendary = 0.40, relic = 0.18, ancient = 0.019, primordial = dragonRate },
	},

	primordial = {
		dragonRate = dragonRate,
		dragonOverTier = { 1.9, 1.7, 1.35, 1.1, 1.05, 1 },
		levelDecay = { startGap = 5, perLevel = 0.10 },
	},
}
