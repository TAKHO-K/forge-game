# QUEUE-UI2 보고서(새 디자인 묶음 적용 - 2026-10-05)

> 지시 = 사용자 메시지(QUEUE-UI2) · 상태 = `QUEUE-UI2-state.md` · 기준 = `docs/design/handoff/00_design-system/v1` · `01_main-menu/v2` · `02_hud/v3` · `03_bag-equip/v1`.
> Play 캡처 = `C:\Users\xkrgh\vibe\claude-design-handoff\<묶음>\play\`(저장소 밖).

## 판단 필요(맨 위)
1. **좁은 창 모드 기준**(01 v3): spec 식은 UI 배율 1(창 끝 1012px)을 가정해 4:3 1440×1080에서 좁은 창 모드가 켜지는데, 우리 루트는 배율 min(가로, 세로)라 4:3에서 창 끝이 759px → 빈 구역이 넓어 모드가 안 켜지고 얼굴도 안 가려짐(keyart_pc-4x3_open). 지금 = "실제 창 끝 화면 px" 기준(가림 없음이 목적). spec 그대로(가로 1577 미만이면 무조건 좁은 창)를 원하면 데이터 한 줄.
3. **폰 전투 버튼 v2 좌표(02 v5 checklist 2)**: 지금 게임은 v2 좌표를 쓴 적이 없고, 전투 버튼을 **로블록스 기본 점프 버튼 자리로 계산**한다(SkillSlots `touchJumpGeometry`). v2 좌표로 옮기려면 기본 점프 버튼을 숨기고 우리 점프 버튼이 3단 점프 · 활강 입력(지금 = 기본 버튼의 JumpRequest)을 대신해야 한다 → 폰 조작 변경 · 실기기 터치 확인 필요(MCP는 터치 불가). 좌표 데이터 · 간격 하네스만 넣고 적용은 안 함. 진행할까요?
4. **스킬 잠금(E 환생 1 · R 2 · T 3)**: 실제 판정 = 잠금 없음(`SkillIconData.unlockRebirth` 전부 0 · 서버 SkillServer도 환생 조건 없음 · 이동 기술만 환생 단계). HUD 잠금 표시는 같은 데이터를 읽어 지금은 잠긴 칸 0개. spec처럼 잠그려면 게임 규칙 변경(서버 + 데이터) - 안 바꿈.
5. **"HUD 직접 배치" 기능이 게임에 없음**: spec은 "유지"라고 하지만 찾은 것은 창 위치 끌기 저장(WindowPositions)뿐. 새로 만들지 여부 결정 필요(지금 = 기본 배치 고정).

2. **로블록스 PreferredTextSize**: Studio에서 읽기 전용이라 겹침 실험 못 함(Medium). 지금 = 우리 배율과 큰 쪽 하나. 실기기(설정 "글자 크게" 폰)에서 개발자 글자도 엔진이 키우는지 1회 확인 필요.

## UI2-0 · UI2-1 묶음 · 에셋
- zip 4개 → 최상위 폴더 벗겨 `assets` · `mockups` · `prototype` 풀기(덮어쓰기 0 · zip 그대로). zip 안 MISSING.md는 빈 파일 → 설계 담당이 넣은 기존 파일 유지.
- 해시 비교(sha256): 01 = 00과 같은 이름 36 + 새 8 · 02 = 같은 이름 28 + **별칭 17**(`icon-attack-*` → `atk-*` · `menu-backpack` → `bag` · `menu-codex` → `book` · `menu-party-phone` → `party2` 등) + 새 3 · 03 = 전부 00과 같음. **같은 이름 다른 내용 0**.
- 업로드 97(Decal 전부 Approved · 이미지 id 기록): 00 90장 = `roblox/art/ui/ds/` · 01 얼굴 2 + 자리표시 2 = `ui/legends/`(전설 2장은 이미 같은 해시로 올라가 있음) · 02 `disc-256` · `ring-256` · `star4-64` = `ui/hud/`.
- 안 올림: 01 `keyart-v2-left/right.jpg` = 지금 메뉴가 쓰는 `menu_keyart_v2_L/R.png`와 같은 그림(upload.py는 png만 · UI2-3 지시도 L/R png 기준).
- 아이콘 표 한 곳 `shared/data/UiIconData`: 아이콘 v2 32종(`ui/ds/icon-*` · tint 끔 = 그림 색) + `aliases` 17 + `old` 열(옛 `icons/hud/*` 13개 - 지우지 않음).

## UI2-2 UI-0 갱신
### 토큰(`shared/data/UiTokens`)
- 00 spec 색 추가: `accent.pressed` #E6B02F · `warning.lip` #A82620 · `plate.b` #F3E7C2 · `plate.lip` · `outline.warm/cool`. 빨강 규칙(넓은 면 금지 · 전투 HUD 위 = 알림 점만 · 위험 버튼 = 확인 창 안에서만)은 토큰 주석 + `UiKit.confirm okKind = "danger"`로만 노출.
- 버튼 상태 수치 `press`(누름 0.06초 · 0.95 · 내용 +2 / 복귀 0.10초 Back Out / 올림 1.03 · 0.08초 / 비활성 흔들림 ±4px 3번 0.24초 / 끌기 취소 8px) · 9-slice `slice`(SliceCenter 00 표 그대로 · SliceScale 0.5) · 포커스 링 `focusRing`(r12 · r10 · 원).
- 글자 단계 `textScale`(임시 값 = 지시 그대로: PC body 18 · caption 16 · micro 14 / 폰 display 28 · title 22 · heading 18 · button 18 · body 16 · caption 14 · micro 13). 화면별 이름(cardInfo 등)은 단계 이름을 가리키거나 자기 값 → **새 단계표가 오면 `textScale` 값만 바꾼다.**

### 글자 작음 원인(PC 1841×1036 캡처의 카드 보조 글자 약 10px)
- 폰 세트가 PC에 쓰인 것 **아님**(PC 판정 정상 · cardInfo PC 16). 원인 = **루트 UIScale이 창 크기에 맞춰 글자까지 같이 줄임**: Studio 창 뷰포트 1052×592 → 배율 592/1080 = **0.548** → 16 × 0.548 = 8.8 논리 px(캡처는 DPI 1.75배라 1841 폭 · 글자 몸 높이 약 10px). 1080p 전체 화면이면 16 그대로였다. 이중 축소는 없음.
- 고침: 글자 = 토큰 × 글자 배율 × 보정(루트 배율이 `textMinRootScale` 0.75보다 작으면 글자만 덜 줄임) - `UiModel.textPx`. 작은 창 · 노트북(배율 0.67)에서도 화면 글자 ≥ 토큰 × 0.75. Play 확인: 1052×592에서 [소식] 33 · 이어하기 부제 22(TextSize - 화면 = × 0.548).

### 글자 크기 설정
- 계정 설정 `textScale`(보통 1.0 · 크게 1.15 · 아주 크게 1.3 · Attribute `UiTextScale` · SlotSaveData.addedFields 등록 + 왕복 하네스) · 설정 창 [화면] 맨 아래 + 메인 메뉴 설정에 줄 추가 · 새 화면(UiKit) 글자에만 곱함(아이콘 · 칸 · 버튼 크기 그대로) · 바꾸면 즉시(등록된 글자 칸 다시 계산).
- Play: 아주 크게 = [소식] 33 → 43 · 부제 22 → 28(한 번만 커짐).
- **PreferredTextSize(로블록스 자체 글자 크기)**: 스크립트에서 읽기 전용(설정 시도 = "read only")이라 Studio Play에서 값을 바꿔 볼 수 없었다(지금 값 Medium). 겹침 방지 = 우리 배율과 곱하지 않고 **큰 쪽 하나**(`UiModel.textMul` - 하네스: 아주 크게 + Larger = 1.3 · 보통 + Largest = 1.5). 로블록스가 개발자 TextLabel까지 자동으로 키우는지는 실기기(설정 바꾼 폰)에서 확인 필요 → 판단 필요 표에 올림.

### 버튼 손맛(UiKit 한 곳 → 모든 v2 화면)
- 먼저 Play 확인(마우스): 기본 `Activated` = **버튼 밖에서 떼면 안 불림**(끌고 나가 떼기 0 · 제자리 1). 터치 · 스크롤 목록 끌기는 MCP로 흉내 불가 → 직접 판정으로 통일(00 prototype과 같은 규칙).
- 판정 = `shared/ButtonPress`(순수): 뗄 때만 · 밖으로 끌면 누름 풀림 + 떼도 0 · 다시 들어오면 누름 복귀 · 꾹 = 뗄 때 1번 · 스크롤 목록 안 8px 넘게 끌면 취소 · 전투(`mode = "instant"`) = 누르는 순간 · 비활성 = 흔들림만 · 확인 키(Enter · 게임패드 A, 선택된 버튼) = 같은 누름 모양.
- 겉 = `UiKit.attachPress`(상태 그림 normal/hover/pressed/disabled 교체 + UIScale + 내용 y +2 · 선택 테두리 = SelectionImageObject focus-ring) · `UiKit.button`(ImageButton 9-slice · kind pri/sec/danger/plate/primal/card/tab) · `UiKit.card`(btn-card) · `UiKit.closeButton`(btn-close + icon-x · 폰 [<] = 판 B + icon-back) · 빈 칸.
- Play(PC 1052×592): 누름 = pressed 그림 · 0.95 · 내용 +2 → 끌어 나감 = normal · 1.0 → 다시 들어옴 = pressed · 0.95 → 밖에서 뗌 = 설정 안 열림 · 안에서 뗌 = 설정 열림.
- 하네스 ui_v2: 밖에서 떼기 0 · 안에서 떼기 1 · 밖 → 안 복귀 1 · 꾹 1 · 스크롤 끌기 0 · 작은 흔들림 1 · 전투 즉시 1(뗄 때 추가 0) · 비활성 0 + 흔들림 · 확인 키 1.
- **UiKit 버튼을 안 쓰는 버튼**(옛 화면 · kit/Button 기반) = `Instance.new("TextButton"/"ImageButton")` 111곳 · 62파일(많은 순: Inventory/BulkSell 8 · ui/SlotWindow 5(옛 이어하기 - v2 스위치 끔 때만) · panels/Party 5 · Inventory/Shell 5 · Leaderboard 4 · StageSelectPanel 4 · Minimap 3 · WorldClient 3 · HelpTooltip 3 · ClassSelectUI 3 …) + 옛 공용 `ui/kit/Button`을 쓰는 37파일. 각 화면 묶음(02 HUD · 03 가방 · 04 ~)이 v2로 올 때 `UiKit.button` / `UiKit.attachPress`로 옮긴다. 메인 메뉴 v2 안에서 남은 것 = 폰 첫 실행 설정 문구 덮개(전체 화면 탭) · 옛 설정 · 소식 페이지(06 묶음 대기) · `UiKit.toggle`.

## UI2-3 01 메인 메뉴 v3(판정 반영 + 키 아트 초점 + 아이콘 v2)
캡처 = `claude-design-handoff\01_main-menu\v3\play\`(목업 이름 그대로 35장: pc_01 ~ 07 · phone_01 ~ 07 + 키 아트 6장 `keyart_<pc-16x9|pc-4x3|phone-19.5x9>_<closed|open>` + 글자 12장 `text-<1.0|1.3>_<pc|phone>_<main|continue|class-select>`). PC = Studio 뷰포트 1052×592(16:9) · 788×592(4:3) · 폰 = 844×390(19.5:9, ForceTouchLayout).

### checklist(01 v3 · 18항목)
| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 얼굴 · 초월 대검이 이어하기 창에 안 가려짐 | O | keyart_* open 3장 · 하네스(비율 6개 지킬 영역 ⊂ [창 끝, 화면]) |
| 2 | 왼쪽 위 로블록스 버튼 자리 비움 | O | 좌표 표 검사 · pc_01 · phone_02 |
| 3 | 폰 버튼 44 이상 · 글자 12 이상 | O | 하네스(폰 글자 13 이상 · 버튼 44) |
| 4 | 캐릭터 0개 → [시작하기] → 직업 선택 · [직업 선택] 숨김 | O | pc_01 → pc_06 · phone_02b → phone_06(새 계정 Play) |
| 5 | 마지막 캐릭터 맨 위 · 두 번 눌러 시작 · 같은 직업 2개만 ① ② | O(②는 하네스) | pc_03 · phone_03 |
| 6 | 보관 확인 첫 포커스 = [취소] · Enter = 취소 | O | pc_05 · phone_05 · Play: Enter 뒤 카드 4장 그대로 |
| 7 | 칸 꽉 참 → 구경 모드(띠 · 확정 비활성) | O | pc_07 · phone_07 |
| 8 | 설정 문구 1회 · 폰 탭 즉시 | O | pc_01b · phone_01(Studio는 Play마다 재시드라 매번 뜸) |
| 9 | 카드 무기 = 장착 무기 아이콘 | O | pc_03(+13 칩 · 등급 테두리) |
| 10 | 직업 선택 = 2D 전설 그림 · 이름 · 스킬 · 수치 = 데이터 | O | pc_06 · 스킬 칸 = 00 v2 스킬 아이콘(icon-skill-<직업>-<칸>) · 치유사 · 도적 = 자리표시 그림(phone_06b) |
| 11 | 카드 목록 ScrollingFrame · 폰 스크롤 | O | phone_03(스크롤바) |
| 12 | 아이콘 v2만(옛 흰 기호 없음) | O | 닫기 = btn-close + icon-x · [<] = 판 B + icon-back · ⋯ = 판 B + icon-more · 보관 · 정보 · 자물쇠 · 더하기 = v2 |
| 13 | 버튼 5상태(0.95 · 어둡게 · 입술 · 튀며 복귀) | O | Play 값 확인(UI2-2) |
| 14 | 밖으로 끌면 취소 · 목록 끌기 취소 | O | Play(마우스) + 하네스 |
| 15 | 게임패드 · 키보드 = 흰 선택 테두리 | O(부분) | SelectionImageObject = focus-ring · 확인 창 첫 포커스 = 테두리 보임(pc_05) · 게임패드 실기 확인 안 함 |
| 16 | 16:9 · 4:3 · 폰에서 얼굴 · 대검 안 가림(창 열려도) | O | keyart_* 6장 |
| 17 | 좁은 창에서 이어하기 열면 메뉴 숨김 · X로 복귀 | O(하네스) | 4:3은 우리 UI 배율(min)로 창 끝이 759px라 좁은 창 모드가 안 걸림(spec 계산은 UI 배율 1 가정) · 정사각에 가까운 창(1080×1000)에서 걸림(하네스) - Play 캡처 없음 |
| 18 | 글자 1.3배에서 카드 글자 잘림 없음 | O | text-1.3_* 6장(카드 높이 늘고 줄바꿈 · 목록 스크롤) |

### 판정 반영 · 고친 것
- 키 아트 = 01 v3 "키 아트 초점" 식 그대로(`first/MenuArtFit.place` · 값 = `MenuBootData.v2.keyArt` 초점 (850, 500) · 지킬 영역 (780, 400) ~ (1270, 770) · 여백 24): 하네스로 spec 결과값 X 385 · −59 · 281 · 271 일치. 두 장(L 0 ~ 770 · R 766 ~ 1536)은 원본 비율 부모 틀 하나에 붙어 있어 이음매 어긋남 없음. 창 오른쪽 끝 화면 px = 메뉴가 gui 속성으로 알려 줌(좌표 표 한 곳). 어두운 그라데이션 끝 = 빈 구역 왼쪽 − 24.
- **얼굴 잘림 원인**: ① L/R 따로 맞춤 = 아님(이미 한 틀) ② **가운데/오른쪽 붙임 기준 잘림 = 원인**(옛 v2 배치 = 높이 × 1.5 영역을 오른쪽에 붙임 → 좁은 비율에서 그림 왼쪽 22% 페이드 + 이어하기 창(창 끝 1012/1920)이 전사 쪽을 덮음) ③ 그라데이션이 화면 비율로 고정이라 좁은 창에서 얼굴 위까지 옴 → ②③ 모두 새 식으로 해결.
- 01 v3 좌표: 선택 카드 158 · 보관 확인 309 · 직업 정보 510/460 · 시작 버튼 918 · 폰 주 버튼 119 · 보관함 75 · [<] 18,64.
- 글자 1.3배 잘림 금지: 카드 줄 = 실제 글 높이(TextService)로 줄바꿈 · 카드 높이 늘림 · 창 아래 안내 글 = 위로 자람 · 직업 선택 시작 안내 = 위로 자람 · [직업 선택] 옆 "빈 칸 없음 · 구경"은 겹치면 숨김(같은 안내 = 직업 선택 띠).
- 등록 글자 칸 표가 약한 표(Instance 키)라 글자 크기 바꿀 때 일부 칸이 안 커지던 것 → 강한 표 + Destroying(기존 메모 "약한 인스턴스 키" 그대로).
- 접속 직후 첫 [이어하기]가 3 ~ 8초 걸림 = 서버 SlotRequest list 첫 답(프로필 로드 대기) → 그동안 주 버튼 부제 "캐릭터를 불러오는 중…" · 연타 막음 · 목록을 못 받으면 월드로 들어가지 않음(옛 = 실패 시 바로 입장).
- 같은 묶음 반영(옛 UI1F-1): 테스트 플래그 실서버 경고 · 소식 빨간 점 · 총 0시간 · 폰 뒤로 버튼 2곳(위 "UI1F-1 결과").

### 남은 것 · 판단
- 총 0시간: 캡처의 0시간 = Studio 재시드 테스트 데이터(코드 원인은 고침 - 위).
- 4:3 좁은 창 모드 Play 캡처 없음(우리 UI 배율에서는 1440×1080에서 안 걸림 - 의도와 다르면 판단 필요 표로).

## UI2-4 02 HUD v5
캡처 = `claude-design-handoff\02_hud\v5\play\`: `pc_01_normal` · `pc_03_more-menu` · `phone_01_normal` · `phone_04_more-menu`(PC = Studio 1052×592 · 폰 = 844×390 ForceTouchLayout). 보스전 · 공중 · 1.3배 캡처는 아직 없음(아래 남은 것).

### 구조
- 메뉴 = 새 `client/hud/HudMenuV2`(항목 `shared/data/HudData` · 좌표 `UiLayoutData.hud` · 버튼 = UiKit 판 B 9-slice · 귀환 = 둥근 판 · 손맛 공통). 옛 `hud/MenuBar` = 스위치 `HudData.menuV5`(파일 그대로).
- 키 칩 = `PanelRegistry.hotkeyOf` · 귀환 = `actionKey("hubReturn")` → G C U M N J K P L B 그대로(Play 캡처). 코드에 "키" 글자 없음(소스 검사).
- 보상 작은 창 = 출석(panels/Attendance) · 시즌 출석판(panels/SeasonBoard) · 선물함(서버 `GiftPending` 속성 + ShopRequest `giftOpen` = 기존 선물 창 다시 띄움). 점 판정 = `shared/RewardHub`(출석 판정은 Attendance가 같은 함수를 씀). 기존 경로(자동 출석 창 · 상점 시즌 탭 · 접속 선물 창 · 상점 추천 탭 선물 줄) 그대로.
- 환생: **창이 아니라 마을 제단**(RebirthAltarPrompt → Confirm → RebirthRequest) + 강화 창 [환생] 안내 탭. 옛 메뉴에도 환생 버튼은 없었음 → "환생 가능" 알림 ④ 추가(서버 조건과 같은 판정 `RewardHub.rebirthReady`). 진입 경로 4개 = 소스 검사 `hud_v5_static`.
- 귀환 = WorldClient 동작(시전 · 취소 · 쿨) 그대로 HUD 둥근 판에 연결 · 옛 귀환 버튼 숨김.
- 펫 = 알 · 펫 창(panels/EggInfo · 옛 = 설정 칩 옆 [알] 칩). 설정 칩은 v5에서 숨김(설정 · 펫 = 더보기).
- 메인 퀘스트 = 오른쪽 위 칩 스택 바로 아래 · 미니맵(켰을 때) = PC (1316, 20, 180) · 파티원 = PC (24, 704) / 보스전 (24, 472) / 폰 (10, 87).
- 스킬 칸 그림 = 00 v2 스킬 아이콘(데이터 `SkillIconData.images` → v2 · 옛 = `imagesV1`) · 대시 = icon-dash.
- 잠긴 스킬 칸 말풍선 = `hud/SkillLockV2`(PC 마우스 올림 · 폰 누름 → "환생 N에서 열림" 1.5초 · 누름 = 흔들림).

### checklist(02 v5 · 21항목)
| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 폰 조이스틱 영역에 버튼 · 파티원 없음 | O(데이터) | 하네스(전투 버튼 · 위 줄 · 조이스틱) |
| 2 | 폰 전투 버튼 = v2 좌표 · 간격 8 | **X → 판단 필요 1** | 좌표 데이터 + 하네스(최소 간격 8 · 끝 8) O · 게임 적용은 안 함 |
| 3 | 메뉴 아이콘 v2 · 판 크림 · 폰 44 식별 | O | pc_01 · phone_01 |
| 4 | 폰 위 줄 = 가방 · 보상 · 더보기 · 더보기 첫 줄 = 구역 · 수련 · 성장 · 퀘스트 | O | phone_01 · phone_04 |
| 5 | 공격 버튼 = 현재 직업 무기 | O(UI-0 그대로) | 기존 |
| 6 | 파티원 2 ~ 4인만 · 쓰러짐 · 보스전 | 자리만 v5 | 파티 Play 캡처 없음(혼자 Play) |
| 7 | 퀘스트 PC 상시 · 폰 접기 · 보스전 숨김 | 부분 | 상시 · 보스전 접힘 = 기존 동작 · 폰 접기 버튼은 기존 칸 그대로 |
| 8 | 점프 점 · 활강 링 = 쓸 때만 | 기존 | 바꾸지 않음 |
| 9 | 잠긴 칸 = "환생 N에서 열림" | O(데이터 0 = 잠긴 칸 없음) | 판단 필요 2 |
| 10 | 키 칩 = 게임 키 | O | pc_01(G C U M N J B · 더보기 P K L) |
| 11 | 전투 = 누를 때 · 일반 = 뗄 때 · 밖으로 끌면 취소 | O | 메뉴 = UiKit 손맛 · 전투 버튼은 기존 입력 그대로 |
| 12 | 옛 흰 기호 아이콘 없음 | O(메뉴) | 스킬 칸 · 칩 스택은 기존 그림(아래) |
| 13 | Q/E/R/T = 직업 스킬 아이콘 · T 금 고리 | O(그림) | 데이터 교체 · T 틀은 기존 궁극기 버튼 |
| 14 | 1.3배: 퀘스트 두 줄 · 체력 숫자 · 잠긴 칸 숫자 | 해당 없음 | HUD(체력 · 퀘스트)는 옛 Theme 글자 = 글자 크기 설정 밖(새 화면만 곱함) |
| 15 | 전투 HUD 빨강 = 알림 점 + 보스 막대만 | O(메뉴) | 소스 검사(메뉴 빨강 = 점만) |
| 16 | 메뉴 = 실제 창 · 키 = 게임 키 | O | 소스 검사(창 id 10개 = PanelRegistry) |
| 17 | 오른쪽 열이 재화 · 퀘스트 · 알림 · 미니맵과 안 겹침 · 보스전 숨김 | O | pc_01(작은 창에서는 열이 퀘스트 칸 아래로 내려가며 간격 · 이름표 줄임) |
| 18 | 보상 점 = 받을 것 있을 때만 · 상점 압박 없음 | O | 하네스 5 + Play(출석 · 시즌판 점) |
| 19 | 귀환 = 둥근 판 | O | pc_01 · phone_04 |
| 20 | 잠긴 칸 말풍선 | O(코드) | 잠긴 칸이 데이터상 없어 화면 확인 못 함 |
| 21 | HUD 직접 배치 유지 · 리셋 | **해당 기능 없음 → 판단 필요 3** | |

### Play에서 본 3건(사용자 관찰)
- 키 칩 "키" 글자: 코드에 "키" 고정 글자 없음 - v5 메뉴는 실제 키(G C U M …). 이전 캡처의 "키"는 목업 쪽이었을 가능성.
- PC 오른쪽 위 재화 · 스테이지 · 퀘스트가 안 보임: **원인 = 창 비율 + 옛 칩 스택이 기준 해상도 배율 밖**(작은 창에서 오른쪽 메뉴 열과 겹쳐 가려짐). 고침 = 칩 스택 · 퀘스트 칸에 기준 배율(하한 0.75) · 메뉴 열을 퀘스트 칸 아래로.
- 알림 띠 아이콘 = 등급색 원 자리표시: 지금 알림 띠(Toast)는 아이콘이 없다(글자 색만 등급). 원 자리표시는 목업 그림 - 알림 아이콘 그림은 다음 묶음 몫.

### 남은 것
- v5 오른쪽 위 2줄(재화 + Lv / 스테이지 · 지역) 재구성 안 함 - 옛 칩 스택(재화 · Lv/CP · 스테이지 · 최고 기록) 그대로 + 지역 이름 표 따로. 
- 캡처: 보스전(pc_02 · phone_02) · 공중(pc_04 · phone_03) · 전 서버 배너(pc_05) · 1.3배(phone_05) - 다음 Play 묶음에서.

## UI2-3 보정(중간 보고 판정 10-05)
1. 좁은 창 모드 조건 = 키 아트(얼굴 · 대검) 가림 **또는** 왼쪽 묶음(펼친 메뉴 · 제목 글 끝) ↔ 이어하기 창 간격 < `UiLayoutData.mainMenu.pc.narrowMinGapPx`(24 화면 px). 좁은 창 모드 창 = 화면에서 16:9일 때와 같은 크기(창 UIScale = 화면 높이 배율 ÷ 지금 배율) · x 24.
   - 4:3(788×592): 좁은 창 모드 켜짐 → `keyart_pc-4x3_open_v2`(메뉴 숨김 · 창 왼쪽 · 얼굴 · 대검 보임) · `keyart_pc-4x3_closed_v2`.
   - 16:9에서 글자 1.3배: 제목이 커져 간격 < 24 → 같은 규칙으로 좁은 창 모드(`text-1.3_pc_continue_v2`). 보통 글자 16:9 = 옛 배치 그대로.
2. 카드 줄바꿈 = 덩어리 단위(`UiModel.wrapChunks` - 덩어리 구분 = 글 데이터의 두 칸 띄움): "1분 전" · "최고 스테이지 46" · "환생 4회"가 안 끊김(하네스 3 + 캡처).
3. PreferredTextSize = 큰 쪽 하나 유지(실기기 = 출시 전 사용자).
4. 재캡처 = `_v2` 3장(옛 파일 그대로).
- 남은 것: 좁은 창 모드에서 창 배율(K)과 글자 하한 보정(0.75)이 겹쳐 글자가 16:9보다 약간 크게 보임(잘림 없음) - 필요하면 보정 기준을 창 배율 포함으로.

## UI2-5 03 가방 · 장비 + 보석 홈 v2(1차)
캡처 = `claude-design-handoff\03_bag-equip\v2\play\`: `pc_01_bag-35-weapon` · `pc_05_gem-sockets`(PC 1052×592).

### 이미 맞던 것(조사 · 코드 변경 없음)
- 칸 수 = 데이터: 기본 35(`SaveConfig.bagBaseSlots`) · 가방 확장 패스 +20 · 스타터 +20(`MonetizationData`) · 상한 75(+ 이정표 칸).
- 일괄 판매 · 분해 등급 = `ArmorData.bulkSellGrades`(일반 · 희귀 · 영웅 · 전설 이상은 하나씩) · 가방 화면 [분해] [판매] = 보조색(빨강 아님 - 판매 확인 창의 [팔기]만 빨강 = 확인 창 안 규칙 그대로).
- 상세: 장착 중 비교 ▲ ▼ · 잠금 토글(태초 · 초월 두 번 확인) · 태초 각인 카드 · [각성](태초 · 초월만).
- 보석 홈 무기 그림 = 장착 무기 아이콘(`icons/weapons/<직업>_<등급>`) · 홈 열림 = 환생 1 ~ 5 · 상한 = `GemData.slotGradeCap`.
- **"꽉 차면 새 장비는 바닥에 남음" = 실제 동작과 같음**(ItemDropServer: 줍기 실패 → 드랍은 땅에 남아 수명까지 · 칸 비우고 다시 지나가면 주움 · 자동 정리를 켜면 가득이어도 처리 · 태초 · 초월은 칸을 넘겨도 들어옴). 문구 변경 필요 없음 - 게임 안 토스트 = "인벤토리가 가득 찼습니다 - 땅에 있는 아이템을 주울 수 없습니다".

### 바꾼 것
- 보석 아이콘 2겹: 몸통(등급 `gem-body-*`) + 문양(종류 `gem-mark-*` · 직업 스킬 보석 = class) - `GemData.iconBodyByGrade` · `iconMarkByOption` → `ItemIcons.gem` 한 곳(옛 한 장 키 · 등급색 원 = 그대로 대체). 보석함 칸 · 홈 칩 크기 키움. 하네스 gem_home +2(영웅 이상 × 모든 옵션 = 몸통 + 문양 그림 있음).
- 가방 PC 칸 88 · 간격 10 · 최대 7열(작은 창 = 들어가는 만큼) · 폰 그대로(78 · 화면 폭) · 창 최대 1600 × 880 · 3구역 312 / 500(넓을 때).
- 확장 안내 = 목록 끝 작은 글자 버튼 "가방 칸 +20 · 가방 확장 패스 ›"(패스 없을 때만 · 상점 편의 탭) - 서버 스냅샷 `bagPass`(필드 추가 · 저장 아님).
- 잠긴 홈 문구 = "환생 N에서 열림".
- HUD v5 메뉴 열과 겹침 방지: 큰 창(가방)이 왼쪽 · 오른쪽 메뉴 열 사이에 놓임(`UIManager.hudReserve`).

### 남은 것(다음 묶음 작업 - 판단 아님)
- 03 v2 겉모습 전체 재구성(칸 = 06 칸 틀 9-slice · 탭 6 그림 · 보석 홈 무대 1000×560 + 반원 홈 5 + ViewportFrame 회전 무기 · 폰 분해 = 아래 시트 · 1.3배 폰 가방)은 아직 - 지금 = 옛 가방 화면 + 위 바꾼 것. 캡처 7장(pc_02 ~ 04 · 06 · 폰 5) 남음.
- 보석 홈 무기 = 512 렌더 아님(장착 무기 아이콘 그림) - "이전 결정"의 512 렌더 원본이 저장소에 없음(icons/weapons = 아이콘 크기) → 확인 필요.

## TEXT-FULL 축약어 → 풀네임(추가 10-05)

원칙: 화면 글자 축약 금지 · 글자 키 id는 그대로 · 값만 바꿈. 찾는 법 = 스크래치 스캐너(`roblox/src` 모든 .lua의 문자열 값 · 주석 · 검증/개발 로그 제외)로 축약어 목록 검색 + 화면 확인.

### 바꾼 것(65곳)

| 파일 | 키 | 옛 글자 | 새 글자 |
|---|---|---|---|
| TextData.lua | `inv.cmp.stat.shoes` | 이동 · 공속 | 이동 속도 · 공격 속도 |
| TextData.lua | `transcendent.special.frenzy` | 이속 · 공속 +{speed}% · 대시 쿨 −{dash}% | 이동 속도 · 공격 속도 +{speed}% · 대시 쿨타임 −{dash}% |
| TextData.lua | `transcendent.special.soar` | (쿨 {cd}초) | (쿨타임 {cd}초) |
| TextData_inv.lua | `gear.gem.valueCrit` | 치확+{rate}%p 치피+{dmg} | 치명타 확률 +{rate}%p · 치명타 피해 +{dmg} |
| TextData_inv.lua | `gear.gem.valueCrit` | Crit +{rate}% · Crit DMG +{dmg} | Critical Hit Chance +{rate}% · Critical Damage +{dmg} |
| TextData_shared.lua | `desc.item.critRate` | 치확 {value}%p | 치명타 확률 {value}%p |
| TextData_shared.lua | `desc.item.critDmg` | 치피 {value} | 치명타 피해 {value} |
| TextData_shared.lua | `desc.item.meta.shoes` | 이동+공속 +{value}% | 이동 속도 · 공격 속도 +{value}% |
| TextData_shared.lua | `desc.cmp.base.shoes` | 이동+공속 +{value}% | 이동 속도 · 공격 속도 +{value}% |
| TextData_shared.lua | `desc.skill.label.expected` | Est. DMG | Expected Damage |
| TextData_shared.lua | `desc.skill.label.crit` | "Crit" | "Critical Hit" |
| TextData_shared.lua | `desc.skill.label.finalDmg` | Final DMG | Final Damage |
| TextData_shared.lua | `desc.skill.critInfo` | Crit chance {rate} · Crit damage ×{dmg} | Critical Hit Chance {rate} · Critical Damage ×{dmg} |
| TextData_shared.lua | `desc.skill.dmg` | Crit {crit} | Critical Hit {crit} |
| TextData_shared.lua | `desc.skill.dmgMulti` | Crit {crit} | Critical Hit {crit} |
| TextData_shared.lua | `desc.skill.dash.effect` | Crit chance +{crit} | Critical Hit Chance +{crit} |
| TextData_shared.lua | `desc.skill.heal.shield` | Crit ×{crit} | Critical Hit ×{crit} |
| TextData_shared.lua | `desc.skill.heal.amount` | Crit ×{crit} | Critical Hit ×{crit} |
| TextData_shared.lua | `desc.skill.crit.summon` | Crit chance over 100% gives crit damage +{bonus} | Critical Hit Chance over 100% gives Critical Damage +{bonus} |
| TextData_shared.lua | `desc.item.critRate` | Crit {value}% | Critical Hit Chance {value}% |
| TextData_shared.lua | `desc.item.critDmg` | Crit DMG {value} | Critical Damage {value} |
| TextData_shared.lua | `desc.item.meta.shoes` | Move+Atk Speed +{value}% | Move Speed · Attack Speed +{value}% |
| TextData_shared.lua | `desc.cmp.base.shoes` | Move+Atk Speed +{value}% | Move Speed · Attack Speed +{value}% |
| TextData_en.lua | `inv.axis.finalDamage` | Final DMG | Final Damage |
| TextData_en.lua | `inv.axis.crit` | "Crit" | "Critical" |
| TextData_en.lua | `inv.axis.healingPower` | "Regen" | "Regeneration" |
| TextData_en.lua | `inv.cmp.stat.shoes` | Move · Atk Speed | Move Speed · Attack Speed |
| TextData_en.lua | `nameplate.mob.stats` | ATK {attack} | Attack {attack} |
| TextData_en.lua | `item.critOverflowNote` | Crit chance over 100% | Critical Hit Chance over 100% |
| TextData_en.lua | `stat.critRate` | Crit Chance | Critical Hit Chance |
| TextData_en.lua | `stat.critDmg` | Crit Damage | Critical Damage |
| TextData_forge.lua | `forge.inherit.stat.critRate` | Crit Rate | Critical Hit Chance |
| TextData_forge.lua | `forge.inherit.stat.critDmg` | Crit DMG | Critical Damage |
| TextData_hud.lua | `hud.party.buffChip` | ✚ DMG +{pct} | ✚ Damage +{pct} |
| TextData_names.lua | `위력` | ["치명"] = "Crit" | ["치명"] = "Critical" |
| TextData_names.lua | `위력` | ["재생"] = "Regen" | ["재생"] = "Regeneration" |
| TextData_panels.lua | `ui.class.row` | ATK {atk}x / DEF {def}x / SPD {speed}x | Attack {atk}x / Defense {def}x / Speed {speed}x |
| TutorialData.lua | `83행` | 신발(이동+공속%) | 신발(이동 속도 · 공격 속도 %) |
| TextData_shared.lua | `desc.skill.desc.dash` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.desc.summon` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.desc.toggle` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.dash.effect` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.dash.dmg` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.toggle.effect` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.act.dash` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.crit.basic` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.final.arrow` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.final.basic` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.healMode.off` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.rule.circle` | 평타 | 기본 공격 |
| TextData_shared.lua | `desc.skill.rule.dash` | 평타 | 기본 공격 |
| TextData.lua | `item.critOverflowNote` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData.lua | `stat.critRate` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData.lua | `stat.critDmg` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_forge.lua | `forge.inherit.stat.critRate` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_forge.lua | `forge.inherit.stat.critDmg` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_shared.lua | `desc.skill.critInfo` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_shared.lua | `desc.skill.dash.effect` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_shared.lua | `desc.skill.crit.summon` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| TextData_shared.lua | `desc.skill.rule.selfBuff` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| SkillIconData.lua | `35행` | 치명 확률 / 치명 피해 | 치명타 확률 / 치명타 피해 |
| SkillIconData.lua | `short.dualblade.q` | 확정 치명을 | 확정 치명타를 |
| SkillIconData.lua | `short.dualblade.r` | 치명 확률 | 치명타 확률 |
| SkillIconData.lua | `short.healer.e` | 평타가 | 기본 공격이 |
| TextData_shared.lua | `desc.skill.summon.effect 외 2` | 확정 치명 | 확정 치명타 |

### 그대로 둔 것(판단 근거)
- 옵션 · 보석 고유 이름(위력 · 신속 · 치명 · 건강 · 방어 · 성장 · 재생 · 흡혈 / en Might · Haste · Vitality · Guard · Growth · Lifesteal) = 축약이 아니라 이름. 단 en `Crit` · `Regen`은 영어 낱말 축약이라 `Critical` · `Regeneration`으로 바꿈.
- 게임 단위 HP · Lv · EXP · CP · Gold·EXP = 장르 공용 단위 표기(풀어 쓰면 칸에 안 들어감) → 유지. 바꾸려면 판단 필요.
- 딜링모드 · 딜러 = 치유사 모드 · 파티 역할 이름(고유 명칭) → 유지. 쿨타임 · 쿨다운 = 낱말 그대로(“쿨” 단독만 쿨타임으로).
- 보상 아이콘 그림이 없을 때 쓰는 대체 글자(RewardIcons SHORT = G · EXP · 석 · 권 · ES · RT) = 그림 자리표시(ART-AUDIT 대상) → 유지.
- 개발 로그 · 검증 문장 · 운영 도구 문구(DevTools · *Verify · MovementConfig.moveGuard.legal 검증 출력) = 플레이어 화면 아님 → 유지.

### 잘림 확인(Play)
- 장비 상세 카드 "착용 중 옵션: 치명타 확률 … · 치명타 피해 …" 줄이 PC에서 …로 잘림 → **DetailCard 글 줄 = 줄바꿈 + 높이 = 글 높이**(다시 축약 안 함 · 옛부터 잘리던 "분해 시 … 판매 시 …" 줄도 같이 해결). 캡처 `claude-design-handoff\_audit	ext-full\pc_detail_compare.png`(상세 + 비교 툴팁).
- 폰(DebugInventoryScreen 800×302): 아래 시트 상세 줄 잘림 없음 `phone_detail_sheet_debug-screen.png`. 캐릭터 창 상세 능력치(치명타 확률 · 치명타 피해 · 공격 속도 · 이동 속도) TextFits 전부 O `pc_character_stats.png`.
- **1.3배**: 장비창 · 캐릭터 창 · 비교 툴팁은 옛 `ui/kit/Theme.textSize` 글자라 설정 "글자 크기"(textScale)가 곱해지지 않는다(UiKit v2 화면만 곱함 - UI2-4 보고와 같은 사실). 즉 지금 1.3배에서도 위 1.0 화면과 같다. 이 창들을 v2 글자로 옮기는 일 = UI2-5 2-4(1.3배 폰 가방)에서.

## MULT-PCT 배율 표시 → %(추가 3 · 10-05)

표기 함수 한 곳 = `shared/NumberFormat.multiplier(v)`: ×1.01 → "+1%" · ×1.5 → "+50%" · ×0.97 → "-3%" · ×1 → "+0%" · 소수 한 자리(끝 0 버림) · **×10 이상 = × 그대로**(×12.5 · ×1,234). 계산 값은 그대로(표시만).

| 파일 | 자리 | 옛 표시 | 새 표시 |
|---|---|---|---|
| client/panels/Character.lua | 캐릭터 창 줄 "레벨 이정표 배율"(MilestoneMultiplier) | ×1.00 | +0% |
| client/panels/Character.lua | 상세 능력치 합계 format mult(공격 속도 · 이동 속도 · 경험치 획득 = StatSheetData) | ×2.50 · ×1.50 · ×1.01 | +150% · +50% · +0.7% |
| client/panels/Character.lua | 출처 분해 kind mult | ×n | +n% |
| shared/EquipCompare.lua | 장비 비교 무기 배율(multText) | ×1.85 / ×1.2K | +85% / ×1.2K(10 이상 ×) |
| client/panels/Enhance/RebirthView.lua · client/RebirthAltar.client.lua + TextData `rebirth.tab.status` · `rebirth.confirm.body`(ko · en) | 환생 경험치 배율 | 경험치 ×1.5 → ×2 | 경험치 +50% → +100% |
| client/panels/Enhance/TranscendView.lua + TextData_forge `transcend.enh.effectMult`(ko · en) | 초월 강화 공격력 | ×1.25 · 성공하면 ×1.31 | +25% · 성공하면 +31% |
| client/panels/Shop/ConvenienceTab.lua · Catalog.lua + TextData `shop.pass.pickupRadius.desc` · `shop.pass.recallCooldown.desc`(ko · en) | 편의 패스 효과 | 반경 ×1.5 넓어짐 · 대기 ×0.5 줄어듦 | 반경 +50% · 대기 -50% |

그대로 둔 것(예외 · 판단 근거):
- 비용 배수: 강화 방지 "비용 ×{k}" · 방지 켬(×k)(지시 예외).
- 초월 계승 "공격력 ×{mult} · 지금의 {mult}배"(`transcend.inherit.*`) = 무기 교체 환산 비율(보너스가 아님) → ×.
- 스킬 설명 공식(`desc.skill.*` ×{mult} · ×{cap} · 이동 속도 ×{move} 등) = 계산식 설명 → ×. 바꾸려면 판단 필요.
- 확률 표 가중치(Probability ×%g) · 묶음 개수(Toast ×n) · 보스 기둥 개수 = 배율 아님.
- `moveUnlock.reward.4` 공중 대시 ×{mult} = 횟수 배수 → ×.
- 옵션 · 세트 · 수련 · 펫 표시는 이미 +n%(배율 표시 없음 - 확인함).

캡처: `claude-design-handoff\_audit\text-full\mult-pct_pc_character.png` · `mult-pct_pc_character_breakdown.png` · `mult-pct_phone_character.png`(ForceTouchLayout 800×361) - 잘림 0(TextFits 전부 O). 1.3배 = 캐릭터 창은 옛 Theme 글자라 설정 배율이 안 걸린다(TEXT-FULL 절과 같음).

추가(TEXT-FULL 보충): 스킬 설명 ko "치명 ×{crit}" · "치명 굴림" · "치명이면" · "1타 … 치명 {crit}" → "치명타 …"(TextData_shared 5곳).

## 세계 번호 확인(읽기 전용 · 10-05)

| 무엇 | 태초 | 초월 | 사용자 결정(09-29) | 같음? |
|---|---|---|---|---|
| 세계 번호 발급(`PrimordialRegistry.claim` → `nextNumber` - DataStore 카운터) | **받음**(PrimordialData.counterKey) | 받음(TranscendentData 별도 카운터) | 초월부터 | **다름** |
| 전 서버 알림(MessagingService 토픽 · 배너 · 채팅) | 없음 | 있음(`DropNoticeData.globalGrades = { transcendent = true }`) | 초월부터 | 같음 |
| 같은 서버 알림(`announceLocal` = 그 서버 전원 배너) | 있음 | 있음 | 태초 = 같은 서버만 | 같음 |
| 명예의 전당 최근 목록 · 칭호 | 없음(global만) | 있음 | - | - |
| 장비 상세 각인 칩 "세계 N번째 태초 · 날짜" | 보임(번호 있음) | 보임 | - | - |

→ **차이 1건: 태초도 세계 번호(태초 전용 순번)를 받는다.** 지시대로 코드는 바꾸지 않았다. 바꾸려면 결정 필요: ① 태초 번호 발급 끄기(각인 칩 문구 · 03 v2 목업 "세계 N번째 태초"도 같이 바뀜) ② 지금대로 두기(태초 = 번호는 있고 알림만 같은 서버).

## 메모(추가 3 · 3번)
- 성장(캐릭터) 창 왼쪽 = 로블록스 아바타 대신 직업 전설 일러스트(직업 선택과 같은 그림 · 치유사 · 도적 자리표시) → 08 v3 묶음이 오면 구현(지금은 안 함).
