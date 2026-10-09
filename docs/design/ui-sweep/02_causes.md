# 원인 조사 — 오른쪽 아래 잘림 · 아이콘 작음 · 맵 옛 아이콘 · 보스 검은 실루엣

표기: **[확인]** = 코드 또는 Studio 실측으로 확인 · **[추정]** = 엔진 동작 · 런타임 값에 기댄 판단. 경로 = `roblox/src` 기준.

## 1. 오른쪽 아래 잘림 · 아이콘이 너무 작음

### 결론
- 잘리는 곳 = **HUD 오른쪽 메뉴 열(구역 · 퀘스트 · 보상 · 상점 · 귀환)의 맨 아래 칸과 그 이름표 · 키 칩**, 그리고 그 아래로 펼쳐지는 보상 작은 창.
- 아이콘이 작은 건 **설정 때문이 아니다**. 메뉴 아이콘이 1920×1080 기준 배율을 그대로 따라 줄고 하한이 없기 때문(글자만 0.75 하한).

### 원인 표

| # | 원인 | 근거 | 구분 |
|---|---|---|---|
| 1 | `HudMenuV2Gui`만 `IgnoreGuiInset = true`인데, 오른쪽 열 정렬(`fitRight`)이 오늘의 목표 칸 아래 끝에 상단 인셋(58)을 더한 뒤 `rightRoot.frame.AbsolutePosition.Y`를 뺀다. 이 GUI의 AbsolutePosition.Y가 **−58**로 읽혀 열이 그만큼 더 내려간다 | hud/HudMenuV2.client.lua:297 · **Studio 실측: `HudRight.AbsolutePosition = (0, −58)` · 귀환 버튼 아래 끝 화면 y 578 / 뷰포트 592(16:9 1052×592)** | **[확인]** |
| 2 | `fitRight`의 남는 높이(`room = 1080 − 24 − top`)에 **마지막 칸 아래 이름표 높이가 빠져 있다** → 마지막 버튼이 바닥에 닿으면 이름표가 화면 밖 | HudMenuV2:291-309 | [확인] |
| 3 | 칸 하한 56 · 간격 하한 10 → 5칸 최소 320(기준 px). 위에서 밀려 `top > 736`이면 열 아래쪽이 화면 밖 | HudMenuV2:291-309 · UiLayoutData:91 | [확인] |
| 4 | 배율 기준이 셋으로 갈린다: 메뉴 = 전체 뷰포트 `s` · 칩 · 오늘의 목표 · 미니맵 = 인셋 공간 `max(s, 0.75)` · 스킬 줄 · T 칸 · 체력바 = 고정 px. 칩 · 퀘스트 칸이 메뉴보다 덜 줄어 오른쪽 열을 더 아래로 민다 | StageUI:62 · TodayGoal:102 · Minimap:411 · SkillSlots:45-52 | [확인] |
| 5 | 글자 크기 설정(보통 1.0 · 크게 1.15 · 아주 크게 1.3)은 **글자에만** 곱해져 이름표만 커진다 → 원인 2를 키운다 · 아이콘 · 칸 크기 설정은 없음 | UiTokens:63-64 · data/SettingsData:31 · UiModel:138-150 | [확인] |
| 6 | 폰 판정이 둘: 메뉴 = `TouchEnabled and not KeyboardEnabled`(Theme:39-45) · 스킬 줄 = `TouchEnabled`만(SkillSlots:108-113). **터치 + 키보드 기기**는 메뉴가 PC 배치(1920 기준 · 작은 화면에서 배율 ~0.33)라 매우 작고, 스킬 줄은 폰 배치 | 코드 | [확인] |
| 7 | `ScreenInsets` · `ClipToDeviceSafeArea` · `SafeAreaCompatibility`를 정한 GUI 0개 · HudMenuV2만 노치 영역까지 그림 | 저장소 전체 grep | [확인] / 노치 그림은 [추정] |
| 8 | 폰 전투 버튼 좌표 데이터(`UiLayoutData.hud.phone.combat`)를 읽는 코드가 없다 · 점프 버튼 자리를 계산식으로 흉내(실제 `TouchGui.JumpButton` 안 읽음) | UiLayoutData:121-130 · SkillSlots:96-103 · 566-586 | [확인] |

