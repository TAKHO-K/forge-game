# 현재 상태 (STATE) - 매 단계 끝에 갱신

> 단계를 시작할 때 PRD · README 전체 대신 이 파일 + 직전 보고서 + 관련 설계 문서만 읽는다(COMMON §7-1 검증 정책 v2).
> 마지막 갱신: **M1-0 · 2026-09-25** · 직전 보고서 = `docs/phase/M1-0-report.md`

## 1. 게임 한 줄

로블록스 "같은 몬스터, 사람마다 다른 스테이지" 강화 액션 RPG. 코드 = `roblox/src`(Rojo) · 웹 원형(`core/` · `data/`)은 동결. 수치 = `roblox/src/shared/data/`만.

## 2. 지금 있는 것(요약)

| 영역 | 상태 | 문서 |
|---|---|---|
| 전투 · 직업 4종(대검 · 쌍검 · 활 · 치유사) · 스킬 Q/E · 대시 | 동작 | PRD 20.x · `docs/design/skills-RT.md`(R/T 예정) |
| 무한 스테이지 · 보스 6종(5스테이지마다) · 파티 4인 · 기믹 | 동작 - **난이도 재설정 대기(G2b)** | `docs/design/boss-rules.md` |
| 강화 · 방어구 3부위 · 보석 · 계승 · 환생 · 리더보드 | 동작 | PRD · `docs/econ/` |
| 이동 | **M1-0 개편**: 공중 점프 충전 2(+6.12씩) · 공중대시 체공 1회 섞기 · 필드 = 아레나 같은 규칙 · 서버 높이 검증 허용 22.38 | `docs/design/movement-metrics.md` v2 |
| 카메라 | **M1-0**: 기본 = 로블록스 기본 카메라(줌 22 · 10 ~ 60) · 설정 창 "탑다운 시점"(55° · 45 - 이번 접속 동안) · 시점 고정 = 왼쪽 Ctrl / 폰 "고정" 버튼 | 같은 문서 §8 |
| 설정 창 | M1-0에 첫 창(카메라 토글 하나). 저장 · 키 재설정은 **P4-4** | `client/panels/Settings.lua` |
| 저장 | SAVE_VERSION 그대로(M1-0 변경 없음) | `server/SaveSystem.lua` |

## 3. 다음 단계

로드맵 = `docs/phase/roadmap-v2.md`. 이동 · 카메라 기준(M1-0)이 섰으니 **M1 맵 그레이박스**(설계 문서 별도 제공 예정)와 **G2b 보스 난이도**(공중 전제 - boss-rules §2)가 이 수치를 쓴다.

## 4. 결정 필요 (열린 것)

| 출처 | 내용 |
|---|---|
| M1-0 ① | 자유 카메라에서 공격 조준(마우스 방향 · 수평선 위 커서 · 폰) |
| M1-0 ② | 보스 아레나 카메라 최소 각(장판 가독성) |
| M1-0 ③ | 중앙 금지 구역 · ScreenMap은 유효(유지) · 시점 고정 중 HUD 버튼을 못 누름(기본 Shift Lock과 같다 - 그대로 둘지) |
| M1-0 ④ | 필드 몬스터 공중 회피 - 몬스터 공격 판정 방식 |
| G2a 1 | 이속 상한을 넘는 신발 몫 처리(지금 = 이동만 ×1.5에서 멈춤) |
| G2a 2 | ~~점프력 옵션 아레나 규칙~~ → M1-0에서 "아레나도 적용"으로 닫음(확인만) |

## 5. 알려진 X(재조사 안 함 - 목록만)

- G1-1(UI) 고리 타이밍 · 29-1 첫 기믹 +0.35초(서버 시작 부하) · S12b(UI) · S16(UI) · S19b(UI) · P25b(UI)(계정 가방 상태) - G1-5 / G2a 전 블록 Play와 같은 계열.
- G1-0(나) 12아레나 한 프레임 합 2.0ms 경계 흔들림(성능 표본).
- S04(나) 멈춤 - `verify.exclude`로 회귀 제외(원인 미확정).

## 6. 검증 방법(요약 - 상세 COMMON §3 · §5 · §7-1)

- Play 전 edit 모드: `ReplicatedStorage:SetAttribute("VerifyArmedUntil", os.time() + 1800)` + `SetAttribute("VerifyOnly", "블록 id, …")` → Play → 로그 파일 폴링(`===… 검증 끝…===`) → 정지 → 둘 다 `nil`.
- 로컬: 스크래치패드 `luau/`(luau-compile · luau-analyze) + `g2a_mk.py` 하네스(순수 (가) 블록 실행) - 세션마다 직전 세션 스크래치패드에서 복사.
- 클라 동작(점프 · 카메라 · 모션)은 수동 Play에서 MCP `user_keyboard_input` + 클라 `execute_luau` 기록기로 잰다. AlwaysOnTop 빌보드는 캡처에 안 나온다(끈 사본으로 확인).
- 이 place의 아바타는 **관절 업그레이드(AnimationConstraint)** - Motor6D가 없다. 관절을 만지는 코드는 둘 다 처리한다(`client/AirMotion.lua`).
