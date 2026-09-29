# Blender 제작 순서표 — 몬스터 13종 + 대검 3등급 (A2-S2 · 2026-09-30 · 대량 생산 전 계획)

> 이 표는 **순서 · 재료만** 정한다. 한 번에 한 종씩 만들고 Studio에서 확인한 뒤 다음으로 간다(대량 생산 금지).
> 규칙: 형태 · 색 = `art-direction-v1.md` · 파트 이름 = `MonsterRigSpec`(관절 이름 그대로 - 전조 포즈가 그대로 먹는다) · 스크립트 = `roblox/tools/blender/make_rig_mesh.py`(몬스터) · `make_greatsword.py`(무기) · 가져오기 = `3d-pipeline.md` · 검사 = `/gg mesh check`(몬스터 · 보스) / `WeaponRigCheck`(무기).
> 색 = `MonsterSpeciesData`의 body / head / accent(스폰과 같은 색 - Blender에는 단색 재질 1개씩 · 색은 데이터가 칠한다). 참조 이미지 = `docs/art/ref/`.
> **방식** 열: `도형 조립` = Studio 기본 도형(공 · 상자 · 쐐기)만으로 이미 실루엣이 된다 - Blender 메시를 만들지 않고 A2-S 슬라임처럼 `ArtStyleV1Data` 관절 표로 짓는다 / `Blender` = 곡면 · 뾰족 · 얇은 판이 핵심이라 파트로는 두꺼운 판 · 상자로 보인다.

## 1. 순서표

| 순서 | 대상 | 티어 | 방식 | 참조 이미지 | 파트(이름 = 리그) | 목표 삼각형(상한) | 색 body / head / accent | 튀어나온 것 1개(실루엣) |
|---|---|---|---|---|---|---|---|---|
| 0 | 대검 3등급(시험 끝 - 가져오기만 남음) | 무기 | Blender | `13_weapons.png` | Blade · Fuller · Guard · Grip · Pommel · (전설+) Wing_R · Wing_L · Gem · (초월) Crack1 · Crack2 | 126 / 162 / 186(800) | `art-direction-v1.md` §3-5 표 | 넓은 날 + 날개 가드 |
| 1 | 이끼 슬라임 `moss_slime` | T1 | 도형 조립(A2-S 샘플 유지 - 사용자 결정) | `10_monsters_T1-T3.png` · `01_T1.png` | Body · Base · Head · Leaf_L · Leaf_R · Eye_L · Eye_R · Pupil_L · Pupil_R · Shine(아트 10) | - (파트 10) | 민트 `#68E0A0` · 이끼 `#3A843E` · 잎 `#7EC446`(아트 샘플 값) | 새싹 두 잎 |
| 2 | 바위 멧돼지 `rock_boar` | T1 | Blender | `10_monsters_T1-T3.png` | Body · Head · Eyes · Tusk_L · Tusk_R · Moss · Leg_FL · Leg_FR · Leg_BL · Leg_BR(10) | 900(1,500) | `#8C8A84` / `#A5A29B` / `#5A9646` | 휜 엄니 두 개(곡면 = 메시) |
| 3 | 수정 딱정벌레 `crystal_beetle` | T2 | Blender | `10_monsters_T1-T3.png` · `02_T2.png` | Body · Head · Eyes · Leg_L · Leg_R · Shell1 · Shell2 · Shell3(8) | 800(1,500) | `#6E50B4` / `#8C6EC8` / `#D796F5` | 등 수정 3개(각진 결정 - 면 깎기) |
| 4 | 자수정 박쥐 `amethyst_bat` | T2 | Blender | `10_monsters_T1-T3.png` | Body · Head · Ear_L · Ear_R · Eyes · Wing_L · Wing_R(7) | 700(1,500) | `#5F4696` / `#5F4696` / `#C882F0` | 날개 막(얇은 판 + 뼈 모서리) |
| 5 | 소라게 기사 `hermit_knight` | T3 | Blender | `10_monsters_T1-T3.png` · `03_T3.png` | Body · Head · Eyes · Shell · Claw_L · Claw_R · Leg_L · Leg_R(8) | 1,000(1,500) | `#EB6E5A` / `#EBDCBE` / `#F58269` | 나선 소라 껍데기 |
| 6 | 물방울 해파리 `bubble_jelly` | T3 | 도형 조립 | `10_monsters_T1-T3.png` | Body · Head · Eyes · Tentacle1 ~ 4(7) | - (파트 7) | `#6ED7E6` / `#AAEBF5` / `#46AAC3` | 갓 + 굵은 촉수(공 · 원기둥으로 충분) |
| 7 | 모래 전갈 `sand_scorpion` | T4 | Blender | `11_monsters_T4-T6.png` · `04_T4.png` | Body · Head · Eyes · Claw_L · Claw_R · Leg_L · Leg_R · Tail1 · Tail2 · Tail3(10) | 1,100(1,500) | `#D79646` / `#E6AF5F` / `#AA3C32` | 위로 말린 꼬리 + 독침(보스 전갈 축소판 - 보스 메시와 같은 비율) |
| 8 | 선인장 꼬마 `cactus_imp` | T4 | Blender | `11_monsters_T4-T6.png` | Body · Head · Flower · Eyes · Arm_L · Arm_R(6) | 600(1,500) | `#469646` / `#5AAA55` / `#F596BE` | 꽃(평소 소품 선인장과 같은 실루엣 - 소품 메시와 공유 검토) |
| 9 | 번개 임프 `bolt_imp` | T5 | Blender | `11_monsters_T4-T6.png` · `05_T5.png` | Body · Head · Eyes · Horn_L · Horn_R · Arm_L · Arm_R · Leg_L · Leg_R · Tail(10) | 900(1,500) | `#5A3C96` / `#6E50AA` / `#78E6FF` | 번개 꼬리(지그재그) + 뿔 |
| 10 | 구름 양 `cloud_sheep` | T5 | 도형 조립 | `11_monsters_T4-T6.png` | Body · Wool · Head · Eyes · Leg_FL · Leg_FR · Leg_BL · Leg_BR(8) | - (파트 8) | `#F0F2F8` / `#5F6473` / `#FADC5A` | 털 덩어리 두 개(공 겹치기로 충분) |
| 11 | 얼음 골렘 `ice_golem` | T6 | Blender | `11_monsters_T4-T6.png` · `06_T6.png` | Body · Head · Eyes · Arm_L · Arm_R · Fist_L · Fist_R · Leg_L · Leg_R(9) | 1,000(1,500) | `#AAD7F5` / `#C8E6FA` / `#509BD7` | 깎인 얼음 주먹(큰 면 깎기) |
| 12 | 푸른 드래곤 `blue_dragon` | T6 | Blender | `19_monsters_T6_blue_dragon.md` · `11_monsters_T4-T6.png` | Body · Leg_FL · Leg_FR · Leg_BL · Leg_BR · Neck1 · Head · Jaw · Eyes · Wing_L · Wing_R · Tail1 · Tail2 · Tail3(14) | 1,500(1,500) | `#4682CD` / `#AFE1FA` / `#C8F0FF` | 날개 + 긴 목(판정 hitbox는 종 데이터 그대로) |
| 13 | 눈토끼 `snow_rabbit` | T6 | 도형 조립(퇴역 `retiredBy = blue_dragon` - 마지막 · 생략 가능) | `11_monsters_T4-T6.png` | Body · Head · Eyes · Ear_L · Ear_R · Tail(6) | - (파트 6) | `#F5F7FC` / `#FAFAFF` / `#F5B4C3` | 긴 귀 |

