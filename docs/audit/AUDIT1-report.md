# AUDIT1 검수 보고서(소넷 시기 혼합 검수)

> 2026-10-04 · QUEUE-N1004 블록 B · **읽기 전용**(코드 · 데이터 · 에셋 변경 0 - 문서만). 범위 = 등급 A(저장 · 결제 · 보안 · 경제 · 전투 - 모델 무관 정밀) + 등급 B(소넷 시기 줄 ≥ 50% 모듈 정밀) + 등급 C(자동 스캔). 모델 시기 지도 = `docs/audit/model-map.md`.
> 방법: 영역별 읽기 전용 서브에이전트 6개(저장 · 결제 · 보안 · 경제 · 전투 · 등급 B)가 코드를 직접 읽고 `파일:줄`을 붙여 기록 → 즉시 확인 2건은 제가 코드를 다시 읽어 확인 · 등급 C는 제가 도구로 직접 스캔. 영역별 원문(근거 · 오탐 방지 기록 포함) = `docs/audit/areas/*.md`. 실행(하네스 · Studio)으로 재현한 것은 아니다 - "재현"은 코드 경로로 따라간 절차다.
> 함께 볼 문서: 정리 후보 = `docs/audit/cleanup-candidates.md` · 미구현 목록 = `docs/audit/unimplemented.md`.

## 1. 즉시 확인(치명 · 고치지 않음 - 재현 방법 + 고치는 방법 제안)

### 즉시-1 결제 이중 지급: 영수증 저장이 실패한 뒤 재시도하면 상품 + 토큰 환산을 둘 다 받는다
- 위치: `roblox/src/server/MonetizationService.lua:176-193`(저장 실패 분기) · `:152`(이미 가졌으면 토큰 환산) · `ownsAll`(`:304-319`). 저장 · 결제 두 감사가 따로 찾았고 제가 코드를 다시 읽어 확인했다.
- 원인: 저장 실패 때 `Monetization.forgetReceipt`로 **영수증 기록만 지우고**, 메모리에 이미 넣은 지급(치장 · 시즌 유료 줄 · 가방 출처 `bagSources`)은 되돌리지 않는다(되돌리는 것 = 칸 건너뛰기 · 토큰 환산뿐). 그 뒤 자동저장이 성공하면 "영수증 없이 지급만" 저장된다. Roblox가 같은 PurchaseId로 다시 부르면 `hasReceipt` = 거짓 · `ownsAll` = 참 → 토큰(sparkleShard) 환산이 추가로 나간다.
- 재현(하네스 `monetize_test.luau` 방식): ① 아직 없는 `theme_starlight` 영수증을 `deps.save = false`로 처리 → NotProcessedYet · 영수증 기록 없음 · `cosmetics.themes.starlight = true` 남음 ② `deps.save = true`로 같은 PurchaseId 다시 → PurchaseGranted + sparkleShard가 `tokenPriceForRobux(199)`(280)만큼 증가. 실제 서버 조건 = DataStore 연속 실패 또는 텔레포트 동결 중 구매 뒤 텔레포트 실패. 기존 하네스(`monetize_test.luau:106-112`)는 이미 가진 테마로만 시험해서 이 경로를 놓친다.
- 영향: 로벅스 1회 결제로 상품 + 토큰(199R$ 상품 = 280 · 시즌 유료 줄 = 560). 스타터 팩(가방 +20 + 치장 2)도 같다.
- 고치는 방법(추천): 실패 분기에서 영수증을 지우지 말고 `unsaved = true`로 남긴다 → 다음 호출이 `hasReceipt`이면서 `unsaved`면 `ImmediateSave.flush`를 다시 불러 성공했을 때만 PurchaseGranted(지급과 영수증이 늘 같은 저장에 함께 들어감). 하네스에 "처음 사는 상품 · 저장 실패 · 같은 ID 재시도 → 토큰 변화 0" 추가. 예상 1.5 ~ 2시간.

### 즉시-2 보안 구멍(보상 판정 우회): 보스전 중 직업을 바꿔 막타 → 새 직업이 그 보스 첫 클리어 표 · 드랍을 받는다
- 위치: `roblox/src/server/ClassServer.server.lua:45-80`(직업 전환 요청에 보스전 · 영혼 · 잔류 상태 검사가 없음 - 제가 다시 읽어 확인) · 기여 = Player 기준(`CombatResolution.lua:311`) · 직업별 첫 클리어 표(`CombatResolution.lua:148` · `199-211`).
- 재현: 강한 직업으로 보스 HP를 거의 다 깎음 → 클라가 `ClassSelectRequest`(레벨 1 직업)를 보냄 → 그 직업으로 막타.
- 영향: 레벨 1 직업이 고스테이지 보스 드랍 · 직업별 첫 클리어 표(확정 전설 · 태초 · 초월 확률)를 받는다. 캐리 방지용 파티 진입 밴드(`BossEncounter.lua:530-556`)도 건너뛴다. 복제는 아니다.
- 고치는 방법: `ClassServer`에서 보스전(잔류 포함) · 영혼 · 채널링 · 잡힘 상태면 거절 + 하네스 1줄. 예상 0.5시간.

## 2. 버그 표(심각도 순 · 영역별 원문 = `docs/audit/areas/`)

- 결제 "높음"(MonetizationService:152-158 · 176-192)은 즉시-1과 같은 결함이다(두 감사가 따로 찾음). 보안 "높음 H1"은 즉시-2다.
- 심각도는 각 감사가 매긴 값 그대로(즉시-2는 보안 감사가 "높음"으로 매겼으나 사용자 기준 "보안 구멍"이라 1절에 올렸다).

