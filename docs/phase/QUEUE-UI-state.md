# QUEUE-UI 상태

- 받음: 2026-10-05(메인 메뉴 버그 수정 진행 중) · 지시 = QUEUE-UI-prompt.md · 자동 압축 뒤 두 파일 + QUEUE-MENU2-state.md 다시 읽고 이어서.
- 순서: 메뉴 버그 → (B1 이미 완료 f23af11d) → UI-0 → UI-1 → MENU2 B2 ~ B5 · ALL9D 등과 번갈아.

| 블록 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| UI-0 기반(토큰 · 공용 부품 · 아이콘 표 · 좌표 표) | 완료 | 51d408e1 | shared/data UiTokens · UiIconData · UiLayoutData · shared/UiModel · client/ui/v2 UiRoot · UiKit · 공격 버튼 무기 아이콘 · ui_v2 21/21 · 부품 화면 확인은 UI-1에서 |
| UI-1 메인 메뉴(01 spec · checklist 14) | 완료(차이 1 · 남음 3 = 보고서) | 0e4896ad | client/ui/v2/MainMenuV2 · 스위치 MainMenuData.v2Menu · 배경 MenuBootData.layoutV2 · 캡처 12장 = handoff play 폴더 · 남음: pc_04 · pc_07 재촬영 · phone_04 · 소식 빨간 점 · MISSING 13 에셋 |
| 다음 | 대기 | | MENU2 B2 ~ B5 · C(DESIGN-BACKLOG 재정리) · ALL9D 등 · 02_hud v1 묶음 도착(docs/design/handoff/02_hud) |
