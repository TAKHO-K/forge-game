# 00 디자인 시스템 — spec v3 (2026-10-05)

## 바뀐 것 (이 버전 v3)
- 빨강 규칙 2번 문장: "전투 HUD 위 빨강 = 알림 점 + 보스 체력 막대만".
- 스킬 아이콘 2장 다시 그림: `icon-skill-greatsword-t.png`(금빛 거대 검사 · 몬스터 위 · 틀 밖으로) · `icon-skill-dualblade-q.png`(분신 2 겹침). 나머지 14장 확정. 비교 = `mockups/pc_08_skill-icons-redraw.png`.
- 새 아이콘 3개: `icon-zone.png`(구역 선택 = 이정표) · `icon-training.png`(수련 = 허수아비 + 목검) · `icon-reward.png`(보상 = 리본 선물 상자). `icon-growth.png` = 성장(캐릭터).

## 바뀐 것 (v2)
- 색 규칙: 빨강 #F2453D 사용 제한 4줄 추가(아래 "UI" 표 밑).
- 글자 단계 개정: 폰 display 28 · title 22 · heading 18 · button 18 · body 16 · caption 14 · micro 13 / PC body 18 · caption 16 · micro 14. 폰 12 이하 금지.
- 설정 "글자 크기" 보통 1.0 · 크게 1.15 · 아주 크게 1.3 — 글자만 커짐 · 잘림 금지(목업 `pc_06`).
- 스킬 아이콘 16장 `icon-skill-<직업>-<칸>.png` 추가(목업 `pc_07`).
- 폰 창 머리 48 확정 · 아이콘 색 4곳 · 버튼 외곽선 2~3px · 추가 아이콘 9개 · `btn-primal` 확정(v1에서 제안 → 채택).
- **파일 이름 = 이 묶음(00) 이름만** — 01 · 02 · 03도 같은 이름을 씀.

> 캔버스 "장비 아바타 정비 가이드" › 페이지 **디자인 시스템 · 장비** 의 시트(디자인 시스템 · 아이콘 v2 · 버튼 상태 · 보석 아이콘 · 07-C 초월 사다리)가 정답 그림. 01 · 02 · 03 화면 묶음은 모두 이 문서를 기준으로 함.

## 원칙
- 색은 아래 토큰 HEX만. **그림자 · 흐림 없음**(UICorner · UIStroke · UIGradient · 9-slice · ImageLabel만).
- 이미지 1024px 이하 · 투명 PNG. 파일 이름 = 영문 · 숫자 · 하이픈 · 밑줄.
- 기준 해상도: PC 1920×1080 · 폰 800×360(가로). 폰 왼쪽 위 = 로블록스 버튼 자리(비움). 폰 버튼 44px 이상 · 버튼 사이 8 이상.
- 글꼴: 한글 = 로블록스 기본 글꼴 Bold + 외곽선 · 숫자 · 영문 = 카툰 글꼴(Fredoka 계열). 한 줄에 섞지 않음.
- **모든 그림 = 굵은 진한 외곽선 · 색보다 형태로 먼저 읽힘.** 강조색이 보스 경고색(빨강 · 진한 주황)과 겹치지 않게.
- 상점 · 패스 아이콘과 문구 = "더 화려하게 / 힘 아닌 편의"까지만. "X2 성장 · X2 돈 · 더 강하게" 같은 표현 · 그림 금지.
- 숫자 · 이름은 게임 데이터에서 읽음(목업 숫자 = 예시).

## 색 토큰 — 등급 8색 (README 확정)
| 등급 | 메인 | 글자 위 | 글자용 밝은 톤 | 비고 |
|---|---|---|---|---|
| 일반 Common | `#9299A1` | `#1B1F2E` | `#C3C7CB` | 테두리 금속 은 |
| 희귀 Rare | `#2478D4` | `#FFFFFF` | `#87B5E7` | 은 |
| 영웅 Heroic | `#7545C6` | `#FFFFFF` | `#B399E0` | 은 |
| 전설 Legendary | `#D87828` | `#1B1F2E` | `#EAB589` | 금 |
| 유물 Relic | `#B92F48` | `#FFFFFF` | `#D88D9A` | 금 |
| 고대 Ancient | `#087F82` | `#FFFFFF` | `#77B9BA` | 금 |
| 태초 Primordial | `#F7F5EF` + `#E95BC8` | `#1B1F2E` | `#E95BC8` | **흰 + 자홍 = 태초 전용** |
| 초월 Transcendent | `#202127` + `#D8B96E` | `#D8B96E` | `#D8B96E` | **검정 + 금 = 초월 전용** |