| 번호 | 심각도 | 영역 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|---|---|
| 1 | 치명 | 저장 | `server/MonetizationService.lua:176-193` · `:152` | 위 치명-1 | 결제 1회에 상품과 토큰 환산을 둘 다 받음 | 영수증을 `unsaved` 표시로 남기고 재시도 때 저장이 성공해야 Granted | 1.5시간 |
| 2 | 높음 | 결제 | `server/MonetizationService.lua:152-158, 176-192` | (1)절 B-1 참고: 안 가진 상품 영수증이 저장에 실패한 뒤 재시도됨 | 같은 구매로 치장(또는 유료 줄 · 가방 칸)과 토큰 환산이 둘 다 지급됨 | 저장 실패 때 기록을 남기고 `unsavedReceipts`로 재저장을 시도한 뒤에 Granted 반환 | 1.5 ~ 2시간 |
| 3 | 높음(공개 전 필수 · 지금은 잠복) | 결제 | `shared/data/MonetizationData.lua:96` · `server/CosmeticService.lua:96-97, 166, 173` · `server/MonetizationService.lua:523` | `nameplateSet` 패스를 사면 `gamepasses.nameplateSet = true`만 기록됨. `includes`를 펼치는 서버 코드가 없다(grep `includes` = 데이터 · 클라 표시만). 장착 · Attribute는 `gamepasses.nameplateColor` · `nameplateBadge`만 확인 | 79R$를 내도 색 · 배지 장착이 `no_pass`로 거부됨. 지금은 공개 단계 2 · passId 0이라 살 수 없음 | `hasPass`(또는 CosmeticService 확인 두 곳 · `applyAttributes`)가 `includes`를 펼쳐 보게 함. 예: `hasPass(p,"nameplateColor") or 그 키를 includes하는 패스 보유` | 30분 |
| 4 | 높음 H1 | 보안 | ClassServer.server.lua:45-80 · CombatResolution.lua:147-148 · 199-211 · 300-341 · BossEncounter.lua:533-556 | ① 직업 A(최고 200)가 보스 스테이지 X(≤ 200)로 내려가 보스전을 시작한다(아래 이동은 자유 - StageServer.server.lua:69-75). ② 보스 HP가 거의 다 깎였을 때 `ClassSelectRequest("B")`를 보낸다(B = 레벨 1 · 진행 0). 서버는 직업 존재 여부 · RequestGate만 본다. ③ 막타를 B로 친다. 기여 표가 직업이 아니라 Player 기준(`contributions[member]` · CombatResolution.lua:311)이라 A가 넣은 피해가 B 몫으로 센다. | B가 **그 직업의 보스 X 첫 클리어 보상**을 받는다. 드랍 기준 = 보스 스테이지(`dropStage` · 148), 직업별 첫 클리어 표(199-211: 태초 · 초월 확률표, 그 직업 첫 보스면 확정 전설)가 적용된다. 파티 진입 밴드(BossEncounter.lua:530-531 주석 "캐리 = 리더보드 조작")를 직업 전환으로 건너뛴다. A가 X를 계속 다시 잡으며 B · C · D로 돌리면 직업마다 보스 스테이지별 첫 클리어 굴림을 미리 당겨 받는다. 복제는 아니다. 진행 기록(bestBossCleared)은 "다음 보스 스테이지"일 때만 오르므로(LeaderboardRules.evaluateClear) 대부분 안 오른다. 경험치 · 골드는 받는 직업의 스테이지 기준이라(147 · 165) 영향이 작다. | (가) ClassServer에서 `BossEncounter.getEncounter(player) ~= nil`(잔류 포함) · `SoulService.isSoul` · `PlayerState.isChanneling/isTrapped`이면 거부 + 결과 알림(추천 · 가장 작음). (나) 또는 보스 진입 순간 멤버별 classId를 encounter에 적어 두고, 보상 때 지금 classId가 다르면 제외한다. 하네스: attack_test에 "보스전 중 직업 전환 거부" 1줄 추가. | 30분 + 하네스 20분 |
| 5 | 중간 | 결제 | `server/InventorySync.lua:51-52` · `server/PlayerProfile.lua:784` · `shared/data/MilestoneData.lua:20` | 마일스톤 가방 +5(inventorySlots 25)를 가진 계정이 가방 패스와 스타터를 둘 다 산 경우: 25 + 15 + 20 + 20 = 80 → 상한 75로 잘림 | 유료로 산 +20 중 5칸이 안 들어옴(돈 낸 만큼 못 받음). 고레벨 계정에만 해당 | 상한을 "기본 + 마일스톤 + 유료" 기준으로 다시 정하거나(`bagMaxSlots`를 마일스톤만큼 올림) 유료 출처는 상한에서 뺌. 결정 필요 | 30분 + 결정 |
| 6 | 중간(확인 필요) | 결제 | `shared/data/SeasonPassData.lua:93-100, 119` · `server/SeasonPassService.lua:102-110, 222-225` | 칸 건너뛰기 20칸 구매 → 40칸에 일찍 닿음 → 그 뒤 자연 경험치가 반복 보너스 칸(무료 = 골드 3,600 + 토큰 1, 시즌당 20회)으로 감. `skipTiers`는 40칸까지만 표시되므로 보너스 칸 골드는 토큰으로 바뀌지 않음 | 매일 접속하지 않는 유저(주 4일 = 42일째 40칸)는 구매자만 시즌 안에 보너스 골드(최대 72,000)를 더 받음. "건너뛰기로 성장 재화를 얻는 길 차단"(보완 6-2)이 우회됨 | 건너뛴 칸 수만큼 보너스 칸도 `skippedFreeReward`로 바꾸거나(시즌별 `skipBought`만큼 앞 보너스 칸을 토큰화), 설계에서 허용으로 확정 | 1시간 + 결정 |
| 7 | 중간 | 경제 | `server/PlayerProfile.lua:1232` · `shared/Loot.lua:404-407` · `shared/GemCraft.lua:100-106` | 계정 최고 스테이지가 장비의 `dropStage`보다 높은 계정(스테이지가 오른 뒤 가방에 남은 장비 · 낮은 스테이지에서 주운 장비)에서 영웅 이상 장비 하나를 고른다. ① 바로 판매하면 `Loot.getSellPrice`의 하한이 `GemCraft.sellPrice(…, item.dropStage)`라서 **주운 스테이지** 기준 값이 나온다. ② 분해한 뒤 보석을 팔면 `sellGem`이 `GemCraft.sellPrice(gem, getAccountBestStage)`를 써서 **계정 최고 스테이지** 기준 값이 나온다. 결과는 ② > ①이다. | QUEUE-ALL9B 1-3의 의도("바로 팔기가 늘 손해이던 역전을 없앤다" - `Loot.lua:402`)가 실제 플레이에서 다시 뒤집힌다. 하네스 `economy_all9b_test.luau:35-40`은 `stage == dropStage`인 경우만 재서 이 차이를 못 잡는다. | 보석 판매가의 스테이지를 계정이 아니라 보석 자체에서 읽는다. 예: `GemCraft.sellPrice(gem, gem.itemLevel)`(itemLevel ≈ 주운 스테이지 척도). 아니면 `Loot.getSellPrice` 하한에 계정 최고 스테이지를 넘기는 인자를 추가한다. 하네스 1-3에 "최고 스테이지 > 주운 스테이지" 경우를 넣는다. | 1 ~ 2시간 |
| 8 | 중간(확인 필요) | 경제 | `shared/GemCraft.lua:100-106` · `server/PlayerProfile.lua:1220-1238` · `shared/data/GemData.lua:113-120` | 위와 같은 원인이다. 계정 최고 스테이지가 높은 계정(예: 20,000)이 낮은 스테이지(예: 1)로 내려가 영웅 이상을 모은 뒤 분해 → 보석 판매를 하면, 영웅 보석 1개(가루 `max(1, round(3 × 0.14)) = 1`)가 `1 × (40 ÷ 4) × 0.5 = 5`마리분 × **스테이지 20,000의** 처치당 골드가 된다. | 보석 판매만으로 "낮은 스테이지에서 빠르게 줍고 높은 스테이지 가격에 판다"는 차익이 생긴다. 무한 골드는 아니다(드랍률 · `DropTable.timeFairnessFactor` · 이동 시간에 묶인다). 정상 사냥보다 나은지는 EconSim으로 재야 한다. | 첫 줄과 같은 수정(보석 가격의 스테이지 = 보석 itemLevel)이면 같이 사라진다. 고치기 전에 EconSim에 "최고 20,000 · 사냥 1 · 분해 → 판매" 경로를 한 줄 넣어 시간당 골드를 정상 사냥과 비교한다. | 측정 1시간 + 수정은 첫 줄에 포함 |
| 9 | 중간(알려진 문제) | 경제 | `server/PlayerProfile.lua:330-344` · `docs/design/econ-baseline-pre-all10.md` 3 · 4절 | 상위 1% 프로필은 1,113시간(스테이지 약 21,435)에 보유 골드가 2^53을 넘는다. 스테이지 25,300에서는 1.4e18이다(문서 3절). 이 상태에서 시즌 패스 무료 줄 3,600골드(`SeasonPassData.lua:92`)나 판매가처럼 ulp(1e18 근처 128 ~ 256)보다 작은 지급은 더해도 사라지거나 반올림된다. | 큰 보유 구간에서 작은 보상이 0이 된다. 차감도 최대 ulp/2만큼 어긋난다. 무한 골드나 음수는 아니다(`changeGold`가 0에서 자른다). `bignum_test.luau`의 KNOWN 4건으로 이미 알려져 있고 ALL10으로 넘어갔다. | ALL10 결정을 따른다(후반 골드 싱크 · 고정 보상의 스테이지 연동 · 단위 축소 중 하나). 그 전까지는 지금 안전망으로 충분하다. | 결정 뒤 별도 |
| 10 | 중간 | 등급 B | `client/panels/Inventory/BulkSell.lua:171-176` (서버 `server/InventoryServer.server.lua:104-111`) | 일괄 판매 확인창을 연 채로 영웅 장비를 줍는다(자동 줍기 포함) → [분해]를 누른다 | 확인창이 보여 준 개수에 없던 영웅 장비까지 보석으로 분해된다(되돌릴 수 없음). 판매 쪽은 QUEUE-ALL8 F 리뷰에서 "보여 준 개수"를 같이 보내 막았지만(`BulkSell.lua:184-191` · 서버 `count_mismatch`) 분해는 기준 등급만 보낸다 | 판매와 같게 확인창의 분해 개수를 같이 보내고 서버 `dismantleItemsUpTo`가 다시 센 수와 다르면 거절 + `count_mismatch` 회신 | 1시간 |
| 11 | 중간 | 등급 B | `server/TutorialState.lua:164-171` · `client/TutorialHud.client.lua:124` · `shared/data/TutorialData.lua:63-` | 언어 en으로 새 계정 시작 | 견습 안내 본문(lessonText) · 친구 한 줄(friendHintText)이 한국어 그대로 나온다. 서버가 데이터 문장을 그대로 보내고 클라가 `Text.name`도 안 거친다(TextData_names에도 없음 - grep 0건) | 문장을 TextData 키로 옮기고 서버는 키만 보내 클라가 `Text.get`, 또는 `Text.getFor(player, …)`로 서버에서 번역 | 1시간 |
| 12 | 중간 M1 | 보안 | PlayerDamage.lua:93 · MonsterSpawner.lua:587 · CombatResolution.lua:258 · 265 · EnhanceService.lua:138 | 라이브 서버에서 플레이어가 맞을 때마다, 몹이 죽을 때마다, 드랍마다, 강화마다 print 1줄이 찍힌다. 30명 서버의 보스 장판 · 광역 사냥이면 초당 수십 ~ 수백 줄이다. | 서버 로그(개발자 콘솔)가 의미 있는 경고를 묻는다. 문자열 포맷 비용도 생긴다. 보안 구멍은 아니지만 운영 진단을 막는다. | data에 로그 단계 스위치(예: `DevToolsConfig`나 새 `LogConfig.verbose`, 기본 false)를 두고 위 줄들을 감싼다. IsStudio이면 켠다. | 1시간 |
| 13 | 중간 M2 | 보안 | docs/design/security-audit-launch.md 3-1 · 5절 R5 | 문서는 입구 58개, 자체 제한은 "Codex · Quest · RedeemCode · SettingsSave 4개"라고 적었다. 실제는 61개이고 RequestGate 없이 자체 제한만 쓰거나 제한이 없는 입구가 29개다(위 표의 "자체" · "없음"). | 다음 감사 · 출시 체크리스트가 낡은 숫자를 믿게 된다. 버린 요청 탐지(`suspect_requests`, SuspicionMonitor.lua:63-68)는 RequestGate만 세므로 자체 제한 입구의 폭주는 탐지되지 않는다. | 문서 표 갱신 + 위 2절 표를 문서로 옮긴다. 탐지가 필요하면 자체 제한에서 버릴 때도 `SuspicionMonitor.noteGateDrop`을 부른다(선택). | 문서 30분 |
| 14 | 중간 M3 | 보안 | tools/harness 전체 | 하네스가 다루는 입구: attack_test(Sell · Quest · Pet · Settings · Fall), request_gate_test(Lock · ClassSelect · Sell · Equip · BulkSell · InheritPreview), security_launch_test(RedeemCode · 초대 · Codex · CommunityGoal · Weekly · Travel · Spectate), ops_security_test(OpsRollback 순수 함수 · 차단 설정 · 탐지 기준). 잘못된 인자 시험이 없는 입구: AttackRequest · SkillRequest · DashRequest · ClassSelect(보스전 중) · LeaderboardRequest · PartyRequest 동작별 · EmoteRequest · BossLingerChoice · BossGiveUp · Gem 5종 · Awaken · Inherit · ShopRequest(monetize_test가 일부를 다룰 수 있음 - 확인 필요). 문서 R6은 옛 하네스가 시작 전에 멈춘다고 적었다(지금 고쳐졌는지 확인 필요 - 이번에 실행 안 함). | 회귀가 생겨도 하네스가 못 잡는다. 특히 H1 같은 상태 검사 누락. | attack_test에 "입구별 잘못된 인자 10종 + 상태(보스전 · 영혼 · 사망)" 표 구동 시험을 추가한다. | 2시간 |
| 15 | 중간 | 저장 | `server/SaveServer.server.lua:105-115` · `server/SaveSystem.lua:2055-2058` · `server/SaveCoordinator.lua:47`(`saving`은 Player 인스턴스 키) | 같은 서버에서 퇴장 저장(재시도 대기 1+3+6초 가능)이 끝나기 전에 같은 사람이 다시 접속해 같은 서버에 배정됨 → `heldElsewhere`는 자기 서버 표식을 잠금으로 보지 않아(`raw.sessionId ~= SERVER_SESSION_ID`) 기다리지 않고 퇴장 전 값을 읽음 → 옛 flush가 늦게 쓰면 새 세션의 첫 저장이 `stale_session`이 되어 그 접속 내내 저장이 중단됨. 반대 순서면 옛 퇴장 저장이 stale로 버려짐 | 둘 중 한 쪽 진행 손실(안내는 나감). 같은 서버 재배정 빈도는 **확인 필요** | `loadForPlayer` 시작에서 같은 UserId의 퇴장 flush가 진행 중이면(UserId 키 표) 끝날 때까지 기다린 뒤 읽기 | 1시간 |
| 16 | 중간(설계 확인 필요) | 저장 | `server/InventorySync.lua:51-52` · `shared/data/MilestoneData.lua:20` | 마일스톤 "가방 칸 +5"를 받은 계정(inventorySlots 25)이 가방 패스와 스타터 팩을 둘 다 가지면 계산은 25+15+20+20 = 80인데 75로 잘림 | 마일스톤 보상 +5가 사라지거나, 반대로 스타터 팩(유료) +20 중 15만 실제로 들어옴. `monetize_test.luau:503`은 마일스톤 없는 경우만 확인 | 상한 75에 마일스톤을 포함할지 사용자 결정. 제외라면 `bagMaxSlots + (inventorySlots - defaultInventorySlots)`로 상한을 올림 | 0.5시간 + 결정 |
| 17 | 중간 | 전투 | SkillServer.server.lua:531-557, 566 (`castHunterTrap` · 덫 Heartbeat `filterSameZone(trap.position, …)`) | 활 직업으로 구역 담장 바깥(구역 판정 밖)에 서서, 안쪽 40 stud 안 지점에 R(사냥꾼의 덫)을 설치한다. 조준점의 높이(Y)는 검사하지 않고, 시야(벽)도 검사하지 않는다. 몹이 덫을 밟으면 피해 · 속박이 들어가고, 그 피해가 처치를 내면 보상도 받는다. | 몹이 쫓아올 수 없는 자리에서 쌓는 기여 · 처치. AttackServer.lua:355-361이 막으려던 "입구에 서서 안쪽을 쏘는" 행위가 그대로 열린다. 쿨다운이 20초라 피해량은 제한적이다. | 설치 순간 `ZoneBounds.isInside(rootPart.Position, 덫 자리의 zoneKey)`와 시전자 → 조준점 Raycast를 검사한다. 발동 순간에도 시전자 위치로 `filterSameZone(시전자 위치, …)`를 한 번 더 적용한다. | 1시간 |
| 18 | 중간 | 전투 | UltimateService.lua:167, 215, 224 (`hitsInCircle(center, …, candidates(center))`) + SkillServer.server.lua:150-152 | 활 궁극기(화살비)를 구역 밖에서 조준점만 구역 안(최대 70 stud, UltimateData.lua:31)으로 찍는다. 구역 필터가 시전자가 아니라 조준점 기준이다. | 위와 같다(구역 밖 안전 사냥, 벽 너머). 지속 틱마다 시전자 위치를 다시 검사하지 않는다. | 구역 필터 기준을 시전자 위치로 바꾸고(`candidates(rootPart.Position)`과 교집합), 조준점까지 시야 Raycast를 추가한다. | 1시간 |
| 19 | 중간 | 전투 | MonsterState.lua:401-409 (상자는 무시된 타격도 `false, damage` 반환) + AttackServer.lua:480-482 · SkillServer.lua:108-113 (`applyLifesteal` · `UltimateService.onDealt`) | 보물상자를 연타한다(상자 유효 피격 간격 안의 타격). 상자는 횟수만 세고 그 타격은 버리지만, 반환값 `dealt`가 넘긴 피해 그대로라 흡혈과 궁극기 충전(대검 · 치유사 = 피해 비례)이 정상 몹을 칠 때처럼 들어간다. | 상자 앞에서 안전하게 궁극기를 충전하고 체력을 회복한다. 흡혈은 초당 상한(PlayerState.tryLifesteal)이 있어 영향이 작다. | 상자 분기의 반환을 `false, 0`(또는 유효 피격일 때만 상징값)으로 바꾼다. 데미지 숫자 표시가 필요하면 표시용 값을 따로 돌려준다. | 30분 |
| 20 | 낮음 | 결제 | `server/SeasonPassService.lua:111, 130, 143-148` · `server/MonetizationService.lua:170-180` | 칸 건너뛰기 영수증 A · B가 연달아 옴: A 저장 대기 중 B의 `applySkip`이 `lastSkipMarked[player]`를 덮음 → A 저장 실패 → `revertSkip`이 B가 표시한 칸을 지움 | 건너뛴 칸 표시가 실제와 한 칸 어긋남. 그 칸의 무료 줄 성장 재화가 토큰 대신 그대로 지급될 수 있음. 금액은 작음 | `lastSkipMarked`를 플레이어가 아니라 PurchaseId 키로 저장(B-1을 고치면 되돌림 자체가 없어져 함께 해결) | B-1에 포함 |
| 21 | 낮음 | 결제 | `server/GiftService.lua:181-186` · `server/MonetizationService.lua:66-70` | 이미 가진 치장을 선물로 받음 → `CosmeticService.grant`가 `owned` → `applyReward`가 성공으로 보고 선물이 사라짐 | 선물 가치 손실(운영 · 초대 선물). 치장 선물은 운영자만 보낼 수 있음 | 선물 받기에서 owned면 토큰 환산(영수증과 같은 식) 또는 선물함에 남김 | 20분 |
| 22 | 낮음 | 결제 | `server/GiftService.lua:90-93` | 온라인 대상에게 보낼 때 `ImmediateSave.flush` 결과를 무시하고 `delivered_online`을 돌려줌 | 저장 실패 뒤 서버가 죽으면 운영자에게는 "전달됨"으로 보이지만 선물이 사라짐(주석 의도와 반대) | flush 실패면 결과 문자열에 표시하거나 DataStore 대기열에도 넣음(id 중복은 claimedIds가 거름) | 15분 |
| 23 | 낮음(확인 필요) | 결제 | `server/MonetizationService.lua:130-137` | 등록 거부 · 정책 제한 상품의 영수증 → 매번 `NotProcessedYet` | 영구 미지급(Roblox 쪽 자동 환불 정책이 있는지 확인 필요). 정상 클라는 프롬프트를 못 열고 변조 클라만 해당 | 운영 기록(`purchases.log`)으로 수동 환불 · 현 상태 유지 가능 | - |
| 24 | 낮음 | 경제 | `server/MonetizationService.lua:51-99` · `server/SeasonPassService.lua:226-231` | `applyReward`는 grant를 키 이름 순서로 하나씩 지급하다가 중간 grant가 실패하면 `false`를 돌려준다. 앞에서 이미 준 것은 되돌리지 않는다. 시즌 패스는 `false`면 받은 표시를 하지 않으므로, 실패하는 종류가 뒤에 있는 칸은 누를 때마다 앞의 골드 · 재료가 반복 지급된다. **지금 데이터로는 재현되지 않는다**(무료 줄 = egg · enhanceStone · gemDust · gold, 모두 성공. 알 가득은 루프 전에 거른다). | 잠재 복사다. 예를 들어 무료 줄에 폐지된 `protectDrop`이 다시 들어가면 정렬상 `gold` 뒤에 와서 `unknown_kind`로 실패한다. 그러면 칸마다 골드가 무한히 나온다. 이 이름은 `SeasonPassData.lua:121 growthKinds`에 아직 있다. | `applyReward`를 2단계로 바꾼다: ① 모든 grant를 먼저 검사(종류 · 판매 금지 · 지급 가능)하고 ② 하나라도 안 되면 아무것도 주지 않는다. 아니면 시즌 받기에서 표시를 먼저 하고, 실패하면 표시를 되돌린다. | 1시간 |
| 25 | 낮음 | 경제 | `server/MonetizationService.lua:167-188` | 영수증을 처리하다 저장이 실패하면 `forgetReceipt`를 하고 NotProcessedYet을 돌려준다. 재시도가 다시 지급한다. 되돌리는 것은 조각 환산과 칸 건너뛰기뿐이다. | 지금 상품은 전부 멱등(치장 · 유료 줄 · 가방 출처 · 칸 건너뛰기 되돌림)이라 문제가 없다. 앞으로 조각 묶음이나 알 같은 더하기 상품을 넣으면 저장 실패 한 번마다 두 번 지급된다. | 더하기 종류 grant는 저장 실패 때 되돌리는 표를 일반화한다. 아니면 상품 검사(`Monetization.checkCatalog`)에서 더하기 종류를 막는다. | 1시간 |
| 26 | 낮음 | 경제 | `server/EnhanceService.lua:112-115` | `PlayerProfile.trySpendGold(player, cost)`의 반환값을 버린다(재료도 같다). 바로 앞 `:103`에서 잔액을 확인했으므로 지금은 실패할 수 없다. | 나중에 `trySpendGold`에 새 거절 조건이 생기면(예: 비용 NaN 거절) 골드를 안 내고도 강화가 진행된다. | `if not PlayerProfile.trySpendGold(...) then return send(insufficient_gold) end`로 바꾼다. | 10분 |
| 27 | 낮음 | 경제 | `server/PlayerProfile.lua:393-414` | `addMaterial` · `trySpendMaterial`은 골드의 `changeGold`와 달리 NaN · inf · 음수 검사가 없다. `trySpendMaterial(…, -n)`이면 재료가 늘어난다. 지금 호출부는 고정 데이터 · 운영 회수(`OpsServer.server.lua:198` - 의도된 음수)뿐이다. | 잘못된 데이터 한 줄로 재료가 NaN이 되거나 늘어날 수 있다. 저장은 `SaveSystem`의 NaN 복구가 막지만, 그 세션에서는 오염된 값이 그대로 쓰인다. | 골드와 같은 한 곳 함수(Sanitize · 0 하한)를 두고, `trySpendMaterial`은 `amount < 0`이면 거절한다. | 30분 |
| 28 | 낮음(확인 필요) | 경제 | `server/PlayerProfile.lua:1234 · 1865 · 2283 · 2329 · 2369` | 판매 · 자동 판매 · 보석 판매는 `addGold`를 거치지 않고 `changeGold`를 바로 부른다. | `SuspicionMonitor.noteGold`(`:357` - 골드/분 · 큰 골드 감사)에 판매 골드가 잡히지 않는다. Telemetry에는 따로 남는다. 의도라면 문제없다. | 의도가 아니면 판매 경로도 같은 감사 함수를 부르게 한다. | 20분 |
| 29 | 낮음(확인 필요) | 경제 | `shared/Loot.lua:418-438` | 자동 정리(`isAutoProcessTarget`)는 보스 · 토벌 출처 세트 장비를 뺀다. 등급 일괄 판매(`isBulkSellTarget`)는 빼지 않는다. 체크 등급에 영웅이 들어 있으면 보스 세트 영웅이 일괄 판매에 포함된다. | 두 판정이 서로 다르다. 플레이어가 세트 장비를 실수로 팔 수 있다. | 의도를 정한 뒤 공통 판정 하나로 모은다. | 30분 |
| 30 | 낮음 | 경제 | `server/SaveSystem.lua:1392-1414`(v68 이관) | 손상된 저장에서 `protectionTickets.drop`이 아주 큰 수(예: 1e12)면 `count × 상점가`가 그대로 골드가 된다. 장수에 상한이 없다. `infiniteBest`가 NaN일 때 `math.max(1, NaN)`의 결과도 확인이 필요하다. | 이미 이관된 계정에는 영향이 없다. 옛 저장을 처음 불러올 때만 해당한다. | 장수를 합리적인 값(예: 지급 일정상 최대 139 + 구매분)으로 자르고 `best`에 `Sanitize`를 건다. | 20분 |
| 31 | 낮음(확인 필요) | 경제 | `server/CombatResolution.lua:308-323` · `server/ProtectionTickets.lua:71-83` | 보스 첫 처치 골드는 **보스 스테이지** 표 값(`BossFirstClearGoldData`)이고 계정당 한 번이다. 파티 보스에서 기여 10%만 넘기면 받는 사람의 자기 스테이지와 상관없이 받는다(예: 10,080 = 1.4e8골드). | 낮은 계정이 캐리를 받으면 자기 수입의 수만 배를 한 번에 받는다. 계정당 한 번이고 파티 입장 밴드로 격차가 제한되므로 크지는 않을 것으로 본다. | 파티 입장 밴드 폭을 확인한다. 필요하면 지급액을 `min(표 값, 받는 사람 최고 스테이지의 표 값)`으로 제한한다. | 확인 30분 |
| 32 | 낮음 | 경제 | `client/panels/CodexV2/Info.lua:217-221` · `server/CodexService.lua:215` | 도감 칸 보상 미리보기는 지금 계정 최고 스테이지로 골드를 계산한다. 서버는 칸이 완료된 순간의 스테이지(`r.done[id]`)로 지급한다. | 화면 숫자와 실제 지급이 다를 수 있다(주석은 "어림"이라고 적었다). | 서버 view에 `done` 스테이지를 같이 내려 클라가 그 값으로 계산하게 한다. | 30분 |
| 33 | 낮음 | 등급 B | `client/panels/Inventory/GemTab.lua:520` vs `shared/ItemDescribe.lua:72` | 치명 옵션 보석을 홈에 끼우고 홈 줄과 툴팁을 비교 | 같은 값이 홈 줄은 `치피+11.50`(×100, % 없음), 툴팁은 `치피 +0.12`로 다르게 보인다(critDmgBase 0.115 - `OptionData.lua:60`) | 둘 중 하나로 통일(한 함수 - ItemDescribe.optionLines를 홈 줄도 쓰게) | 30분 |
| 34 | 낮음 | 등급 B | `client/hud/PartyRequests.client.lua:100-104` | 파티 보스 [다시 도전] · [포기] 투표가 통과/무산 | 결과 배너 제목이 항상 "보스 입장 투표"(`vote.enter.title`)로 바뀐다. 서버 `PartyVote.finish`(`server/PartyVote.lua:48-49`)가 kind를 안 실어 클라가 구분 못 한다 | finish 페이로드에 kind를 싣고 제목 키를 kind로 고른다 | 30분 |
| 35 | 낮음 | 등급 B | `server/PartyVote.lua:141-149` | 투표 도중 파티원이 탈퇴 · 추방 | `cancel`이 클라에 아무것도 안 보내 투표 배너가 남은 시간 동안 떠 있고, 누른 표는 서버가 조용히 버린다 | cancel 때 남은 대상자에게 `{ result = "failed" }`(또는 "cancelled") 한 번 | 20분 |
| 36 | 낮음 | 등급 B | `shared/NumberFormat.lua:62-66` (luau 실행 확인) | `NumberFormat.format(-123456)` · `commas(-999999)` | `-,123,456`이 나온다(자릿수가 3의 배수인 음수). 또 `format`은 음수를 줄이지 않아 `-1e20` = `-,100,000,…`(26자). 지금 호출부는 대부분 절댓값을 넘겨(`EquipCompare.lua:103` · `DamageNumbers.lua:122`) 잠복 상태 | `withCommas`에서 부호를 떼고 붙이기 + `format`도 음수면 `"-" .. format(-n)`(currency와 같은 방식) | 20분 |
| 37 | 낮음 | 등급 B | `client/ui/kit/Toast.lua:505-518` | `groupKey` + `fadeSeconds` 알림이 흐려지는 도중(대기열 단축 passOn으로 seconds가 0까지 줄 때) 같은 키가 다시 온다 | 진행 중인 흐림 트윈을 안 멈춰 합쳐진 행(×2)이 투명한 채 자리만 차지했다가 사라진다. 지금 TR(대기열 없음)에서는 합침 창(1초) < 표시 시간이라 잘 안 난다 | tryMerge에서 `row.fading`이면 `restoreVisual(row)` 먼저 | 15분 |
| 38 | 낮음 | 등급 B | `server/TutorialState.lua:214` | 견습 보스 모델에 PrimaryPart가 없는 채 처치 판정(메시 교체 · 아트 스위치 등) | `target.PrimaryPart.Position` nil 접근으로 졸업 · 다음 단계 진행이 통째로 멈춘다(확인 필요 - 지금 MonsterSpawner는 PrimaryPart를 준다고 가정) | `target:GetPivot().Position`으로 | 10분 |
| 39 | 낮음 | 등급 B | `server/TutorialState.lua:296-310` | Studio에서 플레이어가 모듈 로드보다 먼저 들어온 경우 | `PlayerAdded`만 걸고 이미 있는 플레이어를 안 돈다 - 견습 재개가 안 걸릴 수 있다(라이브에서는 드묾 · 확인 필요) | 끝에 `for _, p in Players:GetPlayers()` 한 번 | 10분 |
| 40 | 낮음 | 등급 B | `server/BuffState.lua:77-89` · `:204-208` | 파티 버프(healerBuff · warcryBuff)가 퇴장 직후의 멤버에게 걸린다(지연 콜백) | PlayerRemoving 뒤에 `buffs[player]`가 다시 생겨 남고, 0.5초 스윕이 떠난 Player에게 FireClient를 시도한다(확인 필요 - 오류 여부) | apply 첫 줄에 `if not player.Parent then return end` | 10분 |
| 41 | 낮음 | 등급 B | `client/panels/Enhance/init.lua:430-443` | 강화대 반경 안에서 가방(window)을 연 채 서 있는다 | 매 Heartbeat마다 `ensureBuilt` → `Theme.recompute()` + `UIManager.open`(window 때문에 실패)을 반복한다(성능만) | open이 window 때문에 막히면 그 프레임은 건너뛰는 플래그, 또는 `UIManager.changed`로 다시 시도 | 20분 |
| 42 | 낮음 | 등급 B | `client/UIManager.lua:418` · `client/StageSelectPanel.lua:703` | 언어 설정 Attribute가 모듈 로드 뒤 도착 | `blockedTexts` · `blockedText`를 로드 시점에 한 번 만들어 그 뒤 언어와 다를 수 있다(확인 필요 - 언어 변경 = 재접속 규칙이면 무해) | 쓰는 순간 `Text.get` | 10분 |
| 43 | 낮음 | 등급 B | `server/HuntingGround.server.lua:100-108` · `:182-202` · `shared/data/WorldConfig.lua:248-249` · `:260-261` | 언어 en | 서버가 만든 프롬프트(환생 제단 · 보석상인 · 상점)의 ObjectText/ActionText가 한국어 고정(이름표 TextLabel은 `bindName`으로 번역되는데 프롬프트는 빠짐). 허브 서비스 프롬프트는 클라가 다시 쓴다(`client/HubServices.client.lua:53-54`) | 클라 쪽에서 세 프롬프트도 relabel(HubServices 패턴) | 30분 |
| 44 | 낮음 | 등급 B | `client/panels/Inventory/BulkSell.lua:205-210` | 언어 en · 일괄 분해 합계 줄 | "영웅 3 · 전설 1"을 한국어 displayName으로 이어 붙여 넘긴다 - `Text.nameIn`은 " · " 조각이 사전에 있을 때만 바꾸므로 "영웅 3"은 안 바뀐다 | 등급 이름을 `Text.name`으로 바꾼 뒤 이어 붙이기 | 10분 |
| 45 | 낮음 L1 | 보안 | AttackServer.server.lua:315 · 329 · 343 | 근접 직업이 NaN 성분 Vector3를 aimPoint로 보낸다. | AimPicker.pick(shared/AimPicker.lua:18-54)에서 direction이 NaN → dot 비교가 거짓 → 최근접 대상으로 대체된다. 피해 없음. | 원거리와 같은 NaN 검사를 분기 앞으로 옮긴다(일관성). | 5분 |
| 46 | 낮음 L2 | 보안 | OpsServer.server.lua:173-201 | 운영자가 `/ops revoke <id> gold inf`를 입력한다. `amount ~= amount`는 NaN만 거른다. | takeGold(inf) 뒤 `%d` 포맷 에러 → pcall이 잡아 "error"로 보고된다. 실제 골드 변화는 확인 필요. 운영자만 가능하다. | `amount == math.huge` 거부 · 정수 상한 추가 | 5분 |
| 47 | 낮음 L3 | 보안 | BossLinger.lua:178 · 182 · TutorialState.lua:292 · DropTableServer.server.lua:23 | 클라가 초당 수백 번 쏜다. | 각 핸들러가 상태 검사로 금방 끝나서 실해는 없다. SuspicionMonitor의 요청 폭주 탐지에서 빠진다. | `RequestGate.allow(player, "<이름>")` 한 줄씩 추가(기본 통) | 15분 |
| 48 | 낮음 L4 | 보안 | OpsServer.server.lua:100-120 | 미리보기만 하고 confirm을 안 하면 `pendingConfirm` 항목이 남는다. | 서버 수명 동안 몇 개 쌓일 뿐이다(운영자만 만듦). | issueToken 때 만료 항목 청소 | 10분 |
| 49 | 낮음 L5 | 보안 | MovementServer.server.lua:90-94 | 서버가 강제 발사를 건 뒤 클라가 PlayerGetup을 보낸다. | 거리와 무관하게 서버 전원에게 "getup" 모션이 중계된다. 발사 1건당 1회라 증폭은 없다. | AirMoveFx처럼 relayRangeStuds 안만 보내기 | 10분 |
| 50 | 낮음 L6 | 보안 | MovementServer.server.lua:224-229 | 장갑 없는 클라가 LedgeClimb을 0.3초마다 보낸다. | 거절 print가 초당 약 3줄 찍힌다(로그 스팸). | 거절 로그를 사람당 초당 1줄로(SoulService.rejectAction 방식) 또는 M1 스위치 | 10분 |
| 51 | 낮음 L7 | 보안 | RangedLagAssist.lua:22-35 | 클라가 LatencyEcho 응답을 일부러 늦게 보낸다. | 왕복 핑이 lagMaxSeconds 상한까지 부풀어 원거리 조준 보정 반경이 상한만큼 넓어진다. 판정 · 피해 · 사거리는 서버라 영향이 작다. | 표시만 하고 둔다(설계상 허용 범위). 필요하면 서버 GetNetworkPing 대조 | - |
| 52 | 낮음 L8 | 보안 | SkillServer.server.lua:532 | 사냥꾼의 덫 aimPoint의 Y를 아주 크게(또는 inf) 보낸다. horizontalDistance만 검사한다. | 덫 파트가 지도 밖 높이에 생긴다. 발동 판정이 수평이면 층이 다른 대상에 걸릴 수 있다(확인 필요). | aimPoint.Y를 시전자 발 ± 허용치로 자르거나 지면 광선으로 내린다 | 15분 |
| 53 | 낮음 L9 | 보안 | DevToolsConfig.allowedUserIds = {} (shared/data/DevToolsConfig.lua) | Studio "로컬 서버 + 여러 클라" 테스트 · Team Create에 들어온 아무나 `/gg`를 쓸 수 있다. | 라이브와는 무관하다(IsStudio). 공유 Studio 세션에서 남이 개발 계정 세션 메모리를 바꿀 수 있다. DevTools는 저장을 막지만(SaveCoordinator) 영향 범위는 확인 필요. | 지금대로 둔다(로컬 다중 클라는 음수 UserId라 목록을 넣으면 시험이 막힌다). 기록만. | - |
| 54 | 낮음 | 저장 | `server/PrimordialRegistry.lua:138-156` · `:291` · `server/AcquisitionAudit.lua:274-286` | 태초 · 초월을 받자마자 퇴장(또는 서버 종료) → 퇴장 저장이 `stamp.pending = true, no = nil`로 써짐 → 번호는 그 뒤 발급되지만 `onNumbered`는 `player.Parent`가 없어 저장 안 함 | 원장 · 명예의 전당에는 번호가 있는데 아이템은 영구히 "세계 번호 확인 중"(`PrimordialStamp.lua:54`). 번호 하나가 허공에 씀 | `auditProfile`에서 `stamp.no == nil`이고 원장 `entry.no`가 있으면 각인에 번호를 옮기고 `pending`을 지움 | 0.5시간 |
| 55 | 낮음 | 저장 | `server/SaveServer.server.lua:119-125` | DataStore가 느릴 때 자동저장 루프가 사람마다 차례로 `saveForPlayer`를 기다림(한 명당 최대 재시도 대기 10초 + 호출 시간) | 16명이면 한 바퀴가 수 분까지 늘어 실제 자동저장 주기가 길어짐(손실 창이 커짐) | 사람마다 `task.spawn`(종료 저장처럼 동시에) | 0.3시간 |
| 56 | 낮음 | 저장 | `server/SaveSystem.lua:1825-1827` | 보관 칸(quarantine)의 장비 id가 다시 생기면 가방 칸 수를 보지 않고 `table.insert(data.inventory, v)` | 가방이 75칸을 넘을 수 있음(넘친 칸은 더 넣기만 막힘, 손실은 없음) | 의도라면 주석만. 아니면 넘치면 보관 칸에 남김 | 0.3시간 |
| 57 | 낮음(Studio 전용) | 저장 | `server/PlayerProfile.lua:2802`(스냅샷) vs `:2829-2890`(복원) | `/gg` 명령 뒤 `/gg reset` | `checkpoints`는 백업은 되는데 복원 코드가 없음. `purchases.bagSources` · `shopViews`(v69) · `tutorial` · `audit` · `optionRerollTickets` · `bulkSellCutoffGrade` · `inventoryWindowPosition`은 백업 대상이 아님. 라이브 영향은 없음(Studio는 `_manual` · `_verify` 키, `SaveSystem.lua:144-156`) | 복원에 `checkpoints` 한 줄 추가. v69 두 필드는 "새 저장 필드 = 백업 대상" 규칙대로 추가 | 0.3시간 |
| 58 | 낮음 | 전투 | UltimateService.lua:63-73 (`onDealt` 쌍검 · 활 = `perHit`, `dealt` 무관) | 막힌 몹(스틸 불가 — 피해 0) · 보호막 보스(`taken = 0`) · 진입 연출 중 보스 · 구출 대상을 쌍검 · 활로 친다. | 피해 0 타격으로도 궁극기 게이지가 찬다. | `onDealt` 앞에서 `dealt > 0`일 때만 충전하도록 호출부 3곳(AttackServer 482 · 610, SkillServer 112)이나 `onDealt` 안을 고친다. | 20분 |
| 59 | 낮음 | 전투 | CombatResolution.lua:299, 437 (`target.PrimaryPart.Position`) | 처치 순간 모델의 PrimaryPart가 없으면(파트 소실 등) `tryClaimDeath` 뒤에 에러가 난다. | 이미 claimed 상태라 `despawn`이 영영 안 불린다. 잡몹은 그 슬롯이 다시 생기지 않고, 보스는 encounter가 끝나지 않는다. 보상 루프 중간 에러(`grantKillReward` 내부)도 같은 결과다(뒤 기여자는 보상을 못 받는다). | 위치는 `PrimaryPart and … or model:GetPivot().Position`으로 받는다. 보상 루프는 기여자마다 `pcall`로 감싸고 `despawn`은 항상 실행한다. | 30분 |
| 60 | 낮음 | 전투 | CombatResolution.lua:193, 230 (`DropTable.gainOnly` 전역 플래그) | `Loot.roll*`이 에러를 내면 230줄(`gainOnly = false`)이 실행되지 않는다. | 그 뒤 다른 플레이어의 굴림도 "첫 환생 전 = 이득만" 규칙으로 굴러간다(전역 상태 누수). | 인자로 넘기거나 `pcall` 뒤 항상 되돌린다. | 20분 |
| 61 | 낮음 | 전투 | MonsterAI.server.lua:463, 473 (`PlayerState.getHp(member) > 0`) | 보스 멤버의 PlayerState 항목이 없으면 nil 비교 에러가 난다(다른 곳은 `or 0`을 쓴다 — 447, 497). | Heartbeat 루프에 `pcall`이 없어(567) 그 프레임의 나머지 몹 처리가 끊긴다. 지금은 퇴장 핸들러가 같은 프레임에 멤버를 빼므로 재현 경로를 찾지 못했다 → **확인 필요**. | `(PlayerState.getHp(member) or 0) > 0`으로 통일한다. | 10분 |
| 62 | 낮음 | 전투 | PlayerState.lua:249 + BossEnvironment.lua:480 · DevTools.server.lua:3303 | 0배 출처(`"bossRocket"` · `"devGod"`)를 `setIncomingDamageMultiplierUntil(…, 0, …)`로 건다 → 하한 `incomingDamageMultiplierFloor = 0.25`(CombatConfig.lua:105)에 막혀 0.25배가 된다. | 로켓은 PlayerDamage.lua:64의 `isRocketing` 면역이 따로 있어 실제 피해는 없다(죽은 코드). `/gg god`은 메모리에 적힌 대로 고스테이지에서 한 방에 죽는다. 설계 주석(CombatConfig.lua:104 "완전 무적은 setInvulnerableUntil")과 어긋난다. | 두 곳 모두 `PlayerState.setInvulnerableUntil`로 바꾼다. | 20분 |
| 63 | 낮음 | 전투 | MonsterState.lua:305-424 (몬스터 피해 출구에 `Sanitize` 없음) | 지금은 재현 경로가 없다. 앞으로 새 배율이 NaN을 내면 `hpRatio`/`hp`가 NaN이 된다. | NaN 몹은 `<= 0`이 영원히 거짓이라 죽지 않는다. HP바도 NaN이 된다. 플레이어 쪽(PlayerDamage.lua:182)과 대칭이 아니다. | `applyDamage` 맨 앞에서 `damage = Sanitize.number(damage, 0)`을 적용하고, 음수도 0으로 자른다. | 10분 |
| 64 | 낮음 | 전투 | SkillServer.server.lua:164-168 (`castLineAttack` — 바라보는 방향이 0이면 그냥 return) + 744 (`markCast`가 먼저) | 수평 바라봄이 없는 순간 Q를 쓰면 쿨다운만 쓰이고, 결과 이벤트가 안 가 클라 슬롯이 어긋난다. | 드문 경우다. 쿨다운만 버려진다. | 방향 검사를 `markCast` 앞으로 옮기거나 `reject`를 보낸다. | 10분 |
| 65 | 낮음 | 전투 | AttackServer.server.lua:271-300, 358-361 | 구역 밖에서 공격하면 쿨다운 · 콤보 증가 · 남의 화면 모션 중계(306)가 먼저 일어나고 그다음에 차단된다. | 차단된 공격도 모션이 남에게 보이고 콤보가 쌓인다(3타 강공격 자리를 미리 소모할 수 있다). | 대상 선정 직후로 구역 검사를 앞당긴다(모션 중계 전). | 20분 |
| 66 | 낮음 | 전투 | DashServer.server.lua:35-53 | 영혼(SoulService) 상태에서 대시 요청을 보낸다. 평타 · 스킬은 `rejectAction`으로 막지만(AttackServer 200, SkillServer 675) 대시는 검사가 없다. | 관전 중에도 대시 · 대시 피해 감소가 걸린다. 영혼은 피해를 안 받으니 실질 영향은 작다 → **확인 필요**(설계 의도). | `SoulService.rejectAction(player, "대시")`를 추가한다. | 10분 |
| 67 | 낮음 | 전투 | AttackServer.lua:343 · SkillServer.lua:306 · AimPicker.lua:36 (`rootPart.Position` = 클라 소유 물리) | 위치 조작(순간이동 → 타격 → 복귀를 0.25초 폴링 사이에)을 한다. 사거리 검사는 복제된 루트 위치만 믿는다. | HeightGuard의 수평 검사(HeightGuard.lua:404, 폴링 0.25초)가 있지만, 공격 판정이 그 상태를 보지 않는다. 일반적인 로블록스 신뢰 모델의 한계다 → **확인 필요**. | 공격 판정에서 "직전 HeightGuard 표본과의 거리"가 상한을 넘으면 그 요청을 거부한다(선택). | 2시간 |
| 68 | 낮음 | 전투 | tools/harness/attack_test.luau:1-94 | 이름은 "공격 하네스"인데, 실제로는 판매 · 퀘스트 · 펫 · 설정 · 낙하 신고 원격만 시험한다. | AttackRequest · SkillRequest(잘못된 인자 · 연타 · NaN 조준점 · 구역 밖) 회귀 시험이 없다. | `handleAttack`/`handleSkill` 입력 퍼징 항목을 추가한다(NaN · 2000 stud 밖 · 숫자 아닌 seq · 연타 빈도). | 2시간 |

