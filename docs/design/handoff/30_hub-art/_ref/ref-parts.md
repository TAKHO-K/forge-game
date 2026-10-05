# 30_hub-art _ref — 마을 NPC · 건물 · 소품 부위 · 크기 표 (ref-parts)

- 만든 날: 2026-10-05 · QUEUE-ART-REF2(읽기 · 문서 추가만 - 게임 코드 · 데이터 · 에셋 변경 0)
- 대상: spec v1 "결정할 것" 1번(NPC 부위 이름 · 관절 표) · 5 · 6 · 7번 자료 + 확인 d · e · f(맨 끝 "확인" 절).
- 출처 = Studio Play 서버 · 클라 인스턴스 실측(`Workspace.HubArt` · `Workspace.Ground.Hub` · `Ground.TreeCourse` · `Ground.BigTree`) + 데이터 `roblox/src/shared/data/HubArtData.lua` · `HubArtMeta.lua`(생성 표). 추측 값 없음.
- 같이 둔 파일: `ref-tree-course.csv`(큰 나무 점프맵 발판 280개 좌표 · 크기).
- 좌표 = 월드 stud(허브 원점 = 큰 나무 줄기 가운데 · 마을 바닥 윗면 y ≈ 1.3). 크기 = 폭 X × 높이 Y × 깊이 Z.

## 1. NPC — 리그가 아니라 "고정 메시 조각 + 관절 점"

**spec v1 가정과 다른 점(중요)**
- NPC는 Motor6D 리그가 아니다. 부위마다 Anchored MeshPart 1개(충돌 끔)이고, 대기 동작은 클라(`client/HubNpcView`)가 부위 묶음을 **관절 점(HubArtMeta `pivots`)** 둘레로 돌린다. 관절 = 점 3개뿐: `ArmL` · `ArmR`(어깨) · `Head`(목).
- **다리는 `Legs` 한 조각**(LegL · LegR · Hip 관절 없음 - 다리는 움직이지 않음). 도구 이름은 `ToolR` · `ToolL`(망치 = 대장장이 `ToolR`).
- 모자 · 얼굴은 `Hat` · `Face`(기사는 `Plume` 깃털도) 따로 - 고개 동작은 `Head` · `Face` · `Hat` · `Plume`을 함께 돌린다(`HubArtData.lua:5` `HEAD`).
- 5명이 같은 몸 상자(머리 1.75 × 1.60 × 1.60 · 몸통 2.00 × 1.95 × 1.15 · 팔 0.66 × 2.10 × 0.66 · 다리 1.80 × 1.90 × 1.20)를 쓰고 모자 · 소품만 다르다.

**관절 점(5명 공통 · 발밑 가운데 기준 · stud)**: `ArmL` (−1.32, 3.55, 0) · `ArmR` (1.32, 3.55, 0) · `Head` (0, 3.95, 0). 축: X+ = 팔이 앞(−Z)으로 · Z+ = 오른팔이 바깥으로 · Y+ = 고개 왼쪽(`HubArtData.lua:4`).

### 공통 몸 조각(5명 같음)
| 파트 | 크기 | 가운데 자리(발밑 기준) | 움직이는 관절 |
|---|---|---|---|
| Head | 1.75 × 1.60 × 1.60 | (0, 4.80, 0) | Head(목) |
| Face | 0.98 × 0.38 × 0.10 (기사 1.20 × 0.22 × 0.10) | (0, 4.90, −0.82) (기사 −0.92) | Head |
| Torso | 2.00 × 1.95 × 1.15 | (0, 2.85, 0) | 없음 |
| ArmL | 0.66 × 2.10 × 0.66 | (−1.32, 2.60, 0) | ArmL(어깨) |
| ArmR | 0.66 × 2.10 × 0.66 | (1.32, 2.60, 0) | ArmR(어깨) |
| Legs | 1.80 × 1.90 × 1.20 | (0, 0.95, −0.12) | 없음 |

