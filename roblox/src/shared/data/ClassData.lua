-- 클래스 4종 정의(10-3에서 atk/atkSpeed/def, 10-4에서 critRate/critDmg 추가).
--
-- critRate/critDmg 출처: PRD-forge-game.md 4.4(대검 12%/2.0, 쌍검 30%/2.0, 활 15%/2.3,
-- 힐러 12%/1.8). `git log`로 확인한 결과 이 값을 담은 재배치 커밋(766db2e)은 PRD 파일만
-- 고쳤고 `data/classes.js`는 건드리지 않았다 - atk/atkSpeed/def 때(위 주석)와 같은 누락
-- 패턴이라 웹 코드(critRate 0.10/0.25/0.15/0.12, critDmg 1.8/1.6/2.6/1.8)는 갱신 전
-- 값이고 참고하지 않는다.
--
-- 값의 출처가 두 갈래다 - 하나로 뭉뚱그려 "웹 그대로"라고 적으면 틀린다:
--
-- 대검·쌍검·활은 `data/classes.js`가 아니라 PRD-forge-game.md 4.1/4.4(766db2e·fa5ea8c
-- 커밋, "직업 밸런스 기준선 재배치")을 기준으로 삼는다. `git log`로 확인한 결과
-- `data/classes.js`의 마지막 수정(169d31d)이 이 재배치 커밋들보다 먼저다 - 즉 PRD를
-- 갱신하면서 웹 코드 반영이 누락된 상태다("웹에서 확정된 값을 그대로 옮겨라"는 이번 지시의
-- 전제 자체가 깨진 사례 - 동결된 옛 코드가 아니라 갱신된 설계가 기준이어야 한다). 이 재배치로
-- 쌍검 def가 1.0→0.6으로 바뀌었다 - PRD-forge-game-roblox.md 20.11-4의 classDefMult 표
-- ("쌍검·활 공통 0.6")는 이 갱신된 값을 정확히 인용한 것이었고, 오히려 이 파일의 첫 버전이
-- (코드를 그대로 베껴) 쌍검def=1.0으로 잘못 만들어 20.11-4를 "정정"하려 했던 게 후퇴였다 -
-- 바로잡았다.
--
-- 힐러 atk/atkSpeed는 반대로 코드값(0.6/1.25)을 쓴다 - PRD 4.1-1의 힐러 표(0.5/1.0)는
-- 최초 커밋(3a750cf)에서 한 번도 갱신된 적이 없는 초안이고, 코드값은 그 뒤 실제로
-- 튜닝되고 지금까지 라이브로 돌아간 값이다(치확·치피는 PRD·코드 둘 다 12%/1.8로 이미
-- 일치 - atk·atkSpeed만 어긋난 상태였다). 어느 쪽을 기준 삼을지 애매해 확인 후 코드값으로
-- 확정했다(사용자 승인, 10-3 세션).

return {
	order = { "greatsword", "dualblade", "bow", "healer" },

	-- rangeMultiplier(19-2) - CombatConfig.attackRangeStuds(=10, 대검 기준 웹 원본값)에
	-- 곱하는 클래스별 사거리 배율. 쌍검은 그대로 1.0(지시 - "가장 짧은 사거리가 쌍검의
	-- 정체성이고, 그 대가로 최고 단일 DPS를 갖는다. 여기를 건드리면 균형이 깨진다").
	-- 활·힐러는 1.5배로 늘려 원거리 직업답게 만들고(WorldConfig.aggro.rangeStuds=25.6보다
	-- 여전히 짧아 무한 안전 사냥은 안 생긴다 - 19-2 [3] 검증), 대검은 근접이지만 리치가 긴
	-- 무기라 쌍검보다는 길게 1.3배로 둔다. 결과 서열: 쌍검(최단) < 대검 < 활 = 지팡이(최장).
	classes = {
		greatsword = {
			id = "greatsword",
			displayName = "대검",
			atk = 1.85,
			atkSpeed = 0.7,
			def = 1.3,
			critRate = 0.12,
			critDmg = 2.0,
			rangeMultiplier = 1.3,
		},
		dualblade = {
			id = "dualblade",
			displayName = "쌍검",
			atk = 0.85,
			atkSpeed = 1.6,
			def = 0.6,
			critRate = 0.30,
			critDmg = 2.0,
			rangeMultiplier = 1.0,
		},
		bow = {
			id = "bow",
			displayName = "활",
			atk = 1.8,
			atkSpeed = 1.0,
			def = 0.6,
			critRate = 0.15,
			critDmg = 2.3,
			rangeMultiplier = 1.5,
		},
		healer = {
			id = "healer",
			displayName = "힐러",
			atk = 0.6,
			atkSpeed = 1.25,
			def = 1.0,
			critRate = 0.12,
			critDmg = 1.8,
			rangeMultiplier = 1.5,
		},
	},
}
