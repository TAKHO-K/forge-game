# QUEUE-UI2 상태

- 받음: 2026-10-05 · 지시 = 사용자 메시지(새 디자인 묶음 적용 · 지난 UI1F 내용 포함 → 끝나면 기존 큐) · QUEUE-UI1F는 이 큐로 합쳐짐(UI1F-1 진행분 = UI2-3 일부).
- 자동 압축 뒤: 이 파일 + QUEUE-UI1F-state.md · QUEUE-UI-state.md · QUEUE-MENU2-state.md 다시 읽고 이어서.
- 공통 규칙: 파일 · 에셋 · DataStore 삭제 금지 · 저장 필드는 추가만(SlotSaveData.addedFields 등록 + 하네스 slot_save) · rojo serve 시작/중지/재시작 금지 · 패키지 설치 금지 · 커밋 전 삭제 파일 0개 · 업로드 = roblox/tools/opencloud/upload.py만(키 값 출력 · 기록 금지).
- "지금 하는 항목까지만 마치고 멈춰" = 그 항목 끝내고 멈춤.

| 항목 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| UI2-3 일부(옛 UI1F-1): 테스트 플래그 서버 경고 · 소식 빨간 점 · 총 0시간 · 폰 뒤로 버튼 2곳 | 완료 | (이 커밋) | 아래 "UI1F-1 결과" |
| UI2-0 묶음 풀기 + 저장소 spec 커밋 | 완료 | (이 커밋) | 4묶음 zip → 최상위 폴더 벗겨 assets · mockups · prototype(00 96 · 01 58 · 02 56 · 03 73 파일 복사 · 덮어쓰기 0 · zip 그대로) · zip 안 MISSING.md는 빈 파일 → 기존(설계 담당 "없음") 유지 · 저장소 docs/design/handoff 4폴더 spec · checklist · MISSING 커밋 |
| UI2-1 에셋 올리기 · 이름 하나로(해시 별칭) | 완료 | (이 커밋) | 해시 비교: 01 = 00과 같은 이름 36 + 새 8 · 02 = 같은 이름 28 + 별칭 17(icon-attack-* → atk-* · menu-* → bag · book · party2 등) + 새 3 · 03 = 전부 00과 같음 · 같은 이름 다른 내용 0 · 업로드 = 00 90장(ui/ds) + 01 얼굴 2 · 자리표시 2(ui/legends - 전설 2장은 이미 올림 · 같은 해시) + 02 disc · ring · star4(ui/hud) = 97 Decal Approved + 이미지 id 97 · 키 아트 jpg 2장 = 이미 쓰는 menu_keyart_v2_L/R png와 같은 그림(upload.py는 png만) → 안 올림 · 아이콘 표 UiIconData = 00 아이콘 32 + 별칭 17 + old(옛 icons/hud 13) · 하네스 ui_v2 아이콘 v2 이미지 · old · 별칭 |
| UI2-2 UI-0 갱신(토큰 · 9-slice · 포커스 링 · 버튼 손맛 · 글자 · 글자 크기 설정) | 완료 | (이 커밋) | 보고서 UI2-2 절 · shared/ButtonPress + UiKit.attachPress · 토큰 00 값 · 글자 원인 = 루트 UIScale(0.548) → textMinRootScale · 설정 textScale · PreferredTextSize 읽기 전용(실기기 확인 필요) · ui_v2 47/47 · run_all 전부 · Play PC |
| UI2-3 01 메인 메뉴 v2(아이콘 표 · 키 아트 cover · 캡처) | 진행 중 | | |
| UI2-4 02 HUD v3 | 대기 | | |
| UI2-5 03 가방 · 장비 + 보석 홈 v1 | 대기 | | |
| UI2 보고 | 대기 | | |
| 기존 큐 1) MENU2 B2 ~ B5 · 2) DESIGN-BACKLOG · 3) ALL9D · 4) SEC2 · 5) PERF1 준비 | 대기 | | |

## UI1F-1 결과(UI2-3 일부)
- 테스트 플래그: 클라 `MenuGate.shouldSkip`은 이미 `isStudio`일 때만 인정 → 서버 `SlotServer` 시작 · 속성 변경 때 `MenuGate.liveWarning` 경고 1줄(실서버 + 값 있음). 하네스 menu_gate 14/14(+4).
- 소식 빨간 점: `SocialRewardData.news[].id` · 계정 설정 `lastSeenNewsId`(stamp · 기본 0 · SlotSaveData.addedFields 등록) · `UiModel.newsDot` · [소식] 열면 최신 id 저장. 하네스 ui_v2 +6 · Play(폰): 점 표시 → [소식] → 점 꺼짐 · 서버 속성 LastSeenNewsId = 2.
- 총 0시간 원인: ① 이관(`SlotSave.splitLegacy`)이 옛 계정 플레이 시간(`audit.playSeconds`)을 어느 캐릭터에도 안 넣음(v74 = 직업 칸 0) → 고침: 이관 첫 캐릭터(지금 직업)에 한 번(`legacyPlayAdded` 표시) · 이 수정 전 이관 계정은 로드 때 같은 캐릭터에 한 번. ② Studio = 매 Play 실제 옛 키로 다시 시드 + 개발 계정 옛 키에 audit 기록 없음 + 시간 내림(1시간 미만 = 0) → 테스트 데이터. 누적 자체는 동작(이번 Play 도적 351초). 하네스 slot_save 57/57(+5).
- 폰 뒤로 버튼: 이어하기 [<] = { 8, 2, 44, 44 } + 흰 테두리 끔(`slotCloseRing`) → 머리 48 안 · 직업 선택 [<] = { 20, 62 }(이어하기 [<]와 같은 화면 자리) · 목록 y 114. Play 폰 캡처 확인.
