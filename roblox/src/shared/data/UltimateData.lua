-- K1 궁극기(T) 게이지 · 충전 · 4직업 수치(docs/design/skills-RT.md §3 · 지시서 K1). 서버 UltimateService가 게이지를 가진다(클라 = 표시만 · Player Attribute UltGauge).
-- 게이지: 0 ~ 100 · 일반 스테이지 이동 · 사망에도 유지 · 보스 입장(아레나 입장 · 전멸 리셋) 때 0 · 가득(100)일 때만 T 발동(서버 판정) → 0.
-- 충전 목표: 보스전 연속 전투 약 60초에 100(직업별 ±20% 안). 사냥(보스 밖)은 huntChargeScale배(D0 §3-1 제안 - 사냥 속도 · 경제 영향 억제).
--   단위: "타 단위" = 이번 타격의 계수(평타 = 한 타 피해 배율 swingScale · 스킬 = 틱 계수) - 스테이지 · 장비와 무관(atk로 나눈 값).
--   k1 하네스(앵커 레벨 100 · 60초 · 스킬 포함): 대검 6.1 atk/초 · 치유사 딜링 14.4 atk/초 · 쌍검 적중 ≈ 4.4회/초 · 활 ≈ 2.2회/초 → 아래 값으로 60초 전후(대검 66초 + 받은 피해 · 쌍검 ≈ 52초 · 활 먼 거리 49초 / 가까이 73초 · 치유사 딜링 69초 + 치유).
return {
	max = 100,
	huntChargeScale = 1 / 3,
	-- 리더보드 이론 최대 DPS(LeaderboardRules.memberDpsCap)에 곱하는 궁극기 몫: 짧은 싸움(≤ 8초)은 대검 변신 +30%가 싸움 전체를 덮을 수 있다 - 다른 궁극기(단일 대상 9 ~ 37 atk)는
	--   평타 상한(burstFactor)의 한 틱 안에 들어간다(k1 하네스: 60초 딜 대비 1.8 ~ 4.4%). 정상 클리어가 too_fast로 거절되지 않게 +30%.
	leaderboardDpsCapBonus = 0.30,
	charge = {
		greatsword = { perDamageUnit = 0.25, perTakenMaxHp = 40 }, -- 준 피해(타 단위) + 받은 피해(최대 체력 비율 × 40 - 25% 맞으면 +10)
		dualblade = { perHit = 0.36, critWeight = 1.5 }, -- 적중 횟수(두 칼 = 2타) · 치명 = 1.5타
		bow = { perHit = 0.62, farStuds = 15, farWeight = 1.5 }, -- 적중 + 15 stud 이상 먼 적중 ×1.5
		healer = { perHealMaxHp = 60, perDamageUnit = 0.1 }, -- 치유량(대상 최대 체력 비율 × 60) + 딜링 모드 피해(타 단위)
	},

	-- 4직업 궁극기(초안 · DPS 규칙 안: 단일 대상 총 피해 ≈ 8 ~ 10 atk 단위 = 60초 보스전 딜의 약 5% - 상한 15%). 계수 = atk 비율(스킬과 같은 원칙).
	skills = {
		greatsword = {
			name = "파괴의 화신", shape = "ultTransform",
			durationSeconds = 8, attackBonus = 0.30, bodyScale = 1.15, -- 공격력 +30%(최종 피해 배율) · 넉백 · 경직 면역(피해 면역 아님) · 몸 ×1.15(클라 연출)
			shockwave = { coefficient = 0.15, radiusStuds = 8, forwardStuds = 5 }, -- 평타마다 앞쪽 원 충격파(평타 대상 제외 주변)
			finale = { coefficient = 2.0, radiusStuds = 12 }, -- 끝에 강타(주변 원)
		},
		bow = {
			name = "천궁의 폭우", shape = "ultRain",
			radiusStuds = 14, durationSeconds = 3, tickCount = 12, -- 클릭 지점 반경 14 · 3초 12틱
			coefficient = 7.5, -- 대상 1명당 총 계수 = 백스텝샷(E) 5발 × 0.5 = 2.5의 ×3
			maxCastStuds = 70, -- 클릭 지점이 이보다 멀면 거부(위조 방지)
		},
		dualblade = {
			name = "죽음의 계약", shape = "ultMark",
			durationSeconds = 5, storeFraction = 0.40, burstCoefficient = 3.0, -- 표식 5초: 내가 그 대상에 준 피해 40%를 모아 끝에 폭발 + 기본 폭발 계수
			rangeStuds = 20, killRefund = 50, -- 표식 대상 선택 거리 · 표식 중 처치 = 게이지 50 반환
		},
		healer = {
			name = "생명의 성역", shape = "ultSanctuary",
			durationSeconds = 6, radiusStuds = 16, healPerSecondMaxHp = 0.03, -- 파티원 HP 1 바닥(일반 피해만 - 즉사 · 전멸기 · 최대 체력 % 기믹 · 낙사는 못 막음) · 초당 최대 체력 3%
			reviveOnEnd = true, -- Q8 K3: 성역이 끝날 때 성역 안 · 성역 동안 죽은 사람 부활(영혼 = 즉시 · 리스폰 대기 = 리스폰 때) - SoulService.reviveSanctuary
		},
	},
}
