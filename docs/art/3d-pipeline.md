# 3D 파이프라인 — Blender → Studio 가져오기 경로 (A2-S2 · 2026-09-30)

> 첫 실측: Blender **5.2.2 LTS**(`C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`) · 백그라운드 실행 `blender -b --factory-startup -P <스크립트> -- <인자>` 동작 O.
> 조립 규칙 · 검사 · 교체 명령은 `blender-to-studio.md`(B3), 색 · 형태 규칙은 `art-direction-v1.md`, 제작 순서는 `blender-production-order.md`.
> 가져오기 경로는 **공식 문서 기준**(아래 출처). 추측으로 채운 칸 없음 - 확인 못 한 것은 "미확인"으로 적었다.

## 1. 경로 표

| 경로 | 사람 손 | 모델당 시간(추정) | 제한 | 이번 실측 | 추천 |
|---|---|---|---|---|---|
| ① Studio 3D 가져오기 창(File → Import 3D) | **매번 사람 클릭**(파일 고르기 · 설정 확인 · 가져오기) - 스크립트 · 플러그인 API가 문서에 없다 | 1 ~ 2분(여러 파일 한꺼번에 줄 세우기 가능) | .fbx · .obj · .gltf · "Upload to Roblox" 기본 켬 = 에셋으로 올라가 Toolbox · 에셋 관리자에 들어간다 | FBX 3개 준비 완료(`roblox/art/weapons/greatsword_<look>.fbx`) · 클릭은 사용자 몫이라 미실행 | **지금 추천(가장 확실)** - 13종 × 1회라 손이 감당된다. 설정은 `blender-to-studio.md` §5 |
| ② Open Cloud Assets API(`POST https://apis.roblox.com/assets/v1/assets` · `assetType = Model`) | **사용자가 API 키 1회 발급**(권한 `assets` + 대상 경험 읽기 · 쓰기) → 이후 명령줄 자동 | 업로드 수 초 + 처리 대기(작업 `operations/<id>` 폴링 → `assetId`) | .fbx · .gltf · .glb · .rbxm(OBJ 불가) · 요청당 20MB · 내용 갱신은 FBX만 · 검수(모더레이션) 통과 뒤 사용 | API 키 없음 → 미실행 | **대량 생산 때 추천** - 키를 환경 변수로만 쓰는 업로드 스크립트 1개면 13종 + 무기를 한 번에. 결과 에셋 ID를 `InsertService`/Studio에서 모델로 넣는 단계는 따로 필요(미확인 - 첫 실행 때 절차 확정) |
| ③ EditableMesh 스크립트 생성(`AssetService:CreateEditableMesh` → `CreateMeshPartAsync`) | 경험 설정 **보안 탭 "Allow Mesh / Image APIs" 켜기**(사용자) · 게시된 경험에서 쓰려면 13세 이상 · **ID 인증** · 명시적 동의(그룹 소유면 그룹 주인) | 없음(런타임에 데이터로 짓는다) | **런타임 전용 - 장소 파일에 저장되지 않고 자동 복제도 안 된다** · 클라 메모리 예산이 빡빡(서버 · Studio는 무제한) · 에셋으로 올리는 플러그인 API는 "예정"(발표 글 기준) | **X - `EditableMesh is not accessible. Go to the Security Tab in Experience Settings to enable this API.`**(Play 2 클라 실행) | 비추천(본 제작) · Studio 안 미리보기 용도로만(설정을 켜면 `greatsword_<look>.preview.luau`가 바로 돈다) |

**결론**: 사람 손이 가장 적은 길은 ②(키 발급 1회) - 하지만 키가 생기기 전까지는 ①이 유일하게 지금 되는 길이다. ③은 저장이 안 돼서 게임 에셋 경로가 될 수 없다.

## 2. 사용자가 할 일(단계별)

