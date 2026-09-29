# 로컬 서버 하네스 (QUEUE-6h-b R2 · R5)

실제 서버 모듈(roblox/src/server)을 Studio 없이 luau CLI로 불러 가짜 플레이어로 돌린다. 게임 코드에 모의 분기를 넣지 않는다(스텁 = `server_prelude.luau`의 Roblox 타입 · 서비스 대역뿐).

```
python deps.py PlayerProfile,PetService,QuestService,SaveSystem > deps.txt   # 서버 모듈 의존 목록(60개)
LUAU=<luau.exe 경로> PRELUDE=server_prelude.luau EXTRA_SERVER=$(cat deps.txt) ECON_RES=res.txt python build_run.py dupe_test.luau   # 결과 = %TEMP%/res.txt
```
- `dupe_test.luau` = 복사(dupe) 경로 7가지(판매 · 잠금 · 일괄 분해 · 부화 · 받기 · 보상 수령 · 튕김 직전 수령) · `multiplayer_test.luau` = 2 ~ 4인 규칙 10가지(전멸 · 기믹 대상 · 성역 · 기도 · 재접속 · 파티 기여 · 스틸) - 첫 줄에 `Random` 대역(dupe_test 첫 줄)을 붙여 실행.
- luau CLI = https://github.com/luau-lang/luau 릴리스(luau.exe · luau-analyze.exe · luau-compile.exe).
