# QUEUE-ALL5 보고서 (Studio 없이 보완 · 검증 · 2026-10-01)

입력: 사용자 지시 "[바로 실행] [속도 우선 모드] QUEUE-ALL5"(A ~ H · Studio · Rojo 연결 없음). 결과물 = `Claude outputs/QUEUE-ALL5/` · Studio 대기열 = `docs/phase/STUDIO-QUEUE.md`.
진행: A · B · C · G · H는 본 세션, C(삼지창) · D①(클라) · D②(서버) · E(아이콘) · F(영어 · 문구)는 서브에이전트 worktree 병렬 → master에 cherry-pick / fast-forward(충돌 0). 저장 · 보안 · 판정 변경은 리뷰 서브에이전트 2회(A1 ~ A3 · D②).
Studio MCP · Play · 캡처 **사용 0회**. 업로드 0회(아이콘은 파일만).

## 1. 결과 한눈에

| 블록 | 결과 | 핵심 | 커밋 |
|---|---|---|---|
| A1 선물함 재지급 방지 | 완료 | SAVE 62 `mailbox.claimedIds`(최근 200) · 재접속 · 서버 이동 · 동시 받기 하네스 | 124d574 |
| A2 주간 도전 입장 조건 | 완료 | `Travel.busyReason` = 체크포인트와 같은 규칙(보스전 · 전투 8초 · 집중 중) + 견습 · 토스트 ko/en 5 | c572eaf |
| A3 id 삭제 금지 + 안전 로드 | 완료 | SAVE 63 `quarantine` 보관 칸 · `shared/IdRegistry` 97개 · 등록부 + 검사 도구 · 리뷰 지적(이름표 오탐) 반영 | c8e7dd1 · dfa617d |
| A4 결정 13건 정리 | 완료 | 4절 표 | - |
| B 출시 설정 | 완료 | `ArtStyleV1Data.enabled = true` · 비상 끔 경로 유지 · 서버 16 / 12 확정 표시 | e4db5d3 |
| C 알려진 버그 | 완료(오프라인 몫) | 삼지창 튐 1 → 0 · 활강 공중 고정 원인 찾아 수정 · 자체 점검 한국어 비교 · 게시판 코드 만료 UTC | b3f1222 · b4a2e2a · 96a9516 |
| D 코드 점검 | 완료 | 컴파일 오류 0(972파일) · 클라 4 · 서버 약 26 + 넘겨받은 2 + 리뷰 2 수정 · pcall 누락 0 | c78bc87 · 55a8912 ~ e8b4f46 · 713391b · (마지막 커밋) |
| E 출시 에셋 | 완료(업로드는 사용자) | 상품 8 · 패스 5 아이콘 + 게임 아이콘 Blender판 3 | cdbc9cd · d58a3e2 · 49fa129 |
| F 영어 · 문구 | 완료 | en 103키 손질 · 용어 확정 · 넘침 위험 v2(상위 30) · 백과사전 · 게시판 첫 글 · 패치 노트 · 코드 초안 | 880f86e · 68f23f3 |
| G 오프라인 회귀 | 완료 | 로컬 하네스 15종 전부 통과 · EconSim = ALL4와 같음 · BossSim 결정 1 · 초반 완화 유지 · 모션 튐 0 | 713391b(run_all) |
| H STUDIO-QUEUE | 완료 | 9절 · 항목마다 명령 · 기준 · 캡처 경로 | 815ceeb |

## 2. A 저장 · 보안 결정 반영

