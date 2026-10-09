# UI 전수 현황표 (FINAL-1 1단계 · 2026-10-09 · 코드 기준 + Studio 캡처)

경로 = `roblox/src` 기준. **v2** = 새 체계(`client/ui/v2` UiKit · UiRoot · `shared/data/UiTokens` · `UiLayoutData` · `UiIconData`) 사용 여부 · "아니오(kit)" = 옛 `client/ui/kit`(Theme · Panel · Button · Toast)만.
**잘림** = 1920×1080 / 1366×768 / 폰 800×360 예상(근거 = `02_cutoff_icon_size.md` 계산 + `cap/` 캡처). **우선** = P1(지금 플레이어가 매일 봄 · 문제 있음) · P2(자주 봄 · v2 아님) · P3(가끔 · 개발용).

공통:
- `ScreenInsets` · `SafeAreaCompatibility` · `ClipToDeviceSafeArea`를 정한 GUI = 0개(전부 엔진 기본값). `IgnoreGuiInset = true` = MenuBoot · LoadingTip · HudMenuV2 · HurtEdge · Wayfinder 가장자리 · BossIntroCinema · BossGimmick13View · BossBR1View 서리 · PrimordialFx · ClassStage 디버그 · CosmeticAudit · A1UiMockups.
- 창(Panel.create / UIManager): 창마다 ScreenGui · AnchorPoint(0.5,0.5) 가운데 · 크기 Offset px · 폰 = Scale 0.92×0.88 + UISizeConstraint · DisplayOrder station 10 / window 100 / overlay 200 + 열린 순서 · PC 창 끌기 가능(ui/WindowPositions).

## A. 시작 · 메뉴

| # | 이름 | 파일 | 언제 뜨나 | v2 | 최신 handoff 반영 | 옛 아이콘 · 하드코딩 id | 잘림(1920/1366/폰) | 우선 |
|---|---|---|---|---|---|---|---|---|
| 1 | 로딩 가림막(키 아트) | first/MenuBoot · MenuBootData · MenuArtFit | 접속 즉시 **자동** | 부분 | 01 v3 키 아트 | 하드코딩 `rbxassetid://90708952668878` · `129274403210371`(MenuBootData:37-38) | 없음 | P3 |
| 2 | 로딩 팁 한 줄 | first/LoadingTip | 접속 **자동** | 아니오 | 없음 | - | 없음 | P3 |
| 3 | 메인 메뉴 v2 | ui/v2/MainMenuV2 · MainMenu.client | 접속 **자동** · [메인 메뉴로] | 예 | 01 v1 ~ v3 | ui/ds · ui/legends(새) | 없음 | P3 |
| 4 | 첫 실행 설정 문구 | MainMenuV2:236 | **자동 1회** | 예 | 01 v1 | - | 없음 | P3 |
| 5 | 메인 메뉴 설정 · 소식(옛 모양) | MainMenu.client(~600 · 666-697) | 메뉴 [설정] · [소식] | 아니오 | **06 v1/v2 미구현** | - | 없음 | P2 |
| 6 | 이어하기 창(옛) | ui/SlotWindow | 옛 메뉴 | 아니오 | 없음 | - | 없음 | P3 |
| 7 | 직업 선택(게임 안) + 변신 무대 | ClassSelectUI · ClassStage · ClassTransform · LegendPlayer | **자동: ClassId 빈 값** · 캐릭터 창 | 아니오 | 없음(v2는 MainMenuV2에만) | ClassStageData `rbxasset://textures/face.png` | 없음 | P3 |

## B. HUD

