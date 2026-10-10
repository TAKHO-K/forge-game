# SEC-FIX-1 상태 (보안 · 저장 · 악용 경로 고치기)

> 원문 = `claude-design-handoff/_inbox/verify/VERIFY-6-SEC2-report.md`(기준 39bac6d2) · 지시 = `claude-design-handoff/CC-SEC-FIX-1-prompt.md`.
> 규칙: 삭제 금지 · 저장 필드 추가만 · force-push 금지 · 키 출력 금지 · 고칠 때마다 재현 하네스("옛 코드 실패 → 새 코드 통과").
> 옛 코드 확인 = 작업 전 HEAD(aad99030)의 `roblox/src`를 `git archive`로 스크래치패드에 떠서 `ECON_SRC=<그 경로>`로 같은 하네스 실행.
> 하네스 전체 = `LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh`(기대 검사 수 고정 · 결과 파일 선삭제).

## 진행

| 번호 | 항목 | 상태 | 커밋 | 재현 하네스(옛 → 새) |
|---|---|---|---|---|
| 1 | 칸 전환 중 자동저장 · 받음 표시와 보상 같은 저장 단위 | 끝 | c75bea32 | `sec_save_test` 1-a · 1-b · 1-c: 옛 5/9 → 새 9/9 |
| 2 | 같은 서버 재접속 저장 멈춤(AUDIT1 #15) | 끝 | 1bd638ec | `sec_save_test` 2: 옛(c75bea32) 10/13 → 새 13/13 |
| 3 | 결제 applyReward 에러 시 잠금 안 풀림 | 끝 | 71d0eae9 | `sec_shop_test` 3: 옛 1/6 → 새 6/6 |
| 4a | 교환 코드 표 → 서버 전용 | 끝 | (이 커밋) | `sec_secret_static` 옛 2/6 → 새 6/6 · `security_launch` +2(게시판 공개분만) |

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