| # | 한 일 | 근거(하네스) |
|---|---|---|
| A1 | 선물마다 GUID(기존) · **받은 id 목록 `mailbox.claimedIds`**(문자열 배열 · 최근 `MonetizationData.gifts.claimedIdsKeep` = 200 · 넘치면 오래된 것부터 버림 - 대기열에 남은 같은 id는 옮길 때마다 지우기를 다시 시도하므로 200개 밖으로 밀려날 때까지 남을 수 없다). 대기열 → 선물함 옮길 때 받은 id · 선물함에 있는 id는 건너뛰고 대기열에서는 지움. 받기 = 지급 **전에** 표시(같은 id 두 줄 · 연타 · all 한 번). SAVE 61 → 62 · migrate · `getMonetizationState` 정규화 · 백업(mailbox 통째) | `monetize_test` 39/39(새 5: 재접속 · 서버 이동(왕복 저장 사본을 다른 Player가 읽음) · 동시 받기 · 정리 규칙 · v61 → v62) |
| A2 | `Travel.busyReason(player)` 새 공용 규칙 = `in_boss`(encounter 있음 - 아레나 안 · 처치 뒤 머무름 포함) · `combat`(최근 `combatLockSeconds` 8초 안 **피격 또는 적 명중** - 명중 = `PartyState` 활동 기록 · `CombatResolution.resolveHit`) · `casting_already`(귀환 · 체크포인트 집중). 체크포인트 순간이동이 이 함수를 쓰고(명중도 전투로 - 데이터 주석 "피해를 주거나 받았으면"과 맞춤), 주간 도전 입장(`WeeklyChallengeService.entryBlocked`) = 견습 + 같은 함수(서버). 토스트 = `srv.weekly.blocked.<이유>` ko/en 5키(`Text.getFor`) | `security_launch_test` 44/44(새 3: 아레나 · 피격 · 8초 뒤 · 명중 · 집중 · 견습 · 평소 스폰 1 · 문구 ko/en · en 40자 · 체크포인트 명중) |
| A3 | (가) **id 등록부**: `shared/IdRegistry`(옵션 16 · 재료 2 · 등급 8 · 부위 3 · 세트 구역 6 · 직업옵션 4 · 초월 특수 3 · 치장 테마 4 · 글라이더 4 · 칭호 47 = 97) · 스냅숏 `roblox/tools/ids/id_registry_snapshot.json` + `docs/design/id-registry.md`(규칙 + 표 · 자동 생성) · 검사 `python roblox/tools/ids/id_registry.py`(사라진 id = exit 1 · `--write` = 새 id 등록 - 지우지 않음). (나) **로드 때 모르는 id = 보관 칸** `profile.quarantine`(SAVE 63): 장비(옵션 · 등급 · 부위 · 직업옵션 · 초월 특수) · 보석 · 재료 · 치장 · 칭호 → 보관 + `warn` + 통계 `SaveQuarantined` · 착용 자리 비움 · 장착 치장 · 고른 칭호는 기본값(선택값 - 보관 안 함) · 같은 id가 데이터에 다시 생기면 다음 로드 때 제자리(착용 → 가방). 세트 구역은 모르면 "세트 아님"으로 동작해 보관 안 함 | `id_quarantine_test` 13/13(오탐 0 · 종류별 · 이름표 색/배지 유지 · 멱등 · 왕복 · 되돌림 · v62 → v63) · `save_launch_test` "모르는 옵션 id" 기대 = 보관 + 로드 O(옛 invalid_schema) · 검사 도구 음성 시험(가짜로 지운 id → 실패) |
| 리뷰 | A1 ~ A3 리뷰 서브에이전트 1회: **중간 ~ 높음 1** = `cosmetics.equipped`의 이름표 색 · 배지(게임패스 선택값)를 테마 id로 보고 접속마다 지움 → 세트 칸 · 글라이더만 보게 고침 · 낮음 3 = 통계 부풀림(선택 해제를 보관 수에서 분리 · 0이면 안 보냄) · DevTools 옛 스냅숏 복원 = 보관 칸 비움 · 가방 정원 초과 되돌림(그대로 - 잃는 것 없음) | dfa617d |

## 3. 출시 설정(B) · 알려진 버그(C)

- **B**: `ArtStyleV1Data.enabled = true`. 옛 식 `enabled or (Studio and Force ~= false)`는 enabled가 켜지면 비상 끔이 안 먹어 → `Force ~= false and (enabled or Studio)`로(`HuntingGround.server.lua` 두 곳). 비상 끔 = enabled false 퍼블리시 또는 RS Attribute `ArtStyleV1Force = false`(이제 라이브에서도 읽음 - 체크리스트에 "퍼블리시 전 남아 있지 않은지" 추가). 체크리스트 2-4절 머리에 **서버 Max 16 · 정원 12** 확정 상자.

