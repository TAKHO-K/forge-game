-- 밸런스 테스트 도구(DevTools.server.lua) 접근 제어(19-3a). 값 자체엔 밸런스 수치가
-- 없지만("코드 밖에 둔다"는 원칙이 이 파일에도 적용된다 - 허용 UserId를 서버 스크립트
-- 안에 하드코딩하면 나중에 바꿀 때마다 로직 파일을 열어야 한다), 이 파일 하나가 곧 "누가
-- 치트를 쓸 수 있는가"를 결정하므로 안전장치 자체의 일부다.
--
-- DevTools는 RunService:IsStudio()가 true일 때만 동작한다(1차 방어, 라이브 서버에선
-- 이 파일 내용과 무관하게 항상 꺼져 있다). allowedUserIds는 2차 방어 - Team Create로
-- 여러 명이 같은 Studio 세션에 들어와도 지정한 계정만 명령을 쓰게 좁힌다. 빈 배열이면
-- "Studio 안의 아무나"를 허용한다(1차 방어만으로 이미 충분히 안전하다는 뜻).

-- 수동 Play 모드(S19b 사전 작업 1): 자동 검증은 **기본 꺼짐**이다. Studio에서 그냥 Play를 누르면 아래 verify 표가 비어 있는 것으로 읽히고
-- (verify.current = {} · regression = false), 자체 점검(UiSelfCheck)과 서버 시작 검증 줄도 안 찍힌다. 터미널(Claude)이 검증할 때만 Play 직전
-- **edit 모드에서** ReplicatedStorage의 Attribute `VerifyArmedUntil`(os.time() + 초)을 켜고, Play가 끝나면 지운다:
--   켜기: game:GetService("ReplicatedStorage"):SetAttribute("VerifyArmedUntil", os.time() + 1800)
--   끄기: game:GetService("ReplicatedStorage"):SetAttribute("VerifyArmedUntil", nil)
-- 왜 Attribute인가: Rojo는 이 파일(src)과 default.project.json에 적힌 것만 Studio에 반영하므로, project에 없는 ReplicatedStorage의 Attribute는
-- 덮어쓰이지 않는다(실측은 PRD 20.106). 왜 만료 시각인가: 끄는 걸 잊어도 30분 뒤에는 저절로 꺼진다(사용자가 그냥 Play를 눌러 검증이 도는 일을 막는다).
-- 켜진 동안(verifyArmed = true)에는 SaveSystem이 개발 계정 프로필을 `Player_<id>_verify` 키로 읽고 쓴다(S19b 사전 작업 2) - 검증 도중 Play가 멈춰도 실제 프로필은 그대로다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local config = {
	allowedUserIds = {},

	-- P0 경제 시뮬(server/EconSim* · /gg econ) 스위치. EconSim.isAllowed() = RunService:IsStudio() and 이 값 - 라이브 서버에서는 IsStudio가 거짓이라 켜져 있어도 안 돈다
	-- (그 위에 DevTools.server.lua 자체가 라이브에서 첫 줄에서 죽는다 - 이중 차단). 끄면 Studio에서도 /gg econ · P0(가)가 에러로 멈춘다.
	econSim = true,

	-- 입력 진단 로거(client/InputDiag.client.lua - S20 사전 작업 [InputDiag]). 기본 꺼짐. 켜면 수동 Play에서도 모든 입력 · 단축키 처리 단계를 한 줄씩 찍는다.
	inputDiag = false,

	-- 서버 시작 때 도는 자동 검증 블록의 실행 스위치(DevTools.server.lua의 verifyEnabled). 블록마다 id("26-2" · "29-3(나)" · "S05(가)" ...)가 있다.
	-- 옛 세션의 블록이 Play마다 전부 돌면 한 번에 4분 가까이 걸린다(S05 실측 3분 55초) - 그래서 기본은 "지금 세션의 블록만"이다.
	--   regression = false(기본): current에 적은 id의 블록만 돈다.
	--   regression = true: 과거 세션의 블록 전부 + current. **마일스톤(S10 · S15 · S21 종료 시 · Fable 세션 전 · 퍼블리시 전)에서만 켜고, 그 Play가 끝나면 다시 false로 되돌린다**(COMMON.md §3 · §5).
	-- 새 세션을 시작할 때 current를 그 세션의 블록 id + 그 세션이 고친 모듈을 쓰는 옛 블록 id("동반 실행")로 갈아 끼운다(그 밖의 id는 지운다 - regression이 켜질 때 어차피 다 돈다).
	verify = {
		regression = false,
		-- exclude: regression = true여도 돌리지 않는 블록 id(DevTools.server.lua verifyEnabled가 먼저 본다).
		exclude = { "S04(나)" },
		-- S15 사전 작업 1(2026-09-20, 40분 제한 조사): S04(나)를 계측(처치 10회마다 몬스터 · 드랍 · workspace 후손 · 메모리 태그 · 하트비트 - 커밋 21ce309에 남아 있다)하며 3번 돌렸다 -
		--   ① 단독 9/9 ② S04(나) 직전까지의 체인 + S04(나) 9/9 ③ 회귀 전체 체인 9/9. 멈춤은 재현되지 않았다(계속 늘어나는 값도 없다 - PRD 20.101). 원인 미확정이라 exclude로 회귀 전체에서도 뺀다.
		-- 동반 실행에서 뺀 블록(2026-09-20, S12 사전 작업 1): "S04(나)". 최근 3회 Play 중 2회 이 블록 도중 Studio가 멈추거나 죽었다(S10 Play 1 · S11 Play 2).
		--   로그로 확인한 것: 서버 스레드 자체가 멈춘 것이다(클라 "Server timeout: 322307ms" · 로그가 그 자리에서 끊기고 하트비트만 다른 스레드에서 이어짐 · Studio 크래시 덤프 생성).
		--   멈춘 자리가 두 번 다르다 - S10: `[12]` 결과 줄 뒤(`[13]` 강화 시도 전후) / S11: `[9]`의 두 번째 200마리 묶음 66번째 처치 직후 - 같은 코드 줄이 원인이 아니다.
		--   이 블록은 잡몹 약 1200마리를 실제 처치 경로로 스폰 · 처치하고 5초 뒤 리스폰분을 다시 지운다(모델 + BillboardGui 수만 개 생성 · 파괴). 서버 코드의 while 루프는 처치 · 드랍 · 강화 경로에 없다(전수 grep) → 원인 미확정.
		--   S15 회귀 전체 전에 다시 다룬다(회귀 전체를 켜면 이 블록도 돈다 - 그때 멈추면 위 두 자리 외의 세 번째 자리를 기록할 것).
		-- S14(2026-09-20): 이번 세션 블록 S14(가)(밀도 식 · 사본 규칙 · 대상 조건 · 검사기 48칸 · 6종 몬테카를로 · 2연타) · S14(나)(스테이지 100 실제 스폰 · 겹친 원 한 번만 · 견습 · 스테이지 25) +
		-- 동반 실행(COMMON.md §3): 이 세션이 고친 모듈(BossData.mechanics · circleTarget 스킬 3종의 densityScalable · BossRules.buildInstanceDataFrom · BossSkillMath · BossSim)을 쓰는 옛 블록 = 보스 패턴 전부 -
		-- 29-1(BossMechanicsVerify) · 29-2(BossSkillVerify) · 29-3(BossGimmickVerify) · 29-4(BossGimmick4Verify) · 29-5(BossGimmick5Verify)의 (가)(나) + 스테이지 100 보스를 실제로 스폰하는
		-- 파티 경로(BossRules.buildInstanceData의 밀도 사본을 그대로 타는 S12(나)(PartyTutorialVerify) · S12b(나)(SocialVerify) - 둘 다 BOSS_STAGE = 100). S04(나)는 계속 제외.
		-- S15(2026-09-20): 스테이지 선택 10단위 UI(클라 전용) - 이번 세션 블록 S15(UI) + 동반 실행(COMMON.md §3): 이 세션이 고친 StageSelectPanel · UIManager · PanelRegistry를 쓰는 옛 검증 =
		-- S12(UI)(PanelFitCheck - 스테이지 선택 패널 화면 안 · 도감 점) · S11(가)(StageSelectPanel이 도는 보상 띠 자체 점검) · S11(나)(서버 보상 미리보기 조회) · 27-4(가)(나)(스테이지 상태 Attribute 파이프라인).
		-- S16 사전 작업(2026-09-20): 잠긴 칩 글씨색 + 자물쇠 · 칸 번호 실효 12 + 색 대비 · X 버튼 44 × 44(StageSelectPanel · HudIcons · UIColors - 클라 전용) - S15(UI)(항목 추가) + 동반 S12(UI)(PanelFitCheck 글씨 줄) · S11(가)(StageSelectPanel 안의 보상 띠 점검) +
		-- 29-3(나)(BossGimmickVerify 구덩이 개수 검증 수정 - 5회 반복 확인).
		-- S16(2026-09-20): 메뉴바 + 단축키 표의 PanelRegistry 한 곳 집중(클라 전용 - 서버 변경 0) - 이번 세션 블록 S16(UI) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈(UIManager · PanelRegistry · ScreenMap ·
		-- HudIcons · PartyHud · UiSelfCheck)을 쓰는 옛 클라 점검 = S12(UI)(PanelFitCheck - 등록 창 전수 화면 안) · S12b(UI)(SocialSelfCheck - 파티창 등록 · 알림 · 창 글씨) · S15(UI)(스테이지 선택 station 등록 규칙 ·
		-- HudIcons.lock 칩) · S10(가)(드랍 피드 [S10][UI] - ScreenMap 슬롯 · FeedLayout). S04(나)는 계속 제외.
		-- S17(2026-09-20): 시스템 토스트 5종 → Toast(클라 전용 - 서버 변경 0) - 이번 세션 블록 S17(UI) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈(ScreenMap 옛 슬롯 5개 삭제 · Toast의 새 사용처)을 쓰는 옛 클라 점검 =
		-- S16(UI)(메뉴바 - ScreenMap 슬롯 겹침 · Toast TC 줄) · S12b(UI)(SocialSelfCheck - Toast TC 알림 · 드랍 피드) · S10(가)(DropFeed의 [S10][UI] - ScreenMap 슬롯 · FeedLayout · Toast TR). `[S06][UI]` 겹침 검사는 항상 돈다. S04(나)는 계속 제외.
		-- S18(2026-09-20): PartyHud 분할(목록 · 요청 배너 · 알림 - 클라 전용, 서버 변경 0) - 이번 세션 블록 S18(UI) + 동반 실행(COMMON.md §3): 이 세션이 고친 것 = ScreenMap 슬롯(옛 partyToast 삭제 · partyVote → requestBanner) · 파티 클라 HUD 전체 · Toast 사용처 ->
		-- S17(UI)(SystemToasts · Toast 창 위 올리기 - 사전 작업 수정 뒤 재실행) · S16(UI)(메뉴바 - PartyList 자리 · ScreenMap 겹침) · S12b(UI)(SocialSelfCheck - requestBanner 슬롯 · 알림) · S12(UI)(PanelFitCheck - 등록 창 · HUD 글씨) · S10(가)(드랍 피드 - blocksDropFeed 슬롯 · FeedLayout) +
		-- 지시서 검증 항목: 27-3(가)(나)(투표 서버 경로) · S12(나)(/gg party selftest 포함 - 파티 서버 경로 회귀) · S09(나)(PartyExpBonus Attribute - 경험치 칩). S04(나)는 계속 제외.
		-- S19(2026-09-20): 사전 작업(클라 전용 - 서버 변경 0) - 직업 표시 이름 개명(ClassData.displayName) · 파티 목록 직업색 + 축약형 직업 이름(PartyListView · PartyList) · Toast 중요 등급 창 위 올리기(Toast · SystemToasts) · I 키 조사.
		-- 본 작업(InventoryUI 파티 탭 분할)은 옮길 대상이 없어 코드 변경 0(PRD 20.105). 동반 실행(COMMON.md §3): 이 세션이 고친 클라 모듈을 쓰는 옛 클라 점검만 -
		-- S18(UI)(PartyHudCheck - 목록 뷰 · 직업 이름) · S17(UI)(SystemToasts - Toast 등급 · 창 위 대역) · S16(UI)(메뉴바 · Toast TC) · S12b(UI)(SocialSelfCheck - Toast TC · 창 글씨 기준선) · S12(UI)(PanelFitCheck - 글씨 기준선) · S10(가)(DropFeed - Toast TR).
		-- 서버 (나) 블록(27-3 · S12(나) · S09(나))은 서버 변경이 없어 뺀다. S04(나)는 계속 제외.
		-- 주의(S19 실측): 서버 (나) 블록(특히 S12(나) - 견습을 잠시 켰다가 블록 끝에서 복원)을 도중에 Play를 멈추면 개발 계정의 견습 상태가 저장 프로필에 남는다(DevTools 스냅샷은 tutorial을 백업하지 않는다) -
		--   그러면 S12(UI) 스테이지 선택 · S18(UI) 배너 겹침 · S12(나) [0](파티 보스 스폰)이 X로 바뀐다. 복구: Play에서 `/gg tutorial off` → `/gg save unlock` → Play 정지.
		-- S19b(2026-09-21): 보스 체력바 화면 UI(A) · 파티 연결 끊김 유예(B) · 수동 Play 모드 + 검증용 저장 분리(사전 작업). 이번 세션 블록 S19b(가)(PartyState 유예 - 스탠드인) · S19b(나)(실제 보스 · 파티) · S19b(UI)(BossBarCheck).
		-- 동반 실행(COMMON.md §3): 이 세션이 고친 모듈을 쓰는 옛 블록 - PartyState · PartyCrossServer · PartyConfig(27-3 투표 · S09 경험치 인원 · S10 드랍 알림 · S12 견습 파티 · S12b 소셜 · S13 · S13b 파티 경로 · 29-5(나)의 파티 보스),
		--   MonsterSpawner(updateHpLabel · 보스 스폰) · BossEncounter(보스전 번호 Attribute · 스폰 · 이탈) = 29-1(보스 뼈대 · 수명) · S01(나)(보스 처치 경로) · S11(나) · S14(나)(보스 스폰) + 클라 UI(PartyListView · Party · ScreenMap · UiSelfCheck) = S18(UI) · S12b(UI) · S12(UI) · S10(가).
		--   SaveSystem(검증용 키)은 모든 서버 (나) 블록이 실제 프로필을 읽고 쓰므로 위 서버 (나) 블록 전부가 그 경로를 지난다. S04(나)는 계속 제외.
		-- S20(2026-09-21) 사전 작업: I → B 단축키(PanelRegistry · MenuBar 점검 · TutorialData) · 파티 복귀 팝업 문구 + 카운트다운(PartyCrossServer · PartyRequests · RequestBanner · PartyAway) · 요청 배너 화면 안전 영역 · Theme.textSizeFor · buttonHeightFor.
		--   이번 세션 블록 S20(UI)(RequestBannerCheck) + 동반 실행(COMMON.md §3): 고친 모듈을 쓰는 옛 블록 = S19b(가)(나)(UI)(PartyState · PartyCrossServer · 파티 목록) · S18(UI)(RequestBanner를 직접 쓰는 PartyHudCheck) · S17(UI) · S16(UI)(MenuBar 표 점검 - 단축키 B) ·
		--   S15(UI) · S12b(UI) · S12(UI)(Theme 글씨 · 버튼 높이를 쓰는 HUD · 패널 점검) · S10(가)(ScreenMap · 토스트). S04(나)는 계속 제외.
		-- S20b(2026-09-21) 사전 작업(클라 전용): 직업 선택창 fitToScreen + 스크롤(ClassSelectUI) · 요청 배너 첫 줄 보호 + 탭 펼침(RequestBanner · PartyRequests · PartyAway).
		--   이번 세션 블록 S20(UI)(RequestBannerCheck에 ⑤ ⑥ ⑦ 추가) + 동반 실행: RequestBanner를 직접 쓰는 S18(UI)(PartyHudCheck) · PartyAway를 쓰는 S19b(UI)(BossBarCheck). 본 작업(GemTab 이동 · 장비창 재구성) 때 다시 갈아 끼운다.
		-- S20b ① 보석 탭 이동(InventoryUI → panels/Inventory/GemTab · 클라 전용): 이번 세션 블록 S20(UI)(GemTabCheck 추가) + 동반 실행: InventoryUI를 여는 · 재는 옛 클라 점검 - S12b(UI)(장비창 글씨 · 탭 줄) · S12(UI)(패널 전수 fit) · S16(UI)(메뉴바 B 키 → 가방).
		-- S20b ② 장비창 재구성(InventoryUI를 Store · Layout · Shell · GearTab · BagTab · BulkSell · DetailSheet · GemTab으로 분할 + UIScale 제거 + 폰 배치): 같은 블록 + InventoryLayoutCheck(S20(UI)에 추가). 동반 실행은 위와 같다.
		-- S20c(2026-09-21) 보석 동선 · 홈 표현 · 장착 입력(GemTab 재구성 · GemActions · GemEquipResult · Toast notice 등급): 이번 세션 블록 S20c(가)(Gem.autoSlot · socketBlockReason · displayOrder 순수 함수) ·
		--   S20c(나)(GemEquip 이유 코드 · 교체 규칙 · 미리 판정 = 서버 30조합) · S20c(UI)(GemFlowCheck - 홈 3상태 · 정렬 · NEW · 강화대 상태 · 폰 치수) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈을 쓰는 옛 블록 -
		--   26-2 · 26-3(PlayerProfile.equipGem · 보석 옵션 - GemServer가 GemEquip을 거치도록 바뀜 · Gem 모듈 함수 추가) · S20(UI)(GemTabCheck · InventoryLayoutCheck - 보석 탭 · 장비창 재구성 위에서 다시 앉음) · S12b(UI)(장비창 글씨) · S12(UI)(패널 전수 fit) ·
		--   S16(UI)(메뉴바 B 키 → 가방 · Toast TC) · S17(UI)(Toast.grades에 notice 추가 - SystemToasts 등급 점검). S04(나)는 계속 제외.
		-- S20d(2026-09-21) 장비 빠른 장착(PC 더블클릭 · 우클릭 · 폰 [장착] / [해제] 버튼) · 요청 중 입력 잠금 · EquipResult · shared/Equip · 보석 자동 장착 미리보기(Gem.replacePreview · GemReplaceTip) ·
		--   상세 시트의 버튼 위 한 줄 + 폰 두 줄 시트 높이 140 → 158: 이번 세션 블록 S20d(가)(Equip · Gem.replacePreview 순수 함수) · S20d(나)(ItemEquip 이유 코드 · 교체 · 가방 가득 참 · 미리 판정 = 서버) ·
		--   S20d(UI)(ItemFlowCheck - 버튼 · 이유 한 줄 · 더블클릭 판정기 · 폰 치수) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈을 쓰는 옛 블록 - PlayerProfile.equipItem · unequipItem을 쓰는 블록은 옛 검증에 없다(직접 호출은 InventoryServer뿐) 하지만
		--   PlayerProfile을 통째로 쓰는 26-2 · 26-3(장비 옵션 · 보석) + 장비창을 여는 옛 점검 = S20c(UI)(GemActions.bounce 분리 · GemBag · 호버 툴팁) · S20c(가)(나)(Gem 모듈 함수 추가) · S20(UI)(GemTabCheck · InventoryLayoutCheck - 시트 높이) ·
		--   S12b(UI)(장비창 글씨) · S12(UI)(패널 전수 fit) · S16(UI)(메뉴바 B → 가방) · S17(UI)(Toast). S04(나)는 계속 제외.
		-- S20e 사전 작업(2026-09-21): 가방 칸 수 서버 전달(InventorySync · Store · BagTab · ItemActions) - 이번 블록 S20d(나)(스냅샷 slots) · S20d(UI)(bagSlots · 칸 수 24 점검) + 아래 S20d 동반 그대로.
		-- S20e(2026-09-22) 보석상인 NPC + 보석 장착 제한 해제(GemEquip far 제거 · GemWorkshop · GemMerchantAccess · 보석 공방 station · 안내 줄 · [위치 안내] · SAVE_VERSION 30 hints): 이번 세션 블록 S20e(가)(자리 판정 · 배치 · 저장 이관) ·
		--   S20e(나)(반경 밖 거절 · 이유 코드 · 플래그 · DataStore 왕복) · S20e(UI)(GemWorkshopCheck - 공방 창 · 마커 · 토스트 · 실제 요청 거절 · station 상호 닫힘 · 폰 치수) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈을 쓰는 옛 블록 =
		--   S20c(가)(나)(UI)(GemEquip · GemActions · GemTab · GemHeader · GemSlotRows - S20c(나)는 far 항목이 "어디서나 성공"으로 바뀌었다) · S20d(UI)(GemTab 미리보기 · DetailSheet) · S20(UI)(GemTabCheck · 장비창) · S12b(UI)(장비창 글씨) ·
		--   S12(UI)(PanelFitCheck - 새 station이 등록 창 전수에 들어간다) · S16(UI) · S17(UI)(Toast) · 26-2 · 26-3(PlayerProfile 옵션 · 리롤) + 저장 구조(SAVE_VERSION 30 · migrate · isValidProfile)를 쓰는 이관 블록 = S02(가) · S03(가) · S04(가) · S05(가) · S05b(가) · S11(가). S04(나)는 계속 제외.
		-- S21-0(2026-09-23): 수치 안전장치(A1 NumberFormat · A2 Sanitize · A3 SaveSystem · A4 safeStageCap · A6 BalanceSim) +
		-- 판매·분해 확인창(B, 클라 전용) - 이번 세션 블록 S21-0(가)(나) + 동반 실행(COMMON.md §3): 이 세션이 고친 모듈(PlayerCombat.getAttack·getDefense ·
		-- PlayerDamage.computeHitDamage·applyHit(사실상 applyFinalDamage) · BalanceSim.getSurviveHits · StageServer(안전 상한 추가) · SaveSystem(sanitizeForSave))을 쓰는 옛 블록 =
		-- S13(가)(나)(BalanceDecisionVerify - PlayerCombat·BalanceSim 앵커 DPS) · S13b(가)(나)(ShieldVerify - PlayerDamage·PlayerCombat·BalanceSim 쉴드 경로) ·
		-- 29-1(BossMechanicsVerify - PlayerDamage.computeHitDamage 직접 호출) · 27-4(가)(나)(StageServer 파이프라인) · SaveSystem 이관 체인(S02(가)·S03(가)·S04(가)·S05(가)·S05b(가)·S11(가)).
		-- P0(2026-09-23): 경제 시뮬 도구(EconSim · EconSimTables · EconSimReport · EconSimVerify · EconSimConfig + /gg econ) - 게임 코드 무변경(새 모듈만 추가, DevTools는 명령 · 블록 연결만).
		-- 이번 블록 P0(가). 동반 실행 없음: 이 단계가 고친 게임 모듈이 없다(새 모듈이 게임 모듈을 읽기만 한다 - what-if 덮어쓰기는 양보 없는 구간 안에서 되돌린다).
		-- P2(2026-09-23): 경제 · 성장 · 보석 · 태초 · 치유사 · 파티 경험치(docs/phase/P2-log.md) - 이번 블록 P2(가) · P2(나) + 동반 실행(COMMON.md §3 - 이 단계가 고친 모듈을 require하는 옛 블록, grep):
		--   P0(가)(EconSim 전체) · S01(가)(나)(Loot · CombatResolution · 변환권 가격 · CharacterLevel) · S03(가)(나) · S04(가) · S05(가)(나)(Enhance.getCost · 방지권 가격 = GoldCost) · S05b(가)(나)(Enhance · Loot) ·
		--   S08(가)(나)(EnhanceService · 준비 골드) · S09(가)(나)(파티 경험치 - 조건부 보너스) · S10(가)(나)(드랍 · 환생) · S11(가)(나)(보스 드랍 미리보기 · Enhance) · S12(나)(처치 경험치 × 파티 보너스) ·
		--   S12b(가)(나)(환생 필요 레벨 · 강화) · S13(가)(나) · S13b(가)(나)(치유사 atk · 딜링모드 배율 · HealCast) · S19b(가)(나)(PartyState) · S20e(가)(나)(환생 · 변환권 가격) · S21-0(가)(나)(NumberFormat) · 26-2 · 26-3(옵션 levelFactor).
		--   뺀 것: 보스 블록 29-x(ClassData를 읽지만 치유사를 안 쓴다 - grep 0) · S04(나)(exclude 그대로).
		-- P2.5a(2026-09-23): 이번 블록 P25a(가)(나) + 동반 실행. 1 · 2회차 Play는 k(1.02) · 강화 · 등급 · 골드 · 생존 앵커가 거의 모든 수치에 들어가 옛 블록 전부를 돌렸다
		-- (docs/phase/P25a-report.md ⑨). 3회차(리뷰 반영 - PlayerCombat.getInvestmentScale 하한 · EnhanceVisualData +26 ~ +29 · CharacterLevel NaN)는 그 모듈을 쓰는 블록만.
		-- P2.5b(2026-09-23): 이번 블록 P25b(가)(나)(UI) + 동반 실행(COMMON.md §3 - 이 단계가 고친 모듈을 쓰는 옛 블록, grep):
		--   PlayerCombat.getAttack(인자 추가) · BalanceSim.buildLoadout · EconSim/Report → P0(가) · P2(가)(나) · P25a(가)(나) · S13(가)(나) · S13b(가)(나) · S21-0(가)(나)
		--   PlayerProfile(계승 · 가루 · 재련 · 마일스톤 · refreshMaxHp · addCharacterExp) · SaveSystem v31 · v32 → 26-2 · 26-3 · S09(가)(나)(경험치 지급) · S03(가)(나) · 이관 체인 S02(가) · S03(가) · S04(가) · S05(가) · S05b(가) · S11(가)
		--   GemServer · GemWorkshop(변환권 = 골드 + 가루) · GemMerchantVerify → S20e(가)(나)(UI) · 보석 장착 경로 → S20c(가)(나)(UI)
		--   DetailSheet · GearTab · 장비창(클라) → S20d(가)(나)(UI) · S20(UI) · S12(UI) · S12b(UI). S04(나)는 계속 제외.
		-- P3a(2026-09-24): 이번 블록 P3a(가) · (나) · (나C) · (D) + 동반(COMMON §3 - 바꾼 모듈이 사실상 전 블록에 걸린다: PlayerProfile(진도 · 기록 제외 표시) ·
		-- SaveSystem v34 · CombatResolution(진도 판정) · BossEncounter · BossPatterns · BossData(킷 원형 재배치) · BossSkillMath · BossSim · WorldConfig(원형 아레나) ·
		-- ZoneBounds · BossGimmicks · 전역 기믹 클라 → grep 결과 PlayerProfile을 쓰는 블록만 28개 → "넓은 쪽"으로 P2.5c와 같은 전 블록). regression 스위치는 그대로 false.
		-- P3b(2026-09-24): 순위 창(L2) · 장비 보기 토글 · 비교 · 인벤토리 토글 상세 · 스킬 툴팁. 이번 블록 P3b(가) · P3b(나) · P3b(UI) + 동반(COMMON §3 - 바꾼 모듈을 쓰는 옛 블록, grep):
		--   Leaderboard(이름 · 내 줄 · 가짜 채우기) → P3a(나) · SkillServer · HealCast(SkillStats로 식 이동) → S13(가)(나) · S13b(가)(나) · P25a(가)(나) ·
		--   Inspect(칸 펼침 · 비교) → S12b(UI) · 인벤토리(BagTab · GearTab · GemTab · DetailSheet 토글 · 굴림) → S20(UI) · S20c(UI) · S20d(UI) · S20e(UI) · P25b(UI) ·
		--   ScreenMap(새 슬롯) · 새 창 2개 → S12(UI)(창 전수 화면 안 · 글씨) · S16(UI) · S18(UI) · S19b(UI) · S10(가)(슬롯 겹침). regression 스위치는 그대로 false.
		-- P3c: 이번 블록 P3c(가)(나) + 동반(COMMON §3 - 바꾼 모듈이 사실상 전 블록에 걸린다: BossPatterns · BossData · BossSkillMath · BossSim(보스 블록 전부) ·
		-- BossArenaMap(Data) · BossEncounter(P3a 맵 · 29-x) · SaveSystem v35(이관을 부르는 S01 · S02 · S03 · S05b · S11 · S20e 블록) · PlayerProfile(경험치 배수 · 보석 판매 - 전 블록) ·
		-- CharacterLevel(P25a · P25c · S12) · Enhance · EnhanceConfig(S03 · S04 · S05 · P25a · P25c) · EconSim(P0 · P2 · P25*) · Leaderboard(P3a(나) · P3b) · 가방 상세 · 순위 창(UI 블록)
		-- → "넓은 쪽"으로 P3a와 같은 전 블록 + 29-x(가)(BossSkillMath · BossSim을 직접 잰다) + P3b 3블록(E1 치명 표본 재실행). P3a(D)(장판 실측 약 9분)는 뺀다 - 이번 변경의 판정 자리는
		-- P3c(나) B4(높이별) · A4(추적)가 따로 잰다. regression 스위치는 그대로 false.
		-- P3d: 이번 블록 P3d(가) · P3d(나) · P3d(가E) + 동반(COMMON §3 - 바꾼 모듈을 쓰는 옛 블록, grep): BossPatterns · BossData(onComplete · 구덩이) · BossArenaMap(Data) ·
		-- BossArenaContainment · ArenaLayout · ArenaContainment(보스 블록 전부 - 29-x · S14 · P3a · P3c) · BossMechanics(29-1 ~ 29-5) · PartyConfig(치유사 b - S13 · S13b · S09 · P25a · 파티 경로 S12 · S12b · S19b) ·
		-- EconSim(Report · Config - P0 · P2 · P25*) · Leaderboard(Rules · Config - P3a(나) · P3b(나) · P3c(나)) · SkillTooltipText(P3b(가)(UI)) · 파티 목록(S18(UI) · S19b(UI)) → P3c와 같은 전 블록(넓은 쪽).
		-- P3a(D)(약 9분)는 뺀다 - 판정 자리를 옮기지 않았다(연출만 · 단상 위 판정은 P3d(나) C가 잰다). regression 스위치는 그대로 false.
		current = {
			"P3d(가)", "P3d(나)", "P3d(가E)",
			"P3c(가)", "P3c(나)",
			"P3b(가)", "P3b(나)", "P3b(UI)",
			"P3a(가)", "P3a(나)", "P3a(나C)", "P3a(가C2)",
			"P25c(가)", "P25c(나)",
			"P25b(가)", "P25b(나)", "P25b(UI)", "P25a(가)", "P25a(나)", "P2(가)", "P2(나)", "P0(가)",
			"26-2", "26-3", "27-1(가)", "27-1(나)", "27-3(가)", "27-3(나)", "27-4(가)", "27-4(나)",
			"29-1", "29-2(가)", "29-2(나)", "29-3(가)", "29-3(나)", "29-4(가)", "29-4(나)", "29-5(가)", "29-5(나)",
			"S01(가)", "S01(나)", "S02(가)", "S02(나)", "S03(가)", "S03(나)", "S04(가)", "S05(가)", "S05(나)", "S05b(가)", "S05b(나)",
			"S07(가)", "S08(가)", "S08(나)", "S09(가)", "S09(나)", "S10(가)", "S10(나)", "S11(가)", "S11(나)", "S12(나)", "S12b(가)", "S12b(나)",
			"S13(가)", "S13(나)", "S13b(가)", "S13b(나)", "S14(가)", "S14(나)", "S19b(가)", "S19b(나)",
			"S20c(가)", "S20c(나)", "S20d(가)", "S20d(나)", "S20e(가)", "S20e(나)", "S21-0(가)", "S21-0(나)",
			"S12(UI)", "S12b(UI)", "S15(UI)", "S16(UI)", "S17(UI)", "S18(UI)", "S19b(UI)", "S20(UI)", "S20c(UI)", "S20d(UI)", "S20e(UI)",
		},
	},
}

local armedUntil = ReplicatedStorage:GetAttribute("VerifyArmedUntil")
config.verifyArmed = RunService:IsStudio() and type(armedUntil) == "number" and os.time() < armedUntil
if not config.verifyArmed then
	config.verify.current = {}
	config.verify.regression = false
end

return config
