# 정리 후보(AUDIT1 B-4 · 사용자 승인용)

> 2026-10-04 · 읽기 전용 검수에서 나온 "필요 없어 보이는 것" 목록. **아무것도 지우지 않았다**(삭제 금지 규칙). 승인한 번호만 다음 큐에서 처리한다.
> 분류: **A** 삭제 안전(참조 0 · 저장/데이터 무관) / **B** 보존 필요(옛 저장 이관 · 데이터 id · 감사 기록 - 이유) / **C** 사용자 결정 / **D** 비활성화만(스위치 · 연결 끊기 - 파일 · 이름은 남김).
> 에셋 · DataStore · 데이터 id · 저장 필드는 후보에 넣지 않았다(항상 보존 - 맨 아래 "보존 확인" 표는 오해를 막으려고 적은 것).
> 근거의 참조 수 = `roblox/src` grep(2026-10-04 · 블록 A 커밋 뒤). 영역 원문 = `docs/audit/areas/*.md`.

## 요약

| 분류 | 개수 |
|---|---|
| A 삭제 안전 | 8 |
| B 보존 필요 | 1(+ 아래 "보존 확인" 4묶음) |
| C 사용자 결정 | 7 |
| D 비활성화만 | 9 |
| 합계 | 25 |

## 표

