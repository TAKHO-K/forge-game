# 출시 체크리스트 (QUEUE-ALL4 블록 F · 2026-10-01)

> 대상 = 로블록스 경험(roblox/). 코드 값은 2026-10-01 master(`5311fd9`) 기준 파일:줄. 문서만 썼다 - 코드 · 설정은 하나도 안 바꿨다.
> **★ 사용자 결정** 표시 칸은 이 문서가 값을 정하지 않는다(맨 끝 6절에 모아 둠).
> Creator Hub 메뉴 이름은 2026년 화면 기준으로 적었지만 로블록스가 자주 바꾼다. 이름이 다르면 같은 뜻의 항목을 찾는다.
> 연관 문서: `docs/design/monetization-p4c.md` §9(수익화 체크리스트) · `docs/phase/roadmap-v2.md` P6 · `docs/phase/QUEUE-ALL2-report.md` 6절(출시 준비물).

## 0. 사용자가 Creator Hub에서 할 일 - 순서 (QUEUE-STUDIO 갱신 2026-10-01)

| 순서 | 할 일 | 어디(이 문서) | 메모 |
|---|---|---|---|
| 1 | **시즌 1 시작일 = 오픈일**(QUEUE-ALL6 A5 사용자 결정) → 오픈일이 정해지면 `roblox/src/shared/data/LeaderboardConfig.lua`의 `firstSeasonDateKst = nil` 한 줄을 `firstSeasonDateKst = { 년, 월, 일 }`(한국 날짜)로 바꿔 커밋 | 2-1 | 자리값 그대로면 시즌 · 시즌 패스가 안 넘어감(서버 시작 경고) |
| 2 | 개발자 상품 8 · 게임패스 5 만들기 → id를 `MonetizationData`에 채워 커밋 | 1-1 ~ 1-3 | 아이콘 = `docs/release/icons/<키>.png`(이름표 색 · 배지는 QUEUE-STUDIO에서 다시 그림 - 한눈에 구분) |
| 3 | 경험 아이콘 1장 올리기 = **D안 확정**(QUEUE-ALL6 A5) | 2-2 | 올릴 파일 = `docs/release/icons/game_icon_blender_D.png`(Blender판) - 게임 안 촬영판 `game_icon_capture_D.png`는 예비(A · B · C는 비교용) |
| 4 | 썸네일 올리기(순서 = A 초월 → C 허브 → B 도감) | 2-2 | QUEUE-STUDIO 재촬영 = `Claude outputs/QUEUE-STUDIO/launch/thumb_*_{plain,text}.png`(개발 계정 이름 없음) |
| 5 | 서버 크기 Max 16 · 정원 12 | 2-4 | 로그 `플랫폼 MaxPlayers=16 PreferredPlayers=12` 확인 |
| 6 | 질문지 · 공개 범위 · 오디오 권한 | 2-3 · 2-5 · 2-7 | |
| 7 | Studio `Workspace.PlayerCharacterDestroyBehavior` 값 확인(속성 창 - 스크립트로는 못 읽음) | 3절 아래 메모 | `Enabled`가 아니면 바꾸고 퍼블리시(리스폰마다 캐릭터별 연결이 쌓이는 것 방지) ★ |
| 8 | 퍼블리시 직전: ReplicatedStorage · Workspace Attribute에 시험 값이 없는지(`VerifyArmedUntil` · `VerifyOnly` · `ArtStyleV1Force` · `TextLanguageDev` · `RiftForce` · `StudioFreshProfile`) | 3절 | QUEUE-STUDIO 끝에 Studio에서 전부 nil 확인함 |
| 9 | 아트 켬 확인 = 라이브 접속 콘솔 `[forge-game] 카툰 스타일 artV1` | 4절 5 | Studio 확인: 기본 = artV1(B-1 O) · 비상 끔 `ArtStyleV1Force = false` → `base`(B-2 O) |
| 10 | 좋아요 목표 단계(QUEUE-ALL6 A5): **1단계 1,000** = `LIKES1K`(입력 가능 · 숨김) → 넘기면 `hidden` 지우고 업데이트 · 2단계 5,000 `LIKES5K` · 3단계 10,000 `LIKES10K`는 `inactive = true`(입력도 안 됨) - 앞 단계 달성 때 `inactive` 지우고(보상 · 기한 확정) 공지 때 `hidden` 지움 | `docs/release/codes.md` | 출시 기념 `FORGE2026`는 처음부터 보임 |

---

## 1. Creator Hub - 개발자 상품 · 게임패스

### 1-1. 들어가는 길

1. 브라우저 `create.roblox.com` → 로그인(개발 계정 HoddyForge · UserId 11595243049 - 경험 소유 계정).
2. 왼쪽 **Creations** → 경험 카드(이 게임) 클릭.
3. 왼쪽 메뉴 **Monetization**
   - **Developer Products** → 오른쪽 위 **Create a Developer Product** → 이름 · 설명 · 아이콘(512 × 512) · 가격(Robux) 입력 → **Create**(저장).
   - **Passes** → **Create a Pass** → 이름 · 설명 · 아이콘 → **Create Pass** → 만든 패스 클릭 → 왼쪽 **Sales** → **Item for Sale** 켬 → 가격 입력 → **Save Changes**(패스는 만든 뒤 판매를 따로 켜야 한다).
4. 만든 항목 목록에서 각 항목의 **ID**(숫자)를 복사한다(항목 옆 ⋯ → **Copy Asset ID** 또는 상세 화면 주소창 숫자).