## 3. 설계와 어긋난 코드(현재 결정 대조)

| 결정 | 판정 | 어긋난 곳(근거) |
|---|---|---|
| 방지권 폐지(v68 골드 환산) | 동작은 일치 · **잔재 많음** | 무료 줄 · 출석판 "성장 재화" 허용 목록에 `protectDrop`(`shared/Monetization.lua:172` · `SeasonPassData.lua:121` · `SeasonBoardData.lua:28` - 누가 무료 줄에 넣으면 지급 실패 → 받은 표시 없음 → 반복 지급 경로, 경제 감사 낮음) · 구매 · 가격 Remote 4개 살아 있음(`ProtectionTicketServer.server.lua` - 클라 참조 0) · `ProtectionTickets.lua:44` 아래 죽은 구매 본문 · 접속 때 `ProtectionDrop/Reset` Attribute(`PlayerProfile.lua:267-271` - 클라 읽기 0) · `/gg ticket` 명령(Studio) · 주석 · 용어("방지권 토글") 10여 곳 · 문서 `monetization-p4c.md:45 · 52` · `gold-budget-g3.md` 1절 표 · 검증 블록 `EnhanceVerify`[17] · `P25cVerify`(exclude 상태) |
| 판매 NPC 제거(가방에서 판매) | 일치 | 판매 NPC · 거리 판정 grep 0 · 판매 = `SellRequest`(가방)뿐 |
| 상점 탭(추천 · 치장 · 시즌 패스 · 편의) | 일치 | `Shop/init.lua:39 · 100`(골드 탭 = 보석상인 좌판에서만) |
| 출석 로벅스 구매 없음 | 일치 | 상품 · 패스에 출석 없음 · 출석판 치장 `boardOnly` |
| 등급 8색 | 일치(값) | 주석만 옛것: `ItemVisualData.lua:87-97`(태초 "진한 자홍" ↔ 실제 흰 + 자홍 외곽선) · `:124-127` "7등급" |
| 시즌 패스 칸당 170 · 무료 줄 성장 재화 | 일치 | `SeasonPassData.lua:110` · 단 칸 건너뛰기 → 반복 보너스 칸 골드가 토큰으로 안 바뀌어 "로벅스로 성장 재화" 우회 가능성(결제 감사 중간 · 확인 필요) |
| 꾸미기 토큰 | 일치 | 화면 가격(Creator Hub) ↔ 토큰 가격 기준(데이터 `robux`)이 어긋날 수 있음 · `SeasonTab.lua:251` 기본값 399 하드코딩 |
| 강화 최상위(+26 하락 없음 · 바닥 17/22 · 방지 ×k) | 일치 | `EnhanceConfig.lua:385-398` · `Enhance.lua:40-58 · 144-145` |
| 공식 Shop 버튼 끔 | 일치 | `Shop/init.lua:681` `SetCoreGuiEnabled(ExperienceShop, false)` |
| 서버 최대 16명 | **코드는 맞고 플랫폼 설정 미완** | `PartyConfig.serverCapacity` 16 · Studio 로그 "플랫폼 MaxPlayers=60 - 대시보드 Max Players=16 · 매치메이킹 정원 12로 맞춰야" · 저장 감사 문서 · 하네스(`save_launch_test` CLOSE · BUDGET)는 12인 기준 |
| 판매 금지 목록(forbiddenKinds) · 유료 랜덤 없음 | 일치 | 상품 · 토큰 · 유료 줄 · 환산 모두 `checkGrant` 통과 |
| 펫 등급 이름(일반 · 희귀 · 영웅 · 전설) | 일치 | `EggData.hatchGradeNames` · `GradeColor.petGrade` |
| 변신 = 전용 캐릭터 | 일치 | 아바타 변신 스위치 끔(코드 남김 - ALL9C 2-4) |
| 가방 최대 75 | **상한은 맞음 · 마일스톤 +5와 겹치면 유료 칸이 잘림** | `InventorySync.lua:51-52` - 마일스톤(25) + 패스 + 스타터 = 80 → 75(결정 필요 1) |
| 보스 수치 한 곳(BossRules) · HP 한 곳(InfiniteStage) | 어긋남 | 2회차 HP 배수(`BossEncounter.lua:383`) · 주간 도전 변형(`WeeklyChallenge.lua:18-43`)이 밖에서 곱함 → 미리보기 · EconSim이 모름 |
| CLAUDE.md "스킬 = effects 조각 조합 · 스킬 전용 함수 금지" | 어긋남(적용 범위 확인 필요) | `SkillServer`는 shape마다 전용 함수 12종 - 웹판 규칙인지 로블록스에도 해당하는지 결정 필요 |
| CLAUDE.md "밸런스 수치는 data/에만" | 일부 어긋남 | `ImmediateSave.lua:17` 6초 · 원장 재시도 횟수 · `AttackServer.lua:61 · 117 · 329` 표시 거리 · 변환권 가격 식 3벌(`GemServer:74` · `GemWorkshop/init.lua:80` · `Shop/GoldTab.lua:24`) |
| 자동 정리(이번 A-1) 대 일괄 판매 | 의도된 차이 | 자동 정리만 보스 · 토벌 출처 제외(A-1 결정 필요 1) |

