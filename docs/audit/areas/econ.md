# 경제 공식 감사 (골드 수입 · 지출 · 강화 · 수련 · 드랍 · 보상)

- 범위: `roblox/src` 읽기 전용 감사(파일 수정 0 · Studio 사용 0). 기준 커밋 = `f639a73e`(master).
- 읽은 핵심 파일: `server/PlayerProfile.lua`(골드 · 재료 · 판매 · 분해 · 계승 · 수련 · 각성) · `shared/Enhance.lua` · `shared/data/EnhanceConfig.lua` · `server/EnhanceService.lua` · `server/EnhancePolicy.lua` · `server/EnhanceServer.server.lua` · `shared/GoldCost.lua` · `shared/data/GoldCostConfig.lua` · `shared/InfiniteStage.lua` · `shared/data/InfiniteStageConfig.lua` · `shared/Training.lua` · `shared/data/TrainingData.lua` · `shared/Loot.lua` · `shared/GemCraft.lua` · `shared/data/GemData.lua`(dust 절) · `server/GemServer.server.lua` · `server/GemCraftRequest.lua` · `server/QuestService.lua` · `shared/Quest.lua` · `server/CodexService.lua` · `server/CommunityGoalService.lua` · `server/WeeklyChallengeService.lua` · `server/SeasonPassService.lua` · `shared/data/SeasonPassData.lua` · `server/MonetizationService.lua` · `server/ProtectionTickets.lua` · `server/CombatResolution.lua`(처치 · 보스 · 상자 보상) · `server/ItemDropServer.server.lua` · `server/InventoryServer.server.lua` · `server/SaveSystem.lua` v68 이관 · `shared/Inherit.lua` · `server/ItemInherit.lua` · `shared/Awaken.lua` · `shared/data/BossFirstClearGoldData.lua` · `shared/data/ComebackData.lua` · 하네스 `economy_all9b_test.luau` · `enhance_g_test.luau` · `bignum_test.luau` · 문서 `econ-baseline-pre-all10.md` · `gold-budget-g3.md` · `QUEUE-ALL9C-report.md` 8절.

## 1. 즉시 확인(치명)

**치명 0건.** 골드 · 아이템 복사나 무한 골드로 이어지는 경로는 찾지 못했다. 확인한 근거:

- 골드 증감은 전부 `PlayerProfile.lua:334 changeGold` 한 함수로 모인다(addGold · takeGold · trySpendGold · 판매 5곳 `:1234 · :1865 · :2283 · :2329 · :2369`). 이 함수를 우회해 `profile.gold`를 직접 쓰는 곳은 DevTools 복원(`:2835` - Studio 전용)과 이관(`SaveSystem.lua:1413`)뿐이다.
- `trySpendGold`(`:375`)가 NaN · inf · 음수 · 숫자 아님을 거절하고, 비용 계산 `GoldCost.cost`(`GoldCost.lua:24`)는 비정상 값을 `math.huge`로 바꿔 항상 거절 쪽으로 보낸다.
- 받은 표시를 지급보다 **먼저** 하는 곳: 퀘스트(`Quest.lua:148-240` → `QuestService.lua:295-299`) · 합동 목표(`CommunityGoalService.lua:183-189`) · 주간 도전(`WeeklyChallengeService.lua:93-96`, `:182-186`) · 보스 첫 처치 골드(`ProtectionTickets.lua:76-80`). 지급 뒤에 표시하는 도감(`CodexService.lua:215-219`)과 시즌 패스(`SeasonPassService.lua:226-231`)는 사이에 yield가 없어서 같은 요청이 끼어들 수 없다(`CosmeticService.grant`에도 yield 없음).
- 강화(`EnhanceService.lua:62-155`)는 확인 · 차감 · 판정 · 반영 사이에 yield가 없고, 비용은 서버가 다시 계산한다. 클라가 보내는 값은 방지 토글 두 개뿐이며 `Enhance.resolveProtectionFlags`(`Enhance.lua:237`)가 다시 거른다.
- 장비 줍기(`ItemDropServer.server.lua:28-52`)는 서버 Heartbeat 한 곳에서 주인만 줍는다. `addArmorDrop` 경로에 yield가 없으므로 두 번 들어갈 수 없다(`CodexService.schedule`은 `task.delay`).
- 판매는 칸 확인값(`InventoryServer.server.lua:81-85` `Loot.itemSignature`)으로 막는다. 등급 일괄 판매는 개수 확인(`PlayerProfile.lua:2340`)으로 막는다. 예전 "기준 등급 이하" 판매는 닫혀 있다(`InventoryServer.server.lua:101-102`).

