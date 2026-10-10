# SEC-FIX-1 상태 (보안 · 저장 · 악용 경로 고치기)

> 원문 = `claude-design-handoff/_inbox/verify/VERIFY-6-SEC2-report.md`(기준 39bac6d2) · 지시 = `claude-design-handoff/CC-SEC-FIX-1-prompt.md`.
> 규칙: 삭제 금지 · 저장 필드 추가만 · force-push 금지 · 키 출력 금지 · 고칠 때마다 재현 하네스("옛 코드 실패 → 새 코드 통과").
> 옛 코드 확인 = 작업 전 HEAD(aad99030)의 `roblox/src`를 `git archive`로 스크래치패드에 떠서 `ECON_SRC=<그 경로>`로 같은 하네스 실행.
> 하네스 전체 = `LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh`(기대 검사 수 고정 · 결과 파일 선삭제).

## 진행

| 번호 | 항목 | 상태 | 커밋 | 재현 하네스(옛 → 새) |
|---|---|---|---|---|
| 1 | 칸 전환 중 자동저장 · 받음 표시와 보상 같은 저장 단위 | 끝 | c75bea32 | `sec_save_test` 1-a · 1-b · 1-c: 옛 5/9 → 새 9/9 |
| 5 | 구역 밖 사냥 · 공격(덫 · 화살비 · 보스 아레나 · 상자 흡혈/충전) | 끝 | 1eb06506 | `sec_zone_test` 옛 5/11 → 새 11/11 |
| 6 | 폴링 사이 순간이동 공격 | 끝 | 848956ef | `sec_move_test` 옛 5/8 → 새 8/8 |
| 7 | 보석 판매가 차익(#7 · #8) · 일괄 분해 개수(#10) | 끝 | 2cb4d544 | `sec_econ_test` 옛 4/7 → 새 7/7 |
| 8 | 패스 칸 건너뛰기 = 못 한 출석 따라잡기(#6 · 사용자 결정 10-11) | 끝 | (이 커밋) | `sec_shop_test` 8: 옛 6/14 → 새 14/14 |
| 2 | 같은 서버 재접속 저장 멈춤(AUDIT1 #15) | 끝 | 1bd638ec | `sec_save_test` 2: 옛(c75bea32) 10/13 → 새 13/13 |
| 3 | 결제 applyReward 에러 시 잠금 안 풀림 | 끝 | 71d0eae9 | `sec_shop_test` 3: 옛 1/6 → 새 6/6 |
| 4a | 교환 코드 표 → 서버 전용 | 끝 | c631de4f | `sec_secret_static` 옛 2/6 → 새 6/6 · `security_launch` +2(게시판 공개분만) |

## 1. 칸 전환 중 자동저장 끼어듦

- 원인(하네스로 확인): 전환 flush 뒤 새 칸을 읽는(yield) 동안 자동저장이 옛 프로필 · 옛 세션으로 계정 키를 씀 → 새 세션의 계정 기준 시각이 낡아 이후 계정 키 저장이 전부 `stale_session`(그 접속 저장 중단) · 캐릭터 키만 써져 보상(골드)은 남고 "받음" 표시(계정 키)는 빠짐 → 재접속 뒤 다시 받기.
- 고침
  - `SaveCoordinator.setSwitchLocked` - `SlotSwitch.switch`가 flush 성공 직후 켜고 새 프로필 자리 잡은 뒤(성공 · 실패 모두) 끈다. 잠금 중 `saveForPlayer` = 건너뜀(앞 저장을 기다린 뒤에도 다시 확인).
  - `SaveSystem.saveSlotProfile` 순서 = **계정 키 → 캐릭터 키**(옛 = 캐릭터 → 계정). 계정 키가 실패하면(장애 · stale) 캐릭터 키도 안 씀 = 보상 · 표시가 함께 다음 저장으로. 새 캐릭터 첫 저장(캐릭터 키 없음)만 캐릭터 키 먼저(계정 칸이 없는 키를 가리키면 다음 로드 = `missing_character`).
- 하네스 `sec_save_test`: 1-a 전환 중 1.1초 자동저장 → 전환 뒤 첫 저장 성공 · 재접속 뒤 보상 ⇒ 표시 / 1-b 계정 키 4회 실패 → 캐릭터 키 골드 그대로 / 1-c 새 캐릭터 키 실패 → 계정 칸 안 생김.
- 남은 위험: 계정 키 성공 뒤 캐릭터 키만 재시도 소진(4회)하고 그 직후 서버가 죽으면 "표시는 있고 보상은 없음"(손실 · 복제 아님 - 다음 저장 · 퇴장 저장이 다시 씀). DataStore에 두 키를 한 번에 쓰는 방법이 없어 0으로 만들 수는 없다.

## 2. 같은 서버 재접속 시 저장 멈춤(AUDIT1 #15)

- 원인(하네스로 확인 - 실제 `SaveServer.server.lua`를 가짜 Players로): 퇴장 저장이 재시도 대기 중일 때 같은 서버로 다시 들어오면 새 로드가 먼저 읽는다(같은 서버 표식이라 세션 잠금 대기도 없음) → **옛 값으로 시작**(하네스: 골드 12345 → 5000) + 늦게 끝난 퇴장 저장이 savedAt을 올려 새 세션 저장이 `stale_session`으로 그 접속 내내 멈춤. 옛 판정(보고서)보다 나쁨 = 진행 손실도 있음.
- 고침: `SaveCoordinator.beginLeave/endLeave`(퇴장 저장을 UserId로 셈 - `saving`은 Player 키라 새 인스턴스와 이어지지 않음) · `waitForLeaveSave` · `SaveServer.loadForPlayer`가 로드 전에 기다림(상한 `SaveConfig.leaveSaveWaitMaxSeconds` = 30 · 기다린 뒤 나갔으면 로드 안 함).
- 순서: 퇴장 = beginLeave → markReleasing(놓음) → flush → clear → 세션 잊기 → endLeave / 로드 = 대기 → 읽기(놓은 값 · 최신 savedAt).
- 하네스 `sec_save_test` 2: 접속 → 진행 → 퇴장(계정 키 첫 시도 장애 = 1초 재시도) → 0.3초 뒤 같은 서버 재접속 → 로드 값 · 자동저장 한 주기 · 다시 퇴장.
- 남은 위험: 퇴장 저장이 30초를 넘으면(DataStore 장기 장애) 기다리기를 멈추고 읽는다 - 옛 동작과 같음(그 뒤는 stale 안내 "다시 접속해 주세요"). 다른 서버로 옮겨 접속은 기존 약한 세션 잠금(10초) 그대로.

## 3. 결제 applyReward 에러 시 잠금 안 풀림

- 원인(하네스로 확인): `processReceipt`가 `inFlight` · `busyPlayers`를 올린 뒤 영수증 기록 · 지급을 pcall 없이 부름 → 지급 함수 런타임 에러면 `done()`이 안 불려 그 서버에서 그 구매(영영 NotProcessedYet) · 토큰 구매 · 시즌 받기 · 선물 받기가 막히고, 기록된 영수증 + 부분 지급이 메모리에 남아 자동저장으로 써질 수 있었다.
- 고침: 영수증 기록 ~ `applyReward`를 pcall 한 구간으로. 에러 = `undo`(영수증 기록 · 이번 지급 · promptSeason 되돌림 - 그것도 pcall) + `done()` + warn + 기록 `grant_error` + **NotProcessedYet**(PurchaseGranted 반환 안 함 - Roblox가 다음에 다시 부른다).
- 하네스 `sec_shop_test` 3: 지급 함수가 앞 지급(테마) 뒤 에러 → 에러 안 새어 나감 · 잠금 풀림 · 영수증 · 테마 되돌림 · 재시도 = PurchaseGranted · 토큰 구매 입구 동작.
- 남은 위험: 에러가 계속 나는 상품은 접속마다 NotProcessedYet 반복(지급 0 · 기록 `grant_error` 한 줄) - 운영이 구매 기록으로 확인 · 환불.

## 4. 클라에 보이는 비밀

### 4a. 교환 코드
- 원인: `shared/data/SocialRewardData.codes`(ReplicatedStorage) → 변조 클라가 require로 공지 전 코드(hidden)까지 읽고 바로 입력 가능 · 켜기 전(inactive) 코드도 켜는 순간 이미 알려짐.
- 고침: 코드 표 → `server/SocialCodeData.lua`(ServerScriptService = 클라 복제 안 됨 · `OpsConfig`와 같은 자리). **ServerStorage가 아니라 server 폴더**인 이유 = `default.project.json`에 ServerStorage 매핑이 없고, 프로젝트 파일 변경은 실행 중 rojo가 반영 못 해 사용자 재시작이 필요 - 복제 안 됨이라는 효과는 같다.
  - 옛 자리(`SocialRewardData.codes`)는 **남기지 않음**(남기면 비밀이 그대로 보임) - 주석으로 새 자리 표시. 쿨다운 · 문구 · 초대 수치 · 소식은 shared 그대로.
  - 검사 = 서버 `SocialRewardService.find`만. 게시판 = 새 RemoteFunction `BoardCodes`(RequestGate.invoke) → `SocialRewardService.boardCodes` = hidden · inactive · 만료 뺀 줄의 코드 · 설명 키 · 기한만(보상 · 목표 수 안 보냄). `client/UpdateBoard`는 처음 그릴 때 한 번 받음.
- 하네스: `sec_secret_static.py`(복제 폴더 shared · client · first에 코드 문자열 · 코드 표 모양 · 클라 직접 읽기 · 서버 설정 사본 0) 옛 2/6 → 새 6/6 · `security_launch_test` +2(게시판 공개분만 · 만료 빠짐).
- 운영 절차 바뀜: 좋아요 목표 달성 = `server/SocialCodeData.lua`의 그 줄 inactive · hidden 지우기(옛 = shared 파일).

### 4b. 다른 비밀 후보 전수 표(조사 범위 = src/shared · src/client · src/first 전체 · 웹훅 · URL · API 키 · 토큰 = 0건)

| # | 어디(옛) | 무엇 | 클라 사용 | 위험 | 처리 → 어디로 |
|---|---|---|---|---|---|
| 1 | shared/data/SocialRewardData.codes | 교환 코드 4개(숨김 1 · 안 연 단계 2) | 게시판 | 높음 | **옮김** → server/SocialCodeData(4a) |
| 2 | shared/data/SecurityOpsConfig(파일 통째) | 치트 탐지 기준값 · 차단 규칙 · 감사 저장소 이름 | 없음 | 중(기준 바로 아래로 맞춰 탐지 회피) | **옮김** → server/SecurityOpsConfig(git mv · 옛 자리 안 남김) |
| 3 | shared/data/LeaderboardConfig.excludedUserIds | 운영(개발) 계정 UserId 1개 | 없음 | 중(운영 계정 노출 - 권한 판정은 서버 OpsConfig) | **옮김** → server/OpsConfig.leaderboardExcludedUserIds(쓰는 곳 3: Leaderboard · TranscendFirsts · P3dVerify) |
| 4 | shared/data/NestData.pickup | 둥지 줍기 서버 검증 기준(반경 · 표본 · 최대 속도) | 없음 | 중 · 하(순간이동 속도를 기준 아래로) | **옮김** → server/NestPickupData(NestServer) |
| 5 | shared/data/LeaderboardConfig.antiCheat | 리더보드 이론 최대 DPS 계수 | 없음 | 하 · 중 | **안 옮김(이유)**: shared/LeaderboardRules(순수 함수 · 하네스가 씀)가 읽는다 - shared 모듈은 서버 경로를 require할 수 없다. 계수를 알아도 "이론 최대보다 빠른 기록"만 막는 상한이라 아래로 맞춰도 정상 기록 범위다 |
| 6 | shared/data/MonetizationData(공개 단계 2 상품 9 · 제안 묶음 1 · 출시일 자리값) | 미공개 상품 가격 · 구성 | 상점 · 추천 · 미리보기 | 하(스포일러 - 구매는 서버 isReleased가 막음) | **결정 필요**: 상품 줄을 서버로 빼려면 상점 UI가 서버 목록을 받게 바꿔야 함. 치장 자체(이름 · 모양)는 CosmeticSlotData에 이미 공개 · 패스 보상으로 화면에도 나옴 → 숨기는 이득이 가격 · 묶음 구성뿐 |
| 7 | server/SecretNestData + shared/data/NestData 합치기 | 비밀 둥지 C 40곳 좌표 | 없음(클라는 A · B만) | 처리됨 | 그대로(이미 서버) |
| 8 | shared/data/CosmeticSlotData · SeasonPassData | 시즌 1 패스 · 출석판 전용 치장 · 할로윈 | 상점 · 캐릭터 · 출석판 | 하(현재 시즌 · 화면에 보임) | 그대로. 다음 시즌 표는 공지 전까지 서버 쪽에 둘 것(운영 규칙) |
| 9 | shared/data/TitleData 히든 칭호 1 | 이름 · 조건 문구 | 이름표 · 캐릭터 | 하(업적 스포일러 · 서버가 ???로 가림) | 그대로 |
| 10 | ClassData 출시 예정 직업 · BossData `enabled = false` 등 꺼진 기능 | 설계 · 연출 | 일부러 Coming Soon 표시 | 하 | 그대로 |
| 11 | DataStore · 토픽 이름 약 25개(SaveConfig · AuditConfig · …) | 저장소 이름 | SlotSaveData만 | 하(클라는 DataStore · MessagingService 접근 불가) | 그대로(이름을 알아도 접근 수단 없음) - 라이브 이름은 11번 항목 |
| 12 | DropTableData · EggData · RareMonsterConfig | 확률 | 확률 공개 창 | 없음(공개 의도) | 그대로 |
| 13 | shared/Quest.lua 일일 퀘스트 시드 = 날짜 | 다음 날 퀘스트 계산 가능 | 간접 | 하 | 그대로 |

- 하네스 `sec_secret_static.py` +3: 탐지 기준 모듈 = 서버 · 운영 계정 UserId(OpsConfig에서 읽음)가 복제 폴더 0 · 줍기 기준 = 서버. 옛 1/9 → 새 9/9.
- **사용자 확인 필요(되돌릴 수 없는 것)**: 옛 버전(코드 표가 shared에 있던 버전)이 라이브로 배포된 적이 있으면 숨김 · 안 연 코드 3개는 이미 알려졌다고 보고 이름을 바꾸는 게 맞다. 저장소가 공개라면 git 이력(커밋 메시지 포함)에도 남아 있다 - 이름 교체만이 해결.

## 5. 구역 밖 사냥 · 공격

- 원인(하네스로 확인): ① 판정이 `ZoneBounds.isInside(공격자, 대상 zoneKey)` - 보스는 zoneKey가 없어 **항상 통과** → 아레나 벽 너머(비멤버)도 맞음 ② 화살비 후보 = 조준점 기준 · 덫 발동 필터 = 덫 자리 기준 → 담장 밖에서 안쪽을 조준하면 안전 사냥(하네스: 담장 밖 화살비가 몹을 맞힘) ③ 보물상자가 세지 않은 연타도 피해를 그대로 돌려 흡혈 · 궁극기 충전(스킬 경로는 계수로 충전해 피해 0이어도 참).
- 고침
  - 새 `server/AttackZone.lua` = 판정 한 곳: `canHit`(잡몹 = 공격자가 그 구역 안 · **보스 = 그 보스전 멤버만** · 보스전 밖 전시 보스 = 옛 계약) · `sameArea`(조준점이 시전자와 같은 구역 · 아레나) · `filter`.
  - 평타(`AttackServer` 근접 대상 · 원거리 경로 대상) · 스킬(`SkillServer.filterSameZone` 호출 8곳 - 이제 사람을 받음) · 궁극기 후보(`UltimateService.candidates` = **캐스터 위치** 기준 · 화살비는 시전 순간 자리) 모두 AttackZone.
  - 덫: 설치 때 `sameArea(시전자, 조준점)` 아니면 거절 `zone`(쿨 안 씀) · 발동 필터 기준 = 설치한 사람 자리. 화살비: 같은 검사 · 거절이면 게이지 안 씀.
  - 보물상자: 세지 않은 타격 = 들어간 피해 0(`MonsterState.applyDamage`) · `UltimateService.onDealt` = 상자 대상이면 충전 없음.
  - 벽 판정 = 레이캐스트가 아니라 구역 · 아레나 경계(지형 · 소품 오탐 없음 · 하네스 재현 가능).
- 하네스 `sec_zone_test`(실제 MonsterState · UltimateService · AttackZone - 옛 코드는 AttackZone이 없어 옛 판정 그대로): 보스 비멤버 · 잡몹 담장 밖 · 조준점 구역 · 화살비 담장 밖 조준(옛 = 발동 + 맞음) · 게이지 · 정상 경로 · 상자 연타 피해 · 상자 충전 · 정상 충전.
- 남은 위험: 세어진 상자 타격(사람당 간격 1번 · 상자당 15번)은 여전히 피해를 돌려 흡혈이 소량 들어간다(상자 숫자 표시와 묶여 있음 - 이득 상한 있음). 원거리 평타의 벽 판정은 기존 레이캐스트 그대로. Studio 실측은 안 함(아래 Play 확인 목록).

## 6. 0.25초 위치 검사 사이 순간이동 공격

- 원인: 수평 이동 검사는 0.25초 폴링끼리만 비교 · 공격 · 스킬은 요청 순간 서버 위치로 판정 → 폴링 사이에 대상 옆으로 옮겨 치고 돌아오기. 폴링 통(bucket 1.5초 ≈ 42 stud)이 차 있으면 한 번 42 stud도 합법.
- 고침: `HeightGuard.requestPositionOk`(순수 · 소비 없음) = 마지막 검증 자리(`hGood`)에서 **합법 속도 × (경과 + `requestJitterSeconds` 0.5) + 남은 대시 · 밀림 허가 + 여유 3** 안인가(통은 안 씀) · `HeightGuard.checkRequest`(입구용 - 거절 = 그 요청만 무시 · 누적 `requestRejects` · warn 5초에 한 번 · 킥 없음). 평타(AttackServer - 쿨 · 콤보 안 씀) · 스킬(SkillServer - 쿨 안 씀 · 거절 `position`) · 궁극기 입구가 부름.
  - 통과 계약 = 폴링과 같음: 붙잡힘 예외 · 서버 순간이동 유예 · 기준 없음 · 고정 · 사망 · `debugOff`(검증 체인).
  - 수치 = `MovementConfig.moveGuard.requestJitterSeconds`(data).
- 하네스 `sec_move_test`(실제 HeightGuard - 폴링 evaluateHorizontal로 상태를 만든 뒤): 200 stud · 40 stud(통 가득) 순간이동 = 거절(옛 = 통과) / 걷기 · 지연 흔들림 · 대시 직후 · 발사 허가 · 예외 · 유예 = 통과.
- 남은 위험: 허용 안(걷기면 0.1초 뒤 약 19 stud)의 짧은 순간이동은 여전히 가능(근접 사거리보다 크다) - 오탐(지연)과의 맞바꿈. 심한 지연(1초 넘게 위치가 안 옴) 중 공격은 거절될 수 있다(요청 무시만 - 다음 폴링이 따라잡으면 정상). Studio 실측 안 함.

## 7. 보석 판매가 차익 · 일괄 분해 개수 불일치

- 원인(하네스로 확인 - **보고서 "중"보다 큼**): 보석 판매가 스테이지 = 계정 최고 스테이지. 최고 20,000 계정이 스테이지 1에서 주운 영웅을 바로 팔면 24골드, 분해 → 보석 판매하면 **약 118억 골드**(16조합 전부 차익). 일괄 분해는 기준 등급만 보내 확인 창 뒤에 주운 영웅까지 분해.
- 고침
  - `GemCraft.sellStage(gem, stageCap)` = 보석 자신의 레벨(itemLevel - 주운 스테이지 척도) · 상한 = 넘긴 스테이지(계정 최고). `GemCraft.sellPrice(gem, stageCap)` 인자 자리 그대로(클라 표시 · 서버 sellGem 호출부 변경 없음 - 뜻만 상한).
  - 장비 바로 팔기 바닥(`Loot.getSellPrice`) = `GemCraft.sellPrice(Loot.dismantleReward(item))`(분해해서 나올 그 보석과 같은 레벨 기준) → 분해 → 판매 ≤ 바로 팔기 항상.
  - 저장 필드 추가 없음(보고서 안 "보석에 dropStage 싣기" 대신 이미 있는 itemLevel - 분해 보석 itemLevel = 장비 itemLevel ≤ dropStage + 2).
  - 일괄 분해: 클라(옛 확인 창 · v2 창)가 보여 준 개수를 같이 보냄 → `PlayerProfile.dismantleItemsUpTo(player, 등급, expectedCount)`가 다시 세서 다르면 0 · `count_mismatch` → 클라 = 판매와 같은 안내 + 새 개수로 창 다시. 개수 없는 요청 = 무시(서버 내부 · `/gg`는 nil = 대조 안 함).
- 판매가 ≤ 얻는 비용 전수(하네스): ① 분해 경로 4등급 × 스테이지 4 ② 재련 경로(대상 4 × 먹이 4 등급 × 레벨 12쌍: 판매가 상승 ≤ 먹이 판매가 + 재련 골드 - 가루는 공짜로 쳐도) ③ 판매가 ≤ 가루 가치. 구매 경로 = 보석을 파는 상품 없음(변환권만 · 보석 아님) · 환생 지급 보석 = 무료(판매가가 옛보다 내려가기만).
- 영향: 고스테이지 계정이 가진 **낮은 레벨 보석의 판매가가 내려감**(옛 = 계정 최고 기준). 같은 레벨이면 그대로. 밸런스 결정이 필요하면 GOLD-CURVE와 함께(BAL-LOCK 전).

## 8. 패스 칸 건너뛰기 = 못 한 출석 따라잡기로만(AUDIT1 #6 · 사용자 결정 10-11)

- 해석(가정 - 다르면 알려 주세요): "출석" = **시즌 출석판 센 칸**(`quests.board.count` - 하루 첫 접속 1칸 · 서버 UTC 날짜 = 출석 초기화와 같은 기준). "따라잡을 칸 있음" = 센 칸 < 시즌 시작부터 지난 날 수(오늘 포함). 출석판 32칸을 다 채웠으면 놓친 날이 없는 것으로 친다(그 뒤는 셀 수 없음). 사는 것 = 기존과 같은 **패스 경험치 1칸**(출석판 칸이 아님 - 출석판은 "로벅스로 칸을 사는 기능 없음" 원칙 유지).
- 규칙(전부 서버 `SeasonPassService.catchUp` - 프롬프트 · 영수증 · 화면 같은 판정): ① 따라잡을 칸 0 → 잠김 `caught_up` ② 하루 1번(`seasonPass.skipDay` = 산 UTC 날짜) → `today` ③ 한 번에 1칸(`SeasonPassData.skip.perDay` 1 · `pass_skip5` = 공개 단계 2로 숨김 · 상품 자리 남김) ④ 사면 오를 칸 ≤ **매일 출석한 무료 유저가 오늘까지 닿는 칸**(`SeasonPassService.paceExp` = 시즌 첫날 ~ 오늘 매일 접속 + 그날 일간 전부 + 일일 상자 · 주말 2배 + 시작한 주마다 주간 전부 - 가장 빠른 무료 유저 쪽으로 넉넉하게) → `ahead` ⑤ 시즌 상한 20 · 40칸 → `cap` ⑥ 시즌 시작일 미정(`LeaderboardConfig.firstSeasonDateKst` nil - 지금 상태) → `no_date`(잠김).
- 화면: 살 수 있으면 "놓친 출석을 오늘 1칸 따라잡을 수 있어요 …" · 막히면 이유 한 줄(`season.skipLock.*` ko/en - 압박 문구 없음). 버튼은 기존대로 방이 모자라면 꺼짐.
- 조건 밖 영수증(창을 연 뒤 날이 바뀜 · 다른 기기 등): 칸 안 올림 → **기존 토큰 환산 경로**(상품 robux 비례 꾸미기 토큰 - "환불 경로") · PurchaseGranted. "다음에 처리(NotProcessedYet)"는 고르지 않음 - 조건이 계속 안 맞으면 접속마다 재시도만 쌓이고 로벅스는 이미 나갔다.
- 저장: **SAVE_VERSION 76 → 77** · `seasonPass.skipDay`(추가만 · 옛 = -1 · migrate v77 · `SlotSaveData.addedFields` 등록 = 계정 키). 되돌리기(저장 실패)는 하루 표시도 되돌린다.
- 하네스 `sec_shop_test` 8(실제 MonetizationService · SeasonPassService · 시즌 시작 = 5일 전): 출석 다 함 → 프롬프트 거절 · 이유 caught_up / 하루 놓침 → 1칸 · 오늘 표시 / 같은 날 두 번째 → 거절 · 영수증 = 칸 안 오름(토큰) / 영수증 멱등 / 매일 출석 유저 도달 칸 → 거절 / 5칸 묶음 거절 / v76 → v77 이관. `monetize_test`의 옛 건너뛰기 검사(칸 표시 · 토큰 환산 · 되돌림 · 60경우 영수증)는 기계 동작 검사라 따라잡기 조건 대신 옛 시즌 상한 판정을 하네스 대역으로 둠(게임 코드 분기 없음 · 86/86).
- 사용자 확인 필요: ① 위 "출석 = 출석판 센 칸" 해석 ② 시즌 시작일을 정하기 전까지 따라잡기는 잠김(no_date) ③ `pass_skip5`(99R$)는 숨김 - Creator Hub에 상품을 만들 때 1칸 상품만 만들면 된다.