### NPC별 다른 조각 · 대기 동작
| NPC | 모델 · 자리(발밑 월드) | 높이 | 다른 조각(크기 · 가운데 자리) | 대기 동작(HubArtData.motion - 관절 · 축 · 기준각 ± 진폭 · 주기) | 몸 색 RGB(HubArtMeta) |
|---|---|---|---|---|---|
| 대장장이 | `HubNpc_smith` · (155.1, −65.0) | 5.95 | Hat 1.90 × 0.50 × 1.75 (0, 5.70, 0) · Apron 1.70 × 2.20 × 0.15 (0, 2.40, −0.62) · ToolR(망치) 0.90 × 1.70 × 0.50 (1.32, 1.15, −0.20) | ArmR + ToolR · X 25 ± 35° · 1.1초(망치질) / 머리 X 6 ± 4° · 1.1초 | 몸 · 팔 150,96,62 · 앞치마 96,62,40 · 모자 60,50,46 · 망치 90,92,104 · 다리 70,60,56 |
| 상인 | `HubNpc_merchant` · (−39.5, −174.7) | 6.51 | Hat(밀짚) 2.60 × 0.95 × 2.60 (0, 6.03, 0) · Bag 0.90 × 1.00 × 0.60 (−1.25, 2.30, −0.30) · 도구 없음 | ArmR · Z 30 ± 18° · 1.4초(손님 부르기) / 머리 Y 0 ± 12° · 3.2초 | 몸 · 팔 64,116,206 · 모자 220,196,120 · 가방 176,124,72 · 다리 80,70,60 |
| 재봉사 | `HubNpc_tailor` · (−54.6, −180.9) | 5.88 | Hat 1.50 × 0.35 × 1.50 (0, 5.70, 0) · Tape(금 띠) 2.10 × 0.22 × 1.25 (0, 3.45, 0) · ToolR(가위) 0.39 × 0.89 × 0.08 (1.32, 1.25, −0.30) | ArmR + ToolR · X 35 ± 10° · 0.55초(가위질) / 머리 X 10 ± 3° · 2.2초 | 몸 · 팔 150,90,160 · 모자 · 띠 236,214,120 · 가위 200,206,218 · 다리 70,56,80 |
| 도전 기사 | `HubNpc_knight` · (142.0, −246.0) | 6.86 | Hat(투구) 1.95 × 2.33 × 1.90 (0, 5.14, 0) · Plume 0.30 × 0.70 × 1.60 (0, 6.50, 0.10) · ToolL(방패) 1.50 × 1.90 × 0.25 (−1.62, 2.55, −0.45) · ToolR(검) 1.10 × 2.14 × 0.30 (1.32, 1.13, −0.55) | 머리 Y 0 ± 18° · 4.5초(둘러보기) / ArmL + ToolL · X 8 ± 3° · 3초 | 갑옷 206,212,224 · 다리 150,158,174 · 깃 · 방패 210,60,70 · 검 232,236,244 |
| 게시판지기 | `HubNpc_keeper` · 게시판 자리 + (5.5, −1.5) = (76.3, −215.2) | 5.83 | Hat(베레모) 1.85 × 0.30 × 1.70 (0, 5.67, −0.15) · ToolR(두루마리) 1.40 × 0.64 × 0.64 (1.32, 1.40, −0.35) | ArmR + ToolR · X 40 ± 8° · 2초(두루마리 보이기) / 머리 X 0 ± 5° · 2초 | 몸 · 팔 92,140,96 · 모자 70,100,72 · 두루마리 250,240,210 · 다리 90,74,60 |
| 보석상인 | `Workspace.GemMerchant`(옛 기본 도형 · HubArt 아님) · 노점 가운데 (−74.0, −158.6) | 6.2 | Stall 6.00 × 2.00 × 3.00(충돌 있음 · 프롬프트 `GemMerchantPrompt` · `ShopPrompt`가 여기) · Body 2.00 × 2.60 × 1.20(노점 피벗 기준 0, 2.30, 2.00) · Head 1.60 × 1.60 × 1.60(0, 4.40, 2.00) · Gem 1.20(Neon · 0, 1.90, −0.40) | 없음 | (기본 도형 색) |
| 부화장지기 | **NPC 없음** - `Ground.Hub.Spot_hatchery` (168.4, −207.6) 회색 자리 상자뿐(`Soon = true` · `PetData.lua:25` `placeholder = true`) | - | 자리 상자 6 × 7 × 2(아래 확인 e) · 프롬프트 없음 · 이름표 "부화장"만 | 없음 | - |

