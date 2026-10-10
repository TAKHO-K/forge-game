# UI-1 상태

- 지시 = `C:\Users\xkrgh\vibe\claude-design-handoff\CC-UI-1-prompt.md`(10-10 · 묶음 A~H를 게임에 넣기). 자동 압축 · 사용량 한도 뒤 이 파일 + 지시 파일을 다시 읽고 "다음 시작"부터.
- 규칙: force-push · 패키지 설치 · rojo serve 건드리기 · DataStore · 자산 · 파일 삭제 금지 · `BossFrameworkData.live = {}` 유지 · 저장 필드 추가만(addedFields) · API 키 출력/커밋 금지 · 단계마다 하네스 → 커밋(단계 번호) → push → 이 파일 갱신 → 캡처 `docs/design/ui1/<단계>/`.
- 사용자 확인 기다리지 않음(막히는 결정만 질문).

| 단계 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| 0 바닥 코드 | 완료 | (이 커밋) | HudPlace(폰 판정 · m · 상단 바 아래 기준 y · B-7 접기) · v6 배치표 · hud_layout 하네스 13/13 · 오른쪽 열 인셋 이중 차감 실측 수정 · 폰 전투 버튼 = 데이터 · 우리 점프 · 지도 핀 키 · BossEnraged · Haptics · UiV2Flags |
| 1 A 공용 부품 | 진행 중 | | |
| 2 B 전투 HUD + B v2 스킬 칸 | 대기 | | |
| 3 F 보스 창 | 대기 | | |
| 4 C 가방 · 장비 | 대기 | | |
| 5 D 도감 | 대기 | | |
| 6 E 강화 불씨 | 대기 | | |
| 7 F 자동 창 | 대기 | | |
| 7b G 지도 · 설정 · HUD 편집 | 대기 | | |
| 7c H 알 · 펫 · 캐릭터 · 상점 | 대기 | | |
| 8 캡처 · 보고 | 대기 | | |

다음 시작 = 1단계(00 v8 spec · MISSING · checklist 읽기부터).
