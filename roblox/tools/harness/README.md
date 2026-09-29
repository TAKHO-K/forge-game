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
