# 보안 · 치트 감사 (출시 전 · QUEUE-ALL4 블록 B · 2026-10-01)

> 범위: `security-audit-alpha.md`(2026-09-29 · 클라 → 서버 입구 51개) 이후 새로 생긴 클라 → 서버 Remote 전부와, 기존 Remote에 새로 붙은 동작(TravelRequest 체크포인트 · 귀환 취소 · 견습 바로 가기 / QuestRequest 출석 · 메인 / PartyRequest 모집 게시판 / SettingsSave 새 종류).
> 방법: `grep "OnServerEvent\|OnServerInvoke" roblox/src` 전수 → 핸들러와 그 아래 판정 함수 읽기 → 클라 `FireServer`/`InvokeServer` 호출부 대조 → 로컬 하네스(`roblox/tools/harness/security_launch_test.luau`)로 실제 핸들러에 잘못된 인자 · 연타 · 이중 요청을 넣어 확인. Studio Play 미실행(다른 작업자가 Studio 사용 중 - 아래 "Studio에서 확인할 것").
> 결론 한 줄: **치명 0 · 중요 3 · 낮음 6 수정, 결정 필요 3, 남은 위험(기록) 6.** 보상 · 발견 · 처치 시간 · 기여 상한은 전부 서버가 판단한다. 고친 것은 "속도 제한이 없던 새 입구(DataStore 읽기 증폭 · 보스 스폰 · 순간이동 연타)"와 "잠긴 구역 체크포인트 · 보상 유실" 두 갈래다.

## 1. 발견 · 수정