### 계산(화면 px · 상단 인셋 58 가정 · 이름표 ≈ 글자 + 4)

| 화면 | 메뉴 배율 s | 퀘스트 칸이 없을 때 오른쪽 열 끝 / 이름표 끝 | 퀘스트 칸 3줄일 때 이름표 끝(인셋 이중) | 판정 |
|---|---|---|---|---|
| 1920×1080 | 1.0 | 784 / 808 | ≈ 998 | 안 잘림 |
| 1366×768 | 0.711 | 557 / 575 | **767(보통) · 771(아주 크게)** | 아주 크게면 잘림 · 보통도 1px 남음 |
| 800×360 PC 배치(터치 + 키보드 · 작은 창) | 0.333 | 261 / 270 | 열 끝 427 > 360 | **보상 · 상점 · 귀환 칸 화면 밖** |
| Studio 16:9 축소(1052×592 · 실측) | 0.548 | - | 귀환 버튼 아래 578 · 키 칩 "B"가 화면 끝에 걸림 | 캡처 `cap/pc169_02_hud_hub.jpg` |

### 아이콘 실제 크기(px)

| 요소 | 기준 | 1920×1080 | 1366×768 | 800×360 PC 배치 | 폰(800×360) |
|---|---|---|---|---|---|
| 메뉴 버튼 / 안 아이콘 | 72 / 56 | 72 / 56 | 51 / **39.8** | 24 / **18.7** | - |
| 귀환 둥근 판 아이콘 | 43 | 43 | 30.6 | 14.3 | - |
| 더보기 칸 | 49 | 49 | 34.8 | 16.3 | 34(폰 위 줄) |
| 키 칩 | 20 | 20 | 14.2 | 6.7 | 없음 |
| Q/E/R 스킬 아이콘(고정) | 37 | 37 | 37 | 37 | 37 |
| 미니맵 | 180 | 170 | 118 | **50**(하한 64 미적용) | 96 |
| 메뉴 이름표 글자 | 16 | 16 | ≈ 12 | 12 | - |

→ 같은 화면 안에서 메뉴(배율 따름)와 스킬 줄(고정 px)의 크기 비율이 해상도마다 달라진다(1366×768에서 메뉴 아이콘 40 · 스킬 아이콘 37).

## 2. 맵 · 월드의 옛 아이콘 목록

공통 [확인]: 지도 핀 = `icons/ui/pin_*`(지도 v1)를 `ArtImage.get("icons/ui/"..이름)`으로 직접 부름(WorldMapPanel:102 · Minimap:73) — **UiIconData(v2 표)를 거치지 않음**. ArtAssetIds에 `ui/ds/pin-*` · `ui/ds/mark-*` 키는 없음(새 아이콘 = 아직 없음 → Claude Design에 요청).

