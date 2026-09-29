# 수익화 설계 (P4c 골격 · QUEUE-B1 B2 · 2026-09-30)

> 코드: 자리값 = `roblox/src/shared/data/MonetizationData.lua`(가격 · 상품 ID · 게임패스 ID · 조각 가격 · 출처 - **이 파일 하나**) · 규칙 = `shared/Monetization.lua` · 서버 = `server/MonetizationService.lua`(구매 처리 · 게임패스 · 정책 · 창구) · `CosmeticService` · `SeasonPassService` · `GiftService` · 치장 목록 = `shared/data/CosmeticSlotData.lua` · 시즌 줄 = `shared/data/SeasonPassData.lua` · 저장 = SAVE v56 · 하네스 = `roblox/tools/harness/monetize_test.luau`(27/27).
> 원칙(사용자 규칙): **돈으로 강해지지 않는다.** 파는 것 = 치장 · 편의 · 시즌 유료 줄(치장 · 치장 재화)뿐. 골드로 치장을 못 산다. 유료 랜덤 없음(알 = 무료 줄만).

## 1. 판매 금지 목록(등록 때 강제)

| 금지 종류(kind) | 같은 뜻 별칭(게임 보상 키) | 막는 곳 |
|---|---|---|
| 골드 `gold` | `goldBoost` → 골드 배수 | 상품 · 시즌 유료 줄 · 선물 |
| 장비 `equipment` | `enhanceStone` · `item` | 〃 |
| 보석 `gem` | `gemDust` | 〃 |
| 랜덤 옵션 `randomOption` | `rerollTicket` | 〃 |
| 전투력 `combatPower` | - | 〃 |
| 강화 보호 `enhanceProtection` | `protectionTicket` | 〃 |
| 행운 부스트 `luckBoost` | - | 〃 |
| 경험치 배수 · 골드 배수 `expMultiplier` · `goldMultiplier` | `expBoost` · `rebirthTicket` | 〃 |
| 칭호 `title` | `titleId` | 〃 |

- 검사 = `Monetization.checkCatalog`(서버 시작 때 1회 · 걸린 상품은 판매 목록에서 빠지고 `[B2] 상품 등록 거부` 경고) · 허용 종류 = `allowedKinds`(cosmeticTheme · gliderSkin · seasonPremium · gamePass)만 - **모르는 종류도 거부**(새 종류는 목록과 검사에 같이 넣는다).
- 같은 productId 두 상품 · 없는 치장 id · 유료 랜덤인데 확률표 없음도 거부.
- 반짝 조각은 **로벅스로 팔지 않는다**(유료 재화를 두지 않음 - 결정 필요 1).

## 2. 상품표(자리값 - Creator Hub에서 만든 뒤 ID만 채운다)

| 코드 이름(key) | 종류 | 받는 것 | 표시 가격(로벅스 · 자리) | 조각 가격 |
|---|---|---|---|---|
| `theme_starlight` | 개발자 상품 | 테마 세트 "별빛"(4칸) | 199 | 120 |
| `theme_ember` | 개발자 상품 | 테마 세트 "불씨" | 199 | 120 |
| `theme_frost` | 개발자 상품 | 테마 세트 "서리꽃" | 199 | 120 |
| `glider_petal` | 개발자 상품 | 글라이더 "꽃잎" | 149 | 80 |
| `glider_kite` | 개발자 상품 | 글라이더 "연" | 149 | 80 |
| `season_premium` | 개발자 상품(시즌마다 다시) | 이번 시즌 유료 줄 | 399 | - |
| `bagExpand` | 게임패스 | 가방 +20칸 | 149 | - |
| `pickupRadius` | 게임패스 | 펫 자동 줍기 반경 ×1.5(해금 기준 그대로) | 99 | - |
| `recallCooldown` | 게임패스 | 마을 귀환 쿨 ×0.5 | 99 | - |
| `nameplateColor` | 게임패스 | 이름표 색 4종(UIColors 기존 색) | 49 | - |

- 외형 에셋(테마 4칸 · 글라이더 모양) = 자리("" = 기본 모습) → A(아트)가 채움. 클라 훅(`CosmeticSlotData.slots[].hook` 파일들)이 Player Attribute `Cosmetic_<칸>`을 읽게 연결하는 일도 A 영역(이번엔 연결 안 함).

## 3. 치장 세트 · 치장 재화