- NPC 꼭대기 위 이름표 = 메시 꼭대기 + 1.4(`tagGap`) · 기능 아이콘 = + 3.4(`iconGap`) · 대기 동작은 150 stud 안에서만(`motionRadius`).
- 삼각형 예산(HubArtMeta `budget`) NPC 1,500 · 지금 362 ~ 426.

## 2. 건물 · 집 · 게시판 · 작업대 · 환생 제단

건물 = 메시는 겉모습만 · 충돌 = 투명 상자 하나(`Ground.Hub.Facility_*` · 크기 = HubArtMeta w × wallTop × d).

| 대상 | 모델(HubArtMeta 키) | 자리(충돌 상자 가운데 월드 x, z) | 메시 경계 X × Y × Z | 충돌 상자 | 문 폭 × 높이 | 메시 조각(빛 = Neon) | 삼각형 / 예산 |
|---|---|---|---|---|---|---|---|
| 대장간 | `hub_forge` | (190.8, −69.4) | 31.2 × 27.0 × 25.4 | 28 × 16.4 × 20 | 6 × 9 | Anvil · Base · Chimney · Door · DoorFrame · **Ember** · Emblem · Porch · Ridge · Roof · SignArm · SignBoard · Tiles · Timber · Wall · **Window** · 굴뚝 끝(연기) (7.84, 27, 3.6) | 718 / 3,000 |
| 상점 | `hub_shop` | (−87.5, −187.6) | 29.2 × 26.7 × 23.4 | 26 × 17.4 × 18 | 5.6 × 8.5 | Awning · AwningStripe · Base · Crates · Door · DoorFrame · Emblem · Porch · Ridge · Roof · SignArm · SignBoard · Timber · Wall · **Window** | 690 / 3,000 |
| 재봉집 | `hub_tailor` | (−57.2, −200.6) | 23.2 × 20.7 × 20.7 | 20 × 13.9 × 16 | 4.6 × 8 | Base · Door · DoorFrame · Emblem · Porch · Ridge · Roof · SignArm · SignBoard · Timber · Wall · **Window** | 606 / 2,500 |
| 명예의 전당 | `hub_hall` | (158.5, −274.5) | 34.0 × 26.5 × 26.0 | 30 × 20 × 22 | 6 × 10 | Body · Columns · Door · Entablature · Gold · Pediment · Roof · Steps | 1,232 / 3,500 |
| 집 A × 3 | `hub_house_a` | 대장간 거리 (177.2, −100.7) · 시장 (−117.0, −172.8) · 광장 (189.0, −253.4) | 23.2 × 19.7 × 19.6 | 20 × 13.4 × 16 | 4.6 × 8 | Base · Door · DoorFrame · Porch · Ridge · Roof · Timber · Wall · **Window** | 446 / 2,500 |
| 집 B × 2 | `hub_house_b` | 대장간 거리 (200.8, −35.9) · 광장 (124.1, −290.9) | 25.2 × 21.2 × 19.6 | 22 × 14.4 × 16 | 4.6 × 8 | Base · Door · DoorFrame · Porch · Ridge · Roof · Tiles · Timber · Wall · **Window**(**굴뚝 조각 없음** - 확인 f) | 518 / 2,500 |
| 마을 게시판 | `hub_board` · `HubProp_board` | `Spot_noticeBoard` (81.8, −213.7) | 9.0 × 8.3 × 3.0 | 없음(자리 기둥 투명 · 충돌 끔 - `server/HubArt.lua:383-384`) | - | Board · Papers · Posts · Roof | 142 / 800 |
| 보석 가공대 | `prop_gem_bench` · `HubProp_gemcraft` | `Spot_gemcraft` (144.2, −95.0) | 4.0 × 4.38 × 2.2 | 없음(자리 기둥 투명 · 충돌 끔) | - | Bench · Gems · Lens | 224 / 300 |
| 재련대 | `prop_refine_furnace` · `HubProp_refine` | `Spot_refine` (149.7, −80.0) | 3.0 × 5.2 × 2.75 | 없음 | - | Body · Crucible · **Glow** · Mouth | 148 / 300 |
| 강화대 | `Workspace.EnhanceStation`(서버 도형) | (160, −58) 부근 | 서버 파트 = Base 4 × 3 × 4(충돌) + AnvilTop 3 × 1 × 2(`server/EnhanceStation.server.lua:17-33`) · 겉모습 = 클라 `ArtV1View`(이번에 실측 안 함) | Base | - | - | - |
| 환생 제단 | `Workspace.RebirthAltar` · 메시 `props/rebirth_altar` | (125.0, −216.5) | 메시 Base_Mesh 5.80 × 2.15 × 5.80 + Orb_Mesh 1.70 × 1.75 × 1.70(**Neon**) | 투명 Base 5 × 2 × 5(충돌 · 프롬프트 `RebirthAltarPrompt`) + 투명 Orb 2.6 | - | Base_Mesh · Orb_Mesh | - |

