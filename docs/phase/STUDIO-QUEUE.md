# STUDIO-QUEUE - Studio 연결 뒤 할 일 (QUEUE-ALL5 H · 2026-10-01)

> 사용자가 **"STUDIO-QUEUE 실행"** 한 줄을 주면 이 문서를 0절부터 위에서 아래로 돈다. 항목마다 `상태` 칸을 채우고 결과는 `docs/phase/STUDIO-QUEUE-result.md`(표 하나 · 항목 번호 · O/X/보류 · 근거 로그 한 줄 · 캡처 경로)에 남긴다.
> 출처: QUEUE-ALL4 남은 것(보고서 1 · 2 · 5 · 6 · 8절) + QUEUE-ALL5 A ~ F에서 Studio 확인이 필요한 것 + 영어 넘침 위험 상위 30(`docs/i18n/overflow-risk-v2.md`).
> 체감 판단(재미 · 박력 · 어색함)은 하지 않고 9절 "사용자 확인"으로 넘긴다(COMMON §7-3).

## 0. 실행 규칙

| 규칙 | 내용 |
|---|---|
| 전제 | ① Studio Rojo 플러그인 **Connect**(사용자만 가능 - 안 돼 있으면 여기서 멈추고 요청) ② §7-2 ① Studio `Source` 대조: `server/SaveSystem.lua`(`quarantineUnknownIds` 있는지) · `server/GiftService.lua`(`claimedSet`) · `shared/data/ArtStyleV1Data.lua`(`enabled = true`) 3개를 edit `execute_luau`로 `find` |
| Play 종류 | **검증 Play**(1절) = edit에서 `VerifyArmedUntil = os.time() + 1800` + `VerifyOnly` 목록 → Play → 로그 폴링(마지막 `검증 끝` 줄) → 정지 → 두 Attribute `nil`. **확인 Play**(2 ~ 8절) = 무장 없이(저장은 개발 계정 실제 키 - `/gg loadout <스테이지>`로 시작) |
| Play 수 | 검증 Play 최대 2회 · 확인 Play는 절마다 1회(같은 Play에 묶을 수 있으면 묶음) |
| 캡처 경로 | `Claude outputs/STUDIO-QUEUE/<항목 번호>_<짧은 이름>[_ko|_en][_pc|_phone].png` (예: `F07_hud.band.gear_en_phone.png`) · 캡처 전 `/gg capture on`(개발 이름표 · 채팅 숨김) · 끝나면 `/gg capture off` |
| 폰 화면 | 800 × 360은 MCP로 못 만든다 → `ForceTouchLayout` + 창 크기 조정(메모리: 폰 가로 = 창 1182 × 900) + 순수 함수 식 대조(`docs/i18n/overflow-risk-v2.md` 3절 기호) |
| 영어 화면 | Edit에서 `workspace:SetAttribute("TextLanguageDev", "en")` → Play(끝나면 `nil`) · 또는 Play 중 `/gg lang en` |
| 멈춤 | X가 나오면 제품/검증 원인부터 로그로 가른다(CLAUDE.md) · 고친 코드는 Rojo 반영 확인 후 같은 항목만 다시 |
| 끝 | `verify.regression = false` 확인 · `VerifyArmedUntil` · `VerifyOnly` · `TextLanguageDev` · `ArtStyleV1Force` · `RiftForce` Attribute가 남지 않았는지 확인 · 결과 커밋 · push |

## 1. 검증 Play (자동 블록 - VerifyOnly)