## 2. 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| 중간 | `server/PlayerProfile.lua:1232` · `shared/Loot.lua:404-407` · `shared/GemCraft.lua:100-106` | 계정 최고 스테이지가 장비의 `dropStage`보다 높은 계정(스테이지가 오른 뒤 가방에 남은 장비 · 낮은 스테이지에서 주운 장비)에서 영웅 이상 장비 하나를 고른다. ① 바로 판매하면 `Loot.getSellPrice`의 하한이 `GemCraft.sellPrice(…, item.dropStage)`라서 **주운 스테이지** 기준 값이 나온다. ② 분해한 뒤 보석을 팔면 `sellGem`이 `GemCraft.sellPrice(gem, getAccountBestStage)`를 써서 **계정 최고 스테이지** 기준 값이 나온다. 결과는 ② > ①이다. | QUEUE-ALL9B 1-3의 의도("바로 팔기가 늘 손해이던 역전을 없앤다" - `Loot.lua:402`)가 실제 플레이에서 다시 뒤집힌다. 하네스 `economy_all9b_test.luau:35-40`은 `stage == dropStage`인 경우만 재서 이 차이를 못 잡는다. | 보석 판매가의 스테이지를 계정이 아니라 보석 자체에서 읽는다. 예: `GemCraft.sellPrice(gem, gem.itemLevel)`(itemLevel ≈ 주운 스테이지 척도). 아니면 `Loot.getSellPrice` 하한에 계정 최고 스테이지를 넘기는 인자를 추가한다. 하네스 1-3에 "최고 스테이지 > 주운 스테이지" 경우를 넣는다. | 1 ~ 2시간 |
| 중간(확인 필요) | `shared/GemCraft.lua:100-106` · `server/PlayerProfile.lua:1220-1238` · `shared/data/GemData.lua:113-120` | 위와 같은 원인이다. 계정 최고 스테이지가 높은 계정(예: 20,000)이 낮은 스테이지(예: 1)로 내려가 영웅 이상을 모은 뒤 분해 → 보석 판매를 하면, 영웅 보석 1개(가루 `max(1, round(3 × 0.14)) = 1`)가 `1 × (40 ÷ 4) × 0.5 = 5`마리분 × **스테이지 20,000의** 처치당 골드가 된다. | 보석 판매만으로 "낮은 스테이지에서 빠르게 줍고 높은 스테이지 가격에 판다"는 차익이 생긴다. 무한 골드는 아니다(드랍률 · `DropTable.timeFairnessFactor` · 이동 시간에 묶인다). 정상 사냥보다 나은지는 EconSim으로 재야 한다. | 첫 줄과 같은 수정(보석 가격의 스테이지 = 보석 itemLevel)이면 같이 사라진다. 고치기 전에 EconSim에 "최고 20,000 · 사냥 1 · 분해 → 판매" 경로를 한 줄 넣어 시간당 골드를 정상 사냥과 비교한다. | 측정 1시간 + 수정은 첫 줄에 포함 |
| 중간(알려진 문제) | `server/PlayerProfile.lua:330-344` · `docs/design/econ-baseline-pre-all10.md` 3 · 4절 | 상위 1% 프로필은 1,113시간(스테이지 약 21,435)에 보유 골드가 2^53을 넘는다. 스테이지 25,300에서는 1.4e18이다(문서 3절). 이 상태에서 시즌 패스 무료 줄 3,600골드(`SeasonPassData.lua:92`)나 판매가처럼 ulp(1e18 근처 128 ~ 256)보다 작은 지급은 더해도 사라지거나 반올림된다. | 큰 보유 구간에서 작은 보상이 0이 된다. 차감도 최대 ulp/2만큼 어긋난다. 무한 골드나 음수는 아니다(`changeGold`가 0에서 자른다). `bignum_test.luau`의 KNOWN 4건으로 이미 알려져 있고 ALL10으로 넘어갔다. | ALL10 결정을 따른다(후반 골드 싱크 · 고정 보상의 스테이지 연동 · 단위 축소 중 하나). 그 전까지는 지금 안전망으로 충분하다. | 결정 뒤 별도 |
| 낮음 | `server/MonetizationService.lua:51-99` · `server/SeasonPassService.lua:226-231` | `applyReward`는 grant를 키 이름 순서로 하나씩 지급하다가 중간 grant가 실패하면 `false`를 돌려준다. 앞에서 이미 준 것은 되돌리지 않는다. 시즌 패스는 `false`면 받은 표시를 하지 않으므로, 실패하는 종류가 뒤에 있는 칸은 누를 때마다 앞의 골드 · 재료가 반복 지급된다. **지금 데이터로는 재현되지 않는다**(무료 줄 = egg · enhanceStone · gemDust · gold, 모두 성공. 알 가득은 루프 전에 거른다). | 잠재 복사다. 예를 들어 무료 줄에 폐지된 `protectDrop`이 다시 들어가면 정렬상 `gold` 뒤에 와서 `unknown_kind`로 실패한다. 그러면 칸마다 골드가 무한히 나온다. 이 이름은 `SeasonPassData.lua:121 growthKinds`에 아직 있다. | `applyReward`를 2단계로 바꾼다: ① 모든 grant를 먼저 검사(종류 · 판매 금지 · 지급 가능)하고 ② 하나라도 안 되면 아무것도 주지 않는다. 아니면 시즌 받기에서 표시를 먼저 하고, 실패하면 표시를 되돌린다. | 1시간 |
| 낮음 | `server/MonetizationService.lua:167-188` | 영수증을 처리하다 저장이 실패하면 `forgetReceipt`를 하고 NotProcessedYet을 돌려준다. 재시도가 다시 지급한다. 되돌리는 것은 조각 환산과 칸 건너뛰기뿐이다. | 지금 상품은 전부 멱등(치장 · 유료 줄 · 가방 출처 · 칸 건너뛰기 되돌림)이라 문제가 없다. 앞으로 조각 묶음이나 알 같은 더하기 상품을 넣으면 저장 실패 한 번마다 두 번 지급된다. | 더하기 종류 grant는 저장 실패 때 되돌리는 표를 일반화한다. 아니면 상품 검사(`Monetization.checkCatalog`)에서 더하기 종류를 막는다. | 1시간 |
| 낮음 | `server/EnhanceService.lua:112-115` | `PlayerProfile.trySpendGold(player, cost)`의 반환값을 버린다(재료도 같다). 바로 앞 `:103`에서 잔액을 확인했으므로 지금은 실패할 수 없다. | 나중에 `trySpendGold`에 새 거절 조건이 생기면(예: 비용 NaN 거절) 골드를 안 내고도 강화가 진행된다. | `if not PlayerProfile.trySpendGold(...) then return send(insufficient_gold) end`로 바꾼다. | 10분 |
| 낮음 | `server/PlayerProfile.lua:393-414` | `addMaterial` · `trySpendMaterial`은 골드의 `changeGold`와 달리 NaN · inf · 음수 검사가 없다. `trySpendMaterial(…, -n)`이면 재료가 늘어난다. 지금 호출부는 고정 데이터 · 운영 회수(`OpsServer.server.lua:198` - 의도된 음수)뿐이다. | 잘못된 데이터 한 줄로 재료가 NaN이 되거나 늘어날 수 있다. 저장은 `SaveSystem`의 NaN 복구가 막지만, 그 세션에서는 오염된 값이 그대로 쓰인다. | 골드와 같은 한 곳 함수(Sanitize · 0 하한)를 두고, `trySpendMaterial`은 `amount < 0`이면 거절한다. | 30분 |
| 낮음(확인 필요) | `server/PlayerProfile.lua:1234 · 1865 · 2283 · 2329 · 2369` | 판매 · 자동 판매 · 보석 판매는 `addGold`를 거치지 않고 `changeGold`를 바로 부른다. | `SuspicionMonitor.noteGold`(`:357` - 골드/분 · 큰 골드 감사)에 판매 골드가 잡히지 않는다. Telemetry에는 따로 남는다. 의도라면 문제없다. | 의도가 아니면 판매 경로도 같은 감사 함수를 부르게 한다. | 20분 |
| 낮음(확인 필요) | `shared/Loot.lua:418-438` | 자동 정리(`isAutoProcessTarget`)는 보스 · 토벌 출처 세트 장비를 뺀다. 등급 일괄 판매(`isBulkSellTarget`)는 빼지 않는다. 체크 등급에 영웅이 들어 있으면 보스 세트 영웅이 일괄 판매에 포함된다. | 두 판정이 서로 다르다. 플레이어가 세트 장비를 실수로 팔 수 있다. | 의도를 정한 뒤 공통 판정 하나로 모은다. | 30분 |
| 낮음 | `server/SaveSystem.lua:1392-1414`(v68 이관) | 손상된 저장에서 `protectionTickets.drop`이 아주 큰 수(예: 1e12)면 `count × 상점가`가 그대로 골드가 된다. 장수에 상한이 없다. `infiniteBest`가 NaN일 때 `math.max(1, NaN)`의 결과도 확인이 필요하다. | 이미 이관된 계정에는 영향이 없다. 옛 저장을 처음 불러올 때만 해당한다. | 장수를 합리적인 값(예: 지급 일정상 최대 139 + 구매분)으로 자르고 `best`에 `Sanitize`를 건다. | 20분 |
| 낮음(확인 필요) | `server/CombatResolution.lua:308-323` · `server/ProtectionTickets.lua:71-83` | 보스 첫 처치 골드는 **보스 스테이지** 표 값(`BossFirstClearGoldData`)이고 계정당 한 번이다. 파티 보스에서 기여 10%만 넘기면 받는 사람의 자기 스테이지와 상관없이 받는다(예: 10,080 = 1.4e8골드). | 낮은 계정이 캐리를 받으면 자기 수입의 수만 배를 한 번에 받는다. 계정당 한 번이고 파티 입장 밴드로 격차가 제한되므로 크지는 않을 것으로 본다. | 파티 입장 밴드 폭을 확인한다. 필요하면 지급액을 `min(표 값, 받는 사람 최고 스테이지의 표 값)`으로 제한한다. | 확인 30분 |
| 낮음 | `client/panels/CodexV2/Info.lua:217-221` · `server/CodexService.lua:215` | 도감 칸 보상 미리보기는 지금 계정 최고 스테이지로 골드를 계산한다. 서버는 칸이 완료된 순간의 스테이지(`r.done[id]`)로 지급한다. | 화면 숫자와 실제 지급이 다를 수 있다(주석은 "어림"이라고 적었다). | 서버 view에 `done` 스테이지를 같이 내려 클라가 그 값으로 계산하게 한다. | 30분 |