| 버그 | 원인 | 수정 | 근거 |
|---|---|---|---|
| 심해 삼지창 던지기 전조 오른팔 튐 1.85배 | 공용 `charge` 동작의 전조 키 f 0.8 = `inout`(속도 0으로 끝) 다음 f 1.0이 `out`(최대 속도로 출발) · 삼지창은 전조 1.0초라 구간 0.176초에 꺾임 831°/s | f 1.0 `ease = "inout"`(자세 · 시각 · 판정 불변) | boss_motion 튐 1 → 0 · 거울 돌진 · 수호자 돌진도 0.70 → 0.53 |
| 활강 캡처 공중 고정(258) | Studio 로그 `이동 보정 … 합법 속도 26/s → (x, 253, z)` 반복 = 서버가 활강 속도(33)를 안 줌 → 클라가 땅을 떠난 직후 보낸 활강 알림이 서버가 공중을 보기 전에 와서 버려짐(클라는 한 번만 보냄) → 걷기 속도로 수평을 재 나무 위로 계속 되돌림 | 서버가 `glide.serverPendingSeconds` 0.6초 안에 공중을 보면 그때 켬(땅 활강 불가 - 보안 그대로) | 로그 근거 · Studio 확인 = STUDIO-QUEUE C-2 |
| 자체 점검이 한국어 문장 비교(DropFeed:356 · P3bUiCheck) | 영어 켜면 X | `Text.get(키)`로 비교 · 피드 합성 문장은 언어별 | 컴파일 · Studio C-3 |
| 게시판 코드 만료(F가 찾음) | 클라 `os.time(표)`가 기기 시간대로 읽힐 수 있음(서버는 UTC) | `DateTime.fromUniversalTime` | Studio C-4 |
| 남의 시점 더미 방어구 · 로드 때 정해지는 글(창 제목) | 검사 도구 한계 · 설계(언어 기본 끔) | 그대로(기록) | - |
| (보고) 자체 점검의 한국어 문자열 비교가 8파일 약 14곳 더 있음 | 영어 켠 채 자체 점검을 돌릴 때만 X(G1_1UiCheck · BossBarCheck · PartyHudCheck · RequestBannerCheck · ItemFlowCheck 등) | 안 고침(언어 기본 ko) | - |

## 4. 결정 13건 정리(추천값으로 진행 - 사용자 검토용)

| # | 무엇 | 추천(지금 값) | 이유 |
|---|---|---|---|
| 3 | 초대받은 쪽 보상이 계정 나이와 무관 | 그대로 | 거래 · 선물 보내기가 없어 부계정 보상이 본계정으로 못 감 - 거래를 열 때 같이 정한다 |
| 5 | 합동 목표 1인 하루 상한을 프로필로(v62 필드) | MemoryStore 유지(TTL = 그날 끝 + 10분) | 메모리 몫이 R × 30B로 줄었고(ALL4) 장애 때만 서버별 상한 - 구조 변경 대비 이득 작음 |
| 6 | 태초 원장 접속마다 재확인 | 그대로 | 태초 보유자는 드묾 · 최악 72 읽기/분도 보호된 예산 안 |
| 7 | 1인 서버 리더보드 갱신 주기 | 그대로(90초) | 목록 한도 7 중 4 · 넘치면 큐 대기(실패 아님) |
| 8 | 파티 원격 초대 발행 상한 | 없음 | 초대 간격 2초 · 좌석은 하트비트가 맞춤 · 서버 수가 커지면 다시 |
| 9 | 약한 세션 잠금 → 강한 잠금 | 출시 뒤 `SaveSessionLockWait` 음수 비율 보고 판단 | 지금도 덮어쓰기는 없음(손실 = 늦게 읽은 쪽 진행만) |
| 10 | 손상 저장 고침이 없어진 보스 도장을 지움 | 지움 | 표시 전용 · 이제 A3 등록부가 보스 외 id 삭제를 막음 |
| 11 | 선물 기록 from("운영" · "친구 초대") 번역 | 그대로(저장된 글) | 키로 저장하면 구조 변경 · 선물함 표시에만 쓰임 |
| 12 | 방송 문장(보물상자 · 명판 · 명예의 전당) 키 + 인자 전송 | ko 그대로 | 프로토콜 변경 · 영어 기본 끔 |
| 13 | 용어집 미정어 | **F가 확정**: 분해 = Salvage · 변환권 = Reroll Ticket · 불씨 = Ember · 홈 = Socket · 기믹 = Mechanic · 펫 고급 = Uncommon(알 Good과 분리) · 강화대 = Forge | `docs/i18n/glossary.md` 표 · 남은 것 = 직업 영어 이름(옛 Greatsword… vs 지금 검사 · 도적 · 궁수 · 치유사) |
| 14 | 방지권 영어 이름이 보상 띠 넘침 | **F가 줄임**: 좁은 띠만 Drop Guard / Reset Guard | 상점 · 설명은 정식 이름 |
| 15 | 서버 Max 16 · 정원 12 | **B에서 확정 표시** | 크로스서버 파티 합류 자리 4 |
| 16 | 활 몸은 아바타 배율 밖 | 그대로(손 자리만) | 활 몸 크기 = 사거리 표시와 같이 읽힘 · 배율 따라가면 큰 아바타 활이 과장 |