### 1-2. 만들 목록 (데이터 = `roblox/src/shared/data/MonetizationData.lua`)

> 설계 문서(monetization-p4c.md §2 · §9)와 roadmap P6은 "상품 6 · 패스 4"라고 적혀 있지만 **지금 데이터는 상품 18 · 패스 5**다(QUEUE-ALL1 P6에서 `theme_jelly` · `glider_dragonWing` · `nameplateBadge` 추가 · QUEUE-ALL6 H에서 꾸미기 10 추가 - 줄 29-1 ~ 29-10). 이 표가 기준이다.
> 가격 = 데이터의 `robux` 값 그대로(표시용 자리값). **실제 청구 가격은 Creator Hub 값이 진실**이라 두 값을 같게 맞춘다. 표시 이름 = 게임 안 이름(`CosmeticSlotData.lua` · `TextData.lua shop.pass.*.name`).

| 줄 | MonetizationData 키 | 종류 | 표시 이름(추천) | 가격 자리(로벅스) | 아이콘 512 파일 | 받은 ID를 넣을 칸 |
|---|---|---|---|---|---|---|
| 22 | `theme_starlight` | 개발자 상품 | 테마 세트 「별빛」 | 199 | `docs/release/icons/theme_starlight.png`(QUEUE-ALL5 E) | `products.theme_starlight.productId` |
| 23 | `theme_ember` | 개발자 상품 | 테마 세트 「불씨」 | 199 | `docs/release/icons/theme_ember.png`(QUEUE-ALL5 E) | `products.theme_ember.productId` |
| 24 | `theme_frost` | 개발자 상품 | 테마 세트 「서리꽃」 | 199 | `docs/release/icons/theme_frost.png`(QUEUE-ALL5 E) | `products.theme_frost.productId` |
| 27 | `theme_jelly` | 개발자 상품 | 테마 세트 「말랑 젤리」 | 199 | `docs/release/icons/theme_jelly.png`(QUEUE-ALL5 E) | `products.theme_jelly.productId` |
| 25 | `glider_petal` | 개발자 상품 | 꽃잎 글라이더 | 149 | `docs/release/icons/glider_petal.png`(QUEUE-ALL5 E) | `products.glider_petal.productId` |
| 26 | `glider_kite` | 개발자 상품 | 연 글라이더 | 149 | `docs/release/icons/glider_kite.png`(QUEUE-ALL5 E) | `products.glider_kite.productId` |
| 28 | `glider_dragonWing` | 개발자 상품 | 푸른 드래곤 날개 | 149 | `docs/release/icons/glider_dragonWing.png`(QUEUE-ALL5 E) | `products.glider_dragonWing.productId` |
| 29-1 | `theme_anvil` | 개발자 상품 | 테마 세트 「망치와 모루」 | 199 | `docs/release/icons/theme_anvil.png`(QUEUE-ALL6 H) | `products.theme_anvil.productId` |
| 29-2 | `theme_halloween` | 개발자 상품 | 테마 세트 「할로윈 박쥐」(10월만 판매) | 199 | `docs/release/icons/theme_halloween.png`(QUEUE-ALL6 H) | `products.theme_halloween.productId` |
| 29-3 | `glider_slimeParachute` | 개발자 상품 | 슬라임 낙하산 | 149 | `docs/release/icons/glider_slimeParachute.png`(QUEUE-ALL6 H) | `products.glider_slimeParachute.productId` |
| 29-4 | `item_rocketPop` | 개발자 상품 | 처치 이펙트 「로켓 반짝」 | 99 | `docs/release/icons/item_rocketPop.png`(QUEUE-ALL6 H) | `products.item_rocketPop.productId` |
| 29-5 | `item_balloonPop` | 개발자 상품 | 처치 이펙트 「풍선 펑」 | 99 | `docs/release/icons/item_balloonPop.png`(QUEUE-ALL6 H) | `products.item_balloonPop.productId` |
| 29-6 | `item_crystalBlade` | 개발자 상품 | 무기 스킨 「수정 결정 무기」 | 149 | `docs/release/icons/item_crystalBlade.png`(QUEUE-ALL6 H) | `products.item_crystalBlade.productId` |
| 29-7 | `item_goldenHammer` | 개발자 상품 | 강화 연출 「황금 망치」 | 99 | `docs/release/icons/item_goldenHammer.png`(QUEUE-ALL6 H) | `products.item_goldenHammer.productId` |
| 29-8 | `item_forgeBrazier` | 개발자 상품 | 귀환 연출 「대장간 화로」 | 99 | `docs/release/icons/item_forgeBrazier.png`(QUEUE-ALL6 H) | `products.item_forgeBrazier.productId` |
| 29-9 | `item_highFive` | 개발자 상품 | 이모트 「하이파이브」 | 49 | `docs/release/icons/item_highFive.png`(QUEUE-ALL6 H) | `products.item_highFive.productId` |
| 29-10 | `item_petCrown` | 개발자 상품 | 펫 꾸미기 「펫 왕관」 | 49 | `docs/release/icons/item_petCrown.png`(QUEUE-ALL6 H) | `products.item_petCrown.productId` |
| 29 | `season_premium` | 개발자 상품(시즌마다 다시 삼) | 시즌 패스 유료 줄 | 399 | `docs/release/icons/season_premium.png`(QUEUE-ALL5 E) | `products.season_premium.productId` |
| 33 | `bagExpand` | 게임패스 | 가방 확장 | 149 | `docs/release/icons/bagExpand.png`(QUEUE-ALL5 E) | `gamePasses.bagExpand.passId` |
| 34 | `pickupRadius` | 게임패스 | 자동 줍기 반경 | 99 | `docs/release/icons/pickupRadius.png`(QUEUE-ALL5 E) | `gamePasses.pickupRadius.passId` |
| 35 | `recallCooldown` | 게임패스 | 빠른 귀환 | 99 | `docs/release/icons/recallCooldown.png`(QUEUE-ALL5 E) | `gamePasses.recallCooldown.passId` |
| 36 | `nameplateColor` | 게임패스 | 이름표 색 | 49 | `docs/release/icons/nameplateColor.png`(QUEUE-ALL5 E) | `gamePasses.nameplateColor.passId` |
| 37 | `nameplateBadge` | 게임패스 | 이름표 배지 | 49 | `docs/release/icons/nameplateBadge.png`(QUEUE-ALL5 E) | `gamePasses.nameplateBadge.passId` |