## 3. 설계와 어긋난 코드

현재 결정 대조:

| 결정 | 코드 | 판정 |
|---|---|---|
| +26부터 하락 없음 | `EnhanceConfig.lua:385-388`(down1 · down2 = 0) · `guardBands[3]`는 reset만(`:436`) | 일치 |
| 초기화 바닥 17 / 22 | `EnhanceConfig.lua:395-398` · `Enhance.getResultLevel`(`Enhance.lua:144-145`) | 일치 |
| 방지 옵션 = 비용 × k | `Enhance.getCost`(`Enhance.lua:40-58`) · 서버 `EnhanceService.lua:89-90` · 클라 `Enhance/Controller.lua:96-121`이 같은 함수 사용 | 일치 |
| 방지권 폐지 | `ProtectionTickets.tryBuy`가 `discontinued`를 반환(`:46-49`) · v68 환산 · 보스 지급은 골드 | 동작은 일치하지만 잔재가 많다(아래) |
| 수련 최대 50 | `TrainingData.lua:85-87` · v65 이관(`SaveSystem.lua:1360`) | 일치 |
| 판매 NPC 없음(가방에서 판매) | 판매 NPC 코드 · 데이터 grep 0건 · 판매는 `SellRequest`(가방)뿐 | 일치 |
| 시즌 패스 칸당 170 | `SeasonPassData.lua:110` | 일치 |
| 골드 증감 = changeGold 한 곳(2^53 안전망) | `PlayerProfile.lua:334-344` | 일치(1절 참고) |

