-- 스킬 8종(직업당 Q/E) 정의의 단일 출처(20-2a). 지금은 대검 2종만 채운다 - 나머지 6종은
-- 다음 세션들(20-2b~)의 자리만 남겨 둔다(빈 테이블).
--
-- coefficient는 반드시 "공격력(atk) 대비 비율"이다 - 절대값을 쓰지 않는다. 20-1이 만든
-- 무기 등급 축과 강화 단계가 전부 atk 하나에 곱해지므로(Enhance.getPlayerAttack), 계수를
-- 비율로 두면 등급이 오르든 강화가 오르든 스킬 데미지가 자동으로 같이 늘어난다(20-1
-- [3](다)에서 이미 실측 확인한 성질 - 등급별로 스킬 밸런스를 다시 잴 필요가 없다는 게
-- 이 설계의 핵심 이유).
--
-- 실제 계수·쿨다운 출처: PRD-forge-game.md 4.3(대검 C_Q=5.5·C_E=5.91, 채널링 위험
-- 프리미엄 `0.15×(1-channelMoveSpeedMultiplier)` 반영, 스테이지 환산까지 끝난 검증값).
-- 20-2a 작업 지시문에 있던 "계수8/쿨다운10, 계수14/쿨다운14/채널0.8초"는 두 PRD 어디에도
-- 기록이 없는 값이라([0] 확인 결과 사용자 승인) 채택하지 않았다.
return {
	greatsword = {
		Q = {
			name = "관통돌진",
			shape = "line", -- 시작점~끝점 경로에 닿는 전원 타격(AttackServer의 단일 대상 픽과 다르다).
			coefficient = 5.5,
			cooldownSeconds = 10,

			-- 돌진 거리·시간(20-2a [2]) - 웹 220px/0.3초를 pxPerStud(10)로 기계 환산하지
			-- 않는다. PRD-forge-game-roblox.md 20.15가 이미 이 방법을 폐기했다 - "사거리·
			-- 이동 속도는 픽셀 비율이 아니라 느낌이 맞는 독자적인 값으로 새로 정의한다,
			-- 3인칭 카메라 거리감과 안 맞기 때문"(사용자 승인, 20-2a [0]). 대신 이 프로젝트
			-- 안의 기준점으로 새로 잡는다: 대검 사거리 13stud(CombatConfig.attackRangeStuds
			-- 10 × ClassData.greatsword.rangeMultiplier 1.3)보다 확실히 길어야 "돌진"이라는
			-- 이름값을 하고, 사냥터 한 변(WorldConfig 192stud)의 약 10%면 담장 안에서 실제로
			-- 여러 몬스터를 꿰뚫을 여지가 있다 - 18stud로 잡는다. 0.25초(72stud/s)는 평타
			-- 쿨다운(0.28초/atkSpeed)보다 짧게 느껴지도록 잡은 값 - 정확한 체감은 실기로
			-- 맞춘다(지시 [4], SkillServer.server.lua/WeaponVisual 쪽 참고).
			rangeStuds = 18,
			durationSeconds = 0.25,
			-- 경로 좌우로 몬스터를 인식하는 폭(선분 판정의 반경) - 칼날 리치를 감안한 값,
			-- 몬스터 판정 파트가 대략 반지름 2stud대라 5stud면 스치는 정도도 맞는다.
			hitRadiusStuds = 5,
		},
		E = {
			name = "회전베기",
			shape = "circle", -- 시전자 중심 반경 안 전원 타격.
			-- 누적(총합) 계수 - PRD 4.3 "3초간... 주변 지속 타격(누적 데미지 계수 5.91)"은
			-- 채널링이 끝나는 순간 한 번이 아니라 진행 중 지속 틱이다. 이번 작업 지시문
			-- [3]은 "채널링이 끝나는 시점에 한 번"이라고 적었지만 실제 명세(PRD 4.3)와
			-- 달라 명세를 따른다(지시 [3]의 "명세가 다르면 명세를 따르고 보고해라" 그대로,
			-- 20-2a [0] 보고 참고). tickCount로 나눠 매 틱 coefficient/tickCount만큼 때린다.
			coefficient = 5.91,
			cooldownSeconds = 16,
			channelSeconds = 3,
			-- 1초 간격 3틱 - PRD 4.3 쌍검 E(8초 도트/8틱→1틱=1초)와 같은 "1초에 1틱" 관례를
			-- 그대로 재사용한다(새 캐던스를 만들지 않는다).
			tickCount = 3,
			channelMoveSpeedMultiplier = 0.5,
			-- 채널링 중 받는 피해 배율 - PRD 4.3 "받는 피해 50% 감소"를 그대로 반영한다.
			-- 이번 작업 지시문 [3]엔 없던 항목이지만 실제 명세에 있어 반영했다(위와 같은 사유).
			incomingDamageMultiplier = 0.5,
			-- 반경(20-2a [3]) - 대검 사거리 13stud의 약 1.5배인 20stud. 단일 대상 평타
			-- 리치보다 넉넉히 커야 광역이라는 이름값을 하고, 사냥터(192stud)를 뒤덮을
			-- 만큼 크지는 않아야 "제자리 회전"이라는 스킬의 정체성이 유지된다.
			radiusStuds = 20,
		},
	},

	-- 나머지 3직업은 다음 세션(20-2b~)에서 채운다 - 지금은 자리만 남긴다. SkillServer.
	-- server.lua/SkillInput.client.lua는 SkillData[classId][slot]이 nil이면 조용히
	-- 아무 일도 하지 않는다(에러를 내지 않는다, 20-2a [5] 검증 7번).
	dualblade = {},
	bow = {},
	healer = {},
}
