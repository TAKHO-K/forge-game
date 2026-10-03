# QUEUE-ALL9C 블록 2 기록

## 2-1 장비 아트 규격 저장

- `docs/design/gear-art-v3.md` = ART-REF v2 전문(정본) + 사용자 10-03 문구 3곳(0절 ⑦ 끝 · 2-1절 제목 괄호 · 5절 ⑦) · 형식만 = 마크다운 제목 · 2 · 3절 표 머리줄.
- `docs/art/ref/gpt-gear-index.md` = GPT 6장을 하나씩 열어 내용으로 판별(②~⑦ 시각 순서 추정과 같음) · ⑦ 그림 속 제목이 틀림(아래 왼쪽 "유물" = 태초 · 아래 오른쪽 "고대" = 초월) · 목록 밖 2장(09_53_05 = 치장 콘셉트 시안 · 9-26 것 = 열지 않음).
- `.gitignore`: `docs/art/ref/`(D0 타 게임 스크린샷) 전체 무시 → 10-03 GPT 원본 · 목록 · compare/만 예외(원본 이름 · 내용 그대로 커밋).

## 2-2 X3 등급 색 확정

- 데이터 한 곳 = `shared/data/ItemVisualData.gradeVisuals[등급]`: color(메인) · light · dark = ART-REF 2절 hex · text(글자 - 메인 대비 4.5:1 미만이면 밝은 색) · border(테두리 · 빛기둥 · 점 - 초월 = 금 #D8B96E) · textStroke(태초 자홍 #E95BC8) · 펫 등급 → 장비 색 `petGradeColorOf`(common 일반 · uncommon 희귀 · rare 영웅 · epic 전설).
- 읽기 = `shared/GradeColor`: of(메인 · 3D 본체) · text · border · light · dark · applyText(글자 + 태초 외곽선) · petGrade · hex(= 글자색). 옛 직접 읽기(`visual.color`) 23곳을 쓰임대로 바꿈(글자 · 아이콘 = text / 테두리 · 빛 · 점 · 드랍 = border). ArtStyleV1 칸 틀(`GradeFrame`) · 초월 배너 · 흑금 칸 · 드랍 빛 · 태초 드랍 테도 같은 데이터.
- 바뀐 색(사용자 확정): 유물 금 → 진홍 #B92F48 · 고대 빨강 → 청록 #087F82 · 태초 자홍 → 백색 #F7F5EF(글자 = 흰 + 자홍 외곽선 · 테두리 = 무지개 띠) · 초월 금 → 흑요석 #202127(칸) + 금 #D8B96E(테두리 · 글자) · 일반 밝은 회색 → #9299A1 등.
- 글자 대비(패널 · 칸 중 낮은 쪽): 일반 5.47 · 희귀 7.27 · 영웅 6.69 · 전설 4.98 · 유물 5.30 · 고대 8.62 · 태초 14.44 · 초월 8.31(전부 ≥ 4.5).
- 검사 `roblox/tools/check_grade_colors.py`: 문서 표 hex = 데이터 8/8 · 대비 8/8 · UI 폴더 옛 색 0(남은 23곳 = 3D 무기 · 갑옷 · 허브 장식 · 보스바 · 목업 = ALL9E · 등급 색 아님) → 통과(`grade-colors-check.txt`). 검증 블록 G1_1Verify(옛 "태초 = 흰색과 멀리" → 자홍 외곽선 · 무지개 · 일반 글자색과 거리) · C5Verify(초월 hex #d8b96e) 기대값 갱신.
- Play(PC): 땅 드랍 7등급 빛(희귀 ~ 초월 - 일반은 빛 없음) · 가방 칸(초월 금 테 · 태초 무지개 · 고대 청록 · 유물 진홍) · 태초 이름(흰 + 자홍 외곽선) · 도감 등급 줄 글자. 캡처 `captures/2-2-*.jpg`.
- 못 찍음: 펫 4등급 색 = 개발 계정 펫 도감이 전부 미발견(실루엣 "?") → 코드 경로(`GradeColor.petGrade` = 옛 HATCH_COLOR와 같은 매핑)로만 확인. 3D 장비 색(본체 · 보석)은 ALL9E.
