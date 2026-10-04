# QUEUE-MENU2 상태

- 받음: 2026-10-04(QUEUE-ALL9E1-ADD 블록 B · C · D 진행 중)
- 배치(지시 그대로 읽음): ADD가 전부 끝난 뒤 시작(홈 규칙 저장 v72 위에 얹는다). ADD F는 ALL9E1 장비 v3 뒤라 실행 순서 = ALL9E1 블록 0 + ADD A ~ E → ALL9E1 블록 1 ~ 4 → ADD F → MENU2 A ~ G.
- 시작: 2026-10-04 23:50 - 사용자 지시(10-04 밤): 장비 전부 갈아엎음 → ALL9E1 디자인 작업(1-2 시안 · 블록 2 · 3 · ADD F)은 나중에 한 번에 · MENU2를 먼저. MENU2는 저장 구조 · 메뉴 로직 · 이어하기/직업 선택 "기능"까지 · 화면 꾸밈(색 · 배치 · 장식)은 Claude Design 목업 확정 뒤 따로 지시 → 지금은 기본 모양.
- 자동 압축 뒤: QUEUE-MENU2-prompt.md · 이 파일 + ALL9E1 · ADD 상태 파일.

| 블록 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| A 조사 | 완료 | (이 커밋) | docs/design/menu2-survey.md(저장 v73 · migrate = SaveSystem.lua:479 · 결정 필요 목록 = 10절) |
| B 캐릭터 칸 저장 | 핵심 완료 · 남음(결제 하네스 추가 3 · EconSim 판단 · 운영 도구 키) | (이 커밋) | 설계 docs/design/menu2-slot-save.md · SlotSaveData · SlotSave(순수) · SaveSystem 슬롯 경로(계정 Acct_ + 캐릭터 Char_ · 옛 Player_ 읽기만) · v74(playSeconds · runtime) · 스위치 끔 = 합쳐 읽기(손실 0) · legacyRecheck · 하네스 slot_save 37/37 · 옛 저장 하네스 4개 = 끔 고정 · Studio Play 이관 4캐릭터 + 자동 저장 확인 · C 서버 직업 변경 거절(srv.class.newCharOnly) |
| C 메뉴 건너뛰기 제거 | 완료 | 617cf053 · b3cda5c4 · (이 커밋) | 서버 직업 변경 거절 · 캐릭터 창 [직업 변경] 숨김 + 안내 + [메인 메뉴로] · 옵션 UI = MainMenuData.skipMenuOption false(저장값 무시) · 직업 선택 안내 문구 고침 |
| D 메인 메뉴로 · 쿨/게이지 | 대부분 완료 | e8216486 · (이 커밋) | 쿨 · 게이지 · 위치 유지 · 설정 [게임] · 캐릭터 창 [메인 메뉴로](확인 창 · 금지 = 회색 + 이유) · 서버 SlotSwitch.toMenu(금지 상태 · 파티 해제 · 즉시 저장 · 캐릭터 빼기) · 메뉴 다시 열기(OpenMainMenu) · Play 확인. 남음: 하네스(금지 상태 · 파티 해제) · 강화/합성 연출 중 금지(클라 상태 - 미구현) |
| E 이어하기 창 | 핵심 완료(기본 모양) | (이 커밋) | ui/SlotWindow(오른쪽 0.25초 · 카드 = 직업 + ① · 레벨 · 최고 · 환생 · 무기 등급 테두리 + 강화 · 플레이 · 마지막 · 마지막 플레이 맨 위 선택 · 두 번 = 시작 · + 새 캐릭터 · 잠긴 칸 · ⋯ 보관 · 보관함 복구) · 서버 SlotSwitch/SlotServer(SlotRequest) · Play: 전환(도적 → 활) · 메뉴 왕복 확인. 남음: 폰 캡처 · 같은 직업 2개 캡처 · 연타 하네스 |
| F 직업 선택(방향 변경) | 기능 완료(그림 · 움직임 대기) | (이 커밋) | LegendData(스위치 avatarPreview = ClassSelectAvatarPreview false · transform = ClassSelectTransform false · 그림 자리 · anim 자리 · temp) · ui/LegendPlayer(재생기 자리 + 임시 실루엣 · 고를 때 강조 · 확정 섬광 → 액션 포즈 0.6초 → 진입) · ClassSelectUI(변신 무대 · [다시 보기] 끔) · Play: 새 캐릭터 → 궁수 ② 진입 |
| G 검증 · 보고 | 남음 | | |