- 합계: Blender 9종 + 대검 · 도형 조립 4종. 순서 = 플레이어가 먼저 만나는 순(T1 → T6) · 같은 티어 안은 실루엣이 어려운 쪽 먼저.
- 도형 조립 종도 **눈 · 광택 · 3톤 규칙**은 슬라임 샘플과 같게 맞춘다(아트 관절 표 `ArtStyleV1Data.monsterRigs.<종>`).

## 2. 한 종 절차(반복 단위)

1. 리그 JSON 뽑기: Studio에서 `rig_dump.luau` → `roblox/tools/blender/rigs/<종>.rig.json`(B3 README).
2. `blender -b --factory-startup -P roblox/tools/blender/make_rig_mesh.py -- --rig roblox/tools/blender/rigs/<종>.rig.json` → 시작 도형 · 메타 · FBX.
3. Blender에서 파트 모양을 다듬는다(오브젝트 이름 · 원점은 그대로) → `--export-only`로 삼각형 수 · 메타 · FBX만 다시.
4. 정면 · 45도 렌더 PNG(무기 스크립트의 렌더 함수와 같은 방식) → 도형 조립 샘플과 나란히 비교.
5. 가져오기(`3d-pipeline.md` ① 또는 ②) → `/gg mesh check <종> <모델>` 14/14 → `/gg mesh swap` 미리보기 → 3각도 스크린샷 + 삼각형 수.
6. 사용자 확인(체감) 뒤 다음 종.

## 3. 결정 필요(이 표에 묶인 것)

1. 도형 조립 4종(슬라임 · 해파리 · 양 · 토끼)을 끝까지 파트로 둘지, 전 종 메시로 맞출지 - 추천: **파트 유지**(삼각형 적고 이미 둥근 실루엣) · 외곽선 두께가 문제 되면 그때 메시.
2. 가져오기 경로 ①(사람 클릭 13회) vs ②(API 키 1회) - 추천: 대검 1자루는 ①로 절차 확정 → 몬스터부터 ②.
3. 대검 날개 크기: Blender 판은 ArtStyleV1Data(0.95 × 0.85)보다 작게(0.75 × 0.6) 만들었다(첫 렌더에서 가시처럼 커 보였다) - 확정 시 데이터 값도 같이.