어두운 패널 위 글자에 등급색을 쓸 때는 "글자용 밝은 톤"(메인 55% + 흰 45%).

## 색 토큰 — UI
| 토큰 | HEX | 쓰는 곳 |
|---|---|---|
| dim | `#000` 투명 0.5 | 창 뒤 화면 어둡게(흐림 대신) |
| bg.deep | `#0E1120` | 가장 깊은 바탕 · 글자 외곽선 |
| panel.window | `#161A2B` | 창 몸통 |
| panel.section | `#20263A` | 창 안 구역 · 창 머리 · 카드 |
| panel.slot | `#2B3350` | 보조 버튼 · 꺼진 탭 · 칸 |
| panel.empty / locked | `#1A1F33` / `#121626` | 빈 칸 / 잠긴 칸 |
| line | `#3A4466` | 창 · 구역 UIStroke |
| text.primary / secondary / muted | `#FFFFFF` / `#B8C0D6` / `#7D87A3` | 본문 / 설명 / 비활성 |
| accent | `#FFC83D` (입술 `#C9901A` · 누름 `#E6B02F` · 위 글자 `#3A2A12`) | 주 버튼(창마다 1개) · 켜진 탭 |
| success | `#3FC97A` | 토글 켜짐 · ▲ 수치 · 내 체력 |
| warning | `#F2453D` (입술 `#A82620`) | 위험 버튼 · 닫기 · 알림 점 · ▼ 수치 — **작게만**, 항상 모양(!, X, ▼)과 같이 |
| info | `#8FD8FF` | 안내 · 게이지 |
| plate.B (아이콘 판) | `#F3E7C2` (테두리 `#2B1B12` 3 · 입술 `#C9B48A`) | 메뉴 · HUD 버튼 판(양피지 크림) |
| outline.warm / cool | `#2B1B12` / `#1C2140` | 아이콘 외곽선(따뜻한 물건 / 쇠 · 마법) |

UI 노랑 `#FFC83D`과 초월 금 `#D8B96E`은 섞지 않음. 넓은 빨강 · 진한 주황 면 = 보스 경고색 → 창 머리 · 큰 바탕에 금지.

**빨강 `#F2453D` 사용 제한 (10-05 확정)**
1. 넓은 면 금지(버튼 하나 · 원 · 점 크기까지만).
2. 전투 HUD 위 빨강 = **알림 점 + 보스 체력 막대만**(보스 체력 = "적 체력 = 빨강" 장르 관습 · 다른 색은 내 체력 초록 · 게이지 하늘과 겹침).
3. 위험 버튼(빨강)은 **확인 창 · 확인 시트 안에서만**. 창 본문의 [분해] · [판매]는 보조(남색).
4. 닫기 빨간 원은 유지.
이유: 보스 경고는 3D 바닥 · 몸 표시라 UI와 층이 다르고, 빨강을 다른 색으로 옮기면 등급 8색(유물 `#B92F48`도 빨강 계열)과 겹침.

## 글자 크기 (TextSize 고정 · PC / 폰)
| 토큰 | PC | 폰 | 용도 |
|---|---|---|---|
| display | 48 | 28 | 결과 연출 · 메뉴 제목 |
| title | 32 | 22 | 창 제목 |
| heading | 24 | 18 | 구역 제목 · 아이템 이름 |
| button | 20 | 18 | 버튼 글자 |
| body | 18 | 16 | 본문 · 수치 |
| caption | 16 | 14 | 설명 · 라벨 |
| micro | 14 | 13 | 칸 안 숫자 = 카툰 숫자 글꼴 + 외곽선(폰 13 = 최소 · 12 이하 금지) |

TextScaled 끄기 · 시작 시 PC/폰 판정 후 값 세트 선택 · heading 이상은 UIStroke 2 `#0E1120`.

