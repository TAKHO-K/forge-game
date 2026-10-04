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
| UI2-3 01 메인 메뉴 → v3 기준(키 아트 초점 · 좁은 창 · 아이콘 v2 · 글자 1.3 · 캡처 35장) | 완료 | (이 커밋) | 보고서 UI2-3 절 · 01_main-menu\v3\play · ui_v2 56/56 |
| (추가 10-05) 새 묶음 00 v2 · 01 v3 · 02 v4 · 03 v2 | 풀기 · spec 커밋 · 에셋(스킬 16장) 완료 | 9bec2db4 · (spec 커밋) | 남은 UI2는 새 버전 기준 · 01 v3 키 아트 초점 규칙(MenuArtFit.place) · 좁은 창 모드 · 글자 단계 = 00 v2(토큰 값 같음) |
| (추가 2 · 10-05) 00 v3 · 02 HUD v5(메뉴 재배치 · 보상 창 · 환생 경로 · 잠긴 스킬 말풍선 · 키 칩 = PanelRegistry · 미니맵 자리) | 완료 = UI2-4 | ee48a73a · (이 커밋) | 업로드 = 해시로 새것 · 바뀐 것만(icon-zone · training · reward · skill-greatsword-t · dualblade-q) |
| (판정 10-05 · HUD 끝난 뒤) UI2-3 보정 | 완료 | (이 커밋) | ① 좁은 창 모드 = 얼굴 · 대검 가림 또는 메뉴 패널 ↔ 이어하기 창 간격 < 24px(값 = 데이터) · 좁은 창 모드 창 폭 = 16:9와 같게 ② 카드 줄바꿈 = 숫자 + 단위 한 덩어리("1분 전" · "스테이지 21" · "환생 4회") ③ PreferredTextSize = 큰 쪽 하나 유지(실기기 = 사용자 출시 전) ④ 재캡처 keyart_pc-4x3_open · keyart_pc-4x3_closed · text-1.3_pc_continue → 이름 뒤 _v2(덮어쓰기 금지) |
| UI2-4 02 HUD → v5 기준 | 완료(판단 3 · 캡처 일부 남음) | (이 커밋) | v4 큰 글자 예외 3 · 빨강 규칙 · 스킬 칸 icon-skill · PC 파티 Y 568 · Play 관찰 3건(키 칩 "키" 글자 · PC 오른쪽 위 재화/스테이지/퀘스트 안 보임 · 알림 띠 아이콘 자리표시) |
| UI2-5 03 가방 · 장비 + 보석 홈 → v2 기준 | 1차 완료(겉모습 전체 재구성 남음) | (이 커밋) | 가방 [분해] [판매] = 보조(남색) |
| (판정 10-05) UI2-5 1차 통과 · 2차 = 03 v2 겉모습 전체 재구성 | 다음 | | 9-slice 칸 틀 · 그림 탭 6 · 반원 홈 5 + 위 무기 무대 · 폰 분해 아래 시트 · 1.3배 폰 가방 + 남은 캡처 7장 · **보석 홈 무기 = 512 렌더 없음(원본 안 만듦) → 장착 무기 실제 3D 모델 ViewportFrame**(회전 · 현재 강화 단계 이펙트 · 장착/계승/캐릭터 전환/강화 때 즉시 갱신) · 그래픽 품질 낮음/폰 성능 낮음 = 128 아이콘(스위치) · 그림 파일 만들지 않음 - 장비 3D 재작업 뒤에도 그대로 동작 |
| (끼워 넣기 10-05) ART-REF 현재 모습 자료집(읽기 전용 · 1 ~ 2시간) | 완료 | (이 커밋) | 결과: handoff 30_hub-art\_ref PNG 26(전체 4방향 + 위 + 마을 높이 · 거리 4 · 건물/소품 8 + 환생 제단 · NPC 7 = 5 + 보석상인 + 크기 기준 플레이어) · 31_bosses\_ref PNG 12(보스 6 × 2각도 - /gg boss anim idle 전시 리그) · ref.md 2개 = 저장소 docs/design/handoff/30_hub-art · 31_bosses/_ref · 코드 변경 0 | 보스 6 · 마을 NPC 7 · 건물/소품 8 · 마을 전체 = 4방향(+위) 캡처 + 표 → handoff 30_hub-art\_ref · 31_bosses\_ref(PNG + ref.md) · 저장소 = ref.md만 · 결정 문서 world-art-track(저장소에 없음) |
| UI2-5 2차 - 2-1 창 · 머리(64 + 노랑 줄) · 탭(btn-tab 9-slice · 폰 그림 44) · 칸 틀(btn-card 9-slice) · 상세 버튼 줄(장착 노랑 + 보조) | 완료(PC Play 확인 · 폰 그림 탭 확인은 2-4) | (이 커밋) | 구조 = 기존 장비창 모듈(Shell · BagTab · ItemCell · DetailCard) 겉모습만 교체 · 기능 그대로 |
| UI2-5 2차 - 2-2 등급 골라 분해(PC 640×480 창 · 폰 아래 시트 784×232) | 다음 | | 판단: 지금 규칙 = 일반 · 희귀 판매 · 영웅 이상 분해(Loot.isBulkDismantleTarget) · 일괄 판매 · 자동 정리 유지 |
| UI2-5 2차 - 2-3 보석 홈 무대(1000×560 · 반원 홈 5 · ViewportFrame 장착 무기 3D + 강화 이펙트 · 저품질 = 128 아이콘 스위치 · 보석함 가로 · 홈 상세) | 대기 | | |
| UI2-5 2차 - 2-4 폰 가방(5열 × 56 · 그림 탭) · 1.3배 넘침 없음 | 대기 | | |
| UI2-5 2차 - 2-5 남은 캡처 7장 + checklist 대조 | 대기 | | |
| UI2 보고 | 대기 | | |
| 기존 큐 1) MENU2 B2 ~ B5 · 2) DESIGN-BACKLOG · 3) ALL9D · 4) SEC2 · 5) PERF1 준비 | 대기 | | |