| ID | 항목 | 위험 | 공격 · 문제 시나리오 | 수정 | 확인 방법 |
|---|---|---|---|---|---|
| L1 | WeeklyChallengeTop(RF) 순위 읽기 증폭 | **중요** | 제한 없는 RF가 부를 때마다 `GetSortedAsync` 1번 + `GetNameFromUserIdAsync` 최대 5번 → 한 사람이 초당 수십 번 부르면 그 서버 DataStore 읽기 예산(60 + 10 × 인원/분)을 다 써 저장 · 리더보드 · 선물함 읽기가 밀린다 | 순위 표 = 서버 공용 캐시(`WeeklyChallengeData.topCacheSeconds` 30초 - 읽는 동안 온 요청은 직전 표) + `RequestGate.invoke`(`RequestLimitConfig.remotes.WeeklyChallengeTop` 초당 1 · 통 3) · 내 기록(myBest)은 매번 새로 | 하네스 "순위 창 3명 × 4번 = 순위 읽기 1번" (수정 전 사본 = 읽기 12 · 이름 12 → X) |
| L2 | WeeklyChallengeStart 연타 | **중요** | 제한 없음 → 보스전 밖에서 연타하면 요청마다 아레나 꾸미기 · 보스 스폰 경로를 탄다(스폰이 실패하는 상황이면 매번 무거운 경로를 끝까지 돈다) | `RequestGate.allow(player, "WeeklyChallengeStart")`(초당 0.5 · 통 2 - 실패 뒤 다시 누르기는 된다) | 하네스 "입장 연타 10 = 스폰 2번 이하" (수정 전 = 10번 → X) · "보스전 중 입장 = 거절" |
| L3 | TravelRequest 제한 없음 · 견습 바로 가기 순간이동 연타 | **중요** | `tutorialZone`은 쿨이 없어 견습 중 연타 = 요청마다 `RequestStreamAroundAsync`(서버 스트리밍 비용) + 순간이동 · 나머지 동작도 사람 단위 제한 없음 | 핸들러 첫 줄 `RequestGate.allow(player, "TravelRequest")`(기본 통 초당 10) + `tutorialZone`만 `TravelTutorialZone`(초당 0.2 · 통 2) | 하네스 "견습 바로 가기 연타 10 = 순간이동 2번" · "TravelRequest 연타 30 = 기본 통만 통과" (수정 전 = 이동 10 · 버림 0 → X) |
| L4 | 체크포인트 순간이동 → 잠긴 구역 | 낮음 | 견습은 단계마다 tier 1 ~ 6 구역을 잠깐 연다(`Travel.unlockedCount`) → 그때 찾은 체크포인트(`scanCheckpoints`는 구역 개방을 안 본다)로 졸업 뒤 아직 잠긴 구역 입구로 순간이동(도착 뒤 밀어내기만 남는다) | `requestCheckpoint`가 `cp.zone`이면 `Travel.isZoneOpen` 확인 → `cp_locked`(돌아가기 `requestBack`과 같은 규칙) · 안내 문구 1줄 | 하네스 "찾았지만 잠긴 구역(tier6 · 보스 0) = cp_locked" (수정 전 = casting → X) |
| L5 | CommunityGoalClaim 알 칸 + 알 가방 가득 = 보상 유실 | 낮음(경제 · 신뢰) | `claimed` 표시 뒤 `QuestService.grant`가 가방 가득이면 알을 버린다 → 칸은 받음 · 알은 사라짐(재수령 불가) | 받음 표시 전에 `#getEggs + egg > NestData.eggCap`이면 거절(기존 문구 `shop.reason.eggFull`) - `QuestService.claim` · `applyReward`와 같은 규칙 | 하네스 "알 칸 + 알 가방 가득 = 거절 · 받음 표시 안 함" (수정 전 = "알 1" 지급 처리 → X) |
| L6 | CommunityGoalClaim 제한 없음 | 낮음 | RF 연타(계산은 가볍다) - 공통 입구 규칙 정리 | `RequestGate.invoke(player, "CommunityGoalClaim", tostring(칸))`(함수 기본 통) | 하네스 "RF 연타 30 = 공통 요청 제한(버림 기록)" |
| L7 | 주간 도전 처치 시간 NaN · inf | 낮음 | `onCleared`가 `fightSeconds <= 0`만 봐서 NaN이 통과 → 참여 보상 지급 · NaN이 OrderedDataStore 쓰기로(호출부는 서버 `os.clock` 차라 지금은 경로 없음 - 방어) | NaN · inf 거절(`Sanitize` 원칙) | 하네스 "처치 시간 NaN · 음수 · 0 · inf · 문자 · nil = 기록 · 보상 0" (수정 전 = 참여 보상 지급 → X) |
| L8 | 지난주 순위 보상 = 읽기 실패 시 영구 유실 | 낮음(보상 유실) | `GetSortedAsync` 실패(pcall)에도 `rankClaimedWeek = last`를 써서 그 주 순위 보상을 다시 못 받는다 | 읽기 전에 표시(이중 지급 방지)하고 읽기 실패면 옛 값으로 되돌림(다음 접속에 다시) | 코드 읽기(하네스는 실패 DataStore 경로 미포함) |
| L9 | SpectateRequest 쿨다운 하드코딩 | 낮음(규칙) | `COOLDOWN = 20`이 server 파일에 숫자로(밸런스 · 제한 수치는 shared/data 규칙) · 공통 입구 밖 | `RequestGate.allow(player, "SpectateRequest")`(초당 0.05 · 통 1 = 20초 1번 - 같은 값) · 넘치면 기존 "잠시 뒤에 다시" 안내 그대로 | 하네스 "구경 가기 연타 3 = 1번만" · "잘못된 jobId 5종 = 에러 0" |

재사용한 공통 입구: `server/RequestGate`(allow · invoke) + `shared/data/RequestLimitConfig`(새 키 4개 - WeeklyChallengeStart · WeeklyChallengeTop · TravelTutorialZone · SpectateRequest. TravelRequest · CommunityGoalClaim은 기본 통) · 알 가방 문구 = 기존 TextData 키 `shop.reason.eggFull`. 새 진입점 · 새 저장 필드 없음.

## 2. 점검 항목별 결과(지시 ① ~ ⑧)