- 테마 1개 = 4칸(대시 트레일 · 점프 이펙트 · 활강 궤적 · 발자국) 해금 → **칸마다 산 세트 중 아무거나 섞어 장착**(`profile.cosmetics.equipped`). 글라이더 스킨 = 별도 칸.
- 반짝 조각 = `profile.quests.currencies.sparkleShard`(G3 퀘스트가 이미 쓰는 칸 · 지급 입구 `QuestService.grant` 하나).
- 조각 출처: 일일 · 주간 퀘스트 · 일일 상자 · 메인 퀘스트 · 7일 출석(기존) + **새 출처**(`MonetizationData.shardSources`): 나무 정거장 처음 오르기 2(정거장마다 1회 · 리프트 · 순간이동 도착 제외) · 비밀 둥지 도감 새 칸 1 · 칭호(업적) 새로 받음 3 · 시즌 무료 줄 2/칸.
- 쓰는 곳: 치장 구매(테마 120 · 글라이더 80)뿐.

## 4. NPC 상점 정리

| 탭 | 내용 | 재화 |
|---|---|---|
| 골드 | 방지권(하락 · 초기화) · 변환권(고대 · 태초) · [보석 도구] = 보석 공방 창 | 골드(+ 보석 가루) - 기존 Remote 그대로 |
| 치장 | 테마 3 · 글라이더 2 구매 · 칸별 장착 · 이름표 색(패스) | 반짝 조각 · 로벅스(골드 불가) |
| 편의 | 게임패스 4 | 로벅스 |
| 시즌 | 40칸 × 무료/유료 · 받기 · 유료 줄 열기 | passExp(퀘스트) · 로벅스 |
- 입구 = 보석상인 좌판의 두 번째 프롬프트 `ShopPrompt`(F · NPC 외형 그대로 - `HuntingGround.server.lua`). 창 = `client/panels/Shop/`.

## 5. 시즌 패스(8주)

- 시즌 번호 = 리더보드와 같은 시계(`LeaderboardConfig.seasonLengthDays` 28 → **56**). 시즌이 바뀌면 경험치 · 받은 칸 · 유료를 새로(유료 줄은 시즌마다 다시 산다).
- 경험치 = `quests.currencies.passExp`(일일 · 주간 미션 · 접속 · 일일 상자 - G3 퀘스트 공통 입구 재사용) · 칸당 250 · 40칸(하루 약 120 + 주 500 → 8주 약 10,700).
- 무료 줄: 조각 2 · 5칸마다 알 1(**알 = 랜덤 = 무료 줄만**) · 20칸 테마 "별빛" · 40칸 글라이더 "꽃잎". 유료 줄: 조각 4 · 10칸 글라이더 "연" · 30칸 테마 "불씨" · 40칸 테마 "서리꽃".
- 규칙 검사 = `Monetization.checkSeasonPass`(유료 줄 알 · 금지 종류 거부).

## 6. 선물함(우편함)

- 받을 선물 = `profile.mailbox.gifts` · 접속 때 수령 팝업(`GiftPopup`) · [모두 받기].
- 보내기 = 관리자 명령 `/ops gift <userId> <cosmeticTheme|gliderSkin|sparkleShard> <id|개수> [메모]`(허용 계정 = `server/OpsConfig.userIds` · 모든 시도가 운영 기록 저장소에 남는다). 대상이 이 서버에 없으면 DataStore `Gifts_v1`(검증 무장 = `_verify`)에 쌓았다가 다음 접속 때 옮긴다. **치장 · 치장 재화만**.
- 유저 간 로벅스 선물 = 자리(`gifts.userToUser.enabled = false`).

## 7. 구매 처리(ProcessReceipt)

1. 접속 · 로드 전 → `NotProcessedYet`(다음 접속 때 Roblox가 다시 부른다).
2. 구매 ID가 기록(`purchases.receipts` - 최근 200)에 있으면 → `PurchaseGranted`(다시 안 줌).
3. 판매 목록 밖 · 모르는 상품 · 유료 랜덤 제한 → `NotProcessedYet` + 기록 줄.
4. 구매 ID 기록 → 지급(치장 소유 · 유료 줄 켜기 = **멱등**) → **즉시 저장 성공 확인 뒤** `PurchaseGranted`.
5. 지급 · 저장 실패 → 구매 ID 기록을 빼고 `NotProcessedYet` → 재시도 때 다시 지급(멱등이라 같은 결과).
- 구매 기록 = `purchases.log`(최근 100줄 - 시각 · 상품 · 구매 ID · 로벅스 · 결과) · 통계 = `Telemetry.custom("Purchase_<key>")`.
- 게임패스: 접속 때 `UserOwnsGamePassAsync`로 `profile.gamepasses` 캐시 갱신(조회 실패면 캐시 유지) · `PromptGamePassPurchaseFinished`로 즉시 반영 · 효과 = `InventorySync.capacity` · `PetService.pickupRange` · `Travel.recallCooldownSeconds` · Attribute `NameplateColor`.

