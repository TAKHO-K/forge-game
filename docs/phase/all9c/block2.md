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

## 2-3 X8 + X9 첫 화면 = 메인 메뉴 → 로딩 → 게임

- 흐름: 접속 즉시 `first/MenuBoot`가 로블록스 기본 로딩을 끄고 가림막(하늘 그라데이션 + 왼쪽 어두운 띠)을 띄움 → 같은 스크립트가 배경 키 아트를 **미리 불러오기 1번**으로 받아 다 오면 0.8초에 서서히 표시(평균 3.4 ~ 3.9초 - 그 전 = 그라데이션) → `client/MainMenu`가 저장을 읽으면 메뉴 표시(접속 → 메뉴 3.2 ~ 3.9초).
- 메뉴 항목 4개: **이어하기**(직업 · Lv · 스테이지 줄 · 기존 유저 기본 선택 = 주황 카드 · Enter) / **직업 선택**(입장 뒤 기존 직업 선택 창 = 기존 전환 규칙 그대로 · 신규 = [시작하기] → 처음 고르기) / **설정**(효과음 · 음악 음량 · 그래픽 · 언어 · "다음부터 메뉴 건너뛰고 바로 시작") / **소식**(업데이트 한 줄 + "코드는 마을 게시판에서"). 로고 자리 = `GameInfoData.name`("NAME" 자리값 - check_textdata 경고 · 출시 점검 목록).
- 메뉴에 있는 동안 미리 불러오기 7단계(`MainMenuData.steps`: 저장 · 맵 완성 · 마을 소품 메시 · 캐릭터 · 주변 스트리밍 · UI 아이콘 · 소리 시트). 누를 때 남았으면 로딩 막대 + 팁 한 줄(옛 S12 로딩 문구 4줄 → TextData_menu ko · en) → 다 되거나 **15초**에 입장(남은 단계는 배경에서). 메뉴 · 로딩 동안 조작 막음(이 게임은 PlayerModule이 없어 ContextActionService 최우선 바인딩으로 키보드 · 게임패드를 삼킴 · 터치 = 가림막 Active) · 로블록스 채팅 · 플레이어 목록 숨김(왼쪽 위 채팅 창이 메뉴 클릭을 가로챘음 - 입장 때 원래대로 · 촬영 모드면 그대로).
- 측정(ALL9F 집계): Remote `MenuTiming` → `Telemetry.custom` MenuShowMs · MenuToPlayMs · MenuLoadCapHit · MenuSkipped(사람당 1회 · 0 ~ 10분 정수 검사) + 서버 로그 `[MENU] 측정 …`.
- 설정 키 `skipMenu`(SettingsData - 없는 키 = 기본값, 이관 없음 · SAVE 버전 그대로). 언어는 메뉴 글만 바로 바뀌고 다른 화면은 다시 접속하면 적용(안내 문구).
- 배경(사용자 10-03 최종): 키 아트 한 장 = `roblox/art/ui/menu_keyart_v1.png`(1536 × 1024 GPT) → 좌우 770 × 1024 2장(가운데 4px 겹침 · 이음매 안 보임) · 화면 꽉 채움 · 가로 가운데 · 세로 기준점 0.55. 교체 절차 = `docs/phase/all9c/menu-background.md`(파일 하나 + `menu_bg.py` 한 줄). 심사 미통과면 빈 배경(그라데이션)으로 생성 - Play로 확인.
- 끈 기능(데이터 스위치 · 코드 남김): 장소 사진 3장 교차 전환(`MainMenuData.backgroundCrossfade` - 마을 · 사냥터 몹 무리 · 1구역 관문 Studio 캡처를 `tools/blender/cartoon_menu_bg.py`로 카툰 후처리) · 좌우 등급 빛줄기(`lights.enabled` - 일반 → 초월 · 색 = GradeColor.border · 움직이는 프레임 20 · lite = 11 · Play 59 fps) · 옛 로딩 문구 스크립트(`MenuBootData.legacyLoadingTip`).
- 메뉴 자리 = 화면 왼쪽 35% 안(`menuZone` · 여백 4%): PC 16:9 x 42 ~ 362 / 1052 · 폰 19.5:9 33 ~ 295 / 844 · 작은 폰 26 ~ 225 / 667. 안전 영역 그림 `docs/art/ref/menu-safe-zone.png`(`tools/blender/menu_safe_zone.py`).
- 글자 대비(캡처 표본 - 배경 위 글자): 로고 뒤 배경 p95 → 8.2 ~ 8.7:1 · 회색 안내 문구 3.3:1 미달 → 밝은 글자 8.1:1로 바꿈 · 로딩 팁 = 반투명 받침. [이어하기] 카드(흰 글 / 주황 ember)는 기존 primary 버튼 색(약 2.2:1)이라 이번 범위 밖 → 결정 필요.
- 같이 고친 기존 결함: 신규 계정(직업 고르기 전)이 접속할 때마다 `StageServer` 재접속 보스 확인이 스테이지 nil을 비교해 오류(`BossRules:158`) → nil이면 건너뜀(신규 흐름 Play에서 발견).
- 검증(Studio Play): 버튼 4개 각각 · 설정 7칸(− · + · 그래픽 · 언어 en ↔ ko · 건너뛰기 → 서버 Attribute 반영) · 소식 · 뒤로 · Enter = 우리 코드 오류 0(studio_log_errors) / 15초 상한(`DevMenuStallStep` = sounds) → "메뉴→플레이 15.01초 · 상한 true · 남은 단계 sounds" / 건너뛰기(실제 프로필 settings.skipMenu를 잠깐 넣고 Play → 메뉴 없이 로딩 9.2초 → 입장 · 건너뜀 true → 원래대로 nil · savedAt 그대로) / 심사 중(asset-ids 상태를 잠깐 Reviewing → 생성 → 그라데이션만 · 메뉴 정상 → 백업으로 복구 cmp 같음) / 신규 계정(StudioFreshProfile → [시작하기] → 로딩 → 직업 선택 창) / 하네스 run_all 전부 통과 · check_textdata · check_names · check_grade_colors 통과.
- 캡처 `captures/2-3-*`: keyart-pc-16x9 · keyart-phone-844x390(19.5:9) · keyart-smallphone-667x375 · keyart-smallphone-settings · keyart-pc-settings-en · keyart-pc-news · keyart-loading-pc · fallback-reviewing-pc · (지난 시안) menu-pc-hub/gate/hunt-light-transcend/light-2/light-3.
- 메모: [직업 선택]으로 들어가면 출석 창이 직업 선택 창 위에 겹쳐 뜬다(기존 창 순서) → 2-4 직업 선택 개편 때 정리.
- 배경 이미지 교체 대기: 사용자 키 아트 v1 적용 완료 · 다음 그림은 같은 절차.

