# QUEUE-ALL9E1 상태

- 시작: 2026-10-04 17:46 (10시간 = 10-05 03:46)
- 자동 압축 뒤: QUEUE-ALL9E1-prompt.md · 이 파일 · docs/design/gear-art-v3.md · docs/design/transcend-inherit-plan.md · docs/art/ref/gpt-gear-index.md 다시 읽기

| 블록 | 항목 | 상태 | 커밋 | 메모 |
|---|---|---|---|---|
| 0 | 준비(지시 저장 · 상태 파일 · P3 결정 기록) | 완료 | dacd00a7 | |
| 0 | 0-1 회복 보조 없음(옵션 A) | 완료(기록만) | dacd00a7 | |
| 0 | 0-2 계승 +29 · 증표 · 히든 칭호 | 완료 | 1fb7e693 | 리뷰어 반영 · Play PC(+29 → 계승) |
| 0 | 0-3 초기화 −4 · k 재탐색 | 완료(Play · 리뷰 = 0-4와 함께) | e824fe3e | k 1.7 · 3.0 · 1.9 · P90/중앙 +30 2.01 → 1.89 |
| 0 | 0-4 초월 강화 확률 | 완료 | 834356de · a799fd33 | gain 0.22 · v71 · levelKills 43만 |
| 0 | 0-5 초월 최초 알림 | 완료 | 834356de · a799fd33 | |
| 0 | 0-6 정밀 재검증(+ ADD A · B · E) | 완료 | 5519b715 · f261e6bf | 판정 = ADD 보고서 E절 · 몹 곡선 · 1,000스테이지 표 |
| 0 | 블록 0 끝 검증 · push | 완료 | f261e6bf | run_all 전부 · textdata · 로그 게임 에러 0 |
| - | (사용자 추가) 치장 시안 v2 등록 | 완료 | 8210a656 | 구현 안 함 |
| - | (사용자 추가) 게임 이름 확정 | 완료 | ef607dec | 메뉴 PC · 작은 창 |

## 추가 항목(10-04 밤) - 보석 홈 화면 무기 그림 · 512 무기 · 보석 아이콘
- 아이콘 블록(3)이 아직이라 블록 3에 합쳐 진행(상한 2.5h) · 원문 = 지시 파일 끝 "추가 항목(10-04 밤)".

