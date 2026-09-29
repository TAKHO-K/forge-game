# A2-S2 보고 - 정리 + B 결과 Studio 확인 + 샘플 보강 + Blender 첫 시험 (2026-09-30)

> 지시 = 사용자 채팅(A2-S2 본 지시 + 추가 지시 A ~ D) · [바로 실행] · COMMON §0 · §7-1 ~ §7-6. **대량 생산 없음**(대검 1자루 × 3등급 시험 · 문서 계획만).
> 스크린샷 = `Claude outputs/A2-S2/`(B 확인 · 샘플 전후 · 폰) · `Claude outputs/ART-sample/blender/`(Blender 렌더 · 비교).
> Play 3회(최대): Play 1 = B 확인(무장 · 옛 코드 - 도중에 B 후속 커밋 발견) · Play 2 = B 후속 재확인 + 샘플 촬영(무장) · Play 3 = 대검 날 색 수정 확인(무장 안 함).

## 0. 결과 표

| 항목 | 결과 | 근거 |
|---|---|---|
| 1 worktree `roblox-b1` 정리 | **O(제거)** | 처음엔 `git worktree move` = Permission denied(세션 B 프로세스가 폴더를 쥐고 있었다 - 끄지 않음) → 추가 지시 B(세션 B 종료) 뒤 **커밋 안 된 변경 0 · `b1-monetize`(4847967) ⊂ master 확인 → `git worktree remove` + 브랜치 삭제**. `git log --all -- roblox-b1` = 빈 결과(**커밋에 들어간 적 없음**). 원격 b1 브랜치 없음. 지금 `git worktree list` = `C:/Users/xkrgh/vibe/game 930c6e6 [master]` 한 줄 |
| 2 git pull | O | 6a9ce11은 이미 있었고, 도중에 올라온 B 후속 3개(c49565f · 18c00bd · **4847967**)까지 받음(리베이스 · 충돌 0) |
| Play 전 체크리스트 | O(3회 모두) | Rojo 실제 동기화 = 바꾼 파일 Studio `Source` 길이 = 로컬 LF 바이트(예: ArtV1View 13585 · SaveSystem 85397 · MonetizationService 15996 → pull 뒤 19016 · DevTools 287789 · WeaponEnhanceVisual 13504 + 새 식별자 `find`) · PlaceId 106413438976597 · DataStore 읽기 ok |
| 3 B 결과 확인(§6 11개) | **8 O · 1 X(표시) · 2 사용자/보류** | 아래 §1 |
| A 추가 확인 3개 | **3/3 O** | `[DevTools] 무거운 (가) 2블록을 체인 끝에서 시작(QUEUE-B1 결정 4)` · 실패 이유 한 줄(`반짝 조각이 모자랍니다` · `먼저 사야 장착할 수 있습니다`) · `[B2] 시즌 1 시작일 미정(LeaderboardConfig.firstSeasonDateKst) …` 서버 경고 |
| 4 샘플 보강 | O | 채도 +0.08 · 잔디 노랑 · 어둡게 · 강화대 1.7배 + 벽돌 화덕 · 주황 불빛 · 굴뚝 연기 · 대성공 Beam 빛기둥 · 폭발 · 바닥 링 · 화면 반짝임(섬광 줄이기 존중) · 입자 24 유지 · 외곽선 · 대검 규칙 = 문서(§2) |
| 5 Play 2 스크린샷 | O | 사냥 · 강화대 40스터드 · 대성공 전후 · 폰 800 × 360(§3) |
| C Blender 첫 시험 | **부분 O** | 실행 파일 · 백그라운드 O · 템플릿 첫 실행 → FBX 버그 수정 · 대검 3등급 메시 · 렌더 · 비교 O · **Studio로 넣기 = 3경로 모두 사용자 행동 필요**(§4) - 가능한 데까지(FBX · 미리보기 코드) 준비 |
| D 손에 쥔 모습 | 도형 조립 대검만 O · Blender 대검은 X(사용자 행동 대기) | 도중에 **실제 버그 발견 · 수정**: 교체 모델 날 색이 은색으로 덮임(§5) |
| 6 제작 순서표 | O | `docs/art/blender-production-order.md`(13종 + 대검 · 방식 열 "도형 조립 / Blender") |
| 파이프라인 표 | O | `docs/art/3d-pipeline.md`(경로 / 사람 손 / 모델당 시간 / 제한 / 추천 · 출처) |