## 8. 정책 점검표(PolicyService)

| 항목 | 지금 | 점검 |
|---|---|---|
| 유료 랜덤(ArePaidRandomItemsRestricted) | 유료 랜덤 상품 0개(알 = 무료 줄만) | 접속 때 캐시 · 조회 실패 = 제한(failClosed) · paidRandom 상품은 제한 대상에게 프롬프트 자체를 막고 영수증도 지급 안 함 · 넣으려면 odds(확률표) 필수 · 창에서 구매 전 표시 |
| 전 상품 점검 | 6 상품 + 4 패스 = 전부 확정 결과(랜덤 없음) | `checkCatalog` 서버 시작 로그 |
| 강화 유료 재료 | 기존 `EnhancePolicy`(강화 유료 입력 = 제한 시 막힘 - 지금 유료 입력 없음) | 변경 없음 |
| 광고 · 외부 링크 · 소셜 | 없음 | - |

## 9. 사용자가 Creator Hub에서 만들 것(체크리스트)

- [ ] 개발자 상품 6개 만들기 → 번호를 `MonetizationData.products.<key>.productId`에: `theme_starlight` · `theme_ember` · `theme_frost` · `glider_petal` · `glider_kite` · `season_premium`(가격은 Creator Hub가 진실 - 파일의 `robux`는 표시용이니 같게 맞춘다)
- [ ] 게임패스 4개 만들기 → 번호를 `MonetizationData.gamePasses.<key>.passId`에: `bagExpand` · `pickupRadius` · `recallCooldown` · `nameplateColor`
- [ ] 각 상품 · 패스 아이콘(512 × 512) 업로드 - 아트 A와 함께
- [ ] 경험(Experience) 설정: "API 서비스 사용"(DataStore - 이미 켜져 있음) · 경험 질문지(유료 랜덤 없음으로 답)
- [ ] 테스트: Studio에서 개발자 상품 구매는 가짜 구매(무료)로 돈다 → 다음 Play 목록의 구매 · 재접속 · 중복 확인
- [ ] 번호를 넣은 뒤 서버 시작 로그에 `[B2] 상품 등록 거부` 줄이 없는지 확인

## 10. 결정(2026-09-30 사용자 - 전부 추천대로 · QUEUE-B1 후속)

- 반짝 조각은 상품으로 직접 팔지 않음 · 시즌 유료 줄 조각 유지 · 게임패스 수치 · 가격 = 자리값 유지 · 기존 passExp 0 출발 · 상점 입구는 NPC 외형 결정 때 전용 상인으로.
- **이미 가진 것 영수증**(클라가 직접 연 구매 창) · **지난 시즌에 연 유료 줄 영수증** = 반짝 조각 환산(`MonetizationData.ownedRefundShards` - 테마 120 · 글라이더 80 · 유료 줄 120 · 자리값). 조각 환산은 더하기라 저장 실패 때 되돌리고 재시도한다. 유료 줄 구매 창을 열 때 시즌을 `seasonPass.promptSeason`에 적는다(v56 표 안 선택 칸 - 이관 불필요).
- 창구 결과 = `ShopResult`(action, ok, why) · 알 수 없는 상품 영수증은 구매 기록에 한 줄만(재시도마다 안 쌓임 - 환불은 운영이 기록을 보고) · 손상된 v56 칸 = 로드는 막지 않고 안쪽 표까지 복구 · DevTools 복원 뒤 치장 · 패스 Attribute 다시 · 나무 정거장 조각 = 바로 아래 정거장(첫 칸 = 바닥)에서 올라온 경우만.
- **시즌 1 시작일** = `LeaderboardConfig.firstSeasonDateKst`(자리 · 비면 서버 시작 경고) · 출시 체크리스트(`docs/phase/roadmap-v2.md` P6)에 "시즌 1 시작일 확정(추천: 오픈일, 8주)".

## 10-1. 옛 결정 필요(기록 - 위에서 닫힘)

1. 반짝 조각을 로벅스로 팔지(추천: 안 판다 - 유료 재화가 생기면 가격 비교 · 환불 · 정책이 복잡해진다. 지금은 치장을 직접 판다).
2. 시즌 유료 줄에 조각 4/칸(총 약 144)을 넣는 것 = 유료로 치장 재화를 얻는 길(추천: 유지 - 치장만 사는 재화라 전투력과 무관).
3. 게임패스 효과 수치(가방 +20 · 반경 ×1.5 · 귀환 ×0.5 · 가격) - 자리값.
4. 기존 계정의 쌓인 passExp는 시즌 패스 첫 적용 때 0으로 시작(시즌 0 → 지금 시즌 넘김) - 추천: 유지(모두 같은 출발선).