| 항목 | 결과 | 근거 |
|---|---|---|
| ① 서버 검증(위치 · 대상 · 보상 · 발견) · 타입/NaN/범위 | O(L4 · L7 수정) | 코드 = 서버 표 · 체크포인트 발견 = 서버 1초 스캔(`scanCheckpoints` - 클라 보고 없음) · 도감 칸 완료 = 서버 기록(`r.done`) · 합동 목표 합계 = 서버 Workspace 속성 · 칸 번호 = `D.tiers[n]`(문자 · 소수 · NaN · bool은 nil) · 시즌 칸 = `canClaim`(정수 · 범위 · NaN 거절) |
| ② 호출 속도 제한 | O(L1 · L2 · L3 · L6 · L9 수정) | 새 입구 7개 모두 제한: RequestGate 5(ShopRequest · WeeklyChallengeStart · WeeklyChallengeTop · CommunityGoalClaim · SpectateRequest) + 자체 제한 2(RedeemCode 3초 · 분당 8 / CodexRequest 0.2초) + TravelRequest 기본 통 |
| ③ 중복 지급(동시 두 번 · yield 사이 · 재접속 · 서버 이동) | O(L5 · L8 수정) · 결정 필요 1(D1) | 코드 · 도감 · 합동 목표 · 시즌 · 출석 = 확인 → 표시 사이 yield 없음(`QuestService.grant` · `Telemetry.economy` · `addEgg` · `addGold` 전부 yield 없음 확인) · 영수증 = 기록 먼저 + inFlight(monetize_test) · 재접속 = 계정 저장 필드(redeemedCodes · codex.claimed · communityGoal.claimed · weeklyChallenge.rewarded) + 세션 잠금. **선물함 대기열 지우기 실패 = 재지급 가능(D1)** |
| ④ 체크포인트 · 귀환 순간이동 | O(L4 수정) | `requestCheckpoint`: 켜짐 · 서버 발견 기록 · (새) 구역 개방 · 보스전 · 전투 중(`combatLockSeconds` 8) · 시전 중 · 체크포인트 쿨 30초 · 시전 3초(맞으면 취소) / 귀환: 보스전 · 시전 중 · 쿨(패스 ×0.5) / 취소 = 시전 중일 때만 · 이유 문자열은 "move" 외 전부 "key" |
| ⑤ 초대 보상 부계정 악용 | O | 자기 초대 거절 · 첫 접속(`savedAt == 0`)만 · 1쌍 1회(DataStore 쌍 키 UpdateAsync) · 초대받은 계정 나이 ≥ 7일일 때만 초대자 보상 · 초대자 하루 5번(UTC 날 키 UpdateAsync) · 초대자 = Roblox가 넣는 `ReferredByPlayerId`(클라 인자 아님) |
| ⑥ 코드 대소문자 · 만료 · 계정당 1회 | O | 대문자화 · 앞뒤 공백 제거 · 3 ~ 24자 영숫자만 · 만료 = 그 UTC 날 23:59:59까지 · `profile.redeemedCodes[code]`를 지급 전에(yield 없이) 표시 |
| ⑦ 주간 도전 기록 조작 | O(L7) | 처치 판정 = `CombatResolution`(서버) · 시간 = 서버 `os.clock() - encounter.startedAt` · 기록 = OrderedDataStore UpdateAsync(더 빠를 때만) · 클라가 보내는 값 없음 |
| ⑧ 합동 목표 1인 하루 상한 | O | 기여는 서버 처치 경로(`CombatResolution` → `note`)만 · 상한 = MemoryStore HashMap UpdateAsync(유저 · UTC 날) · MemoryStore 실패 = 이 서버 세션 상한(`sessionDaily`) · 초월 = 상한 밖(설계) |

## 3. Remote 전수 - 알파 감사 뒤 새 항목

### 3-1. 개수
| 구분 | 알파(09-29) | 지금 | 비고 |
|---|---|---|---|
| 클라 → 서버 입구 | 51(RE 40 · RF 11) | **58(RE 44 · RF 14)** | 새 7개(아래 표) · Studio 전용(`P3aTelegraphAck` · `PerfProbe` 리스너)은 제외 그대로 |
| 기존 입구에 새로 붙은 동작 | - | 4개 Remote | TravelRequest(checkpoint · cancelRecall · tutorialZone) · QuestRequest(attendance · main 진행형) · PartyRequest(board_post · board_remove · board_join) · SettingsSave(choice · volume 종류) |
| 클라 전용(서버 입구 없음) | - | 자동 이동 · 지도 핀 · 친구 보너스 | 자동 이동 = 클라 이동(서버는 HeightGuard 사후 검사) · 지도 핀 = 클라 상태(`WorldMapData.map.maxPins`) · 친구 보너스 = 서버 `IsFriendsWith` 캐시(PartyState) - Remote 없음 |

