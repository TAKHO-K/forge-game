-- 무한 모드 보스 데이터(15-1). PRD-forge-game-roblox.md 20.8-6이 정한 "구간별 보스 풀 +
-- 풀 안에서 랜덤" 구조를 그대로 옮긴다 - 지금은 종류를 하나만 만들지만(지시 [2], 여러 종
-- 제작은 다음 단계), pools 구조 자체는 나중에 항목을 추가하기만 하면 되도록 미리 잡아둔다.
--
-- stageInterval=5: 이 프로젝트엔 "몇 스테이지마다 보스"를 정한 기존 값이 없다(웹 v1의
-- 6단계 보스는 무한 스테이지가 아니라 유한 6판짜리 별도 콘텐츠라 참고가 안 된다,
-- PRD-forge-game-roblox.md 20.9 "웹 v1과의 차이" 참고). 로블록스 무한 모드는 지금 몬스터가
-- tier1 하나뿐이고 스테이지당 성장률 k=1.155(InfiniteStageConfig)만 있어 "긴 구간을 나눠
-- 보스로 매듭짓는다"는 의도 자체가 아직 실측 근거가 없다 - 그래서 이번 판단은 두 조건으로
-- 정했다: (1) 로블록스 타워/시뮬레이터 장르의 "10층마다 보스"보다 촘촘해야 지금 같은
-- 초기 빌드(레벨업・장비 축이 막 생긴 시점)에서 첫 보스를 금방 만나 검증할 수 있다,
-- (2) 5단계 간격이면 stage 5(첫 보스)의 잡몹 공격력이 8×1.155^4≈14.2로 아직 맨몸 캐릭터가
-- 버틸 수 있는 크기다(반면 10단계 간격이면 stage10 잡몹 공격력이 이미 8×1.155^9≈29.2로
-- 방어구 없는 캐릭터를 잡몹 평타만으로 즉사시켜 보스 자체를 검증할 수 없다 - 15-1 세션
-- 계산). 결론: stageInterval=5.
--
-- hpMultiplier=20은 새로 만든 값이 아니라 PRD-forge-game-roblox.md 20.9가 이미 확정해 둔
-- "일반 몬스터 체력 = 보스 체력 ÷ 20"을 그대로 뒤집어 재사용한 것이다(보스가 잡몹 20마리
-- 분량의 체력). attackMultiplier=1(평타는 잡몹과 동일)은 이번 세션에서 새로 정한 값 -
-- "보스가 위험한 이유"를 평타 크기가 아니라 heavyAttackMultiplier(주기적 예고 공격)
-- 하나에 몰아서, 평소엔 잡몹과 다르지 않다가 그 순간만 위험해지는 대비를 분명히 하려는
-- 의도다(지시 [3] "가장 싸게 긴장을 만드는 것 하나만").
return {
	stageInterval = 5,

	pools = {
		{ minStage = 1, bossIds = { "section_guardian" } },
	},

	bosses = {
		section_guardian = {
			id = "section_guardian",
			displayName = "구간 수호자",

			-- 잡몹(MonsterData.tier1) 대비 배율. 실제 수치는 그 스테이지의 잡몹 값에
			-- 곱해서 매번 계산한다(BossRules.buildInstanceData) - 여기 절대값을 박지 않는다
			-- (data/ 폴더 규칙, 스테이지가 바뀌어도 이 표를 고칠 필요가 없어야 한다).
			hpMultiplier = 20,
			attackMultiplier = 1,
			goldMultiplier = 20,
			expMultiplier = 20,

			-- 예고 후 강한 일격(지시 [3]에서 고른 유일한 긴장 장치). 평타의 3배 - 15-1
			-- 세션 계산(stage5 기준 감소율 42.9%, 데미지 24.4 vs playerMaxHp=10)으로 확인한
			-- 즉사급 수치다. 즉사이므로 반드시 예고가 있어야 한다는 지시 조건을 그대로
			-- 따른다 - telegraphWarmupSeconds 동안 보스가 멈춰 서서 색이 바뀌고, 그 사이
			-- 플레이어 이동속도(16stud/s)면 attackRangeStuds 밖으로 벗어나기 충분하다
			-- (로블록스엔 아직 웹의 대시·무적시간이 없어 이동만으로 피해야 한다).
			heavyAttackMultiplier = 3,
			heavyAttackIntervalSeconds = 6,
			telegraphWarmupSeconds = 1.5,
			telegraphColor = Color3.fromRGB(200, 30, 30),

			-- 크기·속도 - 아트 다듬기는 동결 상태라 기본 파트 크기만 키운다(지시 "하지 말
			-- 것"). sizeScale은 MonsterSpawner.buildModel의 파트 크기에 곱한다.
			sizeScale = 3,
			bodyColor = Color3.fromRGB(60, 20, 70),
			headColor = Color3.fromRGB(90, 30, 100),
			moveSpeedStuds = 8, -- 잡몹(10)보다 느리다 - 덩치가 큰 느낌 + 회피 난이도를 낮춘다.
			attackRangeStuds = 14, -- 커진 몸집만큼 사거리도 조금 더 길다.
			attackCooldownSeconds = 1.0,
		},
	},
}
