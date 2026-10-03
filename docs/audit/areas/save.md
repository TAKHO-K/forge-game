# 감사 영역: 저장 · 마이그레이션 · 저장 버전

읽기 전용 감사(2026-10-04). 대상: `roblox/src/server/SaveSystem.lua` · `SaveCoordinator.lua` · `ImmediateSave.lua` · `SaveServer.server.lua` · `PlayerProfile.lua`(저장 · 스냅샷 · 설정) · `shared/data/SaveConfig.lua`(saveVersion 69) · `shared/IdRegistry.lua` · `DevTools.server.lua`(백업 · 복원) · `AcquisitionAudit.lua` · `PrimordialRegistry.lua`, 그리고 저장 경로에 걸린 `MonetizationService.processReceipt` · `PartyCrossServer`의 텔레포트 flush · `InventorySync.capacity`.
하네스 `save_launch_test` · `save_lock_test` · `migrate_curve_test` · `id_quarantine_test` · `monetize_test`가 이미 다루는 것(이관 체인 전 버전 · 손상 고침 · 약한 잠금 · 메아리 · 실패 재시도 · 종료 저장 · 보관 칸 멱등 · 영수증 기본 흐름)은 다시 지적하지 않았다.

## 1. 즉시 확인(치명)

### 치명-1. 영수증 저장 실패 뒤 재시도에서 이중 지급(상품 + 토큰 환산)
- 위치: `roblox/src/server/MonetizationService.lua:176-193`(저장 실패 분기), `:152`(이미 가졌으면 환산), `:304-319`(`ownsAll`)
- 원인: 저장 실패 때 영수증 기록만 빼고(`forgetReceipt`, :178) **이미 메모리에 넣은 지급은 되돌리지 않는다**. 되돌리는 건 칸 건너뛰기(`revertSkip`)와 조각 환산뿐이다. 치장(`CosmeticService.grant`) · 시즌 유료 줄(`SeasonPassService.setPremium`) · 가방 출처(`bagSources`)는 메모리에 남는다. `SaveCoordinator.saveForPlayer`는 일시 에러가 난 뒤에도 저장을 멈추지 않으므로(:133-142), 다음 자동저장이 **영수증 없이 지급만** DataStore에 쓴다. Roblox가 같은 PurchaseId로 다시 부르면 `hasReceipt`는 거짓이고 `ownsAll`은 참이 되어 `:152`에서 토큰(sparkleShard) 환산이 추가로 지급된다.
- 재현(하네스나 Studio에서):
  1. 아직 갖지 않은 `theme_starlight`로 `processReceipt`를 부른다. 이때 `deps.save`는 false를 돌려준다(실제 서버에서는 DataStore 4회 연속 실패나 텔레포트 동결 중 구매).
  2. 결과는 NotProcessedYet이고 `receipts`에는 기록이 없다. 그런데 `cosmetics.themes.starlight == true`는 남는다.
  3. `deps.save`를 true로 바꾸고(다음 자동저장이 성공한 상황) 같은 PurchaseId로 다시 부른다. 결과는 PurchaseGranted이고 테마도 갖고 sparkleShard도 `tokenPriceForRobux(199)`만큼 늘어난다.
  - `monetize_test.luau:106-112`는 이미 가진 `theme_ember`로 실패와 재시도를 시험하므로 이 경로(처음 사는 상품의 실패 뒤 재시도)를 놓친다.
- 영향: 로벅스 1회 결제로 상품과 토큰 환산을 둘 다 받는다(유료 재화 이중 지급). 시즌 유료 줄 · 스타터 팩(가방 +20 + 치장 2)도 같다. 일어나려면 DataStore 장애, 또는 텔레포트 동결 뒤 텔레포트 실패가 있어야 한다.
- 고치는 방법(제안만, 고치지 않음): 실패 분기에서 기록을 빼지 말고 남긴다. 영수증에 `unsaved = true` 표시를 두고, 다음 호출이 `hasReceipt`이면서 `unsaved`이면 `flush`를 다시 불러 성공했을 때만 Granted를 돌려준다(지급과 영수증이 항상 같은 저장에 함께 들어간다). 다른 방법은 실패 분기에서 `applyReward`가 바꾼 칸(치장 · premium · bagSources)도 되돌리는 것인데, 첫 방법이 단순하다. 하네스에는 "처음 사는 상품 · 저장 실패 · 같은 ID 재시도 → 조각 변화 0" 경우를 추가한다.
- 예상 시간: 1.5시간(하네스 포함)

