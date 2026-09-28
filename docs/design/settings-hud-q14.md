# 설정 저장 + P4e HUD 점검 (QUEUE-10h Q14 · 2026-09-29)

## 1. 설정 저장(SAVE v54 `profile.settings` · 서버 `SettingsService` · 데이터 `SettingsData`)
| 키 | 적용 Attribute(클라 코드가 읽는 입구 - 전과 같음) | 기본 |
|---|---|---|
| cameraTopDown | CameraTopDown | 끔 |
| reduceFlashes(새) | ReduceFlashes - 관문 날씨 섬광 끔 · 피뢰침 방전 = 흰 번쩍 대신 35%만 밝게 · 태초 연출 화면 밝아짐 0(채도만) | 끔 |
| screenShake | SettingScreenShake · SettingBossScreenShake | 켬 |
| dimOthersTrail | SettingDimOthers(AttackTrail이 읽음) | 끔 |
| autoStage | AutoStage(AutoStage.server가 로드 때 이 값을 읽음 · Remote AutoStageSetting도 SettingsService.set으로 저장) | 보통 |
- 흐름: 설정 창 토글 → 클라 Attribute 즉시 + Remote SettingsSave(key, value) → 서버 검증(불리언 · 프리셋 id만) → 저장 → Attribute 다시 적용. 로드 때 `SettingsService.onLoaded`가 전부 적용.
- 버그 한 건(로컬 검증이 잡음): `type(v) == "boolean" and v or nil`은 false를 nil로 바꿔 "끄기"가 저장 안 됐다 → 분기로 고침.
- 주간 의뢰판 = G3 퀘스트 주간 5종(Q6)에 이미 통합 - 확인만.

## 2. P4e HUD(U1 기준 재점검)
| 항목 | 이번 | 근거 |
|---|---|---|
| 직업 변경 버튼 × 폰 조이스틱 구역 | 수정 | 버튼(24, 아래 −34)이 BL 예약(좌 40% × 하 45%) 안 → 폰에서 숨김 + 설정 창 [직업 변경] |
| 나머지(친구 부르기 · 파티 HUD 690 · 알림 행 터치 24 · 태초 띠 524 · 폰 태초 알림 12 · 도감 띠 · 큰 화면 대시 · 요청 배너 · 채팅 × 메뉴바) | Play G 캡처 + `[S06][UI]` 자체 점검 줄로 판정 | 결과 = 상태 파일 Play G 표 |