## 4. 출시 전 제거 · 설정 목록

| 항목 | 위치 | 상태 | 할 일 |
|---|---|---|---|
| 개발 명령 `/gg` 권한 | `DevTools.server.lua:20` | 라이브에서 꺼짐(IsStudio 가드가 명령 · Remote 생성보다 앞) · UserId 우회 없음(`allowedUserIds = {}`) | 없음 |
| 운영 명령 `/ops` 계정 | `OpsConfig.lua:3`(개발 계정 1개) | 의도된 라이브 권한 | 그 계정 2단계 인증 필수 · 운영자 늘릴 때 그룹 랭크 방식(결정 필요 7) |
| 테스트 데이터 · Studio 저장 키 | `_manual` · `_verify` 키 · 강화 결과 주입 `debugRolls` | 모두 IsStudio 가드 | 없음 |
| 디버그 · 로그 print | 라이브 서버 경로 약 237줄 · 피격마다(`PlayerDamage.lua:93`) · 몹 사망마다(`MonsterSpawner.lua:587`) · 드랍마다(`CombatResolution.lua:258 · 265`) · 강화마다(`EnhanceService.lua:138`) | 라이브 로그를 덮음 | data에 로그 단계 스위치 + 잦은 줄 감싸기(약 2시간) |
| TEMP 값 | `client/BossGimmick13View.lua:21` `TEMP_SOUND`(Roblox 기본 효과음) · `InfiniteStageConfig.lua:49` 임시 상한 34,230 > 하드 상한 25,300(죽은 값) | 남음 | 소리 교체 · 상한 하나로 정리할지 결정 |
| 자리값 "NAME" | `GameInfoData.lua:4`(게임 이름) | check_textdata 경고 중 | 게임 이름 확정 |
| 상품 · 게임패스 id | `MonetizationData.lua` productId 0 = 23개(출시 공개 15) · passId 0 = 6개(출시 공개 5) | 전부 0 | Creator Hub 등록 후 입력 · 패스 id 중복 검사 없음(수동 확인) |
| 시즌 시작일 | `LeaderboardConfig.lua:16 · 22`(`seasonStartUnix = 0` · `firstSeasonDateKst = nil`) | 시즌 패스가 한 시즌에 멈춤 | 출시 체크리스트 P6 |
| 상점 NEW 기준일 | `MonetizationData.lua:68` `releaseStageStartUtc` 자리값(10-03) | 자리값 | 실제 출시일 |
| 묶음 가격 | `bundle_blacksmith` 499 > 구성품 합 447 | 경고만 | 공개 전 결정 |
| 이름표 세트 패스 | `nameplateSet` - `includes`를 펼치는 서버 코드 없음(결제 감사 높음 · 잠복) | 공개 단계 2 · passId 0 | 고치기 전 공개 금지 |
| 시험 기록 분리(launchEpoch) | 없음 - 라이브 친구 시험 기록이 세계 번호 · 명예의 전당에 남음 | 미구현 | `docs/audit/unimplemented.md` F5 |
| 임시 모델 | 환생 제단 · 보석상인(`HuntingGround.server.lua:52 · 116` · `WorldConfig.lua:241 · 252`) | 임시 | 아트 일정 |
| 검증 모듈 71개(`server/*Verify.lua`) | 라이브에서 require 안 됨(DevTools만) · 서버 전용 | 남음 | 그대로(삭제 금지 원칙) |