### 설정 "글자 크기" (10-05)
| 설정 | 배율 | 폰 caption / body / button | PC caption / body / button |
|---|---|---|---|
| 보통(기본) | 1.0 | 14 / 16 / 18 | 16 / 18 / 20 |
| 크게 | 1.15 | 16 / 18 / 21 | 18 / 21 / 23 |
| 아주 크게 | 1.3 | 18 / 21 / 23 | 21 / 23 / 26 |

- **글자만** 커짐: TextSize = 단계 값 × 배율(반올림). 아이콘 · 칸 · 버튼 · 창 크기는 그대로.
- 버티는 법: 글자 칸 AutomaticSize = Y + TextWrapped = true(줄바꿈 · 높이 늘림) · 목록은 ScrollingFrame. **잘림 금지.** 이름 · 아이템 이름처럼 한 줄 필수인 곳만 TextTruncate = AtEnd(…).
- 고정 크기 버튼 안 짧은 글자(폰 잠긴 스킬 "환생 N")는 큰 글자에서 짧은 표기("N")로 바꿈 — 각 화면 spec에 예외로 적음.
- 저장 = 플레이어 설정(기기 아님) · 기본 보통. 목업 `mockups/pc_06_text-size-setting.png`.

## 간격 · 모서리 · 선
- 간격(4 단위): s1 4 · s2 8 · s3 12 · s4 16 · s5 24 · s6 32. 폰은 한 단계씩 작게(창 여백 24 → 12). 터치 버튼 사이 최소 8.
- 모서리: r1 6(배지) · r2 10(칸 · 탭) · r3 12(버튼 · 구역) · r4 16(창) · full(토글 · 원). 폰 칸 8.
- 선 두께: 창 3 · 구역 2 · 칸(등급) PC 3 / 폰 2 · 글자 외곽선 2.

## 창 · 탭 · 토글
| 요소 | 규칙 |
|---|---|
| 큰 창 | PC 1600×880 · 화면 가운데 · Frame `#161A2B` + UICorner 16 + UIStroke 3 `#3A4466`. 머리 64(**폰 48** 확정) `#20263A` + 아래 노랑 줄 4. 폰 = 화면 꽉(가로 8 · 위 58 · 아래 8) |
| 확인 창 | PC 480×264 · 폰 360×220. 내용이 많으면 640×480(등급 골라 분해). 폰에서 고를 것이 많으면 아래에서 올라오는 시트. 합쇼체 · 왼쪽 [취소](보조 · 기본 선택) · 오른쪽 실행(위험이면 빨강) · X 없음 |
| 탭 | 높이 44 · 켜짐 = 노랑 + `#3A2A12` · 꺼짐 = slot + secondary · 새 항목 = 빨간 점 |
| 토글 | 트랙 56×32 · 터치 줄 높이 44 이상 · 켜짐 `#3FC97A` · 0.12초 |
| 칸 틀 · 강화 표시 | 06 칸 틀(등급 테두리 · 세트 문장 · 등급 마름모 · +N) · 07-B/07-C 강화 · 초월 사다리 그대로(`mockups/pc_05_transcend-ladder.png`) |

## 목업 파일

| 파일 | 내용 |
|---|---|
| `mockups/pc_01_design-system.png` | 디자인 시스템 v1 시트(10-05 개정: 버튼 상태 · 아이콘 v2) |
| `mockups/pc_02_icons-v2.png` | 아이콘 v2 시트(64 · 128 · 44 판) |
| `mockups/pc_03_button-states.png` | 버튼 상태 5개 비교 · 수치 · 동작 규칙 · SliceCenter |
| `mockups/pc_04_gem-icons.png` | 보석 아이콘 몸통 6 × 문양 9 |
| `mockups/pc_05_transcend-ladder.png` | 07-C 초월 사다리 +0~+25(아이콘 · 3D 공용 기준) |
| `mockups/pc_06_text-size-setting.png` | 설정 "글자 크기" 줄(PC · 폰 아주 크게) · 단계 × 배율 표 |
| `mockups/pc_07_skill-icons.png` | 스킬 아이콘 16장 · 폰 44/56 비교 · 상태 |
| `mockups/pc_08_skill-icons-redraw.png` | 스킬 아이콘 2장 다시(파괴의 화신 · 그림자분신) · 크기별 읽힘 |