| # | 쓰는 곳 | 지금 키(이미지 id) | 바꿀 새 이름(제안) |
|---|---|---|---|
| 1 | 내 위치 — WorldMapPanel:451 · Minimap:186 · 범례 :577 | `icons/ui/pin_player`(104419202762902) · 없으면 "▲" | `ui/ds/pin-player` |
| 2 | 허브 · 시설(대장간 외) — WorldMapPanel:56 · 60 · Minimap:101 | `icons/ui/pin_hub`(106883060378679) | `ui/ds/icon-home` 재사용 또는 `ui/ds/pin-hub` |
| 3 | 대장간 — WorldMapPanel:60 · Minimap:102 | `icons/ui/pin_forge`(78649378066202) | `ui/ds/pin-forge` |
| 4 | 보스 관문 — WorldMapPanel:75 · Minimap:109 | `icons/ui/pin_gate`(124064536995290) | `ui/ds/pin-boss-gate` |
| 5 | 캠프 · 체크포인트 — WorldMapPanel:70 · 83 · Minimap:116 | `icons/ui/pin_checkpoint`(72198989981613) | `ui/ds/pin-checkpoint` |
| 6 | 사냥터 · 퀘스트 목적지 · 도감 — WorldMapPanel:72 · Minimap:175 · CodexV2/Detail:78 | `icons/ui/pin_quest`(125025406801795) | `ui/ds/icon-quest` 재사용 또는 `ui/ds/pin-quest` |
| 7 | 사용자 핀 — WorldMapPanel:352 · Minimap:121 | `icons/ui/pin_user`(92708795814700) · 월드 = 보라 원기둥(MapPins:24-33) | `ui/ds/pin-user` |
| 8 | 파티원 — Minimap:587-602 | 색 점(`icons/ui/pin_party` 업로드만 · 안 씀) | `ui/ds/pin-party` 또는 색 점 유지 |
| 9 | 도전 기사(보스) — HubServiceData:14 | `icons/ui/pin_boss`(96813412450294) | `ui/ds/pin-boss` |
| 10 | 명예의 전당 — HubServiceData:12 | `icons/hud/rank`(78292135195856) | `ui/ds/icon-rank` |
| 11 | 게시판 — HubServiceData:13 | `icons/hud/attendance`(75113247446846) | `ui/ds/icon-board`(새) |
| 12 | 제련 · 대장장이 NPC — HubServiceData:16 · HubArtData:14 | `icons/hud/forge`(137666869132080) | `ui/ds/icon-forge`(새 · #3과 통일) |
| 13 | 보석 세공 — HubServiceData:17 | `icons/hud/codex`(책 그림 - 뜻 어긋남) | `ui/ds/icon-gem`(새) |
| 14 | 상점 · 상인 NPC — HubServiceData:18 · HubArtData:18 | `icons/hud/shop`(129799146563428) | `ui/ds/icon-shop` |
| 15 | 재봉사 — HubServiceData:19 | `icons/codex/tab_equipment`(106004003620012) | `ui/ds/icon-tailor`(새) |
| 16 | 마을 기능 머리 위 빌보드(34px) — HubServices:58-70 | 위 10 ~ 15 · 없으면 "!" | 데이터만 바꾸면 따라감 |
| 17 | 미니맵 설정 톱니 — Minimap:315 | `icons/hud/settings`(72177947529035) · 없으면 "≡" | `ui/ds/icon-gear` |
| 18 | 미니맵 북쪽 — Minimap:209 | 글자 "N" | `ui/ds/icon-compass` 또는 유지 |
| 19 | 보스 관문 표시(머리 위) — BossGateView:46 | 글자 "◈" | `ui/ds/mark-boss-gate`(새) |
| 20 | 보스 힌트 화살표 — BossGateView:92 | 글자 "▼" | `ui/ds/mark-arrow-down`(새) |
| 21 | 허브 포탈 표지 — WorldClient:123 | 글자 "→" · 이모지 "🔒" | `ui/ds/icon-lock` · `ui/ds/icon-portal`(새) |
| 22 | "곧 열려요" 자물쇠 — server/WorldMap:124-125 | `icons/ui/lock_badge`(77261605503440) | `ui/ds/icon-lock` |
| 23 | 길 안내 바닥 꺾쇠 — Wayfinder:60 | `icons/ui/guide_chevron`(86118523197528) | `ui/ds/guide-chevron`(낮음) |
| 24 | 조준 대상 발밑 원 — TargetFocus:69 | `icons/ui/target_ring`(85326063276067) | `ui/ds/target-ring`(낮음) |
| 25 | 관문 등록 안내 · 체크포인트 이름표 · 결계 문구 · 포탈 표지판 | 글자만 | 필요하면 #5 · #21 덧붙임 |

바꾸기 쉬운 방법(제안): 핀 이름을 `UiIconData.icons`에 `asset` / `old`로 올리고, 지도 · 미니맵 · 범례의 `"icons/ui/"..` 세 곳만 UiIconData를 보게 하면 표 하나로 교체된다.

## 3. 맵 첫 진입 · 보스 로딩 창 검은 실루엣

### 확인한 사실
- 보스 진입 연출(`client/BossIntroCinema`)은 **ViewportFrame이 아니라 실제 월드 보스 모델 + Scriptable 카메라**(257-325행). 첫 만남 카드(`BossIntroCard`)는 2D 도식만. ViewportFrame에 보스가 나오는 곳은 도감 상세뿐(Ambient 170,170,185 · LightColor 흰 · LightDirection (−1,−1.5,−1) — 연출과 무관).
- 보스 색 = `MeshPart.TextureID`(아틀라스) 하나 · `Color = 흰` (ArtMeshKit:119-129). SurfaceAppearance 안 씀.
- 외곽선 껍데기 `<부위>_Outline` 메시 색 = `#1E1B2E`(거의 검정 · 예: MeshMeta/crystal_queen_v2m:36-38).
- 미리 받기 ①(뒤에서): `ArtMeshReady`(전체 캐시 · 약 50초) 뒤 캐시 원본 모델을 PreloadAsync(BossIntroCinema:25-42) — **아틀라스 TextureID는 스폰 복제본에만 들어가 이 단계는 아틀라스를 데우지 못함**[추정].
- 미리 받기 ②(진입 때): `awaitMeshes(model, 2)` — **최대 2초**, 그것도 서버 고정 시간표 안에서 깎임 · 못 받으면 그대로 시작(45-67 · 189 · 196 · 202행).
- 아틀라스 = 모두 1024×1024 · 보스당 1.1 ~ 4.5 MB(수정 여왕 4.4 · 폭풍 4.45 · 전갈 2.7 · 나가 2.45 · 매머드 1.41 · 수호자 1.08).

### 원인(추정 · 순서대로 유력)
1. 첫 진입에서 아틀라스(2.4 ~ 4.4 MB)를 2초 안에 못 받으면 연출이 그냥 시작 → 단색 껍데기(`_Outline`, 거의 검정)가 먼저 그려져 몸 전체 모양이 검게 보임 → 텍스처 도착 뒤 색이 "늦게" 나옴. 폰 · 서버 막 켜졌을 때 더 심함.
2. 보조: 아래에서 올려다보는 저각 클로즈업(288-291행)의 역광 · 아레나 조명 전환 트윈(ArtV1ZoneLighting:83).
3. 0단계(FINAL-1 0)에서 고친 "첫 보스 블록 몸"도 같은 시기(서버 시작 직후)에 겹쳤을 수 있음.
- 판정 방법: 폰에서 `BossIntroMeshWait` 속성(BossIntroCinema:190)이 2초에 닿는지 보면 1번이 맞는지 확인된다.

### 개선 후보

| 안 | 비용 | 효과 | 위험 |
|---|---|---|---|
| ① 그 보스 텍스처만 PreloadAsync 뒤 표시(`MeshMeta.texture.atlases` 이미지 id + 메시 id · 시간 상한 유지) | 낮음(함수 하나 · 20 ~ 30줄) | 높음(원인 1 직접) | 기다림이 시간표를 깎음 · 상한 넘으면 같은 증상 |
| ② 받기 전 대표 색(`mesh.Color` = 아틀라스 평균색 · 불투명 아틀라스가 덮으니 로드 뒤 차이 없음) + 로드 전 `_Outline` 숨김 | 낮음(ArtMeshKit:128 근처 + 색 표) | 중간(검정 대신 비슷한 색 덩어리) | 아틀라스 투명 · 반투명 부분이 물듦 · 껍데기 숨김 타이밍 |
| ③ 미리 렌더한 2D 초상화 PNG(512 · 로딩/이름 카드) | 중간(6장 · 기존 `icons/codex/boss_*` 재활용 가능) | 중간(카드는 즉시 · 월드 모델은 그대로) | 거의 없음 |
| ④ 폰용 512 텍스처 | 중간(변형 굽기 · 기기 분기) | 중간 ~ 높음(용량 ¼) | 폰 화질 저하 · 키 관리 늘어남 |
| ⑤ 보스 관문 근처 · 구역 선택 때 미리 받기(①과 같은 목록) | 낮음 ~ 중간 | 높음(입장 전에 받아 대기 ≈ 0) | 관문을 안 거치는 진입(파티 소환 · 텔레포트)은 놓침 |

**추천**: ① + ⑤를 한 함수(`preloadBoss(bossId)` = 아틀라스 이미지 id + 메시 id)로 — 관문 접근 · 구역 선택 · 연출 직전(지금 `awaitMeshes` 대신)에 부르고, 뒤에서 하는 미리 받기도 이 목록으로 바꾼다. **② 껍데기 숨김 + 대표 색을 안전망**으로 같이. ③은 연출 카드 덤(도감 아이콘 재활용). ④는 위 조치 뒤에도 폰 대기가 2초를 넘을 때만.
