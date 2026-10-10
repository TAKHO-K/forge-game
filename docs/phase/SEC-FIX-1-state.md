# SEC-FIX-1 상태 (보안 · 저장 · 악용 경로 고치기)

> 원문 = `claude-design-handoff/_inbox/verify/VERIFY-6-SEC2-report.md`(기준 39bac6d2) · 지시 = `claude-design-handoff/CC-SEC-FIX-1-prompt.md`.
> 규칙: 삭제 금지 · 저장 필드 추가만 · force-push 금지 · 키 출력 금지 · 고칠 때마다 재현 하네스("옛 코드 실패 → 새 코드 통과").
> 옛 코드 확인 = 작업 전 HEAD(aad99030)의 `roblox/src`를 `git archive`로 스크래치패드에 떠서 `ECON_SRC=<그 경로>`로 같은 하네스 실행.
> 하네스 전체 = `LUAU=<luau.exe> bash roblox/tools/harness/run_all.sh`(기대 검사 수 고정 · 결과 파일 선삭제).

## 진행

| 번호 | 항목 | 상태 | 커밋 | 재현 하네스(옛 → 새) |
|---|---|---|---|---|
| 1 | 칸 전환 중 자동저장 · 받음 표시와 보상 같은 저장 단위 | 끝 | c75bea32 | `sec_save_test` 1-a · 1-b · 1-c: 옛 5/9 → 새 9/9 |
| 2 | 같은 서버 재접속 저장 멈춤(AUDIT1 #15) | 끝 | (이 커밋) | `sec_save_test` 2: 옛(c75bea32) 10/13 → 새 13/13 |

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
