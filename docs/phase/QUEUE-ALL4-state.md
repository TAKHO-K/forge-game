# QUEUE-ALL4 상태 (출시 전 안정화 · 재개 = "QUEUE-ALL4 이어서")

입력: 사용자 지시 "[바로 실행] [속도 우선 모드] QUEUE-ALL4"(A ~ G) · 읽은 것 = COMMON §0 · §7 · STATE · QUEUE-ALL1 · 2 · 3 보고서 · security-audit-alpha · save-audit-alpha.
산출물 = docs/phase/QUEUE-ALL4-report.md · Claude outputs/QUEUE-ALL4/.

| 항목 | 상태 | 커밋 | 메모 |
|---|---|---|---|
| A1 아레나 4종 캡처 | 완료 | 3c5236b | 화로가 전경에서 점 → 그릇 5.6 · 불 3.8 · 빛 26 (재캡처는 Rojo 재연결 뒤) |
| A2 활강 거품 · 남의 시점 · 폰 800×360 HUD | 부분 | 68aa1bf | 남의 시점(더미) 완료 · 활강 = 캐릭터 공중 고정으로 실패 · 폰 HUD = Rojo 재연결 뒤 |
| A3 무기 손 크기 기준 | 완료 | 343fdc8 · 3c5236b · 68aa1bf | OriginalSize 비율 · 0.8 · 1.35 캡처 · 1.35 이름표 겹침 수정(Play 미확인) |
| A4 땅 치기 타격감 | 완료 | 343fdc8 · 3c5236b | 전후 캡처 · 파편 크기 키움(재캡처 대기) |
| A5 /gg capture · 썸네일 · 아이콘 재촬영 | 부분 | 343fdc8 | 명령 완료 · 재촬영 = Rojo 재연결 뒤 |
| B 보안 점검 + 수정 | 완료 | 4acb9e3 | 41/41 · 리뷰 진행 중 |
| C 저장 · 예산 | 완료 | 360cdb0 | 58/58 · 리뷰 진행 중 · 동반 검증 Play 대기 |
| D 성능 | 부분 | caeb4e2 · 228938b | 도구 · 절차서 완료 · 측정 = Rojo 재연결 뒤 |
| E 영어 준비 | 완료(캡처 대기) | cee8832 | 1,374키 · 876개 이동 |
| F 출시 체크리스트 | 완료 | 68aa1bf | |
| G 전체 회귀 · 정리 | 진행 | | 로컬 하네스 서브에이전트 · EconSim 로컬 · Studio 블록 대기 |

## 가정 · 결정 기록
- SAVE_VERSION은 이미 61(ALL3) - 지시의 "v59까지"는 현재 버전(v61)까지로 읽는다.
- A3 손 배율 기준 = RightHand.Size ÷ OriginalSize(패키지 손 크기가 제각각 - 개발 계정 손 Y 0.89). 활 몸은 배율 밖(손 자리만).
- A4 "전" 캡처 = FxScale 0(새 무게감만 꺼짐 - 옛 동작과 같음).
- 10-01 Play 중 rojo serve 프로세스가 꺼져 있었음(원인 미상) → 다시 켰으나 Studio 플러그인 Connect는 사용자만.