이번에 새로 정한 것(추천값으로 진행): A1 받은 id 200개 · A2 "아레나 안" = encounter 있음(자리 판정 아님)과 "명중"도 전투 · A3 세트 구역은 보관 안 함 · 착용 장비 되돌림 = 가방(정원 넘을 수 있음) · B 비상 끔 Attribute가 라이브에서도 먹게 · C 활강 대기 0.6초.

## 5. 코드 점검(D)

| 구분 | 도구 · 범위 | 결과 |
|---|---|---|
| 컴파일 | `luau-compile` 클라 + shared 515 · 서버 + shared 457 | 오류 0 |
| 분석 | `luau-analyze`(Roblox 전역 잡음 제외) | 실제 버그 = GlobalUsedAsLocal 1(보스 빙판) · MisleadingAndOr 2(`/gg rift off` · 전망대 Station) → 수정. 나머지 = 타입 추론 잡음 · 의도된 코드 |
| D① 클라 수명 | 창 열기/닫기 · 목록 갱신 · 매 프레임 루프 · 풀링 | 수정 4: 보스 빙판 `reset`이 전역에 써서 보스전 뒤에도 미끄러짐 · 활강 중 캐릭터 사라지면 입자 예산 미반환 · WeaponVisual 퇴장 뒤 연결 남음 · SealedFx 스트리밍 표 증가. 보고 1: 캐릭터별 연결 정리가 `PlayerCharacterDestroyBehavior`에 달림(STUDIO-QUEUE C-5) |
| D② 서버 | nil · pcall · 무한 루프 · yield 위험 · 경합 | **pcall 누락 0**. 수정 약 26: `ImmediateSave.request`가 부른 쪽을 멈춤(처치 · 덫 Heartbeat 안에서 DataStore 대기 → 죽은 보스가 계속 공격 등 4 ~ 5건의 공통 원인 - task.spawn + 두 번 쓰기 방지) · 파티 코드 발급 경합(파티 만들기 실패) · 합류 전 저장 실패 무시 · 좌석 · 유령 멤버 · 로드 중 퇴장 프로필 남음 · 죽은 뒤 평타/스킬/틱 · 리더보드 action 무제한 표 · 루프 pcall · 초대 보상 즉시 저장 · 종료 때 합동 목표 flush · 오르골 · 진입 연출 토큰 등. 남긴 낮음 9(보고만) |
| 넘겨받은 2 | 금지 파일 담당 = 본 세션 | `Travel.teleport` 미리 불러오기 중 겹친 이동 · 쓰러진 사람 흡혈 되살아남 → 수정(713391b) |
| 리뷰 | D② 변경 + 넘겨받은 2 리뷰 서브에이전트 | **ImmediateSave 변경 문제 없음**(호출부 50곳 중 완료를 가정한 곳 0 · 구매 · 합류 · 퇴장 · 종료 = flush · saving 잠금 · 종료 마감 대기 정상) · HP 0 거절 오탐 없음 · 연출 토큰 정상. 지적 반영: **중간 1** = 이동 중 `Travel.teleport`가 새 요청을 버려 부른 쪽이 쿨다운 · 상태만 잃음 → 마지막 요청을 기억했다가 지금 이동 뒤 그리로(캐릭터 바뀌면 버림) · 낮음 = 파티 코드 발급 대기에 30초 상한. 남김(낮음 · 개발 계정만): DevTools 백업으로 저장이 막힌 상태의 크로스서버 합류가 service_unavailable |

## 6. 리뷰 · 회귀(G)

