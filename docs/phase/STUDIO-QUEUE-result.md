# STUDIO-QUEUE 결과 (QUEUE-STUDIO · 2026-10-01)

> 항목 = `docs/phase/STUDIO-QUEUE.md`. 캡처 = `Claude outputs/QUEUE-STUDIO/`. O = 통과 · X = 실패 · 부분 = 일부 확인 · 보류 = 못 함(사유).

| # | 결과 | 근거(로그 한 줄 · 사유) | 캡처 |
|---|---|---|---|
| V1 | O | `R2 10/10`(기대값 갱신 뒤 - 1회차 9/10: v60 메인 퀘스트 번호 이관이 설계) · `S05b(가) 11/11` · `S21-0(가) 14/14` · `6hbF(나) 8/8`(잠금 대기 10.3초 · 개발 계정 v63 왕복) · `S05b(나) 5/5` · `S21-0(나) 5/5` · `[SaveSystem] 모르는 id 보관` 개발 계정 0줄 | - |
| V2 | O | `Q 95/95`(설정 키 기대 10 → 14 갱신 뒤) · `P0(가) 19/19` · `BR1(가) 19/19` · `BR1-2(가) 21/21` · `BR1(나) 66/66`(단독 - 1회차 60/66은 무거운 P0(가)와 같은 시간에 돌아 대공 잡기 6건 X = 검증 간섭) · 12인 보스 step 최대 1,797μs | - |
| V3 | 부분 | 3시드(20260930 · 1 · 2) 990곳: 땅 밖 0 · **고립 꼭대기 제외 낙하 0**(낙하 남은 20 · 14 · 24경로 전부 `safeDescent` 낙하 0 경로가 없는 곳) · 묻힌 점 = 시드 1만 **3**(가운데 점 - 그 조각은 안 그려짐 · 기준 0 X) | - |
| V4 | O | `[forge-game] 종료 저장: 전부 끝 · 1.0초` | - |
| A1-1 | 부분 | ① ② 대기열 1건 → `[B2] 선물함 … 1건 옮김` → `[B2] 선물 받기 … sparkleShard 5` O · ③ 재접속 재지급 방지 = **Studio에서 재현 불가**(수동 Play는 Play마다 `_manual` 키를 지우고 실제 프로필로 다시 시드 → 받은 id 기록이 사라져 같은 선물이 다시 들어옴 - 라이브와 다른 Studio 구조) → 하네스 `monetize 39/39`(A1 5건) 근거 · 대기열 키 정리함 | - |
| A2-1 | O | ① `srv.weekly.blocked.combat` "전투 중이에요…" ② `casting_already` "이동 집중 중에는…" ③ `in_boss` "보스전 중에는…" ④ 이번 주 보스(수정 여왕) 등장 · 영어 ① "You're in a fight. Try again soon." 한 줄 | `A2-1_weekly_combat_ko.png` · `_en.png` |
| A2-2 | 보류 | 개발 계정이 찾은 체크포인트 0개라 거절 순서(미발견 → 전투)상 시험 불가. 같은 `Travel.busyReason`을 A2-1 ①이 확인 | - |
| A3-1 | 부분 | 실제 프로필(Edit)에 옵션 `QA5_gone` 장비 1개 → 로드 성공 · `모르는 id 보관: … 옮김 1(item:option:QA5_gone)` · 가방 스냅샷 19(그 장비 없음) O · 이름표 색 · 배지 = 개발 계정 패스 없음(보류) · 실제 프로필 되돌림(가방 19 · savedAt · v39 원래 값) · **중 발견: 접속 직후 가방 0 / 35 버그 → 수정(3b9d625)** | `A3_bag`(0/35 재현) |
| B-1 | O | `ArtStyleV1Force = nil` · `ArtStyleV1 = true` · `카툰 스타일 artV1` | - |
| B-2 | O | `ArtStyleV1Force = false` → `ArtStyleV1 = false` · `카툰 스타일 base` → 끝나고 nil | - |
| C-1 | O | 모션 하네스: `tridentThrow(charge)` · `mirrorDash(charge)` · `charge(charge)` 튐 0 · 접촉 − 판정 0.000초 · 전체 튐 0 | `C-1_abyssal_lord.png` · `C-1_crystal_queen.png` · `C-1_section_guardian.png` |
| C-2 | O(캡처 보류) | 나무 정거장(높이 364)에서 활강: `이동 보정 … 합법 속도` **0줄** · 활강 중 초당 약 5 하강(395 → 382) · 거품 캡처는 자동 입력으로 활강 재진입이 불안정해 보류 | - |
| C-3 | 생략 | 영어 자체 점검을 도는 검증 블록이 VerifyOnly 묶음에 없음(지시 "없으면 생략") | - |
| C-4 | O | 게시판 = `FORGE2026 · 출시 기념(~2026.12.31)` 한 줄(LIKES1K 숨김) · 영어 = `FORGE2026 · Launch gift (until 2026.12.31)` | - |
| C-5 | 보류 | `workspace.PlayerCharacterDestroyBehavior`가 이 Studio(0.740.19)에서 스크립트로 안 읽힘(없음 · 숨김) → 사용자 속성 창 확인 | - |
| D-1 | 보류 | 시간 | - |
| D-2 | 보류 | 자동 입력 활강 재진입 불안정(C-2) | - |
| D-3 | 보류 | 체감(사용자) | - |
| D-4 | O | `파티 결성: #2` · `파티 코드 발급: #2 = WJAE5Z` · service_unavailable 없음 | - |
| D-5 | 부분 | 보스 15 처치(bossdmg 0.995 + 평타): 마지막 피격 13:36:27.109 → 처치 27.679 뒤 보스 공격 0 O · 저장 줄 = 개발 명령 백업 중 저장 차단(설계)이라 관찰 불가 → 하네스 `save 58/58` | - |
| D-6 · D-7 | 하네스 | `attack 7/7`(사망 뒤 평타 · 스킬 거절 · 채널 틱 사망 종료) | - |
| D-8 | O | `/gg rift off` → `RiftForce = false` · `RiftActive = false` | - |
| D-9 | O | 진입 → 1초 뒤 재진입(둘 다 첫 조우 3초): 재진입 뒤 `BossIntroLock` 0.25초 표본 `111111111111` - 2.88초까지 유지(옛 타이머가 풀었을 2.0초를 넘김) | - |
| D-10 | 보류 | 시간 | - |
| D-11 | 하네스 | 개발 계정 골드로 1분 연타 불가 · `save_launch` 최악 1분 쓰기 144(ImmediateSave 창) | - |
| D-12 | O | board(personal · class:greatsword · party) · me · hall · card(`u900000001`) 전부 `ok = true`(`/gg lb fake`) | - |
| D-13 | 보류 | 시간 | - |
| P-1 | O | 12인 Heartbeat 1.12ms(알파 1.05) · 24인 1.77ms | `docs/perf/queue-studio-perf.md` |
| P-2 | O | 보스 4인 6종 0.57 ~ 1.13ms · 원격 수신 1.0/초 · 송신 최대 12.3kbps | 같음 |
| P-3 | 부분 | 조치 2(구슬 광원 · 무한거리 이름표) - 보스전 광원 31 → 7 · 렌더 CPU 7.62 → 4.39 · GPU 8.87 → 2.69ms · 나머지 3개는 측정만 | 같음 |
| P-4 | 사용자 | `docs/phase/perf-manual-test.md` | - |
| S-1 | 부분 | 9화면(허브 · 사냥터 · 보스 · 가방(800 × 302 강제) · 도감 · 퀘스트 · 지도 · 상점 · 설정) 842 × 534 터치 · 화면 밖 0 · 44 미만 = 설정 34(고침 06777b1) · 허브 귀환 40(Studio 강제 판정 차이) · 겹침 = 아래 알려진 버그 2 · 3 · 6 | `S-1_*_phone.png` |
| S-2 | O(체감 사용자) | 아레나 4종 전경 - 테두리 화로 = 그릇 + 빛 | `S-2_brazier_{frost,abyssal,crystal,storm}.png` |
| S-3 | O | 개발 계정 이름 · GUI 없음 · 글자 있음/없음 | `S-3_thumb_{A_transcend,B_codex,C_hub}.png` · `launch/thumb_*` |
| S-4 | O | 사용자 결정 0-4대로 D안: Blender판 + 게임 안 촬영판 | `docs/release/icons/game_icon_blender_D.png` · `game_icon_capture_D.png` · `S-4_icon_D_capture.png` |
| S-5 | 부분 | 영어: 캐릭터(Rogue) · 직업 선택(Swordsman · Rogue · Archer · Healer) · 가방 · 보석 · 파티 · 파티 게시판(Anyone · DPS · Healer) · 순위 · 구역 선택 띠 · 기믹 줄 · 출석 · 토스트 · 게시판 / 상점 · 퀘스트 · 도움말 영어는 미촬영 | `S-5_*_en_pc.png` |
| F(상위 30) | 부분 | 자동 점검(`TextFits = false`) + 캡처: 2 · 6 · 8 · 10 · 12 · 16 · 18 O / 넘침 발견 = 순위 칩 "Swordsman"(고침) · 준비 중 "Paladin (Squeaky Hammer) · Coming Soon"(고침) · 보상 띠 Retry 줄 "…" 잘림(기존) · SHIFT 키 표시 44 × 16 · 출석 7일차 금액 32 × 28 / 나머지 항목은 그 상태(받은 뒤 · 덫 · 계승 등)를 못 만들어 보류 | `F02_*` · `F10_*` · `F18_*` |
| R-1 · R-2 | 사용자 | 2번째 계정 · 아바타 배율 계정 필요 | - |
| R-3 | 부분 | 땅 치기 전조(두 주먹 + 빨간 원) 장면 · 충격 순간은 캡처 지연(3 ~ 4초)으로 못 잡음 → 체감 사용자 | `R-3_slam.png` |
