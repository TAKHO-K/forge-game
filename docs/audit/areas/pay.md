# 감사: 결제 · 영수증 · 게임패스 · 선물 · 치장 (area-pay)

읽은 범위: `roblox/src/server/MonetizationService.lua`(전체) · `shared/Monetization.lua`(전체) · `shared/data/MonetizationData.lua`(전체) · `server/GiftService.lua`(전체) · `server/SeasonPassService.lua`(전체) · `shared/data/SeasonPassData.lua`(전체) · `server/CosmeticService.lua`(전체) · `server/SocialRewardService.lua`(전체) · `server/ImmediateSave.lua` · `server/SaveCoordinator.lua:60-147` · `server/InventorySync.lua:38-53` · `server/PlayerProfile.lua:780-786, 2660-2685` · `server/OpsServer.server.lua:40, 468-475` · `server/DevTools.server.lua:20, 1366-1372, 3205-3213` · `client/panels/Shop/init.lua`(탭 · Remote · ExperienceShop 부분) · `Shop/Catalog.lua:106-117, 315-330` · `Shop/SeasonTab.lua:246-251` · 하네스 `monetize_test.luau:95-116` 외 check 목록 · `season_pass_test.luau` check 목록.
전체 `roblox/src` grep: `ProcessReceipt` 대입은 `MonetizationService.lua:510` 한 곳 · `UserOwnsGamePassAsync` 두 곳(240 · 518) · `PromptProductPurchase`/`PromptGamePassPurchase`는 서버 한 곳씩(407 · 424) · 클라는 `ShopRequest`로 키 문자열만 보낸다(`Shop/init.lua:201`).

---

## (1) 즉시 확인(치명)

**치명 등급은 없음.** 다만 실제 로벅스가 걸린 이중 지급 1건(B-1, 높음)은 출시 전에 고치는 것을 권한다.

### B-1 영수증 저장 실패 → 재시도 때 "이미 가짐 → 토큰 환산"이 겹쳐 이중 지급
- 위치: `server/MonetizationService.lua:138`(기록) · `:152-158`(ownsAll이면 토큰 환산) · `:163`(지급) · `:176-192`(저장 실패 때 `forgetReceipt` + 칸 건너뛰기 · 환산 토큰만 되돌림)
- 원인: 저장 실패 경로는 "치장 · 유료 줄 · 가방 출처 지급은 멱등이라 남겨 둬도 된다"(주석 `:177`)는 전제로 **지급은 메모리에 남기고 영수증 기록만 뺀다**. 그런데 재시도 때 `:152`의 `ownsAll`이 그 남은 지급을 "이미 가짐"으로 보고 **토큰 환산(`sparkleShard`) 경로로 바꾼다**. 따라서 같은 PurchaseId 하나로 치장 + 토큰이 둘 다 나간다.
- 재현(하네스로 재현 가능 · 기존 `monetize_test.luau:106-112`는 이미 가진 테마로 P-2를 시험해서 이 경우를 못 잡음):
  1. 안 가진 상품(예: `theme_jelly`, 또는 `starter_pack` · `season_premium`)의 영수증을 `deps.save = false`로 처리 → `NotProcessedYet`, `cosmetics.themes.jelly == true`가 메모리에 남고 영수증 기록 없음.
  2. (실제 서버에서는 이후 주기 저장 · 퇴장 저장이 치장만 영구 저장)
  3. 같은 PurchaseId로 `deps.save = true` 재호출 → `ownsAll = true` → `reward = { sparkleShard = tokenPrice(199) = 280 }` 지급 → `PurchaseGranted`.
  4. 결과: 테마 + 토큰 280. `starter_pack`이면 가방 +20 · 외형 2종 + 280, `season_premium`이면 유료 줄 + 560.