## 3. 포탈 · 광장 · 기능 자리

| 대상 | 파트 | 크기 | 자리 | 비고 |
|---|---|---|---|---|
| 포탈 광장 바닥 | `Ground.Hub.PortalPlaza` | 원판 지름 92(두께 0.2) | 가운데 (0, −250) | 포장 · 이름표 "포탈 광장" |
| 구역 포탈 6 | `Ground.Hub.HubPortal`(Attribute `Portal = tier1 ~ tier6`) | **원판 지름 12 · 두께 0.4** | 광장 가운데에서 반경 38 · tier1 (38, −250) · tier2 (19, −217.1) · tier3 (−19, −217.1) · tier4 (−38, −250) · tier5 (−19, −282.9) · tier6 (19, −282.9) · 윗면 y 1.7 | 충돌 있음 · 들어감 판정은 서버 거리(`server/Travel.lua` `portalRadius`) |
| 커뮤니티 광장 바닥 | `DistrictFloor`(community) | 원판 지름 100 | (125.0, −216.5) | |
| 광장 4자리(회색 상자) | `Spot_hatchery` · `Spot_partyBoard` · `Spot_rankBoard` · `Spot_hallOfFame` | **6 × 7 × 2**(바닥 위 보이는 높이 약 4.7) | (168.4, −207.6) · (95.6, −249.6) · (105.0, −181.9) · (144.2, −177.7) | 서버 파트 = 투명 0 · 충돌 있음 · 클라는 원래 파트를 숨기고(LocalTransparencyModifier 1) 같은 크기의 둥근 모서리 메시 `BevelSkinLocal.Block`을 그린다 · 프롬프트 = 명예의 전당만 |
| NPC · 소품 자리 7 | `Spot_smith` · `shop` · `tailor` · `challengeKnight` · `noticeBoard` · `gemcraft` · `refine` | 6 × 7 × 2 | NPC · 소품 발밑 | 투명 1 · 충돌 끔(`server/HubArt.lua:383-384`) · 이름표 + 기능 프롬프트 · 아이콘이 여기 붙음(대장장이 자리는 이름표만 - 프롬프트 없음) |

## 4. 큰 나무 — 점프맵 · 잎 · 알 자리 (자세한 좌표 = `ref-tree-course.csv`)

