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

| 1 | 1-1 장비 v3 메시 | 진행 중 | (이 커밋) | make_gear_v3.py(60 + 문장 6 + 무기 20 생성 · 예산 안 - 방어구 최대 1,490 · 무기 최대 796 · 보이는 파트 최대 15) · GearV3Data · 아직 FBX 내보내기 · 업로드 · 게임 연결(ArmorWearView · 색 함수 · 스위치 GearV3Meshes) · 캡처 안 함 |

## 다음 항목
블록 1-1 이어서: ① `bash roblox/tools/blender/bl.sh make_gear_v3.py --weapons --emblems --export`(armor_wear.meta.json 합침 → meta_to_luau) ② 렌더 확인(--render) ③ upload.py 업로드(armor/*_s[1-5].fbx · emblem_* · weapons/*_s[1-5].fbx) ④ 클라 ArmorWearView: GearV3Meshes 켬 = armor/<부위>_<직업>_<단계> · 색 = 구역(GearV3Data + ItemVisualData) · 문(Ep · Re · An · Tr) 파트는 그 등급만 · 문장 메시 ⑤ 48조합 예약 색 하네스 ⑥ Play 캡처. 남은 블록 = 1-2 · 2 · 3(+ 추가 항목) · 4 → ADD F → MENU2

## 결정 기록
- 0-1: 옵션 A(회복 보조 없음) - 기록만.
- 0-2: 계승 결과 무기 강화 단계 = +30 몫(어디서 왔든 같은 초월 +0) - D1 "초월 +0 = 태초 +30 × 1.25" 정의를 지킴.
- 0-2: +29에서 강화 창은 보통 강화 + [초월 계승] 보조 버튼(+30 도전을 막지 않음).
- 0-2: EconSim은 +29 도달 즉시 계승(증표는 경제 가치 없음).
- 0-3: 운 나쁜 P90 시드 = 새 규칙의 +29 기준 20316356(옛 20292599는 새 규칙에서 가장 늦음).
- 0-4: +6 이상 단계당 ×1.22(처치 시간 −18%) · 기준 빌드도 같은 배수 꼴.
- 0-5: launchEpoch = "prelaunch1"(출시 때 바꿈) · 개발 계정 = LeaderboardConfig.excludedUserIds.
