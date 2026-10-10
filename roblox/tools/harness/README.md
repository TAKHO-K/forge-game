# 로컬 서버 하네스 (QUEUE-6h-b R2 · R5)

실제 서버 모듈(roblox/src/server)을 Studio 없이 luau CLI로 불러 가짜 플레이어로 돌린다. 게임 코드에 모의 분기를 넣지 않는다(스텁 = `server_prelude.luau`의 Roblox 타입 · 서비스 대역뿐).

```
python deps.py PlayerProfile,PetService,QuestService,SaveSystem > deps.txt   # 서버 모듈 의존 목록(60개)
LUAU=<luau.exe 경로> PRELUDE=server_prelude.luau EXTRA_SERVER=$(cat deps.txt) ECON_RES=res.txt python build_run.py dupe_test.luau   # 결과 = %TEMP%/res.txt
```
- `dupe_test.luau` = 복사(dupe) 경로 7가지(판매 · 잠금 · 일괄 분해 · 부화 · 받기 · 보상 수령 · 튕김 직전 수령) · `multiplayer_test.luau` = 2 ~ 4인 규칙 10가지(전멸 · 기믹 대상 · 성역 · 기도 · 재접속 · 파티 기여 · 스틸) - 첫 줄에 `Random` 대역(dupe_test 첫 줄)을 붙여 실행.
- `attack_test.luau` = 공격 하네스 6가지(서버 Remote 핸들러에 잘못된 인자 · 연타 · 위조 표시 - prelude의 Instance.new가 RemoteEvent 핸들러를 `REMOTES[이름]`에 모은다). 의존 = `python deps.py PlayerProfile,PetService,QuestService,SaveSystem,SettingsService,FallServer,InventoryServer.server`
- luau CLI = https://github.com/luau-lang/luau 릴리스(luau.exe · luau-analyze.exe · luau-compile.exe).
- `save_lock_test.luau` = QUEUE-6h-b 후속 안전장치 ① 약한 세션 잠금(판정 · 옮겨 접속 대기 · 안 풀림 상한 · 저장 표식 놓기) · ② 손상 저장 음수 골드 → 0(12가지 - 가짜 DataStore는 테스트 파일이 `game.GetService`를 덮어 넣는다). 의존 = `SaveSystem`.
- `request_gate_test.luau` = 안전장치 ③ 공통 요청 제한(`server/RequestGate` · 데이터 `RequestLimitConfig` - 실제 Remote 핸들러 연타 · 사람별 · Remote별 표 · 충전 · RemoteFunction 넘침 = 마지막 결과, 7가지). 의존 = attack_test 묶음 + `RequestGate`.
- `migrate_curve_test.luau` = QUEUE-B1 결정 14 캐릭터 경험치 곡선 이관 왕복(v30 · v33 · v34 표본 = 옛 곡선 리터럴 · v44 표본 = 126+ 배수 곡선 · 레벨 30 ~ 300 · 경계 · `migrate({})`, 15가지). 의존 = `SaveSystem`.
- `regrow_timing_test.py` = QUEUE-B1 결정 12 재생성 지연 vs 피해 판정(실제 `BossArenaMap.lua` 프레임 장부 코드를 잘라 가짜 Heartbeat로 돌림 + `BossPatterns.lua` 솟기 순서 검사, 8가지). 실행 = `LUAU=<luau.exe> python regrow_timing_test.py`(prelude · 의존 없음).
- `mesh_import_test.luau` = B3 메시 가져오기 검사기(`shared/MeshImportCheck`) - 표 기술자(가짜 가져온 모델)로 항목별 O/X(이름 · 관절 · 삼각형 · 크기/판정 · 팔레트 · 재질, 34가지 - 잡몹 13종 규격 그대로 = 전부 O · 보스 1종 포함). 서버 의존 없음: `LUAU=<luau.exe> PRELUDE=server_prelude.luau ECON_RES=res_mesh.txt python build_run.py mesh_import_test.luau`. 리그 → Blender JSON 뽑기(`../blender/rig_dump.py`)도 이 build_run을 쓴다.
- `monetize_test.luau` = QUEUE-B1 B2 수익화 골격(판매 금지 목록 · 카탈로그 · 영수증 중복 · 저장 실패 재시도 · 프롬프트 · 유료 랜덤 정책 · 치장 조각 구매 · 섞어 장착 · 나무 정거장 조각 · 시즌 패스 · 선물함 · v56 이관 · 가방 패스, 27가지). 의존 = `python deps.py MonetizationService,SaveSystem,InventorySync`. `deps.py`는 이제 저장소 기준 상대 경로(worktree에서도 새 모듈을 찾는다).
- `save_launch_test.luau` = QUEUE-ALL4 C 출시 전 저장 · 예산 감사(실제 `SaveSystem` · `SaveCoordinator` · `ImmediateSave` + 가짜 DataStore(호출 수 · 지연 · 실패 · "써진 뒤 에러" 주입) + **가상 시계 스케줄러**(task.wait/spawn/delay가 실제로 양보 - 동시 저장 · 재시도 대기 · 종료 마감을 초 단위로 잰다)). 이관(v0 · v1 · v12 · v21 · v34 · v44 · v54 표본 · 멱등 · 새 계정) · 손상 복구 · 세션 잠금 · 두 서버 · 실패 처리 · 12명 종료 저장 · 12인 호출 수(58가지). 의존 = `SaveSystem,SaveCoordinator,ImmediateSave,LiveStoreConfig`(SEC-FIX-1 11 - 라이브 경로라 라이브 이름 자리를 읽는다). 결과 해설 = `docs/design/save-audit-launch.md`.
- `id_quarantine_test.luau` = QUEUE-ALL5 A3 모르는 id 보관(`SaveSystem.quarantineUnknownIds` · `shared/IdRegistry`): 아는 id만 = 옮김 0(오탐 없음) · 종류마다 모르는 id(옵션 · 등급 · 부위 · 직업옵션 · 초월 특수 · 박힌/가방 보석 · 재료 · 치장 · 칭호) = 보관 + 로드 가능 · 착용/장착 자리 비움 · 멱등 · 저장 왕복 · id가 다시 생기면 제자리로 · v62 → v63(12가지). 의존 = `SaveSystem`.
- `id_registry_dump.luau` = 지금 저장 id 목록 출력 → `python ../ids/id_registry.py`(등록부 `../ids/id_registry_snapshot.json` 대비 사라진 id = exit 1 · `--write` = 새 id 등록 + `docs/design/id-registry.md` 다시 씀).
- QUEUE-ALL5: `monetize_test` 39가지(A1 선물 재지급 방지 5 추가) · `security_launch_test` 44가지(A2 주간 입장 조건 3 추가) · `save_launch_test`의 "모르는 옵션 id" 기대 = 보관 + 로드 O(옛 = invalid_schema).
- SEC-FIX-1(10-11) 재현 하네스 = `sec_save_test`(1 · 2 · 11 저장) · `sec_shop_test`(3 · 8 결제 · 패스) · `sec_secret_static.py`(4 비밀) · `sec_zone_test`(5 구역) · `sec_move_test`(6 위치) · `sec_econ_test`(7 보석 · 분해) · `sec_log_static.py`(9 로그) · `sec_text_static.py`(10 문구). 옛 코드 실패 확인 = `ECON_SRC=<git archive로 뜬 옛 src>`로 같은 명령(상태 = `docs/phase/SEC-FIX-1-state.md`).