## 에셋 파일 (게임에 실제로 넣을 그림 · 투명 PNG)

- `assets/btn-card-disabled.png`
- `assets/btn-card-hover.png`
- `assets/btn-card-normal.png`
- `assets/btn-card-pressed.png`
- `assets/btn-close-disabled.png`
- `assets/btn-close-hover.png`
- `assets/btn-close-normal.png`
- `assets/btn-close-pressed.png`
- `assets/btn-combat-disabled.png`
- `assets/btn-combat-hover.png`
- `assets/btn-combat-normal.png`
- `assets/btn-combat-pressed.png`
- `assets/btn-danger-disabled.png`
- `assets/btn-danger-hover.png`
- `assets/btn-danger-normal.png`
- `assets/btn-danger-pressed.png`
- `assets/btn-plate-disabled.png`
- `assets/btn-plate-hover.png`
- `assets/btn-plate-normal.png`
- `assets/btn-plate-pressed.png`
- `assets/btn-pri-disabled.png`
- `assets/btn-pri-hover.png`
- `assets/btn-pri-normal.png`
- `assets/btn-pri-pressed.png`
- `assets/btn-primal-disabled.png`
- `assets/btn-primal-hover.png`
- `assets/btn-primal-normal.png`
- `assets/btn-primal-pressed.png`
- `assets/btn-sec-disabled.png`
- `assets/btn-sec-hover.png`
- `assets/btn-sec-normal.png`
- `assets/btn-sec-pressed.png`
- `assets/btn-tab-off-disabled.png`
- `assets/btn-tab-off-hover.png`
- `assets/btn-tab-off-normal.png`
- `assets/btn-tab-off-pressed.png`
- `assets/btn-tab-on-disabled.png`
- `assets/btn-tab-on-hover.png`
- `assets/btn-tab-on-normal.png`
- `assets/btn-tab-on-pressed.png`
- `assets/focus-ring-circle.png`
- `assets/focus-ring-r10.png`
- `assets/focus-ring-r12.png`
- `assets/gem-body-ancient.png`
- `assets/gem-body-hero.png`
- `assets/gem-body-legend.png`
- `assets/gem-body-primal.png`
- `assets/gem-body-relic.png`
- `assets/gem-body-transcend.png`
- `assets/gem-mark-class.png`
- `assets/gem-mark-crit.png`
- `assets/gem-mark-growth.png`
- `assets/gem-mark-guard.png`
- `assets/gem-mark-haste.png`
- `assets/gem-mark-leech.png`
- `assets/gem-mark-power.png`
- `assets/gem-mark-regen.png`
- `assets/gem-mark-vitality.png`
- `assets/icon-archive.png`
- `assets/icon-atk-bow.png`
- `assets/icon-atk-dagger.png`
- `assets/icon-atk-staff.png`
- `assets/icon-atk-sword.png`
- `assets/icon-back.png`
- `assets/icon-bag.png`
- `assets/icon-book.png`
- `assets/icon-close.png`
- `assets/icon-compass.png`
- `assets/icon-dash.png`
- `assets/icon-gear.png`
- `assets/icon-gold.png`
- `assets/icon-growth.png`
- `assets/icon-home.png`
- `assets/icon-info.png`
- `assets/icon-jump.png`
- `assets/icon-lock.png`
- `assets/icon-lockon.png`
- `assets/icon-map.png`
- `assets/icon-more.png`
- `assets/icon-party.png`
- `assets/icon-party2.png`
- `assets/icon-pet.png`
- `assets/icon-play.png`
- `assets/icon-plus.png`
- `assets/icon-quest.png`
- `assets/icon-rank.png`
- `assets/icon-rebirth.png`
- `assets/icon-reward.png`
- `assets/icon-shop.png`
- `assets/icon-skill-bow-e.png`
- `assets/icon-skill-bow-q.png`
- `assets/icon-skill-bow-r.png`
- `assets/icon-skill-bow-t.png`
- `assets/icon-skill-dualblade-e.png`
- `assets/icon-skill-dualblade-q.png`
- `assets/icon-skill-dualblade-r.png`
- `assets/icon-skill-dualblade-t.png`
- `assets/icon-skill-greatsword-e.png`
- `assets/icon-skill-greatsword-q.png`
- `assets/icon-skill-greatsword-r.png`
- `assets/icon-skill-greatsword-t.png`
- `assets/icon-skill-healer-e.png`
- `assets/icon-skill-healer-q.png`
- `assets/icon-skill-healer-r.png`
- `assets/icon-skill-healer-t.png`
- `assets/icon-star.png`
- `assets/icon-training.png`
- `assets/icon-x.png`
- `assets/icon-zone.png`