| # | 이름 | 파일 | 언제 | v2 | handoff | 옛 아이콘 | 잘림 | 우선 |
|---|---|---|---|---|---|---|---|---|
| 8 | HUD 메뉴 v5(왼쪽 5 · 오른쪽 4 + 귀환 · 폰 위 줄) | hud/HudMenuV2 · data/HudData | 상시 | 예 | **02_hud v5** | 새 ui/ds | **오른쪽 열 맨 아래(귀환) · 이름표가 화면 끝에 닿음(Studio 16:9 실측 578/592 · 1366×768 계산 767 ~ 771/768)** | **P1** |
| 9 | 더보기 · 보상 작은 창 | HudMenuV2 | HUD 버튼 | 예 | 02 v5 | 새 ui/ds | 보상 작은 창 아래가 화면 끝(캡처 pc169_11) · **첫 표시 때 아이콘 4/5 빈 칸(이미지 로딩)** | P1 |
| 10 | 옛 왼쪽 메뉴바 | hud/MenuBar | menuV5 꺼질 때만(지금 꺼짐) | 아니오 | 없음 | icons/hud/* 11종 | - | P3 |
| 11 | 잠긴 스킬 칸 말풍선 | hud/SkillLockV2 | 잠긴 칸 있을 때(지금 0) | 예 | 02 v5 | - | 없음 | P3 |
| 12 | 스킬 · 공격 · 대시 · 쿨다운 링 | SkillSlots · HudIcons · data/SkillIconData | 상시 | 부분(아이콘만) | UI2-4 아이콘 | **SkillIconData 옛 rbxassetid 6개+** · 공격 = icons/weapons/* | 없음(PC 아래 가운데 고정 px) · 폰 = 점프 버튼 계산식 흉내(실제 TouchGui 안 읽음) | **P1** |
| 13 | 스킬 툴팁 | hud/SkillTooltip | 마우스 · 길게 누름 | 아니오 | 없음 | icons/skills/* | - | P2 |
| 14 | 궁극기 게이지 T | hud/UltGauge | 상시 | 아니오 | 없음 | - | - | P1 |
| 15 | 체력바 · 버프 줄 · 콤보 점 | PlayerHealthBar · BuffHud | 상시 | 아니오 | 없음 | - | - | **P1** |
| 16 | 경험치바 | ExpBar | 상시 | 아니오 | 없음 | - | - | P2 |
| 17 | 재화 · 레벨 · 스테이지 · CP 칩 | StageUI · GoldHud · LevelHud · CombatPowerHud · ui/CurrencyBar | 상시 | 부분(배율) | UI2-4 배율 | icons/reward/* | 없음 | P2 |
| 18 | 알 칩 | EggChip | v5에서 숨음 | 아니오 | 없음 | 도형 | - | P3 |
| 19 | 오늘의 목표 · 메인 퀘스트 칸 | hud/TodayGoal | 상시(전투 중 접힘) | 부분 | 02 v5 | - | 오른쪽 열을 아래로 밂(02 원인 3) | P1 |
| 20 | 미니맵 | hud/Minimap · MapPins | 설정 켬(기본 끔) | 부분 | 02 v5 자리 | **icons/hud/settings** · icons/ui/pin_* | 800×360 PC 배치 50px(하한 미적용) | P2 |
| 21 | 파티원 목록 | hud/PartyList · PartyListView | 파티일 때 | 부분 | 02 v5 | - | - | P2 |
| 22 | 요청 배너(초대 · 투표) | hud/RequestBanner · PartyRequests | **자동** | 아니오 | 없음 | - | - | P2 |
| 23 | 토스트 줄 TC · TR · BC | ui/kit/Toast · FeedLayout | 알림 | 아니오 | 06 v2 알림 띠 미구현 | - | - | P2 |
| 24 | 시스템 토스트 | hud/SystemToasts | **자동** | 아니오 | 없음 | - | - | P2 |
| 25 | 드랍 피드 · 자동 처리 | hud/DropFeed · AutoProcessToast | **자동** | 아니오 | 없음 | - | - | P2 |
| 26 | 이정표 · 마일스톤 · 공방 힌트 토스트 | GuideToast · MilestoneToast · GemWorkshop/Hint | **자동** | 아니오 | 없음 | - | - | P3 |
| 27 | 태초 배너 · 관전 | PrimordialFx | **자동** | 아니오 | 없음 | - | - | P3 |
| 28 | 보스 체력바 | hud/BossBar · BossHudLayout | 보스전 **자동** | 아니오(kit.Gauge) | 없음 | - | **내 체력바 바로 위(아래 가운데) · 폰은 화면 높이 64% 지점(캡처 ph_05)** | **P1** |
| 29 | 견습 토스트 · 진행 칩 · 보스 도전 버튼 | TutorialHud | **자동** | 아니오 | 없음 | - | - | P2 |
| 30 | 구역 진입 알림 | ZoneBoundaryWarning | **자동** | 아니오 | 없음 | - | - | P3 |
| 31 | 피격 가장자리 | HurtEdge | **자동** | - | 없음 | - | - | P3 |
| 32 | 월드 HUD(지역명 · 귀환) | WorldClient | 상시 | 아니오 | UI2-4 숨김만 | **icons/hud/return** | - | P2 |
| 33 | 합동 목표 알약 · 창 · 배너 | CommunityGoalView | 상시 · 배너 **자동** | 아니오 | 없음 | - | - | P2 |
| 34 | 균열 HUD | RiftView | **자동** | 아니오 | 없음 | - | - | P3 |
| 35 | 줍기 빛 구슬 | PickupOrb | **자동** | 아니오 | UI2-4 | - | - | P3 |
| 36 | 길 안내 가장자리 화살표 | Wayfinder | 안내 중 | 아니오 | 없음 | icons/ui/guide_chevron | - | P3 |
| 37 | 옛 파티 · 순위 · 가방 버튼(숨김) | Party:580 · Leaderboard:792 · Inventory/Shell:46 | Visible=false | 아니오 | - | icons/hud/party · rank | - | P3 |
| 38 | 하이파이브 제안 | CosmeticFx | **자동** | 아니오 | 없음 | - | - | P3 |
| 39 | 이동 게이지(공중 점프 점 · 활강 링 · 대시 쿨) | AirChargeDots · GlideController(kit.RingGauge) · SkillSlots 대시 칸 | 공중 · 활강 · 대시 | 아니오 | 없음 | - | - | P1(MOVE-2 연동) |

## C. 창 · 팝업

| # | 이름 | 파일 | 언제 | v2 | handoff | 옛 아이콘 | 잘림 | 우선 |
|---|---|---|---|---|---|---|---|---|
| 40 | 가방 · 장비창(장비 · 가방 · 보석) | InventoryUI · panels/Inventory/* | G · HUD | 예(껍데기 · 칸 · 상세) · 탭 본문 부분 | **03_bag-equip v2** | icons/weapons · armor · **icons/ui/set_<구역>** | 폰: 창 아래가 화면 끝(캡처 ph_04 셋째 줄 잘림 · 스크롤) · 옵션 이름 "그림자…" 말줄임 | **P1** |
| 41 | 일괄 판매 · 등급 분해 | Inventory/BulkSell | 가방 헤더 | 예 | 03 v2 | - | - | P2 |
| 42 | 아이템 확인 | Inventory/ItemConfirm | 판매 · 분해 | 아니오 | 없음 | - | - | P2 |
| 43 | 캐릭터 | panels/Character | C | 아니오 | 08 A3 미구현 | icons/codex/class_* | - | P2 |
| 44 | 수련 | panels/Training | U | 아니오 | 08 A2 미구현 | **icons/hud/training** | - | P2 |
| 45 | 전체 지도 | panels/WorldMapPanel | M | 아니오 | 08 B1 미구현 | icons/ui/pin_* 7종 | 아래 [+ − ?] 버튼 줄이 겹쳐 보임(캡처 pc169_07) | P1 |
| 46 | 구역 선택 + 보스 보상 띠 | StageSelectPanel · StageRewardBand | N | 아니오 | 08 A1 미구현 | HudIcons.lock | - | P1 |
| 47 | 퀘스트 | panels/Quests · QuestsUI | J | 아니오 | 08 A4 미구현 | icons/reward/* | - | P2 |
| 48 | 도감 + 받기 날기 | panels/Codex · CodexV2/* · CodexUI | K · 더보기 | 아니오 | 08 B3 미구현 | **icons/codex/*** · icons/reward · pin_quest | 오른쪽 열 칸이 가로 스크롤로 잘림(캡처 pc169_13) | **P1** |
| 49 | 파티 · 파티 찾기 | panels/Party · PartyBoard | P | 아니오 | 08 B2 미구현 | - | - | P2 |
| 50 | 순위 | panels/Leaderboard | L | 아니오 | 08 B4 미구현 | icons/hud/rank | - | P2 |
| 51 | 설정(4탭) | panels/Settings · ui/SettingSave | 더보기 | 아니오(글자 크기만 UI2-2) | **06 v2 미구현** | - | 체크칸이 네모 칸(토글 손맛 없음 · 캡처 pc169_17) | P1 |
| 52 | 알 · 펫 정보 | panels/EggInfo | 더보기 [펫] | 아니오 | 08 B5 미구현 | - | 표 · 글자 위주(캡처 pc169_16) | P2 |
| 53 | 접속 보상 7일 | panels/Attendance · MenuPanels · AttendanceClaimFx | **자동(받을 칸 + 견습 끝 + 창 없음 → 2초 뒤)** · HUD 보상 | 아니오 | 08 A5 미구현 | icons/reward/* | **폰: [오늘 접속 보상 받기] 버튼이 안내 문구를 덮음(캡처 ph_01)** | **P1** |
| 54 | 시즌 출석판 32칸 | panels/SeasonBoard | **자동(출석 창 닫힐 때 · 출석 없는 날 2.5초 뒤)** | 아니오 | 08 A5 미구현 | icons/reward/* | 넷째 줄이 버튼 뒤로 잘림(캡처 pc169_03) | P1 |
| 55 | 선물함 팝업 | Shop/GiftPopup · ShopClient | **자동: 서버 GiftPopup 1초 뒤** | 아니오 | 08 A5 미구현 | - | - | P2 |
| 56 | 상점 | panels/Shop/* | 보석상인 · HUD | 아니오 | **04 v1/v2 미구현** | icons/reward/* · `rbxasset://textures/ui/common/robux.png` | - | P2 |
| 57 | 상점 3D 미리보기 | Shop/Preview3D | 카드 | 아니오 | 없음 | - | - | P3 |
| 58 | 강화(일반 · 환생 · 초월 · 방지 · 확률) | panels/Enhance/* | **자동: 강화대 근처** | 아니오 | **05 v1 ~ v3 · 07 미구현** | - | (이번 캡처 못 함 - 아래 주) | **P1** |
| 59 | 계승 | panels/Inherit | 상세 [계승] | 아니오 | 05 미구현 | - | - | P2 |
| 60 | 보석 가공 | panels/GemForge | 상세 [재련] | 아니오 | 08 B7 | - | - | P2 |
| 61 | 보석 공방 | panels/GemWorkshop/* | 보석상인 | 아니오 | 08 B7 | - | - | P2 |
| 62 | 확률 공개 | panels/Probability | 퀘스트 창 | 아니오 | 08 B8 | - | - | P3 |
| 63 | 성장 보상(마일스톤) | panels/Milestones | 토스트 · 강화 환생 탭 | 아니오 | 없음 | - | - | P3 |
| 64 | 다른 유저 장비 보기 | panels/Inspect | 이름 메뉴 | 아니오 | 없음 | - | - | P3 |
| 65 | 이름 클릭 메뉴 | panels/PlayerMenu | 이름 | 아니오 | 없음 | - | - | P3 |
| 66 | 도움말 백과 · ? 툴팁 | panels/Help · HelpTooltip | 카드 [도움말] | 아니오 | 없음 | **icons/hud/character · forge** · icons/codex/* | - | P3 |
| 67 | 보스 잔류 선택 | panels/BossLinger | **자동: 보스 처치** | 아니오 | 없음 | - | - | P2 |
| 68 | 환생 해금 안내 | MoveUnlockPopup | **자동: 환생 뒤 이동 단계 상승** | 아니오(kit.Panel) | 없음 | 도형 | - | P3 |
| 69 | 환생 제단 확인 | RebirthAltar + kit/Confirm | 제단 | 아니오 | 08 B6 | - | - | P3 |
| 70 | 공용 확인창 · 메인 메뉴로 | ui/kit/Confirm · ToMainMenu | 각 동작 | 아니오 | 없음 | - | - | P2 |
| 71 | 보상 상세 카드 | ui/RewardDetail | 보상 칸 | 아니오 | 없음 | icons/reward/* | - | P3 |
| 72 | 툴팁 류(아이템 · 비교 · 보석 교체 · 전체 글) | ui/kit/ItemTooltip · FullTextTip · CompareTip · GemReplaceTip | 마우스 | 아니오 | 없음 | - | - | P2 |
| 73 | 업데이트 게시판 · 주간 도전 | UpdateBoard | 게시판 | 아니오(kit.Panel) | 06과 다른 화면 | - | - | P3 |
| 74 | 보스 첫 만남 카드 | BossIntroCard · BossIntroDiagram | **자동: 처음 만날 때** | 아니오(kit.Button) | 없음 | 도형 3컷 | - | P2 |
| 75 | 보스 진입 연출(이름 카드 · 레터박스) | BossIntroCinema | **자동** | 아니오 | 없음 | - | - | **P1(검은 실루엣)** |
| 76 | 순간 연출(처치 도장 · 도감 완성) | FxMoment · CodexMoments | **자동** | 아니오 | 없음 | 도감 그림 | - | P3 |
| 77 | 보스 기믹 화면 HUD | BossRodsView · BossGimmick13View · BossTrapView · BossBR1View · BossEnvironmentView | 보스 패턴 **자동** | BossRodsView만 kit | 없음 | - | - | P2 |
| 78 | 개발용 전시장 · 목업 · 검사 | panels/UiGallery · A1UiMockups 등 | /gg | kit | - | - | - | P3 |

## D. 월드 공간(BillboardGui · SurfaceGui)

| # | 이름 | 파일 | 언제 | v2 | handoff | 아이콘 | 우선 |
|---|---|---|---|---|---|---|---|
| 79 | 플레이어 이름표 + 칭호 | Nameplate | 상시 | 아니오 | **32 v1 이름표 미구현** | HudIcons.badge | P2 |
| 80 | 몬스터 이름표 · 체력 | server/MonsterSpawner:300 · 449 | 상시 | 아니오 | 32 v1 | - | P2 |
| 81 | 조준 대상 이름표 · 발밑 링 | TargetFocus | 조준 | 아니오 | 없음 | icons/ui/target_ring | P3 |
| 82 | 잠긴 몹 표시 | MobLockView | **자동** | 아니오 | 없음 | HudIcons.lock | P3 |
| 83 | 데미지 · 받은 피해 · 힐 숫자 | DamageNumbers · PartyHealView | 타격 | 아니오 | 32 v1 숫자 4종 | - | P2 |
| 84 | 골드 · 재료 팝업 | GoldHud · MaterialHud | 획득 | 아니오 | 없음 | - | P3 |
| 85 | 땅 드랍 이름표 | server/ItemDropSpawner:75 | 드랍 | 아니오 | 없음 | - | P3 |
| 86 | 시설 이름표(강화대 · 제단 · 보석상인) | server/EnhanceStation:35 · HuntingGround:83 · 165 | 상시 | 아니오 | 32 v1 기둥 | - | P2 |
| 87 | 마을 기능 머리 위 아이콘 + 첫 방문 소개 | HubServices · data/HubServiceData | 상시 · 소개 **자동 1회** | 아니오 | 32 v1 · 00 v5 NPC 아이콘 업로드 안 됨 | **icons/hud/rank · attendance · forge · codex · shop · pin_boss · codex/tab_equipment** | P1 |
| 88 | 구역 · 명판 라벨 | server/WorldMap:90 | 상시 | 아니오 | 32 v1 | - | P3 |
| 89 | 포탈 표지판 | server/TeleportPad:85 | 상시 | 아니오 | 없음 | 글자 "→" · 이모지 "🔒" | P2 |
| 90 | 명예의 전당 석판 | server/HallOfFame:34 | 상시 | 아니오 | 없음 | - | P3 |
| 91 | 결계 문 · 포탈 잠김 · 나무 높이 | WorldClient:64 · 103 | 상시 | 아니오 | 없음 | - | P3 |
| 92 | 덩굴 리프트 표지 | VineLiftView | 상시 | kit.Theme | 없음 | - | P3 |
| 93 | 마을 게시판 판면 | UpdateBoard:56 · 117 | 상시 | 아니오 | 없음 | - | P3 |
| 94 | 합동 목표 허브 게이지 | CommunityGoalView | 상시 | 아니오 | 없음 | - | P3 |
| 95 | 보스 관문 등록 · 게이트 표식 | BossGateMarks · BossGateView | 상시 | 아니오 | 없음 | 글자 "◈" · "▼" | P2 |
| 96 | 보스 패턴 말풍선 · 기믹 표식 | BossPatternVisuals 등 13개 | 보스 패턴 **자동** | 아니오 | 없음 | - | P2 |
| 97 | 이동 시전 막대 · 체크포인트 라벨 | TravelChannelView | 귀환 | 아니오 | 없음 | - | P3 |
| 98 | 길 안내 비컨 라벨 | Wayfinder:85 · 243 | 안내 중 | 아니오 | 없음 | - | P3 |
| 99 | 보석상인 위치 마커 | GemWorkshop/Guide | 위치 안내 | 아니오 | 없음 | - | P3 |
| 100 | 공중 점프 점 · 활강 게이지 | AirChargeDots · GlideController | 공중 | 아니오 | 없음 | - | P1(MOVE-2) |
| 101 | 강화 칭호 · 치장 라벨 | WeaponEnhanceVisual · ArtV1Cosmetics · CosmeticFx | 상황 | 아니오 | 없음 | - | P3 |
| 102 | 말풍선 부품(호출 0곳) | ui/kit/Bubble | 쓰이지 않음 | - | - | - | - |

## 자동으로 뜨는 창 · 화면 (트리거 위치)

| 순서 | 창 | 트리거 |
|---|---|---|
| 1 | 로딩 가림막 → 메인 메뉴 → 첫 실행 문구(1회) | first/MenuBoot · MainMenuV2:236 |
| 2 | 직업 선택 | ClassSelectUI:452-468(ClassId 빈 값) |
| 3 | 접속 보상 7일 | panels/Attendance:184-191(받을 칸 + 견습 끝 + 열린 창 없음 → 2초 · 날짜 바뀌면 다시) |
| 4 | 시즌 출석판 | panels/SeasonBoard:186-197 · openIfReady:147(출석 창 닫힐 때) |
| 5 | 선물함 | Shop/GiftPopup:155-162(서버 GiftPopup → 1초) |
| 6 | 강화 창 | Enhance/init:469-482(강화대 근처 Heartbeat · 벗어나면 닫힘) |
| 7 | 보스 첫 만남 카드 | BossIntroCard:119-122 |
| 8 | 보스 진입 연출 | BossIntroCinema:181 |
| 9 | 보스 잔류 선택 | BossLingerClient:14 |
| 10 | 환생 해금 안내 | MoveUnlockPopup:138-150 |
| 11 | 견습 안내 | TutorialHud:117 |
| 12 | 요청 배너 | hud/PartyRequests |
| 13 | 토스트 · 배너 11종 | SystemToasts:59 · DropFeed · AutoProcessToast · GuideToast:10 · MilestoneToast:13 · PrimordialFx · CodexMoments:110 · CommunityGoal 배너 · HubServices 첫 방문(:119-135) · InventoryUI 판매 힌트(:195-200) · MenuBar 이름표(꺼짐) |

소식 창 · 업데이트 게시판은 자동으로 열리지 않음(소식 = 빨간 점만 · MainMenuV2:135-150).

## 요약

- v2 전면: 메인 메뉴 v2(01) · HUD 메뉴 v5(02) · 가방 껍데기 · 칸 · 상세 · 일괄 판매(03 v2).
- v2 부분: 칩 · 오늘의 목표 · 미니맵 · 파티 목록 · 스킬 칸(아이콘만) · 로딩.
- **handoff는 있는데 코드에 없음**: 04_shop · 05_enhance-inherit · 06_notice-news-settings · 07_enhance-lamp · 08_other-screens(a · b · v3) · 32_world-ui v1.
- 옛 `icons/hud/*`가 보이는 곳: 미니맵 톱니 · 수련 · 도움말 · 마을 기능 머리 위 아이콘 5종(+ 숨긴 버튼).
- 보상 아이콘 = 전부 옛 `icons/reward/*`(00 v5 보상 · NPC 아이콘은 ArtAssetIds에 없음 = 업로드 안 됨).
- 하드코딩 rbxassetid: 로딩 키 아트 2 · SkillIconData 옛 스킬 대체 그림 6+.

주: 강화 창은 강화대 근처에서만 자동으로 열리는데 이번 Play에서 강화대 자리를 못 맞춰(서버 순간이동이 되돌려짐 · 걸어간 곳은 재련대) 캡처하지 못했다 — 카드는 handoff 05 v3 목업 · 코드 기준.