폐지 결정과 어긋나는 잔재:

- 방지권 잔재
  - `PlayerProfile.lua:260-271`: 접속 때 `ProtectionDrop` · `ProtectionReset` Attribute를 계속 세운다. 클라에서 읽는 곳은 grep 0건이다.
  - `PlayerProfile.lua:416-439`: `addProtectionTicket` · `trySpendProtectionTicket`이 남아 있다.
  - `ProtectionTicketServer.server.lua`: 구매 · 가격 Remote가 살아 있다. 가격 요청에는 옛 상점가를 그대로 돌려준다.
  - `DevTools.server.lua:2578`: `/gg ticket add`가 폐지된 필드에 장수를 다시 넣을 수 있다. v68 이관이 끝난 뒤라 환산되지 않는다(Studio 전용).
- `protectDrop`이 아직 "성장 재화 종류" 목록에 있다: `SeasonPassData.lua:121` · `SeasonBoardData.lua:28` · `shared/Monetization.lua:172`. 지금은 무해하지만 2절 4번째 줄(잠재 복사)의 계기가 될 수 있다.
- 주석과 데이터가 어긋나는 곳
  - `TrainingData.lua:71`: "최대 공격 +5.6% · 체력 +5.6% · 방어 +3.75%"라고 적혀 있다. 실제 값(`:85-87`)은 +5% · +20% · +10%다.
  - `EnhanceMaterialData.lua:1` · `EnhanceService.lua:102`: "19 ~ 24강"이라고 적혀 있다. 실제로는 +29까지 재료가 든다(`:26-30`).
  - `PlayerProfile.lua:388`: "재료 증가 통로는 처치 보상뿐"이라고 적혀 있다. 실제로는 퀘스트 · 도감 · 시즌 패스도 `addMaterial`을 부른다.
  - `EnhanceService.lua:56-59` · `ProtectionTickets.lua:1-3` 머리 주석이 아직 "방지권 차감"을 설명한다.