| # | 상태 | 무엇 | VerifyOnly | 확인 기준 |
|---|---|---|---|---|
| V1 | | 저장 동반 블록(QUEUE-ALL4 C + ALL5 A1 · A3 - SaveSystem · SaveCoordinator · ImmediateSave · GiftService 변경) | `R2(가), S05b(가), S21-0(가), 6hbF(나), S05b(나), S21-0(나)` | 끝 줄 전부 이전과 같거나 좋음. `6hbF(나)`는 실제 DataStore 잠금 대기 약 20초. 콘솔 `[SaveSystem] 모르는 id 보관`이 개발 계정에 **0줄**(오탐 없음 - 있으면 그 줄 원문 기록) |
| V2 | | QUEUE-ALL4 남은 블록 | `Q0(가), P0(가), BR1(가), BR1-2(가), BR1(나)` | ALL4 G 기준과 같음. `P0(가)`는 무거움(체인 끝 · 타임아웃 주의 - 메모리 "무거운 검증") · `BR1(나)` 12인 step 시간 기록 |
| V3 | | 길 안내 3시드 | (검증 블록 아님) 확인 Play에서 서버 `execute_luau`: `require(game.ServerScriptService.GuideVerify).run({ seed = <시드> })`을 시드 3개(20260930 · 1 · 2)로(execute_luau require = 모듈 사본이지만 순수 지면 읽기라 무관) | 6구역 × 55 × 3 = 990곳 `under = 0`(QUEUE-ALL1 기준) |
| V4 | | 정지 때 종료 저장 | V1 Play 정지 | 출력 `[forge-game] 종료 저장: 전부 끝 · n초` 한 줄 |

## 2. 저장 · 보안(QUEUE-ALL5 A) - 확인 Play

| # | 상태 | 무엇 | 명령 · 방법 | 확인 기준 |
|---|---|---|---|---|
| A1-1 | | 선물 재지급 방지(실제 DataStore) | ① 다른 계정 id로 `/ops gift <id> sparkleShard 5` 대신 **개발 계정 자신에게 오프라인 대기열 흉내**: 서버 `execute_luau`로 `Gifts_v1` 대기열 키 `u<개발 UserId>`에 `{id="QA5-1", kind="sparkleShard", amount=5, from="ops", note="", at=os.time()}` 1건 UpdateAsync → 재접속(Play 다시) ② 팝업 [받기] ③ 같은 대기열 항목을 다시 넣고 재접속 | ② 조각 +5 · ③ 콘솔 `[B2] 선물함: … 이미 받았거나 선물함에 있는 선물 1건 건너뜀` · 조각 변화 0 · 대기열 비워짐. 끝나면 대기열 키 정리 |
| A2-1 | | 주간 도전 입장 조건 | ① 잡몹 때리는 중(8초 안) 퀘스트 창 [주간 도전] → [도전] ② 귀환(H) 집중 중 [도전] ③ 보스전 안에서 [도전] ④ 평소 [도전] | ①②③ 토스트 = `srv.weekly.blocked.combat` · `casting_already` · `in_boss` 문장(ko) · 보스 안 나옴 ④ 보스 등장. `/gg lang en`으로 ① 한 번 더 → 영어 토스트 한 줄에 들어감. 캡처 `A2-1_weekly_combat_ko.png` · `_en.png` |
| A2-2 | | 체크포인트도 "명중 = 전투" | 잡몹을 때린 직후(피해는 안 받음) 지도에서 체크포인트 이동 | "전투 중" 거절 · 8초 뒤 정상 시전 |
| A3-1 | | 모르는 id 보관(실제 로드) | 서버 `execute_luau`로 개발 계정 프로필(`_verify` 무장 Play 권장) 가방에 `{grade="epic", part="armor", itemLevel=1, option={id="QA5_gone"}}` 1개 넣고 저장 → Play 다시 | 로드 성공 · 콘솔 `[SaveSystem] 모르는 id 보관: … 옮김 1(item:option:QA5_gone)` · 가방에 그 장비 없음 · 통계 `[T1][드라이런] … SaveQuarantined` · 이름표 색 · 배지 장착 그대로(리뷰 지적 회귀). 끝나면 `profile.quarantine` 비우고 저장 |

## 3. 출시 설정 · 알려진 버그(QUEUE-ALL5 B · C)

