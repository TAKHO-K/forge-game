# QUEUE-ALL6R 보고서 (QUEUE-ALL6 후속 · 2026-10-02)

입력: 사용자 지시 "[바로 실행] QUEUE-ALL6 후속(R)"(1 ~ 5 - ALL6 보고서 10 · 11절). 상태 = `docs/phase/QUEUE-ALL6R-state.md` · 결과물 = `Claude outputs/QUEUE-ALL6R/`.
시작 확인: rojo serve(34872 연결) · Studio 1개(placeId 106413438976597) · 소스 3개 대조 일치 · DataStore GetAsync OK. 도중 rojo 끊김 → 사용자 재시작 · 재연결 뒤 소스 4개 다시 대조(일치).
진행: 검증 Play 3회 + 수동(캡처) Play 3회 · 로컬 하네스(P0(가) · 깔끔한 골드 · 몹 이름 · 칭호 · run_all 16종) · 리뷰 서브에이전트 1회(경제 · 보안 · 서버 판정 diff).

## 1. 결과 한눈에

| 항목 | 결과 | 핵심 | 커밋 |
|---|---|---|---|
| 1 대시 확인 | 완료(제품 버그 아님) | 2절 | 17f75fdc |
| 2-1 판 털기 25% | 유지(변경 없음) | | |
| 2-2 BR1-4b · M1-2c 로켓 기대값 | 완료 | BR1-4b(가) 7/7 · M1-2c(가) 15/15 · (나) 10/10 | 17f75fdc · f0c6c9a5 |
| 2-3 깔끔한 골드 | 완료(결정 필요 1) | 500 ~ 9,999 = 500 단위 · 1만 이상 앞 두 자리 · 500 미만 = 100 단위 | 51f3f475 |
| 2-4 가격 자리값 | 유지(변경 없음) | | |
| 2-5 할로윈 색 | 완료 | 발자국 = 보라 호박 실루엣 · 주황 = 박쥐 눈 · 공중 작은 호박만 | 870b1cc8 |
| 2-6 하이파이브 자세 | 완료 | `PlayerMotionData.overlay.highFive`(코드 포즈 · 업로드 없음) · 손이 만나는 순간 "짝!" | 66f2de40 |
| 2-7 P0(가) 9번 하한 | 완료 | 하한 2,200h → **P0(가) 19/19**(2,227h · 로컬 하네스) | 2c26a7f4 |
| 2-8 운영 명령 | 완료 | 다른 서버 대상 = MessagingService 내보내기 → 저장 잠금 풀릴 때까지 대기 · 영구 차단 · 초월 회수 = 확인 번호 | 91561a14 |
| 3 서버 완성 문장 → 키 + 인자 | 완료 | 월드 명판 · 강화대 · 제단 · 상인 · 몹 · 드랍 · 명예의 전당 · 도감 알림 · 영어 확인(4절) | 0efb0376 · f0c6c9a5 · 0ef934cb · 22af1396 |
| 4 회귀 표준(로그 오류 집계) | 완료 | `roblox/tools/studio_log_errors.py` · COMMON §5-5 한 줄 | 1ed1f408 |
| 5 캡처 재시도 · 젤리 거품 | 부분 | 박쥐 · 호박 · 로켓 반짝 · 배너(걸어서) · 하이파이브 · 영어 O / 활강 거품 캡처 X(6절) | 81f818bf |

## 2. 대시 원인(1)

- **결론: 제품 버그 아님.** 개발 계정에서 대시가 "안 되던" 것은 수동 Play 접속 때 뜨는 **출석 창(attendanceGui · 딤 = 모달)** 이 열려 있는 동안 `UIManager.isInputBlocked()`가 대시 입력을 막기 때문이다(18-1 [3] "창이 열려 있으면 대시 안 나감" 설계). 처음 잰 값도 같은 이유로 "응답 없음"이었다.
- 창을 닫은 뒤 실측(DashResult · 이동 거리):