| 1 | 1-1 장비 v3 메시 | 완료 | (이 커밋) | FBX 86 업로드(Approved 86) · MeshMeta 갱신 · shared/GearV3(구역 색 · 문 부품 · 스위치 GearV3Meshes) · ArmorWearView(v3 우선 · 세트 문장) · ArtMeshKit 무기 v3 · 하네스 gear_v3 8/8(48조합 · 1인 MeshPart 최대 23) · Play 캡처 4장(8등급 · 4직업 · 6세트 · 플레이어) · 무기 Grip/가림 = 1-2 |
| - | P3 결정 판정(사용자 10-04 19:30) | 완료 | 41818c75 | 2-1 돌파 2.2 · 2-2 값 보류(조건 동시 불가) · 2-3 안전장치 · 2-4 기본값 · docs/design/all10-p3-decisions.md · 리뷰어 결함 없음 |
| - | (사용자 추가) 불씨 시안 v3 .gitignore 예외 + 사양 문서 | 완료 | 29d4734e | docs/design/cosmetics-v3.md |
| - | (사용자 추가) class_legend_*.png 예외 · warrior_v1만 커밋(나머지 3장 = MENU2 F블록) | 완료 | 602c275b | |
| 1 | 1-1 무대 캐릭터(활 시위 · 장갑 크기) | 완료 | 2b1f52d0 | |
| 1 | 1-2 착용 통과 시험 | 멈춤(LOOK1 먼저) | | 한 것: 체형 0.8/1.0/1.35 × 4직업 수치 통과(손발 ≤ 1.10 · 두께 0.150 · 덮음 ≥ 1.11) + 캡처 · Grip 대검 3각도 · 활 2 · 치유사 2 · 쌍검 2(W1PoseHook freeze stance) · 태초 Inner 자홍 → 은빛(Trim = 자홍) 수정(아직 커밋 전). 남은 것: 달리기 · 공격 · 활강 freeze 캡처 · 레이어드 옷 · 시안 비교(docs/art/ref/compare/) |
| + | LOOK1 장비 마감 | LOOK2로 대체 | | 0번 조사만 함(docs/design/look1-survey.md) |
| + | LOOK2 장비 마감 + 색 배치 + 바닥층 · 토글(상한 7h) | 완료 · 판정 받음(→ LOOK3) | 781c8c37 · 6530ea2b · (보고서 커밋) | 보고서 docs/phase/QUEUE-ALL9E1-LOOK2-report.md(맨 위 판정 4건) · 저장 v73 · 리뷰어 2회(결함 1건 반영) |
| A | LOOK2 · P3 판정 기록 + 캐주얼 남는 골드 재측정 | 완료 | (이 커밋) | 남는 골드 캐주얼 0.01h(≤ 6h 통과) · EconSim 초월 +1 ~ +5 칸 즉시 납입으로 고침(25,300 영향 ±1.2%) · run_all 전부 |
| B | LOOK3 3D를 아이콘 수준으로(상한 8h) | 완료 · 임시 확정(10-04 밤) | (이 커밋) | 보고서 docs/phase/QUEUE-ALL9E1-LOOK3-report.md(맨 위 판정 4건) · 등급 메시 96 · 1벌 11파트 · 최대 7,760삼각형 · 색 지도 + 발광 마스크 164 업로드 · LOD 2단 · gear_v3 10/10 · run_all 전부 |
| C | 아이콘 다시 굽기 · 비교 시트(B 뒤) | 완료 · 사용자 선택 받음(갑옷만 교체 - 블록 3에서 연결) | (이 커밋) | roblox/art/icons/gear_v3_look3 96장(업로드 · 연결 안 함) · 시트 docs/art/ref/compare/icons-look3-vs-current.png · 추천 = 갑옷만 교체 |
| - | LOOK3 판정 기록(임시 확정 · 어깨 UpperTorso 예 · 갑옷 아이콘만 교체 · 프레임 = PERF1 사용자) | 완료 | (이 커밋) | gear-art-v3.md 3-3 · 6절 · all10-p3-decisions.md 끝 |
| T | 메시 생성 시험(generate_mesh · 상한 1.5h · 게임 적용 금지) | 완료 | (이 커밋) | 보고서 QUEUE-ALL9E1-MESHGEN-report.md · 도구 동작 · 색 구워짐(등급 재사용 X) · 어깨 몸통 폭 안 · 2회차 모양 크게 다름 → 시안용만 추천 · 생성 모델 = ServerStorage.MeshGenTest_1004 |
| D | 순서: 1-2 남은 부분 → 2 → 3(+보석 홈 · 갑옷 LOOK3 아이콘 연결) → 4 → ADD F → MENU2(기능만 · 꾸밈은 Claude Design 목업 뒤) | 바뀜(아래) | | |
| D' | **사용자(10-04 밤): 디자인 묶음 보류 → 기능 먼저**(지시 = prompt 끝 · 목록 = DESIGN-BACKLOG.md) | 진행 | | 순서: ① ALL9E1 기능(보석 홈 무기 그림 자동 교체 · 보석 아이콘 한 소스 · 무기 이펙트 단계 판정 · 블록 2/4의 규칙·데이터) → ② MENU2 기능 전체 → ③ ALL9D(이동) → ④ SEC2 · PERF1 준비 |
| 1-2 | 무기 4×4 사다리 캡처(⑤) | **보류(디자인)** | | Play에서 4직업 × 일반 · 전설 · 태초 · 초월 복제 배치까지 · 캡처 저장 안 함 |
| F1 | 기능: 보석 탭 무기 그림 = 장착 무기(직업 × 등급) 자동 교체 | 완료 | (이 커밋) | GemHeader → ItemIcons.keyFor/image(장비 탭과 한 소스 · 그림 없으면 도형) · GemTab이 ClassId · WeaponGrade · WeaponLevel 변화에 즉시 다시 그림 · Play 확인(직업 전환 · 태초 · 강화 · 계승 · 원복) · 512 그림 · 강화 표시 꾸밈 = DESIGN-BACKLOG 6 |
| F2 | 기능: 보석 아이콘 한 소스(종류 × 등급) | 완료 | (이 커밋) | GemData.iconKeyByKind/ByGrade + ItemIcons.gem(그림 없으면 등급색 원 = 임시 · GemIconKey 기록) · 홈 · 가방 칸 연결 · 박힌 채 등급 상승 = GemSync 다시 칠함 · 8 × 16 = 임시 128 · 보석함 · 판매 창 · 우편함 연결은 그림 들어올 때(DESIGN-BACKLOG 7) |
| F3 | 기능: 초월 무기 이펙트 단계 판정 + 연결 지점 | 완료 | (이 커밋) | All10Data.transcendEnhance.fxTiers(+0/5/10/15/20/21 → 1 ~ 6) · All10.transcendFxTier · WeaponEnhanceVisual = TranscendLevel · WeaponGrade 신호 → TranscendFxTier 속성 기록 · 효과 = 기존 +30 연출 재사용(tempVisualLevel) · 하네스 gem_home 13/13 · run_all 전부 |
| F3' | 사용자 변경(10-04 밤): 초월 +0 ~ +25 → 단계 번호 0 ~ 25 · 단계마다 요소 표 하나(아이콘 · 3D 공용) · 계승 전 +20 ~ +30(은 · 민트 · 하늘 · 아쿠아 · 흰하늘 · 백금) 포함 | 진행 | | MENU2 B 잠시 멈춤(SlotSaveData.lua 작성 중 · 미커밋) |
| 1-2 | 달리기 · 강공격 · 활강 × 4직업(LOOK3 초월) 캡처 | 완료(디자인 판정 없음) | (이 커밋) | look3/look3_1-2_run_attack_glide_4classes_transcendent.jpg · 무기 손잡이 · 활시위 가림 0 · 활강 = 윗팔이 어깨판 속(판정 2 허용) · 로그 게임 에러 0 |

