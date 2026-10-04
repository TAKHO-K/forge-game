# 디자인 묶음(보류) 목록

> 사용자 결정(2026-10-04 밤): 장비를 전부 갈아엎을 예정 → 겉모습(디자인) 작업은 나중에 한 번에. 기능 작업부터. 아래 항목은 **손대지 않는다**(기능 쪽 연결 지점 · 임시 그림만 허용).
> 지시 원문 = `docs/phase/QUEUE-ALL9E1-prompt.md` 끝 "사용자 결정(10-04 밤): 장비를 전부 갈아엎을 예정".

| # | 항목 | 출처 큐 · 블록 | 지시 원문 위치 | 멈춘 시점 · 남은 것 |
|---|---|---|---|---|
| 1 | 장비 3D(LOOK 계열) 다듬기 | QUEUE-ALL9E1 · LOOK1 ~ LOOK3 | `QUEUE-ALL9E1-prompt.md` "추가 항목 LOOK1" · "LOOK2" · "LOOK2 판정 → LOOK3" · "LOOK3 판정" | LOOK3 임시 확정(게임에 켜져 있음) · 장갑/신발 형태 보강 등 반복 수정 중단 |
| 2 | 아이콘 다시 렌더(128 · 갑옷 LOOK3 아이콘 연결 포함) | QUEUE-ALL9E1 · 블록 3 · LOOK3 C | `QUEUE-ALL9E1-prompt.md` "블록 3. 아이콘 128" · "LOOK3 판정" 3번 | LOOK3 아이콘 96장 업로드됨(`roblox/art/icons/gear_v3_look3/` · 연결 안 함) · 갑옷만 교체 결정은 받음 - 연결은 디자인 묶음 때 |
| 3 | 무기 사다리 캡처(⑤ 4×4) | QUEUE-ALL9E1 · 1-2 시안 비교 | `QUEUE-ALL9E1-prompt.md` 블록 1-2 · gear-art-v3.md 9절 | 4직업 × 일반 · 전설 · 태초 · 초월 무기 복제 배치까지 Play에서 함(캡처 저장 안 함) · 보류(디자인) |
| 4 | 1-2 달리기 · 공격 · 활강 외형 캡처 | QUEUE-ALL9E1 · 1-2 | 같은 곳 | LOOK3 초월 4직업 캡처 1장 커밋됨(`captures/look3/look3_1-2_run_attack_glide_4classes_transcendent.jpg`) · 새 장비로 다시 |
| 5 | 시안 비교(② ③ ④ ⑤ ↔ GPT 원본 · `docs/art/ref/compare/`) | QUEUE-ALL9E1 · 1-2 | `QUEUE-ALL9E1-prompt.md` 블록 1-2 | 안 함 |
| 6 | 512 큰 무기 그림(보석 홈 화면 전용) | QUEUE-ALL9E1 · 추가 항목(10-04 밤) 2번 | `QUEUE-ALL9E1-prompt.md` "추가 항목(10-04 밤)" 2 | 안 함 - 기능(장착 무기로 자동 교체)은 지금 아이콘으로 진행 |
| 7 | 보석 아이콘 새 그림(종류 × 등급 · 광채 규격) | QUEUE-ALL9E1 · 추가 항목 3번 | 같은 곳 3 | 안 함 - 아이콘 id 한 소스 연결 로직 · 임시 아이콘은 기능으로 진행 |
| 8 | 보석 광채(유물 ~ 초월 · 방법 3개 비교) | QUEUE-ALL9E1 · 블록 2-1 | `QUEUE-ALL9E1-prompt.md` 블록 2-1 | 안 함 |
| 9 | 무기 이펙트 실제 모양(+0 ~ +25 · 직업별 타격 · +30 증표 이펙트) | QUEUE-ALL9E1 · 블록 2-2 | `QUEUE-ALL9E1-prompt.md` 블록 2-2 | 안 함 - 단계 판정 · 연결 지점은 기능으로 진행(효과는 기존 것 재사용) |
| 10 | 보석 홈 광원(등급 · 홈 위치별) | QUEUE-ALL9E1 · 블록 2-3 | `QUEUE-ALL9E1-prompt.md` 블록 2-3 | 안 함 |
| 11 | generate_mesh 메시 생성 시험 | QUEUE-ALL9E1 · LOOK3 판정 뒤 | `QUEUE-ALL9E1-prompt.md` "LOOK3 판정" [메시 생성 시험] | 완료 · 보고서 `QUEUE-ALL9E1-MESHGEN-report.md`(추가 시험은 보류) |
| 12 | 전갈 여왕 외형 | QUEUE-ALL9E1-ADD · 블록 F | `QUEUE-ALL9E1-ADD-prompt.md` 83줄 "F. 전갈 여왕 외형 개선" | 안 함 |
| 13 | 치장(시안 v2 · 불씨 v3 구현) | 치장 시안 등록(ALL9E1 사용자 추가) | `docs/design/cosmetics-v3.md` · `docs/art/ref/gpt-gear-index.md` 치장 표 | 구현 안 함(검수 대기) |
| 14 | 메뉴 · 화면 꾸밈(색 · 배치 · 장식) | QUEUE-MENU2 · E · F | `QUEUE-MENU2-prompt.md` E · F + LOOK3 판정 지시 "MENU2는 기능까지" | MENU2는 기본 모양으로 기능만 · 꾸밈은 Claude Design 목업 확정 뒤 |
| 15 | 직업 선택 전설 그림 처리(배경 제거 · 퍼펫 모양 다듬기) | QUEUE-MENU2 · F | `QUEUE-MENU2-prompt.md` F · `QUEUE-MENU2-state.md` F 메모 | 동작은 지금 그림(전사 · 궁수) + 임시 실루엣으로 기능 진행 · 모양 다듬기는 보류 |