## 5. 등급 C 자동 스캔

| 검사 | 결과 |
|---|---|
| `run_all.sh` | 전부 통과(블록 A 끝 - `docs/phase/QUEUE-ALL9C-F-report.md` 검증 절) |
| `check_textdata` · `check_names` · `check_grade_colors` | 통과(경고 = 게임 이름 "NAME") |
| `luau-analyze` 전체(`roblox/src` .lua 800개) | 19,859줄 중 Roblox 전역 · require 경고 제외 400줄: UnknownType 240(타입 표기) · TypeError 91(대부분 추론 한계 - 검증 모듈 `BR1Verify.lua` 인자 개수 8 · `PartyCrossServer.lua:947 · 952` 오탐) · LocalUnused 18 · LocalShadow 13 · MisleadingAndOr 4 · TableOperations 4 · ForRange 2(`client/panels/Inherit.lua:182 · 272` - 0부터 도는 루프, 확인 필요) · DuplicateCondition 2 · UnreachableCode 1(`WeaponEnhanceVisual.lua:75`) · DeprecatedApi 1(`TerrainBakeRun.lua:20` getfenv - edit 전용) |
| 분석기가 잡은 실제 결함 | `SaveSystem.lua:2116` `ok and nil or tostring(err)` → 성공해도 두 번째 값이 문자열 "nil"(호출부 `OpsRollback:174`는 첫 값만 봄 - 영향 없음 · 낮음) · `MonsterState.lua:104` `isBoss and nil or 1.0` → 보스도 hpRatio 1.0(주석은 nil · 읽는 곳 없음 - 낮음) · `BossLinger.lua:63 · 66` 같은 꼴(사용 가능일 때도 이유 문구를 넘김 - 표시 영향 확인 필요) · `ArtV1Cosmetics.client.lua:171` 같은 조건 두 번 |
| 참조 0 모듈 | `client/A1UiMockups.lua`(목업 · 명령줄 전용) · `server/TerrainBakeRun.lua`(edit 명령줄 실행기 - 의도) · `server/TeleportPad.lua`(주석에만 이름 - 등급 B 감사) |
| 클라 참조 0 Remote | `ProtectionTicketBuyRequest` · `ProtectionTicketBuyResult` · `ProtectionTicketGranted` · `ProtectionTicketPriceRequest`(방지권 폐지 잔재) · `BulkSellCutoffRequest`(옛 일괄 판매 기준 - QUEUE-ALL8 체크 방식으로 바뀜) · `RaidRequest`(BossGate만 - 확인 필요) · `OpsReply`(운영 응답 - 클라 표시 없음, 확인 필요) · `DropTableQuery`(이름이 변수로 쓰여 grep에 안 잡힐 수 있음 - 확인 필요) |
| 안 쓰는 글 키 | `toast.autoSell` · `toast.autoDismantle`(이번 A-1 묶음 알림으로 대체 - 그대로 둠) |
| 에셋 id | `ArtAssetIds` 752키 중 코드에 글자 그대로 없는 656키 - 634키는 경로 앞부분(`icons/gear_v3/` 등)이 코드에서 조합됨 = 사용 중으로 봄 · 나머지 22키 = `icons/gear_v3/*_greatsword_*`(ALL9E 아이콘 112장 전환 전) · `extras/vfx/*` 6개(Telegraph · Impact · Shock · WarnPillar - 연출 자리) → **에셋은 지우지 않음**(목록만) |
| TODO · FIXME · HACK | 0 |
| 옛 기대값이 틀린 하네스 · 검증 블록 | `EnhanceVerify.lua:1375-1406`([17] 방지권 구매 성공 기대) · `P25cVerify.lua:324-327`(방지권 지급) - 둘 다 `DevToolsConfig.lua:42 exclude` · `save_launch_test` CLOSE · BUDGET 12인 기준(정원 16) · `monetize_test.luau:106-112` · `:503`(즉시-1 · 마일스톤 경우 빠짐) · `economy_all9b_test.luau:35-40`(보석 판매 스테이지 같은 경우만) · `attack_test.luau`(이름과 달리 Attack · Skill Remote 미시험) |