### 3-2. 새 입구(7)
| # | 이름(파일) | 클라가 보내는 인자 | 서버 검증 | 속도 제한 | 위험도(수정 뒤) |
|---|---|---|---|---|---|
| 52 | RedeemCode (RF · SocialRewardService.lua) | text | 문자열 · 정리 · 3 ~ 24 영숫자 · 코드 표 · 만료 · 계정당 1회(지급 전 표시) · 모든 시도 로그 + Telemetry | 자체 3초 · 분당 8 | 낮음 |
| 53 | CodexRequest (CodexService.lua) | action · arg | view / claim(칸 id · "all" · "board:<점수>" - 완료 = 서버 기록 · 받음 표시) / title(가진 칭호만 · "" = 해제) | 자체 0.2초 | 낮음 |
| 54 | CommunityGoalClaim (RF · CommunityGoalService.lua) | tierIndex | number · 칸 존재 · 서버 합계 도달 · 그 주 기여 ≥ 1 · 받음 · (새) 알 가방 | RequestGate 함수 기본 | 낮음 |
| 55 | ShopRequest (MonetizationService.lua) | action · a · b | 동작 화이트리스트 · 조각 구매(가격 서버 · 시즌 한정 거부 · 소유) · 로벅스 = 서버가 프롬프트(판매 목록 · 정책 · 소유) · 장착(소유 · 패스) · 시즌 칸(canClaim) · 선물(id) · 지급 = ProcessReceipt만 | RequestGate 초당 4 · 통 8 | 낮음 |
| 56 | SpectateRequest (SpectateService.server.lua) | jobId | 문자열 8 ~ 64 · 이 서버 아님 · 보스전 중 거부 · Studio = 이동 안 함 | (새) RequestGate 20초 1번 | 낮음(R4) |
| 57 | WeeklyChallengeStart (WeeklyChallengeService.lua) | 없음 | 보스전 중 · 견습 거부 · 보스 · 스테이지 = 서버 고정 | (새) RequestGate 초당 0.5 · 통 2 | 낮음(D2) |
| 58 | WeeklyChallengeTop (RF · WeeklyChallengeService.lua) | 없음 | 본인 기록 + 공용 순위 표 | (새) 서버 캐시 30초 + RequestGate 초당 1 · 통 3 | 낮음 |

### 3-3. 기존 입구의 새 동작
| Remote | 새 동작 | 서버 검증 | 제한 | 위험도 |
|---|---|---|---|---|
| TravelRequest | checkpoint(id) | 2절 ④ | (새) 기본 통 + 체크포인트 쿨 | 낮음 |
| TravelRequest | cancelRecall(이유) | 시전 중일 때만 · 이유 2종으로 접음 · 쿨 소모 없음 | (새) 기본 통 | 낮음 |
| TravelRequest | tutorialZone | 견습 중 · 보스전 아님 · 목적지 = 그 단계 구역(서버) | (새) 0.2/초 · 통 2 | 낮음 |
| QuestRequest | claim attendance(칸) · main | 칸 = `tonumber` → 표 존재 · 센 날 이하(서버 날짜) · 문자열 키 받음 / 메인 = 서버 facts · 알 가방 사전 확인 | 동작별 0.2초 | 낮음 |
| PartyRequest | board_post · board_remove · board_join | 태그 검증(`PartyBoard.validTags`) · 리더/솔로 · 보스전 · 합류 중 · 역할 = 서버 직업 · 정원 · `checkJoinable` | RequestGate + 동작별 간격(게시 2초 · 참가 1초) | 낮음 |
| SettingsSave | choice · volume 종류 | 선택지 목록 / 0 ~ 1 숫자 · NaN 거절 · 0.01 단위 | 키별 0.1초(trailing) | 낮음 |