- 아이콘(QUEUE-ALL5 E): **13장 제작 완료** + QUEUE-ALL6 H 10장(`make_store_icons.py` 같은 스타일) = `docs/release/icons/<키>.png`(512 × 512 · 투명 바깥 · 3톤 · 굵은 외곽선 · 글자 없음 · 다시 만들기 = `docs/release/icons/README.md`). 업로드는 Creator Hub 각 상품 · 패스 화면의 아이콘 칸(사용자). 비교용 게임 아이콘 Blender판 = `game_icon_blender_{A,B,C}.png`. 아래는 옛 메모: `roblox/art/icons` 아래에 상품 · 패스 전용 512 아이콘은 **하나도 없었다**. 비슷한 것은 보상 아이콘 `roblox/art/icons/reward/cosmeticTheme.png` · `gliderSkin.png` · HUD `roblox/art/icons/hud/bag.png` · `return.png`뿐이고 모두 **256 × 256 범용**이라 임시로도 512 확대가 필요하다. → 13장 제작 필요(★ 사용자 결정: 직접 만들지 · 아트 단계에 맡길지 · 임시로 범용 아이콘 확대본을 쓸지).
- 가격 23칸은 전부 자리값이다(monetization-p4c.md §10 "자리값 유지"로 닫혔지만 **실제 값 확정은 ★ 사용자 결정**).
- 설명란(각 상품): 게임 안 설명과 같게 - 예) 가방 확장 "가방 칸 +20" · 자동 줍기 "펫 자동 줍기 반경 ×1.5" · 빠른 귀환 "마을 귀환 대기 시간 ×0.5" · 테마 "대시 · 점프 · 활강 · 발자국 4칸 치장(능력치 없음)". "전투력 · 획득량은 오르지 않습니다"를 함께 적는다(`TextData.lua:645`).

### 1-3. ID 채우기 → 확인

1. 받은 숫자를 위 표의 칸에 넣는다. 예) `theme_starlight = { productId = 1234567890, robux = 199, ...}` · `bagExpand = { passId = 987654321, robux = 149, ...}`. **0이 남은 항목은 게임 안에서 회색 "준비 중"**(`MonetizationService.lua:282` · `:305` - `not_ready`).
2. Creator Hub 가격을 바꿨으면 같은 줄의 `robux`도 같게 고친다(창에 보이는 값).
3. 커밋 · 푸시 → Rojo가 Studio에 반영 → Studio **Play**.
4. **Output 창**에서 확인(로그 원문 - `MonetizationService.lua:32` · `:366`):
   - 아래 줄이 **한 줄도 없어야** 정상이다. checkCatalog는 통과하면 아무것도 안 찍는다(성공 줄 없음).
     ```
     [B2] 상품 등록 거부: <이유>
     ```
     이유 예: `<키>: productId <번호> 중복(<다른 키>)`(같은 번호를 두 상품에 넣음) · 없는 치장 id · 금지 종류.
   - 시즌 1 시작일(2-1절)을 넣었다면 이 경고도 사라져야 한다.
     ```
     [B2] 시즌 1 시작일 미정(LeaderboardConfig.firstSeasonDateKst) - 시즌 번호 고정 · 시즌 패스가 넘어가지 않는다(출시 전 확정)
     ```
   - **게임패스 번호는 checkCatalog가 중복을 검사하지 않는다** → 5개 번호가 서로 다른지, 상품 번호와 섞이지 않았는지 눈으로 한 번 더 본다.
5. 상점(보석상인 좌판 두 번째 프롬프트 `ShopPrompt` · F) → 치장 · 편의 · 시즌 탭의 로벅스 버튼이 "준비 중"이 아닌지 본다.
6. Studio에서 상품 하나를 사 본다(Studio 구매는 가짜 구매 - 로벅스 안 나감). Output에
   ```
   [B2] 구매 처리: <이름> - theme_starlight(<구매 ID>) → PurchaseGranted
   ```
   가 찍히고, Play를 멈췄다 다시 켜도 산 테마가 남아 있으면 통과(monetization-p4c.md §9 테스트 항목).

---

## 2. Creator Hub - 경험 설정

### 2-1. 시즌 1 시작일 (코드 값)

