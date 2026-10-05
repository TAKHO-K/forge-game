# 31_bosses _ref — 보스 6 부위 · 관절 · 크기 표 (ref-parts)

- 만든 날: 2026-10-05 · QUEUE-ART-REF2(읽기 · 캡처 · 문서 추가만 - 게임 코드 · 데이터 · 에셋 변경 0)
- 대상: spec v1 "결정할 것" 1번(부위 이름 · 크기 · 관절 표) + 확인 a · b · c(맨 끝 "확인" 절).
- 출처 = **아레나 실전 보스 인스턴스 실측**(Studio Play · `/gg boss force <id>` → `/gg boss` · 클라이언트에서 Motor6D · WeldConstraint · 크기 · 재질 · 색을 그대로 읽음). 추측 값 없음.
- 그림 = `C:\Users\xkrgh\vibe\claude-design-handoff\31_bosses\_ref\` 새 파일 11장(`arena_*` 7장 · `bloom_*` 4장 · 기존 `boss_*` 12장은 그대로 둠).

## 먼저 알아 둘 것 — 지난 `_ref` 사진(`boss_*_a/b.png`)은 실전 모습이 아니다

| 구분 | 지난 사진 `boss_*_a/b.png` | 실전(아레나) · 이 표 |
|---|---|---|
| 만든 방법 | `/gg boss anim <id> idle` 전시 리그 | 서버 스폰 보스(`server/MonsterSpawner.lua:141-142`) |
| 몸 | `BossRig.build`만(`client/BossAnimator.client.lua:929`) = 코드 상자 파트 + 코드 장식(`BossDetailSpec` deco · `Deco_*`) | 같은 리그에 **Blender 메시를 끼움**(`ArtMeshKit.applyRig` - A2-N3) · 코드 장식은 지우고(`shared/ArtMeshKit.lua:71-74`) 메시 장식(`<부위>_DecoN`) · 외곽선 껍데기(`<부위>_Outline`)를 붙임 |
| 보이는 차이 | 각진 상자 · 전갈 여왕 금 조각이 떠 있음 · 심해 군주 어깨 쪽 큰 빛 | 둥근 메시 · 외곽선 · 떠 있는 조각 없음 |

→ v2는 이 표와 `arena_*.png`(실전)를 "지금 모습"으로 본다. 관절 이름 · 계층은 두 경우가 같다(메시가 같은 Motor6D에 끼워짐).

## 표 읽는 법
- 크기 · 자리 = stud(리그 배율이 이미 곱해진 실제 값). C0 = Motor6D.C0(부모 파트 공간에서 관절 자리 · 회전). 장식 자리 = 붙은 부위 공간에서 장식 가운데.
- 메시 리그의 C0 회전에는 Y 180°가 들어 있다(`-180,0,-180` = Y 180°) → 메시 부위의 **앞(얼굴) = 부모 공간 +Z**(예: 수호자 `Eyes` C0 Z +1.68). 코드 상자 리그는 앞 = −Z.
- 실측 높이는 아레나에서 그 순간 자세(대기 · 공격 중일 수 있음)의 보이는 파트 경계다. 지난 `ref.md` 높이(전시 리그 대기 자세)와 조금 다르다: 수호자 22.4 → 23.9 · 서리 거인 30.0 → 28.4 · 심해 군주 19.7 → 18.2 · 수정 여왕 21.0 → 19.6 · 전갈 여왕 17.5 → 15.9 · 폭풍 군주 21.9 → 25.1(지팡이를 든 공격 자세).
- 같은 보스 안 `_L` · `_R`는 X 부호만 반대.
- 코드 상자 리그의 원본 수치(sizeScale 1 기준)는 `roblox/src/shared/data/BossRigSpec.lua`(관절) · `BossDetailSpec.lua`(장식)에 있다 - 이 표는 메시가 끼워진 실전 값.

## 구간 수호자 `section_guardian` (tier1 석조 평원)

- 배율: sizeScale 3 × bodyScale 1.3 = 리그 배율 **3.9**(HumanoidRootPart 7.80 × 7.80 × 3.90의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **23.94 stud** · 보이는 파트 69개 · Neon 9개 · 전체 BasePart 72개
- 구성: 관절 부위(Motor6D) 28 · 장식(용접) 31 · 외곽선 껍데기(`_Outline` · 잉크색) 10 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| BannerL1 | 2.13 × 2.00 × 0.41 | BannerL1 | Hips | 3.04,0.59,-1.33 | 176,-0,-174 | SmoothPlastic | 90,30,100 |
| BannerL2 | 1.97 × 1.99 × 0.50 | BannerL2 | BannerL1 | -0.09,-0.89,0.06 | 173,-0,-174 | SmoothPlastic | 90,30,100 |
| BannerL3 | 1.82 × 1.98 × 0.59 | BannerL3 | BannerL2 | -0.09,-0.89,0.11 | 170,-1,-174 | **Neon** | 190,110,255 |
| BannerR1 | 2.13 × 2.00 × 0.41 | BannerR1 | Hips | -3.04,0.59,-1.33 | 176,0,174 | SmoothPlastic | 90,30,100 |
| BannerR2 | 1.97 × 1.99 × 0.50 | BannerR2 | BannerR1 | 0.09,-0.89,0.06 | 173,0,174 | SmoothPlastic | 90,30,100 |
| BannerR3 | 1.82 × 1.98 × 0.59 | BannerR3 | BannerR2 | 0.09,-0.89,0.11 | 170,1,174 | **Neon** | 190,110,255 |
| Body | 10.48 × 7.22 × 5.54 | Waist | Hips | 0.00,1.95,0.00 | -180,0,-180 | SmoothPlastic | 60,20,70 |
| Eyes | 3.20 × 1.07 × 0.39 | Eyes | Head | 0.00,1.62,1.68 | -180,0,-180 | **Neon** | 232,204,255 |
| Foot_L | 3.35 × 1.17 × 5.44 | Ankle_L | Shin_L | 0.00,-1.87,-0.27 | -180,0,-180 | SmoothPlastic | 93,68,103 |
| Foot_R | 3.35 × 1.17 × 5.44 | Ankle_R | Shin_R | 0.00,-1.87,-0.27 | -180,0,-180 | SmoothPlastic | 93,68,103 |
| Forearm_L | 3.87 × 4.29 × 3.75 | Elbow_L | UpperArm_L | 0.32,-1.95,0.00 | 172,1,174 | SmoothPlastic | 90,30,100 |
| Forearm_R | 3.87 × 4.29 × 3.75 | Elbow_R | UpperArm_R | -0.32,-1.95,0.00 | 172,-1,-174 | SmoothPlastic | 90,30,100 |
| Hand_L | 6.04 × 5.28 × 6.55 | Wrist_L | Forearm_L | 0.03,-1.76,0.05 | 172,1,174 | SmoothPlastic | 90,30,100 |
| Hand_R | 6.04 × 5.28 × 6.55 | Wrist_R | Forearm_R | -0.03,-1.76,0.05 | 172,-1,-174 | SmoothPlastic | 90,30,100 |
| Head | 4.38 × 4.86 × 4.45 | Neck | Body | 0.00,3.02,-0.36 | -180,0,-180 | SmoothPlastic | 90,30,100 |
| Hips | 6.99 × 4.29 × 4.49 | RootJoint | HumanoidRootPart | 0.00,6.89,0.00 | -0,0,-0 | SmoothPlastic | 30,10,35 |
| LeftPauldron | 6.02 × 2.71 × 6.86 | Pauldron_L | UpperArm_L | 0.32,1.77,0.00 | -180,0,174 | SmoothPlastic | 90,30,100 |
| Mouth | 1.89 × 0.48 × 0.39 | Jaw | Head | 0.00,0.36,1.68 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| RightPauldron | 7.87 × 6.14 × 9.00 | Pauldron_R | UpperArm_R | -0.32,1.77,0.00 | -180,0,-174 | SmoothPlastic | 90,30,100 |
| Rune | 4.46 × 4.46 × 0.47 | Rune | Body | 0.00,0.49,2.21 | -180,0,-180 | **Neon** | 190,110,255 |
| Shin_L | 3.00 × 3.74 × 3.55 | Knee_L | Thigh_L | 0.00,-1.56,0.00 | -180,0,-180 | SmoothPlastic | 30,10,35 |
| Shin_R | 3.00 × 3.74 × 3.55 | Knee_R | Thigh_R | 0.00,-1.56,0.00 | -180,0,-180 | SmoothPlastic | 30,10,35 |
| TassetB | 4.09 × 2.78 × 0.91 | TassetB | Hips | 0.00,0.35,-2.18 | 174,0,-180 | SmoothPlastic | 136,98,146 |
| TassetF | 4.09 × 2.78 × 0.91 | TassetF | Hips | 0.00,0.35,2.18 | -174,0,-180 | SmoothPlastic | 136,98,146 |
| Thigh_L | 3.07 × 3.12 × 2.98 | Hip_L | Hips | 1.95,0.00,0.00 | -180,0,-180 | SmoothPlastic | 60,20,70 |
| Thigh_R | 3.07 × 3.12 × 2.98 | Hip_R | Hips | -1.95,0.00,0.00 | -180,0,-180 | SmoothPlastic | 60,20,70 |
| UpperArm_L | 3.14 × 4.16 × 2.98 | Shoulder_L | Body | 5.85,1.70,-0.36 | -180,0,174 | SmoothPlastic | 93,68,103 |
| UpperArm_R | 3.14 × 4.16 × 2.98 | Shoulder_R | Body | -5.85,1.70,-0.36 | -180,0,-174 | SmoothPlastic | 93,68,103 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Body_Deco1 | 7.93 × 7.10 × 4.84 | Body | 0.00,2.44,-3.71 | Glass | 190,110,255 |  |
| Body_Deco2 | 9.92 × 2.95 × 2.22 | Body | 0.00,0.10,-3.17 | Glass | 190,110,255 | 예 |
| Body_Deco3 | 5.23 × 1.83 × 0.16 | Body | 0.00,-0.31,2.45 | **Neon** | 190,110,255 | 예 |
| Body_Deco4 | 7.99 × 6.39 × 1.04 | Body | 0.00,-0.22,2.53 | SmoothPlastic | 136,98,146 |  |
| Body_Deco5 | 9.69 × 4.29 × 6.60 | Body | 0.00,-0.10,-0.26 | SmoothPlastic | 94,69,104 |  |
| Forearm_L_Deco1 | 3.93 × 2.37 × 3.91 | Forearm_L | -0.20,0.37,-0.25 | SmoothPlastic | 136,98,146 |  |
| Forearm_L_Deco2 | 2.15 × 2.20 × 2.11 | Forearm_L | -0.32,1.51,-1.59 | SmoothPlastic | 94,69,104 |  |
| Forearm_R_Deco1 | 3.93 × 2.37 × 3.91 | Forearm_R | 0.20,0.37,-0.25 | SmoothPlastic | 136,98,146 |  |
| Forearm_R_Deco2 | 2.15 × 2.20 × 2.11 | Forearm_R | 0.32,1.51,-1.59 | SmoothPlastic | 94,69,104 |  |
| Hand_L_Deco1 | 3.80 × 1.53 × 1.15 | Hand_L | 0.03,-0.36,1.86 | SmoothPlastic | 94,69,104 | 예 |
| Hand_R_Deco1 | 3.80 × 1.53 × 1.15 | Hand_R | -0.03,-0.36,1.86 | SmoothPlastic | 94,69,104 | 예 |
| Head_Deco1 | 4.19 × 3.39 × 1.95 | Head | 0.00,4.18,-0.61 | Glass | 190,110,255 |  |
| Head_Deco2 | 5.42 × 1.69 × 1.52 | Head | 0.00,3.32,-0.74 | Glass | 190,110,255 | 예 |
| Head_Deco3 | 4.68 × 1.27 × 1.51 | Head | 0.00,2.19,1.44 | SmoothPlastic | 136,98,146 |  |
| Head_Deco4 | 5.30 × 2.95 × 2.25 | Head | -0.00,0.48,0.66 | SmoothPlastic | 94,69,104 |  |
| Hips_Deco1 | 2.87 × 2.87 × 0.94 | Hips | 0.00,1.17,2.18 | Glass | 190,110,255 |  |
| Hips_Deco2 | 8.19 × 1.72 × 3.90 | Hips | 0.00,1.05,0.00 | SmoothPlastic | 94,69,104 |  |
| LeftPauldron_Deco1 | 1.97 × 0.51 × 0.16 | LeftPauldron | 0.12,-1.75,2.57 | **Neon** | 190,110,255 | 예 |
| LeftPauldron_Deco2 | 4.78 × 1.65 × 5.07 | LeftPauldron | 0.20,-0.64,0.00 | SmoothPlastic | 136,98,146 |  |
| LeftPauldron_Deco3 | 1.87 × 2.70 × 3.82 | LeftPauldron | 0.99,0.42,-0.07 | SmoothPlastic | 94,69,104 |  |
| RightPauldron_Deco1 | 1.97 × 0.51 × 0.16 | RightPauldron | -0.12,-3.36,2.57 | **Neon** | 190,110,255 | 예 |
| RightPauldron_Deco2 | 4.78 × 1.65 × 5.07 | RightPauldron | -0.20,-2.26,0.00 | SmoothPlastic | 136,98,146 |  |
| RightPauldron_Deco3 | 1.87 × 2.70 × 3.82 | RightPauldron | -0.99,-1.19,-0.07 | SmoothPlastic | 94,69,104 |  |
| Shin_L_Deco1 | 2.81 × 2.34 × 0.78 | Shin_L | 0.00,-0.23,1.21 | SmoothPlastic | 94,69,104 |  |
| Shin_R_Deco1 | 2.81 × 2.34 × 0.78 | Shin_R | 0.00,-0.23,1.21 | SmoothPlastic | 94,69,104 |  |
| Thigh_L_Deco1 | 2.34 × 1.87 × 1.30 | Thigh_L | 0.00,-1.48,1.56 | SmoothPlastic | 136,98,146 |  |
| Thigh_L_Deco2 | 3.35 × 2.03 × 3.35 | Thigh_L | 0.00,0.55,0.00 | SmoothPlastic | 94,69,104 |  |
| Thigh_R_Deco1 | 2.34 × 1.87 × 1.30 | Thigh_R | 0.00,-1.48,1.56 | SmoothPlastic | 136,98,146 |  |
| Thigh_R_Deco2 | 3.35 × 2.03 × 3.35 | Thigh_R | 0.00,0.55,0.00 | SmoothPlastic | 94,69,104 |  |
| UpperArm_L_Deco1 | 0.42 × 2.19 × 0.19 | UpperArm_L | 1.71,-0.24,0.00 | **Neon** | 190,110,255 | 예 |
| UpperArm_R_Deco1 | 0.42 × 2.19 × 0.19 | UpperArm_R | -1.71,-0.24,0.00 | **Neon** | 190,110,255 | 예 |

- 외곽선 껍데기: Body(10.92 × 7.61 × 5.96) · Forearm_L(4.27 × 4.65 × 4.16) · Forearm_R(4.27 × 4.65 × 4.16) · Hand_L(6.43 × 5.66 × 6.93) · Hand_R(6.43 × 5.66 × 6.93) · Head(4.72 × 5.27 × 4.81) · LeftPauldron(6.46 × 3.14 × 7.31) · RightPauldron(8.31 × 6.55 × 9.45) · UpperArm_L(3.54 × 4.50 × 3.35) · UpperArm_R(3.54 × 4.50 × 3.35)
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 9.36 × 6.63 × 5.07 · Head_Query 4.29 × 3.71 × 3.90
- **빛(Neon) 파트**: BannerL3 1.82 × 1.98 × 0.59 (190,110,255) · BannerR3 1.82 × 1.98 × 0.59 (190,110,255) · Body_Deco3 5.23 × 1.83 × 0.16 (190,110,255) · Eyes 3.20 × 1.07 × 0.39 (232,204,255) · LeftPauldron_Deco1 1.97 × 0.51 × 0.16 (190,110,255) · RightPauldron_Deco1 1.97 × 0.51 × 0.16 (190,110,255) · Rune 4.46 × 4.46 × 0.47 (190,110,255) · UpperArm_L_Deco1 0.42 × 2.19 × 0.19 (190,110,255) · UpperArm_R_Deco1 0.42 × 2.19 × 0.19 (190,110,255)

## 서리 거인 `frost_giant` (tier6 빙하 동굴)

- 배율: sizeScale 3.3 × bodyScale 1.35 = 리그 배율 **4.46**(HumanoidRootPart 8.91 × 8.91 × 4.45의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **28.35 stud** · 보이는 파트 61개 · Neon 2개 · 전체 BasePart 64개
- 구성: 관절 부위(Motor6D) 28 · 장식(용접) 23 · 외곽선 껍데기(`_Outline` · 잉크색) 10 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| Beard1 | 3.62 × 3.19 × 2.10 | Beard1 | Head | -0.00,-2.00,1.07 | -172,0,-180 | SmoothPlastic | 200,240,255 |
| Beard2 | 2.69 × 3.12 × 1.83 | Beard2 | Beard1 | 0.09,-0.67,-0.17 | -166,0,-180 | SmoothPlastic | 200,240,255 |
| Beard3 | 1.31 × 2.78 × 1.47 | Beard3 | Beard2 | 0.07,-0.66,-0.27 | -160,0,-180 | SmoothPlastic | 200,240,255 |
| Body | 13.57 × 12.58 × 5.95 | Waist | Hips | -0.00,1.20,0.00 | -180,0,-180 | SmoothPlastic | 96,150,204 |
| Eyes | 2.91 × 0.97 × 0.45 | Eyes | Head | -0.00,0.53,1.96 | -180,0,-180 | **Neon** | 235,249,255 |
| Foot_L | 3.21 × 1.34 × 4.45 | Ankle_L | Shin_L | -0.00,-2.54,-0.13 | -180,0,-180 | SmoothPlastic | 67,105,142 |
| Foot_R | 3.21 × 1.34 × 4.45 | Ankle_R | Shin_R | -0.00,-2.54,-0.13 | -180,0,-180 | SmoothPlastic | 67,105,142 |
| Forearm_L | 3.07 × 4.88 × 3.18 | Elbow_L | UpperArm_L | 0.25,-4.94,-0.03 | 172,1,174 | SmoothPlastic | 226,240,250 |
| Forearm_R | 3.07 × 4.88 × 3.18 | Elbow_R | UpperArm_R | -0.25,-4.94,-0.03 | 172,-1,-174 | SmoothPlastic | 226,240,250 |
| Hand_L | 4.59 × 4.66 × 4.94 | Wrist_L | Forearm_L | 0.09,-2.16,0.18 | 172,1,174 | SmoothPlastic | 226,240,250 |
| Hand_R | 4.59 × 4.66 × 4.94 | Wrist_R | Forearm_R | -0.09,-2.16,0.18 | 172,-1,-174 | SmoothPlastic | 226,240,250 |
| Head | 4.54 × 4.45 × 4.99 | Neck | Body | -0.00,2.17,-0.07 | -180,0,-180 | SmoothPlastic | 226,240,250 |
| Hips | 9.36 × 2.41 × 6.73 | RootJoint | HumanoidRootPart | 0.00,9.86,0.00 | -0,0,-0 | SmoothPlastic | 48,75,102 |
| IceClub | 4.95 × 12.83 × 4.50 | Club | Hand_R | -0.13,-1.17,-0.15 | 172,-1,-174 | Ice | 200,240,255 |
| LeftHorn | 2.40 × 6.03 × 2.00 | Horn_L | Head | 2.00,2.00,-0.27 | -180,0,-155 | SmoothPlastic | 200,240,255 |
| Loin1 | 3.79 × 2.02 × 0.50 | Loin1 | Hips | -0.00,-0.62,2.23 | -176,0,-180 | Fabric | 114,144,181 |
| Loin2 | 3.34 × 2.03 × 0.60 | Loin2 | Loin1 | -0.00,-1.00,-0.07 | -173,0,-180 | Fabric | 114,144,181 |
| Mantle1 | 7.57 × 2.72 × 0.90 | Mantle1 | Body | -0.00,1.42,-2.92 | 174,0,-180 | Fabric | 114,144,181 |
| Mantle2 | 8.13 × 2.74 × 1.08 | Mantle2 | Mantle1 | -0.00,-1.33,0.14 | 170,0,-180 | Fabric | 114,144,181 |
| Mantle3 | 8.69 × 2.74 × 1.25 | Mantle3 | Mantle2 | -0.00,-1.32,0.23 | 166,0,-180 | Fabric | 114,144,181 |
| Mouth | 1.87 × 0.45 × 0.45 | Jaw | Head | -0.00,-0.98,1.96 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| RightHorn | 2.40 × 6.03 × 2.00 | Horn_R | Head | -2.00,2.00,-0.27 | -0,0,25 | SmoothPlastic | 200,240,255 |
| Shin_L | 2.69 × 5.08 × 2.96 | Knee_L | Thigh_L | -0.00,-2.23,0.00 | -180,0,-180 | SmoothPlastic | 67,105,142 |
| Shin_R | 2.69 × 5.08 × 2.96 | Knee_R | Thigh_R | -0.00,-2.23,0.00 | -180,0,-180 | SmoothPlastic | 67,105,142 |
| Thigh_L | 2.93 × 4.45 × 2.93 | Hip_L | Hips | 1.87,-1.02,0.00 | -180,0,-180 | SmoothPlastic | 96,150,204 |
| Thigh_R | 2.93 × 4.45 × 2.93 | Hip_R | Hips | -1.87,-1.02,0.00 | -180,0,-180 | SmoothPlastic | 96,150,204 |
| UpperArm_L | 4.39 × 10.11 × 3.45 | Shoulder_L | Body | 5.44,1.01,-0.07 | -180,0,174 | SmoothPlastic | 96,150,204 |
| UpperArm_R | 4.39 × 10.11 × 3.45 | Shoulder_R | Body | -5.44,1.01,-0.07 | -180,0,-174 | SmoothPlastic | 96,150,204 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Beard3_Deco1 | 0.88 × 1.98 × 1.44 | Beard3 | 0.05,-1.10,-0.52 | Ice | 170,232,255 | 예 |
| Body_Deco1 | 6.01 × 5.64 × 8.79 | Body | 0.00,-0.46,-1.04 | Ice | 170,232,255 |  |
| Body_Deco2 | 6.91 × 3.57 × 1.92 | Body | 0.00,-0.72,-3.37 | Ice | 170,232,255 | 예 |
| Body_Deco3 | 4.23 × 0.27 × 0.18 | Body | 0.00,-1.17,3.40 | **Neon** | 170,232,255 | 예 |
| Body_Deco4 | 9.58 × 2.14 × 6.33 | Body | -0.00,1.95,-0.30 | Fabric | 236,245,252 |  |
| Foot_L_Deco1 | 3.74 × 1.69 × 4.90 | Foot_L | 0.00,0.18,0.09 | SmoothPlastic | 48,75,102 |  |
| Foot_R_Deco1 | 3.74 × 1.69 × 4.90 | Foot_R | 0.00,0.18,0.09 | SmoothPlastic | 48,75,102 |  |
| Forearm_L_Deco1 | 3.49 × 2.38 × 3.49 | Forearm_L | -0.20,0.56,-0.20 | Fabric | 236,245,252 |  |
| Forearm_R_Deco1 | 3.49 × 2.38 × 3.49 | Forearm_R | 0.20,0.56,-0.20 | Fabric | 236,245,252 |  |
| Hand_L_Deco1 | 2.86 × 1.39 × 1.11 | Hand_L | 0.04,-0.35,1.54 | Ice | 170,232,255 | 예 |
| Hand_R_Deco1 | 2.86 × 1.39 × 1.11 | Hand_R | -0.04,-0.35,1.54 | Ice | 170,232,255 | 예 |
| Head_Deco1 | 4.13 × 2.94 × 1.90 | Head | 0.00,3.12,-0.40 | Ice | 170,232,255 |  |
| Head_Deco2 | 4.81 × 1.21 × 1.57 | Head | -0.00,1.16,1.78 | Fabric | 236,245,252 |  |
| Hips_Deco1 | 2.65 × 2.65 × 0.89 | Hips | -0.00,0.53,2.49 | Ice | 170,232,255 |  |
| Hips_Deco2 | 7.04 × 1.43 × 4.81 | Hips | 0.00,0.53,0.00 | Fabric | 236,245,252 |  |
| Shin_L_Deco1 | 3.21 × 2.58 × 3.21 | Shin_L | -0.00,-1.02,-0.13 | Fabric | 236,245,252 |  |
| Shin_R_Deco1 | 3.21 × 2.58 × 3.21 | Shin_R | 0.00,-1.02,-0.13 | Fabric | 236,245,252 |  |
| Thigh_L_Deco1 | 2.32 × 2.01 × 1.29 | Thigh_L | 0.00,-2.14,1.60 | Ice | 170,232,255 |  |
| Thigh_R_Deco1 | 2.32 × 2.01 × 1.29 | Thigh_R | 0.00,-2.14,1.60 | Ice | 170,232,255 |  |
| UpperArm_L_Deco1 | 4.52 × 4.53 × 4.37 | UpperArm_L | 0.15,0.42,-0.03 | Ice | 170,232,255 |  |
| UpperArm_L_Deco2 | 3.33 × 1.66 × 3.21 | UpperArm_L | -0.05,-2.08,-0.03 | Fabric | 236,245,252 | 예 |
| UpperArm_R_Deco1 | 4.52 × 4.53 × 4.37 | UpperArm_R | -0.15,0.42,-0.03 | Ice | 170,232,255 |  |
| UpperArm_R_Deco2 | 3.33 × 1.66 × 3.21 | UpperArm_R | 0.05,-2.08,-0.03 | Fabric | 236,245,252 | 예 |

- 외곽선 껍데기: Body(14.10 × 13.06 × 6.45) · Hand_L(5.04 × 5.09 × 5.37) · Hand_R(5.04 × 5.09 × 5.37) · Head(4.94 × 4.89 × 5.40) · Hips(9.89 × 2.86 × 7.26) · IceClub(5.40 × 13.30 × 4.99) · Thigh_L(3.42 × 4.81 × 3.42) · Thigh_R(3.42 × 4.81 × 3.42) · UpperArm_L(4.91 × 10.58 × 3.93) · UpperArm_R(4.91 × 10.58 × 3.93)
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 8.46 × 8.46 × 5.12 · Head_Query 4.45 × 4.45 × 4.45
- **빛(Neon) 파트**: Body_Deco3 4.23 × 0.27 × 0.18 (170,232,255) · Eyes 2.91 × 0.97 × 0.45 (235,249,255)

## 심해 군주 `abyssal_lord` (tier3 수몰 사원)

- 배율: sizeScale 3 × bodyScale 1.2 = 리그 배율 **3.6**(HumanoidRootPart 7.20 × 7.20 × 3.60의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **18.24 stud** · 보이는 파트 69개 · Neon 7개 · 전체 BasePart 72개
- 구성: 관절 부위(Motor6D) 37 · 장식(용접) 22 · 외곽선 껍데기(`_Outline` · 잉크색) 10 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| BackFin | 0.50 × 6.34 × 4.72 | Crest | Body | -0.00,0.66,-0.97 | -0,0,-0 | SmoothPlastic | 60,200,255 |
| Body | 12.74 × 7.32 × 9.14 | Waist | Hips | -0.00,3.06,-1.35 | -180,0,-180 | SmoothPlastic | 24,66,112 |
| Eyes | 2.57 × 0.73 × 0.36 | Eyes | Head | -0.00,0.39,1.76 | -180,0,-180 | **Neon** | 186,235,255 |
| Foot_L | 2.88 × 0.90 × 4.14 | Ankle_L | Shin_L | -0.00,-1.48,-0.11 | -180,0,-180 | SmoothPlastic | 16,46,78 |
| Foot_R | 2.88 × 0.90 × 4.14 | Ankle_R | Shin_R | -0.00,-1.48,-0.11 | -180,0,-180 | SmoothPlastic | 16,46,78 |
| Forearm_L | 2.52 × 3.61 × 2.59 | Elbow_L | UpperArm_L | 0.22,-1.71,0.00 | 172,1,174 | SmoothPlastic | 36,140,146 |
| Forearm_R | 2.52 × 3.61 × 2.59 | Elbow_R | UpperArm_R | -0.22,-1.71,0.00 | 172,-1,-174 | SmoothPlastic | 36,140,146 |
| Hand_L | 2.98 × 2.99 × 3.31 | Wrist_L | Forearm_L | 0.05,-1.57,0.12 | 172,1,174 | SmoothPlastic | 36,140,146 |
| Hand_R | 2.98 × 2.99 × 3.31 | Wrist_R | Forearm_R | -0.05,-1.57,0.12 | 172,-1,-174 | SmoothPlastic | 36,140,146 |
| Head | 4.04 × 3.24 × 4.39 | Neck | Body | -0.00,2.10,1.55 | -180,0,-180 | SmoothPlastic | 36,140,146 |
| Hips | 11.98 × 6.12 × 6.87 | RootJoint | HumanoidRootPart | 0.00,5.48,0.00 | -0,0,-0 | SmoothPlastic | 16,46,78 |
| LeftFin | 2.36 × 3.16 × 3.24 | Fin_L | Head | 2.16,0.36,-0.58 | -180,0,-145 | SmoothPlastic | 60,200,255 |
| Mouth | 1.66 × 0.32 × 0.36 | Jaw | Head | -0.00,-0.71,1.76 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| RightFin | 2.36 × 3.16 × 3.24 | Fin_R | Head | -2.16,0.36,-0.58 | -180,0,145 | SmoothPlastic | 60,200,255 |
| Shin_L | 2.33 × 2.95 × 2.56 | Knee_L | Thigh_L | -0.00,-1.30,0.00 | -180,0,-180 | SmoothPlastic | 16,46,78 |
| Shin_R | 2.33 × 2.95 × 2.56 | Knee_R | Thigh_R | -0.00,-1.30,0.00 | -180,0,-180 | SmoothPlastic | 16,46,78 |
| Tail1 | 3.43 × 3.47 × 3.26 | Tail1 | Hips | -0.00,1.62,-3.15 | -105,0,-180 | SmoothPlastic | 36,140,146 |
| Tail2 | 3.04 × 3.16 × 2.92 | Tail2 | Tail1 | -0.00,-0.61,-1.33 | -96,0,-180 | SmoothPlastic | 36,140,146 |
| Tail3 | 2.65 × 2.87 × 2.80 | Tail3 | Tail2 | -0.00,-0.46,-1.35 | -87,0,-180 | SmoothPlastic | 36,140,146 |
| Tail4 | 2.25 × 2.72 × 2.98 | Tail4 | Tail3 | -0.00,-0.25,-1.35 | -78,0,-180 | SmoothPlastic | 36,140,146 |
| Tail5 | 1.86 × 2.52 × 3.01 | Tail5 | Tail4 | -0.00,0.07,-1.33 | -69,0,-180 | SmoothPlastic | 36,140,146 |
| Tail6 | 4.92 × 3.75 × 5.70 | Tail6 | Tail5 | -0.00,0.39,-1.28 | -60,0,-180 | SmoothPlastic | 60,200,255 |
| TentL1 | 0.80 × 1.36 × 0.89 | TentL1 | Head | 0.94,-1.58,1.08 | 172,-0,-176 | SmoothPlastic | 36,140,146 |
| TentL2 | 0.63 × 1.40 × 1.00 | TentL2 | TentL1 | -0.04,-0.60,0.08 | 166,-0,-176 | SmoothPlastic | 36,140,146 |
| TentL3 | 0.45 × 1.42 × 1.10 | TentL3 | TentL2 | -0.04,-0.59,0.15 | 160,-1,-176 | **Neon** | 60,200,255 |
| TentM1 | 0.79 × 1.48 × 1.02 | TentM1 | Head | -0.00,-1.66,1.30 | 170,0,-180 | SmoothPlastic | 36,140,146 |
| TentM2 | 0.58 × 1.53 × 1.14 | TentM2 | TentM1 | -0.00,-0.67,0.12 | 164,0,-180 | SmoothPlastic | 36,140,146 |
| TentM3 | 0.36 × 1.57 × 1.25 | TentM3 | TentM2 | -0.00,-0.66,0.19 | 158,0,-180 | **Neon** | 60,200,255 |
| TentR1 | 0.80 × 1.36 × 0.89 | TentR1 | Head | -0.94,-1.58,1.08 | 172,0,176 | SmoothPlastic | 36,140,146 |
| TentR2 | 0.63 × 1.40 × 1.00 | TentR2 | TentR1 | 0.04,-0.60,0.08 | 166,0,176 | SmoothPlastic | 36,140,146 |
| TentR3 | 0.45 × 1.42 × 1.10 | TentR3 | TentR2 | 0.04,-0.59,0.15 | 160,1,176 | **Neon** | 60,200,255 |
| Thigh_L | 2.52 × 2.59 × 2.52 | Hip_L | Hips | 1.66,1.26,-1.35 | -180,0,-180 | SmoothPlastic | 24,66,112 |
| Thigh_R | 2.52 × 2.59 × 2.52 | Hip_R | Hips | -1.66,1.26,-1.35 | -180,0,-180 | SmoothPlastic | 24,66,112 |
| Trident | 3.00 × 15.14 × 3.53 | Trident | Hand_R | -0.10,-0.96,-0.13 | 172,-1,-174 | SmoothPlastic | 60,200,255 |
| TridentHead | 5.81 × 6.20 × 1.33 | TridentHead | Trident | 0.78,7.45,-1.05 | 172,-1,-174 | **Neon** | 60,200,255 |
| UpperArm_L | 2.50 × 3.62 × 2.37 | Shoulder_L | Body | 5.11,1.10,1.55 | -180,0,174 | SmoothPlastic | 24,66,112 |
| UpperArm_R | 2.50 × 3.62 × 2.37 | Shoulder_R | Body | -5.11,1.10,1.55 | -180,0,-174 | SmoothPlastic | 24,66,112 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Body_Deco1 | 1.08 × 1.08 × 1.08 | Body | 0.00,1.38,4.43 | **Neon** | 70,226,214 |  |
| Body_Deco2 | 5.94 × 3.60 × 0.50 | Body | 0.00,-0.42,4.18 | SmoothPlastic | 36,140,146 |  |
| Body_Deco3 | 5.04 × 3.13 × 0.86 | Body | 0.00,0.61,4.14 | SmoothPlastic | 113,180,184 |  |
| Forearm_L_Deco1 | 0.59 × 2.24 × 2.16 | Forearm_L | 1.12,-0.02,-0.46 | Glass | 70,226,214 |  |
| Forearm_R_Deco1 | 0.59 × 2.24 × 2.16 | Forearm_R | -1.12,-0.02,-0.46 | Glass | 70,226,214 |  |
| Head_Deco1 | 3.07 × 2.59 × 0.65 | Head | 0.00,2.38,-0.29 | Glass | 70,226,214 |  |
| Head_Deco2 | 4.12 × 1.04 × 0.36 | Head | 0.00,2.66,-0.29 | Glass | 70,226,214 | 예 |
| Head_Deco3 | 4.18 × 0.87 × 1.24 | Head | 0.00,0.79,1.58 | SmoothPlastic | 12,33,56 |  |
| Hips_Deco1 | 1.87 × 1.51 × 0.65 | Hips | 0.00,2.52,0.81 | SmoothPlastic | 113,180,184 |  |
| Hips_Deco2 | 5.76 × 0.79 × 4.32 | Hips | 0.00,2.70,-1.35 | SmoothPlastic | 12,33,56 |  |
| Shin_L_Deco1 | 2.45 × 1.80 × 0.72 | Shin_L | 0.00,-0.00,1.07 | SmoothPlastic | 36,140,146 |  |
| Shin_R_Deco1 | 2.45 × 1.80 × 0.72 | Shin_R | -0.00,-0.00,1.07 | SmoothPlastic | 36,140,146 |  |
| Tail2_Deco1 | 0.36 × 1.98 × 1.79 | Tail2 | 0.00,1.18,-0.26 | Glass | 70,226,214 |  |
| Tail3_Deco1 | 0.36 × 1.62 × 1.70 | Tail3 | 0.00,1.08,0.07 | Glass | 70,226,214 |  |
| Tail4_Deco1 | 0.36 × 1.41 × 1.71 | Tail4 | -0.00,1.06,0.23 | Glass | 70,226,214 | 예 |
| Tail5_Deco1 | 0.36 × 1.18 × 1.63 | Tail5 | -0.00,1.07,0.34 | Glass | 70,226,214 | 예 |
| Trident_Deco1 | 3.11 × 2.51 × 0.67 | Trident | 0.95,7.98,-1.13 | **Neon** | 70,226,214 |  |
| Trident_Deco2 | 1.87 × 0.93 × 1.85 | Trident | 0.67,6.38,-0.90 | SmoothPlastic | 113,180,184 |  |
| UpperArm_L_Deco1 | 0.71 × 1.85 × 3.31 | UpperArm_L | 0.53,2.22,0.00 | SmoothPlastic | 70,226,214 | 예 |
| UpperArm_L_Deco2 | 3.89 × 2.21 × 3.67 | UpperArm_L | 0.17,1.53,0.00 | SmoothPlastic | 113,180,184 |  |
| UpperArm_R_Deco1 | 0.71 × 1.85 × 3.31 | UpperArm_R | -0.53,2.22,0.00 | SmoothPlastic | 70,226,214 | 예 |
| UpperArm_R_Deco2 | 3.89 × 2.21 × 3.67 | UpperArm_R | -0.17,1.53,0.00 | SmoothPlastic | 113,180,184 |  |

- 외곽선 껍데기: BackFin(0.75 × 6.63 × 5.06) · Body(13.14 × 7.70 × 9.55) · Forearm_L(2.89 × 3.94 × 2.93) · Forearm_R(2.89 × 3.94 × 2.93) · Hand_L(3.34 × 3.33 × 3.67) · Hand_R(3.34 × 3.33 × 3.67) · Head(4.35 × 3.60 × 4.72) · Hips(12.23 × 6.40 × 7.23) · UpperArm_L(2.87 × 3.94 × 2.76) · UpperArm_R(2.87 × 3.94 × 2.76)
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 8.28 × 5.76 × 5.04 · Head_Query 3.96 × 3.24 × 3.96
- **빛(Neon) 파트**: Body_Deco1 1.08 × 1.08 × 1.08 (70,226,214) · Eyes 2.57 × 0.73 × 0.36 (186,235,255) · TentL3 0.45 × 1.42 × 1.10 (60,200,255) · TentM3 0.36 × 1.57 × 1.25 (60,200,255) · TentR3 0.45 × 1.42 × 1.10 (60,200,255) · TridentHead 5.81 × 6.20 × 1.33 (60,200,255) · Trident_Deco1 3.11 × 2.51 × 0.67 (70,226,214)

## 수정 여왕 `crystal_queen` (tier2 수정 동굴)

- 배율: sizeScale 3 × bodyScale 1.2 = 리그 배율 **3.6**(HumanoidRootPart 7.20 × 7.20 × 3.60의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **19.56 stud** · 보이는 파트 62개 · Neon 7개 · 전체 BasePart 65개
- 구성: 관절 부위(Motor6D) 35 · 장식(용접) 17 · 외곽선 껍데기(`_Outline` · 잉크색) 10 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| Body | 6.27 × 7.18 × 4.11 | Waist | Hips | 0.00,1.53,0.14 | -180,0,-180 | SmoothPlastic | 222,120,172 |
| Crown | 3.31 × 2.86 × 2.96 | Crown | Head | 0.00,1.80,-0.12 | -180,0,-90 | **Neon** | 150,240,255 |
| Eyes | 2.12 × 0.73 × 0.36 | Eyes | Head | 0.00,0.41,1.50 | -180,0,-180 | **Neon** | 218,249,255 |
| Foot_L | 1.98 × 0.90 × 3.24 | Ankle_L | Shin_L | 0.00,-1.85,-0.09 | -180,0,-180 | SmoothPlastic | 155,83,120 |
| Foot_R | 1.98 × 0.90 × 3.24 | Ankle_R | Shin_R | 0.00,-1.85,-0.09 | -180,0,-180 | SmoothPlastic | 155,83,120 |
| Forearm_L | 1.86 × 3.46 × 1.95 | Elbow_L | UpperArm_L | 0.23,-1.71,0.00 | 172,1,174 | SmoothPlastic | 246,204,224 |
| Forearm_R | 1.86 × 3.46 × 1.95 | Elbow_R | UpperArm_R | -0.23,-1.71,0.00 | 172,-1,-174 | SmoothPlastic | 246,204,224 |
| Hand_L | 1.79 × 2.19 × 2.20 | Wrist_L | Forearm_L | 0.08,-1.58,0.15 | 172,1,174 | SmoothPlastic | 246,204,224 |
| Hand_R | 1.79 × 2.19 × 2.20 | Wrist_R | Forearm_R | -0.08,-1.58,0.15 | 172,-1,-174 | SmoothPlastic | 246,204,224 |
| Head | 3.37 × 3.56 × 3.52 | Neck | Body | 0.00,2.53,-0.54 | -180,0,-180 | SmoothPlastic | 246,204,224 |
| Hips | 5.83 × 3.06 × 4.37 | RootJoint | HumanoidRootPart | 0.00,6.78,0.00 | -0,0,-0 | SmoothPlastic | 155,83,120 |
| LeftShard | 4.07 × 6.26 × 2.37 | Wing_L | Body | 1.44,1.27,-2.16 | -165,-0,-150 | Glass | 150,240,255 |
| LeftShard2 | 4.22 × 3.62 × 1.52 | Wing2_L | LeftShard | 0.35,0.38,-0.06 | -158,4,-128 | Glass | 150,240,255 |
| Mouth | 1.36 × 0.34 × 0.36 | Jaw | Head | 0.00,-0.75,1.50 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| RightShard | 4.07 × 6.26 × 2.37 | Wing_R | Body | -1.44,1.27,-2.16 | 15,-0,30 | Glass | 150,240,255 |
| RightShard2 | 4.22 × 3.57 × 1.30 | Wing2_R | RightShard | -0.35,0.23,0.50 | 8,-4,52 | Glass | 150,240,255 |
| Scepter | 2.40 × 8.60 × 2.69 | Scepter | Hand_R | -0.08,-0.88,-0.12 | 172,-1,-174 | SmoothPlastic | 246,204,224 |
| ScepterGem | 1.81 × 2.48 × 1.61 | ScepterGem | Scepter | 0.25,4.48,-0.42 | 172,-1,-174 | **Neon** | 150,240,255 |
| Shin_L | 1.75 × 3.69 × 1.92 | Knee_L | Thigh_L | 0.00,-1.62,0.00 | -180,0,-180 | SmoothPlastic | 155,83,120 |
| Shin_R | 1.75 × 3.69 × 1.92 | Knee_R | Thigh_R | 0.00,-1.62,0.00 | -180,0,-180 | SmoothPlastic | 155,83,120 |
| SkirtB1 | 4.72 × 2.97 × 2.10 | SkirtB1 | Hips | 0.00,0.27,-1.48 | -168,0,-180 | SmoothPlastic | 246,204,224 |
| SkirtB2 | 5.10 × 4.37 × 2.45 | SkirtB2 | SkirtB1 | 0.00,-1.32,-0.28 | -162,0,-180 | Glass | 150,240,255 |
| SkirtF1 | 4.72 × 2.97 × 2.10 | SkirtF1 | Hips | 0.00,0.27,1.76 | 168,0,-180 | SmoothPlastic | 246,204,224 |
| SkirtF2 | 5.10 × 4.37 × 2.45 | SkirtF2 | SkirtF1 | 0.00,-1.32,0.28 | 162,0,-180 | Glass | 150,240,255 |
| SkirtL1 | 3.74 × 3.32 × 1.20 | SkirtL1 | Hips | 2.16,0.27,0.14 | -180,0,168 | SmoothPlastic | 246,204,224 |
| SkirtL2 | 4.25 × 4.61 × 2.10 | SkirtL2 | SkirtL1 | 0.11,-1.28,0.00 | -180,0,162 | Glass | 150,240,255 |
| SkirtR1 | 3.74 × 3.32 × 1.20 | SkirtR1 | Hips | -2.16,0.27,0.14 | -180,0,-168 | SmoothPlastic | 246,204,224 |
| SkirtR2 | 4.25 × 4.61 × 1.32 | SkirtR2 | SkirtR1 | -0.11,-1.28,0.00 | -180,0,-162 | Glass | 150,240,255 |
| Thigh_L | 1.91 × 3.24 × 1.91 | Hip_L | Hips | 1.26,-0.27,0.14 | -180,0,-180 | SmoothPlastic | 222,120,172 |
| Thigh_R | 1.91 × 3.24 × 1.91 | Hip_R | Hips | -1.26,-0.27,0.14 | -180,0,-180 | SmoothPlastic | 222,120,172 |
| Train1 | 3.78 × 2.24 × 0.45 | Train1 | Body | 0.00,1.45,-2.26 | 174,0,-180 | SmoothPlastic | 246,204,224 |
| Train2 | 4.23 × 2.23 × 0.64 | Train2 | Train1 | 0.00,-1.11,0.12 | 169,0,-180 | SmoothPlastic | 246,204,224 |
| Train3 | 4.68 × 2.21 × 0.82 | Train3 | Train2 | 0.00,-1.10,0.21 | 164,0,-180 | Glass | 150,240,255 |
| UpperArm_L | 1.87 × 3.56 × 1.72 | Shoulder_L | Body | 3.42,1.80,-0.54 | -180,0,174 | SmoothPlastic | 222,120,172 |
| UpperArm_R | 1.87 × 3.56 × 1.72 | Shoulder_R | Body | -3.42,1.80,-0.54 | -180,0,-174 | SmoothPlastic | 222,120,172 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Body_Deco1 | 1.83 × 1.83 × 0.43 | Body | 0.00,0.73,1.26 | **Neon** | 84,226,214 |  |
| Body_Deco2 | 4.82 × 0.72 × 3.02 | Body | 0.00,2.64,-0.54 | SmoothPlastic | 249,222,235 |  |
| Crown_Deco1 | 2.22 × 2.97 × 1.48 | Crown | 1.77,-1.00,0.70 | Glass | 84,226,214 |  |
| Crown_Deco2 | 1.34 × 2.45 × 0.72 | Crown | 1.30,-1.00,-0.94 | Glass | 84,226,214 | 예 |
| Forearm_L_Deco1 | 1.94 × 0.95 × 1.92 | Forearm_L | 0.03,-1.05,0.08 | Glass | 84,226,214 |  |
| Forearm_R_Deco1 | 1.94 × 0.95 × 1.92 | Forearm_R | -0.03,-1.05,0.08 | Glass | 84,226,214 |  |
| Head_Deco1 | 5.04 × 3.78 × 3.78 | Head | 0.00,1.71,-0.21 | **Neon** | 84,226,214 |  |
| Head_Deco2 | 5.13 × 1.53 × 0.36 | Head | 0.00,3.17,-1.92 | **Neon** | 84,226,214 | 예 |
| Hips_Deco1 | 1.32 × 1.32 × 0.36 | Hips | 0.00,1.17,1.94 | **Neon** | 84,226,214 |  |
| Hips_Deco2 | 4.68 × 0.50 × 3.60 | Hips | 0.00,1.35,0.14 | SmoothPlastic | 249,222,235 |  |
| ScepterGem_Deco1 | 2.90 × 2.45 × 0.61 | ScepterGem | 0.17,0.95,-0.18 | Glass | 84,226,214 |  |
| UpperArm_L_Deco1 | 1.26 × 2.30 × 1.46 | UpperArm_L | 0.39,2.20,0.00 | Glass | 84,226,214 |  |
| UpperArm_L_Deco2 | 0.78 × 1.60 × 0.93 | UpperArm_L | 0.21,1.89,-0.58 | Glass | 84,226,214 | 예 |
| UpperArm_L_Deco3 | 2.25 × 0.73 × 2.02 | UpperArm_L | -0.11,1.50,-0.00 | SmoothPlastic | 249,222,235 |  |
| UpperArm_R_Deco1 | 1.26 × 2.30 × 1.46 | UpperArm_R | -0.39,2.20,-0.00 | Glass | 84,226,214 |  |
| UpperArm_R_Deco2 | 0.78 × 1.60 × 0.93 | UpperArm_R | -0.21,1.89,-0.58 | Glass | 84,226,214 | 예 |
| UpperArm_R_Deco3 | 2.25 × 0.73 × 2.02 | UpperArm_R | 0.11,1.50,-0.00 | SmoothPlastic | 249,222,235 |  |

- 외곽선 껍데기: Body(6.59 × 7.53 × 4.48) · Crown(3.70 × 3.29 × 3.35) · Head(3.80 × 3.99 × 3.95) · Hips(6.19 × 3.31 × 4.72) · LeftShard(4.40 × 6.63 × 2.78) · RightShard(4.40 × 6.63 × 2.78) · SkirtB1(5.03 × 3.32 × 2.47) · SkirtF1(5.03 × 3.32 × 2.47) · SkirtL1(4.07 × 3.63 × 1.52) · SkirtR1(4.07 × 3.63 × 1.52)
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 5.40 × 6.12 × 3.24 · Head_Query 3.24 × 3.42 × 3.24
- **빛(Neon) 파트**: Body_Deco1 1.83 × 1.83 × 0.43 (84,226,214) · Crown 3.31 × 2.86 × 2.96 (150,240,255) · Eyes 2.12 × 0.73 × 0.36 (218,249,255) · Head_Deco1 5.04 × 3.78 × 3.78 (84,226,214) · Head_Deco2 5.13 × 1.53 × 0.36 (84,226,214) · Hips_Deco1 1.32 × 1.32 × 0.36 (84,226,214) · ScepterGem 1.81 × 2.48 × 1.61 (150,240,255)

## 전갈 여왕 `scorpion_queen` (tier4 모래 유적)

- 배율: sizeScale 2.8 × bodyScale 1.25 = 리그 배율 **3.5**(HumanoidRootPart 7.00 × 7.00 × 3.50의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **15.89 stud** · 보이는 파트 74개 · Neon 6개 · 전체 BasePart 77개
- 구성: 관절 부위(Motor6D) 51 · 장식(용접) 23 · 외곽선 껍데기(`_Outline` · 잉크색) 0 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| Body | 11.76 × 4.41 × 9.49 | RootJoint | HumanoidRootPart | 0.00,3.40,0.00 | -0,0,-0 | SmoothPlastic | 168,95,38 |
| Eyes | 2.92 × 0.81 × 0.35 | Eyes | Head | 0.00,-0.13,1.57 | -180,0,-180 | **Neon** | 255,232,186 |
| Forearm_L | 2.40 × 3.41 × 3.47 | Elbow_L | UpperArm_L | 0.00,0.19,1.75 | 42,-19,163 | SmoothPlastic | 168,95,38 |
| Forearm_R | 2.40 × 3.41 × 3.47 | Elbow_R | UpperArm_R | 0.00,0.19,1.75 | 42,19,-163 | SmoothPlastic | 168,95,38 |
| Hand_L | 4.30 × 3.57 × 7.07 | Wrist_L | Forearm_L | 0.54,1.19,1.29 | 91,-25,-178 | SmoothPlastic | 206,150,104 |
| Hand_R | 4.30 × 3.57 × 7.04 | Wrist_R | Forearm_R | -0.54,1.19,1.29 | 91,25,178 | SmoothPlastic | 206,150,104 |
| Head | 4.55 × 3.76 × 3.15 | Neck | Body | 0.00,0.17,3.78 | -180,0,-180 | SmoothPlastic | 206,150,104 |
| Mouth | 2.10 × 0.42 × 0.35 | Jaw | Head | 0.00,-1.29,1.57 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| Pincer_L | 1.68 × 1.45 × 4.67 | Pincer_L | Hand_L | -0.84,0.38,0.26 | 91,-25,172 | SmoothPlastic | 255,190,60 |
| Pincer_R | 1.70 × 1.44 × 4.32 | Pincer_R | Hand_R | 0.84,0.38,0.27 | 91,25,-172 | SmoothPlastic | 255,190,60 |
| Shin1_L | 3.96 × 6.23 × 1.20 | Knee1_L | Thigh1_L | 1.48,1.07,0.00 | -180,0,150 | SmoothPlastic | 117,66,26 |
| Shin1_R | 3.96 × 6.23 × 1.20 | Knee1_R | Thigh1_R | -1.48,1.07,0.00 | -180,0,-150 | SmoothPlastic | 117,66,26 |
| Shin2_L | 3.96 × 6.23 × 1.20 | Knee2_L | Thigh2_L | 1.48,1.07,0.00 | -180,0,150 | SmoothPlastic | 117,66,26 |
| Shin2_R | 3.96 × 6.23 × 1.20 | Knee2_R | Thigh2_R | -1.48,1.07,0.00 | -180,0,-150 | SmoothPlastic | 117,66,26 |
| Shin3_L | 3.96 × 6.23 × 1.20 | Knee3_L | Thigh3_L | 1.48,1.07,-0.00 | -180,0,150 | SmoothPlastic | 117,66,26 |
| Shin3_R | 3.96 × 6.23 × 1.20 | Knee3_R | Thigh3_R | -1.48,1.07,-0.00 | -180,0,-150 | SmoothPlastic | 117,66,26 |
| Tail1_1 | 1.61 × 2.29 × 2.39 | Tail1_1 | Body | 1.58,1.05,-3.57 | -53,30,-180 | SmoothPlastic | 168,95,38 |
| Tail1_2 | 1.62 × 2.36 × 2.14 | Tail1_2 | Tail1_1 | 0.00,0.62,-0.80 | -30,28,169 | SmoothPlastic | 168,95,38 |
| Tail1_3 | 1.74 × 2.25 × 1.81 | Tail1_3 | Tail1_2 | 0.21,0.80,-0.59 | -9,23,160 | SmoothPlastic | 168,95,38 |
| Tail1_4 | 1.85 × 2.21 × 1.65 | Tail1_4 | Tail1_3 | 0.35,0.89,-0.37 | 10,14,153 | SmoothPlastic | 168,95,38 |
| Tail1_5 | 1.88 × 2.17 × 1.74 | Tail1_5 | Tail1_4 | 0.45,0.88,-0.12 | 28,5,150 | SmoothPlastic | 168,95,38 |
| Tail1_6 | 1.79 × 1.88 × 1.94 | Tail1_6 | Tail1_5 | 0.51,0.78,0.36 | 46,-5,150 | SmoothPlastic | 168,95,38 |
| Tail1_7 | 1.59 × 1.42 × 2.09 | Tail1_7 | Tail1_6 | 0.51,0.58,0.65 | 64,-14,153 | SmoothPlastic | 168,95,38 |
| Tail1_8 | 1.67 × 1.54 × 2.65 | Tail1_8 | Tail1_7 | 0.45,0.35,0.84 | 83,-23,160 | **Neon** | 255,190,60 |
| Tail2_1 | 2.50 × 2.91 × 2.86 | Tail2_1 | Body | 0.00,1.05,-3.57 | -53,0,-180 | SmoothPlastic | 168,95,38 |
| Tail2_2 | 2.34 × 2.73 × 2.77 | Tail2_2 | Tail2_1 | 0.00,0.65,-0.82 | -33,0,-180 | SmoothPlastic | 168,95,38 |
| Tail2_3 | 2.17 × 2.30 × 2.48 | Tail2_3 | Tail2_2 | 0.00,0.85,-0.59 | -13,0,-180 | SmoothPlastic | 168,95,38 |
| Tail2_4 | 2.00 × 2.12 × 2.41 | Tail2_4 | Tail2_3 | 0.00,0.95,-0.38 | 7,0,-180 | SmoothPlastic | 168,95,38 |
| Tail2_5 | 1.84 × 2.45 × 2.35 | Tail2_5 | Tail2_4 | 0.00,0.96,-0.03 | 27,0,180 | SmoothPlastic | 168,95,38 |
| Tail2_6 | 1.67 × 2.38 × 2.41 | Tail2_6 | Tail2_5 | 0.00,0.89,0.47 | 47,0,180 | SmoothPlastic | 168,95,38 |
| Tail2_7 | 1.50 × 1.98 × 2.29 | Tail2_7 | Tail2_6 | 0.00,0.70,0.74 | 67,0,-180 | SmoothPlastic | 168,95,38 |
| Tail2_8 | 0.96 × 1.83 × 2.87 | Tail2_8 | Tail2_7 | 0.00,0.43,0.91 | 87,0,180 | **Neon** | 255,190,60 |
| Tail3_1 | 1.61 × 2.29 × 2.39 | Tail3_1 | Body | -1.57,1.05,-3.57 | -53,-30,180 | SmoothPlastic | 168,95,38 |
| Tail3_2 | 1.62 × 2.36 × 2.14 | Tail3_2 | Tail3_1 | 0.00,0.62,-0.80 | -30,-28,-169 | SmoothPlastic | 168,95,38 |
| Tail3_3 | 1.74 × 2.25 × 1.81 | Tail3_3 | Tail3_2 | -0.21,0.80,-0.59 | -9,-23,-160 | SmoothPlastic | 168,95,38 |
| Tail3_4 | 1.85 × 2.21 × 1.65 | Tail3_4 | Tail3_3 | -0.35,0.89,-0.37 | 10,-14,-153 | SmoothPlastic | 168,95,38 |
| Tail3_5 | 1.88 × 2.17 × 1.74 | Tail3_5 | Tail3_4 | -0.45,0.88,-0.12 | 28,-5,-150 | SmoothPlastic | 168,95,38 |
| Tail3_6 | 1.79 × 1.88 × 1.94 | Tail3_6 | Tail3_5 | -0.51,0.78,0.36 | 46,5,-150 | SmoothPlastic | 168,95,38 |
| Tail3_7 | 1.59 × 1.42 × 2.09 | Tail3_7 | Tail3_6 | -0.51,0.58,0.65 | 64,14,-153 | SmoothPlastic | 168,95,38 |
| Tail3_8 | 1.67 × 1.54 × 2.67 | Tail3_8 | Tail3_7 | -0.45,0.35,0.84 | 83,23,-160 | **Neon** | 255,190,60 |
| Thigh1_L | 3.68 × 3.16 × 1.66 | Hip1_L | Body | 4.20,-0.53,2.03 | -180,0,55 | SmoothPlastic | 206,150,104 |
| Thigh1_R | 3.68 × 3.16 × 1.66 | Hip1_R | Body | -4.20,-0.53,2.03 | -180,0,-55 | SmoothPlastic | 206,150,104 |
| Thigh2_L | 3.68 × 3.16 × 1.66 | Hip2_L | Body | 4.20,-0.53,-0.60 | -180,0,55 | SmoothPlastic | 206,150,104 |
| Thigh2_R | 3.68 × 3.16 × 1.66 | Hip2_R | Body | -4.20,-0.53,-0.60 | -180,0,-55 | SmoothPlastic | 206,150,104 |
| Thigh3_L | 3.68 × 3.16 × 1.66 | Hip3_L | Body | 4.20,-0.53,-3.05 | -180,0,55 | SmoothPlastic | 206,150,104 |
| Thigh3_R | 3.68 × 3.16 × 1.66 | Hip3_R | Body | -4.20,-0.53,-3.05 | -180,0,-55 | SmoothPlastic | 206,150,104 |
| UpperArm_L | 1.68 × 1.80 × 3.61 | Shoulder_L | Body | 3.33,0.17,3.60 | 85,-25,180 | SmoothPlastic | 206,150,104 |
| UpperArm_R | 1.68 × 1.80 × 3.61 | Shoulder_R | Body | -3.32,0.17,3.60 | 85,25,-180 | SmoothPlastic | 206,150,104 |
| Veil1 | 3.50 × 0.64 × 1.38 | Veil1 | Body | 0.00,1.92,-0.77 | 110,0,-180 | Fabric | 255,190,60 |
| Veil2 | 3.15 × 0.46 × 1.41 | Veil2 | Veil1 | 0.00,-0.24,0.66 | 102,0,-180 | Fabric | 255,190,60 |
| Veil3 | 2.80 × 0.27 × 1.41 | Veil3 | Veil2 | 0.00,-0.15,0.68 | 94,0,-180 | Fabric | 255,190,60 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Body_Deco1 | 4.20 × 0.31 × 0.31 | Body | 0.00,0.70,3.88 | Metal | 255,196,60 |  |
| Body_Deco2 | 7.49 × 0.39 × 4.93 | Body | 0.00,2.24,1.05 | Metal | 255,196,60 | 예 |
| Body_Deco3 | 0.77 × 1.12 × 0.35 | Body | 0.00,0.14,3.96 | **Neon** | 255,196,60 |  |
| Body_Deco4 | 9.38 × 2.35 × 7.33 | Body | 0.00,1.31,-0.20 | SmoothPlastic | 206,150,104 |  |
| Forearm_L_Deco1 | 2.29 × 2.17 × 1.64 | Forearm_L | -0.12,-0.39,-0.46 | Metal | 255,196,60 |  |
| Forearm_R_Deco1 | 2.29 × 2.17 × 1.64 | Forearm_R | 0.12,-0.39,-0.46 | Metal | 255,196,60 |  |
| Hand_L_Deco1 | 0.64 × 0.60 × 2.05 | Hand_L | -0.41,1.00,-0.54 | SmoothPlastic | 223,187,157 | 예 |
| Hand_R_Deco1 | 0.64 × 0.60 × 2.05 | Hand_R | 0.41,1.00,-0.52 | SmoothPlastic | 223,187,157 | 예 |
| Head_Deco1 | 3.85 × 1.93 × 2.10 | Head | -0.00,1.43,-0.52 | Metal | 255,196,60 |  |
| Head_Deco2 | 3.64 × 0.42 × 0.18 | Head | 0.00,0.11,1.61 | **Neon** | 255,234,187 | 예 |
| Head_Deco3 | 3.49 × 0.63 × 1.75 | Head | 0.00,-1.53,2.17 | SmoothPlastic | 223,187,157 |  |
| Tail1_3_Deco1 | 2.30 × 1.33 × 2.07 | Tail1_3 | 0.34,0.13,0.60 | SmoothPlastic | 206,150,104 | 예 |
| Tail1_7_Deco1 | 1.56 × 1.70 × 1.22 | Tail1_7 | 0.03,0.06,0.02 | Metal | 255,196,60 |  |
| Tail2_3_Deco1 | 1.82 × 0.76 × 1.60 | Tail2_3 | 0.00,0.19,0.58 | SmoothPlastic | 206,150,104 | 예 |
| Tail2_7_Deco1 | 1.26 × 1.30 × 0.81 | Tail2_7 | -0.00,0.05,0.02 | Metal | 255,196,60 |  |
| Tail3_3_Deco1 | 2.30 × 1.33 × 2.07 | Tail3_3 | -0.34,0.13,0.60 | SmoothPlastic | 206,150,104 | 예 |
| Tail3_7_Deco1 | 1.56 × 1.70 × 1.22 | Tail3_7 | -0.03,0.06,0.02 | Metal | 255,196,60 |  |
| Thigh1_L_Deco1 | 1.32 × 1.13 × 0.49 | Thigh1_L | -0.53,-0.34,-0.52 | SmoothPlastic | 223,187,157 | 예 |
| Thigh1_R_Deco1 | 1.32 × 1.13 × 0.49 | Thigh1_R | 0.53,-0.34,-0.53 | SmoothPlastic | 223,187,157 | 예 |
| Thigh2_L_Deco1 | 1.32 × 1.13 × 0.49 | Thigh2_L | -0.53,-0.34,-0.52 | SmoothPlastic | 223,187,157 | 예 |
| Thigh2_R_Deco1 | 1.32 × 1.13 × 0.49 | Thigh2_R | 0.53,-0.34,-0.53 | SmoothPlastic | 223,187,157 | 예 |
| Thigh3_L_Deco1 | 1.32 × 1.13 × 0.49 | Thigh3_L | -0.53,-0.34,-0.52 | SmoothPlastic | 223,187,157 | 예 |
| Thigh3_R_Deco1 | 1.32 × 1.13 × 0.49 | Thigh3_R | 0.53,-0.34,-0.53 | SmoothPlastic | 223,187,157 | 예 |

- 외곽선 껍데기: 
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 8.40 × 3.15 × 7.70 · Head_Query 4.55 × 2.45 × 3.15
- **빛(Neon) 파트**: Body_Deco3 0.77 × 1.12 × 0.35 (255,196,60) · Eyes 2.92 × 0.81 × 0.35 (255,232,186) · Head_Deco2 3.64 × 0.42 × 0.18 (255,234,187) · Tail1_8 1.67 × 1.54 × 2.65 (255,190,60) · Tail2_8 0.96 × 1.83 × 2.87 (255,190,60) · Tail3_8 1.67 × 1.54 × 2.67 (255,190,60)

## 폭풍 군주 `storm_lord` (tier5 폭풍 첨탑)

- 배율: sizeScale 3 × bodyScale 1.25 = 리그 배율 **3.75**(HumanoidRootPart 7.50 × 7.50 × 3.75의 절반 · 아래 크기 · 자리는 전부 이 배율이 곱해진 stud)
- 실측 높이(보이는 파트 경계 · 아레나 실전 · 그 순간 자세): **25.05 stud** · 보이는 파트 61개 · Neon 9개 · 전체 BasePart 64개
- 구성: 관절 부위(Motor6D) 31 · 장식(용접) 20 · 외곽선 껍데기(`_Outline` · 잉크색) 10 · 판정 사본(`_Query` · 투명) 2 · 루트 1

### 관절 부위 (Motor6D · 모션이 이 이름으로 움직임)

| 파트 | 크기 X × Y × Z (stud) | 관절(Motor6D) | 부모 파트 | C0 위치(부모 공간) | C0 회전(도) | 재질 | 색 RGB |
|---|---|---|---|---|---|---|---|
| Body | 6.72 × 9.48 × 4.09 | Waist | Hips | -0.00,1.97,0.15 | -180,0,-180 | SmoothPlastic | 92,97,128 |
| CapeL1 | 5.40 × 2.99 × 1.30 | CapeL1 | Body | 1.57,1.63,-2.30 | -174,0,-180 | SmoothPlastic | 64,67,89 |
| CapeL2 | 7.13 × 2.99 × 1.50 | CapeL2 | CapeL1 | -1.20,-1.51,0.07 | -171,0,-180 | SmoothPlastic | 64,67,89 |
| CapeL3 | 9.53 × 5.66 × 1.96 | CapeL3 | CapeL2 | -3.22,-1.59,0.43 | -168,0,-180 | SmoothPlastic | 64,67,89 |
| CapeR1 | 5.40 × 2.99 × 1.30 | CapeR1 | Body | -1.58,1.63,-2.30 | -174,0,-180 | SmoothPlastic | 64,67,89 |
| CapeR2 | 7.13 × 2.99 × 1.50 | CapeR2 | CapeR1 | 1.20,-1.51,0.07 | -171,0,-180 | SmoothPlastic | 64,67,89 |
| CapeR3 | 9.53 × 5.66 × 1.96 | CapeR3 | CapeR2 | 3.22,-1.59,0.43 | -168,0,-180 | SmoothPlastic | 64,67,89 |
| Eyes | 2.33 × 0.81 × 0.37 | Eyes | Head | -0.00,-1.80,2.34 | -180,0,-180 | **Neon** | 255,249,197 |
| Foot_L | 2.25 × 0.94 × 3.56 | Ankle_L | Shin_L | -0.00,-2.03,-0.10 | -180,0,-180 | SmoothPlastic | 64,67,89 |
| Foot_R | 2.25 × 0.94 × 3.56 | Ankle_R | Shin_R | -0.00,-2.03,-0.10 | -180,0,-180 | SmoothPlastic | 64,67,89 |
| Forearm_L | 2.19 × 3.84 × 2.28 | Elbow_L | UpperArm_L | 0.25,-1.87,0.00 | 172,1,174 | SmoothPlastic | 118,124,156 |
| Forearm_R | 2.19 × 3.84 × 2.28 | Elbow_R | UpperArm_R | -0.25,-1.87,0.00 | 172,-1,-174 | SmoothPlastic | 118,124,156 |
| Hand_L | 2.15 × 2.38 × 2.56 | Wrist_L | Forearm_L | 0.09,-1.74,0.16 | 172,1,174 | SmoothPlastic | 118,124,156 |
| Hand_R | 2.15 × 2.38 × 2.56 | Wrist_R | Forearm_R | -0.09,-1.74,0.16 | 172,-1,-174 | SmoothPlastic | 118,124,156 |
| Head | 6.30 × 8.25 × 4.88 | Neck | Body | -0.00,2.01,-0.24 | -180,0,-180 | SmoothPlastic | 118,124,156 |
| Hips | 6.58 × 3.94 × 4.56 | RootJoint | HumanoidRootPart | 0.00,7.50,0.00 | -0,0,-0 | SmoothPlastic | 64,67,89 |
| LeftBlade | 4.40 × 9.08 × 1.24 | Blade_L | Body | 3.56,2.01,-0.24 | -180,0,-165 | SmoothPlastic | 255,240,90 |
| Mouth | 1.50 × 0.37 × 0.37 | Jaw | Head | -0.00,-3.07,2.34 | -180,0,-180 | SmoothPlastic | 25,18,22 |
| RightBlade | 5.25 × 9.04 × 1.24 | Blade_R | Body | -3.56,2.01,-0.24 | -0,0,15 | SmoothPlastic | 255,240,90 |
| RobeB1 | 4.12 × 2.34 × 0.46 | RobeB1 | Hips | -0.00,0.28,-1.65 | 176,0,-180 | SmoothPlastic | 118,124,156 |
| RobeB2 | 4.50 × 2.34 × 0.58 | RobeB2 | RobeB1 | -0.00,-1.16,0.08 | 173,0,-180 | SmoothPlastic | 118,124,156 |
| RobeF1 | 3.75 × 2.08 × 0.44 | RobeF1 | Hips | -0.00,0.28,1.95 | -176,0,-180 | SmoothPlastic | 118,124,156 |
| RobeF2 | 4.20 × 2.08 × 0.55 | RobeF2 | RobeF1 | -0.00,-1.03,-0.07 | -173,0,-180 | SmoothPlastic | 118,124,156 |
| Shin_L | 2.02 × 4.06 × 2.22 | Knee_L | Thigh_L | -0.00,-1.78,0.00 | -180,0,-180 | SmoothPlastic | 64,67,89 |
| Shin_R | 2.02 × 4.06 × 2.22 | Knee_R | Thigh_R | -0.00,-1.78,0.00 | -180,0,-180 | SmoothPlastic | 64,67,89 |
| Staff | 3.99 × 19.45 × 4.12 | Staff | Hand_R | -0.10,-1.07,-0.11 | 172,-1,-174 | SmoothPlastic | 64,67,89 |
| StaffOrb | 13.61 × 9.34 × 4.30 | StaffOrb | Staff | 0.78,7.61,-1.28 | 172,-1,-174 | **Neon** | 255,240,90 |
| Thigh_L | 2.19 × 3.56 × 2.19 | Hip_L | Hips | 1.42,0.09,0.15 | -180,0,-180 | SmoothPlastic | 92,97,128 |
| Thigh_R | 2.19 × 3.56 × 2.19 | Hip_R | Hips | -1.43,0.09,0.15 | -180,0,-180 | SmoothPlastic | 92,97,128 |
| UpperArm_L | 2.16 × 3.91 × 1.99 | Shoulder_L | Body | 3.94,1.16,-0.24 | -180,0,174 | SmoothPlastic | 92,97,128 |
| UpperArm_R | 2.16 × 3.91 × 1.99 | Shoulder_R | Body | -3.94,1.16,-0.24 | -180,0,-174 | SmoothPlastic | 92,97,128 |

### 장식 (WeldConstraint · 관절 없음 · 판정 없음 · 붙은 부위와 함께 움직임)

| 파트 | 크기 (stud) | 붙은 부위 | 자리(붙은 부위 공간) | 재질 | 색 RGB | 세밀(폰 · 먼 거리 숨김) |
|---|---|---|---|---|---|---|
| Body_Deco1 | 1.35 × 4.37 × 0.15 | Body | -0.11,-1.02,1.71 | **Neon** | 255,224,64 |  |
| Body_Deco2 | 5.74 × 1.99 × 0.45 | Body | 0.00,2.83,0.58 | **Neon** | 255,224,64 | 예 |
| Body_Deco3 | 5.62 × 2.14 × 1.45 | Body | -0.00,2.20,0.96 | SmoothPlastic | 118,124,156 |  |
| Foot_L_Deco1 | 2.48 × 1.12 × 3.75 | Foot_L | 0.00,0.11,0.00 | SmoothPlastic | 46,48,64 |  |
| Foot_R_Deco1 | 2.48 × 1.12 × 3.75 | Foot_R | 0.00,0.11,0.00 | SmoothPlastic | 46,48,64 |  |
| Forearm_L_Deco1 | 0.53 × 1.30 × 0.33 | Forearm_L | -0.14,0.36,1.04 | **Neon** | 255,224,64 | 예 |
| Forearm_L_Deco2 | 2.43 × 2.10 × 2.45 | Forearm_L | -0.12,0.20,-0.12 | SmoothPlastic | 46,48,64 |  |
| Forearm_R_Deco1 | 0.53 × 1.30 × 0.33 | Forearm_R | 0.14,0.36,1.04 | **Neon** | 255,224,64 | 예 |
| Forearm_R_Deco2 | 2.43 × 2.10 × 2.45 | Forearm_R | 0.12,0.20,-0.12 | SmoothPlastic | 46,48,64 |  |
| Head_Deco1 | 4.72 × 5.05 × 4.35 | Head | 0.00,-1.30,0.33 | SmoothPlastic | 46,48,64 |  |
| Hips_Deco1 | 1.20 × 1.20 × 1.20 | Hips | 0.00,1.48,2.10 | **Neon** | 255,224,64 |  |
| Hips_Deco2 | 5.32 × 0.97 × 3.75 | Hips | 0.00,1.59,0.15 | SmoothPlastic | 46,48,64 |  |
| Shin_L_Deco1 | 2.10 × 1.87 × 0.60 | Shin_L | 0.00,0.13,1.03 | SmoothPlastic | 46,48,64 |  |
| Shin_R_Deco1 | 2.10 × 1.87 × 0.60 | Shin_R | 0.00,0.13,1.03 | SmoothPlastic | 46,48,64 |  |
| Thigh_L_Deco1 | 1.72 × 1.30 × 0.87 | Thigh_L | 0.00,-1.72,1.12 | SmoothPlastic | 118,124,156 |  |
| Thigh_R_Deco1 | 1.73 × 1.30 × 0.87 | Thigh_R | 0.00,-1.72,1.12 | SmoothPlastic | 118,124,156 |  |
| UpperArm_L_Deco1 | 2.70 × 0.64 × 0.22 | UpperArm_L | -0.01,2.33,1.39 | **Neon** | 255,224,64 | 예 |
| UpperArm_L_Deco2 | 3.06 × 1.57 × 2.70 | UpperArm_L | 0.06,1.73,0.00 | SmoothPlastic | 118,124,156 |  |
| UpperArm_R_Deco1 | 2.70 × 0.64 × 0.22 | UpperArm_R | 0.01,2.33,1.39 | **Neon** | 255,224,64 | 예 |
| UpperArm_R_Deco2 | 3.06 × 1.57 × 2.70 | UpperArm_R | -0.06,1.73,0.00 | SmoothPlastic | 118,124,156 |  |

- 외곽선 껍데기: Body(7.11 × 9.87 × 4.48) · CapeL3(9.88 × 6.08 × 2.21) · CapeR3(9.88 × 6.08 × 2.21) · Head(6.74 × 8.60 × 5.21) · Hips(6.94 × 4.21 × 4.91) · LeftBlade(4.62 × 9.45 × 1.51) · RightBlade(5.56 × 9.39 × 1.51) · Staff(4.36 × 19.72 × 4.50) · UpperArm_L(2.54 × 4.24 × 2.40) · UpperArm_R(2.54 × 4.24 × 2.40)
- 판정 사본(투명 · 조준 · 피격 이름 유지): Body_Query 6.38 × 6.75 × 3.75 · Head_Query 3.56 × 3.75 × 3.56
- **빛(Neon) 파트**: Body_Deco1 1.35 × 4.37 × 0.15 (255,224,64) · Body_Deco2 5.74 × 1.99 × 0.45 (255,224,64) · Eyes 2.33 × 0.81 × 0.37 (255,249,197) · Forearm_L_Deco1 0.53 × 1.30 × 0.33 (255,224,64) · Forearm_R_Deco1 0.53 × 1.30 × 0.33 (255,224,64) · Hips_Deco1 1.20 × 1.20 × 1.20 (255,224,64) · StaffOrb 13.61 × 9.34 × 4.30 (255,240,90) · UpperArm_L_Deco1 2.70 × 0.64 × 0.22 (255,224,64) · UpperArm_R_Deco1 2.70 × 0.64 × 0.22 (255,224,64)

## 확인 (QUEUE-ART-REF2 확인 6개 - 한 줄 답)

| # | 질문 | 답 | 자세한 근거 |
|---|---|---|---|
| a | 전갈 여왕 주위 떠 있는 금 조각 = 기믹 · 전조? | **아니다** - 전시 리그(`/gg boss anim`)에만 있는 코드 장식(`Deco_Crown_*` · `Deco_Arm_Band_*` 등 금 Metal)이 제자리에서 벗어나 떠 보인 것 · 실전 보스는 코드 장식을 지우고 메시 장식으로 바꿔 떠 있는 조각이 없음 | 31 ref-parts 확인 a |
| b | 심해 군주 어깨 빛 = 기믹 · 전조? | **아니다** - 어깨 높이에 보인 빛 = 오른손 삼지창 머리 `TridentHead`(상시 Neon) · 실전 메시 어깨 장식은 Neon 아님 · 전조 번쩍임은 `Trident` 자루를 잠깐 흰색으로 바꾸는 별도 동작 | 31 ref-parts 확인 b |
| c | 블룸이 하얗게 안 날아가는 빛 파트 크기 상한 | **크기 상한은 없다(0.5 ~ 5 stud 같은 화면 색)** - 흰 날림은 **색**이 결정: Neon 화면 색 ≈ 채널 × 약 1.65 → 세 채널이 모두 약 150 이상이면 크기와 무관하게 흰색 · 색을 지키려면 가장 낮은 채널 ≤ 약 90 · 수정 여왕 왕관 (150,240,255) = 흰색 / 폭풍 군주 어깨 (255,224,64) = 노랑 유지 | 31 ref-parts 확인 c · `bloom_*.png` |
| d | 큰 나무 발판 · 체크포인트 · 전망대 · 둥지 좌표 + 잎 분리? | 점프맵 = `Ground.TreeCourse`(발판 약 300 · 좌표 = `30_hub-art/_ref/ref-tree-course.csv`) · 정거장 5(= 떨어지면 돌아오는 체크포인트) · 전망대 y 750 · 알 자리 2 / **잎은 `Ground.BigTree.Leaves` 모델로 따로 · 충돌 없음 → 잎만 옮길 수 있음**(가지 자리 안 바뀜 · 단 숨은 알 `tree_leafnest`의 가림은 달라짐) | 30 ref-parts 확인 d |
| e | 포탈 원판 지름 · 광장 4자리 상자 크기 | 포탈 원판 = **지름 12 stud**(원통 두께 0.4 · 6개 · 포탈 광장 중심에서 반경 38) / 광장 4자리 = **6 × 7 × 2 stud**(폭 × 높이 × 두께 · 바닥 위로 보이는 높이 약 4.7) | 30 ref-parts 확인 e |
| f | 집 B 옆 판자 더미 · 청록 기둥 | 판자 더미 = `Struct_hub_ruins012` = **마을 비밀 둥지 C `hub_c_chimney`**(나무 상자 기둥 3 = 지붕 굴뚝으로 오르는 계단 · 지난 ref의 "떨어진 굴뚝"도 이 둥지의 굴뚝) · 상점 지붕 막대 = `Struct_hub_ruins968` = 비밀 둥지 `hub_c_attic` / 청록 기둥 = **체크포인트 표시**(`TravelChannelLocal.Checkpoint_hub` · 클라 장식 · 프롬프트 없음 · 숨겨도 기능 영향 없음) · 마을 기능 프롬프트는 `Spot_*` 파트에 붙고 투명이어도 동작 | 30 ref-parts 확인 f · 32 ref-parts |

### 확인 a — 전갈 여왕 떠 있는 금 조각
- 정체: `BossDetailSpec` 코드 장식(금 = accent 색 Metal) - `Deco_Crown_Band` · `Deco_Crown_Spike` · `Deco_Crown_SpikeSide_L/R`(머리) · `Deco_Arm_Band_L/R`(앞팔) · `Deco_Carapace_TrimF/M/B`(등) · `Deco_Necklace` + 연한 색 `Deco_Claw_Tooth*` · `Deco_Mandible_*`.
- 떠 보인 이유(실측 사실): 전시 리그에서 이 장식이 데이터 자리에서 벗어나 있었다. 예 `Deco_Claw_Tooth_L` 데이터 자리 = (0.22, −0.30, −0.20) × 배율 3.5 = (0.77, −1.05, −0.70) → 실측 (8.52, 22.82, 2.68) · `Deco_Crown_Band` 데이터 (0, 1.33, 0.53) → 실측 (0, 1.33, 10.12). 전시 리그 전용이라 원인은 이번에 조사하지 않음(코드 변경 금지 작업).
- 기믹 · 전조가 아닌 근거: 장식 = "관절 없음 · 충돌 · 조준 · 터치 없음 · 모션 비용 0"(`shared/data/BossDetailSpec.lua:4` 주석 · 조립 `shared/BossRig.lua:99-115`). 전갈 여왕 전조 번쩍임은 `flash = "Pincer_R"`(`shared/data/BossMotionData.lua:518`)로 오른 집게만 → `client/BossAnimator.client.lua:225-241` `applyFlash`가 그 파트를 잠깐 Neon + 흰색으로.
- 실전: 서버 스폰이 메시를 끼울 때 코드 장식을 먼저 지운다(`shared/ArtMeshKit.lua:71-74`) → 실전 전갈 여왕에는 `Deco_*` 파트가 0개 · 떠 있는 조각 없음(`arena_5_scorpion-queen.png`). 실전 금색(255,196,60) = `Body_Deco1` · `Body_Deco2`(Metal) · `Body_Deco3`(Neon) · `Head_Deco1`(Metal · 왕관) 메시 장식 - 전부 몸 · 머리에 붙어 있음(위 표).

### 확인 b — 심해 군주 어깨 빛
- 지난 사진의 어깨 쪽 큰 하늘색 빛 = **오른손 삼지창 머리 `TridentHead`**(코드 리그 Neon 0.9 × 0.7 × 0.15 × 배율 3.6 · `shared/data/BossRigSpec.lua:116` `material = "Neon"` 상시). 대기 자세에서 오른손이 어깨 옆이라 어깨 빛처럼 보였다.
- 실전 메시: `TridentHead` 5.81 × 6.20 × 1.33 Neon (60,200,255) · 어깨 장식 `UpperArm_L/R_Deco1`(0.71 × 1.85 × 3.31 · SmoothPlastic) · `UpperArm_L/R_Deco2`(가리비 어깨 3.89 × 2.21 × 3.67 · SmoothPlastic) = **어깨에는 빛 없음**. 실전 Neon 7개 = 눈 · 진주 `Body_Deco1` · 삼지창 머리 + `Trident_Deco1` · 촉수 끝 `TentL3/M3/R3`.
- 기믹 · 전조 아님: 상시 빛이다. 심해 군주 전조 번쩍임은 휘두르기 `flash = "weapon"`(`shared/data/BossMotionData.lua:117`) → 무기 = `Trident` 자루(`client/BossAnimator.client.lua:47` `WEAPONS` · 65-74) → `applyFlash`(225-241)가 자루를 잠깐 흰색으로 바꾸는 것(머리 빛과 별개).

### 확인 c — 블룸 상한(아레나 조명 실측)
- 조명(실측): `Lighting.Bloom` Intensity 0.40 · Size 18 · Threshold 1.50 · `CartoonColorCorrection` Contrast 0.10 · Saturation −0.06 · Brightness 2.2.
- 방법: 수정 여왕 아레나에서 클라 전용 시험 Neon 상자(같은 색 × 크기 0.5 · 1 · 2 · 4 stud)를 세우고 캡처 → 상자 가운데 화면 픽셀 평균(`bloom_2_color-size-grid.png`). 시험 상자는 Play 중 클라에만 · 끝나면 사라짐.

| 넣은 색 RGB | 쓰는 곳(실전) | 화면 색 4 stud | 2 stud | 1 stud | 결과 |
|---|---|---|---|---|---|
| 150,240,255 | 수정 여왕 `Crown` · `ScepterGem` | 255,255,253 | 255,255,253 | 254,254,252 | **흰색** |
| 232,204,255 | 수호자 `Eyes` | 255,255,253 | 255,255,253 | 254,254,252 | **흰색** |
| 190,110,255 | 수호자 `Rune` · 깃발 끝 · 장식 | 255,218,252 | 254,214,251 | 254,207,251 | 거의 흰색(연분홍) |
| 84,226,214 | 수정 여왕 `Head_Deco1/2` 등 | 143,254,251 | 138,255,252 | 130,254,251 | 연청록 유지 |
| 60,200,255 | 심해 군주 `TridentHead` · 촉수 | 59,255,251 | 54,255,249 | 51,254,248 | 청록 유지 |
| 255,190,60 | 전갈 여왕 꼬리 끝 | 255,255,69 | 255,255,67 | 254,254,78 | 노랑(주황 빠짐) |
| 255,224,64 | 폭풍 군주 어깨 · 몸 장식 | 255,255,79 | 254,254,77 | 254,254,70 | 노랑 유지 |
| 90,144,153 | (시험 - 어둡게) | 127,241,241 | 124,240,239 | 120,239,238 | 청록 |
| 50,136,128 | (시험 - 어둡게) | 16,225,206 | 16,225,206 | 14,225,206 | 짙은 청록 |
| 110,66,153 | (시험 - 어둡게) | 182,49,234 | 181,48,233 | 177,46,232 | 보라 유지 |

- 결론(실측): **크기가 아니라 색이 흰 날림을 정한다.** 같은 색이면 1 · 2 · 4 stud(크기 줄 시험 0.5 ~ 5 stud도 같음 · `bloom_1_size-row.png`) 화면 색이 같다. 크기는 둘레 번짐(블룸 halo) 면적만 키운다.
  - Neon 화면 색 ≈ 넣은 채널 × 약 1.65(255에서 잘림) → 채널이 약 155 이상이면 255. **세 채널이 모두 약 150 이상 = 흰색.**
  - 색을 지키려면 **가장 낮은 채널 ≤ 약 90**(화면 ≤ 약 150) · 주황처럼 중간 채널이 중요한 색은 그 채널도 ≤ 약 120(255,190,60 → 노랑이 됨).
- 수정 여왕 왕관(실전 `Crown` 3.31 × 2.86 × 2.96 · 150,240,255): 흰색으로 보임 · 눈(218,249,255)도 흰색. 가까이 보면 얼굴은 보인다(`bloom_3_crystal-queen-crown.png`) - 지난 사진의 "얼굴이 안 보임"은 전시 리그 · 마을 조명 · 각도 영향이 섞인 것.
- 폭풍 군주 어깨(실전): 어깨 빛 = `UpperArm_L/R_Deco1` 2.70 × 0.64 × 0.22 Neon (255,224,64) → 노랑 유지 · 어깨 번개 칼날 `LeftBlade` · `RightBlade`(4.40 ~ 5.25 × 9.04 × 1.24)는 SmoothPlastic(빛 아님) - 흰 날림 없음(`bloom_4_storm-lord-shoulder.png`). 가장 큰 Neon = `StaffOrb` 13.61 × 9.34 × 4.30 (255,240,90).