## 2. 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| 치명 | `server/MonetizationService.lua:176-193` · `:152` | 위 치명-1 | 결제 1회에 상품과 토큰 환산을 둘 다 받음 | 영수증을 `unsaved` 표시로 남기고 재시도 때 저장이 성공해야 Granted | 1.5시간 |
| 중간 | `server/SaveServer.server.lua:105-115` · `server/SaveSystem.lua:2055-2058` · `server/SaveCoordinator.lua:47`(`saving`은 Player 인스턴스 키) | 같은 서버에서 퇴장 저장(재시도 대기 1+3+6초 가능)이 끝나기 전에 같은 사람이 다시 접속해 같은 서버에 배정됨 → `heldElsewhere`는 자기 서버 표식을 잠금으로 보지 않아(`raw.sessionId ~= SERVER_SESSION_ID`) 기다리지 않고 퇴장 전 값을 읽음 → 옛 flush가 늦게 쓰면 새 세션의 첫 저장이 `stale_session`이 되어 그 접속 내내 저장이 중단됨. 반대 순서면 옛 퇴장 저장이 stale로 버려짐 | 둘 중 한 쪽 진행 손실(안내는 나감). 같은 서버 재배정 빈도는 **확인 필요** | `loadForPlayer` 시작에서 같은 UserId의 퇴장 flush가 진행 중이면(UserId 키 표) 끝날 때까지 기다린 뒤 읽기 | 1시간 |
| 중간(설계 확인 필요) | `server/InventorySync.lua:51-52` · `shared/data/MilestoneData.lua:20` | 마일스톤 "가방 칸 +5"를 받은 계정(inventorySlots 25)이 가방 패스와 스타터 팩을 둘 다 가지면 계산은 25+15+20+20 = 80인데 75로 잘림 | 마일스톤 보상 +5가 사라지거나, 반대로 스타터 팩(유료) +20 중 15만 실제로 들어옴. `monetize_test.luau:503`은 마일스톤 없는 경우만 확인 | 상한 75에 마일스톤을 포함할지 사용자 결정. 제외라면 `bagMaxSlots + (inventorySlots - defaultInventorySlots)`로 상한을 올림 | 0.5시간 + 결정 |
| 낮음 | `server/PrimordialRegistry.lua:138-156` · `:291` · `server/AcquisitionAudit.lua:274-286` | 태초 · 초월을 받자마자 퇴장(또는 서버 종료) → 퇴장 저장이 `stamp.pending = true, no = nil`로 써짐 → 번호는 그 뒤 발급되지만 `onNumbered`는 `player.Parent`가 없어 저장 안 함 | 원장 · 명예의 전당에는 번호가 있는데 아이템은 영구히 "세계 번호 확인 중"(`PrimordialStamp.lua:54`). 번호 하나가 허공에 씀 | `auditProfile`에서 `stamp.no == nil`이고 원장 `entry.no`가 있으면 각인에 번호를 옮기고 `pending`을 지움 | 0.5시간 |
| 낮음 | `server/SaveServer.server.lua:119-125` | DataStore가 느릴 때 자동저장 루프가 사람마다 차례로 `saveForPlayer`를 기다림(한 명당 최대 재시도 대기 10초 + 호출 시간) | 16명이면 한 바퀴가 수 분까지 늘어 실제 자동저장 주기가 길어짐(손실 창이 커짐) | 사람마다 `task.spawn`(종료 저장처럼 동시에) | 0.3시간 |
| 낮음 | `server/SaveSystem.lua:1825-1827` | 보관 칸(quarantine)의 장비 id가 다시 생기면 가방 칸 수를 보지 않고 `table.insert(data.inventory, v)` | 가방이 75칸을 넘을 수 있음(넘친 칸은 더 넣기만 막힘, 손실은 없음) | 의도라면 주석만. 아니면 넘치면 보관 칸에 남김 | 0.3시간 |
| 낮음(Studio 전용) | `server/PlayerProfile.lua:2802`(스냅샷) vs `:2829-2890`(복원) | `/gg` 명령 뒤 `/gg reset` | `checkpoints`는 백업은 되는데 복원 코드가 없음. `purchases.bagSources` · `shopViews`(v69) · `tutorial` · `audit` · `optionRerollTickets` · `bulkSellCutoffGrade` · `inventoryWindowPosition`은 백업 대상이 아님. 라이브 영향은 없음(Studio는 `_manual` · `_verify` 키, `SaveSystem.lua:144-156`) | 복원에 `checkpoints` 한 줄 추가. v69 두 필드는 "새 저장 필드 = 백업 대상" 규칙대로 추가 | 0.3시간 |