- 위치: `roblox/src/shared/data/LeaderboardConfig.lua:21` - 현재 `firstSeasonDateKst = nil`(같은 파일 `:16 seasonStartUnix = 0`).
- 지금 상태 = 시즌 번호가 `seasonId = 1`(`:14`)로 고정 → 리더보드 시즌도, 시즌 패스(8주 · `seasonLengthDays = 56` `:15`)도 영원히 안 넘어간다 + 서버 시작마다 `[B2] 시즌 1 시작일 미정` 경고.
- 바꾸는 법: `firstSeasonDateKst = { 2026, 10, 14 },` 처럼 `{ 년, 월, 일 }`을 넣는다(그날 0시 KST가 시즌 1 시작 · 리더보드 · 시즌 패스 공통 시계). 저장 구조 변경이 아니라 SAVE_VERSION은 그대로.
- 추천: **오픈일**(roadmap P6 "시즌 1 시작일 확정(추천: 오픈일, 8주)"). **★ 사용자 결정: 날짜.**

### 2-2. 기본 정보 · 이미지 · 장르

**Creations → 경험 → Configure → Basic Settings**(이름 · 설명 · 장르 · 아이콘 · 썸네일이 이 화면 또는 바로 아래 **Places/Thumbnails** 칸에 있다)

| 항목 | 넣을 것 | 파일 |
|---|---|---|
| 이름 | ★ 사용자 결정(설명 초안도 `{게임 이름}`으로 비어 있음) | - |
| 설명 | 초안 2안(한국어 · 영어) + 업데이트 게시판 첫 글 | `Claude outputs/QUEUE-ALL2/launch/description-drafts.md` · 틀 `docs/store/description-template.md` |
| 아이콘(512 × 512) | 1장 고르기 ★(추천 D) | Blender판 `docs/release/icons/game_icon_blender_{A,B,C,D}.png` · 게임 안 촬영판 D `docs/release/icons/game_icon_capture_D.png`(QUEUE-STUDIO S-4) · 옛 캡처 `Claude outputs/QUEUE-ALL2/launch/icon_{A_grass,B_pillar,C_tight}.png` |
| 썸네일(1920 × 1080) | 3장 × 글자 있음/없음 - 보통 글자 있음 3장 업로드(순서 A → B → C 추천) ★ | `Claude outputs/QUEUE-ALL2/launch/thumb_A_transcend_text.png` · `thumb_B_codex_text.png` · `thumb_C_hub_text.png`(글자 없는 판 = `_plain`) |
| 장르 | 추천: **RPG**(하위 장르가 있으면 액션 RPG 계열) ★ | - |

- 업로드 경로: 아이콘 = **Icon** 칸 **Upload Image** · 썸네일 = **Thumbnails** 칸 **Upload** → 드래그로 순서 정리 → **Save Changes**.
- QUEUE-ALL4 A5에서 썸네일 · 아이콘을 다시 찍을 예정이다 → 업로드 전에 `Claude outputs/QUEUE-ALL4/` 아래 새 판이 있으면 그걸 쓴다.
- 썸네일 원본 캡처가 1920 × 788이라 1.37배 확대돼 약간 부드럽다(QUEUE-ALL2 보고서 6절).

### 2-3. 경험 질문지 (Maturity & Compliance Questionnaire)

**Configure → Questionnaire**(또는 **Audience → Maturity & Compliance**) → **Start/Edit Questionnaire**. 끝내지 않으면 등급 없음으로 노출이 제한되니 공개 전에 반드시 제출한다.

| 질문 주제 | 이 게임에 맞는 답(추천) | 근거 |
|---|---|---|
| 폭력(Violence) | **있음 - 경미/비현실적**(판타지 무기로 몬스터 · 보스와 싸움, 사람 상대 실감 폭력 없음) | 보스 · 잡몹 전투 |
| 피 · 고어(Blood/Gore) | 없음 | 피 연출 없음 |
| 유료 랜덤 아이템(Paid random items) | **없음** | `MonetizationData.lua:20` "paidRandom 지금 0개" · 알(랜덤)은 시즌 무료 줄만 · 강화 확률은 골드(로벅스로 못 삼)로만 |
| 도박 · 실제 돈 · 베팅 | 없음 | - |
| 공포(Fear) | 없음(또는 경미 - 어두운 보스 연출 정도) | - |
| 거친 말 · 욕설 | 없음 | 게임 문구에 없음 |
| 로맨스 · 성적 내용 | 없음 | - |
| 술 · 담배 · 약물 | 없음 | - |
| 사용자 제작물 공유(자유 그리기 · 업로드) | 없음 | - |
| 채팅 | 텍스트 채팅 있음(로블록스 기본 `TextChatService`) · 음성은 2-6절 결정에 따름 | - |
| 소셜 행아웃(어울리기가 주목적) | 아니오 | - |

- 예상 결과 = "경미(Mild)" 등급 근처. 최종 등급은 로블록스가 정한다.

### 2-4. 서버 크기 (Places → 장소 → 설정)

**Configure → Places** → 시작 장소 클릭 → **Server Fill / Access**(서버 인원) 화면:

> ### ★ 서버 크기 = **Max Players 16 · 정원(Preferred) 12** (확정 - QUEUE-ALL5 B)
> 16 = 12 + 파티 합류 여유 4. 정원 12로 채우고, 남은 4칸은 다른 서버의 파티원이 합류하는 자리다. **Max를 12로 두면 파티 합류가 `GameFull`로 거절된다.**