## 그 밖의 파일

- `prototype/buttons-prototype.html`

## 아이콘 v2 — "이 세계의 물건" (확정 10-05)
- 화풍: 굵은 외곽선(따뜻한 물건 `#2B1B12` · 쇠 · 마법 `#1C2140`) · 3단 명암(밝음 · 기본 · 그림자, 빛 = 왼쪽 위) · 작은 흰 하이라이트 1개 · 색은 아이콘 안에. 버튼 판은 단순(양피지 크림 B).
- 크기: 원본 `icon-<이름>.png` 128(투명) → PC 버튼 안 64 · 폰 44 버튼 안 약 36.
- 색: 흰 + 자홍 · 검정 + 금은 아이콘에 안 씀. 보스 경고색과 겹치는 강조 없음(깃발 · 도장 = 파랑 · 나침반 북쪽 = 하늘색 · 깃털 = 호박 노랑). 남은 빨강 = 닫기 원(기존 확정) · 도적 목도리(작은 면적).

| 파일 | 물건 | 쓰는 곳 |
|---|---|---|
| `icon-bag.png` | 전사의 가죽 배낭 · 금 버클 | 가방 |
| `icon-growth.png` | 망치와 모루 | 성장(캐릭터 C) |
| `icon-training.png` | 나무 허수아비 + 목검 | 수련 U |
| `icon-zone.png` | 이정표 표지판 | 구역 선택 N |
| `icon-reward.png` | 리본 묶은 선물 상자 | 보상(출석 · 시즌판 · 선물) |
| `icon-map.png` | 양피지 지도 + 깃발 핀 | 지도 |
| `icon-party.png` / `icon-party2.png` | 전설 4명 얼굴 / 2명(폰 44 전용) | 파티 |
| `icon-pet.png` | 구역 알 | 펫 |
| `icon-book.png` | 가죽 표지 책 + 금 별 | 도감 |
| `icon-rank.png` | 금 왕관 | 순위 |
| `icon-rebirth.png` | 불사조 깃털 | 환생(알림 · 제단 표시용 — HUD 메뉴에는 없음) |
| `icon-home.png` | 마을 돌문 + 소용돌이 | 귀환 |
| `icon-shop.png` | 보물 상자 | 상점 |
| `icon-quest.png` | 밀랍 도장 두루마리 | 퀘스트 |
| `icon-compass.png` | 나침반 | 길 안내 |
| `icon-atk-sword / atk-dagger / atk-bow / atk-staff.png` | 대검 · 쌍검 · 활 · 지팡이 | 공격(현재 직업 무기) |
| `icon-dash.png` | 날개 달린 장화 | 대시 |
| `icon-jump.png` · `icon-lockon.png` | 위 화살표 + 구름 · 과녁 | 점프 · 고정(락온) |
| `icon-gold.png` | 금화 더미 | 골드 |
| `icon-back / plus / play / info / star / archive.png` | 꺾쇠 · 십자 · 금 삼각형 · i · 금 별 · 나무 상자 | 뒤로 · 빈 칸 · 시작 · 정보 · 별 · 보관 |
| `icon-gear / close / x / lock / more.png` | 톱니 · 닫기(빨간 원 + X) · 흰 X(판 위) · 쇠 자물쇠 · 금 징 3개 | 모양 그대로 · 질감만 카툰 |

**파일 이름 규칙:** 모든 묶음(01 · 02 · 03 …)은 이 표의 이름만 씀(`menu-*` 같은 다른 이름 없음).

얼굴이 필요한 곳(파티원 칸 · 이어하기 카드)은 전설 일러스트에서 잘라 씀(01 묶음 `face-*.png`).