| 경우 | 지상 대시 | 공중 대시(Freefall) |
|---|---|---|
| 개발 계정 아바타 · 키보드 Shift | O 30.8 stud | O(점프 → Shift · 쿨다운 다시 걸림) |
| 개발 계정 아바타 · 폰 버튼 경로(SkillSlotPress) | O 30.8 | O 30.8 |
| 기본 아바타(HumanoidDescription.new) | O 30.8 | O 30.8 |
| 할로윈 테마 장착 | O 30.8 | - |

- 애니메이션 권한 오류 `rbxassetid://114302219876492`는 게임 코드에 없는 **개발 계정 아바타 애니메이션**이다(대시 = CFrame 트윈이라 무관). 로블록스 기본 Shift Lock은 서버가 이미 끈다(`DevEnableMouseLock = false`).
- 덤: Studio 검증 훅 `MV1DashHook`이 PlayerGui에 있어 부활하면 사라진다(검증 전용 - 폰 버튼 경로 `SkillSlotPress`는 유지). 제품 영향 없음.

## 3. 결정 반영 세부(2)

- **2-2**: 판 털기 한 사람 날리기를 `BossEnvironment.launchRocket`으로 떼어 판 털기 · 검증이 같은 길을 탄다. M1-2c(가) = 로켓 곡선 표본 · 예외 3.5초 → 되돌림 0 · **예외 없이 같은 곡선 → 되돌림 2**(예외가 실제로 받친다) · (나) = 실제 발 +45.6(설계 48) · 되돌림 0 · BR1-4b(가) = 로켓 시간표 2.5초 · 최고 높이 바닥 + 48(편차 없음) · 반대쪽 착지.
- **2-3**: 예시(`sim/nice_gold_examples.txt` - 퀘스트 지급 경로와 같은 식): 스테이지 1 · 40마리 197 → 200 · 120마리 593 → 500 · 500마리 2,474 → 2,500 / 스테이지 1,000 · 120마리 1,612 → 1,500 · 900마리 12,091 → 12,000 / 스테이지 5,000 · 500마리 366,039 → 370,000. 규칙 하네스 14/14. 흔들림 최대 = 500 ~ 999 구간 33%(750 → 1,000 · 749 → 500) · 1,000 이상 20%. **EconSim(전 프로필 baseline) = 계산 시간 줄 빼고 ALL6과 같음**(퀘스트 · 도감 골드는 모형 밖 - `sim/econsim_R_after.txt`).
- **2-5**: 호박 발자국 = (112, 72, 156) 보라 · 꼭지 짙은 보라 · 박쥐 눈 = 주황 Neon · 박쥐 떼 사이 작은 주황 호박(대시 4번째 · 활강 3번째마다).
- **2-6**: 두 사람 모두 오른팔을 머리 위 앞으로(어깨 160° · 안쪽 10°) · 내 캐릭터만 상대 쪽으로 돌림(위치 그대로) · 0.75초 중 0.29초 = 손이 만나는 순간 효과(머리 위 높이).
- **2-8**: `/ops rollback confirm` - 대상이 이 서버에 없고 저장을 다른 서버가 쥐고 있으면(`SaveSystem.heldElsewhere`) `OpsKick_v1`(검증 무장 = `_verify`) 발행 → 3초마다 다시 읽어 30초 안에 잠금이 풀리면 덮기 · 안 풀리면 **실행 안 함**(늦게 온 그 서버 저장이 되돌리기를 덮어쓰지 않게). `/ops ban <id> perm …` · `/ops revoke <id> t<번호>` = 미리보기 + `/ops … confirm <번호>`(되돌리기와 같은 표 · 5분 · 명령한 사람만). 덤으로 **차단 사유를 바이트로 자르던 것**(한글이 끊기면 UTF-8이 깨짐 - 감사 기록과 같은 종류)을 글자 수로. 절차서 `docs/phase/security-runbook.md` 갱신.