## UI1F-1 결과(UI2-3 일부)
- 테스트 플래그: 클라 `MenuGate.shouldSkip`은 이미 `isStudio`일 때만 인정 → 서버 `SlotServer` 시작 · 속성 변경 때 `MenuGate.liveWarning` 경고 1줄(실서버 + 값 있음). 하네스 menu_gate 14/14(+4).
- 소식 빨간 점: `SocialRewardData.news[].id` · 계정 설정 `lastSeenNewsId`(stamp · 기본 0 · SlotSaveData.addedFields 등록) · `UiModel.newsDot` · [소식] 열면 최신 id 저장. 하네스 ui_v2 +6 · Play(폰): 점 표시 → [소식] → 점 꺼짐 · 서버 속성 LastSeenNewsId = 2.
- 총 0시간 원인: ① 이관(`SlotSave.splitLegacy`)이 옛 계정 플레이 시간(`audit.playSeconds`)을 어느 캐릭터에도 안 넣음(v74 = 직업 칸 0) → 고침: 이관 첫 캐릭터(지금 직업)에 한 번(`legacyPlayAdded` 표시) · 이 수정 전 이관 계정은 로드 때 같은 캐릭터에 한 번. ② Studio = 매 Play 실제 옛 키로 다시 시드 + 개발 계정 옛 키에 audit 기록 없음 + 시간 내림(1시간 미만 = 0) → 테스트 데이터. 누적 자체는 동작(이번 Play 도적 351초). 하네스 slot_save 57/57(+5).
- 폰 뒤로 버튼: 이어하기 [<] = { 8, 2, 44, 44 } + 흰 테두리 끔(`slotCloseRing`) → 머리 48 안 · 직업 선택 [<] = { 20, 62 }(이어하기 [<]와 같은 화면 자리) · 목록 y 114. Play 폰 캡처 확인.