## 정지 기록(2026-10-04 · 사용자 "지금 하는 항목까지만 마치고 멈춰")

### 완료
- 블록 0 전부(0-1 ~ 0-6) · ADD A ~ E(보고서 docs/phase/QUEUE-ALL9E1-ADD-report.md) · 사용자 추가(치장 시안 v2 등록 · 게임 이름 확정) · 블록 0 push.

### 진행 중
- 블록 1-1 장비 v3 메시: `roblox/tools/blender/make_gear_v3.py` 완성(방어구 60 + 문장 6 + 무기 20 · 전부 예산 안 · 통계 `roblox/art/armor/gear_v3.stats.json`) · `shared/data/GearV3Data.lua`(세트 hex · 단계 · 문 · 핵심 보석 색 · 스위치 enabled = true · 아직 아무 코드도 읽지 않음).
- 아직 안 한 것: FBX 내보내기(--export) · 렌더 검수 · upload.py 업로드 · ArmorWearView 연결(구역 색 · 문 파트 · 문장 메시) · 스위치 GearV3Meshes 연결 · 48조합 예약 색 하네스 · Play 캡처.

### 남은 일
- 블록 1-1 나머지 · 1-2(착용 통과 시험 · 시안 비교 캡처) · 블록 2(보석 광채 · 초월 무기 이펙트 · 홈 광원) · 블록 3(아이콘 128 + 추가 항목: 보석 홈 화면 무기 그림 · 512 무기 · 보석 아이콘) · 블록 4(보고서 QUEUE-ALL9E1-report.md).

### 다음에 할 첫 작업
- (10-04 밤 LOOK3 뒤) LOOK3 보고서 맨 위 판정 4건(충분한가 · 어깨 UpperTorso · 아이콘 선택 · 프레임 측정)을 받은 뒤 원래 순서: 1-2 남은 부분 → 2 → 3(+보석 홈) → 4 → ADD F → MENU2. Play 촬영 요령(LOOK3): 더미 = 서버에서 ModelStreamingMode Persistent를 부모 연결 전에(아니면 클라에 몸이 안 옴) · y 2300 공중 바닥판 · 클라 ScreenGui 전부 끔 · LOOK2 비교 = 서버 ReplicatedStorage:SetAttribute("GearV3Look3", false).
- (10-04 밤 LOOK2 뒤) LOOK2 판정(보고서 맨 위 4건 - 특히 어깨 재모델 · 블록 3 아이콘 다시 굽기)을 받은 뒤 1-2 남은 것(달리기 · 공격 · 활강 freeze 캡처 · 레이어드 옷 착용 시험 · 시안 비교 docs/art/ref/compare/) → 블록 2 → 3 → 4 → ADD F → MENU2. 판정 전이면 1-2 남은 것부터(LOOK2 판정에 영향 없는 부분).
- Play 요령(LOOK2): 출석 · 시즌판 · 상점 · 메인 메뉴 Gui를 끄고 시작 · 장비창 버튼은 moveTo 뒤 클릭(첫 클릭이 먹히지 않는 경우) · 폰 배치 = DebugInventoryScreen(800,360) + ForceTouchLayout · 레이어드 옷 시험 에셋 = 재킷 9039676988 · 바지 9180004944(공개 아바타 33의 장신구만).
- (이전 기록) 1-1 완료 → 짧은 작업 2건(불씨 · class_legend) 커밋 → 1-2 착용 통과 시험(4직업 × Grip 3각도 · 달리기 · 공격 · 활강 · 체형 0.8/1.35 · 레이어드 옷 · 시안 비교 docs/art/ref/compare/). Play 더미 = 서버 execute_luau로 R15 모델 + Attribute ArmorWearDummy · ClassId · ArmorLook_<부위>="tierN|등급"(바꾼 직후 1 ~ 2초는 메시 로딩으로 검게 보임) · 카메라 = 클라 BindToRenderStep.