- 문서: `docs/design/gold-budget-g3.md` 1절 표(수련 최대 100 · 0.0375% · 상한 ÷10 · 방지권 열)는 지금 `TrainingData`(50 · 0.1 / 0.4 / 0.2% · ÷20 · ×1.08)와 다르다. 현재 근거는 QUEUE-ALL9B 보고서 3절이다. 문서 앞에 "옛 값" 표시가 필요하다.
- 옛 기대값을 가진 검증 블록: `EnhanceVerify.lua:1375-1406`([17] 상점은 방지권 구매 성공을 기대한다) · `P25cVerify.lua:324-327`(방지권 지급). 둘 다 `DevToolsConfig.lua:42 exclude`로 회귀에서 빠져 있고, 로컬 하네스 `enhance_g_test.luau`가 대신 확인한다. 재작성이 필요한 상태다.

## 4. 단일 소스 위반 · 중복 구현

| 내용 | 위치 | 제안 |
|---|---|---|
| 옵션 변환권 가격 식(`GoldCost.cost(tier1 골드, 스테이지, "rerollTicket") × rerollTicketGoldMultiplier`)이 3곳에 따로 있다 | `server/GemServer.server.lua:74-77` · `client/panels/GemWorkshop/init.lua:80` · `client/panels/Shop/GoldTab.lua:24` | `GemCraft.ticketPrice(stage)` 하나로 모은다 |
| 보석 판매가와 장비 판매 하한이 서로 다른 스테이지 기준을 쓴다(2절 첫 줄) | `GemCraft.sellPrice` 호출부 2곳(`PlayerProfile.lua:1232` 계정 최고 · `Loot.lua:406` 주운 스테이지) | 한 기준으로 맞춘다 |
| 강화대 근접 판정이 2곳에 있다 | `EnhanceService.lua:41-44` · `ProtectionTickets.lua:21-24` | 공용 함수(예: `WorldConfig` 옆 Reach 함수) |
| 등급 순번 함수가 5벌이다 | `Loot.lua:365 gradeIndexOf` · `Loot.lua:446 indexOf`(같은 파일 안 중복) · `GemCraft.lua:17` · `Inherit.lua:20` · `PlayerProfile gradeIndex` | `ArmorData` 옆 공용 함수 하나 |
| 판매 · 분해 제외 규칙이 여러 벌이다 | `sellItem`(`PlayerProfile.lua:2265` - 잠금 · 초월) · `sellItemsBulkUpTo`(`:2299` - 자체 조건) · `Loot.isBulkSellTarget` · `isAutoProcessTarget` · `isBulkDismantleTarget` | 2절 "보스 세트 제외" 줄과 함께 공통 판정으로 정리한다 |
| 처치당 골드 × 몇 마리분 계산이 경로마다 다르다 | 도감 = `floor(kills × floor(6 × 배수))`(`CodexService.lua:44` · `CodexRules.reward`) · 퀘스트 = `floor(6 × kills × 배수)`(`GoldCost.rewardGold`) · 클라 도감 미리보기 = 같은 식 복사(`Info.lua:220`) | `GoldCost.rewardGold`로 모은다(반올림 차이 제거) |
| 고정 숫자로 굳힌 보상(공식이 바뀌어도 그대로) | `BossFirstClearGoldData.lua`(옛 방지권 장수 × 옛 상점가) · `SeasonPassData.lua:16-21, 37`(FREE_GOLD · PROTECT_GOLD) | 의도된 고정이다(주석에 명시). 공식을 바꿀 때 다시 만드는 절차를 문서 한 곳에 둔다 |