- **Max Players(서버 최대 인원) = 16** · **매치메이킹 정원(Customize → 예약 칸 4) = 12** 추천.
  - 근거: `roblox/src/shared/data/PartyConfig.lua:94-95` - `serverPreferredPlayers = maxMembers × partiesPerServer`(4 × 3 = **12**) · `serverCapacity = 12 + crossServerExtraSlots`(파티 1팀 4 = **16**). 주석 `:47-52` "서버 정원 12 = 4인 × 3파티 · 서버 상한(Players.MaxPlayers로 대시보드에 설정해야 하는 값) = 12 + 4 = 16". roadmap-v2 P6 "MaxPlayers 16 · Preferred 12".
  - 즉 **보통 서버는 12명으로 채우고**, 남은 4칸은 다른 서버에서 파티원이 합류(크로스서버)할 자리다. 최대 인원을 12로만 두면 꽉 찬 서버로 오는 파티 합류가 `GameFull`로 거절된다(`PartyCrossServer.lua:104-107`).
  - 화면에서: Server Fill = **Customize** → "Reserve slots"(예약 칸) = 4 → Players.PreferredPlayers = 16 − 4 = 12. 메뉴가 다르면 "Max Players 16"만이라도 넣고 아래 로그로 확인.
- 확인 로그(라이브 서버 F9 · Studio Output 둘 다 · `PartyCrossServer.lua:981`):
  ```
  [forge-game] PartyCrossServer 로드됨 - 플랫폼 MaxPlayers=16 PreferredPlayers=12, 크로스서버 상한 16
  ```
  값이 안 맞으면 끝에 ` - 설정 확인 필요: 대시보드 Max Players=16, 매치메이킹 정원=12 로 맞춰야 설계(12+4)와 일치한다`가 붙는다.
- 성능 근거: 모든 보스 12인 겹침 최악이 허용치 안(`docs/perf/server-logic-alpha.md` 31줄 · BR1(나)).

### 2-5. 공개 범위 (Configure → Audience / Access)

순서 추천:
1. **비공개(Private)** - 지금. 본인만. 1 · 2 · 4장 확인을 여기서 끝낸다.
2. **친구 · 지정 테스터만** - 접근 설정에서 친구(또는 지정 계정 · 그룹 역할) 허용. 실기 다중 접속(파티 · 크로스서버 · 폰)을 사람 손으로 확인.
3. **공개(Public)** - 질문지 제출 완료 · 상품 ID 채움 · 시즌 1 시작일 확정 뒤.
- 주의: 2단계 테스트도 **라이브 서버**라 저장 · 리더보드 · 합동 목표가 진짜 저장소에 쌓인다(4-3절).

### 2-6. 그 밖의 경험 설정

| 항목 | 위치 | 추천 | 근거 |
|---|---|---|---|
| **Studio Access to API Services**(DataStore) | Studio **File → Game Settings → Security** (Creator Hub **Configure → Security**에도 있음) | **켬**(이미 켜져 있음 - monetization-p4c.md §9) | 저장 · 리더보드 · 선물함 · 합동 목표가 전부 DataStore. Studio 저장은 키 분리(`_verify` · `studio_` · `_studio`) |
| **Allow HTTP Requests** | 같은 화면 | **끔 그대로** | `HttpService`는 `GenerateGUID`만 씀(`SaveSystem.lua:30` · `GiftService.lua:36` · `AcquisitionAudit.lua:73`) - 외부 요청 0 |
| Third Party Sales · Third Party Teleports | 같은 화면 | 끔 | 같은 경험 안 텔레포트(크로스서버 파티)만 씀 |
| 음성 채팅(근접) | **Configure → Communication**(또는 Studio Game Settings → Communication) | ★ 사용자 결정(roadmap P6 목록에는 "음성 채팅(근접)"이 있음) | 켜면 질문지 채팅 답도 같이 맞춘다 |
| 매치메이킹 언어 가중치 · 스트리밍 반경 | roadmap P6 대시보드 목록 | roadmap 항목 그대로 따름(이 문서 범위 밖) | - |

### 2-7. 오디오 공개 권한

- 효과음 시트 3개가 업로드돼 있다(`roblox/src/shared/data/ArtAssetIds.lua:100-102` · `audio/sfx_combat` · `sfx_loot` · `sfx_ui`). **상태가 아직 `Reviewing`**(심사 중)이다 → 승인 전에는 라이브에서 소리가 안 난다.
- 확인: **Creations → Development Items → Audio** → 세 파일이 **Approved**인지 · 각 파일 **Permissions**에 이 경험이 허용돼 있는지(같은 계정 소유라 보통 자동). 공개 배포(Distribute on Creator Store)는 **필요 없다**.
- 배경 음악은 자리만(★ 사용자 결정 - QUEUE-ALL2 보고서 6절).

### 2-8. 그룹 (만들 경우)

- 이름만 정하고(★ 사용자 결정), 커뮤니티 · 공지 링크 용도로만 쓴다. 그룹 가입 보상은 꺼져 있다(`SocialRewardData.lua:20 groupRewardEnabled = false`).
- **경험 소유권을 그룹으로 옮기지 말 것.** 이유:
  - 게임이 쓰는 업로드 에셋 **677개**(메시 · 모델 259 · 이미지 Decal 415 · 오디오 3 - `ArtAssetIds.lua`)가 전부 **개인 계정 소유**다. 업로드 스크립트가 만든 사람 = 개인 UserId로 올렸다(`roblox/tools/opencloud/upload.py:29` `CREATOR_USER_ID = "11595243049"` · `:182` `"creator": {"userId": ...}`).
  - 로블록스는 **경험 소유자와 에셋 소유자가 다르면 권한 검사**를 한다. 그룹 경험이 되면 개인 소유 메시 · 이미지 · 오디오가 "권한 없음"으로 로드에 실패할 수 있다 → 아트가 빠지고(`[ArtAssetLoader] 로드 실패` 경고 · 옛 모습으로 대체) 소리가 안 난다.
  - 옮기려면 677개를 그룹 소유로 다시 올리고 `ArtAssetIds.lua`를 새 ID로 다시 만들어야 한다. 출시 전에 할 일이 아니다.