### 예산 초과 단순화 내역(make_gear_v3.py · 첫 생성 → 최종 · 삼각형)
| 부위 · 단계 | 무엇을 줄였나 | 전 → 후 |
|---|---|---|
| 장갑 쌍 s3 ~ s5(4직업) | 바탕 장식을 직업 v3.1 "legendary"(테 · 징) → "normal" 고정 · 단계 차이 = 손목 테 1줄 + 색 | 대검 672 → 424 · 쌍검 760 → 448 · 활 600 → 352 · 치유사 600 → 352 |
| 신발 쌍 s3 ~ s5(4직업) | 위와 같음 · 대검 정강이 테 뺌(바탕 판금 테가 이미 있음) | 대검 800 → 488 · 쌍검 656 → 408 · 활 672 → 424 · 치유사 688 → 440 |
| 쌍검 장갑 s3 ~ s5 | 손목 테 뺌(바탕 가죽 끈 셋이 테 역할) | 512 → 448 |
| 갑옷 s5(대검) | 어깨 s2 테를 s5에서 뺌(왕관 마루가 대신) · 왕관 마루 3 → 2 · 문장 받침 테 s5 뺌(목깃 · 균열이 대신) · 목깃 10 → 8각 | 1,644 → 1,452 |
| 갑옷 s5(치유사) | 위와 같음 + 부유 성물 고리 3 → 2 · 고리 8 → 6각 | 1,734 → 1,474 |
| 갑옷 s4(치유사 · 대검) | 문장 받침 테 10 → 8각 · 핵심 보석 집계 = 문 파트(루비 · 에메랄드) 중 보이는 하나 | 치유사 1,514 → 1,490 · 대검 1,500 → 1,488 |
| 무기 치유사 s1 · s3 · s5 | 날 아닌 파트 모따기(bevel) 뺌(옛 make_weapons와 같게) · s5 태초 빛 테(Halo) 뺌(초월 균열 자리) | s1 748 → 398 · s3 1,296 → 658 · s5 1,381 → 794 |
| 무기 활 s5 | 태초 빛 테(Halo) 뺌 | 895 → 796 |
- 최종 최대: 갑옷 1,490(≤ 1,500) · 장갑 쌍 448 · 신발 쌍 488(≤ 500) · 무기 796(≤ 800) · 핵심 보석 96(≤ 120) · 부유 합 64(≤ 300) · 보이는 파트(방어구 3부위) 최대 15(≤ 24 - 무기 별도 최대 14).

### 대기 중 큐 실행 순서
1. QUEUE-ALL9E1 남은 블록: 1-1 나머지 → 1-2 → 2 → 3(보석 홈 화면 추가 항목 포함) → 4
2. QUEUE-ALL9E1-ADD: F(전갈 여왕 외형 - 장비 v3 뒤) · 보고서 F절
3. QUEUE-MENU2: A → G

### 정지 때 검사(실패해도 고치지 않고 기록)
- run_all: 전부 통과(security_launch 45/45 · save_launch 65/65 · save_lock 12/12 · migrate_curve 21/21 · id_quarantine 15/15 · monetize 85/85 · dupe O 11 / X 0 · multiplayer 12/12 · attack 7/7 · request_gate 7/7 · mesh_import 34/34 · ops_security 25/25 · season_pass 13/13 · economy_all9b 34/34 · enhance_g 25/25 · bignum 67/67(알려진 문제 4) · bulk_sell 11/11 · stat_sheet 9/9 · all10 55/55 · monster_stats 5/5 · ui_rules 4/4 · community_goal 24/24 · boss_motion 점프 0 · regrow_timing 8/8 · meshswap O · id_registry 통과).
- luau-analyze(이번 큐에서 바뀐 Lua 44개): 1,507줄 중 1,479줄 = TypeError · UnknownType(Roblox 타입 정의 없이 돌린 환경 잡음) · 린트 5줄 = DevTools SameLineStatement 4(2958 · 2981 · 2992 · 4464) · SaveSystem MisleadingAndOr 1(2233) - 모두 이번 큐 이전 코드(git blame 9-16 · 9-24 · 10-02) · 이번 큐 코드의 린트 경고 0.

## 결정 기록
- 0-1: 옵션 A(회복 보조 없음) - 기록만.
- 0-2: 계승 결과 무기 강화 단계 = +30 몫(어디서 왔든 같은 초월 +0) - D1 "초월 +0 = 태초 +30 × 1.25" 정의를 지킴.
- 0-2: +29에서 강화 창은 보통 강화 + [초월 계승] 보조 버튼(+30 도전을 막지 않음).
- 0-2: EconSim은 +29 도달 즉시 계승(증표는 경제 가치 없음).
- 0-3: 운 나쁜 P90 시드 = 새 규칙의 +29 기준 20316356(옛 20292599는 새 규칙에서 가장 늦음).
- 0-4: +6 이상 단계당 ×1.22(처치 시간 −18%) · 기준 빌드도 같은 배수 꼴.
- 0-5: launchEpoch = "prelaunch1"(출시 때 바꿈) · 개발 계정 = LeaderboardConfig.excludedUserIds.