## 4. 서버 완성 문장 → 키 + 인자(3) · 영어 확인

- 공통 입구: `shared/Text.lua` `bindLabel(label, key, args)` · `bindName(label, 데이터 이름)`(서버 - 속성만 붙이고 글은 ko) → `client/WorldTextView`가 `Text.applyLabel`로 내 언어로 **한 번** 다시 쓴다(몹 이름표의 세대 앞말은 GenerationView가 같은 함수를 먼저 부르고 붙인다).
- 바꾼 자리: WorldMap 명판(시설 · 정거장 · 정상 전망대 · 봉인 입구 `{name} ???` · 토벌 관문) · 강화대 · 환생의 제단 · 보석상인 · 몹 이름표(`srv.mob.prefixed` = `{prefix} {name}`) · 드랍 이름표(`srv.drop.plate`) · 명예의 전당 머리글 · 도감 알림(`srv.codex.lineDone` · `got` · `eggFull` - 줄 완성 칭호는 `CodexRules.titleText`로 틀 + 이름 따로).
- 검증: ALL6R(나) **8/8**(월드 글자 48개 en 한글 0 · 몹 이름 28개 en · 키 6종) · 영어 모드(`TextLanguageDev = en`) Play: 클라 월드 글자 33개 한글 0(Forge · Rebirth Altar · Gem Merchant · Root Stop (Lv 10) · Camp · Gate → · Mole Mine ??? · ★ Hall of Fame ★ …) · 도감 보상 알림 "Codex reward: Gold 500 · Enhance Stone 3" · 줄 완성 "Line complete! Title “Legendary Collector”" · 몹 "Moss Slime" · "Weak Moss Slime".
- Play 1에서 찾아 고친 것: 영어 사전 빠짐 11종(강화대 · 제단 · 상인 · 길 표지판 2 · 정거장 문장 5 · 전망대) · Play 2: 도감 칭호 40개는 합친 이름이 사전에 없음 → 알림도 `titleText` 경로로.
- 남은 것(범위 밖 - 보고): 명예의 전당 줄 내용(이름 · 날짜 · 출처) · ProximityPrompt 글(ActionText · ObjectText)은 서버 ko 그대로. `TeleportPad.create`는 부르는 곳이 없음(옛 코드).

## 5. 로그 오류 집계(4 - 이번 Play 1 ~ 3 · `log_errors_play1-3.md`)

| 개수 | 수준 | 출처 | 문장(대표) | 판단 |
|---|---|---|---|---|
| 0 | Error | 게임 | - | 스크립트 에러 없음 |
| 7 | Warning | 게임 | `[forge-game] 이동 보정 · 높이 보정 → 되돌림` | M1-2c(나) "허가 없이 +36" · 순간이동 검증이 일부러 만든 것 |
| 2 | Warning | 게임 | `검토 대기(suspect_hits) 명중 분당 2501` | ALL6(나) F 탐지 시험(의도) |
| 6 | Warning | 게임 | `Infinite yield possible … NestSync · CheckpointFound · BossGateRegistered` | 접속 직후 맵 짓기 전 클라 대기(이전부터 · 뒤에 생김) |
| 18 | Error | 엔진 | AMP · PresetChat 403 · User blocking · local secrets · 에셋 203785492 | Studio · 플랫폼 |
| 469 | Warning | 엔진 | Studio · 플러그인(TM2 · Hello World CLI …) | 무시 |

- 도구: `python roblox/tools/studio_log_errors.py --from-line <Play 전 줄 수>`(기본 = 마지막 Play) · 스크립트 에러는 `Error [FLog::CreatorError]`로 찍혀 "게임"으로 분류된다. COMMON §5-5 한 줄 + `_build.py`로 세션 파일 27개 재생성(그동안 반영 안 된 COMMON 옛 개정도 함께 들어감).