| 대상 | 결과 |
|---|---|
| 로컬 하네스(`LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh`) | security 44/44 · save 58/58 · lock 12/12 · migrate 15/15 · **quarantine 13/13(새)** · monetize 39/39 · dupe 7/7 · multiplayer 10/10 · attack 7/7 · request_gate 7/7 · mesh 34/34 · **boss_motion 튐 0**(ALL4 = 1) · regrow 8/8 · meshswap O · **id 등록부 통과(새)** - 15종 전부 |
| EconSim(로컬 · baseline all · 시드 20260923) | 캐주얼 1,000 = **26.8h**(≤ 32 O) · 상위 1% 표 · 요약 줄 = ALL4와 **글자까지 같음**(계산 시간만 다름) · 표본 8/8 · `Claude outputs/QUEUE-ALL5/sim/econsim_baseline_all.txt` |
| BossSim 결정 1(X 6.0 · 300판 · 스테이지 500 · 첫 도전) | 솔로 원거리 61.7% · 솔로 근접 61.3% · 2인 67.7% · 4인 78.6%(채택 때 62.7 · 61.9 · 67.8 · 78.6 · 상한 68.8 · 62.6 · 79.2 · 94.4 안) · `x_now.txt` |
| BossSim 초반 완화 | 스테이지 25 = 0.8 · 0.8 · 0.3 · 0.4% · 50 = 47.8 · 45.7 · 53.7 · 58.8%(ALL1과 같음) · 55 = 59.9 · 60.8 · 69.0 · 79.0%(잡음 안) · `relief.txt` |
| 오프라인 모션 하네스 | 보스 6종 전 동작 튐 0 |
| 텍스트 검사 `check_textdata.py` | 통과(ko 1,374 · en 1,374 · en 40자 넘는 문장 107) |

## 7. 아이콘(E) - `docs/release/icons/`

| 파일 | 종류 | 메모(자체 평가) |
|---|---|---|
| `theme_starlight.png` · `theme_ember.png` · `theme_frost.png` · `theme_jelly.png` | 개발자 상품(테마) | 별빛 · 서리꽃 좋음 / 불씨 · 젤리 보통 |
| `glider_petal.png` · `glider_kite.png` · `glider_dragonWing.png` | 개발자 상품(글라이더) | 연 좋음 · 꽃잎 보통 · 드래곤 날개 다시 그림(V자 · 외곽 상자 86%) |
| `season_premium.png` | 개발자 상품(시즌 패스) | 구름 고래 + 왕관 |
| `bagExpand.png` · `pickupRadius.png` · `recallCooldown.png` · `nameplateColor.png` · `nameplateBadge.png` | 게임패스 | 줍기 반경 다시 그림(가운데 펫 + 점선 원 + 끌려오는 보석 · 금화) · 이름표 색 보통 |
| `game_icon_blender_A/B/C.png` | 게임 아이콘 후보(비교용) | Blender 블록 몸 - 캡처판보다 "실제 게임" 느낌은 덜함 · 개발 계정 이름 없음 |
| `_sheet.png` · `README.md` · `src/` | 확인 시트 · 표 · 렌더 원본 | 다시 만들기 = `bash roblox/tools/blender/bl.sh roblox/tools/icons/store_renders_blender.py` → `python roblox/tools/icons/make_store_icons.py` |

규칙 출처: 타일 · 외곽선 `#1E1B2E` = `make_hud_icons.py` · 3톤(윗면 ×1.18 · 그늘 ×0.72 · 순검정 금지) = `docs/art/art-direction-v1.md` §3-3 · 금지 색 · 글자 금지 = `make_hud_icons.py` · `make_ui_icons_v2.py` · 위험색 검사 = 생성기 `danger()`. 체크리스트 1-2절 표에 13개 경로를 넣었다.

## 8. 영어 · 문구(F)

- en 값 **103키** 손질(UI 31 · 견습/안내 11 · 기믹 카드 22 · 상점 14 · 거절 이유 7 · 토스트 5 · 넘침 줄임 13) - 키 추가 · 삭제 0 · ko 변경 0 · `{자리}` 보존 확인.
- 넘침 위험 v2 = `docs/i18n/overflow-risk-v2.md`(방법 · 상위 30 · 캡처 방법 기호) + 전 키 글자 수 `docs/i18n/length-all.csv`. 상위 3 = `hud.band.gearClaimed` 1.41 · `hud.band.gear` 1.35(둘 다 **ko도 넘침** → 칸 손질 필요) · `inv.act.reroll` 1.28.
- 초안(ko/en): `docs/release/help-encyclopedia.md`(10항목 · 항목마다 데이터 파일 근거) · `update-board-first-post.md` · `patch-notes-v1.0.md` · `codes.md`(FORGE2026 · RIFTOPEN 유지 · `FIRSTBOSS` 강화석 10은 제안만 - 만료 = UTC 그날 23:59:59 = KST 다음 날 08:59:59).
- 영어를 켜도 한국어로 남는 글(키가 아님): `SocialRewardData` 코드 결과 · 게시판 제목 · news · `BossData.intro` · 직업 · 보스 · 구역 · 등급 `displayName`.

