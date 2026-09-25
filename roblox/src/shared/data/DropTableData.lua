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

	-- G1-1(보상 목록 단일 소스): 보스 확정 장비의 등급표. 옛 코드는 첫 클리어 = armorGradeByTier[6](드래곤 표를 그대로 가리킴) · 재도전 = [1]이었다 - 드래곤 표를
	-- 고치면(G1-2 공정성 보정) 보스 보상이 같이 바뀌므로 값을 그대로 옮겨 따로 선언한다(값 불변). 환생 0회의 상향표는 MonsterData가 이 firstClear를 한 단계 민다.
	-- 읽는 곳: DropTable.bossFirstClearGradeTable · bossRetryGradeTable(서버 굴림 Loot · 스테이지 선택 보상 띠 · 검증).
	bossGrades = {
		firstClear = { rare = 0.10, epic = 0.30, legendary = 0.40, relic = 0.18, ancient = 0.019, primordial = dragonRate },
		retry = { normal = 0.90, rare = 0.10 },
	},

	primordial = {
		dragonRate = dragonRate,
		-- P2.5a C9: 1.9 · 1.7 · 1.35 · 1.1 · 1.05 → 1.30 · 1.20 · 1.08 · 0.85 · 0.64. "지배 전략 없음"을 우선(사용자 지시) - 새 단위 손익분기 M*(Δ ≤ 36 = 옛 Δ ≤ 5 · 레벨 10 · 1000 · 10000
		-- 최소) tier1 1.32 · tier2 1.21 · tier3 1.10 · tier4 0.86 · tier5 0.65 바로 아래. 감쇠 시작이 70칸이라 Δ ≤ 36에서는 감쇠가 없다 → 옛 값보다 M*가 낮다.
		-- tier4 · 5는 1 미만 = 드래곤보다 확률이 높다(낮은 tier일수록 낮게와 충돌 - 결정 필요).
		-- P2.5c 결정 7(사용자 확정): 드래곤(tier6)이 항상 최고 - tier4 · 5 = 드래곤의 ×0.94 · ×0.97(dragonOverTier 1/0.94 · 1/0.97, tier3 ×0.926 < tier4 < tier5 < 드래곤).
		-- M*(tier4 0.86 · tier5 0.65)보다 커서 Δ가 작으면 "드래곤을 조금 낮은 스테이지에서"가 tier4 · 5를 앞서는 약한 지배가 생긴다(허용 - 수치는 P25c-after E5).
		dragonOverTier = { 1.30, 1.20, 1.08, 1 / 0.94, 1 / 0.97, 1 },
		-- P2.5a C9: 5 · 10% → 70 · 1.4%. 시작 = 평소 사냥 구간 바깥 - 시뮬에서 사냥 스테이지는 최고 스테이지보다 일반 41 ~ 56 · 상위 1% 56 ~ 66칸 아래다(높은 tier일수록
		-- 몬스터 공격이 세서 더 낮은 스테이지에서 잡는다 - p99 66). 70칸 = 몬스터 HP ×4.0. 0이 되는 격차 = 70 + 71 = 141(옛 감쇠 폭 "시작 ×2.1 → 0 ×7.5"의 비 ×3.6을 그대로 -
		-- 1.02^71 ≈ 4.1). 근거 = docs/phase/P25a-log.md.
		levelDecay = { startGap = 70, perLevel = 0.014 },
	},
}