## 스킬 아이콘 16장 (10-05)
- 직업 4 × Q/E/R/T · 아이콘 v2 화풍(굵은 외곽선 · 3단 명암 · 하이라이트) · "기술 한 장면" + 그 직업 무기 · 색 · 128 투명 PNG.
- 파일: `icon-skill-<greatsword|dualblade|bow|healer>-<q|e|r|t>.png`. 이름 · 설명 = 게임 데이터(아이콘은 직업 · 칸으로 고름).
- T(궁극기) = 금 고리 틀(`#FFC83D` + 진갈 테두리) + 네 방향 흰 보석 + 광선 · 반짝 더 많이 · 장면 0.8배. 검정 + 금(초월 전용) 아님.
- 빨강 · 진한 주황 큰 면 없음. 쿨타임 덮개 · 잠김 = 02 HUD 기존 규칙. 폰 44 · 56 형태 비교 = `mockups/pc_07_skill-icons.png`.

| 직업 | Q | E | R | T(궁극기) |
|---|---|---|---|---|
| 검사 greatsword | 관통돌진 | 회전베기 | 전장의 포효 | 파괴의 화신 |
| 도적 dualblade | 그림자분신 | 난무 | 암영 표식 | 죽음의 계약 |
| 궁수 bow | 강궁 | 백스텝샷 | 사냥꾼의 덫 | 천궁의 폭우 |
| 치유사 healer | 치유 | 딜링모드 | 구원의 기도 | 생명의 성역 |

## 보석 아이콘 = 2겹
- 등급 몸통 6 `gem-body-<hero|legend|relic|ancient|primal|transcend>.png`(128) + 종류 문양 9 `gem-mark-<power|haste|crit|vitality|guard|growth|regen|leech|class>.png`(64).
- 조합: 몸통 위 문양(몸통의 45%, AnchorPoint (1,1), 오른쪽 아래 모서리에 살짝 걸침). 자세한 규칙 = 03 묶음.

## 버튼 상태 5개 (모든 버튼 공통 · 확정 10-05)

종류: 주 버튼(노랑) `btn-pri` · 태초 전용 `btn-primal` · 보조 `btn-sec` · 위험 `btn-danger` · 둥근 아이콘 판 B `btn-plate` · 탭 `btn-tab-on` / `btn-tab-off` · 닫기 `btn-close` · HUD 전투 버튼 `btn-combat` · 칸 · 카드 `btn-card`.
상태: `normal` · `hover`(PC 마우스 올림) · `pressed` · `disabled` · 선택 테두리 = `focus-ring-r12` / `focus-ring-r10`(탭) / `focus-ring-circle`(원)을 버튼 바깥 3px에 겹침.

### 상태 전환 수치
| 전환 | 시간 | 크기(UIScale) | 면 · 밝기 | 입술 · 내용 | 곡선(TweenInfo) |
|---|---|---|---|---|---|
| 누름 들어감 | 0.06초 | 1.00 → 0.95 | 면 이미지 → pressed(밝기 약 −10%) | 입술 4 → 2px(판 B 3 → 1) · 내용 y +2 | Quad · Out |
| 떼고 복귀 | 0.10초 | 0.95 → 1.00(살짝 넘었다 돌아옴) | pressed → normal | 2 → 4px · 내용 y 0 | **Back · Out (튀는 곡선)** |
| 마우스 올림(PC) | 0.08초 | 1.00 → 1.03 | normal → hover(밝기 약 +8%) | 그대로 | Quad · Out |
| 마우스 나감 | 0.08초 | 1.03 → 1.00 | hover → normal | 그대로 | Quad · Out |
| 비활성 누름 | 0.24초 | 1.00 · x ±4px 3번 흔들림 | disabled 그대로 | 그대로 | Sine · InOut |
| 선택 테두리 켜짐 | 0.08초 | — | focus-ring 투명도 1 → 0 | 그대로 | Quad · Out |