## 4. 결정 필요
| ID | 무엇을 | 왜 결정이 필요한가 | 선택지 |
|---|---|---|---|
| D1 | 선물함 대기열 → 선물함 이동 뒤 대기열 지우기(UpdateAsync)가 실패하면 같은 선물이 다음 접속에 다시 들어온다(그 사이 받기를 했으면 **재지급** - 선물함은 "지금 선물함에 같은 id가 있나"로만 거른다) | 막으려면 "받은 선물 id" 기록 = **새 저장 필드**(SAVE_VERSION · migrate)가 필요 - 이번 블록 범위 밖 | (가) `mailbox.claimedIds`(최근 N개)를 두고 옮길 때 거른다(추천) · (나) 지우기 실패 때 이번 세션은 받기를 잠근다(필드 없이 - 다음 접속 전 재시도 없음) · (다) 그대로(DataStore 실패 확률 × 초대자 조각 30 정도의 피해) |
| D2 | 주간 도전 입장 규칙 | 토벌(`BossGate.enterRaid`)은 파티 중 거절 · 진행 조건(raidCheck)을 보는데 주간 도전은 보스전 · 견습만 본다 → 파티 중 혼자 빠져 들어감 · 첫날 계정도 스테이지 40 보스 입장(보상은 처치해야 나와 경제 영향은 없음) · 전투 중 입장(= 사실상 순간이동 탈출) 가능 | (가) 토벌과 같은 규칙(파티 거절 · 최소 진행) · (나) 전투 중(`combatLockSeconds`)만 추가 · (다) 그대로(이벤트 모드라 열어 둠) - 게임 규칙이라 결정 필요 |
| D3 | 초대받은 쪽 보상은 계정 나이와 무관 | 새 부계정을 계속 만들면 그 부계정마다 강화석 20 · 알 1 · 조각 30(거래 기능이 없어 본계정으로 못 옮김 - 지금은 피해 없음) | 거래 · 선물 보내기 기능을 열 때 같이 정한다(지금은 기록만) |

## 5. 남은 위험(기록 - 이번에 안 고침)
| ID | 내용 | 위험 | 비고 |
|---|---|---|---|
| R1 | 합동 목표 MemoryStore가 죽으면 1인 상한이 서버마다 따로(서버를 옮기면 다시 60) | 낮음 | 기여 자체가 서버 처치라 부풀릴 수 있는 폭 = 서버 수 × 보스 처치 속도. MemoryStore 장애 동안만 |
| R2 | RedeemCode가 길이 검사 전에 `gsub` · `upper`(100KB 문자열도 처리) | 낮음 | 3초 제한 안에서 1번 · 하네스로 100KB 거절 확인 |
| R3 | CommunityGoalClaim 넘친 요청은 같은 칸의 마지막 결과(ok = true일 수 있음)를 돌려준다 | 낮음(표시만) | 지급은 안 함 - 연타 때 "받음" 토스트가 한 번 더 뜰 수 있다 |
| R4 | SpectateRequest jobId = 클라 값(서버가 알린 초월 서버인지 대조 안 함) | 낮음 | 같은 게임의 공개 서버로만 이동(예약 서버는 접근 코드 없이 실패) - 친구 따라가기와 같은 수준 |
| R5 | CodexRequest · QuestRequest · RedeemCode · SettingsSave는 RequestGate가 아니라 자체 제한 | 정보 | 동작은 같다(자체 제한이 이미 더 좁음) - 공통 입구로 옮기는 것은 정리 작업 |
| R6 | 기존 하네스(`attack_test` · `request_gate_test`)가 지금 코드에서 시작 전에 멈춘다 | 정보(도구) | `TextData`의 동적 `require(script.Parent[name])`를 build_run 정적 치환이 못 바꿔 `require(nil)` - 새 하네스는 파일 안 대역으로 우회(같은 대역을 `server_prelude.luau`로 옮기면 옛 하네스도 돈다) |

