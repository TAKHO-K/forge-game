# QUEUE-UI 보고서(UI-0 기반 · UI-1 메인 메뉴 - 2026-10-05)

> 지시 = `docs/phase/QUEUE-UI-prompt.md` · 상태 = `QUEUE-UI-state.md` · 기준 = `docs/design/handoff/01_main-menu/v1/spec.md` + `checklist.md`.
> Play 캡처 = `C:\Users\xkrgh\vibe\claude-design-handoff\01_main-menu\v1\play\`(목업과 같은 이름 · 저장소에는 넣지 않음).

## UI-1 checklist 결과(14항목)
| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | PC · 폰 모두 얼굴 · 초월 대검이 이어하기 창에 안 가려짐 | O | 창 오른쪽 끝 PC 1012 · 폰 482(좌표 표 · 하네스 ui_v2) · `pc_03` · `phone_03` |
| 2 | 왼쪽 위 로블록스 버튼 자리 비어 있음 | O | 좌표 표 검사(PC 132×60 · 폰 140×52 아래) · 폰 제목을 y 56으로 내림 |
| 3 | 폰 모든 버튼 44px 이상 · 글자 12 이상 | O | 하네스(닫기 · 돌아가기 · ⋯ · 보관함 · 시작 · 취소 · 보관 · 메뉴 줄 · 카드 줄) · 토큰 폰 글자 최소 12 |
| 4 | 캐릭터 0개 → [시작하기] → 바로 직업 선택 | O | 새 계정 Play: `pc_01` → `pc_06` · `phone_02(새 계정)` → `phone_06` |
| 5 | 마지막 캐릭터가 맨 위 · 선택 · 두 번 눌러 시작 | O(차이 1) | 맨 위 + 노랑 테두리 · 두 번 눌러야 시작(Play: 한 번 = 캐릭터 0 · 두 번 = 입장). **차이**: "한 번 더 누르면 시작" 줄은 첫 누름 뒤에 보인다(10-05 버그 지시 "같은 카드를 두 번" - 미리 선택만으로 그 줄을 보이면 한 번에 시작하는 것처럼 읽힘) |
| 6 | 같은 직업 2개일 때만 ① ② 표시 | O(하네스) | `UiModel.slotRows`(1개 = 번호 없음) · 개발 계정에 같은 직업 2개가 없어 Play 캡처 없음 |
| 7 | 보관 확인 창 첫 포커스 = [취소], Enter = 취소 | O | Play: 창 열림 = 취소 선택 표시 · Enter = 닫힘 + 칸 그대로 · `pc_05` · `phone_05` |
| 8 | 칸 꽉 참 → 직업 선택 구경 모드(띠 · 확정 비활성) | O | `pc_07` · `phone_07`(띠 · 자물쇠 · 회색 [○○로 시작] · 구경 좌표 따로) |
| 9 | 설정 문구 1회만, 폰은 탭으로 즉시 넘김 | O | 설정 키 `menuLoreSeen`(계정 · 없는 키 = 기본값) · PC 3초 뒤 사라짐 · 폰 전체 덮개 탭 = 바로 · `phone_01` · `pc_01b`. Studio는 Play마다 실제 프로필로 다시 시드해서 매번 다시 뜬다 |
| 10 | 노랑 버튼은 시작/구매에만 | O | 노랑 = [이어하기 · 시작하기] · [○○로 시작]만 · 보관 확인 [보관] = 보조(회색) |
| 11 | 캐릭터 0개일 때 [직업 선택] 숨김 | O | `pc_01` · 새 계정 폰 |
| 12 | 이어하기 카드 무기 = 그 캐릭터 장착 무기 아이콘 · 틀 · 강화 표시 | O | `UiModel.weaponIconKey(직업, 무기 등급)` + 등급 테두리 + 강화 칩(+13 · 07-B 띠 색 = `WeaponFx.stepOf`) |
| 13 | 직업 선택에 내 아바타 미리보기 없음 · 2D 전설 일러스트만 크게 | O | 전사 · 궁수 = 넘김 그림 업로드(`ui/legends/class-warrior` · `class-archer`) · 치유사 · 도적 = 임시 실루엣 + "그림 곧 공개" |
| 14 | 직업 이름 · 스킬 · 수치가 게임 데이터에서 읽힘 | O | `UiModel`(ClassData · SkillData · UltimateData) · 하네스 "신직업 = 데이터 추가만" 5항목 |

### 캡처(play 폴더)
`pc_01_main-no-character` · `pc_01b_main-with-character-lore`(추가) · `pc_02_continue-one-character` · `pc_03_continue-full` · `pc_05_archive-confirm` · `pc_06_class-select` · `phone_01_intro-lore` · `phone_02_main` · `phone_03_continue-full` · `phone_05_archive-confirm` · `phone_06_class-select` · `phone_07_class-select-browse`.
못 찍은 것: `pc_04`(빈 칸 사이 · 같은 계정 상태가 없음) · `pc_07`(구경 모드 고친 뒤 재촬영 못 함 - 고치기 전 Play에서 확인) · `phone_04`(캐릭터 1개 폰).

## 목업과 다른 점 · 남은 것
- 빠진 에셋 13개(MISSING.md): 아이콘 9종 = 아이콘 표의 임시 글자(X · 🔒 · + · ⋯ · ▤ · < · ▶ · i · ★) · 얼굴 2장 = 전설 그림을 01 spec의 ImageRect로 잘라 씀 · 치유사 · 도적 = 직업 색 칸 + 첫 글자 / 큰 임시 실루엣. 들어오면 `UiIconData`(아이콘 · 직업 그림 키)만 바꾼다.
- [소식] 빨간 점: 안 읽은 소식 기록이 없어 아직 안 그림(목업에는 있음).
- 제목 글꼴: 한글 GothamBlack(로블록스 기본) · BEYOND LEGENDARY 글자 간격(로블록스 글자 간격 속성 없음).
- 보관함 화면: 다음 묶음 → 지금은 창 안 목록 + [복구](기능 그대로).
- 확인 창 첫 포커스 표시 = 로블록스 기본 선택 테두리(파랑) · 노랑 테두리는 그 아래.

## UI-0 기반(51d408e1)
- 토큰 `shared/data/UiTokens`(01 spec 색 21 + 바탕 2 · 글자 PC/폰 · 모서리 · 테두리 · 아래턱 4 · 창 머리 68/48 + 노랑 줄 4/3) - 00 디자인 시스템 묶음이 오면 이 표만.
- 아이콘 표 `shared/data/UiIconData`(아이콘 ID → ArtAssetIds 키 · `tint` 스위치 = 흰 글리프에 색 입힘 / false = 자체 색 · 임시 글자) · 직업 그림 `classArt` · 공격 버튼 = 지금 직업 무기 아이콘(`attackUsesWeaponIcon`).
- 좌표 표 `shared/data/UiLayoutData`(기준 PC 1920×1080 · 폰 800×360 · 카드 줄 = 첫 줄 + 높이 + 간격) · 루트 `client/ui/v2/UiRoot`(UIScale = min · 왼쪽 붙임 · 세로 가운데).
- 부품 `client/ui/v2/UiKit`(주/보조 버튼 · 닫기 · 창 · 카드 · 빈/잠긴 칸 · 확인 창 · 안내 띠 · 토글 · 아이콘 · 아이콘 칸 + 등급 + 강화 칩) · 화면용 데이터 `shared/UiModel`.
- 하네스 `ui_v2` 21/21(토큰 · 좌표 · 폰 44 · 아이콘 표 · 배율 · 직업/스킬 데이터 · 조사 · 이어하기 줄 · 신직업 = 데이터 추가만).

## UI-1 구조
- `client/ui/v2/MainMenuV2`(메인 · 첫 실행 문구 · 이어하기 창 · 보관 확인 · 보관함 · 직업 선택 새/구경) - 스위치 `MainMenuData.v2Menu`(false = 옛 기본 모양) · 설정 · 소식 페이지 = 옛 모양 그대로(06 묶음 대기).
- 배경 `first/MenuBootData.layoutV2`(키 아트 화면 높이 · 오른쪽 붙임 · 왼쪽 22% 페이드 · #0E1120 덮개 · 남색 바탕 · 땅 없음).
- 직업 선택이 메뉴 안으로: [○○로 시작] = (캐릭터 있으면 SlotRequest new) → ClassSelectRequest → 입장. 성향 막대 = `ClassData.cards[].tendency`(화면 표시 전용 · 01 가안 값).
- Studio 폰 촬영: Edit에서 `ReplicatedStorage:SetAttribute("ForceTouchLayout", true)`(접속 처음부터 폰 배치) + 창 1138×813(뷰포트 800×361).

## 검증
run_all 전부 · ui_v2 21/21 · menu_gate 10/10 · 소스 검사 11/11 · check_textdata · check_names 통과 · Lua 컴파일 · 분석 새 경고 0 · Play(PC 16:9 1052×592 · 폰 800×361 · 새 계정 · 개발 계정) · 로그 게임 에러 0.