### 동작 규칙
- **일반 버튼 = 버튼 위에서 뗄 때만 발동.** 누른 채 밖으로 끌면 누름 모양이 풀리고(복귀 곡선), 그 상태로 떼면 발동 안 함. 다시 안으로 들어오면 누름 모양 복귀. 꾹 눌러도 발동 안 함(뗄 때 1번).
- 스크롤 목록 안 버튼: 누른 뒤 8px 넘게 움직여 목록이 스크롤되면 누름 취소 → 떼도 발동 안 함.
- **전투 버튼(공격 · Q/E/R/T · 대시)만 누르는 순간 발동.** 누름 모양은 같음. 쿨타임 중 누름 = 비활성 흔들림.
- 비활성 = `btn-*-disabled` · 글자 `#7D87A3` · 아이콘 ImageTransparency 0.5 · 누르면 흔들림만, 발동 없음.
- 선택 테두리 = 게임패드 · 키보드로 고른 버튼에만(흰 3px · 버튼 바깥 3px). 마우스 · 터치에서는 안 보임.
- 구현 제안(확실하지 않음 — 실기기 확인): 발동은 `Activated`가 아니라 `InputBegan` / `InputEnded` + 위치 판정으로 직접 처리(밖으로 끌기 취소 · 다시 들어오기 복귀를 정확히 맞추려면). 게임패드 선택은 `GuiService.SelectedObject` + `SelectionImageObject` = focus-ring.

### 9-slice 자르는 값
| 파일 | 원본 px | SliceCenter |
|---|---|---|
| `btn-pri / primal / sec / danger / plate / card-<상태>.png` | 96×96 | `Rect(32, 32, 64, 64)` |
| `btn-tab-on / tab-off-<상태>.png` | 96×96 | `Rect(28, 28, 68, 68)` |
| `focus-ring-r12.png` | 120×120 | `Rect(40, 40, 80, 80)` |
| `focus-ring-r10.png` | 120×120 | `Rect(36, 36, 84, 84)` |
| `btn-combat-<상태>.png` | 192×192 | 9-slice 아님(원 · 크기 그대로) |
| `btn-close-<상태>.png` | 88×88 | 9-slice 아님(원) |
| `focus-ring-circle.png` | 216×216 | 9-slice 아님(원) |

원본이 2배 → SliceScale 0.5 · ScaleType = Slice. 1배 기준 모서리 12(탭 10) · 테두리 2(판 B 3) · 입술 4(판 B 3).

## HTML 시제품
`prototype/buttons-prototype.html` — 브라우저로 열어 직접 눌러 봄(인터넷 없이 열림 · 그림 내장). 뗄 때 발동 · 밖으로 끌면 취소 · 다시 들어오면 누름 복귀 · 목록 끌기 취소 · 전투 버튼 즉시 발동 · 비활성 흔들림 · Tab 키 선택 테두리를 체험하고 아래 "발동 기록"으로 확인.

## 화면별 좌표 (목업에서 추출 · 기준 해상도 px · 원점 왼쪽 위 · X Y W H)

### 디자인 시스템 v1 시트(10-05 개정: 버튼 상태 · 아이콘 v2)

목업 `mockups/pc_01_design-system.png` · 캔버스 아트보드 `DesignSystem`

### 아이콘 v2 시트(64 · 128 · 44 판)

목업 `mockups/pc_02_icons-v2.png` · 캔버스 아트보드 `Icons2`

### 버튼 상태 5개 비교 · 수치 · 동작 규칙 · SliceCenter

목업 `mockups/pc_03_button-states.png` · 캔버스 아트보드 `BtnStates`

### 보석 아이콘 몸통 6 × 문양 9

목업 `mockups/pc_04_gem-icons.png` · 캔버스 아트보드 `Gems`

### 07-C 초월 사다리 +0~+25(아이콘 · 3D 공용 기준)

목업 `mockups/pc_05_transcend-ladder.png` · 캔버스 아트보드 `Transcend`

### 설정 "글자 크기" 줄(PC · 폰 아주 크게) · 단계 × 배율 표

목업 `mockups/pc_06_text-size-setting.png` · 캔버스 아트보드 `SET_TextSize`

### 스킬 아이콘 16장 · 폰 44/56 비교 · 상태

목업 `mockups/pc_07_skill-icons.png` · 캔버스 아트보드 `SkillIcons`

### 스킬 아이콘 2장 다시(파괴의 화신 · 그림자분신) · 크기별 읽힘

목업 `mockups/pc_08_skill-icons-redraw.png` · 캔버스 아트보드 `SkillFix`
