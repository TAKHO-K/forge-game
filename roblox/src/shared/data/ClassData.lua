-- 클래스 4종 정의(10-3). atk/atkSpeed/def만 다룬다 - critRate/critDmg는 원본에 있지만
-- 이번엔 옮기지 않는다(치명타는 10-4 - 새 메커니즘이라 따로 다룬다, 지시 사항의
-- "하지 말 것" 참고).
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

	classes = {
		greatsword = {
			id = "greatsword",
			displayName = "대검",
			atk = 1.85,
			atkSpeed = 0.7,
			def = 1.3,
		},
		dualblade = {
			id = "dualblade",
			displayName = "쌍검",
			atk = 0.85,
			atkSpeed = 1.6,
			def = 0.6,
		},
		bow = {
			id = "bow",
			displayName = "활",
			atk = 1.8,
			atkSpeed = 1.0,
			def = 0.6,
		},
		healer = {
			id = "healer",
			displayName = "힐러",
			atk = 0.6,
			atkSpeed = 1.25,
			def = 1.0,
		},
	},
}