| # | 상태 | 무엇 | 명령 · 방법 | 확인 기준 |
|---|---|---|---|---|
| B-1 | | 아트 켬 = 라이브와 같은 경로 | Edit에서 `ReplicatedStorage:GetAttribute("ArtStyleV1Force")`가 `nil`인지 → Play | `Workspace.ArtStyleV1 = true` · 콘솔 `[forge-game] 카툰 스타일 artV1` |
| B-2 | | 비상 끔 | Edit `ArtStyleV1Force = false` → Play | `Workspace.ArtStyleV1 = false`(옛 모습) · **끝나면 Attribute `nil`로**(퍼블리시에 남으면 라이브 아트 꺼짐) |
| C-1 | | 심해 삼지창 · 수정 여왕 거울 돌진 · 수호자 돌진 전조 | `/gg loadout 30` → `/gg boss pattern abyssal_lord tridentThrow` · `crystal_queen mirrorDash` · `section_guardian charge`(각 1회) | 전조 끝 팔 젖힘이 한 프레임 튐 없이 이어짐 · 투척/돌진 순간 = 판정(바닥 띠 끝). 캡처 3장(전조 끝 프레임) `C-1_<보스>.png` |
| C-2 | | 활강 공중 고정(원인 = 활강 알림이 서버 공중 판정보다 먼저 와서 버려짐 → 걷기 속도로 수평 되돌림) | 허브 나무 정거장 위에서 자동 걷기 + Space 유지로 뛰어내림 3회 | 콘솔 `[forge-game] 이동 보정 … 합법 속도 26/s` **0줄** · 정상 활강(내려감) · 캡처 `C-2_glide_bubble.png`(ALL4 A2 활강 거품 캡처도 여기서) |
| C-3 | | 자체 점검 영어 | `TextLanguageDev = "en"` + 무장 Play(`VerifyOnly`에 DropFeed · P3b UI 점검이 도는 블록 - 없으면 생략) | DropFeed:356 · P3bUiCheck 탭 줄 O |
| C-4 | | 게시판 코드 만료(UTC) | 허브 업데이트 게시판 | FORGE2026 · RIFTOPEN 두 줄 보임(오늘 2026-10 기준) |
| C-5 | | 캐릭터 정리 설정 | Edit `print(workspace.PlayerCharacterDestroyBehavior)` | `Enabled`면 끝. `Default`/`Disabled`면 보고(D① 지적 - 리스폰마다 캐릭터별 연결 누적: Nameplate · GlideView · AirMotion · AttackInput · FallFx) → `default.project.json` Workspace `$properties` 추가 결정 필요(rojo 재시작 = 사용자) |

## 4. 코드 점검 후속(QUEUE-ALL5 D① 클라 · D② 서버)

| # | 상태 | 무엇 | 방법 | 기대 |
|---|---|---|---|---|
| D-1 | | 서리 거인 빙판 정리 | 빙판 위에 선 채 보스전 끝(`/gg boss end` 또는 포기) → 바로 걷기 | 즉시 정상 걸음(옛 = 빙판 시간 끝까지 미끄러짐) |
| D-2 | | 활강 입자 예산 | 치장 글라이더 낀 채 활강 → 리셋 5회 | 입자 연출이 계속 나옴(예산 고갈 없음) |
| D-3 | | 고래 · 흙더미 연출 | 나무 정상 · 광산 근처 1분씩 | 그대로 나옴 |
| D-4 | | 파티 만들기 | 파티 창 [만들기] | `파티 코드 XXXX` 안내 · `service_unavailable` 없음 |
| D-5 | | 보스 처치 직후 | `/gg loadout 15` → `/gg boss 15` 처치 | 처치 뒤 보스 공격 없음 · `저장 성공` 줄은 처치 처리 뒤 따로 |
| D-6 | | 죽은 뒤 입력 | 잡몹에게 쓰러진 뒤 리스폰 전 평타 · Q · 회전베기 | 피해 숫자 · 흡혈 · 치유 없음 · HP 0 유지 |
| D-7 | | 회전베기 중 사망 | god 끈 채 회전베기 도중 사망 | 남은 틱 피해 없음 |
| D-8 | | `/gg rift off` | 명령 → Workspace `RiftForce` | `false` · 균열 꺼짐 |
| D-9 | | 진입 연출 토큰 | 보스 진입 → 3초 안 포기 → 바로 재진입 | 두 번째 연출 내내 고정 · 잠금 유지 |
| D-10 | | 오르골 실패 귀환 | 조각상 상태에서 [마을] | 허브에서 와장창 피해 없음 |
| D-11 | | 즉시 저장 빈도 | 강화 연타 1분 | `저장 성공` 사람당 6초에 1번 이하 |
| D-12 | | 리더보드 창 | 순위 · 내 기록 · 카드 · 명예의 전당 탭 | 전부 표시(action 제한 뒤 회귀 없음) |
| D-13 | | 순간이동 중복 | 잠긴 구역 경계 · 정거장 내려가기 패드 위에서 3초 | 콘솔 `[forge-game] 이동(` 한 번만 · 알림 반복 없음 |