- 실제 발생 조건: `SaveCoordinator.saveForPlayer`가 false를 돌려주는 모든 경우(`SaveCoordinator.lua:93-117` - DataStore 일시 오류 · 한도 초과 · 이동 동결 뒤 해제 등) 다음에 같은 세션 안에서 저장이 한 번이라도 성공하는 경우. 동시 구매 두 건 중 하나만 저장 실패해도 다른 건의 저장이 앞 건의 지급을 영구 저장한다.
- 고치는 방법(제안): 영수증 기록과 지급은 같은 프로필 문서라 함께 저장된다. 그래서 **저장 실패 때 기록을 빼지 말고**(`:178` · `:179-190` 되돌림 제거), 메모리 표 `unsavedReceipts[purchaseId] = true`만 둔다. `:115`의 `hasReceipt` 분기에서 `unsavedReceipts`에 있으면 `ImmediateSave.flush`를 다시 부르고 성공했을 때만 `PurchaseGranted`, 실패면 `NotProcessedYet`을 돌려준다. 서버가 죽으면 기록과 지급이 함께 사라지므로 다음 재시도가 처음부터 다시 지급한다. 하네스에 "안 가진 상품 → 저장 실패 → 재시도 → 토큰 그대로" 경우를 추가한다.
- 예상 시간: 1.5 ~ 2시간(하네스 포함)

---

## (2) 버그 표

| 심각도 | 파일:줄 | 재현 | 영향 | 고치는 방법 | 예상 시간 |
|---|---|---|---|---|---|
| 높음 | `server/MonetizationService.lua:152-158, 176-192` | (1)절 B-1 참고: 안 가진 상품 영수증이 저장에 실패한 뒤 재시도됨 | 같은 구매로 치장(또는 유료 줄 · 가방 칸)과 토큰 환산이 둘 다 지급됨 | 저장 실패 때 기록을 남기고 `unsavedReceipts`로 재저장을 시도한 뒤에 Granted 반환 | 1.5 ~ 2시간 |
| 높음(공개 전 필수 · 지금은 잠복) | `shared/data/MonetizationData.lua:96` · `server/CosmeticService.lua:96-97, 166, 173` · `server/MonetizationService.lua:523` | `nameplateSet` 패스를 사면 `gamepasses.nameplateSet = true`만 기록됨. `includes`를 펼치는 서버 코드가 없다(grep `includes` = 데이터 · 클라 표시만). 장착 · Attribute는 `gamepasses.nameplateColor` · `nameplateBadge`만 확인 | 79R$를 내도 색 · 배지 장착이 `no_pass`로 거부됨. 지금은 공개 단계 2 · passId 0이라 살 수 없음 | `hasPass`(또는 CosmeticService 확인 두 곳 · `applyAttributes`)가 `includes`를 펼쳐 보게 함. 예: `hasPass(p,"nameplateColor") or 그 키를 includes하는 패스 보유` | 30분 |
| 중간 | `server/InventorySync.lua:51-52` · `server/PlayerProfile.lua:784` · `shared/data/MilestoneData.lua:20` | 마일스톤 가방 +5(inventorySlots 25)를 가진 계정이 가방 패스와 스타터를 둘 다 산 경우: 25 + 15 + 20 + 20 = 80 → 상한 75로 잘림 | 유료로 산 +20 중 5칸이 안 들어옴(돈 낸 만큼 못 받음). 고레벨 계정에만 해당 | 상한을 "기본 + 마일스톤 + 유료" 기준으로 다시 정하거나(`bagMaxSlots`를 마일스톤만큼 올림) 유료 출처는 상한에서 뺌. 결정 필요 | 30분 + 결정 |
| 중간(확인 필요) | `shared/data/SeasonPassData.lua:93-100, 119` · `server/SeasonPassService.lua:102-110, 222-225` | 칸 건너뛰기 20칸 구매 → 40칸에 일찍 닿음 → 그 뒤 자연 경험치가 반복 보너스 칸(무료 = 골드 3,600 + 토큰 1, 시즌당 20회)으로 감. `skipTiers`는 40칸까지만 표시되므로 보너스 칸 골드는 토큰으로 바뀌지 않음 | 매일 접속하지 않는 유저(주 4일 = 42일째 40칸)는 구매자만 시즌 안에 보너스 골드(최대 72,000)를 더 받음. "건너뛰기로 성장 재화를 얻는 길 차단"(보완 6-2)이 우회됨 | 건너뛴 칸 수만큼 보너스 칸도 `skippedFreeReward`로 바꾸거나(시즌별 `skipBought`만큼 앞 보너스 칸을 토큰화), 설계에서 허용으로 확정 | 1시간 + 결정 |
| 낮음 | `server/SeasonPassService.lua:111, 130, 143-148` · `server/MonetizationService.lua:170-180` | 칸 건너뛰기 영수증 A · B가 연달아 옴: A 저장 대기 중 B의 `applySkip`이 `lastSkipMarked[player]`를 덮음 → A 저장 실패 → `revertSkip`이 B가 표시한 칸을 지움 | 건너뛴 칸 표시가 실제와 한 칸 어긋남. 그 칸의 무료 줄 성장 재화가 토큰 대신 그대로 지급될 수 있음. 금액은 작음 | `lastSkipMarked`를 플레이어가 아니라 PurchaseId 키로 저장(B-1을 고치면 되돌림 자체가 없어져 함께 해결) | B-1에 포함 |
| 낮음 | `server/GiftService.lua:181-186` · `server/MonetizationService.lua:66-70` | 이미 가진 치장을 선물로 받음 → `CosmeticService.grant`가 `owned` → `applyReward`가 성공으로 보고 선물이 사라짐 | 선물 가치 손실(운영 · 초대 선물). 치장 선물은 운영자만 보낼 수 있음 | 선물 받기에서 owned면 토큰 환산(영수증과 같은 식) 또는 선물함에 남김 | 20분 |
| 낮음 | `server/GiftService.lua:90-93` | 온라인 대상에게 보낼 때 `ImmediateSave.flush` 결과를 무시하고 `delivered_online`을 돌려줌 | 저장 실패 뒤 서버가 죽으면 운영자에게는 "전달됨"으로 보이지만 선물이 사라짐(주석 의도와 반대) | flush 실패면 결과 문자열에 표시하거나 DataStore 대기열에도 넣음(id 중복은 claimedIds가 거름) | 15분 |
| 낮음(확인 필요) | `server/MonetizationService.lua:130-137` | 등록 거부 · 정책 제한 상품의 영수증 → 매번 `NotProcessedYet` | 영구 미지급(Roblox 쪽 자동 환불 정책이 있는지 확인 필요). 정상 클라는 프롬프트를 못 열고 변조 클라만 해당 | 운영 기록(`purchases.log`)으로 수동 환불 · 현 상태 유지 가능 | - |