---

## 3. 출시 직전 코드 쪽 확인 목록

> 고치는 곳은 모두 데이터 파일 한 줄. 고친 뒤 커밋 · 푸시 → Rojo 반영 → Studio Play로 로그 확인 → **File → Publish to Roblox**.

| # | 항목 | 파일:줄 | 현재 값 | 출시 값 추천 | 메모 |
|---|---|---|---|---|---|
| 1 | **아트 스위치** | `roblox/src/shared/data/ArtStyleV1Data.lua:41` | **`enabled = true`(QUEUE-ALL5 B · 사용자 결정 - 켬 완료)** | `true` 그대로 | 라이브도 지금까지 검증한 화면(아트 켬)과 같다. ArtAssetLoader가 에셋 677개를 받는다(2-7 · 2-8 확인). **비상 끔**: ① `enabled = false`로 고쳐 퍼블리시 또는 ② Studio edit에서 ReplicatedStorage Attribute `ArtStyleV1Force = false`를 둔 채 퍼블리시(`HuntingGround.server.lua` - 이 값이 false면 Studio · 라이브 모두 끔). 반대로 **평소 퍼블리시 전에는 `ArtStyleV1Force`가 false로 남아 있지 않은지 꼭 확인**(남아 있으면 라이브가 옛 모습) |
| 2 | 표준 체형 | `ArtStyleV1Data.lua:44` | `standardBody.enabled = false` | ★ 사용자 결정(A2-N4 P0-3 B안 · 기본 끔) | 그대로면 각자 아바타 체형 |
| 3 | 개발 명령 허용 계정 | `roblox/src/shared/data/DevToolsConfig.lua:23` | `allowedUserIds = {}` | 그대로(`{}`) | `/gg` 개발 명령은 라이브에서 스크립트가 첫 줄에서 끝난다(`DevTools.server.lua:20` `if not RunService:IsStudio() then return end`) → 라이브와 무관. Team Create로 남과 Studio를 같이 쓸 때만 `{ 11595243049 }`로 좁힌다 |
| 4 | 운영 명령 허용 계정 | `roblox/src/server/OpsConfig.lua:3` | `userIds = { 11595243049 }`(HoddyForge) | 그대로 · 운영자를 더 둘 거면 UserId 추가 ★ | `/ops`(격리 해제 · 회수 · 리더보드 제거 · 저장 복구 · 선물)는 **라이브에서 동작**한다(`OpsServer.server.lua`). 선물함 관리자도 같은 목록 |
| 5 | 리더보드 제외 계정 | `roblox/src/shared/data/LeaderboardConfig.lua:56` | `excludedUserIds = { 11595243049 }` | 그대로(개발 계정 기록 제외) | 라이브(`writeMode "live"`)에서만 적용 |
| 6 | 시즌 1 시작일 | `LeaderboardConfig.lua:21` | `firstSeasonDateKst = nil` | `{ 년, 월, 일 }` = 오픈일 ★ | 2-1절 |
| 7 | 체크포인트 순간이동 | `roblox/src/shared/data/WorldMapData.lua:451` | `enabledByDefault = true`(Workspace Attribute `CheckpointTeleport`) | ★ 사용자 결정(지금 켬 = 시험판 그대로 출시) | 서버 부팅 때 `Travel.lua:801-802`가 이 값으로 Attribute를 켠다 · 라이브도 같은 값. 끄려면 `false` |
| 8 | 텔레메트리 | `roblox/src/shared/data/TelemetryData.lua:6` · `:8` · `:14` | `enabled = true` · `dryRunInStudio = true` · `purchase.enabled = false` | **그대로** | 라이브 = AnalyticsService로 실제 전송(경제 · 커스텀 · 퍼널) · Studio = `[T1][드라이런]` 로그만. 구매 통계는 이미 `Telemetry.custom("Purchase_<key>")`로 간다 → `purchase` 분류는 자리라 꺼 둬도 된다 |
| 9 | 코드(쿠폰) 표 | `roblox/src/shared/data/SocialRewardData.lua` `codes` | `FORGE2026` 출시 기념(강화석 15 · 반짝 조각 20 · 만료 2026-12-31) · `LIKES1K` 좋아요 목표(강화석 10 · 반짝 조각 10 · 만료 2027-01-31 · 게시판 숨김 - 목표 달성 때 `hidden` 지우고 업데이트) | 만료일 확인 ★ | 만료 = **UTC** 날짜 끝까지(KST로는 다음 날 오전 9시). 설명 초안 · 게시판 첫 글이 `FORGE2026 … 2026-12-31까지`를 적고 있다 - 날짜를 바꾸면 초안도 같이 |
| 10 | 업데이트 게시판 날짜 | `SocialRewardData.lua:22-25` | `news` 두 줄 날짜 `2026-10-01` | 오픈일로 ★ | 허브 게시판에 그대로 보인다 |
| 11 | 합동 목표 1주차 | `roblox/src/shared/data/CommunityGoalData.lua:17` · `server/CommunityGoalService.lua:111-156` | `week1Factor = 0.7` · 주 = **월요일 0시 UTC**(`Quest.lua:13-14` - KST 월요일 오전 9시) | 값 그대로 · **오픈 요일**에 주의 ★ | 1주차 목표 = 그 주 **첫 기여부터 24시간 실측 합 × 7 × 0.7**(`CommunityGoalRules.lua:29-30`) - 24시간 동안 HUD는 "목표 계산 중". 주 중간(예: 목요일)에 열면 남은 날이 적어 1주차 목표에 못 닿기 쉽다 → **월요일(KST 09시 이후) 오픈 추천**. 또 라이브 테스트(2-5의 2단계)에서 남은 `week_<번호>` 기록이 "지난 3주"로 잡히면 첫 목표가 아주 작아진다 → 오픈 전 Creator Hub **Data Stores Manager**에서 `CommunityGoal_v1`의 옛 주 키 확인(Studio 기록은 `studio_` 접두어라 무관) |
| 12 | 자동 검증 회귀 스위치 | `DevToolsConfig.lua:38` | `verify.regression = false` | **`false` 확인** | 출시 직전 회귀 전체를 돌렸다면(블록 G) 다시 false로 돌려놨는지. 라이브에선 어차피 안 돈다(IsStudio) · `:40 exclude = { "S04(나)" }`는 그대로 |
| 13 | 경제 시뮬 · 입력 진단 | `DevToolsConfig.lua:27` · `:30` | `econSim = true` · `inputDiag = false` | 그대로 | 둘 다 Studio 전용(IsStudio로 막힘) |
| 14 | 세트 도감 탭 | `roblox/src/shared/data/SetData.lua:21` | `codex = { enabled = false }` | ★ 사용자 결정(A2-N4 §4-2 "결정 필요 - 기본 끔") | 켜면 장비창 "도감" 탭 |
| 15 | 피해 숫자 새 표시 | `roblox/src/shared/data/DamageNumberData.lua:7` | `enabled = false`(프로토타입) | 그대로 | U1에서 켜는 것 |
| 16 | 유저 간 로벅스 선물 | `MonetizationData.lua:59` | `userToUser.enabled = false` | 그대로 | P4c 뒤 자리 |
| 17 | 그룹 가입 보상 | `SocialRewardData.lua:20` | `groupRewardEnabled = false` | 그대로(그룹 없음) | - |
| 18 | 시즌 패스 | `roblox/src/shared/data/SeasonPassData.lua:56` | `enabled = true` | 그대로 · 6번(시작일)과 한 세트 | 시작일 없으면 1시즌에 멈춤 |
| 19 | 상품 · 패스 ID | `MonetizationData.lua:22-37` | 전부 `0` | Creator Hub 번호 | 1장 |