## 6. 캡처(5 - `Claude outputs/QUEUE-ALL6R/`)

| 대상 | 파일 | 결과 |
|---|---|---|
| 할로윈 대시 박쥐 | `halloween_dash_bats_zoom.png` · `bats_grid.png` | 박쥐(작은 V) + 공중 주황 호박 보임 · **박쥐가 화면에서 아주 작다(사용자 확인)** |
| 할로윈 보라 호박 발자국 | `halloween_pumpkin_footsteps.png` | 보라 호박 실루엣 줄 |
| 판 털기 로켓 꼭대기 반짝 | `rocket_twinkle.png` · `rocket_grid.png` | 서버 이벤트 직접 발신(허브) - 오름 → 꼭대기 별 터짐 → 내려옴. 소리는 캡처로 확인 불가 |
| 세부 지역 진입 배너 | `subarea_banner_walk.png` · `banner_grid.png` | **걸어서 경계를 넘겨** "수호자의 석조 평원 · 멧돼지 들판" 2초 배너 |
| 하이파이브 자세 | `highfive_pose_vs_rest.png` | 오른팔 머리 위 + 짝 빛(단일 클라 = 나 ↔ 나로 발신 · 두 사람 실제는 사용자 확인) |
| 영어 화면 | `en_grid.png` | 도감 보상 알림 · 구역 표지 "Stone Plains Gate" |
| 젤리 활강 거품 | (없음) | **캡처 실패** - 키 입력(점프 3 + Shift 길게)으로 활강이 두 번 다 시작되지 않음(이동 단계 덮어쓰기 `MoveTierOverride 5` 뒤에도) · 수치만 바꿈(크기 0.34 → 0.46 · 발광 1 → 0.2 · 진한 민트) |

## 7. 검증

| Play | 블록(VerifyOnly) | 결과 |
|---|---|---|
| 1 | ALL6R(나) · ALL6(나) · M1-2c(가)(나) · BR1-4b(가) | M1-2c(가) 15/15 · BR1-4b(가) 7/7 · ALL6(나) 19/19 · M1-2c(나) 8/10(검증 쪽 타이밍 - 필터로 체인 맨 앞이 되어 **맵 짓기 1.1초 전에 시작** → 맵 대기 추가) · ALL6R(나) 5/7(사전 빠짐 11 · 칭호) |
| 2 | 같음 | M1-2c(나) **10/10** · ALL6(나) 19/19 · ALL6R(나) 7/8(도감 칭호 40개 사전 없음 → titleText) |
| 3 | ALL6R(나) | **8/8** |
| 로컬 | P0(가) 하네스 | **19/19**(9번 2,227h · 기대 2,200 ~ 2,778) |
| 로컬 | run_all 16종 | 전부 통과(OPS 25/25 - 새 6항목 · SEC 45/45 · save 58/58 · 모션 튐 0) |

- 동반 실행 이유: ALL6(나) = 판 털기(`BossEnvironment` 리팩터) · 운영 명령(`OpsServer`) · M1-2c · BR1-4b = 기대값 갱신 대상. P0(가)는 무거운 순수 블록이라 Play 대신 로컬 하네스(같은 `EconSimVerify.runPure`).
- 생략: S19b(나)(몹 NameLabel 있음만 봄 - 영향 없음).

## 8. 재사용한 공통 입구

`Text.get` · 이름 사전(`TextData_names`) · `CodexRules.titleText` · `WeaponVisual.playOverlay`(덧씌움 포즈) · `SaveSystem.heldElsewhere` · `AuditTrail.clip` · 확인 번호 표(되돌리기 것을 일반화) · `DevCommandHook` · `caploop.ps1`.

## 9. 리뷰(서브에이전트 - 경제 · 보안 · 서버 판정 diff)