확인했고 문제 없음: 프로필 로드 전 · 퇴장 = `NotProcessedYet`(`:106-110`) · 같은 PurchaseId 동시 호출 = `inFlight`(`:112`) · 토큰 구매는 차감과 지급 사이에 yield 없음(`:347-361`) · 게임패스는 접속 때 다시 확인(`:237-246`, 소유 아님이면 캐시를 지워 환불 · 회수 반영) · 구매 완료 신호도 소유 조회로 확인(`:516-522`) · 선물은 `claimedIds`로 중복 수령을 막음(`GiftService.lua:57-69, 127-142, 176-190`) · 코드는 계정 프로필 `redeemedCodes`로 계정당 1회(`SocialRewardService.lua:69-81`) · 시즌 칸 NaN · inf = `bad_tier`/`bonus_cap`(`Monetization.lua:489-494`) · DevTools 패스 지급은 Studio 전용(`DevTools.server.lua:20`) · 운영 선물은 `OpsConfig.userIds`만(`OpsServer.server.lua:40`).

---

## (3) 설계와 어긋난 코드

| 결정 | 코드 상태 | 근거 |
|---|---|---|
| 로벅스로 전투력 판매 금지(forbiddenKinds) | 상품 · 토큰 구매 · 유료 줄 · 환산은 모두 `checkGrant`를 거침(`MonetizationService.lua:52-64`). 상품 grant 종류는 치장 · 유료 줄 · 칸 건너뛰기 · 가방 칸뿐 | 지켜짐. 다만 칸 건너뛰기 → 반복 보너스 골드 경로는 (2)의 중간(확인 필요) 항목 참고 |
| 유료 랜덤 없음 | `paidRandom` 상품 0개 · 유료 줄 알 거부(`Monetization.lua:179-180`) · 건너뛴 칸 알 → 토큰(`:280-281`) | 지켜짐 |
| 방지권 폐지 | 구매 Remote 없음(grep 0) · `forbiddenAliases.protectionTicket` 유지(`MonetizationData.lua:13`). 그러나 **시즌 무료 줄 허용 종류에 `protectDrop`이 남아 있음**(`Monetization.lua:172`, `SeasonPassData.lua:121`). 누가 무료 줄에 `protectDrop`을 넣으면 등록 검사는 통과하지만 `applyReward`는 `unknown_kind`로 받기를 막음(`MonetizationService.lua:95-96`) | 낮음 · 검사 표에서 `protectDrop`을 빼서 데이터 단계에서 거부하게 함(`growthKinds`는 건너뛰기 변환용이라 남겨도 됨) |
| 출석 로벅스 구매 없음 | 상품 · 패스 목록에 출석 관련 없음(`MonetizationData.lua:21-52, 89-97`) · 출석판 치장은 `boardOnly`로 상품 · 토큰 · 선물 차단(`Monetization.lua:117`) | 지켜짐 |
| 상점 탭 추천 · 치장 · 시즌 패스 · 편의 | `TABS = { "recommend", "cosmetic", "season", "convenience", "gold" }` · gold는 보석상인 좌판에서 열 때만(`Shop/init.lua:39, 100`) | 지켜짐 |
| 시즌 패스 칸당 170 · 무료 줄 = 성장 재화 | `expPerTier = 170`(`SeasonPassData.lua:110`) · 무료 줄 골드 · 강화석 · 보석 가루(`:49-65`) | 지켜짐 |
| 공식 Shop 버튼 끔 | `SetCoreGuiEnabled(Enum.CoreGuiType.ExperienceShop, false)`(`Shop/init.lua:680-682`, ShopClient 시작 때) | 지켜짐(pcall이라 실패해도 조용함 - Studio 확인 기록 `docs/phase/all9c/block1.md:116`) |
| 가방 최대 75(기본 35 + 패스 20 + 스타터 20) | 상한은 75로 맞음. 마일스톤 +5와 겹치면 유료 칸이 잘림 | (2) 중간 항목 |
| 스타터 팩 계정당 1회 | 구성품이 `bagSources.starter` + `starterOnly` 치장 2종이라 `ownsAll`로 재구매 프롬프트가 `owned`로 거부됨(`MonetizationService.lua:398-400`). 영수증이 그래도 오면 토큰 환산 | 지켜짐(B-1이 고쳐지기 전까지 저장 실패 재시도 때만 예외) |
| 설계 문서 | `docs/design/monetization-p4c.md:52`는 골드 탭에 "방지권(하락 · 초기화)"를, `:45`는 "시즌 무료 줄 2/칸(조각)"을 적고 있음. 코드(방지권 폐지 · 무료 줄 = 성장 재화)와 다름 | 문서 갱신 필요(코드 문제 아님) |