- 그 밖에 찾아본 개발용 강제 값(모두 Studio 전용이라 출시 때 손댈 것 없음): Workspace `RiftForce`(균열 강제 - `/gg`만 씀) · ReplicatedStorage `DebugZonesUnlocked`(`Travel.lua:87` · Studio만) · `ArtStyleV1Force`(QUEUE-ALL5 B부터 **라이브에서도 읽는다** - false면 라이브 아트 끔. 비상 끔용) · `VerifyArmedUntil`(Studio만 · `DevToolsConfig.lua:175-176`) · 궤적 스킨 `devOnly`(`TrailSkinService.lua:16` Studio만) · 검증 훅(AttackServer · DashServer · MovementServer · SkillServer · StageServer의 `if IsStudio()` 블록).
- 단 **Studio에서 edit 모드로 켠 Attribute는 퍼블리시 때 place 파일에 같이 실려 갈 수 있다**. 퍼블리시 직전 Studio 탐색기에서 ReplicatedStorage · Workspace Attribute에 `VerifyArmedUntil` · `VerifyOnly` · `ArtStyleV1Force` · `RiftForce` · `DebugZonesUnlocked`가 남아 있으면 지운다(라이브는 IsStudio로 무시하지만 `RiftForce`는 `RiftService.server.lua:20`이 라이브에서도 읽는다 - **꼭 지운다**).

---

## 4. 출시 당일 순서

1. **(전날까지)** 1장 상품 · 패스 만들고 ID 채움 · 3장 코드 값 확정 → 커밋 · 푸시.
2. Studio(Rojo 연결) → Play 1회 → Output에서 `[B2] 상품 등록 거부` 0줄 · `[B2] 시즌 1 시작일 미정` 없음 · `PartyCrossServer 로드됨 … 설정 확인 필요` 없음(이건 2-4 저장 뒤 라이브에서만 맞음 - Studio는 Studio 값이 나온다).
3. Studio 탐색기에서 3장 끝의 개발용 Attribute 정리 → **File → Publish to Roblox**.
4. Creator Hub: 2-2 이름 · 설명 · 아이콘 · 썸네일 · 장르 → 2-3 질문지 제출 → 2-4 서버 크기 → 2-6 Security 확인 → 2-7 오디오 Approved 확인.
5. 비공개 상태로 본인 계정 라이브 접속 → F9 서버 로그(5장) 1회 훑기 → 상점 버튼 · 체크포인트 · 아트 켜짐 · 소리 확인.
6. 친구 · 테스터 공개 → 파티 · 크로스서버 합류 · 폰 1회.
7. 공개(Public) 전환 → 업데이트 게시판 · 그룹/소셜 공지(설명 초안의 첫 글).
8. 5장 "출시 후 1시간" 감시.

---

## 5. 출시 후 1시간 볼 것

**F9(개발자 콘솔) → Server 탭 → Log**(소유자 계정으로 라이브 서버에 접속해야 서버 로그가 보인다). 검색창에 아래 접두어를 넣는다.