검토 끝에 문제 없다고 본 것(오탐 방지 기록):
- 저장 겹침 · 종료 경합: `saving` 잠금(`SaveCoordinator.lua:109-116`)은 깨어난 대기자 중 하나만 통과시킨다. PlayerRemoving의 flush 뒤 `clear` 사이에 yield가 없어서 BindToClose 쪽 flush가 지워진 프로필을 쓰지 않는다.
- 로드 중 퇴장(`SaveServer.server.lua:35-38`), 로드 실패 시 기본 프로필 + 저장 중단(`:56-60`), 미래 버전 거부, 이관 에러 → invalid_schema는 모두 맞다.
- v68 방지권 환산은 `protectionRefund`로 멱등이고, 스테이지를 hardMaxStage로 잘라 NaN · inf를 막는다(`SaveSystem.lua:1389-1416`). 하네스 MIG가 이를 확인한다.
- 골드 증감 출구는 하나다(`PlayerProfile.lua:334-345`, NaN · inf · 음수 거부). 2^53 초과 정밀도는 이미 알려진 문제로 기록돼 있다(`:333` 주석).
- `DevTools.server.lua:20-22`는 Studio가 아니면 스크립트 전체가 끝나고, `verifyArmed`도 Studio에서만 켜진다(`DevToolsConfig.lua:178`).

## 3. 설계와 어긋난 코드

- **방지권 폐지(v68)인데 개발 명령은 아직 장수를 더한다**: `server/DevTools.server.lua:2576-2578`(`/gg ticket drop|reset n` → `PlayerProfile.addProtectionTicket`). 저장 버전이 이미 69라 다시 환산되지 않아, 여기서 넣은 장수는 영구히 남는다. Studio 전용이라 라이브 영향은 없다. 명령을 막거나 지운다.
- **v68 이관이 현재 경제식에 의존**: `server/SaveSystem.lua:1406-1410`이 `Enhance.getProtectionPrice` → `GoldCost.cost(MonsterData.tier1.goldDrop, …)` × `EnhanceConfig.protection[kind].priceKillEquivalent`(`shared/Enhance.lua:273-275`)를 부른다. 앞으로 골드 곡선을 조정하면, 오래 접속하지 않은 계정은 접속 시점의 다른 가격으로 환산을 받는다. 다른 이관 블록(v11 · v22의 `LegacyCurveV21`)처럼 폐지 시점 가격을 상수로 박아 두는 것이 원칙에 맞다.
- **서버 정원 16인데 저장 감사 · 하네스는 12인 기준**: `docs/design/save-audit-launch.md:62`("12인 서버 · 분당") · `roblox/tools/harness/save_launch_test.luau:4`, `:612`(CLOSE · BUDGET가 12명). 종료 저장은 동시에 나가므로 16명도 25초 마감 안일 가능성이 높지만, 실측은 **확인 필요**. `ImmediateSave.lua:10-13`의 예산 검산 주석은 100명을 가정한다.
- **가방 상한 75**: 데이터(`MonetizationData.bagMaxSlots = 75`)는 결정과 맞다. 다만 마일스톤 +5가 이 식에 들어 있지 않다(버그 표 3번째 줄).

## 4. 단일 소스 위반 · 중복 구현