---

## (4) 단일 소스 위반 · 중복 구현

| 항목 | 위치 | 내용 | 제안 |
|---|---|---|---|
| 가격 두 원천 | `MonetizationData.lua:19`("실제 가격은 Creator Hub 값이 우선") · `client/ui/PriceCache.lua:1, 25`(지역 가격 조회) vs `Monetization.tokenPriceForRobux`(`MonetizationData.lua:122-128`) · 환산 `MonetizationService.lua:153` | 화면 가격은 Creator Hub 값, 토큰가 · 영수증 환산 · 묶음 검사 · 패스 가치는 데이터 `robux` 값. Creator Hub 가격을 바꾸면 토큰가와 환산이 어긋남 | 출시 전 Creator Hub 가격을 데이터와 같게 맞추는 것을 점검 목록에 넣거나, 서버 시작 때 `GetProductInfo`로 비교해 경고 |
| 시즌 패스 가격 하드코딩 | `client/panels/Shop/SeasonTab.lua:251` `full and full.robux or 399` | 기본값 399가 데이터 밖에 있음 | `MonetizationData.products.season_premium.robux`로 대체 |
| 499급 문구 | `shared/data/TextData.lua:187-188`("다음 499급 치장까지") · `client/panels/Codex.lua:9` | 499가 문구에 고정. `tokenPricing.premiumRobux`를 바꾸면 문구만 남음 | 문구에 `{robux}` 자리를 두고 데이터 값을 넣음(낮음) |
| 치장 종류 판정 3중 | `MonetizationService.ownsAll`(`:310-313`) · `CosmeticService.ownedBag`(`:73-83`) · `Monetization.productCosmetic`/`COMPONENT_PREFIX`(`Monetization.lua:85-91, 353`) · `CosmeticService.PRODUCT_PREFIX`(`:122`) | 같은 종류 → 저장 칸 · 상품 접두사 표가 여러 곳 | 새 치장 종류를 추가할 때 빠뜨리기 쉬움. 한 표로 모으는 것은 정리 후보 |
| 패스 `includes` 의미 | 데이터(`MonetizationData.lua:96`)와 클라 표시(`Shop/Catalog.lua:111`)만 앎 · 서버는 모름 | (2) 높음 항목과 같음 |