| 무엇 | 로그 원문(접두어) | 나오면 |
|---|---|---|
| 저장 실패 | `[forge-game] 저장 실패:` (`SaveCoordinator.lua:112`) | 한두 번은 DataStore 일시 오류 · 계속 나오면 Creator Hub DataStore 한도 확인 |
| 저장 중단 | `[forge-game] 저장 중단:` (`SaveCoordinator.lua:51`) | 그 사람 화면에 경고가 떴다 - 재접속 안내 |
| 로드 실패 | `[forge-game] 저장 데이터 불러오기 실패:` (`SaveServer.server.lua:42`) | 가장 위험 - 바로 원인 확인 |
| 세션 잠금 대기 | `[SaveSystem] 세션 잠금 대기:` (`SaveSystem.lua:1542`) | 빠른 재접속 때 정상 · 오래 걸리면 확인 |
| 저장값 이상 | `[SaveSystem] 저장 직전 비정상 값` · `[SaveSystem] 손상 저장 음수 골드` · `[forge-game] 저장 전 스테이지 하드 상한으로 자름` | 계산 버그 신호 - 기록 |
| 구매 | `[B2] 구매 처리:` (`MonetizationService.lua:105`) - 끝이 `PurchaseGranted`인지 | `NotProcessedYet`가 반복되면 그 상품 확인 |
| 상품 등록 | `[B2] 상품 등록 거부:` | 0줄이어야 함 |
| 시즌 | `[B2] 시즌 1 시작일 미정` · `[B2] 시즌 패스 넘김:` | 첫 줄이 보이면 2-1 누락 |
| 선물함 | `[B2] 선물함:` … `저장 실패` | 다음 접속 때 다시 옮김(정상 복구 경로) |
| 리더보드 | `[Leaderboard]` (`실패` · `최종 실패` · `기록 거절`) · `[forge-game] 리더보드:` | 최종 실패가 이어지면 DataStore 한도 |
| 합동 목표 | `[CommunityGoal]` | 첫 24시간 HUD "목표 계산 중"은 정상 |
| 아트 로드 | `[ArtAssetLoader] 메시 캐시` · `[ArtAssetLoader] 로드 실패` | 실패 = 권한 · 심사 문제(2-7 · 2-8) |
| 서버 인원 | `[forge-game] PartyCrossServer 로드됨 - 플랫폼 MaxPlayers=…` | `설정 확인 필요`가 붙으면 2-4 다시 |
| 크로스서버 | `[forge-game] 크로스서버 텔레포트 실패` · `크로스서버 파티 … 실패` | 파티 합류 문제 |
| 코드 · 초대 | `[forge-game] 코드 시도:` · `[forge-game] 초대 보상:` | 코드 오타 문의 대응 |

- `[forge-game] 저장 성공:`은 저장마다 찍히는 정상 줄이다(많아도 정상).
- Creator Hub → 경험 → **Analytics**: 동시 접속 · 세션 길이 · **Economy**(Gold · EnhanceStone · GemDust · SparkleShard 흐름) · **Funnels**(`ftue_fight` → `ftue_boss` 8단계 - `TelemetryData.lua:22`) · **Monetization → Sales**. 텔레메트리는 `flushSeconds = 300`(5분)마다 보내 첫 숫자는 몇 분 늦다.
- Creator Hub → **Data Stores Manager**: 요청 수 · 제한(throttle) 경고.

---

## 6. 사용자 결정 필요 칸 모음

1. 상품 · 패스 13개 **가격**(지금 자리값 199 · 149 · 399 · 99 · 49).
2. 상품 · 패스 13개 **512 아이콘** - QUEUE-ALL5 E에서 13장 제작(`docs/release/icons/`) → 이대로 쓸지 · 다시 그릴지만 결정.
3. **게임 이름**(설명 초안 `{게임 이름}`). **게임 이름 확정 후 교체(ALL9F 출시 전 점검)**: 게임 안 이름 = `roblox/src/shared/data/GameInfoData.lua` `name` 한 곳(지금 자리값 `"NAME"` - 메인 메뉴 로고 자리) · `python roblox/tools/i18n/check_textdata.py`가 자리값이 남아 있으면 "경고: 게임 이름이 아직 자리값" 줄을 낸다(QUEUE-ALL9C 2-3).
4. 경험 **아이콘 1장**(A 풀밭 · B 빛기둥 · C 근접 · **D 근접 + 초월 대검 + 빛기둥(추천)** - Blender판 `docs/release/icons/game_icon_blender_*.png` · 게임 안 촬영판 `game_icon_capture_D.png`) · **썸네일 순서** · 장르(추천 RPG).
5. **시즌 1 시작일** `LeaderboardConfig.firstSeasonDateKst`(추천 오픈일) - 합동 목표 때문에 **월요일 오픈** 추천.
6. **체크포인트 순간이동** 출시 때 켤지(`WorldMapData.lua:451` - 지금 켬).
7. **표준 체형**(`ArtStyleV1Data.lua:44`) · **세트 도감 탭**(`SetData.lua:21`) 켤지(둘 다 지금 끔).
8. 코드 **만료일** · 게시판 **날짜**(`SocialRewardData.lua:17-18` · `:22-25`).
9. 운영 명령 **추가 운영자**(`OpsConfig.lua:3`).
10. **음성 채팅(근접)** 켤지 · **배경 음악**.
11. **그룹** 이름(만든다면 - 소유권 이전은 하지 않음).