## 9. STUDIO-QUEUE 요약(`docs/phase/STUDIO-QUEUE.md`)

| 절 | 항목 수 | 내용 |
|---|---|---|
| 0 | - | 실행 규칙(Rojo Connect · Source 대조 · 검증/확인 Play · 캡처 경로 `Claude outputs/STUDIO-QUEUE/<번호>_<이름>[_ko|_en][_pc|_phone].png`) |
| 1 검증 Play | 4 | 저장 동반(R2 · S05b · S21-0 · 6hbF) · Q0 · P0 · BR1 · 길 안내 3시드 · 종료 저장 |
| 2 저장 · 보안 | 4 | 선물 재지급(실제 DataStore) · 주간 입장 토스트 ko/en · 체크포인트 명중 · 모르는 id 보관 실로드 |
| 3 설정 · 버그 | 7 | 아트 켬 · 비상 끔 · 삼지창 등 전조 3 · 활강 · 자체 점검 영어 · 게시판 코드 · 캐릭터 정리 설정 |
| 4 코드 점검 후속 | 13 | D①② 수정 실동작 |
| 5 성능 | 4 | perf world · boss · 상위 비용 5 최적화 · 다중 클라(사용자) |
| 6 캡처 | 5 | 폰 HUD · 화로 · 썸네일 3 · 게임 아이콘 3 · 영어 대표 화면 |
| 7 영어 넘침 | 30 | 상위 30 키 PC/폰 |
| 8 · 9 | 3 + 5 | ALL4 나머지 · 사용자 체감 확인 |

## 10. 사용자 확인 목록

| # | 확인할 것 | 방법 |
|---|---|---|
| 1 | **Rojo 플러그인 Connect 후 "STUDIO-QUEUE 실행"** | Studio Rojo 창 → Connect |
| 2 | 출시 아이콘 13장 · 게임 아이콘 Blender판(쓸지 · 다시 그릴지) | `docs/release/icons/_sheet.png` |
| 3 | 결정 13건(4절) 중 바꿀 것 | 4절 표 |
| 4 | 직업 영어 이름 확정(Greatsword… vs Swordsman · Rogue · Archer · Healer) | `docs/i18n/glossary.md` 메모 |
| 5 | 문구 초안(백과사전 · 게시판 첫 글 · 패치 노트 · 코드) · `FIRSTBOSS` 추가 여부 | `docs/release/` |
| 6 | 삼지창 · 돌진 전조 박력(ease 변경) | STUDIO-QUEUE U-1 |
| 7 | `PetData.unlocks.autoPickup = 200`이 "부화 200회"인지 "Lv.200"인지(백과사전 표기) | `docs/release/help-encyclopedia.md` 메모 |
| 8 | 체크리스트 사용자 칸(가격 · 게임 이름 · 시즌 시작일 · 체크포인트 · 표준 체형 · 코드 만료) | `docs/phase/launch-checklist.md` 6절 |

## 11. 재사용한 공통 입구

`Travel.busyReason`(새 - 체크포인트 · 주간 도전 공용) · `PartyState` 활동 기록(명중) · `RequestGate`(주간 입장 그대로) · `Text.getFor`(서버 → 그 사람 언어) · `SaveSystem.repairProfile` 옆 `quarantineUnknownIds`(로드 출구 한 곳) · `ImmediateSave.flush`(선물) · `HeightGuard` 활강 판정(Gliding Attribute) · 하네스 `build_run.py` · `deps.py`(새 `run_all.sh`가 묶음).

## 12. 다음에 알면 좋은 것

- "출시 뒤 id 삭제 금지"는 사람의 기억 대신 **등록부 검사(exit 1)**로 지킨다 - 데이터를 바꾼 커밋 전에 `python roblox/tools/ids/id_registry.py`, 새 id를 더했으면 `--write`. 그래도 빠진 id는 로드를 막지 않고 보관 칸으로 가며, id를 되살리면 다음 접속에 돌아온다.
- 공용 입구가 "끝날 때까지 기다리는" 함수면 부르는 곳 52군데가 전부 그 지연을 떠안는다(D② `ImmediateSave.request`). 저장처럼 느린 일은 입구 안에서 `task.spawn`하고, 정말 끝을 기다려야 하는 곳만 `flush`를 쓰게 나눈다.