## 6. 삭제 규칙 위반 흔적(전체 이력 `git log --diff-filter=D` = 56건)

| 커밋 · 날짜 | 지운 것 | 판정 | 복구 필요 |
|---|---|---|---|
| b6c4a922 · 10-02 | `Claude outputs/QUEUE-ALL7B/*.jpg` 7장 | 의도 - 캡처 폴더 추적 해제(파일은 디스크에 남음) | 아니오 |
| 7e7ec66e · 09-30 | `roblox/art/**/*.blend1` 26개 | 의도 - Blender 자동 백업 추적 해제 + .gitignore | 아니오 |
| fbd4e7ca · fb55f304 · 2b78de9b · 09-30 | `roblox/art/_permtest.txt` · `__pycache__/*.pyc` 4개 | 의도 - 실수로 커밋된 시험 · 캐시 파일 | 아니오 |
| 21a5c1f3 · b10a6499 · 09-26 ~ 27 | `server/BossGimmick4Verify` · `BossSkillVerify` · `BossGimmick5Verify` · `BossGimmickVerify` | 의도 - 검증 통합(옛 스위치 삭제) · 삭제 금지 규칙(10-03) 전 | 아니오(검증은 BR1Verify 등으로 옮김) |
| cabf4f8c · 09-25 | `client/ComboRing.lua` | 의도 - 조준 결정 반영 리팩터 | 아니오 |
| 0a37ecb6 · afe0e9af · 07760223 · 09-20 | `client/PartyHud` · `ItemPickupHud` · `LevelUpHud` · `SaveNoticeHud` · `TreasureChestHud` · `ZoneBlockedHud` · `server/FreezeProbe` | 의도 - 분할 · Toast 통합(S17 · S18 · S15) | 아니오 |
| 3a9e1de7 · 09-19 | `HANDOFF-29-5.md` | 의도로 보임 - 인계 문서(그 커밋이 PRD 20.80에 반영) | 아니오(내용은 git 이력에 남음) |
| 59470ece · 794932b8 · 08-30 | `.gitkeep` 2개 | 의도 | 아니오 |
| 1384092b · 08-23 | `core/equipEnhance.js`(웹판) | 의도 - 장비 강화 폐지(아이템 레벨 각인으로 대체) | 아니오 |