## 6. 확인 방법(로컬 하네스)
```
cd roblox/tools/harness
D=$(python deps.py SocialRewardService,CodexService,CommunityGoalService,WeeklyChallengeService,SpectateService.server,RequestGate,QuestService,PlayerProfile,SaveSystem,Travel)
LUAU=<luau.exe> PRELUDE=server_prelude.luau EXTRA_SERVER=$D ECON_RES=res_sec.txt python build_run.py security_launch_test.luau   # 결과 = %TEMP%/res_sec.txt
```
- 결과: **41/41**(수정본) · 대조 = 고치기 전 6개 파일(HEAD)로 바꾼 사본(`ECON_SRC` · `DEPS_SRC`)에서 **30/41** - X 11개가 전부 위 L1 ~ L9 자리(그중 "시전 · 바로 또"는 L4의 연쇄, "구경 가기 연타"는 옛 자체 쿨을 RequestGate 버림 수로 못 세는 측정 차이).
- 항목(41): 코드 6(정리 9종 · 대소문자 · 연타 · 계정당 1회 · 만료 경계 · 표 인자) · 초대 6(자기 초대 · 정상 · 같은 쌍 · 3일 계정 · 저장 있는 계정 · 하루 상한) · 도감 5 · 합동 목표 7 · 주간 도전 5 · 체크포인트/귀환/TravelRequest 10 · 구경 가기 2.
- 바꾼 Luau 6개: `luau-compile --binary` 통과 · `luau-analyze` Unknown global = Roblox 기본 전역(game · script · workspace · Instance · Enum · task · warn · CFrame · RaycastParams)뿐.

## 7. Studio에서 확인할 것(Play - 이번 블록은 Studio 미사용)
| 확인 | 방법 | 기대 |
|---|---|---|
| 주간 도전 정상 입장 1회 | 퀘스트 창 [주간 도전] → [도전] 1번 | 보스 등장 · 콘솔 `주간 도전 등장` 1줄 |
| 주간 도전 연타 | [도전]을 빠르게 5번(보스전 밖, 스폰 실패 상황이면 더 좋다) | `주간 도전 등장` ≤ 1줄(보스전이 열리면 이후는 "지금은 시작할 수 없어요") |
| 순위 창 | 허브 업데이트 게시판 · 퀘스트 창 순위를 번갈아 여러 번 | 표가 뜬다 · 처치 직후 내 기록은 바로 보이고 상위 표는 최대 30초 늦게 갱신 |
| 체크포인트 잠긴 구역 | 견습 계정으로 tier2+ 입구 근처 발견 → 견습 끝 → 지도에서 그 체크포인트 이동 | "이동 불가 - 아직 열리지 않은 구역의 체크포인트" · 열린 구역은 정상 시전 3초 |
| 견습 바로 가기 | 견습 중 바로 가기 버튼 연타 | 처음 2번만 이동 · 이후 5초에 1번 |
| 합동 목표 알 칸 | `/gg` 등으로 알 가방 40칸 채운 뒤 85% 칸 [받기] | "알 가방이 가득 찼습니다" · 칸은 받지 않은 상태로 남음 |
| 구경 가기 | (라이브 2서버) 초월 알림 → [구경 가기] 두 번 | 첫 번 이동 시도(Studio = 안내 문구) · 20초 안 두 번째 = "잠시 뒤에 다시" |

## 8. 운영 위험 목록 갱신(QUEUE-ALL6 F · 2026-10-02) - 탐지 · 복구 · 차단

> 원칙: 자동 처벌 없음(기록만) · 이동 이상 = 되돌림만 · 복구는 그 사람만. 절차 = `docs/phase/security-runbook.md` · 기준값 = `shared/data/SecurityOpsConfig.lua` · 시험 = 하네스 `ops_security_test.luau`(19/19).