- `server/ImmediateSave.lua:17` `IMMEDIATE_SAVE_THROTTLE_SECONDS = 6`: 저장 수치가 `shared/data/SaveConfig.lua` 밖의 서버 코드에 박혀 있다(규칙 "밸런스 수치는 data/"). `SaveConfig.immediateSaveThrottleSeconds`로 옮긴다.
- 재시도 수치가 코드에 박혀 있다. `server/AcquisitionAudit.lua:87-96`(원장 쓰기 3회 · 0.5초)과 `server/PrimordialRegistry.lua:78`(번호 발급 사이 0.5초, 횟수만 `PrimordialData.claimRetries`)이다.
- 방지권 종류 목록 `{ "drop", "reset" }`가 네 곳에 있다: `SaveSystem.lua`(repairProfile · isValidProfile · v68), `shared/IdRegistry.lua:21`, `:60`, `server/ProtectionTickets.lua:25-27`. 폐지된 id라 늘어날 일은 없으니 낮음이다.
- 스테이지 상한 필드 목록 `{ "infinite", "infiniteBest", "bestBossCleared" }`가 `SaveSystem.lua`의 `stageCapViolations` · `clampStageCap` 두 함수에 따로 있다(같은 파일, 2120-2153 부근).
- 깊은 복사 함수가 같은 파일에 둘이다: `server/PlayerProfile.lua:656`(`copyTree`, 주석이 "deepCopy가 아래라 안 보여서"라고 밝힘)과 `:2759`(`deepCopy`). 같은 구현이 `QuestService.lua:270` 등 검증 파일 6곳에도 있다.
- 손상 방어가 두 겹이다. `PlayerProfile.getMonetizationState`(`:2660-2687`)가 cosmetics · mailbox · seasonPass · receipts · bagSources 모양을 매번 고치는데, 같은 종류의 고침이 `SaveSystem.repairProfile`에도 있다(다른 필드). 의도된 분리(결정 9)지만 새 필드를 넣을 때 둘 중 어디에 넣을지 기준이 없다.

## 5. 출시 전 제거 대상(개발 잔재)

- `server/DevTools.server.lua:2503-2507`(`/gg ticket buy`)과 `:2576-2578`(`/gg ticket drop|reset`): 폐지된 방지권 명령. Studio 전용.
- `server/ProtectionTickets.lua:44-63`: `if true then return false, "discontinued" end` 아래의 도달 불가 구매 본문. `ProtectionTicketServer.server.lua`의 구매 Remote도 항상 거절만 한다. 옛 클라 호환이 필요 없다면 Remote 연결을 정리한다(Remote 이름 · 저장 필드는 남긴다).
- `server/EnhanceVerify.lua:1381-1410`(S05 방지권 구매 검증)은 지금 동작과 반대 결과를 기대한다. `DevToolsConfig.lua:42`의 `exclude`로 꺼져 있을 뿐이다.

## 6. 정리 후보(쓰이지 않는 함수 · 코드, 저장 필드 · id · 에셋 · DataStore는 지우지 않음)

- `PlayerProfile.addProtectionTicket` · `trySpendProtectionTicket` · `getProtectionTicket` · `clearProtectionForDevTools`(`server/PlayerProfile.lua:416-495`): 게임 경로에서 부르는 곳이 없고 DevTools · Verify만 부른다. 함수만 정리 대상이다(`purchases.protectionTickets` 필드는 유지).
- `syncProtectionAttributes`(`PlayerProfile.lua:267-273`): 폐지 뒤 늘 0인 Attribute를 접속 · 복원마다 세운다. 클라가 아직 읽는지는 **확인 필요**.
- `copyTree`(`PlayerProfile.lua:656`): `deepCopy`를 파일 위로 올리면 하나로 합칠 수 있다.
- `SaveSystem.legacyCurveV21` 공개(`SaveSystem.lua:1602`): DevTools "/gg curve migrate" 전용. 이관 블록이 쓰는 지역 값은 유지한다.
- 필드 `classes[*].bossRotation`(29-5부터 아무도 읽지 않음)은 **저장 필드라 지우지 않는다**. 주석대로 유지한다.
