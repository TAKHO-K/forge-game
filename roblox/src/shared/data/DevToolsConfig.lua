-- 밸런스 테스트 도구(DevTools.server.lua) 접근 제어(19-3a). 값 자체엔 밸런스 수치가
-- 없지만("코드 밖에 둔다"는 원칙이 이 파일에도 적용된다 - 허용 UserId를 서버 스크립트
-- 안에 하드코딩하면 나중에 바꿀 때마다 로직 파일을 열어야 한다), 이 파일 하나가 곧 "누가
-- 치트를 쓸 수 있는가"를 결정하므로 안전장치 자체의 일부다.
--
-- DevTools는 RunService:IsStudio()가 true일 때만 동작한다(1차 방어, 라이브 서버에선
-- 이 파일 내용과 무관하게 항상 꺼져 있다). allowedUserIds는 2차 방어 - Team Create로
-- 여러 명이 같은 Studio 세션에 들어와도 지정한 계정만 명령을 쓰게 좁힌다. 빈 배열이면
-- "Studio 안의 아무나"를 허용한다(1차 방어만으로 이미 충분히 안전하다는 뜻).

return {
	allowedUserIds = {},

	-- 서버 시작 때 도는 자동 검증 블록의 실행 스위치(DevTools.server.lua의 verifyEnabled). 블록마다 id("26-2" · "29-3(나)" · "S05(가)" ...)가 있다.
	-- 옛 세션의 블록이 Play마다 전부 돌면 한 번에 4분 가까이 걸린다(S05 실측 3분 55초) - 그래서 기본은 "지금 세션의 블록만"이다.
	--   regression = false(기본): current에 적은 id의 블록만 돈다.
	--   regression = true: 과거 세션의 블록 전부 + current. **마일스톤(S10 · S15 · S21 종료 시 · Fable 세션 전 · 퍼블리시 전)에서만 켜고, 그 Play가 끝나면 다시 false로 되돌린다**(COMMON.md §3 · §5).
	-- 새 세션을 시작할 때 current를 그 세션의 블록 id + 그 세션이 고친 모듈을 쓰는 옛 블록 id("동반 실행")로 갈아 끼운다(그 밖의 id는 지운다 - regression이 켜질 때 어차피 다 돈다).
	verify = {
		regression = false,
		-- 동반 실행에서 뺀 블록(2026-09-20, S12 사전 작업 1): "S04(나)". 최근 3회 Play 중 2회 이 블록 도중 Studio가 멈추거나 죽었다(S10 Play 1 · S11 Play 2).
		--   로그로 확인한 것: 서버 스레드 자체가 멈춘 것이다(클라 "Server timeout: 322307ms" · 로그가 그 자리에서 끊기고 하트비트만 다른 스레드에서 이어짐 · Studio 크래시 덤프 생성).
		--   멈춘 자리가 두 번 다르다 - S10: `[12]` 결과 줄 뒤(`[13]` 강화 시도 전후) / S11: `[9]`의 두 번째 200마리 묶음 66번째 처치 직후 - 같은 코드 줄이 원인이 아니다.
		--   이 블록은 잡몹 약 1200마리를 실제 처치 경로로 스폰 · 처치하고 5초 뒤 리스폰분을 다시 지운다(모델 + BillboardGui 수만 개 생성 · 파괴). 서버 코드의 while 루프는 처치 · 드랍 · 강화 경로에 없다(전수 grep) → 원인 미확정.
		--   S15 회귀 전체 전에 다시 다룬다(회귀 전체를 켜면 이 블록도 돈다 - 그때 멈추면 위 두 자리 외의 세 번째 자리를 기록할 것).
		-- S14(2026-09-20): 이번 세션 블록 S14(가)(밀도 식 · 사본 규칙 · 대상 조건 · 검사기 48칸 · 6종 몬테카를로 · 2연타) · S14(나)(스테이지 100 실제 스폰 · 겹친 원 한 번만 · 견습 · 스테이지 25) +
		-- 동반 실행(COMMON.md §3): 이 세션이 고친 모듈(BossData.mechanics · circleTarget 스킬 3종의 densityScalable · BossRules.buildInstanceDataFrom · BossSkillMath · BossSim)을 쓰는 옛 블록 = 보스 패턴 전부 -
		-- 29-1(BossMechanicsVerify) · 29-2(BossSkillVerify) · 29-3(BossGimmickVerify) · 29-4(BossGimmick4Verify) · 29-5(BossGimmick5Verify)의 (가)(나) + 스테이지 100 보스를 실제로 스폰하는
		-- 파티 경로(BossRules.buildInstanceData의 밀도 사본을 그대로 타는 S12(나)(PartyTutorialVerify) · S12b(나)(SocialVerify) - 둘 다 BOSS_STAGE = 100). S04(나)는 계속 제외.
		current = { "S14(가)", "S14(나)", "29-1", "29-2(가)", "29-2(나)", "29-3(가)", "29-3(나)", "29-4(가)", "29-4(나)", "29-5(가)", "29-5(나)", "S12(나)", "S12b(나)" },
	},
}