| 묶음 | 위치 | 내용 |
|---|---|---|
| 줄기 | `Ground.BigTree` | 반경 48 · 높이 800 · 꼭대기 Spire 4조각(y 821 ~ 941) · 줄기 속 통로 TunnelFloor/Ceiling/Wall(y 250 ~ 370) · 뿌리 30(충돌 18) |
| 잎 | `Ground.BigTree.Leaves` 모델 | LeafLump 176(투명 상자 - 계절 색 역할 `leaves` 77 · `leavesDeep` 99) + 메시 TreeMesh_Leaves 176 · TreeMesh_Deco_Dark 176 · TreeMesh_Deco_Light 176 · **전부 CanCollide 끔** · 높이 y 156 ~ 965 · 줄기에서 반경 0 ~ 317 |
| 점프맵 | `Ground.TreeCourse` 폴더(잎과 별개) | 6구간 × 안쪽 길(반경 60) · 바깥 길(반경 120) · 가지 Branch 83 · 통통 열매 11 · 말랑 열매 22 · 매달린 열매 10 · 혹 Knot 24 · 잎 발판 LeafPad 34 · 점프대 PadCap 19 · 덩굴 9 · 줄기 통로 계단 6 + 입구 3 · 지름길 덩굴 1 · 코스 뿌리 3 + 혹 2 |
| 정거장 = 체크포인트 | `TreeCourse.Station`(고리 16조각 × 5) | 윗면 y **101 · 231 · 361 · 471 · 581** · 고리 반경 68 ~ 110 · 떨어지면 마지막으로 밟은 정거장으로 돌아옴 · 각 정거장에 내려가기 판 `StationDown`(18.5, y, −87.1) · 표지 `StationSign`(0, y, −89) |
| 꼭대기 전망대 | `TreeCourse.Deck` 16조각 | y **750** · 줄기에서 반경 89 · 조각 44.2 × 2 × 42 · 정상 표지 (0, 751.2, −89) |
| 알 자리(둥지) | `DailyEggSpot` · `EasterEggSpot` | **하루 1회 보상** (0, 751.2, −79) - 전망대 위(Soon) · **숨은 알 `tree_leafnest`** (−44.6, 523.5, −117.8) - 줄기에서 반경 126 · 5구간 바깥 길 옆 |
| 덩굴 리프트 | `Ground.Hub.VineLift` | 바구니 (70, 1.5, 0) 지름 10 · 덩굴 높이 ~ 99 · 프롬프트 `VineLiftPrompt` |

- 그 밖의 둥지: 마을 비밀 둥지 C 4곳 중 줄기 밑동 1곳(`Struct_hub_ruins355` = `hub_c_trunk` · 덩굴로 가린 굴) - 위치 데이터는 서버 전용(`server/SecretNestData.lua`)이라 좌표는 적지 않음.

## 확인 (QUEUE-ART-REF2 확인 6개 - 한 줄 답)

| # | 질문 | 답 | 자세한 근거 |
|---|---|---|---|
| a | 전갈 여왕 주위 떠 있는 금 조각 = 기믹 · 전조? | **아니다** - 전시 리그(`/gg boss anim`)에만 있는 코드 장식이 제자리에서 벗어나 떠 보인 것 · 실전 보스에는 없음 | 31 ref-parts 확인 a |
| b | 심해 군주 어깨 빛 = 기믹 · 전조? | **아니다** - 오른손 삼지창 머리 `TridentHead`(상시 Neon) · 실전 메시 어깨 장식은 빛 아님 | 31 ref-parts 확인 b |
| c | 블룸 크기 상한 | **크기 상한 없음** - 흰 날림은 색이 결정(세 채널 모두 약 150 이상 = 흰색 · 가장 낮은 채널 ≤ 약 90이면 색 유지) | 31 ref-parts 확인 c |
| d | 큰 나무 좌표 + 잎 분리 | 위 4절 · `ref-tree-course.csv` · **잎만 옮길 수 있음** | 아래 확인 d |
| e | 포탈 원판 · 광장 4자리 크기 | 포탈 **지름 12** · 광장 자리 **6 × 7 × 2** | 아래 확인 e |
| f | 집 B 옆 판자 더미 · 청록 기둥 | 판자 더미 = **비밀 둥지 `hub_c_chimney`** · 청록 기둥 = **체크포인트 표시**(프롬프트 없음 · 숨겨도 기능 영향 없음) | 아래 확인 f |

### 확인 d — 큰 나무
- 점프맵 발판(가지 · 열매 · 혹 · 잎 발판 · 점프대 · 덩굴 · 통로) · 정거장(체크포인트) · 전망대 · 알 자리 좌표 = 4절 표 + `ref-tree-course.csv`(280행 · 열 = 이름 · 구간 · 길 · 순서 · x · y · z · 줄기에서 반경 r · 각도 · 크기).
- **잎은 점프맵과 분리돼 있다**: 잎 = `Ground.BigTree.Leaves` 모델 하나(충돌 0) · 점프맵 = `Ground.TreeCourse` 폴더. 잎만 옮겨도 가지 · 발판 자리는 그대로다(가지 자리 = `WorldMapData.hub.tree.course.legs` 데이터).
- A안(바깥 고리)에서 볼 것(사실): ① 잎 생성 규칙이 점프맵 길 바깥 `clearRadius` 145부터 덮게 돼 있다(점프맵 바깥 길 반경 120 · 가지 끝 약 128). ② 숨은 알 `tree_leafnest`(반경 126 · y 523)는 이름대로 잎 덩어리 속에 숨은 알이라 잎을 옮기면 가림이 달라진다. ③ 어깨 위 잎 층 아래 가장자리 ≥ 785 = 전망대(750) 눈높이에서 바깥이 보이게 한 규칙(`WorldMapData.lua` crownShape.topTiers 주석). spec v1의 "A는 가지 위치가 바뀜"은 실제로는 해당 없음(가지는 잎과 따로).