- 삭제 금지 규칙(사용자 10-03) 뒤 지워진 파일 = **0**(마지막 삭제 = 10-02 캡처 추적 해제). 실수 삭제로 보이는 것 0 · 복구 필요 0.

## 7. 숫자 요약

| 항목 | 값 |
|---|---|
| 즉시 확인(치명) | **2**(결제 이중 지급 · 보스전 직업 전환) |
| 버그(영역 표 합계 68줄 · 같은 결함 중복 1 → 67건) | 치명 1(즉시-1) · 높음 3(1 = 즉시-1 중복 · 1 = 즉시-2 · 1 = 이름표 세트 패스 잠복) · 중간 15 · 낮음 49 |
| 영역별 | 저장 치명 1 · 중간 2 · 낮음 4 / 결제 높음 2 · 중간 2 · 낮음 4 / 보안 높음 1 · 중간 3 · 낮음 9 / 경제 중간 3 · 낮음 9 / 전투 중간 3 · 낮음 11 / 등급 B 중간 2 · 낮음 12 |
| 설계와 어긋난 코드 | 결정 대조 18줄 중 일치 12 · 잔재 · 부분 6 |
| 출시 전 설정 | productId 0 = 23 · passId 0 = 6 · 시즌 시작일 · NEW 기준일 · 게임 이름 · 대시보드 정원 16 |
| 라이브 서버 print | 약 237줄 |
| Remote(클라 → 서버) | 61개(RemoteEvent 46 · RemoteFunction 15) · RequestGate 밖 자체 제한 · 제한 없음 29개(문서 R5는 4개로 적음) |
| 정리 후보 | 25(A 삭제 안전 8 · B 보존 1 · C 사용자 결정 7 · D 비활성화만 9) - `docs/audit/cleanup-candidates.md` |
| 미구현 | 출시 필수 9(약 40.8h · ALL10 30h 포함) · 권장 19(약 55.5h) · 출시 후 18 · 폐기 후보 7 · 완료 확인 40여 - `docs/audit/unimplemented.md` |