---

## (5) 출시 전 제거 · 설정 필요

**productId 0(개발자 상품 23개 전부)** - `shared/data/MonetizationData.lua:23-51`
- 공개 단계 1(출시 때 필수 15개): `starter_pack`(199) · `season_premium`(399) · `season_premium_sale`(299, `saleActive=false`라 당장은 안 씀) · `pass_skip1`(25) · `pass_skip5`(99) · `theme_anvil`(199) · `theme_jelly`(199) · `theme_halloween`(199, 10월만) · `glider_dragonWing`(149) · `glider_slimeParachute`(149) · `item_rocketPop`(99) · `item_balloonPop`(99) · `item_crystalBlade`(149) · `item_highFive`(49) · `item_petCrown`(49)
- 공개 단계 2(나중 8개): `theme_starlight` · `theme_ember` · `theme_frost` · `glider_petal` · `glider_kite` · `item_goldenHammer` · `item_forgeBrazier` · `bundle_blacksmith`

**passId 0(게임패스 6개 전부)** - `MonetizationData.lua:90-96`
- 공개 단계 1: `bagExpand`(149) · `pickupRadius`(79) · `recallCooldown`(49) · `nameplateColor`(49) · `nameplateBadge`(49)
- 공개 단계 2: `nameplateSet`(79) - **(2) 높음 항목을 고치기 전에는 공개 금지**

**그 밖의 출시 설정**
- 시즌 시작일 미정: `shared/data/LeaderboardConfig.lua:16, 22`(`seasonStartUnix = 0` · `firstSeasonDateKst = nil`) → 시즌 번호가 고정되어 시즌 패스가 안 넘어감(서버 경고 `MonetizationService.lua:491-493`).
- NEW 띠 기준일 자리값: `MonetizationData.lua:68` `releaseStageStartUtc = { [1] = 1790985600 }`(2026-10-03 자리) → 실제 출시일로.
- 묶음 제안 가격: `bundle_blacksmith` 499 ≥ 구성품 합계 447(199 + 149 + 99)이라 등록 검사가 경고만 함(`Monetization.lua:320-326`, `proposal = true`). 공개 전 가격 · 구성 결정 필요.
- 상품 ID를 채우면 `checkCatalog`가 ID 중복을 거름(`Monetization.lua:313-318`). 다만 패스 ID 중복 검사는 없음(`passKeyById`가 첫 일치만 반환 - `Monetization.lua:420-430`) → 채울 때 수동 확인.
- Creator Hub 실제 가격을 데이터 `robux`와 맞추기((4) 첫 항목).

---

## (6) 정리 후보(저장 필드 · 데이터 id · 에셋 · DataStore는 지우지 않음)

- `MonetizationData.ownedRefundShards`(`MonetizationData.lua:128`): 저장소 밖 코드에서 읽는 곳이 없음(grep - 정의만). 표시 · 호환용 상수라면 주석에 "읽는 곳 없음"을 남기거나 정리.
- `view().shardPrices`(`MonetizationService.lua:267`): 클라 Shop에서 읽는 곳이 없음(grep `shardPrices` = 서버 · 하네스 · 주석만). 매 ShopSync마다 보내는 값 정리 후보.
- `Monetization.FREE_ROW_KINDS`의 `protectDrop`(`Monetization.lua:172`): 방지권 폐지 뒤 허용 검사에 남은 값((3) 참고). id(`ItemInfoData` `retired`)는 그대로 둠.
- `CosmeticService.lua:1` 머리 주석 "가격 = MonetizationData.shardPrices" · `CosmeticSlotData.lua:36` 같은 주석: 지금 가격은 `productTokenPrice`(상품 robux 비례). 주석 갱신 후보.
- `docs/design/monetization-p4c.md:45, 52`의 옛 서술(방지권 · 무료 줄 조각) 갱신.