### 삭제 점검(사용자 10-04)

| 경로 | 커밋 | 내용 | 복구 |
|---|---|---|---|
| (없음) | 200c8a7c ~ 2bd708af(이번 큐 커밋 범위) | `git log --diff-filter=D` = 0건 · 이름 바꿈 0건 | - |
| `roblox/src/first/LoadingTip.client.lua` · `LoadingTips.lua` | 2-3 작업 중(미커밋) | 새 가림막으로 이름 바꿈(git mv) | 원래 파일 되살림 + 스위치 `legacyLoadingTip = false`로 끔 |
| `roblox/art/ui/menu_bg.png` + asset-ids `ui/menu_bg.png` | 2-3 작업 중(미커밋) | 첫 배경 시안을 지우고 기록을 뺐음 | 같은 원본에서 다시 만듦(747,630바이트 같음) · 기록 원래 id(95255177655623 · 이미지 123748120333845) |
| 등급 빛줄기 코드 | 2-3 작업 중(미커밋) | 사용자 "빛줄기 중단" 뒤 코드 블록을 지웠음 | 되살림 + `lights.enabled = false` |
| 에셋 기록 수 | - | asset-ids 722 → 730 · ArtAssetIds 722 → 730(추가 8 · 삭제 0 · 바뀐 값 0) | - |
| `docs/art/ui/menu_keyart_v1.png.png` | - | 사용자가 잘못 넣은 사본 - 지우지 않음 | `.gitignore`에만 추가 |