## 1. B 결과 확인(QUEUE-B1 보고서 §6)

| # | 항목 | 결과 | 근거 |
|---|---|---|---|
| 1 | 결정 15 · B1-5 블록 | O | Play 1: 29-1(가) 5/5 · **29-1(나) 23/23** · P2(나) 4/4 · P3a(나) 13/13(`자격 ok · 정렬 쓰기 +2`) · P3a(나C) 18/18 · S16(UI) 14/14 · S12b(UI) 10/10 · 11/11 · S17(UI) 12/12 |
| 2 | 결정 12 | O | G1-0(나) 11/11 - `2.0ms 넘은 프레임 4 / 1531 = 0.26%(기대 ≤ 1%)` |
| 3 | 결정 13 · 14 | O | Play 2(B 후속 반영): **S13(가) 9/9**(#4 = 기록 줄) · **G1-0(가) 4/4** · P3c(가) 30/30(`C4 이관 v34 → v56: 레벨 300 · 진행률 0.400`) · Q0(가) 94/94 |
| 4 | 저장 v56 | O | `이관 체인 v0 → v56(54단계 전부)` · R2(가) 10/10 · 6hbF(나) 8/8(`새 계정 첫 로드 v56` · `개발 계정 왕복 … v56`) |
| 5 | 상점 창 · 구매 버튼 | O | 보석상인 좌판 F → 상점 4탭 실제 클릭(`B-shop-*.jpg`). **상품 번호가 빈 로벅스 · 게임패스 버튼 = 회색 "준비 중"(비활성)** · 조각 0이면 조각 가격 버튼도 회색. 가짜 구매(시험 id)는 id를 넣지 않아 미실행(Creator Hub 등록 전) |
| 6 | 선물함 | O(표시 1 X → B 후속에서 해결 확인) | `/ops gift 11595243049 gliderSkin kite 알파` → `delivered_online` → 팝업(`B-gift-popup.jpg`) → [모두 받기] 실제 클릭 → 연 글라이더 "보유". Play 1(옛 코드) 상태줄은 성공인데 **빨간 "선물을 받지 못했습니다"**(`B-gift-claimed-status.jpg` - 표 비교 추정이 틀림) → B 후속 `ShopResult`(결정 10)로 실패일 때만 이유 줄. Play 2에서 실패 이유 줄 O(A 항목) |
| 7 | 조각 출처(정거장 · 둥지 · 칭호) | 보류 | 이번 범위(아트)와 Play 수 안에서 못 돌림 - 다음 Play 목록 |
| 8 | 상점 UI 스크린샷 | O(PC) | 폰 강제(`DebugShopScreen`) 촬영은 미실시 - 다음 Play 목록 |
| 9 | 사운드 음량 | O(재접속 유지만 보류) | 설정 창 음량 4줄 · [−] 실제 클릭 2회 → 80% · 서버 `SoundVolumeSfx = 0.8`(`B-settings-volume.jpg`). 콘솔 에러 0 |
| 10 | `/gg mesh`(Blender) | 사용자 행동 대기 | 무기는 `/gg mesh`(몬스터 · 보스 전용)가 아니라 `WeaponModels/<직업>` + `WeaponRigCheck` 경로(코드 기준). §4 |
| 11 | 체감 | 사용자 확인 | §7 |

- **S20b(UI)**: B 보고서의 id `S20b(UI)`는 실제 게이트가 `S20(UI)`라 Play 1에서 안 돌았다 → Play 2에서 `S20(UI)`로: 14/14 · 장비창 8/8 · **보석 탭 4/5 X - `보유 보석 칸 0 = 서버 스냅샷 1`**. 실제 화면도 보석 0개(`B-gemtab-0-vs-server-1.jpg`)라 검증 쪽이 아니라 클라 표시가 서버와 어긋난 상태. `GemFlowVerify` 주석대로 "서버 보석 목록이 바뀐 뒤 `GemSync`가 안 밀린" 계열로 보이나 **원인 미확정**(누가 보석을 바꿨는지 추적 안 함 - 알려진 X로).
- 시즌 탭 "남은 기간 0일" = 시즌 1 시작일 미정(결정 7)의 표시 - 서버 경고 줄과 같은 원인.

## 2. 샘플 보강(스위치 `ArtStyleV1` 뒤 - 끄면 이전과 같음)

| 대상 | 바꾼 것 | 파일 |
|---|---|---|
| 조명 | artV1 채도 +0.12 → **+0.08** | `CartoonStyleData` |
| 잔디 | artV1 전용 재질 색: Grass `#6DBA46 → #7FA640` · LeafyGrass `#5DAE45 → #6C9A3C` · 허브 바닥 `#6CC24A → #7AAB44`(노랑 쪽 · 어둡게) - cartoon 프로필은 그대로 | `CartoonStyleData` |
| 슬라임 | 그대로(사용자 결정) | - |
| 외곽선 | 잡몹 = Highlight 유지 · 보스만 Blender 뒤집은 껍데기(문서) | `art-direction-v1.md` §4 |
| 강화대 | 모델 배율 **1.7**(바닥 원점 · 판정 파트 그대로) · 화덕 · 굴뚝 돌 → 따뜻한 벽돌색(회색 벽과 대비) · 화덕 주황 PointLight 범위 18 · 밝기 1.5 · **굴뚝 연기**(엔진 기본 텍스처 `smoke_main.dds` · rate 2 · 수명 3 ~ 4.5초 · 동시 ≤ 9) · 불씨 그대로 | `ArtStyleV1Data.forge` · `ArtV1Models.forge` |
| 대성공 | 빛기둥 = **Beam**(아래 0.05 → 가운데 0.5 → 꼭대기 1 투명 · 높이 12 · 솟음 30% 뒤 흐려지며 가늘어짐) · **순간 폭발** 입자 6(사방 · 0.16 ~ 0.28초) · **바닥 링**(강화대 발밑 → 지름 16 · 0.65초) · **화면 반짝임**(밝기 +0.14 · 0.22초 · 설정 `ReduceFlashes` 켜면 안 만듦) · 입자 합 = 불꽃 14 + 폭발 6 + 별 4 = **24**(예산 그대로) | `ArtStyleV1Data.enhanceFx.great` · `ArtV1View` |
| 대검 | 형태 무변경 · 등급 색 · 발광 규칙표 | `art-direction-v1.md` §3-5 |
| 개발 전용 | Studio 캡처용 슬로모션 `ReplicatedStorage` Attribute `ArtV1FxSlow`(숫자 - 연출 시간 × n · 입자 TimeScale ÷ n · 실제 게임 = 1) | `ArtV1View` |

재사용한 공통 입구(§7-6): 조명 = `CartoonStyle.apply`(프로필 표만 추가) · 섬광 줄이기 = Player Attribute `ReduceFlashes`(PrimordialFx와 같은 방식) · 흔들림 = `CameraShake` · 강화 결과 = `EnhanceResult` 그대로 · 무기 = `WeaponVisual` 교체 모델 경로 · 등급 색 = `GradeColor.of`.

## 3. 스크린샷 (`Claude outputs/A2-S2/`)

| 대상 | 전후 비교 | 후 단독 | 폰(800 × 360 밀도 - PC 캡처를 줄임 · HUD는 PC 배치) |
|---|---|---|---|
| 사냥 화면(T1 슬라임) | `compare-hunt.png` | `hunt-gamecam-after.jpg` | `phone-hunt-gamecam-after.png` |
| 강화대 40스터드 | `compare-forge40.png` | `forge-far40-after.jpg` · `forge-near-smoke-after.jpg`(연기) | `phone-forge-far40-after.png` |
| 대성공 | `compare-vfx-great.png` | `vfx-great-pillar-after.jpg`(×5 슬로) · `vfx-great-burst-after.jpg`(×8) | `phone-vfx-great-pillar-after.png` |
| 초월 대검(도형 조립 · 손 · 등) | `compare-held-transcendent.png`(전 = 은색 날 버그) | `held-transcendent-fixed.jpg` | `phone-held-transcendent-fixed.png` |
| Blender 대검 | `ART-sample/blender/compare-parts-vs-blender-front.png` | `blender-greatsword-front.png` · `-34.png` | - |

실속도 수치(Play 2 · 슬로 1): 0.2초 바닥 링 지름 8.8 · 투명 0.59 · 화면 반짝임 밝기 0.001(0.22초에 거의 0) · 0.7초 빛기둥 높이 12 · 폭 1.52 · 1.3초 전부 정리 · 섬광 줄이기 켬 → `ArtV1ScreenFlash` 생성 안 됨 · 이미터 3개. 강화대: 파트 20 · 그루터기 1.7 → 2.89 · 연기 rate 2 · 불빛 18 / 1.5.

- 사냥 화면: 전(형광 연두) → 후(노랑 쪽 · 덜 번쩍임). 민트 슬라임이 잔디보다 먼저 보이는지는 **체감 판단 = 사용자 확인**. 제 판단으로는 대비가 늘었지만 잔디가 여전히 밝은 편이다(조명 밝기 2.5 · 위쪽 색 이동이 잔디를 띄운다 - 더 내리려면 다음 조정 후보).
- 강화대 40스터드: 전 = 회색 벽 앞에서 작게 묻힘 → 후 = 1.7배 · 벽돌 굴뚝 · 바닥 주황 빛 웅덩이로 먼저 눈에 띈다. 약점: 주황 불빛이 그루터기까지 주황으로 물들인다(의도된 방향이지만 나무색이 사라짐).
- 대성공: 빛기둥이 아래는 진하고 위로 갈수록 투명. 바닥 링은 캡처에서 약하게 보인다(밝은 돌길 위 · 금색) - 수치로는 확인.

## 4. Blender 첫 시험

- Blender **5.2.2 LTS** · `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe` · `-b --factory-startup -P` 동작 O.
- B 템플릿 `make_rig_mesh.py`(슬라임 규격 JSON): 도형 · 삼각형 합 212(README 기대 그대로) · 메타 O · **FBX 내보내기 AssertionError → 수정**(재질 커스텀 속성 `PaletteRGB` 정수 목록을 FBX가 float64로만 받는다 → 16진 문자열). 재실행 FBX · .blend · 메타 O.
- 새 `make_greatsword.py`: 대검 1형태(날 = 모따기 육각 단면 + 뾰족 끝 · 가운데 홈 · 가드 · 8각 손잡이 · 폼멜) × look 3(일반 · 전설 = 등급 색 홈 · 가드 + 날개 + 보석 · 초월 = 검은 날 + 금 균열 2 + 흑금). 파트별 오브젝트 · 이름 = ArtV1Models 파트 이름 · **피벗 = 손잡이 점** · 부착점(Grip 0 · Tip 4.67 · Support −0.48)은 메타 · 삼각형 **126 / 162 / 186**(예산 800). 렌더 정면 · 45도(Workbench) · 도형 조립과 나란히 비교.
- Studio로 넣기(공식 문서 조사 - `docs/art/3d-pipeline.md`): ① 3D 가져오기 = 사람 클릭(스크립트 API 없음) ② Open Cloud Assets API = FBX → Model 가능 · **API 키 필요** ③ EditableMesh = 런타임 전용(장소에 저장 안 됨) · 게시에 ID 인증. **③을 실제로 시도 → `EditableMesh is not accessible. Go to the Security Tab in Experience Settings to enable this API.`**(경험 설정 변경은 사용자 몫이라 바꾸지 않음).
- 그래서 "Blender 대검 손에 쥔 모습"은 못 찍었다. 대신 그 경로(`WeaponModels.greatsword` 교체 모델)가 쓰는 코드에서 버그를 찾아 고쳤다(§5) - Blender 메시를 넣으면 그 색이 그대로 나온다.

## 5. 도중에 찾은 버그(수정)

- **교체 모델 날 색이 은색으로 덮임**: `client/WeaponEnhanceVisual.applyBody`가 몸통 파트(교체 모델이면 `PrimaryPart = Blade`)를 매번 `WeaponModelData.greatsword.color`(`#B4B6C0`)로 칠했다 → A2-S 초월 look 날 `#262230`이 은색으로 보였다(A2-S `held-transcendent.png`도 같은 증상 - 그땐 못 봄). Blender 메시도 같은 경로라 같은 문제가 난다.
- 수정(930c6e6): 기준 색 = **지은 직후 파트 색**(첫 적용 때 Attribute `EnhanceBaseColor`로 기억 → tint는 그 색에서 섞음). 지금 메시는 지을 때 `model.color`로 칠하므로 결과 동일.
- 확인(Play 3): 스위치 켬 초월 `Blade = #262230` · 스위치 끔 기존 `Weapon_Blade = #B4B6C0`(데이터 색 그대로) · 강화 tint 경로 무변경.

## 6. 바뀐 파일 · 커밋

| 커밋 | 내용 |
|---|---|
| 3976664 | 샘플 보강: `CartoonStyleData`(artV1 채도 · 잔디 · 허브 바닥) · `ArtStyleV1Data`(강화대 배율 · 색 · 불빛 · 연기 · 대성공 값) · `ArtV1Models`(ScaleTo · 연기) · `ArtV1View`(Beam 빛기둥 · 폭발 · 바닥 링 · 화면 반짝임 · 슬로 배율) |
| 9cecb16 | Blender: `make_rig_mesh.py` FBX 수정 · `make_greatsword.py` 신규 · `roblox/art/weapons/*`(FBX 3 · .blend · 메타 · 미리보기 Luau 3) |
| 930c6e6 | `WeaponEnhanceVisual` 기준 색 수정 |
| (이 커밋) | 문서: `docs/art/art-direction-v1.md`(외곽선 결정 · 채도 · 잔디 · 대성공 · 대검 등급 표) · `docs/art/3d-pipeline.md` · `docs/art/blender-production-order.md` · 이 보고서 · `STATE.md` |

- 경제 · 저장 · 판정 · 보안 변경 0 → 리뷰 서브에이전트 생략(§7-1). 검증 블록 동반 실행: 없음(아트 · 클라 겉모습 모듈만 - 검증 블록이 require하지 않음). 로컬: 바꾼 Luau 5파일 `luau-compile` O · `luau-analyze` = Roblox 전역 미정의 줄만.

## 7. 사용자 확인 목록

| 확인 | 방법 |
|---|---|
| 사냥 화면에서 슬라임이 잔디보다 먼저 보이는가(잔디를 더 내릴지) | `compare-hunt.png` 또는 Play → `/gg art on` → `/gg tp tier1 3` |
| 강화대가 40스터드에서 "강화하는 곳"으로 보이는가 · 주황 불빛 세기 | `compare-forge40.png` · 허브 대장간 거리 |
| 대성공 연출(빛기둥 · 폭발 · 링 · 반짝임)이 과하거나 약한가 | Studio 클라에서 `ReplicatedStorage:SetAttribute("ArtV1FxTest","great")`(슬로 = `ArtV1FxSlow` 5) 또는 강화 +5 단위 |
| Blender 대검 형태(모따기 날 · 작아진 날개)가 도형 조립보다 나은가 | `compare-parts-vs-blender-front.png` |
| 선물 팝업 · 상점 탭 구성 · 이름표 색(B 체감) | 상점 F · `/ops gift` |

## 8. 사용자가 할 일(Blender 대검을 게임에 넣기 - 상세 `docs/art/3d-pipeline.md` §2)

1. **지금 가능(약 3분)**: Studio → 파일 → Import 3D → `roblox\art\weapons\greatsword_transcendent.fbx` · 단위 Stud · Anchored · Import Only As Model → 가져온 모델을 알려 주면 부착점 · 규격 검사 · 손에 쥔 모습 확인을 이어서 한다.
2. **대량 생산 전(1회)**: Open Cloud API 키(`assets` 권한 · 이 경험) → 환경 변수 `ROBLOX_ASSETS_KEY`로만(파일 · 채팅 금지) + 사용자 ID.
3. (선택) 미리보기만: 게임 설정 → 보안 → Allow Mesh / Image APIs.

## 9. 결정 필요 · 임의 결정

- **결정 필요**: ① 가져오기 경로(①클릭 vs ②API 키) - 추천: 대검은 ①로 절차 확정 → 몬스터부터 ② ② 잔디를 더 어둡게 할지(체감 뒤) ③ 도형 조립 4종 유지 여부(추천 유지) ④ 대검 날개 크기(Blender 0.75 × 0.6 vs 데이터 0.95 × 0.85) ⑤ 태초 등급 전용 대검 look 추가 여부.
- 임의 결정: 강화대 배율 1.7(지시 1.5 ~ 2) · 화덕 돌 → 벽돌색 · 불빛 18 / 1.5 · 연기 = 엔진 기본 텍스처 · 대성공 입자 재배분(불꽃 20 → 14 + 폭발 6) · 화면 반짝임 +0.14 / 0.22초 · 슬로 배율 Attribute(Studio 전용) · Blender 날개 축소 · Play 1 도중 중단(B 후속 커밋이 올라와 옛 코드로 계속 돌리는 게 무의미).
- 알려진 X(추가): S20b 보석 탭 칸 0 vs 서버 1(원인 미확정) · 시즌 "남은 기간 0일"(결정 7 대기).
- 다음 Play 목록(남은 B 항목): 조각 출처(정거장 · 둥지 · 칭호) · 상점 폰 강제 스크린샷 · 음량 재접속 유지 · 테마 가짜 구매(시험 id) · 게임패스 Attribute.