## 끼워 넣기(10-05 · 사용자) - 메인 메뉴 배경 menu_keyart_v2 교체(상한 30분 · 지금 항목 끝난 뒤 바로)
[짧은 작업 · 지금 하는 항목 끝난 뒤 바로 · 상한 30분] 메인 메뉴 배경을 menu_keyart_v2로 교체(사용자 확정 그림).
1. 원본: roblox/art/ui/menu_keyart_v2.png(사용자가 넣음). 없으면 이 작업은 건너뛰고 "파일 없음"만 보고.
2. v1과 똑같은 방식으로 처리: menu_keyart_v1_L.png / _R.png / menu_keyart_v1.meta.json 만든 과정 그대로 → menu_keyart_v2_L.png · menu_keyart_v2_R.png · menu_keyart_v2.meta.json 생성(각 1024 이하 · 이어 붙인 경계선이 보이지 않게).
3. roblox/tools/opencloud/upload.py로 업로드 → 메인 메뉴 배경이 읽는 이미지 id만 v2로 교체(코드 구조 · 메뉴 배치는 건드리지 않음).
4. v1 파일 · v1 meta · v1 에셋 id는 삭제 · 덮어쓰기 금지(기록에 남김 — 되돌릴 수 있게).
5. 확인 캡처: PC 1920×1080 · 폰 800×360 각 1장. 메뉴 버튼 · 글자가 캐릭터 얼굴 4명과 전사가 쥔 초월 대검을 가리지 않는지 확인. 가리면 바꾸지 말고 겹치는 좌표만 보고(메뉴 배치는 Claude Design 목업 확정 후 따로 바꿀 예정).
6. .gitignore에 예외가 필요하면 menu_keyart_v2*만 추가. 커밋 1개(그림 · meta · 이미지 id 데이터) → 푸시(force 금지) · 삭제 파일 0개 확인.
7. 참고: 손잡이 · 단검 두 곳은 나중에 고친 그림이 오면 menu_keyart_v3로 같은 과정 반복 예정.
끝나면 원래 하던 순서대로 이어서.

### 끼워 넣기 결과(menu_keyart_v2) - 완료
- 절차 = docs/phase/all9c/menu-background.md 그대로(menu_bg.py → 좌우 2장 770×1024 · 가운데 2px씩 겹침 · upload.py Decal 72856913796131 · 106571649028543 Approved → 이미지 id 90708952668878 · 129274403210371 → menu_bg.py --gen menu_keyart_v2).
- 바뀐 것 = MenuBootData.lua BEGIN/END 사이(이미지 id 2개 · 출처 이름)만 · ArtAssetIds · asset-ids.json에 v2 줄 추가(v1 줄 · 파일 · meta 그대로 - 되돌리기 = `menu_bg.py --gen menu_keyart_v1`).
- 캡처: docs/phase/menu2/captures/menu_keyart_v2_pc_16x9.jpg(뷰포트 1052×592 - Studio 높이 상한 592라 1920×1080과 같은 16:9) · menu_keyart_v2_phone_800x360.jpg(800×361). 메뉴 묶음이 얼굴 4명 · 초월 대검을 가리지 않음(폰: 메뉴 오른쪽 끝 ≈ 34% · 전사 망토 끝 ≈ 37%) · 이음매 안 보임. .gitignore 변경 불필요(이미 추적 대상).
