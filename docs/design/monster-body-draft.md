# M2 잡몹 몸체 초안 (묶음 B · 2026-09-29)

규격 = `roblox/src/shared/data/MonsterRigSpec.lua` · 종 데이터 = `MonsterSpeciesData.lua` · 조립 = `shared/BossRig.build`(보스와 같은 파트 + Motor6D) · 전조 포즈 = `client/MonsterRigAnimator.client.lua`.
공통: 단순 도형 · SmoothPlastic 단색 · 몸체당 ≤ 10파트 · 외형 파트 CanCollide/CanQuery/CanTouch 끔 · 조준 · 판정 = 투명 `Hitbox`(옛 몸통 + 머리 = 2.4 × 4.6 × 1.6 × 크기) + 루트(그대로).
관절 이름: Body = `RootJoint` · Head = `Neck` · 나머지 = 부위 이름.

| 종(티어) | 부위(파트 수) | 전조 |
|---|---|---|
| 이끼 슬라임(T1) | Body(공) · Head(이끼 모자) · Eye_L · Eye_R (4) | 1.0초 납작(RootJoint −0.35) |
| 바위 멧돼지(T1) | Body · Head · Eyes · Tusk_L/R · Moss · Leg_FL/FR/BL/BR (10) | 0.8초 머리 숙임 + 뒷발 긁기 |
| 수정 딱정벌레(T2) | Body · Head · Eyes · Leg_L/R · Shell1~3 (8) | - |
| 자수정 박쥐(T2) | Body(공) · Head · Ear_L/R · Eyes · Wing_L/R (7) | - |
| 소라게 기사(T3) | Body · Head · Eyes · Shell(공) · Claw_L/R · Leg_L/R (8) | - |
| 물방울 해파리(T3) | Body(갓) · Head · Eyes · Tentacle1~4 (7) | - |
| 모래 전갈(T4) | Body · Head · Eyes · Claw_L/R · Leg_L/R · Tail1~3 (10) | - |
| 선인장 꼬마(T4) | Body · Head · Flower · Eyes · Arm_L/R (6) | - |
| 번개 임프(T5) | Body · Head · Eyes · Horn_L/R · Arm_L/R · Leg_L/R · Tail (10) | - |
| 구름 양(T5) | Body(공) · Wool(공) · Head · Eyes · Leg ×4 (8) | - |
| 얼음 골렘(T6) | Body · Head · Eyes · Arm_L/R · Fist_L/R · Leg_L/R (9) | 1.3초 두 주먹 머리 위 |
| 눈토끼(T6) | Body(공) · Head(공) · Eyes · Ear_L/R · Tail(공) (6) | - |

표준에 새로 넣은 부위 이름: Eye_L/R · Tusk_L/R · Moss · Shell1..n · Wool · Flower · Fist_L/R · Horn_L/R · Tentacle1..n(BossRigSpec에 없던 것).

## 카툰 교체 방법
1. 카툰 메시(MeshPart)를 부위마다 만들고 이름을 이 표의 파트 이름과 같게 둔다(Body · Head는 필수).
2. `MonsterRigSpec.rigs[종]`의 그 관절 `size`를 메시 크기로 바꾸고 `at` · `pivot`(관절 자리)은 그대로 둔다 - 관절 이름 · 부모가 같으면 전조 포즈 · 모션 코드는 안 바뀐다.
3. `BossRig.build`의 `newPart`가 부위를 Part로 만든다 → 메시로 바꿀 때는 그 한 곳에서 "같은 이름 템플릿이 있으면 복제"로 바꾼다(보스와 공용).
4. 외형 파트 CanQuery는 끈 채로 둔다(조준 = Hitbox) - 크기가 바뀌어도 판정은 그대로.
5. 색은 `MonsterSpeciesData`(body · head · accent)만 고친다(세대 틴트 · 피격 번쩍임이 이 색에서 출발).