## 5. 성능(QUEUE-ALL4 D 남은 것)

| # | 상태 | 무엇 | 명령 | 확인 기준 · 기록 |
|---|---|---|---|---|
| P-1 | | 서버 필드 | `/gg perf world 1` · `12` · `16` · `20` · `24` | Heartbeat 평균 · 최대 · 메모리 · 인스턴스 표(알파 12인 1.05ms 대비) → `docs/perf/` 새 표 |
| P-2 | | 보스 4인 | `/gg perf boss 4`(보스 6종) | Heartbeat · 원격 수신/초 · 송신 kbps(알파 최대 2.7ms 서리) |
| P-3 | | 상위 비용 5 최적화 | P-1 · P-2 결과의 상위 5 호출원 | 겉모습 · 판정 불변 최적화 후 같은 명령으로 전후 표 |
| P-4 | | 실제 다중 클라 | 사용자 절차서 `docs/phase/perf-manual-test.md` | 사용자 확인 목록으로 넘김 |

## 6. 화면 캡처(QUEUE-ALL4 A 남은 것 + 출시 이미지)

| # | 상태 | 무엇 | 명령 · 방법 | 캡처 |
|---|---|---|---|---|
| S-1 | | 폰 800 × 360 HUD | ForceTouchLayout + 폰 창 크기 · 허브 · 사냥터 · 보스전 HUD | `S-1_hud_{hub,field,boss}_phone.png` · 화면 밖 0 · 겹침 0 · 터치 44 이상 |
| S-2 | | 키운 화로(A1) | 아레나 4종 전경 `/gg boss 20` 등 | `S-2_brazier_{frost,abyssal,crystal,storm}.png` · 화로가 점이 아니라 그릇 + 불로 읽힘 |
| S-3 | | 썸네일 3 재촬영 | `/gg capture on` · 1920 × 1080(가능하면 창 최대화 - 메모리 capcrop) | `S-3_thumb_{A_transcend,B_codex,C_hub}.png`(글자 없는 판) |
| S-4 | | 게임 아이콘 3 재촬영 | `/gg capture on` · 정사각 크롭 | `S-4_icon_{A_grass,B_pillar,C_tight}.png` · Blender판(`docs/release/icons/game_icon_blender_*.png`)과 나란히 비교표 |
| S-5 | | 영어 화면 대표 | `TextLanguageDev = en` · 허브 · 가방 · 강화 · 보석 · 파티 · 순위 · 상점 · 퀘스트 · 도움말 · 보스 기믹 카드 | `S-5_<창>_en_pc.png` · `_phone.png` |

## 7. 영어 넘침 위험 상위 30 캡처(QUEUE-ALL5 F · 상세 = `docs/i18n/overflow-risk-v2.md` 2 · 3절)

`TextLanguageDev = "en"` · PC(1024 × 768 이상)와 폰(가로 800급) 둘 다 · 캡처 = `F<순위>_<키>_en_{pc,phone}.png`. 기준: 글자가 칸 안(잘림 "…" 없음 · 칸 밖으로 안 삐져나옴 · 다음 줄과 안 겹침). X면 키와 화면을 기록(문장 줄이기는 다음 작업).