## 결정 필요(블록 B)

1. 가방 상한 75에 마일스톤 +5를 넣을지(지금 = 마일스톤 + 패스 + 스타터면 80 → 75로 잘려 유료 칸 5칸 손실) - 추천: 마일스톤은 상한 밖(80까지 허용)으로.
2. 즉시-1 · 즉시-2를 다음 큐 맨 앞에서 고칠지 - 추천: 예(합 2 ~ 2.5시간 · 하네스 포함).
3. 방지권 잔재 정리 범위 - 추천: `protectDrop` 허용 목록 3곳 · 죽은 구매 본문 · 클라 없는 Attribute는 스위치/정리, Remote 이름 · 저장 필드 · id는 보존.
4. 보석 판매가 기준 스테이지(계정 최고 vs 보석 itemLevel) - 추천: itemLevel(ALL9B 1-3 "바로 팔기 손해 역전 없음" 유지).
5. 덫 · 활 궁극기 구역 판정을 시전자 기준으로 - 추천: 예(각 1시간).
6. CLAUDE.md 스킬 규칙(effects 조각)이 로블록스에도 적용되는지 - 추천: 웹판 전용으로 문구 명시.
7. 운영 계정 권한 - 추천: 출시 전 2단계 인증 확인 · 운영자 추가는 그룹 랭크로.
8. 로그 단계 스위치(잦은 print) - 추천: 출시 전 도입.