### ① 3D 가져오기로 대검 1자루 넣기(지금 바로 가능 · 약 3분)
1. Studio → 파일(File) → **Import 3D** → `C:\Users\xkrgh\vibe\game\roblox\art\weapons\greatsword_transcendent.fbx` 선택.
2. 설정: 단위 = **Stud** · **Anchored 켬** · **Import Only As Model 켬** · 리그 · 스킨 · 텍스처 끔(`blender-to-studio.md` §5).
3. 가져오기 → Workspace에 생긴 모델을 `ReplicatedStorage.Shared.WeaponModels` 폴더(없으면 만들기)로 옮기고 이름을 `greatsword`로.
4. 터미널에 "넣었다"고 알려 주면: 부착점(`Grip` · `Tip` · `Support` - 메타 `greatsword.meta.json`) · `PrimaryPart = Blade` · 규격 검사(`WeaponRigCheck` - 부팅 때 경고 줄) · `/gg art off` 상태에서 손에 쥔 모습을 Play로 확인한다(아트 스위치를 켜면 아트 도형 대검이 우선이다).
   - 부착점은 FBX에 안 들어간다(메시만) → 가져온 뒤 `Blade`에 Attachment 3개를 넣는 절차가 필요하다. Rojo 파일로 넣을 수 있게 가져온 모델을 `.rbxm`으로 저장해 `roblox/src/shared/WeaponModels/greatsword.rbxm`에 두는 방식을 추천(스크립트 편집 규칙상 Studio에서 손으로 넣은 것은 git에 안 남는다).

### ② Open Cloud 키(대량 생산 전 · 1회)
1. Creator Hub → 열린 클라우드(Open Cloud) → API 키 만들기 → 권한 `assets`(읽기 · 쓰기) + 이 경험 선택 · IP 제한 권장.
2. 키는 **파일 · 채팅 · 커밋에 쓰지 말고** 터미널 환경 변수로만: `setx ROBLOX_ASSETS_KEY "<키>"`(새 창부터 적용). 터미널은 `$env:ROBLOX_ASSETS_KEY`만 읽는다.
3. 사용자 ID(또는 그룹 ID)를 알려 준다(`creationContext.creator` 필요).

### ③ (선택) Studio 미리보기만
- Studio → 게임 설정(Game Settings) → 보안(Security) → **Allow Mesh / Image APIs** 켜기. 게시 경험에서 켜 둘 필요는 없다(미리보기 전용).

## 3. Blender 쪽 산출물(이번에 만든 것)

| 파일 | 내용 |
|---|---|
| `roblox/tools/blender/make_greatsword.py` | 대검 1형태 × look 3(일반 · 전설 · 초월). 파트 = `Blade`(모따기 육각 단면 + 뾰족 끝 한 메시) · `Fuller` · `Guard` · `Grip`(8각) · `Pommel` · 전설 이상 `Wing_R` · `Wing_L` · `Gem` · 초월 `Crack1` · `Crack2`. 피벗 = 손잡이 점(원점) |
| `roblox/art/weapons/greatsword_<look>.fbx` | Studio 가져오기 · Open Cloud용(축 = Roblox · 1 stud = 1) |
| `roblox/art/weapons/greatsword.blend` · `greatsword.meta.json` | 원본 · 파트별 삼각형 · 부착점 |
| `roblox/art/weapons/greatsword_<look>.preview.luau` | EditableMesh 미리보기(③ 설정이 켜져야 돈다) |
| `Claude outputs/ART-sample/blender/` | `blender-greatsword-front.png` · `blender-greatsword-34.png` · `compare-parts-vs-blender-front.png`(도형 조립과 나란히) |

삼각형: 일반 126 · 전설 162 · 초월 186(예산 800 · art-direction §6). 렌더는 Workbench(평면 · 스튜디오 조명) - 외곽선 옵션은 켰지만 렌더에 거의 안 보인다(게임 외곽선은 Highlight가 맡는다).

- 템플릿 `make_rig_mesh.py`(B3) 첫 실행 결과: 도형 · 삼각형 212(README 기대와 같음) · 메타 O, **FBX 내보내기 X → 수정**(재질 커스텀 속성 `PaletteRGB` 정수 목록을 FBX가 float64 단정에서 거부 → 16진 문자열). `Material.use_nodes`는 Blender 6.0에서 없어진다는 경고(지금은 동작).

## 4. 출처(공식 문서)

- Open Cloud Assets 사용법: https://create.roblox.com/docs/cloud/guides/usage-assets (형식 · 20MB · 권한 · 작업 폴링)
- 3D Importer: https://create.roblox.com/docs/art/modeling/3d-importer (File → Import · 형식 · Upload to Roblox 기본 켬 · 스크립트 API 언급 없음)
- AssetService / EditableMesh 참조: https://create.roblox.com/docs/reference/engine/classes/AssetService · https://create.roblox.com/docs/reference/engine/classes/EditableMesh
- EditableMesh 게시 조건(ID 인증 · 보안 설정 · 런타임 전용 · 복제 안 됨): Roblox 공식 발표 https://devforum.roblox.com/t/client-beta-in-experience-mesh-image-apis-now-available-in-published-experiences/3267293
