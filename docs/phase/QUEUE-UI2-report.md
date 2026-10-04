# QUEUE-UI2 보고서(새 디자인 묶음 적용 - 2026-10-05)

> 지시 = 사용자 메시지(QUEUE-UI2) · 상태 = `QUEUE-UI2-state.md` · 기준 = `docs/design/handoff/00_design-system/v1` · `01_main-menu/v2` · `02_hud/v3` · `03_bag-equip/v1`.
> Play 캡처 = `C:\Users\xkrgh\vibe\claude-design-handoff\<묶음>\play\`(저장소 밖).

## 판단 필요(맨 위)
1. **좁은 창 모드 기준**(01 v3): spec 식은 UI 배율 1(창 끝 1012px)을 가정해 4:3 1440×1080에서 좁은 창 모드가 켜지는데, 우리 루트는 배율 min(가로, 세로)라 4:3에서 창 끝이 759px → 빈 구역이 넓어 모드가 안 켜지고 얼굴도 안 가려짐(keyart_pc-4x3_open). 지금 = "실제 창 끝 화면 px" 기준(가림 없음이 목적). spec 그대로(가로 1577 미만이면 무조건 좁은 창)를 원하면 데이터 한 줄.
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
