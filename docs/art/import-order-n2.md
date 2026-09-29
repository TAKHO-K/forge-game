# 가져오기 순서표 v2 (A2-N2 · 2026-09-30)

> A2-N1 보고서 §4(13단계)에 A2-N2 수정분(보스 테마 색 · 펫 장식 · 무기 실루엣 · 드래곤 · 방어구 착용형 · 뿅망치 · 전조 메시)을 합친 표. 경로 = ① Studio 3D 가져오기 창(사람 클릭) 또는 ② Open Cloud(키 발급 뒤) - `3d-pipeline.md`.
> 공통 설정(모든 FBX): 단위 **Stud** · **Anchored 켬** · **Import Only As Model 켬** · 리그 · 스킨 · 텍스처 끔 · 축 = 이미 구움(−Z 앞 / Y 위 · 파트 회전 0). 색은 데이터 · 코드가 칠한다(메시 재질 색 = 렌더용).
> 메시 모양만 가져오고 **판정 · 경제 · 저장은 바뀌지 않는다**(몬스터 Hitbox · 무기 규격 · 강화대 판정 파트 그대로). 켜기 = `ArtStyleV1` 스위치.

## 1. 순서표

| 순서 | 파일 | 넣을 자리 · 이름 | 가져온 뒤 할 일 | 확인 항목(파일당) |
|---|---|---|---|---|
| 1 | `roblox/art/weapons/greatsword_<등급>.fbx`(8) | `ReplicatedStorage.Shared.WeaponModels.greatsword`(등급별 모델 고르는 코드 = 다음 단계) | 부착점 `Grip` · `Tip` · `Support` = `greatsword.meta.json` `attachments` → `Blade` 아래 Attachment · PrimaryPart = Blade | 부팅 `WeaponRigCheck` 경고 0 · 손에 쥔 모습 3각도 · 삼각형 ≤ 800 |
| 2 | `dualblade_<등급>.fbx`(8 · **A2-N2 희귀 · 영웅 실루엣**) | `WeaponModels.dualblade` `BladeRight` · `BladeLeft`(같은 모델 복제) | Grip · Tip | 좌우 대칭 복제 방향 · 희귀 가드 뿔이 손목에 안 묻힘 |
| 3 | `bow_<등급>.fbx`(8 · **A2-N2 희귀 · 영웅**) | `WeaponModels.bow` | **`String` 파트 삭제**(시위 = 코드) · Grip · Tip · StringNock | 영웅 초승달 날이 시위 코드와 안 겹침 · 전설 84%(목표 초과 - 허용) |
| 4 | `healer_<등급>.fbx`(8 · **A2-N2 희귀 · 영웅**) | `WeaponModels.healer` | Grip · Tip · Support · 머리 = +Y | 영웅 초승달 = 떠 있는 장식(연결 없음 - 의도) |
| 5 | `paladin_<등급>.fbx`(8 · **새 · 게임 연결 없음**) | `WeaponModels.paladin`(`Hammer`) | 원점 = 손잡이 점 → **grip = 0**(규격 `WeaponRigSpec.paladin` grip −0.75와 기준이 다름 - 가져올 때 맞춘다) · 방패는 아직 없음 | 성기사 직업이 생길 때까지 보관만 |
| 6 | `roblox/art/monsters/<종>.fbx`(10 · 슬라임 · 양 제외 · **드래곤 = A2-N2 날개 6.4**) | 몬스터 교체 폴더 → `/gg mesh check <종>` · `/gg mesh swap <종>` | **A2-N2: 기준 루트 없는 FBX는 메타 정렬**(`ReplicatedStorage.Shared.MeshMeta.<종>` = `center` 평균 이동 · 어긋남 ≤ 0.05 stud면 O) → 관절 C0 · C1 = 규격 관절 프레임(회전 파트 = 엄니 · 목 · 날개 · 꼬리도 같은 움직임 - 하네스 O) | `[MeshSwap] 메타 정렬 … O` 줄 · 끼움 n/n · 전조 포즈 1회 · 드래곤 게임 배율 ×1.2는 결정 필요 |
| 7 | `roblox/art/props/forge.fbx` | `ArtV1Models.forge` 파트 20 자리(같은 이름) | 원점 = 코드 파트 자리(배율 1.7 전) · 불빛 · 연기 · 불씨 = 코드 | 판정 파트(Base · AnvilTop) 그대로 숨김 |
| 8 | `boss_gate.fbx` + `extras/gate_decor/<보스>.fbx`(6 · **A2-N2 검토 반영**) | `BossGateKit.frame` 돌 부분(meta `codeName`) + 보스별 장식(새 자리 - `BossGateKit`에 보스 id → 장식 모델 표 추가 필요) | 빛 테 · 문양 · 막 · 발판 · 프롬프트 = 코드 파트 그대로 · 장식 색 = 보스 테마 색(코드) | 틀 3,000 이하 · 장식이 관문 입구를 가리지 않음 |
| 9 | `rebirth_altar.fbx` | `HuntingGround.createRebirthAltar`(Base · Orb 이름 유지) + `Ring` | Orb = Neon 유지 | 프롬프트 · 이름표 붙는 자리 = Orb |
| 10 | `roblox/art/bosses/<보스>.fbx`(6 · **A2-N2 테마 색 · 상한 40 · 전갈 48**) | 보스 리그 교체(파트 = BossRigSpec part · `<파트>_Outline` = 같은 뼈 용접) | **몸 색 = 메타 `themeColors`를 ArtStyleV1 뒤에서 칠함**(BossData 티어 색은 그대로 - 스위치 꺼짐 = 지금과 같게) · 껍데기 있는 보스 = Highlight 끔 · **전갈 여왕 = 껍데기 0 → Highlight 유지** | 파트 ≤ 40(전갈 48) · 삼각형 ≤ 6,000 · 전조 동작 파트(팔 · 주먹 · 머리) 분리 유지 |
| 11 | `roblox/art/pets/<몸 틀>_<등급>.fbx`(9 · **A2-N2 목줄 · 리본 · 스카프 / 보석 · 무늬 · 왕관**) | `PetData.rigs` 파트 자리(이름 · 중심 = pos) | 희귀 = 메타 `glowPoint` 자리에 PointLight(코드) · 색 = 구역 색(코드) · **알 등급 → 외형 등급을 잇는 코드 필요**(부화 결과는 펫 등급 4단계 common ~ epic) | 장식이 움직이지 않는 accent 파트에만 붙음(PetView는 Wing · Head만 움직임) |
| 12 | `roblox/art/icons/weapons/*.png`(40 = 4무기 × 8 + 뿅망치 8) · `icons/armor/*.png`(144 · **A2-N2 착용형 다시**) | Open Cloud 이미지(Decal) → 장비창 아이콘 표 | 파일명 = `<직업>_<등급>` · `<슬롯>_<구역 키>_<등급>` · 256 × 256 투명 · **테두리 = 코드 등급 프레임(A2-N2 `GradeFrame` - 아이콘 안에 테두리 넣지 않음)** | 장비창 칸 안 여백(아이콘 88% 이하) · 폰 800 × 360에서 등급 구별 |
| 13 | `roblox/art/props/kit/<틀 이름>.fbx`(33) | `Shared.PropModels.<틀 이름>`(PropData `overrideFolders`) | 충돌 파트 이름 그대로 · 새 후보 7은 PropData.templates 추가 뒤 | 발자국 = 틀과 같은 상자 |
| 14 | `roblox/art/armor/<부위>_<구역>_<등급>.fbx`(54 · **A2-N2 착용형**) | 새 `Shared.ArmorModels`(아직 없음) | **착용 표시 기능 먼저**(`docs/art/armor-wear-spec.md` 2안 = 클라 조각 + WeldConstraint · 스위치 뒤) → `armor_wear.meta.json` 조각마다 attach(R15 파트) · offset · refSize | 기준 체형 = 이 place 아바타 실측으로 refSize 확인 · 체형 배율 0.8 ~ 1.35 자름 |
| 15 | `roblox/art/extras/vfx/Telegraph{Circle,Cone,Line}.fbx` · `ShockRing` · `WarnPillar` · `ImpactStar` | 전조 · 연출 메시(선택) | **지금 게임 안 전조 테두리 = 코드(`TelegraphStyle` - HandleAdornment · 두께 0.55 고정)**. 메시 Edge는 크기의 8%라 원이 커지면 테두리가 두꺼워진다 → 메시는 꺾쇠 · 화살 같은 **모양 장식에만** 쓰고 테두리 두께 규칙은 코드 쪽을 따른다 | 색 = `ArtV1FxData.telegraph` · 입자 0 |
| 16 | `extras/transcend_crystal.fbx` | 초월 획득 연출 소품(새 자리) | 금 균열 = Neon · 흑금 규칙 | 초월 전용(태초 이하에 쓰지 않음) |

## 2. 파일당 공통 확인(가져온 직후 1분)
1. 이름: MeshPart 이름 = 표의 파트 이름(`Blade` · `Body` · `Tusk_L` …) - Studio가 붙이는 `.001` 접미사 없음.
2. 크기: 모델 경계 ≈ 메타(`/gg mesh check`가 비율 0.8 ~ 1.25 밖이면 단위 힌트 출력).
3. 삼각형: 메타 `totalTris` ≤ 예산(art-direction §6).
4. 재질: SmoothPlastic(Neon = 메타 `neon` 파트만) · 텍스처 · SurfaceAppearance 0.
5. 스위치: `/gg art off`에서 지금 게임과 같은지 1장 · `on`에서 3각도 1장씩.