### 확인 e — 포탈 원판 · 광장 4자리
- 포탈 원판 `HubPortal` 6개 = 원통 0.4 × 12 × 12 → **지름 12 stud · 두께 0.4** · 포탈 광장 가운데(0, −250)에서 반경 38(`portalRingRadius`) · 원판 사이(이웃) 거리 38.
- 광장 4자리 = `Spot_*` 파트 **6 × 7 × 2**(폭 6 · 높이 7 · 두께 2 · 가운데 y 2.5 → 바닥 위 보이는 높이 약 4.7) · 생성 `shared/WorldMapLayout.lua:1355` `column(..., 6, 2, 5, ...)`. 화면의 둥근 회색 상자 = 클라 `BevelSkinLocal.Block` 메시(같은 크기).

### 확인 f — 집 B 옆 판자 더미 · 청록 기둥
- 판자 더미 = `Workspace.Ground.Struct_hub_ruins012` = 마을 비밀 둥지 C **`hub_c_chimney`**(`server/SecretNestData.lua:40` · 키트 `shared/WorldStructures.lua:195-219` `SPECIAL.chimney`). 대장간 거리 첫 집(집 B · 충돌 상자 가운데에서 4 stud) 지붕 높이에 벽돌 굴뚝(Chimney 4 · ChimneyCap · ChimneySoot) + 옆에 나무 상자 기둥 3(Crate 4.5 × 4.5 · 높이 5 · 10 · 15 = 지붕 굴뚝까지 오르는 계단). 굴뚝 안이 알 자리.
  - 그래서 지난 ref의 "집 B 벽돌 굴뚝이 지붕과 떨어져 있음"도 이 둥지의 굴뚝이다(집 B 메시에는 굴뚝 조각이 없음 - HubArtMeta `hub_house_b` parts).
  - 같은 방식으로 "상점 지붕 위 떠 있는 막대 2" = `Struct_hub_ruins968` = 비밀 둥지 **`hub_c_attic`**(`SecretNestData.lua:41` · `WorldStructures.lua:220-242` - 지붕 위 다락 Attic + AtticRoof + 상자 계단 3).
  - → spec v1 공통 규칙의 "상점 지붕 막대 없앰 · 집 B 굴뚝을 지붕에 붙임"은 **비밀 둥지(알 자리)를 지우거나 옮기는 일**이다(마을 비밀 둥지 4 = chimney · attic · trunk · arch).
- 청록 기둥 = `Workspace.TravelChannelLocal.Checkpoint_hub` = **체크포인트 표시 수정 기둥**(클라 `client/TravelChannelView.client.lua:107-131` · Neon (120,220,255) · 2.2 × 7 × 2.2 · 45° 돌림 · 못 찾음 투명 0.7 / 찾음 0.15 · 이름표 "큰 나무 마을"). 마을 (84.1, −155.1) 1개 + 구역 입구 캠프 6개.
  - 숨겨도 기능 영향 없음: 충돌 · 조회 · 터치 모두 끔 · ProximityPrompt 없음 · 체크포인트 발견은 서버가 거리로 판정(40 stud · `server/Travel.lua:253`).
  - 마을 기능 프롬프트는 이 기둥이 아니라 `Spot_*` 파트에 붙는다(`client/HubServices.client.lua:46-58`). Spot은 투명 1이어도 프롬프트가 동작한다(지금 프롬프트가 붙은 NPC · 소품 자리 6곳 - 상점 · 재봉사 · 도전 기사 · 게시판 · 재련대 · 보석 가공대 - 이 이미 투명 1 · 충돌 끔 상태로 동작 중). 숨길 때는 투명도만 바꾸고 파트를 지우거나 옮기면 안 된다(프롬프트 · 이름표 · 아이콘이 같이 사라짐).