| 번호 | 경로/이름 | 무엇 | 왜 필요 없나 | 근거(참조 수 · 관련 결정) | 지우면 위험 | 분류 |
|---|---|---|---|---|---|---|
| 1 | `server/TeleportPad.lua`(125줄) | 옛 3×3 맵 포탈 패드 | M1 큰 세계에서 패드를 안 짓는다 | `require` 0 · 이름은 `HuntingGround.server.lua:3` 주석뿐(주석의 "검증 · 개발 명령이 읽는다"는 사실 아님) | 낮음(옛 맵 복원 계획이 있으면 보관) | A |
| 2 | `client/A1UiMockups.lua` | A1 UI 목업(스타일 잠금용 · 기능 없음) | U1 실제 창이 생김 | `require` 0(명령줄에서 수동 호출용) | 낮음 - 목업 비교가 다시 필요하면 git 이력 | C(참고 자료로 남길지) |
| 3 | `PlayerProfile.sellItemsBulkUpTo`(`server/PlayerProfile.lua:2299-2333`) | 옛 "기준 등급 이하 일괄 판매" | QUEUE-ALL8 G1 등급 체크 방식(`sellItemsByGrades`)으로 바뀜 | 호출 0(`InventoryServer.server.lua:101` 경로 닫힘) · 주석 참조 `ArmorData.lua:81 · 85` | 낮음(주석도 같이 고침) | A |
| 4 | `UIManager.onEmptyStackAction`(`client/UIManager.lua:45` · `:396-401`) | 열린 창 없을 때 X · Backspace 훅 | 아무도 채우지 않음 | 대입 0 | 매우 낮음 | A |
| 5 | `BuffState.apply`의 `mode = "stack"` 분기(`server/BuffState.lua:83-85`) | 중첩 버프 | 어떤 호출부도 `mode`를 안 넘김 | `"stack"` 호출 0 | 매우 낮음(중첩 버프 계획이 있으면 유지) | C |
| 6 | `client/InputDiag.client.lua`(88줄) + `UIManager` 진단 훅(`:477-509`) | S20 임시 입력 진단 | 원인(I · O 키 = 엔진이 가로챔)을 이미 확인 · 스스로 "원인 확인 뒤 제거"라고 적음 | `DevToolsConfig.inputDiag = false` · 쓰는 곳 = 두 파일뿐 | 낮음 | A |
| 7 | `copyTree`(`server/PlayerProfile.lua:656`) | 깊은 복사(같은 파일 `deepCopy` `:2759`와 같은 구현) | 중복 | 주석이 "deepCopy가 아래라 안 보여서"라고 밝힘 | 낮음(`deepCopy`를 위로 올려 하나로) | A |
| 8 | `MonetizationData.ownedRefundShards`(`:128`) | 이미 가진 상품 환산 상수 | 지금 환산 = `tokenPriceForRobux`(상품 robux 비례) | 정의만 · 읽는 곳 0 | 낮음 | A |
| 9 | `view().shardPrices`(`server/MonetizationService.lua:267`) | 상점 동기화에 실어 보내는 옛 조각 가격 | 클라 Shop이 안 읽음 | 클라 참조 0(서버 · 하네스 · 주석만) | 낮음(매 ShopSync 전송량만 줄어듦) | A |
| 10 | 방지권 구매 · 가격 Remote 4개(`ProtectionTicketBuyRequest` · `BuyResult` · `Granted` · `PriceRequest` · `server/ProtectionTicketServer.server.lua`) | 폐지된 방지권 상점 입구 | 방지권 폐지(QUEUE-ALL9B G · SAVE v68) · 항상 거절 | 클라 참조 0 | 중간 - Remote 이름은 옛 클라 호환 · 감사 기록과 연결 → **연결만 끊고 이름은 남김** | D |
| 11 | `ProtectionTickets.lua:44-70` 죽은 구매 본문(`if true then return false, "discontinued" end` 아래) | 옛 구매 로직 | 도달 불가 | 위 줄이 항상 return | 낮음(보스 첫 처치 골드 `grantForBoss`는 유지) | D |
| 12 | `syncProtectionAttributes`(`PlayerProfile.lua:267-273`) · Attribute `ProtectionDrop` · `ProtectionReset` | 접속마다 늘 0인 Attribute | 방지권 폐지 | 클라 읽기 0 | 낮음 | D |
| 13 | `PlayerProfile.addProtectionTicket` · `trySpendProtectionTicket` · `getProtectionTicket` · `clearProtectionForDevTools`(`:416-495`) | 방지권 장수 함수 | 게임 경로 호출 0(DevTools · Verify만) | 저장 필드 `purchases.protectionTickets` · `protectionClaimedStages` · `protectionRefund`는 **유지** | 낮음 | D |
| 14 | `/gg ticket buy · drop · reset`(`DevTools.server.lua:2503-2507` · `2576-2578`) | 폐지된 방지권 개발 명령 | v68 이관 뒤 넣은 장수는 영구히 남음(Studio 전용) | Studio 전용 | 낮음 | D |
| 15 | 성장 재화 허용 목록의 `protectDrop`(`shared/Monetization.lua:172` · `SeasonPassData.lua:121` · `SeasonBoardData.lua:28`) | 무료 줄 · 출석판 검사 목록 | 방지권 폐지 - 누가 무료 줄에 넣으면 지급 실패 → 반복 지급 경로(경제 감사 낮음) | 검사 목록에서만 뺌 · 아이템 id · 아이콘 · 문구(`ItemInfoData.lua:13` retired)는 유지 | 낮음 | D |
| 16 | 옛 기대값 검증 블록 `EnhanceVerify.lua:1375-1406`([17]) · `P25cVerify.lua:324-327` | 방지권 구매 · 지급 성공을 기대 | 지금 동작과 반대 | `DevToolsConfig.lua:42 exclude`로 꺼짐 · 로컬 하네스 `enhance_g_test`가 대신 확인 | 지우지 말고 새 규칙(방지 옵션 · 보스 골드)으로 재작성 | C |
| 17 | 패널 안 Studio 자체 점검 블록(`client/StageSelectPanel.lua:752-771` · `client/hud/DropFeed.client.lua:134-` 약 330줄 등) | (가) 자체 점검 | 제품 경로가 아님(`IsStudio` + verify 목록) | 회귀 체인(S10 · S11)이 씀 | 중간 - 지우지 말고 따로 파일로 빼기만 | C |
| 18 | `client/ui/kit/Badge.lua`(51줄) | 배지 kit 부품 | 게임 화면에서 안 씀 | 참조 = UiGallery(전시장 · 규칙 점검)뿐 | 낮음(kit 부품 목록 정책이면 유지) | C |
| 19 | 글 키 `toast.autoSell` · `toast.autoDismantle`(`TextData.lua:276-277` · en) | 자동 처리 알림 한 줄 문구 | QUEUE-N1004 A-1 묶음 알림(`autoTidy.toast.*`)으로 바뀜 | 코드 참조 0 | 매우 낮음(글 키라 데이터 id 아님) | A |
| 20 | `UIManager.setBossFight`(`client/UIManager.lua:451-462`) | 보스전 중 창 딤 끄기(PRD 20.81 [D-1]) | 부르는 감시자가 없음 | 게임 코드 호출 0(전시장만) | 설계 요구가 연결 안 된 것일 수 있음 → 연결할지 지울지 | C |
| 21 | `SaveSystem.legacyCurveV21` 공개(`SaveSystem.lua:1602`) | 옛 곡선 공개 함수 | DevTools `/gg curve migrate` 전용 | 이관 블록이 쓰는 지역 값은 유지 | 낮음 - 공개만 닫음 | D |
| 22 | `DropTable.gainOnly` 전역 플래그 사용처 | 시뮬 전용 전역 토글 | 에러 때 원래대로 안 돌아감(전투 감사 낮음) | 정리 = pcall + 복원 | 낮음 | D |
| 23 | `BossEnvironment.lua:480` `"bossRocket"` 0배 피해 출처 | 무적을 배율로 거는 옛 방식 | `isRocketing` 면역(`PlayerDamage.lua:64`)과 중복 · 하한 0.25에 막힘 | 동작이 바뀌므로 Play 검증 필요 | 중간 | C |
| 24 | `client/BossGimmick13View.lua:21` `TEMP_SOUND` | Roblox 기본 효과음 임시 | 출시 전 교체 대상 | 1곳 | 낮음(소리 에셋 교체) | D |
| 25 | `ArtAssetIds` `extras/vfx/*` 6키 · `icons/gear_v3/*_greatsword_*` 16키 | 코드에서 아직 안 쓰는 에셋 자리 | 연출 자리 · ALL9E 아이콘 전환 전 | — | **에셋은 지우지 않음** - 목록만(보존) | B |

## 보존 확인(후보 아님 - 지우면 안 되는 것)

| 번호 | 무엇 | 왜 남기나 |
|---|---|---|
| B-1 | 저장 필드 `purchases.protectionTickets` · `protectionClaimedStages` · `protectionRefund` · `classes[*].bossRotation` · `InventoryWindowX/Y` · `bulkSellCutoffGrade` | 옛 저장 이관 · v68 환산 멱등 · 롤백 |
| B-2 | 데이터 id `protectDrop` · `protectReset`(`ItemInfoData` retired) · 방지권 종류 `drop` · `reset`(`IdRegistry.retired`) | id 등록부 · 보관 칸 · 옛 저장 표시 |
| B-3 | `server/*Verify.lua` 71개 · `TerrainBakeRun.lua`(edit 명령줄 실행기) | 회귀 검증 체인 · 맵 굽기 도구(라이브에서 require 안 됨) |
| B-4 | 삭제 이력의 지운 파일(56건) | 모두 의도된 정리 - 복구 필요 0(`AUDIT1-report.md` 6절) |