| 위험 | 지금 방어 | 남은 구멍 | 이번 조치 |
|---|---|---|---|
| 이동 조작(속도 · 비행 · 순간이동 - 캐릭터 물리는 클라 소유) | `HeightGuard`(G2a · S1): 높이 = 서 있던 발 + 허용치(해금 공중 점프 수) · 수평 = 합법 속도 통 + 대시 · 밀림 허가 · 순간이동은 서버 `Travel.teleport`만 예외 · 넘으면 **마지막 정상 위치로 되돌림**(킥 없음) · 공중 정체 검사 | 되돌림만 하고 반복 횟수를 사람별로 모아 보지 않음 | 탐지 `suspect_move`(분당 되돌림 ≥ 8 → 의심 기록) - 처벌 없음 |
| 원격 요청 폭주 | `RequestGate`(사람 × Remote 토큰 통) + 자체 제한 5 | 버린 요청을 사람별로 기록하지 않음 | 탐지 `suspect_requests`(분당 버림 ≥ 60) |
| 자동 사냥 스크립트 | 공격 간격 · 사거리 · 처치 경합 = 서버 · 처치 속도(`killRate` 60초 240) | 오래 켜 두는 "적당한 속도" 봇은 숫자로 못 가림 | 처치 · 명중/분(`suspect_hits` 2,500) · 골드/분 기록 → 신고 + inspect로 판단(차단은 사람이) |
| 복제(동시 요청 · 서버 이동 중 경합) | 지급 전 표시(yield 없음) · 영수증 기록 먼저 · 세션 잠금 · 저장 낙관적 동시성 · 선물 받은 id(v62) · 하네스 dupe 7/0 | 새 경로가 생기면 다시 생길 수 있음 | 감사 기록(획득 · 큰 골드 · 구매 · 지급)으로 **영향 계정만** 찾기 + `rollback`(그 사람만 · 백업 먼저) |
| 드랍 · 보상 조작 시도 | 드랍 굴림 · 보상 계산 = 서버 · 태초/초월 원장(굴림 id) · 원장 없는 태초 = 격리 · 포아송 운 검사 | 초월 회수 명령이 없었음 | `/ops revoke t<번호>`(아이템 삭제 · 결번 · 명예의 전당 · 칭호 · 도감 줄) · 재화 회수 |
| 순위 · 주간 도전 기록 조작 | 처치 시간 = 서버 `os.clock` · 속도 봉투 보류 · 높이 위반 뒤 기록 거절 · NaN 거절 | 주간 도전 기록 제거 명령 없음 · 진입 무적 직후 처치 같은 이상을 따로 안 봄 | `/ops leaderboard remove`(개인 · 직업 · 주간) · 탐지 `suspect_boss_time`(진입 연출 뒤 1초 안 처치) |
| 가짜 초월/태초(세계 번호 위조) | 번호 = 서버 DataStore 카운터 · 원장 대조 · 각인은 서버만 씀 | 저장 손상 · 운영 실수로 생긴 가짜는 수동 처리 | 감사 기록에 세계 번호 · 출처 · 굴림 id · 초월 회수 명령 |
| 코드 · 초대 악용 | 계정당 1회 · 3초 · 분당 8 · 초대 = 계정 나이 7일 · 하루 5 · 1쌍 1회 | 부계정 초대받은 쪽 보상(거래 없어 이동 불가) | 감사 기록 `social`(코드 · 초대 지급) |
| 거래 | **없음**(플레이어 간 아이템 · 재화 이동 기능 없음 - 서버 코드에 trade 경로 0 · 선물은 운영 · 초대 보상만) | - | 복제의 주된 경로(거래 경합)가 없다 - 거래를 열 때 이 표를 다시 본다 |

### 8-1. 탐지 지표 · 기준값(`SecurityOpsConfig.detect` - 60초 창 · 같은 종류 10분에 한 번)
| 지표 | 기준 | 정상 최대(근거) |
|---|---|---|
| 이동 되돌림 / 분 | 8 | 대시 · 활강 · 지연으로 가끔 0 ~ 2(QUEUE-STUDIO C-2 활강 보정 0줄) |
| 골드 / 분(잡몹 몇 마리 몫) | 4,000 | 광역 처치 + 보상 몰아 받기 약 1,500 |
| 명중 / 분 | 2,500 | 평타 + 광역 5마리 + 스킬 틱 약 1,200 |
| 요청 제한 버림 / 분 | 60 | 정상 연타 몇 개 |
| 보스 처치 시간 | 진입 연출 끝 뒤 1.0초 미만 | 진입 연출 동안 무적 - 낮은 스테이지 한 방도 연출 뒤 |
| 처치 / 60초 · 보스 클리어 / 시간 | 240 · 120(옛 S1 그대로) | - |
| 태초 운 | 포아송 P < 1e-6(옛 S1 그대로) | - |

### 8-2. 감사 기록(`AuditTrail_v1` 키 u<userId> · 최근 200 · 90일)
태초/초월 번호(출처 · 굴림 id) · 강화 +20 이상 성공 · 한 번에 잡몹 20,000마리 몫 넘는 골드 · 로벅스 구매(상품 · PurchaseId) · 조각 구매 · 코드/초대 지급 · 선물 받기 · 운영 명령(대상 쪽). 60초마다 · 퇴장 · 서버 종료 때 모아 쓰기(UpdateAsync 1번).