| 지적 | 판단 | 처리 |
|---|---|---|
| (중간) 영어 사용자의 월드 글자가 접속 순간 ko로 굳음 - Language 속성은 프로필 로드 뒤에 붙는데 "한 번만" 표시가 다시 쓰기를 막음 | **맞음**(Studio는 개발 언어 속성이 가렸다) | 표시 = 적용한 언어 · Language · TextLanguageDev 바뀌면 다시 씀 · 세대 앞말은 `WorldTextPrefix`로 보존 → 수동 Play에서 도중 ko → en 바꾸기 = 19개 전부 영어 · 22af1396 |
| (중간) 되돌린 저장을 재접속한 서버가 덮을 수 있음 | **이미 막혀 있음** - `OpsRollback.execute`가 `savedAt = 지금 · sessionId = ""`로 써서 그 전에 읽은 서버 저장은 기존 stale_session이 거절 | 변경 없음 |
| (중간) 영구 차단 · 초월 회수 확인 실행이 대상 감사 기록에 안 남음("confirm"에서 대상 찾기가 끊김) | 맞음 | 실행 쪽에서 `AuditTrail.note`(ops_ban · ops_revoke) · 22af1396 |
| (낮음) 다른 운영자가 잘못 넣으면 남의 확인 번호가 지워짐 | 맞음 | 주인 확인 뒤에 지움 · 22af1396 |
| (낮음) 저장 읽기 실패를 "놓음"으로 봄 | 뒤의 실행이 같은 읽기 실패로 멈춤(read_failed) - 피해 작음 | 변경 없음(보고) |
| 내보내기 메시지 · niceReward · BossEnvironment 리팩터 · 코덱스 알림 | 문제 없음 | - |

- 리뷰 반영 뒤: 하네스 OPS 25/25 · 수동 Play(언어 바꾸기) 확인. 세대 앞말 경로는 이번 계정 스테이지(46)에 세대가 없어 Play로는 못 봄(코드 경로만).

## 10. 결정 필요(추천값으로 진행 · 바꿀 수 있음)

1. **깔끔한 골드 500 미만**: 지시 "1만 미만 = 500 단위"를 그대로 하면 최소 500이라 도감 칸 보상(잡몹 3 ~ 10마리 몫 = 초반 15 ~ 50골드)이 10 ~ 30배로 불어난다 → **500 미만은 옛 100 단위로 유지**했다. 500 단위를 끝까지(최소 500) 원하면 한 줄(`GoldCost.niceReward`).
2. 500 ~ 999 구간 흔들림 최대 33%(749 → 500 · 750 → 1,000) - 이 구간만 100 단위로 둘지.
3. 운영 되돌리기 대기 상한 30초(안 풀리면 실행 안 함 · 다시 시도) - 값은 `SecurityOpsConfig.rollback.releaseWaitSeconds`.
4. 하이파이브 = 내 캐릭터를 상대 쪽으로 돌림(위치 불변) - 돌리지 않기를 원하면 한 줄.

## 11. 사용자 확인 목록

1. **활강 거품(젤리)**: 이번에 키우고 진하게 바꿨다 - 캡처 실패라 실제 활강으로 확인(`/gg cos equip glideTrail jelly` · 활강 해금 계정).
2. **할로윈 박쥐 크기**: 대시 박쥐가 기본 카메라 거리에서 작다 - 키울지(`ArtV1CosmeticData.themes.halloween.dash.bats.size` 0.9).
3. **하이파이브 두 사람**: 두 계정으로 제안 → 수락 → 마주 보고 손 · 짝(단일 클라 확인은 나 ↔ 나).
4. **로켓 반짝 소리**(rocket_twinkle 심사 통과 뒤) · 실제 심해 군주 아레나 장면.
5. **세부 지역 배너 글씨 크기**: 넓은 띠에 글씨가 작다(`subarea_banner_walk.png`).
6. **영어 화면 전체**: 설정 언어 English로 허브 · 사냥터 명판 · 몹 이름표.