## 5. 출시 전 제거 대상

- `server/ProtectionTicketServer.server.lua`: 구매 · 가격 Remote(클라 사용 0). 공개된 Remote 표면만 늘린다. 남은 보스 지급 함수는 `ProtectionTickets.grantForBoss`가 맡는다.
- `server/ProtectionTickets.lua:46-70`: `if true then return … end` 뒤의 죽은 구매 본문.
- `EnhanceService.debugRolls`(`EnhanceService.lua:28, 120`): `RunService:IsStudio()`로 막혀 있어 출시 서버에는 영향이 없다. 남겨도 되지만 출시 점검 목록에 "Studio 전용"으로 적어 둔다.
- DevTools의 골드 · 방지권 명령: 스크립트 전체가 `IsStudio()`가 아니면 끝난다(`DevTools.server.lua:20-21`). 출시 영향은 없다.

## 6. 정리 후보(저장 필드 · 데이터 id · 에셋 · DataStore는 지우지 않는다)

- `PlayerProfile.sellItemsBulkUpTo`(`:2299-2333`): 호출부가 없다(`sellBulk` 동작이 닫힘 - `InventoryServer.server.lua:101`). 주석 참조(`ArmorData.lua:81, 85` · `InventoryServer.server.lua:67`)도 함께 고친다.
- `syncProtectionAttributes`(`PlayerProfile.lua:267-271`) · `addProtectionTicket` · `trySpendProtectionTicket`: 클라 사용 0. 저장 필드 `purchases.protectionTickets` · `protectionClaimedStages` · `protectionRefund`는 **유지**한다(`grantForBoss`가 `protectionClaimedStages`를 계속 쓴다).
- `ProtectionTickets` 모듈 이름 · `getPrices`: 남은 역할은 보스 첫 처치 골드뿐이다. 이름 정리 후보(id 아님).
- `growthKinds`의 `protectDrop` 항목 3곳: 검사 목록에서만 빼는 것이다. 아이템 id · 아이콘 · 문구(`ItemInfoData.lua:13` retired)는 유지한다.
- 오래된 주석 4곳(3절)과 `gold-budget-g3.md` 표 옆의 "옛 값" 표시.
- `EnhanceVerify` [17] · `P25cVerify` 방지권 블록: 지우지 말고 새 규칙(방지 옵션 · 보스 골드)으로 재작성한다. 지금은 exclude 상태다.
