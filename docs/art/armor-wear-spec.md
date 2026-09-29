# 방어구 착용 명세 (A2-N2 · 2026-09-30)

> 대상 = 장비 3부위(`EquipSlots.order` = `armor` 갑옷 · `gloves` 장갑 · `shoes` 신발) × 세트 구역 6(`tier1` ~ `tier6` - `item.setZone`) × 등급 8(`ArmorData.gradeOrder`).
> 메시 = `roblox/tools/blender/make_armor_wear.py` → `roblox/art/armor/<부위>_<구역>_<등급>.fbx` + `armor_wear.meta.json`. 이 문서는 **착용 표시 코드가 아직 없을 때의 설계안**이다(코드 수정 0).

## 1. 지금 게임이 방어구를 어떻게 보여 주나 (코드 확인)

| 항목 | 현재 | 근거 |
|---|---|---|
| 캐릭터에 방어구 외형 | **없음** - 방어구는 방어력 · 공격% · 이동% 수치와 UI(아이콘 · 이름 · 등급 색)만 | `PlayerProfile.getEquippedArmor` → `PlayerDamage`(수치) · 클라 `ArmorData` 사용처는 전부 HUD · 패널 |
| 아이템 모양 | 드랍 · 아이콘용 상자 크기 3개뿐 | `ItemVisualData.lua` 102 ~ 104 |
| 다른 사람이 볼 데이터 | **없음** - 장착 방어구가 Player Attribute로 복제되지 않는다(무기는 `ClassId` · `WeaponGrade` Attribute로 복제) | `WeaponVisual.lua` 6 · `InventorySync.lua` 66 ~ 79 |
| 캐릭터 규격 | R15 이름 가정(관절 = AnimationConstraint · Motor6D 없음) · R6는 일부 폴백만 | `PoseRig.lua` 2 · 11 ~ 12 · `AirMotion.lua` 2 |
| 체형 배율 | 처리 없음(`BodyHeightScale` 등 0회) - 활 시위 자리만 머리 기준이라 체형 무관 | `WeaponRigSpec.lua` 19 |
| 부착 선례 | 무기 = 고정(Anchored) · 충돌 없는 파트를 **매 프레임 손 · 몸 파트 CFrame에 맞춰 놓는다**(용접 아님) · 거리 220 밖은 폴더를 nil | `WeaponVisual.lua` 879 ~ 881 · 1039 ~ 1085 · 43 |
| 치장 | 이동 효과 5칸(대시 · 점프 · 활강 · 발자국 · 글라이더) - 옷 칸 없음 | `CosmeticSlotData.lua` 7 ~ 13 |

→ **표시 기능 없음.** 아래는 착용 표시 설계안(2안 비교 + 추천)과 메시가 지키는 규격이다.

## 2. 부착 방식 2안

| 항목 | 1안 - 서버 Accessory(R15 표준 Attachment 이름 · 엔진 용접) | 2안 - 클라 조각 + WeldConstraint(무기와 같은 쪽 · 추천) |
|---|---|---|
| 방식 | 서버가 `Accessory`(Handle = MeshPart + `BodyFrontAttachment` 같은 표준 이름)를 `Humanoid:AddAccessory` | 각 클라가 장착 Attribute(`ArmorLook_<부위>` = "구역 · 등급")를 보고 조각 MeshPart를 R15 파트에 `WeldConstraint`(Massless · 충돌 · 쿼리 · 터치 끔) |
| 복제 | 자동(서버 인스턴스) | Attribute 3개만 복제 · 조각은 클라마다 |
| 체형 대응 | 엔진이 Attachment 자리에 붙임 · 배율은 HumanoidDescription 경로일 때만 자동(미확인 - 첫 가져오기 때 실측) | 조각 배율 = 붙는 파트 `Size ÷ 기준 Size`(아래 §4) - 코드가 직접 |
| 아트 스위치 · 설정 | 서버 상태라 개인 설정(끄기 · 폰 단순화)이 어렵다 | `ArtStyleV1` · "남의 방어구 숨기기" · 거리 컬링(무기와 같은 220)을 클라에서 |
| 성능(폰) | 서버 파트 × 인원 · 물리 소유 · 복제 트래픽 | 폰이 거리 · 인원으로 줄인다(남의 캐릭터 = 갑옷 몸통만 등) · 매 프레임 비용 없음(용접) |
| 모션 | 엔진 용접 - AnimationConstraint 관절과 같이 움직임 | 같음(파트에 용접) |
| 코드 양 | 적음(서버 1곳) | 중간(무기 `WeaponVisual` 바인딩 패턴 재사용 - 내 캐릭터 · 남 · 더미) |
| 판정 · 경제 · 저장 | 영향 없음 | 영향 없음(Attribute = 화면 전용 복사본) |

**추천 = 2안.** 이유 ① 외형은 전부 `ArtStyleV1` 스위치 뒤 · 클라 VFX 규칙과 같은 층 ② 폰 예산을 사람마다 조절 ③ 무기 표시와 같은 바인딩 · 컬링 코드를 재사용. 무기처럼 매 프레임 CFrame을 쓰지 않고 **용접**을 쓰는 것만 다르다(조각이 파트와 강체로 같이 움직이므로 계산 0).

## 3. 조각 표(부위당 조각 ≤ 4 · MeshPart ≤ 12)