| 순위 | 키 | 화면(캡처 방법 기호 - overflow-risk-v2 3절) | 상태 |
|---|---|---|---|
| 1 | `hud.band.gearClaimed` | 스테이지 선택 보상 띠(가) - ko도 넘침 | |
| 2 | `hud.band.gear` | 보상 띠(가) - ko도 넘침 | |
| 3 | `inv.act.reroll` | 가방 보석 탭 버튼(자) | |
| 4 | `scene.world.recallTime` | 세계 정보 카드 귀환 줄(아) | |
| 5 | `hud.band.ticketRow` · `dropTicket` · `resetTicket` | 보상 띠(가) | |
| 6 | `hud.band.codex` | 보상 띠 34px 칸(가) | |
| 7 | `gear.bulk.dismantle` | 일괄 처리(자) | |
| 8 | `hud.band.gimmickHelp` | 보상 띠 버튼(가) | |
| 9 | `forge.gem.bulk` | 보석 대장간 탭(차) | |
| 10 | `ui.class.row` | 직업 선택(카) | |
| 11 | `scene.world.backTime` | 세계 정보 카드(아) | |
| 12 | `hud.band.remoteEntry` | 보상 띠(가) | |
| 13 | `scene.boss.env.padsToCrystal` | 수정 여왕 환경 문구(타) | |
| 14 | `gimmick.crystal_queen.do` | 기믹 카드 3컷 캡션 · 폰 667폭(파) | |
| 15 | `gimmick.abyssal_lord.line` | 기믹 카드(파) | |
| 16 | `hud.band.gateGuide` | 보상 띠(가) | |
| 17 | `gimmick.section_guardian.do` | 기믹 카드(파) | |
| 18 | `attendance.login` | 출석 창(하) | |
| 19 | `desc.skill.label.range` | 스킬 툴팁(라) | |
| 20 | `desc.skill.label.partyBuff` | 스킬 툴팁(라) | |
| 21 | `gear.bag.fullToast` | 가방 가득 토스트(거) - ko 1.32 | |
| 22 | `forge.inherit.stat.speed` | 계승 창(마) | |
| 23 | `forge.rebirth.milestones` | 환생 화면(너) | |
| 24 | `scene.boss.trap.rescuing` | 덫 구출 문구(사) | |
| 25 | `scene.boss.trap.stuck` | 덫(사) | |
| 26 | `scene.primordial.spectate` | 태초 알림 구경(더) | |
| 27 | `inv.gems.title` | 장비 상세 카드(자) | |
| 28 | `gimmick.abyssal_lord.do` | 기믹 카드(파) | |
| 29 | `boss.grab.struggle` | 대공 잡기(사) | |
| 30 | `desc.skill.label.finalDmg` | 스킬 툴팁(라) | |

## 8. QUEUE-ALL4 그 밖에 남은 것

| # | 상태 | 무엇 | 방법 | 기준 |
|---|---|---|---|---|
| R-1 | | 남의 시점 방어구(검사 도구 한계) | 더미 대신 2번째 계정이 있으면 그 화면 · 없으면 보류 | 사용자 확인으로 |
| R-2 | | 아바타 0.8 · 1.35 무기 · 이름표 | 아바타 배율 바꾼 계정 | 사용자 확인으로 |
| R-3 | | 땅 치기 무게감 재캡처(파편 키운 뒤) | `/gg boss pattern section_guardian innerSmash 15` → 보스 18 stud 앞 | `R-3_slam.png` |

## 9. 사용자 확인(체감 - 자동 판정 안 함)

| # | 무엇 | 확인용 명령 |
|---|---|---|
| U-1 | 삼지창 · 거울 돌진 · 돌진 전조가 `inout`으로 바뀐 뒤 박력이 줄었는가 | C-1과 같음 |
| U-2 | 땅 치기 무게감 | R-3과 같음 |
| U-3 | 출시 아이콘 13장 · 게임 아이콘 Blender판 vs 캡처판 | `docs/release/icons/_sheet.png` · S-4 비교표 |
| U-4 | 영어 문장 톤(아이 대상) | S-5 캡처 |
| U-5 | 4인 실제 성능 | `docs/phase/perf-manual-test.md` |