| 부위 | 조각 | 붙는 R15 파트 | 역할 |
|---|---|---|---|
| 갑옷 `armor` | `Chest` | `UpperTorso` | 가슴 · 등 껍데기(몸통을 0.06 ~ 0.1 감쌈) |
| | `Shoulder_L` · `Shoulder_R` | `LeftUpperArm` · `RightUpperArm` | 어깨 받이(윗팔 위 절반 - 팔을 들면 같이 돈다) · **구역 실루엣의 주인공** |
| | `Belt` | `LowerTorso` | 허리띠 + 앞 · 옆 드림(허벅지 위 0.35까지 - 걸을 때 다리와 겹치지 않게 얇게) |
| 장갑 `gloves` | `Glove_L` · `Glove_R` | `LeftHand` · `RightHand` | 손 덮개(주먹 마디) - **무기 손잡이 점(`WeaponRigSpec.palm` = (0, −0.18, −0.05))을 가리지 않게 손바닥 쪽(아래)은 얇게** |
| | `Bracer_L` · `Bracer_R` | `LeftLowerArm` · `RightLowerArm` | 팔찌(아래팔 아래 60%) |
| 신발 `shoes` | `Boot_L` · `Boot_R` | `LeftFoot` · `RightFoot` | 발 껍데기 + 앞코 |
| | `Greave_L` · `Greave_R` | `LeftLowerLeg` · `RightLowerLeg` | 정강이 판 + 무릎 받이 |

- 한 조각 = 색마다 MeshPart 1개: `<조각>`(구역 본체 색) · `<조각>_Trim`(구역 강조 → 영웅부터 등급 색) · `<조각>_Grade`(희귀 띠 · 고대 날개 = 등급 색) · `<조각>_Glow`(Neon - 전설 보석 · 유물 룬 · 태초 결정 · 초월 균열). 태초 · 초월의 떠 있는 결정 · 흑금 조각은 **대표 조각**(Chest · Bracer_R · Greave_R)에만.
- 삼각형 = **부위 하나(조각 전부) ≤ 800**(art-direction §6).

## 4. 크기 · 자리 기준

- **기준 체형 = R15 블록형 기본 파트 크기**: UpperTorso (2, 1.6, 1) · LowerTorso (2, 0.4, 1) · UpperArm (1, 1.17, 1) · LowerArm (1, 1.05, 1) · Hand (1, 0.3, 1) · LowerLeg (1, 1.19, 1) · Foot (1, 0.3, 1). (값 = 표준 R15 블록형 - 이 place의 실제 아바타는 첫 가져오기 때 `Size`를 읽어 표를 실측으로 바꾼다.)
- 메타 `armor_wear.meta.json`의 조각마다: `attach`(R15 파트 이름) · `offset`(메시 경계 상자 가운데 - 파트 가운데 기준 · 파트 로컬 · 기준 체형 stud) · `refSize`(기준 파트 크기). FBX에서 가져온 MeshPart의 Position = 경계 상자 가운데라서 `offset`이 곧 용접 자리다.
- 용접 식: `조각.CFrame = 파트.CFrame * CFrame.new(offset * k)` · 조각 `Size *= k` 와 같은 배율로(MeshPart는 Size로 늘어난다).

## 5. 체형 차이 규칙

| 경우 | 규칙 |
|---|---|
| 배율 k | 축별 `k = 파트.Size ÷ refSize` → **X · Z는 같은 값 `max(kx, kz)`**(둥근 껍데기가 한쪽으로 찌그러지지 않고, 작은 쪽에 맞춰 몸에 박히지 않게) · Y는 따로 |
| 극단 체형(Rthro · 아주 넓음) | 각 축 k를 **0.8 ~ 1.35**로 자른다. 넘으면 조각이 몸에 박히거나 뜬다 → 자른 채로 두고 뜨는 것은 허용(박히는 것보다 낫다) |
| 머리 · 목 | 방어구는 머리에 아무것도 안 붙인다(투구 없음 - 아바타 얼굴 · 모자 존중) · Chest 목 둘레는 열어 둔다(목 높이 차이) |
| 어깨 너비 | Shoulder는 윗팔 기준이라 몸통 너비와 무관하게 팔에 붙는다(넓은 체형에서 어깨받이가 몸통에 묻히지 않는다) |
| 손 · 무기 | Glove 손바닥 면 두께 ≤ 0.08 - 무기 손잡이 자리(palm)와 겹쳐도 무기가 위에 그려지게 |
| 치마형 아바타 옷 · 레이어 옷 | 방어구가 위를 덮는다(레이어 옷 케이지 대응 없음 - 강체 조각) |
| R6 | 표시 안 함(조각 표가 R15 이름만) |

## 6. 가져오기 뒤 할 일(파일당)

1. FBX 1개 = 한 부위 한 구역 한 등급(`armor_tier3_legendary.fbx` 등 - 일반 · 전설 · 초월 look만 FBX, 아이콘은 8등급 전부). 오브젝트 이름 = 위 조각 이름 그대로.
2. 가져온 모델을 `ReplicatedStorage.Shared.ArmorModels.<부위>_<구역>_<등급>`에 두고, 조각마다 메타 `attach` · `offset`을 Attribute로 옮긴다(`/gg mesh` 도우미 확장 후보).
3. 확인: `/gg art on` + 기본 아바타 · 넓은 아바타 2종에서 서기 · 달리기 · 공격 · 활강 스크린샷 - 박힘 · 뜸 · 무기 손잡이 가림 3가지.
